---@class Action
local Action = getfenv().Action

return function(self, timing)
	local shooty = self.part:FindFirstChild("Shooty")
	if not shooty then
		return
	end
	
	if not shooty.IsPlaying then
		shooty.Played:Wait()
	end

	timing.duih = true
	timing.hitbox = Vector3.new(7, 7, 7)
	timing.fhb = false

	local action = Action.new()
	action._when = 350
	action._type = "Parry"
	action.hitbox = Vector3.new(0, 0, 0)
	action.name = "Contact"
	return self:action(timing, action)
end