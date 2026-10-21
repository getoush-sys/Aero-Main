---@module Game.Timings.Action
local Action = require("Game/Timings/Action")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Game.Timings.Timing
local Timing = require("Game/Timings/Timing")

---@module Game.Timings.SaveManager
local SaveManager = require("Game/Timings/SaveManager")

---@class BuilderSection
---@note: We assume that all elements will exist in callbacks. This is why they are not explicitly set in the constructor.
---@field tabbox table
---@field pair TimingContainerPair
---@field name string
---@field timingList table
---@field timingName table
---@field timingTag table
---@field ignoreAutoParryFrames table
---@field useInhaleFeint table
---@field skipIfRecentlySelfCast table
---@field recentSelfCastAnimationId table
---@field recentSelfCastWindow table
---@field hitboxLength table
---@field hitboxWidth table
---@field hitboxHeight table
---@field timingType table
---@field punishableWindow table
---@field afterWindow table
---@field delayUntilInHitbox table
---@field initialMinimumDistance table
---@field initialMaximumDistance table
---@field actionList table
---@field actionName table
---@field actionDelay table
---@field actionType table
local BuilderSection = {}
BuilderSection.__index = BuilderSection

local stats = game:GetService("Stats")

---@param tab table
function BuilderSection:tide(tab) end

---@param tab table
function BuilderSection:extra(tab) end

---@param timing Timing
function BuilderSection:exload(timing) end

---@param action Action
function BuilderSection:exaload(action) end

---@param base table
function BuilderSection:daction(base)
	self.actionDelay = base:AddInput(nil, {
		Text = "Action Delay",
		Numeric = true,
		Finished = true,
		Callback = self:anc(function(action, value)
			action._when = tonumber(value)
		end),
	})
end

function BuilderSection:reset()
	self.timingName:SetRawValue("")
	self.timingType:SetRawValue("Config")
	self.timingTag:SetRawValue("Undefined")
	self.initialMaximumDistance:SetRawValue(0)
	self.punishableWindow:SetRawValue(0)
	self.afterWindow:SetRawValue(0)
	self.initialMinimumDistance:SetRawValue(0)
	self.delayUntilInHitbox:SetRawValue(false)
	self.timingHitboxHeight:SetRawValue(0)
	self.timingHitboxLength:SetRawValue(0)
	self.timingHitboxWidth:SetRawValue(0)
	self.repeatParryDelay:SetRawValue(0)
	self.repeatStartDelay:SetRawValue(0)
	self.repeatUntilParryEnd:SetRawValue(false)
	self.useModuleOverActions:SetRawValue(false)
	self.skipModuleNotification:SetRawValue(false)
	self.selectedModule:SetRawValue("")
	self.skipRepeatNotification:SetRawValue(false)
	self.noDashFallback:SetRawValue(false)
	self.noVentFallback:SetRawValue(false)
	self.hitboxFacingOffset:SetRawValue(true)
	self.hitboxShiftOffset:SetRawValue(0)
	self.blockFallbackHoldTime:SetRawValue(0.3)
	self.noBlockFallback:SetRawValue(false)
	self.ignoreBlockInput:SetRawValue(false)
	self.ignoreAutoParryFrames:SetRawValue(false)
	self.useInhaleFeint:SetRawValue(false)
	self.skipIfRecentlySelfCast:SetRawValue(false)
	self.recentSelfCastAnimationId:SetRawValue("")
	self.recentSelfCastWindow:SetRawValue(4)

	self:arefresh(nil)

	self:raction()
end

---@return boolean
function BuilderSection:check()
	if not self.timingName.Value or #self.timingName.Value <= 0 then
		return Logger.longNotify("Please enter a valid timing name.")
	end

	if self.pair:find(self.timingName.Value) then
		return Logger.longNotify("The timing '%s' already exists in the list.", self.timingName.Value)
	end

	return true
end

---@param timing Timing
---@return boolean
function BuilderSection:acheck(timing)
	if not self.actionName.Value or #self.actionName.Value <= 0 then
		return Logger.longNotify("Please enter a valid action name.")
	end

	if timing.actions:find(self.actionName.Value) then
		return Logger.longNotify("The action '%s' already exists in the list.", self.actionName.Value)
	end

	return true
end

---@param timing Timing
function BuilderSection:cset(timing)
	timing.name = self.timingName.Value
end

