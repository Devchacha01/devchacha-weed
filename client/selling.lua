local VORPCore = exports.vorp_core:GetCore()
local progressbar = exports.vorp_progressbar:initiate()
local isSelling = false
local soldNPCs = {}
local PendingDeal = nil
local lastAlertTime = 0

-- Progress bar helper
local function startProgressBar(label, duration, cb)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    progressbar.start(label, duration, function()
        FreezeEntityPosition(ped, false)
        if cb then cb() end
    end)
end

local function Notify(msg, type)
    TriggerEvent('vorp:TipRight', msg, 4000)
end

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    
    RequestAnimDict(dict)
    
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not HasAnimDictLoaded(dict) then
        return false
    end
    
    return true
end

local function nativeGetTownName(coords)
    local zoneId = Citizen.InvokeNative(0x43AD8FC02B429D33, coords.x, coords.y, coords.z, 1) -- GetNameOfZone
    if zoneId then
        local name = Citizen.InvokeNative(0xD0EF8A959B8A4CB9, zoneId) -- GetStringFromHashKey
        return name
    end
    return nil
end

local function PlayPassingAnimation(targetPed)
    local ped = PlayerPedId()
    
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
    
    local animDict = "mech_inventory@crafting@fallbacks"
    local animName = "full_craft_and_stow"
    
    RequestAnimDict(animDict)
    local animTimeout = 0
    while not HasAnimDictLoaded(animDict) and animTimeout < 50 do
        Wait(10)
        animTimeout = animTimeout + 1
    end
    
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, 3000, 31, 0, false, false, false)
    end
    
    local success = false
    startProgressBar('Handing over package...', 3000, function()
        success = true
        if prop then DeleteEntity(prop) end
    end)
    Wait(3100) -- wait for completion
    
    if not success and prop then DeleteEntity(prop) end
    return success
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
    
    local x, y, z = table.unpack(GetEntityCoords(npc))
    local package = CreateObject(modelHash, x, y, z + 0.2, true, true, true)
    local righthand = GetEntityBoneIndexByName(npc, "SKEL_R_Hand")
    AttachEntityToEntity(package, npc, righthand, 0.12, 0.0, -0.05, 90.0, 0.0, 0.0, true, true, false, true, 1, true)

    TaskWanderStandard(npc, 10.0, 10)
        
    SetTimeout(60000, function()
        if DoesEntityExist(package) then DeleteEntity(package) end
        if DoesEntityExist(npc) then
            ClearPedTasks(npc)
            TaskWanderStandard(npc, 10.0, 10)
            SetEntityAsMissionEntity(npc, false, true)
            SetPedAsNoLongerNeeded(npc)
        end
    end)
end

local function TryToSellToNpc(entity)
    if IsPedDeadOrDying(entity, true) or IsPedAPlayer(entity) then return end
    
    -- Town Restriction
    local inCity = false
    for _, city in ipairs(Config.Selling.allowedCities) do
        if #(GetEntityCoords(PlayerPedId()) - city.coords) < city.radius then inCity = true break end
    end
    
    if not inCity then 
        Notify('You must be in a city (Valentine, Rhodes, Saint Denis, Blackwater) to sell.', 'error') 
        return 
    end

    -- Stop NPC and Face Player
    ClearPedTasks(entity)
    TaskTurnPedToFaceEntity(entity, PlayerPedId(), 2000)
    Wait(500)
    TaskStandStill(entity, -1) -- Force them to stand still

    Notify('Negotiating with buyer...', 'inform')
    
    VORPCore.Callback.TriggerAsync('devchacha-weed:server:getWeedInventory', function(availableItems)
        if not availableItems or #availableItems == 0 then
            Notify('You have no weed to sell!', 'error')
            ClearPedTasks(entity)
            TaskWanderStandard(entity, 10.0, 10)
            return
        end
        
        local selectedItem = availableItems[math.random(#availableItems)]
        local maxDemand = math.min(selectedItem.amount, 10)
        local demandAmount = math.random(1, maxDemand)
        
        local priceRange = Config.Selling.buyerPrices[selectedItem.type] or Config.Selling.buyerPrices['joint'] or {min = 15, max = 25}
        local basePrice = math.random(priceRange.min, priceRange.max)
        local pricePerUnit = basePrice
        
        local moodRng = math.random(1, 100)
        
        if moodRng <= 40 then
            pricePerUnit = math.floor(basePrice * 0.30)
            if pricePerUnit < 1 then pricePerUnit = 1 end
        elseif moodRng >= 91 then
            pricePerUnit = math.floor(basePrice * 1.50)
        end
        
        local totalPrice = pricePerUnit * demandAmount
        
        PendingDeal = {
            entity = entity,
            item = selectedItem,
            amount = demandAmount,
            price = totalPrice,
            time = GetGameTimer()
        }
        
        print("[devchacha-weed] Opening NUI Selling for item: " .. tostring(selectedItem.label))
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openSelling',
            label = selectedItem.label,
            amount = demandAmount,
            price = totalPrice
        })
        print("[devchacha-weed] SendNUIMessage openSelling dispatched!")
        
        CreateThread(function()
            local dealTime = PendingDeal.time
            Wait(10000)
            
            if PendingDeal and PendingDeal.time == dealTime then
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'close' })
                
                local npc = PendingDeal.entity
                if DoesEntityExist(npc) then
                    ClearPedTasks(npc)
                    TaskWanderStandard(npc, 10.0, 10)
                end
                
                PendingDeal = nil
                Notify('Buyer lost patience and walked away.', 'error')
            end
        end)
    end)
