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
	for k, v in pairs(t) do c[k] = (type(v) == "table") and Clone(v) or v end
	return c
end
local function PlayerTemplate()
	return { Boxes = false, Names = false, HealthBar = false, Tracers = false, Chams = false, Priority = "Closest" }
end

Lib.Defaults = {
	Aimbot = {
		Enabled = false, Key = "MouseButton2", SilentAim = false, SilentKey = "E",
		ShowFov = false, FovColor = C(210, 210, 216, 1), AutoFire = false,
		FOV = 25, Smoothness = 23, HitPart = { "Head", "Torso", "Arms", "Legs", "Feet" },
		Priority = "Lowest Health",
	},
	Triggerbot = {
		Enabled = false, Key = "X", Delay = 195,
		ReactionMin = 66, ReactionMax = 140, Parts = { "Arms", "Legs", "Feet" },
	},
	Visuals = {
		Boxes = false, BoxType = "Corner", Names = false, NamesKey = "E",
		HealthBar = false, Chams = false, Fill = false, Thickness = 1,
		Tracers = false, Skeleton = false, Outline = false,
		FillColor = C(235, 235, 240, 0.85), OutlineColor = C(22, 22, 26, 1),
		HealthColor = C(88, 200, 112, 1), TracerColor = C(222, 88, 88, 1),
		SkeletonColor = C(88, 140, 224, 1), ChamColor = C(156, 102, 208, 1),
	},
	Misc = { Watermark = true, KeybindList = true, PlayerList = false, ConfigName = "", LastSaved = "03/11/2026" },
	Binds = { Menu = "Insert", KeybindList = "Insert", PeekAssist = "C", Speed = "F", Fly = "F", Panic = "Delete" },
	Players = {},
	Settings = { UIScale = 100, Opacity = 100, Theme = "Dark", Accent = C(202, 202, 210, 1), Animations = true, AnimSpeed = 1 },
}
Lib.PlayerTemplate = PlayerTemplate
Lib.Flags = Clone(Lib.Defaults)
Lib.Flags.Misc.LastSaved = os.date("%d/%m/%Y")
Lib.FlagTables = { Lib.Flags.Aimbot, Lib.Flags.Triggerbot, Lib.Flags.Visuals, Lib.Flags.Misc, Lib.Flags.Binds, Lib.Flags.Settings }

-- merge (preserves table references so watchers stay valid) ---------------
local function MergeInto(cur, def)
	for k, v in pairs(def) do
		local cv = cur[k]
		if type(v) == "table" and type(cv) == "table" then
			if v[1] ~= nil and type(v[1]) ~= "table" then
				for i = #cv, 1, -1 do cv[i] = nil end
				for i, x in ipairs(v) do cv[i] = x end
			else
				MergeInto(cv, v)
			end
		else
			cur[k] = v
		end
	end
end
Lib.MergeInto = MergeInto

-- signals -----------------------------------------------------------------
local Watchers = {}
local function Emit(t)
	local list = Watchers[t]
	if list then
		for i = #list, 1, -1 do
			local e = list[i]
			if e.scope and e.scope.Dead then
				table.remove(list, i)
			else
				task.spawn(pcall, e.fn)
			end
		end
	end
end
Lib.Emit = Emit
local function Watch(t, fn, scope)
	local list = Watchers[t]
	if not list then list = {} Watchers[t] = list end
	table.insert(list, { fn = fn, scope = scope })
end
Lib.Watch = Watch
local function EmitAll()
	for _, t in ipairs(Lib.FlagTables) do Emit(t) end
	for _, t in pairs(Lib.Flags.Players) do Emit(t) end
end
Lib.EmitAll = EmitAll

local function RegisterApplier(fn, scope)
	table.insert(Lib.Appliers, { fn = fn, scope = scope })
end
local function RunAppliers()
	for i = #Lib.Appliers, 1, -1 do
		local e = Lib.Appliers[i]
		if e.scope and e.scope.Dead then
			table.remove(Lib.Appliers, i)
		end
	end
	for _, e in ipairs(Lib.Appliers) do
		if not (e.scope and e.scope.Dead) then task.spawn(pcall, e.fn) end
	end
end
Lib.RunAppliers = RunAppliers

-- scopes (for rebuildable control groups) ---------------------------------
function Lib:NewScope()
	local scope = { Conns = {}, Dead = false }
	function scope.Connect(_, signal, fn)
		local c = signal:Connect(fn)
		table.insert(scope.Conns, c)
		return c
	end
	function scope.Clear(_)
		scope.Dead = true
		for _, c in ipairs(scope.Conns) do pcall(function() c:Disconnect() end) end
		scope.Conns = {}
	end
	return scope
end

-- animation ---------------------------------------------------------------
local function AnimTime(t)
	if not Lib.Flags.Settings.Animations then return 0 end
	return math.max((t or 0.12) / math.max(Lib.Flags.Settings.AnimSpeed or 1, 0.05), 0.01)
end
local function Tween(obj, props, t)
	local tw = TweenService:Create(obj, TweenInfo.new(AnimTime(t), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
Lib.Tween = Tween

-- colors ------------------------------------------------------------------
local function ColorOf(c)
	if type(c) ~= "table" then return RGB(255, 255, 255) end
	return RGB(
		math.clamp(math.floor(c.r + 0.5), 0, 255),
		math.clamp(math.floor(c.g + 0.5), 0, 255),
		math.clamp(math.floor(c.b + 0.5), 0, 255)
	)
end
Lib.ColorOf = ColorOf
local function AlphaOf(c) return math.clamp((type(c) == "table" and c.a) or 1, 0, 1) end
Lib.AlphaOf = AlphaOf
local function SetRGB(c, col)
	c.r = math.floor(col.R * 255 + 0.5)
	c.g = math.floor(col.G * 255 + 0.5)
	c.b = math.floor(col.B * 255 + 0.5)
end
Lib.SetRGB = SetRGB
local function HSVOf(c) return ColorOf(c):ToHSV() end
Lib.HSVOf = HSVOf
local function HexOf(c)
	local a = math.clamp(math.floor((c.a or 1) * 255 + 0.5), 0, 255)
	return ("#%02X%02X%02X%02X"):format(c.r, c.g, c.b, a)
end
Lib.HexOf = HexOf
local function ParseHex(str)
	str = tostring(str or ""):gsub("#", ""):gsub("%s", "")
	if (#str ~= 6 and #str ~= 8) or not str:match("^%x+$") then return nil end
	local r = tonumber(str:sub(1, 2), 16)
	local g = tonumber(str:sub(3, 4), 16)
	local b = tonumber(str:sub(5, 6), 16)
	local a = (#str == 8) and (tonumber(str:sub(7, 8), 16) / 255) or nil
	return r, g, b, a
end
Lib.ParseHex = ParseHex
local function ParseRGB(str)
	local parts = {}
	for num in tostring(str or ""):gmatch("%-?%d+%.?%d*") do
		parts[#parts + 1] = tonumber(num)
	end
	if #parts < 3 then return nil end
	local r = math.clamp(parts[1], 0, 255)
	local g = math.clamp(parts[2], 0, 255)
	local b = math.clamp(parts[3], 0, 255)
	local a = (#parts >= 4) and math.clamp(parts[4], 0, 1) or nil
	return r, g, b, a
end
Lib.ParseRGB = ParseRGB
local function GetColorMeta(c)
	local m = Lib.ColorMetas[c]
	if not m then
		m = { Animation = "Fade", ColorAnimation = "Static", Speed = 2, Phase = 0 }
		Lib.ColorMetas[c] = m
	end
	return m
end
Lib.GetColorMeta = GetColorMeta

-- keys --------------------------------------------------------------------
local KeyNames = {
	Insert = "INS", Delete = "DEL", Home = "HOME", End = "END", PageUp = "PGUP", PageDown = "PGDN",
	LeftControl = "LCTRL", RightControl = "RCTRL", LeftShift = "LSHIFT", RightShift = "RSHIFT",
	LeftAlt = "LALT", RightAlt = "RALT", CapsLock = "CAPS", Backspace = "BKSP", Tab = "TAB",
	Backquote = "`", Minus = "-", Equals = "=", LeftBracket = "[", RightBracket = "]",
	Slash = "/", Period = ".", Comma = ",", Semicolon = ";", Quote = "'", Backslash = "\\",
	Space = "SPACE", Enter = "ENTER", Up = "UP", Down = "DOWN", LeftArrow = "LEFT", RightArrow = "RIGHT",
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5",
	Six = "6", Seven = "7", Eight = "8", Nine = "9",
	MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
}
local function PrettyKey(name)
	if name == nil then return "?" end
	return KeyNames[name] or tostring(name)
end
Lib.PrettyKey = PrettyKey
local function MatchesKey(name, input)
	if type(name) ~= "string" then return false end
	if name:sub(1, 10) == "MouseButton" then
		local ut = Enum.UserInputType:FindFirstChild(name)
		return ut ~= nil and input.UserInputType == ut
	end
	local kc = Enum.KeyCode:FindFirstChild(name)
	return kc ~= nil and input.KeyCode == kc
end
Lib.MatchesKey = MatchesKey

-- dropdown lifecycle ------------------------------------------------------
function Lib.CloseDropdowns()
	for i = #Lib.DropdownClosers, 1, -1 do
		local c = Lib.DropdownClosers[i]
		if c then pcall(c) end
	end
end

-- routes a UIS.InputChanged connection to the global registry or a scope
function Lib:AddInputChanged(fn, scope)
	if scope then
		return scope:Connect(UserInputService.InputChanged, fn)
	end
	return BindConn(UserInputService.InputChanged:Connect(fn))
end

-- scale / mouse helpers ---------------------------------------------------
local function AppliedScale()
	return Lib.BaseScale * ((Lib.Flags.Settings.UIScale or 100) / 100)
end
Lib.AppliedScale = AppliedScale
local function InRect(m, x, y, w, h)
	return m.X >= x and m.X <= x + w and m.Y >= y and m.Y <= y + h
end
local function MouseOn(obj, m)
	local p, s = obj.AbsolutePosition, obj.AbsoluteSize
	if InRect(m, p.X, p.Y, s.X, s.Y) then return true end
	local inset = GuiService:GetGuiInset().Y
	return InRect(m, p.X, p.Y - inset, s.X, s.Y) or InRect(m, p.X, p.Y + inset, s.X, s.Y)
end
Lib.MouseOn = MouseOn

-- dragging ----------------------------------------------------------------
local function MakeDraggable(gui, handle)
	handle.Active = true
	local dragging, dragStart, startPos = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = gui.Position
			Lib.CloseDropdowns()
		end
	end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	Connect(UserInputService.InputChanged, function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - dragStart
			gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end
Lib.MakeDraggable = MakeDraggable

-- gui atoms ---------------------------------------------------------------
local function Text(props)
	props.Font = props.Font or Enum.Font.Code
	return New("TextLabel", props)
end
Lib.Text = Text

local function Row(body, h)
	return LO(New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), BorderSizePixel = 0, Parent = body,
	}))
end
Lib.Row = Row

local function Veil(parent, radius)
	local v = New("Frame", {
		BackgroundColor3 = RGB(255, 255, 255), BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 10, Parent = parent,
	})
	if radius then Corner(v, radius) end
	return v
end
local function Hover(btn, radius, hoverT)
	local v = Veil(btn, radius)
	btn.MouseEnter:Connect(function() Tween(v, { BackgroundTransparency = hoverT or 0.93 }, 0.08) end)
	btn.MouseLeave:Connect(function() Tween(v, { BackgroundTransparency = 1 }, 0.15) end)
	return v
end
Lib.Hover = Hover

local function Chevron(parent, pos)
	local holder = New("Frame", {
		BackgroundTransparency = 1, Position = pos, Size = UDim2.fromOffset(8, 5),
		AnchorPoint = Vector2.new(1, 0.5), Parent = parent,
	})
	for _, arm in ipairs({ { -45, 0.30 }, { 45, 0.70 } }) do
		RegisterTheme(New("Frame", {
			BackgroundColor3 = RGB(150, 150, 158), BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(arm[2], 0, 0.5, 0),
			Size = UDim2.fromOffset(1, 4), Rotation = arm[1], Parent = holder,
		}), "BackgroundColor3", "TextDim")
	end
	return holder
end

local function GlyphBar(parent, pos, size, rot, anchor)
	return RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(170, 170, 178), BorderSizePixel = 0, Position = pos, Size = size,
		Rotation = rot or 0, AnchorPoint = anchor or Vector2.new(0.5, 0.5), Parent = parent,
	}), "BackgroundColor3", "TextDim")
end

local function PlusGlyph(parent)
	GlyphBar(parent, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(1, 7))
	GlyphBar(parent, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(7, 1))
end

local function ArrowGlyph(parent, dir)
	if dir == "up" or dir == "down" then
		GlyphBar(parent, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(1, 7))
		local y = (dir == "up") and 0.26 or 0.74
		GlyphBar(parent, UDim2.new(0.38, 0, y, 0), UDim2.fromOffset(1, 4), 45)
		GlyphBar(parent, UDim2.new(0.62, 0, y, 0), UDim2.fromOffset(1, 4), -45)
	else
		GlyphBar(parent, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(7, 1))
		local x = (dir == "left") and 0.26 or 0.74
		GlyphBar(parent, UDim2.new(x, 0, 0.38, 0), UDim2.fromOffset(1, 4), 45)
		GlyphBar(parent, UDim2.new(x, 0, 0.62, 0), UDim2.fromOffset(1, 4), -45)
	end
end

local function GearGlyph(parent)
	local core = GlyphBar(parent, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(5, 5))
	Corner(core, 2)
	GlyphBar(parent, UDim2.new(0.5, 0, 0, 0), UDim2.fromOffset(1, 2), 0, Vector2.new(0.5, 0))
	GlyphBar(parent, UDim2.new(0.5, 0, 1, 0), UDim2.fromOffset(1, 2), 0, Vector2.new(0.5, 1))
	GlyphBar(parent, UDim2.new(0, 0, 0.5, 0), UDim2.fromOffset(2, 1), 0, Vector2.new(0, 0.5))
	GlyphBar(parent, UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(2, 1), 0, Vector2.new(1, 0.5))
end

-- sections ----------------------------------------------------------------
function Lib:Section(parent, title, plain)
	local sec = LO(New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = parent,
	}))
	if not plain then
		RegisterTheme(New("Frame", {
			BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1), Parent = sec,
		}), "BackgroundColor3", "BorderSoft")
		local head = RegisterTheme(New("Frame", {
			BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 14), Parent = sec,
		}), "BackgroundColor3", "Header")
		if title then
			RegisterTheme(Text({
				BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 0),
				Size = UDim2.new(1, -8, 1, 0), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
				Text = "!  " .. title, Parent = head,
			}), "TextColor3", "Text")
		end
		RegisterTheme(New("Frame", {
			BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 14), Size = UDim2.new(1, 0, 0, 1), Parent = sec,
		}), "BackgroundColor3", "BorderSoft")
	end
	local body = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, plain and 0 or 15), Parent = sec,
	})
	New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	New("UIPadding", { PaddingLeft = 3, PaddingRight = 3, PaddingTop = 2, PaddingBottom = 1, Parent = body })
	return { Frame = sec, Body = body }
