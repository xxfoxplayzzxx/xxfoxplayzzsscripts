-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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

-- ESP Instance Pool
local ESPPool = {
    Active = {},
    Inactive = {}
}

-- Create base ESP objects
local function CreateBasePart()
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(2, 3, 1)
    part.Parent = workspace
    return part
end

local function CreateESPUI()
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.new(4, 0, 6, 0)
    gui.AlwaysOnTop = true
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 1
    frame.Parent = gui
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.2, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, -20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextScaled = true
    nameLabel.Parent = gui
    
    local healthBar = Instance.new("Frame")
    healthBar.Size = UDim2.new(0.8, 0, 0.05, 0)
    healthBar.Position = UDim2.new(0.1, 0, 0.85, 0)
    healthBar.BorderSizePixel = 1
    healthBar.Parent = gui
    
    local healthFill = Instance.new("Frame")
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthFill.Parent = healthBar
    
    return gui, frame, nameLabel, healthBar, healthFill
end

-- Get ESP instance from pool
local function GetESPInstance()
    if #ESPPool.Inactive > 0 then
        return table.remove(ESPPool.Inactive)
    else
        local basePart = CreateBasePart()
        local gui, frame, nameLabel, healthBar, healthFill = CreateESPUI()
        return {
            BasePart = basePart,
            GUI = gui,
            Frame = frame,
            NameLabel = nameLabel,
            HealthBar = healthBar,
            HealthFill = healthFill,
            Tracer = TracersEnabled and Instance.new("Beam") or nil
        }
    end
end

-- Update ESP appearance
local function UpdateESP(esp, player, character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end
    
    -- Set position and visibility
    esp.BasePart.CFrame = rootPart.CFrame
    esp.GUI.Adornee = rootPart
    
    -- Calculate distance
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if distance > ESPConfig.MaxDistance then
        esp.GUI.Enabled = false
        return
    end
    
    esp.GUI.Enabled = true
    
    -- Set colors based on team
    local color
    if ESPConfig.TeamCheck and player.Team and LocalPlayer.Team then
        color = player.Team == LocalPlayer.Team and ESPConfig.FriendlyColor or ESPConfig.EnemyColor
    else
        color = ESPConfig.NeutralColor
    end
    
    -- Update visuals
    esp.Frame.BackgroundColor3 = color
    esp.Frame.BorderColor3 = color:lerp(Color3.new(0,0,0), 0.5)
    
    if ESPConfig.Names then
        esp.NameLabel.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
        esp.NameLabel.TextColor3 = color
    end
    
    if ESPConfig.HealthBars and humanoid then
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        esp.HealthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
        esp.HealthFill.BackgroundColor3 = Color3.fromRGB(
            255 * (1 - healthPercent),
            255 * healthPercent,
            0
        )
    end
    
    if ESPConfig.Distance then
        esp.NameLabel.Text = string.format("%s [%dm]", esp.NameLabel.Text, math.floor(distance))
    end
    
    -- Update tracer if enabled
    if esp.Tracer then
        esp.Tracer.Color = ColorSequence.new(color)
        esp.Tracer.Attachment0 = LocalPlayer.Character:FindFirstChild("HumanoidRootPart").RootAttachment
        esp.Tracer.Attachment1 = rootPart.RootAttachment
    end
end

-- Main ESP loop
local function ESPLoop()
    for player, esp in pairs(ESPPool.Active) do
        if player and player.Character then
            UpdateESP(esp, player, player.Character)
        else
            -- Return to pool if player left
            table.insert(ESPPool.Inactive, esp)
            ESPPool.Active[player] = nil
        end
    end
end

-- Toggle ESP system
local function ToggleESP()
    ESPConfig.Enabled = not ESPConfig.Enabled
    
    if ESPConfig.Enabled then
        -- Enable for existing players
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                ESPPool.Active[player] = GetESPInstance()
            end
        end
        
        -- Connect to new players
        Players.PlayerAdded:Connect(function(player)
            ESPPool.Active[player] = GetESPInstance()
        end)
        
        -- Start update loop
        RunService:BindToRenderStep("ESPUpdate", Enum.RenderPriority.Last.Value, ESPLoop)
    else
        -- Disable and clean up
        RunService:UnbindFromRenderStep("ESPUpdate")
        
        for player, esp in pairs(ESPPool.Active) do
            table.insert(ESPPool.Inactive, esp)
        end
        ESPPool.Active = {}
    end
end

-- Keybind
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
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
    
    ToggleESP()
end

Init()
