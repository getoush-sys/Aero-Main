---@class TimingContainerPair
---@note The configs are always prioritized over the internal timings.
---@field internal TimingContainer
---@field config TimingContainer
local TimingContainerPair = {}
TimingContainerPair.__index = TimingContainerPair

---@param internal TimingContainer
---@param config TimingContainer
---@return TimingContainerPair
function TimingContainerPair.new(internal, config)
	local self = setmetatable({}, TimingContainerPair)
	self.internal = internal
	self.config = config
	return self
end

---@param key any?
---@return Timing?
function TimingContainerPair:index(key)
	return self.config.timings[key] or self.internal.timings[key]
end

---@param name string
---@return Timing?
function TimingContainerPair:find(name)
	return self.config:find(name) or self.internal:find(name)
end

---@return Timing[]
function TimingContainerPair:list()
	local timings = {}

	for _, timing in next, self.config:list() do
		table.insert(timings, timing)
	end

	for _, timing in next, self.internal:list() do
		table.insert(timings, timing)
	end

	return timings
end

return TimingContainerPair
