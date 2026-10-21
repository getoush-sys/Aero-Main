local JSON = require("Utility/JSON")
local Filesystem = require("Utility/Filesystem")
local Logger = require("Utility/Logger")

local storage = Filesystem.new("Aero/Spotify")

local DEBUG = false
local function dbg(fmt, ...)
	if DEBUG then
		Logger.warn("[Spotify] " .. fmt, ...)
	end
end

local SpotifyClient = {}

local CLIENT_ID = "70dfc46fe4294dfcb51b5879f021f9d1"

local REDIRECT_URI = "http://127.0.0.1:8888/callback"
local SCOPES = "user-read-playback-state user-modify-playback-state user-read-currently-playing"
local TOKEN_URL = "https://accounts.spotify.com/api/token"
local API_BASE = "https://api.spotify.com/v1/me/player"

local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VERIFIER_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

local state = {
	clientId = CLIENT_ID,
	refreshToken = "",
	codeVerifier = nil,
	accessToken = nil,
	accessTokenExpiresAt = 0,
}

local function base64Encode(input)
	local out = {}
	local length = #input

	for i = 1, length, 3 do
		local b1, b2, b3 = string.byte(input, i, i + 2)
		b2 = b2 or 0
		b3 = b3 or 0

		local n = b1 * 65536 + b2 * 256 + b3

		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64

		local chunk = string.sub(BASE64_CHARS, c1 + 1, c1 + 1)
			.. string.sub(BASE64_CHARS, c2 + 1, c2 + 1)
			.. (i + 1 <= length and string.sub(BASE64_CHARS, c3 + 1, c3 + 1) or "=")
			.. (i + 2 <= length and string.sub(BASE64_CHARS, c4 + 1, c4 + 1) or "=")

		table.insert(out, chunk)
	end

	return table.concat(out)
end

local function base64UrlEncode(input)
	return (base64Encode(input):gsub("[+/=]", { ["+"] = "-", ["/"] = "_", ["="] = "" }))
end

