local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local gui = game:GetObjects("rbxassetid://82094800004860")[1]

if gui then
	gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
else
	warn("Failed to get model!")
end

local bar = gui:WaitForChild("Bar")
local input = bar:WaitForChild("Input")
local underlay = bar:WaitForChild("Underlay")
local overlay = bar:WaitForChild("Overlay")
local active = false

-- commands already been ran:
local fly = false
local Clip = true
local NoclippingConnection = nil
local flinging = false
local flingLoop = nil
local originalPosition = nil
local flingConnection = nil

-- Sounds
local SF = gui:WaitForChild("SFX"):WaitForChild("Default")
local Click = SF:WaitForChild("Click")
local Error = SF:WaitForChild("Error")
local Exec = SF:WaitForChild("Exec")
local Type = SF:WaitForChild("Type")

-- Command system
local validcmds = {
	fly = true,
	noclip = true,
	clip = true,
	kill = true,
	saveinstance = true,
	goto = true,
	infyield = true,
	tracers = true,
	sit = true,
	unsit = true,
	reset = true,
	rejoin = true,
	fling = true,
	unfling = true,
}

local aliases = {
	rj = "rejoin",
	re = "reset",
}

-- Vibrant color scheme for overlay
local TextColors = {
	Valid = "#4CAF50",       -- Bright green
	Invalid = "#F44336",     -- Bright red 
	Neutral = "#5d5d5d",     -- Gray
	Argument = "#9C27B0"     -- Purple
}

local BarPositions = {
	{ -- Active position
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(0.9, 0.02),
		Position = UDim2.new(0.5, 0, 1, -100)
	},
	{ -- Inactive position
		BackgroundTransparency = 0.7,
		Size = UDim2.fromScale(0.8, 0.02),
		Position = UDim2.new(0.5, 0, 1, 150)
	}
}

