local GameTab = {}

---@module GUI.Icons
local Icons = require("GUI/Icons")

---@module Features.Game.Spoofing
local Spoofing = require("Features/Game/Spoofing")

---@module Features.Game.EgirlNotifier
local EgirlNotifier = require("Features/Game/EgirlNotifier")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Environment
local Environment = require("Utility/Environment")

---@module Game.KeyHandling
local KeyHandling = require("Game/KeyHandling")

local players = game:GetService("Players")

---@module Features.Game.Tweening
local Tweening = require("Features/Game/Tweening")

---@module Features.Game.FakeVoid
local FakeVoid = require("Features/Game/FakeVoid")

---@param groupbox table
function GameTab.initMovementSection(groupbox)
	local speedHackToggle = groupbox:AddToggle("Speedhack", {
		Text = "Speedhack",
		Default = false,
	})

	speedHackToggle:AddKeyPicker("SpeedhackKeybind", { Default = "N/A", SyncToggleState = true, Text = "Speedhack" })

	local speedDepBox = groupbox:AddDependencyBox()

	speedDepBox:AddSlider("SpeedhackSpeed", {
		Text = "Speedhack Speed",
		Default = 200,
		Min = 0,
		Max = 300,
		Suffix = "/s",
		Rounding = 0,
	})

	speedDepBox:SetupDependencies({
		{ Toggles.Speedhack, true },
	})

	local cframeSpeedToggle = groupbox:AddToggle("CFrameSpeed", {
		Text = "CFrame Speed",
		Default = false,
	})

	cframeSpeedToggle:AddKeyPicker("CFrameSpeedKeybind", { Default = "N/A", SyncToggleState = true, Text = "CFrame Speed" })

	local cfsDepBox = groupbox:AddDependencyBox()

	cfsDepBox:AddSlider("CFrameSpeedMultiplier", {
		Text = "CFrame Speed Multiplier",
		Default = 1,
		Min = 1,
		Max = 20,
		Suffix = "x",
		Rounding = 1,
	})

	cfsDepBox:SetupDependencies({
		{ Toggles.CFrameSpeed, true },
	})

	local flyToggle = groupbox:AddToggle("Fly", {
		Text = "Fly",
		Default = false,
	})

	flyToggle:AddKeyPicker("FlyKeybind", { Default = "N/A", SyncToggleState = true, Text = "Fly" })

	local flyDepBox = groupbox:AddDependencyBox()

	flyDepBox:AddSlider("FlySpeed", {
		Text = "Fly Speed",
		Default = 200,
		Min = 0,
		Max = 450,
		Suffix = "/s",
		Rounding = 0,
	})

	flyDepBox:AddSlider("FlyUpSpeed", {
		Text = "Spacebar Fly Speed",
		Default = 150,
		Min = 0,
		Max = 450,
		Suffix = "/s",
		Rounding = 0,
	})

	flyDepBox:SetupDependencies({
		{ Toggles.Fly, true },
	})

	local noclipToggle = groupbox:AddToggle("NoClip", {
		Text = "NoClip",
		Default = false,
	})

	noclipToggle:AddKeyPicker("NoClipKeybind", { Default = "N/A", SyncToggleState = true, Text = "NoClip" })

	local noclipDepBox = groupbox:AddDependencyBox()

	noclipDepBox:AddToggle("NoClipCollisionsKnocked", {
		Text = "Collisions While Knocked",
		Default = false,
	})

	noclipDepBox:SetupDependencies({
		{ Toggles.NoClip, true },
	})

	local walkSpeedMultiplierToggle = groupbox:AddToggle("WalkSpeedMultiplier", {
		Text = "Walkspeed Multiplier",
		Default = false,
	})

	walkSpeedMultiplierToggle:AddKeyPicker(
		"WalkSpeedMultiplierKeybind",
		{ Default = "N/A", SyncToggleState = true, Text = "Walkspeed Multiplier" }
	)

	local wsmDepBox = groupbox:AddDependencyBox()

	wsmDepBox:AddSlider("WalkSpeedMultiplierMinimum", {
		Text = "Walkspeed Multiplier Minimum",
		Default = 1.5,
		Min = 1,
		Max = 2,
		Suffix = "x",
		Rounding = 2,
	})

	wsmDepBox:AddSlider("WalkSpeedMultiplierMaximum", {
		Text = "Walkspeed Multiplier Maximum",
		Default = 2,
		Min = 1,
		Max = 2,
		Suffix = "x",
		Rounding = 2,
	})

	wsmDepBox:SetupDependencies({
		{ Toggles.WalkSpeedMultiplier, true },
	})

	local offsetUpLabel = groupbox:AddLabel("Offset Up (1500)")

	offsetUpLabel:AddKeyPicker("OffsetUp", {
		Default = "N/A",
		Mode = "Toggle",
		NoUI = true,
		Text = "Offset Up (1500)",
		Callback = function()
			local localPlayer = players.LocalPlayer
			local character = localPlayer and localPlayer.Character
			if not character then
				return
			end

			character:TranslateBy(Vector3.new(0, 1500, 0))
		end,
	})

	local ttbToggle = groupbox:AddToggle("TweenToBack", {
		Text = "Tween To Back",
		Default = false,
		Callback = function(state)
			if state then
				return
			end

			Tweening.stop("TweenToBack")
		end,
	})

	ttbToggle:AddKeyPicker("TweenToBackKeybind", { Default = "N/A", SyncToggleState = true, Text = "Tween To Back" })

	local ttbDepBox = groupbox:AddDependencyBox()

	ttbDepBox:AddToggle("StickyAttach", {
		Text = "Sticky Attach",
		Default = false,
	})

	ttbDepBox:AddToggle("AttachIgnorePlayers", {
		Text = "Ignore Players",
		Default = true,
	})

	ttbDepBox:AddSlider("BackOffset", {
		Text = "Distance To Entity",
		Default = 5,
		Min = -100,
		Max = 100,
		Suffix = "studs",
		Rounding = 0,
	})

	ttbDepBox:AddSlider("HeightOffset", {
		Text = "Height Offset",
		Default = 0,
		Min = -100,
		Max = 30,
		Suffix = "studs",
		Rounding = 0,
	})

	ttbDepBox:SetupDependencies({
		{ Toggles.TweenToBack, true },
	})

	local tweenToObjectiveToggle = groupbox:AddToggle("TweenToObjective", {
		Text = "Tween To Objectives",
		Default = false,
	})
	tweenToObjectiveToggle:AddKeyPicker(
		"TweenToObjectiveKeybind",
		{ Default = "N/A", SyncToggleState = true, Text = "Tween To Objectives" }
	)

	local infJumpToggle = groupbox:AddToggle("InfiniteJump", {
		Text = "Infinite Jump",
		Default = false,
	})

	infJumpToggle:AddKeyPicker(
		"InfiniteJumpKeybind",
		{ Default = "N/A", SyncToggleState = true, Text = "Infinite Jump" }
	)

	local infiniteJumpDepBox = groupbox:AddDependencyBox()

	infiniteJumpDepBox:AddSlider("InfiniteJumpBoost", {
		Text = "Infinite Jump Boost",
		Default = 50,
		Min = 0,
		Max = 500,
		Suffix = "/s",
		Rounding = 0,
	})

	infiniteJumpDepBox:SetupDependencies({
		{ Toggles.InfiniteJump, true },
	})

	groupbox:AddToggle("AutoSprint", {
		Text = "Auto Sprint",
		Default = false,
	})

	local asDepBox = groupbox:AddDependencyBox()

	asDepBox:AddToggle("AutoSprintOnCrouch", {
		Text = "Auto Sprint On Crouch",
		Default = false,
	})

	asDepBox:AddToggle("AutoSprintDelay", {
		Text = "Auto Sprint Delay",
		Default = false,
	})

	local asdDepBox = asDepBox:AddDependencyBox()

	asdDepBox:AddSlider("AutoSprintDelayTime", {
		Text = "Auto Sprint Delay Time",
		Default = 0.2,
		Min = 0,
		Max = 5,
		Suffix = "s",
		Rounding = 2,
	})

	asdDepBox:SetupDependencies({
		{ Toggles.AutoSprintDelay, true },
	})

	asDepBox:SetupDependencies({
		{ Toggles.AutoSprint, true },
	})

	groupbox:AddButton({
		Text = "Respawn Character",
		DoubleClick = true,
		Func = function()
			local character = players.LocalPlayer.Character
			if not character then
				return
			end

			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then
				return
			end

			character:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 10000000, 0))
		end,
	})

	local function dealSelfFallDamage()
		local remote = KeyHandling.getRemote("FallDamage")
		if not remote then
			return Logger.notify("Failed to find fall damage remote.")
		end

		remote:FireServer(Configuration.expectOptionValue("FallDamageAmount") or 0.0, false)
	end

	groupbox:AddButton({
		Text = "Deal Fall Damage To Self",
		DoubleClick = true,
		Func = dealSelfFallDamage,
	})

	local dealFallDamageLabel = groupbox:AddLabel("Deal Fall Damage Keybind")

	dealFallDamageLabel:AddKeyPicker("DealFallDamageKeybind", {
		Default = "N/A",
		Mode = "Toggle",
		NoUI = true,
		Text = "Deal Fall Damage To Self",
		Callback = function()
			dealSelfFallDamage()
		end,
	})

	groupbox:AddSlider("FallDamageAmount", {
		Text = "Fall Damage Amount",
		Default = 50,
		Min = 0,
		Max = 1000,
		Suffix = "hp",
		Rounding = 0,
	})
