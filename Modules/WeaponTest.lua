---@class Action
local Action = getfenv().Action

---@module Modules.Globals.Weapon
local Weapon = getfenv().Weapon

---@module Utility.Signal
local Signal = getfenv().Signal

---@module Utility.Configuration
local Configuration = getfenv().Configuration

---@module Features.Combat.Objects.RepeatInfo
local RepeatInfo = getfenv().RepeatInfo

---@module Game.Latency
local Latency = getfenv().Latency

---@module Utility.TaskSpawner
local TaskSpawner = getfenv().TaskSpawner

---@type ProjectileTracker
---@diagnostic disable-next-line: unused-local
local ProjectileTracker = getfenv().ProjectileTracker

---@type PartTiming
local PartTiming = getfenv().PartTiming

---@module Features.Combat.Defense
local Defense = getfenv().Defense

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	if self.entity.Name:match("evengarde") and (timing.name:match("1SwordSwing1") or timing.name:match("1SwordSwing2")) then
		-- Skip if already running parry loop.
		if _G.EvengardeSwingGuard and (os.clock() - _G.EvengardeSwingGuard) < 4 then
			return
		end
		_G.EvengardeSwingGuard = os.clock()

		timing.ndfb = true
		timing.pbfb = true
		timing.bfht = 0.15

		-- Repeat parry via actions in spawned task (avoids task cleanup on animation spam).
		TaskSpawner.spawn("EvengardeSwingParry", function()
			task.wait(0.4)
			local startTime = os.clock()
			while (os.clock() - startTime) < 3 do
				local action = Action.new()
				action._when = 0
				action._type = "Parry"
				action.hitbox = Vector3.new(55, 55, 55)
				action.name = "Evengarde Sword Swing"
				self:action(timing, action)
				task.wait(0.01)
			end
		end)
		return
	end

	local data = Weapon.data(self.entity)
	if not data then
		return
	end

	local humanoidRootPart = self.entity:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	-- Funny htibox options.
	timing.htype = Enum.PartType.Ball
	timing.fhb = false
	timing.hso = -5

	-- Fallbacks. Reset to normal.
	timing.nvfb = true
	timing.pbfb = false
	timing.ndfb = false
	timing.bfht = 0.3

	-- Prediction settings.
	timing.dp = false
	timing.pfh = true
	timing.phd = true

	-- Prediction history times.
	timing.pfht = 0.25
	timing.phds = 0.6

	if data.type == "Fist" or data.type == "Dagger" then
		timing.phd = false
		timing.duih = false
		timing.ffh = true
		timing.pfht = 0.5
		timing.dp = false
	end

	if
		data.type == "Sword"
		or data.type == "Staff"
		or data.type == "Twinblade"
		or data.type == "Spear"
		or data.type == "Club"
		or data.type == "Rifle"
		or data.type == "Pistol"
	then
		timing.pbfb = true
		timing.bfht = 0.3
		timing.phd = false
		timing.duih = false
		timing.ffh = true
		timing.pfht = 0.7
	end

	if
		data.type == "Greathammer"
		or data.type == "Greatcannon"
		or data.type == "Greatsword"
		or data.type == "Greataxe"
	then
		timing.phd = false
		timing.duih = false
		timing.ffh = true
		timing.pfht = 0.5
		timing.dp = false
	end

	local windup = nil
	local hitbox = nil
	local ispeed = self.track.Speed

	-- Windup + 0-speed duration.

	if data.type == "Greataxe" and self.track.Speed ~= 1.0 then
		windup = (0.171 / self.track.Speed) + 0.120
	elseif data.type == "Greataxe" and self.track.Speed == 1.0 then
		windup = (0.171 / self.track.Speed)
		windup += 0.250 / data.ss
	elseif data.type == "Greathammer" and self.track.Speed ~= 1.0 then
		windup = (0.150 / self.track.Speed) + 0.200
	elseif data.type == "Greathammer" and self.track.Speed == 1.0 then
		windup = (0.150 / self.track.Speed)
		windup += 0.250 / data.ss
	elseif data.type == "Greatcannon" and self.track.Speed ~= 1.0 then
		windup = (0.155 / self.track.Speed) + 0.160
	elseif data.type == "Greatcannon" and self.track.Speed == 1.0 then
		windup = (0.155 / self.track.Speed) + 0.300
	elseif data.type == "Rapier" then
		windup = (0.155 / self.track.Speed) + 0.120
	elseif data.type == "Bow" then
		local thrown_object = workspace.Thrown:FindFirstChild("Attach_" .. self.entity.Name)
		local tip_attachment = thrown_object and thrown_object:FindFirstChild("HandWeapon") and thrown_object:FindFirstChild("HandWeapon"):FindFirstChild("TipAttachment")
		if tip_attachment then
			local ready = false
			while task.wait() and self.track.IsPlaying do
				ready = tip_attachment:FindFirstChild("Spark")
				if ready then break end
			end

			if not ready then return end
		end
		windup = 0.1
	elseif data.type == "Pistol" and not timing.name:match("Shot") then
		windup = 0.350 / data.ss
	elseif data.type == "Pistol" and timing.name:match("Shot") then
		repeat
			task.wait()
		until self.track.Speed ~= ispeed

		windup = 0.075 / self.track.Speed

		if self.track.Speed == 0.0 then
			windup = 0.100
		end
	elseif data.type == "Rifle" and timing.name:match("2") then
		repeat
			task.wait()
		until self.track.Speed ~= ispeed

		windup = (0.150 / self.track.Speed)

		if self.track.Speed == 0.0 then
			windup = 0.100
		end
	elseif data.type == "Rifle" then
		windup = (0.174 / self.track.Speed) + 0.125
	elseif data.type == "Club" then
		windup = (0.180 / self.track.Speed) + 0.100
	elseif data.type == "Twinblade" then
		windup = (0.200 / self.track.Speed) + 0.050
	elseif data.type == "Spear" then
		windup = (0.150 / self.track.Speed) + 0.100
	elseif data.type == "Greatsword" then
		windup = (0.158 / self.track.Speed) + 0.150
	elseif data.type == "Fist" then
		windup = (0.140 / self.track.Speed) + 0.130
	elseif data.type == "Dagger" then
		windup = (0.200 / self.track.Speed) + 0.075
	elseif data.type == "Staff" then
		windup = 0.350
	elseif data.type == "Sword" then
		windup = (0.200 / self.track.Speed) + 0.100
	end

	if self.entity.Name:lower():match("titus") and data.type == "Fist" then
		repeat
			task.wait()
		until self.track.Speed > 0

		local finalSpeed = self.track.Speed + 0.2

		self:notify(timing, "Titus M1 Windup")

		local action = Action.new()
		action._when = (565 * 0.76) / finalSpeed
		action._type = "Parry"
		action.hitbox = Vector3.new(data.length * 2.1, data.length * 2.1, data.length * 2.1)
		action.name = string.format("(%.2f) Titus M1 Windup", finalSpeed)

		return self:action(timing, action)
	end

	if not windup then
		return self:notify(timing, "(%s) No windup for this weapon type.", data.type)
	end

	-- Create action.
	local action = Action.new()
	action._when = windup * 1000
	action._type = "Parry"
	action.hitbox = hitbox or Vector3.new(data.length * 2.1, data.length * 2.1, data.length * 2.1)
	action.name = string.format(
		"(%.2f, %.2f, %.2f) (%.2f) Dynamic Weapon Swing",
		data.oss,
		data.ss,
		self.track.Speed,
		data.length
	)
	
	if data.type == "Pistol" then
		TaskSpawner.spawn("WeaponTest_ScrapsingerBullet", function()
			local thrown = workspace:FindFirstChild("Thrown")
			if not thrown then
				return
			end

			local tracker = ProjectileTracker.new(function(candidate)
				return candidate.Name == "ScrapsingerBullet_" .. self.entity.Name
			end)

			local bulletAction = Action.new()
			bulletAction._when = 0
			bulletAction._type = "Parry"
			bulletAction.name = "Scrapsinger Bullet"

			local pt = PartTiming.new()
			pt.uhc = true
			pt.duih = true
			pt.fhb = true
			pt.name = "ScrapsingerBulletProjectile"
			pt.hitbox = Vector3.new(20, 35, 15)
			pt.actions:push(bulletAction)
			pt.cbm = true

			Defense.cdpo(tracker:wait(), pt)
		end)
	end
	
	return self:action(timing, action)
end
