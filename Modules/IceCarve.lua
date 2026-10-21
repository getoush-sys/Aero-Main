---@class Action
local Action = getfenv().Action

---@module Modules.Globals.Mantra
local Mantra = getfenv().Mantra

---@class Signal
local Signal = getfenv().Signal

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
    local mantra = Mantra.data(self.entity, "Mantra:CarveIce{{Ice Carve}}")

    if mantra and mantra.spring then
        local distance = self:distance(self.entity)

        timing.iae = true
        timing.mat = 1000
        timing.hitbox = Vector3.new(40, 32, 50)

        local action = Action.new()
        action._when = math.min(600 + distance * 10, 1000)
        action._type = "Dodge"
        action.name = string.format("(%.2f) Ice Carve Spring Spark", distance)
        self:action(timing, action)
        
        return self:action(timing, action)
    end

    timing.ffh = true
    timing.pfh = true
    timing.fhb = true
    timing.rpue = false
    timing.duih = true
    timing.hitbox = Vector3.new(32, 32, 50)

    local action = Action.new()
    action._when = 300
    action._type = "Start Block"
    action.name = "Ice Carve Start"
    self:action(timing, action)

    local hrp = self.entity:FindFirstChild("HumanoidRootPart")
    local humanoid = self.entity:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    repeat task.wait() until not self.track.IsPlaying

    local activeAnim = nil
    for _, animTrack in next, humanoid:GetPlayingAnimationTracks() do
        if animTrack.Animation.AnimationId ~= "rbxassetid://15714151635" then
            continue
        end
        activeAnim = animTrack
        break
    end

    if activeAnim then
        repeat task.wait() until not activeAnim.IsPlaying
        task.wait(0.6)
    end

    local actionEnd = Action.new()
    actionEnd._when = 0
    actionEnd._type = "End Block"
    actionEnd.ihbc = true
    actionEnd.name = "Ice Carve End"
    self:action(timing, actionEnd)
end