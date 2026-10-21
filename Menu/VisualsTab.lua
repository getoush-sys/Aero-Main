---@module GUI.Icons
local Icons = require("GUI/Icons")

---@module Utility.Logger
local Logger = require("Utility/Logger")

---@module Utility.PersistentData
local PersistentData = require("Utility/PersistentData")

---@module Utility.Configuration
local Configuration = require("Utility/Configuration")

---@module Features.Visuals.Visuals
local Visuals = require("Features/Visuals/Visuals")

---@module Utility.JSON
local JSON = require("Utility/JSON")

---@module Features.Visuals.Objects.BuilderData
local BuilderData = require("Features/Visuals/Objects/BuilderData")

local VisualsTab = {}

---@param groupbox table
function VisualsTab.initESPCustomization(groupbox)
	groupbox:AddSlider("FontSize", {
		Text = "ESP Font Size",
		Default = 16,
		Min = 4,
		Max = 24,
		Rounding = 0,
	})

	groupbox:AddSlider("ESPSplitLineLength", {
		Text = "ESP Split Line Length",
		Default = 30,
		Min = 10,
		Max = 100,
		Rounding = 0,
	})

	local fonts = {}

	for _, font in next, Enum.Font:GetEnumItems() do
		if font == Enum.Font.Unknown then
			continue
		end

		table.insert(fonts, font.Name)
	end

	groupbox:AddDropdown("Font", { Text = "ESP Fonts", Default = 1, Values = fonts })
end

---@param groupbox table
function VisualsTab.initESPOptimizations(groupbox)
	groupbox:AddToggle("ESPLimitUpdates", {
		Text = "ESP Limit Updates",
		Default = true,
	})

	local eluDepBox = groupbox:AddDependencyBox()

	eluDepBox:AddSlider("ESPRefreshRate", {
		Text = "ESP Refresh Rate",
		Suffix = "f",
		Default = 30,
		Min = 1,
		Max = 144,
		Rounding = 0,
	})

	eluDepBox:SetupDependencies({
		{ Toggles.ESPLimitUpdates, true },
	})

	groupbox:AddToggle("ESPSplitUpdates", {
		Text = "ESP Split Updates",
		Default = false,
	})

	local esuDepBox = groupbox:AddDependencyBox()

	esuDepBox:AddSlider("ESPSplitFrames", {
		Text = "ESP Split Frames",
		Suffix = "f",
		Default = 32,
		Min = 1,
		Max = 64,
		Rounding = 0,
	})

	esuDepBox:SetupDependencies({
		{ Toggles.ESPSplitUpdates, true },
	})

	groupbox:AddToggle("NoPersisentESP", {
		Text = "No Persistent ESP",
		Default = false,
	})
end

---@param groupbox table
function VisualsTab.initWorldVisualsSection(groupbox)
	groupbox:AddToggle("OptimizeGame", {
		Text = "Optimize Game",
		Tooltip = "Rate-limits Deepwoken's water (SeaClient) and world render (WorldClient) loops for higher FPS by re-driving the game's render connections.",
		Default = false,
	})

	groupbox:AddToggle("UseFastFlags", {
		Text = "Use Fast Flags For Session",
		Default = false,
	})

	Toggles.UseFastFlags:OnChanged(function(state)
		if not state then
			return
		end

		local success, content = pcall(readfile, "fflags.json")
		if not success then
			return Logger.longNotify("Failed to load fflags.json. Make sure the file exists in your workspace.")
		end
		local decodeSuccess, fflags = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), content)
		if not decodeSuccess then
			return Logger.longNotify("fflags.json is not a valid JSON format.")
		end
		for index, value in next, fflags do
			pcall(function()
				setfflag(index, tostring(value))
			end)
		end
		Logger.notify("Fast Flags applied successfully for this session server hop to see changes.")
	end)

	groupbox:AddToggle("ModifyFieldOfView", {
		Text = "Modify Field Of View",
		Default = false,
	})

	local fovDepBox = groupbox:AddDependencyBox()

	fovDepBox:AddSlider("FieldOfView", {
		Text = "Field Of View Slider",
		Default = 90,
		Min = 0,
		Max = 120,
		Suffix = "°",
		Rounding = 0,
	})

	fovDepBox:SetupDependencies({
		{ Toggles.ModifyFieldOfView, true },
	})

	local modifyAmbienceToggle = groupbox:AddToggle("ModifyAmbience", {
		Text = "Modify Ambience",
		Default = false,
	})

	modifyAmbienceToggle:AddColorPicker("AmbienceColor", {
		Default = Color3.fromHex("FFFFFF"),
	})

	local oacDepBox = groupbox:AddDependencyBox()

	oacDepBox:AddToggle("OriginalAmbienceColor", {
		Text = "Original Ambience Color",
		Default = false,
	})

	local umacDepBox = oacDepBox:AddDependencyBox()

	umacDepBox:AddSlider("OriginalAmbienceColorBrightness", {
		Text = "Original Ambience Brightness",
		Default = 0,
		Min = 0,
		Max = 255,
		Suffix = "+",
		Rounding = 0,
	})

	oacDepBox:SetupDependencies({
		{ Toggles.ModifyAmbience, true },
	})

	umacDepBox:SetupDependencies({
		{ Toggles.OriginalAmbienceColor, true },
	})
end

---@param groupbox table
function VisualsTab.initVisualAssistanceSection(groupbox)
	groupbox:AddToggle("ChainOfPerfectionTracker", {
		Text = "Chain Of Perfection Tracker",
		Default = false,
	})

	groupbox:AddToggle("SanityTracker", {
		Text = "Sanity Tracker",
		Default = false,
	})

	groupbox:AddToggle("MysteryMantraRevealer", {
		Text = "Mystery Mantra Revealer",
		Default = false,
	})

	groupbox:AddToggle("Roll2Revealer", {
		Text = "Roll 2 Revealer",
		Default = false,
	})

	local buildAssistanceToggle = groupbox:AddToggle("BuildAssistance", {
		Text = "Build Assistance",
		Default = false,
	})

	local buildAssistanceDepBox = groupbox:AddDependencyBox()

	local sdoToggle = buildAssistanceDepBox:AddToggle("ShrineDetectionOverride", {
		Text = "Shrine Detection Override",
		Default = true,
	})

	local sdoDepBox = buildAssistanceDepBox:AddDependencyBox()

	sdoDepBox:AddDropdown("ShrineOverrideState", {
		Text = "Shrine Override State",
		Default = 1,
		Values = { "Pre-Shrine", "Post-Shrine", "Must Shrine" },
	})

	sdoDepBox:SetupDependencies({
		{ sdoToggle, true },
	})

	buildAssistanceDepBox:AddToggle("AutoFavourCards", {
		Text = "Auto Favour Cards",
		Default = false,
	})

	buildAssistanceDepBox:AddInput("BuildAssistanceLink", {
		Text = "Build Assistance Link",
		Placeholder = "Enter your builder link here.",
		Finished = true,
		Callback = function(value)
			-- Empty box (e.g. restored by a config load) -> do nothing, silently. Only complain when
			-- there's actual text that failed to parse.
			if type(value) ~= "string" or value:gsub("%s+", "") == "" then
				return
			end

			local headers = {
				["Content-Type"] = "application/json",
				["Accept"] = "application/json",
				["Origin"] = "https://deepwoken.co",
				["Referer"] = "https://deepwoken.co/builder",
				["Sec-Fetch-Site"] = "same-origin",
				["Sec-Fetch-Mode"] = "cors",
				["Sec-Fetch-Dest"] = "empty",
			}

			local id = value:match("[?&]id=([%w%d]+)") or value:match("^%s*([%w%d]+)%s*$")
			if not id then
				return Logger.notify("Invalid builder link. Please provide a valid builder URL or builder id.")
			end

			local bresponse = request({
				Url = "https://new.deepwoken.co/api/proxy/builds/" .. id,
				Method = "GET",
				Headers = headers,
			})

			if not bresponse or not bresponse.Success or not bresponse.Body then
				return Logger.notify("Invalid response while fetching builder response.")
			end

			local bsuccess, bresult = pcall(JSON.decode, bresponse.Body)
			if not bsuccess or not bresult then
				return Logger.notify("JSON error '%s' while deserializing builder response.", bresult)
			end

			Logger.notify("Successfully fetched build data.")

			local dresponse = request({
				Url = "https://new.deepwoken.co/api/proxy/get?type=all",
				Method = "GET",
				Headers = headers,
			})

			if not dresponse or not dresponse.Success or not dresponse.Body then
				return Logger.notify("Invalid response while fetching data response.")
			end

			local dsuccess, dresult = pcall(JSON.decode, dresponse.Body)
			if not dsuccess or not dresult then
				return Logger.notify("JSON error '%s' while deserializing data response.", dresult)
			end

			Logger.notify("Successfully created BuilderData object.")

			Visuals.bdata = BuilderData.new(bresult, dresult)
		end,
	})

	buildAssistanceDepBox:SetupDependencies({
		{ buildAssistanceToggle, true },
	})
end

---@param groupbox table
function VisualsTab.initVisualRemovalsSection(groupbox)
	groupbox:AddToggle("NoFog", {
		Text = "No Fog",
		Default = false,
	})

	groupbox:AddToggle("NoBlind", {
		Text = "No Blind",
		Default = false,
	})

	groupbox:AddToggle("NoBlur", {
		Text = "No Blur",
		Default = false,
	})

	groupbox:AddToggle("NoShadows", {
		Text = "No Shadows",
		Default = false,
	})

	groupbox:AddToggle("NoAnimatedSea", {
		Text = "No Animated Sea",
		Default = false,
	})

	groupbox:AddToggle("NoSanityVFX", {
		Text = "No Sanity VFX",
		Default = false,
	})
end

