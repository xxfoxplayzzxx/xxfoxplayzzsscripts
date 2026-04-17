_G.Snail_Config = {
			TunnelOffset = CFrame.new(0, -10, 0),
			Teleport = Enum.KeyCode.E,
			Tunnel = Enum.KeyCode.Q,
			Speed = 0.6
		}

		local success, err = pcall(function()
			local UserInputService = game:GetService("UserInputService")
			local Players = game:GetService("Players")
			local RunService = game:GetService("RunService")
			local ContextActionService = game:GetService("ContextActionService")

			local LocalPlayer = Players.LocalPlayer
			local Mouse = LocalPlayer:GetMouse()
			local Camera = workspace.CurrentCamera
			local Config = _G.Snail_Config
			local IsTunneling = false

			local CameraPart = Instance.new("Part")
			CameraPart.Name = "TunnelAnchor"
			CameraPart.Anchored = true
			CameraPart.Transparency = 1
			CameraPart.Size = Vector3.new(1.5, 1.5, 1.5)
			CameraPart.Color = Color3.fromRGB(255, 170, 0)
			CameraPart.CanCollide = false
			CameraPart.Shape = Enum.PartType.Ball
			CameraPart.Material = Enum.Material.ForceField
			CameraPart.Parent = workspace

			local function SetupCharacter(char)
				if not char then return end
				local root = char:WaitForChild("HumanoidRootPart", 5)
				if not root then return end

				RunService.Stepped:Connect(function()
					-- Added safety check to prevent the 'Parent' member error
					if IsTunneling and char and char.Parent and root then
						root.Velocity = Vector3.zero
						root.RotVelocity = Vector3.zero

						root.CFrame = CameraPart.CFrame * Config.TunnelOffset

						for _, p in pairs(char:GetDescendants()) do
							if p:IsA("BasePart") then p.CanCollide = false end
						end
					end
				end)
			end

			LocalPlayer.CharacterAdded:Connect(SetupCharacter)
			if LocalPlayer.Character then SetupCharacter(LocalPlayer.Character) end

			RunService.RenderStepped:Connect(function()
				if not IsTunneling then 
					local char = LocalPlayer.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root then
						CameraPart.CFrame = root.CFrame
					end
					return 
				end

				local moveDir = Vector3.zero
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end

				if moveDir.Magnitude > 0 then
					moveDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
					CameraPart.CFrame = CameraPart.CFrame + (moveDir * Config.Speed)
				end
			end)

			ContextActionService:BindAction("TunnelToggle", function(_, state)
				if state == Enum.UserInputState.Begin then
					local char = LocalPlayer.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChild("Humanoid")

					IsTunneling = not IsTunneling

					if IsTunneling then
						if root then CameraPart.CFrame = root.CFrame end
						Camera.CameraSubject = CameraPart
						CameraPart.Transparency = 0.5
						if hum then hum.PlatformStand = true end
					else
						if root then root.CFrame = CameraPart.CFrame end
						Camera.CameraSubject = hum or char
						CameraPart.Transparency = 1
						if hum then hum.PlatformStand = false end
					end
				end
			end, true, Config.Tunnel)

			ContextActionService:BindAction("TunnelTP", function(_, state)
				if IsTunneling and state == Enum.UserInputState.Begin then
					CameraPart.CFrame = CFrame.new(Mouse.Hit.Position)
				end
			end, false, Config.Teleport)

			_G.Tunnel_Ran = true
		end)
