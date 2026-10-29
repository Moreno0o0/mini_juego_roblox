--!strict
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)

local SoundManager = {}

local SOUND_DEFINITIONS: { [string]: { AssetId: string, Volume: number, BasePitch: number } } = {
	ButtonClick = { AssetId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, BasePitch = 1.2 },
	ButtonHover = { AssetId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.15, BasePitch = 1.8 },
	CoinPickup = { AssetId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, BasePitch = 1.5 },
	HitMelee = { AssetId = "rbxasset://sounds/swordhit.mp3", Volume = 0.8, BasePitch = 1.0 },
	SwordSlash = { AssetId = "rbxasset://sounds/swordslash.mp3", Volume = 0.65, BasePitch = 1.0 },
	SwordHit = { AssetId = "rbxasset://sounds/swordhit.mp3", Volume = 0.8, BasePitch = 1.0 },
	HitLaser = { AssetId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, BasePitch = 0.6 },
	Victory = { AssetId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.9, BasePitch = 1.0 },
	Defeat = { AssetId = "rbxasset://sounds/action_footstep_plastic.mp3", Volume = 0.6, BasePitch = 0.5 },
	StreakUp = { AssetId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, BasePitch = 1.4 },
	EventAlert = { AssetId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, BasePitch = 0.9 },
}

local soundFolder: Folder? = nil

local function GetSoundFolder(): Folder
	if soundFolder and soundFolder.Parent then
		return soundFolder
	end
	local existing = SoundService:FindFirstChild("CyberSoundCache")
	if existing and existing:IsA("Folder") then
		soundFolder = existing
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "CyberSoundCache"
	f.Parent = SoundService
	soundFolder = f
	return f
end

function SoundManager.PlaySound(name: string, customPitch: number?, customVolume: number?)
	local def = SOUND_DEFINITIONS[name]
	if not def then
		return
	end

	local folder = GetSoundFolder()
	local s = Instance.new("Sound")
	s.SoundId = def.AssetId
	s.Volume = customVolume or def.Volume
	s.PlaybackSpeed = (customPitch or 1.0) * def.BasePitch
	s.RollOffMaxDistance = 100
	s.Parent = folder

	s.Ended:Connect(function()
		s:Destroy()
	end)

	s:Play()
end

function SoundManager.PlayButtonClick()
	SoundManager.PlaySound("ButtonClick", 1.0)
end

function SoundManager.PlayButtonHover()
	SoundManager.PlaySound("ButtonHover", 1.0)
end

function SoundManager.PlayCoin()
	SoundManager.PlaySound("CoinPickup", 1.0 + (math.random() * 0.2))
end

function SoundManager.PlayHit()
	SoundManager.PlaySound("SwordHit", 0.95 + (math.random() * 0.1))
end

function SoundManager.PlaySlash()
	SoundManager.PlaySound("SwordSlash", 0.95 + (math.random() * 0.15))
end

function SoundManager.PlayWin()
	SoundManager.PlaySound("Victory", 1.2)
end

function SoundManager.PlayDefeat()
	SoundManager.PlaySound("Defeat", 0.8)
end

function SoundManager.PlayComboChime(comboIndex: number)
	-- Ascending melodic pitch for combos
	local pitchMultiplier = 1.0 + math.clamp(comboIndex * 0.08, 0, 0.8)
	SoundManager.PlaySound("StreakUp", pitchMultiplier)
end

function SoundManager.PlayEventAlert()
	SoundManager.PlaySound("EventAlert", 1.0)
end

function SoundManager.Init()
	-- Listen for server-requested sound triggers
	local playSoundRemote = Network.GetRemote("PlayClientSound")
	playSoundRemote.OnClientEvent:Connect(function(soundName: any, pitch: any)
		if typeof(soundName) == "string" then
			SoundManager.PlaySound(soundName, if typeof(pitch) == "number" then pitch else nil)
		end
	end)
end

return SoundManager
