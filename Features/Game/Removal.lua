return LPH_NO_VIRTUALIZE(function()
	local Removal = {}

	---@module Utility.Maid
	local Maid = require("Utility/Maid")

	---@module Utility.Signal
	local Signal = require("Utility/Signal")

	---@module Game.KeyHandling
	local KeyHandling = require("Game/KeyHandling")

	---@module Utility.Configuration
	local Configuration = require("Utility/Configuration")

	---@module Utility.OriginalStoreManager
	local OriginalStoreManager = require("Utility/OriginalStoreManager")

	---@module Utility.OriginalStore
	local OriginalStore = require("Utility/OriginalStore")

	---@module Utility.Logger
	local Logger = require("Utility/Logger")

	---@module Game.EffectDispatcher
	local EffectDispatcher = require("Game/EffectDispatcher")

	local runService = game:GetService("RunService")
	local players = game:GetService("Players")
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local lighting = game:GetService("Lighting")
	local debris = game:GetService("Debris")
	local collectionService = game:GetService("CollectionService")

	local removalMaid = Maid.new()

	local originalAcidRemote = nil
	local placeholderRemote = Instance.new("RemoteEvent")
	placeholderRemote.Name = "AcidRemote"

	local noShadows = removalMaid:mark(OriginalStore.new())
	local noBlur = removalMaid:mark(OriginalStore.new())
	local noOverlay = removalMaid:mark(OriginalStore.new())

	local echoModifiersMap = removalMaid:mark(OriginalStoreManager.new())
	local noFogMap = removalMaid:mark(OriginalStoreManager.new())
	local killBricksMap = removalMaid:mark(OriginalStoreManager.new())
	local damageBricksMap = removalMaid:mark(OriginalStoreManager.new())
	local lightBarrierMap = removalMaid:mark(OriginalStoreManager.new())
	local yunShulBarrierMap = removalMaid:mark(OriginalStoreManager.new())
	local yunShulResonanceDoorMap = removalMaid:mark(OriginalStoreManager.new())
	local hiveGateMap = removalMaid:mark(OriginalStoreManager.new())
	local statVFXMap = removalMaid:mark(OriginalStoreManager.new())

	local renderStepped = Signal.new(runService.RenderStepped)
	local workspaceDescendantAdded = Signal.new(workspace.DescendantAdded)
	local workspaceDescendantRemoving = Signal.new(workspace.DescendantRemoving)

	local lastUpdate = os.clock()
	local lastNoKillBricksUpdate = 0
	local noKillBricksWasEnabled = false
	local lastWindEffectTimestamp = os.clock()
	local lastBlindUpdate = os.clock()

	---@param localPlayer Player
	local function updateNoEchoModifiers(localPlayer)
		local backpack = localPlayer:FindFirstChild("Backpack")
		if not backpack then
			return
		end

		for _, instance in pairs(backpack:GetChildren()) do
			if not instance.Name:match("EchoMod") then
				continue
			end

			echoModifiersMap:add(instance, "Parent", nil)
		end
	end

	local function updateNoHiveGate()
		for _, store in next, hiveGateMap:data() do
			local data = store.data
			if not data then
				continue
			end

			store:set(store.data, "Parent", nil)
		end
	end

	local function updateNoKillBricks()
		for _, store in next, killBricksMap:data() do
			local data = store.data
			if not data then
				continue
			end

			store:set(store.data, "CFrame", CFrame.new(math.huge, math.huge, math.huge))
		end
	end

	local function updateNoKillBricksPersistent()
		local now = os.clock()
		if now - lastNoKillBricksUpdate < 0.1 then
			return
		end
		lastNoKillBricksUpdate = now

		if Configuration.expectToggleValue("NoKillBricks") then
			updateNoKillBricks()
			noKillBricksWasEnabled = true
		elseif noKillBricksWasEnabled then
			killBricksMap:restore()
			noKillBricksWasEnabled = false
		end
	end

	local function updateNoLightBarrier()
		for _, store in next, lightBarrierMap:data() do
			local data = store.data
			if not data then
				continue
			end

			store:set(store.data, "CFrame", CFrame.new(math.huge, math.huge, math.huge))
		end
	end

	-- PR's no fog: push FogEnd far out and zero the Atmosphere density (leave FogStart alone). Routed
	-- through noFogMap so toggling NoFog off restores the game's original values.
	local function updateNoFog()
		if lighting.FogEnd ~= 1000000 then
			noFogMap:add(lighting, "FogEnd", 1000000)
		end

		local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere and atmosphere.Density ~= 0 then
			noFogMap:add(atmosphere, "Density", 0)
		end
	end

	local function clearBlindGui(localPlayer)
		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end

		for _, gui in next, playerGui:GetChildren() do
			if gui.Name == "AshBlind" or gui.Name == "AshVision" or gui.Name == "AshDecaying" then
				gui:Destroy()
			end
		end
	end

	-- Blind passives that we've removed, so we can put them back.
	local BLIND_PASSIVES = { "Blinded", "Blind" }
	local removedBlindPassives = {}

	---Get the EffectReplicator passives table.
	---@return table?
	local function getPassives()
		local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
		if not effectReplicator then
			return nil
		end

		local effectReplicatorModule = require(effectReplicator)
		return effectReplicatorModule and effectReplicatorModule.Passives
	end

	local function updateNoBlind()
		local localPlayer = players.LocalPlayer
		if not localPlayer then
			return
		end

		clearBlindGui(localPlayer)

		---@note: EffectClient treats us as blinded if Passives.Blinded or Passives.Blind is set.
		local passives = getPassives()
		if not passives then
			return
		end

		for _, name in next, BLIND_PASSIVES do
			local value = passives[name]
			if value == nil then
				continue
			end

			removedBlindPassives[name] = value
			passives[name] = nil
		end
	end

	local function resetNoBlind()
		if not next(removedBlindPassives) then
			return
		end

		local passives = getPassives()
		if passives then
			for name, value in next, removedBlindPassives do
				if passives[name] == nil then
					passives[name] = value
				end
			end
		end

		table.clear(removedBlindPassives)
	end

	local function updateNoBlur()
		local genericBlur = lighting:FindFirstChild("GenericBlur")
		if not genericBlur then
			return
		end

		local underwaterBlur = lighting:FindFirstChild("UnderwaterBlur")
		if not underwaterBlur then
			return
		end

		noBlur:set(genericBlur, "Size", 0.0)
		noBlur:set(underwaterBlur, "Size", 0.0)
	end

	---@param localPlayer Player
	local function updateNoSanityVFX(localPlayer)
		for _, object in next, collectionService:GetTagged("StatVFX") do
			if object.Parent == replicatedStorage then
				continue
			end

			statVFXMap:add(object, "Parent", replicatedStorage)
		end

		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end

		local overlayGui = playerGui:FindFirstChild("OverlayGui")
		if not overlayGui then
			return
		end

		noOverlay:set(overlayGui, "Enabled", false)
	end

	local function updateNoYunShulBarrier()
		for _, store in next, yunShulBarrierMap:data() do
			local data = store.data
			if not data then
				continue
			end

			store:set(store.data, "CFrame", CFrame.new(math.huge, math.huge, math.huge))
		end

		for _, store in next, yunShulResonanceDoorMap:data() do
			local data = store.data
			if not data then
				continue
			end

			store:set(store.data, "Parent", nil)
		end
	end

	local function updateNoAcidWater()
		if originalAcidRemote then
			return
		end

		local requests = replicatedStorage:FindFirstChild("Requests")
		if not requests then
			return
		end

		local acidRemote = requests:FindFirstChild("AcidRemote")
		if not acidRemote then
			return
		end

		originalAcidRemote = acidRemote
		originalAcidRemote.Name = "AcidRemote_Original"
		placeholderRemote.Parent = requests
	end

	local function restoreNoAcidWater()
		if not originalAcidRemote then
			return
		end

		originalAcidRemote.Name = "AcidRemote"
		placeholderRemote.Parent = nil
	end
	
	local function updateNoDamageBricks()
		for _, store in next, damageBricksMap:data() do
			local data = store.data
			if not data then
				continue
			end

			store:set(store.data, "Parent", nil)
		end
	end

	local function restoreNoDamageBricks()
		damageBricksMap:restore()
		for _,v in next, game:GetService("CollectionService"):GetTagged("DamageBrick") do
			v:Destroy()
		end
	end

	-- PR's no-blind cadence: re-strip the Blind/Blinded passives every 0.5s (instead of riding the 3s
	-- removal loop) so a re-applied blind clears almost instantly rather than lingering up to 3s.
	local function updateNoBlindFast()
		if os.clock() - lastBlindUpdate <= 0.5 then
			return
		end
		lastBlindUpdate = os.clock()

		if Configuration.expectToggleValue("NoBlind") then
			updateNoBlind()
		else
			resetNoBlind()
		end
	end

	local function updateRemoval()
		if os.clock() - lastUpdate <= 3.0 then
			return
		end

		lastUpdate = os.clock()

		local localPlayer = players.LocalPlayer
		if not localPlayer then
			return
		end

		if Configuration.expectToggleValue("NoFog") then
			updateNoFog()
		else
			noFogMap:restore()
		end

		if Configuration.expectToggleValue("NoEchoModifiers") then
			updateNoEchoModifiers(localPlayer)
		else
			echoModifiersMap:restore()
		end

		if Configuration.expectToggleValue("NoKillBricks") then
			updateNoKillBricks()
		else
			killBricksMap:restore()
		end
		
		if Configuration.expectToggleValue("NoDamageBricks") then
			updateNoDamageBricks()
		else
			restoreNoDamageBricks()
		end

		if Configuration.expectToggleValue("NoHiveGate") then
			updateNoHiveGate()
		else
			hiveGateMap:restore()
		end

		if Configuration.expectToggleValue("NoCastleLightBarrier") then
			updateNoLightBarrier()
		else
			lightBarrierMap:restore()
		end

		if Configuration.expectToggleValue("NoYunShulBarrier") then
			updateNoYunShulBarrier()
		else
			yunShulBarrierMap:restore()
			yunShulResonanceDoorMap:restore()
		end

		if Configuration.expectToggleValue("NoBlur") then
			updateNoBlur()
		else
			noBlur:restore()
		end

		if Configuration.expectToggleValue("NoAcidWater") then
			updateNoAcidWater()
		else
			restoreNoAcidWater()
		end

		if Configuration.expectToggleValue("NoShadows") then
			noShadows:set(lighting, "GlobalShadows", false)
		else
			noShadows:restore()
		end

		if Configuration.expectToggleValue("NoSanityVFX") then
			updateNoSanityVFX(localPlayer)
		else
			statVFXMap:restore()
			noOverlay:restore()
		end
	end

	---@param effect table
	local function hideEffect(effect)
		local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
		if not effectReplicator then
			return
		end

		local effectReplicatorModule = require(effectReplicator)
		if not effectReplicatorModule then
			return
		end

		if not effect.ID then
			return
		end

		effectReplicatorModule.Effects[effect.ID] = nil
	end

	---@param effect table
	local function updateRemovalEffects(effect)
		local stunEffects = { "Stun", "Action", "MobileAction" }

		if Configuration.expectToggleValue("NoStun") and table.find(stunEffects, effect.Class) then
			hideEffect(effect)
		end

		if
			(effect.Class == "BeingWinded" or effect.Class == "StrongWind")
			and Configuration.expectToggleValue("NoWind")
		then
			lastWindEffectTimestamp = os.clock()
			return hideEffect(effect)
		end

		if Configuration.expectToggleValue("NoWind") and os.clock() - lastWindEffectTimestamp <= 30.0 then
			if
				effect.Class == "Speed"
				or effect.Class == "NoJump"
				or effect.Class == "NoStun"
				or effect.Class == "NoSprint"
				or effect.Class == "NoRoll"
			then
				return hideEffect(effect)
			end
		end

		if
			(effect.Class == "NoJump" or effect.Class == "NoJumpAlt")
			and Configuration.expectToggleValue("AlwaysAllowJump")
		then
			return hideEffect(effect)
		end

		if
			effect.Class == "SpeedOverride"
			and effect.Value < 14
			and Configuration.expectToggleValue("NoSpeedDebuff")
		then
			return hideEffect(effect)
		end

		if effect.Class == "Speed" and effect.Value < 0 and Configuration.expectToggleValue("NoSpeedDebuff") then
			rawset(effect, "Value", 0)
		end

		if effect.Class == "Burning" and Configuration.expectToggleValue("AutoExtinguishFire") then
			-- getRemote (encoder) + two FireServers -- run on the Heartbeat pump, never on the EffectAdded dispatch
			-- callstack, so this can't nest a guarded STM job (Kernel,2090). The enqueue here is a plain table insert.
			EffectDispatcher.defer(function()
				local serverSlide = KeyHandling.getRemote("ServerSlide")
				local serverSlideStop = KeyHandling.getRemote("ServerSlideStop")

				if not serverSlide or not serverSlideStop then
					return Logger.warn("ServerSlide or ServerSlideStop not found.")
				end

				serverSlide:FireServer(true)
				serverSlideStop:FireServer()
			end)
		end

		if effect.Class == "Blinded" and Configuration.expectToggleValue("NoBlind") then
			return hideEffect(effect)
		end
	end

	---@param descendant Instance
	local function onWorkspaceDescendantAdded(descendant)
		if descendant:IsA("Model") and descendant.Name == "ResonanceDoor" then
			yunShulResonanceDoorMap:mark(descendant, "Parent")
		end

		if descendant:IsA("Model") and descendant.Name == "HiveGate" then
			hiveGateMap:mark(descendant, "Parent")
		end

		if descendant.Name == "WindPusher" and Configuration.expectToggleValue("NoWind") then
			debris:AddItem(descendant, 0.01)
		end

		if not descendant:IsA("BasePart") then
			return
		end

		if descendant.Name == "LifeField" then
			lightBarrierMap:mark(descendant, "CFrame")
		end

		local killInstance = descendant.Name == "KillBrick" or descendant.Name == "KillPlane"
		local killChasm = descendant.Name:match("Chasm")
		local superWall = descendant.Name == "SuperWall"
		local damagePart = descendant.Name == "Lava" and descendant:FindFirstChild("Hazardous") and not descendant:HasTag("DamageBrick")

		if killInstance or killChasm or superWall then
			killBricksMap:mark(descendant, "CFrame")
			if Configuration.expectToggleValue("NoKillBricks") then
				killBricksMap:add(
					descendant,
					"CFrame",
					CFrame.new(math.huge, math.huge, math.huge)
				)
			end
		end

		if descendant.Name == "DeepPassage_Yun" then
			yunShulBarrierMap:mark(descendant, "CFrame")
		end

		if damagePart then
			damageBricksMap:mark(descendant, "Parent")
		end
	end

	---@param descendant Instance
	local function onWorkspaceDescendantRemoving(descendant)
		killBricksMap:forget(descendant)
		lightBarrierMap:forget(descendant)
	end

	-- Effect removal rides the shared Game/EffectDispatcher as an "added" hook (registered in Removal.init) --
	-- one EffectReplicator connection for the whole script, deferred + identity-8 so updateRemovalEffects'
	-- FireServer (AutoExtinguishFire) can't dispatch from the parallel Actor phase.

	function Removal.init()
		removalMaid:add(
			workspaceDescendantAdded:connect("Removal_WorkspaceDescendantAdded", onWorkspaceDescendantAdded)
		)
		removalMaid:add(
			workspaceDescendantRemoving:connect("Removal_WorkspaceDescendantRemoving", onWorkspaceDescendantRemoving)
		)

		removalMaid:add(renderStepped:connect("Removal_RenderStepped", updateRemoval))
		removalMaid:add(
			renderStepped:connect("Removal_NoKillBricksPersistent", updateNoKillBricksPersistent)
		)
		removalMaid:add(renderStepped:connect("Removal_NoBlind", updateNoBlindFast))

		EffectDispatcher.hook("added", updateRemovalEffects)

		for _, descendant in pairs(workspace:GetDescendants()) do
			onWorkspaceDescendantAdded(descendant)
		end
		if Configuration.expectToggleValue("NoKillBricks") then
			updateNoKillBricks()
		end

		if not LPH_OBFUSCATED or shared.Aero.verbose then
			Logger.warn("Removal initialized.")
		end
	end

	function Removal.detach()
		removalMaid:clean()

		resetNoBlind()
		restoreNoAcidWater()

		Logger.warn("Removal detached.")
	end

	return Removal
end)()
