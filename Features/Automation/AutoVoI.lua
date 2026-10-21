-- Auto VoI: automation for the Voice of Insanity area. Started with a button, shows an Auto-Ferryman
-- style status overlay (title / current action / elapsed / timeout / stop) and persists across server
-- hops (resumes on re-execute). Only operates in the VoI place.
--
-- Step 1: if the player is within range of the VoI point, pathfind (walk) to it. Further steps are
-- appended to the routine.
local AutoVoI = { running = false }

---@module GUI.Library
local Library = require("GUI/Library")

---@module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.SafeClick
local safeClick = require("Utility/SafeClick")

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.Prompt
local Prompt = require("Utility/Prompt")

---@module Features.Game.Tweening
local Tweening = require("Features/Game/Tweening")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Game.Objects.DodgeOptions
local DodgeOptions = require("Game/Objects/DodgeOptions")

local players = game:GetService("Players")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local virtualInputManager = game:GetService("VirtualInputManager")

local localPlayer = players.LocalPlayer

-- Only runs in this place.
local VOI_PLACE_ID = 86761619761103

-- The Shogun arena (dungeon place). Reached after teleporting to ShogunBoundary.
local ARENA_PLACE_ID = 8668476218

-- The VoI point + how close we must be to fire the choice.
local VOI_TARGET = Vector3.new(-36654.328125, 7897.25390625, 1524.28271484375)
local WITHIN_DISTANCE = 2000

-- The nil "Choice" remote to fire, and the argument for entering the VoI.
local CHOICE_REMOTE_NAME = "Choice"
local CHOICE_ARGUMENT = "Aratel Wilderness Boundary"

-- When out of range, fly (tween) to this X/Z at TWEEN_ALTITUDE, then drop to DROP_Y and wait for the
-- ShogunBoundary part.
local CROSSING_X = -8980.2431640625
local CROSSING_Z = -4045.797607421875
local TWEEN_ALTITUDE = 20000
local DROP_Y = 900
local TWEEN_ID = "AutoVoI_Tween"
local TWEEN_SPEED = 150
local ARRIVE_DISTANCE = 6
local SHOGUN_PART_NAME = "ShogunBoundary"
-- Parts to teleport to after the shogun dies (DungeonExit -> back to main VoI) and then onward.
local DUNGEON_EXIT_NAME = "DungeonExit"
local TEMPLE_BOUNDARY_NAME = "Temple of Mur Boundary"

-- Temple of Mur shop: interact with this handler NPC and repeatedly click the Power Recall Buy button
-- until we're below this many notes.
-- While waiting for the Temple of Mur boundary to load, hold at this position to stream it in.
local TEMPLE_WAIT_POS = Vector3.new(-9009.1904296875, 825.3460083007812, -4120.7724609375)
local NPCS_FOLDER = "NPCs"
local HANDLER_NPC_NAME = "Your Handler"
local INTERACT_PROMPT_NAME = "InteractPrompt"
local MIN_NOTES = 500
-- Path to the Buy button under PlayerGui.
local BUY_BUTTON_PATH = {
	"DialogueGui",
	"DialogueExtents",
	"ShopFrame",
	"Category_Recollection",
	"Items",
	"Power Recall",
	"ContextFrame",
	"Buy",
}

-- After spending notes: go to the Golden Rat boundary and fight the Rat King (same as the shogun).
local GOLDENRAT_BOUNDARY_NAME = "GoldenRatBoundary"
-- Hold here while waiting for the Golden Rat boundary to load.
local GOLDENRAT_WAIT_POS = Vector3.new(-2828.678466796875, 65.59410095214844, -3287.2890625)
-- The Rat King shares the boss arena (ARENA_PLACE_ID); its Live entity name contains this.
local RATKING_ENEMY_MATCH = "ratking"

-- Enmity is an arena-only boss (ARENA_PLACE_ID); its Live entity name contains this. It spawns
-- "enforcer" adds -- any OTHER live enemy in the arena -- which we clear first before the boss.
local ENMITY_ENEMY_MATCH = "enmity"
local ENMITY_BEHIND = 15 -- Studs behind the boss while following.
local ENMITY_ABOVE = 10 -- Studs above the boss while following.
local ENMITY_ENFORCER_BEHIND = 3 -- Studs behind an enforcer while following.
local ENMITY_ENFORCER_ABOVE = 3 -- Studs above an enforcer while following.

