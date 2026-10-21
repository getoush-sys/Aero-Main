-- AutoTitus (RELICS farm): a Aero port of project-rain-oss's `titus_relicfarm.lua`, built on the ported
-- AutomationStruct + StateMachine framework. Constructs a struct with PR's relic feature set and drives the
-- same state machine: create character -> (bank relics / refill food) -> enter the Titus dungeon -> break
-- Titus (mob_ai_breaker) -> loot the relic chest -> respawn out -> repeat. Relics held in stacks of >= 25
-- get deposited at the Banker.
--
-- NOTE: faithful to PR, the relic farm does NOT run the `jesus` anti-water feature (only the echo farm does
-- in PR). It also keeps its character between cycles (no wipe) so relics accumulate for banking.
--
-- Public surface kept identical for Aero's menu + resume wiring:
--   AutoTitus.start()        -- menu Start + Aero.lua resume
--   AutoTitus.stop()         -- stop + cleanup
--   AutoTitus.inValidPlace() -- resume gate (merit hub or Titus dungeon)
-- Persistence key: "titusdata" { slot, startedAt }.
local AutoTitus = {}

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Features.Automation.Objects.AutoLog
local AutoLog = require("Features/Automation/Objects/AutoLog")

---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")

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

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local EASTERN_PLACE_ID = 6473861193 -- Fort Merit hub.
local DUNGEON_PLACE_ID = 8668476218 -- The Titus (Detainment) dungeon.

local MOVE_ID = "AutoTitus_Move"
local ENTRANCE = CFrame.new(-6875.86, 336.2, 2827.95)
local ENTRANCE_SPEED = 50
local PLAYER_SAFE_RADIUS = 200
local APPROACH_Y = 288
local ATTACH_DISTANCE = 35
local BANK_THRESHOLD = 25
local BANK_COOLDOWN = 45

local running = false
local struct = nil
local maid = Maid.new()
local lastBank = 0
local actionStartedAt = 0 -- os.clock() when the current stage began (0 = disarmed); per-action watchdog.
local ACTION_TIMEOUT = 60 -- a stage stalling longer than this REJOINS (server-hops) to reset the cycle.
local VOID_TIMEOUT = 45 -- shorter cap for the Titus voiding phase ("fighting titus") specifically.
local currentActionTimeout = ACTION_TIMEOUT -- active timeout for the current stage (set per-stage in setStage).

local screenGui, elapsedLabel = nil, nil

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

local function backpack()
	local lp = localPlayer()
	return lp and lp:FindFirstChildOfClass("Backpack")
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

function AutoTitus.inValidPlace()
	return game.PlaceId == EASTERN_PLACE_ID or game.PlaceId == DUNGEON_PLACE_ID
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
	screenGui.Name = "LumaAutoTitusOverlay"
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
		Size = UDim2.new(0, 300, 0, 78),
		BackgroundColor3 = Library.MainColor,
		BorderColor3 = Library.OutlineColor,
		BorderSizePixel = 1,
		ZIndex = 200,
	}, screenGui)
	Library:AddToRegistry(outer, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" })

	local title = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 6),
		Size = UDim2.new(1, -16, 0, 20),
		FontFace = Library.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Library.AccentColor,
		Text = "Auto Titus (Relics)",
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(title, { TextColor3 = "AccentColor" })

	elapsedLabel = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 30),
		Size = UDim2.new(1, -16, 0, 16),
		FontFace = Library.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Library.FontColor or Color3.new(1, 1, 1),
		Text = "Elapsed: 0s",
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(elapsedLabel, { TextColor3 = "FontColor" })

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
		AutoTitus.stop()
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
	elapsedLabel = nil
end

-- Stage text was removed, but setStage now re-arms the per-action watchdog on every stage change (the void
-- phase, "fighting titus", gets the shorter VOID_TIMEOUT cap). Same mechanism as the echo farm.
local function setStage(name)
	actionStartedAt = os.clock()
	currentActionTimeout = (name == "fighting titus") and VOID_TIMEOUT or ACTION_TIMEOUT
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

