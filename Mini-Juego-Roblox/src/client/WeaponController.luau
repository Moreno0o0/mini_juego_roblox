--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local Network = require(ReplicatedStorage.Shared.Network)
local WeaponsConfig = require(ReplicatedStorage.Shared.Config.WeaponsConfig)
local SoundManager = require(script.Parent.SoundManager)

local localPlayer = Players.LocalPlayer
local WeaponController = {}

local currentEquippedTool: Tool? = nil
local lastAttackTime = 0
local comboIndex = 0
local lastDashTime = 0
local isBlocking = false
local originalShoulderC0: CFrame? = nil
local currentShoulderMotor: Motor6D? = nil

local function PlayWeaponSwingVisuals(char: Model, tool: Tool, currentCombo: number)
	-- 1. Slash sound pitched by combo step
	local pitch = if currentCombo == 1 then 1.0 elseif currentCombo == 2 then 1.25 else 0.85
	SoundManager.PlaySound("SwordSlash", pitch)

	-- 2. Weapon Trail (if attached to the tool)
	for _, desc in ipairs(tool:GetDescendants()) do
		if desc:IsA("Trail") then
			desc.Enabled = true
			task.delay(0.22, function()
				if desc and desc.Parent then
					desc.Enabled = false
				end
			end)
		end
	end

	-- 3. Procedural Arm Swing with 3 distinct combo attack angles
	local rightUpperArm = char:FindFirstChild("RightUpperArm")
	local torso = char:FindFirstChild("Torso")
	local shoulder: Motor6D? = nil

	if rightUpperArm then
		shoulder = rightUpperArm:FindFirstChild("RightShoulder") :: Motor6D?
	elseif torso then
		shoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D?
	end

	if shoulder then
		if currentShoulderMotor ~= shoulder or not originalShoulderC0 then
			currentShoulderMotor = shoulder
			originalShoulderC0 = shoulder.C0
		end

		local origC0 = originalShoulderC0
		if origC0 then
			local slashC0: CFrame
			local swingDuration: number

			if currentCombo == 1 then
				-- Combo 1: Fast horizontal left slash
				slashC0 = origC0 * CFrame.Angles(math.rad(45), math.rad(30), math.rad(-25))
				swingDuration = 0.07
			elseif currentCombo == 2 then
				-- Combo 2: Fast cross right slash
				slashC0 = origC0 * CFrame.Angles(math.rad(65), math.rad(-25), math.rad(35))
				swingDuration = 0.07
			else
				-- Combo 3: Heavy Overhead Finisher Slam
				slashC0 = origC0 * CFrame.Angles(math.rad(95), math.rad(0), math.rad(0))
				swingDuration = 0.12
			end

			local swingTween = TweenService:Create(
				shoulder,
				TweenInfo.new(swingDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ C0 = slashC0 }
			)
			swingTween:Play()

			task.delay(swingDuration + 0.01, function()
				if shoulder and shoulder.Parent and origC0 then
					local returnTween = TweenService:Create(
						shoulder,
						TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ C0 = origC0 }
					)
					returnTween:Play()
				end
			end)
		end
	end

	-- 4. Trigger standard Animator track if available
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://522635560"
		pcall(function()
			local track = animator:LoadAnimation(anim)
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.04, 1, if currentCombo == 3 then 0.9 else 1.6)
		end)
	end
end

function WeaponController.PerformDash()
	local char = localPlayer.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end

	local now = os.clock()
	if (now - lastDashTime) < 2.0 then
		return
	end
	lastDashTime = now

	-- Direction: prioritize movement direction, fallback to camera/facing direction
	local dashDir = hum.MoveDirection
	if dashDir.Magnitude < 0.1 then
		dashDir = root.CFrame.LookVector
	end
	dashDir = Vector3.new(dashDir.X, 0, dashDir.Z).Unit

	-- Client-side smooth dash impulse
	local bv = Instance.new("BodyVelocity")
	bv.Name = "DashImpulse"
	bv.Velocity = dashDir * 52
	bv.MaxForce = Vector3.new(300000, 0, 300000)
	bv.Parent = root
	task.delay(0.20, function()
		if bv and bv.Parent then
			bv:Destroy()
		end
	end)

	-- Sound & particles
	SoundManager.PlaySound("EventAlert", 1.8, 0.4)

	-- Tell server authoritative dash action
	pcall(function()
		local actionRemote = Network.GetRemote("RequestCombatAction")
		actionRemote:FireServer("Dash")
	end)
