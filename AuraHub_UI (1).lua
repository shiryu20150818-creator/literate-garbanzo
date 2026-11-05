--[[
	AURA HUB  -  Mobile UI (original build)
	Red/Blue animated gradient + glossy gold border
	- "Toggle" pill (Obsidian style): tap = open UI, tap again = close UI
	- Status bar: fps / ping / server players (modelled on the Resonance bar)
	- Toast notifications (info / success / warn / error), Resonance notification sound
	- Key hints [Z] next to buttons/toggles + rebinding + conflict detection + mobile pins
	- Player selector (search + multi select), log, presets (save / export / import)
	- Japanese / English (gear icon), search bar, long-press tooltips
	This is a UI shell: feature bodies are empty Hooks that you can fill in.
]]

-- ======================================================================
-- SERVICES
-- ======================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

local function Notify(title, text, duration)
	StarterGui:SetCore("SendNotification", {
		Title = title,
		Text = text,
		Duration = duration
	})
end

if getgenv().AuraHub then
	pcall(function() getgenv().AuraHub.Unload() end)
end
getgenv().AuraHubPresets = getgenv().AuraHubPresets or {}
local PresetStore = getgenv().AuraHubPresets

-- ======================================================================
-- CONSTANTS / CONFIG
-- ======================================================================
local VERSION = "v1.0"
local APP_NAME = "Aura Hub"
local SOUND_ID = "rbxassetid://97643101798871"
local MOON_ID = "rbxassetid://79685990879972"
local START_TIME = tick()

local Config = {
	Lang = "ja",
	Hints = true,
	StatusBar = true,
	Gold = true,
	GradSpeed = 40,
	Theme = "Crimson",
	Notify = {Sound = true, Volume = 2, Pos = "TR", Duration = 4},
	Keys = {
		Menu = Enum.KeyCode.RightControl,
		Run = Enum.KeyCode.Z,
		StopLag = Enum.KeyCode.X,
		StopSpin = Enum.KeyCode.C,
		CenterTP = Enum.KeyCode.V,
		PlotBreak = Enum.KeyCode.B,
		Third = Enum.KeyCode.N,
	},
	Pins = {},
}
local Lang = Config.Lang
local Store = {}      -- keyed values (sliders / toggles / chips)
local Reg = {}        -- key -> {get, set} (used by presets)

local ActionList = {
	{id = "Menu", ja = "メニュー開閉", en = "Toggle menu", icon = "☰"},
	{id = "Run", ja = "実行", en = "Run", icon = "▶"},
	{id = "StopLag", ja = "ラグ停止", en = "Stop Lag", icon = "⏸"},
	{id = "StopSpin", ja = "回転停止", en = "Stop Spin", icon = "⟲"},
	{id = "CenterTP", ja = "中心TP", en = "Center TP", icon = "◎"},
	{id = "PlotBreak", ja = "Plot Break", en = "Plot Break", icon = "✂"},
	{id = "Third", ja = "三人称", en = "Third Person", icon = "👁"},
}
local ActionRun = {}

-- ======================================================================
-- UTILS
-- ======================================================================
local Conns = {}
local function Connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(Conns, c)
	return c
end

local function RGB(r, g, b) return Color3.fromRGB(r, g, b) end
local NSK = NumberSequenceKeypoint.new
local CSK = ColorSequenceKeypoint.new
local WHITE = Color3.new(1, 1, 1)

local function New(class, props)
	local o = Instance.new(class)
	local parent = nil
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	if parent then o.Parent = parent end
	return o
end

local function Corner(p, r)
	return New("UICorner", {CornerRadius = UDim.new(0, r), Parent = p})
end

