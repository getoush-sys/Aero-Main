---@note: Answers "what is the server's effect state right now" locally, by mirroring the server's effect
---@note: timestamps into a weak Lua table. Tracking is DRIVEN by StateListener's Project-Rain-style
---@note: EffectReplicator connection (setthreadidentity(8) + task.spawn + reconnect on container rebuild);
---@note: this module no longer connects to EffectAdded/EffectRemoved itself, so the whole script keeps exactly
---@note: one effect connection. StateListener calls track/untrack/clear; everything else just reads `tracked`.

---@module Game.Latency
local Latency = require("Game/Latency")

local EffectTimers = {}

local tracked = setmetatable({}, { __mode = "k" })

---@param effect table
function EffectTimers.track(effect)
	if not effect then
		return
	end

	tracked[effect] = { at = os.clock(), debris = effect.DebrisTime }
end

---@param effect table
function EffectTimers.untrack(effect)
	if not effect then
		return
	end

	tracked[effect] = nil
end

---Drop every tracked effect (used when the server clears/rebuilds its effect container).
function EffectTimers.clear()
	table.clear(tracked)
end

---@param effect table
---@return number
function EffectTimers.elapsed(effect)
	if not effect then
		return 0
	end

	local info = tracked[effect]
	if not info then
		return 0
	end

	return (os.clock() - info.at) + (Latency.rdelay() or 0)
end

---@param effect table
---@return number?
function EffectTimers.remaining(effect)
	if not effect then
		return nil
	end

	local info = tracked[effect]
	if not info or not info.debris then
		return nil
	end

	return math.max(0, info.debris - (os.clock() - info.at))
end

---@param effectReplicatorModule table
---@param class string
---@return number? elapsed
---@return number? remaining
function EffectTimers.forClass(effectReplicatorModule, class)
	local effect = effectReplicatorModule:FindEffect(class)
	if not effect then
		return nil, nil
	end

	return EffectTimers.elapsed(effect), EffectTimers.remaining(effect)
end

function EffectTimers.detach()
	table.clear(tracked)
end

return EffectTimers
