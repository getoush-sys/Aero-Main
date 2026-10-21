---@module Features.Visuals.Objects.EntityESP
local EntityESP = require("Features/Visuals/Objects/EntityESP")

---@class MobESP: EntityESP
local MobESP = setmetatable({}, { __index = EntityESP })
MobESP.__index = MobESP
MobESP.__type = "MobESP"

local ESP_HEALTH = "[%i/%i]"

---@param self MobESP
MobESP.update = LPH_NO_VIRTUALIZE(function(self)
	local humanoid = self._cachedHumanoid
	if not humanoid or not humanoid.Parent then
		humanoid = self.entity:FindFirstChildOfClass("Humanoid")
		self._cachedHumanoid = humanoid
	end
	if not humanoid then
		return self:visible(false)
	end

	EntityESP.update(self, { ESP_HEALTH:format(humanoid.Health, humanoid.MaxHealth) })
end)

---@param identifier string
---@param model Model
---@param label string
function MobESP.new(identifier, model, label)
	local self = setmetatable(EntityESP.new(model, identifier, label), MobESP)
	self:setup()
	self:build()
	self:update()
	return self
end

return MobESP
