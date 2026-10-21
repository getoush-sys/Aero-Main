local CombatTab = {}

---@module GUI.Icons
local Icons = require("GUI/Icons")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Features.Combat.Defense
local Defense = require("Features/Combat/Defense")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.Environment
local Environment = require("Utility/Environment")

---@module GUI.Library
local Library = require("GUI/Library")

---@module Game.Timings.SaveManager
local SaveManager = require("Game/Timings/SaveManager")

local RhythmSpoofer = require("Features/Combat/RhythmSpoofer")

local ForceAutoRotate = require("Features/Combat/ForceAutoRotate")

local AutoDustlunge = require("Features/Combat/AutoDustlunge")

-- Minimal modal confirm popup (Aero's Library has no dialog primitive): dims the screen, shows a title +
-- message with Confirm / Cancel, and calls back with a boolean. Parented on top of Library.ScreenGui.
local function confirmDialog(titleText, bodyText, onResult)
	local backdrop = Library:Create("Frame", {
		Name = "LumaConfirmDialog",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 999990,
		Active = true,
		Parent = Library.ScreenGui,
	})

	local dialog = Library:Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 160),
		BackgroundColor3 = Library.MainColor,
		BorderColor3 = Library.OutlineColor,
		BorderMode = Enum.BorderMode.Inset,
		ZIndex = 999991,
		Active = true,
		Parent = backdrop,
	})
	Library:AddToRegistry(dialog, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" })

	Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 0, 22),
		Font = Enum.Font.GothamBold,
		Text = titleText,
		TextColor3 = Library.AccentColor,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 999992,
		Parent = dialog,
	})

	Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, 58),
		Font = Enum.Font.Gotham,
		Text = bodyText,
		TextColor3 = Library.FontColor,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 999992,
		Parent = dialog,
	})

	local done = false
	local function finish(result)
		if done then
			return
		end
		done = true
		pcall(function()
			backdrop:Destroy()
		end)
		Library:SafeCallback(onResult, result)
	end

	local function makeButton(text, xScale, isAccent)
		return Library:Create("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(xScale, 0, 1, -14),
			Size = UDim2.fromOffset(150, 32),
			BackgroundColor3 = isAccent and Library.AccentColor or Library.MainColor,
			BorderColor3 = Library.OutlineColor,
			BorderMode = Enum.BorderMode.Inset,
			Font = Enum.Font.Gotham,
			Text = text,
			TextColor3 = Library.FontColor,
			TextSize = 15,
			AutoButtonColor = true,
			ZIndex = 999993,
			Parent = dialog,
		})
	end

	makeButton("Confirm", 0.28, true).MouseButton1Click:Connect(function()
		finish(true)
	end)
	makeButton("Cancel", 0.72, false).MouseButton1Click:Connect(function()
		finish(false)
	end)
end

---@param tab table
function CombatTab.initCombatTargetingSection(tab)
	tab:AddDropdown("PlayerSelectionType", {
		Text = "Player Selection Type",
		Values = {
			"Closest In Distance",
			"Closest To Crosshair",
			"Least Health",
		},
		Default = 1,
	})

	tab:AddSlider("FOVLimit", {
		Text = "Player FOV Limit",
		Min = 0,
		Max = 180,
		Default = 180,
		Suffix = "°",
		Rounding = 0,
	})

	tab:AddSlider("DistanceLimit", {
		Text = "Distance Limit",
		Min = 0,
		Max = 10000,
		Default = 3000,
		Suffix = "s",
		Rounding = 0,
	})

	tab:AddSlider("MaxTargets", {
		Text = "Max Targets",
		Min = 1,
		Max = 64,
		Default = 4,
		Rounding = 0,
	})

	tab:AddToggle("CheckTargetingValue", {
		Text = "Check Mob Targeting Value",
		Default = false,
	})

	tab:AddToggle("IgnorePlayers", {
		Text = "Ignore Players",
		Default = false,
	})

	tab:AddToggle("IgnoreMobs", {
		Text = "Ignore Mobs",
		Default = false,
	})

	tab:AddToggle("IgnoreAllies", {
		Text = "Ignore Allies",
		Default = false,
	})
end

---@param groupbox table
function CombatTab.initCombatWhitelistSection(groupbox)
	groupbox:AddToggle("PlayerListWhitelisting", {
		Text = "Player List Whitelisting",
		Default = false,
	})

	local usernameList = groupbox:AddDropdown("UsernameList", {
		Text = "Username List",
		Values = {},
		SaveValues = true,
		Multi = true,
		AllowNull = true,
	})

	local usernameInput = groupbox:AddInput("UsernameInput", {
		Text = "Username Input",
		Placeholder = "Display name or username.",
	})
	groupbox:AddButton("Add Username To Whitelist", function()
		local username = usernameInput.Value
		if #username <= 0 then
			return Logger.longNotify("Please enter a valid username.")
		end

		local values = usernameList.Values
		if not table.find(values, username) then
			table.insert(values, username)
		end

		usernameList:SetValues(values)
		usernameList:SetValue({})
		usernameList:Display()
	end)

	groupbox:AddButton("Remove Selected Usernames", function()
		local values = usernameList.Values
		local value = usernameList.Value

		for selected, _ in next, value do
			local index = table.find(values, selected)
			if not index then
				continue
			end

			table.remove(values, index)
		end

		usernameList:SetValues(values)
		usernameList:SetValue({})
		usernameList:Display()

	end)
end

