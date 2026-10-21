-- Reusable floating, draggable window (title bar + close button + body) parented to the menu ScreenGui.
-- new{ title, size, position } -> { frame, body, Show, Hide, Toggle, IsOpen, SetTitle }. Starts hidden.

---@module GUI.Library
local Library = require("GUI/Library")

local FloatingWindow = {}

local BAR_H = 26

---@param opts table
---@return table
function FloatingWindow.new(opts)
	opts = opts or {}
	local size = opts.size or UDim2.fromOffset(360, 300)
	local position = opts.position or UDim2.fromScale(0.5, 0.5)

	local outer = Library:Create("Frame", {
		Name = "LumaFloatingWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 200,
		Parent = Library.ScreenGui,
	})
	Library:Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = outer })
	local st = Library:Create("UIStroke", { Color = Library.AccentColor, Thickness = 1, Transparency = 0.2, Parent = outer })
	Library:AddToRegistry(outer, { BackgroundColor3 = "MainColor" })
	Library:AddToRegistry(st, { Color = "AccentColor" })
	pcall(function()
		Library:AddUIScale(outer)
	end)

	local bar = Library:Create("Frame", {
		BackgroundColor3 = Library.BackgroundColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, BAR_H),
		ZIndex = 201,
		Parent = outer,
	})
	Library:Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = bar })
	Library:AddToRegistry(bar, { BackgroundColor3 = "BackgroundColor" })

	-- cover the bar's bottom rounded corners so it sits flush on the body
	Library:Create("Frame", {
		BackgroundColor3 = Library.BackgroundColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 6),
		ZIndex = 201,
		Parent = bar,
	})

	local titleLabel = Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = tostring(opts.title or "Window"),
		TextSize = 13,
		TextColor3 = Library.FontColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 202,
		Parent = bar,
	})
	Library:AddToRegistry(titleLabel, { TextColor3 = "FontColor" })

	local closeBtn = Library:Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "X",
		TextSize = 13,
		TextColor3 = Library.FontColor,
		ZIndex = 202,
		Parent = bar,
	})
	Library:AddToRegistry(closeBtn, { TextColor3 = "FontColor" })

	local body = Library:Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 0, BAR_H + 4),
		Size = UDim2.new(1, -12, 1, -(BAR_H + 10)),
		ZIndex = 201,
		Parent = outer,
	})

	pcall(function()
		Library:MakeDraggable(outer, BAR_H)
	end)

	local window = {
		frame = outer,
		body = body,
	}

	function window:IsOpen()
		return outer.Visible
	end

	function window:Show()
		outer.Visible = true
		outer.ZIndex = 200
	end

	function window:Hide()
		outer.Visible = false
	end

	function window:Toggle()
		if outer.Visible then
			self:Hide()
		else
			self:Show()
		end
	end

	function window:SetTitle(t)
		titleLabel.Text = tostring(t or "")
	end

	closeBtn.MouseEnter:Connect(function()
		closeBtn.TextColor3 = Library.AccentColor
	end)
	closeBtn.MouseLeave:Connect(function()
		closeBtn.TextColor3 = Library.FontColor
	end)
	closeBtn.MouseButton1Click:Connect(function()
		window:Hide()
	end)

	return window
end

return FloatingWindow