end

function WeaponController.StartBlock()
	if isBlocking then
		return
	end
	isBlocking = true

	local char = localPlayer.Character
	if char then
		local rightUpperArm = char:FindFirstChild("RightUpperArm")
		local torso = char:FindFirstChild("Torso")
		local shoulder: Motor6D? = nil
		if rightUpperArm then
			shoulder = rightUpperArm:FindFirstChild("RightShoulder") :: Motor6D?
		elseif torso then
			shoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D?
		end

		if shoulder then
			if not originalShoulderC0 then
				originalShoulderC0 = shoulder.C0
			end
			local origC0 = originalShoulderC0
			if origC0 then
				local blockC0 = origC0 * CFrame.Angles(math.rad(80), math.rad(45), math.rad(-30))
				TweenService:Create(shoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = blockC0 }):Play()
			end
		end
	end

	pcall(function()
		local actionRemote = Network.GetRemote("RequestCombatAction")
		actionRemote:FireServer("Block", true)
	end)
end

function WeaponController.StopBlock()
	if not isBlocking then
		return
	end
	isBlocking = false

	local char = localPlayer.Character
	if char then
		local rightUpperArm = char:FindFirstChild("RightUpperArm")
		local torso = char:FindFirstChild("Torso")
		local shoulder: Motor6D? = nil
		if rightUpperArm then
			shoulder = rightUpperArm:FindFirstChild("RightShoulder") :: Motor6D?
		elseif torso then
			shoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D?
		end

		if shoulder and originalShoulderC0 then
			TweenService:Create(shoulder, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = originalShoulderC0 }):Play()
		end
	end

	pcall(function()
		local actionRemote = Network.GetRemote("RequestCombatAction")
		actionRemote:FireServer("Block", false)
	end)
end

local function FindBestTarget(range: number): (Instance?, Vector3)
	local char = localPlayer.Character
	if not char then
		return nil, Vector3.zero
	end

	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, Vector3.zero
	end

	local forward = root.CFrame.LookVector
	local defaultHitPos = root.Position + forward * math.min(range, 5)

	-- 1. Precision check: cursor raycast / hover (primary for PC mouse users)
	local mouse = localPlayer:GetMouse()
	local targetInstance = mouse.Target
	if targetInstance then
		local model = targetInstance:FindFirstAncestorOfClass("Model")
		if model and model ~= char then
			local player = Players:GetPlayerFromCharacter(model)
			local isDummy = (model:GetAttribute("IsDummy") == true) or (string.find(model.Name, "Dummy") ~= nil)
			if player or isDummy then
				local targetRoot = (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart) :: BasePart?
				if targetRoot and (targetRoot.Position - root.Position).Magnitude <= range * 1.5 then
					return (player or model), targetRoot.Position
				end
			end
		end
	end

	-- 2. Smart Aim Cone & Proximity across all viable targets (Players & Dummies)
	local bestTarget: Instance? = nil
	local bestDist = range * 1.35
	local bestPos = defaultHitPos

	local candidateModels: { [Model]: boolean } = {}

	-- Add other players
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= localPlayer and otherPlayer.Character then
			candidateModels[otherPlayer.Character] = true
		end
	end

	-- Add Training Dummies in Workspace
	local world = Workspace:FindFirstChild("World")
	if world then
		for _, desc in ipairs(world:GetDescendants()) do
			if desc:IsA("Model") and (desc:GetAttribute("IsDummy") == true or string.find(desc.Name, "Dummy") ~= nil) then
				candidateModels[desc] = true
			end
		end
	end

	for candModel in pairs(candidateModels) do
		local candHum = candModel:FindFirstChildOfClass("Humanoid")
		local candRoot = (candModel:FindFirstChild("HumanoidRootPart") or candModel:FindFirstChild("Torso") or candModel.PrimaryPart) :: BasePart?
		if candHum and candHum.Health > 0 and candRoot then
			local offset = candRoot.Position - root.Position
			local dist = offset.Magnitude
			if dist <= bestDist then
				local dir = offset.Unit
				local dot = forward:Dot(dir)
				-- Forward 70-degree cone (cos(70) ~ 0.34) or direct proximity (< 5 studs)
				if dot > 0.30 or dist < 5.0 then
					local player = Players:GetPlayerFromCharacter(candModel)
					bestTarget = player or candModel
					bestDist = dist
					bestPos = candRoot.Position
				end
			end
		end
	end

	if bestTarget then
		return bestTarget, bestPos
	end

	return nil, defaultHitPos
