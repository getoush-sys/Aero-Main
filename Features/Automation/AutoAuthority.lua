-- Auto Authority Missions: a Aero port of project-rain-oss's `auto_authority.lua`, on the ported
-- AutomationStruct + StateMachine framework. Runs the Fort Merit authority missions in the Eastern
-- Luminant: talk to Captain Trist, accept a job, identify which one (Hostage / Armament Sabotage / Secure),
-- complete it if it's enabled in the menu, report back, repeat.
--
-- Public surface:
--   AutoAuthority.start()        -- menu Start + Aero.lua resume
--   AutoAuthority.stop()
--   AutoAuthority.inValidPlace() -- resume gate (Eastern Luminant)
-- Persistence key: "authoritydata" { slot, startedAt }.
-- Menu toggles read here: AuthorityHostage / AuthorityBarrels / AuthoritySecure (which jobs to do).
local AutoAuthority = {}

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

---@module Features.Automation.Objects.AutoLog
local AutoLog = require("Features/Automation/Objects/AutoLog")

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local AUTHORITY_PLACE_ID = 6473861193 -- Eastern Luminant (Fort Merit / Captain Trist).

local MOVE_ID = "AutoAuthority_Move"
local TRIST_HIGH = CFrame.new(-7502, 2000, 3481)
local TRIST_LOW = CFrame.new(-7502, 11, 3481)
local TWEEN_SPEED = 225
local PLAYER_SAFE_RADIUS = 300
local JOB_SCAN_INTERVAL = 0.5
local MISSION_SCAN_INTERVAL = 0.2
local HOSTAGE_MISSION_TIMEOUT = 150
local HOSTAGE_LOW_HEALTH_RATIO = 0.25

local running = false
local safetyHold = false
local m1Hold
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

function AutoAuthority.inValidPlace()
	return game.PlaceId == AUTHORITY_PLACE_ID
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
	for key, value in pairs(props) do
		instance[key] = value
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
	screenGui.Name = "LumaAutoAuthorityOverlay"
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
		Text = "Auto Authority",
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
		AutoAuthority.stop()
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
		local data = PersistentData.get("authoritydata")
		if elapsedLabel and data then
			elapsedLabel.Text = "Elapsed: " .. formatDuration(math.max(0, os.time() - (data.startedAt or os.time())))
		end
		task.wait(0.5)
	end
end

-- =========================================================================================================
-- Movement.
-- =========================================================================================================
local function setSpeed(value)
	value = (Options and Options.AuthorityTweenSpeed and Options.AuthorityTweenSpeed.Value) or 100
	if Options and Options.TweenStudsPerSecond and Options.TweenStudsPerSecond.Value ~= value then
		Options.TweenStudsPerSecond:SetValue(value)
	end
end

