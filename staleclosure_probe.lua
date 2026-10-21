-- staleclosure_probe.lua -- standalone, NOT Aero. paste into your executor.
--
-- QUESTION IT ANSWERS: does calling getupvalues() on a getgc'd game closure whose source script was
-- destroyed by a teleport (1) return fine, (2) throw a CATCHABLE error, or (3) HARD-PANIC the client
-- (RSL - panic ...Kernel)? Aero caches the game's "Roll"/"Sprint" closure by pointer and getupvalues it
-- across frames; this reproduces that exact object + that exact op, across a DataModel swap.
--
-- HOW TO READ THE RESULT (file: staleclosure_probe_log.txt, next to your executor's workspace):
--   * a line "... STALE ATTEMPT ..." immediately followed by "... STALE RESULT returned ok ..."  -> SAFE.
--       caching does NOT fault. my theory is dead; the 2090 is something else.
--   * "... STALE RESULT catchable-error ..."  -> it errors but is catchable (pcall caught it)  -> NOT the
--       panic either (a catchable error can't be the uncatchable Kernel crash).
--   * "... STALE ATTEMPT ..." as the VERY LAST line, and the client crashed right after a teleport  ->
--       CONFIRMED. getupvalues on the stale closure hard-panicked exactly where the band-aid clears it.
--   the probe re-reads the log on load and prints a verdict about the PREVIOUS session for you.
--
-- HOW TO RUN: execute once, then teleport around (region -> depths -> dungeon, the same churn as the farm).
--   each teleport re-tests. if it ever crashes, rejoin, re-run this, and read the printed verdict + send the log.

local getgc = getgc or (debug and debug.getgc)
local getupvalues = getupvalues or (debug and debug.getupvalues)
local getinfo = getinfo or (debug and debug.getinfo)
assert(type(getgc) == "function" and type(getupvalues) == "function", "executor lacks getgc/getupvalues")

local isccl = iscclosure or function() return false end
local isexe = isexecutorclosure or checkclosure or function() return false end

local players = game:GetService("Players")

------------------------------------------------------------------- breadcrumb log (synchronous to disk)
local LOG = "staleclosure_probe_log.txt"
local haveFS = type(writefile) == "function" and type(readfile) == "function"

local function crumb(line)
	local msg = ("[%0.3f] %s\n"):format(os.clock(), line)
	print("[probe] " .. line)
	if not haveFS then
		return
	end
	-- write the FULL log every time: each crumb is on disk before the next line of code runs, so a hard
	-- panic can't lose the last breadcrumb (which is the whole point).
	pcall(function()
		if type(appendfile) == "function" then
			appendfile(LOG, msg)
		else
			local prev = ""
			if type(isfile) ~= "function" or isfile(LOG) then
				local ok, data = pcall(readfile, LOG)
				prev = (ok and data) or ""
			end
			writefile(LOG, prev .. msg)
		end
	end)
end

------------------------------------------------------------------- verdict on the PREVIOUS session
if haveFS then
	local ok, prev = pcall(readfile, LOG)
	if ok and prev and #prev > 0 then
		local lastAttempt, lastResult = nil, nil
		for line in prev:gmatch("[^\n]+") do
			if line:find("STALE ATTEMPT", 1, true) then
				lastAttempt, lastResult = line, nil
			elseif line:find("STALE RESULT", 1, true) then
				lastResult = line
			end
		end
		crumb("################### NEW PROBE SESSION ###################")
		if lastAttempt and not lastResult then
			crumb(">>> VERDICT: previous session's LAST stale attempt had NO result line.")
			crumb(">>> that is the hard-panic signature -- getupvalues on the stale closure killed the client.")
			crumb(">>> last attempt was: " .. lastAttempt)
		elseif lastResult then
			crumb(">>> VERDICT: previous session's stale attempts all resolved (no hard panic from this path).")
			crumb(">>> last result was: " .. lastResult)
		else
			crumb(">>> VERDICT: previous session never reached a stale attempt (no teleport happened?).")
		end
	else
		crumb("################### NEW PROBE SESSION (fresh log) ###################")
	end
else
	crumb("WARNING: no writefile/readfile -- cross-crash detection disabled, watch the console output instead.")
end

------------------------------------------------------------------- find the exact closure Aero caches
-- same filter Aero uses: a Lua (non-C, non-executor) closure named "Roll" or "Sprint" that has upvalues.
local function findGameClosure()
	for _, v in next, getgc() do
		if type(v) ~= "function" or isccl(v) or isexe(v) then
			continue
		end
		local okInfo, info = pcall(getinfo, v)
		local name = okInfo and info and info.name
		if name ~= "Roll" and name ~= "Sprint" then
			continue
		end
		local okU, ups = pcall(getupvalues, v)
		if okU and ups and next(ups) ~= nil then
			return v, name
		end
	end
	return nil
end

local staleClosure, staleName

-- Cache the closure once (and only once). Retried below until the character's controller actually exists,
-- because right after inject the Roll/Sprint closures aren't in getgc yet.
local function tryCache(ctx)
	if staleClosure then
		return true
	end
	local c, n = findGameClosure()
	if c then
		staleClosure, staleName = c, n
		crumb(("cached game closure %s (name=%s) [%s]"):format(tostring(c), tostring(n), ctx))
		return true
	end
	return false
end

------------------------------------------------------------------- the test
-- control: re-find a FRESH closure in whatever DataModel we're in now and getupvalues it. this proves
-- getupvalues ITSELF is healthy in the current DataModel, so a stale failure is about staleness, not the call.
local function controlTest(tag)
	local fresh = findGameClosure()
	if not fresh then
		crumb(tag .. " CONTROL: no fresh closure found in current DataModel")
		return
	end
	crumb(tag .. " CONTROL ATTEMPT getupvalues(fresh=" .. tostring(fresh) .. ")")
	local ok = pcall(getupvalues, fresh)
	crumb(tag .. " CONTROL RESULT ok=" .. tostring(ok) .. (fresh == staleClosure and " (same ptr as cached)" or " (different ptr)"))
end

-- the risky one: getupvalues on the pointer we cached BEFORE the swap. ATTEMPT hits disk first; if the
-- client hard-panics inside getupvalues, RESULT never gets written -> that gap is the proof.
local function staleTest(tag)
	if not staleClosure then
		crumb(tag .. " STALE SKIP: nothing was cached")
		return
	end
	crumb(tag .. " STALE ATTEMPT getupvalues(cached=" .. tostring(staleClosure) .. ")")
	local ok, res = pcall(getupvalues, staleClosure)
	if ok then
		crumb(tag .. " STALE RESULT returned ok (type=" .. typeof(res) .. ") -- SAFE, no panic no error")
	else
		crumb(tag .. " STALE RESULT catchable-error: " .. tostring(res) .. " -- ERROR not panic")
	end
end

-- Arm on a spawned thread so we can WAIT for LocalPlayer + the character's controller before touching them
-- (running a split-second after inject is why the first run hit a nil LocalPlayer and an empty getgc).
task.spawn(function()
	local t0 = os.clock()
	while not players.LocalPlayer and os.clock() - t0 < 30 do
		task.wait()
	end
	local lp = players.LocalPlayer
	if not lp then
		crumb("FATAL: no LocalPlayer after 30s -- run this once you're actually in a server.")
		return
	end

	-- Retry the capture until the Roll/Sprint closures exist in getgc (spawn/controller init). Bounded.
	for i = 1, 60 do
		if tryCache("init-try-" .. i) then
			break
		end
		task.wait(0.5)
	end
	if not staleClosure then
		crumb("no Roll/Sprint closure after ~30s -- will capture on the first CharacterAdded instead.")
	end

	-- baseline, same DataModel, right now -- should always be fine.
	staleTest("T0-same-DM")

	-- every CharacterAdded after this point means a NEW DataModel is up and the old one (where the cached
	-- closure lived) is gone -- the exact moment Aero's cache would be dangling.
	lp.CharacterAdded:Connect(function()
		crumb("---- CharacterAdded fired: old DataModel should now be torn down ----")
		if not staleClosure then
			-- Nothing was cached before this swap, so there's nothing stale to test yet -- capture now so the
			-- NEXT teleport is a real stale test.
			tryCache("first-capture-on-swap")
			crumb("note: first capture happened on this swap, so T1 here is same-DM, not stale. next teleport is the real test.")
		end
		controlTest("T1-after-swap") -- fresh closure works?
		staleTest("T1-after-swap") -- stale closure: safe / error / PANIC?

		-- force a GC pass then retry, in case the old Proto is only freed on a later collection.
		crumb("forcing collectgarbage() then retrying stale...")
		pcall(collectgarbage, "collect")
		staleTest("T2-after-gc")

		-- and a couple delayed retries, in case the free is deferred a few frames.
		task.delay(3, function()
			staleTest("T3-plus3s")
		end)
		task.delay(8, function()
			staleTest("T4-plus8s")
		end)
	end)

	crumb("probe armed. now teleport (region/dungeon). read the verdict on next run, or send the log after a crash.")
end)
