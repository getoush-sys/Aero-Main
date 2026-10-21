-- Tools the AI agent can call to inspect the live game and decompile scripts, plus the full Aero custom
-- feature API reference it builds code against. Everything is read-only and bounded so a tool call can't
-- hang or dump unbounded output. GameTools.run(name, args) -> string result.

---@module Features.Custom.Custom
local Custom = require("Features/Custom/Custom")

local GameTools = {}

local Players = game:GetService("Players")

-- ------------------------------------------------------------ path resolution
-- Resolve a dot path from the DataModel, e.g. "game.Workspace.Live", "Players.LocalPlayer",
-- "Players.LocalPlayer.Character". Handles services + the LocalPlayer/Character property shortcuts.
local function resolvePath(path)
	if type(path) ~= "string" or path:gsub("%s", "") == "" then
		return game
	end
	path = path:gsub("/", ".")
	local cur = game
	local first = true
	for token in path:gmatch("[^%.]+") do
		if first and (token == "game" or token == "Game" or token == "DataModel") then
			cur = game
		elseif token == "LocalPlayer" then
			cur = Players.LocalPlayer
			if not cur then
				return nil, "LocalPlayer is nil"
			end
		elseif token == "Character" and typeof(cur) == "Instance" and cur:IsA("Player") then
			cur = cur.Character
			if not cur then
				return nil, "Character is nil"
			end
		else
			local nextInst = nil
			if cur == game then
				pcall(function()
					nextInst = game:GetService(token)
				end)
			end
			if not nextInst then
				nextInst = cur:FindFirstChild(token)
			end
			if not nextInst then
				return nil, "not found: '" .. token .. "' under " .. cur:GetFullName()
			end
			cur = nextInst
		end
		first = false
	end
	return cur
end

GameTools.resolvePath = resolvePath

