local VORPCore = exports.vorp_core:GetCore()
local inPlacing = false
local placedObjects = {} -- Track placed objects for cleanup

local function DrawPlacementHelp(x, y, z)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFontForCurrentCommand(1)
        SetTextColor(255, 255, 255, 215)
        local str = CreateVarString(10, "LITERAL_STRING", "[WASD] Move | [Q/E] Rotate | [ENTER] Place | [BACKSPACE] Cancel")
        SetTextCentre(1)
        DisplayText(str, _x, _y)
    end
end

-- Placed Props Prompts
local PlacedPromptGroup = GetRandomIntInRange(0, 0xffffff)
local WashPrompt, DryPrompt, TrimPrompt, PickUpPrompt

local function SetUpPlacedPrompts()
    WashPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(WashPrompt, 0x760A9C6F) -- G key
    UiPromptSetText(WashPrompt, CreateVarString(10, 'LITERAL_STRING', 'Wash Weed'))
    UiPromptSetEnabled(WashPrompt, false)
    UiPromptSetVisible(WashPrompt, false)
    UiPromptSetHoldMode(WashPrompt, true)
    UiPromptRegisterEnd(WashPrompt)
    UiPromptSetGroup(WashPrompt, PlacedPromptGroup, 0)

    DryPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(DryPrompt, 0x760A9C6F) -- G key
    UiPromptSetText(DryPrompt, CreateVarString(10, 'LITERAL_STRING', 'Dry Weed'))
    UiPromptSetEnabled(DryPrompt, false)
    UiPromptSetVisible(DryPrompt, false)
    UiPromptSetHoldMode(DryPrompt, true)
    UiPromptRegisterEnd(DryPrompt)
    UiPromptSetGroup(DryPrompt, PlacedPromptGroup, 0)

    TrimPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(TrimPrompt, 0x760A9C6F) -- G key
    UiPromptSetText(TrimPrompt, CreateVarString(10, 'LITERAL_STRING', 'Trim Weed'))
    UiPromptSetEnabled(TrimPrompt, false)
    UiPromptSetVisible(TrimPrompt, false)
    UiPromptSetHoldMode(TrimPrompt, true)
    UiPromptRegisterEnd(TrimPrompt)
    UiPromptSetGroup(TrimPrompt, PlacedPromptGroup, 0)

    PickUpPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(PickUpPrompt, GetHashKey("INPUT_RELOAD")) -- R key
    UiPromptSetText(PickUpPrompt, CreateVarString(10, 'LITERAL_STRING', 'Pick Up'))
    UiPromptSetEnabled(PickUpPrompt, false)
    UiPromptSetVisible(PickUpPrompt, false)
    UiPromptSetHoldMode(PickUpPrompt, true)
    UiPromptRegisterEnd(PickUpPrompt)
    UiPromptSetGroup(PickUpPrompt, PlacedPromptGroup, 0)
end

