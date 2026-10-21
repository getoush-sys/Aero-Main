-- Animation ingress guard (ported 1:1 from Katalyst). Token-bucket rate limiter that
-- throttles how many suspicious / candidate / recovery animation-ingress events the
-- anti-breaker admits per-player and globally, plus a monotonic generation counter and
-- lightweight stats. Shared singleton across all defenders.

local IngressGuard = {}

local PRESSURE_WINDOW = 0.5
local CANDIDATE_ID_RING = 16
local CANDIDATE_ID_DEDUP = 0.06
local RECOVERY_RATE = 20
local RECOVERY_BURST_GLOBAL = 40
local RECOVERY_BURST_GLOBAL_TOKENS = 6
local RECOVERY_BURST_PLAYER = 12

local playerSuspiciousRate = 15
local playerSuspiciousBurst = 2
local globalSuspiciousRate = 22.5
local globalSuspiciousBurst = 4

local owners = setmetatable({}, { __mode = "k" })
local ownerCount = 0
local globalSuspicious = nil
local globalCandidate = nil
local globalRecovery = nil
local globalPressureUntil = 0
local stats = nil
local generationCounter = 0

local function newStats()
	return {
		incoming = 0, admittedSuspicious = 0, admittedCandidate = 0, quarantinedCandidate = 0,
		coalescedQuarantine = 0, admittedRecovery = 0, recoveredEvidence = 0, rejectedUniversal = 0,
		rejectedPlayerBudget = 0, rejectedGlobalBudget = 0, rejectedCandidateBudget = 0,
		rejectedRecoveryBudget = 0, advancedEntered = 0, autoDefenderReached = 0, activeMonitors = 0,
	}
end

local function newBucket(tokens, updatedAt)
	return { tokens = tokens, updatedAt = updatedAt }
end

local function refill(bucket, rate, burst, now)
	local elapsed = now - bucket.updatedAt
	if elapsed > 0 then
		bucket.tokens = math.min(burst, bucket.tokens + elapsed * rate)
		bucket.updatedAt = now
	end
end

---Try to consume one token from a player bucket AND the matching global bucket.
local function consume(playerBucket, playerRate, playerBurst, globalBucket, globalRate, globalBurst, now)
	refill(playerBucket, playerRate, playerBurst, now)
	refill(globalBucket, globalRate, globalBurst, now)
	if playerBucket.tokens < 1 then
		return false, "player-budget"
	end
	if globalBucket.tokens < 1 then
		return false, "global-budget"
	end
	playerBucket.tokens = playerBucket.tokens - 1
	globalBucket.tokens = globalBucket.tokens - 1
	return true
end

local function resetState(now)
	generationCounter = generationCounter + 1
	owners = setmetatable({}, { __mode = "k" })
	ownerCount = 0
	globalSuspicious = newBucket(globalSuspiciousBurst, now)
	globalCandidate = newBucket(6, now)
	globalRecovery = newBucket(RECOVERY_BURST_PLAYER, now)
	globalPressureUntil = 0
	stats = newStats()
end

local function ownerState(player, now)
	local character = player.Character
	local state = owners[player]
	if state and state.character == character then
		return state
	end
	state = {
		character = character,
		suspicious = newBucket(2, now),
		candidate = newBucket(3, now),
		recovery = newBucket(RECOVERY_BURST_GLOBAL_TOKENS, now),
		candidateIds = {},
		candidateIdRing = table.create(16),
		candidateIdCount = 0,
		candidateIdCursor = 1,
		pressureUntil = 0,
	}
	if not owners[player] then
		ownerCount = ownerCount + 1
	end
	owners[player] = state
	return state
end

---Candidate-id dedup ring: reject a repeated candidate id within the dedup window.
local function admitCandidateId(state, candidateId, now)
	local last = state.candidateIds[candidateId]
	if last and now - last < CANDIDATE_ID_DEDUP then
		return false
	end
	if not last then
		if state.candidateIdCount < CANDIDATE_ID_RING then
			state.candidateIdCount = state.candidateIdCount + 1
			state.candidateIdRing[state.candidateIdCount] = candidateId
		else
			local cursor = state.candidateIdCursor
			local evicted = state.candidateIdRing[cursor]
			if evicted then
				state.candidateIds[evicted] = nil
			end
			state.candidateIdRing[cursor] = candidateId
			state.candidateIdCursor = cursor % CANDIDATE_ID_RING + 1
		end
	end
	state.candidateIds[candidateId] = now
	return true
end

