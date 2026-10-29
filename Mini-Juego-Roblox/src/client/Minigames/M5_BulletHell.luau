--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Shared.Network)
local MinigameLevelsData = require(ReplicatedStorage.Shared.Config.MinigameLevelsData)

local localPlayer = Players.LocalPlayer

local M5_BulletHell = {}

type Projectile = {
	Part: Part,
	InitialAngle: number,
	Speed: number,
	Direction: Vector3,
	Radius: number,
	Pattern: "Linear" | "Circular" | "Cross" | "Helical" | "RadialHelical",
}

local isRunning = false
local activeConnection: RBXScriptConnection? = nil
local activeHud: ScreenGui? = nil
local activeProjectilesFolder: Folder? = nil

function M5_BulletHell.StopMinigame()
	isRunning = false
	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end
	local cam = Workspace.CurrentCamera
	if cam then
		pcall(function()
			cam.CameraType = Enum.CameraType.Custom
		end)
	end
	if activeProjectilesFolder then
		activeProjectilesFolder:Destroy()
		activeProjectilesFolder = nil
	end
	if activeHud then
		activeHud:Destroy()
		activeHud = nil
	end
	local curPlayer = localPlayer or Players.LocalPlayer
	local playerGui = curPlayer and curPlayer:FindFirstChild("PlayerGui") :: PlayerGui?
	if playerGui then
		for _, child in ipairs(playerGui:GetChildren()) do
			if child.Name == "M5_BulletHell_HUD" then
				child:Destroy()
			end
		end
	end
end

function M5_BulletHell.IsRunning(): boolean
	return isRunning
end

