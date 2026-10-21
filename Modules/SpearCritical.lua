---@class Action
local Action = getfenv().Action

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	timing.pfh = true
	timing.phd = true
	timing.pfht = 0.3
	timing.phds = 1.0

	local action = Action.new()
	action._when = 400
	action._type = "Parry"
	action.hitbox = Vector3.new(20, 20, 20)
	action.name = "(1) Static Spear Critical"
	self:action(timing, action)

	local action2 = Action.new()
	action2._when = 600
	action2._type = "Parry"
	action2.hitbox = Vector3.new(20, 20, 20)
	action2.name = "(2) Static Spear Critical"
	self:action(timing, action2)
end