end

-- toggles -----------------------------------------------------------------
function Lib:Toggle(sec, opts)
	local bind = opts.Bind
	local row = LO(New("TextButton", {
		AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 13), Parent = sec.Body,
	}))
	local box = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
		Size = UDim2.fromOffset(11, 11), Position = UDim2.new(0, 0, 0.5, -5), Parent = row,
	}), "BackgroundColor3", "Box")
	local bst = New("UIStroke", { Thickness = 1, Parent = box })
	RegisterTheme(bst, "Color", "Border")
	local fill = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(7, 7), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Parent = box,
	}), "BackgroundColor3", "Accent")
	local lbl = RegisterTheme(Text({
		BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -16, 1, 0), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		Text = opts.Text or "", Parent = row,
	}), "TextColor3", opts.Disabled and "TextFaint" or "Text")

	local right = (opts.Swatch and 15 or 0) + (opts.Cog and 15 or 0)
	if opts.Keybind then
		Lib:Keybind(row, { Bind = opts.Keybind, TextSize = 10, Height = 13, Offset = right })
	end
	if opts.Cog then
		local cog = LO(New("TextButton", {
			AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
			Size = UDim2.fromOffset(11, 11), AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(opts.Swatch and 15 or 1), 0.5, 0), Parent = row,
		}))
		GearGlyph(cog)
		cog.Activated:Connect(function() Lib:OpenColorPicker(opts.Cog, opts.Text .. " Color", cog) end)
	end
	if opts.Swatch then
		Lib:ColorSwatch(row, { Bind = opts.Swatch, Title = opts.SwatchTitle or (opts.Text .. " Color"), Offset = 1, Size = 10 })
	end
	if opts.RightTag then
		RegisterTheme(Text({
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -right - 2, 0.5, 0), Size = UDim2.new(0, 60, 1, 0),
			TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right,
			Text = opts.RightTag, Parent = row,
		}), "TextColor3", "TextFaint")
	end

	local function Render()
		local v = bind.t[bind.k] and true or false
		Tween(fill, { BackgroundTransparency = v and 0.05 or 1 }, 0.1)
	end
	local obj = {
		Set = function(v) bind.t[bind.k] = v Render() end,
		Get = function() return bind.t[bind.k] end,
	}
	row.Activated:Connect(function()
		if opts.Disabled then return end
		bind.t[bind.k] = not bind.t[bind.k]
		Render()
		Emit(bind.t)
		if opts.OnChanged then opts.OnChanged(bind.t[bind.k]) end
	end)
	Watch(bind.t, Render, opts.Scope)
	RegisterApplier(Render, opts.Scope)
	Render()
	return obj
end

-- keybinds ----------------------------------------------------------------
function Lib:Keybind(parent, opts)
	local bind = opts.Bind
	local btn = LO(New("TextButton", {
		AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
		Size = UDim2.fromOffset(opts.Width or 34, opts.Height or 13),
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(opts.Offset or 0), 0.5, 0),
		Parent = parent,
	}))
	local lbl = RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextSize = opts.TextSize or 10,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "[" .. PrettyKey(bind.t[bind.k]) .. "]", Parent = btn,
	}), "TextColor3", "TextDim")
	local capturing = false
	local function RenderText()
		lbl.Text = capturing and "[...]" or "[" .. PrettyKey(bind.t[bind.k]) .. "]"
	end
	btn.Activated:Connect(function()
		if capturing then return end
		capturing = true
		Lib.Captures = (Lib.Captures or 0) + 1
		RenderText()
		local conn
		local function Handle(input, gp)
			if gp then return end
			if input.KeyCode == Enum.KeyCode.Escape then
				conn:Disconnect()
				capturing = false
				Lib.Captures = math.max((Lib.Captures or 1) - 1, 0)
				RenderText()
				return
			end
			local name
			if input.UserInputType == Enum.UserInputType.Keyboard then
				name = input.KeyCode.Name
			elseif input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3 then
				name = input.UserInputType.Name
			end
			if name then
				bind.t[bind.k] = name
				capturing = false
				Lib.Captures = math.max((Lib.Captures or 1) - 1, 0)
				RenderText()
				conn:Disconnect()
				Emit(bind.t)
			end
		end
		if opts.Scope then
			conn = opts.Scope:Connect(UserInputService.InputBegan, Handle)
		else
			conn = BindConn(UserInputService.InputBegan:Connect(Handle))
		end
	end)
	Watch(bind.t, RenderText, opts.Scope)
	RegisterApplier(RenderText, opts.Scope)
	return btn
end

-- sliders -----------------------------------------------------------------
function Lib:Slider(sec, opts)
	local bind = opts.Bind
	local min, max = opts.Min or 0, opts.Max or 100
	local step = opts.Step or 1
	local block = Row(sec.Body, 25)
	RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 11),
		TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		Text = opts.Label or "", Parent = block,
	}), "TextColor3", "Text")
	local holder = New("TextButton", {
		AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Active = true,
		Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 13), Parent = block,
	})
	local track = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 0.5, -1), Parent = holder,
	}), "BackgroundColor3", "Track")
	local fill = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(0.5, 0, 1, 0), Parent = track,
	}), "BackgroundColor3", "Accent")
	local handle = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromOffset(2, 9),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		ZIndex = 2, Parent = track,
	}), "BackgroundColor3", "Handle")
	local val = RegisterTheme(Text({
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, -3), Size = UDim2.new(0, 70, 0, 11),
		TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
	}), "TextColor3", "Text")

	local function Fmt(v)
		if opts.Format then return opts.Format(v) end
		return tostring(math.floor(v + 0.5)) .. (opts.Suffix or "")
	end
	local function Render()
		local v = math.clamp(bind.t[bind.k] or min, min, max)
		local f = (v - min) / (max - min)
		fill.Size = UDim2.new(f, 0, 1, 0)
		handle.Position = UDim2.new(f, 0, 0.5, 0)
		val.Text = Fmt(v)
	end
	local obj = {
		Set = function(v) bind.t[bind.k] = math.clamp(v, min, max) Render() end,
		Get = function() return bind.t[bind.k] end,
	}
	local dragging = false
	holder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	BindConn(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end));
	(opts.Scope or Lib):AddInputChanged(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local f = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			local v = min + f * (max - min)
			v = math.floor(v / step + 0.5) * step
			v = math.clamp(v, min, max)
			if v ~= bind.t[bind.k] then
				bind.t[bind.k] = v
				Render()
				Emit(bind.t)
				if opts.OnChanged then opts.OnChanged(v) end
			end
		end
	end, opts.Scope)
	RegisterApplier(Render, opts.Scope)
	Render()
	return obj