---@param groupbox table
---@return table autoDefenseToggle
function CombatTab.initDefenseSection(groupbox)
	local autoDefenseToggle = groupbox:AddToggle("EnableAutoDefense", {
		Text = "Enable Auto Defense",
		Default = false,
	})

	autoDefenseToggle:AddKeyPicker(
		"EnableAutoDefenseKeybind",
		{ Default = "N/A", SyncToggleState = true, Text = "Auto Defense" }
	)

	local autoDefenseDepBox = groupbox:AddDependencyBox()

	autoDefenseDepBox:AddToggle("EnableNotifications", {
		Text = "Enable Notifications",
		Default = false,
	})

	autoDefenseDepBox:AddToggle("EnableVisualizations", {
		Text = "Enable Visualizations",
		Default = false,
		Callback = Defense.visualizations,
	})

	autoDefenseDepBox:AddToggle("RollOnParryCooldown", {
		Text = "Roll On Parry Cooldown",
		Default = true,
	})

	autoDefenseDepBox:AddToggle("RollIfBehind", {
		Text = "Roll If Attack Is Behind",
		Default = false,
	})

	autoDefenseDepBox:AddToggle("VentFallback", {
		Text = "Vent Fallback",
		Default = false,
	})

	autoDefenseDepBox:AddToggle("DeflectBlockFallback", {
		Text = "Deflect Block Fallback",
		Default = false,
	})

	autoDefenseDepBox:AddToggle("UseIFrames", {
		Text = "Use Invincibility Frames",
		Default = false,
	})

	autoDefenseDepBox:AddToggle("ParryOnly", {
		Text = "Parry Dodgeables",
		Default = false,
	})

	local predictionToggle = autoDefenseDepBox:AddToggle("UsePrediction", {
		Text = "Use Prediction",
		Default = false,
	})
	local predictionDepBox = autoDefenseDepBox:AddDependencyBox()
	predictionDepBox:AddSlider("PredictionLeadTime", {
		Text = "Prediction Lead Time",
		Default = 0.2,
		Min = 0,
		Max = 2,
		Suffix = "s",
		Rounding = 2,
	})
	predictionDepBox:SetupDependencies({ { predictionToggle, true } })

	local punishmentToggle = autoDefenseDepBox:AddToggle("UsePunishment", {
		Text = "Use Punishment",
		Default = false,
	})
	local punishmentDepBox = autoDefenseDepBox:AddDependencyBox()
	punishmentDepBox:AddSlider("PunishmentLeadTime", {
		Text = "Punishment Lead Time",
		Default = 0.3,
		Min = 0,
		Max = 2,
		Suffix = "s",
		Rounding = 2,
	})
	punishmentDepBox:SetupDependencies({ { punishmentToggle, true } })

	local equalizerToggle = autoDefenseDepBox:AddToggle("UseEqualizer", {
		Text = "Use Equalizer",
		Default = false,
	})
	local equalizerDepBox = autoDefenseDepBox:AddDependencyBox()
	equalizerDepBox:AddSlider("EqualizerLeadTime", {
		Text = "Equalizer Lead Time",
		Default = 0.5,
		Min = 0,
		Max = 2,
		Suffix = "s",
		Rounding = 2,
	})
	equalizerDepBox:SetupDependencies({ { equalizerToggle, true } })

	local unbiddenToggle = autoDefenseDepBox:AddToggle("UseUnbidden", {
		Text = "Use Unbidden",
		Default = false,
	})
	local unbiddenDepBox = autoDefenseDepBox:AddDependencyBox()
	unbiddenDepBox:AddSlider("UnbiddenLeadTime", {
		Text = "Unbidden Lead Time",
		Default = 0.2,
		Min = 0,
		Max = 2,
		Suffix = "s",
		Rounding = 2,
	})
	unbiddenDepBox:SetupDependencies({ { unbiddenToggle, true } })

	local illusoryCounterToggle = autoDefenseDepBox:AddToggle("UseIllusoryCounter", {
		Text = "Use Illusory Counter",
		Default = false,
	})
	local illusoryCounterDepBox = autoDefenseDepBox:AddDependencyBox()
	illusoryCounterDepBox:AddSlider("IllusoryCounterLeadTime", {
		Text = "Illusory Counter Lead Time",
		Default = 0.2,
		Min = 0,
		Max = 2,
		Suffix = "s",
		Rounding = 2,
	})
	illusoryCounterDepBox:SetupDependencies({ { illusoryCounterToggle, true } })

	autoDefenseDepBox:AddToggle("CounterNPCs", {
		Text = "Counter NPCs",
		Default = false,
	})

	local blatantRollToggle = autoDefenseDepBox:AddToggle("BlatantRoll", {
		Text = "Blatant Roll",
		Default = false,
	})

	local rollCancelTgDepBox = autoDefenseDepBox:AddDependencyBox()

	local rollCancelToggle = autoDefenseDepBox:AddToggle("RollCancel", {
		Text = "Roll Cancel",
		Default = false,
	})

	local rollCancelDepBox = autoDefenseDepBox:AddDependencyBox()

	rollCancelDepBox:AddSlider("RollCancelDelay", {
		Text = "Roll Cancel Delay",
		Default = 0.05,
		Min = 0,
		Max = 2,
		Suffix = "s",
		Rounding = 2,
	})

	rollCancelDepBox:SetupDependencies({
		{ rollCancelToggle, true },
	})

	rollCancelTgDepBox:SetupDependencies({
		{ blatantRollToggle, true },
	})

	local blockInputToggle = autoDefenseDepBox:AddToggle("BlockInput", {
		Text = "Block Input",
		Default = true,
	})

	local blockInputDepBox = autoDefenseDepBox:AddDependencyBox()

	blockInputDepBox:AddDropdown("BlockInputAllowedTargets", {
		Text = "Block Input Targets",
		Values = {
			"PVE",
			"PVP",
		},
		Multi = true,
		AllowNull = true,
		Default = {
			"PVE",
			"PVP",
		},
	})
	blockInputDepBox:AddDropdown("BlockedSafeInputUserMoves", {
		Text = "Blocked User Inputs",
		Values = {
			"M1s",
			"Criticals",
			"Mantras",
		},
		Multi = true,
		AllowNull = true,
		Default = {
			"M1s",
			"Criticals",
			"Mantras",
		},
	})

	blockInputDepBox:AddDropdown("BlockInputRangeCheck", {
		Text = "Block Input Range Check",
		Values = {
			"Initial Max Distance",
			"Inside Hitbox",
		},
		Default = 1,
		Tooltip = "Block input when the threat is within the timing's initial max distance, or only when we're inside its hitbox.",
	})

	blockInputDepBox:AddSlider("BlockInputCriticalPunishmentTime", {
		Text = "Critical Punishment Time",
		Min = 1,
		Max = 1000,
		Default = 700,
		Suffix = "ms",
		Rounding = 0,
	})

	blockInputDepBox:AddSlider("BlockInputM1PunishmentTime", {
		Text = "M1 Punishment Time",
		Min = 1,
		Max = 1000,
		Default = 500,
		Suffix = "ms",
		Rounding = 0,
	})

	local blockInputTargetingToggle = blockInputDepBox:AddToggle("BlockInputTargeting", {
		Text = "Use Targeting",
		Default = false,
	})

	local blockInputTargetingDepBox = blockInputDepBox:AddDependencyBox()

	blockInputTargetingDepBox:AddDropdown("BlockInputSelectionType", {
		Text = "Selection Type",
		Values = {
			"Closest In Distance",
			"Closest To Crosshair",
			"Least Health",
		},
		Default = 1,
	})

	blockInputTargetingDepBox:AddSlider("BlockInputFOVLimit", {
		Text = "FOV Limit",
		Min = 0,
		Max = 180,
		Default = 180,
		Suffix = "°",
		Rounding = 0,
	})

	blockInputTargetingDepBox:AddSlider("BlockInputDistanceLimit", {
		Text = "Distance Limit",
		Min = 0,
		Max = 10000,
		Default = 3000,
		Suffix = "s",
		Rounding = 0,
	})

	blockInputTargetingDepBox:AddSlider("BlockInputMaxTargets", {
		Text = "Max Targets",
		Min = 1,
		Max = 64,
		Default = 4,
		Rounding = 0,
	})

	blockInputTargetingDepBox:SetupDependencies({
		{ blockInputTargetingToggle, true },
	})

	blockInputDepBox:SetupDependencies({
		{ blockInputToggle, true },
	})

	local dodgeBehindBackToggle = autoDefenseDepBox:AddToggle("DodgeBehindBack", {
		Text = "Dodge Behind Back",
		Default = false,
	})

	local dodgeBehindBackDepBox = autoDefenseDepBox:AddDependencyBox()

	dodgeBehindBackDepBox:AddSlider("DodgeBehindBackProbability", {
		Text = "Dodge Behind Back Probability",
		Default = 0,
		Min = 0,
		Max = 100,
		Suffix = "%",
		Rounding = 0,
	})

	dodgeBehindBackDepBox:SetupDependencies({
		{ dodgeBehindBackToggle, true },
	})

	autoDefenseDepBox:SetupDependencies({
		{ autoDefenseToggle, true },
	})

	return autoDefenseToggle
