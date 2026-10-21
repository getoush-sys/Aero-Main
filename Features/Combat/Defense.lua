---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Features.Combat.Objects.AnimatorDefender
local AnimatorDefender = require("Features/Combat/Objects/AnimatorDefender")

---@module Features.Combat.Objects.PartDefender
local PartDefender = require("Features/Combat/Objects/PartDefender")

---@module Features.Combat.Objects.SoundDefender
local SoundDefender = require("Features/Combat/Objects/SoundDefender")

---@module Features.Combat.Objects.EffectDefender
local EffectDefender = require("Features/Combat/Objects/EffectDefender")

---@module Features.Combat.Objects.Defender
local Defender = require("Features/Combat/Objects/Defender")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Features.Combat.StateListener
local StateListener = require("Features/Combat/StateListener")

---@module Game.EffectDispatcher
-- Reused purely for EffectDispatcher.defer -- the script's shared off-hook-callstack Heartbeat reaction pump.
local EffectDispatcher = require("Game/EffectDispatcher")

---@module Utility.Finder
local Finder = require("Utility/Finder")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Game.Objects.DodgeOptions
local DodgeOptions = require("Game/Objects/DodgeOptions")

---@module Features.Combat.EntityHistory
local EntityHistory = require("Features/Combat/EntityHistory")

---@module Utility.TaskSpawner
local TaskSpawner = require("Utility/TaskSpawner")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Game.Latency
local Latency = require("Game/Latency")

---@module Game.PlayerScanning
local PlayerScanning = require("Game/PlayerScanning")

---@module Features.Combat.Targeting
local Targeting = require("Features/Combat/Targeting")

local HitboxOptions = require("Features/Combat/Objects/HitboxOptions")

local Defense = { lastMantraActivate = nil }

local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local textChatService = game:GetService("TextChatService")
local localPlayer = players.LocalPlayer

local defenseMaid = Maid.new()

local defenderPartObjects = {}
local defenderAnimationObjects = {}
local defenderObjects = {}

local deletedPlaybackData = {}

local mobAnimations = {}

local WISP_INPUT_MAP = { Z = 1, X = 2, C = 3, V = 4 }
local cws = nil
local cwp = nil

local BLOCK_INPUT_TARGETING_KEYS = {
	fov = "BlockInputFOVLimit",
	distance = "BlockInputDistanceLimit",
	maxTargets = "BlockInputMaxTargets",
	selectionType = "BlockInputSelectionType",
}

local leftClickState = false
local lastEasyFeint = 0
local blockInputActive = {}
local autoWispLocked = false
local backstabMovestackReady = false
local backstabAnimationTriggerTimestamp = 0.0
local lastAutoMixupAt = 0.0
local rollBehindActive = false
local lastMantraActivatedTool = nil
local lastMantraActivatedAt = 0.0

local BACKSTAB_TRIGGER_ANIMATION_ID = "rbxassetid://139745984749680"
local BACKSTAB_TRIGGER_ANIMATION_NUMERIC_ID = "139745984749680"

local lastVisualizationUpdate = os.clock()
local lastGoldenTongueUpdate = os.clock()
local lastHistoryUpdate = os.clock()
local lastAutoArdourUpdate = os.clock()
local EFFECT_DEFENDER_LIFETIME = 30.0
local lastAutoAirCounterUpdate = os.clock()
local lastAutoWispShift = nil
local lastAutoWispUpdate = nil

---@param animator Animator
local addAnimatorDefender = LPH_NO_VIRTUALIZE(function(animator)
	local animationDefender = AnimatorDefender.new(animator, mobAnimations)
	defenderObjects[animator] = animationDefender
	defenderAnimationObjects[animator] = animationDefender
end)

---@param sound Sound
local addSoundDefender = LPH_NO_VIRTUALIZE(function(sound)
	---@note: If there's nothing to base the sound position off of, then I'm just gonna skip it bruh.
	local part = sound:FindFirstAncestorWhichIsA("BasePart")
	if not part then
		return
	end

	defenderObjects[sound] = SoundDefender.new(sound, part)
end)

