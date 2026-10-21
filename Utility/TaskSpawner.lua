local TaskSpawner = {}

---@module Utility.Profiler
local Profiler = require("Utility/Profiler")

---@module Utility.Logger
local Logger = require("Utility/Logger")

local RunService = game:GetService("RunService")

---@param label string
---@param delay function
---@param callback function
---@vararg any
function TaskSpawner.delay(label, delay, callback, ...)
	---@param error string
	local function onTaskFunctionError(error)
		Logger.trace("onTaskFunctionError - (%s) - %s", label, error)
	end

	local taskFunction = Profiler.wrap(
		label,
		LPH_NO_VIRTUALIZE(function(...)
			local timestamp = os.clock()

			while os.clock() - timestamp < delay() do
				RunService.RenderStepped:Wait()
			end

			return xpcall(callback, onTaskFunctionError, ...)
		end)
	)

	return task.spawn(taskFunction, ...)
end

---@param label string
---@param callback function
---@vararg any
function TaskSpawner.spawn(label, callback, ...)
	---@param error string
	local function onTaskFunctionError(error)
		Logger.trace("onTaskFunctionError - (%s) - %s", label, error)
	end

	local taskFunction = Profiler.wrap(
		label,
		LPH_NO_VIRTUALIZE(function(...)
			return xpcall(callback, onTaskFunctionError, ...)
		end)
	)

	return task.spawn(taskFunction, ...)
end

return TaskSpawner
