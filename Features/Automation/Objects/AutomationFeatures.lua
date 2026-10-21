-- AutomationFeatures: Aero-native implementations of project-rain-oss's feature system, used by
-- AutomationStruct. Each feature is created with `AutomationFeatures.create(name, struct)` and exposes
-- `:enable()`, `:disable()`, and (where relevant) `.current_connection`, matching how the PR task files
-- reach into `struct.active_features['mob_ai_breaker'].current_connection`.
--
-- Per the port decision: features that Aero already ships as menu toggles (fly, noclip, no_fall, auto_loot)
-- just drive those toggles (captured + restored). The rest (mob_ai_breaker, jesus, no_one_bit,
-- auto_equip_weapon) are implemented natively here, faithful to PR's behavior.
local AutomationFeatures = {}

---@module Game.InputClient
local InputClient = require("Game/InputClient")

---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")

---@module GUI.Library
local Library = require("GUI/Library")

---@module Utility.Finder
local Finder = require("Utility/Finder")

---@module Features.Automation.Objects.AutoLog
local AutoLog = require("Features/Automation/Objects/AutoLog")

local players = game:GetService("Players")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local EASTERN_PLACE_ID = 6473861193
local TITUS_PLACE_ID = 8668476218

-- Cached require of the game's EffectReplicator (HasEffect / FindEffect / CreateEffect / .Passives).
local effectReplicator = nil
local function getER()
	if effectReplicator then
		return effectReplicator
	end
	pcall(function()
		effectReplicator = require(replicatedStorage:WaitForChild("EffectReplicator"))
		if effectReplicator and effectReplicator.WaitForContainer then
			pcall(function()
				effectReplicator:WaitForContainer()
			end)
		end
	end)
	return effectReplicator
end

local function char()
	return players.LocalPlayer and players.LocalPlayer.Character
end

local function root()
	local c = char()
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- ---------------------------------------------------------------------------------------------------------
-- Toggle-mapped features. enable() captures the user's current value then forces true; disable() restores.
-- ---------------------------------------------------------------------------------------------------------

---@param toggleName string
local function makeToggleFeature(toggleName)
	return function(_name, struct)
		local feat = { name = _name, _prev = nil }

		function feat:enable()
			local deadline = os.clock() + 30
			local toggle
			repeat
				toggle = Toggles and Toggles[toggleName]
				if toggle or (struct and not struct:has_any()) then
					break
				end
				task.wait(0.1)
			until os.clock() >= deadline

			if not toggle then
				if not struct or struct:has_any() then
					warn(string.format("[AutomationStruct] toggle %s was unavailable after 30 seconds", toggleName))
				end
				return
			end
			self._prev = toggle.Value
			toggle:SetValue(true)
		end

		function feat:disable()
			local toggle = Toggles and Toggles[toggleName]
			if toggle and self._prev ~= nil then
				toggle:SetValue(self._prev)
			end
			self._prev = nil
		end

		return feat
	end
end

-- ---------------------------------------------------------------------------------------------------------
-- mob_ai_breaker: PR's Titus kill mechanism. Every Heartbeat, slam the root's velocity straight down
-- (Vector3.new(0, -9e9, 0)); every PreRender, restore the pre-slam velocity so the character doesn't
-- actually fall. This desyncs / breaks the boss's AI + physics targeting. NOT an m1 farm.
-- ---------------------------------------------------------------------------------------------------------
local function makeMobAiBreaker(name, struct)
	local feat = { name = name, current_connection = nil, pre_ren = nil }
	local lastVel = nil

	function feat:enable()
		self.current_connection = runService.Heartbeat:Connect(function()
			local r = root()
			if not r then
				return
			end
			lastVel = r.AssemblyLinearVelocity
			r.AssemblyLinearVelocity = Vector3.new(0, -9e9, 0)
		end)

		self.pre_ren = runService.PreRender:Connect(function()
			if lastVel then
				local r = root()
				if r then
					r.AssemblyLinearVelocity = lastVel
				end
				lastVel = nil
			end
		end)
	end

	function feat:disable()
		if self.current_connection then
			pcall(function()
				self.current_connection:Disconnect()
			end)
			self.current_connection = nil
		end
		if self.pre_ren then
			pcall(function()
				self.pre_ren:Disconnect()
			end)
			self.pre_ren = nil
		end
		if lastVel then
			local r = root()
			if r then
				r.AssemblyLinearVelocity = lastVel
			end
			lastVel = nil
		end
	end

	return feat
end

