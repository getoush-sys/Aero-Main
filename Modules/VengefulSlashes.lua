---@class Action
local Action = getfenv().Action

-- Services.
local players = game:GetService("Players")

---Module function.
---@param self PartDefender
---@param timing PartTiming
return function(self, timing)
	local part = self.part
	if not part then
		return
	end

	local localCharacter = players.LocalPlayer and players.LocalPlayer.Character
	if not localCharacter then
		return
	end

	local origin = part:IsA("BasePart") and part.Position or part:GetPivot().Position

	local closestCharacter, closestDistance = nil, math.huge
	for _, player in next, players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end

		local distance = (hrp.Position - origin).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestCharacter = character
		end
	end

	if closestCharacter == localCharacter then
		return
	end

	local action = Action.new()
	action._when = 100
	action._type = "Parry"
	action.ihbc = true
	action.name = "Vengeful Slashes Timing"
	return self:action(timing, action)
end
