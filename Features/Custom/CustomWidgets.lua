-- Self-managed UI widgets for user-built custom features. These are NOT YSL controls -- they're plain
-- styled frames we fully own, so a feature's whole UI can be torn down cleanly on reload (destroy the
-- frames + disconnect the returned connections). Each builder returns { instance, conns, ... }.

---@module GUI.Library
local Library = require("GUI/Library")

local UserInputService = game:GetService("UserInputService")

local CustomWidgets = {}

local ROW_H = 26

local function corner(inst, radius)
	Library:Create("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = inst })
end

local function stroke(inst, colorKey, transparency)
	local s = Library:Create("UIStroke", {
		Color = Library[colorKey] or Library.OutlineColor,
		Thickness = 1,
		Transparency = transparency or 0.4,
		Parent = inst,
	})
	Library:AddToRegistry(s, { Color = colorKey or "OutlineColor" })
	return s
end

---@param parent Instance
---@param height number
---@return Frame
local function row(parent, height)
	local f = Library:Create("Frame", {
		BackgroundColor3 = Library.BackgroundColor,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height or ROW_H),
		Parent = parent,
	})
	corner(f, 4)
	Library:AddToRegistry(f, { BackgroundColor3 = "BackgroundColor" })
	return f
end

local function label(parent, text, size, xAlign, width)
	return Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = text or "",
		TextSize = size or 13,
		TextColor3 = Library.FontColor,
		TextXAlignment = xAlign or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = width or UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Parent = parent,
	})
end

-- ---------------------------------------------------------------- Label ----
function CustomWidgets.label(parent, text)
	local f = Library:Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})
	local l = Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = tostring(text or ""),
		TextSize = 13,
		TextColor3 = Library.FontColor,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(4, 0),
		Parent = f,
	})
	Library:AddToRegistry(l, { TextColor3 = "FontColor" }, true)
	return {
		instance = f,
		conns = {},
		set = function(t)
			l.Text = tostring(t or "")
		end,
	}
end

-- ---------------------------------------------------------------- Button ----
function CustomWidgets.button(parent, text, callback)
	local f = Library:Create("TextButton", {
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamSemibold,
		Text = tostring(text or "Button"),
		TextSize = 13,
		TextColor3 = Library.FontColor,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Parent = parent,
	})
	corner(f, 4)
	stroke(f, "OutlineColor", 0.4)
	Library:AddToRegistry(f, { BackgroundColor3 = "MainColor", TextColor3 = "FontColor" }, true)

	f.MouseEnter:Connect(function()
		f.TextColor3 = Library.AccentColor
	end)
	f.MouseLeave:Connect(function()
		f.TextColor3 = Library.FontColor
	end)
	f.MouseButton1Click:Connect(function()
		if callback then
			pcall(callback)
		end
	end)

	return { instance = f, conns = {} }
end

-- ---------------------------------------------------------------- Toggle ----
function CustomWidgets.toggle(parent, text, default, callback)
	local value = default and true or false
	local f = row(parent, ROW_H)

	label(f, tostring(text or "Toggle"), 13, Enum.TextXAlignment.Left, UDim2.new(1, -36, 1, 0))

	local boxOuter = Library:Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		Parent = f,
	})
	corner(boxOuter, 3)
	stroke(boxOuter, "OutlineColor", 0.2)
	Library:AddToRegistry(boxOuter, { BackgroundColor3 = "MainColor" })

	local fill = Library:Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Library.AccentColor,
		BorderSizePixel = 0,
		Visible = value,
		Parent = boxOuter,
	})
	corner(fill, 2)
	Library:AddToRegistry(fill, { BackgroundColor3 = "AccentColor" })

	local button = Library:Create("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		Parent = f,
	})

	local control
	local function apply(fireCallback)
		fill.Visible = value
		if fireCallback and callback then
			pcall(callback, value)
		end
	end

	button.MouseButton1Click:Connect(function()
		value = not value
		apply(true)
	end)

	control = {
		instance = f,
		conns = {},
		get = function()
			return value
		end,
		set = function(v, fire)
			value = v and true or false
			apply(fire ~= false)
		end,
	}
	return control
end