-- ---------------------------------------------------------------------------------------------------------
-- jesus: anti-water-death. Parents an invisible 2048x2048 floor at Y=-3 under the player and keeps the
-- "NoSwim" effect applied so the game never forces a swim/drown state. Only active in the merit + dungeon
-- places (the phases where the farm skims over water), matching PR's is_eastern/is_etrean gate.
-- ---------------------------------------------------------------------------------------------------------
local function makeJesus(name, struct)
	local feat = { name = name, current_connection = nil, part = nil }

	function feat:enable()
		if not self.part then
			self.part = Instance.new("Part")
			self.part.Transparency = 1
			self.part.Size = Vector3.new(2048, 1, 2048)
			self.part.Anchored = true
			self.part.CanCollide = false
			self.part.Position = Vector3.new(0, 0, 0)
			self.part.Name = "FakeWater"
		end

		self.current_connection = runService.Heartbeat:Connect(function()
			local placeId = game.PlaceId
			if placeId ~= EASTERN_PLACE_ID and placeId ~= TITUS_PLACE_ID then
				if self.part.Parent then
					self.part.Parent = nil
				end
				return
			end
			local r = root()
			if not r then
				return
			end
			if self.part.Parent ~= workspace then
				self.part.Parent = workspace
			end
			self.part.CFrame = CFrame.new(r.Position.X, -3, r.Position.Z)

			pcall(function()
				local er = getER()
				if er and not er:HasEffect("NoSwim") then
					er:CreateEffect("NoSwim")
				end
			end)
		end)
	end

	function feat:disable()
		if self.current_connection then
			pcall(function()
				self.current_connection:Disconnect()
			end)
			self.current_connection = nil
		end
		if self.part then
			pcall(function()
				self.part:Destroy()
			end)
			self.part = nil
		end
		pcall(function()
			local er = getER()
			if er and er.FindEffect then
				local effect = er:FindEffect("NoSwim")
				if effect and effect.Debris then
					effect:Debris(0.1)
				end
			end
		end)
	end

	return feat
end

-- ---------------------------------------------------------------------------------------------------------
-- no_one_bit: strips the "OneBit" passive (the flaw that one-shots you when you'd otherwise survive a
-- lethal hit) from EffectReplicator.Passives so a freshly-rolled character can't die to it. PR does this
-- via an ssv_parser that just mutates EffectReplicator.Passives[name]; ported directly.
-- ---------------------------------------------------------------------------------------------------------
local function makeNoOneBit(name, struct)
	local feat = { name = name, running = false, removed = false }

	function feat:enable()
		self.running = true
		task.spawn(function()
			while self.running do
				pcall(function()
					local er = getER()
					if er and er.Passives then
						if er.Passives["OneBit"] then
							self.removed = true
						end
						er.Passives["OneBit"] = nil
					end
				end)
				task.wait(1)
			end
		end)
	end

	function feat:disable()
		self.running = false
		if self.removed then
			pcall(function()
				local er = getER()
				if er and er.Passives then
					er.Passives["OneBit"] = true
				end
			end)
			self.removed = false
		end
	end

	return feat
end

-- ---------------------------------------------------------------------------------------------------------
-- auto_equip_weapon: keeps the weapon drawn. Whenever the "Equipped" effect is absent, fire the
-- CharacterHandler DrawWeapon remote. Faithful to PR's poll loop (its EffectReplicatorHandler:hook is a
-- latency optimization Aero has no equivalent for; the 1s poll is the core behavior).
-- ---------------------------------------------------------------------------------------------------------
local function makeAutoEquipWeapon(name, struct)
	local feat = { name = name, running = false }

	local function isUsingUtilityTool()
		local c = char()
		if not c then
			return false
		end
		return c:FindFirstChildOfClass("Tool") ~= nil
	end

	local function drawWeapon()
		if isUsingUtilityTool() then
			return
		end
		local c = char()
		local handler = c and c:FindFirstChild("CharacterHandler")
		local requests = handler and handler:FindFirstChild("Requests")
		local remote = requests and requests:FindFirstChild("DrawWeapon")
		if remote then
			pcall(function()
				remote:FireServer(true)
			end)
		end
	end

	function feat:enable()
		self.running = true
		task.spawn(function()
			while self.running do
				local er = getER()
				if not (er and er:FindEffect("Equipped")) then
					drawWeapon()
				end
				task.wait(1)
			end
		end)
	end

	function feat:disable()
		self.running = false
	end

	return feat
end

-- ---------------------------------------------------------------------------------------------------------
-- m1_hold: PR's held-m1 feature. While `.held` is true, repeatedly throw a left-click (m1) via Aero's
-- InputClient. Tasks flip `struct.active_features.m1_hold.held` on/off around the moments they want to swing.
-- ---------------------------------------------------------------------------------------------------------
local function makeM1Hold(name, struct)
	local feat = { name = name, held = false, running = false }

	function feat:enable()
		self.running = true
		task.spawn(function()
			while self.running do
				if self.held then
					local c = char()
					local r = c and c:FindFirstChild("HumanoidRootPart")
					if r then
						pcall(function()
							-- ignoreChecks + forceGround: PR's m1_hold swings on cooldown with no_aerials on.
							InputClient.left(r.CFrame, true, true)
						end)
					end
				end
				task.wait(0.1)
			end
		end)
	end

	function feat:disable()
		self.running = false
		self.held = false
	end

	return feat
end

