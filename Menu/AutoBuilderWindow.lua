-- A standalone draggable window that shows a loaded build's preshrine (left) and postshrine (right)
-- stats, talents and mantras, with a button on each side to pick which set the script targets. It's
-- its own frame (not a Library window) so it doesn't clobber the main menu's toggle.

---@module GUI.Library
local Library = require("GUI/Library")

---@module Features.Automation.AutoBuilder
local AutoBuilder = require("Features/Automation/AutoBuilder")

local AutoBuilderWindow = {}

local built = false
local frame
local titleLabel
local preColumn, postColumn
local preButton, postButton

local BASE_ORDER = { "Strength", "Fortitude", "Agility", "Intelligence", "Willpower", "Charisma" }
local BASE_SHORT = {
	Strength = "STR",
	Fortitude = "FTD",
	Agility = "AGI",
	Intelligence = "INT",
	Willpower = "WIL",
	Charisma = "CHA",
}
local WEAPON_ORDER = { "Light Wep.", "Medium Wep.", "Heavy Wep." }
local ATTUNEMENT_ORDER =
	{ "Flamecharm", "Frostdraw", "Thundercall", "Galebreathe", "Shadowcast", "Ironsing", "Bloodrend" }

---Build the ordered list of { text, header } rows for one stat spread + its talent/mantra column.
---@param spread table
---@param column table
---@return table
local function columnRows(spread, column)
	local rows = {}

	local function add(text, isHeader)
		rows[#rows + 1] = { text = text, header = isHeader or false }
	end

	-- Base attributes on one line.
	local baseParts = {}
	for _, key in ipairs(BASE_ORDER) do
		table.insert(baseParts, string.format("%s %d", BASE_SHORT[key], spread.base[key] or 0))
	end
	add("Attributes", true)
	add("  " .. table.concat(baseParts, "  "))

	-- Only non-zero weapon / attunement investments (a build can have several of each).
	local weaponParts = {}
	for _, key in ipairs(WEAPON_ORDER) do
		local v = spread.weapon[key] or 0
		if v > 0 then
			table.insert(weaponParts, string.format("%s %d", key:gsub(" Wep%.", ""), v))
		end
	end
	if #weaponParts > 0 then
		add("  Weapon: " .. table.concat(weaponParts, "  "))
	end

	local attParts = {}
	for _, key in ipairs(ATTUNEMENT_ORDER) do
		local v = spread.attunement[key] or 0
		if v > 0 then
			table.insert(attParts, string.format("%s %d", key, v))
		end
	end
	if #attParts > 0 then
		add("  Attunement: " .. table.concat(attParts, "  "))
	end

	local talents = column.talents or {}
	local mantras = column.mantras or {}

	add("")
	add(string.format("Talents (%d)", #talents), true)
	if #talents > 0 then
		for _, name in ipairs(talents) do
			add("  " .. name)
		end
	else
		add("  (none)")
	end

	add("")
	add(string.format("Mantras (%d)", #mantras), true)
	if #mantras > 0 then
		for _, name in ipairs(mantras) do
			add("  " .. name)
		end
	else
		add("  (none)")
	end

	return rows
end

---Render a column's rows as one label per line (so no single label truncates a long list), and
---resize the canvas to fit.
---@param col table { scroll = ScrollingFrame, layout = UIListLayout }
---@param rows table
local function renderColumn(col, rows)
	for _, child in next, col.scroll:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	for i, row in ipairs(rows) do
		Library:CreateLabel({
			LayoutOrder = i,
			Size = UDim2.new(1, -10, 0, 15),
			Text = row.text,
			TextSize = 13,
			TextColor3 = row.header and Library.AccentColor or Library.FontColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 703,
			Parent = col.scroll,
		})
	end

	col.scroll.CanvasSize = UDim2.new(0, 0, 0, col.layout.AbsoluteContentSize.Y + 8)
end

---Update the two target buttons so the active one reads as selected.
local function refreshTargetButtons()
	if not built then
		return
	end

	local pre = AutoBuilder.target == "pre"
	preButton.Text = pre and "> Target: Preshrine <" or "Use Preshrine"
	postButton.Text = (not pre) and "> Target: Postshrine <" or "Use Postshrine"
	preButton.TextColor3 = pre and Library.AccentColor or Library.FontColor
	postButton.TextColor3 = (not pre) and Library.AccentColor or Library.FontColor
end

---Build one side's scrolling column. Returns { scroll, layout }.
---@param xScale number left edge (0 or 0.5)
---@return table
local function buildColumn(xScale)
	local scroll = Library:Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(xScale, xScale == 0 and 10 or 4, 0, 74),
		Size = UDim2.new(0.5, -14, 1, -84),
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Library.AccentColor,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		ZIndex = 702,
		Parent = frame,
	})

	local layout = Library:Create("UIListLayout", {
		Parent = scroll,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 1),
	})

	local col = { scroll = scroll, layout = layout }

	-- Keep the canvas in sync with content whenever it changes.
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
	end)

	local placeholder = Library:CreateLabel({
		LayoutOrder = 1,
		Size = UDim2.new(1, -10, 0, 15),
		Text = "Load a build first.",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 703,
		Parent = scroll,
	})
	placeholder.Name = "Placeholder"

	return col
end

local function ensure()
	if built then
		return
	end
	built = true

	frame = Library:Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Library.BackgroundColor,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(680, 540),
		Visible = false,
		ZIndex = 700,
		Parent = Library.ScreenGui,
	})

	Library:Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = frame })
	Library:Create("UIStroke", {
		Color = Library.AccentColor,
		Thickness = 1,
		Transparency = 0.3,
		Parent = frame,
	})

	-- Drag by the top 34px.
	Library:MakeDraggable(frame, 34)

	titleLabel = Library:CreateLabel({
		Position = UDim2.new(0, 12, 0, 8),
		Size = UDim2.new(1, -210, 0, 18),
		Text = "Auto Builder",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 703,
		Parent = frame,
	})

	-- Close button.
	local close = Library:Create("TextButton", {
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -30, 0, 6),
		Size = UDim2.fromOffset(22, 22),
		Text = "X",
		TextColor3 = Library.FontColor,
		FontFace = Library.Font,
		TextSize = 14,
		ZIndex = 703,
		AutoButtonColor = true,
		Parent = frame,
	})
	Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = close })
	close.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)

	-- Column headers + target buttons.
	Library:CreateLabel({
		Position = UDim2.new(0, 10, 0, 34),
		Size = UDim2.new(0.5, -80, 0, 16),
		Text = "PRESHRINE",
		TextSize = 13,
		TextColor3 = Library.AccentColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 703,
		Parent = frame,
	})
	Library:CreateLabel({
		Position = UDim2.new(0.5, 6, 0, 34),
		Size = UDim2.new(0.5, -80, 0, 16),
		Text = "POSTSHRINE",
		TextSize = 13,
		TextColor3 = Library.AccentColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 703,
		Parent = frame,
	})

	local function targetButton(xScale, text, onClick)
		local button = Library:Create("TextButton", {
			BackgroundColor3 = Library.MainColor,
			BorderSizePixel = 0,
			Position = UDim2.new(xScale, xScale == 0 and 10 or 4, 0, 52),
			Size = UDim2.new(0.5, -14, 0, 18),
			Text = text,
			TextColor3 = Library.FontColor,
			FontFace = Library.Font,
			TextSize = 12,
			ZIndex = 703,
			AutoButtonColor = true,
			Parent = frame,
		})
		Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = button })
		button.MouseButton1Click:Connect(onClick)
		return button
	end

	preButton = targetButton(0, "Use Preshrine", function()
		AutoBuilder.setTarget("pre")
		refreshTargetButtons()
	end)
	postButton = targetButton(0.5, "Use Postshrine", function()
		AutoBuilder.setTarget("post")
		refreshTargetButtons()
	end)

	preColumn = buildColumn(0)
	postColumn = buildColumn(0.5)
end

---Populate + show the window for a loaded, classified build.
---@param build table
---@param classified table
function AutoBuilderWindow.show(build, classified)
	ensure()

	titleLabel.Text = string.format("Auto Builder  -  %s", build.name)

	renderColumn(preColumn, columnRows(build.pre, classified.pre))
	renderColumn(postColumn, columnRows(build.post, classified.post))

	refreshTargetButtons()

	frame.Visible = true
end

function AutoBuilderWindow.hide()
	if built then
		frame.Visible = false
	end
end

return AutoBuilderWindow