end

---@param groupbox table
---@param autoDefenseToggle table
function CombatTab.initHumanizationSection(groupbox, autoDefenseToggle)
	local humanDepBox = groupbox:AddDependencyBox()

	local enableSimulationToggle = humanDepBox:AddToggle("EnableSimulation", {
		Text = "Enable Input Simulation",
		Default = false,
	})

	local simulationDepBox = humanDepBox:AddDependencyBox()

	simulationDepBox:AddSlider("SimulationHoldMinimum", {
		Text = "Simulation Hold Minimum",
		Default = 0.1,
		Min = 0.02,
		Max = 0.5,
		Suffix = "s",
		Rounding = 2,
	})

	simulationDepBox:AddSlider("SimulationHoldMaximum", {
		Text = "Simulation Hold Maximum",
		Default = 0.15,
		Min = 0.02,
		Max = 0.5,
		Suffix = "s",
		Rounding = 2,
	})

	simulationDepBox:SetupDependencies({
		{ enableSimulationToggle, true },
	})

	humanDepBox:AddDropdown("AutoDefenseFilters", {
		Text = "Auto Defense Filters",
		Values = {
			"Filter Out M1s",
			"Filter Out Mantras",
			"Filter Out Criticals",
			"Filter Out Undefined",
			"Disable When Textbox Focused",
			"Disable When Window Not Active",
			"Disable While Holding Block",
			"Disable While Using Sightless Beam",
			"Disable During Chime Countdown",
			"Dont Parry If In Payback",
		},
		Multi = true,
		AllowNull = true,
		Default = {},
	})

	humanDepBox:SetupDependencies({
		{ autoDefenseToggle, true },
	})

	local afToggle = groupbox:AddToggle("AllowFailure", {
		Text = "Allow Failure",
		Default = false,
	})

	local afDepBox = groupbox:AddDependencyBox()

	afDepBox:AddSlider("FailureRate", {
		Text = "Failure Rate",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%",
		Rounding = 2,
	})

	afDepBox:AddSlider("DashInsteadOfParryRate", {
		Text = "Dash Instead Of Parry Rate",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%",
		Rounding = 2,
	})

	afDepBox:AddSlider("IgnoreAnimationEndRate", {
		Text = "Ignore Animation End Rate",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%",
		Rounding = 2,
	})

	afDepBox:AddSlider("ReactToFeintsRate", {
		Text = "React To Feints Rate",
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = "%",
		Rounding = 2,
	})

	afDepBox:SetupDependencies({
		{ afToggle, true },
	})
end

