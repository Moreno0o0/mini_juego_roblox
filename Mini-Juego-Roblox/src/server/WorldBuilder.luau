--!strict
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ZonesConfig = require(ReplicatedStorage.Shared.Config.ZonesConfig)
local CollisionManager = require(ServerScriptService.Server.CollisionManager)

local WorldBuilder = {}

local ZONE_THEME_COLORS: { [number]: Color3 } = {
	[1] = Color3.fromRGB(0, 160, 255), -- Zona 1: Azul Cyberpunk
	[2] = Color3.fromRGB(0, 255, 128), -- Zona 2: Verde Neón
	[3] = Color3.fromRGB(255, 215, 0), -- Zona 3: Amarillo Eléctrico
	[4] = Color3.fromRGB(255, 120, 0), -- Zona 4: Naranja Industrial
	[5] = Color3.fromRGB(210, 20, 255), -- Zona 5: Púrpura / Carmesí Coliseo
}

local MINIGAME_TITLES: { [number]: string } = {
	[1] = "M1: REFLEX QTE",
	[2] = "M2: PLATAFORMAS",
	[3] = "M3: TARGET PRACTICE",
	[4] = "M4: MEMORY MATRIX",
	[5] = "M5: BULLET HELL",
}

local ZONE_DISPENSER_INFO: { [number]: { WeaponId: string, WeaponName: string, Title: string, Subtitle: string } } = {
	[1] = { WeaponId = "w_1", WeaponName = "Bate de Madera", Title = "ARMERÍA ZONA 1", Subtitle = "¡Toma tu Bate de Madera gratis!" },
	[2] = { WeaponId = "w_2a", WeaponName = "Cuchillo Táctico", Title = "ARMERÍA ZONA 2", Subtitle = "¡Toma tu Cuchillo Táctico gratis!" },
	[3] = { WeaponId = "w_3a", WeaponName = "Espada Corta", Title = "ARMERÍA ZONA 3", Subtitle = "¡Toma tu Espada Corta gratis!" },
	[4] = { WeaponId = "w_4a", WeaponName = "Katana", Title = "ARMERÍA ZONA 4", Subtitle = "¡Toma tu Katana gratis!" },
	[5] = { WeaponId = "w_5a", WeaponName = "Martillo Pesado", Title = "ARMERÍA ZONA 5", Subtitle = "¡Toma tu Martillo Pesado gratis!" },
}

local function CreatePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	anchored: boolean,
	canCollide: boolean,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = anchored
	part.CanCollide = canCollide
	part.Parent = parent
	return part
end

