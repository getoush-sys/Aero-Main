local INTERNAL_MODULES = {}
local INTERNAL_GLOBALS = {}

local INTERNAL_MODULE_SOURCES = {}
local INTERNAL_GLOBAL_SOURCES = {}

---@note: All globals get executed first but never ran. This gets set in the global environment of every future module after.
local ModuleManager = { modules = {}, globals = {} }

---@module Utility.Filesystem
local Filesystem = require("Utility/Filesystem")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Game.Timings.Action
local Action = require("Game/Timings/Action")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Features.Combat.Objects.Task
local Task = require("Features/Combat/Objects/Task")

---@module Game.Timings.Timing
local Timing = require("Game/Timings/Timing")

---@module Features.Combat.StateListener
local StateListener = require("Features/Combat/StateListener")

---@module Utility.TaskSpawner
local TaskSpawner = require("Utility/TaskSpawner")

---@module Utility.Finder
local Finder = require("Utility/Finder")

---@module Features.Combat.Targeting
local Targeting = require("Features/Combat/Targeting")

---@module Game.Timings.PartTiming
local PartTiming = require("Game/Timings/PartTiming")

---@module Features.Combat.Objects.HitboxOptions
local HitboxOptions = require("Features/Combat/Objects/HitboxOptions")

---@module Features.Combat.Objects.RepeatInfo
local RepeatInfo = require("Features/Combat/Objects/RepeatInfo")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

local fs = Filesystem.new("Aero-Rewrite-Modules")
local gfs = Filesystem.new(fs:append("Globals"))

local tdetach = {}

---@note: Negative cache for the lazy resolver so a timing pointing at a genuinely missing module
---doesn't hit the filesystem on every fire (e.g. every M1). Cleared on refresh.
local lazyMisses = {}
local LAZY_MISS_TTL = 2.0

