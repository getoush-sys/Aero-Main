return LPH_NO_VIRTUALIZE(function()
-- Animation Inspector -- a live window listing every animation a selected player is CURRENTLY playing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

---@module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")
---@module GUI.Library
local Library = require("GUI/Library")
---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

local AnimationInspector = {}

-- Theme (pulled from the Aero Library so the window matches the menu).
local ACCENT  = Library.AccentColor     or Color3.fromRGB(243, 168, 214)
local MAIN    = Library.MainColor       or Color3.fromRGB(40, 32, 50)
local BG      = Library.BackgroundColor or Color3.fromRGB(28, 22, 36)
local FG      = Library.FontColor       or Color3.fromRGB(245, 238, 250)
local OUTLINE = Library.OutlineColor    or Color3.fromRGB(110, 86, 132)
local RISK    = Library.RiskColor       or Color3.fromRGB(255, 96, 128)
local MUTED   = Color3.fromRGB(168, 156, 182)

local MAX_ROWS = 100         -- hard cap so an AP-break flood can't spawn thousands
local UPDATE_INTERVAL = 0.06 -- ~16 Hz live-prop refresh
local LOG_FILE = "luma_animlog.txt"
local LOG_FLUSH_INTERVAL = 1.0

-- State
local running = false
local targetPlayer = nil
local targetName = nil

local screenGui, mainFrame, titleLabel, subLabel, listFrame, emptyLabel

local rows = {}          -- track -> { frame, nameLabel, propLabel, assetId, stoppedConn }
local rowCount = 0

local animatorConn = nil
local charAddedConn = nil
local charRemovingConn = nil
local updateConn = nil
local updateAccum = 0

-- Namecall-hook capture (fade time isn't exposed on AnimationTrack any other way).
local playArgs = setmetatable({}, { __mode = "k" })
local hookActive = false
local oldNamecall = nil

-- Asset-name resolution.
local nameCache = {}     -- assetId -> name | false
local namePending = {}
local nameQueue = {}
local resolverRunning = false

-- File logging (name / id / priority and any changes to them).
local logBuffer = {}
local logFlushAccum = 0
local logSessionStart = 0

-- Small helpers
local function mk(class, props, parent)
	local inst = Instance.new(class)
	for key, value in pairs(props) do
		inst[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function fmtNum(value, digits)
	if type(value) ~= "number" then
		return "?"
	end
	return string.format("%." .. (digits or 2) .. "f", value)
end

local function safeGet(fn, fallback)
	local ok, value = pcall(fn)
	if ok and value ~= nil then
		return value
	end
	return fallback
end

-- The real asset behind an AnimationId.
local function assetIdOf(animationId)
	local text = tostring(animationId or "")
	local viaQuery = text:match("[?&]id=(%d+)")
	if viaQuery then
		return tonumber(viaQuery)
	end
	return tonumber(text:match("(%d+)"))
end

-- Query junk (a `?` AND an `&`) beyond a plain asset reference = id-spoof tell.
local function isMutatedId(animationId)
	local text = tostring(animationId or "")
	return text:find("?", 1, true) ~= nil and text:find("&", 1, true) ~= nil
end

local function lookupName(assetId)
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
	end)
	local resolved = (ok and info and info.Name) or false
	nameCache[assetId] = resolved
	namePending[assetId] = nil
	return resolved
end

local function queueName(assetId)
	if not assetId or nameCache[assetId] ~= nil or namePending[assetId] then
		return
	end
	namePending[assetId] = true
	nameQueue[#nameQueue + 1] = assetId
end

-- One background worker chews through lookups (GetProductInfo yields + rate-limits).
local function startResolver()
	if resolverRunning then
		return
	end
	resolverRunning = true
	task.spawn(function()
		while running do
			local assetId = table.remove(nameQueue, 1)
			if assetId then
				lookupName(assetId)
				task.wait(0.3)
			else
				task.wait(0.25)
			end
		end
		resolverRunning = false
	end)
end

-- GUI parenting (exploit-safe: gethui -> CoreGui -> PlayerGui)
local function guiParent()
	local ok, hui = pcall(function()
		return gethui and gethui()
	end)
	if ok and hui then
		return hui
	end
	local ok2, cg = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok2 and cg then
		return cg
	end
	local lp = Players.LocalPlayer
	return lp and lp:FindFirstChildOfClass("PlayerGui")
end

-- Window
local function buildWindow()
	if screenGui then
		return
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LumaAnimInspect"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 9999
	CoreGuiManager.imark(screenGui)

	local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end
	pcall(ProtectGui, screenGui)
	screenGui.Parent = guiParent()

	mainFrame = mk("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(360, 420),
		Position = UDim2.fromOffset(120, 120),
		BackgroundColor3 = BG,
		BorderSizePixel = 0,
	}, screenGui)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, mainFrame)
	mk("UIStroke", { Color = OUTLINE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, mainFrame)

	-- Title bar.
	local titleBar = mk("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = MAIN,
		BorderSizePixel = 0,
	}, mainFrame)
	mk("UICorner", { CornerRadius = UDim.new(0, 6) }, titleBar)
	-- Square off the bottom corners of the title bar.
	mk("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.new(0, 0, 1, -8),
		BackgroundColor3 = MAIN,
		BorderSizePixel = 0,
	}, titleBar)

	local accentBar = mk("Frame", {
		Size = UDim2.new(0, 3, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
	}, titleBar)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, accentBar)

	titleLabel = mk("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 3),
		Size = UDim2.new(1, -54, 0, 16),
		Font = Enum.Font.GothamBold,
		Text = "Animation Inspector",
		TextColor3 = FG,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, titleBar)

	subLabel = mk("TextLabel", {
		Name = "Sub",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.new(1, -54, 0, 13),
		Font = Enum.Font.Gotham,
		Text = "no target",
		TextColor3 = MUTED,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, titleBar)

	local closeBtn = mk("TextButton", {
		Name = "Close",
		BackgroundColor3 = MAIN,
		Position = UDim2.new(1, -28, 0, 6),
		Size = UDim2.fromOffset(22, 22),
		Font = Enum.Font.GothamBold,
		Text = "X",
		TextColor3 = RISK,
		TextSize = 13,
		AutoButtonColor = true,
	}, titleBar)
	mk("UICorner", { CornerRadius = UDim.new(0, 4) }, closeBtn)
	closeBtn.MouseButton1Click:Connect(function()
		-- Flip the menu toggle off; its OnChanged calls stop().
		local ok = pcall(function()
			local toggles = getgenv and getgenv().Toggles
			if toggles and toggles.AnimationInspector then
				toggles.AnimationInspector:SetValue(false)
				return true
			end
			return false
		end)
		if not ok then
			AnimationInspector.stop()
		end
	end)

	-- Scrolling list of live rows.
	listFrame = mk("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(6, 40),
		Size = UDim2.new(1, -12, 1, -46),
		BackgroundColor3 = MAIN,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = ACCENT,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, mainFrame)
	mk("UICorner", { CornerRadius = UDim.new(0, 4) }, listFrame)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	}, listFrame)
	mk("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	}, listFrame)

	emptyLabel = mk("TextLabel", {
		Name = "Empty",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.Gotham,
		Text = "no animations playing",
		TextColor3 = MUTED,
		TextSize = 12,
	}, listFrame)

	pcall(function()
		Library:MakeDraggable(mainFrame, 34)
	end)
end

-- Rows
local function updateEmptyState()
	if emptyLabel then
		emptyLabel.Visible = rowCount == 0
	end
	if subLabel then
		local who = targetName or "no target"
		subLabel.Text = string.format("%s  ·  %d playing", who, rowCount)
	end
end

-- File logging -- name / id / priority, and any change to them, appended to a txt in the executor's workspace folder for later reading.
local function loggingEnabled()
	return Configuration.expectToggleValue("AnimInspectLogToFile") == true
end

local function writeLog(text)
	pcall(function()
		if appendfile then
			appendfile(LOG_FILE, text)
		elseif writefile and readfile and isfile then
			local existing = isfile(LOG_FILE) and readfile(LOG_FILE) or ""
			if #existing < 5 * 1024 * 1024 then
				writefile(LOG_FILE, existing .. text)
			end
		end
	end)
end

local function flushLog()
	if #logBuffer == 0 then
		return
	end
	local text = table.concat(logBuffer, "\n") .. "\n"
	logBuffer = {}
	writeLog(text)
end

local function logLine(text)
	if not loggingEnabled() then
		return
	end
	logBuffer[#logBuffer + 1] = string.format("[%8.2f] %s", os.clock() - logSessionStart, text)
	if #logBuffer >= 400 then
		flushLog()
	end
end

local function updateRow(row)
	local track = row.track
	local anim = safeGet(function() return track.Animation end)
	local animationId = anim and tostring(anim.AnimationId) or nil
	local mutated = isMutatedId(animationId)

	local assetId = row.assetId
	local resolved = assetId and nameCache[assetId] or nil
	local displayName = resolved or (anim and anim.Name ~= "" and anim.Name) or "?"
	if displayName == "Animation" and assetId then
		displayName = "id:" .. tostring(assetId)
	end

	local priorityName = tostring(safeGet(function() return track.Priority.Name end, "?"))

	row.nameLabel.Text = string.format("%s   ·   %s", displayName, priorityName)
	row.nameLabel.TextColor3 = mutated and RISK or FG

	local args = playArgs[track]
	local fade = args and fmtNum(args.fade) or "?"

	row.propLabel.Text = string.format(
		"spd %s · wt %s/%s · len %s · t %s · fade %s%s",
		fmtNum(safeGet(function() return track.Speed end)),
		fmtNum(safeGet(function() return track.WeightCurrent end)),
		fmtNum(safeGet(function() return track.WeightTarget end)),
		fmtNum(safeGet(function() return track.Length end)),
		fmtNum(safeGet(function() return track.TimePosition end)),
		fade,
		mutated and "  · MUTATED" or ""
	)

	row.idLabel.Text = "id " .. (animationId or "?")
	row.idLabel.TextColor3 = mutated and RISK or ACCENT

	-- Peak WeightCurrent across this track's life. WeightCurrent is ~0 for EVERY
	-- animation the instant it starts (they all ramp up from 0), so a single play-time
	-- read tells you nothing -- the tell for a 0-weight flood bait is that it NEVER
	-- ramps. Sample the peak here every update and log it on stop.
	row.peakWC = math.max(row.peakWC or 0, safeGet(function() return track.WeightCurrent end, 0) or 0)

	-- File log: one line on first sight, then any change to name / id / priority.
	local idStr = animationId or "?"
	if row.loggedId == nil then
		row.loggedName = displayName
		row.loggedId = idStr
		row.loggedPriority = priorityName
		logLine(string.format('[+] name="%s" id=%s priority=%s wt=%s spd=%s', displayName, idStr, priorityName,
			fmtNum(safeGet(function() return track.WeightTarget end)),
			fmtNum(safeGet(function() return track.Speed end))))
	else
		if idStr ~= row.loggedId then
			logLine(string.format("[~] id=%s  id: %s -> %s", row.loggedId, row.loggedId, idStr))
			row.loggedId = idStr
		end
		if displayName ~= row.loggedName then
			logLine(string.format('[~] id=%s  name: "%s" -> "%s"', row.loggedId, row.loggedName, displayName))
			row.loggedName = displayName
		end
		if priorityName ~= row.loggedPriority then
			logLine(string.format("[~] id=%s  priority: %s -> %s", row.loggedId, row.loggedPriority, priorityName))
			row.loggedPriority = priorityName
		end
	end
end

local function removeRow(track)
	local row = rows[track]
	if not row then
		return
	end
	if row.loggedId then
		logLine(string.format("[-] id=%s  (stopped) peakwc=%s", row.loggedId, fmtNum(row.peakWC or 0)))
	end
	rows[track] = nil
	rowCount = rowCount - 1
	if row.stoppedConn then
		pcall(function() row.stoppedConn:Disconnect() end)
	end
	if row.frame then
		row.frame:Destroy()
	end
	updateEmptyState()
end

local function addRow(track)
	if rows[track] or rowCount >= MAX_ROWS or not listFrame then
		return
	end

	local frame = mk("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = BG,
		BorderSizePixel = 0,
	}, listFrame)
	mk("UICorner", { CornerRadius = UDim.new(0, 4) }, frame)
	mk("UIStroke", { Color = OUTLINE, Thickness = 1, Transparency = 0.4 }, frame)

	local nameLabel = mk("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -12, 0, 15),
		Font = Enum.Font.GothamSemibold,
		Text = "...",
		TextColor3 = FG,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, frame)

	local propLabel = mk("TextLabel", {
		Name = "Props",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 20),
		Size = UDim2.new(1, -12, 0, 14),
		Font = Enum.Font.Code,
		Text = "",
		TextColor3 = MUTED,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, frame)

	local idLabel = mk("TextLabel", {
		Name = "Id",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 35),
		Size = UDim2.new(1, -12, 0, 13),
		Font = Enum.Font.Code,
		Text = "",
		TextColor3 = ACCENT,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, frame)

	local anim = safeGet(function() return track.Animation end)
	local assetId = anim and assetIdOf(anim.AnimationId) or nil
	queueName(assetId)

	local row = { frame = frame, nameLabel = nameLabel, propLabel = propLabel, idLabel = idLabel, assetId = assetId, track = track }
	rows[track] = row
	rowCount = rowCount + 1

	-- DELETE the row the instant the animation ends.
	row.stoppedConn = track.Stopped:Connect(function()
		removeRow(track)
	end)

	updateRow(row)
	updateEmptyState()
end

local function clearRows()
	for track in pairs(rows) do
		removeRow(track)
	end
	rowCount = 0
	rows = {}
	updateEmptyState()
end

-- Live refresh loop: repaints visible rows and prunes tracks that stopped without firing .Stopped.
local function startUpdateLoop()
	if updateConn then
		return
	end
	updateConn = RunService.RenderStepped:Connect(function(dt)
		if not running then
			return
		end
		updateAccum = updateAccum + dt
		if updateAccum < UPDATE_INTERVAL then
			return
		end
		updateAccum = 0

		local dead = nil
		for track, row in pairs(rows) do
			if not safeGet(function() return track.IsPlaying end, false) then
				dead = dead or {}
				dead[#dead + 1] = track
			else
				updateRow(row)
			end
		end
		if dead then
			for _, track in ipairs(dead) do
				removeRow(track)
			end
		end

		logFlushAccum = logFlushAccum + UPDATE_INTERVAL
		if logFlushAccum >= LOG_FLUSH_INTERVAL then
			logFlushAccum = 0
			flushLog()
		end
	end)
end

-- Parallel-hook guard (see Game/Hooking.lua): on executors without parallel_hooks_allowed, install via a
-- read-only metatable swap so this __namecall hook can't be dispatched from an Actor parallel phase, which
-- is an illegal cross-phase op the engine Kernel panics on (RSL - panic: ...Kernel).
local parallelHooksAllowed = parallel_hooks_allowed
local hookmetamethod = (not parallelHooksAllowed)
	and function(target, method, hook)
		local metatable = getrawmetatable(target)
		setreadonly(metatable, false)
		local original = metatable[method]
		metatable[method] = hook
		setreadonly(metatable, true)
		return original
	end
	or hookmetamethod

-- Namecall hook -- capture the caller's Play(fade, weight, speed) args.
local function installHook()
	if hookActive then
		return
	end
	if not (hookmetamethod and getnamecallmethod and checkcaller) then
		return -- fade time simply stays "?" without exploit hook support
	end
	local ok = pcall(function()
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			-- NOTE: deliberately NOT skipping checkcaller() calls.
			if not hookActive then
				return oldNamecall(self, ...)
			end
			if getnamecallmethod() == "Play" then
				local okClass, isTrack = pcall(game.IsA, self, "AnimationTrack")
				if okClass and isTrack then
					local a, b, c = ...
					playArgs[self] = {
						fade = type(a) == "number" and a or 0.1,
						weight = type(b) == "number" and b or 1,
						speed = type(c) == "number" and c or 1,
					}
				end
			end
			return oldNamecall(self, ...)
		end)
	end)
	hookActive = ok
end

local function removeHook()
	if not hookActive then
		return
	end
	hookActive = false
	if oldNamecall and hookmetamethod then
		pcall(function()
			hookmetamethod(game, "__namecall", oldNamecall)
		end)
		oldNamecall = nil
	end
end

-- Target binding
local function bindAnimator(animator, character)
	if animatorConn then
		pcall(function() animatorConn:Disconnect() end)
		animatorConn = nil
	end
	if not animator then
		return
	end

	animatorConn = animator.AnimationPlayed:Connect(function(track)
		if running then
			addRow(track)
		end
	end)

	-- Seed with whatever is already playing.
	for _, track in ipairs(safeGet(function() return animator:GetPlayingAnimationTracks() end, {})) do
		addRow(track)
	end
end

local function hookCharacter(character)
	clearRows()
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		bindAnimator(animator, character)
		return
	end
	-- Character just spawned; its Animator may not exist yet.
	task.spawn(function()
		local hum = character:WaitForChild("Humanoid", 5)
		local anim = hum and hum:WaitForChild("Animator", 5)
		if anim and running and targetPlayer and targetPlayer.Character == character then
			bindAnimator(anim, character)
		end
	end)
end

local function bindPlayer(player)
	if charAddedConn then
		pcall(function() charAddedConn:Disconnect() end)
		charAddedConn = nil
	end
	if charRemovingConn then
		pcall(function() charRemovingConn:Disconnect() end)
		charRemovingConn = nil
	end

	targetPlayer = player
	targetName = player and player.Name or nil

	if titleLabel then
		titleLabel.Text = player and ("Animation Inspector — " .. player.Name) or "Animation Inspector"
	end
	updateEmptyState()

	if not player then
		clearRows()
		return
	end

	charAddedConn = player.CharacterAdded:Connect(function(character)
		if running and targetPlayer == player then
			hookCharacter(character)
		end
	end)
	charRemovingConn = player.CharacterRemoving:Connect(function()
		if running and targetPlayer == player then
			clearRows()
		end
	end)

	hookCharacter(player.Character)
end

local function resolveByName(name)
	if not name or name == "" then
		return nil
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name == name then
			return p
		end
	end
	local lower = string.lower(name)
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
			return p
		end
	end
	return nil
end

-- Public API
function AnimationInspector.startByName(name)
	local player = resolveByName(name)
	if not player then
		pcall(function()
			Library:Notify("Animation Inspector: pick a player first.", 4)
		end)
		pcall(function()
			local toggles = getgenv and getgenv().Toggles
			if toggles and toggles.AnimationInspector then
				toggles.AnimationInspector:SetValue(false)
			end
		end)
		return
	end

	running = true
	if loggingEnabled() then
		logBuffer = {}
		logFlushAccum = 0
		logSessionStart = os.clock()
		pcall(function()
			if writefile then
				writefile(LOG_FILE, string.format(
					"=== Animation Inspector log | target=%s | %s ===\n",
					player.Name, os.date("%Y-%m-%d %H:%M:%S")
				))
			end
		end)
	end
	buildWindow()
	if screenGui then
		screenGui.Enabled = true
	end
	installHook()
	startResolver()
	startUpdateLoop()
	bindPlayer(player)
end

function AnimationInspector.setTargetByName(name)
	if not running then
		return
	end
	local player = resolveByName(name)
	if player then
		bindPlayer(player)
	end
end

function AnimationInspector.stop()
	if not running then
		return
	end
	running = false

	if updateConn then
		pcall(function() updateConn:Disconnect() end)
		updateConn = nil
	end
	if animatorConn then
		pcall(function() animatorConn:Disconnect() end)
		animatorConn = nil
	end
	if charAddedConn then
		pcall(function() charAddedConn:Disconnect() end)
		charAddedConn = nil
	end
	if charRemovingConn then
		pcall(function() charRemovingConn:Disconnect() end)
		charRemovingConn = nil
	end

	clearRows()
	removeHook()
	flushLog()

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
		mainFrame, titleLabel, subLabel, listFrame, emptyLabel = nil, nil, nil, nil, nil
	end

	targetPlayer = nil
	targetName = nil
end

-- Full teardown (script detach): tear everything down for good.
function AnimationInspector.detach()
	AnimationInspector.stop()
end

return AnimationInspector
end)()