---Blocking tween to a CFrame (PR's Tween.new(cf, true, speed).wait()).
local function tweenTo(cframe, speed, deadline, continueWhile)
	while running and safetyHold do
		if deadline and os.clock() >= deadline then
			return false
		end
		if continueWhile and not continueWhile() then
			return false
		end
		task.wait()
	end
	if not running then
		return false
	end

	setSpeed(speed or TWEEN_SPEED)
	Tweening.goal(MOVE_ID, cframe, false)
	local goalPos = cframe.Position
	while running do
		if deadline and os.clock() >= deadline then
			Tweening.stop(MOVE_ID)
			return false
		end
		if continueWhile and not continueWhile() then
			Tweening.stop(MOVE_ID)
			return false
		end
		if safetyHold then
			Tweening.stop(MOVE_ID)
			repeat
				if deadline and os.clock() >= deadline then
					return false
				end
				task.wait()
			until not running or not safetyHold
			if not running then
				return false
			end
			Tweening.goal(MOVE_ID, cframe, false)
		end
		local r = root()
		if r and (r.Position - goalPos).Magnitude <= 4 then
			break
		end
		task.wait()
	end
	Tweening.stop(MOVE_ID)
	return running
end

local function serverHop()
	local ok, err = pcall(function()
		ServerHop.hop(currentSlot(), true)
	end)
	if not ok then
		Logger.warn("Auto Authority server hop failed:", tostring(err))
	end
	return ok
end

-- =========================================================================================================
-- Captain Trist interaction + mission identification.
-- =========================================================================================================
local sendDialogue = nil
local dialogueOpen = false -- PR's `got`
local dialogueFires = 0 -- PR's `fc`

local function connectDialogueListener()
	if sendDialogue then
		return
	end
	pcall(function()
		sendDialogue = replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue")
		maid:mark(sendDialogue.OnClientEvent:Connect(function(v)
			dialogueOpen = not (v and v.exit)
			dialogueFires = dialogueFires + 1
		end))
	end)
end

local function fireDialogue(payload)
	if sendDialogue and not safetyHold then
		pcall(function()
			sendDialogue:FireServer(payload)
		end)
	end
end

---Tween to Captain Trist and fire his prompt until the dialogue opens.
local function reachTrist(deadline, continueWhile)
	setStage("talking to Captain Trist")
	repeat
		if not tweenTo(TRIST_HIGH, TWEEN_SPEED, deadline, continueWhile)
			or not tweenTo(TRIST_LOW, TWEEN_SPEED, deadline, continueWhile)
		then
			return false
		end
		local npcs = workspace:FindFirstChild("NPCs")
		local trist = npcs and npcs:FindFirstChild("Captain Trist")
		local prompt = trist and trist:FindFirstChild("InteractPrompt")
		if prompt and prompt:IsA("ProximityPrompt") and not safetyHold then
			Prompt.fire(prompt)
		end
		task.wait(MISSION_SCAN_INTERVAL)
	until dialogueOpen or not running or (deadline and os.clock() >= deadline)
		or (continueWhile and not continueWhile())
	return dialogueOpen and running and (not continueWhile or continueWhile())
end

---Close any open dialogue (fire exit until the DialogueGui closes).
local function exitDialogue()
	local start = tick()
	repeat
		fireDialogue({ exit = true })
		task.wait(0.5)
	until not (playerGui() and playerGui():FindFirstChild("DialogueGui") and playerGui().DialogueGui.Enabled)
		or not running
		or tick() - start > 8
end

---Identify the accepted job by scanning Terrain for the JobTrackerGui attachment. Returns jobType, cframe.
local function identifyJob()
	local terrain = workspace:FindFirstChild("Terrain")
	if not terrain then
		return nil, nil
	end
	local deadline = os.clock() + 8
	repeat
		for _, entity in next, terrain:GetDescendants() do
			if entity:IsA("Attachment") then
				local jobTracker = entity:FindFirstChild("JobTrackerGui")
				local textLabel = jobTracker and jobTracker:FindFirstChild("TextLabel")
				if textLabel then
					local text = textLabel.Text
					local jobType = (text:find("Hostage") and "hostage")
						or (text:lower():find("secure") and "secure")
						or (text:find("Armanent Sabotage") and "barrels")
					if jobType then
						return jobType, entity.CFrame
					end
				end
			end
		end
		task.wait(JOB_SCAN_INTERVAL)
	until os.clock() >= deadline or not running
	return nil, nil
end

local function wantsJob(jobType)
	local map = {
		hostage = { "AuthorityHostage", "hostage" },
		barrels = { "AuthorityBarrels", "barrels" },
		secure = { "AuthoritySecure", "secure" },
	}
	local toggle = map[jobType]
	if not toggle then
		return false
	end
	local control = Toggles and Toggles[toggle[1]]
	if control then
		return control.Value == true
	end
	local saved = PersistentData.get("authorityMissionToggles")
	return type(saved) ~= "table" or saved[toggle[2]] ~= false
end

m1Hold = function(state)
	if state and safetyHold then
		state = false
	end
	local feat = struct and struct.active_features and struct.active_features["m1_hold"]
	if feat then
		feat.held = state
	end
end

-- =========================================================================================================
-- Missions.
-- =========================================================================================================
local function splashSaysReportBack()
	local gui = playerGui() and playerGui():FindFirstChild("SplashGui")
	local frame = gui and gui:FindFirstChild("TimeFrame")
	local label = frame and frame:FindFirstChild("TimeText")
	return label ~= nil and label.Text:lower():find("report back") ~= nil
end

local function missionHostage(object)
	setStage("mission: hostage")
	local deadline = os.clock() + HOSTAGE_MISSION_TIMEOUT

	local function shouldAbort()
		if os.clock() >= deadline then
			return "timed out after " .. HOSTAGE_MISSION_TIMEOUT .. " seconds"
		end
		local humanoid = character() and character():FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MaxHealth > 0
			and humanoid.Health <= humanoid.MaxHealth * HOSTAGE_LOW_HEALTH_RATIO
		then
			return "health dropped below 25%"
		end
		return nil
	end

	local function abort(reason)
		m1Hold(false)
		if reason == "health dropped below 25%" then
			Tweening.stop(MOVE_ID)
			local currentRoot = root()
			if currentRoot then
				currentRoot.CFrame = CFrame.new(
					currentRoot.Position.X,
					3000,
					currentRoot.Position.Z
				)
			end
		end
		Logger.warn("Auto Authority hostage mission aborted:", reason)
		serverHop()
		return false
	end

	exitDialogue()

	local abortReason = shouldAbort()
	if abortReason then
		return abort(abortReason)
	end

	if not tweenTo(object * CFrame.new(0, 2000, 0), TWEEN_SPEED, deadline)
		or not tweenTo(object, TWEEN_SPEED, deadline)
	then
		if not running then
			return false
		end
		abortReason = shouldAbort()
		return abort(abortReason or "movement interrupted")
	end

	local live = workspace:FindFirstChild("Live")
	local hostage
	repeat
		local abortReason = shouldAbort()
		if abortReason then
			return abort(abortReason)
		end
		for _, entity in next, (live and live:GetChildren() or {}) do
			if entity.Name:find("%.hostage") and entity:FindFirstChild("HumanoidRootPart") then
				if (entity.HumanoidRootPart.Position - (root() and root().Position or Vector3.zero)).Magnitude <= 1000 then
					if not tweenTo(entity.HumanoidRootPart.CFrame, TWEEN_SPEED, deadline) then
						local abortReason = shouldAbort()
						if abortReason then
							return abort(abortReason)
						end
						return false
					end
					hostage = entity
					break
				end
			end
		end
		task.wait(MISSION_SCAN_INTERVAL)
	until hostage or not running
	if not hostage then
		return false
	end

	if not tweenTo(hostage.HumanoidRootPart.CFrame, TWEEN_SPEED, deadline) then
		local abortReason = shouldAbort()
		if abortReason then
			return abort(abortReason)
		end
		return false
	end

	local er = getEffectReplicator()
	local lastCarryRequest = 0
	local function carryingOrDelivered()
		return dialogueOpen or (er and er:FindEffect("Carrying") ~= nil)
	end
	while running do
		local abortReason = shouldAbort()
		if abortReason then
			return abort(abortReason)
		end
		local carrying = er and er:FindEffect("Carrying")
		if carrying then
			local currentRoot = root()
			if currentRoot and currentRoot.Position.Y < 1996 then
				if not tweenTo(
					CFrame.new(currentRoot.Position.X, 2000, currentRoot.Position.Z),
					TWEEN_SPEED,
					deadline,
					carryingOrDelivered
				) then
					abortReason = shouldAbort()
					if abortReason then
						return abort(abortReason)
					end
				end
			end
			if carryingOrDelivered() and reachTrist(deadline, carryingOrDelivered) then
				return true
			end
		else
			local hostageRoot = hostage and hostage.Parent and hostage:FindFirstChild("HumanoidRootPart")
			if hostageRoot then
				local currentRoot = root()
				if currentRoot and (currentRoot.Position - hostageRoot.Position).Magnitude > 10 then
					if not tweenTo(hostageRoot.CFrame, TWEEN_SPEED, deadline) then
						abortReason = shouldAbort()
						if abortReason then
							return abort(abortReason)
						end
					end
				end
			end
			local handler = character() and character():FindFirstChild("CharacterHandler")
			local requests = handler and handler:FindFirstChild("Requests")
			local carry = requests and requests:FindFirstChild("Carry")
			local now = tick()
			if carry and now - lastCarryRequest >= 4 then
				lastCarryRequest = now
				if not safetyHold then
					pcall(function()
						carry:FireServer()
					end)
				end
			end
		end
		task.wait(MISSION_SCAN_INTERVAL)
	end
	return false
end

local function missionBarrels(object)
	setStage("mission: barrels")
	exitDialogue()

	if not safetyHold then
		pcall(function()
			character().CharacterHandler.Requests.DrawWeapon:FireServer(true)
		end)
	end
	tweenTo(object * CFrame.new(0, 1500, 0), TWEEN_SPEED)
	tweenTo(object * CFrame.new(0, 200, 0), TWEEN_SPEED)

	local destructibles = workspace:FindFirstChild("Destructibles")
	while running do
		if splashSaysReportBack() then
			break
		end
		local crates = {}
		local crateDistances = {}
		local rp = root() and root().Position or Vector3.zero
		if destructibles then
			for _, crate in next, destructibles:GetChildren() do
				if crate.Name:find("KhanCrate") and crate:IsA("Model") then
					local pivot = crate:GetPivot().Position
					local distance = (Vector3.new(pivot.X, 0, pivot.Z) - Vector3.new(rp.X, 0, rp.Z)).Magnitude
					if distance < 1200 then
						table.insert(crates, crate)
						crateDistances[crate] = distance
					end
				end
			end
		end
		table.sort(crates, function(a, b)
			return crateDistances[a] < crateDistances[b]
		end)
		for _, crate in ipairs(crates) do
			while running and crate:GetAttribute("StructureHealth") and crate:GetAttribute("StructureHealth") > 0 do
				m1Hold(true)
				tweenTo(CFrame.new((crate:GetPivot() * CFrame.new(0, -5, 0)).Position) * CFrame.Angles(math.rad(90), 0, 0), TWEEN_SPEED)
				task.wait(MISSION_SCAN_INTERVAL)
			end
			m1Hold(false)
		end
		task.wait(MISSION_SCAN_INTERVAL)
	end
	m1Hold(false)

	reachTrist()
end

local function missionSecure(object)
	setStage("mission: secure")

	tweenTo(object * CFrame.new(0, 1500, 0), TWEEN_SPEED)
	tweenTo(object, TWEEN_SPEED)

	local banner
	repeat
		for _, model in next, workspace:GetChildren() do
			if model.Name == "Authority Checkpoint" and model:IsA("Model") then
				local pivot = model:GetPivot().Position
				local rp = root() and root().Position or Vector3.zero
				if (Vector3.new(pivot.X, 0, pivot.Z) - Vector3.new(rp.X, 0, rp.Z)).Magnitude < 1200 then
					banner = model
				end
			end
		end
		task.wait(MISSION_SCAN_INTERVAL)
	until banner or not running
	if not banner then
		return
	end

	-- PR's 3-phase capture loop: sit on the banner (0-35s), fly high above it (35-125s), sit again
	-- (125-155s), each phase bailing out the moment the objective completes ("report back").
	while running do
		tweenTo(banner:GetPivot() * CFrame.new(0, 8, 0), TWEEN_SPEED)
		local start = tick()
		local stop = false

		repeat
			task.wait(MISSION_SCAN_INTERVAL)
			if splashSaysReportBack() then
				stop = true
				break
			end
		until tick() - start > 35 or not running
		if stop then
			break
		end

		repeat
			task.wait(MISSION_SCAN_INTERVAL)
			if splashSaysReportBack() then
				stop = true
				break
			end
			tweenTo(banner:GetPivot() * CFrame.new(0, 3000, 0), TWEEN_SPEED)
		until tick() - start > 90 + 35 or not running
		if stop then
			break
		end

		repeat
			task.wait(MISSION_SCAN_INTERVAL)
			if splashSaysReportBack() then
				stop = true
				break
			end
			tweenTo(banner:GetPivot() * CFrame.new(0, 8, 0), TWEEN_SPEED)
		until tick() - start > 120 + 35 or not running
		if stop then
			break
		end

		if splashSaysReportBack() then
			break
		end
	end

	reachTrist()
end

-- =========================================================================================================
-- State machine.
-- =========================================================================================================
local function runPlayerSafeWatch()
	-- Pause mission activity while a nearby player is a threat, then hop after Danger clears or they leave.
	maid:mark(task.spawn(function()
		local er = getEffectReplicator()
		local radius = math.max(PLAYER_SAFE_RADIUS, AutoLog.get("auto_authority"))

		local function nearbyPlayer()
			local r = root()
			if not r then
				return nil
			end
			local position = Vector3.new(r.Position.X, 0, r.Position.Z)
			for _, player in ipairs(players:GetPlayers()) do
				if player ~= localPlayer() then
					local otherRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if otherRoot then
						local otherPosition = Vector3.new(otherRoot.Position.X, 0, otherRoot.Position.Z)
						if (position - otherPosition).Magnitude <= radius then
							return player
						end
					end
				end
			end
			return nil
		end

		while running do
			if nearbyPlayer() then
				safetyHold = true
				m1Hold(false)
				Tweening.stop(MOVE_ID)
				if er and er:HasEffect("Danger") then
					repeat
						local r = root()
						if r then
							r.CFrame = CFrame.new(r.CFrame.X, 3000, r.CFrame.Z)
						end
						task.wait(0.1)
					until not running or not nearbyPlayer() or not (er and er:HasEffect("Danger"))
				end
				if not running then
					return
				end
				if not serverHop() then
					safetyHold = false
					task.wait(1)
				else
					return
				end
			end
			task.wait(MISSION_SCAN_INTERVAL)
		end
	end))
end

local stateMachine = StateMachine.create({
	initial = "idle",
	events = {
		{ name = "start", from = "idle", to = "_check_area" },
		{ name = "continuation", from = "_check_area", to = "_check_area" },
	},
	callbacks = {
		onenter_check_area = function(self)
			if not running then
				return
			end
			if game.PlaceId ~= AUTHORITY_PLACE_ID then
				return
			end

			pcall(function()
				replicatedStorage:WaitForChild("Requests"):WaitForChild("UpdateUXSettings"):FireServer("FriendlyFire", true)
			end)

			connectDialogueListener()

			-- Talk to Captain Trist + accept the job.
			reachTrist()
			if not running then
				return
			end

			-- Advance past the intro with "Yes, Sir." until the dialogue state moves on.
			setStage("accepting job")
			local startFires = dialogueFires
			repeat
				fireDialogue({ choice = "Yes, Sir." })
				task.wait(MISSION_SCAN_INTERVAL)
			until startFires ~= dialogueFires or not running

			-- Background: keep the conversation closed once accepted.
			maid:mark(task.spawn(function()
				while running and dialogueOpen do
					fireDialogue({ exit = true })
					task.wait(MISSION_SCAN_INTERVAL)
				end
			end))

			-- Figure out which job we accepted.
			setStage("identifying job")
			local jobType, object = identifyJob()

			if not jobType or not object or not wantsJob(jobType) then
				-- Rejoining is faster than doing an unwanted job.
				serverHop()
				return
			end

			if jobType == "hostage" then
				if not missionHostage(object) then
					return
				end
			elseif jobType == "barrels" then
				missionBarrels(object)
			elseif jobType == "secure" then
				missionSecure(object)
			end

			exitDialogue()
			self:continuation()
		end,
	},
})

-- =========================================================================================================
-- Struct.
-- =========================================================================================================
local function buildStruct()
	return AutomationStruct.construct({
		id = "auto_authority",
		state_machine = stateMachine,
		is_running = isRunning,
		features = {
			"fly",
			"noclip",
			"no_fall",
			"no_kill_bricks",
			"m1_hold",
			"no_fire",
			"auto_equip_weapon",
		},
	})
end

-- =========================================================================================================
-- Public interface.
-- =========================================================================================================
function AutoAuthority.start()
	local lp = localPlayer()
	if not lp then
		return
	end
	if running then
		return
	end
	if not AutoAuthority.inValidPlace() then
		return Logger.notify("Auto Authority: not in the Eastern Luminant.")
	end

	local slot = currentSlot()
	if not slot then
		return Logger.notify("Auto Authority: no data slot found.")
	end

	local data = PersistentData.get("authoritydata") or {}
	data.slot = slot
	data.startedAt = data.startedAt or os.time()
	PersistentData.set("authoritydata", data)

	running = true
	safetyHold = false
	dialogueOpen = false
	dialogueFires = 0
	buildOverlay()
	AntiAFK.start("AutoAuthority")

	maid:mark(task.spawn(runElapsed))
	runPlayerSafeWatch()

	stateMachine.current = "idle"
	stateMachine.asyncState = StateMachine.NONE
	stateMachine.currentTransitioningEvent = nil

	struct = buildStruct()
	struct:run()
end

function AutoAuthority.stop()
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
		AntiAFK.stop("AutoAuthority")
	end)

	maid:clean()
	sendDialogue = nil
	destroyOverlay()

	PersistentData.set("authoritydata", nil)
end

return AutoAuthority
