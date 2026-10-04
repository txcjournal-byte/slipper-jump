--!strict
-- Okno obchodu a inventáře: pantofle, čepice, sklad předmětů a katalog (Index).
-- U stánku SHOP se dá kupovat, jinde jen oblékat.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Catalog)
local Models = require(Shared.Models)
local Jump = require(Shared.Config.Jump)
local Swim = require(Shared.Config.Swim)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local HUD = require(script.Parent.HUD)
local ClientState = require(script.Parent.Parent.ClientState)
local Sound = require(script.Parent.Parent.Sound)
local Purchase = require(script.Parent.Parent.Purchase)
local Products = require(Shared.Config.Products)

local Shop = {}

type Tab = "Slippers" | "Sneakers" | "Hats" | "Swim" | "Storage" | "Index"

local window: Kit.Window
local tabButtons: { [string]: TextButton } = {}
local pages: { [string]: ScrollingFrame } = {}
local slipperCards: { [string]: { Button: TextButton, Status: TextLabel } } = {}
local hatCards: { [string]: { Button: TextButton, Status: TextLabel } } = {}
local indexCards: { [string]: { Name: TextLabel, Viewport: ViewportFrame, Built: boolean } } = {}
local indexProgress: TextLabel
local storagePage: ScrollingFrame
local atShop = false
local currentTab: Tab = "Slippers"
local shopAction = Net.Function("ShopAction")

local function action(kind: string, verb: string, id: string)
	local result = shopAction:InvokeServer(verb, kind, id)
	if result then
		HUD.Notify(result.Message, if result.Ok then "Success" else "Warning")
		if result.Ok and verb == "Buy" then
			Sound.Play("Buy")
		end
	end
end

local function card(parent: Instance, order: number, color: Color3): Frame
	local frame = Kit.Panel(parent, {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		LayoutOrder = order,
		StrokeThickness = 3,
		Radius = 16,
	})
	local top = Kit.new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.new(1, -12, 0, 118),
		Position = UDim2.fromOffset(6, 6),
		Parent = frame,
	})
	Kit.Corner(top, 12)
	Kit.Gradient(top, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	top.Name = "Top"
	return frame
end

local skinCards: { [string]: { Button: TextButton, Status: TextLabel, Index: number } } = {}

local function ownsSkin(data: { [string]: any }, id: string): boolean
	return id == Products.FreeSkin or table.find(data.OwnedSkins or {}, id) ~= nil or (data.Passes and data.Passes.AllSneakers == true)
end

local function buildSlippers(page: ScrollingFrame, line: { any })
	local skins = line == Catalog.Sneakers
	for index, cfg in line do
		local frame = card(page, index, cfg.Color:Lerp(Color3.new(1, 1, 1), 0.55))
		local top = frame:FindFirstChild("Top") :: Frame
		local model = Models.Slipper(cfg.Id)
		Kit.Viewport(top, model)
		Kit.Text(frame, { Text = cfg.Name, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 128), TextColor3 = Kit.Colors.Text, NoStroke = true })
		if skins then
			-- tenisky = skiny za Robux: mění jen vzhled, skok je pořád z pantoflí
			Kit.Text(frame, { Text = "✨ SKIN  •  " .. cfg.EffectText, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 156), TextColor3 = Kit.Colors.Purple, NoStroke = true })
			local status = Kit.Text(frame, { Text = "Looks only – your jump stays the same", Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 180), TextColor3 = Kit.Colors.Gray, NoStroke = true })
			local button = Kit.Button(frame, { Text = "", Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, -58), Color = Kit.Colors.Green })
			button.Activated:Connect(function()
				Sound.Play("Click")
				local data = ClientState.Get()
				if ownsSkin(data, cfg.Id) then
					action("Skin", "Equip", if data.EquippedSkin == cfg.Id then "" else cfg.Id)
				elseif not Purchase.Skin(cfg.Id, index) then
					HUD.Notify("Skins are coming soon!", "Info")
				end
			end)
			skinCards[cfg.Id] = { Button = button, Status = status, Index = index }
		else
			local distance = Jump.BaseDistance * cfg.Multiplier
			Kit.Text(frame, { Text = "x" .. cfg.Multiplier .. "  •  " .. FormatNumber.Studs(distance), Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 156), TextColor3 = Kit.Colors.Blue, NoStroke = true })
			local status = Kit.Text(frame, { Text = cfg.EffectText, Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 180), TextColor3 = Kit.Colors.Gray, NoStroke = true })
			local button = Kit.Button(frame, { Text = "", Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, -58), Color = Kit.Colors.Green })
			button.Activated:Connect(function()
				local data = ClientState.Get()
				local owned = table.find(data.OwnedSlippers or {}, cfg.Id) ~= nil
				action("Slippers", if owned then "Equip" else "Buy", cfg.Id)
			end)
			slipperCards[cfg.Id] = { Button = button, Status = status }
		end
	end
