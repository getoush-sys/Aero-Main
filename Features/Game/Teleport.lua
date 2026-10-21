---@note: Teleports in Deepwoken do not work the same. They lag you back, obviously. This is a utility module to handle repeatedly teleporting for a specific purpose.
local Teleport = { destination = nil, gdp = nil }

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.TaskSpawner
local TaskSpawner = require("Utility/TaskSpawner")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.Prompt
local Prompt = require("Utility/Prompt")

local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

local tmaid = Maid.new()

Teleport.activeTween = nil

local RUBBERBAND_THRESHOLD = 1000
local teleportFrameCount = 0
local SPAM_FRAMES = 30
local PAUSE_FRAMES = 15
local STREAM_REQUEST_INTERVAL = 1.0
local REALM_ALIASES = {
	EasternLuminant = { "EastLuminant", "East Luminant", "EasternLuminant", "Eastern Luminant" },
	EtreanLuminant = { "EtreanLuminant", "Etrean Luminant" },
}
local REALM_TELEPORTER_PATHS = {
	{ "ValleyExit", "RealmTeleport" },
	{ "ValleyExit", "RealmTeleporter" },
}
local teleporterCache = {}
local streamRequestTimes = {}

---@note: Ported from Project Rain. Rather than waiting for the realm teleporter
local LUMINANT_TARGETS = {
	EasternLuminant = CFrame.new(
		-2637.4563,
		721.632935,
		-6722.51953,
		-0.757481456,
		0,
		-0.652856648,
		0,
		1,
		0,
		0.652856648,
		0,
		-0.757481456
	),
	EtreanLuminant = CFrame.new(-528.434814, 704.674194, -4760.4292),
}

local noClipSetByTeleport = false

---@param child Instance
local function onPlayerGuiDescendantAdded(child)
	if not child:IsA("TextLabel") then
		return
	end

	local coords = string.split(child.Text, ", ")
	local x, y, z = tonumber(coords[1]), tonumber(coords[2]), tonumber(coords[3])
	if not x or not y or not z then
		return
	end

	local position = Vector3.new(x, y, z)

	if (position - Vector3.new(-20000, 20000, -20000)).Magnitude <= 20 and Teleport.destination == "Voidheart" then
		return Teleport.stop()
	end

	if (position - Vector3.new(1596.1, 555.7, 2849.9)).Magnitude <= 20 and Teleport.destination == "LowerErisia" then
		return Teleport.stop()
	end

	if Teleport.gdp and (position - Teleport.gdp).Magnitude <= 20 and Teleport.destination == "GuildDoor" then
		return Teleport.stop()
	end
end

---@note: First instance is the entrance door. The second instance is the exit door.
---@param name string
---@return Instance?, Instance?
local function getGuildDoors(name)
	for _, instance in next, workspace:GetChildren() do
		if not instance.Name:match("GuildDoor") then
			continue
		end

		local guildName = instance:GetAttribute("GuildName")
		if not guildName then
			continue
		end

		if not guildName:lower():match(name:lower()) then
			continue
		end

		return instance, workspace:FindFirstChild(string.gsub(instance.Name, "GuildDoor", "GuildExitDoor"))
	end

	return nil
end

---@param character Model
---@param part BasePart
local function fireTouchOn(character, part)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	pcall(firetouchinterest, hrp, part, 0)
	pcall(firetouchinterest, hrp, part, 1)
	pcall(firetouchinterest, hrp, part, 0)
	pcall(firetouchinterest, hrp, part, 1)
end

---@note: Ported from Project Rain -- deliberately no 'Realm' attribute check.
---@return BasePart?
local function getValleyRealmTeleport()
	local valleyExit = workspace:FindFirstChild("ValleyExit")
	if not valleyExit then
		return nil
	end

	local teleporter = valleyExit:FindFirstChild("RealmTeleport") or valleyExit:FindFirstChild("RealmTeleporter")
	if not teleporter or not teleporter:IsA("BasePart") then
		return nil
	end

	return teleporter
end

