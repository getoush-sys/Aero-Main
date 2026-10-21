-- ProximityList: an on-screen list of nearby players (name + distance), ported from project-rain's
-- proximity_list. Draggable frame, updates ~0.15s, notifies on enter/leave, highlights voidwalkers.
-- Gated on the ProximityList toggle, with ProximityListRange + ProximityListNotify options.
local ProximityList = {}

---@module GUI.Library
local Library = require("GUI/Library")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.CoreGuiManager
local CoreGuiManager = require("Utility/CoreGuiManager")

local players = game:GetService("Players")
local runService = game:GetService("RunService")

local screenGui, outer, listFrame
local labelMap = {} -- UserId -> TextLabel
local notified = {} -- UserId -> true while we've announced this player's presence (NOT tied to the label)
local lastInRange = {} -- UserId -> os.clock() last time actually in range (for departure debounce)
local active = false

-- A player must be out of range for this long before we announce they "left" -- stops the enter/leave
-- notifications from spamming when a still player briefly drops out of range (HRP streaming, health read,
-- or jitter right at the range boundary).
local PROXIMITY_GRACE = 2

local function localPlayer()
	return players.LocalPlayer
end

local function root()
	local char = localPlayer() and localPlayer().Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function guiParent()
	return (gethui and gethui()) or game:GetService("CoreGui")
end

local function mk(class, props, parent)
	local instance = Instance.new(class)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

---Studs -> "123m" / "1.2km".
local function formatDistance(d)
	if d >= 1000 then
		return string.format("%.1fkm", d / 1000)
	end
	return string.format("%im", d)
end

---Voidwalker check (PR's): their Backpack holds the Voideye / Grasp of Eylis talent. NOTE: other players'
---Backpacks usually aren't replicated to us, so this rarely triggers for remote players -- kept for parity.
local function isVoidwalker(plr)
	local bp = plr:FindFirstChildOfClass("Backpack")
	if not bp then
		return false
	end
	return bp:FindFirstChild("Talent:Voideye") ~= nil or bp:FindFirstChild("Talent:Grasp of Eylis") ~= nil
end

local function build()
	if screenGui then
		return
	end
	screenGui = CoreGuiManager.imark(Instance.new("ScreenGui"))
	screenGui.Name = "LumaProximityList"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.DisplayOrder = 9998

	local protectGui = protectgui or (syn and syn.protect_gui) or function() end
	pcall(protectGui, screenGui)
	screenGui.Parent = guiParent()

	outer = mk("Frame", {
		Name = "Outer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.15, 0),
		Size = UDim2.new(0, 190, 0, 22),
		BackgroundColor3 = Library.MainColor,
		BorderColor3 = Library.OutlineColor,
		BorderSizePixel = 1,
		ZIndex = 200,
	}, screenGui)
	Library:AddToRegistry(outer, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" })

	local title = mk("TextLabel", {
		BackgroundColor3 = Library.BackgroundColor,
		BorderColor3 = Library.OutlineColor,
		BorderSizePixel = 1,
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = Library.Font,
		TextSize = 15,
		TextColor3 = Library.AccentColor,
		Text = "Proximity",
		ZIndex = 201,
	}, outer)
	Library:AddToRegistry(title, { BackgroundColor3 = "BackgroundColor", TextColor3 = "AccentColor" })

	listFrame = mk("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 201,
	}, outer)
	mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, listFrame)

	pcall(function()
		Library:MakeDraggable(outer, 22)
	end)
end

---Players within `range` of us (alive), sorted nearest-first.
local function getInRange(range)
	local inRange = {}
	local r = root()
	if not r then
		return inRange
	end
	local lp = localPlayer()
	for _, plr in ipairs(players:GetPlayers()) do
		if plr == lp then
			continue
		end
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local dist = (r.Position - hrp.Position).Magnitude
			if dist <= range then
				table.insert(inRange, { player = plr, distance = dist })
			end
		end
	end
	table.sort(inRange, function(a, b)
		return a.distance < b.distance
	end)
	return inRange
end

