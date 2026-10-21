local Environment = {}

---@return boolean
Environment.isTester = LPH_NO_VIRTUALIZE(function()
	return LRM_ScriptName == "testing" or not LPH_OBFUSCATED
end)

return Environment
