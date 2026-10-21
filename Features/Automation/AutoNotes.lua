-- Auto Notes (Ministry note farm): a Aero port of project-rain-oss's `ministry_notefarm.lua`, on the
-- AutomationStruct + StateMachine framework. Creates an Etris character, shares Knowledge with the
-- Soothsayer, deposits Notes at the bank (or a guild base + treasury), then wipes and repeats. Stops once
-- the bank is full ("max notes").
--
-- Public surface:
--   AutoNotes.start() / .stop() / .inValidPlace()  (overworld / character creation / fragments)
-- Persistence key: "notesdata" { slot, startedAt, maxNotes }.
-- Menu toggle read here: NotesUseGuild.
local AutoNotes = {}

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")
---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")
---@module Game.Wipe
local Wipe = require("Game/Wipe")
---@module Features.Game.Tweening
local Tweening = require("Features/Game/Tweening")
---@module Utility.Prompt
local Prompt = require("Utility/Prompt")
---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.SafeClick
local safeClick = require("Utility/SafeClick")
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

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local MAIN_GAME_PLACE_ID = 6032399813 -- overworld (Etrean Luminant) + character creation.
local MOVE_ID = "AutoNotes_Move"

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
local function playerGui()
	local lp = localPlayer()
	return lp and lp:FindFirstChildOfClass("PlayerGui")
end
local function backpack()
	local lp = localPlayer()
	return lp and lp:FindFirstChildOfClass("Backpack")
end
local function currentSlot()
	local lp = localPlayer()
	return lp and lp:GetAttribute("DataSlot")
end
local function currentArea()
	local lp = localPlayer()
	return lp and lp:GetAttribute("CurrentArea")
end
local function isRunning()
	return running
end
function AutoNotes.inValidPlace()
	return game.PlaceId == MAIN_GAME_PLACE_ID
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
	screenGui.Name = "LumaAutoNotesOverlay"
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
		Text = "Auto Notes",
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
		AutoNotes.stop()
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
		local data = PersistentData.get("notesdata")
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
	value = (Options and Options.NotesTweenSpeed and Options.NotesTweenSpeed.Value) or 100
	if Options and Options.TweenStudsPerSecond and Options.TweenStudsPerSecond.Value ~= value then
		Options.TweenStudsPerSecond:SetValue(value)
	end
end
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
local function playersNear(target, mag)
	for _, player in next, players:GetPlayers() do
		if player ~= localPlayer() and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			if (player.Character.HumanoidRootPart.Position - target.Position).Magnitude <= mag then
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
local function playerSafeTween(cf, speed, level)
	if playerCheck(200) then
		serverHop()
		while task.wait() do
		end
		return
	end
	local yLevel = level or -20
	local r = root()
	if not r then
		return
	end
	r.CFrame = r.CFrame + Vector3.new(0, yLevel, 0)
	tempTween(cf + Vector3.new(0, yLevel, 0), speed)
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
end
local function dialogueChoice(value)
	pcall(function()
		replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue"):FireServer({ choice = value })
	end)
end
local function dialogueExit()
	pcall(function()
		replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue"):FireServer({ exit = true })
	end)
end
local function click(btn)
	if btn then
		-- safeClick (handler .Function call) instead of firesignal -- firesignal is a native-crash risk pcall
		-- can't catch (see Utility/SafeClick).
		safeClick(btn)
		task.wait(0.2)
	end
end
local function dialogueOpen()
	local gui = playerGui()
	local dg = gui and gui:FindFirstChild("DialogueGui")
	return dg ~= nil and dg.Enabled
end
local function currencyText(name)
	local gui = playerGui()
	local frame = gui and gui:FindFirstChild("CurrencyGui")
	frame = frame and frame:FindFirstChild("CurrencyFrame")
	local entry = frame and frame:FindFirstChild(name)
	local amount = entry and entry:FindFirstChild("Amount")
	return amount and amount.Text or ""
