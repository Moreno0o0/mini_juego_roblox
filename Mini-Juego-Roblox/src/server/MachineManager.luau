--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Types = require(ReplicatedStorage.Shared.Types)
local MachinesConfig = require(ReplicatedStorage.Shared.Config.MachinesConfig)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.ZonesConfig)
local Network = require(ReplicatedStorage.Shared.Network)
local PlayerStateService = require(ServerScriptService.Server.PlayerStateService)
local ProgressionService = require(ServerScriptService.Server.ProgressionService)
local SecurityValidator = require(ServerScriptService.Server.SecurityValidator)
local StreakService = require(ServerScriptService.Server.StreakService)

type MachineId = Types.MachineId
type DifficultyLevel = Types.DifficultyLevel
type SessionStarter = (player: Player, difficulty: number) -> (string, any)

local MachineManager = {}

-- Set of occupants per machine: M -> P(P) (Multiple players allowed, each with an individual instance)
local machineOccupants: { [number]: { [Player]: boolean } } = {
	[1] = {},
	[2] = {},
	[3] = {},
	[4] = {},
	[5] = {},
}

-- Injective lookup P -> M (Each player occupies at most 1 machine at a time)
local PlayerToMachine: { [Player]: number? } = {}

-- Backward-compat single-occupant lookup (returns first active player or nil)
local Occ: { [number]: Player? } = {
	[1] = nil,
	[2] = nil,
	[3] = nil,
	[4] = nil,
	[5] = nil,
}

-- Active timeout cancellation tokens per player
local playerTimeoutTokens: { [Player]: number } = {}

-- Slot counter for vertical isolation of concurrent players in individual chambers
local playerSlotCounters: { [number]: number } = {
	[1] = 0,
	[2] = 0,
	[3] = 0,
	[4] = 0,
	[5] = 0,
}

-- 10-Second Portal Cycle State
local isPortalOpen = false
local portalCycleStart = os.clock()

-- Registry of Minigame session starters (decoupled from validators to avoid cyclic require)
local sessionStarters: { [number]: SessionStarter } = {}

function MachineManager.RegisterSessionStarter(machineId: number, starter: SessionStarter)
	sessionStarters[machineId] = starter
end

-- Pad progress tracking: [machineId] -> { Player: Player?, Progress: number, LastDamageTime: number }
type PadState = {
	CurrentContender: Player?,
	Progress: number,
	LastDamageTime: number,
}

local padStates: { [number]: PadState } = {
	[1] = { CurrentContender = nil, Progress = 0, LastDamageTime = 0 },
	[2] = { CurrentContender = nil, Progress = 0, LastDamageTime = 0 },
	[3] = { CurrentContender = nil, Progress = 0, LastDamageTime = 0 },
	[4] = { CurrentContender = nil, Progress = 0, LastDamageTime = 0 },
	[5] = { CurrentContender = nil, Progress = 0, LastDamageTime = 0 },
}

function MachineManager.VerifyMutualExclusion(): boolean
	local seenPlayers: { [Player]: boolean } = {}

	for m = 1, 5 do
		local occupants = machineOccupants[m]
		if occupants then
			for player in pairs(occupants) do
				if seenPlayers[player] then
					return false
				end
				seenPlayers[player] = true

				if PlayerToMachine[player] ~= m then
					return false
				end
			end
		end
	end

	return true
end

function MachineManager.GetOccupant(machineId: number): Player?
	local occupants = machineOccupants[machineId]
	if occupants then
		for player in pairs(occupants) do
			return player
		end
	end
	return nil
end

function MachineManager.GetOccupants(machineId: number): { Player }
	local list = {}
	local occupants = machineOccupants[machineId]
	if occupants then
		for player in pairs(occupants) do
			table.insert(list, player)
		end
	end
	return list
end

function MachineManager.GetPlayerMachine(player: Player): number?
	return PlayerToMachine[player]
end

