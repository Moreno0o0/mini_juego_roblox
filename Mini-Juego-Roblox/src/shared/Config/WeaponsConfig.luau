--!strict
local Types = require(script.Parent.Parent.Types)

export type WeaponType = "Melee" | "Ranged"

export type WeaponDef = {
	Id: Types.WeaponId,
	Name: string,
	Tier: number,
	Type: WeaponType,
	BaseDamage: number,
	Cooldown: number,
	Range: number,
	Knockback: number,
	Prerequisites: { [string]: boolean },
	ProjectileSpeed: number?,
	Pellets: number?,
	Description: string,
}

local WeaponsConfig: { [string]: WeaponDef } = {
	w_0 = {
		Id = "w_0",
		Name = "Puños",
		Tier = 1,
		Type = "Melee",
		BaseDamage = 8,
		Cooldown = 0.5,
		Range = 4,
		Knockback = 12,
		Prerequisites = {},
		Description = "Ataque básico sin armas. Disponible para todos.",
	},
	w_1 = {
		Id = "w_1",
		Name = "Bate de Madera",
		Tier = 1,
		Type = "Melee",
		BaseDamage = 14,
		Cooldown = 0.8,
		Range = 6,
		Knockback = 28,
		Prerequisites = {},
		Description = "Bate clásico contundente. Arma básica obtenible en la dispensadora de Zona 1.",
	},
	w_2a = {
		Id = "w_2a",
		Name = "Cuchillo Táctico",
		Tier = 2,
		Type = "Melee",
		BaseDamage = 18,
		Cooldown = 0.4,
		Range = 5,
		Knockback = 16,
		Prerequisites = {},
		Description = "Arma blanca rápida y letal a corta distancia. Obtenible gratis en la armería de Zona 2.",
	},
	w_2b = {
		Id = "w_2b",
		Name = "Resortera Reforzada",
		Tier = 2,
		Type = "Ranged",
		BaseDamage = 22,
		Cooldown = 0.9,
		Range = 45,
		Knockback = 22,
		ProjectileSpeed = 130,
		Prerequisites = { ["2_3"] = true },
		Description = "Proyectil a distancia intermedia con empuje efectivo.",
	},
	w_3a = {
		Id = "w_3a",
		Name = "Espada Corta",
		Tier = 3,
		Type = "Melee",
		BaseDamage = 30,
		Cooldown = 0.6,
		Range = 7,
		Knockback = 32,
		Prerequisites = {},
		Description = "Corte balanceado de acero forjado. Obtenible gratis en la armería de Zona 3.",
	},
	w_3b = {
		Id = "w_3b",
		Name = "Pistola Básica",
		Tier = 3,
		Type = "Ranged",
		BaseDamage = 35,
		Cooldown = 0.7,
		Range = 65,
		Knockback = 26,
		ProjectileSpeed = 210,
		Prerequisites = { ["3_3"] = true },
		Description = "Disparos balísticos precisos a larga distancia.",
	},
	w_4a = {
		Id = "w_4a",
		Name = "Katana",
		Tier = 4,
		Type = "Melee",
		BaseDamage = 50,
		Cooldown = 0.5,
		Range = 8,
		Knockback = 38,
		Prerequisites = {},
		Description = "Filo supremo para combate ágil. Obtenible gratis en la armería de Zona 4.",
	},
	w_4b = {
		Id = "w_4b",
		Name = "Escopeta de Combate",
		Tier = 4,
		Type = "Ranged",
		BaseDamage = 60,
		Cooldown = 1.2,
		Range = 40,
		Knockback = 58,
		ProjectileSpeed = 190,
		Pellets = 5,
		Prerequisites = { ["4_3"] = true },
		Description = "Disparo disperso devastador para desalojar cualquier plataforma.",
	},
	w_5a = {
		Id = "w_5a",
		Name = "Martillo Pesado",
		Tier = 5,
		Type = "Melee",
		BaseDamage = 75,
		Cooldown = 1.4,
		Range = 9,
		Knockback = 85,
		Prerequisites = {},
		Description = "Masa titánica con gran empuje físico. Obtenible gratis en la armería de Zona 5.",
	},
	w_5b = {
		Id = "w_5b",
		Name = "Rifle de Plasma",
		Tier = 5,
		Type = "Ranged",
		BaseDamage = 90,
		Cooldown = 0.5,
		Range = 100,
		Knockback = 50,
		ProjectileSpeed = 280,
		Prerequisites = { ["5_5"] = true },
		Description = "El arma definitiva del Coliseo. Dispara proyectiles de energía pura.",
	},
}

local Module = {
	Weapons = WeaponsConfig,
}

function Module.Get(id: Types.WeaponId): WeaponDef?
	return WeaponsConfig[id]
end

function Module.GetAll(): { [string]: WeaponDef }
	return WeaponsConfig
end

function Module.GetByTier(tier: number): { WeaponDef }
	local result: { WeaponDef } = {}
	for _, def in pairs(WeaponsConfig) do
		if def.Tier == tier then
			table.insert(result, def)
		end
	end
	return result
end

function Module.GetBestWeaponForTier(inventory: { [string]: boolean }, maxTier: number): WeaponDef
	local best: WeaponDef = WeaponsConfig["w_0"]
	for id, owned in pairs(inventory) do
		if owned then
			local def = WeaponsConfig[id]
			if def and def.Tier <= maxTier then
				if def.BaseDamage > best.BaseDamage then
					best = def
				end
			end
		end
	end
	return best
end

return Module
