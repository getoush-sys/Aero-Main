-- Auto Ferryman automation.
-- Currently just the scaffolding: an on-screen status overlay (title / current action / elapsed
-- timer / stop button), a blue character highlight while running, and start/stop. The actual
-- ferryman routine is not wired up yet -- setAction() is the hook the routine will drive later.
local AutoFerryman = { running = false }

---@module GUI.Library
local Library = require("GUI/Library")

---@module Features.Automation.Objects.AutoLog
local AutoLog = require("Features/Automation/Objects/AutoLog")

---@module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Finder
local Finder = require("Utility/Finder")

---@module Utility.Prompt
local Prompt = require("Utility/Prompt")

---@module Features.Game.Tweening
local Tweening = require("Features/Game/Tweening")

---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Features.Automation.AutoLoot
local AutoLoot = require("Features/Automation/AutoLoot")

---@module Features.Automation.Objects.AutoLootOptions
local AutoLootOptions = require("Features/Automation/Objects/AutoLootOptions")

---@module Game.PlayerScanning
local PlayerScanning = require("Game/PlayerScanning")

---@module Features.Automation.Objects.General
local General = require("Features/Automation/Objects/General")

local players = game:GetService("Players")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local collectionService = game:GetService("CollectionService")

local localPlayer = players.LocalPlayer

local fastSwingConn = nil

-- Tag placed on a chest once we've looted/given up on it, so it's never re-processed (survives longer
-- than an in-memory table -- e.g. if the chest is re-found on a later pass).
local LOOTED_TAG = "LumaFerrymanLooted"

-- ============================================================================================
-- All Auto Ferryman text -- edit these to change the on-screen action text and notifications.
-- Entries with %d / %s are format strings (the values are filled in at runtime).
-- ============================================================================================
local TEXT = {
	-- Overlay labels
	overlayTitle = "Auto Ferryman",
	actionPrefix = "Current Action: ", -- prepended to every action; the empty form is below
	actionPrefixEmpty = "Current Action:",
	elapsed = "Elapsed: %d:%02d",
	elapsedZero = "Elapsed: 0:00",
	timeout = "Timeout: %d:%02d",
	timeoutNone = "Timeout: --",
	cycles = "Cycles: %d",
	stopButton = "Stop",

	-- Notifications
	started = "Auto Ferryman started.",
	stopped = "Auto Ferryman stopped.",
	notInPlace = "Auto Ferryman: Not in Eastern Luminant or the Ferryman dungeon",
	needTools = "Auto Ferryman: Need a pickaxe and lumber axe to start (for chopping trees and mining coal)",
	craftRemoteMissing = "Auto Ferryman: Craft remote not found.",
	noLumberAxeNotify = "Auto Ferryman: No lumber axe, leaving.",
	noPickaxeNotify = "Auto Ferryman: No pickaxe, leaving.",
	noWeaponNotify = "Auto Ferryman: No wapon in backpack.",
	bossTimedOutNotify = "Auto Ferryman: Boss fight timed out.",
	wrongSlotNotify = "Auto Ferryman: on a different slot than started, stopping.",
	noTreesNotify = "Auto Ferryman: No trees found",
	noMeshNotify = "Auto Ferryman: No %s found in %s.",
	hopNotify = "Auto Ferryman: %s: Server hopping",

	-- Kick messages
	kickNoLumberAxe = "No lumber axe to chop trees",
	kickNoPickaxe = "No pickaxe to mine coal",
	kickDepths = "ended up in depths. sorry.",

	-- Hop reasons (filled into hopNotify)
	reasonTimeout = "timeout",
	reasonModerator = "moderator in server",
	reasonPlayerNearby = "player nearby",
	reasonNoTrees = "no trees",
	reasonCraftFailed = "crafting failed",
	reasonNoMesh = "no %s",
	reasonFlintCraftFailed = "flint crafting failed",
	reasonCycleComplete = "cycle complete",
	reasonLoadingTimeout = "loading timeout",

	-- Current action text
	tweening = "Tweening to %s. Current Distance: %d",
	destIsland = "Ferryman Island",
	destMiners = "Miners Landing",
	waitingForTree = "waiting for trees to load",
	choppingTree = "chopping tree. chop chop",
	placingCampfire = "i place campfires now %d/%d",
	checkingCampfires = "checking campfires",
	craftingCampfires = "crafting %d campfires",
	campfireCraftFailed = "campfire crafting failed",
	waitingForMesh = "waiting for %s",
	miningMesh = "mining %s",
	craftingUmbralFlint = "crafting umbral flint",
	craftingFlint = "crafting flint",
	flintCraftFailed = "flint crafting failed",
	campfiresReady = "campfires ready",
	breakingCampfire = "breaking bad boy campfire",
	campfiresPlaced = "i hope the campfire placements worked",
	lootingChests = "yoinking the loot",
	waitingForChests = "waiting for chests",
	lootingChest = "yoinking the loot",
	ferrymanNotFound = "ferryman not found",
	tweeningToFerryman = "hi ferryman",
	talkingToFerryman = "talking to Ferryman",
	advancingDialogue = "blah blah blah",
	dialogueComplete = "dialogue complete",
	waitingForBoss = "waiting for boss",
	noWeapon = "no weapon",
	bossFightTimedOut = "boss fight timed out",
	wrongSlot = "Auto Ferryman: Wrong slot",
	fightingFerryman = "die ferryman die die",
	bossDefeated = "ferryman died yay",
	chestsLooted = "chests looted",
}

-- Set true while a server hop is in flight, so the various triggers (auto-log, craft failure) only
-- fire one hop.
local hopping = false

-- Current-luminant detection (mirrors Teleport.lua's realm handling). The ValleyExit realm
-- teleporter's "Realm" attribute names the realm it sends you TO -- the OTHER luminant -- so we're
-- in the Eastern Luminant when that teleporter points at the Etrean Luminant.
local ETREAN_REALM_ALIASES = { "EtreanLuminant", "Etrean Luminant" }

---@return boolean
function AutoFerryman.inEasternLuminant()
	local valleyExit = workspace:FindFirstChild("ValleyExit")
	local teleporter = valleyExit
		and (valleyExit:FindFirstChild("RealmTeleport") or valleyExit:FindFirstChild("RealmTeleporter"))
	if not teleporter then
		return false
	end

	local realm = teleporter:GetAttribute("Realm")
	for _, alias in next, ETREAN_REALM_ALIASES do
		if realm == alias then
			return true
		end
	end

	return false
end

-- Boss dungeon: all dungeons share this PlaceId, so we confirm it's the Ferryman fight by looking
-- for "The Ferryman" in workspace.NPCs.
local BOSS_PLACE_ID = 8668476218

-- The Depths -- if the automation ever runs here we've gone wrong; kick out.
local DEPTHS_PLACE_ID = 5735553160
local NPCS_FOLDER = "NPCs"
local FERRYMAN_NPC_NAME = "The Ferryman"

-- Boss fight: after the dialogue the boss spawns as ".ferryman1" in workspace.Live. We fight it with
-- the "Weapon" tool from the backpack.
local LIVE_FOLDER = "Live"
local BOSS_MODEL_NAME = ".ferryman1"
local WEAPON_NAME = "Weapon"

-- Boss positioning: sit this far below + behind the boss (in its own frame) while fighting, facing it.
-- PR ferryman uses CFrame.new(0, -7, 4); we sit 2 studs lower (-9) for the fight loop.
local BOSS_UNDER_OFFSET = 7
local BOSS_BEHIND_OFFSET = 4

-- The Ferryman's triple-slash animations (pause our M1 while either plays, PR: 5968282214 / 5968288116)
-- and its javelin throw (drop to the ground to dodge it, PR: 8183996606).
local BOSS_TRIPLE_ANIM_IDS = { "5968282214", "5968288116" }
local BOSS_JAVELIN_ANIM_ID = "8183996606"

-- Heal when we drop below 35% HP: tween to the safe spot until we're back above 85% (PR: heal_cf).
local BOSS_HEAL_CFRAME = CFrame.new(-3799, 100, 7788)
local BOSS_HEAL_LOW = 0.35
local BOSS_HEAL_HIGH = 0.85

-- Give up the boss fight after this long.
local BOSS_FIGHT_TIMEOUT = 15 * 60

-- After the boss dies, 3 chests spawn as models named "Model" in workspace.Thrown. Loot each with
-- Auto Loot, always taking Umbral Obsidian on top of the player's configured items.
local THROWN_FOLDER = "Thrown"
local CHEST_MODEL_NAME = "Model"
local CHEST_COUNT = 3
local ALWAYS_LOOT = "Umbral Obsidian"

---@return boolean
function AutoFerryman.inBossDungeon()
	if game.PlaceId ~= BOSS_PLACE_ID then
		return false
	end
	local npcs = workspace:FindFirstChild(NPCS_FOLDER)
	return npcs ~= nil and npcs:FindFirstChild(FERRYMAN_NPC_NAME) ~= nil
end

-- Campfire placement spots (full CFrames -- exact position + facing).
local PLACE_LOCATIONS = {
	CFrame.new(-4099.17773, 65.9573746, 9445.28179, 0.981207728, -0.000153392553, -0.192954302, 0.000146208593, 1, -5.14709718e-05, 0.192954302, 2.22921371e-05, 0.981207728),
	CFrame.new(-4072.07329, 65.7076187, 9428.95825, 0.225762814, -0.000561982335, 0.974182129, 0.000387706299, 0.999999821, 0.000487026584, -0.974182248, 0.000267744064, 0.225762993),
	CFrame.new(-4091.05849, 65.870491, 9404.10488, -0.948379517, -0.000251352758, 0.317137599, -0.000239436369, 0.99999994, 7.65478471e-05, -0.317137599, -3.33786375e-06, -0.948379517),
	CFrame.new(-4119.05869, 65.8594055, 9420.94440, -0.279934168, -0.00051805377, -0.960019052, -8.90582305e-05, 0.999999881, -0.000513659848, 0.960019171, -5.8293339e-05, -0.279934168),
}

local HIGHLIGHT_FILL = Color3.fromRGB(0, 120, 255)
local HIGHLIGHT_OUTLINE = Color3.fromRGB(120, 190, 255)

-- Ferryman location. The Y gets a small stand-on offset so we land on the point rather than in it,
-- the same way Titus Farm offsets its tween landings.
local FERRYMAN_TARGET = Vector3.new(-4094.81348, 68.8016357, 9425.08691)
local FERRYMAN_TWEEN_Y = 20000
local FERRYMAN_DESCENT_Y = 100

-- Miner's Landing: where we go to mine coal + rock and craft flint when we're out of flint. Its Y is
-- already a ground position, so the descent lands right on this coordinate.
local MINER_TARGET = Vector3.new(-3522.258056640625, 114.53073120117188, 2919.383544921875)
local INGREDIENTS_FOLDER = "Ingredients"
local INTERACT_PROMPT_NAME = "InteractPrompt"

-- The Ferryman's wager dialogue path, fired via Requests.SendDialogue in order to start the fight.
local FERRYMAN_DIALOGUE_CHOICES = { "Who are you?", "[Tell him your name]", "A wager?", "Deal." }

-- Only mine coal/rock within this range of Miner's Landing (mirrors the tree range around the
-- island).
local MINER_RANGE = 1000
local TWEEN_SPEED = 100
local TWEEN_IDENTIFIER = "AutoFerryman"
local AUTO_LOG_WATCH_INTERVAL = 1

