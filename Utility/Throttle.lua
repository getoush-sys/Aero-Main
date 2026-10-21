---@class Throttle
--- Wrap a per-frame callback so it runs at most once per `interval` seconds, forwarding all
--- arguments (e.g. RenderStepped's dt) straight through. Uses os.clock, so it works regardless
--- of whether the driving signal passes a delta.
---
--- Intended for PASSIVE features that don't need full framerate (attribute farms, ownership
--- scan, ...). Do NOT use it on combat/UI/movement loops -- those want every frame.
---
---@param interval number Minimum seconds between calls.
---@param fn fun(...): ...
---@return fun(...): ...?
local function throttle(interval, fn)
	local last = 0

	return function(...)
		local now = os.clock()
		if now - last < interval then
			return
		end
		last = now
		return fn(...)
	end
end

return throttle
