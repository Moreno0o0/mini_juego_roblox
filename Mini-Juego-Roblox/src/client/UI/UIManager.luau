--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage.Shared.Network)
local AssetIcons = require(script.Parent.AssetIcons)
local ProgressTracker = require(script.Parent.ProgressTracker)
local MachineHUD = require(script.Parent.MachineHUD)
local NavigationBeacon = require(script.Parent.NavigationBeacon)
local JuiceFeedback = require(script.Parent.Parent.Combat.JuiceFeedback)
local ShopGUI = require(script.Parent.ShopGUI)
local SoundManager = require(script.Parent.Parent.SoundManager)

local localPlayer = Players.LocalPlayer

local UIManager = {}

local mainScreenGui: ScreenGui? = nil
local toastContainer: Frame? = nil
local currentHighestZone = 1

function UIManager.UpdateGateVisuals(highestUnlockedZone: number)
	currentHighestZone = math.max(currentHighestZone, highestUnlockedZone)
	local world = Workspace:FindFirstChild("World")
	if not world then
		return
	end
	local gatesFolder = world:FindFirstChild("Gates")
	if not gatesFolder then
		return
	end

	for g = 1, 4 do
		local gateModel = gatesFolder:FindFirstChild(string.format("Gate_%d_%d", g, g + 1))
		if gateModel then
			local barrier = gateModel:FindFirstChild("Barrier") :: BasePart?
			local isUnlocked = (currentHighestZone > g)

			if barrier then
				if isUnlocked then
					barrier.Transparency = 0.88
					barrier.Color = Color3.fromRGB(0, 255, 180) -- Glowing open emerald cyan
					barrier.CanCollide = false
				else
					barrier.Transparency = 0.35
					barrier.Color = Color3.fromRGB(255, 60 + g * 30, 40) -- Laser red
					barrier.CanCollide = true
				end
			end

			-- Dynamic Billboard Sign above gate
			local bb = gateModel:FindFirstChild("GateBillboard") :: BillboardGui?
			if not bb and barrier then
				local newBB = Instance.new("BillboardGui")
				newBB.Name = "GateBillboard"
				newBB.Adornee = barrier
				newBB.Size = UDim2.fromOffset(280, 65)
				newBB.StudsOffset = Vector3.new(0, 16, 0)
				newBB.AlwaysOnTop = true
				newBB.Parent = gateModel

				local signFrame = Instance.new("Frame")
				signFrame.Name = "SignFrame"
				signFrame.Size = UDim2.fromScale(1, 1)
				signFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
				signFrame.BorderSizePixel = 0
				signFrame.Parent = newBB

				local sCorner = Instance.new("UICorner")
				sCorner.CornerRadius = UDim.new(0, 8)
				sCorner.Parent = signFrame

				local sStroke = Instance.new("UIStroke")
				sStroke.Name = "Stroke"
				sStroke.Thickness = 2
				sStroke.Parent = signFrame

				local signLabel = Instance.new("TextLabel")
				signLabel.Name = "SignLabel"
				signLabel.Size = UDim2.fromScale(0.9, 0.8)
				signLabel.Position = UDim2.fromScale(0.05, 0.1)
				signLabel.BackgroundTransparency = 1
				signLabel.TextScaled = true
				signLabel.Font = Enum.Font.GothamBlack
				signLabel.Parent = signFrame

				bb = newBB
			end

			if bb then
				local signFrame = bb:FindFirstChild("SignFrame")
				local signLabel = signFrame and signFrame:FindFirstChild("SignLabel") :: TextLabel?
				local signStroke = signFrame and signFrame:FindFirstChild("Stroke") :: UIStroke?
				if signLabel and signStroke then
					if isUnlocked then
						signLabel.Text = string.format("[ SALA %d: ABIERTA >> ]", g + 1)
						signLabel.TextColor3 = Color3.fromRGB(0, 255, 180)
						signStroke.Color = Color3.fromRGB(0, 255, 180)
					else
						signLabel.Text = string.format("[ BLOQUEADA: Supera Máquina %d ]", g)
						signLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
						signStroke.Color = Color3.fromRGB(255, 60, 60)
					end
				end
			end
		end
	end
end