-- Auto Log: hop the moment a player comes within the per-automation auto-log distance (adjustable 0-2000
-- in the menu; 0 = off). Saved per automation via the AutoLog store.

-- Skip the fly-up tween entirely if we're already this close (horizontally) to the island.
local ISLAND_NEAR_RANGE = 500

-- Timeout: how long a single action may run before we assume we're stuck on some edge case and
-- server-hop. Tweening to the island gets a long budget; everything else a short one.
local DEFAULT_TIMEOUT = 60
local TWEEN_TIMEOUT = 300

-- Campfire phase: need this many Campfire Pits to proceed. Shortfall can be crafted from raw
-- materials -- 1 Wood -> 1 campfire, 3 Stick -> 1 campfire.
local REQUIRED_CAMPFIRES = 4
local WOOD_PER_CAMPFIRE = 1
local STICKS_PER_CAMPFIRE = 3

-- Wood gathering: when short on materials, chop trees in workspace.Destructibles with a Lumber Axe.
local CHOP_TWEEN_IDENTIFIER = "AutoFerrymanChop"
local CHOP_SWING_INTERVAL = 0.3

-- Only ever chop trees within this range of the island -- never wander off across the map for a
-- far-off tree.
local TREE_ISLAND_RANGE = 1000

-- After crafting, break existing Campfire models in Destructibles within this range of the island.
local CAMPFIRE_BREAK_RANGE = 100

-- Overlay + runtime state.
local screenGui, actionLabel, timerLabel, timeoutLabel, cyclesLabel = nil, nil, nil, nil, nil
local highlight = nil
local startClock = 0
-- Cycles (ferrymen killed) and accumulated elapsed time -- both persisted across server hops.
local cycles = 0
local baseElapsed = 0
-- The data slot the automation was started on; if the player switches slots we stop. Persisted so it
-- carries across hops.
local startSlot = nil
local timerConnection = nil
local characterAddedConnection = nil
local weaponConnection = nil
local previousTweenSpeed = nil
local previousNoFallDamage = nil
local previousFly = nil
local removedWindowFilter = false
local noclipConnection = nil

-- The Auto Defense filter we turn off during the run (so defense still works when the Roblox window
-- isn't focused).
local WINDOW_FILTER = "Disable When Window Not Active"

-- Timeout tracking: os.clock() deadline after which we hop. Reset on each action (progress).
local timeoutDeadline = nil

-- True while we're flying up to the island (so a stop mid-air can drop us to a normal Y).
local flying = false

-- os.clock() of the last descent; auto-log holds off briefly after it (players streaming in around
-- the freshly-loaded island shouldn't trip an immediate log).
local lastDescentClock = nil
local DESCENT_LOG_GRACE = 1

---Exploit-safe GUI parent: gethui -> CoreGui -> PlayerGui.
---@return Instance?
local function guiParent()
	local ok, hui = pcall(function()
		return gethui and gethui()
	end)
	if ok and hui then
		return hui
	end

	local ok2, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok2 and coreGui then
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

---Total elapsed time this run, including time carried over from before a server hop.
---@return number
local function currentElapsed()
	return baseElapsed + (os.clock() - startClock)
end

---The player's current data slot, or nil.
---@return any
local function currentSlot()
	return localPlayer and localPlayer:GetAttribute("DataSlot")
end

---Persist the resume flag together with cycles + elapsed + start slot so they survive a server hop.
local function saveState()
	PersistentData.set("afdata", { active = true, cycles = cycles, elapsed = currentElapsed(), slot = startSlot })
end

---Build the status overlay once, hidden.
local function buildOverlay()
	if screenGui then
		return
	end

	screenGui = CoreGuiManager.imark(Instance.new("ScreenGui"))
	screenGui.Name = "LumaAutoFerrymanOverlay"
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
		Size = UDim2.new(0, 300, 0, 170),
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
		Text = "Current Action:",
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
		Text = TEXT.elapsedZero,
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

	cyclesLabel = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 112),
		Size = UDim2.new(1, -16, 0, 20),
		FontFace = Library.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Library.FontColor or Color3.new(1, 1, 1),
		Text = string.format(TEXT.cycles, 0),
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(cyclesLabel, { TextColor3 = "FontColor" })

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
		AutoFerryman.stop()
	end)

	pcall(function()
		Library:MakeDraggable(outer)
	end)

	screenGui.Enabled = false
end

---Highlight the local character in blue (through walls).
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
	highlight.Name = "LumaAutoFerrymanHighlight"
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

---Pin the global tween speed to a fixed value for the run, remembering the old one.
local function applyTweenSpeed()
	if not Options or not Options.TweenStudsPerSecond then
		return
	end
	previousTweenSpeed = Options.TweenStudsPerSecond.Value
	Options.TweenStudsPerSecond:SetValue((Options and Options.FerrymanTweenSpeed and Options.FerrymanTweenSpeed.Value) or 100)
end

local function restoreTweenSpeed()
	if previousTweenSpeed ~= nil and Options and Options.TweenStudsPerSecond then
		Options.TweenStudsPerSecond:SetValue(previousTweenSpeed)
	end
	previousTweenSpeed = nil
end

---Force No Fall Damage on for the run, remembering its previous state.
local function applyNoFallDamage()
	if not Toggles or not Toggles.NoFallDamage then
		return
	end
	previousNoFallDamage = Toggles.NoFallDamage.Value
	Toggles.NoFallDamage:SetValue(true)
end

local function restoreNoFallDamage()
	if previousNoFallDamage ~= nil and Toggles and Toggles.NoFallDamage then
		Toggles.NoFallDamage:SetValue(previousNoFallDamage)
	end
	previousNoFallDamage = nil
end

---Force Fly on for the run, remembering its previous state.
local function applyFly()
	if not Toggles or not Toggles.Fly then
		return
	end
	previousFly = Toggles.Fly.Value
	Toggles.Fly:SetValue(true)
end

local function restoreFly()
	if previousFly ~= nil and Toggles and Toggles.Fly then
		Toggles.Fly:SetValue(previousFly)
	end
	previousFly = nil
end

---Turn off the "Disable When Window Not Active" Auto Defense filter for the run, remembering whether
---it was on so we can put it back.
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