-- Boss fight: tween in front of any Live entity whose name contains the match and M1.
local SHOGUN_ENEMY_MATCH = "shogun"
local FIGHT_TWEEN_ID = "AutoVoI_Fight"
local FIGHT_TWEEN_SPEED = 50
-- How far in front of the boss to stand.
local FIGHT_FRONT_OFFSET = 5
-- Rat King ownership-void (same as mira's Titus farm): stand INSIDE it with Pathfind Breaker + Void
-- Mobs forced on to steal network ownership, then the void-mobs pipeline drops it through the map.
-- Rat King fight: stay behind + above it with normal Pathfind Breaker, holding m1.
local RATKING_BEHIND = 7 -- Studs behind the boss.
local RATKING_ABOVE = 3 -- Studs above the boss.
local RATKING_TWEEN_SPEED = 10 -- Normal follow speed (matches the far-crawl speed, so it's always 10).
local RATKING_FAR_DISTANCE = 500 -- Beyond this the boss has blinked away...
local RATKING_FAR_SPEED = 10 -- ...so crawl instead of flinging across the map.
local RATKING_DODGE_ABOVE = 500 -- Snap this far above it while it plays an Action-priority move.
local SHOGUN_DODGE_ABOVE = 500 -- Same, for the shogun.
local VOID_Y_THRESHOLD = -2000 -- Below this Y we count as "in the void".
local VOID_LIFT_STUDS = 10000 -- How high above the safe spot to hold during void self-recovery.
local WEAPON_NAME = "Weapon"

-- Character highlight while running (same as Auto Ferryman).
local HIGHLIGHT_FILL = Color3.fromRGB(0, 120, 255)
local HIGHLIGHT_OUTLINE = Color3.fromRGB(120, 190, 255)

-- Timeout (seconds) -- every action re-arms this.
local DEFAULT_TIMEOUT = 5 * 60

-- ============================================================================================
-- All Auto VoI text -- edit these to change the on-screen action text and notifications.
-- ============================================================================================
local TEXT = {
	overlayTitle = "Auto VoI",
	actionPrefix = "Current Action: ",
	actionPrefixEmpty = "Current Action:",
	elapsed = "Elapsed: %02d:%02d",
	timeout = "Timeout: %02d:%02d",
	timeoutNone = "Timeout: --",
	stopButton = "Stop",

	notInPlace = "Auto VoI: not in the VoI place.",
	timedOut = "Auto VoI: timed out.",

	checkingDistance = "checking distance to VoI",
	tooFar = "too far from VoI (idle)",
	firing = "entering VoI",
	remoteMissing = "choice remote not found",
	tweening = "flying to the boundary",
	dropping = "descending",
	teleportingCrossing = "teleporting near the boundary",
	waitingShogun = "waiting for ShogunBoundary",
	teleportingShogun = "teleporting to ShogunBoundary",
	waitingForBoss = "waiting for the boss",
	waitingForShogun = "waiting for the shogun",
	fightingShogun = "fighting the shogun",
	waitingDungeonExit = "waiting for DungeonExit",
	teleportingDungeonExit = "teleporting to DungeonExit",
	waitingTemple = "waiting for Temple of Mur",
	teleportingTemple = "teleporting to Temple of Mur",
	waitingHandler = "waiting for the handler",
	interacting = "talking to the handler",
	buying = "buying Power Recall",
	waitingGoldenRat = "waiting for GoldenRatBoundary",
	teleportingGoldenRat = "teleporting to GoldenRatBoundary",
	waitingForRatKing = "waiting for the rat king",
	fightingRatKing = "fighting the rat king",
	waitingForEnmity = "waiting for Enmity",
	fightingEnmity = "fighting Enmity",
	fightingEnforcers = "clearing enforcers",
	notInArena = "Auto VoI: Start Enmity only works in the boss arena.",
	done = "done",
}

local screenGui, actionLabel, timerLabel, timeoutLabel = nil, nil, nil, nil
local timerConnection, characterAddedConnection, noclipConnection = nil, nil, nil
local highlight = nil

local startClock = 0
local timeoutDeadline = nil
local previousTweenSpeed = nil
local previousPathfind = nil
local previousAggressive = nil
local previousFly = nil
local previousNoFall = nil
local previousVoidMobs = nil
local previousAutoDefense = nil
local previousBlockInput = nil
local previousAutoFeint = nil
local previousM1Hold = nil
local m1Held = false

-- Which boss this run targets ("shogun" or "ratking"). Persisted so it survives the place teleport
-- into the arena.
local currentTarget = nil

-- ============================================================================================
-- Helpers
-- ============================================================================================

---@return boolean
function AutoVoI.inPlace()
	return game.PlaceId == VOI_PLACE_ID
end

---@return boolean
function AutoVoI.inArena()
	return game.PlaceId == ARENA_PLACE_ID
end

---Whether we're somewhere the automation can operate (start / resume).
---@return boolean
function AutoVoI.inValidPlace()
	return AutoVoI.inPlace() or AutoVoI.inArena()
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
local function formatClock(fmt, seconds)
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format(fmt, minutes, secs)
end

---@return any
local function currentSlot()
	return localPlayer and localPlayer:GetAttribute("DataSlot")
end

local function saveState()
	PersistentData.set("voidata", {
		active = true,
		slot = currentSlot(),
		target = currentTarget,
	})
end

---Arm the action timeout to `seconds` from now (nil clears it).
---@param seconds number?
local function armTimeout(seconds)
	timeoutDeadline = seconds and (os.clock() + seconds) or nil
end

---Set the "Current Action" line. Each call counts as progress, so it re-arms the default timeout.
---@param text string?
local function setAction(text)
	if actionLabel then
		actionLabel.Text = (text and text ~= "") and (TEXT.actionPrefix .. text) or TEXT.actionPrefixEmpty
	end
	armTimeout(DEFAULT_TIMEOUT)
end

---@return Model?, Humanoid?, BasePart?
local function characterParts()
	local character = localPlayer and localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

---Set the global tween speed (only writes when it actually changes).
---@param value number
local function setTweenSpeed(value)
	value = (Options and Options.VoITweenSpeed and Options.VoITweenSpeed.Value) or 100
	if Options and Options.TweenStudsPerSecond and Options.TweenStudsPerSecond.Value ~= value then
		Options.TweenStudsPerSecond:SetValue(value)
	end
end

---Auto Ferryman's custom noclip: every frame drop CanCollide on all character parts, force the
---AirController so the ground can't hold us, and zero velocity so physics can't fight teleports.
local function applyNoClip()
	if noclipConnection then
		return
	end

	noclipConnection = runService.Stepped:Connect(function()
		if not AutoVoI.running then
			return
		end

		local character = localPlayer and localPlayer.Character
		if not character then
			return
		end

		for _, part in next, character:GetDescendants() do
			if part:IsA("BasePart") then
				pcall(function()
					if part.CanCollide then
						part.CanCollide = false
					end
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
				end)
			end
		end

		local controllerManager = character:FindFirstChild("ControllerManager")
		local airController = controllerManager and controllerManager:FindFirstChild("AirController")
		if controllerManager and airController then
			pcall(function()
				controllerManager.ActiveController = airController
			end)
		end
	end)
end

local function restoreNoClip()
	if noclipConnection then
		pcall(function()
			noclipConnection:Disconnect()
		end)
		noclipConnection = nil
	end
end

---Whether a position is inside the void kill volume.
---@param position Vector3
---@return boolean
local function isVoidPosition(position)
	return position.Y <= VOID_Y_THRESHOLD
end

---Is our roll off cooldown right now (mirrors mira's isRollReady)?
---@return boolean
local function isRollReady()
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local module = effectReplicator and require(effectReplicator)
	if not module then
		return false
	end
	local ok, blocked = pcall(function()
		return module:HasEffect("Dodge")
			or module:HasEffect("Dodged")
			or module:HasEffect("NoRoll")
			or module:HasEffect("PreventRoll")
	end)
	return ok and not blocked
end

---Fire a direct roll the instant it's off cooldown (to survive while standing in the boss).
local function spamRoll()
	if not isRollReady() then
		return
	end
	local options = DodgeOptions.new()
	options.direct = true
	pcall(function()
		InputClient.dodge(options)
	end)
end

---Hold / release the left mouse button (drives Defense's M1 Hold, which respects block input + feint).
---@param down boolean
local function holdM1(down)
	if m1Held == down then
		return
	end
	m1Held = down
	pcall(function()
		virtualInputManager:SendMouseButtonEvent(0, 0, 0, down, game, 0)
	end)
end

---Whether a model is currently playing an Action-priority animation track.
---@param model Instance
---@return boolean
local function isPlayingActionAnim(model)
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return false
	end
	local ok, tracks = pcall(function()
		return animator:GetPlayingAnimationTracks()
	end)
	if not ok or not tracks then
		return false
	end
	for _, track in ipairs(tracks) do
		if track.IsPlaying and track.Priority == Enum.AnimationPriority.Action then
			return true
		end
	end
	return false
end

---Do we currently have network ownership of a part?
---@param part BasePart
---@return boolean
local function weOwn(part)
	if not isnetworkowner then
		return false
	end
	local ok, owned = pcall(isnetworkowner, part)
	return ok and owned == true
end

---Keep physics from sleeping so we don't lose ownership of held parts.
local function keepAwake()
	pcall(function()
		settings().Physics.AllowSleep = false
	end)
end

---Max out the simulation radius so we can take/keep network ownership of the boss from any distance.
local function maxSimulationRadius()
	pcall(function()
		if setsimulationradius then
			setsimulationradius(math.huge, math.huge)
		else
			sethiddenproperty(localPlayer, "MaxSimulationRadius", 9e9)
			sethiddenproperty(localPlayer, "SimulationRadius", 9e9)
		end
	end)
end

---Force Fly on for the run, remembering its previous state.
local function applyFly()
	if Toggles and Toggles.Fly then
		if previousFly == nil then
			previousFly = Toggles.Fly.Value
		end
		Toggles.Fly:SetValue(true)
	end
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

---Draw the weapon (fire DrawWeapon remote, fall back to EquipTool).
local function drawWeapon()
	local character = localPlayer and localPlayer.Character
	local handler = character and character:FindFirstChild("CharacterHandler")
	local requests = handler and handler:FindFirstChild("Requests")
	local drawEvent = requests and requests:FindFirstChild("DrawWeapon")
	if drawEvent then
		pcall(function()
			drawEvent:FireServer(true)
		end)
		return
	end

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild(WEAPON_NAME)
	if humanoid and tool and tool:IsA("Tool") then
		pcall(function()
			humanoid:EquipTool(tool)
		end)
	end
end

---The first live entity in workspace.Live whose name contains `match`, or nil.
---@param match string
---@return Instance?
local function findLiveEnemyMatching(match)
	local live = workspace:FindFirstChild("Live")
	if not live then
		return nil
	end

	local myCharacter = localPlayer and localPlayer.Character

	for _, entity in next, live:GetChildren() do
		if entity == myCharacter then
			continue
		end
		if not string.find(string.lower(entity.Name), match, 1, true) then
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

---Highlight the local character while running (re-adorns if it already exists).
local function applyHighlight()
	local character = localPlayer and localPlayer.Character
	if not character then
		return
	end

	if highlight and highlight.Parent then
		highlight.Adornee = character
		highlight.Parent = character
		return
	end

	highlight = CoreGuiManager.imark(Instance.new("Highlight"))
	highlight.Name = "LumaAutoVoIHighlight"
	highlight.FillColor = HIGHLIGHT_FILL
	highlight.OutlineColor = HIGHLIGHT_OUTLINE
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = character
end

local function removeHighlight()
	if highlight then
		pcall(function()
			highlight:Destroy()
		end)
		highlight = nil
	end
end

-- ============================================================================================
-- Status overlay
-- ============================================================================================

local function buildOverlay()
	if screenGui then
		return
	end

	screenGui = CoreGuiManager.imark(Instance.new("ScreenGui"))
	screenGui.Name = "LumaAutoVoIOverlay"
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
		Size = UDim2.new(0, 300, 0, 150),
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
		Position = UDim2.new(0, 8, 0, 68),
		Size = UDim2.new(1, -16, 0, 20),
		FontFace = Library.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Library.FontColor or Color3.new(1, 1, 1),
		Text = formatClock(TEXT.elapsed, 0),
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(timerLabel, { TextColor3 = "FontColor" })

	timeoutLabel = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 90),
		Size = UDim2.new(1, -16, 0, 20),
		FontFace = Library.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Library.FontColor or Color3.new(1, 1, 1),
		Text = TEXT.timeoutNone,
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(timeoutLabel, { TextColor3 = "FontColor" })

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
		AutoVoI.stop()
	end)

	pcall(function()
		Library:MakeDraggable(outer)
	end)

	screenGui.Enabled = false
end

-- ============================================================================================
-- Routine
-- ============================================================================================

---Find the "Choice" RemoteEvent. It lives in PlayerGui (a sibling of the ChoiceFrame prompt), so we
---search there; getnilinstances is a fallback.
---@return Instance?
local function getChoiceRemote()
	-- PlayerGui (where the choice prompt UI + its Choice remote live).
	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, object in ipairs(playerGui:GetDescendants()) do
			if object.Name == CHOICE_REMOTE_NAME and object:IsA("RemoteEvent") then
				return object
			end
		end
	end

	-- Fallback: parentless instances.
	if getnilinstances then
		local ok, nils = pcall(getnilinstances)
		if ok and nils then
			for _, object in next, nils do
				local nameOk = pcall(function()
					return object.Name
				end)
				if nameOk and object.Name == CHOICE_REMOTE_NAME and object:IsA("RemoteEvent") then
					return object
				end
			end
		end
	end

	return nil
end

---Teleport to a CFrame and wiggle around it a bit so the server registers the touch/arrival, then
---settle back on it.
---@param cframe CFrame
local function jitterTeleport(cframe)
	local character = localPlayer and localPlayer.Character
	if not character then
		return
	end

	pcall(function()
		character:PivotTo(cframe)
	end)

	for _ = 1, 6 do
		if not AutoVoI.running then
			break
		end
		local offset = Vector3.new(math.random(-2, 2), math.random(-1, 1), math.random(-2, 2))
		pcall(function()
			character:PivotTo(cframe + offset)
		end)
		task.wait(0.1)
	end

	pcall(function()
		character:PivotTo(cframe)
	end)
end

---Teleport the character onto workspace.NexusExit (1 stud above), wiggling so the touch registers.
---@return boolean
local function teleportToNexusExit()
	local nexusExit = workspace:FindFirstChild("NexusExit")
	if not nexusExit then
		return false
	end

	local ok, pivot = pcall(function()
		return nexusExit:GetPivot()
	end)
	if not ok then
		return false
	end

	jitterTeleport(pivot + Vector3.new(0, 1, 0))
	return true
end

---Tween (fly) to a world position, Auto-Ferryman style (Y snaps to the goal Y, moves horizontally).
---Blocks until we arrive horizontally or the automation stops.
---@param goalPos Vector3
local function tweenTo(goalPos)
	-- Force a fast tween speed for the crossing, restoring the user's afterwards.
	local prevSpeed
	if Options and Options.TweenStudsPerSecond then
		prevSpeed = Options.TweenStudsPerSecond.Value
		setTweenSpeed(TWEEN_SPEED)
	end

	Tweening.goal(TWEEN_ID, CFrame.new(goalPos), false)

	while AutoVoI.running do
		local _, _, hrp = characterParts()
		if hrp then
			local dx = goalPos.X - hrp.Position.X
			local dz = goalPos.Z - hrp.Position.Z
			setAction(TEXT.tweening) -- re-arms the timeout while we travel
			if math.sqrt(dx * dx + dz * dz) <= ARRIVE_DISTANCE then
				break
			end
		end
		task.wait()
	end

	Tweening.stop(TWEEN_ID)

	if prevSpeed ~= nil and Options and Options.TweenStudsPerSecond then
		Options.TweenStudsPerSecond:SetValue(prevSpeed)
	end
end

---Snap the character to a given Y level, keeping the current X/Z.
---@param y number
local function setYLevel(y)
	local character = localPlayer and localPlayer.Character
	local _, _, hrp = characterParts()
	if character and hrp then
		pcall(function()
			character:PivotTo(CFrame.new(hrp.Position.X, y, hrp.Position.Z))
		end)
	end
end

---Poll for a part (by name) to load in, showing `actionText` while waiting.
---@param name string
---@param actionText string?
---@return Instance?
local function waitForPart(name, actionText)
	while AutoVoI.running do
		if actionText then
			setAction(actionText)
		end
		local part = workspace:FindFirstChild(name, true)
		if part then
			return part
		end
		task.wait(0.2)
	end
	return nil
end

---A part/model's CFrame.
---@param part Instance
---@return CFrame
local function partCFrame(part)
	return part:IsA("BasePart") and part.CFrame or part:GetPivot()
end

---Whether we've arrived: within `radius` of `pos` (nil pos = never "arrived").
---@param pos Vector3?
---@param radius number?
---@return boolean
local function arrivedNear(pos, radius)
	if not pos then
		return false
	end
	local _, _, root = characterParts()
	return root ~= nil and (root.Position - pos).Magnitude <= (radius or WITHIN_DISTANCE)
end

---Continuously teleport onto a part (by name). When the part is present we jitter-teleport onto it;
---when it isn't we hold at `holdPos` (to stream it in). Exits when we arrive near `arrivePos`, the
---automation stops, or -- for non-persistent teleports -- the part despawns (we moved on).
---
---`persistent` = true means it NEVER stops on the part despawning; use it for boundaries that change
---the place id (the place change / VM reset ends the loop).
---@param name string
---@param waitText string?
---@param teleportText string?
---@param holdPos Vector3?
---@param arrivePos Vector3?
---@param arriveRadius number?
---@param persistent boolean?
local function teleportToPartContinuously(name, waitText, teleportText, holdPos, arrivePos, arriveRadius, persistent)
	local seen = false

	while AutoVoI.running do
		if arrivedNear(arrivePos, arriveRadius) then
			break
		end

		local part = workspace:FindFirstChild(name, true)
		if part then
			seen = true
			if teleportText then
				setAction(teleportText)
			end
			jitterTeleport(partCFrame(part))
		else
			-- Part not present. If we'd already used it and this isn't a persistent teleport, we've
			-- moved on. Otherwise keep waiting (holding at holdPos to stream it in).
			if seen and not persistent then
				break
			end
			if waitText then
				setAction(waitText)
			end
			if holdPos then
				local character = localPlayer and localPlayer.Character
				if character then
					pcall(function()
						character:PivotTo(CFrame.new(holdPos))
					end)
				end
			end
		end

		task.wait(0.3)
	end
end

---The player's current Notes, read from the currency UI (PlayerGui.CurrencyGui.CurrencyFrame.Notes),
---or nil if it can't be read.
---@return number?
local function getNotes()
	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	local currencyGui = playerGui and playerGui:FindFirstChild("CurrencyGui")
	local currencyFrame = currencyGui and currencyGui:FindFirstChild("CurrencyFrame")
	local notesLabel = currencyFrame and currencyFrame:FindFirstChild("Notes")
	local amount = notesLabel and notesLabel:FindFirstChild("Amount")
	if not amount then
		return nil
	end

	-- Strip commas / non-digits from the displayed amount.
	local digits = tostring(amount.Text or ""):gsub("[^%d]", "")
	if digits == "" then
		return nil
	end
	return tonumber(digits)
end

---The player's current Power level, or nil if it can't be read.
---@return number?
local function getPower()
	local character = localPlayer and localPlayer.Character
	if not character then
		return nil
	end
	return tonumber(character:GetAttribute("Power"))
end

---The handler NPC in workspace.NPCs, or nil.
---@return Instance?
local function findHandlerNpc()
	local npcs = workspace:FindFirstChild(NPCS_FOLDER)
	return npcs and npcs:FindFirstChild(HANDLER_NPC_NAME)
end

---Fire the NPC's InteractPrompt (same as Auto Ferryman).
---@param npc Instance
local function fireInteract(npc)
	Prompt.interact(npc:FindFirstChild(INTERACT_PROMPT_NAME, true))
end

---Resolve the Power Recall Buy TextButton under PlayerGui, or nil.
---@return Instance?
local function findBuyButton()
	local node = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	for _, name in ipairs(BUY_BUTTON_PATH) do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("TextButton") then
		return node
	end
	return nil
end

---Click a TextButton by firing its MouseButton1Click connections.
---@param button Instance
local function clickButton(button)
	-- conn:Fire() on a getconnections object is the mac/macsploit NULL+0x28 SIGSEGV (native, pcall can't catch).
	-- safeClick invokes each handler's .Function directly instead -- same click, no native crash.
	safeClick(button)
end

---Exit the current dialogue (ReplicatedStorage.Requests.SendDialogue) so we can re-interact to rebuy.
local function exitDialogue()
	local requests = replicatedStorage:FindFirstChild("Requests")
	local sendDialogue = requests and requests:FindFirstChild("SendDialogue")
	if sendDialogue then
		pcall(function()
			sendDialogue:FireServer({ exit = true })
		end)
	end
end

---Generic boss fight (same logic as Auto Ferryman): Pathfind Breaker + Aggressive on, keep the weapon
---drawn, stand in front of any Live entity matching `match` and M1 it. Returns true once the boss was
---present and is gone (defeated), false if the automation stopped first.
---In-front melee boss fight (same logic as Auto Ferryman): Pathfind Breaker + Aggressive on, keep the
---weapon drawn, stand in front of any Live entity matching `match` and M1 it. Returns true once the
---boss was present and is gone (defeated), false if the automation stopped first.
---@param match string
---@param waitText string
---@param fightText string
---@return boolean
local function bossFight(match, waitText, fightText)
	-- Remember Pathfind Breaker + Aggressive Mode prior states so we can restore them after the fight.
	if Toggles and Toggles.AggressiveMode and previousAggressive == nil then
		previousAggressive = Toggles.AggressiveMode.Value
	end
	if Toggles and Toggles.NoFallDamage and previousNoFall == nil then
		previousNoFall = Toggles.NoFallDamage.Value
	end

	applyFly()
	applyNoClip()

	local bossWasPresent = false
	local dodgingAbove = false

	while AutoVoI.running do
		if Toggles and Toggles.AggressiveMode then
			Toggles.AggressiveMode:SetValue(true)
		end
		if Toggles and Toggles.NoFallDamage then
			Toggles.NoFallDamage:SetValue(true)
		end
		if Toggles and Toggles.Fly then
			Toggles.Fly:SetValue(true)
		end

		if not isWeaponDrawn() then
			drawWeapon()
		end

		local enemy = findLiveEnemyMatching(match)
		if not enemy then
			if bossWasPresent then
				break
			end
			setAction(waitText)
			Tweening.stop(FIGHT_TWEEN_ID)
			task.wait(0.3)
		else
			bossWasPresent = true

			-- Pin the boss's velocity so our fast tween into it can't fling it around.
			for _, part in next, enemy:GetDescendants() do
				if part:IsA("BasePart") then
					pcall(function()
						part.AssemblyLinearVelocity = Vector3.zero
						part.AssemblyAngularVelocity = Vector3.zero
					end)
				end
			end

			local ok, enemyCFrame = pcall(function()
				return enemy:GetPivot()
			end)
			if ok then
				local enemyPos = enemyCFrame.Position
				local character = localPlayer and localPlayer.Character
				local _, _, hrp = characterParts()

				if isPlayingActionAnim(enemy) then
					-- Shogun is doing an Action-priority move: snap 1000 studs directly above it (keeping our
					-- X/Z) and don't m1 until it's done.
					dodgingAbove = true
					Tweening.stop(FIGHT_TWEEN_ID)
					if character and hrp then
						pcall(function()
							character:PivotTo(
								CFrame.new(hrp.Position.X, enemyPos.Y + SHOGUN_DODGE_ABOVE, hrp.Position.Z)
							)
						end)
					end
				else
					-- Animation ended: snap back down to the fight spot, then resume normal following.
					if dodgingAbove then
						dodgingAbove = false
						local snapBack = (enemyCFrame * CFrame.new(0, 0, -FIGHT_FRONT_OFFSET)).Position
						if character then
							pcall(function()
								character:PivotTo(CFrame.lookAt(snapBack, enemyPos))
							end)
						end
					end

					setAction(fightText)
					setTweenSpeed(FIGHT_TWEEN_SPEED)

					local frontPos = (enemyCFrame * CFrame.new(0, 0, -FIGHT_FRONT_OFFSET)).Position
					Tweening.goal(FIGHT_TWEEN_ID, CFrame.lookAt(frontPos, enemyPos), false)

					local aim = hrp and CFrame.new(hrp.Position, enemyPos) or CFrame.new(enemyPos)
					pcall(function()
						InputClient.left(aim, true)
					end)
				end
			end
			task.wait(0.3)
		end
	end

	Tweening.stop(FIGHT_TWEEN_ID)
	return AutoVoI.running and bossWasPresent
end

---Rat King fight: normal Pathfind Breaker on, stay 5 studs behind + 3 above it holding m1 (Auto Defense
---+ Block Input + Auto Feint). Follows at 150 speed; if it blinks >500 studs away, crawl at 10 instead
---of flinging across the map. Returns true once it's present-then-gone (killed).
---@param match string
---@param waitText string
---@param fightText string
---@return boolean
local function ratKingFight(match, waitText, fightText)
	-- Remember toggles we force so we can restore them.
	if Toggles and Toggles.NoFallDamage and previousNoFall == nil then
		previousNoFall = Toggles.NoFallDamage.Value
	end
	if Toggles and Toggles.EnableAutoDefense and previousAutoDefense == nil then
		previousAutoDefense = Toggles.EnableAutoDefense.Value
	end
	if Toggles and Toggles.BlockInput and previousBlockInput == nil then
		previousBlockInput = Toggles.BlockInput.Value
	end
	if Toggles and Toggles.AutoFeint and previousAutoFeint == nil then
		previousAutoFeint = Toggles.AutoFeint.Value
	end
	if Toggles and Toggles.Fly and previousFly == nil then
		previousFly = Toggles.Fly.Value
	end

	-- Custom noclip on (CanCollide off + AirController + zero our velocity). Fly off -- movement is via
	-- tweening.
	applyNoClip()

	local bossWasPresent = false
	local dodgingAbove = false

	while AutoVoI.running do
		-- Just normal Pathfind Breaker + the combat toggles.
		if Toggles and Toggles.NoFallDamage then
			Toggles.NoFallDamage:SetValue(true)
		end
		if Toggles and Toggles.Fly then
			Toggles.Fly:SetValue(false)
		end
		if Toggles and Toggles.EnableAutoDefense then
			Toggles.EnableAutoDefense:SetValue(true)
		end
		if Toggles and Toggles.BlockInput then
			Toggles.BlockInput:SetValue(true)
		end
		if Toggles and Toggles.AutoFeint then
			Toggles.AutoFeint:SetValue(true)
		end

		if not isWeaponDrawn() then
			drawWeapon()
		end

		local _, _, localRoot = characterParts()
		if not localRoot then
			task.wait()
			continue
		end

		local enemy = findLiveEnemyMatching(match)
		if not enemy then
			if bossWasPresent then
				break
			end
			setAction(waitText)
			Tweening.stop(FIGHT_TWEEN_ID)
			task.wait(0.3)
		else
			bossWasPresent = true

			-- Anti body-part velocity: zero the boss's velocity so our tween near it can't fling it.
			for _, part in next, enemy:GetDescendants() do
				if part:IsA("BasePart") then
					pcall(function()
						part.AssemblyLinearVelocity = Vector3.zero
						part.AssemblyAngularVelocity = Vector3.zero
					end)
				end
			end

			local targetRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
			if targetRoot then
				local character = localPlayer and localPlayer.Character

				if isPlayingActionAnim(enemy) then
					-- Rat king is doing an Action-priority move: snap 500 studs directly above it (keeping
					-- our X/Z) and don't m1 until it's done.
					dodgingAbove = true
					Tweening.stop(FIGHT_TWEEN_ID)
					if character then
						pcall(function()
							character:PivotTo(
								CFrame.new(localRoot.Position.X, targetRoot.Position.Y + RATKING_DODGE_ABOVE, localRoot.Position.Z)
							)
						end)
					end
				else
					-- Animation ended: snap back down to the fight spot, then resume normal following.
					if dodgingAbove then
						dodgingAbove = false
						local snapBack = (targetRoot.CFrame * CFrame.new(0, RATKING_ABOVE, RATKING_BEHIND)).Position
						if character then
							pcall(function()
								character:PivotTo(CFrame.lookAt(snapBack, targetRoot.Position))
							end)
						end
					end

					-- Normal 150 speed; crawl at 10 if it's blinked far away (so we don't fling ourselves).
					local dist = (localRoot.Position - targetRoot.Position).Magnitude
					setTweenSpeed(dist > RATKING_FAR_DISTANCE and RATKING_FAR_SPEED or RATKING_TWEEN_SPEED)

					-- Stay 5 studs behind it and 3 studs above, facing it.
					local behindPos = (targetRoot.CFrame * CFrame.new(0, RATKING_ABOVE, RATKING_BEHIND)).Position
					Tweening.goal(FIGHT_TWEEN_ID, CFrame.lookAt(behindPos, targetRoot.Position), false)

					setAction(fightText)

					-- Spam m1 like Auto Ferryman (respect block input so blocks/punishes still land).
					if not Defense.shouldBlockInput("M1s") then
						local aim = CFrame.new(localRoot.Position, targetRoot.Position)
						pcall(function()
							InputClient.left(aim, true)
						end)
					end
				end
			end
			task.wait()
		end
	end

	Tweening.stop(FIGHT_TWEEN_ID)
	return AutoVoI.running and bossWasPresent
end

---Pick Enmity's fight targets: the boss (Live entity whose name contains ENMITY_ENEMY_MATCH) and the
---nearest "enforcer" (any OTHER live, alive, non-self entity in workspace.Live). Enforcers are killed
---first, so the caller fights the enforcer when one exists and only falls back to the boss once they're
---all cleared.
---@return Instance? boss, Instance? nearestEnforcer
local function findEnmityTargets()
	local live = workspace:FindFirstChild("Live")
	if not live then
		return nil, nil
	end

	local myCharacter = localPlayer and localPlayer.Character
	local _, _, localRoot = characterParts()

	local boss = nil
	local nearestEnforcer, nearestDist = nil, math.huge

	for _, entity in next, live:GetChildren() do
		if entity == myCharacter then
			continue
		end

		local humanoid = entity:FindFirstChildWhichIsA("Humanoid")
		local root = entity:FindFirstChild("HumanoidRootPart") or entity.PrimaryPart
		if not (humanoid and root and humanoid.Health > 0) then
			continue
		end

		if string.find(string.lower(entity.Name), ENMITY_ENEMY_MATCH, 1, true) then
			boss = entity
		else
			-- An enforcer / other enemy: track the nearest one so we clear it first.
			local dist = localRoot and (localRoot.Position - root.Position).Magnitude or 0
			if dist < nearestDist then
				nearestDist = dist
				nearestEnforcer = entity
			end
		end
	end

	return boss, nearestEnforcer
end

---Enmity fight (arena-only). Normal Pathfind Breaker on, custom noclip, always stay ENMITY_BEHIND studs
---behind + ENMITY_ABOVE up the target holding m1 (no dodge). ALWAYS spams m1 (no block-input gate), and
---prioritizes killing Enmity's enforcers (any other Live enemy) before the boss. Completion is tracked on
---the boss specifically, so enforcers spawning/dying never ends the run. Returns true once the boss was
---present and is gone (killed).
---@param waitText string
---@param fightText string
---@return boolean
local function enmityFight(waitText, fightText)
	-- Remember toggles we force so we can restore them.
	if Toggles and Toggles.NoFallDamage and previousNoFall == nil then
		previousNoFall = Toggles.NoFallDamage.Value
	end
	if Toggles and Toggles.EnableAutoDefense and previousAutoDefense == nil then
		previousAutoDefense = Toggles.EnableAutoDefense.Value
	end
	if Toggles and Toggles.BlockInput and previousBlockInput == nil then
		previousBlockInput = Toggles.BlockInput.Value
	end
	if Toggles and Toggles.AutoFeint and previousAutoFeint == nil then
		previousAutoFeint = Toggles.AutoFeint.Value
	end
	if Toggles and Toggles.Fly and previousFly == nil then
		previousFly = Toggles.Fly.Value
	end

	applyNoClip()

	local bossWasPresent = false

	while AutoVoI.running do
		if Toggles and Toggles.NoFallDamage then
			Toggles.NoFallDamage:SetValue(true)
		end
		if Toggles and Toggles.Fly then
			Toggles.Fly:SetValue(false)
		end
		if Toggles and Toggles.EnableAutoDefense then
			Toggles.EnableAutoDefense:SetValue(true)
		end
		if Toggles and Toggles.BlockInput then
			Toggles.BlockInput:SetValue(true)
		end
		if Toggles and Toggles.AutoFeint then
			Toggles.AutoFeint:SetValue(true)
		end

		if not isWeaponDrawn() then
			drawWeapon()
		end

		local _, _, localRoot = characterParts()
		if not localRoot then
			task.wait()
			continue
		end

		local boss, enforcer = findEnmityTargets()
		if boss then
			bossWasPresent = true
		end

		-- Enforcers first; only fight the boss once they're all cleared.
		local enemy = enforcer or boss
		if not enemy then
			-- No boss and no enforcers left: if the boss had been here, it's dead -> done.
			if bossWasPresent then
				break
			end
			setAction(waitText)
			Tweening.stop(FIGHT_TWEEN_ID)
			task.wait(0.3)
		else
			-- Anti body-part velocity: zero the target's velocity so our tween near it can't fling it.
			for _, part in next, enemy:GetDescendants() do
				if part:IsA("BasePart") then
					pcall(function()
						part.AssemblyLinearVelocity = Vector3.zero
						part.AssemblyAngularVelocity = Vector3.zero
					end)
				end
			end

			local targetRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
			if targetRoot then
				-- Follow speed; crawl if it's blinked far away so we don't fling ourselves.
				local dist = (localRoot.Position - targetRoot.Position).Magnitude
				setTweenSpeed(dist > RATKING_FAR_DISTANCE and RATKING_FAR_SPEED or RATKING_TWEEN_SPEED)

				-- Stay behind + above the target, facing it: enforcers 3/3, the boss 15/10.
				local behindOff = enforcer and ENMITY_ENFORCER_BEHIND or ENMITY_BEHIND
				local aboveOff = enforcer and ENMITY_ENFORCER_ABOVE or ENMITY_ABOVE
				local behindPos = (targetRoot.CFrame * CFrame.new(0, aboveOff, behindOff)).Position
				Tweening.goal(FIGHT_TWEEN_ID, CFrame.lookAt(behindPos, targetRoot.Position), false)

				setAction(enforcer and TEXT.fightingEnforcers or fightText)

				-- ALWAYS spam m1 (no block-input gate).
				local aim = CFrame.new(localRoot.Position, targetRoot.Position)
				pcall(function()
					InputClient.left(aim, true)
				end)
			end
			task.wait()
		end
	end

	Tweening.stop(FIGHT_TWEEN_ID)
	return AutoVoI.running and bossWasPresent
end

local function routine()
	-- In the boss arena: fight the run's target, then end the automation.
	if AutoVoI.inArena() then
		if currentTarget == "enmity" then
			enmityFight(TEXT.waitingForEnmity, TEXT.fightingEnmity)
		elseif currentTarget == "ratking" then
			ratKingFight(RATKING_ENEMY_MATCH, TEXT.waitingForRatKing, TEXT.fightingRatKing)
		else
			bossFight(SHOGUN_ENEMY_MATCH, TEXT.waitingForShogun, TEXT.fightingShogun)
		end

		-- Boss defeated (or stopped) -> end the automation.
		setAction(TEXT.done)
		AutoVoI.stop()
		return
	end

	-- Enmity is arena-only; there's no VoI-side path to it, so idle out here (start guards this).
	if currentTarget == "enmity" then
		setAction(TEXT.waitingForEnmity)
		return
	end

	-- In the VoI: teleport to the target boss's boundary (place change into the arena ends this).
	if currentTarget == "ratking" then
		teleportToPartContinuously(
			GOLDENRAT_BOUNDARY_NAME,
			TEXT.waitingGoldenRat,
			TEXT.teleportingGoldenRat,
			GOLDENRAT_WAIT_POS,
			nil,
			nil,
			true -- persistent: never stops (place change ends it)
		)
	else
		setAction(TEXT.teleportingCrossing)
		teleportToPartContinuously(
			SHOGUN_PART_NAME,
			TEXT.waitingShogun,
			TEXT.teleportingShogun,
			Vector3.new(CROSSING_X, DROP_Y, CROSSING_Z),
			nil,
			nil,
			true -- persistent: never stops (place change ends it)
		)
	end
end

-- ============================================================================================
-- Start / stop
-- ============================================================================================

local function teardown()
	AutoVoI.running = false

	if timerConnection then
		pcall(function()
			timerConnection:Disconnect()
		end)
		timerConnection = nil
	end
	if characterAddedConnection then
		pcall(function()
			characterAddedConnection:Disconnect()
		end)
		characterAddedConnection = nil
	end

	restoreNoClip()
	removeHighlight()
	holdM1(false)

	timeoutDeadline = nil

	pcall(function()
		Tweening.stop(TWEEN_ID)
		Tweening.stop(FIGHT_TWEEN_ID)
	end)

	-- Restore anything the run forced.
	if previousTweenSpeed ~= nil and Options and Options.TweenStudsPerSecond then
		Options.TweenStudsPerSecond:SetValue(previousTweenSpeed)
	end
	if previousAggressive ~= nil and Toggles and Toggles.AggressiveMode then
		Toggles.AggressiveMode:SetValue(previousAggressive)
	end
	if previousFly ~= nil and Toggles and Toggles.Fly then
		Toggles.Fly:SetValue(previousFly)
	end
	if previousVoidMobs ~= nil and Toggles and Toggles.VoidMobs then
		Toggles.VoidMobs:SetValue(previousVoidMobs)
	end
	if previousNoFall ~= nil and Toggles and Toggles.NoFallDamage then
		Toggles.NoFallDamage:SetValue(previousNoFall)
	end
	if previousAutoDefense ~= nil and Toggles and Toggles.EnableAutoDefense then
		Toggles.EnableAutoDefense:SetValue(previousAutoDefense)
	end
	if previousBlockInput ~= nil and Toggles and Toggles.BlockInput then
		Toggles.BlockInput:SetValue(previousBlockInput)
	end
	if previousAutoFeint ~= nil and Toggles and Toggles.AutoFeint then
		Toggles.AutoFeint:SetValue(previousAutoFeint)
	end
	if previousM1Hold ~= nil and Toggles and Toggles.M1Hold then
		Toggles.M1Hold:SetValue(previousM1Hold)
	end
	previousTweenSpeed = nil
	previousPathfind = nil
	previousAggressive = nil
	previousFly = nil
	previousNoFall = nil
	previousVoidMobs = nil
	previousAutoDefense = nil
	previousBlockInput = nil
	previousAutoFeint = nil
	previousM1Hold = nil

	if screenGui then
		screenGui.Enabled = false
	end
end

---@param target string? "shogun" or "ratking" for a manual start; nil = server-hop resume (read the
---persisted target).
function AutoVoI.start(target)
	if AutoVoI.running then
		return
	end

	if not AutoVoI.inValidPlace() then
		return Logger.notify(TEXT.notInPlace)
	end

	-- Resolve the target: a manual Start passes it; a resume reads the persisted one.
	if target then
		currentTarget = target
	else
		local existing = PersistentData.get("voidata")
		currentTarget = existing and existing.target
	end
	if not currentTarget then
		return
	end

	-- Enmity is an arena-only boss -- it can only be started from inside the boss arena.
	if currentTarget == "enmity" and not AutoVoI.inArena() then
		return Logger.notify(TEXT.notInArena)
	end

	-- If the loading screen (LoadingGui) is up (e.g. we just resumed after a place teleport), spam A to
	-- blow through it until the character + backpack have replicated (10s cap) -- same as Auto Ferryman.
	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui and playerGui:FindFirstChild("LoadingGui") then
		local deadline = os.clock() + 10
		while not requirementsMet() and os.clock() < deadline do
			pressKey(Enum.KeyCode.A)
			task.wait(0.25)
		end
	end

	startClock = os.clock()
	AutoVoI.running = true

	-- Capture the user's tween speed so we can restore it after the run.
	if Options and Options.TweenStudsPerSecond then
		previousTweenSpeed = Options.TweenStudsPerSecond.Value
	end

	-- Resume flag: survives server hops (MemStorage).
	saveState()

	buildOverlay()
	setAction(nil)
	if timerLabel then
		timerLabel.Text = formatClock(TEXT.elapsed, 0)
	end
	if timeoutLabel then
		timeoutLabel.Text = TEXT.timeoutNone
	end
	if screenGui then
		screenGui.Enabled = true
	end

	-- Fly + custom noclip for the run.
	applyFly()
	applyNoClip()

	-- Highlight the character, and re-apply it (+ noclip via its connection) if we respawn mid-run.
	applyHighlight()
	characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
		if not AutoVoI.running then
			return
		end
		task.wait(0.2)
		applyHighlight()
		applyFly()
	end)

	-- Tick the elapsed timer + the timeout countdown (and enforce the timeout).
	timerConnection = runService.Heartbeat:Connect(function()
		if not AutoVoI.running then
			return
		end

		if timerLabel then
			timerLabel.Text = formatClock(TEXT.elapsed, os.clock() - startClock)
		end

		if timeoutLabel then
			if timeoutDeadline then
				timeoutLabel.Text = formatClock(TEXT.timeout, math.max(0, timeoutDeadline - os.clock()))
			else
				timeoutLabel.Text = TEXT.timeoutNone
			end
		end

		if timeoutDeadline and os.clock() >= timeoutDeadline then
			Logger.notify(TEXT.timedOut)
			AutoVoI.stop()
		end
	end)

	-- Run the routine off-thread so pathfinding can block.
	task.spawn(routine)
end

function AutoVoI.stop()
	if not AutoVoI.running and not PersistentData.get("voidata") then
		return
	end

	teardown()

	-- Clear the target + resume flag so a re-execute doesn't restart it.
	currentTarget = nil
	PersistentData.set("voidata", nil)
end

function AutoVoI.init()
	if not LPH_OBFUSCATED or (shared.Aero and shared.Aero.verbose) then
		Logger.warn("Auto VoI initialized.")
	end
end

return AutoVoI
