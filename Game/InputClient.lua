---@note: Never call the roll function from the cache. We only need this to get the last roll move direction.
local InputClient = {
	sprintFunctionCache = nil,
	rollFunctionCache = nil,
}

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Game.KeyHandling
local KeyHandling = require("Game/KeyHandling")

---@module Game.SelfFire
local SelfFire = require("Game/SelfFire")

---@module Utility.TaskSpawner
local TaskSpawner = require("Utility/TaskSpawner")

local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")

local unreliableFireServer = Instance.new("UnreliableRemoteEvent").FireServer

local inputDataCache = nil

---@return table?
local getEffectModule = LPH_NO_VIRTUALIZE(function()
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return nil
	end

	return require(effectReplicator)
end)

local freefallTrack = nil
local slideJumpTrack = nil
local cancelLeftTrack = nil
local cancelRightTrack = nil
local jumpAnimTrack = nil
local crouchTrack = nil
local groundslideTrack = nil

local slideBodyVelocity = nil
local slideActive = false

local crouchActive = false
local crouchSession = 0

---@return boolean
local landedCheck = LPH_NO_VIRTUALIZE(function()
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	local humanController = InputClient.getHumanController()
	if not humanController then
		return
	end

	local sprintSpeed = effectReplicatorModule:FindEffect("SprintSpeed")
	if not sprintSpeed then
		return
	end

	local character = players.LocalPlayer.Character
	if not character then
		return
	end

	local characterHandler = character:FindFirstChild("CharacterHandler")
	local inputClient = characterHandler and characterHandler:FindFirstChild("InputClient")
	if not inputClient then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end

	local torso = character:FindFirstChild("Torso")
	if not torso then
		return
	end

	local groundSensor = humanController.GroundSensor
	if not groundSensor then
		return
	end

	local stopDodge = KeyHandling.getRemote("StopDodge")
	if not stopDodge then
		return
	end

	local inputData = InputClient.getInputData()
	if not inputData then
		return
	end

	local repDebris = replicatedStorage:FindFirstChild("Debris")
	if not repDebris then
		return
	end

	local sounds = replicatedStorage:FindFirstChild("Sounds")
	local sliding = sounds and sounds:FindFirstChild("Sliding")
	if not sliding then
		return
	end

	local modules = replicatedStorage:FindFirstChild("Modules")
	local vectorMaths = modules and modules:FindFirstChild("VectorMaths")
	local vectorMathModule = vectorMaths and require(vectorMaths)
	if not vectorMathModule then
		return
	end

	local sensedPart = groundSensor.SensedPart

	if not effectReplicatorModule:HasAny("Swimming", "ClientSwim", "Gliding", "Knocked") then
		if not sensedPart then
			return false
		end

		if sensedPart and sensedPart.CollisionGroup == "Ship" then
			effectReplicatorModule:EnsureEffect("OnShip")
		elseif effectReplicatorModule:HasEffect("OnShip") then
			effectReplicatorModule:RemoveEffectsOfClass("OnShip")
		end
	end

	if freefallTrack.IsPlaying then
		freefallTrack:Stop(0.15)
	end

	if not effectReplicatorModule:HasEffect("Falling") then
		return true
	end

	effectReplicatorModule:RemoveEffectsOfClass("Falling")
	effectReplicatorModule:RemoveEffectsOfClass("ShipJump")
	effectReplicatorModule:RemoveEffectsOfClass("WingDashCooldown")

	humanoid.Jump = false

	effectReplicatorModule:CreateEffect("Landed"):Debris(0.05)

	if effectReplicatorModule:HasEffect("SlideJumping") and not effectReplicatorModule:HasEffect("GravityField") then
		effectReplicatorModule:RemoveEffectsOfClass("SlideJumping")

		if sprintSpeed and sprintSpeed.Value >= 9 then
			sprintSpeed.Value = sprintSpeed.Value - 3
		end

		local lookVector = root.CFrame.LookVector * 3
		local slideJump = torso:FindFirstChild("SlideJump")

		if slideJump then
			slideJump:Destroy()
		end

		if effectReplicatorModule:HasEffect("Sprinting") then
			humanoid:LoadAnimation(inputClient.SlideJumpTransition):Play(nil, 0.65)
		else
			humanoid:LoadAnimation(inputClient.LandingAnim):Play(nil, 0.65)
		end

		if slideJumpTrack.IsPlaying and effectReplicatorModule:HasEffect("Equipped") then
			slideJumpTrack:Stop(0.15)
		end

		stopDodge:FireServer(inputData, effectReplicatorModule:HasEffect("LightAttack"), true)

		local lookVectorUnitMulti = lookVector.Unit * 50

		if sensedPart and sensedPart.AssemblyMass > root.AssemblyMass then
			lookVectorUnitMulti = lookVectorUnitMulti
				+ vectorMathModule.getVelocityAtPoint(sensedPart, groundSensor.HitFrame.Position)
		end

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Name = "SlideJump2"
		bodyVelocity.Velocity = lookVectorUnitMulti
		bodyVelocity.MaxForce = Vector3.new(80000, 80000, 80000, 0)
		bodyVelocity:AddTag("AllowedBM")
		bodyVelocity.Parent = torso

		repDebris:Fire(bodyVelocity, 0.2)

		local slidingSound = sliding:Clone()
		slidingSound.Parent = root
		slidingSound:Play()

		repDebris:Fire(slidingSound, 0.25)

		tweenService
			:Create(slidingSound, TweenInfo.new(0.25), {
				Volume = 0,
			})
			:Play()
	end

	task.delay(0.1, function()
		effectReplicatorModule:RemoveEffectsOfClass("WallJumpCD")
		effectReplicatorModule:RemoveEffectsOfClass("BigMomentum")
		task.wait(2)
	end)

	return true
end)

