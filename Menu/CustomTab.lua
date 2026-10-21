---@module GUI.Icons
local Icons = require("GUI/Icons")

---@module GUI.Library
local Library = require("GUI/Library")

---@module GUI.SaveManager
local SaveManager = require("GUI/SaveManager")

---@module Menu.Objects.CodeEditor
local CodeEditor = require("Menu/Objects/CodeEditor")

---@module Menu.Objects.FloatingWindow
local FloatingWindow = require("Menu/Objects/FloatingWindow")

---@module Features.Custom.Custom
local Custom = require("Features/Custom/Custom")

---@module Features.Custom.AIChat
local AIChat = require("Features/Custom/AIChat")

local CustomTab = {}

local editor -- the code editor control { get, set, setEditable }
local editorWindow
local chatWindow
local statusLabel

local function setStatus(fmt, ...)
	local text = select("#", ...) > 0 and string.format(fmt, ...) or fmt
	pcall(function()
		statusLabel:SetText(text)
	end)
end

local function currentName()
	local name = Options.Custom_FeatureName and Options.Custom_FeatureName.Value or ""
	if type(name) ~= "string" or name:gsub("%s", "") == "" then
		return nil
	end
	return name
end

local function refreshList()
	if Options.Custom_FeatureList then
		Options.Custom_FeatureList:SetValues(Custom.list())
	end
end

-- ============================================================ Editor window (pure code editor)
local function buildEditorWindow()
	editorWindow = FloatingWindow.new({
		title = "Aero - Code Editor",
		size = UDim2.fromOffset(540, 560),
		position = UDim2.fromScale(0.35, 0.5),
	})
	editor = CodeEditor.create(editorWindow.body, 514, "-- write your feature here, or generate one from AI Chat", 205)
	editor.set(Custom.TEMPLATE)
end

