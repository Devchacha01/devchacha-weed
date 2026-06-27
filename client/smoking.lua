local VORPCore = exports.vorp_core:GetCore()

-- Prompt Group
local SmokingGroup = GetRandomIntInRange(0, 0xffffff)

-- Variables
local proppromptdisplayed = false
local PropPrompt = nil
local UsePrompt = nil
local ChangeStance = nil
local isHighActive = false
local highEndTime = 0
local isSmoking = false

-- ============================================================================
-- PROMPT HELPERS
-- ============================================================================

local function DropPrompt()
    CreateThread(function()
        proppromptdisplayed = false
        PropPrompt = UiPromptRegisterBegin()
        UiPromptSetControlAction(PropPrompt, Config.Smoking.dropKey or 0x760A9C6F) -- G key default
        local str = CreateVarString(10, 'LITERAL_STRING', 'Drop')
        UiPromptSetText(PropPrompt, str)
        UiPromptSetEnabled(PropPrompt, false)
        UiPromptSetVisible(PropPrompt, false)
        UiPromptSetHoldMode(PropPrompt, false)
        UiPromptRegisterEnd(PropPrompt)
        UiPromptSetGroup(PropPrompt, SmokingGroup)
    end)
end

local function SmokePrompt()
    CreateThread(function()
        UsePrompt = UiPromptRegisterBegin()
        UiPromptSetControlAction(UsePrompt, Config.Smoking.smokeKey or 0x760A9C6F) -- G key default
        local str = CreateVarString(10, 'LITERAL_STRING', 'Smoke')
        UiPromptSetText(UsePrompt, str)
        UiPromptSetEnabled(UsePrompt, false)
        UiPromptSetVisible(UsePrompt, false)
        UiPromptSetHoldMode(UsePrompt, false)
        UiPromptRegisterEnd(UsePrompt)
        UiPromptSetGroup(UsePrompt, SmokingGroup)
    end)
end

local function StancePrompt()
    CreateThread(function()
        ChangeStance = UiPromptRegisterBegin()
        UiPromptSetControlAction(ChangeStance, Config.Smoking.changeKey or 0x760A9C6F) -- G key default
        local str = CreateVarString(10, 'LITERAL_STRING', 'Change Stance')
        UiPromptSetText(ChangeStance, str)
        UiPromptSetEnabled(ChangeStance, false)
        UiPromptSetVisible(ChangeStance, false)
        UiPromptSetHoldMode(ChangeStance, false)
        UiPromptRegisterEnd(ChangeStance)
        UiPromptSetGroup(ChangeStance, SmokingGroup)
    end)
end

local function ShowPrompts(show)
    if PropPrompt then
        UiPromptSetEnabled(PropPrompt, show)
        UiPromptSetVisible(PropPrompt, show)
    end
    if UsePrompt then
        UiPromptSetEnabled(UsePrompt, show)
        UiPromptSetVisible(UsePrompt, show)
    end
    if ChangeStance then
        UiPromptSetEnabled(ChangeStance, show)
        UiPromptSetVisible(ChangeStance, show)
    end
    proppromptdisplayed = show
end

local function DisplayPromptGroup()
    if proppromptdisplayed then
        local label = CreateVarString(10, 'LITERAL_STRING', 'Smoking')
        UiPromptSetActiveGroupThisFrame(SmokingGroup, label, 0, 0, 0, 0)
    end
end

-- ============================================================================
-- ANIMATION HELPERS
-- ============================================================================

local function Anim(ped, dict, body, duration, flags, introtiming, exittiming)
    RequestAnimDict(dict)
    local timeout = 50
    while not HasAnimDictLoaded(dict) and timeout > 0 do
        timeout = timeout - 1
        Wait(100)
    end
    if timeout <= 0 then
        print('[devchacha-weed] Failed to load animation: ' .. dict)
        return
    end
    
    local dur = duration or -1
    local flag = flags or 1
    local intro = tonumber(introtiming) or 1.0
    local exit = tonumber(exittiming) or 1.0
    TaskPlayAnim(ped, dict, body, intro, exit, dur, flag, 1, false, false, false, 0, true)
end

local function StopAnim(ped, dict, body)
    StopAnimTask(ped, dict, body, 1.0)
end

local function CleanupSmoke()
    ShowPrompts(false)
    isSmoking = false
    local ped = PlayerPedId()
    ClearPedSecondaryTask(ped)
    ClearPedTasks(ped)
end

-- ============================================================================
-- JOINT SMOKING (Uses cigarette-style animations)
-- ============================================================================