end

function Lib:RangeSlider(sec, opts)
	local bmin, bmax = opts.BindMin, opts.BindMax
	local min, max = opts.Min or 0, opts.Max or 100
	local block = Row(sec.Body, 25)
	RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 11),
		TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		Text = opts.Label or "", Parent = block,
	}), "TextColor3", "Text")
	local holder = New("TextButton", {
		AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Active = true,
		Position = UDim2.new(0, 0, 0, 12), Size = UDim2.new(1, 0, 0, 13), Parent = block,
	})
	local track = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 0.5, -1), Parent = holder,
	}), "BackgroundColor3", "Track")
	local fill = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Parent = track,
	}), "BackgroundColor3", "Accent")
	local hA = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromOffset(2, 9),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 2, Parent = track,
	}), "BackgroundColor3", "Handle")
	local hB = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromOffset(2, 9),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0), ZIndex = 2, Parent = track,
	}), "BackgroundColor3", "Handle")
	local val = RegisterTheme(Text({
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -3), Size = UDim2.new(0, 110, 0, 11),
		TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, Parent = holder,
	}), "TextColor3", "Text")

	local function Fmt(v) return tostring(math.floor(v + 0.5)) .. (opts.Suffix or "") end
	local function Render()
		local a = math.clamp(bmin.t[bmin.k] or min, min, max)
		local b = math.clamp(bmax.t[bmax.k] or max, min, max)
		if a > b then a, b = b, a end
		local fa = (a - min) / (max - min)
		local fb = (b - min) / (max - min)
		fill.Position = UDim2.new(fa, 0, 0, 0)
		fill.Size = UDim2.new(fb - fa, 0, 1, 0)
		hA.Position = UDim2.new(fa, 0, 0.5, 0)
		hB.Position = UDim2.new(fb, 0, 0.5, 0)
		val.Text = Fmt(a) .. " - " .. Fmt(b)
	end
	local dragging = nil -- "min" | "max"
	holder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local f = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			local a = math.clamp(bmin.t[bmin.k], min, max)
			local b = math.clamp(bmax.t[bmax.k], min, max)
			local fa, fb = (a - min) / (max - min), (b - min) / (max - min)
			dragging = (math.abs(f - fa) <= math.abs(f - fb)) and "min" or "max"
		end
	end)
	BindConn(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = nil
		end
	end))
	(opts.Scope or Lib):AddInputChanged(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local f = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			local v = math.floor(min + f * (max - min) + 0.5)
			if dragging == "min" then
				bmin.t[bmin.k] = math.clamp(v, min, math.max(bmax.t[bmax.k], min))
			else
				bmax.t[bmax.k] = math.clamp(v, math.max(bmin.t[bmin.k], min), max)
			end
			Render()
			Emit(bmin.t)
		end
	end, opts.Scope)
	RegisterApplier(Render, opts.Scope)
	Render()
end

-- dropdowns ---------------------------------------------------------------
function Lib:Dropdown(sec, opts)
	local bind = opts.Bind
	local hasLabel = opts.Label ~= nil
	local block = Row(sec.Body, hasLabel and 31 or 18)
	if hasLabel then
		RegisterTheme(Text({
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 11),
			TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
			Text = opts.Label, Parent = block,
		}), "TextColor3", "Text")
	end
	local box = LO(New("TextButton", {
		AutoButtonColor = false, Text = "", BackgroundTransparency = 0,
		Position = UDim2.new(0, 0, 0, hasLabel and 13 or 0), Size = UDim2.new(1, 0, 0, 18),
		Parent = block,
	}))
	RegisterTheme(box, "BackgroundColor3", "Box")
	local bst = New("UIStroke", { Thickness = 1, Parent = box })
	RegisterTheme(bst, "Color", "Border")
	local val = RegisterTheme(Text({
		BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 0),
		Size = UDim2.new(1, -18, 1, 0), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = box,
	}), "TextColor3", "Text")
	local chev = Chevron(box, UDim2.new(1, -4, 0.5, 0))
	chev.AnchorPoint = Vector2.new(1, 0.5)

	local open = false
	local list = nil
	local Close
	local function Deregister()
		local i = table.find(Lib.DropdownClosers, Close)
		if i then table.remove(Lib.DropdownClosers, i) end
	end
	local function CloseFn()
		if not open then return end
		open = false
		Lib.ActiveDropdown = nil
		Tween(chev, { Rotation = 0 }, 0.1)
		Deregister()
		if list then
			local l = list
			Tween(l, { BackgroundTransparency = 0.4 }, 0.08)
			task.delay(0.09, function() pcall(function() l:Destroy() end) end)
			list = nil
		end
	end
	Close = CloseFn
	local function SetText()
		local v = bind.t[bind.k]
		if opts.Multi and type(v) == "table" then
			val.Text = table.concat(v, ", ")
		else
			val.Text = tostring(v)
		end
	end
	local function BuildList()
		local layer = Lib.DropdownLayer
		local s = Lib.AppliedScale()
		local bAbs, bSize = box.AbsolutePosition, box.AbsoluteSize
		local x = (bAbs.X - layer.AbsolutePosition.X) / s
		local y = (bAbs.Y - layer.AbsolutePosition.Y + bSize.Y) / s
		local w = bSize.X / s
		local rowH = 14
		local h = (#opts.Values * (rowH + 1) + 4) / s
		local maxBottom = (layer.AbsoluteSize.Y / s) - 2
		if y + h > maxBottom then y = math.max(1, maxBottom - h) end
		list = LO(New("Frame", {
			BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
			ClipsDescendants = true, ZIndex = 51, Parent = layer,
		}))
		RegisterTheme(list, "BackgroundColor3", "ListBg")
		local lst = New("UIStroke", { Thickness = 1, Parent = list })
		RegisterTheme(lst, "Color", "Border")
		New("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		New("UIPadding", { PaddingTop = 2, PaddingBottom = 2, Parent = list })
		for i, v in ipairs(opts.Values) do
			local isSel
			if opts.Multi and type(bind.t[bind.k]) == "table" then
				isSel = table.find(bind.t[bind.k], v) ~= nil
			else
				isSel = v == bind.t[bind.k]
			end
			local rb = LO(New("TextButton", {
				AutoButtonColor = false, Text = "", BackgroundTransparency = 0,
				Size = UDim2.new(1, 0, 0, rowH), Parent = list,
			}))
			RegisterTheme(rb, "BackgroundColor3", "ListBg")
			Hover(rb, nil, 0.88)
			local rl = RegisterTheme(Text({
				BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 0),
				Size = UDim2.new(1, -10, 1, 0), TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(v), Parent = rb,
			}), "TextColor3", isSel and "Text" or "TextDim")
			rb.Activated:Connect(function()
				if opts.Multi and type(bind.t[bind.k]) == "table" then
					local arr = bind.t[bind.k]
					local idx = table.find(arr, v)
					if idx then
						table.remove(arr, idx)
						rl.TextColor3 = Lib.Theme.TextDim
					else
						table.insert(arr, v)
						rl.TextColor3 = Lib.Theme.Text
					end
					SetText()
					Emit(bind.t)
					if opts.OnChanged then opts.OnChanged() end
				else
					bind.t[bind.k] = v
					SetText()
					Emit(bind.t)
					if opts.OnChanged then opts.OnChanged(v) end
					Close()
				end
			end)
		end
	end
	table.insert(Lib.DropdownClosers, Close)
	box.Activated:Connect(function()
		if open then
			Close()
			return
		end
		Lib.CloseDropdowns()
		BuildList()
		open = true
		Lib.ActiveDropdown = {
			Close = Close,
			HitTest = function(m)
				return Lib.MouseOn(box, m) or (list and Lib.MouseOn(list, m))
			end,
		}
		Tween(chev, { Rotation = 180 }, 0.1)
	end)
	RegisterApplier(SetText, opts.Scope)
	SetText()
	return { Set = function(v) bind.t[bind.k] = v SetText() end, Close = Close }
end

-- list boxes --------------------------------------------------------------
function Lib:ListBox(sec, opts)
	local bind = opts.Bind
	local container = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, opts.Height or 52),
		Parent = sec.Body,
	}), "BackgroundColor3", "ListBg")
	local cst = New("UIStroke", { Thickness = 1, Parent = container })
	RegisterTheme(cst, "Color", "BorderSoft")
	local list = New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 2, ScrollBarImageColor3 = RGB(90, 90, 98),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = container,
	})
	New("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	New("UIPadding", { PaddingLeft = 3, PaddingRight = 4, PaddingTop = 2, PaddingBottom = 2, Parent = list })
	local function Render()
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				local v = child:GetAttribute("Value")
				local selected = type(bind.t[bind.k]) == "table" and table.find(bind.t[bind.k], v) ~= nil
				Tween(child, { BackgroundTransparency = selected and 0.9 or 1 }, 0)
				local lbl = child:FindFirstChildOfClass("TextLabel")
				if lbl then lbl.TextColor3 = selected and Lib.Theme.Text or Lib.Theme.TextDim end
			end
		end
	end
	for _, v in ipairs(opts.Values or {}) do
		local rb = LO(New("TextButton", {
			AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 13), Parent = list,
		}))
		rb:SetAttribute("Value", v)
		RegisterTheme(Text({
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(v), Parent = rb,
		}), "TextColor3", "TextDim")
		rb.Activated:Connect(function()
			if type(bind.t[bind.k]) ~= "table" then bind.t[bind.k] = {} end
			local arr = bind.t[bind.k]
			local idx = table.find(arr, v)
			if idx then table.remove(arr, idx) else table.insert(arr, v) end
			Render()
			Emit(bind.t)
		end)
	end
	RegisterApplier(Render)
	Render()
	return container
end

