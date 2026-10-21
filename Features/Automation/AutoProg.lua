-- Auto Prog: PR's auto progression, Aero-native. Ties the Auto Builder (invest attribute points +
-- pick talent/mantra cards toward the pre/post spread) together with a farm (Auto Ferryman or Auto
-- Saramed) that earns the points, with a small state machine:
--
--   DOING_PRESHRINE  -- farm + build the pre spread; when the pre attributes are met, KICK to shrine.
--   DOING_POSTSHRINE -- farm + build the post spread; when the final attributes are met, KICK (done).
--
-- No persistence: after the kick, rejoin, re-execute Aero, and press "Start Postshrine" (or "Start
-- Preshrine") to continue. The in-progress build + farm resume across the farm's own server hops via
-- their own MemStorage state.
--
-- Omits PR's Trial of One / Brutus fortitude / depths escape / rejoin-slot machinery (PR-only infra).

---@module Features.Automation.AutoBuilder
local AutoBuilder = require("Features/Automation/AutoBuilder")

---@module Features.Automation.AutoFerryman
local AutoFerryman = require("Features/Automation/AutoFerryman")

---@module Features.Automation.AutoSaramed
local AutoSaramed = require("Features/Automation/AutoSaramed")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Signal
local Signal = require("Utility/Signal")

local players = game:GetService("Players")
local runService = game:GetService("RunService")

local AutoProg = {}

local CHECK_INTERVAL = 1.0

-- In-memory only: "NULL" | "DOING_PRESHRINE" | "DOING_POSTSHRINE".
local state = "NULL"

local progMaid = Maid.new()
local lastCheck = 0

local function farmMethod()
	return Configuration.expectOptionValue("AutoProgFarmMethod") or "Ferryman"
end

local function startFarm()
	-- Each farm self-guards on location (teleports/hops if we're not there) and is idempotent.
	if farmMethod() == "Saramed" then
		AutoSaramed.start()
	else
		AutoFerryman.start()
	end
end

local function stopFarms()
	pcall(AutoFerryman.stop)
	pcall(AutoSaramed.stop)
end

---Aim the builder at a spread, start building (invest + pick), and run the farm.
---@param phase "pre"|"post"
local function runPhase(phase)
	AutoBuilder.setTarget(phase)
	AutoBuilder.startPicking()
	startFarm()
end

---Stop everything and kick with a message.
---@param message string
local function endRun(message)
	state = "NULL"
	AutoBuilder.stopPicking()
	stopFarms()

	pcall(function()
		players.LocalPlayer:Kick(message)
	end)
end

---Start a phase from the UI.
---@param phase "pre"|"post"
---@return boolean
function AutoProg.start(phase)
	if phase ~= "pre" and phase ~= "post" then
		return false
	end

	if not AutoBuilder.current then
		Logger.notify("Auto Prog: load a build first.")
		return false
	end

	state = phase == "post" and "DOING_POSTSHRINE" or "DOING_PRESHRINE"
	runPhase(phase)

	Logger.notify(
		string.format(
			"Auto Prog: %s started (farming %s).",
			phase == "post" and "postshrine" or "preshrine",
			farmMethod()
		)
	)

	return true
end

---@return boolean
function AutoProg.startPreshrine()
	return AutoProg.start("pre")
end

---@return boolean
function AutoProg.startPostshrine()
	return AutoProg.start("post")
end

function AutoProg.stop()
	state = "NULL"
	AutoBuilder.stopPicking()
	stopFarms()
	Logger.notify("Auto Prog: stopped.")
end

---@return boolean
function AutoProg.isRunning()
	return state == "DOING_PRESHRINE" or state == "DOING_POSTSHRINE"
end

-- The state-machine watcher: kicks to shrine when preshrine is done, and kicks when the build is
-- finished. Armed once at init.
function AutoProg.init()
	local renderStepped = Signal.new(runService.RenderStepped)

	progMaid:add(renderStepped:connect("AutoProg_Watch", function()
		if os.clock() - lastCheck < CHECK_INTERVAL then
			return
		end
		lastCheck = os.clock()

		if state == "DOING_PRESHRINE" then
			if AutoBuilder.shrineReady() then
				endRun(
					'Auto Prog: preshrine done. shrine, then rejoin and press "Start Postshrine".'
				)
			end
		elseif state == "DOING_POSTSHRINE" then
			if AutoBuilder.finished() then
				endRun("Auto Prog: build finished. :)")
			end
		end
	end))

	if not LPH_OBFUSCATED or (shared.Aero and shared.Aero.verbose) then
		Logger.warn("Auto Prog initialized.")
	end
end

function AutoProg.detach()
	progMaid:clean()
end

return AutoProg
