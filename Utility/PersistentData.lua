---@module Utility.Serializer
local Serializer = require("Utility/Serializer")

---@module Utility.Deserializer
local Deserializer = require("Utility/Deserializer")

---@module Utility.String
local String = require("Utility/String")

---@module Utility.Logger
local Logger = require("Utility/Logger")

local PersistentData = {
	_data = {
		fli = nil,

		shslot = nil,

		sblacklist = {},

		wdata = nil,

		efdata = nil,
	},
}

local memStorageService = game:GetService("MemStorageService")

---@param field string
---@return any
function PersistentData.get(field)
	return PersistentData._data[field]
end

---@param field string
---@param key string
---@param value any
function PersistentData.stf(field, key, value)
	local tbl = PersistentData.get(field)

	if type(tbl) ~= "table" then
		return error(string.format("PersistentData field '%s' is not a table.", tostring(field)))
	end

	tbl[key] = value

	PersistentData.set(field, tbl)
end

---@param field string
---@param value any
function PersistentData.set(field, value)
	PersistentData._data[field] = value

	local marshalSuccess, payload = pcall(Serializer.marshal, PersistentData._data)
	if not marshalSuccess then
		return Logger.warn("(%s) Failed to marshal PersistentData snapshot.", tostring(payload))
	end

	local saveSuccess, saveResult = pcall(memStorageService.SetItem, memStorageService, "LYCORIS_PERSISTENT_DATA", payload)

	if not saveSuccess then
		return Logger.warn("(%s) Failed to set PersistentData snapshot.", tostring(saveResult))
	end

	if not LPH_OBFUSCATED or shared.Aero.verbose then
		Logger.warn("(%s) Successfully set PersistentData snapshot.", tostring(saveResult))
	end
end

function PersistentData.init()
	local hasSuccess, hasResult = pcall(memStorageService.HasItem, memStorageService, "LYCORIS_PERSISTENT_DATA")
	if not hasSuccess then
		return hasResult and Logger.warn("(%s) Failed to check for PersistentData snapshot.", tostring(hasResult))
	end

	local itemSuccess, itemResult = pcall(memStorageService.GetItem, memStorageService, "LYCORIS_PERSISTENT_DATA")
	if not itemSuccess then
		return Logger.warn("(%s) Failed to get PersistentData snapshot", tostring(itemResult))
	end

	if itemResult == nil or itemResult == "" then
		if not LPH_OBFUSCATED or shared.Aero.verbose then
			Logger.warn("PersistentData snapshot is missing or empty.")
		end

		return
	end

	local success, result = pcall(Deserializer.unmarshal_one, String.tba(itemResult))
	if not success then
		return Logger.warn("(%s) Failed to deserialize PersistentData snapshot.", tostring(result))
	end

	if not LPH_OBFUSCATED or shared.Aero.verbose then
		Logger.warn("(%s) Successfully loaded PersistentData snapshot.", tostring(result))
	end

	PersistentData._data = result
end

return PersistentData
