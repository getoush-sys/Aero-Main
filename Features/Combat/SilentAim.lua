-- Silent Aim (ported from Project Rain).
--
-- Deepwoken resolves where your attacks/abilities go by asking the CLIENT two things:
--   1. Requests.GetCameraToMouse (RemoteFunction) -- "what CFrame is your camera->mouse aim?"
--   2. Requests.UpdateMouse (RemoteEvent, fired every frame) -- "where is your mouse pointing in world?"
-- We override (1) to hand back a CFrame aimed at the target under the FOV, and we fire (2) ourselves with
-- the target's predicted position. The game's own UpdateMouse is suppressed in Game/Hooking.lua's namecall
-- hook while this is on, so only our redirected position reaches the server.
--
-- When the toggle is off (or no target is in the FOV) the GetCameraToMouse override returns the exact same
-- value the stock client returns -- CFrame.lookAt(camera, real mouse hit) -- so it is behaviourally
-- identical to vanilla and safe to leave installed.

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Game.Latency
local Latency = require("Game/Latency")

---@module Game.PlayerScanning
local PlayerScanning = require("Game/PlayerScanning")

---@module GUI.Library
local Library = require("GUI/Library")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local SilentAim = {}

local localPlayer = Players.LocalPlayer

local TARGET_REFRESH = 1 / 8

local running = false
local installed = false
local renderConn = nil
local characterConn = nil
local currentTarget = nil
local lastTargetRefresh = 0
local lastSentPosition = nil

local fovCircle = nil
local outlineCircle = nil

local cachedEffectModule = nil

---@return any
local function getEffectModule()
	if cachedEffectModule then
		return cachedEffectModule
	end
	local effectReplicator = ReplicatedStorage:FindFirstChild("EffectReplicator")
	cachedEffectModule = effectReplicator and require(effectReplicator) or nil
	return cachedEffectModule
end

---@return boolean
local function hasCameraLock()
	local module = getEffectModule()
	if not module then
		return false
	end
	local ok, result = pcall(function()
		return module:HasEffect("CameraLock")
	end)
	return (ok and result) and true or false
end

---Strip NaN out of numbers/Vectors/CFrames so a bad target position can't desync us or trip a kick.
---@param value any
---@return any
local function safeNAN(value)
	if value == value then
		return value
	end

	if typeof(value) == "Vector3" then
		return Vector3.new(safeNAN(value.X), safeNAN(value.Y), safeNAN(value.Z))
	elseif typeof(value) == "CFrame" then
		local position = safeNAN(value.Position)
		local rotation = value.Rotation
		if rotation ~= rotation then
			rotation = CFrame.identity
		end
		return CFrame.new(position) * rotation
	elseif typeof(value) == "number" then
		return value == value and value or 0
	end

	return value
end

---@param entity Model
---@return BasePart?
local function getPrimary(entity)
	return entity.PrimaryPart or entity:FindFirstChild("HumanoidRootPart")
end

---Lead a target by one round-trip, scaled by the prediction slider.
---@param target Model
---@return Vector3?
local function predictedPosition(target)
	local primary = getPrimary(target)
	if not primary then
		return nil
	end
	local prediction = (Configuration.expectOptionValue("SilentAimPrediction") or 0) / 100
	local lead = primary.AssemblyLinearVelocity * (Latency.rtt() or 0) * prediction
	return primary.Position + lead
end

---The CFrame handed back to the server for GetCameraToMouse, aimed at the target.
---@param target Model
---@return CFrame?
local function getGCTM(target)
	local camera = workspace.CurrentCamera
	local aimPos = predictedPosition(target)
	if not camera or not aimPos then
		return nil
	end
	return safeNAN(CFrame.lookAt(camera.CFrame.Position, aimPos))
end

