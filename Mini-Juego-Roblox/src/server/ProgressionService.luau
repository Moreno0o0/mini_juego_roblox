--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CollisionManager = require(ServerScriptService.Server.CollisionManager)
local Network = require(ReplicatedStorage.Shared.Network)

local ProgressionService = {}

-- Function Prog: P x M -> {0, 1, 2, 3, 4, 5}
-- [Player][MachineId] -> level (0..5)
local playerProgress: { [Player]: { [number]: number } } = {}

function ProgressionService.InitPlayer(player: Player)
	if playerProgress[player] then
		return
	end
	playerProgress[player] = {
		[1] = 0,
		[2] = 0,
		[3] = 0,
		[4] = 0,
		[5] = 0,
	}
end

function ProgressionService.GetProgress(player: Player, machineId: number): number
	local prog = playerProgress[player]
	if not prog then
		return 0
	end
	return prog[machineId] or 0
end

function ProgressionService.SetProgress(player: Player, machineId: number, level: number)
	ProgressionService.InitPlayer(player)
	local clamped = math.clamp(level, 0, 5)
	playerProgress[player][machineId] = clamped

	-- Update collision group on character if present
	local highestZone = ProgressionService.GetHighestUnlockedZone(player)
	if player:IsA("Player") and player.Character then
		CollisionManager.ApplyPlayerCollisionGroup(player.Character, highestZone)
	end

	-- Notify client with new highest zone and progress
	pcall(function()
		local syncRemote = Network.GetRemote("SyncState")
		syncRemote:FireClient(player, {
			MachineId = machineId,
			Level = clamped,
			HighestZone = highestZone,
			AllProgress = ProgressionService.GetAllProgress(player),
		})
	end)
end

function ProgressionService.GetHighestUnlockedZone(player: Player): number
	ProgressionService.InitPlayer(player)
	local highest = 1
	for m = 1, 4 do
		if ProgressionService.GetProgress(player, m) >= 1 then
			highest = m + 1
		else
			break
		end
	end
	return highest
end

function ProgressionService.HasAccess(player: Player, machineId: number): boolean
	if machineId < 1 or machineId > 5 then
		return false
	end
	-- (p, m_k) in Access <=> (k = 1) or (k > 1 and Prog(p, m_{k-1}) >= 1)
	if machineId == 1 then
		return true
	end
	return ProgressionService.GetProgress(player, machineId - 1) >= 1
end

function ProgressionService.CanCrossGate(player: Player, gateIndex: number): boolean
	if gateIndex < 1 or gateIndex > 4 then
		return false
	end
	-- Crossing gate k -> k+1 requires Prog(p, m_k) >= 1 (Superar la máquina desbloquea la siguiente sala)
	return ProgressionService.GetProgress(player, gateIndex) >= 1
end

function ProgressionService.RecordWin(player: Player, machineId: number, difficulty: number): (boolean, string?)
	if not ProgressionService.HasAccess(player, machineId) then
		return false, "Player does not have access to machine " .. machineId
	end

	local current = ProgressionService.GetProgress(player, machineId)
	if difficulty == current + 1 then
		ProgressionService.SetProgress(player, machineId, difficulty)

		local message = string.format("Progreso actualizado: Máquina %d nivel %d/5", machineId, difficulty)
		if difficulty >= 1 and machineId < 5 then
			message ..= string.format(" ¡Compuerta a Zona %d desbloqueada!", machineId + 1)
		end
		return true, message
	elseif difficulty <= current then
		return true, "Nivel ya superado anteriormente"
	else
		return false, string.format("Prerrequisito no cumplido: nivel actual es %d, no puede saltar a %d", current, difficulty)
	end
end

function ProgressionService.GetAllProgress(player: Player): { [number]: number }
	ProgressionService.InitPlayer(player)
	local copy: { [number]: number } = {}
	for m = 1, 5 do
		copy[m] = playerProgress[player][m]
	end
	return copy
end

function ProgressionService.Init()
	Network.InitializeRemotes()

	Players.PlayerAdded:Connect(function(player: Player)
		ProgressionService.InitPlayer(player)
		player.CharacterAdded:Connect(function(char: Model)
			local highest = ProgressionService.GetHighestUnlockedZone(player)
			CollisionManager.ApplyPlayerCollisionGroup(char, highest)

			task.delay(0.6, function()
				if player and player.Parent then
					pcall(function()
						local syncRemote = Network.GetRemote("SyncState")
						syncRemote:FireClient(player, {
							HighestZone = highest,
							AllProgress = ProgressionService.GetAllProgress(player),
						})
					end)
				end
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		playerProgress[player] = nil
	end)
end

return ProgressionService