local function UpdateStatusSign(machineId: number, isOccupied: boolean, nickname: string?)
	pcall(function()
		local world = Workspace:FindFirstChild("World")
		if not world then
			return
		end
		local zones = world:FindFirstChild("Zones")
		if not zones then
			return
		end
		local zone = zones:FindFirstChild("Zone_" .. machineId)
		if not zone then
			return
		end
		local machine = zone:FindFirstChild("Machine_" .. machineId)
		if not machine then
			return
		end
		local statusSign = machine:FindFirstChild("StatusSign") :: BasePart?
		if not statusSign then
			return
		end
		local signGui = statusSign:FindFirstChild("SignGui") :: SurfaceGui?
		if not signGui then
			return
		end
		local label = signGui:FindFirstChild("StatusLabel") :: TextLabel?
		if not label then
			return
		end

		if isOccupied then
			label.Text = "OCUPADO (" .. (nickname or "JUGADOR") .. ")"
			label.TextColor3 = Color3.fromRGB(255, 50, 50)
		else
			label.Text = "DISPONIBLE"
			label.TextColor3 = Color3.fromRGB(50, 255, 50)
		end
	end)
end

local function UpdatePadBillboard(machineId: number, progress: number)
	pcall(function()
		local world = Workspace:FindFirstChild("World")
		if not world then
			return
		end
		local zones = world:FindFirstChild("Zones")
		if not zones then
			return
		end
		local zone = zones:FindFirstChild("Zone_" .. machineId)
		if not zone then
			return
		end
		local padModel = zone:FindFirstChild("CapturePad_" .. machineId)
		if not padModel then
			return
		end
		local padBase = padModel:FindFirstChild("PadBase") :: BasePart?
		if not padBase then
			return
		end
		local billboard = padBase:FindFirstChild("CaptureBillboard") :: BillboardGui?
		if not billboard then
			return
		end
		local label = billboard:FindFirstChild("ProgressLabel") :: TextLabel?
		if label then
			label.Text = string.format("Progreso: %.1fs / 3.0s", math.clamp(progress, 0, 3.0))
		end
	end)
end

local CHAMBER_SPAWN_POS: { [number]: Vector3 } = {
	[1] = Vector3.new(0, -177, 0),
	[2] = Vector3.new(170, -177, -105),
	[3] = Vector3.new(340, -177, -28),
	[4] = Vector3.new(510, -177, 0),
	[5] = Vector3.new(700, -177, 0),
}

local MACHINE_EXIT_POS: { [number]: Vector3 } = {
	[1] = Vector3.new(0, 3, 22),
	[2] = Vector3.new(170, 3, 22),
	[3] = Vector3.new(340, 3, 22),
	[4] = Vector3.new(510, 3, 22),
	[5] = Vector3.new(700, 3, 30),
}

local NEXT_ZONE_SPAWN_POS: { [number]: Vector3 } = {
	[1] = Vector3.new(135, 3, 0), -- Entrance to Zone 2
	[2] = Vector3.new(305, 3, 0), -- Entrance to Zone 3
	[3] = Vector3.new(475, 3, 0), -- Entrance to Zone 4
	[4] = Vector3.new(650, 3, 0), -- Entrance to Zone 5
}

function MachineManager.GetChamberPosition(machineId: number): Vector3?
	return CHAMBER_SPAWN_POS[machineId]
end

function MachineManager.GetExitPosition(machineId: number): Vector3?
	return MACHINE_EXIT_POS[machineId]
end

function MachineManager.TeleportToChamber(player: Player, machineId: number)
	local targetPos = CHAMBER_SPAWN_POS[machineId]
	if targetPos and player.Character then
		local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.CFrame = CFrame.new(targetPos)
		end
	end
end

function MachineManager.TeleportToExit(player: Player, machineId: number)
	local targetPos = MACHINE_EXIT_POS[machineId]
	if targetPos and player.Character then
		local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.CFrame = CFrame.new(targetPos)
		end
	end
end

