--!strict
-- Obří dárek (odměny za doskok na 100 000 studů) a znovuzrození (Rebirth).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GiantGift = require(Shared.Config.GiantGift)
local Formulas = require(Shared.Formulas)
local Catalog = require(Shared.Catalog)
local FormatNumber = require(Shared.Util.FormatNumber)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

local RebirthService = {}

function RebirthService.OnGiftReached(session: Session)
	local data = session.Data
	local player: Player = session.Player
	local rewards = {}
	local first = not data.GiftEverOpened
	if first then
		data.GiftEverOpened = true
		Registry.Items.Give(session, GiantGift.FirstItem)
		Registry.Economy.AddMoney(session, GiantGift.FirstMoney)
		Registry.Shop.GrantHat(session, GiantGift.FirstHat)
		Registry.Level.AddTitle(session, GiantGift.FirstTitle)
		local item = Catalog.Item(GiantGift.FirstItem)
		local hat = Catalog.Hat(GiantGift.FirstHat)
		rewards = {
			if item then item.Name else GiantGift.FirstItem,
			FormatNumber.Money(GiantGift.FirstMoney),
			`Title "{GiantGift.FirstTitle}"`,
			if hat then hat.Name else GiantGift.FirstHat,
		}
	else
		Registry.Economy.AddMoney(session, GiantGift.RepeatMoney)
		local item = Registry.Items.GiveRandom(session, GiantGift.RepeatRarity)
		local cfg = Catalog.Item(item.Id)
		rewards = { FormatNumber.Money(GiantGift.RepeatMoney), if cfg then cfg.Name else item.Id }
	end
	data.GiftOpenedThisLife = true
	Registry.Player.MarkDirty(session)
	Registry.Player.Announce(player.DisplayName .. " reached the Giant Gift!", "Gift")
	Net.Event("OpenUI"):FireClient(player, "GiftOpened", { Rewards = rewards, First = first })
end

-- Dárkový ostrov (Bronze, Silver): odměna jednou za život
function RebirthService.OnIslandReached(session: Session, key: string)
	local data = session.Data
	local player: Player = session.Player
	local island
	for _, entry in GiantGift.Islands do
		if entry.Key == key then
			island = entry
		end
	end
	if not island or data.ClaimedGifts[key] then
		return
	end
	data.ClaimedGifts[key] = true
	local rewards = {}
	Registry.Economy.AddMoney(session, island.Money)
	table.insert(rewards, FormatNumber.Money(island.Money))
	local item = Registry.Items.GiveRandom(session, island.Rarity)
	local cfg = Catalog.Item(item.Id)
	table.insert(rewards, if cfg then cfg.Name else item.Id)
	if island.Hat then
		Registry.Shop.GrantHat(session, island.Hat)
		local hat = Catalog.Hat(island.Hat)
		table.insert(rewards, if hat then hat.Name else island.Hat)
	end
	if island.Title then
		Registry.Level.AddTitle(session, island.Title)
		table.insert(rewards, `Title "{island.Title}"`)
	end
	Registry.Player.MarkDirty(session)
	Registry.Player.Announce(`{player.DisplayName} reached the {island.Name}!`, "Gift")
	local nextIsland = Formulas.NextGiftIsland(data.ClaimedGifts)
	Net.Event("OpenUI"):FireClient(player, "GiftOpened", {
		Rewards = rewards,
		First = false,
		Title = `YOU REACHED THE {island.Name}!`,
		Next = if nextIsland then `Next: {nextIsland.Name} at {FormatNumber.Commas(nextIsland.Distance)} studs!` else "Next: the GIANT GIFT at 100,000 studs!",
	})
end

local function rebirth(player: Player)
	local session = Registry.Player.Get(player)
	if not session or session.Flight then
		return
	end
	local data = session.Data
	if not data.GiftOpenedThisLife then
		Registry.Player.Notify(player, "Reach the Giant Gift first!", "Warning")
		return
	end
	data.GiftOpenedThisLife = false
	data.ClaimedGifts = {} -- dárkové ostrovy se dají získat znovu
	data.Rebirths += 1
	data.Money = 0
	data.OwnedSlippers = { "BasicBlackSlippers" }
	data.EquippedSlippers = "BasicBlackSlippers" -- skiny tenisek (koupené za Robux) zůstávají
	local titles = GiantGift.RebirthTitles
	local title = titles[math.min(data.Rebirths, #titles)]
	if data.Rebirths > #titles then
		title ..= " " .. data.Rebirths
	end
	Registry.Level.AddTitle(session, title)
	Registry.Avatar.ApplyAll(session)
	Registry.House.Render(session)
	Registry.Player.MarkDirty(session)
	Registry.Player.Announce(`{player.DisplayName} was reborn! (Rebirth {data.Rebirths})`, "Gift")
	Net.Event("PlayEffect"):FireClient(player, "Rebirth", { Rebirths = data.Rebirths })
end

function RebirthService.Start()
	Net.Event("Rebirth").OnServerEvent:Connect(rebirth)
end

return RebirthService
