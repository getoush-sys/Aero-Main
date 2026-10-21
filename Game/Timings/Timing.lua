---@module Game.Timings.ActionContainer
local ActionContainer = require("Game/Timings/ActionContainer")

---@class Timing
---@field name string
---@field tag string
---@field imdd number Initial minimum distance from position.
---@field imxd number Initial maximum distance from position.
---@field punishable number Punishable window in seconds.
---@field after number After window in seconds.
---@field duih boolean Delay until in hitbox.
---@field actions ActionContainer
---@field hitbox Vector3
---@field umoa boolean Use module over actions.
---@field smn boolean Skip module notification.
---@field srpn boolean Skip repeat notification.
---@field smod string Selected module string.
---@field aatk boolean Allow attacking.
---@field fhb boolean Hitbox facing offset.
---@field hso number Hitbox shift offset. This offset is applied backwards. Positive is backwards, negative is forwards.
---@field ndfb boolean No dash fallback.
---@field cbm boolean A non-saved field to indicate whether this was non-part-timing created by a module.
---@field nvfb boolean No vent fallback.
---@field bfht number Block fallback hold time.
---@field pbfb boolean Prefer block fallback.
---@field forced boolean Hidden field which allows us to force tasks to go through.
---@field htype Enum.PartType Shape of hitbox. Never accessible unless inside of a module or inside of real code. This is never serialized.
---@field rpue boolean Prefer repeat usage.
---@field _rsd number Repeat start delay in milliseconds. Use :rsd() for seconds.
---@field _rpd number Repeat parry delay in milliseconds. Use :rpd() for seconds.
---@field nbfb boolean No block fallback.
---@field ibi boolean Ignore block input gate for this timing.
---@field iapf boolean Ignore auto parry frames for this timing.
---@field uif boolean Use the inhale cue to identify a feint. When set, a pending reaction to this timing is cancelled if the inhale feint sound plays from the same attacker.
---@field nfd boolean Ignore feint detection for this timing. For moves whose animation naturally ends before the real hit lands, this makes auto defense treat the move as never-stopped instead of canceling the parry as a feint.
---@field rsc boolean Skip this timing if the local player recently played 'rsaid' themselves.
---@field rsaid string Animation ID to watch for local self-casts.
---@field rsaw number Recent self-cast window in seconds.
local Timing = {}
Timing.__index = Timing

---@return number
function Timing:rsd()
	return self._rsd / 1000
end

---@return number
function Timing:rpd()
	return self._rpd / 1000
end

---@return string
function Timing:id()
	return self.name
end

---@param id string
function Timing:set(id)
	self.name = id
end

---@param values table
function Timing:load(values)
	if typeof(values.name) == "string" then
		self.name = values.name
	end

	if typeof(values.tag) == "string" then
		self.tag = values.tag
	end

	if typeof(values.imdd) == "number" then
		self.imdd = values.imdd
	end

	if typeof(values.imxd) == "number" then
		self.imxd = values.imxd
	end

	if typeof(values.duih) == "boolean" then
		self.duih = values.duih
	end

	if typeof(values.punishable) == "number" then
		self.punishable = values.punishable
	end

	if typeof(values.after) == "number" then
		self.after = values.after
	end

	if typeof(values.actions) == "table" then
		self.actions:load(values.actions)
	end

	if typeof(values.smn) == "boolean" then
		self.smn = values.smn
	end

	if typeof(values.hitbox) == "table" then
		self.hitbox = Vector3.new(values.hitbox.X or 0, values.hitbox.Y or 0, values.hitbox.Z or 0)
	end

	if typeof(values.umoa) == "boolean" then
		self.umoa = values.umoa
	end

	if typeof(values.srpn) == "boolean" then
		self.srpn = values.srpn
	end

	if typeof(values.smod) == "string" then
		self.smod = values.smod
	end

	if typeof(values.aatk) == "boolean" then
		self.aatk = values.aatk
	end

	if typeof(values.fhb) == "boolean" then
		self.fhb = values.fhb
	end

	if typeof(values.hso) == "number" then
		self.hso = values.hso
	end

	if typeof(values.ndfb) == "boolean" then
		self.ndfb = values.ndfb
	end

	if typeof(values.nvfb) == "boolean" then
		self.nvfb = values.nvfb
	end

	if typeof(values.bfht) == "number" then
		self.bfht = values.bfht
	end

	if typeof(values.rsd) == "string" then
		self._rsd = tonumber(values.rsd) or 0.0
	end

	if typeof(values.rpd) == "string" then
		self._rpd = tonumber(values.rpd) or 0.0
	end

	if typeof(values.rsd) == "number" then
		self._rsd = values.rsd
	end

	if typeof(values.rpd) == "number" then
		self._rpd = values.rpd
	end

	if typeof(values.rpue) == "boolean" then
		self.rpue = values.rpue
	end

	if typeof(values.nbfb) == "boolean" then
		self.nbfb = values.nbfb
	end

	if typeof(values.ibi) == "boolean" then
		self.ibi = values.ibi
	end

	if typeof(values.iapf) == "boolean" then
		self.iapf = values.iapf
	end

	if typeof(values.uif) == "boolean" then
		self.uif = values.uif
	end

	if typeof(values.rsc) == "boolean" then
		self.rsc = values.rsc
	end

	if typeof(values.rsaid) == "string" then
		self.rsaid = values.rsaid
	end

	if typeof(values.rsaw) == "number" then
		self.rsaw = values.rsaw
	end
