
local RunService_1 = game:GetService("RunService")
local UserInputService_upv_1 = game:GetService("UserInputService")
local ReplicatedStorage_upv_1 = game:GetService("ReplicatedStorage")
local TweenService_upv_1 = game:GetService("TweenService")
local _ = require(game.ReplicatedStorage.Types)
local EffectReplicator_upv_1 = require(ReplicatedStorage_upv_1.EffectReplicator)
local Lib_upv_1 = require(ReplicatedStorage_upv_1.Modules.Lib)
local RealmInfo_upv_1 = require(ReplicatedStorage_upv_1.Info.RealmInfo)
ReplicatedStorage_upv_1.Requests.ClientFXReadout.OnClientInvoke = function()
    local tbl_1 = {}
    local v1, v1 = nil, nil
    for _, value_1 in EffectReplicator_upv_1:GetEffects() do
        v1 = ("\226\128\162 <b>%*</b>: <font color=\"#055\">%*</font>"):format(value_1.Class, value_1.Value)
        local Tags_1 = value_1.Tags
        if not (Tags_1) then
            table.insert(tbl_1, v1)
            continue
        end
        local v2 = next(Tags_1)
        if not (v2) then
            table.insert(tbl_1, v1)
            continue
        end
        v1 = v1 .. " <font size=\"14\" color=\"#555\">{"
        for key_1, value_2 in next, Tags_1 do
            v1 = ((typeof(value_2) ~= "boolean") and (v1 .. ("%*:%*"):format(key_1, value_2))) or (v1 .. key_1)
            v1 = (next(Tags_1, key_1) and (v1 .. "; ")) or v1
        end
        v1 = v1 .. "}</font>"
        table.insert(tbl_1, v1)
    end
    table.sort(tbl_1)
    return table.concat(tbl_1, "\n")
end
local LocalPlayer_upv_1 = game.Players.LocalPlayer
local Character_upv_1 = LocalPlayer_upv_1.Character
local CharacterHandler_upv_1 = Character_upv_1:WaitForChild("CharacterHandler")
local Humanoid_upv_1 = Character_upv_1:WaitForChild("Humanoid")
local v4 = Character_upv_1:WaitForChild("Head")
local HumanoidRootPart_upv_1 = Character_upv_1:WaitForChild("HumanoidRootPart")
local Stomach_upv_1 = Character_upv_1:WaitForChild("Stomach")
local Water_upv_1 = Character_upv_1:WaitForChild("Water")
local v5 = Character_upv_1:WaitForChild("Blood")
local GroundSensor_upv_1 = HumanoidRootPart_upv_1:WaitForChild("GroundSensor")
local Passives_upv_1 = EffectReplicator_upv_1.Passives
Lib_upv_1.setupHumanoid(Humanoid_upv_1)
local CurrentCamera_upv_1 = workspace.CurrentCamera
CurrentCamera_upv_1.CameraType = Enum.CameraType.Custom
CurrentCamera_upv_1.CameraSubject = Humanoid_upv_1
CurrentCamera_upv_1:RemoveTag("FreezeCamera")
CurrentCamera_upv_1:RemoveTag("ForcedSubject")
local v6 = Random.new()
local v3 = LocalPlayer_upv_1:GetAttribute("FieldOfView")
local u1 = v3 or 70
local u2 = 20
local u3 = 196.2
local GenericBlur_upv_1 = game.Lighting:WaitForChild("GenericBlur")
local u4 = GenericBlur_upv_1.Size
Humanoid_upv_1.PlatformStand = true
local IsScyphozia_upv_1 = RealmInfo_upv_1.IsScyphozia
if IsScyphozia_upv_1 then
    workspace.Gravity = 100
    u3 = 100
end
function hasArtifact(a1, a2)
    local v4 = a2:match("Artifact:")
    if not (v4) then
        local _ = "Artifact:" .. a2
    end
    local v5 = game.Players:GetPlayerFromCharacter(a1)
    if v5 then
        if v5.Backpack:FindFirstChild(a2) then
            return true
        end
    elseif a1:FindFirstChild(a2) then
        return true
    end
    return false
