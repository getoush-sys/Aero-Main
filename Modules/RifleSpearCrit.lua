---@type Action
local Action = getfenv().Action

---@module Modules.Globals.Weapon
local Weapon = getfenv().Weapon

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	timing.pfh = true
	timing.phd = true
	timing.pfht = 0.3
	timing.phds = 1.0

	local handWeapon = Weapon.handWeapon(self.entity)
	if not handWeapon then
		return
	end

	if handWeapon:GetAttribute("WeaponName") == "Kyrsieger" then
		return
	end

	local action = Action.new()
	action._when = 370
	action._type = "Parry"
	action.hitbox = Vector3.new(14, 11, 20)
	action.name = "Rifle Spear Crit Timing"
	return self:action(timing, action)
end