function MachineManager.ClaimMachine(machineId: number, player: Player, difficulty: number?): (boolean, string?)
	if machineId < 1 or machineId > 5 then
		return false, "Invalid machineId"
	end

	-- Access check via Poset DAG (p, m_k) in Access
	if not ProgressionService.HasAccess(player, machineId) then
		return false, "Player has not unlocked machine " .. tostring(machineId)
	end

	-- A player can only occupy 1 machine at a time
	if PlayerToMachine[player] ~= nil then
		return false, "Player already occupies machine " .. tostring(PlayerToMachine[player])
	end

	local currentState = PlayerStateService.GetPlayerState(player)
	if currentState ~= "Combat" and currentState ~= "Capturing" and currentState ~= "Immunity" then
		return false, "Cannot occupy machine from state: " .. tostring(currentState)
	end

	-- Determine target difficulty
	local curProg = ProgressionService.GetProgress(player, machineId)
	local finalDifficulty: number
	if difficulty ~= nil and difficulty >= 1 and difficulty <= math.clamp(curProg + 1, 1, 5) then
		finalDifficulty = difficulty
	else
		finalDifficulty = math.clamp(curProg + 1, 1, 5)
	end

	-- Multi-occupancy: Add player to machine's set of players
	if not machineOccupants[machineId] then
		machineOccupants[machineId] = {}
	end
	machineOccupants[machineId][player] = true
	PlayerToMachine[player] = machineId
	Occ[machineId] = player

	-- Vertical slot separation for individual chamber instances
	playerSlotCounters[machineId] = (playerSlotCounters[machineId] or 0) + 1
	local slot = playerSlotCounters[machineId]

	assert(MachineManager.VerifyMutualExclusion(), "Mutual exclusion invariant violated during ClaimMachine")

	-- Transition player to Playing state (applies ForceField, unequips weapons)
	PlayerStateService.Transition(player, "Playing")

	-- Physical teleportation to their individual vertical slice of the minigame chamber
	local baseTargetPos = CHAMBER_SPAWN_POS[machineId]
	if baseTargetPos and player.Character then
		local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local slotOffset = Vector3.new(0, (slot % 4) * 35, 0)
			root.CFrame = CFrame.new(baseTargetPos + slotOffset)
		end
	end

	-- Update physical sign
	local count = 0
	for _ in pairs(machineOccupants[machineId]) do
		count += 1
	end
	UpdateStatusSign(machineId, count > 0, if count == 1 then player.Name else string.format("%d Jugadores", count))

	-- Authoritative Timeout Timer per player
	local levelDef = MachinesConfig.GetLevel(machineId, finalDifficulty)
	local timeout = if levelDef then levelDef.MaxTime else 60.0

	local token = (playerTimeoutTokens[player] or 0) + 1
	playerTimeoutTokens[player] = token

	task.delay(timeout, function()
		if playerTimeoutTokens[player] == token and PlayerToMachine[player] == machineId then
			pcall(function()
				local forceExitRemote = Network.GetRemote("ForceExitMachine")
				forceExitRemote:FireClient(player, "Timeout: Tiempo límite alcanzado")
			end)
			MachineManager.ReleasePlayer(player, "Timeout")
		end
	end)

	-- Start Minigame Session & notify client
	local starter = sessionStarters[machineId]
	if starter then
		local sessionToken, sessionPayload = starter(player, finalDifficulty)
		pcall(function()
			local startRemote = Network.GetRemote("StartMinigameClient")
			startRemote:FireClient(player, machineId, finalDifficulty, timeout, sessionToken, sessionPayload)
		end)
	end

	return true, nil
end

function MachineManager.ReleasePlayer(player: Player, reason: string)
	local machineId = PlayerToMachine[player]
	if not machineId then
		return
	end

	-- Invalidate timeout token
	playerTimeoutTokens[player] = nil

	-- Remove player from machine occupants
	if machineOccupants[machineId] then
		machineOccupants[machineId][player] = nil
	end
	PlayerToMachine[player] = nil

	-- Update Occ[machineId]
	local remainingPlayer: Player? = nil
	if machineOccupants[machineId] then
		for p in pairs(machineOccupants[machineId]) do
			remainingPlayer = p
			break
		end
	end
	Occ[machineId] = remainingPlayer

	-- If clean win, throw the player directly into the next room (no menu, fast continuous flow)
	if reason == "Win" and machineId < 5 and NEXT_ZONE_SPAWN_POS[machineId] then
		local targetPos = NEXT_ZONE_SPAWN_POS[machineId]
		if player.Character then
			local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.CFrame = CFrame.new(targetPos)
			end
		end
	else
		-- Teleport player back to the arena outside the machine cabinet
		MachineManager.TeleportToExit(player, machineId)
	end

	-- Update physical sign
	local count = 0
	if machineOccupants[machineId] then
		for _ in pairs(machineOccupants[machineId]) do
			count += 1
		end
	end
	UpdateStatusSign(machineId, count > 0, if count == 0 then nil elseif count == 1 then (remainingPlayer and remainingPlayer.Name) else string.format("%d Jugadores", count))

	-- If exiting without a clean win, notify client and reset streak
	if reason ~= "Win" then
		StreakService.ResetStreak(player)
		pcall(function()
			local forceExitRemote = Network.GetRemote("ForceExitMachine")
			forceExitRemote:FireClient(player, "Salida de cabina: " .. reason)
		end)
	end

	-- Transition player from Playing to Immunity (10 seconds invulnerability)
	if PlayerStateService.GetPlayerState(player) == "Playing" then
		PlayerStateService.Transition(player, "Immunity")
	end
