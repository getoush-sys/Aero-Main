---@class Action
local Action = getfenv().Action

---@module Modules.Globals.Weapon
local Weapon = getfenv().Weapon

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local handWeapon = Weapon.handWeapon(self.entity)

	if handWeapon and handWeapon:GetAttribute("WeaponName") == "Iron Birch" then
		local action = Action.new()
		action._when = 500
		action._type = "Parry"
		action.hitbox = Vector3.new(25, 20, 20)
		action.name = "Iron Birch Onslaught Timing"
		return self:action(timing, action)
	end

	local action = Action.new()
	action._when = 700
	action._type = "Parry"
	action.hitbox = Vector3.new(25, 20, 20)
	action.name = "Onslaught Timing"
	return self:action(timing, action)
end
