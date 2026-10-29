--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Shared.Types)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.ZonesConfig)
local WeaponsConfig = require(ReplicatedStorage.Shared.Config.WeaponsConfig)
local Network = require(ReplicatedStorage.Shared.Network)
local PlayerStateService = require(ServerScriptService.Server.PlayerStateService)
local MachineManager = require(ServerScriptService.Server.MachineManager)
local SecurityValidator = require(ServerScriptService.Server.SecurityValidator)
local StreakService = require(ServerScriptService.Server.StreakService)
local ShopService = require(ServerScriptService.Server.ShopService)

local CombatSystem = {}

-- Spatial location function Loc_P: P -> Z
function CombatSystem.GetPlayerZone(player: Player): Types.ZoneId?
	return ZonesConfig.GetPlayerZone(player)
end

-- Equivalence relation: p1 ~_Z p2 <=> Loc_P(p1) == Loc_P(p2)
function CombatSystem.AreInSameZone(p1: Player, p2: Player): boolean
	local z1 = CombatSystem.GetPlayerZone(p1)
	local z2 = CombatSystem.GetPlayerZone(p2)
	return z1 ~= nil and z1 == z2
end

-- Binary Relation CanDamage subset of P x P:
-- (p1, p2) in CanDamage <=> (p1 ~= p2) and (p1 ~_Z p2) and (p1 in S_Combat U S_Capturing) and (p2 in S_Combat U S_Capturing)
function CombatSystem.CanPlayerDamage(attacker: Player, victim: Player): boolean
	if attacker == victim then
		return false
	end

	-- Zone equivalence check
	if not CombatSystem.AreInSameZone(attacker, victim) then
		return false
	end

	-- State checks
	local attackerState = PlayerStateService.GetPlayerState(attacker)
	local victimState = PlayerStateService.GetPlayerState(victim)

	local attackerEligible = (attackerState == "Combat" or attackerState == "Capturing")
	local victimEligible = (victimState == "Combat" or victimState == "Capturing")

	-- Critical: Immunity, Playing, or Dead players can NEVER take damage
	return attackerEligible and victimEligible
end