---A stronger noclip than the toggle feature, plus physics stabilization. Every frame (before the
---physics step) we drop CanCollide on ALL character parts, force the AirController so nothing (the
---ground included) blocks our tweens, and zero every part's velocity so a ragdoll can't build
---momentum that fights the CFrame tween (which is what made the tween bug out when knocked).
local function applyNoClip()
	if noclipConnection then
		return
	end

	noclipConnection = runService.Stepped:Connect(function()
		if not AutoFerryman.running then
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
					-- Kill momentum: a ragdoll gives limbs (their own assemblies once the joints
					-- break) physics velocity that fights the tween. Zero it every frame.
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
				end)
			end
		end

		-- Use the air controller so the ground controller can't keep us grounded (lets us sink
		-- through the floor while tweening).
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

---Set only the "Current Action:" label text, WITHOUT touching the timeout. Used by the tween loop,
---which updates the distance every frame but keeps its own long timeout budget.
---@param text string?
local function setActionText(text)
	if not actionLabel then
		return
	end

	if text and text ~= "" then
		actionLabel.Text = TEXT.actionPrefix .. text
	else
		actionLabel.Text = TEXT.actionPrefixEmpty
	end
end

---Arm the timeout to `seconds` from now (nil clears it).
---@param seconds number?
local function armTimeout(seconds)
	timeoutDeadline = seconds and (os.clock() + seconds) or nil
end

---Tween to a world position, updating the "Current Action" line with the live distance, until we
---arrive or the automation stops.
---@param goalPosition Vector3
---@param destName string? Name shown in the action line (defaults to "Ferryman Island").
local function tweenTo(goalPosition, destName)
	destName = destName or TEXT.destIsland
	Tweening.goal(TWEEN_IDENTIFIER, CFrame.new(goalPosition), false)

	-- Long timeout for the whole fly-up; the label updates every frame but must not re-arm it.
	armTimeout(TWEEN_TIMEOUT)

	while AutoFerryman.running do
		local character = localPlayer and localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			-- Horizontal distance only -- the vertical leg snaps, so the Y gap isn't meaningful.
			local dx = goalPosition.X - root.Position.X
			local dz = goalPosition.Z - root.Position.Z
			local distance = math.sqrt(dx * dx + dz * dz)
			setActionText(string.format(TEXT.tweening, destName, distance))
			if distance <= 1.0 then
				break
			end
		end
		runService.Heartbeat:Wait()
	end
end

---Watchdog: Auto Log (always on) hops when a player comes within range, and the timeout hops if an
---action has been stuck past its budget.
local function watchForNearbyPlayers()
	while AutoFerryman.running do
		task.wait(AUTO_LOG_WATCH_INTERVAL)

		if not AutoFerryman.running or hopping then
			break
		end

		-- Ended up in the Depths mid-run -- stop the automation and leave.
		if game.PlaceId == DEPTHS_PLACE_ID then
			AutoFerryman.stop()
			pcall(function()
				localPlayer:Kick(TEXT.kickDepths)
			end)
			return
		end

		-- On a different slot than the one we started on -- stop.
		local slot = currentSlot()
		if startSlot ~= nil and slot ~= nil and slot ~= startSlot then
			AutoFerryman.setAction(TEXT.wrongSlot)
			Logger.notify(TEXT.wrongSlotNotify)
			AutoFerryman.stop()
			return
		end

		-- Timeout: assume a stuck edge case and hop.
		if timeoutDeadline and os.clock() >= timeoutDeadline then
			AutoFerryman.hop(TEXT.reasonTimeout)
			return
		end

		-- A moderator is in the server (mod notifications logic) -- hop away.
		local hasMods = false
		pcall(function()
			hasMods = PlayerScanning.hasModerators()
		end)
		if hasMods then
			AutoFerryman.hop(TEXT.reasonModerator)
			return
		end

		-- Hold off auto-log briefly after a descent -- players loading in around the freshly-streamed
		-- island shouldn't trigger an instant log.
		if lastDescentClock and (os.clock() - lastDescentClock) < DESCENT_LOG_GRACE then
			continue
		end

		local character = localPlayer and localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end

		local autoLogDist = AutoLog.get("auto_ferryman")
		if autoLogDist > 0 and Finder.pnear(root.Position, autoLogDist) then
			AutoFerryman.hop(TEXT.reasonPlayerNearby)
			return
		end
	end
end

---Sum a tool's "Quantity" IntValue across the backpack AND the character (a stack that's currently
---equipped lives under the Character, not the Backpack -- missing that was why the count sometimes
---read low). Returns 0 if the tool (or the value) isn't found.
---@param toolName string
---@return number
local function getToolQuantity(toolName)
	local total = 0

	local containers = {
		localPlayer and localPlayer:FindFirstChild("Backpack"),
		localPlayer and localPlayer.Character,
	}

	for _, container in next, containers do
		if container then
			for _, tool in next, container:GetChildren() do
				if tool:IsA("Tool") and tool.Name == toolName then
					local quantity = tool:FindFirstChild("Quantity")
					if quantity and quantity:IsA("IntValue") then
						total = total + quantity.Value
					end
				end
			end
		end
	end

	return total
end

---Count an item across the backpack AND character. Uses the "Quantity" IntValue when present,
---otherwise counts one per matching tool (some items -- e.g. Flint, Coal -- may not carry a stack
---value). Returns 0 if none are found.
---@param name string
---@return number
local function getItemCount(name)
	local total = 0

	local containers = {
		localPlayer and localPlayer:FindFirstChild("Backpack"),
		localPlayer and localPlayer.Character,
	}

	for _, container in next, containers do
		if container then
			for _, tool in next, container:GetChildren() do
				if tool:IsA("Tool") and tool.Name == name then
					local quantity = tool:FindFirstChild("Quantity")
					if quantity and quantity:IsA("IntValue") then
						total = total + quantity.Value
					else
						total = total + 1
					end
				end
			end
		end
	end

	return total
end

---Total remaining flint "Uses" across the backpack AND character, counting both Flint and Umbral
---Flint (each carries a "Uses" IntValue). One use lights one campfire. Returns 0 if there's none.
---@return number
local function flintUses()
	local total = 0

	local containers = {
		localPlayer and localPlayer:FindFirstChild("Backpack"),
		localPlayer and localPlayer.Character,
	}

	for _, container in next, containers do
		if container then
			for _, tool in next, container:GetChildren() do
				if tool:IsA("Tool") and (tool.Name == "Flint" or tool.Name == "Umbral Flint") then
					local uses = tool:FindFirstChild("Uses")
					if uses and uses:IsA("IntValue") then
						total = total + uses.Value
					end
				end
			end
		end
	end

	return total
end

---Find an instance named "Choice" of the given class. The craft menu's per-session remotes are
---nil-parented (their DebugIds change every session, so we match by name + class), but fall back to
---a full game scan in case this executor parents them somewhere real.
---@param className string
---@param timeout number?
---@return Instance?
local function findChoiceRemote(className, timeout)
	local deadline = os.clock() + (timeout or 5)

	local function scan()
		-- Nil-parented instances (the documented location).
		if getnilinstances then
			local ok, instances = pcall(getnilinstances)
			if ok and type(instances) == "table" then
				for _, object in next, instances do
					local matches = false
					pcall(function()
						matches = object.Name == "Choice" and object:IsA(className)
					end)
					if matches then
						return object
					end
				end
			end
		end

		-- Fallback: anywhere under game.
		local ok, found = pcall(function()
			for _, object in next, game:GetDescendants() do
				if object.Name == "Choice" and object:IsA(className) then
					return object
				end
			end
		end)
		if ok and found then
			return found
		end

		return nil
	end

	repeat
		local found = scan()
		if found then
			return found
		end
		task.wait()
	until os.clock() >= deadline

	return nil
end

---Craft `count` of a recipe, mimicking the game's crafting exactly (CraftScript + ChoiceScript):
--- 1) `Requests.Craft:InvokeServer(recipeTable, product)` -- recipeTable is the ingredient set
---    ({ [ingredient] = true, ... }) and product is the recipe name. For stackable recipes this opens the
---    quantity-slider ChoicePrompt (and yields until it's answered, so we fire it on its own thread).
--- 2) submit the amount like the slider's Submit button: `Choice:InvokeServer(count)` (a RemoteFunction).
---    Recipes that craft directly (no slider) never spawn a Choice, so that step is skipped after a short
---    wait.
---@param materials table Ingredient set, e.g. { Wood = true } or { Coal = true, Rock = true }.
---@param recipeName string The product to craft, e.g. "Campfire Pit" or "Flint".
---@param count number
---@return boolean
local function craftBatch(materials, recipeName, count)
	if count <= 0 then
		return true
	end

	local requests = replicatedStorage:FindFirstChild("Requests")
	local craftRemote = requests and requests:FindFirstChild("Craft")
	if not craftRemote then
		Logger.warn(TEXT.craftRemoteMissing)
		return false
	end

	-- 1) Fire the craft (opens the quantity slider for stackable recipes). Spawned because it yields
	-- until the quantity Choice is answered.
	task.spawn(function()
		pcall(function()
			craftRemote:InvokeServer(materials, recipeName)
		end)
	end)

	-- 2) Submit the quantity via the ChoicePrompt's Choice RemoteFunction (the slider's Submit), asking
	-- for the full count in one go. If no slider appears (direct craft), skip.
	local quantityChoice = findChoiceRemote("RemoteFunction", 5)
	if quantityChoice then
		task.spawn(function()
			pcall(function()
				quantityChoice:InvokeServer(count)
			end)
		end)
	end

	return true
