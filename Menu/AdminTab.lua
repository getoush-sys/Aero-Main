-- AdminTab module -- developer-only admin control panel.
local AdminTab = {}

---@module GUI.Library
local Library = require("GUI/Library")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Features.Admin
local Admin = require("Features/Admin")

---@module Features.Game.Monitoring
local Monitoring = require("Features/Game/Monitoring")

---@module Features.Exploits.AnimationFlooder
local AnimationFlooder = require("Features/Exploits/AnimationFlooder")

---@module Features.Combat.AnimationInspector
local AnimationInspector = require("Features/Combat/AnimationInspector")

local Players = game:GetService("Players")

-- Teleport destinations the ;tp command accepts (see Features/Game/Teleport.lua).
local TP_DESTINATIONS = {
	"EasternLuminant",
	"EtreanLuminant",
	"Depths",
	"Voidheart",
	"TrialOfOne",
	"GuildDoor",
}

---Resolve a live Player from a username (the roster dropdown stores names).
---@param name string
---@return Player?
local function playerFromName(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end

	for _, plr in next, Players:GetPlayers() do
		if plr.Name == name then
			return plr
		end
	end

	return nil
end

---The username the panel is currently pointed at, or nil.
---@return string?
local function selectedName()
	local option = Options and Options["AdminTarget"]
	return option and option.Value or nil
end


---@param name string
---@return string
local function targetToken(name)
	local localPlayer = Players.LocalPlayer
	if localPlayer and name == localPlayer.Name then
		return "me"
	end
	return name
end

---Fire a command at whoever's selected, with a friendly notify either way.
---@param cmd string
---@param extra string?
local function runCommand(cmd, extra)
	local name = selectedName()
	if not name then
		return Logger.notify("Admin panel: pick a player first.")
	end

	if Admin.sendCommand(cmd, targetToken(name), extra) then
		Logger.notify("Admin panel: sent '%s' to %s.", cmd, name)
	else
		Logger.notify("Admin panel: failed to send '%s' (no chat channel).", cmd)
	end
end

---Point the spectate camera at the selected player. 
local function spectateSelected()
	local name = selectedName()
	if not name then
		return Logger.notify("Admin panel: pick a player to spectate.")
	end

	local player = playerFromName(name)
	if not player then
		return Logger.notify("Admin panel: '%s' is no longer in the server.", name)
	end

	if player == Players.LocalPlayer then
		Monitoring.subject = nil
		return Logger.notify("Admin panel: that's you -- camera reset.")
	end

	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return Logger.notify("Admin panel: '%s' isn't loaded in yet.", name)
	end

	Monitoring.subject = humanoidRootPart
	Logger.notify("Admin panel: spectating %s.", name)
end

---Release the spectate camera.
local function stopSpectating()
	Monitoring.subject = nil
	Logger.notify("Admin panel: stopped spectating.")
end

--- Initialize the Admin tab.
---@param window table
function AdminTab.init(window)
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end

	-- Whitelist gate: the whole tab only exists for developers.
	if not Admin.isDeveloper(localPlayer.UserId) then
		return
	end

	local tab = window:AddTab("Admin")

	-- ---- Players / spectate ----
	local roster = tab:AddLeftGroupbox("Players")

	
	roster:AddDropdown("AdminTarget", {
		Text = "Target Player",
		SpecialType = "Player",
		AllowNull = true,
		Tooltip = "Every player in the server, yourself included. Drives the admin commands.",
	})

	roster:AddButton({
		Text = "Spectate Selected",
		Func = spectateSelected,
		Tooltip = "Lock your camera onto the selected player.",
	})
	roster:AddButton({
		Text = "Stop Spectating",
		Func = stopSpectating,
	})

	roster:AddButton({
		Text = "Bring To Me",
		Func = function()
			runCommand("bring")
		end,
		Tooltip = "Pull the selected player to your position.",
	})

	-- ---- Commands ----
	local cmds = tab:AddRightGroupbox("Commands")

	cmds:AddButton({
		Text = "Freeze",
		Func = function()
			runCommand("freeze")
		end,
		Tooltip = "Anchor the target in place.",
	})
	cmds:AddButton({
		Text = "Unfreeze",
		Func = function()
			runCommand("unfreeze")
		end,
	})
	cmds:AddButton({
		Text = "Kill",
		DoubleClick = true,
		Tooltip = "Double-click. Sends max fall damage to the target.",
		Func = function()
			runCommand("kill")
		end,
	})
	cmds:AddButton({
		Text = "Kick",
		DoubleClick = true,
		Tooltip = "Double-click. Kicks the target, naming you as the admin.",
		Func = function()
			runCommand("kick")
		end,
	})
	cmds:AddButton({
		Text = "Fake Ban",
		DoubleClick = true,
		Tooltip = "Double-click. Kicks the target with a fake moderation-ban notice.",
		Func = function()
			runCommand("fakeban")
		end,
	})
	cmds:AddButton({
		Text = "Unload Their Aero",
		DoubleClick = true,
		Tooltip = "Double-click. Force-unloads Aero on the target's client.",
		Func = function()
			runCommand("unload")
		end,
	})
	cmds:AddButton({
		Text = "Fake Agamatsu",
		Func = function()
			runCommand("fakeagamatsu")
		end,
		Tooltip = "Fires a counterfeit 'Agamatsu is staff' alert on the target.",
	})

	-- ---- Teleport ----
	local tp = tab:AddRightGroupbox("Teleport")

	tp:AddDropdown("AdminTpDestination", {
		Text = "Destination",
		Values = TP_DESTINATIONS,
		Default = TP_DESTINATIONS[1],
		Tooltip = "Where ;tp sends the selected player.",
	})
	tp:AddButton({
		Text = "Teleport Selected",
		Func = function()
			local option = Options and Options["AdminTpDestination"]
			runCommand("tp", option and option.Value or nil)
		end,
	})

	--Animation flooder/forgeban
	local flood = tab:AddLeftGroupbox("Forge Ban")

	-- Everyone except yourself (flooding your own character is pointless), sorted.
	local function flooderNames()
		local names = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Players.LocalPlayer then
				names[#names + 1] = p.Name
			end
		end
		table.sort(names)
		return names
	end

	local flooderInitial = flooderNames()

	local flooderDropdown = flood:AddDropdown("AnimationFlooderTarget", {
		Text = "Target Player",
		Values = flooderInitial,
		Default = flooderInitial[1] or "",
		Multi = false,
		AllowNull = true,
		Tooltip = "Which player to flood animations on.",
		Callback = function(name)
			AnimationFlooder.setTargetByName(name)
		end,
	})

	flood:AddButton({
		Text = "Refresh Player List",
		Func = function()
			pcall(function() flooderDropdown:SetValues(flooderNames()) end)
		end,
	})

	flood:AddSlider("AnimationFlooderIntensity", {
		Text = "Intensity",
		Default = 8,
		Min = 1,
		Max = 50,
		Rounding = 0,
		Tooltip = "Flood animations played per second on the target.",
	})

	local floodToggle = flood:AddToggle("AnimationFlooder", {
		Text = "Flood Player Animations",
		Default = false,
		Tooltip = "Plays every decoy attack animation on the selected player's character.",
	})
	floodToggle:OnChanged(function(state)
		if state then
			AnimationFlooder.startByName(flooderDropdown.Value)
		else
			AnimationFlooder.stop()
		end
	end)
	floodToggle:AddKeyPicker("AnimationFlooderKeybind", { Default = "N/A", SyncToggleState = true, Text = "Flood Player Animations" })

	Players.PlayerAdded:Connect(function()
		pcall(function() flooderDropdown:SetValues(flooderNames()) end)
	end)
	Players.PlayerRemoving:Connect(function()
		pcall(function() flooderDropdown:SetValues(flooderNames()) end)
	end)

	-- ---- Animation Logger 
	local logger = tab:AddLeftGroupbox("Animation Logger")

	logger:AddDivider()

	-- Yourself included, and listed FIRST so it's the default pick -- inspecting your own animations is how you see what your breaker is actually emitting.
	local function inspectNames()
		local names = {}
		local lp = Players.LocalPlayer
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp then
				names[#names + 1] = p.Name
			end
		end
		table.sort(names)
		if lp then
			table.insert(names, 1, lp.Name)
		end
		return names
	end

	local inspectInitial = inspectNames()

	local inspectDropdown = logger:AddDropdown("AnimInspectTarget", {
		Text = "Inspect Player",
		Values = inspectInitial,
		Default = inspectInitial[1] or "",
		Multi = false,
		AllowNull = true,
		Tooltip = "Which player's live animations to show in the inspector window. You're listed first, so leave it as-is to watch your own.",
		Callback = function(name)
			AnimationInspector.setTargetByName(name)
		end,
	})

	logger:AddButton({
		Text = "Refresh Player List",
		Func = function()
			pcall(function() inspectDropdown:SetValues(inspectNames()) end)
		end,
	})

	logger:AddToggle("AnimInspectLogToFile", {
		Text = "Log to File",
		Default = false,
		Tooltip = "While the inspector runs, write the target's animation name/id/priority (and any change to them) to luma_animlog.txt in your executor's workspace folder.",
	})

	local inspectToggle = logger:AddToggle("AnimationInspector", {
		Text = "Animation Inspector",
		Default = false,
		Tooltip = "Opens a live window listing every animation the selected player is currently playing. Rows appear as animations start and are DELETED the moment each one ends.",
	})
	inspectToggle:OnChanged(function(state)
		if state then
			AnimationInspector.startByName(inspectDropdown.Value)
		else
			AnimationInspector.stop()
		end
	end)

	-- Keep the dropdown in sync as players join / leave.
	Players.PlayerAdded:Connect(function()
		pcall(function() inspectDropdown:SetValues(inspectNames()) end)
	end)
	Players.PlayerRemoving:Connect(function()
		pcall(function() inspectDropdown:SetValues(inspectNames()) end)
	end)
end

-- Return AdminTab module.
return AdminTab