-- color swatch ------------------------------------------------------------
function Lib:ColorSwatch(parent, opts)
	local bind = opts.Bind
	local sz = opts.Size or 12
	local btn = LO(New("TextButton", {
		AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
		Size = UDim2.fromOffset(sz, sz), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(opts.Offset or 0), 0.5, 0), Parent = parent,
	}))
	local sw = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(255, 255, 255), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = btn,
	}), "BackgroundColor3", "Accent")
	local sst = New("UIStroke", { Thickness = 1, Parent = sw })
	RegisterTheme(sst, "Color", "Border")
	local function Render()
		local c = bind.t[bind.k]
		if type(c) ~= "table" then return end
		sw.BackgroundColor3 = ColorOf(c)
		sw.BackgroundTransparency = math.clamp(1 - (c.a or 1), 0, 1)
	end
	btn.Activated:Connect(function()
		local P = Lib.Picker
		if P.Root and P.Root.Visible and P.Target and P.Target.t == bind.t and P.Target.k == bind.k then
			Lib:ClosePicker()
		else
			Lib:OpenColorPicker(bind, opts.Title or "Color", btn)
		end
	end)
	Watch(bind.t[bind.k], Render)
	RegisterApplier(Render)
	Render()
	return btn
end

-- text boxes --------------------------------------------------------------
function Lib:TextBox(sec, opts)
	local bind = opts.Bind
	local hasLabel = opts.Label ~= nil
	local block = Row(sec.Body, hasLabel and 31 or 16)
	if hasLabel then
		RegisterTheme(Text({
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 11),
			TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
			Text = opts.Label, Parent = block,
		}), "TextColor3", "Text")
	end
	local box = RegisterTheme(New("TextBox", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, hasLabel and 13 or 0), Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.Code, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		Text = bind.t[bind.k] or "", PlaceholderText = opts.Placeholder or "",
		PlaceholderColor3 = Lib.Theme.TextFaint, TextColor3 = Lib.Theme.Text,
		ClearTextOnFocus = false, ClipsDescendants = true, Parent = block,
	}), "BackgroundColor3", "Box")
	New("UIPadding", { PaddingLeft = 5, Parent = box })
	local bst = New("UIStroke", { Thickness = 1, Parent = box })
	RegisterTheme(bst, "Color", "Border")
	RegisterTheme(box, "TextColor3", "Text")
	box.FocusLost:Connect(function()
		bind.t[bind.k] = box.Text
		Emit(bind.t)
		if opts.OnCommit then opts.OnCommit(box.Text) end
	end)
	RegisterApplier(function()
		if not box:IsFocused() then box.Text = bind.t[bind.k] or "" end
	end)
	return box
end

-- buttons -----------------------------------------------------------------
function Lib:Button(parent, opts)
	local btn = LO(New("TextButton", {
		AutoButtonColor = false, Text = "", BackgroundTransparency = 0,
		Position = opts.Position or UDim2.new(0, 0, 0, 0),
		Size = opts.Size or UDim2.new(1, 0, 0, 16), Parent = parent,
	}))
	RegisterTheme(btn, "BackgroundColor3", "Box")
	local bst = New("UIStroke", { Thickness = 1, Parent = btn })
	RegisterTheme(bst, "Color", "Border")
	RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextSize = 11,
		Text = opts.Text or "", Parent = btn,
	}), "TextColor3", "Text")
	Hover(btn, 2, 0.9)
	btn.Activated:Connect(function()
		if opts.OnClick then opts.OnClick() end
	end)
	return btn
end

function Lib:ButtonRow(sec, defs, height)
	local row = Row(sec.Body, height or 16)
	local total = #defs
	local gap = 3
	local w = (100 / total)
	for i, def in ipairs(defs) do
		Lib:Button(row, {
			Text = def.Text,
			Position = UDim2.new((i - 1) * w, (i - 1) * gap, 0, 0),
			Size = UDim2.new(w, -gap, 1, 0),
			OnClick = def.OnClick,
		})
	end
	return row
end

function Lib:IconButton(parent, glyph, onClick, pos, size)
	local btn = LO(New("TextButton", {
		AutoButtonColor = false, Text = "", BackgroundTransparency = 0,
		Position = pos, Size = size or UDim2.fromOffset(13, 13), Parent = parent,
	}))
	RegisterTheme(btn, "BackgroundColor3", "Box")
	local bst = New("UIStroke", { Thickness = 1, Parent = btn })
	RegisterTheme(bst, "Color", "Border")
	local g = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = btn })
	if glyph == "plus" then PlusGlyph(g) else ArrowGlyph(g, glyph) end
	Hover(btn, 2, 0.9)
	btn.Activated:Connect(function()
		if onClick then onClick() end
	end)
	return btn
end

-- misc rows ---------------------------------------------------------------
function Lib:KeybindRow(sec, text, bind)
	local row = Row(sec.Body, 13)
	RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, 0), TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text, Parent = row,
	}), "TextColor3", "Text")
	Lib:Keybind(row, { Bind = bind, TextSize = 10, Height = 13, Width = 40 })
	return row
end

function Lib:ColorRow(sec, text, bind, title)
	local row = Row(sec.Body, 13)
	RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, 0), TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text, Parent = row,
	}), "TextColor3", "Text")
	Lib:ColorSwatch(row, { Bind = bind, Title = title or (text .. " Color"), Size = 10, Offset = 1 })
	return row
end

function Lib:InfoRow(sec, label)
	local row = Row(sec.Body, 13)
	local value = RegisterTheme(Text({
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0),
		TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Text = "-",
		Parent = row, TextTruncate = Enum.TextTruncate.AtEnd,
	}), "TextColor3", "Text")
	RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.new(0, 60, 1, 0), TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, Text = label .. ":",
		Parent = row, ZIndex = 2,
	}), "TextColor3", "TextFaint")
	return { Set = function(v) value.Text = tostring(v) end }
end

-- window ------------------------------------------------------------------
local function Sep(parent, y)
	local f = New("Frame", {
		BorderSizePixel = 0, Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 1), Parent = parent,
	})
	RegisterTheme(f, "BackgroundColor3", "BorderSoft")
	return f
end

local function Column(page, x, w)
	local col = LO(New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, 2), Size = UDim2.new(0, w, 1, -4),
		ScrollBarThickness = 2, ScrollBarImageColor3 = RGB(90, 90, 98),
		ScrollBarImageTransparency = 0.35, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = page,
	}))
	New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = col })
	New("UIPadding", { PaddingLeft = 4, PaddingRight = 4, PaddingTop = 0, PaddingBottom = 6, Parent = col })
	return col
end

function Lib:BuildWindow()
	local gui = New("ScreenGui", {
		Name = "momohax_main", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 200, Parent = Lib.GuiParent,
	})
	Lib.MainGui = gui
	local root = LO(New("CanvasGroup", {
		Name = "Window", Size = UDim2.fromOffset(416, 442),
		Position = UDim2.new(0.5, 0, 0.5, -10), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Parent = gui,
	}))
	RegisterTheme(root, "BackgroundColor3", "Background")
	Corner(root, 4)
	local rst = New("UIStroke", { Thickness = 1, Parent = root })
	RegisterTheme(rst, "Color", "Border")
	Lib.Root = root
	Lib.WindowScale = New("UIScale", { Scale = 1, Parent = root })

	local hl = New("Frame", {
		BackgroundColor3 = RGB(255, 255, 255), BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1), ZIndex = 5, Parent = root,
	})
	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = hl,
	})

	local header = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = root })
	RegisterTheme(Text({
		BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0, 120, 1, 0), TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "momohax", Parent = header,
	}), "TextColor3", "Text")
	local info = RegisterTheme(Text({
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(1, -140, 1, 0), TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = header,
	}), "TextColor3", "TextFaint")
	info.Text = string.format("%s / Uid 1337 / Build: Beta", (LocalPlayer and LocalPlayer.Name) or "player")
	Sep(root, 28)

	local nav = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, 0, 0, 18), Parent = root })
	Lib.Pages = {}
	Lib.NavButtons = {}
	for i, name in ipairs({ "Combat", "Visuals", "Misc", "Players", "Settings" }) do
		local b = LO(New("TextButton", {
			AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
			Position = UDim2.new((i - 1) / 5, 0, 0, 0), Size = UDim2.new(1 / 5, 0, 1, 0), Parent = nav,
		}))
		local bg = RegisterTheme(New("Frame", {
			BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 1, -2), Position = UDim2.new(0, 3, 0, 1), Parent = b,
		}), "BackgroundColor3", "NavSel")
		Corner(bg, 2)
		local lbl = RegisterTheme(Text({
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			TextSize = 11, Text = name, Parent = b,
		}), "TextColor3", "TextDim")
		Hover(b, 2, 0.96)
		b.Activated:Connect(function() Lib:SelectTab(i) end)
		Lib.NavButtons[i] = { Button = b, Bg = bg, Label = lbl }
	end
	Sep(root, 47)

	local content = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48), Parent = root,
	})
	Lib.Content = content
	for i = 1, 5 do
		Lib.Pages[i] = LO(New("Frame", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Visible = (i == 1), Parent = content,
		}))
	end
	Lib.DropdownLayer = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = root,
	})
	Lib.MakeDraggable(root, header)
	Lib:SelectTab(1)
end

function Lib:SelectTab(i)
	Lib.CurrentTab = i
	for j, nb in ipairs(Lib.NavButtons) do
		local sel = (j == i)
		nb.Bg.BackgroundTransparency = sel and 0 or 1
		nb.Label.TextColor3 = sel and Lib.Theme.Text or Lib.Theme.TextDim
	end
	for j, page in ipairs(Lib.Pages) do
		page.Visible = (j == i)
	end
end

-- combat page -------------------------------------------------------------
local function BuildCombatPage(page)
	local F = Lib.Flags
	local colL = Column(page, 0, 202)
	local colR = Column(page, 204, 212)

	local secA = Lib:Section(colL, "Aimbot")
	Lib:Toggle(secA, { Text = "Enabled", Bind = { F.Aimbot, "Enabled" }, Keybind = { t = F.Aimbot, k = "Key" } })
	Lib:Toggle(secA, { Text = "Silent Aim", Bind = { F.Aimbot, "SilentAim" }, Keybind = { t = F.Aimbot, k = "SilentKey" } })
	Lib:Toggle(secA, { Text = "Show Fov", Bind = { F.Aimbot, "ShowFov" }, Swatch = { t = F.Aimbot, k = "FovColor" }, SwatchTitle = "FOV Color" })
	Lib:Toggle(secA, { Text = "Auto Fire", Bind = { F.Aimbot, "AutoFire" } })
	Lib:Slider(secA, { Label = "Field Of View", Min = 5, Max = 250, Bind = { F.Aimbot, "FOV" } })
	Lib:Slider(secA, { Label = "Smoothness", Min = 0, Max = 100, Bind = { F.Aimbot, "Smoothness" }, Suffix = "%" })
	Lib:Dropdown(secA, { Label = "Hit Part", Values = { "Head", "Torso", "Arms", "Legs", "Feet" }, Multi = true, Bind = { F.Aimbot, "HitPart" } })
	Lib:Dropdown(secA, { Label = "Priority", Values = { "Lowest Health", "Closest", "Distance" }, Bind = { F.Aimbot, "Priority" } })

	local secT = Lib:Section(colL, "Triggerbot")
	Lib:Toggle(secT, { Text = "Enabled", Bind = { F.Triggerbot, "Enabled" }, Keybind = { t = F.Triggerbot, k = "Key" } })
	Lib:Slider(secT, { Label = "Delay", Min = 0, Max = 500, Bind = { F.Triggerbot, "Delay" }, Suffix = "ms" })
	Lib:RangeSlider(secT, { Label = "Reaction Time", Min = 10, Max = 400, BindMin = { F.Triggerbot, "ReactionMin" }, BindMax = { F.Triggerbot, "ReactionMax" }, Suffix = "ms" })
	Lib:ListBox(secT, { Values = { "Arms", "Legs", "Feet" }, Bind = { F.Triggerbot, "Parts" }, Height = 52 })

	Lib.BuildVisualsSection(colR)
	Lib.BuildMiscSection(colR)