function UIManager.Init()
	local curPlayer = localPlayer or Players.LocalPlayer
	local playerGui = curPlayer and curPlayer:WaitForChild("PlayerGui") :: PlayerGui?

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameHUD_Main"
	screenGui.ResetOnSpawn = false
	if playerGui then
		screenGui.Parent = playerGui
	end
	mainScreenGui = screenGui

	-- Notifications Toast Container
	local toasts = Instance.new("Frame")
	toasts.Name = "ToastContainer"
	toasts.Size = UDim2.fromScale(0.35, 0.3)
	toasts.Position = UDim2.fromScale(0.63, 0.1)
	toasts.BackgroundTransparency = 1
	toasts.Parent = screenGui
	toastContainer = toasts

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.Parent = toasts

	-- Initialize sub-components
	ProgressTracker.Init(screenGui)
	MachineHUD.Init(screenGui)
	NavigationBeacon.Init(screenGui)
	ShopGUI.Init(screenGui)

	-- Streak Badge Display (HUD Izquierdo)
	local streakFrame = Instance.new("Frame")
	streakFrame.Name = "StreakFrame"
	streakFrame.Size = UDim2.fromScale(0.14, 0.055)
	streakFrame.Position = UDim2.fromScale(0.04, 0.02)
	streakFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	streakFrame.BorderSizePixel = 0
	streakFrame.Parent = screenGui

	local sfCorner = Instance.new("UICorner")
	sfCorner.CornerRadius = UDim.new(0, 8)
	sfCorner.Parent = streakFrame

	local sfStroke = Instance.new("UIStroke")
	sfStroke.Name = "Stroke"
	sfStroke.Color = Color3.fromRGB(80, 90, 120)
	sfStroke.Thickness = 2
	sfStroke.Parent = streakFrame

	local sfLabel = Instance.new("TextLabel")
	sfLabel.Name = "StreakLabel"
	sfLabel.Size = UDim2.fromScale(0.9, 0.8)
	sfLabel.Position = UDim2.fromScale(0.05, 0.1)
	sfLabel.BackgroundTransparency = 1
	sfLabel.Text = "🔥 RACHA: x0"
	sfLabel.TextColor3 = Color3.fromRGB(160, 175, 200)
	sfLabel.TextScaled = true
	sfLabel.Font = Enum.Font.GothamBold
	sfLabel.Parent = streakFrame

	-- Dynamic Arena Event Banner (Desplegable superior)
	local eventBanner = Instance.new("Frame")
	eventBanner.Name = "ArenaEventBanner"
	eventBanner.Size = UDim2.fromScale(0.48, 0.065)
	eventBanner.Position = UDim2.fromScale(0.26, -0.09)
	eventBanner.BackgroundColor3 = Color3.fromRGB(14, 18, 30)
	eventBanner.BorderSizePixel = 0
	eventBanner.Visible = false
	eventBanner.Parent = screenGui

	local ebCorner = Instance.new("UICorner")
	ebCorner.CornerRadius = UDim.new(0, 10)
	ebCorner.Parent = eventBanner

	local ebStroke = Instance.new("UIStroke")
	ebStroke.Name = "Stroke"
	ebStroke.Color = Color3.fromRGB(255, 215, 0)
	ebStroke.Thickness = 2.5
	ebStroke.Parent = eventBanner

	local ebText = Instance.new("TextLabel")
	ebText.Name = "EventText"
	ebText.Size = UDim2.fromScale(0.94, 0.8)
	ebText.Position = UDim2.fromScale(0.03, 0.1)
	ebText.BackgroundTransparency = 1
	ebText.Text = "🚨 ¡EVENTO ACTIVO!"
	ebText.TextColor3 = Color3.fromRGB(255, 220, 50)
	ebText.TextScaled = true
	ebText.Font = Enum.Font.GothamBlack
	ebText.Parent = eventBanner

	-- Quick Access HUD Cyber-Shop Button (Ergonomic for PC and Mobile)
	local shopBtn = Instance.new("TextButton")
	shopBtn.Name = "HUD_ShopButton"
	shopBtn.Size = UDim2.fromScale(0.11, 0.055)
	shopBtn.Position = UDim2.fromScale(0.87, 0.02)
	shopBtn.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
	shopBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
	shopBtn.Text = "🛒 TIENDA"
	shopBtn.TextScaled = true
	shopBtn.Font = Enum.Font.GothamBlack
	shopBtn.BorderSizePixel = 0
	shopBtn.AutoButtonColor = true
	shopBtn.Parent = screenGui

	local sbCorner = Instance.new("UICorner")
	sbCorner.CornerRadius = UDim.new(0, 8)
	sbCorner.Parent = shopBtn

	local sbStroke = Instance.new("UIStroke")
	sbStroke.Color = Color3.fromRGB(255, 215, 0)
	sbStroke.Thickness = 2
	sbStroke.Parent = shopBtn

	shopBtn.Activated:Connect(function()
		SoundManager.PlayButtonClick()
		ShopGUI.Toggle()
	end)

	-- Listen for in-world ProximityPrompts (like CyberShop_Kiosk in Zone 1)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
		if playerWhoTriggered == localPlayer and prompt.Name == "OpenShopPrompt" then
			ShopGUI.Open()
		end
	end)

	-- Initial Gate Visuals update
	task.spawn(function()
		task.wait(1.0)
		UIManager.UpdateGateVisuals(1)
	end)

	if curPlayer then
		curPlayer.CharacterAdded:Connect(function()
			task.wait(0.5)
			UIManager.UpdateGateVisuals(currentHighestZone)
		end)
	end

	-- Wire Network Remotes
	Network.InitializeRemotes()

	local syncRemote = Network.GetRemote("SyncState")
	syncRemote.OnClientEvent:Connect(function(arg1: any, arg2: any)
		local payload: any = nil
		local stateStr: string? = nil

		if typeof(arg1) == "table" then
			payload = arg1
		elseif typeof(arg1) == "string" then
			stateStr = arg1
			if typeof(arg2) == "table" then
				payload = arg2
			end
		end

		if stateStr then
			ProgressTracker.UpdateState(stateStr)
		end

		if payload and typeof(payload) == "table" then
			if payload.Zone ~= nil then
				ProgressTracker.UpdateZone(tostring(payload.Zone))
			end
			if payload.State ~= nil then
				ProgressTracker.UpdateState(tostring(payload.State))
			end
			if payload.MachineId ~= nil and payload.Level ~= nil then
				ProgressTracker.UpdateProgress(payload.MachineId, payload.Level)
				NavigationBeacon.UpdateProgress(payload.MachineId, payload.Level)
			end
			if payload.HighestZone ~= nil and typeof(payload.HighestZone) == "number" then
				UIManager.UpdateGateVisuals(payload.HighestZone)
			end
			if payload.CaptureFraction ~= nil then
				ProgressTracker.SetCaptureProgress(payload.CaptureFraction)
			end
			if payload.Notification ~= nil then
				UIManager.ShowNotification("ARMERÍA", tostring(payload.Notification), Color3.fromRGB(0, 240, 255))
			end
			if payload.CreditPopup ~= nil and typeof(payload.CreditPopup) == "number" then
				JuiceFeedback.SpawnCreditPopup(nil, payload.CreditPopup, nil)
			end
			if payload.WinCelebration ~= nil then
				local celeb = payload.WinCelebration
				local title = string.format("¡VICTORIA EN MÁQUINA %d! ⭐⭐⭐", celeb.MachineId or 1)
				local msg = tostring(celeb.Message or "¡Nivel superado con éxito!")
				if celeb.RewardWeapon then
					msg ..= string.format(" [¡Arma desbloqueada: %s!]", tostring(celeb.RewardWeapon))
				end
				UIManager.ShowNotification(title, msg, Color3.fromRGB(255, 215, 0))
				local nextZone = math.clamp((celeb.MachineId or 1) + 1, 1, 5)
				UIManager.UpdateGateVisuals(nextZone)
			end
		end
	end)

	local shopResultRemote = Network.GetRemote("ShopPurchaseResult")
	shopResultRemote.OnClientEvent:Connect(function(success: any, itemId: any, _newCredits: any)
		if success then
			UIManager.ShowNotification("🛒 COMPRA COMPLETADA", string.format("¡Has adquirido con éxito: %s!", tostring(itemId)), Color3.fromRGB(50, 255, 120))
		else
			UIManager.ShowNotification("TIENDA", "No tienes suficientes créditos o nivel", Color3.fromRGB(255, 70, 70))
		end
	end)

	local forceExitRemote = Network.GetRemote("ForceExitMachine")
	forceExitRemote.OnClientEvent:Connect(function(reason: any)
		MachineHUD.CloseSelector()
		local M2_LaserGrid = require(script.Parent.Parent.Minigames.M2_LaserGrid)
		if M2_LaserGrid and M2_LaserGrid.StopMinigame then
			M2_LaserGrid.StopMinigame()
		end
		UIManager.ShowNotification("SALIDA DE MÁQUINA", tostring(reason or "Sesión finalizada"), Color3.fromRGB(255, 60, 60))
	end)

	local combatFeedback = Network.GetRemote("CombatFeedback")
	combatFeedback.OnClientEvent:Connect(function(attacker: any, targetPlayer: any, finalDamage: any, _knockback: any, specialAction: any)
		local dmg = typeof(finalDamage) == "number" and finalDamage or 0
		local isLocalAttacker = (attacker == localPlayer)
		local isLocalTarget = (targetPlayer == localPlayer)

		local targetPos: Vector3? = nil
		if typeof(targetPlayer) == "Instance" then
			if targetPlayer:IsA("Player") and targetPlayer.Character then
				local hrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					targetPos = hrp.Position
				end
			elseif targetPlayer:IsA("Model") then
				local hrp = (targetPlayer:FindFirstChild("HumanoidRootPart") or targetPlayer:FindFirstChild("Torso") or targetPlayer.PrimaryPart) :: BasePart?
				if hrp then
					targetPos = hrp.Position
				end
			end
		end

		if specialAction == "Parry" then
			SoundManager.PlaySound("SwordHit", 1.8, 1.0)
			if targetPos then
				JuiceFeedback.CreateHitSparks(targetPos, Vector3.new(0, 1, 0))
			end
			if isLocalTarget then
				JuiceFeedback.ScreenShake(2.5)
				UIManager.ShowNotification("PARRY", "⚡ ¡PARRY PERFECTO!", Color3.fromRGB(255, 215, 0))
			elseif isLocalAttacker then
				JuiceFeedback.ScreenShake(3.0)
				UIManager.ShowNotification("ATURDIDO", "💥 ¡PARRY RECIBIDO!", Color3.fromRGB(255, 60, 60))
			end
			return
		end

		if targetPos and dmg > 0 then
			JuiceFeedback.SpawnDamageNumber(targetPos, dmg, dmg >= 28)
			JuiceFeedback.CreateHitSparks(targetPos, Vector3.new(0, 1, 0))
		end

		if isLocalTarget then
			SoundManager.PlayHit()
			JuiceFeedback.ScreenShake(math.clamp(dmg / 6, 2, 8))
			UIManager.ShowNotification("ALERTA", string.format("Daño recibido: -%d HP", dmg), Color3.fromRGB(255, 50, 50))
		elseif isLocalAttacker and dmg > 0 then
			SoundManager.PlayHit()
			JuiceFeedback.ScreenShake(1.5)
			local targetName = if typeof(targetPlayer) == "Instance" and targetPlayer:IsA("Player")
				then targetPlayer.DisplayName
				elseif typeof(targetPlayer) == "Instance" and targetPlayer:IsA("Model")
				then targetPlayer.Name
				else "Objetivo"
			UIManager.ShowNotification("IMPACTO", string.format("-%d HP a %s", dmg, targetName), Color3.fromRGB(50, 255, 120))
		end
	end)

	local streakRemote = Network.GetRemote("StreakUpdated")
	streakRemote.OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" and typeof(data.Streak) == "number" then
			local streak = data.Streak
			local mult = data.Multiplier or 1.0
			if streak > 0 then
				sfLabel.Text = string.format("🔥 RACHA: x%d (x%.2f 🪙)", streak, mult)
				sfLabel.TextColor3 = Color3.fromRGB(255, 140, 20)
				sfStroke.Color = Color3.fromRGB(255, 120, 20)

				local pulse = TweenService:Create(
					streakFrame,
					TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.fromScale(0.155, 0.068) }
				)
				pulse:Play()
				task.delay(0.15, function()
					local ret = TweenService:Create(
						streakFrame,
						TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Size = UDim2.fromScale(0.14, 0.055) }
					)
					ret:Play()
				end)
			else
				sfLabel.Text = "🔥 RACHA: x0"
				sfLabel.TextColor3 = Color3.fromRGB(160, 175, 200)
				sfStroke.Color = Color3.fromRGB(80, 90, 120)
			end
		end
	end)

	local arenaEventRemote = Network.GetRemote("ArenaEventTriggered")
	arenaEventRemote.OnClientEvent:Connect(function(eventData: any)
		if typeof(eventData) == "table" then
			local title = tostring(eventData.EventName or "EVENTO DE ARENA")
			local duration = typeof(eventData.Duration) == "number" and eventData.Duration or 20
			eventBanner.Visible = true
			eventBanner.Position = UDim2.fromScale(0.26, -0.09)

			local dropTween = TweenService:Create(
				eventBanner,
				TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = UDim2.fromScale(0.26, 0.095) }
			)
			dropTween:Play()

			task.spawn(function()
				local start = os.clock()
				while (os.clock() - start) < duration do
					local rem = math.max(0, duration - (os.clock() - start))
					ebText.Text = string.format("%s | %ds restantes", title, math.ceil(rem))
					task.wait(0.5)
				end

				local retreatTween = TweenService:Create(
					eventBanner,
					TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Position = UDim2.fromScale(0.26, -0.09) }
				)
				retreatTween:Play()
				task.wait(0.4)
				eventBanner.Visible = false
			end)
		end
	end)