local freefallCheck = LPH_NO_VIRTUALIZE(function()
	if landedCheck() then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	local character = players.LocalPlayer.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	if effectReplicatorModule:HasEffect("OnShip") then
		effectReplicatorModule:RemoveEffectsOfClass("OnShip")
		effectReplicatorModule:EnsureEffect("ShipJump"):Debris(5, true)
	end

	effectReplicatorModule:EnsureEffect("Falling")

	local fallTime = tick() - (effectReplicatorModule:GetEffectEpoch("Falling") or 0)

	if
		effectReplicatorModule:HasAny("DashIt", "Jumped", "UsingAbility", "LightAttack", "Action")
		or root.AssemblyLinearVelocity.Y > 0
	then
		return freefallTrack.IsPlaying and freefallTrack:Stop(0.1)
	end

	if freefallTrack.IsPlaying then
		return
	end

	if fallTime > 0.5 and root.AssemblyLinearVelocity.Y < 0 then
		freefallTrack.Priority = Enum.AnimationPriority.Movement
		freefallTrack:Play(0.3)
	end
end)

---@return boolean
local inAirCheck = LPH_NO_VIRTUALIZE(function()
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	local character = players.LocalPlayer.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end

	if effectReplicatorModule:HasEffect("Swimming") then
		return false
	elseif humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return true
	elseif effectReplicatorModule:HasEffect("AirBorne") then
		return true
	else
		return false
	end
end)

---@return boolean
local movementCheck = LPH_NO_VIRTUALIZE(function()
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	if effectReplicatorModule:HasEffect("Action") then
		return false
	elseif effectReplicatorModule:HasEffect("NoParkour") then
		return false
	elseif effectReplicatorModule:HasEffect("Knocked") or effectReplicatorModule:HasEffect("Unconscious") then
		return false
	elseif effectReplicatorModule:HasEffect("Pinned") or effectReplicatorModule:HasEffect("Carried") then
		return false
	else
		return true
	end
end)

---@param tbl table
---@param value any
---@return boolean
local manualTableFind = LPH_NO_VIRTUALIZE(function(tbl, value)
	for _, val in next, tbl do
		if val ~= value then
			continue
		end

		return true
	end
end)

---@param tbl table
---@return boolean
local hasNonBooleans = LPH_NO_VIRTUALIZE(function(tbl)
	for _, value in next, tbl do
		if typeof(value) == "boolean" then
			continue
		end

		return false
	end

	return true
end)

