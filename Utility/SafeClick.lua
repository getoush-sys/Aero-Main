---@note: Click a GuiButton by invoking its MouseButton1Click handlers DIRECTLY (conn.Function()), never via
---@note: firesignal() or conn:Fire(). Both of those are native-crash-prone and a pcall can NOT catch a native
---@note: fault:
---@note:   * conn:Fire() on a getconnections() object dereferences a null pointer on mac/macsploit -- the
---@note:     NULL+0x28 SIGSEGV that OptimizeGame documents and avoids.
---@note:   * firesignal() is in Aero's own "these crash" list (see Spoofing.rics).
---@note: getconnections() itself is fine (OptimizeGame uses it); it's the firing that crashes. Every
---@note: getconnections connection exposes .Function (its bound handler) even on macsploit, so calling that
---@note: directly is the safe, cross-executor equivalent of a click.

---@param button Instance A TextButton/ImageButton (anything with MouseButton1Click).
---@return boolean clicked  false if getconnections is unavailable or the button had no handlers.
local function safeClick(button)
	if not button or type(getconnections) ~= "function" then
		return false
	end

	local ok, connections = pcall(getconnections, button.MouseButton1Click)
	if not ok or type(connections) ~= "table" then
		return false
	end

	local fired = false
	for _, connection in ipairs(connections) do
		pcall(function()
			local handler = connection.Function
			if handler then
				handler()
				fired = true
			end
		end)
	end

	return fired
end

return safeClick
