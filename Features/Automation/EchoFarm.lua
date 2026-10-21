-- EchoFarm (Titus): a Aero port of project-rain-oss's `titus_echofarm.lua`, built on the ported
-- AutomationStruct + StateMachine framework. Constructs a struct with PR's echo feature set and drives the
-- same state machine: create character -> enter the Titus dungeon -> break Titus (mob_ai_breaker) -> loot
-- the chest -> enchant -> wipe -> cash the run's echoes in at Fragments of Self -> repeat.
--
-- Public surface kept identical for Aero's menu + resume wiring:
--   EchoFarm.invoke() -- menu Start (bootstraps efdata, then start)
--   EchoFarm.start()  -- resume entry (Aero.lua calls this when efdata survives a hop/teleport)
--   EchoFarm.stop()   -- menu Stop
-- Persistence key: "efdata" { slot, startedAt, echoes, cycles }.
local EchoFarm = {}

-- Set true ONLY while we're flinging the chaser into the void. The pre-wired hooks in Exploits
-- (Fling on the chaser) and OwnershipWatcher (own the chaser instead of dropping it) read this
-- field, so it must live on the module table, not a local.
EchoFarm.voiding = false

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")

---@module Game.Wipe
local Wipe = require("Game/Wipe")

---@module Features.Game.Tweening
local Tweening = require("Features/Game/Tweening")

---@module Utility.Prompt
local Prompt = require("Utility/Prompt")

---@module Features.Automation.AutoLoot
local AutoLoot = require("Features/Automation/AutoLoot")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module GUI.Library
local Library = require("GUI/Library")

---@module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Game.AntiAFK
local AntiAFK = require("Game/AntiAFK")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Features.Automation.Objects.StateMachine
local StateMachine = require("Features/Automation/Objects/StateMachine")

---@module Features.Automation.Objects.AutomationStruct
local AutomationStruct = require("Features/Automation/Objects/AutomationStruct")

---@module Features.Automation.Objects.AutoLog
local AutoLog = require("Features/Automation/Objects/AutoLog")

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local EASTERN_PLACE_ID = 6473861193 -- Fort Merit hub (dungeon entered from here).
local DUNGEON_PLACE_ID = 8668476218 -- The Titus (Detainment) dungeon.
local LOBBY_PLACE_ID = 4111023553
local DEPTHS_PLACE_ID = 5735553160
local CHIME_LOBBY_PLACE_ID = 12559711136

local MOVE_ID = "EchoFarm_Move"
local ENTRANCE = CFrame.new(-6875.86, 336.2, 2827.95)
local ENTRANCE_SPEED = 40
local PLAYER_SAFE_RADIUS = 200
local APPROACH_Y = 288
local ATTACH_DISTANCE = 35

local running = false
local struct = nil
local maid = Maid.new()
local getScoreConn = nil -- persistent GetScore.OnClientEvent listener (echo counting).
local actionStartedAt = 0 -- os.clock() when the current stage began (0 = disarmed); per-action watchdog.
local ACTION_TIMEOUT = 60 -- if a single stage stalls longer than this, wipe to reset the whole cycle.
local VOID_TIMEOUT = 45 -- shorter cap for the Titus voiding phase ("fighting titus") specifically.
local currentActionTimeout = ACTION_TIMEOUT -- active timeout for the current stage (set per-stage in setStage).

local screenGui, stageLabel, echoLabel, timeLabel, epmLabel = nil, nil, nil, nil, nil

-- =========================================================================================================
-- Local-player accessors.
-- =========================================================================================================
local function localPlayer()
	return players.LocalPlayer
end

local function character()
	local lp = localPlayer()
	return lp and lp.Character
end

local function root()
	local c = character()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
	local c = character()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function playerGui()
	local lp = localPlayer()
	return lp and lp:FindFirstChildOfClass("PlayerGui")
end

local function currentSlot()
	local lp = localPlayer()
	return lp and lp:GetAttribute("DataSlot")
end

local function currentArea()
	local lp = localPlayer()
	return lp and lp:GetAttribute("CurrentArea")
end

local function isRunning()
	return running
end

-- =========================================================================================================
-- Overlay.
-- =========================================================================================================
local function guiParent()
	return (gethui and gethui()) or game:GetService("CoreGui")
end