end

---@param groupbox table
function GameTab.initSpoofersSection(groupbox)
	groupbox:AddToggle("AgilitySpoof", {
		Text = "Agility Spoofer",
		Default = false,
	})

	local agilitySpoofDepBox = groupbox:AddDependencyBox()

	agilitySpoofDepBox:AddToggle("BoostAgilityDirectly", {
		Text = "Boost Agility Directly",
		Default = false,
	})

	agilitySpoofDepBox:AddSlider("AgilitySpoof", {
		Text = "Agility Value",
		Default = 0,
		Min = 0,
		Max = 400,
		Suffix = "pts",
		Rounding = 0,
	})

	agilitySpoofDepBox:SetupDependencies({
		{ Toggles.AgilitySpoof, true },
	})

	groupbox:AddToggle("FreestylersBandSpoof", {
		Text = "Freestylers Band Spoofer",
		Default = false,
	})

	groupbox:AddToggle("KongaClutchRingSpoof", {
		Text = "Konga Clutch Ring Spoofer",
		Default = false,
	})

	groupbox:AddToggle("LightweightSpoof", {
		Text = "Lightweight Spoofer",
		Default = false,
	})

	groupbox:AddToggle("CaptainEtreaSpoof", {
		Text = "Captain Etrea Spoofer",
		Default = false,
	})

	groupbox:AddToggle("BoatSpeed", {
		Text = "Boat Speed",
		Default = false,
	})

	groupbox:AddToggle("MaxMomentumSpoof", {
		Text = "Max Momentum Spoofer",
		Default = false,
	})