end
local u5 = 0
local u6 = 0
local u7 = 0
local u8 = tick()
local u9 = 0
local u10 = 0
local u11 = Vector3.new(0, 0, 0)
local u12 = 0
local function processEffects(a1)
    local u13 = 16
    local v6 = 0
    local v7 = 50
    local v8 = 0
    local v9 = false
    local v10 = false
    local v11 = true
    local v12 = false
    local v13 = false
    local Value_1 = 0
    local v14 = 25
    local v15 = 0
    if Stomach_upv_1.Value <= 0 then
        u13 = u13 - 1
    end
    if Water_upv_1.Value < 10 then
        v15 = v15 + (5 + ((10 - Water_upv_1.Value) / 2))
        if Water_upv_1.Value <= 0 then
            u13 = u13 - 1
        end
    end
    local v16 = false
    local v17 = false
    local v18 = nil
    local v19 = EffectReplicator_upv_1:GetEffectsHash()
    local v20 = Passives_upv_1["Oath: Jetstriker"]
    local v21 = (v20 and 2) or 0
    local Wormwarder_1 = Passives_upv_1.Wormwarder
    local v22 = Passives_upv_1["Diver's Resilience"]
    local v23 = Passives_upv_1["Armored Plating"]
    local v24 = Passives_upv_1["Void Glutton"]
    local v25 = Passives_upv_1["Soul Rip"]
    local Hyperbody_1 = Passives_upv_1.Hyperbody
    local Haste_1 = Passives_upv_1.Haste
    local Breeze_1 = Passives_upv_1.Breeze
    local u14 = Passives_upv_1["Woodland Terrain"]
    local v26 = 0
    local v27 = false
    local v28, v29, v29, v29, v29, v29, v30, v31 = nil, nil, nil, nil, nil, nil, nil, nil
    v28 = u1
    for _, value_3 in EffectReplicator_upv_1:GetEffects() do
        if value_3.Class == "SprintSpeed" then
            if v9 then
                continue
            end
            v30 = 0
            if v19.Sprinting then
                v30 = 1.6
            elseif not v19.CriticalWind and not v19.MobilitySpell and v21 < u7 then
                local v32 = -1.6
                if v20 then
                    if u7 < 3 then
                        v30 = v32
                    else
                        v30 = v32 * 2
                    end
                else
                    v30 = v32
                end
            end
            v31 = v30 * a1
            if v31 < 0 then
                v31 = math.max(v31, -u7)
            end
            u7 = math.clamp(u7 + v31, v21 - 2, 4)
            if v19.UsingSpell and not (v19.MobilitySpell) or v19.Stun then
                u7 = math.min(u7, v21)
            end
            local v33 = u7 + 6
            if value_3.Value ~= v33 then
                value_3.Value = v33
                if tick() - u8 > 0.2 then
                    CharacterHandler_upv_1.Requests.ServerMomentum:FireServer(value_3.Value)
                    u8 = tick()
                end
            end
            local v34 = value_3.Value + 4 * (Humanoid_upv_1.Health / Humanoid_upv_1.MaxHealth)
            v34 = ((v19.FoodBuff_speed) and (v34 * 1.2)) or v34
            v6 = v19.Sprinting and RealmInfo_upv_1.Hardcore and (v19.Danger or v6 + v34 + 2)
            if value_3.Value < 10 then
                local v35 = value_3:HasTag("MaxMomentum")
                if not (v35) then
                    continue
                end
                value_3:RemoveTag("MaxMomentum")
                if v20 then
                    ReplicatedStorage_upv_1.Requests.ClientEffectDirect:Fire("MaxMomentum", {On = false, CH = Character_upv_1})
                end
            else
                local v36 = value_3:HasTag("MaxMomentum")
                if v36 then
                    continue
                end
                value_3:AddTag("MaxMomentum")
                ReplicatedStorage_upv_1.Requests.ClientEffectDirect:Fire("WindTrails", {Duration = 1, char = Character_upv_1})
                if v20 then
                    ReplicatedStorage_upv_1.Requests.ClientEffectDirect:Fire("MaxMomentum", {On = true, CH = Character_upv_1})
                end
            end
        elseif value_3.Class == "Speed" then
            if v9 then
                if value_3.Class == "CrystalCombo" then
                    v26 = v26 + 1
                    continue
                end
                if value_3.Class == "FlameBuff" then
                    v6 = v6 + 2
                    continue
                end
                if value_3.Class == "FreezeRoot" then
                    v17 = true
                    continue
                end
                if value_3.Class == "ForceSpeedBuff" then
                    v6 = v6 + value_3.Value
                    continue
                end
                if value_3.Class == "Stun" then
                    v10 = true
                    v7 = 0
                    v8 = v8 + 1
                    v27 = true
                    u13 = u13 - 6
                    continue
                end
                if value_3.Class == "Parried" then
                    v7 = 0
                    v10 = true
                    u13, v27 = u13 - 3, true
                    continue
                end
                if value_3.Class == "LightningStun" then
                    u13, v10, v7 = u13 - 12, true, 0
                    continue
                end
                if value_3.Class ~= "SlowTime" then
                    if value_3.Class ~= "OverrideSpeed" or v9 then
                        if value_3.Class == "NoJump" then
                            v10, v7 = true, 0
                            continue
                        end
                        if value_3.Class == "Falling" then
                            v10, v7 = true, 0
                            continue
                        end
                        if value_3.Class == "NoJumpAlt" then
                            v10, v7 = true, 0
                            continue
                        end
                        if value_3.Class == "Heavy" then
                            v10, v7 = true, 10
                            continue
                        end
                        if value_3.Class == "LightAttack" then
                            v7 = 0
                            u13, v10 = u13 - 2, true
                            continue
                        end
                        if value_3.Class == "UsingCritical" then
                            u13 = u13 - 10
                            continue
                        end
                        if value_3.Class == "Chilled" then
                            local v37 = 5
                            if v19.UsingAbility then
                                u13 = u13 - v37
                                continue
                            end
                            if v19.LightAttack then
                                u13 = u13 - v37
                                continue
                            end
                            if not (v19.Parried) then
                                v37 = v37 * 0.7
                            end
                            u13 = u13 - v37
                        elseif value_3.Class == "Blocking" then
                            v7 = 0
                            if not (v19.HasFist) then
                                local v38 = 4
                                u13 = u13 - (Passives_upv_1["Moving Fortress"] and 4 / 1.35 or 4)
                                v10 = true
                                continue
                            end
                            if not (Passives_upv_1["Captain Etrea"]) then
                                local v38 = 4
                                u13 = u13 - (Passives_upv_1["Moving Fortress"] and 4 / 1.35 or 4)
                            end
                            v10 = true
                        elseif value_3.Class ~= "DecisiveAura" then
                            if value_3.Class == "ClientCrouch" then
                                u13 = ((Passives_upv_1.Lowstride) and (u13 - 1)) or (u13 - 6)
                                continue
                            end
                            if value_3.Class == "ClientSwim" then
                                u13 = u13 - 4 - math.map(Humanoid_upv_1.Health / Humanoid_upv_1.MaxHealth, 0, 1, 2, 0)
                                v7 = 0
                                v10 = true
                                Value_1 = value_3.Value
                                if not (Passives_upv_1["Freestyler's Band"]) then
                                    u13 = ((Passives_upv_1.OneBit) and (u13 - 4)) or u13
                                    continue
                                end
                                u13 = ((Passives_upv_1.OneBit) and (u13 - 4)) or u13
                                
                            elseif value_3.Class ~= "Action" and value_3.Class ~= "NoMove" and value_3.Class ~= "CharacterCreator" and value_3.Class ~= "InDialogue" then
                                if value_3.Class == "Gliding" then
                                    v9, u13, v10, v7 = true, 1, true, 0
                                    continue
                                end
                                if value_3.Class == "AutoRotate" then
                                    v13 = true
                                    continue
                                end
                                if value_3.Class == "Carried" then
                                    v9, u13, v10, v7, v11, v12 = true, 0, true, 0, false, true
                                    continue
                                end
                                if value_3.Class == "RootedGesture" then
                                    v11, v12 = false, true
                                    continue
                                end
                                if value_3.Class == "PlatformStand" then
                                    v11, v12 = false, true
                                    continue
                                end
                                if value_3.Class == "Pinned" then
                                    v9, u13, v10, v7, v11, v12 = true, 0, true, 0, false, true
                                    continue
                                end
                                if value_3.Class ~= "Mounted" then
                                    if value_3.Class == "MountDash" then
                                        v28 = v28 - 10 * value_3.Value
                                        u13 = u13 + 20 * value_3.Value
                                        continue
                                    end
                                    if value_3.Class == "Steering" then
                                        v7 = 0
                                        v10 = true
                                        v11 = false
                                        v12 = true
                                        v14 = v14 + 100
                                        continue
                                    end
                                    if value_3.Class == "DangerBoss" then
                                        v14 = v14 + 50
                                        continue
                                    end
                                    if value_3.Class == "NoTools" then
                                        Humanoid_upv_1:UnequipTools()
                                        continue
                                    end
                                    if value_3.Class == "NoRotate" then
                                        v11 = false
                                        continue
                                    end
                                    if value_3.Class == "ClientSlide" then
                                        v11 = false
                                        continue
                                    end
                                    if value_3.Class == "Knocked" then
                                        v9, u13, v10, v7, v11, v12 = true, 0, true, 0, false, true
                                        continue
                                    end
                                    if value_3.Class ~= "ForceEquip" then
                                        if value_3.Class == "FieldOfView" then
                                            v28 = v28 + value_3.Value
                                            continue
                                        end
                                        if value_3.Class == "LightingBlur" then
                                            v15 = v15 + value_3.Value
                                            continue
                                        end
                                        if value_3.Class ~= "Gravity" or not (value_3.Value) then
                                            continue
                                        end
                                        if typeof(value_3.Value) == "number" then
                                            v18 = value_3.Value
                                            continue
                                        end
                                    else
                                        local Value_2 = value_3.Value
                                        if not (Value_2) or not (Value_2.Parent) then
                                            continue
                                        end
                                        if Value_2.Parent ~= Character_upv_1 then
                                            Humanoid_upv_1:EquipTool(value_3.Value)
                                            continue
                                        end
                                    end
                                else
                                    v28 = v28 + 5
                                    v14 = v14 + 25
                                    if not (v10) then
                                        v7 = v7 + 30
                                    end
                                    u13 = u13 + 6
                                end
                            else
                                v7 = 0
                                local v39 = EffectReplicator_upv_1:HasEffect("NoSpeedAction")
                                if not (v39) then
                                    v9, u13 = true, 0
                                end
                                v10 = true
                                v11 = false
                                if value_3.Class == "CharacterCreator" then
                                    v17, v16 = true, true
                                end
                                continue
                            end
                        else
                            local Value_3 = value_3.Value
                            if not (Value_3) then
                                continue
                            end
                            if (HumanoidRootPart_upv_1.Position - Value_3.Position).Magnitude < 30 then
                                v6 = v6 + 4
                                continue
                            end
                        end
                        continue
                    end
                    v9, u13 = true, value_3.Value
                    continue
                else
                    for v53, value_4 in Humanoid_upv_1:GetPlayingAnimationTracks() do
                        value_4:AdjustSpeed(0.3)
                    end
                end
            else
                v29 = value_3.Value
                if v29 > 0 and (v19.SunkenPredator or v19.MetalShackle or v19.LegShot) then
                    v29 = 0
                end
                if v29 < 0 and not (v19.UsingAbility) and not (v19.LightAttack) and not (v19.Parried) then
                    v29 = ((value_3.Tags.WindSlow) and (v29 * 0.9)) or (v29 * 0.75)
                end
                if v29 < 0 then
                    v29 = ((Passives_upv_1.Conditioning) and (v29 * 0.6)) or v29
                end
                if v29 < 0 then
                    v29 = ((Passives_upv_1.Swiftfoot) and (v29 * 0.9)) or v29
                end
                if Passives_upv_1["Fictitious Force"] and v29 > 0 then
                    v29 = v29 * 0.5
                end
                if v19.ClientSwim and v29 > 0 then
                    if value_3:HasTag("Potion_Speed") or EffectReplicator_upv_1:HasEffect("DiveCheck") then
                        v29 = v29 * 0.5
                        if v29 <= 0 then
                            u13 = u13 + v29
                        else
                            v6 = v6 + v29
                        end
                        continue
                    end
                    v29 = v29 * 0.8
                end
                if v29 <= 0 then
                    u13 = u13 + v29
                else
                    v6 = v6 + v29
                end
            end
        elseif value_3.Class ~= "SpeedUp" or v9 then
            if value_3.Class == "CrystalCombo" then
                v26 = v26 + 1
                continue
            end
            if value_3.Class == "FlameBuff" then
                v6 = v6 + 2
                continue
            end
            if value_3.Class == "FreezeRoot" then
                v17 = true
                continue
            end
            if value_3.Class == "ForceSpeedBuff" then
                v6 = v6 + value_3.Value
                continue
            end
            if value_3.Class == "Stun" then
                v10 = true
                v7 = 0
                v8 = v8 + 1
                v27 = true
                u13 = u13 - 6
                continue
            end
            if value_3.Class == "Parried" then
                v7 = 0
                v10 = true
                u13, v27 = u13 - 3, true
                continue
            end
            if value_3.Class == "LightningStun" then
                u13, v10, v7 = u13 - 12, true, 0
                continue
            end
            if value_3.Class ~= "SlowTime" then
                if value_3.Class ~= "OverrideSpeed" or v9 then
                    if value_3.Class == "NoJump" then
                        v10, v7 = true, 0
                        continue
                    end
                    if value_3.Class == "Falling" then
                        v10, v7 = true, 0
                        continue
                    end
                    if value_3.Class == "NoJumpAlt" then
                        v10, v7 = true, 0
                        continue
                    end
                    if value_3.Class == "Heavy" then
                        v10, v7 = true, 10
                        continue
                    end
                    if value_3.Class == "LightAttack" then
                        v7 = 0
                        u13, v10 = u13 - 2, true
                        continue
                    end
                    if value_3.Class == "UsingCritical" then
                        u13 = u13 - 10
                        continue
                    end
                    if value_3.Class == "Chilled" then
                        local v37 = 5
                        if v19.UsingAbility then
                            u13 = u13 - v37
                            continue
                        end
                        if v19.LightAttack then
                            u13 = u13 - v37
                            continue
                        end
                        if not (v19.Parried) then
                            v37 = v37 * 0.7
                        end
                        u13 = u13 - v37
                    elseif value_3.Class == "Blocking" then
                        v7 = 0
                        if not (v19.HasFist) then
                            local v38 = 4
                            u13 = u13 - (((Passives_upv_1["Moving Fortress"]) and (v38 / 1.35)) or v38)
                            v10 = true
                            continue
                        end
                        if not (Passives_upv_1["Captain Etrea"]) then
                            local v38 = 4
                            u13 = u13 - (Passives_upv_1["Moving Fortress"] and 4 / 1.35 or 4)
                        end
                        v10 = true
                    elseif value_3.Class ~= "DecisiveAura" then
                        if value_3.Class == "ClientCrouch" then
                            u13 = ((Passives_upv_1.Lowstride) and (u13 - 1)) or (u13 - 6)
                            continue
                        end
                        if value_3.Class == "ClientSwim" then
                            u13 = u13 - 4 - math.map(Humanoid_upv_1.Health / Humanoid_upv_1.MaxHealth, 0, 1, 2, 0)
                            v7 = 0
                            v10 = true
                            Value_1 = value_3.Value
                            if not (Passives_upv_1["Freestyler's Band"]) then
                                u13 = ((Passives_upv_1.OneBit) and (u13 - 4)) or u13
                                continue
                            end
                            u13 = ((Passives_upv_1.OneBit) and (u13 - 4)) or u13
                        elseif value_3.Class ~= "Action" and value_3.Class ~= "NoMove" and value_3.Class ~= "CharacterCreator" and value_3.Class ~= "InDialogue" then
                            if value_3.Class == "Gliding" then
                                v9, u13, v10, v7 = true, 1, true, 0
                                continue
                            end
                            if value_3.Class == "AutoRotate" then
                                v13 = true
                                continue
                            end
                            if value_3.Class == "Carried" then
                                v9, u13, v10, v7, v11, v12 = true, 0, true, 0, false, true
                                continue
                            end
                            if value_3.Class == "RootedGesture" then
                                v11, v12 = false, true
                                continue
                            end
                            if value_3.Class == "PlatformStand" then
                                v11, v12 = false, true
                                continue
                            end
                            if value_3.Class == "Pinned" then
                                v9, u13, v10, v7, v11, v12 = true, 0, true, 0, false, true
                                continue
                            end
                            if value_3.Class ~= "Mounted" then
                                if value_3.Class == "MountDash" then
                                    v28 = v28 - 10 * value_3.Value
                                    u13 = u13 + 20 * value_3.Value
                                    continue
                                end
                                if value_3.Class == "Steering" then
                                    v7 = 0
                                    v10 = true
                                    v11 = false
                                    v12 = true
                                    v14 = v14 + 100
                                    continue
                                end
                                if value_3.Class == "DangerBoss" then
                                    v14 = v14 + 50
                                    continue
                                end
                                if value_3.Class == "NoTools" then
                                    Humanoid_upv_1:UnequipTools()
                                    continue
                                end
                                if value_3.Class == "NoRotate" then
                                    v11 = false
                                    continue
                                end
                                if value_3.Class == "ClientSlide" then
                                    v11 = false
                                    continue
                                end
                                if value_3.Class == "Knocked" then
                                    v9, u13, v10, v7, v11, v12 = true, 0, true, 0, false, true
                                    continue
                                end
                                if value_3.Class ~= "ForceEquip" then
                                    if value_3.Class == "FieldOfView" then
                                        v28 = v28 + value_3.Value
                                        continue
                                    end
                                    if value_3.Class == "LightingBlur" then
                                        v15 = v15 + value_3.Value
                                        continue
                                    end
                                    if value_3.Class ~= "Gravity" or not (value_3.Value) then
                                        continue
                                    end
                                    if typeof(value_3.Value) == "number" then
                                        v18 = value_3.Value
                                        continue
                                    end
                                else
                                    local Value_2 = value_3.Value
                                    if not (Value_2) or not (Value_2.Parent) then
                                        continue
                                    end
                                    if Value_2.Parent ~= Character_upv_1 then
                                        Humanoid_upv_1:EquipTool(value_3.Value)
                                        continue
                                    end
                                end
                            else
                                v28 = v28 + 5
                                v14 = v14 + 25
                                if not (v10) then
                                    v7 = v7 + 30
                                end
                                u13 = u13 + 6
                            end
                        else
                            v7 = 0
                            local v39 = EffectReplicator_upv_1:HasEffect("NoSpeedAction")
                            if not (v39) then
                                v9, u13 = true, 0
                            end
                            v10 = true
                            v11 = false
                            if value_3.Class == "CharacterCreator" then
                                v17, v16 = true, true
                            end
                            continue
                        end
                    else
                        local Value_3 = value_3.Value
                        if not (Value_3) then
                            continue
                        end
                        if (HumanoidRootPart_upv_1.Position - Value_3.Position).Magnitude < 30 then
                            v6 = v6 + 4
                            continue
                        end
                    end
                    continue
                end
                v9, u13 = true, value_3.Value
                continue
            else
                for v53, value_4 in Humanoid_upv_1:GetPlayingAnimationTracks() do
                    value_4:AdjustSpeed(0.3)
                end
            end
        else
            v29 = value_3.Value
            if v29 > 0 and (v19.SunkenPredator or v19.MetalShackle or v19.LegShot) then
                v29 = 0
            end
            if v29 < 0 and not (v19.UsingAbility) and not (v19.LightAttack) and not (v19.Parried) then
                v29 = ((value_3.Tags.WindSlow) and (v29 * 0.9)) or (v29 * 0.75)
            end
            if v29 < 0 then
                v29 = ((Passives_upv_1.Conditioning) and (v29 * 0.6)) or v29
            end
            if v29 < 0 then
                v29 = ((Passives_upv_1.Swiftfoot) and (v29 * 0.9)) or v29
            end
            if Passives_upv_1["Fictitious Force"] and v29 > 0 then
                v29 = v29 * 0.5
            end
            if v19.ClientSwim and v29 > 0 then
                if value_3:HasTag("Potion_Speed") or EffectReplicator_upv_1:HasEffect("DiveCheck") then
                    v29 = v29 * 0.5
                    if v29 <= 0 then
                        u13 = u13 + v29
                    else
                        v6 = v6 + v29
                    end
                    continue
                end
                v29 = v29 * 0.8
            end
            if v29 <= 0 then
                u13 = u13 + v29
            else
                v6 = v6 + v29
            end
        end
    end
    if v26 > 0 then
        u13 = u13 - v26 * 0.5
    end
    u13 = (Wormwarder_1 and (u13 - 4)) or u13
    u13 = (v22 and (u13 - 2)) or u13
    u13 = (v23 and (u13 - 2.5)) or u13
    if v25 or Hyperbody_1 then
        u13 = u13 - 4.5
    end
    u13 = (Haste_1 and (u13 + 3)) or ((Breeze_1 and (u13 + 2)) or u13)
    pcall(
        function()
            local SensedMaterial_1 = GroundSensor_upv_1.SensedMaterial
            if not u14 or SensedMaterial_1 ~= Enum.Material.Grass and SensedMaterial_1 ~= Enum.Material.LeafyGrass then
                return
            end
            u13 = u13 + 1.5
        end
    )
    if v24 then
        local v40 = EffectReplicator_upv_1:HasEffect("VoidGluttonHealth") and EffectReplicator_upv_1:FindEffect("VoidGluttonHealth").Value or 0
        u13 = u13 - (4 + ((v40 / 20) + 4))
    end
    if v18 then
        workspace.Gravity = v18
    else
        workspace.Gravity = u3
    end
    local v41 = Humanoid_upv_1:GetAttribute("CarryLoad") or 0
    local v42 = Humanoid_upv_1:GetAttribute("CarryMax") or 100
    if v42 < v41 then
        local v43 = math.min((v41 / v42 - 1) / 0.2, 1) * 2 + 2
        u13 = u13 - v43
    end
    local v44 = math.max((Character_upv_1:GetAttribute("EquipmentWeight") or 0) - (Character_upv_1:GetAttribute("EquipmentCapacity") or 5.5), 0)
    if v44 > 0 then
        u13 = u13 - v44
    end
    if Character_upv_1 then
        local Armor_1 = Character_upv_1:FindFirstChild("Armor")
        if Armor_1 and Passives_upv_1.Lightweight and (Character_upv_1.Armor.Value <= 0 or v19.BerserkState) and u13 > 0 then
            v6 = v6 + 3
        end
    end
    if v19.Danger then
        v30 = -Humanoid_upv_1.MoveDirection:Dot(Lib_upv_1.horizontalCF(CurrentCamera_upv_1.CFrame).LookVector)
        if v30 > 0.1 then
            v6 = v6 * math.map(math.clamp((v30 - 0.1) / 0.4, 0, 1), 0, 1, 1, 0.25)
        end
    end
    if v6 > 0 and not (v19.OverrideSpeedCap) then
        v6 = v6 / (v6 + 30) * 40
    end
    u13 = u13 + (((v19.Mounted) and (v6 * 0.2)) or v6)
    if v19.ClientSwim then
        local v45 = math.sin((Value_1 + 0.25) * 2 * math.pi) * 2
        u13 = u13 + v45
    end
    u13 = math.max(0, u13)
    if v19.SlowTime then
        u13 = u13 * 0.25
    elseif v19.StopTime then
        u13 = u13 * 0.01
    end
    if v8 == 1 then
        u13 = u13 * 0.75
    elseif v8 == 2 then
        u13 = u13 * 0.6
    elseif v8 > 2 then
        u13 = u13 * 0.45
    end
    if v19.Confused then
        Humanoid_upv_1:SetAttribute("InvertedControls", true)
    elseif Humanoid_upv_1:GetAttribute("InvertedControls") then
        Humanoid_upv_1:SetAttribute("InvertedControls", nil)
    end
    Humanoid_upv_1.WalkSpeed = u13
    v7 = math.max(0, ((v19.Gravity) and (v7 * 0.2)) or v7)
    Humanoid_upv_1:SetStateEnabled("Seated", false)
    if Humanoid_upv_1.SeatPart then
        Humanoid_upv_1:SetStateEnabled("Seated", true)
        v7 = 10
    end
    if IsScyphozia_upv_1 then
        v7 = v7 * 0.714
    end
    if v27 then
        for _, value_5 in pairs(game.CollectionService:GetTagged("LocalMover")) do
            value_5.Velocity = Vector3.new(0, 0, 0)
            value_5.MaxForce = Vector3.new(1000, 1000, 1000)
            game.Debris:AddItem(value_5, 0.1)
        end
    end
    Humanoid_upv_1.AutoRotate = v11
    if v13 == true then
        Humanoid_upv_1.AutoRotate = true
    end
    Humanoid_upv_1.PlatformStand = v12
    Humanoid_upv_1.JumpPower = v7
    if v7 ~= 0 then
        Humanoid_upv_1:SetStateEnabled("Jumping", true)
    else
        Humanoid_upv_1:SetStateEnabled("Jumping", false)
        Humanoid_upv_1.Jump = false
    end
    local SHUTDOWN_1 = ReplicatedStorage_upv_1:FindFirstChild("SHUTDOWN")
    if SHUTDOWN_1 then
        v17 = true
    end
    if HumanoidRootPart_upv_1.Anchored ~= v17 then
        HumanoidRootPart_upv_1.Anchored = v17
    end
    if LocalPlayer_upv_1:HasTag("ForcedSubject") then
        local v46 = nil
        if not (LocalPlayer_upv_1:HasTag("WatchDead")) then
            v46 = CurrentCamera_upv_1.CameraSubject
            if v46 and not (v46.Parent) then
                CurrentCamera_upv_1.CameraSubject = Humanoid_upv_1
            end
        end
    else
        CurrentCamera_upv_1.CameraSubject = Humanoid_upv_1
    end
    if not (LocalPlayer_upv_1:HasTag("FreezeCamera")) then
        CurrentCamera_upv_1.CameraType = (v16 and (Enum.CameraType.Scriptable)) or (Enum.CameraType.Custom)
    end
    local _, v54 = TweenService_upv_1:SmoothDamp(u5, HumanoidRootPart_upv_1.AssemblyLinearVelocity.Magnitude, u6, 0.5, 20, a1)
    v28 = (LocalPlayer_upv_1:GetAttribute("DynamicFOV") and (v28 + math.clamp((math.max(u5 - 20, 0) / 15) ^ 2.5, 0, 10))) or v28
    if LocalPlayer_upv_1:GetAttribute("CameraSmoothing") then
        if EffectReplicator_upv_1:HasEffect("HasBow") and EffectReplicator_upv_1:HasEffect("Equipped") and UserInputService_upv_1.MouseBehavior == Enum.MouseBehavior.LockCenter then
            if EffectReplicator_upv_1:HasEffect("HasBow") and EffectReplicator_upv_1:HasEffect("Equipped") then
                if UserInputService_upv_1.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
                    Humanoid_upv_1.CameraOffset = Vector3.new(0, 0, 0)
                else
                    Humanoid_upv_1.CameraOffset = Vector3.new(2, 0, 0)
                end
            else
                Humanoid_upv_1.CameraOffset = Vector3.new(0, 0, 0)
            end
        else
            local v47 = (HumanoidRootPart_upv_1.CFrame * CFrame.new(0, math.clamp(u5 / 80, 0, 0.75) + 1.1, 0)):PointToObjectSpace(Character_upv_1.Torso.Position + Vector3.new(0, 1.5, 0))
            local v48 = math.clamp(LocalPlayer_upv_1:GetAttribute("CameraZoomZ") or 0, -10, 10)
            local v55, v56 = TweenService_upv_1:SmoothDamp(u9, v48, u10, 0.25, 12, a1)
            local v49, v50 = TweenService_upv_1:SmoothDamp(Humanoid_upv_1.CameraOffset, v47 + Vector3.new(0, 0, u9), u11, 0.15, 16, a1)
            u11 = v50
            Humanoid_upv_1.CameraOffset = v49
        end
    elseif EffectReplicator_upv_1:HasEffect("HasBow") and EffectReplicator_upv_1:HasEffect("Equipped") then
        if UserInputService_upv_1.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
            Humanoid_upv_1.CameraOffset = Vector3.new(0, 0, 0)
        else
            Humanoid_upv_1.CameraOffset = Vector3.new(2, 0, 0)
        end
    else
        Humanoid_upv_1.CameraOffset = Vector3.new(0, 0, 0)
    end
    if v16 or LocalPlayer_upv_1:GetAttribute("Freecam") or LocalPlayer_upv_1:GetAttribute("InCutscene") or CurrentCamera_upv_1.CameraType == Enum.CameraType.Scriptable then
        u12 = 0
    else
        local v51, v52 = TweenService_upv_1:SmoothDamp(CurrentCamera_upv_1.FieldOfView, math.clamp(v28, 1, 109), u12, 0.1, nil, a1)
        u12 = v52
        CurrentCamera_upv_1.FieldOfView = v51
    end
    if v15 ~= u4 then
        local tbl_2 = {}
        tbl_2.Size = v15
        game.TweenService:Create(GenericBlur_upv_1, TweenInfo.new(1), tbl_2):Play()
    end
    GenericBlur_upv_1.Enabled = GenericBlur_upv_1.Size > 0
    v14 = math.clamp(v14, 0.5, 400)
    if v14 ~= u2 then
        local tbl_3 = {}
        tbl_3.CameraMaxZoomDistance = v14
        game.TweenService:Create(LocalPlayer_upv_1, TweenInfo.new(1), tbl_3):Play()
    end
    u2 = v14
    u4 = v15
    if UserInputService_upv_1.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
        if not v19.CameraLock then
            return
        end
        EffectReplicator_upv_1:RemoveEffectsOfClass("CameraLock")
        ReplicatedStorage_upv_1.Requests.UpdateCameraLock:FireServer(false)
    elseif not v19.CameraLock then
        EffectReplicator_upv_1:CreateEffect("CameraLock")
        ReplicatedStorage_upv_1.Requests.UpdateCameraLock:FireServer(true)
    end
end
EffectReplicator_upv_1.EffectAdded:Connect(
    function(a1)
        if a1.Class == "AddMomentum" then
            u7 = u7 + a1.Value
        elseif a1.Class == "FallCancel" then
            EffectReplicator_upv_1:RemoveEffectsOfClass("Falling")
        elseif a1.Class == "ResetMomentum" then
            u7 = 0
        elseif a1.Class == "ForceMomentum" then
            local v53 = a1.Value - 6
            if u7 < v53 then
                u7 = v53
            end
        end
    end
)
LocalPlayer_upv_1:GetAttributeChangedSignal("FieldOfView"):Connect(
    function()
        u1 = LocalPlayer_upv_1:GetAttribute("FieldOfView")
    end
)
RunService_1.PreRender:Connect(
    function(a1)
        Lib_upv_1.xpcall(
            function()
                processEffects(a1)
            end,
            nil,
            "warn"
        )
    end
)
