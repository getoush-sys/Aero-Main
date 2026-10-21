local AeroTab = {}

---@module GUI.Icons
local Icons = require("GUI/Icons")

---@module GUI.ThemeManager
local ThemeManager = require("GUI/ThemeManager")

---@module GUI.SaveManager
local SaveManager = require("GUI/SaveManager")

---@module GUI.Library
local Library = require("GUI/Library")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.SpotifyClient
local SpotifyClient = require("Utility/SpotifyClient")

---@module GUI.SpotifyWidget
local SpotifyWidget = require("GUI/SpotifyWidget")

---@param groupbox table
function AeroTab.initCheatSettingsSection(groupbox)
	groupbox:AddButton("Toggle Silent Mode", function()
		if not isfile or not delfile or not writefile then
			return
		end

		shared.Aero.silent = not shared.Aero.silent

		if not shared.Aero.silent then
			Logger.notify("Silent mode was disabled.")
		end

		if isfile("smarker.txt") then
			delfile("smarker.txt")
		else
			writefile(
				"smarker.txt",
				"Hello, if you're reading this, that means you have Aero (Deepwoken) silent mode turned on. Deleting this file will turn it off."
			)
		end
	end)

	groupbox:AddButton("Toggle Player Scanning", function()
		if not isfile or not delfile or not writefile then
			return
		end

		shared.Aero.dpscanning = not shared.Aero.dpscanning

		if shared.Aero.dpscanning then
			Logger.notify("Player scanning was disabled.")
		else
			Logger.notify("Player scanning was enabled.")
		end

		if isfile("dpscanning.txt") then
			delfile("dpscanning.txt")
		else
			writefile(
				"dpscanning.txt",
				"Hello, if you're reading this, that means you have Aero (Deepwoken) player scanning turned off. Deleting this file will turn it on."
			)
		end
	end)

	groupbox:AddButton("Toggle Bloxstrap RPC", function()
		if not isfile or not delfile or not writefile then
			return
		end

		shared.Aero.norpc = not shared.Aero.norpc

		if not shared.Aero.norpc then
			Logger.notify("Bloxstrap RPC was enabled.")
		else
			Logger.notify("Bloxstrap RPC was disabled.")
		end

		if isfile("norpc.txt") then
			delfile("norpc.txt")
		else
			writefile(
				"norpc.txt",
				"Hello, if you're reading this, that means you have Aero (Deepwoken) Bloxstrap RPC turned off. Deleting this file will turn it on."
			)
		end
	end)

	groupbox:AddButton("Toggle Debug Logs", function()
		if not isfile or not delfile or not writefile then
			return
		end

		shared.Aero.verbose = not shared.Aero.verbose

		if shared.Aero.verbose then
			Logger.notify("Debug logs were enabled.")
		else
			Logger.notify("Debug logs were disabled.")
		end

		if isfile("verbose.txt") then
			delfile("verbose.txt")
		else
			writefile(
				"verbose.txt",
				"Hello, if you're reading this, that means you have Aero (Deepwoken) debug logs turned on. Deleting this file will turn it off."
			)
		end
	end)

	groupbox:AddButton("Unload Cheat", function()
		shared.Aero.detach()
	end)
end

function AeroTab.initSpotifySection(groupbox)
	groupbox:AddButton("Copy Auth URL", function()
		setclipboard(SpotifyClient.getAuthUrl())
		Logger.notify("Auth URL copied. Open it in a browser, log in, click Allow, then copy the URL it redirects to (even if the page fails to load).")
	end)

	local redirectUrlInput = groupbox:AddInput("SpotifyRedirectUrl", {
		Text = "Redirect URL",
		Placeholder = "Paste the full URL you were redirected to here.",
	})

	groupbox:AddButton("Authorize", function()
		local ok, err = SpotifyClient.completeAuth(redirectUrlInput.Value)
		if ok then
			Logger.notify("Spotify authorized successfully.")
		else
			Logger.notify("Spotify authorization failed: " .. tostring(err))
		end
	end)

	SpotifyWidget.init(Library)

	local showWidgetToggle = groupbox:AddToggle("ShowSpotifyWidget", {
		Text = "Show Spotify Widget",
		Default = false,
	})

	showWidgetToggle:OnChanged(function(state)
		SpotifyWidget.setVisible(state)
	end)
end