end
local function currentNotes()
	return tonumber((currencyText("Notes"):gsub("%D", ""))) or 0
end
local function hasKnowledge()
	local k = tonumber(currencyText("ShrinePoints"))
	return k ~= nil and k > 0
end

-- =========================================================================================================
-- Banking.
-- =========================================================================================================
local function setBankAmountAndConfirm(amount)
	local gui = playerGui()
	repeat
		task.wait(0.1)
		gui = playerGui()
	until (gui and gui:FindFirstChild("ChoicePrompt")) or not running
	local cp = gui and gui:FindFirstChild("ChoicePrompt")
	if not cp then
		return false
	end
	local slider = cp:FindFirstChild("ChoiceFrame", true)
	slider = slider and slider:FindFirstChild("DescSheet", true)
	slider = slider and slider:FindFirstChild("SliderSheet", true)
	if not slider then
		return false
	end
	local gen = slider:FindFirstChild("GenericSlider")
	local numberBox = gen and gen:FindFirstChild("Number")
	if numberBox and numberBox:IsA("TextBox") then
		numberBox.Text = tostring(amount)
		task.wait(0.2)
		pcall(function()
			numberBox:CaptureFocus()
			task.wait(0.1)
			numberBox:ReleaseFocus()
		end)
		task.wait(0.2)
	end
	local buttons = slider:FindFirstChild("Buttons")
	local submit = buttons and buttons:FindFirstChild("Submit")
	if submit then
		click(submit)
		return true
	end
	return false
end
local function depositAllNotes()
	local notes = currentNotes()
	if notes == 0 then
		return false
	end
	local bankGui = playerGui() and playerGui():FindFirstChild("BankGui")
	if not bankGui then
		return false
	end
	pcall(function()
		bankGui:WaitForChild("Choice"):FireServer("notes_deposit")
	end)
	task.wait(1)
	return setBankAmountAndConfirm(notes)
end
local function closeBankGui()
	local bankGui = playerGui() and playerGui():FindFirstChild("BankGui")
	if bankGui then
		click(bankGui:FindFirstChild("Close"))
	end
end
local function openBankAndDeposit()
	local banker = workspace.NPCs:FindFirstChild("Banker")
	if not banker then
		return false
	end
	pcall(function()
		replicatedStorage.Requests.InteractPrompt:FireServer(banker.InteractPrompt)
	end)
	task.wait(1)
	repeat
		task.wait(0.1)
	until dialogueOpen() or not running
	dialogueChoice("Can I access my account?")
	task.wait(1)
	repeat
		task.wait(0.5)
	until (playerGui() and playerGui():FindFirstChild("BankGui")) or not running
	task.wait(1)
	local success = depositAllNotes()
	closeBankGui()
	dialogueExit()
	return success
end

-- =========================================================================================================
-- Overworld: share knowledge, deposit notes.
-- =========================================================================================================
local function shareKnowledge()
	if not hasKnowledge() then
		return
	end
	setStage("sharing knowledge")
	local npcCF = CFrame.new(-541.776306, 935.564697, -7180.49707, 0.850063145, 0, 0.526680827, 0, 1, 0, -0.526680827, 0, 0.850063145)
	playerSafeTween(npcCF, 250)

	local soothsayer
	repeat
		soothsayer = workspace.NPCs:FindFirstChild("Soothsayer")
		task.wait()
	until soothsayer or not running
	if not soothsayer then
		return
	end
	repeat
		pcall(function()
			Prompt.interact(soothsayer:FindFirstChildOfClass("ProximityPrompt"))
		end)
		task.wait(0.5)
	until dialogueOpen() or not running
	task.wait(1)
	dialogueChoice("[Share your Knowledge]")
	task.wait(0.5)
	dialogueChoice(tonumber(currencyText("ShrinePoints")))
	task.wait(0.5)
	dialogueExit()
	task.wait(0.5)
end