---@return Timing
function BuilderSection:create()
	local timing = Timing.new()
	self:cset(timing)
	return timing
end

function BuilderSection:action()
	local tab = self.tabbox:AddTab("Action")

	self.repeatUntilParryEnd = tab:AddToggle(nil, {
		Text = "Repeat Parry Until End",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.rpue = value
		end),
	})

	local depBoxOn = tab:AddDependencyBox()

	self.repeatStartDelay = depBoxOn:AddInput(nil, {
		Text = "Repeat Start Delay",
		Numeric = true,
		Finished = true,
		Callback = self:tnc(function(timing, value)
			timing._rsd = tonumber(value) or 0
		end),
	})

	self.repeatParryDelay = depBoxOn:AddInput(nil, {
		Text = "Repeat Parry Delay",
		Numeric = true,
		Finished = true,
		Callback = self:tnc(function(timing, value)
			timing._rpd = tonumber(value) or 0
		end),
	})

	local depBoxOff = tab:AddDependencyBox()

	self:baction(depBoxOff)

	depBoxOn:SetupDependencies({
		{ self.repeatUntilParryEnd, true },
	})

	depBoxOff:SetupDependencies({
		{ self.repeatUntilParryEnd, false },
	})
end

function BuilderSection:raction()
	self.actionName:SetRawValue("")
	self.actionDelay:SetRawValue(0)
	self.actionType:SetRawValue("Parry")
	self.hitboxHeight:SetRawValue(0)
	self.hitboxLength:SetRawValue(0)
	self.hitboxWidth:SetRawValue(0)
end

function BuilderSection:refresh()
	local values = self.timingType.Value == "Internal" and self.pair.internal:names() or self.pair.config:names()
	self.timingList:SetValues(values)
	self.timingList:SetValue(nil)
	self.timingList:Display()
end

---@param timing Timing?
function BuilderSection:arefresh(timing)
	self.actionList:SetValues(timing and timing.actions:names() or {})
	self.actionList:SetValue(nil)
	self.actionList:Display()
end

---Resolve the editable (config-side) timing for a name. If only a baked-in (internal) timing exists,
---it's auto-cloned into the config so edits are saved as an override (config shadows internal on
---lookup). This is what makes editing baked-in timings "just work" instead of silently doing nothing.
---@param name string?
---@return Timing?
function BuilderSection:editable(name)
	if not name then
		return nil
	end

	-- Already an editable config timing (either user-created or a previously-cloned override).
	local existing = self.pair.config:find(name)
	if existing then
		return existing
	end

	-- Only a baked-in internal timing exists -> clone it into the config on first edit.
	local internalFound = self.pair.internal:find(name)
	if not internalFound then
		return nil
	end

	local clone = internalFound:clone()

	local ok = pcall(function()
		self.pair.config:push(clone)
	end)
	if not ok then
		-- Something already occupies that id/name in the config; fall back to it.
		return self.pair.config:find(name)
	end

	Logger.notify("Created a config override for '%s' so your changes are saved.", name)

	return clone
end

---@param callback function(Timing, ...)
---@return function(...)
function BuilderSection:tnc(callback)
	return function(...)
		if not self.timingList.Value then
			return Logger.warn("No timing selected.")
		end

		local timing = self:editable(self.timingList.Value)
		if not timing then
			return Logger.longNotify("You must select a valid timing to perform this action.")
		end

		callback(timing, ...)
		SaveManager.markDirty()
	end
end

---@note: This will check for internal timings.
---@param callback function(Timing, Action, ...)
---@return function
function BuilderSection:tanc(callback)
	return function(...)
		if not self.timingList.Value then
			return Logger.warn("No timing selected.")
		end

		-- Resolve (auto-cloning internal -> config) so the action edit lands on the editable copy.
		local timing = self:editable(self.timingList.Value)
		if not timing then
			return Logger.longNotify("You must select a valid timing to perform this action.")
		end

		if not self.actionList.Value then
			return Logger.warn("No action selected.")
		end

		local action = timing.actions:find(self.actionList.Value)
		if not action then
			return Logger.longNotify("You must select a valid action to perform this action.")
		end

		callback(timing, action, ...)
		SaveManager.markDirty()
	end
end