end

-- NUI Callbacks
RegisterNUICallback('sell_accept', function(data, cb)
    SetNuiFocus(false, false)
    
    local deal = PendingDeal
    if deal and deal.entity then
        Notify('Offer accepted. Handing over goods...', 'success')
        
        if PlayPassingAnimation(deal.entity) then
            soldNPCs[deal.entity] = true
            TriggerServerEvent('devchacha-weed:server:sellDynamicItem', deal.item.name, deal.amount, deal.price)
            PlayNPCWalkAway(deal.entity)
            
            if Config.PoliceAlerts and Config.PoliceAlerts.enabled then
                local currentTime = GetGameTimer()
                if (currentTime - lastAlertTime) > (Config.PoliceAlerts.cooldown or 600000) then
                    local chance = math.random(1, 100)
                    if chance <= Config.PoliceAlerts.chance then
                        local ped = PlayerPedId()
                        local coords = GetEntityCoords(ped)
                        local area = nativeGetTownName(coords) or "Unknown Location"
                        
                        TriggerServerEvent('devchacha-weed:server:alertLaw', coords, area)
                        Notify('A witness reported you to the law!', 'error')
                        
                        lastAlertTime = currentTime
                    end
                end
            end
        else
            Notify('Transaction cancelled or failed.', 'error')
            ClearPedTasks(deal.entity)
            TaskWanderStandard(deal.entity, 10.0, 10)
        end
    end
    
    PendingDeal = nil
    cb('ok')
end)

RegisterNUICallback('sell_decline', function(data, cb)
    SetNuiFocus(false, false)
    
    local deal = PendingDeal
    if deal and deal.entity then
        soldNPCs[deal.entity] = true
        Notify('You declined the offer.', 'inform')
        ClearPedTasks(deal.entity)
        TaskWanderStandard(deal.entity, 10.0, 10)
    end
    
    PendingDeal = nil
    cb('ok')
end)

local function IsValidBuyer(entity)
    if not DoesEntityExist(entity) then return false end
    if IsPedDeadOrDying(entity, true) then return false end
    if IsPedAPlayer(entity) then return false end
    if not IsPedHuman(entity) then return false end
    if soldNPCs[entity] then return false end
    
    return true
end

-- Command: /sellweed
local sellingActive = false

