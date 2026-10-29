--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local SetUtils = require(ReplicatedStorage.Shared.SetUtils)
local Network = require(ReplicatedStorage.Shared.Network)

type Set<T> = Types.Set<T>
type PlayerState = Types.PlayerState

local PlayerStateService = {}

-- Universe P of active players
local P: Set<Player> = {}

-- Disjoint State Subsets
local S_Combat: Set<Player> = {}
local S_Capturing: Set<Player> = {}
local S_Playing: Set<Player> = {}
local S_Immunity: Set<Player> = {}
local S_Dead: Set<Player> = {}

-- Active immunity timers
local immunityTokens: { [Player]: number } = {}

-- Active force fields per player
local activeForceFields: { [Player]: ForceField } = {}

-- State mapping for quick lookup
local playerCurrentState: { [Player]: PlayerState } = {}

local function GetSubsetsList(): { Set<Player> }
	return { S_Combat, S_Capturing, S_Playing, S_Immunity, S_Dead }
end

function PlayerStateService.VerifyPartition(): boolean
	return SetUtils.VerifyPartition(P, GetSubsetsList())
end

function PlayerStateService.GetPlayerState(player: Player): PlayerState?
	return playerCurrentState[player]
end

function PlayerStateService.GetActivePlayers(): Set<Player>
	return P
end

function PlayerStateService.GetCombatSet(): Set<Player>
	return S_Combat
end

function PlayerStateService.GetCapturingSet(): Set<Player>
	return S_Capturing
end

function PlayerStateService.GetPlayingSet(): Set<Player>
	return S_Playing
end

function PlayerStateService.GetImmunitySet(): Set<Player>
	return S_Immunity
end

function PlayerStateService.GetDeadSet(): Set<Player>
	return S_Dead
end

local function SetSubset(state: PlayerState, newSet: Set<Player>)
	if state == "Combat" then
		S_Combat = newSet
	elseif state == "Capturing" then
		S_Capturing = newSet
	elseif state == "Playing" then
		S_Playing = newSet
	elseif state == "Immunity" then
		S_Immunity = newSet
	elseif state == "Dead" then
		S_Dead = newSet
	end
end

local function GetSubset(state: PlayerState): Set<Player>
	if state == "Combat" then
		return S_Combat
	elseif state == "Capturing" then
		return S_Capturing
	elseif state == "Playing" then
		return S_Playing
	elseif state == "Immunity" then
		return S_Immunity
	elseif state == "Dead" then
		return S_Dead
	end
	error("Unknown state: " .. tostring(state))
end

function PlayerStateService.AddPlayer(player: Player)
	if P[player] then
		return
	end

	-- Add to Universe P
	P[player] = true

	-- Add to S_Combat
	local single = { [player] = true }
	S_Combat = SetUtils.Union(S_Combat, single)
	playerCurrentState[player] = "Combat"

	assert(PlayerStateService.VerifyPartition(), "Partition invariant violated after AddPlayer")
end

function PlayerStateService.RemovePlayer(player: Player)
	if not P[player] then
		return
	end

	-- Invalidate immunity timer
	immunityTokens[player] = nil

	-- Remove ForceField if any
	local ff = activeForceFields[player]
	if ff then
		ff:Destroy()
		activeForceFields[player] = nil
	end

	local currentState: PlayerState? = playerCurrentState[player]
	if currentState ~= nil then
		local state: PlayerState = currentState
		local targetSubset = GetSubset(state)
		SetSubset(state, SetUtils.Difference(targetSubset, { [player] = true }))
		playerCurrentState[player] = nil
	end

	-- Remove from Universe P
	P = SetUtils.Difference(P, { [player] = true })

	assert(PlayerStateService.VerifyPartition(), "Partition invariant violated after RemovePlayer")
end

function PlayerStateService.Transition(player: Player, toState: PlayerState): boolean
	if not P[player] then
		return false
	end

	local fromState: PlayerState? = playerCurrentState[player]
	if fromState == nil then
		return false
	end
	local validFromState: PlayerState = fromState
	if validFromState == toState then
		return true
	end

	-- Atomic set transition: S_from \ {p} and S_to U {p}
	local single = { [player] = true }
	local fromSet = GetSubset(validFromState)
	local toSet = GetSubset(toState)

	SetSubset(validFromState, SetUtils.Difference(fromSet, single))
	SetSubset(toState, SetUtils.Union(toSet, single))
	playerCurrentState[player] = toState

	-- Check partition invariant immediately
	assert(PlayerStateService.VerifyPartition(), string.format("Partition invariant violated during transition %s -> %s", validFromState, toState))

	-- Manage Side Effects safely
	local char: Model? = nil
	local ok, retrievedChar = pcall(function()
		return player.Character
	end)
	if ok and typeof(retrievedChar) == "Instance" and retrievedChar:IsA("Model") then
		char = retrievedChar
	end

	-- Leaving Immunity: invalidate immunity timer so it does not interrupt Playing or Combat
	if fromState == "Immunity" then
		immunityTokens[player] = (immunityTokens[player] or 0) + 1
		if toState ~= "Playing" then
			local ff = activeForceFields[player]
			if ff then
				ff:Destroy()
				activeForceFields[player] = nil
			end
		end
	end

	-- 1. Entering S_Playing: unequip tools and apply ForceField
	if toState == "Playing" then
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
			if not activeForceFields[player] then
				local ff = Instance.new("ForceField")
				ff.Name = "PlayingProtection"
				ff.Visible = true
				ff.Parent = char
				activeForceFields[player] = ff
			else
				activeForceFields[player].Name = "PlayingProtection"
			end
		end
	end

	-- 2. Exiting S_Playing: remove ForceField
	if fromState == "Playing" and toState ~= "Immunity" then
		local ff = activeForceFields[player]
		if ff then
			ff:Destroy()
			activeForceFields[player] = nil
		end
	end

	-- 3. Entering S_Immunity: apply 10-second timer and protection
	if toState == "Immunity" then
		-- Keep or create ForceField for immunity visual
		if char and not activeForceFields[player] then
			local ff = Instance.new("ForceField")
			ff.Name = "ImmunityProtection"
			ff.Visible = true
			ff.Parent = char
			activeForceFields[player] = ff
		end

		local token = (immunityTokens[player] or 0) + 1
		immunityTokens[player] = token

		task.delay(10.0, function()
			-- Invariant: Transition back to Combat if player is still in Immunity and token matches
			if immunityTokens[player] == token and playerCurrentState[player] == "Immunity" then
				local ff = activeForceFields[player]
				if ff then
					ff:Destroy()
					activeForceFields[player] = nil
				end
				PlayerStateService.Transition(player, "Combat")
			end
		end)
	end

	-- Sync state to client
	pcall(function()
		local syncRemote = Network.GetRemote("SyncState")
		syncRemote:FireClient(player, toState, { PreviousState = validFromState })
	end)

	return true
end

function PlayerStateService.Init()
	Players.PlayerAdded:Connect(function(player: Player)
		PlayerStateService.AddPlayer(player)

		player.CharacterAdded:Connect(function(character: Model)
			-- Reset player to combat upon respawn
			if playerCurrentState[player] == "Dead" then
				PlayerStateService.Transition(player, "Combat")
			end

			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				PlayerStateService.Transition(player, "Dead")
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		PlayerStateService.RemovePlayer(player)
	end)
end

return PlayerStateService
