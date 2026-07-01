local VORPCore = exports.vorp_core:GetCore()
local progressbar = exports.vorp_progressbar:initiate()
local isSelling = false
local soldNPCs = {}
local clientWeedItems = nil
local hasContraband = false
local checkingInventory = false
local wasNearAnyNpc = false
local lastAlertTime = 0
local PendingDeal = nil

-- Progress bar helper
local function startProgressBar(label, duration, cb)
    local ped = PlayerPedId()
    Wait(300)
    FreezeEntityPosition(ped, true)
    progressbar.start(label, duration, function()
        FreezeEntityPosition(ped, false)
        if cb then cb() end
    end)
end

local function Notify(msg, type)
    TriggerEvent('vorp:TipRight', msg, 4000)
end

local function nativeGetTownName(coords)
    local zoneId = Citizen.InvokeNative(0x43AD8FC02B429D33, coords.x, coords.y, coords.z, 1) -- GetNameOfZone
    if zoneId then
        local name = Citizen.InvokeNative(0xD0EF8A959B8A4CB9, zoneId) -- GetStringFromHashKey
        return name
    end
    return nil
end

local function IsValidBuyer(entity)
    if not DoesEntityExist(entity) then return false end
    if IsPedDeadOrDying(entity, true) then return false end
    if IsPedAPlayer(entity) then return false end
    if not IsPedHuman(entity) then return false end
    if soldNPCs[entity] then return false end
    return true
end

-- NPC Walk Away with Package
local function PlayNPCWalkAway(npc)
    SetEntityAsMissionEntity(npc, true, true)
    ClearPedTasks(npc)
    ClearPedSecondaryTask(npc)
    Wait(500)
    
    local modelHash = GetHashKey(Config.Selling.model or 's_drugpackage_02x')
    RequestModel(modelHash)
    local unusedTimeout = 0
    while not HasModelLoaded(modelHash) and unusedTimeout < 50 do
        Wait(10)
        unusedTimeout = unusedTimeout + 1
    end
    
    local package = nil
    if HasModelLoaded(modelHash) then
        local x, y, z = table.unpack(GetEntityCoords(npc))
        package = CreateObject(modelHash, x, y, z + 0.2, true, true, true)
        local righthand = GetEntityBoneIndexByName(npc, "SKEL_R_Hand")
        AttachEntityToEntity(package, npc, righthand, 0.12, 0.0, -0.05, 90.0, 0.0, 0.0, true, true, false, true, 1, true)
    end

    TaskWanderStandard(npc, 10.0, 10)
        
    SetTimeout(10000, function()
        if package and DoesEntityExist(package) then DeleteEntity(package) end
        if DoesEntityExist(npc) then
            ClearPedTasks(npc)
            SetEntityAsMissionEntity(npc, false, true)
            SetPedAsNoLongerNeeded(npc)
        end
    end)
end

-- Shop Proximity Prompts
local SellPromptGroup = GetRandomIntInRange(0, 0xffffff)
local SellContrabandPrompt

local function SetUpSellPrompts()
    SellContrabandPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(SellContrabandPrompt, 0x760A9C6F) -- G key
    UiPromptSetText(SellContrabandPrompt, CreateVarString(10, 'LITERAL_STRING', 'Offer Contraband'))
    UiPromptSetEnabled(SellContrabandPrompt, false)
    UiPromptSetVisible(SellContrabandPrompt, false)
    UiPromptSetHoldMode(SellContrabandPrompt, true)
    UiPromptRegisterEnd(SellContrabandPrompt)
    UiPromptSetGroup(SellContrabandPrompt, SellPromptGroup, 0)
end

