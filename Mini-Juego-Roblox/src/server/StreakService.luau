--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)

local StreakService = {}

local playerStreaks: { [Player]: number } = {}

local function CalculateMultiplier(streak: number): number
	if streak <= 1 then
		return 1.0
	elseif streak == 2 then
		return 1.25
	elseif streak == 3 then
		return 1.5
	elseif streak == 4 then
		return 1.75
	else
		return 2.0
	end
end

function StreakService.GetStreak(player: Player): number
	return playerStreaks[player] or 0
end

function StreakService.GetMultiplier(player: Player): number
	local streak = StreakService.GetStreak(player)
	return CalculateMultiplier(streak)
end

function StreakService.IncrementStreak(player: Player): (number, number)
	local current = StreakService.GetStreak(player)
	local nextVal = current + 1
	playerStreaks[player] = nextVal
	local mult = CalculateMultiplier(nextVal)

	pcall(function()
		local remote = Network.GetRemote("StreakUpdated")
		remote:FireClient(player, {
			Streak = nextVal,
			Multiplier = mult,
			IsIncrement = true,
		})

		local soundRemote = Network.GetRemote("PlayClientSound")
		soundRemote:FireClient(player, "StreakUp", 1.0 + (nextVal * 0.1))

		-- Server-wide announcement for epic streaks (>= 3)
		if nextVal >= 3 then
			local syncRemote = Network.GetRemote("SyncState")
			syncRemote:FireAllClients({
				Notification = string.format("🔥 ¡%s alcanzó una RACHA DE VICTORIAS x%d!", player.DisplayName, nextVal),
			})
		end
	end)

	return nextVal, mult
end

function StreakService.ResetStreak(player: Player)
	local current = playerStreaks[player] or 0
	playerStreaks[player] = 0

	pcall(function()
		local remote = Network.GetRemote("StreakUpdated")
		remote:FireClient(player, {
			Streak = 0,
			Multiplier = 1.0,
			IsIncrement = false,
		})

		if current >= 2 then
			local soundRemote = Network.GetRemote("PlayClientSound")
			soundRemote:FireClient(player, "Defeat", 0.7)
		end
	end)
end

function StreakService.Init()
	Players.PlayerAdded:Connect(function(player)
		playerStreaks[player] = 0
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerStreaks[player] = nil
	end)
end

return StreakService
