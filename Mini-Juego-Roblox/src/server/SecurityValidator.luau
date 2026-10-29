--!strict
local Players = game:GetService("Players")

export type RateLimitConfig = {
	MaxCallsPerSecond: number,
	Cooldown: number,
}

local SecurityValidator = {}

-- Rate limiting store: [Player][Action] -> { LastTimestamp: number, CallCount: number, WindowStart: number }
type RateEntry = {
	LastTimestamp: number,
	CallCount: number,
	WindowStart: number,
}

local playerLimits: { [Player]: { [string]: RateEntry } } = {}

local DEFAULT_LIMITS: { [string]: RateLimitConfig } = {
	RequestCapture = { MaxCallsPerSecond = 5, Cooldown = 0.2 },
	SubmitMinigameResult = { MaxCallsPerSecond = 2, Cooldown = 0.5 },
	RequestAttack = { MaxCallsPerSecond = 8, Cooldown = 0.1 },
	RequestEquip = { MaxCallsPerSecond = 4, Cooldown = 0.25 },
	RequestZoneChange = { MaxCallsPerSecond = 4, Cooldown = 0.25 },
	RequestCombatAction = { MaxCallsPerSecond = 10, Cooldown = 0.05 },
}

function SecurityValidator.Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		playerLimits[player] = nil
	end)
end

function SecurityValidator.CheckRateLimit(player: Player, action: string): boolean
	local now = os.clock()
	local limits = playerLimits[player]
	if not limits then
		limits = {}
		playerLimits[player] = limits
	end

	local entry = limits[action]
	if not entry then
		entry = {
			LastTimestamp = now,
			CallCount = 1,
			WindowStart = now,
		}
		limits[action] = entry
		return true
	end

	local config = DEFAULT_LIMITS[action] or { MaxCallsPerSecond = 10, Cooldown = 0.1 }

	-- Cooldown check
	if (now - entry.LastTimestamp) < config.Cooldown then
		return false
	end

	-- Window rate check (1 second window)
	if (now - entry.WindowStart) >= 1.0 then
		entry.WindowStart = now
		entry.CallCount = 1
	else
		entry.CallCount += 1
		if entry.CallCount > config.MaxCallsPerSecond then
			return false
		end
	end

	entry.LastTimestamp = now
	return true
end

function SecurityValidator.ValidateCapture(player: Player, machineId: any): (boolean, string?)
	if not SecurityValidator.CheckRateLimit(player, "RequestCapture") then
		return false, "Rate limit exceeded"
	end

	if typeof(machineId) ~= "number" then
		return false, "Invalid machineId type: expected number"
	end

	if machineId < 1 or machineId > 5 or math.floor(machineId) ~= machineId then
		return false, "Invalid machineId value: out of range [1, 5]"
	end

	return true, nil
end

function SecurityValidator.ValidateMinigameResult(
	player: Player,
	machineId: any,
	difficulty: any,
	timeSpent: any,
	clientToken: any,
	expectedToken: string?,
	minAllowedTime: number
): (boolean, string?)
	if not SecurityValidator.CheckRateLimit(player, "SubmitMinigameResult") then
		return false, "Rate limit exceeded"
	end

	if typeof(machineId) ~= "number" or machineId < 1 or machineId > 5 then
		return false, "Invalid machineId"
	end

	if typeof(difficulty) ~= "number" or difficulty < 1 or difficulty > 5 then
		return false, "Invalid difficulty"
	end

	if typeof(timeSpent) ~= "number" or timeSpent <= 0 then
		return false, "Invalid timeSpent"
	end

	if typeof(clientToken) ~= "string" or clientToken == "" then
		return false, "Invalid token"
	end

	if expectedToken ~= nil and clientToken ~= expectedToken then
		return false, "Token mismatch: invalid or expired session"
	end

	-- Anti-speedhack invariant: timeSpent must be >= T_min
	if timeSpent < minAllowedTime then
		return false, string.format("Speedhack detected: timeSpent (%.2f) < minAllowedTime (%.2f)", timeSpent, minAllowedTime)
	end

	return true, nil
end

function SecurityValidator.ValidateAttack(
	player: Player,
	target: any,
	hitPosition: any,
	weaponId: any,
	equippedWeaponId: string?,
	maxAllowedRange: number
): (boolean, string?)
	if not SecurityValidator.CheckRateLimit(player, "RequestAttack") then
		return false, "Rate limit exceeded"
	end

	if typeof(weaponId) ~= "string" then
		return false, "Invalid weaponId type"
	end

	if equippedWeaponId and weaponId ~= equippedWeaponId then
		return false, "Weapon mismatch: weaponId does not match equipped weapon"
	end

	if typeof(hitPosition) ~= "Vector3" then
		return false, "Invalid hitPosition: expected Vector3"
	end

	local char = player.Character
	if not char then
		return false, "Attacker character missing"
	end

	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "Attacker HumanoidRootPart missing"
	end

	-- Range check with 50% ping tolerance
	local distance = (root.Position - hitPosition).Magnitude
	local maxRangeWithTolerance = maxAllowedRange * 1.5 + 5.0
	if distance > maxRangeWithTolerance then
		return false, string.format("Attack out of range: %.1f > %.1f", distance, maxRangeWithTolerance)
	end

	if target ~= nil then
		if typeof(target) ~= "Instance" then
			return false, "Invalid target instance type"
		end

		if target:IsA("Player") then
			if target == player then
				return false, "Cannot target self"
			end
		elseif target:IsA("Model") then
			if target == char then
				return false, "Cannot target self"
			end
			local isDummy = target:GetAttribute("IsDummy") == true
			local hasHum = target:FindFirstChildOfClass("Humanoid") ~= nil
			if not isDummy and not hasHum then
				return false, "Invalid model target: missing humanoid"
			end
		else
			return false, "Invalid target instance class"
		end
	end

	return true, nil
end

function SecurityValidator.ValidateEquip(
	player: Player,
	weaponId: any,
	inventory: { [string]: boolean },
	maxTierAllowed: number,
	weaponTier: number?
): (boolean, string?)
	if not SecurityValidator.CheckRateLimit(player, "RequestEquip") then
		return false, "Rate limit exceeded"
	end

	if typeof(weaponId) ~= "string" then
		return false, "Invalid weaponId type"
	end

	if not inventory[weaponId] then
		return false, "Weapon not owned in player inventory"
	end

	if weaponTier and weaponTier > maxTierAllowed then
		return false, string.format("Weapon tier (%d) exceeds zone maximum tier (%d)", weaponTier, maxTierAllowed)
	end

	return true, nil
end

return SecurityValidator
