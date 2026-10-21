---@module Game.Timings.Timing
local Timing = require("Game/Timings/Timing")

---@class SoundTiming: Timing
---@field id string Sound ID.
---@field rpue boolean Repeat parry until end.
---@field _rsd number Repeat start delay in miliseconds. Use :rsd() for seconds.
---@field _rpd number Delay between each repeat parry in miliseconds. Use :rpd() for seconds.
---@field alp boolean Allow local player to be hit.
local SoundTiming = setmetatable({}, { __index = Timing })
SoundTiming.__index = SoundTiming

---@return string
function SoundTiming:id()
	return self._id
end

---@param other SoundTiming
function SoundTiming:equals(other)
	if not Timing.equals(self, other) then
		return false
	end

	if self._id ~= other._id then
		return false
	end

	if self.alp ~= other.alp then
		return false
	end

	return true
end

---@param values table
function SoundTiming:load(values)
	Timing.load(self, values)

	if typeof(values._id) == "string" then
		self._id = values._id
	end

	if typeof(values.alp) == "boolean" then
		self.alp = values.alp
	end
end

---@return SoundTiming
function SoundTiming:clone()
	local clone = setmetatable(Timing.clone(self), SoundTiming)

	clone._id = self._id
	clone.alp = self.alp

	return clone
end

---@return SoundTiming
function SoundTiming:serialize()
	local serializable = Timing.serialize(self)

	serializable._id = self._id
	serializable.alp = self.alp

	return serializable
end

---@param values table?
---@return SoundTiming
function SoundTiming.new(values)
	local self = setmetatable(Timing.new(), SoundTiming)

	self._id = ""
	self.rpue = false
	self._rsd = 0
	self._rpd = 0
	self.alp = false

	if values then
		self:load(values)
	end

	return self
end

return SoundTiming
