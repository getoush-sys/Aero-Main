-- Auto Duke: a Aero port of project-rain-oss's `auto_duke.lua`, on the ported AutomationStruct +
-- StateMachine framework and the shared General/Teleports substrate. Refills food in the Etrean Luminant,
-- opens the Erisia manor (Manor Key), clears the brainsuckers/cultists, rides the elevator into the Duke
-- dungeon, then fights the golems + the Duke (with attack-pattern dodging + optional void mode) and loots.
--
-- Public surface:
--   AutoDuke.start()        -- menu Start + Aero.lua resume
--   AutoDuke.stop()
--   AutoDuke.inValidPlace() -- resume gate (Etrean/Eastern main-game or the Duke dungeon)
-- Persistence key: "dukedata" { slot, startedAt }.
-- Menu toggles read here: DukeVoids (use void mode on the Duke).
local AutoDuke = {}

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Utility.Prompt
local Prompt = require("Utility/Prompt")

---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")

---@module Features.Game.Tweening
local Tweening = require("Features/Game/Tweening")

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

---@module Game.KeyHandling
local KeyHandling = require("Game/KeyHandling")

---@module Features.Automation.Objects.StateMachine
local StateMachine = require("Features/Automation/Objects/StateMachine")

---@module Features.Automation.Objects.AutomationStruct
local AutomationStruct = require("Features/Automation/Objects/AutomationStruct")

---@module Features.Automation.Objects.General
local General = require("Features/Automation/Objects/General")

---@module Features.Automation.Objects.Teleports
local Teleports = require("Features/Automation/Objects/Teleports")

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local collectionService = game:GetService("CollectionService")

local MAIN_GAME_PLACE_ID = 6032399813 -- overworld (Etrean Luminant / Erisia manor).
local EASTERN_PLACE_ID = 6473861193 -- Eastern Luminant.
local DEPTHS_PLACE_ID = 5735553160 -- The Depths (should never be here; stop if we are).

local MOVE_ID = "AutoDuke_Move"
local DUKE_NAME = ".theduke11"

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
local function backpack()
	local lp = localPlayer()
	return lp and lp:FindFirstChildOfClass("Backpack")
end
local function currentSlot()
	local lp = localPlayer()
	return lp and lp:GetAttribute("DataSlot")
end
local function isRunning()
	return running
end

function AutoDuke.inValidPlace()
	if game.PlaceId == MAIN_GAME_PLACE_ID or game.PlaceId == EASTERN_PLACE_ID then
		return true
	end
	-- Also valid if we're inside the Duke dungeon (resume mid-fight).
	local dungeon = localPlayer() and localPlayer():GetAttribute("Dungeon")
	return dungeon ~= nil and tostring(dungeon):match("Duke") ~= nil
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
	screenGui.Name = "LumaAutoDukeOverlay"
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
		Text = "Auto Duke",
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
		AutoDuke.stop()
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
		local data = PersistentData.get("dukedata")
		if elapsedLabel and data then
			elapsedLabel.Text = "Elapsed: " .. formatDuration(math.max(0, os.time() - (data.startedAt or os.time())))
		end
		task.wait(0.5)
	end
end

-- =========================================================================================================
-- Movement + helpers.
-- =========================================================================================================
local function setSpeed(value)
	value = (Options and Options.DukeTweenSpeed and Options.DukeTweenSpeed.Value) or 100
	if Options and Options.TweenStudsPerSecond and Options.TweenStudsPerSecond.Value ~= value then
		Options.TweenStudsPerSecond:SetValue(value)
	end
end

---Blocking tween (PR Tween.new(cf, true, speed).wait()).
local function tempTween(cframe, speed)
	setSpeed(speed or 250)
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

