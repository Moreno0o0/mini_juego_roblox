--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type ClientToServerEvent =
	| "RequestCapture"
	| "SubmitMinigameResult"
	| "RequestAttack"
	| "RequestEquip"
	| "RequestZoneChange"
	| "RequestShopPurchase"
	| "CollectArenaCoin"
	| "RequestCombatAction"

export type ServerToClientEvent =
	| "SyncState"
	| "StartMinigameClient"
	| "ForceExitMachine"
	| "CombatFeedback"
	| "ShopPurchaseResult"
	| "StreakUpdated"
	| "ArenaEventTriggered"
	| "PlayClientSound"

local ClientToServerEvents = {
	"RequestCapture",
	"SubmitMinigameResult",
	"RequestAttack",
	"RequestEquip",
	"RequestZoneChange",
	"RequestShopPurchase",
	"CollectArenaCoin",
	"RequestCombatAction",
}

local ServerToClientEvents = {
	"SyncState",
	"StartMinigameClient",
	"ForceExitMachine",
	"CombatFeedback",
	"ShopPurchaseResult",
	"StreakUpdated",
	"ArenaEventTriggered",
	"PlayClientSound",
}

local Network = {}
local remotesFolder: Folder? = nil

function Network.GetRemotesFolder(): Folder
	if remotesFolder then
		return remotesFolder
	end

	local existing = ReplicatedStorage:FindFirstChild("Network")
	if existing and existing:IsA("Folder") then
		remotesFolder = existing
		return existing
	end

	if RunService:IsServer() or not RunService:IsRunning() then
		local folder = Instance.new("Folder")
		folder.Name = "Network"
		folder.Parent = ReplicatedStorage
		remotesFolder = folder
		return folder
	else
		local found = ReplicatedStorage:WaitForChild("Network", 10)
		assert(found and found:IsA("Folder"), "Network folder could not be found in ReplicatedStorage")
		remotesFolder = found
		return found
	end
end

function Network.GetRemote(name: string): RemoteEvent
	local folder = Network.GetRemotesFolder()
	local remote = folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if RunService:IsServer() or not RunService:IsRunning() then
		local newRemote = Instance.new("RemoteEvent")
		newRemote.Name = name
		newRemote.Parent = folder
		return newRemote
	else
		local found = folder:WaitForChild(name, 10)
		assert(found and found:IsA("RemoteEvent"), "RemoteEvent not found: " .. name)
		return found
	end
end

function Network.InitializeRemotes()
	local folder = Network.GetRemotesFolder()
	for _, eventName in ipairs(ClientToServerEvents) do
		if not folder:FindFirstChild(eventName) then
			local r = Instance.new("RemoteEvent")
			r.Name = eventName
			r.Parent = folder
		end
	end
	for _, eventName in ipairs(ServerToClientEvents) do
		if not folder:FindFirstChild(eventName) then
			local r = Instance.new("RemoteEvent")
			r.Name = eventName
			r.Parent = folder
		end
	end
end

return Network
