--!strict
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SetUtils = require(ReplicatedStorage.Shared.SetUtils)

local CollisionManager = {}

-- Bit definitions for Universe U = {0..31}
CollisionManager.PLAYER_LAYER = 32 -- Bit 5 (2^5)
CollisionManager.GATE_LAYERS = {
	[1] = 2, -- Gate_1_2: Bit 1 (2^1)
	[2] = 4, -- Gate_2_3: Bit 2 (2^2)
	[3] = 8, -- Gate_3_4: Bit 3 (2^3)
	[4] = 16, -- Gate_4_5: Bit 4 (2^4)
}

local GATE_NAMES = {
	[1] = "Gate_1_2",
	[2] = "Gate_2_3",
	[3] = "Gate_3_4",
	[4] = "Gate_4_5",
}

local initialized = false

local function SafeRegisterGroup(groupName: string)
	local success, _ = pcall(function()
		PhysicsService:RegisterCollisionGroup(groupName)
	end)
	return success
end

function CollisionManager.CalculatePlayerMask(highestUnlockedZone: number): number
	local mask = 0
	-- A player with highestUnlockedZone = k collides with all gates where gateIndex >= k
	for gateIndex = 1, 4 do
		if gateIndex >= highestUnlockedZone then
			mask = bit32.bor(mask, CollisionManager.GATE_LAYERS[gateIndex])
		end
	end
	return mask
end

function CollisionManager.CanPlayerCollideWithGate(highestUnlockedZone: number, gateIndex: number): boolean
	local playerLayer = CollisionManager.PLAYER_LAYER
	local playerMask = CollisionManager.CalculatePlayerMask(highestUnlockedZone)
	local gateLayer = CollisionManager.GATE_LAYERS[gateIndex] or 0
	local gateMask = 0 -- Gate collision is governed by the player's access mask

	return SetUtils.BitmaskCanCollide(playerLayer, playerMask, gateLayer, gateMask)
end

function CollisionManager.Init()
	if initialized then
		return
	end
	initialized = true

	-- Register Gate collision groups
	for _, gateName in ipairs(GATE_NAMES) do
		SafeRegisterGroup(gateName)
	end

	-- Register Player Tier collision groups (1 to 5)
	for tier = 1, 5 do
		local groupName = "Players_Tier" .. tier
		SafeRegisterGroup(groupName)

		-- Players can always collide with Default geometry
		pcall(function()
			PhysicsService:CollisionGroupSetCollidable(groupName, "Default", true)
		end)

		-- Configure collidability with gates based on mathematical poset
		for gateIndex, gateName in ipairs(GATE_NAMES) do
			-- Player can collide if and only if gateIndex >= tier
			local shouldCollide = (gateIndex >= tier)
			pcall(function()
				PhysicsService:CollisionGroupSetCollidable(groupName, gateName, shouldCollide)
			end)
		end
	end
end

function CollisionManager.GetPlayerGroupName(highestUnlockedZone: number): string
	local clamped = math.clamp(highestUnlockedZone, 1, 5)
	return "Players_Tier" .. clamped
end

function CollisionManager.ApplyPlayerCollisionGroup(character: Model, highestUnlockedZone: number)
	CollisionManager.Init()
	local groupName = CollisionManager.GetPlayerGroupName(highestUnlockedZone)

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end
end

function CollisionManager.ApplyGateCollisionGroup(gateInstance: Instance, gateIndex: number)
	CollisionManager.Init()
	local groupName = GATE_NAMES[gateIndex]
	if not groupName then
		return
	end

	if gateInstance:IsA("BasePart") then
		gateInstance.CollisionGroup = groupName
	end
	for _, descendant in ipairs(gateInstance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end
end

return CollisionManager
