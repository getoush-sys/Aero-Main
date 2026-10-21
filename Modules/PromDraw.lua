---@type Action
local Action = getfenv().Action

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local distance = self:distance(self.entity)

	local handWeapon = Weapon.handWeapon(self.entity)

	if handWeapon and handWeapon:GetAttribute("WeaponName") == "Forgotten Gladius" then
		local action = Action.new()
		action._when = math.min(300 + distance * 4)
		action._type = "Parry"
		action.hitbox = Vector3.new(60, 60, 60)
		action.name = string.format("(%.2f) Dynamic Forgotten Glad Prominence Draw Timing", distance)
		return self:action(timing, action)
	end

	local action = Action.new()
	action._when = math.min(400 + distance * 10)
	action._type = "Parry"
	action.hitbox = Vector3.new(60, 60, 60)
	action.name = string.format("(%.2f) Dynamic Prominence Draw Timing", distance)

	return self:action(timing, action)
end