local function addLabel(voidwalker)
	local label = mk("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = Library.Font,
		TextSize = 14,
		TextColor3 = voidwalker and Library.AccentColor or (Library.FontColor or Color3.new(1, 1, 1)),
		Text = "",
		ZIndex = 202,
	}, listFrame)
	Library:AddToRegistry(label, { TextColor3 = voidwalker and "AccentColor" or "FontColor" })
	return label
end

local function clearAll()
	for key, label in pairs(labelMap) do
		pcall(function()
			label:Destroy()
		end)
		labelMap[key] = nil
	end
	for key in pairs(notified) do
		notified[key] = nil
	end
	for key in pairs(lastInRange) do
		lastInRange[key] = nil
	end
end

local function sync(inRange, notify)
	local seen = {}
	local order = 0
	local now = os.clock()
	for _, data in ipairs(inRange) do
		local plr = data.player
		local key = plr.UserId
		seen[key] = true
		lastInRange[key] = now
		local name = plr:GetAttribute("CharacterName") or plr.Name
		local vw = isVoidwalker(plr)

		-- Announce entry ONCE per sustained presence -- keyed off `notified`, not the label, so a one-cycle
		-- drop-out (which destroys/recreates the label below) can't re-fire the notification.
		if notify and not notified[key] then
			Logger.notify(
				"%s [%s] entered your proximity range.%s",
				tostring(plr:GetAttribute("CharacterName") or ""),
				plr.Name,
				vw and " (voidwalker)" or ""
			)
		end
		notified[key] = true

		local label = labelMap[key]
		if not label or not label.Parent then
			label = addLabel(vw)
			labelMap[key] = label
		end
		label.Text = name .. " (" .. formatDistance(data.distance) .. ")"
		label.LayoutOrder = order
		order = order + 1
	end

	-- Labels track the instantaneous range (remove when not seen this cycle).
	for key, label in pairs(labelMap) do
		if not seen[key] then
			pcall(function()
				label:Destroy()
			end)
			labelMap[key] = nil
		end
	end

	-- Departures are debounced: only announce "left" once a player has been out of range for the full
	-- grace window. A brief flicker keeps `notified` set, so returning doesn't re-announce an entry.
	for key in pairs(notified) do
		if not seen[key] and (now - (lastInRange[key] or 0)) > PROXIMITY_GRACE then
			if notify then
				local plr = players:GetPlayerByUserId(key)
				Logger.notify(
					"%s left your proximity range.",
					plr and ((plr:GetAttribute("CharacterName") or "") .. " [" .. plr.Name .. "]") or "A player"
				)
			end
			notified[key] = nil
			lastInRange[key] = nil
		end
	end

	-- Manual sizing (AutomaticSize was unreliable here): grow the box to fit the title + one row per player.
	local count = 0
	for _ in pairs(labelMap) do
		count = count + 1
	end
	if listFrame then
		listFrame.Size = UDim2.new(1, 0, 0, count * 18)
	end
	if outer then
		outer.Size = UDim2.new(0, 190, 0, 22 + count * 18)
	end
end

function ProximityList.init()
	if active then
		return
	end
	active = true

	-- Build the window ONCE, up front (same as the automation overlays' buildOverlay), then drive it from a
	-- task.spawn loop -- not a lazy build inside a render connection.
	build()
	if screenGui then
		screenGui.Enabled = false
	end

	task.spawn(function()
		while active do
			task.wait(0.15)
			pcall(function()
				if not active then
					return
				end
				if not Configuration.expectToggleValue("ProximityList") then
					if screenGui and screenGui.Enabled then
						screenGui.Enabled = false
						clearAll()
					end
					return
				end

				if not screenGui then
					build()
				end

				local range = Configuration.expectOptionValue("ProximityListRange") or 1000
				local notify = Configuration.expectToggleValue("ProximityListNotify")
				sync(getInRange(range), notify)

				-- Show the box whenever the feature is on (just the "Proximity" title when nobody's in range).
				screenGui.Enabled = true
			end)
		end
	end)
end

function ProximityList.detach()
	active = false
	clearAll()
	if screenGui then
		pcall(function()
			screenGui:Destroy()
		end)
		screenGui = nil
	end
	outer, listFrame = nil, nil
end

return ProximityList
