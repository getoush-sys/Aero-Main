return LPH_NO_VIRTUALIZE(function()
	---@class Filesystem
	---@field _path string
	local Filesystem = {}
	Filesystem.__index = Filesystem

	---@return string
	function Filesystem:path()
		if not isfolder(self._path) then
			makefolder(self._path)
		end

		return self._path
	end

	---@param path string
	---@return string
	function Filesystem:append(path)
		return self:path() .. "\\" .. path
	end

	---@param filename string
	---@return boolean
	function Filesystem:file(filename)
		return isfile(self:append(filename))
	end

	---@param filename string
	---@return string
	function Filesystem:read(filename)
		if not self:file(filename) then
			return error("File does not exist or is a folder.", 2)
		end

		return readfile(self:append(filename))
	end

	---@param filename string
	---@return string
	function Filesystem:delete(filename)
		if not self:file(filename) then
			return error("File does not exist or is a folder.", 2)
		end

		return delfile(self:append(filename))
	end

	---@param filename string
	---@param contents string?
	function Filesystem:write(filename, contents)
		writefile(self:append(filename), contents and contents or "")
	end

	---@param raw boolean?
	---@return table
	function Filesystem:list(raw)
		local list = listfiles(self:path())
		if not list then
			return error("File list does not exist.", 2)
		end

		local new = {}

		for idx, path in next, list do
			---@note: Non-raw weird behavior where the path is never detected in the string. Let's manually index remove it.
			new[idx] = raw and path or string.sub(path, #(self:path() .. "\\") + 1, #path)
		end

		return new
	end

	---@param path string
	---@return Filesystem
	function Filesystem.new(path)
		local self = setmetatable({}, Filesystem)
		self._path = path
		return self
	end

	return Filesystem
end)()