local function mk(class, props, parent)
	local instance = Instance.new(class)
	for key, value in pairs(props) do
		instance[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function buildOverlay()
	if screenGui then
		return
	end

	screenGui = CoreGuiManager.imark(Instance.new("ScreenGui"))
	screenGui.Name = "LumaEchoFarmOverlay"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.DisplayOrder = 9999

	local protectGui = protectgui or (syn and syn.protect_gui) or function() end
	pcall(protectGui, screenGui)
	screenGui.Parent = guiParent()

	local outer = mk("Frame", {
		Name = "Outer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.new(0, 320, 0, 130),
		BackgroundColor3 = Library.MainColor,
		BorderColor3 = Library.OutlineColor,
		BorderSizePixel = 1,
		ZIndex = 200,
	}, screenGui)
	Library:AddToRegistry(outer, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" })

	local efMode = (PersistentData.get("efdata") and PersistentData.get("efdata").mode) or "Titus"
	local title = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 6),
		Size = UDim2.new(1, -16, 0, 20),
		FontFace = Library.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Library.AccentColor,
		Text = (efMode == "Layer2") and "Layer 2 Echo Farm" or "Titus Echo Farm",
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(title, { TextColor3 = "AccentColor" })

	local function statLabel(y, text)
		local label = mk("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 0, y),
			Size = UDim2.new(1, -16, 0, 16),
			FontFace = Library.Font,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Library.FontColor or Color3.new(1, 1, 1),
			Text = text,
			ZIndex = 201,
		}, outer)
		Library:AddToRegistry(label, { TextColor3 = "FontColor" })
		return label
	end

	echoLabel = statLabel(30, "Echoes: 0")
	timeLabel = statLabel(50, "Elapsed: 0s")
	epmLabel = statLabel(70, "Echoes/min: 0.00")

	local stopButton = mk("TextButton", {
		Position = UDim2.new(0, 8, 1, -30),
		Size = UDim2.new(1, -16, 0, 22),
		AutoButtonColor = true,
		BackgroundColor3 = Library:GetDarkerColor(Library.MainColor),
		BorderColor3 = Library.OutlineColor,
		BorderSizePixel = 1,
		FontFace = Library.Font,
		TextSize = 15,
		TextColor3 = Library.FontColor or Color3.new(1, 1, 1),
		Text = "Stop",
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(stopButton, {
		BackgroundColor3 = function()
			return Library:GetDarkerColor(Library.MainColor)
		end,
		BorderColor3 = "OutlineColor",
		TextColor3 = "FontColor",
	})
	stopButton.MouseButton1Click:Connect(function()
		EchoFarm.stop()
	end)

	pcall(function()
		Library:MakeDraggable(outer)
	end)
end

local function destroyOverlay()
	if screenGui then
		pcall(function()
			screenGui:Destroy()
		end)
		screenGui = nil
	end
	stageLabel, echoLabel, timeLabel, epmLabel = nil, nil, nil, nil
end

local function setStage(name)
	-- Re-arm the per-action watchdog on every stage change. The Titus voiding phase gets a shorter cap.
	actionStartedAt = os.clock()
	currentActionTimeout = (name == "fighting titus") and VOID_TIMEOUT or ACTION_TIMEOUT
	if stageLabel then
		stageLabel.Text = "Stage: " .. tostring(name)
	end
end

local function formatDuration(seconds)
	seconds = math.floor(seconds)
	if seconds < 60 then
		return seconds .. "s"
	end
	local minutes = math.floor(seconds / 60)
	if seconds < 3600 then
		return minutes .. "m " .. (seconds % 60) .. "s"
	end
	return math.floor(minutes / 60) .. "h " .. (minutes % 60) .. "m"
end

---Connect a PERSISTENT GetScore.OnClientEvent listener: whenever the server pushes the run score, fold its
---.Echoes into efdata. Idempotent. This is what actually counts echoes -- the fragments wipe itself is
---handled by Aero's Wipe module (which bypasses our state machine), so counting can't live only there.
local function connectScoreListener()
	if getScoreConn then
		return
	end
	pcall(function()
		local remote = replicatedStorage:WaitForChild("Requests"):WaitForChild("GetScore")
		getScoreConn = remote.OnClientEvent:Connect(function(v)
			local gained = (typeof(v) == "table" and tonumber(v.Echoes)) or 0
			if gained and gained > 0 then
				local data = PersistentData.get("efdata")
				if data then
					PersistentData.stf("efdata", "echoes", (data.echoes or 0) + gained)
				end
			end
		end)
		maid:mark(getScoreConn)
	end)
end

---End of a cycle: bump the cycle count and request the run score ONCE (the persistent listener folds the
---returned .Echoes into the total). A single fire so we don't double-count the same run.
local function recordCycle()
	local data = PersistentData.get("efdata")
	if data then
		PersistentData.stf("efdata", "cycles", (data.cycles or 0) + 1)
	end
	connectScoreListener()
	pcall(function()
		replicatedStorage:WaitForChild("Requests"):WaitForChild("GetScore"):FireServer()
	end)
end

local function runStats()
	while running do
		-- Keep No Fall Damage forced on for the entire farm (respawns / new characters can drop it).
		if Toggles and Toggles.NoFallDamage and not Toggles.NoFallDamage.Value then
			Toggles.NoFallDamage:SetValue(true)
		end

		local data = PersistentData.get("efdata")
		if data then
			local startedAt = data.startedAt or os.time()
			local elapsed = math.max(0, os.time() - startedAt)
			local echoes = data.echoes or 0
			if echoLabel then
				echoLabel.Text = "Echoes: " .. echoes
			end
			if timeLabel then
				timeLabel.Text = "Elapsed: " .. formatDuration(elapsed)
			end
			if epmLabel then
				epmLabel.Text = string.format("Echoes/min: %.2f", echoes / math.max(1 / 60, elapsed / 60))
			end
		end
		task.wait(0.25)
	end
end

---Per-action watchdog: if a single stage stalls longer than ACTION_TIMEOUT, run the wipe loop to reset the
---whole cycle from a fresh character (Aero's resume brings us back in afterward).
local function runActionWatchdog()
	while running do
		if actionStartedAt > 0 and os.clock() - actionStartedAt > currentActionTimeout then
			actionStartedAt = 0 -- disarm so we only fire once
			-- Titus voiding stage ("fighting titus" is the only stage on VOID_TIMEOUT): do NOT wipe --
			-- wiping nukes the character + the run's echoes. Server-hop to rejoin a fresh server instead
			-- (Aero's resume re-enters and continues), matching the relic farm. Every other stage wipes.
			if currentActionTimeout == VOID_TIMEOUT then
				-- Rejoin instead of wiping. Resolve the slot with the efdata fallback (same as the wipe
				-- path): in the dungeon the live DataSlot attribute is often missing, and serverHop() /
				-- ServerHop.hop no-ops on a nil slot -- which made the timeout look like it did nothing.
				local data = PersistentData.get("efdata")
				local slot = currentSlot() or (data and data.slot)
				setStage("titus voiding timed out -- rejoining")
				pcall(function()
					ServerHop.hop(slot, true)
				end)
				return
			end
			local data = PersistentData.get("efdata")
			local slot = currentSlot() or (data and data.slot)
			if slot then
				setStage("action timed out -- wiping")
				pcall(function()
					Wipe.invoke(slot)
				end)
			end
			return
		end
		task.wait(0.25)
	end
end

-- =========================================================================================================
-- Movement primitives (ported from PR's autotitus table).
-- =========================================================================================================
local function setSpeed(value, force)
	-- Normally the per-automation Tween Speed slider wins; `force` lets a specific move (the dungeon-door
	-- travel) pin an exact speed regardless of the slider.
	if not force then
		value = (Options and Options.EchoFarmTweenSpeed and Options.EchoFarmTweenSpeed.Value) or 100
	end
	if Options and Options.TweenStudsPerSecond and Options.TweenStudsPerSecond.Value ~= value then
		Options.TweenStudsPerSecond:SetValue(value)
	end
end

---Blocking tween to a CFrame at `speed` (PR's Tween.new(cf, true, speed).wait()).
---When `force` is set (the dungeon-door travel), step the root toward the goal at an EXACT studs/second
---ourselves instead of going through the shared Tween Speed slider. That slider is clamped (Min) and shared
---across every automation, so it can't reliably pin a slow speed -- this keeps the door approach at the
---speed we actually ask for (e.g. 10 studs/s) no matter what the slider says.
local function tempTween(cframe, speed, force)
	if force then
		Tweening.stop(MOVE_ID) -- make sure the engine isn't also driving us toward a stale goal
		local targetPos = cframe.Position
		local studsPerSecond = speed or 150
		local dt = task.wait()
		while running do
			local r = root()
			if not r then
				return
			end
			r.AssemblyLinearVelocity = Vector3.zero
			local pos = r.Position
			local toTarget = targetPos - pos
			local dist = toTarget.Magnitude
			if dist <= 1 then
				break
			end
			local stepDist = studsPerSecond * dt
			if stepDist >= dist then
				r.CFrame = CFrame.new(targetPos)
				break
			end
			r.CFrame = CFrame.new(pos + (toTarget / dist) * stepDist)
			dt = task.wait()
		end
		return
	end

	setSpeed(speed or 150, force)
	Tweening.goal(MOVE_ID, cframe, false)
	local goalPos = cframe.Position
	while running do
		local r = root()
		if r and (r.Position - goalPos).Magnitude <= 10 then
			break
		end
		task.wait()
	end
	Tweening.stop(MOVE_ID)
end

---True if another player is within `mag` of `position` (defaults to our root).
local function playerCheck(mag, position)
	local origin = position or (root() and root().Position)
	if not origin then
		return false
	end
	for _, other in next, players:GetPlayers() do
		if other == localPlayer() or not other.Character then
			continue
		end
		local hrp = other.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (origin - hrp.Position).Magnitude <= mag then
			return true
		end
	end
	return false
end

local function serverHop()
	-- currentSlot() reads the live DataSlot attribute, which is often absent inside dungeons (e.g. the
	-- Titus dungeon); fall back to the farm's persisted slot so the hop resolves a real save slot instead
	-- of no-opping on nil. Makes every hop -- auto-log, exit hop, the voiding rejoin -- work in the dungeon.
	local data = PersistentData.get("efdata")
	local slot = currentSlot() or (data and data.slot)
	pcall(function()
		ServerHop.hop(slot, true)
	end)
end

-- Player-proximity "auto log" hop, gated by the per-automation auto-log distance (echo_farm slider). 0 = off,
-- so NOTHING in the farm hops on nearby players -- including the Fragments of Self cash-in.
local function shouldLogHop(position)
	local dist = AutoLog.get("echo_farm")
	if dist <= 0 then
		return false
	end
	return playerCheck(dist, position)
end

---Player-safe tween: hop away if anyone is near us/the target, else fly there at altitude and snap down
---(matches Auto Titus -- travel high above the map so nothing along the way can interrupt us).
---@param groundLevel boolean? when true, travel at ground level (no altitude lift) instead of high up.
local function playerSafeTween(cf, speed, groundLevel, force)
	if shouldLogHop() then
		serverHop()
		while task.wait() do
		end
		return
	end
	local r = root()
	if not r then
		return
	end
	if groundLevel then
		-- Match the dungeon door's Y: snap to the target's height, then tween horizontally across to it at
		-- that same Y level (no altitude lift).
		r.CFrame = CFrame.new(r.Position.X, cf.Position.Y, r.Position.Z)
		tempTween(cf, speed, force)
	else
		local y = math.random(8000, 10000)
		r.CFrame = r.CFrame + Vector3.new(0, y, 0)
		tempTween(cf + Vector3.new(0, y, 0), speed, force)
	end
	if shouldLogHop(cf.Position) then
		serverHop()
		while task.wait() do
		end
		return
	end
	r = root()
	if r then
		r.CFrame = cf
	end
end

-- =========================================================================================================
-- Dungeon flow (ported from PR titus_echofarm).
-- =========================================================================================================
local function enterDungeon()
	setStage("enter dungeon")
	-- Force noclip on for the trip to the dungeon door so geometry can't snag us on the way in.
	pcall(function()
		if Toggles and Toggles.NoClip then
			Toggles.NoClip:SetValue(true)
		end
	end)
	pcall(function()
		replicatedStorage.Requests.UpdateUXSettings:FireServer("FriendlyFire", true)
	end)

	-- Keep noclip enforced for the WHOLE trip to the door (not just once we're there): re-assert the NoClip
	-- toggle and brute-force every character part CanCollide=false each frame while we travel, so geometry
	-- can't snag us on the way in.
	local travelNoclip = runService.Heartbeat:Connect(function()
		if Toggles and Toggles.NoClip and not Toggles.NoClip.Value then
			Toggles.NoClip:SetValue(true)
		end
		local c = character()
		if c then
			for _, part in next, c:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end)

	playerSafeTween(ENTRANCE, ENTRANCE_SPEED, true, true) -- ground level (y=0) to the door; force 40 studs/s regardless of the Tween Speed slider
	pcall(function()
		travelNoclip:Disconnect()
	end)
	pcall(function()
		replicatedStorage.Requests.UpdateUXSettings:FireServer("FriendlyFire", true)
	end)

	local entry = workspace:WaitForChild("Map", 10)
	entry = entry and entry:WaitForChild("MeritEntry", 5)

	-- Pin us to the entrance while firing the prompt so nothing nudges us off the door.
	local holdConn = runService.Heartbeat:Connect(function()
		local r = root()
		if r then
			r.CFrame = ENTRANCE
		end
		-- Brute-force noclip for the door approach: force every character part CanCollide=false each frame so
		-- geometry can't snag us (doesn't rely on the NoClip toggle / Movement loop).
		local c = character()
		if c then
			for _, part in next, c:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end)

	local start = tick()
	repeat
		-- Keep noclip ON for the whole door approach (re-assert each pass -- a one-shot set can get cleared by
		-- the fresh-character spawn / feature management, same reason the no-fall loop re-asserts).
		if Toggles and Toggles.NoClip and not Toggles.NoClip.Value then
			Toggles.NoClip:SetValue(true)
		end
		if shouldLogHop(ENTRANCE.Position) then
			if holdConn then
				holdConn:Disconnect()
			end
			serverHop()
			while task.wait() do
			end
			return
		end
		if entry and entry:FindFirstChild("InteractPrompt") then
			Prompt.interact(entry.InteractPrompt)
		end
		task.wait(0.1)
	until tick() - start > 15 or game.PlaceId ~= EASTERN_PLACE_ID or not running

	if holdConn then
		holdConn:Disconnect()
	end
end

-- Old pathfind (mob_ai) breaker, baked straight into the Titus fight (no toggle). Every Heartbeat we
-- snapshot the root's real velocity, then slam it straight down (0, -9e11, 0); we restore the snapshot
-- BEFORE the next physics step so we never actually fall -- the slam lives for one tick, just long enough
-- to replicate the fling. The restore runs on PreRender AND PreSimulation: PreRender covers the focused
-- case, PreSimulation also fires while the window is UNFOCUSED (PreRender doesn't), so an AFK/tabbed-out
-- session can't skip the restore and let the slam rocket us into the void / null zone.
local titusBreakerHB = nil
local titusBreakerPR = nil
local titusBreakerPS = nil
local titusBreakerLastVel = nil

local function stopTitusBreaker()
	if titusBreakerHB then
		pcall(function()
			titusBreakerHB:Disconnect()
		end)
		titusBreakerHB = nil
	end
	if titusBreakerPR then
		pcall(function()
			titusBreakerPR:Disconnect()
		end)
		titusBreakerPR = nil
	end
	if titusBreakerPS then
		pcall(function()
			titusBreakerPS:Disconnect()
		end)
		titusBreakerPS = nil
	end
	if titusBreakerLastVel then
		local r = root()
		if r then
			pcall(function()
				r.AssemblyLinearVelocity = titusBreakerLastVel
			end)
		end
		titusBreakerLastVel = nil
	end
end

local function startTitusBreaker()
	stopTitusBreaker()

	-- Restore the pre-slam velocity. Runs on every pre-physics tick so the slam is always undone before
	-- physics integrates it (otherwise -9e11 would carry us straight into the void).
	local function restoreBreakerVelocity()
		if not titusBreakerLastVel then
			return
		end
		local r = root()
		if r then
			r.AssemblyLinearVelocity = titusBreakerLastVel
		end
		titusBreakerLastVel = nil
	end

	titusBreakerHB = runService.Heartbeat:Connect(function()
		local r = root()
		if not r then
			return
		end
		titusBreakerLastVel = r.AssemblyLinearVelocity
		r.AssemblyLinearVelocity = Vector3.new(0, -9e11, 0)
	end)

	-- PreRender restores while the window is focused; PreSimulation (falling back to Stepped) also fires
	-- when it's unfocused, so the restore can never be skipped and let the slam fling us to the null zone.
	titusBreakerPR = runService.PreRender:Connect(restoreBreakerVelocity)
	local preSim = runService.PreSimulation or runService.Stepped
	if preSim then
		titusBreakerPS = preSim:Connect(restoreBreakerVelocity)
	end
end

---Ram up and down through Titus's torso; the inline pathfind breaker does the actual killing.
local function attachToTitus()
	setStage("fighting titus")

	local titus
	repeat
		for _, ent in next, workspace.Live:GetChildren() do
			if ent.Name:lower():find("titus") and ent.Name:find("%.") then
				titus = ent
				break
			end
		end
		task.wait()
	until titus or not running
	if not titus then
		return
	end

	local torso = titus:WaitForChild("Torso")
	if not torso then
		return
	end

	local playerRoot = root()
	if not playerRoot then
		return
	end

	-- Dodge spam (PR's VIM Q loop -> Aero InputClient.dodge).
	maid:mark(task.spawn(function()
		while titus and titus.Parent and running do
			pcall(function()
				InputClient.dodge({ direct = true })
			end)
			task.wait(0.35)
		end
	end))

	local targetCF = CFrame.new(torso.CFrame.X, APPROACH_Y, torso.CFrame.Z)
	playerRoot.AssemblyLinearVelocity = Vector3.zero
	tempTween(targetCF, 250)
	task.wait(0.5)
	tempTween(targetCF, 250)

	-- Kill by ramming up and down THROUGH Titus's torso: oscillate between his torso and a point VOID_SWING
	-- studs above it (position-only target -- a straight vertical lookAt is degenerate and NaNs the CFrame).
	-- The pathfind breaker does the damage; this just drives the motion. Done when he dies, or hop if he
	-- somehow gets flung up off the map.
	startTitusBreaker()
	-- Ram hard and FAST through Titus's torso at a fixed, slider-independent speed (the shared Tween Speed
	-- slider can't be trusted to hold a value at runtime, and the old setSpeed(200) was non-force so it
	-- silently ran at the ~100 slider default). Step the root straight between his torso and VOID_SWING studs
	-- above it, flipping the instant we reach an end, slamming the whole time via the breaker.
	local VOID_SWING = 100
	local RAM_SPEED = 900
	-- If Titus gets flung farther than this from us, stop chasing him. He's on his way out (flung/voiding),
	-- and gliding across the map after his torso is exactly the bug we're fixing. Hold position instead and
	-- keep swinging; he dies or comes back, and the per-action watchdog server-hops if the fight truly stalls.
	local MAX_RAM_DISTANCE = 10000
	local voidGoingIn = true
	local dt = task.wait()
	while running do
		if not titus or not titus.Parent or not torso.Parent then
			break
		end
		if torso.Position.Y > 2000 then
			stopTitusBreaker()
			serverHop()
			return
		end

		playerRoot = root()
		if playerRoot then
			playerRoot.AssemblyLinearVelocity = Vector3.zero

			local ramPos = torso.Position + Vector3.new(0, voidGoingIn and VOID_SWING or 0, 0)
			local toTarget = ramPos - playerRoot.Position
			local dist = toTarget.Magnitude
			-- Only ram/move while he's close. Flung too far -> don't chase; lift up to Y=1000 and wait him out.
			if dist <= MAX_RAM_DISTANCE then
				local stepDist = RAM_SPEED * dt
				if dist <= stepDist or dist < 3 then
					playerRoot.CFrame = CFrame.new(ramPos)
					voidGoingIn = not voidGoingIn
				else
					playerRoot.CFrame = CFrame.new(playerRoot.Position + (toTarget / dist) * stepDist)
				end
			else
				-- Titus flung past MAX_RAM_DISTANCE: sit at Y=1000 (keep our X/Z) instead of gliding after him.
				local pos = playerRoot.Position
				playerRoot.CFrame = CFrame.new(pos.X, 1000, pos.Z)
			end
			pcall(function()
				character().CharacterHandler.Requests.DrawWeapon:FireServer(true)
			end)
		end

		dt = task.wait()
	end
	stopTitusBreaker()
	Tweening.stop(MOVE_ID)
end

---Loot the boss chest (echo: force Loot All).
local function grabChest()
	setStage("looting chest")

	-- Find the chest (wait for it to spawn after the kill).
	local chest
	local findStart = tick()
	repeat
		local thrown = workspace:FindFirstChild("Thrown")
		if thrown then
			for _, object in next, thrown:GetChildren() do
				if object:FindFirstChild("Lid") then
					chest = object
					break
				end
			end
		end
		if not chest then
			task.wait()
		end
	until chest or not running or (tick() - findStart > 15)
	if not chest then
		return
	end

	local previousAutoLootIgnore = AutoLoot.ignore
	AutoLoot.ignore = true
	local ok, err = xpcall(function()
		-- Chest appeared: snap straight onto it and hold there. After the post-kill teleport we're ~1300 studs
		-- up, so don't rely on a slow descend tween -- lock onto the chest position immediately, then the
		-- re-tween loop below keeps us glued to it while we open + loot.
		do
			local rr = root()
			if rr then
				rr.AssemblyLinearVelocity = Vector3.zero
				rr.CFrame = CFrame.new(chest.Lid.CFrame.Position)
			end
		end

		-- The farm sends LOOT_ALL itself; keep generic AutoLoot from closing this prompt with EXIT.
		tempTween(chest.Lid.CFrame, 170)
		local promptStart = tick()
		repeat
			task.wait(0.1)
			pcall(function()
				Prompt.interact(chest:FindFirstChildWhichIsA("ProximityPrompt"))
			end)
			pcall(function()
				tempTween(chest.Lid.CFrame, 170)
			end)
		until (playerGui() and playerGui():FindFirstChild("ChoicePrompt")) or not running or (tick() - promptStart > 15)

		local gui = playerGui()
		if not (gui and gui:FindFirstChild("ChoicePrompt")) then
			return
		end

		local time = tick()
		repeat
			task.wait()
			gui = playerGui()
			local cp = gui and gui:FindFirstChild("ChoicePrompt")
			if cp then
				pcall(function()
					cp:FindFirstChild("Choice"):FireServer("LOOT_ALL")
				end)
			end
		until not (gui and gui:FindFirstChild("ChoicePrompt")) or not running or (tick() - time >= 3)

		gui = playerGui()
		local cp = gui and gui:FindFirstChild("ChoicePrompt")
		if cp then
			pcall(function()
				cp:FindFirstChild("Choice"):FireServer("EXIT")
			end)
		end
		-- Intentionally NOT tweening back down to Y=0 -- stay at altitude after looting.
	end, debug.traceback)
	AutoLoot.ignore = previousAutoLootIgnore
	if not ok then
		error(err, 0)
	end
end

---Idol relief-from-flaws + weapon enchant (PR echo getechoes).
local function getEchoes()
	setStage("enchant / idol")

	local lp = localPlayer()
	local backpack = lp and lp:FindFirstChildOfClass("Backpack")
	local char = character()
	if not backpack or not char then
		return
	end
	local hum = humanoid()

	local function equipWeapon(weaponName)
		if not weaponName then
			return false
		end
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name:match(weaponName) then
				hum:EquipTool(tool)
				task.wait(0.1)
				tool:Activate()
				return true
			end
		end
		return false
	end

	-- Idol of Yun'Shul -> relief from flaws.
	local idol = backpack:FindFirstChild("Idol of Yun'Shul")
	if idol and running then
		hum:EquipTool(idol)
		task.wait(0.3)
		for _ = 1, 3 do
			idol:Activate()
			task.wait(0.1)
			if playerGui() and playerGui():FindFirstChild("ChoicePrompt") then
				break
			end
		end
		local prompt = playerGui() and playerGui():WaitForChild("ChoicePrompt", 5)
		if prompt and prompt:FindFirstChild("Choice") then
			prompt.Choice:FireServer("Give me relief from my Flaws.")
			local start = tick()
			repeat
				task.wait(0.1)
			until not (playerGui() and playerGui():FindFirstChild("ChoicePrompt")) or tick() - start > 5
		end
	end

	-- Enchant the main weapon.
	local enchantStone
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and tool.Name:match("Enchant") then
			enchantStone = tool
			break
		end
	end

	if enchantStone and running then
		local weaponHolder = backpack:FindFirstChild("Weapon")
		local currentWeapon = weaponHolder and weaponHolder:FindFirstChild("Weapon") and weaponHolder.Weapon.Value
		pcall(function()
			replicatedStorage:WaitForChild("Requests"):WaitForChild("Unequip"):InvokeServer("Weapon", true)
		end)
		task.wait(0.5)

		equipWeapon(currentWeapon)

		hum:EquipTool(enchantStone)
		task.wait(0.5)
		enchantStone:Activate()

		local prompt = playerGui() and playerGui():WaitForChild("ChoicePrompt", 5)
		local choice = prompt and prompt:WaitForChild("Choice", 5)
		if choice then
			choice:FireServer(true)
			task.wait(1)
		end
	end

	-- Report whether the chest actually yielded enchant stones -- the run-dungeon flow uses this to
	-- decide between banking (wipe) and retrying for another chest.
	return enchantStone ~= nil
end

-- =========================================================================================================
-- State machine.
-- =========================================================================================================
local function isCharacterCreation()
	local cc = workspace:FindFirstChild("CharacterCreator")
	local c = character()
	return cc ~= nil and c ~= nil and c.Parent == cc
end

-- Ferryman-style auto log: throughout the entire farm, hop the moment another player comes within the
-- per-automation auto-log distance (adjustable 0-2000 in the menu; 0 = off). Saved per automation.
local function watchForPlayers()
	while running do
		task.wait(1)
		if not running then
			break
		end
		-- Don't hop mid-creation (lobby players would softlock the character creator).
		if isCharacterCreation() then
			continue
		end
		-- Never auto-log in Fragments of Self: it's the shared cash-in hub where other players are ALWAYS
		-- present, so proximity-hopping there just interrupts banking echoes over and over. Skip the area
		-- entirely regardless of the distance setting -- this is the "autologs in Fragments of Self" report.
		local area = currentArea()
		if area and tostring(area):match("Fragments of Self") then
			continue
		end
		local dist = AutoLog.get("echo_farm")
		if dist > 0 and playerCheck(dist) then
			serverHop()
			return
		end
	end
end

---Blow through the game's start / loading screen by firing Requests.StartMenu.Start until our character
---loads into workspace.Live. Skipped in character creation (that's its own flow). PR's framework fires this
---during init; Aero has to do it per session since each cycle spans multiple joins.
---Tap a key once via VirtualInputManager (input-only; no remote).
local function pressKey(keyCode)
	pcall(function()
		local vim = Instance.new("VirtualInputManager")
		vim:SendKeyEvent(true, keyCode, false, game)
		vim:SendKeyEvent(false, keyCode, false, game)
	end)
end

local function requestStart()
	-- Blow through the loading screen by spamming A while the LoadingGui is up (input-only -- the old
	-- Requests.StartMenu.Start remote is an anticheat honeypot, firing it = instant ban). Wait for the
	-- character to spawn into workspace.Live. Skipped in character creation.
	local deadline = os.clock() + 25
	repeat
		if isCharacterCreation() then
			return
		end
		local c = character()
		if c and c.Parent and c.Parent.Name == "Live" then
			return
		end
		local pg = players.LocalPlayer and players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pg and pg:FindFirstChild("LoadingGui") then
			pressKey(Enum.KeyCode.A)
		end
		task.wait(0.2)
	until not running or os.clock() >= deadline
end

local stateMachine = StateMachine.create({
	initial = "idle",
	events = {
		{ name = "start", from = "idle", to = "_check_area" },
		{ name = "continuation", from = "_create_character", to = "_check_area" },
		{ name = "continuation", from = "_handle_fragments", to = "_check_area" },
		{ name = "die", from = "_check_area", to = "_die" },
		{ name = "die", from = "_run_dungeon", to = "_die" },
		{ name = "fragments", from = "_check_area", to = "_handle_fragments" },
		{ name = "cc", from = "_check_area", to = "_create_character" },
		{ name = "enter", from = "_check_area", to = "_enter_dungeon" },
		{ name = "run", from = "_check_area", to = "_run_dungeon" },
	},
	callbacks = {
		onenter_check_area = function(self)
			if not running then
				return
			end
			setStage("check area")

			-- Merit / dungeon: we always have an existing character here, so it's safe to blow through the
			-- start/loading screen with StartMenu.Start before routing.
			if game.PlaceId == EASTERN_PLACE_ID then
				requestStart()
				return self:enter()
			end
			if game.PlaceId == DUNGEON_PLACE_ID then
				requestStart()
				return self:run()
			end

			-- Anywhere else (lobby / character creator / fragments / depths): DO NOT fire StartMenu.Start --
			-- that would rush the character creator and roll the wrong character. Wait patiently to classify.
			local deadline = os.clock() + 20
			repeat
				if isCharacterCreation() then
					return self:cc()
				end
				local area = currentArea()
				if area and tostring(area):match("Fragments of Self") then
					return self:fragments()
				end
				if area and tostring(area):match("The Depths") then
					return self:die()
				end
				task.wait()
			until os.clock() >= deadline or not running
		end,

		onenter_create_character = function(self)
			if not running then
				return
			end
			setStage("create character")
			struct:create_character()
			self:continuation()
		end,

		onenter_enter_dungeon = function(self)
			if not running then
				return
			end
			enterDungeon()
		end,

		onenter_run_dungeon = function(self)
			if not running then
				return
			end
			setStage("run dungeon")

			local startTime = tick()
			repeat
				task.wait(0.2)
			until (currentArea() and tostring(currentArea()):match("Detainment")) or not running

			task.wait(1)
			attachToTitus()

			-- Titus is down: re-arm the watchdog so the post-kill exit-wait + fly-up + loot/enchant each get
			-- a fresh ACTION_TIMEOUT. The "fighting titus" cap was armed back when the FIGHT started and is
			-- shorter (VOID_TIMEOUT); leaving it armed lets it expire mid-transition and wipe the run before
			-- the idol + enchant stones are used.
			setStage("boss defeated")

			-- Reset the 30s DungeonExitFinal cap to measure from the KILL, not the dungeon-run start, so a
			-- slow fight can't eat the window the run gets to wait for the exit to spawn.
			startTime = tick()

			local hum = humanoid()
			if hum then
				hum.Died:Connect(function()
					serverHop()
				end)
			end

			local finished = false
			local core = workspace:WaitForChild("DetainmentCore", 10)
			local conn
			if core then
				conn = core.ChildAdded:Connect(function(child)
					if child.Name == "DungeonExitFinal" then
						finished = true
					end
				end)
			end

			repeat
				task.wait(0.2)
				if tick() - startTime > 30 then
					if conn then
						conn:Disconnect()
					end
					serverHop()
					while task.wait() do
					end
					return
				end
			until finished or not running

			if conn then
				conn:Disconnect()
			end

			task.wait(0.5)

			-- Tear the pathfind breaker down before looting so velocity is normal for the chest interaction.
			stopTitusBreaker()

			-- Fly up out of the arena, then loot + enchant.
			local r = root()
			if r then
				r.CFrame = r.CFrame * CFrame.new(0, 1300, 0)
			end

			local gotEnchant = false
			xpcall(function()
				grabChest()
				gotEnchant = getEchoes() == true
			end, function(err)
				Logger.notify("EchoFarm loot error: %s", tostring(err))
			end)

			-- No enchant stones in the chest: do NOT wipe (that banks + resets the run for nothing). Rejoin
			-- to re-run the dungeon for another chest instead, keeping the character + its echoes. Only a run
			-- that actually pulled enchant stones proceeds to the wipe (banking at Fragments of Self).
			if not gotEnchant then
				setStage("no enchant stones -- retrying")
				serverHop()
				while task.wait() do
				end
				return
			end

			-- Count this run's echoes (request the score; the persistent listener folds it in) + bump cycle.
			recordCycle()

			task.wait(3.75)

			-- Wait out any lingering danger, then wipe (obliteration) to bank echoes at Fragments of Self.
			local hum2 = humanoid()
			if hum2 and hum2:GetAttribute("DangerExpiration") and hum2:GetAttribute("DangerExpiration") > 0 then
				repeat
					task.wait()
				until not (hum2:GetAttribute("DangerExpiration") and hum2:GetAttribute("DangerExpiration") > 0)
					or not running
			end

			self:die()
		end,

		onenter_handle_fragments = function(self)
			if not running then
				return
			end
			setStage("fragments cash-in")

			local self_npc
			local deadline = os.clock() + 40
			repeat
				local npcs = workspace:FindFirstChild("NPCs")
				self_npc = npcs and npcs:FindFirstChild("Self")
				task.wait()
			until self_npc or os.clock() >= deadline or not running
			if not self_npc then
				serverHop()
				return
			end

			-- Count this run once via the persistent listener, then interact to finalize.
			recordCycle()

			local tpLocation = (self_npc:GetPivot() - Vector3.new(0, 15.7, 0))
				* CFrame.Angles(math.rad(180), math.rad(90), math.rad(180))

			-- No auto-log here: the cash-in happens IN Fragments of Self, a shared hub that's always full of
			-- other players, so a proximity hop would abort the bank-in on practically every run. Just cash in.

			local sendDialogue = replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue")
			-- NPCs expose the prompt either as a child named "InteractPrompt" or just a ProximityPrompt.
			local prompt = self_npc:FindFirstChild("InteractPrompt")
				or self_npc:FindFirstChildWhichIsA("ProximityPrompt", true)

			-- True while Self's dialogue window is up.
			local function dialogueOpen()
				local gui = playerGui()
				local dlg = gui and gui:FindFirstChild("DialogueGui")
				return dlg ~= nil and dlg.Enabled ~= false
			end

			-- Advance Self's dialogue by firing the choices it ACTUALLY presents. Each choice button carries
			-- a "ChoiceID" attribute -- that ID is what the game sends to the server, NOT the display text --
			-- so the old hardcoded "[The End]" string silently matched nothing once the dialogue changed.
			-- Fire every non-exit choice the live dialogue offers (the cash-in is short, so this walks it to
			-- the end); fall back to the old string if no choices are readable.
			local function advanceDialogue()
				local gui = playerGui()
				local scroll = gui and gui:FindFirstChild("DialogueGui")
				scroll = scroll and scroll:FindFirstChild("DialogueFrame")
				scroll = scroll and scroll:FindFirstChild("DialogueContainer")
				scroll = scroll and scroll:FindFirstChild("ChoiceSheet")
				scroll = scroll and scroll:FindFirstChild("ChoiceScroll")
				local firedAny = false
				if scroll then
					for _, choice in ipairs(scroll:GetChildren()) do
						local id = choice:GetAttribute("ChoiceID")
						if id ~= nil and id ~= "EXIT" then
							pcall(function()
								sendDialogue:FireServer({ choice = id })
							end)
							firedAny = true
							task.wait(0.15)
						end
					end
				end
				if not firedAny then
					pcall(function()
						sendDialogue:FireServer({ choice = "[The End]" })
					end)
				end
			end

			local start = tick()
			repeat
				local r = root()
				if r then
					r.CFrame = tpLocation
				end
				-- Open the dialogue: press the interact key like a human, and if it still isn't up, force the
				-- prompt directly (distance/LOS-independent) so bad positioning can't block the cash-in.
				if prompt then
					Prompt.interact(prompt)
					if not dialogueOpen() then
						Prompt.fire(prompt)
					end
				end
				if dialogueOpen() then
					advanceDialogue()
				end
				task.wait(0.25)
			until isCharacterCreation() or not (currentArea() and tostring(currentArea()):match("Fragments of Self")) or not running or (tick() - start > 20)

			self:continuation()
		end,

		onenter_die = function(self)
			if not running then
				return
			end
			setStage("wipe")
			local slot = currentSlot() or (PersistentData.get("efdata") and PersistentData.get("efdata").slot)
			pcall(function()
				Wipe.invoke(slot)
			end)
		end,
	},
})

-- =========================================================================================================
-- Struct.
-- =========================================================================================================
local function buildStruct()
	return AutomationStruct.construct({
		id = "echo_titus",
		state_machine = stateMachine,
		is_running = isRunning,
		features = {
			"no_fall",
			"noclip",
			"fly",
			"auto_loot",
			"auto_equip_weapon",
		},
		character_creator_handler_used = true,
		character_creator_handler_opts = {
			origin = "Merit",
			-- Select the Merit spawn (Authority Ensign origin), verified against DataReplication.Origin. If it
			-- doesn't apply within 10s, server-hop and retry on a fresh server instead of kicking the player.
			origin_button = {
				category = "Authority Ensign",
				spawn = "Merit",
				timeout = 10,
				on_fail = function()
					serverHop()
				end,
			},
			weapon = "Sword",
			-- "All" enables every meta modifier; then toggle "OneBit" (the can't-swim flaw) back off.
			modifiers = { "All", "OneBit" },
		},
	})
end

-- =========================================================================================================
-- Layer 2 (Chaser) echo farm -- a Aero port of project-rain-oss's `auto_echo_layer2.lua`. Reuses every
-- helper above (overlay, stats, watchdog, score listener, fragments cash-in, wipe, server-hop safety); only
-- the route differs: dive into the void -> key/door -> bonekeeper -> generator -> chaser -> void it -> wipe.
--
-- The chaser kill uses Aero's own void path: EchoFarm.voiding = true makes OwnershipWatcher own the chaser
-- (instead of dropping it like the trash mobs) and runs Fling on it -- the pre-wired `.voiding`
-- hooks in Exploits / OwnershipWatcher -- and we fling its owned root up past the destroy height.
--
-- NOTE: the waypoint CFrames below are PR's and are dungeon-layout-specific; if Deepwoken moves the Layer 2
-- geometry they'll need re-capturing. The chaser-void physics can't be bench-tested here, so expect to tune.
-- =========================================================================================================
local L2_BONEKEEPER = CFrame.new(-5747, 459, -6357)
local L2_BONEKEEPER_APPROACH = CFrame.new(-5889, 459, -6308)
local L2_BONEKEEPER_WATCH = CFrame.new(-5788, 563, -6351)
local L2_GENERATOR = CFrame.new(-5555, 529, -6475)
local L2_CHASER_HIGH = CFrame.new(-5361, 5000, -4801)
local L2_CHASER_DOWN = CFrame.new(-5361, 285, -4801)
local L2_CHASER_ANGLE = CFrame.new(-5224.36523, 194.26561, -4633.03223, -0.803056717, 0, -0.595902622, 0, 1, 0, 0.595902622, 0, -0.803056717)
local L2_VOID_Y = 2500 -- chaser root above this = voided.

---Fire Requests.SendDialogue with a choice (or exit), matching PR's send_dialogue.
local function sendDialogue(textOrNil, exit)
	pcall(function()
		local send = replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue")
		if exit then
			send:FireServer({ exit = true })
		else
			send:FireServer({ choice = textOrNil })
		end
	end)
	if not exit then
		task.wait(0.5)
	end
end

---Disable + forget a struct feature mid-run (same pattern EchoFarm uses to drop mob_ai_breaker before loot).
local function disableStructFeature(name)
	pcall(function()
		local feat = struct and struct.active_features and struct.active_features[name]
		if feat then
			feat:disable()
			struct.active_features[name] = nil
		end
	end)
end

local function liveChildren()
	local live = workspace:FindFirstChild("Live")
	return live and live:GetChildren() or {}
end

local function nearestKillPlane()
	local r = root()
	if not r then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, item in ipairs(game:GetService("CollectionService"):GetTagged("KillPlane")) do
		if item:IsA("BasePart") and item:IsDescendantOf(workspace) then
			local d = (item.Position - r.Position).Magnitude
			if d < bestDist then
				best, bestDist = item, d
			end
		end
	end
	return best
end

local function inLayer2()
	local lp = localPlayer()
	local dungeon = lp and lp:GetAttribute("Dungeon")
	if dungeon and tostring(dungeon):match("Layer2") then
		return true
	end
	local area = currentArea()
	return area ~= nil and tostring(area):match("Layer2") ~= nil
end

---Dive into the void so the server routes us into Layer 2: drop kill-brick immunity + fly so we actually
---fall, then slam downward velocity into the nearest kill plane until the area flips to Layer 2.
local function enterVoid()
	if currentArea() and tostring(currentArea()):match("Fragments of Self") then
		return
	end
	setStage("entering the void")
	disableStructFeature("no_kill_bricks")
	disableStructFeature("fly")

	local startedAt = tick()
	local plane = nearestKillPlane()
	repeat
		plane = nearestKillPlane()
		task.wait()
	until plane or tick() - startedAt > 15 or not running or inLayer2()

	while running and tick() - startedAt < 60 do
		if inLayer2() then
			break
		end
		if playerCheck(300) then
			serverHop()
			while task.wait() do
			end
			return
		end
		local r = root()
		if r then
			r.AssemblyLinearVelocity = Vector3.new(0, -999, 0)
		end
		if plane and plane.Parent then
			-- Void physics need the full dive speed (slowing this broke the dive); keep it at 200 even though
			-- the L2 travel tweens are slower.
			setSpeed(200)
			Tweening.goal(MOVE_ID, plane.CFrame, false)
		else
			plane = nearestKillPlane()
		end
		task.wait()
	end
	Tweening.stop(MOVE_ID)
end

---Tween to an NPC under workspace.NPCs, fire its prompt until the dialogue opens, then pick `choice` (if any)
---and/or exit. Shared by the key/door/generator steps.
local function tweenToNpcAndTalk(npcName, choice, exitAfter)
	local npc
	local findStart = tick()
	repeat
		local npcs = workspace:FindFirstChild("NPCs")
		npc = npcs and npcs:FindFirstChild(npcName)
		task.wait()
	until npc or tick() - findStart > 20 or not running
	if not npc then
		return false
	end

	local start = tick()
	repeat
		pcall(function()
			tempTween(npc:GetPivot(), 150)
		end)
		local prompt = npc:FindFirstChild("InteractPrompt")
		if prompt then
			Prompt.interact(prompt)
		end
		task.wait(0.5)
		local gui = playerGui()
		if gui and gui:FindFirstChild("DialogueGui") and gui.DialogueGui.Enabled then
			break
		end
	until tick() - start > 20 or not running

	if choice then
		sendDialogue(choice, false)
	end
	if exitAfter then
		sendDialogue(nil, true)
	end
	return true
end

local function getKey()
	setStage("key / door")
	tweenToNpcAndTalk("TheKey", nil, true)
	tweenToNpcAndTalk("TheDoor", nil, true)
end

---Bonekeeper encounter: enable VoidMobs (clears trash mobs), wait for the keeper to spawn + its bridge
---barrier to drop (PR spawn_keeper).
local function spawnKeeper()
	setStage("bonekeeper")
	tempTween(L2_BONEKEEPER, 150)
	pcall(function()
		if Toggles and Toggles.VoidMobs then
			Toggles.VoidMobs:SetValue(true)
		end
	end)

	local keeper
	local startedAt = tick()
	repeat
		if not keeper then
			pcall(function()
				tempTween(L2_BONEKEEPER_APPROACH, 100)
			end)
		end
		for _, ent in next, liveChildren() do
			if ent ~= character() and ent.Name:find("%.boneboy") then
				keeper = ent
			end
		end
		task.wait()
	until keeper or tick() - startedAt > 40 or not running

	-- Wait for the boneboy to disappear (bridge barrier drops), hovering 100 studs directly above it the whole
	-- time. Tweened toward keeper.Position + 100Y every frame (tweening both axes is anticheat-safe); once the
	-- keeper is gone we just hold and keep watching the barrier.
	local bridgeStart = tick()
	repeat
		if keeper and keeper.Parent then
			local kp = keeper:GetPivot().Position
			setSpeed(150)
			Tweening.goal(MOVE_ID, CFrame.new(kp.X, kp.Y + 100, kp.Z), false)
		end
		task.wait()
		local triggers = workspace:FindFirstChild("EncounterTriggers")
		local bridge = triggers and (triggers:FindFirstChild("BonekeeperBridge") or triggers:FindFirstChild("BoneKeeperBridge"))
		if not bridge or not bridge:FindFirstChild("Barrier") then
			break
		end
	until tick() - bridgeStart > 40 or not running
	Tweening.stop(MOVE_ID)
end

---Restart the generator (PR go_to_generator), then stop clearing trash mobs.
local function goToGenerator()
	setStage("generator")
	local start = tick()
	repeat
		pcall(function()
			tempTween(L2_GENERATOR, 150)
		end)
		task.wait(0.5)
		pcall(function()
			local npcs = workspace:FindFirstChild("NPCs")
			local gen = npcs and npcs:FindFirstChild("TheGenerator")
			if gen and gen:FindFirstChild("InteractPrompt") then
				Prompt.interact(gen.InteractPrompt)
			end
		end)
		local gui = playerGui()
		if gui and gui:FindFirstChild("DialogueGui") and gui.DialogueGui.Enabled then
			break
		end
	until tick() - start > 20 or not running

	sendDialogue("[Restart it]", false)
	sendDialogue(nil, true)
	pcall(function()
		if Toggles and Toggles.VoidMobs then
			Toggles.VoidMobs:SetValue(false)
		end
	end)
end

local function drawWeapon()
	pcall(function()
		local char = character()
		if char and char:FindFirstChild("CharacterHandler") then
			char.CharacterHandler.Requests.DrawWeapon:FireServer(true)
		end
	end)
end

---Find + engage the chaser (PR chaser_route). Returns the chaser model (or nil).
local function chaserRoute()
	setStage("finding chaser")
	tempTween(L2_CHASER_HIGH, 150)

	local chaser
	local startedAt = tick()
	repeat
		pcall(function()
			tempTween(L2_CHASER_DOWN, 150)
		end)
		for _, ent in next, liveChildren() do
			if ent ~= character() and ent.Name:find("chaser") then
				chaser = ent
				break
			end
		end
		if not chaser then
			pcall(function()
				tempTween(L2_CHASER_ANGLE, 150)
			end)
		end
		task.wait()
	until chaser or tick() - startedAt > 40 or not running
	if not chaser then
		return nil
	end

	-- Last approach before the fight. The anticheat flags HORIZONTAL (X/Z) position snaps but not VERTICAL
	-- ones, so horizontal travel must be tweened and only Y may be snapped. Snap UP to Y=20000, TWEEN
	-- horizontally to directly above the chaser at that altitude, then snap straight DOWN onto it.
	do
		local r = root()
		if r then
			r.CFrame = CFrame.new(r.Position.X, 20000, r.Position.Z)
		end
		local cp = chaser:GetPivot().Position
		tempTween(CFrame.new(cp.X, 20000, cp.Z), 150)
		r = root()
		if r then
			-- Vertical-only snap down onto the chaser (keep our tweened X/Z, drop Y to the chaser's).
			r.CFrame = CFrame.new(r.Position.X, chaser:GetPivot().Position.Y, r.Position.Z)
		end
	end

	local talkStart = tick()
	repeat
		-- Hold on the chaser by TWEENING (never a horizontal snap) while we fire the prompt.
		pcall(function()
			tempTween(chaser:GetPivot(), 150)
		end)
		local prompt = chaser:FindFirstChild("InteractPrompt")
		if prompt then
			Prompt.interact(prompt)
		end
		task.wait(0.5)
		local gui = playerGui()
		if gui and gui:FindFirstChild("DialogueGui") and gui.DialogueGui.Enabled then
			break
		end
	until tick() - talkStart > 20 or not running

	drawWeapon()
	-- PR's dialogue chain that starts the fight.
	sendDialogue("Ethiron's Wake?", false)
	sendDialogue("What happened here?", false)
	sendDialogue("They mutinied?", false)
	sendDialogue("The City?", false)
	return chaser
end

---Void the chaser: EchoFarm.voiding engages Aero's chaser hooks (own-not-drop + Fling), we extend
---our simulation radius + fling its owned root up, and orbit it to keep it owned. Done when it's gone or
---flung past L2_VOID_Y.
local function voidChaser(chaser)
	if not chaser then
		return
	end
	setStage("voiding chaser")
	EchoFarm.voiding = true
	pcall(function()
		sethiddenproperty(localPlayer(), "MaxSimulationRadius", 5000)
		sethiddenproperty(localPlayer(), "SimulationRadius", 5000)
	end)

	local startedAt = tick()
	while running and chaser.Parent do
		drawWeapon()
		local hrp = chaser:FindFirstChild("HumanoidRootPart")
		if hrp then
			if hrp.Position.Y > L2_VOID_Y then
				break
			end
			-- Orbit just above its root to keep it owned + in range (void physics -- keep full speed)...
			setSpeed(200)
			Tweening.goal(MOVE_ID, CFrame.new(hrp.Position) * CFrame.new(0, 6, 0), false)
			-- ...and fling it straight up (works once we're its network owner; harmless otherwise).
			pcall(function()
				hrp.AssemblyLinearVelocity = Vector3.new(0, 12500, 0)
			end)
		end
		if tick() - startedAt > ACTION_TIMEOUT then
			break
		end
		task.wait()
	end

	Tweening.stop(MOVE_ID)
	EchoFarm.voiding = false
end

-- Layer 2 state machine. Mirrors the Titus one's shared states (check_area / create_character / fragments /
-- die), but routes by Layer 2 geography and runs the void + chaser route instead of the Titus dungeon.
local l2StateMachine = StateMachine.create({
	initial = "idle",
	events = {
		{ name = "start", from = "idle", to = "_check_area" },
		{ name = "continuation", from = "_create_character", to = "_check_area" },
		{ name = "continuation", from = "_handle_fragments", to = "_check_area" },
		{ name = "continuation", from = "_enter_void", to = "_check_area" },
		{ name = "die", from = "_check_area", to = "_die" },
		{ name = "die", from = "_run_void", to = "_die" },
		{ name = "fragments", from = "_check_area", to = "_handle_fragments" },
		{ name = "cc", from = "_check_area", to = "_create_character" },
		{ name = "enter_void", from = "_check_area", to = "_enter_void" },
		{ name = "run_void", from = "_check_area", to = "_run_void" },
	},
	callbacks = {
		onenter_check_area = function(self)
			if not running then
				return
			end
			setStage("check area")

			-- Blow through the start/loading screen so the character actually spawns before we classify
			-- (skipped automatically during character creation so we don't rush the creator).
			if not isCharacterCreation() then
				requestStart()
			end

			local deadline = os.clock() + 25
			repeat
				if isCharacterCreation() then
					return self:cc()
				end
				if inLayer2() then
					return self:run_void()
				end
				local area = currentArea()
				if area and tostring(area):match("Fragments of Self") then
					return self:fragments()
				end
				-- Have a spawned character in the overworld (not creating, not in Layer 2, not at Fragments)
				-- -> dive into the void. Gate on the character being in Live, NOT on CurrentArea being set:
				-- right after creation the area attribute is often still nil, which previously left this
				-- stuck here (never diving) until it timed out.
				local c = character()
				if c and c.Parent and c.Parent.Name == "Live" then
					return self:enter_void()
				end
				task.wait()
			until os.clock() >= deadline or not running
		end,

		onenter_create_character = function(self)
			if not running then
				return
			end
			setStage("create character")
			struct:create_character()
			self:continuation()
		end,

		onenter_enter_void = function(self)
			if not running then
				return
			end
			enterVoid()
			self:continuation()
		end,

		onenter_run_void = function(self)
			if not running then
				return
			end
			setStage("run layer 2")

			local startTime = tick()
			repeat
				task.wait(0.2)
			until inLayer2() or not running or tick() - startTime > 30

			getKey()
			spawnKeeper()
			goToGenerator()
			local chaser = chaserRoute()
			voidChaser(chaser)

			recordCycle()
			task.wait(2)
			self:die()
		end,

		onenter_handle_fragments = function(self)
			if not running then
				return
			end
			setStage("fragments cash-in")

			local self_npc
			local deadline = os.clock() + 40
			repeat
				local npcs = workspace:FindFirstChild("NPCs")
				self_npc = npcs and npcs:FindFirstChild("Self")
				task.wait()
			until self_npc or os.clock() >= deadline or not running
			if not self_npc then
				serverHop()
				return
			end

			recordCycle()

			local tpLocation = (self_npc:GetPivot() - Vector3.new(0, 15.7, 0))
				* CFrame.Angles(math.rad(180), math.rad(90), math.rad(180))

			if shouldLogHop(tpLocation.Position) then
				serverHop()
				while task.wait() do
				end
				return
			end

			local sendDlg = replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue")
			local prompt = self_npc:WaitForChild("InteractPrompt", 10)

			local start = tick()
			repeat
				local r = root()
				if r then
					r.CFrame = tpLocation
				end
				if prompt then
					Prompt.interact(prompt)
				end
				pcall(function()
					sendDlg:FireServer({ choice = "[The End]" })
				end)
				task.wait(0.25)
			until isCharacterCreation() or not (currentArea() and tostring(currentArea()):match("Fragments of Self")) or not running or (tick() - start > 20)

			self:continuation()
		end,

		onenter_die = function(self)
			if not running then
				return
			end
			setStage("wipe")
			local slot = currentSlot() or (PersistentData.get("efdata") and PersistentData.get("efdata").slot)
			pcall(function()
				Wipe.invoke(slot)
			end)
		end,
	},
})

local function buildL2Struct()
	return AutomationStruct.construct({
		id = "echo_layer2",
		state_machine = l2StateMachine,
		is_running = isRunning,
		features = {
			"no_fall",
			"noclip",
			"fly",
			"no_kill_bricks",
			"mob_ai_breaker",
			"auto_equip_weapon",
		},
		character_creator_handler_used = true,
		character_creator_handler_opts = {
			-- PR's throwaway Layer 2 character: Diluvian Mechanism origin, every meta modifier on.
			origin = "DiluvianMechanism",
			-- Select the origin via the real UI button (click until selected, kick if it never takes).
			-- DiluvianMechanism lives under the Deepbound origin category.
			origin_button = {
				category = "Deepbound",
				spawn = "DiluvianMechanism",
				timeout = 10,
				kick_message = "Need diluvian mechanism origin",
			},
			modifiers = { "All" },
		},
	})
end

-- =========================================================================================================
-- Public interface.
-- =========================================================================================================
function EchoFarm.start()
	local lp = localPlayer()
	if not lp then
		return
	end
	local data = PersistentData.get("efdata")
	if not data or not data.slot then
		return
	end
	if running then
		return
	end

	running = true
	buildOverlay()
	setStage("starting")
	AntiAFK.start("EchoFarm")

	maid:mark(task.spawn(runStats))

	-- Per-action 60s watchdog: wipe-reset the cycle if a stage stalls.
	maid:mark(task.spawn(runActionWatchdog))

	-- Ferryman-style auto log: hop if any player comes within 1000 studs.
	maid:mark(task.spawn(watchForPlayers))

	-- Persistent echo counter for this session.
	connectScoreListener()

	-- Layer 2 echo farm was removed -- only the Titus farm runs now (force it even if stale efdata says Layer2).
	local sm = stateMachine
	sm.current = "idle"
	sm.asyncState = StateMachine.NONE
	sm.currentTransitioningEvent = nil

	struct = buildStruct()
	struct:run()
end

function EchoFarm.invoke(mode)
	local lp = localPlayer()
	if not lp then
		return
	end
	if running then
		return
	end

	local slot = currentSlot()
	if not slot then
		return Logger.notify("EchoFarm: no data slot found.")
	end

	-- Fresh run stats. Layer 2 echo farm was removed -- always Titus regardless of the passed mode.
	PersistentData.set("efdata", {
		slot = slot,
		mode = "Titus",
		startedAt = os.time(),
		echoes = 0,
		cycles = 0,
	})

	-- Wipe the current character on start; the wipe teleports us out, and Aero's resume (efdata) brings us
	-- back into a fresh farm cycle (character creation -> enter -> fight -> ...).
	pcall(function()
		Wipe.invoke(slot)
	end)
end

function EchoFarm.stop()
	if not running then
		return
	end
	running = false

	-- Clear the chaser-void flag so the Exploits / OwnershipWatcher hooks don't keep running after a stop.
	EchoFarm.voiding = false
	stopTitusBreaker()

	if struct then
		pcall(function()
			struct:stop()
		end)
		struct = nil
	end

	Tweening.stop(MOVE_ID)

	pcall(function()
		AntiAFK.stop("EchoFarm")
	end)

	maid:clean()
	getScoreConn = nil
	destroyOverlay()

	PersistentData.set("efdata", nil)
end

return EchoFarm
