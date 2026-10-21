---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Environment
local Environment = require("Utility/Environment")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Features.Combat.Objects.Task
local Task = require("Features/Combat/Objects/Task")

---@module Game.QueuedBlocking
local QueuedBlocking = require("Game/QueuedBlocking")

---@module Game.KeyHandling
local KeyHandling = require("Game/KeyHandling")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Game.Timings.ModuleManager
local ModuleManager = require("Game/Timings/ModuleManager")

---@module Utility.TaskSpawner
local TaskSpawner = require("Utility/TaskSpawner")

---@module Features.Combat.Targeting
local Targeting = require("Features/Combat/Targeting")

---@module Features.Combat.Objects.ValidationOptions
local ValidationOptions = require("Features/Combat/Objects/ValidationOptions")

---@module Features.Combat.EntityHistory
local EntityHistory = require("Features/Combat/EntityHistory")

---@module Features.Combat.Objects.HitboxOptions
local HitboxOptions = require("Features/Combat/Objects/HitboxOptions")

---@module Utility.OriginalStore
local OriginalStore = require("Utility/OriginalStore")

---@module Features.Combat.StateListener
local StateListener = require("Features/Combat/StateListener")

---@module Utility.Finder
local Finder = require("Utility/Finder")

---@module Game.Latency
local Latency = require("Game/Latency")

---@module GUI.Library
local Library = require("GUI/Library")

---@class Defender
---@field tasks Task[]
---@field tmaid Maid Cleaned up every clean cycle.
---@field rhook table<string, function> Hooked functions that we can restore on clean-up.
---@field markers table<string, boolean> Blocking markers for unknown length timings. If the entry exists and is true, then we're blocking.
---@field maid Maid
---@field hmaid Maid Maid for hitbox visualizations.
---@field uids number Unique ID counter for hitbox visualizations.
---@field afeinted boolean Whether if we have auto-feinted this defense cycle.
---@field ifeinted boolean Whether if we have initial auto-feinted this defense cycle.
local Defender = {}
Defender.__index = Defender
Defender.__type = "Defender"

Defender.armed = setmetatable({}, { __mode = "k" })

local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")
local textChatService = game:GetService("TextChatService")
local debrisService = game:GetService("Debris")
local runService = game:GetService("RunService")

local MAX_VISUALIZATION_TIME = 5.0
local MAX_REPEAT_WAIT = 10.0
local PREDICTION_LENIENCY_MULTI = 10.0

local COUNTER_LEAD_DEFAULT = {
	Prediction = 0.200,
	Unbidden = 0.200,
	IllusoryCounter = 0.200,
	Punishment = 0.300,
	Equalizer = 0.500,
}

local COUNTER_LEAD_OPTION = {
	Prediction = "PredictionLeadTime",
	Unbidden = "UnbiddenLeadTime",
	IllusoryCounter = "IllusoryCounterLeadTime",
	Punishment = "PunishmentLeadTime",
	Equalizer = "EqualizerLeadTime",
}

---@param counter string
---@return number
local function counterLead(counter)
	local value = Configuration.expectOptionValue(COUNTER_LEAD_OPTION[counter])
	if type(value) ~= "number" then
		value = COUNTER_LEAD_DEFAULT[counter]
	end
	return math.max(0, value)
end

---@module Game.Objects.DodgeOptions
local DodgeOptions = require("Game/Objects/DodgeOptions")

local AUTO_FEINT_TAGS = {
	M1 = "M1s",
	Mantra = "Mantras",
	Critical = "Criticals",
}

local function autoFeintAgainstAllowed(timing)
	local label = AUTO_FEINT_TAGS[timing.tag]
	if not label then
		return false
	end

	local selected = Configuration.expectOptionValue("AutoFeintAgainstTags") or {}
	return selected[label] == true
end

local function autoFeintOwnAllowed()
	local ownTiming = StateListener.lAnimTiming
	local label = ownTiming and AUTO_FEINT_TAGS[ownTiming.tag]
	if not label then
		return false
	end

	local selected = Configuration.expectOptionValue("AutoFeintOwnTags") or {}
	return selected[label] == true
end

---@param type string
---@param key string
---@param name string?
---@param distance number
---@param parent string? If provided, will be shown in the log.
---@return boolean
function Defender:miss(type, key, name, distance, parent)
	if not Configuration.expectToggleValue("ShowLoggerWindow") then
		return false
	end

	if
		distance < (Configuration.expectOptionValue("MinimumLoggerDistance") or 0)
		or distance > (Configuration.expectOptionValue("MaximumLoggerDistance") or 0)
	then
		return false
	end

	Library:AddMissEntry(type, key, name, distance, parent)

	return true
end

local knownLogDedupe = {}

---@param type string
---@param key string
---@param name string?
---@param distance number
---@param parent string?
---@return boolean
function Defender:known(type, key, name, distance, parent)
	if not Configuration.expectToggleValue("ShowLoggerWindow") then
		return false
	end

	if not Configuration.expectToggleValue("LogKnownTimings") then
		return false
	end

	if
		distance < (Configuration.expectOptionValue("MinimumLoggerDistance") or 0)
		or distance > (Configuration.expectOptionValue("MaximumLoggerDistance") or 0)
	then
		return false
	end

	local now = os.clock()
	local dedupeKey = tostring(type) .. "|" .. tostring(key)
	if knownLogDedupe[dedupeKey] and now - knownLogDedupe[dedupeKey] < 10 then
		return false
	end
	knownLogDedupe[dedupeKey] = now

	Library:AddMissEntry(type, key, name, distance, parent, true)

	return true
end

---@param from Model? | BasePart?
---@return number?
Defender.distance = LPH_NO_VIRTUALIZE(function(_, from)
	if not from then
		return
	end

	local entRootPart = from

	if from:IsA("Model") then
		entRootPart = from:FindFirstChild("HumanoidRootPart")
	end

	if not entRootPart then
		return
	end

	local localCharacter = players.LocalPlayer.Character
	if not localCharacter then
		return
	end

	local localRootPart = localCharacter:FindFirstChild("HumanoidRootPart")
	if not localRootPart then
		return
	end

	return (entRootPart.Position - localRootPart.Position).Magnitude
end)

---@param self Defender
---@return boolean
Defender.behind = LPH_NO_VIRTUALIZE(function(self)
	local entity = self.entity
	if not entity then
		return false
	end

	local entityRoot = entity:FindFirstChild("HumanoidRootPart")
	if not entityRoot then
		return false
	end

	local localCharacter = players.LocalPlayer.Character
	local localRootPart = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
	if not localRootPart then
		return false
	end

	return (entityRoot.Position - localRootPart.Position):Dot(localRootPart.CFrame.LookVector) < 0
end)

---@param self Defender
---@param entity Model
---@return Target?
Defender.target = LPH_NO_VIRTUALIZE(function(self, entity)
	return Targeting.find(entity)
end)

---@param self Defender
---@param timing AnimationTiming
---@return number
Defender.fsecs = LPH_NO_VIRTUALIZE(function(self, timing)
	local player = players:GetPlayerFromCharacter(self.entity)
	local sd = (player and player:GetAttribute("AveragePing") or 50.0) / 2000
	-- self._gateDelay is the anti-breaker auth/quarantine delay (0 on the normal path); adding it
	-- keeps the hitbox extrapolation leading correctly when a cue arrives late under a flood.
	return (timing.pfht or 0.15) + (sd + Latency.rdelay()) + (self._gateDelay or 0)
end)

