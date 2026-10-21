---@type Action
local Action = getfenv().Action

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	timing.ffh = true

	local distance = self:distance(self.entity)
	local action = Action.new()
	action._when = 400

	if distance >= 20 then
		action._when = 550
	end

	action._type = "Parry"
	action.name = string.format("(%.2f) Dynamic Wind Gun Timing", distance)
	action.hitbox = Vector3.new(30, 20, 40)

	return self:action(timing, action)
end