local function T(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function ParentGui(g)
	local ok = pcall(function() g.Parent = CoreGui end)
	if not ok or not g.Parent then
		g.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

local function Tr(ja, en)
	if Lang == "ja" then return ja end
	return en
end

local SHORT = {
	RightControl = "RCtrl", LeftControl = "LCtrl", RightShift = "RShift", LeftShift = "LShift",
	RightAlt = "RAlt", LeftAlt = "LAlt", Return = "Enter", Backspace = "Bksp",
	One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
}
local function ShortKey(k)
	if not k then return "-" end
	return SHORT[k.Name] or k.Name
end

local function FmtTime(sec)
	sec = math.floor(sec)
	return string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
end

-- ======================================================================
-- LANGUAGE BINDING
-- ======================================================================
local LangBound = {}
local DynamicFns = {}

local function Txt(inst, ja, en, prop)
	prop = prop or "Text"
	table.insert(LangBound, {inst = inst, ja = ja, en = en, prop = prop})
	inst[prop] = (Lang == "ja") and ja or en
end

local function UpdateDynamic()
	for _, fn in ipairs(DynamicFns) do
		pcall(fn)
	end
end

local function RefreshLang()
	for i = #LangBound, 1, -1 do
		local e = LangBound[i]
		if e.inst.Parent then
			e.inst[e.prop] = (Lang == "ja") and e.ja or e.en
		else
			table.remove(LangBound, i)
		end
	end
	UpdateDynamic()
end

-- ======================================================================
-- THEME / GRADIENTS (red <-> blue, glossy gold)
-- ======================================================================
local Themes = {
	Crimson = {RGB(255, 45, 75), RGB(60, 120, 255)},
	Flame = {RGB(255, 95, 40), RGB(40, 170, 255)},
	Rose = {RGB(255, 70, 150), RGB(85, 95, 255)},
	Royal = {RGB(210, 30, 60), RGB(30, 70, 210)},
}
local RBGrads, GoldGrads = {}, {}

local function RBSeq()
	local th = Themes[Config.Theme]
	return ColorSequence.new({CSK(0, th[1]), CSK(0.5, th[2]), CSK(1, th[1])})
end

local GOLD_SEQ = ColorSequence.new({
	CSK(0, RGB(140, 95, 15)),
	CSK(0.25, RGB(235, 185, 55)),
	CSK(0.45, RGB(255, 248, 215)),
	CSK(0.6, RGB(235, 185, 55)),
	CSK(1, RGB(140, 95, 15)),
})

local function AddRB(parent, rot)
	local g = New("UIGradient", {Color = RBSeq(), Rotation = rot or math.random(0, 359), Parent = parent})
	table.insert(RBGrads, g)
	return g
end

local function AddGold(parent, rot)
	local g = New("UIGradient", {Color = GOLD_SEQ, Rotation = rot or 35, Parent = parent})
	table.insert(GoldGrads, g)
	return g
end

local function GoldStroke(parent, thickness)
	local s = New("UIStroke", {Thickness = thickness, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent})
	AddGold(s)
	return s
end

local function ApplyTheme(name)
	if not Themes[name] then return end
	Config.Theme = name
	local seq = RBSeq()
	for _, g in ipairs(RBGrads) do
		if g.Parent then g.Color = seq end
	end
end

-- ======================================================================
-- ROOT GUI
-- ======================================================================
local Gui = New("ScreenGui", {
	Name = "AuraHub",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
ParentGui(Gui)

local VP = workspace.CurrentCamera.ViewportSize
local BaseScale = math.clamp(math.min(VP.X / 560, VP.Y / 340), 0.6, 1)
local WIN_W, WIN_H = 520, 310

-- drag helper (touch)
local DragHandler, DragEnd = nil, nil
Connect(UserInputService.InputChanged, function(i)
	if DragHandler and i.UserInputType == Enum.UserInputType.Touch then DragHandler(i.Position) end
end)
Connect(UserInputService.InputEnded, function(i)
	if i.UserInputType == Enum.UserInputType.Touch and DragEnd then DragEnd() end
end)
local function MakeDraggable(handle, target, onTap)
	Connect(handle.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		local start = input.Position
		local sp = target.Position
		local moved = false
		DragHandler = function(pos)
			local d = pos - start
			if d.Magnitude > 8 then moved = true end
			if moved then
				target.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
			end
		end
		DragEnd = function()
			DragHandler = nil
			DragEnd = nil
			if not moved and onTap then onTap() end
		end
	end)
end

-- ======================================================================
-- LOG
-- ======================================================================
local Log = {Entries = {}}
local LogList = nil
local LOG_COL = {
	info = RGB(150, 190, 255), success = RGB(110, 235, 150),
	warn = RGB(255, 205, 90), error = RGB(255, 110, 120),
}
local LOG_ICON = {info = "i", success = "✓", warn = "!", error = "×"}

function Log.Add(kind, text)
	local line = string.format("[%s] %s %s", os.date("%H:%M:%S"), LOG_ICON[kind] or "i", text)
	table.insert(Log.Entries, line)
	if #Log.Entries > 200 then table.remove(Log.Entries, 1) end
	if LogList then
		LogList.Add(line, nil, LOG_COL[kind])
		local kids = {}
		for _, c in ipairs(LogList.Frame:GetChildren()) do
			if c:IsA("TextButton") then table.insert(kids, c) end
		end
		if #kids > 200 then kids[1]:Destroy() end
		LogList.Frame.CanvasPosition = Vector2.new(0, 99999)
	end
end

-- ======================================================================
-- TOASTS (with sound)
-- ======================================================================
local ToastHolder = New("Frame", {
	Size = UDim2.new(0, 270, 1, -20),
	BackgroundTransparency = 1,
	ZIndex = 50,
	Parent = Gui,
})
local ToastLayout = New("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ToastHolder})

local function ApplyToastPos(pos)
	Config.Notify.Pos = pos
	if pos == "TR" then
		ToastHolder.AnchorPoint = Vector2.new(1, 0)
		ToastHolder.Position = UDim2.new(1, -10, 0, 64)
		ToastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		ToastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	elseif pos == "TL" then
		ToastHolder.AnchorPoint = Vector2.new(0, 0)
		ToastHolder.Position = UDim2.new(0, 10, 0, 104)
		ToastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		ToastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	elseif pos == "BR" then
		ToastHolder.AnchorPoint = Vector2.new(1, 1)
		ToastHolder.Position = UDim2.new(1, -10, 1, -10)
		ToastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		ToastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	else
		ToastHolder.AnchorPoint = Vector2.new(0, 1)
		ToastHolder.Position = UDim2.new(0, 10, 1, -10)
		ToastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		ToastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	end
end
ApplyToastPos("TR")

local TYPE_STYLE = {
	info = {col = RGB(70, 140, 255), icon = "i", speed = 1.0},
	success = {col = RGB(60, 220, 120), icon = "✓", speed = 1.15},
	warn = {col = RGB(255, 190, 50), icon = "!", speed = 0.9},
	error = {col = RGB(255, 70, 80), icon = "×", speed = 0.75},
}

local function PlaySound(speed)
	local s = Instance.new("Sound")
	s.SoundId = SOUND_ID
	s.Volume = Config.Notify.Volume
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 6)
end

local ActiveToasts = {}
local ToastSeq = 0

local function Toast(kind, title, text, duration)
	local st = TYPE_STYLE[kind] or TYPE_STYLE.info
	duration = duration or Config.Notify.Duration
	Log.Add(kind, title .. ": " .. text)
	if Config.Notify.Sound then PlaySound(st.speed) end

	ToastSeq = ToastSeq + 1
	local side = (Config.Notify.Pos == "TR" or Config.Notify.Pos == "BR") and 1 or -1
	local outer = New("Frame", {Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, LayoutOrder = ToastSeq, Parent = ToastHolder})
	local card = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.new(side * 1.3, 0, 0, 0),
		BackgroundColor3 = RGB(12, 12, 18),
		BackgroundTransparency = 0.04,
		Parent = outer,
	})
	Corner(card, 10)
	GoldStroke(card, 1.5)
	local accent = New("Frame", {Size = UDim2.new(0, 4, 1, -16), Position = UDim2.new(0, 6, 0, 8), BackgroundColor3 = st.col, BorderSizePixel = 0, Parent = card})
	Corner(accent, 2)
	New("TextLabel", {
		Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(18, 9), BackgroundTransparency = 1,
		Text = "☾", Font = Enum.Font.GothamBold, TextSize = 24, TextColor3 = RGB(255, 205, 70), Parent = card,
	})
	New("ImageLabel", {
		Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(18, 9), BackgroundTransparency = 1,
		Image = MOON_ID, Parent = card,
	})
	local c = st.col
	New("TextLabel", {
		Size = UDim2.new(1, -64, 0, 18), Position = UDim2.fromOffset(56, 6), BackgroundTransparency = 1,
		Text = string.format('<font color="rgb(%d,%d,%d)">%s</font> %s', math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), st.icon, title),
		RichText = true, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
	New("TextLabel", {
		Size = UDim2.new(1, -64, 0, 30), Position = UDim2.fromOffset(56, 24), BackgroundTransparency = 1,
		Text = text, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = RGB(190, 195, 215),
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
	local barBg = New("Frame", {Size = UDim2.new(1, -16, 0, 2), Position = UDim2.new(0, 8, 1, -5), BackgroundColor3 = RGB(40, 40, 55), BorderSizePixel = 0, Parent = card})
	local bar = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = st.col, BorderSizePixel = 0, Parent = barBg})

	local removed = false
	local function remove()
		if removed then return end
		removed = true
		for i, o in ipairs(ActiveToasts) do
			if o == outer then table.remove(ActiveToasts, i) break end
		end
		T(card, 0.3, {Position = UDim2.new(side * 1.3, 0, 0, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.32, function() outer:Destroy() end)
	end
	table.insert(ActiveToasts, outer)
	while #ActiveToasts > 5 do
		local old = table.remove(ActiveToasts, 1)
		if old then old:Destroy() end
	end

	T(card, 0.38, {Position = UDim2.new(0, 0, 0, 0)}, Enum.EasingStyle.Back)
	T(bar, duration, {Size = UDim2.new(0, 0, 1, 0)}, Enum.EasingStyle.Linear)
	task.delay(duration, remove)
end

-- ======================================================================
-- MAIN WINDOW
-- ======================================================================
local Holder = New("Frame", {
	Size = UDim2.fromOffset(WIN_W, WIN_H),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = Gui,
})
local Window = New("Frame", {
	Size = UDim2.fromScale(1, 1),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.04,
	ClipsDescendants = true,
	Parent = Holder,
})
Corner(Window, 14)
local WScale = New("UIScale", {Scale = 0.01, Parent = Window})
New("UIGradient", {Color = ColorSequence.new(RGB(18, 16, 30), RGB(8, 8, 16)), Rotation = 65, Parent = Window})
GoldStroke(Window, 2.5)

local TopBar = New("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = RGB(10, 10, 18), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 5, Parent = Window})
local TopLine = New("Frame", {Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 6, Parent = TopBar})
AddRB(TopLine, 0)

New("TextLabel", {Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(10, 8), BackgroundTransparency = 1, Text = "☾", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = RGB(255, 205, 70), ZIndex = 6, Parent = TopBar})
New("ImageLabel", {Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(10, 8), BackgroundTransparency = 1, Image = MOON_ID, ZIndex = 7, Parent = TopBar})
local TitleLbl = New("TextLabel", {
	Size = UDim2.fromOffset(90, 40), Position = UDim2.fromOffset(40, 0), BackgroundTransparency = 1,
	Text = APP_NAME, Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = TopBar,
})
AddRB(TitleLbl, 0)

local SearchBox = New("TextBox", {
	Size = UDim2.fromOffset(170, 26), Position = UDim2.fromOffset(136, 7), BackgroundColor3 = RGB(24, 24, 40),
	Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = WHITE, PlaceholderColor3 = RGB(120, 125, 150),
	ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = TopBar,
})
Corner(SearchBox, 13)
New("UIPadding", {PaddingLeft = UDim.new(0, 28), PaddingRight = UDim.new(0, 8), Parent = SearchBox})
New("TextLabel", {Size = UDim2.fromOffset(20, 26), Position = UDim2.fromOffset(142, 7), BackgroundTransparency = 1, Text = "🔎", TextSize = 12, ZIndex = 7, Parent = TopBar})
Txt(SearchBox, "検索...", "Search...", "PlaceholderText")

local function TopBtn(text, xOff, size)
	local b = New("TextButton", {
		Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, xOff, 0.5, -15), BackgroundColor3 = RGB(30, 30, 50),
		Text = text, Font = Enum.Font.GothamBold, TextSize = size or 16, TextColor3 = WHITE, AutoButtonColor = false, ZIndex = 8, Parent = TopBar,
	})
	Corner(b, 15)
	GoldStroke(b, 1.2)
	return b
end
local GearBtn = TopBtn("⚙", -76, 17)
local MinBtn = TopBtn("–", -40, 18)

-- ======================================================================
-- RIPPLE
-- ======================================================================
local function Ripple(btn, x, y)
	local sc = WScale.Scale
	local r = New("Frame", {
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x - btn.AbsolutePosition.X) / sc, (y - btn.AbsolutePosition.Y) / sc),
		Size = UDim2.fromOffset(0, 0), ZIndex = 20, Parent = btn,
	})
	Corner(r, 200)
	local big = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2.2 / sc
	T(r, 0.5, {Size = UDim2.fromOffset(big, big), BackgroundTransparency = 1})
	task.delay(0.55, function() r:Destroy() end)
end

-- ======================================================================
-- TOOLTIP (long press) + key badges + search registry
-- ======================================================================
local TipFrame = New("Frame", {
	Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = RGB(10, 10, 16),
	Visible = false, ZIndex = 80, Parent = Gui,
})
Corner(TipFrame, 8)
GoldStroke(TipFrame, 1.2)
New("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = TipFrame})
local TipLabel = New("TextLabel", {
	Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
	Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = WHITE, ZIndex = 81, Parent = TipFrame,
})
local TipHideAt, TipToken, TipConsume = 0, 0, false

local function AttachTip(obj, ja, en)
	Connect(obj.InputBegan, function(i)
		if i.UserInputType ~= Enum.UserInputType.Touch then return end
		TipConsume = false
		if not ja then return end
		TipToken = TipToken + 1
		local my = TipToken
		task.delay(0.5, function()
			if TipToken ~= my or not obj.Parent then return end
			TipLabel.Text = Tr(ja, en)
			local pos = obj.AbsolutePosition
			local vp = workspace.CurrentCamera.ViewportSize
			TipFrame.Position = UDim2.fromOffset(math.clamp(pos.X, 8, math.max(8, vp.X - 260)), math.max(8, pos.Y - 32))
			TipFrame.Visible = true
			TipHideAt = tick() + 2.4
			TipConsume = true
		end)
	end)
	Connect(obj.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.Touch then TipToken = TipToken + 1 end
	end)
end
local function Guard()
	if TipConsume then
		TipConsume = false
		return false
	end
	return true
end

local Badges = {}
local function MakeBadge(parent, actionId)
	local b = New("TextLabel", {
		Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = RGB(0, 0, 0), BackgroundTransparency = 0.35,
		Text = "", Font = Enum.Font.Code, TextSize = 11, TextColor3 = RGB(255, 225, 140), ZIndex = 6, Parent = parent,
	})
	Corner(b, 5)
	New("UIPadding", {PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = b})
	table.insert(Badges, {lbl = b, id = actionId})
	return b
end
local function RefreshBadges()
	for _, x in ipairs(Badges) do
		local k = Config.Keys[x.id]
		x.lbl.Text = k and ("[" .. ShortKey(k) .. "]") or ""
		x.lbl.Visible = Config.Hints and k ~= nil
	end
end

local PageItems = {}
local function RegItem(page, frame, kw)
	table.insert(PageItems[page], {f = frame, kw = string.lower(kw)})
end

-- ======================================================================
-- TABS
-- ======================================================================
local Sidebar = New("ScrollingFrame", {
	Size = UDim2.new(0, 104, 1, -54), Position = UDim2.fromOffset(8, 46), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4, Parent = Window,
})
New("UIListLayout", {Padding = UDim.new(0, 3), Parent = Sidebar})
local Content = New("Frame", {
	Size = UDim2.new(1, -128, 1, -54), Position = UDim2.fromOffset(120, 46), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 4, Parent = Window,
})

local Pages, TabBtns, CurrentTab = {}, {}, nil

local function ApplyFilter()
	local q = string.lower(SearchBox.Text)
	for _, items in pairs(PageItems) do
		for _, it in ipairs(items) do
			if it.f.Parent then
				it.f.Visible = (q == "") or (string.find(it.kw, q, 1, true) ~= nil)
			end
		end
	end
end
Connect(SearchBox:GetPropertyChangedSignal("Text"), ApplyFilter)

local function SelectTab(id)
	if CurrentTab == id then return end
	CurrentTab = id
	for n, pg in pairs(Pages) do
		local active = (n == id)
		local tb = TabBtns[n]
		tb.Grad.Enabled = active
		T(tb.Btn, 0.25, {BackgroundColor3 = active and WHITE or RGB(24, 24, 42)})
		T(tb.Lbl, 0.25, {TextColor3 = active and WHITE or RGB(165, 170, 200)})
		pg.Visible = active
		if active then
			pg.Position = UDim2.fromOffset(18, 0)
			T(pg, 0.3, {Position = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Quint)
		end
	end
end

local function Order(page)
	local n = (page:GetAttribute("n") or 0) + 1
	page:SetAttribute("n", n)
	return n
end

local function CreateTab(id, icon, ja, en)
	local btn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = RGB(24, 24, 42), Text = "", AutoButtonColor = false, ClipsDescendants = true, Parent = Sidebar,
	})
	Corner(btn, 9)
	local g = AddRB(btn)
	g.Enabled = false
	New("TextLabel", {Size = UDim2.fromOffset(26, 30), Position = UDim2.fromOffset(4, 0), BackgroundTransparency = 1, Text = icon, TextSize = 14, ZIndex = 3, Parent = btn})
	local lbl = New("TextLabel", {
		Size = UDim2.new(1, -32, 1, 0), Position = UDim2.fromOffset(30, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11,
		TextColor3 = RGB(165, 170, 200), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = btn,
	})
	Txt(lbl, ja, en)
	local page = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = Content,
	})
	New("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page})
	New("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), Parent = page})
	Pages[id] = page
	PageItems[page] = {}
	TabBtns[id] = {Btn = btn, Lbl = lbl, Grad = g}
	Connect(btn.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch then Ripple(btn, i.Position.X, i.Position.Y) end
	end)
	Connect(btn.Activated, function()
		SelectTab(id)
		ApplyFilter()
	end)
	return page
end

-- ======================================================================
-- COMPONENTS
-- ======================================================================
local function Section(page, ja, en)
	local l = New("TextLabel", {
		Size = UDim2.new(1, -4, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = Order(page), Parent = page,
	})
	Txt(l, ja, en)
	AddRB(l, 0)
	RegItem(page, l, ja .. " " .. en)
end

local function InfoLabel(page, ja, en, height)
	local holder = New("Frame", {Size = UDim2.new(1, -4, 0, height or 26), BackgroundColor3 = RGB(20, 20, 36), LayoutOrder = Order(page), Parent = page})
	Corner(holder, 8)
	local l = New("TextLabel", {
		Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = RGB(215, 220, 240), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = holder,
	})
	if ja then Txt(l, ja, en) end
	if ja then RegItem(page, holder, ja .. " " .. en) end
	return l
end

local function Button(page, ja, en, cb, actionId, tipJa, tipEn)
	local b = New("TextButton", {
		Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, ClipsDescendants = true,
		LayoutOrder = Order(page), Parent = page,
	})
	Corner(b, 9)
	AddRB(b)
	GoldStroke(b, 1.2)
	local lbl = New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE, ZIndex = 3, Parent = b})
	Txt(lbl, ja, en)
	if actionId then
		local badge = MakeBadge(b, actionId)
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Position = UDim2.new(1, -8, 0.5, 0)
		badge.ZIndex = 4
	end
	Connect(b.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch then Ripple(b, i.Position.X, i.Position.Y) end
	end)
	AttachTip(b, tipJa, tipEn)
	Connect(b.Activated, function()
		if Guard() then cb() end
	end)
	if actionId then ActionRun[actionId] = cb end
	RegItem(page, b, ja .. " " .. en)
	return {Fire = cb}
end

local function Toggle(page, ja, en, def, key, cb, actionId, tipJa, tipEn)
	local holder = New("TextButton", {
		Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = RGB(20, 20, 36), Text = "", AutoButtonColor = false, LayoutOrder = Order(page), Parent = page,
	})
	Corner(holder, 9)
	GoldStroke(holder, 1)
	local lbl = New("TextLabel", {
		Size = UDim2.new(1, -130, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = RGB(228, 232, 248), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = holder,
	})
	Txt(lbl, ja, en)
	if actionId then
		local badge = MakeBadge(holder, actionId)
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Position = UDim2.new(1, -62, 0.5, 0)
	end
	local track = New("Frame", {Size = UDim2.fromOffset(42, 20), Position = UDim2.new(1, -52, 0.5, -10), BackgroundColor3 = RGB(46, 48, 74), Parent = holder})
	Corner(track, 10)
	local tg = AddRB(track)
	tg.Enabled = false
	local knob = New("Frame", {Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = WHITE, Parent = track})
	Corner(knob, 8)
	local state = def and true or false
	if key then Store[key] = state end
	local function render(anim)
		tg.Enabled = state
		local gp = state and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2)
		local gc = state and WHITE or RGB(46, 48, 74)
		if anim then
			T(knob, 0.25, {Position = gp}, Enum.EasingStyle.Back)
			T(track, 0.25, {BackgroundColor3 = gc})
		else
			knob.Position = gp
			track.BackgroundColor3 = gc
		end
	end
	render(false)
	local function set(v, silent)
		state = v and true or false
		if key then Store[key] = state end
		render(true)
		if not silent and cb then cb(state) end
	end
	AttachTip(holder, tipJa, tipEn)
	Connect(holder.Activated, function()
		if Guard() then set(not state, false) end
	end)
	if actionId then ActionRun[actionId] = function() set(not state, false) end end
	if key then Reg[key] = {get = function() return state end, set = function(v) set(v, false) end} end
	RegItem(page, holder, ja .. " " .. en)
	return {Set = set}
end

local function Slider(page, ja, en, min, max, def, decimals, key, cb, tipJa, tipEn)
	local holder = New("Frame", {Size = UDim2.new(1, -4, 0, 46), BackgroundColor3 = RGB(20, 20, 36), LayoutOrder = Order(page), Parent = page})
	Corner(holder, 9)
	GoldStroke(holder, 1)
	local lbl = New("TextLabel", {
		Size = UDim2.new(1, -90, 0, 20), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = RGB(228, 232, 248), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = holder,
	})
	Txt(lbl, ja, en)
	local val = New("TextLabel", {
		Size = UDim2.fromOffset(76, 20), Position = UDim2.new(1, -84, 0, 4), BackgroundTransparency = 1, Text = tostring(def), Font = Enum.Font.Code, TextSize = 12,
		TextColor3 = RGB(255, 225, 140), TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
	})
	local bar = New("Frame", {Size = UDim2.new(1, -20, 0, 8), Position = UDim2.new(0, 10, 0, 31), BackgroundColor3 = RGB(38, 40, 64), Parent = holder})
	Corner(bar, 4)
	local fill = New("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = bar})
	Corner(fill, 4)
	AddRB(fill)
	local knob = New("Frame", {Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = WHITE, ZIndex = 3, Parent = bar})
	Corner(knob, 7)
	GoldStroke(knob, 1.2)
	local current = def
	local function set(v, silent)
		local m = 10 ^ decimals
		v = math.clamp(math.floor(v * m + 0.5) / m, min, max)
		current = v
		local a = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		val.Text = tostring(v)
		if key then Store[key] = v end
		if not silent and cb then cb(v) end
	end
	set(def, true)
	local function fromX(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		set(min + (max - min) * a, false)
	end
	AttachTip(holder, tipJa, tipEn)
	Connect(holder.InputBegan, function(i)
		if i.UserInputType ~= Enum.UserInputType.Touch then return end
		page.ScrollingEnabled = false
		T(knob, 0.15, {Size = UDim2.fromOffset(20, 20)})
		fromX(i.Position.X)
		DragHandler = function(pos) fromX(pos.X) end
		DragEnd = function()
			DragHandler = nil
			DragEnd = nil
			page.ScrollingEnabled = true
			T(knob, 0.15, {Size = UDim2.fromOffset(14, 14)})
		end
	end)
	if key then Reg[key] = {get = function() return current end, set = function(v) set(v, false) end} end
	RegItem(page, holder, ja .. " " .. en)
	return {Set = set}
end

local function Chips(page, options, default, key, cb)
	local row = New("Frame", {Size = UDim2.new(1, -4, 0, 30), BackgroundTransparency = 1, LayoutOrder = Order(page), Parent = page})
	New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = row})
	local n = #options
	local chips = {}
	local currentId = default
	local function select(id, silent)
		currentId = id
		if key then Store[key] = id end
		for _, c in ipairs(chips) do
			local on = (c.id == id)
			c.g.Enabled = on
			T(c.b, 0.2, {BackgroundColor3 = on and WHITE or RGB(26, 26, 46)})
		end
		if not silent and cb then cb(id) end
	end
	for _, o in ipairs(options) do
		local b = New("TextButton", {
			Size = UDim2.new(1 / n, -(4 * (n - 1)) / n, 1, 0), BackgroundColor3 = RGB(26, 26, 46), Text = "", Font = Enum.Font.GothamBold, TextSize = 11,
			TextColor3 = WHITE, AutoButtonColor = false, ClipsDescendants = true, Parent = row,
		})
		Corner(b, 9)
		local g = AddRB(b)
		g.Enabled = false
		GoldStroke(b, 1)
		local l = New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = WHITE, ZIndex = 3, Parent = b})
		Txt(l, o.ja, o.en)
		table.insert(chips, {b = b, g = g, id = o.id})
		Connect(b.InputBegan, function(inp)
			if inp.UserInputType == Enum.UserInputType.Touch then Ripple(b, inp.Position.X, inp.Position.Y) end
		end)
		AttachTip(b, nil, nil)
		Connect(b.Activated, function() select(o.id, false) end)
	end
	select(default, true)
	if key then Reg[key] = {get = function() return currentId end, set = function(v) select(v, false) end} end
	return {Select = select}
