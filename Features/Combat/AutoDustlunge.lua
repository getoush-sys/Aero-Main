local KeyHandling = require("Game/KeyHandling")

local InputClient = require("Game/InputClient")

local Latency = require("Game/Latency")

local Configuration = require("Utility/Configuration")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AutoDustlunge = {}

local HITBOX_SIZE = Vector3.new(2, 6, 10)
local HITBOX_SHIFT_BACK = -5
local TICK_INTERVAL = 1 / 5

local holdKeyPicker = nil
local running = false
local simulationPart = nil

function AutoDustlunge.setHoldKeyPicker(keyPicker)
	holdKeyPicker = keyPicker
end

local function cleanupSimulation()
	if simulationPart then
		simulationPart:Destroy()
		simulationPart = nil
	end
end

local function getEffectModule()
	local effectReplicator = ReplicatedStorage:FindFirstChild("EffectReplicator")
	return effectReplicator and require(effectReplicator)
end

local function setSprinting(state)
	local character = Players.LocalPlayer.Character
	local characterHandler = character and character:FindFirstChild("CharacterHandler")
	local requests = characterHandler and characterHandler:FindFirstChild("Requests")
	local sprintRemote = requests and requests:FindFirstChild("ServerSprint")
	if sprintRemote then
		sprintRemote:FireServer(state)
	end
end

local function runTick()
	local effectReplicatorModule = getEffectModule()
	if not effectReplicatorModule or effectReplicatorModule:FindEffect("GrabCD") then
		cleanupSimulation()
		return
	end

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local usedCFrame = root.CFrame * CFrame.new(0, 0, HITBOX_SHIFT_BACK)

	if not simulationPart or simulationPart.Parent ~= workspace then
		cleanupSimulation()
		simulationPart = Instance.new("Part")
		simulationPart.Name = "AutoDustlungeHitbox"
		simulationPart.Anchored = true
		simulationPart.CanCollide = false
		simulationPart.CanQuery = false
		simulationPart.CanTouch = false
		simulationPart.Material = Enum.Material.ForceField
		simulationPart.CastShadow = false
	end

	simulationPart.Transparency = Configuration.expectToggleValue("AutoDustlungeDebug") and 0.5 or 1.0
	simulationPart.Shape = Enum.PartType.Block
	simulationPart.Size = HITBOX_SIZE
	simulationPart.CFrame = usedCFrame
	simulationPart.Parent = workspace

	local live = workspace:FindFirstChild("Live")
	local instances = {}
	if live then
		for _, child in next, live:GetChildren() do
			if child ~= character then
				table.insert(instances, child)
			end
		end
	end

	if #instances <= 0 then
		return
	end

	local params = OverlapParams.new()
	params.FilterDescendantsInstances = instances
	params.FilterType = Enum.RaycastFilterType.Include

	local ok, parts = pcall(function()
		return workspace:GetPartsInPart(simulationPart, params)
	end)

	if not ok or not parts or #parts <= 0 then
		return
	end

	local targetCharacter = parts[1]:FindFirstAncestorWhichIsA("Model")
	local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
	local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetHumanoid or not targetRoot then
		return
	end

	local facingDot = (targetRoot.Position - root.Position):Dot(root.CFrame.LookVector)
	if facingDot <= 0 then
		return
	end

	local sprinting = effectReplicatorModule:FindEffect("Sprinting") ~= nil
	if sprinting then
		setSprinting(false)
		task.wait(1 / 20)
	end

	local scriptCrouched = false
	if not effectReplicatorModule:FindEffect("Crouching") then
		InputClient.crouch()
		scriptCrouched = true
	end

	local start = tick()
	local pingWindow = (Latency.rtt() or 0) * 2
	repeat
		task.wait()
	until effectReplicatorModule:FindEffect("Crouching") or tick() - start > pingWindow

	if tick() - start > pingWindow then
		if scriptCrouched then
			InputClient.uncrouch()
		end
		if sprinting then
			setSprinting(true)
		end
		return
	end

	task.spawn(function()
		local remote = KeyHandling.getRemote("LeftClick")
		if not remote then
			return
		end

		remote:FireServer(false, Players.LocalPlayer:GetMouse().Hit, {
			S = false,
			NOAERIALS = true,
			Space = false,
			Right = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2),
			W = false,
			Left = true,
			ctrl = false,
		})
	end)

	task.wait(1 / 20)

	if scriptCrouched then
		InputClient.uncrouch()
	else
		local vim = Instance.new("VirtualInputManager")
		vim:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
		vim:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
	end

	if sprinting then
		setSprinting(true)
	end
end

local function loop()
	while running do
		if not holdKeyPicker or not holdKeyPicker:GetState() then
			cleanupSimulation()
		else
			local ok, err = pcall(runTick)
			if not ok then
				cleanupSimulation()
			end
		end

		task.wait(TICK_INTERVAL)
	end
end

function AutoDustlunge.enable()
	if running then
		return
	end

	cleanupSimulation()
	running = true
	task.spawn(loop)
end

function AutoDustlunge.disable()
	running = false
	cleanupSimulation()
end

return AutoDustlunge
