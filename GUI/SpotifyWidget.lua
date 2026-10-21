local SpotifyClient = require("Utility/SpotifyClient")
local Filesystem = require("Utility/Filesystem")
local Logger = require("Utility/Logger")

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Mouse = Players.LocalPlayer:GetMouse()

local artStorage = Filesystem.new("Aero/Spotify/Art")
local artCache = {}

local POLL_INTERVAL = 2

local SpotifyWidget = {}

local built = false
local library = nil

local outer, inner, artLabel, titleLabel, artistLabel
local barBack, barFill, scrubberDot, currentTimeLabel, durationLabel
local playPauseLabel

local lastPoll = 0
local nowPlaying = nil
local lastProgressMs = 0
local lastProgressAt = 0
local fetchingArt = {}
local scrubbing = false

local function formatTime(ms)
	local totalSeconds = math.floor((ms or 0) / 1000)
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return string.format("%d:%02d", minutes, seconds)
end

local function fetchAlbumArt(trackId, url)
	if not trackId or not url or artCache[trackId] or fetchingArt[trackId] then
		return
	end

	fetchingArt[trackId] = true

	task.spawn(function()
		local filename = trackId .. ".png"
		local contentId = nil

		local ok = pcall(function()
			if not artStorage:file(filename) then
				local response = request({ Url = url, Method = "GET" })
				if not response or not response.Success or not response.Body then
					return
				end
				artStorage:write(filename, response.Body)
			end

			contentId = getcustomasset(artStorage:append(filename))
		end)

		if ok and contentId then
			artCache[trackId] = contentId
			if nowPlaying and nowPlaying.trackId == trackId then
				artLabel.Image = contentId
			end
		end

		fetchingArt[trackId] = nil
	end)
end

local function makeControlButton(parent, text, position, callback)
	local buttonOuter = library:Create("Frame", {
		BackgroundTransparency = 1,
		Position = position,
		Size = UDim2.new(0, 30, 0, 24),
		ZIndex = 210,
		Parent = parent,
	})

	local label = library:CreateLabel({
		Active = false,
		Size = UDim2.new(1, 0, 1, 0),
		TextSize = 18,
		Text = text,
		ZIndex = 211,
		Parent = buttonOuter,
	})

	library:OnHighlight(buttonOuter, label, { TextColor3 = "AccentColor" }, { TextColor3 = "FontColor" })

	label.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 and not library:MouseIsOverOpenedFrame() then
			callback()
		end
	end)

	return buttonOuter, label
end

