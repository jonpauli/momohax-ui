--[[
	Momohax UI Library - 1:1 interface recreation
	USAGE: LocalScript in StarterPlayerScripts (or runfile in an executor).
	Interface only: no gameplay automation, no exploit execution, no AC bypass.
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local GuiService       = game:GetService("GuiService")
local LocalPlayer      = Players.LocalPlayer

local Lib = {}
Lib.Connections      = {}
Lib.Appliers         = {}
Lib.DropdownClosers  = {}
Lib.ColorMetas       = {}
Lib.ThemeObjects     = {}
Lib.BaseScale        = 1
Lib.Destroyed        = false

local function BindConn(conn)
	table.insert(Lib.Connections, conn)
	return conn
end
local function Connect(signal, fn)
	return BindConn(signal:Connect(fn))
end

local LOCounter = 0
local function LO(inst)
	LOCounter += 1
	inst.LayoutOrder = LOCounter
	return inst
end

local function New(class, props, children)
	local inst = Instance.new(class)
	if children then
		for _, child in ipairs(children) do child.Parent = inst end
	end
	local parent = nil
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	inst.Parent = parent
	return inst
end

local function Corner(parent, r)
	New("UICorner", { CornerRadius = UDim.new(0, r or 2), Parent = parent })
end

-- theme -------------------------------------------------------------------
local function RGB(r, g, b) return Color3.fromRGB(r, g, b) end

local Themes = {
	Dark = {
		Background = RGB(13, 13, 16),  Surface = RGB(9, 9, 12),   Header = RGB(8, 8, 11),
		Border = RGB(45, 45, 50),      BorderSoft = RGB(30, 30, 35),
		Text = RGB(222, 222, 228),     TextDim = RGB(150, 150, 158), TextFaint = RGB(102, 102, 110),
		Track = RGB(40, 40, 46),       Box = RGB(17, 17, 21),     ListBg = RGB(11, 11, 14),
		NavSel = RGB(29, 29, 34),      Handle = RGB(233, 233, 239), Accent = RGB(202, 202, 210),
	},
	Midnight = {
		Background = RGB(6, 6, 8),     Surface = RGB(4, 4, 6),    Header = RGB(3, 3, 5),
		Border = RGB(34, 34, 40),      BorderSoft = RGB(22, 22, 26),
		Text = RGB(212, 212, 220),     TextDim = RGB(132, 132, 140), TextFaint = RGB(86, 86, 94),
		Track = RGB(30, 30, 36),       Box = RGB(11, 11, 14),     ListBg = RGB(7, 7, 9),
		NavSel = RGB(20, 20, 25),      Handle = RGB(226, 226, 232), Accent = RGB(202, 202, 210),
	},
	Light = {
		Background = RGB(236, 236, 240), Surface = RGB(228, 228, 233), Header = RGB(222, 222, 228),
		Border = RGB(168, 168, 176),   BorderSoft = RGB(192, 192, 200),
		Text = RGB(28, 28, 34),        TextDim = RGB(96, 96, 104), TextFaint = RGB(140, 140, 148),
		Track = RGB(204, 204, 212),    Box = RGB(246, 246, 250),  ListBg = RGB(250, 250, 253),
		NavSel = RGB(216, 216, 224),   Handle = RGB(60, 60, 68),  Accent = RGB(60, 60, 68),
	},
}
Lib.Themes = Themes
Lib.Theme = Themes.Dark

local function RegisterTheme(obj, prop, key)
	table.insert(Lib.ThemeObjects, { Object = obj, Prop = prop, Key = key })
	obj[prop] = Lib.Theme[key]
	return obj
end

local function ApplyTheme()
	for _, e in ipairs(Lib.ThemeObjects) do
		pcall(function() e.Object[e.Prop] = Lib.Theme[e.Key] end)
	end
end

-- flags -------------------------------------------------------------------
local function C(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
local function Clone(t)
	local c = {}