end

-- visuals section (shared: combat page right column + visuals tab) --------
function Lib.BuildVisualsSection(parent)
	local F = Lib.Flags
	local sec = Lib:Section(parent, "Visuals")
	Lib:Toggle(sec, { Text = "Boxes", Bind = { F.Visuals, "Boxes" }, Cog = { t = F.Visuals, k = "FillColor" }, Swatch = { t = F.Visuals, k = "FillColor" }, SwatchTitle = "Fill Color" })
	Lib:Toggle(sec, { Text = "Names", Bind = { F.Visuals, "Names" }, Keybind = { t = F.Visuals, k = "NamesKey" } })
	Lib:Toggle(sec, { Text = "Health Bar", Bind = { F.Visuals, "HealthBar" }, Swatch = { t = F.Visuals, k = "HealthColor" }, SwatchTitle = "Health Bar Color" })
	Lib:Toggle(sec, { Text = "Chams", Bind = { F.Visuals, "Chams" }, Swatch = { t = F.Visuals, k = "ChamColor" }, SwatchTitle = "Chams Color" })
	Lib:Toggle(sec, { Text = "Fill", Bind = { F.Visuals, "Fill" } })
	Lib:Slider(sec, { Label = "Thickness", Min = 1, Max = 10, Bind = { F.Visuals, "Thickness" }, Suffix = "px" })
	Lib:Toggle(sec, { Text = "Tracers", Bind = { F.Visuals, "Tracers" }, Swatch = { t = F.Visuals, k = "TracerColor" }, SwatchTitle = "Tracer Color" })
	Lib:Toggle(sec, { Text = "Skeleton", Bind = { F.Visuals, "Skeleton" }, Swatch = { t = F.Visuals, k = "SkeletonColor" }, SwatchTitle = "Skeleton Color" })
	Lib:Toggle(sec, { Text = "Outline", Bind = { F.Visuals, "Outline" }, Swatch = { t = F.Visuals, k = "OutlineColor" }, SwatchTitle = "Outline Color" })
	Lib:Dropdown(sec, { Label = "Box Type", Values = { "Corner", "Full", "Cross" }, Bind = { F.Visuals, "BoxType" } })
	return sec
end

-- misc section (shared: combat page right column + misc tab) --------------
function Lib.BuildMiscSection(parent)
	local F = Lib.Flags
	local sec = Lib:Section(parent, "Misc")

	local trow = Row(sec.Body, 14)
	Lib:IconButton(trow, "plus", function() Lib:CreateConfig(F.Misc.ConfigName) end, UDim2.fromOffset(0, 0))
	Lib:IconButton(trow, "up", function() Lib:NudgeConfig(-1) end, UDim2.fromOffset(16, 0))
	Lib:IconButton(trow, "down", function() Lib:NudgeConfig(1) end, UDim2.fromOffset(32, 0))
	Lib:IconButton(trow, "left", function() Lib:CycleConfig(-1) end, UDim2.fromOffset(48, 0))
	Lib:IconButton(trow, "right", function() Lib:CycleConfig(1) end, UDim2.fromOffset(64, 0))

	Lib:Toggle(sec, { Text = "Watermark", Bind = { F.Misc, "Watermark" }, OnChanged = function(v) Lib.SetWatermark(v) end })
	Lib:Toggle(sec, { Text = "Keybind List", Bind = { F.Misc, "KeybindList" }, Keybind = { t = F.Binds, k = "KeybindList" }, OnChanged = function(v) Lib.SetKeybindPanel(v) end })
	Lib:Toggle(sec, { Text = "Player List", Bind = { F.Misc, "PlayerList" }, Disabled = true, RightTag = "[SOON]" })

	Row(sec.Body, 2)
	Lib:TextBox(sec, { Label = "Config Name", Bind = { F.Misc, "ConfigName" } })
	Lib:Button(sec, { Text = "Legit", OnClick = function() Lib:ApplyLegitPreset() end })
	Lib:Button(sec, { Text = "Create Config", OnClick = function() Lib:CreateConfig(F.Misc.ConfigName) end })
	Lib:ButtonRow(sec, {
		{ Text = "Save", OnClick = function() Lib:SaveConfig(F.Misc.ConfigName) end },
		{ Text = "Load", OnClick = function() Lib:LoadConfig(F.Misc.ConfigName) end },
	})
	Lib:ButtonRow(sec, {
		{ Text = "Delete", OnClick = function() Lib:DeleteConfig(F.Misc.ConfigName) end },
		{ Text = "Refresh", OnClick = function() Lib:RefreshConfigs() end },
		{ Text = "Reset", OnClick = function() Lib:ResetUI() end },
	})

	local lrow = Row(sec.Body, 13)
	RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.new(0, 70, 1, 0), TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "Last Saved", Parent = lrow,
	}), "TextColor3", "TextFaint")
	local ls = RegisterTheme(Text({
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(1, -74, 1, 0), TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right, Text = F.Misc.LastSaved, Parent = lrow,
	}), "TextColor3", "Text")
	RegisterApplier(function() ls.Text = F.Misc.LastSaved end)
end

function Lib:ApplyLegitPreset()
	local F = Lib.Flags
	MergeInto(F.Aimbot, { Enabled = true, SilentAim = false, ShowFov = false, AutoFire = false, FOV = 25, Smoothness = 45, HitPart = { "Head" }, Priority = "Closest" })
	MergeInto(F.Triggerbot, { Enabled = true, Delay = 120, ReactionMin = 100, ReactionMax = 180, Parts = { "Arms" } })
	MergeInto(F.Visuals, { Fill = false, Thickness = 1, BoxType = "Corner" })
	Lib.RunAppliers()
	EmitAll()
end

-- players page ------------------------------------------------------------
function Lib:BuildPlayersPage(page)
	local colL = Column(page, 0, 202)
	local colR = Column(page, 204, 212)

	local sec = Lib:Section(colL, "Players")
	local frame = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 250),
		Parent = sec.Body,
	}), "BackgroundColor3", "ListBg")
	local fst = New("UIStroke", { Thickness = 1, Parent = frame })
	RegisterTheme(fst, "Color", "BorderSoft")
	local list = New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 2, ScrollBarImageColor3 = RGB(90, 90, 98),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = frame,
	})
	Lib.PlayerList = { Container = frame, List = list, Rows = {} }
	Lib:Button(sec, { Text = "Refresh", OnClick = function() Lib:RefreshPlayerList() end })

	local secS = Lib:Section(colR, "Selected")
	Lib.PlayerInfo = {
		Name = Lib:InfoRow(secS, "Name"),
		Display = Lib:InfoRow(secS, "Display"),
		Uid = Lib:InfoRow(secS, "Uid"),
	}
	Lib.PlayerControlsSec = Lib:Section(colR, "Visuals")
	Lib:RebuildPlayerControls()

	Connect(Players.PlayerAdded, function() Lib:RefreshPlayerList() end)
	Connect(Players.PlayerRemoving, function(plr)
		Lib.Flags.Players[plr.Name] = nil
		Lib:RefreshPlayerList()
	end)
	Lib:RefreshPlayerList()
end

function Lib:GetPlayerFlags(plr)
	local t = Lib.Flags.Players[plr.Name]
	if not t then
		t = Clone(Lib.PlayerTemplate())
		Lib.Flags.Players[plr.Name] = t
	end
	return t
end

function Lib:RefreshPlayerList()
	local P = Lib.PlayerList
	if not P then return end
	P.List:ClearAllChildren()
	P.Rows = {}
	New("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = P.List })
	New("UIPadding", { PaddingLeft = 3, PaddingRight = 4, PaddingTop = 2, PaddingBottom = 2, Parent = P.List })
	local count = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			count += 1
			local rb = LO(New("TextButton", {
				AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 15), Parent = P.List,
			}))
			RegisterTheme(Text({
				BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left, Text = plr.Name, Parent = rb,
			}), "TextColor3", "TextDim")
			Hover(rb, nil, 0.92)
			P.Rows[plr.Name] = rb
			rb.Activated:Connect(function() Lib:SelectPlayer(plr) end)
		end
	end
	if count == 0 then
		RegisterTheme(Text({
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 15), TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left, Text = "No players found", Parent = P.List,
		}), "TextColor3", "TextFaint")
	end
	if Lib.SelectedPlayer and not Lib.SelectedPlayer.Parent then
		Lib.SelectedPlayer = nil
		Lib:UpdatePlayerInfo()
		Lib:RebuildPlayerControls()
	end
	Lib:HighlightPlayerRows()
end

function Lib:HighlightPlayerRows()
	local P = Lib.PlayerList
	if not P then return end
	for name, rb in pairs(P.Rows) do
		local sel = Lib.SelectedPlayer ~= nil and Lib.SelectedPlayer.Name == name
		Tween(rb, { BackgroundTransparency = sel and 0.85 or 1 }, 0.08)
		local lbl = rb:FindFirstChildOfClass("TextLabel")
		if lbl then lbl.TextColor3 = sel and Lib.Theme.Text or Lib.Theme.TextDim end
	end
end

function Lib:SelectPlayer(plr)
	Lib.SelectedPlayer = plr
	Lib:UpdatePlayerInfo()
	Lib:HighlightPlayerRows()
	Lib:RebuildPlayerControls()
end

function Lib:UpdatePlayerInfo()
	if not Lib.PlayerInfo then return end
	local plr = Lib.SelectedPlayer
	if plr then
		Lib.PlayerInfo.Name.Set(plr.Name)
		Lib.PlayerInfo.Display.Set(plr.DisplayName)
		Lib.PlayerInfo.Uid.Set(plr.UserId)
	else
		Lib.PlayerInfo.Name.Set("-")
		Lib.PlayerInfo.Display.Set("-")
		Lib.PlayerInfo.Uid.Set("-")
	end
end

