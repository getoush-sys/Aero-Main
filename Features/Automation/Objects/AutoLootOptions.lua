---@class AutoLootOptions
---@field smin number Minimum stars to loot.
---@field smax number Maximum stars to loot.
---@field wanted string[] List of wanted item names.
---@field lall boolean Whether to loot everything.
---@field always string[] Item names always looted regardless of the star filter.
local AutoLootOptions = {}

---@param smin number Minimum stars to loot.
---@param smax number Maximum stars to loot.
---@param wanted string[] List of wanted item names.
---@param lall boolean Whether to loot everything.
---@param always string[]? Item names always looted regardless of the star filter.
---@return AutoLootOptions
function AutoLootOptions.new(smin, smax, wanted, lall, always)
	local self = setmetatable({}, AutoLootOptions)
	self.smin = smin
	self.smax = smax
	self.wanted = wanted
	self.lall = lall
	self.always = always or {}
	return self
end

return AutoLootOptions
