---@class Action
local Action = getfenv().Action

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local distance = self:distance(self.entity)
	timing.pfh = true

	local action = Action.new()
	action._when = math.min(100 + distance * 10)

	if self.track.Speed >= 0.7 then
		action._when = math.min(100 + distance * 10)
	end

	action._type = "Parry"
	action.hitbox = Vector3.new(20, 40, 60)
	action.name = string.format("(%.2f) Mayhem Silentheart Timing", self.track.Speed)
	self:action(timing, action)
end
