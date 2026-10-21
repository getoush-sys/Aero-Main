-- Builds the sandboxed API a user's custom-feature code runs against. new(hostBody, name) returns
-- { env, destroy }: `env` is the environment to setfenv the user chunk with (API helpers are available
-- as globals AND under the `Aero`/`api` table); `destroy()` tears down every widget, window, connection
-- and loop the feature created. Everything the feature makes is tracked so a reload leaves nothing behind.

---@module GUI.Library
local Library = require("GUI/Library")

---@module Features.Custom.CustomWidgets
local Widgets = require("Features/Custom/CustomWidgets")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Features.Combat.Targeting
local Targeting = require("Features/Combat/Targeting")

---@module Utility.Logger
local Logger = require("Utility/Logger")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CustomAPI = {}

local function normalizeOpts(arg)
	if type(arg) == "function" then
		return { callback = arg }
	end
	if type(arg) == "table" then
		return arg
	end
	return {}
end

---@param hostBody Instance where this feature's widgets are parented
---@param name string
---@return table
function CustomAPI.new(hostBody, name)
	local conns = {}
	local roots = {}
	local cleanupFns = {}
	local intervals = {}
	local destroyed = false

	local function track(control)
		if control and control.conns then
			for _, c in ipairs(control.conns) do
				conns[#conns + 1] = c
			end
		end
		return control
	end

	local function trackConn(c)
		conns[#conns + 1] = c
		return c
	end

	-- Section for this feature inside the host panel; all its root widgets live here.
	local rootSection = Widgets.section(hostBody, name or "Custom Feature")
	roots[#roots + 1] = rootSection.instance

	-- Builds a widget surface bound to a particular parent body (root section, a sub-section, or a window).
	local function buildSurface(parent)
		local surface = {}

		function surface.Label(text)
			return track(Widgets.label(parent, text))
		end

		function surface.Button(text, callback)
			return track(Widgets.button(parent, text, callback))
		end

		function surface.Toggle(text, arg)
			local o = normalizeOpts(arg)
			return track(Widgets.toggle(parent, text, o.default, o.callback))
		end

		function surface.Slider(text, arg)
			local o = normalizeOpts(arg)
			return track(Widgets.slider(parent, text, o.min, o.max, o.default, o.callback, o.decimals))
		end

		function surface.Dropdown(text, arg)
			local o = normalizeOpts(arg)
			return track(Widgets.dropdown(parent, text, o.values, o.default, o.callback))
		end

		function surface.Input(text, arg)
			local o = normalizeOpts(arg)
			return track(Widgets.input(parent, text, o.default, o.callback))
		end

		function surface.Keybind(text, arg)
			local o = normalizeOpts(arg)
			return track(Widgets.keybind(parent, text, o.default, o.callback))
		end

		function surface.Section(title)
			local sec = track(Widgets.section(parent, title))
			return buildSurface(sec.body)
		end

		return surface
	end

	local root = buildSurface(rootSection.body)

	-- Floating, draggable window parented to the menu ScreenGui. Returns a widget surface for its body.
	local function makeWindow(title)
		local gui = Library.ScreenGui
		local outer = Library:Create("Frame", {
			Name = "CustomWindow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(240, 60),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Library.MainColor,
			BorderSizePixel = 0,
			ZIndex = 70,
			Parent = gui,
		})
		Library:Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = outer })
		local os = Library:Create("UIStroke", { Color = Library.AccentColor, Thickness = 1, Transparency = 0.2, Parent = outer })
		Library:AddToRegistry(outer, { BackgroundColor3 = "MainColor" })
		Library:AddToRegistry(os, { Color = "AccentColor" })
		pcall(function() Library:AddUIScale(outer) end)

		local bar = Library:Create("TextLabel", {
			BackgroundColor3 = Library.BackgroundColor,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 24),
			Font = Enum.Font.GothamBold,
			Text = "  " .. tostring(title or "Window"),
			TextSize = 13,
			TextColor3 = Library.FontColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 71,
			Parent = outer,
		})
		Library:Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = bar })
		Library:AddToRegistry(bar, { BackgroundColor3 = "BackgroundColor", TextColor3 = "FontColor" })
		pcall(function() Library:MakeDraggable(outer, 24) end)

		local body = Library:Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(6, 28),
			Size = UDim2.new(1, -12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 71,
			Parent = outer,
		})
		Library:Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = body })
		Library:Create("UIPadding", { PaddingBottom = UDim.new(0, 6), Parent = body })

		roots[#roots + 1] = outer
		return buildSurface(body)
	end

	-- ------------------------------------------------------------ lifecycle + helpers
	local api = {}

	-- widget methods (root surface)
	for k, v in pairs(root) do
		api[k] = v
	end

	function api.Window(title)
		return makeWindow(title)
	end

	function api.OnRender(fn)
		trackConn(RunService.RenderStepped:Connect(function(dt)
			if not destroyed then
				local ok, err = pcall(fn, dt)
				if not ok then
					Logger.notify("[Custom] render error: %s", tostring(err))
				end
			end
		end))
	end

	function api.OnStep(fn)
		trackConn(RunService.Heartbeat:Connect(function(dt)
			if not destroyed then
				pcall(fn, dt)
			end
		end))
	end

	function api.OnInput(fn)
		trackConn(UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not destroyed then
				pcall(fn, input, gameProcessed)
			end
		end))
	end

	function api.Interval(seconds, fn)
		seconds = tonumber(seconds) or 1
		local token = { running = true }
		intervals[#intervals + 1] = token
		task.spawn(function()
			while token.running and not destroyed do
				task.wait(seconds)
				if token.running and not destroyed then
					pcall(fn)
				end
			end
		end)
	end

	function api.OnCleanup(fn)
		cleanupFns[#cleanupFns + 1] = fn
	end

	function api.Notify(text, time)
		pcall(function()
			Library:Notify(tostring(text), time)
		end)
	end

	-- game helpers
	api.LocalPlayer = Players.LocalPlayer
	api.Services = {
		Players = Players,
		RunService = RunService,
		UserInputService = UserInputService,
		Workspace = Workspace,
		ReplicatedStorage = game:GetService("ReplicatedStorage"),
		TweenService = game:GetService("TweenService"),
		VirtualInputManager = nil,
	}

	function api.Character()
		local lp = Players.LocalPlayer
		return lp and lp.Character
	end

	function api.HRP()
		local char = api.Character()
		return char and char:FindFirstChild("HumanoidRootPart")
	end

	function api.Humanoid()
		local char = api.Character()
		return char and char:FindFirstChildOfClass("Humanoid")
	end

	function api.Mouse()
		local lp = Players.LocalPlayer
		return lp and lp:GetMouse()
	end

	function api.Camera()
		return Workspace.CurrentCamera
	end

	-- Current best aim target (Targeting respects the user's targeting config), and the full list.
	function api.GetTarget()
		local ok, list = pcall(Targeting.best)
		if ok and list then
			return list[1]
		end
		return nil
	end

	function api.GetTargets()
		local ok, list = pcall(Targeting.best)
		if ok and list then
			return list
		end
		return {}
	end

	-- Read any existing Aero control value by flag.
	function api.Value(flag)
		local v = Configuration.expectToggleValue(flag)
		if v ~= nil then
			return v
		end
		return Configuration.expectOptionValue(flag)
	end

	api.Toggles = getgenv().Toggles
	api.Options = getgenv().Options
	api.Library = Library

	-- ------------------------------------------------------------ sandbox env
	local base = getfenv(1)
	local gg = getgenv and getgenv() or nil
	local backing = {}
	local env = setmetatable(backing, {
		__index = function(_, key)
			local a = api[key]
			if a ~= nil then
				return a
			end
			local b = base[key]
			if b ~= nil then
				return b
			end
			if gg then
				return gg[key]
			end
			return nil
		end,
		__newindex = function(t, key, value)
			rawset(t, key, value)
		end,
	})
	-- Expose the whole surface as a table too, for users who prefer `Aero.Toggle(...)`.
	backing.Aero = api
	backing.api = api

	local function destroy()
		if destroyed then
			return
		end
		destroyed = true
		for _, token in ipairs(intervals) do
			token.running = false
		end
		for _, c in ipairs(conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		for _, fn in ipairs(cleanupFns) do
			pcall(fn)
		end
		for _, inst in ipairs(roots) do
			pcall(function()
				inst:Destroy()
			end)
		end
	end

	return { env = env, destroy = destroy, api = api }
end

return CustomAPI
