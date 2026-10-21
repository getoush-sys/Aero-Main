local TimingBuilderTab = {}

---@module GUI.Icons
local Icons = require("GUI/Icons")

---@module GUI.Library
local Library = require("GUI/Library")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Environment
local Environment = require("Utility/Environment")

---@module Game.Timings.SaveManager
local SaveManager = require("Game/Timings/SaveManager")

---@module Game.Timings.ModuleManager
local ModuleManager = require("Game/Timings/ModuleManager")

---@module Game.Timings.AnimationTiming
local AnimationTiming = require("Game/Timings/AnimationTiming")

---@module Game.Timings.EffectTiming
local EffectTiming = require("Game/Timings/EffectTiming")

---@module Game.Timings.PartTiming
local PartTiming = require("Game/Timings/PartTiming")

---@module Game.Timings.SoundTiming
local SoundTiming = require("Game/Timings/SoundTiming")

---@module Game.Timings.Action
local Action = require("Game/Timings/Action")

---@module Features.Game.AnimationVisualizer
local AnimationVisualizer = require("Features/Game/AnimationVisualizer")

---@module Utility.JSON
local JSON = require("Utility/JSON")

local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64Encode(input)
	local out = {}
	local length = #input
	for i = 1, length, 3 do
		local b1, b2, b3 = string.byte(input, i, i + 2)
		b2 = b2 or 0
		b3 = b3 or 0
		local n = b1 * 65536 + b2 * 256 + b3
		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64
		out[#out + 1] = string.sub(BASE64_CHARS, c1 + 1, c1 + 1)
			.. string.sub(BASE64_CHARS, c2 + 1, c2 + 1)
			.. (i + 1 <= length and string.sub(BASE64_CHARS, c3 + 1, c3 + 1) or "=")
			.. (i + 2 <= length and string.sub(BASE64_CHARS, c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

local function countKeys(t)
	local n = 0
	for _ in next, t or {} do
		n = n + 1
	end
	return n
end

local function makePermissiveEnv()
	local base = getfenv(1)

	local dummy
	local dummyMeta = {
		__index = function()
			return dummy
		end,
		__newindex = function() end,
		__call = function()
			return dummy
		end,
		__concat = function()
			return dummy
		end,
	}
	for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm" }) do
		dummyMeta[op] = function()
			return dummy
		end
	end
	dummy = setmetatable({}, dummyMeta)

	return setmetatable({}, {
		__index = function(_, key)
			local real = base[key]
			if real ~= nil then
				return real
			end
			return dummy
		end,
		__newindex = function() end,
	})
end

---@param source string
---@return boolean ok, string? err
local function validateModuleSource(source)
	local chunk, compileErr = loadstring(source)
	if not chunk then
		local clean = tostring(compileErr):gsub('^%[string "[^"]*"%]:', "line ")
		return false, "Syntax error: " .. clean
	end

	pcall(function()
		setfenv(chunk, makePermissiveEnv())
	end)

	local ok, result = pcall(chunk)
	if not ok then
		local clean = tostring(result):gsub('^%[string "[^"]*"%]:', "line ")
		return false, "Error while loading: " .. clean
	end

	if type(result) ~= "function" then
		return false, "Module must `return function(self, timing) ... end` (got " .. type(result) .. ")."
	end

	return true
end

local TYPE_ORDER = { "Animation", "Part", "Sound", "Effect" }
local TYPES = {
	Animation = { new = function() return AnimationTiming.new() end, pair = function() return SaveManager.as end, idProp = "_id" },
	Part = { new = function() return PartTiming.new() end, pair = function() return SaveManager.ps end, idProp = "pname" },
	Sound = { new = function() return SoundTiming.new() end, pair = function() return SaveManager.ss end, idProp = "_id" },
	Effect = { new = function() return EffectTiming.new() end, pair = function() return SaveManager.es end, idProp = "ename" },
}

local ACTION_TYPES = {
	"Parry",
	"Dodge",
	"Forced Full Dodge",
	"Jump",
	"Start Block",
	"End Block",
	"Teleport Up",
	"Start Slide",
	"End Slide",
	"Start Crouch",
	"End Crouch",
}

local TAGS = { "Undefined", "Critical", "Mantra", "M1" }

local TEMPLATES = {
{ "Blank", [==[-- Timing type: Any (Animation / Part / Sound / Effect)
return function(self, timing)

end
]==] },
{ "Basic Parry", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- one simple parry.
return function(self, timing)
	local action = Action.new()
	action.name = "Custom Parry"
	action._type = "Parry"
	action._when = 500 -- milliseconds into the move to react
	action.hitbox = Vector3.new(40, 15, 40)

	return self:action(timing, action)
end
]==] },
{ "Prediction", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- basic parry with prediction
return function(self, timing)
	timing.pfh = true -- predict facing hitbox
	timing.phd = true -- past hitbox detection
	timing.pfht = 0.3 -- extrapolation seconds
	timing.phds = 1.0 -- history seconds

	local action = Action.new()
	action.name = "Custom Parry"
	action._type = "Parry"
	action._when = 650
	action.hitbox = Vector3.new(10, 10, 20)

	return self:action(timing, action)
end
]==] },
{ "Following Hitbox", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- the hitbox follows the attacker
return function(self, timing)
	timing.duih = true -- delay until in hitbox (re-checks the attacker's live position each frame)
	timing.fhb = true  -- forward hitbox

	local action = Action.new()
	action._type = "Parry"
	action._when = 0
	action.hitbox = Vector3.new(25, 20, 25)
	action.name = "Following Hitbox Timing"

	return self:action(timing, action)
end
]==] },
{ "Dynamic Distance Parry", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- parry more delayed the further the enemy is
return function(self, timing)
	local distance = self:distance(self.entity)

	local action = Action.new()
	action._type = "Parry"
	action._when = math.min(325 + distance * 17, 1500) -- base + per-stud, capped
	action.hitbox = Vector3.new(20, 12, 15)
	action.name = string.format("(%.2f) Dynamic Timing", distance)

	return self:action(timing, action)
end
]==] },
{ "Mantra Ingredients", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action
local Mantra = getfenv().Mantra

-- uses mantra ingredients
return function(self, timing)
	local distance = self:distance(self.entity)
	local data = Mantra.data(self.entity, "Mantra:YourMantraId{{Display Name}}")
	local range = data.perfect * 2 + data.crystal * 1

	local action = Action.new()
	action._type = "Parry"
	action._when = math.min(500 + distance * 5, 1000)
	action.hitbox = Vector3.new(15 + range, 15 + range, 85)
	action.name = "Dynamic Mantra Timing"

	timing.hitbox = action.hitbox

	return self:action(timing, action)
end
]==] },
{ "Shared Weapon Animation", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action
local Weapon = getfenv().Weapon

-- if different attacks use the same animation like relic axe and greataxe, you can check for which one
return function(self, timing)
	local handWeapon = Weapon.handWeapon(self.entity)

	if handWeapon and handWeapon:GetAttribute("WeaponName") == "Relic Axe" then
		local action = Action.new()
		action._type = "Parry"
		action._when = 750
		action.hitbox = Vector3.new(15, 30, 40)
		action.name = "Relic Axe Timing"
		return self:action(timing, action)
	end

	local action = Action.new()
	action._type = "Parry"
	action._when = 700
	action.hitbox = Vector3.new(15, 15, 20)
	action.name = "Greataxe Timing"
	return self:action(timing, action)
end
]==] },
{ "Dodge", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- dodges instead of parrying for unparryable attacks
return function(self, timing)
	local action = Action.new()
	action._type = "Dodge"
	action._when = 0
	action.hitbox = Vector3.new(30, 30, 30)
	action.name = "Dodge Timing"

	return self:action(timing, action)
end
]==] },
{ "Forced Full Dodge", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- forced dodge that ignores hitbox
return function(self, timing)
	local action = Action.new()
	action._type = "Forced Full Dodge"
	action._when = 300
	action.ihbc = true
	action.name = "Forced Dodge Timing"

	return self:action(timing, action)
end
]==] },
{ "Close/Far Branch", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- different timings depending on range
return function(self, timing)
	timing.ffh = true    -- force facing hitbox (always make the hitbox face towards you)
	timing.duih = false

	local distance = self:distance(self.entity)

	if distance <= 12 then
		local action = Action.new()
		action._type = "Parry"
		action._when = 450
		action.ihbc = true
		action.name = string.format("(%.2f) Close Timing", distance)
		return self:action(timing, action)
	end

	local action = Action.new()
	action._type = "Parry"
	action._when = 800
	action.ihbc = true
	action.name = string.format("(%.2f) Far Timing", distance)
	return self:action(timing, action)
end
]==] },
{ "Multi-Hit", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- multiple parries
return function(self, timing)
	local hits = { 400, 1000, 1400 }

	for _, when in ipairs(hits) do
		local action = Action.new()
		action._type = "Parry"
		action._when = when
		action.hitbox = Vector3.new(25, 25, 30)
		action.name = string.format("Multi-Hit @ %dms", when)
		self:action(timing, action)
	end
end
]==] },
{ "Speed Scaled", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- scales the hit frame by the animation's playback speed
return function(self, timing)
	local speed = self.track.Speed

	local action = Action.new()
	action._type = "Parry"
	action._when = (750 * 1.21) / speed
	action.hitbox = Vector3.new(80, 250, 140)
	action.name = string.format("(%.2fx) Speed Scaled Timing", speed)

	return self:action(timing, action)
end
]==] },
{ "Teleport Up", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- teleports your character up to avoid some attacks (ngl just use jump).
return function(self, timing)
	timing.aatk = true

	local action = Action.new()
	action._type = "Teleport Up"
	action._when = 150
	action.hitbox = Vector3.new(50, 50, 50)
	action.name = "TP up test"

	return self:action(timing, action)
end
]==] },
{ "Block Window", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- holds block for a duration (beams)
return function(self, timing)
	local distance = self:distance(self.entity)

	local start = Action.new()
	start._type = "Start Block"
	start._when = distance > 18 and 650 or 500
	start.hitbox = Vector3.new(30, 20, 50)
	start.name = "Block Start"
	self:action(timing, start)

	local stop = Action.new()
	stop._type = "End Block"
	stop._when = 1400
	stop.ihbc = true --ignore hitbox check (so we end the block even if we arent in the hitbox anymore)
	stop.name = "Block End"
	return self:action(timing, stop)
end
]==] },
{ "Repeat Parry", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action
local Timing = getfenv().Timing
local Waiter = getfenv().Waiter
local RepeatInfo = getfenv().RepeatInfo
local Latency = getfenv().Latency

-- repeat parries
return function(self, timing)
	local humanoid = self.entity:FindFirstChild("Humanoid")
	local animator = humanoid and humanoid:FindFirstChild("Animator")
	if not animator then
		return
	end

	timing.fhb = true -- foward hitbox
	timing._rsd = 0 -- repeat start delay (ms)
	timing._rpd = 200 -- repeat parry delay (ms)
	timing.duih = true -- delay until in hitbox
	timing.rpue = true -- repeat parry until end
	timing.hitbox = Vector3.new(18, 18, 16)

	local track = Waiter.fet("rbxassetid://0000000000", animator) --replace with animation id
	if not track then
		return
	end

	local info = RepeatInfo.new(timing, Latency.rdelay(), self:uid(10))
	info.track = track
	self:srpue(self.entity, timing, info)
end
]==] },
{ "Projectile", [==[-- Timing type: Animation (spawns a Part sub-timing)
---@type PartTiming
local PartTiming = getfenv().PartTiming
local Action = getfenv().Action
local ProjectileTracker = getfenv().ProjectileTracker
local Defense = getfenv().Defense
local Latency = getfenv().Latency

-- tracks a projectile
return function(self, timing)
	local tracker = ProjectileTracker.new(function(candidate)
		return candidate.Name == "YourProjectileName_" .. self.entity.Name
	end)

	task.wait(0.05 - Latency.rtt())

	--if we are close enough to the enemy, there is no need to track the projectile, we can just parry directly
	if self:distance(self.entity) <= 25 then
		local action = Action.new()
		action._type = "Parry"
		action._when = 0
		action.ihbc = true
		action.name = "Projectile Close Timing"
		return self:action(timing, action)
	end

	--otherwise, track the projectile
	local action = Action.new()
	action._type = "Parry"
	action._when = 0
	action.name = "Projectile Part"

	--make a part timing
	local pt = PartTiming.new()
	pt.uhc = true -- use hitbox cframe
	pt.duih = true -- delay until in hitbox
	pt.name = "Projectile"
	pt.hitbox = Vector3.new(50, 50, 100)
	pt.actions:push(action)
	pt.cbm = true -- created by module flag

	Defense.cdpo(tracker:wait(), pt)
end
]==] },
{ "Effect Timing", [==[-- Timing type: Effect
---@type Action
local Action = getfenv().Action

return function(self, timing)
	-- only react to effects owned by the attacker, not ourselves.
	local players = game:GetService("Players")
	if self.owner == players.LocalPlayer.Character then
		return
	end

	local action = Action.new()
	action._type = "Parry"
	action._when = 250
	action.ihbc = true
	action.name = "Effect Timing"

	return self:action(timing, action)
end
]==] },
{ "Sound Timing", [==[-- Timing type: Sound
---@type Action
local Action = getfenv().Action

return function(self, timing)
	timing.alp = false -- allow local player

	local action = Action.new()
	action._type = "Parry"
	action._when = 300
	action.hitbox = Vector3.new(30, 30, 30)
	action.name = "Sound Cue Timing"

	return self:action(timing, action)
end
]==] },
{ "Part Timing", [==[-- Timing type: Part
---@type Action
local Action = getfenv().Action

-- waits until the part is close, then blocks through its active window.
return function(self, timing)
	repeat
		task.wait()
	until not self.part.Parent or self:distance(self.part) < 20

	local start = Action.new()
	start._type = "Start Block"
	start._when = 100
	start.name = "Part Block Start"
	self:action(timing, start)

	local stop = Action.new()
	stop._type = "End Block"
	stop._when = 4200
	stop.name = "Part Block End"
	return self:action(timing, stop)
end
]==] },
{ "Two-Phase", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- two hits in one animation, timed off the track's own progress: parry the first hit
-- immediately, then wait until the animation reaches a set point (TimePosition) and parry
-- the second. use for attacks whose second hit follows by animation, not a fixed delay.
-- bails if the attacker feints and the track isnt playing.
return function(self, timing)
	timing.duih = false -- delay until in hitbox
	timing.fhb = false -- forward hitbox

	local first = Action.new()
	first._type = "Parry"
	first._when = 0
	first.hitbox = Vector3.new(20, 20, 25)
	first.name = "First Hit"
	self:action(timing, first)

	repeat
		task.wait()
	until self.track.TimePosition >= 0.25 or not self.track.IsPlaying

	if not self.track.IsPlaying then
		return
	end

	timing.duih = true -- delay until in hitbox
	timing.fhb = true -- forward hitbox
	timing.hitbox = Vector3.new(20, 20, 20)

	local second = Action.new()
	second._type = "Parry"
	second._when = 0
	second.name = "Second Hit"
	return self:action(timing, second)
end
]==] },
{ "Latency-Settled Parry", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action
local Latency = getfenv().Latency

-- waits a fixed real-time settle (minus your ping) before deciding
return function(self, timing)
	task.wait(0.4 - Latency.rtt())

	local action = Action.new()
	action._type = "Parry"
	action._when = 0
	action.ihbc = true
	action.hitbox = Vector3.new(20, 20, 20)
	action.name = "Settled Timing"

	return self:action(timing, action)
end
]==] },
{ "Sound Branch", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action

-- branches on replicated sound markers parented under the attacker's HumanoidRootPart
-- useful if two attacks use the same animation, so you use sound to tell the difference
return function(self, timing)
	local hrp = self.entity:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	if hrp:FindFirstChild("REP_SOUND_0000000000") then
		local start = Action.new()
		start._type = "Start Block"
		start._when = 0
		start.hitbox = Vector3.new(45, 25, 45)
		start.name = "Variant Start Block"
		self:action(timing, start)

		local stop = Action.new()
		stop._type = "End Block"
		stop._when = 850
		stop.ihbc = true -- ignore hitbox check
		stop.name = "Variant End Block"
		return self:action(timing, stop)
	end

	local action = Action.new()
	action._type = "Parry"
	action._when = 400
	action.hitbox = Vector3.new(20, 20, 20)
	action.name = "Normal Timing"
	return self:action(timing, action)
end
]==] },
{ "Feint Detection", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action
local Signal = getfenv().Signal

-- cancel a swing if its feinted (uses the feint sound to confirm its a real feint)
return function(self, timing)
	local action = Action.new()
	action._type = "Parry"
	action._when = 350
	action.hitbox = Vector3.new(25, 15, 25)
	action.name = "Cancelable Timing"

	local onDescendantAdded = Signal.new(self.entity.DescendantAdded)
	self.tmaid:add(onDescendantAdded:connect("CancelOnSound", function(child)
		if child.Name ~= "CLIENT_SOUND_0000000000" then
			return
		end
		local current = self.tasks[#self.tasks]
		if current then
			current:cancel()
		end
	end))

	return self:action(timing, action)
end
]==] },
{ "Terrain Listener", [==[-- Timing type: Effect
---@type Action
local Action = getfenv().Action
local TerrainListener = getfenv().TerrainListener

local listener = TerrainListener.new("MyTerrainMove")

return function(self, timing)
	if self:distance(self.owner) >= 50 then
		return
	end

	local hrp = self.owner:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	listener:connect(function(child)
		if child.Name ~= "REP_EMIT" or not child:IsA("Attachment") then
			return
		end
		task.wait(0.02)
		if (child.Position - hrp.Position).Magnitude >= 5 then
			return
		end

		timing.fhb = false
		local action = Action.new()
		action._type = "Parry"
		action._when = 0
		action.ihbc = true
		action.name = "Terrain AoE Timing"
		self:action(timing, action)
	end)
end
]==] },
{ "Sound Defender (Anim-Gated)", [==[-- Timing type: Sound
---@type Action
local Action = getfenv().Action
local Waiter = getfenv().Waiter

-- sound timing: runs when a tracked sound plays (self.owner is who played it).
-- confirms the attacker is actually playing the expected animation (via Waiter.ftrack) before reacting
return function(self, timing)
	if not self.owner then
		return
	end

	local humanoid = self.owner:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	if not Waiter.ftrack("rbxassetid://0000000000", animator) then
		return
	end

	timing.fhb = true
	local action = Action.new()
	action._type = "Dodge"
	action._when = 350
	action.hitbox = Vector3.new(20, 20, 50)
	action.name = "Sound-Gated Timing"
	return self:action(timing, action)
end
]==] },
{ "Shared Sub-Timing", [==[-- Timing type: Animation
---@type Action
local Action = getfenv().Action
local Timing = getfenv().Timing

-- Builds a fresh timing with its own flags and defends against THAT instead of the passed-in
-- one. Use when one animation should be handled differently depending on state (e.g. a
-- close-range variant with a different hitbox/flags).
return function(self, timing)
	if self:distance(self.entity) <= 10 then
		local closeTiming = Timing.new()
		closeTiming.fhb = true
		closeTiming.duih = false
		closeTiming.name = "MyMove"
		closeTiming.cbm = true

		local action = Action.new()
		action._type = "Parry"
		action._when = 0
		action.ihbc = true
		action.name = "Close Sub-Timing"
		return self:action(closeTiming, action)
	end

	local action = Action.new()
	action._type = "Parry"
	action._when = 300
	action.hitbox = Vector3.new(15, 15, 30)
	action.name = "Far Timing"
	return self:action(timing, action)
end
]==] },
}

