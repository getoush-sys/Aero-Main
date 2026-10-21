-- General: Aero port of project-rain-oss's `general_utilitys` helpers used by the automation tasks.
-- The notable one is playing_ap_anims -- "is this entity currently in an attack-pattern animation" -- which
-- PR backs with its own 4.5k-line timing DB. Here it's backed by Aero's OWN timing database
-- (SaveManager.as:index), so there's no duplicated data and it tracks Aero's timings.
local General = {}

---@module Game.Timings.SaveManager
local SaveManager = require("Game/Timings/SaveManager")

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local FAST_SWING_CLASSES = { "OffhandAttack", "HeavyAttack", "MediumAttack", "LightAttack", "UsingSpell" }

---Tap a key once via VirtualInputManager (pure client input; no remote).
---@param keyCode Enum.KeyCode
function General.pressKey(keyCode)
	pcall(function()
		local vim = Instance.new("VirtualInputManager")
		vim:SendKeyEvent(true, keyCode, false, game)
		vim:SendKeyEvent(false, keyCode, false, game)
	end)
end

---Spam the A key to click through the game's loading screen (LoadingGui) until it disappears or the
---character spawns (10s cap). Input-only: the old Requests.StartMenu.Start remote is an anticheat
---honeypot (instant ban), so we drive the menu the way a player would instead of firing anything.
function General.clickThroughLoadingGui()
	-- Poll (up to 10s) for the loading screen OR the character being in -- not WaitForChild, so a character
	-- that loads in mid-wait bails immediately instead of stalling the full timeout.
	local loadingGui
	local findDeadline = os.clock() + 10
	repeat
		if players.LocalPlayer and players.LocalPlayer.Character then
			return
		end
		local pg = players.LocalPlayer and players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		loadingGui = pg and pg:FindFirstChild("LoadingGui")
		if loadingGui then
			break
		end
		task.wait()
	until os.clock() >= findDeadline
	if not loadingGui then
		return
	end
	local deadline = os.clock() + 10
	repeat
		General.pressKey(Enum.KeyCode.A)
		task.wait(0.2)
	until not loadingGui.Parent or (players.LocalPlayer and players.LocalPlayer.Character) or os.clock() >= deadline
end

---Blow through the loading screen (was: fire Requests.StartMenu.Start). Now spams A through the
---LoadingGui instead -- the StartMenu remote is an AC honeypot. Kept under the same name so callers work.
function General.fireStartMenu()
	General.clickThroughLoadingGui()
end

---Fast swing: remove the attack-cooldown effects (LightAttack/HeavyAttack/etc.) the instant they're added,
---so swings aren't rate-limited client-side (PR's fast_swing). Returns the connection to disconnect, or nil.
function General.connectFastSwing()
	local er
	pcall(function()
		er = require(replicatedStorage:WaitForChild("EffectReplicator", 5))
	end)
	if not er or not er.EffectAdded then
		return nil
	end
	return er.EffectAdded:Connect(function(effect)
		if effect and effect.Class and table.find(FAST_SWING_CLASSES, effect.Class) then
			task.defer(function()
				pcall(function()
					effect:Remove(true)
				end)
			end)
		end
	end)
end

---Blow through the game's loading screen and wait for our character to spawn into workspace.Live.
---While the LoadingGui is up, spams A to click through it (input-only -- the old StartMenu.Start
---remote is an anticheat honeypot). Skipped for character creation (that's its own flow).
---@param isRunning function? returns false to bail early
function General.requestStart(isRunning)
	-- Already in-game (char in Live) or in the character creator? nothing to click through.
	local function inGame()
		local char = players.LocalPlayer and players.LocalPlayer.Character
		local creator = workspace:FindFirstChild("CharacterCreator")
		return (creator and char and char.Parent == creator)
			or (char and char.Parent and char.Parent.Name == "Live") and true
			or false
	end

	-- Wait (up to 10s) for EITHER the loading screen to appear OR the character to already be in. This is a
	-- poll, not WaitForChild, on purpose: WaitForChild blocks, so if the character loads in mid-wait it would
	-- stall the full timeout before returning (that was the "stalls a few seconds after the character loads"
	-- bug). Polling lets inGame() bail us out the instant the character is in. Called very early, so it also
	-- resolves PlayerGui here.
	local loadingGui
	local findDeadline = os.clock() + 10
	repeat
		if isRunning and not isRunning() then
			return
		end
		if inGame() then
			return
		end
		local pg = players.LocalPlayer and players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		loadingGui = pg and pg:FindFirstChild("LoadingGui")
		if loadingGui then
			break
		end
		task.wait()
	until os.clock() >= findDeadline

	local deadline = os.clock() + 25
	repeat
		if isRunning and not isRunning() then
			return
		end
		if inGame() then
			return
		end
		-- Loading screen still up? spam A to click through it.
		if loadingGui and loadingGui.Parent then
			General.pressKey(Enum.KeyCode.A)
		end
		task.wait(0.2)
	until os.clock() >= deadline
end

---True if `entity` is currently playing any animation Aero recognises as an attack timing. `ids` is an
---optional list of AnimationIds to ignore (PR passes specific ids it wants to treat as "safe").
---@param entity Instance
---@param ids table? list of AnimationId strings to skip
---@return boolean
function General.playing_ap_anims(entity, ids)
	if not entity then
		return false
	end
	local humanoid = entity:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	local as = SaveManager and SaveManager.as
	if not as then
		return false
	end

	local ok, playing = pcall(function()
		return humanoid:GetPlayingAnimationTracks()
	end)
	if not ok or not playing then
		return false
	end

	for _, track in next, playing do
		local full = tostring(track.Animation.AnimationId)
		if not (ids and table.find(ids, full)) then
			local digits = full:match("%d+")
			local matched = false
			pcall(function()
				matched = as:index(full) ~= nil or (digits ~= nil and as:index(digits) ~= nil)
			end)
			if matched then
				return true
			end
		end
	end
	return false
end

---Respawn / leave via the fastest route: replicate the Kill signal, then void ourselves if we somehow
---survived. Direct port of PR's `buttons/respawn`.
function General.respawn()
	local lp = players.LocalPlayer
	if not lp then
		return
	end
	if replicatesignal then
		pcall(function()
			replicatesignal(lp.Kill)
		end)
		task.delay(1, function()
			local char = lp.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health <= 1 then
				return
			end
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = root.CFrame * CFrame.new(0, 9e9, 0)
			end
		end)
	else
		local char = lp.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = root.CFrame * CFrame.new(0, 9e9, 0)
		end
	end
end

return General
