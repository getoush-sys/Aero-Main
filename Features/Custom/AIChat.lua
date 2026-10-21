-- Conversational AI agent for the Custom tab. Keeps a message transcript, calls the configured provider
-- (OpenAI / Anthropic / Google) as a multi-turn chat, and runs a ReAct-style tool loop: the model asks
-- for a tool by replying with a JSON object, we run it against the live game (GameTools) and feed the
-- result back, repeating until the model gives a final answer. Provider-agnostic (plain chat, no native
-- function-calling), so it works the same across all three.

---@module Utility.JSON
local JSON = require("Utility/JSON")

---@module Features.Custom.GameTools
local GameTools = require("Features/Custom/GameTools")

---@module Features.Custom.Custom
local Custom = require("Features/Custom/Custom")

local AIChat = {}

local MAX_STEPS = 10

AIChat.busy = false
AIChat.lastCode = nil
AIChat.messages = nil
AIChat.current = nil -- active run token (for interrupt)

-- Stop the in-flight run. Takes effect between steps / mid-reveal (a blocking request() can't be aborted).
function AIChat.cancel()
	if AIChat.current then
		AIChat.current.cancelled = true
	end
end

local function httpRequest()
	return (syn and syn.request)
		or (http and http.request)
		or http_request
		or request
		or (getgenv and getgenv().request)
end

local function systemPrompt()
	return table.concat({
		"You are an expert assistant embedded in 'Aero', a menu for the Roblox game Deepwoken. You help the",
		"user understand the game and build custom features. You can inspect the LIVE game and decompile",
		"scripts via tools before answering, so prefer checking real data over guessing.",
		"",
		GameTools.API_REFERENCE,
		"",
		GameTools.TOOLS_DOC,
		"",
		"Be concise. When the user asks for a feature, inspect what you need, then give the final code in a",
		"single ```lua block using only the API above.",
	}, "\n")
end

function AIChat.reset()
	AIChat.messages = { { role = "system", content = systemPrompt() } }
	AIChat.lastCode = nil
end

local function ensureInit()
	if not AIChat.messages then
		AIChat.reset()
	end
end

-- ------------------------------------------------------------ provider chat completion (synchronous)
local function chatComplete(messages)
	local s = Custom.settings()
	local req = httpRequest()
	if not req then
		return false, "no HTTP request function on this executor"
	end
	if not s.apiKey or s.apiKey:gsub("%s", "") == "" then
		return false, "set your API key in the Custom tab first"
	end

	local provider = s.provider or "OpenAI"
	local model = (s.model and s.model:gsub("%s", "") ~= "" and s.model) or Custom.DEFAULT_MODELS[provider] or "gpt-4o-mini"

	local url, headers, body
	if provider == "Anthropic" then
		local system = {}
		local msgs = {}
		for _, m in ipairs(messages) do
			if m.role == "system" then
				system[#system + 1] = m.content
			else
				msgs[#msgs + 1] = { role = m.role, content = m.content }
			end
		end
		url = "https://api.anthropic.com/v1/messages"
		headers = {
			["x-api-key"] = s.apiKey,
			["anthropic-version"] = "2023-06-01",
			["Content-Type"] = "application/json",
		}
		body = JSON.encode({
			model = model,
			max_tokens = 4096,
			system = table.concat(system, "\n"),
			messages = msgs,
		})
	elseif provider == "Google" then
		local system = {}
		local contents = {}
		for _, m in ipairs(messages) do
			if m.role == "system" then
				system[#system + 1] = m.content
			else
				local role = (m.role == "assistant") and "model" or "user"
				contents[#contents + 1] = { role = role, parts = { { text = m.content } } }
			end
		end
		url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":generateContent?key=" .. s.apiKey
		headers = { ["Content-Type"] = "application/json" }
		body = JSON.encode({
			system_instruction = { parts = { { text = table.concat(system, "\n") } } },
			contents = contents,
		})
	else
		url = "https://api.openai.com/v1/chat/completions"
		headers = {
			["Authorization"] = "Bearer " .. s.apiKey,
			["Content-Type"] = "application/json",
		}
		body = JSON.encode({
			model = model,
			temperature = 0.3,
			messages = messages,
		})
	end

	local ok, res = pcall(req, { Url = url, Method = "POST", Headers = headers, Body = body })
	if not ok or type(res) ~= "table" then
		return false, "request failed: " .. tostring(res)
	end
	local status = res.StatusCode or res.Status or 0
	if type(res.Body) ~= "string" or res.Body == "" then
		return false, "empty response (status " .. tostring(status) .. ")"
	end
	local decodeOk, decoded = pcall(JSON.decode, res.Body)
	if not decodeOk or type(decoded) ~= "table" then
		return false, "bad JSON (status " .. tostring(status) .. ")"
	end
	if decoded.error then
		local msg = type(decoded.error) == "table" and decoded.error.message or tostring(decoded.error)
		return false, "api error: " .. tostring(msg)
	end

	local content
	if provider == "Anthropic" then
		if decoded.content then
			local parts = {}
			for _, p in ipairs(decoded.content) do
				if p.type == "text" and p.text then
					parts[#parts + 1] = p.text
				end
			end
			content = table.concat(parts)
		end
	elseif provider == "Google" then
		local cand = decoded.candidates and decoded.candidates[1]
		if cand and cand.content and cand.content.parts then
			local parts = {}
			for _, p in ipairs(cand.content.parts) do
				if p.text then
					parts[#parts + 1] = p.text
				end
			end
			content = table.concat(parts)
		end
	else
		content = decoded.choices and decoded.choices[1] and decoded.choices[1].message and decoded.choices[1].message.content
	end

	if type(content) ~= "string" or content:gsub("%s", "") == "" then
		return false, "no content in response (status " .. tostring(status) .. ")"
	end
	return true, content
end

-- ------------------------------------------------------------ parsing
local function stripFence(text)
	local inner = text:match("^%s*```[%w]*%s*\n(.-)\n?%s*```%s*$")
	return inner or text
end

local function parseToolCall(text)
	local t = stripFence(text)
	t = t:gsub("^%s+", ""):gsub("%s+$", "")
	if t:sub(1, 1) ~= "{" then
		return nil
	end
	local ok, decoded = pcall(JSON.decode, t)
	if ok and type(decoded) == "table" and type(decoded.tool) == "string" then
		return { tool = decoded.tool, args = type(decoded.args) == "table" and decoded.args or {} }
	end
	return nil
end

local function extractCode(text)
	local c = text:match("```lua%s*\n(.-)```") or text:match("```%s*\n(.-)```")
	if c and c:gsub("%s", "") ~= "" then
		return c
	end
	return nil
end
AIChat.extractCode = extractCode

-- Reveal the final answer progressively (typewriter). request() returns the whole body at once, so this
-- is a cosmetic reveal, interruptible via the run token. Chunk size scales with length (~160 ticks total).
local function streamOut(text, onEvent, token)
	AIChat.lastCode = extractCode(text) or AIChat.lastCode
	onEvent("assistant_begin")
	local n = #text
	local chunkSize = math.max(2, math.floor(n / 160))
	local i = 1
	while i <= n do
		if token.cancelled then
			onEvent("assistant_delta", text:sub(i)) -- reveal the remainder instantly on stop
			break
		end
		onEvent("assistant_delta", text:sub(i, i + chunkSize - 1))
		i = i + chunkSize
		task.wait(0.012)
	end
	onEvent("assistant_end")
end

-- ------------------------------------------------------------ agent loop
---@param userText string
---@param onEvent fun(kind: string, text: string?)
-- kinds: user, assistant_begin, assistant_delta, assistant_end, tool, toolresult, error, status, done
function AIChat.send(userText, onEvent)
	ensureInit()
	if AIChat.busy then
		onEvent("error", "still working on the previous message...")
		return
	end
	if type(userText) ~= "string" or userText:gsub("%s", "") == "" then
		return
	end

	local token = { cancelled = false }
	AIChat.current = token
	AIChat.busy = true
	table.insert(AIChat.messages, { role = "user", content = userText })
	onEvent("user", userText)

	task.spawn(function()
		local steps = 0
		local finished = false
		while steps < MAX_STEPS do
			if token.cancelled then
				onEvent("status", "stopped.")
				finished = true
				break
			end
			steps = steps + 1
			onEvent("status", steps > 1 and ("thinking... (step " .. steps .. ")") or "thinking...")

			local ok, text = chatComplete(AIChat.messages)
			if token.cancelled then
				onEvent("status", "stopped.")
				finished = true
				break
			end
			if not ok then
				onEvent("error", text)
				finished = true
				break
			end

			table.insert(AIChat.messages, { role = "assistant", content = text })

			local call = parseToolCall(text)
			if call then
				local argsStr = ""
				pcall(function()
					argsStr = JSON.encode(call.args)
				end)
				onEvent("tool", call.tool .. " " .. argsStr)
				local result = GameTools.run(call.tool, call.args)
				onEvent("toolresult", result)
				table.insert(AIChat.messages, {
					role = "user",
					content = "TOOL RESULT (" .. call.tool .. "):\n" .. result,
				})
			else
				streamOut(text, onEvent, token)
				finished = true
				break
			end
		end

		if not finished then
			onEvent("error", "reached the tool-step limit; ask again or be more specific")
		end

		AIChat.busy = false
		AIChat.current = nil
		onEvent("done")
	end)
end

return AIChat
