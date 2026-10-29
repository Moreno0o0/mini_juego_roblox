--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)
local ShopService = require(script.Parent.ShopService)

local ArenaEventManager = {}

local isRunning = false
local currentCoins: { [Part]: boolean } = {}
local defaultGravity = 196.2
local defaultSpeed = 16

local function SpawnEventCoins()
	local world = Workspace:FindFirstChild("World")
	local zones = world and world:FindFirstChild("Zones")
	if not zones then
		return
	end

	local coinFolder = Instance.new("Folder")
	coinFolder.Name = "EventCoins"
	coinFolder.Parent = Workspace

	-- Spawn 3 coins in each of the 5 zones
	for z = 1, 5 do
		local zone = zones:FindFirstChild("Zone_" .. z)
		local floor = zone and zone:FindFirstChild("Floor") :: BasePart?
		if floor then
			local floorPos = floor.Position
			for _ = 1, 3 do
				local offsetX = (math.random() - 0.5) * 60
				local offsetZ = (math.random() - 0.5) * 60
				local spawnPos = floorPos + Vector3.new(offsetX, 3.2, offsetZ)

				local coin = Instance.new("Part")
				coin.Name = "ArenaCoin"
				coin.Shape = Enum.PartType.Cylinder
				coin.Size = Vector3.new(0.6, 2.4, 2.4)
				coin.CFrame = CFrame.new(spawnPos) * CFrame.Angles(0, 0, math.rad(90))
				coin.Color = Color3.fromRGB(255, 215, 0)
				coin.Material = Enum.Material.Neon
				coin.Anchored = true
				coin.CanCollide = false
				coin.CanTouch = true
				coin.Parent = coinFolder
				currentCoins[coin] = true

				-- Touch collection
				local touchedConn: RBXScriptConnection? = nil
				touchedConn = coin.Touched:Connect(function(hit)
					local char = hit.Parent
					local player = char and Players:GetPlayerFromCharacter(char)
					if player and currentCoins[coin] then
						currentCoins[coin] = nil
						if touchedConn then
							touchedConn:Disconnect()
						end

						-- Reward player
						ShopService.AddCredits(player, 5)

						pcall(function()
							local soundRemote = Network.GetRemote("PlayClientSound")
							soundRemote:FireClient(player, "CoinPickup", 1.4)

							local syncRemote = Network.GetRemote("SyncState")
							syncRemote:FireClient(player, {
								CreditPopup = 5,
							})
						end)

						-- Visual burst and destroy
						coin.Transparency = 1
						local burst = Instance.new("Highlight")
						burst.FillColor = Color3.fromRGB(255, 255, 100)
						burst.OutlineColor = Color3.fromRGB(255, 215, 0)
						burst.Parent = coin

						task.delay(0.1, function()
							coin:Destroy()
						end)
					end
				end)
			end
		end
	end

	-- Despawn any uncollected coins after 24s
	task.delay(24, function()
		if coinFolder and coinFolder.Parent then
			coinFolder:Destroy()
		end
		currentCoins = {}
	end)
end

local function RunEvent(eventId: number)
	if eventId == 1 then
		-- 1. Lluvia de Monedas
		pcall(function()
			local eventRemote = Network.GetRemote("ArenaEventTriggered")
			eventRemote:FireAllClients({
				EventName = "🪙 LLUVIA DE CRÉDITOS",
				Description = "¡Monedas holográficas han caído por toda la arena! ¡Recógelas!",
				Duration = 24,
				Icon = "🪙",
			})
			local soundRemote = Network.GetRemote("PlayClientSound")
			soundRemote:FireAllClients("EventAlert", 1.2)
		end)
		SpawnEventCoins()
	elseif eventId == 2 then
		-- 2. Gravedad Cero Cibernética
		pcall(function()
			local eventRemote = Network.GetRemote("ArenaEventTriggered")
			eventRemote:FireAllClients({
				EventName = "🚀 GRAVEDAD CERO CIBERNÉTICA",
				Description = "¡Gravedad reducida a 65! Salta y domina el espacio aéreo.",
				Duration = 20,
				Icon = "🚀",
			})
			local soundRemote = Network.GetRemote("PlayClientSound")
			soundRemote:FireAllClients("EventAlert", 1.0)
		end)
		Workspace.Gravity = 65
		task.delay(20, function()
			Workspace.Gravity = defaultGravity
		end)
	elseif eventId == 3 then
		-- 3. Sobrecarga de Velocidad (Overdrive Surge)
		pcall(function()
			local eventRemote = Network.GetRemote("ArenaEventTriggered")
			eventRemote:FireAllClients({
				EventName = "⚡ SOBRECARGA DE VELOCIDAD",
				Description = "¡Todos los gladiadores reciben +60% de velocidad!",
				Duration = 20,
				Icon = "⚡",
			})
			local soundRemote = Network.GetRemote("PlayClientSound")
			soundRemote:FireAllClients("EventAlert", 1.3)
		end)

		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = 26
			end
		end

		task.delay(20, function()
			for _, p in ipairs(Players:GetPlayers()) do
				local char = p.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = defaultSpeed
				end
			end
		end)
	end
end

function ArenaEventManager.Init()
	if isRunning then
		return
	end
	isRunning = true

	task.spawn(function()
		task.wait(20) -- Initial calm period after match start
		local eventIndex = 1
		while isRunning do
			RunEvent(eventIndex)
			eventIndex = if eventIndex >= 3 then 1 else eventIndex + 1
			task.wait(75) -- Next event in 75 seconds
		end
	end)
end

return ArenaEventManager
