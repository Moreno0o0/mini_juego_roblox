--!strict
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MinigameLevelsData = require(ReplicatedStorage.Shared.Config.MinigameLevelsData)
local MachinesConfig = require(ReplicatedStorage.Shared.Config.MachinesConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Network = require(ReplicatedStorage.Shared.Network)
local SecurityValidator = require(ServerScriptService.Server.SecurityValidator)
local ProgressionService = require(ServerScriptService.Server.ProgressionService)
local InventoryService = require(ServerScriptService.Server.InventoryService)
local MachineManager = require(ServerScriptService.Server.MachineManager)
local ShopService = require(ServerScriptService.Server.ShopService)
local StreakService = require(ServerScriptService.Server.StreakService)

type Session = {
	Token: string,
	Player: Player,
	MachineId: number,
	Difficulty: number,
	StartTime: number,
	Data: any,
}

local activeSessions: { [Player]: Session } = {}

local MinigameValidators = {}

local QTE_ALPHABET = { "W", "A", "S", "D", "E", "Q", "Space" }

function MinigameValidators.StartQTESession(player: Player, difficulty: number): (string, { Sequence: { string }, Distractors: { [number]: boolean } })
	local levelData = MinigameLevelsData.GetLevel(1, difficulty)
	local qteConfig = levelData and levelData.Specific.QTE or { SequenceLength = 4, WindowPerKey = 1.2, DistractorCount = 0 }

	local sequence: { string } = {}
	local distractors: { [number]: boolean } = {}

	for _ = 1, qteConfig.SequenceLength do
		local randIdx = math.random(1, #QTE_ALPHABET)
		table.insert(sequence, QTE_ALPHABET[randIdx])
	end

	-- Place distractors (indices that are traps and must be skipped/avoided)
	local trapCount = qteConfig.DistractorCount
	while trapCount > 0 do
		local trapIdx = math.random(1, #sequence)
		if not distractors[trapIdx] then
			distractors[trapIdx] = true
			trapCount -= 1
		end
	end

	local token = HttpService:GenerateGUID(false)
	activeSessions[player] = {
		Token = token,
		Player = player,
		MachineId = 1,
		Difficulty = difficulty,
		StartTime = os.clock(),
		Data = {
			Sequence = sequence,
			Distractors = distractors,
		},
	}

	return token, { Sequence = sequence, Distractors = distractors }
end

function MinigameValidators.ValidateQTESubmission(
	player: Player,
	difficulty: number,
	timeSpent: number,
	clientToken: string,
	inputs: { string },
	pressedTraps: boolean
): (boolean, string?)
	local session = activeSessions[player]
	if not session or session.MachineId ~= 1 then
		return false, "No active QTE session found"
	end

	if clientToken ~= session.Token then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(1, "InvalidToken", player)
		return false, "Token mismatch"
	end

	-- Check loss conditions first so failures are NEVER blocked by anti-speedhack minTime
	if pressedTraps then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(1, "TrapPressed", player)
		return false, "Failed: Distractor trap key was pressed"
	end

	local targetSeq: { string } = session.Data.Sequence
	local distractors: { [number]: boolean } = session.Data.Distractors

	-- Check that valid sequence matches non-distractor targets
	local validInputs = {}
	for idx, key in ipairs(targetSeq) do
		if not distractors[idx] then
			table.insert(validInputs, key)
		end
	end

	if #inputs ~= #validInputs then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(1, "InputLengthMismatch", player)
		return false, string.format("Input length mismatch: expected %d, got %d", #validInputs, #inputs)
	end

	for i = 1, #validInputs do
		if inputs[i] ~= validInputs[i] then
			activeSessions[player] = nil
			MachineManager.ReleaseMachine(1, "KeyMismatch", player)
			return false, string.format("Key mismatch at index %d: expected %s, got %s", i, validInputs[i], inputs[i])
		end
	end

	-- Only for verified victory attempts: validate against physical minimum time
	local levelData = MinigameLevelsData.GetLevel(1, difficulty)
	local minTime = if levelData then levelData.MinPhysicalTime else 2.0

	local isValidSec, secErr = SecurityValidator.ValidateMinigameResult(
		player,
		1,
		difficulty,
		timeSpent,
		clientToken,
		session.Token,
		minTime
	)
	if not isValidSec then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(1, "SpeedhackCheckFailed", player)
		return false, secErr
	end

	-- Session verified: Award win and rewards
	activeSessions[player] = nil

	local _, msg = ProgressionService.RecordWin(player, 1, difficulty)
	local _, streakMult = StreakService.IncrementStreak(player)
	local baseReward = ShopConfig.WinRewardCredits
	local finalCredits = math.floor(baseReward * streakMult)
	ShopService.AddCredits(player, finalCredits)

	local levelReward = MachinesConfig.GetReward(1, difficulty)
	if levelReward and levelReward.WeaponId then
		InventoryService.AddReward(player, 1, difficulty, levelReward.WeaponId)
	else
		InventoryService.AddReward(player, 1, difficulty, nil)
	end

	pcall(function()
		local syncRemote = Network.GetRemote("SyncState")
		syncRemote:FireClient(player, {
			MachineId = 1,
			Level = difficulty,
			WinCelebration = {
				MachineId = 1,
				Difficulty = difficulty,
				Message = msg or string.format("¡Máquina 1 Nivel %d superado!", difficulty),
				RewardWeapon = levelReward and levelReward.WeaponId or nil,
			}
		})
	end)

	-- Release machine to Immunity
	MachineManager.ReleaseMachine(1, "Win", player)

	return true, nil
end

function MinigameValidators.StartLaserGridSession(player: Player, difficulty: number): (string, { LaserCount: number, LaserSpeed: number, DisappearingPlatforms: boolean })
	local levelData = MinigameLevelsData.GetLevel(2, difficulty)
	local laserConfig = levelData and levelData.Specific.LaserGrid or { LaserCount = 2, LaserSpeed = 10, DisappearingPlatforms = false }

	local token = HttpService:GenerateGUID(false)
	activeSessions[player] = {
		Token = token,
		Player = player,
		MachineId = 2,
		Difficulty = difficulty,
		StartTime = os.clock(),
		Data = laserConfig,
	}

	return token, laserConfig
end

function MinigameValidators.ValidateLaserGridSubmission(
	player: Player,
	difficulty: number,
	timeSpent: number,
	clientToken: string,
	reachedGoal: boolean,
	_touchedLaser: boolean
): (boolean, string?)
	local session = activeSessions[player]
	if not session or session.MachineId ~= 2 then
		return false, "No active Laser Grid session found"
	end

	if clientToken ~= session.Token then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(2, "InvalidToken", player)
		return false, "Token mismatch"
	end

	if not reachedGoal then
		activeSessions[player] = nil
		-- Abort match immediately and release player to immunity
		MachineManager.ReleaseMachine(2, "FallHazard", player)
		return false, "Failed: Did not reach goal"
	end

	local levelData = MinigameLevelsData.GetLevel(2, difficulty)
	local minTime = if levelData then levelData.MinPhysicalTime else 3.0

	local isValidSec, secErr = SecurityValidator.ValidateMinigameResult(
		player,
		2,
		difficulty,
		timeSpent,
		clientToken,
		session.Token,
		minTime
	)
	if not isValidSec then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(2, "SpeedhackCheckFailed", player)
		return false, secErr
	end

	-- Verified victory
	activeSessions[player] = nil
	local _, msg = ProgressionService.RecordWin(player, 2, difficulty)
	local _, streakMult = StreakService.IncrementStreak(player)
	local baseReward = ShopConfig.WinRewardCredits
	local finalCredits = math.floor(baseReward * streakMult)
	ShopService.AddCredits(player, finalCredits)

	local levelReward = MachinesConfig.GetReward(2, difficulty)
	if levelReward and levelReward.WeaponId then
		InventoryService.AddReward(player, 2, difficulty, levelReward.WeaponId)
	else
		InventoryService.AddReward(player, 2, difficulty, nil)
	end

	pcall(function()
		local syncRemote = Network.GetRemote("SyncState")
		syncRemote:FireClient(player, {
			MachineId = 2,
			Level = difficulty,
			WinCelebration = {
				MachineId = 2,
				Difficulty = difficulty,
				Message = msg or string.format("¡Máquina 2 Nivel %d superado!", difficulty),
				RewardWeapon = levelReward and levelReward.WeaponId or nil,
			}
		})
	end)

	MachineManager.ReleaseMachine(2, "Win", player)

	return true, nil
end

function MinigameValidators.StartTargetPracticeSession(player: Player, difficulty: number): (string, { TargetCount: number, TargetLifespan: number, PenaltyDecoyCount: number })
	local levelData = MinigameLevelsData.GetLevel(3, difficulty)
	local tpConfig = levelData and levelData.Specific.TargetPractice or { TargetCount = 6, TargetLifespan = 2.5, PenaltyDecoyCount = 0 }

	local token = HttpService:GenerateGUID(false)
	activeSessions[player] = {
		Token = token,
		Player = player,
		MachineId = 3,
		Difficulty = difficulty,
		StartTime = os.clock(),
		Data = tpConfig,
	}

	return token, tpConfig
end

function MinigameValidators.ValidateTargetPracticeSubmission(
	player: Player,
	difficulty: number,
	timeSpent: number,
	clientToken: string,
	targetsHit: number,
	penaltyHits: number
): (boolean, string?)
	local session = activeSessions[player]
	if not session or session.MachineId ~= 3 then
		return false, "No active Target Practice session found"
	end

	if clientToken ~= session.Token then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(3, "InvalidToken", player)
		return false, "Token mismatch"
	end

	local levelData = MinigameLevelsData.GetLevel(3, difficulty)
	local tpConfig = levelData and levelData.Specific.TargetPractice or { TargetCount = 6, TargetLifespan = 2.5, PenaltyDecoyCount = 0 }

	-- In high difficulties (d >= 4), hitting penalty decoys fails the attempt
	if difficulty >= 4 and penaltyHits > 0 then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(3, "PenaltyDecoyHit", player)
		return false, "Failed: Hit penalty decoy target"
	end

	if targetsHit < tpConfig.TargetCount then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(3, "TargetsInsufficient", player)
		return false, string.format("Targets hit (%d) < required (%d)", targetsHit, tpConfig.TargetCount)
	end

	local minTime = if levelData then levelData.MinPhysicalTime else 3.0

	local isValidSec, secErr = SecurityValidator.ValidateMinigameResult(
		player,
		3,
		difficulty,
		timeSpent,
		clientToken,
		session.Token,
		minTime
	)
	if not isValidSec then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(3, "SpeedhackCheckFailed", player)
		return false, secErr
	end

	activeSessions[player] = nil
	local _, msg = ProgressionService.RecordWin(player, 3, difficulty)
	local _, streakMult = StreakService.IncrementStreak(player)
	local baseReward = ShopConfig.WinRewardCredits
	local finalCredits = math.floor(baseReward * streakMult)
	ShopService.AddCredits(player, finalCredits)

	local levelReward = MachinesConfig.GetReward(3, difficulty)
	if levelReward and levelReward.WeaponId then
		InventoryService.AddReward(player, 3, difficulty, levelReward.WeaponId)
	else
		InventoryService.AddReward(player, 3, difficulty, nil)
	end

	pcall(function()
		local syncRemote = Network.GetRemote("SyncState")
		syncRemote:FireClient(player, {
			MachineId = 3,
			Level = difficulty,
			WinCelebration = {
				MachineId = 3,
				Difficulty = difficulty,
				Message = msg or string.format("¡Máquina 3 Nivel %d superado!", difficulty),
				RewardWeapon = levelReward and levelReward.WeaponId or nil,
			}
		})
	end)

	MachineManager.ReleaseMachine(3, "Win", player)

	return true, nil
end

type GridCoord = { x: number, y: number }

function MinigameValidators.StartMemoryMatrixSession(
	player: Player,
	difficulty: number
): (string, { Sequence: { GridCoord }, FlashDuration: number, PathLength: number })
	local levelData = MinigameLevelsData.GetLevel(4, difficulty)
	local mmConfig = levelData and levelData.Specific.MemoryMatrix or { PathLength = 4, FlashDuration = 1.0 }

	-- Cartesian product G = {1, 2, 3, 4} x {1, 2, 3, 4}
	-- Directed path sequence P_seq = <g_1, ..., g_Ld>
	local sequence: { GridCoord } = {}
	for _ = 1, mmConfig.PathLength do
		table.insert(sequence, {
			x = math.random(1, 4),
			y = math.random(1, 4),
		})
	end

	local token = HttpService:GenerateGUID(false)
	activeSessions[player] = {
		Token = token,
		Player = player,
		MachineId = 4,
		Difficulty = difficulty,
		StartTime = os.clock(),
		Data = {
			Sequence = sequence,
			FlashDuration = mmConfig.FlashDuration,
			PathLength = mmConfig.PathLength,
		},
	}

	return token, {
		Sequence = sequence,
		FlashDuration = mmConfig.FlashDuration,
		PathLength = mmConfig.PathLength,
	}
end

function MinigameValidators.ValidateMemoryMatrixSubmission(
	player: Player,
	difficulty: number,
	timeSpent: number,
	clientToken: string,
	playerSequence: { GridCoord }
): (boolean, string?)
	local session = activeSessions[player]
	if not session or session.MachineId ~= 4 then
		return false, "No active Memory Matrix session found"
	end

	if clientToken ~= session.Token then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(4, "InvalidToken", player)
		return false, "Token mismatch"
	end

	local expectedSeq: { GridCoord } = session.Data.Sequence

	if #playerSequence ~= #expectedSeq then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(4, "WrongSequenceLength", player)
		return false, string.format("Sequence length mismatch: expected %d, got %d", #expectedSeq, #playerSequence)
	end

	for i = 1, #expectedSeq do
		local exp = expectedSeq[i]
		local got = playerSequence[i]
		if not got or got.x ~= exp.x or got.y ~= exp.y then
			activeSessions[player] = nil
			MachineManager.ReleaseMachine(4, "WrongSequenceStep", player)
			return false, string.format("Step %d incorrect: expected (%d,%d), got (%s,%s)", i, exp.x, exp.y, tostring(got and got.x), tostring(got and got.y))
		end
	end

	local levelData = MinigameLevelsData.GetLevel(4, difficulty)
	local minTime = if levelData then levelData.MinPhysicalTime else 3.5

	local isValidSec, secErr = SecurityValidator.ValidateMinigameResult(
		player,
		4,
		difficulty,
		timeSpent,
		clientToken,
		session.Token,
		minTime
	)
	if not isValidSec then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(4, "SpeedhackCheckFailed", player)
		return false, secErr
	end

	activeSessions[player] = nil
	local _, msg = ProgressionService.RecordWin(player, 4, difficulty)
	local _, streakMult = StreakService.IncrementStreak(player)
	local baseReward = ShopConfig.WinRewardCredits
	local finalCredits = math.floor(baseReward * streakMult)
	ShopService.AddCredits(player, finalCredits)

	local levelReward = MachinesConfig.GetReward(4, difficulty)
	if levelReward and levelReward.WeaponId then
		InventoryService.AddReward(player, 4, difficulty, levelReward.WeaponId)
	else
		InventoryService.AddReward(player, 4, difficulty, nil)
	end

	pcall(function()
		local syncRemote = Network.GetRemote("SyncState")
		syncRemote:FireClient(player, {
			MachineId = 4,
			Level = difficulty,
			WinCelebration = {
				MachineId = 4,
				Difficulty = difficulty,
				Message = msg or string.format("¡Máquina 4 Nivel %d superado!", difficulty),
				RewardWeapon = levelReward and levelReward.WeaponId or nil,
			}
		})
	end)

	MachineManager.ReleaseMachine(4, "Win", player)
	return true, nil
end

function MinigameValidators.StartBulletHellSession(
	player: Player,
	difficulty: number
): (string, { ProjectileCount: number, PatternType: string, SurvivalDuration: number })
	local levelData = MinigameLevelsData.GetLevel(5, difficulty)
	local bhConfig = levelData and levelData.Specific.BulletHell or {
		ProjectileCount = 4,
		PatternType = "Linear",
		SurvivalDuration = 15,
	}

	local token = HttpService:GenerateGUID(false)
	activeSessions[player] = {
		Token = token,
		Player = player,
		MachineId = 5,
		Difficulty = difficulty,
		StartTime = os.clock(),
		Data = bhConfig,
	}

	return token, {
		ProjectileCount = bhConfig.ProjectileCount,
		PatternType = bhConfig.PatternType,
		SurvivalDuration = bhConfig.SurvivalDuration,
	}
end

function MinigameValidators.ValidateBulletHellSubmission(
	player: Player,
	difficulty: number,
	timeSpent: number,
	clientToken: string,
	survived: boolean,
	hitDetected: boolean
): (boolean, string?)
	local session = activeSessions[player]
	if not session or session.MachineId ~= 5 then
		return false, "No active Bullet Hell session found"
	end

	if hitDetected or not survived then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(5, "ProjectileCollision", player)
		return false, "Failed: Hit by projectile"
	end

	local levelData = MinigameLevelsData.GetLevel(5, difficulty)
	local minTime = if levelData then levelData.MinPhysicalTime else 15.0

	local isValidSec, secErr = SecurityValidator.ValidateMinigameResult(
		player,
		5,
		difficulty,
		timeSpent,
		clientToken,
		session.Token,
		minTime
	)
	if not isValidSec then
		activeSessions[player] = nil
		MachineManager.ReleaseMachine(5, "SpeedhackCheckFailed", player)
		return false, secErr
	end

	activeSessions[player] = nil
	local _, msg = ProgressionService.RecordWin(player, 5, difficulty)
	local _, streakMult = StreakService.IncrementStreak(player)
	local baseReward = ShopConfig.WinRewardCredits
	local finalCredits = math.floor(baseReward * streakMult)
	ShopService.AddCredits(player, finalCredits)

	local levelReward = MachinesConfig.GetReward(5, difficulty)
	if levelReward and levelReward.WeaponId then
		InventoryService.AddReward(player, 5, difficulty, levelReward.WeaponId)
	else
		InventoryService.AddReward(player, 5, difficulty, nil)
	end

	pcall(function()
		local syncRemote = Network.GetRemote("SyncState")
		syncRemote:FireClient(player, {
			MachineId = 5,
			Level = difficulty,
			WinCelebration = {
				MachineId = 5,
				Difficulty = difficulty,
				Message = msg or string.format("¡Máquina 5 Nivel %d superado!", difficulty),
				RewardWeapon = levelReward and levelReward.WeaponId or nil,
			}
		})
	end)

	MachineManager.ReleaseMachine(5, "Win", player)
	return true, nil
end

function MinigameValidators.GetActiveSession(player: Player): Session?
	return activeSessions[player]
end

function MinigameValidators.ClearSession(player: Player)
	activeSessions[player] = nil
end

function MinigameValidators.Init()
	Network.InitializeRemotes()

	MachineManager.RegisterSessionStarter(1, function(player: Player, difficulty: number)
		return MinigameValidators.StartQTESession(player, difficulty)
	end)
	MachineManager.RegisterSessionStarter(2, function(player: Player, difficulty: number)
		return MinigameValidators.StartLaserGridSession(player, difficulty)
	end)
	MachineManager.RegisterSessionStarter(3, function(player: Player, difficulty: number)
		return MinigameValidators.StartTargetPracticeSession(player, difficulty)
	end)
	MachineManager.RegisterSessionStarter(4, function(player: Player, difficulty: number)
		return MinigameValidators.StartMemoryMatrixSession(player, difficulty)
	end)
	MachineManager.RegisterSessionStarter(5, function(player: Player, difficulty: number)
		return MinigameValidators.StartBulletHellSession(player, difficulty)
	end)

	local submitRemote = Network.GetRemote("SubmitMinigameResult")
	submitRemote.OnServerEvent:Connect(function(player: Player, machineId: any, difficulty: any, timeSpent: any, token: any, payload: any)
		if machineId == 1 and typeof(difficulty) == "number" and typeof(timeSpent) == "number" and typeof(token) == "string" and typeof(payload) == "table" then
			local inputs = payload.Inputs or {}
			local pressedTraps = payload.PressedTraps or false
			MinigameValidators.ValidateQTESubmission(player, difficulty, timeSpent, token, inputs, pressedTraps)
		elseif machineId == 2 and typeof(difficulty) == "number" and typeof(timeSpent) == "number" and typeof(token) == "string" and typeof(payload) == "table" then
			local reachedGoal = payload.ReachedGoal == true
			local touchedLaser = payload.TouchedLaser == true
			MinigameValidators.ValidateLaserGridSubmission(player, difficulty, timeSpent, token, reachedGoal, touchedLaser)
		elseif machineId == 3 and typeof(difficulty) == "number" and typeof(timeSpent) == "number" and typeof(token) == "string" and typeof(payload) == "table" then
			local targetsHit = payload.TargetsHit or 0
			local penaltyHits = payload.PenaltyHits or 0
			MinigameValidators.ValidateTargetPracticeSubmission(player, difficulty, timeSpent, token, targetsHit, penaltyHits)
		elseif machineId == 4 and typeof(difficulty) == "number" and typeof(timeSpent) == "number" and typeof(token) == "string" and typeof(payload) == "table" then
			local playerSequence = payload.PlayerSequence or {}
			MinigameValidators.ValidateMemoryMatrixSubmission(player, difficulty, timeSpent, token, playerSequence)
		elseif machineId == 5 and typeof(difficulty) == "number" and typeof(timeSpent) == "number" and typeof(token) == "string" and typeof(payload) == "table" then
			local survived = payload.Survived == true
			local hitDetected = payload.HitDetected == true
			MinigameValidators.ValidateBulletHellSubmission(player, difficulty, timeSpent, token, survived, hitDetected)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		MinigameValidators.ClearSession(player)
	end)
end

return MinigameValidators
