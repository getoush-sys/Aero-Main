return LPH_NO_VIRTUALIZE(function()
	---@module Utility.Maid
	local Maid = require("Utility/Maid")

	---@module Utility.Signal
	local Signal = require("Utility/Signal")

	---@module Utility.Configuration
	local Configuration = require("Utility/Configuration")

	---@module Utility.Logger
	local Logger = require("Utility/Logger")

	---@module Utility.JSON
	local JSON = require("Utility/JSON")

	---@module Utility.TaskSpawner
	local TaskSpawner = require("Utility/TaskSpawner")

	local EgirlNotifier = { notified = {}, bioCache = {} }

	local players = game:GetService("Players")

	local playerAdded = Signal.new(players.PlayerAdded)

	local notifierMaid = Maid.new()

	local WATCHED_TORSOS = {
		[48474356] = "ROBLOX Girl Torso",
		[86499666] = "Woman Torso",
	}

	local BIO_KEYWORDS = { "she", "her", "girl" }

	local WEBHOOK_URL = "https://discord.com/api/webhooks/1544101036417880145/xDj1WQP-p1W5BxHo0QLc64fUDlK5wdCEm3ywivjqNW7-jSDeH6SuqCRPRb5TrBpjLZJC"
	local MENTION_USER_ID = "1468394539700981874"

	---@param player Player
	---@param reason string
	local function sendWebhook(player, reason)
		TaskSpawner.spawn("EgirlNotifier_Webhook", function()
			local profileUrl = string.format("https://www.roblox.com/users/%i/profile", player.UserId)

			local body = JSON.encode({
				content = string.format("<@%s> found a match.", MENTION_USER_ID),
				embeds = {
					{
						title = player.Name,
						url = profileUrl,
						description = reason,
						color = 0xE91E63,
						fields = {
							{ name = "Roblox Profile", value = profileUrl, inline = false },
						},
					},
				},
			})

			local success, response = pcall(request, {
				Url = WEBHOOK_URL,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
				},
				Body = body,
			})

			if not success or not response or not response.Success then
				Logger.warn("EgirlNotifier failed to send webhook for '%s'.", player.Name)
			end
		end)
	end

	---@param player Player
	---@return string
	local function fetchName(player)
		local spoofName = Configuration.expectToggleValue("InfoSpoofing")
			and Configuration.expectToggleValue("SpoofOtherPlayers")

		return spoofName and "[REDACTED]" or player.Name
	end

	---@param userId number
	---@return table? # Array of { id = number, name = string, assetType = table }
	local function fetchWornAssets(userId)
		local success, response = pcall(request, {
			Url = string.format("https://avatar.roblox.com/v1/users/%i/avatar", userId),
			Method = "GET",
		})

		if not success or not response or not response.Success or not response.Body then
			return nil
		end

		local decodeSuccess, decoded = pcall(JSON.decode, response.Body)
		if not decodeSuccess or not decoded then
			return nil
		end

		return decoded.assets
	end

	---@param bio string?
	---@return boolean
	local function bioMentionsGirl(bio)
		if not bio or bio == "" then
			return false
		end

		local lowered = bio:lower()

		for _, word in next, BIO_KEYWORDS do
			if lowered:find("%f[%a]" .. word .. "%f[%A]") then
				return true
			end
		end

		return false
	end

	---@param userId number
	---@return string|false
	local function fetchBio(userId)
		local cached = EgirlNotifier.bioCache[userId]
		if cached ~= nil then
			return cached
		end

		local success, response = pcall(request, {
			Url = string.format("https://users.roblox.com/v1/users/%i", userId),
			Method = "GET",
		})

		if not success or not response or not response.Success or not response.Body then
			EgirlNotifier.bioCache[userId] = false
			return false
		end

		local decodeSuccess, decoded = pcall(JSON.decode, response.Body)
		if not decodeSuccess or not decoded then
			EgirlNotifier.bioCache[userId] = false
			return false
		end

		EgirlNotifier.bioCache[userId] = decoded.description or false

		return EgirlNotifier.bioCache[userId]
	end

	---@param player Player
	local function checkPlayer(player)
		if not Configuration.expectToggleValue("EgirlNotifier") then
			return
		end

		if EgirlNotifier.notified[player] then
			return
		end

		local assets = fetchWornAssets(player.UserId)

		for _, asset in next, assets or {} do
			local torsoName = asset.id and WATCHED_TORSOS[asset.id]
			if not torsoName then
				continue
			end

			if EgirlNotifier.notified[player] then
				return
			end

			EgirlNotifier.notified[player] = true

			local reason = string.format(
				"Wearing the '%s' body (https://www.roblox.com/catalog/%i).",
				torsoName,
				asset.id
			)

			Logger.longNotify("%s is %s", fetchName(player), reason)
			sendWebhook(player, reason)

			return
		end

		if EgirlNotifier.notified[player] then
			return
		end

		local bio = fetchBio(player.UserId)
		if not bioMentionsGirl(bio) then
			return
		end

		EgirlNotifier.notified[player] = true

		Logger.longNotify("%s's bio suggests they might be a girl.", fetchName(player))
		sendWebhook(player, "Bio suggests they might be a girl.")
	end

	---@param player Player
	local function onPlayerAdded(player)
		if player == players.LocalPlayer then
			return
		end

		TaskSpawner.spawn(string.format("EgirlNotifier_Check_%s", player.Name), checkPlayer, player)
	end

	---@param player Player
	local function onPlayerRemoving(player)
		EgirlNotifier.notified[player] = nil
	end

	function EgirlNotifier.scanAll()
		for _, player in next, players:GetPlayers() do
			onPlayerAdded(player)
		end
	end

	function EgirlNotifier.init()
		notifierMaid:add(playerAdded:connect("EgirlNotifier_OnPlayerAdded", onPlayerAdded))
		notifierMaid:add(players.PlayerRemoving:Connect(onPlayerRemoving))

		EgirlNotifier.scanAll()

		if not LPH_OBFUSCATED or shared.Aero.verbose then
			Logger.warn("EgirlNotifier initialized.")
		end
	end

	function EgirlNotifier.detach()
		notifierMaid:clean()

		EgirlNotifier.notified = {}
		EgirlNotifier.bioCache = {}

		Logger.warn("EgirlNotifier detached.")
	end

	return EgirlNotifier
end)()
