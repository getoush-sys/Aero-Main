local Aero = { queued = false, silent = false, dpscanning = false, norpc = false, verbose = false }

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.JSON
local JSON = require("Utility/JSON")

---@module Utility.TaskSpawner
local TaskSpawner = require("Utility/TaskSpawner")

---@module Utility.Environment
local Environment = require("Utility/Environment")

---@module Game.Hooking
local Hooking = require("Game/Hooking")

---@module GUI.Library
local Library = require("GUI/Library")

---@module Menu
local Menu = require("Menu")

---@module Features
local Features = require("Features")

---@module Utility.ControlModule
local ControlModule = require("Utility/ControlModule")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Game.PlayerScanning
local PlayerScanning = require("Game/PlayerScanning")

---@module Game.Timings.SaveManager
local SaveManager = require("Game/Timings/SaveManager")

---@module Features.Combat.StateListener
local StateListener = require("Features/Combat/StateListener")

---@module Game.EffectDispatcher
local EffectDispatcher = require("Game/EffectDispatcher")

---@module Features.Admin
local Admin = require("Features/Admin")

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Game.KeyHandling
local KeyHandling = require("Game/KeyHandling")

---@module Game.QueuedBlocking
local QueuedBlocking = require("Game/QueuedBlocking")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Game.Timings.ModuleManager
local ModuleManager = require("Game/Timings/ModuleManager")

---@module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")

---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")

---@module Game.Wipe
local Wipe = require("Game/Wipe")

---@module Features.Automation.EchoFarm
local EchoFarm = require("Features/Automation/EchoFarm")

---@module Features.Automation.AutoLayer2
local AutoLayer2 = require("Features/Automation/AutoLayer2")

---@module Features.Automation.Objects.General
local General = require("Features/Automation/Objects/General")

local lumaMaid = Maid.new()

local LOBBY_PLACE_ID = 4111023553
local DEPTHS_PLACE_ID = 5735553160
local CHIME_LOBBY_PLACE_ID = 12559711136

local replicatedStorage = game:GetService("ReplicatedStorage")
local playersService = game:GetService("Players")

local startTimestamp = os.clock()

local function get_bloxstrap_rpc()
	local modules = replicatedStorage:FindFirstChild("Modules")
	local rpc = modules and modules:FindFirstChild("BloxstrapRPC")
	if not rpc then
		return nil
	end

	local ok, module = pcall(require, rpc)
	return ok and module or nil
end

---@note: Stops every farm but keeps its resume flag, so a reload restarts exactly one copy via the resume blocks in init.
local function stop_farms()
	local farms = {
		{ require("Features/Automation/EchoFarm"), "efdata" },
		{ require("Features/Automation/AutoLayer2"), "l2data" },
		{ require("Features/Automation/AutoTo1"), "to1data" },
		{ require("Features/Automation/AutoVoI"), "voidata" },
		{ require("Features/Automation/AutoFerryman"), "afdata" },
		{ require("Features/Automation/AutoTitus"), "titusdata" },
		{ require("Features/Automation/AutoAuthority"), "authoritydata" },
		{ require("Features/Automation/AutoDuke"), "dukedata" },
		{ require("Features/Automation/AutoMooneyrie"), "mooneyriedata" },
		{ require("Features/Automation/AutoNotes"), "notesdata" },
		{ require("Features/Automation/AutoSaramed"), "sarameddata" },
	}

	for _, farm in ipairs(farms) do
		local module, key = farm[1], farm[2]
		local saved = PersistentData.get(key)

		pcall(module.stop)

		if saved ~= nil and PersistentData.get(key) ~= saved then
			pcall(PersistentData.set, key, saved)
		end
	end
end

