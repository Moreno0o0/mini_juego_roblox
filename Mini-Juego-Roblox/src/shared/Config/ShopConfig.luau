--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

export type ShopCategory = "Immunity" | "Buff" | "Weapon"

export type ShopItem = {
	Id: string,
	Name: string,
	Description: string,
	Category: ShopCategory,
	Price: number,
	RequiredZoneTier: number,
	WeaponId: Types.WeaponId?,
	Duration: number?,
}

local ShopItems: { [string]: ShopItem } = {
	["shield_immunity_15s"] = {
		Id = "shield_immunity_15s",
		Name = "Escudo de Inmunidad (15s)",
		Description = "Invulnerabilidad total en combate mediante ForceField durante 15 segundos.",
		Category = "Immunity",
		Price = 15,
		RequiredZoneTier = 1,
		Duration = 15,
	},
	["shield_immunity_30s"] = {
		Id = "shield_immunity_30s",
		Name = "Escudo de Sobrecarga (30s)",
		Description = "Invulnerabilidad total extendida durante 30 segundos continuos.",
		Category = "Immunity",
		Price = 28,
		RequiredZoneTier = 2,
		Duration = 30,
	},
	["stim_speed_boost"] = {
		Id = "stim_speed_boost",
		Name = "Estimulante de Velocidad",
		Description = "+50% de velocidad de movimiento (WalkSpeed 24) durante 20 segundos.",
		Category = "Buff",
		Price = 10,
		RequiredZoneTier = 1,
		Duration = 20,
	},
	["stim_hyper_speed"] = {
		Id = "stim_hyper_speed",
		Name = "Estimulante Hiper-Velocidad",
		Description = "+75% de velocidad extrema (WalkSpeed 28) durante 25 segundos.",
		Category = "Buff",
		Price = 18,
		RequiredZoneTier = 2,
		Duration = 25,
	},
	["nanobots_heal"] = {
		Id = "nanobots_heal",
		Name = "Nanobots Médicos",
		Description = "Regenera instantáneamente la salud al 100% de HP.",
		Category = "Buff",
		Price = 10,
		RequiredZoneTier = 1,
	},
	["weapon_bat"] = {
		Id = "weapon_bat",
		Name = "Bate de Madera Reforzado",
		Description = "Arma contundente cuerpo a cuerpo (Tier 1). Daño base: 14.",
		Category = "Weapon",
		Price = 10,
		RequiredZoneTier = 1,
		WeaponId = "w_1",
	},
	["weapon_knife"] = {
		Id = "weapon_knife",
		Name = "Cuchillo Táctico Cibernético",
		Description = "Arma rápida de corta distancia (Tier 2). Daño base: 18.",
		Category = "Weapon",
		Price = 20,
		RequiredZoneTier = 2,
		WeaponId = "w_2a",
	},
	["weapon_slingshot"] = {
		Id = "weapon_slingshot",
		Name = "Resortera Reforzada",
		Description = "Arma balística de medio alcance (Tier 2). Daño base: 22.",
		Category = "Weapon",
		Price = 25,
		RequiredZoneTier = 2,
		WeaponId = "w_2b",
	},
	["weapon_sword"] = {
		Id = "weapon_sword",
		Name = "Espada Corta de Acero",
		Description = "Corte balanceado de gran daño (Tier 3). Daño base: 30.",
		Category = "Weapon",
		Price = 35,
		RequiredZoneTier = 3,
		WeaponId = "w_3a",
	},
	["weapon_pistol"] = {
		Id = "weapon_pistol",
		Name = "Pistola Balística",
		Description = "Disparos a distancia precisa (Tier 3). Daño base: 35.",
		Category = "Weapon",
		Price = 45,
		RequiredZoneTier = 3,
		WeaponId = "w_3b",
	},
	["weapon_katana"] = {
		Id = "weapon_katana",
		Name = "Katana de Nanocristal",
		Description = "Filo supremo de combate ágil (Tier 4). Daño base: 50.",
		Category = "Weapon",
		Price = 60,
		RequiredZoneTier = 4,
		WeaponId = "w_4a",
	},
	["weapon_shotgun"] = {
		Id = "weapon_shotgun",
		Name = "Escopeta de Choque",
		Description = "Dispersión devastadora y gran empuje (Tier 4). Daño base: 60.",
		Category = "Weapon",
		Price = 75,
		RequiredZoneTier = 4,
		WeaponId = "w_4b",
	},
	["weapon_hammer"] = {
		Id = "weapon_hammer",
		Name = "Martillo Pesado Titánico",
		Description = "Fuerza colosal y el mayor empuje (Tier 5). Daño base: 75.",
		Category = "Weapon",
		Price = 90,
		RequiredZoneTier = 5,
		WeaponId = "w_5a",
	},
	["weapon_plasma"] = {
		Id = "weapon_plasma",
		Name = "Rifle de Plasma Supremo",
		Description = "Tecnología definitiva de energía (Tier 5). Daño base: 90.",
		Category = "Weapon",
		Price = 120,
		RequiredZoneTier = 5,
		WeaponId = "w_5b",
	},
}

local ShopConfig = {
	Items = ShopItems,
	StartingCredits = 50,
	WinRewardCredits = 25,
}

function ShopConfig.GetItem(id: string): ShopItem?
	return ShopItems[id]
end

return ShopConfig
