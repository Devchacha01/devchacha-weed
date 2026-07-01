local VORPCore = exports.vorp_core:GetCore()
local progressbar = exports.vorp_progressbar:initiate()

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

-- Helper to process action
local function ProcessAction(type)
    local duration = Config.ProcessTime[type] or 5000
    local label = ''
    
    if type == 'wash' then 
        label = 'Processing (Wash)' 
    elseif type == 'dry' then 
        label = 'Processing (Dry)' 
    elseif type == 'trim' then 
        label = 'Processing (Trim)' 
    elseif type == 'roll' then 
        label = 'Rolling Joint' 
    end

    VORPCore.Callback.TriggerAsync('devchacha-weed:server:canProcess', function(can, msg)
        if can then
            local toolProp = nil
            local weedProps = {}
            
            if type ~= 'wash' then
                 local wpHash = GetHashKey('prop_weed_05')
                 RequestModel(wpHash)
                 while not HasModelLoaded(wpHash) do Wait(0) end
                 
                 local pCoords = GetEntityCoords(PlayerPedId())
                 local tableHash = GetHashKey(Config.ProcessingProps.dry)
                 local tableObj = GetClosestObjectOfType(pCoords.x, pCoords.y, pCoords.z, 5.0, tableHash, false, false, false)
                 
                 if DoesEntityExist(tableObj) then
                      if type == 'dry' or type == 'trim' then
                          local offsets = {-0.6, 0.0, 0.6}
                          for _, xOff in ipairs(offsets) do
                              local wProp = CreateObject(wpHash, 0, 0, 0, true, true, false)
                              SetEntityCollision(wProp, false, false)
                              AttachEntityToEntity(wProp, tableObj, 0, xOff, 0.0, 2.2, 180.0, 0.0, 0.0, true, true, false, true, 1, true)
                              table.insert(weedProps, wProp)
                          end
                      end
                 end
            end
            
            if type == 'wash' then
                TaskStartScenarioInPlaceHash(PlayerPedId(), GetHashKey('WORLD_HUMAN_BUCKET_POUR_LOW'), -1, true, 0, 0.0, false)
            elseif type == 'dry' then
                TaskStartScenarioInPlaceHash(PlayerPedId(), GetHashKey('WORLD_HUMAN_CLIPBOARD'), -1, true, 0, 0.0, false)
            elseif type == 'trim' then
                 TaskStartScenarioInPlaceHash(PlayerPedId(), GetHashKey('WORLD_HUMAN_STAND_IMPATIENT'), -1, true, 0, 0.0, false)
                 
                 local toolHash = GetHashKey('w_melee_knife01')
                 RequestModel(toolHash)
                 local timeout = 0
                 while not HasModelLoaded(toolHash) and timeout < 50 do 
                     Wait(10) 
                     timeout = timeout + 1
                 end
                 
                 if HasModelLoaded(toolHash) then
                     local ped = PlayerPedId()
                     local boneIndex = GetEntityBoneIndexByName(ped, "SKEL_R_Hand")
                     toolProp = CreateObject(toolHash, 0, 0, 0, true, true, false)
                     SetEntityCollision(toolProp, false, false)
                     AttachEntityToEntity(toolProp, ped, boneIndex, 0.1, 0.05, -0.05, -90.0, 0.0, 0.0, true, true, false, true, 1, true)
                     SetModelAsNoLongerNeeded(toolHash)
                 end
            elseif type == 'roll' then
                local animDict = "mech_inventory@crafting@fallback@base"
                local animName = "base"
                RequestAnimDict(animDict)
                while not HasAnimDictLoaded(animDict) do Wait(10) end
                TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
            end
            
            startProgressBar(label, duration, function()
                TriggerServerEvent('devchacha-weed:server:finishProcess', type)
                
                ClearPedTasksImmediately(PlayerPedId())
                if weedProps then
                    for _, prop in ipairs(weedProps) do
                        if DoesEntityExist(prop) then DeleteObject(prop) end
                    end
                end
                if toolProp and DoesEntityExist(toolProp) then DeleteObject(toolProp) end
            end)
        else
            TriggerEvent('vorp:TipRight', msg or 'Missing required items!', 4000)
        end
    end, { type = type })
end

-- Processing Action Event (triggered from placement.lua targets)
RegisterNetEvent('devchacha-weed:client:processAction', function(type)
    ProcessAction(type)
end)

-- Roll Joint from Inventory (triggered when using trimmed bud)
RegisterNetEvent('devchacha-weed:client:rollJoint', function(strainKey)
    local duration = Config.ProcessTime.roll or 5000
    
    local animDict = "mech_inventory@crafting@fallbacks"
    local animName = "full_craft_and_stow"
    RequestAnimDict(animDict)
    
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 100 do 
        Wait(10) 
        timeout = timeout + 1
    end
    
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, -8.0, -1, 31, 0, false, false, false)
    end
    
    startProgressBar('Rolling Joint...', duration, function()
        TriggerServerEvent('devchacha-weed:server:finishRollJoint', strainKey)
        ClearPedTasksImmediately(PlayerPedId())
    end)
end)
