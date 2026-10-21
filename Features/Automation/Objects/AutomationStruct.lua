-- AutomationStruct: a Aero port of project-rain-oss's `src/automation/struct.lua`. Bundles a state machine
-- with a set of features (see AutomationFeatures) and a character-creation routine. `construct` builds one;
-- `run` enables the features and starts the state machine; `stop` tears the features back down.
--
-- PR's global `aztup.automation:has_any()` (is any automation still running) is provided per-struct via the
-- `is_running` option -- a function the caller passes so features + state callbacks can bail when stopped.
local AutomationStruct = {}
AutomationStruct.__index = AutomationStruct

---@module Features.Automation.Objects.AutomationFeatures
local AutomationFeatures = require("Features/Automation/Objects/AutomationFeatures")

---@module Features.Automation.Objects.General
local General = require("Features/Automation/Objects/General")

---@module Utility.SafeClick
local safeClick = require("Utility/SafeClick")

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local function localPlayer()
	return players.LocalPlayer
end

local function character()
	local lp = localPlayer()
	return lp and lp.Character
end

---@param opts table
---@return table
function AutomationStruct.construct(opts)
	local obj = setmetatable({}, AutomationStruct)

	obj.id = opts.id
	obj.state_machine = opts.state_machine
	obj.features = opts.features or {}
	obj.on_run = opts.on_run
	obj.is_running = opts.is_running or function()
		return true
	end

	obj.character_creator_handler_used = opts.character_creator_handler_used or false
	obj.character_creator_handler_opts = opts.character_creator_handler_opts or {}

	obj.active_features = {}
	obj.threads = {}

	return obj
end

