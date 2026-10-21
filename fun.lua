-- Decompiled with Medal

local ReplicatedStorage_0 = game:GetService("ReplicatedStorage")
require(ReplicatedStorage_0.Types)
local m_EffectReplicator = require(ReplicatedStorage_0.EffectReplicator)
m_EffectReplicator:WaitForContainer()
local FindEffect = m_EffectReplicator.FindEffect
local v_u_4 = tostring(FindEffect)
local info = debug.info
local v_u_6 = tostring(info)
local m_Lib = require(ReplicatedStorage_0.Modules.Lib)
local m_VectorMaths = require(ReplicatedStorage_0.Modules.VectorMaths)
require(ReplicatedStorage_0.Modules.Waves)
local m_CollisionUtils = require(ReplicatedStorage_0.Modules.CollisionUtils)
local TweenService = game:GetService("TweenService")
game:GetService("RunService")
local v11 = setmetatable
local v_u_12 = v11({}, {
    ["__index"] = 1,
    ["__tostring"] = 1,
    ["__newindex"] = 1
})
for _ = 1, 10 do
    v_u_12 = v11(v_u_12, {
        ["__index"] = 1,
        ["__tostring"] = 1,
        ["__newindex"] = 1
    })
end
scr = script
script = v11(v_u_12, {
    ["__index"] = 1,
    ["__tostring"] = 1,
    ["__newindex"] = 1,
    ["__call"] = 1,
    ["__namecall"] = 1,
    ["__metatable"] = false
})
local Parent = scr.Parent
local Requests = Parent:WaitForChild("Requests")
local StopSprint = Requests:WaitForChild("StopSprint")
local LocalPlayer = game.Players.LocalPlayer
local v_u_17 = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = v_u_17:WaitForChild("Humanoid")
local HumanoidRootPart = v_u_17:WaitForChild("HumanoidRootPart")
local Torso = v_u_17:WaitForChild("Torso")
local RootJoint = HumanoidRootPart:WaitForChild("RootJoint")
local RootAttachment = HumanoidRootPart:WaitForChild("RootAttachment")
local v_u_23 = Torso:WaitForChild("Left Hip")
local v_u_24 = Torso:WaitForChild("Right Hip")
local UserInputService = game:GetService("UserInputService")
UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
local Movement = ReplicatedStorage_0.Assets.Anims.Movement
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService_0 = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local CurrentCamera = workspace.CurrentCamera
local v_u_34 = pcall
local v_u_35 = xpcall
local v_u_36 = tostring
local random = math.random
local _ = Instance.new("Humanoid").LoadAnimation
local _ = Instance.new("Humanoid").GetState
local InvokeServer = Instance.new("RemoteFunction").InvokeServer
local FireServer = Instance.new("UnreliableRemoteEvent").FireServer
local FireServer_0 = Instance.new("RemoteEvent").FireServer
local v_u_41 = v_u_36(InvokeServer)
local v_u_42 = v_u_36(FireServer_0)
local IsA = game.IsA
local Disconnect = game.Changed:Connect(function() end).Disconnect
local Live = workspace:WaitForChild("Live")
local NPCs = workspace:WaitForChild("NPCs")
local Thrown = workspace:WaitForChild("Thrown")
local Terrain = workspace:WaitForChild("Terrain")
local m_RealmInfo = require(ReplicatedStorage.Info.RealmInfo)
local m_DataReplication = require(ReplicatedStorage.Info.DataReplication)
local Passives = m_EffectReplicator.Passives
local m_KeyBinds = require(ReplicatedStorage.KeyBinds)
require(ReplicatedStorage.Modules.UI)
require(ReplicatedStorage.Modules.Gizmos)
require(ReplicatedStorage.Modules.AreaSystem)
local v_u_53 = require(ReplicatedStorage.Modules.Checks)(m_EffectReplicator)
local ControllerManager = v_u_17:WaitForChild("ControllerManager")
local v_u_55 = require(ReplicatedStorage.Modules.ClientManager.KeyHandler)()
local function v_u_57(p56) -- name: gk
    -- upvalues: (copy) v_u_55
    return v_u_55[1](p56, "orats")