-- ---------------------------------------------------------------- Slider ----
function CustomWidgets.slider(parent, text, min, max, default, callback, decimals)
	min = tonumber(min) or 0
	max = tonumber(max) or 100
	if max <= min then
		max = min + 1
	end
	decimals = tonumber(decimals) or 0
	local value = math.clamp(tonumber(default) or min, min, max)

	local f = Library:Create("Frame", {
		BackgroundColor3 = Library.BackgroundColor,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = parent,
	})
	corner(f, 4)
	Library:AddToRegistry(f, { BackgroundColor3 = "BackgroundColor" })

	local nameLabel = label(f, tostring(text or "Slider"), 12, Enum.TextXAlignment.Left, UDim2.new(1, -60, 0, 14))
	nameLabel.Position = UDim2.fromOffset(8, 2)

	local valueLabel = Library:Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -8, 0, 2),
		Size = UDim2.fromOffset(54, 14),
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextColor3 = Library.AccentColor,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = f,
	})
	Library:AddToRegistry(valueLabel, { TextColor3 = "AccentColor" }, true)

	local track = Library:Create("Frame", {
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 22),
		Size = UDim2.new(1, -16, 0, 6),
		Parent = f,
	})
	corner(track, 3)
	Library:AddToRegistry(track, { BackgroundColor3 = "MainColor" })

	local fill = Library:Create("Frame", {
		BackgroundColor3 = Library.AccentColor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})
	corner(fill, 3)
	Library:AddToRegistry(fill, { BackgroundColor3 = "AccentColor" })

	local function round(v)
		local m = 10 ^ decimals
		return math.floor(v * m + 0.5) / m
	end

	local control
	local function apply(fireCallback)
		local ratio = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		valueLabel.Text = tostring(round(value))
		if fireCallback and callback then
			pcall(callback, value)
		end
	end

	local dragging = false
	local function setFromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		value = round(min + rel * (max - min))
		apply(true)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	local c1 = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	local c2 = UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			setFromX(input.Position.X)
		end
	end)

	apply(false)

	control = {
		instance = f,
		conns = { c1, c2 },
		get = function()
			return value
		end,
		set = function(v, fire)
			value = math.clamp(round(tonumber(v) or min), min, max)
			apply(fire ~= false)
		end,
	}
	return control
end

-- ---------------------------------------------------------------- Input ----
function CustomWidgets.input(parent, text, default, callback)
	local f = row(parent, ROW_H)
	local hasLabel = text ~= nil and tostring(text) ~= ""
	if hasLabel then
		label(f, tostring(text), 13, Enum.TextXAlignment.Left, UDim2.new(0.4, -8, 1, 0))
	end

	local boxHolder = Library:Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = hasLabel and UDim2.new(0.6, -10, 1, -8) or UDim2.new(1, -12, 1, -8),
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		Parent = f,
	})
	corner(boxHolder, 3)
	stroke(boxHolder, "OutlineColor", 0.3)
	Library:AddToRegistry(boxHolder, { BackgroundColor3 = "MainColor" })

	local tb = Library:Create("TextBox", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -10, 1, 0),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Library.FontColor,
		PlaceholderText = "...",
		PlaceholderColor3 = Library.OutlineColor,
		Text = tostring(default or ""),
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = boxHolder,
	})
	Library:AddToRegistry(tb, { TextColor3 = "FontColor" }, true)

	tb.FocusLost:Connect(function()
		if callback then
			pcall(callback, tb.Text)
		end
	end)

	return {
		instance = f,
		conns = {},
		get = function()
			return tb.Text
		end,
		set = function(t)
			tb.Text = tostring(t or "")
		end,
	}
end

-- ---------------------------------------------------------------- Keybind ----
function CustomWidgets.keybind(parent, text, default, callback)
	local key = default
	local listening = false
	local f = row(parent, ROW_H)

	label(f, tostring(text or "Keybind"), 13, Enum.TextXAlignment.Left, UDim2.new(1, -74, 1, 0))

	local keyBtn = Library:Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(60, 18),
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamSemibold,
		TextSize = 11,
		TextColor3 = Library.AccentColor,
		Text = key and tostring(key) or "None",
		Parent = f,
	})
	corner(keyBtn, 3)
	stroke(keyBtn, "OutlineColor", 0.3)
	Library:AddToRegistry(keyBtn, { BackgroundColor3 = "MainColor", TextColor3 = "AccentColor" })

	keyBtn.MouseButton1Click:Connect(function()
		listening = true
		keyBtn.Text = "..."
	end)

	local conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if listening and input.UserInputType == Enum.UserInputType.Keyboard then
			listening = false
			if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
				key = nil
				keyBtn.Text = "None"
			else
				key = input.KeyCode.Name
				keyBtn.Text = key
			end
			return
		end
		if gameProcessed then
			return
		end
		if key and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == key then
			if callback then
				pcall(callback, key)
			end
		end
	end)

	return {
		instance = f,
		conns = { conn },
		get = function()
			return key
		end,
		set = function(k)
			key = k
			keyBtn.Text = k and tostring(k) or "None"
		end,
	}