end

---@param groupbox table
function GameTab.initRevealAnimationsSection(groupbox)
	groupbox:AddToggle("RevealAnimations", {
		Text = "Reveal AP Breaker Animations",
		Default = false,
	})

	local revealDepBox = groupbox:AddDependencyBox()

	revealDepBox:AddSlider("RevealWeightThreshold", {
		Text = "Weight Threshold",
		Default = 0.5,
		Min = 0,
		Max = 1,
		Suffix = "",
		Rounding = 2,
	})

	revealDepBox:SetupDependencies({
		{ Toggles.RevealAnimations, true },
	})
end

---@param groupbox table
function GameTab.initPlayerMonitoringSection(groupbox)
	groupbox:AddToggle("NotifyMod", {
		Text = "Mod Notifications",
		Default = true,
	})

	local nmDepBox = groupbox:AddDependencyBox()

	nmDepBox:AddToggle("NotifyModSound", {
		Text = "Mod Notification Sound",
		Default = false,
	})

	local nmbDepBox = nmDepBox:AddDependencyBox()

	nmbDepBox:AddSlider("NotifyModSoundVolume", {
		Text = "Sound Volume",
		Default = 10,
		Min = 0,
		Max = 20,
		Suffix = "v",
		Rounding = 2,
	})

	nmbDepBox:SetupDependencies({
		{ Toggles.NotifyModSound, true },
	})

	nmDepBox:SetupDependencies({
		{ Toggles.NotifyMod, true },
	})

	groupbox:AddToggle("NotifyVoidWalker", {
		Text = "Void Walker Notifications",
		Default = false,
	})

	local niToggle = groupbox:AddToggle("NotifyItems", {
		Text = "Item Notifications",
		Default = false,
	})

	local niDepBox = groupbox:AddDependencyBox()

	local notifyItemsList = niDepBox:AddDropdown("NotifyItemsList", {
		Text = "Item List",
		Default = {},
		SaveValues = true,
		Multi = true,
		Values = {},
	})

	local itemLabel = niDepBox:AddInput("NotifyItemsLabel", {
		Text = "Item Name",
		Placeholder = "Partial or exact item name.",
	})

	niDepBox:AddButton("Add Name To Filter", function()
		local itemLabelValue = itemLabel.Value

		if #itemLabelValue <= 0 then
			return Logger.notify("Please enter a valid item name.")
		end

		local notifyItemsListValues = notifyItemsList.Values

		if not table.find(notifyItemsListValues, itemLabelValue) then
			table.insert(notifyItemsListValues, itemLabelValue)
		end

		notifyItemsList:SetValues(notifyItemsListValues)
		notifyItemsList:SetValue({})
		notifyItemsList:Display()
	end)

	niDepBox:AddButton("Remove Selected Names", function()
		local notifyItemsListValues = notifyItemsList.Values
		local selectedNotifyItems = notifyItemsList.Value

		for selectedNotifyItem, _ in next, selectedNotifyItems do
			local selectedIndex = table.find(notifyItemsListValues, selectedNotifyItem)
			if not selectedIndex then
				return Logger.notify("The selected item name %s does not exist in the list", selectedNotifyItem)
			end

			table.remove(notifyItemsListValues, selectedIndex)
		end

		notifyItemsList:SetValues(notifyItemsListValues)
		notifyItemsList:SetValue({})
		notifyItemsList:Display()
	end)

	niDepBox:SetupDependencies({
		{ niToggle, true },
	})

	groupbox:AddToggle("PlayerSpectating", {
		Text = "Player List Spectating",
		Default = false,
	})

	groupbox:AddToggle("BuildStealer", {
		Text = "Build Stealer",
		Default = false,
	})

	groupbox:AddToggle("HairStealer", {
		Text = "Hair Stealer",
		Default = false,
	})

	groupbox:AddToggle("ShowHiddenPlayers", {
		Text = "Show Hidden Players",
		Default = false,
	})

	groupbox:AddToggle("ShowRobloxChat", {
		Text = "Show Roblox Chat",
		Default = false,
	})

	groupbox:AddToggle("ShowOwnership", {
		Text = "Show Network Ownership",
		Default = false,
	})

	groupbox:AddToggle("PlayerProximity", {
		Text = "Player Proximity Notifications",
		Default = false,
	})

	local ppDepBox = groupbox:AddDependencyBox()

	ppDepBox:AddSlider("PlayerProximityRange", {
		Text = "Player Proximity Distance",
		Default = 1000,
		Min = 50,
		Max = 2500,
		Suffix = "studs",
		Rounding = 0,
	})

	ppDepBox:AddToggle("PlayerProximityVW", {
		Text = "Only Allow Voidwalkers",
		Default = false,
	})

	ppDepBox:AddToggle("PlayerProximityBeep", {
		Text = "Play Beep Sound",
		Default = false,
	})

	local ppbDepBox = ppDepBox:AddDependencyBox()

	ppbDepBox:AddSlider("PlayerProximityBeepVolume", {
		Text = "Beep Sound Volume",
		Default = 0.1,
		Min = 0,
		Max = 10,
		Suffix = "v",
		Rounding = 2,
	})

	ppbDepBox:SetupDependencies({
		{ Toggles.PlayerProximityBeep, true },
	})

	ppDepBox:SetupDependencies({
		{ Toggles.PlayerProximity, true },
	})

	groupbox:AddToggle("EgirlNotifier", {
		Text = "Egirl Notifier",
		Default = false,
		Callback = function(value)
			if value then
				EgirlNotifier.scanAll()
			end
		end,
	})

	local freecamToggle = groupbox:AddToggle("Freecam", {
		Text = "Freecam",
		Default = false,
	})

	freecamToggle:AddKeyPicker("FreecamKeybind", { Default = "N/A", SyncToggleState = true, Text = "Freecam" })

	local freecamDepBox = groupbox:AddDependencyBox()

	freecamDepBox:AddSlider("FreecamSpeed", {
		Text = "Freecam Speed",
		Default = 60,
		Min = 5,
		Max = 400,
		Suffix = "/s",
		Rounding = 0,
	})

	freecamDepBox:SetupDependencies({
		{ Toggles.Freecam, true },
	})

	groupbox:AddToggle("InfiniteZoom", {
		Text = "Infinite Zoom Out",
		Default = false,
	}):AddKeyPicker("InfiniteZoomKeybind", { Default = "N/A", SyncToggleState = true, Text = "Infinite Zoom Out" })
