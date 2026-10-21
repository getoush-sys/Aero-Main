---@module Features.Combat.Objects.RepeatInfo
local RepeatInfo = getfenv().RepeatInfo

---@module Game.Latency
local Latency = getfenv().Latency

---@module Game.Timings.PartTiming
local PartTiming = getfenv().PartTiming

-- Services.
local players = game:GetService("Players")

---Module function.
---@param self PartDefender
---@param timing PartTiming
return function(self, timing)
	local humanoid = players.LocalPlayer
		and players.LocalPlayer.Character
		and players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return
	end

	for _, track in next, humanoid:GetPlayingAnimationTracks() do
		if track.Animation.AnimationId == "rbxassetid://9919986614" then
			return
		end
	end

	local ntiming = PartTiming.new()
	ntiming.name = "SinisterHaloRepeat"
	ntiming.duih = true
	ntiming.hitbox = Vector3.new(20, 20, 20)
	ntiming.fhb = false
	ntiming.ndfb = true
	ntiming._rsd = 0
	ntiming._rpd = 125
	ntiming.imxd = 120
	ntiming.imdd = 0
	ntiming.mrt = 1.75

	ntiming.rsd = function()
		return ntiming._rsd / 1000
	end

	ntiming.rpd = function()
		return ntiming._rpd / 1000
	end

	local info = RepeatInfo.new(ntiming, Latency.rdelay(), self:uid(10))
	self:srpue(self.part, ntiming, info)
end