---@param detectionBox table
---@param thresholdsBox table
function CombatTab.initAntiBreakerSection(detectionBox, thresholdsBox)
	local toggle = detectionBox:AddToggle("AntiBreakerEnabled", {
		Text = "Anti-AP Breaker",
		Default = false,
	})

	toggle:AddKeyPicker(
		"AntiBreakerKeybind",
		{ Default = "N/A", SyncToggleState = true, Text = "Anti-AP Breaker" }
	)

	-- Confirm before enabling: Anti-AP Breaker degrades your AP, so require explicit acceptance. We snap
	-- the toggle back off immediately and only re-enable it if the user picks Confirm.
	local programmatic = false
	local dialogOpen = false
	toggle:OnChanged(function(state)
		if programmatic or not state then
			return
		end
		programmatic = true
		toggle:SetValue(false)
		programmatic = false
		if dialogOpen then
			return
		end
		dialogOpen = true
		confirmDialog("Anti-AP Breaker", "THIS WILL MAKE AP SIGNIFICANTLY WORSE", function(confirmed)
			dialogOpen = false
			if confirmed then
				programmatic = true
				toggle:SetValue(true)
				programmatic = false
			end
		end)
	end)

	-- Notifies you when a nearby player is flagged as trying to AP-break you (ported from Mira).
	detectionBox:AddToggle("AntiBreakerNotify", {
		Text = "Ap Break Notifications",
		Default = false,
	})
end

---@param callback function
---@return function
local function timingOverrideCallback(callback)
	return function()
		local overrideData = Library.OverrideData
		if not overrideData then
			return false
		end

		local selectedTo = Configuration.expectOptionValue("TimingOverrideList")
		if not selectedTo or #selectedTo == 0 then
			return false
		end

		local override = overrideData[selectedTo]
		if not override then
			return false
		end

		callback(override)
	end
end

