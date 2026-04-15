local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if method == "FireServer" and self.ClassName == "RemoteEvent" then
        if self.Name == "BadActionEvent" then
            return 
        end
    end

    return oldNamecall(self, ...)
end)

local oldIndex
oldIndex = hookmetamethod(game, "__index", function(self, key)
    if not checkcaller() and (key == "ADONIS_FLIGHT_POSITION" or key == "QuicksilverVelocity") then
        return nil
    end
    return oldIndex(self, key)
end)

print("Anti-Cheat has been successfully fucked.")
