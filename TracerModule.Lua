-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Import Tracer from model
local ESPAssets = game:GetObjects("rbxassetid://118067082961835")[1]
local CustomTracer = ESPAssets:FindFirstChild("Tracer")

-- Configuration
local ESPConfig = {
    Enabled = false,
    TeamCheck = true,
    Tracers = true,
    Highlights = true,
    Names = true,
    HealthBars = true,
    Distance = false,

    -- Colors
    NeutralColor = Color3.fromRGB(255, 255, 60),

    HighlightTransparency = 0.6,
    OutlineTransparency = 0.2,

    TracerTexture = "http://www.roblox.com/asset/?id=4955566540",
    TracerWidth = 0.5,  -- Changed to 0.5 as requested

    ToggleKey = Enum.KeyCode.N,

    UpdateRate = 0.3,
    MaxDistance = 1000
}

-- ESP Storage
local ESPObjects = {}
local ESPLoopConnection = nil

local function UpdateESP(player)
    if not ESPObjects[player] then return end
    local esp = ESPObjects[player]
    local character = player.Character

    -- Clear if no character
    if not character then
        if esp.Highlight then esp.Highlight.Parent = nil end
        if esp.Tracer then esp.Tracer.Parent = nil end
        if esp.Billboard then esp.Billboard.Parent = nil end
        return
    end

    -- Get root part for distance checks
    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso")
    if not rootPart then return end

    -- Check distance (still used for rendering, just not displayed)
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
    if distance > ESPConfig.MaxDistance then
        if esp.Highlight then esp.Highlight.Parent = nil end
        if esp.Tracer then esp.Tracer.Parent = nil end
        if esp.Billboard then esp.Billboard.Parent = nil end
        return
    end

    -- Determine color based on team (using actual team colors)
    local color
    if ESPConfig.TeamCheck and player.Team then
        color = player.TeamColor.Color  -- Use the actual team color
    else
        color = ESPConfig.NeutralColor  -- Fallback to yellow
    end

    -- Update highlight with team color
    if esp.Highlight then
        esp.Highlight.Parent = character
        esp.Highlight.FillColor = color
        esp.Highlight.OutlineColor = color
        esp.Highlight.Enabled = ESPConfig.Enabled and ESPConfig.Highlights
    end

    -- Update tracer with team color
    if esp.Tracer then
        esp.Tracer.Color = ColorSequence.new(color)  -- Set to team color
        esp.Tracer.Parent = ESPConfig.Enabled and ESPConfig.Tracers and workspace.CurrentCamera or nil

        if ESPConfig.Enabled and ESPConfig.Tracers and LocalPlayer.Character then
            local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local myAttachment = myRoot:FindFirstChild("RootAttachment") or Instance.new("Attachment")
                myAttachment.Name = "RootAttachment"
                myAttachment.Parent = myRoot

                local theirAttachment = rootPart:FindFirstChild("RootAttachment") or Instance.new("Attachment")
                theirAttachment.Name = "RootAttachment"
                theirAttachment.Parent = rootPart

                esp.Tracer.Attachment0 = myAttachment
                esp.Tracer.Attachment1 = theirAttachment
            end
        end
    end

    -- Update billboard text (removed distance display)
    if esp.Billboard and esp.TextLabel then
        -- Make sure it's parented to head
        local head = character:FindFirstChild("Head")
        if head and esp.Billboard.Parent ~= head then
            esp.Billboard.Adornee = head
            esp.Billboard.Parent = head
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local healthText = humanoid and string.format("Health: %d/%d", humanoid.Health, humanoid.MaxHealth) or "Health: N/A"

        esp.TextLabel.Text = string.format("%s\n%s",  -- Removed distance from this line
            player.DisplayName ~= "" and player.DisplayName or player.Name,
            healthText
        )
        esp.TextLabel.TextColor3 = color
        esp.Billboard.Enabled = ESPConfig.Enabled and ESPConfig.Names
    end
end

