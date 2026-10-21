---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Utility.Logger
local Logger = require("Utility/Logger")

local ServerHop = {}

local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local teleportService = game:GetService("TeleportService")
local runService = game:GetService("RunService")

local LOBBY_PLACE_ID = 4111023553
local DEBUGGING_MODE = true
local UNKNOWN_PLAYER_COUNT = 1000000000

-- If the current target server hasn't teleported us in this window, blacklist it and move to the next
-- one (full, or the instance is no longer available).
local SERVER_SWITCH_TIMEOUT = 10

local lastRetry = nil
local currentSlot = nil
local currentServerId = nil
local currentServerSince = nil

local function telemetryLog(...)
	if not DEBUGGING_MODE then
		return
	end

	Logger.warn(...)
end

---@return table
local function getBlacklist()
	local blacklist = PersistentData.get("sblacklist") or {}

	for key, value in next, blacklist do
		if tick() - value < 300 then
			continue
		end

		telemetryLog("(%s) Removed old entry (%s) from server blacklist.", tostring(key), tostring(value))

		blacklist[key] = nil
	end

	PersistentData.set("sblacklist", blacklist)

	return blacklist
end

---@param id string The server ID (JobId) to add to the blacklist.
local function addBlacklist(id)
	if not id then
		return
	end

	local blacklist = getBlacklist()

	blacklist[id] = tick()

	PersistentData.set("sblacklist", blacklist)
end

-- ============================================================================================
-- UI-driven server picking. Instead of firing PickSlot/PickServer remotes directly (which the game
-- ignored unless its own UI state was set up), we press the actual menu buttons via firesignal, so
-- the game's own handlers run -- exactly like a real player clicking them.
-- ============================================================================================

---LoadingGui.Overlay.Columns.MainFrame, or nil.
---@return Instance?
local function getMainFrame()
	local playerGui = players.LocalPlayer and players.LocalPlayer:FindFirstChild("PlayerGui")
	local loadingGui = playerGui and playerGui:FindFirstChild("LoadingGui")
	local overlay = loadingGui and loadingGui:FindFirstChild("Overlay")
	local columns = overlay and overlay:FindFirstChild("Columns")
	return columns and columns:FindFirstChild("MainFrame")
end

---Click a GUI button the way the game's own UI would (fire its click signals).
---@param button Instance?
local function pressButton(button)
	if not button then
		return
	end

	pcall(function()
		firesignal(button.MouseButton1Click)
	end)
	pcall(function()
		firesignal(button.Activated)
	end)
end

---Press the slot button (MainFrame.Slots.SlotScroll.<slot>) to select the slot and populate its
---server list.
local function pressSlot()
	local mainFrame = getMainFrame()
	local slots = mainFrame and mainFrame:FindFirstChild("Slots")
	local scroll = slots and slots:FindFirstChild("SlotScroll")
	local slotButton = scroll and currentSlot and scroll:FindFirstChild(currentSlot)
	pressButton(slotButton)
end

