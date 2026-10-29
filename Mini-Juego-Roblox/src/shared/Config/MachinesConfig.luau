--!strict
local Types = require(script.Parent.Parent.Types)

export type RewardType = "Weapon" | "Perk" | "ZoneUnlock"

export type RewardDef = {
	Type: RewardType,
	WeaponId: Types.WeaponId?,
	PerkKey: string?,
	NextZoneId: Types.ZoneId?,
	Description: string,
}

export type MachineLevelDef = {
	MachineId: Types.MachineId,
	Difficulty: Types.DifficultyLevel,
	MinTime: number, -- T_min: Physically minimum possible time (anti-cheat)
	MaxTime: number, -- T_max: Timeout (45-60s)
	Complexity: number, -- Phi(m, d): strictly monotonic increasing
	Reward: RewardDef,
}

export type MachineDef = {
	Id: Types.MachineId,
	Name: string,
	MinigameType: string,
	AssociatedZoneId: Types.ZoneId,
	Description: string,
	DefaultTimeout: number,
	Levels: { [Types.DifficultyLevel]: MachineLevelDef },
}

local function CreateReward(
	rType: RewardType,
	desc: string,
	weaponId: Types.WeaponId?,
	perkKey: string?,
	nextZoneId: Types.ZoneId?
): RewardDef
	return {
		Type = rType,
		WeaponId = weaponId,
		PerkKey = perkKey,
		NextZoneId = nextZoneId,
		Description = desc,
	}
end

-- Reward mapping Rew: M x D -> RewardDef
local RewardMatrix: { [string]: RewardDef } = {
	["1_1"] = CreateReward("Weapon", "Desbloquea Bate de Madera y Acceso a Zona 2", "w_1", nil, "Zone_2"),
	["1_2"] = CreateReward("Perk", "Mejora de Velocidad +5%", nil, "speed_1", nil),
	["1_3"] = CreateReward("Perk", "Bonificación de Ataque +5%", nil, "damage_1", nil),
	["1_4"] = CreateReward("Perk", "Salud Máxima +10 HP", nil, "health_1", nil),
	["1_5"] = CreateReward("Perk", "Maestría de Reflejos +10% Velocidad", nil, "speed_max", "Zone_2"),

	["2_1"] = CreateReward("Weapon", "Desbloquea Cuchillo Táctico y Acceso a Zona 3", "w_2a", nil, "Zone_3"),
	["2_2"] = CreateReward("Perk", "Tiempo de Recarga -10%", nil, "cooldown_1", nil),
	["2_3"] = CreateReward("Weapon", "Desbloquea Resortera Reforzada", "w_2b", nil, nil),
	["2_4"] = CreateReward("Perk", "Resistencia de Empuje +15%", nil, "knockback_res_1", nil),
	["2_5"] = CreateReward("Perk", "Evasión Láser +10% Defensa", nil, "defense_laser", "Zone_3"),

	["3_1"] = CreateReward("Weapon", "Desbloquea Espada Corta y Acceso a Zona 4", "w_3a", nil, "Zone_4"),
	["3_2"] = CreateReward("Perk", "Velocidad de Movimiento +8%", nil, "speed_2", nil),
	["3_3"] = CreateReward("Weapon", "Desbloquea Pistola Básica", "w_3b", nil, nil),
	["3_4"] = CreateReward("Perk", "Salud Máxima +15 HP", nil, "health_2", nil),
	["3_5"] = CreateReward("Perk", "Puntería de Élite +15% Daño", nil, "damage_sniper", "Zone_4"),

	["4_1"] = CreateReward("Weapon", "Desbloquea Katana y Acceso a Zona 5 (Cumbre)", "w_4a", nil, "Zone_5"),
	["4_2"] = CreateReward("Perk", "Daño Crítico +15%", nil, "crit_1", nil),
	["4_3"] = CreateReward("Weapon", "Desbloquea Escopeta de Combate", "w_4b", nil, nil),
	["4_4"] = CreateReward("Perk", "Reducción de Daño Entrante 10%", nil, "defense_1", nil),
	["4_5"] = CreateReward("Perk", "Memoria Cuántica +20% HP", nil, "health_matrix", "Zone_5"),

	["5_1"] = CreateReward("Weapon", "Desbloquea Martillo Pesado", "w_5a", nil, nil),
	["5_2"] = CreateReward("Perk", "Regeneración Pasiva +2 HP/s", nil, "regen_1", nil),
	["5_3"] = CreateReward("Perk", "Empuje Físico +25%", nil, "knockback_boost_1", nil),
	["5_4"] = CreateReward("Perk", "Escudo Protector en Captura +20%", nil, "capture_shield_1", nil),
	["5_5"] = CreateReward("Weapon", "Desbloquea Rifle de Plasma Supremo", "w_5b", nil, nil),
}