-- ---------------------------------------------------------------------------------------------------------
-- mod_detector: hop away if a Deepwoken Staff member joins the server. PR checks a static member map first;
-- here we do PR's live fallback (GetRankInGroup on the staff group) for every player, which needs no data.
-- ---------------------------------------------------------------------------------------------------------
local STAFF_GROUP_ID = 5212858
local function makeModDetector(name, struct)
	local feat = { name = name, running = false, conn = nil }

	local function check(player)
		if player == players.LocalPlayer then
			return
		end
		task.spawn(function()
			local rank = 0
			pcall(function()
				rank = player:GetRankInGroup(STAFF_GROUP_ID)
			end)
			if rank and rank > 0 and feat.running then
				pcall(function()
					if Library and Library.NotifyWithSound then
						Library:NotifyWithSound(string.format("%s is in the Deepwoken Staff group -- hopping.", player.Name), 15)
					end
				end)
				if struct:has_any() then
					local slot = players.LocalPlayer and players.LocalPlayer:GetAttribute("DataSlot")
					pcall(function()
						ServerHop.hop(slot, true)
					end)
				end
			end
		end)
	end

	function feat:enable()
		self.running = true
		self.conn = players.PlayerAdded:Connect(check)
		task.delay(0.25, function()
			for _, p in ipairs(players:GetPlayers()) do
				check(p)
			end
		end)
	end

	function feat:disable()
		self.running = false
		if self.conn then
			pcall(function()
				self.conn:Disconnect()
			end)
			self.conn = nil
		end
	end

	return feat
end

-- ---------------------------------------------------------------------------------------------------------
-- fast_swing: remove the attack-cooldown effects (LightAttack/HeavyAttack/etc.) the instant they're added,
-- so swings aren't rate-limited client-side. Direct port of PR's fast_swing (EffectReplicator "added" hook
-- -> effect:Remove(true)).
-- ---------------------------------------------------------------------------------------------------------
local FAST_SWING_CLASSES = { "OffhandAttack", "HeavyAttack", "MediumAttack", "LightAttack", "UsingSpell" }
local function makeFastSwing(name, struct)
	local feat = { name = name, running = false, conn = nil }

	function feat:enable()
		self.running = true
		task.spawn(function()
			local er = getER()
			if not self.running or not er or not er.EffectAdded then
				return
			end
			self.conn = er.EffectAdded:Connect(function(effect)
				if effect and effect.Class and table.find(FAST_SWING_CLASSES, effect.Class) then
					task.defer(function()
						pcall(function()
							effect:Remove(true)
						end)
					end)
				end
			end)
		end)
	end

	function feat:disable()
		self.running = false
		if self.conn then
			pcall(function()
				self.conn:Disconnect()
			end)
			self.conn = nil
		end
	end

	return feat
end

-- ---------------------------------------------------------------------------------------------------------
-- auto_log: Ferryman-style anti-detection. Hop the moment another player comes within the automation's
-- auto-log distance (per-automation AutoLog store, adjustable 0-2000 in the menu; 0 = off). Skipped during
-- character creation (lobby players would softlock the creator).
-- ---------------------------------------------------------------------------------------------------------
local function makeAutoLog(name, struct)
	local feat = { name = name, running = false }

	function feat:enable()
		self.running = true
		task.spawn(function()
			while self.running do
				task.wait(1)
				if not self.running then
					break
				end
				local cc = workspace:FindFirstChild("CharacterCreator")
				local c = char()
				if cc and c and c.Parent == cc then
					-- character creation; don't hop
				else
					local r = c and c:FindFirstChild("HumanoidRootPart")
					local dist = AutoLog.get(struct and struct.id)
					if r and dist > 0 and Finder.pnear(r.Position, dist) then
						if struct:has_any() then
							local slot = players.LocalPlayer and players.LocalPlayer:GetAttribute("DataSlot")
							pcall(function()
								ServerHop.hop(slot, true)
							end)
						end
						return
					end
				end
			end
		end)
	end

	function feat:disable()
		self.running = false
	end

	return feat
end

-- ---------------------------------------------------------------------------------------------------------
-- Registry.
-- ---------------------------------------------------------------------------------------------------------
local constructors = {
	fly = makeToggleFeature("Fly"),
	noclip = makeToggleFeature("NoClip"),
	no_fall = makeToggleFeature("NoFallDamage"),
	auto_loot = makeToggleFeature("AutoLoot"),
	no_kill_bricks = makeToggleFeature("NoKillBricks"),
	no_fire = makeToggleFeature("AutoExtinguishFire"),
	no_stun = makeToggleFeature("NoStun"),
	fast_swing = makeFastSwing,
	mob_ai_breaker = makeMobAiBreaker,
	jesus = makeJesus,
	no_one_bit = makeNoOneBit,
	auto_equip_weapon = makeAutoEquipWeapon,
	m1_hold = makeM1Hold,
	mod_detector = makeModDetector,
	auto_log = makeAutoLog,
	-- auto_wisp maps to Aero's AutoWisp toggle.
	auto_wisp = makeToggleFeature("AutoWisp"),
}

---Create a feature object for `name`, bound to `struct`. Returns nil if the name is unknown.
---@param name string
---@param struct table
---@return table?
function AutomationFeatures.create(name, struct)
	local ctor = constructors[name]
	if not ctor then
		return nil
	end
	return ctor(name, struct)
end

return AutomationFeatures
