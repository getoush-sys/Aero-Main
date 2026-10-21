---@module Features.Combat.Objects.Defender
local Defender = require("Features/Combat/Objects/Defender")

---@module Game.Timings.SaveManager
local SaveManager = require("Game/Timings/SaveManager")

---@module Features.Combat.Objects.RepeatInfo
local RepeatInfo = require("Features/Combat/Objects/RepeatInfo")

---@module Features.Combat.Objects.HitboxOptions
local HitboxOptions = require("Features/Combat/Objects/HitboxOptions")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Game.Latency
local Latency = require("Game/Latency")

---@class PartDefender: Defender
---@field part BasePart
---@field owner Model? The owner of the part, if resolvable.
---@field timing PartTiming
---@field touched boolean Determines whether if we touched the timing in the past.
---@field vuid string Visualizer UID.
local PartDefender = setmetatable({}, { __index = Defender })
PartDefender.__index = PartDefender
PartDefender.__type = "Part"

local players = game:GetService("Players")

---@param self PartDefender
---@return CFrame
PartDefender.cframe = LPH_NO_VIRTUALIZE(function(self)
	return self.timing.uhc and self.part.CFrame or CFrame.new(self.part.Position)
end)

---@param self PartDefender
---@param options ValidationOptions
---@return boolean
PartDefender.valid = LPH_NO_VIRTUALIZE(function(self, options)
	if not Defender.valid(self, options) then
		return false
	end

	local function internalNotifyFunction(timing, message)
		if not options.notify then
			return
		end

		return self:notify(timing, message)
	end

	local timing = options.timing
	local action = options.action

	local character = players.LocalPlayer.Character
	if not character then
		return internalNotifyFunction(timing, "No character found.")
	end

	local hoptions = HitboxOptions.new(self.part, timing)
	hoptions.spredict = false
	hoptions.action = action
	hoptions:ucache()

	if not timing.duih or timing.umoa then
		if not self:hc(hoptions, timing.duih and RepeatInfo.new(timing, Latency.rdelay(), self.vuid) or nil) then
			return internalNotifyFunction(timing, "Not in hitbox.")
		end
	end

	return true
end)

---@param self PartDefender
PartDefender.update = LPH_NO_VIRTUALIZE(function(self)
	if not self.timing.duih or self.timing.umoa then
		return
	end

	if #self.tasks > 0 then
		return
	end

	local localPlayer = players.LocalPlayer
	if not localPlayer then
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end

	local hb = self.timing.hitbox

	---@note: If we're using PartDefender, why perserve rotation? It's likely wrong or gonna mess us up.
	local touching, cframe = self:hitbox(
		self:cframe(),
		self.timing.fhb,
		self.timing.hso,
		hb,
		{ character },
		self.timing.htype or Enum.PartType.Block
	)

	if cframe then
		self:visualize(
			self.vuid,
			cframe,
			hb,
			touching and Color3.fromHex("#DDF527") or Color3.fromHex("#2765F5"),
			self.timing.htype or Enum.PartType.Block
		)
	end

	if not touching then
		return
	end

	if self.touched and touching then
		return
	end

	self.touched = touching

	self:clean()

	---@note: Start processing the timing. Add the actions if we're not RPUE.
	if not self.timing.rpue then
		return self:actions(self.timing)
	end

	local info = RepeatInfo.new(self.timing, Latency.rdelay(), self:uid(10))
	self:srpue(self.entity, self.timing, info)
end)

---@param part BasePart
---@param timing PartTiming?
---@return PartDefender?
function PartDefender.new(part, timing)
	if not Configuration.expectToggleValue("EnableAutoDefense") then
		return nil
	end

	local okey = nil

	if part.Name:match("VengefulSlash") then
		okey = "VengefulSlashes"
	end

	if not timing and not SaveManager.ps:index(okey or part.Name) and not Configuration.expectToggleValue("ShowLoggerWindow") then
		return nil
	end

	local self = setmetatable(Defender.new(), PartDefender)
	self.part = part
	self.owner = part:FindFirstAncestorWhichIsA("Model")

	if not self.owner then
		local localCharacter = players.LocalPlayer.Character
		local thrown = localCharacter and workspace:FindFirstChild("Thrown")
		local ownAttach = thrown and thrown:FindFirstChild("Attach_" .. localCharacter.Name)

		if ownAttach and part:IsDescendantOf(ownAttach) then
			self.owner = localCharacter
		end
	end

	self.timing = timing or self:initial(part, SaveManager.ps, nil, okey or part.Name)
	self.touched = false
	self.vuid = self:uid(10)

	if not self.timing then
		return nil
	end

	if self.timing.umoa then
		self:module(self.timing)
	end

	if self.timing.umoa or self.timing.duih then
		return self
	end

	local info = RepeatInfo.new(self.timing, Latency.rdelay(), self:uid(10))

	if self.timing.rpue then
		self:srpue(self.entity, self.timing, info)
	else
		self:actions(self.timing)
	end

	return self
end

return PartDefender
