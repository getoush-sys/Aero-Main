local AutomationTab = {}

---@module GUI.Icons
local Icons = require("GUI/Icons")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Game.QueuedBlocking
local QueuedBlocking = require("Game/QueuedBlocking")

---@module Game.KeyHandling
local KeyHandling = require("Game/KeyHandling")

---@module Features.Game.Tweening
local Tweening = require("Features/Game/Tweening")

---@module Features.Automation.AutoFerryman
local AutoFerryman = require("Features/Automation/AutoFerryman")

---@module Features.Automation.AutoBuilder
local AutoBuilder = require("Features/Automation/AutoBuilder")

---@module Features.Automation.AutoProg
local AutoProg = require("Features/Automation/AutoProg")

---@module Features.Automation.AutoTo1
local AutoTo1 = require("Features/Automation/AutoTo1")

---@module Features.Automation.AutoVoI
local AutoVoI = require("Features/Automation/AutoVoI")

---@module Features.Automation.AutoTitus
local AutoTitus = require("Features/Automation/AutoTitus")

---@module Features.Automation.EchoFarm
local EchoFarm = require("Features/Automation/EchoFarm")

---@module Features.Automation.AutoLayer2
local AutoLayer2 = require("Features/Automation/AutoLayer2")

---@module Features.Automation.AutoAuthority
local AutoAuthority = require("Features/Automation/AutoAuthority")

---@module Features.Automation.AutoDuke
local AutoDuke = require("Features/Automation/AutoDuke")

---@module Features.Automation.AutoMooneyrie
local AutoMooneyrie = require("Features/Automation/AutoMooneyrie")

---@module Features.Automation.AutoNotes
local AutoNotes = require("Features/Automation/AutoNotes")

---@module Features.Automation.AutoSaramed
local AutoSaramed = require("Features/Automation/AutoSaramed")

---@module Menu.AutoBuilderWindow
local AutoBuilderWindow = require("Menu/AutoBuilderWindow")

---@module GUI.SaveManager
local SaveManager = require("GUI/SaveManager")

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Features.Automation.Objects.AutoLog
local AutoLog = require("Features/Automation/Objects/AutoLog")

---Add a per-automation "Auto Log Distance" slider (0-2000; 0 = off) to a section. The value is saved per
---automation in the AutoLog store (NOT in Aero config saves): ignored by SaveManager, loaded from disk as
---the slider's default, and written back on every change.
---@param groupbox table
---@param flag string unique Options key for the slider
---@param storeKey string automation id the distance is saved under
local function addAutoLogSlider(groupbox, flag, storeKey)
	local slider = groupbox:AddSlider(flag, {
		Text = "Auto Log Distance",
		Tooltip = "Server-hop when another player comes within this many studs (0 = off). Saved per automation, not in configs.",
		Min = 0,
		Max = 2000,
		Rounding = 0,
		Default = AutoLog.get(storeKey),
		Suffix = " studs",
	})
	SaveManager:SetIgnoreIndexes({ flag })
	slider:OnChanged(function(value)
		AutoLog.set(storeKey, value)
	end)
	return slider
end

---Per-automation tween (movement) speed slider: every tween in that automation uses this value. Default
---100, range 50-300. Saved in configs like any normal option.
---@param groupbox table
---@param flag string unique Options key for the slider
local function addTweenSpeedSlider(groupbox, flag)
	return groupbox:AddSlider(flag, {
		Text = "Tween Speed",
		Tooltip = "Movement (tween) speed for this automation, in studs/second.",
		Default = 100,
		Min = 50,
		Max = 300,
		Rounding = 0,
		Suffix = " studs/s",
	})
end

local function addAuthorityMissionToggle(groupbox, flag, label, key)
	local saved = PersistentData.get("authorityMissionToggles")
	local default = true
	if type(saved) == "table" and type(saved[key]) == "boolean" then
		default = saved[key]
	end
	local toggle = groupbox:AddToggle(flag, {
		Text = label,
		Default = default,
	})
	SaveManager:SetIgnoreIndexes({ flag })
	toggle:OnChanged(function(value)
		local current = PersistentData.get("authorityMissionToggles")
		if type(current) ~= "table" then
			current = {}
		end
		current[key] = value == true
		PersistentData.set("authorityMissionToggles", current)
	end)
	return toggle