---@param lf function
---@param id string
---@param file string?
---@param global boolean
---@param moduleStore table? Target table for non-global results (defaults to the live modules table).
---@param globalStore table? Target table for global results + env injection (defaults to live globals).
function ModuleManager.execute(lf, id, file, global, moduleStore, globalStore)
	moduleStore = moduleStore or ModuleManager.modules
	globalStore = globalStore or ModuleManager.globals
	---@module Features.Combat.Defense
	---@note: For some reason, it broke lol. Returned nil.
	local Defense = require("Features/Combat/Defense")

	---@module Game.Latency
	local Latency = require("Game/Latency")

	getfenv(lf).Timing = Timing
	getfenv(lf).PartTiming = PartTiming
	getfenv(lf).Defense = Defense
	getfenv(lf).Action = Action
	getfenv(lf).Task = Task
	getfenv(lf).Maid = Maid
	getfenv(lf).Signal = Signal
	getfenv(lf).InputClient = InputClient
	getfenv(lf).TaskSpawner = TaskSpawner
	getfenv(lf).Targeting = Targeting
	getfenv(lf).Finder = Finder
	getfenv(lf).Logger = Logger
	getfenv(lf).HitboxOptions = HitboxOptions
	getfenv(lf).RepeatInfo = RepeatInfo
	getfenv(lf).StateListener = StateListener
	getfenv(lf).Latency = Latency
	getfenv(lf).Configuration = Configuration

	for name, entry in next, (not global) and globalStore or {} do
		getfenv(lf)[name] = entry
	end

	local success, result = pcall(lf)
	if not success then
		return Logger.warn("Module '%s' failed to load due to error '%s' while executing.", file or id, result)
	end

	if global and typeof(result) ~= "table" then
		return Logger.warn("Global module '%s' is invalid because it does not return a table.", file or id)
	end

	local output = global and globalStore or moduleStore

	output[id] = result

	if typeof(result) == "table" and typeof(result.detach) == "function" then
		tdetach[#tdetach + 1] = result.detach
	end
end

---@param tfs Filesystem The filesystem to load from.
---@param global boolean Whether we're loading global modules or not.
---@param moduleStore table? Target table for non-global results (defaults to the live modules table).
---@param globalStore table? Target table for global results (defaults to the live globals table).
function ModuleManager.load(tfs, global, moduleStore, globalStore)
	for _, file in next, tfs:list(false) do
		if string.sub(file, #file - 3, #file) ~= ".lua" then
			continue
		end

		local ls = tfs:read(file)

		local lf, lr = loadstring(ls)
		if not lf then
			Logger.warn("Module file '%s' failed to load due to error '%s' while loading.", file, lr)
			continue
		end

		ModuleManager.execute(lf, string.sub(file, 1, #file - 4), file, global, moduleStore, globalStore)
	end
end

---@return string[]
function ModuleManager.loaded()
	local out = {}

	for file, _ in next, ModuleManager.modules do
		table.insert(out, file)
	end

	return out
end

---@return string[]
function ModuleManager.listFiles()
	local set = {}

	local ok, list = pcall(function()
		return fs:list(false)
	end)
	if ok and type(list) == "table" then
		for _, file in next, list do
			if string.sub(file, #file - 3, #file) == ".lua" then
				set[string.sub(file, 1, #file - 4)] = true
			end
		end
	end

	for name in next, INTERNAL_MODULE_SOURCES do
		set[name] = true
	end
	for name in next, INTERNAL_GLOBAL_SOURCES do
		set[name] = true
	end

	local out = {}
	for name in next, set do
		out[#out + 1] = name
	end

	table.sort(out)

	return out
end

---@param name string
---@return boolean
function ModuleManager.fileExists(name)
	return fs:file(name .. ".lua") or INTERNAL_MODULE_SOURCES[name] ~= nil or INTERNAL_GLOBAL_SOURCES[name] ~= nil
end

---@param name string
---@return string?
function ModuleManager.readFile(name)
	if fs:file(name .. ".lua") then
		local ok, contents = pcall(function()
			return fs:read(name .. ".lua")
		end)
		if ok then
			return contents
		end
	end

	return INTERNAL_MODULE_SOURCES[name] or INTERNAL_GLOBAL_SOURCES[name]
end

---@param name string
---@param source string?
---@return boolean
function ModuleManager.writeFile(name, source)
	local ok = pcall(function()
		fs:write(name .. ".lua", source or "")
	end)

	return ok
end

---@param name string
---@return boolean
function ModuleManager.deleteFile(name)
	if not fs:file(name .. ".lua") then
		return false
	end

	local ok = pcall(function()
		fs:delete(name .. ".lua")
	end)

	return ok
end

---@return table<string,string> modules, table<string,string> globals
function ModuleManager.exportSources()
	local modules, globals = {}, {}

	local function collect(tfs, out)
		local ok, list = pcall(function()
			return tfs:list(false)
		end)
		if not ok or type(list) ~= "table" then
			return
		end
		for _, file in next, list do
			if string.sub(file, #file - 3, #file) == ".lua" then
				local ok2, source = pcall(function()
					return tfs:read(file)
				end)
				if ok2 then
					out[string.sub(file, 1, #file - 4)] = source
				end
			end
		end
	end

	collect(fs, modules)
	collect(gfs, globals)

	return modules, globals
end

function ModuleManager.resetUserModules()
	local function wipe(tfs)
		local ok, list = pcall(function()
			return tfs:list(false)
		end)
		if not ok or type(list) ~= "table" then
			return
		end
		for _, file in next, list do
			if string.sub(file, #file - 3, #file) == ".lua" then
				pcall(function()
					tfs:delete(file)
				end)
			end
		end
	end

	wipe(fs)
	wipe(gfs)
end

function ModuleManager.detach()
	for _, detach in next, tdetach do
		detach()
	end

	tdetach = {}
end

function ModuleManager.refresh()
	ModuleManager.detach()

	lazyMisses = {}

	---@note: Build into fresh tables and swap them in atomically at the end. The live
	---`modules`/`globals` tables stay intact (fully populated) for the whole rebuild, so a
	---module-timing that fires mid-refresh never sees an empty/partial table -> no spurious
	---"module not found" during a refresh (startup, menu build, or a builder button press).
	local newModules = {}
	local newGlobals = {}

	for id, lf in next, INTERNAL_GLOBALS do
		ModuleManager.execute(lf, id, nil, true, newModules, newGlobals)
	end

	for id, lf in next, INTERNAL_MODULES do
		ModuleManager.execute(lf, id, nil, false, newModules, newGlobals)
	end

	ModuleManager.load(gfs, true, newModules, newGlobals)

	ModuleManager.load(fs, false, newModules, newGlobals)

	ModuleManager.modules = newModules
	ModuleManager.globals = newGlobals
end

---Resolve a module by name, lazily loading it from disk if it isn't in memory yet. Covers a
---module created/edited this session that a refresh hasn't picked up, and any lookup that raced a
---refresh.
---@param name string?
---@return any
function ModuleManager.get(name)
	if typeof(name) ~= "string" or name == "" then
		return nil
	end

	local existing = ModuleManager.modules[name]
	if existing ~= nil then
		return existing
	end

	local missedAt = lazyMisses[name]
	if missedAt and os.clock() - missedAt < LAZY_MISS_TTL then
		return nil
	end

	local ok, hasFile = pcall(function()
		return fs:file(name .. ".lua")
	end)
	if not ok or not hasFile then
		lazyMisses[name] = os.clock()
		return nil
	end

	local source
	local read = pcall(function()
		source = fs:read(name .. ".lua")
	end)
	if not read or typeof(source) ~= "string" then
		lazyMisses[name] = os.clock()
		return nil
	end

	local lf, lr = loadstring(source)
	if not lf then
		Logger.warn("Module file '%s.lua' failed to load due to error '%s' while lazy-loading.", name, lr)
		lazyMisses[name] = os.clock()
		return nil
	end

	ModuleManager.execute(lf, name, name .. ".lua", false)

	local loaded = ModuleManager.modules[name]
	if loaded == nil then
		lazyMisses[name] = os.clock()
	else
		lazyMisses[name] = nil
	end

	return loaded
end

return ModuleManager
