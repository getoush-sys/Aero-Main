---@module Features.Combat.Objects.Defender
local Defender = require("Features/Combat/Objects/Defender")

---@module Features.Combat.Objects.AttackAuthenticator
local AttackAuthenticator = require("Features/Combat/Objects/AttackAuthenticator")

---@module Features.Combat.Objects.AnimationIngressGuard
local IngressGuard = require("Features/Combat/Objects/AnimationIngressGuard")

---@module Features.Combat.Objects.AttackOwnership
local AttackOwnership = require("Features/Combat/Objects/AttackOwnership")

---@module Utility.Maid
local AntiBreakerMaid = require("Utility/Maid")

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Game.Timings.SaveManager
local SaveManager = require("Game/Timings/SaveManager")

---@module Utility.Logger
local Logger = require("Utility/Logger")

local CANONICAL_AID_SCHEMES = {
	["rbxassetid"] = true,
	["rbxasset"] = true,
	["http"] = true,
	["https"] = true,
}

local function canonicalAid(animationId)
	local text = tostring(animationId or "")

	local plain = text:match("^rbxassetid://(%d+)$")
	if plain then
		return "rbxassetid://" .. plain
	end

	if text:find("[^%w:/.?&=%%%-]") then
		return text
	end

	local scheme = text:match("^(%a+)://")
	if not scheme or not CANONICAL_AID_SCHEMES[scheme:lower()] then
		return text
	end

	local _, idOccurrences = text:gsub("[?&]id=", "")
	if idOccurrences ~= 1 then
		return text
	end

	local real = text:match("[?&]id=(%d+)")
	if real then
		return "rbxassetid://" .. real
	end

	return text
end

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Game.Timings.PlaybackData
local PlaybackData = require("Game/Timings/PlaybackData")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Features.Combat.Objects.RepeatInfo
local RepeatInfo = require("Features/Combat/Objects/RepeatInfo")

---@module Game.QueuedBlocking
local QueuedBlocking = require("Game/QueuedBlocking")

---@module Features.Combat.Objects.HitboxOptions
local HitboxOptions = require("Features/Combat/Objects/HitboxOptions")

---@module Utility.OriginalStore
local OriginalStore = require("Utility/OriginalStore")

---@module Features.Combat.EntityHistory
local EntityHistory = require("Features/Combat/EntityHistory")

---@module Features.Combat.StateListener
local StateListener = require("Features/Combat/StateListener")

---@module Game.Latency
local Latency = require("Game/Latency")

---@module GUI.Library
local Library = require("GUI/Library")

---@module Utility.TaskSpawner
local TaskSpawner = require("Utility/TaskSpawner")

---@class AnimatorDefender: Defender
---@field animator Animator
---@field offset number?
---@field entity Model
---@field keyframes Action[]
---@field timing AnimationTiming?
---@field pbdata table<AnimationTrack, PlaybackData> Playback data to be recorded.
---@field rpbdata table<string, PlaybackData> Recorded playback data. Optimization so we don't have to constantly reiterate over recorded data.
---@field manimations table<number, Animation>
---@field track AnimationTrack? Don't be confused. This is the **valid && last** animation track played.
---@field maid Maid This maid is cleaned up after every new animation track. Safe to use for on-animation-track setup.
---@field sct table<AnimationTrack, boolean> Tracks that need to have their speed changed.
---@field tsc table<AnimationTrack, number> Tracks that are saving their last speed.
---@field _trackSeq number Monotonic counter incremented each time self.track is assigned. Used to detect stale deferred checks.
local AnimatorDefender = setmetatable({}, { __index = Defender })
AnimatorDefender.__index = AnimatorDefender
AnimatorDefender.__type = "Animation"

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local MAX_REPEAT_TIME = 5.0
local HISTORY_STEPS = 5.0
local PREDICT_FACING_DELTA = 3
local GALE_FEINT_GRACE = 0.1
local FEINT_CUE_GRACE_PERIOD = 0.15

-- Roll whether we react to a feint on this timing. Honors the timing's per-move override (rtfr) and
-- otherwise only reacts when Allow Failure is on (default rate 0 = never blindly react).
---@param timing AnimationTiming?
---@return boolean
local function reactRoll(timing)
	local reactRate = Configuration.expectOptionValue("ReactToFeintsRate") or 0.0
	local overrideData = timing and Library:GetOverrideData(timing.name)
	if overrideData and overrideData.rtfr then
		reactRate = overrideData.rtfr
	elseif not Configuration.expectToggleValue("AllowFailure") then
		return false
	end

	return Random.new():NextNumber(1.0, 100.0) <= reactRate
end

local MAX_ANIMATIONS_PER_SECOND = 50
local animationProcessWindowStart = os.clock()
local animationProcessCount = 0

local function underAnimationProcessCap()
	local now = os.clock()
	if now - animationProcessWindowStart >= 1 then
		animationProcessWindowStart = now
		animationProcessCount = 0
	end

	animationProcessCount = animationProcessCount + 1
	return animationProcessCount <= MAX_ANIMATIONS_PER_SECOND
end

---@param self AnimatorDefender
---@param track AnimationTrack
---@param timing AnimationTiming
---@param notify boolean? Whether to notify or not.
---@return boolean
AnimatorDefender.stopped = LPH_NO_VIRTUALIZE(function(self, track, timing, notify)
	local function internalNotifyFunction(...)
		if not notify then
			return
		end

		return self:notify(...)
	end

	if self._feintedTrack == track then
		return true, internalNotifyFunction(timing, "Feint cue was heard for this track.")
	end

	local overrideData = Library:GetOverrideData(timing.name)
	local rate = (Configuration.expectOptionValue("IgnoreAnimationEndRate") or 0.0)

	if overrideData then
		rate = overrideData.iaer
	end

	if
		(Configuration.expectToggleValue("AllowFailure") or overrideData)
		and not timing.rpue
		and Random.new():NextNumber(1.0, 100.0) <= rate
		and StateListener.cdodge()
	then
		return false, internalNotifyFunction(timing, "Intentionally ignoring animation end to simulate human error.")
	end

	if timing.nfd then
		return false
	end

	-- Anti-AP Breaker: a real attack still resolves server-side even when the attacker Stop()s and
	-- replays the animation client-side (the core of their breaker -- stop, then replay at Core
	-- priority with TimePosition 0). While the anti is armed, ignore the animation end so a faked stop
	-- can't abort the parry -- same effect as Allow Failure's ignore-animation-end, forced on at 100%.
	-- RPUE timings keep their normal end handling (they rely on it to know when to stop repeating).
	if not timing.rpue and Configuration.expectToggleValue("AntiBreakerEnabled") then
		return false, internalNotifyFunction(timing, "Anti-AP Breaker: ignoring animation end.")
	end

	if not timing.iae and not track.IsPlaying and self._respectFeint then
		return true, internalNotifyFunction(timing, "Animation stopped playing.")
	end

	if timing.iae and not timing.ieae and not track.IsPlaying and track.TimePosition < track.Length and self._respectFeint then
		return true, internalNotifyFunction(timing, "Animation stopped playing early.")
	end
end)

---@param self AnimatorDefender
---@param info RepeatInfo
---@return boolean
AnimatorDefender.rc = LPH_NO_VIRTUALIZE(function(self, info)
	---@note: There are cases where we might not have a track. If it's not handled properly, it will throw an error.
	if not info.track then
		return Logger.warn(
			"(%s) Did you forget to pass the track? Or perhaps you forgot to place a hook before using this function.",
			info.timing.name
		)
	end

	if self:stopped(info.track, info.timing) then
		return false
	end

	if info.timing.iae and os.clock() - info.start >= ((info.timing.mat / 1000) or MAX_REPEAT_TIME) then
		return self:notify(info.timing, "Max animation timeout exceeded.")
	end

	return true
end)

---@param self AnimatorDefender
---@param options HitboxOptions
---@return boolean
AnimatorDefender.pfh = LPH_NO_VIRTUALIZE(function(self, options)
	local root = self.entity:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local localRoot = players.LocalPlayer.Character and players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not localRoot then
		return false
	end

	if not options.timing.ffh then
		local yrate = EntityHistory.yrate(self.entity)
		if not yrate then
			return false
		end

		if math.abs(yrate) < PREDICT_FACING_DELTA then
			return
		end
	end

	local clone = options:clone()
	clone.hcolor = Color3.new(0, 1, 1)
	clone.mcolor = Color3.new(1, 1, 0)
	clone:ucache()

	local result = false
	local store = OriginalStore.new()

	store:run(root, "CFrame", CFrame.lookAt(root.Position, localRoot.Position), function()
		result = self:hc(clone, nil)
	end)

	return result
end)

---@param timing Timing
---@param options HitboxOptions
---@return boolean
AnimatorDefender.phd = LPH_NO_VIRTUALIZE(function(self, timing, options)
	for _, cframe in next, EntityHistory.pstepped(self.entity, HISTORY_STEPS, timing.phds) or {} do
		local clone = options:clone()
		clone.cframe = cframe
		clone.hcolor = Color3.new(0.839215, 0.976470, 0.537254)
		clone.mcolor = Color3.new(0.564705, 0, 1)
		clone:ucache()

		if not self:hc(clone, nil) then
			continue
		end

		return true
	end
end)

AnimatorDefender.fpc = LPH_NO_VIRTUALIZE(function(self, timing, options)
	if timing.duih then
		return false
	end

	if (timing.ffh or timing.pfh) and self:pfh(options) then
		return true
	end

	if timing.phd and self:phd(timing, options) then
		return true
	end
end)

---@param self AnimatorDefender
---@param options ValidationOptions
---@return boolean
AnimatorDefender.valid = LPH_NO_VIRTUALIZE(function(self, options)
	if not Defender.valid(self, options) then
		return false
	end

	local timing = options.timing
	local action = options.action

	local function internalNotifyFunction(...)
		if not options.notify then
			return
		end

		return self:notify(...)
	end

	if not self.track then
		return internalNotifyFunction(timing, "No current track.")
	end

	if not self.entity then
		return internalNotifyFunction(timing, "No entity found.")
	end

	local target = self:target(self.entity)
	if not target then
		return internalNotifyFunction(timing, "Not a viable target.")
	end

	local root = self.entity:FindFirstChild("HumanoidRootPart")
	if not root then
		return internalNotifyFunction(timing, "No humanoid root part found.")
	end

	local character = players.LocalPlayer.Character
	if not character then
		return internalNotifyFunction(timing, "No character found.")
	end

	local targetInstance = self.entity:FindFirstChild("Target")

	if
		targetInstance
		and targetInstance.Value ~= character
		and Configuration.expectToggleValue("CheckTargetingValue")
	then
		return internalNotifyFunction(timing, "Not being targeted.")
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return internalNotifyFunction(timing, "No effect replicator found.")
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return internalNotifyFunction(timing, "No effect replicator module found.")
	end

	if
		not timing.imb
		and root:FindFirstChild("MegalodauntBroken")
		and not players:GetPlayerFromCharacter(self.entity)
	then
		return internalNotifyFunction(timing, "Entity is block broken.")
	end

	if self:stopped(self.track, timing, options.notify) then
		return false
	end

	if timing.uif then
		local function feinted()
			return self._galeFeintTracks ~= nil and table.find(self._galeFeintTracks, self.track) ~= nil
		end

		local deadline = os.clock() + GALE_FEINT_GRACE
		while not feinted() and os.clock() < deadline do
			task.wait()
		end

		if feinted() and self._respectFeint then
			Logger.warn("(%s) Skipping action '%s', gale feint detected.", self.entity.Name, timing.name)
			return internalNotifyFunction(timing, "Gale feint detected (inhale cue) -- skipping.")
		end
	end

	local hoptions = HitboxOptions.new(root, timing)
	hoptions.spredict = not timing.duih and not timing.dp
	hoptions.ptime = self:fsecs(timing)
	hoptions.action = action
	hoptions.entity = self.entity
	hoptions.visualize = options.visualize
	hoptions:ucache()

	local info = RepeatInfo.new(timing, Latency.rdelay(), self:uid(10))
	info.track = self.track

	local hc = self:hc(hoptions, timing.duih and info or nil)
	if hc then
		return true
	end

	local pc = self:fpc(timing, hoptions)
	if pc then
		return true
	end

	return self:notify(timing, "Not in hitbox.")
end)

---@param self AnimatorDefender
AnimatorDefender.update = LPH_NO_VIRTUALIZE(function(self)
	for track, data in next, self.pbdata do
		if not Configuration.expectToggleValue("ShowAnimationVisualizer") then
			self.pbdata[track] = nil
			continue
		end

		if not track.IsPlaying then
			self.pbdata[track] = nil
			self.rpbdata[tostring(track.Animation.AnimationId)] = data

			continue
		end

		data:astrack(track.Speed)
	end

	if not Configuration.expectToggleValue("AnimationSpeedChanger") then
		return
	end

	local min = Configuration.expectOptionValue("AnimationSpeedMinimum") or 1.0
	local max = Configuration.expectOptionValue("AnimationSpeedMaximum") or 1.3
	local rng = Random.new()

	for track, _ in next, self.sct do
		if not track.IsPlaying then
			self.sct[track] = nil
			self.tsc[track] = nil
			self.multiplier[track] = nil
			continue
		end

		if self.tsc[track] == tostring(track.Speed) then
			continue
		end

		local mode = rng:NextInteger(1, 2)
		local generated = nil

		if not self.multiplier[track] and not Configuration.expectToggleValue("SwitchBetweenSpeeds") then
			generated = rng:NextNumber(min, max)
		end

		if not self.multiplier[track] and Configuration.expectToggleValue("SwitchBetweenSpeeds") then
			generated = mode == 1 and min or max
		end

		if not self.multiplier[track] and generated then
			self.multiplier[track] = generated
		end

		local multiplier = self.multiplier[track]
		if not multiplier then
			continue
		end

		if multiplier == 1.0 then
			continue
		end

		local adjusted = track.Speed * multiplier

		track:AdjustSpeed(adjusted)

		self.tsc[track] = tostring(track.Speed)
	end
end)

---@param self AnimatorDefender
---@param track AnimationTrack
---@return boolean
function AnimatorDefender:isFullyDead(track)
	local humanoid = self.entity:FindFirstChild("Humanoid")
	if not humanoid then
		return true
	end

	return not table.find(humanoid:GetPlayingAnimationTracks(), track)
end

