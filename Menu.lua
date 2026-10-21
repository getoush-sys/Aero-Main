local Menu = {}

---@module GUI.ThemeManager
local ThemeManager = require("GUI/ThemeManager")

---@module GUI.SaveManager
local SaveManager = require("GUI/SaveManager")

---@module GUI.Library
local Library = require("GUI/Library")

---@module Menu.CombatTab
local CombatTab = require("Menu/CombatTab")

---@module Menu.GameTab
local GameTab = require("Menu/GameTab")

---@module Menu.AutomationTab
local AutomationTab = require("Menu/AutomationTab")

---@module Menu.TimingBuilderTab
local TimingBuilderTab = require("Menu/TimingBuilderTab")

---@module Menu.VisualsTab
local VisualsTab = require("Menu/VisualsTab")

---@module Menu.ExploitTab
local ExploitTab = require("Menu/ExploitTab")

---@module Menu.AeroTab
local AeroTab = require("Menu/AeroTab")

---@module Menu.UtilityTab
local UtilityTab = require("Menu/UtilityTab")

---@module Menu.ConfigTab
local ConfigTab = require("Menu/ConfigTab")

---@module Menu.AdminTab
local AdminTab = require("Menu/AdminTab")

---@module Menu.CustomTab
local CustomTab = require("Menu/CustomTab")

---@module Features.Custom.Custom
local Custom = require("Features/Custom/Custom")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

local runService = game:GetService("RunService")
local stats = game:GetService("Stats")
local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService")

local renderStepped = Signal.new(runService.RenderStepped)

local menuMaid = Maid.new()

local MENU_TITLE = "Aero rewrite"

