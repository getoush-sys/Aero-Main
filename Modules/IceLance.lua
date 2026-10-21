---@type Action
local Action = getfenv().Action

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local distance = self:distance(self.entity)
	local action = Action.new()
	action._when = 250 + distance * 13
	action._type = "Start Block"
	action.hitbox = Vector3.new(19, 15, 26)
	action.name = string.format("(%.2f) Dynamic Ice Lance Timing", distance)
	self:action(timing, action)

	local actionTwo = Action.new()
	actionTwo._when = 700 + distance * 13
	actionTwo.ihbc = true
	actionTwo._type = "End Block"
	actionTwo.name = string.format("(%.2f) Dynamic Ice Lance End Timing", distance)
	return self:action(timing, actionTwo)
end
