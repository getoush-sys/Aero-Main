---@class Action
local Action = getfenv().Action

---Get ParticleEmitter inside ChargeAttachment on entity's HumanoidRootPart.
---@param entity Model
---@return ParticleEmitter?
local function getChargeEmitter(entity)
	local hrp = entity:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local attachment = hrp:FindFirstChild("ChargeAttachment")
	if not attachment then
		return
	end

	return attachment:FindFirstChildOfClass("ParticleEmitter")
end

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	local emitter = nil

	-- Wait until ChargeAttachment and its emitter appear on the entity.
	repeat
		task.wait()

		if not self.entity or not self.entity.Parent then
			return
		end

		emitter = getChargeEmitter(self.entity)
	until emitter

	local action = Action.new()
	action._when = 0
	action._type = "Parry"
	action.ihbc = true
	action.name = string.format("(%.6f - %.6f) Rushdown Timing", emitter.Speed.Min, emitter.Speed.Max)
	return self:action(timing, action)
end
