
---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Game.Timings.SaveManager
local TimingStore = require("Game/Timings/SaveManager")

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PRIORITY_ORDER = {
	Enum.AnimationPriority.Core,
	Enum.AnimationPriority.Idle,
	Enum.AnimationPriority.Movement,
	Enum.AnimationPriority.Action,
	Enum.AnimationPriority.Action2,
	Enum.AnimationPriority.Action3,
	Enum.AnimationPriority.Action4,
}
local PRIORITY_INDEX = {}
for index, priority in ipairs(PRIORITY_ORDER) do
	PRIORITY_INDEX[priority] = index
end
local ACTION_INDEX = PRIORITY_INDEX[Enum.AnimationPriority.Action]
local BOOST_OFFSET = PRIORITY_INDEX[Enum.AnimationPriority.Action4] - PRIORITY_INDEX[Enum.AnimationPriority.Action]
local ACTION3_INDEX = PRIORITY_INDEX[Enum.AnimationPriority.Action3]
local ACTION4_INDEX = PRIORITY_INDEX[Enum.AnimationPriority.Action4]

local function boostPriority(priority)
	local index = PRIORITY_INDEX[priority] or ACTION4_INDEX
	return PRIORITY_ORDER[math.clamp(index + BOOST_OFFSET, ACTION3_INDEX, ACTION4_INDEX)]
end

local loadedTrackRegistry = setmetatable({}, { __mode = "k" })

local ApBreaker = { force = false }

local function getOption(name, fallback)
	local value = Configuration.expectOptionValue(name)
	if value == nil then
		return fallback
	end
	return value
end

local ANIM_LIMIT = 60
local function underAnimationLimit(animator)
	if Configuration.expectToggleValue("ApBreakerDontHitAnimLimit") == false then
		return true
	end
	if not animator then
		return true
	end
	local ok, playing = pcall(function() return animator:GetPlayingAnimationTracks() end)
	if not ok or type(playing) ~= "table" then
		return true
	end
	return #playing < ANIM_LIMIT
end

local FALLBACK_AGGRESSIVE2_ANIMATION_IDS = {
	"rbxassetid://9726608174",
	"rbxassetid://111647546998749",
	"rbxassetid://5064195992",
	"rbxassetid://6607519294",
	"rbxassetid://7600160919",
}
local AGGRESSIVE2_MOVE_TYPES = { M1 = true, Mantra = true, Critical = true }
local AGGRESSIVE2_PRIORITY = Enum.AnimationPriority.Action

