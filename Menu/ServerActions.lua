local ServerActions = {}

---@module Game.ServerHop
local ServerHop = require("Game/ServerHop")

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Utility.Logger
local Logger = require("Utility/Logger")

local players = game:GetService("Players")

---@param tab table
function ServerActions.init(tab)
	tab:AddButton({
		Text = "Serverhop",
		DoubleClick = true,
		Tooltip = "Click twice to join another server.",
		Func = function()
			local player = players.LocalPlayer
			local slot = player and player:GetAttribute("DataSlot")
			if type(slot) ~= "string" or slot == "" then
				slot = PersistentData.get("shslot")
			end
			if type(slot) ~= "string" or slot == "" then
				Logger.warn("Serverhop failed: no data slot is selected.")
				return
			end

			local ok, err = pcall(ServerHop.hop, slot, true)
			if not ok then
				Logger.warn("Serverhop failed:", tostring(err))
			end
		end,
	})
end

return ServerActions
