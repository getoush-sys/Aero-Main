---@class Action
local Action = getfenv().Action

---@module Modules.Globals.Weapon
local Weapon = getfenv().Weapon

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local player = game:GetService("Players"):GetPlayerFromCharacter(self.entity)
	local backpack = player and player:FindFirstChild("Backpack")

	if backpack and backpack:FindFirstChild("Mantra:LeapStrength{{Strong Leap}}") then
		return
	end

	local action = Action.new()
	action._when = 400
	action._type = "Parry"
	action.hitbox = Vector3.new(31, 31, 31)
	action.name = "Flameleap Timing"
	return self:action(timing, action)
end
