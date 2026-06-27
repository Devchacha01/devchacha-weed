local VORPCore = exports.vorp_core:GetCore()
local activeWagon = nil

local function PlayWagonCam(vehicle)
    local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", 1433.0, 258.0, 92.5, -15.0, 0.0, 145.0, 50.0, false, 0)
    PointCamAtEntity(cam, vehicle, 0.0, 0.0, 0.0, true)
    
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 1000, true, true)
    
    Wait(4000)
    
    RenderScriptCams(false, true, 1000, true, true)
    DestroyCam(cam, false)
end

-- Spawn Wagon Event
RegisterNetEvent('devchacha-weed:client:spawnWagon', function()
    if activeWagon and DoesEntityExist(activeWagon) then
        DeleteVehicle(activeWagon)
    end

    local model = GetHashKey('cart05')
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 50 do Wait(100); timeout = timeout + 1 end
    
    if HasModelLoaded(model) then
        local spawnCoords = vector4(1426.9, 252.6, 90.8, 180.0)
        
        local vehicle = CreateVehicle(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
        
        Wait(500)
        SetVehicleOnGroundProperly(vehicle)
        Wait(200)
        
        FreezeEntityPosition(vehicle, true)
        Wait(100)
        FreezeEntityPosition(vehicle, false)
        
        SetModelAsNoLongerNeeded(model)
        
        Entity(vehicle).state:set('isWaterWagon', true, true)
        Entity(vehicle).state:set('waterLevel', 50, true) -- 50 uses
        
        activeWagon = vehicle
        
        PlayWagonCam(vehicle)
        
        TriggerEvent('vorp:TipRight', 'Wagon Rented! 50 Litres water remaining.', 4000)
    else
        TriggerEvent('vorp:TipRight', 'Failed to load wagon model', 4000)
    end
end)

-- Wagon Proximity Prompts
local WagonPromptGroup = GetRandomIntInRange(0, 0xffffff)
local WagonFillPrompt, WagonRefillPrompt

local function SetUpWagonPrompts()
    WagonFillPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(WagonFillPrompt, 0xE30CD707) -- R key
    UiPromptSetText(WagonFillPrompt, CreateVarString(10, 'LITERAL_STRING', 'Fill Bucket'))
    UiPromptSetEnabled(WagonFillPrompt, false)
    UiPromptSetVisible(WagonFillPrompt, false)
    UiPromptSetHoldMode(WagonFillPrompt, true)
    UiPromptRegisterEnd(WagonFillPrompt)
    UiPromptSetGroup(WagonFillPrompt, WagonPromptGroup, 0)

    WagonRefillPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(WagonRefillPrompt, 0xE30CD707) -- R key
    UiPromptSetText(WagonRefillPrompt, CreateVarString(10, 'LITERAL_STRING', 'Refill Tank'))
    UiPromptSetEnabled(WagonRefillPrompt, false)
    UiPromptSetVisible(WagonRefillPrompt, false)
    UiPromptSetHoldMode(WagonRefillPrompt, true)
    UiPromptRegisterEnd(WagonRefillPrompt)
    UiPromptSetGroup(WagonRefillPrompt, WagonPromptGroup, 0)
end

CreateThread(function()
    SetUpWagonPrompts()
    while true do
        local sleep = 500
        if true then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            
            local vehicles = GetGamePool("CVehicle")
            local closestWagon = 0
            local minDist = 4.0
            
            for _, veh in ipairs(vehicles) do
                if DoesEntityExist(veh) and Entity(veh).state.isWaterWagon then
                    local vehCoords = GetEntityCoords(veh)
                    local dist = #(coords - vehCoords)
                    if dist < minDist then
                        minDist = dist
                        closestWagon = veh
                    end
                end
            end
            
            if closestWagon > 0 then
                sleep = 0
                local currentLevel = Entity(closestWagon).state.waterLevel or 0
                local inWater = IsEntityInWater(closestWagon)
                
                UiPromptSetEnabled(WagonFillPrompt, true)
                UiPromptSetVisible(WagonFillPrompt, true)
                
                if inWater then
                    UiPromptSetEnabled(WagonRefillPrompt, true)
                    UiPromptSetVisible(WagonRefillPrompt, true)
                else
                    UiPromptSetEnabled(WagonRefillPrompt, false)
                    UiPromptSetVisible(WagonRefillPrompt, false)
                end
                
                local groupLabel = CreateVarString(10, 'LITERAL_STRING', "Water Wagon (" .. currentLevel .. "L)")
                UiPromptSetActiveGroupThisFrame(WagonPromptGroup, groupLabel, 0, 0, 0, 0)
                
                if UiPromptHasHoldModeCompleted(WagonFillPrompt) then
                    if currentLevel <= 0 then
                        TriggerEvent('vorp:TipRight', 'The water tank is empty!', 4000)
                    else
                        VORPCore.Callback.TriggerAsync('devchacha-weed:server:hasEmptyBucket', function(hasBucket)
                            if hasBucket then
                                TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_BUCKET_POUR_LOW'), -1, true, 0, 0.0, false)
                                Wait(4000)
                                ClearPedTasksImmediately(ped)
                                
                                TriggerServerEvent('devchacha-weed:server:fillBucket')
                                
                                local newLevel = currentLevel - 1
                                Entity(closestWagon).state:set('waterLevel', newLevel, true)
                                TriggerEvent('vorp:TipRight', newLevel .. ' Litres water still left', 4000)
                             else
                                TriggerEvent('vorp:TipRight', 'You need an empty bucket!', 4000)
                             end
                        end)
                    end
                    Wait(1000)
                elseif inWater and UiPromptHasHoldModeCompleted(WagonRefillPrompt) then
                    TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_BUCKET_POUR_LOW'), -1, true, 0, 0.0, false)
                    Wait(5000)
                    ClearPedTasksImmediately(ped)
                    
                    Entity(closestWagon).state:set('waterLevel', 50, true)
                    TriggerEvent('vorp:TipRight', 'Water Tank Refilled (50/50)', 4000)
                    Wait(1000)
                end
            else
                UiPromptSetEnabled(WagonFillPrompt, false)
                UiPromptSetVisible(WagonFillPrompt, false)
                UiPromptSetEnabled(WagonRefillPrompt, false)
                UiPromptSetVisible(WagonRefillPrompt, false)
            end
        end
        Wait(sleep)
    end
end)

-- Cleanup on Resource Stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if activeWagon and DoesEntityExist(activeWagon) then
            DeleteVehicle(activeWagon)
            activeWagon = nil
        end
    end
end)