local function depositNotesAtBank()
	if currentNotes() <= 0 then
		return
	end
	if PersistentData.get("notesdata") and PersistentData.get("notesdata").maxNotes then
		AutoNotes.stop()
		return
	end

	setStage("banking notes")
	local bankerCF = CFrame.new(1563.5769, 164.524414, -4312.33643, -0.104543328, 0, -0.994520426, 0, 1, 0, 0.994520426, 0, -0.104543328)
	playerSafeTween(bankerCF * CFrame.new(0, -5, 0), 170, math.random(10000, 30000))

	local banker
	repeat
		for _, npc in next, workspace.NPCs:GetChildren() do
			if npc.Name:match("Banker") and npc:FindFirstChild("HumanoidRootPart") then
				if not banker then
					banker = npc
				elseif (root().Position - npc.HumanoidRootPart.Position).Magnitude < (root().Position - banker.HumanoidRootPart.Position).Magnitude then
					banker = npc
				end
			end
		end
		task.wait()
	until banker or not running

	openBankAndDeposit()
	task.wait(3.5)
	if currentNotes() > 0 then
		-- Still holding notes -> bank is full.
		PersistentData.stf("notesdata", "maxNotes", true)
		AutoNotes.stop()
	end
end

local function useGuild()
	return Toggles and Toggles.NotesUseGuild and Toggles.NotesUseGuild.Value == true
end

local GUILD_PLACEMENTS = {
	CFrame.new(-996.915771, 998.557617, -7053.39062, 0.20362483, 0, -0.979048967, 0, 1, 0, 0.979048967, 0, 0.20362483),
	CFrame.new(-376.312347, 1109.97266, -6917.1875, 0.830629528, 0, 0.556825459, 0, 1, 0, -0.556825459, 0, 0.830629528),
	CFrame.new(237.318726, 1135.56323, -7003.09619, 0.981070876, 0, 0.193649009, 0, 1, 0, -0.193649009, 0, 0.981070876),
}

---Place the guild base door (Chime of Dwelling) at the first free spot and enter it.
local function placeGuildDoor()
	setStage("placing guild door")
	for _, location in ipairs(GUILD_PLACEMENTS) do
		local near = false
		for _, door in next, workspace:GetChildren() do
			if door:IsA("Part") and door.Name:find("Guild") then
				if (location.Position - door.Position).Magnitude <= 50 or playersNear(location, 400) then
					near = true
					break
				end
			end
		end
		if not near then
			playerSafeTween(location, 250)
			break
		end
	end

	task.wait(1)
	local bp = backpack()
	local chime = bp and bp:FindFirstChild("Chime of Dwelling")
	if chime then
		chime.Parent = character()
		pcall(function()
			character()["Chime of Dwelling"]:Activate()
		end)
	end

	local closest
	repeat
		for _, door in next, workspace:GetChildren() do
			if door:IsA("Part") and door.Name:find("GuildDoor") and door:FindFirstChild("InteractPrompt") then
				if root() and (root().Position - door.Position).Magnitude <= 5 then
					closest = door
					break
				end
			end
		end
		task.wait()
	until closest or not running
	if not closest then
		return
	end

	repeat
		pcall(function()
			Prompt.interact(closest:FindFirstChild("InteractPrompt"))
		end)
		task.wait(0.5)
	until (currentArea() and tostring(currentArea()):find("Base")) or not running
	task.wait(1)
end