---Pick the entity in workspace.Live whose box falls inside the FOV circle around the cursor.
---@return Model?
local function getTarget()
	local live = workspace:FindFirstChild("Live")
	if not live then
		return nil
	end

	local camera = workspace.CurrentCamera
	local mouse = localPlayer and localPlayer:GetMouse()
	if not camera or not mouse then
		return nil
	end

	local targets = Configuration.expectOptionValue("SilentAimTargets") or {}
	local fovRadius = Configuration.expectOptionValue("SilentAimFOV") or 90

	local mouseX = mouse.X
	local mouseY = mouse.Y + GuiService:GetGuiInset().Y
	local character = localPlayer and localPlayer.Character

	for _, entity in next, live:GetChildren() do
		local isMob = entity.Name:sub(1, 1) == "."
		local isPlayer = not isMob

		if isMob and not targets.Mobs then
			continue
		end
		if isPlayer and not targets.Players then
			continue
		end
		if entity == character then
			continue
		end

		local primary = getPrimary(entity)
		if not primary then
			continue
		end

		if isPlayer then
			local player = Players:GetPlayerFromCharacter(entity)
			if player and PlayerScanning.isAlly(player) and not targets.Guildmates then
				continue
			end
		end

		-- 8 corners of a rough character box projected to screen; first corner inside the FOV wins.
		local size = Vector3.new(4, 5, 6)
		local base = primary.CFrame - (size / 2)
		local mins = base.Position
		local maxs = (base + size).Position

		local points = {
			Vector3.new(mins.X, mins.Y, mins.Z),
			Vector3.new(mins.X, maxs.Y, mins.Z),
			Vector3.new(maxs.X, maxs.Y, mins.Z),
			Vector3.new(maxs.X, mins.Y, mins.Z),
			Vector3.new(maxs.X, maxs.Y, maxs.Z),
			Vector3.new(mins.X, maxs.Y, maxs.Z),
			Vector3.new(mins.X, mins.Y, maxs.Z),
			Vector3.new(maxs.X, mins.Y, maxs.Z),
		}

		for _, point in next, points do
			local screenPoint, onScreen = camera:WorldToViewportPoint(point)
			if
				onScreen
				and screenPoint.X > mouseX - fovRadius
				and screenPoint.X < mouseX + fovRadius
				and screenPoint.Y > mouseY - fovRadius
				and screenPoint.Y < mouseY + fovRadius
			then
				return entity
			end
		end
	end

	return nil
end

