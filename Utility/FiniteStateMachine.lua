---@class FiniteStateMachine
---@field states FiniteState[]
---@field current string Current identifier.
---@field initial string Initial identifier.
---@field started boolean
local FiniteStateMachine = {}
FiniteStateMachine.__index = FiniteStateMachine

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@param states FiniteState[]
---@param initial string
---@return FiniteStateMachine
function FiniteStateMachine.new(states, initial)
	local self = setmetatable({}, FiniteStateMachine)
	self.states = states
	self.current = initial
	self.initial = initial
	self.started = false

	self:get(self.current)

	return self
end

---@param identifier string
---@return FiniteState
function FiniteStateMachine:get(identifier)
	for _, state in next, self.states do
		if state.identifier ~= identifier then
			continue
		end

		return state
	end

	return Logger.warn(string.format("(%s) State does not exist in states table.", identifier))
end

---@param identifier string
---@return boolean
function FiniteStateMachine:has(identifier)
	for _, state in next, self.states do
		if state.identifier ~= identifier then
			continue
		end

		return true
	end

	return false
end

function FiniteStateMachine:stop()
	if not self.started then
		return Logger.warn("Finite state machine has not been started.")
	end

	local current = self:get(self.current)
	current:detach()

	self.started = false
	self.current = self.initial
end

function FiniteStateMachine:start()
	if self.started then
		return Logger.warn("Finite state machine has already been started.")
	end

	self.started = true
	self.current = self.initial

	local current = self:get(self.current)
	current:start(self)
end

---@param identifier string
function FiniteStateMachine:transition(identifier)
	if not self.started then
		return Logger.warn("Finite state machine has not been started.")
	end

	local old = self:get(self.current)
	old:detach()

	self.current = identifier

	local new = self:get(identifier)
	new:start(self)
end

return FiniteStateMachine