end

-- ---------------------------------------------------------------- Dropdown ----
-- Collapsed row shows the selected value; clicking expands an inline option list below it.
function CustomWidgets.dropdown(parent, text, values, default, callback)
	values = values or {}
	local selected = default
	if selected == nil and values[1] ~= nil then
		selected = values[1]
	end

	local f = Library:Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW_H),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})

	local header = row(f, ROW_H)
	label(header, tostring(text or "Dropdown"), 13, Enum.TextXAlignment.Left, UDim2.new(0.5, -8, 1, 0))

	local valueLabel = Library:Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -22, 0.5, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextColor3 = Library.AccentColor,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = selected ~= nil and tostring(selected) or "...",
		Parent = header,
	})
	Library:AddToRegistry(valueLabel, { TextColor3 = "AccentColor" }, true)

	local arrow = Library:Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Library.FontColor,
		Text = "+",
		Parent = header,
	})

	local listHolder = Library:Create("Frame", {
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, ROW_H + 2),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = f,
	})
	corner(listHolder, 4)
	stroke(listHolder, "OutlineColor", 0.3)
	Library:AddToRegistry(listHolder, { BackgroundColor3 = "MainColor" })
	Library:Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = listHolder })
	Library:Create("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		Parent = listHolder,
	})

	local open = false
	local function setOpen(v)
		open = v
		listHolder.Visible = v
		arrow.Text = v and "-" or "+"
	end

	local headerBtn = Library:Create("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		Parent = header,
	})
	headerBtn.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	local control
	local function rebuild()
		for _, c in ipairs(listHolder:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		for i, v in ipairs(values) do
			local opt = Library:Create("TextButton", {
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Font = Enum.Font.Gotham,
				Text = tostring(v),
				TextSize = 12,
				TextColor3 = Library.FontColor,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -8, 0, 20),
				Position = UDim2.fromOffset(6, 0),
				LayoutOrder = i,
				Parent = listHolder,
			})
			opt.MouseEnter:Connect(function()
				opt.TextColor3 = Library.AccentColor
			end)
			opt.MouseLeave:Connect(function()
				opt.TextColor3 = Library.FontColor
			end)
			opt.MouseButton1Click:Connect(function()
				selected = v
				valueLabel.Text = tostring(v)
				setOpen(false)
				if callback then
					pcall(callback, v)
				end
			end)
		end
	end
	rebuild()

	control = {
		instance = f,
		conns = {},
		get = function()
			return selected
		end,
		set = function(v, fire)
			selected = v
			valueLabel.Text = v ~= nil and tostring(v) or "..."
			if fire ~= false and callback then
				pcall(callback, v)
			end
		end,
		setValues = function(newValues)
			values = newValues or {}
			rebuild()
		end,
	}
	return control
end

-- ---------------------------------------------------------------- Section ----
-- A labelled container with its own vertical body for nested widgets.
function CustomWidgets.section(parent, title)
	local f = Library:Create("Frame", {
		BackgroundColor3 = Library.MainColor,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})
	corner(f, 4)
	stroke(f, "OutlineColor", 0.5)
	Library:AddToRegistry(f, { BackgroundColor3 = "MainColor" })

	Library:Create("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = f,
	})
	Library:Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = f,
	})

	local head = Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = tostring(title or "Section"),
		TextSize = 13,
		TextColor3 = Library.AccentColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 0,
		Parent = f,
	})
	Library:AddToRegistry(head, { TextColor3 = "AccentColor" }, true)

	local body = Library:Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = f,
	})
	Library:Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		Parent = body,
	})

	return { instance = f, body = body, conns = {} }
end

return CustomWidgets
