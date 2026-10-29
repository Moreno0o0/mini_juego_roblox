--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Network = require(ReplicatedStorage.Shared.Network)
local SoundManager = require(script.Parent.Parent.SoundManager)

local ShopGUI = {}

local shopFrame: Frame? = nil
local creditsLabel: TextLabel? = nil
local currentCredits = ShopConfig.StartingCredits
local isOpen = false

function ShopGUI.Init(parentGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "CyberShopModal"
	modal.Size = UDim2.fromScale(0.68, 0.72)
	modal.Position = UDim2.fromScale(0.16, 0.14)
	modal.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = parentGui
	shopFrame = modal

	local mCorner = Instance.new("UICorner")
	mCorner.CornerRadius = UDim.new(0, 16)
	mCorner.Parent = modal

	local mStroke = Instance.new("UIStroke")
	mStroke.Color = Color3.fromRGB(255, 215, 0)
	mStroke.Thickness = 2.5
	mStroke.Parent = modal

	-- Header Bar
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromScale(1, 0.14)
	header.BackgroundColor3 = Color3.fromRGB(22, 28, 42)
	header.BorderSizePixel = 0
	header.Parent = modal

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 16)
	hCorner.Parent = header

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(0.5, 0.8)
	title.Position = UDim2.fromScale(0.04, 0.1)
	title.BackgroundTransparency = 1
	title.Text = "🛒 CYBER-SHOP: ARMAS & INMUNIDAD"
	title.TextColor3 = Color3.fromRGB(255, 220, 60)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = header

	-- Credit Display
	local cLabel = Instance.new("TextLabel")
	cLabel.Name = "CreditLabel"
	cLabel.Size = UDim2.fromScale(0.3, 0.75)
	cLabel.Position = UDim2.fromScale(0.56, 0.12)
	cLabel.BackgroundColor3 = Color3.fromRGB(30, 38, 55)
	cLabel.Text = string.format("🪙 %d CRÉDITOS", currentCredits)
	cLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	cLabel.TextScaled = true
	cLabel.Font = Enum.Font.GothamBold
	cLabel.BorderSizePixel = 0
	cLabel.Parent = header
	creditsLabel = cLabel

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = cLabel

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.fromScale(0.08, 0.7)
	closeBtn.Position = UDim2.fromScale(0.89, 0.15)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "✕"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBlack
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = header

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 8)
	cbCorner.Parent = closeBtn

	closeBtn.Activated:Connect(function()
		SoundManager.PlayButtonClick()
		ShopGUI.Close()
	end)

	-- Scrollable Items Grid
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ItemsScroll"
	scroll.Size = UDim2.fromScale(0.92, 0.8)
	scroll.Position = UDim2.fromScale(0.04, 0.17)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.Parent = modal

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(260, 130)
	gridLayout.CellPadding = UDim2.fromOffset(14, 14)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scroll

	local order = 1
	for itemId, item in pairs(ShopConfig.Items) do
		local card = Instance.new("Frame")
		card.Name = "ItemCard_" .. itemId
		card.BackgroundColor3 = Color3.fromRGB(22, 27, 40)
		card.BorderSizePixel = 0
		card.LayoutOrder = order
		order += 1
		card.Parent = scroll

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = if item.Category == "Immunity" then Color3.fromRGB(120, 255, 180) elseif item.Category == "Weapon" then Color3.fromRGB(255, 100, 50) else Color3.fromRGB(0, 200, 255)
		cardStroke.Thickness = 1.5
		cardStroke.Parent = card

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ItemName"
		nameLabel.Size = UDim2.fromScale(0.92, 0.26)
		nameLabel.Position = UDim2.fromScale(0.04, 0.05)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = item.Name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "ItemDesc"
		descLabel.Size = UDim2.fromScale(0.92, 0.35)
		descLabel.Position = UDim2.fromScale(0.04, 0.31)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = item.Description
		descLabel.TextColor3 = Color3.fromRGB(170, 180, 205)
		descLabel.TextScaled = true
		descLabel.Font = Enum.Font.Gotham
		descLabel.Parent = card

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyBtn"
		buyBtn.Size = UDim2.fromScale(0.92, 0.28)
		buyBtn.Position = UDim2.fromScale(0.04, 0.67)
		buyBtn.BackgroundColor3 = Color3.fromRGB(35, 120, 75)
		buyBtn.TextColor3 = Color3.fromRGB(240, 255, 240)
		buyBtn.Text = string.format("COMPRAR - %d 🪙", item.Price)
		buyBtn.TextScaled = true
		buyBtn.Font = Enum.Font.GothamBlack
		buyBtn.BorderSizePixel = 0
		buyBtn.Parent = card

		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 6)
		buyCorner.Parent = buyBtn

		buyBtn.Activated:Connect(function()
			SoundManager.PlayButtonClick()
			-- Bounce tween
			local origSize = buyBtn.Size
			buyBtn.Size = UDim2.fromScale(origSize.X.Scale * 0.95, origSize.Y.Scale * 0.95)
			task.delay(0.08, function()
				if buyBtn and buyBtn.Parent then
					buyBtn.Size = origSize
				end
			end)

			local buyRemote = Network.GetRemote("RequestShopPurchase")
			buyRemote:FireServer(itemId)
		end)
	end

	-- Listen for purchase result
	local resultRemote = Network.GetRemote("ShopPurchaseResult")
	resultRemote.OnClientEvent:Connect(function(success: any, _itemId: any, newCredits: any)
		if success and typeof(newCredits) == "number" then
			SoundManager.PlayCoin()
			ShopGUI.UpdateCredits(newCredits)
		end
	end)
end

function ShopGUI.UpdateCredits(credits: number)
	currentCredits = credits
	if creditsLabel then
		creditsLabel.Text = string.format("🪙 %d CRÉDITOS", credits)
	end
end

function ShopGUI.Open()
	if shopFrame then
		isOpen = true
		shopFrame.Visible = true
		SoundManager.PlayButtonClick()
		ShopGUI.UpdateCredits(currentCredits)
	end
end

function ShopGUI.Close()
	if shopFrame then
		isOpen = false
		shopFrame.Visible = false
	end
end

function ShopGUI.Toggle()
	if isOpen then
		ShopGUI.Close()
	else
		ShopGUI.Open()
	end
end

return ShopGUI
