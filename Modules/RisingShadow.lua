---@type PartTiming
local PartTiming = getfenv().PartTiming

---@type Action
local Action = getfenv().Action

---@module Modules.Globals.Mantra
local Mantra = getfenv().Mantra

---@type ProjectileTracker
local ProjectileTracker = getfenv().ProjectileTracker

---@module Features.Combat.Defense
local Defense = getfenv().Defense

---@module Utility.TaskSpawner
local TaskSpawner = getfenv().TaskSpawner

---@module Game.Latency
local Latency = getfenv().Latency

---Module function.
---@param self AnimatorDefender
---@param timing AnimationTiming
return function(self, timing)
    timing.forced = true

    TaskSpawner.spawn("Module_RisingShadow", function()
        local data = Mantra.data(self.entity, "Mantra:RisingSlashShadow{{Rising Shadow}}")
        local range = data.rush * 3 + data.drift * 2
        
        local thrown = workspace:FindFirstChild("Thrown")
        if not thrown then
            return
        end

        local distance = self:distance(self.entity)

        local tracker = ProjectileTracker.new(function(candidate)
            return candidate.Name == "TRACKER" 
        end)

        task.wait(math.max(0, 0.05 - Latency.rtt()))

        if distance <= 15 then
            local action = Action.new()
            action._type = "Parry" 
            action._when = math.min(500 + distance * 50, 1000)
            action.name = "Rising Shadow Close Timing"
            action.ihbc = true
            action.fhb = true
            return self:action(timing, action)
        end
        
        local action = Action.new()
        action._when = 600
        action._type = "Parry" 
        action.name = "Rising Shadow Part"

        local pt = PartTiming.new()
        pt.uhc = true
        pt.duih = true
        pt.fhb = true 
        pt.name = "RisingShadowProjectile"
        
        pt.hitbox = Vector3.new(22 + range, 22 + range, 22 + range)
        pt.actions:push(action)
        pt.cbm = true

        Defense.cdpo(tracker:wait(), pt)
    end)
end