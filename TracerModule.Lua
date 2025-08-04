-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import Tracer from model
local ESPAssets = game:GetObjects("rbxassetid://118067082961835")[1]
local CustomTracer = ESPAssets:FindFirstChild("Tracer")

if not CustomTracer then
    warn("Failed to find Tracer in the model")
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
    
    -- Visual settings
    BoxTransparency = 0.7,
    TextSize = 20,
    
    -- Keybind
    ToggleKey = Enum.KeyCode.F1,
    
    -- Performance
    UpdateRate = 0.1, -- Seconds between updates
    MaxDistance = 1000 -- Max render distance
}

-- ESP Storage
local ESPObjects = {}
local ESPLoopConnection = nil
local COREGUI = Instance.new("Folder")
COREGUI.Name = "ESP_CORE"
COREGUI.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Helper functions
local function getRoot(character)
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
end

local function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Create ESP components for a player
local function CreateESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then 
        if ESPObjects[player].ESPholder then 
            ESPObjects[player].ESPholder:Destroy() 
        end
        if ESPObjects[player].Tracer then 
            ESPObjects[player].Tracer:Destroy() 
        end
    end
    
    -- Create tracer if enabled
    local tracer
    if ESPConfig.Tracers then
        tracer = CustomTracer:Clone()
        tracer.Name = player.Name.."_Tracer"
        tracer.Color = ColorSequence.new(ESPConfig.NeutralColor)
        tracer.Parent = workspace.CurrentCamera
    end

    -- Create ESP holder
    local ESPholder = Instance.new("Folder")
    ESPholder.Name = player.Name.."_ESP"
    ESPholder.Parent = COREGUI

    -- Wait for character
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    repeat wait() until player.Character and getRoot(player.Character) and player.Character:FindFirstChildOfClass("Humanoid")

    -- Create box adornments for all parts
    if ESPConfig.Boxes then
        for _, part in pairs(player.Character:GetChildren()) do
            if part:IsA("BasePart") then
                local box = Instance.new("BoxHandleAdornment")
                box.Name = part.Name
                box.Parent = ESPholder
                box.Adornee = part
                box.AlwaysOnTop = true
                box.ZIndex = 10
                box.Size = part.Size
                box.Transparency = ESPConfig.BoxTransparency
                box.Color3 = player.Team == LocalPlayer.Team and ESPConfig.FriendlyColor or ESPConfig.EnemyColor
            end
        end
    end

    -- Create name tag
    if player.Character:FindFirstChild("Head") then
        local BillboardGui = Instance.new("BillboardGui")
        local TextLabel = Instance.new("TextLabel")
        
        BillboardGui.Adornee = player.Character.Head
        BillboardGui.Name = player.Name
        BillboardGui.Parent = ESPholder
        BillboardGui.Size = UDim2.new(0, 100, 0, 150)
        BillboardGui.StudsOffset = Vector3.new(0, 1, 0)
        BillboardGui.AlwaysOnTop = true
        
        TextLabel.Parent = BillboardGui
        TextLabel.BackgroundTransparency = 1
        TextLabel.Position = UDim2.new(0, 0, 0, -50)
        TextLabel.Size = UDim2.new(0, 100, 0, 100)
        TextLabel.Font = Enum.Font.SourceSansSemibold
        TextLabel.TextSize = ESPConfig.TextSize
        TextLabel.TextColor3 = Color3.new(1, 1, 1)
        TextLabel.TextStrokeTransparency = 0
        TextLabel.TextYAlignment = Enum.TextYAlignment.Bottom
        TextLabel.ZIndex = 10

        -- Set initial text
        local root = getRoot(player.Character)
        local myRoot = LocalPlayer.Character and getRoot(LocalPlayer.Character)
        local distance = myRoot and math.floor((myRoot.Position - root.Position).magnitude) or 0
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        local health = humanoid and round(humanoid.Health, 1) or 0
        
        TextLabel.Text = string.format("%s\nHealth: %d\nDistance: %d", 
            player.DisplayName ~= "" and player.DisplayName or player.Name,
            health,
            distance
        )
    end

    -- Store ESP objects
    ESPObjects[player] = {
        ESPholder = ESPholder,
        Tracer = tracer,
        Player = player
    }

    -- Set up character added event
    local charAddedConn
    charAddedConn = player.CharacterAdded:Connect(function(newChar)
        if ESPConfig.Enabled then
            charAddedConn:Disconnect()
            CreateESP(player)
        end
    end)

    -- Set up team change event
    local teamChangeConn
    teamChangeConn = player:GetPropertyChangedSignal("Team"):Connect(function()
        if ESPConfig.Enabled then
            teamChangeConn:Disconnect()
            CreateESP(player)
        end
    end)

    -- Add to maid
    if not ESPObjects[player].Connections then
        ESPObjects[player].Connections = {}
    end
    table.insert(ESPObjects[player].Connections, charAddedConn)
    table.insert(ESPObjects[player].Connections, teamChangeConn)