end
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("Dodge", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("StopDodge", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("Block", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("Unblock", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("LeftClick", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("FeintClick", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("CriticalClick", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("OffhandAttack", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("ServerSwim", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("GrabShip", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("ServerSlide", (1 / 0)))
end)
task.spawn(function()
    -- upvalues: (copy) v_u_55, (copy) Requests
    v_u_55[2](Requests:WaitForChild("ServerSlideStop", (1 / 0)))
end)
Humanoid:LoadAnimation(scr.Jump).Priority = Enum.AnimationPriority.Movement
local v_u_58 = Humanoid:LoadAnimation(Movement.Roll.CancelLeft)
local v_u_59 = Humanoid:LoadAnimation(Movement.Roll.CancelRight)
local v_u_60 = Humanoid:LoadAnimation(scr.SlideJump)
local ForwardRoll = Movement.Roll.ForwardRoll
local BackRoll = Movement.Roll.BackRoll
local RightRoll = Movement.Roll.RightRoll
local LeftRoll = Movement.Roll.LeftRoll
local v_u_65 = Humanoid:LoadAnimation(BackRoll)
local v_u_66 = Humanoid:LoadAnimation(Movement.Crouch)
local v_u_67 = Humanoid:LoadAnimation(Movement.Slide)
local v_u_68 = Humanoid:LoadAnimation(Movement.Groundslide)
local v_u_69 = {
    [ForwardRoll] = Movement.WaterDash.ForwardWaterDash,
    [BackRoll] = Movement.WaterDash.BackWaterDash,
    [RightRoll] = Movement.WaterDash.RightWaterDash,
    [LeftRoll] = Movement.WaterDash.LeftWaterDash
}
local v_u_70 = false
local v_u_71 = nil
local v_u_72 = true
local v_u_73 = {}
local v_u_74 = m_DataReplication.GetData()
function InAir() -- name: InAir
    -- upvalues: (copy) m_EffectReplicator, (copy) ControllerManager, (copy) m_CollisionUtils, (copy) HumanoidRootPart
    if m_EffectReplicator:HasEffect("Swimming") then
        return false
    end
    if m_EffectReplicator:HasEffect("AirBorne") then
        return true
    end
    if not ControllerManager.GroundSensor.SensedPart then
        local v75 = m_CollisionUtils
        local Position_1 = HumanoidRootPart.Position
        local v77 = -(ControllerManager.GroundSensor.SearchDistance + 3)
        if not v75:Raycast(Position_1, Vector3.new(0, v77, 0), m_CollisionUtils.solidParams) then
            return true
        end
    end
    return false
end
local v_u_78 = LocalPlayer:GetMouse()
function ReplicatedStorage.Requests.GetResTP.OnClientInvoke(p79)
    -- upvalues: (copy) m_Lib, (copy) CurrentCamera, (copy) v_u_78, (copy) IsA
    local v80 = nil
    local v81 = 0.4
    local v82 = nil
    local v83 = m_Lib.lookAt(CurrentCamera.CFrame.Position, v_u_78.Hit.Position)
    local ExistingResTPMarkers = workspace:FindFirstChild("ExistingResTPMarkers")
    if ExistingResTPMarkers then
        for _, v85 in ExistingResTPMarkers:GetChildren() do
            if v85.Value and v85.Value.Parent then
                local v86 = v85:GetAttribute("Corrupted")
                if not v86 or p79 then
                    local Value = v85.Value
                    local v88 = not IsA(Value, "BasePart") or Value:FindFirstChild("X")
                    if v88 then
                        local Adornee = v88.Adornee
                        local Magnitude = (m_Lib.lookAt(CurrentCamera.CFrame.Position, Adornee.Position).LookVector - v83.LookVector).Magnitude
                        if Magnitude < v81 then
                            v80 = v85:GetAttribute("ListID")
                            v82 = v86
                            v81 = Magnitude
                        end
                    end
                end
            end
        end
        return v80, v82
    end
end
function ReplicatedStorage.Requests.GetCameraToMouse.OnClientInvoke()
    -- upvalues: (copy) m_Lib, (copy) CurrentCamera, (copy) v_u_78
    return m_Lib.lookAt(CurrentCamera.CFrame.Position, v_u_78.Hit.Position)
end
function ReplicatedStorage.Requests.WaitForMob.OnClientInvoke(p91)
    local v92 = workspace.Live:WaitForChild(p91)
    v92:WaitForChild("HumanoidRootPart")
    v92:WaitForChild("Humanoid")
    warn("found them", p91)
end
function MovementCheck() -- name: MovementCheck
    -- upvalues: (copy) m_EffectReplicator
    if m_EffectReplicator:HasEffect("Action") then
        return false
    elseif m_EffectReplicator:HasEffect("NoParkour") then
        return false
    elseif m_EffectReplicator:HasEffect("Knocked") or m_EffectReplicator:HasEffect("Unconscious") then
        return false
    else
        return not (m_EffectReplicator:HasEffect("Pinned") or m_EffectReplicator:HasEffect("Carried"))
    end
end
function CrouchCheck() -- name: CrouchCheck
    -- upvalues: (copy) m_EffectReplicator
    if MovementCheck() then
        if m_EffectReplicator:HasEffect("Stun") then
            return
        elseif m_EffectReplicator:HasEffect("Action") then
            return
        elseif m_EffectReplicator:HasEffect("MobileAction") then
            return
        elseif m_EffectReplicator:HasEffect("Blocking") then
            return
        elseif not m_EffectReplicator:HasEffect("ClientSlide") then
            if not m_EffectReplicator:HasEffect("ClientSwim") then
                return true
            end
        end
    else
        return
    end
end
local v_u_93 = not m_RealmInfo.Hardcore and 0 or v_u_17:GetAttribute("Trait_Speed")
local v_u_94 = m_EffectReplicator:CreateEffect("SprintSpeed", {
    ["Value"] = v_u_93 + 8
})
local v_u_95 = false
function Crouch() -- name: Crouch
    -- upvalues: (copy) m_EffectReplicator, (ref) v_u_95, (copy) Humanoid, (copy) HumanoidRootPart, (copy) Live, (copy) NPCs, (copy) Thrown, (ref) v_u_70, (copy) v_u_66, (copy) Requests
    local v96 = m_EffectReplicator:FindEffect("ClientCrouch")
    if v96 then
        if not v_u_95 then
            v96:Remove()
        end
    end
    local v97 = m_EffectReplicator:FindEffect("ClientSlide")
    if v97 then
        v97:Remove()
        return
    end
    if m_EffectReplicator:HasEffect("Crouching") then
        return
    end
    if m_EffectReplicator:HasEffect("ClientSwim") then
        return
    end
    if not CrouchCheck() then
        return
    end
    local MoveDirection_0 = Humanoid.MoveDirection
    if MoveDirection_0.Magnitude > 0.1 then
        local v99 = Ray.new(HumanoidRootPart.Position, Vector3.new(0, -12, 0))
        local v100 = false
        local v101 = { Live, NPCs, Thrown }
        local v102, _, v103 = workspace:FindPartOnRayWithIgnoreList(v99, v101)
        if v102 and v103.y <= 0.99 then
            local Unit = (v103 * Vector3.new(1, 0, 1)).Unit
            local Magnitude_0 = Unit.Magnitude
            v100 = Magnitude_0 > 0 and (Magnitude_0 == Magnitude_0 and Unit:Dot(MoveDirection_0) > -0.1) and true or v100
        end
        local v106 = Humanoid:GetState()
        local v107 = v106 == Enum.HumanoidStateType.Freefall or (v106 == Enum.HumanoidStateType.Jumping or v106 == Enum.HumanoidStateType.Landed)
        if (v_u_70 == true or (m_EffectReplicator:HasEffect("ForceSlide") or m_EffectReplicator:HasEffect("ClientDodge"))) and not v100 then
            SlideForward(v107)
            return
        end
        if v100 then
            SlideDown(v107)
            return
        end
    end
    if m_EffectReplicator:HasEffect("CastingSpell") then
        return
    end
    Sprint(false)
    v_u_66:Play()
    Requests.ServerCrouch:FireServer(true)
    if CrouchCheck() and not m_EffectReplicator:HasEffect("Sprinting") then
        local _ = Humanoid.Jump
    end
    local v108 = m_EffectReplicator:CreateEffect("ClientCrouch")
    while true do
        local v109 = not CrouchCheck() or (m_EffectReplicator:HasEffect("StrongWind") or m_EffectReplicator:HasEffect("Sprinting") or (Humanoid.Jump or (v_u_70 == true and true or m_EffectReplicator:HasEffect("DurationCast"))))
        if Humanoid.MoveDirection.Magnitude < 0.1 then
            v_u_66:AdjustSpeed(0)
        else
            v_u_66:AdjustSpeed(Humanoid.WalkSpeed / 15.5)
        end
        task.wait()
        if not v108 or (not v108.Parent or (v109 or m_EffectReplicator:HasEffect("LightAttack") and not m_EffectReplicator:HasEffect("AllowCrouch"))) then
            Requests.ServerCrouch:FireServer(false)
            v_u_66:Stop()
            if v108 and v108.Parent then
                v108:Remove()
            end
            return
        end
    end
end
local v_u_110 = 0
function JetJump() -- name: JetJump
    -- upvalues: (copy) m_EffectReplicator, (copy) Passives, (copy) v_u_17, (copy) HumanoidRootPart, (copy) v_u_34, (copy) Requests, (copy) Humanoid, (copy) v_u_17, (copy) v_u_73, (copy) ReplicatedStorage
    if m_EffectReplicator:HasEffect("ClientSwim") then
        return
    end
    if not Passives["Arc Module: Leap"] then
        return
    end
    if v_u_17:FindFirstChild("Ether").Value < 15 or m_EffectReplicator:HasEffect("JetJumpCD") then
        return
    end
    local v111 = m_EffectReplicator:CreateEffect("JetJumpCD")
    v111:AddTag("CDName", "Arc Module: Leap")
    v111:Debris(m_EffectReplicator:HasEffect("Danger") and 15 or 10)
    m_EffectReplicator:CreateEffect("ArcJump"):Debris(0.25)
    local Position = HumanoidRootPart.Position
    local v_u_113 = HumanoidRootPart.CFrame.UpVector * 3
    v_u_34(function()
        -- upvalues: (ref) Requests, (copy) Position, (copy) v_u_113
        Requests.ServerJetJump:FireServer(Position, v_u_113)
    end)
    local v114 = 40
    if Humanoid.Health < Humanoid.MaxHealth * 0.5 then
        v114 = v114 / 2
    end
    local v115 = Instance.new("BodyVelocity", HumanoidRootPart)
    v115:AddTag("LocalMover")
    v115.Velocity = v_u_113.Unit * v114
    v115.MaxForce = Vector3.new(0, 80000, 0)
    if m_EffectReplicator:HasEffect("GravityField") then
        v115.MaxForce = Vector3.new(60000, 50, 60000)
    end
    v115.Parent = v_u_17.Torso
    v115:AddTag("AllowedBM")
    local v116 = tick()
    Humanoid:LoadAnimation(scr.JetJump):Play(0.1)
    while true do
        task.wait()
        if tick() - v116 < 0.05 then
            v115.Velocity = v_u_113.Unit * v114 * 1.5
        else
            v115.Velocity = v_u_113.Unit * v114
        end
        if tick() - v116 >= 0.5 or (not v_u_73.Space or (m_EffectReplicator:HasEffect("Stun") or m_EffectReplicator:HasEffect("Action"))) then
            local v117 = Instance.new("Folder", v_u_17)
            v117.Name = "ExhaustCancel"
            ReplicatedStorage.Debris:Fire(v117, 0.1)
            if v115 then
                v115:Destroy()
            end
            return
        end
    end
end
function LongJump(p118) -- name: LongJump
    -- upvalues: (copy) m_EffectReplicator, (ref) v_u_110, (copy) HumanoidRootPart, (ref) v_u_93, (copy) Humanoid, (copy) v_u_17, (copy) ReplicatedStorage
    local v119 = tick()
    if (m_EffectReplicator:HasEffect("Danger") and 2 or 1) > v119 - v_u_110 then
        return
    elseif m_EffectReplicator:HasEffect("GravityField") then
        return
    elseif m_EffectReplicator:HasEffect("NoSlideJump") then
        return
    elseif not m_EffectReplicator:HasEffect("NoJump") then
        local UpVector = HumanoidRootPart.CFrame.LookVector * 3 + HumanoidRootPart.CFrame.UpVector
        local v_u_121 = Instance.new("BodyVelocity")
        v_u_121:AddTag("LocalMover")
        v_u_121.Name = "SlideJump"
        local v122 = 45
        if not p118 then
            v122 = v122 + 7.5
        end
        local v123 = v122 + v_u_93 * 5
        m_EffectReplicator:CreateEffect("SlideJumping"):Debris(2)
        if Humanoid.Health <= Humanoid.MaxHealth * 0.4 then
            v123 = v123 * 0.8
        end
        if m_EffectReplicator:HasEffect("Heavy") then
            v123 = v123 * 0.1
        end
        v_u_121.Velocity = UpVector.Unit * v123
        v_u_121.MaxForce = Vector3.new(8000, 8000, 8000)
        v_u_121:AddTag("AllowedBM")
        v_u_121.Parent = v_u_17.Torso
        ReplicatedStorage.Debris:Fire(v_u_121, 0.25)
        local v_u_125 = m_EffectReplicator.EffectAdded:Connect(function(p124)
            -- upvalues: (copy) v_u_121, (ref) HumanoidRootPart
            if p124.Class == "Parried" then
                if v_u_121.Parent then
                    v_u_121:Destroy()
                end
                HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        end)
        task.delay(1, function()
            -- upvalues: (copy) v_u_125
            v_u_125:Disconnect()
        end)
        m_EffectReplicator:CreateEffect("AirBorne"):Debris(0.5)
        local v126 = {
            ["char"] = nil,
            ["Duration"] = 0.5,
            ["char"] = v_u_17
        }
        ReplicatedStorage.Requests.ClientEffectDirect:Fire("WindTrails", v126)
        v_u_110 = v119
    end
end
function GaleLeap(p_u_127) -- name: GaleLeap
    -- upvalues: (copy) m_EffectReplicator, (copy) v_u_17, (copy) HumanoidRootPart, (copy) v_u_34, (copy) Requests, (copy) Humanoid, (copy) v_u_53, (copy) v_u_17, (copy) ReplicatedStorage
    if m_EffectReplicator:HasEffect("GaleLeapCD") then
        return
    elseif not m_EffectReplicator:HasEffect("Danger") or v_u_17:FindFirstChild("Ether").Value >= 20 then
        m_EffectReplicator:CreateEffect("GaleLeapin"):Debris(0.25)
        local Position_0 = HumanoidRootPart.Position
        local upVector = HumanoidRootPart.CFrame.LookVector * 3 + HumanoidRootPart.CFrame.upVector
        v_u_34(function()
            -- upvalues: (ref) Requests, (copy) Position_0, (copy) upVector, (copy) p_u_127
            Requests.ServerGaleLeap:FireServer(Position_0, upVector, p_u_127)
        end)
        local v130 = 110
        if Humanoid.Health < Humanoid.MaxHealth * 0.5 then
            v130 = v130 / 2
        end
        if v_u_53.HorMobilityChain() then
            v130 = v130 * 0.8
        end
        local v131 = Instance.new("BodyVelocity")
        v131:AddTag("LocalMover")
        v131.Velocity = upVector.Unit * v130
        v131.MaxForce = Vector3.new(80000, 80000, 80000)
        v131.Parent = v_u_17.Torso
        v131:AddTag("AllowedBM")
        ReplicatedStorage.Debris:Fire(v131, 0.25)
        Humanoid:LoadAnimation(scr.GaleLeap):Play(0.1)
    end
end
local v132 = {
    Live,
    NPCs,
    Thrown,
    workspace.Corpses,
    workspace.SnowSurfaces
}
local v_u_133 = RaycastParams.new()
v_u_133.RespectCanCollide = true
v_u_133.FilterDescendantsInstances = v132
local v_u_134 = false
function SlideDown(p135) -- name: SlideDown
    -- upvalues: (copy) m_EffectReplicator, (copy) Humanoid, (ref) v_u_134, (copy) v_u_67, (copy) Passives, (copy) v_u_17, (copy) v_u_55, (copy) HumanoidRootPart, (copy) v_u_133, (copy) m_CollisionUtils, (copy) CurrentCamera, (copy) m_Lib, (copy) ReplicatedStorage, (copy) FireServer_0, (copy) v_u_57
    if not MovementCheck() then
        return
    end
    if m_EffectReplicator:HasEffect("Action") then
        return
    end
    if m_EffectReplicator:HasEffect("MobileAction") then
        return
    end
    if m_EffectReplicator:HasEffect("LightAttack") then
        return
    end
    if m_EffectReplicator:HasEffect("Blocking") then
        return
    end
    if m_EffectReplicator:HasEffect("NoSlide") then
        return
    end
    if m_EffectReplicator:HasEffect("ClientSlide") then
        return
    end
    if m_EffectReplicator:HasEffect("ClientSwim") then
        return
    end
    local v136 = m_EffectReplicator:CreateEffect("ClientSlide")
    v136:Debris(60)
    if m_EffectReplicator:FindEffect("ClientDodge") or ((m_EffectReplicator:HasEffect("LightAttack") or m_EffectReplicator:HasEffect("Action")) and not m_EffectReplicator:HasEffect("SlidingAttack") or Humanoid.Jump) or (m_EffectReplicator:FindEffect("Blocking") or m_EffectReplicator:HasEffect("Knocked")) then
        v136:Remove()
        return
    end
    v_u_134 = true
    v_u_67:Play()
    local MaxHealth = Humanoid.Health / Humanoid.MaxHealth
    if Passives["Endurance Runner"] then
        MaxHealth = 0.25 + MaxHealth * 0.75
    end
    local v138 = 30 + v_u_17.PassiveAgility.Value * MaxHealth
    if p135 == true then
        v138 = 40 + v_u_17.PassiveAgility.Value * MaxHealth
    end
    if m_EffectReplicator:HasEffect("GravityField") then
        v138 = v138 * 0.2
    end
    v_u_55[1]("ServerSlide", "orats"):FireServer(v138)
    local v139 = tick()
    local v140 = false
    local v141 = nil
    local v142 = nil
    local v143 = nil
    while true do
        task.wait()
        local Instance = workspace:Raycast(HumanoidRootPart.CFrame * CFrame.new(0, -2, 0).Position, HumanoidRootPart.CFrame.LookVector * 1.5, v_u_133)
        if Instance then
            Instance = Instance.Instance
        end
        if Instance then
            v147 = v141
            break
        end
        local v145, v146, v147 = m_CollisionUtils:Ray(HumanoidRootPart.Position, Vector3.new(0, -15, 0), v_u_133)
        if not v145 then
            v147 = v141
            break
        end
        local v148 = (v147 * Vector3.new(1, 0, 1)).Unit
        local Magnitude_1 = v148.Magnitude
        if Magnitude_1 < 0 or Magnitude_1 ~= Magnitude_1 then
            v148 = HumanoidRootPart.CFrame.LookVector
        end
        if v143 and v148:Dot(v143.CFrame.LookVector) < 0 then
            if v145 ~= workspace.Terrain then
                break
            end
            local v150 = workspace:Raycast((HumanoidRootPart.CFrame * CFrame.new(0, 0, -1)).Position, Vector3.new(0, -15, 0), v_u_133)
            if not v150 or v150.Position.y >= v146.y then
                break
            end
        end
        local v151 = CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
        if v151 ~= v151 then
            v151 = v148
        end
        if v151:Dot(v148) < 0 and v145 ~= workspace.Terrain then
            local v152 = -v151.z
            local v153 = v151.x
            if Vector3.new(v152, 0, v153):Dot(v148) < 0 then
                local v154 = -v148.z
                local v155 = v148.x
                v151 = Vector3.new(v154, 0, v155)
            else
                local v156 = v148.z
                local v157 = -v148.x
                v151 = Vector3.new(v156, 0, v157)
            end
        end
        local v158 = v151 + v148
        if v145 == workspace.Terrain then
            v158 = v151 * 1.5
            v140 = true
        end
        if v142 then
            if m_EffectReplicator:HasEffect("CameraLock") then
                v142.Velocity = v158 * v138
            end
        else
            v142 = Instance.new("BodyVelocity")
            v142:AddTag("LocalMover")
            v142.Name = "SlideVel"
            v142.MaxForce = Vector3.new(1000000, 0, 1000000)
            v142.Velocity = v158 * v138
            v142:AddTag("AllowedBM")
            v142.Parent = HumanoidRootPart
        end
        local identity = CFrame.new(Vector3.new(0, 0, 0), v158)
        if m_Lib.isNAN(identity) then
            identity = CFrame.identity
        end
        if v143 then
            if m_EffectReplicator:HasEffect("CameraLock") then
                v143.CFrame = identity
            end
        else
            v143 = Instance.new("BodyGyro")
            v143:AddTag("AllowedBM")
            v143.Name = "SlideGyro"
            v143.MaxTorque = Vector3.new(0, 4000000, 0)
            v143.P = 10000
            v143.CFrame = identity
            v143.Parent = HumanoidRootPart
        end
        if m_EffectReplicator:HasEffect("MantraCasted") and v_u_67.IsPlaying then
            v_u_67:Stop()
        end
        local v160 = m_EffectReplicator:FindEffect("ClientDodge") or (m_EffectReplicator:HasEffect("LightAttack") or m_EffectReplicator:HasEffect("Action")) and not m_EffectReplicator:HasEffect("SlidingAttack") or (m_EffectReplicator:HasEffect("NoSlide") or Humanoid.Jump) or m_EffectReplicator:FindEffect("Blocking") or (m_EffectReplicator:HasEffect("Knocked") or m_EffectReplicator:HasEffect("NoSlide"))
        local v161 = 1 - v147.Y
        local v162 = v138 + math.max(v161, 0)
        v138 = math.min(v162, 70)
        if v147 and (v147.y > 0.99 and v145) or v160 then
            break
        end
        v141 = v147
    end
    v_u_134 = false
    local v163 = tick() - v139
    local v164 = v163 > 0.3 and true or not v140
    if v163 > 0.3 and (Humanoid.Jump and (Passives["Wind Step"] and (v147 and not m_EffectReplicator:HasEffect("GravityField")))) then
        GaleLeap(v147)
    end
    if v164 and (Humanoid.Jump and not (m_EffectReplicator:HasEffect("GaleLeapin") or m_EffectReplicator:HasEffect("GravityField"))) then
        LongJump()
    end
    if v164 then
        local v165 = m_EffectReplicator:GetEffectsWithTag("SlideBoost")
        for _, v166 in next, v165 do
            v166:Remove()
        end
        local v167 = m_EffectReplicator:CreateEffect("Speed", {
            ["Value"] = 7 + v138 / 10
        })
        v167:AddTag("SlideBoost")
        v167:Debris(1.5)
        local v168 = {
            ["char"] = nil,
            ["Duration"] = 1.5,
            ["char"] = v_u_17
        }
        ReplicatedStorage.Requests.ClientEffectDirect:Fire("WindTrails", v168)
    end
    FireServer_0(v_u_57("ServerSlideStop"))
    if v142 and v142.Parent then
        v142:Destroy()
    end
    if v143 and v143.Parent then
        v143:Destroy()
    end
    v_u_67:Stop()
    if v136 and v136.Parent then
        v136:Remove()
    end
end
local v_u_169 = false
local v_u_170 = -1000
local v_u_171 = false
local v_u_172 = 0
local v173 = RaycastParams.new()
v173.RespectCanCollide = true
v173.FilterDescendantsInstances = m_CollisionUtils.SolidFilter
v173:AddToFilter(v_u_17)
v_u_73.NOAERIALS = false
function Roll() -- name: Roll
    -- upvalues: (copy) m_EffectReplicator, (copy) FireServer_0, (copy) v_u_57, (copy) HumanoidRootPart, (copy) Passives, (copy) v_u_17, (copy) Humanoid, (copy) v_u_17, (copy) v_u_55, (ref) v_u_72, (copy) ForwardRoll, (copy) RightRoll, (copy) LeftRoll, (copy) BackRoll, (copy) v_u_69, (copy) ReplicatedStorage, (copy) ControllerManager, (copy) m_RealmInfo, (copy) RootAttachment, (copy) m_VectorMaths, (copy) v_u_73, (copy) v_u_58, (copy) v_u_59, (copy) m_CollisionUtils, (copy) CurrentCamera, (copy) v_u_53, (ref) v_u_93, (copy) v_u_34, (copy) Requests
    local v174 = m_EffectReplicator:FindEffect("ClientSwim")
    local v175 = not m_EffectReplicator:HasEffect("WingDashCooldown")
    if v175 then
        v175 = m_EffectReplicator:HasEffect("Wings")
    end
    if m_EffectReplicator:HasEffect("UsingSpell") or m_EffectReplicator:HasEffect("CastingSpell") then
        return
    end
    if not MovementCheck() then
        return
    end
    if m_EffectReplicator:HasEffect("MidAttack") then
        return
    end
    if m_EffectReplicator:HasEffect("NoAttack") and not m_EffectReplicator:HasEffect("CanRoll") then
        return
    end
    if m_EffectReplicator:HasEffect("Dodged") or m_EffectReplicator:HasEffect("Dodge") then
        return
    end
    if m_EffectReplicator:HasEffect("NoRoll") or m_EffectReplicator:HasEffect("PreventRoll") then
        return
    end
    if m_EffectReplicator:HasEffect("SwimRestrict") and m_EffectReplicator:HasEffect("Swimming") then
        return
    end
    if m_EffectReplicator:HasEffect("Stun") and not m_EffectReplicator:HasEffect("PureMobStun") then
        return
    end
    if m_EffectReplicator:HasEffect("Action") or m_EffectReplicator:HasEffect("MobileAction") then
        return
    end
    if m_EffectReplicator:HasEffect("Carried") then
        return
    end
    local v176 = m_EffectReplicator:FindEffect("PressureForward")
    if m_EffectReplicator:HasEffect("LightAttack") and not v176 then
        return
    end
    if m_EffectReplicator:HasEffect("Blocking") then
        FireServer_0(v_u_57("Unblock"))
    end
    if m_EffectReplicator:HasEffect("ClientSlide") then
        return
    end
    if HumanoidRootPart:FindFirstChild("GravBV") then
        return
    end
    local v177 = v174 and "waterdash" or "roll"
    if Passives.Flashwind and m_EffectReplicator:HasEffect("Flashcharge") then
        _G.Sound(game.ReplicatedStorage.Sounds.WindFlash, HumanoidRootPart)
        _G.Sound(game.ReplicatedStorage.Sounds.WindFlash2, HumanoidRootPart)
    end
    local v_u_178
    if m_EffectReplicator:HasEffect("PressureForward") or (m_EffectReplicator:HasEffect("GaleDash") or (m_EffectReplicator:HasEffect("Flashcharge") or m_EffectReplicator:HasEffect("PhantomStep") and not m_EffectReplicator:HasEffect("PhantomStepDashCD"))) then
        v_u_178 = true
        m_EffectReplicator:CreateEffect("PressureForwarding"):Debris(0.5)
        if Passives.Flashwind and not m_EffectReplicator:FindEffect("FlashwindCD") then
            m_EffectReplicator:CreateEffect("Flashcharge"):Debris(3)
            local v179 = m_EffectReplicator:CreateEffect("FlashwindCD")
            v179:AddTag("CDName", "Flashwind")
            v179:Debris(15)
            local Attach_ = workspace.Thrown:FindFirstChild("Attach_" .. v_u_17.Name)
            local v181
            if Attach_ then
                v181 = Attach_:FindFirstChild("HandWeapon")
            else
                v181 = nil
            end
            if v181 then
                local v182 = Color3.new(0.721569, 1, 0.203922)
                _G.Emit(game.ReplicatedStorage.Assets.StaticSpear1, v181, 1, {
                    ["Duration"] = 6,
                    ["Color"] = nil,
                    ["Color"] = v182
                })
                _G.Emit(game.ReplicatedStorage.Assets.StaticSpear2, v181, 1, {
                    ["Duration"] = 6,
                    ["Color"] = nil,
                    ["Color"] = v182
                })
                _G.Sound(game.ReplicatedStorage.Sounds.SSlightning, v181, {
                    ["Duration"] = 6
                })
                _G.Sound(game.ReplicatedStorage.Sounds.WindFlash, v181, {
                    ["Duration"] = 6
                })
            end
        end
    else
        v_u_178 = false
    end
    local Ether = v_u_17:FindFirstChild("Ether")
    local Blinkstep = Passives.Blinkstep
    if Blinkstep then
        Blinkstep = Ether.Value >= Ether.MaxValue * 0.9
    end
    if not Blinkstep and (Passives.Blinkstep and Passives["Cutting Pace"]) then
        local v185 = m_EffectReplicator:FindEffect("CuttingPace")
        Blinkstep = v185 and v185.Value - 1 >= 0 and true or Blinkstep
    end
    local MaxHealth_0 = Humanoid.Health / Humanoid.MaxHealth
    if Passives["Endurance Runner"] then
        MaxHealth_0 = 0.25 + MaxHealth_0 * 0.75
    end
    local v_u_187 = 60 + v_u_17.PassiveAgility.Value * 0.5 * MaxHealth_0
    local v188 = false
    if Passives.Lowstride and m_EffectReplicator:FindEffect("ClientCrouch") then
        v_u_187 = v_u_187 + 10
    end
    if Blinkstep then
        print("BUFF THE DRIFT")
        v_u_187 = v_u_187 + (25 + 25 * MaxHealth_0)
    end
    if Passives["Rush of Ancients"] and (not m_EffectReplicator:HasEffect("AncientRushCD") and m_EffectReplicator:FindEffectWithTag("MaxMomentum")) then
        v188 = true
        if MaxHealth_0 < 0.5 then
            local v189 = 1 - MaxHealth_0
            local v190 = math.clamp(v189, 0, 1) * 5 + 3
            local v191 = m_EffectReplicator:CreateEffect("AncientRushCD")
            v191:AddTag("CDName", "Rush of Ancients")
            v191:Debris(v190)
        end
        if m_EffectReplicator:HasEffect("Danger") then
            local v192 = m_EffectReplicator:CreateEffect("AncientRushCD")
            v192:AddTag("CDName", "Rush of Ancients")
            v192:Debris(8)
        end
        v_u_187 = v_u_187 + (20 + 15 * MaxHealth_0)
    end
    if m_EffectReplicator:HasEffect("SpinAttack") then
        FireServer_0(v_u_55[1]("Dodge", "orats"), v177, true)
    else
        FireServer_0(v_u_55[1]("Dodge", "orats"), v177, nil, InAir(), v188)
    end
    m_EffectReplicator:CreateEffect("ClientDodge"):Debris(0.3)
    local v193 = m_EffectReplicator:CreateEffect("NoRoll")
    v193:Debris(2.3)
    tick()
    local v194
    if (m_EffectReplicator:HasEffect("GodSpeed") or (m_EffectReplicator:HasEffect("Overcharged") or m_EffectReplicator:HasEffect("Flashcharge"))) and not m_EffectReplicator:HasEffect("ClientSwim") then
        v194 = 0.5
        if Passives.Flashwind and not m_EffectReplicator:HasEffect("FlashwindCD") then
            m_EffectReplicator:CreateEffect("Flashcharge"):Debris(3)
            local v195 = m_EffectReplicator:CreateEffect("FlashwindCD")
            v195:AddTag("CDName", "Flashwind")
            v195:Debris(15)
            local Attach__0 = workspace.Thrown:FindFirstChild("Attach_" .. v_u_17.Name)
            local v197
            if Attach__0 then
                v197 = Attach__0:FindFirstChild("HandWeapon")
            else
                v197 = nil
            end
            if v197 then
                local v198 = Color3.new(0.721569, 1, 0.203922)
                _G.Emit(game.ReplicatedStorage.Assets.StaticSpear1, v197, 1, {
                    ["Duration"] = 6,
                    ["Color"] = nil,
                    ["Color"] = v198
                })
                _G.Emit(game.ReplicatedStorage.Assets.StaticSpear2, v197, 1, {
                    ["Duration"] = 6,
                    ["Color"] = nil,
                    ["Color"] = v198
                })
                _G.Sound(game.ReplicatedStorage.Sounds.SSlightning, v197, {
                    ["Duration"] = 6
                })
                _G.Sound(game.ReplicatedStorage.Sounds.WindFlash, v197, {
                    ["Duration"] = 6
                })
            end
        end
    else
        v194 = 0.2
    end
    v_u_72 = false
    local LookVector = HumanoidRootPart.CFrame.LookVector
    local MoveDirection = Humanoid.MoveDirection
    if MoveDirection.Magnitude < 0.1 then
        MoveDirection = -LookVector
    end
    local v201 = MoveDirection:Dot(LookVector)
    local v202 = math.clamp(v201, -1, 1)
    local v203 = math.acos(v202)
    local v204 = math.deg(v203)
    local v205
    if v204 <= 45 then
        v205 = ForwardRoll
    elseif v204 > 45 and v204 < 135 then
        local v206 = -LookVector.z
        local v207 = LookVector.x
        local v208 = MoveDirection:Dot((Vector3.new(v206, 0, v207)))
        local v209 = math.clamp(v208, -1, 1)
        local v210 = math.acos(v209)
        local v211 = math.deg(v210)
        if v211 <= 45 then
            v205 = RightRoll
        elseif v211 > 135 then
            v205 = LeftRoll
        else
            v205 = BackRoll
        end
    else
        v205 = BackRoll
    end
    local v212 = false
    local v213 = false
    local v214 = false
    local v215 = false
    if InAir() and not (m_EffectReplicator:HasEffect("ClientSwim") or (Passives["Chained Ring"] or m_EffectReplicator:HasAny("GravityField", "DisableAirDash"))) then
        if v205 == BackRoll then
            v214 = true
        else
            v212 = true
            v213 = true
            v215 = true
            local AirStalled = HumanoidRootPart:FindFirstChild("AirStalled")
            if AirStalled then
                AirStalled:Destroy()
                v_u_187 = 50
            else
                v_u_187 = 35
            end
        end
    end
    if v174 then
        v_u_187 = 30 + 10 * MaxHealth_0
        v205 = v_u_69[v205] or v205
        v212 = true
    end
    if v205 == BackRoll then
        v_u_187 = v_u_187 - 10
    end
    if Blinkstep then
        v205 = scr.PressureSlide
    end
    if v_u_178 then
        v205 = scr.PressureSlide
        v194 = 0.5
    end
    local v217 = m_EffectReplicator:HasEffect("ArcSuit")
    if v217 then
        v217 = Passives["Arc Module: Dash"]
    end
    if v217 then
        v_u_187 = v_u_187 - 5
        v205 = scr.PressureSlide
        local v218 = {
            ["char"] = nil,
            ["Duration"] = 0.3,
            ["char"] = v_u_17
        }
        ReplicatedStorage.Requests.ClientEffectDirect:Fire("WindTrails", v218)
        v194 = 0.3
    end
    if m_EffectReplicator:HasEffect("ReducedRoll") and not v217 then
        v_u_187 = v_u_187 - 10
    end
    if m_EffectReplicator:HasEffect("GravityField") then
        v_u_187 = v_u_187 * 0.2
        v212 = true
    end
    if v213 then
        v205 = scr.AirDash
    end
    local v_u_219 = Humanoid:LoadAnimation(v205)
    if v_u_178 then
        v_u_219.Priority = Enum.AnimationPriority.Movement
    end
    local v220 = 1
    if m_EffectReplicator:HasEffect("SlowTime") then
        v194 = 1
        v220 = 0.5
        v_u_187 = 10
    elseif m_EffectReplicator:HasEffect("StopTime") then
        v194 = 0.1
        v220 = 0.01
        v_u_187 = -100
    end
    if not m_EffectReplicator:HasEffect("SlowDodge") then
        local v221 = next
        local v222, v223 = m_EffectReplicator:GetEffectsOfClass("MetalCombo")
        local Value_0 = 0
        local v225 = false
        for _, v226 in v221, v222, v223 do
            v225 = v226:HasTag("heavyshoulder") and true or v225
            Value_0 = Value_0 + v226.Value
        end
        if Value_0 >= 3 and v225 then
            m_EffectReplicator:CreateEffect("SlowDodge"):Debris(1)
        end
    end
    if m_EffectReplicator:HasEffect("SlowDodge") then
        v194 = v194 + 0.1
        v220 = v220 * 0.75
        local v227 = v_u_187 - 20
        v_u_187 = math.max(v227, 10)
    end
    if not (m_EffectReplicator:HasEffect("GodSpeed") or m_EffectReplicator:HasEffect("ClientSwim")) then
        if v_u_178 then
            v_u_219:Play(0.1, 0.5, v220)
        else
            v_u_219:Play(0.1, 1, v220)
        end
    end
    local v228 = m_EffectReplicator:HasEffect("ArcSuit")
    if v228 then
        v228 = Passives["Arc Module: Dash"]
    end
    local v229 = m_EffectReplicator:CreateEffect("DashIt")
    if v177 == "waterdash" then
        _G.Sound(ReplicatedStorage.Sounds.WaterDash, HumanoidRootPart)
    elseif v213 then
        if v175 then
            _G.Sound(ReplicatedStorage.Sounds.Flap2, HumanoidRootPart)
            m_EffectReplicator:CreateEffect("WingDashCooldown")
        elseif Passives["Total Silence"] then
            _G.Sound(ReplicatedStorage.Sounds.AirDodge, HumanoidRootPart, {
                ["Volume"] = 0.05
            })
        else
            _G.Sound(ReplicatedStorage.Sounds.AirDodge, HumanoidRootPart)
        end
    elseif v214 then
        if Passives["Total Silence"] then
            _G.Sound(ReplicatedStorage.Sounds.AirDodge, HumanoidRootPart, {
                ["PlaybackSpeed"] = 5,
                ["Volume"] = 0.05
            })
        else
            _G.Sound(ReplicatedStorage.Sounds.AirDodge, HumanoidRootPart, {
                ["PlaybackSpeed"] = 5
            })
        end
    elseif not (v228 and Blinkstep) then
        if Passives["Total Silence"] then
            _G.Sound(ReplicatedStorage.Sounds.Roll, HumanoidRootPart, {
                ["Volume"] = 0.05
            })
        else
            _G.Sound(ReplicatedStorage.Sounds.Roll, HumanoidRootPart)
        end
    end
    if v214 then
        HumanoidRootPart.AssemblyLinearVelocity = Vector3.new()
        local v230 = {
            ["char"] = v_u_17
        }
        ReplicatedStorage.Requests.ClientEffectDirect:Fire("GaleLeapDown", v230)
    end
    m_EffectReplicator:RemoveEffectsOfClass("ShipJump")
    m_EffectReplicator:RemoveEffectsOfClass("ForceSlide")
    local GroundSensor = ControllerManager.GroundSensor
    local _ = HumanoidRootPart.CFrame
    local v232 = tick()
    local v233 = {
        ["char"] = nil,
        ["strength"] = 1.8,
        ["char"] = v_u_17
    }
    ReplicatedStorage.Requests.ClientEffectDirect:Fire("footprintCheck", v233)
    local IsScyphozia = m_RealmInfo.IsScyphozia
    local v_u_235 = false
    local function v247(_) -- name: groundDash
        -- upvalues: (ref) v_u_17, (ref) ForwardRoll, (ref) MoveDirection, (ref) v_u_187, (ref) RootAttachment, (ref) v_u_178, (ref) Blinkstep, (ref) ReplicatedStorage, (copy) GroundSensor, (ref) HumanoidRootPart, (ref) m_VectorMaths, (ref) m_EffectReplicator, (copy) v_u_219, (ref) FireServer_0, (ref) v_u_55, (ref) v_u_73, (ref) v_u_58, (ref) v_u_59, (ref) v_u_235, (ref) Humanoid, (ref) m_CollisionUtils
        local v236 = tick()
        v_u_17.Humanoid:LoadAnimation(ForwardRoll):Play(0, 1, 1)
        local v237 = Instance.new("LinearVelocity")
        v237.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        v237.ForceLimitMode = Enum.ForceLimitMode.PerAxis
        v237.RelativeTo = Enum.ActuatorRelativeTo.World
        v237.VectorVelocity = MoveDirection * v_u_187
        v237.MaxAxesForce = Vector3.new(8000, 8000, 8000)
        v237.Attachment0 = RootAttachment
        v237.Name = (v_u_178 or Blinkstep) and "EasyCancel" or "Mover"
        v237:AddTag("AllowedBM")
        v237.Parent = RootAttachment
        v_u_187 = v_u_187 + 5
        ReplicatedStorage.Debris:Fire(v237, 0.2)
        MoveDirection = MoveDirection * Vector3.new(1, 0, 1)
        local _ = v237.MaxAxesForce
        local v238 = MoveDirection * v_u_187
        if GroundSensor then
            local SensedPart = GroundSensor.SensedPart
            if SensedPart and SensedPart.AssemblyMass > HumanoidRootPart.AssemblyMass then
                v238 = v238 + m_VectorMaths.getVelocityAtPoint(SensedPart, GroundSensor.HitFrame.Position)
            end
            local HitNormal = GroundSensor.HitNormal
            v238 = (CFrame.lookAlong(Vector3.new(0, 0, 0), HitNormal, Vector3.new(0, 0, 1)) * CFrame.Angles(-1.5707963267948966, 0, 0)).Rotation:VectorToWorldSpace(v238)
        end
        HumanoidRootPart.AssemblyLinearVelocity = v238
        v237.VectorVelocity = v238
        while true do
            task.wait()
            if m_EffectReplicator:HasEffect("MantraCasted") and v_u_219.IsPlaying then
                v_u_219:Stop(0)
            end
            local v241 = m_EffectReplicator:HasAny("Feint", "ClientFeint", "Parry", "Parried", "DodgedFrame")
            if v241 or m_EffectReplicator:HasAny("LightAttack", "UsingAbility") and not m_EffectReplicator:HasEffect("PressureForwarding") or m_EffectReplicator:HasAny("CastingSpell", "UsingSpell") then
                FireServer_0(v_u_55[1]("StopDodge", "orats"), v_u_73, m_EffectReplicator:HasEffect("LightAttack"))
                if v_u_219.IsPlaying then
                    v_u_219:Stop(0)
                end
                if (m_EffectReplicator:FindEffect("Feint") or m_EffectReplicator:HasEffect("ClientFeint")) and not (v_u_58.IsPlaying or v_u_59.IsPlaying) then
                    if v_u_73.A then
                        v_u_58:Play(0.1)
                    else
                        v_u_59:Play(0.1)
                    end
                end
                if not v241 then
                    v_u_235 = "mantra"
                    return
                end
                v_u_235 = true
            end
            if v237 and v237.Parent then
                local _ = (tick() - v236) / 0.2
                local MoveDirection_1 = Humanoid.MoveDirection
                if MoveDirection_1.Magnitude < 0.1 then
                    MoveDirection_1 = MoveDirection
                end
                MoveDirection = MoveDirection_1
                if v_u_235 == true and v_u_187 >= 30 then
                    v_u_187 = v_u_187 - 10
                end
                local v243 = MoveDirection * v_u_187
                local v244 = Vector3.new(8000, 8000, 8000)
                if GroundSensor then
                    local SensedPart_0 = GroundSensor.SensedPart
                    if SensedPart_0 then
                        if SensedPart_0.AssemblyMass > HumanoidRootPart.AssemblyMass then
                            v243 = v243 + m_VectorMaths.getVelocityAtPoint(SensedPart_0, GroundSensor.HitFrame.Position)
                        end
                        local HitNormal_0 = GroundSensor.HitNormal
                        v243 = (CFrame.lookAlong(Vector3.new(0, 0, 0), HitNormal_0, Vector3.new(0, 0, 1)) * CFrame.Angles(-1.5707963267948966, 0, 0)).Rotation:VectorToWorldSpace(v243)
                    else
                        v244 = v244 * Vector3.new(1, 0, 1)
                    end
                end
                if HumanoidRootPart.AssemblyLinearVelocity.Unit:Angle(v243.Unit) > 0.17453292519943295 then
                    v244 = v244 * 5
                end
                if workspace:Raycast(HumanoidRootPart.Position, HumanoidRootPart.AssemblyLinearVelocity.Unit, m_CollisionUtils.solidParams) then
                    v244 = v244 * Vector3.new(0.8, 1, 0.8)
                end
                v237.MaxAxesForce = v244
                v237.VectorVelocity = v243
            end
            if tick() - v236 > 0.2 or (not v237 or (not v237.Parent or (HumanoidRootPart:FindFirstChild("GravBV") or (m_EffectReplicator:HasEffect("CancelDodge") or v_u_178 and m_EffectReplicator:FindEffect("Parried"))))) then
                return
            end
        end
    end
    local v248, v249, v250
    if v213 then
        v248 = CurrentCamera.CFrame.LookVector
        v_u_187 = (50 + MaxHealth_0 * 20) * 1.1
        local v251 = 1.3
        if v175 and not IsScyphozia then
            if v_u_53.HorMobilityChain() then
                v_u_187 = 50 + MaxHealth_0 * 25
            else
                v_u_187 = 50 + MaxHealth_0 * 30
            end
        end
        if IsScyphozia then
            v_u_187 = v_u_187 * 0.8
        end
        if m_EffectReplicator:HasEffect("Carrying") then
            v_u_187 = v_u_187 * 0.75
        end
        if m_EffectReplicator:HasEffect("GravityField") then
            v_u_187 = v_u_187 * 0.5
            v251 = v251 * 0.5
        end
        if v_u_93 > 0 then
            v251 = v251 + v_u_93 / 10
        end
        local v252 = Vector3.new(1, 1, 1) * v_u_187
        local v253 = v248 * v252
        if GroundSensor then
            local SensedPart_1 = GroundSensor.SensedPart
            if SensedPart_1 and SensedPart_1.AssemblyMass > HumanoidRootPart.AssemblyMass then
                v253 = v253 + m_VectorMaths.getVelocityAtPoint(SensedPart_1, GroundSensor.HitFrame.Position)
            end
        end
        HumanoidRootPart.AssemblyLinearVelocity = v253
        v249 = Instance.new("BodyVelocity")
        v249:AddTag("LocalMover")
        v249:AddTag("AllowedBM")
        v249.MaxForce = Vector3.new(50000, 50000, 50000)
        v249.Velocity = v248 * v252
        v249.Name = (v_u_178 or Blinkstep) and "EasyCancel" or "Mover"
        v249.Parent = HumanoidRootPart
        ReplicatedStorage.Debris:Fire(v249, v251)
        ReplicatedStorage.Requests.ClientEffectDirect:Fire("WindTrails", {
            ["char"] = v_u_17,
            ["Duration"] = v251 + 0.4
        })
        if v228 then
            local v255 = {
                ["char"] = nil,
                ["dur"] = 0.6,
                ["char"] = v_u_17
            }
            ReplicatedStorage.Requests.ClientEffectDirect:Fire("ArcExhaust", v255)
        else
            local v256 = {
                ["char"] = v_u_17
            }
            ReplicatedStorage.Requests.ClientEffectDirect:Fire("GaleLeap15", v256)
        end
        local v257 = m_EffectReplicator:CreateEffect("ClientAirDodge")
        local v258 = m_EffectReplicator:CreateEffect("BigAirDodgin")
        v250 = v_u_235
        local v259 = false
        while true do
            task.wait()
            if v215 then
                v259 = WallJump({
                    ["AirDashTag"] = nil,
                    ["NoSidejump"] = true,
                    ["AirDashTag"] = v249
                })
            end
            if m_EffectReplicator:HasEffect("MantraCasted") and v_u_219.IsPlaying then
                v_u_219:Stop()
            end
            if m_EffectReplicator:HasAny("LightAttack", "UsingAbility") and not v_u_178 or m_EffectReplicator:HasAny("UsingSpell", "Feint", "ClientFeint", "Parry", "DodgedFrame", "AirCombo") then
                FireServer_0(v_u_55[1]("StopDodge", "orats"), v_u_73, m_EffectReplicator:HasEffect("LightAttack") and true or false, true)
                if Passives["Death from Above"] or m_EffectReplicator:HasEffect("RevealBleeding") and Passives["Float Like a Butterfly"] then
                    v_u_34(function()
                        -- upvalues: (ref) Requests
                        Requests.ServerAirDashCancel:FireServer()
                    end)
                end
                v_u_219:Stop()
                if v_u_73.A then
                    v_u_58:Play(0.1)
                else
                    v_u_59:Play(0.1)
                end
                ReplicatedStorage.Debris:Fire(v249, 0.1)
                v249.MaxForce = Vector3.new(100, 0, 100)
                v249.Velocity = Vector3.new(0, 0, 0)
                v_u_235 = true
                v250 = v_u_235
                break
            end
            if v249 and v249.Parent then
                local _ = (tick() - v232) / v194
                v248 = CurrentCamera.CFrame.LookVector
                local v260 = v248 * v252
                local v261 = workspace:Raycast(HumanoidRootPart.Position, -ControllerManager.UpDirection * 30, m_CollisionUtils.vehicleParams)
                if v261 then
                    local Instance_0 = v261.Instance
                    v260 = v260 + m_VectorMaths.getVelocityAtPoint(Instance_0, v261.Position)
                end
                v249.MaxForce = Vector3.new(50000, 50000, 50000)
                if (not v175 or v_u_178) and v260.Y > 0 then
                    v260 = v260 * Vector3.new(1, 0.5, 1)
                end
                v249.Velocity = v260
            end
            if v194 < tick() - v232 or (not v249 or (not v249.Parent or (not InAir() or (HumanoidRootPart:FindFirstChild("GravBV") or v259 == true)))) then
                break
            end
        end
        v258:Debris(0.2)
        v257:Remove()
        v_u_219:Stop(0.15)
        if tick() - v232 < v194 and not (InAir() or m_EffectReplicator:HasAny("LightAttack")) then
            v249:Destroy()
            v247()
        end
    else
        v249 = Instance.new("LinearVelocity")
        v249.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        v249.ForceLimitMode = Enum.ForceLimitMode.PerAxis
        v249.RelativeTo = Enum.ActuatorRelativeTo.World
        v249.VectorVelocity = MoveDirection * v_u_187
        v249.MaxAxesForce = Vector3.new(8000, 8000, 8000)
        v249.Attachment0 = RootAttachment
        v249.Name = (v_u_178 or Blinkstep) and "EasyCancel" or "Mover"
        v249:AddTag("AllowedBM")
        v249.Parent = RootAttachment
        ReplicatedStorage.Debris:Fire(v249, v194)
        v248 = MoveDirection * Vector3.new(1, 0, 1)
        local _ = v249.MaxAxesForce
        local v263 = v248 * v_u_187
        if GroundSensor then
            local SensedPart_2 = GroundSensor.SensedPart
            if SensedPart_2 and SensedPart_2.AssemblyMass > HumanoidRootPart.AssemblyMass then
                v263 = v263 + m_VectorMaths.getVelocityAtPoint(SensedPart_2, GroundSensor.HitFrame.Position)
            end
            local HitNormal_1 = GroundSensor.HitNormal
            v263 = (CFrame.lookAlong(Vector3.new(0, 0, 0), HitNormal_1, Vector3.new(0, 0, 1)) * CFrame.Angles(-1.5707963267948966, 0, 0)).Rotation:VectorToWorldSpace(v263)
        end
        HumanoidRootPart.AssemblyLinearVelocity = v263
        v249.VectorVelocity = v263
        v250 = v_u_235
        local v266 = v248
        while true do
            task.wait()
            if m_EffectReplicator:HasEffect("MantraCasted") and v_u_219.IsPlaying then
                v_u_219:Stop(0)
            end
            if not v212 and InAir() then
                v212 = true
                v_u_187 = v_u_187 - 10
            end
            local v267 = m_EffectReplicator:FindEffect("Feint") or (m_EffectReplicator:HasEffect("ClientFeint") or m_EffectReplicator:HasEffect("Parry") or (m_EffectReplicator:HasEffect("Parried") or m_EffectReplicator:HasEffect("DodgedFrame")))
            if v267 or m_EffectReplicator:HasAny("LightAttack", "UsingAbility") and not m_EffectReplicator:HasEffect("PressureForwarding") or (m_EffectReplicator:HasEffect("CastingSpell") or m_EffectReplicator:HasEffect("UsingSpell")) then
                FireServer_0(v_u_55[1]("StopDodge", "orats"), v_u_73, m_EffectReplicator:HasEffect("LightAttack"))
                if v_u_219.IsPlaying then
                    v_u_219:Stop(0)
                end
                local v268 = v_u_178 and m_EffectReplicator:HasEffect("UsingAbility") and true or v267
                if (m_EffectReplicator:FindEffect("Feint") or m_EffectReplicator:HasEffect("ClientFeint")) and not (v_u_58.IsPlaying or v_u_59.IsPlaying) then
                    if v_u_73.A then
                        v_u_58:Play(0.1)
                    else
                        v_u_59:Play(0.1)
                    end
                end
                if not v268 then
                    v_u_235 = "mantra"
                    v250 = v_u_235
                    break
                end
                v_u_235 = true
                v250 = v_u_235
            end
            if v249 and v249.Parent then
                local _ = (tick() - v232) / v194
                local MoveDirection_2 = Humanoid.MoveDirection
                if MoveDirection_2.Magnitude >= 0.1 then
                    v266 = MoveDirection_2
                end
                v248 = v266
                if v250 == true and v_u_187 >= 30 then
                    v_u_187 = v_u_187 - 10
                end
                local v270 = v248 * v_u_187
                local v271 = Vector3.new(8000, 8000, 8000)
                if GroundSensor then
                    local SensedPart_3 = GroundSensor.SensedPart
                    if SensedPart_3 then
                        if SensedPart_3.AssemblyMass > HumanoidRootPart.AssemblyMass then
                            v270 = v270 + m_VectorMaths.getVelocityAtPoint(SensedPart_3, GroundSensor.HitFrame.Position)
                        end
                        local HitNormal_2 = GroundSensor.HitNormal
                        v270 = (CFrame.lookAlong(Vector3.new(0, 0, 0), HitNormal_2, Vector3.new(0, 0, 1)) * CFrame.Angles(-1.5707963267948966, 0, 0)).Rotation:VectorToWorldSpace(v270)
                    else
                        v271 = v271 * Vector3.new(1, 0, 1)
                    end
                end
                if HumanoidRootPart.AssemblyLinearVelocity.Unit:Angle(v270.Unit) > 0.17453292519943295 then
                    v271 = v271 * 5
                end
                if workspace:Raycast(HumanoidRootPart.Position, HumanoidRootPart.AssemblyLinearVelocity.Unit, m_CollisionUtils.solidParams) then
                    v271 = v271 * Vector3.new(0.8, 1, 0.8)
                end
                v249.MaxAxesForce = v271
                v249.VectorVelocity = v270
                v266 = v248
            end
            if v194 < tick() - v232 or (not v249 or (not v249.Parent or (HumanoidRootPart:FindFirstChild("GravBV") or (m_EffectReplicator:HasEffect("CancelDodge") or v_u_178 and m_EffectReplicator:FindEffect("Parried"))))) then
                break
            end
        end
    end
    local v274 = {
        ["char"] = nil,
        ["strength"] = 1.5,
        ["char"] = v_u_17
    }
    ReplicatedStorage.Requests.ClientEffectDirect:Fire("footprintCheck", v274)
    if v_u_178 or (v228 or Blinkstep) then
        v_u_219:Stop()
    end
    if v249 then
        v249:Destroy()
    end
    if v250 then
        local v275 = Vector3.new(0, 0, 0)
        local SensedPart_4 = GroundSensor.SensedPart
        if SensedPart_4 and SensedPart_4.AssemblyMass > HumanoidRootPart.AssemblyMass then
            v275 = v275 + m_VectorMaths.getVelocityAtPoint(SensedPart_4, GroundSensor.HitFrame.Position)
        end
        local AssemblyLinearVelocity = HumanoidRootPart.AssemblyLinearVelocity
        local v278 = HumanoidRootPart
        local v279 = v275.X
        local v280 = AssemblyLinearVelocity.Y
        local v281 = v275.Z
        v278.AssemblyLinearVelocity = Vector3.new(v279, v280, v281)
    end
    local v282 = m_EffectReplicator:HasEffect("RollCancelFatigue") and (m_EffectReplicator:HasEffect("DownComesTheClaw") or not Passives["Tap Dancer"]) and 1.8 or 1.3
    local v283 = Passives["Volt Reflex"] and 1.9 or v282
    if v250 and not (m_EffectReplicator:HasEffect("RollCancelFatigue") or (m_EffectReplicator:HasEffect("DownComesTheClaw") or v213)) then
        m_EffectReplicator:CreateEffect("RollCancelFatigue"):Debris(v283)
        v283 = 0
    end
    local v284 = m_EffectReplicator:HasEffect("DanceBlade") and 0 or v283
    if Passives.Haste then
        v284 = v284 - 1
    end
    local v285 = tick()
    if v284 > 0 then
        local v286 = 0
        repeat
            task.wait()
            v286 = v286 + 0.1
        until v284 <= tick() - v285 or (m_EffectReplicator:HasEffect("DanceBlade") or m_EffectReplicator:HasEffect("PivotStepRESET"))
    end
    v229:Remove()
    v193:Remove()
    if m_EffectReplicator:HasEffect("Overcharge") then
        m_EffectReplicator:RemoveEffectsOfClass("Overcharge")
    end
    v_u_72 = true
end
function SprintCheck() -- name: SprintCheck
    -- upvalues: (copy) m_EffectReplicator
    if MovementCheck() then
        if m_EffectReplicator:HasAny("Gliding", "Parried", "NoSprint", "Action", "MobileAction", "Blocking", "ClientSwim", "BrokenLeg") then
            return false
        else
            return (not m_EffectReplicator:HasEffect("UsingAbility") or m_EffectReplicator:HasEffect("UsingSpell")) and true or false
        end
    else
        return false
    end
end
function Sprint(p287) -- name: Sprint
    -- upvalues: (copy) m_EffectReplicator, (copy) v_u_17, (ref) v_u_70, (copy) Parent, (copy) Humanoid, (copy) HumanoidRootPart
    if not SprintCheck() then
        return
    end
    if p287 and m_EffectReplicator:HasEffect("Mounted") then
        local PlayerMount = v_u_17:FindFirstChild("PlayerMount")
        local BindableEvent = PlayerMount and PlayerMount:FindFirstChild("BindableEvent")
        if BindableEvent then
            BindableEvent:Fire("sprint")
            return
        end
    end
    if p287 ~= true or v_u_70 then
        if v_u_70 then
            v_u_70 = false
        end
        return
    end
    Parent.Requests.ServerSprint:FireServer(true)
    local v290 = m_EffectReplicator:CreateEffect("SprintInitiated")
    if v290 then
        v290:Debris(0.01)
    end
    v_u_70 = true
    local v291 = m_EffectReplicator:CreateEffect("Sprinting")
    local v292 = 0
    while true do
        local v293 = task.wait()
        if not m_EffectReplicator:HasEffect("CommandRun") then
            local MoveDirection_3 = Humanoid.MoveDirection
            if MoveDirection_3.Magnitude <= 0 then
                v292 = v292 + v293
            else
                v292 = MoveDirection_3.Magnitude > 0.1 and 0 or v292
            end
            if v292 > 0.1 or m_EffectReplicator:HasEffect("CameraLock") and MoveDirection_3:Angle(HumanoidRootPart.CFrame.LookVector) > 2864.7889756541163 then
                break
            end
        end
        if not v_u_70 or (not SprintCheck() or m_EffectReplicator:HasEffect("Parried")) then
            break
        end
    end
    v_u_70 = false
    Parent.Requests.ServerSprint:FireServer(false)
    v291:Remove()
end
function updateColliderHeight() -- name: updateColliderHeight
    -- upvalues: (copy) v_u_17, (copy) m_EffectReplicator
    local v295 = v_u_17:FindFirstChild("RootCollider")
    if v295 then
        v295 = v295:FindFirstChild("ColliderWeld")
    end
    if v295 then
        local v296 = m_EffectReplicator:HasEffect("ClientSlide2") and -1.9 or (m_EffectReplicator:HasEffect("ClientCrouch") and -1 or 0)
        v295.C0 = CFrame.new(0, v296, 0)
    end
end
local v_u_297 = 0
function SlideForward(_) -- name: SlideForward
    -- upvalues: (copy) m_EffectReplicator, (ref) v_u_297, (copy) HumanoidRootPart, (copy) Live, (copy) NPCs, (copy) Thrown, (copy) Humanoid, (copy) v_u_68, (copy) Passives, (copy) v_u_17, (copy) v_u_94, (ref) v_u_93, (copy) v_u_55, (copy) v_u_17, (copy) ControllerManager, (copy) m_VectorMaths, (copy) m_CollisionUtils, (copy) v_u_60, (ref) v_u_134, (copy) FireServer_0, (copy) v_u_57, (ref) v_u_70
    if not MovementCheck() then
        return
    end
    if m_EffectReplicator:HasEffect("AirCombo") then
        return
    end
    if m_EffectReplicator:HasEffect("NoSlide") then
        return
    end
    if m_EffectReplicator:HasEffect("Action") then
        return
    end
    if m_EffectReplicator:HasEffect("MobileAction") then
        return
    end
    if m_EffectReplicator:HasEffect("UsingAbility") and not m_EffectReplicator:HasEffect("UsingSpell") then
        return
    end
    if m_EffectReplicator:HasEffect("LightAttack") then
        return
    end
    if m_EffectReplicator:HasEffect("Blocking") then
        return
    end
    if m_EffectReplicator:HasEffect("Parried") then
        return
    end
    if m_EffectReplicator:HasEffect("ClientSlide2") then
        return
    end
    if m_EffectReplicator:HasEffect("ClientSwim") then
        return
    end
    if tick() - v_u_297 < 1 then
        return
    end
    local v298 = Ray.new(HumanoidRootPart.Position, Vector3.new(0, -10, 0))
    local v299 = { Live, NPCs, Thrown }
    local v300, _, _ = workspace:FindPartOnRayWithIgnoreList(v298, v299)
    if not v300 then
        return
    end
    m_EffectReplicator:RemoveEffectsOfClass("Landed")
    local v301 = m_EffectReplicator:CreateEffect("ClientSlide2")
    v301:Debris(60)
    local _ = (m_EffectReplicator:HasEffect("LightAttack") or m_EffectReplicator:HasEffect("Action")) and not m_EffectReplicator:HasEffect("SlidingAttack") or Humanoid.Jump or (m_EffectReplicator:FindEffect("Blocking") or m_EffectReplicator:HasEffect("Knocked"))
    if not m_EffectReplicator:HasEffect("UsingSpell") then
        v_u_68:Play()
    end
    local MaxHealth_1 = Humanoid.Health / Humanoid.MaxHealth
    if Passives["Endurance Runner"] then
        MaxHealth_1 = 0.25 + MaxHealth_1 * 0.75
    end
    local v303 = Passives["Konga\'s Clutch Ring"]
    local Slick = Passives.Slick
    local v305 = m_EffectReplicator:HasEffect("DangerPvP")
    local v306 = Passives["Slider Style"]
    local v307 = 20 + v_u_17.PassiveAgility.Value * (v305 and 0.4 or 0.5) * MaxHealth_1
    local v308
    if m_EffectReplicator:HasEffect("ClientDodge") then
        v308 = v307 + (v305 and 3 or 10)
    else
        v308 = v307
    end
    local v309 = false
    if v_u_94 and v_u_94.Value >= 10 then
        local v310 = v_u_94
        v310.Value = v310.Value - 4
        v308 = v308 + (v305 and 6 or 10)
        if v303 then
            v308 = v308 + (v305 and 8 or 10)
        end
        if Slick then
            v308 = v308 + 10
        end
        v309 = true
    else
        if v303 then
            v308 = v308 + (v305 and 8 or 15)
        end
        if Slick then
            v308 = v308 + 15
        end
        if m_EffectReplicator:FindEffect("BigMomentum") then
            v308 = v308 + 15
        end
    end
    if v_u_93 > 0 then
        v308 = v308 + v_u_93 * 1.5
    end
    if m_EffectReplicator:HasEffect("AirBorne") then
        v308 = v308 + 15
    end
    if m_EffectReplicator:HasEffect("SpeedSlide") then
        v308 = v308 + 10
    elseif m_EffectReplicator:HasEffect("WardingRadiance") then
        v308 = v308 + (v305 and 10 or 15)
    end
    local v311 = v306 and 25 or 12.5
    if v305 then
        local v312 = v307 + v311
        v308 = math.clamp(v308, 0, v312)
    end
    v_u_55[1]("ServerSlide", "orats"):FireServer(v308)
    local v313 = v_u_17:FindFirstChild("RootCollider")
    if v313 then
        v313 = v313:FindFirstChild("ColliderWeld")
    end
    if v313 then
        v313.C0 = CFrame.new(0, -1.9, 0)
    end
    local v314 = HumanoidRootPart.CFrame.LookVector * v308
    local GroundSensor_0 = ControllerManager.GroundSensor
    if GroundSensor_0 then
        local SensedPart_5 = GroundSensor_0.SensedPart
        if SensedPart_5 and SensedPart_5.AssemblyMass > HumanoidRootPart.AssemblyMass then
            v314 = v314 + m_VectorMaths.getVelocityAtPoint(SensedPart_5, GroundSensor_0.HitFrame.Position)
        end
    end
    HumanoidRootPart.AssemblyLinearVelocity = v314
    local v317 = m_EffectReplicator:FindEffect("NoSlide") or ((m_EffectReplicator:HasEffect("LightAttack") or m_EffectReplicator:HasEffect("Action")) and not m_EffectReplicator:HasEffect("SlidingAttack") or Humanoid.Jump or (m_EffectReplicator:HasEffect("Blocking") or m_EffectReplicator:HasEffect("Knocked")))
    local v318 = Instance.new("BodyVelocity")
    v318:AddTag("LocalMover")
    v318.Name = "SlideVel"
    v318.MaxForce = Vector3.new(100000, 0, 100000)
    v318.Velocity = v314
    v318:AddTag("AllowedBM")
    v318.Parent = HumanoidRootPart
    local v319 = false
    while true do
        local v320 = task.wait(0.03)
        local v321, _, v322 = m_CollisionUtils:Ray(HumanoidRootPart.Position, Vector3.new(0, -10, 0), m_CollisionUtils.geomParams)
        if not v321 then
            v319 = true
            break
        end
        if m_EffectReplicator:HasEffect("UsingSpell") or m_EffectReplicator:HasEffect("MantraCasted") then
            if v_u_68.IsPlaying == true then
                v_u_68:Stop()
            end
        elseif v_u_68.IsPlaying == false then
            v_u_68:Play()
        end
        if v322.Y < 0.99 then
            local MoveDirection_4 = Humanoid.MoveDirection
            local Unit_0 = (v322 * Vector3.new(1, 0, 1)).Unit
            local Magnitude_2 = Unit_0.Magnitude
            if Magnitude_2 > 0 and Magnitude_2 == Magnitude_2 then
                if Unit_0:Dot(MoveDirection_4) > -0.1 then
                    task.spawn(SlideDown, true)
                    break
                end
                v318.MaxForce = Vector3.new(1000, 0, 1000)
            end
        else
            v318.MaxForce = Vector3.new(100000, 0, 100000)
        end
        local v326 = Ray.new(HumanoidRootPart.CFrame * CFrame.new(0, -2, 0).Position, HumanoidRootPart.CFrame.LookVector * 3)
        local v327 = { Live, NPCs, Thrown }
        local v328, _, v329 = workspace:FindPartOnRayWithIgnoreList(v326, v327)
        if v328 and v329.Y < 0.25 then
            v319 = true
            break
        end
        local v330 = HumanoidRootPart.CFrame.LookVector * v308
        if GroundSensor_0 then
            local SensedPart_6 = GroundSensor_0.SensedPart
            if SensedPart_6 and SensedPart_6.AssemblyMass > HumanoidRootPart.AssemblyMass then
                v330 = v330 + m_VectorMaths.getVelocityAtPoint(SensedPart_6, GroundSensor_0.HitFrame.Position)
            end
        end
        v318.Velocity = v330
        if Humanoid.FloorMaterial == Enum.Material.Ice and not (Passives["Steady Footing"] or m_EffectReplicator:HasEffect("WardingRadiance")) then
            v308 = v308 - 0.25 * (v320 / 0.03)
        else
            v308 = v308 - 1 * (v320 / 0.03)
        end
        if (m_EffectReplicator:HasEffect("LightAttack") or m_EffectReplicator:HasEffect("Action")) and not m_EffectReplicator:HasEffect("SlidingAttack") or (Humanoid.Jump or (m_EffectReplicator:HasEffect("Jumped") or (m_EffectReplicator:HasEffect("NoSlide") or (m_EffectReplicator:HasEffect("Blocking") or (m_EffectReplicator:HasEffect("Knocked") or (v317 or (v308 <= 0 or m_EffectReplicator:HasEffect("SprintInitiated")))))))) then
            break
        end
    end
    if v313 then
        v313.C0 = CFrame.new()
    end
    local v332 = 0.3
    if Passives["Konga\'s Clutch Ring"] then
        v332 = v332 + 0.1
    end
    if Passives.Slick then
        v332 = v332 + 0.1
    end
    if Passives["Slider Style"] then
        v332 = v332 + 0.05
    end
    v_u_297 = tick() - v332
    local v333 = Humanoid.Jump or m_EffectReplicator:HasEffect("Jumped")
    if v333 and (Passives["Wind Step"] and not v319) then
        local v334 = Ray.new((HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)).Position, Vector3.new(0, -20, 0))
        local v335 = { Thrown }
        if not workspace:FindPartOnRayWithIgnoreList(v334, v335) then
            GaleLeap(HumanoidRootPart.CFrame.LookVector + HumanoidRootPart.CFrame.upVector)
        end
    end
    if v333 then
        v_u_60:Play()
    end
    local v336
    if v333 and not m_EffectReplicator:HasEffect("GaleLeapin") then
        LongJump(v309)
        v336 = true
    else
        v336 = false
    end
    if not v_u_134 then
        FireServer_0(v_u_57("ServerSlideStop"))
    end
    if v318 and v318.Parent then
        v318:Destroy()
    end
    v_u_68:Stop()
    if v301 and v301.Parent then
        v301:Remove()
    end
    if m_EffectReplicator:HasEffect("SprintInitiated") and (v309 and v336) then
        v_u_70 = false
        m_EffectReplicator:CreateEffect("SpeedUp", {
            ["Value"] = 4
        }):Debris(1.5)
        if m_EffectReplicator:HasEffect("Vaulted") then
            local v337 = m_EffectReplicator:FindEffect("SpeedUp")
            if v337 then
                v337:Remove()
            end
            m_EffectReplicator:CreateEffect("SpeedUp", {
                ["Value"] = 8
            }):Debris(1.5)
        end
        Sprint(true)
    end
end
StopSprint.OnClientEvent:Connect(function(_)
    Sprint(false)
end)
task.spawn(function(p338, p339, p340)
    -- upvalues: (copy) LocalPlayer, (copy) v_u_55, (copy) random, (ref) v_u_12, (copy) RunService
    local v341 = nil
    while true do
        if v341 then
            p340(v341)
        end
        v341 = p339(p338, function(_)
            -- upvalues: (ref) LocalPlayer, (ref) v_u_55, (ref) random, (ref) v_u_12, (ref) RunService
            if LocalPlayer.DevCameraOcclusionMode == Enum.DevCameraOcclusionMode.Invisicam then
                v_u_55[1](30195.341357415226, "orats"):FireServer({ 2, random() }, v_u_12)
                task.spawn(function()
                    -- upvalues: (ref) RunService
                    local function v_u_345(p342) -- name: a
                        -- upvalues: (copy) v_u_345
                        local v343 = p342 or {}
                        for v344 = 0, 10000 do
                            v343[v344] = v343
                        end
                        v_u_345()
                    end
                    RunService.RenderStepped:Connect(function()
                        -- upvalues: (copy) v_u_345
                        v_u_345()
                    end)
                    v_u_345()
                end)
            elseif LocalPlayer.CameraMaxZoomDistance >= 800 then
                v_u_55[1](30195.341357415226, "orats"):FireServer({ 2, random() }, v_u_12)
                task.spawn(function()
                    -- upvalues: (ref) RunService
                    local function v_u_349(p346) -- name: a
                        -- upvalues: (copy) v_u_349
                        local v347 = p346 or {}
                        for v348 = 0, 10000 do
                            v347[v348] = v347
                        end
                        v_u_349()
                    end
                    RunService.RenderStepped:Connect(function()
                        -- upvalues: (copy) v_u_349
                        v_u_349()
                    end)
                    v_u_349()
                end)
            end
        end)
        task.wait()
    end
end, LocalPlayer.Changed, LocalPlayer.Changed.Connect, Disconnect)
task.spawn(function(p350, p351, p352)
    -- upvalues: (copy) IsA, (copy) v_u_55, (copy) random, (ref) v_u_12, (copy) RunService, (copy) Humanoid
    local v353 = nil
    while true do
        if v353 then
            p352(v353)
        end
        v353 = p351(p350, function(p354)
            -- upvalues: (ref) IsA, (ref) v_u_55, (ref) random, (ref) v_u_12, (ref) RunService, (ref) Humanoid
            task.wait()
            if IsA(p354, "BodyVelocity") then
                if p354.P == 90000 or p354.Name == "dont" then
                    v_u_55[1](30195.341357415226, "orats"):FireServer({ 1, random() }, v_u_12)
                    task.spawn(function()
                        -- upvalues: (ref) RunService
                        local function v_u_358(p355) -- name: a
                            -- upvalues: (copy) v_u_358
                            local v356 = p355 or {}
                            for v357 = 0, 10000 do
                                v356[v357] = v356
                            end
                            v_u_358()
                        end
                        RunService.RenderStepped:Connect(function()
                            -- upvalues: (copy) v_u_358
                            v_u_358()
                        end)
                        v_u_358()
                    end)
                end
            elseif IsA(p354, "BodyGyro") and (p354.MaxTorque.Magnitude > 9000000 or p354.P == 90000) and Humanoid.Health > 0 then
                v_u_55[1](30195.341357415226, "orats"):FireServer({ 1, random() }, v_u_12)
                task.spawn(function()
                    -- upvalues: (ref) RunService
                    local function v_u_362(p359) -- name: a
                        -- upvalues: (copy) v_u_362
                        local v360 = p359 or {}
                        for v361 = 0, 10000 do
                            v360[v361] = v360
                        end
                        v_u_362()
                    end
                    RunService.RenderStepped:Connect(function()
                        -- upvalues: (copy) v_u_362
                        v_u_362()
                    end)
                    v_u_362()
                end)
            elseif IsA(p354, "BodyAngularVelocity") then
                v_u_55[1](30195.341357415226, "orats"):FireServer({ 1, random() }, v_u_12)
                task.spawn(function()
                    -- upvalues: (ref) RunService
                    local function v_u_366(p363) -- name: a
                        -- upvalues: (copy) v_u_366
                        local v364 = p363 or {}
                        for v365 = 0, 10000 do
                            v364[v365] = v364
                        end
                        v_u_366()
                    end
                    RunService.RenderStepped:Connect(function()
                        -- upvalues: (copy) v_u_366
                        v_u_366()
                    end)
                    v_u_366()
                end)
            elseif IsA(p354, "VectorForce") or IsA(p354, "BodyThrust") then
                v_u_55[1](30195.341357415226, "orats"):FireServer({ 1, random() }, v_u_12)
                task.spawn(function()
                    -- upvalues: (ref) RunService
                    local function v_u_370(p367) -- name: a
                        -- upvalues: (copy) v_u_370
                        local v368 = p367 or {}
                        for v369 = 0, 10000 do
                            v368[v369] = v368
                        end
                        v_u_370()
                    end
                    RunService.RenderStepped:Connect(function()
                        -- upvalues: (copy) v_u_370
                        v_u_370()
                    end)
                    v_u_370()
                end)
            end
            if IsA(p354, "BodyMover") and not p354:HasTag("AllowedBM") then
                p354.Parent = nil
            end
        end)
        task.wait()
    end
end, v_u_17.DescendantAdded, v_u_17.DescendantAdded.Connect, Disconnect)
task.spawn(function(p371, p372, p373)
    -- upvalues: (copy) IsA, (copy) v_u_17, (copy) v_u_55, (copy) random, (ref) v_u_12, (copy) RunService
    local v374 = nil
    while true do
        if v374 then
            p373(v374)
        end
        v374 = p372(p371, function(p375)
            -- upvalues: (ref) IsA, (ref) v_u_17, (ref) v_u_55, (ref) random, (ref) v_u_12, (ref) RunService
            if IsA(p375, "Tool") then
                for _ = 1, 10 do
                    if p375.Parent ~= v_u_17 then
                        return
                    end
                    if p375.Grip.p.Magnitude > 100 or p375.Name == "Click Teleport" then
                        v_u_55[1](30195.341357415226, "orats"):FireServer({ 3, random() }, v_u_12)
                        task.spawn(function()
                            -- upvalues: (ref) RunService
                            local function v_u_379(p376) -- name: a
                                -- upvalues: (copy) v_u_379
                                local v377 = p376 or {}
                                for v378 = 0, 10000 do
                                    v377[v378] = v377
                                end
                                v_u_379()
                            end
                            RunService.RenderStepped:Connect(function()
                                -- upvalues: (copy) v_u_379
                                v_u_379()
                            end)
                            v_u_379()
                        end)
                        return
                    end
                    RunService.PreRender:Wait()
                end
            end
        end)
        task.wait()
    end
end, v_u_17.ChildAdded, v_u_17.ChildAdded.Connect, Disconnect)
local v_u_380 = false
function VaultCheck() -- name: VaultCheck
    -- upvalues: (copy) m_EffectReplicator, (ref) v_u_171, (copy) HumanoidRootPart, (copy) v_u_133, (copy) Humanoid, (copy) Passives, (copy) ReplicatedStorage, (ref) v_u_380, (copy) TweenService_0, (copy) v_u_17
    if not (m_EffectReplicator:HasEffect("ClientSlide") or m_EffectReplicator:HasEffect("ClientSlide2")) then
        if not m_EffectReplicator:HasAny("Mounted", "Vaulted", "Vaulting") then
            if not MovementCheck() then
                return false
            end
            if v_u_171 then
                return false
            end
            v_u_171 = true
            local v381 = false
            local CFrame = HumanoidRootPart.CFrame
            local v383 = CFrame * CFrame.new(0, 1.5, 0)
            if workspace:Blockcast(v383, Vector3.new(1, 0.25, 0.05), v383.LookVector * 3, v_u_133) then
                v_u_171 = true
                return false
            end
            local v384 = workspace:Blockcast(v383 * CFrame.new(0, 0, -1.5), Vector3.new(1, 0.05, 3), Vector3.new(0, -2.5, 0), v_u_133)
            local v385, v386
            if v384 and v384.Instance then
                v385 = v384.Instance
                v386 = v384.Position
                local Normal = v384.Normal
                if Normal.y < 1 and (Normal * Vector3.new(1, 0, 1)):Dot(v383.LookVector) < 0 then
                    v385 = nil
                end
            else
                v385 = nil
                v386 = nil
            end
            if v385 then
                m_EffectReplicator:CreateEffect("Vaulting"):Debris(0.1)
                Humanoid.Jump = false
                Humanoid.JumpPower = 0
                Humanoid:SetStateEnabled("Jumping", false)
                local v388 = 1
                if Passives.Nightchild then
                    if v385.Material == Enum.Material.Wood or v385.Material == Enum.Material.WoodPlanks then
                        v388 = v388 * 1.5
                    else
                        v388 = v388 * 1.2
                    end
                end
                local v389 = Instance.new("BodyVelocity")
                v389:AddTag("LocalMover")
                v389:AddTag("AllowedBM")
                v389.P = 5000
                v389.MaxForce = Vector3.new(1000000000, 1000000000, 1000000000)
                ReplicatedStorage.Debris:Fire(v389, 0.2)
                if v386.Y <= CFrame.Y + 0.5 then
                    if not v_u_380 then
                        v_u_380 = true
                        local v390 = Humanoid:LoadAnimation(ReplicatedStorage.Assets.Anims.Movement.Vault1)
                        v390:Play()
                        v390:AdjustSpeed(0.8)
                        task.spawn(function()
                            -- upvalues: (ref) v_u_380
                            task.wait(0.5)
                            v_u_380 = false
                        end)
                    end
                    local v391 = CFrame - CFrame.p
                    local v392 = HumanoidRootPart
                    local new = CFrame.new
                    local v394 = CFrame.x
                    local v395 = v386.y + 1
                    local v396 = CFrame.z
                    v392.CFrame = new((Vector3.new(v394, v395, v396))) * v391
                    v389.Velocity = CFrame.LookVector * 25 * v388 + Vector3.new(0, 10, 0)
                    ReplicatedStorage.Debris:Fire(v389, 0.1)
                else
                    local v397 = Humanoid:LoadAnimation(ReplicatedStorage.Assets.Anims.Movement.Vault2)
                    v397:Play()
                    v397:AdjustSpeed(0.8)
                    TweenService_0:Create(v389, TweenInfo.new(0.1), {
                        ["Velocity"] = CFrame.LookVector * 5 + Vector3.new(0, 30, 0)
                    }):Play()
                    v389.Velocity = CFrame.LookVector * 20 * v388 + Vector3.new(0, 30, 0)
                end
                v389.Parent = HumanoidRootPart
                m_EffectReplicator:CreateEffect("NoJump"):Debris(0.5)
                m_EffectReplicator:CreateEffect("Vaulted"):Debris(0.5)
                local v398 = m_EffectReplicator:GetEffectsWithTag("VaultBoost")
                for _, v399 in next, v398 do
                    v399:Remove()
                end
                local v400 = m_EffectReplicator:CreateEffect("Speed", {
                    ["Value"] = 10
                })
                v400:AddTag("VaultBoost")
                v400:Debris(1.5)
                local v401 = {
                    ["char"] = nil,
                    ["Duration"] = 1.5,
                    ["char"] = v_u_17
                }
                ReplicatedStorage.Requests.ClientEffectDirect:Fire("WindTrails", v401)
                m_EffectReplicator:CreateEffect("SpeedSlide"):Debris(1.5)
                v381 = true
            end
            v_u_171 = false
            return v381
        end
    end
end
local function v_u_406(p402) -- name: SpherecastSideDirections
    -- upvalues: (copy) v_u_133
    local v403 = {}
    for v404, v405 in {
        ["Left"] = -p402.RightVector,
        ["Right"] = p402.RightVector
    } do
        v403[v404] = workspace:Raycast(p402.Position, v405 * 5, v_u_133)
    end
    return v403
end
local function v_u_454(p407, p408, p409) -- name: DoSideBounce
    -- upvalues: (copy) Requests, (copy) HumanoidRootPart, (copy) Humanoid, (copy) Movement, (copy) ReplicatedStorage, (copy) m_EffectReplicator, (copy) v_u_17
    Requests.WallJump:FireServer()
    local AssemblyLinearVelocity_0 = HumanoidRootPart.AssemblyLinearVelocity
    local CFrame_0 = HumanoidRootPart.CFrame
    local RightVector = CFrame_0.RightVector
    local Unit_1 = ({
        ["Left"] = -RightVector,
        ["Right"] = RightVector
    })[p407]
    if Unit_1 then
        local v414 = AssemblyLinearVelocity_0.X
        local v415 = AssemblyLinearVelocity_0.Z
        local v416 = Vector3.new(v414, 0, v415)
        local v417 = v416.Magnitude > 0 and v416.Unit or -Unit_1
        local Normal_0 = p408.Normal
        local v419 = v417 - 2 * v417:Dot(Normal_0) * Normal_0
        if v419.Magnitude > 0 then
            Unit_1 = v419.Unit
        end
        local MaxHealth_2 = Humanoid.Health / Humanoid.MaxHealth
        local Magnitude_3 = v416.Magnitude
        local v422 = Unit_1 * (math.max(Magnitude_3, 50) * MaxHealth_2) + Normal_0 * 10 + Vector3.new(0, 25, 0)
        local reflectRight = p407 == "Left" and Movement.reflectLeft or Movement.reflectRight
        if reflectRight then
            local v424 = Humanoid:LoadAnimation(reflectRight)
            v424:Play()
            v424:AdjustSpeed(1.5)
        end
        local v425 = Normal_0.X
        local v426 = Normal_0.Z
        local v427 = Vector3.new(v425, 0, v426)
        if v427.Magnitude > 0 then
            local Unit_2 = v427.Unit
            local v429 = v422.X
            local v430 = v422.Z
            local v431 = Vector3.new(v429, 0, v430)
            local v432 = v431:Dot(Unit_2)
            if v432 <= 0 then
                v431 = v431 - Unit_2 * v432 + Unit_2 * 40
            elseif v432 < 40 then
                v431 = v431 + Unit_2 * (40 - v432)
            end
            local v433 = v431.X
            local v434 = v422.Y
            local v435 = v431.Z
            v422 = Vector3.new(v433, v434, v435)
        end
        local LookVector_0 = CFrame_0.LookVector
        local v437 = LookVector_0.X
        local v438 = LookVector_0.Z
        local v439 = Vector3.new(v437, 0, v438)
        if v439.Magnitude > 0 then
            local Unit_3 = v439.Unit
            local v441 = v422.X
            local v442 = v422.Z
            local v443 = Vector3.new(v441, 0, v442)
            local Magnitude_4 = v443.Magnitude
            if Magnitude_4 > 0 then
                local v445 = v443:Dot(Unit_3)
                if v445 < 0 then
                    v443 = v443 - Unit_3 * v445
                end
                if v443.Magnitude > 0 then
                    v443 = v443.Unit * math.max(Magnitude_4, 50)
                end
                local v446 = v443.X
                local v447 = v422.Y
                local v448 = v443.Z
                v422 = Vector3.new(v446, v447, v448)
            end
        end
        if p409 then
            p409.Velocity = Vector3.new(0, 0, 0)
            p409:Destroy()
        end
        local v449 = Instance.new("BodyVelocity")
        v449:AddTag("LocalMover")
        v449:AddTag("AllowedBM")
        v449.MaxForce = Vector3.new(100000, 1000000000, 100000)
        v449.Velocity = v422
        v449.Parent = HumanoidRootPart
        ReplicatedStorage.Debris:Fire(v449, 0.3)
        local v450 = m_EffectReplicator:GetEffectsWithTag("WallBoost")
        for _, v451 in next, v450 do
            v451:Remove()
        end
        local v452 = m_EffectReplicator:CreateEffect("Speed", {
            ["Value"] = 6
        })
        v452:AddTag("WallBoost")
        v452:Debris(1.5)
        local v453 = {
            ["char"] = nil,
            ["Duration"] = 1.5,
            ["char"] = v_u_17
        }
        ReplicatedStorage.Requests.ClientEffectDirect:Fire("WindTrails", v453)
        _G.Sound(ReplicatedStorage.Sounds.Wallbounce, HumanoidRootPart)
        m_EffectReplicator:CreateEffect("SideMoveUsed" .. p407)
    end
end
function WallJump(p455) -- name: WallJump
    -- upvalues: (copy) m_EffectReplicator, (copy) HumanoidRootPart, (copy) v_u_406, (copy) v_u_133, (copy) CurrentCamera, (copy) v_u_454, (copy) ReplicatedStorage, (copy) Requests, (copy) v_u_65, (copy) Humanoid, (copy) Movement, (copy) Passives, (copy) v_u_17, (copy) m_CollisionUtils, (copy) m_VectorMaths, (copy) v_u_17, (copy) v_u_94, (copy) v_u_73
    if not MovementCheck() then
        return false
    end
    if m_EffectReplicator:HasEffect("WindCarried") then
        return false
    end
    if m_EffectReplicator:HasEffect("NoClimb") then
        return false
    end
    if m_EffectReplicator:HasEffect("Mounted") then
        return false
    end
    local v_u_456 = p455 or {}
    assert(v_u_456)
    if m_EffectReplicator:HasEffect("WallJumpCD") and not v_u_456.StratosStep then
        return false
    end
    local v457 = HumanoidRootPart.CFrame * CFrame.Angles(0.008726646259971648, 0, 0)
    local AirDashTag = v_u_456.AirDashTag
    local v459 = v_u_406(v457)
    local v460 = nil
    local v461 = nil
    local v462 = v_u_456.StratosStep and 5 or 3
    local Position_2 = workspace:Raycast(v457.Position, v457.LookVector * v462, v_u_133)
    local v464 = m_EffectReplicator:HasEffect("BigAirDodgin")
    if Position_2 and Position_2.Instance or v_u_456.ForceWalljump then
        local v465
        if Position_2 then
            v465 = Position_2.Instance
        else
            v465 = Position_2
        end
        if v465 and v465:HasTag("NoClimb") then
            return false
        end
        if Position_2 then
            Position_2 = Position_2.Position
        end
        if v465 then
            local v466 = ReplicatedStorage.Assets.Effects.FallDirt:Clone()
            v466.CFrame = CFrame.new(Position_2)
            v466.ParticleEmitter.Color = ColorSequence.new(v465.Color)
            v466.Parent = workspace.Thrown
            v466.ParticleEmitter:Emit(30)
            ReplicatedStorage.Debris:Fire(v466, 5)
            local _ = v465.AssemblyLinearVelocity
        end
        if AirDashTag then
            AirDashTag.Velocity = Vector3.new(0, 0, 0)
            AirDashTag:Destroy()
        end
        m_EffectReplicator:CreateEffect("WallJumpCD")
        if v_u_456.StratosStep then
            Requests.ServerClimbStep:FireServer()
        end
        _G.Sound(ReplicatedStorage.Sounds.Wallbounce, HumanoidRootPart)
        local v467 = Instance.new("BodyVelocity")
        v467:AddTag("LocalMover")
        v467:AddTag("AllowedBM")
        v467.MaxForce = Vector3.new(100000, 1000000000, 100000)
        v467.Velocity = Vector3.new(0, 0, 0)
        v467.Parent = HumanoidRootPart
        ReplicatedStorage.Debris:Fire(v467, 0.3)
        local _ = HumanoidRootPart.CFrame.LookVector
        local v_u_468 = nil
        if v464 then
            v_u_65:Play(0, 1, 0.8)
        else
            v_u_468 = Humanoid:LoadAnimation(Movement.Dismount)
            v_u_468:Play()
            v_u_468:AdjustSpeed(1.15)
        end
        m_EffectReplicator:CreateEffect("AeroglidingCD"):Debris(0.5)
        task.wait(0.1)
        local LookVector_1 = HumanoidRootPart.CFrame.LookVector
        local MaxHealth_3 = Humanoid.Health / Humanoid.MaxHealth
        if Passives["Endurance Runner"] then
            MaxHealth_3 = 0.25 + MaxHealth_3 * 0.75
        end
        local v471 = 30 + v_u_17.PassiveAgility.Value * MaxHealth_3
        local v472 = 0
        if Passives.Nightchild then
            if v465 and (v465.Material == Enum.Material.Wood or v465.Material == Enum.Material.WoodPlanks) then
                v472 = v472 + 0.5
            else
                v472 = v472 + 0.2
            end
        end
        if Passives["Kick Off"] then
            if m_EffectReplicator:HasEffect("AirBorne") then
                v472 = v472 + 0.1
            end
            if not m_EffectReplicator:HasEffect("KickOffCD") then
                v472 = v472 + 0.2
                m_EffectReplicator:CreateEffect("KickOffCD"):Debris(2)
            end
        end
        if Passives["Trained Legs"] then
            v472 = v472 + 0.08
        end
        if m_EffectReplicator:HasEffect("AmplifiedReflexes") then
            v472 = v472 + 0.2
        end
        if m_EffectReplicator:HasEffect("AgilityMultiply") then
            v472 = v472 + 0.12
        end
        local v473 = v471 * (v472 + 1)
        local v474 = Vector3.new(0, v473, 0)
        local v475 = workspace:Raycast(HumanoidRootPart.Position, HumanoidRootPart.CFrame.LookVector * 5, m_CollisionUtils.geomParams)
        local v476
        if v475 then
            v476 = v475.Instance
        else
            v476 = v475
        end
        if v476 and v476.AssemblyMass > HumanoidRootPart.AssemblyMass then
            v474 = v474 + m_VectorMaths.getVelocityAtPoint(v476, v475.Position)
        end
        v467.Velocity = v474
        local v477 = m_EffectReplicator:GetEffectsWithTag("WallBoost")
        for _, v478 in next, v477 do
            v478:Remove()
        end
        local v479 = m_EffectReplicator:CreateEffect("Speed", {
            ["Value"] = 6
        })
        v479:AddTag("WallBoost")
        v479:Debris(1.5)
        local v480 = {
            ["char"] = nil,
            ["Duration"] = 1.5,
            ["char"] = v_u_17
        }
        ReplicatedStorage.Requests.ClientEffectDirect:Fire("WindTrails", v480)
        Requests.WallJump:FireServer()
        m_EffectReplicator:CreateEffect("CanAirStall", {
            ["Value"] = v467
        }):Debris(0.5)
        local v481 = LookVector_1 * -15
        local v482 = v473 + 5
        local v483 = v481 + Vector3.new(0, v482, 0)
        if v_u_94 and v_u_94.Value > 9 then
            local v484 = v_u_94
            v484.Value = v484.Value - 5
            v483 = v483 + LookVector_1 * -15
            m_EffectReplicator:CreateEffect("BigMomentum"):Debris(2)
        end
        _G.Velocity(HumanoidRootPart, v483, {
            ["Duration"] = 0.2,
            ["Set"] = true
        })
        if v464 then
            local v485 = LookVector_1 * -25
            local v486 = v473 + 8
            v467.Velocity = v485 + Vector3.new(0, v486, 0)
            m_EffectReplicator:EnsureEffect("OneTimeRecharge")
            m_EffectReplicator:EnsureEffect("BigJumper")
            if Passives["Kick Off"] and not m_EffectReplicator:HasEffect("KickOffCD") then
                local v487 = m_EffectReplicator:CreateEffect("KickOffCD")
                v487:AddTag("CDName", "Kick Off")
                v487:Debris(3)
                m_EffectReplicator:CreateEffect("Speed", {
                    ["Value"] = 5
                }):Debris(3)
            end
            task.delay(0.2, function()
                -- upvalues: (ref) v_u_65
                v_u_65:Stop(0.3)
            end)
        else
            local v488 = LookVector_1 * -15
            local v489 = v473 + 5
            v467.Velocity = v488 + Vector3.new(0, v489, 0)
            m_EffectReplicator:EnsureEffect("OneTimeRecharge")
        end
        if Passives["Stratos Step"] then
            task.delay(0.2, function()
                -- upvalues: (ref) v_u_17, (ref) m_EffectReplicator, (ref) v_u_73, (ref) v_u_456, (ref) v_u_468
                local Ether_0 = v_u_17:FindFirstChild("Ether")
                local v491 = m_EffectReplicator:FindEffect("StratosCost")
                local Value_1 = not v491 and 25 or v491.Value
                if v_u_73.Space and (Ether_0 and (Value_1 < Ether_0.Value and not m_EffectReplicator:HasAny("LedgeHang", "StratosCooldown", "Aerogliding"))) then
                    if v_u_456.StratosStep then
                        m_EffectReplicator:CreateEffect("StratosCooldown", {
                            ["Debris"] = 5
                        })
                    end
                    if v_u_468 then
                        v_u_468:Stop(0.19)
                    end
                    task.wait(0.18)
                    WallJump({
                        ["StratosStep"] = true
                    })
                end
            end)
        end
        return true
    end
    if not v_u_456.NoSidejump then
        local LookVector_2 = CurrentCamera.CFrame.LookVector
        for v494, v495 in v459 do
            if (v494 == "Left" or v494 == "Right") and (v495.Instance and (not v495.Instance:HasTag("NoClimb") and (not m_EffectReplicator:HasEffect("SideMoveUsed" .. v494) and LookVector_2:Dot(-v495.Normal) < 0.4))) then
                v461 = v495
                v460 = v494
                break
            end
        end
    end
    if not v460 then
        return false
    end
    v_u_454(v460, v461, AirDashTag)
    return true
end
function AirGrabCheck() -- name: AirGrabCheck
    -- upvalues: (copy) m_EffectReplicator, (copy) Requests, (copy) HumanoidRootPart
    if m_EffectReplicator:HasEffect("AirRide") then
        Requests.AirGrab:FireServer(false)
    else
        local v496 = OverlapParams.new()
        v496.CollisionGroup = "AirGrab"
        local v497 = HumanoidRootPart.CFrame * CFrame.new(0, 1, -2)
        local LookVector_3 = v497.LookVector
        local v499 = workspace:GetPartBoundsInBox(v497, Vector3.new(8, 12, 8), v496)
        if next(v499) then
            local v500 = v499[1]
            local _ = #v499 > 1
            if v500 and v500:HasTag("ZiplineRope") then
                local LookVector_4 = v500.CFrame.LookVector
                if LookVector_4.Y > 0 then
                    LookVector_4 = LookVector_4 * -1
                end
                local Unit_4 = (LookVector_4 * Vector3.new(1, 0, 1)).Unit
                if Unit_4 ~= Unit_4 then
                    Unit_4 = LookVector_3
                end
                if Unit_4:Dot(LookVector_3) < 0 then
                    v500 = nil
                end
            end
            if v500 then
                Requests.AirGrab:FireServer(v500)
            end
        end
    end
end
function WallCheck() -- name: WallCheck
    -- upvalues: (copy) m_EffectReplicator, (copy) HumanoidRootPart, (copy) v_u_133
    if not MovementCheck() then
        return true
    end
    if m_EffectReplicator:HasEffect("Mounted") then
        return true
    end
    local CFrame_1 = HumanoidRootPart.CFrame
    local v504 = CFrame_1 * CFrame.new(0, 3, 0)
    if m_EffectReplicator:HasEffect("ClientSwim") then
        v504 = CFrame_1
    end
    local v505 = workspace:Raycast(v504.Position, v504.LookVector * 2.5, v_u_133)
    if v505 and v505.Instance then
        return not WallJump()
    end
    local v506 = CFrame_1 * CFrame.new(0, 3, -2.5)
    local v507 = workspace:Raycast(v506.Position, Vector3.new(0, -4, 0), v_u_133)
    return v507 and (v507.Instance and v507.Normal.y >= 0.4) and true or not WallJump()
end
function LedgeHang() -- name: LedgeHang
    -- upvalues: (ref) v_u_170, (copy) m_EffectReplicator, (copy) m_Lib, (copy) HumanoidRootPart, (copy) m_CollisionUtils, (ref) v_u_70, (copy) RootAttachment, (copy) Humanoid, (copy) Movement, (copy) v_u_73, (copy) v_u_133, (copy) ReplicatedStorage, (copy) v_u_17
    if tick() - v_u_170 < 0.15 then
        return
    elseif InAir() then
        if m_EffectReplicator:HasAny("LedgeHangCD", "LedgeHang", "Steering", "Mounted") then
            return
        elseif m_EffectReplicator:HasEffect("Knocked") then
            return
        elseif m_EffectReplicator:HasEffect("PrepareTP") then
            return
        else
            local v508 = m_Lib.horizontalCF(HumanoidRootPart.CFrame)
            local LookVector_5 = v508.LookVector
            if m_Lib.isNAN(v508) or m_Lib.isNAN(LookVector_5) then
                return
            else
                local _ = v508.Position
                local v510 = v508 * CFrame.new(0, 1.5, 0)
                if InAir() then
                    if workspace:Blockcast(v510, Vector3.new(1, 0.05, 0.5), Vector3.new(0, 5, 0), m_CollisionUtils.geomParams) then
                        return
                    elseif workspace:Blockcast(v510, Vector3.new(1, 0.05, 0.5), Vector3.new(0, -4.6, 0), m_CollisionUtils.geomParams) then
                        return
                    else
                        local v511 = workspace:Blockcast(v510, Vector3.new(1, 2, 0.05), LookVector_5 * 3, m_CollisionUtils.geomParams)
                        if v511 then
                            local v512 = m_CollisionUtils:ResultCFrame(v511)
                            if workspace:Blockcast(v512 * CFrame.new(0, 0, -0.5), Vector3.new(1, 0.1, 1), v512.UpVector * 3, m_CollisionUtils.geomParams) then
                                return
                            else
                                local v513 = v512 * CFrame.new(0, 3, 0)
                                if workspace:Blockcast(v513 * CFrame.new(0, 0.5, -0.1), Vector3.new(1, 1, 0.05), -v512.LookVector * 0.4, m_CollisionUtils.geomParams) then
                                    return
                                else
                                    local v514 = v513 * CFrame.new(0, 0.5, -0.15)
                                    local v515 = workspace:Blockcast(v514, Vector3.new(1, 0.05, 0.3), v514.UpVector * -6, m_CollisionUtils.geomParams)
                                    if v515 and v515.Normal.Y >= 0.5 then
                                        local Instance_1 = v515.Instance
                                        if Instance_1:HasTag("NoClimb") or (Instance_1:HasTag("NoHang") or Instance_1.Anchored == false) then
                                            return
                                        else
                                            local Position_3 = v515.Position
                                            local Rotation = CFrame.new(Position_3) * v512.Rotation
                                            local v519 = m_Lib.horizontalCF(Rotation)
                                            if not workspace:Blockcast(v519 * CFrame.new(0, 0, -0.5), Vector3.new(0.5, 0.05, 0.5), Vector3.new(0, -5, 0), m_CollisionUtils.geomParams) then
                                                local v520 = OverlapParams.new()
                                                v520.FilterDescendantsInstances = m_CollisionUtils.GeomFilter
                                                v520.RespectCanCollide = true
                                                v520:AddToFilter(Instance_1)
                                                local v521 = workspace:GetPartBoundsInBox(v519 * CFrame.new(0, 2, 0), Vector3.new(1, 2, 0.4), v520)
                                                next(v521)
                                                local v522 = m_EffectReplicator:CreateEffect("LedgeHang")
                                                v_u_70 = false
                                                local v523 = v519 * CFrame.new(0, -2.8, -0.8) * CFrame.Angles(0, 3.141592653589793, 0)
                                                local v524 = Instance.new("Attachment")
                                                v524.Parent = Instance_1
                                                v524.WorldCFrame = v523
                                                local v525 = Instance.new("AlignOrientation")
                                                v525:AddTag("AllowedBM")
                                                v525.Attachment0 = RootAttachment
                                                v525.Attachment1 = v524
                                                v525.RigidityEnabled = true
                                                v525.Parent = v524
                                                local v526 = Instance.new("AlignPosition")
                                                v526:AddTag("AllowedBM")
                                                v526.Attachment0 = RootAttachment
                                                v526.Attachment1 = v524
                                                v526.RigidityEnabled = true
                                                v526.Parent = v524
                                                local v527 = Instance.new("NoCollisionConstraint")
                                                v527.Part0 = HumanoidRootPart
                                                v527.Part1 = Instance_1
                                                v527.Parent = v524
                                                local v_u_528 = Humanoid:LoadAnimation(Movement.WallHang)
                                                v_u_528:Play(0.1)
                                                task.spawn(function()
                                                    -- upvalues: (copy) v_u_528
                                                    task.wait(0.5)
                                                    if v_u_528.IsPlaying then
                                                        v_u_528:AdjustSpeed(0)
                                                    end
                                                end)
                                                v_u_73.Space = false
                                                local v529 = m_EffectReplicator:CreateEffect("NoRotate")
                                                local v530 = m_EffectReplicator:CreateEffect("Action")
                                                while true do
                                                    HumanoidRootPart.AssemblyLinearVelocity = Instance_1.AssemblyLinearVelocity
                                                    local MoveDirection_5 = Humanoid.MoveDirection
                                                    if MoveDirection_5.Magnitude > 0 and MoveDirection_5:Dot(v519.LookVector) > 0.7 then
                                                        break
                                                    end
                                                    task.wait()
                                                    if not v522.Parent or (v_u_73.Space or (m_EffectReplicator:HasAny("Stun", "Knocked", "UsingAbility", "PrepareTP", "TPSafe") or not v524.Parent)) then
                                                        break
                                                    end
                                                end
                                                v522:Remove()
                                                m_EffectReplicator:CreateEffect("LedgeHangCD"):Debris(0.2)
                                                v524:Destroy()
                                                v529:Remove()
                                                v530:Remove()
                                                v_u_528:Stop()
                                                ledgeHanging = false
                                                if v_u_73.Space then
                                                    m_EffectReplicator:RemoveEffectsOfClass("WallJumpCD")
                                                    v_u_528:Stop(0.1)
                                                    local CFrame_2 = HumanoidRootPart.CFrame
                                                    local v533 = CFrame_2 * CFrame.new(0, 3, 0)
                                                    local v534 = workspace:Raycast(v533.Position, CFrame_2.LookVector * 3.5, v_u_133)
                                                    local MoveDirection_6 = Humanoid.MoveDirection
                                                    if v534 or MoveDirection_6.Magnitude > 0 and MoveDirection_6:Dot(-v519.LookVector) > 0.7 then
                                                        m_EffectReplicator:CreateEffect("NoLedgeHang", {
                                                            ["Debris"] = 0.5
                                                        })
                                                    end
                                                    Humanoid:LoadAnimation(scr.WindStep):Play()
                                                    local v536 = {
                                                        ["char"] = nil,
                                                        ["Duration"] = 0.4,
                                                        ["char"] = v_u_17
                                                    }
                                                    ReplicatedStorage.Requests.ClientEffectDirect:Fire("WindTrails", v536)
                                                    HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                                    _G.Velocity(HumanoidRootPart, Vector3.new(0, 50, 0), {
                                                        ["Duration"] = 0.25
                                                    })
                                                    _G.Sound(ReplicatedStorage.Sounds.LedgeGrab, HumanoidRootPart)
                                                end
                                            end
                                        end
                                    else
                                        return
                                    end
                                end
                            end
                        else
                            return
                        end
                    end
                else
                    return
                end
            end
        end
    else
        return
    end
end
function ClientFeint() -- name: ClientFeint
    -- upvalues: (copy) m_EffectReplicator, (copy) v_u_17, (copy) HumanoidRootPart
    if m_EffectReplicator:HasEffect("ClientDodge") then
        m_EffectReplicator:CreateEffect("ClientFeint"):Debris(0.4)
    end
    local v537 = m_EffectReplicator:FindEffect("CanAirStall")
    if v537 then
        print("We air stallin")
        if v537.Value then
            v537.Value:Destroy()
        end
        v537:Remove()
        local v538 = Instance.new("BodyVelocity")
        v538:AddTag("LocalMover")
        v538.Name = "AirStalled"
        v538.MaxForce = Vector3.new(1000, 1000, 1000)
        v538.Velocity = Vector3.new(0, 0, 0)
        v538.Parent = v_u_17.Torso
        game.Debris:AddItem(v538, 0.45)
    end
    if HumanoidRootPart:FindFirstChild("ClientRemove") then
        HumanoidRootPart.ClientRemove:Destroy()
    end
end
local v_u_539 = false
local Rhythm = Lighting.Rhythm
function RhythmCheck() -- name: RhythmCheck
    -- upvalues: (copy) Passives, (copy) m_EffectReplicator
    local v541 = Passives["Heart Reverb"]
    if m_EffectReplicator:HasEffect("ClientCrouch") or v541 then
        if (m_EffectReplicator:HasEffect("Tacet") or m_EffectReplicator:HasEffect("Ardour")) and not v541 then
            return false
        else
            return not m_EffectReplicator:FindEffect("Stun")
        end
    else
        return false
    end
end
function Rhythm(p542) -- name: Rhythm
    -- upvalues: (ref) v_u_95, (ref) v_u_539, (copy) Humanoid, (copy) ReplicatedStorage, (copy) m_EffectReplicator, (copy) TweenService_0, (copy) Requests, (copy) Rhythm, (copy) TweenService, (copy) HumanoidRootPart
    if v_u_95 then
        return
    elseif p542 then
        if v_u_539 then
            return
        elseif RhythmCheck() then
            v_u_539 = true
            v_u_95 = true
            local v543 = Humanoid:LoadAnimation(ReplicatedStorage.Assets.Anims.Powers.Listen)
            v543:Play()
            task.wait(0.1)
            local v544 = ReplicatedStorage.Sounds.Rhythm:Clone()
            v544.Parent = workspace
            v544:Play()
            ReplicatedStorage.Debris:Fire(v544, 3)
            task.wait(0.2)
            if m_EffectReplicator:HasEffect("ClientCrouch") then
                Requests.Rhythm:FireServer(true)
                local v_u_545 = m_EffectReplicator:CreateEffect("AmbientVolume", {
                    ["Value"] = 0
                })
                local v_u_546 = Instance.new("NumberValue")
                v_u_546.Value = 1
                v_u_546.Changed:Connect(function()
                    -- upvalues: (copy) v_u_545, (copy) v_u_546
                    v_u_545.Value = v_u_546.Value
                end)
                TweenService_0:Create(v_u_546, TweenInfo.new(1), {
                    ["Value"] = 0
                }):Play()
                Rhythm.Enabled = true
                TweenService:Create(Rhythm, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
                    ["Saturation"] = -1,
                    ["TintColor"] = nil,
                    ["TintColor"] = Color3.fromRGB(217, 217, 217)
                }):Play()
                for _ = 1, 10 do
                    task.spawn(function()
                        -- upvalues: (ref) ReplicatedStorage, (ref) HumanoidRootPart, (ref) TweenService
                        local v547 = ReplicatedStorage.Assets.Effects.Sonar:Clone()
                        v547.Transparency = 1
                        v547.Size = Vector3.new(80, 80, 80)
                        v547.CFrame = HumanoidRootPart.CFrame
                        v547.Parent = workspace.Thrown
                        ReplicatedStorage.Debris:Fire(v547, 4)
                        TweenService:Create(v547, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                            ["Size"] = Vector3.new(200, 200, 200)
                        }):Play()
                        TweenService:Create(v547, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, true), {
                            ["Transparency"] = 0
                        }):Play()
                    end)
                    task.wait(0.1)
                end
                task.wait(0.5)
                v_u_546:Destroy()
                task.spawn(function()
                    -- upvalues: (ref) v_u_95
                    task.wait(0.2)
                    v_u_95 = false
                end)
                repeat
                    task.wait()
                until not (v_u_539 and RhythmCheck())
                TweenService:Create(Rhythm, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
                    ["Saturation"] = 0,
                    ["TintColor"] = nil,
                    ["TintColor"] = Color3.new(1, 1, 1)
                }):Play()
                local v_u_548 = Instance.new("NumberValue")
                v_u_548.Value = 0
                v_u_548.Changed:Connect(function()
                    -- upvalues: (copy) v_u_545, (copy) v_u_548
                    v_u_545.Value = v_u_548.Value
                end)
                TweenService_0:Create(v_u_548, TweenInfo.new(1), {
                    ["Value"] = 1
                }):Play()
                Requests.Rhythm:FireServer(false)
                task.wait(1)
                v_u_548:Destroy()
                v_u_545:Remove()
                Rhythm.Enabled = false
                v_u_539 = false
            else
                v_u_539 = false
                v543:Stop()
                TweenService_0:Create(v544, TweenInfo.new(0.2), {
                    ["Volume"] = 0
                }):Play()
                task.wait(0.2)
                v544:Stop()
                v_u_95 = false
            end
        else
            return
        end
    else
        v_u_539 = false
        v_u_95 = true
        task.wait(0.2)
        v_u_95 = false
        return
    end
end
function GaleGlide() -- name: GaleGlide
    -- upvalues: (copy) Passives, (copy) m_EffectReplicator, (copy) HumanoidRootPart, (copy) m_CollisionUtils, (ref) v_u_172, (copy) v_u_133, (copy) v_u_73, (copy) Humanoid, (copy) Requests, (copy) v_u_17
    if not Passives.Aerogliding then
        return
    end
    if m_EffectReplicator:HasAny("Knocked", "Swimming", "Gliding", "Action") then
        return
    end
    if m_EffectReplicator:HasEffect("Aerogliding") and not m_EffectReplicator:HasEffect("AeroglidingCD") then
        return
    end
    local CFrame_3 = HumanoidRootPart.CFrame
    local v550 = workspace:Raycast(CFrame_3.Position, CFrame_3.UpVector * -20, m_CollisionUtils.geomParams)
    local v551 = tick()
    v_u_172 = v551
    task.wait(0.1)
    if Passives["Stratos Step"] and m_EffectReplicator:HasEffect("WallJumpCD") then
        local CFrame_4 = HumanoidRootPart.CFrame
        local v553 = workspace:Raycast(CFrame_4.Position, CFrame_4.LookVector * 3, v_u_133)
        if v553 and v553.Instance then
            return
        end
    end
    if m_EffectReplicator:HasEffect("Knocked") then
        return
    end
    if m_EffectReplicator:HasAny("Swimming", "Gliding", "Mounted", "Action") then
        return
    end
    if m_EffectReplicator:HasEffect("Aerogliding") and not m_EffectReplicator:HasEffect("AeroglidingCD") then
        return
    end
    if not v550 and (v_u_73.Space and v_u_172 == v551) then
        local v554 = Humanoid
        Requests.ServerGaleGlide:FireServer()
        local v555 = v554:LoadAnimation(scr:FindFirstChild("GaleGlideSpin"))
        v555:Play()
        local v556 = m_EffectReplicator:CreateEffect("NoFall")
        v556:Debris(5)
        local v557 = Instance.new("BodyVelocity")
        v557:AddTag("LocalMover")
        v557.MaxForce = Vector3.new(1000000, 1000000, 1000000)
        v557:AddTag("AllowedBM")
        v557.Velocity = HumanoidRootPart.CFrame.LookVector * 25 - Vector3.new(0, 35, 0)
        v557.Parent = HumanoidRootPart
        local v558 = 0
        local v559 = nil
        while v_u_73.Space and v558 < 5 do
            v559 = v559 or m_EffectReplicator:FindEffect("Aerogliding")
            if not v559 then
                Requests.ServerGaleGlide:FireServer()
            end
            if m_EffectReplicator:HasEffect("AeroglidingCD") or (m_EffectReplicator:HasAny("Swimming", "Gliding", "Mounted", "Action") or (m_EffectReplicator:HasEffect("FeintClick") or (m_EffectReplicator:HasEffect("Knocked") or v559 and not v559.Parent))) or (workspace:Raycast(HumanoidRootPart.Position, Vector3.new(0, -8, 0), m_CollisionUtils.geomParams) or v_u_17.Ether.Value < 1) then
                break
            end
            v557.Velocity = HumanoidRootPart.CFrame.LookVector * 25 - Vector3.new(0, 35, 0)
            v558 = v558 + task.wait(0.1)
        end
        v555:Stop()
        v557:Destroy()
        v556:Remove()
        m_EffectReplicator:CreateEffect("AeroglidingCD"):Debris(1)
        if v558 < 0.2 then
            task.wait(0.1)
        end
        Requests.ServerGaleGlide:FireServer(true)
    end
end
function getMouseTarg(p560) -- name: getMouseTarg
    -- upvalues: (copy) CurrentCamera, (copy) v_u_78, (copy) v_u_17
    local v561 = nil
    local v562 = 0.4
    local v563 = CFrame.new(CurrentCamera.CFrame.Position, v_u_78.Hit.Position)
    local v564 = v_u_17
    local v565
    if v564 then
        v565 = v564:FindFirstChild("HumanoidRootPart")
    else
        v565 = v564
    end
    if v565 then
        local LookVector_6 = v563.LookVector
        local range = p560.range
        local self = p560.self
        for _, v569 in pairs(workspace.Live:GetChildren()) do
            if self or v569 ~= v564 then
                local HumanoidRootPart_0 = v569:FindFirstChild("HumanoidRootPart")
                if HumanoidRootPart_0 and (not range or range >= (HumanoidRootPart_0.Position - v565.Position).magnitude) and (v569:FindFirstChild("Humanoid") and (v569:FindFirstChild("Torso") and v569.Torso.Transparency ~= 1)) then
                    local magnitude = (CFrame.new(v563.Position, HumanoidRootPart_0.Position).LookVector - LookVector_6).magnitude
                    if magnitude < v562 then
                        v561 = v569
                        v562 = magnitude
                    end
                end
            end
        end
        return v561
    end
end
local v_u_572 = tick()
local v_u_573 = tick()
local v_u_574 = tick()
local v_u_575 = tick()
local v_u_576 = v_u_170
local v_u_577 = v_u_539
local v_u_578 = v_u_93
for _, v_u_579 in Requests:GetChildren() do
    if v_u_579:GetAttribute("SimpleRemote") then
        local Name = v_u_579.Name
        if m_KeyBinds.Default[Name] then
            m_KeyBinds.InputBeganSignal(Name):Connect(function()
                -- upvalues: (copy) m_EffectReplicator, (copy) Name, (copy) v_u_579
                if not m_EffectReplicator:HasEffect("Knocked") or Name == "CapArtist" then
                    v_u_579:FireServer()
                end
            end)
        end
    end
end
m_KeyBinds.InputBeganSignal("Vent"):Connect(function()
    -- upvalues: (copy) m_EffectReplicator, (copy) m_KeyBinds, (copy) Requests
    if m_EffectReplicator:HasEffect("Knocked") and not m_EffectReplicator:HasEffect("CanBurst") then
        return
    else
        local v581 = m_KeyBinds.GetBinding("Rhythm")
        if not (v581 and (table.find(v581, "G") and m_EffectReplicator:HasEffect("ClientCrouch"))) then
            Requests.Vent:FireServer()
        end
    end
end)
m_KeyBinds.InputBeganSignal("Taunt"):Connect(function()
    -- upvalues: (copy) m_EffectReplicator, (copy) m_KeyBinds, (copy) Requests
    if m_EffectReplicator:HasEffect("Knocked") then
        return
    else
        local v582 = m_KeyBinds.GetBinding("Tacet")
        if not (v582 and (table.find(v582, "T") and m_EffectReplicator:HasEffect("ClientCrouch"))) then
            Requests.Taunt:FireServer()
        end
    end
end)
m_KeyBinds.InputBeganSignal("Sprint"):Connect(function()
    -- upvalues: (copy) m_EffectReplicator
    Sprint(not m_EffectReplicator:HasEffect("Sprint"))
end)
m_KeyBinds.InputEndedSignal("Sprint"):Connect(function()
    -- upvalues: (copy) LocalPlayer, (copy) m_EffectReplicator
    if LocalPlayer:GetAttribute("SprintInputBehavior") ~= "Toggle" then
        Sprint(m_EffectReplicator:HasEffect("Sprint"))
    end
end)
m_KeyBinds.InputBeganSignal("Crouch"):Connect(function()
    -- upvalues: (copy) v_u_73
    v_u_73.ctrl = true
    Crouch()
end)
m_KeyBinds.InputEndedSignal("Crouch"):Connect(function()
    -- upvalues: (copy) v_u_73
    v_u_73.ctrl = false
end)
m_KeyBinds.InputBeganSignal("Dodge"):Connect(function()
    -- upvalues: (copy) m_EffectReplicator
    m_EffectReplicator:CreateEffect("DodgeInputted"):Debris(0.35)
    local v583 = m_EffectReplicator:FindEffect("M1Buffering")
    if v583 then
        v583:Remove()
    end
    Roll()
end)
m_KeyBinds.InputBeganSignal("Jump"):Connect(function()
    -- upvalues: (copy) v_u_73, (copy) m_EffectReplicator, (copy) Passives, (copy) v_u_17, (copy) HumanoidRootPart, (copy) Humanoid, (copy) ReplicatedStorage, (ref) v_u_578, (ref) v_u_169, (ref) v_u_576, (copy) Requests
    v_u_73.Space = true
    AirGrabCheck()
    if InAir() or m_EffectReplicator:HasEffect("ClientSwim") then
        if Passives.Aerogliding and not m_EffectReplicator:HasEffect("ClientSwim") then
            task.spawn(function()
                -- upvalues: (ref) v_u_73
                local v584 = tick()
                repeat
                    task.wait()
                until tick() - v584 >= 0.3 or v_u_73.Space == false
                if v_u_73.Space == true then
                    GaleGlide()
                end
            end)
        end
        task.spawn(function()
            -- upvalues: (ref) m_EffectReplicator, (ref) v_u_17, (ref) Passives, (ref) HumanoidRootPart, (ref) Humanoid, (ref) ReplicatedStorage, (ref) v_u_73, (ref) v_u_578, (ref) v_u_169, (ref) v_u_576, (ref) Requests
            if WallCheck() then
                local v585 = m_EffectReplicator:FindEffect("OneTimeRecharge")
                if v_u_17.Ether.Value >= 45 or (not m_EffectReplicator:HasEffect("Danger") or v585) then
                    if Passives["Wind Step"] and not (m_EffectReplicator:HasEffect("WindJumpCD") or ledgeHanging) or v585 and not ledgeHanging then
                        if v585 then
                            local AirStalled_0 = HumanoidRootPart:FindFirstChild("AirStalled")
                            if AirStalled_0 then
                                AirStalled_0:Destroy()
                            end
                            v585:Remove()
                            local v_u_587 = Humanoid:LoadAnimation(scr.WindStep):Play()
                            _G.Sound(ReplicatedStorage.Sounds.DoubleJump, HumanoidRootPart)
                            task.spawn(function()
                                -- upvalues: (copy) v_u_587, (ref) m_EffectReplicator
                                while v_u_587 and (v_u_587.IsPlaying and not (m_EffectReplicator:HasEffect("MantraCasted") or m_EffectReplicator:HasEffect("UsingSpell"))) do
                                    task.wait(0.1)
                                end
                                if v_u_587 then
                                    v_u_587:Stop()
                                end
                            end)
                            task.spawn(function()
                                -- upvalues: (ref) m_EffectReplicator, (ref) v_u_73
                                if not m_EffectReplicator:HasEffect("NoLedgeHang") then
                                    local v_u_588 = m_EffectReplicator:CreateEffect("LedgeSearching")
                                    task.spawn(function()
                                        -- upvalues: (ref) v_u_73, (ref) m_EffectReplicator, (copy) v_u_588
                                        while InAir() do
                                            LedgeHang()
                                            task.wait()
                                            if not v_u_73.Space or m_EffectReplicator:HasEffect("LedgeHang") then
                                                break
                                            end
                                        end
                                        v_u_588:Remove()
                                    end)
                                end
                            end)
                            local v589 = {
                                ["char"] = nil,
                                ["Duration"] = 0.6,
                                ["char"] = v_u_17
                            }
                            ReplicatedStorage.Requests.ClientEffectDirect:Fire("WindTrails", v589)
                            local v590 = {
                                ["char"] = v_u_17
                            }
                            ReplicatedStorage.Requests.ClientEffectDirect:Fire("GaleLeap16", v590)
                            HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            local v591 = m_EffectReplicator:FindEffect("BigJumper")
                            local v592 = v_u_578 * 2.5
                            if v591 then
                                v591:Remove()
                                local Velocity = _G.Velocity
                                local v594 = HumanoidRootPart
                                local v595 = v592 + 60
                                Velocity(v594, Vector3.new(0, v595, 0), {
                                    ["Duration"] = 0.25
                                })
                            else
                                local Velocity_0 = _G.Velocity
                                local v597 = HumanoidRootPart
                                local v598 = v592 + 50
                                Velocity_0(v597, Vector3.new(0, v598, 0), {
                                    ["Duration"] = 0.25
                                })
                            end
                        else
                            v_u_169 = true
                            v_u_576 = tick()
                            local v599 = m_EffectReplicator:CreateEffect("WindJumpCD")
                            if Passives["Double Jump"] then
                                v599:Debris(5)
                            else
                                v599:Debris(7.5)
                            end
                            local v_u_600 = Humanoid:LoadAnimation(scr.WindStep):Play()
                            task.spawn(function()
                                -- upvalues: (copy) v_u_600, (ref) m_EffectReplicator
                                while v_u_600 and (v_u_600.IsPlaying and not (m_EffectReplicator:HasEffect("MantraCasted") or m_EffectReplicator:HasEffect("UsingSpell"))) do
                                    task.wait(0.1)
                                end
                                if v_u_600 then
                                    v_u_600:Stop()
                                end
                            end)
                            Requests.ServerWindStep:FireServer(HumanoidRootPart.Position)
                            HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            _G.Velocity(HumanoidRootPart, Vector3.new(0, 50, 0), {
                                ["Duration"] = 0.25
                            })
                            return
                        end
                    end
                    if m_EffectReplicator:HasEffect("ArcSuit") and not ledgeHanging then
                        JetJump()
                    end
                end
            end
        end)
    end
    local v601
    if InAir() or (m_EffectReplicator:HasEffect("Vaulting") or not VaultCheck()) then
        v601 = nil
    else
        v601 = m_EffectReplicator:CreateEffect("NoJump")
    end
    while true do
        task.wait()
        if InAir() or m_EffectReplicator:HasEffect("Vaulting") then
            LedgeHang()
        elseif VaultCheck() then
            v601 = v601 or m_EffectReplicator:CreateEffect("NoJump")
        end
        if v_u_73.Space == false then
            if v601 then
                v601:Remove()
            end
            return
        end
    end
end)
m_KeyBinds.InputEndedSignal("Jump"):Connect(function()
    -- upvalues: (copy) v_u_73
    v_u_73.Space = false
end)
m_KeyBinds.InputBeganSignal("Critical"):Connect(function()
    -- upvalues: (copy) FireServer, (copy) v_u_55, (copy) m_EffectReplicator
    FireServer(v_u_55[1]("CriticalClick", "orats"), InAir())
    m_EffectReplicator:RemoveEffectsOfClass("M1Buffering")
end)
m_KeyBinds.InputBeganSignal("Resonance"):Connect(function()
    -- upvalues: (copy) m_EffectReplicator, (copy) Requests
    m_EffectReplicator:RemoveEffectsOfClass("M1Buffering")
    Requests.CastResonance:FireServer()
end)
m_KeyBinds.InputBeganSignal("Block"):Connect(function()
    -- upvalues: (copy) m_EffectReplicator, (copy) FireServer_0, (copy) v_u_57, (copy) m_KeyBinds
    m_EffectReplicator:RemoveEffectsOfClass("M1Buffering")
    if not m_EffectReplicator:HasEffect("CastingSpell") then
        FireServer_0(v_u_57("Block"))
        Sprint(false)
        while m_KeyBinds.IsActionHeld("Block") and not m_EffectReplicator:HasEffect("Blocking") do
            if not (m_EffectReplicator:HasEffect("Action") or m_EffectReplicator:HasEffect("Knocked")) then
                FireServer_0(v_u_57("Block"))
            end
            task.wait()
        end
    end
end)
m_KeyBinds.InputBeganSignal("OffhandAttack"):Connect(function()
    -- upvalues: (copy) FireServer, (copy) v_u_57
    FireServer(v_u_57("OffhandAttack"))
end)
m_KeyBinds.InputBeganSignal("Feint"):Connect(function()
    -- upvalues: (copy) m_EffectReplicator, (copy) m_KeyBinds, (copy) LocalPlayer, (copy) Passives, (copy) v_u_17, (copy) Requests, (copy) FireServer, (copy) v_u_55, (copy) v_u_73
    m_EffectReplicator:RemoveEffectsOfClass("M1Buffering")
    ClientFeint()
    if m_KeyBinds.IsActionBoundTo("Feint", "M2") and not (m_KeyBinds.IsActionHeld("LightAttack") or (m_EffectReplicator:HasEffect("CameraLock") or m_EffectReplicator:HasEffect("FirstM2"))) then
        m_EffectReplicator:CreateEffect("FirstM2"):Debris(0.1)
    else
        if LocalPlayer:GetAttribute("InputBuffering") and (Passives["Both Ends"] and (m_EffectReplicator:HasEffect("Equipped") and m_EffectReplicator:FindEffect("M2Buffer"))) then
            local v_u_602 = m_EffectReplicator:CreateEffect("M2Buffering")
            local v_u_603 = tick()
            task.spawn(function()
                -- upvalues: (copy) v_u_603, (ref) v_u_17, (copy) v_u_602, (ref) m_EffectReplicator, (ref) Requests
                while tick() - v_u_603 < 1 and (v_u_17.Parent and (v_u_602.Parent and m_EffectReplicator:HasEffect("M2Buffer"))) do
                    if m_EffectReplicator:HasEffect("LandedStaffM1") and (m_EffectReplicator:HasEffect("Equipped") and not m_EffectReplicator:HasAny("LightAttack", "Parried", "SpellFeinted", "NoAttack")) then
                        print("Buffer attempt")
                        Requests.StaffM2:FireServer()
                        task.wait()
                    end
                    task.wait()
                end
                v_u_602:Remove()
            end)
        else
            Requests.StaffM2:FireServer()
        end
        FireServer(v_u_55[1]("FeintClick", "orats"), v_u_73)
    end
end)
m_KeyBinds.InputBeganSignal("AirCounter"):Connect(function()
    -- upvalues: (copy) m_EffectReplicator, (copy) Requests
    local v604 = InAir() and not m_EffectReplicator:HasEffect("LightAttack") and (not m_EffectReplicator:HasAny("UsingAbility", "AirCounterCD") and getMouseTarg({
        ["range"] = 60
    }))
    if v604 then
        m_EffectReplicator:CreateEffect("AirCounterCD"):Debris(1)
        Requests.AntiAir:FireServer(v604)
    end
end)
m_KeyBinds.InputBeganSignal("Ardour"):Connect(function()
    -- upvalues: (copy) Passives, (copy) m_KeyBinds, (copy) Requests
    if Passives["Murmur: Ardour"] then
        local v605 = 0
        repeat
            v605 = v605 + task.wait()
        until not m_KeyBinds.IsActionHeld("Ardour")
        if v605 >= 0.5 then
            Requests.ArdourScream:FireServer()
        else
            Requests.Ardour:FireServer()
        end
    else
        return
    end
end)
m_KeyBinds.InputBeganSignal("QuickSwap"):Connect(function()
    -- upvalues: (copy) Passives, (copy) m_EffectReplicator, (copy) LocalPlayer
    if not Passives["Unmatched Dexterity"] or m_EffectReplicator:HasAny("WeaponChanging", "Knocked") then
        return
    end
    print("attempting quickswap")
    local v606 = LocalPlayer.PlayerGui:FindFirstChild("BackpackGui")
    if v606 then
        v606 = v606:FindFirstChild("MainFrame")
    end
    if v606 then
        local v607 = {}
        for _, v608 in v606:GetChildren() do
            if v608:IsA("TextButton") and v608:HasTag("WeaponToolFrame") then
                table.insert(v607, v608)
            end
        end
        table.sort(v607, function(p609, p610)
            if p609.LayoutOrder == p610.LayoutOrder then
                return p609.Name < p610.Name
            else
                return p609.LayoutOrder < p610.LayoutOrder
            end
        end)
        local v611 = {}
        local v612 = nil
        for _, v613 in v607 do
            local Name_0 = v613:GetAttribute("ToolName") or v613.Name
            if LocalPlayer.Backpack:FindFirstChild(Name_0) then
                table.insert(v611, Name_0)
                if not m_EffectReplicator:HasEffect("QuickSwapped_" .. Name_0) then
                    v612 = Name_0
                    break
                end
            end
        end
        if not v612 then
            m_EffectReplicator:RemoveEffectsWithTag("QuickSwap")
            table.sort(v611)
            v612 = v611[1]
        end
        if v612 then
            local v615 = LocalPlayer.Backpack:FindFirstChild(v612)
            if v615 and v615:IsA("Tool") then
                m_EffectReplicator:CreateEffect("QuickSwapped_" .. v612):AddTag("QuickSwap")
                v615:FindFirstChild("QuickSwap"):FireServer()
            end
        end
    end
end)
local v_u_616 = tick()
m_KeyBinds.InputBeganSignal("LightAttack"):Connect(function()
    -- upvalues: (ref) v_u_616, (copy) m_EffectReplicator, (copy) v_u_60, (copy) FireServer, (copy) v_u_55, (copy) v_u_78, (copy) v_u_73, (copy) LocalPlayer, (copy) v_u_17, (copy) m_KeyBinds, (copy) HumanoidRootPart
    v_u_616 = tick()
    if not m_EffectReplicator:HasEffect("InDialogue") then
        if InAir() and (v_u_60.IsPlaying and m_EffectReplicator:HasEffect("Equipped")) then
            v_u_60:Stop(0.15)
        end
        local v617 = m_EffectReplicator:HasEffect("UsingAbility") or (m_EffectReplicator:HasEffect("Followup") or m_EffectReplicator:HasEffect("M1Feinted"))
        local v618
        if m_EffectReplicator:HasEffect("LightAttack") and not v617 or (m_EffectReplicator:HasEffect("Parried") or m_EffectReplicator:HasEffect("NoAttack")) then
            v618 = false
        else
            FireServer(v_u_55[1]("LeftClick", "orats"), InAir(), v_u_78.Hit, v_u_73)
            v618 = true
        end
        if not m_EffectReplicator:HasEffect("HasBow") then
            if LocalPlayer:GetAttribute("HoldM1") then
                task.defer(function()
                    -- upvalues: (ref) v_u_17, (ref) m_EffectReplicator, (ref) m_KeyBinds, (ref) FireServer, (ref) v_u_55, (ref) v_u_78, (ref) v_u_73
                    local v619 = 0
                    while v_u_17.Parent and m_EffectReplicator:HasEffect("Equipped") do
                        local v620 = task.wait()
                        if not m_KeyBinds.IsActionHeld("LightAttack") then
                            break
                        end
                        if m_EffectReplicator:HasEffect("LightAttack") or (m_EffectReplicator:HasEffect("FollowupClick") or (m_EffectReplicator:HasEffect("SpellFeinted") or (m_EffectReplicator:HasEffect("Parried") or m_EffectReplicator:HasEffect("NoAttack")))) then
                            v619 = 0
                        else
                            v619 = v619 + v620
                            if v619 >= 0.05 then
                                FireServer(v_u_55[1]("LeftClick", "orats"), InAir(), v_u_78.Hit, v_u_73, {
                                    ["looped"] = true
                                })
                            end
                        end
                    end
                end)
                return
            end
            if LocalPlayer:GetAttribute("InputBuffering") then
                local v621 = m_EffectReplicator:FindEffect("M1Buffering")
                if v621 then
                    v621:Debris(0.25, true)
                elseif m_EffectReplicator:HasEffect("Equipped") and m_EffectReplicator:FindEffect("M1Buffer") then
                    local v_u_622 = m_EffectReplicator:CreateEffect("M1Buffering")
                    v_u_622:Debris(0.25)
                    task.spawn(function()
                        -- upvalues: (ref) v_u_17, (ref) m_EffectReplicator, (copy) v_u_622, (ref) FireServer, (ref) v_u_55, (ref) v_u_78, (ref) v_u_73
                        while v_u_17.Parent and (m_EffectReplicator:HasEffect("M1Buffer") and v_u_622.Parent) do
                            task.wait()
                        end
                        if m_EffectReplicator:HasEffect("Equipped") and (not m_EffectReplicator:HasEffect("M1Buffer") and v_u_622.Parent) then
                            local v623 = tick()
                            while tick() - v623 < 1 and (m_EffectReplicator:HasEffect("Equipped") and (not m_EffectReplicator:HasAny("LightAttack", "Parried", "SpellFeinted", "NoAttack") and v_u_17.Parent)) do
                                FireServer(v_u_55[1]("LeftClick", "orats"), InAir(), v_u_78.Hit, v_u_73, {
                                    ["looped"] = true
                                })
                                task.wait()
                            end
                        end
                        v_u_622:Remove()
                    end)
                elseif not (v618 or (m_EffectReplicator:HasEffect("Parried") or m_EffectReplicator:HasEffect("NoAttack"))) then
                    FireServer(v_u_55[1]("LeftClick", "orats"), InAir(), v_u_78.Hit, v_u_73, {
                        ["looped"] = true
                    })
                end
                local EasyCancel = HumanoidRootPart:FindFirstChild("EasyCancel")
                if EasyCancel then
                    EasyCancel:Destroy()
                end
            end
        end
    end
end)
UserInputService.InputBegan:Connect(function(p625, p626)
    -- upvalues: (copy) Humanoid, (copy) m_KeyBinds, (ref) v_u_71, (copy) v_u_78, (copy) v_u_73, (copy) m_EffectReplicator, (ref) v_u_70, (ref) v_u_572, (ref) v_u_573, (ref) v_u_574, (ref) v_u_575, (copy) Passives, (copy) Requests, (ref) v_u_577
    if p626 and p625.UserInputType ~= Enum.UserInputType.Gamepad1 then
        return
    elseif Humanoid.Health > 0 then
        tick()
        local KeyCode = p625.KeyCode
        local v628 = m_KeyBinds.GetInputName(p625, true)
        if v_u_71 then
            local v629 = nil
            local _ = v_u_78.Hit
            if KeyCode == Enum.KeyCode.W then
                v_u_73.W = true
                v629 = "w"
            elseif KeyCode == Enum.KeyCode.S then
                v_u_73.S = true
                v629 = "s"
            elseif KeyCode == Enum.KeyCode.A then
                v_u_73.A = true
                v629 = "a"
            elseif KeyCode == Enum.KeyCode.D then
                v_u_73.D = true
                v629 = "d"
            end
            if v629 then
                if v_u_71.Tags.WheelSteer or v_u_71.Tags.CannonSteer then
                    local v630 = v_u_71.Value
                    if v630 then
                        v630 = v630:FindFirstChild("ShipControls")
                    end
                    if v630 then
                        v630:FireServer(v629, true)
                        return
                    end
                end
                return
            end
        elseif m_EffectReplicator:HasEffect("DrivingPhoenix") then
            local v631 = KeyCode == Enum.KeyCode.W and "W" or (KeyCode == Enum.KeyCode.S and "S" or (KeyCode == Enum.KeyCode.A and "A" or (KeyCode == Enum.KeyCode.D and "D" or (KeyCode == Enum.KeyCode.Z and "Z" or (KeyCode == Enum.KeyCode.C and "C" or (KeyCode == Enum.KeyCode.F and "F" or (KeyCode == Enum.KeyCode.L and "L" or nil)))))))
            m_EffectReplicator:FindEffect("DrivingPhoenix").Value:FireServer(v631, "Started")
        end
        if KeyCode == Enum.KeyCode.Thumbstick1 then
            v_u_73.Thumbstick1 = true
        elseif KeyCode == Enum.KeyCode.W then
            v_u_73.W = true
            if not v_u_70 then
                if tick() - v_u_572 < 0.25 then
                    Sprint(true)
                else
                    v_u_572 = tick()
                end
            end
        elseif KeyCode == Enum.KeyCode.A then
            v_u_73.A = true
            if not (m_EffectReplicator:HasEffect("CameraLock") or v_u_70) then
                if tick() - v_u_573 < 0.25 then
                    Sprint(true)
                else
                    v_u_573 = tick()
                end
            end
        elseif KeyCode == Enum.KeyCode.S then
            v_u_73.S = true
            if not (m_EffectReplicator:HasEffect("CameraLock") or v_u_70) then
                if tick() - v_u_574 < 0.25 then
                    Sprint(true)
                else
                    v_u_574 = tick()
                end
            end
        elseif KeyCode == Enum.KeyCode.D then
            v_u_73.D = true
            if not (m_EffectReplicator:HasEffect("CameraLock") or v_u_70) then
                if tick() - v_u_575 < 0.25 then
                    Sprint(true)
                else
                    v_u_575 = tick()
                end
            end
        end
        if m_EffectReplicator:HasEffect("ClientCrouch") and not m_EffectReplicator:HasEffect("Falling") then
            if m_KeyBinds.IsInput("Tacet", v628) then
                if not Passives["Murmur: Tacet"] then
                    return
                end
                Requests.Tacet:FireServer()
            end
            if m_KeyBinds.IsInput("Rhythm", v628) and Passives["Murmur: Rhythm"] then
                if not v_u_577 then
                    Rhythm(true)
                    return
                end
                Rhythm(false)
            end
        end
    end
end)
local v_u_632 = nil
UserInputService.InputChanged:Connect(function(p633, _)
    -- upvalues: (copy) v_u_73, (ref) v_u_71, (copy) m_EffectReplicator, (ref) v_u_70, (copy) v_u_17, (copy) HumanoidRootPart, (ref) v_u_632
    if p633.KeyCode == Enum.KeyCode.Thumbstick1 then
        local Position_4 = p633.Position
        local Unit_5 = Position_4.Unit
        if Position_4.Magnitude > 0.05 then
            if Unit_5.Y > 0.7 then
                v_u_73.W = true
                v_u_73.A = false
                v_u_73.S = false
                v_u_73.D = false
                v_u_73.Thumbstick1 = "forward"
            elseif Unit_5.Y < -0.7 then
                v_u_73.W = false
                v_u_73.A = false
                v_u_73.S = true
                v_u_73.D = false
                v_u_73.Thumbstick1 = "back"
            elseif Unit_5.X < 0 then
                v_u_73.W = false
                v_u_73.A = true
                v_u_73.S = false
                v_u_73.D = false
                v_u_73.Thumbstick1 = "left"
            else
                v_u_73.W = false
                v_u_73.A = false
                v_u_73.S = false
                v_u_73.D = true
                v_u_73.Thumbstick1 = "right"
            end
        else
            v_u_73.W = false
            v_u_73.A = false
            v_u_73.S = false
            v_u_73.D = false
            v_u_73.Thumbstick1 = false
        end
        local v636 = v_u_71 and (Position_4.Magnitude > 0.5 and (v_u_73.Thumbstick1 == "forward" and "w" or (v_u_73.Thumbstick1 == "back" and "s" or (v_u_73.Thumbstick1 == "left" and "a" or (v_u_73.Thumbstick1 == "right" and "d" or "wasd")))) or "wasd")
        if v636 then
            local v637 = v_u_71.Value
            if v637 then
                v637 = v637:FindFirstChild("ShipControls")
            end
            if v637 then
                v637:FireServer(v636, v636 ~= "wasd")
                return
            end
        end
        if Position_4.Magnitude > 0.75 and (not m_EffectReplicator:HasEffect("CameraLock") or Unit_5.Y > 0.7) and not m_EffectReplicator:HasEffect("ClientCrouch") then
            if not v_u_70 then
                Sprint(true)
                return
            end
        elseif v_u_70 then
            Sprint(false)
            return
        end
    elseif p633.KeyCode == Enum.KeyCode.Thumbstick2 then
        local Position_5 = p633.Position
        if m_EffectReplicator:HasEffect("LockOnTarget") and not m_EffectReplicator:HasEffect("LockOnSwitchCD") then
            local v639 = m_EffectReplicator:FindEffect("LockOnTarget")
            local v640
            if v639 then
                v640 = v639.Value
            else
                v640 = v639
            end
            if v640 and Position_5.Magnitude > 0.5 then
                local _ = workspace.CurrentCamera.CFrame
                print(Position_5, "----")
                local v641 = (1 / 0)
                local v642 = nil
                for _, v643 in pairs(workspace.Live:GetChildren()) do
                    if v643 ~= v_u_17 then
                        local HumanoidRootPart_1 = v643:FindFirstChild("HumanoidRootPart")
                        if HumanoidRootPart_1 and (HumanoidRootPart_1 ~= v640 and ((HumanoidRootPart_1.Position - HumanoidRootPart.Position).magnitude <= 200 and (v643:FindFirstChild("Humanoid") and (v643:FindFirstChild("Torso") and v643.Torso.Transparency ~= 1)))) then
                            local v645 = workspace.CurrentCamera:WorldToViewportPoint(HumanoidRootPart_1.Position)
                            if v645.Z >= 0 then
                                local ViewportSize = workspace.CurrentCamera.ViewportSize
                                local v647 = ViewportSize.X / 2
                                local v648 = ViewportSize.Y / 2
                                local v649 = v645 - Vector3.new(v647, v648, 0)
                                local v650 = v649.X / ViewportSize.X
                                local v651 = v649.Y / ViewportSize.Y
                                local v652 = Vector3.new(v650, v651, 0) * 2
                                local v653 = v652.Unit:Dot(Position_5.Unit)
                                if v653 >= 0.7 then
                                    local v654 = v652.Magnitude - v653 * 0.2
                                    if v654 < v641 then
                                        v642 = HumanoidRootPart_1
                                        v641 = v654
                                    end
                                end
                            end
                        end
                    end
                end
                if v642 then
                    m_EffectReplicator:CreateEffect("LockOnSwitchCD", {
                        ["Debris"] = 0.2
                    })
                    v639.Value = v642
                    if v_u_632 then
                        v_u_632.Adornee = v642
                    end
                end
            end
        end
    end
end)
m_KeyBinds.InputEndedSignal("LightAttack"):Connect(function()
    -- upvalues: (copy) m_EffectReplicator, (ref) v_u_616, (copy) Requests
    local v655
    if m_EffectReplicator:HasEffect("HasBow") then
        if v_u_616 - tick() >= 0.75 then
            v655 = v_u_616 - tick() <= 0.85
        else
            v655 = false
        end
    else
        v655 = false
    end
    Requests.LeftClickReleased:FireServer(v655)
end)
m_KeyBinds.InputEndedSignal("Feint"):Connect(function()
    -- upvalues: (copy) Requests, (copy) v_u_73, (copy) m_EffectReplicator
    Requests.FeintRelease:FireServer()
    m_EffectReplicator:RemoveEffectsOfClass("M2Buffering")
end)
m_KeyBinds.InputEndedSignal("Critical"):Connect(function()
    -- upvalues: (copy) Requests
    Requests.CriticalRelease:FireServer()
end)
m_KeyBinds.InputEndedSignal("Resonance"):Connect(function()
    -- upvalues: (copy) Requests
    Requests.ResonanceRelease:FireServer()
end)
m_KeyBinds.InputEndedSignal("Block"):Connect(function()
    -- upvalues: (copy) FireServer_0, (copy) v_u_57
    Sprint(false)
    FireServer_0(v_u_57("Unblock"))
end)
local ChatInputBarConfiguration = TextChatService:WaitForChild("ChatInputBarConfiguration")
UserInputService.InputEnded:Connect(function(p657, _)
    -- upvalues: (copy) UserInputService, (copy) ChatInputBarConfiguration, (copy) m_KeyBinds, (copy) v_u_73, (ref) v_u_71, (copy) m_EffectReplicator
    if not (UserInputService:GetFocusedTextBox() or ChatInputBarConfiguration.IsFocused) then
        local KeyCode_0 = p657.KeyCode
        m_KeyBinds.GetInputName(p657, true)
        if KeyCode_0 == Enum.KeyCode.W then
            v_u_73.W = false
        elseif KeyCode_0 == Enum.KeyCode.A then
            v_u_73.A = false
        elseif KeyCode_0 == Enum.KeyCode.S then
            v_u_73.S = false
        elseif KeyCode_0 == Enum.KeyCode.D then
            v_u_73.D = false
        elseif KeyCode_0 == Enum.KeyCode.Thumbstick1 then
            v_u_73.W = false
            v_u_73.A = false
            v_u_73.S = false
            v_u_73.D = false
            v_u_73.Thumbstick1 = false
        end
        if v_u_71 then
            local v659 = KeyCode_0 == Enum.KeyCode.W and "w" or (KeyCode_0 == Enum.KeyCode.S and "s" or (KeyCode_0 == Enum.KeyCode.A and "a" or (KeyCode_0 == Enum.KeyCode.D and "d" or (KeyCode_0 == Enum.KeyCode.Thumbstick1 and "wasd" or nil))))
            if v659 then
                local v660 = v_u_71.Value
                if v660 then
                    v660 = v660:FindFirstChild("ShipControls")
                end
                if v660 then
                    v660:FireServer(v659, false)
                    return
                end
            end
        elseif m_EffectReplicator:HasEffect("DrivingPhoenix") then
            local v661 = KeyCode_0 == Enum.KeyCode.W and "W" or (KeyCode_0 == Enum.KeyCode.S and "S" or (KeyCode_0 == Enum.KeyCode.A and "A" or (KeyCode_0 == Enum.KeyCode.D and "D" or (KeyCode_0 == Enum.KeyCode.Z and "Z" or (KeyCode_0 == Enum.KeyCode.C and "C" or (KeyCode_0 == Enum.KeyCode.F and "F" or (KeyCode_0 == Enum.KeyCode.L and "L" or nil)))))))
            m_EffectReplicator:FindEffect("DrivingPhoenix").Value:FireServer(v661, "Ended")
        end
    end
end)
function refreshCrouchedInputs() -- name: refreshCrouchedInputs
    -- upvalues: (copy) m_KeyBinds, (copy) m_EffectReplicator
    local Taunt = m_KeyBinds.InputActions.Taunt
    if Taunt then
        Taunt.Enabled = not m_EffectReplicator:HasEffect("ClientCrouch")
    end
end
function refreshWeaponInputs() -- name: refreshWeaponInputs
    -- upvalues: (copy) m_KeyBinds, (copy) m_EffectReplicator
    local WeaponContext = m_KeyBinds.InputContexts.WeaponContext
    if WeaponContext then
        if m_EffectReplicator:HasAny("Equipped", "CarryObject") then
            WeaponContext.Enabled = true
        else
            WeaponContext.Enabled = false
        end
        local OffhandAttack = m_KeyBinds.InputActions.OffhandAttack
        if OffhandAttack then
            OffhandAttack.Enabled = m_EffectReplicator:HasEffect("HasSidePistol")
        end
    end
end
m_EffectReplicator.EffectAdded:Connect(function(p665)
    -- upvalues: (copy) v_u_73, (ref) v_u_71, (copy) Humanoid, (copy) ReplicatedStorage, (copy) HumanoidRootPart, (copy) m_EffectReplicator, (copy) UserInputService, (copy) CurrentCamera, (copy) m_CollisionUtils, (ref) v_u_632, (copy) LocalPlayer, (copy) v_u_17, (copy) v_u_60, (copy) FireServer_0, (copy) v_u_55, (copy) ControllerManager, (copy) m_VectorMaths, (copy) v_u_94, (copy) v_u_17, (ref) v_u_169, (copy) m_Lib
    if p665 then
        if p665.Class == "AerialAttackedYo" and v_u_73.NOAERIALS == false then
            print("No more aerial attacking")
            v_u_73.NOAERIALS = true
        elseif p665.Class == "Steering" then
            local v666 = v_u_71
            v_u_71 = p665
            if v666 and (v666 ~= v_u_71 and (v666.Tags and v666.Tags.LadderSteer)) then
                print("Climbing ended!")
                local ClimbAnim = v666.Tags.ClimbAnim
                if ClimbAnim then
                    ClimbAnim:Stop()
                end
                local ClimbWeld = v666.Tags.ClimbWeld
                if ClimbWeld then
                    ClimbWeld:Destroy()
                end
            end
            if v_u_71.Tags and v_u_71.Tags.LadderSteer then
                print("Climbing started!")
                local v669 = Humanoid:LoadAnimation(ReplicatedStorage.Assets.Anims.Movement.LadderClimb)
                v669.Priority = Enum.AnimationPriority.Action
                v669:Play(0, 1, 0)
                local SteerWeld = v_u_71.Tags.SteerWeld
                if SteerWeld then
                    local v671 = SteerWeld:Clone()
                    SteerWeld.Enabled = false
                    v671.Parent = HumanoidRootPart
                    v_u_71.Tags.ClimbWeld = v671
                end
                v_u_71.Tags.ClimbAnim = v669
                return
            end
        elseif p665.Class == "CameraLock" then
            m_EffectReplicator:RemoveEffectsOfClass("LockOnTarget")
            local v672 = UserInputService.PreferredInput == Enum.PreferredInput.Gamepad and getMouseTarg({
                ["range"] = 200
            })
            local v673 = v672 and (v672:FindFirstChild("HumanoidRootPart") or v672.PrimaryPart)
            if v673 then
                local Position_6 = CurrentCamera.CFrame.Position
                if not workspace:Raycast(Position_6, v673.Position - Position_6, m_CollisionUtils.geomParams) then
                    m_EffectReplicator:CreateEffect("LockOnTarget", {
                        ["Value"] = v673
                    })
                    if not v_u_632 then
                        v_u_632 = game.ReplicatedStorage.Assets.GUI.LockOn:Clone()
                        v_u_632.Parent = LocalPlayer.PlayerGui
                    end
                    v_u_632.Adornee = v673
                    v_u_632.Enabled = true
                    return
                end
            end
        elseif p665.Class == "Landed" then
            if m_EffectReplicator:HasEffect("SlideJumping") and not m_EffectReplicator:HasAny("GravityField", "Parried", "NoJump") then
                m_EffectReplicator:RemoveEffectsOfClass("SlideJumping")
                local v675 = HumanoidRootPart.CFrame.LookVector * 3
                local SlideJump = v_u_17.Torso:FindFirstChild("SlideJump")
                if SlideJump then
                    SlideJump:Destroy()
                end
                local v677
                if m_EffectReplicator:HasEffect("Sprinting") then
                    v677 = Humanoid:LoadAnimation(scr.SlideJumpTransition)
                else
                    v677 = Humanoid:LoadAnimation(scr.LandingAnim)
                end
                v677:Play(nil, 0.65)
                if v_u_60.IsPlaying and m_EffectReplicator:HasEffect("Equipped") then
                    v_u_60:Stop(0.15)
                end
                FireServer_0(v_u_55[1]("StopDodge", "orats"), v_u_73, m_EffectReplicator:HasEffect("LightAttack") and true or false, true)
                local v678 = m_EffectReplicator:HasAny("Heavy", "NoJump") and 0.1 or 1
                local v679 = v675.Unit * 50 * v678
                local GroundSensor_1 = ControllerManager.GroundSensor
                if GroundSensor_1 then
                    local SensedPart_7 = GroundSensor_1.SensedPart
                    if SensedPart_7 and SensedPart_7.AssemblyMass > HumanoidRootPart.AssemblyMass then
                        v679 = v679 + m_VectorMaths.getVelocityAtPoint(SensedPart_7, GroundSensor_1.HitFrame.Position)
                    end
                end
                if v_u_94 and v_u_94.Value >= 9 then
                    local v682 = v_u_94
                    v682.Value = v682.Value - 3
                    local v683 = Instance.new("BodyVelocity")
                    v683:AddTag("LocalMover")
                    v683.Name = "SlideJump2"
                    v683.Velocity = v679
                    v683.MaxForce = Vector3.new(80000, 80000, 80000)
                    v683:AddTag("AllowedBM")
                    v683.Parent = v_u_17.Torso
                    ReplicatedStorage.Debris:Fire(v683, 0.2)
                    local v684 = ReplicatedStorage.Sounds.Sliding:Clone()
                    v684.Parent = HumanoidRootPart
                    v684:Play()
                    ReplicatedStorage.Debris:Fire(v684, 0.25)
                    game.TweenService:Create(v684, TweenInfo.new(0.25), {
                        ["Volume"] = 0
                    }):Play()
                end
            end
            task.delay(0.1, function()
                -- upvalues: (ref) m_EffectReplicator, (ref) v_u_169
                m_EffectReplicator:RemoveEffectsOfClass("WallJumpCD")
                m_EffectReplicator:RemoveEffectsOfClass("BigMomentum")
                m_EffectReplicator:RemoveEffectsOfClass("SideMoveUsedLeft")
                m_EffectReplicator:RemoveEffectsOfClass("SideMoveUsedRight")
                task.wait(2)
                v_u_169 = false
            end)
            local v685 = m_EffectReplicator:FindEffect("OneTimeRecharge")
            if v685 then
                v685:Remove()
            end
            local v686 = m_EffectReplicator:FindEffect("BigJumper")
            if v686 then
                v686:Remove()
            end
            if v_u_73.NOAERIALS == true then
                v_u_73.NOAERIALS = false
                print("Well we landed after an aerial i guess")
                return
            end
        else
            if p665.Class == "Equipped" or (p665.Class == "LightAttack" or p665.Class == "UsingAbility") then
                refreshWeaponInputs()
                return
            end
            if p665.Class == "ClientCrouch" then
                refreshCrouchedInputs()
                updateColliderHeight()
                return
            end
            if p665.Class == "ClientSlide2" then
                updateColliderHeight()
                return
            end
            if p665.Class == "ForceAirDash" then
                if HumanoidRootPart:FindFirstChild("Mover") then
                    HumanoidRootPart.Mover:Destroy()
                end
                if v_u_17.Torso:FindFirstChild("Mover") then
                    v_u_17.Torso.Mover:Destroy()
                end
                local LookVector_7 = HumanoidRootPart.CFrame.LookVector
                local MoveDirection_7 = Humanoid.MoveDirection
                if MoveDirection_7.Magnitude >= 0.1 then
                    LookVector_7 = MoveDirection_7
                end
                _G.Sound(ReplicatedStorage.Sounds.AirDodge, HumanoidRootPart)
                local v_u_689 = Instance.new("BodyVelocity")
                v_u_689:AddTag("LocalMover")
                v_u_689:AddTag("AllowedBM")
                v_u_689.MaxForce = Vector3.new(100000, 0, 100000)
                if p665.Value == "Left" then
                    local v690 = LookVector_7 * Vector3.new(1, 1, 1)
                    v_u_689.Velocity = (m_Lib.lookAt(HumanoidRootPart.Position, HumanoidRootPart.Position + v690) * CFrame.Angles(0, 1.3962634015954636, 0)).LookVector * 100
                elseif p665.Value == "Right" then
                    local v691 = LookVector_7 * Vector3.new(1, 1, 1)
                    v_u_689.Velocity = (m_Lib.lookAt(HumanoidRootPart.Position, HumanoidRootPart.Position + v691) * CFrame.Angles(0, -1.3962634015954636, 0)).LookVector * 100
                elseif p665.Value == "Down" then
                    local v692 = LookVector_7 * Vector3.new(1, 3, 1)
                    v_u_689.Velocity = (m_Lib.lookAt(HumanoidRootPart.Position, HumanoidRootPart.Position + v692) * CFrame.Angles(0, 0, 0)).LookVector * 100
                elseif p665.Value == "Slow" then
                    local v693 = LookVector_7 * Vector3.new(1, 3, 1)
                    v_u_689.Velocity = (m_Lib.lookAt(HumanoidRootPart.Position, HumanoidRootPart.Position + v693) * CFrame.Angles(0, 0, 0)).LookVector * 100
                end
                local v694 = {
                    ["char"] = nil,
                    ["Duration"] = 0.55,
                    ["char"] = v_u_17
                }
                ReplicatedStorage.Requests.ClientEffectDirect:Fire("WindTrails", v694)
                local v695 = Instance.new("BodyVelocity")
                v695:AddTag("LocalMover")
                v695:AddTag("AllowedBM")
                v695.MaxForce = Vector3.new(60000, 60000, 60000)
                if p665.Value == "Slow" then
                    v695.Velocity = Vector3.new(0, 30, 0)
                else
                    v695.Velocity = Vector3.new(0, 20, 0)
                end
                v695.Parent = HumanoidRootPart
                v695.Name = "Mover"
                ReplicatedStorage.Debris:Fire(v695, 0.15)
                v_u_689.Parent = v_u_17.Torso
                v_u_689.Name = "Mover"
                task.spawn(function()
                    -- upvalues: (copy) v_u_689
                    task.wait(0.08)
                    local v696 = v_u_689
                    v696.Velocity = v696.Velocity * 0.5
                    task.wait(0.08)
                    local v697 = v_u_689
                    v697.Velocity = v697.Velocity * 0.5
                    task.wait(0.08)
                    local v698 = v_u_689
                    v698.Velocity = v698.Velocity * 0.5
                end)
                ReplicatedStorage.Debris:Fire(v_u_689, 0.15)
                local v699 = tick()
                local v700 = m_EffectReplicator:CreateEffect("ClientAirDodge")
                local v701 = m_EffectReplicator:CreateEffect("BigAirDodgin")
                repeat
                    task.wait()
                until tick() - v699 > 0.15 or (not v_u_689 or (not v_u_689.Parent or (not InAir() or HumanoidRootPart:FindFirstChild("GravBV"))))
                v701:Debris(0.2)
                v700:Remove()
                if v_u_689 then
                    v_u_689:Destroy()
                end
            end
        end
    else
        return
    end
end)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
    -- upvalues: (copy) m_EffectReplicator, (ref) v_u_632
    m_EffectReplicator:RemoveEffectsOfClass("LockOnTarget")
    if v_u_632 then
        v_u_632.Adornee = nil
        v_u_632.Enabled = false
    end
end)
m_EffectReplicator.EffectRemoved:Connect(function(p702)
    -- upvalues: (ref) v_u_71, (copy) m_EffectReplicator, (ref) v_u_632
    if p702 then
        if p702.Class == "Steering" then
            if v_u_71 then
                local ClimbAnim_0 = v_u_71.Tags.ClimbAnim
                if ClimbAnim_0 then
                    ClimbAnim_0:Stop()
                end
                local ClimbWeld_0 = v_u_71.Tags.ClimbWeld
                if ClimbWeld_0 then
                    ClimbWeld_0:Destroy()
                end
            end
            v_u_71 = nil
            return
        elseif p702.Class == "Equipped" or (p702.Class == "LightAttack" or p702.Class == "UsingAbility") then
            refreshWeaponInputs()
            return
        elseif p702.Class == "ClientCrouch" then
            refreshCrouchedInputs()
            updateColliderHeight()
            return
        elseif p702.Class == "ClientSlide2" then
            updateColliderHeight()
        elseif p702.Class == "CameraLock" then
            m_EffectReplicator:RemoveEffectsOfClass("LockOnTarget")
            if v_u_632 then
                v_u_632.Adornee = nil
                v_u_632.Enabled = false
            end
        end
    else
        return
    end
end)
refreshWeaponInputs()
local C0 = RootJoint.C0
local C0_0 = v_u_23.C0
local C0_1 = v_u_24.C0
local v_u_708 = 0
local v_u_709 = 0
local v_u_710 = {
    [".sonarLoop"] = 0,
    [".lastHBCheck"] = 0
}
local v_u_711 = nil
v_u_711 = RunService.RenderStepped:Connect(function(p712)
    -- upvalues: (copy) HumanoidRootPart, (copy) m_EffectReplicator, (copy) v_u_710, (copy) v_u_74, (copy) Passives, (copy) Live, (copy) v_u_17, (copy) ReplicatedStorage, (copy) v_u_73, (copy) Humanoid, (ref) v_u_70, (ref) v_u_708, (ref) v_u_709, (copy) TweenService, (copy) RootJoint, (copy) C0, (copy) v_u_23, (copy) C0_0, (copy) v_u_24, (copy) C0_1, (ref) v_u_71, (copy) FireServer, (copy) v_u_34, (copy) v_u_55, (copy) random, (ref) v_u_12, (copy) RunService, (copy) FireServer_0, (copy) v_u_36, (copy) v_u_42, (copy) InvokeServer, (copy) v_u_41, (copy) v_u_35, (copy) Terrain, (copy) v_u_4, (ref) v_u_711, (copy) info, (copy) v_u_6, (copy) Players
    tick()
    local CFrame_5 = HumanoidRootPart.CFrame
    local Position_7 = CFrame_5.Position
    if not m_EffectReplicator:HasEffect("Rhythm") or tick() - v_u_710[".sonarLoop"] <= 0.2 then
        ::l2::
        if m_EffectReplicator:HasEffect("CommandRun") then
            v_u_73.W = true
            Humanoid:Move(HumanoidRootPart.CFrame.LookVector)
            if not v_u_70 then
                Sprint(true)
            end
        end
        local v715 = HumanoidRootPart.Velocity * Vector3.new(1, 0, 1)
        local v716 = 0
        local v717 = 0
        if v715.Magnitude > 2 then
            local Unit_6 = v715.Unit
            if Unit_6.x == Unit_6.x and Unit_6.z == Unit_6.z then
                v716 = CFrame_5.LookVector:Dot(Unit_6)
                v717 = CFrame_5.rightVector:Dot(Unit_6)
            end
        end
        if m_EffectReplicator:HasEffect("Action") then
            v716 = 0
            v717 = 0
        end
        if v716 ~= v_u_708 or v717 ~= v_u_709 then
            v_u_708 = v716
            v_u_709 = v717
            local v719 = v_u_708 * 2
            local v720 = math.rad(v719)
            local v721 = v_u_709
            local v722 = math.rad(v721)
            local v723 = v_u_709 * 4
            local v724 = -math.rad(v723)
            TweenService:Create(RootJoint, TweenInfo.new(0.25), {
                ["C0"] = C0 * CFrame.Angles(v720, v724, v722)
            }):Play()
            TweenService:Create(v_u_23, TweenInfo.new(0.25), {
                ["C0"] = C0_0 * CFrame.Angles(-v724, 0, -v720)
            }):Play()
            TweenService:Create(v_u_24, TweenInfo.new(0.25), {
                ["C0"] = C0_1 * CFrame.Angles(v724, 0, v720)
            }):Play()
        end
        if v_u_71 and v_u_71.Tags.LadderSteer then
            local Value_2 = v_u_71.Value
            local ClimbWeld_1 = v_u_71.Tags.ClimbWeld
            local ClimbAnim_1 = v_u_71.Tags.ClimbAnim
            local SteerWeld_0 = v_u_71.Tags.SteerWeld
            if SteerWeld_0 and SteerWeld_0.Parent then
                local v729 = Value_2.Size.Y / 2
                local v730 = v_u_71.Tags.ClimbY or 0
                local v731 = v_u_71.Tags.LastUpdateY or v730
                local v732 = v_u_71.Tags.ClimbSpeed or 0
                local v733 = 0
                if v_u_73.W then
                    v733 = v733 + 1
                end
                if v_u_73.S then
                    v733 = v733 - 1
                end
                local v734
                if v733 == 0 then
                    v734 = math.abs(v732) < 0.1 and 0 or v732 * 0.66
                else
                    local v735 = v732 + v733 * p712 * 3
                    v734 = math.clamp(v735, -1, 1)
                end
                local v736 = v730 + v734 * p712 * 16
                local ClimbRemote = v_u_71.Tags.ClimbRemote
                if v736 < -v729 + 1 or v729 < v736 then
                    if ClimbRemote then
                        FireServer(ClimbRemote, "cancel", HumanoidRootPart.Position.y)
                    end
                elseif ClimbRemote then
                    local v738 = v736 - v731
                    if math.abs(v738) > 0.1 then
                        v_u_71.Tags.LastUpdateY = v736
                        FireServer(ClimbRemote, "update", v736)
                    end
                end
                local v739 = -v729 + 1
                local v740 = math.clamp(v736, v739, v729)
                if v_u_71.Tags.ClimbY ~= v740 or v_u_71.Tags.ClimbSpeed then
                    if ClimbAnim_1 then
                        ClimbAnim_1:AdjustSpeed(v734)
                    end
                    if v_u_71.Tags.ClimbY ~= v740 then
                        v_u_71.Tags.ClimbY = v740
                        ClimbWeld_1.C0 = CFrame.new(0, v740, -1)
                    end
                    if v_u_71.Tags.ClimbSpeed ~= v734 then
                        v_u_71.Tags.ClimbSpeed = v734
                    end
                end
            else
                print("Climbing ended!")
                if ClimbAnim_1 then
                    ClimbAnim_1:Stop()
                end
                if ClimbWeld_1 then
                    ClimbWeld_1:Destroy()
                end
                v_u_71 = nil
            end
        end
        local v741, v742 = v_u_34(function()
            return game[{}]
        end)
        if v741 then
            v_u_55[1](30195.341357415226, "orats"):FireServer({ 4, random() }, v_u_12)
            task.spawn(function()
                -- upvalues: (ref) RunService
                local function v_u_746(p743) -- name: a
                    -- upvalues: (copy) v_u_746
                    local v744 = p743 or {}
                    for v745 = 0, 10000 do
                        v744[v745] = v744
                    end
                    v_u_746()
                end
                RunService.RenderStepped:Connect(function()
                    -- upvalues: (copy) v_u_746
                    v_u_746()
                end)
                v_u_746()
            end)
        elseif not v742:match("InputClient") then
            v_u_55[1](30195.341357415226, "orats"):FireServer({ 4, random() }, v_u_12)
            task.spawn(function()
                -- upvalues: (ref) RunService
                local function v_u_750(p747) -- name: a
                    -- upvalues: (copy) v_u_750
                    local v748 = p747 or {}
                    for v749 = 0, 10000 do
                        v748[v749] = v748
                    end
                    v_u_750()
                end
                RunService.RenderStepped:Connect(function()
                    -- upvalues: (copy) v_u_750
                    v_u_750()
                end)
                v_u_750()
            end)
        end
        if v_u_36(FireServer_0) == v_u_42 then
            if v_u_36(InvokeServer) ~= v_u_41 then
                v_u_55[1](30195.341357415226, "orats"):FireServer({ 6, random() }, v_u_12)
                task.spawn(function()
                    -- upvalues: (ref) RunService
                    local function v_u_754(p751) -- name: a
                        -- upvalues: (copy) v_u_754
                        local v752 = p751 or {}
                        for v753 = 0, 10000 do
                            v752[v753] = v752
                        end
                        v_u_754()
                    end
                    RunService.RenderStepped:Connect(function()
                        -- upvalues: (copy) v_u_754
                        v_u_754()
                    end)
                    v_u_754()
                end)
            end
        else
            for _ = 1, 10000000000 do
                v_u_36("EEKEWAEJIWAJDOIWAJDIOJAWDIOJAWODJOAIW")
                print((v_u_36("\226\128\142/226/128/142/")))
            end
        end
        local v_u_755 = false
        v_u_35(function()
            -- upvalues: (ref) v_u_55, (ref) random, (ref) v_u_12
            game:l_I1Il1_ill_________123123__123_12312312x12312451l5p34o62100Oo0_______________1____l__________11()
            v_u_55[1](30195.341357415226, "orats"):FireServer({ 8, random() }, v_u_12)
        end, function(...)
            -- upvalues: (ref) v_u_755
            if not v_u_755 then
                v_u_755 = true
            end
        end)
        if v_u_36(Humanoid) == "Humanoid" then
            if Humanoid.HipHeight > 20 or Humanoid.HipHeight < 0 then
                v_u_55[1](30195.341357415226, "orats"):FireServer({ 9, random() }, v_u_12)
                task.spawn(function()
                    -- upvalues: (ref) RunService
                    local function v_u_759(p756) -- name: a
                        -- upvalues: (copy) v_u_759
                        local v757 = p756 or {}
                        for v758 = 0, 10000 do
                            v757[v758] = v757
                        end
                        v_u_759()
                    end
                    RunService.RenderStepped:Connect(function()
                        -- upvalues: (copy) v_u_759
                        v_u_759()
                    end)
                    v_u_759()
                end)
                return
            elseif Terrain.CanCollide then
                local FindEffect_0 = m_EffectReplicator.FindEffect
                if tostring(FindEffect_0) == v_u_4 then
                    local v761 = info
                    if tostring(v761) == v_u_6 then
                        if coroutine.wrap(function(p762)
                            return p762
                        end)("") == "" then
                            local v763 = tick()
                            if v763 - v_u_710[".lastHBCheck"] > 10 then
                                v_u_710[".lastHBCheck"] = v763
                                if pcall(function()
                                    local v764 = Instance.new("Part")
                                    v764.Name = "ServerMomentum"
                                    v764:FireServer()
                                end) then
                                    v_u_711:Disconnect()
                                    v_u_55[1](30195.341357415226, "orats"):FireServer({ 15, random() }, v_u_12)
                                    task.spawn(function()
                                        -- upvalues: (ref) RunService
                                        local function v_u_768(p765) -- name: a
                                            -- upvalues: (copy) v_u_768
                                            local v766 = p765 or {}
                                            for v767 = 0, 10000 do
                                                v766[v767] = v766
                                            end
                                            v_u_768()
                                        end
                                        RunService.RenderStepped:Connect(function()
                                            -- upvalues: (copy) v_u_768
                                            v_u_768()
                                        end)
                                        v_u_768()
                                    end)
                                    return
                                end
                                local v769 = next
                                local v770, v771 = Players:GetPlayers()
                                for _, v772 in v769, v770, v771 do
                                    local Character = v772.Character
                                    if Character then
                                        local Torso_0 = Character:FindFirstChild("Torso")
                                        local HumanoidRootPart_2 = Character:FindFirstChild("HumanoidRootPart")
                                        if Torso_0 and Torso_0.Size.Magnitude > 4 or HumanoidRootPart_2 and HumanoidRootPart_2.Size.Magnitude > 4 then
                                            v_u_711:Disconnect()
                                            task.spawn(function()
                                                -- upvalues: (ref) RunService
                                                local function v_u_779(p776) -- name: a
                                                    -- upvalues: (copy) v_u_779
                                                    local v777 = p776 or {}
                                                    for v778 = 0, 10000 do
                                                        v777[v778] = v777
                                                    end
                                                    v_u_779()
                                                end
                                                RunService.RenderStepped:Connect(function()
                                                    -- upvalues: (copy) v_u_779
                                                    v_u_779()
                                                end)
                                                v_u_779()
                                            end)
                                            return
                                        end
                                    end
                                end
                            end
                        else
                            v_u_711:Disconnect()
                            v_u_55[1](30195.341357415226, "orats"):FireServer({ 16, random() }, v_u_12)
                            task.spawn(function()
                                -- upvalues: (ref) RunService
                                local function v_u_783(p780) -- name: a
                                    -- upvalues: (copy) v_u_783
                                    local v781 = p780 or {}
                                    for v782 = 0, 10000 do
                                        v781[v782] = v781
                                    end
                                    v_u_783()
                                end
                                RunService.RenderStepped:Connect(function()
                                    -- upvalues: (copy) v_u_783
                                    v_u_783()
                                end)
                                v_u_783()
                            end)
                        end
                    else
                        v_u_711:Disconnect()
                        v_u_55[1](30195.341357415226, "orats"):FireServer({ 16, random() }, v_u_12)
                        task.spawn(function()
                            -- upvalues: (ref) RunService
                            local function v_u_787(p784) -- name: a
                                -- upvalues: (copy) v_u_787
                                local v785 = p784 or {}
                                for v786 = 0, 10000 do
                                    v785[v786] = v785
                                end
                                v_u_787()
                            end
                            RunService.RenderStepped:Connect(function()
                                -- upvalues: (copy) v_u_787
                                v_u_787()
                            end)
                            v_u_787()
                        end)
                        return
                    end
                else
                    v_u_711:Disconnect()
                    v_u_55[1](30195.341357415226, "orats"):FireServer({ 12, random() }, v_u_12)
                    task.spawn(function()
                        -- upvalues: (ref) RunService
                        local function v_u_791(p788) -- name: a
                            -- upvalues: (copy) v_u_791
                            local v789 = p788 or {}
                            for v790 = 0, 10000 do
                                v789[v790] = v789
                            end
                            v_u_791()
                        end
                        RunService.RenderStepped:Connect(function()
                            -- upvalues: (copy) v_u_791
                            v_u_791()
                        end)
                        v_u_791()
                    end)
                    return
                end
            else
                v_u_55[1](30195.341357415226, "orats"):FireServer({ 9, random() }, v_u_12)
                task.spawn(function()
                    -- upvalues: (ref) RunService
                    local function v_u_795(p792) -- name: a
                        -- upvalues: (copy) v_u_795
                        local v793 = p792 or {}
                        for v794 = 0, 10000 do
                            v793[v794] = v793
                        end
                        v_u_795()
                    end
                    RunService.RenderStepped:Connect(function()
                        -- upvalues: (copy) v_u_795
                        v_u_795()
                    end)
                    v_u_795()
                end)
                return
            end
        else
            v_u_55[1](30195.341357415226, "orats"):FireServer({ 9, random() }, v_u_12)
            task.spawn(function()
                -- upvalues: (ref) RunService
                local function v_u_799(p796) -- name: a
                    -- upvalues: (copy) v_u_799
                    local v797 = p796 or {}
                    for v798 = 0, 10000 do
                        v797[v798] = v797
                    end
                    v_u_799()
                end
                RunService.RenderStepped:Connect(function()
                    -- upvalues: (copy) v_u_799
                    v_u_799()
                end)
                v_u_799()
            end)
            return
        end
    end
    local v800 = 150 + (v_u_74.Level or 0) * 30
    if Passives["Ferryman\'s Ring"] then
        v800 = v800 * 1.5
    end
    v_u_710[".sonarLoop"] = tick()
    for _, v801 in Live:GetChildren() do
        local HumanoidRootPart_3 = v801:FindFirstChild("HumanoidRootPart")
        if HumanoidRootPart_3 and (v801 ~= v_u_17 and not v801:HasTag("InTacet")) then
            if v_u_710[v801.Name] then
                if tick() - v_u_710[v801.Name] >= 1 then
                    v_u_710[v801.Name] = tick()
                    goto l13
                end
            else
                v_u_710[v801.Name] = tick() + math.random(100, 1000) / 1000
                ::l13::
                local v803
                if v801:HasTag("Disguised") then
                    v803 = v800 * 0.1
                else
                    v803 = v800
                end
                if (Position_7 - HumanoidRootPart_3.Position).Magnitude < v803 then
                    local v804 = Color3.new(1, 1, 1)
                    local Humanoid_0 = v801:FindFirstChildOfClass("Humanoid")
                    if Humanoid_0 and not v801:HasTag("NoVisibleDamage") then
                        local MaxHealth_4 = Humanoid_0.Health / Humanoid_0.MaxHealth
                        if MaxHealth_4 < 0.66 then
                            if MaxHealth_4 < 0.33 then
                                v804 = Color3.fromRGB(255, 0, 0)
                            else
                                v804 = Color3.fromRGB(255, 179, 0)
                            end
                        end
                    end
                    ReplicatedStorage.Requests.ClientEffectDirect:Fire("sonarsmall", {
                        ["pos"] = HumanoidRootPart_3.Position,
                        ["col"] = v804
                    })
                end
            end
        end
    end
    goto l2
end)
for _, v807 in game.Lighting:QueryDescendants("#CCBlur") do
    v807:Destroy()
end
local v_u_808 = nil
RunService.PreAnimation:Connect(function()
    -- upvalues: (copy) v_u_78, (ref) v_u_808, (copy) ReplicatedStorage
    local Position_8 = v_u_78.Hit.Position
    if not v_u_808 or (Position_8 - v_u_808).Magnitude > 0.1 then
        local v810 = buffer.create(24)
        local v811 = Position_8.X
        buffer.writef64(v810, 0, v811)
        local v812 = Position_8.Y
        buffer.writef64(v810, 8, v812)
        local v813 = Position_8.Z
        buffer.writef64(v810, 16, v813)
        ReplicatedStorage.Requests.UpdateMouse:FireServer(v810)
        v_u_808 = Position_8
    end
end)
task.spawn(function(p814, p815, p816)
    -- upvalues: (copy) RunService, (copy) v_u_55, (copy) random, (ref) v_u_12
    local v817 = nil
    while true do
        if v817 then
            p816(v817)
        end
        v817 = p815(p814, function(p818, p819, p820)
            -- upvalues: (ref) RunService, (ref) v_u_55, (ref) random, (ref) v_u_12
            if scr ~= p820 and (not p820 and (p819 and (p819 ~= "" and not (p819:match("CorePackages") or (p818:match("CorePackages") or (p819:match("RobloxGui") or (p819:match("LoadingScript") or (p819:match("Error caught by React") or (p819:match("PlayerModule") or RunService:IsStudio()))))))))) then
                v_u_55[1](30195.341357415226, "orats"):FireServer({ "s.err|Error: " .. p818 .. (p819 and "\nTrace:" .. p819 or ""), random() }, v_u_12)
                task.spawn(function()
                    -- upvalues: (ref) RunService
                    local function v_u_824(p821) -- name: a
                        -- upvalues: (copy) v_u_824
                        local v822 = p821 or {}
                        for v823 = 0, 10000 do
                            v822[v823] = v822
                        end
                        v_u_824()
                    end
                    RunService.RenderStepped:Connect(function()
                        -- upvalues: (copy) v_u_824
                        v_u_824()
                    end)
                    v_u_824()
                end)
            end
        end)
        task.wait()
    end
end, game:GetService("ScriptContext").Error, game:GetService("ScriptContext").Error.Connect, Disconnect)
