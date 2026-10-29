--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Shared.Types)
local ProgressionService = require(ServerScriptService.Server.ProgressionService)
local InventoryService = require(ServerScriptService.Server.InventoryService)
local CollisionManager = require(ServerScriptService.Server.CollisionManager)

export type SerializedProfile = {
	Version: number,
	Progress: { [string]: number }, -- ["1"]..["5"]
	Inventory: { [string]: boolean }, -- ["w_0"]..["w_5b"]
	History: { [string]: boolean }, -- ["1_1"]..["5_5"]
	EquippedWeapon: string,
	LastSaved: number,
}

local DATA_VERSION = 1
local DATA_STORE_NAME = "CompetitiveMinigameData_v1"

local DataService = {}

function DataService.SetDependencies(prog: any, inv: any)
	ProgressionService = prog
	InventoryService = inv
end

-- In-memory cache and mock store for Studio / offline resiliency
local cachedProfiles: { [Player]: SerializedProfile } = {}
local mockDataStore: { [string]: SerializedProfile } = {}

-- Safe retrieval of real DataStore (or nil if API is disabled)
local realDataStore: GlobalDataStore? = nil
pcall(function()
	if not RunService:IsStudio() then
		realDataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
	else
		-- In Studio, test if API access is permitted
		local testStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
		testStore:GetAsync("__test_ping__")
		realDataStore = testStore
	end
end)

-- Bijective Serialization: (Prog: M -> D, Inv subset of W, H subset of M x D, eq in W) -> SerializedProfile
function DataService.Serialize(
	progress: { [number]: number },
	inventory: { [string]: boolean },
	history: { [string]: boolean },
	equippedWeapon: string
): SerializedProfile
	local stringKeyProgress: { [string]: number } = {}
	for m = 1, 5 do
		stringKeyProgress[tostring(m)] = progress[m] or 0
	end

	return {
		Version = DATA_VERSION,
		Progress = stringKeyProgress,
		Inventory = table.clone(inventory),
		History = table.clone(history),
		EquippedWeapon = equippedWeapon,
		LastSaved = os.time(),
	}
end

-- Bijective Deserialization: SerializedProfile -> (Prog, Inv, H, eq)
function DataService.Deserialize(
	profile: SerializedProfile
): ({ [number]: number }, { [string]: boolean }, { [string]: boolean }, string)
	local numericProgress: { [number]: number } = {}
	for m = 1, 5 do
		local strVal = profile.Progress[tostring(m)]
		numericProgress[m] = if typeof(strVal) == "number" then strVal else 0
	end

	local inventory = table.clone(profile.Inventory or { w_0 = true })
	local history = table.clone(profile.History or {})
	local equipped = profile.EquippedWeapon or "w_0"

	return numericProgress, inventory, history, equipped
end

function DataService.GetDefaultProfile(): SerializedProfile
	return {
		Version = DATA_VERSION,
		Progress = {
			["1"] = 0,
			["2"] = 0,
			["3"] = 0,
			["4"] = 0,
			["5"] = 0,
		},
		Inventory = {
			w_0 = true,
		},
		History = {},
		EquippedWeapon = "w_0",
		LastSaved = os.time(),
	}
end

local function GetPlayerUserIdStr(player: Player): string
	local ok, uid = pcall(function()
		return player.UserId
	end)
	if ok and uid ~= nil then
		return tostring(uid)
	end
	local attr = player:GetAttribute("UserId")
	if attr ~= nil then
		return tostring(attr)
	end
	return "0"
end

function DataService.LoadProfile(player: Player): (boolean, SerializedProfile)
	local userIdStr = GetPlayerUserIdStr(player)
	local loadedProfile: SerializedProfile? = nil

	if realDataStore then
		local success, result = pcall(function()
			return (realDataStore :: GlobalDataStore):GetAsync(userIdStr)
		end)
		if success and typeof(result) == "table" and result.Version ~= nil then
			loadedProfile = result :: SerializedProfile
		end
	end

	-- Fallback to Mock Store if real DataStore is unavailable or empty
	if not loadedProfile then
		loadedProfile = mockDataStore[userIdStr] or DataService.GetDefaultProfile()
	end

	local profile = loadedProfile :: SerializedProfile
	cachedProfiles[player] = profile

	-- Restore state into authoritative game services
	local prog, inv, hist, equipped = DataService.Deserialize(profile)

	for m = 1, 5 do
		ProgressionService.SetProgress(player, m, prog[m] or 0)
	end

	InventoryService.SetInventory(player, inv, hist, equipped :: Types.WeaponId)

	-- Update collision groups and unlock gates
	local highestZone = ProgressionService.GetHighestUnlockedZone(player)
	if player:IsA("Player") and player.Character then
		CollisionManager.ApplyPlayerCollisionGroup(player.Character, highestZone)
		InventoryService.GiveToolToCharacter(player, equipped :: Types.WeaponId)
	end

	return true, profile
end

function DataService.SaveProfile(player: Player): (boolean, string?)
	local prog = ProgressionService.GetAllProgress(player)
	local inv = InventoryService.GetInventory(player)
	local hist = InventoryService.GetHistory(player)
	local equipped = InventoryService.GetEquippedWeapon(player)

	local serialized = DataService.Serialize(prog, inv, hist, equipped)
	cachedProfiles[player] = serialized

	local userIdStr = GetPlayerUserIdStr(player)
	mockDataStore[userIdStr] = serialized

	if realDataStore then
		local success, err = pcall(function()
			(realDataStore :: GlobalDataStore):SetAsync(userIdStr, serialized)
		end)
		if not success then
			return false, tostring(err)
		end
	end

	return true, nil
end

function DataService.GetCachedProfile(player: Player): SerializedProfile?
	return cachedProfiles[player]
end

function DataService.SetMockProfile(userId: number, profile: SerializedProfile)
	mockDataStore[tostring(userId)] = profile
end

function DataService.GetMockProfile(userId: number): SerializedProfile?
	return mockDataStore[tostring(userId)]
end

function DataService.Init()
	Players.PlayerAdded:Connect(function(player: Player)
		DataService.LoadProfile(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		DataService.SaveProfile(player)
		cachedProfiles[player] = nil
	end)

	-- Server shutdown: BindToClose
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.SaveProfile(player)
		end
	end)
end

return DataService
