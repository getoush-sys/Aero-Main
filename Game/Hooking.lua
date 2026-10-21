local Hooking = {}

---@module Game.KeyHandling
local KeyHandling = require("Game/KeyHandling")

---@module Game.SelfFire
local SelfFire = require("Game/SelfFire")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Features.Combat.StateListener
local StateListener = require("Features/Combat/StateListener")

---@module Game.LeaderboardClient
local LeaderboardClient = require("Game/LeaderboardClient")

---@module Features.Game.Spoofing
local Spoofing = require("Features/Game/Spoofing")

---@module Game.Objects.DodgeOptions
local DodgeOptions = require("Game/Objects/DodgeOptions")

---@module Utility.TaskSpawner
local TaskSpawner = require("Utility/TaskSpawner")

---@module Features.Combat.Defense
local Defense = require("Features/Combat/Defense")

local LogService = game:GetService("LogService")
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local lighting = game:GetService("Lighting")
local httpService = game:GetService("HttpService")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")

local LOBBY_PLACE_ID = 4111023553

local noFallConnection = nil
local noFallModule = nil
local noFallLastOn = false
local noFallLastRun = 0

local isA = game.IsA

-- Parallel-hook guard. Deepwoken's SmartBone system (ReplicatedStorage.Modules.SmartBone) spawns one
-- Instance.new("Actor") per smartbone object -- every nearby character's hair/cloth/cape/mob fur -- and
-- each Actor VM runs a Heartbeat:ConnectParallel callback that, in the DESYNCHRONIZED phase, makes
-- Instance namecalls (u1:GetAttribute("SmartBones"), UpdateBones, ...). A game __namecall/__newindex hook
-- installed via the native hookmetamethod is process-global: those parallel namecalls dispatch our hook
-- body (checkcaller()/getnamecallmethod() -- main-VM executor reflection) mid-parallel-phase, which is the
-- illegal cross-phase op the engine Kernel deliberately aborts on (RSL - panic: ...Kernel,2090 -- fires
-- AFK/random because smartbones animate off other entities, toggle-independent because the reflection runs
-- before any config check). The native hookmetamethod is NEVER safe here, even when the executor advertises
-- parallel_hooks_allowed. ALWAYS install via a plain read-only metatable swap: the main VM's `game` metatable
-- is not shared into the SmartBone Actor VMs, so their parallel namecalls can never reach our body.
local hookmetamethod = function(target, method, hook)
	local metatable = getrawmetatable(target)
	setreadonly(metatable, false)
	local original = metatable[method]
	metatable[method] = hook
	setreadonly(metatable, true)
	return original
end

-- ============================================================================
-- STM worker-thread / foreign-VM firewall.
--
-- Roblox's 0.742 scheduler rewrite (old single-threaded "TS" -> new multi-threaded "STM", confirmed by
-- diffing 0.738 vs 0.742: the panic file hash 7179168 and "STM::guard"/Worker/Queue/Condition modules are
-- new, and "Kernel,2090" did not exist in 0.738) added a STRICT per-thread re-entrancy guard:
--   STM::guard -> "RBX_on* callback re-entrancy violation" -> RSL panic 7179168-Kernel,2090.
-- It fires when a thread re-enters a guarded scheduler callback. That happens when one of our process-global
-- hooks is dispatched inside a parallel Actor VM running on an STM worker thread (Deepwoken's SmartBone
-- ConnectParallel jobs) and then does engine work there. The old TS scheduler had no such guard, which is why
-- 0.738 never crashed and the crash "started after a Roblox update".
--
-- Fix: capture Aero's own VM identity ONCE at load (we are required on the main, synchronized VM). If a hook
-- body is ever entered with a different VM identity, it is executing in a foreign (Actor/worker) VM, so we bail
-- straight to the original and touch NOTHING. The check is pure Lua (registry/global-table identity compare,
-- no reflection) so it cannot itself re-enter STM::guard, and in the main VM it is always a no-op -> zero cost
-- to normal behaviour. Prefer getreg() (per-Lua-state registry, strongest signal); fall back to getfenv(0)
-- (per-state global env); if neither exists the guard disables itself (behaviour identical to before).
-- ============================================================================
local function captureVMToken()
	local token
	local ok = pcall(function()
		if type(getreg) == "function" then
			token = getreg()
		elseif type(getfenv) == "function" then
			token = getfenv(0)
		end
	end)
	if ok then
		return token
	end
	return nil
end

local MAIN_VM_TOKEN = captureVMToken()

local function foreignVM()
	if MAIN_VM_TOKEN == nil then
		return false
	end
	local token = captureVMToken()
	return token ~= nil and token ~= MAIN_VM_TOKEN
end

local oldFireServer = nil
local oldUnreliableFireServer = nil
local oldNameCall = nil
local oldNewIndex = nil
local oldToString = nil
local usingMetaMethodHooks = false

local oldGetKey = nil
local oldCreateKey = nil
local oldKeyHandlerModule = nil
local hookedGetFn = nil
local hookedCreateFn = nil
local hookedKeyHandlerModule = nil

local cachedEffectReplicator = nil
local function getEffectReplicator()
	if not cachedEffectReplicator then
		cachedEffectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	end
	return cachedEffectReplicator
end

local lastActionRoll = nil

