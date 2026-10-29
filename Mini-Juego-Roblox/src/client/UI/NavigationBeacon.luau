--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZonesConfig = require(ReplicatedStorage.Shared.Config.ZonesConfig)

local localPlayer = Players.LocalPlayer
local NavigationBeacon = {}

local currentZone = 1
local currentProgress = 0
local beaconGui: BillboardGui? = nil
local beaconPart: Part? = nil
local beaconText: TextLabel? = nil
local distanceText: TextLabel? = nil
local renderConn: RBXScriptConnection? = nil

function NavigationBeacon.Init(parentGui: ScreenGui)
	local part = Instance.new("Part")
	part.Name = "NavigationTargetAnchor"
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Parent = Workspace
	beaconPart = part

	local bb = Instance.new("BillboardGui")
	bb.Name = "ObjectiveBeacon"
	bb.Adornee = part
	bb.Size = UDim2.fromScale(5, 2.2)
	bb.StudsOffset = Vector3.new(0, 7, 0)
	bb.AlwaysOnTop = true
	bb.Parent = parentGui
	beaconGui = bb

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 240, 255)
	stroke.Thickness = 2
	stroke.Parent = frame

	local icon = Instance.new("TextLabel")
	icon.Name = "ArrowIcon"
	icon.Size = UDim2.fromScale(1, 0.35)
	icon.Position = UDim2.fromScale(0, 0.05)
	icon.BackgroundTransparency = 1
	icon.Text = "▼ OBJETIVO PRINCIPAL ▼"
	icon.TextColor3 = Color3.fromRGB(0, 255, 180)
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBlack
	icon.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "ObjectiveTitle"
	title.Size = UDim2.fromScale(0.95, 0.35)
	title.Position = UDim2.fromScale(0.025, 0.38)
	title.BackgroundTransparency = 1
	title.Text = "Captura la Máquina 1"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame
	beaconText = title

	local distLabel = Instance.new("TextLabel")
	distLabel.Name = "DistanceLabel"
	distLabel.Size = UDim2.fromScale(1, 0.25)
	distLabel.Position = UDim2.fromScale(0, 0.72)
	distLabel.BackgroundTransparency = 1
	distLabel.Text = "Distancia: 0m"
	distLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	distLabel.TextScaled = true
	distLabel.Font = Enum.Font.GothamMedium
	distLabel.Parent = frame
	distanceText = distLabel

	NavigationBeacon.UpdateTarget()

	renderConn = RunService.RenderStepped:Connect(function()
		local char = localPlayer.Character
		if not char or not beaconPart then
			return
		end
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end

		-- Real-time tracking of dynamic moving platform
		if currentProgress < 5 or currentZone >= 5 then
			local world = Workspace:FindFirstChild("World")
			local zone = world and world:FindFirstChild("Zones") and world.Zones:FindFirstChild("Zone_" .. currentZone)
			local padModel = zone and zone:FindFirstChild("CapturePad_" .. currentZone)
			local padBase = padModel and padModel:FindFirstChild("PadBase") :: BasePart?
			if padBase then
				beaconPart.CFrame = CFrame.new(padBase.Position + Vector3.new(0, 2, 0))
			end
		end

		local dist = (hrp.Position - beaconPart.Position).Magnitude
		if distanceText then
			distanceText.Text = string.format("Distancia: %d studs", math.floor(dist))
		end
	end)
end

function NavigationBeacon.UpdateProgress(zone: number, progress: number)
	currentZone = zone
	currentProgress = progress
	NavigationBeacon.UpdateTarget()
end

function NavigationBeacon.UpdateTarget()
	if not beaconPart or not beaconText then
		return
	end

	local zoneDef = ZonesConfig.GetByIndex(currentZone)
	if not zoneDef then
		return
	end

	if currentProgress >= 5 and currentZone < 5 then
		-- Target is the Gate to next zone
		local corridorGateX = zoneDef.Center.X + zoneDef.Size.X / 2 + 20
		beaconPart.CFrame = CFrame.new(corridorGateX, 5, 0)
		beaconText.Text = string.format("¡CRUZA A LA ZONA %d!", currentZone + 1)
	else
		-- Target is the Machine Capture Pad
		beaconPart.CFrame = CFrame.new(zoneDef.PadPosition + Vector3.new(0, 2, 0))
		beaconText.Text = string.format("MÁQUINA %d (Nivel %d/5)", currentZone, currentProgress)
	end
end

function NavigationBeacon.Destroy()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if beaconGui then
		beaconGui:Destroy()
		beaconGui = nil
	end
	if beaconPart then
		beaconPart:Destroy()
		beaconPart = nil
	end
end

return NavigationBeacon
