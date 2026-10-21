-- Reusable Lua code editor widget (line gutter, custom caret, selection highlight, syntax colouring).
-- Lifted from the timing builder's module editor so the Custom tab can offer the exact same editor.
-- create(host, height, placeholder) -> { get, set, setEditable } ; host is a groupbox/tab (has .Container + :Resize()).

---@module GUI.Library
local Library = require("GUI/Library")

local CodeEditor = {}

local LUA_KEYWORDS = {}
for _, kw in ipairs({
	"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto",
	"if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until",
	"while", "continue", "self",
}) do
	LUA_KEYWORDS[kw] = true
end

local HL_KEYWORD = "#f3a8d6"
local HL_STRING = "#a8e6b0"
local HL_NUMBER = "#f5c07a"
local HL_COMMENT = "#8b7fa0"

local function escapeRich(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function span(color, text)
	return '<font color="' .. color .. '">' .. escapeRich(text) .. "</font>"
end

local function highlightLua(code)
	local out = {}
	local i, n = 1, #code

	while i <= n do
		local c = code:sub(i, i)
		local two = code:sub(i, i + 1)

		if two == "--" then
			local eqs = code:sub(i + 2):match("^%[(=*)%[")
			if eqs then
				local close = "]" .. eqs .. "]"
				local endpos = code:find(close, i + 2, true)
				local chunk = endpos and code:sub(i, endpos + #close - 1) or code:sub(i)
				out[#out + 1] = span(HL_COMMENT, chunk)
				i = i + #chunk
			else
				local nl = code:find("\n", i, true)
				local chunk = nl and code:sub(i, nl - 1) or code:sub(i)
				out[#out + 1] = span(HL_COMMENT, chunk)
				i = i + #chunk
			end
		elseif c == '"' or c == "'" then
			local j = i + 1
			while j <= n do
				local cj = code:sub(j, j)
				if cj == "\\" then
					j = j + 2
				elseif cj == c or cj == "\n" then
					j = j + 1
					break
				else
					j = j + 1
				end
			end
			local chunk = code:sub(i, j - 1)
			out[#out + 1] = span(HL_STRING, chunk)
			i = i + #chunk
		elseif c == "[" and code:sub(i):match("^%[=*%[") then
			local eqs = code:sub(i):match("^%[(=*)%[")
			local close = "]" .. eqs .. "]"
			local endpos = code:find(close, i + #eqs + 2, true)
			local chunk = endpos and code:sub(i, endpos + #close - 1) or code:sub(i)
			out[#out + 1] = span(HL_STRING, chunk)
			i = i + #chunk
		elseif c:match("%d") or (c == "." and code:sub(i + 1, i + 1):match("%d")) then
			local num = code:sub(i):match("^0[xX]%x+")
				or code:sub(i):match("^%d*%.?%d+[eE][%+%-]?%d+")
				or code:sub(i):match("^%d*%.?%d+")
				or c
			out[#out + 1] = span(HL_NUMBER, num)
			i = i + #num
		elseif c:match("[%a_]") then
			local word = code:sub(i):match("^[%w_]+")
			if LUA_KEYWORDS[word] then
				out[#out + 1] = span(HL_KEYWORD, word)
			else
				out[#out + 1] = escapeRich(word)
			end
			i = i + #word
		else
			out[#out + 1] = escapeRich(c)
			i = i + 1
		end
	end

	return table.concat(out)
end

CodeEditor.highlight = highlightLua
CodeEditor.escape = escapeRich

---@param host table|Instance a groupbox/tab (needs .Container and :Resize()) OR a raw parent frame
---@param height number
---@param placeholder string?
---@return table
function CodeEditor.create(host, height, placeholder, zbase)
	local GUTTER_W = 34
	local PAD = 6
	local PLACEHOLDER = placeholder or "-- write your feature here"
	-- The ScreenGui uses Global ZIndexBehavior, so when the editor lives in a high-ZIndex floating window
	-- its elements must be lifted above the window's background (pass zbase ~205), else it renders hidden.
	local Z = zbase or 5

	-- Accept either a Aero groupbox/tab (parent into .Container, call :Resize afterwards) or a plain frame.
	local isContainer = typeof(host) ~= "Instance"
	local parentInst = isContainer and host.Container or host

	local holder = Library:Create("Frame", {
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -4, 0, height),
		LayoutOrder = 9999,
		ZIndex = Z,
		Parent = parentInst,
	})

	Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = holder })
	Library:AddToRegistry(holder, { BackgroundColor3 = "MainColor" })

	local stroke = Library:Create("UIStroke", {
		Color = Library.OutlineColor,
		Thickness = 1,
		Transparency = 0.5,
		Parent = holder,
	})
	Library:AddToRegistry(stroke, { Color = "OutlineColor" })

	local gutterHolder = Library:Create("Frame", {
		BackgroundColor3 = Library.BackgroundColor,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.new(0, 0, 0, PAD),
		Size = UDim2.new(0, GUTTER_W, 1, -PAD * 2),
		ZIndex = Z + 1,
		Parent = holder,
	})

	local gutter = Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = Library.OutlineColor,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "1",
		ZIndex = Z + 1,
		Parent = gutterHolder,
	})

	local scroll = Library:Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, GUTTER_W + 2, 0, PAD),
		Size = UDim2.new(1, -(GUTTER_W + 2 + PAD), 1, -PAD * 2),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ScrollingDirection = Enum.ScrollingDirection.XY,
		ScrollBarThickness = 4,
		ZIndex = Z + 1,
		Parent = holder,
	})

	local selectionFrames = {}

	local highlight = Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 2, 0, 0),
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		RichText = true,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(150, 150, 162),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = escapeRich(PLACEHOLDER),
		ZIndex = Z + 1,
		Parent = scroll,
	})

	local box = Library:Create("TextBox", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 2, 0, 0),
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		MultiLine = true,
		ClearTextOnFocus = false,
		TextEditable = true,
		TextWrapped = false,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = Library.FontColor,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		PlaceholderText = "",
		ZIndex = Z + 2,
		Parent = scroll,
	})

	local TextService = game:GetService("TextService")
	local HUGE = Vector2.new(1e6, 1e6)
	local LINE_H = 15
	pcall(function()
		LINE_H = TextService:GetTextSize("Ag", 13, Enum.Font.Code, HUGE).Y
	end)

	local caret = Library:Create("Frame", {
		BackgroundColor3 = Library.FontColor,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 1, 0, LINE_H),
		Position = UDim2.new(0, 2, 0, 0),
		Visible = false,
		ZIndex = Z + 3,
		Parent = scroll,
	})
	Library:AddToRegistry(caret, { BackgroundColor3 = "FontColor" })

	local function updateCaret()
		if not box:IsFocused() then
			caret.Visible = false
			return
		end
		local pos = box.CursorPosition
		if pos < 1 then
			caret.Visible = false
			return
		end
		local before = box.Text:sub(1, pos - 1)
		local line = 0
		for _ in before:gmatch("\n") do
			line = line + 1
		end
		local seg = before:match("[^\n]*$") or ""
		local width = 0
		pcall(function()
			width = TextService:GetTextSize(seg, 13, Enum.Font.Code, HUGE).X
		end)
		caret.Position = UDim2.new(0, 2 + width, 0, line * LINE_H)
		caret.Visible = true
		caret.BackgroundTransparency = 0
	end

	task.spawn(function()
		while caret.Parent do
			task.wait(0.5)
			if box:IsFocused() and caret.Visible then
				caret.BackgroundTransparency = caret.BackgroundTransparency == 0 and 1 or 0
			end
		end
	end)

	local function renderSelection()
		for _, f in ipairs(selectionFrames) do
			f:Destroy()
		end
		selectionFrames = {}

		local sStart, cPos = box.SelectionStart, box.CursorPosition
		if sStart == -1 or cPos == -1 or sStart == cPos then
			return
		end
		local a = math.min(sStart, cPos)
		local b = math.max(sStart, cPos)

		local text = box.Text
		local pos = 1
		for line in (text .. "\n"):gmatch("(.-)\n") do
			local len = #line
			local lineEndPos = pos + len
			local selA = math.max(a, pos)
			local selB = math.min(b, lineEndPos + 1)
			if selB > selA then
				local col1 = math.min(selA - pos, len)
				local col2 = math.min(selB - pos, len)
				local x1, x2 = 0, 0
				pcall(function()
					x1 = TextService:GetTextSize(line:sub(1, col1), 13, Enum.Font.Code, HUGE).X
					x2 = TextService:GetTextSize(line:sub(1, col2), 13, Enum.Font.Code, HUGE).X
				end)
				local lineIdx = 0
				for _ in text:sub(1, pos - 1):gmatch("\n") do
					lineIdx = lineIdx + 1
				end
				local w = x2 - x1
				if b > lineEndPos then
					w = w + 4
				end
				local sel = Library:Create("Frame", {
					BackgroundColor3 = Library.AccentColor,
					BackgroundTransparency = 0.55,
					BorderSizePixel = 0,
					Position = UDim2.new(0, 2 + x1, 0, lineIdx * LINE_H),
					Size = UDim2.new(0, math.max(w, 2), 0, LINE_H),
					ZIndex = Z,
					Parent = scroll,
				})
				Library:AddToRegistry(sel, { BackgroundColor3 = "AccentColor" })
				selectionFrames[#selectionFrames + 1] = sel
			end
			pos = lineEndPos + 1
		end
	end

	box:GetPropertyChangedSignal("CursorPosition"):Connect(function()
		updateCaret()
		renderSelection()
	end)
	box:GetPropertyChangedSignal("SelectionStart"):Connect(renderSelection)
	box.Focused:Connect(updateCaret)
	box.FocusLost:Connect(function()
		caret.Visible = false
		renderSelection()
	end)

	local function refresh()
		local text = box.Text

		if text == "" then
			highlight.TextColor3 = Color3.fromRGB(150, 150, 162)
			highlight.Text = escapeRich(PLACEHOLDER)
		else
			highlight.TextColor3 = Library.FontColor
			local ok, colored = pcall(highlightLua, text)
			highlight.Text = ok and colored or escapeRich(text)
		end

		local lines = 1
		for _ in text:gmatch("\n") do
			lines = lines + 1
		end
		local nums = {}
		for k = 1, lines do
			nums[k] = tostring(k)
		end
		gutter.Text = table.concat(nums, "\n")
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		refresh()
		updateCaret()
		renderSelection()
	end)
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		gutter.Position = UDim2.new(0, 0, 0, -scroll.CanvasPosition.Y)
	end)

	refresh()

	if isContainer and host.Resize then
		pcall(function()
			host:Resize()
		end)
	end

	return {
		get = function()
			return box.Text
		end,
		set = function(text)
			box.Text = text or ""
			refresh()
		end,
		setEditable = function(editable)
			box.TextEditable = editable and true or false
			if not editable then
				caret.Visible = false
			end
		end,
	}
end

return CodeEditor