---@param tbl table
local getTableLength = LPH_NO_VIRTUALIZE(function(tbl)
	local count = 0

	for _ in next, tbl do
		count = count + 1
	end

	return count
end)

---@param tbl table
local validateKeys = LPH_NO_VIRTUALIZE(function(tbl)
	local allowedKeys = {
		["Left"] = true,
		["Right"] = true,
		["W"] = true,
		["A"] = true,
		["S"] = true,
		["D"] = true,
		["Thumbstick1"] = true,
		["C"] = true,
		["f"] = true,
		["H"] = true,
		["Space"] = true,
		["ctrl"] = true,
	}

	for key, _ in next, tbl do
		if allowedKeys[key] then
			continue
		end

		return false
	end

	return true
end)

---@return Vector3?
InputClient.getLastRollMoveDirection = LPH_NO_VIRTUALIZE(function()
	local rollFunction = InputClient.rollFunctionCache
	if not rollFunction then
		return nil
	end

	local lastRollMoveDirection = nil

	for _, upvalue in next, debug.getupvalues(rollFunction) do
		if typeof(upvalue) ~= "Vector3" then
			continue
		end

		lastRollMoveDirection = upvalue
		break
	end

	if not lastRollMoveDirection then
		lastRollMoveDirection = Vector3.zero
	end

	if lastRollMoveDirection and typeof(lastRollMoveDirection) ~= "Vector3" then
		return nil
	end

	return lastRollMoveDirection
end)

---@return table?
InputClient.getHumanController = LPH_NO_VIRTUALIZE(function()
	---@note: Shouldn't be too many connections to PreSimulation.
	for _, connection in next, getconnections(runService.PreSimulation) do
		local func = connection.Function
		if not func then
			continue
		end

		if iscclosure(func) or isexecutorclosure(func) then
			continue
		end

		local upvalues = debug.getupvalues(func)
		if not upvalues then
			continue
		end

		for _, upvalue in next, upvalues do
			if typeof(upvalue) ~= "table" then
				continue
			end

			if upvalue.Jumping == nil then
				continue
			end

			return upvalue
		end
	end

	return nil
end)

---@return table?
InputClient.getInputData = LPH_NO_VIRTUALIZE(function()
	return inputDataCache
end)

---@param cframe CFrame
---@param ignoreChecks boolean
InputClient.left = LPH_NO_VIRTUALIZE(function(cframe, ignoreChecks, forceGround)
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	local character = players.LocalPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end

	if effectReplicatorModule:HasEffect("InDialogue") then
		return
	end

	local inputData = InputClient.getInputData()
	if not inputData then
		return Logger.warn("Cannot left click without input data.")
	end

	local leftClickRemote = KeyHandling.getRemote("LeftClick")
	if not leftClickRemote then
		return
	end

	if not ignoreChecks then
		if
			effectReplicatorModule:HasEffect("LightAttack")
			or effectReplicatorModule:HasEffect("CriticalAttack")
			or effectReplicatorModule:HasEffect("Followup")
			or effectReplicatorModule:HasEffect("Parried")
		then
			return
		end
	end

	---@note: Missing M1-Hold and Input Buffering functionality but I don't think the caller cares about it.
	-- forceGround forces a grounded m1 (no aerial), matching PR's m1_hold no_aerials behavior.
	local aerial = (not forceGround) and inAirCheck() or false
	-- Mark this as our own fire so the UnreliableFireServer hook passes it through (no re-block / re-mixup)
	-- without needing checkcaller() -- see Game/SelfFire.
	SelfFire.wrap(function()
		unreliableFireServer(leftClickRemote, aerial, cframe, inputData)
	end)
end)

