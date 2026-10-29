--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Shared.Network)
local MinigameLevelsData = require(ReplicatedStorage.Shared.Config.MinigameLevelsData)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local M2_LaserGrid = {}

local isRunning = false
local activeConnection: RBXScriptConnection? = nil
local activeHud: ScreenGui? = nil
local activeFolder: Folder? = nil
local charDiedConn: RBXScriptConnection? = nil

local function ShowAutoAdvanceBanner(zoneUnlocked: number)
	local toastGui = Instance.new("ScreenGui")
	toastGui.Name = "AutoAdvanceToast_M2"
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
	bStroke.Color = Color3.fromRGB(50, 255, 120)
	bStroke.Thickness = 2.5
	bStroke.Parent = banner

	local bText = Instance.new("TextLabel")
	bText.Size = UDim2.fromScale(1, 1)
	bText.BackgroundTransparency = 1
	bText.Text = string.format("🏆 ¡SALA 2 SUPERADA! >> AVANZANDO A SALA %d (+25 CRÉDITOS)", zoneUnlocked)
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

function M2_LaserGrid.StopMinigame()
	isRunning = false
	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end
	if charDiedConn then
		charDiedConn:Disconnect()
		charDiedConn = nil
	end
	if activeFolder then
		activeFolder:Destroy()
		activeFolder = nil
	end
	if activeHud then
		activeHud:Destroy()
		activeHud = nil
	end

	-- Force cleanup of any lingering M2 HUDs in playerGui
	for _, child in ipairs(playerGui:GetChildren()) do
		if child.Name == "M2_LaserGrid_HUD" then
			child:Destroy()
		end
	end

	-- Clean up any lingering LaserBeams or MinigameChamber_2 dynamic items
	local world = Workspace:FindFirstChild("World")
	local chamber = world and world:FindFirstChild("Zones") and world.Zones:FindFirstChild("Zone_2") and world.Zones.Zone_2:FindFirstChild("MinigameChamber_2")
	if chamber then
		local oldFolder = chamber:FindFirstChild("LaserBeams")
		if oldFolder then
			oldFolder:Destroy()
		end
		local itemsFolder = chamber:FindFirstChild("M2_Items")
		if itemsFolder then
			itemsFolder:Destroy()
		end
	end
end

function M2_LaserGrid.IsRunning(): boolean
	return isRunning
end

