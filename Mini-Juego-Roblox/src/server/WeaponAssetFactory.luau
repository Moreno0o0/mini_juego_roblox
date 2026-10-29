--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponAssetFactory = {}

local function EnsureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function CreateWeld(part0: BasePart, part1: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
end

local function CreatePart(
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	isMassless: boolean,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.Massless = isMassless
	part.Transparency = transparency or 0
	part.Parent = parent
	return part
end

local function AttachMeleeTrail(bladePart: BasePart, color: ColorSequence): Trail
	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, -bladePart.Size.Y * 0.45, 0)
	att0.Parent = bladePart

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, bladePart.Size.Y * 0.45, 0)
	att1.Parent = bladePart

	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = color
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.Lifetime = 0.22
	trail.LightEmission = 0.8
	trail.Parent = bladePart
	return trail
end

local function AttachMuzzleVFX(muzzlePart: BasePart, glowColor: Color3)
	local light = Instance.new("PointLight")
	light.Name = "MuzzleGlow"
	light.Color = glowColor
	light.Range = 6
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = muzzlePart
end

function WeaponAssetFactory.BuildWeapons(): Folder
	local assetsFolder = EnsureFolder(ReplicatedStorage, "Assets")
	local weaponsFolder = EnsureFolder(assetsFolder, "Weapons")

	-- Clear old tools if re-running
	for _, child in ipairs(weaponsFolder:GetChildren()) do
		child:Destroy()
	end

	-- 0. Fists / Puños (Tier 1 Default Attack)
	do
		local tool = Instance.new("Tool")
		tool.Name = "Puños"
		tool.RequiresHandle = true
		tool:SetAttribute("WeaponId", "w_0")
		tool:SetAttribute("Tier", 1)

		local handle = CreatePart("Handle", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 0, 0), Color3.fromRGB(40, 40, 45), Enum.Material.SmoothPlastic, tool, false, 1.0)
		local glove = CreatePart("GloveRight", Vector3.new(0.8, 0.8, 0.9), CFrame.new(0, 0, -0.4), Color3.fromRGB(35, 40, 50), Enum.Material.Fabric, tool, true)
		local knuckles = CreatePart("Knuckles", Vector3.new(0.85, 0.25, 0.25), CFrame.new(0, 0.25, -0.8), Color3.fromRGB(0, 200, 255), Enum.Material.Neon, tool, true)
		local hitbox = CreatePart("Hitbox", Vector3.new(1.2, 1.2, 1.8), CFrame.new(0, 0, -0.4), Color3.fromRGB(255, 0, 0), Enum.Material.ForceField, tool, true, 1.0)

		CreateWeld(handle, glove)
		CreateWeld(handle, knuckles)
		CreateWeld(handle, hitbox)

		AttachMeleeTrail(glove, ColorSequence.new(Color3.fromRGB(0, 220, 255), Color3.fromRGB(0, 100, 255)))

		tool.PrimaryPart = handle
		tool.Parent = weaponsFolder
	end

	-- 1. WoodBat (Tier 1 Melee)
	do
		local tool = Instance.new("Tool")
		tool.Name = "WoodBat"
		tool.RequiresHandle = true
		tool:SetAttribute("WeaponId", "w_1")
		tool:SetAttribute("Tier", 1)

		local handle = CreatePart("Handle", Vector3.new(0.8, 3.8, 0.8), CFrame.new(0, 0, 0), Color3.fromRGB(150, 105, 60), Enum.Material.Wood, tool, false)
		local gripTape = CreatePart("GripTape", Vector3.new(0.85, 1.4, 0.85), CFrame.new(0, -1.0, 0), Color3.fromRGB(30, 30, 30), Enum.Material.Fabric, tool, true)
		local batHead = CreatePart("BatHead", Vector3.new(1.1, 1.8, 1.1), CFrame.new(0, 1.0, 0), Color3.fromRGB(165, 115, 65), Enum.Material.Wood, tool, true)
		local hitbox = CreatePart("Hitbox", Vector3.new(1.4, 4.2, 1.4), CFrame.new(0, 0.5, 0), Color3.fromRGB(255, 0, 0), Enum.Material.ForceField, tool, true, 1.0)

		CreateWeld(handle, gripTape)
		CreateWeld(handle, batHead)
		CreateWeld(handle, hitbox)

		AttachMeleeTrail(batHead, ColorSequence.new(Color3.fromRGB(255, 200, 100), Color3.fromRGB(180, 120, 50)))

		tool.PrimaryPart = handle
		tool.Parent = weaponsFolder
	end

	-- 2. Knife (Tier 2 Melee)
	do
		local tool = Instance.new("Tool")
		tool.Name = "Knife"
		tool.RequiresHandle = true
		tool:SetAttribute("WeaponId", "w_2a")
		tool:SetAttribute("Tier", 2)

		local handle = CreatePart("Handle", Vector3.new(0.4, 1.2, 0.4), CFrame.new(0, 0, 0), Color3.fromRGB(35, 38, 42), Enum.Material.Metal, tool, false)
		local guard = CreatePart("Guard", Vector3.new(0.9, 0.15, 0.5), CFrame.new(0, 0.6, 0), Color3.fromRGB(50, 55, 65), Enum.Material.Metal, tool, true)
		local blade = CreatePart("Blade", Vector3.new(0.2, 1.8, 0.5), CFrame.new(0, 1.5, 0), Color3.fromRGB(210, 215, 225), Enum.Material.Metal, tool, true)
		local hitbox = CreatePart("Hitbox", Vector3.new(0.8, 2.5, 0.8), CFrame.new(0, 1.0, 0), Color3.fromRGB(255, 0, 0), Enum.Material.ForceField, tool, true, 1.0)

		CreateWeld(handle, guard)
		CreateWeld(handle, blade)
		CreateWeld(handle, hitbox)

		AttachMeleeTrail(blade, ColorSequence.new(Color3.fromRGB(100, 255, 180), Color3.fromRGB(40, 180, 100)))

		tool.PrimaryPart = handle
		tool.Parent = weaponsFolder
	end

	-- 3. Slingshot (Tier 2 Ranged)
	do
		local tool = Instance.new("Tool")
		tool.Name = "Slingshot"
		tool.RequiresHandle = true
		tool:SetAttribute("WeaponId", "w_2b")
		tool:SetAttribute("Tier", 2)

		local handle = CreatePart("Handle", Vector3.new(0.5, 1.5, 0.5), CFrame.new(0, 0, 0), Color3.fromRGB(130, 85, 45), Enum.Material.Wood, tool, false)
		local fork = CreatePart("Fork", Vector3.new(1.4, 1.0, 0.4), CFrame.new(0, 1.1, 0), Color3.fromRGB(140, 95, 55), Enum.Material.Wood, tool, true)
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "MuzzlePoint"
		muzzle.Position = Vector3.new(0, 0.6, 0)
		muzzle.Parent = fork

		CreateWeld(handle, fork)
		AttachMuzzleVFX(fork, Color3.fromRGB(100, 255, 120))

		tool.PrimaryPart = handle
		tool.Parent = weaponsFolder
	end

	-- 4. ShortSword (Tier 3 Melee)
	do
		local tool = Instance.new("Tool")
		tool.Name = "ShortSword"
		tool.RequiresHandle = true
		tool:SetAttribute("WeaponId", "w_3a")
		tool:SetAttribute("Tier", 3)

		local handle = CreatePart("Handle", Vector3.new(0.5, 1.4, 0.5), CFrame.new(0, 0, 0), Color3.fromRGB(55, 45, 35), Enum.Material.Wood, tool, false)
		local guard = CreatePart("Guard", Vector3.new(1.8, 0.3, 0.6), CFrame.new(0, 0.8, 0), Color3.fromRGB(230, 190, 45), Enum.Material.Metal, tool, true)
		local blade = CreatePart("Blade", Vector3.new(0.3, 3.2, 0.7), CFrame.new(0, 2.4, 0), Color3.fromRGB(220, 225, 235), Enum.Material.Metal, tool, true)
		local fuller = CreatePart("Fuller", Vector3.new(0.1, 2.6, 0.15), CFrame.new(0, 2.4, 0), Color3.fromRGB(255, 220, 80), Enum.Material.Neon, tool, true)
		local hitbox = CreatePart("Hitbox", Vector3.new(1.2, 4.0, 1.2), CFrame.new(0, 2.2, 0), Color3.fromRGB(255, 0, 0), Enum.Material.ForceField, tool, true, 1.0)

		CreateWeld(handle, guard)
		CreateWeld(handle, blade)
		CreateWeld(blade, fuller)
		CreateWeld(handle, hitbox)

		AttachMeleeTrail(blade, ColorSequence.new(Color3.fromRGB(255, 220, 50), Color3.fromRGB(255, 160, 0)))

		tool.PrimaryPart = handle
		tool.Parent = weaponsFolder
	end

	-- 5. BasicPistol (Tier 3 Ranged)
	do
		local tool = Instance.new("Tool")
		tool.Name = "BasicPistol"
		tool.RequiresHandle = true
		tool:SetAttribute("WeaponId", "w_3b")
		tool:SetAttribute("Tier", 3)

		local handle = CreatePart("Handle", Vector3.new(0.6, 1.4, 0.8), CFrame.new(0, 0, 0), Color3.fromRGB(30, 32, 38), Enum.Material.Metal, tool, false)
		local barrel = CreatePart("Barrel", Vector3.new(0.6, 0.7, 2.2), CFrame.new(0, 0.8, -0.7), Color3.fromRGB(22, 24, 28), Enum.Material.Metal, tool, true)
		local sight = CreatePart("Sight", Vector3.new(0.15, 0.2, 0.3), CFrame.new(0, 1.2, -1.6), Color3.fromRGB(255, 220, 0), Enum.Material.Neon, tool, true)
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "MuzzlePoint"
		muzzle.Position = Vector3.new(0, 0, -1.1)
		muzzle.Parent = barrel

		CreateWeld(handle, barrel)
		CreateWeld(barrel, sight)
		AttachMuzzleVFX(barrel, Color3.fromRGB(255, 200, 50))

		tool.PrimaryPart = handle
		tool.Parent = weaponsFolder
	end

	-- 6. Katana (Tier 4 Melee)
	do
		local tool = Instance.new("Tool")
		tool.Name = "Katana"
		tool.RequiresHandle = true
		tool:SetAttribute("WeaponId", "w_4a")
		tool:SetAttribute("Tier", 4)

		local handle = CreatePart("Handle", Vector3.new(0.4, 1.8, 0.4), CFrame.new(0, 0, 0), Color3.fromRGB(18, 18, 22), Enum.Material.Fabric, tool, false)
		local tsuba = CreatePart("Tsuba", Vector3.new(1.3, 0.2, 1.1), CFrame.new(0, 1.0, 0), Color3.fromRGB(210, 160, 30), Enum.Material.Metal, tool, true)
		local blade = CreatePart("Blade", Vector3.new(0.2, 4.6, 0.6), CFrame.new(0, 3.3, 0), Color3.fromRGB(235, 240, 250), Enum.Material.Metal, tool, true)
		local edgeNeon = CreatePart("EdgeNeon", Vector3.new(0.08, 4.4, 0.1), CFrame.new(0, 3.3, 0.25), Color3.fromRGB(255, 120, 0), Enum.Material.Neon, tool, true)
		local hitbox = CreatePart("Hitbox", Vector3.new(1.0, 5.2, 1.0), CFrame.new(0, 3.2, 0), Color3.fromRGB(255, 0, 0), Enum.Material.ForceField, tool, true, 1.0)

		CreateWeld(handle, tsuba)
		CreateWeld(handle, blade)
		CreateWeld(blade, edgeNeon)
		CreateWeld(handle, hitbox)

		AttachMeleeTrail(blade, ColorSequence.new(Color3.fromRGB(255, 130, 20), Color3.fromRGB(255, 50, 0)))

		tool.PrimaryPart = handle
		tool.Parent = weaponsFolder
	end

	-- 7. Shotgun (Tier 4 Ranged)
	do
		local tool = Instance.new("Tool")
		tool.Name = "Shotgun"
		tool.RequiresHandle = true
		tool:SetAttribute("WeaponId", "w_4b")
		tool:SetAttribute("Tier", 4)

		local handle = CreatePart("Handle", Vector3.new(0.6, 1.6, 1.0), CFrame.new(0, 0, 0), Color3.fromRGB(110, 70, 35), Enum.Material.Wood, tool, false)
		local receiver = CreatePart("Receiver", Vector3.new(0.8, 0.9, 1.6), CFrame.new(0, 0.7, -0.5), Color3.fromRGB(25, 27, 32), Enum.Material.Metal, tool, true)
		local barrel = CreatePart("Barrel", Vector3.new(0.7, 0.7, 3.4), CFrame.new(0, 0.7, -2.2), Color3.fromRGB(28, 30, 35), Enum.Material.Metal, tool, true)
		local pump = CreatePart("Pump", Vector3.new(0.9, 0.9, 1.2), CFrame.new(0, 0.7, -1.8), Color3.fromRGB(100, 60, 30), Enum.Material.Wood, tool, true)
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "MuzzlePoint"
		muzzle.Position = Vector3.new(0, 0, -1.7)
		muzzle.Parent = barrel

		CreateWeld(handle, receiver)
		CreateWeld(receiver, barrel)
		CreateWeld(receiver, pump)
		AttachMuzzleVFX(barrel, Color3.fromRGB(255, 140, 40))

		tool.PrimaryPart = handle
		tool.Parent = weaponsFolder
	end

	-- 8. HeavyHammer (Tier 5 Melee)
	do
		local tool = Instance.new("Tool")
		tool.Name = "HeavyHammer"
		tool.RequiresHandle = true
		tool:SetAttribute("WeaponId", "w_5a")
		tool:SetAttribute("Tier", 5)

		local handle = CreatePart("Handle", Vector3.new(0.7, 5.0, 0.7), CFrame.new(0, 0, 0), Color3.fromRGB(45, 40, 50), Enum.Material.Metal, tool, false)
		local head = CreatePart("Head", Vector3.new(2.6, 2.2, 3.0), CFrame.new(0, 2.8, 0), Color3.fromRGB(28, 30, 40), Enum.Material.DiamondPlate, tool, true)
		local powerCore1 = CreatePart("PowerCore1", Vector3.new(0.4, 1.6, 2.8), CFrame.new(1.31, 2.8, 0), Color3.fromRGB(220, 20, 255), Enum.Material.Neon, tool, true)
		local powerCore2 = CreatePart("PowerCore2", Vector3.new(0.4, 1.6, 2.8), CFrame.new(-1.31, 2.8, 0), Color3.fromRGB(220, 20, 255), Enum.Material.Neon, tool, true)
		local hitbox = CreatePart("Hitbox", Vector3.new(3.4, 3.2, 3.8), CFrame.new(0, 2.8, 0), Color3.fromRGB(255, 0, 0), Enum.Material.ForceField, tool, true, 1.0)

		CreateWeld(handle, head)
		CreateWeld(head, powerCore1)
		CreateWeld(head, powerCore2)
		CreateWeld(handle, hitbox)

		AttachMeleeTrail(head, ColorSequence.new(Color3.fromRGB(220, 40, 255), Color3.fromRGB(150, 0, 255)))

		tool.PrimaryPart = handle
		tool.Parent = weaponsFolder
	end

	-- 9. PlasmaRifle (Tier 5 Ranged)
	do
		local tool = Instance.new("Tool")
		tool.Name = "PlasmaRifle"
		tool.RequiresHandle = true
		tool:SetAttribute("WeaponId", "w_5b")
		tool:SetAttribute("Tier", 5)

		local handle = CreatePart("Handle", Vector3.new(0.6, 1.6, 1.0), CFrame.new(0, 0, 0), Color3.fromRGB(18, 22, 30), Enum.Material.Metal, tool, false)
		local body = CreatePart("Body", Vector3.new(0.9, 1.2, 3.0), CFrame.new(0, 0.8, -0.9), Color3.fromRGB(28, 35, 48), Enum.Material.Metal, tool, true)
		local core = CreatePart("PlasmaCore", Vector3.new(0.7, 0.7, 1.2), CFrame.new(0, 0.8, -0.9), Color3.fromRGB(0, 240, 255), Enum.Material.Neon, tool, true)
		local topRail = CreatePart("TopRail", Vector3.new(0.4, 0.3, 2.4), CFrame.new(0, 1.5, -0.9), Color3.fromRGB(0, 200, 255), Enum.Material.Neon, tool, true)
		local barrel = CreatePart("Barrel", Vector3.new(0.7, 0.7, 1.8), CFrame.new(0, 0.8, -2.8), Color3.fromRGB(15, 20, 28), Enum.Material.DiamondPlate, tool, true)
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "MuzzlePoint"
		muzzle.Position = Vector3.new(0, 0, -0.9)
		muzzle.Parent = barrel

		CreateWeld(handle, body)
		CreateWeld(body, core)
		CreateWeld(body, topRail)
		CreateWeld(body, barrel)
		AttachMuzzleVFX(barrel, Color3.fromRGB(0, 240, 255))

		tool.PrimaryPart = handle
		tool.Parent = weaponsFolder
	end

	return weaponsFolder
end

return WeaponAssetFactory
