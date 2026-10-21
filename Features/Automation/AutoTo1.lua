-- Auto To1: Trial of One automation. Started with a button (like Auto Ferryman), shows a status
-- overlay, and persists across server hops (resumes on re-execute). Only operates in the Etrean
-- Luminant.
--
-- Step 1: enable No Fall Damage and teleport to the Trial of One (reusing the script's teleport).
-- Further steps are appended to the step machine.
local AutoTo1 = { running = false }

---@module GUI.Library
local Library = require("GUI/Library")

---@module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Features.Game.Teleport
local Teleport = require("Features/Game/Teleport")

---@module Features.Game.Tweening
local Tweening = require("Features/Game/Tweening")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Features.Combat.Defense
local Defense = require("Features/Combat/Defense")

---@module Features.Automation.Objects.General
local General = require("Features/Automation/Objects/General")

local players = game:GetService("Players")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local fastSwingConn = nil

local localPlayer = players.LocalPlayer

-- The Etrean Luminant place (where the Trial of One entrance / teleport is available).
local ETREAN_LUMINANT_PLACE_ID = 6032399813

-- The Trial of One arena (dungeon place). After the teleport in the Etrean Luminant, we land here.
local TRIAL_ARENA_PLACE_ID = 8668476218
local ARENA_TWEEN_ID = "AutoTo1_Arena"
local LIVE_FOLDER = "Live"
-- How far below OneTrigger's Y level to sit while swinging up at the enemy.
local ENEMY_UNDER_OFFSET = 12
-- Swing interval while fighting (matches Auto Ferryman).
local SWING_INTERVAL = 0.3
-- Auto Defense filter turned off for the run (so defense works when the window isn't focused).
local WINDOW_FILTER = "Disable When Window Not Active"
-- Force a very fast tween speed for the run so movement is effectively instant.
local TWEEN_SPEED = 150
-- Tween speed while travelling to OneTrigger.
local ONETRIGGER_TWEEN_SPEED = 50

-- ============================================================================================
-- All Auto To1 text -- edit these to change the on-screen action text and notifications.
-- Entries with %s / %d are format strings (the values are filled in at runtime).
-- ============================================================================================
local TEXT = {
	-- Overlay
	overlayTitle = "Auto To1",
	actionPrefix = "Current Action: ", -- prepended to every action; the empty form is below
	actionPrefixEmpty = "Current Action:",
	elapsed = "Elapsed: %02d:%02d",
	stopButton = "Stop",

	-- Notifications
	notInPlace = "Auto To1: not in the Etrean Luminant or Trial of One.",

	-- Current action text
	teleportingToTrial = "teleporting",
	waitingForOneTrigger = "loading...",
	tweeningToOneTrigger = "tweening",
	waitingForEnemy = "manually invest your points or use auto builder",
	fightingEnemy = "fighting enemy",
	waitingForTrial = "loading...",
	completing = "Trial of One complete, kicking...",

	-- Kick message shown after the trial is finished (alpha killed).
	kickMessage = "Trial of One complete",
}

local screenGui, actionLabel, timerLabel = nil, nil, nil
local timerConnection, stepConnection, characterAddedConnection, weaponConnection = nil, nil, nil, nil

-- Set true once we've reached OneTrigger; from then on we keep the weapon drawn.
local weaponWanted = false

-- Step machine + run state.
local step = 0
local previousNoFall = nil
local previousFly = nil
local previousPathfind = nil
local previousAutoDefense = nil
local previousBlockInput = nil
local previousAutoFeint = nil
local previousVoidMobs = nil
local previousTweenSpeed = nil
local removedWindowFilter = false
local startClock = 0

-- Trial completion: track whether an "alpha" enemy has been present, and when it's gone start a 5s
-- countdown before kicking the player out.
local alphaWasPresent = false
local completeAt = nil

-- ============================================================================================
-- Helpers
-- ============================================================================================

---@return boolean
function AutoTo1.inEtreanLuminant()
	return game.PlaceId == ETREAN_LUMINANT_PLACE_ID
end

---@return boolean
function AutoTo1.inArena()
	return game.PlaceId == TRIAL_ARENA_PLACE_ID
end

---Whether we're somewhere the automation can operate (start / resume).
---@return boolean
function AutoTo1.inValidPlace()
	return AutoTo1.inEtreanLuminant() or AutoTo1.inArena()
end

---@return Instance?
local function guiParent()
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and coreGui then
		return coreGui
	end
	return localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
end

---@param class string
---@param props table
---@param parent Instance?
---@return Instance
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

---@param seconds number
---@return string
local function formatElapsed(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format(TEXT.elapsed, minutes, secs)
end

---@return any
local function currentSlot()
	return localPlayer and localPlayer:GetAttribute("DataSlot")
end

---Persist the resume flag + slot so the automation survives a server hop.
local function saveState()
	PersistentData.set("to1data", { active = true, slot = currentSlot() })
end

---@param text string?
local function setAction(text)
	if not actionLabel then
		return
	end
	actionLabel.Text = (text and text ~= "") and (TEXT.actionPrefix .. text) or TEXT.actionPrefixEmpty
end

---Force a toggle to a value, returning its previous value (or nil if the toggle doesn't exist).
---@param name string
---@param value boolean
---@return boolean?
local function setToggle(name, value)
	if not Toggles or not Toggles[name] then
		return nil
	end
	local previous = Toggles[name].Value
	Toggles[name]:SetValue(value)
	return previous
end

---Force a toggle on, returning its previous value.
---@param name string
---@return boolean?
local function forceToggle(name)
	return setToggle(name, true)
end

---Set the global tween speed (only writes when it actually changes, to avoid callback spam).
---@param value number
local function setTweenSpeed(value)
	value = (Options and Options.To1TweenSpeed and Options.To1TweenSpeed.Value) or 100
	if Options and Options.TweenStudsPerSecond and Options.TweenStudsPerSecond.Value ~= value then
		Options.TweenStudsPerSecond:SetValue(value)
	end
end

---The user's normal tween speed captured at start (fallback 200).
---@return number
local function normalTweenSpeed()
	return previousTweenSpeed or 200
end

---Restore a toggle to a remembered value (no-op if nil).
---@param name string
---@param previous boolean?
local function restoreToggle(name, previous)
	if previous ~= nil and Toggles and Toggles[name] then
		Toggles[name]:SetValue(previous)
	end
end

---Turn off the "Disable When Window Not Active" Auto Defense filter for the run (so defense/block
---input still work when the Roblox window isn't focused), remembering whether it was on.
local function applyDefenseFilter()
	local option = Options and Options.AutoDefenseFilters
	if not option then
		return
	end

	local current = option.Value or {}
	removedWindowFilter = current[WINDOW_FILTER] == true
	if not removedWindowFilter then
		return
	end

	local newValue = {}
	for key, value in pairs(current) do
		newValue[key] = value
	end
	newValue[WINDOW_FILTER] = nil
	option:SetValue(newValue)
end

local function restoreDefenseFilter()
	local option = Options and Options.AutoDefenseFilters
	if option and removedWindowFilter then
		local newValue = {}
		for key, value in pairs(option.Value or {}) do
			newValue[key] = value
		end
		newValue[WINDOW_FILTER] = true
		option:SetValue(newValue)
	end
	removedWindowFilter = false
end

---Turn on the run's toggles: No Fall Damage, Fly, Auto Defense + Block Input + Auto Feint + Void Mobs
---(and remove the window filter) -- mirrors Auto Ferryman's combat setup.
local function applyToggles()
	if previousNoFall == nil then
		previousNoFall = forceToggle("NoFallDamage")
	end
	if previousFly == nil then
		previousFly = forceToggle("Fly")
	end
	-- Pathfind Breaker must be OFF for this automation.
	if previousPathfind == nil then
		previousPathfind = setToggle("Fling", false)
	end
	if previousAutoDefense == nil then
		previousAutoDefense = forceToggle("EnableAutoDefense")
	end
	if previousBlockInput == nil then
		previousBlockInput = forceToggle("BlockInput")
	end
	if previousAutoFeint == nil then
		previousAutoFeint = forceToggle("AutoFeint")
	end
	if previousVoidMobs == nil then
		previousVoidMobs = forceToggle("VoidMobs")
	end

	-- Remember the user's tween speed so we can flip to a fast speed only while fighting.
	if previousTweenSpeed == nil and Options and Options.TweenStudsPerSecond then
		previousTweenSpeed = Options.TweenStudsPerSecond.Value
	end

	-- Fast swing: strip attack cooldowns so m1s aren't rate-limited during the fight.
	if not fastSwingConn then
		fastSwingConn = General.connectFastSwing()
	end

	applyDefenseFilter()
end

local function restoreToggles()
	if fastSwingConn then
		pcall(function()
			fastSwingConn:Disconnect()
		end)
		fastSwingConn = nil
	end
	restoreToggle("NoFallDamage", previousNoFall)
	restoreToggle("Fly", previousFly)
	restoreToggle("Fling", previousPathfind)
	restoreToggle("EnableAutoDefense", previousAutoDefense)
	restoreToggle("BlockInput", previousBlockInput)
	restoreToggle("AutoFeint", previousAutoFeint)
	restoreToggle("VoidMobs", previousVoidMobs)
	if previousTweenSpeed ~= nil and Options and Options.TweenStudsPerSecond then
		Options.TweenStudsPerSecond:SetValue(previousTweenSpeed)
	end
	previousTweenSpeed = nil
	previousNoFall = nil
	previousFly = nil
	previousPathfind = nil
	previousAutoDefense = nil
	previousBlockInput = nil
	previousAutoFeint = nil
	previousVoidMobs = nil

	restoreDefenseFilter()
end

---Press a key (used to blow through the loading screen).
---@param keyCode Enum.KeyCode
local function pressKey(keyCode)
	pcall(function()
		local vim = Instance.new("VirtualInputManager")
		vim:SendKeyEvent(true, keyCode, false, game)
		vim:SendKeyEvent(false, keyCode, false, game)
	end)
end

---Whether the character + backpack have replicated in.
---@return boolean
local function requirementsMet()
	local character = localPlayer and localPlayer.Character
	if not character then
		return false
	end
	local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
	return backpack ~= nil and #backpack:GetChildren() > 0
end

---Whether the weapon is currently drawn (the "Equipped" effect is present).
---@return boolean
local function isWeaponDrawn()
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local module = effectReplicator and require(effectReplicator)
	if not module then
		return false
	end
	local ok, has = pcall(function()
		return module:HasEffect("Equipped")
	end)
	return ok and has == true
end

---Draw the weapon by firing the game's DrawWeapon remote.
local function drawWeapon()
	local character = localPlayer and localPlayer.Character
	local handler = character and character:FindFirstChild("CharacterHandler")
	local requests = handler and handler:FindFirstChild("Requests")
	local drawEvent = requests and requests:FindFirstChild("DrawWeapon")
	if not drawEvent then
		return
	end
	pcall(function()
		drawEvent:FireServer(true)
	end)
end

---The first live entity in workspace.Live that isn't our own character (an enemy), or nil.
---@return Instance?
local function findEnemyInLive()
	local live = workspace:FindFirstChild(LIVE_FOLDER)
	if not live then
		return nil
	end

	local myCharacter = localPlayer and localPlayer.Character

	for _, entity in next, live:GetChildren() do
		if entity == myCharacter then
			continue
		end

		-- Skip anything with "hostage" in the name so we never target the trial hostages.
		if string.find(string.lower(entity.Name), "hostage", 1, true) then
			continue
		end

		local humanoid = entity:FindFirstChildWhichIsA("Humanoid")
		local root = entity:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			return entity
		end
	end

	return nil
end

---Whether any live entity in workspace.Live has "alpha" in its name (the trial's final boss).
---@return boolean
local function alphaEnemyPresent()
	local live = workspace:FindFirstChild(LIVE_FOLDER)
	if not live then
		return false
	end

	local myCharacter = localPlayer and localPlayer.Character

	for _, entity in next, live:GetChildren() do
		if entity == myCharacter then
			continue
		end
		if not string.find(string.lower(entity.Name), "alpha", 1, true) then
			continue
		end

		local humanoid = entity:FindFirstChildWhichIsA("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return true
		end
	end

	return false
end

-- ============================================================================================
-- Status overlay
-- ============================================================================================

local function buildOverlay()
	if screenGui then
		return
	end

	screenGui = CoreGuiManager.imark(Instance.new("ScreenGui"))
	screenGui.Name = "LumaAutoTo1Overlay"
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
		Size = UDim2.new(0, 300, 0, 120),
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
		Text = TEXT.overlayTitle,
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(title, { TextColor3 = "AccentColor" })

	actionLabel = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 30),
		Size = UDim2.new(1, -16, 0, 34),
		FontFace = Library.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Library.FontColor or Color3.new(1, 1, 1),
		TextWrapped = true,
		Text = TEXT.actionPrefixEmpty,
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(actionLabel, { TextColor3 = "FontColor" })

	timerLabel = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 66),
		Size = UDim2.new(1, -16, 0, 20),
		FontFace = Library.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Library.FontColor or Color3.new(1, 1, 1),
		Text = formatElapsed(0),
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(timerLabel, { TextColor3 = "FontColor" })

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
		Text = TEXT.stopButton,
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
		AutoTo1.stop()
	end)

	pcall(function()
		Library:MakeDraggable(outer)
	end)

	screenGui.Enabled = false
end

-- ============================================================================================
-- Step machine
-- ============================================================================================

local function runStep()
	-- ---- Etrean Luminant: teleport to the Trial of One (toggles already applied on start) ----
	if AutoTo1.inEtreanLuminant() then
		if step == 0 then
			setAction(TEXT.teleportingToTrial)
			Teleport.start("TrialOfOne")
			step = 1
		end
		return
	end

	-- ---- Trial arena (8668476218): go to workspace.One.OneTrigger, then fight enemies ----
	if AutoTo1.inArena() then
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		-- Trial completion: once an "alpha" enemy that was present is gone, wait 5s then kick out.
		if alphaEnemyPresent() then
			alphaWasPresent = true
		elseif alphaWasPresent and completeAt == nil then
			completeAt = os.clock() + 5
		end

		if completeAt then
			setAction(TEXT.completing)
			if os.clock() >= completeAt then
				-- Clear the resume flag so it doesn't restart, then kick.
				PersistentData.set("to1data", nil)
				pcall(function()
					localPlayer:Kick(TEXT.kickMessage)
				end)
			end
			return
		end

		-- Resolve workspace.One.OneTrigger's position (part or model).
		local one = workspace:FindFirstChild("One")
		local trigger = one and one:FindFirstChild("OneTrigger")
		if not trigger then
			setAction(TEXT.waitingForOneTrigger)
			return
		end

		local triggerPos = trigger:IsA("BasePart") and trigger.Position or trigger:GetPivot().Position

		if step == 0 then
			-- Slow tween speed + Pathfind Breaker off while travelling to OneTrigger.
			setTweenSpeed(ONETRIGGER_TWEEN_SPEED)
			setToggle("Fling", false)
			setAction(TEXT.tweeningToOneTrigger)
			Tweening.goal(ARENA_TWEEN_ID, CFrame.new(triggerPos), false)

			if (root.Position - triggerPos).Magnitude <= 3 then
				-- Reached OneTrigger: draw the weapon and keep it drawn from here on, then wait for an
				-- enemy (no wait timer).
				weaponWanted = true
				drawWeapon()
				step = 2
			end
			return
		end

		if step == 2 then
			-- Normal tween speed + Pathfind Breaker off while holding + waiting for an enemy.
			setTweenSpeed(normalTweenSpeed())
			setToggle("Fling", false)
			Tweening.goal(ARENA_TWEEN_ID, CFrame.new(triggerPos), false)
			setAction(TEXT.waitingForEnemy)

			if findEnemyInLive() then
				step = 3
			end
			return
		end

		-- Step 3: fight -- fast-tween onto the enemy and m1 until it's gone, then wait for the next.
		local enemy = findEnemyInLive()
		if not enemy then
			-- Enemy dead / despawned: back to normal speed, Pathfind Breaker off, wait for more enemies.
			setTweenSpeed(normalTweenSpeed())
			setToggle("Fling", false)
			step = 2
			return
		end

		local ok, enemyCFrame = pcall(function()
			return enemy:GetPivot()
		end)
		if ok then
			local enemyPos = enemyCFrame.Position
			local targetCFrame

			local lowerName = string.lower(enemy.Name)
			local isEnforcer = string.find(lowerName, "enforcer", 1, true) ~= nil

			-- Fling stays OFF for this automation (never flings, even on enforcers).
			setToggle("Fling", false)

			setAction(TEXT.fightingEnemy)

			if string.find(lowerName, "stoneknight", 1, true) or isEnforcer then
				-- Stoneknight / Enforcer: stay 5 studs behind it and 8 studs above it, facing it.
				local behind = enemyPos - (enemyCFrame.LookVector * 5) + Vector3.new(0, 8, 0)
				targetCFrame = CFrame.lookAt(behind, enemyPos)
			else
				-- Track the enemy horizontally but hold the Y under OneTrigger, facing up at it (small
				-- nudge keeps CFrame.lookAt stable when directly overhead).
				local underPos = Vector3.new(enemyPos.X + 0.1, triggerPos.Y - ENEMY_UNDER_OFFSET, enemyPos.Z)
				targetCFrame = CFrame.lookAt(underPos, enemyPos)
			end

			-- Fast tween speed ONLY while fighting, so positioning onto the enemy is effectively instant.
			setTweenSpeed(TWEEN_SPEED)
			Tweening.goal(ARENA_TWEEN_ID, targetCFrame, false)

			-- Respect Block Input: don't swing while it wants to hold our M1 (block/punish window).
			if not Defense.shouldBlockInput("M1s") then
				local aim = CFrame.new(root.Position, enemyPos)
				pcall(function()
					InputClient.left(aim, true)
				end)
			end
		end
		return
	end

	-- Neither place yet -- wait.
	setAction(TEXT.waitingForTrial)
end

-- ============================================================================================
-- Start / stop
-- ============================================================================================

local function teardown()
	AutoTo1.running = false

	if timerConnection then
		pcall(function()
			timerConnection:Disconnect()
		end)
		timerConnection = nil
	end
	if stepConnection then
		pcall(function()
			stepConnection:Disconnect()
		end)
		stepConnection = nil
	end
	if characterAddedConnection then
		pcall(function()
			characterAddedConnection:Disconnect()
		end)
		characterAddedConnection = nil
	end
	if weaponConnection then
		pcall(function()
			weaponConnection:Disconnect()
		end)
		weaponConnection = nil
	end

	weaponWanted = false

	pcall(function()
		Tweening.stop(ARENA_TWEEN_ID)
	end)
	pcall(Teleport.stop)
	restoreToggles()

	if screenGui then
		screenGui.Enabled = false
	end
end

function AutoTo1.start()
	if AutoTo1.running then
		return
	end

	if not AutoTo1.inValidPlace() then
		return Logger.notify(TEXT.notInPlace)
	end

	-- If the loading screen (LoadingGui) is up (e.g. we just resumed after a place teleport), fire the
	-- StartMenu.Start remote to blow through it until the character + backpack have replicated (10s cap).
	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui and playerGui:FindFirstChild("LoadingGui") then
		local deadline = os.clock() + 10
		while not requirementsMet() and os.clock() < deadline do
			General.fireStartMenu()
			task.wait(0.25)
		end
	end

	step = 0
	weaponWanted = false
	alphaWasPresent = false
	completeAt = nil
	startClock = os.clock()
	AutoTo1.running = true

	-- Resume flag: survives server hops (MemStorage), so it restarts on the next server.
	saveState()

	-- No Fall Damage + Fly + Auto Defense/Block Input/Auto Feint + Void Mobs on for the run.
	applyToggles()

	buildOverlay()
	setAction(nil)
	if timerLabel then
		timerLabel.Text = formatElapsed(0)
	end
	if screenGui then
		screenGui.Enabled = true
	end

	-- Re-run current step if we respawn mid-automation.
	characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
		if not AutoTo1.running then
			return
		end
		task.wait(0.2)
	end)

	-- Elapsed timer.
	timerConnection = runService.Heartbeat:Connect(function()
		if not AutoTo1.running then
			return
		end
		if timerLabel then
			timerLabel.Text = formatElapsed(os.clock() - startClock)
		end
	end)

	-- Keep the weapon drawn: once we've reached OneTrigger, continuously check if it's not drawn and
	-- fire the DrawWeapon remote if so.
	weaponConnection = runService.Heartbeat:Connect(function()
		if not AutoTo1.running or not weaponWanted then
			return
		end
		if not isWeaponDrawn() then
			drawWeapon()
		end
	end)

	-- Step machine (throttled).
	local lastStepAt = 0
	stepConnection = runService.Heartbeat:Connect(function()
		if not AutoTo1.running then
			return
		end
		if os.clock() - lastStepAt < 0.25 then
			return
		end
		lastStepAt = os.clock()
		runStep()
	end)
end

function AutoTo1.stop()
	if not AutoTo1.running and not PersistentData.get("to1data") then
		return
	end

	teardown()

	-- Manual stop: clear the resume flag so a re-execute doesn't restart it.
	PersistentData.set("to1data", nil)
end

function AutoTo1.init()
	if not LPH_OBFUSCATED or (shared.Aero and shared.Aero.verbose) then
		Logger.warn("Auto To1 initialized.")
	end
end

return AutoTo1