-- Action Rolling reactions are QUEUED here by onInterceptedInput (a pure table write on the hook callstack) and
-- drained by an always-on Heartbeat pump on its OWN top-level scheduler step -- never task.defer'd from inside
-- the FireServer/__namecall hook body. task.defer there registers a thread with the scheduler from inside the
-- hook's STM job, a candidate for nesting a second guarded job (RSL panic Kernel,2090 on 0.742+). A table write
-- touches the scheduler not at all; the pump runs handleActionRolling (which yields + fires the dodge) on its
-- own step, where that's safe -- the same place maintainNoFall already runs.
local pendingActionRolls = {}
local actionRollPumpConnection = nil

local walkSpeedRandom = Random.new()
local walkSpeedMultiplier = 1.0
local lastWalkSpeedRefresh = 0
local WALK_SPEED_REFRESH = 1.5

local banRemotes = {}

local INPUT_LEFT_CLICK = 1
local INPUT_RIGHT_CLICK = 2
local INPUT_CRITICAL = 3
local INPUT_CAST = 4
local INPUT_BLOCK = 5

local BLOCK_INPUT_MOVE_MAP = {
	[INPUT_LEFT_CLICK] = "M1s",
	[INPUT_CRITICAL] = "Criticals",
	[INPUT_CAST] = "Mantras",
}

local INPUT_TYPE_BEFORE = 1
local INPUT_TYPE_AFTER = 2

-- Auto Flow State -- EXACTLY Project Rain's auto_flow_state.lua. Driven off Humanoid.AnimationPlayed, never
-- from a remote/input hook: when one of the Silentheart flow-state move animations plays, fire the
-- Talent:Flow State ActivateRt remote. AnimationPlayed resolves on its own main-VM scheduler step, entirely
-- outside any FireServer / __namecall callstack -- so there is structurally nothing to re-enter. That removes
-- the cross-phase re-entrancy the old input-hook flowstate created (a Kernel,2090 panic candidate). No
-- effectReplicator cooldown reflection either, exactly like PR: the server just no-ops a fire made on cooldown.
local FLOW_STATE_ANIMATION_IDS = {
	["rbxassetid://110691694093015"] = true,
	["rbxassetid://85523657178401"] = true,
	["rbxassetid://100709561068031"] = true,
	["rbxassetid://139465383955578"] = true,
	["rbxassetid://82111969749817"] = true,
	["rbxassetid://101880653361558"] = true,
	["rbxassetid://132164383275060"] = true,
	["rbxassetid://72748965289041"] = true,
	["rbxassetid://12564120372"] = true,
}

local flowStateAnimConnection = nil
local flowStateCharConnection = nil

---@param track AnimationTrack
local onFlowStateAnimation = LPH_NO_VIRTUALIZE(function(track)
	if not Configuration.expectToggleValue("AutoFlowState") then
		return
	end

	if not track or not track.Animation then
		return
	end

	if not FLOW_STATE_ANIMATION_IDS[track.Animation.AnimationId] then
		return
	end

	local localPlayer = playersService.LocalPlayer
	if not localPlayer then
		return
	end

	local character = localPlayer.Character
	local backpack = localPlayer:FindFirstChild("Backpack")

	local flowStateTool = (backpack and backpack:FindFirstChild("Talent:Flow State"))
		or (character and character:FindFirstChild("Talent:Flow State"))
	if not flowStateTool then
		return
	end

	local flowStateRemote = flowStateTool:FindFirstChild("ActivateRt")
	if not flowStateRemote then
		return
	end

	flowStateRemote:FireServer()
end)

---@param character Model
local bindFlowStateCharacter = LPH_NO_VIRTUALIZE(function(character)
	if flowStateAnimConnection then
		pcall(function()
			flowStateAnimConnection:Disconnect()
		end)
		flowStateAnimConnection = nil
	end

	if not character then
		return
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid") or character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	flowStateAnimConnection = humanoid.AnimationPlayed:Connect(onFlowStateAnimation)
end)

---@param type number
local handleActionRolling = LPH_NO_VIRTUALIZE(function(type)
	local actionRollTypes = Configuration.expectOptionValue("ActionRollingActions") or {}
	local actionRollInputs = {
		[INPUT_LEFT_CLICK] = actionRollTypes["Roll On M1"],
		[INPUT_CRITICAL] = actionRollTypes["Roll On Critical"],
		[INPUT_CAST] = actionRollTypes["Roll On Cast"],
		[INPUT_BLOCK] = actionRollTypes["Roll On Parry"],
	}

	if not actionRollInputs[type] then
		return
	end

	if type ~= INPUT_CAST then
		local effectReplicator = getEffectReplicator()
		if not effectReplicator then
			return
		end

		local effectReplicatorModule = require(effectReplicator)
		if not effectReplicatorModule then
			return
		end

		if not effectReplicatorModule:HasEffect("Equipped") then
			return
		end
	end

	if type == INPUT_CAST then
		local lMantraActivated = StateListener.lMantraActivated
		if not lMantraActivated then
			return
		end

		if lMantraActivated.Name:match("Wisp") then
			return
		end
	end

	if
		lastActionRoll
		and os.clock() - lastActionRoll < (Configuration.expectOptionValue("ActionRollCooldown") or 2.0)
	then
		return
	end

	lastActionRoll = os.clock()

	if type ~= INPUT_BLOCK then
		task.wait(0.1)
	end

	local options = DodgeOptions.new()
	options.rollCancel = true
	options.rollCancelDelay = Configuration.expectOptionValue("ActionRollCancelDelay") or 0.1
	options.actionRolling = true

	Logger.warn("(%i) Performing action roll dodge.", type)

	if type == INPUT_CAST then
		TaskSpawner.spawn("ActionRolling_CastDodge", InputClient.dodge, options)
	else
		InputClient.dodge(options)
	end
end)

