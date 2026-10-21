---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.TaskSpawner
local TaskSpawner = require("Utility/TaskSpawner")

---@class EntityESP
local EntityESP = {}
EntityESP.__index = EntityESP
EntityESP.__type = "EntityESP"

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")

local ELEMENT_PADDING = 1
local BILLBOARD_MIN_WIDTH = 10
local BILLBOARD_MIN_HEIGHT = 10

local _textLabelCache = setmetatable({}, { __mode = "k" })
local _barCache = setmetatable({}, { __mode = "k" })

---@param frame Frame
---@param strokeColor Color3
---@param insideOffset number
EntityESP.gio = LPH_NO_VIRTUALIZE(function(frame, strokeColor, insideOffset)
	local sizeOffset = -insideOffset * 2
	local strokeContainer = Instance.new("Frame")
	strokeContainer.Name = "Outline_" .. tostring(insideOffset)
	strokeContainer.Parent = frame
	strokeContainer.Size = UDim2.new(1, sizeOffset, 1, sizeOffset)
	strokeContainer.Position = UDim2.new(0, insideOffset, 0, insideOffset)
	strokeContainer.BackgroundTransparency = 1

	local outlineStroke = Instance.new("UIStroke")
	outlineStroke.Color = strokeColor
	outlineStroke.Thickness = 1
	outlineStroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	outlineStroke.Parent = strokeContainer

	return strokeContainer
end)

---@param self EntityESP
---@param container Frame
---@param text string
EntityESP.utext = LPH_NO_VIRTUALIZE(function(self, container, text)
	local textLabel = _textLabelCache[container]
	if not textLabel then
		textLabel = container:FindFirstChildOfClass("TextLabel")
		if not textLabel then
			return
		end
		_textLabelCache[container] = textLabel
	end

	textLabel.Text = text
	textLabel.TextSize = Configuration.expectOptionValue("FontSize") or 13
	textLabel.Font = Enum.Font[Configuration.expectOptionValue("Font") or "Code"] or Enum.Font.Code
	textLabel.TextColor3 = Configuration.idOptionValue(self.identifier, "Color") or Color3.new(1, 1, 1)

	local transparency = 1 - (Configuration.idOptionValue(self.identifier, "TextOpacity") or 100) / 100
	textLabel.TextTransparency = transparency
	textLabel.TextStrokeTransparency = transparency
end)

EntityESP.gb = LPH_NO_VIRTUALIZE(function(container)
	local cached = _barCache[container]
	if cached then
		return cached
	end

	local background = container:FindFirstChild("Background")
	if not background then
		return nil
	end

	local barArea = background:FindFirstChild("BarArea")
	if not barArea then
		return nil
	end

	local bar = barArea:FindFirstChild("Bar")
	if not bar then
		return nil
	end

	_barCache[container] = bar
	return bar
end)

---@param container Frame
---@param vertical boolean
---@param percentage number
EntityESP.mbs = LPH_NO_VIRTUALIZE(function(container, vertical, percentage)
	local bar = _barCache[container]
	if not bar then
		local background = container:FindFirstChild("Background")
		local barArea = background and background:FindFirstChild("BarArea")
		bar = barArea and barArea:FindFirstChild("Bar")
		if not bar then
			return
		end
		_barCache[container] = bar
	end

	percentage = math.clamp(percentage, 0.0, 1.0)

	if vertical then
		bar.Size = UDim2.new(1, 0, percentage, 0)
	else
		bar.Size = UDim2.new(percentage, 0, 1, 0)
	end
end)

