-- AutoLayer2: a Aero port of project-rain-oss's `auto_layer2.lua` -- the full Layer 2 raid CLEAR (not the
-- echo farm). Dives into the void to enter Layer 2, then runs the whole route on Aero's ported framework:
--
--   Floor 1: key/door -> bonekeeper -> generator -> chaser fight (snow cleanse, bloodjar, frost-grab void)
--            -> chest -> light-hook escape (or puzzle-skip once the chaser's already dead).
--   Floor 2: buzz obelisks -> kyrsan chests + klaris medallion shop -> miserables -> ethiron summon + the
--            bonespear/altar gauntlet (bomb-charge detection, stun windows, heal retreats) -> chest.
--
-- Public surface:
--   AutoLayer2.start() -- menu Start + resume entry (Aero.lua calls it when l2data survives a hop/teleport)
--   AutoLayer2.stop()  -- menu/overlay Stop
-- Persistence key: "l2data" { active, killedChaser }. Config is read live from the menu toggles (L2*).
--
-- NOTE: this is beta/content-specific. Every CFrame is PR's and can't be verified here -- if Deepwoken moves
-- the Layer 2 geometry, the waypoints need re-capturing. Expect to tune the chaser / ethiron timing in-game.
local AutoLayer2 = {}

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")

---@module Features.Game.Tweening
local Tweening = require("Features/Game/Tweening")

---@module Utility.Prompt
local Prompt = require("Utility/Prompt")

---@module Features.Automation.AutoLoot
local AutoLoot = require("Features/Automation/AutoLoot")

---@module Features.Combat.Defense
local Defense = require("Features/Combat/Defense")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Game.AntiAFK
local AntiAFK = require("Game/AntiAFK")

---@module GUI.Library
local Library = require("GUI/Library")

---@module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")

---@module Features.Automation.Objects.StateMachine
local StateMachine = require("Features/Automation/Objects/StateMachine")

---@module Features.Automation.Objects.AutomationStruct
local AutomationStruct = require("Features/Automation/Objects/AutomationStruct")

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local collectionService = game:GetService("CollectionService")

local EASTERN_PLACE_ID = 6473861193
local DEPTHS_PLACE_ID = 5735553160
local LOBBY_PLACE_ID = 4111023553

local MOVE_ID = "AutoLayer2_Move"
local PLAYER_SAFE_RADIUS = 400

local running = false
local struct = nil
local maid = Maid.new()
local screenGui, elapsedLabel = nil, nil
local startedAt = 0
local chaserFlingPrior = nil

-- =========================================================================================================
-- Accessors.
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

local function dungeon()
	local lp = localPlayer()
	return lp and lp:GetAttribute("Dungeon")
end

local function isRunning()
	return running
end

---Config toggle (menu). Defaults keep a first run sensible even before the user touches the section.
local function cfg(name, default)
	local v = Configuration.expectToggleValue(name)
	if v == nil then
		return default
	end
	return v
end

-- =========================================================================================================
-- Overlay (stage + stop).
-- =========================================================================================================
local function guiParent()
	return (gethui and gethui()) or game:GetService("CoreGui")
end

local function mk(class, props, parent)
	local instance = Instance.new(class)
	for k, v in pairs(props) do
		instance[k] = v
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
	screenGui.Name = "LumaAutoLayer2Overlay"
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
		Text = "Auto Layer 2",
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
		AutoLayer2.stop()
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

-- Stage text was replaced with an elapsed timer (matches the other automations); setStage is kept as a
-- no-op so the route's many setStage(...) callers don't need changing.
local function setStage(_) end

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
		if elapsedLabel then
			elapsedLabel.Text = "Elapsed: " .. formatDuration(math.max(0, os.time() - startedAt))
		end
		task.wait(0.5)
	end
end

-- =========================================================================================================
-- Movement + combat primitives (ported from PR's layertwo table + autofarm_util / safety).
-- =========================================================================================================
local function setSpeed(value)
	value = (Options and Options.Layer2TweenSpeed and Options.Layer2TweenSpeed.Value) or 100
	if Options and Options.TweenStudsPerSecond and Options.TweenStudsPerSecond.Value ~= value then
		Options.TweenStudsPerSecond:SetValue(value)
	end
end

---Blocking tween to a CFrame (PR's Tween.new(cf, true, speed).wait()).
local function tempTween(cframe, speed, smoothY, shouldInterrupt)
	setSpeed(speed or 175)
	Tweening.goal(MOVE_ID, cframe, false, smoothY)
	local goalPos = cframe.Position
	local reached = false
	while running do
		if shouldInterrupt and shouldInterrupt() then
			break
		end
		local r = root()
		if r and (r.Position - goalPos).Magnitude <= 5 then
			reached = true
			break
		end
		task.wait()
	end
	Tweening.stop(MOVE_ID)
	return reached
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
	pcall(function()
		ServerHop.hop(currentSlot(), true)
	end)
end

---Fly high over the map to a point, snapping down (PR safety:PlayerSafeTween). Hops if anyone's near.
local function playerSafeTween(cf, speed)
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
	local y = math.random(3000, 4000)
	r.CFrame = r.CFrame + Vector3.new(0, y, 0)
	tempTween(cf + Vector3.new(0, y, 0), speed)
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

local function drawWeapon()
	pcall(function()
		local c = character()
		if c and c:FindFirstChild("CharacterHandler") then
			c.CharacterHandler.Requests.DrawWeapon:FireServer(true)
		end
	end)
end

---Toggle held m1 attacks via the m1_hold struct feature (PR autofarm_util:Auto_M1).
local function autoM1(toggle)
	local feat = struct and struct.active_features and struct.active_features.m1_hold
	if feat then
		feat.held = toggle and true or false
	end
end

local function autoM1WhenSafe(toggle)
	autoM1(toggle and not Defense.shouldBlockInput("M1s"))
end

local function setVoidMobs(on)
	pcall(function()
		if Toggles and Toggles.VoidMobs then
			Toggles.VoidMobs:SetValue(on and true or false)
		end
	end)
end

local function setChaserFling(enabled)
	local toggle = Toggles and Toggles.Fling
	if not toggle then
		return
	end

	if not enabled then
		if chaserFlingPrior == nil then
			chaserFlingPrior = toggle.Value
		end
		toggle:SetValue(false)
	elseif chaserFlingPrior ~= nil then
		toggle:SetValue(chaserFlingPrior)
		chaserFlingPrior = nil
	end
end

local function disableStructFeature(name)
	pcall(function()
		local feat = struct and struct.active_features and struct.active_features[name]
		if feat then
			feat:disable()
			struct.active_features[name] = nil
		end
	end)
end

local function sendDialogue(text, exit)
	pcall(function()
		local send = replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue")
		if exit then
			send:FireServer({ exit = true })
		else
			send:FireServer({ choice = text })
		end
	end)
	if not exit then
		task.wait(0.5)
	end
end

local function dialogueOpen()
	local gui = playerGui()
	local dg = gui and gui:FindFirstChild("DialogueGui")
	return dg ~= nil and dg.Enabled == true
end

local function fireProx(prompt)
	if prompt then
		Prompt.interact(prompt)
	end
end

local function liveChildren()
	local live = workspace:FindFirstChild("Live")
	return live and live:GetChildren() or {}
end

local function thrownChildren()
	local thrown = workspace:FindFirstChild("Thrown")
	return thrown and thrown:GetChildren() or {}
end

-- =========================================================================================================
-- Geometry / target helpers (direct ports).
-- =========================================================================================================
local function getPosition(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.Position
	end
	if instance:IsA("Model") then
		if instance.GetPivot then
			return instance:GetPivot().Position
		elseif instance.PrimaryPart then
			return instance.PrimaryPart.Position
		end
		return nil
	end
	if instance:IsA("ObjectValue") and instance.Value then
		return getPosition(instance.Value)
	end
	return nil
end

local function getNearest(list, filter)
	local closest, dist = nil, 9e9
	local r = root()
	if not r then
		return nil
	end
	for _, v in next, list do
		if filter(v) then
			local pos = getPosition(v)
			if pos then
				local d = (pos - r.Position).Magnitude
				if d < dist then
					dist = d
					closest = v
				end
			end
		end
	end
	return closest
end

local function getBloodJar(target)
	local hrp = target and target:FindFirstChild("HumanoidRootPart")
	if hrp then
		local jar = hrp:FindFirstChild("BloodJar")
		if jar and jar.Value and jar.Value:IsDescendantOf(workspace) then
			return jar.Value
		end
	end
	return nil
end

local CHASER_SPIKE_GRACE = 2
local CHASER_BLOODWAVE_GRACE = 2
local lastChaserSpikeAt = 0
local lastChaserBloodwaveAt = 0
local CHASER_BLOODWAVE_SOUND = "REP_SOUND_428800263"

local function isChaserSpikeSignal(instance)
	local effects = instance.Parent
	local spikeMod = effects and effects.Parent
	local spikeTrap = spikeMod and spikeMod.Parent
	return
		(instance.Name == "SemiDust" or instance.Name == "RockDust" or instance.Name == "REP_SOUND_8044058354")
		and effects ~= nil
		and effects.Name == "Stalagmite"
		and spikeMod ~= nil
		and spikeMod.Name:match("SpikeMod") ~= nil
		and spikeTrap ~= nil
		and spikeTrap.Name == "SpecialSpikeTrap"
end

local function trackChaserSpikeSignal(instance)
	if isChaserSpikeSignal(instance) then
		lastChaserSpikeAt = os.clock()
	elseif instance.Name == CHASER_BLOODWAVE_SOUND and instance.Parent == workspace:FindFirstChild("EffectCenter") then
		lastChaserBloodwaveAt = os.clock()
	end
end

local function chaserHazardActive()
	local now = os.clock()
	if now - lastChaserSpikeAt < CHASER_SPIKE_GRACE then
		return true
	end
	if now - lastChaserBloodwaveAt < CHASER_BLOODWAVE_GRACE then
		return true
	end

	local spikeTrap = workspace:FindFirstChild("SpecialSpikeTrap")
	for _, spike in next, (spikeTrap and spikeTrap:GetChildren() or {}) do
		local stalagmite = spike.Name:match("SpikeMod") and spike:FindFirstChild("Stalagmite")
		if stalagmite
			and (
				stalagmite:FindFirstChild("SemiDust")
				or stalagmite:FindFirstChild("RockDust")
				or stalagmite:FindFirstChild("REP_SOUND_8044058354")
			)
		then
			lastChaserSpikeAt = now
			return true
		end
	end

	return false
end

local function hideFromChaserHazards(chaser, retreat)
	autoM1(false)
	while running and chaser.Parent and chaserHazardActive() do
		autoM1(false)
		local r = root()
		if r and (r.Position - retreat.Position).Magnitude > 8 then
			tempTween(retreat, 125, true, function()
				return not chaserHazardActive()
			end)
		else
			Tweening.stop(MOVE_ID)
			task.wait(0.1)
		end
	end
	Tweening.stop(MOVE_ID)
end

local function avatarExists()
	for _, avatar in next, liveChildren() do
		if avatar.Name:match("%.avatar") then
			return true
		end
	end
	return false
end

local function getNearestBoneSpear()
	local closest = nil
	local r = root()
	if not r then
		return nil
	end
	for _, object in next, thrownChildren() do
		if not object.Name:match("BoneSpear") or not object:FindFirstChild("InteractPrompt") then
			continue
		end
		if not closest or (r.Position - object.Position).Magnitude < (r.Position - closest.Position).Magnitude then
			closest = object
		end
	end
	return closest
end

local function foundFlyingBoneSpear()
	for _, spear in next, thrownChildren() do
		if spear.Name:match("BoneSpear") and not spear:FindFirstChild("InteractPrompt") then
			return true
		end
	end
	return false
end

---Nearest free altar across Floor1/2/3 (only advances a floor once the previous is fully filled).
local function getNearestAltar()
	local room = workspace:FindFirstChild("TrueAvatarBossRoom")
	if not room then
		return nil
	end
	local r = root()
	if not r then
		return nil
	end
	local closest = nil
	local function scan(floor)
		local allFilled = true
		if not floor then
			return allFilled
		end
		for _, altar in next, floor:GetChildren() do
			if not altar.Name:match("Altar") or altar:FindFirstChild("BoneSpear") then
				continue
			end
			allFilled = false
			local pivot = altar:GetPivot().Position
			if not closest or (r.Position - pivot).Magnitude < (r.Position - closest:GetPivot().Position).Magnitude then
				closest = altar
			end
		end
		return allFilled
	end
	if scan(room:FindFirstChild("Floor1Stuff")) then
		if scan(room:FindFirstChild("Floor2Stuff")) then
			scan(room:FindFirstChild("Floor3Stuff"))
		end
	end
	return closest
end

---Open a chest and force LOOT_ALL while its choice prompt is active.
local function grabChest(chest)
	if not cfg("L2LootChests", true) or not chest or not chest:FindFirstChild("Lid") then
		return
	end
	local previousAutoLootIgnore = AutoLoot.ignore
	AutoLoot.ignore = true
	local gui = playerGui()
	local openDeadline = os.clock() + 3
	repeat
		pcall(function()
			tempTween(chest.Lid.CFrame, 170)
		end)
		pcall(function()
			fireProx(chest:FindFirstChildWhichIsA("ProximityPrompt"))
		end)
		task.wait(0.1)
		gui = playerGui()
	until (gui and gui:FindFirstChild("ChoicePrompt")) or not running or os.clock() >= openDeadline

	local choicePrompt = gui and gui:FindFirstChild("ChoicePrompt")
	local choice = choicePrompt and choicePrompt:FindFirstChild("Choice")
	if choice and choice:IsA("RemoteEvent") then
		local lootDeadline = os.clock() + 3
		repeat
			choice:FireServer("LOOT_ALL")
			task.wait(0.1)
			gui = playerGui()
			choicePrompt = gui and gui:FindFirstChild("ChoicePrompt")
			choice = choicePrompt and choicePrompt:FindFirstChild("Choice")
		until not choicePrompt or not running or os.clock() >= lootDeadline

		if choice and choice:IsA("RemoteEvent") and choicePrompt and choicePrompt.Parent then
			choice:FireServer("EXIT")
		end
	end

	local closeDeadline = os.clock() + 3
	gui = playerGui()
	while gui and gui:FindFirstChild("ChoicePrompt") and running and os.clock() < closeDeadline do
		task.wait(0.1)
		gui = playerGui()
	end
	AutoLoot.ignore = previousAutoLootIgnore
end

local function grabNearestChest()
	local r = root()
	if not r then
		return
	end
	local closest = nil
	for _, chest in next, thrownChildren() do
		if not chest:FindFirstChild("Lid") then
			continue
		end
		if not closest or (r.Position - chest.Lid.Position).Magnitude < (r.Position - closest.Lid.Position).Magnitude then
			closest = chest
		end
	end
	if closest then
		grabChest(closest)
	end
end

local function detectBombFullyCharged()
	while running and task.wait() do
		local count = 0
		for _, p in next, thrownChildren() do
			if p.Name:lower():find("bombspec") then
				count = count + 1
			end
		end
		if count > 7 then
			return
		end
	end
end

local function detectBombFired()
	while running and task.wait() do
		local count = 0
		for _, p in next, thrownChildren() do
			if p.Name:lower():find("bombspec") then
				count = count + 1
			end
		end
		if count <= 5 then
			return
		end
	end
end

-- =========================================================================================================
-- Floor 1.
-- =========================================================================================================
local L2_BONEKEEPER = CFrame.new(-5747, 459, -6357)
local L2_BONEKEEPER_APPROACH = CFrame.new(-5889, 459, -6308)
local L2_BONEKEEPER_WATCH = CFrame.new(-5788, 563, -6351)
local L2_GENERATOR = CFrame.new(-5555, 529, -6475)
local L2_CHASER_HIGH = CFrame.new(-5361, 5000, -4801)
local L2_CHASER_DOWN = CFrame.new(-5361, 285, -4801)
local L2_CHASER_ANGLE = CFrame.new(-5224.36523, 194.26561, -4633.03223, -0.803056717, 0, -0.595902622, 0, 1, 0, 0.595902622, 0, -0.803056717)
local FROST_GRAB_NAME = "Mantra:ChokeIce{{Frost Grab}}"

local function handleDoor()
	setStage("floor 1: key / door")
	drawWeapon()
	repeat
		pcall(function()
			tempTween(workspace.NPCs:FindFirstChild("TheKey"):GetPivot(), 250)
		end)
		pcall(function()
			fireProx(workspace.NPCs.TheKey.InteractPrompt)
		end)
		task.wait(0.5)
	until dialogueOpen() or not running
	sendDialogue(nil, true)

	pcall(function()
		tempTween(workspace.NPCs:FindFirstChild("TheDoor"):GetPivot(), 250)
	end)
	repeat
		pcall(function()
			fireProx(workspace.NPCs:FindFirstChild("TheDoor").InteractPrompt)
		end)
		task.wait(0.5)
	until dialogueOpen() or not running
	sendDialogue(nil, true)
end

local function handleBonekeeper()
	setStage("floor 1: bonekeeper")
	tempTween(L2_BONEKEEPER, 250)
	setVoidMobs(true)

	local keeper, realKeeper = nil, nil
	repeat
		if not keeper then
			pcall(function()
				tempTween(L2_BONEKEEPER_APPROACH, 150)
			end)
		end
		if realKeeper and realKeeper.Parent == nil and not keeper then
			break
		end
		for _, v in next, liveChildren() do
			if v ~= character() and v.Name:find("%.boneboy") then
				realKeeper = v
				keeper = v
			end
		end
		if not keeper then
			pcall(function()
				tempTween(L2_BONEKEEPER, 150)
			end)
		end
		task.wait()
	until keeper or not running

	tempTween(L2_BONEKEEPER_WATCH, 250)
	repeat
		task.wait()
		local triggers = workspace:FindFirstChild("EncounterTriggers")
		local bridge = triggers and (triggers:FindFirstChild("BonekeeperBridge") or triggers:FindFirstChild("BoneKeeperBridge"))
		if not bridge or not bridge:FindFirstChild("Barrier") then
			break
		end
	until not running
end

local function handleGenerator()
	setStage("floor 1: generator")
	repeat
		pcall(function()
			tempTween(L2_GENERATOR, 175)
		end)
		task.wait(0.5)
		pcall(function()
			fireProx(workspace.NPCs.TheGenerator.InteractPrompt)
		end)
	until dialogueOpen() or not running
	sendDialogue("[Restart it]")
	sendDialogue(nil, true)
end

local function handleSpawnChaser()
	setStage("floor 1: finding chaser")
	tempTween(L2_CHASER_HIGH, 250)
	local chaser = nil
	repeat
		pcall(function()
			tempTween(L2_CHASER_DOWN, 250)
		end)
		task.wait()
		for _, v in next, liveChildren() do
			if v ~= character() and v.Name:find("chaser") then
				chaser = v
				break
			end
		end
		if not chaser then
			pcall(function()
				tempTween(L2_CHASER_ANGLE, 250)
			end)
		end
		task.wait()
	until chaser or not running
	return chaser
end

local function initChaserFight(chaser)
	if not chaser then
		return
	end
	setStage("floor 1: engaging chaser")
	setSpeed(250)
	while running and chaser.Parent do
		local target = chaser:GetPivot()
		Tweening.goal(MOVE_ID, target, false, true)
		local r = root()
		if r and (r.Position - target.Position).Magnitude <= 5 then
			break
		end
		task.wait()
	end
	Tweening.stop(MOVE_ID)
	repeat
		local prompt = chaser:FindFirstChild("InteractPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			Prompt.fire(prompt)
		end
		task.wait(0.5)
	until dialogueOpen() or not running
	sendDialogue("Ethiron's Wake?")
	sendDialogue("What happened here?")
	sendDialogue("They mutinied?")
	sendDialogue("The City?")
end

local function breakBloodJar(chaser, bloodJar, attackedBloodJars)
	setStage("floor 1: breaking blood jar")
	autoM1(false)

	local jarPosition = getPosition(bloodJar)
	local r = root()
	if not jarPosition or not r then
		return
	end

	while running and chaser.Parent and getBloodJar(chaser) == bloodJar do
		jarPosition = getPosition(bloodJar)
		r = root()
		if not jarPosition or not r then
			autoM1(false)
			Tweening.stop(MOVE_ID)
			task.wait(0.1)
			continue
		end

		if chaserHazardActive() then
			hideFromChaserHazards(chaser, CFrame.new(-4523, 745, -5069))
			continue
		end

		local targetPosition = jarPosition - Vector3.new(0, 8, 0)
		local verticalDelta = targetPosition.Y - r.Position.Y
		local horizontalTarget = Vector3.new(targetPosition.X, r.Position.Y, targetPosition.Z)
		local horizontalDistance = (r.Position - horizontalTarget).Magnitude
		if verticalDelta < -4 and horizontalDistance > 2.5 then
			autoM1(false)
			setSpeed(175)
			Tweening.goal(
				MOVE_ID,
				CFrame.lookAt(horizontalTarget, Vector3.new(jarPosition.X, r.Position.Y, jarPosition.Z)),
				false,
				true
			)
		elseif verticalDelta < -4 then
			autoM1(false)
			Tweening.stop(MOVE_ID)
			r.CFrame = CFrame.lookAt(targetPosition, jarPosition)
		elseif verticalDelta > 4 then
			autoM1(false)
			Tweening.stop(MOVE_ID)
			r.CFrame = CFrame.lookAt(targetPosition, jarPosition)
		elseif horizontalDistance > 2.5 then
			autoM1(false)
			setSpeed(175)
			Tweening.goal(MOVE_ID, CFrame.lookAt(targetPosition, jarPosition), false, true)
		else
			Tweening.stop(MOVE_ID)
			autoM1(false)
			local now = os.clock()
			local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
			local effectModule = effectReplicator and require(effectReplicator)
			if
				now - (attackedBloodJars[bloodJar] or 0) >= 1
				and not Defense.shouldBlockInput("M1s")
				and effectModule
				and not effectModule:HasEffect("InDialogue")
				and not effectModule:HasEffect("LightAttack")
				and not effectModule:HasEffect("CriticalAttack")
				and not effectModule:HasEffect("Followup")
				and not effectModule:HasEffect("Parried")
			then
				InputClient.left(r.CFrame, false, true)
				attackedBloodJars[bloodJar] = now
			end
		end
		task.wait(0.1)
	end

	Tweening.stop(MOVE_ID)
	autoM1(false)
end

---The chaser fight. Returns its initial location (for the chest). Ports PR's snow-cleanse, bloodjar, waves,
---chaser-down attach-to-head + frost-grab void path.
local function handleChaserFight(chaser)
	if not chaser or not chaser:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	setStage("floor 1: chaser fight")
	local initLocation = chaser.HumanoidRootPart.CFrame
	local voidingMode = cfg("L2VoidChaser", false)
	local lastFrostGrab = 0
	local retreat = CFrame.new(-4523, 745, -5069)
	local voidActive = false
	local attackedBloodJars = {}
	local chaserDownUntil = 0

	local function chaserIsDown(hrp)
		local now = os.clock()
		if hrp:FindFirstChild("REP_SOUND_10463439228") then
			chaserDownUntil = now + 2.5
		end
		return now < chaserDownUntil
	end

	if voidingMode then
		setChaserFling(false)
	end

	setStage("floor 1: retreating from chaser")
	autoM1(false)
	tempTween(retreat, 125, true)

	while running and chaser.Parent do
		local hrp = chaser:FindFirstChild("HumanoidRootPart")
		if not hrp then
			break
		end

		local chaserDown = chaserIsDown(hrp)
		local shouldVoid = voidingMode and chaserDown
		if shouldVoid ~= voidActive then
			setVoidMobs(shouldVoid)
			voidActive = shouldVoid
		end

		if chaserHazardActive() then
			hideFromChaserHazards(chaser, retreat)
			continue
		end

		local bloodJar = getBloodJar(chaser)
		if bloodJar then
			breakBloodJar(chaser, bloodJar, attackedBloodJars)
			continue
		end

		if not chaserDown then
			autoM1(false)
			local r = root()
			if r and (r.Position - retreat.Position).Magnitude > 8 then
				setStage("floor 1: waiting for chaser stun")
				tempTween(retreat, 125, true)
			else
				task.wait(0.1)
			end
			continue
		end

		while running and chaser.Parent do
			hrp = chaser:FindFirstChild("HumanoidRootPart")
			if not hrp
				or not chaserIsDown(hrp)
				or chaserHazardActive()
				or getBloodJar(chaser)
			then
				break
			end

			local attackCFrame = hrp.CFrame * CFrame.new(0, -5, 0) * CFrame.Angles(math.rad(90), 0, 0)
			local r = root()
			if r and attackCFrame.Position.Y >= 20 then
				local inAttackRange = (r.Position - attackCFrame.Position).Magnitude <= 5
				setSpeed(240)
				Tweening.goal(MOVE_ID, attackCFrame, false, true)
				autoM1WhenSafe(inAttackRange)

				if voidingMode and inAttackRange and tick() - lastFrostGrab > 5 then
					local backpack = localPlayer():FindFirstChildOfClass("Backpack")
					local frost = backpack and backpack:FindFirstChild(FROST_GRAB_NAME)
					local c = character()
					local requests = c and c:FindFirstChild("CharacterHandler")
					requests = requests and requests:FindFirstChild("Requests")
					local activate = requests and requests:FindFirstChild("ActivateMantra")
					if frost and activate then
						activate:FireServer(frost)
						lastFrostGrab = tick()
					end
				end
			else
				Tweening.stop(MOVE_ID)
				autoM1(false)
			end

			task.wait(0.1)
		end
		autoM1(false)
		Tweening.stop(MOVE_ID)
	end

	autoM1(false)
	Tweening.stop(MOVE_ID)
	autoM1(false)
	setVoidMobs(false)
	setChaserFling(true)
	return initLocation
end

local function handleChaserChest(initLocation)
	if not cfg("L2LootChests", true) or not initLocation then
		return
	end
	setStage("floor 1: chaser chest")
	local chest = nil
	repeat
		tempTween(initLocation * CFrame.new(0, 40, 0), 175)
		local r = root()
		for _, c in next, thrownChildren() do
			if c:FindFirstChild("Lid") and r and (r.Position - c.Lid.Position).Magnitude <= 400 then
				chest = c
				break
			end
		end
		task.wait()
	until chest or not running
	grabChest(chest)
end

---Trap-door puzzle skip (used when the chaser's already dead and we don't want to re-fight).
local function puzzleSkip()
	setStage("floor 1: puzzle skip")
	tempTween(CFrame.new(-5538.2334, 43.929615, -5194.18164, 0.383664161, 0, -0.923472703, 0, 1, 0, 0.923472703, 0, 0.383664161), 175)

	local floor1 = workspace:FindFirstChild("Layer2Floor1")
	if not floor1 then
		return
	end
	local one, two, three, four
	for _, pp in next, floor1:GetChildren() do
		if not pp.Name:match("PuzzlePart") or not pp:FindFirstChild("Requires") then
			continue
		end
		local req = pp.Requires.Value
		if req:match("AShape") then
			one = pp
		elseif req:match("DShape") then
			two = pp
		elseif req:match("CShape") then
			three = pp
		elseif req:match("BShape") then
			four = pp
		end
		if one and two and three and four then
			break
		end
	end
	if not (one and two and three and four) then
		return
	end

	repeat
		tempTween(CFrame.new(-5579.28174, 6.74480486, -5203.97754, 0.490061522, 0, 0.871687829, 0, 1, 0, -0.871687829, 0, 0.490061522), 175)
		pcall(firetouchinterest, root(), workspace.EncounterTriggers.TrapDoorPuzzle.Spawner, 0)
		pcall(firetouchinterest, root(), workspace.EncounterTriggers.TrapDoorPuzzle.Spawner, 1)
		task.wait(1)
		tempTween(CFrame.new(-5510.97363, 5.74480391, -5181.09619, -0.191880465, 0, -0.981418312, 0, 1, 0, 0.981418312, 0, -0.191880465), 175)
		pcall(firetouchinterest, root(), workspace.EncounterTriggers.TrapDoorPuzzle.Spawner, 0)
		pcall(firetouchinterest, root(), workspace.EncounterTriggers.TrapDoorPuzzle.Spawner, 1)
		task.wait(1)
	until one:FindFirstChild("InteractPrompt", true) or not running

	local function pressPuzzle(part, times)
		tempTween(part:GetPivot() * CFrame.new(0, 4, 0), 175)
		for _ = 1, times do
			repeat
				pcall(function()
					fireProx(part:FindFirstChild("InteractPrompt", true))
				end)
				task.wait()
			until part:FindFirstChild("Shifting", true) or not running
			repeat
				task.wait()
			until not part:FindFirstChild("Shifting", true) or not running
		end
	end
	pressPuzzle(one, 2)
	pressPuzzle(two, 1)
	pressPuzzle(three, 3)
	pressPuzzle(four, 4)

	tempTween(workspace.Layer2Floor1.WindPortal.CFrame, 175)
	for _ = 1, 2 do
		pcall(firetouchinterest, root(), workspace.Layer2Floor1.WindPortal, 0)
		pcall(firetouchinterest, root(), workspace.Layer2Floor1.WindPortal, 1)
	end
end

local function leaveFloorOne()
	if cfg("L2KillEthiron", false) then
		local second = workspace:FindFirstChild("SecondStage")
		if second then
			tempTween(second:IsA("BasePart") and second.CFrame or second:GetPivot(), 175)
		else
			Logger.notify("Auto L2: Floor 2 entrance not found.")
		end
		return
	end

	local hook = workspace:FindFirstChild("InGameLightHook")
	if hook then
		tempTween(hook.CFrame, 175)
		for _ = 1, 2 do
			pcall(firetouchinterest, root(), hook, 0)
			pcall(firetouchinterest, root(), hook, 1)
		end
	else
		Logger.notify("Auto L2: light hook not found after Chaser chest.")
	end
end

local function floorOne()
	local data = PersistentData.get("l2data")
	if data and data.killedChaser then
		-- A floor transition can take more than one state-machine pass. Resume the exit route
		-- instead of replaying the key/door sequence after the Chaser is already cleared.
		if not cfg("L2KillChaser", true) then
			puzzleSkip()
		else
			leaveFloorOne()
		end
		return
	end

	handleDoor()
	handleBonekeeper()
	handleGenerator()
	setVoidMobs(false)

	local chaser = handleSpawnChaser()
	initChaserFight(chaser)
	if not running or not chaser then
		return
	end

	local initLocation = handleChaserFight(chaser)
	handleChaserChest(initLocation)
	if not running then
		return
	end

	PersistentData.stf("l2data", "killedChaser", true)
	leaveFloorOne()
end

-- =========================================================================================================
-- Floor 2 (Ethiron).
-- =========================================================================================================
local function handleObelisks()
	setStage("floor 2: obelisks")
	repeat
		local obelisk = getNearest(collectionService:GetTagged("BuzzObelisk"), function(o)
			return o.Name:match("Buzz") ~= nil
		end)
		if obelisk then
			tempTween(obelisk.CFrame, 175)
			pcall(function()
				fireProx(obelisk.InteractPrompt)
			end)
		end
		task.wait()
	until #collectionService:GetTagged("BuzzObelisk") == 0 or not running
end

local function handleKrysanChests()
	if not cfg("L2LootChests", true) then
		return
	end

	setStage("floor 2: kyrsan chests")
	local gui = playerGui()
	local currency = gui and gui:FindFirstChild("CurrencyGui")
	local medallions = currency and currency.CurrencyFrame:FindFirstChild("KyrsanMedallions")
	local amount = medallions and medallions:FindFirstChild("Amount")
	if amount and amount.Text == "250" then
		return
	end

	local chests = {}
	for _, chest in next, thrownChildren() do
		if chest:FindFirstChild("Lid") then
			table.insert(chests, chest)
		end
	end
	while running and #chests > 0 do
		local r = root()
		local closest, idx = nil, nil
		for i, chest in ipairs(chests) do
			if not chest.Parent or not chest:FindFirstChild("Lid") then
				continue
			end
			if not closest or (r.Position - chest.Lid.Position).Magnitude < (r.Position - closest.Lid.Position).Magnitude then
				closest, idx = chest, i
			end
		end
		if not closest then
			break
		end
		tempTween(closest.Lid.CFrame, 175)
		grabChest(closest)
		table.remove(chests, idx)
		task.wait()
	end
end

local function handleEthironSpawn()
	setStage("floor 2: summon ethiron")
	tempTween(CFrame.new(787.787598, 1311.22559, 7324.95801), 175)
	pcall(function()
		tempTween(workspace.NPCs.EthironSummonPodium:GetPivot(), 175)
	end)
	repeat
		pcall(function()
			fireProx(workspace.NPCs.EthironSummonPodium.InteractPrompt)
		end)
		task.wait(0.5)
	until dialogueOpen() or not running
	sendDialogue("[Resist it]")
	sendDialogue("[Resist further]")
	sendDialogue("[Resist with all that you are]")
	sendDialogue("[Breathe out]")
end

local function handleEthironFight()
	setStage("floor 2: ethiron gauntlet")
	local ultimateDetected = false
	local boneTweenActive = false
	local ethironStunned = false

	maid:mark(workspace.DescendantAdded:Connect(function(descendant)
		if not running then
			return
		end
		if descendant.Name:lower():find("bombcharge") then
			if not avatarExists() then
				return
			end
			ultimateDetected = true
			while boneTweenActive do
				task.wait()
			end
			tempTween(CFrame.new(787.787598, 1380, 7324.95801), 175)
			detectBombFullyCharged()
			detectBombFired()
			tempTween(CFrame.new(774.600281, 2000, 7465.85791), 175)
			ultimateDetected = false
		end
	end))

	local avatar = nil
	repeat
		for _, v in next, liveChildren() do
			if v.Name:find("%.avatar") then
				avatar = v
				break
			end
		end
		task.wait()
	until avatar or not running
	if not avatar then
		return
	end

	local initHeadCF = nil
	repeat
		pcall(function()
			initHeadCF = avatar:FindFirstChild("Head").CFrame
		end)
		task.wait()
	until initHeadCF or not running

	pcall(function()
		avatar.Humanoid.Animator.AnimationPlayed:Connect(function(anim)
			if anim.Animation.AnimationId:match("rbxassetid://10880826811") then
				ethironStunned = true
			elseif anim.Animation.AnimationId:match("rbxassetid://10978735338") then
				ethironStunned = false
			end
		end)
	end)

	local function hp()
		local h = humanoid()
		return h and h.Health or 0, h and h.MaxHealth or 1
	end

	repeat
		xpcall(function()
			repeat
				local bonespear = getNearestBoneSpear()
				local bonealtar = getNearestAltar()
				local health, maxHealth = hp()

				if health <= maxHealth * 0.25 then
					repeat
						if not ultimateDetected then
							tempTween(CFrame.new(774.600281, 1380, 7465.85791), 175)
						end
						task.wait()
						health = hp()
					until health >= maxHealth * 0.25 or not running
				elseif ultimateDetected then
					task.wait()
				elseif (bonespear and bonealtar and not foundFlyingBoneSpear())
					or (bonealtar and character():FindFirstChild("BoneSpear")) then
					-- Grab a spear.
					if not ultimateDetected and not character():FindFirstChild("BoneSpear") and hp() > maxHealth * 0.40 then
						boneTweenActive = true
						repeat
							pcall(function()
								tempTween(bonespear.CFrame, 175)
							end)
							pcall(function()
								fireProx(bonespear.InteractPrompt)
							end)
							task.wait()
						until bonespear == nil or bonespear.Parent == nil or character():FindFirstChild("BoneSpear") or ultimateDetected or hp() <= maxHealth * 0.40 or not running
					end
					-- Plant it on an altar.
					if not ultimateDetected and character():FindFirstChild("BoneSpear") and hp() > maxHealth * 0.40 then
						boneTweenActive = true
						repeat
							pcall(function()
								tempTween(bonealtar:GetPivot(), 175)
							end)
							pcall(function()
								fireProx(bonealtar.InteractPrompt)
							end)
							task.wait()
						until not character():FindFirstChild("BoneSpear") or ultimateDetected or hp() <= maxHealth * 0.40 or not running
					end
					boneTweenActive = false
				elseif ethironStunned and not foundFlyingBoneSpear() then
					repeat
						boneTweenActive = true
						tempTween(avatar.Head.CFrame * CFrame.new(0, -5, 0), 175)
						boneTweenActive = false
						autoM1(true)
						task.wait()
					until not ethironStunned or hp() <= maxHealth * 0.40 or not running
					autoM1(false)
				else
					boneTweenActive = true
					tempTween(initHeadCF * CFrame.new(0, 150, 0), 175)
					boneTweenActive = false
				end
				task.wait()
			until avatar.Parent == nil or not running
		end, function(err)
			Logger.notify("Auto L2 ethiron error: %s", tostring(err))
		end)
		task.wait()
	until avatar.Parent == nil or not running
	autoM1(false)
end

local function handleEthironChest()
	if not cfg("L2LootChests", true) then
		return
	end

	setStage("floor 2: ethiron chest")
	tempTween(CFrame.new(791.660889, 563.343811, 7120.29248), 175)
	grabNearestChest()
end

local function floorTwo()
	drawWeapon()
	handleObelisks()
	handleKrysanChests()
	handleEthironSpawn()
	handleEthironFight()
	handleEthironChest()

	-- Light-hook escape.
	tempTween(CFrame.new(944.20166, 850.517029, 4173.19775), 175)
	local hook = workspace:FindFirstChild("InGameLightHook")
	if hook then
		for _ = 1, 2 do
			pcall(firetouchinterest, root(), hook, 0)
			pcall(firetouchinterest, root(), hook, 1)
		end
	end
end

-- =========================================================================================================
-- Void dive into Layer 2.
-- =========================================================================================================
local function nearestKillPlane()
	local r = root()
	if not r then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, item in ipairs(collectionService:GetTagged("KillPlane")) do
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
	local d = dungeon()
	if d and tostring(d):match("Layer2") then
		return true
	end
	local a = currentArea()
	return a ~= nil and tostring(a):match("Layer2") ~= nil
end

---Dive into the void to enter Layer 2 (PR go_to_layer_two). Drops kill-brick immunity + fly so we fall.
local function goToLayerTwo()
	setStage("diving into layer 2")
	disableStructFeature("no_kill_bricks")

	local hum = humanoid()
	if hum and hum.Health <= hum.MaxHealth / 2 then
		-- PR kicks here; we just hop to a fresh server + retry instead of booting the user.
		return serverHop()
	end

	if currentArea() and tostring(currentArea()):match("Fragments of Self") then
		-- We got wiped -- stop cleanly rather than loop.
		AutoLayer2.stop()
		return
	end

	disableStructFeature("fly")

	local startedAt = tick()
	local plane = nearestKillPlane()
	repeat
		plane = nearestKillPlane()
		task.wait()
	until plane or tick() - startedAt > 15 or not running or inLayer2()

	maid:mark(task.spawn(function()
		while running do
			if playerCheck(PLAYER_SAFE_RADIUS) then
				serverHop()
				return
			end
			task.wait()
		end
	end))

	while running and tick() - startedAt < 60 do
		if inLayer2() then
			break
		end
		if not plane then
			plane = nearestKillPlane()
		end
		if plane and plane.Parent then
			setSpeed(200)
			Tweening.goal(MOVE_ID, plane.CFrame, false)
		end
		local r = root()
		if r then
			r.AssemblyLinearVelocity = Vector3.new(0, -999, 0)
		end
		task.wait()
	end
	Tweening.stop(MOVE_ID)
end

-- =========================================================================================================
-- State machine.
-- =========================================================================================================
local stateMachine = StateMachine.create({
	initial = "idle",
	events = {
		{ name = "start", from = "idle", to = "_check_area" },
		{ name = "dive", from = "_check_area", to = "_to_layer_two_floor_one" },
		{ name = "floorone", from = "_check_area", to = "_floor_one" },
		{ name = "floortwo", from = "_check_area", to = "_floor_two" },
		{ name = "continuation", from = "_floor_one", to = "_check_area" },
		{ name = "continuation", from = "_floor_two", to = "_check_area" },
	},
	callbacks = {
		onenter_check_area = function(self)
			if not running then
				return
			end
			setStage("check area")

			local deadline = os.clock() + 25
			repeat
				local d = dungeon()
				if d and tostring(d):match("Layer2Floor1") then
					return self:floorone()
				end
				if d and tostring(d):match("Layer2Floor2") then
					return self:floortwo()
				end
				local area = currentArea()
				if area and tostring(area):match("Fragments of Self") then
					-- Wiped out of a run; stop.
					AutoLayer2.stop()
					return
				end
				if area or game.PlaceId == DEPTHS_PLACE_ID or game.PlaceId == EASTERN_PLACE_ID then
					return self:dive()
				end
				task.wait()
			until os.clock() >= deadline or not running
		end,

		onenter_to_layer_two_floor_one = function(self)
			if not running then
				return
			end
			-- First entry always dives in. On a loop re-entry (already cleared once) only continue if the
			-- user wants loops; otherwise finish cleanly.
			local data = PersistentData.get("l2data")
			if data and data.clearedOnce and not cfg("L2AllowLoops", false) then
				Logger.notify("Auto L2: run finished (loops off).")
				AutoLayer2.stop()
				return
			end
			goToLayerTwo()
			self:continuation()
		end,

		onenter_floor_one = function(self)
			if not running then
				return
			end
			floorOne()
			if not running then
				return
			end
			PersistentData.stf("l2data", "clearedOnce", true)
			self:continuation()
		end,

		onenter_floor_two = function(self)
			if not running then
				return
			end
			floorTwo()
			PersistentData.stf("l2data", "clearedOnce", true)
			self:continuation()
		end,
	},
})

-- =========================================================================================================
-- Struct.
-- =========================================================================================================
local function buildStruct()
	return AutomationStruct.construct({
		id = "auto_layer2",
		state_machine = stateMachine,
		is_running = isRunning,
		features = {
			"no_fall",
			"noclip",
			"no_kill_bricks",
			"mod_detector",
			"fly",
			"m1_hold",
			"auto_equip_weapon",
		},
		character_creator_handler_used = false,
	})
end

-- =========================================================================================================
-- Public interface.
-- =========================================================================================================
function AutoLayer2.start()
	local lp = localPlayer()
	if not lp or running then
		return
	end

	if not PersistentData.get("l2data") then
		PersistentData.set("l2data", { active = true })
	end

	running = true
	startedAt = os.time()
	lastChaserSpikeAt = 0
	lastChaserBloodwaveAt = 0
	maid:mark(workspace.DescendantAdded:Connect(trackChaserSpikeSignal))
	for _, descendant in next, workspace:GetDescendants() do
		trackChaserSpikeSignal(descendant)
	end
	buildOverlay()
	AntiAFK.start("AutoLayer2")
	maid:mark(task.spawn(runElapsed))

	stateMachine.current = "idle"
	stateMachine.asyncState = StateMachine.NONE
	stateMachine.currentTransitioningEvent = nil

	struct = buildStruct()
	struct:run()
end

function AutoLayer2.stop()
	if not running then
		return
	end
	running = false

	if struct then
		pcall(function()
			struct:stop()
		end)
		struct = nil
	end

	Tweening.stop(MOVE_ID)
	setVoidMobs(false)
	setChaserFling(true)
	pcall(function()
		AntiAFK.stop("AutoLayer2")
	end)

	maid:clean()
	destroyOverlay()
	PersistentData.set("l2data", nil)
	Logger.notify("Auto L2: stopped.")
end

---@return boolean
function AutoLayer2.isRunning()
	return running
end

return AutoLayer2
