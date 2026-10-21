---@module Modules.Globals.ProjectileListener
local ProjectileListener = getfenv().ProjectileListener

---@type PartTiming
local PartTiming = getfenv().PartTiming

---@type Action
local Action = getfenv().Action

---@module Features.Combat.Defense
local Defense = getfenv().Defense

---@module Modules.Globals.Mantra
local Mantra = getfenv().Mantra

-- Create listener for Fire Forge projectiles
local plistener = ProjectileListener.new("FireForge")

---@module Game.Latency
local Latency = getfenv().Latency

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local thrown = workspace:FindFirstChild("Thrown")
	if not thrown then
		return
	end

	local player = game:GetService("Players"):GetPlayerFromCharacter(self.entity)
	local backpack = player and player:FindFirstChild("Backpack")
	local mantra = Mantra.data(self.entity, "Mantra:ForgeFire{{Fire Forge}}")

	if mantra and mantra.tornado then
		local distance = self:distance(self.entity)

		timing.iae = true
		timing.mat = 1500
		timing.duih = true
		timing.hitbox = Vector3.new(20, 25, 60)

		local action = Action.new()
		action._when = 300
		action._type = "Start Block"
		action.name = string.format("(%.2f) Fire Forge Tornado Spark", distance)
		self:action(timing, action)

		local actionEnd = Action.new()
		actionEnd._when = math.min(1300 + distance * 3)
		actionEnd._type = "End Block"
		actionEnd.name = string.format("(%.2f) Fire Forge Tornado Spark End", distance)
		return self:action(timing, actionEnd)
	end

	if backpack and backpack:FindFirstChild("Mantra:ForgeFire{{Fire Forge}}") then
		timing.ffh = true

		local action = Action.new()
		action._when = 300
		action._type = "Parry"
		action.hitbox = Vector3.new(15, 25, 25)
		action.name = "FireForge Timing"
		self:action(timing, action)
	end

	plistener:connect(function(child)
		if
			not child.Name:match("FireDagger_" .. self.entity.Name)
			and not child.Name:match("FireDaggerBlue_" .. self.entity.Name)
		then
			return
		end

		task.wait(0.01 - Latency.rtt())

		if self:distance(self.entity) <= 20 then
			local action = Action.new()
			action._type = "Parry"
			action._when = 0
			action.name = "Fire Forge Close Timing"
			action.hitbox = Vector3.new(18, 18, 25)
			action.fhb = true
			action.ihbc = false
			return self:action(timing, action)
		end

		local action = Action.new()
		action._when = 0
		action._type = "Parry"
		action.name = "Fire Forge Part"

		local pt = PartTiming.new()
		pt.uhc = true
		pt.duih = true
		pt.fhb = true
		pt.ndfb = true
		pt.name = "FireForgeProjectile"
		pt.hitbox = Vector3.new(12, 8, 10)
		pt.actions:push(action)
		pt.cbm = true

		Defense.cdpo(child, pt)
	end)
end
