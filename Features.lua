local Features = {}

---@module Features.Automation.CharismaFarm
local CharismaFarm = require("Features/Automation/CharismaFarm")

---@module Features.Automation.InteligenceFarm
local IntelligenceFarm = require("Features/Automation/InteligenceFarm")

---@module Features.Game.Movement
local Movement = require("Features/Game/Movement")

---@module Features.Exploits.Exploits
local Exploits = require("Features/Exploits/Exploits")

---@module Features.Visuals.Visuals
local Visuals = require("Features/Visuals/Visuals")

---@module Features.Visuals.ProximityList
local ProximityList = require("Features/Visuals/ProximityList")

---@module Features.Visuals.TargetHUD
local TargetHUD = require("Features/Visuals/TargetHUD")

---@module Features.Game.Removal
local Removal = require("Features/Game/Removal")

---@module Features.Game.Monitoring
local Monitoring = require("Features/Game/Monitoring")

---@module Features.Game.Spoofing
local Spoofing = require("Features/Game/Spoofing")

---@module Features.Game.OwnershipWatcher
local OwnershipWatcher = require("Features/Game/OwnershipWatcher")

---@module Features.Game.EgirlNotifier
local EgirlNotifier = require("Features/Game/EgirlNotifier")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Features.Combat.Defense
local Defense = require("Features/Combat/Defense")

---@module Features.Combat.ExpApBreaker
local ExpApBreaker = require("Features/Combat/ExpApBreaker")

---@module Features.Game.AnimationVisualizer
local AnimationVisualizer = require("Features/Game/AnimationVisualizer")

---@module Features.Automation.FishFarm
local FishFarm = require("Features/Automation/FishFarm")

---@module Features.Game.Teleport
local Teleport = require("Features/Game/Teleport")

---@module Features.Automation.AutoLoot
local AutoLoot = require("Features/Automation/AutoLoot")

---@module Features.Automation.AutoBuilder
local AutoBuilder = require("Features/Automation/AutoBuilder")

---@module Features.Automation.AutoProg
local AutoProg = require("Features/Automation/AutoProg")

---@module Features.Automation.AutoTo1
local AutoTo1 = require("Features/Automation/AutoTo1")

---@module Features.Automation.AutoVoI
local AutoVoI = require("Features/Automation/AutoVoI")

---@module Game.AntiAFK
local AntiAFK = require("Game/AntiAFK")

---@module Features.Game.OptimizeGame
local OptimizeGame = require("Features/Game/OptimizeGame")

---@module Features.Game.RevealAnimations
local RevealAnimations = require("Features/Game/RevealAnimations")()

---@module Features.Exploits.AnimationFlooder
local AnimationFlooder = require("Features/Exploits/AnimationFlooder")

---@module Features.Combat.AnimationInspector
local AnimationInspector = require("Features/Combat/AnimationInspector")

---@note: Careful with features that have entire return LPH_NO_VIRTUALIZE(function() blocks. We assume that we don't care about what's placed in there.
local INIT_ORDER = {
	Defense,
	ExpApBreaker,
	Visuals,
	ProximityList,
	TargetHUD,
	Movement,
	Monitoring,
	Removal,
	Exploits,
	Spoofing,
	OwnershipWatcher,
	EgirlNotifier,
	CharismaFarm,
	IntelligenceFarm,
	FishFarm,
	Teleport,
	AutoLoot,
	AutoBuilder,
	AutoProg,
	AutoTo1,
	AutoVoI,
	AntiAFK,
	OptimizeGame,
	RevealAnimations,
}

local DETACH_ORDER = {
	Teleport,
	AntiAFK,
	OptimizeGame,
	RevealAnimations,
	FishFarm,
	ExpApBreaker,
	Defense,
	CharismaFarm,
	IntelligenceFarm,
	Spoofing,
	OwnershipWatcher,
	EgirlNotifier,
	Movement,
	Removal,
	Monitoring,
	Exploits,
	Visuals,
	ProximityList,
	TargetHUD,
	AutoLoot,
	AutoBuilder,
	AutoProg,
}

-- Isolate each feature's init/detach: one feature erroring can no longer abort loading/unloading the rest.
-- This is the core of the re-execution fix -- before, a single throwing detach left every later module's
-- connections/threads/hooks leaked, and they piled up across teleports until the client died.
---@param module table
---@param method string
local function isolated(module, method)
	local fn = module[method]
	if type(fn) ~= "function" then
		return
	end

	pcall(fn)
end

---@note: Careful with features that have entire return LPH_NO_VIRTUALIZE(function() blocks. We assume that we don't care about what's placed in there.
function Features.init()
	for _, module in ipairs(INIT_ORDER) do
		isolated(module, "init")
	end

	if not armorshield or armorshield.current_role == "builder" then
		isolated(AnimationVisualizer, "init")
	end

	if not LPH_OBFUSCATED or shared.Aero.verbose then
		Logger.warn("Features initialized.")
	end
end

function Features.detach()
	-- Admin-panel-driven exploits: stop them no matter the game branch so their render loops
	-- (and the inspector's namecall hook) never survive an unload.
	isolated(AnimationFlooder, "detach")
	isolated(AnimationInspector, "detach")

	if not armorshield or armorshield.current_role == "builder" then
		isolated(AnimationVisualizer, "detach")
	end

	for _, module in ipairs(DETACH_ORDER) do
		isolated(module, "detach")
	end

	Logger.warn("Features detached.")
end

return Features