function Lib:RebuildPlayerControls()
	local sec = Lib.PlayerControlsSec
	if not sec then return end
	if Lib.PlayerScope then Lib.PlayerScope:Clear() end
	Lib.PlayerScope = Lib:NewScope()
	sec.Body:ClearAllChildren()
	New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sec.Body })
	New("UIPadding", { PaddingLeft = 3, PaddingRight = 3, PaddingTop = 2, PaddingBottom = 1, Parent = sec.Body })
	local plr = Lib.SelectedPlayer
	if not plr then
		RegisterTheme(Text({
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left, Text = "No player selected", Parent = sec.Body,
		}), "TextColor3", "TextFaint")
		return
	end
	local pf = Lib:GetPlayerFlags(plr)
	local scope = Lib.PlayerScope
	Lib:Toggle(sec, { Text = "Boxes", Bind = { pf, "Boxes" }, Scope = scope })
	Lib:Toggle(sec, { Text = "Names", Bind = { pf, "Names" }, Scope = scope })
	Lib:Toggle(sec, { Text = "Health Bar", Bind = { pf, "HealthBar" }, Scope = scope })
	Lib:Toggle(sec, { Text = "Tracers", Bind = { pf, "Tracers" }, Scope = scope })
	Lib:Toggle(sec, { Text = "Chams", Bind = { pf, "Chams" }, Scope = scope })
	Lib:Dropdown(sec, { Label = "Priority", Values = { "Lowest Health", "Closest", "Distance" }, Bind = { pf, "Priority" }, Scope = scope })
end

-- settings page -----------------------------------------------------------
function Lib:BuildSettingsPage(page)
	local F = Lib.Flags
	local colL = Column(page, 0, 202)
	local colR = Column(page, 204, 212)

	local secI = Lib:Section(colL, "Interface")
	Lib:Slider(secI, { Label = "UI Scale", Min = 50, Max = 150, Bind = { F.Settings, "UIScale" }, Suffix = "%", OnChanged = function() Lib:ApplyScale() end })
	Lib:Slider(secI, { Label = "UI Opacity", Min = 30, Max = 100, Bind = { F.Settings, "Opacity" }, Suffix = "%", OnChanged = function() Lib:ApplyOpacity() end })
	Lib:Dropdown(secI, { Label = "Theme", Values = { "Dark", "Midnight", "Light" }, Bind = { F.Settings, "Theme" }, OnChanged = function(v) Lib:SetTheme(v) end })
	Lib:ColorRow(secI, "Accent", { t = F.Settings, k = "Accent" }, "Accent Color")
	Watch(F.Settings.Accent, function() Lib:SetAccent() end)
	Lib:Toggle(secI, { Text = "Animations", Bind = { F.Settings, "Animations" } })
	Lib:Slider(secI, { Label = "Animation Speed", Min = 0.25, Max = 2, Step = 0.05, Bind = { F.Settings, "AnimSpeed" }, Format = function(v) return string.format("%.2fx", v) end })

	local secM = Lib:Section(colR, "Menu")
	Lib:KeybindRow(secM, "Menu Key", { t = F.Binds, k = "Menu" })
	Lib:KeybindRow(secM, "Keybind List", { t = F.Binds, k = "KeybindList" })
	Lib:KeybindRow(secM, "Panic Key", { t = F.Binds, k = "Panic" })

	local secC = Lib:Section(colR, "Config")
	Lib:TextBox(secC, { Label = "Config Name", Bind = { F.Misc, "ConfigName" } })
	Lib:ButtonRow(secC, {
		{ Text = "Save UI", OnClick = function() Lib:SaveUIConfig() end },
		{ Text = "Load UI", OnClick = function() Lib:LoadUIConfig() end },
	})
	Lib:Button(secC, { Text = "Reset UI", OnClick = function() Lib:ResetUI(true) end })
end

-- color picker ------------------------------------------------------------
function Lib:BuildColorPicker()
	local gui = New("ScreenGui", {
		Name = "momohax_picker", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 400, Parent = Lib.GuiParent,
	})
	Lib.PickerGui = gui
	local root = LO(New("CanvasGroup", {
		Size = UDim2.fromOffset(154, 172), Position = UDim2.new(0.5, 240, 0.5, -120),
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Visible = false, Parent = gui,
	}))
	RegisterTheme(root, "BackgroundColor3", "Background")
	Corner(root, 3)
	local rst = New("UIStroke", { Thickness = 1, Parent = root })
	RegisterTheme(rst, "Color", "Border")
	Lib.PickerScale = New("UIScale", { Scale = 1, Parent = root })
	Lib.Picker = { Gui = gui, Root = root, Target = nil, OpenId = 0 }

	local title = LO(New("TextButton", {
		AutoButtonColor = false, Text = "", BackgroundTransparency = 0,
		Size = UDim2.fromOffset(64, 13), Parent = root,
	}))
	RegisterTheme(title, "BackgroundColor3", "Box")
	local tst = New("UIStroke", { Thickness = 1, Parent = title })
	RegisterTheme(tst, "Color", "Border")
	Lib.PickerTitle = RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextSize = 10,
		Text = "Fill Color", Parent = title,
	}), "TextColor3", "Text")
	Hover(title, 2, 0.94)
	MakeDraggable(root, title)

	local tabrow = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 14),
		Size = UDim2.new(1, -8, 0, 15), Parent = root,
	})
	Lib.PickerTabs = {}
	for i, name in ipairs({ "Color", "Animations" }) do
		local b = LO(New("TextButton", {
			AutoButtonColor = false, Text = "", BackgroundTransparency = 0,
			Position = UDim2.new((i - 1) / 2, (i - 1) * 2, 0, 0),
			Size = UDim2.new(0.5, -2, 1, 0), Parent = tabrow,
		}))
		RegisterTheme(b, "BackgroundColor3", "Header")
		local lbl = RegisterTheme(Text({
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextSize = 10,
			Text = name, Parent = b,
		}), "TextColor3", "TextDim")
		Hover(b, 2, 0.94)
		b.Activated:Connect(function() Lib:SelectPickerTab(i) end)
		Lib.PickerTabs[i] = { Button = b, Label = lbl }
	end
	Lib.PickerBodies = {}
	for i = 1, 2 do
		Lib.PickerBodies[i] = New("Frame", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 31),
			Size = UDim2.new(1, -8, 1, -35), Visible = (i == 1), Parent = root,
		})
	end
	Lib:BuildPickerSV(Lib.PickerBodies[1])
	Lib:BuildPickerInputs(Lib.PickerBodies[1])
	Lib.PickerAnimSec = Lib:Section(Lib.PickerBodies[2], nil, true)
	Lib:SelectPickerTab(1)
end

function Lib:SelectPickerTab(i)
	Lib.PickerTab = i
	for j, tab in ipairs(Lib.PickerTabs) do
		local sel = (j == i)
		tab.Button.BackgroundTransparency = sel and 0 or 0.55
		tab.Label.TextColor3 = sel and Lib.Theme.Text or Lib.Theme.TextDim
	end
	for j, body in ipairs(Lib.PickerBodies) do
		body.Visible = (j == i)
	end
end

function Lib:BuildPickerSV(b1)
	local P = Lib.Picker
	local sv = New("Frame", {
		BackgroundColor3 = RGB(255, 0, 0), BorderSizePixel = 0, Size = UDim2.fromOffset(96, 96),
		Active = true, Parent = b1,
	})
	local ov1 = New("Frame", { BackgroundColor3 = RGB(255, 255, 255), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sv })
	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = ov1,
	})
	local ov2 = New("Frame", { BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = sv })
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = ov2,
	})
	local cursor = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(7, 7),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 3, Parent = sv,
	})
	New("UIStroke", { Color = RGB(0, 0, 0), Thickness = 1, Parent = cursor })
	local inner = New("Frame", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(5, 5),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = cursor,
	})
	New("UIStroke", { Color = RGB(255, 255, 255), Thickness = 1, Parent = inner })
	P.SV = sv
	P.SVCursor = cursor

	local hue = New("Frame", {
		BorderSizePixel = 0, Position = UDim2.fromOffset(100, 0),
		Size = UDim2.fromOffset(10, 96), Active = true, Parent = b1,
	})
	New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, RGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, RGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.33, RGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.50, RGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.67, RGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.83, RGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1.00, RGB(255, 0, 0)),
		}),
		Parent = hue,
	})
	local hhandle = New("Frame", {
		BackgroundColor3 = RGB(255, 255, 255), BorderSizePixel = 0, Size = UDim2.fromOffset(14, 2),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), ZIndex = 2, Parent = hue,
	})
	New("UIStroke", { Color = RGB(0, 0, 0), Thickness = 1, Parent = hhandle })
	P.Hue = hue
	P.HueHandle = hhandle

	local function DragSide(obj, onMove)
		local dragging = false
		obj.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				onMove(input.Position)
			end
		end)
		BindConn(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end))
		BindConn(UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				onMove(input.Position)
			end
		end))
	end
	DragSide(sv, function(m)
		local p, s = sv.AbsolutePosition, sv.AbsoluteSize
		P.S = math.clamp((m.X - p.X) / s.X, 0, 1)
		P.V = 1 - math.clamp((m.Y - p.Y) / s.Y, 0, 1)
		Lib:PickerApplyColor()
	end)
	DragSide(hue, function(m)
		local p, s = hue.AbsolutePosition, hue.AbsoluteSize
		P.H = math.clamp((m.Y - p.Y) / s.Y, 0, 1)
		Lib:PickerApplyColor()
	end)
end

function Lib:BuildPickerInputs(b1)
	local P = Lib.Picker
	local prev = RegisterTheme(New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 102), Size = UDim2.fromOffset(12, 15), Parent = b1,
	}), "BackgroundColor3", "Accent")
	local pst = New("UIStroke", { Thickness = 1, Parent = prev })
	RegisterTheme(pst, "Color", "Border")
	P.Preview = prev

	local rgb = RegisterTheme(New("TextBox", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 102), Size = UDim2.new(1, -16, 0, 15),
		Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "", ClearTextOnFocus = false, ClipsDescendants = true, Parent = b1,
	}), "BackgroundColor3", "Box")
	New("UIPadding", { PaddingLeft = 4, Parent = rgb })
	local rgbst = New("UIStroke", { Thickness = 1, Parent = rgb })
	RegisterTheme(rgbst, "Color", "Border")
	RegisterTheme(rgb, "TextColor3", "Text")
	P.RgbBox = rgb

	local hex = RegisterTheme(New("TextBox", {
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 119), Size = UDim2.new(1, 0, 0, 15),
		Font = Enum.Font.Code, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "", ClearTextOnFocus = false, ClipsDescendants = true, Parent = b1,
	}), "BackgroundColor3", "Box")
	New("UIPadding", { PaddingLeft = 4, Parent = hex })
	local hexst = New("UIStroke", { Thickness = 1, Parent = hex })
	RegisterTheme(hexst, "Color", "Border")
	RegisterTheme(hex, "TextColor3", "Text")
	P.HexBox = hex

	rgb.FocusLost:Connect(function()
		local bind = P.Target
		if not bind then return end
		local c = bind.t[bind.k]
		local r, g, b, a = ParseRGB(rgb.Text)
		if r and type(c) == "table" then
			c.r, c.g, c.b = math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5)
			if a then c.a = a end
			P.H, P.S, P.V = HSVOf(c)
			Emit(bind.t)
			Emit(c)
		end
		Lib:PickerSyncVisuals()
	end)
	hex.FocusLost:Connect(function()
		local bind = P.Target
		if not bind then return end
		local c = bind.t[bind.k]
		local r, g, b, a = ParseHex(hex.Text)
		if r and type(c) == "table" then
			c.r, c.g, c.b = r, g, b
			if a then c.a = a end
			P.H, P.S, P.V = HSVOf(c)
			Emit(bind.t)
			Emit(c)
		end
		Lib:PickerSyncVisuals()
	end)