end

---@param groupbox table
function GameTab.initEffectRemovalsSection(groupbox)
	groupbox:AddToggle("NoStun", {
		Text = "No Stun",
		Default = false,
	})

	groupbox:AddToggle("NoSpeedDebuff", {
		Text = "No Speed Debuff",
		Default = false,
	})

	local noFallToggle = groupbox:AddToggle("NoFallDamage", {
		Text = "No Fall Damage",
		Default = false,
	})

	noFallToggle:AddKeyPicker(
		"NoFallDamageKeybind",
		{ Default = "N/A", SyncToggleState = true, Text = "No Fall Damage" }
	)

	groupbox:AddToggle("NoAcidWater", {
		Text = "No Acid Water",
		Default = false,
	})

	groupbox:AddToggle("NoWind", {
		Text = "No Wind",
		Default = false,
	})

	groupbox:AddToggle("NoAttackingClientChecks", {
		Text = "No Attacking Client Checks",
		Default = false,
	})

	groupbox:AddToggle("AlwaysAllowJump", {
		Text = "Always Allow Jump",
		Default = false,
	})
end

---@param groupbox table
function GameTab.initInstanceRemovalsSection(groupbox)
	groupbox:AddToggle("NoEchoModifiers", {
		Text = "No Echo Modifiers",
		Default = false,
	})

	groupbox:AddToggle("NoKillBricks", {
		Text = "No Kill Bricks",
		Default = false,
	})

	local fakeVoidToggle = groupbox:AddToggle("FakeVoid", {
		Text = "Fake Void",
		Default = false,
	})
	fakeVoidToggle:AddKeyPicker("FakeVoidKeybind", { Default = "N/A", SyncToggleState = true, Text = "Fake Void" })
	fakeVoidToggle:OnChanged(function(state)
		if state then
			FakeVoid.init()
		else
			FakeVoid.detach()
		end
	end)

	groupbox:AddToggle("NoDamageBricks", {
		Text = "No Damage Bricks",
		Default = false,
	})

	groupbox:AddToggle("NoCastleLightBarrier", {
		Text = "No Castle Light Barrier",
		Default = false,
	})

	groupbox:AddToggle("NoYunShulBarrier", {
		Text = "No Yun Shul Barrier",
		Default = false,
	})

	groupbox:AddToggle("NoHiveGate", {
		Text = "No Hive Gate",
		Default = false,
	})
