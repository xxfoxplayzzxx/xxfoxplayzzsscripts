local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Configuration
local DRAG_THRESHOLD = 10 -- Minimum movement to be considered a "drag"
local TAP_THRESHOLD = 0.2 -- Maximum time for a tap

local touchStartPos = nil
local touchStartTime = nil
local isDragging = false

-- Function to simulate Left Click (Tap)
local function handleTap()
	-- Simulating Click (Left Click)
	print("Left Clicked")
	-- You can fire a RemoteEvent here to trigger tools
end

-- Function to simulate Right Click (Hold/Drag)
local function handleRightClick()
	print("Right Clicked")
	-- You can fire a RemoteEvent here
end

UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
	if gameProcessed then return end
	touchStartPos = touch.Position
	touchStartTime = tick()
	isDragging = false
end)

UserInputService.TouchMoved:Connect(function(touch, gameProcessed)
	if gameProcessed then return end
	if touchStartPos and (touch.Position - touchStartPos).Magnitude > DRAG_THRESHOLD then
		if not isDragging then
			isDragging = true
			handleRightClick()
		end
	end
end)

UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
	if gameProcessed then return end
	if touchStartTime and not isDragging then
		if (tick() - touchStartTime) < TAP_THRESHOLD then
			handleTap()
		end
	end
	
	touchStartPos = nil
	touchStartTime = nil
	isDragging = false
end)
