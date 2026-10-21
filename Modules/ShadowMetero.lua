---@type Action
local Action = getfenv().Action

---@type Maid
local Maid = getfenv().Maid

---@type Signal
local Signal = getfenv().Signal

-- Services.
local players = game:GetService("Players")

local SHADOW_METEOR_ANIM = "rbxassetid://6701095669"

local RECENT_WINDOW = 4

local lastCastAt = -math.huge

local animMaid = Maid.new()


---@param character Model
local function hookCharacter(character)
	animMaid:clean()

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local animationPlayed = Signal.new(animator.AnimationPlayed)
	animMaid:mark(animationPlayed:connect("ShadowMetero_LocalCast", function(track)
		local animation = track and track.Animation
		if animation and animation.AnimationId == SHADOW_METEOR_ANIM then
			lastCastAt = os.clock()
		end
	end))
end

do
	local localPlayer = players.LocalPlayer
	if localPlayer.Character then
		hookCharacter(localPlayer.Character)
	end
	Signal.new(localPlayer.CharacterAdded):connect("ShadowMetero_CharacterAdded", hookCharacter)
end

---Module function.
---@param self PartDefender
---@param timing PartTiming
return function(self, timing)
	if os.clock() - lastCastAt <= RECENT_WINDOW then
		return
	end

	local action = Action.new()
	action._when = 500
	action._type = "Parry"
	action.ihbc = true
	action.name = "Shadow Metero Timing"
	return self:action(timing, action)
end
