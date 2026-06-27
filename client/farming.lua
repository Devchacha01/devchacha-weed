local VORPCore = exports.vorp_core:GetCore()
local progressbar = exports.vorp_progressbar:initiate()
local PlantsData = {} -- All known plants data
local spawnedPlants = {} -- Physically spawned objects
local inPlanting = false

-- Notification helper
local function Notify(text, type)
    TriggerEvent('vorp:TipRight', text, 4000)
end

-- Progress bar helper
local function startProgressBar(label, duration, cb)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    progressbar.start(label, duration, function()
        FreezeEntityPosition(ped, false)
        if cb then cb() end
    end)
end

-- Quick ground check function
local function GetGroundZ(x, y, z)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 20.0, false)
    if found then return groundZ end
    return z
end

-- Model Loader
local function LoadPropModel(modelName)
    local model = GetHashKey(modelName)
    if not HasModelLoaded(model) then
        RequestModel(model)
        local t = 0
        while not HasModelLoaded(model) do Wait(10) t=t+1 end
    end
    return model
end

-- Helper to draw 3D text
local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen then
        SetTextScale(0.40, 0.40)
        SetTextFontForCurrentCommand(1) -- Default RDR2 Serif-like
        SetTextColor(248, 222, 126, 255) -- Vintage Gold
        SetTextDropshadow(4, 0, 0, 0, 255) -- Strong Shadow
        local str = CreateVarString(10, "LITERAL_STRING", text)
        SetTextCentre(1)
        DisplayText(str, _x, _y)
    end
end

local function DespawnPlantObject(plantId)
    if spawnedPlants[plantId] then
        if DoesEntityExist(spawnedPlants[plantId].entity) then
            DeleteEntity(spawnedPlants[plantId].entity)
        end
        spawnedPlants[plantId] = nil
    end
end

local function SpawnPlantObject(plant)
    if spawnedPlants[plant.id] then return end -- Already spawned

    local strainData = Config.Strains[plant.strain]
    if not strainData then return end
    
    local stage = plant.stage or 1
    local modelName = strainData.props['stage' .. stage]
    if not modelName then return end
    
    local model = LoadPropModel(modelName)
    if not HasModelLoaded(model) then 
        print('^1[devchacha-weed] Failed to load model: ' .. tostring(modelName) .. '^7')
        return 
    end
    
    -- Safe Coordinate Extraction
    local pCoords = plant.coords
    local x, y, z
    if type(pCoords) == 'table' then
       x = pCoords.x or pCoords[1]
       y = pCoords.y or pCoords[2]
       z = pCoords.z or pCoords[3]
    elseif type(pCoords) == 'vector3' or type(pCoords) == 'vector4' then
       x, y, z = pCoords.x, pCoords.y, pCoords.z
    end

    if not x or not y or not z then 
        print('^1[devchacha-weed] Invalid coordinates for plant ID: ' .. tostring(plant.id) .. ' - REMOVING LOCAL DATA^7')
        PlantsData[plant.id] = nil -- Self-heal: Remove broken plant from local cache
        return 
    end

    -- Calculate precise ground Z
    local groundZ = GetGroundZ(x, y, z)
    
    -- Create object (Local only is fine for visual prop)
    local obj = CreateObject(model, x, y, groundZ, false, false, false)
    
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityHeading(obj, plant.coords.w or 0.0)
    SetEntityCollision(obj, true, true)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    
    spawnedPlants[plant.id] = { entity = obj }
end

