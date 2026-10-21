-- Attack ownership / loadout scanner (ported 1:1 from Katalyst's PlayerScanning additions).
-- Caches each player's Backpack tools + equipped-weapon context (parsed from RichStats /
-- PrimaryWeapon attributes) so the anti-breaker can (a) confirm an attacker actually owns the
-- tool a timing maps to, and (b) match replicated weapon evidence to the equipped weapon.
-- Isolated module -- does NOT touch Aero's own PlayerScanning / ModuleManager.

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.Maid
local Maid = require("Utility/Maid")

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Ownership = { friendCache = {}, loadoutCache = {}, loadoutMaids = {} }

local sharedMaid = Maid.new()
local initialized = false
local loadoutTrackingActive = false

local function clearTable(t)
	for k in next, t do
		t[k] = nil
	end
end

local function isTrackedItem(inst)
	return inst and typeof(inst) == "Instance"
		and (inst:IsA("Tool") or inst:GetAttribute("ItemName") ~= nil or inst.Name:match("^Mantra:"))
end

local function disposeCache(player)
	local cache = Ownership.loadoutCache[player]
	if cache then
		cache.backpackMaid:clean()
		cache.characterMaid:clean()
		cache.weaponMaid:clean()
	end
	local maid = Ownership.loadoutMaids[player]
	if maid then
		maid:clean()
	end
	Ownership.loadoutMaids[player] = nil
	Ownership.loadoutCache[player] = nil
end

local function newCache(player)
	local now = os.clock()
	return {
		player = player, tools = {}, itemNames = {}, backpack = nil, character = nil,
		firstSeen = now, lastChanged = now, backpackLoaded = false, weaponInstance = nil,
		weaponContext = nil, backpackMaid = Maid.new(), characterMaid = Maid.new(), weaponMaid = Maid.new(),
	}
end

local function touch(cache)
	cache.lastChanged = os.clock()
end

local function tableCount(t)
	local n = 0
	for _ in next, t or {} do
		n = n + 1
	end
	return n
end

local function reliable(cache)
	if not cache or not cache.backpack then
		return false
	end
	local now = os.clock()
	local stable = now - cache.lastChanged >= 0.35
	local loaded = cache.backpackLoaded or CollectionService:HasTag(cache.backpack, "Loaded")
	local aged = now - cache.firstSeen >= 3
	return stable and (loaded or aged)
end

local function cacheDebug(cache)
	if not cache then
		return "cache=none"
	end
	local now = os.clock()
	return string.format("cache=%s backpack=%s loaded=%s stable=%.2f age=%.2f tools=%d itemNames=%d",
		reliable(cache) and "reliable" or "warming",
		cache.backpack and "yes" or "no",
		cache.backpackLoaded and "yes" or "no",
		now - (cache.lastChanged or now), now - (cache.firstSeen or now),
		tableCount(cache.tools), tableCount(cache.itemNames))
end

local function addTool(cache, inst)
	if not isTrackedItem(inst) then
		return
	end
	cache.tools[inst.Name] = true
	local itemName = inst:GetAttribute("ItemName")
	if typeof(itemName) == "string" and itemName ~= "" then
		cache.itemNames[itemName] = true
	end
end

local function trim(s)
	if typeof(s) ~= "string" then
		return nil
	end
	local v = s:match("^%s*(.-)%s*$")
	if v == "" then
		return nil
	end
	return v
end

