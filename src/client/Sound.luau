--!strict
-- Zvuky a hudba (ID v Config/Sounds.luau). Respektuje nastavení hráče.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local ClientState = require(script.Parent.ClientState)

local Sound = {}

local cache: { [string]: Sound } = {}
local music: Sound? = nil
local ambience: { Sound } = {}
local loops: { [string]: Sound } = {}

local function settings(): { Music: boolean, Sfx: boolean }
	local data = ClientState.Get()
	return data.Settings or { Music = true, Sfx = true }
end

local function make(key: string, looped: boolean, volume: number): Sound?
	local id = (Sounds :: any)[key]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = id
	s.Looped = looped
	s.Volume = volume
	s.Parent = SoundService
	return s
end

function Sound.Play(key: string, pitch: number?)
	if not settings().Sfx then
		return
	end
	local s = cache[key]
	if not s then
		local created = make(key, false, Sounds.SfxVolume * (Sounds.Volume[key] or 1))
		if not created then
			return
		end
		cache[key] = created
		s = created
	end
	assert(s)
	-- výchozí výška tónu z Configu × výška od volajícího
	s.PlaybackSpeed = (Sounds.Pitch[key] or 1) * (pitch or 1)
	SoundService:PlayLocalSound(s)
end

-- Smyčka (např. vítr během letu): zapnout/vypnout, za běhu jde měnit hlasitost a výšku
function Sound.SetLoop(key: string, playing: boolean, volume: number?, pitch: number?)
	local s = loops[key]
	if not playing or not settings().Sfx then
		if s and s.IsPlaying then
			s:Stop()
		end
		return
	end
	if not s then
		local created = make(key, true, 0)
		if not created then
			return
		end
		loops[key] = created
		s = created
	end
	assert(s)
	s.Volume = Sounds.SfxVolume * (Sounds.Volume[key] or 1) * (volume or 1)
	s.PlaybackSpeed = (Sounds.Pitch[key] or 1) * (pitch or 1)
	if not s.IsPlaying then
		s:Play()
	end
end

local function refresh()
	local current = settings()
	if music then
		if current.Music and not music.IsPlaying then
			music:Play()
		elseif not current.Music and music.IsPlaying then
			music:Stop()
		end
	end
	for _, s in ambience do
		if current.Sfx and not s.IsPlaying then
			s:Play()
		elseif not current.Sfx and s.IsPlaying then
			s:Stop()
		end
	end
	if not current.Sfx then
		for _, s in loops do
			s:Stop()
		end
	end
end

function Sound.Start()
	music = make("Music", true, Sounds.MusicVolume)
	for _, key in { "Waves", "Seagulls" } do
		local s = make(key, true, 0.25)
		if s then
			table.insert(ambience, s)
		end
	end
	ClientState.Changed:Connect(refresh)
end

return Sound
