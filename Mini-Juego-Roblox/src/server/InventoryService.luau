--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Types = require(ReplicatedStorage.Shared.Types)
local SetUtils = require(ReplicatedStorage.Shared.SetUtils)
local WeaponsConfig = require(ReplicatedStorage.Shared.Config.WeaponsConfig)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.ZonesConfig)
local Network = require(ReplicatedStorage.Shared.Network)
local SecurityValidator = require(ServerScriptService.Server.SecurityValidator)
local ProgressionService = require(ServerScriptService.Server.ProgressionService)

type WeaponId = Types.WeaponId
type ZoneId = Types.ZoneId

local InventoryService = {}

-- Player inventory: Inv(p) subset of W
local playerInventories: { [Player]: { [string]: boolean } } = {}

-- Player cleared levels: H_p subset of M x D
local playerHistory: { [Player]: { [string]: boolean } } = {}

-- Currently equipped weapon
local equippedWeapons: { [Player]: WeaponId } = {}

function InventoryService.InitPlayer(player: Player)
	if playerInventories[player] then
		return
	end
	-- Default starter inventory: { w_0 } (Puños)
	playerInventories[player] = {
		w_0 = true,
	}
	playerHistory[player] = {}
	equippedWeapons[player] = "w_0"
end

function InventoryService.GetInventory(player: Player): { [string]: boolean }
	InventoryService.InitPlayer(player)
	return playerInventories[player]
end

function InventoryService.SetInventory(
	player: Player,
	inventory: { [string]: boolean },
	history: { [string]: boolean }?,
	equipped: WeaponId?
)
	InventoryService.InitPlayer(player)
	playerInventories[player] = table.clone(inventory)
	if history then
		playerHistory[player] = table.clone(history)
	end
	if equipped then
		equippedWeapons[player] = equipped
	end
end

function InventoryService.GetHistory(player: Player): { [string]: boolean }
	InventoryService.InitPlayer(player)
	return playerHistory[player]
end

function InventoryService.GetEquippedWeapon(player: Player): WeaponId
	InventoryService.InitPlayer(player)
	return equippedWeapons[player] or "w_0"
end

function InventoryService.HasWeapon(player: Player, weaponId: string): boolean
	local inv = InventoryService.GetInventory(player)
	return inv[weaponId] == true
end

-- Idempotent union on win: Inv'(p) = Inv(p) U { Rew(m, d) }
function InventoryService.AddReward(player: Player, machineId: number, difficulty: number, rewardWeaponId: WeaponId?)
	InventoryService.InitPlayer(player)

	-- Update history H_p' = H_p U { (m, d) }
	local levelKey = string.format("%d_%d", machineId, difficulty)
	playerHistory[player] = SetUtils.Union(playerHistory[player], { [levelKey] = true })

	-- If reward contains a weapon, idempotent union into inventory
	if rewardWeaponId then
		playerInventories[player] = SetUtils.Union(playerInventories[player], { [rewardWeaponId] = true })
	end
end

-- Can equip <=> R_w subset of H_p
function InventoryService.CanEquip(player: Player, weaponId: WeaponId): boolean
	local weapon = WeaponsConfig.Get(weaponId)
	if not weapon then
		return false
	end

	-- Must own the weapon
	if not InventoryService.HasWeapon(player, weaponId) then
		return false
	end

	-- Check prerequisites R_w subset of H_p
	local history = InventoryService.GetHistory(player)
	if not SetUtils.IsSubset(weapon.Prerequisites, history) then
		return false
	end

	return true
end

-- Anti-abuse check and auto-downgrade when stepping back into lower zones
function InventoryService.EnforceZoneWeaponRestrictions(player: Player): WeaponId
	InventoryService.InitPlayer(player)

	local rawZoneId = ZonesConfig.GetPlayerZone(player) or "Zone_1"
	local zoneId: ZoneId = rawZoneId :: ZoneId
	local zoneDef = ZonesConfig.GetById(zoneId)
	local maxAllowedTier = if zoneDef then zoneDef.Tier else 1

	local currentWeaponId: WeaponId = (equippedWeapons[player] or "w_0") :: WeaponId
	local currentWeaponDef = WeaponsConfig.Get(currentWeaponId)

	if currentWeaponDef and currentWeaponDef.Tier > maxAllowedTier then
		-- Player exceeded zone tier: Downgrade to best weapon in inventory where tier <= maxAllowedTier
		local bestWeaponDef = WeaponsConfig.GetBestWeaponForTier(playerInventories[player], maxAllowedTier)
		local newWeaponId: WeaponId = bestWeaponDef.Id :: WeaponId
		equippedWeapons[player] = newWeaponId

		-- Physically update Tool in character
		InventoryService.GiveToolToCharacter(player, newWeaponId)

		return newWeaponId
	end

	return currentWeaponId
