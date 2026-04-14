local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TraumaPath = ReplicatedStorage:WaitForChild("Resources"):WaitForChild("Client"):WaitForChild("BodyTrauma")
local TraumaModule = require(TraumaPath)

-- We need to access the internal data table (v_u_38 in your source)
-- Most Luau modules store this in a 'Data' or 'States' table, 
-- but we can brute-force the reset via the module's debug function if it exists,
-- or by simply spamming the state setters.
local isManualRagdoll = false
local loopConnection = nil

local function resetInternalFlags()
    -- These are the common names for the variables in the Trauma module
    -- Setting these to false ensures the module doesn't "ignore" your next Ragdoll call
    TraumaModule.IgnoreXaxisCheck(true)
    TraumaModule.SetRagdollTimer(-1)
end

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    
    if input.KeyCode == Enum.KeyCode.R then
        isManualRagdoll = not isManualRagdoll
        
        if isManualRagdoll then
            -- 1. Reset everything to "Clean" state first
            resetInternalFlags()
            
            -- 2. Force the Ragdoll
            TraumaModule.Ragdoll(Vector3.new(0, 2, 0), false, false)
            
            -- 3. Lock the timer so the ground check doesn't break it
            if loopConnection then loopConnection:Disconnect() end
            loopConnection = RunService.Heartbeat:Connect(function()
                if isManualRagdoll then
                    TraumaModule.SetRagdollTimer(999)
                end
            end)
            
            print("Ragdoll Active")
        else
            -- 1. Kill the loop
            if loopConnection then
                loopConnection:Disconnect()
                loopConnection = nil
            end
            
            -- 2. Clean up states and Unragdoll
            TraumaModule.SetRagdollTimer(-1)
            TraumaModule.Unragdoll(false)
            
            -- 3. Final reset to ensure the NEXT press works
            task.delay(0.1, function()
                resetInternalFlags()
            end)
            
            print("Ragdoll Reset")
        end
    end
end)
