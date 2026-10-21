return LPH_NO_VIRTUALIZE(function()
	local OptimizeGame = {}

	---@module Utility.Signal
	local Signal = require("Utility/Signal")

	---@module Utility.Logger
	local Logger = require("Utility/Logger")

	---@module Utility.Configuration
	local Configuration = require("Utility/Configuration")

	---@module Utility.Maid
	local Maid = require("Utility/Maid")

	local optimizeGameMaid = Maid.new()

	local getinfo = getinfo or debug.getinfo
	local getconstants = getconstants or debug.getconstants

	local alive = false
	local seaHookedFn = nil
	local seaOldFn = nil
	local replicationRestores = {}

	-- Only fire a retry while the module is still attached, so retry loops can't keep running (and re-driving
	-- render connections) after a detach/re-exec.
	local function retry(callback)
		task.delay(1, function()
			if alive then
				callback()
			end
		end)
	end

	local LOW_TEXTURE = "rbxassetid://130143779"

	local initialized = false
	local ranVisuals = false

	---@param obj Instance
	local function downgradeObject(obj)
		if obj:IsA("BasePart") then
			obj.Material = Enum.Material.Plastic
			obj.Reflectance = 0
			obj.CastShadow = false
		end

		if obj:IsA("Texture") or obj:IsA("Decal") then
			obj.Texture = LOW_TEXTURE
		elseif obj:IsA("SurfaceAppearance") then
			obj.ColorMap = LOW_TEXTURE
			obj.MetalnessMap = ""
			obj.RoughnessMap = ""
			obj.NormalMap = ""
		end

		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
			obj.Rate = 0
			obj.Speed = NumberRange.new(0)
		end

		if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
			obj.Enabled = false
			obj.Brightness = 0
			obj.Range = 2
		end
	end

	function OptimizeGame.runAggressive()
		if ranVisuals then
			return
		end
		ranVisuals = true
		task.spawn(function()
			local count = 0
			for _, obj in next, game:GetDescendants() do
				pcall(downgradeObject, obj)
				count = count + 1
				if count % 1000 == 0 then
					task.wait()
				end
			end
			Logger.notify("Aggressively optimized %d objects.", count)
		end)
	end

	local function setupSeaClient()
		local sea_client_func

		local function scan(objects)
			for _, object in next, objects do
				if typeof(object) ~= "function" or not getinfo(object).source:find("SeaClient") then
					continue
				end
				if not table.find(getconstants(object), "getWaveAt") then
					continue
				end

				sea_client_func = object
				break
			end
		end
		
		if filtergc then
			pcall(function()
				scan(filtergc("function", {
					IgnoreExecutor = false,
					Constants = { "getWaveAt" },
				}))
			end)
		end

		if not sea_client_func then
			scan(getgc(false))
		end

		if not sea_client_func then
			return Logger.warn("Failed to get SeaClient function.")
		end

		-- When throttled, hand back the LAST real result instead of nil. The old hook returned nothing
		-- on a skipped frame, so anything sampling the sea (floating objects, the local player while
		-- swimming) got nil and jittered -- that was the "lag". Returning the previous value is never
		-- worse than nil. os.clock + an inline Toggles read (no expectToggleValue call) keep the
		-- per-invocation cost near zero on this very hot function.
		local SEA_INTERVAL = 1 / 20
		local last_allowed_call = 0
		local cached = { n = 0 }
		local cachedArgs = { n = 0 }

		---@note: The cached result is only valid for the exact arguments it was computed with.
		local function sameArgs(...)
			local count = select("#", ...)
			if cachedArgs.n ~= count then
				return false
			end

			for index = 1, count do
				if cachedArgs[index] ~= (select(index, ...)) then
					return false
				end
			end

			return true
		end

		local old
		old = hookfunction(sea_client_func, function(...)
			local optimizeToggle = Toggles and Toggles.OptimizeGame
			if
				optimizeToggle
				and optimizeToggle.Value
				and os.clock() - last_allowed_call < SEA_INTERVAL
				and sameArgs(...)
			then
				return table.unpack(cached, 1, cached.n)
			end

			last_allowed_call = os.clock()
			cachedArgs = table.pack(...)
			cached = table.pack(old(...))
			return table.unpack(cached, 1, cached.n)
		end)

		seaHookedFn = sea_client_func
		seaOldFn = old
	end

	-- LowGraphics attribute state.
	local forcingLowGraphics = false
	local originalLowGraphics = nil

	---Force the LowGraphics player attribute while optimizing. WorldClient skips ambient VFX
	---(wind trails, glitches, bubbles, meteors, sail bones, despawn tweens) when it's set.
	---@param enabled boolean
	local function updateLowGraphics(enabled)
		local localPlayer = game:GetService("Players").LocalPlayer
		if not localPlayer then
			return
		end

		if enabled then
			if not forcingLowGraphics then
				originalLowGraphics = localPlayer:GetAttribute("LowGraphics")
				forcingLowGraphics = true
			end

			if localPlayer:GetAttribute("LowGraphics") ~= true then
				localPlayer:SetAttribute("LowGraphics", true)
			end
		elseif forcingLowGraphics then
			forcingLowGraphics = false
			localPlayer:SetAttribute("LowGraphics", originalLowGraphics)
		end
	end

	local function setupWorldClient()
		local last_world_client_func
		local function apply()
			task.wait(1)

			local hi = "WorldClient"
			local cns = getconnections(game:GetService("RunService").PreRender)

			local conn
			for _, object in next, cns do
				local func = object.Function
				if not func or not getinfo(func).source:find(hi) then
					continue
				end

				if last_world_client_func == func then
					return task.delay(1, apply)
				end

				last_world_client_func = func

				-- Crash fix (macOS/macsploit): getconnections() objects on macsploit expose only
				-- .Function and :Disconnect() - the Synapse-style :Disable() method is absent, so the
				-- original object:Disable() raised "attempt to call a nil value (method 'Disable')".
				-- On a worker-thread VM that error unwinds through the executor's native trampoline into
				-- the same NULL+0x28 SIGSEGV documented for conn:Fire(). Neutralize the connection through
				-- whatever the executor actually supports and record whether it stuck: if we cannot silence
				-- the game's own render connection we must NOT install the manual re-fire below, or every
				-- frame renders twice.
				local disabled = false
				if type(object.Disable) == "function" then
					disabled = pcall(function()
						object:Disable()
					end)
				end
				if not disabled then
					-- macsploit path: no :Disable(); try the writable .Enabled flag it exposes on
					-- getconnections objects, and confirm the write actually took.
					disabled = pcall(function()
						object.Enabled = false
					end) and object.Enabled == false
				end
				if not disabled and type(object.Disconnect) == "function" then
					-- Last resort: drop the native listener entirely. We re-fire .Function ourselves
					-- below, so a hard disconnect still yields exactly one render per throttled frame.
					disabled = pcall(function()
						object:Disconnect()
					end)
				end
				if not disabled then
					-- Could not neutralize the render connection on this executor; skip the manual
					-- optimization for this UI rather than double-firing WorldClient. Retry later in
					-- case the connection set changes.
					last_world_client_func = nil
					return task.delay(1, apply)
				end

				conn = object
			end

			if not conn then
				return
			end

			-- Crash fix (macOS/macsploit): conn:Fire() on a getconnections() object dereferences the
			-- executor's cached connection_data inside its Fire path with no liveness check - a
			-- freed/stale pointer after reconnections or respawns produces the NULL+0x28 read we
			-- SIGSEGV'd on. conn.Function is null-safe by comparison, so invoke the listener directly
			-- and wrap in pcall - a defunct connection degrades to a skipped frame, not a dead process.
			local function fireConnection(delta)
				return pcall(function()
					conn.Function(delta)
				end)
			end

			---@note: Re-enable the original connection on cleanup, otherwise WorldClient stays dead after detach.
			optimizeGameMaid["WorldClientRestore"] = function()
				pcall(function()
					if type(conn.Enable) == "function" then
						conn:Enable()
					else
						conn.Enabled = true
					end
				end)
			end

			local last_update = tick()
			optimizeGameMaid["WorldClientRender"] = game:GetService("RunService").PreRender:Connect(function()
				local now = tick()
				local enabled = Configuration.expectToggleValue("OptimizeGame")

				updateLowGraphics(enabled)

				if enabled and now - last_update < 1 / 15 then
					return
				end

				---@note: WorldClient feeds this into SmoothDamp - it must be the real elapsed time.
				local dt = now - last_update
				last_update = now

				return fireConnection(dt)
			end)
		end

		apply()

		local players = game:GetService("Players")
		local localPlayer = players.LocalPlayer
		if localPlayer then
			optimizeGameMaid:add(localPlayer.PlayerGui.ChildAdded:Connect(function(object)
				if not Configuration.expectToggleValue("OptimizeGame") then
					return
				end
				if object.Name ~= "WorldClient" then
					return
				end

				apply()
			end))
		end
	end

	-- PR's opti_clouds: the game drives cloud/entity replication rendering from a RenderStepped
	-- connection inside PlayerScripts.Replication. We neutralize the game's own connection and
	-- re-drive its function at 10Hz, so replication rendering costs a fraction of the frames without
	-- disappearing. Mirrors setupWorldClient's crash-safe handling for macsploit.
	local function setupReplication()
		local last_replication_func

		local function apply()
			local rep_func

			for _, object in next, getconnections(game:GetService("RunService").RenderStepped) do
				local func = object.Function
				if not func or not getinfo(func).source:find("PlayerScripts.Replication") then
					continue
				end

				if last_replication_func == func then
					return retry(apply)
				end

				last_replication_func = func

				-- Same macsploit-safe neutralization as setupWorldClient: the getconnections object may
				-- lack :Disable(); fall back to the writable .Enabled flag, then a hard :Disconnect(). Each
				-- path records a `restore` closure so detach can hand the game's own render connection back
				-- instead of leaving it neutralized across a re-exec.
				local restore = nil
				if type(object.Disable) == "function" and pcall(object.Disable, object) then
					restore = function()
						if type(object.Enable) == "function" then
							object:Enable()
						else
							object.Enabled = true
						end
					end
				end
				if not restore and pcall(function()
					object.Enabled = false
				end) and object.Enabled == false then
					restore = function()
						object.Enabled = true
					end
				end
				if not restore and type(object.Disconnect) == "function" and pcall(object.Disconnect, object) then
					restore = function()
						game:GetService("RunService").RenderStepped:Connect(func)
					end
				end
				if not restore then
					last_replication_func = nil
					return retry(apply)
				end

				replicationRestores[#replicationRestores + 1] = restore
				rep_func = func
				break
			end

			if not rep_func then
				-- Replication connection not present yet (early join); retry.
				return retry(apply)
			end

			-- Re-drive at 10Hz. Invoke rep_func directly (null-safe) rather than conn:Fire() to avoid
			-- the macsploit SIGSEGV, wrapped in pcall so a defunct connection degrades to a skipped frame.
			local last_update = tick()
			optimizeGameMaid["ReplicationRender"] = game:GetService("RunService").RenderStepped:Connect(function()
				local delta = tick() - last_update

				if not Configuration.expectToggleValue("OptimizeGame") then
					last_update = tick()
					return pcall(rep_func, delta)
				end

				if delta < 1 / 10 then
					return
				end
				last_update = tick()

				return pcall(rep_func, delta)
			end)
		end

		apply()
	end

	function OptimizeGame.init()
		if initialized then
			return
		end
		initialized = true
		alive = true

		-- Gate the render-connection manipulation on the toggle. setupSeaClient / setupReplication use
		-- getconnections to neutralize the game's OWN render connections and re-drive the game's render
		-- functions each frame for higher FPS; only run them when OptimizeGame is enabled.
		--
		-- setupWorldClient is DELIBERATELY NOT CALLED. It re-drove Deepwoken's WorldClient PreRender function
		-- from our own main-VM PreRender connection; WorldClient runs in the game's parallel Actor render
		-- phase, so calling its function from our serial connection ran parallel-context Lua in the wrong
		-- phase -- the illegal cross-phase op the engine Kernel-panics on, on the RENDER thread
		-- (RBXCRASH: FatalRuntimeError (RSL - panic: ...Kernel)), randomly ~40 min in, independent of every
		-- other toggle. This is EXACTLY what Project Rain does: PR's optimize_game defines opti_world_client
		-- but its enable() only ever spawns opti_sea + opti_clouds and never opti_world_client -- the same one
		-- it abandoned. setupWorldClient stays defined below (like PR's dead opti_world_client) but unused.
		if Configuration.expectToggleValue("OptimizeGame") then
			task.spawn(setupSeaClient)
			task.spawn(setupReplication)
		end

		local descendantAddedSignal = Signal.new(game.DescendantAdded)
		optimizeGameMaid:add(descendantAddedSignal:connect("OptimizeGame_DescendantAdded", function(obj)
			if ranVisuals then
				task.defer(pcall, downgradeObject, obj)
			end
		end))

		if not LPH_OBFUSCATED or shared.Aero.verbose then
			Logger.warn("OptimizeGame initialized.")
		end
	end

	function OptimizeGame.detach()
		alive = false
		optimizeGameMaid:clean()

		for _, restore in ipairs(replicationRestores) do
			pcall(restore)
		end
		table.clear(replicationRestores)

		if seaHookedFn and seaOldFn then
			pcall(hookfunction, seaHookedFn, seaOldFn)
		end
		seaHookedFn = nil
		seaOldFn = nil

		updateLowGraphics(false)
		initialized = false
		ranVisuals = false
		Logger.warn("OptimizeGame detached.")
	end

	return OptimizeGame
end)()
