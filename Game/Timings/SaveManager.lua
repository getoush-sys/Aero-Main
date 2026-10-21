---@module Game.Timings.TimingSave
local TimingSave = require("Game/Timings/TimingSave")

---@module Game.Timings.TimingContainerPair
local TimingContainerPair = require("Game/Timings/TimingContainerPair")

---@module Game.Timings.TimingContainer
local TimingContainer = require("Game/Timings/TimingContainer")

---@module Game.Timings.AnimationTiming
local AnimationTiming = require("Game/Timings/AnimationTiming")

---@module Game.Timings.EffectTiming
local EffectTiming = require("Game/Timings/EffectTiming")

---@module Game.Timings.PartTiming
local PartTiming = require("Game/Timings/PartTiming")

---@module Game.Timings.SoundTiming
local SoundTiming = require("Game/Timings/SoundTiming")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

local SaveManager = { llc = nil, llcn = nil, lct = nil, dirtyAt = nil }

---@note: How long after the last builder edit (seconds) we flush changes to disk. Keeps
---edit-to-disk latency low so a freshly-set value (e.g. an action hitbox) isn't lost if the
---user reloads before the long periodic interval elapses, while still debouncing slider drags.
local SAVE_DEBOUNCE = 1.0

---@module Utility.Filesystem
local Filesystem = require("Utility/Filesystem")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Deserializer
local Deserializer = require("Utility/Deserializer")

---@module Utility.String
local String = require("Utility/String")

---@module Utility.Serializer
local Serializer = require("Utility/Serializer")

local fs = Filesystem.new("Aero-Rewrite-Timings")

local config = TimingSave.new()

local runService = game:GetService("RunService")

local saveMaid = Maid.new()

---@return table
function SaveManager.list()
	local list = fs:list(true)
	local out = {}

	for idx = 1, #list do
		local file = list[idx]

		if file:sub(-4) ~= ".txt" then
			continue
		end

		local pos = file:find(".txt", 1, true)
		local char = file:sub(pos, pos)
		local start = pos

		while char ~= "/" and char ~= "\\" and char ~= "" do
			pos = pos - 1
			char = file:sub(pos, pos)
		end

		if char == "/" or char == "\\" then
			table.insert(out, file:sub(pos + 1, start - 1))
		end
	end

	return out
end

---@param dropdown table
function SaveManager.refresh(dropdown)
	dropdown:SetValues(SaveManager.list())
end

---@param name string
function SaveManager.autoload(name)
	if not name or #name <= 0 then
		return Logger.longNotify("Config name cannot be empty.")
	end

	local success, result = pcall(fs.write, fs, "autoload.txt", name)

	if not success then
		Logger.longNotify("Failed to write autoload file %s.", name)

		return Logger.warn(
			"Timing manager ran into the error '%s' while attempting to write autoload file %s.",
			result,
			name
		)
	end

	Logger.notify("Config file %s has set to auto-load.", name)
end

---@param name string
function SaveManager.create(name)
	if not name or #name <= 0 then
		return Logger.longNotify("Config name cannot be empty.")
	end

	if fs:file(name .. ".txt") then
		return Logger.longNotify("Config file %s already exists.", name)
	end

	SaveManager.write(name)
end

---@param name string
function SaveManager.save(name)
	if not name or #name <= 0 then
		return Logger.longNotify("Config name cannot be empty.")
	end

	if not fs:file(name .. ".txt") then
		return Logger.longNotify("Config file %s does not exist.", name)
	end

	SaveManager.write(name)
end

---@param name string
---@return number
function SaveManager.write(name, silent)
	if not name or #name <= 0 then
		return -1, Logger.longNotify("Config name cannot be empty.")
	end

	local success, result = pcall(Serializer.marshal, config:serialize())

	if not success then
		Logger.longNotify("Failed to serialize config file %s.", name)

		return -2,
			Logger.warn("Timing manager ran into the error '%s' while attempting to serialize config %s.", result, name)
	end

	success, result = pcall(fs.write, fs, name .. ".txt", result)

	if not success then
		Logger.longNotify("Failed to write config file %s.", name)

		return -3,
			Logger.warn("Timing manager ran into the error '%s' while attempting to write config %s.", result, name)
	end

	if not silent then
		Logger.notify("Config file %s has written to.", name)
	end

	return 0
end

---@param name string
function SaveManager.clear(name)
	if not name or #name <= 0 then
		return Logger.longNotify("Config name cannot be empty.")
	end

	local success, result = pcall(Serializer.marshal, TimingSave.new():serialize())

	if not success then
		Logger.longNotify("Failed to serialize config file %s.", name)

		return Logger.warn(
			"Timing manager ran into the error '%s' while attempting to serialize config %s.",
			result,
			name
		)
	end

	success, result = pcall(fs.write, fs, name .. ".txt", result)

	if not success then
		Logger.longNotify("Failed to write config file %s.", name)

		return Logger.warn("Timing manager ran into the error '%s' while attempting to write config %s.", result, name)
	end

	Logger.notify("Config file %s has been cleared.", name)
end