-- ============================================================ Chat window (agentic AI)
local function buildChatWindow()
	chatWindow = FloatingWindow.new({
		title = "Aero - AI Chat",
		size = UDim2.fromOffset(430, 520),
		position = UDim2.fromScale(0.65, 0.5),
	})
	local body = chatWindow.body

	local transcript = Library:Create("ScrollingFrame", {
		BackgroundColor3 = Library.BackgroundColor,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 1, -64),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ZIndex = 202,
		Parent = body,
	})
	Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = transcript })
	Library:AddToRegistry(transcript, { BackgroundColor3 = "BackgroundColor" })
	Library:Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = transcript })
	Library:Create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = transcript,
	})

	local order = 0
	local function addMsg(role, text)
		order = order + 1
		local color = Library.FontColor
		local prefix = ""
		if role == "user" then
			color = Library.AccentColor
			prefix = "You: "
		elseif role == "assistant" then
			color = Library.FontColor
			prefix = "AI: "
		elseif role == "tool" then
			color = Library.OutlineColor
			prefix = "[tool] "
		elseif role == "toolresult" then
			color = Library.OutlineColor
			prefix = "[result] "
			if #text > 500 then
				text = text:sub(1, 500) .. " ... (" .. #text .. " chars)"
			end
		elseif role == "error" then
			color = Color3.fromRGB(255, 96, 96)
			prefix = "[error] "
		end

		local lbl = Library:Create("TextLabel", {
			BackgroundTransparency = 1,
			Font = (role == "tool" or role == "toolresult") and Enum.Font.Code or Enum.Font.Gotham,
			Text = prefix .. tostring(text),
			TextSize = (role == "tool" or role == "toolresult") and 11 or 12,
			TextColor3 = color,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			ZIndex = 203,
			Parent = transcript,
		})
		task.defer(function()
			transcript.CanvasPosition = Vector2.new(0, math.max(0, transcript.AbsoluteCanvasSize.Y))
		end)
		return lbl
	end

	addMsg("assistant", "Ask me to build a feature or explain the game. I can inspect the live game and decompile scripts. Set your provider/key in the Custom tab first.")

	local statusText = Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 2, 1, -62),
		Size = UDim2.new(1, -4, 0, 12),
		Font = Enum.Font.Gotham,
		Text = "",
		TextSize = 11,
		TextColor3 = Library.AccentColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 202,
		Parent = body,
	})
	Library:AddToRegistry(statusText, { TextColor3 = "AccentColor" })

	local inputHolder = Library:Create("Frame", {
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -46),
		Size = UDim2.new(1, -66, 0, 28),
		ZIndex = 202,
		Parent = body,
	})
	Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = inputHolder })
	local is = Library:Create("UIStroke", { Color = Library.OutlineColor, Thickness = 1, Transparency = 0.3, Parent = inputHolder })
	Library:AddToRegistry(inputHolder, { BackgroundColor3 = "MainColor" })
	Library:AddToRegistry(is, { Color = "OutlineColor" })

	local inputBox = Library:Create("TextBox", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -14, 1, 0),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Library.FontColor,
		PlaceholderText = "Describe a feature, or ask about the game...",
		PlaceholderColor3 = Library.OutlineColor,
		Text = "",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 203,
		Parent = inputHolder,
	})
	Library:AddToRegistry(inputBox, { TextColor3 = "FontColor" })

	local sendBtn = Library:Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, -46),
		Size = UDim2.fromOffset(60, 28),
		BackgroundColor3 = Library.AccentColor,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamSemibold,
		Text = "Send",
		TextSize = 12,
		TextColor3 = Library.MainColor,
		ZIndex = 203,
		Parent = body,
	})
	Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = sendBtn })
	Library:AddToRegistry(sendBtn, { BackgroundColor3 = "AccentColor", TextColor3 = "MainColor" })

	local clearBtn = Library:Create("TextButton", {
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(0.5, -2, 0, 16),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Enum.Font.Gotham,
		Text = "Clear chat",
		TextSize = 11,
		TextColor3 = Library.OutlineColor,
		ZIndex = 203,
		Parent = body,
	})
	Library:AddToRegistry(clearBtn, { TextColor3 = "OutlineColor" })

	local toEditorBtn = Library:Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, -16),
		Size = UDim2.new(0.5, -2, 0, 16),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Enum.Font.GothamSemibold,
		Text = "Send code to editor ->",
		TextSize = 11,
		TextColor3 = Library.AccentColor,
		ZIndex = 203,
		Parent = body,
	})
	Library:AddToRegistry(toEditorBtn, { TextColor3 = "AccentColor" })

	local busy = false
	local currentAssistant = nil

	local function scrollBottom()
		task.defer(function()
			transcript.CanvasPosition = Vector2.new(0, math.max(0, transcript.AbsoluteCanvasSize.Y))
		end)
	end

	local function onEvent(kind, payload)
		if kind == "status" then
			statusText.Text = tostring(payload or "")
		elseif kind == "done" then
			busy = false
			currentAssistant = nil
			sendBtn.Text = "Send"
			statusText.Text = ""
		elseif kind == "user" then
			addMsg("user", payload)
		elseif kind == "assistant_begin" then
			currentAssistant = addMsg("assistant", "")
		elseif kind == "assistant_delta" then
			if currentAssistant then
				currentAssistant.Text = currentAssistant.Text .. tostring(payload)
				scrollBottom()
			end
		elseif kind == "assistant_end" then
			currentAssistant = nil
		elseif kind == "assistant" then
			addMsg("assistant", payload)
		elseif kind == "tool" then
			addMsg("tool", payload)
		elseif kind == "toolresult" then
			addMsg("toolresult", payload)
		elseif kind == "error" then
			addMsg("error", payload)
		end
	end

	local function doSend()
		if busy then
			AIChat.cancel()
			statusText.Text = "stopping..."
			return
		end
		local text = inputBox.Text
		if type(text) ~= "string" or text:gsub("%s", "") == "" then
			return
		end
		inputBox.Text = ""
		busy = true
		sendBtn.Text = "Stop"
		AIChat.send(text, onEvent)
	end

	sendBtn.MouseButton1Click:Connect(doSend)
	inputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed and not busy then
			doSend()
		end
	end)

	clearBtn.MouseButton1Click:Connect(function()
		AIChat.reset()
		for _, c in ipairs(transcript:GetChildren()) do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		order = 0
		addMsg("assistant", "Chat cleared.")
	end)

	toEditorBtn.MouseButton1Click:Connect(function()
		if AIChat.lastCode and editor then
			editor.set(AIChat.lastCode)
			editorWindow:Show()
			setStatus("Pulled AI code into the editor.")
		end
	end)
end