---@param self Defender
---@param ref Model|Part
---@param timing Timing
---@param info RepeatInfo
Defender.srpue = LPH_NO_VIRTUALIZE(function(self, ref, timing, info)
	local cache = {
		["name"] = timing.name,
		["imdd"] = timing.imdd,
		["imxd"] = timing.imxd,
		["rsd"] = timing:rsd(),
		["rpd"] = timing:rpd(),
	}

	local target = self:target(ref)
	local part = target and target.root or CFrame.new()

	if ref:IsA("Part") then
		part = ref
	end

	local options = HitboxOptions.new(part, timing)
	options.spredict = not timing.duih
	options.ptime = self:fsecs(timing)
	options.entity = ref:IsA("Model") and target or nil
	options.hmid = info.hmid
	options:ucache()

	self:mark(Task.new(string.format("RPUE_%s_%i", timing.name, 0), function()
		return cache["rsd"] - info.irdelay - Latency.sdelay()
	end, timing.punishable, timing.after, self.rpue, self, ref, timing, info, cache, options))

	if Environment.isTester() then
		self:notify(
			timing,
			"Added RPUE '%s' (%.2fs, then every %.2fs) with ping '%.2f' (changing) subtracted.",
			cache["name"],
			cache["rsd"],
			cache["rpd"],
			Latency.rtt()
		)
	else
		self:notify(
			timing,
			"Added RPUE '%s' ([redacted], then every [redacted]) with ping '%.2f' (changing) subtracted.",
			cache["name"],
			Latency.rtt()
		)
	end
end)

