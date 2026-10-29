--!strict
export type Set<T> = { [T]: boolean }
export type Relation<A, B> = { [A]: { [B]: boolean } }

export type PlayerState = "Combat" | "Capturing" | "Playing" | "Immunity" | "Dead"

export type ZoneId = "Zone_1" | "Zone_2" | "Zone_3" | "Zone_4" | "Zone_5"
export type MachineId = number
export type DifficultyLevel = number

export type WeaponId =
	| "w_0"
	| "w_1"
	| "w_2a"
	| "w_2b"
	| "w_3a"
	| "w_3b"
	| "w_4a"
	| "w_4b"
	| "w_5a"
	| "w_5b"

export type LevelKey = string -- format "m_d", e.g., "1_1"

return {}
