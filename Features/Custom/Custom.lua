-- Manager for user-built custom features: storage (workspace files), sandboxed execution via CustomAPI,
-- and optional AI code generation (OpenAI / Anthropic / Google) against a described Aero feature API.

---@module Utility.Filesystem
local Filesystem = require("Utility/Filesystem")

---@module Utility.JSON
local JSON = require("Utility/JSON")

---@module Features.Custom.CustomAPI
local CustomAPI = require("Features/Custom/CustomAPI")

---@module Utility.Logger
local Logger = require("Utility/Logger")

local Custom = {}

local storage = Filesystem.new("Aero/Custom")

local host = nil -- the panel widgets render into (set by CustomTab)
local running = {} -- name -> CustomAPI instance
local settingsCache = nil

local DEFAULT_SETTINGS = {
	provider = "OpenAI",
	model = "gpt-4o-mini",
	apiKey = "",
	autorun = {},
}

Custom.PROVIDERS = { "OpenAI", "Anthropic", "Google" }
Custom.DEFAULT_MODELS = {
	OpenAI = "gpt-4o-mini",
	Anthropic = "claude-3-5-sonnet-latest",
	Google = "gemini-1.5-flash",
}

Custom.TEMPLATE = table.concat({
	"-- Custom feature. The Aero API is available as globals (and under `Aero`).",
	"-- Widgets appear in a section on the right; everything is cleaned up on reload.",
	"",
	'local enabled = Toggle("Enabled", function(on)',
	'    Notify(on and "Enabled" or "Disabled")',
	"end)",
	"",
	'Slider("Speed", { min = 16, max = 200, default = 16, callback = function(v)',
	"    local hum = Humanoid()",
	"    if hum then hum.WalkSpeed = v end",
	"end })",
	"",
	"OnRender(function()",
	"    if not enabled.get() then return end",
	"    -- runs every frame while this feature is loaded",
	"end)",
}, "\n")

-- ------------------------------------------------------------ settings
function Custom.settings()
	if settingsCache then
		return settingsCache
	end
	local data = nil
	pcall(function()
		if storage:file("settings.json") then
			local ok, decoded = pcall(JSON.decode, storage:read("settings.json"))
			if ok and type(decoded) == "table" then
				data = decoded
			end
		end
	end)
	data = data or {}
	for k, v in pairs(DEFAULT_SETTINGS) do
		if data[k] == nil then
			data[k] = v
		end
	end
	if type(data.autorun) ~= "table" then
		data.autorun = {}
	end
	settingsCache = data
	return data
end

function Custom.saveSettings()
	local s = Custom.settings()
	pcall(function()
		storage:write("settings.json", JSON.encode(s))
	end)
end

function Custom.setSetting(key, value)
	local s = Custom.settings()
	s[key] = value
	Custom.saveSettings()
end

