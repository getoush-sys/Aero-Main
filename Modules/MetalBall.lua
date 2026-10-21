---@type Action
local Action = getfenv().Action

---@module Game.Latency
local Latency = getfenv().Latency

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
	task.wait(0.5 - Latency.rtt())

	timing.ieae = true
	timing.iae = true

	local spikeBall = self.entity:WaitForChild("SpikeBall") or self.entity:WaitForChild("SpikeBall2")
	local isBlocking = false

	while task.wait() do
		if not spikeBall or not spikeBall.Parent then
			local endAction = Action.new()
			endAction._when = 0
			endAction._type = "End Block"
			endAction.ihbc = true
			endAction.name = "Metal Ball End"
			return self:action(timing, endAction)
		end

		if isBlocking then
			continue
		end

		if self:distance(self.entity) >= 30 then
			continue
		end

		local action = Action.new()
		action._when = 0
		action.ihbc = true
		action._type = "Start Block"
		action.name = "Metal Ball Block"
		self:action(timing, action)

		isBlocking = true
	end
end
