---@class Action
local Action = getfenv().Action

---@class Timing
local Timing = getfenv().Timing

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local distance = self:distance(self.entity)

	-- Close range: bypass hitbox check and parry immediately.
	if distance and distance <= 15 then
		local closeTiming = timing:clone()
		closeTiming.duih = false

		local action = Action.new()
		action._when = 0
		action._type = "Parry"
		action.ihbc = true
		action.hitbox = Vector3.new(10, 10, 10)
		action.name = "Thrust (Close)"
		return self:action(closeTiming, action)
	end

	-- Far range: wait until thrust reaches us, then parry.
	local timestamp = os.clock()

	timing.fhb = true
	timing.duih = true

	self:hook("stopped", function()
		return os.clock() - timestamp >= 2.0
	end)

	local action = Action.new()
	action._when = 0
	action._type = "Parry"
	action.hitbox = Vector3.new(10, 10, 22)
	action.name = "Thrust (Far)"
	self:action(timing, action)
end
