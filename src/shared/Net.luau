--!strict
-- Všechny RemoteEventy a RemoteFunctiony na jednom místě. Server je vytvoří, klient na ně počká.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"State", -- server → klient: snapshot dat hráče
	"Notify", -- server → klient: krátká hláška
	"Announce", -- server → všichni: velká hláška
	"JumpCharge", -- klient → server: začal držet JUMP
	"JumpRelease", -- klient → server: pustil JUMP (hodnota ukazatele)
	"FlightStart", -- server → klient: parametry letu, mince, kruhy
	"FlightLanded", -- klient → server: posbírané mince a kruhy
	"JumpResult", -- server → klient: výsledek skoku
	"PlayEffect", -- server → klienti: efekt (konfety, šplouchnutí...)
	"ConfirmSell", -- server ↔ klient: potvrzení prodeje vzácného předmětu
	"GiftOffer", -- server → klient: nabídka daru
	"GiftRespond", -- klient → server: Accept / Decline
	"OpenUI", -- server → klient: otevřít okno (Shop, Spinner)
	"WelcomeBack", -- server → klient: příjem offline
	"LevelUp", -- server → klient
	"Leaderboard", -- server → klient: data žebříčků (pro UI)
	"SetSetting", -- klient → server: hudba / zvuky
	"SkipTutorial", -- klient → server
	"Rebirth", -- klient → server
	"HoldStoredItem", -- klient → server: vzít předmět ze skladu nad hlavu
	"SwimStart", -- server → klient: začni plavat k voru (žralok)
	"SwimResult", -- server → klient: doplaval / chytil ho žralok
	"SlalomHit", -- klient → server: náraz ve slalomu (hvězdičky)
	"SlalomPickup", -- klient → server: sebral věc ve slalomu (mince, turbo, mráz)
	"TrialOffer", -- server → klient: úkol na cestu domů z dárkového ostrova (panel + šipka)
	"TrialAction", -- klient → server: "Start" / "GoHome"
	"TrialState", -- server → klient: průběh úkolu (Running, Checkpoint, Respawn, Complete, End)
	"SwimChoice", -- klient → server: na voru plavat dál k dalšímu voru (true) / zpět na pláž (false)
	"ServerEvent", -- server → všichni: právě běžící událost (nebo konec)
	"ContestBoard", -- server → všichni: živá tabulka soutěže o nejdelší skok (nebo nil = konec)
	"LegendRace", -- server → všichni: stav závodu LEGEND RACE (odpočet, závodníci, výsledky)
	"Teleport", -- klient → server: rychlý přesun (House / Pier)
	"QuickSell", -- klient → server: prodat běžný předmět z rukou kdekoli (tlačítko SELL)
	"SelectSkin", -- klient → server: který skin tenisek chce koupit (před nákupem za Robux)
	"StudioTestPurchase", -- klient → server: jen ve Studiu – vyzkoušet nákup zdarma
	"StudioTest", -- klient → server: jen ve Studiu – testovací panel (události, level, peníze…)
}

local FUNCTIONS = {
	"ShopAction", -- koupit / obléct pantofle a čepice
	"Spin", -- točit kolem štěstí
	"RedeemCode",
	"SellItems", -- prodejní okno u stánku SELL: prodat vybrané předměty (domeček, sklad, ruce)
}

local Net = {}

local folder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, name in EVENTS do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		for _, name in FUNCTIONS do
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.Event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), "Unknown RemoteEvent " .. name)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	assert(table.find(FUNCTIONS, name), "Unknown RemoteFunction " .. name)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
