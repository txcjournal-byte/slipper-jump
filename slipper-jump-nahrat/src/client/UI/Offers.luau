--!strict
-- Kontextové nabídky: po novém osobním rekordu nebo když hráče chytí žralok se může ukázat
-- malá karta s JEDNÍM související passem nebo produktem.
-- Pravidla: nejvýš jednou za Products.OfferCooldown, nikdy během tutoriálu, jen založené produkty (Id ~= 0),
-- nic, co už hráč vlastní, neutrální text (žádné "Kup teď!", žádné odpočty) a vždy jde zavřít.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local RobuxShop = require(script.Parent.RobuxShop)
local ClientState = require(script.Parent.Parent.ClientState)
local Sound = require(script.Parent.Parent.Sound)

local Offers = {}

type Reason = "Record" | "Shark"

type Offer = { Key: string, Title: string, Text: string, Price: number, Color: Color3 }

local SHOW_DELAY = 1.5 -- sekundy po návratu na pláž
local PENDING_TIMEOUT = 60 -- nabídka, která se nestihla ukázat, propadne
local AUTO_HIDE = 15 -- karta sama zmizí

local card: Frame
local titleLabel: TextLabel
local textLabel: TextLabel
local buyButton: TextButton
local currentKey: string? = nil
local lastShown = -math.huge
local pending: Reason? = nil
local pendingAt = 0
local showToken = 0

local TITLES: { [Reason]: string } = {
	Record = "Want to jump even farther?",
	Shark = "That was close! Swim faster!",
}

-- Kandidáti podle situace (v pořadí, první vhodný vyhrává)
local CANDIDATES: { [Reason]: { string } } = {
	Record = { "SuperJumper", "MegaJumpPack" },
	Shark = { "TurboFins", "SharkRepellent" },
}

local function findProduct(key: string): (string?, number, Color3, boolean)
	for _, pass in Products.GamePasses do
		if pass.Key == key then
			return if pass.Id ~= 0 then pass.Name .. ": " .. pass.Description else nil, pass.Price, pass.Color, true
		end
	end
	for _, product in Products.DevProducts do
		if product.Key == key then
			return if product.Id ~= 0 then product.Name .. ": " .. product.Description else nil, product.Price, product.Color, false
		end
	end
	return nil, 0, Kit.Colors.Turquoise, false
end

local function pickOffer(reason: Reason, data: { [string]: any }): Offer?
	local passes = data.Passes or {}
	for _, key in CANDIDATES[reason] do
		local text, price, color, isPass = findProduct(key)
		local owned = isPass and passes[key] == true
		-- repelent nabízet jen tomu, kdo žádný nemá
		local stocked = key == "SharkRepellent" and (data.Repellents or 0) > 0
		if text and not owned and not stocked then
			return { Key = key, Title = TITLES[reason], Text = text, Price = price, Color = color }
		end
	end
	return nil
end

local function hide()
	showToken += 1
	card.Visible = false
	currentKey = nil
end

local function show(offer: Offer)
	lastShown = os.clock()
	currentKey = offer.Key
	titleLabel.Text = offer.Title
	textLabel.Text = offer.Text
	Kit.SetButtonText(buyButton, "R$ " .. offer.Price)
	card.BackgroundColor3 = Kit.Colors.Panel
	local header = card:FindFirstChild("Header") :: Frame?
	if header then
		header.BackgroundColor3 = offer.Color
	end
	card.Visible = true
	Kit.Pop(card, 1.08)
	showToken += 1
	local token = showToken
	task.delay(AUTO_HIDE, function()
		if token == showToken then
			hide()
		end
	end)
end

local function canOffer(data: { [string]: any }): boolean
	return data.TutorialDone == true and os.clock() - lastShown >= Products.OfferCooldown and not card.Visible
end

local function queue(reason: Reason)
	local data = ClientState.Get()
	if not canOffer(data) then
		return
	end
	pending = reason
	pendingAt = os.clock()
end

-- Ukázat až po návratu na pláž (ne během letu nebo plavání)
local function tryShowPending()
	local reason: Reason? = pending
	if not reason then
		return
	end
	local data = ClientState.Get()
	if os.clock() - pendingAt > PENDING_TIMEOUT or not canOffer(data) then
		pending = nil
		return
	end
	if data.Flying then
		return
	end
	pending = nil
	local offer = pickOffer(reason :: Reason, data)
	if not offer then
		return
	end
	local chosen: Offer = offer
	task.delay(SHOW_DELAY, function()
		local now = ClientState.Get()
		if not now.Flying and canOffer(now) then
			show(chosen)
		end
	end)
end

function Offers.Init(screen: ScreenGui)
	card = Kit.Panel(screen, {
		Name = "OfferCard",
		Size = UDim2.fromOffset(400, 190),
		Position = UDim2.new(1, -140, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		Visible = false,
		StrokeThickness = 3,
	})
	local header = Kit.new("Frame", {
		Name = "Header",
		BackgroundColor3 = Kit.Colors.Turquoise,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 0, 46),
		Position = UDim2.fromOffset(6, 6),
		Parent = card,
	})
	Kit.Corner(header, 12)
	Kit.Gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	titleLabel = Kit.Text(header, { Text = "", Size = UDim2.new(1, -70, 1, -10), Position = UDim2.fromOffset(10, 5), TextXAlignment = Enum.TextXAlignment.Left })
	textLabel = Kit.Text(card, {
		Text = "",
		Size = UDim2.new(1, -24, 0, 56),
		Position = UDim2.fromOffset(12, 58),
		TextColor3 = Kit.Colors.Text,
		NoStroke = true,
		TextWrapped = true,
	})
	buyButton = Kit.Button(card, { Text = "R$ 0", Color = Kit.Colors.Green, Size = UDim2.new(0.5, -18, 0, 54), Position = UDim2.new(0, 12, 1, -64) }, function()
		Sound.Play("Click")
		local key = currentKey
		hide()
		if key then
			RobuxShop.PromptKey(key)
		end
	end)
	Kit.Button(card, { Text = "No thanks", Color = Kit.Colors.Gray, Size = UDim2.new(0.5, -18, 0, 54), Position = UDim2.new(0.5, 6, 1, -64) }, function()
		Sound.Play("Click")
		hide()
	end)
	local close = Kit.Button(card, { Text = "X", Color = Kit.Colors.Coral, Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, 10, 0, -10), AnchorPoint = Vector2.new(1, 0), Name = "Close" }, function()
		hide()
	end)
	close.ZIndex = 5

	-- spouštěče (server posílá výsledky; klient jen rozhoduje, jestli nabídku ukázat)
	Net.Event("JumpResult").OnClientEvent:Connect(function(result: { [string]: any })
		if result.PersonalRecord and not result.ReachedGift then
			queue("Record")
		end
	end)
	Net.Event("SwimResult").OnClientEvent:Connect(function(result: { [string]: any })
		if result.Reason == "Shark" then
			queue("Shark")
		end
	end)
	ClientState.Changed:Connect(function(data)
		if data.Flying and card.Visible then
			hide() -- při skoku kartu schovat
		end
		tryShowPending()
	end)
	-- pojistka, kdyby po návratu nepřišel nový stav
	task.spawn(function()
		while true do
			task.wait(1)
			tryShowPending()
		end
	end)
end

return Offers