-- ------------------------------------------------------------ tools
local function tExplore(path, depth)
	local inst, err = resolvePath(path)
	if not inst then
		return "Error: " .. tostring(err)
	end
	depth = math.clamp(tonumber(depth) or 1, 1, 3)
	local lines = { inst:GetFullName() .. "  [" .. inst.ClassName .. "]" }
	local count = 0
	local function walk(node, d, indent)
		if count >= 200 then
			return
		end
		local ok, children = pcall(function()
			return node:GetChildren()
		end)
		if not ok then
			return
		end
		for _, child in ipairs(children) do
			count = count + 1
			if count >= 200 then
				lines[#lines + 1] = indent .. "... (truncated)"
				return
			end
			lines[#lines + 1] = indent .. child.Name .. "  [" .. child.ClassName .. "]"
			if d > 1 then
				walk(child, d - 1, indent .. "  ")
			end
		end
	end
	walk(inst, depth, "  ")
	if count == 0 then
		lines[#lines + 1] = "  (no children)"
	end
	return table.concat(lines, "\n")
end

local PROP_CANDIDATES = {
	"Name", "ClassName", "Enabled", "Value", "Visible", "Transparency", "Anchored", "CanCollide",
	"Position", "Size", "Orientation", "CFrame", "Health", "MaxHealth", "WalkSpeed", "JumpPower",
	"HipHeight", "DisplayName", "Text", "PlaceholderText", "Color", "BrickColor", "Material",
	"Massless", "CollisionGroup", "MeshId", "TextureId", "SoundId", "Volume", "Playing", "TimePosition",
	"AssetId", "AnimationId", "PrimaryPart", "Adornee", "Active",
}

local function tProperties(path)
	local inst, err = resolvePath(path)
	if not inst then
		return "Error: " .. tostring(err)
	end
	local out = { inst:GetFullName() .. "  [" .. inst.ClassName .. "]" }
	for _, p in ipairs(PROP_CANDIDATES) do
		local ok, v = pcall(function()
			return inst[p]
		end)
		if ok and v ~= nil then
			out[#out + 1] = p .. " = " .. tostring(v)
		end
	end
	pcall(function()
		if inst.Parent then
			out[#out + 1] = "Parent = " .. inst.Parent:GetFullName()
		end
	end)
	local okA, attrs = pcall(function()
		return inst:GetAttributes()
	end)
	if okA and type(attrs) == "table" then
		for k, v in pairs(attrs) do
			out[#out + 1] = "@" .. tostring(k) .. " = " .. tostring(v)
		end
	end
	return table.concat(out, "\n")
end

local function matchClass(className, filter)
	if filter == nil or filter == "" then
		return true
	end
	return className == filter
end

local function tSearch(query, class, rootPath)
	local root, err = resolvePath(rootPath or "game")
	if not root then
		return "Error: " .. tostring(err)
	end
	query = tostring(query or ""):lower()
	local results = {}
	local scanned = 0
	local ok, descendants = pcall(function()
		return root:GetDescendants()
	end)
	if not ok then
		return "Error: could not enumerate descendants."
	end
	for _, d in ipairs(descendants) do
		scanned = scanned + 1
		if scanned > 60000 then
			break
		end
		if matchClass(d.ClassName, class) and (query == "" or d.Name:lower():find(query, 1, true)) then
			results[#results + 1] = d:GetFullName() .. "  [" .. d.ClassName .. "]"
			if #results >= 60 then
				results[#results + 1] = "... (more results omitted)"
				break
			end
		end
	end
	if #results == 0 then
		return "No matches (scanned " .. scanned .. " descendants)."
	end
	return table.concat(results, "\n")
end

local SCRIPT_CLASSES = { LocalScript = true, ModuleScript = true, Script = true }

local function tScripts(rootPath)
	local root, err = resolvePath(rootPath or "game")
	if not root then
		return "Error: " .. tostring(err)
	end
	local results = {}
	local scanned = 0
	local ok, descendants = pcall(function()
		return root:GetDescendants()
	end)
	if not ok then
		return "Error: could not enumerate descendants."
	end
	for _, d in ipairs(descendants) do
		scanned = scanned + 1
		if scanned > 60000 then
			break
		end
		if SCRIPT_CLASSES[d.ClassName] then
			results[#results + 1] = d:GetFullName() .. "  [" .. d.ClassName .. "]"
			if #results >= 80 then
				results[#results + 1] = "... (more omitted)"
				break
			end
		end
	end
	if #results == 0 then
		return "No scripts found."
	end
	return table.concat(results, "\n")
end

local function tDecompile(path)
	local inst, err = resolvePath(path)
	if not inst then
		return "Error: " .. tostring(err)
	end
	if not (typeof(inst) == "Instance" and inst:IsA("LuaSourceContainer")) then
		return "Not a script: " .. inst.ClassName
	end
	local dec = decompile or (getgenv and getgenv().decompile)
	if not dec then
		return "decompile() is not available on this executor."
	end
	local ok, src = pcall(dec, inst)
	if not ok or type(src) ~= "string" then
		return "Decompile failed: " .. tostring(src)
	end
	if #src > 9000 then
		src = src:sub(1, 9000) .. "\n-- [truncated; ask to decompile a nested module for more]"
	end
	return src
end

-- ------------------------------------------------------------ dispatch
---@param name string
---@param args table?
---@return string
function GameTools.run(name, args)
	args = args or {}
	local ok, result = pcall(function()
		if name == "explore" then
			return tExplore(args.path, args.depth)
		elseif name == "properties" then
			return tProperties(args.path)
		elseif name == "search" then
			return tSearch(args.query, args.class, args.root)
		elseif name == "scripts" then
			return tScripts(args.root)
		elseif name == "decompile" then
			return tDecompile(args.path)
		elseif name == "api_reference" then
			return GameTools.API_REFERENCE
		elseif name == "run_feature" then
			local fname = (type(args.name) == "string" and args.name:gsub("%s", "") ~= "") and args.name or "AI Test"
			if type(args.code) ~= "string" or args.code:gsub("%s", "") == "" then
				return "Error: no 'code' provided."
			end
			Custom.save(fname, args.code)
			local okRun, err = Custom.run(fname, args.code)
			if okRun then
				return "Ran '" .. fname .. "' successfully; its controls are now in the Custom Controls panel. "
					.. "Toggle them to verify behaviour, then give the user the final code in a ```lua block."
			end
			return "Run FAILED: " .. tostring(err) .. "\nFix the code and call run_feature again."
		elseif name == "stop_feature" then
			local fname = type(args.name) == "string" and args.name or ""
			Custom.stop(fname)
			return "Stopped '" .. fname .. "'."
		elseif name == "list_features" then
			local names = Custom.list()
			if #names == 0 then
				return "No saved features."
			end
			return table.concat(names, "\n")
		end
		return "Unknown tool: " .. tostring(name)
	end)
	if not ok then
		return "Tool error: " .. tostring(result)
	end
	return tostring(result)
end

-- ------------------------------------------------------------ docs for the system prompt
GameTools.TOOLS_DOC = table.concat({
	"TOOLS -- to call one, reply with ONLY a JSON object (no prose, no code fences):",
	'  {"tool":"explore","args":{"path":"game.Workspace","depth":1}}   -- list children (depth 1-3)',
	'  {"tool":"properties","args":{"path":"game.Players.LocalPlayer.Character.Humanoid"}}',
	'  {"tool":"search","args":{"query":"ClientManager","class":"ModuleScript","root":"game"}}',
	'  {"tool":"scripts","args":{"root":"game.Players.LocalPlayer.PlayerScripts"}}',
	'  {"tool":"decompile","args":{"path":"game.ReplicatedStorage.SomeModule"}}',
	'  {"tool":"api_reference","args":{}}   -- re-read the Aero feature API',
	'  {"tool":"run_feature","args":{"name":"My Feature","code":"<full luau code>"}}  -- TEST your code live; returns success or the error',
	'  {"tool":"stop_feature","args":{"name":"My Feature"}}',
	'  {"tool":"list_features","args":{}}',
	"Paths are dot paths from the DataModel. Shortcuts: 'LocalPlayer' and '.Character' resolve correctly.",
	"After I return a tool result, keep going: call more tools or give your final answer. One tool per message.",
	"Prefer to TEST feature code with run_feature before finishing -- if it returns an error, fix it and retry.",
	"When you have enough info, reply normally. If you wrote a feature, put the final code in a ```lua block.",
}, "\n")

GameTools.API_REFERENCE = table.concat({
	"Aero CUSTOM FEATURE API. User code runs in a sandbox inside the 'Aero' Deepwoken exploit menu.",
	"These are available as GLOBAL functions (and under the `Aero` table). Use ONLY this API for UI + lifecycle.",
	"",
	"UI (each returns a control; controls have :get()/:set(v) where sensible, accessed as control.get()/control.set(v)):",
	"  Toggle(text, cb_or_opts)   -- cb_or_opts = function(value) OR { default=bool, callback=fn }",
	"  Button(text, function() end)",
	"  Slider(text, { min=number, max=number, default=number, decimals=number, callback=function(value) end })",
	"  Dropdown(text, { values={...}, default=any, callback=function(value) end })  -- control.setValues(t)",
	"  Input(text, { default=string, callback=function(text) end })  -- or Input(text, function(text) end)",
	"  Keybind(text, { default='E', callback=function(key) end })  -- callback fires when the key is pressed",
	"  Label(text)  -- control.set(text)",
	"  Section(title) -> sub-surface with all the same UI methods",
	"  Window(title) -> a floating draggable window; sub-surface with the same UI methods",
	"",
	"Lifecycle (ALL auto-disconnected when the feature is reloaded/stopped):",
	"  OnRender(function(dt) end)   -- RenderStepped (every frame)",
	"  OnStep(function(dt) end)     -- Heartbeat",
	"  OnInput(function(input, gameProcessed) end)  -- UserInputService.InputBegan",
	"  Interval(seconds, function() end)",
	"  OnCleanup(function() end)",
	"  Notify(text, seconds)",
	"",
	"Game helpers:",
	"  LocalPlayer, Character(), HRP(), Humanoid(), Mouse(), Camera()",
	"  GetTarget() -> nearest target { character, humanoid, root, du=distance } or nil ; GetTargets() -> list",
	"  Value(flag) -> read an existing Aero toggle/option by its flag string",
	"  Toggles, Options -> raw Aero control tables ; Services -> { Players, RunService, Workspace, ... } ; Library",
	"  Standard Roblox globals work: game, workspace, task, math, string, table, Vector3, CFrame, Instance, etc.",
	"",
	"Rules: guard every frame loop with a toggle so it only runs when enabled. Never call loadstring/HttpGet/",
	"setfenv/require inside a feature. Keep code correct and concise. Example:",
	"  local on = Toggle('Enabled', function(v) end)",
	"  Slider('Speed', { min=16, max=200, default=16, callback=function(v)",
	"    local h = Humanoid(); if h then h.WalkSpeed = v end",
	"  end })",
	"  OnRender(function() if not on.get() then return end end)",
}, "\n")

return GameTools