-- Distance Check Loop for spawning models
CreateThread(function()
    while true do
        Wait(1500) -- Check every 1.5 seconds
        if true then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            
            for id, plant in pairs(PlantsData) do
                if plant and plant.coords then
                    local pCoords = plant.coords
                    local x = pCoords.x or pCoords[1]
                    local y = pCoords.y or pCoords[2]
                    local z = pCoords.z or pCoords[3]
                    
                    if x and y and z then
                        local dist = #(coords - vector3(x, y, z))
                        
                        if dist < 50.0 then
                            if not spawnedPlants[id] then
                                SpawnPlantObject(plant)
                            end
                        else
                            if spawnedPlants[id] then
                                DespawnPlantObject(id)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Prompts setup
local InspectPrompt
local PromptGroup = GetRandomIntInRange(0, 0xffffff)

local function SetUpInspectPrompt()
    InspectPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(InspectPrompt, 0x760A9C6F) -- G key
    local str = CreateVarString(10, 'LITERAL_STRING', 'Inspect Plant')
    UiPromptSetText(InspectPrompt, str)
    UiPromptSetEnabled(InspectPrompt, false)
    UiPromptSetVisible(InspectPrompt, false)
    UiPromptSetHoldMode(InspectPrompt, true)
    UiPromptRegisterEnd(InspectPrompt)
    UiPromptSetGroup(InspectPrompt, PromptGroup, 0)
end

-- Prompts loop for plant interaction
CreateThread(function()
    SetUpInspectPrompt()
    while true do
        local sleep = 500
        if true then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local nearPlant = nil
            local minDist = 2.0
            
            for id, plant in pairs(spawnedPlants) do
                local pData = PlantsData[id]
                if pData and pData.coords then
                    local px = pData.coords.x or pData.coords[1]
                    local py = pData.coords.y or pData.coords[2]
                    local pz = pData.coords.z or pData.coords[3]
                    
                    if px and py and pz then
                        local dist = #(coords - vector3(px, py, pz))
                        if dist < minDist then
                            minDist = dist
                            nearPlant = pData
                        end
                    end
                end
            end
            
            if nearPlant then
                sleep = 0
                local strainData = Config.Strains[nearPlant.strain]
                local label = strainData and strainData.label or "Weed"
                if nearPlant.stage == 1 then 
                    label = "Seedling " .. label 
                elseif nearPlant.stage == 2 then 
                    label = "Young " .. label 
                end
                
                local str = CreateVarString(10, 'LITERAL_STRING', "Inspect " .. label)
                UiPromptSetText(InspectPrompt, str)
                UiPromptSetEnabled(InspectPrompt, true)
                UiPromptSetVisible(InspectPrompt, true)
                
                local groupLabel = CreateVarString(10, 'LITERAL_STRING', label)
                UiPromptSetActiveGroupThisFrame(PromptGroup, groupLabel, 0, 0, 0, 0)
                
                if UiPromptHasHoldModeCompleted(InspectPrompt) then
                    local pData = PlantsData[nearPlant.id]
                    if pData then
                        pData.timeRemaining = math.ceil(Config.GrowthTime * (1 - (pData.growth/100)))
                        pData.label = strainData.label
                        pData.fertilized = pData.fertilized or 0
                        
                        print("[devchacha-weed] Opening NUI Plant Menu for ID: " .. tostring(nearPlant.id))
                        SetNuiFocus(true, true)
                        SendNUIMessage({
                            action = 'openPlant',
                            plant = pData
                        })
                        print("[devchacha-weed] SendNUIMessage openPlant dispatched!")
                        Wait(500) -- Prevent double click/spam
                    end
                end
            else
                UiPromptSetEnabled(InspectPrompt, false)
                UiPromptSetVisible(InspectPrompt, false)
            end
        end
        Wait(sleep)
    end
end)

-- NUI Callbacks
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('plantAction', function(data, cb)
    local action = data.action
    local plantId = data.plantId
    
    if action == 'water' then
        local plant = PlantsData[plantId]
        if plant and plant.water >= 100 then
            Notify('Plant is already fully watered!', 'error')
            cb({ success = false })
            return
        end
        
        VORPCore.Callback.TriggerAsync('devchacha-weed:server:hasWaterBucket', function(hasItem)
            if not hasItem then
                Notify('You need a full water bucket!', 'error')
                cb({ success = false })
                return
            end
            
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })

            local ped = PlayerPedId()
            TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_BUCKET_POUR_LOW'), -1, true, 0, 0.0, false)

            startProgressBar('Watering...', 4000, function()
                ClearPedTasksImmediately(ped)
                
                VORPCore.Callback.TriggerAsync('devchacha-weed:server:waterPlant', function(result)
                    if result.success then
                        if PlantsData[plantId] then
                            PlantsData[plantId].water = math.min(100, PlantsData[plantId].water + 50)
                        end
                        if result.usesLeft then
                            Notify('Watered! Uses remaining: ' .. result.usesLeft, 'success')
                        end
                    else
                        Notify(result.msg or 'Failed', 'error')
                    end
                end, plantId)
            end)
        end)
        cb({ success = true })
        
    elseif action == 'fertilize' then
        local plant = PlantsData[plantId]
        if plant then
            if plant.fertilized and plant.fertilized >= 1 then
                Notify('Plant is already fertilized!', 'error')
                cb({ success = false })
                return
            end
            if plant.growth >= 99 then
                Notify('Plant is fully grown, no need to fertilize!', 'error')
                cb({ success = false })
                return
            end
        end
        
        VORPCore.Callback.TriggerAsync('devchacha-weed:server:hasFertilizer', function(hasItem)
            if not hasItem then
                Notify('You need fertilizer!', 'error')
                cb({ success = false })
                return
            end

            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })

            local ped = PlayerPedId()
            TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_FEED_CHICKEN'), -1, true, 0, 0.0, false)

            startProgressBar('Fertilizing...', 4000, function()
                ClearPedTasksImmediately(ped)
                
                VORPCore.Callback.TriggerAsync('devchacha-weed:server:fertilizePlant', function(result)
                    if result.success then
                        Notify('Fertilized! (+10% Growth)', 'success')
                    else
                        Notify(result.msg or 'Need Fertilizer!', 'error')
                    end
                end, plantId)
            end)
        end)
        cb({ success = true })
        
    elseif action == 'destroy' then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        
        local ped = PlayerPedId()
        local plant = PlantsData[plantId]
        
        if not plant then
            Notify('Plant not found', 'error')
            cb({ success = false })
            return
        end
        
        local plantCoords = vector3(plant.coords.x, plant.coords.y, plant.coords.z)
        TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, 0, 0.0, false)
        
        startProgressBar('Setting Fire...', 3000, function()
            ClearPedTasksImmediately(ped)
            local fire = StartScriptFire(plantCoords.x, plantCoords.y, plantCoords.z, 10, false, false, false, 16)
            Wait(3000)
            RemoveScriptFire(fire)
            
            TriggerServerEvent('devchacha-weed:server:deletePlant', plantId, 'destroy')
            Notify('Plant burned to ashes!', 'success')
            cb({ success = true, message = 'Plant destroyed.' })
        end)
        
    elseif action == 'harvest' then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        
        local plant = PlantsData[plantId]
        if plant and plant.growth >= 99 then
            local ped = PlayerPedId()
            TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_FARMER_WEEDING'), -1, true, 0, 0.0, false)
            
            startProgressBar('Harvesting...', 4000, function()
                ClearPedTasksImmediately(ped)
                TriggerServerEvent('devchacha-weed:server:deletePlant', plantId, 'harvest')
                cb({ success = true, message = 'Harvested!' })
            end)
        else
            Notify('Plant not ready!', 'error')
            cb({ success = false, message = 'Plant not ready!' })
        end
    end
