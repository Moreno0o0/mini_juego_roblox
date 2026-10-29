--!strict
export type WeaponIconInfo = {
	Glyph: string,
	Color: Color3,
	AccentColor: Color3,
	Tier: number,
	Name: string,
}

local WEAPON_ICON_DATA: { [string]: WeaponIconInfo } = {
	w_0 = { Glyph = "👊", Color = Color3.fromRGB(120, 120, 130), AccentColor = Color3.fromRGB(180, 180, 190), Tier = 1, Name = "Puños" },
	w_1 = { Glyph = "🏏", Color = Color3.fromRGB(160, 110, 60), AccentColor = Color3.fromRGB(220, 160, 90), Tier = 1, Name = "Bate de Madera" },
	w_2a = { Glyph = "🗡️", Color = Color3.fromRGB(70, 130, 180), AccentColor = Color3.fromRGB(120, 190, 240), Tier = 2, Name = "Cuchillo Táctico" },
	w_2b = { Glyph = "🎯", Color = Color3.fromRGB(60, 150, 90), AccentColor = Color3.fromRGB(100, 220, 140), Tier = 2, Name = "Resortera" },
	w_3a = { Glyph = "⚔️", Color = Color3.fromRGB(65, 105, 225), AccentColor = Color3.fromRGB(130, 170, 255), Tier = 3, Name = "Espada Corta" },
	w_3b = { Glyph = "🔫", Color = Color3.fromRGB(90, 100, 140), AccentColor = Color3.fromRGB(160, 175, 220), Tier = 3, Name = "Pistola Básica" },
	w_4a = { Glyph = "⚡", Color = Color3.fromRGB(160, 60, 230), AccentColor = Color3.fromRGB(215, 120, 255), Tier = 4, Name = "Katana" },
	w_4b = { Glyph = "💥", Color = Color3.fromRGB(230, 80, 40), AccentColor = Color3.fromRGB(255, 150, 80), Tier = 4, Name = "Escopeta" },
	w_5a = { Glyph = "🔨", Color = Color3.fromRGB(230, 170, 20), AccentColor = Color3.fromRGB(255, 220, 80), Tier = 5, Name = "Martillo Pesado" },
	w_5b = { Glyph = "⚛️", Color = Color3.fromRGB(0, 210, 255), AccentColor = Color3.fromRGB(140, 245, 255), Tier = 5, Name = "Rifle de Plasma" },
}

local DIFFICULTY_COLORS: { [number]: { Color: Color3, Accent: Color3, Title: string } } = {
	[1] = { Color = Color3.fromRGB(46, 204, 113), Accent = Color3.fromRGB(100, 255, 160), Title = "Novato" },
	[2] = { Color = Color3.fromRGB(52, 152, 219), Accent = Color3.fromRGB(120, 200, 255), Title = "Intermedio" },
	[3] = { Color = Color3.fromRGB(155, 89, 182), Accent = Color3.fromRGB(210, 140, 255), Title = "Avanzado" },
	[4] = { Color = Color3.fromRGB(230, 126, 34), Accent = Color3.fromRGB(255, 170, 90), Title = "Experto" },
	[5] = { Color = Color3.fromRGB(241, 196, 15), Accent = Color3.fromRGB(255, 235, 100), Title = "Cumbre" },
}

local AssetIcons = {}

function AssetIcons.GetWeaponData(weaponId: string): WeaponIconInfo
	return WEAPON_ICON_DATA[weaponId] or {
		Glyph = "⚔️",
		Color = Color3.fromRGB(100, 100, 100),
		AccentColor = Color3.fromRGB(180, 180, 180),
		Tier = 1,
		Name = weaponId,
	}
end

function AssetIcons.CreateWeaponIcon(weaponId: string, parent: Instance?): Frame
	local data = AssetIcons.GetWeaponData(weaponId)

	local card = Instance.new("Frame")
	card.Name = "WeaponIcon_" .. weaponId
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	card.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = data.Color
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 32, 40)),
		ColorSequenceKeypoint.new(1, data.Color),
	})
	gradient.Rotation = 45
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	gradient.Parent = card

	local glyphLabel = Instance.new("TextLabel")
	glyphLabel.Name = "Glyph"
	glyphLabel.Size = UDim2.fromScale(1, 0.6)
	glyphLabel.Position = UDim2.fromScale(0, 0.05)
	glyphLabel.BackgroundTransparency = 1
	glyphLabel.Text = data.Glyph
	glyphLabel.TextScaled = true
	glyphLabel.Font = Enum.Font.GothamBold
	glyphLabel.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.3)
	nameLabel.Position = UDim2.fromScale(0, 0.65)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.Name
	nameLabel.TextColor3 = data.AccentColor
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.Parent = card

	local tierBadge = Instance.new("TextLabel")
	tierBadge.Name = "TierBadge"
	tierBadge.Size = UDim2.fromScale(0.3, 0.2)
	tierBadge.Position = UDim2.fromScale(0.05, 0.05)
	tierBadge.BackgroundColor3 = data.Color
	tierBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	tierBadge.Text = "T" .. data.Tier
	tierBadge.TextScaled = true
	tierBadge.Font = Enum.Font.GothamBold
	tierBadge.BorderSizePixel = 0
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 4)
	badgeCorner.Parent = tierBadge
	tierBadge.Parent = card

	if parent then
		card.Parent = parent
	end

	return card
end

function AssetIcons.CreateDifficultyBadge(difficulty: number, parent: Instance?): Frame
	local clamped = math.clamp(difficulty, 1, 5)
	local info = DIFFICULTY_COLORS[clamped]

	local badge = Instance.new("Frame")
	badge.Name = "DiffBadge_" .. clamped
	badge.Size = UDim2.fromScale(1, 1)
	badge.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
	badge.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Color = info.Color
	stroke.Thickness = 2
	stroke.Parent = badge

	local stars = string.rep("★", clamped) .. string.rep("☆", 5 - clamped)

	local starLabel = Instance.new("TextLabel")
	starLabel.Name = "Stars"
	starLabel.Size = UDim2.fromScale(1, 0.5)
	starLabel.Position = UDim2.fromScale(0, 0.05)
	starLabel.BackgroundTransparency = 1
	starLabel.Text = stars
	starLabel.TextColor3 = info.Accent
	starLabel.TextScaled = true
	starLabel.Font = Enum.Font.GothamBold
	starLabel.Parent = badge

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Title"
	textLabel.Size = UDim2.fromScale(1, 0.4)
	textLabel.Position = UDim2.fromScale(0, 0.55)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = string.format("Nivel %d: %s", clamped, info.Title)
	textLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamMedium
	textLabel.Parent = badge

	if parent then
		badge.Parent = parent
	end

	return badge
end

return AssetIcons