-- ------------------------------------------------------------ storage
---@return string[]
function Custom.list()
	local out = {}
	pcall(function()
		for _, filename in ipairs(storage:list()) do
			if type(filename) == "string" and filename:sub(-4) == ".lua" then
				out[#out + 1] = filename:sub(1, #filename - 4)
			end
		end
	end)
	table.sort(out)
	return out
end

---@param name string
---@return string?
function Custom.load(name)
	local source
	pcall(function()
		if storage:file(name .. ".lua") then
			source = storage:read(name .. ".lua")
		end
	end)
	return source
end

---@param name string
---@param source string
---@return boolean ok, string? err
function Custom.save(name, source)
	if type(name) ~= "string" or name:gsub("%s", "") == "" then
		return false, "invalid name"
	end
	-- Keep filenames flat/safe.
	name = name:gsub("[\\/:*?\"<>|]", "_")
	local ok, err = pcall(function()
		storage:write(name .. ".lua", source or "")
	end)
	if not ok then
		return false, tostring(err)
	end
	return true
end

---@param name string
function Custom.delete(name)
	Custom.stop(name)
	pcall(function()
		if storage:file(name .. ".lua") then
			storage:delete(name .. ".lua")
		end
	end)
	local s = Custom.settings()
	if s.autorun[name] then
		s.autorun[name] = nil
		Custom.saveSettings()
	end
end

-- ------------------------------------------------------------ execution
function Custom.setHost(panel)
	host = panel
end

function Custom.isRunning(name)
	return running[name] ~= nil
end

function Custom.runningNames()
	local out = {}
	for name in pairs(running) do
		out[#out + 1] = name
	end
	table.sort(out)
	return out
end

function Custom.stop(name)
	local inst = running[name]
	if inst then
		pcall(inst.destroy)
		running[name] = nil
	end
end

function Custom.stopAll()
	for name in pairs(running) do
		Custom.stop(name)
	end
end

---Run (or re-run) a feature's source. Cleans any previous instance of the same name first.
---@param name string
---@param source string
---@return boolean ok, string? err
function Custom.run(name, source)
	if not host then
		return false, "custom panel not ready"
	end

	Custom.stop(name)

	local chunk, compileErr = loadstring(source)
	if not chunk then
		local clean = tostring(compileErr):gsub('^%[string "[^"]*"%]:', "line ")
		return false, "syntax: " .. clean
	end

	local inst = CustomAPI.new(host, name)
	pcall(setfenv, chunk, inst.env)

	local ranOk, runErr = pcall(chunk)
	if not ranOk then
		pcall(inst.destroy)
		local clean = tostring(runErr):gsub('^%[string "[^"]*"%]:', "line ")
		return false, "runtime: " .. clean
	end

	running[name] = inst
	return true
end

function Custom.setAutorun(name, on)
	local s = Custom.settings()
	s.autorun[name] = on and true or nil
	Custom.saveSettings()
end

function Custom.isAutorun(name)
	return Custom.settings().autorun[name] == true
end

-- Run every feature flagged autorun (called by CustomTab once the host panel exists).
function Custom.autorunAll()
	local s = Custom.settings()
	for name in pairs(s.autorun) do
		local source = Custom.load(name)
		if source then
			local ok, err = Custom.run(name, source)
			if not ok then
				Logger.notify("[Custom] autorun '%s' failed: %s", tostring(name), tostring(err))
			end
		end
	end
end

-- ------------------------------------------------------------ AI code generation
local function httpRequest()
	return (syn and syn.request)
		or (http and http.request)
		or http_request
		or request
		or (getgenv and getgenv().request)
end

local API_REFERENCE = table.concat({
	"You write Luau code for the Roblox game Deepwoken, run inside the 'Aero' exploit menu's custom-feature sandbox.",
	"The following API is available as GLOBAL functions (also under the `Aero` table). Use ONLY this API for UI + lifecycle:",
	"",
	"UI (each returns a control object):",
	"  Toggle(text, function(value) end)  -- or Toggle(text, { default=bool, callback=fn }); control.get()/control.set(v)",
	"  Button(text, function() end)",
	"  Slider(text, { min=number, max=number, default=number, decimals=number, callback=function(value) end }); control.get()/set(v)",
	"  Dropdown(text, { values={...}, default=any, callback=function(value) end }); control.get()/set(v)/setValues(t)",
	"  Input(text, { default=string, callback=function(text) end }); control.get()/set(v)",
	"  Keybind(text, { default='E', callback=function(key) end })  -- fires callback when the bound key is pressed",
	"  Label(text); control.set(text)",
	"  Section(title) -> a sub-surface with the same UI methods",
	"  Window(title) -> a floating draggable window, a sub-surface with the same UI methods",
	"",
	"Lifecycle (auto-cleaned on reload):",
	"  OnRender(function(dt) end)   -- every RenderStepped frame",
	"  OnStep(function(dt) end)     -- every Heartbeat",
	"  OnInput(function(input, gameProcessed) end)",
	"  Interval(seconds, function() end)",
	"  OnCleanup(function() end)",
	"  Notify(text, seconds)",
	"",
	"Game helpers:",
	"  LocalPlayer, Character(), HRP(), Humanoid(), Mouse(), Camera()",
	"  GetTarget() -> { character, humanoid, root, du } (nearest aim target) ; GetTargets() -> list",
	"  Value(flag) -> read an existing Aero toggle/option by flag; Toggles, Options, Services, Library",
	"  Standard Roblox globals (game, workspace, task, math, Vector3, CFrame, etc.) are available.",
	"",
	"Rules: output ONLY runnable Luau code, no markdown fences, no explanation. Do not call loadstring/HttpGet/setfenv.",
	"Guard every frame loop with a toggle. Keep it concise and correct.",
}, "\n")

local function extractCode(text)
	if type(text) ~= "string" then
		return nil
	end
	-- Prefer a fenced code block if the model added one.
	local fenced = text:match("```[%w]*\n(.-)```")
	if fenced and fenced:gsub("%s", "") ~= "" then
		return fenced
	end
	return text
end

---Generate feature code from a natural-language prompt. Runs async; cb(ok, codeOrErr).
---@param prompt string
---@param cb fun(ok: boolean, result: string)
function Custom.generate(prompt, cb)
	task.spawn(function()
		local s = Custom.settings()
		local req = httpRequest()
		if not req then
			return cb(false, "no HTTP request function on this executor")
		end
		if not s.apiKey or s.apiKey:gsub("%s", "") == "" then
			return cb(false, "set your API key first")
		end

		local provider = s.provider or "OpenAI"
		local model = (s.model and s.model:gsub("%s", "") ~= "" and s.model) or Custom.DEFAULT_MODELS[provider] or "gpt-4o-mini"

		local url, headers, body
		if provider == "Anthropic" then
			url = "https://api.anthropic.com/v1/messages"
			headers = {
				["x-api-key"] = s.apiKey,
				["anthropic-version"] = "2023-06-01",
				["Content-Type"] = "application/json",
			}
			body = JSON.encode({
				model = model,
				max_tokens = 2048,
				system = API_REFERENCE,
				messages = { { role = "user", content = prompt } },
			})
		elseif provider == "Google" then
			url = "https://generativelanguage.googleapis.com/v1beta/models/"
				.. model
				.. ":generateContent?key="
				.. s.apiKey
			headers = { ["Content-Type"] = "application/json" }
			body = JSON.encode({
				system_instruction = { parts = { { text = API_REFERENCE } } },
				contents = { { role = "user", parts = { { text = prompt } } } },
			})
		else
			url = "https://api.openai.com/v1/chat/completions"
			headers = {
				["Authorization"] = "Bearer " .. s.apiKey,
				["Content-Type"] = "application/json",
			}
			body = JSON.encode({
				model = model,
				temperature = 0.4,
				messages = {
					{ role = "system", content = API_REFERENCE },
					{ role = "user", content = prompt },
				},
			})
		end

		local ok, res = pcall(req, {
			Url = url,
			Method = "POST",
			Headers = headers,
			Body = body,
		})
		if not ok or type(res) ~= "table" then
			return cb(false, "request failed: " .. tostring(res))
		end
		local status = res.StatusCode or res.Status or 0
		if type(res.Body) ~= "string" or res.Body == "" then
			return cb(false, "empty response (status " .. tostring(status) .. ")")
		end

		local decodeOk, decoded = pcall(JSON.decode, res.Body)
		if not decodeOk or type(decoded) ~= "table" then
			return cb(false, "bad JSON (status " .. tostring(status) .. ")")
		end

		-- API-level error?
		if decoded.error then
			local msg = type(decoded.error) == "table" and decoded.error.message or tostring(decoded.error)
			return cb(false, "api error: " .. tostring(msg))
		end

		local content
		if provider == "Anthropic" then
			content = decoded.content and decoded.content[1] and decoded.content[1].text
		elseif provider == "Google" then
			content = decoded.candidates
				and decoded.candidates[1]
				and decoded.candidates[1].content
				and decoded.candidates[1].content.parts
				and decoded.candidates[1].content.parts[1]
				and decoded.candidates[1].content.parts[1].text
		else
			content = decoded.choices and decoded.choices[1] and decoded.choices[1].message and decoded.choices[1].message.content
		end

		if type(content) ~= "string" or content:gsub("%s", "") == "" then
			return cb(false, "no code in response (status " .. tostring(status) .. ")")
		end

		return cb(true, extractCode(content))
	end)
end

return Custom
