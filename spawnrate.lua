-- spawnrate.lua -- standalone, NOT Aero. Inject Aero FIRST, then paste this into your executor.
--
-- threadcount.lua counts LIVE coroutines via getgc, which returns 0 on Volt (it doesn't expose thread
-- objects). This measures the other half instead: how many fibers get CREATED per second. A sustained
-- high creation rate is the real fingerprint of the "failed to spawn a fiber" / scheduler-panic class,
-- and it needs no getgc -- it hooks the task primitives, so it catches every task.spawn/defer/delay Aero
-- or the game makes (EffectDispatcher spawns one per hook per effect, and effects fire constantly even
-- while AFK, so anything flooding the scheduler will light this up).
--
-- NOTE: it does NOT catch engine-created signal-dispatch fibers (the fresh fiber each :Connect handler
-- runs on) -- there's no Lua hook for those. But Aero's explicit task.* spawns are the ones Aero controls
-- and could be over-firing, and those are exactly what this measures.

local hookfunction = hookfunction or hookfunc or (syn and syn.hook_function)
assert(type(hookfunction) == "function", "this executor doesn't expose hookfunction")

local counts = { spawn = 0, defer = 0, delay = 0 }

local function tap(name, fn)
	if type(fn) ~= "function" then
		return
	end
	pcall(function()
		local orig
		orig = hookfunction(fn, function(...)
			counts[name] += 1
			return orig(...)
		end)
	end)
end

tap("spawn", task.spawn)
tap("defer", task.defer)
tap("delay", task.delay)

print("[spawnrate] hooked task.spawn/defer/delay -- go AFK, nothing on, and watch the per-second rate.")

local peak = 0
while true do
	task.wait(1)
	local total = counts.spawn + counts.defer + counts.delay
	if total > peak then
		peak = total
	end
	print(("[spawnrate] %d/s  (spawn %d  defer %d  delay %d)  peak %d/s")
		:format(total, counts.spawn, counts.defer, counts.delay, peak))
	counts.spawn, counts.defer, counts.delay = 0, 0, 0
end