end

local function Input(page, phJa, phEn, height, multi)
	local tb = New("TextBox", {
		Size = UDim2.new(1, -4, 0, height or 32), BackgroundColor3 = RGB(18, 18, 32), Text = "", PlaceholderColor3 = RGB(110, 115, 140),
		TextColor3 = RGB(235, 238, 250), Font = multi and Enum.Font.Code or Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false,
		MultiLine = multi and true or false, TextWrapped = multi and true or false, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = multi and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center, ClipsDescendants = true, LayoutOrder = Order(page), Parent = page,
	})
	Corner(tb, 9)
	New("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), Parent = tb})
	local st = GoldStroke(tb, 1)
	st.Transparency = 0.4
	Txt(tb, "", "", "Text")
	LangBound[#LangBound] = nil
	Txt(tb, phJa, phEn, "PlaceholderText")
	return tb
end

local function ListBox(page, height)
	local sf = New("ScrollingFrame", {
		Size = UDim2.new(1, -4, 0, height), BackgroundColor3 = RGB(16, 16, 28), BorderSizePixel = 0, ScrollBarThickness = 3,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = Order(page), Parent = page,
	})
	Corner(sf, 9)
	GoldStroke(sf, 1)
	New("UIListLayout", {Padding = UDim.new(0, 3), Parent = sf})
	New("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4), Parent = sf})
	local obj = {Frame = sf}
	function obj.Clear()
		for _, c in ipairs(sf:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
	end
	function obj.Add(text, cb, color)
		local row = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = RGB(28, 28, 46), Text = text, TextColor3 = color or RGB(222, 226, 244), Font = Enum.Font.Code, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false, Parent = sf,
		})
		Corner(row, 5)
		New("UIPadding", {PaddingLeft = UDim.new(0, 6), Parent = row})
		Connect(row.Activated, function()
			if cb then cb(row) end
		end)
		return row
	end
	return obj
end

-- ======================================================================
-- HOOKS (your real feature code goes here)
-- ======================================================================
local OrigCam = {Mode = LocalPlayer.CameraMode, Min = LocalPlayer.CameraMinZoomDistance, Max = LocalPlayer.CameraMaxZoomDistance}
local ThirdOn = false

local Hooks = {}
local function Unset()
	Toast("warn", Tr("未設定", "Not set"), Tr("この機能にはまだ処理が割り当てられていません", "No function is attached to this hook yet"), 3)
end
Hooks.Run = Unset
Hooks.StopLag = Unset
Hooks.StopSpin = function(state) Unset() end
Hooks.CenterTP = Unset
Hooks.PlotBreak = Unset
Hooks.Third = function(state)
	ThirdOn = state
	if state then
		LocalPlayer.CameraMode = Enum.CameraMode.Classic
		LocalPlayer.CameraMinZoomDistance = 12
		LocalPlayer.CameraMaxZoomDistance = math.max(OrigCam.Max, 40)
	else
		LocalPlayer.CameraMode = OrigCam.Mode
		LocalPlayer.CameraMinZoomDistance = OrigCam.Min
		LocalPlayer.CameraMaxZoomDistance = OrigCam.Max
	end
	Toast("success", Tr("三人称", "Third Person"), state and Tr("ON", "ON") or Tr("OFF", "OFF"), 2)
end

local function RunHook(name, ...)
	local f = Hooks[name]
	if not f then return end
	local ok, err = pcall(f, ...)
	if not ok then
		Toast("error", Tr("エラー", "Error"), tostring(err), 5)
		Notify("Aura Hub", "Hook error: " .. string.sub(tostring(err), 1, 80), 4)
	end
end

-- ======================================================================
-- PLAYER SELECTION STATE
-- ======================================================================
local Selected = {}
local function CountSelected()
	local n = 0
	for _ in pairs(Selected) do n = n + 1 end
	return n
end

-- ======================================================================
-- TAB: HOME
-- ======================================================================
local Home = CreateTab("Home", "🏠", "ホーム", "Home")
local HomeRef = {}

do
	local card = New("Frame", {Size = UDim2.new(1, -4, 0, 92), BackgroundColor3 = RGB(18, 18, 34), LayoutOrder = Order(Home), Parent = Home})
	Corner(card, 12)
	GoldStroke(card, 1.6)
	local glow = New("Frame", {Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = card})
	AddRB(glow, 0)
	local av = New("ImageLabel", {
		Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(12, 14), BackgroundColor3 = RGB(30, 30, 50), Image = "", Parent = card,
	})
	Corner(av, 32)
	GoldStroke(av, 2)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and av.Parent then av.Image = img end
	end)
	New("TextLabel", {
		Size = UDim2.new(1, -92, 0, 22), Position = UDim2.fromOffset(86, 10), BackgroundTransparency = 1, Text = "🏠 " .. LocalPlayer.DisplayName,
		Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
	New("TextLabel", {
		Size = UDim2.new(1, -92, 0, 16), Position = UDim2.fromOffset(86, 32), BackgroundTransparency = 1, Text = "@" .. LocalPlayer.Name .. "  ·  ID " .. LocalPlayer.UserId,
		Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = RGB(170, 175, 205), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
	HomeRef.Uptime = New("TextLabel", {
		Size = UDim2.new(1, -92, 0, 16), Position = UDim2.fromOffset(86, 54), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = RGB(255, 225, 140), TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
	})
	HomeRef.Server = New("TextLabel", {
		Size = UDim2.new(1, -92, 0, 16), Position = UDim2.fromOffset(86, 71), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = RGB(150, 200, 255), TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
	})
	RegItem(Home, card, "home profile ホーム プロフィール name uptime server")

	local row = New("Frame", {Size = UDim2.new(1, -4, 0, 56), BackgroundTransparency = 1, LayoutOrder = Order(Home), Parent = Home})
	New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = row})
	local function StatCard(refKey, ja, en)
		local c = New("Frame", {Size = UDim2.new(1 / 3, -4, 1, 0), BackgroundColor3 = RGB(20, 20, 36), Parent = row})
		Corner(c, 10)
		GoldStroke(c, 1)
		HomeRef[refKey] = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 5), BackgroundTransparency = 1, Text = "--", Font = Enum.Font.GothamBlack, TextSize = 20,
			TextColor3 = WHITE, Parent = c,
		})
		AddRB(HomeRef[refKey], 0)
		local l = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 11,
			TextColor3 = RGB(170, 175, 205), Parent = c,
		})
		Txt(l, ja, en)
	end
	StatCard("FPS", "FPS", "FPS")
	StatCard("Ping", "Ping", "Ping")
	StatCard("Players", "サーバー人数", "Players")
	RegItem(Home, row, "fps ping players サーバー人数")

	HomeRef.Coords = InfoLabel(Home, "座標", "Position", 26)
	HomeRef.Time = InfoLabel(Home, "現在時刻", "Time", 26)

	Button(Home, "情報をコピー", "Copy info", function()
		local info = string.format("User: %s (%d)\nPlaceId: %d\nJobId: %s\nPlayers: %d/%d", LocalPlayer.Name, LocalPlayer.UserId, game.PlaceId, game.JobId, #Players:GetPlayers(), Players.MaxPlayers)
		setclipboard(info)
		Toast("success", Tr("コピー", "Copied"), Tr("情報をクリップボードにコピーしました", "Info copied to clipboard"), 2.5)
	end, nil, "現在のセッション情報をコピーします", "Copies the current session info")
end

-- ======================================================================
-- TAB: NO BLOB
-- ======================================================================
local NoBlob = CreateTab("NoBlob", "🌀", "ノーブロブ", "No Blob")
Section(NoBlob, "操作", "Controls")
Button(NoBlob, "実行", "Run", function() RunHook("Run") end, "Run", "Hooks.Run を実行します", "Runs Hooks.Run")
Button(NoBlob, "ラグ停止", "Stop Lag", function() RunHook("StopLag") end, "StopLag", "Hooks.StopLag を実行します", "Runs Hooks.StopLag")
Toggle(NoBlob, "回転停止", "Stop Spin", false, "StopSpin", function(s) RunHook("StopSpin", s) end, "StopSpin", "Hooks.StopSpin(state) を呼びます", "Calls Hooks.StopSpin(state)")
Button(NoBlob, "中心TP", "Center TP", function() RunHook("CenterTP") end, "CenterTP", "Hooks.CenterTP を実行します", "Runs Hooks.CenterTP")
Button(NoBlob, "Plot Break", "Plot Break", function() RunHook("PlotBreak") end, "PlotBreak", "Hooks.PlotBreak を実行します", "Runs Hooks.PlotBreak")
Toggle(NoBlob, "三人称", "Third Person", false, "Third", function(s) RunHook("Third", s) end, "Third", "カメラを三人称に固定します", "Forces a third person camera")

-- ======================================================================
-- TAB: SETTINGS (values)
-- ======================================================================
local SettingsTab = CreateTab("Settings", "⚙", "設定", "Settings")
Section(SettingsTab, "パラメータ", "Parameters")
Slider(SettingsTab, "半径", "Radius", 1, 200, 30, 0, "Radius", nil, "Store.Radius に保存されます", "Saved to Store.Radius")
Slider(SettingsTab, "高さ", "Height", 0, 100, 10, 0, "Height", nil, "Store.Height に保存されます", "Saved to Store.Height")
Slider(SettingsTab, "P値", "P Value", 100, 20000, 5000, 0, "PValue", nil, "Store.PValue に保存されます", "Saved to Store.PValue")
Slider(SettingsTab, "MaxForce", "MaxForce", 1000, 1000000, 100000, 0, "MaxForce", nil, "Store.MaxForce に保存されます", "Saved to Store.MaxForce")

-- ======================================================================
-- TAB: PLAYERS (dropdown, search, multi-select)
-- ======================================================================
local PlayersTab = CreateTab("Players", "👥", "プレイヤー", "Players")
Section(PlayersTab, "プレイヤー選択", "Select players")
local SelHeader = New("TextButton", {
	Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = RGB(20, 20, 36), Text = "", AutoButtonColor = false, LayoutOrder = Order(PlayersTab), Parent = PlayersTab,
})
Corner(SelHeader, 9)
GoldStroke(SelHeader, 1.2)
local SelHeaderLbl = New("TextLabel", {
	Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
	TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Parent = SelHeader,
})
local PSearch = Input(PlayersTab, "プレイヤー検索...", "Search players...", 30, false)
local PList = ListBox(PlayersTab, 140)
local NoteLbl = InfoLabel(PlayersTab, "未選択 = 全員が対象です", "None selected = everyone is targeted", 26)
local ListOpen = true

local function RefreshSelHeader()
	local n = CountSelected()
	SelHeaderLbl.Text = (ListOpen and "▼ " or "▶ ") .. Tr("選択中: ", "Selected: ") .. n .. " / " .. #Players:GetPlayers()
end
table.insert(DynamicFns, RefreshSelHeader)

local function RebuildPlayers()
	PList.Clear()
	local q = string.lower(PSearch.Text)
	local list = Players:GetPlayers()
	table.sort(list, function(a, b) return string.lower(a.DisplayName) < string.lower(b.DisplayName) end)
	for _, p in ipairs(list) do
		local label = p.DisplayName .. " (@" .. p.Name .. ")" .. (p == LocalPlayer and (" " .. Tr("[自分]", "[you]")) or "")
		if q == "" or string.find(string.lower(label), q, 1, true) then
			local function glyph() return Selected[p.UserId] and "☑ " or "☐ " end
			local row
			row = PList.Add(glyph() .. label, function()
				if Selected[p.UserId] then Selected[p.UserId] = nil else Selected[p.UserId] = true end
				row.Text = glyph() .. label
				row.TextColor3 = Selected[p.UserId] and RGB(255, 225, 140) or RGB(222, 226, 244)
				RefreshSelHeader()
			end, Selected[p.UserId] and RGB(255, 225, 140) or nil)
		end
	end
	RefreshSelHeader()
end

Connect(SelHeader.Activated, function()
	ListOpen = not ListOpen
	PList.Frame.Visible = ListOpen
	PSearch.Visible = ListOpen
	RefreshSelHeader()
end)
Connect(PSearch:GetPropertyChangedSignal("Text"), RebuildPlayers)
Connect(Players.PlayerAdded, RebuildPlayers)
Connect(Players.PlayerRemoving, function(p)
	Selected[p.UserId] = nil
	task.defer(RebuildPlayers)
end)

do
	local row = New("Frame", {Size = UDim2.new(1, -4, 0, 32), BackgroundTransparency = 1, LayoutOrder = Order(PlayersTab), Parent = PlayersTab})
	New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = row})
	local function Mini(ja, en, cb)
		local b = New("TextButton", {Size = UDim2.new(1 / 3, -3, 1, 0), BackgroundColor3 = WHITE, Text = "", AutoButtonColor = false, ClipsDescendants = true, Parent = row})
		Corner(b, 9)
		AddRB(b)
		GoldStroke(b, 1)
		local l = New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = WHITE, ZIndex = 3, Parent = b})
		Txt(l, ja, en)
		Connect(b.InputBegan, function(i)
			if i.UserInputType == Enum.UserInputType.Touch then Ripple(b, i.Position.X, i.Position.Y) end
		end)
		AttachTip(b, nil, nil)
		Connect(b.Activated, cb)
	end
	Mini("全員選択", "Select all", function()
		for _, p in ipairs(Players:GetPlayers()) do Selected[p.UserId] = true end
		RebuildPlayers()
		Toast("info", Tr("プレイヤー", "Players"), Tr("全員を選択しました", "Selected everyone"), 2)
	end)
	Mini("解除", "Clear", function()
		Selected = {}
		RebuildPlayers()
		Toast("info", Tr("プレイヤー", "Players"), Tr("選択を解除しました", "Selection cleared"), 2)
	end)
	Mini("更新", "Refresh", function() RebuildPlayers() end)
