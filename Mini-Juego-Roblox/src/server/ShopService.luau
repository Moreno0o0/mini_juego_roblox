--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Shared.Types)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Network = require(ReplicatedStorage.Shared.Network)
local PlayerStateService = require(ServerScriptService.Server.PlayerStateService)
local ProgressionService = require(ServerScriptService.Server.ProgressionService)
local InventoryService = require(ServerScriptService.Server.InventoryService)

local ShopService = {}

local playerCredits: { [Player]: number } = {}
local activeSpeedBoosts: { [Player]: number } = {}

function ShopService.InitPlayer(player: Player)
	if playerCredits[player] == nil then
		playerCredits[player] = ShopConfig.StartingCredits
	end
end

function ShopService.GetCredits(player: Player): number
	ShopService.InitPlayer(player)
	return playerCredits[player]
end

function ShopService.AddCredits(player: Player, amount: number)
	ShopService.InitPlayer(player)
	playerCredits[player] = math.max(0, playerCredits[player] + amount)

	pcall(function()
		local syncRemote = Network.GetRemote("SyncState")
		syncRemote:FireClient(player, {
			Credits = playerCredits[player],
			Notification = string.format("+%d Cyber-Créditos recibidos! Total: %d 🪙", amount, playerCredits[player])
		})
	end)
end

function ShopService.ProcessPurchase(player: Player, itemId: string): (boolean, string?)
	ShopService.InitPlayer(player)

	local item = ShopConfig.GetItem(itemId)
	if not item then
		return false, "Artículo no encontrado"
	end

	-- Credits check
	if playerCredits[player] < item.Price then
		return false, string.format("Créditos insuficientes: tienes %d 🪙, requiere %d 🪙", playerCredits[player], item.Price)
	end

	-- Zone tier requirement check
	local highestZone = ProgressionService.GetHighestUnlockedZone(player)
	if item.RequiredZoneTier > highestZone then
		return false, string.format("Requiere desbloquear la Zona %d", item.RequiredZoneTier)
	end

	local char = player.Character
	if not char then
		return false, "Personaje no encontrado"
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false, "El jugador está derrotado"
	end

	-- Deduct credits
	playerCredits[player] -= item.Price

	-- Apply item effect
	if item.Category == "Immunity" then
		-- Apply immunity ForceField
		PlayerStateService.Transition(player, "Immunity")
		local duration = item.Duration or 15
		task.delay(duration, function()
			if player:IsA("Player") and PlayerStateService.GetPlayerState(player) == "Immunity" then
				PlayerStateService.Transition(player, "Combat")
			end
		end)
	elseif itemId == "stim_speed_boost" then
		-- Speed boost buff +50%
		local token = (activeSpeedBoosts[player] or 0) + 1
		activeSpeedBoosts[player] = token
		hum.WalkSpeed = 24

		task.delay(item.Duration or 20, function()
			if activeSpeedBoosts[player] == token and hum and hum.Parent then
				hum.WalkSpeed = 16
			end
		end)
	elseif itemId == "stim_hyper_speed" then
		-- Hyper speed boost buff +75%
		local token = (activeSpeedBoosts[player] or 0) + 1
		activeSpeedBoosts[player] = token
		hum.WalkSpeed = 28

		task.delay(item.Duration or 25, function()
			if activeSpeedBoosts[player] == token and hum and hum.Parent then
				hum.WalkSpeed = 16
			end
		end)
	elseif itemId == "nanobots_heal" then
		-- Instant 100% healing
		hum.Health = hum.MaxHealth
	elseif item.Category == "Weapon" and item.WeaponId then
		local rawWId: any = item.WeaponId
		if typeof(rawWId) == "string" then
			local wId: Types.WeaponId = rawWId :: any
			InventoryService.AddReward(player, item.RequiredZoneTier, 0, wId)
			InventoryService.EquipWeapon(player, wId)
		end
	end

	-- Notify client
	pcall(function()
		local resultRemote = Network.GetRemote("ShopPurchaseResult")
		resultRemote:FireClient(player, true, itemId, playerCredits[player])

		local syncRemote = Network.GetRemote("SyncState")
		syncRemote:FireClient(player, {
			Credits = playerCredits[player],
			Notification = string.format("¡Comprado: %s! Te quedan %d 🪙", item.Name, playerCredits[player])
		})
	end)

	return true, nil
end

function ShopService.Init()
	Network.InitializeRemotes()

	Players.PlayerAdded:Connect(function(player: Player)
		ShopService.InitPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		playerCredits[player] = nil
		activeSpeedBoosts[player] = nil
	end)

	local purchaseRemote = Network.GetRemote("RequestShopPurchase")
	purchaseRemote.OnServerEvent:Connect(function(player: Player, itemId: any)
		if typeof(itemId) == "string" then
			ShopService.ProcessPurchase(player, itemId)
		end
	end)
end

return ShopService
