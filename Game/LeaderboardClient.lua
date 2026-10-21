local LeaderboardClient = { calling = false }

local players = game:GetService("Players")

local cachedUpvaluesTable = nil
local cachedUpvaluesFunction = nil
local lastDataCacheTime = os.clock()
local lastFunctionCacheTime = os.clock()

---@param func function?
---@return boolean
local function filterFunction(func)
	if not func or not islclosure(func) then
		return false
	end

	local info = debug.getinfo(func)
	if info.name ~= nil and info.name ~= "" then
		return false
	end

	local constants = debug.getconstants(func)
	if #constants ~= 1 or constants[1] ~= "Destroy" then
		return false
	end

	local upvalues = debug.getupvalues(func)
	if not upvalues then
		return false
	end

	return true
end

---@return function?
function LeaderboardClient.glrf()
	if cachedUpvaluesFunction and os.clock() - lastFunctionCacheTime <= 2.0 then
		return cachedUpvaluesFunction
	end

	for _, con in next, getconnections(players.PlayerRemoving) do
		local func = con.Function
		if not filterFunction(func) then
			continue
		end

		local upvalues = debug.getupvalues(func)
		if not upvalues then
			continue
		end

		local upvaluesFunction = upvalues[2]

		cachedUpvaluesFunction = upvaluesFunction
		lastFunctionCacheTime = os.clock()

		return function()
			if LeaderboardClient.calling then
				return
			end

			LeaderboardClient.calling = true

			upvaluesFunction()

			LeaderboardClient.calling = false
		end
	end

	return nil
end

---@return table?
function LeaderboardClient.gld()
	if cachedUpvaluesTable and os.clock() - lastDataCacheTime <= 2.0 then
		return cachedUpvaluesTable
	end

	for _, con in next, getconnections(players.PlayerRemoving) do
		local func = con.Function
		if not filterFunction(func) then
			continue
		end

		local upvalues = debug.getupvalues(func)
		if not upvalues then
			continue
		end

		local upvaluesTable = upvalues[1]

		cachedUpvaluesTable = upvaluesTable
		lastDataCacheTime = os.clock()

		return upvaluesTable
	end

	return nil
end

return LeaderboardClient
