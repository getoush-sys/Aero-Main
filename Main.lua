if not shared then
	return
end

local services = {
	Players = game:GetService("Players"),
	CollectionService = game:GetService("CollectionService"),
}

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Was a blind `task.wait(3)`. Instead wait for the client to actually be ready -- LocalPlayer +
-- PlayerScripts (where the anti-cheat lives, so Hooking can neutralize it) --
-- capped at the same 3s ceiling so worst-case behaviour is unchanged. On a normal load these exist
-- in well under a second, so this shaves ~2s off every startup.
do
	local deadline = os.clock() + 3

	repeat
		task.wait()

		local localPlayer = services.Players.LocalPlayer

		if localPlayer and localPlayer:FindFirstChild("PlayerScripts") then
			break
		end
	until os.clock() >= deadline
end

loadstring("getfenv().LPH_NO_VIRTUALIZE = function(...) return ... end")()

getfenv().PP_SCRAMBLE_NUM = function(...)
	return ...
end

getfenv().PP_SCRAMBLE_STR = function(...)
	return ...
end

getfenv().PP_SCRAMBLE_RE_NUM = function(...)
	return ...
end

---@module Utility.Profiler
local Profiler = require("Utility/Profiler")

---@module Aero
local Aero
do
	local ok, result = xpcall(function()
		return require("Aero")
	end, function(e)
		warn("[Aero/diag] require(Aero) LOAD ERROR: " .. tostring(e))
		warn("[Aero/diag] " .. debug.traceback())
		return e
	end)
	if not ok then
		return
	end
	Aero = result
end

local function initializeScript()
	if shared.Aero then
		pcall(shared.Aero.detach)

		Aero.queued = shared.Aero.queued
	end

	shared.Aero = Aero
	shared.Aero.init()
end

---@param error string
local function onInitializeError(error)
	warn("[Aero/diag] INIT ERROR: " .. tostring(error))
	warn("[Aero/diag] " .. debug.traceback())
	pcall(Aero.detach)
end

Profiler.run("Main_InitializeScript", function(...)
	return xpcall(initializeScript, onInitializeError, ...)
end)