local function NegotiateDeal(npc)
    local ped = PlayerPedId()
    
    SetEntityAsMissionEntity(npc, true, true)
    ClearPedTasks(npc)
    TaskTurnPedToFaceEntity(npc, ped, 2000)
    TaskTurnPedToFaceEntity(ped, npc, 2000)
    Wait(500)
    TaskStandStill(npc, -1)
    
    -- Police Alert (chance-based while initiating negotiation)
    if Config.PoliceAlerts and Config.PoliceAlerts.enabled then
        local currentTime = GetGameTimer()
        if (currentTime - lastAlertTime) > (Config.PoliceAlerts.cooldown or 60000) then
            local chance = math.random(1, 100)
            if chance <= Config.PoliceAlerts.chance then
                local coords = GetEntityCoords(ped)
                local area = "Unknown Location"
                for _, city in ipairs(Config.Selling.allowedCities or {}) do
                    if #(coords - city.coords) < city.radius then
                        area = city.name
                        break
                    end
                end
                TriggerServerEvent('devchacha-weed:server:alertLaw', coords, area)
                Notify('A witness reported your suspicious transaction to the law!', 'error')
                lastAlertTime = currentTime
            end
        end
    end
    
    -- Pick a random item from clientWeedItems
    if not clientWeedItems or #clientWeedItems == 0 then
        Notify('No weed/joints left to sell!', 'error')
        ClearPedTasks(npc)
        TaskWanderStandard(npc, 10.0, 10)
        SetEntityAsMissionEntity(npc, false, true)
        SetPedAsNoLongerNeeded(npc)
        isSelling = false
        return
    end
    
    local selectedItem = clientWeedItems[math.random(#clientWeedItems)]
    local maxDemand = math.min(selectedItem.amount, 10)
    local demandAmount = math.random(1, maxDemand)
    
    local priceRange = Config.Selling.buyerPrices[selectedItem.type] or {min = 15, max = 25}
    local basePrice = math.random(priceRange.min, priceRange.max)
    local pricePerUnit = basePrice
    
    local moodRng = math.random(1, 100)
    if moodRng <= 40 then
        pricePerUnit = math.floor(basePrice * 0.30) -- Low ball (30% value)
        if pricePerUnit < 1 then pricePerUnit = 1 end
    elseif moodRng >= 91 then
        pricePerUnit = math.floor(basePrice * 1.50) -- High ball (150% value)
    end
    
    local totalPrice = pricePerUnit * demandAmount
    
    PendingDeal = {
        entity = npc,
        item = selectedItem,
        amount = demandAmount,
        price = totalPrice
    }
    
    -- Open UI Offer
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openSelling',
        label = selectedItem.label,
        amount = demandAmount,
        price = totalPrice
    })
end

-- NUI Callbacks
RegisterNUICallback('sell_accept', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
    
    local deal = PendingDeal
    if not deal or not DoesEntityExist(deal.entity) then
        isSelling = false
        PendingDeal = nil
        return
    end
    
    local ped = PlayerPedId()
    
    -- Request package prop
    local modelHash = 1180245127 -- s_drugpackage_02x
    RequestModel(modelHash)
    local propTimeout = 0
    while not HasModelLoaded(modelHash) and propTimeout < 100 do 
        Wait(10) 
        propTimeout = propTimeout + 1
    end
    
    local prop = nil
    if HasModelLoaded(modelHash) then
        local x, y, z = table.unpack(GetEntityCoords(ped))
        prop = CreateObject(modelHash, x, y, z + 0.2, true, true, false)
        SetEntityCollision(prop, false, true)
        local righthand = GetEntityBoneIndexByName(ped, "SKEL_R_Hand")
        AttachEntityToEntity(prop, ped, righthand, 0.12, 0.0, -0.05, 90.0, 0.0, 0.0, true, true, false, true, 1, true)
    end
    
    -- Request animation
    local animDict = "mech_inventory@crafting@fallbacks"
    local animName = "full_craft_and_stow"
    RequestAnimDict(animDict)
    local animTimeout = 0
    while not HasAnimDictLoaded(animDict) and animTimeout < 50 do
        Wait(10)
        animTimeout = animTimeout + 1
    end
    
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, 8000, 31, 0, false, false, false)
    end
    
    local completed = false
    startProgressBar('Selling contraband...', 8000, function()
        completed = true
        if prop then DeleteEntity(prop) end
        
        soldNPCs[deal.entity] = true
        
        TriggerServerEvent('devchacha-weed:server:sellDynamicItem', deal.item.name, deal.amount, deal.price)
        PlayNPCWalkAway(deal.entity)
        
        -- Force inventory recheck
        checkingInventory = true
        VORPCore.Callback.TriggerAsync('devchacha-weed:server:getWeedInventory', function(items)
            if items and #items > 0 then
                clientWeedItems = items
                hasContraband = true
            else
                clientWeedItems = nil
                hasContraband = false
            end
            checkingInventory = false
            isSelling = false
            PendingDeal = nil
            wasNearAnyNpc = false
        end)
    end)
    
    -- Safety thread to ensure entity cleanup if progress bar fails
    CreateThread(function()
        local timeout = 8500
        while not completed and timeout > 0 do
            Wait(100)
            timeout = timeout - 100
        end
        if not completed then
            if prop then DeleteEntity(prop) end
            isSelling = false
            PendingDeal = nil
            local playerPed = PlayerPedId()
            FreezeEntityPosition(playerPed, false)
            ClearPedTasks(playerPed)
            
            if DoesEntityExist(deal.entity) then
                ClearPedTasks(deal.entity)
                TaskWanderStandard(deal.entity, 10.0, 10)
                SetEntityAsMissionEntity(deal.entity, false, true)
                SetPedAsNoLongerNeeded(deal.entity)
            end
        end
    end)