end

function MachineManager.ReleaseMachine(target: any, reason: string, optionalPlayer: Player?)
	if typeof(target) == "Instance" and target:IsA("Player") then
		MachineManager.ReleasePlayer(target, reason)
	elseif optionalPlayer and typeof(optionalPlayer) == "Instance" and optionalPlayer:IsA("Player") then
		MachineManager.ReleasePlayer(optionalPlayer, reason)
	elseif typeof(target) == "number" then
		local machineId = target
		if machineOccupants[machineId] then
			local list = {}
			for p in pairs(machineOccupants[machineId]) do
				table.insert(list, p)
			end
			for _, p in ipairs(list) do
				MachineManager.ReleasePlayer(p, reason)
			end
		end
	end
end

function MachineManager.OnPlayerDamage(player: Player)
	-- If player is currently capturing a pad, reset progress
	for m = 1, 5 do
		local pad = padStates[m]
		if pad.CurrentContender == player then
			pad.Progress = 0
			pad.LastDamageTime = os.clock()
			UpdatePadBillboard(m, 0)
		end
	end
end

function MachineManager.UpdatePadProgress(machineId: number, contender: Player?, deltaTime: number): boolean
	local pad = padStates[machineId]
	if not pad then
		return false
	end

	if Occ[machineId] ~= nil then
		pad.Progress = 0
		pad.CurrentContender = nil
		UpdatePadBillboard(machineId, 0)
		return false
	end

	if contender == nil then
		pad.Progress = 0
		pad.CurrentContender = nil
		UpdatePadBillboard(machineId, 0)
		return false
	end

	if pad.CurrentContender ~= contender then
		pad.CurrentContender = contender
		pad.Progress = 0
		UpdatePadBillboard(machineId, 0)
	end

	-- Check if recently damaged (must go 3 seconds continuous without damage)
	if (os.clock() - pad.LastDamageTime) < 3.0 and pad.LastDamageTime > 0 then
		pad.Progress = 0
		UpdatePadBillboard(machineId, 0)
		return false
	end

	pad.Progress += deltaTime
	UpdatePadBillboard(machineId, pad.Progress)
	if pad.Progress >= 3.0 then
		pad.Progress = 0
		pad.CurrentContender = nil
		UpdatePadBillboard(machineId, 0)
		-- Award capture
		local nextDiff = math.clamp(ProgressionService.GetProgress(contender, machineId) + 1, 1, 5)
		local success, _ = MachineManager.ClaimMachine(machineId, contender, nextDiff)
		return success
	end

	return false
end

function MachineManager.OnPlayerDeath(player: Player)
	local occupiedMachine = PlayerToMachine[player]
	if occupiedMachine then
		MachineManager.ReleaseMachine(occupiedMachine, "PlayerDeath")
	end
	for m = 1, 5 do
		if padStates[m].CurrentContender == player then
			padStates[m].CurrentContender = nil
			padStates[m].Progress = 0
		end
	end
end

local function HandleMachinePromptActivation(player: Player, machineId: number)
	if not isPortalOpen then
		pcall(function()
			local syncRemote = Network.GetRemote("SyncState")
			syncRemote:FireClient(player, {
				Notification = "🌀 El portal se está cargando. Se abrirá en unos segundos..."
			})
		end)
		return
	end

	if not ProgressionService.HasAccess(player, machineId) then
		pcall(function()
			local syncRemote = Network.GetRemote("SyncState")
			syncRemote:FireClient(player, {
				Notification = string.format("¡Acceso Bloqueado! Debes superar la Máquina %d para desbloquear esta sala", machineId - 1)
			})
		end)
		return
	end
	local state = PlayerStateService.GetPlayerState(player)
	if state ~= "Combat" and state ~= "Capturing" and state ~= "Immunity" then
		return
	end
	local nextDiff = math.clamp(ProgressionService.GetProgress(player, machineId) + 1, 1, 5)
	MachineManager.ClaimMachine(machineId, player, nextDiff)