---@param callback function(Action, ...)
---@return function
function BuilderSection:anc(callback)
	return function(...)
		if not self.timingList.Value then
			return Logger.warn("No timing selected.")
		end

		-- Resolve (auto-cloning internal -> config) so the action edit lands on the editable copy.
		local timing = self:editable(self.timingList.Value)
		if not timing then
			return Logger.longNotify("You must select a valid timing to perform this action.")
		end

		if not self.actionList.Value then
			return Logger.warn("No action selected.")
		end

		local action = timing.actions:find(self.actionList.Value)
		if not action then
			return Logger.longNotify("You must select a valid action to perform this action.")
		end

		callback(action, ...)
		SaveManager.markDirty()
	end
end

---@param base table
function BuilderSection:baction(base)
	self.actionList = base:AddDropdown(nil, {
		Text = "Action List",
		Values = {},
		AllowNull = true,
		Searchable = true,
		-- Read-only populate: look up WITHOUT cloning (browsing an internal timing's actions must not
		-- create a config override -- only actual edits should).
		Callback = function(value)
			self:raction()

			if not value then
				return Logger.warn("No action value.")
			end

			local timing = self.pair:find(self.timingList.Value)
			if not timing then
				return
			end

			local action = timing.actions:find(value)
			if not action then
				return Logger.longNotify("The selected action '%s' does not exist in the list.", value)
			end

			self.actionName:SetRawValue(action.name)
			self.actionDelay:SetRawValue(action._when or 0)
			self.actionType:SetRawValue(action._type)
			self.hitboxWidth:SetRawValue(action.hitbox.X)
			self.hitboxHeight:SetRawValue(action.hitbox.Y)
			self.hitboxLength:SetRawValue(action.hitbox.Z)

			self:exaload(action)
		end,
	})

	self.actionType = base:AddDropdown(nil, {
		Text = "Action Type",
		Values = {
			"Parry",
			"Dodge",
			"Forced Full Dodge",
			"Jump",
			"Start Block",
			"End Block",
			"Teleport Up",
			"Start Slide",
			"End Slide",
			"Start Crouch",
			"End Crouch",
		},
		Default = 1,
		Callback = self:anc(function(action, value)
			action._type = value
		end),
	})

	self:daction(base)

	self.hitboxLength = base:AddSlider(nil, {
		Text = "Hitbox Length",
		Min = 0,
		Max = 300,
		Suffix = "s",
		Default = 0,
		Rounding = 0,
		Callback = self:anc(function(action, value)
			action.hitbox = Vector3.new(action.hitbox.X, action.hitbox.Y, value)
		end),
	})

	self.hitboxWidth = base:AddSlider(nil, {
		Text = "Hitbox Width",
		Min = 0,
		Max = 300,
		Suffix = "s",
		Default = 0,
		Rounding = 0,
		Callback = self:anc(function(action, value)
			action.hitbox = Vector3.new(value, action.hitbox.Y, action.hitbox.Z)
		end),
	})

	self.hitboxHeight = base:AddSlider(nil, {
		Text = "Hitbox Height",
		Min = 0,
		Max = 300,
		Suffix = "s",
		Default = 0,
		Rounding = 0,
		Callback = self:anc(function(action, value)
			action.hitbox = Vector3.new(action.hitbox.X, value, action.hitbox.Z)
		end),
	})

	base:AddDivider()

	self.actionName = base:AddInput(nil, {
		Text = "Action Name",
	})

	base:AddButton(
		"Create New Action",
		self:tnc(function(timing)
			local actions = timing.actions

			if not self:acheck(timing) then
				return
			end

			local action = Action.new()
			action.name = self.actionName.Value
			action._type = "Parry"

			local network = stats:FindFirstChild("Network")
			local serverStatsItem = network and network:FindFirstChild("ServerStatsItem")
			local dataPingItem = serverStatsItem and serverStatsItem:FindFirstChild("Data Ping")

			if dataPingItem then
				action.ping = dataPingItem:GetValue()
			end

			actions:push(action)
			SaveManager.markDirty()

			self:arefresh(timing)

			self.actionList:SetValue(action.name)
			self.actionList:Display()
		end)
	)

	base:AddButton(
		"Duplicate Selected Action",
		self:tanc(function(timing, action)
			local actions = timing.actions

			if not self:acheck(timing) then
				return
			end

			local newAction = action:clone()
			newAction.name = self.actionName.Value

			local network = stats:FindFirstChild("Network")
			local serverStatsItem = network and network:FindFirstChild("ServerStatsItem")
			local dataPingItem = serverStatsItem and serverStatsItem:FindFirstChild("Data Ping")

			if dataPingItem then
				newAction.ping = dataPingItem:GetValue()
			end

			actions:push(newAction)

			self:arefresh(timing)

			self.actionList:SetValue(newAction.name)
			self.actionList:Display()
		end)
	)

	base:AddButton(
		"Remove Selected Action",
		self:tnc(function(timing)
			local selected = self.actionList.Value
			if not selected then
				return Logger.longNotify("Please select an action to remove.")
			end

			local actions = timing.actions

			local action = actions:find(selected)
			if not action then
				return Logger.longNotify("The selected action '%s' does not exist in the list.", selected)
			end

			actions:remove(action)

			self:arefresh(timing)
		end)
	)
