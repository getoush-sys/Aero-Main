---@type PartTiming
local PartTiming = getfenv().PartTiming

---@type Action
local Action = getfenv().Action

---@type ProjectileTracker
---@diagnostic disable-next-line: unused-local
local ProjectileTracker = getfenv().ProjectileTracker

---@module Features.Combat.Defense
local Defense = getfenv().Defense

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local distance = self:distance(self.entity)

	local tracker = ProjectileTracker.new(function(candidate)
		return candidate.Name == "HandWeapon_" .. self.entity.Name
	end)

	if distance <= 10 then
		local action = Action.new()
		action._type = "Parry"
		action._when = 400
		action.name = "Stormbreaker Close"
		action.ihbc = true
		return self:action(timing, action)
	end

	local action = Action.new()
	action._when = 0
	action._type = "Start Block"
	action.name = "Stormbreaker Part"

	local actionTwo = Action.new()
	actionTwo._when = 500
	actionTwo._type = "End Block"
	actionTwo.name = "Stormbreaker"
	actionTwo.ihbc = true

	local pt = PartTiming.new()
	pt.uhc = true
	pt.duih = true
	pt.fhb = true
	pt.name = "StormbreakerProjectile"
	pt.hitbox = Vector3.new(20, 35, 20)
	pt.actions:push(action)
	pt.actions:push(actionTwo)
	pt.cbm = true

	Defense.cdpo(tracker:wait(), pt)
end