end

function UIManager.ShowNotification(title: string, message: string, accentColor: Color3?)
	if not toastContainer then
		return
	end
	local color = accentColor or Color3.fromRGB(0, 220, 255)

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.fromScale(1, 0.28)
	toast.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	toast.BorderSizePixel = 0
	toast.Parent = toastContainer

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 8)
	tCorner.Parent = toast

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = color
	tStroke.Thickness = 2
	tStroke.Parent = toast

	local tTitle = Instance.new("TextLabel")
	tTitle.Name = "Title"
	tTitle.Size = UDim2.fromScale(0.9, 0.45)
	tTitle.Position = UDim2.fromScale(0.05, 0.05)
	tTitle.BackgroundTransparency = 1
	tTitle.Text = title
	tTitle.TextColor3 = color
	tTitle.TextScaled = true
	tTitle.Font = Enum.Font.GothamBold
	tTitle.Parent = toast

	local tDesc = Instance.new("TextLabel")
	tDesc.Name = "Desc"
	tDesc.Size = UDim2.fromScale(0.9, 0.45)
	tDesc.Position = UDim2.fromScale(0.05, 0.5)
	tDesc.BackgroundTransparency = 1
	tDesc.Text = message
	tDesc.TextColor3 = Color3.fromRGB(220, 230, 245)
	tDesc.TextScaled = true
	tDesc.Font = Enum.Font.GothamMedium
	tDesc.Parent = toast

	-- Animated Dismiss
	task.delay(3.5, function()
		if toast and toast.Parent then
			local fade = TweenService:Create(
				toast,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			)
			fade:Play()
			task.delay(0.45, function()
				toast:Destroy()
			end)
		end
	end)
end

function UIManager.ShowWeaponUnlock(weaponId: string)
	local data = AssetIcons.GetWeaponData(weaponId)
	UIManager.ShowNotification(
		"¡NUEVA ARMA DESBLOQUEADA!",
		string.format("%s %s (Tier %d)", data.Glyph, data.Name, data.Tier),
		data.Color
	)
end

function UIManager.ShowGateUnlock(gateNumber: number)
	UIManager.ShowNotification(
		"¡COMPUERTA ABIERTA!",
		string.format("Acceso a Zona %d concedido. ¡Avanza!", gateNumber + 1),
		Color3.fromRGB(50, 255, 120)
	)
end

function UIManager.GetScreenGui(): ScreenGui?
	return mainScreenGui
end

return UIManager