end

---@param groupbox table
function AutomationTab.initAttributeSection(groupbox)
	groupbox
		:AddToggle("AutoCharisma", {
			Text = "Auto Charisma Farm",
			Default = false,
		})
		:AddKeyPicker("AutoCharismaKeybind", {
			Default = "N/A",
			SyncToggleState = true,
			Text = "Auto Charisma Farm",
		})

	groupbox:AddInput("CharismaCap", {
		Text = "Charisma Cap",
		Numeric = true,
		MaxLength = 3,
		Default = "75",
	})

	groupbox
		:AddToggle("AutoIntelligence", {
			Text = "Auto Intelligence Farm",
			Default = false,
		})
		:AddKeyPicker("AutoIntelligenceKeybind", {
			Default = "N/A",
			SyncToggleState = true,
			Text = "Auto Intelligence",
		})

	groupbox:AddInput("IntelligenceCap", {
		Text = "Intelligence Cap",
		Numeric = true,
		MaxLength = 3,
		Default = "75",
	})
end

---@param groupbox table
function AutomationTab.initFishFarmSection(groupbox)
	groupbox
		:AddToggle("AutoFish", {
			Text = "Auto Fish Farm",
			Default = false,
		})
		:AddKeyPicker("AutoFishKeybind", {
			Default = "N/A",
			SyncToggleState = true,
			Text = "Auto Fish Farm",
		})
end


---@param groupbox table
function AutomationTab.initDebuggingSection(groupbox)
	groupbox:AddButton("Start Deflect", function()
		QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_DEFLECT, "StartDeflect", nil)
	end)

	groupbox:AddButton("Start Deflect 0.1s", function()
		QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_DEFLECT, "StartDeflect", 0.1)
	end)

	groupbox:AddButton("Start Block 0.3s", function()
		QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_NORMAL, "StartBlock", 0.3)
	end)

	groupbox:AddButton("Start Block", function()
		QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_NORMAL, "StartBlock", nil)
	end)

	groupbox:AddButton("Stop All Block", function()
		QueuedBlocking.empty()
	end)

	groupbox:AddButton("Raw Start Block", function()
		local blockRemote = KeyHandling.getRemote("Block")
		if not blockRemote then
			return
		end

		blockRemote:FireServer()
	end)

	groupbox:AddButton("Raw Stop Block", function()
		local unblockRemote = KeyHandling.getRemote("Unblock")
		if not unblockRemote then
			return
		end

		unblockRemote:FireServer()
	end)

	groupbox:AddButton("Test Tween", function()
		local positions = {
			CFrame.new(2414.70, 442.28, -5595.58),
			CFrame.new(2424.78, 408.30, -5501.38),
			CFrame.new(2429.86, 408.30, -5495.80),
			CFrame.new(2507.99, 414.60, -5560.85),
			CFrame.new(600.33, 983.29, -7643.66),
			CFrame.new(669.22, 979.31, -7668.61),
			CFrame.new(2960.38, 404.16, -5604.14),
		}

		for idx, position in next, positions do
			Tweening.goal(string.format("TweenToTest_%i", idx), position, true)
		end
	end)

	groupbox:AddButton("Cancel Tween", function()
		for idx = 1, 7 do
			Tweening.stop(string.format("TweenToTest_%i", idx))
		end
	end)
end

---@param groupbox table
function AutomationTab.initAutoFerrymanSection(groupbox)
	groupbox:AddButton({
		Text = "Start",
		DoubleClick = true,
		Func = function()
			-- start() self-guards on the Eastern Luminant and notifies if we're not there.
			AutoFerryman.start()
		end,
	})
	addAutoLogSlider(groupbox, "FerrymanAutoLogDist", "auto_ferryman")
	addTweenSpeedSlider(groupbox, "FerrymanTweenSpeed")
end

---@param groupbox table
function AutomationTab.initAutoTo1Section(groupbox)
	groupbox:AddButton({
		Text = "Start",
		DoubleClick = true,
		Func = function()
			AutoTo1.start()
		end,
	})
	addTweenSpeedSlider(groupbox, "To1TweenSpeed")