---@param self AnimatorDefender
---@param track AnimationTrack
AnimatorDefender.asc = LPH_NO_VIRTUALIZE(function(self, track)
	if not Configuration.expectToggleValue("AnimationSpeedChanger") then
		return
	end

	if
		Configuration.expectToggleValue("LimitToAPAnimations")
		and not SaveManager.as:index(canonicalAid(track.Animation.AnimationId))
	then
		return
	end

	self.sct[track] = true
end)

-- ============================================================================
-- ANTI-AP-BREAKER (exact 1:1 port of Katalyst): heuristic classifier (aapb) +
-- evidence authentication (AttackAuthenticator) + ingress rate-limiting
-- (AnimationIngressGuard) + loadout/weapon ownership (AttackOwnership). Armed
-- per-player-defender only while "AntiBreakerEnabled" is on. Gated OFF by default.
-- ============================================================================

-- ---- Ingress-quarantine ring: constants + forward declarations -------------
local APB_QUARANTINE_SIZE = 256
local APB_QUARANTINE_LANE_SIZE = 64
local APB_QUARANTINE_TTL = 0.30
local APB_QUARANTINE_LANE_BASE = { mantra = 0, ["weapon-critical"] = 1, weapon = 2, other = 3 }
local APB_WEAPON_SOUND_LATENCY = 0.04
local apbRecoverIngress -- XR: recover a quarantined candidate from authoritative evidence
local apbPruneQuarantine -- sR: age-out quarantine slots
local apbResolveCandidate -- rb: resolve a plausible timing candidate from a track
local apbQuarantine -- wb: park a rate-limited candidate in the ring

-- Category -> quarantine lane (PM).
local function apbLane(category)
	if category == "mantra" or category == "weapon-critical" then
		return category
	end
	if category == "weapon-m1" or category == "weapon-special" then
		return "weapon"
	end
	return "other"
end
-- Lane + cursor -> flat ring index (tM).
local function apbLaneIndex(lane, cursor)
	return APB_QUARANTINE_LANE_BASE[lane] * APB_QUARANTINE_LANE_SIZE + cursor
end
-- Clear one quarantine slot and drop it from the by-track index (YA).
local function apbClearQuarantineSlot(self, slot)
	local track = slot.track
	local lane = slot.lane
	if track and lane then
		local byTrack = self._apQuarantineByTrack and self._apQuarantineByTrack[lane]
		if byTrack and byTrack[track] == slot then
			byTrack[track] = nil
		end
	end
	if track then
		self._apQuarantineCount = math.max(0, (self._apQuarantineCount or 0) - 1)
	end
	slot.track = nil
	slot.timing = nil
	slot.aid = nil
	slot.category = nil
	slot.lane = nil
	slot.startedAt = nil
end
-- (Re)initialise the quarantine ring for this defender (uI).
local function apbInitQuarantine(self)
	local ring = self._apQuarantine
	if not ring then
		ring = table.create(APB_QUARANTINE_SIZE)
		for i = 1, APB_QUARANTINE_SIZE do
			ring[i] = {}
		end
		self._apQuarantine = ring
	else
		for i = 1, APB_QUARANTINE_SIZE do
			local slot = ring[i]
			slot.track = nil
			slot.timing = nil
			slot.aid = nil
			slot.category = nil
			slot.lane = nil
			slot.startedAt = nil
		end
	end
	self._apQuarantineCursors = { mantra = 1, ["weapon-critical"] = 1, weapon = 1, other = 1 }
	self._apQuarantineByTrack = {
		mantra = setmetatable({}, { __mode = "k" }),
		["weapon-critical"] = setmetatable({}, { __mode = "k" }),
		weapon = setmetatable({}, { __mode = "k" }),
		other = setmetatable({}, { __mode = "k" }),
	}
	self._apQuarantinePruneCursor = 1
	self._apQuarantineCount = 0
	self._apRecoveredOccurrences = setmetatable({}, { __mode = "k" })
end
-- Max-parry distance by tag/category (gU).
local function apbMaxDist(timing, base)
	base = base or tonumber(Configuration.expectOptionValue("AutoParryMaxDist")) or 28
	local imxd = timing and tonumber(timing.imxd)
	local tag = timing and timing.tag
	local cap
	if tag == "M1" or tag == "weapon-m1" then
		cap = math.min(base, 35)
	elseif tag == "Critical" or tag == "weapon-critical" then
		cap = math.min(math.max(base, 35), 45)
	elseif tag == "Mantra" then
		cap = 65
	else
		cap = math.max(base, 35)
	end
	if imxd and imxd > 0 then
		return math.min(imxd, cap)
	end
	return cap
end
-- Does an effect's prop belong to this attacker (ru)?
local function apbOwnsProp(self, prop, data)
	if typeof(data) == "table" and data.char == self.entity then
		return true
	end
	if typeof(prop) ~= "Instance" then
		return false
	end
	if prop:IsDescendantOf(self.entity) then
		return true
	end
	local owner = self._playerOwner or players:GetPlayerFromCharacter(self.entity)
	local name = owner and owner.Name or self.entity.Name
	local node = prop
	for _ = 1, 6 do
		if not node then
			break
		end
		if string.find(node.Name, name, 1, true) then
			return true
		end
		node = node.Parent
	end
	return false
end
-- Evidence family covers candidate category (Qb).
local function apbFamilyCovers(category, evidence)
	local families = evidence.families
	if not families or families[category] == true then
		return true
	end
	local weaponFamilies = { ["weapon-m1"] = true, ["weapon-critical"] = true, ["weapon-special"] = true }
	return evidence.allowWeaponFamilyBridge == true
		and weaponFamilies[category] == true
		and weaponFamilies[evidence.exactFamily] == true
end