local function BuildLevels(machineId: Types.MachineId): { [Types.DifficultyLevel]: MachineLevelDef }
	local levels: { [Types.DifficultyLevel]: MachineLevelDef } = {}
	for d = 1, 5 do
		local key = string.format("%d_%d", machineId, d)
		local reward = RewardMatrix[key]
		assert(reward ~= nil, "Missing reward for key: " .. key)

		local maxTime = 60.0
		if machineId == 1 then
			maxTime = 50.0
		elseif machineId == 2 then
			maxTime = 80.0 -- Generoso tiempo de 80s para cruzar plataformas y láseres
		elseif machineId == 3 then
			maxTime = 60.0
		elseif machineId == 4 then
			maxTime = 70.0
		elseif machineId == 5 then
			maxTime = 35.0
		end

		levels[d] = {
			MachineId = machineId,
			Difficulty = d,
			MinTime = 2.0, -- T_min: safe anti-cheat floor
			MaxTime = maxTime,
			Complexity = (machineId * 10) + d, -- Strictly increasing Phi(m, d)
			Reward = reward,
		}
	end
	return levels
end

local MachinesConfig: { [Types.MachineId]: MachineDef } = {
	[1] = {
		Id = 1,
		Name = "Máquina 1: Reflex QTE",
		MinigameType = "ReflexQTE",
		AssociatedZoneId = "Zone_1",
		Description = "Prueba de reflejos rápidos. Presiona la secuencia de teclas en orden evitando trampas.",
		DefaultTimeout = 50,
		Levels = BuildLevels(1),
	},
	[2] = {
		Id = 2,
		Name = "Máquina 2: Plataformas",
		MinigameType = "LaserGrid",
		AssociatedZoneId = "Zone_2",
		Description = "Micro-parkour evasivo sobre plataformas con foso inferior.",
		DefaultTimeout = 52,
		Levels = BuildLevels(2),
	},
	[3] = {
		Id = 3,
		Name = "Máquina 3: Target Practice",
		MinigameType = "TargetPractice",
		AssociatedZoneId = "Zone_3",
		Description = "Galería de tiro en primera persona. Destruye dianas evitando los señuelos rojos.",
		DefaultTimeout = 55,
		Levels = BuildLevels(3),
	},
	[4] = {
		Id = 4,
		Name = "Máquina 4: Memory Matrix",
		MinigameType = "MemoryMatrix",
		AssociatedZoneId = "Zone_4",
		Description = "Matriz 4x4 de memoria secuencial. Reproduce el camino exacto de paneles luminosos.",
		DefaultTimeout = 58,
		Levels = BuildLevels(4),
	},
	[5] = {
		Id = 5,
		Name = "Máquina 5: Bullet Hell",
		MinigameType = "BulletHell",
		AssociatedZoneId = "Zone_5",
		Description = "Coliseo de supervivencia. Esquiva la tormenta de proyectiles helicoidales.",
		DefaultTimeout = 60,
		Levels = BuildLevels(5),
	},
}

local Module = {
	Machines = MachinesConfig,
	RewardMatrix = RewardMatrix,
}

function Module.GetMachine(id: Types.MachineId): MachineDef?
	return MachinesConfig[id]
end

function Module.GetLevel(machineId: Types.MachineId, difficulty: Types.DifficultyLevel): MachineLevelDef?
	local machine = MachinesConfig[machineId]
	if not machine then
		return nil
	end
	return machine.Levels[difficulty]
end

function Module.GetReward(machineId: Types.MachineId, difficulty: Types.DifficultyLevel): RewardDef?
	local key = string.format("%d_%d", machineId, difficulty)
	return RewardMatrix[key]
end

return Module