function Aero.init()
	local localPlayer = nil

	repeat
		task.wait()
	until game:IsLoaded()

	-- Client prep -- the loading-screen A-spam (resume-gated) and the LocalPlayer/PlayerScripts/Character
	-- wait -- now runs in the loader (luarmor VM) BEFORE the core is executed, so the client is already
	-- ready here. We just resolve LocalPlayer (instant) and hook.
	repeat
		localPlayer = playersService.LocalPlayer
		task.wait()
	until localPlayer ~= nil

	if game.PlaceId ~= LOBBY_PLACE_ID then
		-- Start the init timer here. The character wait already happened in the loader, so this measures
		-- actual script loading, not the spawn wait.
		startTimestamp = os.clock()

		Hooking.earlyInit()
	end

	if isfile and isfile("smarker.txt") then
		Aero.silent = true
	end

	if isfile and isfile("dpscanning.txt") then
		Aero.dpscanning = true
	end

	if isfile and isfile("norpc.txt") then
		Aero.norpc = true
	end

	if isfile and isfile("verbose.txt") then
		Aero.verbose = true
	end


	if game.PlaceId == CHIME_LOBBY_PLACE_ID then
		return Logger.warn("Script has initialized in the Chime lobby.")
	end

	if game.PlaceId ~= LOBBY_PLACE_ID then
		KeyHandling.init()

		Hooking.init()
	end

	CoreGuiManager.set()

	PersistentData.init()

	if game.PlaceId == LOBBY_PLACE_ID then
		Logger.warn("Script has initialized in the lobby.")
	end

	if game.PlaceId == LOBBY_PLACE_ID then
		if PersistentData.get("shslot") then
			return ServerHop.lobby()
		end

		if PersistentData.get("wdata") then
			return Wipe.lobby()
		end
	end

	PersistentData.set("shslot", nil)

	if game.PlaceId == DEPTHS_PLACE_ID then
		if PersistentData.get("wdata") then
			Wipe.depths()
		end
	end

	if PersistentData.get("efdata") then
		EchoFarm.start()
	end

	if PersistentData.get("l2data") then
		AutoLayer2.start()
	end

	if game.PlaceId == LOBBY_PLACE_ID then
		return
	end

	QueuedBlocking.init()

	SaveManager.init()

	ModuleManager.refresh()

	ControlModule.init()

	Features.init()

	Menu.init()

	PlayerScanning.init()

	StateListener.init()

	-- Single shared EffectReplicator connection for every always-on consumer (StateListener, Removal, ...).
	-- Connect AFTER they've registered their hooks above so the initial replay reaches all of them.
	EffectDispatcher.init()

	-- Developer-only admin command layer (whitelist-gated inside the module).
	pcall(function()
		Admin.init()
	end)

	-- Resume Auto Builder after a server hop (abdata survives the teleport via MemStorage). Only
	-- resumes if it was active on this same data slot; reloads the same link + target and restarts.
	if PersistentData.get("abdata") then
		task.spawn(function()
			local AutoBuilder = require("Features/Automation/AutoBuilder")

			-- Wait for the character's DataSlot to be available before checking the slot match.
			local deadline = os.clock() + 60
			repeat
				task.wait(1)
			until AutoBuilder.currentSlot() ~= nil or os.clock() >= deadline

			local build = AutoBuilder.resume()
			if build then
				pcall(function()
					require("Menu/AutoBuilderWindow").show(build, AutoBuilder.classified)
				end)
			end
		end)
	end

	-- Resume Auto To1 after a server hop / place teleport (to1data survives via MemStorage). Wait
	-- until we're in a place it can run (Etrean Luminant or the Trial arena) before restarting.
	if PersistentData.get("to1data") then
		task.spawn(function()
			local AutoTo1 = require("Features/Automation/AutoTo1")
			local deadline = os.clock() + 60
			repeat
				task.wait(1)
			until AutoTo1.inValidPlace() or os.clock() >= deadline

			if AutoTo1.inValidPlace() then
				AutoTo1.start()
			end
		end)
	end

	-- Resume Auto VoI after a server hop / place teleport (voidata survives via MemStorage). Wait until
	-- we're in a place it can run (the VoI place or the Shogun arena).
	if PersistentData.get("voidata") then
		task.spawn(function()
			local AutoVoI = require("Features/Automation/AutoVoI")
			local deadline = os.clock() + 60
			repeat
				task.wait(1)
			until AutoVoI.inValidPlace() or os.clock() >= deadline

			if AutoVoI.inValidPlace() then
				AutoVoI.start()
			end
		end)
	end

	-- Resume Auto Ferryman after a server hop (afdata survives the teleport via MemStorage). Wait
	-- until we're actually in the Eastern Luminant (ValleyExit may still be streaming in) before
	-- restarting the farm.
	if PersistentData.get("afdata") then
		task.spawn(function()
			local AutoFerryman = require("Features/Automation/AutoFerryman")
			local deadline = os.clock() + 60
			repeat
				task.wait(1)
			until AutoFerryman.inEasternLuminant() or AutoFerryman.inBossDungeon() or os.clock() >= deadline

			if AutoFerryman.inEasternLuminant() or AutoFerryman.inBossDungeon() then
				AutoFerryman.start()
			end
		end)
	end

	-- Resume Auto Titus after a server hop / merit<->dungeon teleport (titusdata survives via MemStorage).
	-- Wait until we're back in the merit hub or the Titus dungeon before restarting.
	if PersistentData.get("titusdata") then
		task.spawn(function()
			local AutoTitus = require("Features/Automation/AutoTitus")
			local deadline = os.clock() + 60
			repeat
				task.wait(1)
			until AutoTitus.inValidPlace() or os.clock() >= deadline

			if AutoTitus.inValidPlace() then
				AutoTitus.start()
			end
		end)
	end

	-- Resume Auto Authority after a server hop (authoritydata survives via MemStorage). Wait until we're
	-- back in the Eastern Luminant before restarting.
	if PersistentData.get("authoritydata") then
		task.spawn(function()
			local AutoAuthority = require("Features/Automation/AutoAuthority")
			local deadline = os.clock() + 60
			repeat
				task.wait(1)
			until AutoAuthority.inValidPlace() or os.clock() >= deadline

			if AutoAuthority.inValidPlace() then
				AutoAuthority.start()
			end
		end)
	end

	-- Resume Auto Duke after a server hop / dungeon teleport (dukedata survives via MemStorage).
	if PersistentData.get("dukedata") then
		task.spawn(function()
			local AutoDuke = require("Features/Automation/AutoDuke")
			local deadline = os.clock() + 60
			repeat
				task.wait(1)
			until AutoDuke.inValidPlace() or (localPlayer and localPlayer:GetAttribute("Dungeon")) or os.clock() >= deadline

			AutoDuke.start()
		end)
	end

	-- Resume Auto Mooneyrie after a server hop (mooneyriedata survives via MemStorage).
	if PersistentData.get("mooneyriedata") then
		task.spawn(function()
			local AutoMooneyrie = require("Features/Automation/AutoMooneyrie")
			local deadline = os.clock() + 60
			repeat
				task.wait(1)
			until AutoMooneyrie.inValidPlace() or os.clock() >= deadline

			if AutoMooneyrie.inValidPlace() then
				AutoMooneyrie.start()
			end
		end)
	end

	-- Resume Auto Notes after a server hop / wipe (notesdata survives via MemStorage).
	if PersistentData.get("notesdata") then
		task.spawn(function()
			local AutoNotes = require("Features/Automation/AutoNotes")
			local deadline = os.clock() + 60
			repeat
				task.wait(1)
			until AutoNotes.inValidPlace() or os.clock() >= deadline

			if AutoNotes.inValidPlace() then
				AutoNotes.start()
			end
		end)
	end

	-- Resume Auto Saramed after a server hop / dungeon teleport (sarameddata survives via MemStorage).
	if PersistentData.get("sarameddata") then
		task.spawn(function()
			local AutoSaramed = require("Features/Automation/AutoSaramed")
			local deadline = os.clock() + 60
			repeat
				task.wait(1)
			until AutoSaramed.inValidPlace() or os.clock() >= deadline

			if AutoSaramed.inValidPlace() then
				AutoSaramed.start()
			end
		end)
	end

	if not Aero.silent then
		Logger.notify("Script has been initialized in %ims.", (os.clock() - startTimestamp) * 1000)
	end

	if not PersistentData.get("fli") then
		PersistentData.set("fli", os.time())
	end

	local bloxstrapRPCModule = get_bloxstrap_rpc()

	if not bloxstrapRPCModule then
		return
	end

	if Aero.norpc then
		return
	end

	bloxstrapRPCModule.SetRichPresence({
		details = "Aero (Attached)",
		state = string.format(
			"Currently attached to the script - time elapsed is a session of %s time spent.",
			Environment.isTester() and "developing" or "using"
		),
		timeStart = PersistentData.get("fli") or os.time(),
		largeImage = {
			assetId = Environment.isTester() and 11289930484 or 109802578297970,
			hoverText = Environment.isTester() and "Developing Deepwoken" or "Using Deepwoken",
		},
		smallImage = {
			assetId = Environment.isTester() and 15828456271 or 17278571027,
			hoverText = Environment.isTester() and "Developing Deepwoken" or "Using Deepwoken",
		},
	})

	local playerRemovingSignal = Signal.new(playersService.PlayerRemoving)

	lumaMaid:mark(playerRemovingSignal:connect("Aero_OnLocalPlayerRemoved", function(player)
		if player ~= playersService.LocalPlayer then
			return
		end

		bloxstrapRPCModule.SetRichPresence({
			details = "",
			state = "",
			timeStart = 0,
			timeEnd = 0,
			largeImage = {
				clear = true,
			},
			smallImage = {
				clear = true,
			},
		})
	end))
