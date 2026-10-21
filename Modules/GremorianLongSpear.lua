---@type PartTiming
local PartTiming = getfenv().PartTiming

---@type Action
local Action = getfenv().Action

---@type ProjectileTracker
---@diagnostic disable-next-line: unused-local
local ProjectileTracker = getfenv().ProjectileTracker

---@module Features.Combat.Defense
local Defense = getfenv().Defense

---@module Game.Latency
local Latency = getfenv().Latency

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

	local thrown = workspace:FindFirstChild("Thrown")
	if not thrown then
		return
	end

	local tracker = ProjectileTracker.new(function(candidate)
		return candidate.Name == "BloodtideProjectile_" .. self.entity.Name
	end)

	task.wait(0.5 - Latency.rtt())
	
	if handWeapon:GetAttribute("WeaponName") == "Bloodtide Trident" and self:distance(self.entity) <= 35 then
		local action = Action.new()
		action._type = "Parry"
		action._when = 0
		action.name = "Bloodtide Trident Close Timing"
		action.fhb = false
		action.ihbc = true
		return self:action(timing, action)
	end

	if handWeapon:GetAttribute("WeaponName") == "Gremorian Longspear" then
		local action = Action.new()
		action._when = 500
		action._type = "Parry"
		action.hitbox = Vector3.new(15, 30, 40)
		action.name = string.format("(%.2f) Gremorian Longspear Critical")
		action.fhb = true
		return self:action(timing, action)
	end

	local action = Action.new()
	action._when = 0
	action._type = "Parry"
	action.name = "Bloodtide Trident Part"

	local pt = PartTiming.new()
	pt.uhc = true
	pt.duih = true
	pt.fhb = false
	pt.name = "BloodtideTridentProjectile"
	pt.hitbox = Vector3.new(20, 50, 20)
	pt.actions:push(action)
	pt.cbm = true

	Defense.cdpo(tracker:wait(), pt)
end