end

---@param groupbox table
function AutomationTab.initAutoVoISection(groupbox)
	groupbox:AddButton({
		Text = "Start Shogun",
		DoubleClick = true,
		Func = function()
			AutoVoI.start("shogun")
		end,
	})

	groupbox:AddButton({
		Text = "Start Rat King",
		DoubleClick = true,
		Func = function()
			AutoVoI.start("ratking")
		end,
	})

	-- NOTE: Enmity button removed for now (hard to get consistent). The enmity logic in AutoVoI is kept
	-- intact -- re-add `AutoVoI.start("enmity")` here to bring the button back.

	addTweenSpeedSlider(groupbox, "VoITweenSpeed")
end

---@param groupbox table
function AutomationTab.initAutoLootSection(groupbox)
	groupbox:AddToggle("AutoLoot", {
		Text = "Auto Loot",
		Tooltip = "Automatically loot items from choice prompts with filtering options.",
		Default = false,
	}):AddKeyPicker("AutoLootKeybind", {
		Default = "N/A",
		SyncToggleState = true,
		Text = "Auto Loot",
	})

	local autoLootDepBox = groupbox:AddDependencyBox()

	autoLootDepBox:AddToggle("AutoLootAll", {
		Text = "Loot All Items",
		Tooltip = "Loot all items from choice prompts. This will ignore filtering options.",
		Default = false,
	})

	local autoLootAllDepBox = autoLootDepBox:AddDependencyBox()

	autoLootAllDepBox:AddSlider("AutoLootStarsMin", {
		Text = "Minimum Stars",
		Tooltip = "The minimum number of stars an item must have to be looted.",
		Min = 0,
		Max = 4,
		Rounding = 0,
		Default = 0,
	})

	autoLootAllDepBox:AddSlider("AutoLootStarsMax", {
		Text = "Maximum Stars",
		Tooltip = "The maximum number of stars an item can have to be looted.",
		Min = 0,
		Max = 4,
		Rounding = 0,
		Default = 4,
	})

	local itemNameList = autoLootAllDepBox:AddDropdown("ItemNameList", {
		Text = "Item Name List",
		Values = {},
		SaveValues = true,
		Multi = true,
		AllowNull = true,
	})

	local itemNameInput = autoLootAllDepBox:AddInput("ItemNameInput", {
		Text = "Item Name Input",
		Placeholder = "Exact or partial names.",
	})

	autoLootAllDepBox:AddButton("Add Item Name To Filter", function()
		local itemName = itemNameInput.Value
		if #itemName <= 0 then
			return Logger.notify("Please enter a valid item name.")
		end

		local values = itemNameList.Values
		if not table.find(values, itemName) then
			table.insert(values, itemName)
		end

		itemNameList:SetValues(values)
		itemNameList:SetValue({})
		itemNameList:Display()
	end)

	autoLootAllDepBox:AddButton("Remove Selected Item Names", function()
		local values = itemNameList.Values
		local value = itemNameList.Value

		for selected, _ in next, value do
			local index = table.find(values, selected)
			if not index then
				continue
			end

			table.remove(values, index)
		end

		itemNameList:SetValues(values)
		itemNameList:SetValue({})
		itemNameList:Display()
	end)

	autoLootAllDepBox:SetupDependencies({
		{ Toggles.AutoLootAll, false },
	})

	autoLootDepBox:SetupDependencies({
		{ Toggles.AutoLoot, true },
	})
end

