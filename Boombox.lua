local assetId = "74360442571818"
local player = game:GetService("Players").LocalPlayer
local backpack = player:WaitForChild("Backpack")

-- 1. Import the Tool
local success, objects = pcall(function()
    return game:GetObjects("rbxassetid://" .. assetId)
end)

if not (success and objects and objects[1]) then
    return warn("Import failed. Check if the asset is Public!")
end

local tool = objects[1]
tool.Parent = backpack

-- 2. State Management
local currentSound = nil
local songGui = nil

-- 3. Audio Execution
local function playSong(handle, id)
    if currentSound then 
        currentSound:Stop()
        currentSound:Destroy() 
    end
    
    if not id or id == "" or id == 0 then return end

    currentSound = Instance.new("Sound")
    currentSound.Name = "LocalBoomboxSound"
    currentSound.Parent = handle
    currentSound.Volume = 0.5
    currentSound.Looped = true
    currentSound.SoundId = "rbxassetid://" .. tostring(id)
    
    -- Wait for load then play
    if not currentSound.IsLoaded then
        currentSound.Loaded:Wait()
    end
    currentSound:Play()
end

-- 4. Interface Logic
local function openGui(handle)
    if player.PlayerGui:FindFirstChild("BoomboxGui") then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "BoomboxGui"
    sg.ResetOnSpawn = false
    sg.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 120)
    frame.Position = UDim2.new(0.5, -125, 0.5, -60)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    frame.BorderSizePixel = 0
    frame.Draggable = true
    frame.Active = true
    frame.Parent = sg

    -- Corner rounding for a modern look
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "CLIENT BOOMBOX"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = frame

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0.9, 0, 0, 35)
    input.Position = UDim2.new(0.05, 0, 0.3, 0)
    input.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    input.Text = "142376088"
    input.PlaceholderText = "Sound ID Here"
    input.TextColor3 = Color3.new(1, 1, 1)
    input.Font = Enum.Font.Gotham
    input.TextSize = 16
    input.BorderSizePixel = 0
    input.Parent = frame
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = input

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0.65, 0)
    btn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    btn.Text = "PLAY"
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    btn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        local id = tonumber(input.Text:match("%d+"))
        playSong(handle, id)
        sg:Destroy()
        songGui = nil
    end)
    
    songGui = sg
end

-- 5. Event Connections (The "Hijacker")
tool.Activated:Connect(function()
    local handle = tool:FindFirstChild("Handle")
    if handle then
        openGui(handle)
    else
        warn("Boombox Handle missing!")
    end
end)

tool.Unequipped:Connect(function()
    if songGui then 
        songGui:Destroy() 
        songGui = nil 
    end
    if currentSound then 
        currentSound:Stop() 
    end
end)

print("Boombox Controller Ready. Asset:", assetId)