local TEMPLATE_NAMES = {}
local TEMPLATE_CODE = {}
for _, entry in ipairs(TEMPLATES) do
	TEMPLATE_NAMES[#TEMPLATE_NAMES + 1] = entry[1]
	TEMPLATE_CODE[entry[1]] = entry[2]
end

function TimingBuilderTab.ensurePersistence()
	if SaveManager.llcn then
		return
	end

	local name = "MyTimings"
	local exists = false
	for _, file in ipairs(SaveManager.list()) do
		if file == name then
			exists = true
			break
		end
	end

	if not exists then
		SaveManager.create(name)
	end

	SaveManager.load(name)
	SaveManager.autoload(name)
end

---@param box table
---@param getActive fun():Timing?
---@param getWritable fun():Timing?
---@return table
local function buildActionsEditor(box, getActive, getWritable)
	getWritable = getWritable or getActive
	local ctrl = {}
	local list, nameInput, typeDrop, delayInput, hbLength, hbWidth, hbHeight

	local function anc(apply)
		return function(value)
			---@note: Only mutate when an action is actually selected. Checking the selection before
			---getWritable() also avoids spuriously cloning an internal timing into the config just
			---from touching a field while nothing is selected (e.g. while configuring a new action).
			if not list.Value then
				return
			end
			local timing = getWritable()
			if not timing then
				return
			end
			local action = timing.actions:find(list.Value)
			if not action then
				return
			end
			apply(action, value)
			SaveManager.markDirty()
		end
	end

	list = box:AddDropdown(nil, {
		Text = "Actions",
		Values = {},
		AllowNull = true,
		Searchable = true,
		Callback = function(value)
			local timing = getActive()
			if not timing or not value then
				return
			end
			local action = timing.actions:find(value)
			if not action then
				return
			end
			nameInput:SetRawValue(action.name)
			typeDrop:SetRawValue(action._type)
			delayInput:SetRawValue(tostring(action._when or 0))
			hbWidth:SetRawValue(action.hitbox.X)
			hbHeight:SetRawValue(action.hitbox.Y)
			hbLength:SetRawValue(action.hitbox.Z)
		end,
	})

	typeDrop = box:AddDropdown(nil, {
		Text = "Action Type",
		Values = ACTION_TYPES,
		Default = 1,
		Callback = anc(function(action, value)
			action._type = value
		end),
	})

	delayInput = box:AddInput(nil, {
		Text = "Action Delay (ms)",
		Numeric = true,
		Finished = true,
		Callback = anc(function(action, value)
			action._when = tonumber(value) or 0
		end),
	})

	hbLength = box:AddSlider(nil, {
		Text = "Action Hitbox Length",
		Min = 0,
		Max = 300,
		Default = 0,
		Rounding = 0,
		Callback = anc(function(action, value)
			action.hitbox = Vector3.new(action.hitbox.X, action.hitbox.Y, value)
		end),
	})

	hbWidth = box:AddSlider(nil, {
		Text = "Action Hitbox Width",
		Min = 0,
		Max = 300,
		Default = 0,
		Rounding = 0,
		Callback = anc(function(action, value)
			action.hitbox = Vector3.new(value, action.hitbox.Y, action.hitbox.Z)
		end),
	})

	hbHeight = box:AddSlider(nil, {
		Text = "Action Hitbox Height",
		Min = 0,
		Max = 300,
		Default = 0,
		Rounding = 0,
		Callback = anc(function(action, value)
			action.hitbox = Vector3.new(action.hitbox.X, value, action.hitbox.Z)
		end),
	})

	box:AddDivider()

	nameInput = box:AddInput(nil, {
		Text = "Action Name",
	})

	box:AddButton("Create Action", function()
		local timing = getWritable()
		if not timing then
			return Logger.longNotify("Select or create a timing first.")
		end
		local name = nameInput.Value
		if not name or #name <= 0 then
			return Logger.longNotify("Enter an action name.")
		end
		if timing.actions:find(name) then
			return Logger.longNotify("The action '%s' already exists.", name)
		end
		---@note: Seed the new action from whatever is currently in the editor fields so "set the
		---type/delay/hitbox, name it, create" produces an action with those values -- instead of a
		---blank action while the values silently apply to the previously-selected action.
		local action = Action.new()
		action.name = name
		action._type = typeDrop.Value or "Parry"
		action._when = tonumber(delayInput.Value) or 0
		action.hitbox = Vector3.new(
			tonumber(hbWidth.Value) or 0,
			tonumber(hbHeight.Value) or 0,
			tonumber(hbLength.Value) or 0
		)
		timing.actions:push(action)
		SaveManager.markDirty()
		---@note: reload() clears the selection and resets the fields, so the editor returns to a
		---clean "new action" state and the next create won't inherit this one's values.
		ctrl.reload(timing)
		list:Display()
	end)

	box:AddButton("Duplicate Action", function()
		local timing = getWritable()
		if not timing then
			return Logger.longNotify("Select or create a timing first.")
		end
		local action = timing.actions:find(list.Value)
		if not action then
			return Logger.longNotify("Select an action to duplicate.")
		end
		local name = nameInput.Value
		if not name or #name <= 0 then
			return Logger.longNotify("Enter a name for the copy.")
		end
		if timing.actions:find(name) then
			return Logger.longNotify("The action '%s' already exists.", name)
		end
		local copy = action:clone()
		copy.name = name
		timing.actions:push(copy)
		SaveManager.markDirty()
		ctrl.reload(timing)
		list:SetValue(name)
		list:Display()
	end)

	box:AddButton("Remove Action", function()
		local timing = getWritable()
		if not timing then
			return
		end
		local action = timing.actions:find(list.Value)
		if not action then
			return Logger.longNotify("Select an action to remove.")
		end
		timing.actions:remove(action)
		SaveManager.markDirty()
		ctrl.reload(timing)
	end)

	---@param timing Timing?
	function ctrl.reload(timing)
		list:SetValues(timing and timing.actions:names() or {})
		list:SetValue(nil)
		list:Display()
		nameInput:SetRawValue("")
		typeDrop:SetRawValue("Parry")
		delayInput:SetRawValue("0")
		hbLength:SetRawValue(0)
		hbWidth:SetRawValue(0)
		hbHeight:SetRawValue(0)
	end

	return ctrl
end

---@param tab table
---@param getActive fun():Timing?
---@param getWritable fun():Timing?
---@return table
local function buildTimingForm(tab, getActive, getWritable)
	getWritable = getWritable or getActive
	local form = {}
	form.typeMarker = { Type = "Dropdown", Value = "Animation" }

	local function bind(apply)
		return function(value)
			local timing = getWritable()
			if not timing then
				return
			end
			apply(timing, value)
			SaveManager.markDirty()
		end
	end

	form.tag = tab:AddDropdown(nil, {
		Text = "Tag",
		Values = TAGS,
		Default = 1,
		Callback = bind(function(t, v)
			t.tag = v
		end),
	})

	form.imdd = tab:AddSlider(nil, {
		Text = "Initial Minimum Distance",
		Min = 0,
		Max = 300,
		Default = 0,
		Rounding = 0,
		Suffix = "s",
		Callback = bind(function(t, v)
			t.imdd = v
		end),
	})

	form.imxd = tab:AddSlider(nil, {
		Text = "Initial Maximum Distance",
		Min = 0,
		Max = 2500,
		Default = 1000,
		Rounding = 0,
		Suffix = "s",
		Callback = bind(function(t, v)
			t.imxd = v
		end),
	})

	form.punishable = tab:AddSlider(nil, {
		Text = "Punishable Window",
		Min = 0,
		Max = 2,
		Default = 0.6,
		Rounding = 2,
		Suffix = "s",
		Callback = bind(function(t, v)
			t.punishable = v
		end),
	})

	form.after = tab:AddSlider(nil, {
		Text = "After Window",
		Min = 0,
		Max = 1,
		Default = 0.1,
		Rounding = 2,
		Suffix = "s",
		Callback = bind(function(t, v)
			t.after = v
		end),
	})

	form.bfht = tab:AddSlider(nil, {
		Text = "Block Fallback Hold Time",
		Min = 0,
		Max = 5,
		Default = 0.3,
		Rounding = 2,
		Suffix = "s",
		Callback = bind(function(t, v)
			t.bfht = v
		end),
	})

	form.hso = tab:AddSlider(nil, {
		Text = "Hitbox Backwards Offset",
		Min = -50,
		Max = 50,
		Default = 0,
		Rounding = 0,
		Suffix = "s",
		Callback = bind(function(t, v)
			t.hso = v
		end),
	})

	form.behavior = tab:AddDropdown(nil, {
		Text = "Behavior",
		Values = { "Static", "Module" },
		Default = 1,
		Callback = bind(function(t, v)
			t.umoa = (v == "Module")
		end),
	})

	local moduleBox = tab:AddDependencyBox()

	form.smn = moduleBox:AddToggle(nil, {
		Text = "Skip Module Notification",
		Default = false,
		Callback = bind(function(t, v)
			t.smn = v
		end),
	})

	form.smod = moduleBox:AddDropdown(nil, {
		Text = "Module",
		Values = ModuleManager.loaded(),
		AllowNull = true,
		Searchable = true,
		Callback = bind(function(t, v)
			t.smod = v or ""
		end),
	})

	moduleBox:AddButton("Refresh Modules", function()
		form.smod:SetValues(ModuleManager.loaded())
		form.smod:Display()
	end)

	moduleBox:SetupDependencies({
		{ form.behavior, "Module" },
	})

	local actionsBox = tab:AddDependencyBox()
	form.actions = buildActionsEditor(actionsBox, getActive, getWritable)
	actionsBox:SetupDependencies({
		{ form.behavior, "Static" },
	})

	form.duih = tab:AddToggle(nil, {
		Text = "Delay Until In Hitbox",
		Default = false,
		Callback = bind(function(t, v)
			t.duih = v
		end),
	})

	local duihBox = tab:AddDependencyBox()

	form.hbLength = duihBox:AddSlider(nil, {
		Text = "Hitbox Length",
		Min = 0,
		Max = 300,
		Default = 0,
		Rounding = 0,
		Callback = bind(function(t, v)
			t.hitbox = Vector3.new(t.hitbox.X, t.hitbox.Y, v)
		end),
	})

	form.hbWidth = duihBox:AddSlider(nil, {
		Text = "Hitbox Width",
		Min = 0,
		Max = 300,
		Default = 0,
		Rounding = 0,
		Callback = bind(function(t, v)
			t.hitbox = Vector3.new(v, t.hitbox.Y, t.hitbox.Z)
		end),
	})

	form.hbHeight = duihBox:AddSlider(nil, {
		Text = "Hitbox Height",
		Min = 0,
		Max = 300,
		Default = 0,
		Rounding = 0,
		Callback = bind(function(t, v)
			t.hitbox = Vector3.new(t.hitbox.X, v, t.hitbox.Z)
		end),
	})

	duihBox:SetupDependencies({
		{ form.duih, true },
	})

	form.fhb = tab:AddToggle(nil, {
		Text = "Front Facing Hitbox",
		Default = true,
		Callback = bind(function(t, v)
			t.fhb = v
		end),
	})

	form.srpn = tab:AddToggle(nil, {
		Text = "Skip Repeat Notification",
		Default = false,
		Callback = bind(function(t, v)
			t.srpn = v
		end),
	})

	form.ndfb = tab:AddToggle(nil, {
		Text = "No Dash Fallback",
		Default = false,
		Callback = bind(function(t, v)
			t.ndfb = v
		end),
	})

	form.nvfb = tab:AddToggle(nil, {
		Text = "No Vent Fallback",
		Default = false,
		Callback = bind(function(t, v)
			t.nvfb = v
		end),
	})

	form.nbfb = tab:AddToggle(nil, {
		Text = "No Block Fallback",
		Default = false,
		Callback = bind(function(t, v)
			t.nbfb = v
		end),
	})

	form.ibi = tab:AddToggle(nil, {
		Text = "Ignore Block Input Gate",
		Default = false,
		Callback = bind(function(t, v)
			t.ibi = v
		end),
	})

	form.iapf = tab:AddToggle(nil, {
		Text = "Ignore Auto Parry Frames",
		Default = false,
		Callback = bind(function(t, v)
			t.iapf = v
		end),
	})

	form.uif = tab:AddToggle(nil, {
		Text = "Use Inhale To Identify Feint",
		Default = false,
		Callback = bind(function(t, v)
			t.uif = v
		end),
	})

	form.nfd = tab:AddToggle(nil, {
		Text = "Ignore Feint Detection",
		Default = false,
		Callback = bind(function(t, v)
			t.nfd = v
		end),
	})

	form.rsc = tab:AddToggle(nil, {
		Text = "Skip If Recently Self-Cast",
		Default = false,
		Callback = bind(function(t, v)
			t.rsc = v
		end),
	})

	local rscBox = tab:AddDependencyBox()

	form.rsaid = rscBox:AddInput(nil, {
		Text = "Recent Self-Cast Animation ID",
		Finished = true,
		Callback = bind(function(t, v)
			t.rsaid = v
		end),
	})

	form.rsaw = rscBox:AddSlider(nil, {
		Text = "Recent Self-Cast Window",
		Min = 0,
		Max = 15,
		Default = 4,
		Rounding = 1,
		Suffix = "s",
		Callback = bind(function(t, v)
			t.rsaw = tonumber(v) or 4.0
		end),
	})

	rscBox:SetupDependencies({
		{ form.rsc, true },
	})

	form.rpue = tab:AddToggle(nil, {
		Text = "Repeat Parry Until End",
		Default = false,
		Callback = bind(function(t, v)
			t.rpue = v
		end),
	})

	local rpueBox = tab:AddDependencyBox()

	form.rsd = rpueBox:AddInput(nil, {
		Text = "Repeat Start Delay (ms)",
		Numeric = true,
		Finished = true,
		Callback = bind(function(t, v)
			t._rsd = tonumber(v) or 0
		end),
	})

	form.rpd = rpueBox:AddInput(nil, {
		Text = "Repeat Parry Delay (ms)",
		Numeric = true,
		Finished = true,
		Callback = bind(function(t, v)
			t._rpd = tonumber(v) or 0
		end),
	})

	rpueBox:SetupDependencies({
		{ form.rpue, true },
	})

	local animBox = tab:AddDependencyBox()

	form.ha = animBox:AddToggle(nil, {
		Text = "Hyperarmor Flag",
		Default = false,
		Callback = bind(function(t, v)
			t.ha = v
		end),
	})

	form.iae = animBox:AddToggle(nil, {
		Text = "Ignore Animation End",
		Default = false,
		Callback = bind(function(t, v)
			t.iae = v
		end),
	})

	local iaeBox = animBox:AddDependencyBox()

	form.mat = iaeBox:AddInput(nil, {
		Text = "Max Animation Timeout",
		Numeric = true,
		Finished = true,
		Callback = bind(function(t, v)
			t.mat = tonumber(v) or 2000
		end),
	})

	iaeBox:SetupDependencies({
		{ form.iae, true },
	})

	form.ieae = animBox:AddToggle(nil, {
		Text = "Ignore Early Animation End",
		Default = false,
		Callback = bind(function(t, v)
			t.ieae = v
		end),
	})

	form.phd = animBox:AddToggle(nil, {
		Text = "Past Hitbox Detection",
		Default = false,
		Callback = bind(function(t, v)
			t.phd = v
		end),
	})

	local phdBox = animBox:AddDependencyBox()

	form.phds = phdBox:AddSlider(nil, {
		Text = "History Seconds",
		Min = 0,
		Max = 3,
		Default = 0.5,
		Rounding = 2,
		Callback = bind(function(t, v)
			t.phds = tonumber(v) or 0
		end),
	})

	phdBox:SetupDependencies({
		{ form.phd, true },
	})

	form.pfh = animBox:AddToggle(nil, {
		Text = "Predict Facing Hitboxes",
		Default = false,
		Callback = bind(function(t, v)
			t.pfh = v
		end),
	})

	form.dp = animBox:AddToggle(nil, {
		Text = "Disable Prediction",
		Default = false,
		Callback = bind(function(t, v)
			t.dp = v
		end),
	})

	form.pfht = animBox:AddSlider(nil, {
		Text = "Extrapolation Time",
		Min = 0,
		Max = 2,
		Default = 0.15,
		Rounding = 3,
		Callback = bind(function(t, v)
			t.pfht = tonumber(v) or 0.15
		end),
	})

	animBox:SetupDependencies({
		{ form.typeMarker, "Animation" },
	})

	local effectBox = tab:AddDependencyBox()

	form.ilp = effectBox:AddToggle(nil, {
		Text = "Ignore Local Player",
		Default = false,
		Callback = bind(function(t, v)
			t.ilp = v
		end),
	})

	form.flp = effectBox:AddToggle(nil, {
		Text = "Force Local Player",
		Default = false,
		Callback = bind(function(t, v)
			t.flp = v
		end),
	})

	effectBox:SetupDependencies({
		{ form.typeMarker, "Effect" },
	})

	local partBox = tab:AddDependencyBox()

	form.uhc = partBox:AddToggle(nil, {
		Text = "Use Hitbox CFrame",
		Default = false,
		Callback = bind(function(t, v)
			t.uhc = v
		end),
	})

	partBox:SetupDependencies({
		{ form.typeMarker, "Part" },
	})

	local soundBox = tab:AddDependencyBox()

	form.alp = soundBox:AddToggle(nil, {
		Text = "Allow Local Player",
		Default = false,
		Callback = bind(function(t, v)
			t.alp = v
		end),
	})

	soundBox:SetupDependencies({
		{ form.typeMarker, "Sound" },
	})

	---@param timing Timing?
	---@param typeKey string
	function form:load(timing, typeKey)
		self.typeMarker.Value = typeKey or "Animation"

		if timing then
			self.tag:SetRawValue(timing.tag)
			self.imdd:SetRawValue(timing.imdd)
			self.imxd:SetRawValue(timing.imxd)
			self.punishable:SetRawValue(timing.punishable)
			self.after:SetRawValue(timing.after)
			self.bfht:SetRawValue(timing.bfht)
			self.hso:SetRawValue(timing.hso)
			self.behavior:SetRawValue(timing.umoa and "Module" or "Static")
			self.smn:SetRawValue(timing.smn)
			self.smod:SetValues(ModuleManager.loaded())
			self.smod:SetRawValue(timing.smod)
			self.duih:SetRawValue(timing.duih)
			self.hbLength:SetRawValue(timing.hitbox.Z)
			self.hbWidth:SetRawValue(timing.hitbox.X)
			self.hbHeight:SetRawValue(timing.hitbox.Y)
			self.fhb:SetRawValue(timing.fhb)
			self.srpn:SetRawValue(timing.srpn)
			self.ndfb:SetRawValue(timing.ndfb)
			self.nvfb:SetRawValue(timing.nvfb)
			self.nbfb:SetRawValue(timing.nbfb)
			self.ibi:SetRawValue(timing.ibi)
			self.iapf:SetRawValue(timing.iapf)
			self.uif:SetRawValue(timing.uif)
			self.nfd:SetRawValue(timing.nfd)
			self.rsc:SetRawValue(timing.rsc)
			self.rsaid:SetRawValue(timing.rsaid or "")
			self.rsaw:SetRawValue(timing.rsaw)
			self.rpue:SetRawValue(timing.rpue)
			self.rsd:SetRawValue(tostring(timing._rsd or 0))
			self.rpd:SetRawValue(tostring(timing._rpd or 0))

			if typeKey == "Animation" then
				self.ha:SetRawValue(timing.ha)
				self.iae:SetRawValue(timing.iae)
				self.mat:SetRawValue(tostring(timing.mat or 2000))
				self.ieae:SetRawValue(timing.ieae)
				self.phd:SetRawValue(timing.phd)
				self.phds:SetRawValue(timing.phds)
				self.pfh:SetRawValue(timing.pfh)
				self.dp:SetRawValue(timing.dp)
				self.pfht:SetRawValue(timing.pfht)
			elseif typeKey == "Effect" then
				self.ilp:SetRawValue(timing.ilp)
				self.flp:SetRawValue(timing.flp)
			elseif typeKey == "Part" then
				self.uhc:SetRawValue(timing.uhc)
			elseif typeKey == "Sound" then
				self.alp:SetRawValue(timing.alp)
			end
		end

		self.actions.reload(timing)
		Library:UpdateDependencyBoxes()
	end

	return form
end

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

---@param tab table
---@param height number
---@return table
local function createCodeEditor(tab, height)
	local GUTTER_W = 34
	local PAD = 6
	local PLACEHOLDER = "-- select or create a module"

	local holder = Library:Create("Frame", {
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -4, 0, height),
		LayoutOrder = 9999,
		ZIndex = 5,
		Parent = tab.Container,
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
		ZIndex = 6,
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
		ZIndex = 6,
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
		ZIndex = 6,
		Parent = holder,
	})

	-- Custom text-selection highlight lives here (ZIndex 5), BEHIND the colored text (6) so the
	-- text reads on top of the selection color. Roblox doesn't render native selection on a
	-- transparent-text box, so we draw it ourselves from box.SelectionStart / box.CursorPosition.
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
		ZIndex = 6,
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
		ZIndex = 7,
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
		ZIndex = 8,
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

	-- Draw the text-selection highlight ourselves: Roblox doesn't render native selection on a
	-- transparent-text box, so build a rectangle per selected line from SelectionStart/CursorPosition.
	local function renderSelection()
		for _, f in ipairs(selectionFrames) do
			f:Destroy()
		end
		selectionFrames = {}

		local sStart, cPos = box.SelectionStart, box.CursorPosition
		if sStart == -1 or cPos == -1 or sStart == cPos then
			return
		end
		local a = math.min(sStart, cPos) -- first selected position (1 = before char 1)
		local b = math.max(sStart, cPos) -- one past the last selected position

		local text = box.Text
		local pos = 1 -- 1-based position at the start of the current line
		for line in (text .. "\n"):gmatch("(.-)\n") do
			local len = #line
			local lineEndPos = pos + len -- position just after this line's last char
			-- Intersect selection [a, b) with this line's positions [pos, lineEndPos] (+1 covers the newline).
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
				-- Line index (0-based) = number of newlines before this line's start position.
				local lineIdx = 0
				for _ in text:sub(1, pos - 1):gmatch("\n") do
					lineIdx = lineIdx + 1
				end
				local w = x2 - x1
				if b > lineEndPos then
					w = w + 4 -- selection continues past this line: show a small trailing block for the newline
				end
				local sel = Library:Create("Frame", {
					BackgroundColor3 = Library.AccentColor,
					BackgroundTransparency = 0.55,
					BorderSizePixel = 0,
					Position = UDim2.new(0, 2 + x1, 0, lineIdx * LINE_H),
					Size = UDim2.new(0, math.max(w, 2), 0, LINE_H),
					ZIndex = 5,
					Parent = scroll,
				})
				Library:AddToRegistry(sel, { BackgroundColor3 = "AccentColor" })
				selectionFrames[#selectionFrames + 1] = sel
			end
			pos = lineEndPos + 1 -- skip the newline
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

	pcall(function()
		tab:Resize()
	end)

	return {
		get = function()
			return box.Text
		end,
		set = function(text)
			box.Text = text or ""
			refresh()
		end,
		-- Toggle whether the box can be typed into. Used to make the template PREVIEW read-only
		-- while keeping module editing writable. When locked, also hide the custom caret.
		setEditable = function(editable)
			box.TextEditable = editable and true or false
			if not editable then
				caret.Visible = false
			end
		end,
	}
end

---@return string? encoded, number timingCount, number moduleCount
local function buildExportString()
	local payload = {
		v = 1,
		timings = {
			version = 1,
			animation = SaveManager.as.config:serialize(),
			effect = SaveManager.es.config:serialize(),
			part = SaveManager.ps.config:serialize(),
			sound = SaveManager.ss.config:serialize(),
		},
	}

	local modules, globals = ModuleManager.exportSources()
	payload.modules = modules
	payload.globals = globals

	local ok, encoded = pcall(function()
		return JSON.encode(payload)
	end)
	if not ok or type(encoded) ~= "string" then
		return nil
	end

	local timingCount = #payload.timings.animation
		+ #payload.timings.effect
		+ #payload.timings.part
		+ #payload.timings.sound
	local moduleCount = countKeys(modules) + countKeys(globals)

	return "LUMA1:" .. base64Encode(encoded), timingCount, moduleCount
end

-- Base export folder in the executor workspace; each export drops a timestamped subfolder here so a
-- history is kept.
local EXPORT_ROOT = "Aero/TimingBuilderExport"

---Ensure a folder path exists (creating each level, since some executors don't make nested folders).
---@param path string
local function ensureFolder(path)
	local built = nil
	for segment in string.gmatch(path, "[^/]+") do
		built = built and (built .. "/" .. segment) or segment
		if not isfolder(built) then
			pcall(makefolder, built)
		end
	end
end

---Make a module name safe to use as a flat filename (path separators -> underscores).
---@param name string
---@return string
local function safeFileName(name)
	return (tostring(name):gsub("[\\/]", "_"))
end

---Write the new/changed modules + the timing patch JSON into a folder in the executor workspace.
---Returns (folderPath, moduleFileCount, err).
---@return string?, number?, string?
local function exportToWorkspace()
	if type(writefile) ~= "function" or type(makefolder) ~= "function" or type(isfolder) ~= "function" then
		return nil, nil, "This executor has no filesystem functions."
	end

	local modules, globals = ModuleManager.exportSources()

	-- The timing patch: just the timings portion of the export payload.
	local timingPatch = {
		version = 1,
		animation = SaveManager.as.config:serialize(),
		effect = SaveManager.es.config:serialize(),
		part = SaveManager.ps.config:serialize(),
		sound = SaveManager.ss.config:serialize(),
	}

	local okEncode, timingsJson = pcall(JSON.encode, timingPatch)
	if not okEncode or type(timingsJson) ~= "string" then
		return nil, nil, "Failed to encode the timing patch."
	end

	-- Timestamped subfolder per export so previous exports are preserved as a history.
	local stamp = os.date("!%Y-%m-%d_%H-%M-%S")
	local exportFolder = EXPORT_ROOT .. "/" .. stamp

	ensureFolder(EXPORT_ROOT)

	-- If two exports land in the same second, suffix with a counter so we never clobber one.
	if isfolder(exportFolder) then
		local n = 2
		while isfolder(exportFolder .. "_" .. n) do
			n = n + 1
		end
		exportFolder = exportFolder .. "_" .. n
	end

	ensureFolder(exportFolder)

	local okWrite, resultOrErr = pcall(function()
		writefile(exportFolder .. "/timings.json", timingsJson)

		local fileCount = 0

		if next(modules) then
			ensureFolder(exportFolder .. "/modules")
			for name, source in pairs(modules) do
				writefile(exportFolder .. "/modules/" .. safeFileName(name) .. ".lua", source)
				fileCount = fileCount + 1
			end
		end

		if next(globals) then
			ensureFolder(exportFolder .. "/globals")
			for name, source in pairs(globals) do
				writefile(exportFolder .. "/globals/" .. safeFileName(name) .. ".lua", source)
				fileCount = fileCount + 1
			end
		end

		return fileCount
	end)

	if not okWrite then
		return nil, nil, tostring(resultOrErr)
	end

	return exportFolder, resultOrErr, nil
end

local function resetTimingData()
	pcall(function() SaveManager.as.config:clear() end)
	pcall(function() SaveManager.es.config:clear() end)
	pcall(function() SaveManager.ps.config:clear() end)
	pcall(function() SaveManager.ss.config:clear() end)
	if SaveManager.llcn then
		pcall(function() SaveManager.write(SaveManager.llcn) end)
	end
	pcall(function() ModuleManager.resetUserModules() end)
	pcall(function() ModuleManager.refresh() end)

	if TimingBuilderTab._refreshEditList then
		TimingBuilderTab._refreshEditList()
	end
	if TimingBuilderTab._refreshModulesList then
		TimingBuilderTab._refreshModulesList()
	end

	Logger.notify("Timing data reset to the original baked-in set.")
end

---Count all distinct timings the script knows (baked-in internal + config overrides/additions),
---deduped by id per type so a config override of an internal timing isn't double-counted.
---@return number
local function countKnownTimings()
	local total = 0
	for _, typeKey in ipairs(TYPE_ORDER) do
		local pair = TYPES[typeKey].pair()
		if pair then
			local seen = {}
			for _, timing in ipairs(pair.config:list()) do
				seen[timing:id()] = true
			end
			for _, timing in ipairs(pair.internal:list()) do
				seen[timing:id()] = true
			end
			for _ in next, seen do
				total = total + 1
			end
		end
	end
	return total
end

---Count all modules the script knows (user files + baked-in), matching the Modules tab list.
---@return number
local function countKnownModules()
	local ok, files = pcall(ModuleManager.listFiles)
	if ok and type(files) == "table" then
		return #files
	end
	return 0
end

---@param tab table
function TimingBuilderTab.initGeneral(tab)
	-- Statistics: live counts of known timings + modules.
	local timingsStat = tab:AddLabel("Timings: ...")
	local modulesStat = tab:AddLabel("Modules: ...")

	local function refreshStats()
		timingsStat:SetText(string.format("Timings: %d", countKnownTimings()))
		modulesStat:SetText(string.format("Modules: %d", countKnownModules()))
	end

	refreshStats()
	TimingBuilderTab._refreshStats = refreshStats

	tab:AddButton("Refresh Statistics", refreshStats)

	tab:AddDivider()

	local animVisualizerToggle = tab:AddToggle("ShowAnimationVisualizer", {
		Text = "Show Animation Visualizer",
		Default = false,
		Callback = AnimationVisualizer.visible,
	})
	animVisualizerToggle:AddKeyPicker(
		"AnimationVisualizerKeyBind",
		{ Default = "N/A", SyncToggleState = true, Text = "Animation Visualizer" }
	)

	local showLoggerToggle = tab:AddToggle("ShowLoggerWindow", {
		Text = "Show Logger Window",
		Default = false,
		Callback = function(value)
			Library.InfoLoggerFrame.Visible = value
		end,
	})
	showLoggerToggle:AddKeyPicker(
		"ShowLoggerWindowKeyBind",
		{ Default = "N/A", SyncToggleState = true, Text = "Logger Window" }
	)

	tab:AddToggle("LogKnownTimings", {
		Text = "Log Known Timings",
		Default = false,
	})

	tab:AddSlider("MinimumLoggerDistance", {
		Text = "Minimum Logger Distance",
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = "m",
		Default = 0,
	})

	tab:AddSlider("MaximumLoggerDistance", {
		Text = "Maximum Logger Distance",
		Min = 0,
		Max = 1000,
		Rounding = 0,
		Suffix = "m",
		Default = 0,
	})

	local blacklistedKeys = tab:AddDropdown("BlacklistedKeys", {
		Text = "Blacklisted Keys",
		Default = {},
		Values = Library:KeyBlacklists(),
		Multi = true,
	})

	tab:AddButton("Remove Selected Keys", function()
		for selected, _ in next, blacklistedKeys.Value do
			Library.InfoLoggerData.KeyBlacklistList[selected] = nil
		end
		blacklistedKeys:SetValues(Library:KeyBlacklists())
		blacklistedKeys:SetValue({})
		blacklistedKeys:Display()
	end)

	tab:AddDivider()

	tab:AddButton("Export Timings", function()
		local encoded, timingCount, moduleCount = buildExportString()
		if not encoded then
			return Logger.longNotify("Failed to build the export string.")
		end
		local ok = pcall(setclipboard, encoded)
		if not ok then
			return Logger.longNotify("Failed to copy to clipboard.")
		end

		-- Also dump the new/changed modules + the timing patch JSON to a folder in the workspace.
		local folder, fileCount, exportErr = exportToWorkspace()
		if not folder then
			Logger.notify(
				"Copied %d timing(s) + %d module(s) to clipboard. (Workspace export failed: %s)",
				timingCount,
				moduleCount,
				tostring(exportErr)
			)
			return
		end

		Logger.notify(
			"Copied %d timing(s) + %d module(s) to clipboard, and saved %d module file(s) + timings.json to workspace/%s.",
			timingCount,
			moduleCount,
			fileCount or 0,
			folder
		)
	end)

	tab:AddButton({
		Text = "Reset Timing Data",
		DoubleClick = true,
		DoubleClickText = "Wipe ALL custom timings + modules?",
		Func = resetTimingData,
	})
end

---@param tab table
function TimingBuilderTab.initCreate(tab)
	local state = { type = "Animation", draft = AnimationTiming.new(), suppressTypeReset = false, dupEntries = {} }
	local form, nameInput, idInput, typeDrop, dupDrop

	-- Build the "Duplicate From" list: every existing timing (config overrides + baked-in), by type.
	local function rebuildDuplicateList()
		state.dupEntries = {}
		local names = {}
		for _, typeKey in ipairs(TYPE_ORDER) do
			local pair = TYPES[typeKey].pair()
			if pair then
				local seen = {}
				for _, timing in ipairs(pair.config:list()) do
					local display = string.format("[%s] %s", typeKey, timing.name)
					state.dupEntries[display] = { timing = timing, type = typeKey }
					names[#names + 1] = display
					seen[timing:id()] = true
				end
				for _, timing in ipairs(pair.internal:list()) do
					if not seen[timing:id()] then
						local display = string.format("[%s] %s", typeKey, timing.name)
						state.dupEntries[display] = { timing = timing, type = typeKey }
						names[#names + 1] = display
					end
				end
			end
		end
		table.sort(names)
		if dupDrop then
			dupDrop:SetValues(names)
		end
	end

	typeDrop = tab:AddDropdown(nil, {
		Text = "Timing Type",
		Values = TYPE_ORDER,
		Default = 1,
		Callback = function(value)
			-- Skip the reset when the type is being set programmatically by a duplicate load.
			if state.suppressTypeReset then
				return
			end
			state.type = value
			state.draft = TYPES[value].new()
			nameInput:SetRawValue("")
			idInput:SetRawValue("")
			form:load(state.draft, value)
		end,
	})

	nameInput = tab:AddInput(nil, {
		Text = "Timing Name",
	})

	idInput = tab:AddInput(nil, {
		Text = "Timing ID",
		Placeholder = "Animation/Sound ID, or Part/Effect name",
	})

	-- Duplicate an existing timing: clones all of its fields into the draft. Picks up the source's
	-- type, suffixes the name with " Copy", and clears the ID so you set a new (unique) one.
	dupDrop = tab:AddDropdown(nil, {
		Text = "Duplicate From",
		Values = {},
		Default = nil,
		AllowNull = true,
		Searchable = true,
		Callback = function(value)
			if not value then
				return
			end
			local entry = state.dupEntries[value]
			if not entry then
				return
			end

			state.type = entry.type
			state.suppressTypeReset = true
			pcall(function()
				typeDrop:SetValue(entry.type)
			end)
			state.suppressTypeReset = false

			state.draft = entry.timing:clone()
			nameInput:SetRawValue((entry.timing.name or "") .. " Copy")
			idInput:SetRawValue("")
			form:load(state.draft, entry.type)

			Logger.notify("Loaded a copy of '%s'. Set a new Timing ID before creating.", entry.timing.name)
		end,
	})

	tab:AddButton("Create Timing", function()
		local info = TYPES[state.type]
		local name = nameInput.Value
		local id = idInput.Value
		if not name or #name <= 0 then
			return Logger.longNotify("Enter a timing name.")
		end
		if not id or #id <= 0 then
			return Logger.longNotify("Enter a timing ID.")
		end
		local pair = info.pair()
		if pair:index(id) then
			return Logger.longNotify("A timing with ID '%s' already exists.", id)
		end
		if pair:find(name) then
			return Logger.longNotify("A timing named '%s' already exists.", name)
		end

		state.draft.name = name
		state.draft[info.idProp] = id

		local ok, err = pcall(function()
			pair.config:push(state.draft)
		end)
		if not ok then
			return Logger.longNotify("Failed to create timing: %s", tostring(err))
		end

		SaveManager.markDirty()
		Logger.notify("Created %s timing '%s'.", state.type, name)
		TimingBuilderTab.refreshEditList()
		rebuildDuplicateList()

		state.draft = info.new()
		nameInput:SetRawValue("")
		idInput:SetRawValue("")
		form:load(state.draft, state.type)
	end)

	tab:AddButton("Refresh Duplicate List", rebuildDuplicateList)

	tab:AddDivider()

	form = buildTimingForm(tab, function()
		return state.draft
	end)
	form:load(state.draft, "Animation")

	rebuildDuplicateList()
end

---@param tab table
function TimingBuilderTab.initEdit(tab)
	local state = { selected = nil, entry = nil, entries = {} }
	local form, list, renameInput, idInput

	local function rebuildList()
		state.entries = {}
		local names = {}

		for _, typeKey in ipairs(TYPE_ORDER) do
			local pair = TYPES[typeKey].pair()
			if pair then
				local seen = {}
				for _, timing in ipairs(pair.config:list()) do
					local display = string.format("[%s] %s", typeKey, timing.name)
					state.entries[display] = { pair = pair, timing = timing, type = typeKey }
					names[#names + 1] = display
					seen[timing:id()] = true
				end
				for _, timing in ipairs(pair.internal:list()) do
					if not seen[timing:id()] then
						local display = string.format("[%s] %s", typeKey, timing.name)
						state.entries[display] = { pair = pair, timing = timing, type = typeKey }
						names[#names + 1] = display
					end
				end
			end
		end

		table.sort(names)

		if list then
			list:SetValues(names)
			list:SetValue(nil)
			list:Display()
		end

		if TimingBuilderTab._refreshStats then
			TimingBuilderTab._refreshStats()
		end
	end

	local function getWritable()
		local timing = state.selected
		if not timing then
			return nil
		end
		local entry = state.entry
		if not entry then
			return timing
		end
		local pair = entry.pair
		local id = timing:id()
		if pair.config.timings[id] == timing then
			return timing
		end
		local existing = pair.config.timings[id]
		if existing then
			state.selected = existing
			return existing
		end
		local copy = timing:clone()
		local ok = pcall(function()
			pair.config:push(copy)
		end)
		if not ok then
			return timing
		end
		state.selected = copy
		SaveManager.markDirty()
		Logger.notify("Editing '%s' (copied into your config so changes save).", copy.name)
		return copy
	end

	list = tab:AddDropdown(nil, {
		Text = "Timing",
		Values = {},
		AllowNull = true,
		Searchable = true,
		Callback = function(display)
			state.selected = nil
			state.entry = nil
			if not display then
				if form then
					form:load(nil, "Animation")
				end
				return
			end
			local entry = state.entries[display]
			if not entry then
				return
			end

			-- If editing a baked-in timing previously created a config override (getWritable clones on
			-- first edit), select THAT override so its saved changes show -- otherwise state.entries
			-- still points at the stale internal object and the edits look lost on re-select.
			local timing = entry.timing
			local override = entry.pair and entry.pair.config.timings[timing:id()]
			if override then
				timing = override
			end

			state.selected = timing
			state.entry = entry
			renameInput:SetRawValue(timing.name)
			idInput:SetRawValue(timing:id())
			form:load(timing, entry.type)
		end,
	})

	tab:AddButton("Refresh List", rebuildList)

	renameInput = tab:AddInput(nil, {
		Text = "Rename To",
		Finished = true,
	})

	tab:AddButton("Rename Timing", function()
		if not state.entry then
			return Logger.longNotify("Select a timing.")
		end
		local newName = renameInput.Value
		if not newName or #newName <= 0 then
			return Logger.longNotify("Enter a new name.")
		end
		if state.entry.pair:find(newName) then
			return Logger.longNotify("A timing named '%s' already exists.", newName)
		end
		local timing = getWritable()
		if not timing then
			return
		end
		timing.name = newName
		SaveManager.markDirty()
		Logger.notify("Renamed to '%s'.", newName)
		rebuildList()
	end)

	idInput = tab:AddInput(nil, {
		Text = "ID To",
		Finished = true,
	})

	tab:AddButton("Change ID", function()
		if not state.entry then
			return Logger.longNotify("Select a timing.")
		end
		local newId = idInput.Value
		if not newId or #newId <= 0 then
			return Logger.longNotify("Enter a new ID.")
		end
		local pair = state.entry.pair
		local oldId = state.entry.timing:id()
		if newId == oldId then
			return Logger.longNotify("ID is unchanged.")
		end
		if pair:index(newId) then
			return Logger.longNotify("A timing with ID '%s' already exists.", newId)
		end
		local timing = getWritable()
		if not timing then
			return
		end
		local idProp = TYPES[state.entry.type].idProp
		---@note: The config container is keyed by id, so rehome the timing: remove it under the old
		---id, set the new id field, then re-push it under the new id.
		pair.config:remove(timing)
		timing[idProp] = newId
		local ok, err = pcall(function()
			pair.config:push(timing)
		end)
		if not ok then
			-- Restore the old id and re-add so a failed change can't drop the timing.
			timing[idProp] = oldId
			pcall(function()
				pair.config:push(timing)
			end)
			return Logger.longNotify("Failed to change ID: %s", tostring(err))
		end
		SaveManager.markDirty()
		Logger.notify("Changed ID to '%s'.", newId)
		rebuildList()
	end)

	tab:AddButton({
		Text = "Delete Timing",
		DoubleClick = true,
		Func = function()
			local entry = state.entry
			if not entry then
				return Logger.longNotify("Select a timing.")
			end
			local id = entry.timing:id()
			local configTiming = entry.pair.config.timings[id]
			if not configTiming then
				return Logger.longNotify("Internal timings are baked in; edit one to make a deletable copy first.")
			end
			entry.pair.config:remove(configTiming)
			SaveManager.markDirty()
			Logger.notify("Deleted '%s'.", entry.timing.name)
			state.selected = nil
			state.entry = nil
			form:load(nil, "Animation")
			rebuildList()
		end,
	})

	tab:AddDivider()

	form = buildTimingForm(tab, function()
		return state.selected
	end, getWritable)
	form:load(nil, "Animation")

	TimingBuilderTab._refreshEditList = rebuildList
	rebuildList()
end

function TimingBuilderTab.refreshEditList()
	if TimingBuilderTab._refreshEditList then
		TimingBuilderTab._refreshEditList()
	end
end

---@param tab table
function TimingBuilderTab.initModules(tab)
	local list, nameInput, templateDrop, editor

	local function rebuild()
		local files = ModuleManager.listFiles()
		if list then
			list:SetValues(files)
			list:SetValue(nil)
			list:Display()
		end

		if TimingBuilderTab._refreshStats then
			TimingBuilderTab._refreshStats()
		end
	end

	list = tab:AddDropdown(nil, {
		Text = "Modules",
		Values = {},
		AllowNull = true,
		Searchable = true,
		Callback = function(name)
			if not name then
				editor.set("")
				return
			end
			-- Selecting a real module -> editable.
			editor.setEditable(true)
			editor.set(ModuleManager.readFile(name) or "-- (empty)")
		end,
	})

	tab:AddButton("Refresh List", function()
		rebuild()
		ModuleManager.refresh()
	end)

	tab:AddButton("Save Code", function()
		local name = list.Value
		if not name then
			return Logger.longNotify("Select a module to save.")
		end
		local ok, err = validateModuleSource(editor.get())
		if not ok then
			return Logger.longNotify("Not saved -- %s", err)
		end
		if ModuleManager.writeFile(name, editor.get()) then
			Logger.notify("Saved module '%s'.", name)
			ModuleManager.refresh()
		else
			Logger.longNotify("Failed to save module '%s'.", name)
		end
	end)

	tab:AddButton({
		Text = "Delete Module",
		DoubleClick = true,
		Func = function()
			local name = list.Value
			if not name then
				return Logger.longNotify("Select a module to delete.")
			end
			if ModuleManager.deleteFile(name) then
				Logger.notify("Deleted module '%s'.", name)
				editor.set("")
				rebuild()
				ModuleManager.refresh()
			else
				Logger.longNotify("Failed to delete module '%s'.", name)
			end
		end,
	})

	tab:AddDivider()

	nameInput = tab:AddInput(nil, {
		Text = "New Module Name",
	})

	templateDrop = tab:AddDropdown(nil, {
		Text = "Template",
		Values = TEMPLATE_NAMES,
		Default = 1,
		Searchable = true,
		Callback = function(value)
			if editor then
				-- Template preview is read-only; create a module from it to edit it.
				editor.set(TEMPLATE_CODE[value] or "")
				editor.setEditable(false)
			end
		end,
	})

	tab:AddButton("Create Module", function()
		local name = nameInput.Value
		if not name or #name <= 0 then
			return Logger.longNotify("Enter a module name.")
		end
		name = name:gsub("%.lua$", "")
		if ModuleManager.fileExists(name) then
			return Logger.longNotify("Module '%s' already exists.", name)
		end
		local template = TEMPLATE_CODE[templateDrop.Value] or ""
		if not ModuleManager.writeFile(name, template) then
			return Logger.longNotify("Failed to create module '%s'.", name)
		end
		Logger.notify("Created module '%s'.", name)
		rebuild()
		ModuleManager.refresh()
		list:SetValue(name)
		list:Display()
		-- Now editing the newly-created module -> editable again.
		editor.setEditable(true)
		editor.set(template)
	end)

	tab:AddDivider()

	editor = createCodeEditor(tab, 320)
	TimingBuilderTab._refreshModulesList = rebuild
	rebuild()
end

---@param window table
function TimingBuilderTab.init(window)
	-- Builder tab is available to everyone (no Luarmor note required).
	pcall(TimingBuilderTab.ensurePersistence)

	local tab = window:AddTab("Builder", "Combat", Icons.Builder)

	local tabbox = tab:AddFullTabbox()

	TimingBuilderTab.initGeneral(tabbox:AddTab("General"))
	TimingBuilderTab.initCreate(tabbox:AddTab("Create Timing"))
	TimingBuilderTab.initEdit(tabbox:AddTab("Edit Timing"))
	TimingBuilderTab.initModules(tabbox:AddTab("Modules"))
end

function TimingBuilderTab.detach() end

return TimingBuilderTab