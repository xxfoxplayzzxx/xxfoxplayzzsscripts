-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import ESP assets from model
local ESPAssets = game:GetObjects("rbxassetid://118067082961835")[1]
local CustomESPGui = ESPAssets:FindFirstChild("ESPGui")
local CustomTracer = ESPAssets:FindFirstChild("Tracer")

if not CustomESPGui or not CustomTracer then
    warn("Failed to find required ESP components in the model")
end

-- Configuration
local ESPConfig = {
    Enabled = false,
    TeamCheck = true,
    Tracers = true,
    Boxes = true,
    Names = true,
    HealthBars = true,
    Distance = true,
    
    -- Colors
    EnemyColor = Color3.fromRGB(255, 60, 60),
    FriendlyColor = Color3.fromRGB(60, 255, 60),
    NeutralColor = Color3.fromRGB(255, 255, 60),
    
    -- Keybind
    ToggleKey = Enum.KeyCode.F1,
    
    -- Performance
    UpdateRate = 0.1, -- Seconds between updates
    MaxDistance = 1000 -- Max render distance
}

-- ESP Storage
local ESPObjects = {}
local ESPLoopConnection = nil

-- Create ESP components for a player
local function CreateESP(player)
    if ESPObjects[player] then return end -- Prevent duplicates
    
    -- Clone the custom GUI
    local gui = CustomESPGui:Clone()
    gui.Name = "ESP_"..player.Name
    gui.ResetOnSpawn = false
    gui.Enabled = false
    gui.Adornee = nil
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Find or create components
    local header = gui:FindFirstChild("Header") or Instance.new("TextLabel")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0.2, 0)
    header.Position = UDim2.new(0, 0, 0, -20)
    header.BackgroundTransparency = 1
    header.TextScaled = true
    header.Font = Enum.Font.SourceSansBold
    header.Visible = ESPConfig.Names
    header.Parent = gui
    
    -- Add additional ESP components to the custom GUI
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel = 1
    frame.Visible = ESPConfig.Boxes
    frame.Parent = gui
    
    local healthBar = Instance.new("Frame")
    healthBar.Size = UDim2.new(0.8, 0, 0.05, 0)
    healthBar.Position = UDim2.new(0.1, 0, 0.85, 0)
    healthBar.BorderSizePixel = 1
    healthBar.BackgroundColor3 = Color3.new(0, 0, 0)
    healthBar.Visible = ESPConfig.HealthBars
    healthBar.Parent = gui
    
    local healthFill = Instance.new("Frame")
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBar
    
    -- Clone the custom tracer
    local tracer
    if ESPConfig.Tracers then
        tracer = CustomTracer:Clone()
        tracer.Name = "Tracer_"..player.Name
        tracer.Color = ColorSequence.new(ESPConfig.NeutralColor)
        tracer.Visible = false
        tracer.Parent = workspace.CurrentCamera
    end
    
    ESPObjects[player] = {
        GUI = gui,
        Frame = frame,
        Header = header,
        HealthBar = healthBar,
        HealthFill = healthFill,
        Tracer = tracer
    }
end