end)

RegisterNetEvent('devchacha-weed:client:spawnPlant', function(plant)
    PlantsData[plant.id] = plant
end)

RegisterNetEvent('devchacha-weed:client:updatePlant', function(plant)
    PlantsData[plant.id] = plant
    
    if spawnedPlants[plant.id] then
        local strainData = Config.Strains[plant.strain]
        local currentModel = GetEntityModel(spawnedPlants[plant.id].entity)
        local newModelHash = GetHashKey(strainData.props['stage' .. plant.stage])
        
        if currentModel ~= newModelHash then
            DespawnPlantObject(plant.id)
            SpawnPlantObject(plant)
        end
    end
end)

RegisterNetEvent('devchacha-weed:client:updatePlantsBatch', function(plantsList)
    for _, plant in pairs(plantsList) do
        PlantsData[plant.id] = plant
        
        if spawnedPlants[plant.id] then
            local strainData = Config.Strains[plant.strain]
            local currentModel = GetEntityModel(spawnedPlants[plant.id].entity)
            local newModelHash = GetHashKey(strainData.props['stage' .. plant.stage])
            
            if currentModel ~= newModelHash then
                DespawnPlantObject(plant.id)
                SpawnPlantObject(plant)
            end
        end
    end
end)

RegisterNetEvent('devchacha-weed:client:removePlant', function(plantId)
    PlantsData[plantId] = nil
    DespawnPlantObject(plantId)
end)