end

function Lib:PickerApplyColor()
	local P = Lib.Picker
	local bind = P.Target
	if not bind then return end
	local c = bind.t[bind.k]
	if type(c) ~= "table" then return end
	SetRGB(c, Color3.fromHSV(P.H, P.S, P.V))
	Emit(bind.t)
	Emit(c)
	Lib:PickerSyncVisuals()
end

function Lib:PickerSyncVisuals()
	local P = Lib.Picker
	if not P.SV then return end
	P.SV.BackgroundColor3 = Color3.fromHSV(P.H or 0, 1, 1)
	P.SVCursor.Position = UDim2.new(P.S or 0, 0, 1 - (P.V or 1), 0)
	P.HueHandle.Position = UDim2.new(0.5, 0, P.H or 0, 0)
	local bind = P.Target
	if bind and type(bind.t[bind.k]) == "table" then
		local c = bind.t[bind.k]
		P.Preview.BackgroundColor3 = ColorOf(c)
		P.Preview.BackgroundTransparency = math.clamp(1 - (c.a or 1), 0, 1)
		if not P.RgbBox:IsFocused() then
			P.RgbBox.Text = string.format("%d, %d, %d, %.2f", c.r, c.g, c.b, c.a or 1)
		end
		if not P.HexBox:IsFocused() then
			P.HexBox.Text = HexOf(c)
		end
	end
end

function Lib:OpenColorPicker(bind, title, near)
	local P = Lib.Picker
	if not P.Root then return end
	local c = bind.t[bind.k]
	if type(c) ~= "table" then return end
	P.Target = bind
	P.OpenId = (P.OpenId or 0) + 1
	P.Title.Text = title or "Color"
	P.H, P.S, P.V = HSVOf(c)
	Watch(c, function()
		local t = Lib.Picker.Target
		if t and t.t[t.k] == c then Lib:PickerSyncVisuals() end
	end)
	if P.AnimScope then P.AnimScope:Clear() end
	P.AnimScope = Lib:NewScope()
	local sec = P.AnimSec
	sec.Body:ClearAllChildren()
	New("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sec.Body })
	New("UIPadding", { PaddingLeft = 3, PaddingRight = 3, PaddingTop = 2, PaddingBottom = 1, Parent = sec.Body })
	local meta = GetColorMeta(c)
	Lib:Dropdown(sec, { Label = "Animation", Values = { "Fade", "Slide", "Instant" }, Bind = { meta, "Animation" } })
	Lib:Dropdown(sec, { Label = "Color Animation", Values = { "Static", "Rainbow", "Pulse" }, Bind = { meta, "ColorAnimation" } })
	Lib:Slider(sec, { Label = "Speed", Min = 0.1, Max = 5, Step = 0.1, Bind = { meta, "Speed" }, Format = function(v) return string.format("%.1fx", v) end, Scope = P.AnimScope })
	Lib:PickerSyncVisuals()
	Lib:ShowPicker(near)
end

function Lib:ShowPicker(near)
	local P = Lib.Picker
	local root = P.Root
	P.OpenId = (P.OpenId or 0) + 1
	if near then
		local ap = near.AbsolutePosition
		local s = Lib.AppliedScale()
		local cam = workspace.CurrentCamera
		local vw, vh = 1920, 1080
		if cam then vw, vh = cam.ViewportSize.X, cam.ViewportSize.Y end
		local x = math.clamp((ap.X + 16) / s, 4, vw / s - 160)
		local y = math.clamp((ap.Y - 20) / s, 4, vh / s - 180)
		root.Position = UDim2.fromOffset(x, y)
	end
	local style = "Fade"
	if P.Target then
		style = GetColorMeta(P.Target.t[P.Target.k]).Animation or "Fade"
	end
	root.Visible = true
	if style == "Instant" then
		root.GroupTransparency = 0
	elseif style == "Slide" then
		root.GroupTransparency = 0
		local start = root.Position
		root.Position = UDim2.new(start.X.Scale, start.X.Offset, start.Y.Scale, start.Y.Offset + 10)
		Tween(root, { Position = start }, 0.15)
	else
		root.GroupTransparency = 1
		Tween(root, { GroupTransparency = 0 }, 0.12)
	end
end

function Lib:ClosePicker()
	local P = Lib.Picker
	if not P.Root or not P.Root.Visible then return end
	local style = "Fade"
	if P.Target then
		style = GetColorMeta(P.Target.t[P.Target.k]).Animation or "Fade"
	end
	P.OpenId = (P.OpenId or 0) + 1
	local id = P.OpenId
	if style == "Instant" then
		P.Root.Visible = false
	else
		Tween(P.Root, { GroupTransparency = 1 }, 0.1)
		task.delay(0.11, function()
			if P.OpenId == id then P.Root.Visible = false end
		end)
	end
end

-- animated colors (rainbow / pulse) ---------------------------------------
BindConn(RunService.Heartbeat:Connect(function(dt)
	for c, meta in pairs(Lib.ColorMetas) do
		local anim = meta.ColorAnimation
		if anim == "Rainbow" then
			local h, s, v = HSVOf(c)
			h = (h + dt * 0.12 * (meta.Speed or 2)) % 1
			SetRGB(c, Color3.fromHSV(h, s, v))
			Emit(c)
		elseif anim == "Pulse" then
			meta.Phase = (meta.Phase + dt * (meta.Speed or 2) * 0.5) % 1000
			c.a = 0.35 + 0.6 * (0.5 + 0.5 * math.sin(meta.Phase * math.pi))
			Emit(c)
		end
	end
end))

-- keybinds panel ----------------------------------------------------------
function Lib:BuildKeybindPanel()
	local gui = New("ScreenGui", {
		Name = "momohax_keybinds", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 300, Parent = Lib.GuiParent,
	})
	Lib.KeybindGui = gui
	local root = LO(New("Frame", {
		Size = UDim2.fromOffset(128, 136), Position = UDim2.new(0.5, 280, 0.5, -100),
		BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, Parent = gui,
	}))
	RegisterTheme(root, "BackgroundColor3", "Background")
	Corner(root, 3)
	local rst = New("UIStroke", { Thickness = 1, Parent = root })
	RegisterTheme(rst, "Color", "Border")
	Lib.KeybindScale = New("UIScale", { Scale = 1, Parent = root })

	local title = LO(New("TextButton", {
		AutoButtonColor = false, Text = "", BackgroundTransparency = 0,
		Size = UDim2.fromOffset(56, 13), Parent = root,
	}))
	RegisterTheme(title, "BackgroundColor3", "Box")
	local tst = New("UIStroke", { Thickness = 1, Parent = title })
	RegisterTheme(tst, "Color", "Border")
	RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), TextSize = 10,
		Text = "Keybinds", Parent = title,
	}), "TextColor3", "Text")
	Hover(title, 2, 0.94)
	MakeDraggable(root, title)

	local body = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 15),
		Size = UDim2.new(1, 0, 1, -15), Parent = root,
	})
	local entries = {
		{ "Menu", { t = Lib.Flags.Binds, k = "Menu" } },
		{ "Aimbot", { t = Lib.Flags.Aimbot, k = "Key" } },
		{ "Silent Aim", { t = Lib.Flags.Aimbot, k = "SilentKey" } },
		{ "Triggerbot", { t = Lib.Flags.Triggerbot, k = "Key" } },
		{ "Keybind List", { t = Lib.Flags.Binds, k = "KeybindList" } },
		{ "Peek Assist", { t = Lib.Flags.Binds, k = "PeekAssist" } },
		{ "Speed", { t = Lib.Flags.Binds, k = "Speed" } },
		{ "Fly", { t = Lib.Flags.Binds, k = "Fly" } },
		{ "Panic Key", { t = Lib.Flags.Binds, k = "Panic" } },
	}
	for i, e in ipairs(entries) do
		local row = LO(New("TextButton", {
			AutoButtonColor = false, Text = "", BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, (i - 1) * 12 + 2), Size = UDim2.new(1, -8, 0, 12),
			Parent = body,
		}))
		RegisterTheme(Text({
			BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, 0), TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left, Text = e[1], Parent = row,
		}), "TextColor3", "TextDim")
		Lib:Keybind(row, { Bind = e[2], TextSize = 9, Height = 12, Width = 40 })
	end
	Lib.KeybindPanel = { Gui = gui, Root = root }
	root.Visible = Lib.Flags.Misc.KeybindList
end

function Lib.SetKeybindPanel(v)
	Lib.Flags.Misc.KeybindList = v and true or false
	Emit(Lib.Flags.Misc)
	if Lib.KeybindPanel then
		Lib.KeybindPanel.Root.Visible = Lib.Flags.Misc.KeybindList
	end
end

function Lib:ToggleKeybindPanel()
	Lib.SetKeybindPanel(not Lib.Flags.Misc.KeybindList)
end

-- watermark ---------------------------------------------------------------
function Lib:BuildWatermark()
	local gui = New("ScreenGui", {
		Name = "momohax_watermark", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100, Parent = Lib.GuiParent,
	})
	Lib.WatermarkGui = gui
	local holder = New("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 16),
		Size = UDim2.fromOffset(320, 40), Parent = gui,
	})
	RegisterTheme(Text({
		BackgroundTransparency = 1, Size = UDim2.new(0, 320, 0, 18),
		Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Momohax UI Library Roblox", TextStrokeTransparency = 0.55, Parent = holder,
	}), "TextColor3", "Text")
	local bar = New("Frame", {
		BackgroundColor3 = RGB(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 13), Parent = holder,
	})
	New("UIPadding", { PaddingLeft = 4, PaddingRight = 4, Parent = bar })
	Lib.WatermarkText = RegisterTheme(Text({
		BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 13), TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "momohax / Fps 420 / Build: Beta", Parent = bar,
	}), "TextColor3", "Text")
	Lib.SetWatermark(Lib.Flags.Misc.Watermark)