end

local function hatBonusText(cfg: any): string
	local parts = {}
	if cfg.JumpBonus > 0 then
		table.insert(parts, "+" .. math.floor(cfg.JumpBonus * 100 + 0.5) .. "% jump")
	end
	if cfg.IncomeBonus > 0 then
		table.insert(parts, "+" .. math.floor(cfg.IncomeBonus * 100 + 0.5) .. "% money")
	end
	return table.concat(parts, "  ")
end

local function buildHats(page: ScrollingFrame)
	for index, cfg in Catalog.Hats do
		local frame = card(page, index, cfg.Color:Lerp(Color3.new(1, 1, 1), 0.55))
		local top = frame:FindFirstChild("Top") :: Frame
		Kit.Viewport(top, Models.Hat(cfg.Id))
		Kit.Text(frame, { Text = cfg.Name, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 128), TextColor3 = Kit.Colors.Text, NoStroke = true })
		Kit.Text(frame, { Text = hatBonusText(cfg), Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 156), TextColor3 = if cfg.JumpBonus > 0 then Kit.Colors.Blue else Color3.fromRGB(40, 160, 70), NoStroke = true })
		local status = Kit.Text(frame, { Text = cfg.Source or "", Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 180), TextColor3 = Kit.Colors.Gray, NoStroke = true })
		local button = Kit.Button(frame, { Text = "", Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, -58), Color = Kit.Colors.Green })
		button.Activated:Connect(function()
			local data = ClientState.Get()
			local owned = table.find(data.OwnedHats or {}, cfg.Id) ~= nil
			if owned then
				action("Hats", "Equip", if data.EquippedHat == cfg.Id then "" else cfg.Id)
			else
				action("Hats", "Buy", cfg.Id)
			end
		end)
		hatCards[cfg.Id] = { Button = button, Status = status }
	end
end

local function buildIndex(page: ScrollingFrame)
	-- nahoře: kolik předmětů z každé vzácnosti už hráč našel (celá vzácnost = točení zdarma)
	local header = Kit.Panel(page, { BackgroundColor3 = Kit.Colors.Navy, LayoutOrder = 0, StrokeThickness = 3, Radius = 16 })
	Kit.Text(header, { Text = "📖 ALBUM", Size = UDim2.new(1, -12, 0, 34), Position = UDim2.fromOffset(6, 8), TextColor3 = Kit.Colors.Yellow })
	indexProgress = Kit.Text(header, { Text = "", Size = UDim2.new(1, -16, 0, 150), Position = UDim2.fromOffset(8, 46), TextColor3 = Kit.Colors.White, StrokeThickness = 1.5, TextWrapped = true, TextScaled = true })
	Kit.Text(header, { Text = "Find every item of a rarity for free Spins!", Size = UDim2.new(1, -12, 0, 44), Position = UDim2.new(0, 6, 1, -50), TextColor3 = Kit.Colors.Turquoise, StrokeThickness = 1.5, TextWrapped = true })
	for index, cfg in Catalog.Items do
		local rarity = Catalog.Rarity(cfg.Rarity)
		local frame = card(page, index, if rarity.Name == "Secret" then Color3.fromRGB(70, 60, 90) else rarity.Color)
		local top = frame:FindFirstChild("Top") :: Frame
		local viewport = Kit.Viewport(top, nil)
		local name = Kit.Text(frame, { Text = cfg.Name, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 128), TextColor3 = Kit.Colors.Text, NoStroke = true })
		Kit.Text(frame, { Text = rarity.Name, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 156), TextColor3 = if rarity.Name == "Secret" then Color3.fromRGB(120, 60, 200) else rarity.Color, StrokeThickness = 1.5 })
		Kit.Text(frame, { Text = "+" .. FormatNumber.Money(cfg.Income) .. "/s", Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 182), TextColor3 = Color3.fromRGB(40, 160, 70), NoStroke = true })
		indexCards[cfg.Id] = { Name = name, Viewport = viewport, Built = false }
	end
end