end

-- Update ESP appearance
local function UpdateESP(player)
    if not ESPObjects[player] then return end
    
    local esp = ESPObjects[player]
    local character = player.Character
    if not character then
        if esp.ESPholder then esp.ESPholder:Destroy() end
        if esp.Tracer then esp.Tracer.Parent = nil end
        return
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = getRoot(character)
    if not humanoid or not rootPart then
        if esp.ESPholder then esp.ESPholder:Destroy() end
        if esp.Tracer then esp.Tracer.Parent = nil end
        return
    end
    
    -- Calculate distance
    local myRoot = LocalPlayer.Character and getRoot(LocalPlayer.Character)
    local distance = myRoot and (rootPart.Position - myRoot.Position).Magnitude or 0
    if distance > ESPConfig.MaxDistance then
        if esp.ESPholder then esp.ESPholder:Destroy() end
        if esp.Tracer then esp.Tracer.Parent = nil end
        return
    end
    
    -- Set colors based on team
    local color
    if ESPConfig.TeamCheck and player.Team and LocalPlayer.Team then
        color = player.Team == LocalPlayer.Team and ESPConfig.FriendlyColor or ESPConfig.EnemyColor
    else
        color = ESPConfig.NeutralColor
    end
    
    -- Update box colors if they exist
    if esp.ESPholder then
        for _, adornment in ipairs(esp.ESPholder:GetChildren()) do
            if adornment:IsA("BoxHandleAdornment") then
                adornment.Color3 = color
            end
        end
    end
    
    -- Update name tag
    local billboard = esp.ESPholder and esp.ESPholder:FindFirstChildOfClass("BillboardGui")
    if billboard then
        local textLabel = billboard:FindFirstChildOfClass("TextLabel")
        if textLabel then
            local health = humanoid and round(humanoid.Health, 1) or 0
            textLabel.Text = string.format("%s\nHealth: %d\nDistance: %dm", 
                player.DisplayName ~= "" and player.DisplayName or player.Name,
                health,
                math.floor(distance)
            )
            textLabel.TextColor3 = color
        end
    end
    
    -- Update tracer
    if esp.Tracer then
        esp.Tracer.Color = ColorSequence.new(color)
        
        if ESPConfig.Tracers and ESPConfig.Enabled and LocalPlayer.Character then
            local myRoot = getRoot(LocalPlayer.Character)
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
                esp.Tracer.Parent = workspace.CurrentCamera
            else
                esp.Tracer.Parent = nil
            end
        else
            esp.Tracer.Parent = nil
        end
    end
end

-- Toggle ESP system
local function ToggleESP()
    ESPConfig.Enabled = not ESPConfig.Enabled
    
    if ESPConfig.Enabled then
        -- Create ESP for all players
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreateESP(player)
            end
        end
        
        -- Start update loop if not already running
        if not ESPLoopConnection then
            ESPLoopConnection = RunService.Heartbeat:Connect(function()
                for player, _ in pairs(ESPObjects) do
                    if player and player.Parent then
                        UpdateESP(player)
                    else
                        -- Clean up if player left
                        if ESPObjects[player] then
                            if ESPObjects[player].ESPholder then 
                                ESPObjects[player].ESPholder:Destroy() 
                            end
                            if ESPObjects[player].Tracer then 
                                ESPObjects[player].Tracer:Destroy() 
                            end
                            ESPObjects[player] = nil
                        end
                    end
                end
            end)
        end
    else
        -- Disable all ESP objects
        for _, esp in pairs(ESPObjects) do
            if esp.ESPholder then esp.ESPholder:Destroy() end
            if esp.Tracer then esp.Tracer:Destroy() end
        end
        ESPObjects = {}
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
        if ESPObjects[player].ESPholder then 
            ESPObjects[player].ESPholder:Destroy() 
        end
        if ESPObjects[player].Tracer then 
            ESPObjects[player].Tracer:Destroy() 
        end
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
