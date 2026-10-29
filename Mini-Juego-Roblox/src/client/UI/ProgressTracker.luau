--!strict
local ProgressTracker = {}

local zoneLabel: TextLabel? = nil
local stateBadge: TextLabel? = nil
local starsLabel: TextLabel? = nil
local captureBarFrame: Frame? = nil
local captureFill: Frame? = nil

local immunityCountdownThread: thread? = nil

local STATE_COLORS: { [string]: Color3 } = {
	Combat = Color3.fromRGB(255, 100, 40),
	Capturing = Color3.fromRGB(255, 200, 20),
	Playing = Color3.fromRGB(0, 220, 255),
	Immunity = Color3.fromRGB(120, 255, 180),
	Dead = Color3.fromRGB(180, 40, 40),
}

function ProgressTracker.Init(parentGui: ScreenGui)
	-- Top HUD Banner
	local topBar = Instance.new("Frame")
	topBar.Name = "TopHUD"
	topBar.Size = UDim2.fromScale(0.6, 0.07)
	topBar.Position = UDim2.fromScale(0.2, 0.015)
	topBar.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	topBar.BorderSizePixel = 0
	topBar.Parent = parentGui

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 10)
	bCorner.Parent = topBar

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(40, 50, 75)
	bStroke.Thickness = 2
	bStroke.Parent = topBar

	-- 1. Zone Display
	local zLabel = Instance.new("TextLabel")
	zLabel.Name = "ZoneLabel"
	zLabel.Size = UDim2.fromScale(0.3, 0.8)
	zLabel.Position = UDim2.fromScale(0.02, 0.1)
	zLabel.BackgroundTransparency = 1
	zLabel.Text = "ZONA 1: NOVATOS"
	zLabel.TextColor3 = Color3.fromRGB(180, 210, 255)
	zLabel.TextScaled = true
	zLabel.Font = Enum.Font.GothamBold
	zLabel.Parent = topBar
	zoneLabel = zLabel

	-- 2. State Badge
	local sBadge = Instance.new("TextLabel")
	sBadge.Name = "StateBadge"
	sBadge.Size = UDim2.fromScale(0.32, 0.76)
	sBadge.Position = UDim2.fromScale(0.34, 0.12)
	sBadge.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	sBadge.Text = "ESTADO: COMBATE"
	sBadge.TextColor3 = STATE_COLORS.Combat
	sBadge.TextScaled = true
	sBadge.Font = Enum.Font.GothamBlack
	sBadge.BorderSizePixel = 0

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 6)
	badgeCorner.Parent = sBadge

	sBadge.Parent = topBar
	stateBadge = sBadge

	-- 3. Stars / Progression Tracker
	local stLabel = Instance.new("TextLabel")
	stLabel.Name = "StarsLabel"
	stLabel.Size = UDim2.fromScale(0.32, 0.8)
	stLabel.Position = UDim2.fromScale(0.66, 0.1)
	stLabel.BackgroundTransparency = 1
	stLabel.Text = "Progreso: ☆☆☆☆☆ (0/5)"
	stLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	stLabel.TextScaled = true
	stLabel.Font = Enum.Font.GothamBold
	stLabel.Parent = topBar
	starsLabel = stLabel

	-- Screen Circular / Linear Capture Bar
	local capFrame = Instance.new("Frame")
	capFrame.Name = "CaptureOverlay"
	capFrame.Size = UDim2.fromScale(0.26, 0.05)
	capFrame.Position = UDim2.fromScale(0.37, 0.72)
	capFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	capFrame.BorderSizePixel = 0
	capFrame.Visible = false
	capFrame.Parent = parentGui
	captureBarFrame = capFrame

	local capCorner = Instance.new("UICorner")
	capCorner.CornerRadius = UDim.new(0, 8)
	capCorner.Parent = capFrame

	local capStroke = Instance.new("UIStroke")
	capStroke.Color = Color3.fromRGB(255, 200, 20)
	capStroke.Thickness = 2
	capStroke.Parent = capFrame

	local capLabel = Instance.new("TextLabel")
	capLabel.Name = "CapLabel"
	capLabel.Size = UDim2.fromScale(1, 0.5)
	capLabel.Position = UDim2.fromScale(0, -0.6)
	capLabel.BackgroundTransparency = 1
	capLabel.Text = "RECLAMANDO CABINA..."
	capLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	capLabel.TextScaled = true
	capLabel.Font = Enum.Font.GothamBold
	capLabel.Parent = capFrame

	local cFill = Instance.new("Frame")
	cFill.Name = "Fill"
	cFill.Size = UDim2.fromScale(0, 1)
	cFill.BackgroundColor3 = Color3.fromRGB(255, 210, 30)
	cFill.BorderSizePixel = 0
	cFill.Parent = capFrame
	captureFill = cFill

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = cFill
end

function ProgressTracker.UpdateZone(zoneName: string)
	if zoneLabel then
		zoneLabel.Text = string.upper(zoneName)
	end
end

function ProgressTracker.UpdateState(newState: string)
	if not stateBadge then
		return
	end

	if immunityCountdownThread then
		task.cancel(immunityCountdownThread)
		immunityCountdownThread = nil
	end

	local color = STATE_COLORS[newState] or Color3.fromRGB(200, 200, 200)
	stateBadge.TextColor3 = color

	if newState == "Immunity" then
		stateBadge.Text = "INMUNIDAD: 10.0s"
		immunityCountdownThread = task.spawn(function()
			local startTime = os.clock()
			while (os.clock() - startTime) < 10.0 do
				local remaining = 10.0 - (os.clock() - startTime)
				if stateBadge then
					stateBadge.Text = string.format("INMUNIDAD: %.1fs", math.max(0, remaining))
				end
				task.wait(0.1)
			end
			if stateBadge then
				stateBadge.Text = "COMBATE"
				stateBadge.TextColor3 = STATE_COLORS.Combat
			end
		end)
	else
		stateBadge.Text = "ESTADO: " .. string.upper(newState)
	end
end

function ProgressTracker.UpdateProgress(machineId: number, level: number)
	if not starsLabel then
		return
	end
	local filled = math.clamp(level, 0, 5)
	local starsStr = string.rep("★", filled) .. string.rep("☆", 5 - filled)
	starsLabel.Text = string.format("M%d: %s (%d/5)", machineId, starsStr, filled)
end

function ProgressTracker.SetCaptureProgress(fraction: number)
	if not captureBarFrame or not captureFill then
		return
	end
	local clamped = math.clamp(fraction, 0, 1)
	if clamped > 0 and clamped < 1 then
		captureBarFrame.Visible = true
		captureFill.Size = UDim2.fromScale(clamped, 1)
	else
		captureBarFrame.Visible = false
		captureFill.Size = UDim2.fromScale(0, 1)
	end
end

return ProgressTracker