local function refreshTimingOverrideList()
	local overrideData = Library.OverrideData
	if not overrideData then
		return
	end

	local timingList = Options["TimingOverrideList"]
	if not timingList then
		return
	end

	local values = {}

	for rname, _ in next, overrideData do
		values[#values + 1] = rname
	end

	timingList:SetValues(values)
end

---@param groupbox table
function CombatTab:initTimingsSection(groupbox)
	self.tol = groupbox:AddDropdown("TimingOverrideList", {
		Text = "Timing Override List",
		Values = {},
		SaveValues = false,
		Multi = false,
		AllowNull = true,
		Searchable = true,
		Callback = function()
			self.dashInsteadOfParryRate:SetRawValue(0)
			self.failureRate:SetRawValue(0)
			self.ignoreAnimationEndRate:SetRawValue(0)
			self.reactToFeintsRate:SetRawValue(0)

			local overrideData = Library.OverrideData
			if not overrideData then
				return false
			end

			local selectedTo = Configuration.expectOptionValue("TimingOverrideList")
			if not selectedTo or #selectedTo == 0 then
				return false
			end

			local override = overrideData[selectedTo]
			if not override then
				return false
			end

			self.dashInsteadOfParryRate:SetRawValue(override.dipr or 0)
			self.failureRate:SetRawValue(override.fr or 0)
			self.ignoreAnimationEndRate:SetRawValue(override.iaer or 0)
			self.reactToFeintsRate:SetRawValue(override.rtfr or 0)
		end,
	})

	groupbox:AddDivider()

	local names = {}
	local plist = { SaveManager.as, SaveManager.es, SaveManager.ss, SaveManager.ps }

	---@todo: There should be a specific method for this; I mean as far as I'm aware THERE IS ONE. But, I'm too lazy.
	for _, pair in next, plist do
		for _, timing in next, pair:list() do
			names[#names + 1] = timing.name
		end
	end

	table.sort(names)

	self.ti = groupbox:AddDropdown("TimingOverrideTimingList", {
		Text = "Timing List",
		Values = names,
		Multi = false,
		AllowNull = true,
		Searchable = true,
	})

	groupbox:AddButton("Add Timing Override", function()
		if Library.OverrideData[self.ti.Value] then
			return Logger.notify("A timing override with that name already exists.")
		end

		local override = {
			fr = self.failureRate.Value,
			dipr = self.dashInsteadOfParryRate.Value,
			iaer = self.ignoreAnimationEndRate.Value,
			rtfr = self.reactToFeintsRate.Value,
		}

		Library.OverrideData[self.ti.Value] = override

		refreshTimingOverrideList()

		self.tol:SetValue(self.ti.Value)
		self.tol:Display()
	end)

	groupbox:AddButton("Remove Selected Override", function()
		Library.OverrideData[self.tol.Value] = nil

		refreshTimingOverrideList()

		self.tol:SetValue(nil)
		self.tol:Display()
	end)

	refreshTimingOverrideList()
end

---@param groupbox table
function CombatTab:initProbabilitiesSection(groupbox)
	self.failureRate = groupbox:AddSlider("TP_FailureRate", {
		Text = "Failure Rate",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%",
		Rounding = 2,
		Callback = timingOverrideCallback(function(override)
			override.fr = self.failureRate.Value
		end),
	})

	self.dashInsteadOfParryRate = groupbox:AddSlider("TP_DashInsteadOfParryRate", {
		Text = "Dash Instead Of Parry Rate",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%",
		Rounding = 2,
		Callback = timingOverrideCallback(function(override)
			override.dipr = self.dashInsteadOfParryRate.Value
		end),
	})

	self.ignoreAnimationEndRate = groupbox:AddSlider("TP_IgnoreAnimationEndRate", {
		Text = "Ignore Animation End Rate",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%",
		Rounding = 2,
		Callback = timingOverrideCallback(function(override)
			override.iaer = self.ignoreAnimationEndRate.Value
		end),
	})

	self.reactToFeintsRate = groupbox:AddSlider("TP_ReactToFeintsRate", {
		Text = "React To Feints Rate",
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = "%",
		Rounding = 2,
		Callback = timingOverrideCallback(function(override)
			override.rtfr = self.reactToFeintsRate.Value
		end),
	})
end

---@param groupbox table
function CombatTab.initAttackAssistanceSection(groupbox)
	local afToggle = groupbox:AddToggle("AutoFeint", {
		Text = "Auto Feint",
		Default = true,
	})

	local afDepBox = groupbox:AddDependencyBox()

	afDepBox:AddDropdown("AutoFeintOwnTags", {
		Text = "Auto Feint Our Move Types",
		Values = {
			"M1s",
			"Mantras",
		},
		Multi = true,
		AllowNull = true,
		Default = {
			"M1s",
			"Mantras",
		},
	})

	afDepBox:AddDropdown("AutoFeintAgainstTags", {
		Text = "Auto Feint Against Move Types",
		Values = {
			"M1s",
			"Mantras",
			"Criticals",
		},
		Multi = true,
		AllowNull = true,
		Default = {
			"M1s",
			"Mantras",
			"Criticals",
		},
	})

	afDepBox:SetupDependencies({
		{ afToggle, true },
	})

	-- ---- Auto Mixup ----
	local autoMixupToggle = groupbox:AddToggle("AutoMixup", {
		Text = "Auto Mixup",
		Default = false,
	})

	local autoMixupDepBox = groupbox:AddDependencyBox()

	autoMixupDepBox:AddSlider("AutoMixupFeintProbability", {
		Text = "Feint Probability",
		Default = 0,
		Min = 0,
		Max = 100,
		Suffix = "%",
		Rounding = 0,
	})

	autoMixupDepBox:AddSlider("AutoMixupFeintIntoMantraProbability", {
		Text = "Greycast Probability",
		Default = 0,
		Min = 0,
		Max = 100,
		Suffix = "%",
		Rounding = 0,
	})

	autoMixupDepBox:AddSlider("AutoMixupFeintIntoMantraDelay", {
		Text = "Greycast Delay",
		Default = 0.08,
		Min = 0,
		Max = 0.5,
		Suffix = "s",
		Rounding = 3,
	})

	local autoMixupMantras = autoMixupDepBox:AddDropdown("AutoMixupMantras", {
		Text = "Mantras",
		Values = {},
		Default = {},
		Multi = true,
		AllowNull = true,
		SaveValues = true,
	})

	autoMixupDepBox:AddButton("Load Mantras", function()
		local player = game:GetService("Players").LocalPlayer
		if not player then
			return
		end

		local backpack = player:FindFirstChild("Backpack")
		if not backpack then
			return
		end

		local mantras = {}
		for _, mantra in pairs(backpack:GetChildren()) do
			if mantra:IsA("Tool") and mantra.Name:find("Mantra:") and not mantra.Name:find("RecalledMantra:") then
				local defaultName = mantra:GetAttribute("DefaultName")
				if defaultName and not table.find(mantras, defaultName) then
					table.insert(mantras, defaultName)
				end
			end
		end

		autoMixupMantras:SetValues(mantras)
		autoMixupMantras:SetValue({})
		autoMixupMantras:Display()
	end)

	autoMixupDepBox:AddSlider("AutoMixupRollBehindProbability", {
		Text = "Roll Cancel Behind Back Probability",
		Default = 0,
		Min = 0,
		Max = 100,
		Suffix = "%",
		Rounding = 0,
	})

	autoMixupDepBox:AddSlider("AutoMixupRollBehindLockOnIntensity", {
		Text = "Lock On Intensity",
		Default = 50,
		Min = 0,
		Max = 100,
		Suffix = "%",
		Rounding = 0,
	})

	autoMixupDepBox:AddToggle("AutoMixupRollBehindPlayersOnly", {
		Text = "Roll Behind Players Only",
		Default = false,
	})

	autoMixupDepBox:SetupDependencies({
		{ autoMixupToggle, true },
	})
end

---@param groupbox table
function CombatTab.initCombatAssistance(groupbox)
	local awToggle = groupbox:AddToggle("AutoWisp", {
		Text = "Auto Wisp",
		Default = false,
	})

	local awDepBox = groupbox:AddDependencyBox()

	awDepBox:AddSlider("AutoWispDelay", {
		Text = "Auto Wisp Delay",
		Default = 0.4,
		Min = 0,
		Max = 1,
		Suffix = "s",
		Rounding = 2,
	})

	awDepBox:SetupDependencies({
		{ awToggle, true },
	})

	local agtToggle = groupbox:AddToggle("AutoGoldenTongue", {
		Text = "Auto Golden Tongue",
		Default = false,
	})

	local agtDepBox = groupbox:AddDependencyBox()

	agtDepBox:AddToggle("CheckIfInCombat", {
		Text = "Check If In Combat",
		Default = false,
	})

	agtDepBox:SetupDependencies({
		{ agtToggle, true },
	})

	local amfToggle = groupbox:AddToggle("AutoMantraFollowup", {
		Text = "Auto Mantra Followup",
		Default = false,
	})

	local amfDepBox = groupbox:AddDependencyBox()

	amfDepBox:AddToggle("CheckIfMoveHit", {
		Text = "Check If Move Hit",
		Default = false,
	})

	amfDepBox:SetupDependencies({
		{ amfToggle, true },
	})

	groupbox:AddToggle("AutoArdour", {
		Text = "Auto Ardour",
		Default = false,
	})

	groupbox:AddToggle("AutoFlowState", {
		Text = "Auto Flow State",
		Default = false,
	})

	groupbox:AddToggle("DelayedFeints", {
		Text = "Delayed Feints",
		Default = false,
	})

	groupbox:AddToggle("RhythmSpoofer", {
		Text = "Rhythm Spoofer",
		Default = false,
	})

	Toggles.RhythmSpoofer:OnChanged(function(state)
		if state then
			RhythmSpoofer.init()
		else
			RhythmSpoofer.detach()
		end
	end)

	local ascToggle = groupbox:AddToggle("AnimationSpeedChanger", {
		Text = "Animation Speed Changer",
		Default = false,
	})

	local ascDepBox = groupbox:AddDependencyBox()

	ascDepBox:AddToggle("LimitToAPAnimations", {
		Text = "Limit To AP Animations",
		Default = false,
	})

	ascDepBox:AddToggle("SwitchBetweenSpeeds", {
		Text = "Switch Between Speeds",
		Default = false,
	})

	ascDepBox:AddSlider("AnimationSpeedMinimum", {
		Text = "Animation Speed Minimum",
		Default = 1.0,
		Min = 0.1,
		Max = 5,
		Suffix = "x",
		Rounding = 2,
	})

	ascDepBox:AddSlider("AnimationSpeedMaximum", {
		Text = "Animation Speed Maximum",
		Default = 1.25,
		Min = 0.1,
		Max = 5,
		Suffix = "x",
		Rounding = 2,
	})

	ascDepBox:SetupDependencies({
		{ ascToggle, true },
	})

	local arToggle = groupbox:AddToggle("ActionRolling", {
		Text = "Action Rolling",
		Default = false,
	})

	arToggle:AddKeyPicker("ActionRollingKeybind", { Default = "N/A", SyncToggleState = true, Text = "Action Rolling Keybind" })

	local arDepBox = groupbox:AddDependencyBox()

	arDepBox:AddDropdown("ActionRollingActions", {
		Text = "Action Rolling Actions",
		Values = {
			"Roll On M1",
			"Roll On Critical",
			"Roll On Cast",
			"Roll On Parry",
		},
		Multi = true,
		AllowNull = true,
		Default = {},
	})

	arDepBox:AddSlider("ActionRollCancelDelay", {
		Text = "Action Roll Cancel Delay",
		Default = 0.1,
		Min = 0,
		Max = 2,
		Suffix = "s",
		Rounding = 2,
	})

	arDepBox:AddSlider("ActionRollCooldown", {
		Text = "Action Roll Cooldown",
		Default = 2,
		Min = 0,
		Max = 5,
		Suffix = "s",
		Rounding = 2,
	})

	arDepBox:SetupDependencies({
		{ arToggle, true },
	})

	groupbox:AddToggle("M1Hold", {
		Text = "M1 Hold",
		Default = false,
	})

	groupbox:AddToggle("AutoRagdollRecover", {
		Text = "Auto Ragdoll Recover",
		Default = false,
	})

	groupbox:AddToggle("ForceAutoRotate", {
		Text = "Force Auto Rotate",
		Default = false,
	})

	Toggles.ForceAutoRotate:OnChanged(function(state)
		if state then
			ForceAutoRotate.init()
		else
			ForceAutoRotate.detach()
		end
	end)

	groupbox:AddToggle("FeintFlourish", {
		Text = "Feint Flourish",
		Default = false,
	})

	local backstabMovestackToggle = groupbox:AddToggle("BackstabMovestack", {
		Text = "Backstab Movestacker",
		Default = false,
	})

	local backstabMovestackDepBox = groupbox:AddDependencyBox()

	local backstabMovestackMantras = backstabMovestackDepBox:AddDropdown("BackstabMovestackMantras", {
		Text = "Trigger Mantras",
		Values = {},
		Default = {},
		Multi = true,
		AllowNull = true,
		SaveValues = true,
	})

	backstabMovestackDepBox:AddButton("Load Mantras", function()
		local player = game:GetService("Players").LocalPlayer
		if not player then
			return
		end

		local backpack = player:FindFirstChild("Backpack")
		if not backpack then
			return
		end

		local mantras = {}
		for _, mantra in pairs(backpack:GetChildren()) do
			if mantra:IsA("Tool") and mantra.Name:find("Mantra:") and not mantra.Name:find("RecalledMantra:") then
				local defaultName = mantra:GetAttribute("DefaultName")
				if defaultName and not table.find(mantras, defaultName) then
					table.insert(mantras, defaultName)
				end
			end
		end

		backstabMovestackMantras:SetValues(mantras)
		backstabMovestackMantras:SetValue({})
		backstabMovestackMantras:Display()
	end)

	backstabMovestackDepBox:AddSlider("BackstabMovestackDelay", {
		Text = "Trigger Delay",
		Default = 0.05,
		Min = 0,
		Max = 0.3,
		Suffix = "s",
		Rounding = 3,
	})

	backstabMovestackDepBox:SetupDependencies({
		{ backstabMovestackToggle, true },
	})

	local rollCastMantrasToggle = groupbox:AddToggle("RollCastMantras", {
		Text = "Roll Cast Mantras",
		Default = false,
	})

	local rollCastMantrasDepBox = groupbox:AddDependencyBox()

	local rollCastMantrasList = rollCastMantrasDepBox:AddDropdown("RollCastMantrasList", {
		Text = "Trigger Mantras",
		Values = {},
		Default = {},
		Multi = true,
		AllowNull = true,
		SaveValues = true,
	})

	rollCastMantrasDepBox:AddButton("Load Rollcast Mantras", function()
		local player = game:GetService("Players").LocalPlayer
		if not player then
			return
		end

		local backpack = player:FindFirstChild("Backpack")
		if not backpack then
			return
		end

		local mantras = {}
		for _, mantra in pairs(backpack:GetChildren()) do
			if mantra:IsA("Tool") and mantra.Name:find("Mantra:") and not mantra.Name:find("RecalledMantra:") then
				local defaultName = mantra:GetAttribute("DefaultName")
				if defaultName and not table.find(mantras, defaultName) then
					table.insert(mantras, defaultName)
				end
			end
		end

		rollCastMantrasList:SetValues(mantras)
		rollCastMantrasList:SetValue({})
		rollCastMantrasList:Display()
	end)

	rollCastMantrasDepBox:SetupDependencies({
		{ rollCastMantrasToggle, true },
	})

	local slideCastMantrasToggle = groupbox:AddToggle("SlideCastMantras", {
		Text = "Slide Cast Mantras",
		Default = false,
	})

	local slideCastMantrasDepBox = groupbox:AddDependencyBox()

	local slideCastMantrasList = slideCastMantrasDepBox:AddDropdown("SlideCastMantrasList", {
		Text = "Trigger Mantras",
		Values = {},
		Default = {},
		Multi = true,
		AllowNull = true,
		SaveValues = true,
	})

	slideCastMantrasDepBox:AddButton("Load Slidecast Mantras", function()
		local player = game:GetService("Players").LocalPlayer
		if not player then
			return
		end

		local backpack = player:FindFirstChild("Backpack")
		if not backpack then
			return
		end

		local mantras = {}
		for _, mantra in pairs(backpack:GetChildren()) do
			if mantra:IsA("Tool") and mantra.Name:find("Mantra:") and not mantra.Name:find("RecalledMantra:") then
				local defaultName = mantra:GetAttribute("DefaultName")
				if defaultName and not table.find(mantras, defaultName) then
					table.insert(mantras, defaultName)
				end
			end
		end

		slideCastMantrasList:SetValues(mantras)
		slideCastMantrasList:SetValue({})
		slideCastMantrasList:Display()
	end)

	slideCastMantrasDepBox:SetupDependencies({
		{ slideCastMantrasToggle, true },
	})

	local autoAirCounterToggle = groupbox:AddToggle("AutoAirCounter", {
		Text = "Auto Air Counter",
		Default = false,
	})

	autoAirCounterToggle:AddKeyPicker("AutoAirCounterKeybind", { Default = "N/A", SyncToggleState = true, Text = "Auto Air Counter" })

	local autoAirCounterDepBox = groupbox:AddDependencyBox()

	autoAirCounterDepBox:AddToggle("AutoAirCounterAllyCheck", {
		Text = "Ally Check",
		Default = false,
	})

	autoAirCounterDepBox:AddToggle("AutoAirCounterOnGround", {
		Text = "Air Counter On Ground",
		Default = false,
	})

	autoAirCounterDepBox:AddSlider("AutoAirCounterRange", {
		Text = "Air Counter Range",
		Default = 60,
		Min = 1,
		Max = 100,
		Suffix = " studs",
		Rounding = 0,
	})

	autoAirCounterDepBox:SetupDependencies({
		{ autoAirCounterToggle, true },
	})

	local autoDustlungeToggle = groupbox:AddToggle("AutoDustlunge", {
		Text = "Auto Assassination",
		Default = false,
	})

	autoDustlungeToggle:AddKeyPicker("AutoDustlungeKeybind", {
		Default = "N/A",
		SyncToggleState = true,
		Text = "Auto Assassination",
	})

	autoDustlungeToggle:AddKeyPicker("AutoDustlungeHoldBind", {
		Default = "V",
		Mode = "Hold",
		Modes = { "Hold" },
		Text = "Auto Assassination Bind (hold)",
	})

	AutoDustlunge.setHoldKeyPicker(Options.AutoDustlungeHoldBind)

	autoDustlungeToggle:OnChanged(function(state)
		if state then
			AutoDustlunge.enable()
		else
			AutoDustlunge.disable()
		end
	end)

	local autoDustlungeDepBox = groupbox:AddDependencyBox()

	autoDustlungeDepBox:AddToggle("AutoDustlungeDebug", {
		Text = "Show Hitbox",
		Default = false,
	})

	autoDustlungeDepBox:SetupDependencies({
		{ autoDustlungeToggle, true },
	})
end

---@param groupbox table
function CombatTab.initDebuggingSection(groupbox)
	groupbox:AddToggle("BlockParryState", {
		Text = "Block Parry State",
		Default = false,
	})

	groupbox:AddToggle("BlockDodgeState", {
		Text = "Block Dodge State",
		Default = false,
	})

	groupbox:AddToggle("BlockVentState", {
		Text = "Block Vent State",
		Default = false,
	})

	groupbox:AddToggle("NoBlockingState", {
		Text = "No Blocking State",
		Default = false,
	})
end

---@param groupbox table
function CombatTab.initApBreakerSection(groupbox)
	local ExpApBreaker = require("Features/Combat/ExpApBreaker")

	local apBreakerToggle = groupbox:AddToggle("ExpApBreaker", {
		Text = "AP Breaker",
		Default = false,
	})

	apBreakerToggle:AddKeyPicker("APBreakerKeybind", { Default = "N/A", SyncToggleState = true, Text = "AP Breaker" })

	apBreakerToggle:OnChanged(function(state)
		if not ExpApBreaker then
			return
		end
		if state then
			ExpApBreaker:Start()
		else
			ExpApBreaker:Stop()
		end
	end)

	local apbDepBox = groupbox:AddDependencyBox()

	apbDepBox:AddDropdown("ExpApBreakerModes", {
		Text = "Breakers",
		Values = {
			"Priority Mask",
			"Fade Time Flood",
			"Monster Flood",
			"Mutate",
		},
		Default = {},
		Multi = true,
		AllowNull = true,
		Callback = function()
			if ExpApBreaker then
				ExpApBreaker.refresh()
			end
		end,
	})

	apbDepBox:AddSlider("ExpApBreakerAggressive2Intensity", {
		Text = "Flood Intensity",
		Default = 200,
		Min = 1,
		Max = 200,
		Rounding = 0,
	})

	apbDepBox:AddToggle("ExpApBreakerMaskVisual", {
		Text = "Mask Visual",
		Default = true,
	})

	apbDepBox:AddToggle("ApBreakerDontHitAnimLimit", {
		Text = "Don't hit animation limit",
		Default = true,
	})

	apbDepBox:SetupDependencies({
		{ apBreakerToggle, true },
	})

	-- Blatant Flood: standalone, independent of the AP Breaker toggle above. Floods every known
	-- timing and blanks your real attack animation ids to nothing so the enemy can't parry them.
	local blatantFlood = groupbox:AddToggle("BlatantFlood", {
		Text = "Blatant Flood",
		Default = false,
	})

	blatantFlood:AddKeyPicker(
		"BlatantFloodKeybind",
		{ Default = "N/A", SyncToggleState = true, Text = "Blatant Flood" }
	)

	blatantFlood:OnChanged(function(state)
		if not ExpApBreaker then
			return
		end
		if state then
			ExpApBreaker:StartBlatantFlood()
		else
			ExpApBreaker:StopBlatantFlood()
		end
	end)

	local blatantFloodBox = groupbox:AddDependencyBox()

	-- Flood rate (plays/sec). Higher = harder to read but each play replicates to the server, so
	-- pushing this too high spikes YOUR OWN ping. 40-80 buries the real swing without flooding.
	blatantFloodBox:AddSlider("BlatantFloodRate", {
		Text = "Blatant Flood Rate",
		Default = 60,
		Min = 1,
		Max = 300,
		Rounding = 0,
		Suffix = "/s",
	})

	blatantFloodBox:SetupDependencies({
		{ blatantFlood, true },
	})
end
---@param tab table
function CombatTab.initSilentAimSection(tab)
	local SilentAim = require("Features/Combat/SilentAim")

	local toggle = tab:AddToggle("SilentAim", {
		Text = "Silent Aim",
		Default = false,
		Tooltip = "Redirects your server-side aim (GetCameraToMouse + UpdateMouse) onto the target under your FOV.",
	})

	toggle:AddKeyPicker("SilentAimKeybind", { Default = "N/A", SyncToggleState = true, Text = "Silent Aim" })

	toggle:OnChanged(function(state)
		if state then
			SilentAim.enable()
		else
			SilentAim.disable()
		end
	end)

	tab:AddDropdown("SilentAimTargets", {
		Text = "Allowed Targets",
		Values = { "Players", "Mobs", "Guildmates" },
		Multi = true,
		AllowNull = true,
		Default = { "Players" },
	})

	tab:AddSlider("SilentAimFOV", {
		Text = "FOV",
		Min = 1,
		Max = 2000,
		Default = 90,
		Suffix = "px",
		Rounding = 0,
	})

	tab:AddSlider("SilentAimPrediction", {
		Text = "Prediction",
		Min = 0,
		Max = 200,
		Default = 15,
		Suffix = "%",
		Rounding = 0,
	})

	tab:AddToggle("SilentAimShowFOV", {
		Text = "Show FOV",
		Default = false,
	})

	tab:AddToggle("SilentAimFillFOV", {
		Text = "Fill FOV",
		Default = false,
	})

	tab:AddSlider("SilentAimFOVTransparency", {
		Text = "FOV Transparency",
		Min = 0,
		Max = 1,
		Default = 0.3,
		Rounding = 2,
	})
end

---@param window table
function CombatTab.init(window)
	local tab = window:AddTab("Combat", "Combat", Icons.Combat)

	local tabbox = tab:AddFullTabbox()

	local defenseTab = tabbox:AddTab("Defense")
	local autoDefenseToggle = CombatTab.initDefenseSection(defenseTab)
	CombatTab.initHumanizationSection(defenseTab, autoDefenseToggle)

	local targetingTab = tabbox:AddTab("Targeting")
	CombatTab.initCombatTargetingSection(targetingTab)
	CombatTab.initCombatWhitelistSection(targetingTab)

	local assistTab = tabbox:AddTab("Assist")
	CombatTab.initAttackAssistanceSection(assistTab)
	CombatTab.initCombatAssistance(assistTab)
	CombatTab.initSilentAimSection(assistTab)
	assistTab:AddToggle("AutoExtinguishFire", {
		Text = "Auto Extinguish Fire",
		Default = false,
	})

	local easyMantraFeintToggle = assistTab:AddToggle("EasyMantraFeint", {
		Text = "Easy Mantra Feint",
		Default = false,
	})
	easyMantraFeintToggle:AddKeyPicker("EasyMantraFeintKeybind", { Default = "N/A", SyncToggleState = true, Text = "Easy Mantra Feint" })

	local easyRollCancelToggle = assistTab:AddToggle("EasyRollCancel", {
		Text = "Easy Roll Cancel",
		Default = false,
	})
	easyRollCancelToggle:AddKeyPicker("EasyRollCancelKeybind", { Default = "N/A", SyncToggleState = true, Text = "Easy Roll Cancel" })

	local GameTab = require("Menu/GameTab")
	GameTab.initSpoofersSection(tabbox:AddTab("Spoofers"))

	local overrideTab = tabbox:AddTab("Override")
	CombatTab:initProbabilitiesSection(overrideTab)
	CombatTab:initTimingsSection(overrideTab)
end

---@param window table
function CombatTab.initAntiExploit(window)
	local tab = window:AddTab("Anti-Exploit", "Combat", Icons.Combat)

	local tabbox = tab:AddFullTabbox()

	local antiTab = tabbox:AddTab("Anti-Breaker")
	CombatTab.initAntiBreakerSection(antiTab, antiTab)

	CombatTab.initApBreakerSection(tabbox:AddTab("Breakers"))
end
return CombatTab