function Menu.init()
	local Window = Library:Window({Name = MENU_TITLE})
	local Watermark = Library:Watermark(MENU_TITLE)
	local KeybindList = Library:KeybindList()

	ThemeManager:SetLibrary(Library)
	ThemeManager:SetFolder("Aero-Rewrite-Themes")

	SaveManager:SetLibrary(Library)
	SaveManager:IgnoreThemeSettings()
	SaveManager:SetFolder("Aero-Rewrite-Configs")
	SaveManager:SetIgnoreIndexes({
		"Fly",
		"NoClip",
		"Speedhack",
		"InfiniteJump",
		"TweenToObjective",
		"TweenToBack",
	})

	CombatTab.init(Window)
	CombatTab.initAntiExploit(Window)

	local lastUpdate = os.clock()

	menuMaid:add(renderStepped:connect("Menu_WatermarkUpdate", LPH_NO_VIRTUALIZE(function()
		if os.clock() - lastUpdate <= 0.5 then return end
		lastUpdate = os.clock()

		local networkStats = stats:FindFirstChild("Network")
		local workspaceStats = stats:FindFirstChild("Workspace")
		local performanceStats = stats:FindFirstChild("PerformanceStats")
		local serverStats = networkStats and networkStats:FindFirstChild("ServerStatsItem") or nil

		local pingData = serverStats and serverStats:FindFirstChild("Data Ping") or nil
		local heartbeatData = workspaceStats and workspaceStats:FindFirstChild("Heartbeat") or nil
		local cpuData = performanceStats and performanceStats:FindFirstChild("CPU") or nil
		local gpuData = performanceStats and performanceStats:FindFirstChild("GPU") or nil

		local ping = pingData and pingData:GetValue() or 0.0
		local fps = heartbeatData and heartbeatData:GetValue() or 0.0
		local cpu = cpuData and cpuData:GetValue() or 0.0
		local gpu = gpuData and gpuData:GetValue() or 0.0

		local mouse = players.LocalPlayer and players.LocalPlayer:GetMouse()
		local character = players.LocalPlayer and players.LocalPlayer.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local position = humanoidRootPart and humanoidRootPart.Position
		local positionFormat = position and string.format("(%.2f, %.2f, %.2f)", position.X, position.Y, position.Z) or "N/A"

		local str = string.format("%s | %.2fms | %.1f/s | %.1fms | %.1fms", MENU_TITLE, ping, fps, cpu, gpu)

		if Configuration.expectToggleValue("ShowDebugInformation") then
			str = str .. string.format(" | %s", positionFormat)
			str = str .. string.format(" | %s", mouse and mouse.Target and mouse.Target:GetFullName() or "N/A")
		end

		if Watermark and Watermark.SetText then
			Watermark:SetText(str)
		end
	end)))

	local menuUIHidden = false

	menuMaid:add(renderStepped:connect("Menu_HideUIInMenus", LPH_NO_VIRTUALIZE(function()
		local playerGui = players.LocalPlayer and players.LocalPlayer:FindFirstChild("PlayerGui")
		local backpackGui = playerGui and playerGui:FindFirstChild("BackpackGui")
		local leftFrame = backpackGui and backpackGui:FindFirstChild("LeftFrame")
		local inMenu = leftFrame and leftFrame:IsA("GuiObject") and leftFrame.Visible

		if Configuration.expectToggleValue("HideUIInMenus") and inMenu then
			if KeybindList and KeybindList.Instance then KeybindList.Instance.Visible = false end
			if Watermark and Watermark.Instance then Watermark.Instance.Visible = false end
			menuUIHidden = true
			return
		end

		if not menuUIHidden then return end
		menuUIHidden = false
		if KeybindList and KeybindList.Instance and Options.KeybindList then
			KeybindList.Instance.Visible = Options.KeybindList:GetState() or false
		end
		if Watermark and Watermark.Instance and Options.Watermark then
			Watermark.Instance.Visible = Options.Watermark:GetState() or false
		end
	end)))

	local inputBegan = Signal.new(userInputService.InputBegan)

	inputBegan:connect("Menu_InputBegan", function(input, gameProcessed)
		if gameProcessed then return end
		if not Configuration.expectToggleValue("ShowDebugInformation") then return end

		if input.KeyCode == Enum.KeyCode.F8 then
			local mouse = players.LocalPlayer and players.LocalPlayer:GetMouse()
			local target = mouse and mouse.Target
			if not target then return end
			target.Name = tostring(math.random(100000, 1000000))
			return Logger.mnnotify("The target has been renamed to '%s' as a marker.", target.Name)
		end

		if input.KeyCode == Enum.KeyCode.Equals and Library.Recording then
			local Character = players.LocalPlayer and players.LocalPlayer.Character
			local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
			local Position = HumanoidRootPart and HumanoidRootPart.Position
			local PositionFormat = Position and string.format("CFrame.new(%.2f, %.2f, %.2f)", Position.X, Position.Y, Position.Z) or "N/A"
			if Library.PositionList then
				Library.PositionList[#Library.PositionList + 1] = PositionFormat
			end
		end
	end)

	task.spawn(function()
		local function diagTab(n, f)
			local ok, e = pcall(f, Window)
			if not ok then warn("[Aero/diag] " .. n .. ".init FAILED: " .. tostring(e)) end
			task.wait()
		end
		diagTab("TimingBuilderTab", TimingBuilderTab.init)
		diagTab("VisualsTab", VisualsTab.init)
		diagTab("UtilityTab", UtilityTab.init)
		diagTab("AutomationTab", AutomationTab.init)
		diagTab("AeroTab", AeroTab.init)
		diagTab("ConfigTab", ConfigTab.init)
		diagTab("AdminTab", AdminTab.init)

		if Library.ToggleKeybind and Options and Options.MenuKeybind then
			Library.ToggleKeybind = Options.MenuKeybind
		end

		if SaveManager.LoadAutoloadConfig then
			SaveManager:LoadAutoloadConfig()
		elseif SaveManager.LoadAutoload then
			SaveManager:LoadAutoload()
		end

		if not LPH_OBFUSCATED or shared.Aero.verbose then
			Logger.warn("Menu initialized.")
		end
	end)

	local SettingsPage = Library:CreateSettingsPage(Window, KeybindList, Watermark)
end

function Menu.detach()
	menuMaid:clean()
	pcall(Custom.stopAll)
	if TimingBuilderTab.detach then TimingBuilderTab.detach() end
	if Library.Unload then Library:Unload() end
	Logger.warn("Menu detached.")
end

return Menu
