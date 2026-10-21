local InteligenceFarm = {}

---@module Utility.Maid
local Maid = require("Utility/Maid")

---@module Utility.Signal
local Signal = require("Utility/Signal")

---@module Utility.Attributes
local Attributes = require("Utility/Attributes")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.Throttle
local throttle = require("Utility/Throttle")

local players = game:GetService("Players")
local runService = game:GetService("RunService")

local renderStepped = Signal.new(runService.RenderStepped)

local autoIntelligenceMaid = Maid.new()

local updateInteligence = LPH_NO_VIRTUALIZE(function()
	local inteligenceFarm = Toggles["AutoIntelligence"]
	if not inteligenceFarm or not inteligenceFarm.Value then
		return
	end

	local inteligenceFarmCap = Options["IntelligenceCap"]
	if not inteligenceFarmCap then
		return
	end

	local localPlayer = players.LocalPlayer
	local localPlayerCharacter = localPlayer.Character
	if not localPlayerCharacter then
		return
	end

	if not Attributes.isNotAtCap(localPlayerCharacter, "Stat_Intelligence", inteligenceFarmCap.Value - 1) then
		Logger.longNotify("Intelligence AutoFarm is automatically stopping.")
		return inteligenceFarm:SetValue(false)
	end

	local humanoid = localPlayerCharacter:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local backpack = localPlayer:FindFirstChild("Backpack")
	if not backpack then
		return
	end

	local characterBook = localPlayerCharacter:FindFirstChild("Math Textbook")
	local backpackBook = backpack:FindFirstChild("Math Textbook")

	if not characterBook and backpackBook then
		return humanoid:EquipTool(backpackBook)
	end

	local choicePrompt = localPlayer.PlayerGui:FindFirstChild("ChoicePrompt")
	if not choicePrompt then
		return characterBook and characterBook:Activate()
	end

	local choiceRemote = choicePrompt:FindFirstChild("Choice")
	if not choiceRemote then
		return
	end

	local choiceFrame = choicePrompt:FindFirstChild("ChoiceFrame")
	if not choiceFrame then
		return
	end

	local descSheet = choiceFrame:FindFirstChild("DescSheet")
	local description = descSheet and descSheet:FindFirstChild("Desc")
	if not description then
		return
	end

	local options = choiceFrame:FindFirstChild("Options")
	if not options then
		return
	end

	local answers = {}

	for _, instance in next, options:GetChildren() do
		if not instance:IsA("TextButton") then
			continue
		end

		local number = tonumber(instance.Name)
		if not number then
			continue
		end

		table.insert(answers, number)
	end

	local descriptionText = tostring(description.Text)
	local parsedDescription = descriptionText:gsub("What is", ""):gsub(" ", ""):gsub("?", ""):gsub("by", "")

	local operation = nil

	if parsedDescription:match("divided") then
		operation = "divided"
	end

	if parsedDescription:match("times") then
		operation = "times"
	end

	if parsedDescription:match("plus") then
		operation = "plus"
	end

	if parsedDescription:match("minus") then
		operation = "minus"
	end

	if not operation then
		return
	end

	local parsedNumbers = parsedDescription:split(operation)
	local firstNumber = tonumber(parsedNumbers[1] or "")
	local secondNumber = tonumber(parsedNumbers[2] or "")
	if not firstNumber or not secondNumber then
		return
	end

	local answer = nil

	if operation == "divided" then
		answer = firstNumber / secondNumber
	end

	if operation == "times" then
		answer = firstNumber * secondNumber
	end

	if operation == "plus" then
		answer = firstNumber + secondNumber
	end

	if operation == "minus" then
		answer = firstNumber - secondNumber
	end

	local closestAnswer = nil
	local closestDifference = nil

	for _, possible in next, answers do
		local delta = math.abs(answer - possible)

		if closestDifference and delta > closestDifference then
			continue
		end

		closestAnswer = possible
		closestDifference = delta
	end

	if not closestAnswer then
		return
	end

	choiceRemote:FireServer(tostring(closestAnswer))
end)

function InteligenceFarm.init()
	autoIntelligenceMaid:add(renderStepped:connect("AttributeFarmIntelligence_OnPreRender", throttle(1 / 10, updateInteligence)))

	if not LPH_OBFUSCATED or shared.Aero.verbose then
		Logger.warn("Inteligence Farm initialized.")
	end
end

function InteligenceFarm.detach()
	autoIntelligenceMaid:clean()

	Logger.warn("Inteligence Farm detached.")
end

return InteligenceFarm
