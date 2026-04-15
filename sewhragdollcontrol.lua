local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Path to the EventHandler to mute damage
local CommPath = ReplicatedStorage:WaitForChild("Communication")
local EventHandler = require(CommPath:WaitForChild("EventHandler"))

local TraumaPath = ReplicatedStorage:WaitForChild("Resources"):WaitForChild("Client"):WaitForChild("BodyTrauma")
local TraumaModule = require(TraumaPath)

-----------------------------------------------------------
-- DAMAGE MUTE HOOK
-----------------------------------------------------------
-- This intercepts the communication between the trauma module and the server.
-- It allows the physics/ragdoll to happen locally without telling the server to hurt you.
local oldFireServer = EventHandler.FireServer
EventHandler.FireServer = function(self, eventName, ...)
    if eventName == "CharHit" or eventName == "HurtSelf" or eventName == "BlockedTrauma" or eventName == "ResetCharacter" then
        return 
    end
    return oldFireServer(self, eventName, ...)
end
-----------------------------------------------------------

local isManualRagdoll = false
local heartbeatConnection = nil
local stateCheckConnection = nil

-- Bypass all the trauma system's auto-recovery by directly accessing internal state
local function forceRagdollState(enabled)
    -- Access the internal trauma state table (v_u_38 in the decompiled code)
    local traumaState = debug.getupvalue(TraumaModule.Ragdoll, 3) -- Gets v_u_38
    
    if traumaState then
        if enabled then
            traumaState.ragdolled = true
            traumaState.ragdollTimer = 999
            traumaState.noRagdoll = false
            traumaState.debounce = false
            traumaState.ragdollCanceling = false
            traumaState.psuedoRagdollCancel = false
            traumaState.ragdollCancelDebounce = true -- Prevent parry
            traumaState.justGotHit = false
        else
            traumaState.ragdollTimer = -1
            traumaState.ragdolled = false
            traumaState.ragdollCancelDebounce = false
        end
    end
end

local function enforceManualRagdoll()
    if not isManualRagdoll then return end
    
    -- Override the timer every frame to prevent auto-recovery
    TraumaModule.SetRagdollTimer(999)
    
    -- Force the internal state to stay ragdolled
    forceRagdollState(true)
end

local function toggleRagdoll()
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    isManualRagdoll = not isManualRagdoll
    
    if isManualRagdoll then
        -- Clean up old connections
        if heartbeatConnection then heartbeatConnection:Disconnect() end
        if stateCheckConnection then stateCheckConnection:Disconnect() end
        
        -- Force clear all trauma states
        TraumaModule.SetRagdollTimer(-1)
        TraumaModule.IgnoreXaxisCheck(true)
        forceRagdollState(false)
        
        -- Small delay to ensure clean state
        task.wait(0.05)
        
        -- Trigger ragdoll with minimal velocity
        TraumaModule.Ragdoll(Vector3.new(0, 1, 0), false, false)
        
        -- Set up enforcement loop - runs BEFORE physics
        heartbeatConnection = RunService.Heartbeat:Connect(enforceManualRagdoll)
        
        -- Monitor humanoid state changes to prevent auto-recovery
        stateCheckConnection = humanoid.StateChanged:Connect(function(_, newState)
            if not isManualRagdoll then return end
            
            -- Force back to physics state if it tries to recover
            if newState == Enum.HumanoidStateType.GettingUp or 
               newState == Enum.HumanoidStateType.Freefall or
               newState == Enum.HumanoidStateType.Running or
               newState == Enum.HumanoidStateType.Landed then
                task.defer(function()
                    if isManualRagdoll and humanoid then
                        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                    end
                end)
            end
        end)
        
        print("[Manual Ragdoll] Enabled (Damage Muted)")
    else
        -- Clean up connections
        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end
        if stateCheckConnection then
            stateCheckConnection:Disconnect()
            stateCheckConnection = nil
        end
        
        -- Force clean state
        forceRagdollState(false)
        TraumaModule.SetRagdollTimer(-1)
        
        -- Unragdoll
        TraumaModule.Unragdoll(false)
        
        -- Reset humanoid state
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        
        -- Final cleanup after state settles
        task.delay(0.15, function()
            TraumaModule.IgnoreXaxisCheck(false)
            forceRagdollState(false)
        end)
        
        print("[Manual Ragdoll] Disabled")
    end
end

-- Keybind
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.R then
        toggleRagdoll()
    end
end)

-- Safety cleanup on death/respawn
game.Players.LocalPlayer.CharacterRemoving:Connect(function()
    isManualRagdoll = false
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    if stateCheckConnection then stateCheckConnection:Disconnect() end
end)

print("[Manual Ragdoll Debug] Loaded - Press R to toggle ragdoll without damage")