---Non-blocking tween goal (used inside tight fight loops so we don't stall on arrival).
local function tweenGoal(cframe, speed)
	setSpeed(speed or 250)
	Tweening.goal(MOVE_ID, cframe, false)
end

local function playerNear()
	local origin = root() and root().Position
	if not origin then
		return false
	end
	for _, player in next, players:GetPlayers() do
		if player ~= localPlayer() and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			if (origin - player.Character:GetPivot().Position).Magnitude <= 1000 then
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

---PR's player_safe_tween: hop if anyone near, else go up to altitude, travel, drop.
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
	if playerNear() then
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

local function m1Hold(state)
	local feat = struct and struct.active_features and struct.active_features["m1_hold"]
	if feat then
		feat.held = state
	end
end

local function readyWeapon()
	pcall(function()
		character().CharacterHandler.Requests.DrawWeapon:FireServer(true)
	end)
end

-- =========================================================================================================
-- Loot.
-- =========================================================================================================
local function playerGuiHasChoice()
	local lp = localPlayer()
	local gui = lp and lp:FindFirstChildOfClass("PlayerGui")
	return gui and gui:FindFirstChild("ChoicePrompt") ~= nil
end

local function grabChests()
	local looted = false
	local thrown = workspace:FindFirstChild("Thrown")
	if not thrown then
		return false
	end
	for _, chest in next, thrown:GetChildren() do
		if not running then
			break
		end
		if chest:FindFirstChild("Lid") and not collectionService:HasTag(chest, "looted") then
			tempTween(chest.Lid.CFrame, 170)
			local t = tick()
			repeat
				task.wait(1)
				pcall(function()
					Prompt.interact(chest:FindFirstChildWhichIsA("ProximityPrompt"))
				end)
				pcall(function()
					tempTween(chest.Lid.CFrame, 170)
				end)
			until (playerGuiHasChoice()) or not running or tick() - t > 3
			if playerGuiHasChoice() then
				looted = true
			end
			local t2 = tick()
			repeat
				task.wait(1)
			until not playerGuiHasChoice() or not running or tick() - t2 > 3
			if playerGuiHasChoice() then
				looted = true
				pcall(function()
					localPlayer().PlayerGui.ChoicePrompt.Choice:FireServer("EXIT")
				end)
			end
			collectionService:AddTag(chest, "looted")
		end
	end
	return looted
end

-- =========================================================================================================
-- Refill food (Etrean ingredients).
-- =========================================================================================================
local function refill()
	setStage("refill food")
	local char = character()
	if not char then
		return
	end
	local water = char:FindFirstChild("Water")
	if not water then
		return
	end

	local function isSatiated()
		return water.Value >= (water.MaxValue * 0.5)
	end

	local passives = char:GetAttribute("ssv_Passives")
	if passives and tostring(passives):find("Carnivore") then
		return
	end

	local function closestIngredient(namePart)
		local closest
		local folder = workspace:FindFirstChild("Ingredients")
		if not folder then
			return nil
		end
		for _, ing in next, folder:GetChildren() do
			if ing.Name:match(namePart) then
				if not closest then
					closest = ing
				elseif (root().Position - ing.Position).Magnitude < (root().Position - closest.Position).Magnitude then
					closest = ing
				end
			end
		end
		return closest
	end

	local function collect(ing)
		playerSafeTween(ing.CFrame, 200)
		local cf = ing.CFrame
		repeat
			tempTween(cf, 200)
			pcall(function()
				Prompt.interact(ing:FindFirstChildOfClass("ProximityPrompt"))
			end)
			task.wait()
		until ing.Parent == nil or not running
	end

	local function eat(foodName)
		local item = backpack() and backpack():FindFirstChild(foodName)
		if not item then
			return
		end
		humanoid():EquipTool(item)
		item:Activate()
		task.wait(0.5)
		humanoid():UnequipTools()
	end

	local start = tick()
	while running and not isSatiated() and tick() - start <= 45 do
		local ing = closestIngredient("Dentifilo") or closestIngredient("Calabash")
		if not ing then
			break
		end
		local name = ing.Name
		collect(ing)
		eat(name)
		task.wait()
	end
end

-- =========================================================================================================
-- Create instance (open manor, clear adds, ride elevator into the Duke dungeon).
-- =========================================================================================================
local function createInstance()
	setStage("opening manor")
	local bp = backpack()
	if not bp then
		return
	end
	local manorKey = bp:WaitForChild("Manor Key", 10) or (character() and character():WaitForChild("Manor Key", 10))
	if not manorKey then
		Logger.notify("Auto Duke: need a Manor Key.")
		return
	end
	manorKey.Parent = character()
	local handle = manorKey:WaitForChild("Handle", 10)
	if not handle then
		return
	end

	-- The key has to be "charged" (handle turns white) before it works. If it isn't, wait up to 10s for it
	-- to change; if it still isn't white, this slot's key is spent -> hop to a fresh server.
	if handle.Color.R < 0.99 or handle.Color.G < 0.99 or handle.Color.B < 0.99 then
		local start = tick()
		local old = handle.Color
		repeat
			task.wait()
		until handle.Color ~= old or tick() - start > 10 or not running
		if handle.Color.R < 0.99 or handle.Color.G < 0.99 or handle.Color.B < 0.99 then
			return serverHop()
		end
	end

	playerSafeTween(CFrame.new(1460, 74, 3069), 200)

	local started = false
	task.delay(20, function()
		if not started and running then
			serverHop()
		end
	end)

	maid:mark(workspace.Live.ChildAdded:Connect(function(entity)
		if (entity.Name:find("brainsucker") or entity.Name:find("dukecultist")) then
			if (entity:GetPivot().Position - (root() and root().Position or Vector3.zero)).Magnitude <= 400 then
				started = true
			end
		end
	end))

	setStage("entering manor")
	while running and not started do
		if sethiddenproperty and humanoid() then
			pcall(function()
				sethiddenproperty(humanoid(), "MoveDirectionInternal", Vector3.one)
			end)
		end
		pcall(function()
			Prompt.interact(workspace.Doors.ErisiaDungeonGate.Main.InteractPrompt)
		end)
		task.wait()
	end

	readyWeapon()
	m1Hold(true)

	setStage("clearing adds")
	local done = false
	while running and not done do
		done = true
		for _, entity in next, workspace.Live:GetChildren() do
			if entity.Name:find("brainsucker") or entity.Name:find("dukecultist") then
				if (entity:GetPivot().Position - (root() and root().Position or Vector3.zero)).Magnitude <= 900 then
					local hum = entity:FindFirstChildOfClass("Humanoid")
					while running and hum and hum.Health > 0 and entity:FindFirstChild("HumanoidRootPart") do
						if playerNear() then
							serverHop()
							while task.wait() do
							end
							return
						end
						m1Hold(true)
						tweenGoal(entity.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3), 250)
						task.wait()
					end
					done = false
				end
			end
		end
	end
	m1Hold(false)
	Tweening.stop(MOVE_ID)

	task.delay(30, function()
		if running then
			serverHop()
		end
	end)

	setStage("riding elevator")
	playerSafeTween(CFrame.new(1470, 84, 3586), 200)
	for _ = 1, 300 do
		if not running then
			break
		end
		if playerNear() then
			serverHop()
			while task.wait() do
			end
			return
		end
		tempTween(CFrame.new(1470, 84, 3586), 250)
		pcall(function()
			Prompt.interact(workspace.ErisiaElevator.Switch.InteractPrompt)
		end)
		task.wait(0.1)
	end