-- Drain queued action-roll reactions on the Heartbeat step -- a fresh top-level scheduler job (same place
-- maintainNoFall runs), NOT a resumption nested inside a hook. handleActionRolling's internal task.wait + dodge
-- fire therefore happen off the FireServer/__namecall callstack. Snapshot-and-clear before running so a re-entry
-- (the handler yields) sees an empty queue; handleActionRolling self-cools via lastActionRoll, so a type
-- re-queued every input frame can't stack dodges. Run inline (pcall), no task.spawn -- the only scheduler op is
-- handleActionRolling's own task.wait, a benign yield, never a second job-start.
local drainActionRolls = LPH_NO_VIRTUALIZE(function()
	if not next(pendingActionRolls) then
		return
	end
	local queued = pendingActionRolls
	pendingActionRolls = {}
	for rollType in next, queued do
		pcall(handleActionRolling, rollType)
	end
end)

local handleDelayedFeints = LPH_NO_VIRTUALIZE(function()
	local lAnimTrack = StateListener.lAnimationValidTrack
	if not lAnimTrack then
		return Logger.warn("No valid animation track for delayed feint.")
	end

	local lAnimFaction = StateListener.lAnimFaction
	if not lAnimFaction then
		return Logger.warn("No animation faction for delayed feint.")
	end

	if not lAnimTrack.IsPlaying then
		return Logger.warn("Non playing animation track for delayed feint.")
	end

	if not StateListener.cfeint() then
		return Logger.warn("Unable to feint for delayed feint.")
	end

	local laTimestamp = StateListener.lAnimTimestamp
	if not laTimestamp then
		return Logger.warn("No animation timestamp for delayed feint.")
	end

	local laLatency = StateListener.lAnimLatency
	if not laLatency then
		return Logger.warn("No animation latency for delayed feint.")
	end

	local delayed = (lAnimFaction:when() - (os.clock() - laTimestamp)) - laLatency

	Logger.warn("Delaying for %.2f seconds before sending the feint remote.", delayed)

	task.wait(delayed)
end)