---@param groupbox table
function AeroTab.initUISettingsSection(groupbox)
	groupbox:AddSlider("NotificationScale", {
		Text = "Notification Scale",
		Min = 50,
		Max = 300,
		Default = 100,
		Rounding = 0,
		Suffix = "%",
	})

	groupbox:AddSlider("QuickNotificationSpeed", {
		Text = "Quick Notification Speed",
		Min = 0.1,
		Max = 2.0,
		Default = 0.5,
		Rounding = 2,
		Suffix = "s",
	})

	local menuBindLabel = groupbox:AddLabel("Menu Bind")

	menuBindLabel:AddKeyPicker("MenuKeybind", { Default = "LeftAlt", NoUI = true, Text = "Menu Keybind" })

	local keybindFrameLabel = groupbox:AddLabel("Keybind List Bind")

	keybindFrameLabel:AddKeyPicker("KeybindList", {
		Default = "N/A",
		Mode = "Off",
		NoUI = true,
		Text = "Keybind List",
		Callback = function(Value)
			Library.KeybindFrame.Visible = Value
		end,
	})

	-- The keybind list's KeyPicker:Update() reads Toggles.OnlyShowEnabledKeybinds to decide whether to hide
	-- bindings whose feature is currently off. YSL defines this toggle in its own settings module, which Aero
	-- replaces -- so create it here and re-run every KeyPicker's Update() on change to refresh the list.
	local onlyEnabledKeybinds = groupbox:AddToggle("OnlyShowEnabledKeybinds", {
		Text = "Only Show Enabled Keybinds",
		Tooltip = "Hide keybinds from the on-screen list unless their feature is currently toggled on.",
		Default = false,
	})
	onlyEnabledKeybinds:OnChanged(function()
		for _, option in pairs(Options) do
			if option.Type == "KeyPicker" and option.Update then
				option:Update()
			end
		end
	end)

	local watermarkFrameLabel = groupbox:AddLabel("Watermark Bind")

	watermarkFrameLabel:AddKeyPicker("Watermark", {
		Default = "N/A",
		Mode = "Off",
		NoUI = true,
		Text = "Watermark",
		Callback = function(Value)
			Library:SetWatermarkVisibility(Value)
		end,
	})

	groupbox:AddToggle("HideUIInMenus", {
		Text = "Hide UI In Menus",
		Tooltip = "Hide the keybind list and watermark while the inventory or other in-game menus are open.",
		Default = false,
	})

	-- YSL ArrayList: on-screen HUD listing currently-enabled toggles. The controller is created in the
	-- Library's CreateWindow wrapper and self-registers as Library.ArrayListController. These control
	-- toggles set ArrayList = false so they don't list themselves.
	local arrayListToggle = groupbox:AddToggle("YSL_ArrayListEnabled", {
		Text = "Array List",
		Tooltip = "Show currently enabled toggles in a movable on-screen list.",
		Default = false,
		ArrayList = false,
	})
	arrayListToggle:OnChanged(function(enabled)
		if Library.ArrayListController then
			Library.ArrayListController:SetVisible(enabled)
		end
	end)

	local arrayListBackgroundToggle = groupbox:AddToggle("YSL_ArrayListBackground", {
		Text = "Array List Background",
		Tooltip = "Draw a translucent background behind each ArrayList row.",
		Default = true,
		ArrayList = false,
	})
	arrayListBackgroundToggle:OnChanged(function(enabled)
		if Library.ArrayListController then
			Library.ArrayListController:SetBackgroundEnabled(enabled)
		end
	end)
end

function AeroTab.init(window)
	local tab = window:AddTab("Settings", "Settings", Icons.Settings)

	local tabbox = tab:AddFullTabbox()

	AeroTab.initCheatSettingsSection(tabbox:AddTab("Cheat"))
	AeroTab.initUISettingsSection(tabbox:AddTab("Interface"))

	local debugTab = tabbox:AddTab("Debug")
	local CombatTab = require("Menu/CombatTab")
	local GameTab = require("Menu/GameTab")
	local AutomationTab = require("Menu/AutomationTab")
	if not LRM_UserNote then
		CombatTab.initDebuggingSection(debugTab)
	end
	GameTab.initDebuggingSection(debugTab)
	if not LRM_UserNote then
		AutomationTab.initDebuggingSection(debugTab)
	end

	ThemeManager:ApplyToGroupbox(tabbox:AddTab("Theme"))

	if not LPH_OBFUSCATED then
		AeroTab.initSpotifySection(tabbox:AddTab("Spotify"))
	end
end

return AeroTab