-- Sliding-window prune helpers (window seconds, cap entries).
local AAPB_WINDOW = 1.0
local AAPB_CAP = 16
local function apbPruneTimes(list, now)
	local w = 0
	for i = 1, #list do
		if now - list[i] <= AAPB_WINDOW then
			w = w + 1
			list[w] = list[i]
		end
	end
	for i = #list, w + 1, -1 do
		list[i] = nil
	end
	local over = #list - AAPB_CAP
	if over > 0 then
		table.move(list, over + 1, #list, 1)
		for i = #list, AAPB_CAP + 1, -1 do
			list[i] = nil
		end
	end
end
local function apbPruneRecent(list, now)
	local w = 0
	for i = 1, #list do
		if now - list[i].time <= AAPB_WINDOW then
			w = w + 1
			list[w] = list[i]
		end
	end
	for i = #list, w + 1, -1 do
		list[i] = nil
	end
	local over = #list - AAPB_CAP
	if over > 0 then
		table.move(list, over + 1, #list, 1)
		for i = #list, AAPB_CAP + 1, -1 do
			list[i] = nil
		end
	end
end

local function apbLower(s)
	return typeof(s) == "string" and string.lower(s) or ""
end
local function apbNorm(s)
	if typeof(s) ~= "string" then
		return ""
	end
	return (string.gsub(string.lower(s), "[^%w]+", ""))
end
local function apbCount(map)
	local n = 0
	for _ in next, map or {} do
		n = n + 1
	end
	return n
end

-- Action aliases from StoredAction / StoredToolName for mantra evidence matching (nL).
local function apbMantraDisplay(s)
	if typeof(s) ~= "string" then
		return nil
	end
	return string.match(s, "{{(.-)}}") or string.match(s, "^RecalledMantra:(.-)%$")
end
local function apbMantraPrefix(s)
	if typeof(s) ~= "string" or s == "" then
		return nil
	end
	local base = string.match(s, "^(.-){{") or s
	base = string.match(base, "([^:]+)$") or base
	base = string.gsub(base, "%$", "")
	if base == "" or string.lower(base) == "mantra" then
		return nil
	end
	return base
end
local function apbActionAliases(entity)
	local out = {}
	local seen = {}
	local storedTool = entity and entity:GetAttribute("StoredToolName")
	local function add(value)
		if typeof(value) ~= "string" or value == "" then
			return
		end
		local norm = apbNorm(value)
		if norm == "" or seen[norm] then
			return
		end
		seen[norm] = true
		out[#out + 1] = value
	end
	add(entity and entity:GetAttribute("StoredAction"))
	add(apbMantraDisplay(storedTool))
	add(apbMantraPrefix(storedTool))
	return out
end

-- ---- Category (BA) ----------------------------------------------------------
local function apbSmod(timing)
	return timing and apbLower(timing.smod) or ""
end
local function apbName(timing)
	return timing and apbLower(timing.name) or ""
end
local function BA(timing)
	if not timing then
		return "other"
	end
	local smod = apbSmod(timing)
	local name = apbName(timing)
	if timing.tag == "Mantra" then
		return "mantra"
	end
	if timing.tag == "Critical" or smod:find("critical", 1, true) or name:find("critical", 1, true) then
		return "weapon-critical"
	end
	if timing.tag == "M1"
		or smod:find("swing", 1, true)
		or smod:find("weapontest", 1, true)
		or smod:find("weaponrunningattacktest", 1, true)
		or smod:find("weaponaerialattacktest", 1, true)
		or smod:find("weaponuppercuttest", 1, true)
		or smod:find("weaponflourishtest", 1, true) then
		return "weapon-m1"
	end
	if smod:find("silentheart", 1, true) or smod:find("veinbreaker", 1, true) or smod:find("curved", 1, true)
		or smod:find("pyre", 1, true) or smod:find("wraithclaw", 1, true) or smod:find("mayhem", 1, true)
		or smod:find("relentless", 1, true) or smod:find("risingstar", 1, true) or smod:find("runningcrit", 1, true) then
		return "weapon-special"
	end
	if timing.umoa then
		return "module"
	end
	return "other"
end
local function RA(category)
	return category == "weapon-m1" or category == "weapon-critical" or category == "weapon-special"
end

-- ---- Weapon-family descriptor DB (static, from Katalyst) + qM ---------------
local APB_ANY_WEAPON = { anyWeapon = true, family = "AnyWeapon", reason = "generic-weapon-context" }
local APB_SMOD_DESCRIPTORS = {
	galeheroblade = { exactNames = { "galehero", "galeheroblade" }, family = "GaleHeroBlade", reason = "specific-hero-blade" },
	iceheroblade = { exactNames = { "icehero", "iceheroblade" }, family = "IceHeroBlade", reason = "specific-hero-blade" },
	lightninghercrit = { exactNames = { "lightninghero", "lightningheroblade" }, family = "LightningHeroBlade", reason = "specific-hero-blade" },
	pyrekeepercritsliding = { exactNames = { "pyre", "pyrekeeper" }, family = "Pyrekeeper", reason = "specific-pyrekeeper" },
	soulthorncrit = { exactNames = { "soulthorn" }, family = "Soulthorn", reason = "specific-soulthorn" },
	wraithclawcrit = { exactNames = { "wraithclaw" }, family = "Wraithclaw", reason = "specific-wraithclaw" },
}
local APB_SPECIFIC_DESCRIPTORS = {
	{ needles = { "wraithclaw" }, exactNames = { "wraithclaw" }, family = "Wraithclaw", reason = "specific-wraithclaw" },
	{ needles = { "soulthorn" }, exactNames = { "soulthorn" }, family = "Soulthorn", reason = "specific-soulthorn" },
	{ needles = { "pyrekeeper" }, exactNames = { "pyre", "pyrekeeper" }, family = "Pyrekeeper", reason = "specific-pyrekeeper" },
	{ needles = { "curvedblade", "dualcurvedblade", "curved" }, exactNames = { "curved" }, family = "CurvedBlade", reason = "specific-curved" },
	{ needles = { "icehero", "iceheroblade" }, exactNames = { "icehero", "iceheroblade" }, family = "IceHeroBlade", reason = "specific-hero-blade" },
	{ needles = { "galehero", "galeheroblade" }, exactNames = { "galehero", "galeheroblade" }, family = "GaleHeroBlade", reason = "specific-hero-blade" },
	{ needles = { "lightninghero", "lightningheroblade", "lightninghercrit" }, exactNames = { "lightninghero", "lightningheroblade" }, family = "LightningHeroBlade", reason = "specific-hero-blade" },
}
local APB_GENERIC_DESCRIPTORS = {
	{ needles = { "musket", "rifle" }, types = { Rifle = true }, family = "Rifle", reason = "generic-rifle" },
	{ needles = { "pistol" }, types = { Pistol = true }, family = "Pistol", reason = "generic-pistol" },
	{ needles = { "greatcannon", "cannon", "blunderbuss" }, types = { Greatcannon = true, Rifle = true }, family = "ProjectileHeavy", reason = "generic-projectile-heavy" },
	{ needles = { "bow" }, types = { Bow = true }, family = "Bow", reason = "generic-bow" },
	{ needles = { "greatsword", "greataxe", "greathammer", "genericheavy", "heavy" }, classes = { Heavy = true }, types = { Greatsword = true, Greataxe = true, Greathammer = true, Axe = true, Hammer = true }, family = "Heavy", reason = "generic-heavy" },
	{ needles = { "spear", "javelin", "lance", "trident", "polearm" }, types = { Spear = true, Polearm = true, Javelin = true, Lance = true, Trident = true }, family = "Spear", reason = "generic-spear" },
	{ needles = { "club", "blunt", "mace" }, types = { Club = true, Mace = true }, damageTypes = { Blunt = true }, family = "ClubBlunt", reason = "generic-club-blunt" },
	{ needles = { "genericdagger", "dagger", "tanto", "rapier" }, classes = { Light = true }, types = { Dagger = true, Tanto = true, Rapier = true }, family = "Light", reason = "generic-light" },
	{ needles = { "fist", "karita", "navae" }, types = { Fist = true }, family = "Fist", reason = "generic-fist" },
	{ needles = { "genericsword", "swordswing", "swordcritical", "swordaerial", "genericmedium", "medium", "sword" }, classes = { Medium = true }, types = { Sword = true, Club = true, Mace = true, Katana = true }, family = "Medium", reason = "generic-medium" },
	{ needles = { "staff" }, types = { Staff = true }, family = "Staff", reason = "generic-staff" },
}
local APB_WEAPONTEST_DESCRIPTOR = { anyWeapon = true, family = "WeaponTest", reason = "weapon-test-module" }

-- Haystack string for needle matching: normalized smod/name/id.
local function apbHaystack(timing, aid)
	return table.concat({ apbNorm(timing and timing.smod), apbNorm(timing and timing.name), apbNorm(timing and timing._id), apbNorm(aid) }, " ")
end
local function apbNeedleHit(haystack, needles)
	for _, needle in next, needles or {} do
		if string.find(haystack, needle, 1, true) then
			return true
		end
	end
	return false
end
---@return table? descriptor, string reason
local function qM(timing, category, aid)
	if not RA(category) then
		return nil, "non-weapon-timing"
	end
	local smodKey = apbNorm(timing and timing.smod)
	local specific = smodKey ~= "" and APB_SMOD_DESCRIPTORS[smodKey]
	if specific then
		return specific, specific.reason or "specific-smod"
	end
	local haystack = apbHaystack(timing, aid)
	for _, d in next, APB_SPECIFIC_DESCRIPTORS do
		if apbNeedleHit(haystack, d.needles) then
			return d, d.reason
		end
	end
	if apbNeedleHit(haystack, { "silentheart" }) then
		if apbNeedleHit(haystack, { "light" }) then
			return { classes = { Light = true }, family = "SilentheartLight", reason = "specific-silentheart-class" }, "specific-silentheart-class"
		elseif apbNeedleHit(haystack, { "medium", "med" }) then
			return { classes = { Medium = true }, family = "SilentheartMedium", reason = "specific-silentheart-class" }, "specific-silentheart-class"
		elseif apbNeedleHit(haystack, { "heavy" }) then
			return { classes = { Heavy = true }, family = "SilentheartHeavy", reason = "specific-silentheart-class" }, "specific-silentheart-class"
		end
		return nil, "silentheart-unknown-class"
	end
	for _, d in next, APB_GENERIC_DESCRIPTORS do
		if apbNeedleHit(haystack, d.needles) then
			return d, d.reason
		end
	end
	if apbNeedleHit(haystack, { "weapontest", "weaponaerialattacktest", "weaponflourishtest", "weaponrunningattacktest", "weaponuppercuttest" }) then
		return APB_WEAPONTEST_DESCRIPTOR, APB_WEAPONTEST_DESCRIPTOR.reason
	end
	return nil, "unmapped"
end

-- ---- Weapon context (CR) via AttackOwnership -------------------------------
local function apbHasWeaponContext(ctx)
	return ctx and (ctx.weaponName or ctx.primaryWeapon or ctx.weaponClass or ctx.weaponType or ctx.weaponDamageType)
end
local function apbWeaponKeyOf(ctx)
	if not apbHasWeaponContext(ctx) then
		return nil
	end
	return table.concat({ tostring(ctx.weaponName or ctx.primaryWeapon or "unknown"), tostring(ctx.weaponClass or "unknown"), tostring(ctx.weaponType or "unknown") }, "|")
end
-- key-set membership (p1): does value normalize-match any key in set?
local function apbSetMatch(set, value)
	if not set or typeof(value) ~= "string" or value == "" then
		return false, false
	end
	local nv = apbNorm(value)
	if nv == "" then
		return false, false
	end
	for k in next, set do
		if nv == apbNorm(k) then
			return true, true
		end
	end
	return false, true
end
local function apbExactNameMatch(descriptor, ctx)
	local hay = table.concat({ apbNorm(ctx.primaryWeapon), apbNorm(ctx.weaponName) }, " ")
	if hay == "" then
		return nil, "missing-weapon-name"
	end
	for _, name in next, descriptor.exactNames or {} do
		local n = apbNorm(name)
		if n ~= "" and string.find(hay, n, 1, true) then
			return true, "exact-name"
		end
	end
	return false, "exact-name-conflict"
end
local function apbFamilyMatch(descriptor, ctx)
	if descriptor.classes and ctx.weaponClass then
		local ok = apbSetMatch(descriptor.classes, ctx.weaponClass)
		if ok then
			return true, "class"
		end
		return false, "class-conflict"
	end
	local okType, chkType = apbSetMatch(descriptor.types, ctx.weaponType)
	if okType then
		return true, "type"
	end
	local okDmg, chkDmg = apbSetMatch(descriptor.damageTypes, ctx.weaponDamageType)
	if okDmg then
		return true, "damage-type"
	end
	if chkType or chkDmg then
		return false, "family-conflict"
	end
	return nil, "missing-family-context"
end
-- Build a descriptor from the attacker's replicated weapon name when no static one maps (gu).
local function apbNamedWeaponDescriptor(timing, aid, ctx)
	if not ctx or ctx.status ~= "available" then
		return nil
	end
	local haystack = apbHaystack(timing, aid)
	local exact = {}
	local seen = {}
	for _, value in next, { ctx.primaryWeapon, ctx.weaponName } do
		local norm = apbNorm(value)
		if #norm >= 5 and string.find(haystack, norm, 1, true) and not seen[norm] then
			seen[norm] = true
			exact[#exact + 1] = value
		end
	end
	if #exact == 0 then
		return nil
	end
	return { exactNames = exact, family = ctx.weaponType or ctx.weaponClass or "NamedWeapon", reason = "replicated-weapon-name" }
end
local function CR(entity, timing, category, aid)
	if not entity then
		return { status = "unknown", reason = "no-entity" }
	end
	local player = players:GetPlayerFromCharacter(entity)
	if not player then
		return { status = "not-applicable", reason = "npc" }
	end
	if not RA(category) then
		return { status = "not-applicable", reason = "non-weapon-timing" }
	end
	local descriptor, reason = qM(timing, category, aid)
	local out = { status = "unknown", reason = reason, timingWeaponFamily = descriptor and descriptor.family or nil }
	local ctx = AttackOwnership.weaponContext(player)
	if not ctx then
		return { status = "unknown", reason = "weapon-context-read-failed", expectedDescriptor = descriptor }
	end
	for k, v in next, ctx do
		out[k] = v
	end
	out.status = "unknown"
	out.reason = ctx.status == "available" and reason or (ctx.reason or "weapon-context-unknown")
	out.expectedDescriptor = descriptor
	if ctx.status ~= "available" or not apbHasWeaponContext(ctx) then
		return out
	end
	if not descriptor then
		descriptor = apbNamedWeaponDescriptor(timing, aid, ctx)
		if not descriptor then
			out.reason = reason or "unmapped"
			return out
		end
		reason = descriptor.reason
		out.expectedDescriptor = descriptor
		out.timingWeaponFamily = descriptor.family
		out.reason = reason
	end
	local exactType, checkedType = apbSetMatch(descriptor.types, ctx.weaponType)
	out.exactWeaponTypeMatch = exactType == true
	out.exactWeaponTypeChecked = checkedType == true
	if descriptor.anyWeapon then
		out.status = "confirmed"
		out.reason = descriptor.reason or "any-weapon-context"
		return out
	end
	local ok, why
	if descriptor.exactNames then
		ok, why = apbExactNameMatch(descriptor, ctx)
	else
		ok, why = apbFamilyMatch(descriptor, ctx)
	end
	if ok == true then
		out.status = "confirmed"
		out.reason = why
	elseif ok == false then
		out.status = "mismatch"
		out.reason = why
	else
		out.reason = why or out.reason
	end
	return out
end
-- Weapon key for the currently equipped weapon (C1).
local function C1(entity)
	local player = players:GetPlayerFromCharacter(entity)
	if not player then
		return nil
	end
	local ok, ctx = pcall(AttackOwnership.weaponContext, player)
	if not ok or not ctx or ctx.status ~= "available" then
		return nil
	end
	return apbWeaponKeyOf(ctx)
end

-- ---- Ownership (bM) -- exact tool-descriptor DB (Cn) + GL + AttackOwnership --
-- Static tool-ownership descriptor table, keyed by module/timing name (1:1 from Katalyst's
-- ModuleManager). Maps a timing to the tool(s) the attacker must own for the attack to be real.
local APB_OWNERSHIP_DESCRIPTORS = {
	AirForce = { label = "Mantra:BlastWind{{Air Force}}", names = { "Mantra:BlastWind{{Air Force}}" } },
	BurningServants = { label = "Burning/Frozen Servants", contains = { "SquadFire", "SquadIce" } },
	ChainPull = { label = "Mantra:StreamMetal{{Chain Pull}}", names = { "Mantra:StreamMetal{{Chain Pull}}" } },
	FireEruption = { label = "Mantra:EruptionFire{{Fire Eruption}}", names = { "Mantra:EruptionFire{{Fire Eruption}}" } },
	FireForgeCast = { label = "Mantra:TrapWind{{Galetrap}}", names = { "Mantra:TrapWind{{Galetrap}}" } },
	FirePalm = { label = "Mantra:PalmFire{{Fire Palm}}", names = { "Mantra:PalmFire{{Fire Palm}}" } },
	FiringLine = { label = "Mantra:GunMetal{{Firing Line}}", names = { "Mantra:GunMetal{{Firing Line}}" } },
	FlameRepulsion = { label = "Mantra:RepulsionFire{{Flame Repulsion}}", names = { "Mantra:RepulsionFire{{Flame Repulsion}}" } },
	FlameRepulsionSpring = { label = "Mantra:RepulsionFire{{Flame Repulsion}}", names = { "Mantra:RepulsionFire{{Flame Repulsion}}" } },
	GaleHeroblade = { label = "Gale Hero Blade", names = { "Gale Hero Blade", "Gale Heroblade" }, contains = { "Gale Hero", "GaleHeroblade", "Gale Heroblade" } },
	IceBeam = { label = "Mantra:BeamIce{{Ice Beam}}", names = { "Mantra:BeamIce{{Ice Beam}}" } },
	IceCarve = { label = "Mantra:CarveIce{{Ice Carve}}", names = { "Mantra:CarveIce{{Ice Carve}}" } },
	IceEruption = { label = "Mantra:EruptionMetal{{Metal Eruption}}", names = { "Mantra:EruptionMetal{{Metal Eruption}}" } },
	IceHeroBlade = { label = "Ice Hero Blade", names = { "Ice Hero Blade", "Ice Heroblade" }, contains = { "Ice Hero", "IceHeroBlade", "Ice Heroblade" } },
	IronQuills = { label = "Mantra:PalmMetal{{Iron Quills}}", names = { "Mantra:PalmMetal{{Iron Quills}}" } },
	IronSlam = { label = "Mantra:SmashMetal{{Iron Slam}}", names = { "Mantra:SmashMetal{{Iron Slam}}" } },
	LightningAssault = { label = "Mantra:StrikeLightning{{Lightning Assault}}", names = { "Mantra:StrikeLightning{{Lightning Assault}}" } },
	LightningHerCrit = { label = "Lightning Hero Blade", names = { "Lightning Hero Blade", "Lightning Heroblade" }, contains = { "Lightning Hero", "LightningHeroBlade", "Lightning Heroblade" } },
	LightningStream = { label = "Mantra:StreamLightning{{Lightning Stream}}", names = { "Mantra:StreamLightning{{Lightning Stream}}" } },
	PressureBlast = { label = "Mantra:StrongPunchWeaponHeavy{{Pressure Blast}}", names = { "Mantra:StrongPunchWeaponHeavy{{Pressure Blast}}" } },
	RapidSlashes = { label = "Mantra:DashWeaponLight{{Rapid Slashes}}", names = { "Mantra:DashWeaponLight{{Rapid Slashes}}" } },
	Revenge = { label = "Mantra:RevengeAgility{{Revenge}}", names = { "Mantra:RevengeAgility{{Revenge}}" } },
	RisingFlame = { label = "Mantra:RisingSlashFire{{Rising Flame}}", names = { "Mantra:RisingSlashFire{{Rising Flame}}" } },
	RisingShadow = { label = "Mantra:RisingSlashShadow{{Rising Shadow}}", names = { "Mantra:RisingSlashShadow{{Rising Shadow}}" } },
	ShadowEruptionCast = { label = "Shadow Eruption/Chains", names = { "Mantra:EruptionShadow{{Shadow Eruption}}", "Mantra:RestraintShadow{{Shadow Chains}}" } },
	ShadowGun = { label = "Mantra:GunShadow{{Shadow Gun}}", names = { "Mantra:GunShadow{{Shadow Gun}}" } },
	ShadowRoar = { label = "Mantra:RoarShadow{{Shadow Roar}}", names = { "Mantra:RoarShadow{{Shadow Roar}}" } },
	WindCarve = { label = "Mantra:CarveWind{{Wind Carve}}", names = { "Mantra:CarveWind{{Wind Carve}}" } },
}
-- GL: resolve a timing to its ownership descriptor by trying smod, then name, then _id, then aid.
local function GL(timing, aid)
	local candidates = {}
	local function tryKey(value, label)
		if typeof(value) ~= "string" or value == "" or value == "N/A" then
			return nil
		end
		candidates[#candidates + 1] = label .. "=" .. value
		local descriptor = APB_OWNERSHIP_DESCRIPTORS[value]
		if descriptor then
			return descriptor, label .. "=" .. value
		end
	end
	local d, src = tryKey(timing and timing.smod, "smod")
	if not d then
		d, src = tryKey(timing and timing.name, "name")
	end
	if not d then
		d, src = tryKey(timing and timing._id, "_id")
	end
	if not d then
		d, src = tryKey(aid, "aid")
	end
	return d, src or "unmapped", table.concat(candidates, "|")
end
local function bM(entity, timing, aid)
	local player = players:GetPlayerFromCharacter(entity)
	if not player then
		return { status = "not-applicable", reason = "npc" }
	end
	local descriptor, source = GL(timing, aid)
	local result = AttackOwnership.toolOwnership(player, descriptor)
	result.mappingSource = source
	if descriptor == nil then
		result.reason = "unmapped"
	end
	return result
end

-- ---- Mantra store (sM) -----------------------------------------------------
-- Does the attacker's StoredAction / StoredToolName correspond to this timing?
local function apbTimingTokens(timing, aid)
	local out = {}
	local function add(s)
		local n = apbNorm(s)
		if n ~= "" then
			out[n] = true
		end
	end
	add(timing and timing.smod)
	add(timing and timing.name)
	add(timing and timing._id)
	add(aid)
	if typeof(timing and timing.name) == "string" then
		add(timing.name:match("{{(.-)}}"))
	end
	return out
end
local function sM(entity, timing, aid)
	if not entity then
		return { status = "unknown", reason = "no-entity" }
	end
	local storedAction = entity:GetAttribute("StoredAction")
	local storedTool = entity:GetAttribute("StoredToolName")
	local tokens = apbTimingTokens(timing, aid)
	local candidates = {}
	local function check(value)
		local n = apbNorm(value)
		if n == "" then
			return nil
		end
		candidates[#candidates + 1] = tostring(value)
		if tokens[n] then
			return n
		end
	end
	local key = check(storedAction) or check(storedTool)
	if key then
		return { status = "match", reason = "stored-mantra-match", key = key, storedAction = storedAction, storedTool = storedTool }
	end
	if #candidates > 0 then
		local mismatchKey = apbNorm(storedAction)
		if mismatchKey == "" then
			mismatchKey = apbNorm(storedTool)
		end
		return { status = "mismatch", reason = "stored-mantra-mismatch", key = mismatchKey, storedAction = storedAction, storedTool = storedTool }
	end
	return { status = "unknown", reason = "missing-stored-mantra", storedAction = storedAction, storedTool = storedTool }
end

-- ---- Ether tracking (ka/KI/vI) ---------------------------------------------
local function apbReadEther(inst)
	if not inst then
		return nil
	end
	local ok, value = pcall(function()
		return inst.Value
	end)
	if ok and type(value) == "number" then
		return value
	end
	return nil
end
function AnimatorDefender:_apbEtherUpdate(value, now)
	if type(value) ~= "number" then
		return
	end
	local prev = self._apEtherValue
	if prev ~= nil and value < prev - 0.01 then
		self._apEtherLastSpendAt = now
		self._apEtherLastSpendAmount = prev - value
		self._apEtherSpendSerial = (self._apEtherSpendSerial or 0) + 1
		self._apEtherClaimedSerial = nil
		self._apMantraIntentSerial = nil
		self:apMantraSpend(self._apEtherSpendSerial)
	end
	self._apEtherValue = value
	if not self._apEtherResolvedAt then
		self._apEtherResolvedAt = now
	end
end
function AnimatorDefender:_apbWatchEther(ether, now)
	if self._apEther == ether then
		return
	end
	if self._apEtherConn then
		pcall(function()
			self._apEtherConn:Disconnect()
		end)
		self._apEtherConn = nil
	end
	self._apEther = ether
	self._apEtherValue = nil
	self._apEtherResolvedAt = now
	if not ether then
		return
	end
	self:_apbEtherUpdate(apbReadEther(ether), now)
	self._apEtherConn = ether.Changed:Connect(function(v)
		self:_apbEtherUpdate((type(v) == "number") and v or apbReadEther(ether), os.clock())
	end)
	self.apMaid:add(self._apEtherConn)
end
---Resolve whether a mantra is backed by a recent ether spend (apme).
function AnimatorDefender:apme(timing, aid, now)
	local entity = self.entity
	local store = sM(entity, timing, aid)
	local ether = entity and entity:FindFirstChild("Ether")
	self:_apbWatchEther(ether, now)
	if not ether then
		return { status = "unknown", reason = "missing-ether" }
	end
	self:_apbEtherUpdate(apbReadEther(ether), now)
	if self._apEtherValue == nil then
		return { status = "unknown", reason = "unreadable-ether" }
	end
	if self._apEtherLastSpendAt then
		local age = now - self._apEtherLastSpendAt
		if age <= 1 then
			local serial = self._apEtherSpendSerial or 0
			local key = store.key or "unknown"
			local result = { value = self._apEtherValue, age = age, delta = self._apEtherLastSpendAmount, serial = serial, context = store.status, contextReason = store.reason, contextKey = key }
			if self._apEtherClaimedSerial == serial then
				result.status = "claimed"
				result.reason = "ether-spend-already-claimed"
				return result
			end
			if store.status == "mismatch" then
				result.status = "mismatch"
				result.reason = "stored-mantra-mismatch"
				return result
			end
			self._apEtherClaimedSerial = serial
			result.status = "spent"
			result.reason = store.status == "match" and "recent-ether-drop-matched" or "recent-ether-drop-unmatched"
			return result
		end
	end
	if self._apEtherResolvedAt and now - self._apEtherResolvedAt <= 0.2 then
		return { status = "unknown", reason = "fresh-ether-baseline", value = self._apEtherValue, context = store.status, contextReason = store.reason, contextKey = store.key }
	end
	return { status = "no-spend", reason = "no-recent-ether-drop", value = self._apEtherValue, context = store.status, contextReason = store.reason, contextKey = store.key }
end

-- ---- Real-hit geometry (apbh) ----------------------------------------------
function AnimatorDefender:apbh(timing)
	local root = self.entity and self.entity:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "no-root"
	end
	if not players.LocalPlayer.Character then
		return false, "no-local-character"
	end
	if not self:target(self.entity) then
		return false, "not-target"
	end
	local firstAction = nil
	if timing.actions and timing.actions:count() > 0 then
		for _, a in next, timing.actions:get() do
			firstAction = a
			break
		end
	end
	local ok, options = pcall(function()
		return HitboxOptions.new(root, timing)
	end)
	if not ok or not options then
		return false, "no-options"
	end
	options.spredict = not timing.duih and not timing.dp
	options.ptime = self:fsecs(timing)
	options.action = firstAction
	options.entity = self.entity
	pcall(function()
		options:ucache()
	end)
	if self:hc(options, nil) then
		return true, "direct-hitbox"
	end
	if timing.duih then
		return false, "delay-until-hitbox"
	end
	if (timing.ffh or timing.pfh) and self:pfh(options) then
		return true, "facing-prediction"
	end
	if timing.phd and self:phd(timing, options) then
		return true, "past-position"
	end
	return false, "no-real-hit-evidence"
end

-- ---- History maintenance (capb) + record (rapb) ----------------------------
function AnimatorDefender:capb(now)
	if now < (self._apNextMaintenanceAt or 0) then
		return
	end
	self._apNextMaintenanceAt = now + 0.05
	for track, info in next, self._apActive do
		if not (track.IsPlaying and now - info.start <= 2) then
			if info.stopConn then
				pcall(function()
					info.stopConn:Disconnect()
				end)
				info.stopConn = nil
			end
			if info.suspicious and not info.shortRecorded and now - info.start <= 0.12 then
				self._apShortDurations[#self._apShortDurations + 1] = now
			end
			self._apActive[track] = nil
			self._apActiveCount = math.max(0, (self._apActiveCount or 1) - 1)
		end
	end
	apbPruneTimes(self._apGlobalHistory, now)
	apbPruneTimes(self._apShortDurations, now)
	apbPruneRecent(self._apRecentIds, now)
	for aid, list in next, self._apHistory do
		apbPruneTimes(list, now)
		if #list == 0 then
			self._apHistory[aid] = nil
		end
	end
end
function AnimatorDefender:rapb(track, aid, report, now)
	local category = report and report.category or "other"
	local hist = self._apHistory[aid]
	if not hist then
		hist = {}
		self._apHistory[aid] = hist
	end
	hist[#hist + 1] = now
	self._apGlobalHistory[#self._apGlobalHistory + 1] = now
	self._apRecentIds[#self._apRecentIds + 1] = { time = now, aid = aid, category = category }
	self._apLastKnownTime = now
	apbPruneTimes(hist, now)
	apbPruneTimes(self._apGlobalHistory, now)
	apbPruneRecent(self._apRecentIds, now)
	if report and (report.score or 0) >= 3 then
		if not self._apActive[track] then
			self._apActiveCount = (self._apActiveCount or 0) + 1
		end
		local info = { start = now, suspicious = true, aid = aid }
		self._apActive[track] = info
		info.stopConn = track.Stopped:Connect(function()
			local w = self._apActive[track]
			if not w or w ~= info then
				return
			end
			local t = os.clock()
			if info.suspicious and not info.shortRecorded and (t - info.start) <= 0.12 then
				info.shortRecorded = true
				self._apShortDurations[#self._apShortDurations + 1] = t
				apbPruneTimes(self._apShortDurations, t)
			end
			if info.stopConn then
				pcall(function()
					info.stopConn:Disconnect()
				end)
				info.stopConn = nil
			end
		end)
		self.apMaid:add(info.stopConn)
	end
end
local function apbActiveSuspicious(map)
	local n = 0
	for _, info in next, map do
		if info.suspicious then
			n = n + 1
		end
	end
	return n
end

-- ---- Heuristic classifier (aapb) -- exact ----------------------------------
function AnimatorDefender:aapb(track, timing, aid, now)
	now = now or os.clock()
	self:capb(now)

	local isPlayer = players:GetPlayerFromCharacter(self.entity) ~= nil
	local tr, m4, iCount = 0, 0, 0
	local signals = {}
	local function t(points, reason)
		tr = tr + points
		iCount = iCount + 1
		signals[#signals + 1] = reason
	end
	local function oa(points)
		if points > 0 then
			m4 = m4 + points
		end
	end

	local ownership = bM(self.entity, timing, aid)
	local category = BA(timing)
	local weaponCtx = CR(self.entity, timing, category, aid)
	local mantraEther = nil
	local Gr = false
	local bt = false
	local NA = weaponCtx.status == "mismatch"
	local EA = weaponCtx.status == "confirmed"
	local zo = false
	local Tt = false

	if not isPlayer then
		oa(4)
	end
	if NA then
		t(4, "weapon-context-mismatch")
	elseif EA then
		oa(3)
	end
	if timing.umoa and (EA or ownership.status == "confirmed") then
		oa(2)
	end

	if isPlayer and category == "mantra" then
		mantraEther = self:apme(timing, aid, now)
		if mantraEther.status == "spent" then
			zo = true
			oa(8)
		elseif mantraEther.status == "no-spend" then
			Gr = true
			t(8, "mantra-no-ether-spend")
		elseif mantraEther.status == "claimed" then
			Gr = true
			t(8, "mantra-ether-spend-claimed")
		elseif mantraEther.status == "mismatch" then
			Gr = true
			t(8, "mantra-ether-spend-mismatch")
		end
	end

	if ownership.status == "missing" then
		t(2, "ownership-missing")
	elseif ownership.status == "confirmed" then
		oa(4)
	end

	if timing.rpue then
		Tt = true
		oa(3)
	end
	if timing.duih then
		Tt = true
		if EA or ownership.status == "confirmed" or not isPlayer then
			oa(2)
		end
	end

	local wt = tonumber(track.WeightTarget) or 0
	local wc = tonumber(track.WeightCurrent) or 0
	local weight = wt > 0 and wt or wc
	local speed = tonumber(track.Speed) or 0
	local length = tonumber(track.Length) or 0
	local priority = track.Priority
	local lowWeight = false
	local badPriority = false
	local badSpeed = false
	local shortLen = false
	local blendGap = false
	local extremeSpeed = false

	if wt >= 1 and wc <= 0.01 then
		blendGap = true
		t(2, "high-target-zero-current")
	elseif wt >= 0.5 and wc <= 0.12 then
		blendGap = true
	end
	if wt > 0 and wt <= 0.05 then
		lowWeight = true
		t(1, "very-low-weight")
	elseif wt > 0 and wt <= 0.12 then
		lowWeight = true
		t(1, "low-weight")
	end
	if priority == Enum.AnimationPriority.Core then
		badPriority = true
		t(2, "core-priority")
	elseif priority == Enum.AnimationPriority.Idle then
		badPriority = true
		t(1, "idle-priority")
	end
	if speed >= 10 then
		badSpeed = true
		extremeSpeed = true
		t(4, "extreme-speed")
	elseif speed >= 3 then
		badSpeed = true
		t(2, "fast-speed")
	elseif speed > 0 and speed < 0.5 then
		badSpeed = true
		t(1, "slow-speed")
	end
	if length > 0 and length < 0.12 then
		shortLen = true
		t(2, "very-short-length")
	end
	if not track.IsPlaying then
		shortLen = true
		t(2, "not-playing")
	end

	local j3 = false
	if isPlayer and self:_apIsMobAnimation(track) then
		j3 = true
		t(5, "player-mob-animation")
	end

	local gap = nil
	if self._apLastKnownTime then
		gap = now - self._apLastKnownTime
		if gap < 0.05 then
			bt = true
			t(3, "tiny-gap")
		elseif gap < 0.12 then
			bt = true
			t(2, "short-gap")
		elseif gap < 0.3 then
			bt = true
			t(gap <= 0.28 and 2 or 1, "breaker-gap")
		end
	end

	local sameId = self._apHistory[aid]
	local sameCount = (sameId and #sameId or 0) + 1
	if sameCount >= 5 then
		t(3, "same-id-spam")
	elseif sameCount >= 3 then
		t(2, "same-id-repeat")
	end

	local globalCount = #self._apGlobalHistory + 1
	local seenIds = { [aid] = true }
	local seenCats = { [category] = true }
	local uniqueIds, uniqueCats = 1, 1
	for _, e in next, self._apRecentIds do
		if e.aid and not seenIds[e.aid] then
			seenIds[e.aid] = true
			uniqueIds = uniqueIds + 1
		end
		if e.category and not seenCats[e.category] then
			seenCats[e.category] = true
			uniqueCats = uniqueCats + 1
		end
	end
	local q = false
	if globalCount >= 8 then
		q = true
		t(3, "global-spam")
	elseif globalCount >= 5 then
		q = true
		t(2, "global-burst")
	elseif globalCount >= 3 then
		q = true
		t(2, "burst-pressure")
	end
	if globalCount >= 3 and uniqueIds >= 3 then
		q = true
		t(2, "rotating-id-burst")
	elseif globalCount >= 3 and uniqueIds >= 2 then
		q = true
		t(1, "rotating-id-pair")
	end
	if globalCount >= 3 and uniqueCats >= 2 then
		q = true
		t(2, "rotating-category-burst")
	end
	if bt and globalCount >= 2 and uniqueIds >= 2 then
		q = true
		t(2, "breaker-window-rotation")
	end
	if RA(category) and globalCount >= 3 and (uniqueIds >= 2 or uniqueCats >= 2) then
		q = true
		t(1, "weapon-rotation-pressure")
	end
	local activeSusp = apbActiveSuspicious(self._apActive)
	if activeSusp >= 4 then
		q = true
		t(2, "active-suspicious-limit")
	end
	local shortCount = #self._apShortDurations
	if shortCount >= 3 then
		q = true
		shortLen = true
		t(3, "stopped-track-pattern")
	elseif shortCount >= 1 and globalCount >= 2 then
		q = true
		shortLen = true
		t(2, "recent-short-stop")
	end

	local shapeSuspicious = lowWeight or badPriority or badSpeed or shortLen or blendGap
	local missing = ownership.status == "missing"
	local confirmedOwn = ownership.status == "confirmed"
	local Or = false
	local needsLegitimacy = isPlayer and (timing.tag == "Mantra" or timing.tag == "Critical" or timing.tag == "M1"
		or timing.tag == "Undefined" or timing.umoa or ownership.reason == "unmapped" or NA or RA(category))
	if needsLegitimacy and not confirmedOwn and not EA and (missing or NA or shapeSuspicious or q or bt) then
		Or = true
		if not missing then
			t(q and 3 or 2, "missing-attack-legitimacy")
		end
	end

	local hitPlausible = false
	if not zo then
		local geomOk, geomReason = self:apbh(timing)
		if geomOk then
			Tt = true
			hitPlausible = true
		elseif geomReason == "delay-until-hitbox" then
			Tt = true
		elseif isPlayer then
			t(3, "no-real-hit-evidence")
			t(2, "known-timing-without-hit")
		end
	end

	local realistic = not shapeSuspicious and track.IsPlaying and (weight <= 0 or weight >= 0.12)
		and (speed <= 0 or (speed >= 0.5 and speed <= 2.25))
	local notPlaying = not track.IsPlaying
	local ownedRealOrConfirmed = confirmedOwn or EA
	local moduleCtx = timing.rpue or (timing.duih and (ownedRealOrConfirmed or not isPlayer)) or (timing.umoa and ownedRealOrConfirmed)
	local n3 = moduleCtx and not q
	local realLegit = not Gr and (not isPlayer or zo or ownedRealOrConfirmed or n3)
	local breakerSignal = (bt and not ownedRealOrConfirmed) or (q and not ownedRealOrConfirmed)
	local cleanShape = realistic and not j3 and not extremeSpeed and not NA
	local ownedRealistic = isPlayer and cleanShape and Tt and not notPlaying and realLegit
	local strongReal = not Gr and (zo or not isPlayer or (cleanShape and Tt and (ownedRealOrConfirmed or (n3 and not bt))))
	local anyReal = not Gr and (strongReal or ownedRealistic or (isPlayer and cleanShape and Tt and not notPlaying and realLegit))
	local highSignals = iCount >= 3
	local burstShape = isPlayer and ((bt and (uniqueIds >= 2 or uniqueCats >= 2 or globalCount >= 3)) or (q and (uniqueIds >= 2 or uniqueCats >= 2)) or (shortCount >= 1 and globalCount >= 2) or activeSusp >= 4)
	local stackedBreaker = burstShape and not strongReal and not ownedRealOrConfirmed and not n3 and (Or or highSignals or tr >= 7)
	local likelyReal = ownedRealistic and not stackedBreaker
	local legitContext = anyReal and not stackedBreaker
	local fakeHard = isPlayer and not legitContext and (Gr or j3 or extremeSpeed or (notPlaying and Or and (shapeSuspicious or breakerSignal)) or (NA and (shapeSuspicious or breakerSignal or not Tt)))
	local fakeStacked = isPlayer and not legitContext and (stackedBreaker or (Or and highSignals and tr >= 7 and (shapeSuspicious or breakerSignal or not Tt or shortCount >= 3)))

	local tier = "Uncertain"
	if not isPlayer then
		tier = "Real"
	elseif strongReal then
		tier = "Real"
	elseif likelyReal then
		tier = "Likely Real"
	elseif fakeHard then
		tier = "Fake"
	elseif fakeHard or fakeStacked then
		tier = "Likely Fake"
	elseif legitContext then
		tier = "Likely Real"
	elseif tr > 0 or Or or q then
		tier = "Suspicious"
	end

	local block = fakeHard or fakeStacked
	local decision = block and "BlockFakeOccurrence" or ((strongReal or likelyReal or legitContext) and "AllowReal" or "AllowUncertain")

	return {
		block = block,
		wouldBlock = block,
		decision = decision,
		tier = tier,
		score = tr,
		trust = m4,
		category = category,
		geometricPlausible = hitPlausible or Tt,
		signals = signals,
		raw = {
			category = category,
			hasBurstPattern = q,
			breakerTimer = bt,
			recentGlobal = globalCount,
			plausible = hitPlausible,
			geometricPlausibility = Tt and "plausible" or "none",
			mantraEtherStatus = mantraEther and mantraEther.status or "not-applicable",
			mantraEtherSerial = mantraEther and mantraEther.serial or nil,
			mantraEtherContext = mantraEther and mantraEther.context or "not-applicable",
			mantraEtherContextKey = mantraEther and mantraEther.contextKey or nil,
		},
	}
end

-- ---- Evidence builder (eu) + authenticator wiring --------------------------
local function apbFps()
	local ok, fps = pcall(function()
		return workspace:GetRealPhysicsFPS()
	end)
	if not ok or typeof(fps) ~= "number" or fps <= 0 then
		return 60
	end
	return math.max(15, fps)
end
-- Earliest action time of a timing, in seconds (Bu).
local function apbTimingDuration(timing)
	if not timing or not timing.actions or timing.actions:count() <= 0 then
		return nil
	end
	local best = nil
	for _, action in next, timing.actions:get() do
		local when = tonumber(action._when)
		if when and when >= 0 then
			local secs = when / 1000
			if best == nil or secs < best then
				best = secs
			end
		end
	end
	return best
end

function AnimatorDefender:apCandidateView(track, timing, aid, report, startedAt)
	local category = report.category
	local weaponCtx = CR(self.entity, timing, category, aid)
	local speed = math.abs(tonumber(track.Speed) or 0)
	local length = tonumber(track.Length) or 0
	local expected = speed > 0.0001 and length / speed or length
	local timingDur = apbTimingDuration(timing)
	local legal = tonumber(weaponCtx.weaponAttackDuration) or (expected > 0 and expected) or 2
	local reach = timingDur and math.max(0, timingDur - Latency.rdelay() - Latency.sdelay()) or legal
	local grace = math.max(2 / apbFps(), 0.02)
	local plannedDefense = startedAt + reach
	local deadline = startedAt + math.max(0, reach - grace)
	local raw = report.raw or {}
	local plausible = raw.plausible == true or (raw.geometricPlausibility ~= nil and raw.geometricPlausibility ~= "none")
	return {
		track = track,
		occurrence = self._apTrackOccurrences[track],
		timing = timing,
		aid = aid,
		category = category,
		weaponContext = weaponCtx,
		startedAt = startedAt,
		plannedDefenseAt = plannedDefense,
		deadlineAt = deadline,
		legalInterval = legal,
		longestTiming = math.max(legal, expected, reach or 0),
		expectedDuration = expected,
		evidenceLatencyMax = category == "weapon-critical" and 0.15 or 0.12,
		progressionGrace = grace,
		geometricPlausible = plausible,
		comboContinuous = true,
		actionKey = raw.mantraEtherContextKey,
		timingActionNames = { timing.name, timing.smod },
		classifierBlocked = report.block == true,
		callbackDispatchDeadlineAt = startedAt + grace,
		recoveredIngress = self._apRecoveredOccurrences[track] == self._apTrackOccurrences[track],
	}
end

-- ---- Ingress candidate resolve (rb) + quarantine (wb/sR) + recovery (XR) ----
apbResolveCandidate = function(self, track)
	local animation = track.Animation
	if not animation then
		return nil
	end
	-- Cached + canonicalized id: survives a later id="" blank and normalizes obfuscated ids
	-- (e.g. rbxhttp://...?id=garbage?id=12345&junk), matching the normal path.
	local aid = self:_apResolveAid(track)
	local timing = SaveManager.as:index(aid)
	if not timing or track.Priority == Enum.AnimationPriority.Core or not track.IsPlaying then
		return nil, aid
	end
	local speed = math.abs(tonumber(track.Speed) or 0)
	local weightTarget = tonumber(track.WeightTarget) or 0
	local timePos = tonumber(track.TimePosition) or 0
	if speed < 0.05 or speed > 4 or weightTarget <= 0.12 or weightTarget > 2 or timePos > 0.4 then
		return nil, aid
	end
	local distance = self:distance(self.entity)
	if not distance then
		return nil, aid
	end
	local minDist = timing.imdd
	if minDist <= 0.01 then
		minDist = 0
	end
	if distance < minDist or distance > apbMaxDist(timing) then
		return nil, aid
	end
	return timing, aid
end

apbQuarantine = function(self, track, timing, aid, startedAt)
	local category = BA(timing)
	local lane = apbLane(category)
	local byTrack = self._apQuarantineByTrack[lane]
	local slot = byTrack[track]
	local existed = slot ~= nil
	if not slot then
		local cursor = self._apQuarantineCursors[lane]
		slot = self._apQuarantine[apbLaneIndex(lane, cursor)]
		apbClearQuarantineSlot(self, slot)
		self._apQuarantineCursors[lane] = cursor % APB_QUARANTINE_LANE_SIZE + 1
		self._apQuarantineCount = math.min(APB_QUARANTINE_SIZE, (self._apQuarantineCount or 0) + 1)
		byTrack[track] = slot
	end
	slot.track = track
	slot.timing = timing
	slot.aid = aid
	slot.category = category
	slot.lane = lane
	slot.startedAt = startedAt
	IngressGuard.quarantineCandidate(existed)
	return not existed
end

apbPruneQuarantine = function(self, now, steps)
	local cursor = self._apQuarantinePruneCursor or 1
	for _ = 1, steps do
		local slot = self._apQuarantine[cursor]
		if slot.track and now - slot.startedAt > APB_QUARANTINE_TTL then
			apbClearQuarantineSlot(self, slot)
		end
		cursor = cursor % APB_QUARANTINE_SIZE + 1
	end
	self._apQuarantinePruneCursor = cursor
end

-- Score one quarantine slot against a piece of evidence; nil = incompatible (ages stale slots).
local function apbScoreQuarantineSlot(self, slot, evidence, at, latMin, latMax)
	local track = slot.track
	local startedAt = slot.startedAt
	if not track or not startedAt then
		return nil
	end
	local latency = at - startedAt
	if latency > APB_QUARANTINE_TTL then
		apbClearQuarantineSlot(self, slot)
		return nil
	end
	local actionOk = not evidence.actionKey or not evidence.requireTimingActionMatch
		or AttackAuthenticator.timingActionCompatible(
			{ timingActionNames = { slot.timing.name, slot.timing.smod } },
			evidence.actionKey,
			evidence.actionAliases
		)
	local occ = self._apOccurrenceStartedAt[track]
	if latency < latMin or latency > latMax or not apbFamilyCovers(slot.category, evidence) or not actionOk
		or (occ and occ.startedAt >= startedAt - 0.0001) then
		return nil
	end
	local speed = math.abs(tonumber(track.Speed) or 0)
	local dur = speed > 0.0001 and (tonumber(track.Length) or 0) / speed or 0
	local evDur = tonumber(evidence.duration)
	local score = 0
	if evDur and dur > 0 then
		local err = math.abs(dur - evDur) / math.max(dur, evDur, 0.01)
		if err > 0.75 then
			return nil
		end
		score = (1 - err) * 8
	end
	local weaponCtx = CR(self.entity, slot.timing, slot.category, slot.aid)
	if evidence.weaponKey and weaponCtx.status == "mismatch" then
		return nil
	elseif weaponCtx.status == "confirmed" then
		score = score + 40
	end
	if evidence.exactFamily == slot.category then
		score = score + 100
	elseif evidence.families and evidence.families[slot.category] then
		score = score + 50
	end
	if (tonumber(track.WeightCurrent) or 0) > 0.12 then
		score = score + 20
	end
	if (tonumber(track.TimePosition) or 0) > 0.0001 then
		score = score + 10
	end
	if latency >= (tonumber(evidence.centralLatencyMin) or latMin) and latency <= (tonumber(evidence.centralLatencyMax) or latMax) then
		score = score + 10
	end
	return score + startedAt * 0.000001
end

apbRecoverIngress = function(self, evidence)
	local at = tonumber(evidence.at) or os.clock()
	local latMin = tonumber(evidence.latencyMin) or -0.02
	local latMax = math.min(tonumber(evidence.latencyMax) or APB_QUARANTINE_TTL, APB_QUARANTINE_TTL)
	local best, bestScore = nil, -math.huge
	for i = 1, APB_QUARANTINE_SIZE do
		local slot = self._apQuarantine[i]
		local score = apbScoreQuarantineSlot(self, slot, evidence, at, latMin, latMax)
		if score and score > bestScore then
			best = slot
			bestScore = score
		end
	end
	if not best then
		return nil
	end
	local track = best.track
	local timing = best.timing
	local startedAt = best.startedAt
	apbClearQuarantineSlot(self, best)
	for i = 1, APB_QUARANTINE_SIZE do
		local slot = self._apQuarantine[i]
		if slot.track == track and slot.startedAt and slot.startedAt <= startedAt then
			apbClearQuarantineSlot(self, slot)
		end
	end
	local occ = (self._apTrackOccurrences[track] or 0) + 1
	self._apTrackOccurrences[track] = occ
	self._apOccurrenceStartedAt[track] = { occurrence = occ, startedAt = startedAt }
	self._apRecoveredOccurrences[track] = occ
	IngressGuard.recoveredEvidence()
	self:apProcess(track, occ, timing, true)
	return self.apAuthenticator:getCandidate(track, occ)
end

-- recordAttackEvidence: family-bridge settle-defer + ingress recovery + authenticate.
function AnimatorDefender:apRecordEvidence(evidence)
	if not self.apAuthenticator or not self.apAdvancedEnabled or not self._isFromPlayer then
		return nil, "inactive"
	end
	if evidence.allowWeaponFamilyBridge and not evidence.candidateSetSettled then
		local copy = {}
		for k, v in next, evidence do
			copy[k] = v
		end
		copy.candidateSetSettled = true
		local generation = self.apEvidenceGeneration
		local settle = math.max(2 / apbFps(), 0.02)
		task.delay(settle, function()
			if self.apAdvancedEnabled and self.apTrackingActive and self.apEvidenceGeneration == generation then
				self:apRecordEvidence(copy)
			end
		end)
		return nil, "candidate-settle-pending"
	end
	if evidence.authoritative and not evidence.causalCandidateId and apbRecoverIngress then
		if evidence._ingressRecoveryAdmitted == nil then
			local owner = self._playerOwner or players:GetPlayerFromCharacter(self.entity)
			evidence._ingressRecoveryAdmitted = owner == nil or IngressGuard.admitRecovery(owner)
		end
		if evidence._ingressRecoveryAdmitted then
			local recovered = apbRecoverIngress(self, evidence)
			if recovered then
				evidence.causalCandidateId = recovered.id
				evidence.causalTrack = recovered.track
				evidence.causalOccurrence = recovered.occurrence
			end
		end
	end
	local candidate, reason = self.apAuthenticator:recordEvidence(evidence)
	if not candidate then
		return nil, reason
	end
	task.defer(function()
		if self.apAuthenticator
			and self.apAuthenticator:isAuthenticated(candidate.track, candidate.occurrence)
			and candidate.track.IsPlaying then
			self:apProcess(candidate.track, candidate.occurrence, nil, false)
		end
	end)
	return candidate, reason
end

-- xA: on an ether spend, if StoredAction+StoredToolName present, record mantra intent.
function AnimatorDefender:apMantraSpend(serial)
	if not self.apAdvancedEnabled or self._apMantraIntentSerial == serial then
		return
	end
	if (self._apEtherSpendSerial or 0) ~= serial then
		return
	end
	local action = apbNorm(self.entity:GetAttribute("StoredAction"))
	local tool = self.entity:GetAttribute("StoredToolName")
	if action == "" or action == "criticalattack" or typeof(tool) ~= "string" or tool == "" then
		return
	end
	local spendAt = self._apEtherLastSpendAt
	if not spendAt or os.clock() - spendAt > 1 then
		return
	end
	self._apMantraIntentSerial = serial
	local grace = math.max(2 / apbFps(), 0.04)
	self:apRecordEvidence({
		kind = "replicated-mantra-intent", at = spendAt, authoritative = true, retainForFutureCandidate = true,
		exactFamily = "mantra", families = { mantra = true }, actionKey = action, actionAliases = apbActionAliases(self.entity),
		requireTimingActionMatch = true,
		latencyMin = -1, latencyMax = 0.25, centralLatencyMin = -grace, centralLatencyMax = grace, uncertainty = grace, serial = serial,
	})
end

function AnimatorDefender:apQueueMantraEvidence(candidate, report)
	local raw = report and report.raw
	if not raw or candidate.category ~= "mantra" then
		return
	end
	local serial = tonumber(raw.mantraEtherSerial)
	local key = raw.mantraEtherContextKey
	if not serial or not key or raw.mantraEtherContext ~= "match" or raw.mantraEtherStatus ~= "spent" then
		return
	end
	if self._apQueuedMantraEvidence[serial] then
		return
	end
	local entry = { serial = serial, key = key, track = candidate.track, occurrence = candidate.occurrence, candidateId = candidate.id }
	self._apQueuedMantraEvidence[serial] = entry
	task.delay(0.04, function()
		if self._apQueuedMantraEvidence[serial] ~= entry or not self.apAdvancedEnabled then
			return
		end
		self._apQueuedMantraEvidence[serial] = nil
		local live = self.apAuthenticator:getCandidate(entry.track, entry.occurrence)
		if live ~= candidate or live.status ~= "pending" then
			return
		end
		self:apRecordEvidence({
			kind = "replicated-mantra-ether-action", at = os.clock(), authoritative = true, exactFamily = "mantra",
			families = { mantra = true }, actionKey = key,
			latencyMin = -0.05, latencyMax = 0.25, centralLatencyMin = -0.02, centralLatencyMax = 0.12, uncertainty = 0.04,
			causalCandidateId = entry.candidateId, causalTrack = entry.track, causalOccurrence = entry.occurrence,
		})
	end)
end

-- ---- Weapon-sound producer (Tu/au/SL/V1/Ny/LA) ------------------------------
local function apbAncestorModelOrPart(inst)
	return inst:FindFirstAncestorWhichIsA("Model") or inst:FindFirstAncestorWhichIsA("BasePart")
end
-- nR: is `container` weld/joint-connected to the attacker (owns the thrown weapon)?
local function apbOwnsContainer(entity, container)
	if not entity or not container or not container.Parent then
		return false
	end
	local function related(a, b)
		return a == b or a:IsDescendantOf(b)
	end
	local function jointLinks(joint)
		if not (joint:IsA("JointInstance") or joint:IsA("WeldConstraint")) then
			return false
		end
		local p0, p1 = joint.Part0, joint.Part1
		return p0 ~= nil and p1 ~= nil
			and ((related(p0, entity) and related(p1, container)) or (related(p1, entity) and related(p0, container)))
	end
	if jointLinks(container) then
		return true
	end
	local scanned = 0
	for _, d in next, container:GetDescendants() do
		scanned = scanned + 1
		if jointLinks(d) then
			return true
		end
		if scanned >= 256 then
			break
		end
	end
	return false
end
-- Tu: find the single matching pending weapon candidate for a sound.
function AnimatorDefender:_apFindWeaponSoundCandidate(now, weaponKey)
	local found = nil
	for _, c in next, self.apAuthenticator.candidates or {} do
		local age = now - c.startedAt
		if c.status == "pending" and RA(c.category) and c.weaponKey == weaponKey
			and c.weaponContext and c.weaponContext.status == "confirmed" and c.weaponContext.exactWeaponTypeMatch == true
			and age >= 0 and age <= 0.04 and now <= c.deadlineAt and c.track and c.track.IsPlaying then
			if found then
				return nil
			end
			found = c
		end
	end
	return found
end
function AnimatorDefender:_apWeaponSoundPlayed(sound, root)
	if not self.apAdvancedEnabled or not self.apTrackingActive or not self._isFromPlayer then
		return
	end
	if not sound:IsDescendantOf(root) or not apbOwnsContainer(self.entity, root) then
		return
	end
	local weaponKey = C1(self.entity)
	if not weaponKey then
		return
	end
	local now = os.clock()
	local candidate = self:_apFindWeaponSoundCandidate(now, weaponKey)
	if not candidate then
		return
	end
	local m1 = 0.04
	self:apRecordEvidence({
		kind = "replicated-weapon-sound", at = now, authoritative = true, retainForFutureCandidate = false,
		weaponKey = weaponKey, exactFamily = candidate.category, families = { [candidate.category] = true },
		requireExactWeaponType = true, latencyMin = 0, latencyMax = m1, centralLatencyMin = 0, centralLatencyMax = m1,
		uncertainty = m1, causalCandidateId = candidate.id, causalTrack = candidate.track, causalOccurrence = candidate.occurrence,
	})
end
function AnimatorDefender:_apBindWeaponSound(sound, root)
	if self._apWeaponSounds[sound] then
		return
	end
	self._apWeaponSounds[sound] = root
	self.apMaid:add(sound.Played:Connect(function()
		self:_apWeaponSoundPlayed(sound, root)
	end))
end
function AnimatorDefender:_apBindWeaponRoots(inst)
	if self._apWeaponSoundRoots[inst] then
		return true
	end
	if not inst or not inst.Parent or not apbOwnsContainer(self.entity, inst) then
		return false
	end
	local root = inst:IsA("Model") and inst or apbAncestorModelOrPart(inst)
	if not root or not apbOwnsContainer(self.entity, root) then
		return false
	end
	if self._apWeaponSoundRoots[root] then
		return true
	end
	self._apWeaponSoundRoots[root] = true
	self.apMaid:add(root.DescendantAdded:Connect(function(child)
		if child:IsA("Sound") then
			self:_apBindWeaponSound(child, root)
		end
	end))
	for _, d in next, root:GetDescendants() do
		if d:IsA("Sound") then
			self:_apBindWeaponSound(d, root)
		end
	end
	return true
end
function AnimatorDefender:_apRefreshWeaponSounds()
	if not self.apAdvancedEnabled or not self.entity or not self.entity.Parent then
		return
	end
	self._apNextWeaponSoundRefreshAt = os.clock() + 2
	local thrown = workspace:FindFirstChild("Thrown")
	local attach = thrown and thrown:FindFirstChild("Attach_" .. self.entity.Name)
	if attach then
		self:_apBindWeaponRoots(attach)
	end
end
function AnimatorDefender:_apClearWeaponSounds()
	self._apWeaponSounds = setmetatable({}, { __mode = "k" })
	self._apWeaponSoundRoots = setmetatable({}, { __mode = "k" })
	self._apNextWeaponSoundRefreshAt = 0
end

-- ---- Client-effect / attribute / root evidence producers -------------------
function AnimatorDefender:apce(name, data)
	if not self.apAdvancedEnabled or not self._isFromPlayer or typeof(name) ~= "string" or typeof(data) ~= "table" then
		return
	end
	local prop = data.prop
	if not apbOwnsProp(self, prop, data) then
		return
	end
	if typeof(prop) == "Instance" then
		self:_apBindWeaponRoots(prop)
	end
	local weaponKey = C1(self.entity)
	local now = os.clock()
	if name == "WeaponTrailOff" then
		local cancelled = self.apAuthenticator:cancelFromEvidence({ kind = "replicated-weapon-trail-off", at = now, weaponKey = weaponKey })
		for _, candidate in next, cancelled do
			self:cancelAuthenticatedOccurrence(candidate)
		end
		return
	end
	if name == "WeaponTrail" then
		self:apRecordEvidence({
			kind = "replicated-weapon-trail", at = now, authoritative = true, weaponKey = weaponKey,
			duration = tonumber(data and data.dur),
			families = { ["weapon-m1"] = true, ["weapon-critical"] = true, ["weapon-special"] = true },
			latencyMin = -0.02, latencyMax = 0.12, centralLatencyMin = -0.02, centralLatencyMax = 0.05, uncertainty = 0.02,
		})
	elseif name == "CriticalSwirl" then
		self:apRecordEvidence({
			kind = "replicated-critical-effect", at = now, authoritative = true, weaponKey = weaponKey,
			duration = tonumber(data and data.dur), exactFamily = "weapon-critical",
			families = { ["weapon-critical"] = true }, allowWeaponFamilyBridge = true,
			latencyMin = -0.08, latencyMax = 0.15, centralLatencyMin = -0.02, centralLatencyMax = 0.05, uncertainty = 0.02,
		})
	end
end
function AnimatorDefender:apae(attr)
	if not self.apAdvancedEnabled or not self._isFromPlayer then
		return
	end
	if attr == "StoredToolName" or attr == "PrimaryWeapon" or attr == "Weapon" then
		self:_apRefreshWeaponSounds()
		return
	end
	if attr ~= "StoredAction" then
		return
	end
	if (self._apEtherSpendSerial or 0) > 0 then
		self:apMantraSpend(self._apEtherSpendSerial)
	end
	if apbNorm(self.entity:GetAttribute("StoredAction")) ~= "criticalattack" then
		return
	end
	self:apRecordEvidence({
		kind = "replicated-stored-critical", at = os.clock(), authoritative = true, weaponKey = C1(self.entity),
		exactFamily = "weapon-critical", families = { ["weapon-critical"] = true }, allowWeaponFamilyBridge = true,
		latencyMin = -0.08, latencyMax = 0.15, centralLatencyMin = -0.02, centralLatencyMax = 0.05, uncertainty = 0.02,
	})
end
function AnimatorDefender:apcr(child)
	if not self.apAdvancedEnabled or not self._isFromPlayer then
		return
	end
	local hrp = self.entity and self.entity:FindFirstChild("HumanoidRootPart")
	if not hrp or child.Parent ~= hrp then
		return
	end
	local now = os.clock()
	local paired = false
	if child:IsA("AudioPlayer") or child:IsA("Sound") then
		self._apRootAudioAt = now
		paired = self._apRootAttachmentAt ~= nil and now - self._apRootAttachmentAt <= 0.05
	elseif child:IsA("Attachment") then
		self._apRootAttachmentAt = now
		paired = self._apRootAudioAt ~= nil and now - self._apRootAudioAt <= 0.05
	else
		return
	end
	if not paired then
		return
	end
	local action = apbNorm(self.entity:GetAttribute("StoredAction"))
	local weaponKey = C1(self.entity)
	if action ~= "criticalattack" then
		if action == "" then
			return
		end
		if self._apMantraRootClaimedAction == action and self._apMantraRootClaimedUntil and now <= self._apMantraRootClaimedUntil then
			return
		end
		local recorded = self:apRecordEvidence({
			kind = "replicated-mantra-root-action-pair", at = now, authoritative = true, retainForFutureCandidate = true,
			exactFamily = "mantra", families = { mantra = true }, actionKey = action, actionAliases = apbActionAliases(self.entity),
			requireTimingActionMatch = true,
			latencyMin = -1, latencyMax = 0.25, centralLatencyMin = -0.02, centralLatencyMax = 0.12, uncertainty = 0.05,
		})
		if recorded then
			self._apMantraRootClaimedAction = action
			self._apMantraRootClaimedUntil = recorded.startedAt + math.max(recorded.behaviorWindow or 0, recorded.legalInterval or 0)
		end
		return
	end
	local recorded = self:apRecordEvidence({
		kind = "replicated-critical-root-pair", at = now, authoritative = true, weaponKey = weaponKey,
		exactFamily = "weapon-critical", families = { ["weapon-critical"] = true }, allowWeaponFamilyBridge = true,
		latencyMin = -0.08, latencyMax = 0.15, centralLatencyMin = 0, centralLatencyMax = 0.08, uncertainty = 0.05,
	})
	if recorded then
		return
	end
	if self.apAuthenticator and self.apAuthenticator.floodActive then
		return
	end
	-- Vestigial critical-pending confirmation (the pending set is not populated in this build).
	for track, info in next, self._apCriticalPending do
		if self._apTrackOccurrences[track] == info.occurrence and now - info.startedAt <= 0.08 then
			self._apCriticalPending[track] = nil
			self._apCriticalConfirmed[track] = info
			self._apCriticalConfirmedSources[track] = "replicated-root-event"
			task.defer(function()
				if self._apTrackOccurrences[track] == info.occurrence and track.IsPlaying then
					self:apProcess(track, info.occurrence)
				end
			end)
			return
		end
	end
end

-- ---- Ingress generation sync -----------------------------------------------
function AnimatorDefender:syncIngressGeneration()
	local gen = IngressGuard.generation()
	if self._apIngressGeneration == gen then
		return
	end
	self._apIngressGeneration = gen
	if self.apAuthenticator then
		for _, candidate in next, self.apAuthenticator.candidates or {} do
			if candidate.status == "pending" or candidate.status == "authenticated" then
				self:cancelAuthenticatedOccurrence(candidate)
			end
		end
		self.apAuthenticator:reset("ingress-reset")
	end
	self._apTrackOccurrences = setmetatable({}, { __mode = "k" })
	self._apOccurrenceStartedAt = setmetatable({}, { __mode = "k" })
	self._apScheduledOccurrences = setmetatable({}, { __mode = "k" })
	self._apMantraRootClaimedAction = nil
	self._apMantraRootClaimedUntil = nil
	apbInitQuarantine(self)
	self.apEvidenceGeneration = (self.apEvidenceGeneration or 0) + 1
end

-- ---- Animation-id cache -----------------------------------------------------
-- Capture a track's (canonical) animation id the first moment it's non-empty -- i.e. at the play
-- instant -- and reuse it forever. The blank-id breaker wipes track.Animation.AnimationId to ""
-- AFTER the attack starts, so a later (deferred) re-read would see nothing; the cache preserves the
-- real id we already saw. Falls back to the live/canonical id until a real one is captured. Weak
-- keys let dead tracks clean themselves.
---@param track AnimationTrack
---@return string
function AnimatorDefender:_apResolveAid(track)
	local animation = track and track.Animation
	local live = canonicalAid(tostring(animation and animation.AnimationId or ""))
	if live ~= "" then
		self._apAidCache[track] = live
		return live
	end
	return self._apAidCache[track] or live
end

-- Is this track a mob animation being played by a player (a fake/exploit)? Uses the cached id so a
-- blanked or obfuscated id still matches the mob-animation set, then falls back to the live id --
-- so it strictly ADDS coverage over the old raw-id lookup, never removes any.
---@param track AnimationTrack
---@return boolean
function AnimatorDefender:_apIsMobAnimation(track)
	local cached = self:_apResolveAid(track)
	if cached ~= "" and self.manimations[cached] ~= nil then
		return true
	end
	local animation = track.Animation
	local live = animation and animation.AnimationId
	return live ~= nil and self.manimations[live] ~= nil
end

-- ---- Occurrence bookkeeping -------------------------------------------------
function AnimatorDefender:isOccurrenceCurrent(track, occurrence)
	return occurrence == nil or self._apTrackOccurrences[track] == occurrence
end

-- Claim the defense schedule for one occurrence exactly once.
function AnimatorDefender:claimOccurrenceSchedule(track, occurrence)
	if not occurrence then
		return true
	end
	if self._apScheduledOccurrences[track] == occurrence then
		return false
	end
	self._apScheduledOccurrences[track] = occurrence
	return true
end

-- Cancel any scheduled tasks belonging to a (now counter-evidenced) occurrence.
function AnimatorDefender:cancelAuthenticatedOccurrence(candidate)
	if not candidate then
		return
	end
	for idx, atask in next, self.tasks do
		if atask.sourceTrack == candidate.track and atask.sourceOccurrence == candidate.occurrence then
			local thread = atask.thread
			if not thread or coroutine.status(thread) ~= "dead" then
				atask:cancel()
			end
			self.tasks[idx] = nil
			if atask.identifier == "End Block" or atask.identifier == "Start Block" then
				QueuedBlocking.stop("Defender_StartBlock")
			end
		end
	end
end

-- Occurrence-aware clean: on an "AllowUncertain" allow, preserve tasks belonging to a
-- different, still-current, still-playing track; otherwise fall through to a full clean.
function AnimatorDefender:cleanForOccurrence(track, report)
	local preserve = self.apAdvancedEnabled and report and report.decision == "AllowUncertain"
	if not preserve then
		return self:clean()
	end
	self.keyframes = {}
	for idx, atask in next, self.tasks do
		local keep = false
		if atask.forced and atask.identifier ~= "Start Block" and atask.identifier ~= "End Block" then
			keep = true
		elseif atask.identifier == "Start Crouch" or atask.identifier == "End Crouch"
			or atask.identifier == "Start Slide" or atask.identifier == "End Slide" then
			keep = true
		else
			local src = atask.sourceTrack
			local thread = atask.thread
			if src and src ~= track and self:isOccurrenceCurrent(src, atask.sourceOccurrence)
				and src.IsPlaying and (not thread or coroutine.status(thread) ~= "dead") then
				keep = true
			end
		end
		if not keep then
			atask:cancel()
			self.tasks[idx] = nil
			if atask.identifier == "End Block" or atask.identifier == "Start Block" then
				QueuedBlocking.stop("Defender_StartBlock")
			end
		end
	end
end

-- Lightweight pre-validation gate (pvalidate). When armed, defers to the classifier's block
-- decision; otherwise applies coarse priority/weight/speed sanity checks.
function AnimatorDefender:pvalidate(track, timing, report)
	if self.apAdvancedEnabled and timing then
		return not (report and report.block)
	end
	if track.Priority == Enum.AnimationPriority.Core then
		return false
	end
	if self._isFromPlayer and track.WeightTarget <= 0.05 then
		return false
	end
	if self._isFromPlayer and self:_apIsMobAnimation(track) then
		return false
	end
	if track.Speed >= 1000 then
		return false
	end
	return true
end

-- ---- Crasher-protection ingress gate (rlimit) ------------------------------
-- Returns (admitted, timing?, recovered?). Rate-limits suspicious animation ingress per player
-- and globally; quarantines rate-limited attack candidates so authoritative evidence can recover
-- them, and sheds pure overflow. Only meaningful for player attackers while armed.
function AnimatorDefender:rlimit(track)
	self:syncIngressGeneration()
	if not self._isFromPlayer then
		return true, nil, false
	end
	local owner = self._playerOwner or players:GetPlayerFromCharacter(self.entity)
	if not owner then
		return true, nil, false
	end
	self._playerOwner = owner
	local admitted, reason, underPressure = IngressGuard.admitSuspicious(owner)
	if admitted and not underPressure then
		return true, nil, false
	end
	local priority = track.Priority
	local isAction = priority == Enum.AnimationPriority.Action or priority == Enum.AnimationPriority.Action2
		or priority == Enum.AnimationPriority.Action3 or priority == Enum.AnimationPriority.Action4
	if underPressure and not isAction then
		IngressGuard.reject("universal-noncombat-priority")
		return false, nil, false
	end
	local timing, candidateId = apbResolveCandidate(self, track)
	if timing and candidateId then
		local candidateOk, candidateReason = IngressGuard.admitCandidate(owner, candidateId)
		if candidateOk then
			return true, timing, true
		end
		reason = candidateReason or reason
		if self.apAdvancedEnabled then
			local now = os.clock()
			local quarantinedNew = apbQuarantine(self, track, timing, candidateId, now)
			if quarantinedNew and self.apAuthenticator then
				local retained = self.apAuthenticator:retainedEvidenceForTiming({
					category = BA(timing), startedAt = now, timingActionNames = { timing.name, timing.smod },
				}, now)
				if retained then
					self:apRecordEvidence(retained)
				end
			end
			reason = "advanced-candidate-quarantine"
		end
	else
		reason = "untrusted-overflow"
	end
	IngressGuard.reject(reason)
	return false, nil, false
end

-- ---- Arm / disarm -----------------------------------------------------------
function AnimatorDefender:apArm(enabled)
	self._isFromPlayer = players:GetPlayerFromCharacter(self.entity) ~= nil
	if self._isFromPlayer then
		self._playerOwner = players:GetPlayerFromCharacter(self.entity)
	end
	enabled = enabled == true and self._isFromPlayer
	if self.apAdvancedEnabled == enabled then
		return
	end
	self.apAdvancedEnabled = enabled
	self.apTrackingActive = enabled

	if not enabled then
		if self.apAuthenticator then
			for _, candidate in next, self.apAuthenticator.candidates or {} do
				if candidate.status == "pending" or candidate.status == "authenticated" then
					self:cancelAuthenticatedOccurrence(candidate)
				end
			end
		end
		pcall(function()
			self.apMaid:clean()
		end)
		self:_apClearWeaponSounds()
		if self.apAuthenticator then
			self.apAuthenticator:reset("disarmed")
		end
		apbInitQuarantine(self)
		self._apScheduledOccurrences = setmetatable({}, { __mode = "k" })
		self._apOccurrenceStartedAt = setmetatable({}, { __mode = "k" })
		self.apEvidenceGeneration = (self.apEvidenceGeneration or 0) + 1
		self._apEther = nil
		self._apMantraRootClaimedAction = nil
		self._apMantraRootClaimedUntil = nil
		-- NOTE: loadout tracking is shared across defenders, so a single defender disarming
		-- must NOT disable it globally; it self-cleans on player removal and idles when unused.
		return
	end

	if not self.apAuthenticator then
		self.apAuthenticator = AttackAuthenticator.new()
	end
	AttackOwnership.init()
	AttackOwnership.setLoadoutTrackingActive(true)
	self:syncIngressGeneration()

	-- Ether watcher.
	self:_apbWatchEther(self.entity:FindFirstChild("Ether"), os.clock())

	-- Weapon-sound roots.
	self:_apRefreshWeaponSounds()

	-- ClientEffect remote -> apce (prop-ownership is checked inside apce).
	local requests = replicatedStorage:FindFirstChild("Requests")
	local clientEffect = requests and requests:FindFirstChild("ClientEffect")
	if clientEffect and (clientEffect:IsA("RemoteEvent") or clientEffect:IsA("UnreliableRemoteEvent")) then
		self.apMaid:add(clientEffect.OnClientEvent:Connect(function(effectName, data)
			self:apce(effectName, data)
		end))
	end

	-- Attribute evidence -> apae.
	self.apMaid:add(self.entity.AttributeChanged:Connect(function(attr)
		self:apae(attr)
	end))

	-- Root-pair + ether-instance evidence -> apcr.
	self.apMaid:add(self.entity.DescendantAdded:Connect(function(child)
		if child.Name == "Ether" then
			self:_apbWatchEther(child, os.clock())
		end
		self:apcr(child)
	end))
end

-- ---- AP-break detection notification (ported from Mira) ---------------------
-- Record one piece of AP-break evidence (a blocked fake occurrence). Purely informational:
-- flags the attacker after enough evidence in a short window and notifies the user. Never gates
-- the block decision itself -- that's already made by the classifier/authenticator.
local APB_EVIDENCE_WINDOW = 1.0       -- seconds of evidence history kept
local APB_EVIDENCE_THRESHOLD = 3      -- evidence events within the window to flag the attacker
local APB_FLAG_RESET_WINDOW = 10.0    -- clean seconds before the flag lifts
local APB_NOTIFY_COOLDOWN = 10.0      -- min seconds between notifications for one attacker
function AnimatorDefender:_apbEvidenceEvent()
	local now = os.clock()
	local ev = self._apbEvidence
	local writeIdx = 0
	for i = 1, #ev do
		if now - ev[i] <= APB_EVIDENCE_WINDOW then
			writeIdx = writeIdx + 1
			ev[writeIdx] = ev[i]
		end
	end
	for i = #ev, writeIdx + 1, -1 do
		ev[i] = nil
	end
	ev[writeIdx + 1] = now

	if writeIdx + 1 >= APB_EVIDENCE_THRESHOLD then
		self._apbFlagged = true
		self._apbFlaggedAt = now
		if Configuration.expectToggleValue("AntiBreakerNotify") then
			if not self._apbNotifiedAt or (now - self._apbNotifiedAt) > APB_NOTIFY_COOLDOWN then
				self._apbNotifiedAt = now
				local name = self.entity and self.entity.Name or "Someone"
				pcall(function()
					Library:Notify(string.format("%s is attempting to AP break you.", name), APB_NOTIFY_COOLDOWN)
				end)
			end
		end
	elseif self._apbFlagged and now - (self._apbFlaggedAt or 0) > APB_FLAG_RESET_WINDOW then
		self._apbFlagged = false
	end
end

-- ---- Advanced authenticator flow (process) ---------------------------------
-- @param track AnimationTrack
-- @param occurrence number Monotonic occurrence token for this track (from ingress/recovery).
-- @param timing AnimationTiming? Pre-resolved timing (from rlimit's candidate admission).
-- @param recovered boolean? Whether this occurrence was recovered from quarantine.
function AnimatorDefender:apProcess(track, occurrence, timing, recovered)
	if not self.apAdvancedEnabled or not self.apAuthenticator then
		return
	end
	self:syncIngressGeneration()

	occurrence = occurrence or self._apTrackOccurrences[track]
	local occurrenceAuthed = self.apAuthenticator:isAuthenticated(track, occurrence)
	if not self:isOccurrenceCurrent(track, occurrence) and not occurrenceAuthed then
		return
	end

	local occInfo = self._apOccurrenceStartedAt[track]
	local startedAt = (occInfo and occInfo.occurrence == occurrence and occInfo.startedAt) or os.clock()

	if self._playerOwner == players.LocalPlayer or (players.LocalPlayer.Character and self.entity == players.LocalPlayer.Character) then
		return
	end

	if self._apNextWeaponSoundRefreshAt and os.clock() >= self._apNextWeaponSoundRefreshAt then
		self:_apRefreshWeaponSounds()
	end
	if (self._apQuarantineCount or 0) > 0 then
		apbPruneQuarantine(self, os.clock(), 8)
	end

	-- Cached + canonicalized id: survives a later id="" blank (captured at the play instant) and
	-- resolves obfuscated ids to their real timing (matches the normal path).
	local aid = self:_apResolveAid(track)
	local resolved = timing or SaveManager.as:index(aid)
	if resolved then
		local distance = self:distance(self.entity)
		local minDist = resolved.imdd
		if not minDist or minDist <= 0.01 then
			minDist = 0
		end
		local maxDist = apbMaxDist(resolved, tonumber(Configuration.expectOptionValue("AutoParryMaxDist")) or 28)
		if not distance or distance < minDist or distance > maxDist then
			resolved = nil
		end
	end
	if not resolved then
		return
	end

	IngressGuard.advancedEntered()
	local report = self:aapb(track, resolved, aid, os.clock())
	local view = self:apCandidateView(track, resolved, aid, report, startedAt)
	view.occurrence = occurrence
	local candidate, isNew, retried = self.apAuthenticator:observeCandidate(view)
	if retried and retried ~= candidate then
		task.defer(function()
			if self.apAuthenticator:isAuthenticated(retried.track, retried.occurrence) then
				self:apProcess(retried.track, retried.occurrence)
			end
		end)
	end
	if isNew then
		self:rapb(track, aid, report, startedAt)
		candidate.historyRecorded = true
		self:apQueueMantraEvidence(candidate, report)
	end

	local candidateAuthed = false
	if candidate.status == "authenticated" then
		candidateAuthed = self.apAuthenticator:isAuthenticated(track, occurrence)
	elseif candidate.status == "released" then
		-- provisional quiet-window release: allowed through
	elseif candidate.status == "pending" then
		if not candidate._releaseScheduled then
			candidate._releaseScheduled = true
			task.delay(math.max(0, candidate.provisionalUntil - os.clock()), function()
				if self._apTrackOccurrences[track] ~= occurrence
					or self.apAuthenticator:getCandidate(track, occurrence) ~= candidate then
					return
				end
				if self.apAuthenticator:releaseCandidate(candidate, os.clock()) and track.IsPlaying then
					self:apProcess(track, occurrence)
				end
			end)
		end
		return
	else
		return
	end

	if not Configuration.expectToggleValue("EnableAutoDefense") then
		return
	end
	IngressGuard.autoDefenderReached()

	-- Evidence override: an authenticated occurrence is trusted regardless of heuristics.
	if candidateAuthed then
		report.block = false
		report.wouldBlock = false
		report.decision = "AllowAuthenticatedEvidence"
		report.tier = "Real"
	end

	if not candidate.historyRecorded then
		self:rapb(track, aid, report, os.clock())
		candidate.historyRecorded = true
	end

	if report.block then
		self:_apbEvidenceEvent()
		return
	end
	if not self:pvalidate(track, resolved, report) then
		return
	end

	-- Schedule the defense exactly once for this occurrence.
	if candidateAuthed then
		if not self.apAuthenticator:claimSchedule(track, occurrence, os.clock()) then
			return
		end
	end
	if not self:claimOccurrenceSchedule(track, occurrence) then
		return
	end

	self._evaluationData[track] = { t = tick() }
	self._apStampTrack = track
	self._apStampOccurrence = occurrence
	-- Anti-breaker held this candidate through the ingress gate / quarantine / provisional
	-- window, so the cue is arriving late by (now - startedAt). Feed that elapsed delay into
	-- the auto-defender so both the cue lead (self.offset) and the hitbox extrapolation
	-- (fsecs) compensate. Clamp it so a long quarantine recovery can't over-lead the parry.
	local gateDelay = os.clock() - startedAt
	local gateCap = (resolved.pfht and resolved.pfht * 2) or 0.3
	gateDelay = math.clamp(gateDelay, 0, gateCap)
	self:processValidated(track, aid, gateDelay)
	self._apStampTrack = nil
	self._apStampOccurrence = nil
end

---@param self AnimatorDefender
---@param track AnimationTrack
-- Global cap on concurrent parry evaluations, ported from Project Rain's `tasks >= task_concurrency` guard.
-- Shared across EVERY AnimatorDefender instance (this is an upvalue, not per-self). Each AnimationPlayed
-- fires its handler on a fresh Luau fiber, and the evaluation below (apProcess / processValidated) yields
-- with task.wait through the parry timing -- so without a ceiling, an animation burst (crowded area, many
-- mobs, fast attacks) spawns an unbounded pile of suspended fibers that never drains, until the scheduler
-- can't allocate another stack and the client dies with "failed to spawn a fiber" (RSL - panic: ...Kernel).
-- The thread logs showed this exactly: count spiking into the thousands within a second in busy areas.
-- 25 matches PR's default; legit combat never approaches it, so no parries are lost in normal fights.
local MAX_CONCURRENT_EVALUATIONS = 25
local activeEvaluations = 0

AnimatorDefender.process = LPH_NO_VIRTUALIZE(function(self, track)
	if track.WeightTarget <= 0.050 and track.WeightCurrent <= 0.050 then
		return
	end

	local isLocalPlayer = players.LocalPlayer.Character and self.entity == players.LocalPlayer.Character

	if isLocalPlayer then
		self:asc(track)

		local aid = tostring(track.Animation.AnimationId)
		self:initial(self.entity, SaveManager.as, self.entity.Name, aid)

		return
	end

	do
		local localCharacter = players.LocalPlayer.Character
		local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
		local entityRoot = self.entity:FindFirstChild("HumanoidRootPart")
		if localRoot and entityRoot then
			if (localRoot.Position - entityRoot.Position).Magnitude > 200 then
				return
			end
		end
	end

	-- Resolve (and cache) the canonical id at the play instant. For the anti path this primes the
	-- per-track id cache with the real id before any deferred logic runs, so a later id="" blank
	-- can't erase it; for the normal path it's the same canonical value as before.
	local aid = self:_apResolveAid(track)

	-- Concurrency cap (ported from Project Rain). Everything above here is a cheap O(1) filter; from this
	-- point on we commit to an evaluation that yields through the parry timing on this handler's fiber. If
	-- too many are already in flight, drop this one instead of piling up another suspended fiber. Decrement
	-- after 1s like PR (evaluations resolve well under that), which bounds the live-fiber count.
	if activeEvaluations >= MAX_CONCURRENT_EVALUATIONS then
		return
	end
	activeEvaluations = activeEvaluations + 1
	task.delay(1, function()
		activeEvaluations = activeEvaluations - 1
	end)

	-- Anti-breaker: for player attackers, route through the crasher-protection ingress gate
	-- and the authenticator flow while the toggle is on. NPCs and the disabled state fall
	-- straight through to the normal path.
	local advanced = players:GetPlayerFromCharacter(self.entity) ~= nil
		and Configuration.expectToggleValue("AntiBreakerEnabled") == true
	self:apArm(advanced)
	if advanced then
		local admitted, admittedTiming, admittedRecovered = self:rlimit(track)
		if not admitted then
			return
		end
		local occurrence = (self._apTrackOccurrences[track] or 0) + 1
		self._apTrackOccurrences[track] = occurrence
		self._apOccurrenceStartedAt[track] = { occurrence = occurrence, startedAt = os.clock() }
		return self:apProcess(track, occurrence, admittedTiming, admittedRecovered)
	end

	self._evaluationData[track] = { t = tick() }
	self:processValidated(track, aid)
end)

---@param self AnimatorDefender
---@param track AnimationTrack
---@param aid string
---@param gateDelay number? Extra delay from ramp/judge gate to compensate in timing.
AnimatorDefender.processValidated = LPH_NO_VIRTUALIZE(function(self, track, aid, gateDelay)
	if self.track and self.track ~= track and not self:isFullyDead(self.track) then
		local currentEval = self._evaluationData[self.track]
		local incomingEval = self._evaluationData[track]
		if currentEval and incomingEval and incomingEval.t < currentEval.t then
			return
		end
	end

	---@type AnimationTiming?
	local timing = self:initial(self.entity, SaveManager.as, self.entity.Name, aid)

	---@note: Record playback data for visualizer/builder regardless of existing timing.
	if Configuration.expectToggleValue("ShowAnimationVisualizer") then
		self.pbdata[track] = PlaybackData.new(self.entity)
	end

	if not timing then
		return
	end

	if not underAnimationProcessCap() then
		return
	end

	if not Configuration.expectToggleValue("EnableAutoDefense") then
		return
	end

	local humanoidRootPart = self.entity:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	if timing.tag == "Critical" then
		timing.nbfb = true
		timing.ha = true
	end

	---@note: Clean up previous tasks that are still waiting or suspended because they're in a different track.
	self:clean()

	self.timing = timing
	self.track = track
	self.offset = Latency.rdelay() + (gateDelay or 0)
	self._gateDelay = gateDelay or 0

	self._feintedTrack = nil
	self._galeFeintTracks = nil

	self._respectFeint = not reactRoll(timing)

	local ed = self._evaluationData[track]
	self._trackPlayedAt = ed and ed.t or tick()

	self._trackStoppedAt = nil
	local stoppedSignal = Signal.new(track.Stopped)
	self.tmaid:add(stoppedSignal:connect("AnimatorDefender_TrackStopped", function()
		self._trackStoppedAt = os.clock()
	end))

	self._trackSeq = self._trackSeq + 1
	local mySeq = self._trackSeq

	if timing.umoa then
		return self:module(timing)
	end

	---@note: Start processing the timing. Add the actions if we're not RPUE.
	if not timing.rpue then
		return self:actions(timing)
	end

	local info = RepeatInfo.new(timing, Latency.rdelay(), self:uid(10))
	info.track = track
	self:srpue(self.entity, timing, info)
end)

---@param self AnimatorDefender
---@param reason string
---@param expectedTrack AnimationTrack?
function AnimatorDefender:_cancelFeintedTrack(reason, expectedTrack)
	if
		not self.track
		or (expectedTrack and expectedTrack ~= self.track)
		-- NOTE: do NOT require self.track to still be in GetPlayingAnimationTracks() here.
		-- A feint STOPS the attack track, so by the time the feint sound's Playing flips true the
		-- track has already left the playing set -- gating on that is what made react-to-feints
		-- never fire. `expectedTrack` (captured at cue time) is the real staleness guard.
		or tick() - (self._trackPlayedAt or 0) < FEINT_CUE_GRACE_PERIOD
		or (self.timing and self.timing.tag == "Mantra")
	then
		return
	end

	if LPH_OBFUSCATED then
		Logger.warn(
			"(%s) %s; cancelling running actions for '%s'.",
			self.entity.Name,
			reason,
			self.timing and self.timing.name or "?"
		)
	else
		Logger.warn(
			"(%s) [FeintDiag] clock=%.3f %s; cancelling running actions for '%s'.",
			self.entity.Name,
			os.clock(),
			reason,
			self.timing and self.timing.name or "?"
		)
	end

	self._feintedTrack = self.track
	self:clean()

	QueuedBlocking.stop("Defender_Deflect")
	QueuedBlocking.stop("Defender_BlockFallback")
end

function AnimatorDefender:clean()
	self.keyframes = {}

	Defender.clean(self)
end

---@param animator Animator
---@param manimations table<number, Animation>
---@return AnimatorDefender
function AnimatorDefender.new(animator, manimations)
	local entity = animator:FindFirstAncestorWhichIsA("Model")
	if not entity then
		return error(string.format("AnimatorDefender.new(%s) - no entity.", animator:GetFullName()))
	end

	local self = setmetatable(Defender.new(), AnimatorDefender)
	local animationPlayed = Signal.new(animator.AnimationPlayed)

	self.animator = animator
	self.manimations = manimations
	self.entity = entity

	self.track = nil
	self.timing = nil
	self.offset = nil
	self._gateDelay = 0

	self.keyframes = {}
	self.pbdata = {}
	self.rpbdata = {}
	self.sct = {}
	self.tsc = {}
	self.multiplier = {}

	self._evaluationData = {}

	-- Anti-breaker state (only used while armed via :apArm).
	self.apMaid = AntiBreakerMaid.new()
	self.apAuthenticator = nil
	self.apAdvancedEnabled = false
	self.apTrackingActive = false
	self._isFromPlayer = players:GetPlayerFromCharacter(entity) ~= nil
	self._playerOwner = players:GetPlayerFromCharacter(entity)
	self.apEvidenceGeneration = 0
	self._apTrackOccurrences = setmetatable({}, { __mode = "k" })
	self._apRecoveredOccurrences = setmetatable({}, { __mode = "k" })
	self._apOccurrenceStartedAt = setmetatable({}, { __mode = "k" })
	self._apScheduledOccurrences = setmetatable({}, { __mode = "k" })
	-- Per-track animation-id cache (see :_apResolveAid). Weak keys; never manually reset so a
	-- captured real id survives even across ingress generations.
	self._apAidCache = setmetatable({}, { __mode = "k" })
	self._apIngressGeneration = nil
	self._apWeaponSounds = setmetatable({}, { __mode = "k" })
	self._apWeaponSoundRoots = setmetatable({}, { __mode = "k" })
	self._apNextWeaponSoundRefreshAt = 0
	self._apHistory = {}
	self._apGlobalHistory = {}
	self._apRecentIds = {}
	self._apShortDurations = {}
	self._apActive = {}
	self._apActiveCount = 0
	self._apLastKnownTime = nil
	self._apNextMaintenanceAt = 0
	self._apQueuedMantraEvidence = {}
	self._apMantraIntentSerial = nil
	self._apMantraRootClaimedAction = nil
	self._apMantraRootClaimedUntil = nil
	self._apRootAudioAt = nil
	self._apRootAttachmentAt = nil
	self._apEther = nil
	self._apEtherValue = nil
	self._apEtherResolvedAt = nil
	self._apEtherLastSpendAt = nil
	self._apEtherLastSpendAmount = 0
	self._apEtherSpendSerial = 0
	self._apEtherClaimedSerial = nil
	self._apEtherConn = nil
	self._apOnEtherSpend = nil
	-- Vestigial critical/occurrence confirmation tables (present for 1:1 structure; the pending
	-- sets are not populated in this build, so their process/apcr reads stay nil).
	self._apCriticalPending = {}
	self._apCriticalConfirmed = {}
	self._apCriticalConfirmedSources = {}
	self._apStampTrack = nil
	self._apStampOccurrence = nil
	-- AP-break detection notification state (ported from Mira).
	self._apbEvidence = {}
	self._apbFlagged = false
	self._apbFlaggedAt = nil
	self._apbNotifiedAt = nil
	-- Quarantine ring + occurrence tables are lazily allocated on first arm (apArm ->
	-- syncIngressGeneration -> apbInitQuarantine), so an unarmed/NPC defender carries no
	-- anti-breaker overhead.
	self.maid:add(function()
		pcall(function()
			self.apMaid:clean()
		end)
	end)

	self._trackStoppedAt = nil

	self._trackPlayedAt = 0

	self._feintedTrack = nil
	self._feintPlayingConn = nil
	self._galeFeintTracks = nil
	self._respectFeint = true

	self.hits = {}
	self.maid:mark(entity.DescendantAdded:Connect(function(child)
		local isHitEffect = child.Name == "PunchBlood"
			or child.Name == "PunchEffect"
			or child.Name == "BloodSpray"
			or (child:IsA("ParticleEmitter") and child.Texture == "rbxassetid://7216855595")

		if not isHitEffect then
			return
		end

		local id = self:uid(1)
		self.hits[id] = true

		task.delay(0.2, function()
			self.hits[id] = nil
		end)
	end))

	self._feintConn = entity.DescendantAdded:Connect(function(child)
		if child.Name == "Feint" and child:IsA("Sound") then
			if self._feintPlayingConn then
				self._feintPlayingConn:Disconnect()
				self._feintPlayingConn = nil
			end

			local trackAtCue = self.track

			if child.IsPlaying then
				self:_cancelFeintedTrack("feint cue heard", trackAtCue)
			else
				self._feintPlayingConn = child:GetPropertyChangedSignal("Playing"):Connect(function()
					if not child.IsPlaying then
						return
					end

					self:_cancelFeintedTrack("feint cue heard", trackAtCue)
				end)

				self.maid:mark(self._feintPlayingConn)
			end

			return
		end

		if child.Name == "REP_SOUND_1241766316" then
			self._galeFeintTracks = animator:GetPlayingAnimationTracks()
			Logger.warn("(%s) Gale feint cue heard; snapshotted %d track(s).", entity.Name, #self._galeFeintTracks)
			return
		end

		local fakeStrike = child.Name == "REP_SOUND_5115545256" and tostring(child.PlaybackSpeed) == "2"
		if child.Name == "REP_SOUND_4954198253" or fakeStrike then
			self:_cancelFeintedTrack("fake strike cue heard", self.track)
		end
	end)
	self.maid:mark(self._feintConn)

	self._trackSeq = 0

	self.maid:mark(animationPlayed:connect(
		"AnimatorDefender_OnAnimationPlayed",
		LPH_NO_VIRTUALIZE(function(track)
			self:process(track)
		end)
	))

	return self
end

return AnimatorDefender