-- ============================================================ tab
function CustomTab.init(window)
	local tab = window:AddTab("Custom", "Custom", Icons.Settings)

	SaveManager:SetIgnoreIndexes({
		"Custom_FeatureName",
		"Custom_FeatureList",
		"Custom_AIKey",
		"Custom_AIModel",
		"Custom_AIProvider",
		"Custom_Autorun",
	})

	buildEditorWindow()
	buildChatWindow()

	-- --------------------------------- LEFT: windows + feature management
	local manageBox = tab:AddLeftGroupbox("Custom Features")

	manageBox
		:AddButton("Open Code Editor", function()
			editorWindow:Show()
		end)
		:AddButton("Open AI Chat", function()
			chatWindow:Show()
		end)

	manageBox:AddInput("Custom_FeatureName", { Text = "Feature name", Default = "" })
	manageBox:AddDropdown("Custom_FeatureList", { Text = "Saved features", Values = Custom.list(), AllowNull = true })

	manageBox
		:AddButton("Run / Reload", function()
			if not editor then
				return setStatus("Editor not ready.")
			end
			if not currentName() then
				Options.Custom_FeatureName:SetValue("Untitled")
			end
			local name = currentName() or "Untitled"
			local source = editor.get()
			Custom.save(name, source)
			refreshList()
			local ok, err = Custom.run(name, source)
			if ok then
				setStatus("Running '%s'.", name)
			else
				setStatus("Error: %s", tostring(err))
			end
		end)
		:AddButton("Stop", function()
			local name = currentName()
			if not name then
				return setStatus("Nothing to stop.")
			end
			Custom.stop(name)
			setStatus("Stopped '%s'.", name)
		end)

	manageBox
		:AddButton("Save", function()
			local name = currentName()
			if not name then
				return setStatus("Enter a feature name first.")
			end
			local ok, err = Custom.save(name, editor and editor.get() or "")
			if ok then
				refreshList()
				setStatus("Saved '%s'.", name)
			else
				setStatus("Save failed: %s", tostring(err))
			end
		end)
		:AddButton("Load", function()
			local sel = Options.Custom_FeatureList.Value
			if type(sel) ~= "string" or sel == "" then
				return setStatus("Select a feature to load.")
			end
			local source = Custom.load(sel)
			if not source then
				return setStatus("Could not read '%s'.", sel)
			end
			if editor then
				editor.set(source)
			end
			Options.Custom_FeatureName:SetValue(sel)
			if Toggles.Custom_Autorun then
				Toggles.Custom_Autorun:SetValue(Custom.isAutorun(sel))
			end
			editorWindow:Show()
			setStatus("Loaded '%s'.", sel)
		end)

	manageBox
		:AddButton("New", function()
			if editor then
				editor.set(Custom.TEMPLATE)
			end
			Options.Custom_FeatureName:SetValue("")
			setStatus("New feature.")
		end)
		:AddButton("Delete", function()
			local sel = Options.Custom_FeatureList.Value
			if type(sel) ~= "string" or sel == "" then
				return setStatus("Select a feature to delete.")
			end
			Custom.delete(sel)
			refreshList()
			Options.Custom_FeatureList:SetValue(nil)
			setStatus("Deleted '%s'.", sel)
		end)

	local autorunToggle = manageBox:AddToggle("Custom_Autorun", {
		Text = "Autorun this feature on load",
		Default = false,
	})
	autorunToggle:OnChanged(function(value)
		local name = currentName()
		if name then
			Custom.setAutorun(name, value)
		end
	end)

	statusLabel = manageBox:AddLabel("Idle.", true)

	-- --------------------------------- LEFT: AI settings
	local aiBox = tab:AddLeftGroupbox("AI Settings")
	local s = Custom.settings()

	aiBox:AddDropdown("Custom_AIProvider", { Text = "Provider", Values = Custom.PROVIDERS, Default = s.provider })
	aiBox:AddInput("Custom_AIModel", { Text = "Model", Default = s.model })
	aiBox:AddInput("Custom_AIKey", { Text = "API key", Default = s.apiKey })

	local aiReady = false
	Options.Custom_AIProvider:OnChanged(function(value)
		Custom.setSetting("provider", value)
		if aiReady then
			local model = Custom.DEFAULT_MODELS[value]
			if model then
				Options.Custom_AIModel:SetValue(model)
			end
		end
	end)
	Options.Custom_AIModel:OnChanged(function(value)
		Custom.setSetting("model", value)
	end)
	Options.Custom_AIKey:OnChanged(function(value)
		Custom.setSetting("apiKey", value)
	end)
	aiReady = true

	aiBox:AddLabel("Key is stored locally (workspace/Aero/Custom), never in configs.", true)

	-- --------------------------------- RIGHT: live controls host
	local controlsBox = tab:AddRightGroupbox("Custom Controls")

	local holder = Library:Create("Frame", {
		BackgroundColor3 = Library.MainColor,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -4, 0, 360),
		LayoutOrder = 9999,
		ZIndex = 5,
		Parent = controlsBox.Container,
	})
	Library:Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = holder })
	Library:AddToRegistry(holder, { BackgroundColor3 = "MainColor" })
	local hstroke = Library:Create("UIStroke", { Color = Library.OutlineColor, Thickness = 1, Transparency = 0.5, Parent = holder })
	Library:AddToRegistry(hstroke, { Color = "OutlineColor" })

	local host = Library:Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ZIndex = 6,
		Parent = holder,
	})
	Library:Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = host })
	Library:Create("UIPadding", { PaddingRight = UDim.new(0, 4), Parent = host })

	local emptyHint = Library:Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.Gotham,
		Text = "Run a feature to see its controls here.",
		TextSize = 12,
		TextColor3 = Library.OutlineColor,
		TextWrapped = true,
		Parent = host,
	})
	Library:AddToRegistry(emptyHint, { TextColor3 = "OutlineColor" }, true)

	Custom.setHost(host)

	pcall(function()
		controlsBox:Resize()
	end)

	task.spawn(function()
		Custom.autorunAll()
	end)
end

return CustomTab
