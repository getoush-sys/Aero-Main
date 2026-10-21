---@class Action
local Action = getfenv().Action

---@module Utility.Finder
local Finder = getfenv().Finder

---Module function.
---@param self PartDefender
---@param timing PartTiming
return function(self, timing)
	if Finder.entity("knell") then
		return
	end

	timing.duih = true
	timing.fhb = false
	timing.hso = 0
	timing.hitbox = Vector3.new(20, 20, 20)

	local action = Action.new()
	action._when = 500
	action._type = "Dodge"
	action.hitbox = Vector3.new(20, 20, 20)
	action.name = "Dynamic Big Bell Timing"
	return self:action(timing, action)
end