---@note: Ported from Project Rain. The game rubber-bands a character it thinks
---@param character Model
local function spoofMoveDirection(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	pcall(sethiddenproperty, humanoid, "MoveDirectionInternal", Vector3.one)
end

---@note: Ported from Project Rain -- stops geometry from blocking the run.
local function ensureNoClip()
	if noClipSetByTeleport then
		return
	end

	if not Toggles or not Toggles.NoClip then
		return
	end

	if Toggles.NoClip.Value then
		return
	end

	noClipSetByTeleport = true
	Toggles.NoClip:SetValue(true)
end

local function restoreNoClip()
	if not noClipSetByTeleport then
		return
	end

	noClipSetByTeleport = false

	if Toggles and Toggles.NoClip then
		Toggles.NoClip:SetValue(false)
	end
end

local function resetTeleportState()
	teleportFrameCount = 0
	teleporterCache = {}
	streamRequestTimes = {}

	restoreNoClip()
end

---@param label string
---@param position Vector3
local function requestStreamAround(label, position)
	local timestamp = os.clock()
	local lastRequestTime = streamRequestTimes[label]
	if lastRequestTime and timestamp - lastRequestTime < STREAM_REQUEST_INTERVAL then
		return
	end

	streamRequestTimes[label] = timestamp
	tmaid:add(
		TaskSpawner.spawn(
			label,
			players.LocalPlayer.RequestStreamAroundAsync,
			players.LocalPlayer,
			position,
			0.1
		)
	)
end

---@param realm string
---@param destination string
---@return boolean
local function isRealmName(realm, destination)
	for _, alias in next, REALM_ALIASES[destination] or { destination } do
		if realm == alias then
			return true
		end
	end

	return false
end

---@param path table
---@return Instance?
local function getWorkspacePath(path)
	local current = workspace
	for _, name in next, path do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end

	return current
end

---@param realm string
---@return BasePart?
local function getRealmTeleporter(realm)
	local cachedTeleporter = teleporterCache[realm]
	if cachedTeleporter and cachedTeleporter.Parent and isRealmName(cachedTeleporter:GetAttribute("Realm"), realm) then
		return cachedTeleporter
	end

	for _, path in next, REALM_TELEPORTER_PATHS do
		local teleporter = getWorkspacePath(path)
		if not teleporter or not teleporter:IsA("BasePart") then
			continue
		end

		if not isRealmName(teleporter:GetAttribute("Realm"), realm) then
			continue
		end

		teleporterCache[realm] = teleporter
		return teleporter
	end

	return nil
end

---@return BasePart?
local function scanVoidheartTeleporter()
	local warpPoints = workspace:FindFirstChild("WarpPoints")
	local voidheartWarpPoint = warpPoints and warpPoints:FindFirstChild("Voidheart")
	if voidheartWarpPoint and voidheartWarpPoint:IsA("BasePart") then
		return voidheartWarpPoint
	end

	local voidheart = workspace:FindFirstChild("Voidheart")
	local voidheartVoidWarp = voidheart and voidheart:FindFirstChild("VoidheartVoidWarp", true)
	if voidheartVoidWarp and voidheartVoidWarp:IsA("BasePart") then
		return voidheartVoidWarp
	end

	return nil
end

---@return BasePart?
local function getVoidheartTeleporter()
	local cachedTeleporter = teleporterCache.Voidheart
	if cachedTeleporter and cachedTeleporter.Parent then
		return cachedTeleporter
	end

	local teleporter = scanVoidheartTeleporter()
	if teleporter then
		teleporterCache.Voidheart = teleporter
	end

	return teleporter
end

local onTeleportLoop = LPH_NO_VIRTUALIZE(function()
	local dest = Teleport.destination
	if not dest then
		return
	end

	local localPlayer = players.LocalPlayer
	local character = localPlayer.Character
	if not character then
		return
	end

	---@note: Ported from Project Rain. We move onto the destination every frame
	local luminantTarget = LUMINANT_TARGETS[dest]
	if luminantTarget then
		requestStreamAround(string.format("Teleport_%sStream", dest), luminantTarget.Position)

		ensureNoClip()
		spoofMoveDirection(character)

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		hrp.AssemblyLinearVelocity = Vector3.one * (math.random() / 100)
		hrp.CFrame = luminantTarget * CFrame.new(math.random() / 100, math.random() / 100, math.random() / 100)

		local realmTeleport = getValleyRealmTeleport()
		if realmTeleport then
			fireTouchOn(character, realmTeleport)
		end

		return
	end

	if dest == "Depths" then
		tmaid:add(
			TaskSpawner.spawn(
				"Teleport_DepthsStream",
				players.LocalPlayer.RequestStreamAroundAsync,
				players.LocalPlayer,
				Vector3.new(39911.3672, 39980.9375, 39708.3203),
				0.1
			)
		)

		local modOffice = workspace:FindFirstChild("ModOffice")
		local officePit = modOffice and modOffice:FindFirstChild("OfficePit")
		if not officePit then
			return
		end

		character:PivotTo(officePit.CFrame)
	end

	if dest == "Voidheart" then
		local voidheartTeleporter = getVoidheartTeleporter()
		requestStreamAround(
			"Teleport_VoidheartStream",
			voidheartTeleporter and voidheartTeleporter.Position or Vector3.new(-20000.0, 19713.9609, -20000.0)
		)

		if not voidheartTeleporter then
			return
		end

		local vhCFrame = voidheartTeleporter.CFrame
		teleportFrameCount = teleportFrameCount + 1
		local cycleFrame = (teleportFrameCount - 1) % (SPAM_FRAMES + PAUSE_FRAMES)

		if cycleFrame < SPAM_FRAMES then
			character:PivotTo(vhCFrame)
			fireTouchOn(character, voidheartTeleporter)
			return
		end

		if cycleFrame == SPAM_FRAMES + PAUSE_FRAMES - 1 then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - vhCFrame.Position).Magnitude <= RUBBERBAND_THRESHOLD then
				return Teleport.stop()
			end
		end
	end

	if dest == "TrialOfOne" then
		tmaid:add(
			TaskSpawner.spawn(
				"Teleport_TrialStream",
				players.LocalPlayer.RequestStreamAroundAsync,
				players.LocalPlayer,
				Vector3.new(-959.787659, 146.996887, -6659.63037),
				0.1
			)
		)

		local oneEntrance = workspace:FindFirstChild("OneEntrance")
		if not oneEntrance then
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

		if effectReplicatorModule:FindEffect("Knocked") then
			return Teleport.stop()
		end

		character:PivotTo(oneEntrance.CFrame)
	end

	---@note: Ported from Project Rain. Instead of dropping below the base bounds
	if dest == "GuildDoor" then
		local guildName = Configuration.expectOptionValue("GuildDoorName")
		if not guildName or #guildName <= 0 then
			return
		end

		local entranceDoor, exitDoor = getGuildDoors(guildName)
		if not entranceDoor or not exitDoor then
			return
		end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		if (hrp.Position - entranceDoor.Position).Magnitude < 20 then
			hrp.AssemblyLinearVelocity = Vector3.zero
			return Teleport.stop()
		end

		requestStreamAround("Teleport_GuildBaseStream", exitDoor.Position)

		ensureNoClip()
		spoofMoveDirection(character)

		hrp.CFrame = exitDoor.CFrame

		local interactPrompt = exitDoor:FindFirstChild("InteractPrompt")
			or exitDoor:FindFirstChildWhichIsA("ProximityPrompt", true)

		if interactPrompt then
			Prompt.fire(interactPrompt)
		end

		return
	end
end)