local function StartSellingLoop()
    CreateThread(function()
        while sellingActive do
            local sleep = 5000
            
            if not PendingDeal then
                local ped = PlayerPedId()
                local pCo = GetEntityCoords(ped)
                
                -- Check if still in a valid city
                local inCity = false
                for _, city in ipairs(Config.Selling.allowedCities) do
                    if #(pCo - city.coords) < city.radius then
                        inCity = true
                        break
                    end
                end
                
                if not inCity then
                    Notify('You left the selling zone! Selling stopped.', 'error')
                    sellingActive = false
                    break
                end
                
                -- Verify if player has weed to sell
                local hasWeed = false
                local checkDone = false
                VORPCore.Callback.TriggerAsync('devchacha-weed:server:getWeedInventory', function(availableItems)
                    if availableItems and #availableItems > 0 then
                        hasWeed = true
                    end
                    checkDone = true
                end)
                
                while not checkDone do Wait(10) end
                
                if not hasWeed then
                    Notify('You ran out of weed! Selling stopped.', 'error')
                    sellingActive = false
                    break
                end
                
                -- Scan for a nearby civilian NPC
                local peds = GetGamePool("CPed")
                local targetNpc = nil
                local minDist = 30.0
                
                for _, npc in ipairs(peds) do
                    if npc ~= ped and IsValidBuyer(npc) then
                        local nCo = GetEntityCoords(npc)
                        local dist = #(pCo - nCo)
                        if dist < minDist and dist > 3.0 then
                            if not IsPedInAnyVehicle(npc, true) then
                                minDist = dist
                                targetNpc = npc
                            end
                        end
                    end
                end
                
                if targetNpc then
                    Notify('A potential buyer is walking towards you...', 'inform')
                    SetEntityAsMissionEntity(targetNpc, true, true)
                    ClearPedTasks(targetNpc)
                    TaskGoToEntity(targetNpc, ped, -1, 1.0, 1.0, 0, 0)
                    
                    local arrivalTimeout = 30000 -- 30 seconds
                    local startTimer = GetGameTimer()
                    local arrived = false
                    
                    while sellingActive and DoesEntityExist(targetNpc) and not IsPedDeadOrDying(targetNpc, true) and not arrived do
                        Wait(500)
                        local myCoords = GetEntityCoords(PlayerPedId())
                        local npcCoords = GetEntityCoords(targetNpc)
                        local dist = #(myCoords - npcCoords)
                        
                        if dist < 2.5 then
                            arrived = true
                        elseif (GetGameTimer() - startTimer) > arrivalTimeout then
                            break
                        else
                            -- Keep moving towards player in case player moved
                            TaskGoToEntity(targetNpc, PlayerPedId(), -1, 1.0, 1.0, 0, 0)
                        end
                    end
                    
                    if arrived and sellingActive then
                        TryToSellToNpc(targetNpc)
                        -- Wait for transaction to finish
                        while sellingActive and PendingDeal do
                            Wait(500)
                        end
                    else
                        if DoesEntityExist(targetNpc) then
                            ClearPedTasks(targetNpc)
                            TaskWanderStandard(targetNpc, 10.0, 10)
                            SetEntityAsMissionEntity(targetNpc, false, true)
                            SetPedAsNoLongerNeeded(targetNpc)
                        end
                    end
                else
                    sleep = 5000 -- Wait 5 seconds to look for buyers again
                end
            end
            
            Wait(sleep)
        end
    end)
end

local function ToggleSelling()
    if sellingActive then
        sellingActive = false
        Notify('You stopped selling weed.', 'inform')
        if PendingDeal then
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
            local npc = PendingDeal.entity
            if DoesEntityExist(npc) then
                ClearPedTasks(npc)
                TaskWanderStandard(npc, 10.0, 10)
                SetEntityAsMissionEntity(npc, false, true)
                SetPedAsNoLongerNeeded(npc)
            end
            PendingDeal = nil
        end
    else
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local inCity = false
        for _, city in ipairs(Config.Selling.allowedCities) do
            if #(coords - city.coords) < city.radius then
                inCity = true
                break
            end
        end
        
        if not inCity then
            Notify('You must be in a city (Valentine, Rhodes, Saint Denis, Blackwater) to sell.', 'error')
            return
        end
        
        VORPCore.Callback.TriggerAsync('devchacha-weed:server:getWeedInventory', function(availableItems)
            if not availableItems or #availableItems == 0 then
                Notify('You have no weed to sell!', 'error')
                return
            end
            
            soldNPCs = {} -- Reset sold NPCs list on new session
            sellingActive = true
            Notify('You are now looking for buyers... Stand by.', 'success')
            StartSellingLoop()
        end)
    end
end

RegisterCommand('sellweed', function()
    ToggleSelling()
end, false)

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
