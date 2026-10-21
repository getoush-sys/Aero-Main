local ForceAutoRotate = {}

---@module Utility.Logger
local Logger = require("Utility/Logger")

local hooked = false
local active = false
local originalNewIndex = nil

-- Parallel-hook guard (see Game/Hooking.lua): on executors without parallel_hooks_allowed, install via a
-- read-only metatable swap so this __newindex hook can't be dispatched from an Actor parallel phase, which
-- is an illegal cross-phase op the engine Kernel panics on (RSL - panic: ...Kernel).
local parallelHooksAllowed = parallel_hooks_allowed
local hookmetamethod = (not parallelHooksAllowed)
	and function(target, method, hook)
		local metatable = getrawmetatable(target)
		setreadonly(metatable, false)
		local original = metatable[method]
		metatable[method] = hook
		setreadonly(metatable, true)
		return original
	end
	or hookmetamethod

local function installHook()
	if hooked then
		return true
	end

	if type(hookmetamethod) ~= "function" then
		return false
	end

	local ok, result = pcall(function()
		originalNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
			if active
				and key == "AutoRotate"
				and value == false
				and typeof(self) == "Instance"
				and self:IsA("Humanoid")
			then
				return
			end

			return originalNewIndex(self, key, value)
		end)
	end)

	if not ok then
		Logger.longNotify("Force Auto Rotate failed to hook: " .. tostring(result))
		return false
	end

	hooked = true
	return true
end


function ForceAutoRotate.init()
	if not installHook() then
		return
	end
	active = true
end

function ForceAutoRotate.detach()
	active = false
end

return ForceAutoRotate
