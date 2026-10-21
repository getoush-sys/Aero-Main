return LPH_NO_VIRTUALIZE(function()
	local Maid = require("Utility/Maid")

	local Signal = require("Utility/Signal")

	local Configuration = require("Utility/Configuration")

	local Logger = require("Utility/Logger")

	local SaveManager = require("Game/Timings/SaveManager")

	local RevealAnimations = {}

	local runService = game:GetService("RunService")
	local players = game:GetService("Players")
	local collectionService = game:GetService("CollectionService")

	local revealAnimationsMaid = Maid.new()

	local renderStepped = Signal.new(runService.RenderStepped)

	local lastUpdateTime = 0
	local updateThrottleTime = 0.03
	local weightValue = 1
	local modifiedAnimations = {}

	local function checkAnimationTrack(animationTrack)
		local priority = animationTrack.Priority

		if
			priority == Enum.AnimationPriority.Action2
			or priority == Enum.AnimationPriority.Action3
			or priority == Enum.AnimationPriority.Action4
		then
			return 0
		end

		if priority == Enum.AnimationPriority.Core or priority == Enum.AnimationPriority.Idle then
			return weightValue
		end

		if animationTrack.WeightCurrent <= 0.01 then
			return weightValue
		end

		local threshold = tonumber(Configuration.expectOptionValue("RevealWeightThreshold")) or 0.5

		if animationTrack.WeightCurrent < threshold then
			return weightValue
		end

		return nil
	end

	local function updateRevealAnimations()
		if not Configuration.expectToggleValue("RevealAnimations") then
			for animationTrack in pairs(modifiedAnimations) do
				if animationTrack.Parent then
					pcall(function()
						collectionService:RemoveTag(animationTrack, "RevealAnimationsModified")
					end)
				end
			end
			modifiedAnimations = {}
			return
		end

		local currentTime = os.clock()

		if currentTime - lastUpdateTime < updateThrottleTime then
			return
		end

		lastUpdateTime = currentTime

		local localPlayer = players.LocalPlayer
		if not localPlayer then
			return
		end

		for _, player in ipairs(players:GetPlayers()) do
			if player == localPlayer then
				continue
			end

			local character = player.Character

			if not character then
				continue
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				continue
			end

			local animator = humanoid:FindFirstChildOfClass("Animator")
			if not animator then
				continue
			end

			local success, animationTracks = pcall(function()
				return animator:GetPlayingAnimationTracks()
			end)

			if not success then
				continue
			end

			for _, animationTrack in ipairs(animationTracks) do
				if SaveManager.as:index(tostring(animationTrack.Animation.AnimationId)) ~= nil then
					continue
				end

				local adjustWeight = checkAnimationTrack(animationTrack)

				if adjustWeight ~= nil then
					pcall(function()
						animationTrack:AdjustWeight(adjustWeight, 0)
						if not collectionService:HasTag(animationTrack, "RevealAnimationsModified") then
							collectionService:AddTag(animationTrack, "RevealAnimationsModified")
							modifiedAnimations[animationTrack] = true
						end
					end)
				end
			end
		end
	end

	function RevealAnimations.init()
		if not LPH_OBFUSCATED or shared.Aero.verbose then
			Logger.warn("RevealAnimations initialized.")
		end
		revealAnimationsMaid:add(renderStepped:connect("RevealAnimations_RenderStepped", updateRevealAnimations))
	end

	function RevealAnimations.detach()
		Logger.warn("RevealAnimations detached.")
		for animationTrack in pairs(modifiedAnimations) do
			if animationTrack.Parent then
				pcall(function()
					collectionService:RemoveTag(animationTrack, "RevealAnimationsModified")
				end)
			end
		end
		modifiedAnimations = {}
		revealAnimationsMaid:clean()
	end

	return RevealAnimations
end)