end

---@param groupbox table
function GameTab.initDebuggingSection(groupbox)
	groupbox:AddToggle("ShowDebugInformation", {
		Text = "Show Debug Information",
		Default = false,
	})

	groupbox:AddToggle("EffectLogging", {
		Text = "Effect Logging",
		Default = false,
	})

	groupbox:AddToggle("StopGameLogging", {
		Text = "Stop Game Logging",
		Default = false,
	})
end

---@param groupbox table
function GameTab.initInfoSpoofingSection(groupbox)
	local hasEverBeenEnabled = true

	groupbox:AddToggle("InfoSpoofing", {
		Text = "Enable Info Spoofing",
		Default = false,
		Callback = function(value)
			if value or hasEverBeenEnabled then
				Spoofing.rics()
			end

			if not value then
				return
			end

			Spoofing.sss(Configuration.expectOptionValue("SpoofedSlotString"))
			Spoofing.sds(Configuration.expectOptionValue("SpoofedDateString"))
			Spoofing.sgv(Configuration.expectOptionValue("SpoofedGameVersion"))

			hasEverBeenEnabled = true
		end,
	})

	local isDepBox = groupbox:AddDependencyBox()

	isDepBox:AddToggle("SpoofOtherPlayers", {
		Text = "Spoof Other Players",
		Default = false,
		Callback = Spoofing.rics,
	})

	isDepBox:AddToggle("HideDeathInformation", {
		Text = "Hide Death Information",
		Default = false,
	})

	isDepBox:AddInput("SpoofedSlotString", {
		Text = "Spoofed Slot String",
		Default = "1234567890:Z|1 [Lv. 1]",
		Finished = true,
		Callback = Spoofing.sss,
	})

	isDepBox:AddInput("SpoofedDateString", {
		Text = "Spoofed Date String",
		Default = "Linoria, 1970 CE",
		Finished = true,
		Callback = Spoofing.sds,
	})

	isDepBox:AddInput("SpoofedGameVersion", {
		Text = "Spoofed Game Version",
		Default = "pv_JAN_01_00:00z",
		Finished = true,
		Callback = Spoofing.sgv,
	})

	local function refreshHandler()
		if not Configuration.expectToggleValue("InfoSpoofing") then
			return
		end

		Spoofing.rics()
	end

	isDepBox:AddInput("SpoofedFirstName", {
		Text = "Spoofed First Name",
		Default = "W Spoof",
		Finished = true,
		Callback = refreshHandler,
	})

	isDepBox:AddInput("SpoofedLastName", {
		Text = "Spoofed Last Name",
		Default = "On Top",
		Finished = true,
		Callback = refreshHandler,
	})

	isDepBox:AddInput("SpoofedGuildName", {
		Text = "Spoofed Guild Name",
		Default = "discord.gg/lyc",
		Finished = true,
		Callback = refreshHandler,
	})

	isDepBox:AddInput("SpoofedServerName", {
		Text = "Spoofed Server Name",
		Default = "W Spoof",
		Finished = true,
		Callback = refreshHandler,
	})

	isDepBox:AddInput("SpoofedServerRegion", {
		Text = "Spoofed Server Region",
		Default = "discord.gg/lyc",
		Finished = true,
		Callback = refreshHandler,
	})

	isDepBox:AddInput("SpoofedServerAge", {
		Text = "Spoofed Server Age",
		Default = "???",
		Finished = true,
		Callback = refreshHandler,
	})

	isDepBox:SetupDependencies({
		{ Toggles.InfoSpoofing, true },
	})
end

---@param groupbox table
function GameTab.initTweeningSection(groupbox)
	groupbox:AddSlider("TweenStudsPerSecond", {
		Text = "Tween Speed",
		Default = 200,
		Min = 1,
		Max = 450,
		Suffix = "/s",
		Rounding = 0,
	})
end

return GameTab