end

function BuilderSection:timing()
	local tab = self.tabbox:AddTab("Timings")

	self.timingType = tab:AddDropdown(nil, {
		Text = "Timing Type",
		Values = { "Config", "Internal" },
		Default = 1,
		Callback = function()
			self:refresh()

			self:reset()
		end,
	})

	self.timingList = tab:AddDropdown(nil, {
		Text = "Timing List",
		Values = self.timingType.Value == "Internal" and self.pair.internal:names() or self.pair.config:names(),
		AllowNull = true,
		Searchable = true,
		Callback = function(value)
			self:reset()

			if not value then
				return Logger.warn("No timing value.")
			end

			local found = self.pair:find(value)
			if not found then
				return Logger.longNotify("The selected timing '%s' does not exist in the list.", value)
			end

			self.timingName:SetRawValue(found.name)
			self.timingTag:SetRawValue(found.tag)
			self.initialMaximumDistance:SetRawValue(found.imxd)
			self.initialMinimumDistance:SetRawValue(found.imdd)
			self.delayUntilInHitbox:SetRawValue(found.duih)
			self.timingHitboxLength:SetRawValue(found.hitbox.Z)
			self.timingHitboxWidth:SetRawValue(found.hitbox.X)
			self.timingHitboxHeight:SetRawValue(found.hitbox.Y)
			self.punishableWindow:SetRawValue(found.punishable)
			self.afterWindow:SetRawValue(found.after)
			self.useModuleOverActions:SetRawValue(found.umoa)
			self.skipModuleNotification:SetRawValue(found.smn)
			self.selectedModule:SetRawValue(found.smod)
			self.skipRepeatNotification:SetRawValue(found.srpn)
			self.hitboxFacingOffset:SetRawValue(found.fhb)
			self.hitboxShiftOffset:SetRawValue(found.hso)
			self.noDashFallback:SetRawValue(found.ndfb)
			self.noVentFallback:SetRawValue(found.nvfb)
			self.blockFallbackHoldTime:SetRawValue(found.bfht)
			self.noBlockFallback:SetRawValue(found.nbfb)
			self.ignoreBlockInput:SetRawValue(found.ibi)
			self.ignoreAutoParryFrames:SetRawValue(found.iapf)
			self.useInhaleFeint:SetRawValue(found.uif)
			self.ignoreFeintDetection:SetRawValue(found.nfd)
			self.skipIfRecentlySelfCast:SetRawValue(found.rsc)
			self.recentSelfCastAnimationId:SetRawValue(found.rsaid)
			self.recentSelfCastWindow:SetRawValue(found.rsaw)
			self.repeatParryDelay:SetRawValue(found._rpd)
			self.repeatStartDelay:SetRawValue(found._rsd)
			self.repeatUntilParryEnd:SetRawValue(found.rpue)

			self:exload(found)

			self:arefresh(found)
		end,
	})

	tab:AddDivider()

	self.timingName = tab:AddInput(nil, {
		Text = "Timing Name",
		Finished = true,
	})

	self:tide(tab)

	local configDepBox = tab:AddDependencyBox()

	configDepBox:AddButton("Create New Timing", function()
		local config = self.pair.config

		if not self:check() then
			return
		end

		local timing = self:create()

		config:push(timing)
		SaveManager.markDirty()

		self:refresh()

		self.timingList:SetValue(timing.name)
		self.timingList:Display()
	end)

	configDepBox:AddButton(
		"Duplicate Selected Timing",
		self:tnc(function(found)
			local config = self.pair.config

			if not self:check() then
				return
			end

			local timing = found:clone()

			self:cset(timing)

			config:push(timing)

			self:refresh()

			self.timingList:SetValue(timing.name)
			self.timingList:Display()
		end)
	)

	local internalDepBox = tab:AddDependencyBox()

	internalDepBox:AddButton("Clone To Config", function()
		local name = self.timingList.Value
		if not name then
			return Logger.longNotify("Please select a timing to clone.")
		end

		local internal = self.pair.internal
		local config = self.pair.config

		local found = internal:find(name)
		if not found then
			return Logger.longNotify("The selected timing '%s' does not exist in the list.", name)
		end

		if config.timings[found:id()] then
			return Logger.longNotify("The timing ID '%s' already exists in the config.", found:id())
		end

		if config:find(found.name) then
			return Logger.longNotify("The timing name '%s' already exists in the config.", found.name)
		end

		---@note: No need to refresh after this. It's in the other timing list!
		config:push(internal:clone(found))
		SaveManager.markDirty()
	end)

	tab:AddButton("Remove Selected Timing", function()
		local name = self.timingList.Value
		if not name then
			return Logger.longNotify("Please select a timing to remove.")
		end

		local internal = self.pair.internal
		local config = self.pair.config
		local found = config:find(name)

		---@todo: Implement functionality to remove internal timings.
		if internal:find(name) then
			return Logger.longNotify("You cannot remove internal timings, only override them.")
		end

		if not found then
			return Logger.longNotify("The selected timing '%s' does not exist in the list.", name)
		end

		config:remove(found)
		SaveManager.markDirty()

		self:refresh()
	end)

	configDepBox:SetupDependencies({
		{ self.timingType, "Config" },
	})

	internalDepBox:SetupDependencies({
		{ self.timingType, "Internal" },
	})
