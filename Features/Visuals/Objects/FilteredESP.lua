---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@class FilteredESP
---@note: This is a wrapper object.
---@field object ModelESP|PartESP
---@field identifier string
---@field delayTimestamp number?
local FilteredESP = {}
FilteredESP.__index = FilteredESP
FilteredESP.__type = "FilteredESP"

---@param visible boolean
function FilteredESP:visible(visible)
	self.object:visible(visible)
end

function FilteredESP:detach()
	self.object:detach()
end

---@param self FilteredESP
FilteredESP.update = LPH_NO_VIRTUALIZE(function(self)
	local object = self.object
	local identifier = self.identifier
	local label = object.label

	if Configuration.idToggleValue(identifier, "FilterObjects") then
		local hiddenLabels = Configuration.idOptionValue(identifier, "FilterLabelList")

		if hiddenLabels and hiddenLabels[label] then
			return self:visible(false)
		end
	end

	object:update()

	self.delayTimestamp = object.delayTimestamp
end)

---@param object ModelESP|PartESP
function FilteredESP.new(object)
	local self = setmetatable({}, FilteredESP)
	self.object = object
	self.identifier = object.identifier
	self.delayTimestamp = object.delayTimestamp
	return self
end

return FilteredESP
