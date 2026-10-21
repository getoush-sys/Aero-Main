-- Auto Saramed: a Aero port of project-rain-oss's `auto_saramed.lua`, on the AutomationStruct +
-- StateMachine framework. Enters the Saramed deepdrill dungeon (via Malisae in the Eastern Luminant),
-- clears the mobs, mines the magma ore, deposits it into the drill, loots, then resets the dungeon and
-- repeats. Keeps hunger/thirst topped up (gather + craft bread, drink at the well).
--
-- Public surface:
--   AutoSaramed.start() / .stop() / .inValidPlace()  (Eastern Luminant or the Saramed dungeon)
-- Persistence key: "sarameddata" { slot, startedAt }.
local AutoSaramed = {}

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

local SARAMED_PLACE_ID = 8668476218 -- the deepdrill (Saramed) dungeon.
local EASTERN_PLACE_ID = 6473861193 -- Eastern Luminant (Malisae, the dungeon entrance).
local MAIN_GAME_PLACE_ID = 6032399813 -- Etrean overworld (route back to Eastern from here).
local DEPTHS_PLACE_ID = 5735553160 -- The Depths (should never be here; stop if we are).

local MOVE_ID = "AutoSaramed_Move"
local MIN_HEALTH = 0.5 -- retreat/bail on the fight at or below this health fraction (raised from PR's 0.25 -- retreat earlier, at half HP).
local ATTACH_DISTANCE = 8 -- studs above the mob's torso when attaching (PR default: 8).

local running = false
local struct = nil
local maid = Maid.new()
local screenGui, elapsedLabel = nil, nil
local autoDepositThread = nil
local disconnectHandlerSet = false
local previousAutoDefense = nil -- EnableAutoDefense state before the run, restored on stop

local function isSaramed()
	return game.PlaceId == SARAMED_PLACE_ID
end

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
function AutoSaramed.inValidPlace()
	return game.PlaceId == SARAMED_PLACE_ID or game.PlaceId == EASTERN_PLACE_ID or game.PlaceId == MAIN_GAME_PLACE_ID
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
	screenGui.Name = "LumaAutoSaramedOverlay"
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
		Text = "Auto Saramed",
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
		AutoSaramed.stop()
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
		local data = PersistentData.get("sarameddata")
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
	value = (Options and Options.SaramedTweenSpeed and Options.SaramedTweenSpeed.Value) or 100
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
local function tweenGoal(cframe, speed)
	setSpeed(speed or 100)
	Tweening.goal(MOVE_ID, cframe, false)
end
local function playerCheck(mag, custom)
	local origin = custom or (root() and root().Position)
	if not origin then
		return false
	end
	for _, player in next, players:GetPlayers() do
		if player ~= localPlayer() and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			if (origin - player.Character.HumanoidRootPart.Position).Magnitude <= mag then
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
	if playerCheck(200) then
		serverHop()
		while task.wait() do
		end
		return
	end
	local r = root()
	if not r then
		return
	end
	local y = math.random(10000, 30000)
	r.CFrame = r.CFrame + Vector3.new(0, y, 0)
	tempTween(cf + Vector3.new(0, y, 0), speed)
	if playerCheck(200, cf.Position) then
		serverHop()
		while task.wait() do
		end
		return
	end
	r = root()
	if r then
		r.CFrame = cf
	end
	task.wait(0.3)
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
local function statValue(name)
	local c = character()
	return c and c:FindFirstChild(name)
end
local function clampCFrame(cf)
	return CFrame.new(Vector3.new(cf.Position.X, math.clamp(cf.Position.Y, 0, 1000), cf.Position.Z))
end

-- (Food/water refill removed -- hunger and thirst upkeep both dropped.)

-- =========================================================================================================
-- Combat + mining.
-- =========================================================================================================
local function foundMobs()
	for _, mob in next, workspace:WaitForChild("Live"):GetChildren() do
		if mob:GetAttribute("MOB_rich_name") then
			return true
		end
	end
	return false
end

local function closestMob()
	local live = workspace:FindFirstChild("Live")
	if not live then
		return nil
	end
	local closest, shortest = nil, math.huge
	for _, model in next, live:GetChildren() do
		if model:IsA("Model") and model ~= character() and model.Name:sub(1, 1) == "." then
			local r = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			local hum = model:FindFirstChildOfClass("Humanoid")
			if r and hum and hum.Health > 0 then
				local torso = model:FindFirstChild("Torso")
				if not (torso and torso:FindFirstChild("RagdollAttach")) then
					local dist = (r.Position - (root() and root().Position or Vector3.zero)).Magnitude
					if dist < shortest then
						shortest = dist
						closest = model
					end
				end
			end
		end
	end
	return closest
end

local function killTarget(target)
	if not target or not target:IsA("Model") then
		return
	end
	if target.Name:match(localPlayer().Name) then
		return
	end

	readyWeapon()
	if target:FindFirstChild("HumanoidRootPart") then
		tempTween(target.HumanoidRootPart.CFrame, 170)
	end

	local attach = task.spawn(function()
		local activeTween = false
		while running do
			if not target.Parent then
					break
				end
				local hrp = target:FindFirstChild("HumanoidRootPart")
				if not hrp then
					task.wait()
					continue
				end
				local cf
			if target.Name:lower():find("buncle") or target.Name:lower():find("knight") then
				cf = clampCFrame(hrp.CFrame) * CFrame.new(0, -ATTACH_DISTANCE, 0) * CFrame.Angles(math.rad(90), 0, 0)
			else
				cf = clampCFrame(hrp.CFrame) * CFrame.new(0, ATTACH_DISTANCE, 0) * CFrame.Angles(math.rad(-90), 0, 0)
			end
			local r = root()
			if r then
				r.AssemblyLinearVelocity = Vector3.zero
				if (r.Position - cf.Position).Magnitude > 30 then
					tweenGoal(cf, 100)
					activeTween = true
				else
					if activeTween then
						Tweening.stop(MOVE_ID)
						activeTween = false
					end
					r.CFrame = cf
				end
			end
			task.wait()
		end
		Tweening.stop(MOVE_ID)
	end)

	m1Hold(true)
	local startedAt = tick()
	repeat
		task.wait()
		m1Hold(true)
		local hum = target:FindFirstChildOfClass("Humanoid")
	until healthCheck(MIN_HEALTH) or target.Parent == nil or (hum and hum.Health <= 0) or (tick() - startedAt > 20) or not running
	pcall(function()
		task.cancel(attach)
	end)
	m1Hold(false)
	Tweening.stop(MOVE_ID)
	return healthCheck(MIN_HEALTH)
end

local function closestOre()
	local closest
	for _, ore in next, workspace:GetDescendants() do
		if ore:IsA("MeshPart") and ore.Name:match("MagmaOre") and ore:FindFirstChild("InteractPrompt") then
			if not closest then
				closest = ore
			elseif (root().Position - ore.Position).Magnitude < (root().Position - closest.Position).Magnitude then
				closest = ore
			end
		end
	end
	return closest
end

local function mineOre(target)
	if not target or target.Parent == nil or not target:IsA("MeshPart") or not target.Name:match("MagmaOre") then
		return false
	end
	tempTween(target.CFrame, 170)
	local r = root()
	if r then
		r.CFrame = target.CFrame
	end
	xpcall(function()
		for _ = 1, 60 do
			if not running then
				break
			end
			if root() then
				root().CFrame = target.CFrame
			end
			pcall(function()
				local prompt = target:FindFirstChild("InteractPrompt")
				if prompt then
					Prompt.interact(prompt)
				end
			end)
			task.wait()
		end
		local debounce = tick()
		repeat
			task.wait()
		until not target:FindFirstChild("InteractPrompt") or tick() - debounce > 5 or not running
	end, function() end)
	return true
end

local function depositOre()
	local deepdrill = workspace:FindFirstChild("Deepdrill")
	local dungeondrill = deepdrill and deepdrill:FindFirstChild("DungeonDrill")
	local fuelport = dungeondrill and dungeondrill:FindFirstChild("FuelPort")
	local hit = fuelport and fuelport:FindFirstChild("Hit")
	if hit then
		tempTween(hit.CFrame, 170)
		task.wait(1)
	end
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
				task.wait(0.1)
				pcall(function()
					Prompt.interact(chest:FindFirstChildWhichIsA("ProximityPrompt"))
				end)
				pcall(function()
					tempTween(chest.Lid.CFrame, 170)
				end)
			until (playerGui() and playerGui():FindFirstChild("ChoicePrompt")) or not running or tick() - t > 5
			local t2 = tick()
			repeat
				task.wait(0.1)
			until not (playerGui() and playerGui():FindFirstChild("ChoicePrompt")) or not running or tick() - t2 > 5
			break
		end
	end
end

-- =========================================================================================================
-- Stages.
-- =========================================================================================================
local function pathToSaramed()
	if isSaramed() then
		return
	end
	if game.PlaceId == EASTERN_PLACE_ID then
		setStage("entering Saramed")
		local malisaeCF = CFrame.new(-2835.7998046875, 136.5481414794922, 3442.84814453125, 0.541101158, 0, -0.840957522, 0, 1, 0, 0.840957522, 0, 0.541101158)
		playerSafeTween(malisaeCF, 170)
		task.wait(0.5)
		repeat
			task.wait()
		until workspace.NPCs:FindFirstChild("Malisae") or not running
		pcall(function()
			Prompt.interact(workspace.NPCs.Malisae.InteractPrompt)
		end)
		task.wait(3)
		pcall(function()
			replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue"):FireServer({ choice = "Enter alone." })
		end)
		task.wait(5)
	end
end

local function checkPlayerStatus()
	-- Food/water upkeep removed; nothing to do here now. Kept as a no-op so the _status state's call to it
	-- stays valid.
end

local function startDungeon()
	if not isSaramed() then
		return
	end
	repeat
		task.wait()
	until character() or not running

	if not (backpack() and backpack():FindFirstChild("Pickaxe")) and not (character() and character():FindFirstChild("Pickaxe")) then
		Logger.notify("[Auto Saramed] Please buy a pickaxe.")
		repeat
			task.wait()
		until (backpack() and backpack():FindFirstChild("Pickaxe"))
			or (character() and character():FindFirstChild("Pickaxe"))
			or not running
	end

	local deepdrill = workspace:FindFirstChild("Deepdrill")
	if not deepdrill then
		return
	end
	local drillSwitch = deepdrill.DungeonDrill.Switch.Case
	local evatorSwitch = deepdrill.Drillevator.Switch.Case
	local drillDist = (drillSwitch.Position - (root() and root().Position or Vector3.zero)).Magnitude
	local evatorDist = (evatorSwitch.Position - (root() and root().Position or Vector3.zero)).Magnitude

	setStage("starting dungeon")
	-- Use the nearer switch (DungeonDrill vs Drillevator).
	local useDrill = drillDist < evatorDist
	local switchCase = useDrill and drillSwitch or evatorSwitch
	local switchObj = useDrill and deepdrill.DungeonDrill.Switch or deepdrill.Drillevator.Switch
	-- Keep pressing it until the drill actually starts (mobs spawn). A single press sometimes misses -- the
	-- tween hasn't landed or the prompt is briefly out of range -- and nothing retried, so completeDungeon
	-- then waited forever on mobs that never came and the farm just stopped. Re-tween + re-press each pass.
	repeat
		if root() then
			root().CFrame = CFrame.new(root().CFrame.X, switchCase.CFrame.Y, root().CFrame.Z)
		end
		-- Nudge the stand spot 2 studs right (+X) and 1 stud forward (-Z, the lever's LookVector) relative
		-- to the lever, so we land on the interactable side instead of on top of the Case.
		tempTween(switchCase.CFrame * CFrame.new(2, 0, -1), 170)
		task.wait(1)
		pcall(function()
			Prompt.interact(switchObj.InteractPrompt)
		end)
		task.wait(2)
	until foundMobs() or not running
end

local function completeDungeon()
	if not isSaramed() then
		return
	end
	setStage("clearing mobs")
	repeat
		task.wait()
	until foundMobs() or not running

	repeat
		pcall(function()
			killTarget(closestMob())
		end)
		if healthCheck(MIN_HEALTH) or not running then
			break
		end
		task.wait()
	until not foundMobs()

	if not running or healthCheck(MIN_HEALTH) then
		return
	end

	setStage("mining ore")
	for _ = 0, 5 do
		local ore
		repeat
			ore = closestOre()
			task.wait()
		until ore ~= nil or not running
		if not running then
			break
		end
		mineOre(ore)
	end
	if not running then
		return
	end

	depositOre()

	-- Keep mining until the fuel bar is full (green).
	local function fuelFull()
		local ok, full = pcall(function()
			local bar = workspace.Deepdrill.DungeonDrill.FuelPort.Display.SurfaceGui.Bar
			return bar.BackgroundColor3:ToHex() == Color3.fromRGB(141, 239, 112):ToHex()
		end)
		return ok and full
	end
	if not fuelFull() then
		repeat
			for _, ore in next, workspace:GetDescendants() do
				if ore:IsA("MeshPart") and ore.Name:match("MagmaOre") then
					if not running then
						break
					end
					mineOre(ore)
					break
				end
			end
			depositOre()
			task.wait()
		until fuelFull() or not running
	end

	if not running then
		return
	end
	setStage("looting")
	grabChest()
end

local function resetDungeon()
	if not isSaramed() or not running then
		return
	end
	setStage("resetting dungeon")
	local deepdrill = workspace:FindFirstChild("Deepdrill")
	local dungeondrill = deepdrill and deepdrill:FindFirstChild("DungeonDrill")
	local radio = dungeondrill and dungeondrill:FindFirstChild("Radio")
	local destructibles = workspace:FindFirstChild("Destructibles")
	if not radio or not destructibles then
		return
	end

	-- Retreat uses the radio (workspace.Deepdrill.DungeonDrill.Radio), NOT the lever -- the lever is for
	-- going deeper, the radio is for retreating. Tween onto the RADIO itself (GetPivot handles part-or-model)
	-- and press E on it (same as every other interaction) until the retreat ChoicePrompt shows, then confirm.
	tempTween(radio:GetPivot(), 170)
	local vim = Instance.new("VirtualInputManager")
	repeat
		task.wait()
		pcall(function()
			vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
			task.wait(0.1)
			vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
		end)
		tempTween(radio:GetPivot(), 170)
	until (playerGui() and playerGui():FindFirstChild("ChoicePrompt")) or not running
	vim:Destroy()
	pcall(function()
		playerGui().ChoicePrompt.Choice:FireServer(true)
	end)

	local campfire = destructibles:FindFirstChild("Campfire")
	if not campfire then
		return
	end
	local dist = math.huge
	repeat
		task.wait()
		local part = campfire:FindFirstChildWhichIsA("Part")
		if part then
			dist = (part.Position - (root() and root().Position or Vector3.zero)).Magnitude
		end
	until dist <= 150 or not running

	if not healthCheck(0.7) then
		return
	end

	local er = getEffectReplicator()
	repeat
		tempTween(campfire.Part.CFrame, 170)
		if root() then
			root().CFrame = campfire.Part.CFrame * CFrame.new(0, 1, 0)
		end
		task.wait(1)
		pcall(function()
			Prompt.interact(campfire.InteractPrompt)
		end)
		task.wait(1)
	until (er and er:FindEffect("Resting")) or not running
	repeat
		task.wait()
	until (humanoid() and humanoid().Health >= humanoid().MaxHealth * 0.7) or not running
	local vim = Instance.new("VirtualInputManager")
	pcall(function()
		vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
		task.wait(0.1)
		vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	end)
	task.wait(1)
	vim:Destroy()
end

-- On a Roblox disconnect (kick), keep the slot in MemStorage and server-hop to reconnect (PR resilience).
local function setupDisconnectHandler()
	if disconnectHandlerSet then
		return
	end
	disconnectHandlerSet = true
	local guiService = game:GetService("GuiService")
	maid:mark(guiService.ErrorMessageChanged:Connect(function()
		local ok, code = pcall(function()
			return guiService:GetErrorCode().Value
		end)
		if ok and code and code >= Enum.ConnectionError.DisconnectErrors.Value then
			pcall(function()
				local memStorage = game:GetService("MemStorageService")
				memStorage:SetItem("DataSlot", localPlayer():GetAttribute("DataSlot"))
			end)
			while task.wait() do
				pcall(serverHop)
			end
		end
	end))
end

-- Auto-deposit any MagmaOre we're carrying (runs the whole time we're in the dungeon).
local function startAutoDeposit()
	if autoDepositThread then
		return
	end
	autoDepositThread = task.spawn(function()
		while running do
			if isSaramed() and character() and character():FindFirstChild("MagmaOre") then
				pcall(function()
					local hit = workspace.Deepdrill.DungeonDrill.FuelPort.Hit
					firetouchinterest(character().MagmaOre, hit, 0)
					firetouchinterest(character().MagmaOre, hit, 1)
				end)
			end
			task.wait(0.2)
		end
	end)
	maid:mark(autoDepositThread)
end

-- =========================================================================================================
-- State machine.
-- =========================================================================================================
local stateMachine = StateMachine.create({
	initial = "idle",
	events = {
		{ name = "start", from = "idle", to = "_check_area" },
		{ name = "path", from = "_check_area", to = "_path" },
		{ name = "status", from = "_path", to = "_status" },
		{ name = "dungeonStart", from = "_status", to = "_start_dungeon" },
		{ name = "dungeonComplete", from = "_start_dungeon", to = "_complete_dungeon" },
		{ name = "dungeonContinuation", from = "_complete_dungeon", to = "_start_dungeon" },
		{ name = "dungeonReset", from = "_complete_dungeon", to = "_reset_dungeon" },
		{ name = "fullReset", from = "_reset_dungeon", to = "_check_area" },
	},
	callbacks = {
		onenter_check_area = function(self)
			if not running then
				return
			end
			setStage("check area")
			setupDisconnectHandler()
			startAutoDeposit()

			-- Somehow ended up in the Depths -> stop (PR kicks here).
			if game.PlaceId == DEPTHS_PLACE_ID then
				Logger.notify("Auto Saramed: ended up in the Depths -- stopping.")
				return AutoSaramed.stop()
			end

			-- Etrean overworld -> route to Eastern.
			if game.PlaceId == MAIN_GAME_PLACE_ID then
				Teleports.eastern()
				return
			end

			self:path()
		end,
		onenter_path = function(self)
			if not running then
				return
			end
			pathToSaramed()
			self:status()
		end,
		onenter_status = function(self)
			if not running then
				return
			end
			checkPlayerStatus()
			self:dungeonStart()
		end,
		onenter_start_dungeon = function(self)
			if not running then
				return
			end
			startDungeon()
			self:dungeonComplete()
		end,
		onenter_complete_dungeon = function(self)
			if not running then
				return
			end
			completeDungeon()

			-- Keep diving unless we're low or hit the bottom (2.00 depth).
			local atBottom = false
			pcall(function()
				atBottom = workspace.Deepdrill.DungeonDrill.DepthDisplay.SurfaceGui.TextLabel.Text:find("2.00") ~= nil
			end)
			if not healthCheck(MIN_HEALTH) and not atBottom then
				task.defer(function()
					self:dungeonContinuation()
				end)
			else
				task.defer(function()
					self:dungeonReset()
				end)
			end
		end,
		onenter_reset_dungeon = function(self)
			if not running then
				return
			end
			resetDungeon()
			self:fullReset()
		end,
	},
})

-- =========================================================================================================
-- Struct.
-- =========================================================================================================
local function buildStruct()
	return AutomationStruct.construct({
		id = "auto_saramed",
		state_machine = stateMachine,
		is_running = isRunning,
		features = {
			"no_fall",
			"noclip",
			"fly",
			"no_fire",
			"no_stun",
			"fast_swing",
			"m1_hold",
			"auto_equip_weapon",
			"auto_log",
		},
	})
end

-- Force Auto Defense (the parry/block engine) on for the run, remembering its previous state so stopping
-- the farm puts it back to whatever it was. Auto Saramed fights the dungeon mobs, so it wants defense up.
local function applyAutoDefense()
	if not Toggles or not Toggles.EnableAutoDefense then
		return
	end
	previousAutoDefense = Toggles.EnableAutoDefense.Value
	Toggles.EnableAutoDefense:SetValue(true)
end

local function restoreAutoDefense()
	if previousAutoDefense ~= nil and Toggles and Toggles.EnableAutoDefense then
		Toggles.EnableAutoDefense:SetValue(previousAutoDefense)
	end
	previousAutoDefense = nil
end

-- =========================================================================================================
-- Public interface.
-- =========================================================================================================
function AutoSaramed.start()
	local lp = localPlayer()
	if not lp then
		return
	end
	if running then
		return
	end
	if not AutoSaramed.inValidPlace() then
		return Logger.notify("Auto Saramed: not in the Eastern Luminant or the Saramed dungeon.")
	end
	local slot = currentSlot()
	if not slot then
		return Logger.notify("Auto Saramed: no data slot found.")
	end

	local data = PersistentData.get("sarameddata") or {}
	data.slot = slot
	data.startedAt = data.startedAt or os.time()
	PersistentData.set("sarameddata", data)

	running = true
	applyAutoDefense()
	buildOverlay()
	AntiAFK.start("AutoSaramed")

	maid:mark(task.spawn(runElapsed))

	stateMachine.current = "idle"
	stateMachine.asyncState = StateMachine.NONE
	stateMachine.currentTransitioningEvent = nil

	struct = buildStruct()
	struct:run()
end

function AutoSaramed.stop()
	if not running then
		return
	end
	running = false
	restoreAutoDefense()
	if struct then
		pcall(function()
			struct:stop()
		end)
		struct = nil
	end
	Tweening.stop(MOVE_ID)
	pcall(function()
		AntiAFK.stop("AutoSaramed")
	end)
	maid:clean()
	autoDepositThread = nil
	disconnectHandlerSet = false
	destroyOverlay()
	PersistentData.set("sarameddata", nil)
end

return AutoSaramed