end
RebuildPlayers()

-- ======================================================================
-- TAB: KEYBINDS (rebind, conflict detection, mobile pins)
-- ======================================================================
local KeysTab = CreateTab("Keys", "⌨", "キーバインド", "Keybinds")
Section(KeysTab, "キー割り当て", "Key bindings")
InfoLabel(KeysTab, "キーをタップして変更 / Backspaceで解除", "Tap a key to rebind / Backspace to clear", 26)
local KeyRows = {}
local Rebind = nil
local PinFrames = {}

local function SetPin(id, on)
	if on then
		Config.Pins[id] = true
		if not PinFrames[id] then
			local idx = 0
			for i, a in ipairs(ActionList) do if a.id == id then idx = i end end
			local info = ActionList[idx]
			local pin = New("TextButton", {
				Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -62, 0, 110 + idx * 54), BackgroundColor3 = WHITE, Text = info.icon,
				TextSize = 20, TextColor3 = WHITE, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 30, Parent = Gui,
			})
			Corner(pin, 23)
			AddRB(pin)
			GoldStroke(pin, 2)
			MakeDraggable(pin, pin, function()
				local r = ActionRun[id]
				if r then r() end
			end)
			PinFrames[id] = pin
		end
	else
		Config.Pins[id] = nil
		if PinFrames[id] then
			PinFrames[id]:Destroy()
			PinFrames[id] = nil
		end
	end
	if KeyRows[id] then KeyRows[id].pin.TextColor3 = Config.Pins[id] and RGB(255, 215, 90) or RGB(120, 125, 150) end