end

function InventoryService.GiveToolToCharacter(player: Player, weaponId: WeaponId)
	local char = player.Character
	if not char then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")

	-- Remove old weapon tools from character and backpack
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") ~= nil then
			child:Destroy()
		end
	end
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("WeaponId") ~= nil then
				child:Destroy()
			end
		end
	end

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assetsFolder and assetsFolder:FindFirstChild("Weapons")
	if not weaponsFolder then
		return
	end

	-- Find matching tool template by WeaponId attribute
	for _, tool in ipairs(weaponsFolder:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("WeaponId") == weaponId then
			local clone = tool:Clone()
			clone.Parent = char
			break
		end
	end
end

function InventoryService.EquipWeapon(player: Player, weaponId: WeaponId): (boolean, string?)
	if not InventoryService.HasWeapon(player, weaponId) then
		return false, "El jugador no posee el arma " .. tostring(weaponId)
	end
	if not InventoryService.CanEquip(player, weaponId) then
		return false, "Prerrequisitos no cumplidos para equipar " .. tostring(weaponId)
	end

	-- Enforce Zone Tier Limit
	local rawZoneId = ZonesConfig.GetPlayerZone(player) or "Zone_1"
	local zoneId: ZoneId = rawZoneId :: ZoneId
	local zoneDef = ZonesConfig.GetById(zoneId)
	local maxTier = if zoneDef then zoneDef.Tier else 1

	local weaponDef = WeaponsConfig.Get(weaponId)
	if not weaponDef then
		return false, "Arma desconocida"
	end

	if weaponDef.Tier > maxTier then
		return false, string.format("El arma tier %d excede el tier máximo permitido en %s (%d)", weaponDef.Tier, zoneId, maxTier)
	end

	equippedWeapons[player] = weaponId
	InventoryService.GiveToolToCharacter(player, weaponId)

	return true, nil
end

function InventoryService.Init()
	Network.InitializeRemotes()

	Players.PlayerAdded:Connect(function(player: Player)
		InventoryService.InitPlayer(player)

		player.CharacterAdded:Connect(function()
			local activeWeapon: WeaponId = (equippedWeapons[player] or "w_0") :: WeaponId
			InventoryService.GiveToolToCharacter(player, activeWeapon)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		playerInventories[player] = nil
		playerHistory[player] = nil
		equippedWeapons[player] = nil
	end)

	-- Connect All Zone Weapon Dispensers Globally (Resilient to World Rebuilds)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if prompt.Name == "DispenserPrompt" then
			local zoneTier = prompt:GetAttribute("ZoneTier")
			local z = if typeof(zoneTier) == "number" then zoneTier else 1
			local weaponId = prompt:GetAttribute("WeaponId")
			local rawName = prompt:GetAttribute("WeaponName")
			local weaponName: string = if typeof(rawName) == "string" then rawName else "Arma"

			if typeof(weaponId) ~= "string" then
				return
			end

			local highestZone = ProgressionService.GetHighestUnlockedZone(player)
			if highestZone < z then
				pcall(function()
					local syncRemote = Network.GetRemote("SyncState")
					syncRemote:FireClient(player, {
						Notification = string.format("Acceso restringido: debes desbloquear la Zona %d primero.", z)
					})
				end)
				return
			end

			-- Unlock weapon in inventory unconditionally (Free Zone Armory Weapon)
			InventoryService.InitPlayer(player)
			playerInventories[player][weaponId] = true
			equippedWeapons[player] = weaponId :: WeaponId
			InventoryService.GiveToolToCharacter(player, weaponId :: WeaponId)

			pcall(function()
				local syncRemote = Network.GetRemote("SyncState")
				syncRemote:FireClient(player, {
					Notification = string.format("⚔️ ¡%s obtenido! Equipado para el combate.", weaponName),
					Inventory = playerInventories[player],
					EquippedWeapon = weaponId,
				})
			end)
		end
	end)

	local equipRemote = Network.GetRemote("RequestEquip")
	equipRemote.OnServerEvent:Connect(function(player: Player, weaponId: any)
		if typeof(weaponId) == "string" then
			local rawZoneId = ZonesConfig.GetPlayerZone(player) or "Zone_1"
			local zoneDef = ZonesConfig.GetById(rawZoneId :: ZoneId)
			local maxTier = if zoneDef then zoneDef.Tier else 1

			local isValid, _ = SecurityValidator.ValidateEquip(player, weaponId, playerInventories[player] or {}, maxTier)
			if isValid then
				InventoryService.EquipWeapon(player, weaponId :: Types.WeaponId)
			end
		end
	end)
end

return InventoryService