end

-- =========================================================================================================
-- Kill the Duke.
-- =========================================================================================================
local function killDuke()
	setStage("fighting duke")
	readyWeapon()
	m1Hold(true)

	-- Dodge the golem laser (GolemLaserFire client effect).
	local nopeTfOut = false
	local clientEffect
	repeat
		clientEffect = replicatedStorage:FindFirstChild("ClientEffect", true)
		if not clientEffect then
			task.wait()
		end
	until clientEffect or not running
	if clientEffect then
		maid:mark(clientEffect.OnClientEvent:Connect(function(effectName)
			if effectName == "GolemLaserFire" then
				nopeTfOut = true
				task.delay(0.4, function()
					nopeTfOut = false
				end)
			end
		end))
	end

	-- Phase 1: clear the prime golems / remaining cultists (Z > 2000, i.e. in the arena).
	local done = false
	while running and not done do
		done = true
		for _, entity in next, workspace.Live:GetChildren() do
			if not running then
				break
			end
			if (entity.Name:find("prime_golem") or entity.Name:find("dukecultist")) then
				if (entity:GetPivot().Position - (root() and root().Position or Vector3.zero)).Magnitude <= 900 and entity:GetPivot().Z >= 2000 then
					local hum = entity:FindFirstChildOfClass("Humanoid")
					while running and hum and hum.Health > 0 do
						m1Hold(true)
						if not entity:FindFirstChild("HumanoidRootPart") then
							break
						end
						if not nopeTfOut then
							tweenGoal(
								entity.HumanoidRootPart.CFrame
									* (entity.Name:find("prime_golem") and CFrame.new(0, 5, 0.35) or CFrame.new(0, 2, 3)),
								250
							)
						else
							tweenGoal(entity.HumanoidRootPart.CFrame * CFrame.new(0, 100, 10), 250)
						end
						task.wait()
					end
					done = false
				end
			end
		end
	end
	m1Hold(false)
	if not running then
		return
	end

	-- Phase 2: start the Duke dialogue -- fire the interact prompt on .theduke11 until dialogue opens.
	local sendDialogue = replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue")
	local got = false
	maid:mark(sendDialogue.OnClientEvent:Connect(function(v)
		got = not (v and v.exit)
	end))

	local vim = Instance.new("VirtualInputManager")
	repeat
		local duke = workspace.Live:FindFirstChild(DUKE_NAME)
		if duke and duke:FindFirstChild("HumanoidRootPart") then
			tempTween(duke.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3), 250)
			pcall(function()
				Prompt.interact(duke.InteractPrompt)
			end)
		end
		pcall(function()
			vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
			task.wait()
			vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
		end)
		task.wait()
	until got or not running
	-- Spam the accept key while the dialogue is open.
	while running and got do
		pcall(function()
			vim:SendKeyEvent(true, Enum.KeyCode.One, false, game)
			task.wait()
			vim:SendKeyEvent(false, Enum.KeyCode.One, false, game)
		end)
		task.wait()
	end

	-- Wait for the Duke to actually target us (fight starts).
	repeat
		task.wait()
		local duke = workspace.Live:FindFirstChild(DUKE_NAME)
		if duke and duke:FindFirstChild("Target") and duke.Target.Value then
			break
		end
	until not running
	readyWeapon()

	-- Detect the Duke's dangerous animations.
	task.delay(5, function()
		local duke = workspace.Live:FindFirstChild(DUKE_NAME)
		if duke and duke:FindFirstChildOfClass("Humanoid") then
			maid:mark(duke.Humanoid.AnimationPlayed:Connect(function(anim)
				local id = anim.Animation.AnimationId
				if id:find("8275408994") or id:find("8290899374") or id:find("8294560344") then
					nopeTfOut = true
					task.delay(id:find("8294560344") and 7.5 or 2.5, function()
						nopeTfOut = false
					end)
				end
			end))
		end
	end)

	-- Void mode?
	local voidingMode = Toggles and Toggles.DukeVoids and Toggles.DukeVoids.Value == true
	if Toggles and Toggles.VoidMobs then
		Toggles.VoidMobs:SetValue(voidingMode)
	end

	-- Main Duke loop.
	local duke = workspace.Live:FindFirstChild(DUKE_NAME)
	while running and workspace.Live:FindFirstChild(DUKE_NAME) do
		task.wait()
		duke = workspace.Live:FindFirstChild(DUKE_NAME)
		m1Hold(not General.playing_ap_anims(duke))

		if not duke:FindFirstChild("HumanoidRootPart") or not duke:FindFirstChild("Humanoid") or not duke.Parent or duke.Humanoid.Health <= 0 then
			break
		end

		-- Void mode: cast Frost Grab while safe.
		if voidingMode and not nopeTfOut and not General.playing_ap_anims(duke) then
			local frost = backpack() and backpack():FindFirstChild("Mantra:ChokeIce{{Frost Grab}}")
			if frost then
				pcall(function()
					character().CharacterHandler.Requests.ActivateMantra:FireServer(frost)
				end)
			end
		end

		local hrp = duke.HumanoidRootPart
		if hrp.CFrame.Y <= -1000 then
			continue -- void can fail; don't chase into the void
		end

		local x, y, z = hrp.CFrame:GetComponents()
		local xSin = math.sin(tick() * 2) * 30
		local zCos = math.cos(tick() * 2) * 30

		if General.playing_ap_anims(duke, { "rbxassetid://8085349676" }) or nopeTfOut then
			local critical = KeyHandling.getRemote("CriticalClick")
			if critical then
				pcall(function()
					critical:FireServer({ S = false, NOAERIALS = false, Space = false, Right = false, W = false, Left = true }, false)
				end)
			end
			tweenGoal(CFrame.new(x + xSin, y < 70 and math.random(175, 250) or math.random(0, 10), z + zCos), 250)
		elseif General.playing_ap_anims(duke) then
			tweenGoal(CFrame.new(x + xSin, y < 70 and math.random(175, 250) or math.random(0, 10), z + zCos), 250)
		else
			tweenGoal(hrp.CFrame * CFrame.new(0, -6, 0) * CFrame.Angles(math.rad(90), 0, 0), 250)
		end
	end
	m1Hold(false)
	Tweening.stop(MOVE_ID)
	if not running then
		return
	end

	-- Wait out danger, then loot the chests and respawn out.
	setStage("looting")
	task.delay(60 * 5, function()
		if not running then
			return
		end
		local er = getEffectReplicator()
		repeat
			task.wait()
			tempTween(CFrame.new(2495, 139, 1926), 160)
		until not (er and er:FindEffect("Danger")) or not running
		General.respawn()
	end)

	while running do
		local ok, res = pcall(grabChests)
		if ok and res then
			break
		end
		task.wait(1)
	end

	local er = getEffectReplicator()
	repeat
		task.wait()
		tempTween(CFrame.new(2495, 139, 1926), 160)
	until not (er and er:FindEffect("Danger")) or not running
	General.respawn()
