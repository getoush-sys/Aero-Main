---@class Freecam
--- Project Rain's freecam, adapted for Aero. Detaches the camera from the character:
---   WASD  - move (relative to look)      Q / E        - down / up
---   mouse - look                         Up / Down    - adjust speed live
---   LeftShift - move slowly
--- The character stays put. Speed is scaled by the FreecamSpeed slider via set_speed().
local Freecam = {}

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCamera = workspace.CurrentCamera
	if newCamera then
		Camera = newCamera
	end
end)

local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value

local running = false
local cameraPos = Vector3.new()
local cameraRot = Vector2.new()

local NAV_KEYBOARD_SPEED = Vector3.new(1, 1, 1)
local PAN_MOUSE_SPEED = Vector2.new(1, 1) * (math.pi / 64)
local NAV_ADJ_SPEED = 0.75
local NAV_SHIFT_MUL = 0.25

local navSpeed = 2

local keyboard = { W = 0, A = 0, S = 0, D = 0, E = 0, Q = 0, Up = 0, Down = 0 }
local mouse = { Delta = Vector2.new() }

local function inputVel(dt)
	navSpeed = math.clamp(navSpeed + dt * (keyboard.Up - keyboard.Down) * NAV_ADJ_SPEED, 0.01, 4)

	local kKeyboard = Vector3.new(
		keyboard.D - keyboard.A,
		keyboard.E - keyboard.Q,
		keyboard.S - keyboard.W
	) * NAV_KEYBOARD_SPEED

	local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)

	return kKeyboard * (navSpeed * (shift and NAV_SHIFT_MUL or 1))
end

local function inputPan()
	local kMouse = mouse.Delta * PAN_MOUSE_SPEED
	mouse.Delta = Vector2.new()
	return kMouse
end

local function keypress(_, state, input)
	keyboard[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
	return Enum.ContextActionResult.Sink
end

local function mousePan(_, _, input)
	local delta = input.Delta
	mouse.Delta = Vector2.new(-delta.Y, -delta.X)
	return Enum.ContextActionResult.Sink
end

local function zero(t)
	for k in next, t do
		t[k] = 0
	end
end

local function startCapture()
	ContextActionService:BindActionAtPriority(
		"FreecamKeyboard",
		keypress,
		false,
		INPUT_PRIORITY,
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.E,
		Enum.KeyCode.Q,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down
	)
	ContextActionService:BindActionAtPriority(
		"FreecamMousePan",
		mousePan,
		false,
		INPUT_PRIORITY,
		Enum.UserInputType.MouseMovement
	)
end

local function stopCapture()
	navSpeed = 1
	zero(keyboard)
	mouse.Delta = Vector2.new()
	ContextActionService:UnbindAction("FreecamKeyboard")
	ContextActionService:UnbindAction("FreecamMousePan")
end

local function getFocusDistance(cameraFrame)
	local znear = 0.1
	local viewport = Camera.ViewportSize
	local projy = 2 * math.tan(70 / 2)
	local projx = viewport.X / viewport.Y * projy
	local fx = cameraFrame.RightVector
	local fy = cameraFrame.UpVector
	local fz = cameraFrame.LookVector

	local minVect = Vector3.new()
	local minDist = 512

	for x = 0, 1, 0.5 do
		for y = 0, 1, 0.5 do
			local cx = (x - 0.5) * projx
			local cy = (y - 0.5) * projy
			local offset = fx * cx - fy * cy + fz
			local origin = cameraFrame.Position + offset * znear

			local result = workspace:Raycast(origin, offset.Unit * minDist)
			local hitPos = result and result.Position or (origin + offset.Unit * minDist)
			local dist = (hitPos - origin).Magnitude
			if minDist > dist then
				minDist = dist
				minVect = offset.Unit
			end
		end
	end

	return fz:Dot(minVect) * minDist
end

local function stepFreecam(dt)
	local vel = inputVel(dt)
	local pan = inputPan()

	cameraRot = cameraRot + pan * Vector2.new(0.75, 1) * 8 * dt
	cameraRot = Vector2.new(math.clamp(cameraRot.X, -math.rad(90), math.rad(90)), cameraRot.Y % (2 * math.pi))

	local cameraCFrame = CFrame.new(cameraPos)
		* CFrame.fromOrientation(cameraRot.X, cameraRot.Y, 0)
		* CFrame.new(vel * 64 * dt)
	cameraPos = cameraCFrame.Position

	Camera.CFrame = cameraCFrame
	Camera.Focus = cameraCFrame * CFrame.new(0, 0, -getFocusDistance(cameraCFrame))
end

-- Saved player camera + mouse state (restored on exit).
local savedCameraType, savedCFrame, savedFocus, savedMouseIcon, savedMouseBehavior

local function push()
	savedCameraType = Camera.CameraType
	Camera.CameraType = Enum.CameraType.Custom

	savedCFrame = Camera.CFrame
	savedFocus = Camera.Focus

	savedMouseIcon = UserInputService.MouseIconEnabled
	UserInputService.MouseIconEnabled = true

	savedMouseBehavior = UserInputService.MouseBehavior
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function pop()
	Camera.CameraType = savedCameraType or Enum.CameraType.Custom
	Camera.CFrame = savedCFrame or Camera.CFrame
	Camera.Focus = savedFocus or Camera.Focus
	UserInputService.MouseIconEnabled = savedMouseIcon
	if savedMouseBehavior then
		UserInputService.MouseBehavior = savedMouseBehavior
	end

	savedCameraType, savedCFrame, savedFocus, savedMouseIcon, savedMouseBehavior = nil, nil, nil, nil, nil
end

---@param pos CFrame? Optional starting camera CFrame.
function Freecam.enter(pos)
	if running then
		Freecam.exit()
	end

	local cameraCFrame = pos or Camera.CFrame
	cameraRot = Vector2.new()
	cameraPos = cameraCFrame.Position

	push()
	RunService:BindToRenderStep("Freecam", Enum.RenderPriority.Camera.Value, stepFreecam)
	startCapture()
	running = true
end

function Freecam.exit()
	if not running then
		return
	end

	stopCapture()
	RunService:UnbindFromRenderStep("Freecam")
	pop()
	running = false
end

---@param speed number Multiplier on the base nav speed (1 = default feel).
function Freecam.set_speed(speed)
	NAV_KEYBOARD_SPEED = Vector3.new(speed, speed, speed)
end

---@return boolean
function Freecam.running()
	return running
end

return Freecam
