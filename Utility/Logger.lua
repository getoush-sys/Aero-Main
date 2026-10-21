return LPH_NO_VIRTUALIZE(function()
	local Logger = {}
	Logger.__index = Logger

	---@module GUI.Library
	local Library = require("GUI/Library")

	---@module Utility.Configuration
	local Configuration = require("Utility/Configuration")

	---@param str string
	---@return function
	function Logger.mnnotify(str, ...)
		return Library:ManuallyManagedNotify(string.format(str, ...))
	end

	---@param str string
	function Logger.qnotify(str, ...)
		local quickNotificationSpeed = Configuration.expectOptionValue("QuickNotificationSpeed") or 0.5
		Library:Notify(string.format(str, ...), quickNotificationSpeed)
	end

	---@param str string
	function Logger.notify(str, ...)
		Library:Notify(string.format(str, ...), 3.0)
	end

	---@param str string
	function Logger.longNotify(str, ...)
		Library:Notify(string.format(str, ...), 30.0)
	end

	-- warn/trace are no-ops. They used to emit "[Aero Recode]"-prefixed lines to the Roblox LogService
	-- (via warn/print), which the anticheat exfiltrates from GetLogHistory and bans on. Kept as empty
	-- functions so every existing call site is a cheap no-op. Notifications (notify/qnotify/longNotify/
	-- mnnotify) still work -- they go to Aero's own UI, never LogService.
	---@param str string
	function Logger.warn(str, ...) end

	---@param str string
	function Logger.trace(str, ...) end

	return Logger
end)()
