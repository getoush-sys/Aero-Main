-- AutoLog: per-automation auto-log (server-hop-when-a-player-is-near) distance store. Saved to disk per
-- automation id -- deliberately NOT part of Aero's config saves, so the distance is a persistent per-
-- automation setting that survives config switches and rejoins. The menu sliders in AutomationTab read/write
-- it here; the automations (AutomationFeatures.auto_log + AutoTitus/EchoFarm/AutoFerryman watchers) read it.
local AutoLog = {}

---@module Utility.Filesystem
local Filesystem = require("Utility/Filesystem")

---@module Utility.JSON
local JSON = require("Utility/JSON")

local storage = Filesystem.new("Aero/Automation")
local FILE = "autolog.json"

-- Default range preserves the old hardcoded behaviour (1000 studs) for any automation never adjusted.
AutoLog.DEFAULT = 1000

local cache = nil

local function load()
	if cache then
		return cache
	end
	local data
	pcall(function()
		if storage:file(FILE) then
			local ok, decoded = pcall(JSON.decode, storage:read(FILE))
			if ok and type(decoded) == "table" then
				data = decoded
			end
		end
	end)
	cache = data or {}
	return cache
end

---Current auto-log distance for an automation id (DEFAULT if never set).
---@param id string?
---@return number
function AutoLog.get(id)
	if id == nil then
		return AutoLog.DEFAULT
	end
	local v = load()[tostring(id)]
	if type(v) ~= "number" then
		return AutoLog.DEFAULT
	end
	return v
end

---Persist a new auto-log distance for an automation id (writes to disk immediately).
---@param id string
---@param distance number
function AutoLog.set(id, distance)
	if id == nil then
		return
	end
	local c = load()
	c[tostring(id)] = tonumber(distance) or AutoLog.DEFAULT
	pcall(function()
		storage:write(FILE, JSON.encode(c))
	end)
end

return AutoLog
