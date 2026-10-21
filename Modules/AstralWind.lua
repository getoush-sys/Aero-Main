---@type Action
local Action = getfenv().Action

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	timing.uif = true
	timing.pfh = true
	timing.pfht = 0.25
	timing.phd = true
	timing.phds = 1.0

	local hrp = self.entity:FindFirstChild("HumanoidRootPart")
	local speed = hrp and math.clamp(hrp.Velocity.Magnitude, 0, 25) or 0

	local action = Action.new()
	action._when = 300
	action._type = "Parry"
	action.hitbox = Vector3.new(40, 20, 40) + Vector3.new(0, 0, speed)
	action.name = "Astral Wind Parry"
	return self:action(timing, action)
end