local function refreshStorage(data: { [string]: any })
	for _, child in storagePage:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local storage = data.Storage or {}
	if #storage == 0 then
		local empty = Kit.Panel(storagePage, { BackgroundColor3 = Kit.Colors.PanelDark, LayoutOrder = 0 })
		Kit.Text(empty, { Text = "Storage is empty", Size = UDim2.new(1, -12, 0.4, 0), Position = UDim2.fromScale(0, 0.3), TextColor3 = Kit.Colors.Gray, NoStroke = true })
		return
	end
	for index, item in storage do
		local cfg = Catalog.Item(item.Id)
		if cfg then
			local rarity = Catalog.Rarity(cfg.Rarity)
			local frame = card(storagePage, index, rarity.Color)
			local top = frame:FindFirstChild("Top") :: Frame
			Kit.Viewport(top, Models.Item(cfg.Id))
			Kit.Text(frame, { Text = cfg.Name, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 128), TextColor3 = Kit.Colors.Text, NoStroke = true })
			Kit.Text(frame, { Text = "+" .. FormatNumber.Money(cfg.Income) .. "/s", Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 156), TextColor3 = Color3.fromRGB(40, 160, 70), NoStroke = true })
			local button = Kit.Button(frame, { Text = "HOLD", Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, -58), Color = Kit.Colors.Orange })
			button.Activated:Connect(function()
				if ClientState.Get().Carried then
					HUD.Notify("Your hands are full!", "Warning")
					return
				end
				Net.Event("HoldStoredItem"):FireServer(item.Uid)
				window.Close()
			end)
		end
	end
end

local swimCards: { [number]: TextButton } = {}

local function buildSwim(page: ScrollingFrame)
	for index, upgrade in Swim.Upgrades do
		local frame = card(page, index, upgrade.Color)
		local top = frame:FindFirstChild("Top") :: Frame
		Kit.Text(top, { Text = "SWIM", Size = UDim2.fromScale(0.8, 0.5), Position = UDim2.fromScale(0.1, 0.25), StrokeThickness = 3 })
		Kit.Text(frame, { Text = upgrade.Name, Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 128), TextColor3 = Kit.Colors.Text, NoStroke = true })
		Kit.Text(frame, { Text = "Swim speed " .. upgrade.Speed, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 156), TextColor3 = Kit.Colors.Blue, NoStroke = true })
		Kit.Text(frame, { Text = "Outswim sharks & sea monsters!", Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 180), TextColor3 = Kit.Colors.Gray, NoStroke = true })
		local button = Kit.Button(frame, { Text = "", Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 1, -58), Color = Kit.Colors.Green })
		button.Activated:Connect(function()
			action("Swim", "Buy", upgrade.Id)
		end)
		swimCards[index] = button
	end
end

