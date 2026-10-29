--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage.Shared.Network)
local MinigameLevelsData = require(ReplicatedStorage.Shared.Config.MinigameLevelsData)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local M1_ReflexQTE = {}

local activeScreenGui: ScreenGui? = nil
local isRunning = false
local FREEZE_ACTION_NAME = "M1_MovementFreezeAction"
local currentKeyProcessor: ((string) -> ())? = nil

function M1_ReflexQTE.ProcessKey(key: string)
	if currentKeyProcessor then
		currentKeyProcessor(key)
	end
end

-- Procedural SFX helper for Audio Pitch Scaling (Dopamine boost)
local function PlayDopamineChime(comboIndex: number)
	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.Name = "QTE_Chime"
		sound.SoundId = "rbxassetid://6895079853" -- Crisp feedback chime
		sound.Volume = 0.75
		-- Audio pitch scaling: frequency ascends as streak increases
		sound.PlaybackSpeed = math.clamp(1.0 + (comboIndex * 0.12), 1.0, 2.2)
		sound.Parent = Workspace
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		task.delay(1.5, function()
			if sound and sound.Parent then
				sound:Destroy()
			end
		end)
	end)
end

local function PlayFailureBuzzer()
	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.Name = "QTE_Fail"
		sound.SoundId = "rbxassetid://9114223170" -- Low error thud
		sound.Volume = 0.8
		sound.PlaybackSpeed = 0.7
		sound.Parent = Workspace
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		task.delay(1.5, function()
			if sound and sound.Parent then
				sound:Destroy()
			end
		end)
	end)
end