end

function Lib.SetWatermark(v)
	if Lib.WatermarkGui then
		Lib.WatermarkGui.Enabled = v and true or false
	end
end

-- configuration -----------------------------------------------------------
Lib.MemConfigs = {}
Lib.ConfigOrder = {}
local FSOk = (type(writefile) == "function")
local CONFIG_DIR = "momohax_configs"

local function Sanitize(name)
	return (tostring(name or ""):gsub("[^%w%-_ ]", ""))
end

local function ConfigPath(name)
	return CONFIG_DIR .. "/" .. Sanitize(name) .. ".json"
end

local function EnsureDir()
	if FSOk and not isfolder(CONFIG_DIR) then pcall(makefolder, CONFIG_DIR) end
end

function Lib:RefreshConfigs()
	Lib.ConfigOrder = {}
	if FSOk then
		EnsureDir()
		local ok, files = pcall(listdir, CONFIG_DIR)
		if ok and files then
			for _, f in ipairs(files) do
				local base = (f:match("([^/\\]+)$")) or f
				local name = base:match("^(.*)%.json$") or base
				table.insert(Lib.ConfigOrder, name)
			end
		end
	else
		for name in pairs(Lib.MemConfigs) do table.insert(Lib.ConfigOrder, name) end
	end
	table.sort(Lib.ConfigOrder)
end

function Lib:WriteConfig(name, data)
	name = Sanitize(name)
	if name == "" then return false end
	local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
	if not ok then return false end
	if FSOk then
		EnsureDir()
		return pcall(writefile, ConfigPath(name), json)
	else
		Lib.MemConfigs[name] = data
		return true
	end
end

function Lib:ReadConfig(name)
	name = Sanitize(name)
	if name == "" then return nil end
	if FSOk then
		local ok, raw = pcall(readfile, ConfigPath(name))
		if ok and raw then
			local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
			if ok2 then return data end
		end
		return nil
	else
		return Lib.MemConfigs[name]
	end
end

function Lib:CreateConfig(name)
	name = Sanitize(name or Lib.Flags.Misc.ConfigName)
	if name == "" then return end
	Lib:WriteConfig(name, Clone(Lib.Flags))
	Lib:RefreshConfigs()
	Lib.Flags.Misc.LastSaved = os.date("%d/%m/%Y")
	Emit(Lib.Flags.Misc)
end
Lib.SaveConfig = Lib.CreateConfig

function Lib:LoadConfig(name)
	local data = Lib:ReadConfig(name or Lib.Flags.Misc.ConfigName)
	if not data then return end
	MergeInto(Lib.Flags, data)
	Lib:AfterFlagsRestore()
end

function Lib:DeleteConfig(name)
	name = Sanitize(name or Lib.Flags.Misc.ConfigName)
	if name == "" then return end
	if FSOk then pcall(delfile, ConfigPath(name)) else Lib.MemConfigs[name] = nil end
	Lib:RefreshConfigs()
end

function Lib:NudgeConfig(dir)
	local order = Lib.ConfigOrder
	if not order then return end
	local name = Sanitize(Lib.Flags.Misc.ConfigName)
	local i = table.find(order, name)
	if not i then return end
	local j = math.clamp(i + dir, 1, #order)
	order[i], order[j] = order[j], order[i]
end

function Lib:CycleConfig(dir)
	local order = Lib.ConfigOrder
	if not order or #order == 0 then return end
	local name = Sanitize(Lib.Flags.Misc.ConfigName)
	local i = table.find(order, name) or 0
	i = ((i - 1 + dir) % #order) + 1
	Lib.Flags.Misc.ConfigName = order[i]
	Emit(Lib.Flags.Misc)
end

-- UI config (settings + binds) --------------------------------------------
function Lib:SaveUIConfig()
	local name = Sanitize(Lib.Flags.Misc.ConfigName)
	if name == "" then name = "ui" end
	Lib:WriteConfig("ui_" .. name, { Settings = Clone(Lib.Flags.Settings), Binds = Clone(Lib.Flags.Binds) })
	Lib.Flags.Misc.LastSaved = os.date("%d/%m/%Y")
	Emit(Lib.Flags.Misc)
end

function Lib:LoadUIConfig()
	local payload = Lib:ReadConfig(Lib.Flags.Misc.ConfigName)
	if not payload then
		payload = Lib:ReadConfig("ui_" .. Sanitize(Lib.Flags.Misc.ConfigName))
	end
	if not payload then return end
	if type(payload) == "table" then
		if payload.Settings then MergeInto(Lib.Flags.Settings, payload.Settings) end
		if payload.Binds then MergeInto(Lib.Flags.Binds, payload.Binds) end
	end
	Lib:AfterFlagsRestore()
end

function Lib:AfterFlagsRestore()
	Lib:SetTheme(Lib.Flags.Settings.Theme)
	Lib:ApplyScale()
	Lib:ApplyOpacity()
	Lib.SetWatermark(Lib.Flags.Misc.Watermark)
	Lib.SetKeybindPanel(Lib.Flags.Misc.KeybindList)
	Lib.RunAppliers()
	EmitAll()
end

function Lib:ResetUI(recenter)
	MergeInto(Lib.Flags, Lib.Defaults)
	Lib:AfterFlagsRestore()
	if recenter and Lib.Root then
		Lib.Root.Position = UDim2.new(0.5, 0, 0.5, -10)
	end
end

-- settings appliers -------------------------------------------------------
function Lib:ApplyScale()
	local s = Lib.AppliedScale()
	for _, sc in ipairs({ Lib.WindowScale, Lib.PickerScale, Lib.KeybindScale }) do
		if sc then sc.Scale = s end
	end
end

function Lib:ApplyOpacity()
	if Lib.Root then
		Tween(Lib.Root, { GroupTransparency = math.clamp(1 - (Lib.Flags.Settings.Opacity or 100) / 100, 0, 1) }, 0.15)
	end
end

function Lib:SetTheme(name)
	if Themes[name] then
		Lib.Flags.Settings.Theme = name
		Lib.Theme = Themes[name]
	end
	Lib.Theme.Accent = ColorOf(Lib.Flags.Settings.Accent)
	ApplyTheme()
	Lib:SelectTab(Lib.CurrentTab or 1)
	Lib:SelectPickerTab(Lib.PickerTab or 1)
end

function Lib:SetAccent()
	Lib.Theme.Accent = ColorOf(Lib.Flags.Settings.Accent)
	ApplyTheme()
end

-- visibility / panic ------------------------------------------------------
function Lib:ToggleMain()
	local root = Lib.Root
	if not root then return end
	root.Visible = not root.Visible
	if root.Visible then
		local s = Lib.AppliedScale()
		Lib.WindowScale.Scale = s * 0.97
		Tween(Lib.WindowScale, { Scale = s }, 0.15)
	end
end

function Lib:Panic()
	Lib.PanicState = not Lib.PanicState
	for _, gui in ipairs({ Lib.MainGui, Lib.PickerGui, Lib.KeybindGui, Lib.WatermarkGui }) do
		if gui then gui.Enabled = not Lib.PanicState end
	end
end

-- input -------------------------------------------------------------------
local function InitInput()
	Connect(UserInputService.InputBegan, function(input, gp)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and Lib.ActiveDropdown then
			local m = Vector2.new(input.Position.X, input.Position.Y)
			local dd = Lib.ActiveDropdown
			local inside = dd.HitTest and dd.HitTest(m)
			if not inside then dd.Close() end
		end
		if gp then return end
		if UserInputService:GetFocusedTextBox() then return end
		if (Lib.Captures or 0) > 0 then return end
		if MatchesKey(Lib.Flags.Binds.Menu, input) then
			Lib:ToggleMain()
		elseif MatchesKey(Lib.Flags.Binds.KeybindList, input) then
			Lib:ToggleKeybindPanel()
		elseif MatchesKey(Lib.Flags.Binds.Panic, input) then
			Lib:Panic()
		elseif input.KeyCode == Enum.KeyCode.Escape and Lib.Picker and Lib.Picker.Root and Lib.Picker.Root.Visible then
			Lib:ClosePicker()
		end
	end)
end

local function InitFps()
	local frames = 0
	Connect(RunService.RenderStepped, function() frames += 1 end)
	task.spawn(function()
		while not Lib.Destroyed do
			task.wait(1)
			if Lib.WatermarkText then
				Lib.WatermarkText.Text = ("momohax / Fps %d / Build: Beta"):format(frames)
			end
			frames = 0
		end
	end)
end

-- boot --------------------------------------------------------------------
function Lib:Init()
	local ok, hui = pcall(function() return (gethui and gethui()) end)
	if ok and hui then
		Lib.GuiParent = hui
	else
		Lib.GuiParent = LocalPlayer:WaitForChild("PlayerGui")
	end
	local cam = workspace.CurrentCamera
	if cam then
		Lib.BaseScale = math.clamp(cam.ViewportSize.Y / 1080, 0.75, 1.25)
	end
	Lib:BuildWindow()
	BuildCombatPage(Lib.Pages[1])
	local colV = Column(Lib.Pages[2], 0, 202)
	Lib.BuildVisualsSection(colV)
	local colM = Column(Lib.Pages[3], 0, 202)
	Lib.BuildMiscSection(colM)
	Lib:BuildPlayersPage(Lib.Pages[4])
	Lib:BuildSettingsPage(Lib.Pages[5])
	Lib:BuildColorPicker()
	Lib:BuildKeybindPanel()
	Lib:BuildWatermark()
	Lib:RefreshConfigs()
	Lib:ApplyScale()
	Lib:ApplyOpacity()
	RegisterApplier(function() Lib:SelectTab(Lib.CurrentTab or 1) end)
	RegisterApplier(function() Lib:SetTheme(Lib.Flags.Settings.Theme) end)
	RegisterApplier(function() Lib:ApplyScale() end)
	RegisterApplier(function() Lib:ApplyOpacity() end)
	RegisterApplier(function() Lib:SetAccent() end)
	InitInput()
	InitFps()
	Lib:SelectTab(1)
end

function Lib:Destroy()
	Lib.Destroyed = true
	for _, c in ipairs(Lib.Connections) do pcall(function() c:Disconnect() end) end
	table.clear(Lib.Connections)
	for _, gui in ipairs({ Lib.MainGui, Lib.PickerGui, Lib.KeybindGui, Lib.WatermarkGui }) do
		if gui then pcall(function() gui:Destroy() end) end
	end
end

if type(getgenv) == "function" then
	getgenv().Momohax = Lib
end

Lib:Init()