local function runElapsed()
	while running do
		local data = PersistentData.get("titusdata")
		if elapsedLabel and data then
			elapsedLabel.Text = "Elapsed: " .. formatDuration(math.max(0, os.time() - (data.startedAt or os.time())))
		end
		task.wait(0.5)
	end
end

-- =========================================================================================================
-- Movement primitives (ported from PR's autotitus table).
-- =========================================================================================================
local function setSpeed(value, force)
	-- Normally the per-automation Tween Speed slider wins; `force` lets a specific move (the dungeon-door
	-- travel) pin an exact speed regardless of the slider.
	if not force then
		value = (Options and Options.TitusTweenSpeed and Options.TitusTweenSpeed.Value) or 100
	end
	if Options and Options.TweenStudsPerSecond and Options.TweenStudsPerSecond.Value ~= value then
		Options.TweenStudsPerSecond:SetValue(value)
	end
end

---When `force` is set (the dungeon-door travel), step the root toward the goal at an EXACT studs/second
---ourselves instead of going through the shared Tween Speed slider. That slider is clamped (Min) and shared
---across every automation, so it can't reliably pin a speed at runtime -- this keeps the door approach at
---the speed we actually ask for (e.g. 50 studs/s) no matter what the slider says.
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
	-- currentSlot() reads the live DataSlot attribute, which is often absent inside the Titus dungeon;
	-- fall back to the farm's persisted slot so the rejoin resolves a real save slot instead of no-opping
	-- on nil.
	local data = PersistentData.get("titusdata")
	local slot = currentSlot() or (data and data.slot)
	pcall(function()
		ServerHop.hop(slot, true)
	end)
end

---Per-action watchdog (same mechanism as the echo farm): if a stage stalls past its cap -- the Titus void
---("fighting titus") gets VOID_TIMEOUT, everything else ACTION_TIMEOUT -- server-hop to rejoin a fresh server
---and re-enter (titusdata resume brings the farm back). Unlike the echo farm this REJOINS rather than wiping:
---a relic-farm character must survive, so it never obliterates.
local function runActionWatchdog()
	while running do
		if actionStartedAt > 0 and os.clock() - actionStartedAt > currentActionTimeout then
			actionStartedAt = 0 -- disarm so we only fire once
			serverHop()
			return
		end
		task.wait(0.25)
	end
end

---Player-safe tween: hop if anyone is near, else fly there at altitude and snap down (PR relic version).
---@param groundLevel boolean? when true, travel at ground level (no altitude lift) instead of high up.
local function playerSafeTween(cf, speed, groundLevel, force)
	if playerCheck(PLAYER_SAFE_RADIUS) then
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
	if playerCheck(PLAYER_SAFE_RADIUS, cf.Position) then
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
-- Relic helpers.
-- =========================================================================================================
local function countItem(name)
	local bp = backpack()
	if not bp then
		return 0
	end
	local qty = 0
	for _, item in next, bp:GetChildren() do
		if item.Name == name then
			qty = qty + 1
		end
	end
	return qty
end

local function bankItems()
	-- Aero menu dropdown "TitusBankItems" -> a set { [name] = true }.
	if Options and Options.TitusBankItems then
		return Options.TitusBankItems.Value or {}
	end
	return {}
end

local function needFood()
	local c = character()
	if not c then
		return false
	end
	local water = c:FindFirstChild("Water")
	local stomach = c:FindFirstChild("Stomach")
	if not water or not stomach then
		return false
	end
	return (water.Value <= (water.MaxValue * 0.3)) and (stomach.Value <= (stomach.MaxValue * 0.3))
end

local function refillFood()
	setStage("refill food")
	local c = character()
	local water = c and c:FindFirstChild("Water")
	if not water then
		return
	end

	local function nearestWell()
		local closest
		local terrain = workspace:FindFirstChild("Terrain")
		local waterFolder = terrain and terrain:FindFirstChild("Water")
		if not waterFolder then
			return nil
		end
		for _, well in next, waterFolder:GetChildren() do
			if well.Name:match("DrinkingWater") then
				if not closest then
					closest = well
				else
					local cd = (root().Position - closest:GetPivot().Position).Magnitude
					local d = (root().Position - well:GetPivot().Position).Magnitude
					if d < cd then
						closest = well
					end
				end
			end
		end
		return closest
	end

	if not (water.Value >= (water.MaxValue * 0.75)) then
		local well = nearestWell()
		if not well then
			return
		end
		playerSafeTween(well:GetPivot(), 250)
		repeat
			well = nearestWell()
			task.wait()
		until well or not running
		repeat
			pcall(function()
				Prompt.interact(well.InteractPrompt)
			end)
			task.wait(0.2)
		until (water.Value >= (water.MaxValue * 0.75)) or not running
	end
end

-- =========================================================================================================
-- Dungeon flow.
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

	playerSafeTween(ENTRANCE, ENTRANCE_SPEED, true, true) -- ground level (y=0) to the door; force 50 studs/s regardless of the Tween Speed slider
	pcall(function()
		travelNoclip:Disconnect()
	end)
	pcall(function()
		replicatedStorage.Requests.UpdateUXSettings:FireServer("FriendlyFire", true)
	end)

	local entry = workspace:WaitForChild("Map", 10)
	entry = entry and entry:WaitForChild("MeritEntry", 10)

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
		if playerCheck(PLAYER_SAFE_RADIUS, ENTRANCE.Position) then
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
	until tick() - start > 30 or game.PlaceId ~= EASTERN_PLACE_ID or not running

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

---Loot the relic chest (relic: open + force LOOT_ALL, then EXIT).
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

		if not (playerGui() and playerGui():FindFirstChild("ChoicePrompt")) then
			return
		end

		-- Force Loot All while the ChoicePrompt is up, then EXIT to close.
		local time = tick()
		repeat
			task.wait()
			local gui = playerGui()
			local cp = gui and gui:FindFirstChild("ChoicePrompt")
			if cp then
				pcall(function()
					cp:FindFirstChild("Choice"):FireServer("LOOT_ALL")
				end)
			end
		until not (playerGui() and playerGui():FindFirstChild("ChoicePrompt")) or not running or (tick() - time >= 3)

		local gui = playerGui()
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

---Deposit relic stacks (>= BANK_THRESHOLD) at the Banker.
local function bankRelics()
	setStage("banking relics")

	local npcs = workspace:FindFirstChild("NPCs")
	local banker = npcs and npcs:WaitForChild("Banker", 10)
	if not banker then
		return
	end

	pcall(function()
		playerSafeTween(banker.HumanoidRootPart.CFrame * CFrame.new(0, -6, 0), 150)
	end)
	pcall(function()
		local r = root()
		if r then
			r.CFrame = banker.HumanoidRootPart.CFrame * CFrame.new(0, -6, 0)
		end
	end)

	local sendDialogue = replicatedStorage.Requests.SendDialogue
	local dl = tick()
	repeat
		local dg = playerGui() and playerGui():FindFirstChild("DialogueGui")
		if dg and dg.Enabled then
			pcall(function()
				sendDialogue:FireServer({ choice = "Can I access my account?" })
			end)
		else
			pcall(function()
				Prompt.interact(banker.InteractPrompt)
			end)
		end
		task.wait(0.5)
	until (playerGui() and playerGui():FindFirstChild("BankGui")) or tick() - dl > 15 or not running

	local bankGui = playerGui() and playerGui():FindFirstChild("BankGui")
	if not bankGui then
		return
	end

	local function bankFull()
		local cp = playerGui() and playerGui():FindFirstChild("ChoicePrompt")
		if not cp then
			return false
		end
		local ds = cp:FindFirstChild("DescSheet", true)
		if not ds or not ds:FindFirstChild("Ok") then
			return false
		end
		local dc = ds:FindFirstChild("Desc", true)
		return dc ~= nil and dc.Text == "You don't have any bank slots free."
	end

	local function confirmMax()
		local cp = playerGui() and playerGui():FindFirstChild("ChoicePrompt")
		if not cp then
			return false
		end
		local mx = cp:GetAttribute("Max")
		local ch = cp:FindFirstChild("Choice")
		if mx and ch then
			task.spawn(function()
				pcall(function()
					ch:InvokeServer(mx)
				end)
			end)
			return true
		end
		return false
	end

	for name, selected in pairs(bankItems()) do
		if selected and countItem(name) >= BANK_THRESHOLD then
			local n = 0
			while countItem(name) > 0 and n < 6 and running do
				n = n + 1
				local before = countItem(name)
				local deposit = {}
				for _, item in next, backpack():GetChildren() do
					if item.Name == name then
						deposit[#deposit + 1] = item
					end
				end
				if #deposit == 0 then
					break
				end
				pcall(function()
					bankGui:WaitForChild("Choice"):FireServer("deposit", deposit)
				end)
				local bt = tick()
				repeat
					if bankFull() then
						Logger.notify("Bank full -- Auto Titus stopped.")
						AutoTitus.stop()
						return
					end
					confirmMax()
					task.wait(0.3)
				until countItem(name) < before or tick() - bt > 8 or not running
			end
		end
	end
end

-- =========================================================================================================
-- State machine.
-- =========================================================================================================
local function isCharacterCreation()
	local cc = workspace:FindFirstChild("CharacterCreator")
	local c = character()
	return cc ~= nil and c ~= nil and c.Parent == cc
end

---Tap a key once via VirtualInputManager (input-only; no remote).
local function pressKey(keyCode)
	pcall(function()
		local vim = Instance.new("VirtualInputManager")
		vim:SendKeyEvent(true, keyCode, false, game)
		vim:SendKeyEvent(false, keyCode, false, game)
	end)
end

---Blow through the loading screen and wait for our character to spawn into workspace.Live. While the
---LoadingGui is up, spams A to click through it (input-only -- the old Requests.StartMenu.Start remote
---is an anticheat honeypot, firing it = instant ban). Skipped in character creation.
local function requestStart()
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

-- Kept the name (callers unchanged); tears down the inline pathfind breaker (the Titus kill mechanism).
local function disableBreaker()
	stopTitusBreaker()
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
		local dist = AutoLog.get("auto_titus")
		if dist > 0 and playerCheck(dist) then
			serverHop()
			return
		end
	end
end

local stateMachine = StateMachine.create({
	initial = "idle",
	events = {
		{ name = "start", from = "idle", to = "_check_area" },
		{ name = "continuation", from = "_create_character", to = "_check_area" },
		{ name = "continuation", from = "_bank_relics", to = "_check_area" },
		{ name = "bank", from = "_check_area", to = "_bank_relics" },
		{ name = "cc", from = "_check_area", to = "_create_character" },
		{ name = "enter", from = "_check_area", to = "_enter_dungeon" },
		{ name = "run", from = "_check_area", to = "_run_dungeon" },
		{ name = "exit", from = "_run_dungeon", to = "_exit" },
	},
	callbacks = {
		onenter_check_area = function(self)
			if not running then
				return
			end
			setStage("check area")

			-- Merit / dungeon: existing character here, so it's safe to blow through the loading screen.
			if game.PlaceId == EASTERN_PLACE_ID then
				requestStart()
				-- Bank first if we're holding a full stack of any selected relic (cooldown-gated).
				for name, selected in pairs(bankItems()) do
					if selected and countItem(name) >= BANK_THRESHOLD and tick() - lastBank > BANK_COOLDOWN then
						lastBank = tick()
						return self:bank()
					end
				end
				-- No wipe: turn the breaker off in the hub, refill food if low, then enter.
				disableBreaker()
				if needFood() then
					refillFood()
				end
				return self:enter()
			end

			if game.PlaceId == DUNGEON_PLACE_ID then
				requestStart()
				return self:run()
			end

			-- Anywhere else (lobby / character creator): DO NOT fire StartMenu.Start -- that would rush the
			-- character creator and roll the wrong character. Wait patiently for the creator to come up.
			local deadline = os.clock() + 20
			repeat
				if isCharacterCreation() then
					return self:cc()
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

			-- Re-arm the watchdog off the shorter void cap now the fight's over, so the exit-wait + loot get a
			-- fresh ACTION_TIMEOUT instead of inheriting "fighting titus"'s 45s.
			setStage("boss defeated")

			-- Titus is down: reset the 30s DungeonExitFinal cap to measure from the KILL, not the dungeon-run
			-- start, so a slow fight can't eat the window the run gets to wait for the exit to spawn.
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

			disableBreaker()

			local r = root()
			if r then
				r.CFrame = r.CFrame * CFrame.new(0, 1300, 0)
			end

			xpcall(function()
				grabChest()
			end, function(err)
				Logger.notify("AutoTitus loot error: %s", tostring(err))
			end)

			task.wait(2)

			r = root()
			if r then
				r.CFrame = r.CFrame * CFrame.new(0, 1300, 0)
			end

			local hum2 = humanoid()
			if hum2 and hum2:GetAttribute("DangerExpiration") and hum2:GetAttribute("DangerExpiration") > 0 then
				repeat
					task.wait()
				until not (hum2:GetAttribute("DangerExpiration") and hum2:GetAttribute("DangerExpiration") > 0)
					or not running
			end

			self:exit()
		end,

		onenter_bank_relics = function(self)
			if not running then
				return
			end
			bankRelics()
			self:continuation()
		end,

		onenter_exit = function(self)
			if not running then
				return
			end
			setStage("respawn")
			-- Fast way out: replicate the Kill signal, then void ourselves if we somehow survived.
			if replicatesignal then
				pcall(function()
					replicatesignal(localPlayer().Kill)
				end)
				task.delay(1, function()
					local hum = humanoid()
					if hum and hum.Health <= 1 then
						return
					end
					local r = root()
					if r then
						r.CFrame = r.CFrame * CFrame.new(0, 9e9, 0)
					end
				end)
			else
				local r = root()
				if r then
					r.CFrame = r.CFrame * CFrame.new(0, 9e9, 0)
				end
			end
		end,
	},
})

-- =========================================================================================================
-- Struct.
-- =========================================================================================================
local function buildStruct()
	return AutomationStruct.construct({
		id = "auto_titus",
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
		},
	})
end

-- =========================================================================================================
-- Public interface.
-- =========================================================================================================
function AutoTitus.start()
	local lp = localPlayer()
	if not lp then
		return
	end
	if running then
		return
	end
	if not AutoTitus.inValidPlace() then
		return Logger.notify("Auto Titus: Not in Eastern Luminant")
	end

	local slot = currentSlot()
	if not slot then
		return Logger.notify("Auto Titus: no data slot found.")
	end

	local data = PersistentData.get("titusdata") or {}
	data.slot = slot
	data.startedAt = data.startedAt or os.time()
	PersistentData.set("titusdata", data)

	running = true
	buildOverlay()
	AntiAFK.start("AutoTitus")

	maid:mark(task.spawn(runElapsed))

	-- Keep No Fall Damage forced on for the entire farm (respawns / new characters can drop it).
	maid:mark(task.spawn(function()
		while running do
			if Toggles and Toggles.NoFallDamage and not Toggles.NoFallDamage.Value then
				Toggles.NoFallDamage:SetValue(true)
			end
			task.wait(0.25)
		end
	end))

	-- Ferryman-style auto log: hop if any player comes within 1000 studs.
	maid:mark(task.spawn(watchForPlayers))

	-- Per-action watchdog: rejoin if a stage (esp. the Titus void) stalls past its cap.
	maid:mark(task.spawn(runActionWatchdog))

	stateMachine.current = "idle"
	stateMachine.asyncState = StateMachine.NONE
	stateMachine.currentTransitioningEvent = nil

	struct = buildStruct()
	struct:run()
end

function AutoTitus.stop()
	if not running then
		return
	end
	running = false

	stopTitusBreaker()

	if struct then
		pcall(function()
			struct:stop()
		end)
		struct = nil
	end

	Tweening.stop(MOVE_ID)

	pcall(function()
		AntiAFK.stop("AutoTitus")
	end)

	maid:clean()
	destroyOverlay()

	PersistentData.set("titusdata", nil)
end

return AutoTitus
