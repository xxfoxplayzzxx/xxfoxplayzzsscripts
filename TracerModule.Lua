-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Load ESP assets
local ESPAssets = game:GetObjects("rbxassetid://136147565845068")[1]
local ESPGuiTemplate = ESPAssets:FindFirstChild("ESPGui")
local TracerTemplate = ESPAssets:FindFirstChild("Tracer")

if not ESPGuiTemplate or not TracerTemplate then
    error("Missing ESP assets in the model!")
end

-- ESP Settings
local ESPEnabled = false
local TeamCheck = true -- Change to false to ignore teams
local TracersEnabled = true

-- Colors (using standard Color3 values instead of Studio settings)
local EnemyColor = Color3.fromRGB(255, 60, 60)    -- Red
local FriendlyColor = Color3.fromRGB(60, 255, 60) -- Green
local NeutralColor = Color3.fromRGB(255, 255, 60) -- Yellow

-- Track all ESP instances
local ESPInstances = {}

-- Create ESP for a player
local function CreateESP(player)
    if player == LocalPlayer or ESPInstances[player] then return end
    
    local esp = {
        Player = player,
        Gui = nil,
        Tracer = nil,
        Connections = {}
    }
    ESPInstances[player] = esp
    
    local function Initialize()
        -- Wait for characters
        local targetChar = player.Character or player.CharacterAdded:Wait()
        local localChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        
        -- Create ESP GUI
        esp.Gui = ESPGuiTemplate:Clone()
        esp.Gui.Adornee = targetChar:WaitForChild("HumanoidRootPart")
        esp.Gui.Parent = Camera
        esp.Gui.Enabled = true
        
        -- Set player name
        local header = esp.Gui:FindFirstChild("Header")
        if header then
            header.Text = player.DisplayName ~= player.Name and 
                string.format("%s (@%s)", player.DisplayName, player.Name) or 
                player.Name
        end
        
        -- Create tracer
        if TracersEnabled then
            esp.Tracer = TracerTemplate:Clone()
            esp.Tracer.Attachment0 = localChar:WaitForChild("HumanoidRootPart"):WaitForChild("RootAttachment")
            esp.Tracer.Attachment1 = targetChar:WaitForChild("HumanoidRootPart"):WaitForChild("RootAttachment")
            esp.Tracer.Parent = Camera
        end
        
        -- Update colors based on team
        local function UpdateColors()
            local color
            if TeamCheck and player.Team and LocalPlayer.Team then
                color = player.Team == LocalPlayer.Team and FriendlyColor or EnemyColor
            else
                color = NeutralColor
            end
            
            if esp.Tracer then
                esp.Tracer.Color = ColorSequence.new(color)
            end
            if esp.Gui:FindFirstChild("BackgroundColor3") then
                esp.Gui.BackgroundColor3 = color
            end
        end
        
        -- Setup connections
        table.insert(esp.Connections, player.CharacterAdded:Connect(function(newChar)
            esp.Gui.Adornee = newChar:WaitForChild("HumanoidRootPart")
            if esp.Tracer then
                esp.Tracer.Attachment1 = newChar:WaitForChild("HumanoidRootPart").RootAttachment
            end
            UpdateColors()
        end))
        
        table.insert(esp.Connections, LocalPlayer.CharacterAdded:Connect(function(newChar)
            if esp.Tracer then
                esp.Tracer.Attachment0 = newChar:WaitForChild("HumanoidRootPart").RootAttachment
            end
        end))
        
        if TeamCheck then
            table.insert(esp.Connections, player:GetPropertyChangedSignal("Team"):Connect(UpdateColors))
            table.insert(esp.Connections, LocalPlayer:GetPropertyChangedSignal("Team"):Connect(UpdateColors))
        end
        
        UpdateColors()
    end
    
    -- Initialize with error handling
    local success, err = pcall(Initialize)
    if not success then
        warn("ESP failed for "..player.Name..": "..err)
        ESPInstances[player] = nil
    end
end

-- Remove ESP for a player
local function RemoveESP(player)
    local esp = ESPInstances[player]
    if not esp then return end
    
    -- Disconnect all events
    for _, conn in pairs(esp.Connections) do
        conn:Disconnect()
    end
    
    -- Destroy objects
    if esp.Gui then esp.Gui:Destroy() end
    if esp.Tracer then esp.Tracer:Destroy() end
    
    ESPInstances[player] = nil
end

-- Toggle ESP system
local function ToggleESP()
    ESPEnabled = not ESPEnabled
    
    if ESPEnabled then
        -- Enable for all players
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreateESP(player)
            end
        end
        
        -- Connect to new players
        ESPInstances.PlayerAdded = Players.PlayerAdded:Connect(function(player)
            CreateESP(player)
        end)
        
        -- Connect to leaving players
        ESPInstances.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
            RemoveESP(player)
        end)
    else
        -- Disable all ESP
        for player in pairs(ESPInstances) do
            if type(player) == "userdata" then -- Only actual player instances
                RemoveESP(player)
            end
        end
        
        -- Clean up connections
        if ESPInstances.PlayerAdded then
            ESPInstances.PlayerAdded:Disconnect()
        end
        if ESPInstances.PlayerRemoving then
            ESPInstances.PlayerRemoving:Disconnect()
        end
    end
end

-- Keybind (F1 to toggle)
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F1 then
        ToggleESP()
    end
end)

-- Initial notification
local function Notify(message)
    print("[ESP] "..message)
    if not game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Chat) then
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "ESP System",
            Text = message,
            Duration = 3
        })
    end
end

Notify("ESP loaded! Press F1 to toggle")

-- Auto-cleanup
local function Cleanup()
    if ESPEnabled then
        ToggleESP() -- Turn off ESP before cleanup
    end
end

game:GetService("ScriptContext").DescendantRemoving:Connect(function(descendant)
    if descendant == script then
        Cleanup()
    end
end)
