--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)
local WeaponController = require(script.WeaponController)
local M1_ReflexQTE = require(script.Minigames.M1_ReflexQTE)
local M2_LaserGrid = require(script.Minigames.M2_LaserGrid)
local M3_TargetPractice = require(script.Minigames.M3_TargetPractice)
local M4_MemoryMatrix = require(script.Minigames.M4_MemoryMatrix)
local M5_BulletHell = require(script.Minigames.M5_BulletHell)
local UIManager = require(script.UI.UIManager)
local SoundManager = require(script.SoundManager)

print("[CLIENT] Initializing client subsystems...")

Network.InitializeRemotes()
SoundManager.Init()
UIManager.Init()
WeaponController.Init()
M1_ReflexQTE.Init()
M2_LaserGrid.Init()
M3_TargetPractice.Init()
M4_MemoryMatrix.Init()
M5_BulletHell.Init()

print("[CLIENT] Subsystems initialized successfully.")
