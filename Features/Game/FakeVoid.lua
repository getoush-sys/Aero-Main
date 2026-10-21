local FakeVoid = {}

local Signal = require("Utility/Signal")

local Logger = require("Utility/Logger")

local Configuration = require("Utility/Configuration")

local Maid = require("Utility/Maid")

local runService = game:GetService("RunService")
local players = game:GetService("Players")

local fakeVoidMaid = Maid.new()

local preSimulation = Signal.new(runService.PreSimulation)
local workspaceDescendantAdded = Signal.new(workspace.DescendantAdded)
local workspaceDescendantRemoving = Signal.new(workspace.DescendantRemoving)

local TRIGGER_HEIGHT = 100
local DEPTHS_ROOF_Y = -600
local DEPTHS_RAY_LENGTH = 1000
local ROOF_OFFSET = 3
local TELEPORT_COOLDOWN = 1.0

local killPlanes = {}

local lastTeleport = 0
local initialized = false

local function isKillPlane(instance)
	return instance:IsA("BasePart") and (instance.Name == "KillPlane" or instance.Name:match("Chasm") ~= nil)
end

local function getBounds(part)
	local cframe = part.CFrame
	if cframe.Y ~= cframe.Y or math.abs(cframe.Y) == math.huge then
		return nil
	end

	local size = part.Size
	local right, up, look = cframe.RightVector, cframe.UpVector, cframe.LookVector
	local extents = Vector3.new(
		math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(look.X) * size.Z,
		math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(look.Y) * size.Z,
		math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(look.Z) * size.Z
	) / 2

	return { min = cframe.Position - extents, max = cframe.Position + extents }
end

local function onWorkspaceDescendantAdded(descendant)
	if not isKillPlane(descendant) then
		return
	end

	killPlanes[descendant] = getBounds(descendant) or false
end

local function onWorkspaceDescendantRemoving(descendant)
	killPlanes[descendant] = nil
end

local function getKillPlaneY(position)
	local fpdh = workspace:GetAttribute("OriginalFPDH") or workspace.FallenPartsDestroyHeight
	local best = (typeof(fpdh) == "number" and fpdh == fpdh) and fpdh or nil

	for part, cached in next, killPlanes do
		local data = getBounds(part) or cached
		if not data then
			continue
		end

		killPlanes[part] = data

		if position.X < data.min.X or position.X > data.max.X then
			continue
		end

		if position.Z < data.min.Z or position.Z > data.max.Z then
			continue
		end

		if not best or data.max.Y > best then
			best = data.max.Y
		end
	end

	return best
end

local function getDepthsRoofY(position)
	local map = workspace:FindFirstChild("Map")
	if not map then
		return DEPTHS_ROOF_Y
	end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { map }
	params.FilterType = Enum.RaycastFilterType.Include

	local result = workspace:Raycast(
		Vector3.new(position.X, DEPTHS_ROOF_Y, position.Z),
		Vector3.new(0, -DEPTHS_RAY_LENGTH, 0),
		params
	)

	return result and result.Position.Y + ROOF_OFFSET or DEPTHS_ROOF_Y
end

local function updateFakeVoid()
	if not Configuration.expectToggleValue("FakeVoid") then
		return
	end

	if os.clock() - lastTeleport <= TELEPORT_COOLDOWN then
		return
	end

	local character = players.LocalPlayer and players.LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local position = rootPart.Position

	local killPlaneY = getKillPlaneY(position)

	if not killPlaneY or position.Y - killPlaneY > TRIGGER_HEIGHT then
		return
	end

	local targetY = getDepthsRoofY(position)
	if targetY - killPlaneY <= TRIGGER_HEIGHT then
		return
	end

	lastTeleport = os.clock()

	Logger.warn(
		"(FakeVoid) Teleporting from Y %.1f to Y %.1f (kill Y %.1f).",
		position.Y,
		targetY,
		killPlaneY
	)

	rootPart.CFrame = rootPart.CFrame + Vector3.new(0, targetY - position.Y, 0)
	rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
end

function FakeVoid.init()
	if initialized then
		return
	end
	initialized = true

	for _, descendant in next, workspace:GetDescendants() do
		onWorkspaceDescendantAdded(descendant)
	end

	fakeVoidMaid:add(
		workspaceDescendantAdded:connect("FakeVoid_WorkspaceDescendantAdded", onWorkspaceDescendantAdded)
	)
	fakeVoidMaid:add(
		workspaceDescendantRemoving:connect("FakeVoid_WorkspaceDescendantRemoving", onWorkspaceDescendantRemoving)
	)
	fakeVoidMaid:add(preSimulation:connect("FakeVoid_PreSimulation", updateFakeVoid))

	if not LPH_OBFUSCATED or shared.Aero.verbose then
		local count = 0

		for _ in next, killPlanes do
			count = count + 1
		end

		Logger.warn("FakeVoid initialized with %d kill planes.", count)
	end
end

function FakeVoid.detach()
	-- Guard: a startup toggle callback (config load firing OnChanged(false) before FakeVoid was ever
	-- started) must NOT run a spurious detach. The ungated Logger.warn below leaked the "[Aero Recode]"
	-- fingerprint into LogService for release users (where every other log is gated off) and got them
	-- flagged by the anticheat's log scan.
	if not initialized then
		return
	end
	initialized = false

	fakeVoidMaid:clean()
	table.clear(killPlanes)

	if not LPH_OBFUSCATED or (shared.Aero and shared.Aero.verbose) then
		Logger.warn("FakeVoid detached.")
	end
end

return FakeVoid
