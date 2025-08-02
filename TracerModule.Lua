-- ESP & Tracer Script (Paste in LocalScript)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera

-- Load ESP assets from Roblox library
local ESPAssets = game:GetObjects("rbxassetid://136147565845068")[1]
local ESPGuiTemplate = ESPAssets:FindFirstChild("ESPGui")
local TracerTemplate = ESPAssets:FindFirstChild("Tracer")

if not ESPGuiTemplate or not TracerTemplate then
    error("Could not find ESP assets in the model!")
end

-- ESP tracking table
local ActiveESPs = {}

-- Color settings
local TeamColor = settings().Studio.TeamColor
local EnemyColor = Color3.fromRGB(255, 50, 50)
local FriendlyColor = Color3.fromRGB(50, 255, 50)

local function CreateESP(targetPlayer)
    -- Don't ESP yourself or existing ESPs
    if targetPlayer == LocalPlayer or ActiveESPs[targetPlayer] then return end
    
    local esp = {
        Player = targetPlayer,
        Gui = nil,
        Tracer = nil,
        Connections = {}
    }
    
    ActiveESPs[targetPlayer] = esp
    
    -- Function to initialize ESP
    local function Initialize()
        -- Wait for both characters to exist
        local targetChar = targetPlayer.Character or targetPlayer.CharacterAdded:Wait()
        local localChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        
        -- Create ESP GUI
        esp.Gui = ESPGuiTemplate:Clone()
        esp.Gui.Adornee = targetChar:WaitForChild("HumanoidRootPart")
        esp.Gui.Parent = Camera
        esp.Gui.Enabled = true
        
        -- Set player name
        local header = esp.Gui:FindFirstChild("Header")
        if header then
            header.Text = targetPlayer.DisplayName ~= targetPlayer.Name and 
                targetPlayer.DisplayName.." (@"..targetPlayer.Name..")" or 
                targetPlayer.Name
        end
        
        -- Create tracer
        esp.Tracer = TracerTemplate:Clone()
        esp.Tracer.Attachment0 = localChar:WaitForChild("HumanoidRootPart"):WaitForChild("RootAttachment")
        esp.Tracer.Attachment1 = targetChar:WaitForChild("HumanoidRootPart"):WaitForChild("RootAttachment")
        esp.Tracer.Parent = Camera
        
        -- Update color based on team
        local function UpdateColor()
            local color = targetPlayer.Team == LocalPlayer.Team and LocalPlayer.Team ~= nil 
                and FriendlyColor or EnemyColor
            esp.Tracer.Color = ColorSequence.new(color)
            if esp.Gui:FindFirstChild("BackgroundColor3") then
                esp.Gui.BackgroundColor3 = color
            end
        end
        
        -- Set up connections
        table.insert(esp.Connections, targetPlayer.CharacterAdded:Connect(function(char)
            esp.Gui.Adornee = char:WaitForChild("HumanoidRootPart")
            esp.Tracer.Attachment1 = char:WaitForChild("HumanoidRootPart").RootAttachment
        end))
        
        table.insert(esp.Connections, LocalPlayer.CharacterAdded:Connect(function(char)
            esp.Tracer.Attachment0 = char:WaitForChild("HumanoidRootPart").RootAttachment
        end))
        
        table.insert(esp.Connections, targetPlayer:GetPropertyChangedSignal("Team"):Connect(UpdateColor))
        
        UpdateColor()
    end
    
    -- Initialize and handle errors
    local success, err = pcall(Initialize)
    if not success then
        warn("Failed to initialize ESP for "..targetPlayer.Name..": "..err)
        DestroyESP(targetPlayer)
    end
end

local function DestroyESP(targetPlayer)
    local esp = ActiveESPs[targetPlayer]
    if not esp then return end
    
    -- Clean up connections
    for _, conn in pairs(esp.Connections) do
        conn:Disconnect()
    end
    
    -- Destroy objects
    if esp.Gui then esp.Gui:Destroy() end
    if esp.Tracer then esp.Tracer:Destroy() end
    
    ActiveESPs[targetPlayer] = nil
end

-- Main ESP toggle
local ESPEnabled = false

local function ToggleESP()
    ESPEnabled = not ESPEnabled
    
    if ESPEnabled then
        -- Create ESP for all players
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreateESP(player)
            end
        end
        
        -- Connect to detect new players
        Players.PlayerAdded:Connect(function(player)
            CreateESP(player)
        end)
    else
        -- Destroy all ESPs
        for player in pairs(ActiveESPs) do
            DestroyESP(player)
        end
    end
end

-- Bind to key (F1 for example)
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F1 then
        ToggleESP()
    end
end)

-- Clean up on script destruction
script.Destroying:Connect(function()
    for player in pairs(ActiveESPs) do
        DestroyESP(player)
    end
end)

print("ESP script loaded! Press F1 to toggle ESP")