function WorldBuilder.BuildWorld(): Folder
	CollisionManager.Init()

	-- 1. Desactivar acceso al Baseplate exterior y limpiar entidades residuales
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.CanCollide = false
		baseplate.Transparency = 1
	end

	-- Limpiar modelos dummy 'Char', 'Char1', etc., y SpawnLocation exterior
	for _, child in ipairs(Workspace:GetChildren()) do
		if (child:IsA("Model") and string.find(child.Name, "Char") ~= nil) or (child:IsA("SpawnLocation") and child.Name == "SpawnLocation") then
			child:Destroy()
		end
	end

	-- Remove previous world if exists
	local existingWorld = Workspace:FindFirstChild("World")
	if existingWorld then
		existingWorld:Destroy()
	end

	local worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = Workspace

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = worldFolder

	local gatesFolder = Instance.new("Folder")
	gatesFolder.Name = "Gates"
	gatesFolder.Parent = worldFolder

	local corridorsFolder = Instance.new("Folder")
	corridorsFolder.Name = "Corridors"
	corridorsFolder.Parent = worldFolder

	local wallThickness = 2
	local wallHeight = 30
	local corridorWidth = 24
	local halfCorridor = corridorWidth / 2

	-- Build 5 Zones
	for i = 1, 5 do
		local zoneDef = ZonesConfig.GetByIndex(i)
		assert(zoneDef ~= nil, "Zone definition missing for index " .. i)

		local themeColor = ZONE_THEME_COLORS[i] or Color3.fromRGB(0, 200, 255)
		local zoneModel = Instance.new("Model")
		zoneModel.Name = zoneDef.Id
		zoneModel:SetAttribute("ZoneId", zoneDef.Id)
		zoneModel:SetAttribute("MachineId", zoneDef.AssociatedMachineId)
		zoneModel:SetAttribute("Tier", zoneDef.Tier)
		zoneModel.Parent = zonesFolder

		local cx = zoneDef.Center.X
		local cz = zoneDef.Center.Z
		local sx = zoneDef.Size.X
		local sz = zoneDef.Size.Z
		local hx = sx / 2
		local hz = sz / 2
		local wallCenterY = 1 + wallHeight / 2 -- Floor top is Y=1, so center is Y=16

		-- 1. Floor
		local floorColor = Color3.fromRGB(20 + i * 5, 22 + i * 5, 28 + i * 5)
		local floor = CreatePart(
			"Floor",
			Vector3.new(sx, 2, sz),
			CFrame.new(cx, 0, cz),
			floorColor,
			Enum.Material.SmoothPlastic,
			true,
			true,
			zoneModel
		)
		zoneModel.PrimaryPart = floor

		-- Floor Inset Border (SmoothPlastic)
		local floorTrimN = CreatePart(
			"FloorTrimN",
			Vector3.new(sx - 2, 0.2, 0.8),
			CFrame.new(cx, 1.05, cz + hz - 1),
			themeColor,
			Enum.Material.SmoothPlastic,
			true,
			false,
			zoneModel
		)
		floorTrimN.CanTouch = false

		local floorTrimS = CreatePart(
			"FloorTrimS",
			Vector3.new(sx - 2, 0.2, 0.8),
			CFrame.new(cx, 1.05, cz - hz + 1),
			themeColor,
			Enum.Material.SmoothPlastic,
			true,
			false,
			zoneModel
		)
		floorTrimS.CanTouch = false

		-- 2. Hermetic Cyberpunk Arena Enclosure (Muros de 30 studs)
		-- North Wall (Full Width)
		CreatePart(
			"WallNorth",
			Vector3.new(sx + wallThickness * 2, wallHeight, wallThickness),
			CFrame.new(cx, wallCenterY, cz + hz + wallThickness / 2),
			Color3.fromRGB(24, 26, 34),
			Enum.Material.SmoothPlastic,
			true,
			true,
			zoneModel
		)
		-- Trim North (SmoothPlastic)
		local trimN = CreatePart(
			"WallTrimNorth",
			Vector3.new(sx + wallThickness * 2, 0.8, wallThickness + 0.2),
			CFrame.new(cx, wallCenterY + wallHeight / 2 - 1, cz + hz + wallThickness / 2),
			themeColor,
			Enum.Material.SmoothPlastic,
			true,
			false,
			zoneModel
		)
		trimN.CanTouch = false

		-- South Wall (Full Width)
		CreatePart(
			"WallSouth",
			Vector3.new(sx + wallThickness * 2, wallHeight, wallThickness),
			CFrame.new(cx, wallCenterY, cz - hz - wallThickness / 2),
			Color3.fromRGB(24, 26, 34),
			Enum.Material.SmoothPlastic,
			true,
			true,
			zoneModel
		)
		-- Trim South (SmoothPlastic)
		local trimS = CreatePart(
			"WallTrimSouth",
			Vector3.new(sx + wallThickness * 2, 0.8, wallThickness + 0.2),
			CFrame.new(cx, wallCenterY + wallHeight / 2 - 1, cz - hz - wallThickness / 2),
			themeColor,
			Enum.Material.SmoothPlastic,
			true,
			false,
			zoneModel
		)
		trimS.CanTouch = false

		-- West Wall
		if i == 1 then
			-- Closed solid wall
			CreatePart(
				"WallWest",
				Vector3.new(wallThickness, wallHeight, sz),
				CFrame.new(cx - hx - wallThickness / 2, wallCenterY, cz),
				Color3.fromRGB(24, 26, 34),
				Enum.Material.SmoothPlastic,
				true,
				true,
				zoneModel
			)
		else
			-- Connects to corridor from Zone i-1 (opening of corridorWidth studs in center)
			local segLength = hz - halfCorridor
			local segCenterOffset = halfCorridor + segLength / 2
			-- West North segment
			CreatePart(
				"WallWestNorth",
				Vector3.new(wallThickness, wallHeight, segLength),
				CFrame.new(cx - hx - wallThickness / 2, wallCenterY, cz + segCenterOffset),
				Color3.fromRGB(24, 26, 34),
				Enum.Material.SmoothPlastic,
				true,
				true,
				zoneModel
			)
			-- West South segment
			CreatePart(
				"WallWestSouth",
				Vector3.new(wallThickness, wallHeight, segLength),
				CFrame.new(cx - hx - wallThickness / 2, wallCenterY, cz - segCenterOffset),
				Color3.fromRGB(24, 26, 34),
				Enum.Material.SmoothPlastic,
				true,
				true,
				zoneModel
			)
		end

		-- East Wall
		if i == 5 then
			-- Closed solid wall
			CreatePart(
				"WallEast",
				Vector3.new(wallThickness, wallHeight, sz),
				CFrame.new(cx + hx + wallThickness / 2, wallCenterY, cz),
				Color3.fromRGB(24, 26, 34),
				Enum.Material.SmoothPlastic,
				true,
				true,
				zoneModel
			)
		else
			-- Connects to corridor to Zone i+1
			local segLength = hz - halfCorridor
			local segCenterOffset = halfCorridor + segLength / 2
			-- East North segment
			CreatePart(
				"WallEastNorth",
				Vector3.new(wallThickness, wallHeight, segLength),
				CFrame.new(cx + hx + wallThickness / 2, wallCenterY, cz + segCenterOffset),
				Color3.fromRGB(24, 26, 34),
				Enum.Material.SmoothPlastic,
				true,
				true,
				zoneModel
			)
			-- East South segment
			CreatePart(
				"WallEastSouth",
				Vector3.new(wallThickness, wallHeight, segLength),
				CFrame.new(cx + hx + wallThickness / 2, wallCenterY, cz - segCenterOffset),
				Color3.fromRGB(24, 26, 34),
				Enum.Material.SmoothPlastic,
				true,
				true,
				zoneModel
			)
		end

		-- 3. Four Corner Cyberpunk Pillars with Neon Strips
		local cornerOffsets = {
			Vector3.new(hx, 0, hz),
			Vector3.new(-hx, 0, hz),
			Vector3.new(hx, 0, -hz),
			Vector3.new(-hx, 0, -hz),
		}
		for idx, offset in ipairs(cornerOffsets) do
			local pillar = CreatePart(
				"Pillar_" .. idx,
				Vector3.new(4, wallHeight, 4),
				CFrame.new(cx + offset.X, wallCenterY, cz + offset.Z),
				Color3.fromRGB(35, 38, 48),
				Enum.Material.SmoothPlastic,
				true,
				true,
				zoneModel
			)
			local pillarStrip = CreatePart(
				"PillarNeon_" .. idx,
				Vector3.new(1.4, wallHeight - 2, 1.4),
				CFrame.new(cx + offset.X, wallCenterY, cz + offset.Z),
				themeColor,
				Enum.Material.SmoothPlastic,
				true,
				false,
				pillar
			)
			pillarStrip.CanTouch = false

			-- High-Intensity Cyberpunk Arena Floodlight (eliminates pitch black shadows at night)
			local pLight = Instance.new("PointLight")
			pLight.Name = "ArenaFloodlight"
			pLight.Brightness = 3.5
			pLight.Range = 65
			pLight.Color = themeColor
			pLight.Shadows = true
			pLight.Parent = pillarStrip
		end

		-- 4. Techo Hermético Superior de la Arena (Elimina destellos del cielo exterior)
		local roof = CreatePart(
			"ArenaCeiling",
			Vector3.new(sx + wallThickness * 2, 2, sz + wallThickness * 2),
			CFrame.new(cx, 1 + wallHeight + 1, cz), -- Y = 32
			Color3.fromRGB(16, 18, 26),
			Enum.Material.SmoothPlastic,
			true,
			true,
			zoneModel
		)
		roof.CastShadow = false

		-- 5. SpawnLocation (Base mate suave con borde de acento)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnLocation_" .. i
		spawn.Size = Vector3.new(8, 0.4, 8)
		spawn.CFrame = CFrame.lookAt(zoneDef.SpawnPosition, Vector3.new(zoneDef.Center.X, zoneDef.SpawnPosition.Y, zoneDef.Center.Z))
		spawn.Color = Color3.fromRGB(24, 28, 38)
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Anchored = true
		spawn.CanCollide = true
		spawn.Neutral = (i == 1) -- Only Zone 1 is neutral default spawn
		spawn.Enabled = true
		spawn.Duration = 0
		spawn.Parent = zoneModel

		local spawnTrim = CreatePart(
			"SpawnTrim",
			Vector3.new(8.2, 0.2, 8.2),
			spawn.CFrame * CFrame.new(0, -0.15, 0),
			themeColor,
			Enum.Material.SmoothPlastic,
			true,
			false,
			zoneModel
		)
		spawnTrim.CanTouch = false

		-- 5.1 Weapon Dispenser in Zone i (Armería básica de zona)
		local dispInfo = ZONE_DISPENSER_INFO[i] or ZONE_DISPENSER_INFO[1]
		local dispenserModel = Instance.new("Model")
		dispenserModel.Name = "WeaponDispenser"
		dispenserModel:SetAttribute("ZoneTier", i)
		dispenserModel:SetAttribute("WeaponId", dispInfo.WeaponId)
		dispenserModel.Parent = zoneModel

		local dispPos = Vector3.new(cx - 24, 1, cz - 22)

		-- Pedestal Base
		local basePart = CreatePart(
			"DispenserBase",
			Vector3.new(6, 1.4, 4),
			CFrame.new(dispPos + Vector3.new(0, 0.7, 0)),
			Color3.fromRGB(24, 28, 38),
			Enum.Material.SmoothPlastic,
			true,
			true,
			dispenserModel
		)
		dispenserModel.PrimaryPart = basePart

		-- Accent Rim
		local rim = CreatePart(
			"NeonRim",
			Vector3.new(6.2, 0.2, 4.2),
			CFrame.new(dispPos + Vector3.new(0, 1.4, 0)),
			themeColor,
			Enum.Material.SmoothPlastic,
			true,
			false,
			dispenserModel
		)
		rim.CanTouch = false

		-- Rack Pillars
		CreatePart(
			"RackPillarL",
			Vector3.new(0.5, 3.2, 0.5),
			CFrame.new(dispPos + Vector3.new(-1.8, 3.0, 0)),
			Color3.fromRGB(45, 50, 65),
			Enum.Material.SmoothPlastic,
			true,
			true,
			dispenserModel
		)
		CreatePart(
			"RackPillarR",
			Vector3.new(0.5, 3.2, 0.5),
			CFrame.new(dispPos + Vector3.new(1.8, 3.0, 0)),
			Color3.fromRGB(45, 50, 65),
			Enum.Material.SmoothPlastic,
			true,
			true,
			dispenserModel
		)

		-- Display Weapon Model
		local weaponDisplay = CreatePart(
			"DisplayWeapon",
			Vector3.new(0.7, 3.6, 0.7),
			CFrame.new(dispPos + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(70)),
			Color3.fromRGB(160, 110, 60),
			Enum.Material.SmoothPlastic,
			true,
			false,
			dispenserModel
		)
		weaponDisplay.CanTouch = false

		-- Weapon Accent
		local weaponTrim = CreatePart(
			"DisplayWeaponNeon",
			Vector3.new(0.8, 1.2, 0.8),
			CFrame.new(dispPos + Vector3.new(0.9, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(70)),
			themeColor,
			Enum.Material.SmoothPlastic,
			true,
			false,
			dispenserModel
		)
		weaponTrim.CanTouch = false

		-- Billboard GUI
		local dispBillboard = Instance.new("BillboardGui")
		dispBillboard.Name = "DispenserBillboard"
		dispBillboard.Adornee = basePart
		dispBillboard.Size = UDim2.fromScale(6, 2.8)
		dispBillboard.StudsOffset = Vector3.new(0, 5.5, 0)
		dispBillboard.AlwaysOnTop = true
		dispBillboard.Parent = basePart

		local bbFrame = Instance.new("Frame")
		bbFrame.Size = UDim2.fromScale(1, 1)
		bbFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
		bbFrame.BackgroundTransparency = 0.2
		bbFrame.Parent = dispBillboard

		local bbCorner = Instance.new("UICorner")
		bbCorner.CornerRadius = UDim.new(0, 8)
		bbCorner.Parent = bbFrame

		local bbStroke = Instance.new("UIStroke")
		bbStroke.Color = themeColor
		bbStroke.Thickness = 2
		bbStroke.Parent = bbFrame

		local titleL = Instance.new("TextLabel")
		titleL.Name = "Title"
		titleL.Size = UDim2.fromScale(1, 0.5)
		titleL.Position = UDim2.fromScale(0, 0.05)
		titleL.BackgroundTransparency = 1
		titleL.Text = dispInfo.Title
		titleL.TextColor3 = themeColor
		titleL.TextScaled = true
		titleL.Font = Enum.Font.GothamBlack
		titleL.Parent = bbFrame

		local subL = Instance.new("TextLabel")
		subL.Name = "Subtitle"
		subL.Size = UDim2.fromScale(0.95, 0.4)
		subL.Position = UDim2.fromScale(0.025, 0.52)
		subL.BackgroundTransparency = 1
		subL.Text = dispInfo.Subtitle
		subL.TextColor3 = Color3.fromRGB(255, 220, 80)
		subL.TextScaled = true
		subL.Font = Enum.Font.GothamBold
		subL.Parent = bbFrame

		-- ProximityPrompt
		local dispenserPrompt = Instance.new("ProximityPrompt")
		dispenserPrompt.Name = "DispenserPrompt"
		dispenserPrompt.ObjectText = string.format("Armería Zona %d", i)
		dispenserPrompt.ActionText = string.format("Tomar %s", dispInfo.WeaponName)
		dispenserPrompt.HoldDuration = 0.2
		dispenserPrompt.MaxActivationDistance = 14
		dispenserPrompt.RequiresLineOfSight = false
		dispenserPrompt:SetAttribute("ZoneTier", i)
		dispenserPrompt:SetAttribute("WeaponId", dispInfo.WeaponId)
		dispenserPrompt:SetAttribute("WeaponName", dispInfo.WeaponName)
		dispenserPrompt.Parent = basePart

		-- 5.2 CyberShop Kiosk in Zone i (Tienda de Armas, Inmunidad y Potenciadores)
		local shopModel = Instance.new("Model")
		shopModel.Name = "CyberShop_Kiosk"
		shopModel:SetAttribute("ZoneTier", i)
		shopModel.Parent = zoneModel

		local shopPos = Vector3.new(cx + 24, 1, cz - 22)

		local kioskBase = CreatePart(
			"ShopBase",
			Vector3.new(8, 1.4, 4),
			CFrame.new(shopPos + Vector3.new(0, 0.7, 0)),
			Color3.fromRGB(22, 26, 36),
			Enum.Material.SmoothPlastic,
			true,
			true,
			shopModel
		)
		shopModel.PrimaryPart = kioskBase

		-- Counter Top
		CreatePart(
			"ShopCounter",
			Vector3.new(8.2, 0.4, 4.2),
			CFrame.new(shopPos + Vector3.new(0, 1.5, 0)),
			themeColor,
			Enum.Material.SmoothPlastic,
			true,
			true,
			shopModel
		)

		-- Back Wall / Shelves
		CreatePart(
			"ShopBackWall",
			Vector3.new(8, 6, 0.8),
			CFrame.new(shopPos + Vector3.new(0, 4.5, 1.6)),
			Color3.fromRGB(30, 35, 48),
			Enum.Material.SmoothPlastic,
			true,
			true,
			shopModel
		)

		-- Marquee Sign
		local marquee = CreatePart(
			"ShopMarquee",
			Vector3.new(8.4, 1.5, 1.2),
			CFrame.new(shopPos + Vector3.new(0, 7.5, 1.6)),
			Color3.fromRGB(255, 215, 0),
			Enum.Material.SmoothPlastic,
			true,
			false,
			shopModel
		)

		local marqueeLight = Instance.new("PointLight")
		marqueeLight.Brightness = 3.5
		marqueeLight.Range = 25
		marqueeLight.Color = Color3.fromRGB(255, 215, 0)
		marqueeLight.Parent = marquee

		-- Billboard GUI
		local shopBillboard = Instance.new("BillboardGui")
		shopBillboard.Name = "ShopBillboard"
		shopBillboard.Size = UDim2.fromOffset(280, 80)
		shopBillboard.StudsOffset = Vector3.new(0, 4.0, 0)
		shopBillboard.AlwaysOnTop = true
		shopBillboard.MaxDistance = 50
		shopBillboard.Adornee = kioskBase
		shopBillboard.Parent = kioskBase

		local sTitle = Instance.new("TextLabel")
		sTitle.Name = "Title"
		sTitle.Size = UDim2.fromScale(1, 0.55)
		sTitle.BackgroundTransparency = 1
		sTitle.Text = string.format("🛒 CYBER-SHOP (ZONA %d) 🛒", i)
		sTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
		sTitle.TextScaled = true
		sTitle.Font = Enum.Font.GothamBlack
		sTitle.Parent = shopBillboard

		local sSub = Instance.new("TextLabel")
		sSub.Name = "SubTitle"
		sSub.Size = UDim2.fromScale(1, 0.4)
		sSub.Position = UDim2.fromScale(0, 0.55)
		sSub.BackgroundTransparency = 1
		sSub.Text = string.format("ARMAS TIER %d • INMUNIDAD • BUFFS", i)
		sSub.TextColor3 = themeColor
		sSub.TextScaled = true
		sSub.Font = Enum.Font.GothamBold
		sSub.Parent = shopBillboard

		-- ProximityPrompt to Open Shop
		local shopPrompt = Instance.new("ProximityPrompt")
		shopPrompt.Name = "OpenShopPrompt"
		shopPrompt.ObjectText = string.format("Cyber-Shop Zona %d", i)
		shopPrompt.ActionText = "Abrir Tienda"
		shopPrompt.HoldDuration = 0
		shopPrompt.MaxActivationDistance = 14
		shopPrompt.RequiresLineOfSight = false
		shopPrompt.Parent = kioskBase

		-- 6. CapturePad Circular (Una sola plataforma circular frente a la máquina)
		local capturePadModel = Instance.new("Model")
		capturePadModel.Name = "CapturePad_" .. i
		capturePadModel:SetAttribute("MachineId", i)
		capturePadModel:SetAttribute("ZoneId", zoneDef.Id)
		capturePadModel.Parent = zoneModel

		-- Cylinder Base (Height 0.6, Diameter 14)
		local padBase = CreatePart(
			"PadBase",
			Vector3.new(0.6, 14, 14),
			CFrame.new(zoneDef.PadPosition) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(40, 45, 60),
			Enum.Material.SmoothPlastic,
			true,
			true,
			capturePadModel
		)
		padBase.Shape = Enum.PartType.Cylinder
		capturePadModel.PrimaryPart = padBase

		-- Ring Cylinder (Height 0.7, Diameter 12)
		local progressRing = CreatePart(
			"ProgressRing",
			Vector3.new(0.7, 12, 12),
			CFrame.new(zoneDef.PadPosition + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			themeColor,
			Enum.Material.SmoothPlastic,
			true,
			false,
			capturePadModel
		)
		progressRing.Shape = Enum.PartType.Cylinder
		progressRing:SetAttribute("Progress", 0.0)

		local padLight = Instance.new("PointLight")
		padLight.Name = "PadLight"
		padLight.Brightness = 3.0
		padLight.Range = 28
		padLight.Color = themeColor
		padLight.Parent = progressRing

		-- Floating BillboardGui
		local padBillboard = Instance.new("BillboardGui")
		padBillboard.Name = "CaptureBillboard"
		padBillboard.Size = UDim2.fromOffset(260, 70)
		padBillboard.StudsOffset = Vector3.new(0, 5, 0)
		padBillboard.AlwaysOnTop = true
		padBillboard.MaxDistance = 60
		padBillboard.Adornee = padBase
		padBillboard.Parent = padBase

		local billboardTitle = Instance.new("TextLabel")
		billboardTitle.Name = "TitleLabel"
		billboardTitle.Size = UDim2.fromScale(1, 0.48)
		billboardTitle.Position = UDim2.fromScale(0, 0)
		billboardTitle.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
		billboardTitle.BackgroundTransparency = 0.2
		billboardTitle.TextColor3 = Color3.fromRGB(255, 220, 50)
		billboardTitle.Text = "ZONA DE CAPTURA - MANTENTE 3s SIN DAÑO"
		billboardTitle.TextScaled = true
		billboardTitle.Font = Enum.Font.GothamBold
		billboardTitle.Parent = padBillboard

		local billboardProgress = Instance.new("TextLabel")
		billboardProgress.Name = "ProgressLabel"
		billboardProgress.Size = UDim2.fromScale(1, 0.48)
		billboardProgress.Position = UDim2.fromScale(0, 0.52)
		billboardProgress.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
		billboardProgress.BackgroundTransparency = 0.2
		billboardProgress.TextColor3 = Color3.fromRGB(50, 255, 180)
		billboardProgress.Text = "Progreso: 0.0s / 3.0s"
		billboardProgress.TextScaled = true
		billboardProgress.Font = Enum.Font.GothamBold
		billboardProgress.Parent = padBillboard

		local capturePrompt = Instance.new("ProximityPrompt")
		capturePrompt.Name = "CapturePrompt"
		capturePrompt.ObjectText = "Máquina " .. i
		capturePrompt.ActionText = "Acceder a Cabina"
		capturePrompt.HoldDuration = 0.5
		capturePrompt.MaxActivationDistance = 15
		capturePrompt.RequiresLineOfSight = false
		capturePrompt.Parent = padBase

		-- 7. Cabina Arcade de Alta Tecnología (Mínimo 15 piezas por máquina)
		local machineModel = Instance.new("Model")
		machineModel.Name = "Machine_" .. i
		machineModel:SetAttribute("MachineId", i)
		machineModel:SetAttribute("ZoneId", zoneDef.Id)
		machineModel.Parent = zoneModel

		local mPos = zoneDef.MachinePosition

		-- 1. Stepped Lower Base
		local machineBase = CreatePart(
			"MachineBase",
			Vector3.new(16, 1.2, 16),
			CFrame.new(mPos + Vector3.new(0, 0.6, 0)),
			Color3.fromRGB(18, 20, 28),
			Enum.Material.SmoothPlastic,
			true,
			true,
			machineModel
		)
		machineModel.PrimaryPart = machineBase

		-- 2. Stepped Upper Base
		CreatePart(
			"BaseStepUpper",
			Vector3.new(14, 0.8, 14),
			CFrame.new(mPos + Vector3.new(0, 1.6, 0)),
			Color3.fromRGB(28, 30, 40),
			Enum.Material.SmoothPlastic,
			true,
			true,
			machineModel
		)

		-- 3. Trim on Base
		CreatePart(
			"BaseNeonTrim",
			Vector3.new(14.2, 0.3, 14.2),
			CFrame.new(mPos + Vector3.new(0, 2.1, 0)),
			themeColor,
			Enum.Material.SmoothPlastic,
			true,
			false,
			machineModel
		)

		-- 4, 5, 6, 7. Four Corner Metallic Columns
		local colH = 14
		local colY = 2 + colH / 2
		CreatePart("Pillar_FL", Vector3.new(1.4, colH, 1.4), CFrame.new(mPos + Vector3.new(-6.2, colY, -6.2)), Color3.fromRGB(45, 48, 60), Enum.Material.SmoothPlastic, true, true, machineModel)
		CreatePart("Pillar_FR", Vector3.new(1.4, colH, 1.4), CFrame.new(mPos + Vector3.new(6.2, colY, -6.2)), Color3.fromRGB(45, 48, 60), Enum.Material.SmoothPlastic, true, true, machineModel)
		CreatePart("Pillar_BL", Vector3.new(1.4, colH, 1.4), CFrame.new(mPos + Vector3.new(-6.2, colY, 6.2)), Color3.fromRGB(45, 48, 60), Enum.Material.SmoothPlastic, true, true, machineModel)
		CreatePart("Pillar_BR", Vector3.new(1.4, colH, 1.4), CFrame.new(mPos + Vector3.new(6.2, colY, 6.2)), Color3.fromRGB(45, 48, 60), Enum.Material.SmoothPlastic, true, true, machineModel)

		-- 8. Armored Glass Left (Named ArmoredGlass for backward-compat)
		local glassLeft = CreatePart(
			"ArmoredGlass",
			Vector3.new(0.4, 12, 11),
			CFrame.new(mPos + Vector3.new(-6.2, 8.2, 0)),
			Color3.fromRGB(180, 230, 255),
			Enum.Material.Glass,
			true,
			true,
			machineModel
		)
		glassLeft.Transparency = 0.65

		-- 9. Armored Glass Right
		local glassRight = CreatePart(
			"ArmoredGlassRight",
			Vector3.new(0.4, 12, 11),
			CFrame.new(mPos + Vector3.new(6.2, 8.2, 0)),
			Color3.fromRGB(180, 230, 255),
			Enum.Material.Glass,
			true,
			true,
			machineModel
		)
		glassRight.Transparency = 0.65

		-- 10. Armored Glass Back
		local glassBack = CreatePart(
			"ArmoredGlassBack",
			Vector3.new(11, 12, 0.4),
			CFrame.new(mPos + Vector3.new(0, 8.2, 6.2)),
			Color3.fromRGB(180, 230, 255),
			Enum.Material.Glass,
			true,
			true,
			machineModel
		)
		glassBack.Transparency = 0.65

		-- 11. Sliding Front Door (Real sliding door geometry)
		local slidingDoor = CreatePart(
			"SlidingDoor",
			Vector3.new(9, 12, 0.4),
			CFrame.new(mPos + Vector3.new(0, 8.2, -6.2)),
			Color3.fromRGB(200, 240, 255),
			Enum.Material.Glass,
			true,
			true,
			machineModel
		)
		slidingDoor.Transparency = 0.5

		-- 12. Ceiling Cap / Top Cover
		CreatePart(
			"CeilingCap",
			Vector3.new(14.5, 1.2, 14.5),
			CFrame.new(mPos + Vector3.new(0, 16.6, 0)),
			Color3.fromRGB(24, 26, 35),
			Enum.Material.SmoothPlastic,
			true,
			true,
			machineModel
		)

		-- 13. Interior Console Desk
		CreatePart(
			"ConsoleDesk",
			Vector3.new(6, 3, 3.5),
			CFrame.new(mPos + Vector3.new(0, 3.5, 2)),
			Color3.fromRGB(30, 34, 45),
			Enum.Material.SmoothPlastic,
			true,
			true,
			machineModel
		)

		-- 14. Interior Screen
		CreatePart(
			"Screen",
			Vector3.new(5, 3.2, 0.4),
			CFrame.new(mPos + Vector3.new(0, 6.2, 3.2)),
			Color3.fromRGB(0, 200, 230),
			Enum.Material.SmoothPlastic,
			true,
			false,
			machineModel
		)

		-- 15. Interior Joystick
		CreatePart(
			"Joystick",
			Vector3.new(0.4, 1.2, 0.4),
			CFrame.new(mPos + Vector3.new(-1.2, 5.4, 1.8)),
			Color3.fromRGB(255, 40, 40),
			Enum.Material.SmoothPlastic,
			true,
			false,
			machineModel
		)

		-- 16. Interior Arcade Buttons
		CreatePart(
			"ArcadeButtons",
			Vector3.new(2, 0.3, 1),
			CFrame.new(mPos + Vector3.new(1.2, 5.1, 1.8)),
			Color3.fromRGB(255, 215, 0),
			Enum.Material.SmoothPlastic,
			true,
			false,
			machineModel
		)

		-- 17. Big Marquee Status Sign on Front
		local signPart = CreatePart(
			"StatusSign",
			Vector3.new(12, 4, 0.8),
			CFrame.new(mPos + Vector3.new(0, 16.5, -6.5)),
			Color3.fromRGB(12, 14, 20),
			Enum.Material.SmoothPlastic,
			true,
			true,
			machineModel
		)

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "SignGui"
		surfaceGui.Face = Enum.NormalId.Front
		surfaceGui.Adornee = signPart
		surfaceGui.Parent = signPart

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "TitleLabel"
		titleLabel.Size = UDim2.fromScale(1, 0.32)
		titleLabel.Position = UDim2.fromScale(0, 0)
		titleLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
		titleLabel.TextColor3 = themeColor
		titleLabel.TextScaled = true
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.Text = MINIGAME_TITLES[i] or ("MÁQUINA " .. i)
		titleLabel.Parent = surfaceGui

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "StatusLabel"
		statusLabel.Size = UDim2.fromScale(1, 0.38)
		statusLabel.Position = UDim2.fromScale(0, 0.32)
		statusLabel.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
		statusLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
		statusLabel.TextScaled = true
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.Text = "DISPONIBLE"
		statusLabel.Parent = surfaceGui

		local starsLabel = Instance.new("TextLabel")
		starsLabel.Name = "DifficultyStars"
		starsLabel.Size = UDim2.fromScale(1, 0.30)
		starsLabel.Position = UDim2.fromScale(0, 0.70)
		starsLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
		starsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		starsLabel.TextScaled = true
		starsLabel.Font = Enum.Font.GothamBold
		starsLabel.Text = "DIFICULTAD: [ ★ ★ ★ ★ ★ ] (Niveles 1 a 5)"
		starsLabel.Parent = surfaceGui

		-- 18. Roof Marquee Crown
		CreatePart("RoofMarqueeNeon", Vector3.new(14.8, 0.4, 14.8), CFrame.new(mPos + Vector3.new(0, 17.3, 0)), themeColor, Enum.Material.SmoothPlastic, true, false, machineModel)

		-- 19. Bezel around the Screen
		CreatePart("ConsoleBezel", Vector3.new(5.6, 3.8, 0.3), CFrame.new(mPos + Vector3.new(0, 6.2, 3.0)), Color3.fromRGB(15, 16, 22), Enum.Material.SmoothPlastic, true, true, machineModel)

		-- 20. Red Joystick Ball Top
		local jBall = CreatePart("JoystickBall", Vector3.new(0.8, 0.8, 0.8), CFrame.new(mPos + Vector3.new(-1.2, 6.1, 1.8)), Color3.fromRGB(255, 30, 30), Enum.Material.SmoothPlastic, true, false, machineModel)
		jBall.Shape = Enum.PartType.Ball

		-- 21. Secondary Arcade Buttons Panel (Cyan)
		CreatePart("ArcadeButtons2", Vector3.new(2, 0.3, 1), CFrame.new(mPos + Vector3.new(1.2, 5.1, 2.5)), Color3.fromRGB(0, 200, 230), Enum.Material.SmoothPlastic, true, false, machineModel)

		-- 22. Coin Acceptor Door
		CreatePart("CoinSlot", Vector3.new(2.4, 2, 0.3), CFrame.new(mPos + Vector3.new(0, 2.5, 0.2)), Color3.fromRGB(20, 22, 28), Enum.Material.SmoothPlastic, true, true, machineModel)

		-- 23. Glowing Coin Insert Light
		CreatePart("CoinSlotLight", Vector3.new(1.2, 0.2, 0.35), CFrame.new(mPos + Vector3.new(0, 2.8, 0.22)), Color3.fromRGB(255, 140, 0), Enum.Material.SmoothPlastic, true, false, machineModel)

		-- 24. Speaker Grill Left
		CreatePart("SpeakerLeft", Vector3.new(2, 1, 0.3), CFrame.new(mPos + Vector3.new(-4, 14.5, 6.0)), Color3.fromRGB(25, 28, 38), Enum.Material.SmoothPlastic, true, true, machineModel)

		-- 25. Speaker Grill Right
		CreatePart("SpeakerRight", Vector3.new(2, 1, 0.3), CFrame.new(mPos + Vector3.new(4, 14.5, 6.0)), Color3.fromRGB(25, 28, 38), Enum.Material.SmoothPlastic, true, true, machineModel)

		-- 26. Cabinet Side Accent Left
		CreatePart("CabinetSideArtLeft", Vector3.new(0.3, 10, 2), CFrame.new(mPos + Vector3.new(-6.4, 8.5, 0)), themeColor, Enum.Material.SmoothPlastic, true, false, machineModel)

		-- 27. Cabinet Side Accent Right
		CreatePart("CabinetSideArtRight", Vector3.new(0.3, 10, 2), CFrame.new(mPos + Vector3.new(6.4, 8.5, 0)), themeColor, Enum.Material.SmoothPlastic, true, false, machineModel)

		-- 28. Tubular Metal Footrest Bar
		local footrest = CreatePart("FootRest", Vector3.new(8, 0.6, 0.6), CFrame.new(mPos + Vector3.new(0, 1.2, -4.5)), Color3.fromRGB(160, 165, 180), Enum.Material.SmoothPlastic, true, true, machineModel)
		footrest.Shape = Enum.PartType.Cylinder

		-- 7.1 Training Dummies for combat practice
		if i == 1 then
			WorldBuilder.CreateTrainingDummy("Dummy de Pruebas A", CFrame.new(cx - 16, 2.5, cz + 10), zoneModel)
			WorldBuilder.CreateTrainingDummy("Dummy de Pruebas B", CFrame.new(cx + 16, 2.5, cz + 10), zoneModel)
		elseif i == 2 then
			WorldBuilder.CreateTrainingDummy("Dummy de Pruebas 2", CFrame.new(cx - 16, 2.5, cz + 10), zoneModel)
		end

		-- 8. Dedicated Physical Minigame Chamber (Underground Y < -150)
		local chamberModel = Instance.new("Model")
		chamberModel.Name = "MinigameChamber_" .. i
		chamberModel:SetAttribute("MachineId", i)
		chamberModel:SetAttribute("ZoneId", zoneDef.Id)
		chamberModel.Parent = zoneModel

		local chPos = zoneDef.ChamberPosition

		if i == 1 then
			-- Chamber 1: Reflex QTE (Spacious 80x80 room with giant reactive screens and bright lighting)
			local chFloor = CreatePart("ChamberFloor", Vector3.new(80, 2, 80), CFrame.new(chPos), Color3.fromRGB(15, 18, 26), Enum.Material.SmoothPlastic, true, true, chamberModel)
			chamberModel.PrimaryPart = chFloor
			local chCeil = CreatePart("ChamberCeiling", Vector3.new(80, 2, 80), CFrame.new(chPos + Vector3.new(0, 24, 0)), Color3.fromRGB(24, 26, 35), Enum.Material.SmoothPlastic, true, true, chamberModel)
			
			-- High-Intensity Chamber Ceiling Floodlight
			local cLight = Instance.new("PointLight")
			cLight.Name = "ChamberFloodlight"
			cLight.Brightness = 3.2
			cLight.Range = 80
			cLight.Color = Color3.fromRGB(220, 245, 255)
			cLight.Shadows = true
			cLight.Parent = chCeil

			-- 4 Outer Walls
			CreatePart("WallN", Vector3.new(80, 24, 2), CFrame.new(chPos + Vector3.new(0, 12, 40)), Color3.fromRGB(20, 22, 30), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallS", Vector3.new(80, 24, 2), CFrame.new(chPos + Vector3.new(0, 12, -40)), Color3.fromRGB(20, 22, 30), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallE", Vector3.new(2, 24, 80), CFrame.new(chPos + Vector3.new(40, 12, 0)), Color3.fromRGB(20, 22, 30), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallW", Vector3.new(2, 24, 80), CFrame.new(chPos + Vector3.new(-40, 12, 0)), Color3.fromRGB(20, 22, 30), Enum.Material.SmoothPlastic, true, true, chamberModel)
			
			-- 4 Giant Reactive Screens
			CreatePart("ScreenN", Vector3.new(64, 16, 0.5), CFrame.new(chPos + Vector3.new(0, 12, 38.5)), Color3.fromRGB(0, 160, 230), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("ScreenS", Vector3.new(64, 16, 0.5), CFrame.new(chPos + Vector3.new(0, 12, -38.5)), Color3.fromRGB(0, 160, 230), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("ScreenE", Vector3.new(0.5, 16, 64), CFrame.new(chPos + Vector3.new(38.5, 12, 0)), Color3.fromRGB(0, 160, 230), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("ScreenW", Vector3.new(0.5, 16, 64), CFrame.new(chPos + Vector3.new(-38.5, 12, 0)), Color3.fromRGB(0, 160, 230), Enum.Material.SmoothPlastic, true, true, chamberModel)
			
			-- Center Pedestal & Spawn (Spacious 28x28 platform so player never falls)
			CreatePart("Pedestal", Vector3.new(28, 1.2, 28), CFrame.new(chPos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(35, 40, 52), Enum.Material.SmoothPlastic, true, true, chamberModel)
			local spawnP = CreatePart("ChamberSpawn", Vector3.new(10, 0.2, 10), CFrame.new(chPos + Vector3.new(0, 2.2, 0)), themeColor, Enum.Material.SmoothPlastic, true, false, chamberModel)
			spawnP.CanTouch = false

			local pedLight = Instance.new("PointLight")
			pedLight.Brightness = 2.5
			pedLight.Range = 25
			pedLight.Color = themeColor
			pedLight.Parent = spawnP

			-- 4 Corner Structural Beams
			CreatePart("NeonBeam_1", Vector3.new(2.5, 24, 2.5), CFrame.new(chPos + Vector3.new(38, 12, 38)), themeColor, Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("NeonBeam_2", Vector3.new(2.5, 24, 2.5), CFrame.new(chPos + Vector3.new(-38, 12, 38)), themeColor, Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("NeonBeam_3", Vector3.new(2.5, 24, 2.5), CFrame.new(chPos + Vector3.new(38, 12, -38)), themeColor, Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("NeonBeam_4", Vector3.new(2.5, 24, 2.5), CFrame.new(chPos + Vector3.new(-38, 12, -38)), themeColor, Enum.Material.SmoothPlastic, true, true, chamberModel)

		elseif i == 2 then
			-- Chamber 2: Extended Obstacle Parkour (240 studs long, 10 dynamic platforms, hazard pit, V_goal)
			local pitFloor = CreatePart("HazardPit", Vector3.new(38, 2, 240), CFrame.new(chPos + Vector3.new(0, -12, 0)), Color3.fromRGB(120, 25, 25), Enum.Material.SmoothPlastic, true, true, chamberModel)
			chamberModel.PrimaryPart = pitFloor
			local chCeil = CreatePart("ChamberCeiling", Vector3.new(38, 2, 240), CFrame.new(chPos + Vector3.new(0, 24, 0)), Color3.fromRGB(24, 26, 35), Enum.Material.SmoothPlastic, true, true, chamberModel)
			
			local cLight = Instance.new("PointLight")
			cLight.Name = "ChamberFloodlight"
			cLight.Brightness = 3.5
			cLight.Range = 100
			cLight.Color = Color3.fromRGB(220, 245, 255)
			cLight.Parent = chCeil

			CreatePart("WallE", Vector3.new(2, 38, 240), CFrame.new(chPos + Vector3.new(19, 6, 0)), Color3.fromRGB(22, 24, 32), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallW", Vector3.new(2, 38, 240), CFrame.new(chPos + Vector3.new(-19, 6, 0)), Color3.fromRGB(22, 24, 32), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallN", Vector3.new(38, 38, 2), CFrame.new(chPos + Vector3.new(0, 6, 120)), Color3.fromRGB(22, 24, 32), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallS", Vector3.new(38, 38, 2), CFrame.new(chPos + Vector3.new(0, 6, -120)), Color3.fromRGB(22, 24, 32), Enum.Material.SmoothPlastic, true, true, chamberModel)

			-- Start Platform
			CreatePart("StartPlatform", Vector3.new(24, 2, 16), CFrame.new(chPos + Vector3.new(0, 0, -105)), Color3.fromRGB(35, 40, 50), Enum.Material.SmoothPlastic, true, true, chamberModel)
			local spawnP = CreatePart("ChamberSpawn", Vector3.new(6, 0.2, 6), CFrame.new(chPos + Vector3.new(0, 1.1, -105)), themeColor, Enum.Material.SmoothPlastic, true, false, chamberModel)
			spawnP.CanTouch = false

			-- 10 Intermittent Obstacle Platforms
			CreatePart("Platform_1", Vector3.new(16, 1.5, 9), CFrame.new(chPos + Vector3.new(0, 0, -88)), Color3.fromRGB(40, 45, 60), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("Platform_2", Vector3.new(12, 1.5, 8), CFrame.new(chPos + Vector3.new(-5, 0.5, -70)), Color3.fromRGB(40, 45, 60), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("Platform_3", Vector3.new(12, 1.5, 8), CFrame.new(chPos + Vector3.new(5, 1.2, -52)), Color3.fromRGB(40, 45, 60), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("Platform_4", Vector3.new(14, 1.5, 8), CFrame.new(chPos + Vector3.new(0, 2.0, -34)), Color3.fromRGB(40, 45, 60), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("Platform_5", Vector3.new(10, 1.5, 7), CFrame.new(chPos + Vector3.new(-6, 2.8, -16)), Color3.fromRGB(40, 45, 60), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("Platform_6", Vector3.new(10, 1.5, 7), CFrame.new(chPos + Vector3.new(6, 3.5, 2)), Color3.fromRGB(40, 45, 60), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("Platform_7", Vector3.new(14, 1.5, 8), CFrame.new(chPos + Vector3.new(0, 4.2, 20)), Color3.fromRGB(40, 45, 60), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("Platform_8", Vector3.new(11, 1.5, 7), CFrame.new(chPos + Vector3.new(-5, 4.8, 38)), Color3.fromRGB(40, 45, 60), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("Platform_9", Vector3.new(11, 1.5, 7), CFrame.new(chPos + Vector3.new(5, 5.2, 56)), Color3.fromRGB(40, 45, 60), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("Platform_10", Vector3.new(15, 1.5, 9), CFrame.new(chPos + Vector3.new(0, 4.0, 74)), Color3.fromRGB(40, 45, 60), Enum.Material.SmoothPlastic, true, true, chamberModel)

			-- Goal Pad (V_goal)
			local vGoal = CreatePart("V_goal", Vector3.new(22, 2, 16), CFrame.new(chPos + Vector3.new(0, 3, 105)), Color3.fromRGB(40, 200, 100), Enum.Material.SmoothPlastic, true, true, chamberModel)
			vGoal:SetAttribute("IsGoal", true)

		elseif i == 3 then
			-- Chamber 3: Target Practice (Spacious 65x80 range, counter, background rails, 3D targets)
			local chFloor = CreatePart("ChamberFloor", Vector3.new(65, 2, 80), CFrame.new(chPos), Color3.fromRGB(18, 20, 28), Enum.Material.SmoothPlastic, true, true, chamberModel)
			chamberModel.PrimaryPart = chFloor
			local chCeil = CreatePart("ChamberCeiling", Vector3.new(65, 2, 80), CFrame.new(chPos + Vector3.new(0, 22, 0)), Color3.fromRGB(24, 26, 35), Enum.Material.SmoothPlastic, true, true, chamberModel)
			
			local cLight = Instance.new("PointLight")
			cLight.Name = "ChamberFloodlight"
			cLight.Brightness = 3.0
			cLight.Range = 75
			cLight.Color = Color3.fromRGB(220, 245, 255)
			cLight.Parent = chCeil

			CreatePart("WallN", Vector3.new(65, 22, 2), CFrame.new(chPos + Vector3.new(0, 11, 40)), Color3.fromRGB(24, 26, 34), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallS", Vector3.new(65, 22, 2), CFrame.new(chPos + Vector3.new(0, 11, -40)), Color3.fromRGB(24, 26, 34), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallE", Vector3.new(2, 22, 80), CFrame.new(chPos + Vector3.new(32.5, 11, 0)), Color3.fromRGB(24, 26, 34), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallW", Vector3.new(2, 22, 80), CFrame.new(chPos + Vector3.new(-32.5, 11, 0)), Color3.fromRGB(24, 26, 34), Enum.Material.SmoothPlastic, true, true, chamberModel)
			-- Player Counter Barrier
			CreatePart("ShootingCounter", Vector3.new(50, 3.5, 2), CFrame.new(chPos + Vector3.new(0, 2.75, -20)), Color3.fromRGB(35, 40, 52), Enum.Material.SmoothPlastic, true, true, chamberModel)
			local spawnP = CreatePart("ChamberSpawn", Vector3.new(6, 0.2, 6), CFrame.new(chPos + Vector3.new(0, 1.1, -30)), themeColor, Enum.Material.SmoothPlastic, true, false, chamberModel)
			spawnP.CanTouch = false
			-- Background Target Rails
			CreatePart("TargetRail_Top", Vector3.new(50, 0.8, 0.8), CFrame.new(chPos + Vector3.new(0, 13, 36)), Color3.fromRGB(45, 50, 65), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("TargetRail_Bottom", Vector3.new(50, 0.8, 0.8), CFrame.new(chPos + Vector3.new(0, 8, 36)), Color3.fromRGB(45, 50, 65), Enum.Material.SmoothPlastic, true, true, chamberModel)
			-- 3D Active Targets (T_active)
			CreatePart("T_active_1", Vector3.new(3.5, 3.5, 0.6), CFrame.new(chPos + Vector3.new(-16, 13, 35.5)), Color3.fromRGB(0, 220, 100), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("T_active_2", Vector3.new(3.5, 3.5, 0.6), CFrame.new(chPos + Vector3.new(0, 13, 35.5)), Color3.fromRGB(0, 220, 100), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("T_active_3", Vector3.new(3.5, 3.5, 0.6), CFrame.new(chPos + Vector3.new(16, 13, 35.5)), Color3.fromRGB(0, 220, 100), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("T_active_4", Vector3.new(3.5, 3.5, 0.6), CFrame.new(chPos + Vector3.new(-8, 8, 35.5)), Color3.fromRGB(0, 220, 100), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("T_active_5", Vector3.new(3.5, 3.5, 0.6), CFrame.new(chPos + Vector3.new(8, 8, 35.5)), Color3.fromRGB(0, 220, 100), Enum.Material.SmoothPlastic, true, true, chamberModel)
			-- 3D Penalty Targets (T_penalty)
			CreatePart("T_penalty_1", Vector3.new(3, 3, 0.6), CFrame.new(chPos + Vector3.new(-22, 8, 35.5)), Color3.fromRGB(240, 40, 40), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("T_penalty_2", Vector3.new(3, 3, 0.6), CFrame.new(chPos + Vector3.new(22, 8, 35.5)), Color3.fromRGB(240, 40, 40), Enum.Material.SmoothPlastic, true, true, chamberModel)

		elseif i == 4 then
			-- Chamber 4: Memory Matrix (Spacious 80x80 room, physical 4x4 interactive grid of platforms)
			local chFloor = CreatePart("ChamberFloor", Vector3.new(80, 2, 80), CFrame.new(chPos), Color3.fromRGB(15, 16, 24), Enum.Material.SmoothPlastic, true, true, chamberModel)
			chamberModel.PrimaryPart = chFloor
			local chCeil = CreatePart("ChamberCeiling", Vector3.new(80, 2, 80), CFrame.new(chPos + Vector3.new(0, 22, 0)), Color3.fromRGB(24, 26, 35), Enum.Material.SmoothPlastic, true, true, chamberModel)
			
			local cLight = Instance.new("PointLight")
			cLight.Name = "ChamberFloodlight"
			cLight.Brightness = 3.0
			cLight.Range = 75
			cLight.Color = Color3.fromRGB(220, 245, 255)
			cLight.Parent = chCeil

			CreatePart("WallN", Vector3.new(80, 22, 2), CFrame.new(chPos + Vector3.new(0, 11, 40)), Color3.fromRGB(22, 24, 32), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallS", Vector3.new(80, 22, 2), CFrame.new(chPos + Vector3.new(0, 11, -40)), Color3.fromRGB(22, 24, 32), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallE", Vector3.new(2, 22, 80), CFrame.new(chPos + Vector3.new(40, 11, 0)), Color3.fromRGB(22, 24, 32), Enum.Material.SmoothPlastic, true, true, chamberModel)
			CreatePart("WallW", Vector3.new(2, 22, 80), CFrame.new(chPos + Vector3.new(-40, 11, 0)), Color3.fromRGB(22, 24, 32), Enum.Material.SmoothPlastic, true, true, chamberModel)
			-- Observation / Start Pad
			CreatePart("ObservationPad", Vector3.new(45, 1.2, 12), CFrame.new(chPos + Vector3.new(0, 1, -28)), Color3.fromRGB(35, 40, 52), Enum.Material.SmoothPlastic, true, true, chamberModel)
			local spawnP = CreatePart("ChamberSpawn", Vector3.new(6, 0.2, 6), CFrame.new(chPos + Vector3.new(0, 1.6, -28)), themeColor, Enum.Material.SmoothPlastic, true, false, chamberModel)
			spawnP.CanTouch = false
			-- 4x4 Grid of 16 Physical Platforms (7x7 studs each, separated by channels)
			local gridFolder = Instance.new("Folder")
			gridFolder.Name = "MatrixGrid"
			gridFolder.Parent = chamberModel
			for r = 1, 4 do
				for c = 1, 4 do
					local tileX = (c - 2.5) * 10.5
					local tileZ = (r - 2.5) * 10.5 + 4
					local tileBase = CreatePart(string.format("Tile_%d_%d", r, c), Vector3.new(8, 1.2, 8), CFrame.new(chPos + Vector3.new(tileX, 1.2, tileZ)), Color3.fromRGB(28, 32, 44), Enum.Material.SmoothPlastic, true, true, gridFolder)
					tileBase:SetAttribute("Row", r)
					tileBase:SetAttribute("Col", c)
					local tileTop = CreatePart("TileTop", Vector3.new(7.6, 0.3, 7.6), CFrame.new(chPos + Vector3.new(tileX, 1.95, tileZ)), Color3.fromRGB(0, 100, 180), Enum.Material.SmoothPlastic, true, false, tileBase)
					tileTop.CanTouch = false
				end
			end

		elseif i == 5 then
			-- Chamber 5: Bullet Hell (Spacious 78 studs diameter circular closed coliseum with bouncing projectiles B(t))
			-- Circular Floor
			local chFloor = CreatePart("ChamberFloor", Vector3.new(2, 78, 78), CFrame.new(chPos) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(20, 18, 28), Enum.Material.SmoothPlastic, true, true, chamberModel)
			chFloor.Shape = Enum.PartType.Cylinder
			chamberModel.PrimaryPart = chFloor
			-- Circular Energy Perimeter (16-sided polygon)
			local barrierRadius = 39
			local wallHeightChamber = 24
			for seg = 1, 16 do
				local angle = (seg / 16) * math.pi * 2
				local segX = math.cos(angle) * barrierRadius
				local segZ = math.sin(angle) * barrierRadius
				local segRot = CFrame.new(chPos + Vector3.new(segX, 12, segZ), chPos + Vector3.new(0, 12, 0))
				CreatePart(string.format("EnergyBarrier_%d", seg), Vector3.new(15.5, wallHeightChamber, 1.5), segRot, themeColor, Enum.Material.ForceField, true, true, chamberModel).Transparency = 0.4
			end
			-- Circular Ceiling
			local chCeil = CreatePart("ChamberCeiling", Vector3.new(2, 78, 78), CFrame.new(chPos + Vector3.new(0, 24, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(24, 26, 35), Enum.Material.SmoothPlastic, true, true, chamberModel)
			chCeil.Shape = Enum.PartType.Cylinder
			
			local cLight = Instance.new("PointLight")
			cLight.Name = "ChamberFloodlight"
			cLight.Brightness = 4.0
			cLight.Range = 80
			cLight.Color = Color3.fromRGB(220, 245, 255)
			cLight.Parent = chCeil

			-- Spawn at Center
			local spawnP = CreatePart("ChamberSpawn", Vector3.new(8, 0.2, 8), CFrame.new(chPos + Vector3.new(0, 1.1, 0)), themeColor, Enum.Material.SmoothPlastic, true, false, chamberModel)
			spawnP.CanTouch = false
			-- Projectile Hazards B(t)
			local bFolder = Instance.new("Folder")
			bFolder.Name = "Projectiles_B"
			bFolder.Parent = chamberModel
			local orb1 = CreatePart("B_Orb_1", Vector3.new(3.5, 3.5, 3.5), CFrame.new(chPos + Vector3.new(-15, 4, -15)), Color3.fromRGB(255, 40, 70), Enum.Material.SmoothPlastic, true, true, bFolder)
			orb1.Shape = Enum.PartType.Ball
			local orb2 = CreatePart("B_Orb_2", Vector3.new(3.5, 3.5, 3.5), CFrame.new(chPos + Vector3.new(15, 4, 15)), Color3.fromRGB(255, 40, 70), Enum.Material.SmoothPlastic, true, true, bFolder)
			orb2.Shape = Enum.PartType.Ball
			local orb3 = CreatePart("B_Orb_3", Vector3.new(3.5, 3.5, 3.5), CFrame.new(chPos + Vector3.new(-18, 4, 18)), Color3.fromRGB(255, 40, 70), Enum.Material.SmoothPlastic, true, true, bFolder)
			orb3.Shape = Enum.PartType.Ball
			CreatePart("B_Blade_1", Vector3.new(6, 0.4, 6), CFrame.new(chPos + Vector3.new(16, 3, -12)), Color3.fromRGB(255, 200, 0), Enum.Material.SmoothPlastic, true, true, bFolder)
			CreatePart("B_Blade_2", Vector3.new(6, 0.4, 6), CFrame.new(chPos + Vector3.new(0, 3, 20)), Color3.fromRGB(255, 200, 0), Enum.Material.SmoothPlastic, true, true, bFolder)
		end
	end

	-- Build 4 Corridors and Gates connecting zones
	-- Zone 1: [-60, 60] (Center = 0, Size = 120)
	-- Zone 2: [110, 230] (Center = 170, Size = 120)
	-- Zone 3: [280, 400] (Center = 340, Size = 120)
	-- Zone 4: [450, 570] (Center = 510, Size = 120)
	-- Zone 5: [620, 780] (Center = 700, Size = 160)
	local corridorIntervals = {
		{ StartX = 60, EndX = 110, GateX = 85 },
		{ StartX = 230, EndX = 280, GateX = 255 },
		{ StartX = 400, EndX = 450, GateX = 425 },
		{ StartX = 570, EndX = 620, GateX = 595 },
	}

	for g = 1, 4 do
		local info = corridorIntervals[g]
		local length = info.EndX - info.StartX
		local midX = (info.StartX + info.EndX) / 2
		local wallCenterY = 1 + wallHeight / 2

		local corridorModel = Instance.new("Model")
		corridorModel.Name = string.format("Corridor_%d_%d", g, g + 1)
		corridorModel.Parent = corridorsFolder

		-- Corridor Floor
		CreatePart(
			"Floor",
			Vector3.new(length, 2, corridorWidth),
			CFrame.new(midX, 0, 0),
			Color3.fromRGB(20, 22, 28),
			Enum.Material.SmoothPlastic,
			true,
			true,
			corridorModel
		)

		-- Corridor North Wall
		CreatePart(
			"WallNorth",
			Vector3.new(length, wallHeight, wallThickness),
			CFrame.new(midX, wallCenterY, halfCorridor + wallThickness / 2),
			Color3.fromRGB(24, 26, 34),
			Enum.Material.SmoothPlastic,
			true,
			true,
			corridorModel
		)

		-- Corridor South Wall
		CreatePart(
			"WallSouth",
			Vector3.new(length, wallHeight, wallThickness),
			CFrame.new(midX, wallCenterY, -halfCorridor - wallThickness / 2),
			Color3.fromRGB(24, 26, 34),
			Enum.Material.SmoothPlastic,
			true,
			true,
			corridorModel
		)

		-- Corridor Roof
		local cRoof = CreatePart(
			"CorridorRoof",
			Vector3.new(length, 2, corridorWidth + wallThickness * 2),
			CFrame.new(midX, 1 + wallHeight + 1, 0),
			Color3.fromRGB(16, 18, 26),
			Enum.Material.SmoothPlastic,
			true,
			true,
			corridorModel
		)
		cRoof.CastShadow = false

		-- Corridor High-Power Illumination
		local cLight = Instance.new("PointLight")
		cLight.Name = "CorridorFloodlight"
		cLight.Brightness = 3.5
		cLight.Range = 45
		cLight.Color = Color3.fromRGB(240, 245, 255)
		cLight.Parent = cRoof

		-- Corridor Gate Model
		local gateModel = Instance.new("Model")
		local gateName = string.format("Gate_%d_%d", g, g + 1)
		gateModel.Name = gateName
		gateModel:SetAttribute("GateIndex", g)
		gateModel:SetAttribute("GateId", gateName)
		gateModel.Parent = gatesFolder

		-- The Gate barrier covers the ENTIRE corridor cross-section wall-to-wall and floor-to-ceiling
		local barrier = CreatePart(
			"Barrier",
			Vector3.new(4, wallHeight, corridorWidth),
			CFrame.new(info.GateX, wallCenterY, 0),
			Color3.fromRGB(255, 60 + g * 40, 40),
			Enum.Material.ForceField,
			true,
			true,
			gateModel
		)
		barrier.Transparency = 0.35
		gateModel.PrimaryPart = barrier

		-- Gate decorative frame
		CreatePart(
			"FrameTop",
			Vector3.new(4.2, 2, corridorWidth + 1),
			CFrame.new(info.GateX, 1 + wallHeight - 1, 0),
			Color3.fromRGB(40, 44, 56),
			Enum.Material.SmoothPlastic,
			true,
			true,
			gateModel
		)

		-- Gate Billboard Gui
		local gateBillboard = Instance.new("BillboardGui")
		gateBillboard.Name = "GateBillboard"
		gateBillboard.Adornee = barrier
		gateBillboard.Size = UDim2.fromOffset(280, 65)
		gateBillboard.StudsOffset = Vector3.new(0, 16, 0)
		gateBillboard.AlwaysOnTop = true
		gateBillboard.Parent = gateModel

		local signFrame = Instance.new("Frame")
		signFrame.Name = "SignFrame"
		signFrame.Size = UDim2.fromScale(1, 1)
		signFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
		signFrame.BorderSizePixel = 0
		signFrame.Parent = gateBillboard

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(0, 8)
		sCorner.Parent = signFrame

		local sStroke = Instance.new("UIStroke")
		sStroke.Name = "Stroke"
		sStroke.Color = Color3.fromRGB(255, 60, 60)
		sStroke.Thickness = 2
		sStroke.Parent = signFrame

		local signLabel = Instance.new("TextLabel")
		signLabel.Name = "SignLabel"
		signLabel.Size = UDim2.fromScale(0.9, 0.8)
		signLabel.Position = UDim2.fromScale(0.05, 0.1)
		signLabel.BackgroundTransparency = 1
		signLabel.Text = string.format("[ BLOQUEADA: Supera Máquina %d ]", g)
		signLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		signLabel.TextScaled = true
		signLabel.Font = Enum.Font.GothamBlack
		signLabel.Parent = signFrame

		-- Apply collision group
		CollisionManager.ApplyGateCollisionGroup(gateModel, g)
	end

	-- Apply Cyberpunk Arena Lighting & Post-Processing (Blade Ball style visual retention)
	WorldBuilder.SetupLighting()

	return worldFolder
end

function WorldBuilder.CreateTrainingDummy(name: string, cframe: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("IsDummy", true)
	model.Parent = parent

	local root = CreatePart("HumanoidRootPart", Vector3.new(2, 2, 1), cframe, Color3.fromRGB(180, 180, 190), Enum.Material.SmoothPlastic, true, false, model)
	root.Transparency = 1
	model.PrimaryPart = root

	local _torso = CreatePart("Torso", Vector3.new(2, 2.5, 1.2), cframe * CFrame.new(0, 0.25, 0), Color3.fromRGB(200, 75, 75), Enum.Material.SmoothPlastic, true, true, model)
	local head = CreatePart("Head", Vector3.new(1.3, 1.3, 1.3), cframe * CFrame.new(0, 2.1, 0), Color3.fromRGB(240, 200, 170), Enum.Material.SmoothPlastic, true, true, model)
	head.Shape = Enum.PartType.Ball

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayDistance = 60
	humanoid.DisplayName = name
	humanoid.Parent = model

	local animator = Instance.new("Animator")
	animator.Parent = humanoid

	humanoid.Died:Connect(function()
		task.delay(2.5, function()
			if humanoid.Parent then
				humanoid.Health = humanoid.MaxHealth
			end
		end)
	end)

	local bb = Instance.new("BillboardGui")
	bb.Name = "DummyTag"
	bb.Size = UDim2.fromOffset(190, 45)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	bb.Parent = head

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "🎯 DUMMY DE PRUEBAS"
	lbl.TextColor3 = Color3.fromRGB(255, 220, 50)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = bb

	return model
end

function WorldBuilder.SetupLighting()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 20.0
	Lighting.Brightness = 3.2
	Lighting.Ambient = Color3.fromRGB(225, 230, 240) -- Clear, soft daylight fill
	Lighting.OutdoorAmbient = Color3.fromRGB(215, 220, 230)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
	Lighting.ColorShift_Bottom = Color3.fromRGB(235, 240, 245)
	Lighting.ShadowSoftness = 0.8
	Lighting.GlobalShadows = false
	Lighting.ExposureCompensation = 0.0 -- Zero overexposure glare

	-- Clear residual effects including any BloomEffect
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostProcessEffect") or child:IsA("Atmosphere") or child:IsA("BloomEffect") then
			child:Destroy()
		end
	end

	-- Zero BloomEffect to eliminate all neon glare/blur and maintain crisp, clean visibility

	-- 1. ColorCorrectionEffect: soft, pleasant, natural clarity without crushed shadows
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "VibrantColor"
	colorCorrection.Contrast = 0.0
	colorCorrection.Saturation = 0.05
	colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	colorCorrection.Parent = Lighting

	-- 2. Atmosphere: ultra crystal-clear view, zero haze
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "CyberAtmosphere"
	atmosphere.Density = 0.0
	atmosphere.Offset = 0.0
	atmosphere.Color = Color3.fromRGB(220, 230, 245)
	atmosphere.Decay = Color3.fromRGB(180, 195, 220)
	atmosphere.Glare = 0.0
	atmosphere.Haze = 0.0
	atmosphere.Parent = Lighting
end

return WorldBuilder