function M1_ReflexQTE.StartMinigame(
	difficulty: number,
	token: string,
	sequence: { string },
	distractors: { [number]: boolean },
	onCompleted: (boolean, string?) -> ()
)
	if isRunning then
		return
	end
	isRunning = true

	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local levelData = MinigameLevelsData.GetLevel(1, difficulty)
	local qteConfig = levelData and levelData.Specific.QTE or { SequenceLength = #sequence, WindowPerKey = 2.5, DistractorCount = 0 }

	-- 1. FREEZE CHARACTER MOVEMENT SO PRESSING WASD/SPACE DOES NOT MOVE THE CHARACTER
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?

	local prevWalkSpeed = if hum then hum.WalkSpeed else 16
	local prevJumpPower = if hum then hum.JumpPower else 50
	local prevJumpHeight = if hum then hum.JumpHeight else 7.2
	local wasAnchored = if hrp then hrp.Anchored else false

	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
	end
	if hrp then
		hrp.Anchored = true
	end

	local ProcessInputFunc: ((string) -> ())? = nil

	-- Intercept QTE keys directly and sink movement keys
	ContextActionService:BindActionAtPriority(
		FREEZE_ACTION_NAME,
		function(_actionName, inputState, inputObject)
			if inputState == Enum.UserInputState.Begin and ProcessInputFunc then
				local k = inputObject.KeyCode
				local keyStr: string? = nil
				if k == Enum.KeyCode.W then
					keyStr = "W"
				elseif k == Enum.KeyCode.A then
					keyStr = "A"
				elseif k == Enum.KeyCode.S then
					keyStr = "S"
				elseif k == Enum.KeyCode.D then
					keyStr = "D"
				elseif k == Enum.KeyCode.E then
					keyStr = "E"
				elseif k == Enum.KeyCode.Q then
					keyStr = "Q"
				elseif k == Enum.KeyCode.Space then
					keyStr = "Space"
				end
				if keyStr then
					ProcessInputFunc(keyStr)
				end
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 300,
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.E,
		Enum.KeyCode.Q,
		Enum.KeyCode.Space,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right
	)

	local function RestoreMovement()
		ContextActionService:UnbindAction(FREEZE_ACTION_NAME)
		currentKeyProcessor = nil
		if hum and hum.Parent then
			hum.WalkSpeed = prevWalkSpeed
			hum.JumpPower = prevJumpPower
			hum.JumpHeight = prevJumpHeight
		end
		if hrp and hrp.Parent then
			hrp.Anchored = wasAnchored
		end
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "M1_ReflexQTE_Gui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	activeScreenGui = screenGui

	-- Container Frame (responsive for Mobile and PC)
	local container = Instance.new("Frame")
	container.Name = "QTEContainer"
	if isMobile then
		container.Size = UDim2.fromScale(0.88, 0.74)
		container.Position = UDim2.fromScale(0.06, 0.13)
	else
		container.Size = UDim2.fromScale(0.44, 0.54)
		container.Position = UDim2.fromScale(0.28, 0.23)
	end
	container.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
	container.BorderSizePixel = 0
	container.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 220, 255)
	stroke.Thickness = 2.5
	stroke.Parent = container

	-- Header / Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 0.12)
	titleLabel.Position = UDim2.fromScale(0, 0.02)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("⚡ MÁQUINA 1: REFLEJOS QTE [NIVEL %d] ⚡", difficulty)
	titleLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = container

	-- Combo & Streak Badge (Dopamine Trigger)
	local comboBadge = Instance.new("TextLabel")
	comboBadge.Name = "ComboBadge"
	comboBadge.Size = UDim2.fromScale(0.4, 0.08)
	comboBadge.Position = UDim2.fromScale(0.3, 0.13)
	comboBadge.BackgroundTransparency = 1
	comboBadge.Text = "RACHA: x0 🔥"
	comboBadge.TextColor3 = Color3.fromRGB(255, 215, 0)
	comboBadge.TextScaled = true
	comboBadge.Font = Enum.Font.GothamBlack
	comboBadge.Parent = container

	-- Key prompt display card
	local keyCard = Instance.new("Frame")
	keyCard.Name = "KeyCard"
	keyCard.Size = if isMobile then UDim2.fromScale(0.46, 0.28) else UDim2.fromScale(0.42, 0.30)
	keyCard.Position = if isMobile then UDim2.fromScale(0.27, 0.21) else UDim2.fromScale(0.29, 0.21)
	keyCard.BackgroundColor3 = Color3.fromRGB(22, 28, 42)
	keyCard.BorderSizePixel = 0
	keyCard.Parent = container

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 12)
	cardCorner.Parent = keyCard

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(60, 120, 200)
	cardStroke.Thickness = 2.5
	cardStroke.Parent = keyCard

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyText"
	keyLabel.Size = UDim2.fromScale(1, 0.68)
	keyLabel.Position = UDim2.fromScale(0, 0.02)
	keyLabel.BackgroundTransparency = 1
	keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	keyLabel.TextScaled = true
	keyLabel.Font = Enum.Font.GothamBlack
	keyLabel.Parent = keyCard

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintText"
	hintLabel.Size = UDim2.fromScale(1, 0.25)
	hintLabel.Position = UDim2.fromScale(0, 0.7)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "¡PRESIONA LA TECLA!"
	hintLabel.TextColor3 = Color3.fromRGB(180, 210, 240)
	hintLabel.TextScaled = true
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.Parent = keyCard

	-- Timer bar
	local timerBarBg = Instance.new("Frame")
	timerBarBg.Name = "TimerBarBg"
	timerBarBg.Size = UDim2.fromScale(0.85, 0.05)
	timerBarBg.Position = if isMobile then UDim2.fromScale(0.075, 0.50) else UDim2.fromScale(0.075, 0.53)
	timerBarBg.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	timerBarBg.BorderSizePixel = 0
	timerBarBg.Parent = container

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = timerBarBg

	local timerFill = Instance.new("Frame")
	timerFill.Name = "TimerFill"
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = Color3.fromRGB(0, 255, 180)
	timerFill.BorderSizePixel = 0
	timerFill.Parent = timerBarBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = timerFill

	-- Interactive Touch/Click Button Pad
	local touchPad = Instance.new("Frame")
	touchPad.Name = "TouchPad"
	if isMobile then
		touchPad.Size = UDim2.fromScale(0.92, 0.40)
		touchPad.Position = UDim2.fromScale(0.04, 0.57)
	else
		touchPad.Size = UDim2.fromScale(0.92, 0.36)
		touchPad.Position = UDim2.fromScale(0.04, 0.60)
	end
	touchPad.BackgroundTransparency = 1
	touchPad.Parent = container

	-- Ergonomic 2-row layout: Row 1 = Q, W, E, Space | Row 2 = A, S, D
	local registeredButtons: { [string]: TextButton } = {}

	local row1Keys = { "Q", "W", "E", "Space" }
	local row2Keys = { "A", "S", "D" }

	local function CreateTouchButton(name: string, posX: number, posY: number, sizeX: number, sizeY: number)
		local btn = Instance.new("TextButton")
		btn.Name = "Btn_" .. name
		btn.Size = UDim2.fromScale(sizeX, sizeY)
		btn.Position = UDim2.fromScale(posX, posY)
		btn.BackgroundColor3 = if name == "Space" then Color3.fromRGB(35, 75, 115) else Color3.fromRGB(30, 42, 60)
		btn.TextColor3 = Color3.fromRGB(240, 245, 255)
		btn.Text = if name == "Space" then "␣ ESPACIO" else name
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = true

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 8)
		bCorner.Parent = btn

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = Color3.fromRGB(0, 180, 220)
		bStroke.Thickness = 1.5
		bStroke.Parent = btn

		btn.Parent = touchPad
		registeredButtons[name] = btn
	end

	-- Row 1: Q, W, E, Space
	for i, k in ipairs(row1Keys) do
		local width = if k == "Space" then 0.32 else 0.19
		local posX = (i - 1) * 0.22
		if k == "Space" then
			posX = 3 * 0.22
		end
		CreateTouchButton(k, posX, 0.04, width, 0.44)
	end

	-- Row 2: A, S, D
	for i, k in ipairs(row2Keys) do
		local width = 0.28
		local posX = 0.06 + (i - 1) * 0.31
		CreateTouchButton(k, posX, 0.52, width, 0.44)
	end

	-- Gameplay variables
	local currentStep = 1
	local comboStreak = 0
	local collectedInputs: { string } = {}
	local pressedTraps = false
	local startTime = os.clock()
	local stepStartTime = os.clock()

	-- Anti-rebote debounce filters
	local lastInputTimestamp = 0.0
	local lastAcceptedKey = ""
	local MIN_DEBOUNCE_SAME_KEY = 0.22
	local MIN_STEP_TRANSITION_COOLDOWN = 0.08

	local inputConn: RBXScriptConnection? = nil
	local buttonConns: { RBXScriptConnection } = {}

	local function CleanupConnections()
		RestoreMovement()
		currentKeyProcessor = nil
		ProcessInputFunc = nil
		if inputConn then
			inputConn:Disconnect()
			inputConn = nil
		end
		for _, conn in ipairs(buttonConns) do
			conn:Disconnect()
		end
		table.clear(buttonConns)
	end

	local function HighlightTargetButton(target: string, isTrap: boolean)
		for btnKey, btn in pairs(registeredButtons) do
			local bStroke = btn:FindFirstChildOfClass("UIStroke")
			if btnKey == target then
				if isTrap then
					btn.BackgroundColor3 = Color3.fromRGB(120, 25, 25)
					if bStroke then
						bStroke.Color = Color3.fromRGB(255, 60, 60)
					end
				else
					btn.BackgroundColor3 = Color3.fromRGB(0, 140, 180)
					if bStroke then
						bStroke.Color = Color3.fromRGB(0, 255, 220)
					end
				end
			else
				btn.BackgroundColor3 = if btnKey == "Space" then Color3.fromRGB(35, 75, 115) else Color3.fromRGB(30, 42, 60)
				if bStroke then
					bStroke.Color = Color3.fromRGB(0, 180, 220)
				end
			end
		end
	end

	local function ShowAutoAdvanceBanner(zoneUnlocked: number)
		local toastGui = Instance.new("ScreenGui")
		toastGui.Name = "AutoAdvanceToast"
		toastGui.ResetOnSpawn = false
		toastGui.Parent = playerGui

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
		bStroke.Color = Color3.fromRGB(0, 240, 255)
		bStroke.Thickness = 2.5
		bStroke.Parent = banner

		local bText = Instance.new("TextLabel")
		bText.Size = UDim2.fromScale(1, 1)
		bText.BackgroundTransparency = 1
		bText.Text = string.format("🏆 ¡SALA SUPERADA! >> AVANZANDO A SALA %d (+25 CRÉDITOS)", zoneUnlocked)
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
	end

	local function ShowFailureModal(reasonText: string)
		isRunning = false
		CleanupConnections()
		PlayFailureBuzzer()

		titleLabel.Visible = false
		comboBadge.Visible = false
		keyCard.Visible = false
		timerBarBg.Visible = false
		touchPad.Visible = false

		local failFrame = Instance.new("Frame")
		failFrame.Name = "FailFrame"
		failFrame.Size = UDim2.fromScale(1, 1)
		failFrame.BackgroundTransparency = 1
		failFrame.Parent = container

		local fTitle = Instance.new("TextLabel")
		fTitle.Name = "FailTitle"
		fTitle.Size = UDim2.fromScale(0.94, 0.18)
		fTitle.Position = UDim2.fromScale(0.03, 0.08)
		fTitle.BackgroundTransparency = 1
		fTitle.Text = "❌ ¡INTENTO FALLIDO! ❌"
		fTitle.TextColor3 = Color3.fromRGB(255, 60, 60)
		fTitle.TextScaled = true
		fTitle.Font = Enum.Font.GothamBlack
		fTitle.Parent = failFrame

		local fReason = Instance.new("TextLabel")
		fReason.Name = "FailReason"
		fReason.Size = UDim2.fromScale(0.88, 0.26)
		fReason.Position = UDim2.fromScale(0.06, 0.30)
		fReason.BackgroundColor3 = Color3.fromRGB(24, 18, 22)
		fReason.Text = reasonText
		fReason.TextColor3 = Color3.fromRGB(255, 180, 180)
		fReason.TextScaled = true
		fReason.Font = Enum.Font.GothamMedium
		fReason.BorderSizePixel = 0
		fReason.Parent = failFrame

		local frCorner = Instance.new("UICorner")
		frCorner.CornerRadius = UDim.new(0, 8)
		frCorner.Parent = fReason

		local btnRetry = Instance.new("TextButton")
		btnRetry.Name = "BtnRetry"
		btnRetry.Size = UDim2.fromScale(0.42, 0.18)
		btnRetry.Position = UDim2.fromScale(0.06, 0.65)
		btnRetry.BackgroundColor3 = Color3.fromRGB(0, 160, 200)
		btnRetry.TextColor3 = Color3.fromRGB(255, 255, 255)
		btnRetry.Text = "🔄 REINTENTAR"
		btnRetry.TextScaled = true
		btnRetry.Font = Enum.Font.GothamBold
		btnRetry.BorderSizePixel = 0
		btnRetry.Parent = failFrame

		local brCorner = Instance.new("UICorner")
		brCorner.CornerRadius = UDim.new(0, 8)
		brCorner.Parent = btnRetry

		btnRetry.Activated:Connect(function()
			if activeScreenGui then
				activeScreenGui:Destroy()
				activeScreenGui = nil
			end
			local captureRemote = Network.GetRemote("RequestCapture")
			captureRemote:FireServer(1, difficulty)
		end)

		local btnExit = Instance.new("TextButton")
		btnExit.Name = "BtnExit"
		btnExit.Size = UDim2.fromScale(0.42, 0.18)
		btnExit.Position = UDim2.fromScale(0.52, 0.65)
		btnExit.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
		btnExit.TextColor3 = Color3.fromRGB(220, 230, 245)
		btnExit.Text = "🚪 SALIR"
		btnExit.TextScaled = true
		btnExit.Font = Enum.Font.GothamBold
		btnExit.BorderSizePixel = 0
		btnExit.Parent = failFrame

		local beCorner = Instance.new("UICorner")
		beCorner.CornerRadius = UDim.new(0, 8)
		beCorner.Parent = btnExit

		btnExit.Activated:Connect(function()
			if activeScreenGui then
				activeScreenGui:Destroy()
				activeScreenGui = nil
			end
		end)
	end

	local function ShowStep(idx: number)
		if idx > #sequence then
			-- Completed all steps successfully!
			isRunning = false
			CleanupConnections()
			RestoreMovement()
			local totalTime = os.clock() - startTime

			-- Victory fanfare
			PlayDopamineChime(sequence and #sequence + 2 or 5)

			-- Authoritative Server Submission
			local submitRemote = Network.GetRemote("SubmitMinigameResult")
			submitRemote:FireServer(1, difficulty, totalTime, token, {
				Inputs = collectedInputs,
				PressedTraps = pressedTraps,
			})

			onCompleted(not pressedTraps, if pressedTraps then "Trampa activada" else nil)

			if activeScreenGui then
				activeScreenGui:Destroy()
				activeScreenGui = nil
			end

			local nextZoneNum = difficulty == 1 and 2 or (difficulty + 1)
			ShowAutoAdvanceBanner(nextZoneNum)
			return
		end

		stepStartTime = os.clock()
		local targetKey = sequence[idx]
		local isTrap = distractors[idx] == true

		keyLabel.Text = if targetKey == "Space" then "ESPACIO" else targetKey
		HighlightTargetButton(targetKey, isTrap)

		if isTrap then
			keyCard.BackgroundColor3 = Color3.fromRGB(110, 20, 20)
			cardStroke.Color = Color3.fromRGB(255, 50, 50)
			hintLabel.Text = "¡TRAMPA! ¡NO PRESIONAR!"
			hintLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			timerFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
		else
			keyCard.BackgroundColor3 = Color3.fromRGB(22, 28, 42)
			cardStroke.Color = Color3.fromRGB(0, 200, 255)
			hintLabel.Text = "¡PRESIONA LA TECLA!"
			hintLabel.TextColor3 = Color3.fromRGB(180, 210, 240)
			timerFill.BackgroundColor3 = Color3.fromRGB(0, 255, 180)
		end

		-- Visual Pulse Tween
		keyCard.Size = if isMobile then UDim2.fromScale(0.49, 0.30) else UDim2.fromScale(0.45, 0.32)
		local tween = TweenService:Create(keyCard, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = if isMobile then UDim2.fromScale(0.46, 0.28) else UDim2.fromScale(0.42, 0.30)
		})
		tween:Play()
	end

	local function ProcessInput(inputKey: string)
		if not isRunning then
			return
		end

		local now = os.clock()

		-- 1. Anti-rebote check: mechanical switch chatter of the same key
		if (now - lastInputTimestamp) < MIN_DEBOUNCE_SAME_KEY and inputKey == lastAcceptedKey then
			return
		end

		-- 2. Step transition cooldown: ignore accidental lingering presses in the first 80ms
		if (now - stepStartTime) < MIN_STEP_TRANSITION_COOLDOWN then
			return
		end

		local isTrap = distractors[currentStep] == true
		if isTrap then
			-- Pressed a trap key! Immediate failure
			pressedTraps = true
			isRunning = false
			CleanupConnections()

			local submitRemote = Network.GetRemote("SubmitMinigameResult")
			submitRemote:FireServer(1, difficulty, os.clock() - startTime, token, {
				Inputs = collectedInputs,
				PressedTraps = true,
			})
			onCompleted(false, "Pulsaste una trampa distractor")
			ShowFailureModal("Pulsaste una trampa distractor")
			return
		end

		local expectedKey = sequence[currentStep]
		if inputKey == expectedKey then
			-- Success on this key!
			comboStreak += 1
			PlayDopamineChime(comboStreak)

			-- Update combo badge with animated scale punch
			comboBadge.Text = string.format("COMBO x%d! 🔥", comboStreak)
			comboBadge.TextColor3 = if comboStreak >= 4 then Color3.fromRGB(255, 80, 220) else Color3.fromRGB(255, 215, 0)
			local bTween = TweenService:Create(comboBadge, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(0.46, 0.10)
			})
			bTween:Play()
			task.delay(0.12, function()
				if comboBadge and comboBadge.Parent then
					comboBadge.Size = UDim2.fromScale(0.4, 0.08)
				end
			end)

			lastInputTimestamp = now
			lastAcceptedKey = inputKey
			table.insert(collectedInputs, inputKey)
			currentStep += 1
			ShowStep(currentStep)
		else
			-- Wrong key pressed! Immediate failure
			isRunning = false
			CleanupConnections()

			local submitRemote = Network.GetRemote("SubmitMinigameResult")
			submitRemote:FireServer(1, difficulty, os.clock() - startTime, token, {
				Inputs = collectedInputs,
				PressedTraps = false,
			})
			local failMsg = string.format("Tecla incorrecta: se esperaba %s, pulsaste %s", expectedKey, inputKey)
			onCompleted(false, failMsg)
			ShowFailureModal(failMsg)
			return
		end
	end

	ProcessInputFunc = ProcessInput
	currentKeyProcessor = ProcessInput

	-- Connect keyboard input (we do NOT filter gameProcessed because ContextActionService sinks the movement)
	inputConn = UserInputService.InputBegan:Connect(function(input, _gameProcessed)
		if not isRunning then
			return
		end
		local keyStr: string? = nil
		if input.KeyCode == Enum.KeyCode.W then
			keyStr = "W"
		elseif input.KeyCode == Enum.KeyCode.A then
			keyStr = "A"
		elseif input.KeyCode == Enum.KeyCode.S then
			keyStr = "S"
		elseif input.KeyCode == Enum.KeyCode.D then
			keyStr = "D"
		elseif input.KeyCode == Enum.KeyCode.E then
			keyStr = "E"
		elseif input.KeyCode == Enum.KeyCode.Q then
			keyStr = "Q"
		elseif input.KeyCode == Enum.KeyCode.Space then
			keyStr = "Space"
		end

		if keyStr then
			ProcessInput(keyStr)
		end
	end)

	-- Connect touch / screen buttons
	for btnKey, btn in pairs(registeredButtons) do
		local conn = btn.Activated:Connect(function()
			-- Touch button bounce animation
			local origSize = btn.Size
			btn.Size = UDim2.fromScale(origSize.X.Scale * 0.94, origSize.Y.Scale * 0.94)
			task.delay(0.08, function()
				if btn and btn.Parent then
					btn.Size = origSize
				end
			end)
			ProcessInput(btnKey)
		end)
		table.insert(buttonConns, conn)
	end

	-- Timer update thread
	task.spawn(function()
		ShowStep(1)

		while isRunning do
			local elapsed = os.clock() - stepStartTime
			local fraction = 1 - (elapsed / qteConfig.WindowPerKey)

			if fraction <= 0 then
				local isTrap = distractors[currentStep] == true
				if isTrap then
					-- Successfully waited out the trap without pressing! Proceed!
					comboStreak += 1
					PlayDopamineChime(comboStreak)
					currentStep += 1
					ShowStep(currentStep)
				else
					-- Timeout on legitimate key!
					isRunning = false
					CleanupConnections()
					local submitRemote = Network.GetRemote("SubmitMinigameResult")
					submitRemote:FireServer(1, difficulty, os.clock() - startTime, token, {
						Inputs = collectedInputs,
						PressedTraps = false,
					})
					local timeoutMsg = "Tiempo agotado en la tecla " .. sequence[currentStep]
					onCompleted(false, timeoutMsg)
					ShowFailureModal(timeoutMsg)
					break
				end
			else
				timerFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			end

			task.wait(0.03)
		end

		CleanupConnections()
	end)
end

function M1_ReflexQTE.Init()
	Network.InitializeRemotes()
	local startRemote = Network.GetRemote("StartMinigameClient")
	startRemote.OnClientEvent:Connect(function(machineId: any, difficulty: any, _duration: any, token: any, payload: any)
		if machineId == 1 and typeof(token) == "string" and typeof(payload) == "table" then
			local seq = payload.Sequence or { "W", "A", "S", "D" }
			local distractors = payload.Distractors or {}
			M1_ReflexQTE.StartMinigame(difficulty or 1, token, seq, distractors, function(win, reason)
				print(string.format("QTE Minigame result: %s (Reason: %s)", tostring(win), tostring(reason)))
			end)
		end
	end)
end

return M1_ReflexQTE
