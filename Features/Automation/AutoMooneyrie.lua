-- Auto Mooneyrie: a Aero port of project-rain-oss's `auto_mooneyrie.lua`, on the AutomationStruct +
-- StateMachine framework. In the Eastern Luminant: heal at a campfire if low, travel to Moon's Eyrie, open
-- the Moon door, kill the Moon Knight(s), loot, then hide/hop. Runs the fight with m1_hold + a kick-anim
-- dodge (attach behind the knight, fly up when he winds up a kick).
--
-- Public surface:
--   AutoMooneyrie.start() / .stop() / .inValidPlace()  (Eastern Luminant)
-- Persistence key: "mooneyriedata" { slot, startedAt }.
local AutoMooneyrie = {}

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")
---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")
---@module Features.Game.Tweening
local Tweening = require("Features/Game/Tweening")
---@module Utility.Prompt
local Prompt = require("Utility/Prompt")
---@module Utility.Logger
local Logger = require("Utility/Logger")
---@module GUI.Library
local Library = require("GUI/Library")
---@module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")
---@module Utility.Maid
local Maid = require("Utility/Maid")
---@module Game.AntiAFK
local AntiAFK = require("Game/AntiAFK")
---@module Features.Automation.Objects.StateMachine
local StateMachine = require("Features/Automation/Objects/StateMachine")
---@module Features.Automation.Objects.AutomationStruct
local AutomationStruct = require("Features/Automation/Objects/AutomationStruct")

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local EASTERN_PLACE_ID = 6473861193 -- Eastern Luminant (Moon's Eyrie).
local DEPTHS_PLACE_ID = 5735553160 -- The Depths (should never be here; stop if we are).
local MOVE_ID = "AutoMooneyrie_Move"

local running = false
local struct = nil
local maid = Maid.new()
local screenGui, elapsedLabel = nil, nil

-- =========================================================================================================
-- Accessors.
-- =========================================================================================================
local function localPlayer()
	return players.LocalPlayer
end
local function character()
	local lp = localPlayer()
	return lp and lp.Character
end
local function root()
	local c = character()
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function humanoid()
	local c = character()
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function playerGui()
	local lp = localPlayer()
	return lp and lp:FindFirstChildOfClass("PlayerGui")
end
local function currentSlot()
	local lp = localPlayer()
	return lp and lp:GetAttribute("DataSlot")
end
local function isRunning()
	return running
end
function AutoMooneyrie.inValidPlace()
	return game.PlaceId == EASTERN_PLACE_ID
end
local function getEffectReplicator()
	local ok, mod = pcall(function()
		return require(replicatedStorage:WaitForChild("EffectReplicator"))
	end)
	return ok and mod or nil
end

-- =========================================================================================================
-- Overlay.
-- =========================================================================================================
local function guiParent()
	return (gethui and gethui()) or game:GetService("CoreGui")
end
local function mk(class, props, parent)
	local instance = Instance.new(class)
	for k, v in pairs(props) do
		instance[k] = v
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end
local function buildOverlay()
	if screenGui then
		return
	end
	screenGui = CoreGuiManager.imark(Instance.new("ScreenGui"))
	screenGui.Name = "LumaAutoMooneyrieOverlay"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.DisplayOrder = 9999
	local protectGui = protectgui or (syn and syn.protect_gui) or function() end
	pcall(protectGui, screenGui)
	screenGui.Parent = guiParent()
	local outer = mk("Frame", {
		Name = "Outer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.new(0, 300, 0, 78),
		BackgroundColor3 = Library.MainColor,
		BorderColor3 = Library.OutlineColor,
		BorderSizePixel = 1,
		ZIndex = 200,
	}, screenGui)
	Library:AddToRegistry(outer, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" })
	local title = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 6),
		Size = UDim2.new(1, -16, 0, 20),
		FontFace = Library.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Library.AccentColor,
		Text = "Auto Mooneyrie",
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(title, { TextColor3 = "AccentColor" })
	elapsedLabel = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 30),
		Size = UDim2.new(1, -16, 0, 16),
		FontFace = Library.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Library.FontColor or Color3.new(1, 1, 1),
		Text = "Elapsed: 0s",
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(elapsedLabel, { TextColor3 = "FontColor" })
	local stopButton = mk("TextButton", {
		Position = UDim2.new(0, 8, 1, -30),
		Size = UDim2.new(1, -16, 0, 22),
		AutoButtonColor = true,
		BackgroundColor3 = Library:GetDarkerColor(Library.MainColor),
		BorderColor3 = Library.OutlineColor,
		BorderSizePixel = 1,
		FontFace = Library.Font,
		TextSize = 15,
		TextColor3 = Library.FontColor or Color3.new(1, 1, 1),
		Text = "Stop",
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(stopButton, {
		BackgroundColor3 = function()
			return Library:GetDarkerColor(Library.MainColor)
		end,
		BorderColor3 = "OutlineColor",
		TextColor3 = "FontColor",
	})
	stopButton.MouseButton1Click:Connect(function()
		AutoMooneyrie.stop()
	end)
	pcall(function()
		Library:MakeDraggable(outer)
	end)
end
local function destroyOverlay()
	if screenGui then
		pcall(function()
			screenGui:Destroy()
		end)
		screenGui = nil
	end
	elapsedLabel = nil
end
-- Stage text was removed; kept as a no-op so the many callers don't need changing.
local function setStage(_) end

local function formatDuration(seconds)
	seconds = math.floor(seconds)
	if seconds < 60 then
		return seconds .. "s"
	end
	local minutes = math.floor(seconds / 60)
	if seconds < 3600 then
		return minutes .. "m " .. (seconds % 60) .. "s"
	end
	return math.floor(minutes / 60) .. "h " .. (minutes % 60) .. "m"
end

local function runElapsed()
	while running do
		local data = PersistentData.get("mooneyriedata")
		if elapsedLabel and data then
			elapsedLabel.Text = "Elapsed: " .. formatDuration(math.max(0, os.time() - (data.startedAt or os.time())))
		end
		task.wait(0.5)
	end
end

-- =========================================================================================================
-- Helpers.
-- =========================================================================================================
local function setSpeed(value)
	value = (Options and Options.MooneyrieTweenSpeed and Options.MooneyrieTweenSpeed.Value) or 100
	if Options and Options.TweenStudsPerSecond and Options.TweenStudsPerSecond.Value ~= value then
		Options.TweenStudsPerSecond:SetValue(value)
	end
end
local function tempTween(cframe, speed)
	setSpeed(speed or 170)
	Tweening.goal(MOVE_ID, cframe, false)
	local goalPos = cframe.Position
	while running do
		local r = root()
		if r and (r.Position - goalPos).Magnitude <= 4 then
			break
		end
		task.wait()
	end
	Tweening.stop(MOVE_ID)
end
local function playerNear()
	local origin = root() and root().Position
	if not origin then
		return false
	end
	for _, player in next, players:GetPlayers() do
		if player ~= localPlayer() and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			if (origin - player.Character:GetPivot().Position).Magnitude <= 200 then
				return true
			end
		end
	end
	return false
end
local function playersNear(target, mag)
	for _, player in next, players:GetPlayers() do
		if player ~= localPlayer() and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			if (target - player.Character:GetPivot().Position).Magnitude <= mag then
				return true
			end
		end
	end
	return false
end
local function serverHop()
	pcall(function()
		ServerHop.hop(currentSlot(), true)
	end)
end
local function playerSafeTween(cf, speed)
	if playerNear() then
		serverHop()
		while task.wait() do
		end
		return
	end
	local r = root()
	if not r then
		return
	end
	local y = math.random(8000, 10000)
	r.CFrame = r.CFrame + Vector3.new(0, y, 0)
	tempTween(cf + Vector3.new(0, y, 0), speed)
	if playersNear(cf.Position, 200) then
		serverHop()
		while task.wait() do
		end
		return
	end
	r = root()
	if r then
		r.CFrame = cf
	end
	task.wait(1)
end
local function readyWeapon()
	pcall(function()
		character().CharacterHandler.Requests.DrawWeapon:FireServer(true)
	end)
end
local function m1Hold(state)
	local feat = struct and struct.active_features and struct.active_features["m1_hold"]
	if feat then
		feat.held = state
	end
end
local function healthCheck(percent)
	local hum = humanoid()
	return hum ~= nil and hum.Health <= (hum.MaxHealth * percent)
end
local function inDanger()
	local hum = humanoid()
	return hum ~= nil and hum:GetAttribute("DangerExpiration") and hum:GetAttribute("DangerExpiration") > 0
end
local function getClosestMob(name, mag)
	local closest
	local live = workspace:FindFirstChild("Live")
	if not live then
		return nil
	end
	for _, mob in next, live:GetChildren() do
		if mob:IsA("Model") and mob.Name:find(name) and mob:FindFirstChild("HumanoidRootPart") then
			local dist = (root().Position - mob.HumanoidRootPart.Position).Magnitude
			if not closest then
				if not mag or dist < mag then
					closest = mob
				end
			elseif dist < (root().Position - closest.HumanoidRootPart.Position).Magnitude then
				closest = mob
			end
		end
	end
	return closest
end
local function getClosestCampfire()
	local closest
	local thrown = workspace:FindFirstChild("Thrown")
	if not thrown then
		return nil
	end
	for _, campfire in next, thrown:GetChildren() do
		if campfire.Name:match("Campfire") and campfire:IsA("Model") then
			local part = campfire:FindFirstChildOfClass("Part")
			if part then
				if not closest then
					closest = part
				elseif (root().Position - part.Position).Magnitude < (root().Position - closest.Position).Magnitude then
					closest = part
				end
			end
		end
	end
	return closest
end
local function grabChest()
	local thrown = workspace:FindFirstChild("Thrown")
	if not thrown then
		return
	end
	for _, chest in next, thrown:GetChildren() do
		if chest:FindFirstChild("Lid") then
			tempTween(chest.Lid.CFrame, 170)
			local t = tick()
			repeat
				task.wait(0.5)
				pcall(function()
					Prompt.interact(chest:FindFirstChildWhichIsA("ProximityPrompt"))
				end)
				pcall(function()
					tempTween(chest.Lid.CFrame, 170)
				end)
			until (playerGui() and playerGui():FindFirstChild("ChoicePrompt")) or not running or tick() - t > 3 or playerNear()
			if playerNear() then
				break
			end
			local t2 = tick()
			repeat
				task.wait(1)
			until not (playerGui() and playerGui():FindFirstChild("ChoicePrompt")) or not running or tick() - t2 > 3 or playerNear()
			break
		end
	end
end

-- =========================================================================================================
-- Kill a Moon Knight: attach behind it, m1, dodge its kick (fly up when the kick anim plays), then vacuum
-- nearby LootDrops.
-- =========================================================================================================
local function killTarget(target)
	if playerNear() or not target or not target:IsA("Model") then
		return false
	end
	if target.Name:match(localPlayer().Name) then
		return false
	end

	readyWeapon()
	if target:FindFirstChild("HumanoidRootPart") then
		tempTween(target.HumanoidRootPart.CFrame, 170)
	end
	if playerNear() then
		return false
	end

	local foundKick = false
	local animator = target:FindFirstChild("Animator", true)
	local kickConn
	if animator then
		kickConn = animator.AnimationPlayed:Connect(function(track)
			local id = track.Animation.AnimationId
			if (id:match("106711913879378") or id:match("111024000122473")) and not foundKick then
				foundKick = true
				task.delay(2, function()
					foundKick = false
				end)
			end
		end)
	end

	-- Attach behind the knight (fly up when it winds up a kick).
	local attach = task.spawn(function()
		while running and not playerNear() do
			if not target.Parent or not target:FindFirstChild("HumanoidRootPart") then
				break
			end
			local r = root()
			if r then
				r.AssemblyLinearVelocity = Vector3.zero
				r.CFrame = target.HumanoidRootPart.CFrame
					* CFrame.new(0, foundKick and 60 or 10, 0)
					* CFrame.Angles(math.rad(-90), 0, 0)
			end
			task.wait()
		end
	end)

	-- Track health stalls (bail if no damage for 20s).
	local healthTick = tick()
	local lastHealth = nil
	local status = task.spawn(function()
		while running do
			pcall(function()
				local hp = target.Humanoid.Health
				if lastHealth == nil or lastHealth ~= hp then
					healthTick = tick()
					lastHealth = hp
				end
			end)
			task.wait()
		end
	end)

	m1Hold(true)
	repeat
		task.wait()
	until not running
		or not target
		or target.Parent == nil
		or playerNear()
		or healthCheck(0.35)
		or (tick() - healthTick >= 20)

	pcall(function()
		if kickConn then
			kickConn:Disconnect()
		end
	end)
	pcall(function()
		task.cancel(attach)
	end)
	pcall(function()
		task.cancel(status)
	end)
	m1Hold(false)

	-- Vacuum LootDrops.
	if running and not playerNear() then
		task.wait(2)
		local thrown = workspace:FindFirstChild("Thrown")
		for _, drop in next, (thrown and thrown:GetChildren() or {}) do
			if drop:IsA("Model") and drop:FindFirstChild("LootDrop") then
				if (root().Position - drop.LootDrop.Position).Magnitude <= 100 and not playersNear(drop.LootDrop.Position, 200) then
					tempTween(drop.LootDrop.CFrame, 120)
					local t = tick()
					repeat
						pcall(function()
							firetouchinterest(drop.LootDrop, root(), 0)
							firetouchinterest(drop.LootDrop, root(), 1)
						end)
						task.wait()
					until drop.Parent == nil or playerNear() or not running or tick() - t >= 3
					if drop.Parent ~= nil then
						pcall(function()
							drop:Destroy()
						end)
					end
				end
			end
		end
		task.wait(0.2)
	end

	if healthCheck(0.35) then
		return false
	end
	if playerNear() or not running then
		return true
	end
	return false
end

-- =========================================================================================================
-- Main handle: heal if low, go to Moon's Eyrie, open the door, kill knights + loot.
-- =========================================================================================================
local function handle()
	-- Heal at a campfire if we're low.
	if healthCheck(0.35) then
		setStage("resting at campfire")
		playerSafeTween(
			CFrame.new(-7632.27881, 980.369873, 421.907501, -0.95457083, 0, 0.297984123, 0, 1, 0, -0.297984123, 0, -0.95457083),
			170
		)
		task.wait(1)
		local campfire = getClosestCampfire()
		local er = getEffectReplicator()
		if campfire then
			repeat
				local r = root()
				if r then
					r.CFrame = campfire.CFrame * CFrame.new(0, 1, 0)
				end
				task.wait(1)
				pcall(function()
					Prompt.interact(campfire.Parent.InteractPrompt)
				end)
				task.wait(1)
			until (er and er:FindEffect("Resting")) or not running
			repeat
				task.wait()
			until (humanoid() and humanoid().Health >= humanoid().MaxHealth * 0.5) or not running
			-- Stand up (E).
			local vim = Instance.new("VirtualInputManager")
			pcall(function()
				vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
				task.wait(0.1)
				vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
			end)
			task.wait(1)
			vim:Destroy()
		end
	end

	if not running then
		return
	end

	-- Travel to Moon's Eyrie.
	setStage("traveling to Moon's Eyrie")
	local marker = replicatedStorage:FindFirstChild("MarkerWorkspace")
	local location = marker
		and marker.AreaMarkers
		and marker.AreaMarkers:FindFirstChild("Moon's Eyrie")
		and marker.AreaMarkers["Moon's Eyrie"].AreaMarker.CFrame
	if not location then
		return
	end
	playerSafeTween(location, 170)

	local door
	repeat
		task.wait()
		door = workspace:FindFirstChild("MoonseyeDoor")
	until door or not running
	if not running then
		return
	end

	readyWeapon()
	playerSafeTween(door.CFrame * CFrame.new(0, -5, 0), 170)

	-- Open the Moon door.
	setStage("opening Moon door")
	repeat
		pcall(function()
			local moonDoor = workspace.NPCs:FindFirstChild("MoonDoor")
			if moonDoor then
				Prompt.interact(moonDoor:FindFirstChild("InteractPrompt"))
			end
		end)
		task.wait(0.5)
	until (playerGui() and playerGui():FindFirstChild("DialogueGui") and playerGui().DialogueGui.Enabled) or not running
	pcall(function()
		replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue"):FireServer({ choice = "[Interact]" })
	end)

	tempTween(door.CFrame * CFrame.new(0, 0, -100), 170)

	-- Wait for a Moon Knight to appear.
	local waited = 0
	repeat
		task.wait(0.1)
		waited = waited + 0.1
	until waited > 3 or playerNear() or getClosestMob("moonknight", 60) or not running
	if playerNear() or not running then
		return
	end

	setStage("fighting Moon Knight")
	local knight = getClosestMob("moonknight", 60)
	local knightWasNil = knight == nil

	killTarget(knight)

	if running and not playerNear() and not healthCheck(0.35) and not knightWasNil then
		task.wait(0.5)
		grabChest()
	end

	-- A second knight may be further out.
	local knight2 = getClosestMob("moonknight", 3000)
	if knight2 then
		killTarget(knight2)
	end
end

local function toSafety()
	setStage("hiding")
	repeat
		local r = root()
		if r then
			r.CFrame = r.CFrame * CFrame.new(0, math.random(8000, 10000), 0)
		end
		task.wait()
	until not inDanger() or not running
end

-- =========================================================================================================
-- State machine.
-- =========================================================================================================
local stateMachine = StateMachine.create({
	initial = "idle",
	events = {
		{ name = "start", from = "idle", to = "_check_area" },
		{ name = "moons", from = "_check_area", to = "_moonseyrie" },
		{ name = "hide", from = "_check_area", to = "_hide" },
		{ name = "hide", from = "_moonseyrie", to = "_hide" },
		{ name = "hop", from = "_moonseyrie", to = "_hop" },
		{ name = "hop", from = "_hide", to = "_hop" },
		{ name = "continuation", from = "_hide", to = "_moonseyrie" },
	},
	callbacks = {
		onenter_check_area = function(self)
			if not running then
				return
			end
			setStage("check area")
			if game.PlaceId == DEPTHS_PLACE_ID then
				Logger.notify("Auto Mooneyrie: ended up in the Depths -- stopping.")
				return AutoMooneyrie.stop()
			end
			if game.PlaceId == EASTERN_PLACE_ID then
				return self:moons()
			end
		end,
		onenter_moonseyrie = function(self)
			if not running then
				return
			end
			handle()
			if playerNear() or inDanger() then
				return self:hide()
			end
			self:hop()
		end,
		onenter_hide = function(self)
			if not running then
				return
			end
			toSafety()
			self:hop()
		end,
		onenter_hop = function(self)
			if not running then
				return
			end
			serverHop()
			while task.wait() do
			end
		end,
	},
})

-- =========================================================================================================
-- Struct.
-- =========================================================================================================
local function buildStruct()
	return AutomationStruct.construct({
		id = "auto_mooneyrie",
		state_machine = stateMachine,
		is_running = isRunning,
		features = {
			"no_fall",
			"noclip",
			"fly",
			"no_fire",
			"m1_hold",
			"no_stun",
			"fast_swing",
			"auto_equip_weapon",
			"auto_log",
		},
	})
end

-- =========================================================================================================
-- Public interface.
-- =========================================================================================================
function AutoMooneyrie.start()
	local lp = localPlayer()
	if not lp then
		return
	end
	if running then
		return
	end
	if not AutoMooneyrie.inValidPlace() then
		return Logger.notify("Auto Mooneyrie: not in the Eastern Luminant.")
	end
	local slot = currentSlot()
	if not slot then
		return Logger.notify("Auto Mooneyrie: no data slot found.")
	end

	local data = PersistentData.get("mooneyriedata") or {}
	data.slot = slot
	data.startedAt = data.startedAt or os.time()
	PersistentData.set("mooneyriedata", data)

	running = true
	buildOverlay()
	AntiAFK.start("AutoMooneyrie")

	maid:mark(task.spawn(runElapsed))

	stateMachine.current = "idle"
	stateMachine.asyncState = StateMachine.NONE
	stateMachine.currentTransitioningEvent = nil

	struct = buildStruct()
	struct:run()
end

function AutoMooneyrie.stop()
	if not running then
		return
	end
	running = false
	if struct then
		pcall(function()
			struct:stop()
		end)
		struct = nil
	end
	Tweening.stop(MOVE_ID)
	pcall(function()
		AntiAFK.stop("AutoMooneyrie")
	end)
	maid:clean()
	destroyOverlay()
	PersistentData.set("mooneyriedata", nil)
end

return AutoMooneyrie
