local KeyHandling = {}

---@module Utility.Logger
local Logger = require("Utility/Logger")

-- KeyHandler bypass, project-rain-oss style. Aero used to REIMPLEMENT the game's name-encoder
-- (a full SHA-256) and recompute keys itself -- fragile: the moment the game changes its encoding
-- or keying, every keyed remote silently fails to resolve. Instead we grab the game's OWN encoder
-- and remote table straight out of its live KeyHandler state via getgc, so we always match whatever
-- the game is doing (it's been actively reworking this -- remotes like Dodge/Sprint have left the
-- key system entirely).
--
-- The KeyHandler state table is tagged with a magic constant at index 9 ("heaven key"), and carries
-- the encoded-name -> remote map at [12] and the encoder function at [13]. The heaven_key expression
-- is reproduced verbatim from project-rain-oss so the float value matches the game's byte-for-byte.

local pi = 0.125 + tonumber("3")
local heaven_key = 2754 * (72 % (0.6769230769205024 * 7 * 7 % 5 % 64 % 41 / 66 + 12) / 54 / (4 / 36 + 5.3655660377358485) + 1 * 4 % 52 * 21 / 4 % 35 / 3) / 35 * 38 + (66 + (8 + 4 + 5 + 2 + 19035.52631578947) / 34 + 40 % 41 / 56 % 65 * 57 + 3381) + 420 + 35 * (0.3150684931506849 + 69 + 14 / 56 + 28 + 36) + (pi)

local remotes = nil -- the game's encoded-name -> remote instance table (state[12])
local encf = nil    -- the game's name-encoder function (state[13])
local cache = {}    -- remoteName -> encoded key

---Find the game's KeyHandler state in getgc (identified by the heaven_key tag at index 9) and grab
---its remotes table + encoder.
---@return boolean
local function grabKeyHandler()
	for _, tbl in next, getgc(true) do
		if typeof(tbl) ~= "table" then
			continue
		end
		if getrawmetatable(tbl) then
			continue
		end
		if #tbl ~= 13 or tbl[9] ~= heaven_key then
			continue
		end

		remotes = tbl[12]
		encf = tbl[13]
		return remotes ~= nil and encf ~= nil
	end

	return false
end

---Encode a remote name with the game's own encoder (cached).
---@param remoteName string
---@return any
local function encode(remoteName)
	local encoded = cache[remoteName]
	if encoded == nil then
		local ok, res = pcall(encf, remoteName)
		if not ok then
			return nil
		end
		encoded = res
		cache[remoteName] = encoded
	end
	return encoded
end

KeyHandling.init = LPH_NO_VIRTUALIZE(function()
	local retries = 0

	while true do
		if (remotes and encf) or grabKeyHandler() then
			break
		end

		if not LPH_OBFUSCATED or shared.Aero.verbose then
			Logger.warn("KeyHandler retry (%i attempts) grabbing remotes/enc_f", retries)
		end

		retries = retries + 1

		if retries >= 10 then
			Logger.warn("KeyHandler failed to initialize after 10 attempts.")

			return error("Please report this message to the developers.")
		end

		task.wait(0.5)
	end
end)

---Resolve a keyed remote by its original name via the game's encoder.
---@param remoteName string
---@return Instance|nil
KeyHandling.getRemote = LPH_NO_VIRTUALIZE(function(remoteName)
	if not (remotes and encf) then
		return nil
	end

	local encoded = encode(remoteName)

	return (encoded ~= nil and remotes[encoded]) or nil
end)

---Resolve a keyed remote using ONLY the already-computed key cache -- it never calls the game's encoder.
---This is project-rain-oss's `get_cache`: the process-global FireServer / UnreliableFireServer hooks run on
---every remote fire the game makes, and PR only ever does pure table reads there (cache[name] -> remotes[key]).
---Aero used to call getRemote() -> encode() -> pcall(encf, ...) from those hooks, which re-invokes the game's
---grabbed encoder closure on every fire for any name that has left the key system (encode never caches a nil
---result, so it retries forever). That high-frequency game-closure call from the global hook body is the
---always-on divergence from PR. Resolving the keys once up front (KeyHandling.prewarm) and reading the cache
---here keeps the hot path to pure table lookups, exactly like PR. remotes[encoded] stays live, so re-keys are
---still followed; only the encoder call is lifted out of the hook.
---@param remoteName string
---@return Instance|nil
KeyHandling.getCachedRemote = LPH_NO_VIRTUALIZE(function(remoteName)
	if not remotes then
		return nil
	end

	local encoded = cache[remoteName]
	if encoded == nil then
		return nil
	end

	return remotes[encoded] or nil
end)

---Compute and cache the keys for a set of remote names once, from the current (main, synchronized) thread.
---Call this at init so the global fire hooks can resolve those remotes with getCachedRemote without ever
---touching the encoder from the hook context.
---@param names string[]
KeyHandling.prewarm = LPH_NO_VIRTUALIZE(function(names)
	if not (remotes and encf) then
		return
	end

	for _, remoteName in ipairs(names) do
		encode(remoteName)
	end
end)

---Register a remote under its (original) name's key, then it can be renamed by the caller.
---@param remote Instance
KeyHandling.registerRemote = LPH_NO_VIRTUALIZE(function(remote)
	if not (remotes and encf) then
		return
	end

	local encoded = encode(remote.Name)
	if encoded ~= nil then
		remotes[encoded] = remote
	end
end)

return KeyHandling