local function urlEncode(value)
	return (tostring(value):gsub("[^%w%-%.%_%~]", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

local function encodeForm(fields)
	local parts = {}
	for key, value in next, fields do
		table.insert(parts, urlEncode(key) .. "=" .. urlEncode(value))
	end
	return table.concat(parts, "&")
end

local SHA256_K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function sha256(msg)
	local band, bxor, bnot, rshift, rrotate = bit32.band, bit32.bxor, bit32.bnot, bit32.rshift, bit32.rrotate

	local h0, h1, h2, h3, h4, h5, h6, h7 =
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

	local msgLen = #msg
	local bitLen = msgLen * 8

	msg = msg .. "\128"
	while #msg % 64 ~= 56 do
		msg = msg .. "\0"
	end

	for i = 7, 0, -1 do
		msg = msg .. string.char(band(rshift(bitLen, i * 8), 0xFF))
	end

	for chunkStart = 1, #msg, 64 do
		local w = {}
		for i = 0, 15 do
			local o = chunkStart + i * 4
			local b1, b2, b3, b4 = string.byte(msg, o, o + 3)
			w[i + 1] = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
		end

		for i = 17, 64 do
			local w15, w2 = w[i - 15], w[i - 2]
			local s0 = bxor(rrotate(w15, 7), rrotate(w15, 18), rshift(w15, 3))
			local s1 = bxor(rrotate(w2, 17), rrotate(w2, 19), rshift(w2, 10))
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % 4294967296
		end

		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7

		for i = 1, 64 do
			local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local temp1 = (h + S1 + ch + SHA256_K[i] + w[i]) % 4294967296
			local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local temp2 = (S0 + maj) % 4294967296

			h, g, f = g, f, e
			e = (d + temp1) % 4294967296
			d, c, b = c, b, a
			a = (temp1 + temp2) % 4294967296
		end

		h0 = (h0 + a) % 4294967296
		h1 = (h1 + b) % 4294967296
		h2 = (h2 + c) % 4294967296
		h3 = (h3 + d) % 4294967296
		h4 = (h4 + e) % 4294967296
		h5 = (h5 + f) % 4294967296
		h6 = (h6 + g) % 4294967296
		h7 = (h7 + h) % 4294967296
	end

	local out = {}
	for _, v in next, { h0, h1, h2, h3, h4, h5, h6, h7 } do
		out[#out + 1] = string.char(
			band(rshift(v, 24), 0xFF),
			band(rshift(v, 16), 0xFF),
			band(rshift(v, 8), 0xFF),
			band(v, 0xFF)
		)
	end

	return table.concat(out)
end

local function generateCodeVerifier()
	local rng = Random.new()
	local chars = {}
	for i = 1, 64 do
		local idx = rng:NextInteger(1, #VERIFIER_CHARS)
		chars[i] = VERIFIER_CHARS:sub(idx, idx)
	end
	return table.concat(chars)
end

function SpotifyClient.load()
	if not storage:file("auth.json") then
		return
	end

	local ok, decoded = pcall(JSON.decode, storage:read("auth.json"))
	if not ok or type(decoded) ~= "table" then
		return
	end

	if type(decoded.clientId) == "string" and decoded.clientId ~= "" then
		state.clientId = decoded.clientId
	end
	state.refreshToken = decoded.refreshToken or ""
end

function SpotifyClient.save()
	storage:write(
		"auth.json",
		JSON.encode({
			clientId = state.clientId,
			refreshToken = state.refreshToken,
		})
	)
end

function SpotifyClient.setClientId(clientId)
	if clientId and clientId ~= "" then
		state.clientId = clientId
		SpotifyClient.save()
	end
end

function SpotifyClient.getClientId()
	return state.clientId
end

function SpotifyClient.isAuthorized()
	return state.refreshToken ~= ""
end

function SpotifyClient.getAuthUrl()
	state.codeVerifier = generateCodeVerifier()
	local codeChallenge = base64UrlEncode(sha256(state.codeVerifier))

	return "https://accounts.spotify.com/authorize?"
		.. encodeForm({
			client_id = state.clientId,
			response_type = "code",
			redirect_uri = REDIRECT_URI,
			scope = SCOPES,
			code_challenge_method = "S256",
			code_challenge = codeChallenge,
		})
end

local function extractCode(pastedUrl)
	return pastedUrl:match("[?&]code=([^&#]+)")
end

function SpotifyClient.completeAuth(pastedUrl)
	if not state.codeVerifier then
		return false, "Click 'Copy Auth URL' first -- authorization needs to start from there."
	end

	local code = extractCode(pastedUrl)
	if not code then
		return false, "Couldn't find a 'code' parameter in that URL."
	end

	local response = request({
		Url = TOKEN_URL,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/x-www-form-urlencoded",
		},
		Body = encodeForm({
			grant_type = "authorization_code",
			code = code,
			redirect_uri = REDIRECT_URI,
			client_id = state.clientId,
			code_verifier = state.codeVerifier,
		}),
	})

	state.codeVerifier = nil

	if not response or not response.Success then
		return false, "Token exchange request failed."
	end

	local ok, decoded = pcall(JSON.decode, response.Body)
	if not ok or not decoded or not decoded.refresh_token then
		return false, "Token exchange returned an unexpected response."
	end

	state.refreshToken = decoded.refresh_token
	state.accessToken = decoded.access_token
	state.accessTokenExpiresAt = os.clock() + (decoded.expires_in or 3600) - 30
	SpotifyClient.save()

	return true
end

local function refreshAccessToken()
	if state.refreshToken == "" then
		return false
	end

	local response = request({
		Url = TOKEN_URL,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/x-www-form-urlencoded",
		},
		Body = encodeForm({
			grant_type = "refresh_token",
			refresh_token = state.refreshToken,
			client_id = state.clientId,
		}),
	})

	if not response or not response.Success then
		return false
	end

	local ok, decoded = pcall(JSON.decode, response.Body)
	if not ok or not decoded or not decoded.access_token then
		return false
	end

	state.accessToken = decoded.access_token
	state.accessTokenExpiresAt = os.clock() + (decoded.expires_in or 3600) - 30

	if decoded.refresh_token then
		state.refreshToken = decoded.refresh_token
		SpotifyClient.save()
	end

	return true
end

local function ensureToken()
	if state.accessToken and os.clock() < state.accessTokenExpiresAt then
		return true
	end

	return refreshAccessToken()
end

local function authorizedRequest(method, path, body)
	if not ensureToken() then
		dbg("%s %s: ensureToken() failed, no valid access token", method, path)
		return nil
	end

	local response = request({
		Url = API_BASE .. path,
		Method = method,
		Headers = {
			["Authorization"] = "Bearer " .. state.accessToken,
			["Content-Type"] = "application/json",
		},
		Body = body or "{}",
	})

	if not response then
		dbg("%s %s: request() returned nil", method, path)
	elseif not response.Success then
		dbg("%s %s: failed, status=%s body=%s", method, path, tostring(response.StatusCode), tostring(response.Body))
	else
		dbg("%s %s: ok, status=%s", method, path, tostring(response.StatusCode))
	end

	return response
end

function SpotifyClient.getCurrentlyPlaying()
	local response = authorizedRequest("GET", "/currently-playing")
	if not response or not response.Success or response.StatusCode == 204 or not response.Body or response.Body == "" then
		return nil
	end

	local ok, decoded = pcall(JSON.decode, response.Body)
	if not ok or not decoded or not decoded.item then
		return nil
	end

	local images = decoded.item.album and decoded.item.album.images or {}
	local artists = {}
	for _, artist in next, decoded.item.artists or {} do
		table.insert(artists, artist.name)
	end

	return {
		trackId = decoded.item.id,
		trackName = decoded.item.name,
		artistName = table.concat(artists, ", "),
		albumArtUrl = images[1] and images[1].url,
		progressMs = decoded.progress_ms or 0,
		durationMs = decoded.item.duration_ms or 0,
		isPlaying = decoded.is_playing or false,
	}
end

function SpotifyClient.play()
	authorizedRequest("PUT", "/play")
end

function SpotifyClient.pause()
	authorizedRequest("PUT", "/pause")
end

function SpotifyClient.next()
	authorizedRequest("POST", "/next")
end

function SpotifyClient.previous()
	authorizedRequest("POST", "/previous")
end

function SpotifyClient.seek(positionMs)
	authorizedRequest("PUT", "/seek?position_ms=" .. math.floor(positionMs))
end

SpotifyClient.load()

return SpotifyClient
