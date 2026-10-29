--!strict
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local JuiceFeedback = {}

local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

function JuiceFeedback.SpawnDamageNumber(position: Vector3, damage: number, isCritical: boolean)
	local part = Instance.new("Part")
	part.Name = "DamageIndicatorAnchor"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position + Vector3.new(0, 2.5, 0))
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageBillboard"
	billboard.Adornee = part
	billboard.Size = UDim2.fromScale(2.5, 1.2)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "NumberLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = if isCritical then string.format("-%d CRIT!", damage) else string.format("-%d", damage)
	label.TextColor3 = if isCritical then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(255, 220, 60)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	label.Parent = billboard

	-- Random horizontal spread
	local spreadX = (math.random() - 0.5) * 1.5
	local targetOffset = Vector3.new(spreadX, 2.2, 0)

	local tweenInfo = TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local moveTween = TweenService:Create(billboard, tweenInfo, {
		StudsOffset = targetOffset,
	})
	moveTween:Play()

	task.delay(0.35, function()
		if label.Parent then
			local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local fadeTween = TweenService:Create(label, fadeInfo, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			fadeTween:Play()
		end
	end)

	task.delay(0.7, function()
		part:Destroy()
	end)
end

function JuiceFeedback.ScreenShake(intensity: number)
	task.spawn(function()
		local curCamera = Workspace.CurrentCamera or camera
		local duration = 0.2
		local startTime = os.clock()
		local magnitude = math.clamp(intensity, 1, 10) * 0.08

		while (os.clock() - startTime) < duration do
			local offsetX = (math.random() - 0.5) * magnitude
			local offsetY = (math.random() - 0.5) * magnitude
			curCamera.CFrame = curCamera.CFrame * CFrame.Angles(math.rad(offsetY * 8), math.rad(offsetX * 8), 0)
			task.wait(0.02)
		end
	end)
end

function JuiceFeedback.CreateHitSparks(position: Vector3, normal: Vector3?)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://658724212" -- Universal spark texture fallback
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 100)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 120, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 30, 10)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.2, 0.45)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(15, 35)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.LightEmission = 1
	if normal then
		emitter.EmissionDirection = Enum.NormalId.Top
	end
	emitter.Parent = attachment

	emitter:Emit(18)

	Debris:AddItem(attachment, 0.6)
end

function JuiceFeedback.SpawnCreditPopup(position: Vector3?, amount: number, multiplier: number?)
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	local targetPos: Vector3
	if position then
		targetPos = position
	else
		local char = localPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		targetPos = if hrp then hrp.Position + Vector3.new(0, 3.2, 0) else Vector3.new(0, 5, 0)
	end

	local part = Instance.new("Part")
	part.Name = "CreditPopupAnchor"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(targetPos)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CreditBillboard"
	billboard.Adornee = part
	billboard.Size = UDim2.fromScale(3.2, 1.4)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "CreditLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	if multiplier and multiplier > 1.0 then
		label.Text = string.format("+%d 🪙 (x%.1f)", amount, multiplier)
	else
		label.Text = string.format("+%d 🪙", amount)
	end
	label.TextColor3 = Color3.fromRGB(255, 225, 50)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(20, 24, 35)
	label.Parent = billboard

	local spreadX = (math.random() - 0.5) * 1.2
	local targetOffset = Vector3.new(spreadX, 3.0, 0)

	local tweenInfo = TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local moveTween = TweenService:Create(billboard, tweenInfo, {
		StudsOffset = targetOffset,
	})
	moveTween:Play()

	task.delay(0.4, function()
		if label.Parent then
			local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local fadeTween = TweenService:Create(label, fadeInfo, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			fadeTween:Play()
		end
	end)

	task.delay(0.8, function()
		part:Destroy()
	end)
end

return JuiceFeedback
