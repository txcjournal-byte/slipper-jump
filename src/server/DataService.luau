--!strict
-- Ukládání dat hráčů přes ProfileStore (session locking, automatické ukládání).
-- Ukládá se při odchodu a každých Economy.SaveInterval sekund.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local ProfileStore = require(script.Parent.Packages.ProfileStore)

export type ItemData = { Id: string, Uid: number }

export type Data = {
	Money: number,
	TotalEarned: number,
	OwnedSlippers: { string },
	EquippedSlippers: string,
	OwnedHats: { string },
	EquippedHat: string,
	HouseSlots: { [string]: ItemData },
	Carried: ItemData?,
	Storage: { ItemData },
	PendingCash: number,
	Level: number,
	XP: number,
	Rebirths: number,
	GiftEverOpened: boolean,
	GiftOpenedThisLife: boolean,
	Titles: { string },
	Title: string,
	BestJump: number,
	TotalJumps: number,
	DailyPeriodStart: number,
	DailySpinsUsed: number,
	ExtraSpins: number,
	BoostUntil: number,
	TutorialDone: boolean,
	TutorialStep: number,
	UsedCodes: { [string]: boolean },
	LastLogout: number,
	GiftsSentDay: number,
	GiftsSentToday: number,
	Settings: { Music: boolean, Sfx: boolean },
	PurchaseIds: { string },
	Discovered: { [string]: boolean },
	NextUid: number,
	SuperJumps: number,
}

local TEMPLATE: Data = {
	Money = Economy.StartingMoney,
	TotalEarned = 0,
	OwnedSlippers = { "BasicBlackSlippers" },
	EquippedSlippers = "BasicBlackSlippers",
	OwnedHats = {},
	EquippedHat = "",
	HouseSlots = {},
	Carried = nil,
	Storage = {},
	PendingCash = 0,
	Level = 1,
	XP = 0,
	Rebirths = 0,
	GiftEverOpened = false,
	GiftOpenedThisLife = false,
	Titles = {},
	Title = "",
	BestJump = 0,
	TotalJumps = 0,
	DailyPeriodStart = 0,
	DailySpinsUsed = 0,
	ExtraSpins = 0,
	BoostUntil = 0,
	TutorialDone = false,
	TutorialStep = 1,
	UsedCodes = {},
	LastLogout = 0,
	GiftsSentDay = 0,
	GiftsSentToday = 0,
	Settings = { Music = true, Sfx = true },
	PurchaseIds = {},
	Discovered = {},
	NextUid = 1,
	SuperJumps = 0,
}

local store = ProfileStore.New("SlipperJump_PlayerData_v1", TEMPLATE)

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }

function DataService.Load(player: Player): any?
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("We could not load your data. Please rejoin!")
		return nil
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		DataService.Profiles[player] = nil
		player:Kick("Your data was opened on another server. Please rejoin!")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end
	DataService.Profiles[player] = profile
	return profile
end

function DataService.Release(player: Player)
	local profile = DataService.Profiles[player]
	if profile then
		DataService.Profiles[player] = nil
		profile:EndSession()
	end
end

function DataService.Start()
	-- průběžné ukládání
	task.spawn(function()
		while true do
			task.wait(Economy.SaveInterval)
			for _, profile in DataService.Profiles do
				if profile:IsActive() then
					profile:Save()
				end
			end
		end
	end)
end

return DataService