---@note: Fires for every instance added anywhere in the DataModel, so it can catch things
---@param descendant Instance
local handleGameDescendant = LPH_NO_VIRTUALIZE(function(descendant)
	if descendant:IsA("BasePart") then
		return Defense.cdpo(descendant)
	end

	if descendant:IsA("Sound") then
		return addSoundDefender(descendant)
	end

	-- Animators are NOT tracked here anymore. This fires for EVERY Animator in the whole DataModel (UI,
	-- viewport, accessory and other players' cosmetic animators included -- thousands), and each one fired
	-- AnimationPlayed -> process -> a yielding evaluation fiber on its idle loops. That unbounded eval-fiber
	-- rate is the "failed to spawn a fiber" (RSL - panic: ...Kernel) crash. Animators are now tracked one per
	-- entity off workspace.Live instead (see trackLiveEntity), exactly like Project Rain's animator handler.
end)

local onGameDescendantAdded = LPH_NO_VIRTUALIZE(function(descendant)
	pcall(handleGameDescendant, descendant)
end)

---@param descendant Instance
local onGameDescendantRemoved = LPH_NO_VIRTUALIZE(function(descendant)
	local object = defenderObjects[descendant]
	if not object then
		return
	end

	if object.rpbdata then
		deletedPlaybackData[descendant] = object.rpbdata
	end

	if defenderPartObjects[descendant] then
		defenderPartObjects[descendant] = nil
	end

	if defenderAnimationObjects[descendant] then
		defenderAnimationObjects[descendant] = nil
	end

	object:detach()
	defenderObjects[descendant] = nil
end)

-- PR-style per-entity animator tracking. `trackedEntities` maps a live entity -> its Animator (or `true`
-- while the Animator is still being resolved, which claims the slot synchronously so a racing ChildAdded +
-- the initial scan can't double-track the same entity). Only models under workspace.Live get an
-- AnimatorDefender, so the number of parry trackers is bounded by the live combat entities (tens) instead of
-- every Animator in the DataModel (thousands) -- that unbounded count was the fiber-exhaustion crash.
local trackedEntities = {}

---@param entity Instance
local untrackLiveEntity = LPH_NO_VIRTUALIZE(function(entity)
	local animator = trackedEntities[entity]
	if not animator then
		return
	end

	trackedEntities[entity] = nil

	-- `true` is only the "resolving" placeholder -- just a real Animator has a defender to tear down.
	if typeof(animator) == "Instance" then
		onGameDescendantRemoved(animator)
	end
end)

---@param entity Instance
local trackLiveEntity = LPH_NO_VIRTUALIZE(function(entity)
	if not entity:IsA("Model") or trackedEntities[entity] then
		return
	end

	-- Claim the slot synchronously (before the yield below) so a racing ChildAdded / initial-scan pass can't
	-- spin up a second AnimatorDefender for the same entity.
	trackedEntities[entity] = true

	task.spawn(function()
		-- The Animator is usually parented a frame or two after the entity enters Live, so wait briefly.
		local animator = entity:FindFirstChildWhichIsA("Animator", true)
		if not animator then
			local deadline = os.clock() + 5
			repeat
				task.wait()
				animator = entity:FindFirstChildWhichIsA("Animator", true)
			until animator or os.clock() >= deadline or not entity.Parent
		end

		-- Bail if it never showed, the entity already left, or it was untracked while we waited.
		if not animator or not entity.Parent or trackedEntities[entity] ~= true then
			if trackedEntities[entity] == true then
				trackedEntities[entity] = nil
			end
			return
		end

		trackedEntities[entity] = animator
		addAnimatorDefender(animator)
	end)
end)

---@param name string?
---@param data table?
local onClientEffectEvent = LPH_NO_VIRTUALIZE(function(name, data)
	if not name then
		return
	end

	if not data or typeof(data) ~= "table" then
		data = {}
	end



	local effectDefender = EffectDefender.new(name, data)
	if not effectDefender.timing then
		return effectDefender:detach()
	end

	defenderObjects[data] = effectDefender

	task.delay(EFFECT_DEFENDER_LIFETIME, function()
		if defenderObjects[data] ~= effectDefender then
			return
		end

		defenderObjects[data] = nil
		effectDefender:detach()
	end)
end)

local updateHistory = LPH_NO_VIRTUALIZE(function()
	if os.clock() - lastHistoryUpdate <= 0.1 then
		return
	end

	lastHistoryUpdate = os.clock()

	local character = players.LocalPlayer.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	EntityHistory.add(players.LocalPlayer, humanoidRootPart.CFrame, humanoidRootPart.AssemblyLinearVelocity, tick())

	for _, player in next, players:GetPlayers() do
		if player == players.LocalPlayer then
			continue
		end

		local pcharacter = player.Character
		if not pcharacter then
			continue
		end

		local proot = pcharacter:FindFirstChild("HumanoidRootPart")
		if not proot then
			continue
		end

		EntityHistory.add(pcharacter, proot.CFrame, proot.AssemblyLinearVelocity, tick())
	end
end)

local updateGoldenTongue = LPH_NO_VIRTUALIZE(function()
	if os.clock() - lastGoldenTongueUpdate <= 1.0 then
		return
	end

	lastGoldenTongueUpdate = os.clock()

	if not Configuration.expectToggleValue("AutoGoldenTongue") then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	local passives = effectReplicatorModule.Passives
	if not passives or passives["Golden Tongue"] == nil then
		return
	end

	if effectReplicatorModule:FindEffect("GoldCool") then
		return
	end

	if Configuration.expectToggleValue("CheckIfInCombat") and not effectReplicatorModule:FindEffect("Danger") then
		return
	end

	local textChannels = textChatService:FindFirstChild("TextChannels")
	local rbxSystem = textChannels and textChannels:FindFirstChild("RBXSystem")
	if not rbxSystem then
		return
	end

	defenseMaid:mark(TaskSpawner.spawn("Defender_GoldenTongueSendAsync", rbxSystem.SendAsync, rbxSystem, "/e"))
end)

local updateAutoArdour = LPH_NO_VIRTUALIZE(function()
	if os.clock() - lastAutoArdourUpdate <= 1.0 then
		return
	end
	lastAutoArdourUpdate = os.clock()

	if not Configuration.expectToggleValue("AutoArdour") then
		return
	end

	local localPlayer = players.LocalPlayer
	if not localPlayer then
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local effectReplicatorModule = effectReplicator and require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	local passives = effectReplicatorModule.Passives
	if not passives or passives["Murmur: Ardour"] == nil then
		return
	end

	local thrown = workspace:FindFirstChild("Thrown")
	local attach = thrown and thrown:FindFirstChild("Attach_" .. character.Name)
	local handWeapon = attach and attach:FindFirstChild("HandWeapon")
	if not handWeapon then
		return
	end

	if handWeapon:FindFirstChild("ArdourHum") then
		return
	end

	local characterHandler = character:FindFirstChild("CharacterHandler")
	local requests = characterHandler and characterHandler:FindFirstChild("Requests")
	local ardourRemote = requests and requests:FindFirstChild("Ardour")

	if ardourRemote then
		pcall(function()
			ardourRemote:FireServer()
		end)
	end
end)

local function isMantraAllowed(mantra, optionKey)
	local selectedMantras = Configuration.expectOptionValue(optionKey)
	if type(selectedMantras) ~= "table" then
		return true
	end

	local isEmpty = true
	for _, v in pairs(selectedMantras) do
		if v then
			isEmpty = false
			break
		end
	end

	if isEmpty then
		return false
	end

	local defaultName = mantra and mantra.GetAttribute and mantra:GetAttribute("DefaultName")
	if not defaultName then
		return false
	end

	return selectedMantras[defaultName] == true
end

---@param optionName string
---@param randomize boolean? If true, pick a random off-cooldown mantra instead of the first in order.
local function getSelectedMantraTool(optionName, randomize)
	local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
	if not backpack then
		return nil
	end

	local selectedMantras = Configuration.expectOptionValue(optionName)
	if type(selectedMantras) ~= "table" then
		return nil
	end

	-- Selected mantra names (the multi-dropdown stores a { [name] = true } set); ignore any that
	-- were toggled off, and sort so "the next mantra" is a stable, predictable fallback order.
	local names = {}
	for name, selected in next, selectedMantras do
		if selected then
			names[#names + 1] = name
		end
	end

	if #names == 0 then
		return nil
	end

	table.sort(names)

	-- DefaultNames of every mantra currently on cooldown (a ToolLockCD effect whose Value names the tool).
	local onCooldown = {}
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local effectReplicatorModule = effectReplicator and require(effectReplicator)

	if effectReplicatorModule and effectReplicatorModule.GetEffects then
		for _, effect in pairs(effectReplicatorModule:GetEffects()) do
			if type(effect) ~= "table" then
				continue
			end

			local class = effect.Class or (effect.index and effect.index.Class)
			local value = effect.Value or (effect.index and effect.index.Value)

			if class == "ToolLockCD" and value then
				local tool = backpack:FindFirstChild(tostring(value))
				local defaultName = tool and tool:GetAttribute("DefaultName")
				if defaultName then
					onCooldown[defaultName] = true
				end
			end
		end
	end

	---Find the backpack Tool for a mantra DefaultName.
	local function toolFor(name)
		for _, tool in pairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("DefaultName") == name then
				return tool
			end
		end
		return nil
	end

	if randomize then
		-- Collect every selected mantra that exists and is off cooldown, then pick one at random.
		local available = {}
		for _, name in ipairs(names) do
			if not onCooldown[name] then
				local tool = toolFor(name)
				if tool then
					available[#available + 1] = tool
				end
			end
		end

		if #available == 0 then
			return nil
		end

		return available[math.random(1, #available)]
	end

	-- Walk the selection in order and return the first mantra that exists and is off cooldown,
	-- skipping straight past any that are still cooling down.
	for _, name in ipairs(names) do
		if not onCooldown[name] then
			local tool = toolFor(name)
			if tool then
				return tool
			end
		end
	end

	return nil
end

local function tryActivateBackstabMovestack()
	if not Configuration.expectToggleValue("BackstabMovestack") then
		return false
	end

	local tool = getSelectedMantraTool("BackstabMovestackMantras")
	if not tool then
		return false
	end

	local localPlayer = game:GetService("Players").LocalPlayer
	local character = localPlayer and localPlayer.Character
	local characterHandler = character and character:FindFirstChild("CharacterHandler")
	local requests = characterHandler and characterHandler:FindFirstChild("Requests")
	local activateMantra = requests and requests:FindFirstChild("ActivateMantra")

	if activateMantra then
		activateMantra:FireServer(tool)
		return true
	end

	return false
end

-- ---- Auto Mixup: Roll Cancel Behind Back ----
-- Nearest living, non-ally enemy's root part within range (self-contained, no aimbot config needed).
local function getNearestEnemyRoot()
	local character = localPlayer and localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local live = workspace:FindFirstChild("Live")
	if not live then
		return nil
	end

	local best, bestDistance = nil, math.huge
	for _, entity in next, live:GetChildren() do
		if entity == character then
			continue
		end

		local humanoid = entity:FindFirstChildWhichIsA("Humanoid")
		local entityRoot = entity:FindFirstChild("HumanoidRootPart")
		if not humanoid or not entityRoot or humanoid.Health <= 0 then
			continue
		end

		local player = players:GetPlayerFromCharacter(entity)
		if player and PlayerScanning.isAlly(player) then
			continue
		end

		-- Optionally restrict roll-behind to real players (skip NPCs/mobs).
		if Configuration.expectToggleValue("AutoMixupRollBehindPlayersOnly") and not player then
			continue
		end

		local distance = (entityRoot.Position - root.Position).Magnitude
		if distance <= 60 and distance < bestDistance then
			best = entityRoot
			bestDistance = distance
		end
	end

	return best
end

-- Roll -> lock onto the opponent through the roll -> roll cancel -> m1 again (the Easy Roll Cancel path).
local performRollCancelBehindBack = LPH_NO_VIRTUALIZE(function(targetRoot)
	-- Dodge gate over the whole sequence: if we can't dodge right now, do nothing -- no roll, no
	-- roll cancel, no m1 -- rather than feinting and m1ing on a roll that never happened.
	if not StateListener.cdodge() then
		return
	end

	-- Re-entry guard: this routine holds a ~0.5s camera lock (Heartbeat:Wait loops below), and it has two
	-- drivers -- the m1 remote-hook mixup path and the Roll Parry alias (Defense.rollCancelBehindBack). If a
	-- second call enters while the first is still mid-lock, both BindToRenderStep the SAME name with a fresh
	-- closure, so they stack (2-3 deep) and Roblox warns "removed different functions with same reference name
	-- AutoMixup_RollBehindLockOn N times" every unbind -- the churn that saturated the crash log. One at a time.
	if rollBehindActive then
		return
	end

	-- Suppress Easy Roll Cancel / Easy Mantra Feint for the duration so they don't stack their own
	-- feint + m1 on top of this sequence's roll cancel.
	rollBehindActive = true

	local intensity = math.clamp((Configuration.expectOptionValue("AutoMixupRollBehindLockOnIntensity") or 50) / 100, 0.0, 1.0)

	-- How long before the roll cancel, and how long the camera stays locked on overall.
	local ROLL_CANCEL_DELAY = 0.18
	local LOCK_ON_DURATION = 0.5

	-- Roll -- same rolling logic as the auto-defense roll (honors the Blatant Roll setting). We do
	-- the cancel ourselves below (Easy Roll Cancel path), so leave the dodge's own rollCancel off.
	local rollOptions = DodgeOptions.new()
	rollOptions.direct = Configuration.expectToggleValue("BlatantRoll")
	InputClient.dodge(rollOptions)

	-- Lock onto the opponent with the CAMERA. Bound just above the camera render step so our aim is
	-- the last write each frame. Lock On Intensity = lerp strength.
	local bindName = "AutoMixup_RollBehindLockOn"
	-- Always clear any prior bind under this name before re-binding, so a run that errored out of its wait
	-- loop before reaching the unbind below can never leave a stale closure stacked under the same name.
	pcall(runService.UnbindFromRenderStep, runService, bindName)
	if intensity > 0 then
		pcall(function()
			runService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function()
				local camera = workspace.CurrentCamera
				if camera and targetRoot and targetRoot.Parent then
					camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camera.CFrame.Position, targetRoot.Position), intensity)
				end
			end)
		end)
	end

	local lockStart = os.clock()

	-- Short window before the roll cancel.
	while os.clock() - lockStart < ROLL_CANCEL_DELAY do
		runService.Heartbeat:Wait()
	end

	-- Roll cancel + m1 again (Easy Roll Cancel path), aimed via the camera (mouse hit).
	local character = localPlayer and localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		-- Only feint if we're actually still mid-roll (Dodge / ClientDodge effect); otherwise a stray
		-- feint would get buffered onto the m1 below and feint it.
		local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
		local effectReplicatorModule = effectReplicator and require(effectReplicator)
		if effectReplicatorModule and (effectReplicatorModule:HasEffect("Dodge") or effectReplicatorModule:HasEffect("ClientDodge")) then
			InputClient.feint()
			task.wait()
		end

		local mouse = localPlayer and localPlayer:GetMouse()
		local aim = (mouse and mouse.Hit) or root.CFrame
		InputClient.left(aim, true)
	end

	-- Hold the camera lock for the rest of the set lock-on duration, then release it.
	while os.clock() - lockStart < LOCK_ON_DURATION do
		runService.Heartbeat:Wait()
	end

	pcall(function()
		runService:UnbindFromRenderStep(bindName)
	end)

	rollBehindActive = false
end)

-- Public alias so other modules (e.g. the Roll Parry defense option) can run the roll-behind ->
-- roll cancel -> m1 sequence against a given target root.
Defense.rollCancelBehindBack = performRollCancelBehindBack

-- Called from the m1 remote hook. Rolls each enabled Auto Mixup action's probability, then picks
-- ONE of the actions that hit at random -- no fixed priority order. Returns true to BLOCK the
-- manual m1 (roll-cancel-behind-back takes over), false to let it fire (a feint / feint-into-mantra
-- rides on the m1 that goes out).
Defense.tryAutoMixup = LPH_NO_VIRTUALIZE(function()
	if not Configuration.expectToggleValue("AutoMixup") then
		return false
	end

	if os.clock() - lastAutoMixupAt < 0.2 then
		return false
	end

	if not (localPlayer and localPlayer.Character) then
		return false
	end

	-- Only mix up while the weapon is actually drawn. "Equipped" is the drawn-weapon effect (same one
	-- weapon-draw detection keys off). Sheathed / no weapon out -> leave the manual m1 alone.
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local effectReplicatorModule = effectReplicator and require(effectReplicator)
	if not (effectReplicatorModule and effectReplicatorModule:HasEffect("Equipped")) then
		return false
	end

	-- Build the pool of actions that rolled this m1. Each is gated by its own feasibility check so
	-- we never queue something the player can't actually do.
	local candidates = {}
	local mantraTool = nil
	local enemyRoot = nil

	local feintChance = Configuration.expectOptionValue("AutoMixupFeintProbability") or 0.0
	if feintChance > 0 and Random.new():NextNumber(1.0, 100.0) <= feintChance and StateListener.cfeint() then
		candidates[#candidates + 1] = "feint"
	end

	local mantraChance = Configuration.expectOptionValue("AutoMixupFeintIntoMantraProbability") or 0.0
	if mantraChance > 0 and Random.new():NextNumber(1.0, 100.0) <= mantraChance then
		mantraTool = getSelectedMantraTool("AutoMixupMantras", true)
		if mantraTool then
			candidates[#candidates + 1] = "mantra"
		end
	end

	local rollChance = Configuration.expectOptionValue("AutoMixupRollBehindProbability") or 0.0
	-- Never roll-cancel-behind if the player can't dodge right now (NoRoll cooldown / stun / blocked).
	if rollChance > 0 and Random.new():NextNumber(1.0, 100.0) <= rollChance and StateListener.cdodge() then
		enemyRoot = getNearestEnemyRoot()
		if enemyRoot then
			candidates[#candidates + 1] = "rollbehind"
		end
	end

	if #candidates == 0 then
		return false
	end

	local choice = candidates[Random.new():NextInteger(1, #candidates)]
	lastAutoMixupAt = os.clock()

	if choice == "rollbehind" then
		-- Off the UnreliableFireServer hook callstack: enqueue to the shared Heartbeat pump (a table insert, no
		-- scheduler touch) and still return true synchronously so the manual m1 is swallowed now. Was task.defer,
		-- which registered a thread from inside the hook body -- a Kernel,2090 nesting candidate on 0.742+.
		EffectDispatcher.defer(function()
			performRollCancelBehindBack(enemyRoot)
		end)
		return true
	end

	if choice == "mantra" then
		local mantraDelay = Configuration.expectOptionValue("AutoMixupFeintIntoMantraDelay") or 0.0
		EffectDispatcher.defer(function()
			if mantraDelay > 0 then
				task.wait(mantraDelay)
			end
			InputClient.amantra(mantraTool)
		end)
		return false
	end

	if choice == "feint" then
		EffectDispatcher.defer(function()
			task.wait() -- let the manual m1 go out first, then feint it
			InputClient.feint()
		end)
		return false
	end

	return false
end)

local function isBackstabActionLocked()
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local effectReplicatorModule = effectReplicator and require(effectReplicator)
	if not effectReplicatorModule then
		return false
	end

	return effectReplicatorModule:HasAny("Action", "MobileAction", "UsingAbility", "LightAttack")
end

local function getBackstabMovestackDelay()
	local delay = Configuration.expectOptionValue("BackstabMovestackDelay") or 0.05
	return math.max(delay, 0.0)
end

local function scheduleBackstabMovestackActivation(label)
	TaskSpawner.delay(label, function()
		return getBackstabMovestackDelay()
	end, function()
		backstabMovestackReady = false
		tryActivateBackstabMovestack()
	end)
end

local function isBackstabTriggerAnimationTrack(track)
	if not track or not track.Animation then
		return false
	end

	local aid = tostring(track.Animation.AnimationId)
	if aid == BACKSTAB_TRIGGER_ANIMATION_ID then
		return true
	end

	local numericId = aid:match("%d+")
	return numericId == BACKSTAB_TRIGGER_ANIMATION_NUMERIC_ID
end

local onBackstabLocalAnimationPlayed = LPH_NO_VIRTUALIZE(function(track)
	if not Configuration.expectToggleValue("BackstabMovestack") then
		return
	end

	if not isBackstabTriggerAnimationTrack(track) then
		return
	end

	if os.clock() - backstabAnimationTriggerTimestamp <= 0.15 then
		return
	end

	backstabMovestackReady = true
	backstabAnimationTriggerTimestamp = os.clock()

	if not isBackstabActionLocked() and tryActivateBackstabMovestack() then
		backstabMovestackReady = false
		return
	end

	TaskSpawner.spawn("Defense_BackstabMovestackImmediateRetry", function()
		local startedAt = os.clock()

		while os.clock() - startedAt <= 0.35 do
			if not backstabMovestackReady then
				return
			end

			if not Configuration.expectToggleValue("BackstabMovestack") then
				return
			end

			if not isBackstabActionLocked() and tryActivateBackstabMovestack() then
				backstabMovestackReady = false
				return
			end

			runService.RenderStepped:Wait()
		end

		scheduleBackstabMovestackActivation("Defense_BackstabMovestackFromAnimation")
	end)
end)

local function bindBackstabAnimationListener(character)
	if not character then
		return
	end

	local animator = character:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return
	end

	local animationPlayed = Signal.new(animator.AnimationPlayed)
	defenseMaid["Defense_BackstabAnimationPlayed"] =
		animationPlayed:connect("Defense_BackstabAnimationPlayed", onBackstabLocalAnimationPlayed)
end

local function onBackstabCharacterAdded(character)
	if not character then
		return
	end

	bindBackstabAnimationListener(character)

	local descendantAdded = Signal.new(character.DescendantAdded)
	defenseMaid["Defense_BackstabCharacterDescendantAdded"] = descendantAdded:connect(
		"Defense_BackstabCharacterDescendantAdded",
		function(descendant)
			if not descendant:IsA("Animator") then
				return
			end

			bindBackstabAnimationListener(character)
		end
	)
end

---@param effect table
local function onBackstabEffectAdded(effect)
	if not Configuration.expectToggleValue("BackstabMovestack") then
		return
	end

	if effect.Class == "backstabDebounce" then
		backstabMovestackReady = true
		task.delay(3, function()
			backstabMovestackReady = false
		end)
	end
end

---@param effect table
local function onBackstabEffectRemoved(effect)
	if not Configuration.expectToggleValue("BackstabMovestack") then
		return
	end

	if os.clock() - backstabAnimationTriggerTimestamp <= 1.0 then
		return
	end

	if effect.Class ~= "Action" or not backstabMovestackReady then
		return
	end

	scheduleBackstabMovestackActivation("Defense_BackstabMovestack")
end



local function attemptRollCast(mantra)
	if not isMantraAllowed(mantra, "RollCastMantrasList") then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local effectReplicatorModule = effectReplicator and require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	if effectReplicatorModule:HasAny(
		"AirCombo",
		"NoSlide",
		"Action",
		"MobileAction",
		"UsingAbility",
		"LightAttack",
		"Blocking",
		"Parried",
		"ClientSlide2",
		"ClientSwim"
	) then
		return
	end

	local keybindsModule = replicatedStorage:FindFirstChild("KeyBinds")
	if not keybindsModule then
		return
	end

	local Keybinds = require(keybindsModule)
	if not Keybinds or not Keybinds.ForceActionDown then
		return
	end

	Keybinds.ForceActionDown("Dodge")
	Keybinds.ForceActionUp("Dodge")

	task.delay(0.09, function()
		local clientFeint = effectReplicatorModule:CreateEffect("ClientFeint")
		if clientFeint then
			clientFeint:Debris(0.1)
		end
	end)
end

local function attemptSlideCast(mantra)
	if not isMantraAllowed(mantra, "SlideCastMantrasList") then
		return
	end

	local character = localPlayer and localPlayer.Character
	if not character then
		return
	end

	local ether = character:FindFirstChild("Ether")
	local spellCost = mantra and mantra:GetAttribute("SpellCost")
	if not ether or not spellCost or ether.Value <= spellCost then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local effectReplicatorModule = effectReplicator and require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	if effectReplicatorModule:HasAny(
		"AirCombo",
		"NoSlide",
		"Action",
		"MobileAction",
		"UsingAbility",
		"LightAttack",
		"Blocking",
		"Parried",
		"ClientSlide2",
		"ClientSwim"
	) then
		return
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end

	local moveDirection = humanoid.MoveDirection
	if moveDirection.Magnitude <= 0.1 then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local hitPart = workspace:FindPartOnRayWithIgnoreList(
		Ray.new(rootPart.Position, Vector3.new(0, -10, 0)),
		{ workspace:FindFirstChild("Live"), workspace:FindFirstChild("NPCs"), workspace:FindFirstChild("Thrown") }
	)

	if not hitPart then
		return
	end

	if not effectReplicatorModule:FindEffect("Sprinting") then
		return
	end

	local keybindsModule = replicatedStorage:FindFirstChild("KeyBinds")
	if not keybindsModule then
		return
	end

	local Keybinds = require(keybindsModule)
	if not Keybinds or not Keybinds.ForceActionDown then
		return
	end

	if not effectReplicatorModule:FindEffect("CastingSpell") then
		local castingSpell = effectReplicatorModule:CreateEffect("CastingSpell")
		if castingSpell then
			castingSpell:Debris(0.05)
		end
	end

	Keybinds.ForceActionDown("Crouch")
	Keybinds.ForceActionUp("Crouch")
end

local function updateMantraRequests()
	local mantra = StateListener.lMantraActivated
	if not mantra then
		return
	end

	local activatedAt = StateListener.lMantraActivatedAt
	if activatedAt == lastMantraActivatedAt then
		return
	end

	lastMantraActivatedTool = mantra
	lastMantraActivatedAt = activatedAt

	if Configuration.expectToggleValue("RollCastMantras") then
		attemptRollCast(mantra)
	end

	if Configuration.expectToggleValue("SlideCastMantras") then
		attemptSlideCast(mantra)
	end
end

local updateAutoAirCounter = LPH_NO_VIRTUALIZE(function()
	if not Configuration.expectToggleValue("AutoAirCounter") then
		return
	end

	if os.clock() - lastAutoAirCounterUpdate < 0.1 then
		return
	end
	lastAutoAirCounterUpdate = os.clock()

	local character = localPlayer and localPlayer.Character
	if not character then
		return
	end

	local characterHandler = character:FindFirstChild("CharacterHandler")
	local requests = characterHandler and characterHandler:FindFirstChild("Requests")
	local antiAir = requests and requests:FindFirstChild("AntiAir")
	if not antiAir then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	if not Configuration.expectToggleValue("AutoAirCounterOnGround") then
		local isGrounded = false
		local controllerManager = character:FindFirstChild("ControllerManager")
		if controllerManager then
			local groundSensor = controllerManager:FindFirstChild("GroundSensor")
			if groundSensor and groundSensor.SensedPart then
				isGrounded = true
			end
		end
		
		if not isGrounded then
			local humanoid = character:FindFirstChildWhichIsA("Humanoid")
			if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
				isGrounded = true
			end
		end

		if not isGrounded then
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = { workspace:FindFirstChild("Live"), workspace:FindFirstChild("NPCs"), workspace:FindFirstChild("Thrown") }
			local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -4, 0), raycastParams)
			if hit and hit.Instance then
				isGrounded = true
			end
		end

		if isGrounded then
			return
		end
	end

	local live = workspace:FindFirstChild("Live")
	if not live then
		return
	end

	local range = Configuration.expectOptionValue("AutoAirCounterRange") or 60
	local allyCheck = Configuration.expectToggleValue("AutoAirCounterAllyCheck")

	for _, entity in next, live:GetChildren() do
		if entity == character then
			continue
		end

		if entity.Name:sub(1, 1) == "." then
			continue
		end

		local entityRoot = entity:FindFirstChild("HumanoidRootPart")
		if not entityRoot then
			continue
		end

		local distance = (entityRoot.Position - rootPart.Position).Magnitude
		if distance > range then
			continue
		end

		if allyCheck then
			local entityPlayer = players:GetPlayerFromCharacter(entity)
			if entityPlayer then
				local pvpAttribute = entity:GetAttribute("PVPEnabled")
				if pvpAttribute == false or PlayerScanning.isAlly(entityPlayer) then
					continue
				end
			end
		end

		antiAir:FireServer(entity)
	end
end)

Defense.visualizations = LPH_NO_VIRTUALIZE(function()
	for _, object in next, defenderObjects do
		for _, hitbox in next, object.hmaid._tasks do
			if typeof(hitbox) ~= "Instance" then
				continue
			end

			hitbox.Transparency = Configuration.expectToggleValue("EnableVisualizations") and 0.2 or 1.0
		end
	end
end)

local updateVisualizations = LPH_NO_VIRTUALIZE(function()
	if not Configuration.expectToggleValue("EnableVisualizations") then
		return
	end

	if os.clock() - lastVisualizationUpdate <= 5.0 then
		return
	end

	lastVisualizationUpdate = os.clock()

	for _, object in next, defenderObjects do
		for idx, hitbox in next, object.hmaid._tasks do
			if typeof(hitbox) ~= "Instance" then
				continue
			end

			---@note: We call :Debris so we don't have to clean it up ourselves. We just unregister it from the maid.
			if hitbox.Parent then
				continue
			end

			object.hmaid._tasks[idx] = nil
		end
	end
end)

---@param position number
---@param str string
local hssp = LPH_NO_VIRTUALIZE(function(position, str)
	if autoWispLocked then
		return Logger.warn("Auto Wisp is locked.")
	end

	if position <= 0 or position > #str then
		return Logger.warn("Invalid position (%i vs. %i) for Auto Wisp.", position, #str)
	end

	local delay = Configuration.expectOptionValue("AutoWispDelay") or 0

	if lastAutoWispShift and os.clock() - lastAutoWispShift <= 0.15 + delay then
		return Logger.warn(
			"(%.2f - %.2f = %.2f vs. %.2f) Auto Wisp shift is on forced cooldown.",
			os.clock(),
			lastAutoWispShift,
			os.clock() - lastAutoWispShift,
			0.15 + delay
		)
	end

	local character = str:sub(position, position)
	if character ~= "Z" and character ~= "X" and character ~= "C" and character ~= "V" then
		return Logger.warn("Invalid character (%s) for Auto Wisp.", tostring(character))
	end

	local localPlayer = players.LocalPlayer
	local localPlayerCharacter = localPlayer.Character
	if not localPlayerCharacter then
		return
	end

	local mantras = replicatedStorage:FindFirstChild("Requests")
	mantras = mantras and mantras:FindFirstChild("Mantras")
	local spellInput = mantras and mantras:FindFirstChild("RitualSpellInput")
	if not spellInput then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	if not effectReplicatorModule:HasEffect("RitualCastingSpell") then
		return Logger.warn("RitualCastingSpell effect not found.")
	end

	if effectReplicatorModule:HasEffect("Knocked") then
		return Logger.warn("Knocked effect found.")
	end

	Logger.warn("Sending event for character (%s) with position (%i) and string (%s).", character, position, str)

	autoWispLocked = true
	lastAutoWispUpdate = os.clock()

	pcall(function()
		spellInput:FireServer(WISP_INPUT_MAP[character] or character)
	end)

	task.delay(0.5 + delay, function()
		autoWispLocked = false
	end)
end)

local updateDefenders = LPH_NO_VIRTUALIZE(function()
	Defense.updateBlockInputState()

	if Configuration.expectToggleValue("M1Hold") and leftClickState and not Defense.shouldBlockInput("M1s") then
		-- Held m1s are fired by our own code, so they bypass the m1 hook's Auto Mixup (which only runs
		-- on non-checkcaller input). Run the mixup here too: if it takes over (roll-cancel-behind), skip
		-- this held m1; otherwise fire it (a feint / feint-into-mantra rides on it).
		if not Defense.tryAutoMixup() then
			InputClient.left(players.LocalPlayer:GetMouse().Hit, true)
		end
	end

	if Configuration.expectToggleValue("AutoWisp") and cwp and cws then
		hssp(cwp, cws)
	end

	if not Configuration.expectToggleValue("EnableAutoDefense") then
		return
	end

	for _, object in next, defenderAnimationObjects do
		object:update()
	end

	for _, object in next, defenderPartObjects do
		object:update()
	end
end)

---@param part BasePart
---@param timing PartTiming?
---@return PartDefender?
Defense.cdpo = LPH_NO_VIRTUALIZE(function(part, timing)
	local partDefender = PartDefender.new(part, timing)
	if not partDefender then
		return nil
	end

	defenderObjects[part] = partDefender
	defenderPartObjects[part] = partDefender

	return partDefender
end)

---@param entity Instance
---@return AnimatorDefender?
Defense.dao = LPH_NO_VIRTUALIZE(function(entity)
	for _, object in next, defenderAnimationObjects do
		if object.entity ~= entity then
			continue
		end

		return object
	end
end)

local function isThreatImminent(object, timing)
	local entity = object.entity
	if not entity then
		return true
	end

	if not entity:FindFirstChild("HumanoidRootPart") then
		return true
	end

	local root = entity:FindFirstChild("HumanoidRootPart")

	if Configuration.expectOptionValue("BlockInputRangeCheck") == "Inside Hitbox" then
		local hoptions = HitboxOptions.new(root, timing)
		hoptions.visualize = false
		-- Enlarge the detection hitbox by 1.2x so it triggers a touch more leniently than the exact hitbox
		-- (hc reads the size from options:hitbox(), which returns this cache).
		hoptions.cache = hoptions:hitbox() * 1.2

		if hoptions:hitbox().Magnitude > 0 then
			return object:hc(hoptions, nil) == true
		end
	end

	local distance = object:distance(entity)
	if not distance then
		return true
	end

	return distance <= (timing.imxd or math.huge)
end

---@note: Runs on a safe thread (postSimulation) so the input hooks only ever read the cached
Defense.updateBlockInputState = LPH_NO_VIRTUALIZE(function()
	if
		not Configuration.expectToggleValue("EnableAutoDefense")
		or not Configuration.expectToggleValue("BlockInput")
	then
		blockInputActive = {}
		return
	end

	local allowedTargets = Configuration.expectOptionValue("BlockInputAllowedTargets") or {
		PVE = true,
		PVP = true,
	}

	local useTargeting = Configuration.expectToggleValue("BlockInputTargeting")
	local criticalPunishTime = (Configuration.expectOptionValue("BlockInputCriticalPunishmentTime") or 0) / 1000
	local m1PunishTime = (Configuration.expectOptionValue("BlockInputM1PunishmentTime") or 0) / 1000
	local halfPing = Latency.rdelay()

	local active = {}

	for object in next, Defender.armed do
		local timing = object.timing
		if timing and timing.ibi then
			continue
		end

		local ownerModel = object.entity or object.owner
		if not ownerModel and object.part then
			ownerModel = object.part:FindFirstAncestorWhichIsA("Model")
		end

		local isPvp = ownerModel and players:GetPlayerFromCharacter(ownerModel) ~= nil
		if isPvp and not allowedTargets.PVP then
			continue
		end

		if not isPvp and not allowedTargets.PVE then
			continue
		end

		if useTargeting and not (ownerModel and Targeting.find(ownerModel, BLOCK_INPUT_TARGETING_KEYS)) then
			continue
		end

		if timing and not isThreatImminent(object, timing) then
			continue
		end

		if object:blocking() then
			active.Mantras = true
		end

		for _, tsk in next, object.tasks do
			if coroutine.status(tsk.thread) == "dead" then
				continue
			end

			local when = tsk:when()
			local tail = when + tsk.after

			if os.clock() >= when - criticalPunishTime - halfPing and os.clock() <= tail then
				active.Criticals = true
			end

			if os.clock() >= when - m1PunishTime - halfPing and os.clock() <= tail then
				active.M1s = true
			end
		end
	end

	blockInputActive = active
end)

---@note: Cheap read only (booleans + option table) so it is safe to call from input hooks.
---@param moveType string
---@return boolean
Defense.shouldBlockInput = LPH_NO_VIRTUALIZE(function(moveType)
	local blockedMoves = Configuration.expectOptionValue("BlockedSafeInputUserMoves") or {}
	return blockedMoves[moveType] == true and blockInputActive[moveType] == true
end)

---@param aid string
---@return PlaybackData?
Defense.agpd = LPH_NO_VIRTUALIZE(function(aid)
	---@note: Grabbing from 'rpbdata' means that we know that the data has been fully recorded.
	for _, object in next, defenderAnimationObjects do
		local pbdata = object.rpbdata[aid]
		if not pbdata then
			continue
		end

		return pbdata
	end

	---@note: Fallback to deleted playback data if that doesn't exist.
	for _, rpbdata in next, deletedPlaybackData do
		local pbdata = rpbdata[aid]
		if not pbdata then
			continue
		end

		return pbdata
	end
end)

---@param name string
---@param data any?
local onSpellEvent = LPH_NO_VIRTUALIZE(function(name, data)
	if name == "close" then
		cws = nil
		cwp = nil
		lastAutoWispUpdate = nil
		lastAutoWispShift = nil
		autoWispLocked = false
	end

	if name == "start" then
		cws = data
		cwp = 1
		lastAutoWispUpdate = nil
		lastAutoWispShift = nil
		autoWispLocked = false
	end

	if cws and cwp and name == "shift" then
		cwp = cwp + 1
		lastAutoWispShift = os.clock()
		autoWispLocked = false
	end
end)

function Defense.fflourish()
	if not Configuration.expectToggleValue("FeintFlourish") then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return Logger.warn("EffectReplicator not found for FeintFlourish.")
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return Logger.warn("EffectReplicator module not found for FeintFlourish.")
	end

	if not effectReplicatorModule:FindEffect("MidAttack") then
		return Logger.warn("Not MidAttack effect for FeintFlourish.")
	end

	local mantra = Finder.ncdm()
	if not mantra then
		return Logger.warn("No mantra found for FeintFlourish.")
	end

	if effectReplicatorModule:FindEffect("FeintCool") then
		return Logger.warn("No avaliable feint for FeintFlourish.")
	end

	local lastAnimationTiming = StateListener.lAnimTiming
	if not lastAnimationTiming then
		return Logger.warn("No last animation timing found for FeintFlourish.")
	end

	if not lastAnimationTiming.smod:match("Flourish") then
		return Logger.warn("Last animation is not a flourish for FeintFlourish.")
	end

	Logger.warn("(%s) FeintFlourish activated mantra.", mantra.Name)

	InputClient.amantra(mantra)

	task.wait(0.1)

	Logger.warn("(%s) FeintFlourish feinted mantra.", mantra.Name)

	InputClient.feint()
end

function Defense.init()
	local WAIT = 30

	local assetFolder = replicatedStorage:WaitForChild("Assets", WAIT)
	local animationFolder = assetFolder and assetFolder:WaitForChild("Anims", WAIT)
	local mobsAnimationFolder = animationFolder and animationFolder:WaitForChild("Mobs", WAIT)

	for _, animation in next, mobsAnimationFolder and mobsAnimationFolder:QueryDescendants("Animation") or {} do
		if animation.Name == "RunningAttack" then
			continue
		end

		mobAnimations[animation.AnimationId] = animation
	end

	local requests = replicatedStorage:WaitForChild("Requests", WAIT)
	local clientEffect = requests and requests:WaitForChild("ClientEffect", WAIT)
	local clientEffectLarge = requests and requests:WaitForChild("ClientEffectLarge", WAIT)
	local clientEffectDirect = requests and requests:WaitForChild("ClientEffectDirect", WAIT)
	local mantras = requests and requests:WaitForChild("Mantras", WAIT)
	local spell = mantras and mantras:WaitForChild("RitualSpellInput", WAIT)

	local gameDescendantAdded = Signal.new(game.DescendantAdded)
	local gameDescendantRemoved = Signal.new(game.DescendantRemoving)
	local characterAdded = Signal.new(localPlayer.CharacterAdded)
	local inputBegan = Signal.new(userInputService.InputBegan)
	local inputEnded = Signal.new(userInputService.InputEnded)
	local renderStepped = Signal.new(runService.RenderStepped)
	local postSimulation = Signal.new(runService.PostSimulation)
	local clientEffectEvent = clientEffect and Signal.new(clientEffect.OnClientEvent)
	local clientEffectLargeEvent = clientEffectLarge and Signal.new(clientEffectLarge.OnClientEvent)
	local cientEffectDirect = clientEffectDirect
		and Signal.new(clientEffectDirect:IsA("BindableEvent") and clientEffectDirect.Event or clientEffectDirect.OnClientEvent)
	local spellEvent = spell and Signal.new(spell.OnClientEvent)

	local effectReplicator = replicatedStorage:WaitForChild("EffectReplicator", WAIT)
	if not effectReplicator then
		return error("EffectReplicator not found.")
	end

	local effectReplicatorModule = require(effectReplicator)
	local effectAddedSignal = Signal.new(effectReplicatorModule.EffectAdded)
	local effectRemovedSignal = Signal.new(effectReplicatorModule.EffectRemoved)

	---@note: Need this to detect UI presses / game processed inputs.
	defenseMaid:mark(inputBegan:connect("Defense_OnInputBegan", function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			TaskSpawner.delay("StateListener_FeintFlourish", function()
				return 0.07
			end, Defense.fflourish)
		end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		do
			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			-- Skip while Auto Mixup's roll-behind runs its own roll cancel, so we don't stack a second
			-- feint + m1 on it. Time-bounded so a stuck flag can't disable Easy Roll Cancel for good.
			local mixupBusy = rollBehindActive and (os.clock() - lastAutoMixupAt) < 1.0
			if root and not mixupBusy and (os.clock() - lastEasyFeint) > 0.3 and StateListener.cfeint() then
				if
					Configuration.expectToggleValue("EasyMantraFeint")
					and (effectReplicatorModule:HasEffect("UsingSpell") or effectReplicatorModule:HasEffect("CastingSpell"))
				then
					lastEasyFeint = os.clock()
					task.spawn(function()
						InputClient.feint()
						task.wait()
						InputClient.left(root.CFrame, true)
					end)
				elseif
					Configuration.expectToggleValue("EasyRollCancel")
					and (effectReplicatorModule:HasEffect("Dodge") or effectReplicatorModule:HasEffect("ClientDodge"))
				then
					lastEasyFeint = os.clock()
					task.spawn(function()
						InputClient.feint()
						task.wait()
						InputClient.left(root.CFrame, true)
					end)
				end
			end
		end

		leftClickState = true
	end))

	defenseMaid:mark(inputEnded:connect("Defense_OnInputEnded", function(input, _)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		leftClickState = false
	end))

	defenseMaid:mark(gameDescendantAdded:connect("Defense_OnDescendantAdded", onGameDescendantAdded))
	defenseMaid:mark(gameDescendantRemoved:connect("Defense_OnDescendantRemoved", onGameDescendantRemoved))

	-- Per-entity animator tracking off workspace.Live (replaces the game-wide Animator branch of
	-- handleGameDescendant). One AnimatorDefender per live entity, torn down the instant it leaves Live --
	-- ChildRemoved fires on a reparent-out too, which game.DescendantRemoving misses. Spawned so a missing
	-- Live folder can't block init.
	defenseMaid:mark(task.spawn(function()
		local live = workspace:WaitForChild("Live", 30)
		if not live then
			return
		end

		defenseMaid:mark(Signal.new(live.ChildAdded):connect("Defense_LiveEntityAdded", trackLiveEntity))
		defenseMaid:mark(Signal.new(live.ChildRemoved):connect("Defense_LiveEntityRemoved", untrackLiveEntity))

		for _, entity in next, live:GetChildren() do
			trackLiveEntity(entity)
		end
	end))

	defenseMaid:mark(renderStepped:connect("Defense_UpdateVisualizations", updateVisualizations))
	defenseMaid:mark(renderStepped:connect("Defense_UpdateHistory", updateHistory))
	defenseMaid:mark(renderStepped:connect("Defense_UpdateGoldenTongue", updateGoldenTongue))
	defenseMaid:mark(renderStepped:connect("Defense_UpdateAutoArdour", updateAutoArdour))
	defenseMaid:mark(postSimulation:connect("Defense_UpdateDefenders", updateDefenders))
	defenseMaid:mark(postSimulation:connect("Defense_UpdateMantraRequests", updateMantraRequests))
	defenseMaid:mark(postSimulation:connect("Defense_UpdateAutoAirCounter", updateAutoAirCounter))

	if clientEffectEvent then
		defenseMaid:mark(clientEffectEvent:connect("Defense_ClientEffectEvent", onClientEffectEvent))
	end

	if clientEffectLargeEvent then
		defenseMaid:mark(clientEffectLargeEvent:connect("Defense_ClientEffectEventLarge", onClientEffectEvent))
	end

	if cientEffectDirect then
		defenseMaid:mark(cientEffectDirect:connect("Defense_ClientEffectEventDirect", onClientEffectEvent))
	end

	if spellEvent then
		defenseMaid:mark(spellEvent:connect("Defense_SpellEvent", onSpellEvent))
	end
	defenseMaid:mark(characterAdded:connect("Defense_BackstabCharacterAdded", onBackstabCharacterAdded))
	defenseMaid:mark(effectAddedSignal:connect("Defense_BackstabEffectAdded", onBackstabEffectAdded))
	defenseMaid:mark(effectRemovedSignal:connect("Defense_BackstabEffectRemoved", onBackstabEffectRemoved))

	onBackstabCharacterAdded(localPlayer.Character)

	-- Initial catch-up sweep for parts/sounds/animators that already exist. This walks the ENTIRE
	-- DataModel (tens of thousands of instances, most of them BaseParts that miss every timing) and
	-- was the single biggest chunk of startup (~425ms, fully blocking). Run it in the background with
	-- a ~4ms/frame budget instead: game.DescendantAdded (connected just above) already covers anything
	-- that appears while we sweep, so nothing is missed -- pre-existing static hazards just get their
	-- defender within a few frames instead of blocking the whole load.
	defenseMaid:mark(task.spawn(function()
		local descendants = game:GetDescendants()
		local budgetStart = os.clock()

		for index = 1, #descendants do
			onGameDescendantAdded(descendants[index])

			if os.clock() - budgetStart > 0.004 then
				runService.Heartbeat:Wait()
				budgetStart = os.clock()
			end
		end
	end))

	if not LPH_OBFUSCATED or shared.Aero.verbose then
		Logger.warn("Defense initialized.")
	end
end

function Defense.detach()
	for _, object in next, defenderObjects do
		object:detach()
	end

	table.clear(defenderObjects)
	table.clear(defenderPartObjects)
	table.clear(defenderAnimationObjects)
	table.clear(deletedPlaybackData)

	defenseMaid:clean()

	Logger.warn("Defense detached.")
end

return Defense
