-- Teleports: Aero port of project-rain-oss's `generic_teleport` + the region teleport buttons
-- (etrean / eastern / depths). Each teleport forces NoClip, streams the destination in, then repeatedly
-- snaps to the destination and fires its RealmTeleport TouchInterest until the place change happens.
local Teleports = {}

local players = game:GetService("Players")
local runService = game:GetService("RunService")

local function localPlayer()
	return players.LocalPlayer
end

local function root()
	local lp = localPlayer()
	local char = lp and lp.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
	local lp = localPlayer()
	local char = lp and lp.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

-- ---------------------------------------------------------------------------------------------------------
-- Generic teleport (port of generic_teleport.lua).
-- ---------------------------------------------------------------------------------------------------------
local GenericTeleport = {}
GenericTeleport.__index = GenericTeleport

function GenericTeleport.new(destination, destinationPartGetter, stopCondition)
	return setmetatable({
		lastStreamRequest = 0,
		destination = destination,
		destinationPartGetter = destinationPartGetter,
		stopCondition = stopCondition,
		conn = nil,
	}, GenericTeleport)
end

function GenericTeleport:requestStreamAroundDestination()
	if not workspace.StreamingEnabled then
		return
	end
	if tick() - self.lastStreamRequest > 1 / 30 then
		self.lastStreamRequest = tick()
		pcall(function()
			localPlayer():RequestStreamAroundAsync(self.destination.Position)
		end)
	end
end

function GenericTeleport:run()
	-- Force NoClip on for the trip (restore it if we turned it on).
	local setForUser = false
	if Toggles and Toggles.NoClip and not Toggles.NoClip.Value then
		setForUser = true
		Toggles.NoClip:SetValue(true)
	end

	self.conn = runService.PostSimulation:Connect(function()
		self:requestStreamAroundDestination()

		if self.stopCondition and self:stopCondition() then
			if self.conn then
				self.conn:Disconnect()
				self.conn = nil
			end
			if setForUser and Toggles and Toggles.NoClip then
				Toggles.NoClip:SetValue(false)
			end
			return
		end

		local r = root()
		local destinationPart = self.destinationPartGetter()
		if r and destinationPart and destinationPart:FindFirstChild("TouchInterest") then
			r.AssemblyLinearVelocity = Vector3.one * (math.random() / 100)
			r.CFrame = self.destination * CFrame.new(math.random() / 100, math.random() / 100, math.random() / 100)
			xpcall(function()
				firetouchinterest(r, destinationPart, true)
				firetouchinterest(r, destinationPart, false)
			end, function() end)
		end

		local hum = humanoid()
		if hum and sethiddenproperty then
			pcall(function()
				sethiddenproperty(hum, "MoveDirectionInternal", Vector3.one)
			end)
		end
	end)

	return self
end

function GenericTeleport:stop()
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
end

Teleports.GenericTeleport = GenericTeleport

-- ---------------------------------------------------------------------------------------------------------
-- Region teleports. Each returns the GenericTeleport instance (so callers can :stop() it if needed).
-- ---------------------------------------------------------------------------------------------------------
local function valleyRealmTeleport()
	local exit = workspace:FindFirstChild("ValleyExit")
	return exit and exit:FindFirstChild("RealmTeleport")
end

---Etrean Luminant.
function Teleports.etrean()
	return GenericTeleport.new(CFrame.new(-528.434814, 704.674194, -4760.4292), valleyRealmTeleport):run()
end

---Eastern Luminant.
function Teleports.eastern()
	return GenericTeleport.new(
		CFrame.new(-2637.4563, 721.632935, -6722.51953, -0.757481456, 0, -0.652856648, 0, 1, 0, 0.652856648, 0, -0.757481456),
		valleyRealmTeleport
	):run()
end

---The Depths (via the Mod Office pit).
function Teleports.depths()
	return GenericTeleport.new(CFrame.new(39911.3672, 39980.9375, 39708.3203), function()
		local modOffice = workspace:FindFirstChild("ModOffice")
		return modOffice and modOffice:FindFirstChild("OfficePit")
	end):run()
end

return Teleports