---@param name string
---@param silent boolean? Suppress the "config loaded" notification (used for startup autoload).
function SaveManager.load(name, silent)
	local timestamp = os.clock()

	if not name or #name <= 0 then
		return Logger.longNotify("Config name cannot be empty.")
	end

	local success, result = pcall(fs.read, fs, name .. ".txt")

	if not success then
		Logger.longNotify("Failed to read config file %s.", name)

		return Logger.warn("Timing manager ran into the error '%s' while attempting to read config %s.", result, name)
	end

	success, result = pcall(Deserializer.unmarshal_one, String.tba(result))

	if not success then
		Logger.longNotify("Failed to deserialize config file %s.", name)

		return Logger.warn(
			"Timing manager ran into the error '%s' while attempting to deserialize config %s.",
			result,
			name
		)
	end

	if typeof(result) ~= "table" then
		Logger.longNotify("Failed to process config file %s.", name)

		return Logger.warn("Timing manager failed to process config %s with result %s.", name, tostring(result))
	end

	config:clear()

	success, result = pcall(config.load, config, result)

	if not success then
		Logger.longNotify("Failed to load config file %s.", name)

		return Logger.warn("Timing manager ran into the error '%s' while attempting to load config %s.", result, name)
	end

	if not silent then
		Logger.notify(
			"Config file %s has loaded with %i timings in %.2f seconds.",
			name,
			config:count(),
			os.clock() - timestamp
		)
	end

	SaveManager.llc = config:clone()
	SaveManager.llcn = name
	SaveManager.dirtyAt = nil
end

---@note: Called by the timing builder whenever it mutates a timing/action (add an action, change
---a hitbox, etc.). Schedules a debounced flush so recent edits persist within ~1s instead of
---waiting for the periodic interval. No-op until a config is loaded.
function SaveManager.markDirty()
	if SaveManager.llcn then
		SaveManager.dirtyAt = os.clock()
	end
end

---@return boolean, number
function SaveManager.autosave()
	if not SaveManager.llcn then
		return false, -1, Logger.warn("No config name has been loaded for auto-save.")
	end

	if not SaveManager.sautos then
		return false, -2, Logger.warn("Auto-save has been disabled.")
	end

	Logger.warn("Auto-saving timings to '%s' config file.", SaveManager.llcn)

	return true, SaveManager.write(SaveManager.llcn), Logger.notify("Auto-save has completed successfully.")
end

function SaveManager.init()
	local timestamp = os.clock()
	local preRenderSignal = Signal.new(runService.PreRender)

	---@note: These are flagged 'scrambled' - entries loaded into them come from the
	local internalAnimationContainer = TimingContainer.new(AnimationTiming.new(), true)
	local internalEffectContainer = TimingContainer.new(EffectTiming.new(), true)
	local internalPartContainer = TimingContainer.new(PartTiming.new(), true)
	local internalSoundContainer = TimingContainer.new(SoundTiming.new(), true)

	---@todo: Load internal timings from server.
	internalAnimationContainer:load({})
	internalEffectContainer:load({})
	internalPartContainer:load({})
	internalSoundContainer:load({})

	local internalCount = internalAnimationContainer:count()
		+ internalEffectContainer:count()
		+ internalPartContainer:count()
		+ internalSoundContainer:count()


	local success, result = pcall(fs.read, fs, "autoload.txt")

	if success and result then
		SaveManager.load(result, true)
	end

	SaveManager.as = TimingContainerPair.new(internalAnimationContainer, config:get().animation)

	SaveManager.es = TimingContainerPair.new(internalEffectContainer, config:get().effect)

	SaveManager.ps = TimingContainerPair.new(internalPartContainer, config:get().part)

	SaveManager.ss = TimingContainerPair.new(internalSoundContainer, config:get().sound)

	saveMaid:add(preRenderSignal:connect("SaveManager_AutoSave", function()
		local llc = SaveManager.llc
		if not llc then
			return
		end

		local llcn = SaveManager.llcn
		if not llcn then
			return
		end

		---@note: Save-on-edit. ALWAYS flush a dirty config shortly after edits settle, independent of
		---the PeriodicAutoSave toggle -- so every edit is written to disk (the 1s debounce just avoids
		---hammering the disk mid slider-drag). The write is silent so it doesn't spam notifications.
		if SaveManager.dirtyAt then
			if os.clock() - SaveManager.dirtyAt < SAVE_DEBOUNCE then
				return
			end

			SaveManager.dirtyAt = nil
			SaveManager.lct = os.clock()

			if config:equals(llc) then
				return
			end

			SaveManager.write(SaveManager.llcn, true)
			SaveManager.llc = config:clone()

			return
		end

		-- The periodic full re-save below is the only part gated by the PeriodicAutoSave toggle.
		if not Configuration.expectToggleValue("PeriodicAutoSave") then
			return
		end

		if
			SaveManager.lct
			and os.clock() - SaveManager.lct < (Configuration.expectOptionValue("PeriodicAutoSaveInterval") or 60)
		then
			return
		end

		SaveManager.lct = os.clock()

		if config:equals(llc) then
			return
		end

		Logger.warn("Auto-saving timings to '%s' config file.", SaveManager.llcn)

		SaveManager.write(SaveManager.llcn)

		SaveManager.llc = config:clone()

		Logger.notify("Timing auto-save has completed successfully.")
	end))
end

function SaveManager.detach()
	saveMaid:clean()
end

return SaveManager