---@param self Defender
---@param ref Model|Part
---@param timing Timing
---@param info RepeatInfo
---@param cache table Cache table for RPUE to prevent unnecessary recalculations.
---@param options HitboxOptions
Defender.rpue = LPH_NO_VIRTUALIZE(function(self, ref, timing, info, cache, options)
	local distance = self:distance(ref)
	if not distance then
		return Logger.warn("Stopping RPUE '%s' because the distance is not valid.", cache.name)
	end

	if not self:rc(info) then
		return Logger.warn("Stopping RPUE '%s' because the repeat condition is not valid.", cache.name)
	end

	local target = ref:IsA("Model") and self:target(ref) or true
	local success = false
	local reasons = {}

	options.part = ref:IsA("Part") and ref or (target and target.root)
	options.cframe = not options.part and CFrame.new()

	if timing.duih and target then
		success = self:hc(options, info)
		reasons[#reasons + 1] = string.format("hitbox (%s)", tostring(options:hitbox()))
	end

	local within = (distance >= cache.imdd and distance <= cache.imxd)

	if timing then
		success = within
	end

	if not within then
		reasons[#reasons + 1] = string.format("distance range (%.2f < %.2f > %.2f)", cache.imdd, distance, cache.imxd)
	end

	info.index = info.index + 1

	self:mark(Task.new(string.format("RPUE_%s_%i", timing.name, info.index), function()
		return cache.rpd - info.irdelay - Latency.sdelay()
	end, timing.punishable, timing.after, self.rpue, self, ref, timing, info, cache, options))

	if not target then
		return Logger.warn("Skipping RPUE '%s' because the target is not valid.", cache.name)
	end

	if not success then
		return Logger.warn("Skipping RPUE '%s' (%s)", cache.name, #reasons > 1 and table.concat(reasons, ", ") or "N/A")
	end

	self:notify(timing, "Action type 'RPUE Parry' is being executed.")

	self:parry(timing, nil)
end)

---@param self Defender
---@param options ValidationOptions
---@return boolean
Defender.valid = LPH_NO_VIRTUALIZE(function(self, options)
	local integer = Random.new():NextNumber(1.0, 100.0)
	local rate = Configuration.expectOptionValue("FailureRate") or 0.0
	local timing = options.timing

	local function internalNotifyFunction(...)
		if not options.notify then
			return
		end

		return self:notify(...)
	end

	local overrideData = Library:GetOverrideData(timing.name)

	if overrideData then
		rate = overrideData.fr
	end

	if (Configuration.expectToggleValue("AllowFailure") or overrideData) and integer <= rate then
		return internalNotifyFunction(timing, "(%i <= %i) Intentionally did not run.", integer, rate)
	end

	if self.hits and next(self.hits) then
		return internalNotifyFunction(timing, "Already landed a hit on the attacker; skipping to not contest M1 priority.")
	end

	local selectedFilters = Configuration.expectOptionValue("AutoDefenseFilters") or {}

	if selectedFilters["Disable While Holding Block"] and StateListener.hblock() then
		return internalNotifyFunction(timing, "User is pressing down on a key binded to Block.")
	end

	if selectedFilters["Disable While Using Payback"] and StateListener.pback() then
		return internalNotifyFunction(timing, "User is using the 'Payback' move.")
	end

	local chatInputBarConfiguration = textChatService:FindFirstChildOfClass("ChatInputBarConfiguration")

	if
		selectedFilters["Disable When Textbox Focused"]
		and (userInputService:GetFocusedTextBox() or chatInputBarConfiguration.IsFocused)
	then
		return internalNotifyFunction(timing, "User is typing in a text box.")
	end

	if selectedFilters["Disable While Using Sightless Beam"] and StateListener.csb() then
		return internalNotifyFunction(timing, "User is using the 'Sightless Beam' move.")
	end

	if selectedFilters["Disable When Window Not Active"] and not iswindowactive() then
		return internalNotifyFunction(timing, "Window is not active.")
	end

	if selectedFilters["Disable During Chime Countdown"] and StateListener.ccd() then
		return internalNotifyFunction(timing, "Chime countdown is active.")
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return internalNotifyFunction(timing, "No effect replicator found.")
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return internalNotifyFunction(timing, "No effect replicator module found.")
	end

	if
		selectedFilters["Dont Parry If In Payback"]
		and (
			(effectReplicatorModule:FindEffect("PaybackHealTally") and tick() - StateListener.lastPaybackDelay > 60)
			or effectReplicatorModule:FindEffect("DelayedPayback")
		)
	then
		return internalNotifyFunction(timing, "User is in Payback.")
	end

	local actionType = options.action and options.action._type or "N/A"

	if
		not Configuration.expectToggleValue("BlatantRoll")
		or (actionType ~= "Dodge" and actionType ~= "Forced Full Dodge")
	then
		if not self.afeinted and not options.sstun and StateListener.astun() then
			return internalNotifyFunction(timing, "User is in action stun.")
		end

		if effectReplicatorModule:FindEffect("Knocked") then
			return internalNotifyFunction(timing, "User is knocked.")
		end
	end

	if not timing.iapf and actionType == "Parry" then
		if effectReplicatorModule:FindEffect("AutoParry") then
			return internalNotifyFunction(timing, "User has auto parry frames.")
		end
	end

	if timing.tag == "M1" and selectedFilters["Filter Out M1s"] then
		return internalNotifyFunction(timing, "Attacker is using a 'M1' attack.")
	end

	if timing.tag == "Mantra" and selectedFilters["Filter Out Mantras"] then
		return internalNotifyFunction(timing, "Attacker is using a 'Mantra' attack.")
	end

	if timing.tag == "Critical" and selectedFilters["Filter Out Criticals"] then
		return internalNotifyFunction(timing, "Attacker is using a 'Critical' attack.")
	end

	if timing.tag == "Undefined" and selectedFilters["Filter Out Undefined"] then
		return internalNotifyFunction(timing, "Attacker is using an 'Undefined' attack.")
	end

	if timing.rsc and StateListener.recentlyCast(timing.rsaid, timing.rsaw) then
		return internalNotifyFunction(timing, "User recently played the same animation themselves (%s).", timing.rsaid)
	end

	return true
end)

---@note: Solara fallback.
local function checkParts(parts, filter)
	for _, part in next, parts do
		for _, fpart in next, filter do
			if part ~= fpart and not part:IsDescendantOf(fpart) then
				continue
			end

			return true
		end
	end

	return false
end

---@param spaces number Determines how many spaces that one UID can occupy.
---@return number
function Defender:uid(spaces)
	self.uids = self.uids + spaces

	return self.uids
end

---@param self Defender
---@param identifier number? If the identifier is nil, then we will auto-generate one for each visualization.
---@param cframe CFrame
---@param size Vector3
---@param color Color3
---@param shape Enum.PartType
Defender.visualize = LPH_NO_VIRTUALIZE(function(self, identifier, cframe, size, color, shape)
	local id = identifier or self:uid(10)
	local vpart = self.hmaid[id] or Instance.new("Part")

	pcall(function()
		vpart.Parent = workspace
	end)

	if vpart.Parent then
		vpart.Anchored = true
		vpart.CanCollide = false
		vpart.CanQuery = false
		vpart.CanTouch = false
		vpart.Material = Enum.Material.ForceField
		vpart.CastShadow = false
		vpart.Size = size
		vpart.CFrame = cframe
		vpart.Color = color
		vpart.Shape = shape
		vpart.Transparency = Configuration.expectToggleValue("EnableVisualizations") and 0.2 or 1.0
	end

	if self.hmaid[id] then
		return
	end

	self.hmaid[id] = vpart

	debrisService:AddItem(vpart, MAX_VISUALIZATION_TIME)
end)

---@param self Defender
---@param cframe CFrame
---@param fd boolean
---@param soffset number
---@param size Vector3
---@param filter Instance[]
---@param shape Enum.PartType
---@return boolean?, CFrame?
Defender.hitbox = LPH_NO_VIRTUALIZE(function(self, cframe, fd, soffset, size, filter, shape)
	local shouldManualFilter = getexecutorname
		and (getexecutorname():match("Solara") or getexecutorname():match("Xeno"))

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = shouldManualFilter and {} or filter
	overlapParams.FilterType = shouldManualFilter and Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Include

	local character = players.LocalPlayer.Character
	if not character then
		return nil, nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end

	local usedCFrame = cframe

	if fd then
		usedCFrame = usedCFrame * CFrame.new(0, 0, -(size.Z / 2))
	end

	if soffset and soffset ~= 0 then
		usedCFrame = usedCFrame * CFrame.new(0, 0, soffset)
	end

	local simulationPart = Instance.new("Part")
	simulationPart.Size = size
	simulationPart.Material = Enum.Material.ForceField
	simulationPart.Shape = shape
	simulationPart.CFrame = usedCFrame

	if shape == Enum.PartType.Cylinder then
		simulationPart.CFrame = usedCFrame * CFrame.Angles(0, 0, math.rad(90))
	end

	local parts = workspace:GetPartsInPart(simulationPart, overlapParams)

	return shouldManualFilter and checkParts(parts, filter) or #parts > 0, usedCFrame
end)

---@param self Defender
---@param from Model? | BasePart?
---@param pair TimingContainerPair
---@param name string
---@param key string
---@return Timing?
Defender.initial = LPH_NO_VIRTUALIZE(function(self, from, pair, name, key)
	local timing = pair:index(key)

	local distance = self:distance(from)
	if not distance then
		return nil
	end

	if timing then
		self:known(self.__type, key, timing.name, distance, from and tostring(from.Parent) or nil)

		local md = timing.imdd

		if md <= 0.01 then
			md = 0.0
		end

		if distance < md or distance > timing.imxd then
			return nil
		end
	end

	---@note: Ignore return value.
	if not timing then
		self:miss(self.__type, key, name, distance, from and tostring(from.Parent) or nil)
		return false
	end

	return timing
end)

---@param self Defender
---@param timing Timing
---@param str string
Defender.notify = LPH_NO_VIRTUALIZE(function(self, timing, str, ...)
	if not Configuration.expectToggleValue("EnableNotifications") then
		return
	end

	Logger.qnotify("[%s] (%s) %s", timing.name, self.__type, string.format(str, ...))
end)

---@param self Defender
---@param info RepeatInfo
---@return boolean
Defender.rc = LPH_NO_VIRTUALIZE(function(self, info)
	local limit = (info.timing and info.timing.mrt) or MAX_REPEAT_WAIT

	if os.clock() - info.start >= limit then
		return false
	end

	return true
end)

---@param self Defender
---@param options HitboxOptions
---@param info RepeatInfo
---@return boolean
Defender.duih = LPH_NO_VIRTUALIZE(function(self, options, info)
	local clone = options:clone()
	clone.hmid = info.hmid
	clone:ucache()

	while task.wait() do
		if not self:rc(info) then
			return false
		end

		if not self:hc(clone, nil) then
			continue
		end

		return true
	end
end)

---@param self Defender
---@param options HitboxOptions
---@param info RepeatInfo? Pass this in if you want to use the delay until in hitbox.
---@return boolean
Defender.hc = LPH_NO_VIRTUALIZE(function(self, options, info)
	local action = options.action
	local timing = options.timing

	local function innerVisualize(...)
		if not options.visualize then
			return
		end

		return self:visualize(...)
	end

	local character = players.LocalPlayer.Character
	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	if action and action.ihbc then
		return true
	end

	if info then
		return self:duih(options, info)
	end

	local hitbox = options:hitbox()
	local eposition = options.spredict and options:extrapolate() or nil
	local position = options:pos()
	local pt = timing.htype or Enum.PartType.Block

	local result, usedCFrame = self:hitbox(position, timing.fhb, timing.hso, hitbox, options.filter, pt)

	if usedCFrame then
		innerVisualize(options.hmid, usedCFrame, hitbox, options:ghcolor(result), pt)
		innerVisualize(options.hmid and options.hmid + 1 or nil, root.CFrame, root.Size, options:ghcolor(result), pt)
	end

	if not options.spredict or result then
		return result
	end

	local closest = EntityHistory.pclosest(players.LocalPlayer, tick() - (Latency.rtt() * PREDICTION_LENIENCY_MULTI))
	if not closest then
		return false
	end

	local store = OriginalStore.new()

	store:run(root, "CFrame", closest, function()
		result, usedCFrame = self:hitbox(eposition, timing.fhb, timing.hso, hitbox, options.filter, pt)
	end)

	if usedCFrame then
		innerVisualize(options.hmid and options.hmid + 1 or nil, usedCFrame, hitbox, options:gphcolor(result), pt)
		innerVisualize(options.hmid and options.hmid + 1 or nil, closest, root.Size, options:gphcolor(result), pt)
	end

	return result
end)

---@param self Defender
---@param timing Timing
---@param action Action
---@param started number
Defender.handle = LPH_NO_VIRTUALIZE(function(self, timing, action, started)
	local actionType = action._type

	if actionType == "End Block" then
		QueuedBlocking.stop("Defender_StartBlock")
	end

	if
		Configuration.expectToggleValue("AutoFeint")
		and not timing.duih
		and action:when() > 0
		and self.__type == "Animation"
		and actionType ~= "End Block"
		and autoFeintAgainstAllowed(timing)
	then
		self:afeint(timing, action, started, false)
	end

	if actionType ~= "End Block" then
		if not self:valid(ValidationOptions.new(action, timing)) then
			return
		end
	end

	local redactedMap = {
		["Start Slide"] = "1",
		["End Slide"] = "2",
		["Teleport Up"] = "3",
		["Forced Full Dodge"] = "4",
		["Jump"] = "5",
		["Start Block"] = "6",
		["End Block"] = "7",
		["Parry"] = "8",
		["Dodge"] = "9",
		["Start Crouch"] = "10",
		["End Crouch"] = "11",
	}

	if LRM_UserNote then
		self:notify(timing, "Action type '%s' is being executed.", redactedMap[actionType] or actionType)
	else
		self:notify(timing, "Action type '%s' is being executed.", actionType)
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	if not effectReplicator then
		return
	end

	local effectReplicatorModule = require(effectReplicator)
	if not effectReplicatorModule then
		return
	end

	if actionType == "Start Block" then
		return QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_NORMAL, "Defender_StartBlock", 20.0)
	end

	local options = DodgeOptions.new()
	options.rollCancel = Configuration.expectToggleValue("RollCancel") and actionType ~= "Forced Full Dodge"
	options.rollCancelDelay = Configuration.expectOptionValue("RollCancelDelay") or 0.0
	options.direct = Configuration.expectToggleValue("BlatantRoll")
	options.full = actionType == "Forced Full Dodge"

	local inIFrame = effectReplicatorModule:FindEffect("Immortal")
		or effectReplicatorModule:FindEffect("Dodge")
		or effectReplicatorModule:FindEffect("Ghost")
	
	if (actionType == "Dodge" or actionType == "Forced Full Dodge") and Configuration.expectToggleValue("ParryOnly") then
		actionType = "Parry"
		self:notify(timing, "Action 'Dodge' changed to 'Parry'")
	end

	if actionType == "Dodge" then
		if Configuration.expectToggleValue("UseIFrames") and inIFrame then
			return
		end

		return InputClient.dodge(options)
	end

	if actionType == "Forced Full Dodge" then
		return InputClient.dodge(options)
	end

	---@note: End block is handled elsewhere.
	if actionType == "End Block" then
		return
	end

	if actionType == "Start Crouch" then
		return InputClient.crouch(true)
	end

	if actionType == "End Crouch" then
		return InputClient.crouch(false)
	end

	if actionType == "Start Slide" then
		local serverSlide = KeyHandling.getRemote("ServerSlide")
		if not serverSlide then
			return
		end

		return serverSlide:FireServer(true)
	end

	if actionType == "End Slide" then
		local serverSlideStop = KeyHandling.getRemote("ServerSlideStop")
		if not serverSlideStop then
			return
		end

		return serverSlideStop:FireServer(false)
	end

	if actionType == "Start Crouch" then
		local character = players.LocalPlayer.Character
		if not character then
			return
		end

		local characterHandler = character:FindFirstChild("CharacterHandler")
		if not characterHandler then
			return
		end

		local requests = characterHandler:FindFirstChild("Requests")
		if not requests then
			return
		end

		local serverCrouch = requests:FindFirstChild("ServerCrouch")
		if not serverCrouch then
			return
		end

		return serverCrouch:FireServer(true)
	end

	if actionType == "End Crouch" then
		local character = players.LocalPlayer.Character
		if not character then
			return
		end

		local characterHandler = character:FindFirstChild("CharacterHandler")
		if not characterHandler then
			return
		end

		local requests = characterHandler:FindFirstChild("Requests")
		if not requests then
			return
		end

		local serverCrouch = requests:FindFirstChild("ServerCrouch")
		if not serverCrouch then
			return
		end

		return serverCrouch:FireServer(false)
	end

	if actionType == "Jump" then
		local humanController = InputClient.getHumanController()
		if not humanController then
			return
		end

		if effectReplicatorModule:HasAny("Swimming", "Jumped", "NoJump", "Landed") then
			return
		end

		if not humanController:Jump() then
			return
		end

		return InputClient.ejump()
	end

	if actionType == "Teleport Up" then
		local character = players.LocalPlayer.Character
		if not character then
			return
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return
		end

		if Finder.pnear(humanoidRootPart.Position, 500) then
			return self:notify(timing, "Action 'Teleport Up' blocked because there are players nearby.")
		end

		humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position + Vector3.new(0, 75, 0))
	end

	self:parry(timing, action)
end)

---@param self Defender
---@param timing Timing
---@param action Action
Defender.SimulateInput = LPH_NO_VIRTUALIZE(function(self, timing, action)
	if not Configuration.expectToggleValue("EnableSimulation") then
		return
	end

	if not action or not action._type then
		return
	end

	local actionType = action._type

	local function holdTime()
		local min = Configuration.expectOptionValue("SimulationHoldMinimum") or 0.1
		local max = Configuration.expectOptionValue("SimulationHoldMaximum") or 0.15

		if min > max then
			min, max = max, min
		end

		return Random.new():NextNumber(min, max)
	end

	local function simulateRightClick(hold)
		if type(mouse2press) == "function" and type(mouse2release) == "function" then
			mouse2press()
			task.delay(hold, function()
				mouse2release()
			end)
			return
		end

		keypress(0x02)
		task.delay(hold, function()
			keyrelease(0x02)
		end)
	end

	local selectedFilters = Configuration.expectOptionValue("AutoDefenseFilters") or {}

	if selectedFilters["Disable While Holding Block"] and StateListener.hblock() then
		return
	end

	local chatInputBarConfiguration = textChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if
		selectedFilters["Disable When Textbox Focused"]
		and (userInputService:GetFocusedTextBox() or (chatInputBarConfiguration and chatInputBarConfiguration.IsFocused))
	then
		return
	end

	if selectedFilters["Disable While Using Sightless Beam"] and StateListener.csb() then
		return
	end

	if selectedFilters["Disable When Window Not Active"] and not iswindowactive() then
		return
	end

	if selectedFilters["Disable During Chime Countdown"] and StateListener.ccd() then
		return
	end

	if timing and timing.tag == "M1" and selectedFilters["Filter Out M1s"] then
		return
	end

	if timing and timing.tag == "Mantra" and selectedFilters["Filter Out Mantras"] then
		return
	end

	if timing and timing.tag == "Critical" and selectedFilters["Filter Out Criticals"] then
		return
	end

	if timing and timing.tag == "Undefined" and selectedFilters["Filter Out Undefined"] then
		return
	end

	if actionType == "Parry" then
		keypress(0x46)
		task.delay(holdTime(), function()
			keyrelease(0x46)
		end)

	elseif actionType == "Dodge" or actionType == "Forced Full Dodge" then
		keypress(0x51)

		if Configuration.expectToggleValue("RollCancel") then
			task.delay(0.01, function()
				simulateRightClick(holdTime())
			end)
		end

		task.delay(holdTime(), function()
			keyrelease(0x51)
		end)

	elseif actionType == "Vent" then
		keypress(0x47)
		task.delay(holdTime(), function()
			keyrelease(0x47)
		end)

	elseif actionType == "Feint" then
		simulateRightClick(holdTime())
	end
end)

---@param self Defender
---@param timing Timing
---@param action Action
Defender.parry = LPH_NO_VIRTUALIZE(function(self, timing, action)
	local options = DodgeOptions.new()
	options.rollCancel = Configuration.expectToggleValue("RollCancel")
	options.rollCancelDelay = Configuration.expectOptionValue("RollCancelDelay") or 0.0
	options.direct = Configuration.expectToggleValue("BlatantRoll")

	local rate = (Configuration.expectOptionValue("DashInsteadOfParryRate") or 0.0)
	local overrideData = Library:GetOverrideData(timing.name)
	if overrideData then
		rate = overrideData.dipr
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local effectReplicatorModule = effectReplicator and require(effectReplicator)

	local inIFrame = effectReplicatorModule:FindEffect("Immortal")
		or effectReplicatorModule:FindEffect("DodgeFrame")
		or effectReplicatorModule:FindEffect("ParryFrame")
		or effectReplicatorModule:FindEffect("Ghost")

	local dashReplacement = Random.new():NextNumber(1.0, 100.0) <= rate

	if action and action._type ~= "Parry" then
		dashReplacement = false
	end

	if not Configuration.expectToggleValue("AllowFailure") and not overrideData then
		dashReplacement = false
	end

	if timing.umoa or timing.actions:count() ~= 1 then
		dashReplacement = false
	end
	
	if Configuration.expectToggleValue("ParryOnly") then
		dashReplacement = false
	end

	local function internalNotify(...)
		if timing.rpue and timing.srpn then
			return
		end

		return self:notify(...)
	end

	-- Dodge Behind Back: instead of parrying, roll behind the attacker, roll cancel and m1 (the same
	-- roll-behind sequence as Auto Mixup).
	if
		Configuration.expectToggleValue("DodgeBehindBack")
		and StateListener.cdodge()
		and Random.new():NextNumber(1.0, 100.0) <= (Configuration.expectOptionValue("DodgeBehindBackProbability") or 0.0)
	then
		local attacker = self.entity
		local attackerRoot = attacker and attacker:FindFirstChild("HumanoidRootPart")

		-- Don't roll behind an attacker that's too far away (>10 studs) -- the roll-behind only makes
		-- sense in close range.
		local localCharacter = players.LocalPlayer and players.LocalPlayer.Character
		local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
		local tooFar = not localRoot
			or not attackerRoot
			or (attackerRoot.Position - localRoot.Position).Magnitude > 10

		if attackerRoot and not tooFar then
			local Defense = require("Features/Combat/Defense")
			if Defense and Defense.rollCancelBehindBack then
				self:SimulateInput(timing, { _type = "Dodge" })
				task.spawn(function()
					Defense.rollCancelBehindBack(attackerRoot)
				end)
				return internalNotify(timing, "Dodge Behind Back: rolled behind and punished.")
			end
		end
	end

	if Configuration.expectToggleValue("UseIFrames") and inIFrame then
		return internalNotify(timing, "Action 'Parry' blocked because there are already existing IFrames.")
	end
	
	if self.hits and next(self.hits) then
		return internalNotify(timing, "Action 'Parry' blocked because opponent is in hitstun.")
	end

	if
		Configuration.expectToggleValue("RollIfBehind")
		and StateListener.cdodge()
		and not timing.ndfb
		and self:behind()
	then
		self:SimulateInput(timing, { _type = "Dodge" })
		InputClient.dodge(options)

		return internalNotify(timing, "Action type 'Parry' rolled because attack is behind.")
	end

	if StateListener.cparry() then
		if timing.ndfb or not StateListener.cdodge() or not dashReplacement then
			if self.__type == "Animation" and self.track then
				runService.Heartbeat:Wait()

				if self:stopped(self.track, timing) then
					return internalNotify(timing, "Feint Detected")
				end
			end

			self:SimulateInput(timing, { _type = "Parry" })
			return QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_DEFLECT, "Defender_Deflect", nil)
		end

		internalNotify(timing, "Action type 'Parry' replaced to 'Dodge' type.")

		self:SimulateInput(timing, { _type = "Dodge" })
		return InputClient.dodge(options)
	end

	local canBlock = Configuration.expectToggleValue("DeflectBlockFallback")
		and not timing.nbfb
		and StateListener.cblock()

	local canVent = StateListener.cvent()
		and Configuration.expectToggleValue("VentFallback")
		and not timing.nvfb
		and not timing.rpue
		and self.__type ~= "Part"

	local canDodge = StateListener.cdodge()
		and Configuration.expectToggleValue("RollOnParryCooldown")
		and not timing.ndfb

	if canDodge then
		self:SimulateInput(timing, { _type = "Dodge" })
		InputClient.dodge(options)

		return internalNotify(timing, "Action type 'Parry' fallback to 'Dodge' type.")
	end

	if canVent then
		self:SimulateInput(timing, { _type = "Vent" })
		InputClient.vent()

		return internalNotify(timing, "Action type 'Parry' fallback to 'Vent' type.")
	end

	if canBlock then
		self:SimulateInput(timing, { _type = "Start Block" })
		QueuedBlocking.invoke(QueuedBlocking.BLOCK_TYPE_NORMAL, "Defender_BlockFallback", timing.bfht)

		return internalNotify(timing, "Action type 'Parry' fallback to 'Block' type.")
	end

	return internalNotify(timing, "Action 'Parry' blocked because no fallbacks are available.")
end)

