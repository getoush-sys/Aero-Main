return LPH_NO_VIRTUALIZE(function()
	---@module Utility.Maid
	local Maid = require("Utility/Maid")

	---@module Utility.Signal
	local Signal = require("Utility/Signal")

	---@module Utility.Configuration
	local Configuration = require("Utility/Configuration")

	---@module Utility.OriginalStore
	local OriginalStore = require("Utility/OriginalStore")

	---@module Utility.OriginalStoreManager
	local OriginalStoreManager = require("Utility/OriginalStoreManager")

	---@module Utility.CoreGuiManager
	local CoreGuiManager = require("Utility/CoreGuiManager")

	---@module Utility.TaskSpawner
	local TaskSpawner = require("Utility/TaskSpawner")

	---@module Utility.JSON
	local JSON = require("Utility/JSON")

	---@module Utility.Logger
	local Logger = require("Utility/Logger")

	---@module Utility.Finder
	local Finder = require("Utility/Finder")

	---@module Game.LeaderboardClient
	local LeaderboardClient = require("Game/LeaderboardClient")

	local Monitoring = { subject = nil, seen = {}, proximityLastSeen = {} }

	-- A player must be out of range this long before their proximity notification is dismissed. Stops the
	-- alert re-firing when Finder.gpir briefly drops a still player (HRP streaming / range-boundary jitter).
	local PROXIMITY_GRACE = 2

	local runService = game:GetService("RunService")
	local players = game:GetService("Players")

	local renderStepped = Signal.new(runService.RenderStepped)

	local monitoringMaid = Maid.new()
	local spectateMaid = Maid.new()
	local buildStealMaid = Maid.new()
	local hairStealMaid = Maid.new()
	local plwMaid = Maid.new()

	local beepSound = CoreGuiManager.imark(Instance.new("Sound"))

	local lastUpdateTime = os.clock()

	local cameraSubject = spectateMaid:mark(OriginalStore.new())

	local showHiddenMap = spectateMaid:mark(OriginalStoreManager.new())

	local function fetchName(player)
		local spoofName = Configuration.expectToggleValue("InfoSpoofing")
			and Configuration.expectToggleValue("SpoofOtherPlayers")

		return spoofName and "[REDACTED]"
			or string.format("(%s) %s", player:GetAttribute("CharacterName") or "Unknown Character Name", player.Name)
	end

	---@param player Player
	---@param input InputObject
	local function onWhitelistingInputBegan(player, input)
		if input.KeyCode ~= Enum.KeyCode.L then
			return
		end

		local usernameList = Options["UsernameList"]
		if not usernameList then
			return
		end

		local whitelisted = usernameList.Values
		if not whitelisted then
			return
		end

		local whitelistIndex = table.find(whitelisted, player.Name)

		if whitelistIndex then
			whitelisted[whitelistIndex] = nil

			Logger.notify("Removed player '%s' from the whitelist.", fetchName(player))
		else
			whitelisted[#whitelisted + 1] = player.Name

			Logger.notify("Added player '%s' to the whitelist.", fetchName(player))
		end

		usernameList:SetValues(whitelisted)
		usernameList:SetValue({})
		usernameList:Display()
	end

	---@param player Player
	---@param input InputObject
	local function onSpectateInputBegan(player, input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local usedName = fetchName(player)

		local localPlayer = players.LocalPlayer
		if not localPlayer then
			return Logger.notify("Failed to spectate '%s' because the local player does not exist.", usedName)
		end

		local character = player.Character
		if not character then
			return Logger.notify("Failed to spectate '%s' because their character does not exist.", usedName)
		end

		local mapPosition = character:GetAttribute("MapPos")
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

		if mapPosition and not humanoidRootPart then
			spectateMaid:add(
				TaskSpawner.spawn(
					"Monitoring_RequestStreamMapPos",
					players.LocalPlayer.RequestStreamAroundAsync,
					players.LocalPlayer,
					mapPosition,
					0.1
				)
			)

			return Logger.notify("Requesting stream for unloaded character '%s' - try again later.", usedName)
		end

		if not humanoidRootPart then
			return Logger.notify("Failed to spectate '%s' because they are not loaded in.", usedName)
		end

		local shouldUpdateSubject = Monitoring.subject ~= humanoidRootPart and players.LocalPlayer ~= player

		Monitoring.subject = shouldUpdateSubject and humanoidRootPart or nil

		if shouldUpdateSubject then
			Logger.notify("Started spectating player %s.", usedName)
		else
			Logger.notify("Reset spectating camera subject.")
		end
	end

	---@param player Player
	local function onBuildStealPlayer(player)
		local character = player.Character
		if not character then
			return Logger.notify(
				"Failed to steal build from '%s' because their character does not exist.",
				fetchName(player)
			)
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return Logger.notify(
				"Failed to steal build from '%s' because their humanoid does not exist.",
				fetchName(player)
			)
		end

		local backpack = player:FindFirstChild("Backpack")
		if not backpack then
			return Logger.notify(
				"Failed to steal build from '%s' because their backpack does not exist.",
				fetchName(player)
			)
		end

		local AttributePoints = 0
		local Power = 0
		for i, v in pairs(character:GetAttributes()) do
			if i:match("Stat") then
				AttributePoints = AttributePoints + v
			end
		end
		for i = 1, 20 do
			if AttributePoints <= 15 then
				break
			end
			AttributePoints = AttributePoints - 15
			Power = Power + 1
		end
		local level = math.min(20, math.max(1, Power))

		local data = {
			version = 3,
			stats = {
				buildName = string.format("%s %s's Stolen Build", os.date("%B %d %Y"), player.Name),
				buildDescription = "Talents are not stealable anymore - this is just the opponent's stats. Preshrine will need to be solved for.",
				buildAuthor = ".gg/lyc",
				power = level,
				pointsUntilNextPower = 67,
				points = 67,
				pointSpent = 67,
				traitPoints = 0,
				traits = {
					Vitality = character:GetAttribute("Trait_Health"),
					Erudition = character:GetAttribute("Trait_Ether"),
					Songchant = character:GetAttribute("Trait_MantraDamage"),
					Proficiency = character:GetAttribute("Trait_WeaponDamage"),
				},
				meta = {
					Race = "None",
					Oath = "None",
					Murmur = "None",
					Bell = "None",
					Origin = "Castaway",
					Outfit = "None",
				},
			},
			attributes = {
				weapon = {
					["Heavy Wep."] = character:GetAttribute("Stat_WeaponHeavy"),
					["Medium Wep."] = character:GetAttribute("Stat_WeaponMedium"),
					["Light Wep."] = character:GetAttribute("Stat_WeaponLight"),
				},
				base = {
					Strength = character:GetAttribute("Stat_Strength"),
					Fortitude = character:GetAttribute("Stat_Fortitude"),
					Agility = character:GetAttribute("Stat_Agility"),
					Intelligence = character:GetAttribute("Stat_Intelligence"),
					Willpower = character:GetAttribute("Stat_Willpower"),
					Charisma = character:GetAttribute("Stat_Charisma"),
				},
				attunement = {
					Flamecharm = character:GetAttribute("Stat_ElementFire"),
					Frostdraw = character:GetAttribute("Stat_ElementIce"),
					Thundercall = character:GetAttribute("Stat_ElementLightning"),
					Galebreathe = character:GetAttribute("Stat_ElementWind"),
					Shadowcast = character:GetAttribute("Stat_ElementShadow"),
					Ironsing = character:GetAttribute("Stat_ElementMetal"),
					Bloodrend = character:GetAttribute("Stat_ElementBlood"),
				},
			},
			content = {
				mantraModifications = {},
				notes = "",
			},
			meta = {
				tags = {},
				isPrivate = true,
			},
			talents = {},
			mantras = {},
			weapons = "",
			enchant = "",
			motif = "",
			preShrine = {
				base = {
					Strength = 100,
					Fortitude = 100,
					Agility = 100,
					Intelligence = 100,
					Willpower = 100,
					Charisma = 100,
				},
				weapon = {
					["Heavy Wep."] = 100,
					["Medium Wep."] = 100,
					["Light Wep."] = 100,
				},
				attunement = {
					Flamecharm = 100,
					Frostdraw = 100,
					Thundercall = 100,
					Galebreathe = 100,
					Shadowcast = 100,
					Ironsing = 100,
					Bloodrend = 100,
				},
			},
			postShrine = nil,
			favoritedTalents = {},
		}

		data.postShrine = data.attributes

		local meta = data.stats.meta
		local notes = {}

		for _, child in next, backpack:GetChildren() do
			if child.Name:match("Resonance:") then
				meta.Bell = child.Name:gsub("Resonance:", "")
			end

			if child.Name:match("Mantra") and child:GetAttribute("DisplayName") then
				local isRecalled = child.Name:match("RecalledMantra")
				notes[#notes + 1] = (isRecalled and "[RECALLED MANTRA]" or "[USED MANTRA]")
					.. " "
					.. (child:GetAttribute("RichStats") and child:GetAttribute("RichStats"):gsub("\n", " | ") or "NO RICH STATS?")

				if not isRecalled then
					data.mantras[#data.mantras + 1] = child:GetAttribute("DisplayName")
					data.content.mantraModifications[child:GetAttribute("DisplayName")] = {}
				end
			end

			if child.Name == "Weapon" then
				notes[#notes + 1] = "[USED WEAPON] " .. (child:GetAttribute("RichStats") and child:GetAttribute("RichStats"):gsub("\n", " | ") or child.Name)
			end
		end

		for _, instance in next, character:GetChildren() do
			if instance.Name == "Ring" then
				local ringName = instance:GetAttribute("DisplayName")
					or instance:GetAttribute("EquipmentRef")
					or instance.Name
				notes[#notes + 1] = string.format("[EQUIPPED RING] %s\n", ringName)
					.. (instance:GetAttribute("RichStats") and instance:GetAttribute("RichStats"):gsub("\n", " | ") or instance.Name)
			end

			if instance.Name == "Shirt" then
				notes[#notes + 1] = "[EQUIPPED SHIRT ID] " .. instance.ShirtTemplate
			end

			if instance.Name == "Pants" then
				notes[#notes + 1] = "[EQUIPPED PANTS ID] " .. instance.PantsTemplate
			end

			if
				instance.Name:match("Equipment")
				and instance:GetAttribute("RichStats")
				and instance:GetAttribute("DisplayName")
			then
				notes[#notes + 1] = string.format(
					"[EQUIPPED EQUIPMENT] [%s] %s",
					instance.Name,
					instance:GetAttribute("DisplayName")
				) .. (instance:GetAttribute("RichStats") and instance:GetAttribute("RichStats"):gsub("\n", " | ") or "")
			end
		end

		notes[#notes + 1] = string.format("[HEALTH] %.2f/%.2f", humanoid.Health, humanoid.MaxHealth)

		data.content.notes = table.concat(notes, "\n\n")

		local response = request({
			Url = "https://new.deepwoken.co/api/proxy/builds",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Accept"] = "application/json",
				["Origin"] = "https://deepwoken.co",
				["Referer"] = "https://deepwoken.co/builder",
				["Sec-Fetch-Site"] = "same-origin",
				["Sec-Fetch-Mode"] = "cors",
				["Sec-Fetch-Dest"] = "empty",
			},
			Body = JSON.encode(data),
		})

		if not response then
			return Logger.notify("Failed to steal build from '%s' due to no response.", fetchName(player))
		end

		if not response.Success then
			return Logger.notify(
				"(Status %i) Failed to steal build from '%s' due to build creation failure.",
				response.StatusCode,
				fetchName(player)
			)
		end

		if not response.Body then
			return Logger.notify("Failed to steal build from '%s' due to no response body.", fetchName(player))
		end

		local decoded = JSON.decode(response.Body)

		if not decoded or not decoded.id then
			return Logger.notify(
				"(Status %i) Failed to steal build from '%s' due to invalid response body.",
				response.StatusCode,
				fetchName(player)
			)
		end

		local buildUrl = string.format("https://deepwoken.co/builder?id=%s", decoded.id)
		setclipboard(buildUrl)

		local path = string.format("%s %s Stolen Build", os.date("%B %d %Y"), player.Name)
		Logger.notify("Successfully stole %s's build, %s & saved to file.", fetchName(player), buildUrl)

		if not isfolder("Aero/Stolen Builds") then
			makefolder("Aero/Stolen Builds")
		end
		
		writefile("Aero/Stolen Builds/" .. path .. ".txt", string.format([[.gg/lyc
stolen on %s
build url: %s
%s]], os.date("%B %d %Y"), buildUrl, data.content.notes))
	end

	local function onHairStealPlayer(player)
		local character = player.Character
		if not character then
			return Logger.notify(
				"Failed to steal hair IDs from '%s' because their character does not exist.",
				fetchName(player)
			)
		end

		local hairIds = {}
		local seen = {}

		for _, instance in next, character:GetDescendants() do
			if not instance:IsA("Accessory") then
				continue
			end

			local isHairSlot = instance.AccessoryType == Enum.AccessoryType.Hair
			if not isHairSlot then
				local handle = instance:FindFirstChild("Handle")
				isHairSlot = handle ~= nil and handle:FindFirstChild("HairAttachment") ~= nil
			end

			if not isHairSlot then
				continue
			end

			local id = instance.Name:match("^Asset:(%d+)$") or instance.Name:match("(%d+)")
			if id and not seen[id] then
				seen[id] = true
				table.insert(hairIds, id)
			end
		end

		if #hairIds == 0 then
			return Logger.notify("Failed to find any hair IDs for '%s'.", fetchName(player))
		end

		setclipboard(table.concat(hairIds, ", "))
		Logger.notify("Successfully stole %s's hair ID(s) & copied to clipboard.", fetchName(player))
	end

	local function updateBuildStealing()
		local leaderboardMap = LeaderboardClient.gld()
		if not leaderboardMap then
			return cameraSubject:restore()
		end

		for player, frame in next, leaderboardMap do
			local inputBegan = Signal.new(frame.InputBegan)
			local label = string.format("Monitoring_InputBegan_Steal_%s", player.Name)

			if buildStealMaid[frame] then
				continue
			end

			buildStealMaid[frame] = inputBegan:connect(label, function(input)
				if input.KeyCode ~= Enum.KeyCode.P then
					return
				end

				onBuildStealPlayer(player)
			end)
		end
	end

	local function updateHairStealing()
		local leaderboardMap = LeaderboardClient.gld()
		if not leaderboardMap then
			return cameraSubject:restore()
		end

		for player, frame in next, leaderboardMap do
			local inputBegan = Signal.new(frame.InputBegan)
			local label = string.format("Monitoring_InputBegan_HairSteal_%s", player.Name)

			if hairStealMaid[frame] then
				continue
			end

			hairStealMaid[frame] = inputBegan:connect(label, function(input)
				if input.KeyCode ~= Enum.KeyCode.O then
					return
				end

				onHairStealPlayer(player)
			end)
		end
	end

	local function updatePlayerListWhitelisting()
		local leaderboardMap = LeaderboardClient.gld()
		if not leaderboardMap then
			return cameraSubject:restore()
		end

		for player, frame in next, leaderboardMap do
			local inputBegan = Signal.new(frame.InputBegan)
			local label = string.format("Monitoring_InputBegan_PLW_%s", player.Name)

			if plwMaid[frame] then
				continue
			end

			plwMaid[frame] = inputBegan:connect(label, function(input)
				onWhitelistingInputBegan(player, input)
			end)
		end
	end

	local function updateSpectating()
		local leaderboardMap = LeaderboardClient.gld()
		if not leaderboardMap then
			return cameraSubject:restore()
		end

		for player, frame in next, leaderboardMap do
			local inputBegan = Signal.new(frame.InputBegan)
			local label = string.format("Monitoring_InputBegan%s", player.Name)

			if Configuration.expectToggleValue("ShowHiddenPlayers") then
				showHiddenMap:add(frame, "Visible", true)
			end

			if spectateMaid[frame] then
				continue
			end

			spectateMaid[frame] = inputBegan:connect(label, function(input)
				onSpectateInputBegan(player, input)
			end)
		end
	end

	local function updatePlayerProximity()
		local proximityRange = Configuration.expectOptionValue("PlayerProximityRange") or 350
		local playersInRange = Finder.gpir(proximityRange)
		if not playersInRange then
			return
		end

		local localPlayer = players.LocalPlayer
		if not localPlayer then
			return
		end

		local backpack = localPlayer:FindFirstChild("Backpack")
		if not backpack then
			return
		end

		local now = os.clock()

		-- Refresh the last-in-range stamp for everyone currently in range.
		for _, player in next, playersInRange do
			Monitoring.proximityLastSeen[player] = now
		end

		-- Dismiss a player's notification only after they've been out of range for the full grace window.
		-- A one-cycle drop-out keeps the notification up, so returning doesn't re-fire a fresh "entered".
		for player, removeNotification in next, Monitoring.seen do
			local isInPlayerRange = table.find(playersInRange, player)
			if isInPlayerRange then
				continue
			end

			if now - (Monitoring.proximityLastSeen[player] or 0) <= PROXIMITY_GRACE then
				continue
			end

			removeNotification()

			Monitoring.seen[player] = nil
			Monitoring.proximityLastSeen[player] = nil
		end

		for _, player in next, playersInRange do
			if Monitoring.seen[player] ~= nil then
				continue
			end

			if
				Configuration.expectToggleValue("PlayerProximityVW")
				and not backpack:FindFirstChild("Talent:Voidwalker Contract")
			then
				continue
			end

			Monitoring.seen[player] =
				Logger.mnnotify("%s entered your proximity radius of %i studs.", fetchName(player), proximityRange)

			if Configuration.expectToggleValue("PlayerProximityBeep") then
				beepSound.SoundId = "rbxassetid://100849623977896"
				beepSound.PlaybackSpeed = 1
				beepSound.Volume = Configuration.expectOptionValue("PlayerProximityBeepVolume") or 0.1
				beepSound:Play()
			end
		end
	end

	local function updateSubjectMonitoring()
		cameraSubject:set(workspace.CurrentCamera, "CameraSubject", Monitoring.subject)

		if Monitoring.subject ~= nil then
			players.LocalPlayer:AddTag("ForcedSubject")
		else
			players.LocalPlayer:RemoveTag("ForcedSubject")
		end
		-- The spectate stream request is NOT done here any more -- it runs on its own throttled connection in
		-- Monitoring.init, exactly like Project Rain's leaderboard_spectate (inline, never a per-frame spawn).
	end

	local function updateMonitoring()
		if Monitoring.subject then
			updateSubjectMonitoring()
		else
			cameraSubject:restore()
		end

		if os.clock() - lastUpdateTime <= 2.0 then
			return
		end

		lastUpdateTime = os.clock()

		if Configuration.expectToggleValue("PlayerListWhitelisting") then
			updatePlayerListWhitelisting()
		else
			plwMaid:clean()
		end

		if Configuration.expectToggleValue("BuildStealer") then
			updateBuildStealing()
		else
			buildStealMaid:clean()
		end

		if Configuration.expectToggleValue("HairStealer") then
			updateHairStealing()
		else
			hairStealMaid:clean()
		end

		if Configuration.expectToggleValue("PlayerSpectating") then
			updateSpectating()
		else
			spectateMaid:clean()
		end

		if Configuration.expectToggleValue("PlayerProximity") then
			updatePlayerProximity()
		end
	end

	function Monitoring.init()
		monitoringMaid:add(renderStepped:connect("Monitoring_OnRenderStepped", updateMonitoring))

		-- Project Rain's leaderboard_spectate streaming, verbatim in structure: a dedicated RenderStepped loop
		-- that, while a subject is set, calls RequestStreamAroundAsync INLINE in a pcall at most every 0.25s.
		-- PR issues one request per 0.25s on this one connection and lets it return before the next -- so at
		-- most ~one is ever in flight. (Aero's old code wrapped it in TaskSpawner.spawn + maid:add EVERY frame,
		-- which piled thousands of parked requests into the fiber pool -> "RSL - panic: failed to spawn a fiber".)
		local lastStreamRequest = tick()
		monitoringMaid:add(renderStepped:connect("Monitoring_StreamSpectate", function()
			if tick() - lastStreamRequest < 0.25 or Monitoring.subject == nil then
				return
			end
			lastStreamRequest = tick()
			pcall(function()
				players.LocalPlayer:RequestStreamAroundAsync(Monitoring.subject.Position, 1000)
			end)
		end))

		if not LPH_OBFUSCATED or shared.Aero.verbose then
			Logger.warn("Monitoring initialized.")
		end
	end

	function Monitoring.detach()
		monitoringMaid:clean()
		buildStealMaid:clean()
		hairStealMaid:clean()
		spectateMaid:clean()
		plwMaid:clean()
		showHiddenMap:restore()

		local refreshLeaderboard = LeaderboardClient.glrf()

		if refreshLeaderboard then
			refreshLeaderboard()
		end

		Logger.warn("Monitoring detached.")
	end

	return Monitoring
end)()