-- Update ESP appearance
local function UpdateESP(player)
    if not ESPObjects[player] then return end
    
    local esp = ESPObjects[player]
    local character = player.Character
    if not character then
        esp.GUI.Enabled = false
        if esp.Tracer then esp.Tracer.Visible = false end
        return
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        esp.GUI.Enabled = false
        if esp.Tracer then esp.Tracer.Visible = false end
        return
    end
    
    -- Calculate distance
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if distance > ESPConfig.MaxDistance then
        esp.GUI.Enabled = false
        if esp.Tracer then esp.Tracer.Visible = false end
        return
    end
    
    -- Set position and visibility
    esp.GUI.Adornee = rootPart
    esp.GUI.Enabled = ESPConfig.Enabled
    
    -- Set colors based on team
    local color
    if ESPConfig.TeamCheck and player.Team and LocalPlayer.Team then
        color = player.Team == LocalPlayer.Team and ESPConfig.FriendlyColor or ESPConfig.EnemyColor
    else
        color = ESPConfig.NeutralColor
    end
    
    -- Update visuals
    if ESPConfig.Boxes then
        esp.Frame.BackgroundColor3 = color
        esp.Frame.BorderColor3 = color:lerp(Color3.new(0,0,0), 0.5)
        esp.Frame.Visible = true
    else
        esp.Frame.Visible = false
    end
    
    if ESPConfig.Names then
        esp.Header.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
        esp.Header.TextColor3 = color
        esp.Header.Visible = true
    else
        esp.Header.Visible = false
    end
    
    if ESPConfig.HealthBars and humanoid then
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        esp.HealthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
        esp.HealthFill.BackgroundColor3 = Color3.fromRGB(
            255 * (1 - healthPercent),
            255 * healthPercent,
            0
        )
        esp.HealthBar.Visible = true
    else
        esp.HealthBar.Visible = false
    end
    
    if ESPConfig.Distance then
        esp.Header.Text = string.format("%s [%dm]", 
            esp.Header.Text, 
            math.floor(distance))
    end
    
    -- Update custom tracer if enabled
    if esp.Tracer then
        esp.Tracer.Color = ColorSequence.new(color)
        esp.Tracer.Visible = false -- Default to hidden
        
        if ESPConfig.Tracers and ESPConfig.Enabled and LocalPlayer.Character then
            local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                -- Set tracer attachments
                local myAttachment = myRoot:FindFirstChild("RootAttachment") or Instance.new("Attachment")
                myAttachment.Name = "RootAttachment"
                myAttachment.Parent = myRoot
                
                local theirAttachment = rootPart:FindFirstChild("RootAttachment") or Instance.new("Attachment")
                theirAttachment.Name = "RootAttachment"
                theirAttachment.Parent = rootPart
                
                esp.Tracer.Attachment0 = myAttachment
                esp.Tracer.Attachment1 = theirAttachment
                esp.Tracer.Visible = true
            end
        end
    end
end

-- Toggle ESP system
local function ToggleESP()
    ESPConfig.Enabled = not ESPConfig.Enabled
    
    if ESPConfig.Enabled then
        -- Create ESP for all players if not already existing
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreateESP(player)
            end
        end
        
        -- Start update loop if not already running
        if not ESPLoopConnection then
            ESPLoopConnection = RunService.Heartbeat:Connect(function()
                for player, _ in pairs(ESPObjects) do
                    if player and player.Parent then -- Check if player still exists
                        UpdateESP(player)
                    else
                        -- Clean up if player left
                        if ESPObjects[player] then
                            if ESPObjects[player].GUI then ESPObjects[player].GUI:Destroy() end
                            if ESPObjects[player].Tracer then ESPObjects[player].Tracer:Destroy() end
                            ESPObjects[player] = nil
                        end
                    end
                end
            end)
        end
    else
        -- Disable all ESP objects
        for _, esp in pairs(ESPObjects) do
            if esp.GUI then esp.GUI.Enabled = false end
            if esp.Tracer then esp.Tracer.Visible = false end
        end
    end
end

-- Keybind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == ESPConfig.ToggleKey then
        ToggleESP()
    end
end)

-- Player handlers
local function PlayerAdded(player)
    if player ~= LocalPlayer then
        CreateESP(player)
        if ESPConfig.Enabled then
            UpdateESP(player)
        end
    end
end

local function PlayerRemoving(player)
    if ESPObjects[player] then
        if ESPObjects[player].GUI then ESPObjects[player].GUI:Destroy() end
        if ESPObjects[player].Tracer then ESPObjects[player].Tracer:Destroy() end
        ESPObjects[player] = nil
    end
end

-- Initialization
local function Init()
    -- Wait for character
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    
    -- Set up player handlers
    Players.PlayerAdded:Connect(PlayerAdded)
    Players.PlayerRemoving:Connect(PlayerRemoving)
    
    -- Create ESP for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        PlayerAdded(player)
    end
    
    -- Start with ESP off
    ESPConfig.Enabled = false
end

Init()
