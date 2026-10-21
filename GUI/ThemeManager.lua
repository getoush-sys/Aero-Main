-- ThemeManager for the YSL swap: real theme picker using YSL's theme palettes.
return LPH_NO_VIRTUALIZE(function()
local ThemeManager = {}
local themes = {
	Nord = {
		FontColor = Color3.fromHex("e5e9f0"),
		MainColor = Color3.fromHex("2e3440"),
		AccentColor = Color3.fromHex("88c0d0"),
		BackgroundColor = Color3.fromHex("242933"),
		OutlineColor = Color3.fromHex("3b4252"),
	},
	Forest = {
		FontColor = Color3.fromHex("e8f5e9"),
		MainColor = Color3.fromHex("1b3124"),
		AccentColor = Color3.fromHex("66bb6a"),
		BackgroundColor = Color3.fromHex("15261c"),
		OutlineColor = Color3.fromHex("294334"),
	},
	Mint = {
		FontColor = Color3.fromHex("ffffff"),
		MainColor = Color3.fromHex("242424"),
		AccentColor = Color3.fromHex("3db488"),
		BackgroundColor = Color3.fromHex("1c1c1c"),
		OutlineColor = Color3.fromHex("373737"),
	},
	Transparent = {
		FontColor = Color3.fromHex("f1f5f9"),
		MainColor = Color3.fromHex("24313a"),
		AccentColor = Color3.fromHex("3db488"),
		BackgroundColor = Color3.fromHex("172129"),
		OutlineColor = Color3.fromHex("3b5964"),
	},
	Dracula = {
		FontColor = Color3.fromHex("ffffff"),
		MainColor = Color3.fromHex("232533"),
		AccentColor = Color3.fromHex("6271a5"),
		BackgroundColor = Color3.fromHex("1b1c27"),
		OutlineColor = Color3.fromHex("7c82a7"),
	},
	Midnight = {
		FontColor = Color3.fromHex("f5f7ff"),
		MainColor = Color3.fromHex("151826"),
		AccentColor = Color3.fromHex("4f7dff"),
		BackgroundColor = Color3.fromHex("10121b"),
		OutlineColor = Color3.fromHex("272c3f"),
	},
	Aero = {
		FontColor = Color3.fromHex("d7dff2"),
		MainColor = Color3.fromHex("171a2a"),
		AccentColor = Color3.fromHex("7896d4"),
		BackgroundColor = Color3.fromHex("0c0e18"),
		OutlineColor = Color3.fromHex("303b5e"),
	},
	Iceberg = {
		FontColor = Color3.fromHex("e0f4ff"),
		MainColor = Color3.fromHex("1f2933"),
		AccentColor = Color3.fromHex("5bc0eb"),
		BackgroundColor = Color3.fromHex("151a23"),
		OutlineColor = Color3.fromHex("324154"),
	},
	Monokai = {
		FontColor = Color3.fromHex("f8f8f2"),
		MainColor = Color3.fromHex("272822"),
		AccentColor = Color3.fromHex("a6e22e"),
		BackgroundColor = Color3.fromHex("1e1f1c"),
		OutlineColor = Color3.fromHex("49483e"),
	},
	Ocean = {
		FontColor = Color3.fromHex("e2f3f8"),
		MainColor = Color3.fromHex("173744"),
		AccentColor = Color3.fromHex("36c2c9"),
		BackgroundColor = Color3.fromHex("0d232c"),
		OutlineColor = Color3.fromHex("2a5663"),
	},
	Terminal = {
		FontColor = Color3.fromHex("d6f5d6"),
		MainColor = Color3.fromHex("13271a"),
		AccentColor = Color3.fromHex("78d882"),
		BackgroundColor = Color3.fromHex("0b180f"),
		OutlineColor = Color3.fromHex("31523a"),
	},
	["Solarized Light"] = {
		FontColor = Color3.fromHex("586e75"),
		MainColor = Color3.fromHex("eee8d5"),
		AccentColor = Color3.fromHex("268bd2"),
		BackgroundColor = Color3.fromHex("fdf6e3"),
		OutlineColor = Color3.fromHex("93a1a1"),
	},
	Ruby = {
		FontColor = Color3.fromHex("ffebf0"),
		MainColor = Color3.fromHex("321c28"),
		AccentColor = Color3.fromHex("f05a79"),
		BackgroundColor = Color3.fromHex("23131c"),
		OutlineColor = Color3.fromHex("633348"),
	},
	Sunset = {
		FontColor = Color3.fromHex("fff1e6"),
		MainColor = Color3.fromHex("38243d"),
		AccentColor = Color3.fromHex("ff8a5b"),
		BackgroundColor = Color3.fromHex("24182e"),
		OutlineColor = Color3.fromHex("70445d"),
	},
	Amethyst = {
		FontColor = Color3.fromHex("f4edff"),
		MainColor = Color3.fromHex("282039"),
		AccentColor = Color3.fromHex("b58cff"),
		BackgroundColor = Color3.fromHex("1b1628"),
		OutlineColor = Color3.fromHex("51406c"),
	},
	["Cherry Blossom"] = {
		FontColor = Color3.fromHex("fff0f5"),
		MainColor = Color3.fromHex("382632"),
		AccentColor = Color3.fromHex("ff8fb1"),
		BackgroundColor = Color3.fromHex("261a24"),
		OutlineColor = Color3.fromHex("70485d"),
	},
	Ember = {
		FontColor = Color3.fromHex("fff1dc"),
		MainColor = Color3.fromHex("38251e"),
		AccentColor = Color3.fromHex("ff7138"),
		BackgroundColor = Color3.fromHex("241813"),
		OutlineColor = Color3.fromHex("75432e"),
	},
	Sapphire = {
		FontColor = Color3.fromHex("e9f2ff"),
		MainColor = Color3.fromHex("1d2b43"),
		AccentColor = Color3.fromHex("5b9dff"),
		BackgroundColor = Color3.fromHex("121b2c"),
		OutlineColor = Color3.fromHex("354f75"),
	},
	["Lavender Mist"] = {
		FontColor = Color3.fromHex("f3f0ff"),
		MainColor = Color3.fromHex("29283d"),
		AccentColor = Color3.fromHex("a89aff"),
		BackgroundColor = Color3.fromHex("1b1a2c"),
		OutlineColor = Color3.fromHex("4b486f"),
	},
	["Golden Hour"] = {
		FontColor = Color3.fromHex("fff6df"),
		MainColor = Color3.fromHex("39301f"),
		AccentColor = Color3.fromHex("f2c14e"),
		BackgroundColor = Color3.fromHex("241e14"),
		OutlineColor = Color3.fromHex("75613b"),
	},
	Crimson = {
		FontColor = Color3.fromHex("ffe9ed"),
		MainColor = Color3.fromHex("351c25"),
		AccentColor = Color3.fromHex("f0445e"),
		BackgroundColor = Color3.fromHex("21131a"),
		OutlineColor = Color3.fromHex("6b3443"),
	},
	["Rose Quartz"] = {
		FontColor = Color3.fromHex("fff2f6"),
		MainColor = Color3.fromHex("382b37"),
		AccentColor = Color3.fromHex("e89bb9"),
		BackgroundColor = Color3.fromHex("251d28"),
		OutlineColor = Color3.fromHex("715268"),
	},
	["Coral Reef"] = {
		FontColor = Color3.fromHex("eafffb"),
		MainColor = Color3.fromHex("1e3537"),
		AccentColor = Color3.fromHex("39d6c5"),
		BackgroundColor = Color3.fromHex("122527"),
		OutlineColor = Color3.fromHex("397a78"),
	},
	Tangerine = {
		FontColor = Color3.fromHex("fff4e5"),
		MainColor = Color3.fromHex("3d2b20"),
		AccentColor = Color3.fromHex("ff9c38"),
		BackgroundColor = Color3.fromHex("281b14"),
		OutlineColor = Color3.fromHex("805333"),
	},
	Lemon = {
		FontColor = Color3.fromHex("fffde6"),
		MainColor = Color3.fromHex("36351e"),
		AccentColor = Color3.fromHex("e6dc45"),
		BackgroundColor = Color3.fromHex("242311"),
		OutlineColor = Color3.fromHex("77733a"),
	},
	Jade = {
		FontColor = Color3.fromHex("e6fff5"),
		MainColor = Color3.fromHex("1d382e"),
		AccentColor = Color3.fromHex("38d99a"),
		BackgroundColor = Color3.fromHex("12271f"),
		OutlineColor = Color3.fromHex("367a5c"),
	},
	Evergreen = {
		FontColor = Color3.fromHex("e8f3e8"),
		MainColor = Color3.fromHex("24352a"),
		AccentColor = Color3.fromHex("8dbb67"),
		BackgroundColor = Color3.fromHex("17251c"),
		OutlineColor = Color3.fromHex("4c6849"),
	},
	Arctic = {
		FontColor = Color3.fromHex("effaff"),
		MainColor = Color3.fromHex("263641"),
		AccentColor = Color3.fromHex("70d7f5"),
		BackgroundColor = Color3.fromHex("17232d"),
		OutlineColor = Color3.fromHex("4a7182"),
	},
	Glacier = {
		FontColor = Color3.fromHex("eaf7ff"),
		MainColor = Color3.fromHex("253849"),
		AccentColor = Color3.fromHex("8bbcff"),
		BackgroundColor = Color3.fromHex("172635"),
		OutlineColor = Color3.fromHex("4d6e94"),
	},
	Cobalt = {
		FontColor = Color3.fromHex("edf1ff"),
		MainColor = Color3.fromHex("202947"),
		AccentColor = Color3.fromHex("536dfe"),
		BackgroundColor = Color3.fromHex("141b35"),
		OutlineColor = Color3.fromHex("3a4d8d"),
	},
	["Royal Purple"] = {
		FontColor = Color3.fromHex("f6eeff"),
		MainColor = Color3.fromHex("30213f"),
		AccentColor = Color3.fromHex("bd75f5"),
		BackgroundColor = Color3.fromHex("1e162b"),
		OutlineColor = Color3.fromHex("654586"),
	},
	["Grape Soda"] = {
		FontColor = Color3.fromHex("f8eeff"),
		MainColor = Color3.fromHex("34213c"),
		AccentColor = Color3.fromHex("dc72e8"),
		BackgroundColor = Color3.fromHex("24162d"),
		OutlineColor = Color3.fromHex("70427a"),
	},
	["Neon Noir"] = {
		FontColor = Color3.fromHex("f1f5f9"),
		MainColor = Color3.fromHex("20242c"),
		AccentColor = Color3.fromHex("ff3cac"),
		BackgroundColor = Color3.fromHex("12151b"),
		OutlineColor = Color3.fromHex("64405f"),
	},
	Coffee = {
		FontColor = Color3.fromHex("f4e6d5"),
		MainColor = Color3.fromHex("382b23"),
		AccentColor = Color3.fromHex("c58b5b"),
		BackgroundColor = Color3.fromHex("241b16"),
		OutlineColor = Color3.fromHex("70513b"),
	},
	Sandstone = {
		FontColor = Color3.fromHex("453b2c"),
		MainColor = Color3.fromHex("e8dcc5"),
		AccentColor = Color3.fromHex("b47b45"),
		BackgroundColor = Color3.fromHex("f4ead7"),
		OutlineColor = Color3.fromHex("b8a486"),
	},
	Paper = {
		FontColor = Color3.fromHex("30343b"),
		MainColor = Color3.fromHex("f0f1ed"),
		AccentColor = Color3.fromHex("4776a8"),
		BackgroundColor = Color3.fromHex("fafaf7"),
		OutlineColor = Color3.fromHex("a9b0b8"),
	},
	Graphite = {
		FontColor = Color3.fromHex("e1e5e9"),
		MainColor = Color3.fromHex("292d32"),
		AccentColor = Color3.fromHex("aeb8c2"),
		BackgroundColor = Color3.fromHex("1a1d21"),
		OutlineColor = Color3.fromHex("555d65"),
	},
	Steel = {
		FontColor = Color3.fromHex("e7edf2"),
		MainColor = Color3.fromHex("28333c"),
		AccentColor = Color3.fromHex("8da9bd"),
		BackgroundColor = Color3.fromHex("19232b"),
		OutlineColor = Color3.fromHex("526978"),
	},
	Toxic = {
		FontColor = Color3.fromHex("f0ffe8"),
		MainColor = Color3.fromHex("28351e"),
		AccentColor = Color3.fromHex("a8ef38"),
		BackgroundColor = Color3.fromHex("192411"),
		OutlineColor = Color3.fromHex("5e7d34"),
	},
	Void = {
		FontColor = Color3.fromHex("eeeaff"),
		MainColor = Color3.fromHex("211d36"),
		AccentColor = Color3.fromHex("806bff"),
		BackgroundColor = Color3.fromHex("131123"),
		OutlineColor = Color3.fromHex("453d75"),
	},
	["High Contrast"] = {
		FontColor = Color3.fromHex("f5f5f5"),
		MainColor = Color3.fromHex("1b1b1b"),
		AccentColor = Color3.fromHex("ffda44"),
		BackgroundColor = Color3.fromHex("101010"),
		OutlineColor = Color3.fromHex("505050"),
	},
}
local function applyTheme(library, name)
	local colors = themes[name]
	if not colors then return end
	for k, c in pairs(colors) do library[k] = c end
	library.AccentColorDark = library:GetDarkerColor(library.AccentColor)
	pcall(function() library:UpdateColorsUsingRegistry() end)
	pcall(function() library:SetThemeStyle() end)
end

ThemeManager.Folder = "Aero-Rewrite-Themes"
function ThemeManager:SetLibrary(l) self.Library = l end
function ThemeManager:SetFolder(f) self.Folder = f end
function ThemeManager:ApplyToGroupbox(groupbox)
	if not groupbox or not self.Library then return end
	local names = {}
	for k in pairs(themes) do names[#names + 1] = k end
	table.sort(names)
	local lib = self.Library
	groupbox:AddDropdown("ThemeManager_ThemeList", {
		Text = "Theme",
		Values = names,
		Default = "Aero",
		Callback = function(value) applyTheme(lib, value) end,
	})
end
function ThemeManager:ApplyToTab(tab)
	if tab and tab.AddLeftGroupbox then self:ApplyToGroupbox(tab:AddLeftGroupbox("Themes")) end
end
function ThemeManager:ApplyTheme() end
function ThemeManager:ThemeUpdate() end
function ThemeManager:LoadDefault() end
function ThemeManager:SaveDefault() end
function ThemeManager:GetCustomTheme() return nil end
function ThemeManager:SaveCustomTheme() end
function ThemeManager:ReloadCustomThemes() return {} end
function ThemeManager:BuildFolderTree() end
function ThemeManager:CreateGroupBox() end
function ThemeManager:CreateThemeManager() end
return ThemeManager
end)()