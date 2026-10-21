---@module Modules.Globals.ProjectileListener
local ProjectileListener = getfenv().ProjectileListener

---@class Action
local Action = getfenv().Action

---@module Features.Combat.Defense
local Defense = getfenv().Defense

---@module Game.Timings.PartTiming
local PartTiming = getfenv().PartTiming

---@module Modules.Globals.Mantra
local Mantra = getfenv().Mantra

local Latency = getfenv().Latency

-- Listener object.
local plistener = ProjectileListener.new("WindTrap")

task.wait(math.max(0, 0.5 - Latency.rtt()))

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local player = game:GetService("Players"):GetPlayerFromCharacter(self.entity)
	local backpack = player and player:FindFirstChild("Backpack")
	local players = game:GetService("Players")
	local humanoid = players.LocalPlayer
		and players.LocalPlayer.Character
		and players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return
	end

	for _, track in next, humanoid:GetPlayingAnimationTracks() do
		if track.Animation.AnimationId == "rbxassetid://7608490737" then
			return
		end
	end

	if backpack and backpack:FindFirstChild("Mantra:TrapWind{{Galetrap}}") then
		timing.ffh = true

		local action = Action.new()
		action._when = 100
		action._type = "Parry"
		action.hitbox = Vector3.new(10, 25, 25)
		action.name = "Galetrap Timing"

		
		plistener:connect(function(child)
			if child.Name ~= "WindTrap" then
				return
			end

			local action = Action.new()
			action._when = 0
			action._type = "Parry"
			action.name = "Galetrap Part"

			local pt = PartTiming.new()
			pt.uhc = true
			pt.duih = true
			pt.fhb = true
			pt.ndfb = true
			pt.name = "GaletrapProjectile"
			pt.hitbox = Vector3.new(50, 30, 30)
			pt.actions:push(action)
			pt.cbm = true

			Defense.cdpo(child, pt)
		end)

		return self:action(timing, action)
	end
end
