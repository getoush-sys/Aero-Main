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
		return candidate.Name == "IceDagger_" .. self.entity.Name
	end)

	if distance <= 10 then
		local action = Action.new()
		action._type = "Parry"
		action._when = math.min(600 + distance * 10, 1200)
		action.name = "Ice Dagger Close Timing"
		action.ihbc = true
		return self:action(timing, action)
	end

	if distance <= 20 then
		local action = Action.new()
		action._type = "Parry"
		action._when = math.min(700 + distance * 4, 1200)
		action.name = "Ice Dagger Mid Timing"
		action.ihbc = true
		return self:action(timing, action)
	end

	local action = Action.new()
	action._when = 0
	action._type = "Start Block"
	action.name = "Ice Dagger Part"

	local actionTwo = Action.new()
	actionTwo._when = 500
	actionTwo._type = "End Block"
	actionTwo.name = "Ice Dagger End"
	actionTwo.ihbc = true

	local pt = PartTiming.new()
	pt.uhc = true
	pt.duih = true
	pt.fhb = true
	pt.name = "Ice Dagger Projectile"
	pt.hitbox = Vector3.new(20, 35, 15)
	pt.actions:push(action)
	pt.actions:push(actionTwo)
	pt.cbm = true

	Defense.cdpo(tracker:wait(), pt)
end