---Deposit at the guild bank, then push the overflow into the guild treasury.
local function depositNotesAtGuild()
	placeGuildDoor()
	if not running then
		return
	end

	local guildAttr = localPlayer():GetAttribute("Guild")
	if not guildAttr then
		return
	end
	local guildName = tostring(guildAttr)
		:lower()
		:gsub("%s*%[.-%]%s*", " ")
		:gsub("^%d+", "")
		:gsub("z%w+divider", "")
		:gsub("[^%a%d]", "")

	local banker, treasurer
	for _, npc in next, workspace.NPCs:GetChildren() do
		if banker and treasurer then
			break
		end
		if npc:IsA("Model") and npc:GetAttribute("Guild") and tostring(npc:GetAttribute("Guild")):match(guildName) then
			if npc.Name:match("Banker") then
				banker = npc
			elseif npc.Name:match("Treasurer") then
				treasurer = npc
			end
		end
	end

	local data = PersistentData.get("notesdata")
	if banker and banker:FindFirstChild("HumanoidRootPart") and not (data and data.maxNotes) then
		setStage("guild bank")
		tempTween(banker.HumanoidRootPart.CFrame * CFrame.new(5, 0, 0), 170)
		openBankAndDeposit()
		task.wait(3.5)
		if currentNotes() > 0 then
			PersistentData.stf("notesdata", "maxNotes", true)
		end
	end

	if currentNotes() > 0 and treasurer and treasurer:FindFirstChild("HumanoidRootPart") then
		setStage("guild treasury")
		tempTween(treasurer.HumanoidRootPart.CFrame * CFrame.new(5, 0, 0), 170)
		repeat
			pcall(function()
				Prompt.interact(treasurer:FindFirstChildOfClass("ProximityPrompt"))
			end)
			task.wait(0.5)
		until dialogueOpen() or not running
		dialogueChoice("I'd like to add money to the treasury. [Add to Treasury]")
		task.wait(0.5)
		dialogueChoice(20000)
		task.wait(0.5)
		dialogueExit()
	end
end

local function overworld()
	repeat
		task.wait()
	until character() or not running
	shareKnowledge()
	if not running then
		return
	end
	if currentNotes() > 0 then
		if useGuild() then
			depositNotesAtGuild()
		else
			depositNotesAtBank()
		end
	end
end

-- =========================================================================================================
-- Fragments cash-in (Self [The End]) -- same shape as Echo, no echo counting needed here.
-- =========================================================================================================
local function handleFragments()
	setStage("fragments")
	local self_npc
	local deadline = os.clock() + 40
	repeat
		local npcs = workspace:FindFirstChild("NPCs")
		self_npc = npcs and npcs:FindFirstChild("Self")
		task.wait()
	until self_npc or os.clock() >= deadline or not running
	if not self_npc then
		serverHop()
		return
	end

	local tpLocation = (self_npc:GetPivot() - Vector3.new(0, 15.7, 0))
		* CFrame.Angles(math.rad(180), math.rad(90), math.rad(180))
	if playerCheck(200, tpLocation.Position) then
		serverHop()
		while task.wait() do
		end
		return
	end

	local sendDialogue = replicatedStorage:WaitForChild("Requests"):WaitForChild("SendDialogue")
	local prompt = self_npc:WaitForChild("InteractPrompt", 10)
	local start = tick()
	repeat
		local r = root()
		if r then
			r.CFrame = tpLocation
		end
		if prompt then
			Prompt.interact(prompt)
		end
		pcall(function()
			sendDialogue:FireServer({ choice = "[The End]" })
		end)
		task.wait(0.25)
	until (workspace:FindFirstChild("CharacterCreator") and character() and character().Parent == workspace.CharacterCreator)
		or not (currentArea() and tostring(currentArea()):match("Fragments of Self"))
		or not running
		or tick() - start > 20
end

-- =========================================================================================================
-- State machine.
-- =========================================================================================================
local function isCharacterCreation()
	local cc = workspace:FindFirstChild("CharacterCreator")
	local c = character()
	return cc ~= nil and c ~= nil and c.Parent == cc
end

