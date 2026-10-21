-- Attack authenticator: confirms whether an attack "candidate" (one occurrence of a track)
-- is a REAL attack by matching it against authoritative server-replicated evidence, and
-- detects decoy floods statistically. Ported from Katalyst's AttackAuthenticator.
--
-- A candidate starts "pending". It becomes:
--   authenticated  -> matched by evidence within its timing/latency window (real).
--   released       -> provisional timeout during a quiet period (allowed w/o evidence).
--   rejected       -> released during a flood, or the classifier already blocked it.
--   expired        -> passed its authentication deadline.
--   cancelled      -> killed by counter-evidence (e.g. weapon-trail-off).

local AttackAuthenticator = {}
AttackAuthenticator.__index = AttackAuthenticator

local BASELINE_SAMPLES = 24
local FEATURES = { "density", "overlap", "overdue", "mismatch", "transition", "deficit" }
local FEATURE_DEFAULT = { density = 1, overlap = 1, overdue = 0, mismatch = 0, transition = 0, deficit = 0 }
local FEATURE_FLOOR = { density = 0.75, overlap = 0.75, overdue = 0.5, mismatch = 0.35, transition = 0.35, deficit = 0.75 }

local WEAPON_FAMILIES = { ["weapon-m1"] = true, ["weapon-critical"] = true, ["weapon-special"] = true }

-- Stopwords ignored when tokenizing action names.
local ACTION_STOPWORDS = {
	action = true, attack = true, cast = true, charge = true, fire = true, flame = true, frost = true,
	gale = true, go = true, ice = true, lightning = true, mantra = true, new = true, recall = true,
	release = true, shadow = true, start = true, startup = true, wind = true, windup = true,
}

