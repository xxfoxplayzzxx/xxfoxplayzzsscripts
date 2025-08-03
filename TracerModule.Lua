-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

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
    
    local gui = Instance.new("BillboardGui")
    gui.Name = "ESP_"..player.Name
    gui.Size = UDim2.new(4, 0, 6, 0)
    gui.AlwaysOnTop = true
    gui.Enabled = false
    gui.Adornee = nil
    gui.Parent = game:GetService("CoreGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel = 1
    frame.Visible = ESPConfig.Boxes
    frame.Parent = gui
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.2, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, -20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Visible = ESPConfig.Names
    nameLabel.Parent = gui
    
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
    
    local tracer
    if ESPConfig.Tracers then
        tracer = Instance.new("Frame")
        tracer.AnchorPoint = Vector2.new(0.5, 0.5)
        tracer.Size = UDim2.new(0, 200, 0, 2) -- Length will be adjusted in update
        tracer.BackgroundColor3 = Color3.new(1, 1, 1) -- Default color, will be updated
        tracer.BorderSizePixel = 0
        tracer.ZIndex = 10
        tracer.Visible = false
        tracer.Parent = gui
    end
    
    ESPObjects[player] = {
        GUI = gui,
        Frame = frame,
        NameLabel = nameLabel,
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
        return
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        esp.GUI.Enabled = false
        return
    end
    
    -- Calculate distance
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if distance > ESPConfig.MaxDistance then
        esp.GUI.Enabled = false
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
        esp.NameLabel.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
        esp.NameLabel.TextColor3 = color
        esp.NameLabel.Visible = true
    else
        esp.NameLabel.Visible = false
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
        esp.NameLabel.Text = string.format("%s [%dm]", 
            esp.NameLabel.Text, 
            math.floor(distance))
    end
    
    -- Update tracer if enabled
    if esp.Tracer then
        esp.Tracer.BackgroundColor3 = color
        esp.Tracer.Visible = false -- Default to hidden
        
        if ESPConfig.Tracers and ESPConfig.Enabled and LocalPlayer.Character then
            local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local startPos = Camera:WorldToViewportPoint(myRoot.Position)
                local endPos = Camera:WorldToViewportPoint(rootPart.Position)
                
                -- Only draw if both points are on screen
                if startPos.Z > 0 and endPos.Z > 0 then
                    local midpoint = Vector2.new(
                        (startPos.X + endPos.X)/2,
                        (startPos.Y + endPos.Y)/2
                    )
                    local length = math.sqrt(
                        (endPos.X - startPos.X)^2 + 
                        (endPos.Y - startPos.Y)^2
                    )
                    local angle = math.deg(math.atan2(
                        endPos.Y - startPos.Y, 
                        endPos.X - startPos.X
                    ))
                    
                    esp.Tracer.Position = UDim2.new(0, midpoint.X, 0, midpoint.Y)
                    esp.Tracer.Size = UDim2.new(0, length, 0, 2)
                    esp.Tracer.Rotation = angle
                    esp.Tracer.Visible = true
                end
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
                            ESPObjects[player].GUI:Destroy()
                            ESPObjects[player] = nil
                        end
                    end
                end
            end)
        end
    else
        -- Disable all ESP objects
        for _, esp in pairs(ESPObjects) do
            esp.GUI.Enabled = false
            if esp.Tracer then
                esp.Tracer.Visible = false
            end
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
        ESPObjects[player].GUI:Destroy()
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
