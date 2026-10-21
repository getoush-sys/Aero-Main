---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.OriginalStoreManager
local OriginalStoreManager = require("Utility/OriginalStoreManager")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Freecam
local Freecam = require("Utility/Freecam")

local movementMaid = Maid.new()

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local collectionService = game:GetService("CollectionService")
local animationInstance = Instance.new("Animation")
animationInstance.AnimationId = "rbxassetid://12106091136"

return LPH_NO_VIRTUALIZE(function()
	local Movement = {}

	---@module Utility.Signal
	local Signal = require("Utility/Signal")

	---@module Utility.InstanceWrapper
	local InstanceWrapper = require("Utility/InstanceWrapper")

	---@module Utility.OriginalStore
	local OriginalStore = require("Utility/OriginalStore")

	---@module Utility.ControlModule
	local ControlModule = require("Utility/ControlModule")

	---@module Utility.Finder
	local Finder = require("Utility/Finder")

	---@module Features.Game.Tweening
	local Tweening = require("Features/Game/Tweening")

	---@module Utility.Logger
	local Logger = require("Utility/Logger")

	---@module Game.Timings.SaveManager
	local SaveManager = require("Game/Timings/SaveManager")

	local runService = game:GetService("RunService")
	local userInputService = game:GetService("UserInputService")

	local agilitySpoofer = movementMaid:mark(OriginalStore.new())

	local noClipMap = movementMaid:mark(OriginalStoreManager.new())

	local preSimulation = Signal.new(runService.PreSimulation)
	local heartbeat = Signal.new(runService.Heartbeat)

	local cachedTarget = nil

	-- Infinite zoom out: remember the original max zoom so we can restore it when the toggle is off.
	local originalMaxZoom = nil
	local objectiveTarget = nil
	local objectiveActive = false
	local nextObjectiveScan = 0
	local objectiveNotFoundNotified = false

	local noClipSpoofedClasses = { PrepareTP = true, TPSafe = true }
	local oldEffectReplicatorHasAny = nil
	local noClipHasAnyHooked = false

	local function onNoClipHasAny(effectReplicatorSelf, ...)
		if Configuration.expectToggleValue("NoClip") then
			for _, class in next, { ... } do
				if noClipSpoofedClasses[class] then
					return true
				end
			end
		end

		return oldEffectReplicatorHasAny(effectReplicatorSelf, ...)
	end

	local function updateNoClipHasAnyHook(enabled)
		local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
		local effectReplicatorModule = effectReplicator and require(effectReplicator)

		if not effectReplicatorModule or typeof(effectReplicatorModule.HasAny) ~= "function" then
			return
		end

		if enabled and not noClipHasAnyHooked then
			oldEffectReplicatorHasAny = effectReplicatorModule.HasAny
			effectReplicatorModule.HasAny = onNoClipHasAny
			noClipHasAnyHooked = true
		elseif not enabled and noClipHasAnyHooked then
			effectReplicatorModule.HasAny = oldEffectReplicatorHasAny
			oldEffectReplicatorHasAny = nil
			noClipHasAnyHooked = false
		end
	end

	---@param character Model
	---@param rootPart BasePart
	local function updateNoClip(character, rootPart)
		local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
		if not effectReplicator then
			return
		end

		local controllerManager = character:FindFirstChild("ControllerManager")
		if not controllerManager then
			return
		end

		local airController = controllerManager:FindFirstChild("AirController")
		if not airController then
			return
		end

		local groundController = controllerManager:FindFirstChild("GroundController")
		if not groundController then
			return
		end

		if Configuration.expectToggleValue("Fly") then
			controllerManager.ActiveController = airController
		else
			controllerManager.ActiveController = groundController
		end

		local effectReplicatorModule = require(effectReplicator)
		local knockedRestore = effectReplicatorModule:FindEffect("Knocked")
			and Configuration.expectToggleValue("NoClipCollisionsKnocked")

		if Tweening.active then
			knockedRestore = false
		end

		for _, instance in pairs(character:GetChildren()) do
			if not instance:IsA("BasePart") then
				continue
			end

			noClipMap:add(instance, "CanCollide", knockedRestore and noClipMap:get(instance):get() or false)

			local bone = instance:FindFirstChild("Bone")
			if not bone then
				continue
			end

			local success, result = pcall(function()
				return bone.CanCollide ~= nil
			end)

			if not success or not result then
				continue
			end

			noClipMap:add(bone, "CanCollide", knockedRestore and noClipMap:get(bone):get() or false)
		end
	end


---@param rootPart BasePart
---@param humanoid Humanoid
---@param dt number
local function updateBoatfly(rootPart, humanoid, dt)
    local players = game:GetService("Players")
    local replicatedStorage = game:GetService("ReplicatedStorage")
    
    local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
    local effectReplicatorModule = effectReplicator and require(effectReplicator)
    
    if not effectReplicatorModule then
        return
    end

    local localPlayer = players.LocalPlayer
    local speed = 1000

    local steeringEffect = effectReplicatorModule:FindEffect("Steering")
    if not steeringEffect or not steeringEffect.Value then return end
    
    local steeringValue = steeringEffect.Value
    local ship = steeringValue:FindFirstAncestorWhichIsA("Model")
    if not ship then return end

    local character = localPlayer.Character
    local characterHandler = character and character:FindFirstChild("CharacterHandler")
    
    if characterHandler then
        local requests = characterHandler:FindFirstChild("Requests")
        local equipWeapon = requests and requests:FindFirstChild("DrawWeapon")
        if equipWeapon then
            equipWeapon:FireServer(true)
            equipWeapon:FireServer(false)
        end
    end

    local moveDirection = humanoid.MoveDirection

    if moveDirection.Magnitude > 0 then
        local velocityVector = moveDirection.Unit * speed
        local bv = ship:FindFirstChild("BodyVelocity", true)

        if bv then
            bv.Velocity = velocityVector
            bv.P = 99999
        else
            ship:TranslateBy(moveDirection.Unit * dt * speed)
        end
    else
        local bv = ship:FindFirstChild("BodyVelocity", true)
        if bv then
            bv.Velocity = Vector3.zero
            bv.P = 99999
        end
    end

    local shipControls = steeringValue:FindFirstChild("ShipControls")
    if shipControls then
        local args = {
            "s",
            true,
            rootPart.CFrame
        }
        shipControls:FireServer(unpack(args))
    end
end

	---@param rootPart BasePart
	---@param humanoid Humanoid
	local function updateSpeedHack(rootPart, humanoid)
		if Configuration.expectToggleValue("Fly") then
			return
		end

		rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity * Vector3.new(0, 1, 0)

		local moveDirection = humanoid.MoveDirection
		if moveDirection.Magnitude <= 0.001 then
			return
		end

		rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity
			+ moveDirection.Unit * Configuration.expectOptionValue("SpeedhackSpeed")
	end

	-- CFrame Speed (ported from mira): CFrame-based movement in the humanoid's move direction. Smoother
	-- than velocity speedhack; standalone from Speedhack.
	---@param rootPart BasePart
	---@param humanoid Humanoid
	---@param deltaTime number
	local function updateCFrameSpeed(rootPart, humanoid, deltaTime)
		if Configuration.expectToggleValue("Fly") then
			return
		end

		local moveDirection = humanoid.MoveDirection
		if not moveDirection or moveDirection.Magnitude <= 0.001 then
			return
		end

		local speed = Configuration.expectOptionValue("CFrameSpeedMultiplier") or 1
		rootPart.CFrame = rootPart.CFrame + moveDirection * (speed * deltaTime)
	end

	---@param rootPart BasePart
	local function updateInfiniteJump(rootPart)
		if Configuration.expectToggleValue("Fly") then
			return
		end

		if not userInputService:IsKeyDown(Enum.KeyCode.Space) then
			return
		end

		rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity
			+ Vector3.new(0, Configuration.expectOptionValue("InfiniteJumpBoost"), 0)
	end

	---@param rootPart BasePart
	---@param humanoid Humanoid
	local flyActive = false -- tracks fly on->off transitions so we restore the controller/sensor/speed-cap once

	-- Project Rain's fly: a tagged BodyVelocity driven by camera-relative WASD + Space/LeftControl, with any
	-- stray body-movers cleared each frame. The "AllowedBM" CollectionService tag is Deepwoken's body-mover
	-- allowlist, so the anticheat doesn't flag/strip it; OverrideSpeedCap uncaps speed while flying; the
	-- AirController + GroundSensor tweaks stop the ground controller from fighting the movement.
	local function updateFlyHack(character, rootPart, humanoid)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		if rootPart:FindFirstChild("HelioFlight") then
			rootPart.HelioFlight:Destroy()
		end

		-- Direction straight from the camera + held keys (PR).
		local look = camera.CFrame.LookVector
		local direction = Vector3.zero
		local keymap = {
			[Enum.KeyCode.W] = look,
			[Enum.KeyCode.S] = -look,
			[Enum.KeyCode.A] = Vector3.new(look.Z, 0, -look.X),
			[Enum.KeyCode.D] = Vector3.new(-look.Z, 0, look.X),
			[Enum.KeyCode.Space] = Vector3.new(0, 1, 0),
			[Enum.KeyCode.LeftControl] = Vector3.new(0, -1, 0),
		}
		for key, vec in pairs(keymap) do
			if userInputService:IsKeyDown(key) then
				direction = direction + vec
			end
		end
		if direction.Magnitude > 0 then
			direction = direction.Unit
		else
			direction = Vector3.zero
		end

		-- Clear stray body-movers, then (re)use our tagged one.
		local collectionService = game:GetService("CollectionService")
		for _, descendant in pairs(character:GetDescendants()) do
			if descendant:IsA("BodyVelocity") and descendant.Name ~= "LumaFly" then
				descendant:Destroy()
			end
		end

		local flyBodyVelocity = InstanceWrapper.create(movementMaid, "flyBodyVelocity", "BodyVelocity", rootPart)
		flyBodyVelocity.Name = "LumaFly"
		flyBodyVelocity.MaxForce = Vector3.new(1000000, 1000000, 1000000)
		pcall(function()
			collectionService:AddTag(flyBodyVelocity, "AllowedBM")
		end)

		-- Speed: user's FlySpeed, clamped higher while knocked (PR caps 250 / 350 knocked).
		local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
		local effectReplicatorModule = effectReplicator and require(effectReplicator)
		local knocked = effectReplicatorModule and effectReplicatorModule:FindEffect("Knocked")
		local speed = math.min(knocked and 350 or 250, Configuration.expectOptionValue("FlySpeed") or 50)

		flyBodyVelocity.Velocity = direction * speed

		-- Keep the air controller active + the ground sensor from grabbing us.
		local controllerManager = character:FindFirstChild("ControllerManager")
		if controllerManager then
			local airController = controllerManager:FindFirstChild("AirController")
			if airController then
				controllerManager.ActiveController = airController
			end
		end

		local groundSensor = rootPart:FindFirstChild("GroundSensor")
		if groundSensor then
			if Configuration.expectToggleValue("NoClip") then
				groundSensor.SensorMode = Enum.SensorMode.ClassicLadder
				groundSensor.UpdateType = Enum.SensorUpdateType.OnRead
			else
				groundSensor.SensorMode = Enum.SensorMode.Floor
				groundSensor.UpdateType = Enum.SensorUpdateType.Manual
			end
		end

		-- Uncap speed while flying.
		if effectReplicatorModule and not effectReplicatorModule:FindEffect("OverrideSpeedCap") then
			pcall(function()
				effectReplicatorModule:CreateEffect("OverrideSpeedCap")
			end)
		end
	end

	local lastMomentumUpdate = 0
	local function updateMaxMomentumSpoofer()
		if tick() - lastMomentumUpdate < 0.1 then
			return
		end
		lastMomentumUpdate = tick()

		local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
		local effectReplicatorModule = effectReplicator and require(effectReplicator)
		if not effectReplicatorModule then
			return
		end

		local forcedMomentumEffect = effectReplicatorModule:FindEffect("ForceMomentum")

		if not Configuration.expectToggleValue("MaxMomentumSpoof") then
			if forcedMomentumEffect then
				forcedMomentumEffect.Disabled = true
				forcedMomentumEffect.Value = 0
			end
			return
		end

		if not forcedMomentumEffect then
			return effectReplicatorModule:CreateEffect("ForceMomentum", { Value = 10 })
		end

		if forcedMomentumEffect.Value ~= 10 then
			forcedMomentumEffect.Value = 10
		end

		if forcedMomentumEffect.Disabled ~= false then
			forcedMomentumEffect.Disabled = false
		end
	end

	---@note: The client recomputes WalkSpeed from effects every frame, so a
	local function updateForceSpeedBuff()
		local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
		local effectReplicatorModule = effectReplicator and require(effectReplicator)
		if not effectReplicatorModule then
			return
		end

		local forceSpeedEffect = effectReplicatorModule:FindEffect("ForceSpeedBuff")

		if not Configuration.expectToggleValue("ForceSpeedBuff") then
			if forceSpeedEffect then
				forceSpeedEffect.Value = 0
				forceSpeedEffect.Disabled = true
			end
			return
		end

		if not forceSpeedEffect then
			return effectReplicatorModule:CreateEffect("ForceSpeedBuff")
		end

		local amount = Configuration.expectOptionValue("ForceSpeedBuffAmount") or 0.0
		if forceSpeedEffect.Value ~= amount then
			forceSpeedEffect.Value = amount
		end

		forceSpeedEffect.Disabled = false
	end

	---@param character Model
	local function updateAgilitySpoofer(character)
		local agility = character:FindFirstChild("PassiveAgility")
		if not agility then
			return
		end

		---@note: For every 10 investment points, there are two real agility points.
		local agilitySpoofValue = 8 + (Options.AgilitySpoof.Value / 10) * 2

		if Toggles.BoostAgilityDirectly.Value then
			agilitySpoofValue = Options.AgilitySpoof.Value
		end

		agilitySpoofer:set(agility, "Value", agilitySpoofValue)
	end

	local function updateTweenToBack()
		local validTargets = Finder.geir(300, Configuration.expectToggleValue("AttachIgnorePlayers"))
		if not validTargets then
			return true
		end

		local attachTarget = Configuration.expectToggleValue("StickyAttach") and cachedTarget or validTargets[1]
		if not attachTarget then
			return true
		end

		if not attachTarget.Parent then
			return false
		end

		local attachTargetHrp = attachTarget:FindFirstChild("HumanoidRootPart")
		if not attachTargetHrp then
			return false
		end

		local attachTargetHumanoid = attachTarget:FindFirstChild("Humanoid")
		if not attachTargetHumanoid then
			return false
		end

		if attachTargetHumanoid.Health <= 0 then
			return false
		end

		cachedTarget = cachedTarget or attachTarget

		local offsetCFrame = CFrame.new(
			0.0,
			Configuration.expectOptionValue("HeightOffset"),
			Configuration.expectOptionValue("BackOffset")
		)

		local targetPosition = (attachTargetHrp.CFrame * offsetCFrame).Position
		local goalCFrame = CFrame.lookAt(targetPosition, attachTargetHrp.Position)

		Tweening.goal("TweenToBack", goalCFrame, false)

		return true
	end

	local function getObjectiveCFrame(instance)
		if not instance or not instance:IsDescendantOf(workspace) then
			return nil
		end

		if instance:IsA("BasePart") then
			return instance.CFrame
		elseif instance:IsA("Model") then
			return instance:GetPivot()
		elseif instance:IsA("Attachment") then
			return instance.WorldCFrame
		end

		return nil
	end

	local function hasObjectiveName(instance)
		local name = string.lower(instance.Name)
		return string.find(name, "objective", 1, true) ~= nil
			or string.find(name, "questmarker", 1, true) ~= nil
	end

	local function findNearestObjective(position)
		local closest, closestDistance = nil, math.huge

		local function consider(instance)
			local cframe = getObjectiveCFrame(instance)
			if not cframe then
				return
			end

			local distance = (cframe.Position - position).Magnitude
			if distance < closestDistance then
				closest = instance
				closestDistance = distance
			end
		end

		for _, instance in next, workspace:GetDescendants() do
			if hasObjectiveName(instance) then
				consider(instance)
			end
		end

		for _, tag in next, { "Objective", "QuestObjective" } do
			for _, instance in next, collectionService:GetTagged(tag) do
				if instance:IsDescendantOf(workspace) then
					consider(instance)
				end
			end
		end

		return closest
	end

	local function updateTweenToObjective(rootPart)
		if Configuration.expectToggleValue("TweenToObjective") then
			objectiveActive = true
			if Toggles and Toggles.TweenToObjective then
				Toggles.TweenToObjective:SetValue(false)
			end
		end

		if not objectiveActive then
			return
		end

		if Configuration.expectToggleValue("TweenToBack") then
			objectiveActive = false
			objectiveTarget = nil
			Tweening.stop("TweenToObjective")
			return
		end
		for _, tween in next, Tweening.queue do
			if tween.identifier ~= "TweenToObjective" then
				objectiveActive = false
				objectiveTarget = nil
				Tweening.stop("TweenToObjective")
				return
			end
		end

		local now = os.clock()
		if now >= nextObjectiveScan or not getObjectiveCFrame(objectiveTarget) then
			objectiveTarget = findNearestObjective(rootPart.Position)
			nextObjectiveScan = now + 1
		end

		local targetCFrame = getObjectiveCFrame(objectiveTarget)
		if not targetCFrame then
			objectiveActive = false
			Tweening.stop("TweenToObjective")
			if not objectiveNotFoundNotified then
				Logger.notify("No active objective marker found.")
				objectiveNotFoundNotified = true
			end
			objectiveTarget = nil
			return
		end

		objectiveNotFoundNotified = false
		if (rootPart.Position - targetCFrame.Position).Magnitude <= 5 then
			objectiveActive = false
			objectiveTarget = nil
			Tweening.stop("TweenToObjective")
			return
		end

		Tweening.goal("TweenToObjective", targetCFrame, false, true)
	end

	-- Infinite zoom out: crank the local player's max camera zoom while enabled, restore it when off.
	local function updateInfiniteZoom()
		local localPlayer = players.LocalPlayer
		if not localPlayer then
			return
		end

		if Configuration.expectToggleValue("InfiniteZoom") then
			if originalMaxZoom == nil then
				originalMaxZoom = localPlayer.CameraMaxZoomDistance
			end
			-- Re-assert every frame; the game resets this on some state changes.
			if localPlayer.CameraMaxZoomDistance ~= 1000000 then
				localPlayer.CameraMaxZoomDistance = 1000000
			end
		elseif originalMaxZoom ~= nil then
			localPlayer.CameraMaxZoomDistance = originalMaxZoom
			originalMaxZoom = nil
		end
	end

	-- Freecam: Project Rain's freecam module. Detaches the camera (WASD move, Q/E down/up, mouse
	-- look, Up/Down adjust speed, LeftShift slow). The character stays put. The module runs its own
	-- BindToRenderStep, so this just enters/exits on the toggle and feeds the speed slider in.
	local function updateFreecam()
		if Configuration.expectToggleValue("Freecam") then
			if not Freecam.running() then
				Freecam.enter()
			end

			Freecam.set_speed((Configuration.expectOptionValue("FreecamSpeed") or 60) / 60)
		elseif Freecam.running() then
			Freecam.exit()
		end
	end

	---@param dt number
	local function updateMovement(dt)
		updateInfiniteZoom()
		updateFreecam(dt)

		local localPlayer = players.LocalPlayer
		local character = localPlayer.Character
		if not character then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end

		updateTweenToObjective(rootPart)

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then
			return
		end

		if not Configuration.expectToggleValue("TweenToBack") or not updateTweenToBack() then
			cachedTarget = nil
		end

		if Configuration.expectToggleValue("AgilitySpoof") then
			updateAgilitySpoofer(character)
		else
			agilitySpoofer:restore()
		end

		updateMaxMomentumSpoofer()

		updateForceSpeedBuff()

		if Tweening.active or Configuration.expectToggleValue("NoClip") then
			updateNoClip(character, rootPart)
			updateNoClipHasAnyHook(true)
		else
			noClipMap:restore()
			updateNoClipHasAnyHook(false)
		end

		if Tweening.active then
			return
		end

		if Configuration.expectToggleValue("Fly") then
			flyActive = true
			updateFlyHack(character, rootPart, humanoid)
		else
			movementMaid["flyBodyVelocity"] = nil
			if flyActive then
				flyActive = false
				-- Restore normal movement: hand control back to the ground controller, reset the ground
				-- sensor, and drop the speed-cap override the fly loop created.
				local controllerManager = character and character:FindFirstChild("ControllerManager")
				if controllerManager then
					local groundController = controllerManager:FindFirstChild("GroundController")
					if groundController then
						controllerManager.ActiveController = groundController
					end
				end
				local groundSensor = rootPart and rootPart:FindFirstChild("GroundSensor")
				if groundSensor then
					groundSensor.SensorMode = Enum.SensorMode.Floor
					groundSensor.UpdateType = Enum.SensorUpdateType.Manual
				end
				local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
				local effectReplicatorModule = effectReplicator and require(effectReplicator)
				local capEffect = effectReplicatorModule and effectReplicatorModule:FindEffect("OverrideSpeedCap")
				if capEffect then
					pcall(function()
						capEffect:Debris(1)
					end)
				end
			end
		end
		
		if Configuration.expectToggleValue("BoatSpeed") then
			updateBoatfly(rootPart, humanoid)
		end

		if Configuration.expectToggleValue("Speedhack") then
			updateSpeedHack(rootPart, humanoid)
		end

		-- CFrame Speed is standalone and can be used independently of Speedhack.
		if Configuration.expectToggleValue("CFrameSpeed") then
			updateCFrameSpeed(rootPart, humanoid, dt)
		end

		if Configuration.expectToggleValue("InfiniteJump") then
			updateInfiniteJump(rootPart)
		end
	end

	function Movement.init()
		movementMaid:add(preSimulation:connect("Movement_PreSimulation", updateMovement))
		movementMaid:add(heartbeat:connect("Movement_Heartbeat", Tweening.update))

		if not LPH_OBFUSCATED or shared.Aero.verbose then
			Logger.warn("Movement initialized.")
		end
	end

	function Movement.detach()
		movementMaid:clean()
		Tweening.stop("TweenToObjective")
		objectiveActive = false
		objectiveTarget = nil

		if Freecam.running() then
			Freecam.exit()
		end

		Logger.warn("Movement detached.")
	end

	return Movement
end)()