-- Create ESP components for a player
local function CreateESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local esp = {
        Highlight = nil,
        Tracer = nil,
        Billboard = nil,
        Connections = {}
    }
    ESPObjects[player] = esp

    -- Function to setup character ESP
    local function setupCharacterESP(character)
        -- Create highlight
        if ESPConfig.Highlights then
            esp.Highlight = Instance.new("Highlight")
            esp.Highlight.Name = player.Name.."_Highlight"
            esp.Highlight.FillTransparency = ESPConfig.HighlightTransparency
            esp.Highlight.OutlineTransparency = ESPConfig.OutlineTransparency
            esp.Highlight.Parent = character
        end

        -- Create tracer with custom settings
        if ESPConfig.Tracers and CustomTracer then
            esp.Tracer = CustomTracer:Clone()
            esp.Tracer.Name = player.Name.."_Tracer"

            -- Apply custom texture and width (0.5 as requested)
            esp.Tracer.Texture = ESPConfig.TracerTexture
            esp.Tracer.Width0 = ESPConfig.TracerWidth
            esp.Tracer.Width1 = ESPConfig.TracerWidth

            esp.Tracer.Parent = workspace.CurrentCamera
        end

        -- Create billboard
        if ESPConfig.Names then
            esp.Billboard = Instance.new("BillboardGui")
            esp.Billboard.Name = player.Name.."_Billboard"
            esp.Billboard.Size = UDim2.new(0, 200, 0, 50)
            esp.Billboard.StudsOffset = Vector3.new(0, 2, 0)
            esp.Billboard.AlwaysOnTop = true

            local TextLabel = Instance.new("TextLabel")
            TextLabel.Size = UDim2.new(1, 0, 1, 0)
            TextLabel.BackgroundTransparency = 1
            TextLabel.TextScaled = true
            TextLabel.Font = Enum.Font.SourceSansBold
            TextLabel.TextStrokeTransparency = 0
            TextLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            TextLabel.Parent = esp.Billboard
            esp.TextLabel = TextLabel

            -- Parent to head if exists
            local head = character:WaitForChild("Head", 2)
            if head then
                esp.Billboard.Adornee = head
                esp.Billboard.Parent = head
            end
        end

        -- Update immediately
        UpdateESP(player)
    end

    -- Setup for current character if exists
    if player.Character then
        setupCharacterESP(player.Character)
    end

    -- Connect character added event
    esp.Connections.characterAdded = player.CharacterAdded:Connect(function(character)
        if ESPConfig.Enabled then
            -- Clean up old ESP
            if esp.Highlight then esp.Highlight:Destroy() end
            if esp.Tracer then esp.Tracer:Destroy() end
            if esp.Billboard then esp.Billboard:Destroy() end

            -- Setup new character
            setupCharacterESP(character)
        end
    end)
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

		-- Start update loop
		if not ESPLoopConnection then
			ESPLoopConnection = RunService.Heartbeat:Connect(function()
				for player, _ in pairs(ESPObjects) do
					if player and player.Parent then
						UpdateESP(player)
					else
						-- Clean up if player left
						if ESPObjects[player] then
							if ESPObjects[player].Highlight then ESPObjects[player].Highlight:Destroy() end
							if ESPObjects[player].Tracer then ESPObjects[player].Tracer:Destroy() end
							if ESPObjects[player].Billboard then ESPObjects[player].Billboard:Destroy() end
							ESPObjects[player] = nil
						end
					end
				end
			end)
		end
	else
		-- Disable all ESP objects
		for _, esp in pairs(ESPObjects) do
			if esp.Highlight then esp.Highlight.Enabled = false end
			if esp.Tracer then esp.Tracer.Parent = nil end
			if esp.Billboard then esp.Billboard.Enabled = false end
		end
	end
end

-- Initialize
local function Init()
	-- Set up player handlers
	Players.PlayerAdded:Connect(function(player)
		CreateESP(player)
		if ESPConfig.Enabled then
			UpdateESP(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if ESPObjects[player] then
			if ESPObjects[player].Highlight then ESPObjects[player].Highlight:Destroy() end
			if ESPObjects[player].Tracer then ESPObjects[player].Tracer:Destroy() end
			if ESPObjects[player].Billboard then ESPObjects[player].Billboard:Destroy() end
			ESPObjects[player] = nil
		end
	end)

	-- Create ESP for existing players
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			CreateESP(player)
		end
	end

	-- Set up keybind
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == ESPConfig.ToggleKey then
			ToggleESP()
		end
	end)
end

Init()
