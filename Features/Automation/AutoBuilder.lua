-- Auto Builder: fetch + parse a deepwoken.co build link into a normalized table the automation can
-- act on. deepwoken.co is a Nuxt app that proxies its API through its own origin
-- (`/api/proxy/builds/<id>`), so no auth token is needed -- just browser-ish headers or it 403s.

---@module Utility.JSON
local JSON = require("Utility/JSON")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Features.Visuals.Objects.BuilderData
local BuilderData = require("Features/Visuals/Objects/BuilderData")

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

local players = game:GetService("Players")
local runService = game:GetService("RunService")

local AutoBuilder = {}

local PROXY_BASE = "https://deepwoken.co/api/proxy/builds/"
local GAMEDATA_URL = "https://deepwoken.co/api/proxy/get?type=all"

-- The proxy rejects requests without a browser-looking Origin/Referer/User-Agent.
local USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
	.. "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

-- The most recently loaded + parsed build, and which stat/talent set the script targets.
---@type table?
AutoBuilder.current = nil
---@type "pre"|"post"
AutoBuilder.target = "pre"

-- When true, the picking loop clicks talent/mantra cards as they appear.
AutoBuilder.picking = false

-- The id of the currently loaded build (used to persist + resume across server hops).
AutoBuilder.loadedId = nil

---The player's current data slot, or nil.
---@return any
function AutoBuilder.currentSlot()
	local localPlayer = players.LocalPlayer
	return localPlayer and localPlayer:GetAttribute("DataSlot")
end

-- Persist the active state (link + target + slot) so a server hop resumes it on the same character.
local function persist()
	PersistentData.set("abdata", {
		active = AutoBuilder.picking and true or false,
		id = AutoBuilder.loadedId,
		target = AutoBuilder.target,
		slot = AutoBuilder.currentSlot(),
	})
end

-- Fire the UI state-changed hook (refreshes the Start/Stop button), if one is registered.
local function notifyState()
	if AutoBuilder.onStateChanged then
		pcall(AutoBuilder.onStateChanged)
	end
end

---Resolve the executor's HTTP request function across the common names.
---@return function?
local function getRequester()
	if type(request) == "function" then
		return request
	elseif type(http_request) == "function" then
		return http_request
	elseif syn and type(syn.request) == "function" then
		return syn.request
	elseif http and type(http.request) == "function" then
		return http.request
	end

	return nil
end

---Pull the build id out of anything the user might paste: a full builder URL, a share URL, or the
---raw id on its own.
---@param input string
---@return string?
function AutoBuilder.extractId(input)
	if type(input) ~= "string" then
		return nil
	end

	input = input:gsub("%s+", "")

	if input == "" then
		return nil
	end

	local id = input:match("[?&]id=([%w%-_]+)")
		or input:match("/builds/([%w%-_]+)")
		or input:match("/builder/([%w%-_]+)")

	-- A bare id (no URL wrapping) -- accept it as-is.
	if not id and input:match("^[%w%-_]+$") then
		id = input
	end

	return id
end

---Fetch a URL and return the decoded JSON table (or nil, err). Sends browser-ish headers because the
---deepwoken.co proxy 403s without them.
---@param url string
---@param referer string
---@return table?, string?
local function httpGetJson(url, referer)
	local requester = getRequester()
	if not requester then
		return nil, "This executor has no HTTP request function."
	end

	local ok, response = pcall(requester, {
		Url = url,
		Method = "GET",
		Headers = {
			["Accept"] = "application/json",
			["Origin"] = "https://deepwoken.co",
			["Referer"] = referer,
			["User-Agent"] = USER_AGENT,
		},
	})

	if not ok or not response then
		return nil, "Request failed (network/executor error)."
	end

	local status = response.StatusCode or response.Status or 0
	if status == 404 then
		return nil, "Not found (404)."
	elseif status ~= 200 then
		return nil, string.format("Server returned %s.", tostring(status))
	end

	local body = response.Body
	if not body or body == "" then
		return nil, "Empty response body."
	end

	local decodeOk, decoded = pcall(JSON.decode, body)
	if not decodeOk or type(decoded) ~= "table" then
		return nil, "Couldn't parse JSON."
	end

	return decoded, nil