---@param self Defender
---@return boolean
Defender.blocking = LPH_NO_VIRTUALIZE(function(self)
	for _, marker in next, self.markers do
		if not marker then
			continue
		end

		return true
	end

	for _, task in next, self.tasks do
		if not task:blocking() then
			continue
		end

		return true
	end
end)

---@param task Task
function Defender:mark(task)
	---@note: Anti-breaker occurrence stamping. Only set while the armed anti-flow has an active
	---occurrence context (see AnimatorDefender:apProcess); nil on the normal path, so tasks are
	---untouched and the standard parry path stays byte-identical.
	if self._apStampTrack ~= nil then
		if task.sourceTrack == nil then
			task.sourceTrack = self._apStampTrack
		end
		if task.sourceOccurrence == nil then
			task.sourceOccurrence = self._apStampOccurrence
		end
	end

	self.tasks[#self.tasks + 1] = task
	Defender.armed[self] = true
end

function Defender:clhook()
	for key, old in next, self.rhook do
		if not self[key] then
			continue
		end

		self[key] = old
	end

	self.rhook = {}
end

---@param self Defender
Defender.clean = LPH_NO_VIRTUALIZE(function(self)
	for idx, task in next, self.tasks do
		if task.forced then
			continue
		end

		task:cancel()

		self.tasks[idx] = nil

		if task.identifier ~= "End Block" and task.identifier ~= "Start Block" then
			continue
		end

		QueuedBlocking.stop("Defender_StartBlock")
	end

	self:clhook()

	self.tmaid:clean()

	self.markers = {}

	self.hmaid:clean()

	self.afeinted = false

	if next(self.tasks) == nil then
		Defender.armed[self] = nil
	end
end)

---@param self Defender
---@param timing Timing
---@varargs any
Defender.module = LPH_NO_VIRTUALIZE(function(self, timing, ...)
	local lf = ModuleManager.get(timing.smod)
	if not lf then
		return self:notify(timing, "No module '%s' found.", timing.smod)
	end

	local identifier = string.format("Defender_RunModule_%s", timing.smod)

	if not timing.smn then
		self:notify(timing, "Running module '%s' on timing.", timing.smod)
	end

	self.tmaid:mark(TaskSpawner.spawn(identifier, lf, self, timing, ...))
end)

---@param self Defender
---@param timing Timing
---@param action Action
---@param started number Timestamp of when the auto feint task started.
---@param initial boolean Whether this is the initial auto feint check.
Defender.afeint = LPH_NO_VIRTUALIZE(function(self, timing, action, started, initial)
    local function innerNotify(...)
        if initial then return end
        return self:notify(...)
    end

    local lfaction = StateListener.lAnimFaction
    if not lfaction then
        return innerNotify(timing, "Auto feint blocked: No local action.")
    end

    if not autoFeintOwnAllowed() then
        return innerNotify(timing, "Auto feint blocked: Our own attack type isn't selected.")
    end

    local latimestamp = StateListener.lAnimTimestamp
    if latimestamp and (os.clock() - latimestamp) > (lfaction:when() * 0.8) then
        return innerNotify(timing, "Auto feint blocked: Attack is too late to feint")
    end

    if not StateListener.cfeint() then
        return innerNotify(timing, "Auto feint blocked: Unable to feint.")
    end

    local options = ValidationOptions.new(action, timing)
    options.sstun = true
    options.notify = false
    options.visualize = false

    if not self:valid(options) then
        return innerNotify(timing, "Auto feint failed: Action invalid.")
    end

    if not self.ifeinted then
        self:notify(timing, "Legacy auto feint executed.")
    end

    if not initial then
        self.afeinted = true
    else
        self.ifeinted = true
    end

    InputClient.feint()
end)

	Defender.prediction = LPH_NO_VIRTUALIZE(function(self, timing, action)
		if timing.smod == "Throw" then
			return
		end

		if not players:GetPlayerFromCharacter(self.entity) and not Configuration.expectToggleValue("CounterNPCs") then
			return
		end

		task.wait(0.1)

		local options = ValidationOptions.new(action, timing)
		options.skipFailureRate = true
		options.visualize = false
		if not self:valid(options) then
			return
		end

		if self.__type == "Animation" and self.track and self:stopped(self.track, timing) then
			return
		end

		local localPlayer = players.LocalPlayer
		local character = localPlayer and localPlayer.Character
		local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
		local predictionMantra = backpack and backpack:FindFirstChild("Mantra:PredictionIntelligence{{Prediction}}")

		if not character then
			return
		end

		local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
		local effectReplicatorModule = effectReplicator and require(effectReplicator)

		if not effectReplicatorModule then
			return
		end

		local inIFrame = effectReplicatorModule:FindEffect("Immortal")
			or effectReplicatorModule:FindEffect("DodgeFrame")
			or effectReplicatorModule:FindEffect("ParryFrame")
			or effectReplicatorModule:FindEffect("Ghost")

		local isPlayer = self.entity and players:GetPlayerFromCharacter(self.entity)
		if Configuration.expectToggleValue("UseIFrames") and inIFrame and isPlayer then
			return
		end

		if self.entity and self.__type == "Animation" then
			local root = self.entity:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end

			local hoptions = HitboxOptions.new(root, timing)
			hoptions.spredict = not timing.duih and not timing.dp
			hoptions.ptime = self:fsecs(timing)
			hoptions.action = action
			hoptions.entity = self.entity
			hoptions.visualize = false
			hoptions:ucache()

			if not self:hc(hoptions, nil) and not self:fpc(timing, hoptions) then
				return
			end
		end

		if not predictionMantra then
			return
		end

		local onCooldown = false
		for _, effect in next, effectReplicatorModule.Effects do
			if effect.Class == "ToolLockCD" and effect.index and effect.index.Value and tostring(effect.index.Value):find("PredictionIntelligence") then
				onCooldown = true
				break
			end
		end

		if onCooldown then
			return
		end

		local activateMantra = character:FindFirstChild("CharacterHandler")
			and character.CharacterHandler:FindFirstChild("Requests")
			and character.CharacterHandler.Requests:FindFirstChild("ActivateMantra")

		if not activateMantra then
			return
		end

		activateMantra:FireServer(predictionMantra)
		self:notify(timing, "Action 'Parry' replaced with 'Prediction' mantra.")
	end)

---@param self Defender
---@param timing Timing
---@param action Action
Defender.punishment = LPH_NO_VIRTUALIZE(function(self, timing, action)
	if timing.smod == "Throw" then
		return
	end

	if not players:GetPlayerFromCharacter(self.entity) and not Configuration.expectToggleValue("CounterNPCs") then
		return
	end

	task.wait(0.1)

	local options = ValidationOptions.new(action, timing)
	options.skipFailureRate = true
	options.visualize = false
	if not self:valid(options) then
		return
	end

	if self.__type == "Animation" and self.track and self:stopped(self.track, timing) then
		return
	end

	local localPlayer = players.LocalPlayer
	local character = localPlayer and localPlayer.Character
	local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
	local punishmentMantra = backpack and backpack:FindFirstChild("Mantra:RevengeWeaponHeavy{{Punishment}}")

	if not character then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local effectReplicatorModule = effectReplicator and require(effectReplicator)

	if not effectReplicatorModule then
		return
	end

	if Configuration.expectToggleValue("UsePrediction") then
		local predictionMantra = backpack and backpack:FindFirstChild("Mantra:PredictionIntelligence{{Prediction}}")
		if predictionMantra then
			local predictionOnCooldown = false
			for _, effect in next, effectReplicatorModule.Effects do
				if effect.Class == "ToolLockCD" and effect.index and effect.index.Value and tostring(effect.index.Value):find("PredictionIntelligence") then
					predictionOnCooldown = true
					break
				end
			end

			if not predictionOnCooldown then
				return
			end
		end
	end

	if effectReplicatorModule:FindEffect("AbsorbCharge") then
		return
	end

	local inIFrame = effectReplicatorModule:FindEffect("Immortal")
		or effectReplicatorModule:FindEffect("DodgeFrame")
		or effectReplicatorModule:FindEffect("ParryFrame")
		or effectReplicatorModule:FindEffect("Ghost")

	local isPlayer = self.entity and players:GetPlayerFromCharacter(self.entity)
	if Configuration.expectToggleValue("UseIFrames") and inIFrame and isPlayer then
		return
	end

	if self.entity and self.__type == "Animation" then
		local root = self.entity:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		local hoptions = HitboxOptions.new(root, timing)
		hoptions.spredict = not timing.duih and not timing.dp
		hoptions.ptime = self:fsecs(timing)
		hoptions.action = action
		hoptions.entity = self.entity
		hoptions.visualize = false
		hoptions:ucache()

		if not self:hc(hoptions, nil) and not self:fpc(timing, hoptions) then
			return
		end
	end

	if not punishmentMantra then
		return
	end

	local onCooldown = false
	for _, effect in next, effectReplicatorModule.Effects do
		if effect.Class == "ToolLockCD" and effect.index and effect.index.Value and tostring(effect.index.Value):find("RevengeWeaponHeavy") then
			onCooldown = true
			break
		end
	end

	if onCooldown then
		return
	end

	local activateMantra = character:FindFirstChild("CharacterHandler")
		and character.CharacterHandler:FindFirstChild("Requests")
		and character.CharacterHandler.Requests:FindFirstChild("ActivateMantra")

	if not activateMantra then
		return
	end

	activateMantra:FireServer(punishmentMantra)
	self:notify(timing, "Action 'Parry' replaced with 'Punishment' mantra.")
end)

---@param self Defender
---@param timing Timing
---@param action Action
Defender.Equalizer = LPH_NO_VIRTUALIZE(function(self, timing, action)
	if timing.smod == "Throw" then
		return
	end

	if not players:GetPlayerFromCharacter(self.entity) and not Configuration.expectToggleValue("CounterNPCs") then
		return
	end

	local options = ValidationOptions.new(action, timing)
	options.skipFailureRate = true
	options.visualize = false
	if not self:valid(options) then
		return
	end

	if self.__type == "Animation" and self.track and self:stopped(self.track, timing) then
		return
	end

	local localPlayer = players.LocalPlayer
	local character = localPlayer and localPlayer.Character
	local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
	local equalizerMantra = backpack and backpack:FindFirstChild("Mantra:AntiairContractor{{Equalizer}}")

	if not character then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local effectReplicatorModule = effectReplicator and require(effectReplicator)

	if not effectReplicatorModule then
		return
	end

	if Configuration.expectToggleValue("UsePrediction") then
		local predictionMantra = backpack and backpack:FindFirstChild("Mantra:PredictionIntelligence{{Prediction}}")
		if predictionMantra then
			local predictionOnCooldown = false
			for _, effect in next, effectReplicatorModule.Effects do
				if effect.Class == "ToolLockCD" and effect.index and effect.index.Value and tostring(effect.index.Value):find("PredictionIntelligence") then
					predictionOnCooldown = true
					break
				end
			end

			if not predictionOnCooldown then
				return
			end
		end
	end

	if effectReplicatorModule:FindEffect("AbsorbCharge") then
		return
	end

	local inIFrame = effectReplicatorModule:FindEffect("Immortal")
		or effectReplicatorModule:FindEffect("DodgeFrame")
		or effectReplicatorModule:FindEffect("ParryFrame")
		or effectReplicatorModule:FindEffect("Ghost")

	local isPlayer = self.entity and players:GetPlayerFromCharacter(self.entity)
	if Configuration.expectToggleValue("UseIFrames") and inIFrame and isPlayer then
		return
	end

	if self.entity and self.__type == "Animation" then
		local root = self.entity:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		local hoptions = HitboxOptions.new(root, timing)
		hoptions.spredict = not timing.duih and not timing.dp
		hoptions.ptime = self:fsecs(timing)
		hoptions.action = action
		hoptions.entity = self.entity
		hoptions.visualize = false
		hoptions:ucache()

		if not self:hc(hoptions, nil) and not self:fpc(timing, hoptions) then
			return
		end
	end

	if not equalizerMantra then
		return
	end

	local onCooldown = false
	for _, effect in next, effectReplicatorModule.Effects do
		if effect.Class == "ToolLockCD" and effect.index and effect.index.Value and tostring(effect.index.Value):find("AntiairContractor") then
			onCooldown = true
			break
		end
	end

	if onCooldown then
		return
	end

	local activateMantra = character:FindFirstChild("CharacterHandler")
		and character.CharacterHandler:FindFirstChild("Requests")
		and character.CharacterHandler.Requests:FindFirstChild("ActivateMantra")

	if not activateMantra then
		return
	end

	activateMantra:FireServer(equalizerMantra)
	self:notify(timing, "Action 'Parry' replaced with 'Equalizer' mantra.")
end)

---@param self Defender
---@param timing Timing
---@param action Action
Defender.unbidden = LPH_NO_VIRTUALIZE(function(self, timing, action)
    if timing.smod == "Throw" then
        return
    end

    if not players:GetPlayerFromCharacter(self.entity) and not Configuration.expectToggleValue("CounterNPCs") then
        return
    end

    task.wait(0.1)

    local options = ValidationOptions.new(action, timing)
    options.skipFailureRate = true
    options.visualize = false
    if not self:valid(options) then
        return
    end

    if self.__type == "Animation" and self.track and self:stopped(self.track, timing) then
        return
    end

    local localPlayer = players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    if not character then
        return
    end

    local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
    local effectReplicatorModule = effectReplicator and require(effectReplicator)

    if effectReplicatorModule then
        local inIFrame = effectReplicatorModule:FindEffect("Immortal")
            or effectReplicatorModule:FindEffect("DodgeFrame")
            or effectReplicatorModule:FindEffect("ParryFrame")
            or effectReplicatorModule:FindEffect("Ghost")

        if Configuration.expectToggleValue("UseIFrames") and inIFrame then
            return
        end

        for _, effect in next, effectReplicatorModule.Effects do
            if effect.Class == "ToolLockCD" then
                return
            end
        end
    end

    if self.entity and self.__type == "Animation" then
        local root = self.entity:FindFirstChild("HumanoidRootPart")
        if root then
            local hoptions = HitboxOptions.new(root, timing)
            hoptions.spredict = not timing.duih and not timing.dp
            hoptions.ptime = self:fsecs(timing)
            hoptions.action = action
            hoptions.entity = self.entity
            hoptions.visualize = false
            hoptions:ucache()

            if not self:hc(hoptions, nil) and not self:fpc(timing, hoptions) then
                return
            end
        end
    end

    local criticalRemote = KeyHandling.getRemote("CriticalClick")

    if criticalRemote then
        criticalRemote:FireServer()
        self:notify(timing, "Action 'Parry' replaced with 'Unbidden'.")
    end
end)

---@param self Defender
---@param timing Timing
---@param action Action
Defender.illusorycounter = LPH_NO_VIRTUALIZE(function(self, timing, action)
	if timing.smod == "Throw" then
		return
	end

	if action:when() <= counterLead("IllusoryCounter") then
		return
	end

	if not players:GetPlayerFromCharacter(self.entity) and not Configuration.expectToggleValue("CounterNPCs") then
		return
	end

	task.wait(0.1)

	local options = ValidationOptions.new(action, timing)
	options.skipFailureRate = true
	options.visualize = false
	if not self:valid(options) then
		return
	end

	if self.__type == "Animation" and self.track and self:stopped(self.track, timing) then
		return
	end

	local localPlayer = players.LocalPlayer
	local character = localPlayer and localPlayer.Character
	local backpack = localPlayer and localPlayer:FindFirstChild("Backpack")
	local illusoryCounterMantra = backpack and backpack:FindFirstChild("Mantra:CounterIllusion{{Illusory Counter}}")

	if not character then
		return
	end

	local effectReplicator = replicatedStorage:FindFirstChild("EffectReplicator")
	local effectReplicatorModule = effectReplicator and require(effectReplicator)

	if not effectReplicatorModule then
		return
	end

	if Configuration.expectToggleValue("UsePrediction") then
		local predictionMantra = backpack and backpack:FindFirstChild("Mantra:PredictionIntelligence{{Prediction}}")
		if predictionMantra then
			local predictionOnCooldown = false
			for _, effect in next, effectReplicatorModule.Effects do
				if effect.Class == "ToolLockCD" and effect.index and effect.index.Value and tostring(effect.index.Value):find("PredictionIntelligence") then
					predictionOnCooldown = true
					break
				end
			end

			if not predictionOnCooldown then
				return
			end
		end
	end

	local inIFrame = effectReplicatorModule:FindEffect("Immortal")
		or effectReplicatorModule:FindEffect("DodgeFrame")
		or effectReplicatorModule:FindEffect("ParryFrame")
		or effectReplicatorModule:FindEffect("Ghost")

	local isPlayer = self.entity and players:GetPlayerFromCharacter(self.entity)
	if Configuration.expectToggleValue("UseIFrames") and inIFrame and isPlayer then
		return
	end

	if self.entity and self.__type == "Animation" then
		local root = self.entity:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		local hoptions = HitboxOptions.new(root, timing)
		hoptions.spredict = not timing.duih and not timing.dp
		hoptions.ptime = self:fsecs(timing)
		hoptions.action = action
		hoptions.entity = self.entity
		hoptions.visualize = false
		hoptions:ucache()

		if not self:hc(hoptions, nil) and not self:fpc(timing, hoptions) then
			return
		end
	end

	if not illusoryCounterMantra then
		return
	end

	local onCooldown = false
	for _, effect in next, effectReplicatorModule.Effects do
		if effect.Class == "ToolLockCD" and effect.index and effect.index.Value and tostring(effect.index.Value):find("CounterIllusion") then
			onCooldown = true
			break
		end
	end

	if onCooldown then
		return
	end

	local activateMantra = character:FindFirstChild("CharacterHandler")
		and character.CharacterHandler:FindFirstChild("Requests")
		and character.CharacterHandler.Requests:FindFirstChild("ActivateMantra")

	if not activateMantra then
		return
	end

	activateMantra:FireServer(illusoryCounterMantra)
	self:notify(timing, "Action 'Parry' replaced with 'Illusory Counter' mantra.")
end)

---@param self Defender
---@param timing Timing
---@param action Action
Defender.action = LPH_NO_VIRTUALIZE(function(self, timing, action)
	if timing.umoa and self.__type == "Animation" then
		timing.et = action["_when"]
	end

	local actionType = action._type
    local isParryOrDodge = (actionType == "Parry" or actionType == "Dodge")

	local rdelay = self.offset or Latency.rdelay()

	if not LPH_OBFUSCATED and actionType == "Parry" and self.__type == "Animation" then
		local rtt = rdelay + Latency.sdelay()

		Logger.warn(
			"(%s) [FeintDiag] Scheduling '%s' at clock=%.3f: when=%.3fs rtt=%.3fs -> fireDelay=%.3fs",
			timing.name,
			action.name,
			os.clock(),
			action:when(),
			rtt,
			action:when() - rtt
		)
	end

	local atask = Task.new(action._type, function()
		return action:when() - rdelay - Latency.sdelay()
	end, timing.punishable, timing.after, self.handle, self, timing, action, os.clock())

	if timing.forced then
		atask.forced = true
	end

	self:mark(atask)

	local actionWhen = action:when()

	if Configuration.expectToggleValue("UsePrediction") and isParryOrDodge and actionWhen > counterLead("Prediction") then
		self:mark(Task.new("Prediction", function()
			return action:when() - rdelay - Latency.sdelay() - counterLead("Prediction")
		end, timing.punishable, timing.after, self.prediction, self, timing, action, os.clock()))
	end

	if Configuration.expectToggleValue("UseEqualizer") and isParryOrDodge and actionWhen > counterLead("Equalizer") then
		self:mark(Task.new("Equalizer", function()
			return action:when() - rdelay - Latency.sdelay() - counterLead("Equalizer")
		end, timing.punishable, timing.after, self.Equalizer, self, timing, action, os.clock()))
	end

	if Configuration.expectToggleValue("UsePunishment") and isParryOrDodge and actionWhen > counterLead("Punishment") then
		self:mark(Task.new("Punishment", function()
			return action:when() - rdelay - Latency.sdelay() - counterLead("Punishment")
		end, timing.punishable, timing.after, self.punishment, self, timing, action, os.clock()))
	end

	if Configuration.expectToggleValue("UseUnbidden") and isParryOrDodge and actionWhen > counterLead("Unbidden") then
        self:mark(Task.new("Unbidden", function()
            return action:when() - rdelay - Latency.sdelay() - counterLead("Unbidden")
        end, timing.punishable, timing.after, self.unbidden, self, timing, action, os.clock()))
    end

	if Configuration.expectToggleValue("UseIllusoryCounter") and isParryOrDodge and actionWhen > counterLead("IllusoryCounter") then
		self:mark(Task.new("IllusoryCounter", function()
			return action:when() - rdelay - Latency.sdelay() - counterLead("IllusoryCounter")
		end, timing.punishable, timing.after, self.illusorycounter, self, timing, action, os.clock()))
	end

	if
		Configuration.expectToggleValue("AutoFeint")
		and not timing.duih
		and action:when() > 0
		and self.__type == "Animation"
		and action._type ~= "End Block"
		and autoFeintAgainstAllowed(timing)
	then
		self:mark(Task.new(action._type, function()
			return (action:when() - rdelay - Latency.sdelay()) / 2
		end, timing.punishable, timing.after, self.afeint, self, timing, action, os.clock(), true))
	end
	
	if Environment.isTester() then
		self:notify(
			timing,
			"Added action '%s' (%.2fs) with ping '%.2f' (changing) subtracted.",
			action.name,
			action:when(),
			Latency.rtt()
		)
	else
		self:notify(
			timing,
			"Added action '%s' ([redacted]) with ping '%.2f' (changing) subtracted.",
			action.name,
			Latency.rtt()
		)
	end
end)

---@param self Defender
---@param timing Timing
Defender.actions = LPH_NO_VIRTUALIZE(function(self, timing)
	for _, action in next, timing.actions:get() do
		self:action(timing, action)
	end
end)

---@param key string
---@param new function
---@return boolean, function
function Defender:hook(key, new)
	if self.rhook[key] then
		Logger.warn("Cannot hook '%s' because it is already hooked.", key)
		return false, nil
	end

	local old = self[key]

	if typeof(old) ~= "function" then
		Logger.warn("Cannot hook '%s' because it is not a function.", key)
		return false, nil
	end

	self[key] = new

	self.rhook[key] = old

	Logger.warn("Hooked '%s' with new function.", key)

	return true, old
end

function Defender:detach()
	self:clean()
	self.maid:clean()

	self.hmaid:clean()

	Defender.armed[self] = nil

	self = nil
end

---@return Defender
function Defender.new()
	local self = setmetatable({}, Defender)
	self.tasks = {}
	self.rhook = {}
	self.tmaid = Maid.new()
	self.maid = Maid.new()
	self.hmaid = Maid.new()
	self.uids = 0
	self.markers = {}
	self.lvisualization = os.clock()
	self.afeinted = false
	self.ifeinted = false
	return self
end

return Defender
