---@module Menu.Objects.BuilderSection
local BuilderSection = require("Menu/Objects/BuilderSection")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Game.Timings.AnimationTiming
local AnimationTiming = require("Game/Timings/AnimationTiming")

---@class AnimationBuilderSection: BuilderSection
---@field animationId table
---@field repeatStartDelay table
---@field repeatUntilParryEnd table
---@field repeatParryDelay table
---@field timing AnimationTiming
local AnimationBuilderSection = setmetatable({}, { __index = BuilderSection })
AnimationBuilderSection.__index = AnimationBuilderSection

---@param tab table
function AnimationBuilderSection:tide(tab)
	self.animationId = tab:AddInput(nil, {
		Text = "Animation ID",
	})
end

---@param timing AnimationTiming
function AnimationBuilderSection:exload(timing)
	self.animationId:SetRawValue(timing._id)
	self.hyperarmor:SetRawValue(timing.ha)
	self.ignoreAnimationEnd:SetRawValue(timing.iae)
	self.ignoreEarlyAnimationEnd:SetRawValue(timing.ieae)
	self.maxAnimationTimeout:SetRawValue(timing.mat)
	self.pastHitboxDetection:SetRawValue(timing.phd)
	self.predictFacingHitboxes:SetRawValue(timing.pfh)
	self.historySeconds:SetRawValue(timing.phds)
	self.extrapolationTime:SetRawValue(timing.pfht)
end

function AnimationBuilderSection:reset()
	BuilderSection.reset(self)
	self.animationId:SetRawValue("")
	self.hyperarmor:SetRawValue(false)
	self.hitboxFacingOffset:SetRawValue(true)
	self.ignoreAnimationEnd:SetRawValue(false)
	self.ignoreEarlyAnimationEnd:SetRawValue(false)
	self.maxAnimationTimeout:SetRawValue(2000)
	self.pastHitboxDetection:SetRawValue(false)
	self.historySeconds:SetRawValue(0.5)
	self.predictFacingHitboxes:SetRawValue(false)
	self.extrapolationTime:SetRawValue(0.15)
end

---@return boolean
function AnimationBuilderSection:check()
	if not BuilderSection.check(self) then
		return false
	end

	if not self.animationId.Value or #self.animationId.Value <= 0 then
		return Logger.longNotify("Please enter a valid animation ID.")
	end

	local timing = self.pair:index(self.animationId.Value)
	if timing then
		return Logger.longNotify("The timing ID '%s' (%s) is already in the list.", self.animationId.Value, timing.name)
	end

	return true
end

---@param timing AnimationTiming
function AnimationBuilderSection:cset(timing)
	timing.name = self.timingName.Value
	timing._id = self.animationId.Value
end

---@return Timing
function AnimationBuilderSection:create()
	local timing = AnimationTiming.new()
	self:cset(timing)
	return timing
end

---@param tab table
function AnimationBuilderSection:extra(tab)
	self.hyperarmor = tab:AddToggle(nil, {
		Text = "Hyperarmor Flag",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.ha = value
		end),
	})

	self.ignoreAnimationEnd = tab:AddToggle(nil, {
		Text = "Ignore Animation End",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.iae = value
		end),
	})

	local depBoxEnd = tab:AddDependencyBox()

	self.maxAnimationTimeout = depBoxEnd:AddInput(nil, {
		Text = "Max Animation Timeout",
		Default = 2000,
		Numeric = true,
		Callback = self:tnc(function(timing, value)
			timing.mat = tonumber(value)
		end),
	})

	depBoxEnd:SetupDependencies({
		{ self.ignoreAnimationEnd, true },
	})

	self.ignoreEarlyAnimationEnd = tab:AddToggle(nil, {
		Text = "Ignore Early Animation End",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.ieae = value
		end),
	})

	self.pastHitboxDetection = tab:AddToggle(nil, {
		Text = "Past Hitbox Detection",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.phd = value
		end),
	})

	local pfdOffDepBox = tab:AddDependencyBox()

	self.historySeconds = pfdOffDepBox:AddSlider(nil, {
		Text = "History Seconds",
		Default = 0.5,
		Min = 0,
		Max = 3.0,
		Rounding = 2,
		Numeric = true,
		Callback = self:tnc(function(timing, value)
			timing.phds = tonumber(value) or 0
		end),
	})

	pfdOffDepBox:SetupDependencies({
		{ self.pastHitboxDetection, true },
	})

	self.predictFacingHitboxes = tab:AddToggle(nil, {
		Text = "Predict Facing Hitboxes",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.pfh = value
		end),
	})

	self.disablePrediction = tab:AddToggle(nil, {
		Text = "Disable Prediction",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.dp = value
		end),
	})

	self.extrapolationTime = tab:AddSlider(nil, {
		Text = "Extrapolation Time",
		Default = 0.15,
		Min = 0,
		Max = 2.0,
		Rounding = 3,
		Numeric = true,
		Callback = self:tnc(function(timing, value)
			timing.pfht = tonumber(value)
		end),
	})
end

---@param name string
---@param tabbox table
---@param pair TimingContainerPair
---@param timing AnimationTiming
---@return AnimationBuilderSection
function AnimationBuilderSection.new(name, tabbox, pair, timing)
	return setmetatable(BuilderSection.new(name, tabbox, pair, timing), AnimationBuilderSection)
end

return AnimationBuilderSection
