---@note: Unified EffectReplicator handler -- the whole script's SINGLE connection to the game's EffectReplicator,
---@note: mirroring Project Rain's EffectReplicatorHandler. Consumers register "added"/"removed" hooks via
---@note: EffectDispatcher.hook(...) instead of each opening its own EffectAdded connection.
---@note:
---@note: Added hooks run INLINE (plain xpcall) -- no task.spawn, no task.defer, no setthreadidentity. Both
---@note: scheduler primitives were tried here and both crashed: spawning/deferring a thread from inside the
---@note: deferred-lane scheduler step the game fires EffectAdded from can enter a second guarded job under
---@note: Roblox's 0.742+ STM scheduler and trip its per-thread re-entrancy guard ("RSL - panic ...Kernel,2090").
---@note: Running inline touches the scheduler not at all. Removed hooks already run inline. The whole connection
---@note: is rebuilt when the server clears/rebuilds its effect container
---@note: (Requests.EffectReplication._update "clear"/"updatecontainer"), so nothing ever rides a stale container.

local EffectDispatcher = {}

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Logger
local Logger = require("Utility/Logger")

local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local hooks = {}
local reconnectCallbacks = {}
local pendingReactions = {} -- reactions handed over by hook bodies via EffectDispatcher.defer, drained on Heartbeat
local effectMaid = Maid.new() -- EffectAdded/EffectRemoved connections -- torn down and rebuilt on reconnect
local lifecycleMaid = Maid.new() -- the _update reconnect listener -- set up once
local reactionPumpConnection = nil -- Heartbeat drain for pendingReactions -- set up once in init
local connected = false

---@param err string
local function onHookError(err)
	Logger.trace("EffectDispatcher_HookError - %s", err)
end

-- Reaction offloading. Added/removed hooks run INLINE on the game's deferred-lane EffectAdded/EffectRemoved
-- dispatch thread (see header note). A hook body must therefore do ONLY cheap, scheduler-free work on that
-- callstack -- any remote fire, task.wait or follow-up spawn done there can nest a second guarded STM job and trip
-- Roblox 0.742+'s per-thread re-entrancy guard (RSL panic Kernel,2090). When a hook needs to DO such a thing it
-- hands a closure to EffectDispatcher.defer, which only appends to a table (zero scheduler touch); the Heartbeat
-- pump below runs it on its OWN top-level scheduler step -- a fresh scheduler entry, never nested inside the
-- dispatch -- where firing/yielding is safe (the same place Hooking.maintainNoFall already fires remotes). Each
-- reaction runs on its own task.spawn'd thread so one that yields (e.g. a wait-loop) can't block the others;
-- task.spawn is safe HERE precisely because this is NOT a hook callstack -- it is the Heartbeat job itself.
---@param fn fun()
function EffectDispatcher.defer(fn)
	pendingReactions[#pendingReactions + 1] = fn
end

local function drainReactions()
	if #pendingReactions == 0 then
		return
	end
	local batch = pendingReactions
	pendingReactions = {}
	for _, fn in next, batch do
		task.spawn(pcall, fn)
	end
end

-- Disconnect helper for both real RBXScriptConnections and Deepwoken's custom EffectReplicator signal connections
-- (EffectAdded/EffectRemoved are NOT RBXScriptSignals -- their connections are tables/functions Maid won't clean on
-- its own). Wrapping it in a cleanup function makes a reconnect actually drop the old handler, no duplicates.
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

---Register an effect hook.
---@param hookType string "added" | "removed"
---@param callback fun(effect: table)
---@return table hook  -- call hook:remove() to unregister
function EffectDispatcher.hook(hookType, callback)
	local hook = { type = hookType, call = callback }

	function hook:remove()
		local at = table.find(hooks, self)
		if at then
			table.remove(hooks, at)
		end
	end

	table.insert(hooks, hook)
	return hook
end

---Run callback (serial, pcall-guarded) on every (re)connect, before existing effects are replayed. Used for
---state that must be wiped when the server rebuilds its container (e.g. EffectTimers.clear).
---@param callback fun()
function EffectDispatcher.onReconnect(callback)
	table.insert(reconnectCallbacks, callback)
end

---@return table effectReplicatorModule
function EffectDispatcher.module()
	return require(replicatedStorage:WaitForChild("EffectReplicator"))
end

---@param effect table
local function dispatchAdded(effect)
	-- Run each added hook INLINE -- no task.spawn, no task.defer, no setthreadidentity. Both scheduler primitives
	-- (spawn AND defer) have been tried here and BOTH crashed: they register/resume a thread with the task
	-- scheduler, and doing that from inside the deferred-lane scheduler step the game fires EffectAdded from is a
	-- candidate for entering a second guarded STM job (Roblox 0.742+ per-thread re-entrancy guard -> RSL panic
	-- Kernel,2090). So we don't touch the scheduler at all: a plain xpcall runs hook.call directly on the thread
	-- the game's own Signal already handed us, with per-hook error isolation but zero new threads. hook.call
	-- (EffectTimers.track + StateListener.onEffectReplicated) never yields on the always-on path -- its reactive
	-- branches defer their own work -- so running inline cannot stall the dispatch.
	for _, hook in next, hooks do
		if hook.type == "added" and hook.call then
			xpcall(hook.call, onHookError, effect)
		end
	end
end

---@param effect table
local function dispatchRemoved(effect)
	for _, hook in next, hooks do
		if hook.type == "removed" and hook.call then
			xpcall(hook.call, onHookError, effect)
		end
	end
end

local function connect()
	effectMaid:clean()

	for _, callback in next, reconnectCallbacks do
		pcall(callback)
	end

	local effectReplicatorModule = EffectDispatcher.module()

	markConnection(effectMaid, effectReplicatorModule.EffectAdded:Connect(dispatchAdded))
	markConnection(effectMaid, effectReplicatorModule.EffectRemoved:Connect(dispatchRemoved))

	-- No replay of already-active effects. Project Rain's EffectReplicatorHandler only wires EffectAdded/
	-- EffectRemoved and never re-dispatches EffectReplicator.Effects on (re)connect -- it takes the inject-time
	-- gap instead of running a synchronous burst of every added hook over every live effect inside connect()
	-- (which, on an _update "clear"/"updatecontainer", fires inline within that OnClientEvent callback). Match it.
end

---Connect (replaying current effects to all registered hooks) and wire the container-rebuild reconnect. Call
---ONCE, after every always-on consumer has registered its hooks.
function EffectDispatcher.init()
	connect()

	if connected then
		return
	end
	connected = true

	if not reactionPumpConnection then
		reactionPumpConnection = runService.Heartbeat:Connect(drainReactions)
	end

	task.spawn(pcall, function()
		local update = replicatedStorage
			:WaitForChild("Requests")
			:WaitForChild("EffectReplication")
			:WaitForChild("_update")

		lifecycleMaid:mark(update.OnClientEvent:Connect(function(payload)
			if type(payload) == "table" and (payload.updateType == "clear" or payload.updateType == "updatecontainer") then
				connect()
			end
		end))
	end)
end

function EffectDispatcher.detach()
	effectMaid:clean()
	lifecycleMaid:clean()
	if reactionPumpConnection then
		pcall(function()
			reactionPumpConnection:Disconnect()
		end)
		reactionPumpConnection = nil
	end
	table.clear(hooks)
	table.clear(reconnectCallbacks)
	table.clear(pendingReactions)
	connected = false
end

return EffectDispatcher