end

function WeaponController.OnToolActivated(tool: Tool)
	local weaponId = tool:GetAttribute("WeaponId")
	if not weaponId or typeof(weaponId) ~= "string" then
		return
	end

	local weaponDef = WeaponsConfig.Get(weaponId :: Types.WeaponId)
	if not weaponDef then
		return
	end

	local char = localPlayer.Character
	if char and char:GetAttribute("IsStaggered") == true then
		return
	end

	local now = os.clock()
	if (now - lastAttackTime) > 0.9 or comboIndex >= 3 then
		comboIndex = 1
	else
		comboIndex += 1
	end

	local cooldownMod = if comboIndex == 3 then 1.25 else 0.60
	local effectiveCooldown = weaponDef.Cooldown * cooldownMod
	if (now - lastAttackTime) < effectiveCooldown then
		return
	end
	lastAttackTime = now

	if char then
		PlayWeaponSwingVisuals(char, tool, comboIndex)
	end

	local targetInstance, hitPos = FindBestTarget(weaponDef.Range)

	-- Send authoritative request to server
	local attackRemote = Network.GetRemote("RequestAttack")
	attackRemote:FireServer(targetInstance, hitPos, weaponId)
end

local function SetupMobileCombatButtons()
	if not UserInputService.TouchEnabled then
		return
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	if playerGui:FindFirstChild("MobileCombatGui") then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MobileCombatGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- 1. Main Attack Button (⚔️)
	local attackButton = Instance.new("TextButton")
	attackButton.Name = "AttackButton"
	attackButton.Size = UDim2.fromOffset(80, 80)
	attackButton.Position = UDim2.new(1, -105, 1, -185)
	attackButton.BackgroundColor3 = Color3.fromRGB(220, 45, 45)
	attackButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	attackButton.Text = "⚔️"
	attackButton.TextScaled = true
	attackButton.Font = Enum.Font.GothamBlack
	attackButton.BorderSizePixel = 0
	attackButton.Parent = screenGui

	local corner1 = Instance.new("UICorner")
	corner1.CornerRadius = UDim.new(1, 0)
	corner1.Parent = attackButton

	local stroke1 = Instance.new("UIStroke")
	stroke1.Color = Color3.fromRGB(255, 180, 50)
	stroke1.Thickness = 3
	stroke1.Parent = attackButton

	local labelSub1 = Instance.new("TextLabel")
	labelSub1.Name = "SubText"
	labelSub1.Size = UDim2.fromScale(1, 0.3)
	labelSub1.Position = UDim2.fromScale(0, 0.7)
	labelSub1.BackgroundTransparency = 1
	labelSub1.Text = "ATACAR"
	labelSub1.TextColor3 = Color3.fromRGB(255, 255, 200)
	labelSub1.TextScaled = true
	labelSub1.Font = Enum.Font.GothamBold
	labelSub1.Parent = attackButton

	attackButton.Activated:Connect(function()
		local anim = TweenService:Create(attackButton, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(70, 70),
			Position = UDim2.new(1, -100, 1, -180),
		})
		anim:Play()
		task.delay(0.09, function()
			local returnAnim = TweenService:Create(attackButton, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(80, 80),
				Position = UDim2.new(1, -105, 1, -185),
			})
			returnAnim:Play()
		end)

		if currentEquippedTool then
			WeaponController.OnToolActivated(currentEquippedTool)
		else
			local backpack = localPlayer:FindFirstChildOfClass("Backpack")
			local char = localPlayer.Character
			if backpack and char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local tool = backpack:FindFirstChildOfClass("Tool")
				if hum and tool then
					hum:EquipTool(tool)
					task.defer(function()
						WeaponController.OnToolActivated(tool)
					end)
				end
			end
		end
	end)

	-- 2. Dash Button (💨 DASH)
	local dashButton = Instance.new("TextButton")
	dashButton.Name = "DashButton"
	dashButton.Size = UDim2.fromOffset(65, 65)
	dashButton.Position = UDim2.new(1, -185, 1, -165)
	dashButton.BackgroundColor3 = Color3.fromRGB(40, 140, 240)
	dashButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	dashButton.Text = "💨"
	dashButton.TextScaled = true
	dashButton.Font = Enum.Font.GothamBlack
	dashButton.BorderSizePixel = 0
	dashButton.Parent = screenGui

	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(1, 0)
	corner2.Parent = dashButton

	local stroke2 = Instance.new("UIStroke")
	stroke2.Color = Color3.fromRGB(150, 220, 255)
	stroke2.Thickness = 2.5
	stroke2.Parent = dashButton

	local labelSub2 = Instance.new("TextLabel")
	labelSub2.Name = "SubText"
	labelSub2.Size = UDim2.fromScale(1, 0.3)
	labelSub2.Position = UDim2.fromScale(0, 0.7)
	labelSub2.BackgroundTransparency = 1
	labelSub2.Text = "DASH"
	labelSub2.TextColor3 = Color3.fromRGB(200, 240, 255)
	labelSub2.TextScaled = true
	labelSub2.Font = Enum.Font.GothamBold
	labelSub2.Parent = dashButton

	dashButton.Activated:Connect(function()
		WeaponController.PerformDash()
	end)

	-- 3. Block / Guard Button (🛡️ DEF)
	local blockButton = Instance.new("TextButton")
	blockButton.Name = "BlockButton"
	blockButton.Size = UDim2.fromOffset(65, 65)
	blockButton.Position = UDim2.new(1, -105, 1, -265)
	blockButton.BackgroundColor3 = Color3.fromRGB(230, 160, 30)
	blockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	blockButton.Text = "🛡️"
	blockButton.TextScaled = true
	blockButton.Font = Enum.Font.GothamBlack
	blockButton.BorderSizePixel = 0
	blockButton.Parent = screenGui

	local corner3 = Instance.new("UICorner")
	corner3.CornerRadius = UDim.new(1, 0)
	corner3.Parent = blockButton

	local stroke3 = Instance.new("UIStroke")
	stroke3.Color = Color3.fromRGB(255, 230, 120)
	stroke3.Thickness = 2.5
	stroke3.Parent = blockButton

	local labelSub3 = Instance.new("TextLabel")
	labelSub3.Name = "SubText"
	labelSub3.Size = UDim2.fromScale(1, 0.3)
	labelSub3.Position = UDim2.fromScale(0, 0.7)
	labelSub3.BackgroundTransparency = 1
	labelSub3.Text = "DEF"
	labelSub3.TextColor3 = Color3.fromRGB(255, 255, 200)
	labelSub3.TextScaled = true
	labelSub3.Font = Enum.Font.GothamBold
	labelSub3.Parent = blockButton

	blockButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			WeaponController.StartBlock()
		end
	end)

	blockButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			WeaponController.StopBlock()
		end
	end)
end

function WeaponController.Init()
	local function SetupCharacter(char: Model)
		char.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Tool") then
				currentEquippedTool = child
				child.Activated:Connect(function()
					WeaponController.OnToolActivated(child)
				end)
			end
		end)

		char.ChildRemoved:Connect(function(child: Instance)
			if child == currentEquippedTool then
				currentEquippedTool = nil
			end
		end)
	end

	if localPlayer.Character then
		SetupCharacter(localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(SetupCharacter)

	-- Desktop Keybinds: 'Q' for Dash, 'F' for Block / Parry
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.Q then
			WeaponController.PerformDash()
		elseif input.KeyCode == Enum.KeyCode.F then
			WeaponController.StartBlock()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.F then
			WeaponController.StopBlock()
		end
	end)

	-- Setup Mobile UI if on touch device
	SetupMobileCombatButtons()
end

return WeaponController
