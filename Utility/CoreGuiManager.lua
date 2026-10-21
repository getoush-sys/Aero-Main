---@note: We need to be careful where we use CoreGui because exploits have this weird permission issue. We need consistent setting of the parent.
---@note: All scripts that must access this module should require it at the top of the file where it gets loaded.
local CoreGuiManager = {}

local instances = {}

---@param instance Instance
---@return Instance
function CoreGuiManager.imark(instance)
	instances[#instances + 1] = instance
	return instance
end

---@return table
function CoreGuiManager.set()
	local coreGui = game:GetService("CoreGui")

	for _, instance in next, instances do
		instance.Parent = coreGui
	end

	return instances
end

function CoreGuiManager.clear()
	for _, instance in next, instances do
		instance:Destroy()
	end

	instances = {}
end

return CoreGuiManager