function M2_LaserGrid.StartMinigame(
	difficulty: number,
	token: string,
	maxDuration: number?,
	onCompleted: (boolean, string?) -> ()
)
	-- If already running or old HUD remains, stop and reset first
	M2_LaserGrid.StopMinigame()
	isRunning = true

	local levelData = MinigameLevelsData.GetLevel(2, difficulty)
	local timeoutTotal = if typeof(maxDuration) == "number" and maxDuration > 0
		then maxDuration
		else (if levelData then levelData.MaxAllowedTime else 80.0)

	local world = Workspace:FindFirstChild("World")
	local chamber = world and world:FindFirstChild("Zones") and world.Zones:FindFirstChild("Zone_2") and world.Zones.Zone_2:FindFirstChild("MinigameChamber_2")
	if not chamber then
		isRunning = false
		onCompleted(false, "MinigameChamber_2 not found")
		return
	end

	-- Center of Chamber 2 is at Vector3.new(170, -180, 0)
	local chamberPos = Vector3.new(170, -180, 0)

	-- Teleport player onto StartPlatform at Z = -105
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.CFrame = CFrame.new(chamberPos + Vector3.new(0, 3, -105))
	end

	-- Create HUD ScreenGui
	local hud = Instance.new("ScreenGui")
	hud.Name = "M2_LaserGrid_HUD"
	hud.ResetOnSpawn = false
	hud.Parent = playerGui
	activeHud = hud

	-- Top Instruction Banner
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Size = UDim2.fromScale(0.44, 0.07)
	banner.Position = UDim2.fromScale(0.28, 0.03)
	banner.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	banner.BorderSizePixel = 0
	banner.Parent = hud

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 8)
	bCorner.Parent = banner

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(0, 200, 255)
	bStroke.Thickness = 2
	bStroke.Parent = banner

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = string.format("¡CRUZA HASTA LA META VERDE! (Nivel %d)", difficulty)
	title.TextColor3 = Color3.fromRGB(0, 220, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = banner

	-- Visible Countdown Timer Card
	local timerCard = Instance.new("Frame")
	timerCard.Name = "TimerCard"
	timerCard.Size = UDim2.fromScale(0.32, 0.05)
	timerCard.Position = UDim2.fromScale(0.34, 0.11)
	timerCard.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	timerCard.BorderSizePixel = 0
	timerCard.Parent = hud

	local tcCorner = Instance.new("UICorner")
	tcCorner.CornerRadius = UDim.new(0, 8)
	tcCorner.Parent = timerCard

	local tcStroke = Instance.new("UIStroke")
	tcStroke.Name = "Stroke"
	tcStroke.Color = Color3.fromRGB(50, 255, 120)
	tcStroke.Thickness = 2
	tcStroke.Parent = timerCard

	local timerFill = Instance.new("Frame")
	timerFill.Name = "TimerFill"
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = Color3.fromRGB(50, 255, 120)
	timerFill.BorderSizePixel = 0
	timerFill.Parent = timerCard

	local tfCorner = Instance.new("UICorner")
	tfCorner.CornerRadius = UDim.new(0, 8)
	tfCorner.Parent = timerFill

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.fromScale(1, 1)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = string.format("⏱️ TIEMPO: %.0fs", timeoutTotal)
	timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timerLabel.TextScaled = true
	timerLabel.Font = Enum.Font.GothamBlack
	timerLabel.ZIndex = 2
	timerLabel.Parent = timerCard

	-- Dynamic Minigame Items Folder (No Lasers)
	local itemsFolder = Instance.new("Folder")
	itemsFolder.Name = "M2_Items"
	itemsFolder.Parent = chamber
	activeFolder = itemsFolder

	-- Goal Part at Z = +46 (SmoothPlastic without neon glare)
	local goal = Instance.new("Part")
	goal.Name = "CorridorGoal"
	goal.Size = Vector3.new(20, 8, 12)
	goal.CFrame = CFrame.new(chamberPos.X, chamberPos.Y + 4, chamberPos.Z + 46)
	goal.Color = Color3.fromRGB(40, 220, 110)
	goal.Material = Enum.Material.SmoothPlastic
	goal.Transparency = 0.4
	goal.Anchored = true
	goal.CanCollide = false
	goal.Parent = itemsFolder

	local startTime = os.clock()

	-- Monitor Humanoid death during minigame
	local currentHumanoid = char and char:FindFirstChild("Humanoid") :: Humanoid?
	if currentHumanoid then
		charDiedConn = currentHumanoid.Died:Connect(function()
			M2_LaserGrid.StopMinigame()
			onCompleted(false, "Personaje eliminado")
		end)
	end

	activeConnection = RunService.Heartbeat:Connect(function()
		if not isRunning then
			return
		end

		local currentChar = localPlayer.Character
		local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not currentHrp then
			M2_LaserGrid.StopMinigame()
			return
		end

		local pPos = currentHrp.Position

		-- Spatial Fail-Safe: If player is outside Chamber 2 (e.g. teleported back to arena at Y > -100 or far away)
		-- 2.5s grace period during initial teleportation
		if (os.clock() - startTime) > 2.5 and (pPos.Y > -100 or math.abs(pPos.X - chamberPos.X) > 80 or math.abs(pPos.Z - chamberPos.Z) > 150) then
			M2_LaserGrid.StopMinigame()
			return
		end

		local t = os.clock() - startTime
		local remaining = math.max(0, timeoutTotal - t)
		local frac = math.clamp(remaining / timeoutTotal, 0, 1)

		-- Update Countdown Timer Display
		if timerFill and timerFill.Parent then
			timerFill.Size = UDim2.fromScale(frac, 1)
			if frac < 0.25 then
				timerFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
				tcStroke.Color = Color3.fromRGB(255, 50, 50)
			elseif frac < 0.50 then
				timerFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
				tcStroke.Color = Color3.fromRGB(255, 215, 0)
			else
				timerFill.BackgroundColor3 = Color3.fromRGB(50, 255, 120)
				tcStroke.Color = Color3.fromRGB(50, 255, 120)
			end
		end

		if timerLabel and timerLabel.Parent then
			timerLabel.Text = string.format("⏱️ TIEMPO: %.1fs", remaining)
		end

		-- Timeout check
		if remaining <= 0 then
			M2_LaserGrid.StopMinigame()
			local submitRemote = Network.GetRemote("SubmitMinigameResult")
			submitRemote:FireServer(2, difficulty, t, token, {
				ReachedGoal = false,
				TouchedLaser = false,
			})
			onCompleted(false, "Tiempo límite agotado en la Sala 2")
			return
		end

		-- Pit hazard check (falling off platforms below Y - 182.5)
		if pPos.Y < (chamberPos.Y - 2.5) then
			M2_LaserGrid.StopMinigame()
			local submitRemote = Network.GetRemote("SubmitMinigameResult")
			submitRemote:FireServer(2, difficulty, t, token, {
				ReachedGoal = false,
				TouchedLaser = false,
			})
			onCompleted(false, "Caíste al foso")
			return
		end

		-- Goal intersection check (reached the green goal pad at Z >= +98)
		if pPos.Z >= (chamberPos.Z + 98) and math.abs(pPos.X - chamberPos.X) <= 14 and pPos.Y >= (chamberPos.Y - 2) then
			M2_LaserGrid.StopMinigame()
			local submitRemote = Network.GetRemote("SubmitMinigameResult")
			submitRemote:FireServer(2, difficulty, t, token, {
				ReachedGoal = true,
				TouchedLaser = false,
			})
			onCompleted(true, nil)
			ShowAutoAdvanceBanner(3)
			return
		end
	end)
end

function M2_LaserGrid.Init()
	Network.InitializeRemotes()

	local startRemote = Network.GetRemote("StartMinigameClient")
	startRemote.OnClientEvent:Connect(function(machineId: any, difficulty: any, duration: any, token: any)
		if machineId == 2 and typeof(token) == "string" then
			local dur = if typeof(duration) == "number" and duration > 0 then duration else 80.0
			M2_LaserGrid.StartMinigame(difficulty or 1, token, dur, function(win, reason)
				print(string.format("M2 Platforms Minigame result: %s (Reason: %s)", tostring(win), tostring(reason)))
			end)
		end
	end)

	local forceExitRemote = Network.GetRemote("ForceExitMachine")
	forceExitRemote.OnClientEvent:Connect(function()
		M2_LaserGrid.StopMinigame()
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
			M2_LaserGrid.StopMinigame()
		end
	end)

	localPlayer.CharacterAdded:Connect(function(newChar)
		if isRunning then
			M2_LaserGrid.StopMinigame()
		end
		local hum = newChar:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum then
			hum.Died:Connect(function()
				if isRunning then
					M2_LaserGrid.StopMinigame()
				end
			end)
		end
	end)

	if localPlayer.Character then
		local hum = localPlayer.Character:FindFirstChild("Humanoid") :: Humanoid?
		if hum then
			hum.Died:Connect(function()
				if isRunning then
					M2_LaserGrid.StopMinigame()
				end
			end)
		end
	end
end

return M2_LaserGrid
