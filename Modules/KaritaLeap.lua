---@type Action
local Action = getfenv().Action

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local distance = self:distance(self.entity)

	local action = Action.new()
	action._when = math.min(400 + distance * 5)
	action._type = "Parry"
	action.hitbox = Vector3.new(20, 20, 40)
	action.name = "Karita Leap Timing"
	return self:action(timing, action)
end
