local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local DEBOUNCE_TIME = 0.25
local lastRun = 0

local function run()
    local currentTime = tick()
    if currentTime - lastRun < DEBOUNCE_TIME then return end
    lastRun = currentTime
    for _, conn in pairs(getconnections(char.DescendantAdded)) do
        conn:Disable()
    end
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remoteFolder = ReplicatedStorage:FindFirstChild("Remote")
    if remoteFolder then
        local actionEvent = remoteFolder:FindFirstChild("ActionEvent")
        if actionEvent then
            actionEvent:Destroy()
        else
        end
    end
end

run()

plr.CharacterAdded:Connect(function(newChar)
    char = newChar
    run()
end)

while true do
    run()
    wait(DEBOUNCE_TIME)
end
