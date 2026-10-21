return LPH_NO_VIRTUALIZE(function()
	local Profiler = {}

	-- Opt-in: set getgenv().LycorisProfile = true before executing. When off, run/wrap are
	-- pass-throughs with no overhead.
	local enabled = getgenv ~= nil and getgenv().LycorisProfile == true
	local reportInterval = 10.0
	local stats = {}

	local function record(label, start)
		local elapsed = os.clock() - start
		local entry = stats[label]

		if not entry then
			entry = { total = 0, calls = 0, max = 0 }
			stats[label] = entry
		end

		entry.total = entry.total + elapsed
		entry.calls = entry.calls + 1

		if elapsed > entry.max then
			entry.max = elapsed
		end
	end

	---Runs a function, forwarding all return values.
	---@param label string
	---@param functionToProfile function
	function Profiler.run(label, functionToProfile, ...)
		if not enabled then
			return functionToProfile(...)
		end

		local start = os.clock()
		local results = table.pack(functionToProfile(...))
		record(label, start)
		return table.unpack(results, 1, results.n)
	end

	---Wrap function to match Profiler.run signature.
	---@param label string
	---@param functionToProfile function
	---@return function
	function Profiler.wrap(label, functionToProfile)
		if not enabled then
			return functionToProfile
		end

		return function(...)
			return Profiler.run(label, functionToProfile, ...)
		end
	end

	---Print the most expensive labels since the last report, then reset.
	---@param count number?
	function Profiler.report(count)
		local sorted = {}

		for label, entry in next, stats do
			sorted[#sorted + 1] = { label = label, entry = entry }
		end

		table.sort(sorted, function(a, b)
			return a.entry.total > b.entry.total
		end)

		warn(string.format("[Profiler] Top labels over the last %.0fs (total ms / calls / avg ms / max ms):", reportInterval))

		for idx = 1, math.min(count or 15, #sorted) do
			local label = sorted[idx].label
			local entry = sorted[idx].entry

			warn(
				string.format(
					"[Profiler] %2d. %-48s %8.2f / %6d / %6.3f / %6.2f",
					idx,
					label,
					entry.total * 1000,
					entry.calls,
					(entry.total / entry.calls) * 1000,
					entry.max * 1000
				)
			)
		end

		table.clear(stats)
	end

	if enabled then
		task.spawn(function()
			while true do
				task.wait(reportInterval)
				Profiler.report()
			end
		end)
	end

	return Profiler
end)()
