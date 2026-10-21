---@class PlaybackData
---@field base number Timestamp of when the object was created.
---@field ash table<number, number> Animation speed history. The key is the timestamp delta and the value is the speed at that point.
---@field entity Model Entity to playback.
local PlaybackData = {}
PlaybackData.__index = PlaybackData

---@param from number
---@return number?, number?
function PlaybackData:last(from)
	local latestExceededSpeed = nil
	local latestExceededDelta = nil

	for delta, speed in next, self.ash do
		if from <= delta then
			continue
		end

		if latestExceededDelta and delta <= latestExceededDelta then
			continue
		end

		latestExceededSpeed = speed
		latestExceededDelta = delta
	end

	return latestExceededSpeed, latestExceededDelta
end

---@param speed number
function PlaybackData:astrack(speed)
	local delta = os.clock() - self.base

	if self:last(delta) == speed then
		return
	end

	self.ash[delta] = speed
end

---@param entity Model
---@return PlaybackData
function PlaybackData.new(entity)
	local self = setmetatable({}, PlaybackData)
	self.base = os.clock()
	self.entity = entity

	---@note: Timestamp delta is how many seconds need to pass before being able to reach this speed.
	self.ash = {}

	return self
end

return PlaybackData