---@param tool Tool
InputClient.amantra = LPH_NO_VIRTUALIZE(function(tool)
	local character = players.LocalPlayer.Character
	if not character then
		return Logger.warn("Cannot activate mantra without character.")
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return Logger.warn("Cannot activate mantra without humanoid root part.")
	end

	local characterHandler = character:FindFirstChild("CharacterHandler")
	if not characterHandler then
		return Logger.warn("Cannot activate mantra without character handler.")
	end

	local requests = characterHandler:FindFirstChild("Requests")
	if not requests then
		return Logger.warn("Cannot activate mantra without requests.")
	end

	local activateMantraRemote = requests:FindFirstChild("ActivateMantra")
	if not activateMantraRemote then
		return Logger.warn("Cannot activate mantra without ActivateMantra remote.")
	end

	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return Logger.warn("Cannot activate mantra without valid tool.")
	end

	activateMantraRemote:FireServer(tool)
end)

InputClient.crouch = LPH_NO_VIRTUALIZE(function()
	local character = players.LocalPlayer.Character
	if not character then
		return
	end

	local characterHandler = character:FindFirstChild("CharacterHandler")
	local requests = characterHandler and characterHandler:FindFirstChild("Requests")
	if not requests then
		return
	end

	local crouchRemote = requests:FindFirstChild("ServerCrouch")
	if not crouchRemote then
		return
	end

	local effectReplicatorModule = getEffectModule()
	if not effectReplicatorModule then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if crouchTrack then
		crouchTrack:Play()
	end

	crouchRemote:FireServer(true)
	effectReplicatorModule:CreateEffect("ClientCrouch")

	crouchActive = true
	crouchSession = crouchSession + 1
	local session = crouchSession

	task.spawn(function()
		while crouchActive and crouchSession == session and crouchTrack do
			if humanoid and humanoid.MoveDirection.Magnitude < 0.1 then
				crouchTrack:AdjustSpeed(0)
			elseif humanoid then
				crouchTrack:AdjustSpeed(humanoid.WalkSpeed / 15.5)
			end

			task.wait()
		end
	end)
end)

InputClient.uncrouch = LPH_NO_VIRTUALIZE(function()
	local character = players.LocalPlayer.Character
	if not character then
		return
	end

	local characterHandler = character:FindFirstChild("CharacterHandler")
	local requests = characterHandler and characterHandler:FindFirstChild("Requests")
	if not requests then
		return
	end

	local crouchRemote = requests:FindFirstChild("ServerCrouch")
	if not crouchRemote then
		return
	end

	local effectReplicatorModule = getEffectModule()
	if not effectReplicatorModule then
		return
	end

	crouchActive = false
	crouchRemote:FireServer(false)

	if crouchTrack then
		crouchTrack:Stop()
	end

	effectReplicatorModule:RemoveEffectsOfClass("ClientCrouch")
end)