RegisterNetEvent('devchacha-weed:client:smokeJoint', function(strainKey)
    if isSmoking then return end
    isSmoking = true
    
    local ped = PlayerPedId()
    local strain = Config.Strains[strainKey]
    if not strain then isSmoking = false return end
    
    -- Setup prompts
    DropPrompt()
    SmokePrompt()
    StancePrompt()
    Wait(100)
    
    local male = IsPedMale(ped)
    local x, y, z = table.unpack(GetEntityCoords(ped, true))
    
    -- Create joint prop (using cigarette model)
    local joint = CreateObject(GetHashKey('P_CIGARETTE01X'), x, y, z + 0.2, true, true, true)
    local righthand = GetEntityBoneIndexByName(ped, "SKEL_R_Finger13")
    local mouth = GetEntityBoneIndexByName(ped, "skel_head")
    
    local stance = "c"
    
    if male then
        -- Male enter animation
        AttachEntityToEntity(joint, ped, mouth, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        Anim(ped, "amb_rest@world_human_smoking@male_c@stand_enter", "enter_back_rf", 5400, 0)
        Wait(1000)
        AttachEntityToEntity(joint, ped, righthand, 0.03, -0.01, 0.0, 0.0, 90.0, 0.0, true, true, false, true, 1, true)
        Wait(1000)
        AttachEntityToEntity(joint, ped, mouth, -0.017, 0.1, -0.01, 0.0, 90.0, -90.0, true, true, false, true, 1, true)
        Wait(3000)
        AttachEntityToEntity(joint, ped, righthand, 0.017, -0.01, -0.01, 0.0, 120.0, 10.0, true, true, false, true, 1, true)
        Wait(1000)
        Anim(ped, "amb_rest@world_human_smoking@male_c@base", "base", -1, 30)
        RemoveAnimDict("amb_rest@world_human_smoking@male_c@stand_enter")
        Wait(1000)
    else
        -- Female enter animation
        AttachEntityToEntity(joint, ped, mouth, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        Anim(ped, "amb_rest@world_human_smoking@female_c@base", "base", -1, 30)
        Wait(1000)
        AttachEntityToEntity(joint, ped, righthand, 0.01, 0.0, 0.01, 0.0, -160.0, -130.0, true, true, false, true, 1, true)
        Wait(2500)
    end
    
    ShowPrompts(true)
    
    -- Main smoking loop
    local baseDict = male and "amb_rest@world_human_smoking@male_c@base" or "amb_rest@world_human_smoking@female_c@base"
    
    while IsEntityPlayingAnim(ped, baseDict, "base", 3) or 
          IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@nervous_stressed@male_b@base", "base", 3) or
          IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@male_d@base", "base", 3) or
          IsEntityPlayingAnim(ped, "amb_wander@code_human_smoking_wander@male_a@base", "base", 3) or
          IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@female_b@base", "base", 3) or
          IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@female_a@base", "base", 3) do
        Wait(5)
        
        -- Display prompt group on screen
        if proppromptdisplayed then
            local label = CreateVarString(10, 'LITERAL_STRING', 'Smoking')
            UiPromptSetActiveGroupThisFrame(SmokingGroup, label, 0, 0, 0, 0)
        end
        
        -- DROP - finish smoking
        if IsControlJustReleased(0, Config.Smoking.dropKey or 0x3B24C470) then
            ShowPrompts(false)
            
            if male then
                ClearPedSecondaryTask(ped)
                Anim(ped, "amb_rest@world_human_smoking@male_a@stand_exit", "exit_back", -1, 1)
                Wait(2800)
            else
                ClearPedSecondaryTask(ped)
                Anim(ped, "amb_rest@world_human_smoking@female_b@trans", "b_trans_fire_stand_a", -1, 1)
                Wait(3800)
            end
            
            DetachEntity(joint, true, true)
            SetEntityVelocity(joint, 0.0, 0.0, -1.0)
            Wait(1500)
            DeleteEntity(joint)
            
            if Config.Smoking.enableHighEffect then
                ApplyHighEffect()
            end
            
            CleanupSmoke()
            break
        end
        
        -- CHANGE STANCE (male only has multiple stances)
        if male and IsControlJustReleased(0, Config.Smoking.changeKey or 0xD51B784F) then
            if stance == "c" then
                Anim(ped, "amb_rest@world_human_smoking@nervous_stressed@male_b@base", "base", -1, 30)
                Wait(1000)
                stance = "b"
            elseif stance == "b" then
                Anim(ped, "amb_rest@world_human_smoking@male_d@base", "base", -1, 30)
                Wait(1000)
                stance = "d"
            elseif stance == "d" then
                Anim(ped, "amb_rest@world_human_smoking@male_d@trans", "d_trans_a", -1, 30)
                Wait(4000)
                Anim(ped, "amb_wander@code_human_smoking_wander@male_a@base", "base", -1, 30, 0)
                stance = "a"
            else
                Anim(ped, "amb_rest@world_human_smoking@male_a@trans", "a_trans_c", -1, 30)
                Wait(4233)
                Anim(ped, "amb_rest@world_human_smoking@male_c@base", "base", -1, 30, 0)
                stance = "c"
            end
        end
        
        -- TAKE A PUFF
        if IsControlJustReleased(0, Config.Smoking.smokeKey or 0x07B8BEAF) then
            if male then
                if stance == "c" then
                    Anim(ped, "amb_rest@world_human_smoking@male_c@idle_a", "idle_a", -1, 30, 0)
                    Wait(8500)
                    Anim(ped, "amb_rest@world_human_smoking@male_c@base", "base", -1, 30, 0)
                elseif stance == "b" then
                    Anim(ped, "amb_rest@world_human_smoking@nervous_stressed@male_b@idle_a", "idle_a", -1, 30, 0)
                    Wait(3199)
                    Anim(ped, "amb_rest@world_human_smoking@nervous_stressed@male_b@base", "base", -1, 30, 0)
                elseif stance == "d" then
                    Anim(ped, "amb_rest@world_human_smoking@male_d@idle_a", "idle_b", -1, 30, 0)
                    Wait(7366)
                    Anim(ped, "amb_rest@world_human_smoking@male_d@base", "base", -1, 30, 0)
                else
                    Anim(ped, "amb_rest@world_human_smoking@male_a@idle_a", "idle_a", -1, 30, 0)
                    Wait(8200)
                    Anim(ped, "amb_wander@code_human_smoking_wander@male_a@base", "base", -1, 30, 0)
                end
            else
                Anim(ped, "amb_rest@world_human_smoking@female_c@idle_a", "idle_a", -1, 30, 0)
                Wait(9566)
                Anim(ped, "amb_rest@world_human_smoking@female_c@base", "base", -1, 30, 0)
            end
            Wait(100)
        end
    end
    
    -- Cleanup
    ShowPrompts(false)
    if DoesEntityExist(joint) then
        DetachEntity(joint, true, true)
        DeleteEntity(joint)
    end
    
    TriggerServerEvent('devchacha-weed:server:finishSmokeJoint', strainKey)
    
    CleanupSmoke()
end)

-- ============================================================================
-- PIPE SMOKING
-- ============================================================================

RegisterNetEvent('devchacha-weed:client:smokePipe', function(strainKey, puffsRemaining)
    if isSmoking then return end
    isSmoking = true
    
    local ped = PlayerPedId()
    local strain = Config.Strains[strainKey]
    if not strain then isSmoking = false return end
    
    -- Setup prompts
    DropPrompt()
    SmokePrompt()
    StancePrompt()
    Wait(100)
    
    local x, y, z = table.unpack(GetEntityCoords(ped, true))
    local righthand = GetEntityBoneIndexByName(ped, "SKEL_R_Finger13")
    
    -- Create pipe prop
    local pipe = CreateObject(GetHashKey('P_PIPE01X'), x, y, z + 0.2, true, true, true)
    AttachEntityToEntity(pipe, ped, righthand, 0.005, -0.045, 0.0, -170.0, 10.0, -15.0, true, true, false, true, 1, true)
    
    -- Enter animation
    Anim(ped, "amb_wander@code_human_smoking_wander@male_b@trans", "nopipe_trans_pipe", -1, 30)
    Wait(9000)
    Anim(ped, "amb_rest@world_human_smoking@male_b@base", "base", -1, 31)
    
    while not IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@male_b@base", "base", 3) do
        Wait(100)
    end
    
    ShowPrompts(true)
    TriggerEvent('vorp:TipRight', puffsRemaining .. ' puffs remaining', 4000)
    
    -- Main smoking loop
    while IsEntityPlayingAnim(ped, "amb_rest@world_human_smoking@male_b@base", "base", 3) do
        Wait(5)
        
        -- Display prompt group on screen
        if proppromptdisplayed then
            local label = CreateVarString(10, 'LITERAL_STRING', 'Pipe Smoking')
            UiPromptSetActiveGroupThisFrame(SmokingGroup, label, 0, 0, 0, 0)
        end
        
        -- DROP - stop smoking and keep pipe
        if IsControlJustReleased(0, Config.Smoking.dropKey or 0x3B24C470) then
            ShowPrompts(false)
            
            Anim(ped, "amb_wander@code_human_smoking_wander@male_b@trans", "pipe_trans_nopipe", -1, 30)
            Wait(6066)
            DeleteEntity(pipe)
            CleanupSmoke()
            break
        end
        
        -- CHANGE STANCE
        if IsControlJustReleased(0, Config.Smoking.changeKey or 0xD51B784F) then
            Anim(ped, "amb_rest@world_human_smoking@pipe@proper@male_d@wip_base", "wip_base", -1, 30)
            Wait(5000)
            Anim(ped, "amb_rest@world_human_smoking@male_b@base", "base", -1, 31)
            Wait(100)
        end
        
        -- TAKE A PUFF
        if IsControlJustReleased(0, Config.Smoking.smokeKey or 0x07B8BEAF) then
            local healthBoost = Config.Smoking.pipeHealthBoost or 5
            local currentHealth = GetEntityHealth(ped)
            local maxHealth = GetEntityMaxHealth(ped)
            SetEntityHealth(ped, math.min(currentHealth + healthBoost, maxHealth))
            
            Anim(ped, "amb_rest@world_human_smoking@male_b@idle_a", "idle_a", -1, 30, 0)
            Wait(22600)
            Anim(ped, "amb_rest@world_human_smoking@male_b@base", "base", -1, 31, 0)
            
            TriggerServerEvent('devchacha-weed:server:finishSmokePipe', strainKey)
            
            if Config.Smoking.enableHighEffect then
                ApplyHighEffect(0.5)
            end
            
            Wait(100)
        end
    end
    
    -- Cleanup
    ShowPrompts(false)
    if DoesEntityExist(pipe) then
        DetachEntity(pipe, true, true)
        DeleteEntity(pipe)
    end
    CleanupSmoke()
    
    -- Cleanup anim dicts
    RemoveAnimDict("amb_wander@code_human_smoking_wander@male_b@trans")
    RemoveAnimDict("amb_rest@world_human_smoking@male_b@base")
    RemoveAnimDict("amb_rest@world_human_smoking@pipe@proper@male_d@wip_base")
    RemoveAnimDict("amb_rest@world_human_smoking@male_b@idle_a")
end)

-- ============================================================================
-- PIPE LOADING MENU
-- ============================================================================

RegisterNetEvent('devchacha-weed:client:openLoadPipeMenu', function()
    -- Query server for available trimmed buds and auto-load pipe
    TriggerServerEvent('devchacha-weed:server:loadPipeAuto')
end)

RegisterNetEvent('devchacha-weed:client:loadPipe', function(strainKey)
    local ped = PlayerPedId()
    
    local progressbar = exports.vorp_progressbar:initiate()
    FreezeEntityPosition(ped, true)
    progressbar.start('Loading pipe...', 2000, function()
        FreezeEntityPosition(ped, false)
        TriggerServerEvent('devchacha-weed:server:finishLoadPipe', strainKey)
    end)
end)

-- ============================================================================
-- HIGH EFFECT
-- ============================================================================

function ApplyHighEffect(intensityMultiplier)
    intensityMultiplier = intensityMultiplier or 1.0
    local intensity = (Config.Smoking.highIntensity or 0.3) * intensityMultiplier
    
    isHighActive = true
    highEndTime = GetGameTimer() + (Config.Smoking.highDuration or 60000)
    
    CreateThread(function()
        AnimpostfxPlay('PlayerDrunk01')
        
        while isHighActive and GetGameTimer() < highEndTime do
            Wait(100)
            ShakeGameplayCam('DRUNK_SHAKE', intensity * 0.3)
        end
        
        AnimpostfxStop('PlayerDrunk01')
        ShakeGameplayCam('', 0.0)
        isHighActive = false
    end)
    
    TriggerEvent('vorp:TipRight', 'You feel relaxed...', 4000)
end

function StopHighEffect()
    isHighActive = false
    highEndTime = 0
    AnimpostfxStop('PlayerDrunk01')
    ShakeGameplayCam('', 0.0)
end

exports('StopHighEffect', StopHighEffect)

-- ============================================================================
-- STAT BOOSTS
-- ============================================================================

RegisterNetEvent('devchacha-weed:client:applySmokingBoost', function(type)
    local ped = PlayerPedId()
    
    local healthBoost, staminaBoost
    if type == 'joint' then
        healthBoost = Config.Smoking.jointHealthBoost or 10
        staminaBoost = Config.Smoking.jointStaminaBoost or 20
    else
        healthBoost = Config.Smoking.pipeHealthBoost or 5
        staminaBoost = Config.Smoking.pipeStaminaBoost or 10
    end
    
    local currentHealth = GetEntityHealth(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(currentHealth + healthBoost, maxHealth))
    
    Citizen.InvokeNative(0x675680D089BFA21F, ped, staminaBoost)
end)

print('^2[devchacha-weed]^0 Enhanced smoking system loaded!')
