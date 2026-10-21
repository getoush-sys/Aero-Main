---@note: Shared "Aero is firing this remote itself" flag. It replaces checkcaller() inside the process-global
---@note: FireServer hooks. checkcaller() is executor reflection, and when the game fires an attack remote from
---@note: its parallel Actor VM the process-global hook runs there -- reflection mid-parallel-phase is the illegal
---@note: cross-phase op the engine Kernel-panics on (RSL - panic ...Kernel,2090), the same class as the old
---@note: getgc-in-tostring crash. Project Rain never calls checkcaller in a process-global hook; it distinguishes
---@note: its own fires by STATE. So do we: Aero sets this flag around its own attack re-fires, and the hook reads
---@note: the flag -- a plain boolean, no reflection, safe to read from any VM -- instead of checkcaller().

local SelfFire = { active = false }

---Run fn with the self-fire flag raised, always lowering it again (even if fn errors). Use this to wrap Aero's
---own fires of a remote the FireServer hooks intercept, so the hook treats them as ours and passes them through.
---@param fn function
function SelfFire.wrap(fn)
	SelfFire.active = true

	local ok, err = pcall(fn)

	SelfFire.active = false

	if not ok then
		error(err, 0)
	end
end

return SelfFire