end

local function RefreshKeyRows()
	for id, r in pairs(KeyRows) do
		r.key.Text = (Rebind == id) and "..." or ("[" .. ShortKey(Config.Keys[id]) .. "]")
		r.pin.TextColor3 = Config.Pins[id] and RGB(255, 215, 90) or RGB(120, 125, 150)
	end
	RefreshBadges()
end

for _, a in ipairs(ActionList) do
	local row = New("Frame", {Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = RGB(20, 20, 36), LayoutOrder = Order(KeysTab), Parent = KeysTab})
	Corner(row, 9)
	GoldStroke(row, 1)
	local nameLbl = New("TextLabel", {
		Size = UDim2.new(1, -140, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = RGB(228, 232, 248), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	Txt(nameLbl, a.icon .. " " .. a.ja, a.icon .. " " .. a.en)
	local keyBtn = New("TextButton", {
		Size = UDim2.fromOffset(72, 24), Position = UDim2.new(1, -118, 0.5, -12), BackgroundColor3 = RGB(10, 10, 18), Text = "",
		Font = Enum.Font.Code, TextSize = 12, TextColor3 = RGB(255, 225, 140), AutoButtonColor = false, Parent = row,
	})
	Corner(keyBtn, 7)
	GoldStroke(keyBtn, 1)
	local pinBtn = New("TextButton", {
		Size = UDim2.fromOffset(34, 24), Position = UDim2.new(1, -40, 0.5, -12), BackgroundColor3 = RGB(10, 10, 18), Text = "📌",
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = RGB(120, 125, 150), AutoButtonColor = false, Parent = row,
	})
	Corner(pinBtn, 7)
	GoldStroke(pinBtn, 1)
	KeyRows[a.id] = {key = keyBtn, pin = pinBtn}
	AttachTip(pinBtn, "モバイル用の浮動ボタンを表示します", "Shows a floating mobile button")
	AttachTip(keyBtn, nil, nil)
	Connect(keyBtn.Activated, function()
		Rebind = a.id
		RefreshKeyRows()
		Toast("info", Tr("キー変更", "Rebind"), Tr("キーを押してください...", "Press a key..."), 2.5)
	end)
	Connect(pinBtn.Activated, function()
		if Guard() then SetPin(a.id, not Config.Pins[a.id]) end
	end)
	RegItem(KeysTab, row, a.ja .. " " .. a.en .. " " .. a.id)
end

-- keyboard listener (secondary controls) + rebinding
Connect(UserInputService.InputBegan, function(input, gpe)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if Rebind then
		local id = Rebind
		Rebind = nil
		if input.KeyCode == Enum.KeyCode.Escape then
			RefreshKeyRows()
			return
		end
		if input.KeyCode == Enum.KeyCode.Backspace then
			Config.Keys[id] = nil
			RefreshKeyRows()
			Toast("info", Tr("キー変更", "Rebind"), Tr("割り当てを解除しました", "Binding cleared"), 2)
			return
		end
		for otherId, k in pairs(Config.Keys) do
			if otherId ~= id and k == input.KeyCode then
				local nm = otherId
				for _, a in ipairs(ActionList) do if a.id == otherId then nm = Tr(a.ja, a.en) end end
				RefreshKeyRows()
				Toast("warn", Tr("キーが重複しています", "Key conflict"), "[" .. ShortKey(input.KeyCode) .. "] → " .. nm, 4)
				return
			end
		end
		Config.Keys[id] = input.KeyCode
		RefreshKeyRows()
		Toast("success", Tr("キー変更", "Rebind"), "[" .. ShortKey(input.KeyCode) .. "]", 2)
		return
	end
	if gpe then return end
	for id, key in pairs(Config.Keys) do
		if key == input.KeyCode then
			local r = ActionRun[id]
			if r then r() end
		end
	end
end)

-- ======================================================================
-- TAB: LOG
-- ======================================================================
local LogTab = CreateTab("Log", "📜", "ログ", "Log")
Section(LogTab, "実行履歴", "History")
LogList = ListBox(LogTab, 170)
for _, line in ipairs(Log.Entries) do
	LogList.Add(line, nil, nil)
end
Button(LogTab, "ログをコピー", "Copy log", function()
	setclipboard(table.concat(Log.Entries, "\n"))
	Toast("success", Tr("コピー", "Copied"), Tr("ログをコピーしました", "Log copied"), 2)
end)
Button(LogTab, "クリア", "Clear", function()
	Log.Entries = {}
	LogList.Clear()
end)

-- ======================================================================
-- TAB: UI SETTINGS
-- ======================================================================
local UITab = CreateTab("UI", "🎨", "UI設定", "UI Settings")
local Open, Busy = false, false
local SetOpen

Section(UITab, "メニュー", "Menu")
do
	local row = New("Frame", {Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = RGB(20, 20, 36), LayoutOrder = Order(UITab), Parent = UITab})
	Corner(row, 9)
	GoldStroke(row, 1)
	local l = New("TextLabel", {
		Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = RGB(228, 232, 248), TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	Txt(l, "メニューキー", "Menu key")
	local kb = New("TextButton", {
		Size = UDim2.fromOffset(90, 24), Position = UDim2.new(1, -98, 0.5, -12), BackgroundColor3 = RGB(10, 10, 18), Text = "",
		Font = Enum.Font.Code, TextSize = 12, TextColor3 = RGB(255, 225, 140), AutoButtonColor = false, Parent = row,
	})
	Corner(kb, 7)
	GoldStroke(kb, 1)
	KeyRows.Menu = KeyRows.Menu
	table.insert(DynamicFns, function() kb.Text = "[" .. ShortKey(Config.Keys.Menu) .. "]" end)
	AttachTip(kb, nil, nil)
	Connect(kb.Activated, function()
		Rebind = "Menu"
		kb.Text = "..."
		Toast("info", Tr("キー変更", "Rebind"), Tr("キーを押してください...", "Press a key..."), 2.5)
	end)
	RegItem(UITab, row, "menu key メニューキー")
end

Section(UITab, "通知", "Notifications")
Toggle(UITab, "通知音", "Sound", true, "NSound", function(s) Config.Notify.Sound = s end, nil, "Resonanceの通知音を使用します", "Uses the Resonance notification sound")
Slider(UITab, "音量", "Volume", 0, 5, 2, 1, "NVolume", function(v) Config.Notify.Volume = v end)
Slider(UITab, "表示時間(秒)", "Duration (s)", 1, 10, 4, 0, "NDuration", function(v) Config.Notify.Duration = v end)
Chips(UITab, {
	{id = "TR", ja = "右上", en = "Top R"}, {id = "TL", ja = "左上", en = "Top L"},
	{id = "BR", ja = "右下", en = "Btm R"}, {id = "BL", ja = "左下", en = "Btm L"},
}, "TR", "NPos", function(id) ApplyToastPos(id) end)
do
	local row = New("Frame", {Size = UDim2.new(1, -4, 0, 30), BackgroundTransparency = 1, LayoutOrder = Order(UITab), Parent = UITab})
	New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = row})
	local defs = {
		{"info", "情報", "Info"}, {"success", "成功", "OK"}, {"warn", "警告", "Warn"}, {"error", "エラー", "Error"},
	}
	for _, d in ipairs(defs) do
		local st = TYPE_STYLE[d[1]]
		local b = New("TextButton", {
			Size = UDim2.new(0.25, -3, 1, 0), BackgroundColor3 = st.col, Text = "", AutoButtonColor = false, ClipsDescendants = true, Parent = row,
		})
		Corner(b, 9)
		GoldStroke(b, 1)
		local l = New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = WHITE, ZIndex = 3, Parent = b})
		Txt(l, d[2], d[3])
		Connect(b.InputBegan, function(i)
			if i.UserInputType == Enum.UserInputType.Touch then Ripple(b, i.Position.X, i.Position.Y) end
		end)
		AttachTip(b, nil, nil)
		Connect(b.Activated, function()
			Toast(d[1], Tr("通知テスト", "Notification test"), Tr("これは " .. d[2] .. " 通知です", "This is a " .. d[3] .. " notification"), nil)
		end)
	end
	RegItem(UITab, row, "test notification 通知テスト")
end

Section(UITab, "テーマ", "Theme")
Chips(UITab, {
	{id = "Crimson", ja = "クリムゾン", en = "Crimson"}, {id = "Flame", ja = "フレイム", en = "Flame"},
	{id = "Rose", ja = "ローズ", en = "Rose"}, {id = "Royal", ja = "ロイヤル", en = "Royal"},
}, "Crimson", "Theme", function(id) ApplyTheme(id) end)
Slider(UITab, "グラデ速度", "Gradient speed", 0, 180, 40, 0, "GradSpeed", function(v) Config.GradSpeed = v end)
Toggle(UITab, "金の光沢", "Gold shine", true, "GoldShine", function(s) Config.Gold = s end)

Section(UITab, "表示", "Display")
Toggle(UITab, "ステータスバー", "Status bar", true, "StatusBar", nil)
Toggle(UITab, "キー表示", "Key hints", true, "Hints", function(s)
	Config.Hints = s
	RefreshBadges()
end, nil, "ボタン名の横にキーを表示します", "Shows key hints next to buttons")
Slider(UITab, "UIサイズ", "UI scale", 0.5, 1.4, BaseScale, 2, "UIScale", function(v)
	BaseScale = v
	if Open then WScale.Scale = v end
end)

-- ---------------- Presets ----------------
Section(UITab, "プリセット", "Presets")
local PresetName = Input(UITab, "プリセット名", "Preset name", 30, false)
local PresetList = ListBox(UITab, 90)
local SelectedPreset = nil
local PresetInfo = InfoLabel(UITab, "選択中: -", "Selected: -", 24)

local function Snapshot()
	local p = {Values = {}, Keys = {}, Pins = {}}
	for k, r in pairs(Reg) do p.Values[k] = r.get() end
	for id, key in pairs(Config.Keys) do p.Keys[id] = key.Name end
	for id, on in pairs(Config.Pins) do p.Pins[id] = on end
	return p
end

local function ApplyPresetData(p)
	for k, v in pairs(p.Values or {}) do
		if Reg[k] then pcall(Reg[k].set, v) end
	end
	Config.Keys = {}
	for id, name in pairs(p.Keys or {}) do
		local ok, kc = pcall(function() return Enum.KeyCode[name] end)
		if ok and kc then Config.Keys[id] = kc end
	end
	for _, a in ipairs(ActionList) do
		SetPin(a.id, p.Pins and p.Pins[a.id] or false)
	end
	RefreshKeyRows()
	UpdateDynamic()
end

local function RebuildPresets()
	PresetList.Clear()
	local names = {}
	for n in pairs(PresetStore) do table.insert(names, n) end
	table.sort(names)
	for _, n in ipairs(names) do
		PresetList.Add("💾 " .. n, function()
			SelectedPreset = n
			PresetInfo.Text = Tr("選択中: ", "Selected: ") .. n
		end)
	end
end
table.insert(DynamicFns, function()
	PresetInfo.Text = Tr("選択中: ", "Selected: ") .. (SelectedPreset or "-")
end)

Button(UITab, "保存", "Save", function()
	local name = PresetName.Text
	if name == "" then
		Toast("warn", Tr("プリセット", "Preset"), Tr("名前を入力してください", "Enter a name first"), 3)
		return
	end
	PresetStore[name] = Snapshot()
	SelectedPreset = name
	RebuildPresets()
	UpdateDynamic()
	Toast("success", Tr("プリセット", "Preset"), Tr("保存しました: ", "Saved: ") .. name, 3)
end)
Button(UITab, "読込", "Load", function()
	if not SelectedPreset or not PresetStore[SelectedPreset] then
		Toast("warn", Tr("プリセット", "Preset"), Tr("プリセットを選択してください", "Select a preset first"), 3)
		return
	end
	ApplyPresetData(PresetStore[SelectedPreset])
	Toast("success", Tr("プリセット", "Preset"), Tr("読み込みました: ", "Loaded: ") .. SelectedPreset, 3)
end)
Button(UITab, "削除", "Delete", function()
	if SelectedPreset and PresetStore[SelectedPreset] then
		PresetStore[SelectedPreset] = nil
		Toast("info", Tr("プリセット", "Preset"), Tr("削除しました: ", "Deleted: ") .. SelectedPreset, 3)
		SelectedPreset = nil
		RebuildPresets()
		UpdateDynamic()
	end
end)
Button(UITab, "エクスポート (コピー)", "Export (copy)", function()
	local ok, json = pcall(function() return HttpService:JSONEncode(Snapshot()) end)
	if ok then
		setclipboard(json)
		Toast("success", Tr("エクスポート", "Export"), Tr("JSONをコピーしました", "JSON copied to clipboard"), 3)
	else
		Toast("error", Tr("エクスポート", "Export"), tostring(json), 4)
	end
end)
local ImportBox = Input(UITab, "ここにJSONを貼り付け", "Paste JSON here", 50, true)
Button(UITab, "インポート", "Import", function()
	local ok, data = pcall(function() return HttpService:JSONDecode(ImportBox.Text) end)
	if ok and type(data) == "table" then
		ApplyPresetData(data)
		Toast("success", Tr("インポート", "Import"), Tr("設定を適用しました", "Settings applied"), 3)
	else
		Toast("error", Tr("インポート", "Import"), Tr("JSONが正しくありません", "Invalid JSON"), 4)
	end
end)

Section(UITab, "危険", "Danger")
local Unload
Button(UITab, "アンロード", "Unload", function() Unload() end, nil, "UIを完全に削除します", "Removes the UI completely")

-- ======================================================================
-- TOGGLE PILL (Obsidian style) + STATUS BAR
-- ======================================================================
local Pill = New("TextButton", {
	Size = UDim2.fromOffset(96, 32), Position = UDim2.fromOffset(14, 62), BackgroundColor3 = RGB(8, 8, 12), Text = "Toggle",
	Font = Enum.Font.Code, TextSize = 14, TextColor3 = WHITE, AutoButtonColor = false, ZIndex = 60, Parent = Gui,
})
Corner(Pill, 8)
GoldStroke(Pill, 1.8)

local StatusBar = New("Frame", {
	Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(116, 12),
	BackgroundColor3 = RGB(8, 8, 12), ZIndex = 60, Parent = Gui,
})
Corner(StatusBar, 8)
GoldStroke(StatusBar, 1.8)
New("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = StatusBar})
New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), Parent = StatusBar})
do
	local moon = New("Frame", {Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, ZIndex = 61, Parent = StatusBar})
	New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "☾", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = RGB(255, 205, 70), ZIndex = 61, Parent = moon})
	New("ImageLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = MOON_ID, ZIndex = 62, Parent = moon})
end
local StatusText = New("TextLabel", {
	Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = "", Font = Enum.Font.Code, TextSize = 14,
	TextColor3 = WHITE, ZIndex = 61, Parent = StatusBar,
})
MakeDraggable(StatusBar, StatusBar, nil)

-- open / close with animation + toasts
SetOpen = function(state, silent)
	if Busy or Open == state then return end
	Busy = true
	Open = state
	if state then
		Holder.Visible = true
		WScale.Scale = 0.01
		T(WScale, 0.42, {Scale = BaseScale}, Enum.EasingStyle.Back)
		T(Pill, 0.25, {BackgroundColor3 = RGB(40, 12, 24)})
		task.delay(0.42, function() Busy = false end)
		if not silent then Toast("info", APP_NAME, Tr("UIを開きました", "UI opened"), 2) end
	else
		T(WScale, 0.28, {Scale = 0.01}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		T(Pill, 0.25, {BackgroundColor3 = RGB(8, 8, 12)})
		task.delay(0.3, function()
			Holder.Visible = false
			Busy = false
		end)
		if not silent then Toast("info", APP_NAME, Tr("UIを閉じました", "UI closed"), 2) end
	end
end

MakeDraggable(Pill, Pill, function() SetOpen(not Open) end)
Connect(MinBtn.Activated, function() SetOpen(false) end)
MakeDraggable(TopBar, Holder, nil)
ActionRun.Menu = function() SetOpen(not Open) end

-- ======================================================================
-- GEAR POPUP (language)
-- ======================================================================
local LangPop = New("Frame", {
	Size = UDim2.fromOffset(150, 74), Position = UDim2.new(1, -164, 0, 46), BackgroundColor3 = RGB(10, 10, 18), Visible = false, ZIndex = 40, Parent = Window,
})
Corner(LangPop, 10)
GoldStroke(LangPop, 1.6)
local LangTitle = New("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 6), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12,
	TextColor3 = RGB(255, 225, 140), ZIndex = 41, Parent = LangPop,
})
Txt(LangTitle, "⚙ 言語", "⚙ Language")
local LangBtn = New("TextButton", {
	Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 32), BackgroundColor3 = WHITE, Text = "English", Font = Enum.Font.GothamBold,
	TextSize = 13, TextColor3 = WHITE, AutoButtonColor = false, ZIndex = 41, Parent = LangPop,
})
Corner(LangBtn, 9)
AddRB(LangBtn)
GoldStroke(LangBtn, 1)

