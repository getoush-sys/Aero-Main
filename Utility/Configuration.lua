local Configuration = {}

---@param key string
---@return any?
Configuration.expectToggleValue = LPH_NO_VIRTUALIZE(function(key)
	if not Toggles then
		return nil
	end

	local toggle = Toggles[key]

	if not toggle then
		return nil
	end

	return toggle.Value
end)

---@param key string
---@return any?
Configuration.expectOptionValue = LPH_NO_VIRTUALIZE(function(key)
	if not Options then
		return nil
	end

	local option = Options[key]

	if not option then
		return nil
	end

	return option.Value
end)

---@param key string
---@return any?
Configuration.expectOptionValues = LPH_NO_VIRTUALIZE(function(key)
	if not Options then
		return nil
	end

	local option = Options[key]

	if not option then
		return nil
	end

	return option.Values
end)

---@param identifier string
---@param topLevelIdentifier string
---@return string
Configuration.identify = LPH_NO_VIRTUALIZE(function(identifier, topLevelIdentifier)
	return identifier .. topLevelIdentifier
end)

local composedKeyCache = {}

---@param identifier string
---@param topLevelIdentifier string
---@return string
local resolveKey = LPH_NO_VIRTUALIZE(function(identifier, topLevelIdentifier)
	local sub = composedKeyCache[identifier]
	if not sub then
		sub = {}
		composedKeyCache[identifier] = sub
	end

	local key = sub[topLevelIdentifier]
	if not key then
		key = identifier .. topLevelIdentifier
		sub[topLevelIdentifier] = key
	end

	return key
end)

---@param identifier string
---@param topLevelIdentifier string
---@return any
Configuration.idToggleValue = LPH_NO_VIRTUALIZE(function(identifier, topLevelIdentifier)
	if not Toggles then
		return nil
	end

	local toggle = Toggles[resolveKey(identifier, topLevelIdentifier)]
	if not toggle then
		return nil
	end

	return toggle.Value
end)

---@param identifier string
---@param topLevelIdentifier string
---@return any
Configuration.idOptionValue = LPH_NO_VIRTUALIZE(function(identifier, topLevelIdentifier)
	if not Options then
		return nil
	end

	local option = Options[resolveKey(identifier, topLevelIdentifier)]
	if not option then
		return nil
	end

	return option.Value
end)

---@param identifier string
---@param topLevelIdentifier string
---@return any
Configuration.idOptionValues = LPH_NO_VIRTUALIZE(function(identifier, topLevelIdentifier)
	if not Options then
		return nil
	end

	local option = Options[resolveKey(identifier, topLevelIdentifier)]
	if not option then
		return nil
	end

	return option.Values
end)

return Configuration