InputClient.slide = LPH_NO_VIRTUALIZE(function()
	local character = players.LocalPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local serverSlide = KeyHandling.getRemote("ServerSlide")
	if not serverSlide then
		return
	end

	local effectReplicatorModule = getEffectModule()
	if not effectReplicatorModule then
		return
	end

	local characterHashes = replicatedStorage:FindFirstChild("CharacterHashes")
	local characterHashesModule = characterHashes and require(characterHashes)
	local hashData = characterHashesModule and characterHashesModule.Snap(character)

	local healthPercent = humanoid.Health / humanoid.MaxHealth
	if hashData and hashData["Endurance Runner"] then
		healthPercent = 0.25 + healthPercent * 0.75
	end

	local agility = character:FindFirstChild("PassiveAgility")
	local agilityValue = agility and agility.Value or 0
	local isDanger = effectReplicatorModule:HasEffect("DangerPvP")
	local speed = 20 + agilityValue * (isDanger and 0.4 or 0.5) * healthPercent

	if effectReplicatorModule:HasEffect("ClientDodge") then
		speed = speed + (isDanger and 3 or 10)
	end

	if hashData then
		local kongaRing = hashData["Konga's Clutch Ring"]
		local slick = hashData.Slick

		if kongaRing then
			speed = speed + (isDanger and 5 or 15)
		end

		if slick then
			speed = speed + (isDanger and 0 or 15)
		end

		if not kongaRing and not slick and effectReplicatorModule:FindEffect("BigMomentum") then
			speed = speed + 15
		end
	end

	if effectReplicatorModule:HasEffect("AirBorne") then
		speed = speed + 15
	end

	if effectReplicatorModule:HasEffect("SpeedSlide") then
		speed = speed + 10
	elseif effectReplicatorModule:HasEffect("WardingRadiance") then
		speed = speed + (isDanger and 7.5 or 15)
	end

	local slideEffect = effectReplicatorModule:CreateEffect("ClientSlide2")
	slideEffect:Debris(60)

	if groundslideTrack then
		groundslideTrack:Play()
	end

	serverSlide:FireServer(true)

	local rootCollider = character:FindFirstChild("RootCollider")
	local colliderWeld = rootCollider and rootCollider:FindFirstChild("ColliderWeld")
	if colliderWeld then
		colliderWeld.C0 = CFrame.new(0, -1.9, 0)
	end

	local velocity = root.CFrame.LookVector * speed
	root.AssemblyLinearVelocity = velocity

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity:AddTag("LocalMover")
	bodyVelocity.Name = "SlideVel"
	bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVelocity.Velocity = velocity
	bodyVelocity:AddTag("AllowedBM")
	bodyVelocity.Parent = root

	slideBodyVelocity = bodyVelocity
	slideActive = true

	task.spawn(function()
		while slideActive and bodyVelocity.Parent do
			task.wait(0.03)

			local isIce = humanoid.FloorMaterial == Enum.Material.Ice
				and not (
					hashData
					and (
						hashData["Steady Footing"]
						or effectReplicatorModule:HasEffect("WardingRadiance")
					)
				)

			speed = speed - (isIce and 0.25 or 1)
			if speed <= 0 then
				break
			end

			bodyVelocity.Velocity = root.CFrame.LookVector * speed
		end
	end)

	task.delay(3, function()
		if slideActive then
			InputClient.unslide()
		end
	end)
end)

InputClient.unslide = LPH_NO_VIRTUALIZE(function()
	slideActive = false

	local serverSlideStop = KeyHandling.getRemote("ServerSlideStop")
	if serverSlideStop then
		serverSlideStop:FireServer()
	end

	if slideBodyVelocity and slideBodyVelocity.Parent then
		slideBodyVelocity:Destroy()
		slideBodyVelocity = nil
	end

	local character = players.LocalPlayer.Character
	if character then
		local rootCollider = character:FindFirstChild("RootCollider")
		local colliderWeld = rootCollider and rootCollider:FindFirstChild("ColliderWeld")
		if colliderWeld then
			colliderWeld.C0 = CFrame.new()
		end
	end

	if groundslideTrack then
		groundslideTrack:Stop()
	end

	local effectReplicatorModule = getEffectModule()
	if effectReplicatorModule then
		effectReplicatorModule:RemoveEffectsOfClass("ClientSlide2")
	end
end)

InputClient.vent = LPH_NO_VIRTUALIZE(function()
	local character = players.LocalPlayer.Character
	if not character then
		return Logger.warn("Cannot vent without character.")
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return Logger.warn("Cannot vent without humanoid root part.")
	end

	local characterHandler = character:FindFirstChild("CharacterHandler")
	if not characterHandler then
		return Logger.warn("Cannot vent without character handler.")
	end

	local requests = characterHandler:FindFirstChild("Requests")
	if not requests then
		return Logger.warn("Cannot vent without requests.")
	end

	local ventRemote = requests:FindFirstChild("Vent")
	if not ventRemote then
		return Logger.warn("Cannot vent without vent remote.")
	end

	ventRemote:FireServer()
end)