---@return number[]
local function sortedValues(map)
	local out = {}
	for _, v in next, map do
		out[#out + 1] = v
	end
	table.sort(out)
	return out
end

---@return number?
local function median(list)
	if #list == 0 then
		return nil
	end
	local sorted = sortedValues(list)
	local mid = math.floor(#sorted / 2)
	if #sorted % 2 == 1 then
		return sorted[mid + 1]
	end
	return (sorted[mid] + sorted[mid + 1]) / 2
end

---Median absolute deviation from a given center.
---@return number?
local function medianDeviation(list, center)
	if #list == 0 or center == nil then
		return nil
	end
	local deviations = {}
	for _, v in next, list do
		deviations[#deviations + 1] = math.abs(v - center)
	end
	return median(deviations)
end

local function removeValue(list, value)
	for i = #list, 1, -1 do
		if list[i] == value then
			table.remove(list, i)
			return
		end
	end
end

---Does the evidence's family set cover the candidate's category?
local function familyMatch(candidate, evidence)
	local families = evidence.families
	if not families then
		return true
	end
	if families[candidate.category] == true then
		return true
	end
	return evidence.allowWeaponFamilyBridge == true
		and WEAPON_FAMILIES[candidate.category] == true
		and WEAPON_FAMILIES[evidence.exactFamily] == true
end

local function weaponKeyOf(candidate)
	local ctx = candidate.weaponContext
	if not ctx then
		return "unknown"
	end
	return table.concat({
		tostring(ctx.weaponName or ctx.primaryWeapon or "unknown"),
		tostring(ctx.weaponClass or "unknown"),
		tostring(ctx.weaponType or "unknown"),
	}, "|")
end

local function normalize(s)
	return (string.gsub(string.lower(tostring(s or "")), "[^%w]", ""))
end

---Split a name into meaningful lowercase tokens (>=4 chars, not stopwords).
local function tokenize(s)
	local text = tostring(s or "")
	text = string.gsub(text, "(%l)(%u)", "%1 %2")
	text = string.gsub(text, "(%a)(%d)", "%1 %2")
	text = string.gsub(text, "(%d)(%a)", "%1 %2")
	text = string.lower(text)
	local tokens = {}
	for word in string.gmatch(text, "%w+") do
		if #word >= 4 and not ACTION_STOPWORDS[word] then
			tokens[word] = true
		end
	end
	return tokens
end

---Length of the common prefix (reverse=false) or suffix (reverse=true) of two strings.
local function commonAffix(a, b, reverse)
	local limit = math.min(#a, #b)
	local count = 0
	for i = 1, limit do
		local ia = reverse and (#a - i + 1) or i
		local ib = reverse and (#b - i + 1) or i
		if string.sub(a, ia, ia) == string.sub(b, ib, ib) then
			count = count + 1
		else
			break
		end
	end
	return count
end

---Fuzzy match: does any of the timing's action names correspond to the evidence's action key(s)?
local function timingActionCompatible(candidate, actionKey, aliases)
	local keys = { actionKey }
	for k, v in next, aliases or {} do
		if type(k) == "number" then
			keys[#keys + 1] = v
		elseif v == true then
			keys[#keys + 1] = k
		else
			keys[#keys + 1] = v
		end
	end

	local keyTokens = {}
	for _, key in next, keys do
		for tok in next, tokenize(key) do
			keyTokens[tok] = true
		end
	end

	for _, name in next, candidate.timingActionNames or {} do
		local normName = normalize(name)
		if #normName >= 4 then
			for _, key in next, keys do
				local normKey = normalize(key)
				if #normKey >= 4 then
					if normName == normKey then
						return true
					end
					local shorter = math.min(#normName, #normKey)
					local contains = string.find(normName, normKey, 1, true) ~= nil
						or string.find(normKey, normName, 1, true) ~= nil
					if contains and shorter / math.max(#normName, #normKey) >= 0.6 then
						return true
					end
					local pre = commonAffix(normName, normKey, false)
					local suf = commonAffix(normName, normKey, true)
					if pre >= 3 and suf >= 3 and (pre + suf) / shorter >= 0.75 then
						return true
					end
				end
			end
			for tok in next, tokenize(name) do
				if keyTokens[tok] then
					return true
				end
			end
		end
	end
	return false
end
AttackAuthenticator.timingActionCompatible = timingActionCompatible

---@return boolean loose, boolean tight, number error
local function durationMatch(candidate, evidence)
	if not evidence.duration or not candidate.expectedDuration or candidate.expectedDuration <= 0 then
		return true, false, math.huge
	end
	local err = math.abs(candidate.expectedDuration - evidence.duration)
		/ math.max(candidate.expectedDuration, evidence.duration, 0.01)
	return err <= 0.75, err <= 0.35, err
end

---Has the candidate's track actually progressed (played forward) since it started?
local function progressed(candidate, now, evidence)
	if candidate.recoveredIngress and evidence and evidence.authoritative then
		return true
	end
	local track = candidate.track
	if not track or not track.IsPlaying then
		return false, "track-not-playing"
	end
	local target = tonumber(track.WeightTarget) or 0
	local position = tonumber(track.TimePosition) or 0
	local weight = tonumber(track.WeightCurrent) or 0
	if target <= 0 then
		return false, "track-target-weight-zero"
	end
	local samples = candidate.progressionSamples
	samples[#samples + 1] = { at = now, position = position, weight = weight, target = target, speed = tonumber(track.Speed) or 0 }
	while #samples > 8 do
		table.remove(samples, 1)
	end
	local first = samples[1]
	local movedPosition = position > candidate.initialTimePosition + 0.0001
	local movedWeight = first and weight > first.weight + 0.001
	if movedPosition or movedWeight or now - candidate.startedAt <= candidate.progressionGrace then
		return true
	end
	return false, "track-did-not-progress"
end

---Score a compatible candidate/evidence pairing (higher = better match).
local function scorePairing(candidate, evidence, latency, durationTight)
	local score = 0
	local ctx = candidate.weaponContext or {}
	if evidence.exactFamily and candidate.category == evidence.exactFamily then
		score = 5
	elseif evidence.allowWeaponFamilyBridge and familyMatch(candidate, evidence) then
		score = 3
	elseif evidence.families and evidence.families[candidate.category] then
		score = 2
	end
	if ctx.status == "confirmed" then
		score = score + 4
	elseif ctx.status == "unknown" then
		score = score + 1
	end
	if durationTight then
		score = score + 2
	end
	if candidate.geometricPlausible and not evidence.authoritative then
		score = score + 2
	end
	if (evidence.centralLatencyMin or evidence.latencyMin) <= latency
		and latency <= (evidence.centralLatencyMax or evidence.latencyMax) then
		score = score + 2
	end
	if candidate.comboContinuous then
		score = score + 1
	end
	return score
end

function AttackAuthenticator:_candidateMap(track)
	local map = self.candidatesByTrack[track]
	if not map then
		map = {}
		self.candidatesByTrack[track] = map
	end
	return map
end

function AttackAuthenticator:_removeCandidate(candidate)
	removeValue(self.candidates, candidate)
	local map = self.candidatesByTrack[candidate.track]
	if map then
		map[candidate.occurrence] = nil
		if next(map) == nil then
			self.candidatesByTrack[candidate.track] = nil
		end
	end
end

function AttackAuthenticator:_prune(now)
	for i = #self.candidates, 1, -1 do
		local c = self.candidates[i]
		local hardExpiry = math.max(c.deadlineAt or c.startedAt, c.startedAt + c.behaviorWindow) + c.behaviorWindow
		if c.status == "pending" and now > (c.deadlineAt or now) then
			c.status = "expired"
			c.reason = "authentication-deadline-expired"
		end
		if now > hardExpiry then
			self:_removeCandidate(c)
		end
	end
	for i = #self.evidence, 1, -1 do
		if now - self.evidence[i].at > self.longestBehaviorWindow * 2 then
			table.remove(self.evidence, i)
		end
	end
	for i = #self.mismatchEvents, 1, -1 do
		if now - self.mismatchEvents[i] > self.longestBehaviorWindow * 2 then
			table.remove(self.mismatchEvents, i)
		end
	end
	while #self.candidates > 32 do
		local oldest = self.candidates[1]
		if oldest.status == "pending" then
			oldest.status = "expired"
			oldest.reason = "candidate-capacity"
		end
		self:_removeCandidate(oldest)
	end
	while #self.evidence > 64 do
		table.remove(self.evidence, 1)
	end
	while #self.mismatchEvents > 64 do
		table.remove(self.mismatchEvents, 1)
	end
end

function AttackAuthenticator:_featureThreshold(feature)
	local samples = self.baselines[feature]
	local center = median(samples) or FEATURE_DEFAULT[feature]
	local dev = medianDeviation(samples, center) or 0
	return center + math.max(dev * 3, FEATURE_FLOOR[feature]), dev
end

function AttackAuthenticator:_featureVector(now, candidate)
	local window = candidate.behaviorWindow
	local expected = math.max(1, math.ceil(window / candidate.legalInterval))
	local inWindow = {}
	local playing = 0
	local overdue = 0
	local deficit = 0
	local transition = 0
	local previous = nil
	for _, c in next, self.candidates do
		if now - c.startedAt <= window then
			inWindow[#inWindow + 1] = c
			if c.track and c.track.IsPlaying then
				playing = playing + 1
			end
			if c.status == "pending" then
				deficit = deficit + 1
				if now - c.startedAt > c.evidenceLatencyMax then
					overdue = overdue + 1
				end
			end
			if previous and c.category ~= previous.category
				and c.startedAt - previous.startedAt < math.min(c.legalInterval, previous.legalInterval) * 0.35 then
				transition = transition + 1
			end
			if c.weaponContext and c.weaponContext.status == "mismatch" then
				transition = transition + 1
			end
			previous = c
		end
	end
	local mismatch = 0
	for _, at in next, self.mismatchEvents do
		if now - at <= window then
			mismatch = mismatch + 1
		end
	end
	local overlapDenom = math.max(1, math.min(2, expected))
	local vector = {
		density = #inWindow / expected,
		overlap = playing / overlapDenom,
		overdue = overdue / expected,
		mismatch = mismatch / expected,
		transition = transition / expected,
		deficit = deficit / expected,
	}
	return vector, deficit
end

function AttackAuthenticator:_evaluateFlood(now, candidate)
	local vector, pendingCount = self:_featureVector(now, candidate)
	local abnormal = 0
	local severe = 0
	for _, feature in next, FEATURES do
		local threshold, dev = self:_featureThreshold(feature)
		local severeMargin = math.max(dev * 2, FEATURE_FLOOR[feature])
		if vector[feature] > threshold then
			abnormal = abnormal + 1
		end
		if vector[feature] > threshold + severeMargin then
			severe = severe + 1
		end
	end
	candidate.featureVector = vector
	candidate.abnormalFeatures = abnormal
	if not self.floodActive then
		if abnormal >= 3 then
			self.enterStreak = self.enterStreak + 1
		else
			self.enterStreak = 0
		end
		if self.enterStreak >= 2 or severe >= 4 then
			self.floodActive = true
			self.floodEnteredAt = now
			self.quietSince = nil
		end
	else
		if abnormal <= 1 and pendingCount == 0 and #self.mismatchEvents == 0 then
			self.quietSince = self.quietSince or now
			local quietWindow = math.max(self.longestBehaviorWindow, candidate.behaviorWindow * 2)
			if now - self.quietSince >= quietWindow then
				self.floodActive = false
				self.enterStreak = 0
				self.quietSince = nil
			end
		else
			self.quietSince = nil
		end
	end
	return vector
end

function AttackAuthenticator:_recordBaseline(vector)
	if self.floodActive or not vector then
		return
	end
	for _, feature in next, FEATURES do
		local samples = self.baselines[feature]
		samples[#samples + 1] = vector[feature]
		while #samples > BASELINE_SAMPLES do
			table.remove(samples, 1)
		end
	end
end

---Register a new candidate for an attack occurrence (idempotent per track+occurrence).
---@return table candidate, boolean isNew, table? retriedTransaction
function AttackAuthenticator:observeCandidate(view)
	local map = self:_candidateMap(view.track)
	local existing = map[view.occurrence]
	if existing then
		return existing, false
	end

	local startedAt = view.startedAt
	local legalInterval = math.clamp(tonumber(view.legalInterval) or 0.6, 0.08, 4)
	local behaviorWindow = math.max(legalInterval, tonumber(view.longestTiming) or legalInterval)
	local evidenceLatencyMax = math.clamp(tonumber(view.evidenceLatencyMax) or legalInterval * 0.2, 0.03, legalInterval)
	local settle = math.max(evidenceLatencyMax, legalInterval * 0.2)
	local weaponKey = weaponKeyOf(view)

	local comboContinuous = view.comboContinuous ~= false
	local last = self.lastTransaction
	if last and not last.cancelled then
		local prev = last.candidate
		local gap = startedAt - last.authenticatedAt
		local minGap = math.clamp(math.min(legalInterval, prev.legalInterval) * 0.1, 0.025, 0.12)
		if gap < 0 or (gap < minGap and (weaponKey ~= prev.weaponKey or view.category ~= prev.category)) then
			comboContinuous = false
		end
	end

	self.sequence = self.sequence + 1
	self.longestBehaviorWindow = math.max(self.longestBehaviorWindow, behaviorWindow)

	local candidate = {
		id = self.sequence,
		track = view.track,
		occurrence = view.occurrence,
		timing = view.timing,
		aid = view.aid,
		category = view.category,
		weaponContext = view.weaponContext,
		weaponKey = weaponKey,
		startedAt = startedAt,
		deadlineAt = view.deadlineAt,
		plannedDefenseAt = view.plannedDefenseAt,
		legalInterval = legalInterval,
		behaviorWindow = behaviorWindow,
		evidenceLatencyMax = evidenceLatencyMax,
		progressionGrace = math.clamp(tonumber(view.progressionGrace) or 0.034, 0.016, 0.1),
		provisionalUntil = math.min(view.deadlineAt, startedAt + settle),
		initialTimePosition = tonumber(view.track.TimePosition) or 0,
		progressionSamples = {
			{
				at = startedAt,
				position = tonumber(view.track.TimePosition) or 0,
				weight = tonumber(view.track.WeightCurrent) or 0,
				target = tonumber(view.track.WeightTarget) or 0,
				speed = tonumber(view.track.Speed) or 0,
			},
		},
		expectedDuration = view.expectedDuration,
		geometricPlausible = view.geometricPlausible == true,
		comboContinuous = comboContinuous,
		actionKey = view.actionKey,
		timingActionNames = view.timingActionNames or {},
		classifierBlocked = view.classifierBlocked == true,
		callbackDispatchDeadlineAt = view.callbackDispatchDeadlineAt or view.deadlineAt,
		recoveredIngress = view.recoveredIngress == true,
		status = "pending",
		reason = "awaiting-combat-evidence",
	}

	map[view.occurrence] = candidate
	self.candidates[#self.candidates + 1] = candidate
	self:_prune(startedAt)
	self:_evaluateFlood(startedAt, candidate)
	local retried = self:_retryRetainedEvidence(startedAt)
	return candidate, true, retried
end

function AttackAuthenticator:getCandidate(track, occurrence)
	local map = self.candidatesByTrack[track]
	return map and map[occurrence] or nil
end

---Provisionally release a pending candidate once its window elapses (allow only when quiet).
function AttackAuthenticator:releaseCandidate(candidate, now)
	if not candidate or candidate.status ~= "pending" then
		return false
	end
	now = now or os.clock()
	self:_prune(now)
	self:_evaluateFlood(now, candidate)
	if now > candidate.deadlineAt then
		candidate.status = "expired"
		candidate.reason = "authentication-deadline-expired"
		return false
	end
	if self.floodActive or self.enterStreak > 0 then
		candidate.status = "rejected"
		candidate.reason = "unauthenticated-realistic-flood-candidate"
		return false
	end
	if candidate.classifierBlocked then
		candidate.status = "rejected"
		candidate.reason = "classifier-rejected"
		return false
	end
	candidate.status = "released"
	candidate.reason = "quiet-release"
	self:_recordBaseline(candidate.featureVector)
	return true
end

---Full compatibility gate between a candidate and a piece of evidence.
---@return boolean ok, table|string result
local function evidenceGate(self, candidate, evidence, now)
	if candidate.status ~= "pending" or evidence.claimedBy then
		return false, "candidate-or-evidence-already-claimed"
	end
	if evidence.at > candidate.deadlineAt then
		return false, "safe-deadline-closed"
	end
	local latency = evidence.at - candidate.startedAt
	if latency < evidence.latencyMin or latency > evidence.latencyMax then
		return false, "evidence-latency-outside-distribution"
	end
	if not familyMatch(candidate, evidence) then
		return false, "attack-family-mismatch"
	end
	if candidate.weaponContext and candidate.weaponContext.status == "mismatch" then
		return false, "weapon-context-mismatch"
	end
	if evidence.weaponKey and candidate.weaponKey ~= evidence.weaponKey then
		return false, "equipped-weapon-mismatch"
	end
	if evidence.requireExactWeaponType and not (candidate.weaponContext and candidate.weaponContext.exactWeaponTypeMatch == true) then
		return false, "exact-weapon-type-mismatch"
	end
	if evidence.actionKey then
		if evidence.requireTimingActionMatch then
			if not timingActionCompatible(candidate, evidence.actionKey, evidence.actionAliases) then
				return false, "timing-action-family-mismatch"
			end
		elseif candidate.actionKey ~= evidence.actionKey then
			return false, "action-context-mismatch"
		end
	end
	if evidence.causalCandidateId and candidate.id ~= evidence.causalCandidateId then
		return false, "causal-anchor-mismatch"
	end
	if evidence.causalTrack and candidate.track ~= evidence.causalTrack then
		return false, "causal-track-mismatch"
	end
	if evidence.causalOccurrence and candidate.occurrence ~= evidence.causalOccurrence then
		return false, "causal-occurrence-mismatch"
	end
	if not candidate.comboContinuous then
		return false, "combo-discontinuity"
	end
	if not candidate.geometricPlausible and not evidence.authoritative then
		return false, "geometry-not-plausible"
	end
	local last = self.lastTransaction
	if last and last.candidate ~= candidate and not last.cancelled
		and evidence.at - last.authenticatedAt < math.min(candidate.legalInterval, last.candidate.legalInterval) * 0.25 then
		return false, "combat-transaction-already-open"
	end
	local ok, reason = progressed(candidate, evidence.at, evidence)
	if not ok then
		return false, reason
	end
	local durLoose, durTight, durErr = durationMatch(candidate, evidence)
	if not durLoose then
		return false, "track-duration-mismatch"
	end
	return true, { candidate = candidate, latency = latency, durationTight = durTight, durationError = durErr, score = scorePairing(candidate, evidence, latency, durTight) }
end

---Record a piece of replicated evidence and authenticate the best-matching candidate.
---@return table? candidate, string reason
function AttackAuthenticator:recordEvidence(evidence, now)
	now = now or os.clock()
	self:_prune(now)
	if evidence.id == nil then
		self.evidenceSequence = self.evidenceSequence + 1
		evidence.id = self.evidenceSequence
		evidence.latencyMin = evidence.latencyMin or -0.02
		evidence.latencyMax = evidence.latencyMax or self.longestBehaviorWindow
		evidence.uncertainty = evidence.uncertainty or 0.02
		if evidence.retainForFutureCandidate == nil then
			evidence.retainForFutureCandidate = evidence.authoritative == true
		end
		self.evidence[#self.evidence + 1] = evidence
	end

	local matches = {}
	for _, candidate in next, self.candidates do
		local ok, result = evidenceGate(self, candidate, evidence, now)
		if ok then
			matches[#matches + 1] = result
		end
	end
	table.sort(matches, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		elseif a.durationError ~= b.durationError then
			return a.durationError < b.durationError
		end
		return a.latency < b.latency
	end)

	if #matches == 0 then
		if evidence.retainForFutureCandidate then
			return nil, "awaiting-compatible-candidate"
		end
		if not evidence.finalizedUnmatched then
			evidence.finalizedUnmatched = true
			self.mismatchEvents[#self.mismatchEvents + 1] = evidence.at
		end
		return nil, "no-compatible-candidate"
	end

	local best = matches[1]
	local second = matches[2]
	if second then
		local sameShape = best.candidate.category == second.candidate.category
			and best.candidate.weaponKey == second.candidate.weaponKey
			and best.score == second.score
		local nearLatency = math.abs(best.latency - second.latency) <= evidence.uncertainty
		local nearDuration = math.abs(best.durationError - second.durationError) <= 0.05
		if sameShape and nearLatency and nearDuration then
			self.mismatchEvents[#self.mismatchEvents + 1] = evidence.at
			evidence.reason = "ambiguous-compatible-candidates"
			return nil, evidence.reason
		end
	end

	local candidate = best.candidate
	self.transactionSequence = self.transactionSequence + 1
	local transaction = {
		id = self.transactionSequence,
		candidate = candidate,
		evidence = evidence,
		authenticatedAt = evidence.at,
		scheduled = false,
		issued = false,
		cancelled = false,
	}
	evidence.claimedBy = candidate.id
	candidate.status = "authenticated"
	candidate.reason = evidence.kind
	candidate.authenticatedFamily = evidence.exactFamily or candidate.category
	candidate.familyBridged = evidence.allowWeaponFamilyBridge == true and evidence.exactFamily ~= nil and candidate.category ~= evidence.exactFamily
	candidate.transaction = transaction
	candidate.evidenceLatency = best.latency
	self.lastTransaction = transaction
	self:_recordBaseline(candidate.featureVector)
	return candidate, "authenticated"
end

---Find a retained authoritative evidence that would authenticate a candidate-shaped view
---(used by the ingress-recovery path to anchor a quarantined candidate to prior evidence).
---@return table? evidence
function AttackAuthenticator:retainedEvidenceForTiming(view, now)
	now = now or os.clock()
	self:_prune(now)
	for i = #self.evidence, 1, -1 do
		local evidence = self.evidence[i]
		if evidence.authoritative and evidence.retainForFutureCandidate
			and not evidence.claimedBy and not evidence.causalCandidateId then
			local latency = evidence.at - view.startedAt
			local latencyMin = evidence.latencyMin or -0.02
			local latencyMax = evidence.latencyMax or self.longestBehaviorWindow
			local actionOk = not evidence.actionKey or not evidence.requireTimingActionMatch
				or timingActionCompatible(view, evidence.actionKey, evidence.actionAliases)
			if latencyMin <= latency and latency <= latencyMax and familyMatch(view, evidence)
				and actionOk and (not view.deadlineAt or evidence.at <= view.deadlineAt) then
				return evidence
			end
		end
	end
	return nil
end

function AttackAuthenticator:_retryRetainedEvidence(now)
	now = now or os.clock()
	for _, evidence in next, self.evidence do
		if evidence.retainForFutureCandidate and not evidence.claimedBy then
			local result = self:recordEvidence(evidence, now)
			if result then
				return result
			end
		end
	end
end

---Counter-evidence: cancel any authenticated-but-not-yet-issued occurrence (attack aborted).
---@return table[] cancelled
function AttackAuthenticator:cancelFromEvidence(evidence)
	local cancelled = {}
	for _, candidate in next, self.candidates do
		local transaction = candidate.transaction
		local duration = transaction and transaction.evidence and tonumber(transaction.evidence.duration)
		local age = transaction and evidence.at - transaction.authenticatedAt or math.huge
		local withinWindow = not duration or age <= duration * 0.65
		if transaction and not transaction.issued and not transaction.cancelled and withinWindow
			and evidence.at <= candidate.deadlineAt
			and (not evidence.weaponKey or evidence.weaponKey == candidate.weaponKey) then
			transaction.cancelled = true
			transaction.cancelReason = evidence.kind
			candidate.status = "cancelled"
			candidate.reason = evidence.kind
			cancelled[#cancelled + 1] = candidate
		end
	end
	return cancelled
end

function AttackAuthenticator:isAuthenticated(track, occurrence)
	local candidate = self:getCandidate(track, occurrence)
	return candidate ~= nil and candidate.status == "authenticated"
		and candidate.transaction ~= nil and not candidate.transaction.cancelled
end

function AttackAuthenticator:isOccurrenceValid(track, occurrence)
	local candidate = self:getCandidate(track, occurrence)
	if not candidate then
		return true
	end
	if candidate.status == "released" then
		return true
	end
	return candidate.status == "authenticated" and candidate.transaction ~= nil and not candidate.transaction.cancelled
end

---Claim the defense sequence for an authenticated occurrence exactly once.
function AttackAuthenticator:claimSchedule(track, occurrence, now)
	local candidate = self:getCandidate(track, occurrence)
	local transaction = candidate and candidate.transaction
	if not candidate or candidate.status ~= "authenticated" or not transaction or transaction.cancelled then
		return false, "transaction-not-authenticated"
	end
	if transaction.scheduled then
		return false, "defense-sequence-already-scheduled"
	end
	now = now or os.clock()
	if transaction.authenticatedAt > candidate.deadlineAt then
		transaction.cancelled = true
		transaction.cancelReason = "authentication-deadline-expired"
		candidate.status = "expired"
		candidate.reason = transaction.cancelReason
		return false, transaction.cancelReason
	end
	if now > math.max(candidate.deadlineAt, candidate.callbackDispatchDeadlineAt or candidate.deadlineAt) then
		transaction.cancelled = true
		transaction.cancelReason = "scheduling-dispatch-deadline-expired"
		candidate.status = "expired"
		candidate.reason = transaction.cancelReason
		return false, transaction.cancelReason
	end
	transaction.scheduled = true
	transaction.scheduledAt = now
	return true, "defense-sequence-claimed"
end

function AttackAuthenticator:markIssued(track, occurrence)
	local candidate = self:getCandidate(track, occurrence)
	if candidate and candidate.transaction and not candidate.transaction.cancelled then
		local transaction = candidate.transaction
		if transaction.issued then
			return false
		end
		transaction.issued = true
		transaction.issuedAt = os.clock()
		return true
	end
	return false
end

function AttackAuthenticator:reset(reason)
	for _, candidate in next, self.candidates do
		if candidate.status == "pending" or candidate.status == "authenticated" then
			candidate.status = "cancelled"
			candidate.reason = reason or "reset"
		end
	end
	self.candidates = {}
	self.candidatesByTrack = {}
	self.evidence = {}
	self.mismatchEvents = {}
	self.lastTransaction = nil
	self.floodActive = false
	self.enterStreak = 0
	self.quietSince = nil
end

---@return AttackAuthenticator
function AttackAuthenticator.new()
	local self = setmetatable({}, AttackAuthenticator)
	self.candidates = {}
	self.candidatesByTrack = {}
	self.evidence = {}
	self.mismatchEvents = {}
	self.baselines = { density = {}, overlap = {}, overdue = {}, mismatch = {}, transition = {}, deficit = {} }
	self.floodActive = false
	self.enterStreak = 0
	self.quietSince = nil
	self.floodEnteredAt = nil
	self.lastTransaction = nil
	self.sequence = 0
	self.evidenceSequence = 0
	self.transactionSequence = 0
	self.longestBehaviorWindow = 0.5
	return self
end

return AttackAuthenticator