RegisterNetEvent('devchacha-weed:client:cleanupPlants', function(validIds)
    for id, _ in pairs(PlantsData) do
        if not validIds[id] then
            PlantsData[id] = nil
            DespawnPlantObject(id)
        end
    end
end)

RegisterNetEvent('devchacha-weed:client:startPlanting', function(strain)
    if inPlanting then return end
    
    local ped = PlayerPedId()
    
    VORPCore.Callback.TriggerAsync('devchacha-weed:server:hasShovel', function(hasShovel)
        if not hasShovel then
            Notify('You need a shovel to plant!', 'error')
            return
        end
        
        local coords = GetEntityCoords(ped)
        local strainData = Config.Strains[strain]
        if not strainData then return end
        
        local modelName = strainData.props.stage3 -- Use largest stage for ghost preview
        local model = LoadPropModel(modelName)
        
        inPlanting = true
        
        local ghost = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
        SetEntityAlpha(ghost, 150, false)
        SetEntityCollision(ghost, false, false)
        local ghostHeading = GetEntityHeading(ped)

        CreateThread(function()
            while inPlanting do
                Wait(0)
                local pCoords = GetEntityCoords(ped)
                local forward = GetEntityForwardVector(ped)
                
                local x, y, z = table.unpack(pCoords + forward * 1.5)
                local groundZ = GetGroundZ(x, y, z)
                
                SetEntityCoords(ghost, x, y, groundZ, 0, 0, 0, false)
                SetEntityHeading(ghost, ghostHeading)
                
                DrawText3D(x, y, z + 1.0, "[WASD] Move | [Q/E] Rotate | [ENTER] Place | [BACKSPACE] Cancel")
                
                if IsControlPressed(0, 0xDE794E3E) then -- Q
                    ghostHeading = ghostHeading + 1.0
                end
                if IsControlPressed(0, 0xCEFD9220) then -- E
                    ghostHeading = ghostHeading - 1.0
                end

                if IsControlJustPressed(0, 0xC7B5340A) then
                    local finalCoords = GetEntityCoords(ghost)
                    local heading = GetEntityHeading(ghost)
                    DeleteEntity(ghost)
                    inPlanting = false
                    
                    local ped = PlayerPedId()
                    TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_FARMER_WEEDING'), -1, true, 0, 0.0, false)
                    
                    startProgressBar('Planting Seed...', 4000, function()
                        ClearPedTasksImmediately(ped)
                        local coordsToSend = { x = finalCoords.x, y = finalCoords.y, z = finalCoords.z, w = heading }
                        TriggerServerEvent('devchacha-weed:server:savePlant', coordsToSend, strain)
                        Notify('Seed planted!', 'success')
                    end)
                    break
                end
                
                if IsControlJustPressed(0, 0x156F7119) then
                    DeleteEntity(ghost)
                    inPlanting = false
                    Notify('Planting cancelled', 'error')
                    break
                end
            end
        end)
    end)
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for id, _ in pairs(spawnedPlants) do
            DespawnPlantObject(id)
        end
    end
end)

