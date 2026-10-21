---@class Action
local Action = getfenv().Action

---@module Modules.Globals.Mantra
local Mantra = getfenv().Mantra

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local data = Mantra.data(self.entity, "Mantra:RisingSlashFire{{Rising Flame}}")
	local range = data.stratus * 3 + data.cloud * 2
	local action = Action.new()
	action._when = 400
	action._type = "Parry"
	action.hitbox = Vector3.new(30 + range, 25, 30 + range)
	action.name = "Dynamic Rising Flame Timing"
	self:action(timing, action)
end
