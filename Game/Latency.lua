local Latency = {}

local stats = game:GetService("Stats")

---@note: Perhaps one day, we can get better approximations for these.

local smoothedRtt = nil
local EMA_ALPHA = 0.25

local OUTLIER_JUMP_MULTIPLIER = 2.0
local OUTLIER_JUMP_FLOOR = 0.05

---@note: https://devforum.roblox.com/t/in-depth-information-about-robloxs-remoteevents-instance-replication-and-physics-replication-w-sources/1847340
---@note: The forum post above is misleading, not only is it the RTT time, please note that this also takes into account all delays like frame time.
---@return number?
local function rawRtt()
	local network = stats:FindFirstChild("Network")
	if not network then
		return
	end

	local serverStatsItem = network:FindFirstChild("ServerStatsItem")
	if not serverStatsItem then
		return
	end

	local dataPingItem = serverStatsItem:FindFirstChild("Data Ping")
	if not dataPingItem then
		return
	end

	return dataPingItem:GetValue() / 1000
end

---@return number
function Latency.rdelay()
	return math.max(Latency.rtt() / 2, 0.0)
end

---@return number
function Latency.sdelay()
	return math.max(Latency.rtt() / 2, 0.0)
end

---@note: This is our round-trip time (e.g double the ping) since we have a receiving delay (replication) and a sending delay when we send the input to the server.
---@todo: For every usage, the sending delay needs to be continously updated. The receiving one must be calculated once at initial send for AP ping compensation.
---@return number?
function Latency.rtt()
	local raw = rawRtt()
	if not raw then
		return smoothedRtt
	end

	if not smoothedRtt then
		smoothedRtt = raw
		return smoothedRtt
	end

	local deviation = raw - smoothedRtt
	local maxJump = math.max(smoothedRtt * OUTLIER_JUMP_MULTIPLIER, OUTLIER_JUMP_FLOOR)

	if math.abs(deviation) > maxJump then
		deviation = maxJump * (deviation < 0 and -1 or 1)
	end

	smoothedRtt = smoothedRtt + EMA_ALPHA * deviation

	return smoothedRtt
end

return Latency