end

-- The raw master game-data dump (talents/mantras/etc.), fetched once and cached.
AutoBuilder.gameDump = nil

---Fetch (once, cached) deepwoken's master data dump (the `get?type=all` payload).
---@return table?, string?
function AutoBuilder.fetchGameData()
	if AutoBuilder.gameDump then
		return AutoBuilder.gameDump, nil
	end

	local dump, err = httpGetJson(GAMEDATA_URL, "https://deepwoken.co/builder")
	if not dump then
		return nil, err
	end

	AutoBuilder.gameDump = dump

	return dump, nil
end

---Fetch the raw build JSON by id. Returns (buildJson, nil) or (nil, errorMessage).
---@param id string
---@return table?, string?
function AutoBuilder.fetch(id)
	if not id or id == "" then
		return nil, "No build id."
	end

	local build, err = httpGetJson(PROXY_BASE .. id, "https://deepwoken.co/builder?id=" .. id)
	if not build then
		if err == "Not found (404)." then
			return nil, "Invalid link"
		end
		return nil, err
	end

	return build, nil
end

---Load a build from anything the user pasted (URL or id), store it as the current build, and return
---(build, nil) or (nil, errorMessage). Notifies the user either way.
---@param input string
---@return table?, string?
function AutoBuilder.load(input)
	-- Nothing pasted (e.g. an empty box restored by a config load) -> do nothing, silently. We only
	-- complain when there's actual text that failed to parse.
	if type(input) ~= "string" or input:gsub("%s+", "") == "" then
		return nil, "Empty."
	end

	local id = AutoBuilder.extractId(input)
	if not id then
		Logger.notify("Auto Builder: couldn't find a build id in that link.")
		return nil, "No id."
	end

	local buildJson, err = AutoBuilder.fetch(id)
	if not buildJson then
		Logger.notify("Auto Builder: " .. tostring(err))
		return nil, err
	end

	local dump, dumpErr = AutoBuilder.fetchGameData()
	if not dump then
		Logger.notify("Auto Builder: " .. tostring(dumpErr))
		return nil, dumpErr
	end

	-- Reuse Build Assistance's data objects: BuilderData wraps DeepwokenData (ddata) plus the pre/post
	-- AttributeData spreads, cleaned talent/mantra lists, and traits.
	local bdata = BuilderData.new(buildJson, dump)

	local stats = buildJson.stats or {}
	local meta = stats.meta or {}

	local build = {
		id = id,
		name = stats.buildName or "Unnamed Build",
		meta = {
			Origin = meta.Origin or "None",
			Oath = meta.Oath or "None",
		},
		pre = bdata.pre, -- AttributeData: .base / .weapon / .attunement
		post = bdata.post,
		talents = bdata.talents,
		mantras = bdata.mantras,
		traits = bdata.traits,
		bdata = bdata,
	}

	AutoBuilder.current = build
	AutoBuilder.loadedId = id

	local classified = AutoBuilder.classify(build)
	AutoBuilder.classified = classified

	-- If we're mid-run (e.g. a reload while active), keep the persisted state current.
	if AutoBuilder.picking then
		persist()
	end

	Logger.notify(
		string.format(
			"Auto Builder: loaded \"%s\" (%d talents, %d mantras).",
			build.name,
			#build.talents,
			#build.mantras
		)
	)

	return build, nil
end

---@param target "pre"|"post"
function AutoBuilder.setTarget(target)
	if target ~= "pre" and target ~= "post" then
		return
	end

	AutoBuilder.target = target

	if AutoBuilder.picking then
		persist()
	end

	notifyState()
end

---Start the automation (picking + investment) and persist it for server-hop resume.
function AutoBuilder.startPicking()
	AutoBuilder.picking = true
	persist()
	notifyState()
