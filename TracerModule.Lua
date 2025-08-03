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

-- Create ESP components for a player
local function CreateESP(player)
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
    frame.Parent = gui
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.2, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, -20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Parent = gui
    
    local healthBar = Instance.new("Frame")
    healthBar.Size = UDim2.new(0.8, 0, 0.05, 0)
    healthBar.Position = UDim2.new(0.1, 0, 0.85, 0)
    healthBar.BorderSizePixel = 1
    healthBar.BackgroundColor3 = Color3.new(0, 0, 0)
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
    tracer.Size = UDim2.new(0, 2, 0, 2) -- Small dot instead of stretched cube
    tracer.BackgroundColor3 = color -- Use player color
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
    
    local character = player.Character
    if not character then
        ESPObjects[player].GUI.Enabled = false
        return
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        ESPObjects[player].GUI.Enabled = false
        return
    end
    
    -- Calculate distance
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if distance > ESPConfig.MaxDistance then
        ESPObjects[player].GUI.Enabled = false
        return
    end
    
    -- Set position and visibility
    ESPObjects[player].GUI.Adornee = rootPart
    ESPObjects[player].GUI.Enabled = true
    
    -- Set colors based on team
    local color
    if ESPConfig.TeamCheck and player.Team and LocalPlayer.Team then
        color = player.Team == LocalPlayer.Team and ESPConfig.FriendlyColor or ESPConfig.EnemyColor
    else
        color = ESPConfig.NeutralColor
    end
    
    -- Update visuals
    if ESPConfig.Boxes then
        ESPObjects[player].Frame.BackgroundColor3 = color
        ESPObjects[player].Frame.BorderColor3 = color:lerp(Color3.new(0,0,0), 0.5)
        ESPObjects[player].Frame.Visible = true
    else
        ESPObjects[player].Frame.Visible = false
    end
    
    if ESPConfig.Names then
        ESPObjects[player].NameLabel.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
        ESPObjects[player].NameLabel.TextColor3 = color
        ESPObjects[player].NameLabel.Visible = true
    else
        ESPObjects[player].NameLabel.Visible = false
    end
    
    if ESPConfig.HealthBars and humanoid then
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        ESPObjects[player].HealthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
        ESPObjects[player].HealthFill.BackgroundColor3 = Color3.fromRGB(
            255 * (1 - healthPercent),
            255 * healthPercent,
            0
        )
        ESPObjects[player].HealthBar.Visible = true
    else
        ESPObjects[player].HealthBar.Visible = false
    end
    
    if ESPConfig.Distance then
        ESPObjects[player].NameLabel.Text = string.format("%s [%dm]", 
            ESPObjects[player].NameLabel.Text, 
            math.floor(distance))
    end
    
    -- Update tracer if enabled
    if ESPObjects[player].Tracer then
    ESPObjects[player].Tracer.BackgroundColor3 = color
    ESPObjects[player].Tracer.Visible = ESPConfig.Tracers and ESPConfig.Enabled
    
    if ESPConfig.Tracers and ESPConfig.Enabled 
       and LocalPlayer.Character 
       and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        
        local startPos = Camera:WorldToViewportPoint(LocalPlayer.Character.HumanoidRootPart.Position)
        local endPos = Camera:WorldToViewportPoint(rootPart.Position)
        
        -- Only draw if both points are on screen
        if startPos.Z > 0 and endPos.Z > 0 then
            ESPObjects[player].Tracer.Position = UDim2.new(
                0, (startPos.X + endPos.X)/2,
                0, (startPos.Y + endPos.Y)/2
            )
            local length = math.sqrt(
                math.pow(endPos.X - startPos.X, 2) + 
                math.pow(endPos.Y - startPos.Y, 2)
            )
            ESPObjects[player].Tracer.Size = UDim2.new(0, length, 0, 2)
            ESPObjects[player].Tracer.Rotation = math.deg(math.atan2(
                endPos.Y - startPos.Y, 
                endPos.X - startPos.X
            ))
            ESPObjects[player].Tracer.Visible = true
        else
            ESPObjects[player].Tracer.Visible = false
        end
    end
end
end

-- Main ESP loop
local function ESPLoop()
    for player, _ in pairs(ESPObjects) do
        UpdateESP(player)
    end
end

-- Toggle ESP system
local function ToggleESP()
    ESPConfig.Enabled = not ESPConfig.Enabled
    
    if ESPConfig.Enabled then
        -- Refresh all ESP objects
        for player, esp in pairs(ESPObjects) do
            if player and player.Parent then -- Check if player still exists
                esp.GUI.Enabled = true
                UpdateESP(player)
            else
                esp.GUI:Destroy()
                ESPObjects[player] = nil
            end
        end
        
        -- Start update loop if not already running
        if not ESPLoopConnection then
            ESPLoopConnection = RunService.Heartbeat:Connect(function()
                for player, _ in pairs(ESPObjects) do
                    UpdateESP(player)
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
        
        -- Clean up connection
        if ESPLoopConnection then
            ESPLoopConnection:Disconnect()
            ESPLoopConnection = nil
        end
    end
end


-- Keybind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == ESPConfig.ToggleKey then
        ToggleESP()
    end
end)

-- Initialization
local function Init()
    -- Wait for character
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    
    -- Create ESP for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateESP(player)
        end
    end
    
    -- Set up player added/removed handlers
    Players.PlayerAdded:Connect(function(player)
        CreateESP(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        if ESPObjects[player] then
            ESPObjects[player].GUI:Destroy()
            ESPObjects[player] = nil
        end
    end)
    
    -- Start ESP
    ToggleESP()
end

Init()