---@param type number
---@param state number
local onInterceptedInput = LPH_NO_VIRTUALIZE(function(type, state)
	-- Every handler is pcall'd: a thrown error would otherwise propagate out of the hook and abort the player's
	-- real input fire (you'd silently lose the M1/parry/cast). pcall degrades a broken feature to a no-op.
	--
	-- Action Rolling detection stays inline (a pure remote-identity read). The REACTION is not task.defer'd from
	-- here anymore: task.defer registers a thread with the scheduler from inside this FireServer/__namecall hook
	-- body (an STM job on 0.742+), which can nest a second guarded job -> RSL panic Kernel,2090. Instead we only
	-- set a flag; the always-on Heartbeat pump (drainActionRolls) runs handleActionRolling -- which yields + fires
	-- the dodge -- on its own top-level scheduler step, off this hook's callstack entirely.
	if Configuration.expectToggleValue("ActionRolling") and state == INPUT_TYPE_AFTER then
		pendingActionRolls[type] = true
	end

	-- Delayed Feints stays INLINE on purpose: it fires no remote of its own -- it task.wait()s here to postpone
	-- the player's own feint passthrough (oldFireServer runs after this returns). It's a scheduler yield, not a
	-- cross-phase fire, so it isn't the 2090 surface. (PR's analogue, easy_feint, instead initiates the feint off
	-- the EffectReplicator "added" signal -- a different mechanism, left as-is to preserve Aero's feint timing.)
	if
		Configuration.expectToggleValue("DelayedFeints")
		and state == INPUT_TYPE_BEFORE
		and type == INPUT_RIGHT_CLICK
		and StateListener.lAnimationValidTrack
	then
		pcall(handleDelayedFeints)
	end
end)

---@todo: de-duplicate this method with the following below, just too lazy for now, time crunch
---@return number?, table?
local findClientPhysicsLevel = LPH_NO_VIRTUALIZE(function()
	for level = 1, math.huge do
		local success, info = pcall(debug.getinfo, level)
		if not success or not info then
			break
		end

		if not info.source:match("ClientPhysics") then
			continue
		end

		return level, info
	end
end)

---@param value Color3
local modifyAmbienceColor = LPH_NO_VIRTUALIZE(function(value)
	local ambienceColor = Configuration.expectOptionValue("AmbienceColor")
	local shouldUseOriginalAmbienceColor = Configuration.expectToggleValue("OriginalAmbienceColor")

	if not shouldUseOriginalAmbienceColor and ambienceColor then
		return ambienceColor
	end

	local brightness = Configuration.expectOptionValue("OriginalAmbienceColorBrightness") or 0.0
	local red, green, blue = value.R, value.G, value.B

	red = math.min(red * 255 + brightness, 255)
	green = math.min(green * 255 + brightness, 255)
	blue = math.min(blue * 255 + brightness, 255)

	return Color3.fromRGB(red, green, blue)
end)

---@return any
local onNameCall = LPH_NO_VIRTUALIZE(function(self, ...)
	-- STM firewall: never run our body on an Actor/worker VM (see foreignVM above) -- bail to the original.
	if foreignVM() then
		return oldNameCall(self, ...)
	end

	if not LeaderboardClient.calling and checkcaller() then
		return oldNameCall(self, ...)
	end

	if banRemotes[self] then
		return Logger.warn("(%s) Anticheat is referencing a ban remote.", self.Name)
	end

	if typeof(self) ~= "Instance" then
		return oldNameCall(self, ...)
	end

	local secondArg = ...
	local method = getnamecallmethod()
	local name = self.Name

	-- Silent Aim: drop the game's own UpdateMouse fire so only our redirected mouse position reaches the
	-- server. Our own UpdateMouse fire is checkcaller() == true and short-circuits at the top of this hook,
	-- so it is never caught here -- only the game's (checkcaller() == false) calls reach this point.
	if name == "UpdateMouse" and method == "FireServer" and Configuration.expectToggleValue("SilentAim") then
		return
	end

	if method == "Raycast" then
		local callingScript = getcallingscript()

		if callingScript and callingScript.Name == "ClientPhysics" then
			local _, info = findClientPhysicsLevel()

			if info and info.name == "" then
				return false
			end
		end
	end

	if method == "Create" then
		---@note: Fix object if we're using a lighting template.
		local lightingTemplate = select(3, ...)

		if typeof(lightingTemplate) == "table" then
			if
				lightingTemplate["FogStart"]
				and lightingTemplate["FogEnd"]
				and Configuration.expectToggleValue("NoFog")
			then
				lightingTemplate["FogStart"] = 9e9
				lightingTemplate["FogEnd"] = 9e9
			end

			if lightingTemplate["Ambient"] and Configuration.expectToggleValue("ModifyAmbience") then
				lightingTemplate["Ambient"] = modifyAmbienceColor(lightingTemplate["Ambient"])
			end

			if lightingTemplate["Density"] and Configuration.expectToggleValue("NoFog") then
				lightingTemplate["Density"] = 0
			end

			---@note: lightingTemplate is mutated in place (same table reference), so
			return oldNameCall(self, ...)
		end
	end

	if Configuration.expectToggleValue("InfoSpoofing") then
		if typeof(secondArg) == "string" and method == "GetAttribute" and not Spoofing.force then
			local localPlayer = playersService.LocalPlayer
			local character = localPlayer and localPlayer.Character
			local humanoid = game.FindFirstChild(character, "Humanoid")
			local foreign = true

			if character and humanoid and (self.Parent == character or self.Parent == humanoid) then
				foreign = false
			end

			if foreign and not Configuration.expectToggleValue("SpoofOtherPlayers") then
				return oldNameCall(self, ...)
			end

			if secondArg == "FirstName" then
				return foreign and "Linoria V2" or Configuration.expectOptionValue("SpoofedFirstName")
			end

			if secondArg == "LastName" then
				return foreign and "On Top" or Configuration.expectOptionValue("SpoofedLastName")
			end

			if secondArg == "CharacterName" then
				local characterName = Configuration.expectOptionValue("SpoofedFirstName")
					.. " "
					.. Configuration.expectOptionValue("SpoofedLastName")

				return foreign and "Linoria V2 On Top" or characterName
			end

			if secondArg == "Guild" then
				return foreign and "discord.gg/lyc" or Configuration.expectOptionValue("SpoofedGuild")
			end

			if secondArg == "GuildRich" then
				return foreign and "discord.gg/lyc" or Configuration.expectOptionValue("SpoofedGuildName")
			end
		end
	end

	if name == "ActivateMantra" and method == "FireServer" then
		local blockMantra = false
		if not checkcaller() then
			local ok, result = pcall(Defense.shouldBlockInput, "Mantras")
			blockMantra = ok and result == true
		end

		if blockMantra then
			return
		end

		StateListener.lMantraActivated = secondArg

		onInterceptedInput(INPUT_CAST, INPUT_TYPE_BEFORE)

		if setnamecallmethod then
			setnamecallmethod(method)
		end

		local result = oldNameCall(self, ...)

		onInterceptedInput(INPUT_CAST, INPUT_TYPE_AFTER)

		return result
	end

	if name == "ClientEffectBatch" and method == "FireServer" then
		return
	end

	return oldNameCall(self, ...)
end)

---@return any
local onUnreliableFireServer = LPH_NO_VIRTUALIZE(function(self, ...)
	if foreignVM() then
		return oldUnreliableFireServer(self, ...)
	end

	if banRemotes[self] then
		return Logger.warn("(%s) Anticheat is calling a unreliable ban remote.", self.Name)
	end

	-- PR-style hard gate: our own re-fires skip the reactive hook body entirely, mirroring Project Rain's
	-- `if checkcaller() then return old_fireserver(...)` top guard -- but via SelfFire.active, the reflection-free
	-- boolean (this hook is process-global and runs in the parallel Actor VMs, where checkcaller() itself would be
	-- the Kernel,2090 cross-phase reflection). Aero raises SelfFire only around its own InputClient re-fires, so a
	-- real player input is never SelfFire.active here and always runs the full body below.
	if SelfFire.active then
		return oldUnreliableFireServer(self, ...)
	end

	-- getCachedRemote (pure cache read, never the encoder) -- PR resolves these in setup and only pure-reads in
	-- the global fire hooks. The keys are prewarmed once at init (Hooking.init -> KeyHandling.prewarm).
	local leftClickRemote = KeyHandling.getCachedRemote("LeftClick")
	local criticalRemote = KeyHandling.getCachedRemote("CriticalClick")
	local feintClickRemote = KeyHandling.getCachedRemote("FeintClick")
	local offhandAttackRemote = KeyHandling.getCachedRemote("OffhandAttack")

	local inputType = nil

	if criticalRemote and self == criticalRemote then
		inputType = INPUT_CRITICAL
	end

	if leftClickRemote and self == leftClickRemote then
		inputType = INPUT_LEFT_CLICK
	end

	if (feintClickRemote and self == feintClickRemote) or (offhandAttackRemote and self == offhandAttackRemote) then
		inputType = INPUT_RIGHT_CLICK
	end

	if inputType then
		-- SelfFire.active was handled by the top gate, so by here this is always the game's own fire.
		local blockMove = BLOCK_INPUT_MOVE_MAP[inputType]
		local ok, blocked = pcall(Defense.shouldBlockInput, blockMove)
		if ok and blocked then
			return
		end

		if inputType == INPUT_LEFT_CLICK then
			local okMixup, handled = pcall(Defense.tryAutoMixup)
			if okMixup and handled then
				return
			end
		end

		onInterceptedInput(inputType, INPUT_TYPE_BEFORE)

		local result = oldUnreliableFireServer(self, ...)

		onInterceptedInput(inputType, INPUT_TYPE_AFTER)

		return result
	end

	return oldUnreliableFireServer(self, ...)
end)

---@return any
local onFireServer = LPH_NO_VIRTUALIZE(function(self, ...)
	if foreignVM() then
		return oldFireServer(self, ...)
	end

	if banRemotes[self] then
		return Logger.warn("(%s) Anticheat is calling a ban remote.", self.Name)
	end

	-- PR-style hard gate (see onUnreliableFireServer): our own fires skip the reactive body via the reflection-free
	-- SelfFire.active flag, the parallel-safe equivalent of PR's checkcaller() top guard.
	if SelfFire.active then
		return oldFireServer(self, ...)
	end

	local blockRemote = KeyHandling.getCachedRemote("Block")

	local inputType = nil

	if blockRemote and self == blockRemote then
		inputType = INPUT_BLOCK
	end

	if inputType then
		onInterceptedInput(inputType, INPUT_TYPE_BEFORE)

		local result = oldFireServer(self, ...)

		onInterceptedInput(inputType, INPUT_TYPE_AFTER)

		return result
	end

	return oldFireServer(self, ...)
end)

---@return number
local getWalkSpeedMultiplier = LPH_NO_VIRTUALIZE(function()
	if os.clock() - lastWalkSpeedRefresh > WALK_SPEED_REFRESH then
		local min = Configuration.expectOptionValue("WalkSpeedMultiplierMinimum") or 1.0
		local max = Configuration.expectOptionValue("WalkSpeedMultiplierMaximum") or 1.0

		if min > max then
			min, max = max, min
		end

		walkSpeedMultiplier = walkSpeedRandom:NextNumber(min, max)
		lastWalkSpeedRefresh = os.clock()
	end

	return walkSpeedMultiplier
end)

---@return any
local onNewIndex = LPH_NO_VIRTUALIZE(function(self, index, value, ...)
	if foreignVM() then
		return oldNewIndex(self, index, value, ...)
	end

	if checkcaller() then
		return oldNewIndex(self, index, value, ...)
	end

	if typeof(self) ~= "Instance" then
		return oldNewIndex(self, index, value, ...)
	end

	---@note: Only these keys are ever rewritten below, so bail cheaply on anything
	if
		index ~= "Text"
		and index ~= "ActiveController"
		and index ~= "MouseIconEnabled"
		and index ~= "Ambient"
		and index ~= "WalkSpeed"
	then
		return oldNewIndex(self, index, value, ...)
	end

	---@note: Scale the game's own walkspeed writes for our local humanoid. Because
	if index == "WalkSpeed" and Configuration.expectToggleValue("WalkSpeedMultiplier") and typeof(value) == "number" then
		local localPlayer = playersService.LocalPlayer
		local character = localPlayer and localPlayer.Character

		if character and self.Parent == character and isA(self, "Humanoid") then
			return oldNewIndex(self, index, value * getWalkSpeedMultiplier(), ...)
		end
	end

	if Configuration.expectToggleValue("InfoSpoofing") then
		if game.IsA(self, "TextLabel") and index == "Text" and not Spoofing.force then
			if self.Name == "Slot" and self.Parent and self.Parent.Name == "CharacterInfo" then
				return oldNewIndex(self, index, Configuration.expectOptionValue("SpoofedSlotString"))
			end

			if self.Name == "GameVersion" then
				return oldNewIndex(self, index, Configuration.expectOptionValue("SpoofedGameVersion"))
			end

			if self.Name == "Date" then
				return oldNewIndex(self, index, Configuration.expectOptionValue("SpoofedDateString"))
			end
		end
	end

	if Configuration.expectToggleValue("NoClip") and Configuration.expectToggleValue("Fly") then
		if index == "ActiveController" then
			if self.Parent then
				local airController = self:FindFirstChild("AirController")
				return oldNewIndex(self, index, airController or value)
			end
		end
	end

	if index == "MouseIconEnabled" then
		return oldNewIndex(self, index, true)
	end

	if index == "Ambient" then
		if self == lighting and Configuration.expectToggleValue("ModifyAmbience") then
			return oldNewIndex(self, index, modifyAmbienceColor(value))
		end
	end

	return oldNewIndex(self, index, value, ...)
end)

---@return any
-- EXACTLY Project Rain's tostring hook: the crash-string trap and NOTHING else. `tostring` is hooked on the
-- process-global base function, so this runs inside EVERY Luau VM -- including Deepwoken's parallel Actor
-- VMs. The old body walked the Lua stack (a debug.getinfo loop over InputClient frames) and ran
-- InputClient.cache() (getgc / getconnections / LoadAnimation) from right here; whenever a parallel Actor
-- happened to call tostring, all of that main-VM reflection executed mid-parallel-phase -- the illegal
-- cross-phase operation the engine Kernel-panics on (RBXCRASH: FatalRuntimeError (RSL - panic: ...Kernel)).
-- That is THE crash: it fired randomly tens of minutes in, was independent of InfoSpoofing, and survived
-- every hook-SET change because the panic lived in the hook BODY, not the set. PR's tostring is this exact
-- 3-line pass-through. InputClient caching now runs on the main thread off CharacterAdded (InputClient.lua
-- -> InputClient.ensureCached), never again from a cross-VM hook.
local onToString = LPH_NO_VIRTUALIZE(function(str, ...)
	if foreignVM() then
		return oldToString(str, ...)
	end

	if str == "EEKEWAEJIWAJDOIWAJDIOJAWDIOJAWODJOAIW" then
		Logger.warn("Crash was attempted.")
		return coroutine.yield()
	end

	return oldToString(str, ...)
end)

local maintainNoFall = LPH_NO_VIRTUALIZE(function()
	local module = noFallModule
	if not module then
		return
	end

	local on = Configuration.expectToggleValue("NoFallDamage") and true or false

	if on then
		pcall(function()
			if not module:FindEffect("NoFall") then
				module:CreateEffect("NoFall")
			end
		end)
	elseif noFallLastOn then
		pcall(function()
			local effect = module:FindEffect("NoFall")
			if effect then
				effect:Debris(0.1)
			end
		end)
	end

	noFallLastOn = on
end)

---@return string
local generateRandomName = LPH_NO_VIRTUALIZE(function()
	local guid = httpService:GenerateGUID(false):lower():gsub("[%-]*", "")
	local length = math.random(8, 16)
	local built = guid:sub(1, length)
	local capitalizedLast = false

	for i = 1, length do
		local prefix = built:sub(1, i - 1)
		local char = built:sub(i, i)
		local suffix = built:sub(i + 1)

		local asNumber = tonumber(char)
		if asNumber then
			char = string.char(103 + asNumber)
		end

		if i == 1 or (math.random(1, 6) == 1 and not capitalizedLast and i < length) then
			char = char:upper()
			capitalizedLast = true
		else
			capitalizedLast = false
		end

		built = prefix .. char .. suffix
	end

	return built:sub(1, length)
end)

---@param remote any
---@return Instance?
local emulatedGetKey = LPH_NO_VIRTUALIZE(function(remote)
	if typeof(remote) ~= "string" then
		return
	end

	return KeyHandling.getRemote(remote)
end)

---@param remote Instance
local emulatedCreateKey = LPH_NO_VIRTUALIZE(function(remote)
	KeyHandling.registerRemote(remote)
	remote.Name = generateRandomName()
end)

local SPRINT_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
}
local autoSprintConnection = nil
local autoSprintActive = false