end

---Stop the automation and clear the persisted resume state.
function AutoBuilder.stopPicking()
	AutoBuilder.picking = false
	PersistentData.set("abdata", nil)
	notifyState()
end

---Resume a persisted Auto Builder session after a server hop. Only resumes if it was active and on
---the same data slot. Returns the reloaded build, or nil.
---@return table?
function AutoBuilder.resume()
	local data = PersistentData.get("abdata")
	if type(data) ~= "table" or not data.active or not data.id then
		return nil
	end

	-- Only resume on the same slot it was started on (a different character shouldn't inherit it).
	local slot = AutoBuilder.currentSlot()
	if data.slot ~= nil and slot ~= nil and slot ~= data.slot then
		return nil
	end

	AutoBuilder.setTarget(data.target == "post" and "post" or "pre")

	local build = AutoBuilder.load(data.id)
	if not build then
		return nil
	end

	AutoBuilder.startPicking()

	return build
end

-- ============================================================================================
-- Preshrine / postshrine split.
--
-- Uses Build Assistance's obtainability check (bdata.ddata:possible(name, spread)), which resolves
-- each talent/mantra's requirements against an AttributeData spread. A talent belongs to the
-- preshrine column when it's obtainable at the pre-shrine spread but NOT at the post-shrine spread
-- (you'd lose access after the Shrine of Order, so grab it first). Everything else is postshrine.
-- ============================================================================================

---Split the loaded build's talents + mantras into preshrine/postshrine columns.
---@param build table
---@return table? { pre = { talents = {}, mantras = {} }, post = { talents = {}, mantras = {} } }
function AutoBuilder.classify(build)
	local bdata = build and build.bdata
	if not bdata then
		return nil
	end

	local result = {
		pre = { talents = {}, mantras = {} },
		post = { talents = {}, mantras = {} },
	}

	local function place(bucket, name)
		local canPre = bdata.ddata:possible(name, bdata.pre)
		local canPost = bdata.ddata:possible(name, bdata.post)

		if canPre and not canPost then
			table.insert(result.pre[bucket], name)
		else
			table.insert(result.post[bucket], name)
		end
	end

	for _, talent in ipairs(bdata.talents) do
		place("talents", talent)
	end

	for _, mantra in ipairs(bdata.mantras) do
		place("mantras", mantra)
	end

	return result
end

-- ============================================================================================
-- Talent / mantra card picking.
--
-- The game shows talent/mantra cards as TextButtons under PlayerGui.TalentGui.ChoiceFrame, each named
-- after the talent/mantra it grants. Rather than clicking, we fire the exact remote the game's own
-- TalentClient fires on a card click:
--     ReplicatedStorage.Requests.TalentChoice:InvokeServer(cardName, isSpecial)
-- where isSpecial is true only for a "special" hand (resonance/foretold gift). We still read the card
-- buttons to know what's on offer and apply the build's priority: preshrine, then postshrine, then a
-- random real card.
-- ============================================================================================

local replicatedStorage = game:GetService("ReplicatedStorage")

local renderStepped = Signal.new(runService.RenderStepped)
local pickMaid = Maid.new()
local pickCooldownUntil = 0
local pickBusy = false
local investCooldownUntil = 0
local investBusy = false

---@return Instance? PlayerGui.TalentGui
local function getTalentGui()
	local playerGui = players.LocalPlayer and players.LocalPlayer:FindFirstChild("PlayerGui")
	return playerGui and playerGui:FindFirstChild("TalentGui")
end

---@return Instance? ReplicatedStorage.Requests.TalentChoice
local function getTalentChoiceRemote()
	local requests = replicatedStorage:FindFirstChild("Requests")
	return requests and requests:FindFirstChild("TalentChoice")
end

-- ============================================================================================
-- Point investment.
--
-- Each +1 to an attribute fires ReplicatedStorage.Requests.IncreaseAttribute:InvokeServer(<arg>),
-- where <arg> is the character attribute name minus the "Stat_" prefix (e.g. "Agility",
-- "WeaponMedium", "ElementWind"). We read the current value from the character's Stat_* attribute and
-- fire one increment at a time toward the target spread, so the server validates each point and we
-- never overshoot.
-- ============================================================================================

-- Ordered invest targets: { stat = <character attribute>, arg = <remote argument>, group, key }.
local INVEST_TARGETS = {
	-- Weapons + attunements first (they gate the most talents), then base attributes.
	{ group = "weapon", key = "Light Wep.", stat = "Stat_WeaponLight", arg = "WeaponLight" },
	{ group = "weapon", key = "Medium Wep.", stat = "Stat_WeaponMedium", arg = "WeaponMedium" },
	{ group = "weapon", key = "Heavy Wep.", stat = "Stat_WeaponHeavy", arg = "WeaponHeavy" },

	{ group = "attunement", key = "Flamecharm", stat = "Stat_ElementFire", arg = "ElementFire" },
	{ group = "attunement", key = "Frostdraw", stat = "Stat_ElementIce", arg = "ElementIce" },
	{ group = "attunement", key = "Thundercall", stat = "Stat_ElementLightning", arg = "ElementLightning" },
	{ group = "attunement", key = "Galebreathe", stat = "Stat_ElementWind", arg = "ElementWind" },
	{ group = "attunement", key = "Shadowcast", stat = "Stat_ElementShadow", arg = "ElementShadow" },
	{ group = "attunement", key = "Ironsing", stat = "Stat_ElementMetal", arg = "ElementMetal" },
	{ group = "attunement", key = "Bloodrend", stat = "Stat_ElementBlood", arg = "ElementBlood" },

	{ group = "base", key = "Strength", stat = "Stat_Strength", arg = "Strength" },
	{ group = "base", key = "Fortitude", stat = "Stat_Fortitude", arg = "Fortitude" },
	{ group = "base", key = "Agility", stat = "Stat_Agility", arg = "Agility" },
	{ group = "base", key = "Intelligence", stat = "Stat_Intelligence", arg = "Intelligence" },
	{ group = "base", key = "Willpower", stat = "Stat_Willpower", arg = "Willpower" },
	{ group = "base", key = "Charisma", stat = "Stat_Charisma", arg = "Charisma" },
}

---@return Instance? ReplicatedStorage.Requests.IncreaseAttribute
local function getIncreaseAttributeRemote()
	local requests = replicatedStorage:FindFirstChild("Requests")
	return requests and requests:FindFirstChild("IncreaseAttribute")
end

---The spread the script is currently working toward (pre or post), or nil if no build is loaded.
---@return table?
local function targetSpread()
	local build = AutoBuilder.current
	if not build then
		return nil
	end
	return AutoBuilder.target == "post" and build.post or build.pre
end

-- Attributes we recently couldn't raise (not enough XP): [stat] = os.clock() deadline to retry.
local investBlockedUntil = {}

---Invest a single point toward the target spread. Walks the attributes in order; for the first one
---below its goal that isn't temporarily blocked, it fires one increment and waits for the stat to
---actually rise (confirming the point landed before we ever fire again -- no overshoot). If the stat
---doesn't rise in time (can't afford it), that attribute is blocked for a while and we move on to the
---next one. Returns true if a point was successfully invested.
---@return boolean
function AutoBuilder.investOnce()
	local spread = targetSpread()
	if not spread then
		return false
	end

	local character = players.LocalPlayer and players.LocalPlayer.Character
	if not character then
		return false
	end

	local remote = getIncreaseAttributeRemote()
	if not remote then
		return false
	end

	for _, entry in ipairs(INVEST_TARGETS) do
		local goal = tonumber(spread[entry.group] and spread[entry.group][entry.key]) or 0
		if goal <= 0 then
			continue
		end

		local before = tonumber(character:GetAttribute(entry.stat)) or 0
		if before >= goal then
			continue
		end

		-- Skip attributes we recently failed to raise (retry only after the block expires).
		local blockedUntil = investBlockedUntil[entry.stat]
		if blockedUntil and os.clock() < blockedUntil then
			continue
		end

		-- Fire one increment and confirm it landed before returning.
		pcall(function()
			remote:InvokeServer(entry.arg)
		end)

		local deadline = os.clock() + 0.75
		while os.clock() < deadline do
			local now = tonumber(character:GetAttribute(entry.stat)) or 0
			if now > before then
				investBlockedUntil[entry.stat] = nil
				return true
			end
			task.wait(0.05)
		end

		-- Didn't rise -> can't afford it right now. Block it briefly and move on to the next attribute.
		investBlockedUntil[entry.stat] = os.clock() + 8
	end

	return false
end

-- ============================================================================================
-- Shrine progress (used by Auto Prog). Mirrors PR's ab_builder:shrine_ready / finished -- purely
-- attribute-based: compare the character's current Stat_* values to a target spread.
-- ============================================================================================

---Sum of still-unmet attribute points for a spread, plus the total wanted. Returns (missing, wanted).
---@param spread table?
---@return number, number
function AutoBuilder.missingForSpread(spread)
	local character = players.LocalPlayer and players.LocalPlayer.Character
	if not spread or not character then
		return 0, 0
	end

	local missing, wanted = 0, 0
	for _, entry in ipairs(INVEST_TARGETS) do
		local goal = tonumber(spread[entry.group] and spread[entry.group][entry.key]) or 0
		if goal > 0 then
			wanted = wanted + goal
			local current = tonumber(character:GetAttribute(entry.stat)) or 0
			missing = missing + math.max(0, goal - current)
		end
	end

	return missing, wanted
end

---Whether the preshrine attribute spread is fully invested (ready for the Shrine of Order).
---@return boolean
function AutoBuilder.shrineReady()
	local build = AutoBuilder.current
	if not build then
		return false
	end

	local missing, wanted = AutoBuilder.missingForSpread(build.pre)
	return wanted > 0 and missing == 0
end

---Whether the postshrine (final) attribute spread is fully invested -- the build is complete.
---@return boolean
function AutoBuilder.finished()
	local build = AutoBuilder.current
	if not build then
		return false
	end

	local missing, wanted = AutoBuilder.missingForSpread(build.post)
	return wanted > 0 and missing == 0
end

---Whether the current pending choice is a "special" hand (matches the game's u1 == "special"): the
---replicated SpecialChoice has a Type and a non-empty Selection.
---@return boolean
local function isSpecialChoice()
	local info = replicatedStorage:FindFirstChild("Info")
	local dataReplication = info and info:FindFirstChild("DataReplication")
	if not dataReplication then
		return false
	end

	local ok, module = pcall(require, dataReplication)
	if not ok or type(module) ~= "table" or type(module.GetData) ~= "function" then
		return false
	end

	local gotData, data = pcall(module.GetData)
	if not gotData or type(data) ~= "table" then
		return false
	end

	local special = data.SpecialChoice
	return type(special) == "table"
		and special.Type ~= nil
		and type(special.Selection) == "table"
		and #special.Selection > 0
end

---Fire the game's TalentChoice remote for a card by name. Returns true if the remote was invoked.
---@param name string
---@return boolean
local function chooseCard(name)
	local remote = getTalentChoiceRemote()
	if not remote then
		return false
	end

	local special = isSpecialChoice()

	return pcall(function()
		remote:InvokeServer(name, special)
	end)
end

---All TextButton descendants of PlayerGui.TalentGui.ChoiceFrame (the talent/mantra cards).
---@return table
local function getChoiceButtons()
	local talentGui = getTalentGui()
	local choiceFrame = talentGui and talentGui:FindFirstChild("ChoiceFrame")

	local buttons = {}
	if not choiceFrame then
		return buttons
	end

	for _, descendant in next, choiceFrame:GetDescendants() do
		if descendant:IsA("TextButton") then
			buttons[#buttons + 1] = descendant
		end
	end

	return buttons
end

---Pick a single card according to the priority (preshrine wanted > postshrine wanted > random real
---card) by firing the TalentChoice remote. Returns true if a card was chosen.
---@return boolean
function AutoBuilder.pickOnce()
	local buttons = getChoiceButtons()
	if #buttons == 0 then
		return false
	end

	-- "Only Roll 2 For Mantras": the special "Roll 2" card only appears in a Mantra Hand (it grants 2
	-- Talents instead of a mantra). When the toggle is on, always take it before considering any card --
	-- so mantra hands never pick a mantra. Talent hands have no Roll 2 card, so they fall through.
	if Toggles and Toggles.AutoBuilderOnlyRoll2 and Toggles.AutoBuilderOnlyRoll2.Value then
		for _, button in ipairs(buttons) do
			if button.Name == "Roll 2" then
				return chooseCard("Roll 2")
			end
		end
	end

	local classified = AutoBuilder.classified
	local bdata = AutoBuilder.current and AutoBuilder.current.bdata

	-- Build the wanted-name sets (talents + mantras) for each column.
	local wantedPre, wantedPost = {}, {}
	if classified then
		for _, name in ipairs(classified.pre.talents) do
			wantedPre[name] = true
		end
		for _, name in ipairs(classified.pre.mantras) do
			wantedPre[name] = true
		end
		for _, name in ipairs(classified.post.talents) do
			wantedPost[name] = true
		end
		for _, name in ipairs(classified.post.mantras) do
			wantedPost[name] = true
		end
	end

	-- 1) A preshrine pick that's on offer.
	for _, button in ipairs(buttons) do
		if wantedPre[button.Name] then
			return chooseCard(button.Name)
		end
	end

	-- 2) A postshrine pick that's on offer.
	for _, button in ipairs(buttons) do
		if wantedPost[button.Name] then
			return chooseCard(button.Name)
		end
	end

	-- 3) None of the wanted cards are here -- pick a random real talent/mantra card. We use ddata to
	-- confirm each button's name is an actual talent/mantra (avoids firing on non-card buttons). If
	-- ddata isn't available, fall back to any button.
	local cards = {}
	for _, button in ipairs(buttons) do
		if bdata and bdata.ddata:get(button.Name) ~= nil then
			cards[#cards + 1] = button
		end
	end
	if #cards == 0 then
		cards = buttons
	end

	return chooseCard(cards[math.random(1, #cards)].Name)
end

---Register the picking loop (guarded by AutoBuilder.picking). Call once at startup.
function AutoBuilder.init()
	pickMaid:add(renderStepped:connect("AutoBuilderPick_OnRender", function()
		if not AutoBuilder.picking then
			return
		end

		-- Point investment toward the selected spread. The remote yields, so run it off-thread with a
		-- busy guard to avoid overlapping invokes.
		if not investBusy and os.clock() >= investCooldownUntil then
			investBusy = true
			task.spawn(function()
				-- investOnce self-paces (it confirms each point), so retry immediately after a success
				-- and back off when there's nothing to do / everything's blocked.
				local fired = AutoBuilder.investOnce()
				investCooldownUntil = os.clock() + (fired and 0 or 1.0)
				investBusy = false
			end)
		end

		-- Card picking: paced by a cooldown, off-thread (the TalentChoice remote yields too). Picks as
		-- soon as cards are present (no wait for the list to "settle").
		if not pickBusy and os.clock() >= pickCooldownUntil then
			pickBusy = true
			task.spawn(function()
				local fired = AutoBuilder.pickOnce()
				pickCooldownUntil = os.clock() + (fired and 1.0 or 0.25)
				pickBusy = false
			end)
		end
	end))

	if not LPH_OBFUSCATED or (shared.Aero and shared.Aero.verbose) then
		Logger.warn("Auto Builder initialized.")
	end
end

function AutoBuilder.detach()
	pickMaid:clean()
end

return AutoBuilder