end

function MachineManager.MoveCapturePad(machineId: number, targetPos: Vector3, duration: number)
	local world = Workspace:FindFirstChild("World")
	local zone = world and world:FindFirstChild("Zones") and world.Zones:FindFirstChild("Zone_" .. machineId)
	local padModel = zone and zone:FindFirstChild("CapturePad_" .. machineId) :: Model?
	if not padModel or not padModel.PrimaryPart then
		return
	end

	local startPos = padModel.PrimaryPart.Position
	local ring = padModel:FindFirstChild("ProgressRing") :: BasePart?

	local startTime = os.clock()
	task.spawn(function()
		while (os.clock() - startTime) < duration do
			local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
			local smoothAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			local curPos = startPos:Lerp(targetPos, smoothAlpha)
			if padModel.PrimaryPart then
				padModel.PrimaryPart.CFrame = CFrame.new(curPos) * CFrame.Angles(0, 0, math.pi / 2)
			end
			if ring then
				ring.CFrame = CFrame.new(curPos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			end
			task.wait(0.03)
		end
		if padModel.PrimaryPart then
			padModel.PrimaryPart.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, 0, math.pi / 2)
		end
		if ring then
			ring.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end)
end

function MachineManager.Init()
	Network.InitializeRemotes()

	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(char: Model)
			local humanoid = char:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				MachineManager.OnPlayerDeath(player)
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local occupiedMachine = PlayerToMachine[player]
		if occupiedMachine then
			MachineManager.ReleaseMachine(occupiedMachine, "PlayerRemoving")
		end
		for m = 1, 5 do
			if padStates[m].CurrentContender == player then
				padStates[m].CurrentContender = nil
				padStates[m].Progress = 0
			end
		end
	end)

	-- RequestCapture Remote Listener
	local captureRemote = Network.GetRemote("RequestCapture")
	captureRemote.OnServerEvent:Connect(function(player: Player, machineId: any, requestedDifficulty: any)
		local ok, _err = SecurityValidator.ValidateCapture(player, machineId)
		if not ok then
			return
		end
		local m = machineId :: number
		if not ProgressionService.HasAccess(player, m) then
			return
		end
		local state = PlayerStateService.GetPlayerState(player)
		if state ~= "Combat" and state ~= "Capturing" and state ~= "Immunity" then
			return
		end

		local curProg = ProgressionService.GetProgress(player, m)
		local diff = math.clamp(curProg + 1, 1, 5)
		if typeof(requestedDifficulty) == "number" and requestedDifficulty >= 1 and requestedDifficulty <= math.clamp(curProg + 1, 1, 5) then
			diff = requestedDifficulty
		end

		MachineManager.ClaimMachine(m, player, diff)
	end)

	-- Global ProximityPrompt listener for CapturePad Portals (Resilient across world rebuilds)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if prompt.Name == "CapturePrompt" then
			local machineId: any = prompt:GetAttribute("MachineId")
			if typeof(machineId) ~= "number" then
				local model = prompt:FindFirstAncestorOfClass("Model")
				local attr = model and model:GetAttribute("MachineId")
				if typeof(attr) == "number" then
					machineId = attr
				else
					for i = 1, 5 do
						if string.find(prompt:GetFullName(), "CapturePad_" .. i) or string.find(prompt:GetFullName(), "Zone_" .. i) then
							machineId = i
							break
						end
					end
				end
			end
			local m = if typeof(machineId) == "number" then machineId else 1
			HandleMachinePromptActivation(player, m)
		end
	end)

	-- 10-Second Portal Cycle (Opens every 10 seconds for multi-player snappy access)
	task.spawn(function()
		while true do
			local now = os.clock()
			local elapsed = (now - portalCycleStart) % 10.0
			local openWindow = (elapsed >= 5.5) -- Open 4.5 seconds every 10 seconds!
			isPortalOpen = openWindow

			local world = Workspace:FindFirstChild("World")
			local zones = world and world:FindFirstChild("Zones")

			for m = 1, 5 do
				local zone = zones and zones:FindFirstChild("Zone_" .. m)
				local pad = zone and zone:FindFirstChild("CapturePad_" .. m)
				local padBase = pad and pad:FindFirstChild("PadBase")
				local billboard = padBase and padBase:FindFirstChild("PadBillboard")
				local label = billboard and billboard:FindFirstChild("ProgressLabel") :: TextLabel?
				local prompt = padBase and padBase:FindFirstChildOfClass("ProximityPrompt")
				local ring = pad and pad:FindFirstChild("ProgressRing") :: BasePart?

				if isPortalOpen then
					local remOpen = math.max(0.1, 10.0 - elapsed)
					if label then
						label.Text = string.format("⚡ ¡PORTAL ABIERTO! (%.1fs)", remOpen)
						label.TextColor3 = Color3.fromRGB(50, 255, 180)
					end
					if ring then
						ring.Color = Color3.fromRGB(0, 255, 180)
					end
					if prompt then
						prompt.Enabled = true
						prompt.ActionText = "¡Entrar al Portal!"
						prompt.HoldDuration = 0.05
					end
				else
					local remCharge = math.max(0.1, 5.5 - elapsed)
					if label then
						label.Text = string.format("🌀 Portal cargando: %.1fs", remCharge)
						label.TextColor3 = Color3.fromRGB(0, 200, 255)
					end
					if ring then
						ring.Color = Color3.fromRGB(0, 150, 255)
					end
					if prompt then
						prompt.Enabled = true
						prompt.ActionText = string.format("Cargando (%.0fs)", remCharge)
						prompt.HoldDuration = 0.35
					end
				end
			end

			task.wait(0.25)
		end
	end)

	-- Dynamic Periodic Capture Pad Relocation (Every 25s, moves unoccupied pads to new spots in the zone)
	task.spawn(function()
		task.wait(8.0)
		while true do
			task.wait(25.0)
			for m = 1, 5 do
				-- If someone is actively occupying the machine or capturing the pad, don't move yet
				if Occ[m] ~= nil or padStates[m].Progress > 0.05 then
					continue
				end

				local zoneDef = ZonesConfig.GetByIndex(m)
				if not zoneDef then
					continue
				end

				local minX = zoneDef.Center.X - (zoneDef.Size.X * 0.30)
				local maxX = zoneDef.Center.X + (zoneDef.Size.X * 0.30)
				local minZ = zoneDef.Center.Z - (zoneDef.Size.Z * 0.30)
				local maxZ = zoneDef.Center.Z + (zoneDef.Size.Z * 0.10)
				local newX = math.random(math.floor(minX), math.floor(maxX))
				local newZ = math.random(math.floor(minZ), math.floor(maxZ))
				local targetPos = Vector3.new(newX, zoneDef.PadPosition.Y, newZ)

				MachineManager.MoveCapturePad(m, targetPos, 2.5)
			end
		end
	end)

	-- King-of-the-Hill Spatial Heartbeat Loop
	local PAD_RADIUS = 12.0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local world = Workspace:FindFirstChild("World")
		if not world then
			return
		end
		local zones = world:FindFirstChild("Zones")
		if not zones then
			return
		end

		for m = 1, 5 do
			if Occ[m] ~= nil then
				continue
			end

			local zone = zones:FindFirstChild("Zone_" .. m)
			if not zone then
				continue
			end
			local padModel = zone:FindFirstChild("CapturePad_" .. m)
			if not padModel then
				continue
			end
			local padBase = padModel:FindFirstChild("PadBase") :: BasePart?
			if not padBase then
				continue
			end

			local padPos = padBase.Position
			local candidates: { Player } = {}

			for _, player in ipairs(Players:GetPlayers()) do
				local state = PlayerStateService.GetPlayerState(player)
				if state == "Combat" or state == "Capturing" or state == "Immunity" then
					local char = player.Character
					if char then
						local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if hrp then
							local dist = (hrp.Position - padPos).Magnitude
							if dist <= PAD_RADIUS and math.abs(hrp.Position.Y - padPos.Y) <= 8 then
								if ProgressionService.HasAccess(player, m) then
									table.insert(candidates, player)
								end
							end
						end
					end
				end
			end

			if #candidates == 1 then
				local contender = candidates[1]
				local st = PlayerStateService.GetPlayerState(contender)
				if st == "Combat" or st == "Immunity" then
					PlayerStateService.Transition(contender, "Capturing")
				end
				MachineManager.UpdatePadProgress(m, contender, deltaTime)
			else
				MachineManager.UpdatePadProgress(m, nil, deltaTime)
			end
		end
	end)
end

return MachineManager
