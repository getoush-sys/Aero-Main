local CharismaFarm = {}

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

local autoCharismaMaid = Maid.new()

local updateCharisma = LPH_NO_VIRTUALIZE(function()
	local charismaFarm = Toggles["AutoCharisma"]
	if not charismaFarm or not charismaFarm.Value then
		return
	end

	local charismaFarmCap = Options["CharismaCap"]
	if not charismaFarmCap then
		return
	end

	local localPlayer = players.LocalPlayer
	local localPlayerCharacter = localPlayer.Character
	if not localPlayerCharacter then
		return
	end

	if not Attributes.isNotAtCap(localPlayerCharacter, "Stat_Charisma", charismaFarmCap.Value - 1) then
		Logger.longNotify("Charisma AutoFarm is automatically stopping.")
		return charismaFarm:SetValue(false)
	end

	local humanoid = localPlayerCharacter:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local backpack = localPlayer:FindFirstChild("Backpack")
	if not backpack then
		return
	end

	local characterBook = localPlayerCharacter:FindFirstChild("How to Make Friends")
	local backpackBook = backpack:FindFirstChild("How to Make Friends")

	if not characterBook and backpackBook then
		return humanoid:EquipTool(backpackBook)
	end

	local choicePrompt = localPlayer.PlayerGui:FindFirstChild("ChoicePrompt")
	if not choicePrompt then
		return characterBook and characterBook:Activate()
	end

	local choiceFrame = choicePrompt:FindFirstChild("ChoiceFrame")
	if not choiceFrame then
		return
	end

	local chatChoice = choicePrompt:FindFirstChild("ChatChoice")
	if not chatChoice then
		return
	end

	local description = choiceFrame:FindFirstChild("Desc")
	if not description then
		return
	end

	local text = description.Text:split("\n")
	local charismaLine = text[2]:sub(2, -2)

	chatChoice:InvokeServer(charismaLine)
end)

function CharismaFarm.init()
	autoCharismaMaid:add(renderStepped:connect("AttributeFarmCharisma_OnPreRender", throttle(1 / 10, updateCharisma)))

	if not LPH_OBFUSCATED or shared.Aero.verbose then
		Logger.warn("Charisma Farm initialized.")
	end
end

function CharismaFarm.detach()
	autoCharismaMaid:clean()

	Logger.warn("Charisma Farm detached.")
end

return CharismaFarm
