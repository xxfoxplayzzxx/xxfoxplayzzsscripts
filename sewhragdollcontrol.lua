local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TraumaPath = ReplicatedStorage:WaitForChild("Resources"):WaitForChild("Client"):WaitForChild("BodyTrauma")
local TraumaModule = require(TraumaPath)

local isManualRagdoll = false
local loopConnection = nil

-- Clears the module's internal state to prevent the "can't ragdoll twice" bug
local function clearTraumaState()
    TraumaModule.SetRagdollTimer(-1)
    TraumaModule.IgnoreXaxisCheck(true)
end

local function toggleRagdoll()
    isManualRagdoll = not isManualRagdoll
    
    if isManualRagdoll then
        -- Force reset before triggering
        clearTraumaState()
        
        -- Trigger physical ragdoll
        TraumaModule.Ragdoll(Vector3.new(0, 2, 0), false, false)
        
        -- High-priority loop to overwrite game auto-recovery
        if loopConnection then loopConnection:Disconnect() end
        loopConnection = RunService.Heartbeat:Connect(function()
            if isManualRagdoll then
                TraumaModule.SetRagdollTimer(999)
            end
        end)
    else
        -- Kill the loop and force stand-up
        if loopConnection then
            loopConnection:Disconnect()
            loopConnection = nil
        end
        
        TraumaModule.SetRagdollTimer(-1)
        TraumaModule.Unragdoll(false)
        
        -- Small delay reset to ensure the internal 'debounce' clears
        task.delay(0.1, clearTraumaState)
    end
end

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.R then
        toggleRagdoll()
    end
end)