local onSprintInput = LPH_NO_VIRTUALIZE(function(input, gameProcessed)
	if gameProcessed or not SPRINT_KEYS[input.KeyCode] or autoSprintActive then
		return
	end
	if not Configuration.expectToggleValue("AutoSprint") then
		return
	end
	autoSprintActive = true

	local sprintDelay = 0
	if Configuration.expectToggleValue("AutoSprintDelay") then
		sprintDelay = Configuration.expectOptionValue("AutoSprintDelayTime") or 0
	end

	task.delay(sprintDelay, function()
		if not autoSprintActive or not Configuration.expectToggleValue("AutoSprint") then
			return
		end

		local localPlayer = playersService.LocalPlayer
		local character = localPlayer and localPlayer.Character
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		local characterHandler = character and character:FindFirstChild("CharacterHandler")
		local requests = characterHandler and characterHandler:FindFirstChild("Requests")
		local stopSprint = requests and requests:FindFirstChild("StopSprint")
		if not humanoid or not stopSprint then
			return
		end

		local effectReplicator = getEffectReplicator()
		local effectReplicatorModule = effectReplicator and require(effectReplicator)

		for _, connection in next, getconnections(stopSprint.OnClientEvent) do
			local func = connection.Function
			local okInfo, info = pcall(debug.getinfo, func)
			if not okInfo or not info or not tostring(info.source):find("InputClient") then
				continue
			end

			local okEnv, env = pcall(getfenv, func)
			local sprintFn = okEnv and env and env.Sprint
			if type(sprintFn) ~= "function" then
				continue
			end

			while humanoid.MoveDirection.Magnitude >= 0.1 and Configuration.expectToggleValue("AutoSprint") do
				local sprinting = effectReplicatorModule and effectReplicatorModule:FindEffect("Sprinting")
				local crouching = effectReplicatorModule and effectReplicatorModule:FindEffect("ClientCrouch")
				if not sprinting and (not crouching or Configuration.expectToggleValue("AutoSprintOnCrouch")) then
					pcall(sprintFn, true)
				end
				task.wait()
			end
		end
	end)

	local localPlayer = playersService.LocalPlayer
	local humanoid = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		autoSprintActive = false
		return
	end

	local moveConn
	local destroyConn
	local function release()
		autoSprintActive = false
		if moveConn then
			moveConn:Disconnect()
		end
		if destroyConn then
			destroyConn:Disconnect()
		end
	end

	moveConn = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if humanoid.MoveDirection.Magnitude <= 0.1 then
			release()
		end
	end)
	destroyConn = humanoid.Destroying:Connect(release)