function IngressGuard.configure(rate)
	rate = math.clamp(tonumber(rate) or 15, 1, 200)
	if playerSuspiciousRate == rate and globalSuspicious then
		return
	end
	playerSuspiciousRate = rate
	playerSuspiciousBurst = math.max(2, math.min(4, rate * 0.1))
	globalSuspiciousRate = math.min(120, math.max(rate, rate * 1.5))
	globalSuspiciousBurst = math.max(4, math.min(8, globalSuspiciousRate * 0.1))
	local now = os.clock()
	if not globalSuspicious then
		resetState(now)
		return
	end
	refill(globalSuspicious, globalSuspiciousRate, globalSuspiciousBurst, now)
	globalSuspicious.tokens = math.min(globalSuspicious.tokens, globalSuspiciousBurst)
	for _, state in next, owners do
		refill(state.suspicious, playerSuspiciousRate, playerSuspiciousBurst, now)
		state.suspicious.tokens = math.min(state.suspicious.tokens, playerSuspiciousBurst)
	end
end

function IngressGuard.reset()
	resetState(os.clock())
end

function IngressGuard.generation()
	return generationCounter
end

function IngressGuard.removeOwner(player)
	if player and owners[player] then
		owners[player] = nil
		ownerCount = math.max(0, ownerCount - 1)
	end
end

---@return boolean admitted, string? reason, boolean underPressure
function IngressGuard.admitSuspicious(player)
	local now = os.clock()
	stats.incoming = stats.incoming + 1
	local state = ownerState(player, now)
	local ok, reason = consume(state.suspicious, playerSuspiciousRate, playerSuspiciousBurst,
		globalSuspicious, globalSuspiciousRate, globalSuspiciousBurst, now)
	if ok then
		stats.admittedSuspicious = stats.admittedSuspicious + 1
	else
		state.pressureUntil = now + PRESSURE_WINDOW
		if reason == "global-budget" then
			globalPressureUntil = now + PRESSURE_WINDOW
		end
	end
	return ok, reason, now < state.pressureUntil or now < globalPressureUntil
end

---@return boolean admitted, string? reason
function IngressGuard.admitCandidate(player, candidateId)
	local now = os.clock()
	local state = ownerState(player, now)
	if not admitCandidateId(state, candidateId, now) then
		stats.rejectedCandidateBudget = stats.rejectedCandidateBudget + 1
		return false, "repeated-candidate-id"
	end
	local ok, reason = consume(state.candidate, 12, 3, globalCandidate, 24, 6, now)
	if ok then
		stats.admittedCandidate = stats.admittedCandidate + 1
	else
		stats.rejectedCandidateBudget = stats.rejectedCandidateBudget + 1
	end
	return ok, reason
end

---@return boolean admitted, string? reason
function IngressGuard.admitRecovery(player)
	local now = os.clock()
	local state = ownerState(player, now)
	local ok, reason = consume(state.recovery, RECOVERY_RATE, RECOVERY_BURST_GLOBAL_TOKENS,
		globalRecovery, RECOVERY_BURST_GLOBAL, RECOVERY_BURST_PLAYER, now)
	if ok then
		stats.admittedRecovery = stats.admittedRecovery + 1
	else
		stats.rejectedRecoveryBudget = stats.rejectedRecoveryBudget + 1
	end
	return ok, reason
end

function IngressGuard.reject(reason)
	if reason == "global-budget" then
		stats.rejectedGlobalBudget = stats.rejectedGlobalBudget + 1
	elseif reason == "player-budget" then
		stats.rejectedPlayerBudget = stats.rejectedPlayerBudget + 1
	else
		stats.rejectedUniversal = stats.rejectedUniversal + 1
	end
end

function IngressGuard.quarantineCandidate(coalesced)
	stats.quarantinedCandidate = stats.quarantinedCandidate + 1
	if coalesced then
		stats.coalescedQuarantine = stats.coalescedQuarantine + 1
	end
end

function IngressGuard.recoveredEvidence()
	stats.recoveredEvidence = stats.recoveredEvidence + 1
end

function IngressGuard.advancedEntered()
	stats.advancedEntered = stats.advancedEntered + 1
end

function IngressGuard.autoDefenderReached()
	stats.autoDefenderReached = stats.autoDefenderReached + 1
end

function IngressGuard.monitorAdded()
	stats.activeMonitors = stats.activeMonitors + 1
end

function IngressGuard.monitorRemoved()
	stats.activeMonitors = math.max(0, stats.activeMonitors - 1)
end

function IngressGuard.snapshot()
	local out = {}
	for k, v in next, stats do
		out[k] = v
	end
	out.owners = ownerCount
	out.queued = 0
	out.pending = 0
	return out
end

IngressGuard.configure(playerSuspiciousRate)

return IngressGuard
