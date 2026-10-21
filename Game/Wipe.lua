local Wipe = {}

local LOBBY_PLACE_ID = 4111023553
local FRAGMENTS_OF_SELF_POS = Vector3.new(2910.00, 1133.03, 1474.00)

---@module Features.Game.Interactions
local Interactions = require("Features/Game/Interactions")

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Utility.Finder
local Finder = require("Utility/Finder")

---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")

---@module Utility.Logger
local Logger = require("Utility/Logger")

local DEBUGGING_MODE = true

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local function telemetryLog(...)
	if not DEBUGGING_MODE then
		return
	end

	Logger.warn(...)
end

function Wipe.pwait()
	local wdata = PersistentData.get("wdata")
	if not wdata then
		return error("No wipe data set in PersistentData.")
	end

	local startTimestamp = os.clock()

	while task.wait() do
		if os.clock() - startTimestamp >= 30 then
			return ServerHop.hop(wdata.slot, true)
		end

		if Finder.near(FRAGMENTS_OF_SELF_POS, 200) then
			break
		end
	end
end

function Wipe.pitems()
	local wdata = PersistentData.get("wdata")
	if not wdata then
		return error("No wipe data set in PersistentData.")
	end

	local npcs = workspace:WaitForChild("NPCs")
	local hippocampusPool = npcs:WaitForChild("Hippocampal Pool")

	for _, name in next, wdata.weapons do
		local weapon = Finder.weweapon(name)
		if not weapon then
			continue
		end

		Interactions.etool(weapon)

		Interactions.interact(hippocampusPool, {
			{ choice = "[Inspect]" },
			{ choice = "[Pass down item]" },
			{ exit = true },
		}, true)
	end
end

function Wipe.depths()
	-- Blow through the loading screen by spamming A while the LoadingGui is up (input-only -- the old
	-- Requests.StartMenu.Start remote is an anticheat honeypot, firing it = instant ban). The server
	-- brings us into the depths on its own.
	local function pressKey(keyCode)
		pcall(function()
			local vim = Instance.new("VirtualInputManager")
			vim:SendKeyEvent(true, keyCode, false, game)
			vim:SendKeyEvent(false, keyCode, false, game)
		end)
	end
	local loadingDeadline = os.clock() + 10
	while os.clock() < loadingDeadline do
		local pg = players.LocalPlayer and players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not (pg and pg:FindFirstChild("LoadingGui")) then
			break
		end
		pressKey(Enum.KeyCode.A)
		task.wait(0.2)
	end

	telemetryLog("(Depths) Waiting for spawn.")

	Wipe.pwait()

	telemetryLog("(Depths) Looking for anyone in the Fragments of Self area.")

	local wdata = PersistentData.get("wdata")
	if not wdata then
		return error("No wipe data set in PersistentData.")
	end

	if Finder.pnear(FRAGMENTS_OF_SELF_POS, 500) then
		return ServerHop.hop(wdata.slot, true)
	end

	Wipe.pitems()

	local npcs = workspace:WaitForChild("NPCs")
	local selfNpc = npcs:WaitForChild("Self")

	telemetryLog("(Depths) Teleporting and interacting with Self NPC.")

	repeat
		Interactions.interact(selfNpc, {
			{ choice = "[The End]" },
		}, true)

		task.wait()
	until not players.LocalPlayer.Character

	telemetryLog("(Depths) Wiped slot. Removing marker.")

	PersistentData.set("wdata", nil)

	if PersistentData.get("efdata") then
		PersistentData.stf("efdata", "wiped", true)
	end
end

function Wipe.lobby()
	telemetryLog("(Lobby) (Step 1) Wiping slot in lobby.")

	local requests = replicatedStorage:WaitForChild("Requests")
	local wipeSlot = requests:WaitForChild("WipeSlot")

	local wdata = PersistentData.get("wdata")
	if not wdata then
		return error("No wipe data set in PersistentData.")
	end

	repeat
		task.wait()
	until wipeSlot:InvokeServer(wdata.slot)

	telemetryLog("(Lobby) (Step 2) Wiped slot. Server hopping.")

	ServerHop.hop(wdata.slot, false)
end

---@param slot string The data slot to wipe.
---@param weapons string[]? Optional items to keep. Does not handle any validation.
function Wipe.invoke(slot, weapons)
	PersistentData.set("wdata", {
		slot = slot,
		weapons = weapons or {},
	})

	telemetryLog("(Invoke) (Step 1) Marked slot %s in data.", slot)

	if game.PlaceId == LOBBY_PLACE_ID then
		return Wipe.lobby()
	end

	return ServerHop.rlobby()
end

return Wipe