---@note: Every ESP object has access to these options.
---@param identifier string
---@param groupbox table
---@return string, table
function VisualsTab.initBaseESPSection(identifier, groupbox)
	local enableToggle = groupbox
		:AddToggle(Configuration.identify(identifier, "Enable"), {
			Text = "Enable ESP",
			Default = false,
		})
		:AddKeyPicker(Configuration.identify(identifier, "Keybind"), {
			Default = "N/A",
			SyncToggleState = true,
			NoUI = true,
			Text = groupbox.Name,
		})

	enableToggle:AddColorPicker(Configuration.identify(identifier, "Color"), {
		Default = Color3.new(1, 1, 1),
	})

	local enableDepBox = groupbox:AddDependencyBox()

	enableDepBox:AddToggle(Configuration.identify(identifier, "ShowDistance"), {
		Text = "Show Distance",
		Default = false,
	})

	enableDepBox:AddSlider(Configuration.identify(identifier, "TextOpacity"), {
		Text = "Text Opacity",
		Default = 100,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = "%",
	})

	enableDepBox:AddSlider(Configuration.identify(identifier, "MaxDistance"), {
		Text = "Distance Threshold",
		Default = 2000,
		Min = 0,
		Max = 100000,
		Suffix = "studs",
		Rounding = 0,
	})

	enableDepBox:SetupDependencies({
		{ enableToggle, true },
	})

	return identifier, enableDepBox
end

---@param identifier string
---@param depbox table
---@return string, table
function VisualsTab.addChestESP(identifier, depbox)
	depbox:AddToggle(Configuration.identify(identifier, "HideIfOpened"), {
		Text = "Hide If Opened",
		Default = false,
	})

	return identifier, depbox
end

---@param identifier string
---@param depbox table
---@return string, table
function VisualsTab.addObeliskESP(identifier, depbox)
	depbox:AddToggle(Configuration.identify(identifier, "HideIfTurnedOn"), {
		Text = "Hide If Turned On",
		Default = false,
	})

	return identifier, depbox
end

---@param identifier string
---@param depbox table
---@return string, table
function VisualsTab.addBoneAltarESP(identifier, depbox)
	depbox:AddToggle(Configuration.identify(identifier, "HideIfBoneInside"), {
		Text = "Hide If Bone Inside",
		Default = false,
	})

	return identifier, depbox
end

---@param identifier string
---@param depbox table
---@return string, table
function VisualsTab.addEntityESP(identifier, depbox)
	local hbToggle = depbox:AddToggle(Configuration.identify(identifier, "HealthBar"), {
		Text = "Show Health Bar",
		Default = false,
	})

	hbToggle:AddColorPicker(Configuration.identify(identifier, "FullColor"), {
		Default = Color3.new(0, 1, 0),
	})

	hbToggle:AddColorPicker(Configuration.identify(identifier, "EmptyColor"), {
		Default = Color3.new(1, 0, 0),
	})

	depbox:AddToggle(Configuration.identify(identifier, "BoundingBox"), {
		Text = "Show Bounding Box",
		Default = false,
	})

	depbox:AddToggle(Configuration.identify(identifier, "ShowHealthChanges"), {
		Text = "Show Health Changes",
		Default = false,
	})

	return identifier, depbox
end

---@param identifier string
---@param depbox table
---@return string, table
function VisualsTab.addPlayerESP(identifier, depbox)
	local markAlliesToggle = depbox:AddToggle(Configuration.identify(identifier, "MarkAllies"), {
		Text = "Mark Allies",
		Default = false,
	})

	markAlliesToggle:AddColorPicker(Configuration.identify(identifier, "AllyColor"), {
		Default = Color3.new(1, 1, 1),
	})

	local maDepBox = depbox:AddDependencyBox()

	maDepBox
		:AddToggle(Configuration.identify(identifier, "HideIfAlly"), {
			Text = "Hide Allies On ESP",
			Default = false,
		})
		:AddKeyPicker(Configuration.identify(identifier, "HideIfAllyKeybind"), {
			Default = "N/A",
			SyncToggleState = true,
			NoUI = true,
			Text = "Hide Allies On ESP",
		})

	maDepBox:SetupDependencies({
		{ markAlliesToggle, true },
	})

	local markSackToggle = depbox:AddToggle(Configuration.identify(identifier, "MarkSackUsers"), {
		Text = "Mark Users Holding Sack",
		Default = false,
	})

	markSackToggle:AddColorPicker(Configuration.identify(identifier, "SackColor"), {
		Default = Color3.new(1, 1, 1),
	})

	local markOathToggle = depbox:AddToggle(Configuration.identify(identifier, "MarkOathUsers"), {
		Text = "Mark Oath Users",
		Default = false,
	})

	markOathToggle:AddColorPicker(Configuration.identify(identifier, "OathColor"), {
		Default = Color3.new(1, 1, 1),
	})

	depbox:AddToggle(Configuration.identify(identifier, "ShowHealthComparison"), {
		Text = "Show Health Comparison",
		Default = false,
	})

	depbox:AddToggle(Configuration.identify(identifier, "ShowDangerTime"), {
		Text = "Show Danger Time",
		Default = false,
	})

	local armorBar = depbox:AddToggle(Configuration.identify(identifier, "ArmorBar"), {
		Text = "Show Armor Bar",
		Default = false,
	})

	armorBar:AddColorPicker(Configuration.identify(identifier, "ArmorBarColor"), {
		Default = Color3.new(0.388235, 0.686274, 0.984313),
	})

	local bloodBar = depbox:AddToggle(Configuration.identify(identifier, "BloodBar"), {
		Text = "Show Blood Bar",
		Default = false,
	})

	bloodBar:AddColorPicker(Configuration.identify(identifier, "BloodBarColor"), {
		Default = Color3.new(0.8, 0, 0),
	})

	local sanityBar = depbox:AddToggle(Configuration.identify(identifier, "SanityBar"), {
		Text = "Show Sanity Bar",
		Default = false,
	})

	sanityBar:AddColorPicker(Configuration.identify(identifier, "SanityBarColor"), {
		Default = Color3.new(0.6, 0, 0.8),
	})

	local tempoBar = depbox:AddToggle(Configuration.identify(identifier, "TempoBar"), {
		Text = "Show Tempo Bar",
		Default = false,
	})

	tempoBar:AddColorPicker(Configuration.identify(identifier, "TempoBarColor"), {
		Default = Color3.new(0, 1, 1),
	})

	local postureBar = depbox:AddToggle(Configuration.identify(identifier, "PostureBar"), {
		Text = "Show Posture Bar",
		Default = false,
	})

	postureBar:AddColorPicker(Configuration.identify(identifier, "PostureBarColor"), {
		Default = Color3.new(1, 0.8, 0),
	})

	depbox:AddDropdown(Configuration.identify(identifier, "PlayerNameType"), {
		Text = "Player Name Type",
		Default = 1,
		Values = { "Character Name", "Roblox Display Name", "Roblox Username" },
	})

	return identifier, depbox
end

---@param identifier string
---@param depbox table
---@return string, table
function VisualsTab.addFilterESP(identifier, depbox)
	local filterObjectsToggle = depbox:AddToggle(Configuration.identify(identifier, "FilterObjects"), {
		Text = "Filter Objects",
		Default = false,
	})

	local foDepBox = depbox:AddDependencyBox()

	foDepBox:AddDropdown(Configuration.identify(identifier, "FilterLabelList"), {
		Text = "Hidden Labels",
		Tooltip = "Select the labels you don't want shown. Only labels currently being tracked are listed.",
		Default = {},
		SaveValues = true,
		Multi = true,
		AllowNull = true,
		Searchable = true,
		Values = {},
	})

	foDepBox:SetupDependencies({
		{ filterObjectsToggle, true },
	})

	return identifier, depbox
end