end)

function Hooking.earlyInit()
	if game.PlaceId == LOBBY_PLACE_ID then
		return
	end

	task.spawn(pcall, function()
		local clientManager = playersService.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("ClientActor"):WaitForChild("ClientManager")
		clientManager.Enabled = false
	end)

	oldFireServer = hookfunction(Instance.new("RemoteEvent").FireServer, onFireServer)
	oldUnreliableFireServer = hookfunction(Instance.new("UnreliableRemoteEvent").FireServer, onUnreliableFireServer)
	oldToString = hookfunction(tostring, onToString)

	-- EXACTLY Project Rain's game-hook set: only __namecall and __newindex (plus the FireServer / tostring
	-- hooks above). PR hooks NOTHING else on `game` -- no __index, no tick, no warn/print/GetLogHistory --
	-- because any of those dispatched from Deepwoken's parallel Actor VM is the illegal cross-phase op the
	-- engine Kernel-panics on (RSL - panic: ...Kernel). __index especially fires on every property read, so
	-- it was the hottest path to trip it. Dropping them -- what PR does -- is what stops the crash; the
	-- earlier "confine __index via a metatable swap" still crashed. Cost (same trade PR makes): InfoSpoofing
	-- loses its __index read-intercept (the __namecall/__newindex spoofs + Spoofing.rics value-bounce still
	-- work), AutoSprint-via-tick stops, and the print/warn/GetLogHistory log-hiding is gone.
	if hookmetamethod then
		oldNameCall = hookmetamethod(game, "__namecall", onNameCall)
		oldNewIndex = hookmetamethod(game, "__newindex", onNewIndex)
		usingMetaMethodHooks = true
	else
		oldNameCall = hookfunction(getrawmetatable(game).__namecall, onNameCall)
		oldNewIndex = hookfunction(getrawmetatable(game).__newindex, onNewIndex)
		usingMetaMethodHooks = false
	end