---@param target_cframe CFrame
---@param speed number? (Optional, defaults to 190)
function Teleport.Safetweenstart(target_cframe, speed)
    Teleport.Safetweenstop()
    task.wait()

	local function internalSafeNAN(val)
        if val == val then return val end
        if typeof(val) == "Vector3" then
            return Vector3.new(val.X == val.X and val.X or 0, val.Y == val.Y and val.Y or 0, val.Z == val.Z and val.Z or 0)
        elseif typeof(val) == "CFrame" then
            local pos = val.Position
            local rot = val.Rotation
            return CFrame.new(pos.X == pos.X and pos.X or 0, pos.Y == pos.Y and pos.Y or 0, pos.Z == pos.Z and pos.Z or 0) * (rot == rot and rot or CFrame.identity)
        elseif typeof(val) == "number" then
            return val == val and val or 0
        end
        return val
    end

    speed = speed or 190
    local heightOffset = 8000
    local target_pos = target_cframe.Position
    local travel_pos = target_pos + Vector3.new(0, heightOffset, 0)
    local local_player = players.LocalPlayer

    local conn
    conn = runService.PreSimulation:Connect(function(dt)
        local character = local_player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local current_pos = root.Position
        local offset = travel_pos - current_pos
        local distance = offset.Magnitude

        if distance <= 1 or distance ~= distance then return end

        root.AssemblyLinearVelocity = Vector3.zero
        
        root.CFrame = CFrame.new(root.CFrame.X, travel_pos.Y, root.CFrame.Z)

        local dir = offset.Unit
        local step = speed * dt

        if step > distance then step = distance end

        root.CFrame = internalSafeNAN(root.CFrame + internalSafeNAN(dir * step))
    end)

    task.spawn(function()
        local character = local_player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        
    
        while conn and root and (Vector2.new(travel_pos.X, travel_pos.Z) - Vector2.new(root.Position.X, root.Position.Z)).Magnitude > 15 do
            task.wait()
            root = character and character:FindFirstChild("HumanoidRootPart")
        end

        if root and conn then
            root.CFrame = target_cframe
        end

        if conn then
            conn:Disconnect()
            conn = nil
        end
    end)

    Teleport.activeTween = {
        stop = function()
            if conn then
                conn:Disconnect()
                conn = nil
            end
            
            local character = players.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = CFrame.new(root.Position.X, target_cframe.Y, root.Position.Z)
            end
        end
    }
end

function Teleport.Safetweenstop()
    if Teleport.activeTween then
        Teleport.activeTween.stop()
        Teleport.activeTween = nil
    end
end

---@param destination string
function Teleport.start(destination)
	if not destination then
		return error("Destination must be provided for teleporting.")
	end

	resetTeleportState()
	Teleport.destination = destination
end

function Teleport.stop()
	resetTeleportState()
	Teleport.destination = nil
end

function Teleport.init()
	local localPlayer = players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local descendantAddedSignal = Signal.new(playerGui.DescendantAdded)
	tmaid:mark(descendantAddedSignal:connect("Teleport_PlayerGui_DescendantAdded", onPlayerGuiDescendantAdded))

	local renderStepped = Signal.new(runService.RenderStepped)
	tmaid:mark(renderStepped:connect("Teleport_RenderStepped", onTeleportLoop))
end

function Teleport.detach()
	Teleport.Safetweenstop()
	tmaid:clean()
end

return Teleport