function M5_BulletHell.StartMinigame(
	difficulty: number,
	token: string,
	onCompleted: (boolean, string?) -> ()
)
	if isRunning then
		return
	end
	isRunning = true

	local curPlayer = localPlayer or Players.LocalPlayer
	local playerGui = curPlayer and curPlayer:FindFirstChild("PlayerGui") :: PlayerGui?
	local camera = Workspace.CurrentCamera

	local levelData = MinigameLevelsData.GetLevel(5, difficulty)
	local bhConfig = levelData and levelData.Specific.BulletHell or {
		ProjectileCount = 4,
		PatternType = "Linear" :: "Linear" | "Circular" | "Cross" | "Helical" | "RadialHelical",
		SurvivalDuration = 15,
	}

	local world = Workspace:FindFirstChild("World")
	local chamber = world and world:FindFirstChild("Zones") and world.Zones:FindFirstChild("Zone_5") and world.Zones.Zone_5:FindFirstChild("MinigameChamber_5")
	local chamberCenter = Vector3.new(700, -179, 0)
	if chamber and chamber:IsA("Model") and chamber.PrimaryPart then
		chamberCenter = chamber.PrimaryPart.Position + Vector3.new(0, 1.5, 0)
	end

	-- Teleport player into chamber
	local char = curPlayer and curPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.CFrame = CFrame.new(chamberCenter + Vector3.new(0, 3, 0))
	end

	-- Setup top-down zenith camera
	local originalCameraType = if camera then camera.CameraType else Enum.CameraType.Custom
	local originalCameraCFrame = if camera then camera.CFrame else CFrame.identity
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.new(chamberCenter + Vector3.new(0, 42, 0), chamberCenter)
	end

	-- HUD Display
	local hud = Instance.new("ScreenGui")
	hud.Name = "M5_BulletHell_HUD"
	hud.ResetOnSpawn = false
	if playerGui then
		hud.Parent = playerGui
	end
	activeHud = hud

	local timerFrame = Instance.new("Frame")
	timerFrame.Name = "TimerCard"
	timerFrame.Size = UDim2.fromScale(0.32, 0.08)
	timerFrame.Position = UDim2.fromScale(0.34, 0.03)
	timerFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
	timerFrame.BorderSizePixel = 0
	timerFrame.Parent = hud

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 8)
	tCorner.Parent = timerFrame

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = Color3.fromRGB(255, 60, 100)
	tStroke.Thickness = 2
	tStroke.Parent = timerFrame

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerText"
	timerLabel.Size = UDim2.fromScale(1, 1)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = string.format("SOBREVIVE: %.1fs (Nivel %d)", bhConfig.SurvivalDuration, difficulty)
	timerLabel.TextColor3 = Color3.fromRGB(255, 80, 120)
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.Parent = timerFrame

	-- Spawn Projectile Container
	local projFolder = Instance.new("Folder")
	projFolder.Name = "BulletHellProjectiles"
	projFolder.Parent = Workspace
	activeProjectilesFolder = projFolder

	local arenaRadius = 22.0
	local playerRadius = 1.6
	local projectileRadius = 1.0

	-- Instantiate Dynamic Set of Projectiles B(t) = {b_1, ..., b_k}
	local projectiles: { Projectile } = {}
	for i = 1, bhConfig.ProjectileCount do
		local angle = (i / bhConfig.ProjectileCount) * (2 * math.pi)
		local part = Instance.new("Part")
		part.Name = "Bullet_" .. i
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(projectileRadius * 2, projectileRadius * 2, projectileRadius * 2)
		local bulletColor = if difficulty >= 4 then Color3.fromRGB(255, 30, 200) else Color3.fromRGB(255, 60, 40)
		part.Color = bulletColor
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = false

		local bLight = Instance.new("PointLight")
		bLight.Brightness = 1.8
		bLight.Range = 8
		bLight.Color = bulletColor
		bLight.Parent = part

		local dist = 8 + (i % 3) * 5
		part.CFrame = CFrame.new(chamberCenter + Vector3.new(math.cos(angle) * dist, 1.5, math.sin(angle) * dist))
		part.Parent = projFolder

		table.insert(projectiles, {
			Part = part,
			InitialAngle = angle,
			Speed = 8 + (difficulty * 2.5),
			Direction = Vector3.new(math.cos(angle + math.pi / 2), 0, math.sin(angle + math.pi / 2)).Unit,
			Radius = projectileRadius,
			Pattern = bhConfig.PatternType,
		})
	end

	local startTime = os.clock()

	local function Cleanup()
		isRunning = false
		if activeConnection then
			activeConnection:Disconnect()
			activeConnection = nil
		end
		if camera then
			pcall(function()
				camera.CameraType = originalCameraType
				camera.CFrame = originalCameraCFrame
			end)
		end
		if activeProjectilesFolder then
			activeProjectilesFolder:Destroy()
			activeProjectilesFolder = nil
		end
		if activeHud then
			activeHud:Destroy()
			activeHud = nil
		end
	end

	activeConnection = RunService.Heartbeat:Connect(function()
		if not isRunning then
			return
		end

		local t = os.clock() - startTime
		local remainingTime = bhConfig.SurvivalDuration - t
		if remainingTime > 0 then
			timerLabel.Text = string.format("SOBREVIVE: %.1fs (Nivel %d)", remainingTime, difficulty)
		end

		local currentHrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local pPos = if currentHrp then currentHrp.Position else chamberCenter

		-- Spatial Fail-Safe: If player is outside Chamber 5 (e.g. teleported back to arena at Y > -100 or far away)
		-- Grace period of 2.5 seconds during initial teleportation
		if t > 2.5 and (pPos.Y > -100 or math.abs(pPos.X - chamberCenter.X) > 70 or math.abs(pPos.Z - chamberCenter.Z) > 70) then
			Cleanup()
			return
		end

		-- Update projectile positions along their parametric curves
		for idx, proj in ipairs(projectiles) do
			local currentPos: Vector3

			if proj.Pattern == "Linear" then
				-- Linear trajectory reflecting off arena boundary
				local cur = proj.Part.Position - chamberCenter
				local newCur = cur + (proj.Direction * (proj.Speed * 0.016))
				local dist2D = Vector2.new(newCur.X, newCur.Z).Magnitude
				if dist2D >= arenaRadius then
					-- Reflect direction vector
					local normal = Vector3.new(newCur.X, 0, newCur.Z).Unit
					proj.Direction = (proj.Direction - 2 * (proj.Direction:Dot(normal)) * normal).Unit
					newCur = normal * (arenaRadius - 0.5)
				end
				currentPos = chamberCenter + Vector3.new(newCur.X, 1.5, newCur.Z)
			elseif proj.Pattern == "Circular" then
				local curAngle = proj.InitialAngle + (t * (proj.Speed * 0.1))
				local r = 12 + math.sin(t * 2 + idx) * 6
				currentPos = chamberCenter + Vector3.new(math.cos(curAngle) * r, 1.5, math.sin(curAngle) * r)
			elseif proj.Pattern == "Cross" then
				local axis = (idx % 2 == 0) and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
				local offset = math.sin(t * (proj.Speed * 0.15) + idx) * (arenaRadius * 0.85)
				local perp = (idx % 2 == 0) and Vector3.new(0, 0, ((idx % 4) - 2) * 4) or Vector3.new(((idx % 4) - 2) * 4, 0, 0)
				currentPos = chamberCenter + (axis * offset) + perp + Vector3.new(0, 1.5, 0)
			elseif proj.Pattern == "Helical" then
				-- Parametric Archimedean / Logarithmic Spiral
				local omega = 2.2
				local curAngle = proj.InitialAngle + (t * omega)
				local spiralRadius = ((t * proj.Speed + (idx * 3)) % arenaRadius) + 2
				currentPos = chamberCenter + Vector3.new(math.cos(curAngle) * spiralRadius, 1.5, math.sin(curAngle) * spiralRadius)
			else -- "RadialHelical" (Difficulty 5 storm)
				local ringDir = (idx % 2 == 0) and 1 or -1
				local omega = 2.8 * ringDir
				local curAngle = proj.InitialAngle + (t * omega)
				local rWave = 4 + (((t * 12 + idx * 2.5) % (arenaRadius - 4)))
				currentPos = chamberCenter + Vector3.new(math.cos(curAngle) * rWave, 1.5, math.sin(curAngle) * rWave)
			end

			proj.Part.CFrame = CFrame.new(currentPos)

			-- Metric Collision Test: ||x_p(t) - x_b(t)|| <= r_p + r_b (with 1.2s start grace)
			local delta = pPos - currentPos
			local distance2D = Vector2.new(delta.X, delta.Z).Magnitude
			if t > 1.2 and distance2D <= (playerRadius + proj.Radius) then
				-- Collision detected! Non-empty intersection: Fail
				Cleanup()
				local submitRemote = Network.GetRemote("SubmitMinigameResult")
				submitRemote:FireServer(5, difficulty, t, token, {
					Survived = false,
					HitDetected = true,
				})
				onCompleted(false, "Impactado por proyectil en Bullet Hell")
				return
			end
		end

		-- Check Victory Condition (survived entire T_d)
		if t >= bhConfig.SurvivalDuration then
			Cleanup()
			local submitRemote = Network.GetRemote("SubmitMinigameResult")
			submitRemote:FireServer(5, difficulty, t, token, {
				Survived = true,
				HitDetected = false,
			})
			onCompleted(true, nil)

			local toastGui = Instance.new("ScreenGui")
			toastGui.Name = "AutoAdvanceToast_M5"
			toastGui.ResetOnSpawn = false
			if playerGui then
				toastGui.Parent = playerGui
			end

			local banner = Instance.new("Frame")
			banner.Name = "ToastBanner"
			banner.Size = UDim2.fromScale(0.60, 0.08)
			banner.Position = UDim2.fromScale(0.20, 0.04)
			banner.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
			banner.BorderSizePixel = 0
			banner.Parent = toastGui

			local bCorner = Instance.new("UICorner")
			bCorner.CornerRadius = UDim.new(0, 10)
			bCorner.Parent = banner

			local bStroke = Instance.new("UIStroke")
			bStroke.Color = Color3.fromRGB(255, 215, 0)
			bStroke.Thickness = 2.5
			bStroke.Parent = banner

			local bText = Instance.new("TextLabel")
			bText.Size = UDim2.fromScale(1, 1)
			bText.BackgroundTransparency = 1
			bText.Text = "👑 ¡COLISEO COMPLETADO! ¡HAS DOMINADO TODAS LAS MÁQUINAS! 👑"
			bText.TextColor3 = Color3.fromRGB(255, 215, 0)
			bText.TextScaled = true
			bText.Font = Enum.Font.GothamBlack
			bText.Parent = banner

			task.delay(3.5, function()
				if toastGui and toastGui.Parent then
					local tw = TweenService:Create(banner, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
					tw:Play()
					task.wait(0.4)
					toastGui:Destroy()
				end
			end)
			return
		end
	end)
end

function M5_BulletHell.Init()
	Network.InitializeRemotes()
	local startRemote = Network.GetRemote("StartMinigameClient")
	startRemote.OnClientEvent:Connect(function(machineId: any, difficulty: any, _duration: any, token: any)
		if machineId == 5 and typeof(token) == "string" then
			M5_BulletHell.StartMinigame(difficulty or 1, token, function(win, reason)
				print(string.format("BulletHell result: %s (Reason: %s)", tostring(win), tostring(reason)))
			end)
		end
	end)

	local forceExitRemote = Network.GetRemote("ForceExitMachine")
	forceExitRemote.OnClientEvent:Connect(function()
		M5_BulletHell.StopMinigame()
	end)

	local syncRemote = Network.GetRemote("SyncState")
	syncRemote.OnClientEvent:Connect(function(arg1: any, arg2: any)
		local stateStr: string? = nil
		if typeof(arg1) == "string" then
			stateStr = arg1
		elseif typeof(arg1) == "table" and arg1.State ~= nil then
			stateStr = tostring(arg1.State)
		elseif typeof(arg2) == "table" and arg2.State ~= nil then
			stateStr = tostring(arg2.State)
		end

		if stateStr and stateStr ~= "Playing" and isRunning then
			M5_BulletHell.StopMinigame()
		end
	end)

	local curPlayer = localPlayer or Players.LocalPlayer
	if curPlayer then
		curPlayer.CharacterAdded:Connect(function(newChar)
			if isRunning then
				M5_BulletHell.StopMinigame()
			end
			local hum = newChar:WaitForChild("Humanoid", 5) :: Humanoid?
			if hum then
				hum.Died:Connect(function()
					if isRunning then
						M5_BulletHell.StopMinigame()
					end
				end)
			end
		end)

		if curPlayer.Character then
			local hum = curPlayer.Character:FindFirstChild("Humanoid") :: Humanoid?
			if hum then
				hum.Died:Connect(function()
					if isRunning then
						M5_BulletHell.StopMinigame()
					end
				end)
			end
		end
	end
end

return M5_BulletHell