---@param groupbox table
function AutomationTab.initAutoBuilderSection(groupbox)
	-- The tab only holds the link box + load button. The loaded build's stats, talents and mantras
	-- (preshrine on the left, postshrine on the right) live in a separate window that Load opens.
	local linkInput = groupbox:AddInput("AutoBuilderLink", {
		Text = "Builder Link",
		Placeholder = "deepwoken.co/builder?id=...",
	})

	groupbox:AddButton("Load Build", function()
		local build = AutoBuilder.load(linkInput.Value)
		local classified = AutoBuilder.classified

		if build and classified then
			AutoBuilderWindow.show(build, classified)
		end
	end)

	-- A Mantra Hand always contains a special "Roll 2" card that grants 2 Talents instead of a Mantra.
	-- With this on, the builder always takes Roll 2 on mantra hands rather than picking a mantra.
	groupbox:AddToggle("AutoBuilderOnlyRoll2", {
		Text = "Only Roll 2 For Mantras",
		Default = false,
		Tooltip = "On a Mantra Hand, always take the 'Roll 2' card (2 Talents instead of a Mantra). Talent choices are unaffected.",
	})

	-- Start/Stop button. Reads "Start Preshrine"/"Start Postshrine" per the selected target (double-
	-- click to confirm), and flips to "Stop" once picking is running.
	local startButton
	local function startLabel()
		return AutoBuilder.target == "post" and "Start Postshrine" or "Start Preshrine"
	end

	local function applyState()
		if AutoBuilder.picking then
			startButton.Text = "Stop"
			startButton.Label.Text = "Stop"
			startButton.DoubleClick = false
			startButton.Func = AutoBuilder.stopPicking
		else
			local label = startLabel()
			startButton.Text = label
			startButton.Label.Text = label
			startButton.DoubleClick = true
			startButton.Func = AutoBuilder.startPicking
		end
	end

	startButton = groupbox:AddButton({
		Text = startLabel(),
		DoubleClick = true,
		Func = AutoBuilder.startPicking,
	})

	-- Keep the button in sync with target changes (from the window) and start/stop (incl. a hop
	-- resume that flips picking on without this button being pressed).
	AutoBuilder.onStateChanged = applyState

	-- Reflect any state that a server-hop resume may have already set before the menu was built.
	applyState()
end

---@param groupbox table
function AutomationTab.initAutoProgSection(groupbox)
	-- Like Auto Builder (a link box + Load that opens the preshrine/postshrine window), but the start
	-- buttons run the full progression: the builder invests points + picks talents toward the spread
	-- while the chosen farm earns the points. Shrine manually between preshrine and postshrine.
	local linkInput = groupbox:AddInput("AutoProgLink", {
		Text = "Builder Link",
		Placeholder = "deepwoken.co/builder?id=...",
	})

	groupbox:AddButton("Load Build", function()
		local build = AutoBuilder.load(linkInput.Value)
		local classified = AutoBuilder.classified

		if build and classified then
			AutoBuilderWindow.show(build, classified)
		end
	end)

	groupbox:AddDropdown("AutoProgFarmMethod", {
		Text = "Method",
		Values = { "Ferryman", "Saramed" },
		Default = "Ferryman",
	})

	groupbox:AddButton({
		Text = "Start Preshrine",
		DoubleClick = true,
		Func = AutoProg.startPreshrine,
	})

	groupbox:AddButton({
		Text = "Start Postshrine",
		DoubleClick = true,
		Func = AutoProg.startPostshrine,
	})

	groupbox:AddButton({
		Text = "Stop",
		Func = AutoProg.stop,
	})
end

