local StateListener = {
	lMantraActivated = nil,
	lAnimTiming = nil,
	lAnimFaction = nil,
	lAnimTimestamp = nil,
	chainStacks = nil,
	lastVent = nil,
	lastPaybackDelay = 0,
	lAnimLatency = nil,

	lADAction = nil,
	lADAnimation = nil,

	lRecentAnims = {},
}

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.TaskSpawner
local TaskSpawner = require("Utility/TaskSpawner")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Game.Timings.SaveManager
local SaveManager = require("Game/Timings/SaveManager")

---@module Game.Timings.ModuleManager
local ModuleManager = require("Game/Timings/ModuleManager")

---@module Game.Latency
local Latency = require("Game/Latency")

---@module Game.EffectTimers
local EffectTimers = require("Game/EffectTimers")

---@module Game.EffectDispatcher
local EffectDispatcher = require("Game/EffectDispatcher")

---@module Utility.Table
local Table = require("Utility/Table")

local stateMaid = Maid.new()

-- Per-effect timestamps for withinTime(). Deepwoken's effect objects are owned by the game (effect.index lives
-- in the game's VM, likely an Actor), so writing a field back into effect.index from our thread is an illegal
-- cross-boundary write and the Luau kernel aborts with "RSL - panic ...Kernel,2090" (AFK: mobs spew LightAttack/
-- Stun nonstop at random timing; threads+mem stay flat so it isn't a leak). EffectTimers already demonstrates the
-- safe shape -- it listens to the same EffectAdded signal INLINE and only READS effect fields into a weak Lua
-- table -- so we keep our stamps the same way and never write into the effect object. Weak keys => entries drop
-- when the effect is GC'd, no manual cleanup, no leak.
local stamps = setmetatable({}, { __mode = "k" })

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")

local CHIME_ARENA_PLACE_ID = 6832944305

local ATTACK_EFFECT_CLASSES = {
	"LightAttack",
	"HeavyAttack",
	"OffhandAttack",
	"UsingAbility",
	"CastingSpell",
}

---@param track AnimationTrack
---@param timing AnimationTiming
local handleModuleData = LPH_NO_VIRTUALIZE(function(track, timing)
	if timing.tag ~= "M1" then
		return
	end

	if typeof(ModuleManager) ~= "table" or typeof(ModuleManager.get) ~= "function" then
		return
	end

	local lf = ModuleManager.get(timing.smod)
	if not lf then
		return
	end

	local extracted = {}
	local fake = {
		tmaid = Maid.new(),
		track = track,
		entity = players.LocalPlayer.Character,
		action = function(_, _, action)
			table.insert(extracted, action)
		end,
	}

	lf(fake, timing)

	fake.tmaid:clean()

	StateListener.lAnimFaction = extracted[1]
end)

---@param track AnimationTrack
local onLocalAnimationPlayed = LPH_NO_VIRTUALIZE(function(track)
	local aid = tostring(track.Animation.AnimationId)

	StateListener.lRecentAnims[aid] = os.clock()

	local data = SaveManager.as:index(aid)
	if not data then
		return
	end

	StateListener.lAnimTimestamp = os.clock()
	StateListener.lAnimationValidTrack = track
	StateListener.lAnimTiming = data
	StateListener.lAnimLatency = Latency.rtt()

	if data.umoa then
		return handleModuleData(track, data)
	end

	StateListener.lAnimFaction = data.actions:stack()[1]
end)

---@param effect table
---@param time number? If the number is unspecified, it will use the Debris time.
---@param offset boolean If the number is specified, should we use it as an offset from the Debris time?
---@return boolean
local withinTime = LPH_NO_VIRTUALIZE(function(effect, time, offset)
	local timestamp = stamps[effect]
	if not timestamp then
		return false
	end

	if not effect.index then
		return false
	end

	local dtime = effect.index.DebrisTime
	if not dtime then
		return false
	end

	if offset and time then
		return os.clock() - timestamp <= (dtime + time)
	end

	return os.clock() - timestamp <= (time or dtime)
end)

---@return boolean
local function getKeyCode(name)
	return Enum.KeyCode[name]
end

StateListener.hblock = LPH_NO_VIRTUALIZE(function()
	local keybinds = replicatedStorage:FindFirstChild("KeyBinds")
	if not keybinds then
		return false
	end

	local keybindsModule = require(keybinds)
	if not keybindsModule or not keybindsModule.Current then
		return false
	end

	local bindings = keybindsModule:GetBindings() or {}

	for _, keybind in next, bindings["Block"] do
		local success, keyCode = pcall(getKeyCode, tostring(keybind))

		if not success or not keyCode then
			continue
		end

		if not userInputService:IsKeyDown(keyCode) then
			continue
		end

		return true
	end

	return false
end)

---@return boolean
StateListener.csb = LPH_NO_VIRTUALIZE(function()
	if not StateListener.lMantraActivated then
		return false
	end

	local name = tostring(StateListener.lMantraActivated)
	if not name or not name:match("Sightless Beam") then
		return false
	end

	local character = players.LocalPlayer and players.LocalPlayer.Character
	if not character then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	if hrp:FindFirstChild("REP_SOUND_376107250") then
		return true
	end

	for _, child in next, hrp:GetChildren() do
		if not child:IsA("Sound") then
			continue
		end

		if child.Name ~= "Telekin" then
			continue
		end

		if not child.IsPlaying then
			continue
		end

		return true
	end

	return false
end)

---@return boolean
StateListener.astun = LPH_NO_VIRTUALIZE(function()
	local effectReplicator = replicatedStorage:WaitForChild("EffectReplicator")
	local effectReplicatorModule = require(effectReplicator)
	local lightAttackEffect = effectReplicatorModule:FindEffect("LightAttack")
	local usingCriticalEffect = effectReplicatorModule:FindEffect("UsingCritical")
	local usingSpellEffect = effectReplicatorModule:FindEffect("UsingSpell")

	if lightAttackEffect and withinTime(lightAttackEffect, 0.5, false) then
		return true
	end

	if usingCriticalEffect and withinTime(usingCriticalEffect, -0.1, true) then
		return true
	end

	if usingSpellEffect then
		return true
	end

	return false
end)

---@return boolean
StateListener.cvent = LPH_NO_VIRTUALIZE(function()
	local effectReplicator = replicatedStorage:WaitForChild("EffectReplicator")
	local effectReplicatorModule = require(effectReplicator)
	local ventCooldownEffect = effectReplicatorModule:FindEffect("NoBurst")

	if Configuration.expectToggleValue("BlockVentState") then
		return false
	end

	local character = players.LocalPlayer and players.LocalPlayer.Character
	if not character then
		return false
	end

	if StateListener.lastVent and (os.clock() - StateListener.lastVent) <= 8.0 then
		return false
	end

	local tempo = character:FindFirstChild("Tempo")
	if not tempo then
		return false
	end

	if tempo.Value < 40 then
		return false
	end

	if not effectReplicatorModule:FindEffect("Equipped") then
		return false
	end

	if ventCooldownEffect then
		return false
	end

	return true
end)

---@return boolean
StateListener.cparry = LPH_NO_VIRTUALIZE(function()
	local effectReplicator = replicatedStorage:WaitForChild("EffectReplicator")
	local effectReplicatorModule = require(effectReplicator)
	local parryCooldownEffect = effectReplicatorModule:FindEffect("ParryCool")

	if Configuration.expectToggleValue("EffectLogging") then
		local classes = {}
		for _, effect in next, effectReplicatorModule:GetEffects() do
			table.insert(classes, string.format("%s(%s)", tostring(effect.Class), tostring(effect.Value)))
		end
		table.sort(classes)
		Logger.warn("[cparry] active effects: %s", table.concat(classes, ", "))
	end

	if Configuration.expectToggleValue("BlockParryState") then
		return false
	end

	if not effectReplicatorModule:FindEffect("Equipped") then
		return false
	end

	if parryCooldownEffect then
		local remaining = EffectTimers.remaining(parryCooldownEffect)

		if Configuration.expectToggleValue("EffectLogging") then
			Logger.warn(
				"[ParryCool] DebrisTime=%s remaining=%s rdelay=%.3f sdelay=%.3f",
				tostring(parryCooldownEffect.DebrisTime),
				tostring(remaining),
				Latency.rdelay() or -1,
				Latency.sdelay() or -1
			)
		end

		if not remaining then
			return false
		end

		if remaining > (Latency.rdelay() or 0) + Latency.sdelay() then
			return false
		end
	end

	return true
end)

---@return boolean
StateListener.cfeint = LPH_NO_VIRTUALIZE(function()
	local effectReplicator = replicatedStorage:WaitForChild("EffectReplicator")
	local effectReplicatorModule = require(effectReplicator)
	local feintCooldownEffect = effectReplicatorModule:FindEffect("FeintCool")

	if feintCooldownEffect then
		return false
	end

	return true
end)

---@return boolean
StateListener.cblock = LPH_NO_VIRTUALIZE(function()
	local character = players.LocalPlayer and players.LocalPlayer.Character
	if not character then
		return false
	end

	if Configuration.expectToggleValue("NoBlockingState") then
		return false
	end

	local breakMeter = character:FindFirstChild("BreakMeter")
	if not breakMeter then
		return false
	end

	if breakMeter.Value / breakMeter.MaxValue > 0.6 then
		return false
	end

	local effectReplicator = replicatedStorage:WaitForChild("EffectReplicator")
	local effectReplicatorModule = require(effectReplicator)

	if effectReplicatorModule:FindEffect("ShakyBlock") then
		return false
	end

	if effectReplicatorModule:FindEffect("CancelBlock") then
		return false
	end

	return true
end)

---@return boolean
StateListener.cdodge = LPH_NO_VIRTUALIZE(function()
	local effectReplicator = replicatedStorage:WaitForChild("EffectReplicator")
	local effectReplicatorModule = require(effectReplicator)
	local dodgeCooldownEffect = effectReplicatorModule:FindEffect("NoRoll")
	local stunCooldownEffect = effectReplicatorModule:FindEffect("Stun")

	if Configuration.expectToggleValue("BlockDodgeState") then
		return false
	end

	if dodgeCooldownEffect then
		return false
	end

	if stunCooldownEffect and withinTime(stunCooldownEffect, nil, false) then
		return false
	end

	return true
end)

---@param aid string Animation ID (e.g. "rbxassetid://...").
---@param window number? Seconds. Defaults to 4.
---@return boolean
StateListener.recentlyCast = LPH_NO_VIRTUALIZE(function(aid, window)
	if not aid or #aid <= 0 then
		return false
	end

	local timestamp = StateListener.lRecentAnims[aid]
	if not timestamp then
		return false
	end

	return os.clock() - timestamp <= (window or 4.0)
end)

---@return boolean
StateListener.ccd = LPH_NO_VIRTUALIZE(function()
	return game.PlaceId == CHIME_ARENA_PLACE_ID and workspace.DistributedGameTime < 15
end)

---@param effect table
local onEffectReplicated = LPH_NO_VIRTUALIZE(function(effect)
	if Configuration.expectToggleValue("NoAttackingClientChecks") and table.find(ATTACK_EFFECT_CLASSES, effect.Class) then
		-- Off the dispatch callstack: EffectDispatcher.defer appends to a table here (no scheduler touch) and runs
		-- the removal on the Heartbeat pump, so effect:Remove never fires from inside the EffectAdded dispatch.
		EffectDispatcher.defer(function()
			effect:Remove(true)
		end)
	end

	if effect.Class == "Knocked" or effect.Class == "Ragdoll" then
		if Configuration.expectToggleValue("AutoRagdollRecover") then
			-- feint fires remotes -- run it on the Heartbeat pump, not synchronously on the dispatch callstack.
			EffectDispatcher.defer(InputClient.feint)
		end
	end

	if effect.Class == "MantraCasted" then
		-- Was TaskSpawner.spawn (= task.spawn) fired straight from the dispatch callstack on EVERY MantraCasted
		-- effect, toggle-checked only inside the thread -- an unconditional scheduler touch on the always-on effect
		-- path. Now we only enqueue (a table insert); the Heartbeat pump runs this body on its own thread.
		EffectDispatcher.defer(function()
			---@module Game.QueuedBlocking
			local QueuedBlocking = require("Game/QueuedBlocking")

			if not Configuration.expectToggleValue("AutoMantraFollowup") then
				return
			end

			local track = StateListener.lAnimationValidTrack
			if not track or not track.IsPlaying then
				return
			end

			local instance = StateListener.lMantraActivated
			if not instance then
				return
			end

			local faction = StateListener.lAnimFaction
			if not faction then
				return
			end

			if not instance.ToolTip:match("Press @Block@") then
				return
			end

			local effectReplicator = replicatedStorage:WaitForChild("EffectReplicator")
			local effectReplicatorModule = require(effectReplicator)

			if
				Configuration.expectToggleValue("CheckIfMoveHit")
				and not effectReplicatorModule:FindEffect("DamagedAnother")
			then
				return
			end

			QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_NORMAL, "AutoMantraFollowup", nil)

			repeat
				task.wait()
			until os.clock() - StateListener.lAnimTimestamp >= (faction:when() + 0.100) - Latency.rtt()

			QueuedBlocking.stop("AutoMantraFollowup")
		end)
	end

	if effect.Class == "LightAttack" then
		stamps[effect] = os.clock()
	end

	if effect.Class == "Stun" then
		stamps[effect] = os.clock()
	end

	if effect.Class == "DodgeCool" then
		stamps[effect] = os.clock()
	end

	if effect.Class == "ParryCool" then
		stamps[effect] = os.clock()
	end

	if effect.Class == "Vented" then
		StateListener.lastVent = os.clock()
	end

	if effect.Class == "DelayedPayback" then
		StateListener.lastPaybackDelay = tick()
	end

	if effect.Class == "PerfectStack" then
		StateListener.chainStacks = 0
	end

	if effect.Class == "PerfectionCool" and StateListener.chainStacks then
		StateListener.chainStacks = math.min(StateListener.chainStacks + 1, 20)
	end
end)

