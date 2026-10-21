return LPH_NO_VIRTUALIZE(function()
---@note: You should never leave the service access running here. Use a direct reference because we would want to know if they add any detections targeting this feature.
local AntiAFK = { wanters = {} }

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.Maid
local Maid = require("Utility/Maid")

local players = game:GetService("Players")

local afkMaid = Maid.new()

function AntiAFK.start(identifier)
	AntiAFK.wanters[identifier] = true
end

function AntiAFK.stop(identifier)
	AntiAFK.wanters[identifier] = nil
end

function AntiAFK.init()
	local idledSignal = Signal.new(players.LocalPlayer.Idled)

	idledSignal:connect("AntiAFK_OnIdled", function()
		if not AntiAFK.wanters or #AntiAFK.wanters == 0 then
			return
		end

		local virtualUser = game:GetService("VirtualUser")
		virtualUser:CaptureController()
		virtualUser:ClickButton2(Vector2.new())
	end)
end

function AntiAFK.detach()
	afkMaid:clean()
end

return AntiAFK
end)()
