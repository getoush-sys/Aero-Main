---@type Action
local Action = getfenv().Action

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local distance = self:distance(self.entity)
	local action = Action.new()
	action._when = 400
	if distance >= 22 then
		action._when = 300
	end
	if distance >= 28 then
		action._when = 550
	end
	if distance >= 32 then
		action._when = 600
	end
	if distance >= 36 then
		action._when = 620
	end
	if distance >= 38 then
		action._when = 650
	end
	if distance >= 40 then
		action._when = 680
	end
	if distance >= 42 then
		action._when = 700
	end
	action._type = "Parry"
	action.hitbox = Vector3.new(25, 20, 60)
	action.name = string.format("(%.2f) Dynamic Pyre Keeper Sliding Crit Timing", distance)
	return self:action(timing, action)
end
