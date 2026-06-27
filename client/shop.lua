local VORPCore = exports.vorp_core:GetCore()
local npcPed = nil
local npcSpawned = false
local activeMenuOptions = {}

-- Helper to show NUI menu
function ShowCustomMenu(title, options, description)
    activeMenuOptions = options
    local optionsForNui = {}
    for i, opt in ipairs(options) do
        table.insert(optionsForNui, {
            title = opt.title or opt.header,
            description = opt.description or opt.txt,
            image = opt.image,
            price = opt.price,
            btnLabel = opt.btnLabel,
        })
    end
    
    print("[devchacha-weed] ShowCustomMenu called with title: " .. tostring(title))
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openMenu",
        title = title,
        description = description,
        options = optionsForNui
    })
    print("[devchacha-weed] SendNUIMessage openMenu dispatched!")
end

function OpenWagonDialog()
    local shopMenu = {}
    
    table.insert(shopMenu, {
        title = 'Rent Water Wagon',
        description = 'Rent a wagon with a 500L water tank. Refillable in rivers.',
        price = 50,
        image = "img/wagon.png",
        btnLabel = "RENT",
        onSelect = function()
            TriggerServerEvent('devchacha-weed:server:buyItem', 'wagon_rent', 50, 1)
            CloseCustomMenu()
        end
    })

    ShowCustomMenu("Need help farming?", shopMenu, "I can rent you one of my wagons. It has a water tank with enough water for all your plants. Interested?")
end

function CloseCustomMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeMenu" })
end

-- NUI Callbacks
RegisterNUICallback('selectOption', function(data, cb)
    local index = data.index
    print("[devchacha-weed] selectOption callback received with index: " .. tostring(index))
    if activeMenuOptions[index] and activeMenuOptions[index].onSelect then
        activeMenuOptions[index].onSelect()
    end
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('buyItem', function(data, cb)
    if data.item and data.quantity and data.price then
        TriggerServerEvent('devchacha-weed:server:buyItem', data.item, data.price, data.quantity)
    end
    cb('ok')
end)

-- Spawn NPC
local function SpawnNPC()
    if npcSpawned then return end
    
    local model = Config.SeedVendor.model
    local coords = Config.SeedVendor.coords
    
    local modelHash = GetHashKey(model)
    print("[devchacha-weed] Requesting NPC model: " .. tostring(model) .. " (" .. tostring(modelHash) .. ")")
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then 
        print("[devchacha-weed] Failed to load NPC model: " .. tostring(model))
        return 
    end
    print("[devchacha-weed] NPC model loaded successfully!")
    
    local groundZ = coords.z
    local foundGround, groundHeight = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 100.0, false)
    if foundGround then groundZ = groundHeight end
    
    npcPed = CreatePed(modelHash, coords.x, coords.y, groundZ, coords.w, false, false, false, false)
    print("[devchacha-weed] Ped entity created: " .. tostring(npcPed))
    
    timeout = 0
    while not DoesEntityExist(npcPed) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    
    if not DoesEntityExist(npcPed) then return end
    
    Citizen.InvokeNative(0x283978A15512B2FE, npcPed, true) 
    SetEntityNoCollisionEntity(npcPed, PlayerPedId(), false)
    SetEntityCanBeDamaged(npcPed, false)
    SetEntityInvincible(npcPed, true)
    FreezeEntityPosition(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    PlaceEntityOnGroundProperly(npcPed, true)
    
    npcSpawned = true
end

-- Open Shop Menu
function OpenWeedShop()
    local shopMenu = {}
    
    -- Seeds
    for k, v in pairs(Config.Strains) do
        table.insert(shopMenu, {
            title = v.label .. ' Seed',
            description = "Plant to grow " .. v.label,
            price = 5,
            image = "img/" .. v.items.seed .. ".png",
            onSelect = function()
                print("[devchacha-weed] onSelect triggered for seed: " .. tostring(v.items.seed))
                SendNUIMessage({
                    action = "openQuantityModal",
                    item = v.items.seed,
                    label = v.label .. ' Seed',
                    price = 5
                })
            end
        })
    end
    
    -- Tools
    table.insert(shopMenu, {
        title = 'Shovel',
        description = 'For planting',
        price = 10,
        image = "img/" .. Config.ShovelItem .. ".png",
        onSelect = function()
            print("[devchacha-weed] onSelect triggered for Shovel")
            SendNUIMessage({
                action = "openQuantityModal",
                item = Config.ShovelItem,
                label = 'Shovel',
                price = 10
            })
        end
    })

    table.insert(shopMenu, {
        title = 'Rolling Paper',
        description = 'For rolling joints',
        price = 0.5,
        image = "img/rolling_paper.png",
        onSelect = function()
            SendNUIMessage({
                action = "openQuantityModal",
                item = 'rolling_paper',
                label = 'Rolling Paper',
                price = 0.5
            })
        end
    })

    table.insert(shopMenu, {
        title = 'Empty Bucket',
        description = 'For collecting water',
        price = 2,
        image = "img/bucket.png",
        onSelect = function()
            SendNUIMessage({
                action = "openQuantityModal",
                item = Config.EmptyBucketItem,
                label = 'Empty Bucket',
                price = 2
            })
        end
    })

    table.insert(shopMenu, {
        title = 'Smoking Pipe',
        description = 'Reusable pipe - load with bud for 10 puffs',
        price = 25,
        image = "img/smoking_pipe.png",
        onSelect = function()
            SendNUIMessage({
                action = "openQuantityModal",
                item = 'smoking_pipe',
                label = 'Smoking Pipe',
                price = 25
            })
        end
    })

    table.insert(shopMenu, {
        title = 'Match Box',
        description = 'For lighting joints/pipes (20 uses)',
        price = 2,
        image = "img/matches.png",
        onSelect = function()
            SendNUIMessage({
                action = "openQuantityModal",
                item = 'matches',
                label = 'Match Box',
                price = 2
            })
        end
    })

    table.insert(shopMenu, {
        title = 'Fertilizer',
        description = 'Speed growth',
        price = 15,
        image = "img/" .. Config.FertilizerItem .. ".png",
        onSelect = function()
            SendNUIMessage({
                action = "openQuantityModal",
                item = Config.FertilizerItem,
                label = 'Fertilizer',
                price = 15
            })
        end
    })
    
    -- Props
    table.insert(shopMenu, {
        title = 'Wash Bucket',
        description = 'Cleaning',
        price = 50,
        image = "img/wash_bucket.png", 
        onSelect = function()
            SendNUIMessage({
                action = "openQuantityModal",
                item = 'wash_barrel',
                label = 'Wash Bucket',
                price = 50
            })
        end
    })
    
    table.insert(shopMenu, {
        title = 'Drying Rack',
        description = 'For drying and trimming herbs',
        price = 50,
        image = "img/processing_rack.png", 
        onSelect = function()
            SendNUIMessage({
                action = "openQuantityModal",
                item = 'processing_table',
                label = 'Drying Rack',
                price = 50
            })
        end
    })
    
    ShowCustomMenu("The Outlaw's Garden", shopMenu)
end

-- Delete NPC
local function DeleteNPC()
    if npcPed then
        DeletePed(npcPed)
        npcPed = nil
        npcSpawned = false
    end
end

-- NPC Management Loop
CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local shopCoords = vector3(Config.SeedVendor.coords.x, Config.SeedVendor.coords.y, Config.SeedVendor.coords.z)
        local dist = #(playerCoords - shopCoords)
        
        if dist < 50.0 then
            if not npcSpawned then
                SpawnNPC()
            end
        else
            if npcSpawned then
                DeleteNPC()
            end
        end
        
        Wait(2000)
    end
end)

