-- Hardened ProximityPrompt firing.
--
-- Why this exists: bare `fireproximityprompt(prompt)` "works for some users and
-- fails for others" on the SAME executor because the failures are game-state, not
-- executor. Deepwoken runs with StreamingEnabled, so a prompt's part may not be
-- streamed in for a given client yet (slower stream = further away / lower memory /
-- lower graphics / fired too soon after a teleport), and firing against a
-- streamed-out part silently no-ops. On top of that the engine enforces
-- RequiresLineOfSight / MaxActivationDistance / Enabled / HoldDuration at trigger
-- time, and whether those bite depends on the player's camera, morph/accessories
-- obstructing the line of sight, and how the executor implements the function.
--
-- Prompt.fire() removes every one of those variables: it requests streaming around
-- the prompt, forces the prompt open (LOS off, huge distance, no hold, enabled),
-- fires, then restores the originals so the game's own UI/logic is untouched.
local Prompt = {}

local players = game:GetService("Players")

---Request the world region around a part to stream in, so the part is resident
---(has physics + a valid trigger) before we fire. No-op on non-streaming games.
---@param part BasePart?
local function ensureStreamedIn(part)
	if not part then
		return
	end
	local localPlayer = players.LocalPlayer
	if not localPlayer then
		return
	end
	pcall(function()
		if localPlayer.RequestStreamingAround then
			localPlayer:RequestStreamingAround(part.Position)
		end
	end)
end

---Fire a ProximityPrompt reliably.
---@param prompt Instance? A ProximityPrompt, or any instance to search under for one.
---@return boolean fired
function Prompt.fire(prompt)
	if not prompt then
		return false
	end

	-- Accept a model/part and dig out the prompt so callers don't have to.
	if not prompt:IsA("ProximityPrompt") then
		local found = prompt:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not found then
			return false
		end
		prompt = found
	end

	local part = prompt:FindFirstAncestorWhichIsA("BasePart") or prompt.Parent
	if typeof(part) == "Instance" and part:IsA("BasePart") then
		ensureStreamedIn(part)
	end

	local fireProx = fireproximityprompt

	local fired = false
	pcall(function()
		-- Snapshot the properties the engine checks at trigger time and force them
		-- into the state that always allows a fire. ProximityPrompt property writes
		-- from the client are local-only (never replicate), so this only affects our
		-- own trigger path and is restored immediately after.
		local origEnabled = prompt.Enabled
		local origLOS = prompt.RequiresLineOfSight
		local origDist = prompt.MaxActivationDistance
		local origHold = prompt.HoldDuration

		prompt.Enabled = true
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = math.max(origDist, 1000)
		prompt.HoldDuration = 0

		if fireProx then
			fireProx(prompt)
			fired = true
		elseif prompt.InputHoldBegin then
			prompt:InputHoldBegin()
			task.wait(origHold or 0)
			prompt:InputHoldEnd()
			fired = true
		end

		prompt.Enabled = origEnabled
		prompt.RequiresLineOfSight = origLOS
		prompt.MaxActivationDistance = origDist
		prompt.HoldDuration = origHold
	end)

	return fired
end

-- =========================================================================================================
-- Interact-key press (used by the automations instead of firing ProximityPrompts directly).
--
-- Rather than fireproximityprompt(), the automations press the real interact key -- like a human -- after
-- they've tweened to the target. The key is configurable under the Automations panel ("Interact Key",
-- default E). We still stream the target's part in and read its HoldDuration so a hold-prompt registers.
-- =========================================================================================================
local DEFAULT_INTERACT_KEY = Enum.KeyCode.E

local function resolveInteractKey()
	local picker = Options and Options.AutomationInteractKey
	local name = picker and picker.Value
	if type(name) == "string" and name ~= "" and name ~= "None" and name ~= "N/A" then
		local ok, code = pcall(function()
			return Enum.KeyCode[name]
		end)
		if ok and code then
			return code
		end
	end
	return DEFAULT_INTERACT_KEY
end

---Press the configured interact key. `prompt` is optional, used only to stream the target in and read its
---HoldDuration (so a hold-prompt is held long enough); the actual interaction is the key press.
---@param prompt Instance?
---@return boolean pressed
function Prompt.interact(prompt)
	local holdDuration = 0

	if typeof(prompt) == "Instance" then
		local resolved = prompt
		if not resolved:IsA("ProximityPrompt") then
			resolved = resolved:FindFirstChildWhichIsA("ProximityPrompt", true)
		end
		if resolved and resolved:IsA("ProximityPrompt") then
			holdDuration = resolved.HoldDuration or 0
			local part = resolved:FindFirstAncestorWhichIsA("BasePart")
			if part then
				ensureStreamedIn(part)
			end
		elseif prompt:IsA("BasePart") then
			ensureStreamedIn(prompt)
		end
	end

	local key = resolveInteractKey()
	local pressed = false
	pcall(function()
		local vim = Instance.new("VirtualInputManager")
		vim:SendKeyEvent(true, key, false, game)
		task.wait(holdDuration + 0.06)
		vim:SendKeyEvent(false, key, false, game)
		pressed = true
	end)
	return pressed
end

return Prompt
