-- threadcount.lua -- standalone, NOT Aero. paste straight into your executor.
-- counts every coroutine the Lua GC is holding, broken down by status, so you can WATCH
-- a fiber leak climb: suspended going up and never coming back = threads spawned that
-- never finish (that's what feeds the "failed to spawn a fiber" panic).

local getgc = getgc or (debug and debug.getgc)
assert(type(getgc) == "function", "this executor doesn't expose getgc")

-- one pass over the GC -> (total, suspended, running, normal, dead)
local function snapshot()
	local total, suspended, running, normal, dead = 0, 0, 0, 0, 0
	for _, v in ipairs(getgc()) do          -- default getgc() = functions/threads/userdata, no tables (cheap)
		if type(v) == "thread" then
			total += 1
			local st = coroutine.status(v)
			if st == "suspended" then
				suspended += 1
			elseif st == "running" then
				running += 1
			elseif st == "normal" then
				normal += 1
			elseif st == "dead" then
				dead += 1
			end
		end
	end
	return total, suspended, running, normal, dead
end

-- one-shot, right now
local base = snapshot()
print(("[threads] %d total to start"):format(base))

-- live monitor: re-print every second with the delta from that first sample, so growth is
-- obvious at a glance. kill the script (or comment this block out) when you're done.
while true do
	local total, suspended, running, normal, dead = snapshot()
	print(("[threads] %d total (%+d) | %d suspended | %d running | %d dead")
		:format(total, total - base, suspended, running, dead))
	task.wait(1)
end
