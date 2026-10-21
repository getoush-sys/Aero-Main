-- Target HUD: a compact, draggable on-screen panel showing the current best target's name, level,
-- distance, and stat bars (health + any of posture/blood/sanity the entity exposes). There is no
-- prebuilt target HUD in the YSL library -- only the Library.TargetHUDFrame scaffolding (HUD-transparency
-- + layout hook) -- so this builds the frame and assigns it there, then drives it from Targeting.best().

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Features.Combat.Targeting
local Targeting = require("Features/Combat/Targeting")

local players = game:GetService("Players")
local runService = game:GetService("RunService")

local TargetHUD = {}

-- Bars drawn top-to-bottom. "health" reads the Humanoid; the rest read a child value-store object
-- (entity:FindFirstChild(store).Value / .MaxValue) exactly like the player ESP does.
local BAR_SPECS = {
	{ id = "health", label = "HP", color = Color3.fromRGB(86, 214, 110) },
	{ id = "posture", label = "POS", color = Color3.fromRGB(240, 170, 60), store = "BreakMeter" },
	{ id = "blood", label = "BLD", color = Color3.fromRGB(214, 64, 72), store = "Blood" },
	{ id = "sanity", label = "SAN", color = Color3.fromRGB(150, 110, 222), store = "Sanity" },
}

local UPDATE_INTERVAL = 0.08

local frame
local nameLabel
local distLabel
local bars = {}
local built = false
local lastUpdate = 0

---@param parent Instance
---@param order number
---@param spec table
---@return table
local function makeBar(parent, order, spec)
	local row = Library:Create("Frame", {
		Name = spec.id .. "Bar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = order,
		Parent = parent,
	})

	local tag = Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(30, 14),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Library.FontColor,
		Text = spec.label,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = row,
	})
	Library:AddToRegistry(tag, { TextColor3 = "FontColor" }, true)

	local track = Library:Create("Frame", {
		Name = "Track",
		BackgroundColor3 = Library.BackgroundColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 32, 0.5, -4),
		Size = UDim2.new(1, -32, 0, 8),
		Parent = row,
	})
	Library:AddToRegistry(track, { BackgroundColor3 = "BackgroundColor" }, true)

	local fill = Library:Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = spec.color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})

	local valueText = Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.35,
		Text = "",
		Parent = track,
	})

	return { row = row, fill = fill, text = valueText }
end

local function build()
	if built then
		return
	end
	built = true

	frame = Library:Create("Frame", {
		Name = "YSL_TargetHUD",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Library.MainColor,
		BackgroundTransparency = Library.HudTransparency or 0.18,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(224, 0),
		Visible = false,
		ZIndex = 90,
		Parent = Library.ScreenGui,
	})
	-- Hook into the library's scaffolding: HUD-transparency and layout both key off Library.TargetHUDFrame.
	Library.TargetHUDFrame = frame
	Library:AddUIScale(frame)
	Library:MakeDraggable(frame, 10)
	Library:AddToRegistry(frame, { BackgroundColor3 = "MainColor" }, true)

	local stroke = Library:Create("UIStroke", {
		Color = Library.AccentColor,
		Thickness = 1,
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	})
	Library:AddToRegistry(stroke, { Color = "AccentColor" })

	Library:Create("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = frame,
	})

	Library:Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
		Parent = frame,
	})

	local header = Library:Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 0,
		Parent = frame,
	})

	nameLabel = Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -62, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Library.FontColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Target",
		Parent = header,
	})
	Library:AddToRegistry(nameLabel, { TextColor3 = "FontColor" }, true)

	distLabel = Library:Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(60, 16),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = Library.AccentColor,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
		Parent = header,
	})
	Library:AddToRegistry(distLabel, { TextColor3 = "AccentColor" }, true)

	for index, spec in ipairs(BAR_SPECS) do
		bars[spec.id] = makeBar(frame, index, spec)
	end
end

---@param bar table
---@param value number
---@param maxValue number
local function setBar(bar, value, maxValue)
	local ratio = 0
	if maxValue and maxValue > 0 then
		ratio = math.clamp(value / maxValue, 0, 1)
	end
	bar.fill.Size = UDim2.fromScale(ratio, 1)
	bar.text.Text = string.format("%d / %d", math.floor(value + 0.5), math.floor((maxValue or 0) + 0.5))
end

-- Reads a child value-store (.Value / .MaxValue). Returns nil if the entity doesn't expose it.
---@param entity Instance
---@param storeName string
---@return number?, number?
local function readStore(entity, storeName)
	local store = entity:FindFirstChild(storeName)
	if not store then
		return nil
	end
	local ok, value, maxValue = pcall(function()
		return store.Value, store.MaxValue
	end)
	if ok and type(value) == "number" and type(maxValue) == "number" then
		return value, maxValue
	end
	return nil
end

local function update()
	if not Configuration.expectToggleValue("TargetHUD") then
		if frame then
			frame.Visible = false
		end
		return
	end

	build()

	local best = Targeting.best()[1]
	if not best or not best.character or not best.humanoid or best.humanoid.Health <= 0 then
		frame.Visible = false
		return
	end

	frame.Visible = true

	local entity = best.character
	local player = players:GetPlayerFromCharacter(entity)
	local name = (player and (player:GetAttribute("CharacterName") or player.Name))
		or entity:GetAttribute("MOB_rich_name")
		or entity.Name
	local level = entity:GetAttribute("Level")
	nameLabel.Text = (level and string.format("%s  [Lv.%d]", tostring(name), level)) or tostring(name)
	distLabel.Text = string.format("%.0fst", best.du or 0)

	for _, spec in ipairs(BAR_SPECS) do
		local bar = bars[spec.id]
		if spec.id == "health" then
			bar.row.Visible = true
			setBar(bar, best.humanoid.Health, best.humanoid.MaxHealth)
		else
			local value, maxValue = readStore(entity, spec.store)
			if value then
				bar.row.Visible = true
				setBar(bar, value, maxValue)
			else
				bar.row.Visible = false
			end
		end
	end
end

local updateConnection = nil

function TargetHUD.init()
	local renderStepped = Signal.new(runService.RenderStepped)
	updateConnection = renderStepped:connect("TargetHUD_Update", function()
		if os.clock() - lastUpdate < UPDATE_INTERVAL then
			return
		end
		lastUpdate = os.clock()
		update()
	end)
end

function TargetHUD.detach()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
end

return TargetHUD