---Best-effort player count for a server button, parsed from its text / descendant labels. Unknown
---counts sort last so they are not mistaken for the emptiest servers.
---@param button Instance
---@return number
local function parsePlayers(button)
	local texts = {}
	local function addText(text)
		if type(text) == "string" then
			texts[#texts + 1] = text
		end
	end

	pcall(function()
		addText(button.Text)
	end)

	for _, descendant in next, button:GetDescendants() do
		if descendant:IsA("TextLabel") then
			pcall(function()
				addText(descendant.Text)
			end)
		end
	end

	for _, text in ipairs(texts) do
		local ratio = text:match("(%d+)%s*/%s*%d+") -- "12/40"
		if ratio then
			return tonumber(ratio)
		end
	end

	for _, text in ipairs(texts) do
		local count = text:match("(%d+)")
		if count then
			return tonumber(count)
		end
	end

	return UNKNOWN_PLAYER_COUNT
end

---All server buttons in MainFrame.Servers.Servers -- each is a TextButton named by its JobId.
---@return table
local function serverButtons()
	local mainFrame = getMainFrame()
	local serversFrame = mainFrame and mainFrame:FindFirstChild("Servers")
	local scroll = serversFrame and serversFrame:FindFirstChild("Servers")

	local list = {}
	if scroll then
		for _, child in next, scroll:GetChildren() do
			if child:IsA("GuiButton") then
				list[#list + 1] = { id = child.Name, button = child, players = parsePlayers(child) }
			end
		end
	end
	return list
end

---Blacklist the current target so it's never picked again, and drop it so the next tick picks a
---different server.
---@param reason string
local function advanceServer(reason)
	if currentServerId then
		telemetryLog("(%s) %s -- blacklisting and switching servers.", tostring(currentServerId), reason)
		addBlacklist(currentServerId)
	end

	currentServerId = nil
	currentServerSince = nil
end

local function updateServerHopping()
	-- Throttle to once a second.
	if lastRetry and os.clock() - lastRetry <= 1.0 then
		return
	end

	lastRetry = os.clock()

	-- No servers listed yet -- press the slot button to select it and populate the list.
	local buttons = serverButtons()
	if #buttons == 0 then
		pressSlot()
		return
	end

	-- Filter out blacklisted servers, then sort by (parsed) population.
	local blacklist = getBlacklist()
	local candidates = {}
	for _, server in ipairs(buttons) do
		if not blacklist[server.id] then
			candidates[#candidates + 1] = server
		end
	end

	if #candidates == 0 then
		-- Everything currently listed is blacklisted -- re-select the slot to refresh the list.
		pressSlot()
		return
	end

	table.sort(candidates, function(first, second)
		if first.players == second.players then
			return first.id < second.id
		end
		return first.players < second.players
	end)

	-- Drop a target that got blacklisted since we picked it.
	if currentServerId and blacklist[currentServerId] then
		currentServerId = nil
	end

	-- Pick the lowest-population non-blacklisted server.
	if not currentServerId then
		currentServerId = candidates[1].id
		currentServerSince = os.clock()
		local playerCount = candidates[1].players == UNKNOWN_PLAYER_COUNT
			and "unknown"
			or tostring(candidates[1].players)
		telemetryLog("(%s) Trying server (%s players).", tostring(currentServerId), playerCount)
	end

	-- Current target hasn't taken us in time -- blacklist it and move on.
	if currentServerSince and os.clock() - currentServerSince >= SERVER_SWITCH_TIMEOUT then
		advanceServer("Not joined in time")
		return
	end

	-- Press the current target's button to join it (re-find it each tick in case the list rebuilt).
	local target = nil
	for _, server in ipairs(candidates) do
		if server.id == currentServerId then
			target = server
			break
		end
	end

	if target then
		pressButton(target.button)
	else
		currentServerId = nil -- the button disappeared; re-pick next tick
	end
end

local function onTeleportFailure(...)
	-- A full server (or other teleport failure) -- blacklist it and switch.
	advanceServer("Teleport failed")
end

function ServerHop.lobby()
	local shslot = PersistentData.get("shslot")
	if not shslot then
		return error("No server hop slot set in PersistentData.")
	end

	currentSlot = shslot
	currentServerId = nil
	currentServerSince = nil
	lastRetry = nil

	telemetryLog("(%s) Picking a server by pressing the menu buttons.", tostring(shslot))

	teleportService.TeleportInitFailed:Connect(onTeleportFailure)

	runService.PreRender:Connect(updateServerHopping)
end

function ServerHop.rlobby()
	telemetryLog("Returning to lobby.")

	local requests = replicatedStorage:WaitForChild("Requests")
	local returnToMenu = requests:WaitForChild("ReturnToMenu")
	local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")

	while task.wait() do
		returnToMenu:FireServer()

		local prompt = playerGui:FindFirstChild("ChoicePrompt")
		local choicePrompt = prompt and prompt:FindFirstChild("Choice")

		if not choicePrompt then
			continue
		end

		choicePrompt:FireServer(true)
	end
end

---@param slot string The data slot to use.
---@param blacklist boolean If true, blacklist the current server.
function ServerHop.hop(slot, blacklist)
	PersistentData.set("shslot", slot)

	telemetryLog("(%s, %s) Hopping to new server.", tostring(slot), tostring(blacklist))

	if blacklist then
		local blacklisted = getBlacklist()
		local currentServerId = game.JobId
		if currentServerId and currentServerId ~= "" then
			blacklisted[currentServerId] = tick()
		end
		PersistentData.set("sblacklist", blacklisted)
	end

	if game.PlaceId == LOBBY_PLACE_ID then
		return ServerHop.lobby()
	end

	return ServerHop.rlobby()
end

return ServerHop