local PopOpen = false
local function SetPop(state)
	PopOpen = state
	if state then
		LangPop.Visible = true
		LangPop.Position = UDim2.new(1, -164, 0, 30)
		T(LangPop, 0.25, {Position = UDim2.new(1, -164, 0, 46)}, Enum.EasingStyle.Back)
	else
		LangPop.Visible = false
	end
end
Connect(GearBtn.Activated, function() SetPop(not PopOpen) end)
Connect(LangBtn.Activated, function()
	Lang = (Lang == "ja") and "en" or "ja"
	Config.Lang = Lang
	LangBtn.Text = (Lang == "ja") and "English" or "日本語"
	RefreshLang()
	SetPop(false)
	Toast("success", Tr("言語", "Language"), Tr("日本語に切り替えました", "Switched to English"), 2.5)
end)

-- ======================================================================
-- STATUS / DYNAMIC REFRESH
-- ======================================================================
table.insert(DynamicFns, RefreshBadges)
table.insert(DynamicFns, function()
	for id, r in pairs(KeyRows) do
		r.key.Text = "[" .. ShortKey(Config.Keys[id]) .. "]"
	end
end)

local function PlayersText()
	return #Players:GetPlayers() .. "/" .. Players.MaxPlayers
end

local function RefreshStatus(fps, ping)
	StatusText.Text = string.format("%s %s | %d fps | %s ms | %s", APP_NAME, VERSION, fps, ping, PlayersText() .. Tr("人", " players"))
	HomeRef.FPS.Text = tostring(fps)
	HomeRef.Ping.Text = tostring(ping)
	HomeRef.Players.Text = PlayersText()
	HomeRef.Uptime.Text = "⏱ " .. Tr("起動時間: ", "Uptime: ") .. FmtTime(tick() - START_TIME)
	HomeRef.Server.Text = "👥 " .. Tr("サーバー人数: ", "Server players: ") .. PlayersText()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local p = root.Position
		HomeRef.Coords.Text = Tr("座標: ", "Position: ") .. string.format("X %.0f  Y %.0f  Z %.0f", p.X, p.Y, p.Z)
	else
		HomeRef.Coords.Text = Tr("座標: -", "Position: -")
	end
	HomeRef.Time.Text = Tr("現在時刻: ", "Time: ") .. os.date("%Y-%m-%d  %H:%M:%S")
