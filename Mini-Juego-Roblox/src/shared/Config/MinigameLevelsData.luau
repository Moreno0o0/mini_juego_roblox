--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

export type QTELevelConfig = {
	SequenceLength: number,
	WindowPerKey: number,
	DistractorCount: number,
}

export type LaserGridLevelConfig = {
	LaserCount: number,
	LaserSpeed: number,
	DisappearingPlatforms: boolean,
}

export type TargetPracticeLevelConfig = {
	TargetCount: number,
	TargetLifespan: number,
	PenaltyDecoyCount: number,
}

export type MemoryMatrixLevelConfig = {
	PathLength: number,
	FlashDuration: number,
}

export type BulletHellLevelConfig = {
	ProjectileCount: number,
	PatternType: "Linear" | "Circular" | "Cross" | "Helical" | "RadialHelical",
	SurvivalDuration: number,
}

export type SpecificLevelData = {
	QTE: QTELevelConfig?,
	LaserGrid: LaserGridLevelConfig?,
	TargetPractice: TargetPracticeLevelConfig?,
	MemoryMatrix: MemoryMatrixLevelConfig?,
	BulletHell: BulletHellLevelConfig?,
}

export type LevelData = {
	MachineId: Types.MachineId,
	Difficulty: Types.DifficultyLevel,
	ComplexityPhi: number, -- Phi(m, d) strictly monotonic increasing in d
	MinPhysicalTime: number, -- T_min(m, d) > 0
	MaxAllowedTime: number, -- T_max(m, d) <= 60
	Specific: SpecificLevelData,
}

local LevelsMatrix: { [string]: LevelData } = {}

-- Populate Machine 1: Reflex QTE
do
	local lengths = { 5, 6, 7, 9, 11 }
	local windows = { 2.0, 1.7, 1.4, 1.2, 1.0 }
	local distractors = { 0, 1, 1, 2, 3 }
	local minTimes = { 0.4, 0.5, 0.65, 0.8, 1.0 }
	local maxTimes = { 50, 50, 55, 55, 60 }

	for d = 1, 5 do
		local key = string.format("1_%d", d)
		LevelsMatrix[key] = {
			MachineId = 1,
			Difficulty = d,
			ComplexityPhi = 100 + (d * 20),
			MinPhysicalTime = minTimes[d],
			MaxAllowedTime = maxTimes[d],
			Specific = {
				QTE = {
					SequenceLength = lengths[d],
					WindowPerKey = windows[d],
					DistractorCount = distractors[d],
				},
			},
		}
	end
end

-- Populate Machine 2: Laser Grid / Extended Parkour
do
	local laserCounts = { 3, 5, 7, 10, 14 }
	local laserSpeeds = { 12, 16, 20, 25, 30 }
	local disappearing = { false, false, false, true, true }
	local minTimes = { 6.0, 7.0, 8.0, 8.5, 9.0 }
	local maxTimes = { 35, 30, 28, 25, 22 }

	for d = 1, 5 do
		local key = string.format("2_%d", d)
		LevelsMatrix[key] = {
			MachineId = 2,
			Difficulty = d,
			ComplexityPhi = 200 + (d * 20),
			MinPhysicalTime = minTimes[d],
			MaxAllowedTime = maxTimes[d],
			Specific = {
				LaserGrid = {
					LaserCount = laserCounts[d],
					LaserSpeed = laserSpeeds[d],
					DisappearingPlatforms = disappearing[d],
				},
			},
		}
	end
end

-- Populate Machine 3: Target Practice (High-Difficulty Aim-Trainer)
do
	local targets = { 10, 15, 20, 26, 32 }
	local lifespans = { 1.5, 1.25, 1.0, 0.8, 0.65 }
	local decoys = { 1, 2, 4, 6, 8 }
	local minTimes = { 3.0, 4.0, 5.0, 6.0, 7.0 }
	local maxTimes = { 30, 28, 25, 22, 20 }

	for d = 1, 5 do
		local key = string.format("3_%d", d)
		LevelsMatrix[key] = {
			MachineId = 3,
			Difficulty = d,
			ComplexityPhi = 300 + (d * 20),
			MinPhysicalTime = minTimes[d],
			MaxAllowedTime = maxTimes[d],
			Specific = {
				TargetPractice = {
					TargetCount = targets[d],
					TargetLifespan = lifespans[d],
					PenaltyDecoyCount = decoys[d],
				},
			},
		}
	end
end

-- Populate Machine 4: Memory Matrix
do
	local pathLengths = { 5, 6, 7, 8, 10 }
	local flashTimes = { 0.8, 0.7, 0.55, 0.45, 0.35 }
	local minTimes = { 4.0, 5.0, 6.0, 7.5, 9.0 }
	local maxTimes = { 48, 50, 54, 58, 60 }

	for d = 1, 5 do
		local key = string.format("4_%d", d)
		LevelsMatrix[key] = {
			MachineId = 4,
			Difficulty = d,
			ComplexityPhi = 400 + (d * 20),
			MinPhysicalTime = minTimes[d],
			MaxAllowedTime = maxTimes[d],
			Specific = {
				MemoryMatrix = {
					PathLength = pathLengths[d],
					FlashDuration = flashTimes[d],
				},
			},
		}
	end
end

-- Populate Machine 5: Bullet Hell
do
	local projectileCounts = { 6, 10, 16, 24, 34 }
	local patterns: { "Linear" | "Circular" | "Cross" | "Helical" | "RadialHelical" } = {
		"Linear",
		"Circular",
		"Cross",
		"Helical",
		"RadialHelical",
	}
	local survivalTimes = { 15, 20, 25, 30, 35 }
	local maxTimes = { 45, 50, 52, 58, 60 }

	for d = 1, 5 do
		local key = string.format("5_%d", d)
		LevelsMatrix[key] = {
			MachineId = 5,
			Difficulty = d,
			ComplexityPhi = 500 + (d * 20),
			MinPhysicalTime = survivalTimes[d], -- Survival min time is the exact required duration
			MaxAllowedTime = maxTimes[d],
			Specific = {
				BulletHell = {
					ProjectileCount = projectileCounts[d],
					PatternType = patterns[d],
					SurvivalDuration = survivalTimes[d],
				},
			},
		}
	end
end

local Module = {
	Matrix = LevelsMatrix,
}

function Module.GetLevel(machineId: Types.MachineId, difficulty: Types.DifficultyLevel): LevelData?
	local key = string.format("%d_%d", machineId, difficulty)
	return LevelsMatrix[key]
end

return Module