end)

RegisterNUICallback('sell_decline', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
    
    local deal = PendingDeal
    if deal and DoesEntityExist(deal.entity) then
        soldNPCs[deal.entity] = true
        Notify('You declined the offer.', 'inform')
        
        ClearPedTasks(deal.entity)
        TaskWanderStandard(deal.entity, 10.0, 10)
        SetTimeout(10000, function()
            if DoesEntityExist(deal.entity) then
                ClearPedTasks(deal.entity)
                SetEntityAsMissionEntity(deal.entity, false, true)
                SetPedAsNoLongerNeeded(deal.entity)
            end
        end)
    end
    
    isSelling = false
    PendingDeal = nil
end)

CreateThread(function()
    SetUpSellPrompts()
    
    while true do
        local sleep = 500
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Check if player is in a valid selling city
        local inCity = false
        for _, city in ipairs(Config.Selling.allowedCities or {}) do
            if #(playerCoords - city.coords) < city.radius then
                inCity = true
                break
            end
        end
        
        if inCity then
            -- Scan for nearest civilian NPC
            local peds = GetGamePool("CPed")
            local targetNpc = nil
            local minDist = 3.0 -- Only show prompt when very close (3 meters)
            
            for _, npc in ipairs(peds) do
                if npc ~= playerPed and IsValidBuyer(npc) and not IsPedInAnyVehicle(npc, true) then
                    local npcCoords = GetEntityCoords(npc)
                    local dist = #(playerCoords - npcCoords)
                    if dist < minDist then
                        minDist = dist
                        targetNpc = npc
                    end
                end
            end
            
            if targetNpc then
                sleep = 0
                
                -- Transition from not near to near -> check inventory
                if not wasNearAnyNpc then
                    wasNearAnyNpc = true
                    if not checkingInventory then
                        checkingInventory = true
                        VORPCore.Callback.TriggerAsync('devchacha-weed:server:getWeedInventory', function(availableItems)
                            if availableItems and #availableItems > 0 then
                                clientWeedItems = availableItems
                                hasContraband = true
                            else
                                clientWeedItems = nil
                                hasContraband = false
                            end
                            checkingInventory = false
                        end)
                    end
                end
                
                if hasContraband and not isSelling then
                    UiPromptSetEnabled(SellContrabandPrompt, true)
                    UiPromptSetVisible(SellContrabandPrompt, true)
                    
                    local groupLabel = CreateVarString(10, 'LITERAL_STRING', "Contraband Buyer")
                    UiPromptSetActiveGroupThisFrame(SellPromptGroup, groupLabel, 0, 0, 0, 0)
                    
                    if UiPromptHasHoldModeCompleted(SellContrabandPrompt) then
                        isSelling = true
                        UiPromptSetEnabled(SellContrabandPrompt, false)
                        UiPromptSetVisible(SellContrabandPrompt, false)
                        
                        NegotiateDeal(targetNpc)
                    end
                else
                    UiPromptSetEnabled(SellContrabandPrompt, false)
                    UiPromptSetVisible(SellContrabandPrompt, false)
                end
            else
                wasNearAnyNpc = false
                UiPromptSetEnabled(SellContrabandPrompt, false)
                UiPromptSetVisible(SellContrabandPrompt, false)
            end
        else
            wasNearAnyNpc = false
            UiPromptSetEnabled(SellContrabandPrompt, false)
            UiPromptSetVisible(SellContrabandPrompt, false)
        end
        
        Wait(sleep)
    end
end)

RegisterNetEvent('devchacha-weed:client:policeBlip', function(coords)
    local blip = BlipAddForCoords(1664425300, coords)
    SetBlipSprite(blip, GetHashKey(Config.PoliceAlerts.blip.sprite))
    SetBlipScale(blip, 1.0)
    SetBlipName(blip, "Drug Sale Reported")
    local blipColor = Config.PoliceAlerts.blip.color or 'BLIP_MODIFIER_MP_COLOR_8'
    Citizen.InvokeNative(0x662D364AB21693F3, blip, GetHashKey(blipColor), 1) -- SetBlipModifier
    
    SetTimeout(Config.PoliceAlerts.blip.time, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if SellContrabandPrompt then
            UiPromptSetEnabled(SellContrabandPrompt, false)
            UiPromptSetVisible(SellContrabandPrompt, false)
        end
    end
end)