---@param options DodgeOptions
InputClient.dodge = LPH_NO_VIRTUALIZE(function(options)
	-- Dodge is now a DIRECT remote (no longer keyed via KeyHandler), so getRemote("Dodge") returns nil.
	-- Resolve it by name from CharacterHandler.Requests (where the other combat remotes live), falling
	-- back to the global ReplicatedStorage.Requests.
	local dodgeCharacter = players.LocalPlayer and players.LocalPlayer.Character
	local dodgeHandler = dodgeCharacter and dodgeCharacter:FindFirstChild("CharacterHandler")
	local dodgeRequests = dodgeHandler and dodgeHandler:FindFirstChild("Requests")
	local dodge = dodgeRequests and dodgeRequests:FindFirstChild("Dodge")
	if not dodge then
		local globalRequests = replicatedStorage:FindFirstChild("Requests")
		dodge = globalRequests and globalRequests:FindFirstChild("Dodge")
	end
	if not dodge then
		return Logger.warn("Cannot dodge without dodge remote.")
	end

	local stopDodge = KeyHandling.getRemote("StopDodge")
	if not stopDodge then
		return Logger.warn("Cannot dodge without stop dodge remote.")
	end

	local inputData = InputClient.getInputData()
	if not inputData then
		return Logger.warn("Cannot dodge without input data.")
	end

	local effectReplicatorModule = getEffectModule()
	if not effectReplicatorModule then
		return Logger.warn("Cannot dodge without effect replicator module.")
	end

	if options.direct and not options.full then
		-- New Dodge signature: FireServer(dodgeType, optionsTable). The game passes
		-- { ancient, spin_attack, in_air }; the old (type, nil, nil, false) form is now wrong args.
		dodge:FireServer("roll", { ancient = false, spin_attack = effectReplicatorModule:HasEffect("SpinAttack"), in_air = false })

		task.delay(0.15, function()
			stopDodge:FireServer(inputData, effectReplicatorModule:HasEffect("LightAttack"), true)
		end)

		return
	end

	local keybinds = replicatedStorage:FindFirstChild("KeyBinds")
	local keybindsModule = keybinds and require(keybinds)
	if not keybindsModule or not keybindsModule.ForceActionDown or not keybindsModule.ForceActionUp then
		return Logger.warn("Cannot dodge without keybinds module.")
	end

	keybindsModule.ForceActionDown("Dodge")
	keybindsModule.ForceActionUp("Dodge")

	if options.rollCancel then
		task.wait(options.rollCancelDelay)

		local clientFeint = effectReplicatorModule:CreateEffect("ClientFeint")
		if clientFeint then
			clientFeint:Debris(0.1)
		end
	end
end)

InputClient.ejump = LPH_NO_VIRTUALIZE(function()
	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return Logger.warn("Cannot dodge without effect replicator.")
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return Logger.warn("Cannot dodge without effect replicator module.")
	end

	if not jumpAnimTrack then
		return Logger.warn("Cannot jump without jump animation track.")
	end

	local character = players.LocalPlayer.Character
	if not character then
		return Logger.warn("Cannot jump without character.")
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return Logger.warn("Cannot jump without humanoid root part.")
	end

	local characterHandler = character:FindFirstChild("CharacterHandler")
	if not characterHandler then
		return Logger.warn("Cannot jump without character handler.")
	end

	local requests = characterHandler:FindFirstChild("Requests")
	if not requests then
		return Logger.warn("Cannot jump without requests.")
	end

	local jumpRemote = requests:FindFirstChild("Jump")
	if not jumpRemote then
		return Logger.warn("Cannot jump without jump remote.")
	end

	effectReplicatorModule:CreateEffect("Jumped"):Debris(0.1)
	jumpAnimTrack:Play(0.05)

	if effectReplicatorModule:HasEffect("HasWeapon") then
		jumpAnimTrack.Priority = Enum.AnimationPriority.Idle
	else
		jumpAnimTrack.Priority = Enum.AnimationPriority.Movement
	end

	TaskSpawner.delay("InputClient_EJump_Track", function()
		return 0.4
	end, function()
		jumpAnimTrack:AdjustSpeed(0.5)
		jumpAnimTrack:Stop(0.1)
	end)

	TaskSpawner.spawn("InputClient_EJump_Loop", function()
		local start = os.clock()

		while task.wait() do
			if os.clock() - start >= 0.2 then
				break
			end

			if not jumpAnimTrack or not jumpAnimTrack.IsPlaying then
				break
			end

			jumpRemote:FireServer()
		end
	end)
end)

