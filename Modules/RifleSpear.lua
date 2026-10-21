---@class Action
local Action = getfenv().Action

---@module Modules.Globals.Weapon
local Weapon = getfenv().Weapon

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local handWeapon = Weapon.handWeapon(self.entity)
	if not handWeapon then
		return
	end

	local weaponName = handWeapon:GetAttribute("WeaponName")
	if weaponName == "Rifle Spear" then
		local action = Action.new()
		action._when = 370
		action._type = "Parry"
		action.hitbox = Vector3.new(14, 14, 20)
		action.name = "Rifle Spear Critical"

		self:action(timing, action)
	end
end