end

---@param other Timing
---@return boolean
function Timing:equals(other)
	if self.name ~= other.name then
		return false
	end

	if self.tag ~= other.tag then
		return false
	end

	if self.imdd ~= other.imdd then
		return false
	end

	if self.imxd ~= other.imxd then
		return false
	end

	if self.duih ~= other.duih then
		return false
	end

	if self.punishable ~= other.punishable then
		return false
	end

	if self.after ~= other.after then
		return false
	end

	if not self.actions:equals(other.actions) then
		return false
	end

	if self.smn ~= other.smn then
		return false
	end

	if self.hitbox ~= other.hitbox then
		return false
	end

	if self.umoa ~= other.umoa then
		return false
	end

	if self.hso ~= other.hso then
		return false
	end

	if self.srpn ~= other.srpn then
		return false
	end

	if self.smod ~= other.smod then
		return false
	end

	if self.aatk ~= other.aatk then
		return false
	end

	if self.fhb ~= other.fhb then
		return false
	end

	if self.ndfb ~= other.ndfb then
		return false
	end

	if self.nvfb ~= other.nvfb then
		return false
	end

	if self.bfht ~= other.bfht then
		return false
	end

	if self.rpue ~= other.rpue then
		return false
	end

	if self._rsd ~= other._rsd then
		return false
	end

	if self._rpd ~= other._rpd then
		return false
	end

	if self.nbfb ~= other.nbfb then
		return false
	end

	if self.ibi ~= other.ibi then
		return false
	end

	if self.iapf ~= other.iapf then
		return false
	end

	if self.uif ~= other.uif then
		return false
	end

	if self.rsc ~= other.rsc then
		return false
	end

	if self.rsaid ~= other.rsaid then
		return false
	end

	if self.rsaw ~= other.rsaw then
		return false
	end

	return true
end

---@return Timing
function Timing:clone()
	local clone = Timing.new()

	clone.name = self.name
	clone.tag = self.tag
	clone.duih = self.duih
	clone.imdd = self.imdd
	clone.imxd = self.imxd
	clone.smn = self.smn
	clone.punishable = self.punishable
	clone.after = self.after
	clone.actions = self.actions:clone()
	clone.hitbox = self.hitbox
	clone.umoa = self.umoa
	clone.srpn = self.srpn
	clone.smod = self.smod
	clone.aatk = self.aatk
	clone.fhb = self.fhb
	clone.ndfb = self.ndfb
	clone.hso = self.hso
	clone.nvfb = self.nvfb
	clone.bfht = self.bfht
	clone.rpue = self.rpue
	clone._rsd = self._rsd
	clone._rpd = self._rpd
	clone.nbfb = self.nbfb
	clone.ibi = self.ibi
	clone.iapf = self.iapf
	clone.uif = self.uif
	clone.rsc = self.rsc
	clone.rsaid = self.rsaid
	clone.rsaw = self.rsaw

	return clone
end

---@return table
function Timing:serialize()
	return {
		name = self.name,
		tag = self.tag,
		imdd = self.imdd,
		imxd = self.imxd,
		duih = self.duih,
		punishable = self.punishable,
		smn = self.smn,
		after = self.after,
		actions = self.actions:serialize(),
		hitbox = {
			X = self.hitbox.X,
			Y = self.hitbox.Y,
			Z = self.hitbox.Z,
		},
		srpn = self.srpn,
		umoa = self.umoa,
		smod = self.smod,
		aatk = self.aatk,
		fhb = self.fhb,
		ndfb = self.ndfb,
		phd = self.phd,
		pfh = self.pfh,
		hso = self.hso,
		nvfb = self.nvfb,
		bfht = self.bfht,
		rpue = self.rpue,
		rsd = self._rsd,
		rpd = self._rpd,
		nbfb = self.nbfb,
		ibi = self.ibi,
		iapf = self.iapf,
		uif = self.uif,
		rsc = self.rsc,
		rsaid = self.rsaid,
		rsaw = self.rsaw,
	}
end

---@param values table?
---@return Timing
function Timing.new(values)
	local self = setmetatable({}, Timing)

	self.tag = "Undefined"
	self.name = "N/A"
	self.imdd = 0
	self.imxd = 0
	self.smn = false
	self.punishable = 0
	self.after = 0
	self.rpue = false
	self._rsd = 0
	self._rpd = 0
	self.duih = false
	self.actions = ActionContainer.new()
	self.hitbox = Vector3.zero
	self.umoa = false
	self.srpn = false
	self.smod = "N/A"
	self.aatk = false
	self.fhb = true
	self.ndfb = false
	self.hso = 0
	self.nvfb = false
	self.bfht = 0.3
	self.nbfb = false
	self.ibi = false
	self.iapf = false
	self.uif = false
	self.rsc = false
	self.rsaid = ""
	self.rsaw = 4.0

	if values then
		self:load(values)
	end

	return self
end

return Timing