---True while the owning automation is still running (PR's aztup.automation:has_any()).
---@return boolean
function AutomationStruct:has_any()
	return self.is_running() == true
end

---Enable every feature, then start the state machine.
function AutomationStruct:run()
	self.active_features = {}

	-- Blow through the start/loading screen so the character actually spawns before we route (every farm
	-- needs this on a fresh join; skipped automatically during character creation).
	General.requestStart(function()
		return self:has_any()
	end)

	for _, name in ipairs(self.features) do
		local feat = AutomationFeatures.create(name, self)
		if feat then
			task.spawn(function()
				local ok, err = pcall(function()
					feat:enable()
				end)
				if not ok then
					warn(string.format("[AutomationStruct] feature %s enable failed: %s", tostring(name), tostring(err)))
				end
			end)
			self.active_features[name] = feat
		end
	end

	if self.on_run then
		task.spawn(self.on_run)
	end

	table.insert(
		self.threads,
		task.spawn(function()
			self.state_machine:start()
		end)
	)
end

---Disable every active feature and cancel any in-flight character-creation helper threads.
function AutomationStruct:stop()
	for _, feat in pairs(self.active_features) do
		pcall(function()
			feat:disable()
		end)
	end
	self.active_features = {}

	if self._creation_threads then
		for _, thread in ipairs(self._creation_threads) do
			pcall(function()
				task.cancel(thread)
			end)
		end
		self._creation_threads = {}
	end
end

---Character creation. Direct port of PR's automation_struct.create_character (Aero-native requires).
function AutomationStruct:create_character()
	local options = self.character_creator_handler_opts
	local lp = localPlayer()

	local requests = replicatedStorage:WaitForChild("Requests")
	local characterCreator = requests:WaitForChild("CharacterCreator")
	local pickSpawn = characterCreator:WaitForChild("PickSpawn")
	local changeWeapon = characterCreator:WaitForChild("ChangeWeapon")
	local finishCreation = characterCreator:WaitForChild("FinishCreation")
	local toggleMetaModifier = requests:WaitForChild("ToggleMetaModifier", 20)
	local playerGui = lp:WaitForChild("PlayerGui")
	local characterGui = playerGui:WaitForChild("CharacterCreator")
	local suc

	-- Re-resolve the PickSpawn remote fresh each pick -- the game can replace the CharacterCreator remotes
	-- between invocations, and a cached reference would go stale (InvokeServer on a destroyed remote no-ops).
	local function getPickSpawn()
		local cc = requests:FindFirstChild("CharacterCreator")
		return (cc and cc:FindFirstChild("PickSpawn")) or pickSpawn
	end

	-- Origin selection. The PickSpawn return value is NOT a reliable confirmation -- it echoes the requested
	-- spawn even when the origin never actually applies (the "script thinks it picked but it didn't" bug). The
	-- authoritative current origin is what the creator client itself reads: `DataReplication.GetData().Origin`
	-- (line 1851 of the decompiled creator -- defaults to "Castaway"). So we fire PickSpawn, then verify the
	-- REAL server-synced origin equals our target category (Titus = "Authority Ensign", L2 = "Deepbound"),
	-- retrying until it does or `timeout` seconds pass -> kick. cfg = { category, spawn, timeout, kick_message };
	-- `category` is the origin whose presence in DataReplication.Origin we verify.
	local function clickOriginButton(cfg)
		local deadline = os.clock() + (cfg.timeout or 10)

		local function currentOrigin()
			local origin
			pcall(function()
				origin = require(replicatedStorage:WaitForChild("Info"):WaitForChild("DataReplication")).GetData().Origin
			end)
			return origin
		end

		repeat
			-- Already the right origin (server-synced)? done.
			if cfg.category and currentOrigin() == cfg.category then
				return true
			end
			-- Fire the spawn pick (what the real button does), then re-check the real origin.
			pcall(function()
				getPickSpawn():InvokeServer(cfg.spawn)
			end)
			task.wait(0.25)
			if cfg.category and currentOrigin() == cfg.category then
				return true
			end
		until os.clock() >= deadline

		-- Couldn't get the origin to apply in time. Prefer the automation's on_fail handler (e.g. server-hop +
		-- retry on a fresh server) over kicking, so the farm just tries again instead of dropping the player.
		if cfg.on_fail then
			pcall(cfg.on_fail)
		else
			pcall(function()
				lp:Kick(cfg.kick_message or "Need authority origin")
			end)
		end
		return false
	end

	-- Select the Standard gamemode by CLICKING its button -- NOT just firing ChangeGamemode. The decompiled
	-- creator shows the button handler does MORE than the remote: after ChangeGamemode:InvokeServer it sets the
	-- client's `u40` flag and calls refreshGamemode(), which is what hides the gamemode screen and REVEALS the
	-- origin / creation UI. Firing the remote alone leaves the client stuck on the gamemode screen, so the
	-- origin never applies (that was the "origin never chosen" bug). We confirm by the GameMode frame going
	-- invisible -- exactly what refreshGamemode does once a mode is chosen.
	do
		local deadline = os.clock() + 10
		local function standardElement()
			local gm = characterGui:FindFirstChild("GameMode")
			local opts = gm and gm:FindFirstChild("Options")
			local std = opts and opts:FindFirstChild("Standard")
			return std and std:FindFirstChild("Element")
		end
		local function gamemodeChosen()
			local gm = characterGui:FindFirstChild("GameMode")
			return gm ~= nil and gm.Visible == false
		end
		repeat
			if gamemodeChosen() then
				break
			end
			local el = standardElement()
			if el then
				-- safeClick instead of firesignal (native-crash risk pcall can't catch -- see Utility/SafeClick).
				safeClick(el)
			end
			task.wait(0.25)
			if gamemodeChosen() then
				break
			end
		until os.clock() >= deadline
	end

	-- Pick the origin UP FRONT, before weapon/modifiers/boons/flaws. Deepwoken keys the rest of creation off
	-- the chosen origin, so those picks (and FinishCreation) must happen with an origin already set -- otherwise
	-- the character commits before the origin applies. It's re-asserted again as the last write below to beat
	-- the Standard gamemode's async default-origin overwrite.
	if options.origin_button then
		-- Button path: wait for + click the real UI origin button (kicks the player if it never appears).
		if not clickOriginButton(options.origin_button) then
			return
		end
	elseif options.origin then
		for _ = 1, 10 do
			suc = getPickSpawn():InvokeServer(options.origin)
			task.wait(0.1)
		end
	end

	if options.weapon then
		for _ = 1, 10 do
			suc = changeWeapon:InvokeServer(options.weapon)
			if suc then
				break
			end
			task.wait(0.1)
		end
	end

	if options.modifiers and toggleMetaModifier then
		for _, modifier in ipairs(options.modifiers) do
			toggleMetaModifier:FireServer(modifier)
			if #options.modifiers == 1 then
				break
			end
			task.wait(1)
		end
	end

	local pickBoon = characterCreator:WaitForChild("PickBoon")
	local pickFlaw = characterCreator:WaitForChild("PickFlaw")
	local dataReplication =
		require(replicatedStorage:WaitForChild("Info"):WaitForChild("DataReplication")).GetData()

	for _, flaw in next, dataReplication.Flaws do
		pickFlaw:InvokeServer(tostring(flaw))
	end

	for _, boon in next, dataReplication.Boons do
		pickBoon:InvokeServer(tostring(boon))
	end

	pickBoon:InvokeServer("Autodidact")
	task.wait(1.5)
	pickFlaw:InvokeServer("Obvious")

	if not self:has_any() then
		return
	end

	-- Settle FIRST, BEFORE the final origin lock. The Standard gamemode applies its own default origin
	-- (Authority) asynchronously, and it can land a beat after our picks. Previously this wait happened AFTER
	-- the final origin write, which gave the async default a 2s window to deselect our origin again right
	-- before FinishCreation -- committing the wrong origin (button showing the wrong colour). Waiting here,
	-- before the lock, lets that default land first so our lock below is the genuine last word.
	task.wait(2)

	-- FINAL origin lock -- the very last thing before committing, with NO wait after it, so nothing can
	-- overwrite the origin before FinishCreation. clickOriginButton invokes PickSpawn and only returns once the
	-- server echoes back our spawn (authoritative), so this is the definitive last origin write.
	if options.origin_button then
		if not clickOriginButton(options.origin_button) then
			return
		end
	elseif options.origin then
		for _ = 1, 10 do
			getPickSpawn():InvokeServer(options.origin)
			task.wait(0.1)
		end
	end

	-- Finish creation ONCE, then confirm the "create this character?" prompt. Both helper threads are
	-- tracked on the struct (cancelled by :stop) and time-bounded, so a failed/stopped attempt can't leave a
	-- zombie confirm thread that later fires Choice:FireServer(true) on the NEXT run's prompt -- that is what
	-- intermittently rolled the wrong character. (PR's framework gets a fresh session each cycle, so it never
	-- hits this; Aero persists in-session, so we have to guard it.)
	self._creation_threads = self._creation_threads or {}
	table.insert(
		self._creation_threads,
		task.spawn(function()
			pcall(function()
				finishCreation:InvokeServer()
			end)
		end)
	)
	table.insert(
		self._creation_threads,
		task.spawn(function()
			local choicePrompt = playerGui:WaitForChild("ChoicePrompt", 30)
			local choice = choicePrompt and choicePrompt:WaitForChild("Choice", 5)
			if choice and self:has_any() then
				pcall(function()
					choice:FireServer(true)
				end)
			end
		end)
	)

	-- Wait for the character to spawn into Live (30s cap so a failed creation can't hang forever -- the caller
	-- re-checks and retries instead).
	local waitStart = os.clock()
	repeat
		task.wait()
		local c = character()
		if c and c.Parent and c.Parent.Name == "Live" then
			break
		end
	until not self:has_any() or os.clock() - waitStart > 30

	local c = character()
	if c and c.Parent and c.Parent.Name == "Live" then
		c:WaitForChild("HumanoidRootPart")
		c:WaitForChild("Humanoid")
	end
end

return AutomationStruct
