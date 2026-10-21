
local Serializer = {}

---@param tbl table
---@return boolean
local function isAnArray(tbl)
	local expected = 1

	for k in next, tbl do
		if k ~= expected then
			return false
		end

		expected = expected + 1
	end

	return true
end

---@param value number
---@return string
local function serializeFloat(value)
	local serializedFloat = string.unpack("f", string.pack("f", value))
	if serializedFloat == value then
		return string.pack(">Bf", 0xca, value)
	end

	return string.pack(">Bd", 0xcb, value)
end

---@param value number
---@return string
local function serializeSignedInt(value)
	if value < 128 then
		return string.pack("B", value)
	elseif value <= 0xff then
		return string.pack("BB", 0xcc, value)
	elseif value <= 0xffff then
		return string.pack(">BI2", 0xcd, value)
	elseif value <= 0xffffffff then
		return string.pack(">BI4", 0xce, value)
	end

	return string.pack(">BI8", 0xcf, value)
end

---@param value number
---@return string
local function serializeUnsignedInt(value)
	if value >= -32 then
		return string.pack("B", 0xe0 + (value + 32))
	elseif value >= -128 then
		return string.pack("Bb", 0xd0, value)
	elseif value >= -32768 then
		return string.pack(">Bi2", 0xd1, value)
	elseif value >= -2147483648 then
		return string.pack(">Bi4", 0xd2, value)
	end

	return string.pack(">Bi8", 0xd3, value)
end

---@param value string
---@return string
local function serializeUtf8(value)
	local len = #value

	if len < 32 then
		return string.pack("B", 0xa0 + len) .. value
	elseif len < 256 then
		return string.pack(">Bs1", 0xd9, value)
	elseif len < 65536 then
		return string.pack(">Bs2", 0xda, value)
	end

	return string.pack(">Bs4", 0xdb, value)
end

---@param value string
---@return string
local function serializeStringBytes(value)
	local len = #value

	if len < 256 then
		return string.pack(">Bs1", 0xc4, value)
	elseif len < 65536 then
		return string.pack(">Bs2", 0xc5, value)
	end

	return string.pack(">Bs4", 0xc6, value)
end

local serializable = nil

---@param value table
---@return string
local function serializeArray(value)
	local elements = {}

	for i = 1, #value do
		local v = value[i]
		if serializable(v) then
			elements[#elements + 1] = Serializer.marshal(v)
		end
	end

	local result = table.concat(elements)
	local length = #elements

	if length < 16 then
		return string.pack(">B", 0x90 + length) .. result
	elseif length < 65536 then
		return string.pack(">BI2", 0xdc, length) .. result
	end

	return string.pack(">BI4", 0xdd, length) .. result
end

---@param value table
---@return string
local function serializeMap(value)
	local elements = {}

	for k, v in pairs(value) do
		if serializable(k) and serializable(v) then
			elements[#elements + 1] = Serializer.marshal(k)
			elements[#elements + 1] = Serializer.marshal(v)
		end
	end

	local length = math.floor(#elements / 2)
	if length < 16 then
		return string.pack(">B", 0x80 + length) .. table.concat(elements)
	elseif length < 65536 then
		return string.pack(">BI2", 0xde, length) .. table.concat(elements)
	end

	return string.pack(">BI4", 0xdf, length) .. table.concat(elements)
end

---@return string
local function serializeNil()
	return string.pack("B", 0xc0)
end

---@param value table
---@return string
local function serializeTable(value)
	return isAnArray(value) and serializeArray(value) or serializeMap(value)
end

---@param value boolean
---@return string
local function serializeBoolean(value)
	return string.pack("B", value and 0xc3 or 0xc2)
end

---@param value number
---@return string
local function serializeInt(value)
	return value >= 0 and serializeSignedInt(value) or serializeUnsignedInt(value)
end

---@param value number
---@return string
local function serializeNumber(value)
	return value % 1 == 0 and math.abs(value) < 2 ^ 53 and serializeInt(value) or serializeFloat(value)
end

---@param value number
---@return string
local function serializeString(value)
	return utf8.len(value) and serializeUtf8(value) or serializeStringBytes(value)
end

local typeToSerializeMap = {
	["nil"] = serializeNil,
	["boolean"] = serializeBoolean,
	["number"] = serializeNumber,
	["string"] = serializeString,
	["table"] = serializeTable,
}

serializable = function(value)
	return typeToSerializeMap[type(value)] ~= nil
end

---@param value any
---@return string
function Serializer.marshal(value)
	local serialize = typeToSerializeMap[type(value)]
	if not serialize then
		return serializeNil()
	end

	return serialize(value)
end

return Serializer