---@param groupbox table
function AutomationTab.initAutoTitusSection(groupbox)
	groupbox:AddButton({
		Text = "Start",
		DoubleClick = true,
		Func = function()
			-- start() self-guards on the merit hub / Titus dungeon and notifies if we're not there.
			AutoTitus.start()
		end,
	})

	addAutoLogSlider(groupbox, "TitusAutoLogDist", "auto_titus")
	addTweenSpeedSlider(groupbox, "TitusTweenSpeed")

	-- Relic names to bank when we hold >= 25 of them (leave empty to never bank).
	local bankList = groupbox:AddDropdown("TitusBankItems", {
		Text = "Bank Items (>=25)",
		-- Pre-populated with the real relic item names (exact Backpack Tool names, same list PR banks) so
		-- they always match countItem(). The old empty list forced you to hand-type a name, and any typo /
		-- wrong case / missing apostrophe silently never matched -- so it never banked. Use the input +
		-- "Add Bank Item" below only for relics outside this standard set.
		Values = { "Moonseye Tome", "Idol of Yun'Shul", "Armorer's Needle", "Smith's Alloy" },
		Default = { "Moonseye Tome", "Idol of Yun'Shul", "Armorer's Needle", "Smith's Alloy" },
		SaveValues = true,
		Multi = true,
		AllowNull = true,
	})

	local bankInput = groupbox:AddInput("TitusBankItemInput", {
		Text = "Bank Item Name",
		Placeholder = "Exact relic name.",
	})

	groupbox:AddButton("Add Bank Item", function()
		local itemName = bankInput.Value
		if #itemName <= 0 then
			return Logger.notify("Please enter a valid relic name.")
		end
		-- Snapshot the current selection so adding a custom relic doesn't wipe what's already ticked.
		local selected = {}
		for selectedName in next, bankList.Value do
			selected[selectedName] = true
		end

		local values = bankList.Values
		if not table.find(values, itemName) then
			table.insert(values, itemName)
		end
		bankList:SetValues(values)

		-- Keep the previous selection and also tick the item we just added.
		selected[itemName] = true
		bankList:SetValue(selected)
		bankList:Display()
	end)

	groupbox:AddButton("Remove Selected Bank Items", function()
		local values = bankList.Values
		for selected, _ in next, bankList.Value do
			local index = table.find(values, selected)
			if index then
				table.remove(values, index)
			end
		end
		bankList:SetValues(values)
		bankList:SetValue({})
		bankList:Display()
	end)
end

---@param groupbox table
function AutomationTab.initEchoFarmSection(groupbox)
	-- Titus echo farm (Fort Merit detainment). Start is a double-click: shows "Start", then
	-- "THIS WILL WIPE YOUR CURRENT CHARACTER" after the first click; clicking again confirms and starts.
	groupbox:AddButton({
		Text = "Start",
		DoubleClick = true,
		DoubleClickText = "THIS WILL WIPE YOUR CURRENT CHARACTER",
		Func = function()
			EchoFarm.invoke("Titus")
		end,
	})
	-- Distance governs the Titus farm's player-proximity server-hop (0 = never hop on nearby players).
	addAutoLogSlider(groupbox, "EchoFarmAutoLogDist", "echo_farm")
	addTweenSpeedSlider(groupbox, "EchoFarmTweenSpeed")
	-- Stop via the on-screen overlay's Stop button.
end

---@param groupbox table
function AutomationTab.initAutoLayer2Section(groupbox)
	groupbox:AddToggle("L2AllowLoops", { Text = "Loop", Default = false })
	groupbox:AddToggle("L2KillChaser", { Text = "Kill chaser", Default = true })
	groupbox:AddToggle("L2VoidChaser", { Text = "Void (Frost Grab)", Default = false })
	groupbox:AddToggle("L2KillEthiron", { Text = "Floor 2", Default = false })
	groupbox:AddToggle("L2LootChests", { Text = "Loot chests", Default = true })

	groupbox:AddButton({
		Text = "Start",
		DoubleClick = true,
		Func = function()
			AutoLayer2.start()
		end,
	})
	addTweenSpeedSlider(groupbox, "Layer2TweenSpeed")
	-- Stop via the on-screen overlay's Stop button.
end

---@param groupbox table
function AutomationTab.initAutoAuthoritySection(groupbox)
	addAuthorityMissionToggle(groupbox, "AuthorityHostage", "Do Hostage missions", "hostage")
	addAuthorityMissionToggle(groupbox, "AuthorityBarrels", "Do Armament Sabotage missions", "barrels")
	addAuthorityMissionToggle(groupbox, "AuthoritySecure", "Do Secure missions", "secure")

	groupbox:AddButton({
		Text = "Start",
		DoubleClick = true,
		Func = function()
			AutoAuthority.start()
		end,
	})
	addAutoLogSlider(groupbox, "AuthorityAutoLogDist", "auto_authority")
	addTweenSpeedSlider(groupbox, "AuthorityTweenSpeed")
	-- Stop via the on-screen overlay's Stop button.
end

---@param groupbox table
function AutomationTab.initAutoDukeSection(groupbox)
	groupbox:AddToggle("DukeVoids", { Text = "Void (Frost Grab)", Default = false })

	groupbox:AddButton({
		Text = "Start",
		DoubleClick = true,
		Func = function()
			AutoDuke.start()
		end,
	})
	addAutoLogSlider(groupbox, "DukeAutoLogDist", "auto_duke")
	addTweenSpeedSlider(groupbox, "DukeTweenSpeed")
	-- Stop via the on-screen overlay's Stop button.