end

-- ======================================================================
-- UNLOAD
-- ======================================================================
local Destroyed = false
Unload = function()
	if Destroyed then return end
	Destroyed = true
	if ThirdOn then
		pcall(Hooks.Third, false)
	end
	Toast("info", APP_NAME, Tr("アンロードしています...", "Unloading..."), 2)
	T(WScale, 0.25, {Scale = 0.01}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.7, function()
		for _, c in ipairs(Conns) do
			pcall(function() c:Disconnect() end)
		end
		Conns = {}
		Gui:Destroy()
		getgenv().AuraHub = nil
	end)
end

getgenv().AuraHub = {
	Unload = Unload,
	Hooks = Hooks,
	Values = Store,
	Selected = function() return Selected end,
	Toast = Toast,
	Config = Config,
}

-- ======================================================================
-- MAIN LOOP
-- ======================================================================
local frames, acc, fps, ping = 0, 0, 60, 0
local statTimer = 0
RefreshStatus(60, 0)

Connect(RunService.Heartbeat, function(dt)
	if Destroyed then return end
	local now = tick()

	-- animated red/blue gradients
	for i = #RBGrads, 1, -1 do
		local g = RBGrads[i]
		if g.Parent then
			if g.Enabled then g.Rotation = (g.Rotation + dt * Config.GradSpeed) % 360 end
		else
			table.remove(RBGrads, i)
		end
	end
	-- glossy gold sweep
	local off = Vector2.new(((now * 0.45) % 2) - 1, 0)
	for i = #GoldGrads, 1, -1 do
		local g = GoldGrads[i]
		if g.Parent then
			g.Offset = Config.Gold and off or Vector2.new(0, 0)
		else
			table.remove(GoldGrads, i)
		end
	end

	-- tooltip auto hide
	if TipFrame.Visible and now > TipHideAt then TipFrame.Visible = false end

	-- stats
	frames = frames + 1
	acc = acc + dt
	if acc >= 0.5 then
		fps = math.floor(frames / acc + 0.5)
		frames, acc = 0, 0
		local ok, p = pcall(function()
			return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
		end)
		ping = ok and p or 0
		StatusBar.Visible = Store.StatusBar ~= false
		RefreshStatus(fps, ping)
		if Selected and PList then RefreshSelHeader() end
	end
end)

-- ======================================================================
-- START
-- ======================================================================
SelectTab("Home")
RefreshBadges()
RefreshKeyRows()
RebuildPresets()
PresetStore["Default"] = PresetStore["Default"] or Snapshot()
RebuildPresets()
UpdateDynamic()
task.delay(0.4, function()
	Toast("success", APP_NAME .. " " .. VERSION, Tr("読み込み完了！ Toggleボタンで開閉できます", "Loaded! Use the Toggle button to open / close"), 4)
end)
