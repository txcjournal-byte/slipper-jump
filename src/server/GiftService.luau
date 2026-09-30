--!strict
-- Darování předmětů mezi hráči na stejném serveru.
-- Pravidla: obdarovaný musí mít volné místo v domečku, max. 20 darů denně, jen jednosměrně.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Catalog = require(Shared.Catalog)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

type Offer = { Id: number, Giver: Player, Target: Player, Uid: number, ItemId: string, Expires: number }

local GiftService = {}

local offers: { [number]: Offer } = {}
local offerCounter = 0

local function today(): number
	return os.time() // 86400
end

local function giftsSentToday(session: Session): number
	if session.Data.GiftsSentDay ~= today() then
		return 0
	end
	return session.Data.GiftsSentToday
end

local function hasOpenSlot(session: Session): boolean
	return Registry.Items.FreeSlot(session) ~= nil
end

function GiftService.Request(giver: Player, target: Player)
	if giver == target then
		return
	end
	local giverSession = Registry.Player.Get(giver)
	local targetSession = Registry.Player.Get(target)
	if not giverSession or not targetSession then
		return
	end
	local carried = giverSession.Data.Carried
	if not carried then
		Registry.Player.Notify(giver, "Pick up an item first, then gift it!", "Info")
		return
	end
	local cfg = Catalog.Item(carried.Id)
	if not cfg or cfg.CanGift == false then
		Registry.Player.Notify(giver, "This item can't be gifted.", "Warning")
		return
	end
	if giftsSentToday(giverSession) >= Economy.GiftsPerDay then
		Registry.Player.Notify(giver, `You can send only {Economy.GiftsPerDay} gifts per day.`, "Warning")
		return
	end
	if not hasOpenSlot(targetSession) then
		Registry.Player.Notify(giver, target.DisplayName .. "'s house is full!", "Warning")
		return
	end
	for _, offer in offers do
		if offer.Giver == giver and offer.Expires > os.clock() then
			Registry.Player.Notify(giver, "Wait for the answer to your last gift.", "Info")
			return
		end
	end
	offerCounter += 1
	local offer: Offer = {
		Id = offerCounter,
		Giver = giver,
		Target = target,
		Uid = carried.Uid,
		ItemId = carried.Id,
		Expires = os.clock() + Economy.GiftOfferTimeout,
	}
	offers[offer.Id] = offer
	Net.Event("GiftOffer"):FireClient(target, { OfferId = offer.Id, From = giver.DisplayName, ItemId = carried.Id, Timeout = Economy.GiftOfferTimeout })
	Registry.Player.Notify(giver, "Gift offered to " .. target.DisplayName .. "!", "Info")
	task.delay(Economy.GiftOfferTimeout, function()
		offers[offer.Id] = nil
	end)
end

local function respond(target: Player, offerId: unknown, accepted: unknown)
	if type(offerId) ~= "number" then
		return
	end
	local offer = offers[offerId]
	if not offer or offer.Target ~= target or offer.Expires < os.clock() then
		return
	end
	offers[offerId] = nil
	local giver = offer.Giver
	if accepted ~= true then
		Registry.Player.Notify(giver, target.DisplayName .. " declined your gift.", "Info")
		return
	end
	local giverSession = Registry.Player.Get(giver)
	local targetSession = Registry.Player.Get(target)
	if not giverSession or not targetSession then
		return
	end
	local carried = giverSession.Data.Carried
	if not carried or carried.Uid ~= offer.Uid then
		Registry.Player.Notify(target, "The gift is no longer available.", "Warning")
		return
	end
	if not hasOpenSlot(targetSession) then
		Registry.Player.Notify(target, "Your house is full!", "Warning")
		return
	end
	if giftsSentToday(giverSession) >= Economy.GiftsPerDay then
		return
	end
	-- přesun předmětu
	local item = Registry.Items.TakeCarried(giverSession)
	if not item then
		return
	end
	if giverSession.Data.GiftsSentDay ~= today() then
		giverSession.Data.GiftsSentDay = today()
		giverSession.Data.GiftsSentToday = 0
	end
	giverSession.Data.GiftsSentToday += 1
	local newItem = { Id = item.Id, Uid = targetSession.Data.NextUid }
	targetSession.Data.NextUid += 1
	targetSession.Data.Discovered[item.Id] = true
	Registry.Items.Store(targetSession, newItem)
	local cfg = Catalog.Item(item.Id)
	local name = if cfg then cfg.Name else item.Id
	Registry.Player.Notify(giver, target.DisplayName .. " accepted your " .. name .. "!", "Success")
	Registry.Player.Notify(target, "You got " .. name .. " from " .. giver.DisplayName .. "!", "Success")
	Registry.Player.MarkDirty(giverSession)
	Registry.Player.MarkDirty(targetSession)
end

function GiftService.OnLeave(player: Player)
	for id, offer in offers do
		if offer.Giver == player or offer.Target == player then
			offers[id] = nil
		end
	end
end

function GiftService.Start()
	Net.Event("GiftRespond").OnServerEvent:Connect(respond)
end

return GiftService
