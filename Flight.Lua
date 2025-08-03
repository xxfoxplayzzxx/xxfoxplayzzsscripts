local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local currentCharacter = nil

-- Movement vars
local directions = {
    Forward = false,
    Backward = false,
    Left = false,
    Right = false,
    Up = false,
    Down = false,
}

local maxSpeed = 3
local speedIncrement = maxSpeed / 25
local currentSpeed = 0
local flying = false -- Default: OFF

-- Cleanupable connections
local inputBeganConn, inputEndedConn, steppedConn, preRenderConn
local bodyGyro, alignPos, humanoid, hrp

local function disconnectAll()
    if inputBeganConn then inputBeganConn:Disconnect() inputBeganConn = nil end
    if inputEndedConn then inputEndedConn:Disconnect() inputEndedConn = nil end
    if steppedConn then steppedConn:Disconnect() steppedConn = nil end
    if preRenderConn then preRenderConn:Disconnect() preRenderConn = nil end
end

local function alreadyHasFlightParts(part)
    return part:FindFirstChild("ADONIS_FLIGHT_POSITION") and part:FindFirstChild("ADONIS_FLIGHT_GYRO_ATTACHMENT")
end

local function loadFlightAssets(hrp)
    if alreadyHasFlightParts(hrp) then return true end

    local assetId = 116894377414956
    local success, asset = pcall(function()
        return game:GetObjects("rbxassetid://"..assetId)[1]
    end)

    if success and asset then
        asset.Parent = hrp

        if asset:IsA("Model") then
            for _, obj in ipairs(asset:GetChildren()) do
                if not obj:IsA("LocalScript") then
                    obj.Parent = hrp
                end
            end
            asset:Destroy()
        end
        return true
    else
        warn("Failed to load flight assets")
        return false
    end
end

local function toggleFlight()
    flying = not flying
    humanoid.PlatformStand = flying

    if flying then
        alignPos.Position = hrp.Position -- Reset position when enabling
        alignPos.Enabled = true
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    else
        alignPos.Enabled = false
        bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
        currentSpeed = 0
    end
end

local function setupFlight(character)
    if currentCharacter == character then return end
    currentCharacter = character

    character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            currentCharacter = nil
            disconnectAll()
        end
    end)

    hrp = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")

    loadFlightAssets(hrp)
    alignPos = hrp:WaitForChild("ADONIS_FLIGHT_POSITION")
    alignPos.Position = hrp.Position
    alignPos.Enabled = false -- Default: OFF

    local existingGyro = hrp:FindFirstChild("ADONIS_FLIGHT_GYRO")
    if existingGyro then existingGyro:Destroy() end

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "ADONIS_FLIGHT_GYRO"
    bodyGyro.P = 3000
    bodyGyro.MaxTorque = Vector3.new(0, 0, 0) -- Default: OFF
    bodyGyro.Parent = hrp

    -- Initial state (flight OFF by default)
    flying = false
    humanoid.PlatformStand = false

    -- INPUTS
    inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        if input.KeyCode == Enum.KeyCode.W then directions.Forward = true
        elseif input.KeyCode == Enum.KeyCode.S then directions.Backward = true
        elseif input.KeyCode == Enum.KeyCode.A then directions.Left = true
        elseif input.KeyCode == Enum.KeyCode.D then directions.Right = true
        elseif input.KeyCode == Enum.KeyCode.Space then directions.Up = true
        elseif input.KeyCode == Enum.KeyCode.Q then directions.Down = true
        elseif input.KeyCode == Enum.KeyCode.R then
            toggleFlight()
        end
    end)

    inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        if input.KeyCode == Enum.KeyCode.W then directions.Forward = false
        elseif input.KeyCode == Enum.KeyCode.S then directions.Backward = false
        elseif input.KeyCode == Enum.KeyCode.A then directions.Left = false
        elseif input.KeyCode == Enum.KeyCode.D then directions.Right = false
        elseif input.KeyCode == Enum.KeyCode.Space then directions.Up = false
        elseif input.KeyCode == Enum.KeyCode.Q then directions.Down = false
        end
    end)

    -- Movement & rotation
    preRenderConn = RunService.PreRender:Connect(function()
        if not flying then
            bodyGyro.CFrame = hrp.CFrame
            return
        end

        local cam = workspace.CurrentCamera
        local velocity = Vector3.new()

        if not (directions.Forward or directions.Backward or directions.Up or directions.Down or directions.Left or directions.Right) then
            currentSpeed = 0
        else
            currentSpeed = math.min(currentSpeed + speedIncrement, maxSpeed)
        end

        if directions.Up then velocity += Vector3.new(0, currentSpeed, 0) end
        if directions.Down then velocity += Vector3.new(0, -currentSpeed, 0) end
        if directions.Forward then velocity += cam.CFrame.LookVector * currentSpeed end
        if directions.Backward then velocity -= cam.CFrame.LookVector * currentSpeed end
        if directions.Left then velocity -= cam.CFrame.RightVector * currentSpeed end
        if directions.Right then velocity += cam.CFrame.RightVector * currentSpeed end

        alignPos.Position += velocity

        local pos = hrp.Position
        bodyGyro.CFrame = CFrame.new(pos, pos + cam.CFrame.LookVector)
    end)
end

-- Connect setup
player.CharacterAdded:Connect(setupFlight)
if player.Character then
    setupFlight(player.Character)
end