end

function Aero.detach()
	pcall(lumaMaid.clean, lumaMaid)

	pcall(stop_farms)

	pcall(ModuleManager.detach)

	pcall(Menu.detach)

	pcall(QueuedBlocking.detach)

	pcall(ControlModule.detach)

	pcall(InputClient.detach)

	pcall(Features.detach)

	pcall(SaveManager.detach)

	pcall(PlayerScanning.detach)

	pcall(CoreGuiManager.clear)

	pcall(StateListener.detach)

	pcall(EffectDispatcher.detach)

	local bloxstrapRPCModule = get_bloxstrap_rpc()

	if bloxstrapRPCModule then
		pcall(bloxstrapRPCModule.SetRichPresence, {
			details = "Aero (Detached)",
			state = Environment.isTester() and "Detached from script - something broke, fixing a bug, or a hot-reload."
				or "Detached from script - something broke or a hot-reload.",
			timeStart = PersistentData.get("fli") or os.time(),
			largeImage = {
				assetId = Environment.isTester() and 11289930484 or 109802578297970,
				hoverText = Environment.isTester() and "Developing Deepwoken" or "Not Using Deepwoken",
			},
			smallImage = {
				assetId = Environment.isTester() and 15828456271 or 17278571027,
				hoverText = Environment.isTester() and "Developing Deepwoken" or "Not Using Deepwoken",
			},
		})
	end

	pcall(Hooking.detach)

	Logger.warn("Script has been detached.")
end

return Aero
