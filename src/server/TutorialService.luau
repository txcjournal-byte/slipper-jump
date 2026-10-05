--!strict
-- Tutoriál (5 kroků). Server hlídá, kdy je krok splněný; klient jen ukazuje text a šipku.
-- 1 k molu → 2 první skok → 3 do domečku → 4 vybrat kasičku → 5 koupit pantofle.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tutorial = require(Shared.Config.Tutorial)
local World = require(Shared.Config.World)
local Net = require(Shared.Net)

local Registry = require(script.Parent.Registry)

type Session = any

local TutorialService = {}

local function setStep(session: Session, step: number)
	local data = session.Data
	if data.TutorialDone then
		return
	end
	if step > #Tutorial.Steps then
		data.TutorialDone = true
		Registry.Player.Notify(session.Player, "Tutorial complete! Jump farther and reach the Giant Gift!", "Success")
	else
		data.TutorialStep = step
		if step == 5 then
			-- peníze na první pantofle
			Registry.Economy.AddMoney(session, Tutorial.ShopMoney)
			Registry.Player.Notify(session.Player, "Here is $" .. Tutorial.ShopMoney .. " for your first slippers!", "Money")
		end
	end
	Registry.Player.MarkDirty(session)
end

function TutorialService.OnJoin(session: Session)
	local data = session.Data
	if not data.TutorialDone and data.TotalJumps > 0 and data.TutorialStep <= 2 then
		data.TutorialStep = 3
	end
end

function TutorialService.CheckPosition(session: Session, position: Vector3)
	local data = session.Data
	if data.TutorialDone then
		return
	end
	if data.TutorialStep == 1 and position.X >= World.PierEndX - World.PierLength then
		setStep(session, 2)
	elseif data.TutorialStep == 3 and Registry.House.IsInside(session, position) then
		setStep(session, 4)
	end
end

function TutorialService.OnJumped(session: Session)
	local step = session.Data.TutorialStep
	if step <= 2 then
		setStep(session, 3)
	end
end

function TutorialService.OnCollect(session: Session)
	-- (krok 3 taky: kasička je hned u vchodu, takže ji hráč často vybere dřív, než ho hlídání polohy
	-- stihne „pustit“ do domečku – pak by návod zůstal viset na „Collect your money!“)
	local step = session.Data.TutorialStep
	if step == 3 or step == 4 then
		setStep(session, 5)
	end
end

function TutorialService.OnPurchase(session: Session)
	if session.Data.TutorialStep == 5 then
		setStep(session, #Tutorial.Steps + 1)
	end
end

function TutorialService.Start()
	Net.Event("SkipTutorial").OnServerEvent:Connect(function(player)
		local session = Registry.Player.Get(player)
		if session and not session.Data.TutorialDone then
			session.Data.TutorialDone = true
			Registry.Player.MarkDirty(session)
		end
	end)
end

return TutorialService