function CombatSystem.ProcessAttack(
	attacker: Player,
	target: Instance?,
	_hitPosition: Vector3,
	weaponId: string
): (boolean, number)
	local weapon = WeaponsConfig.Get(weaponId :: Types.WeaponId)
	if not weapon then
		return false, 0
	end

	local okAttackerChar, attackerChar = pcall(function()
		return attacker.Character
	end)
	local attackerRoot: BasePart? = nil
	if okAttackerChar and typeof(attackerChar) == "Instance" and attackerChar:IsA("Model") then
		attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if attackerChar:GetAttribute("IsStaggered") == true then
			return false, 0
		end
	end

	-- Zone Damage Cap (anti-abuse rule)
	local zoneId: Types.ZoneId = CombatSystem.GetPlayerZone(attacker) or "Zone_1"
	local zoneDef = ZonesConfig.GetById(zoneId)
	local maxZoneDamage = if zoneDef then zoneDef.MaxZoneDamage else 100
	local finalDamage = math.min(weapon.BaseDamage, maxZoneDamage)

	if not target then
		-- Swung at air: valid action, 0 damage
		return true, 0
	end

	if target:IsA("Player") then
		local targetPlayer: Player = target
		if not CombatSystem.CanPlayerDamage(attacker, targetPlayer) then
			return false, 0
		end

		local okTargetChar, targetChar = pcall(function()
			return targetPlayer.Character
		end)
		if not okTargetChar or typeof(targetChar) ~= "Instance" or not targetChar:IsA("Model") then
			return false, 0
		end

		-- Check if victim is currently in i-frames (Dash evade)
		if targetChar:GetAttribute("IsDashing") == true then
			pcall(function()
				local syncRemote = Network.GetRemote("SyncState")
				syncRemote:FireClient(attacker, { Notification = "💨 ¡El rival esquivó el ataque!" })
				syncRemote:FireClient(targetPlayer, { Notification = "💨 ¡Ataque esquivado con éxito!" })
			end)
			return false, 0
		end

		-- Check if victim is blocking or perfect parrying
		local isBlocking = targetChar:GetAttribute("IsBlocking") == true
		local blockTime = targetChar:GetAttribute("BlockStartTime")
		local blockAge = if typeof(blockTime) == "number" then (os.clock() - blockTime) else 999.0
		local isParry = isBlocking and (blockAge <= 0.28)

		if isParry then
			-- Perfect Parry: Negates 100% damage and staggers the attacker!
			if okAttackerChar and typeof(attackerChar) == "Instance" and attackerChar:IsA("Model") then
				attackerChar:SetAttribute("IsStaggered", true)
				task.delay(0.75, function()
					if attackerChar and attackerChar.Parent then
						attackerChar:SetAttribute("IsStaggered", nil)
					end
				end)
			end

			pcall(function()
				local feedbackRemote = Network.GetRemote("CombatFeedback")
				feedbackRemote:FireAllClients(attacker, targetPlayer, 0, Vector3.zero, "Parry")
				local syncRemote = Network.GetRemote("SyncState")
				syncRemote:FireClient(targetPlayer, { Notification = "⚡ ¡PARRY PERFECTO! Rival desestabilizado." })
				syncRemote:FireClient(attacker, { Notification = "💥 ¡PARRY RECIBIDO! Estás aturdido." })
			end)
			return false, 0
		elseif isBlocking then
			-- Normal block: 65% damage reduction
			finalDamage = math.max(1, math.floor(finalDamage * 0.35))
			pcall(function()
				local syncRemote = Network.GetRemote("SyncState")
				syncRemote:FireClient(targetPlayer, { Notification = "🛡️ Bloqueo defensivo (-65% daño)" })
			end)
		end

		local humanoid = targetChar:FindFirstChildOfClass("Humanoid")
		local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or humanoid.Health <= 0 or not targetRoot then
			return false, 0
		end

		-- Apply Damage
		humanoid:TakeDamage(finalDamage)

		if humanoid.Health <= 0 then
			StreakService.ResetStreak(targetPlayer)
			local _, streakMult = StreakService.IncrementStreak(attacker)
			local killCredits = math.floor(15 * streakMult)
			ShopService.AddCredits(attacker, killCredits)

			pcall(function()
				local syncRemote = Network.GetRemote("SyncState")
				syncRemote:FireAllClients({
					Notification = string.format("⚔️ %s eliminó a %s (+%d 🪙)", attacker.DisplayName, targetPlayer.DisplayName, killCredits),
				})
			end)
		end

		-- Inform MachineManager (interrupts capture if victim was capturing)
		MachineManager.OnPlayerDamage(targetPlayer)

		-- Apply Knockback impulse
		local knockbackDir = Vector3.new(0, 0.2, 0)
		if attackerRoot then
			local horizontalDelta = (targetRoot.Position - attackerRoot.Position)
			local planar = Vector3.new(horizontalDelta.X, 0, horizontalDelta.Z)
			if planar.Magnitude > 0.01 then
				knockbackDir = (planar.Unit + Vector3.new(0, 0.35, 0)).Unit
			end
		end

		local impulse = knockbackDir * (weapon.Knockback * targetRoot.AssemblyMass * 0.75)
		targetRoot:ApplyImpulse(impulse)

		-- Sync combat feedback to clients
		pcall(function()
			local feedbackRemote = Network.GetRemote("CombatFeedback")
			feedbackRemote:FireAllClients(attacker, targetPlayer, finalDamage, knockbackDir)
		end)

		return true, finalDamage
	elseif target:IsA("Model") then
		local attackerState = PlayerStateService.GetPlayerState(attacker)
		if attackerState ~= "Combat" and attackerState ~= "Capturing" then
			return false, 0
		end

		local humanoid = target:FindFirstChildOfClass("Humanoid")
		local targetRoot = (target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso") or target.PrimaryPart) :: BasePart?
		if not humanoid or humanoid.Health <= 0 or not targetRoot then
			return false, 0
		end

		-- Apply Damage to dummy
		humanoid:TakeDamage(finalDamage)

		if humanoid.Health <= 0 then
			StreakService.IncrementStreak(attacker)
			ShopService.AddCredits(attacker, 5)

			pcall(function()
				local syncRemote = Network.GetRemote("SyncState")
				syncRemote:FireClient(attacker, {
					Notification = "🎯 ¡Dummy de pruebas derrotado! (+5 🪙)",
				})
			end)

			task.delay(2.5, function()
				if humanoid.Parent then
					humanoid.Health = humanoid.MaxHealth
				end
			end)
		end

		local knockbackDir = Vector3.new(0, 0.2, 0)
		if attackerRoot then
			local horizontalDelta = (targetRoot.Position - attackerRoot.Position)
			local planar = Vector3.new(horizontalDelta.X, 0, horizontalDelta.Z)
			if planar.Magnitude > 0.01 then
				knockbackDir = (planar.Unit + Vector3.new(0, 0.35, 0)).Unit
			end
		end

		if not targetRoot.Anchored then
			local impulse = knockbackDir * (weapon.Knockback * targetRoot.AssemblyMass * 0.75)
			targetRoot:ApplyImpulse(impulse)
		end

		-- Sync combat feedback to clients
		pcall(function()
			local feedbackRemote = Network.GetRemote("CombatFeedback")
			feedbackRemote:FireAllClients(attacker, target, finalDamage, knockbackDir)
		end)

		return true, finalDamage
	end

	return false, 0
end

function CombatSystem.Init()
	Network.InitializeRemotes()

	local attackRemote = Network.GetRemote("RequestAttack")
	attackRemote.OnServerEvent:Connect(function(player: Player, target: any, hitPos: any, weaponId: any)
		local isValid, _ = SecurityValidator.ValidateAttack(player, target, hitPos, weaponId, nil, 100)
		if not isValid then
			return
		end

		if (target == nil or (typeof(target) == "Instance" and (target:IsA("Player") or target:IsA("Model"))))
			and typeof(hitPos) == "Vector3"
			and typeof(weaponId) == "string"
		then
			CombatSystem.ProcessAttack(player, target, hitPos, weaponId)
		end
	end)

	local actionRemote = Network.GetRemote("RequestCombatAction")
	actionRemote.OnServerEvent:Connect(function(player: Player, actionType: any, actionData: any)
		local char = player.Character
		if not char then
			return
		end

		if actionType == "Dash" then
			local lastDash = char:GetAttribute("LastDashTime")
			local now = os.clock()
			if typeof(lastDash) == "number" and (now - lastDash) < 2.0 then
				return
			end
			char:SetAttribute("LastDashTime", now)
			char:SetAttribute("IsDashing", true)
			task.delay(0.35, function()
				if char and char.Parent then
					char:SetAttribute("IsDashing", nil)
				end
			end)
		elseif actionType == "Block" then
			local isBlocking = actionData == true
			char:SetAttribute("IsBlocking", isBlocking)
			if isBlocking then
				char:SetAttribute("BlockStartTime", os.clock())
			else
				char:SetAttribute("BlockStartTime", nil)
			end
		end
	end)
end

return CombatSystem
