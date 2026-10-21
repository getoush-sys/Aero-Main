---@class DodgeOptions
---@field rollCancel boolean
---@field rollCancelDelay number
---@field direct boolean
---@field actionRolling boolean
---@field full boolean
local DodgeOptions = {}
DodgeOptions.__index = DodgeOptions

function DodgeOptions.new()
	local self = setmetatable({}, DodgeOptions)
	self.rollCancel = false
	self.rollCancelDelay = 0.0
	self.direct = false
	self.actionRolling = false
	self.full = false
	return self
end

return DodgeOptions
