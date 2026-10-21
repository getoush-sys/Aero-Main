local Interactions = {}

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Prompt
local Prompt = require("Utility/Prompt")

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local DEBUGGING_MODE = true

local function telemetryLog(...)
	if not DEBUGGING_MODE then
		return
	end

	Logger.warn(...)
end

---@param tool Instance
---@param data any Response to interaction to send with the tool use.
function Interactions.utool(tool, data)
	Interactions.etool(tool)

	telemetryLog("Activating tool '%s' until ChoicePrompt appears.", tool.Name)

	local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")
	local choicePrompt = nil

	while not choicePrompt do
		tool:Activate()

		choicePrompt = playerGui:FindFirstChild("ChoicePrompt")

		task.wait()
	end

	telemetryLog("Firing ChoicePrompt ('%s') with data.", tostring(data))

	local choice = choicePrompt:WaitForChild("Choice")
	choice:FireServer(data)

	telemetryLog("Waiting for ChoicePrompt to disappear...")

	repeat
		task.wait()
	until not choicePrompt.Parent

	telemetryLog("ChoicePrompt has disappeared.")
end

---@param tool Instance
function Interactions.etool(tool)
	local character = players.LocalPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	repeat
		humanoid:EquipTool(tool)

		task.wait()
	until tool.Parent == players.LocalPlayer.Character
end

---@param instance Model
---@param actions table
---@param teleport boolean Should we teleport to the instance?
function Interactions.interact(instance, actions, teleport)
	if not instance or not instance.Parent then
		return
	end

	local interactPrompt = instance:FindFirstChild("InteractPrompt")
	if not interactPrompt or not interactPrompt:IsA("ProximityPrompt") then
		return
	end

	telemetryLog("(%s) Interacting until dialogue appears.", instance.Name)

	local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")
	local dialogueGui = playerGui:WaitForChild("DialogueGui")
	local character = players.LocalPlayer.Character or players.LocalPlayer.CharacterAdded:Wait()

	repeat
		if teleport then
			character:PivotTo(instance:GetPivot())
		end

		Prompt.fire(interactPrompt)

		task.wait()
	until dialogueGui.Enabled

	telemetryLog("(%s) Going through dialogue with %i actions.", instance.Name, #actions)

	local requests = replicatedStorage:WaitForChild("Requests")
	local dialogueEvent = requests:WaitForChild("SendDialogue")

	local dialogueCompleted = false

	dialogueEvent.OnClientEvent:Connect(function()
		dialogueCompleted = true
	end)

	for _, action in next, actions do
		dialogueEvent:FireServer(action)

		dialogueCompleted = false

		telemetryLog(
			"(%s) Sent dialogue action '%s' and now waiting for OnClientEvent to fire.",
			instance.Name,
			action.exit and "[EXIT]" or (action.choice or "N/A")
		)

		if action.exit then
			break
		end

		repeat
			task.wait()
		until dialogueCompleted
	end

	telemetryLog("(%s) Completed dialogue.", instance.Name)
end

return Interactions