local function stripRich(s)
	if typeof(s) ~= "string" then
		return ""
	end
	return (s:gsub("<[^>]*>", ""):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"))
end

local function firstNonColonLine(text)
	for line in string.gmatch(text or "", "[^\r\n]+") do
		local t = trim(line)
		if t and not string.find(t, ":", 1, true) then
			return t
		end
	end
end

local function splitPipe(text)
	local out = {}
	for part in string.gmatch(text or "", "([^|]+)") do
		out[#out + 1] = trim(part)
	end
	return out
end

local function matchNumber(pattern, text)
	local m = text and text:match(pattern)
	return tonumber(m)
end

---Parse a Weapon instance's attributes into a weapon-context table.
local function parseWeapon(weapon)
	if not weapon then
		return nil
	end
	local primary = trim(weapon:GetAttribute("PrimaryWeapon"))
	local richStats = weapon:GetAttribute("RichStats")
	local clean = stripRich(richStats)
	local typeLine = clean:match("[Tt]ype%s*:%s*([^\r\n]+)")
	local typeParts = splitPipe(typeLine)
	local name = primary or firstNonColonLine(clean)
	if not name and weapon.Name ~= "Weapon" then
		name = weapon.Name
	end
	local ctx = {
		instance = weapon,
		primaryWeapon = primary,
		weaponName = name,
		weaponType = typeParts[1],
		weaponClass = typeParts[2],
		weaponDamageType = typeParts[3],
		weaponSwingSpeed = matchNumber("[Ss]wing%s+[Ss]peed%s*:%s*([%d%.]+)", clean),
		weaponAttackDuration = matchNumber("[Aa]ttack%s+[Dd]uration%s*:%s*([%d%.]+)", clean),
		weaponRange = matchNumber("[Rr]ange%s*:%s*([%d%.]+)", clean),
		richStats = typeof(richStats) == "string" and richStats or nil,
	}
	if not ctx.weaponName and not ctx.weaponType and not ctx.weaponClass and not ctx.weaponDamageType then
		return nil
	end
	return ctx
end

local function bindWeapon(cache, weapon)
	if cache.weaponInstance == weapon then
		return
	end
	cache.weaponInstance = weapon
	cache.weaponMaid:clean()
	if not weapon then
		return
	end
	local function reparse()
		cache.weaponContext = parseWeapon(weapon)
		touch(cache)
	end
	cache.weaponMaid:add(Signal.new(weapon:GetAttributeChangedSignal("PrimaryWeapon"))
		:connect("AttackOwnership_WeaponPrimaryChanged", reparse))
	cache.weaponMaid:add(Signal.new(weapon:GetAttributeChangedSignal("RichStats"))
		:connect("AttackOwnership_WeaponRichStatsChanged", reparse))
end

local function refreshWeapon(cache)
	local weapon = cache.backpack and cache.backpack:FindFirstChild("Weapon")
	bindWeapon(cache, weapon)
	cache.weaponContext = parseWeapon(weapon)
end

local function refreshTools(player)
	local cache = Ownership.loadoutCache[player]
	if not cache then
		return
	end
	cache.tools = {}
	cache.itemNames = {}
	local backpack = cache.backpack
	cache.backpackLoaded = (backpack and CollectionService:HasTag(backpack, "Loaded") == true) or false
	if backpack then
		for _, child in next, backpack:GetChildren() do
			addTool(cache, child)
		end
	end
	refreshWeapon(cache)
	if cache.character then
		for _, child in next, cache.character:GetChildren() do
			addTool(cache, child)
		end
	end
end

local function bindContainer(player, maid, container)
	if not container then
		return
	end
	maid:add(Signal.new(container.ChildAdded):connect("AttackOwnership_LoadoutChildAdded", function(child)
		local cache = Ownership.loadoutCache[player]
		if not cache then
			return
		end
		addTool(cache, child)
		if container == cache.backpack and child.Name == "Weapon" then
			refreshTools(player)
		end
		touch(cache)
	end))
	maid:add(Signal.new(container.ChildRemoved):connect("AttackOwnership_LoadoutChildRemoved", function()
		local cache = Ownership.loadoutCache[player]
		if not cache then
			return
		end
		refreshTools(player)
		touch(cache)
	end))
end

local function bindBackpack(player, cache, backpack)
	if cache.backpack == backpack then
		return false
	end
	cache.backpackMaid:clean()
	cache.backpack = backpack
	cache.backpackLoaded = false
	cache.firstSeen = os.clock()
	bindContainer(player, cache.backpackMaid, backpack)
	return true
end

local function bindCharacter(player, cache, character)
	if cache.character == character then
		return false
	end
	cache.characterMaid:clean()
	cache.character = character
	bindContainer(player, cache.characterMaid, character)
	return true
end

local function buildCache(player)
	if player == Players.LocalPlayer then
		return nil
	end
	if Ownership.loadoutCache[player] then
		return Ownership.loadoutCache[player]
	end
	disposeCache(player)
	local maid = Maid.new()
	local cache = newCache(player)
	Ownership.loadoutMaids[player] = maid
	Ownership.loadoutCache[player] = cache

	local function resync()
		if Ownership.loadoutCache[player] ~= cache then
			return
		end
		refreshTools(player)
		touch(cache)
	end

	maid:add(Signal.new(player.ChildAdded):connect("AttackOwnership_PlayerChildAdded", function(child)
		if child.Name == "Backpack" and bindBackpack(player, cache, child) then
			resync()
		end
	end))
	maid:add(Signal.new(player.ChildRemoved):connect("AttackOwnership_PlayerChildRemoved", function(child)
		if child == cache.backpack then
			bindBackpack(player, cache, player:FindFirstChild("Backpack"))
			resync()
		end
	end))
	maid:add(Signal.new(player.CharacterAdded):connect("AttackOwnership_CharacterAdded", function(character)
		if bindCharacter(player, cache, character) then
			resync()
		end
	end))
	maid:add(Signal.new(player.CharacterRemoving):connect("AttackOwnership_CharacterRemoving", function(character)
		if character == cache.character then
			bindCharacter(player, cache, nil)
			resync()
		end
	end))

	bindBackpack(player, cache, player:FindFirstChild("Backpack"))
	bindCharacter(player, cache, player.Character)
	resync()
	return cache
end

local function disposeAll()
	local players = {}
	for p in next, Ownership.loadoutMaids do
		players[p] = true
	end
	for p in next, Ownership.loadoutCache do
		players[p] = true
	end
	for p in next, players do
		disposeCache(p)
	end
end

---Does the cached loadout satisfy the descriptor (names/exact/contains)?
local function matchDescriptor(cache, descriptor)
	local names = descriptor.names or descriptor.exact or {}
	if typeof(names) == "string" then
		names = { names }
	end
	for _, n in next, names do
		if cache.tools[n] or cache.itemNames[n] then
			return true, n
		end
	end
	local contains = descriptor.contains or {}
	if typeof(contains) == "string" then
		contains = { contains }
	end
	for tool in next, cache.tools do
		for _, needle in next, contains do
			if string.find(tool, needle, 1, true) then
				return true, tool
			end
		end
	end
	for item in next, cache.itemNames do
		for _, needle in next, contains do
			if string.find(item, needle, 1, true) then
				return true, item
			end
		end
	end
	return false, names[1] or contains[1]
end

---@return table
function Ownership.toolOwnership(player, descriptor)
	if not player or player == Players.LocalPlayer then
		return { status = "not-applicable", reason = "npc-or-local" }
	end
	if typeof(descriptor) ~= "table" or descriptor.notApplicable then
		return { status = "not-applicable", reason = "unmapped" }
	end
	if not descriptor.names and not descriptor.exact and not descriptor.contains then
		return { status = "not-applicable", reason = "no-tool-descriptor" }
	end
	local cache = Ownership.loadoutCache[player] or buildCache(player)
	if not cache then
		return { status = "unknown", reason = "no-cache", attack = descriptor.label, cache = "cache=none" }
	end
	local matched, label = matchDescriptor(cache, descriptor)
	local attackLabel = descriptor.label or label
	local dbg = cacheDebug(cache)
	if matched then
		return { status = "confirmed", reason = "matched", attack = attackLabel, matched = matched, cache = dbg }
	end
	if reliable(cache) then
		return { status = "missing", reason = "not-found", attack = attackLabel, expected = label, cache = dbg }
	end
	return { status = "unknown", reason = cache.backpack and "loading-or-unstable" or "no-backpack", attack = attackLabel, expected = label, cache = dbg }
end

---@return table
function Ownership.weaponContext(player)
	if not player or player == Players.LocalPlayer then
		return { status = "not-applicable", reason = "npc-or-local", cache = "cache=none" }
	end
	local cache = Ownership.loadoutCache[player] or buildCache(player)
	if not cache then
		return { status = "unknown", reason = "no-cache", cache = "cache=none" }
	end
	local dbg = cacheDebug(cache)
	if not reliable(cache) then
		return { status = "unknown", reason = cache.backpack and "loading-or-unstable" or "no-backpack", cache = dbg }
	end
	if not cache.weaponContext then
		return { status = "unknown", reason = cache.weaponInstance and "unparsed-weapon" or "no-backpack-weapon", cache = dbg }
	end
	local out = {}
	for k, v in next, cache.weaponContext do
		out[k] = v
	end
	out.status = "available"
	out.reason = "backpack-weapon"
	out.cache = dbg
	return out
end

function Ownership.isAlly(player)
	if not player then
		return false
	end
	local guild = Players.LocalPlayer:GetAttribute("Guild")
	return Ownership.friendCache[player] == true or (guild and guild ~= "" and player:GetAttribute("Guild") == guild)
end

local function onFriendStatus(player, status)
	Ownership.friendCache[player] = status == Enum.FriendStatus.Friend
end

local function onPlayerAdded(player)
	if player == Players.LocalPlayer then
		return
	end
	Ownership.friendCache[player] = Players.LocalPlayer:GetFriendStatus(player) == Enum.FriendStatus.Friend
	if loadoutTrackingActive then
		buildCache(player)
	end
end

local function onPlayerRemoving(player)
	disposeCache(player)
	Ownership.friendCache[player] = nil
end

function Ownership.setLoadoutTrackingActive(active)
	active = active == true
	if loadoutTrackingActive == active then
		if not active then
			disposeAll()
		end
		return
	end
	loadoutTrackingActive = active
	if active and initialized then
		for _, player in next, Players:GetPlayers() do
			if player ~= Players.LocalPlayer then
				buildCache(player)
			end
		end
	else
		disposeAll()
	end
end

function Ownership.init()
	if initialized then
		return
	end
	initialized = true
	pcall(function()
		sharedMaid:add(Signal.new(Players.LocalPlayer.FriendStatusChanged)
			:connect("AttackOwnership_FriendStatusChanged", onFriendStatus))
	end)
	pcall(function()
		sharedMaid:add(Signal.new(Players.PlayerAdded):connect("AttackOwnership_PlayerAdded", onPlayerAdded))
	end)
	pcall(function()
		sharedMaid:add(Signal.new(Players.PlayerRemoving):connect("AttackOwnership_PlayerRemoving", onPlayerRemoving))
	end)
	for _, player in next, Players:GetPlayers() do
		pcall(onPlayerAdded, player)
	end
end

function Ownership.detach()
	initialized = false
	loadoutTrackingActive = false
	sharedMaid:clean()
	disposeAll()
	clearTable(Ownership.friendCache)
end

return Ownership