local function collectKnownAttackAnimationIds()
	local ids, seen = {}, {}
	pcall(function()
		local list = TimingStore.as:list()
		for _, entry in ipairs(list) do
			if AGGRESSIVE2_MOVE_TYPES[entry.tag] then
				local id = entry:id()
				if type(id) == "string" and id:match("%d") and not seen[id] then
					seen[id] = true
					ids[#ids + 1] = id
				end
			end
		end
	end)
	return ids
end

local ULTIMATE_IDLE_COVER_ID = "rbxassetid://180435571"
local ULTIMATE_IDLE_FADE = 0.2
local ULTIMATE_COVER_REPLAY = 0.3

local function startUltimateMode(character)
	if not character then return function() end end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return function() end end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return function() end end

	local trackPool = {}
	local trackPoolSet = {}
	local poolSize = 0

	local stopped = false

	local function loadDecoyTracks(idList, spread)
		for _, track in next, trackPool do
			pcall(function() track:Stop(0); track:Destroy() end)
		end
		trackPool = {}
		trackPoolSet = {}
		poolSize = 0
		if type(idList) ~= "table" or #idList == 0 then return end

		local targetPoolSize = math.min(200, math.max(#idList, 20))
		local cursor, attempts, maxAttempts = 0, 0, targetPoolSize + #idList + 8
		while #trackPool < targetPoolSize and attempts < maxAttempts and not stopped do
			attempts = attempts + 1
			cursor = cursor % #idList + 1
			local id = idList[cursor]
			if not string.find(id, "://", 1, true) then
				id = "rbxassetid://" .. id
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
			if ok and track then
				loadedTrackRegistry[track] = true
				track.Looped = false
				trackPool[#trackPool + 1] = track
				trackPoolSet[track] = true
			end

			if spread and attempts % 20 == 0 then
				task.wait()
			end
		end
		poolSize = #trackPool

		if stopped then
			for _, track in next, trackPool do
				pcall(function() track:Stop(0); track:Destroy() end)
			end
		end
	end

	local knownIds = collectKnownAttackAnimationIds()
	local usingFallbackIds = false
	if #knownIds == 0 then
		knownIds = FALLBACK_AGGRESSIVE2_ANIMATION_IDS
		usingFallbackIds = true
	end
	loadDecoyTracks(knownIds)

	local maskTrack = nil
	local maskSet = {}
	do
		local animation = Instance.new("Animation")
		animation.AnimationId = ULTIMATE_IDLE_COVER_ID
		local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
		if ok and track then
			loadedTrackRegistry[track] = true
			track.Looped = true
			maskTrack = track
			maskSet[track] = true
		end
	end
	local lastMaskPlay = 0

	local running = true
	local aggressive2Accumulator = 0
	local poolCursor = 0
	local framesSinceCheck = 0
	local fallbackRefreshTimer = 0
	local lastPlayTime = os.clock()
	local originalPriorities = setmetatable({}, { __mode = "k" })
	local function detectRealAttack(maskVisualEnabled)
		local realAttackPlaying = false
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if trackPoolSet[track] then
				if track.Priority ~= AGGRESSIVE2_PRIORITY then
					pcall(function() track.Priority = AGGRESSIVE2_PRIORITY end)
				end
			elseif not maskSet[track] and not loadedTrackRegistry[track] and track.Animation and track.Animation.AnimationId then
				local savedPriority = originalPriorities[track]
				if savedPriority == nil then
					savedPriority = track.Priority
					originalPriorities[track] = savedPriority
				end
				local boosted = boostPriority(savedPriority)
				pcall(function() track.Priority = boosted end)
				if (PRIORITY_INDEX[boosted] or 0) > ACTION_INDEX and track.WeightCurrent > 0.5 then
					realAttackPlaying = true
				end
			end
		end
		if maskTrack and maskVisualEnabled then
			realAttackPlaying = true
		end
		return realAttackPlaying
	end

	local function restoreForeignPriorities()
		for track, priority in pairs(originalPriorities) do
			pcall(function() track.Priority = priority end)
		end
		originalPriorities = setmetatable({}, { __mode = "k" })
	end

	local renderSteppedConn
	renderSteppedConn = RunService.RenderStepped:Connect(function(deltaTime)
		if not running then return end
		if not character.Parent then
			running = false
			return
		end

		if usingFallbackIds then
			fallbackRefreshTimer = fallbackRefreshTimer + deltaTime
			if fallbackRefreshTimer >= 1.5 then
				fallbackRefreshTimer = 0
				local refreshed = collectKnownAttackAnimationIds()
				if #refreshed > 0 then
					usingFallbackIds = false
					task.spawn(loadDecoyTracks, refreshed, true)
				end
			end
		end

		if poolSize == 0 then return end

		local maskVisualEnabled = Configuration.expectToggleValue("ExpApBreakerMaskVisual") ~= false

		local shouldRunAggressive2 = true
		if maskVisualEnabled then
			shouldRunAggressive2 = detectRealAttack(maskVisualEnabled)
		elseif next(originalPriorities) ~= nil then
			restoreForeignPriorities()
		end

		if maskTrack then
			if maskVisualEnabled then
				local now = os.clock()
				if not maskTrack.IsPlaying then
					pcall(function()
						maskTrack.Priority = Enum.AnimationPriority.Action2
						maskTrack:Play(0, 1, 1)
					end)
					lastMaskPlay = now
				elseif now - lastMaskPlay >= ULTIMATE_COVER_REPLAY then
					lastMaskPlay = now
					pcall(function()
						local position = maskTrack.TimePosition
						maskTrack:Stop(0)
						maskTrack.Priority = Enum.AnimationPriority.Action2
						maskTrack:Play(0, 1, 1)
						maskTrack.TimePosition = position
					end)
				end
			elseif maskTrack.IsPlaying then
				pcall(function() maskTrack:Stop(ULTIMATE_IDLE_FADE) end)
			end
		end

		if maskVisualEnabled and not shouldRunAggressive2 then
			for _, track in next, trackPool do
				if track.IsPlaying then
					pcall(function() track:Stop(0) end)
				end
			end
			framesSinceCheck = 0
			aggressive2Accumulator = 0
			return
		end

		framesSinceCheck = framesSinceCheck + 1
		if maskVisualEnabled and framesSinceCheck < 3 then return end

		local intensity = getOption("ExpApBreakerAggressive2Intensity", 200)
		local interval = 1 / math.max(1, intensity)
		aggressive2Accumulator = math.min(aggressive2Accumulator + deltaTime, interval * 2)

		if not underAnimationLimit(animator) then
			return
		end

		local burstsThisFrame = 0
		while aggressive2Accumulator >= interval and burstsThisFrame < 50 do
			aggressive2Accumulator = aggressive2Accumulator - interval
			burstsThisFrame = burstsThisFrame + 1

			local chosenTrack = nil
			local fallbackZeroLenTrack = nil
			for _ = 1, poolSize do
				poolCursor = poolCursor % poolSize + 1
				local candidate = trackPool[poolCursor]
				if candidate and not candidate.IsPlaying then
					if candidate.Length > 0 then
						chosenTrack = candidate
						break
					elseif not fallbackZeroLenTrack then
						fallbackZeroLenTrack = candidate
					end
				end
			end
			if not chosenTrack and os.clock() - lastPlayTime > 8 then
				chosenTrack = fallbackZeroLenTrack
			end
			if chosenTrack then
				pcall(function()
					chosenTrack.Priority = AGGRESSIVE2_PRIORITY
					chosenTrack:Play(0.1, 1, 1)
				end)
				lastPlayTime = os.clock()
			end
		end
	end)

	return function()
		running = false
		stopped = true
		if renderSteppedConn then
			renderSteppedConn:Disconnect()
			renderSteppedConn = nil
		end
		restoreForeignPriorities()
		if maskTrack then
			pcall(function() maskTrack:Stop(0); maskTrack:Destroy() end)
			maskTrack = nil
		end
		for _, track in next, trackPool do
			pcall(function() track:Stop(0); track:Destroy() end)
		end
	end
end

local FADE_TIME_FLOOD_FADE = 99999
local FADE_TIME_FLOOD_PRIORITY = Enum.AnimationPriority.Action

local function startFadeTimeFloodMode(character)
	if not character then return function() end end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return function() end end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return function() end end

	local trackPool = {}
	local function destroyPool()
		for _, track in next, trackPool do
			pcall(function() track:Stop(0); track:Destroy() end)
		end
		trackPool = {}
	end

	local function loadPool(idList)
		destroyPool()
		if type(idList) ~= "table" or #idList == 0 then return end
		local targetSize = math.min(200, math.max(#idList, 20))
		local cursor, attempts, maxAttempts = 0, 0, targetSize + #idList + 8
		while #trackPool < targetSize and attempts < maxAttempts do
			attempts = attempts + 1
			cursor = cursor % #idList + 1
			local id = idList[cursor]
			if not string.find(id, "://", 1, true) then
				id = "rbxassetid://" .. id
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
			if ok and track then
				loadedTrackRegistry[track] = true
				track.Looped = false
				trackPool[#trackPool + 1] = track
			end
		end
	end

	local ids = collectKnownAttackAnimationIds()
	local usingFallback = false
	if #ids == 0 then
		ids = FALLBACK_AGGRESSIVE2_ANIMATION_IDS
		usingFallback = true
	end
	loadPool(ids)

	local running = true
	local accumulator = 0
	local poolCursor = 0
	local fallbackRefreshTimer = 0
	local renderConn
	renderConn = RunService.RenderStepped:Connect(function(deltaTime)
		if not running then return end
		if not character.Parent then
			running = false
			return
		end

		if usingFallback then
			fallbackRefreshTimer = fallbackRefreshTimer + deltaTime
			if fallbackRefreshTimer >= 1.5 then
				fallbackRefreshTimer = 0
				local refreshed = collectKnownAttackAnimationIds()
				if #refreshed > 0 then
					loadPool(refreshed)
					usingFallback = false
				end
			end
		end

		local poolSize = #trackPool
		if poolSize == 0 then return end

		local intensity = getOption("ExpApBreakerAggressive2Intensity", 200)
		local interval = 1 / math.max(1, intensity)
		accumulator = math.min(accumulator + deltaTime, interval * 2)

		if not underAnimationLimit(animator) then
			return
		end

		local burstsThisFrame = 0
		while accumulator >= interval and burstsThisFrame < 50 do
			accumulator = accumulator - interval
			burstsThisFrame = burstsThisFrame + 1

			local chosen = nil
			for _ = 1, poolSize do
				poolCursor = poolCursor % poolSize + 1
				local candidate = trackPool[poolCursor]
				if candidate and not candidate.IsPlaying then
					chosen = candidate
					break
				end
			end
			if chosen then
				pcall(function()
					chosen.Priority = FADE_TIME_FLOOD_PRIORITY
					chosen:Play(FADE_TIME_FLOOD_FADE, 1, 1)
				end)
			end
		end
	end)

	return function()
		running = false
		if renderConn then
			pcall(function() renderConn:Disconnect() end)
			renderConn = nil
		end
		destroyPool()
	end
end

local MONSTER_FLOOD_ID = "11710290503"
local MONSTER_FLOOD_ATTACK_SEED = 7600160919
local MONSTER_FLOOD_SLOT_BASE = 104824667
local MONSTER_FLOOD_POOL = 60
local MONSTER_FLOOD_PRIORITY = Enum.AnimationPriority.Action

local function startMonsterFloodMode(character)
	if not character then return function() end end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return function() end end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return function() end end

	local trackPool = {}
	local function destroyPool()
		for _, track in next, trackPool do
			pcall(function() track:Stop(0); track:Destroy() end)
		end
		trackPool = {}
	end

	local slot = MONSTER_FLOOD_SLOT_BASE
	local attempts = 0
	while #trackPool < MONSTER_FLOOD_POOL and attempts < MONSTER_FLOOD_POOL * 2 do
		attempts = attempts + 1
		local url = string.format(
			"https://www.roblox.com/asset/?attack=%d&slot=%d&id=%s",
			MONSTER_FLOOD_ATTACK_SEED, slot, MONSTER_FLOOD_ID
		)
		slot = slot + 1
		local animation = Instance.new("Animation")
		animation.AnimationId = url
		local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
		if ok and track then
			loadedTrackRegistry[track] = true
			track.Looped = false
			trackPool[#trackPool + 1] = track
		end
	end

	local running = true
	local accumulator = 0
	local poolCursor = 0
	local renderConn
	renderConn = RunService.RenderStepped:Connect(function(deltaTime)
		if not running then return end
		if not character.Parent then
			running = false
			return
		end
		local poolSize = #trackPool
		if poolSize == 0 then return end

		local intensity = getOption("ExpApBreakerAggressive2Intensity", 200)
		local interval = 1 / math.max(1, intensity)
		accumulator = math.min(accumulator + deltaTime, interval * 2)

		if not underAnimationLimit(animator) then
			return
		end

		local burstsThisFrame = 0
		while accumulator >= interval and burstsThisFrame < 50 do
			accumulator = accumulator - interval
			burstsThisFrame = burstsThisFrame + 1

			local chosen = nil
			for _ = 1, poolSize do
				poolCursor = poolCursor % poolSize + 1
				local candidate = trackPool[poolCursor]
				if candidate and not candidate.IsPlaying then
					chosen = candidate
					break
				end
			end
			local recycled = false
			if not chosen then
				poolCursor = poolCursor % poolSize + 1
				chosen = trackPool[poolCursor]
				recycled = chosen ~= nil
			end
			if chosen then
				pcall(function()
					if recycled then chosen:Stop(0) end
					chosen.Priority = MONSTER_FLOOD_PRIORITY
					chosen:Play(0.1, 1, 1)
				end)
			end
		end
	end)

	return function()
		running = false
		if renderConn then
			pcall(function() renderConn:Disconnect() end)
			renderConn = nil
		end
		destroyPool()
	end
end

local GOD_ANIMS = {
	"11508725111",
	"11710290503",
	"6428519131",
	"129800120542781",
	"6501497627",
	"82335285372711",
	"106886961189983",
}
local GOD_OBF_CHARS = "ABCDEFGHIJKMNOLPQRSTUVWXYZabcdefghijkmnolpqrstuvwxyz1234567890%🏳️‍⚧️🏳️‍🌈🪟🌈㊗️🧒👏🩶🥹"
local GOD_OBF_FAKES = {
	"9657469282", "6055558740", "128614295452457", "7599155704", "10168663111",
	"15302935464", "5053295423", "6385078248", "7968088101", "7617742471",
	"11328614766", "9726608174", "90136907973692",
}
local MUTATE_POOL = 60
local MUTATE_PRIORITY = Enum.AnimationPriority.Action

local function randomStringFrom(pool, n)
	local poolLen = utf8.len(pool)
	local cs = {}
	for i = 1, n do
		local poolIdx = math.random(1, poolLen)
		local startByte = utf8.offset(pool, poolIdx)
		local endByte = utf8.offset(pool, poolIdx + 1) - 1
		cs[i] = string.sub(pool, startByte, endByte)
	end
	return table.concat(cs)
end

local function obfuscateAnimId(id)
	local junk = ""
	local percentEscapes = {}
	for i = 1, 25 do
		percentEscapes[i] = "%" .. i
	end
	if math.random() > 0.5 then
		for _ = 1, 2 do
			junk = junk .. percentEscapes[math.ceil(math.random(1, 20))]
		end
	else
		junk = junk .. randomStringFrom(GOD_OBF_CHARS, 5)
	end

	local urlSchemes = { "rbxhttp://", "rbxasset://" }
	local made = urlSchemes[math.floor(math.random(1, #urlSchemes))]
		.. "?id="
		.. randomStringFrom(GOD_OBF_CHARS, math.random(2, 7))
		.. "?id="
		.. tostring(GOD_OBF_FAKES[math.floor(math.random(1, #GOD_OBF_FAKES))])
		.. junk

	local suffix = "?id=" .. id .. "&"
	local remaining = math.max(0, 100 - #made - #suffix) - 1
	local left = math.random(math.floor(remaining * 0.4), math.floor(remaining * 0.6))
	local right = remaining - left

	made = made
		.. randomStringFrom(GOD_OBF_CHARS, left)
		.. suffix
		.. randomStringFrom("ABCDEFGHIJKMNOLPQRSTUVWXYZabcdefghijkmnolpqrstuvwxyz%", 1)
		.. randomStringFrom(GOD_OBF_CHARS, right)

	return made
end

local function startMutateMode(character)
	if not character then return function() end end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return function() end end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return function() end end

	local trackPool = {}
	local function destroyPool()
		for _, track in next, trackPool do
			pcall(function() track:Stop(0); track:Destroy() end)
		end
		trackPool = {}
	end

	local attempts = 0
	while #trackPool < MUTATE_POOL and attempts < MUTATE_POOL * 2 do
		attempts = attempts + 1
		local realId = GOD_ANIMS[math.random(1, #GOD_ANIMS)]
		local animation = Instance.new("Animation")
		animation.AnimationId = obfuscateAnimId(realId)
		local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
		if ok and track then
			loadedTrackRegistry[track] = true
			track.Looped = false
			trackPool[#trackPool + 1] = track
		end
	end

	local running = true
	local accumulator = 0
	local poolCursor = 0
	local renderConn
	renderConn = RunService.RenderStepped:Connect(function(deltaTime)
		if not running then return end
		if not character.Parent then
			running = false
			return
		end
		local poolSize = #trackPool
		if poolSize == 0 then return end

		local intensity = getOption("ExpApBreakerAggressive2Intensity", 200)
		local interval = 1 / math.max(1, intensity)
		accumulator = math.min(accumulator + deltaTime, interval * 2)

		if not underAnimationLimit(animator) then
			return
		end

		local burstsThisFrame = 0
		while accumulator >= interval and burstsThisFrame < 50 do
			accumulator = accumulator - interval
			burstsThisFrame = burstsThisFrame + 1

			local chosen = nil
			for _ = 1, poolSize do
				poolCursor = poolCursor % poolSize + 1
				local candidate = trackPool[poolCursor]
				if candidate and not candidate.IsPlaying then
					chosen = candidate
					break
				end
			end
			local recycled = false
			if not chosen then
				poolCursor = poolCursor % poolSize + 1
				chosen = trackPool[poolCursor]
				recycled = chosen ~= nil
			end
			if chosen then
				pcall(function()
					if recycled then chosen:Stop(0) end
					chosen.Priority = MUTATE_PRIORITY
					chosen:Play(0.1, 1, 1)
				end)
			end
		end
	end)

	return function()
		running = false
		if renderConn then
			pcall(function() renderConn:Disconnect() end)
			renderConn = nil
		end
		destroyPool()
	end
end

-- ---- Blatant Flood tuning --------------------------------------------------
local FULL_BLATANT_POOL_TARGET = 150
local FULL_BLATANT_FADE_HIGH = 99999

-- All known animation ids (every tag), not just attack tags.
local function collectAllKnownAnimationIds()
	local ids, seen = {}, {}
	pcall(function()
		local list = TimingStore.as:list()
		for _, entry in ipairs(list) do
			local id = entry:id()
			if type(id) == "string" and id:match("%d") and not seen[id] then
				seen[id] = true
				ids[#ids + 1] = id
			end
		end
	end)
	return ids
end

local function numericAnimId(id)
	if type(id) ~= "string" then
		return nil
	end
	return id:match("id=(%d+)") or id:match("(%d+)%s*$") or id:match("(%d+)")
end

local function randomPriority()
	return PRIORITY_ORDER[math.random(1, #PRIORITY_ORDER)]
end
local function randomWeight()
	if math.random() < 0.5 then
		return math.random() * 0.15
	end
	return math.random() * 9.5 + 0.5
end
local function randomFade()
	if math.random() < 0.5 then
		return math.random() * 0.15
	end
	return FULL_BLATANT_FADE_HIGH
end
local function randomSpeed()
	if math.random() < 0.5 then
		return math.random() * 0.9 + 0.1
	end
	return math.random() * 24 + 1
end

-- ---- Blatant Flood ---------------------------------------------------------
-- Floods every known timing at a high rate with randomized properties AND blanks the animation id
-- of your real attacks to nothing -- so inside the storm the enemy's auto-parry can't even read
-- what you threw, let alone parry it. It does NOT stop your real attacks: they still land, just
-- with an empty (unresolvable) id. Ids are blanked the instant the attack plays (AnimationPlayed)
-- with a per-frame backstop.
local function startBlatantFloodMode(character)
	if not character then return function() end end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return function() end end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return function() end end

	local trackPool = {}
	local function destroyPool()
		for _, track in next, trackPool do
			pcall(function() track:Stop(0); track:Destroy() end)
		end
		trackPool = {}
	end

	-- Numeric ids of the moves you actually throw (M1 / Mantra / Critical) -- these are the ones an
	-- enemy has timings for, so blanking exactly these is what defeats their parry.
	local attackIdSet = {}
	local function rebuildAttackIdSet()
		attackIdSet = {}
		for _, id in ipairs(collectKnownAttackAnimationIds()) do
			local n = numericAnimId(id)
			if n then
				attackIdSet[n] = true
			end
		end
	end

	-- Tracks whose id we've already blanked, so we don't touch them every frame.
	local obfuscated = setmetatable({}, { __mode = "k" })
	local function obfuscateRealAttack(track)
		if loadedTrackRegistry[track] or obfuscated[track] or not track.Animation then
			return
		end
		local n = numericAnimId(track.Animation.AnimationId)
		if n and attackIdSet[n] then
			obfuscated[track] = true
			-- Blank the id to nothing: the track keeps playing (your attack still lands) but the
			-- replicated id becomes empty, so the enemy can't resolve a timing for it.
			pcall(function()
				track.Animation.AnimationId = ""
			end)
		end
	end

	local function loadPool(idList)
		destroyPool()
		if type(idList) ~= "table" or #idList == 0 then return end
		local target = math.min(FULL_BLATANT_POOL_TARGET, math.max(#idList, 40))
		local cursor, attempts, maxAttempts = 0, 0, target + #idList + 16
		while #trackPool < target and attempts < maxAttempts do
			attempts = attempts + 1
			cursor = cursor % #idList + 1
			local id = idList[cursor]
			if not string.find(id, "://", 1, true) then
				id = "rbxassetid://" .. id
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
			if ok and track then
				loadedTrackRegistry[track] = true
				track.Looped = false
				trackPool[#trackPool + 1] = track
			end
		end
	end

	local ids = collectAllKnownAnimationIds()
	local usingFallback = false
	if #ids == 0 then
		ids = FALLBACK_AGGRESSIVE2_ANIMATION_IDS
		usingFallback = true
	end
	loadPool(ids)
	rebuildAttackIdSet()

	local running = true
	local accumulator = 0
	local poolCursor = 0
	local fallbackRefreshTimer = 0

	-- Blank real attacks the instant they start (before the next frame can leak the id).
	local animPlayedConn = animator.AnimationPlayed:Connect(function(track)
		if running then
			obfuscateRealAttack(track)
		end
	end)

	local renderConn
	renderConn = RunService.RenderStepped:Connect(function(deltaTime)
		if not running then return end
		if not character.Parent then
			running = false
			return
		end

		-- Per-frame backstop for any real attack the AnimationPlayed hook missed.
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			obfuscateRealAttack(track)
		end

		if usingFallback then
			fallbackRefreshTimer = fallbackRefreshTimer + deltaTime
			if fallbackRefreshTimer >= 1.5 then
				fallbackRefreshTimer = 0
				local refreshed = collectAllKnownAnimationIds()
				if #refreshed > 0 then
					loadPool(refreshed)
					rebuildAttackIdSet()
					usingFallback = false
				end
			end
		end

		local poolSize = #trackPool
		if poolSize == 0 then return end

		-- Rate is user-tunable (default 60/s). Each Play() replicates to the server, so a very high
		-- rate saturates your uplink and spikes YOUR ping -- keep this modest; 40-80/s already buries
		-- the real swing in noise. Burst cap scales with rate so a low rate can't batch a huge frame.
		local rate = getOption("BlatantFloodRate", 60)
		rate = math.clamp(tonumber(rate) or 60, 1, 300)
		local burstCap = math.max(4, math.ceil(rate / 10))
		local interval = 1 / rate
		accumulator = math.min(accumulator + deltaTime, interval * burstCap)

		local burstsThisFrame = 0
		while accumulator >= interval and burstsThisFrame < burstCap do
			accumulator = accumulator - interval
			burstsThisFrame = burstsThisFrame + 1

			poolCursor = poolCursor % poolSize + 1
			local track = trackPool[poolCursor]
			if track then
				pcall(function()
					if track.IsPlaying then
						track:Stop(0)
					end
					track.Priority = randomPriority()
					track:Play(randomFade(), randomWeight(), randomSpeed())
				end)
			end
		end
	end)

	return function()
		running = false
		if animPlayedConn then
			pcall(function() animPlayedConn:Disconnect() end)
			animPlayedConn = nil
		end
		if renderConn then
			pcall(function() renderConn:Disconnect() end)
			renderConn = nil
		end
		destroyPool()
	end
end

-- Blatant Flood runs as its own standalone toggle, independent of the AP Breaker mode system.
local blatantFloodActive = false
local blatantFloodCleanup = nil
local blatantFloodCharConn = nil

function ApBreaker:StartBlatantFlood()
	if blatantFloodActive or ApBreaker.force then return end
	blatantFloodActive = true

	local player = Players.LocalPlayer
	local function apply(character)
		if blatantFloodCleanup then
			pcall(blatantFloodCleanup)
			blatantFloodCleanup = nil
		end
		if blatantFloodActive and character then
			blatantFloodCleanup = startBlatantFloodMode(character)
		end
	end

	if not blatantFloodCharConn then
		blatantFloodCharConn = player.CharacterAdded:Connect(apply)
	end
	apply(player.Character or player.CharacterAdded:Wait())
	Logger.warn("Blatant Flood started.")
end

function ApBreaker:StopBlatantFlood()
	if not blatantFloodActive then return end
	blatantFloodActive = false

	if blatantFloodCleanup then
		pcall(blatantFloodCleanup)
		blatantFloodCleanup = nil
	end
	if blatantFloodCharConn then
		blatantFloodCharConn:Disconnect()
		blatantFloodCharConn = nil
	end
	Logger.warn("Blatant Flood stopped.")
end

local MODE_STARTERS = {
	["Priority Mask"]   = startUltimateMode,
	["Fade Time Flood"] = startFadeTimeFloodMode,
	["Monster Flood"]   = startMonsterFloodMode,
	["Mutate"]          = startMutateMode,
}

local apBreakerActive = false
local apBreakerCleanups = {}
local characterAddedConn = nil

local function getSelectedModes()
	local selected = Configuration.expectOptionValue("ExpApBreakerModes")
	local result = {}
	if type(selected) == "table" then
		for key, value in pairs(selected) do
			local name = (value == true) and key or value
			if type(name) == "string" and MODE_STARTERS[name] then
				result[name] = true
			end
		end
	end
	return result
end

local function applyModes(character, forceRestart)
	if forceRestart then
		for _, cleanup in pairs(apBreakerCleanups) do
			pcall(cleanup)
		end
		apBreakerCleanups = {}
	end

	if not apBreakerActive or not character then
		for _, cleanup in pairs(apBreakerCleanups) do
			pcall(cleanup)
		end
		apBreakerCleanups = {}
		return
	end

	local selected = getSelectedModes()

	for mode, cleanup in pairs(apBreakerCleanups) do
		if not selected[mode] then
			pcall(cleanup)
			apBreakerCleanups[mode] = nil
		end
	end

	for mode in pairs(selected) do
		if not apBreakerCleanups[mode] then
			apBreakerCleanups[mode] = MODE_STARTERS[mode](character)
		end
	end
end

function ApBreaker:Start()
	if apBreakerActive then return end
	apBreakerActive = true

	local player = Players.LocalPlayer
	if not characterAddedConn then
		characterAddedConn = player.CharacterAdded:Connect(function(character)
			applyModes(character, true)
		end)
	end

	applyModes(player.Character or player.CharacterAdded:Wait(), true)
	Logger.warn("AP Breaker started.")
end

function ApBreaker:Stop()
	if not apBreakerActive then return end
	apBreakerActive = false

	for _, cleanup in pairs(apBreakerCleanups) do
		pcall(cleanup)
	end
	apBreakerCleanups = {}

	if characterAddedConn then
		characterAddedConn:Disconnect()
		characterAddedConn = nil
	end
	Logger.warn("AP Breaker stopped.")
end

function ApBreaker.refresh()
	if not apBreakerActive then return end
	applyModes(Players.LocalPlayer.Character, false)
end

function ApBreaker.init()
	if Configuration.expectToggleValue("ExpApBreaker") then
		ApBreaker:Start()
	end
	if Configuration.expectToggleValue("BlatantFlood") then
		ApBreaker:StartBlatantFlood()
	end
end

function ApBreaker.detach()
	ApBreaker.force = true
	ApBreaker:Stop()
	ApBreaker:StopBlatantFlood()
end

if getgenv then
	getgenv().ExpApBreaker = ApBreaker
end

return ApBreaker
