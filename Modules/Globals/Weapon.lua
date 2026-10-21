---@module Game.Timings.Action
local Action = getfenv().Action

-- Weapon module.
local Weapon = {}

---Find HandWeapon in workspace.Thrown for an entity.
---The game stores weapon models under workspace.Thrown.Attach_<entityname>.
---@param entityName string The entity's Name.
---@return Model?
local function findThrownHandWeapon(entityName)
	local thrown = workspace:FindFirstChild("Thrown")
	if not thrown then
		return nil
	end

	local attach = thrown:FindFirstChild("Attach_" .. entityName)
	if not attach then
		return nil
	end

	return attach:FindFirstChild("HandWeapon")
end

---Get equipped weapon data.
---@param entity Model
function Weapon.data(entity)
	local lh = entity:FindFirstChild("LeftHand")
	local rh = entity:FindFirstChild("RightHand")
	if not lh and not rh then
		return
	end

	-- Try direct hand children first (legacy), then fall back to workspace.Thrown (new layout).
	local hw = (lh and lh:FindFirstChild("HandWeapon")) or (rh and rh:FindFirstChild("HandWeapon"))
	if not hw then
		hw = findThrownHandWeapon(entity.Name)
	end
	if not hw then
		return
	end

	local hwstats = hw:FindFirstChild("Stats")
	if not hwstats then
		return
	end

	local ssv = hwstats:FindFirstChild("SwingSpeed")
	if not ssv then
		return
	end

	local lv = hwstats:FindFirstChild("Length")
	if not lv then
		return
	end

	local type = hw:FindFirstChild("Type")
	if not type then
		return
	end

	local nemesis = false

	for _, inst in next, hw:GetChildren() do
		if not inst:IsA("ParticleEmitter") then
			continue
		end

		if inst.Texture ~= "rbxassetid://11889781532" then
			continue
		end

		nemesis = true
		break
	end

	return {
		hw = hw,
		ss = ssv.Value,
		oss = ssv:GetAttribute("OldValue") or ssv.Value,
		length = lv.Value,
		type = type.Value or "N/A",
		nemesis = nemesis,
	}
end

---Find the HandWeapon model for an entity.
---Checks direct hand children first, then falls back to workspace.Thrown.
---@param entity Model
---@return Model?
function Weapon.handWeapon(entity)
	local lh = entity:FindFirstChild("LeftHand")
	local rh = entity:FindFirstChild("RightHand")
	local hw = (lh and lh:FindFirstChild("HandWeapon")) or (rh and rh:FindFirstChild("HandWeapon"))
	if not hw then
		hw = findThrownHandWeapon(entity.Name)
	end
	return hw
end

-- Return Weapon module.
return Weapon