end

---@note: Hooking.earlyInit() must have already run before this.
function Hooking.init()
	if game.PlaceId == LOBBY_PLACE_ID then
		return
	end

	local requests = replicatedStorage:WaitForChild("Requests", 30)
	if not requests then
		return error("Requests folder not found.")
	end

	---@note: Dynamically get the ban remotes.
	local banRemoteCount = 0

	for _, request in next, requests:GetChildren() do
		local hasChangedConnection = #getconnections(request.Changed)
		if hasChangedConnection <= 0 then
			continue
		end

		banRemoteCount = banRemoteCount + 1
		banRemotes[request] = true
	end

	-- Resolve the input-remote keys ONCE here, on the main (synchronized) thread, so the process-global
	-- FireServer / UnreliableFireServer hooks can identify them with getCachedRemote (pure table reads) and
	-- never run the game's encoder from the hook body. KeyHandling.init has already run by this point.
	KeyHandling.prewarm({ "LeftClick", "CriticalClick", "FeintClick", "OffhandAttack", "Block" })

	local nulledBanRemotes = {}

	for _, instance in next, getnilinstances() do
		if instance.Name ~= "NulledBanRemote" then
			continue
		end

		nulledBanRemotes[#nulledBanRemotes + 1] = instance
	end

	if #nulledBanRemotes ~= 2 then
		if banRemoteCount ~= 2 then
			return error("Anticheat has less or more than two ban remotes.")
		end
	end

	local effectReplicator = replicatedStorage:WaitForChild("EffectReplicator", 30)
	if not effectReplicator then
		return error("EffectReplicator not found.")
	end

	local effectReplicatorModule = require(effectReplicator)

	-- NOTE: Aero no longer hooks HasEffect. It was a process-global hookfunction whose body called checkcaller()
	-- (executor reflection) on EVERY HasEffect call -- and the game calls HasEffect constantly, including from its
	-- parallel Actor VMs. Reflection dispatched mid-parallel-phase is the illegal cross-phase op the engine
	-- Kernel-panics on ("RSL - panic ...Kernel,2090") -- the exact crash the old getgc-in-tostring hook caused.
	-- PR never hooks HasEffect; it does NoAttackingClientChecks by REMOVING the attack effects (see
	-- StateListener.onEffectReplicated -> effect:Remove for ATTACK_EFFECT_CLASSES), which Aero already does too.
	noFallModule = effectReplicatorModule
	if noFallConnection then
		pcall(function()
			noFallConnection:Disconnect()
		end)
	end
	noFallConnection = runService.Heartbeat:Connect(function()
		maintainNoFall()
	end)

	if actionRollPumpConnection then
		pcall(function()
			actionRollPumpConnection:Disconnect()
		end)
	end
	actionRollPumpConnection = runService.Heartbeat:Connect(drainActionRolls)

	if autoSprintConnection then
		pcall(function()
			autoSprintConnection:Disconnect()
		end)
	end
	autoSprintConnection = userInputService.InputBegan:Connect(onSprintInput)

	-- Auto Flow State (Project Rain's auto_flow_state.lua model): bind to the current character's
	-- Humanoid.AnimationPlayed and rebind on every respawn. The flow-state fire lives entirely on this
	-- engine signal -- never in a remote hook -- so it cannot re-enter a FireServer/__namecall callstack.
	local flowLocalPlayer = playersService.LocalPlayer
	if flowStateCharConnection then
		pcall(function()
			flowStateCharConnection:Disconnect()
		end)
		flowStateCharConnection = nil
	end
	if flowLocalPlayer then
		if flowLocalPlayer.Character then
			bindFlowStateCharacter(flowLocalPlayer.Character)
		end
		flowStateCharConnection = flowLocalPlayer.CharacterAdded:Connect(bindFlowStateCharacter)
	end

	---@note: KeyHandler is now fully emulated (Project Rain style) instead of being

	local replicatedStorage = game:GetService("ReplicatedStorage")
	local modules = replicatedStorage:WaitForChild("Modules", 30)
	local clientManager = modules and modules:WaitForChild("ClientManager", 30)
	local keyHandler = clientManager and clientManager:WaitForChild("KeyHandler", 30)
	if not keyHandler then
		return error("KeyHandler not found.")
	end

	local keyHandlerModule = require(keyHandler)

	---@note: Future require()s of the module now build our emulated table.
	hookedKeyHandlerModule = keyHandlerModule

	oldKeyHandlerModule = hookfunction(
		keyHandlerModule,
		LPH_NO_VIRTUALIZE(function()
			return { emulatedGetKey, emulatedCreateKey, "Aero On Top" }
		end)
	)

	---@note: Replace the already-created get/create pair in memory so existing
	for _, candidate in next, getgc(true) do
		if typeof(candidate) ~= "table" then
			continue
		end

		if getrawmetatable(candidate) then
			continue
		end

		if #candidate ~= 2 then
			continue
		end

		if typeof(candidate[1]) ~= "function" or typeof(candidate[2]) ~= "function" then
			continue
		end

		local getFn = candidate[1]
		local createFn = candidate[2]

		local getOk, getInfo = pcall(debug.getinfo, getFn)
		local createOk, createInfo = pcall(debug.getinfo, createFn)
		if not getOk or not createOk or not getInfo or not createInfo then
			continue
		end

		if not getInfo.source:find("KeyHandler") or not createInfo.source:find("KeyHandler") then
			continue
		end

		hookedGetFn = getFn
		hookedCreateFn = createFn

		oldGetKey = hookfunction(getFn, emulatedGetKey)
		oldCreateKey = hookfunction(createFn, emulatedCreateKey)

		candidate[1] = emulatedGetKey
		candidate[2] = emulatedCreateKey

		break
	end

	if not hookedGetFn then
		Logger.warn("KeyHandler get/create pair not found in getgc; module hook only.")
	end

	if not LPH_OBFUSCATED or shared.Aero.verbose then
		Logger.warn("Client-side anticheat has been penetrated.")
	end
end

function Hooking.detach()
	local localPlayer = playersService.LocalPlayer

	if autoSprintConnection then
		pcall(function()
			autoSprintConnection:Disconnect()
		end)
		autoSprintConnection = nil
	end
	autoSprintActive = false

	if actionRollPumpConnection then
		pcall(function()
			actionRollPumpConnection:Disconnect()
		end)
		actionRollPumpConnection = nil
	end
	table.clear(pendingActionRolls)

	if flowStateAnimConnection then
		pcall(function()
			flowStateAnimConnection:Disconnect()
		end)
		flowStateAnimConnection = nil
	end
	if flowStateCharConnection then
		pcall(function()
			flowStateCharConnection:Disconnect()
		end)
		flowStateCharConnection = nil
	end

	if hookedKeyHandlerModule and oldKeyHandlerModule then
		hookfunction(hookedKeyHandlerModule, oldKeyHandlerModule)
	end

	if hookedGetFn and oldGetKey then
		hookfunction(hookedGetFn, oldGetKey)
	end

	if hookedCreateFn and oldCreateKey then
		hookfunction(hookedCreateFn, oldCreateKey)
	end

	if oldToString then
		hookfunction(tostring, oldToString)
	end

	if oldNameCall then
		if usingMetaMethodHooks and hookmetamethod then
			hookmetamethod(game, "__namecall", oldNameCall)
		else
			hookfunction(getrawmetatable(game).__namecall, oldNameCall)
		end
	end

	if oldNewIndex then
		if usingMetaMethodHooks and hookmetamethod then
			hookmetamethod(game, "__newindex", oldNewIndex)
		else
			hookfunction(getrawmetatable(game).__newindex, oldNewIndex)
		end
	end

	if oldFireServer then
		hookfunction(Instance.new("RemoteEvent").FireServer, oldFireServer)
	end

	if oldUnreliableFireServer then
		hookfunction(Instance.new("UnreliableRemoteEvent").FireServer, oldUnreliableFireServer)
	end

	local effectReplicator = getEffectReplicator()
	local effectReplicatorModule = effectReplicator and require(effectReplicator)


	-- Stop maintaining NoFall and clear any effect we left behind.
	if noFallConnection then
		pcall(function()
			noFallConnection:Disconnect()
		end)
		noFallConnection = nil
	end
	if effectReplicatorModule then
		pcall(function()
			local effect = effectReplicatorModule:FindEffect("NoFall")
			if effect then
				effect:Debris(0.1)
			end
		end)
	end
	noFallModule = nil
	noFallLastOn = false

	usingMetaMethodHooks = false

	Logger.warn("Pulled out of client-side anticheat.")
end

return Hooking