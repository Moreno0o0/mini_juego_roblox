--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Shared.Network)
local MinigameLevelsData = require(ReplicatedStorage.Shared.Config.MinigameLevelsData)

local localPlayer = Players.LocalPlayer

local M4_MemoryMatrix = {}

type GridCoord = { x: number, y: number }

local isRunning = false
local activeScreenGui: ScreenGui? = nil
local activeConnections: { RBXScriptConnection } = {}

function M4_MemoryMatrix.StartMinigame(
	difficulty: number,
	token: string,
	sequence: { GridCoord },
	flashDuration: number,
	onCompleted: (boolean, string?) -> ()
)
	if isRunning then
		return
	end
	isRunning = true

	local curPlayer = localPlayer or Players.LocalPlayer
	local playerGui = curPlayer and curPlayer:FindFirstChild("PlayerGui") :: PlayerGui?

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "M4_MemoryMatrix_Gui"
	screenGui.ResetOnSpawn = false
	if playerGui then
		screenGui.Parent = playerGui
	end
	activeScreenGui = screenGui

	-- Container
	local mainContainer = Instance.new("Frame")
	mainContainer.Name = "MatrixContainer"
	mainContainer.Size = UDim2.fromScale(0.48, 0.68)
	mainContainer.Position = UDim2.fromScale(0.26, 0.16)
	mainContainer.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	mainContainer.BorderSizePixel = 0
	mainContainer.Parent = screenGui

	local mCorner = Instance.new("UICorner")
	mCorner.CornerRadius = UDim.new(0, 14)
	mCorner.Parent = mainContainer

	local mStroke = Instance.new("UIStroke")
	mStroke.Color = Color3.fromRGB(160, 60, 255)
	mStroke.Thickness = 3
	mStroke.Parent = mainContainer

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromScale(1, 0.15)
	header.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
	header.BorderSizePixel = 0
	header.Parent = mainContainer

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 0.5)
	titleLabel.Position = UDim2.fromScale(0, 0.05)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("MATRIZ DE MEMORIA 4x4 (Nivel %d)", difficulty)
	titleLabel.TextColor3 = Color3.fromRGB(200, 120, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = header

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.fromScale(1, 0.4)
	statusLabel.Position = UDim2.fromScale(0, 0.55)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "¡MEMORIZA LA SECUENCIA!"
	statusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.Parent = header

	-- 4x4 Grid Frame
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "GridArea"
	gridFrame.Size = UDim2.fromScale(0.85, 0.78)
	gridFrame.Position = UDim2.fromScale(0.075, 0.18)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = mainContainer

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromScale(0.22, 0.22)
	gridLayout.CellPadding = UDim2.fromScale(0.04, 0.04)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	gridLayout.Parent = gridFrame

	local panels: { [string]: TextButton } = {}
	local canInput = false
	local currentStep = 1
	local playerSequence: { GridCoord } = {}
	local startTime = os.clock()

	local function Cleanup()
		isRunning = false
		canInput = false
		for _, conn in ipairs(activeConnections) do
			conn:Disconnect()
		end
		table.clear(activeConnections)
		if activeScreenGui then
			activeScreenGui:Destroy()
			activeScreenGui = nil
		end
	end

	local function PlayTone(freq: number)
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sound.PlaybackSpeed = freq
		sound.Volume = 0.5
		sound.Parent = Workspace
		sound:Play()
		task.delay(1, function()
			sound:Destroy()
		end)
	end

	-- Instantiate the 16 Grid Tiles: G = {1..4} x {1..4}
	for y = 1, 4 do
		for x = 1, 4 do
			local key = string.format("%d_%d", x, y)
			local btn = Instance.new("TextButton")
			btn.Name = "Tile_" .. key
			btn.BackgroundColor3 = Color3.fromRGB(30, 36, 54)
			btn.Text = ""
			btn.BorderSizePixel = 0
			btn.AutoButtonColor = false

			local bCorner = Instance.new("UICorner")
			bCorner.CornerRadius = UDim.new(0, 8)
			bCorner.Parent = btn

			local bStroke = Instance.new("UIStroke")
			bStroke.Color = Color3.fromRGB(50, 60, 90)
			bStroke.Thickness = 2
			bStroke.Parent = btn

			btn.Parent = gridFrame
			panels[key] = btn

			local clickConn = btn.MouseButton1Click:Connect(function()
				if not isRunning or not canInput then
					return
				end

				local expectedCoord = sequence[currentStep]
				if not expectedCoord then
					return
				end

				if x == expectedCoord.x and y == expectedCoord.y then
					-- Step matched: Advance
					table.insert(playerSequence, { x = x, y = y })
					PlayTone(1.0 + (currentStep * 0.1))

					btn.BackgroundColor3 = Color3.fromRGB(40, 255, 130)
					TweenService:Create(
						btn,
						TweenInfo.new(0.25),
						{ BackgroundColor3 = Color3.fromRGB(30, 36, 54) }
					):Play()

					currentStep += 1
					statusLabel.Text = string.format("Progreso: %d / %d", currentStep - 1, #sequence)

					if currentStep > #sequence then
						-- Completed full sequence!
						canInput = false
						statusLabel.Text = "¡SECUENCIA CORRECTA!"
						statusLabel.TextColor3 = Color3.fromRGB(40, 255, 130)

						task.wait(0.3)
						Cleanup()

						local totalDuration = os.clock() - startTime
						local submitRemote = Network.GetRemote("SubmitMinigameResult")
						submitRemote:FireServer(4, difficulty, totalDuration, token, {
							PlayerSequence = playerSequence,
						})

						onCompleted(true, nil)

						local toastGui = Instance.new("ScreenGui")
						toastGui.Name = "AutoAdvanceToast_M4"
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

						local tbCorner = Instance.new("UICorner")
						tbCorner.CornerRadius = UDim.new(0, 10)
						tbCorner.Parent = banner

						local tbStroke = Instance.new("UIStroke")
						tbStroke.Color = Color3.fromRGB(180, 80, 255)
						tbStroke.Thickness = 2.5
						tbStroke.Parent = banner

						local bText = Instance.new("TextLabel")
						bText.Size = UDim2.fromScale(1, 1)
						bText.BackgroundTransparency = 1
						bText.Text = "🏆 ¡SALA 4 SUPERADA! >> AVANZANDO AL COLISEO FINAL (+25 CRÉDITOS)"
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
				else
					-- Incorrect step: Failure!
					table.insert(playerSequence, { x = x, y = y })
					canInput = false
					btn.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
					PlayTone(0.5)
					statusLabel.Text = "¡PASO INCORRECTO!"
					statusLabel.TextColor3 = Color3.fromRGB(255, 40, 40)

					task.wait(0.6)
					Cleanup()

					local totalDuration = os.clock() - startTime
					local submitRemote = Network.GetRemote("SubmitMinigameResult")
					submitRemote:FireServer(4, difficulty, totalDuration, token, {
						PlayerSequence = playerSequence,
					})

					onCompleted(false, "Paso incorrecto en la secuencia")
				end
			end)
			table.insert(activeConnections, clickConn)
		end
	end

	-- Phase 1 Demonstration Playback Thread
	task.spawn(function()
		task.wait(0.8)

		for idx, coord in ipairs(sequence) do
			if not isRunning then
				return
			end

			local key = string.format("%d_%d", coord.x, coord.y)
			local btn = panels[key]
			if btn then
				statusLabel.Text = string.format("Demostración: %d / %d", idx, #sequence)
				btn.BackgroundColor3 = Color3.fromRGB(200, 100, 255)
				PlayTone(1.0 + (idx * 0.1))

				local pulse = TweenService:Create(
					btn,
					TweenInfo.new(flashDuration * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundColor3 = Color3.fromRGB(30, 36, 54) }
				)
				pulse:Play()
			end

			task.wait(flashDuration)
		end

		if not isRunning then
			return
		end

		-- Phase 2 Start Input
		canInput = true
		statusLabel.Text = string.format("¡TU TURNO! (0 / %d)", #sequence)
		statusLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
	end)
end

function M4_MemoryMatrix.Init()
	Network.InitializeRemotes()
	local startRemote = Network.GetRemote("StartMinigameClient")
	startRemote.OnClientEvent:Connect(function(machineId: any, difficulty: any, _duration: any, token: any, payload: any)
		if machineId == 4 and typeof(token) == "string" and typeof(payload) == "table" then
			local levelData = MinigameLevelsData.GetLevel(4, difficulty or 1)
			local flashDuration = if levelData and levelData.Specific.MemoryMatrix
				then levelData.Specific.MemoryMatrix.FlashDuration
				else 0.8
			local seq: { GridCoord } = payload.Sequence or {}

			M4_MemoryMatrix.StartMinigame(difficulty or 1, token, seq, flashDuration, function(win, reason)
				print(string.format("MemoryMatrix result: %s (Reason: %s)", tostring(win), tostring(reason)))
			end)
		end
	end)
end

return M4_MemoryMatrix