end

---@param groupbox table
function AutomationTab.initAutoMooneyrieSection(groupbox)
	groupbox:AddButton({
		Text = "Start",
		DoubleClick = true,
		Func = function()
			AutoMooneyrie.start()
		end,
	})
	addAutoLogSlider(groupbox, "MooneyrieAutoLogDist", "auto_mooneyrie")
	addTweenSpeedSlider(groupbox, "MooneyrieTweenSpeed")
	-- Stop via the on-screen overlay's Stop button.
end

---@param groupbox table
function AutomationTab.initAutoNotesSection(groupbox)
	groupbox:AddToggle("NotesUseGuild", { Text = "Use guild", Default = false })

	groupbox:AddButton({
		Text = "Start",
		DoubleClick = true,
		DoubleClickText = "THIS WILL WIPE YOUR CURRENT CHARACTER",
		Func = function()
			AutoNotes.invoke()
		end,
	})
	addAutoLogSlider(groupbox, "NotesAutoLogDist", "auto_notes")
	addTweenSpeedSlider(groupbox, "NotesTweenSpeed")
	-- Stop via the on-screen overlay's Stop button.
end

---@param groupbox table
function AutomationTab.initAutoSaramedSection(groupbox)
	groupbox:AddButton({
		Text = "Start",
		DoubleClick = true,
		Func = function()
			AutoSaramed.start()
		end,
	})
	addAutoLogSlider(groupbox, "SaramedAutoLogDist", "auto_saramed")
	addTweenSpeedSlider(groupbox, "SaramedTweenSpeed")
	-- Stop via the on-screen overlay's Stop button.
end

---@param window table
---@param groupbox table
function AutomationTab.initGeneralSection(groupbox)
	-- The key every automation presses to interact (instead of firing ProximityPrompts directly). Default E.
	groupbox:AddLabel("Interact Key"):AddKeyPicker("AutomationInteractKey", {
		Default = "E",
		Text = "Interact Key",
	})
end

function AutomationTab.init(window)
	local tab = window:AddTab("Auto", "Utility", Icons.Auto)

	AutomationTab.initGeneralSection(tab:AddDynamicGroupbox("General"))
	AutomationTab.initFishFarmSection(tab:AddDynamicGroupbox("Fish Farm"))
	AutomationTab.initAttributeSection(tab:AddDynamicGroupbox("Attribute Farm"))
	AutomationTab.initAutoFerrymanSection(tab:AddDynamicGroupbox("Auto Ferryman"))
	AutomationTab.initAutoTo1Section(tab:AddDynamicGroupbox("Auto To1"))
	AutomationTab.initAutoVoISection(tab:AddDynamicGroupbox("Auto VoI"))
	AutomationTab.initAutoTitusSection(tab:AddDynamicGroupbox("Auto Titus"))
	AutomationTab.initEchoFarmSection(tab:AddDynamicGroupbox("Echo Farm"))
	AutomationTab.initAutoLayer2Section(tab:AddDynamicGroupbox("Auto L2"))
	AutomationTab.initAutoAuthoritySection(tab:AddDynamicGroupbox("Auto Authority"))
	AutomationTab.initAutoDukeSection(tab:AddDynamicGroupbox("Auto Duke"))
	AutomationTab.initAutoMooneyrieSection(tab:AddDynamicGroupbox("Auto Mooneyrie"))
	AutomationTab.initAutoNotesSection(tab:AddDynamicGroupbox("Auto Notes"))
	AutomationTab.initAutoSaramedSection(tab:AddDynamicGroupbox("Auto Saramaed"))
	AutomationTab.initAutoBuilderSection(tab:AddDynamicGroupbox("Auto Builder"))
	AutomationTab.initAutoProgSection(tab:AddDynamicGroupbox("Auto Prog"))
	AutomationTab.initAutoLootSection(tab:AddDynamicGroupbox("Auto Loot"))
end

return AutomationTab