--- Morph loader. Models live under the executor workspace at luma_morphs/Races and luma_morphs/Ornaments.
---@param groupbox table
function VisualsTab.initMorphLoaderSection(groupbox)
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer

	-- Executor file API resolution (Synapse Z / generic).
	local readCustomAsset = getcustomasset or getsynasset or (syn and syn.get_custom_asset)
	local listFiles = listfiles

	local FOLDERS = {
		Races = "Aero/luma_morphs/Races",
		Ornaments = "Aero/luma_morphs/Ornaments",
	}

	-- Create the morph folders on first execution, the same way the config / theme folders get made.
	do
		local function ensureFolder(path)
			if type(makefolder) ~= "function" then
				return
			end
			if type(isfolder) == "function" and isfolder(path) then
				return
			end
			pcall(makefolder, path)
		end
		ensureFolder("Aero")
		ensureFolder("Aero/luma_morphs")
		ensureFolder(FOLDERS.Races)
		ensureFolder(FOLDERS.Ornaments)
	end

	local HOLDER_NAME = "LumaMorph_Applied"
	local BACKUP_NAME = "LumaMorph_Backup"
	local HIDDEN_LTM_ATTRIBUTE = "LumaMorphOriginalLocalTransparency"
	local HIDDEN_TRANSPARENCY_ATTRIBUTE = "LumaMorphOriginalTransparency"
	local AVATAR_COLOR_ATTRIBUTE = "LumaMorphAvatarOriginalColor"
	-- Per-morph baked forward nudge (studs, along facing).
	local MORPH_FORWARD = {
	}
	-- Morphs that ship a HideBody flag but look better worn OVER the body.
	local MORPH_NOHIDE = {
	}
	-- For hide-body morphs with gaps, keep these character limbs visible to plug the holes. morphName -> { limbName = true }.
	local MORPH_KEEP_VISIBLE = {
	}

	local currentCategory = "Races"
	local currentFile = nil
	local savedMorph = PersistentData.get("morphResume")
	local serverHopEnabled = type(savedMorph) == "table" and savedMorph.enabled == true
	local activeMorph = nil
	if serverHopEnabled and type(savedMorph.kind) == "string" then
		if savedMorph.kind == "file"
			and FOLDERS[savedMorph.category]
			and type(savedMorph.file) == "string"
			and savedMorph.file ~= ""
		then
			activeMorph = {
				kind = "file",
				category = savedMorph.category,
				file = savedMorph.file,
			}
		elseif savedMorph.kind == "avatar" and type(savedMorph.username) == "string" then
			activeMorph = {
				kind = "avatar",
				username = savedMorph.username,
			}
		end
	end
	local hideBodyEnabled = true
	local hideHeadFaceEnabled = true
	local reapplyEnabled = false
	local hideToggle -- forward declared; assigned in UI section below
	local RunService = game:GetService("RunService")
	local hideConn = nil
	local hiddenList = {}

	local function saveMorphResume()
		if not serverHopEnabled then
			PersistentData.set("morphResume", nil)
			return
		end

		local data = { enabled = true }
		if activeMorph then
			data.kind = activeMorph.kind
			data.category = activeMorph.category
			data.file = activeMorph.file
			data.username = activeMorph.username
		end
		PersistentData.set("morphResume", data)
	end

	local function listMorphs(dir)
		if type(listFiles) ~= "function" then return {} end
		local ok, res = pcall(listFiles, dir)
		if not ok or type(res) ~= "table" then return {} end
		local out = {}
		for _, p in ipairs(res) do
			local path = tostring(p):gsub("\\", "/")
			if path:sub(-5):lower() == ".rbxm" then
				local name = path:match("([^/]+)%.rbxm$")
				if name then table.insert(out, name) end
			end
		end
		table.sort(out)
		return out
	end

	local function getChar()
		local c = lp.Character
		if not c then return nil end
		if not c:FindFirstChild("HumanoidRootPart") then
			c:WaitForChild("HumanoidRootPart", 5)
		end
		return c
	end

	-- Stop enforcing invisibility and restore everything we hid.
	local function stopHide()
		if hideConn then hideConn:Disconnect(); hideConn = nil end
		for _, p in ipairs(hiddenList) do
			if p and p.Parent then
				pcall(function()
					if p:IsA("BasePart") then
						local originalLtm = p:GetAttribute(HIDDEN_LTM_ATTRIBUTE)
						p.LocalTransparencyModifier = originalLtm or 0
						p:SetAttribute(HIDDEN_LTM_ATTRIBUTE, nil)
						local originalTransparency = p:GetAttribute(HIDDEN_TRANSPARENCY_ATTRIBUTE)
						if originalTransparency ~= nil then
							p.Transparency = originalTransparency
						end
						p:SetAttribute(HIDDEN_TRANSPARENCY_ATTRIBUTE, nil)
					end
					if p:GetAttribute("LumaMorphHidden") ~= nil then
						p.Transparency = p:GetAttribute("LumaMorphHidden")
						p:SetAttribute("LumaMorphHidden", nil)
					end
				end)
			end
		end
		hiddenList = {}
	end

	-- Keep the given parts/decals invisible every frame (Deepwoken re-shows them otherwise).
	local function startHide(parts)
		stopHide()
		hiddenList = parts
		hideConn = RunService.RenderStepped:Connect(function()
			for _, p in ipairs(hiddenList) do
				if p and p.Parent then
					if p:IsA("BasePart") then
						if p:GetAttribute(HIDDEN_LTM_ATTRIBUTE) == nil then
							p:SetAttribute(HIDDEN_LTM_ATTRIBUTE, p.LocalTransparencyModifier)
						end
						if p:GetAttribute(HIDDEN_TRANSPARENCY_ATTRIBUTE) == nil then
							p:SetAttribute(HIDDEN_TRANSPARENCY_ATTRIBUTE, p.Transparency)
						end
						p.LocalTransparencyModifier = 1
					else
						p.Transparency = 1
					end
				end
			end
		end)
	end

	local function clearMorphs()
		stopHide()
		local c = lp.Character
		if not c then return end
		-- Recover legacy hides from earlier runs, which did not save each part's prior LTM.
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then
				local originalLtm = p:GetAttribute(HIDDEN_LTM_ATTRIBUTE)
				if originalLtm ~= nil then
					p.LocalTransparencyModifier = originalLtm
					p:SetAttribute(HIDDEN_LTM_ATTRIBUTE, nil)
				elseif p.LocalTransparencyModifier > 0 then
					p.LocalTransparencyModifier = 0
				end
				local originalTransparency = p:GetAttribute(HIDDEN_TRANSPARENCY_ATTRIBUTE)
				if originalTransparency ~= nil then
					p.Transparency = originalTransparency
					p:SetAttribute(HIDDEN_TRANSPARENCY_ATTRIBUTE, nil)
				end
			end
		end
		-- Remove morph clothing clones we added.
		for _, p in ipairs(c:GetChildren()) do
			if p:GetAttribute("LumaMorphClothing")
				or p:GetAttribute("LumaMorphAccessory")
				or p:GetAttribute("LumaMorphBodyColors")
				or p:GetAttribute("LumaMorphCharacterMesh")
			then
				p:Destroy()
			end
		end
		-- Restore any original clothing we backed up.
		local backup = c:FindFirstChild(BACKUP_NAME)
		if backup then
			for _, p in ipairs(backup:GetChildren()) do p.Parent = c end
			backup:Destroy()
		end
		local h = c:FindFirstChild(HOLDER_NAME)
		if h then h:Destroy() end
		-- Restore / remove any face decals we changed.
		for _, p in ipairs(c:GetDescendants()) do
			if p:GetAttribute("LumaMorphFaceClone") then
				p:Destroy()
			elseif p:GetAttribute("LumaMorphFace") ~= nil then
				pcall(function() p.Texture = p:GetAttribute("LumaMorphFace") end)
				p:SetAttribute("LumaMorphFace", nil)
			end
		end
		-- Safety sweep for any leftover hidden decals from a prior run.
		for _, p in ipairs(c:GetDescendants()) do
			if p:GetAttribute("LumaMorphHidden") ~= nil then
				pcall(function() p.Transparency = p:GetAttribute("LumaMorphHidden") end)
				p:SetAttribute("LumaMorphHidden", nil)
			end
		end
		-- Restore any real body limbs we recolored to a morph's skin tone.
		for _, p in ipairs(c:GetDescendants()) do
			if p:GetAttribute("LumaMorphSkin") ~= nil then
				pcall(function() p.Color = p:GetAttribute("LumaMorphSkin") end)
				p:SetAttribute("LumaMorphSkin", nil)
			end
			if p:GetAttribute(AVATAR_COLOR_ATTRIBUTE) ~= nil then
				pcall(function() p.Color = p:GetAttribute(AVATAR_COLOR_ATTRIBUTE) end)
				p:SetAttribute(AVATAR_COLOR_ATTRIBUTE, nil)
			end
		end
	end

	-- Character limb parts (R15 first, R6 fallback) we can bind morph pieces to.
	local LIMB_NAMES = {
		"Head", "UpperTorso", "LowerTorso",
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"RightUpperLeg", "RightLowerLeg", "RightFoot",
		"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
	}
	-- Names a morph tends to use for its torso/root anchor.
	local ANCHOR_NAMES = {
		"HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso",
		"tt", "t", "lt", "Chestplate", "Body", "Root", "Middle",
	}

	local function collectLimbs(char)
		local limbs = {}
		for _, name in ipairs(LIMB_NAMES) do
			local p = char:FindFirstChild(name)
			if p and p:IsA("BasePart") then limbs[#limbs + 1] = p end
		end
		return limbs
	end

	local function findCharAnchor(char)
		return char:FindFirstChild("UpperTorso")
			or char:FindFirstChild("Torso")
			or char:FindFirstChild("LowerTorso")
			or char:FindFirstChild("HumanoidRootPart")
	end

	local function findMorphAnchor(model)
		for _, an in ipairs(ANCHOR_NAMES) do
			local p = model:FindFirstChild(an, true)
			if p and p:IsA("BasePart") then return p end
		end
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end

	local function nearestLimb(limbs, pos)
		local best, bestDist
		for _, l in ipairs(limbs) do
			local d = (l.Position - pos).Magnitude
			if not bestDist or d < bestDist then bestDist, best = d, l end
		end
		return best
	end

	-- Map a keyword in a morph part's name to a character limb, so morphs that bind by naming convention land on the intended limb instead of relying on raw nearest-position guessing.
	local LIMB_HINTS = {
		{ "uppertorso", { "UpperTorso" } },
		{ "lowertorso", { "LowerTorso" } },
		{ "torso", { "UpperTorso", "Torso", "LowerTorso" } },
		{ "chest", { "UpperTorso", "Torso" } },
		{ "head", { "Head" } }, { "face", { "Head" } }, { "hair", { "Head" } },
		{ "hat", { "Head" } }, { "horn", { "Head" } }, { "mask", { "Head" } }, { "helm", { "Head" } },
		-- Head/hair overlay meshes (ippo's "Shading") are head pieces; without a hint they'd fall to the torso and render on the chest.
		{ "shading", { "Head" } }, { "shade", { "Head" } },
		{ "lefthand", { "LeftHand", "Left Arm" } }, { "righthand", { "RightHand", "Right Arm" } },
		{ "leftlowerarm", { "LeftLowerArm", "Left Arm" } }, { "rightlowerarm", { "RightLowerArm", "Right Arm" } },
		{ "leftupperarm", { "LeftUpperArm", "Left Arm" } }, { "rightupperarm", { "RightUpperArm", "Right Arm" } },
		{ "leftarm", { "LeftUpperArm", "Left Arm" } }, { "rightarm", { "RightUpperArm", "Right Arm" } },
		{ "leftfoot", { "LeftFoot", "Left Leg" } }, { "rightfoot", { "RightFoot", "Right Leg" } },
		{ "leftlowerleg", { "LeftLowerLeg", "Left Leg" } }, { "rightlowerleg", { "RightLowerLeg", "Right Leg" } },
		{ "leftupperleg", { "LeftUpperLeg", "Left Leg" } }, { "rightupperleg", { "RightUpperLeg", "Right Leg" } },
		{ "leftleg", { "LeftUpperLeg", "Left Leg" } }, { "rightleg", { "RightUpperLeg", "Right Leg" } },
		{ "arm", { "UpperTorso", "Torso" } }, -- generic "arms equipment" binds to the torso anchor
	}
	local function limbFromName(char, name)
		local n = tostring(name):lower():gsub("[^%w]", "")
		for _, pair in ipairs(LIMB_HINTS) do
			if n:find(pair[1], 1, true) then
				for _, cand in ipairs(pair[2]) do
					local limb = char:FindFirstChild(cand)
					if limb and limb:IsA("BasePart") then
						return limb
					end
				end
			end
		end
		return nil
	end

	-- The attachment a morph part welds by.
	local function bindingAttachment(part)
		local a = part:FindFirstChild("Offset") or part:FindFirstChild("JointOffset")
			or part:FindFirstChild("Attach")
		if a and a:IsA("Attachment") then
			return a
		end
		return nil
	end

	-- Per-morph, per-part vertical lift (studs) for pieces a morph anchors too low.
	local MORPH_PART_LIFT = {
		FifthGear = { ArmsEquipment_Torso = 1.3 },
	}
	local function partLift(morphName, partName)
		local base = tostring(morphName):gsub("%s*%(%d+%)%s*$", "")
		local t = MORPH_PART_LIFT[base]
		return (t and t[partName]) or 0
	end

	-- Per-morph skin tone.
	local MORPH_SKIN = {
		FifthGear = Color3.fromRGB(226, 178, 132), -- Gear 5 golden tan
	}
	-- Real body limbs to recolor (R6 + R15 names; whichever the character actually has).
	local SKIN_LIMBS = {
		"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
		"UpperTorso", "LowerTorso",
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"RightUpperLeg", "RightLowerLeg", "RightFoot",
	}

	-- Full R15 limb names.
	local R15_LIMB_SET = {
		Head = true, UpperTorso = true, LowerTorso = true,
		LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
		RightUpperArm = true, RightLowerArm = true, RightHand = true,
		LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
		RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	}

	-- ---- Per-morph overrides (keyed by base file name, trailing " (n)" copy-suffix ignored) ----
	local function morphBase(name) return tostring(name):gsub("%s*%(%d+%)%s*$", "") end
	-- Morphs whose "head" is a stiff extension of the body: weld the head region to the TORSO, not the neck, so it can't swing away from the body when a weapon draw / emote animation tilts the head.
	local MORPH_RIGID_HEAD = { TungTung = true }
	-- Redundant / overlapping pieces to drop outright.
	local MORPH_HIDE_PARTS = {
		Mudskipper = { MudskipperHatA = true },
	}
	-- Force a named morph part onto a named character limb, overriding the name-guessing.
	local MORPH_PART_LIMB = {}
	-- Corrective vertical lift (studs) for DRIVEN sub-parts that sit too low -- their joint offset drops them onto the chest.
	local MORPH_SUBPART_LIFT = { ippo = { MeshPart = 1.5 } }

	local function applyModel(model, hideBody, morphName)
		local char = getChar()
		if not char then return false, "no character" end
		if not char:FindFirstChild("HumanoidRootPart") then return false, "no HumanoidRootPart" end

		local limbs = collectLimbs(char)
		if #limbs == 0 then return false, "no limbs on character" end

		local extraHide = {} -- specific parts (e.g. real hair) to hide even when not hiding the whole body
		local morphHasHair = false -- set true if the morph supplies its own hair

		local base = morphBase(morphName)

		-- NOTE: do NOT strip the morph's LocalScripts -- on these Deepwoken race morphs they apply the skin/hair/eye colouring from RaceData at runtime; removing them renders the morph flat black.

		-- Drop pieces this morph is known to double up on (prevents z-fighting overlaps).
		local hideParts = MORPH_HIDE_PARTS[base]
		if hideParts then
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") and hideParts[p.Name] then
					pcall(function() p:Destroy() end)
				end
			end
		end

		-- Per-morph forced part->limb map, consulted before name guessing.
		local partLimbMap = MORPH_PART_LIMB[base]
		local function overrideLimb(partName)
			local nm = partLimbMap and partLimbMap[partName]
			if nm then
				local l = char:FindFirstChild(nm)
				if l and l:IsA("BasePart") then return l end
			end
			return nil
		end
		local rigidHead = MORPH_RIGID_HEAD[base]
		-- Records which character limb each morph part was bound to, so sub-parts of an assembly can inherit their parent's limb instead of falling to a nearest-position guess that can strand them on the chest.
		local partToLimb = {}

		-- Snapshot the real body NOW (before adding morph parts) so we can hide it wholesale, skipping any joint-filler limbs this morph wants kept visible.
		local keepVisible = MORPH_KEEP_VISIBLE[morphName] or {}
		local originalBits = {}
		for _, p in ipairs(char:GetDescendants()) do
			local isPart = p:IsA("BasePart") and p.Name ~= "HumanoidRootPart"
			local isDecal = p:IsA("Decal") or p:IsA("Texture")
			if isPart or isDecal then
				local ownerName = isPart and p.Name or (p.Parent and p.Parent.Name)
				if not (ownerName and keepVisible[ownerName]) then
					if isDecal and p:GetAttribute("LumaMorphHidden") == nil then
						p:SetAttribute("LumaMorphHidden", p.Transparency)
					end
					originalBits[#originalBits + 1] = p
				end
			end
		end

		local cAnchor = findCharAnchor(char)
		local mAnchor = findMorphAnchor(model)
		if not cAnchor or not mAnchor then return false, "could not find torso anchor" end

		-- Does this morph actually replace the body?
		local morphWantsHide = model:FindFirstChild("HideBody", true) ~= nil
		-- Only trust the anchor if it's a genuine torso part; otherwise recenter afterward.
		local TRUE_TORSO = {
			HumanoidRootPart = true, UpperTorso = true, Torso = true,
			LowerTorso = true, tt = true, t = true, lt = true,
		}
		local trustedAnchor = TRUE_TORSO[mAnchor.Name] == true

		-- Transform that maps morph-space onto the character.
		local T = cAnchor.CFrame * mAnchor.CFrame:Inverse()

		-- Parts already driven by the morph's own joints — don't re-weld those.
		local driven = {}
		for _, j in ipairs(model:GetDescendants()) do
			if j:IsA("Weld") or j:IsA("Motor6D") or j:IsA("WeldConstraint")
				or j:IsA("Snap") or j:IsA("ManualWeld") then
				if j.Part1 then driven[j.Part1] = true end
			end
		end

		-- Rigidly slide the whole morph onto the character (keeps internal layout + joints).
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CFrame = T * p.CFrame
			end
		end

		-- If we anchored off a non-torso part (e.g.
		if not trustedAnchor then
			local sum, cnt = Vector3.zero, 0
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then sum = sum + p.Position; cnt = cnt + 1 end
			end
			if cnt > 0 then
				local center = sum / cnt
				local delta = Vector3.new(cAnchor.Position.X - center.X, 0, cAnchor.Position.Z - center.Z)
				for _, p in ipairs(model:GetDescendants()) do
					if p:IsA("BasePart") then p.CFrame = p.CFrame + delta end
				end
			end
		end

		-- Forward/back nudge along the character's facing: per-morph baked default.
		local fwdAmount = MORPH_FORWARD[morphName] or 0
		if fwdAmount ~= 0 then
			local fwd = cAnchor.CFrame.LookVector * fwdAmount
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then p.CFrame = p.CFrame + fwd end
			end
		end

		-- Full-body R15 rig morphs (e.g.
		local rigParts = {}
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and R15_LIMB_SET[p.Name] and char:FindFirstChild(p.Name) then
				rigParts[#rigParts + 1] = p
			end
		end
		if #rigParts >= 6 then
			-- Cut the morph's internal limb welds so each limb is free to follow its own bone.
			for _, w in ipairs(model:GetDescendants()) do
				if (w:IsA("Weld") or w:IsA("Motor6D") or w:IsA("ManualWeld")
					or w:IsA("Snap") or w:IsA("WeldConstraint"))
					and w.Part1 and R15_LIMB_SET[w.Part1.Name] then
					w:Destroy()
				end
			end
			for _, p in ipairs(rigParts) do
				local targetName = p.Name
				local keepPos = false
				-- Rigid-head morphs: pin the head to the torso and KEEP its current offset above the body, so the log head rides the torso as one piece instead of pivoting on the neck when the character animates.
				if rigidHead and p.Name == "Head" then
					if char:FindFirstChild("UpperTorso") then targetName = "UpperTorso"
					elseif char:FindFirstChild("Torso") then targetName = "Torso" end
					keepPos = true
				end
				local real = char:FindFirstChild(targetName)
				if real and real:IsA("BasePart") then
					-- A standard R15 skinned part's CFrame IS its bone frame, so aligning it to the real limb's CFrame fits it exactly; the weld then locks it there.
					if not keepPos then p.CFrame = real.CFrame end
					p.Anchored = false; p.CanCollide = false; p.Massless = true
					local w = Instance.new("Weld")
					w.Name = "LumaMorphWeld"
					w.Part0 = real
					w.Part1 = p
					w.C0 = real.CFrame:Inverse() * p.CFrame
					w.C1 = CFrame.new()
					w.Parent = p
					driven[p] = true
				end
			end
			-- Hide the leftover bone-anchor Parts (la/t/h/...): they only carried the welds we just replaced and would otherwise render as stray blocks around the body.
			for _, p in ipairs(model:GetDescendants()) do
				if p.ClassName == "Part" and not driven[p] then
					pcall(function()
						p.Transparency = 1; p.CanCollide = false; p.Massless = true
					end)
				end
			end
		end

		-- Cosmetic/clothing morphs: place Offset-attachment pieces on the right limb and swap the face decal.
		if not morphWantsHide then
			local headPart = char:FindFirstChild("Head")
			local torsoPart = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") and not driven[p] then
					local off = bindingAttachment(p)
					if off then
						local n = p.Name:lower()
						local isHair = n:find("hair") ~= nil
						-- Prefer the limb named in the part itself (e.g.
						local limb = overrideLimb(p.Name) or limbFromName(char, p.Name)
						if not limb then
							if isHair or n:find("head") or n:find("face")
								or n:find("hat") or n:find("horn") or n:find("mask") then
								limb = headPart
							else
								limb = torsoPart
							end
						end
						if limb then
							-- The Offset attachment marks where the piece meets the limb; align that attachment onto the limb so it sits right.
							p.CFrame = limb.CFrame * off.CFrame:Inverse()
							-- Per-morph vertical correction for pieces that anchor too low.
							local lift = partLift(morphName, p.Name)
							if lift ~= 0 then
								p.CFrame = p.CFrame + Vector3.new(0, lift, 0)
							end
							p.Anchored = false; p.CanCollide = false; p.Massless = true
							local w = Instance.new("Weld")
							w.Name = "LumaMorphWeld"
							w.Part0 = limb
							w.Part1 = p
							w.C0 = limb.CFrame:Inverse() * p.CFrame
							w.C1 = CFrame.new()
							w.Parent = p
							driven[p] = true
							partToLimb[p] = limb
							if isHair then morphHasHair = true end
						end
					end
				end
			end

			-- Face: Deepwoken renders the face as a Decal sitting on the FaceMount mesh -- NOT the block Head, and NOT the mesh's TextureID.
			local faces = model:FindFirstChild("Faces", true)
			local head = char:FindFirstChild("Head")
			if faces and head then
				local srcFace = faces:FindFirstChild("Base") or faces:FindFirstChildWhichIsA("Decal")
				if srcFace and srcFace:IsA("Decal") then
					local faceTex = srcFace.Texture
					-- The face decal lives under the head (usually on FaceMount).
					local faceDecal
					for _, d in ipairs(head:GetDescendants()) do
						if d:IsA("Decal") then
							if d.Name:lower() == "face" then
								faceDecal = d
								break
							elseif not faceDecal then
								faceDecal = d
							end
						end
					end
					if faceDecal then
						if faceDecal:GetAttribute("LumaMorphFace") == nil then
							faceDecal:SetAttribute("LumaMorphFace", faceDecal.Texture)
						end
						faceDecal.Texture = faceTex
						-- Deepwoken layers separate overlay decals for the eyes/brows on top of the base face; the morph face already includes its own eyes, so hide every OTHER face decal/texture on the head so the real eyes don't show through.
						for _, d in ipairs(head:GetDescendants()) do
							if d ~= faceDecal
								and (d:IsA("Decal") or d:IsA("Texture"))
								and not d:GetAttribute("LumaMorphFaceClone")
							then
								if d:GetAttribute("LumaMorphHidden") == nil then
									d:SetAttribute("LumaMorphHidden", d.Transparency)
								end
								d.Transparency = 1
							end
						end
					else
						-- No existing face decal: mount a fresh one on FaceMount's front (a Decal keeps alpha, so it blends instead of boxing solid).
						local mount = head:FindFirstChild("FaceMount") or head
						local nd = srcFace:Clone()
						nd.Name = "LumaMorphFace"
						nd.Face = Enum.NormalId.Front
						nd:SetAttribute("LumaMorphFaceClone", true)
						nd.Parent = mount
					end
				end
			end
		end

		-- Bind each free (non-driven) part to a limb so it sits right and articulates.
		local bound = 0
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and not driven[p] then
				local limb = overrideLimb(p.Name) or limbFromName(char, p.Name)
				if not limb then
					-- Inherit the limb an ancestor part was bound to: a strand parented under a hair clump belongs on the head with it, not wherever nearest-position lands.
					local anc = p.Parent
					while anc and anc ~= model do
						if partToLimb[anc] then limb = partToLimb[anc]; break end
						anc = anc.Parent
					end
				end
				limb = limb or nearestLimb(limbs, p.Position)
				if limb then
					p.Anchored = false
					p.CanCollide = false
					p.Massless = true
					local w = Instance.new("Weld")
					w.Name = "LumaMorphWeld"
					w.Part0 = limb
					w.Part1 = p
					w.C0 = limb.CFrame:Inverse() * p.CFrame
					w.C1 = CFrame.new()
					w.Parent = p
					partToLimb[p] = limb
					bound = bound + 1
				end
			end
		end

		-- Safety net: if every part looked driven, at least pin the anchor to the torso.
		if bound == 0 then
			mAnchor.Anchored = false
			local w = Instance.new("Weld")
			w.Name = "LumaMorphWeld"
			w.Part0 = cAnchor
			w.Part1 = mAnchor
			w.C0 = cAnchor.CFrame:Inverse() * mAnchor.CFrame
			w.Parent = mAnchor
		end

		-- Nothing anchored / colliding.
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.CanCollide = false
			end
		end

		-- Accessories self-weld under the Humanoid.
		for _, acc in ipairs(model:GetDescendants()) do
			if acc:IsA("Accessory") then
				acc:SetAttribute("LumaMorphAccessory", true)
				acc.Parent = char
			end
		end

		-- Turn effects on (they usually ship disabled).
		for _, fx in ipairs(model:GetDescendants()) do
			if fx:IsA("ParticleEmitter") or fx:IsA("Trail") or fx:IsA("Beam")
				or fx:IsA("PointLight") or fx:IsA("SpotLight") or fx:IsA("SurfaceLight") then
				pcall(function() fx.Enabled = true end)
			end
		end

		-- Apply clothing morphs (Shirt / Pants / graphic) straight onto the character.
		local backup = char:FindFirstChild(BACKUP_NAME)
		for _, cl in ipairs(model:GetDescendants()) do
			if cl:IsA("Shirt") or cl:IsA("Pants") or cl:IsA("ShirtGraphic") then
				if not backup then
					backup = Instance.new("Folder")
					backup.Name = BACKUP_NAME
					backup.Parent = char
				end
				local existing = char:FindFirstChildOfClass(cl.ClassName)
				if existing then existing.Parent = backup end
				local clone = cl:Clone()
				clone:SetAttribute("LumaMorphClothing", true)
				clone.Parent = char
				-- The carrier part (e.g.
				local carrier = cl.Parent
				if carrier and carrier:IsA("BasePart") then
					carrier.Transparency = 1
					carrier.CanCollide = false
				end
			end
		end

		-- Hide the player's real hair whenever the morph replaces the body or brings its own hair.
		if morphWantsHide or morphHasHair then
			for _, acc in ipairs(char:GetChildren()) do
				if acc:IsA("Accessory") then
					local handle = acc:FindFirstChild("Handle")
					local isHairAcc = false
					local ok, at = pcall(function() return acc.AccessoryType end)
					if ok and at == Enum.AccessoryType.Hair then isHairAcc = true end
					if handle and handle:FindFirstChild("HairAttachment") then isHairAcc = true end
					if isHairAcc and handle then extraHide[#extraHide + 1] = handle end
				end
			end
		end

		-- Wear-over morph that brings its OWN head: the real Deepwoken head keeps rendering straight through the morph one -- the "two heads" bug.
		if hideBody and not morphWantsHide then
			local morphReplacesHead = false
			for _, p in ipairs(model:GetDescendants()) do
				-- Exact "Head" only: a piece merely CONTAINING "head" is an accessory, not a head replacement -- hiding the real head for those would leave the character headless.
				if p:IsA("BasePart") and p.Name:lower() == "head" then
					morphReplacesHead = true
					break
				end
			end
			if morphReplacesHead then
				local realHead = char:FindFirstChild("Head")
				if realHead then
					extraHide[#extraHide + 1] = realHead
					for _, d in ipairs(realHead:GetChildren()) do
						if d:IsA("Decal") or d:IsA("Texture") then
							extraHide[#extraHide + 1] = d
						end
					end
				end
			end
		end

		-- Hide the real body ONLY for morphs that truly replace it (e.g.
		if hideBody and morphWantsHide and not MORPH_NOHIDE[morphName] then
			startHide(originalBits)
		elseif #extraHide > 0 then
			startHide(extraHide)
		else
			stopHide()
		end

		-- Skin tone: recolor the real body limbs to the morph's skin so exposed arms/legs/hands match instead of showing the player's own pale skin.
		local skin = MORPH_SKIN[(tostring(morphName):gsub("%s*%(%d+%)%s*$", ""))]
		if skin then
			for _, name in ipairs(SKIN_LIMBS) do
				local part = char:FindFirstChild(name)
				if part and part:IsA("BasePart") then
					if part:GetAttribute("LumaMorphSkin") == nil then
						part:SetAttribute("LumaMorphSkin", part.Color)
					end
					part.Color = skin
				end
			end

			-- The FACE mesh isn't in SKIN_LIMBS: recolor it to skin so the face isn't left white, and clear its Deepwoken face TextureID so the old eyes/skin stop bleeding through the morph face's transparent parts.
			local skinHead = char:FindFirstChild("Head")
			local faceMount = skinHead and skinHead:FindFirstChild("FaceMount")
			if faceMount and faceMount:IsA("MeshPart") then
				if faceMount:GetAttribute("LumaMorphSkin") == nil then
					faceMount:SetAttribute("LumaMorphSkin", faceMount.Color)
				end
				faceMount.Color = skin
				if faceMount:GetAttribute("LumaMorphFaceTex") == nil then
					faceMount:SetAttribute("LumaMorphFaceTex", faceMount.TextureID)
				end
				faceMount.TextureID = ""
			end
		end

		-- Corrective lift for driven sub-parts that hang too low.
		local subLift = MORPH_SUBPART_LIFT[base]
		if subLift then
			for _, j in ipairs(model:GetDescendants()) do
				if (j:IsA("Motor6D") or j:IsA("Weld")) and j.Part1 and subLift[j.Part1.Name] then
					j.C0 = CFrame.new(0, subLift[j.Part1.Name], 0) * j.C0
				end
			end
		end

		local holder = char:FindFirstChild(HOLDER_NAME)
		if not holder then
			holder = Instance.new("Folder")
			holder.Name = HOLDER_NAME
			holder.Parent = char
		end
		model.Parent = holder
		return true
	end

	local function loadMorph(category, fileName)
		if not fileName or fileName == "" then
			return Logger.notify("Pick a morph from the dropdown first.")
		end
		if type(readCustomAsset) ~= "function" then
			return Logger.notify("Executor has no getcustomasset — can't load local models.")
		end
		local path = (FOLDERS[category] or FOLDERS.Races) .. "/" .. fileName .. ".rbxm"
		local ok, asset = pcall(readCustomAsset, path)
		if not ok or not asset then
			return Logger.notify("getcustomasset failed: " .. path)
		end
		local ok2, objs = pcall(function() return game:GetObjects(asset) end)
		if not ok2 or type(objs) ~= "table" or not objs[1] then
			return Logger.notify("Failed to deserialize: " .. tostring(objs))
		end
		local model = objs[1]
		if not model:IsA("Model") then
			local m = Instance.new("Model")
			model.Parent = m
			model = m
		end


		-- Force the morph's meshes/textures to download BEFORE we place anything.
		pcall(function()
			local cp = game:GetService("ContentProvider")
			local assets = { model }
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("MeshPart") or d:IsA("SpecialMesh") or d:IsA("Decal") or d:IsA("Texture") then
					assets[#assets + 1] = d
				end
			end
			cp:PreloadAsync(assets)
		end)

		clearMorphs() -- replace any previously applied morph
		local okA, err = applyModel(model, hideBodyEnabled, fileName)
		if okA then
			activeMorph = { kind = "file", category = category, file = fileName }
			saveMorphResume()
		else
			if model then model:Destroy() end
			activeMorph = nil
			saveMorphResume()
			Logger.notify("Apply error: " .. tostring(err))
		end
	end

	local function loadRobloxAvatar(username)
		username = tostring(username or ""):match("^%s*(.-)%s*$")
		local userId = lp.UserId
		if username ~= "" then
			local ok, result = pcall(function()
				return Players:GetUserIdFromNameAsync(username)
			end)
			if not ok then
				return Logger.notify("Could not find Roblox username '" .. username .. "': " .. tostring(result))
			end
			userId = result
		end

		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
		end)
		if not ok or not description then
			return Logger.notify("Could not load Roblox avatar: " .. tostring(description))
		end

		local char = getChar()
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			description:Destroy()
			return Logger.notify("Could not apply Roblox avatar: character has no Humanoid.")
		end

		local modelOk, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(
				description,
				humanoid.RigType,
				Enum.AssetTypeVerification.ClientOnly
			)
		end)
		if not modelOk or not model then
			description:Destroy()
			return Logger.notify("Could not build Roblox avatar morph: " .. tostring(model))
		end

		local appearance = {}
		local avatarAccessories = {}
		local layeredClothingNames = {}
		local faceTexture
		local function captureAvatarAccessory(item, sourceModel)
			local accessory = item:Clone()
			if item:FindFirstChildWhichIsA("WrapLayer", true) then
				layeredClothingNames[item.Name] = true
				if humanoid.RigType == Enum.HumanoidRigType.R6 then
					accessory:SetAttribute("LumaMorphRigidLayered", true)
				end
			end
			local handle = item:FindFirstChild("Handle")
			if handle then
				local sourcePart
				local sourceWeld = handle:FindFirstChild("AccessoryWeld")
				if sourceWeld and (sourceWeld:IsA("JointInstance") or sourceWeld:IsA("WeldConstraint")) then
					local part0 = sourceWeld.Part0
					local part1 = sourceWeld.Part1
					if part0 == handle then
						sourcePart = part1
					elseif part1 == handle then
						sourcePart = part0
					end
					if not sourcePart or not sourcePart:IsDescendantOf(sourceModel) then
						sourcePart = nil
					end
				end
				if not sourcePart then
					for _, handleAttachment in ipairs(handle:GetChildren()) do
						if handleAttachment:IsA("Attachment") then
							for _, bodyPart in ipairs(sourceModel:GetChildren()) do
								if bodyPart:IsA("BasePart") then
									local bodyAttachment = bodyPart:FindFirstChild(handleAttachment.Name)
									if bodyAttachment and bodyAttachment:IsA("Attachment") then
										sourcePart = bodyPart
										break
									end
								end
							end
						end
						if sourcePart then
							break
						end
					end
				end
				if sourcePart then
					accessory:SetAttribute("LumaMorphSourcePart", sourcePart.Name)
					local offset = Instance.new("CFrameValue")
					offset.Name = "LumaMorphSourceOffset"
					offset.Value = sourcePart.CFrame:ToObjectSpace(handle.CFrame)
					offset.Parent = accessory
					local sourceSize = Instance.new("Vector3Value")
					sourceSize.Name = "LumaMorphSourcePartSize"
					sourceSize.Value = sourcePart.Size
					sourceSize.Parent = accessory
				end
			end
			if accessory:GetAttribute("LumaMorphRigidLayered") then
				for _, descendant in ipairs(accessory:GetDescendants()) do
					if descendant:IsA("WrapLayer") then
						descendant:Destroy()
					end
				end
			end
			appearance[#appearance + 1] = accessory
			avatarAccessories[accessory] = true
		end
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("Accessory") then
				captureAvatarAccessory(item, model)
			elseif item.Parent == model and (item:IsA("Shirt") or item:IsA("Pants")
				or item:IsA("ShirtGraphic") or item:IsA("BodyColors")
				or item:IsA("CharacterMesh"))
			then
				appearance[#appearance + 1] = item:Clone()
			end
		end
		local layeredClothingError
		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			local layeredModelOk, layeredModel = pcall(function()
				return Players:CreateHumanoidModelFromDescription(
					description,
					Enum.HumanoidRigType.R15,
					Enum.AssetTypeVerification.ClientOnly
				)
			end)
			if layeredModelOk and layeredModel then
				for _, item in ipairs(layeredModel:GetDescendants()) do
					if item:IsA("Accessory") and item:FindFirstChildWhichIsA("WrapLayer", true)
						and not layeredClothingNames[item.Name]
					then
						captureAvatarAccessory(item, layeredModel)
					end
				end
				layeredModel:Destroy()
			else
				layeredClothingError = layeredModel
			end
		end
		local sourceHead = model:FindFirstChild("Head")
		local avatarHead = sourceHead and sourceHead:Clone()
		if sourceHead then
			for _, item in ipairs(sourceHead:GetDescendants()) do
				if item:IsA("Decal") and item.Name:lower() == "face" then
					faceTexture = item.Texture
					break
				end
			end
		end
		if not faceTexture and description.Face ~= 0 then
			faceTexture = "rbxthumb://type=Asset&id=" .. tostring(description.Face) .. "&w=420&h=420"
		end
		if avatarHead then
			avatarHead.Name = "LumaMorphAvatarHead"
			avatarHead:SetAttribute("LumaMorphAvatarHead", true)
			for _, item in ipairs(avatarHead:GetDescendants()) do
				if item:IsA("Script") or item:IsA("LocalScript") then
					item:Destroy()
				end
			end
			if faceTexture then
				local hasFace = false
				for _, item in ipairs(avatarHead:GetDescendants()) do
					if item:IsA("Decal") and item.Name:lower() == "face" then
						hasFace = true
						break
					end
				end
				if not hasFace then
					local face = Instance.new("Decal")
					face.Name = "face"
					face.Face = Enum.NormalId.Front
					face.Texture = faceTexture
					face.Parent = avatarHead:FindFirstChild("FaceMount") or avatarHead
				end
			end
		end
		local meshError
		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			local meshOk, meshModel = pcall(function()
				return Players:CreateHumanoidModelFromDescription(
					description,
					Enum.HumanoidRigType.R6,
					Enum.AssetTypeVerification.ClientOnly
				)
			end)
			if meshOk and meshModel then
				for _, item in ipairs(meshModel:GetChildren()) do
					if item:IsA("CharacterMesh") then
						appearance[#appearance + 1] = item:Clone()
					end
				end
				meshModel:Destroy()
			else
				meshError = meshModel
			end
		end
		model:Destroy()
		description:Destroy()

		char = getChar()
		humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not humanoid then
			if avatarHead then avatarHead:Destroy() end
			for _, item in ipairs(appearance) do item:Destroy() end
			return Logger.notify("Could not apply Roblox avatar: character changed while loading.")
		end

		clearMorphs()
		char = getChar()
		humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not humanoid then
			if avatarHead then avatarHead:Destroy() end
			for _, item in ipairs(appearance) do item:Destroy() end
			return Logger.notify("Could not apply Roblox avatar: character changed while clearing the previous morph.")
		end
		local backup
		local function findBodyPart(name)
			local part = char:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				return part
			end
			local aliases = {
				Head = {},
				Torso = { "UpperTorso", "LowerTorso" },
				UpperTorso = { "Torso", "LowerTorso" },
				LowerTorso = { "Torso", "UpperTorso" },
				["Left Arm"] = { "LeftArm", "LeftUpperArm", "LeftLowerArm", "LeftHand" },
				LeftArm = { "Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand" },
				LeftUpperArm = { "Left Arm", "LeftArm", "LeftLowerArm", "LeftHand" },
				LeftLowerArm = { "Left Arm", "LeftArm", "LeftUpperArm", "LeftHand" },
				LeftHand = { "Left Arm", "LeftArm", "LeftLowerArm", "LeftUpperArm" },
				["Right Arm"] = { "RightArm", "RightUpperArm", "RightLowerArm", "RightHand" },
				RightArm = { "Right Arm", "RightUpperArm", "RightLowerArm", "RightHand" },
				RightUpperArm = { "Right Arm", "RightArm", "RightLowerArm", "RightHand" },
				RightLowerArm = { "Right Arm", "RightArm", "RightUpperArm", "RightHand" },
				RightHand = { "Right Arm", "RightArm", "RightUpperArm", "RightLowerArm" },
				["Left Leg"] = { "LeftLeg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
				LeftLeg = { "Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
				LeftUpperLeg = { "Left Leg", "LeftLeg", "LeftLowerLeg", "LeftFoot" },
				LeftLowerLeg = { "Left Leg", "LeftLeg", "LeftUpperLeg", "LeftFoot" },
				LeftFoot = { "Left Leg", "LeftLeg", "LeftLowerLeg", "LeftUpperLeg" },
				["Right Leg"] = { "RightLeg", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
				RightLeg = { "Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
				RightUpperLeg = { "Right Leg", "RightLeg", "RightLowerLeg", "RightFoot" },
				RightLowerLeg = { "Right Leg", "RightLeg", "RightUpperLeg", "RightFoot" },
				RightFoot = { "Right Leg", "RightLeg", "RightLowerLeg", "RightUpperLeg" },
			}
			for _, alias in ipairs(aliases[name] or {}) do
				part = char:FindFirstChild(alias)
				if part and part:IsA("BasePart") then
					return part
				end
			end
		end
		local function attachAvatarAccessory(accessory)
			local handle = accessory:FindFirstChild("Handle")
			if not handle or not handle:IsA("BasePart") then
				return false, "missing Handle"
			end
			handle.Anchored = false
			handle.CanCollide = false
			handle.CanTouch = false
			handle.CanQuery = false
			handle.Massless = true
			accessory:SetAttribute("LumaMorphAccessory", true)
			humanoid:AddAccessory(accessory)
			local rigidLayered = accessory:GetAttribute("LumaMorphRigidLayered") == true

			local handleAttachments = {}
			for _, child in ipairs(handle:GetChildren()) do
				if child:IsA("Attachment") then
					handleAttachments[#handleAttachments + 1] = child
				end
			end

			local targetPart
			local targetAttachment
			local targetHandleAttachment
			if not rigidLayered then
				for _, bodyPart in ipairs(char:GetChildren()) do
					if bodyPart:IsA("BasePart") then
						for _, handleAttachment in ipairs(handleAttachments) do
							local attachment = bodyPart:FindFirstChild(handleAttachment.Name)
							if attachment and attachment:IsA("Attachment") then
								targetPart = bodyPart
								targetAttachment = attachment
								targetHandleAttachment = handleAttachment
								break
							end
						end
						if targetPart then
							break
						end
					end
				end
			end

			local weld = handle:FindFirstChild("AccessoryWeld")
			if weld and (weld:IsA("Weld") or weld:IsA("WeldConstraint")) then
				if weld.Part0 == handle or weld.Part1 == handle then
					weld:Destroy()
				end
			end
			if targetPart and targetAttachment then
				handle.CFrame = targetAttachment.WorldCFrame * targetHandleAttachment.CFrame:Inverse()
				local accessoryWeld = Instance.new("Weld")
				accessoryWeld.Name = "AccessoryWeld"
				accessoryWeld.Part0 = targetPart
				accessoryWeld.Part1 = handle
				accessoryWeld.C0 = targetAttachment.CFrame
				accessoryWeld.C1 = targetHandleAttachment.CFrame
				accessoryWeld.Parent = handle
				return true
			end

			local sourcePartName = accessory:GetAttribute("LumaMorphSourcePart")
			local fallbackPart = sourcePartName and findBodyPart(sourcePartName)
			local okType, accessoryType = pcall(function()
				return accessory.AccessoryType
			end)
			if not fallbackPart and okType then
				local fallbackName
				if accessoryType == Enum.AccessoryType.Hair or accessoryType == Enum.AccessoryType.Hat
					or accessoryType == Enum.AccessoryType.Face or accessoryType == Enum.AccessoryType.Eyebrow
					or accessoryType == Enum.AccessoryType.Eyelash
				then
					fallbackName = "Head"
				elseif accessoryType == Enum.AccessoryType.Neck or accessoryType == Enum.AccessoryType.Front
					or accessoryType == Enum.AccessoryType.Back or accessoryType == Enum.AccessoryType.Shoulder
				then
					fallbackName = "Torso"
				elseif accessoryType == Enum.AccessoryType.Waist then
					fallbackName = "LowerTorso"
				elseif accessoryType == Enum.AccessoryType.LeftShoe then
					fallbackName = "LeftFoot"
				elseif accessoryType == Enum.AccessoryType.RightShoe then
					fallbackName = "RightFoot"
				else
					fallbackName = "Torso"
				end
				fallbackPart = fallbackName and findBodyPart(fallbackName)
			end
			if not fallbackPart then
				return false, "no matching body attachment or fallback body part"
			end

			local sourceOffset = accessory:FindFirstChild("LumaMorphSourceOffset")
			local offset = sourceOffset and sourceOffset:IsA("CFrameValue") and sourceOffset.Value
			local weldOffset = offset ~= nil
			if weldOffset and rigidLayered then
				local sourceSize = accessory:FindFirstChild("LumaMorphSourcePartSize")
				if sourceSize and sourceSize:IsA("Vector3Value") then
					local originalSize = sourceSize.Value
					local scale = Vector3.new(
						originalSize.X > 0 and fallbackPart.Size.X / originalSize.X or 1,
						originalSize.Y > 0 and fallbackPart.Size.Y / originalSize.Y or 1,
						originalSize.Z > 0 and fallbackPart.Size.Z / originalSize.Z or 1
					)
					local position = offset.Position
					offset = CFrame.new(
						position.X * scale.X,
						position.Y * scale.Y,
						position.Z * scale.Z
					) * offset.Rotation
				end
			end
			if not offset then
				if okType and accessoryType == Enum.AccessoryType.Face then
					offset = CFrame.new(0, 0, -fallbackPart.Size.Z / 2)
				elseif okType and accessoryType == Enum.AccessoryType.Neck then
					offset = CFrame.new(0, -fallbackPart.Size.Y / 2, 0)
				else
					offset = CFrame.new(0, fallbackPart.Size.Y / 2, 0)
				end
			end
			local handleAttachment = handleAttachments[1]
			local weldC1 = weldOffset and CFrame.new()
				or (handleAttachment and handleAttachment.CFrame or CFrame.new())
			handle.CFrame = fallbackPart.CFrame * offset * weldC1:Inverse()
			local accessoryWeld = Instance.new("Weld")
			accessoryWeld.Name = "AccessoryWeld"
			accessoryWeld.Part0 = fallbackPart
			accessoryWeld.Part1 = handle
			accessoryWeld.C0 = offset
			accessoryWeld.C1 = weldC1
			accessoryWeld.Parent = handle
			return true
		end
		local function applyAvatarHead()
			if not avatarHead then
				return false, "avatar has no generated Head"
			end
			local targetHead = char:FindFirstChild("Head")
			if not targetHead or not targetHead:IsA("BasePart") then
				return false, "character has no Head part"
			end
			avatarHead.CFrame = targetHead.CFrame
			avatarHead.Anchored = false
			avatarHead.CanCollide = false
			avatarHead.Massless = true
			local holder = char:FindFirstChild(HOLDER_NAME)
			if not holder then
				holder = Instance.new("Folder")
				holder.Name = HOLDER_NAME
				holder.Parent = char
			end
			avatarHead.Parent = holder
			local weld = Instance.new("Weld")
			weld.Name = "LumaMorphAvatarHeadWeld"
			weld.Part0 = targetHead
			weld.Part1 = avatarHead
			weld.Parent = avatarHead

			local hideParts = {}
			local function addToHide(part)
				if part and part:IsA("BasePart") then
					hideParts[#hideParts + 1] = part
				elseif part and (part:IsA("Decal") or part:IsA("Texture")) then
					if part:GetAttribute("LumaMorphHidden") == nil then
						part:SetAttribute("LumaMorphHidden", part.Transparency)
					end
					hideParts[#hideParts + 1] = part
				end
			end
			if hideHeadFaceEnabled then
				for _, descendant in ipairs(char:GetDescendants()) do
					if descendant:IsDescendantOf(holder) then
						continue
					end
					if descendant:IsA("BasePart") and descendant.Name:lower() == "head" then
						addToHide(descendant)
						for _, headDescendant in ipairs(descendant:GetDescendants()) do
							if headDescendant:IsA("BasePart")
								or headDescendant:IsA("Decal")
								or headDescendant:IsA("Texture")
							then
								addToHide(headDescendant)
							end
						end
					elseif (descendant:IsA("Decal") or descendant:IsA("Texture"))
						and descendant.Name:lower() == "face"
					then
						addToHide(descendant)
					end
				end
			end
			for _, descendant in ipairs(char:GetDescendants()) do
				if descendant:IsA("BasePart")
					and not descendant:IsDescendantOf(holder)
					and not descendant:GetAttribute("LumaMorphAccessory")
				then
					local isHair = descendant.Name:lower():find("hair", 1, true) ~= nil
					local ancestor = descendant
					local isRaceOrOathOrnament = false
					while ancestor and ancestor ~= char do
						local ancestorName = ancestor.Name:lower()
						if ancestorName:find("oath", 1, true)
							or ancestorName:find("race", 1, true)
							or ancestorName:find("ornament", 1, true)
						then
							isRaceOrOathOrnament = true
							break
						end
						ancestor = ancestor.Parent
					end
					if isHair or isRaceOrOathOrnament then
						addToHide(descendant)
					end
				end
			end
			for _, accessory in ipairs(char:GetChildren()) do
				if accessory:IsA("Accessory") and not accessory:GetAttribute("LumaMorphAccessory") then
					local handle = accessory:FindFirstChild("Handle")
					local isHair = accessory.Name:lower():find("hair", 1, true) ~= nil
					if handle then
						local okType, accessoryType = pcall(function()
							return accessory.AccessoryType
						end)
						isHair = isHair or (okType and accessoryType == Enum.AccessoryType.Hair)
							or handle:FindFirstChild("HairAttachment") ~= nil
						if isHair then
							addToHide(handle)
						end
					end
				end
			end
			startHide(hideParts)
			return true
		end
		local okApply, applyError = pcall(function()
			for _, item in ipairs(appearance) do
				if avatarAccessories[item] then
					local attached, attachError = attachAvatarAccessory(item)
					if not attached then
						Logger.notify("Could not attach avatar accessory '" .. item.Name .. "': " .. attachError)
						item:Destroy()
					end
				elseif item:IsA("BodyColors") or item:IsA("CharacterMesh") then
					if item:IsA("CharacterMesh") and humanoid.RigType ~= Enum.HumanoidRigType.R6 then
						item:Destroy()
					else
						if item:IsA("BodyColors") then
							for _, name in ipairs(LIMB_NAMES) do
								local part = char:FindFirstChild(name)
								if part and part:IsA("BasePart")
									and part:GetAttribute(AVATAR_COLOR_ATTRIBUTE) == nil
								then
									part:SetAttribute(AVATAR_COLOR_ATTRIBUTE, part.Color)
								end
							end
						end
						if not backup then
							backup = Instance.new("Folder")
							backup.Name = BACKUP_NAME
							backup.Parent = char
						end
						for _, existing in ipairs(char:GetChildren()) do
							if existing.ClassName == item.ClassName and not existing:GetAttribute("LumaMorphBodyColors")
								and not existing:GetAttribute("LumaMorphCharacterMesh")
							then
								existing.Parent = backup
							end
						end
						item:SetAttribute(
							item:IsA("BodyColors") and "LumaMorphBodyColors" or "LumaMorphCharacterMesh",
							true
						)
						item.Parent = char
					end
				elseif item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
					if not backup then
						backup = Instance.new("Folder")
						backup.Name = BACKUP_NAME
						backup.Parent = char
					end
					local existing = char:FindFirstChildOfClass(item.ClassName)
					if existing then existing.Parent = backup end
					item:SetAttribute("LumaMorphClothing", true)
					item.Parent = char
				end
			end

			local headApplied, headError = applyAvatarHead()
			if not headApplied then
				error(headError)
			end
		end)
		for _, item in ipairs(appearance) do
			if item.Parent == nil then
				item:Destroy()
			end
		end
		if not okApply then
			if avatarHead and avatarHead.Parent == nil then
				avatarHead:Destroy()
			end
			clearMorphs()
			activeMorph = nil
			saveMorphResume()
			return Logger.notify("Could not apply Roblox avatar appearance: " .. tostring(applyError))
		end

		activeMorph = { kind = "avatar", username = username }
		if username ~= "" then
			PersistentData.set("morphUsername", username)
		end
		saveMorphResume()
		if meshError then
			Logger.notify("Loaded avatar appearance, but R6 body meshes failed: " .. tostring(meshError))
		end
		if layeredClothingError then
			Logger.notify("Loaded avatar, but R15 layered clothing could not be retrieved: "
				.. tostring(layeredClothingError))
		end
	end

	local function applyActiveMorph()
		if not activeMorph then
			return
		end
		if activeMorph.kind == "file" then
			loadMorph(activeMorph.category, activeMorph.file)
		elseif activeMorph.kind == "avatar" then
			loadRobloxAvatar(activeMorph.username)
		end
	end

	-- ===== UI =====
	local catDropdown = groupbox:AddDropdown("LumaMorph_Category", {
		Text = "Category",
		Values = { "Races", "Ornaments" },
		AllowNull = false,
		Default = "Races",
	})

	local morphDropdown = groupbox:AddDropdown("LumaMorph_File", {
		Text = "Morph",
		Values = listMorphs(FOLDERS[currentCategory]),
		AllowNull = true,
		Default = nil,
	})

	catDropdown:OnChanged(function(v)
		currentCategory = v
		morphDropdown:SetValues(listMorphs(FOLDERS[v]))
		morphDropdown:Display()
	end)

	morphDropdown:OnChanged(function(v)
		currentFile = v
	end)

	groupbox:AddButton("Load Morph", function()
		loadMorph(currentCategory, currentFile)
	end)

	groupbox:AddButton("Clear Morph", function()
		clearMorphs()
		activeMorph = nil
		saveMorphResume()
		Logger.notify("Cleared applied morphs.")
	end)

	groupbox:AddButton("Refresh List", function()
		morphDropdown:SetValues(listMorphs(FOLDERS[currentCategory]))
		morphDropdown:Display()
	end)

	hideToggle = groupbox:AddToggle("LumaMorph_HideBody", {
		Text = "Hide real body (for HideBody morphs)",
		Default = true,
	})
	hideToggle:OnChanged(function(v)
		hideBodyEnabled = v
	end)

	local hideHeadFaceToggleInitialized = false
	local hideHeadFaceToggle = groupbox:AddToggle("LumaMorph_HideHeadFace", {
		Text = "Hide original face/head",
		Default = true,
	})
	hideHeadFaceToggle:OnChanged(function(v)
		local changed = hideHeadFaceEnabled ~= v
		hideHeadFaceEnabled = v
		if hideHeadFaceToggleInitialized and changed
			and activeMorph and activeMorph.kind == "avatar"
		then
			loadRobloxAvatar(activeMorph.username)
		end
	end)
	hideHeadFaceToggleInitialized = true

	local reapplyToggle = groupbox:AddToggle("LumaMorph_Reapply", {
		Text = "Reapply on respawn",
		Default = false,
	})
	reapplyToggle:OnChanged(function(v)
		reapplyEnabled = v
	end)

	local serverHopToggle = groupbox:AddToggle("LumaMorph_ServerHop", {
		Text = "Reapply morph after server hop",
		Default = serverHopEnabled,
	})
	serverHopToggle:OnChanged(function(v)
		serverHopEnabled = v
		saveMorphResume()
	end)

	local savedUsername = PersistentData.get("morphUsername")
	if type(activeMorph) == "table" and activeMorph.kind == "avatar"
		and type(activeMorph.username) == "string" and activeMorph.username ~= ""
	then
		savedUsername = activeMorph.username
	end
	local usernameInput = groupbox:AddInput("LumaMorph_Username", {
		Text = "Roblox username (blank = your avatar)",
		Placeholder = "Username or blank for your avatar.",
		Default = type(savedUsername) == "string" and savedUsername or "",
	})
	groupbox:AddButton("Apply Roblox Character Morph", function()
		loadRobloxAvatar(usernameInput.Value)
	end)

	lp.CharacterAdded:Connect(function()
		if (reapplyEnabled or serverHopEnabled) and activeMorph then
			task.wait(1.5)
			if (reapplyEnabled or serverHopEnabled) and activeMorph then
				applyActiveMorph()
			end
		end
	end)

	if serverHopEnabled and activeMorph then
		task.spawn(function()
			local char = lp.Character or lp.CharacterAdded:Wait()
			if char then
				char:WaitForChild("HumanoidRootPart", 10)
				task.wait(1.5)
				if serverHopEnabled then
					applyActiveMorph()
				end
			end
		end)
	end
end

---@param window table
---@param groupbox table
function VisualsTab.initProximitySection(groupbox)
	-- On-screen list of nearby players (name + distance), ported from project-rain's proximity list.
	-- NOTE: distinct flags from GameTab's "PlayerProximity" NOTIFICATION feature -- reusing those collided.
	groupbox:AddToggle("ProximityList", {
		Text = "Player Proximity List",
		Tooltip = "Show an on-screen list of nearby players with their distance (updates live).",
		Default = false,
	})

	local depBox = groupbox:AddDependencyBox()

	depBox:AddSlider("ProximityListRange", {
		Text = "Range",
		Min = 100,
		Max = 5000,
		Default = 1000,
		Rounding = 0,
		Suffix = " studs",
	})

	depBox:AddToggle("ProximityListNotify", {
		Text = "Notify On Enter / Leave",
		Default = true,
	})

	depBox:SetupDependencies({
		{ Toggles.ProximityList, true },
	})
end

---@param groupbox table
function VisualsTab.initTargetHUDSection(groupbox)
	groupbox:AddToggle("TargetHUD", {
		Text = "Target HUD",
		Tooltip = "Show a draggable panel with the current target's name, level, distance, health, posture, blood and sanity.",
		Default = false,
	})

	groupbox:AddLabel("Drag the panel to reposition it.")
end

function VisualsTab.init(window)
	local tab = window:AddTab("ESP", "Visuals", Icons.Visuals)

	VisualsTab.initESPCustomization(tab:AddDynamicGroupbox("ESP Customization"))
	VisualsTab.initESPOptimizations(tab:AddDynamicGroupbox("ESP Optimizations"))
	VisualsTab.initProximitySection(tab:AddDynamicGroupbox("Player Proximity"))
	VisualsTab.initTargetHUDSection(tab:AddDynamicGroupbox("Target HUD"))

	VisualsTab.addPlayerESP(
		VisualsTab.addEntityESP(VisualsTab.initBaseESPSection("Player", tab:AddDynamicGroupbox("Player ESP")))
	)

	VisualsTab.addFilterESP(
		VisualsTab.addEntityESP(VisualsTab.initBaseESPSection("Mob", tab:AddDynamicGroupbox("Mob ESP")))
	)

	VisualsTab.initBaseESPSection("NPC", tab:AddDynamicGroupbox("NPC ESP"))
	VisualsTab.addChestESP(VisualsTab.initBaseESPSection("Chest", tab:AddDynamicGroupbox("Chest ESP")))
	VisualsTab.initBaseESPSection("BagDrop", tab:AddDynamicGroupbox("Bag ESP"))
	VisualsTab.addFilterESP(VisualsTab.initBaseESPSection("AreaMarker", tab:AddDynamicGroupbox("Area Marker ESP")))
	VisualsTab.initBaseESPSection("VOIBoundaryESP", tab:AddDynamicGroupbox("VOI Boundary ESP"))
	VisualsTab.initBaseESPSection("VOIWeaponESP", tab:AddDynamicGroupbox("VOI Weapon ESP"))
	VisualsTab.initBaseESPSection("ShopESP", tab:AddDynamicGroupbox("Shop ESP"))
	VisualsTab.initBaseESPSection("JobBoard", tab:AddDynamicGroupbox("Job Board ESP"))
	VisualsTab.initBaseESPSection("Artifact", tab:AddDynamicGroupbox("Artifact ESP"))
	VisualsTab.initBaseESPSection("WindrunnerOrb", tab:AddDynamicGroupbox("Windrunner Orb ESP"))
	VisualsTab.initBaseESPSection("Whirlpool", tab:AddDynamicGroupbox("Whirlpool ESP"))
	VisualsTab.initBaseESPSection("ExplosiveBarrel", tab:AddDynamicGroupbox("Explosive Barrel ESP"))
	VisualsTab.initBaseESPSection("MinistryCacheIndicator", tab:AddDynamicGroupbox("Ministry Cache ESP"))
	VisualsTab.initBaseESPSection("OwlFeathers", tab:AddDynamicGroupbox("Owl Feathers ESP"))
	VisualsTab.initBaseESPSection("GuildDoor", tab:AddDynamicGroupbox("Guild Door ESP"))
	VisualsTab.initBaseESPSection("GuildBanner", tab:AddDynamicGroupbox("Guild Banner ESP"))
	VisualsTab.addObeliskESP(VisualsTab.initBaseESPSection("Obelisk", tab:AddDynamicGroupbox("Obelisk ESP")))
	VisualsTab.addBoneAltarESP(VisualsTab.initBaseESPSection("BoneAltar", tab:AddDynamicGroupbox("Bone Altar ESP")))
	VisualsTab.addFilterESP(VisualsTab.initBaseESPSection("Ingredient", tab:AddDynamicGroupbox("Ingredient ESP")))
	VisualsTab.initBaseESPSection("BoneSpear", tab:AddDynamicGroupbox("Bone Spear ESP"))
	VisualsTab.initBaseESPSection("ArmorBrick", tab:AddDynamicGroupbox("Armor Brick ESP"))
	VisualsTab.initBaseESPSection("BellMeteor", tab:AddDynamicGroupbox("Bell Meteor ESP"))
	VisualsTab.initBaseESPSection("RareObelisk", tab:AddDynamicGroupbox("Rare Obelisk ESP"))
	VisualsTab.initBaseESPSection("HealBrick", tab:AddDynamicGroupbox("Heal Brick ESP"))
	VisualsTab.initBaseESPSection("MantraObelisk", tab:AddDynamicGroupbox("Mantra Obelisk ESP"))
	VisualsTab.initBaseESPSection("BRWeapon", tab:AddDynamicGroupbox("BR Weapon ESP"))
	VisualsTab.initBaseESPSection("BellKey", tab:AddDynamicGroupbox("Bell Key ESP"))
end

return VisualsTab