---@param effect table
local onEffectRemoving = LPH_NO_VIRTUALIZE(function(effect)
	if effect.Class == "PerfectStack" then
		StateListener.chainStacks = nil
	end
end)

-- Disconnect helper that works for both real RBXScriptConnections and Deepwoken's custom signal connections.
-- EffectReplicator.EffectAdded/EffectRemoved are NOT RBXScriptSignals, so their connections are plain tables with
-- a :Disconnect (or :disconnect/:Destroy) method that Maid won't recognise on its own -- wrap them in a cleanup
-- function (which Maid does call) so a reconnect actually drops the old handlers instead of stacking duplicates.
local function markConnection(maid, connection)
	maid:mark(function()
		pcall(function()
			if type(connection) == "function" then
				connection()
			elseif typeof(connection) == "RBXScriptConnection" then
				connection:Disconnect()
			elseif type(connection) == "table" then
				local disconnect = connection.Disconnect or connection.disconnect or connection.Destroy
				if disconnect then
					disconnect(connection)
				end
			end
		end)
	end)

	return connection
end

function StateListener.init()
	-- Effects are handled through the shared EffectDispatcher: one EffectReplicator connection for the whole
	-- script (PR-style -- deferred + identity-8 added dispatch, inline removed, rebuilt on container clear/
	-- updatecontainer). We register our hooks here; EffectDispatcher.init() (called once from Aero.init after
	-- every always-on consumer has registered) does the connect + replay. EffectTimers tracking rides these hooks.
	EffectDispatcher.onReconnect(EffectTimers.clear)

	EffectDispatcher.hook("added", function(effect)
		EffectTimers.track(effect)
		onEffectReplicated(effect)
	end)

	EffectDispatcher.hook("removed", function(effect)
		EffectTimers.untrack(effect)
		onEffectRemoving(effect)
	end)

	-- Local-character animator listening. We only ever want the LOCAL player's OWN Animator -- it drives the
	-- AnimationPlayed timings this module reads -- and it appears once per respawn. This used to watch
	-- workspace.Live.DescendantAdded: a server-wide, recursive firehose (every nested part/bone/particle/sound of
	-- every entity in the server -- hundreds-to-thousands per second in a populated place), with a per-event
	-- IsA("Animator") routed back through our own game.__namecall hook and a setthreadidentity(8)+task.spawn per
	-- Animator. That is pure waste (we discard every descendant that isn't the local Animator) and the single
	-- biggest always-on Aero-only engine interaction -- Project Rain runs nothing like it. Scope it to the local
	-- character instead, Project-Rain-style: find its Animator directly and rebind on every respawn, with the only
	-- fallback watch bounded to the local character's own descendants (tiny volume, self-terminating).
	local function bindLocalAnimator(character)
		if not character then
			return
		end

		local function tryBind()
			local animator = character:FindFirstChildWhichIsA("Animator", true)
			if not animator then
				return false
			end

			local animationPlayed = Signal.new(animator.AnimationPlayed)
			stateMaid["LocalPlayerAnimListener"] =
				animationPlayed:connect("StateListener_AnimationPlayed", onLocalAnimationPlayed)

			return true
		end

		if tryBind() then
			return
		end

		-- Animator not parented yet. Watch ONLY this character's own descendants (not the whole Live folder) until
		-- it appears, bind once, then drop the watch. Still inline -- no setthreadidentity, no task.spawn.
		local watch
		watch = character.DescendantAdded:Connect(function(descendant)
			if not descendant:IsA("Animator") then
				return
			end

			if tryBind() then
				pcall(function()
					watch:Disconnect()
				end)
			end
		end)

		stateMaid["LocalAnimatorWatch"] = function()
			pcall(function()
				watch:Disconnect()
			end)
		end
	end

	local localPlayer = players.LocalPlayer
	if localPlayer then
		bindLocalAnimator(localPlayer.Character)
		markConnection(stateMaid, localPlayer.CharacterAdded:Connect(bindLocalAnimator))
	end

	if not LPH_OBFUSCATED or shared.Aero.verbose then
		Logger.warn("StateListener initialized.")
	end
end

function StateListener.detach()
	stateMaid:clean()
	EffectTimers.detach()
end

return StateListener
