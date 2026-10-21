---@class Signal
---@field signal RBXScriptSignal Underlying roblox script signal
local Signal = {}
Signal.__index = Signal

---@module Utility.Profiler
local Profiler = require("Utility/Profiler")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@param label string
---@param eventFunction function
---@return RBXScriptConnection
function Signal:connect(label, eventFunction)
	---@param error string
	local function onEventFunctionError(error)
		Logger.trace("onEventFunctionError - (%s) - %s", label, error)
	end

	local connection = self.signal:Connect(Profiler.wrap(
		label,
		LPH_NO_VIRTUALIZE(function(...)
			return xpcall(eventFunction, onEventFunctionError, ...)
		end)
	))

	return connection
end

---@param robloxSignal RBXScriptSignal
---@return Signal
function Signal.new(robloxSignal)
	local self = setmetatable({}, Signal)
	self.signal = robloxSignal

	return self
end

return Signal
