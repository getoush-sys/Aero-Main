---@class DeepwokenData
---@field talents table
---@field mantras table
local DeepwokenData = {}
DeepwokenData.__index = DeepwokenData

---@param name string
function DeepwokenData:get(name)
	return self.talents[string.lower(name)] or self.mantras[string.lower(name)]
end

---@param name string
---@param adata AttributeData
---@return boolean
function DeepwokenData:possible(name, adata)
	local data = self:get(name)
	if not data then
		return false
	end

	local formatted = {}

	if data.requirements and data.requirements.stats then
		for idx, value in pairs(data.requirements.stats) do
			formatted[idx] = value
		end
	elseif data.reqs then
		if data.reqs.base then
			for idx, value in pairs(data.reqs.base) do
				formatted[idx] = value
			end
		end

		if data.reqs.weapon then
			for idx, value in pairs(data.reqs.weapon) do
				formatted[idx] = value
			end
		end

		if data.reqs.attunement then
			for idx, value in pairs(data.reqs.attunement) do
				formatted[idx] = value
			end
		end
	else
		return false
	end

	return adata:possible(formatted)
end

---Whether an entry carries stat requirements (either schema).
---@param entry table
---@return boolean
local function hasReqs(entry)
	return (entry.requirements ~= nil and entry.requirements.stats ~= nil) or entry.reqs ~= nil
end

---@param values table
function DeepwokenData:load(values)
	-- Many talents have a duplicate "(VOI)" Voidwalker variant sharing the same name: the base entry
	-- carries the stat requirements, the variant has none (shop/memento acquisition). Storing whichever
	-- comes last would mask the real one, so a requirement-bearing variant always wins.
	local function ingest(source, target)
		for key, entry in pairs(source) do
			if typeof(entry) == "table" then
				local name = entry.name or (typeof(key) == "string" and key or nil)
				if name then
					local lname = string.lower(name)
					local existing = target[lname]
					if not existing or (hasReqs(entry) and not hasReqs(existing)) then
						target[lname] = entry
					end
				end
			end
		end
	end

	if typeof(values.talents) == "table" then
		self.talents = {}
		ingest(values.talents, self.talents)
	end

	if typeof(values.mantras) == "table" then
		self.mantras = {}
		ingest(values.mantras, self.mantras)
	end
end

---@param values table?
---@return DeepwokenData
function DeepwokenData.new(values)
	local self = setmetatable({}, DeepwokenData)

	self.talents = {}
	self.mantras = {}

	if values then
		self:load(values)
	end

	return self
end

return DeepwokenData