---Install (or re-install after a respawn) the GetCameraToMouse override. Transparent passthrough when the
---toggle is off or no target is found.
local function installCameraHook()
	local requests = ReplicatedStorage:FindFirstChild("Requests")
	local getCameraToMouse = requests and requests:FindFirstChild("GetCameraToMouse")
	if not getCameraToMouse then
		return false
	end

	getCameraToMouse.OnClientInvoke = function()
		if Configuration.expectToggleValue("SilentAim") then
			local target = getTarget()
			if target then
				local cf = getGCTM(target)
				if cf then
					return cf, hasCameraLock()
				end
			end
		end

		-- Vanilla behaviour: aim at the real mouse hit (matches the stock client's handler exactly).
		local camera = workspace.CurrentCamera
		local mouse = localPlayer and localPlayer:GetMouse()
		local origin = camera and camera.CFrame.Position or Vector3.zero
		local hit = (mouse and mouse.Hit and mouse.Hit.Position) or origin
		return safeNAN(CFrame.lookAt(origin, hit)), hasCameraLock()
	end

	return true
end

local function ensureDrawings()
	if fovCircle then
		return
	end
	if not (Drawing and Drawing.new) then
		return
	end

	local ok = pcall(function()
		fovCircle = Drawing.new("Circle")
		fovCircle.Visible = false
		fovCircle.ZIndex = 2
		fovCircle.NumSides = 100
		fovCircle.Thickness = 1
		fovCircle.Filled = true
		fovCircle.Transparency = 0.3

		outlineCircle = Drawing.new("Circle")
		outlineCircle.Visible = false
		outlineCircle.ZIndex = 1
		outlineCircle.NumSides = 100
		outlineCircle.Thickness = 2
		outlineCircle.Filled = false
	end)

	if not ok then
		fovCircle = nil
		outlineCircle = nil
	end
end

local function destroyDrawings()
	for _, drawing in next, { fovCircle, outlineCircle } do
		pcall(function()
			drawing.Visible = false
			drawing:Remove()
		end)
	end
	fovCircle = nil
	outlineCircle = nil
end

local function onRender()
	local mouse = localPlayer and localPlayer:GetMouse()
	if not mouse then
		return
	end

	-- FOV circle (optional; only on executors with a Drawing library).
	ensureDrawings()
	if fovCircle and outlineCircle then
		local showFov = Configuration.expectToggleValue("SilentAimShowFOV")
		local radius = Configuration.expectOptionValue("SilentAimFOV") or 90
		local position = Vector2.new(mouse.X, mouse.Y + GuiService:GetGuiInset().Y)

		fovCircle.Visible = showFov
		outlineCircle.Visible = showFov
		fovCircle.Radius = radius
		outlineCircle.Radius = radius
		fovCircle.Filled = Configuration.expectToggleValue("SilentAimFillFOV")
		fovCircle.Transparency = 1 - (Configuration.expectOptionValue("SilentAimFOVTransparency") or 0.3)
		fovCircle.Position = position
		outlineCircle.Position = position
	end

	if tick() - lastTargetRefresh > TARGET_REFRESH then
		currentTarget = getTarget()
		lastTargetRefresh = tick()
	end

	local aimPos = mouse.Hit and mouse.Hit.Position
	local accent = Library.AccentColor or Color3.fromRGB(255, 80, 80)

	if currentTarget and getPrimary(currentTarget) then
		if fovCircle then
			fovCircle.Color = accent
		end
		aimPos = predictedPosition(currentTarget) or aimPos
	elseif fovCircle then
		fovCircle.Color = Library:GetDarkerColor(accent)
	end

	if not aimPos then
		return
	end

	-- Redirect UpdateMouse (the game's own fire is dropped by the namecall hook while Silent Aim is on).
	if not lastSentPosition or (aimPos - lastSentPosition).Magnitude > 0.1 then
		local requests = ReplicatedStorage:FindFirstChild("Requests")
		local updateMouse = requests and requests:FindFirstChild("UpdateMouse")
		if updateMouse then
			local packet = buffer.create(24)
			buffer.writef64(packet, 0, aimPos.X)
			buffer.writef64(packet, 8, aimPos.Y)
			buffer.writef64(packet, 16, aimPos.Z)
			pcall(function()
				updateMouse:FireServer(packet)
			end)
		end
		lastSentPosition = aimPos
	end
end

function SilentAim.enable()
	if running then
		return
	end
	running = true
	currentTarget = nil
	lastSentPosition = nil

	-- Install the OnClientInvoke override once the character + Requests exist.
	task.spawn(function()
		local timeout = tick() + 30
		repeat
			task.wait()
		until (localPlayer.Character and ReplicatedStorage:FindFirstChild("Requests")) or tick() > timeout

		if not running then
			return
		end

		local ok = pcall(installCameraHook)
		installed = installed or ok
	end)

	-- The game re-sets GetCameraToMouse.OnClientInvoke on respawn, so re-install after each CharacterAdded.
	if characterConn then
		pcall(function()
			characterConn:Disconnect()
		end)
	end
	characterConn = localPlayer.CharacterAdded:Connect(function()
		if not running then
			return
		end
		task.spawn(function()
			task.wait(1)
			if running then
				pcall(installCameraHook)
			end
		end)
	end)

	if renderConn then
		pcall(function()
			renderConn:Disconnect()
		end)
	end
	renderConn = RunService.PreRender:Connect(function()
		if not running then
			return
		end
		pcall(onRender)
	end)
end

function SilentAim.disable()
	running = false
	currentTarget = nil
	lastSentPosition = nil

	if renderConn then
		pcall(function()
			renderConn:Disconnect()
		end)
		renderConn = nil
	end
	if characterConn then
		pcall(function()
			characterConn:Disconnect()
		end)
		characterConn = nil
	end

	destroyDrawings()

	-- The GetCameraToMouse override stays installed but is a transparent passthrough while the toggle is
	-- off (returns the real mouse aim), so leaving it is identical to the stock client.
end

return SilentAim
