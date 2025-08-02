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
	local commandHandlers = {}
	local commandHandlers = {
		noclip = function()
			Clip = false
			task.wait(0.1)
			if NoclippingConnection then
				NoclippingConnection:Disconnect()
			end
			NoclippingConnection = RunService.Stepped:Connect(function()
				local character = player.Character
				if not character then return end
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = Clip == false or part.CanCollide
					end
				end
			end)

			return "Noclip enabled"
		end,
		clip = function()
			Clip = true
			if NoclippingConnection then
				NoclippingConnection:Disconnect()
				NoclippingConnection = nil
			end

			-- Re-enable collisions (optional, since Roblox does this automatically)
			local character = player.Character
			if character then
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = true
					end
				end
			end

			return "Noclip disabled"
		end,
		fly = function()
			if fly == false then
				fly = true

				-- Initialize flight system
				local RunService = game:GetService("RunService")
				local UserInputService = game:GetService("UserInputService")

				local directions = {
					Forward = false,
					Backward = false,
					Left = false,
					Right = false,
					Up = false,
					Down = false,
				}

				local maxSpeed = 3
				local speedIncrement = maxSpeed / 25
				local currentSpeed = 0

				local inputBeganConn, inputEndedConn, preRenderConn
				local bodyGyro, alignPos, humanoid, hrp
				local charAddedConn

				local function disconnectFlight()
					-- Disconnect all connections
					if inputBeganConn then 
						inputBeganConn:Disconnect()
						inputBeganConn = nil 
					end
					if inputEndedConn then 
						inputEndedConn:Disconnect()
						inputEndedConn = nil 
					end
					if preRenderConn then 
						preRenderConn:Disconnect()
						preRenderConn = nil 
					end
					if charAddedConn then
						charAddedConn:Disconnect()
						charAddedConn = nil
					end

					-- Clean up flight parts
					if hrp then
						if hrp:FindFirstChild("ADONIS_FLIGHT_POSITION") then
							hrp.ADONIS_FLIGHT_POSITION:Destroy()
						end
						if hrp:FindFirstChild("ADONIS_FLIGHT_GYRO") then
							hrp.ADONIS_FLIGHT_GYRO:Destroy()
						end
					end

					-- Reset character state
					if humanoid and humanoid.Parent then
						humanoid.PlatformStand = false
					end

					-- Disable noclip if the clip command exists
					if commandHandlers.clip then
						commandHandlers.clip()
					end

					fly = false
				end

				local function setupFlight(character)
					-- Safety checks
					if not character or not character:IsDescendantOf(workspace) then
						warn("Flight: Invalid character")
						return false
					end

					local success, err = pcall(function()
						-- Wait for necessary parts with timeout
						hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 2)
						humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChildOfClass("Humanoid", 2)

						if not hrp or not humanoid then
							error("Failed to find character parts")
						end

						-- Enable noclip if available
						if commandHandlers.noclip then
							commandHandlers.noclip()
						end

						-- Clean up any existing flight parts
						for _, name in pairs({"ADONIS_FLIGHT_POSITION", "ADONIS_FLIGHT_GYRO"}) do
							local part = hrp:FindFirstChild(name)
							if part then
								part:Destroy()
							end
						end

						-- Create new flight parts
						alignPos = Instance.new("BodyPosition")
						alignPos.Name = "ADONIS_FLIGHT_POSITION"
						alignPos.Position = hrp.Position
						alignPos.MaxForce = Vector3.new(9e9, 9e9, 9e9)
						alignPos.P = 1250
						alignPos.Parent = hrp

						bodyGyro = Instance.new("BodyGyro")
						bodyGyro.Name = "ADONIS_FLIGHT_GYRO"
						bodyGyro.P = 3000
						bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
						bodyGyro.Parent = hrp

						humanoid.PlatformStand = true

						-- Input handling
						inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
							if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

							if input.KeyCode == Enum.KeyCode.W then directions.Forward = true
							elseif input.KeyCode == Enum.KeyCode.S then directions.Backward = true
							elseif input.KeyCode == Enum.KeyCode.A then directions.Left = true
							elseif input.KeyCode == Enum.KeyCode.D then directions.Right = true
							elseif input.KeyCode == Enum.KeyCode.Space then directions.Up = true
							elseif input.KeyCode == Enum.KeyCode.Q then directions.Down = true
							elseif input.KeyCode == Enum.KeyCode.R then
								disconnectFlight()
							end
						end)

						inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
							if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

							if input.KeyCode == Enum.KeyCode.W then directions.Forward = false
							elseif input.KeyCode == Enum.KeyCode.S then directions.Backward = false
							elseif input.KeyCode == Enum.KeyCode.A then directions.Left = false
							elseif input.KeyCode == Enum.KeyCode.D then directions.Right = false
							elseif input.KeyCode == Enum.KeyCode.Space then directions.Up = false
							elseif input.KeyCode == Enum.KeyCode.Q then directions.Down = false
							end
						end)

						-- Movement handling
						preRenderConn = RunService.PreRender:Connect(function()
							-- Safety checks
							if not hrp or not hrp.Parent or not humanoid or not humanoid.Parent then
								disconnectFlight()
								return
							end

							local cam = workspace.CurrentCamera
							if not cam then return end

							local velocity = Vector3.new()

							-- Speed calculation
							if not (directions.Forward or directions.Backward or directions.Up or directions.Down or directions.Left or directions.Right) then
								currentSpeed = 0
							else
								currentSpeed = math.min(currentSpeed + speedIncrement, maxSpeed)
							end

							-- Movement directions
							if directions.Up then velocity += Vector3.new(0, currentSpeed, 0) end
							if directions.Down then velocity += Vector3.new(0, -currentSpeed, 0) end
							if directions.Forward then velocity += cam.CFrame.LookVector * currentSpeed end
							if directions.Backward then velocity -= cam.CFrame.LookVector * currentSpeed end
							if directions.Left then velocity -= cam.CFrame.RightVector * currentSpeed end
							if directions.Right then velocity += cam.CFrame.RightVector * currentSpeed end

							-- Apply movement
							alignPos.Position += velocity

							-- Update rotation
							local pos = hrp.Position
							bodyGyro.CFrame = CFrame.new(pos, pos + cam.CFrame.LookVector)
						end)
					end)

					if not success then
						warn("Flight setup failed: " .. tostring(err))
						disconnectFlight()
						return false
					end

					return true
				end

				-- Initial setup
				if player.Character then
					setupFlight(player.Character)
				end

				-- Handle character changes
				charAddedConn = player.CharacterAdded:Connect(function(character)
					setupFlight(character)
				end)

				-- Clean up when character is removed
				player.CharacterRemoving:Connect(disconnectFlight)

				return "Flight enabled (W/S/A/D/Space/Q to move, R to disable)"
			else
				-- Toggle flight off
				fly = false
				return "Flight disabled"
			end
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
			player.Character.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame

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
			targetPlayer = nil

			processCommand("noclip")
			task.wait(0.1)

			local character = player.Character
			if not character then return end
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if not rootPart or not humanoid then return end

			if targetName == "" then
				-- Self-fling (spin in place)
				rootPart.Anchored = true
				rootPart.Velocity = Vector3.new()
				rootPart.RotVelocity = Vector3.new()
				local bambam = Instance.new("BodyAngularVelocity")
				bambam.Name = "ADONIS_FLIGHT_POSITION"
				bambam.Parent = rootPart
				bambam.AngularVelocity = Vector3.new(0, 99999, 0)
				bambam.MaxTorque = Vector3.new(0, math.huge, 0)
				bambam.P = math.huge

				task.wait(0.1)
				rootPart.Anchored = false
				flinging = true
				return "Spinning in place"
			end

			-- Target player fling
			if targetName:lower() == "random" then
				local players = Players:GetPlayers()
				if #players > 0 then
					targetPlayer = players[math.random(1,#players)]
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

			if not targetPlayer then return "Player not found" end

			originalPosition = rootPart.CFrame
			humanoid.PlatformStand = true

			local bambam = Instance.new("BodyAngularVelocity")
			bambam.Name = "ADONIS_FLIGHT_POSITION"
			bambam.Parent = rootPart
			bambam.AngularVelocity = Vector3.new(20000, 20000, 20000)
			bambam.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			bambam.P = math.huge

			if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
				rootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
			end

			flinging = true
			local cycleStart = tick()

			flingLoop = RunService.Heartbeat:Connect(function()
				if not flinging then return end

				if tick() - cycleStart >= 1.5 then
					processCommand("unfling")
					return
				end

				if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
					rootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
				else
					processCommand("unfling")
				end
			end)

			return "Flinging "..targetPlayer.Name
		end,
		unfling = function()
			flinging = false

			if flingLoop then
				flingLoop:Disconnect()
				flingLoop = nil
			end

			local character = player.Character
			if not character then return end
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if rootPart then
				rootPart.Anchored = true
			end

			-- Re-enable R15 joints
			for _, v in pairs(character:GetDescendants()) do
				if v:IsA("Motor6D") then
					v.Enabled = true
				elseif v:IsA("BasePart") then
					v.Velocity = Vector3.new()
					v.RotVelocity = Vector3.new()
					for _, child in pairs(v:GetChildren()) do
						if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") then
							child:Destroy()
						end
					end
				end
			end

			if humanoid then
				humanoid.PlatformStand = false
				humanoid.AutoRotate = true
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end

			task.wait(0.3) -- Extra stabilization for R15

			if originalPosition and rootPart then
				rootPart.CFrame = originalPosition
				task.wait(0.1)
			end

			if rootPart then
				for _, v in pairs(rootPart:GetChildren()) do
					if v.Name == "ADONIS_FLIGHT_POSITION" then
						v:Destroy()
					end
				end
				rootPart.Anchored = false
			end

			targetPlayer = nil
			originalPosition = nil
			return "Stopped flinging"
		end,
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
