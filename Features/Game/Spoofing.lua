return LPH_NO_VIRTUALIZE(function()
	---@module Utility.Maid
	local Maid = require("Utility/Maid")

	---@module Utility.Signal
	local Signal = require("Utility/Signal")

	---@module Utility.Configuration
	local Configuration = require("Utility/Configuration")

	---@module Utility.Logger
	local Logger = require("Utility/Logger")

	---@module Utility.OriginalStoreManager
	local OriginalStoreManager = require("Utility/OriginalStoreManager")

	---@note: Replace (e.g Konga Clutch Ring Spoofer) with Talent Spoofer & Instance Spoofer in the future.
	local Spoofing = { force = false }

	local runService = game:GetService("RunService")
	local starterGui = game:GetService("StarterGui")
	local players = game:GetService("Players")
	local replicatedStorage = game:GetService("ReplicatedStorage")

	local renderStepped = Signal.new(runService.RenderStepped)

	local spoofingMaid = Maid.new()

	local infoSpoofMap = spoofingMaid:mark(OriginalStoreManager.new())

	local fakeKongaClutchRing = Instance.new("Folder")
	fakeKongaClutchRing.Name = "Ring:Konga's Clutch Ring"

	local fakeFreestylerBand = Instance.new("Folder")
	fakeFreestylerBand.Name = "Ring:Freestyler's Band"

	local lastTimestampRun = os.clock()

	local cachedEffectReplicator = nil
	local function getPassives()
		if not cachedEffectReplicator then
			local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
			if effectReplicator then
				local success, result = pcall(require, effectReplicator)
				if success then
					cachedEffectReplicator = result
				end
			end
		end
		return cachedEffectReplicator and cachedEffectReplicator.Passives
	end

	local function updateFreestylerBandSpoof(character)
		local passives = getPassives()
		if passives and not passives["Freestyler's Band"] then
			passives["Freestyler's Band"] = true
		end

		local localPlayer = players.LocalPlayer
		local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
		if backpack then
			fakeFreestylerBand.Parent = backpack
		end
	end

	local function updateKongaClutchRingSpoof(character)
		local passives = getPassives()
		if passives and not passives["Konga's Clutch Ring"] then
			passives["Konga's Clutch Ring"] = true
		end

		local localPlayer = players.LocalPlayer
		local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
		if backpack then
			fakeKongaClutchRing.Parent = backpack
		end
	end

	local function resetFreestylerBandSpoof(character)
		local passives = getPassives()
		if passives and passives["Freestyler's Band"] then
			passives["Freestyler's Band"] = nil
		end
		
		fakeFreestylerBand.Parent = nil
	end

	local function resetKongaClutchRingSpoof(character)
		local passives = getPassives()
		if passives and passives["Konga's Clutch Ring"] then
			passives["Konga's Clutch Ring"] = nil
		end

		fakeKongaClutchRing.Parent = nil
	end

	local function updateLightweightSpoof()
		local passives = getPassives()
		if passives and not passives["Lightweight"] then
			passives["Lightweight"] = true
		end
	end

	local function resetLightweightSpoof()
		local passives = getPassives()
		if passives and passives["Lightweight"] then
			passives["Lightweight"] = nil
		end
	end

	local function updateCaptainEtreaSpoof()
		local passives = getPassives()
		if passives and not passives["Captain Etrea"] then
			passives["Captain Etrea"] = true
		end
	end

	local function resetCaptainEtreaSpoof()
		local passives = getPassives()
		if passives and passives["Captain Etrea"] then
			passives["Captain Etrea"] = nil
		end
	end

	---@param instance Instance
	local function onPgDescendantAdded(instance)
		if
			instance.Name ~= "DeathID"
			and instance.Name ~= "KillerPlayer"
			and instance.Name ~= "KillerCharacter"
			and instance.Name ~= "Timestamp"
		then
			return
		end

		if not instance:IsA("TextLabel") and not instance:IsA("TextBox") then
			return
		end

		instance.Visible = not (
			Configuration.expectToggleValue("InfoSpoofing")
			and Configuration.expectToggleValue("HideDeathInformation")
		)
	end

	local function updateDeathInformationSpoof()
		local localPlayer = players.LocalPlayer
		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end

		local killGui = playerGui:FindFirstChild("KillGui")
		if not killGui then
			return
		end

		local splash = killGui:FindFirstChild("Splash")
		if not splash then
			return
		end

		for _, descendant in next, splash:GetDescendants() do
			onPgDescendantAdded(descendant)
		end
	end

	local function updateSpoofing()
		if os.clock() - lastTimestampRun <= 2.0 then
			return
		end

		lastTimestampRun = os.clock()

		if not Configuration.expectToggleValue("InfoSpoofing") then
			infoSpoofMap:restore()
		end

		updateDeathInformationSpoof()

		local player = players.LocalPlayer
		if not player then
			return
		end

		local character = player.Character
		if not character then
			return
		end

		if Configuration.expectToggleValue("FreestylersBandSpoof") then
			updateFreestylerBandSpoof(character)
		else
			resetFreestylerBandSpoof(character)
		end

		if Configuration.expectToggleValue("KongaClutchRingSpoof") then
			updateKongaClutchRingSpoof(character)
		else
			resetKongaClutchRingSpoof(character)
		end

		if Configuration.expectToggleValue("LightweightSpoof") then
			updateLightweightSpoof()
		else
			resetLightweightSpoof()
		end

		if Configuration.expectToggleValue("CaptainEtreaSpoof") then
			updateCaptainEtreaSpoof()
		else
			resetCaptainEtreaSpoof()
		end
	end

	---@param value string
	function Spoofing.sgv(value)
		if not Configuration.expectToggleValue("InfoSpoofing") then
			return
		end

		local player = players.LocalPlayer
		if not player then
			return
		end

		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end

		local topBarGui = playerGui:FindFirstChild("TopbarGui")
		local container = topBarGui and topBarGui:FindFirstChild("Container")
		local infoFrame = container and container:FindFirstChild("InfoFrame")
		local gameInfo = infoFrame and infoFrame:FindFirstChild("GameInfo")
		if not gameInfo then
			return
		end

		local gameVersionLabel = gameInfo:FindFirstChild("GameVersion")
		if not gameVersionLabel then
			return
		end

		infoSpoofMap:add(gameVersionLabel, "Text", value)
	end

	---@param value string
	function Spoofing.sds(value)
		if not Configuration.expectToggleValue("InfoSpoofing") then
			return
		end

		local player = players.LocalPlayer
		if not player then
			return
		end

		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end

		local topBarGui = playerGui:FindFirstChild("TopbarGui")
		local container = topBarGui and topBarGui:FindFirstChild("Container")
		local infoFrame = container and container:FindFirstChild("InfoFrame")
		local worldInfoFrame = infoFrame and infoFrame:FindFirstChild("WorldInfo")
		if not worldInfoFrame then
			return
		end

		local dateLabel = worldInfoFrame:FindFirstChild("Date")
		if not dateLabel then
			return
		end

		infoSpoofMap:add(dateLabel, "Text", value)
	end

	---@param value string
	function Spoofing.sss(value)
		if not Configuration.expectToggleValue("InfoSpoofing") then
			return
		end

		local player = players.LocalPlayer
		if not player then
			return
		end

		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end

		local topBarGui = playerGui:FindFirstChild("TopbarGui")
		local container = topBarGui and topBarGui:FindFirstChild("Container")
		local infoFrame = container and container:FindFirstChild("InfoFrame")
		local characterInfo = infoFrame and infoFrame:FindFirstChild("CharacterInfo")
		if not characterInfo then
			return
		end

		local slotLabel = characterInfo:FindFirstChild("Slot")
		if not slotLabel then
			return
		end

		infoSpoofMap:add(slotLabel, "Text", value)
	end

	---@param instance Instance
	---@param attribute string
	function Spoofing.facs(instance, attribute)
		local original = instance:GetAttribute(attribute)
		instance:SetAttribute(attribute, "SPOOFING_RICS")
		instance:SetAttribute(attribute, original)
	end

	---@param instance ValueBase
	function Spoofing.fvcs(instance)
		local original = instance.Value
		instance.Value = "SPOOFING_RICS"
		instance.Value = original
	end

	---@note: Attempts to trigger them w/o using 'firesignal' or 'getconnections' because they crash.
	function Spoofing.rics()
		for _, player in next, players:GetPlayers() do
			Spoofing.facs(player, "Guild")
			Spoofing.facs(player, "FirstName")
			Spoofing.facs(player, "LastName")

			local character = player.Character
			if not character then
				continue
			end

			Spoofing.facs(character, "GuildRich")

			local humanoid = character:FindFirstChild("Humanoid")
			if not humanoid then
				continue
			end

			Spoofing.facs(humanoid, "CharacterName")
		end

		local serverRegion = replicatedStorage:FindFirstChild("SERVER_REGION")
		local serverName = replicatedStorage:FindFirstChild("SERVER_NAME")
		local serverAge = replicatedStorage:FindFirstChild("SERVER_AGE")

		if not serverRegion or not serverName or not serverAge then
			return
		end

		Spoofing.fvcs(serverRegion)
		Spoofing.fvcs(serverName)

		local original = serverAge.Value
		serverAge.Value = "L"
		serverAge.Value = original
	end

	-- PR streamer_mode's server-info spoof: WRITE the values directly and re-apply them whenever the game
	-- changes them (.Changed), instead of intercepting the .Value READ through the now-removed __index hook.
	local function hookServerValue(valueInstance, getSpoofed)
		if not valueInstance then
			return
		end
		local function apply()
			if Spoofing.force or not Configuration.expectToggleValue("InfoSpoofing") then
				return
			end
			local spoofed = getSpoofed()
			if spoofed ~= nil and valueInstance.Value ~= spoofed then
				valueInstance.Value = spoofed
			end
		end
		spoofingMaid:add(valueInstance.Changed:Connect(apply))
		apply()
	end

	function Spoofing.init()
		local localPlayer = players.LocalPlayer
		local playerGui = localPlayer:WaitForChild("PlayerGui")
		local pgDescendantAdded = Signal.new(playerGui.DescendantAdded)

		spoofingMaid:add(renderStepped:connect("Spoofing_OnRenderStepped", updateSpoofing))
		spoofingMaid:add(pgDescendantAdded:connect("Spoofing_OnPGDescendantAdded", onPgDescendantAdded))

		-- Server-info spoof the PR way (direct writes + .Changed re-apply), replacing the dropped __index reads.
		pcall(function()
			hookServerValue(replicatedStorage:WaitForChild("SERVER_NAME", 10), function()
				return Configuration.expectOptionValue("SpoofedServerName")
			end)
			hookServerValue(replicatedStorage:WaitForChild("SERVER_REGION", 10), function()
				return Configuration.expectOptionValue("SpoofedServerRegion")
			end)
			hookServerValue(replicatedStorage:WaitForChild("SERVER_AGE", 10), function()
				return Configuration.expectOptionValue("SpoofedServerAge")
			end)
		end)

		if not LPH_OBFUSCATED or shared.Aero.verbose then
			Logger.warn("Spoofing initialized.")
		end
	end

	function Spoofing.detach()
		Spoofing.force = true

		spoofingMaid:clean()

		Spoofing.rics()

		fakeFreestylerBand.Parent = nil
		fakeKongaClutchRing.Parent = nil
		resetLightweightSpoof()
		resetCaptainEtreaSpoof()

		Logger.warn("Spoofing detached.")
	end

	return Spoofing
end)()