CreateThread(function()
    SetUpPlacedPrompts()
    while true do
        local sleep = 500
        if true then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local nearObj = nil
            local minDist = 2.0
            local nearIndex = nil
            
            for i, pData in ipairs(placedObjects) do
                if pData and DoesEntityExist(pData.entity) then
                    local objCoords = GetEntityCoords(pData.entity)
                    local dist = #(coords - objCoords)
                    if dist < minDist then
                        minDist = dist
                        nearObj = pData
                        nearIndex = i
                    end
                end
            end
            
            if nearObj then
                sleep = 0
                local propLabel = nearObj.type == 'wash_barrel' and "Wash Bucket" or "Processing Rack"
                local groupLabel = CreateVarString(10, 'LITERAL_STRING', propLabel)
                
                UiPromptSetEnabled(PickUpPrompt, true)
                UiPromptSetVisible(PickUpPrompt, true)
                
                if nearObj.type == 'wash_barrel' then
                    UiPromptSetEnabled(WashPrompt, true)
                    UiPromptSetVisible(WashPrompt, true)
                    UiPromptSetEnabled(DryPrompt, false)
                    UiPromptSetVisible(DryPrompt, false)
                    UiPromptSetEnabled(TrimPrompt, false)
                    UiPromptSetVisible(TrimPrompt, false)
                else
                    UiPromptSetEnabled(WashPrompt, false)
                    UiPromptSetVisible(WashPrompt, false)
                    UiPromptSetEnabled(DryPrompt, true)
                    UiPromptSetVisible(DryPrompt, true)
                    UiPromptSetEnabled(TrimPrompt, true)
                    UiPromptSetVisible(TrimPrompt, true)
                end
                
                UiPromptSetActiveGroupThisFrame(PlacedPromptGroup, groupLabel, 0, 0, 0, 0)
                
                if nearObj.type == 'wash_barrel' and UiPromptHasHoldModeCompleted(WashPrompt) then
                    TriggerEvent('devchacha-weed:client:processAction', 'wash')
                    Wait(1000)
                end
                if nearObj.type == 'processing_table' and UiPromptHasHoldModeCompleted(DryPrompt) then
                    TriggerEvent('devchacha-weed:client:processAction', 'dry')
                    Wait(1000)
                end
                if nearObj.type == 'processing_table' and UiPromptHasHoldModeCompleted(TrimPrompt) then
                    TriggerEvent('devchacha-weed:client:processAction', 'trim')
                    Wait(1000)
                end
                if UiPromptHasHoldModeCompleted(PickUpPrompt) then
                    local entity = nearObj.entity
                    DeleteObject(entity)
                    table.remove(placedObjects, nearIndex)
                    TriggerServerEvent('devchacha-weed:server:givePlaceable', nearObj.type)
                    TriggerEvent('vorp:TipRight', 'Picked up!', 4000)
                    Wait(1000)
                end
            else
                UiPromptSetEnabled(WashPrompt, false)
                UiPromptSetVisible(WashPrompt, false)
                UiPromptSetEnabled(DryPrompt, false)
                UiPromptSetVisible(DryPrompt, false)
                UiPromptSetEnabled(TrimPrompt, false)
                UiPromptSetVisible(TrimPrompt, false)
                UiPromptSetEnabled(PickUpPrompt, false)
                UiPromptSetVisible(PickUpPrompt, false)
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('devchacha-weed:client:startPlacing', function(type)
    if inPlacing then return end
    
    local propData = Config.PlaceableProps[type]
    if not propData then return end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local model = GetHashKey(propData.model)
    
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do 
        Wait(50) 
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(model) then
        TriggerEvent('vorp:TipRight', 'Failed to load model', 4000)
        return
    end
    
    inPlacing = true
    
    -- Create Ghost
    local forward = GetEntityForwardVector(ped)
    local spawnCoords = coords + forward * 2.0
    local ghost = CreateObject(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, true, false)
    local ghostHeading = GetEntityHeading(ped)
    
    SetEntityAlpha(ghost, 200, false)
    SetEntityCollision(ghost, false, false)
    PlaceObjectOnGroundProperly(ghost)
    
    CreateThread(function()
        while inPlacing do
            Wait(0)
            local pCoords = GetEntityCoords(ped)
            local pForward = GetEntityForwardVector(ped)
            
            local newCoords = pCoords + pForward * 2.0
            
            SetEntityCoords(ghost, newCoords.x, newCoords.y, newCoords.z, false, false, false, false)
            SetEntityHeading(ghost, ghostHeading)
            PlaceObjectOnGroundProperly(ghost)
            
            DrawPlacementHelp(newCoords.x, newCoords.y, newCoords.z + 1.0)
            
            if IsControlPressed(0, 0xDE794E3E) then -- Q
                ghostHeading = ghostHeading + 1.0
            end
            if IsControlPressed(0, 0xCEFD9220) then -- E
                ghostHeading = ghostHeading - 1.0
            end
            
            -- ENTER to place
            if IsControlJustPressed(0, 0xC7B5340A) then
                local finalCoords = GetEntityCoords(ghost)
                local finalHeading = GetEntityHeading(ghost)
                DeleteObject(ghost)
                
                -- Spawn Real Object
                local obj = CreateObject(model, finalCoords.x, finalCoords.y, finalCoords.z, true, true, false)
                SetEntityAsMissionEntity(obj, true, true)
                SetEntityHeading(obj, finalHeading)
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                SetEntityCollision(obj, true, true)
                
                -- Track the object
                table.insert(placedObjects, { entity = obj, type = type })
                
                -- Remove Item
                TriggerServerEvent('devchacha-weed:server:removeItem', type, 1)
                TriggerEvent('vorp:TipRight', propData.label .. ' placed!', 4000)
                
                inPlacing = false
                break
            end
            
            -- Backspace to cancel
            if IsControlJustPressed(0, 0x156F7119) then
                DeleteObject(ghost)
                TriggerEvent('vorp:TipRight', 'Placement cancelled', 4000)
                inPlacing = false
                break
            end
        end
    end)
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for _, data in ipairs(placedObjects) do
            if DoesEntityExist(data.entity) then
                DeleteObject(data.entity)
            end
        end
    end
end)