end

function BuilderSection:builder()
	local tab = self.tabbox:AddTab(string.format("%s", self.name))

	self.timingTag = tab:AddDropdown(nil, {
		Text = "Timing Tag",
		Values = { "Undefined", "Critical", "Mantra", "M1" },
		Default = 1,
		Callback = self:tnc(function(timing, value)
			timing.tag = value
		end),
	})

	self.initialMinimumDistance = tab:AddSlider(nil, {
		Text = "Initial Minimum Distance",
		Min = 0,
		Max = 300,
		Suffix = "s",
		Default = 0,
		Rounding = 0,
		Callback = self:tnc(function(timing, value)
			timing.imdd = value
		end),
	})

	self.initialMaximumDistance = tab:AddSlider(nil, {
		Text = "Initial Maximum Distance",
		Min = 0,
		Max = 2500,
		Suffix = "s",
		Default = 1000,
		Rounding = 0,
		Callback = self:tnc(function(timing, value)
			timing.imxd = value
		end),
	})

	self.punishableWindow = tab:AddSlider(nil, {
		Text = "Punishable Window",
		Min = 0,
		Max = 2,
		Default = 0.6,
		Suffix = "s",
		Rounding = 1,
		Callback = self:tnc(function(timing, value)
			timing.punishable = value
		end),
	})

	self.afterWindow = tab:AddSlider(nil, {
		Text = "After Window",
		Min = 0,
		Max = 1,
		Default = 0.1,
		Suffix = "s",
		Rounding = 2,
		Callback = self:tnc(function(timing, value)
			timing.after = value
		end),
	})

	self.blockFallbackHoldTime = tab:AddSlider(nil, {
		Text = "Block Fallback Hold Time",
		Min = 0,
		Max = 5,
		Suffix = "s",
		Default = 0.3,
		Rounding = 2,
		Callback = self:tnc(function(timing, value)
			timing.bfht = value
		end),
	})

	self.hitboxShiftOffset = tab:AddSlider(nil, {
		Text = "Hitbox Backwards Offset",
		Min = -50,
		Max = 50,
		Suffix = "s",
		Default = 0,
		Rounding = 0,
		Callback = self:tnc(function(timing, value)
			timing.hso = value
		end),
	})

	self.delayUntilInHitbox = tab:AddToggle(nil, {
		Text = "Delay Until In Hitbox",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.duih = value
		end),
	})

	local duihDepBox = tab:AddDependencyBox()

	self.timingHitboxLength = duihDepBox:AddSlider(nil, {
		Text = "Hitbox Length",
		Min = 0,
		Max = 300,
		Suffix = "s",
		Default = 0,
		Rounding = 0,
		Callback = self:tnc(function(timing, value)
			timing.hitbox = Vector3.new(timing.hitbox.X, timing.hitbox.Y, value)
		end),
	})

	self.timingHitboxWidth = duihDepBox:AddSlider(nil, {
		Text = "Hitbox Width",
		Min = 0,
		Max = 300,
		Suffix = "s",
		Default = 0,
		Rounding = 0,
		Callback = self:tnc(function(timing, value)
			timing.hitbox = Vector3.new(value, timing.hitbox.Y, timing.hitbox.Z)
		end),
	})

	self.timingHitboxHeight = duihDepBox:AddSlider(nil, {
		Text = "Hitbox Height",
		Min = 0,
		Max = 300,
		Suffix = "s",
		Default = 0,
		Rounding = 0,
		Callback = self:tnc(function(timing, value)
			timing.hitbox = Vector3.new(timing.hitbox.X, value, timing.hitbox.Z)
		end),
	})

	duihDepBox:SetupDependencies({
		{ self.delayUntilInHitbox, true },
	})

	self.useModuleOverActions = tab:AddToggle(nil, {
		Text = "Use Module Over Actions",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.umoa = value
		end),
	})

	local umoaDepBox = tab:AddDependencyBox()

	self.skipModuleNotification = umoaDepBox:AddToggle(nil, {
		Text = "Skip Module Notification",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.smn = value
		end),
	})

	self.selectedModule = umoaDepBox:AddInput(nil, {
		Text = "Selected Module",
		Finished = true,
		Callback = self:tnc(function(timing, value)
			timing.smod = value
		end),
	})

	umoaDepBox:SetupDependencies({
		{ self.useModuleOverActions, true },
	})

	self.skipRepeatNotification = tab:AddToggle(nil, {
		Text = "Skip Repeat Notification",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.srpn = value
		end),
	})

	self.hitboxFacingOffset = tab:AddToggle(nil, {
		Text = "Hitbox Facing Offset",
		Default = true,
		Callback = self:tnc(function(timing, value)
			timing.fhb = value
		end),
	})

	self.noDashFallback = tab:AddToggle(nil, {
		Text = "No Dash Fallback",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.ndfb = value
		end),
	})

	self.noVentFallback = tab:AddToggle(nil, {
		Text = "No Vent Fallback",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.nvfb = value
		end),
	})

	self.noBlockFallback = tab:AddToggle(nil, {
		Text = "No Block Fallback",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.nbfb = value
		end),
	})

	self.ignoreBlockInput = tab:AddToggle(nil, {
		Text = "Ignore Block Input Gate",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.ibi = value
		end),
	})

	self.ignoreAutoParryFrames = tab:AddToggle(nil, {
		Text = "Ignore Auto Parry Frames",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.iapf = value
		end),
	})

	self.useInhaleFeint = tab:AddToggle(nil, {
		Text = "Use Inhale To Identify Feint",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.uif = value
		end),
	})

	self.ignoreFeintDetection = tab:AddToggle(nil, {
		Text = "Ignore Feint Detection",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.nfd = value
		end),
	})

	self.skipIfRecentlySelfCast = tab:AddToggle(nil, {
		Text = "Skip If Recently Self-Cast",
		Default = false,
		Callback = self:tnc(function(timing, value)
			timing.rsc = value
		end),
	})

	local rscDepBox = tab:AddDependencyBox()

	self.recentSelfCastAnimationId = rscDepBox:AddInput(nil, {
		Text = "Recent Self-Cast Animation ID",
		Finished = true,
		Callback = self:tnc(function(timing, value)
			timing.rsaid = value
		end),
	})

	self.recentSelfCastWindow = rscDepBox:AddSlider(nil, {
		Text = "Recent Self-Cast Window",
		Min = 0,
		Max = 15,
		Suffix = "s",
		Default = 4,
		Rounding = 1,
		Callback = self:tnc(function(timing, value)
			timing.rsaw = tonumber(value) or 4.0
		end),
	})

	rscDepBox:SetupDependencies({
		{ self.skipIfRecentlySelfCast, true },
	})

	self:extra(tab)
end

function BuilderSection:init()
	self:timing()
	self:builder()
	self:action()
end

---@param name string
---@param tabbox table
---@param pair TimingContainerPair
---@param timing Timing
---@return BuilderSection
function BuilderSection.new(name, tabbox, pair, timing)
	local self = setmetatable({}, BuilderSection)
	self.name = name
	self.tabbox = tabbox
	self.pair = pair
	return self
end

return BuilderSection