end

---Craft `amount` Campfire Pits from Wood (1:1). Sticks are not used.
---@param amount number
---@return boolean crafted Whether crafting ran.
local function craftCampfires(amount)
	return craftBatch({ Wood = true }, "Campfire Pit", amount)
end

---How many campfires the current Wood stock can make (1 per Wood). Sticks are not used.
---@return number
local function craftableCampfires()
	return math.floor(getToolQuantity("Wood") / WOOD_PER_CAMPFIRE)
end

---Nearest live tree model in workspace.Destructibles (a Model with "Tree" in its name), restricted
---to trees within TREE_ISLAND_RANGE of the island so we never wander off for a far-off tree.
---@return Model?
local function findTree()
	local destructibles = workspace:FindFirstChild("Destructibles")
	if not destructibles then
		return nil
	end

	local character = localPlayer and localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = (root and root.Position) or FERRYMAN_TARGET

	local best, bestDistance = nil, math.huge

	for _, model in next, destructibles:GetChildren() do
		if model:IsA("Model") and model.Parent and model.Name:find("Tree") then
			local ok, pivot = pcall(function()
				return model:GetPivot().Position
			end)
			if ok then
				-- Must be within range of the island, else skip it entirely.
				if (pivot - FERRYMAN_TARGET).Magnitude <= TREE_ISLAND_RANGE then
					local distance = (pivot - origin).Magnitude
					if distance < bestDistance then
						best = model
						bestDistance = distance
					end
				end
			end
		end
	end

	return best
end

---Equip the Lumber Axe. If one is already on the character it's reused; otherwise it's pulled from
---the backpack. If the player has no Lumber Axe at all, leave the game (kick).
---@return Tool?
local function equipLumberAxe()
	local character = localPlayer and localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return nil
	end

	local equipped = character:FindFirstChild("Lumber Axe")
	if equipped and equipped:IsA("Tool") then
		return equipped
	end

	local backpack = localPlayer:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild("Lumber Axe")
	if not (tool and tool:IsA("Tool")) then
		Logger.notify(TEXT.noLumberAxeNotify)
		AutoFerryman.stop()
		pcall(function()
			localPlayer:Kick(TEXT.kickNoLumberAxe)
		end)
		return nil
	end

	pcall(function()
		humanoid:EquipTool(tool)
	end)

	return character:FindFirstChild("Lumber Axe")
end

---Nearest live "Campfire" in Destructibles within CAMPFIRE_BREAK_RANGE of the island spot we tweened
---down to. Campfires can be a Model or a bare MeshPart, so match either.
---@return Instance?
local function findNearbyCampfire()
	local destructibles = workspace:FindFirstChild("Destructibles")
	if not destructibles then
		return nil
	end

	local reference = Vector3.new(FERRYMAN_TARGET.X, FERRYMAN_DESCENT_Y, FERRYMAN_TARGET.Z)
	local best, bestDistance = nil, math.huge

	for _, object in next, destructibles:GetChildren() do
		if (object:IsA("Model") or object:IsA("BasePart")) and object.Parent and object.Name:find("Campfire") then
			local ok, pivot = pcall(function()
				return object:GetPivot().Position
			end)
			if ok then
				local distance = (pivot - reference).Magnitude
				if distance <= CAMPFIRE_BREAK_RANGE and distance < bestDistance then
					best = object
					bestDistance = distance
				end
			end
		end
	end

	return best
end

---Equip the axe, tween to a destructible (Model or MeshPart), and keep swinging until it is deleted.
---@param model Instance
---@return boolean destroyed True once it is gone; false if kicked (no axe) or stopped.
local function chopModel(model)
	if not equipLumberAxe() then
		return false -- kicked (no axe) or no character
	end

	local position = model:GetPivot().Position

	while AutoFerryman.running and model.Parent do
		-- Hold position at the model.
		Tweening.goal(CHOP_TWEEN_IDENTIFIER, CFrame.new(position), false)

		-- Keep the axe equipped (a respawn/unequip would otherwise silently stop the chopping).
		local axe = equipLumberAxe()
		if not axe then
			Tweening.stop(CHOP_TWEEN_IDENTIFIER)
			return false
		end

		-- Swing.
		pcall(function()
			axe:Activate()
		end)

		task.wait(CHOP_SWING_INTERVAL)
	end

	Tweening.stop(CHOP_TWEEN_IDENTIFIER)

	return model.Parent == nil
end

---Chop the nearest tree down for wood.
---@return boolean destroyed True once a tree was chopped down; false if none/kicked/stopped.
local function chopTree()
	-- Wait for a tree within range to appear (they respawn). If none shows within 60s this server is
	-- barren -- hop to a fresh one.
	local tree = findTree()
	local deadline = os.clock() + 60
	while not tree and AutoFerryman.running do
		if os.clock() >= deadline then
			AutoFerryman.hop(TEXT.reasonNoTrees)
			return false
		end
		AutoFerryman.setAction(TEXT.waitingForTree)
		task.wait(1)
		tree = findTree()
	end

	if not AutoFerryman.running or not tree then
		return false
	end

	AutoFerryman.setAction(TEXT.choppingTree)
	return chopModel(tree)
end

---Equip the Campfire Pit tool (from the character or the backpack).
---@return Tool?
local function equipCampfirePit()
	local character = localPlayer and localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return nil
	end

	local equipped = character:FindFirstChild("Campfire Pit")
	if equipped and equipped:IsA("Tool") then
		return equipped
	end

	local backpack = localPlayer:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild("Campfire Pit")
	if not (tool and tool:IsA("Tool")) then
		return nil
	end

	pcall(function()
		humanoid:EquipTool(tool)
	end)

	return character:FindFirstChild("Campfire Pit")
end

---Equip a flint to light campfires -- prefer an Umbral Flint if we have one, else a normal Flint.
---Flint is gated before placement now, so a miss here just returns nil rather than kicking.
---@return Tool?
local function equipFlint()
	local character = localPlayer and localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return nil
	end

	local backpack = localPlayer:FindFirstChild("Backpack")

	local function find(name)
		return character:FindFirstChild(name) or (backpack and backpack:FindFirstChild(name))
	end

	local tool = find("Umbral Flint") or find("Flint")
	if not (tool and tool:IsA("Tool")) then
		return nil
	end

	local name = tool.Name
	pcall(function()
		humanoid:EquipTool(tool)
	end)

	return character:FindFirstChild(name)
end

---Tween to a CFrame (position + facing) and hold there until we arrive or stop.
---@param cframe CFrame
local function moveTo(cframe)
	Tweening.goal(TWEEN_IDENTIFIER, cframe, false)

	while AutoFerryman.running do
		local character = localPlayer and localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local dx = cframe.Position.X - root.Position.X
			local dz = cframe.Position.Z - root.Position.Z
			if math.sqrt(dx * dx + dz * dz) <= 2 then
				break
			end
		end
		runService.Heartbeat:Wait()
	end

	Tweening.stop(TWEEN_IDENTIFIER)
end

