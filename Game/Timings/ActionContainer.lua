---@module Game.Timings.Action
local Action = require("Game/Timings/Action")

---@class ActionContainer
---@field _data table<string, Action>
local ActionContainer = {}
ActionContainer.__index = ActionContainer

---@return ActionContainer
function ActionContainer:clone()
	local clone = ActionContainer.new()

	for _, action in next, self._data do
		clone:push(action:clone())
	end

	return clone
end

---@param other ActionContainer
---@return boolean
function ActionContainer:equals(other)
	if self:count() ~= other:count() then
		return false
	end

	for name, action in next, self._data do
		local otherAction = other:find(name)
		if not otherAction then
			return false
		end

		if not action:equals(otherAction) then
			return false
		end
	end

	return true
end

---@param name string
---@return Action?
function ActionContainer:find(name)
	return self._data[name]
end

---@param action Action
function ActionContainer:remove(action)
	self._data[action.name] = nil

	local idx = table.find(self._stack, action)
	if not idx then
		return
	end

	table.remove(self._stack, idx)
end

---@param action Action
function ActionContainer:push(action)
	local name = action.name

	---@note: Action array keys must all be unique.
	if self._data[name] then
		return error(string.format("Action name '%s' already exists in container.", name))
	end

	self._data[name] = action

	table.insert(self._stack, action)
end

---@param values table
function ActionContainer:load(values)
	for _, data in next, values do
		self:push(Action.new(data))
	end
end

---@return string[]
function ActionContainer:names()
	local names = {}

	for name, _ in next, self._data do
		table.insert(names, name)
	end

	return names
end

---@return Action[]
function ActionContainer:stack()
	return self._stack
end

---@return number
function ActionContainer:count()
	return #self._stack
end

function ActionContainer:clear()
	self._data = {}
	self._stack = {}
end

---@return table<string, Action>
function ActionContainer:get()
	return self._data
end

---@return table
function ActionContainer:serialize()
	local data = {}

	for _, action in next, self._data do
		table.insert(data, action:serialize())
	end

	return data
end

---@param values table?
---@return ActionContainer
function ActionContainer.new(values)
	local self = setmetatable({}, ActionContainer)

	self._data = {}
	self._stack = {}

	if values then
		self:load(values)
	end

	return self
end

return ActionContainer