-- Handle using fullbucket from inventory
RegisterNetEvent('devchacha-weed:client:useWaterBucket', function()
    Notify('Approach a plant and inspect it to water!', 'inform')
end)

-- Prompts and logic for Water Pumps and Natural Water
local FillBucketPrompt
local PumpPromptGroup = GetRandomIntInRange(0, 0xffffff)

local function SetUpPumpPrompt()
    FillBucketPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(FillBucketPrompt, 0x760A9C6F) -- G key
    local str = CreateVarString(10, 'LITERAL_STRING', 'Fill Bucket')
    UiPromptSetText(FillBucketPrompt, str)
    UiPromptSetEnabled(FillBucketPrompt, false)
    UiPromptSetVisible(FillBucketPrompt, false)
    UiPromptSetHoldMode(FillBucketPrompt, true)
    UiPromptRegisterEnd(FillBucketPrompt)
    UiPromptSetGroup(FillBucketPrompt, PumpPromptGroup, 0)
end

CreateThread(function()
    SetUpPumpPrompt()
    while true do
        local sleep = 1000
        if true then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local nearPump = false
            
            if Config.Pumps then
                for _, modelName in ipairs(Config.Pumps) do
                    local modelHash = GetHashKey(modelName)
                    local pumpObj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.0, modelHash, false, false, false)
                    if DoesEntityExist(pumpObj) then
                        nearPump = true
                        break
                    end
                end
            end
            
            if nearPump then
                sleep = 0
                UiPromptSetEnabled(FillBucketPrompt, true)
                UiPromptSetVisible(FillBucketPrompt, true)
                
                local groupLabel = CreateVarString(10, 'LITERAL_STRING', "Water Pump")
                UiPromptSetActiveGroupThisFrame(PumpPromptGroup, groupLabel, 0, 0, 0, 0)
                
                if UiPromptHasHoldModeCompleted(FillBucketPrompt) then
                    VORPCore.Callback.TriggerAsync('devchacha-weed:server:hasEmptyBucket', function(hasBucket)
                        if hasBucket then
                            TaskStartScenarioInPlaceHash(PlayerPedId(), GetHashKey('WORLD_HUMAN_BUCKET_POUR_LOW'), -1, true, 0, 0.0, false)
                            Wait(4000)
                            ClearPedTasksImmediately(PlayerPedId())
                            TriggerServerEvent('devchacha-weed:server:fillBucket')
                        else
                            Notify('You need an empty bucket!', 'error')
                        end
                    end)
                    Wait(1000)
                end
            else
                UiPromptSetEnabled(FillBucketPrompt, false)
                UiPromptSetVisible(FillBucketPrompt, false)
            end
        end
        Wait(sleep)
    end
end)

-- Natural Water Interaction
CreateThread(function()
    while true do
        local sleep = 1000
        if true then
            local ped = PlayerPedId()
            if IsEntityInWater(ped) and not IsPedInAnyVehicle(ped, true) then
                sleep = 0
                local coords = GetEntityCoords(ped)
                DrawText3D(coords.x, coords.y, coords.z + 1.0, "[ALT] Fill Bucket")
                
                if IsControlJustPressed(0, 0x8AAA0AD4) then -- LEFT ALT key
                    VORPCore.Callback.TriggerAsync('devchacha-weed:server:hasEmptyBucket', function(hasBucket)
                        if hasBucket then
                            TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_BUCKET_POUR_LOW'), -1, true, 0, 0.0, false)
                            Wait(4000)
                            ClearPedTasksImmediately(ped)
                            TriggerServerEvent('devchacha-weed:server:fillBucket')
                        else
                            Notify('You need an empty bucket!', 'error')
                        end
                    end)
                    Wait(1000)
                end
            end
        end
        Wait(sleep)
    end
end)