---Tween to each placement spot and place a campfire there.
local function placeCampfires()
	for index, cframe in ipairs(PLACE_LOCATIONS) do
		if not AutoFerryman.running then
			return
		end

		AutoFerryman.setAction(string.format(TEXT.placingCampfire, index, #PLACE_LOCATIONS))

		moveTo(cframe)
		if not AutoFerryman.running then
			return
		end

		-- Nail the exact position + facing before placing.
		local character = localPlayer and localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = cframe
		end

		local tool = equipCampfirePit()
		if tool then
			task.wait(0.3)
			pcall(function()
				tool:Activate()
			end)
		end

		task.wait(1)

		-- Light the campfire: equip Flint, then click it. Kicks if the player has none.
		local flint = equipFlint()
		if not flint then
			return -- kicked (no flint) or stopped
		end

		task.wait(0.3)
		pcall(function()
			flint:Activate()
		end)

		-- Extra second after using the flint before moving to the next campfire.
		task.wait(1)
	end
end

---Get to REQUIRED_CAMPFIRES: chop trees for wood as needed, then craft once. Crafting is a single
---attempt -- if it doesn't produce campfires, we stop retrying and let the action timeout hop us.
---@return boolean ok
local function acquireCampfires()
	while AutoFerryman.running do
		AutoFerryman.setAction(TEXT.checkingCampfires)

		local campfires = getToolQuantity("Campfire Pit")
		if campfires >= REQUIRED_CAMPFIRES then
			return true
		end

		local needed = REQUIRED_CAMPFIRES - campfires

		if craftableCampfires() >= needed then
			-- Enough materials on hand: craft the shortfall once, then wait for the count to rise.
			AutoFerryman.setAction(string.format(TEXT.craftingCampfires, needed))
			craftCampfires(needed)

			local before = campfires
			local deadline = os.clock() + 12
			repeat
				task.wait(0.5)
			until (not AutoFerryman.running)
				or getToolQuantity("Campfire Pit") > before
				or os.clock() >= deadline

			if not AutoFerryman.running then
				return false
			end

			if getToolQuantity("Campfire Pit") <= before then
				-- One craft attempt produced nothing -- hop to a fresh server right away.
				AutoFerryman.setAction(TEXT.campfireCraftFailed)
				AutoFerryman.hop(TEXT.reasonCraftFailed)
				return false
			end
			-- Progress -- loop and re-check.
		else
			-- Short on materials: chop a tree for wood, then re-check. Give the drop a moment to
			-- replicate so the next material count includes it.
			if not chopTree() then
				return false -- no trees left, no axe (kicked), or stopped
			end
			task.wait(1)
		end
	end

	return false
end

---Nearest mesh named `meshName` in workspace.Ingredients (searched deep), by distance from the HRP,
---restricted to meshes within MINER_RANGE of Miner's Landing.
---@param meshName string
---@return BasePart?
local function findNearestIngredient(meshName)
	local ingredients = workspace:FindFirstChild(INGREDIENTS_FOLDER)
	if not ingredients then
		return nil
	end

	local character = localPlayer and localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = (root and root.Position) or MINER_TARGET

	local best, bestDistance = nil, math.huge

	for _, object in next, ingredients:GetDescendants() do
		if object:IsA("BasePart") and object.Name == meshName and object.Parent then
			-- Must be within range of Miner's Landing, else skip it entirely.
			if (object.Position - MINER_TARGET).Magnitude <= MINER_RANGE then
				local distance = (object.Position - origin).Magnitude
				if distance < bestDistance then
					best = object
					bestDistance = distance
				end
			end
		end
	end

	return best
end

---Equip a Pickaxe (from the character or backpack). No kick here -- the caller gates on it.
---@return Tool?
local function equipPickaxe()
	local character = localPlayer and localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return nil
	end

	local equipped = character:FindFirstChild("Pickaxe")
	if equipped and equipped:IsA("Tool") then
		return equipped
	end

	local backpack = localPlayer:FindFirstChild("Backpack")
	local tool = backpack and backpack:FindFirstChild("Pickaxe")
	if not (tool and tool:IsA("Tool")) then
		return nil
	end

	pcall(function()
		humanoid:EquipTool(tool)
	end)

	return character:FindFirstChild("Pickaxe")
end

---Mine one `itemName` off the nearest `meshName` in Ingredients: tween to it, keep the Pickaxe
---equipped, and fire its InteractPrompt until our item count goes up.
---@param meshName string
---@param itemName string
---@return boolean ok True once we've gained one; false if none found / stuck / stopped.
local function mineIngredient(meshName, itemName)
	local before = getItemCount(itemName)

	while AutoFerryman.running do
		if getItemCount(itemName) > before then
			return true
		end

		-- Wait for an in-range mesh to appear (they respawn). If none shows within 60s this server is
		-- barren -- hop to a fresh one.
		local mesh = findNearestIngredient(meshName)
		local deadline = os.clock() + 60
		while not mesh and AutoFerryman.running do
			if os.clock() >= deadline then
				AutoFerryman.hop(string.format(TEXT.reasonNoMesh, meshName))
				return false
			end
			AutoFerryman.setAction(string.format(TEXT.waitingForMesh, meshName))
			task.wait(1)
			mesh = findNearestIngredient(meshName)
		end
		if not AutoFerryman.running or not mesh then
			return false
		end

		AutoFerryman.setAction(string.format(TEXT.miningMesh, meshName))
		moveTo(CFrame.new(mesh.Position))
		if not AutoFerryman.running then
			return false
		end

		-- Keep the pickaxe equipped and fire the mesh's proximity prompt.
		equipPickaxe()
		Prompt.interact(mesh:FindFirstChild(INTERACT_PROMPT_NAME))

		task.wait(1)
	end

	return false
end

---Craft one flint (a single attempt). If we have Umbral Obsidian, craft an Umbral Flint (1 Umbral
---Obsidian + 1 Coal); otherwise a normal Flint (Coal + Rock). If it produces nothing we stop retrying
---and let the action timeout hop us.
---@return boolean ok
local function craftFlint()
	if not AutoFerryman.running then
		return false
	end

	local umbral = getItemCount("Umbral Obsidian") >= 1

	AutoFerryman.setAction(umbral and TEXT.craftingUmbralFlint or TEXT.craftingFlint)

	local before = flintUses()
	if umbral then
		craftBatch({ ["Umbral Obsidian"] = true, Coal = true }, "Umbral Flint", 1)
	else
		craftBatch({ Coal = true, Rock = true }, "Flint", 1)
	end

	local deadline = os.clock() + 12
	repeat
		task.wait(0.5)
	until (not AutoFerryman.running) or flintUses() > before or os.clock() >= deadline

	if not AutoFerryman.running then
		return false
	end

	if flintUses() > before then
		return true
	end

	-- One craft attempt produced nothing -- hop to a fresh server right away.
	AutoFerryman.setAction(TEXT.flintCraftFailed)
	AutoFerryman.hop(TEXT.reasonFlintCraftFailed)
	return false
end

---Out of flint: make sure we have 1 Coal + 1 Rock (mining them at Miner's Landing only if we don't
---already have them), then craft a Flint. Kicks only if we actually need to mine but have no Pickaxe.
---@return boolean ok True once a flint has been crafted; false if kicked / hopped / stopped.
local function mineForFlint()
	-- With Umbral Obsidian we craft Umbral Flint (Obsidian + Coal), so Rock isn't needed.
	local umbral = getItemCount("Umbral Obsidian") >= 1
	local needCoal = getItemCount("Coal") < 1
	local needRock = (not umbral) and getItemCount("Rock") < 1

	-- Only make the mining trip if we're missing a material -- otherwise craft with what we have.
	if needCoal or needRock then
		-- Pickaxe gate (only needed to mine).
		local character = localPlayer and localPlayer.Character
		local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
		local hasPickaxe = (character and character:FindFirstChild("Pickaxe"))
			or (backpack and backpack:FindFirstChild("Pickaxe"))
		if not hasPickaxe then
			Logger.notify(TEXT.noPickaxeNotify)
			AutoFerryman.stop()
			pcall(function()
				localPlayer:Kick(TEXT.kickNoPickaxe)
			end)
			return false
		end

		-- Fly to Miner's Landing (skip the fly-up if we're already within range horizontally).
		local startRoot = localPlayer and localPlayer.Character
			and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		local alreadyNear = false
		if startRoot then
			local dx = MINER_TARGET.X - startRoot.Position.X
			local dz = MINER_TARGET.Z - startRoot.Position.Z
			alreadyNear = math.sqrt(dx * dx + dz * dz) <= ISLAND_NEAR_RANGE
		end

		if not alreadyNear then
			flying = true
			tweenTo(Vector3.new(MINER_TARGET.X, FERRYMAN_TWEEN_Y, MINER_TARGET.Z), "Miners Landing")
		end
		if not AutoFerryman.running then
			return false
		end

		-- Instant descend to the ground.
		Tweening.stop(TWEEN_IDENTIFIER)
		local root = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(MINER_TARGET)
		end
		flying = false
		lastDescentClock = os.clock()

		if not AutoFerryman.running then
			return false
		end

		equipPickaxe()

		-- Mine only what we're missing.
		if needCoal and not mineIngredient("Coal", "Coal") then
			return false
		end
		if needRock and not mineIngredient("Rock", "Rock") then
			return false
		end
	end

	-- Craft the flint.
	return craftFlint()
end

---The (early) ferryman routine: fly up, descend onto the island, then make sure we have campfires.
local function runRoutine()
	-- Flint check FIRST (before flying to the island): one Use per campfire. If we're short, go mine
	-- coal + rock and craft flint at Miner's Landing, then rerun the whole loop.
	if flintUses() < REQUIRED_CAMPFIRES then
		if mineForFlint() then
			return runRoutine() -- got flint; restart the whole loop (tail call, no stack growth)
		end
		return -- kicked (no pickaxe), hopped (craft/mining failed), or stopped
	end

	-- Skip the fly-up entirely if we're already within range of the island (horizontally).
	local startCharacter = localPlayer and localPlayer.Character
	local startRoot = startCharacter and startCharacter:FindFirstChild("HumanoidRootPart")
	local alreadyNear = false
	if startRoot then
		local dx = FERRYMAN_TARGET.X - startRoot.Position.X
		local dz = FERRYMAN_TARGET.Z - startRoot.Position.Z
		alreadyNear = math.sqrt(dx * dx + dz * dz) <= ISLAND_NEAR_RANGE
	end

	if not alreadyNear then
		flying = true
		tweenTo(Vector3.new(FERRYMAN_TARGET.X, FERRYMAN_TWEEN_Y, FERRYMAN_TARGET.Z))
	end

	if not AutoFerryman.running then
		return
	end

	-- Instant descend onto the island.
	Tweening.stop(TWEEN_IDENTIFIER)

	local character = localPlayer and localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(FERRYMAN_TARGET.X, FERRYMAN_DESCENT_Y, FERRYMAN_TARGET.Z)
	end
	flying = false
	lastDescentClock = os.clock()

	if not AutoFerryman.running then
		return
	end

	-- Phase: campfire pits -- chop trees for wood as needed, craft, repeat until enough.
	if not acquireCampfires() then
		-- If a hop is in flight (craft failure), leave the resume flag alone; otherwise this is a
		-- terminal failure (e.g. no trees left) -- stop for good.
		if not hopping then
			AutoFerryman.stop()
		end
		return
	end

	if not AutoFerryman.running then
		return
	end

	AutoFerryman.setAction(TEXT.campfiresReady)

	-- Phase: break existing campfires near the island with the Lumber Axe.
	while AutoFerryman.running do
		local campfire = findNearbyCampfire()
		if not campfire then
			break
		end

		AutoFerryman.setAction(TEXT.breakingCampfire)
		if not chopModel(campfire) then
			return -- kicked (no axe) or stopped
		end
	end

	if not AutoFerryman.running then
		return
	end

	-- Phase: place the fresh campfires at the 4 spots (flint was ensured at the top of the loop).
	placeCampfires()

	if not AutoFerryman.running then
		return
	end

	AutoFerryman.setAction(TEXT.campfiresPlaced)
end

---The Ferryman NPC model in workspace.NPCs, or nil.
---@return Model?
local function findFerrymanNpc()
	local npcs = workspace:FindFirstChild(NPCS_FOLDER)
	local ferryman = npcs and npcs:FindFirstChild(FERRYMAN_NPC_NAME)
	if ferryman and ferryman:IsA("Model") then
		return ferryman
	end
	return nil
end

---Tap a keyboard key once via VirtualInputManager.
---@param keyCode Enum.KeyCode
local function pressKey(keyCode)
	pcall(function()
		local vim = Instance.new("VirtualInputManager")
		vim:SendKeyEvent(true, keyCode, false, game)
		vim:SendKeyEvent(false, keyCode, false, game)
	end)
end

---The boss model (".ferryman1") in workspace.Live, or nil.
---@return Model?
local function findBossModel()
	local live = workspace:FindFirstChild(LIVE_FOLDER)
	local boss = live and live:FindFirstChild(BOSS_MODEL_NAME)
	if boss and boss:IsA("Model") then
		return boss
	end
	return nil
end

---Which attack the boss is currently playing: "triple" (pause our M1 + hold), "javelin" (drop to the
---ground to dodge), or nil. Mirrors PR ferryman's AnimationPlayed handling.
---@param boss Instance
---@return string?
local function bossAnimState(boss)
	local animator = boss:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return nil
	end

	local ok, tracks = pcall(function()
		return animator:GetPlayingAnimationTracks()
	end)
	if not ok or not tracks then
		return nil
	end

	for _, track in next, tracks do
		local anim = track.Animation
		local id = anim and tostring(anim.AnimationId)
		if id then
			if id:find(BOSS_JAVELIN_ANIM_ID, 1, true) then
				return "javelin"
			end

			for _, tripleId in next, BOSS_TRIPLE_ANIM_IDS do
				if id:find(tripleId, 1, true) then
					return "triple"
				end
			end
		end
	end

	return nil
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

---Draw the "Weapon" tool via the DrawWeapon remote (instead of EquipTool). Returns the weapon tool if
---one exists (character or backpack), nil otherwise.
---@return Tool?
local function equipWeapon()
	local character = localPlayer and localPlayer.Character
	if not character then
		return nil
	end

	-- The Weapon tool, wherever it lives.
	local tool = character:FindFirstChild(WEAPON_NAME)
	if not (tool and tool:IsA("Tool")) then
		local backpack = localPlayer:FindFirstChild("Backpack")
		tool = backpack and backpack:FindFirstChild(WEAPON_NAME)
	end
	if not (tool and tool:IsA("Tool")) then
		return nil
	end

	-- Draw it via the remote, only if it isn't already out.
	if not isWeaponDrawn() then
		local handler = character:FindFirstChild("CharacterHandler")
		local requests = handler and handler:FindFirstChild("Requests")
		local drawEvent = requests and requests:FindFirstChild("DrawWeapon")
		if drawEvent then
			pcall(function()
				drawEvent:FireServer(true)
			end)
		end
	end

	return tool
end

---Turn on the combat features we want for the boss fight: Auto Defense, Block Input (PVE, blocking
---M1s/Criticals/Mantras), and Auto Feint (all move types).
local function enableBossCombat()
	if Options then
		if Options.BlockInputAllowedTargets then
			Options.BlockInputAllowedTargets:SetValue({ PVE = true })
		end
		if Options.BlockedSafeInputUserMoves then
			Options.BlockedSafeInputUserMoves:SetValue({ M1s = true, Criticals = true, Mantras = true })
		end
		if Options.AutoFeintOwnTags then
			Options.AutoFeintOwnTags:SetValue({ M1s = true, Mantras = true })
		end
		if Options.AutoFeintAgainstTags then
			Options.AutoFeintAgainstTags:SetValue({ M1s = true, Mantras = true, Criticals = true })
		end
	end

	if Toggles then
		if Toggles.EnableAutoDefense then
			Toggles.EnableAutoDefense:SetValue(true)
		end
		if Toggles.BlockInput then
			Toggles.BlockInput:SetValue(true)
		end
		if Toggles.AutoFeint then
			Toggles.AutoFeint:SetValue(true)
		end
		if Toggles.Fling then
			Toggles.Fling:SetValue(false)
		end
	end
end

---Name-matched loot: fire the ChoicePrompt's Choice remote for every option button whose title matches
---one of `names` (case-insensitive substring). Mirrors the automation folder's loot_from_prompt.
---@param choicePrompt Instance
---@param names table
---@return boolean selected
local function lootMatchingItems(choicePrompt, names)
	local frame = choicePrompt:FindFirstChild("ChoiceFrame")
	local options = frame and frame:FindFirstChild("Options")
	local choice = choicePrompt:FindFirstChild("Choice")
	if not options or not choice then
		return false
	end

	local selected = false
	for _, button in next, options:GetChildren() do
		if not button:IsA("TextButton") then
			continue
		end
		local title = button:FindFirstChild("Title")
		local text = title and title.Text
		if not text then
			continue
		end
		local lower = text:lower()
		for _, name in next, names do
			if type(name) == "string" and lower:find(name:lower(), 1, true) then
				pcall(function()
					choice:FireServer(button.Name)
				end)
				selected = true
				task.wait(0.1)
				break
			end
		end
	end
	return selected
end

---All chests near us: workspace.Thrown descendants named "Lid" (BaseParts) -> their parent model, within
---`maxDistance`. Direct port of PR ferryman's find_chests.
---@param maxDistance number?
---@return table
local function findChests(maxDistance)
	local chests = {}
	local thrown = workspace:FindFirstChild(THROWN_FOLDER)
	if not thrown then
		return chests
	end
	local character = localPlayer and localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for _, object in next, thrown:GetDescendants() do
		if object.Name == "Lid" and object:IsA("BasePart") then
			if not maxDistance or not root or (root.Position - object.Position).Magnitude <= maxDistance then
				table.insert(chests, object.Parent)
			end
		end
	end
	return chests
end

---After the boss dies, loot the chests -- direct port of PR ferryman's grab_chests: tween onto each lid,
---spam its proximity prompt until the ChoicePrompt opens, name-match loot the wanted items, wait for the
---prompt to close, handle a Craft prompt (-> Campfire Pit), and tag the chest looted.
local function lootChests()
	AutoFerryman.setAction(TEXT.lootingChests)

	-- PR ferryman takes Umbral Obsidian + Coal; merge in the user's configured items too.
	local wanted = { ALWAYS_LOOT, "Coal" }
	for _, name in next, (Configuration.expectOptionValues("ItemNameList") or {}) do
		wanted[#wanted + 1] = name
	end

	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	local function choicePrompt()
		return playerGui and playerGui:FindFirstChild("ChoicePrompt")
	end

	-- Wait for the chests to spawn (up to 30s).
	local spawnDeadline = os.clock() + 30
	repeat
		AutoFerryman.setAction(TEXT.waitingForChests)
		task.wait(0.5)
	until #findChests(2000) > 0 or os.clock() >= spawnDeadline or not AutoFerryman.running

	for _, chest in next, findChests(2000) do
		if not AutoFerryman.running then
			break
		end
		if not collectionService:HasTag(chest, LOOTED_TAG) and chest:FindFirstChild("Lid") then
			AutoFerryman.setAction(TEXT.lootingChest)

			-- Tween onto the lid and spam the chest's proximity prompt until the ChoicePrompt opens.
			pcall(function()
				moveTo(chest.Lid.CFrame)
			end)
			local openDeadline = os.clock() + 3
			repeat
				pcall(function()
					Prompt.interact(chest:FindFirstChildWhichIsA("ProximityPrompt", true))
				end)
				pcall(function()
					moveTo(chest.Lid.CFrame)
				end)
				task.wait(1)
			until choicePrompt() or os.clock() >= openDeadline or not AutoFerryman.running

			-- Name-match the wanted items out of the prompt.
			if choicePrompt() then
				pcall(function()
					lootMatchingItems(choicePrompt(), wanted)
				end)
			end

			-- Wait for the prompt to close (up to 3s).
			local closeDeadline = os.clock() + 3
			repeat
				task.wait(1)
			until not choicePrompt() or os.clock() >= closeDeadline or not AutoFerryman.running

			-- A Craft prompt (campfire pit) can pop -- pick Campfire Pit to clear it (PR).
			local cp = choicePrompt()
			if cp then
				local title = cp:FindFirstChild("Title", true)
				local choice = cp:FindFirstChild("Choice")
				if title and choice and tostring(title.Text):find("Craft") then
					pcall(function()
						choice:FireServer("Campfire Pit")
					end)
				end
			end

			pcall(function()
				collectionService:AddTag(chest, LOOTED_TAG)
			end)
		end
	end
end

---The boss-dungeon routine: tween to the Ferryman, start the interaction, and spam "1" to blow
---through the dialogue until the Ferryman leaves the NPCs folder (the fight is next -- built later).
local function bossRoutine()
	local ferryman = findFerrymanNpc()
	if not ferryman then
		AutoFerryman.setAction(TEXT.ferrymanNotFound)
		AutoFerryman.stop()
		return
	end

	-- Tween to the Ferryman.
	AutoFerryman.setAction(TEXT.tweeningToFerryman)
	local ok, pivot = pcall(function()
		return ferryman:GetPivot().Position
	end)
	if ok then
		moveTo(CFrame.new(pivot))
	end
	if not AutoFerryman.running then
		return
	end

	-- Interact with the Ferryman: fire its InteractPrompt until the dialogue opens, then walk its wager
	-- dialogue tree by firing Requests.SendDialogue with the exact choice strings (deterministic -- picks
	-- name -> wager -> deal, instead of blindly spamming "1"). setAction arms the timeout once; the loop
	-- uses setActionText so the timeout actually counts down, and we hop if it runs out.
	AutoFerryman.setAction(TEXT.talkingToFerryman)

	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")

	-- Fire the Ferryman's InteractPrompt until the dialogue GUI opens (matches PR: raw fireproximityprompt
	-- against workspace.NPCs['The Ferryman'].InteractPrompt). Timeout/running guards keep it from hanging.
	while AutoFerryman.running do
		if timeoutDeadline and os.clock() >= timeoutDeadline then
			AutoFerryman.hop(TEXT.reasonTimeout)
			return
		end

		local dialogueGui = playerGui and playerGui:FindFirstChild("DialogueGui")
		if dialogueGui and dialogueGui.Enabled then
			break -- dialogue is open, stop prompting
		end

		pcall(function()
			Prompt.interact(workspace.NPCs["The Ferryman"].InteractPrompt)
		end)

		setActionText(TEXT.talkingToFerryman)
		task.wait(0.5)
	end

	if not AutoFerryman.running then
		return
	end

	-- Walk the wager dialogue by firing the choices in order.
	setActionText(TEXT.advancingDialogue)
	local requests = replicatedStorage:FindFirstChild("Requests")
	local sendDialogue = requests and requests:FindFirstChild("SendDialogue")
	for index, choice in ipairs(FERRYMAN_DIALOGUE_CHOICES) do
		if not AutoFerryman.running then
			return
		end
		if sendDialogue then
			pcall(function()
				sendDialogue:FireServer({ choice = choice })
			end)
		end
		if index < #FERRYMAN_DIALOGUE_CHOICES then
			task.wait(0.5)
		end
	end

	AutoFerryman.setAction(TEXT.dialogueComplete)

	-- Wait for the boss to spawn as ".ferryman1" in workspace.Live.
	AutoFerryman.setAction(TEXT.waitingForBoss)
	while AutoFerryman.running and not findBossModel() do
		task.wait(0.5)
	end
	if not AutoFerryman.running then
		return
	end

	-- Turn on the combat features for the fight.
	enableBossCombat()

	-- Equip the weapon.
	local weapon = equipWeapon()
	if not weapon then
		AutoFerryman.setAction(TEXT.noWeapon)
		Logger.notify(TEXT.noWeaponNotify)
		AutoFerryman.stop()
		return
	end

	-- Continuously tween under the boss (facing up at it) and swing until it's gone. No fight timeout -- clear
	-- any armed deadline so the fight runs as long as it needs (it only ends when the boss is gone).
	armTimeout(nil)
	local healing = false
	while AutoFerryman.running do
		local boss = findBossModel()
		if not boss then
			break -- boss defeated / despawned (next phase later)
		end

		local root = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
		local bossHRP = boss:FindFirstChild("HumanoidRootPart")

		if root and humanoid and bossHRP then
			-- Heal hysteresis: once below 35% HP, go heal until back above 85% (PR's heal_cf loop).
			if healing then
				if humanoid.Health >= humanoid.MaxHealth * BOSS_HEAL_HIGH then
					healing = false
				end
			elseif humanoid.Health <= humanoid.MaxHealth * BOSS_HEAL_LOW then
				healing = true
			end

			local animState = bossAnimState(boss)

			if healing then
				-- Low HP: stop swinging and sit on the safe spot until we're topped up.
				setActionText(TEXT.fightingFerryman)
				Tweening.goal(CHOP_TWEEN_IDENTIFIER, BOSS_HEAL_CFRAME, false)
			elseif animState == "javelin" then
				-- Javelin throw: drop straight down to the ground to dodge it (PR drops to Y 0).
				Tweening.goal(CHOP_TWEEN_IDENTIFIER, CFrame.new(root.Position.X, 0, root.Position.Z), false)
			elseif animState == "triple" then
				-- Triple slash: hold still and stop attacking, let Auto Defense handle it.
				Tweening.stop(CHOP_TWEEN_IDENTIFIER)
			else
				-- Sit below + behind the boss in its own frame, facing it, then swing (PR: CFrame.new(0, -7, 4)).
				local targetCFrame = bossHRP.CFrame * CFrame.new(0, -BOSS_UNDER_OFFSET, BOSS_BEHIND_OFFSET)
				Tweening.goal(CHOP_TWEEN_IDENTIFIER, CFrame.lookAt(targetCFrame.Position, bossHRP.Position), false)

				equipWeapon()
				setActionText(TEXT.fightingFerryman)
				local aim = CFrame.new(root.Position, bossHRP.Position)
				pcall(function()
					InputClient.left(aim, true)
				end)
			end
		end

		task.wait(CHOP_SWING_INTERVAL)
	end

	Tweening.stop(CHOP_TWEEN_IDENTIFIER)

	if not AutoFerryman.running then
		return
	end

	-- Ferryman killed -- count the cycle and persist it.
	cycles = cycles + 1
	saveState()
	AutoFerryman.setAction(TEXT.bossDefeated)

	-- Loot the chests that spawn after the kill.
	lootChests()

	if not AutoFerryman.running then
		return
	end

	AutoFerryman.setAction(TEXT.chestsLooted)

	-- Make sure the chest's ChoicePrompt is fully closed before we hop (fire EXIT if it's still open,
	-- then wait for it to actually close, up to 3s).
	do
		local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
		local cp = playerGui and playerGui:FindFirstChild("ChoicePrompt")
		if cp then
			local choice = cp:FindFirstChild("Choice")
			if choice then
				pcall(function()
					choice:FireServer("EXIT")
				end)
			end
			local closeDeadline = os.clock() + 3
			repeat
				task.wait(0.1)
			until not (playerGui and playerGui:FindFirstChild("ChoicePrompt")) or os.clock() >= closeDeadline
		end
	end

	-- Restart the whole process on a fresh server (carries cycles + elapsed over).
	AutoFerryman.hop(TEXT.reasonCycleComplete)
end

---Update the "Current Action:" line. Each call counts as progress, so it re-arms the default
---timeout.
---@param text string?
function AutoFerryman.setAction(text)
	setActionText(text)
	armTimeout(DEFAULT_TIMEOUT)
end

---Is a tool present on the character or in the backpack?
---@param name string
---@return boolean
local function toolPresent(name)
	local character = localPlayer and localPlayer.Character
	local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
	if character and character:FindFirstChild(name) then
		return true
	end
	if backpack and backpack:FindFirstChild(name) then
		return true
	end
	return false
end

---Are we loaded in enough to start: character exists and the backpack contents have replicated.
---@return boolean
local function requirementsMet()
	local character = localPlayer and localPlayer.Character
	if not character then
		return false
	end
	local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
	return backpack ~= nil and #backpack:GetChildren() > 0
end

---Wait for the backpack to exist and have its contents replicated (up to `timeout`s).
---@param timeout number?
---@return boolean loaded
local function waitForBackpack(timeout)
	local deadline = os.clock() + (timeout or 10)
	while os.clock() < deadline do
		local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
		if backpack and #backpack:GetChildren() > 0 then
			return true
		end
		task.wait(0.1)
	end
	return false
end

---Start the automation (overlay + timer + highlight). The routine itself is not wired up yet.
function AutoFerryman.start()
	if AutoFerryman.running then
		return
	end

	-- Ended up in the Depths -- something went wrong; end the automation and leave immediately.
	if game.PlaceId == DEPTHS_PLACE_ID then
		AutoFerryman.stop()
		pcall(function()
			localPlayer:Kick(TEXT.kickDepths)
		end)
		return
	end

	-- Pick the mode from where we are: the Eastern Luminant runs the gather-to-dungeon routine, the
	-- boss dungeon (Ferryman present) runs the fight routine.
	local mode
	if AutoFerryman.inEasternLuminant() then
		mode = "gather"
	elseif AutoFerryman.inBossDungeon() then
		mode = "boss"
	else
		return Logger.notify(TEXT.notInPlace)
	end

	hopping = false
	flying = false
	timeoutDeadline = nil
	lastDescentClock = nil
	startClock = os.clock()

	-- Carry cycles + elapsed over from before a server hop (nil/fresh start -> 0). Loaded before the
	-- LoadingGui check so a loading-timeout hop preserves the running totals.
	local resumeData = PersistentData.get("afdata") or {}
	cycles = resumeData.cycles or 0
	baseElapsed = resumeData.elapsed or 0

	-- A manual first start (no resume flag yet) vs. an auto-resume after a hop.
	local firstStart = not resumeData.active

	-- Remember the slot we started on (a manual start locks in the current slot; a resume keeps it).
	if firstStart then
		startSlot = currentSlot()
	else
		startSlot = resumeData.slot
	end

	-- If the loading screen (LoadingGui) is up, fire the StartMenu.Start remote to blow through it until
	-- the character + backpack are loaded (10s cap). Handles resuming right after a hop. If we never load
	-- in, hop to a fresh server like the other timeouts.
	local loadingGuiParent = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if loadingGuiParent and loadingGuiParent:FindFirstChild("LoadingGui") then
		local deadline = os.clock() + 10
		while not requirementsMet() and os.clock() < deadline do
			General.fireStartMenu()
			task.wait(0.25)
		end

		if not requirementsMet() then
			-- Mark running so hop()'s guard/teardown behave, then hop.
			AutoFerryman.running = true
			return AutoFerryman.hop(TEXT.reasonLoadingTimeout)
		end
	end

	-- Wait for the backpack contents to replicate before we start (and before the tool check).
	waitForBackpack(10)

	-- First (manual) start: require a Pickaxe and Lumber Axe up front, else don't start.
	if firstStart and not (toolPresent("Pickaxe") and toolPresent("Lumber Axe")) then
		return Logger.notify(TEXT.needTools)
	end

	AutoFerryman.running = true

	-- Resume flag: survives server hops (MemStorage), so the farm restarts on the next server.
	saveState()

	buildOverlay()
	AutoFerryman.setAction(nil)
	if timerLabel then
		timerLabel.Text = formatElapsed(baseElapsed)
	end
	if timeoutLabel then
		timeoutLabel.Text = TEXT.timeoutNone
	end
	if cyclesLabel then
		cyclesLabel.Text = string.format(TEXT.cycles, cycles)
	end
	if screenGui then
		screenGui.Enabled = true
	end

	applyHighlight()
	applyTweenSpeed()
	applyNoFallDamage()
	applyFly()
	applyDefenseFilter()
	applyNoClip()

	-- Fast swing: strip attack cooldowns so m1s aren't rate-limited during the Ferryman fight.
	if not fastSwingConn then
		fastSwingConn = General.connectFastSwing()
	end

	-- Re-apply the highlight and re-pin the replication focus if we respawn mid-run.
	characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
		if not AutoFerryman.running then
			return
		end
		task.wait(0.2)
		applyHighlight()
	end)

	-- Tick the elapsed timer + the timeout countdown.
	timerConnection = runService.Heartbeat:Connect(function()
		if not AutoFerryman.running then
			return
		end
		if timerLabel then
			timerLabel.Text = formatElapsed(currentElapsed())
		end
		if cyclesLabel then
			cyclesLabel.Text = string.format(TEXT.cycles, cycles)
		end
		if timeoutLabel then
			if timeoutDeadline then
				local remaining = math.max(0, timeoutDeadline - os.clock())
				timeoutLabel.Text = string.format(TEXT.timeout, math.floor(remaining / 60), math.floor(remaining % 60))
			else
				timeoutLabel.Text = TEXT.timeoutNone
			end
		end
	end)

	-- Keep the weapon drawn during the boss fight (only while the boss is present, so it doesn't fight
	-- the pickaxe/lumber-axe phases): redraw it whenever it's sheathed, like the other farms.
	weaponConnection = runService.Heartbeat:Connect(function()
		if not AutoFerryman.running then
			return
		end
		if not findBossModel() then
			return
		end
		if not isWeaponDrawn() then
			equipWeapon()
		end
	end)

	-- Wait 2s before the first action so the auto-log watcher gets a chance to catch a nearby player
	-- (and hop) before we start flying.
	if mode == "boss" then
		-- Instanced dungeon -- no auto-log / server-hopping, just run the fight routine.
		task.spawn(function()
			task.wait(2)
			if AutoFerryman.running then
				bossRoutine()
			end
		end)
	else
		task.spawn(watchForNearbyPlayers)
		task.spawn(function()
			task.wait(2)
			if AutoFerryman.running then
				runRoutine()
			end
		end)
	end

	Logger.notify(TEXT.started)