-- Shop Proximity Prompts
local ShopPromptGroup = GetRandomIntInRange(0, 0xffffff)
local ShopBrowsePrompt, ShopWagonPrompt

local function SetUpShopPrompts()
    ShopBrowsePrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(ShopBrowsePrompt, 0x760A9C6F) -- G key
    UiPromptSetText(ShopBrowsePrompt, CreateVarString(10, 'LITERAL_STRING', 'Browse Herbs'))
    UiPromptSetEnabled(ShopBrowsePrompt, false)
    UiPromptSetVisible(ShopBrowsePrompt, false)
    UiPromptSetHoldMode(ShopBrowsePrompt, true)
    UiPromptRegisterEnd(ShopBrowsePrompt)
    UiPromptSetGroup(ShopBrowsePrompt, ShopPromptGroup, 0)

    ShopWagonPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(ShopWagonPrompt, GetHashKey("INPUT_RELOAD")) -- R key
    UiPromptSetText(ShopWagonPrompt, CreateVarString(10, 'LITERAL_STRING', 'Rent Wagon'))
    UiPromptSetEnabled(ShopWagonPrompt, false)
    UiPromptSetVisible(ShopWagonPrompt, false)
    UiPromptSetHoldMode(ShopWagonPrompt, true)
    UiPromptRegisterEnd(ShopWagonPrompt)
    UiPromptSetGroup(ShopWagonPrompt, ShopPromptGroup, 0)
end

CreateThread(function()
    SetUpShopPrompts()
    while true do
        local sleep = 500
        if npcPed and DoesEntityExist(npcPed) then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local npcCoords = GetEntityCoords(npcPed)
            local dist = #(coords - npcCoords)
            
            if dist < 3.0 then
                sleep = 0
                UiPromptSetEnabled(ShopBrowsePrompt, true)
                UiPromptSetVisible(ShopBrowsePrompt, true)
                UiPromptSetEnabled(ShopWagonPrompt, true)
                UiPromptSetVisible(ShopWagonPrompt, true)
                
                local groupLabel = CreateVarString(10, 'LITERAL_STRING', "Exotic Herb Merchant")
                UiPromptSetActiveGroupThisFrame(ShopPromptGroup, groupLabel, 0, 0, 0, 0)
                
                if UiPromptHasHoldModeCompleted(ShopBrowsePrompt) then
                    print("[devchacha-weed] ShopBrowsePrompt completed, opening shop!")
                    OpenWeedShop()
                    Wait(1000)
                elseif UiPromptHasHoldModeCompleted(ShopWagonPrompt) then
                    print("[devchacha-weed] ShopWagonPrompt completed, opening wagon dialog!")
                    OpenWagonDialog()
                    Wait(1000)
                end
            else
                UiPromptSetEnabled(ShopBrowsePrompt, false)
                UiPromptSetVisible(ShopBrowsePrompt, false)
                UiPromptSetEnabled(ShopWagonPrompt, false)
                UiPromptSetVisible(ShopWagonPrompt, false)
            end
        else
            UiPromptSetEnabled(ShopBrowsePrompt, false)
            UiPromptSetVisible(ShopBrowsePrompt, false)
            UiPromptSetEnabled(ShopWagonPrompt, false)
            UiPromptSetVisible(ShopWagonPrompt, false)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DeleteNPC()
    end
end)