end

-- =========================================================================================================
-- State machine.
-- =========================================================================================================
local stateMachine = StateMachine.create({
	initial = "idle",
	events = {
		{ name = "start", from = "idle", to = "_check_area" },
		{ name = "refill", from = "_check_area", to = "_refill" },
		{ name = "initiate", from = "_check_area", to = "_initiate" },
		{ name = "initiate", from = "_refill", to = "_initiate" },
		{ name = "kill", from = "_check_area", to = "_kill" },
	},
	callbacks = {
		onenter_check_area = function(self)
			if not running then
				return
			end
			setStage("check area")

			-- Somehow ended up in the Depths -> stop (PR kicks here).
			if game.PlaceId == DEPTHS_PLACE_ID then
				Logger.notify("Auto Duke: ended up in the Depths -- stopping.")
				return AutoDuke.stop()
			end

			local dungeon = localPlayer() and localPlayer():GetAttribute("Dungeon")
			if dungeon and tostring(dungeon):match("Duke") then
				return self:kill()
			end

			if game.PlaceId == EASTERN_PLACE_ID then
				-- Wrong region -- teleport back to the Etrean Luminant (manor is there).
				Teleports.etrean()
				return
			end

			if game.PlaceId == MAIN_GAME_PLACE_ID then
				self:refill()
				self:initiate()
				return
			end
		end,
		onenter_refill = function(self)
			if not running then
				return
			end
			refill()
			self:initiate()
		end,
		onenter_initiate = function(self)
			if not running then
				return
			end
			createInstance()
		end,
		onenter_kill = function(self)
			if not running then
				return
			end
			killDuke()
		end,
	},
})