local function refresh(data: { [string]: any })
	if not window or ClientState.Data == nil then
		return
	end
	for id, entry in skinCards do
		local owned = ownsSkin(data, id)
		local wearing = data.EquippedSkin == id
		entry.Button.BackgroundColor3 = if wearing then Kit.Colors.Gray elseif owned then Kit.Colors.Blue else Kit.Colors.Green
		Kit.SetButtonText(entry.Button, if wearing then "TAKE OFF" elseif owned then "WEAR" else "R$ " .. Purchase.Price("SkinTier" .. Products.SkinTier(entry.Index)))
	end
	for _, cfg in Catalog.Slippers do
		local entry = slipperCards[cfg.Id]
		local owned = table.find(data.OwnedSlippers, cfg.Id) ~= nil
		local equipped = data.EquippedSlippers == cfg.Id
		entry.Button.BackgroundColor3 = if equipped then Kit.Colors.Gray elseif owned then Kit.Colors.Blue elseif data.Money >= cfg.Price then Kit.Colors.Green else Kit.Colors.Coral
		Kit.SetButtonText(entry.Button, if equipped then "EQUIPPED" elseif owned then "EQUIP" elseif not atShop then "AT SHOP " .. FormatNumber.Money(cfg.Price) elseif cfg.Price == 0 then "FREE" else FormatNumber.Money(cfg.Price))
	end
	local swimLevel = data.SwimLevel or 0
	for index, button in swimCards do
		local upgrade = Swim.Upgrades[index]
		if index <= swimLevel then
			Kit.SetButtonText(button, "OWNED")
			button.BackgroundColor3 = Kit.Colors.Gray
		elseif index == swimLevel + 1 then
			Kit.SetButtonText(button, if atShop then FormatNumber.Money(upgrade.Price) else "AT SHOP " .. FormatNumber.Money(upgrade.Price))
			button.BackgroundColor3 = if data.Money >= upgrade.Price then Kit.Colors.Green else Kit.Colors.Coral
		else
			Kit.SetButtonText(button, "LOCKED")
			button.BackgroundColor3 = Kit.Colors.Gray
		end
	end
	for _, cfg in Catalog.Hats do
		local entry = hatCards[cfg.Id]
		local owned = table.find(data.OwnedHats, cfg.Id) ~= nil
		local equipped = data.EquippedHat == cfg.Id
		local price = cfg.Price
		entry.Button.BackgroundColor3 = if equipped then Kit.Colors.Gray elseif owned then Kit.Colors.Blue elseif price and data.Money >= price then Kit.Colors.Green else Kit.Colors.Coral
		local text: string
		if equipped then
			text = "TAKE OFF"
		elseif owned then
			text = "EQUIP"
		elseif price == nil then
			text = "LOCKED"
		elseif not atShop then
			text = "AT SHOP " .. FormatNumber.Money(price)
		else
			text = FormatNumber.Money(price)
		end
		Kit.SetButtonText(entry.Button, text)
	end
	-- katalog
	local discovered = data.Discovered or {}
	local counts: { [string]: { Found: number, Total: number } } = {}
	for _, cfg in Catalog.Items do
		if cfg.CanDrop ~= false then
			local c = counts[cfg.Rarity] or { Found = 0, Total = 0 }
			c.Total += 1
			if discovered[cfg.Id] then
				c.Found += 1
			end
			counts[cfg.Rarity] = c
		end
	end
	local lines = {}
	for _, rarity in Catalog.Rarities do
		local c = counts[rarity.Name]
		if c then
			table.insert(lines, `{rarity.Name} {c.Found}/{c.Total}{if c.Found >= c.Total then " ✅" else ""}`)
		end
	end
	if indexProgress then
		indexProgress.Text = table.concat(lines, "\n")
	end
	for _, cfg in Catalog.Items do
		local entry = indexCards[cfg.Id]
		local found = discovered[cfg.Id] == true
		if found and not entry.Built then
			entry.Built = true
			local model = Models.Item(cfg.Id)
			model:PivotTo(CFrame.identity)
			Kit.Viewport(entry.Viewport.Parent :: Instance, model)
			entry.Viewport:Destroy()
		end
		if found then
			entry.Name.Text = cfg.Name
		elseif cfg.Rarity == "Secret" then
			entry.Name.Text = "???"
		else
			entry.Name.Text = cfg.Name .. " (not found)"
		end
	end
	if currentTab == "Storage" then
		refreshStorage(data)
	end
end

local function showTab(tab: Tab)
	currentTab = tab
	for name, page in pages do
		page.Visible = name == tab
	end
	for name, button in tabButtons do
		-- vybraná záložka žlutá, ostatní modré; text vždy bílý, aby byl dobře čitelný
		button.BackgroundColor3 = if name == tab then Kit.Colors.Yellow else Kit.Colors.Blue
		local label = button:FindFirstChild("Label") :: TextLabel?
		if label then
			label.TextColor3 = Kit.Colors.White
		end
	end
	if tab == "Storage" then
		refreshStorage(ClientState.Get())
	end
end

function Shop.Init(screen: ScreenGui)
	window = Kit.Window(screen, "SHOP", UDim2.fromOffset(980, 640), Kit.Colors.Coral)
	local tabs = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Parent = window.Content })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), Parent = tabs })
	local body = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -66), Position = UDim2.fromOffset(0, 66), Parent = window.Content })
	for i, name in { "Slippers", "Sneakers", "Hats", "Swim", "Storage", "Index" } do
		local button = Kit.Button(tabs, { Text = name, Size = UDim2.fromOffset(148, 52), LayoutOrder = i, Color = Kit.Colors.Blue })
		button.Activated:Connect(function()
			Sound.Play("Click")
			showTab(name :: Tab)
		end)
		tabButtons[name] = button
		local page = Kit.Grid(body, UDim2.fromOffset(210, 262))
		page.Visible = false
		pages[name] = page
	end
	buildSlippers(pages.Slippers, Catalog.Slippers)
	buildSlippers(pages.Sneakers, Catalog.Sneakers)
	buildSwim(pages.Swim)
	buildHats(pages.Hats)
	storagePage = pages.Storage
	buildIndex(pages.Index)
	ClientState.Changed:Connect(refresh)
	refresh(ClientState.Get())
	showTab("Slippers")
end

function Shop.Open(fromStall: boolean, tab: Tab?)
	atShop = fromStall
	window.Title.Text = if fromStall then "SHOP" else "MY STUFF"
	local data = ClientState.Data
	if data then
		refresh(data)
	end
	showTab(tab or (if fromStall then "Slippers" else currentTab))
	window.Open()
end

function Shop.Toggle()
	if window.IsOpen() then
		window.Close()
	else
		Shop.Open(false)
	end
end


return Shop
