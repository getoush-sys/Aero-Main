local UtilityTab = {}

---@module GUI.Icons
local Icons = require("GUI/Icons")

---@param window table
function UtilityTab.init(window)
	local GameTab = require("Menu/GameTab")
	local VisualsTab = require("Menu/VisualsTab")
	local ExploitTab = require("Menu/ExploitTab")

	local tab = window:AddTab("Utility", "Utility", Icons.Exploit)

	local tabbox = tab:AddFullTabbox()

	GameTab.initMovementSection(tabbox:AddTab("Movement"))

	local exploitsTab = tabbox:AddTab("Exploits")
	ExploitTab.initMobExploitsSection(exploitsTab)
	ExploitTab.initLocalCharacterExploitsSection(exploitsTab)
	VisualsTab.initMorphLoaderSection(exploitsTab)

	local realmOk = true
	pcall(function()
		local replicatedStorage = game:GetService("ReplicatedStorage")
		local info = replicatedStorage:WaitForChild("Info", 5)
		local realmInfo = info and info:WaitForChild("RealmInfo", 5)
		local currentWorld = (realmInfo and require(realmInfo).CurrentWorld) or "N/A"
		if currentWorld == "Depths" or currentWorld == "Mission" or currentWorld == "Dungeon" then
			realmOk = false
		end
	end)
	if realmOk then
		ExploitTab.initTeleportsSection(tabbox)
	end

	GameTab.initPlayerMonitoringSection(tabbox:AddTab("Monitoring"))

	GameTab.initInfoSpoofingSection(tabbox:AddTab("Info"))

	local trackersTab = tabbox:AddTab("Trackers")
	VisualsTab.initVisualAssistanceSection(trackersTab)
	GameTab.initRevealAnimationsSection(trackersTab)

	local worldTab = tabbox:AddTab("World")
	VisualsTab.initWorldVisualsSection(worldTab)
	GameTab.initEffectRemovalsSection(worldTab)
	GameTab.initInstanceRemovalsSection(worldTab)
	VisualsTab.initVisualRemovalsSection(worldTab)
	GameTab.initTweeningSection(worldTab)
end

return UtilityTab