-- =========================================================================================================
-- Struct.
-- =========================================================================================================
local function buildStruct()
	return AutomationStruct.construct({
		id = "auto_duke",
		state_machine = stateMachine,
		is_running = isRunning,
		features = {
			"no_fall",
			"noclip",
			"no_kill_bricks",
			"mod_detector",
			"fly",
			"m1_hold",
			"auto_wisp",
			"auto_equip_weapon",
			"auto_log",
		},
	})
end

-- =========================================================================================================
-- Public interface.
-- =========================================================================================================
function AutoDuke.start()
	local lp = localPlayer()
	if not lp then
		return
	end
	if running then
		return
	end
	if not AutoDuke.inValidPlace() then
		return Logger.notify("Auto Duke: not in the Etrean/Eastern Luminant.")
	end
	local slot = currentSlot()
	if not slot then
		return Logger.notify("Auto Duke: no data slot found.")
	end

	local data = PersistentData.get("dukedata") or {}
	data.slot = slot
	data.startedAt = data.startedAt or os.time()
	PersistentData.set("dukedata", data)

	running = true
	buildOverlay()
	AntiAFK.start("AutoDuke")

	maid:mark(task.spawn(runElapsed))

	stateMachine.current = "idle"
	stateMachine.asyncState = StateMachine.NONE
	stateMachine.currentTransitioningEvent = nil

	struct = buildStruct()
	struct:run()
end

function AutoDuke.stop()
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
		AntiAFK.stop("AutoDuke")
	end)
	maid:clean()
	destroyOverlay()
	PersistentData.set("dukedata", nil)
end

return AutoDuke
