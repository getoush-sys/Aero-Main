return LPH_NO_VIRTUALIZE(function()
	---@class ReferencedMap
	---@field _map table
	---@field _references table
	local ReferencedMap = {}
	ReferencedMap.__index = ReferencedMap

	---@param ref any
	---@param element any
	function ReferencedMap:insert(ref, element)
		local key = #self._map + 1
		self._map[key] = element
		self._references[ref] = element
	end

	---@param ref any
	---@return any?
	function ReferencedMap:remove(ref)
		local element = self._references[ref]
		if not element then
			return nil
		end

		self._references[ref] = nil

		local position = table.find(self._map, element)
		if not position then
			return nil
		end

		table.remove(self._map, position)

		return element
	end

	---@return number
	function ReferencedMap:size()
		return #self._map
	end

	---@return table
	function ReferencedMap:data()
		return self._map
	end

	---@return ReferencedMap
	function ReferencedMap.new()
		local self = setmetatable({}, ReferencedMap)
		self._map = {}
		self._references = {}
		return self
	end

	return ReferencedMap
end)()