function SpotifyWidget.init(Library)
	if built then
		return
	end
	built = true
	library = Library

	outer = library:Create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderColor3 = library.AccentColor,
		Position = UDim2.new(0, 100, 0, 100),
		Size = UDim2.new(0, 230, 0, 300),
		Visible = false,
		ZIndex = 205,
		Parent = library.ScreenGui,
	})

	library:AddToRegistry(outer, {
		BorderColor3 = "AccentColor",
	})

	library:Create("UICorner", {
		CornerRadius = UDim.new(0, 10),
		Parent = outer,
	})

	library:MakeDraggable(outer)

	inner = library:Create("Frame", {
		BackgroundColor3 = library.MainColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 206,
		Parent = outer,
	})

	library:AddToRegistry(inner, {
		BackgroundColor3 = "MainColor",
	})

	library:Create("UICorner", {
		CornerRadius = UDim.new(0, 9),
		Parent = inner,
	})

	artLabel = library:Create("ImageLabel", {
		BackgroundColor3 = library:GetDarkerColor(library.MainColor),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 6),
		Size = UDim2.new(1, -12, 0, 180),
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 207,
		Parent = inner,
	})

	library:AddToRegistry(artLabel, {
		BackgroundColor3 = "MainColor",
	})

	library:Create("UICorner", {
		CornerRadius = UDim.new(0, 8),
		Parent = artLabel,
	})

	titleLabel = library:CreateLabel({
		Position = UDim2.new(0, 6, 0, 190),
		Size = UDim2.new(1, -12, 0, 18),
		TextSize = 14,
		Text = "Nothing playing",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 207,
		Parent = inner,
	})

	artistLabel = library:CreateLabel({
		Position = UDim2.new(0, 6, 0, 208),
		Size = UDim2.new(1, -12, 0, 16),
		TextSize = 12,
		Text = "",
		TextColor3 = Color3.fromRGB(170, 170, 170),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 207,
		Parent = inner,
	})

	barBack = library:Create("Frame", {
		BackgroundColor3 = library.OutlineColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 0, 236),
		Size = UDim2.new(1, -12, 0, 3),
		ZIndex = 207,
		Parent = inner,
	})

	library:AddToRegistry(barBack, {
		BackgroundColor3 = "OutlineColor",
	})

	library:Create("UICorner", {
		CornerRadius = UDim.new(1, 0),
		Parent = barBack,
	})

	barFill = library:Create("Frame", {
		BackgroundColor3 = library.AccentColor,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 208,
		Parent = barBack,
	})

	library:AddToRegistry(barFill, {
		BackgroundColor3 = "AccentColor",
	})

	library:Create("UICorner", {
		CornerRadius = UDim.new(1, 0),
		Parent = barFill,
	})

	scrubberDot = library:Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 8, 0, 8),
		ZIndex = 209,
		Parent = barFill,
	})

	library:Create("UICorner", {
		CornerRadius = UDim.new(1, 0),
		Parent = scrubberDot,
	})

	local barHitArea = library:Create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 212,
		Parent = barBack,
	})

	local function seekToMouseX()
		if not nowPlaying or nowPlaying.durationMs <= 0 then
			return nil
		end

		local relativeX = Mouse.X - barBack.AbsolutePosition.X
		local percent = math.clamp(relativeX / barBack.AbsoluteSize.X, 0, 1)

		barFill.Size = UDim2.new(percent, 0, 1, 0)
		currentTimeLabel.Text = formatTime(percent * nowPlaying.durationMs)

		return percent
	end

	barHitArea.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		scrubbing = true
		local finalPercent

		repeat
			finalPercent = seekToMouseX() or finalPercent
			RunService.RenderStepped:Wait()
		until not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

		scrubbing = false

		if finalPercent and nowPlaying and nowPlaying.durationMs > 0 then
			local seekMs = math.floor(finalPercent * nowPlaying.durationMs)
			lastProgressMs = seekMs
			lastProgressAt = os.clock()
			SpotifyClient.seek(seekMs)
		end
	end)

	currentTimeLabel = library:CreateLabel({
		Position = UDim2.new(0, 6, 0, 242),
		Size = UDim2.new(0.5, -8, 0, 14),
		TextSize = 11,
		Text = "0:00",
		TextColor3 = Color3.fromRGB(170, 170, 170),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 207,
		Parent = inner,
	})

	durationLabel = library:CreateLabel({
		Position = UDim2.new(0.5, 2, 0, 242),
		Size = UDim2.new(0.5, -8, 0, 14),
		TextSize = 11,
		Text = "0:00",
		TextColor3 = Color3.fromRGB(170, 170, 170),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 207,
		Parent = inner,
	})

	local function forcePollSoon(delaySeconds)
		task.delay(delaySeconds or 0.4, function()
			lastPoll = 0
		end)
	end

	makeControlButton(inner, "<", UDim2.new(0.5, -55, 0, 264), function()
		SpotifyClient.previous()
		forcePollSoon(0.5)
	end)

	local _, resolvedPlayPauseLabel = makeControlButton(inner, "||", UDim2.new(0.5, -15, 0, 264), function()
		if nowPlaying then
			nowPlaying.isPlaying = not nowPlaying.isPlaying
			playPauseLabel.Text = nowPlaying.isPlaying and "||" or "▶"

			if nowPlaying.isPlaying then
				SpotifyClient.play()
			else
				SpotifyClient.pause()
			end
		else
			SpotifyClient.play()
		end

		forcePollSoon()
	end)
	playPauseLabel = resolvedPlayPauseLabel

	makeControlButton(inner, ">", UDim2.new(0.5, 25, 0, 264), function()
		SpotifyClient.next()
		forcePollSoon(0.5)
	end)

	RunService.Heartbeat:Connect(function()
		if not outer.Visible then
			return
		end

		if os.clock() - lastPoll >= POLL_INTERVAL then
			lastPoll = os.clock()

			task.spawn(function()
				local result = SpotifyClient.getCurrentlyPlaying()
				nowPlaying = result

				if result then
					if not scrubbing then
						lastProgressMs = result.progressMs
						lastProgressAt = os.clock()
					end

					titleLabel.Text = result.trackName
					artistLabel.Text = result.artistName
					durationLabel.Text = formatTime(result.durationMs)
					playPauseLabel.Text = result.isPlaying and "||" or "▶"

					if not artCache[result.trackId] then
						artLabel.Image = ""
					end
					fetchAlbumArt(result.trackId, result.albumArtUrl)
				else
					titleLabel.Text = "Nothing playing"
					artistLabel.Text = ""
					durationLabel.Text = "0:00"
					currentTimeLabel.Text = "0:00"
					barFill.Size = UDim2.new(0, 0, 1, 0)
					artLabel.Image = ""
				end
			end)
		end

		if not nowPlaying or scrubbing then
			return
		end

		local elapsedMs = nowPlaying.isPlaying and ((os.clock() - lastProgressAt) * 1000) or 0
		local displayedMs = math.clamp(lastProgressMs + elapsedMs, 0, nowPlaying.durationMs)
		local percent = nowPlaying.durationMs > 0 and (displayedMs / nowPlaying.durationMs) or 0

		currentTimeLabel.Text = formatTime(displayedMs)
		barFill.Size = UDim2.new(percent, 0, 1, 0)
	end)
end

function SpotifyWidget.setVisible(visible)
	if outer then
		outer.Visible = visible
	end
end

return SpotifyWidget
