local PlayerScanning = {
	scanQueue = {},
	scanDataCache = {},
	friendCache = {},
	waitingForLoad = {},
	readyList = {},
	scanning = false,
}

---@module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Game.ModeratorMap
local ModeratorMap = require("Game/ModeratorMap")

local STAFF_GROUP_ID = 5212858

local players = game:GetService("Players")
local collectionService = game:GetService("CollectionService")
local runService = game:GetService("RunService")

local moderatorSound = CoreGuiManager.imark(Instance.new("Sound"))

local playerScanningMaid = Maid.new()

local lastCheckedTimestamp = os.clock()
local lastPlayerScanTimestamp = os.clock()

local seenTools = {}

local function fetchName(player)
	local spoofName = Configuration.expectToggleValue("InfoSpoofing")
		and Configuration.expectToggleValue("SpoofOtherPlayers")

	return spoofName and "[REDACTED]"
		or string.format("(%s) %s", player:GetAttribute("CharacterName") or "Unknown Character Name", player.Name)
end

---@param list table<string, any>
---@param value string
---@return string?
local partialStringFind = LPH_NO_VIRTUALIZE(function(list, value)
	for _, str in next, list do
		if not value:match(str) then
			continue
		end

		return str
	end

	return nil
end)

local function checkInventoriesForTools()
	for _, player in next, players:GetPlayers() do
		if not Configuration.expectToggleValue("NotifyItems") then
			continue
		end

		if player == players.LocalPlayer then
			continue
		end

		local backpack = player:FindFirstChild("Backpack")
		if not backpack then
			continue
		end

		local notifyItemsList = Options.NotifyItemsList and Options.NotifyItemsList.Values
		if not notifyItemsList then
			continue
		end

		for _, tool in next, backpack:GetChildren() do
			if seenTools[tool] then
				continue
			end

			local itemName = tool:GetAttribute("ItemName")
			if typeof(itemName) ~= "string" or itemName == "" then
				continue
			end

			local matchedString = partialStringFind(notifyItemsList, itemName)
			if not matchedString then
				continue
			end

			seenTools[tool] = matchedString

			Logger.longNotify("%s has item '%s' in their inventory.", fetchName(player), itemName)
		end

		for tool, matched in next, seenTools do
			if table.find(notifyItemsList, matched) then
				continue
			end

			seenTools[tool] = nil
		end
	end

	lastCheckedTimestamp = os.clock()
end

local runPlayerScans = LPH_NO_VIRTUALIZE(function()
	local localPlayer = players.LocalPlayer
	if not localPlayer then
		return
	end

	for player, _ in next, PlayerScanning.scanQueue do
		if shared.Aero.dpscanning then
			continue
		end

		if not PlayerScanning.scanDataCache[player] then
			local handledSuccess, handledResult = nil, nil

			local unhandledSuccess, unhandledResult = pcall(function()
				handledSuccess, handledResult = PlayerScanning.getStaffRank(player)
			end)

			if not unhandledSuccess then
				Logger.warn(
					"Scan player %s ran into error '%s' while getting staff rank.",
					player.Name,
					unhandledResult
				)

				Logger.mnnotify("Failed to scan player %s for moderator status.", fetchName(player), unhandledResult)

				PlayerScanning.scanQueue[player] = nil

				continue
			end

			if not handledSuccess then
				continue
			end

			if Configuration.expectToggleValue("NotifyMod") and handledResult then
				Logger.mnnotify("%s is a staff member with the rank '%s' in group.", fetchName(player), handledResult)

				if Configuration.expectToggleValue("NotifyModSound") then
					moderatorSound.SoundId = "rbxassetid://6045346303"
					moderatorSound.PlaybackSpeed = 1
					moderatorSound.Volume = Configuration.expectToggleValue("NotifyModSoundVolume") or 10
					moderatorSound:Play()
				end
			end

			PlayerScanning.scanDataCache[player] = { staffRank = handledResult }
		end

		local backpack = player:FindFirstChild("Backpack")
		if not backpack then
			return
		end

		if not collectionService:HasTag(backpack, "Loaded") or #backpack:GetChildren() < 1 then
			if not PlayerScanning.waitingForLoad[player] then
				Logger.warn("Player scanning is waiting for %s to load in the game.", fetchName(player))
			end

			PlayerScanning.waitingForLoad[player] = true

			continue
		end

		if
			Configuration.expectToggleValue("NotifyVoidWalker")
			and backpack:FindFirstChild("Talent:Voidwalker Contract")
		then
			Logger.longNotify("%s has the Voidwalker Contract talent.", fetchName(player))
		end

		PlayerScanning.scanQueue[player] = nil

		PlayerScanning.friendCache[player] = localPlayer:GetFriendStatus(player) == Enum.FriendStatus.Friend

		Logger.warn("Player scanning finished scanning %s in queue.", fetchName(player))
	end
end)

