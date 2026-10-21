---@note: Glorified extended non-utility Entities file.
local Targeting = {}

local DEFAULT_KEYS = {
	fov = "FOVLimit",
	distance = "DistanceLimit",
	maxTargets = "MaxTargets",
	selectionType = "PlayerSelectionType",
}

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Game.PlayerScanning
local PlayerScanning = require("Game/PlayerScanning")

---@module Features.Combat.Objects.Target
local Target = require("Features/Combat/Objects/Target")

---@module Utility.Table
local Table = require("Utility/Table")

local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService")

---@return Target[]
Targeting.viable = LPH_NO_VIRTUALIZE(function(keys)
	keys = keys or DEFAULT_KEYS

	local live = workspace:FindFirstChild("Live")
	if not live then
		return {}
	end

	local localCharacter = players.LocalPlayer.Character
	if not localCharacter then
		return {}
	end

	local localRootPart = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
	if not localRootPart then
		return {}
	end

	local currentCamera = workspace.CurrentCamera
	if not currentCamera then
		return {}
	end

	local targets = {}

	local fieldOfViewLimit = Configuration.expectOptionValue(keys.fov)
	local distanceLimit = Configuration.expectOptionValue(keys.distance)
	if not fieldOfViewLimit or not distanceLimit or fieldOfViewLimit <= 0 then
		return targets
	end

	local fieldOfViewCos = math.cos(math.rad(fieldOfViewLimit))

	for _, entity in next, live:GetChildren() do
		if entity == localCharacter then
			continue
		end

		local playerFromCharacter = players:GetPlayerFromCharacter(entity)
		if not playerFromCharacter and Configuration.expectToggleValue("IgnoreMobs") then
			continue
		end

		if playerFromCharacter and Configuration.expectToggleValue("IgnorePlayers") then
			continue
		end

		local humanoid = entity:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then
			continue
		end

		local rootPart = entity:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			continue
		end

		if humanoid.Health <= 0 then
			continue
		end

		if
			playerFromCharacter
			and PlayerScanning.isAlly(playerFromCharacter)
			and Configuration.expectToggleValue("IgnoreAllies")
		then
			continue
		end

		local fieldOfViewToEntity =
			currentCamera.CFrame.LookVector:Dot((localRootPart.Position - rootPart.Position).Unit)

		if (fieldOfViewToEntity * -1) <= fieldOfViewCos then
			continue
		end

		local currentDistance = (rootPart.Position - localRootPart.Position).Magnitude
		if currentDistance > distanceLimit then
			continue
		end

		local mousePosition = userInputService:GetMouseLocation()
		local unitRay = workspace.CurrentCamera:ScreenPointToRay(mousePosition.X, mousePosition.Y)
		local distanceToCrosshair = unitRay:Distance(rootPart.Position)

		targets[#targets + 1] =
			Target.new(entity, humanoid, rootPart, distanceToCrosshair, fieldOfViewToEntity, currentDistance)
	end

	return targets
end)

---@return Target[]
Targeting.best = LPH_NO_VIRTUALIZE(function(keys)
	keys = keys or DEFAULT_KEYS

	local targets = Targeting.viable(keys)
	local sortType = Configuration.expectOptionValue(keys.selectionType)
	local sortFunction = nil

	if sortType == "Closest To Crosshair" then
		sortFunction = function(first, second)
			return first.dc < second.dc
		end
	end

	if sortType == "Closest In Distance" then
		sortFunction = function(first, second)
			return first.du < second.du
		end
	end

	if sortType == "Least Health" then
		sortFunction = function(first, second)
			return first.humanoid.Health < second.humanoid.Health
		end
	end

	if sortFunction then
		table.sort(targets, sortFunction)
	end

	return Table.slice(targets, 1, Configuration.expectOptionValue(keys.maxTargets))
end)

---@param model Model
---@return Target?
Targeting.find = LPH_NO_VIRTUALIZE(function(model, keys)
	for _, target in next, Targeting.best(keys) do
		if target.character ~= model then
			continue
		end

		return target
	end
end)

return Targeting
