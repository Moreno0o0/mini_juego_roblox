--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Network = require(ReplicatedStorage.Shared.Network)
local MinigameLevelsData = require(ReplicatedStorage.Shared.Config.MinigameLevelsData)

local localPlayer = Players.LocalPlayer

local M3_TargetPractice = {}

local isRunning = false
local activeScreenGui: ScreenGui? = nil
local activeConnections: { RBXScriptConnection } = {}

type TargetInfo = {
	Id: string,
	IsPenalty: boolean,
	Button: ImageButton,
	SpawnTime: number,
	Lifespan: number,
	Pos: Vector2,
	Velocity: Vector2,
}

function M3_TargetPractice.StartMinigame(
	difficulty: number,
	token: string,
	onCompleted: (boolean, string?) -> ()
)
	if isRunning then
		return
	end
	isRunning = true

	local levelData = MinigameLevelsData.GetLevel(3, difficulty)
	local tpConfig = levelData and levelData.Specific.TargetPractice or {
		TargetCount = 6,
		TargetLifespan = 2.5,
		PenaltyDecoyCount = 0,
	}

	local curPlayer = localPlayer or Players.LocalPlayer
	local playerGui = curPlayer and curPlayer:FindFirstChild("PlayerGui") :: PlayerGui?
	local cam = Workspace.CurrentCamera

	-- Set Camera to first-person view inside Chamber 3 Shooting Gallery
	local originalCameraType = if cam then cam.CameraType else Enum.CameraType.Custom
	local originalCameraCFrame = if cam then cam.CFrame else CFrame.identity
	pcall(function()
		if cam then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.new(Vector3.new(340, -174, -27), Vector3.new(340, -172, 36))
		end
	end)

	-- GUI Viewport / Shooting Gallery Container
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "M3_TargetPractice_Gui"
	screenGui.ResetOnSpawn = false
	if playerGui then
		screenGui.Parent = playerGui
	end
	activeScreenGui = screenGui

	local mainContainer = Instance.new("Frame")
	mainContainer.Name = "ArcadeBooth"
	mainContainer.Size = UDim2.fromScale(0.7, 0.75)
	mainContainer.Position = UDim2.fromScale(0.15, 0.12)
	mainContainer.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
	mainContainer.BorderSizePixel = 0
	mainContainer.Parent = screenGui

	local boothCorner = Instance.new("UICorner")
	boothCorner.CornerRadius = UDim.new(0, 12)
	boothCorner.Parent = mainContainer

	local boothStroke = Instance.new("UIStroke")
	boothStroke.Color = Color3.fromRGB(0, 200, 255)
	boothStroke.Thickness = 3
	boothStroke.Parent = mainContainer

	-- Header / Stats
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromScale(1, 0.12)
	header.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
	header.BorderSizePixel = 0
	header.Parent = mainContainer

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(0.45, 1)
	titleLabel.Position = UDim2.fromScale(0.03, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("GALERÍA DE TIRO (Nivel %d)", difficulty)
	titleLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = header

	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.fromScale(0.45, 1)
	scoreLabel.Position = UDim2.fromScale(0.52, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = string.format("Dianas: 0 / %d", tpConfig.TargetCount)
	scoreLabel.TextColor3 = Color3.fromRGB(255, 220, 0)
	scoreLabel.TextScaled = true
	scoreLabel.Font = Enum.Font.GothamBold
	scoreLabel.Parent = header

	-- Gallery Viewport Area
	local galleryFrame = Instance.new("Frame")
	galleryFrame.Name = "GalleryArea"
	galleryFrame.Size = UDim2.fromScale(0.94, 0.82)
	galleryFrame.Position = UDim2.fromScale(0.03, 0.15)
	galleryFrame.BackgroundColor3 = Color3.fromRGB(22, 28, 42)
	galleryFrame.ClipsDescendants = true
	galleryFrame.BorderSizePixel = 0
	galleryFrame.Parent = mainContainer

	local galleryCorner = Instance.new("UICorner")
	galleryCorner.CornerRadius = UDim.new(0, 8)
	galleryCorner.Parent = galleryFrame

	-- Custom Reticle
	local reticle = Instance.new("ImageLabel")
	reticle.Name = "Crosshair"
	reticle.Size = UDim2.fromOffset(36, 36)
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.BackgroundTransparency = 1
	reticle.Image = "rbxassetid://6031075931" -- Standard target reticle or circular asset
	reticle.ImageColor3 = Color3.fromRGB(0, 255, 200)
	reticle.Visible = false
	reticle.Parent = galleryFrame

	-- Game Variables and Set Relations
	-- T_active = { t_1, ..., t_m }, T_penalty = { p_1, ..., p_k }
	local activeTargets: { [string]: TargetInfo } = {}
	local penaltyTargets: { [string]: TargetInfo } = {}
	local targetCounter = 0
	local targetsHit = 0
	local penaltyHits = 0
	local missesCount = 0
	local maxMisses = if difficulty >= 4 then 2 else 3
	local startTime = os.clock()

	scoreLabel.Text = string.format("Dianas: 0 / %d | Fallos: 0/%d", tpConfig.TargetCount, maxMisses)

	local function Cleanup()
		isRunning = false
		for _, conn in ipairs(activeConnections) do
			conn:Disconnect()
		end
		table.clear(activeConnections)

		pcall(function()
			if cam then
				cam.CameraType = originalCameraType
				cam.CFrame = originalCameraCFrame
			end
		end)

		if activeScreenGui then
			activeScreenGui:Destroy()
			activeScreenGui = nil
		end
	end

	local function PlayHitSound(isSuccess: boolean)
		local sound = Instance.new("Sound")
		sound.SoundId = if isSuccess then "rbxasset://sounds/electronicpingshort.wav" else "rbxasset://sounds/bass.wav"
		sound.Volume = 0.6
		sound.Parent = Workspace
		sound:Play()
		task.delay(1, function()
			sound:Destroy()
		end)
	end

	local function RemoveTarget(targetId: string, fromPenalty: boolean)
		-- Discrete Set Difference: T_active' = T_active \ { t_i }
		local target = if fromPenalty then penaltyTargets[targetId] else activeTargets[targetId]
		if target then
			if fromPenalty then
				penaltyTargets[targetId] = nil
			else
				activeTargets[targetId] = nil
			end
			target.Button:Destroy()
		end
	end

	local function SpawnTarget(isPenalty: boolean)
		if not isRunning then
			return
		end
		targetCounter += 1
		local targetId = "target_" .. tostring(targetCounter)

		local targetBtn = Instance.new("ImageButton")
		targetBtn.Name = targetId

		-- Scale target size by difficulty (smaller on higher difficulty)
		local baseW = math.max(0.065, 0.12 - (difficulty * 0.012))
		local baseH = math.max(0.085, 0.15 - (difficulty * 0.015))
		targetBtn.Size = UDim2.fromScale(baseW, baseH)

		local posX = math.random(8, 78) / 100
		local posY = math.random(8, 72) / 100
		targetBtn.Position = UDim2.fromScale(posX, posY)
		targetBtn.BackgroundColor3 = if isPenalty then Color3.fromRGB(220, 30, 30) else Color3.fromRGB(0, 180, 255)
		targetBtn.BorderSizePixel = 0
		targetBtn.AutoButtonColor = false

		local tCorner = Instance.new("UICorner")
		tCorner.CornerRadius = UDim.new(1, 0) -- Circular target
		tCorner.Parent = targetBtn

		local tStroke = Instance.new("UIStroke")
		tStroke.Color = if isPenalty then Color3.fromRGB(255, 100, 100) else Color3.fromRGB(255, 255, 255)
		tStroke.Thickness = 2
		tStroke.Parent = targetBtn

		local centerDot = Instance.new("Frame")
		centerDot.Name = "Bullseye"
		centerDot.Size = UDim2.fromScale(0.35, 0.35)
		centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
		centerDot.Position = UDim2.fromScale(0.5, 0.5)
		centerDot.BackgroundColor3 = if isPenalty then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 40, 40)
		centerDot.BorderSizePixel = 0
		centerDot.Parent = targetBtn

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = centerDot

		targetBtn.Parent = galleryFrame

		-- Velocity for dynamic moving targets
		local moveSpeed = 0.04 + (difficulty * 0.035)
		local angle = math.random() * math.pi * 2
		local vel = Vector2.new(math.cos(angle) * moveSpeed, math.sin(angle) * moveSpeed)

		local info: TargetInfo = {
			Id = targetId,
			IsPenalty = isPenalty,
			Button = targetBtn,
			SpawnTime = os.clock(),
			Lifespan = tpConfig.TargetLifespan,
			Pos = Vector2.new(posX, posY),
			Velocity = vel,
		}

		if isPenalty then
			penaltyTargets[targetId] = info
		else
			activeTargets[targetId] = info
		end

		-- Target click handler (Directed Ray / Hit projection, compatible with PC and Mobile)
		targetBtn.Activated:Connect(function()
			if not isRunning then
				return
			end

			if isPenalty then
				penaltyHits += 1
				PlayHitSound(false)
				RemoveTarget(targetId, true)

				-- In high difficulties (d >= 4), hitting penalty decoy terminates attempt
				if difficulty >= 4 then
					Cleanup()
					local submitRemote = Network.GetRemote("SubmitMinigameResult")
					submitRemote:FireServer(3, difficulty, os.clock() - startTime, token, {
						TargetsHit = targetsHit,
						PenaltyHits = penaltyHits,
					})
					onCompleted(false, "Penalización activada: Impactaste una diana trampa")
					return
				end
			else
				targetsHit += 1
				scoreLabel.Text = string.format("Dianas: %d / %d | Fallos: %d/%d", targetsHit, tpConfig.TargetCount, missesCount, maxMisses)
				PlayHitSound(true)
				RemoveTarget(targetId, false)

				-- Check victory condition
				if targetsHit >= tpConfig.TargetCount then
					Cleanup()
					local totalDuration = os.clock() - startTime
					local submitRemote = Network.GetRemote("SubmitMinigameResult")
					submitRemote:FireServer(3, difficulty, totalDuration, token, {
						TargetsHit = targetsHit,
						PenaltyHits = penaltyHits,
					})
					onCompleted(true, nil)

					-- Auto-advance toast banner
					local toastGui = Instance.new("ScreenGui")
					toastGui.Name = "AutoAdvanceToast_M3"
					toastGui.ResetOnSpawn = false
					if playerGui then
						toastGui.Parent = playerGui
					end

					local banner = Instance.new("Frame")
					banner.Name = "ToastBanner"
					banner.Size = UDim2.fromScale(0.56, 0.08)
					banner.Position = UDim2.fromScale(0.22, 0.04)
					banner.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
					banner.BorderSizePixel = 0
					banner.Parent = toastGui

					local bCorner = Instance.new("UICorner")
					bCorner.CornerRadius = UDim.new(0, 10)
					bCorner.Parent = banner

					local bStroke = Instance.new("UIStroke")
					bStroke.Color = Color3.fromRGB(0, 220, 255)
					bStroke.Thickness = 2.5
					bStroke.Parent = banner

					local bText = Instance.new("TextLabel")
					bText.Size = UDim2.fromScale(1, 1)
					bText.BackgroundTransparency = 1
					bText.Text = "🏆 ¡SALA 3 SUPERADA! >> AVANZANDO A SALA 4 (+25 CRÉDITOS)"
					bText.TextColor3 = Color3.fromRGB(255, 215, 0)
					bText.TextScaled = true
					bText.Font = Enum.Font.GothamBlack
					bText.Parent = banner

					task.delay(2.5, function()
						if toastGui and toastGui.Parent then
							local tw = TweenService:Create(banner, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
							tw:Play()
							task.wait(0.4)
							toastGui:Destroy()
						end
					end)
					return
				end
			end
		end)

		-- Animated shrink during lifespan
		local shrinkTween = TweenService:Create(
			targetBtn,
			TweenInfo.new(tpConfig.TargetLifespan, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(0.02, 0.03) }
		)
		shrinkTween:Play()
	end

	-- Update reticle cursor position on mouse / touch movement
	local moveConn = UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local mousePos: Vector3 = input.Position
			local framePos: Vector2 = galleryFrame.AbsolutePosition
			reticle.Visible = true
			reticle.Position = UDim2.fromOffset(mousePos.X - framePos.X, mousePos.Y - framePos.Y)
		end
	end)
	table.insert(activeConnections, moveConn)

	-- Dynamic Movement for moving targets
	local moveTargetsConn = RunService.RenderStepped:Connect(function(dt: number)
		if not isRunning then
			return
		end

		for _, target in pairs(activeTargets) do
			local curX = target.Pos.X + target.Velocity.X * dt
			local curY = target.Pos.Y + target.Velocity.Y * dt
			local velX = target.Velocity.X
			local velY = target.Velocity.Y

			if curX <= 0.04 or curX >= 0.86 then
				velX = -velX
				curX = math.clamp(curX, 0.04, 0.86)
			end
			if curY <= 0.04 or curY >= 0.80 then
				velY = -velY
				curY = math.clamp(curY, 0.04, 0.80)
			end

			target.Pos = Vector2.new(curX, curY)
			target.Velocity = Vector2.new(velX, velY)
			target.Button.Position = UDim2.fromScale(curX, curY)
		end

		for _, target in pairs(penaltyTargets) do
			local curX = target.Pos.X + target.Velocity.X * dt
			local curY = target.Pos.Y + target.Velocity.Y * dt
			local velX = target.Velocity.X
			local velY = target.Velocity.Y

			if curX <= 0.04 or curX >= 0.86 then
				velX = -velX
				curX = math.clamp(curX, 0.04, 0.86)
			end
			if curY <= 0.04 or curY >= 0.80 then
				velY = -velY
				curY = math.clamp(curY, 0.04, 0.80)
			end

			target.Pos = Vector2.new(curX, curY)
			target.Velocity = Vector2.new(velX, velY)
			target.Button.Position = UDim2.fromScale(curX, curY)
		end
	end)
	table.insert(activeConnections, moveTargetsConn)

	-- Spawner and Lifespan lifecycle loop
	task.spawn(function()
		local spawnInterval = math.clamp(tpConfig.TargetLifespan * 0.65, 0.35, 1.8)
		local nextSpawn = os.clock()

		while isRunning do
			local now = os.clock()

			-- Expire old targets: T_active' = T_active \ { t | now - t.SpawnTime >= t.Lifespan }
			for id, target in pairs(activeTargets) do
				if (now - target.SpawnTime) >= target.Lifespan then
					RemoveTarget(id, false)
					missesCount += 1
					scoreLabel.Text = string.format("Dianas: %d / %d | Fallos: %d/%d", targetsHit, tpConfig.TargetCount, missesCount, maxMisses)
					PlayHitSound(false)

					if missesCount >= maxMisses then
						Cleanup()
						local submitRemote = Network.GetRemote("SubmitMinigameResult")
						submitRemote:FireServer(3, difficulty, os.clock() - startTime, token, {
							TargetsHit = targetsHit,
							PenaltyHits = penaltyHits,
						})
						onCompleted(false, "Límite de fallos alcanzado en Sala 3")
						return
					end
				end
			end
			for id, target in pairs(penaltyTargets) do
				if (now - target.SpawnTime) >= target.Lifespan then
					RemoveTarget(id, true)
				end
			end

			-- Spawn new targets
			if now >= nextSpawn then
				nextSpawn = now + spawnInterval

				-- Determine if this should spawn a penalty decoy
				local shouldSpawnDecoy = (tpConfig.PenaltyDecoyCount > 0) and (math.random(1, 10) <= 3)
				if shouldSpawnDecoy then
					SpawnTarget(true)
				else
					SpawnTarget(false)
				end
			end

			task.wait(0.04)
		end
	end)
end

function M3_TargetPractice.Init()
	Network.InitializeRemotes()
	local startRemote = Network.GetRemote("StartMinigameClient")
	startRemote.OnClientEvent:Connect(function(machineId: any, difficulty: any, _duration: any, token: any)
		if machineId == 3 and typeof(token) == "string" then
			M3_TargetPractice.StartMinigame(difficulty or 1, token, function(win, reason)
				print(string.format("TargetPractice result: %s (Reason: %s)", tostring(win), tostring(reason)))
			end)
		end
	end)
end

return M3_TargetPractice
