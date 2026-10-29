--!strict
local UserInputService = game:GetService("UserInputService")

local MachineHUD = {}

local modalFrame: Frame? = nil
local timerLabel: TextLabel? = nil
local timerThread: thread? = nil
local currentOnSelect: ((number) -> ())? = nil

local isSelectorOpen = false

local DIFFICULTY_NAMES = {
	[1] = "Novato",
	[2] = "Intermedio",
	[3] = "Avanzado",
	[4] = "Experto",
	[5] = "Cumbre",
}

local DIFFICULTY_COLORS = {
	[1] = Color3.fromRGB(46, 204, 113),
	[2] = Color3.fromRGB(52, 152, 219),
	[3] = Color3.fromRGB(155, 89, 182),
	[4] = Color3.fromRGB(230, 126, 34),
	[5] = Color3.fromRGB(241, 196, 15),
}

function MachineHUD.Init(parentGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "DifficultySelectorModal"
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if isMobile then
		modal.Size = UDim2.fromScale(0.86, 0.76)
		modal.Position = UDim2.fromScale(0.07, 0.12)
	else
		modal.Size = UDim2.fromScale(0.5, 0.6)
		modal.Position = UDim2.fromScale(0.25, 0.2)
	end
	modal.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	modalFrame = modal

	local mCorner = Instance.new("UICorner")
	mCorner.CornerRadius = UDim.new(0, 14)
	mCorner.Parent = modal

	local mStroke = Instance.new("UIStroke")
	mStroke.Color = Color3.fromRGB(0, 220, 255)
	mStroke.Thickness = 3
	mStroke.Parent = modal

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "ModalTitle"
	title.Size = UDim2.fromScale(1, 0.14)
	title.Position = UDim2.fromScale(0, 0.03)
	title.BackgroundTransparency = 1
	title.Text = "SELECCIONA LA DIFICULTAD"
	title.TextColor3 = Color3.fromRGB(0, 240, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = modal

	-- Giant Authoritative Timeout Countdown
	local tLabel = Instance.new("TextLabel")
	tLabel.Name = "GiantTimer"
	tLabel.Size = UDim2.fromScale(1, 0.12)
	tLabel.Position = UDim2.fromScale(0, 0.16)
	tLabel.BackgroundTransparency = 1
	tLabel.Text = "TIEMPO: 60s"
	tLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	tLabel.TextScaled = true
	tLabel.Font = Enum.Font.GothamBold
	tLabel.Parent = modal
	timerLabel = tLabel

	-- Button Container
	local btnContainer = Instance.new("Frame")
	btnContainer.Name = "ButtonGrid"
	btnContainer.Size = UDim2.fromScale(0.9, 0.65)
	btnContainer.Position = UDim2.fromScale(0.05, 0.3)
	btnContainer.BackgroundTransparency = 1
	btnContainer.Parent = modal

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = btnContainer
end

function MachineHUD.OpenSelector(
	_machineId: number,
	currentProgress: number,
	maxAllowedTime: number,
	onSelect: (number) -> ()
)
	if not modalFrame or isSelectorOpen then
		return
	end
	isSelectorOpen = true
	currentOnSelect = onSelect
	modalFrame.Visible = true

	local maxUnlocked = math.clamp(currentProgress + 1, 1, 5)

	-- Start Giant Countdown
	if timerThread and timerThread ~= coroutine.running() then
		task.cancel(timerThread)
		timerThread = nil
	end

	local startTime = os.clock()
	timerThread = task.spawn(function()
		while (os.clock() - startTime) < maxAllowedTime and isSelectorOpen do
			local remaining = maxAllowedTime - (os.clock() - startTime)
			if timerLabel then
				timerLabel.Text = string.format("TIEMPO: %ds", math.max(0, math.floor(remaining)))
			end
			task.wait(0.2)
		end
		if isSelectorOpen then
			MachineHUD.CloseSelector()
		end
	end)

	local btnContainer = modalFrame:FindFirstChild("ButtonGrid") :: Frame?
	if btnContainer then
		-- Clear old buttons
		for _, child in ipairs(btnContainer:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		for d = 1, 5 do
			local isUnlocked = d <= maxUnlocked
			local btn = Instance.new("TextButton")
			btn.Name = "DiffBtn_" .. d
			btn.Size = UDim2.fromScale(0.95, 0.16)
			btn.LayoutOrder = d
			btn.BorderSizePixel = 0
			btn.Font = Enum.Font.GothamBold
			btn.TextScaled = true

			local bCorner = Instance.new("UICorner")
			bCorner.CornerRadius = UDim.new(0, 8)
			bCorner.Parent = btn

			local diffColor = DIFFICULTY_COLORS[d] or Color3.fromRGB(150, 150, 150)

			if isUnlocked then
				btn.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
				btn.TextColor3 = diffColor
				btn.Text = string.format("Nivel %d: %s [DESBLOQUEADO]", d, DIFFICULTY_NAMES[d])

				local bStroke = Instance.new("UIStroke")
				bStroke.Color = diffColor
				bStroke.Thickness = 1.5
				bStroke.Parent = btn

				btn.Activated:Connect(function()
					MachineHUD.SelectDifficulty(d)
				end)
			else
				btn.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
				btn.TextColor3 = Color3.fromRGB(90, 95, 110)
				btn.Text = string.format("🔒 Nivel %d: %s (Supera Nivel %d)", d, DIFFICULTY_NAMES[d], d - 1)
				btn.AutoButtonColor = false
			end

			btn.Parent = btnContainer
		end
	end
end

function MachineHUD.SelectDifficulty(difficulty: number)
	if currentOnSelect then
		local cb = currentOnSelect
		MachineHUD.CloseSelector()
		cb(difficulty)
	end
end

function MachineHUD.CloseSelector()
	isSelectorOpen = false
	currentOnSelect = nil
	if timerThread and timerThread ~= coroutine.running() then
		task.cancel(timerThread)
		timerThread = nil
	end
	if modalFrame then
		modalFrame.Visible = false
	end
end

function MachineHUD.IsOpen(): boolean
	return isSelectorOpen
end

return MachineHUD