---@param container Frame
---@param vertical boolean
---@param seperators boolean
---@param color Color3
EntityESP.cgb = LPH_NO_VIRTUALIZE(function(self, container, seperators, vertical, color)
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Parent = container

	if vertical then
		background.Size = UDim2.new(1, -1, -1, 0)
		background.Position = UDim2.new(1, -1, 1, 0)
		background.AnchorPoint = Vector2.new(1.0, 0.0)
	else
		background.Size = UDim2.new(1, 0, 1, 0)
		background.Position = UDim2.new(0, 0, 0, 0)
		background.AnchorPoint = Vector2.new(0, 0)
	end

	background.BackgroundColor3 = Color3.new(0.0862745, 0.105882, 0.219608)
	background.BorderSizePixel = 0

	self.gio(background, Color3.new(0, 0, 0), 0)

	local barArea = Instance.new("Frame")
	barArea.Name = "BarArea"
	barArea.Parent = background
	barArea.BackgroundTransparency = 1
	barArea.Position = UDim2.new(0, 1, 0, 1)
	barArea.Size = UDim2.new(1, -2, 1, -2)
	barArea.ZIndex = 1

	if seperators then
		for Idx = 1, 4 do
			local Separator = Instance.new("Frame")
			Separator.Name = "Separator"
			Separator.Parent = barArea
			Separator.BackgroundColor3 = Color3.new(0, 0, 0)
			Separator.BorderSizePixel = 0
			Separator.Position = UDim2.new(0, 0, Idx / 5, 0)
			Separator.Size = UDim2.new(1, 0, 0, 1)
			Separator.ZIndex = 3
		end
	end

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Parent = barArea
	bar.BorderSizePixel = 0
	bar.ZIndex = 2

	if vertical then
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0, 0, 1, 0)
		bar.Size = UDim2.new(1, 0, 0.0, 0)
	else
		bar.Position = UDim2.new(0, 0, 0, 0)
		bar.Size = UDim2.new(0.0, 0, 1, 0)
	end

	bar.BackgroundColor3 = color
end)

---@param visible boolean
EntityESP.visible = LPH_NO_VIRTUALIZE(function(self, visible)
	self.billboard.Enabled = visible
end)

EntityESP.detach = LPH_NO_VIRTUALIZE(function(self)
	self.maid:clean()
end)