local stateMachine = StateMachine.create({
	initial = "idle",
	events = {
		{ name = "start", from = "idle", to = "_check_area" },
		{ name = "overworld", from = "_check_area", to = "_overworld" },
		{ name = "fragments", from = "_check_area", to = "_handle_fragments" },
		{ name = "die", from = "_check_area", to = "_die" },
		{ name = "cc", from = "_check_area", to = "_create_character" },
		{ name = "continuation", from = "_create_character", to = "_check_area" },
		{ name = "continuation", from = "_handle_fragments", to = "_check_area" },
		{ name = "continuation", from = "_overworld", to = "_check_area" },
	},
	callbacks = {
		onenter_check_area = function(self)
			if not running then
				return
			end
			setStage("check area")

			local area = currentArea()
			if area and tostring(area):match("Fragments of Self") then
				return self:fragments()
			end

			if isCharacterCreation() then
				return self:cc()
			end

			if area and tostring(area):match("The Depths") then
				return self:die()
			end

			if game.PlaceId == MAIN_GAME_PLACE_ID then
				-- If we're in a guild base, respawn to the Inn first.
				if area and tostring(area):find("Base") then
					General.respawn()
					repeat
						task.wait()
					until (playerGui() and playerGui():FindFirstChild("SpawnPrompt")) or not running
					pcall(function()
						playerGui().SpawnPrompt.Choice:FireServer("Inn")
					end)
					repeat
						task.wait()
					until character() or not running
				end
				return self:overworld()
			end
		end,
		onenter_create_character = function(self)
			if not running then
				return
			end
			setStage("create character")
			struct:create_character()
			self:continuation()
		end,
		onenter_handle_fragments = function(self)
			if not running then
				return
			end
			handleFragments()
			self:continuation()
		end,
		onenter_overworld = function(self)
			if not running then
				return
			end
			setStage("overworld")
			overworld()
			if not running then
				return
			end
			-- Wipe and reroll.
			local slot = currentSlot() or (PersistentData.get("notesdata") and PersistentData.get("notesdata").slot)
			pcall(function()
				Wipe.invoke(slot)
			end)
		end,
		onenter_die = function(self)
			if not running then
				return
			end
			local slot = currentSlot() or (PersistentData.get("notesdata") and PersistentData.get("notesdata").slot)
			pcall(function()
				Wipe.invoke(slot)
			end)
		end,
	},
})

-- =========================================================================================================
-- Struct.
-- =========================================================================================================
local function buildStruct()
	return AutomationStruct.construct({
		id = "auto_notes",
		state_machine = stateMachine,
		is_running = isRunning,
		features = {
			"no_fall",
			"noclip",
			"mod_detector",
			"fly",
			"auto_equip_weapon",
			"auto_log",
		},
		character_creator_handler_used = true,
		character_creator_handler_opts = {
			origin = "Etris",
		},
	})
end

-- =========================================================================================================
-- Public interface.
-- =========================================================================================================

---Menu Start: wipe the current character first (like Echo Farm), then Aero's resume (notesdata) drops us
---into a fresh farm cycle.
function AutoNotes.invoke()
	local lp = localPlayer()
	if not lp then
		return
	end
	if running then
		return
	end
	local slot = currentSlot()
	if not slot then
		return Logger.notify("Auto Notes: no data slot found.")
	end

	PersistentData.set("notesdata", {
		slot = slot,
		startedAt = os.time(),
	})

	-- Wipe the current character on start; the wipe teleports us out and the resume brings us back in.
	pcall(function()
		Wipe.invoke(slot)
	end)
end

function AutoNotes.start()
	local lp = localPlayer()
	if not lp then
		return
	end
	if running then
		return
	end
	local slot = currentSlot()
	if not slot then
		return Logger.notify("Auto Notes: no data slot found.")
	end

	local data = PersistentData.get("notesdata") or {}
	data.slot = slot
	data.startedAt = data.startedAt or os.time()
	PersistentData.set("notesdata", data)

	running = true
	buildOverlay()
	AntiAFK.start("AutoNotes")

	maid:mark(task.spawn(runElapsed))

	stateMachine.current = "idle"
	stateMachine.asyncState = StateMachine.NONE
	stateMachine.currentTransitioningEvent = nil

	struct = buildStruct()
	struct:run()
end

function AutoNotes.stop()
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
		AntiAFK.stop("AutoNotes")
	end)
	maid:clean()
	destroyOverlay()
	PersistentData.set("notesdata", nil)
end

return AutoNotes
