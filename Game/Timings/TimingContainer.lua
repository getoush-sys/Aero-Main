---@class TimingContainer
---@field timings table<string, Timing>
---@field module Timing
---@field scrambled boolean Whether entries passed to :load() come from the baked-in truth data and need one-time decoding.
local TimingContainer = {}
TimingContainer.__index = TimingContainer

---@note: Mirrors Preprocessor.py's `_inline_timings` scrambling 1:1, including the
---@param raw table
---@return table
function TimingContainer.decode(raw)
	local out = {}
	for k, v in next, raw do
		out[k] = v
	end

	local function decodeHitbox(hb)
		return {
			X = PP_SCRAMBLE_NUM(hb.X),
			Y = PP_SCRAMBLE_NUM(hb.Y),
			Z = PP_SCRAMBLE_NUM(hb.Z),
		}
	end

	if typeof(out.name) == "string" then
		out.name = PP_SCRAMBLE_STR(out.name)
	end

	if typeof(out.smod) == "string" then
		out.smod = PP_SCRAMBLE_STR(out.smod)
	end

	if typeof(out._id) == "string" and out._id ~= "" then
		out._id = PP_SCRAMBLE_STR(out._id)
	end

	if typeof(out.pname) == "string" and out.pname ~= "" then
		out.pname = PP_SCRAMBLE_STR(out.pname)
	end

	if typeof(out.ename) == "string" and out.ename ~= "" then
		out.ename = PP_SCRAMBLE_STR(out.ename)
	end

	if typeof(out.imxd) == "number" then
		out.imxd = PP_SCRAMBLE_NUM(out.imxd)
	end

	if typeof(out.imdd) == "number" then
		out.imdd = PP_SCRAMBLE_NUM(out.imdd)
	end

	if typeof(out.rpd) == "number" and out.rpd ~= 0 then
		out.rpd = PP_SCRAMBLE_NUM(out.rpd)
		if typeof(out.rsd) == "number" then
			out.rsd = PP_SCRAMBLE_NUM(out.rsd)
		end
	end

	if typeof(out.hitbox) == "table" then
		out.hitbox = decodeHitbox(out.hitbox)
	end

	if typeof(out.actions) == "table" then
		local actions = {}
		for idx, action in next, out.actions do
			local decoded = {}
			for k, v in next, action do
				decoded[k] = v
			end

			if typeof(decoded._type) == "string" then
				decoded._type = PP_SCRAMBLE_STR(decoded._type)
			end

			if typeof(decoded.name) == "string" then
				decoded.name = PP_SCRAMBLE_STR(decoded.name)
			end

			if typeof(decoded.when) == "number" then
				decoded.when = PP_SCRAMBLE_NUM(decoded.when)
			end

			if typeof(decoded.hitbox) == "table" then
				decoded.hitbox = decodeHitbox(decoded.hitbox)
			end

			actions[idx] = decoded
		end
		out.actions = actions
	end

	return out
end

---@param name string
---@return Timing?
function TimingContainer:find(name)
	for _, timing in next, self.timings do
		if timing.name ~= name then
			continue
		end

		return timing
	end
end

---@return Timing[]
function TimingContainer:list()
	local timings = {}

	for _, timing in next, self.timings do
		timings[#timings + 1] = timing
	end

	return timings
end

---@return string[]
function TimingContainer:names()
	local names = {}

	for _, timing in next, self.timings do
		names[#names + 1] = timing.name
	end

	table.sort(names)

	return names
end

---@param timing Timing
function TimingContainer:remove(timing)
	local id = timing:id()
	if not id then
		return
	end

	self.timings[id] = nil
end

---@param other TimingContainer
---@return boolean
function TimingContainer:equals(other)
	if self:count() ~= other:count() then
		return false
	end

	for id, timing in next, self.timings do
		local otherTiming = other.timings[id]
		if not otherTiming then
			return false
		end

		if not timing:equals(otherTiming) then
			return false
		end
	end

	return true
end

---@return TimingContainer
function TimingContainer:clone()
	local container = TimingContainer.new(self.module)

	for _, timing in next, self.timings do
		container:push(timing:clone())
	end

	return container
end

---@param timing Timing
function TimingContainer:push(timing)
	local id = timing:id()
	if not id then
		return
	end

	---@note: Timing array keys must all be unique.
	if self.timings[id] then
		return error(string.format("Timing identifier '%s' already exists in container.", id))
	end

	---@note: Every timing must have unique names.
	if self:find(timing.name) then
		return error(string.format("Timing name '%s' already exists in container.", timing.name))
	end

	self.timings[id] = timing
end

function TimingContainer:clear()
	self.timings = {}
end

---@return number
function TimingContainer:count()
	local count = 0

	for _ in next, self.timings do
		count = count + 1
	end

	return count
end

---@param values table
function TimingContainer:load(values)
	for _, value in next, values do
		local timing = self.module.new(self.scrambled and TimingContainer.decode(value) or value)
		if not timing then
			continue
		end

		local id = timing:id()
		if not id then
			continue
		end

		---@note: Timing array keys must all be unique.
		if self.timings[id] then
			return error(string.format("Timing identifier '%s' already exists in container.", id))
		end

		---@note: Every timing must have unique names.
		if self:find(timing.name) then
			return error(string.format("Timing name '%s' already exists in container.", timing.name))
		end

		---@note: Why are the stored timing keys different from what's loaded?

		self.timings[id] = timing
	end
end

---@return table
function TimingContainer:serialize()
	local out = {}

	for _, timing in next, self.timings do
		out[#out + 1] = timing:serialize()
	end

	return out
end

---@param module Timing
---@param scrambled boolean? Whether entries passed to :load() are baked-in truth data that needs one-time decoding.
---@return TimingContainer
function TimingContainer.new(module, scrambled)
	local self = setmetatable({}, TimingContainer)
	self.timings = {}
	self.module = module
	self.scrambled = scrambled or false
	return self
end

return TimingContainer