end

---Tear down this run (threads, overlay, highlight, tweens, restored toggles) WITHOUT clearing the
---resume flag. Shared by stop() and the server-hop path.
local function teardown()
	AutoFerryman.running = false
	timeoutDeadline = nil

	if fastSwingConn then
		pcall(function()
			fastSwingConn:Disconnect()
		end)
		fastSwingConn = nil
	end

	-- If we were flying up when stopped, drop the character back to a normal Y (onto the island)
	-- instead of leaving them stranded in the sky.
	if flying then
		Tweening.stop(TWEEN_IDENTIFIER)
		local character = localPlayer and localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			pcall(function()
				root.CFrame = CFrame.new(FERRYMAN_TARGET.X, FERRYMAN_DESCENT_Y, FERRYMAN_TARGET.Z)
			end)
		end
	end
	flying = false

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

	if weaponConnection then
		pcall(function()
			weaponConnection:Disconnect()
		end)
		weaponConnection = nil
	end

	removeHighlight()

	Tweening.stop(TWEEN_IDENTIFIER)
	Tweening.stop(CHOP_TWEEN_IDENTIFIER)
	restoreTweenSpeed()
	restoreNoFallDamage()
	restoreFly()
	restoreDefenseFilter()
	restoreNoClip()

	if screenGui then
		screenGui.Enabled = false
	end
