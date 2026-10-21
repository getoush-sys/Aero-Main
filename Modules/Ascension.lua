---@type Action
local Action = getfenv().Action

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local distance = self:distance(self.entity)
	local when = 1020 + distance * 10

	local hitbox = Vector3.new(30, 35, 30)

	timing.mat = when + 500
	timing.hitbox = hitbox

	local action = Action.new()
	action._when = when
	action._type = "Forced Full Dodge"
	action.hitbox = hitbox
	action.name = string.format("(%.2f) Dynamic Ascension Timing", distance)

	return self:action(timing, action)
end
