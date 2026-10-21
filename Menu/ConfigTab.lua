local ConfigTab = {}

---@module GUI.Icons
local Icons = require("GUI/Icons")

---@module GUI.SaveManager
local SaveManager = require("GUI/SaveManager")

---@param window table
function ConfigTab.init(window)
	local tab = window:AddTab("Config", "Settings", Icons.Builder)

	SaveManager:BuildConfigSection(tab)
end

return ConfigTab