InputClient.feint = LPH_NO_VIRTUALIZE(function()
	local character = players.LocalPlayer.Character
	if not character then
		return Logger.warn("Cannot feint without character.")
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return Logger.warn("Cannot feint without humanoid root part.")
	end

	local characterHandler = character:FindFirstChild("CharacterHandler")
	if not characterHandler then
		return Logger.warn("Cannot feint without character handler.")
	end

	local requests = characterHandler:FindFirstChild("Requests")
	if not requests then
		return Logger.warn("Cannot feint without requests.")
	end

	local feintReleaseRemote = requests:FindFirstChild("FeintRelease")
	if not feintReleaseRemote then
		return Logger.warn("Cannot feint without feint release remote.")
	end

	local inputDataTable = InputClient.getInputData()
	if not inputDataTable then
		return Logger.warn("Cannot feint without input data.")
	end

	local feintClickRemote = KeyHandling.getRemote("FeintClick")
	if not feintClickRemote then
		return Logger.warn("Cannot feint without feint click remote.")
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return Logger.warn("Cannot dodge without effect replicator.")
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return Logger.warn("Cannot dodge without effect replicator module.")
	end

	if effectReplicatorModule:HasEffect("ClientDodge") then
		effectReplicatorModule:CreateEffect("ClientFeint"):Debris(0.4)
	end

	if humanoidRootPart:FindFirstChild("ClientRemove") then
		humanoidRootPart.ClientRemove:Destroy()
	end

	inputDataTable["Right"] = true

	-- Our own feint fire -- flag it so the UnreliableFireServer hook passes it through (see Game/SelfFire).
	SelfFire.wrap(function()
		feintClickRemote:FireServer(inputDataTable)
	end)

	-- New FeintRelease signature takes no argument (was: inputDataTable).
	feintReleaseRemote:FireServer()

	inputDataTable["Right"] = false
end)

---@note: I sold my soul to the GC gods because there's no other way. This basically does a ton of intensive stuff. Updates are only done when needed.
InputClient.cache = LPH_NO_VIRTUALIZE(function()
	InputClient.sprintFunctionCache = nil
	InputClient.rollFunctionCache = nil
	inputDataCache = nil

	for _, value in next, getgc() do
		if typeof(value) ~= "function" or iscclosure(value) or isexecutorclosure(value) then
			continue
		end

		local functionName = debug.getinfo(value).name
		if not functionName then
			continue
		end

		if functionName ~= "Sprint" and functionName ~= "Roll" then
			continue
		end

		local upvalues = debug.getupvalues(value)

		if not upvalues or #upvalues <= 0 then
			continue
		end

		if functionName == "Sprint" then
			InputClient.sprintFunctionCache = value

			if not LPH_OBFUSCATED or shared.Aero.verbose then
				Logger.warn("Sprint function (%s) cache successful.", tostring(value))
			end
		end

		if functionName == "Roll" then
			InputClient.rollFunctionCache = value

			if not LPH_OBFUSCATED or shared.Aero.verbose then
				Logger.warn("Roll function (%s) cache successful.", tostring(value))
			end
		end

		if InputClient.sprintFunctionCache and InputClient.rollFunctionCache then
			break
		end
	end

	local inputData = {}

	for _, connection in next, getconnections(runService.RenderStepped) do
		local func = connection.Function
		if not func then
			continue
		end

		if iscclosure(func) then
			continue
		end

		local consts = debug.getconstants(func)
		if not manualTableFind(consts, ".lastHBCheck") then
			continue
		end

		local upvalues = debug.getupvalues(func)

		---@note: Only table with boolean values is the input table. Find a better way to filter this?
		for _, upvalue in next, upvalues do
			if typeof(upvalue) ~= "table" or getrawmetatable(upvalue) then
				continue
			end

			if not hasNonBooleans(upvalue) then
				continue
			end

			if getTableLength(upvalue) >= 1 and not validateKeys(upvalue) then
				continue
			end

			inputData = upvalue
			break
		end
	end

	inputDataCache = inputData

	local assets = replicatedStorage:FindFirstChild("Assets")
	local anims = assets and assets:FindFirstChild("Anims")
	local movement = anims and anims:FindFirstChild("Movement")
	local roll = movement and movement:FindFirstChild("Roll")
	local cancelLeft = roll and roll:FindFirstChild("CancelLeft")
	local cancelRight = roll and roll:FindFirstChild("CancelRight")

	local character = players.LocalPlayer.Character
	local characterHandler = character and character:FindFirstChild("CharacterHandler")
	local inputClient = characterHandler and characterHandler:FindFirstChild("InputClient")
	local freefallAnim = inputClient and inputClient:FindFirstChild("FreefallAnim")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local slideJumpAnim = inputClient and inputClient:FindFirstChild("SlideJump")
	local jumpAnim = inputClient and inputClient:FindFirstChild("Jump")
	local crouchAnim = movement and movement:FindFirstChild("Crouch")
	local groundslideAnim = movement and movement:FindFirstChild("Groundslide")

	if not slideJumpAnim or not jumpAnim or not humanoid or not cancelLeft or not cancelRight or not freefallAnim then
		return false
	end

	---@note: Tracks are reset on CharacterAdded, so retries must not load a fresh copy each time.
	slideJumpTrack = slideJumpTrack or humanoid:LoadAnimation(slideJumpAnim)
	freefallTrack = freefallTrack or humanoid:LoadAnimation(freefallAnim)
	cancelLeftTrack = cancelLeftTrack or humanoid:LoadAnimation(cancelLeft)
	cancelRightTrack = cancelRightTrack or humanoid:LoadAnimation(cancelRight)
	jumpAnimTrack = jumpAnimTrack or humanoid:LoadAnimation(jumpAnim)

	if crouchAnim then
		crouchTrack = crouchTrack or humanoid:LoadAnimation(crouchAnim)
	end

	if groundslideAnim then
		groundslideTrack = groundslideTrack or humanoid:LoadAnimation(groundslideAnim)
	end

	return InputClient.sprintFunctionCache ~= nil and InputClient.rollFunctionCache ~= nil and inputDataCache ~= nil
end)