---@return table
function PlayerScanning.hasModerators()
	for _, scanData in next, PlayerScanning.scanDataCache do
		if not scanData.staffRank then
			continue
		end

		return true
	end

	return false
end

---@param player Player
---@return boolean
function PlayerScanning.isAlly(player)
	---@note: bruh we can call ReputationSystem
	local localPlayerGuild = players.LocalPlayer:GetAttribute("Guild")
	local usernameList = Options["UsernameList"]

	if usernameList then
		local displayNameFound = player and table.find(usernameList.Values, player.DisplayName)
		local usernameFound = player and table.find(usernameList.Values, player.Name)

		if displayNameFound or usernameFound then
			return true
		end
	end

	return PlayerScanning.friendCache[player]
		or ((localPlayerGuild and #localPlayerGuild >= 1) and player:GetAttribute("Guild") == localPlayerGuild)
end

---@param player Player
---@return boolean, string?
function PlayerScanning.getStaffRank(player)
	local mapped = ModeratorMap[player.UserId]
	if mapped then
		return true, mapped
	end

	local rankSuccess, rank = pcall(player.GetRankInGroup, player, STAFF_GROUP_ID)
	if not rankSuccess then
		return false, rank
	end

	if typeof(rank) ~= "number" or rank <= 0 then
		return true, nil
	end

	local roleSuccess, role = pcall(player.GetRoleInGroup, player, STAFF_GROUP_ID)
	if not roleSuccess or typeof(role) ~= "string" then
		return true, "Staff"
	end

	return true, role
end

---@note: Request will yield - so we need a debounce to prevent multiple scan loops.
---@note: We must defer the error back to the caller and reset the scanning debounce so errors will not break the scanning loop.
function PlayerScanning.update()
	if os.clock() - lastCheckedTimestamp >= 5.0 then
		checkInventoriesForTools()
	end

	if os.clock() - lastPlayerScanTimestamp <= 1.0 then
		return
	end

	lastPlayerScanTimestamp = os.clock()

	if PlayerScanning.scanning then
		return
	end

	PlayerScanning.scanning = true

	local success, result = pcall(runPlayerScans)

	PlayerScanning.scanning = false

	if success then
		return
	end

	return error(result)
end

---@param player Player
---@param status Enum.FriendStatus
function PlayerScanning.friend(player, status)
	PlayerScanning.friendCache[player] = status == Enum.FriendStatus.Friend
end

---@param player Player
function PlayerScanning.onPlayerAdded(player)
	if player == players.LocalPlayer then
		return
	end

	PlayerScanning.scanQueue[player] = true
end

---@param player Player
function PlayerScanning.onPlayerRemoving(player)
	PlayerScanning.scanQueue[player] = nil
	PlayerScanning.scanDataCache[player] = nil
	PlayerScanning.friendCache[player] = nil
	PlayerScanning.waitingForLoad[player] = nil
end

function PlayerScanning.init()
	local playerAddedSignal = Signal.new(players.PlayerAdded)
	local playerRemovingSignal = Signal.new(players.PlayerRemoving)
	local renderSteppedSignal = Signal.new(runService.RenderStepped)
	local friendStatusChanged = Signal.new(players.LocalPlayer.FriendStatusChanged)

	playerScanningMaid:add(friendStatusChanged:connect("PlayerScanning_OnFriendStatusChanged", PlayerScanning.friend))
	playerScanningMaid:add(renderSteppedSignal:connect("PlayerScanning_Update", PlayerScanning.update))
	playerScanningMaid:add(playerAddedSignal:connect("PlayerScanning_OnPlayerAdded", PlayerScanning.onPlayerAdded))
	playerScanningMaid:add(
		playerRemovingSignal:connect("PlayerScanning_OnPlayerRemoving", PlayerScanning.onPlayerRemoving)
	)

	for _, player in next, players:GetPlayers() do
		PlayerScanning.onPlayerAdded(player)
	end
end

function PlayerScanning.detach()
	playerScanningMaid:clean()
end

return PlayerScanning