local function updateBar()
	local pos = BarPositions[active and 1 or 2]
	bar:TweenSizeAndPosition(pos.Size, pos.Position, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
	bar.BackgroundTransparency = pos.BackgroundTransparency
	input.Visible = active
	underlay.Visible = active
	overlay.Visible = active
	if not active then 
		input.Text = ""
		underlay.Text = ""
		overlay.Text = ""
	end
end

-- Build colored segment
local function colorizeCommand(inputText)
	local commandSegments = {}
	for segment in inputText:gmatch("([^,]+)") do
		commandSegments[#commandSegments + 1] = segment:gsub("^%s*(.-)%s*$", "%1")
	end

	if #commandSegments == 0 then
		overlay.Text = ""
		return
	end

	local coloredOutput = ""

	for i, segment in ipairs(commandSegments) do
		-- Split into command and arguments
		local cmd, args = segment:match("^(%S+)%s*(.*)$")
		cmd = cmd or ""
		args = args or ""
		local isValid = validcmds[cmd:lower()] ~= nil or aliases[cmd:lower()] ~= nil
		if i > 1 then
			coloredOutput = coloredOutput .. '<font color="'..TextColors.Neutral..'">, </font>'
		end

		coloredOutput = coloredOutput .. string.format(
			'<font color="%s">%s</font>', 
			isValid and TextColors.Valid or TextColors.Invalid, 
			cmd
		)
		if args ~= "" then
			coloredOutput = coloredOutput .. string.format(
				' <font color="%s">%s</font>', 
				TextColors.Argument, 
				args
			)
		end
	end

	overlay.Text = coloredOutput
end

local StringUtils = {}

-- Fuzzy matching function
StringUtils.matchScore = function(str, pattern)
	if str:find(pattern, 1, true) then  -- Exact match
		return 1.0
	end

	-- Simple fuzzy matching algorithm
	local score = 0
	local patternIdx = 1
	local lastMatchPos = 0

	for i = 1, #str do
		if patternIdx <= #pattern and str:sub(i,i):lower() == pattern:sub(patternIdx,patternIdx):lower() then
			score = score + 1
			patternIdx = patternIdx + 1
			lastMatchPos = i
		end
	end

	-- Normalize score (0-1 range)
	local normalized = score / #pattern

	-- Penalize gaps between matches
	if lastMatchPos > 0 then
		local gapPenalty = 1 - (lastMatchPos - #pattern) / #str
		normalized = normalized * gapPenalty
	end

	return normalized
end

local function updateAutocomplete()
	local fullText = input.Text
	underlay.Text = ""
	colorizeCommand(fullText)

	-- Get the last segment
	local lastSegment = fullText:match("([^,]*)$"):gsub("^%s*(.-)%s*$", "%1")
	if lastSegment == "" then return end

	-- Split into command and arguments
	local cmd, args = lastSegment:match("^(%S+)%s*(.*)$")
	cmd = cmd or ""
	args = args or ""

	-- Check for multi-command situation
	local hasExistingCommas = fullText:sub(1, -#lastSegment - 1):find(",")
	local prefix = hasExistingCommas and fullText:sub(1, -#lastSegment - 1) or ""

	-- Find best match for command (only if starting letters match)
	local bestCmdMatch, bestCmdScore = nil, 0
	for cmdName in pairs(validcmds) do
		-- Only suggest if the typed letters match the beginning of the command
		if cmdName:lower():sub(1, #cmd) == cmd:lower() then
			bestCmdMatch = cmdName
			bestCmdScore = 1.0
			break
		end
	end

	-- Find best match for player (if we have arguments)
	local bestPlayerMatch, bestPlayerScore = nil, 0
	if args ~= "" then
		-- Check for "random" keyword
		if args:lower() == "rand" or args:lower() == "rando" or args:lower() == "random" then
			bestPlayerMatch = "random"
			bestPlayerScore = 1.0
		else
			for _, player in pairs(Players:GetPlayers()) do
				-- Only suggest if the typed letters match the beginning of the name
				if player.Name:lower():sub(1, #args) == args:lower() then
					bestPlayerMatch = player.Name
					bestPlayerScore = 1.0
					break
				end
			end
		end
	end

	-- If we have an exact command match with no arguments, auto-complete it
	if args == "" and bestCmdMatch and bestCmdMatch:lower() == cmd:lower() then
		-- Don't show suggestion since it's already complete
		underlay.Text = ""
	elseif args == "" and bestCmdMatch and bestCmdScore > 0.5 then
		-- Suggest command completion
		underlay.Text = prefix .. bestCmdMatch
		underlay.TextTransparency = 0.5

		-- Add a space for arguments if it's a perfect match
		if bestCmdMatch:lower():sub(1, #cmd) == cmd:lower() then
			underlay.Text = underlay.Text .. " "
		end
	elseif args ~= "" and bestPlayerMatch and bestPlayerScore > 0.5 then
		-- Suggest player completion
		underlay.Text = prefix .. (bestCmdMatch or cmd) .. " " .. bestPlayerMatch
		underlay.TextTransparency = 0.5
	end
end

local function processCommand(fullInput)
	underlay.Text = ""
	overlay.Text = ""

	local commandHandlers = {
		fly = function()
			if fly == false then
				fly = true
				loadstring(game:HttpGet("https://raw.githubusercontent.com/xxfoxplayzzxx/xxfoxplayzzsscripts/main/Flight.Lua"))()
				return
			else
				return
			end
		end,
		noclip = function()
			Clip = false
			task.wait(0.1)

			if NoclippingConnection then
				NoclippingConnection:Disconnect()
			end

			NoclippingConnection = RunService.Stepped:Connect(function()
				local character = player.Character
				if Clip == false and character then
					for _, part in ipairs(character:GetDescendants()) do
						if part:IsA("BasePart") and part.CanCollide == true then
							part.CanCollide = false
						end
					end
				end
			end)
		end,
		clip = function()
			Clip = true
			if NoclippingConnection then
				NoclippingConnection:Disconnect()
				NoclippingConnection = nil
			end

			local character = player.Character
			if character then
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = true
					end
				end
			end
		end,
		kill = function()
			return
		end,
		saveinstance = function()
			local synsaveinstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau"))()
			synsaveinstance({mode="full", ShowStatus=true})
			return
		end,
		infyield = function()
			loadstring(game:HttpGet('https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua'))()
			return
		end,
		goto = function(args)
			local targetName = args:match("%S+") or ""
			local targetPlayer = nil

			-- Handle random selection
			if targetName:lower() == "random" then
				local players = Players:GetPlayers()
				if #players > 0 then
					local candidates = {}
					for _, player in pairs(players) do
						if player ~= player then
							table.insert(candidates, player)
						end
					end

					if #candidates == 0 then
						candidates = players
					end

					math.randomseed(tick())
					targetPlayer = candidates[math.random(1, #candidates)]
					targetName = targetPlayer.Name
				else
					return
				end
			else
				for _, player in pairs(Players:GetPlayers()) do
					if string.find(string.lower(player.Name), string.lower(targetName)) then
						targetPlayer = player
						break
					end
				end
			end

			if not targetPlayer then
				return "Player '"..targetName.."' not found"
			end

			if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
				return "Target player has no character"
			end

			if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
				return "Your character is not ready"
			end

			-- Handle if sitting in a vehicle
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.SeatPart then
				humanoid.Sit = false
				wait(0.1)
			end

			-- Teleport to target (with slight offset)
			player.Character.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(3, 1, 0)

			return
		end,
		tracers = function()
			loadstring(game:HttpGet("https://raw.githubusercontent.com/xxfoxplayzzxx/xxfoxplayzzsscripts/main/TracerModule.Lua"))()
			return
		end,
		sit = function()
			player.Character:FindFirstChildOfClass("Humanoid").Sit = true
		end,
		unsit = function()
			player.Character:FindFirstChildOfClass("Humanoid").Sit = false
		end,
		reset = function()
			player.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Dead)
		end,
		rejoin = function()
			local PlaceId = game.PlaceId
			local JobId = game.JobId
			if #Players:GetPlayers() <= 1 then
				Players.LocalPlayer:Kick("\nRejoining...")
				wait()
				TeleportService:Teleport(PlaceId, Players.LocalPlayer)
			else
				TeleportService:TeleportToPlaceInstance(PlaceId, JobId, Players.LocalPlayer)
			end
		end,
		fling = function(args)
			local targetName = args:match("%S+") or ""
			local targetPlayer = nil

			-- Enable noclip immediately
			processCommand("noclip")
			wait(0.1) -- Ensure noclip applies

			-- If no target specified, fling yourself in place
			if targetName == "" then
				-- Set up fling properties
				local root = player.Character.HumanoidRootPart
				for _, child in pairs(player.Character:GetDescendants()) do
					if child:IsA("BasePart") then
						child.CustomPhysicalProperties = PhysicalProperties.new(math.huge, 0.3, 0.5)
						child.CanCollide = false
						child.Massless = true
						child.Velocity = Vector3.new(0, 0, 0)
					end
				end

				local bambam = Instance.new("BodyAngularVelocity")
				bambam.Name = "ADONIS_FLIGHT_POSITION"
				bambam.Parent = root
				bambam.AngularVelocity = Vector3.new(0, 99999, 0)
				bambam.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
				bambam.P = math.huge

				flinging = true
				return "Flinging in place"
			end

			-- Handle player targeting
			if targetName:lower() == "random" then
				local players = Players:GetPlayers()
				if #players > 0 then
					targetPlayer = players[math.random(1, #players)]
					targetName = targetPlayer.Name
				else
					return "No players found"
				end
			else
				for _, p in pairs(Players:GetPlayers()) do
					if string.find(string.lower(p.Name), string.lower(targetName)) then
						targetPlayer = p
						break
					end
				end
			end

			if not targetPlayer then
				return "Player not found"
			end

			-- Store original position
			originalPosition = player.Character.HumanoidRootPart.CFrame

			-- Set up fling properties
			local root = player.Character.HumanoidRootPart
			for _, child in pairs(player.Character:GetDescendants()) do
				if child:IsA("BasePart") then
					child.CustomPhysicalProperties = PhysicalProperties.new(math.huge, 0.3, 0.5)
					child.CanCollide = false
					child.Massless = true
					child.Velocity = Vector3.new(0, 0, 0)
				end
			end

			local bambam = Instance.new("BodyAngularVelocity")
			bambam.Name = "ADONIS_FLIGHT_POSITION"
			bambam.Parent = root
			bambam.AngularVelocity = Vector3.new(0, 99999, 0)
			bambam.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			bambam.P = math.huge

			-- Create fling loop with automatic return after cycle
			flinging = true
			local cycleStart = tick()

			flingLoop = RunService.Heartbeat:Connect(function()
				if not flinging then return end

				-- Automatic return after 1.5 seconds
				if tick() - cycleStart >= 1.5 then
					processCommand("unfling")
					return
				end

				-- Continue flinging toward target
				if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
					local targetRoot = targetPlayer.Character.HumanoidRootPart
					root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, -3)
					bambam.AngularVelocity = Vector3.new(0, 99999, 0)
				else
					processCommand("unfling")
				end
			end)

			return "Flinging "..targetPlayer.Name.." (auto-return in 1.5s)"
		end,
		unfling = function()
			flinging = false

			-- Stop the fling loop
			if flingLoop then
				flingLoop:Disconnect()
				flingLoop = nil
			end

			-- Return to original position if exists
			if originalPosition and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				player.Character.HumanoidRootPart.CFrame = originalPosition
			end
			originalPosition = nil

			-- Clean up fling effects
			local character = player.Character
			if character then
				-- Remove BodyAngularVelocity
				local root = character:FindFirstChild("HumanoidRootPart")
				if root then
					for _, v in pairs(root:GetChildren()) do
						if v.Name == "ADONIS_FLIGHT_POSITION" then
							v:Destroy()
						end
					end
				end

				-- Reset part properties
				for _, child in pairs(character:GetDescendants()) do
					if child:IsA("BasePart") then
						child.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
						child.CanCollide = true
						child.Massless = false
					end
				end
			end

			processCommand("clip") -- Re-enable clipping
			targetPlayer = nil

			return "Stopped flinging"
		end
	}

	for cmd in fullInput:gmatch("([^,]+)") do
		cmd = cmd:gsub("^%s*(.-)%s*$", "%1")
		local cmdName = cmd:match("^(%S+)") or ""
		local args = cmd:sub(#cmdName + 1) or ""

		if cmdName ~= "" then
			cmdName = cmdName:lower()

			-- Check for aliases before checking valid commands
			if aliases[cmdName] then
				cmdName = aliases[cmdName]
			end

			if validcmds[cmdName] then
				Exec:Play()
				local handler = commandHandlers[cmdName]
				local resultMessage = handler and handler(args) or cmdName .. " executed (default)"
				local coloredCmd = string.format('<font color="%s">%s</font>', TextColors.Valid, cmdName)
				print(coloredCmd .. " - " .. resultMessage)
			else
				Error:Play()
				local coloredCmd = string.format('<font color="%s">%s</font>', TextColors.Invalid, cmdName)
				print("Unknown command: "..coloredCmd)
			end
		end
	end

	input.Text = ""
	input:ReleaseFocus()
	active = false
	updateBar()
end

-- Input handling
input:GetPropertyChangedSignal("Text"):Connect(function()
	updateAutocomplete()
end)

input.FocusLost:Connect(function(enterPressed)
	if enterPressed then processCommand(input.Text) end
end)

-- Toggle with M key
UIS.InputBegan:Connect(function(inputObj, gpe)
	if gpe then return end

	if inputObj.KeyCode == Enum.KeyCode.M then
		active = not active
		updateBar()
		if active then
			task.wait(0.2)
			input.Text = ""
			input:CaptureFocus()
		end
	end
end)

input.InputBegan:Connect(function(inputObj)
	if inputObj.KeyCode == Enum.KeyCode.Tab and underlay.Text ~= "" then
		input.Text = underlay.Text
		-- Move cursor to end
		input.CursorPosition = #input.Text + 1
	end
end)

-- Click outside to close
UIS.InputBegan:Connect(function(inputObj, gpe)
	if gpe or not active or inputObj.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local absPos = bar.AbsolutePosition
	local absSize = bar.AbsoluteSize
	local mousePos = UIS:GetMouseLocation()
	mousePos = Vector2.new(mousePos.X, mousePos.Y - 36)

	if not (mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X
		and mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y) then
		active = false
		updateBar()
	end
end)

updateBar()