end

---Blacklist the current server and hop to a fresh one, keeping the resume flag set so Auto Ferryman
---restarts automatically after the teleport. Used by auto-log and craft-failure.
---@param reason string
function AutoFerryman.hop(reason)
	if hopping then
		return
	end
	hopping = true

	Logger.notify(TEXT.hopNotify, reason)

	-- Blacklist the current server (by JobId) so the hopper won't rejoin it, matching ServerHop's
	-- own blacklist shape (id -> tick()).
	local blacklist = PersistentData.get("sblacklist") or {}
	blacklist[game.JobId] = tick()
	PersistentData.set("sblacklist", blacklist)

	-- Keep the resume flag set (with cycles + elapsed) so the fresh server restarts and carries the
	-- running totals over.
	saveState()

	-- Stop this run but keep afdata, then hop (ServerHop returns to the menu, which rejoins a new
	-- server on the same slot).
	teardown()

	-- Use the slot we captured at start (persisted in afdata) rather than re-reading DataSlot now --
	-- a nil read here would set shslot = nil and the menu resume would never rejoin a server (looks
	-- like the automation just stopped).
	local slot = startSlot or (localPlayer and localPlayer:GetAttribute("DataSlot"))
	ServerHop.hop(slot, false)
end

---Stop the automation for good (manual): tears down and clears the resume flag.
function AutoFerryman.stop()
	if not AutoFerryman.running and not PersistentData.get("afdata") then
		return
	end

	teardown()

	-- Manual stop: clear the resume flag so a re-execute doesn't restart the farm.
	PersistentData.set("afdata", nil)

	Logger.notify(TEXT.stopped)
end

return AutoFerryman