---@param self EntityESP
---@param distance number
EntityESP.useperators = LPH_NO_VIRTUALIZE(function(self, distance)
	if not self._cachedSeparators then
		local bar = self.gb(self.hbar)
		if not bar then
			return
		end

		local seps = {}
		for _, sep in next, bar.Parent:GetChildren() do
			if sep:IsA("Frame") and sep.Name == "Separator" then
				seps[#seps + 1] = sep
			end
		end
		self._cachedSeparators = seps
	end

	local vis = distance <= 300
	for _, sep in next, self._cachedSeparators do
		sep.Visible = vis
	end
end)

---@param self EntityESP
---@param label string
---@param tags string[]
---@return string, number
EntityESP.btext = LPH_NO_VIRTUALIZE(function(self, label, tags)
	if #tags <= 0 then
		return label
	end

	local lines = {}
	local start = true

	for _, tag in next, tags do
		local line = lines[#lines] or label

		if not start and #line > Configuration.expectOptionValue("ESPSplitLineLength") then
			lines[#lines + 1] = tag
			continue
		end

		line = line .. " " .. tag

		lines[start and 1 or #lines] = line

		start = false
	end

	return table.concat(lines, "\n"), #lines
end)

---@param self PlayerESP
EntityESP.hchanged = LPH_NO_VIRTUALIZE(function(self)
	if not self.lhealth then
		return
	end

	if self.billboard.Enabled == false then
		return
	end

	if not Configuration.idToggleValue(self.identifier, "ShowHealthChanges") then
		return
	end

	local character = self.entity
	if not character or not character:IsA("Model") then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local debris = replicatedStorage:FindFirstChild("Debris")
	if not debris then
		return
	end

	local newHealth = humanoid.Health
	local differenceColor = Color3.fromRGB(255, 0, 0)
	local differenceAmount = newHealth - self.lhealth

	if differenceAmount >= 0 then
		differenceColor = Color3.fromRGB(0, 255, 0)
	end

	self.lhealth = newHealth

	if differenceAmount >= -0.5 and differenceAmount <= 0.5 then
		return
	end

	local clientEffectModules = replicatedStorage:FindFirstChild("ClientEffectModules")
	local replication = clientEffectModules and clientEffectModules:FindFirstChild("Replication")
	local replicationModule = replication and replication:FindFirstChild("Replication")
	if not replicationModule then
		return
	end

	local damageSplash = replicationModule:FindFirstChild("DamageSplash")
	if not damageSplash then
		return
	end

	local thrown = workspace:FindFirstChild("Thrown")
	if not thrown then
		return
	end

	local initialOffset = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * 2
	local clonedSplash = damageSplash:Clone()
	clonedSplash.Adornee = root
	clonedSplash.Size = UDim2.new(2.5, 0, 0.5, 0)
	clonedSplash.Parent = thrown
	clonedSplash.TextLabel.Text = string.format("%.02f", differenceAmount)
	clonedSplash.StudsOffsetWorldSpace = initialOffset

	if differenceColor then
		clonedSplash.TextLabel.TextColor3 = differenceColor
	end

	local textLabel = clonedSplash and clonedSplash:FindFirstChild("TextLabel")
	if not textLabel then
		return
	end

	local uiStroke = textLabel:FindFirstChild("UIStroke")
	if not uiStroke then
		return
	end

	uiStroke.Transparency = 1.0

	tweenService
		:Create(clonedSplash, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
			Size = UDim2.new(5, 0, 1),
		})
		:Play()

	tweenService
		:Create(clonedSplash, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			StudsOffsetWorldSpace = initialOffset + Vector3.new(0, 10, 0),
		})
		:Play()

	self.maid:mark(TaskSpawner.delay("PlayerESP_RemoveDamageSplash", function()
		return 3.0
	end, function()
		tweenService
			:Create(textLabel, TweenInfo.new(2), {
				TextTransparency = 1,
			})
			:Play()
	end))

	debris:Fire(clonedSplash, 5)
end)

---@param self InstanceESP
---@param tags string[]
EntityESP.update = LPH_NO_VIRTUALIZE(function(self, tags)
	local identifier = self.identifier

	local localPlayer = playersService.LocalPlayer
	local localCharacter = localPlayer and localPlayer.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")

	local entity = self.entity
	local entityHumanoid = self._cachedHumanoid
	local entityRoot = self._cachedRoot

	if not entityHumanoid or not entityHumanoid.Parent then
		entityHumanoid = entity and entity:FindFirstChildOfClass("Humanoid")
		self._cachedHumanoid = entityHumanoid
	end

	if not entityRoot or not entityRoot.Parent then
		entityRoot = entity and entity:FindFirstChild("HumanoidRootPart")
		self._cachedRoot = entityRoot
	end

	local position = entityRoot and entityRoot.Position

	if not Configuration.idToggleValue(identifier, "Enable") then
		return self:visible(false)
	end

	if not entityHumanoid then
		return self:visible(false)
	end

	if not localRoot then
		return self:visible(false)
	end

	if not position then
		return self:visible(false)
	end

	local distance = (localRoot.Position - position).Magnitude

	if distance > Configuration.idOptionValue(identifier, "MaxDistance") then
		return self:visible(false)
	end

	---@todo: This was a lazy way to connect to the signal.
	if not self.maid["PlayerESP_OnHealthChanged"] and not self.lhealth then
		local onHealthChanged = Signal.new(entityHumanoid.HealthChanged)

		self.lhealth = entityHumanoid.Health

		self.maid["PlayerESP_OnHealthChanged"] = onHealthChanged:connect("PlayerESP_OnHealthChanged", function()
			self:hchanged()
		end)
	end

	self.billboard.Adornee = entityRoot

	local bbstroke = self.bbstroke
	local wbstroke = self.wbstroke
	local dcontainer = self.dcontainer
	local ncontainer = self.ncontainer
	local hbar = self.hbar

	bbstroke.Visible = Configuration.idToggleValue(identifier, "BoundingBox")
	wbstroke.Visible = Configuration.idToggleValue(identifier, "BoundingBox")
	dcontainer.Visible = Configuration.idToggleValue(identifier, "ShowDistance")
	hbar.Visible = Configuration.idToggleValue(identifier, "HealthBar")

	local fontSize = Configuration.expectOptionValue("FontSize") or 13
	local text, lines = self:btext(self.label, tags)
	self:utext(ncontainer, text)

	local name = self._cachedNameElement
	if not name then
		name = self:find("Name")
		self._cachedNameElement = name
	end
	if name then
		name.space = (lines * fontSize) + (ELEMENT_PADDING * 2)
	end

	local delement = self._cachedDistElement
	if not delement then
		delement = self:find("Distance")
		self._cachedDistElement = delement
	end
	if delement then
		delement.space = fontSize + (ELEMENT_PADDING * 2)
	end

	if dcontainer then
		self:utext(dcontainer, string.format("%im", math.floor(distance)))
	end

	local bar = self.gb(hbar)

	if hbar and bar then
		local percent = entityHumanoid.Health / entityHumanoid.MaxHealth
		local fullColor = Configuration.idOptionValue(identifier, "FullColor")
		local emptyColor = Configuration.idOptionValue(identifier, "EmptyColor")

		self.mbs(hbar, true, percent)

		bar.BackgroundColor3 = emptyColor:Lerp(fullColor, math.clamp(percent, 0.0, 1.0))

		self:useperators(distance)
	end

	self:build()

	self:visible(true)
end)

EntityESP.build = LPH_NO_VIRTUALIZE(function(self)
	local sideOffsets = { top = 0, bottom = 0, left = 0, right = 0 }

	for side, elementList in next, self.elements do
		local offsetElementCount = 0

		for _, item in next, elementList do
			if not item.container.Visible then
				continue
			end

			sideOffsets[side] = sideOffsets[side] + item.space + ELEMENT_PADDING
			offsetElementCount = offsetElementCount + 1
		end

		if offsetElementCount > 0 then
			sideOffsets[side] = sideOffsets[side] - ELEMENT_PADDING
		end
	end

	local maxHorizontalPadding = math.max(sideOffsets.left, sideOffsets.right)
	local maxVerticalPadding = math.max(sideOffsets.top, sideOffsets.bottom)

	local now = os.clock()
	if not self._lastExtentsTime or (now - self._lastExtentsTime) >= 1.0 then
		local extentsSize = self.entity:GetExtentsSize()
		self._lastExtentsTime = now

		if self.lextents and math.abs(self.lextents.Magnitude - extentsSize.Magnitude) >= 10.0 then
			self.sextents = nil
			self._cachedBoneParts = nil
		end

		self.lextents = extentsSize
	end

	if not self.sextents then
		local parts = self._cachedBoneParts
		if not parts then
			parts = {}
			for _, inst in next, self.entity:GetDescendants() do
				if inst:IsA("BasePart") then
					if not inst.Parent:IsA("BasePart") and (inst:FindFirstChildWhichIsA("Weld") or inst:FindFirstChildWhichIsA("Motor6D") or inst.Name == "HumanoidRootPart") then
						parts[#parts + 1] = inst
					end
				end
			end
			self._cachedBoneParts = parts
		end

		local minX, minY, minZ = math.huge, math.huge, math.huge
		local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
		local found = false

		for _, inst in next, parts do
			if inst.Parent then
				local size = inst.Size
				local pos = inst.CFrame.Position
				minX = math.min(minX, pos.X - size.X / 2)
				minY = math.min(minY, pos.Y - size.Y / 2)
				minZ = math.min(minZ, pos.Z - size.Z / 2)
				maxX = math.max(maxX, pos.X + size.X / 2)
				maxY = math.max(maxY, pos.Y + size.Y / 2)
				maxZ = math.max(maxZ, pos.Z + size.Z / 2)
				found = true
			end
		end

		if found then
			self.sextents = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
		else
			self.sextents = self.lextents or self.entity:GetExtentsSize()
		end
	end

	self.billboard.Size = UDim2.new(
		self.sextents.X + 1.5,
		maxHorizontalPadding * 2 + BILLBOARD_MIN_WIDTH,
		self.sextents.Y + 1.5,
		maxVerticalPadding * 2 + BILLBOARD_MIN_HEIGHT
	)

	self.bbox.Position = UDim2.new(0, maxHorizontalPadding, 0, maxVerticalPadding)
	self.bbox.Size = UDim2.new(1, -(maxHorizontalPadding * 2), 1, -(maxVerticalPadding * 2))

	local currentTopOffset = 0

	for _, element in next, self.elements.top do
		if not element.container.Visible then
			continue
		end

		if element.container.Parent ~= self.canvas then
			element.container.Parent = self.canvas
		end
		element.container.AnchorPoint = Vector2.new(0, 1)
		element.container.Position = UDim2.new(0, maxHorizontalPadding, 0, maxVerticalPadding - currentTopOffset)
		element.container.Size = UDim2.new(1, -(maxHorizontalPadding * 2), 0, element.space)
		currentTopOffset = currentTopOffset + element.space + ELEMENT_PADDING

		if element.created then
			continue
		end

		if not element.create then
			continue
		end

		element.create(element.container)
		element.created = true
	end

	local currentBottomOffset = 0

	for _, element in next, self.elements.bottom do
		if not element.container.Visible then
			continue
		end

		if element.container.Parent ~= self.bbox then
			element.container.Parent = self.bbox
		end
		element.container.AnchorPoint = Vector2.new(0, 0)
		element.container.Position = UDim2.new(0, 0, 1, currentBottomOffset)
		element.container.Size = UDim2.new(1, 0, 0, element.space)
		currentBottomOffset = currentBottomOffset + element.space + ELEMENT_PADDING

		if element.created then
			continue
		end

		if not element.create then
			continue
		end

		element.create(element.container)
		element.created = true
	end

	local currentLeftOffset = 0

	for _, element in next, self.elements.left do
		if not element.container.Visible then
			continue
		end

		if element.container.Parent ~= self.canvas then
			element.container.Parent = self.canvas
		end
		element.container.AnchorPoint = Vector2.new(1, 0)
		element.container.Position = UDim2.new(0, maxHorizontalPadding - currentLeftOffset, 0, maxVerticalPadding)
		element.container.Size = UDim2.new(0, element.space, 1, -(maxVerticalPadding * 2))
		currentLeftOffset = currentLeftOffset + element.space + ELEMENT_PADDING

		if element.created then
			continue
		end

		if not element.create then
			continue
		end

		element.create(element.container)
		element.created = true
	end

	local currentRightOffset = 0

	for _, element in next, self.elements.right do
		if not element.container.Visible then
			continue
		end

		if element.container.Parent ~= self.bbox then
			element.container.Parent = self.bbox
		end
		element.container.AnchorPoint = Vector2.new(0, 0)
		element.container.Position = UDim2.new(1, currentRightOffset, 0, 0)
		element.container.Size = UDim2.new(0, element.space, 1, 0)
		currentRightOffset = currentRightOffset + element.space + ELEMENT_PADDING

		if element.created then
			continue
		end

		if not element.create then
			continue
		end

		element.create(element.container)
		element.created = true
	end
end)

---@param name string
EntityESP.find = LPH_NO_VIRTUALIZE(function(self, name)
	for _, list in next, self.elements do
		for _, element in next, list do
			if element.name ~= name then
				continue
			end

			return element
		end
	end

	return nil
end)

---@param name string
---@param side string "Top" | "Bottom" | "Left" | "Right"
---@param space number
---@param create function
EntityESP.add = LPH_NO_VIRTUALIZE(function(self, name, side, space, create)
	local container = Instance.new("Frame")
	container.Name = string.format("%s_Container_%s", side, name)
	container.BackgroundTransparency = 1

	table.insert(self.elements[side], {
		name = name,
		container = container,
		space = space,
		create = create,
		created = false,
	})

	return container
end)

EntityESP.extra = LPH_NO_VIRTUALIZE(function(_) end)

EntityESP.setup = LPH_NO_VIRTUALIZE(function(self)
	local root = self.entity:FindFirstChild("HumanoidRootPart")

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.AlwaysOnTop = true
	billboardGui.Enabled = false
	billboardGui.Adornee = root or self.entity
	billboardGui.Parent = workspace
	billboardGui.ClipsDescendants = false
	billboardGui.AutoLocalize = false

	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.new(1, 0, 1, 0)
	canvas.Position = UDim2.new(0, 0, 0, 0)
	canvas.Parent = billboardGui

	local espBoundingBox = Instance.new("Frame")
	espBoundingBox.Name = "ESPBoundingBox"
	espBoundingBox.Parent = canvas
	espBoundingBox.BackgroundTransparency = 1
	espBoundingBox.Size = UDim2.new(1, 0, 1, 0)
	espBoundingBox.Position = UDim2.new(0, 0, 0, 0)

	self.bbstroke = self.gio(espBoundingBox, Color3.new(0, 0, 0), 0)
	self.wbstroke = self.gio(espBoundingBox, Color3.new(1, 1, 1), 1)

	self.billboard = self.maid:mark(billboardGui)
	self.canvas = self.maid:mark(canvas)
	self.bbox = self.maid:mark(espBoundingBox)

	self.hbar = self:add("HealthBar", "left", 6, function(container)
		self:cgb(container, true, true, Color3.new(1.0, 1.0, 1.0))
	end)

	self:extra()

	self.dcontainer = self:add("Distance", "bottom", 16, function(container)
		local textLabel = Instance.new("TextLabel")
		textLabel.Parent = container
		textLabel.Text = "0m"
		textLabel.Size = UDim2.new(0, 400, 1, 0)
		textLabel.AnchorPoint = Vector2.new(0.5, 0)
		textLabel.Position = UDim2.new(0.5, 0, 0, 0)
		textLabel.BackgroundTransparency = 1.0
		textLabel.TextStrokeColor3 = Color3.new(0.0, 0.0, 0.0)
		textLabel.TextStrokeTransparency = 0.0
		textLabel.TextColor3 = Color3.new(1.0, 1.0, 1.0)
		textLabel.TextSize = 13
		textLabel.TextWrapped = false
		textLabel.Font = Enum.Font.Code
	end)

	self.ncontainer = self:add("Name", "top", 16, function(container)
		local textLabel = Instance.new("TextLabel")
		textLabel.Parent = container
		textLabel.Text = "N/A"
		textLabel.Size = UDim2.new(0, 400, 1, 0)
		textLabel.AnchorPoint = Vector2.new(0.5, 0)
		textLabel.Position = UDim2.new(0.5, 0, 0, 0)
		textLabel.BackgroundTransparency = 1.0
		textLabel.TextStrokeColor3 = Color3.new(0.0, 0.0, 0.0)
		textLabel.TextStrokeTransparency = 0.0
		textLabel.TextColor3 = Color3.new(0.0117647, 1, 1)
		textLabel.TextSize = 13
		textLabel.TextWrapped = false
		textLabel.Font = Enum.Font.Code
	end)
end)

---@param entity Model
---@param identifier string
---@param label string
function EntityESP.new(entity, identifier, label)
	local self = setmetatable({}, EntityESP)
	self.label = label
	self.entity = entity
	self.identifier = identifier
	self.maid = Maid.new()
	self.elements = {
		top = {},
		bottom = {},
		left = {},
		right = {},
	}

	return self
end

return EntityESP