-- Re-populate the caches on the MAIN thread (serial phase), bounded + retried. This used to be driven by the
-- global `tostring` hook in Hooking.lua, but that hook is invoked from EVERY Luau VM, so the
-- getgc / getconnections / LoadAnimation work inside cache() could run during Deepwoken's parallel Actor
-- phase and Kernel-panic the client (RSL - panic: ...Kernel). A plain task.spawn keeps all of those main-VM
-- ops in the serial phase, where they're legal. cache() returns true only once the game's Sprint/Roll
-- functions and the inputData table exist, so retry until it succeeds (or a newer character supersedes this
-- run via the session bump), then STOP -- steady-state cost is zero, no periodic getgc scanning.
local cacheSession = 0
InputClient.ensureCached = LPH_NO_VIRTUALIZE(function()
	cacheSession = cacheSession + 1
	local session = cacheSession

	task.spawn(function()
		local attempts = 0
		while cacheSession == session and attempts < 40 do
			local ok, success = pcall(InputClient.cache)
			if ok and success then
				break
			end
			attempts = attempts + 1
			task.wait(0.5)
		end
	end)
end)

local characterAddedConnection = players.LocalPlayer.CharacterAdded:Connect(function()
	InputClient.sprintFunctionCache = nil
	InputClient.rollFunctionCache = nil
	inputDataCache = nil

	freefallTrack = nil
	slideJumpTrack = nil
	cancelLeftTrack = nil
	cancelRightTrack = nil
	jumpAnimTrack = nil
	crouchTrack = nil
	groundslideTrack = nil

	if slideBodyVelocity and slideBodyVelocity.Parent then
		slideBodyVelocity:Destroy()
	end

	slideBodyVelocity = nil
	slideActive = false
	crouchActive = false

	-- Re-grab Sprint/Roll/inputData + animation tracks for the new character, on the main thread.
	InputClient.ensureCached()
end)

-- Prime the cache for a character that already exists at load time (re-exec / late inject), since the
-- CharacterAdded above won't fire for it.
if players.LocalPlayer.Character then
	InputClient.ensureCached()
end

function InputClient.detach()
	cacheSession = cacheSession + 1
	characterAddedConnection:Disconnect()
end

return InputClient
