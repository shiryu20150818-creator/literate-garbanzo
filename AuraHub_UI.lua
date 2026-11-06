--[[
	AURA HUB  -  Mobile UI (original build)
	Red/Blue animated gradient + glossy gold border
	- "Toggle" pill (Obsidian style): tap = open UI, tap again = close UI
	- Status bar: fps / ping / server players (modelled on the Resonance bar)
	- Toast notifications (info / success / warn / error), Resonance notification sound
	- Key hints [Z] next to buttons/toggles + rebinding + conflict detection + mobile pins
	- Player selector (search + multi select), log, presets (save / export / import)
	- Japanese / English (gear icon), search bar, long-press tooltips
	Protect tab = FTAP anti set (Anti-Grab / Ragdoll / Kick / Lag / Void / Sit / Sticky / Burn /
	Explosion / Paint / GUCCI Anti-Grab / Anti Network / Delete Legs). Hooks are wired to it.
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
	{id = "Menu", ja = "メニュー開閉", en = "Toggle menu", icon = "menu"},
	{id = "Run", ja = "実行", en = "Run", icon = "play"},
	{id = "StopLag", ja = "ラグ停止", en = "Stop Lag", icon = "pause"},
	{id = "StopSpin", ja = "回転停止", en = "Stop Spin", icon = "rotate-cw"},
	{id = "CenterTP", ja = "中心TP", en = "Center TP", icon = "locate-fixed"},
	{id = "PlotBreak", ja = "Plot Break", en = "Plot Break", icon = "scissors"},
	{id = "Third", ja = "三人称", en = "Third Person", icon = "eye"},
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
-- ICONS (Lucide sprite sheets, same method as Resonance)
-- Sprite sheet image IDs come from Resonance's lucide-icons/1.png and 2.png.
-- Each icon = {sheet, x, y}; cut out with ImageRectOffset / ImageRectSize (24x24).
-- Icon() accepts: a Lucide name ("house"), an image id ("rbxassetid://123" / "123"),
-- or a plain text symbol ("▶"). Images -> ImageLabel, symbols -> TextLabel.
-- ======================================================================
local LUCIDE_SHEETS = {"rbxassetid://97854828246256", "rbxassetid://96738291359702"}
local LUCIDE_SIZE = 24
local LUCIDE = {
	["house"] = {1, 325, 675},
	["user"] = {2, 25, 300},
	["users"] = {2, 350, 0},
	["settings"] = {1, 525, 900},
	["shield"] = {1, 525, 925},
	["shield-check"] = {1, 850, 600},
	["crosshair"] = {1, 250, 525},
	["keyboard"] = {1, 500, 525},
	["scroll-text"] = {1, 450, 950},
	["funnel"] = {1, 50, 875},
	["palette"] = {1, 825, 400},
	["search"] = {1, 850, 575},
	["bell"] = {1, 125, 300},
	["cog"] = {1, 600, 150},
	["sliders-horizontal"] = {1, 800, 700},
	["swords"] = {1, 800, 950},
	["moon"] = {1, 200, 950},
	["ghost"] = {1, 675, 275},
	["bomb"] = {1, 25, 425},
	["rocket"] = {1, 575, 775},
	["zap"] = {2, 350, 100},
	["terminal"] = {1, 875, 975},
	["list"] = {1, 625, 450},
	["clipboard-list"] = {1, 500, 200},
	["wrench"] = {2, 450, 0},
	["layout-dashboard"] = {1, 875, 175},
	["monitor"] = {1, 250, 900},
	["bookmark"] = {1, 200, 300},
	["save"] = {1, 975, 425},
	["hand"] = {1, 400, 575},
	["eye"] = {1, 700, 150},
	["lock"] = {1, 375, 700},
	["target"] = {1, 975, 875},
	["menu"] = {1, 125, 975},
	["x"] = {2, 400, 50},
	["minus"] = {1, 650, 500},
	["pin"] = {1, 675, 600},
	["map-pin"] = {1, 450, 650},
	["play"] = {1, 500, 775},
	["pause"] = {1, 850, 400},
	["rotate-cw"] = {1, 925, 450},
	["scissors"] = {1, 550, 850},
	["clock"] = {1, 525, 200},
	["activity"] = {1, 25, 25},
	["wifi"] = {2, 175, 250},
	["locate-fixed"] = {1, 525, 550},
	["circle-question-mark"] = {1, 175, 500},
	["user-round"] = {2, 150, 175},
	["gauge"] = {1, 775, 175},
	["timer"] = {2, 150, 0},
	["shield-alert"] = {1, 900, 550},
	["refresh-cw"] = {1, 350, 975},
	["check"] = {1, 400, 225},
	["info"] = {1, 850, 175},
	["triangle-alert"] = {2, 75, 150},
	["octagon-alert"] = {1, 575, 625},
}
-- plain-text fallbacks (shown only if the sprite sheet does not load)
local ICON_GLYPH = {
	["house"] = "⌂", ["crosshair"] = "⊕", ["settings"] = "*", ["users"] = "•", ["user"] = "•",
	["keyboard"] = "▭", ["scroll-text"] = "≡", ["shield"] = "◇", ["palette"] = "◐", ["search"] = "⌕",
	["pin"] = "•", ["eye"] = "◉", ["menu"] = "☰", ["play"] = "›", ["pause"] = "‖", ["rotate-cw"] = "⟳",
	["scissors"] = "×", ["locate-fixed"] = "◎", ["clock"] = "◷",
}

-- returns the ImageLabel-ready data for a Lucide name: image id, rect offset, rect size
local function Lucide(name)
	local d = LUCIDE[name]
	if not d then return nil end
	return {Image = LUCIDE_SHEETS[d[1]], RectOffset = Vector2.new(d[2], d[3]), RectSize = Vector2.new(LUCIDE_SIZE, LUCIDE_SIZE)}
end

local function IconColor(inst, color)
	if not inst then return end
	if inst:IsA("ImageLabel") then
		inst.ImageColor3 = color
	else
		inst.TextColor3 = color
	end
end

-- MakeIcon: branches on the kind of icon value (Lucide name / image id / text symbol)
local function MakeIcon(parent, icon, size, pos, color, z)
	color = color or WHITE
	local data = Lucide(icon)
	local isId = type(icon) == "string" and (string.match(icon, "^rbxassetid://") ~= nil or string.match(icon, "^%d+$") ~= nil)
	if data or isId then
		local img = New("ImageLabel", {Size = size, Position = pos, BackgroundTransparency = 1, ImageColor3 = color, ZIndex = z or 1, Parent = parent})
		if data then
			img.Image = data.Image
			img.ImageRectOffset = data.RectOffset
			img.ImageRectSize = data.RectSize
			local g = ICON_GLYPH[icon]
			if g then
				local fb = New("TextLabel", {
					Size = size, Position = pos, BackgroundTransparency = 1, Text = g, Font = Enum.Font.GothamBold,
					TextSize = math.max(10, math.floor(size.Y.Offset * 0.85)), TextColor3 = color, Visible = false, ZIndex = z or 1, Parent = parent,
				})
				task.delay(4, function()
					if img.Parent and not img.IsLoaded then fb.Visible = true end
				end)
			end
		else
			img.Image = string.match(icon, "^%d+$") and ("rbxassetid://" .. icon) or icon
		end
		return img
	end
	return New("TextLabel", {
		Size = size, Position = pos, BackgroundTransparency = 1, Text = tostring(icon), Font = Enum.Font.GothamBold,
		TextSize = math.max(10, math.floor(size.Y.Offset * 0.85)), TextColor3 = color, ZIndex = z or 1, Parent = parent,
	})
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
local WIN_W, WIN_H = 560, 340

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
MakeIcon(TopBar, "search", UDim2.fromOffset(16, 16), UDim2.fromOffset(143, 12), RGB(190, 195, 220), 7)
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
local GearBtn = TopBtn("", -76, 17)
MakeIcon(GearBtn, "settings", UDim2.fromOffset(18, 18), UDim2.fromOffset(6, 6), WHITE, 9)
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
	MakeIcon(btn, icon, UDim2.fromOffset(18, 18), UDim2.fromOffset(7, 6), WHITE, 3)
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
local Home = CreateTab("Home", "house", "ホーム", "Home")
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
		Size = UDim2.new(1, -112, 0, 22), Position = UDim2.fromOffset(108, 10), BackgroundTransparency = 1, Text = LocalPlayer.DisplayName,
		Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
	New("TextLabel", {
		Size = UDim2.new(1, -92, 0, 16), Position = UDim2.fromOffset(86, 32), BackgroundTransparency = 1, Text = "@" .. LocalPlayer.Name .. "  ·  ID " .. LocalPlayer.UserId,
		Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = RGB(170, 175, 205), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
	})
	HomeRef.Uptime = New("TextLabel", {
		Size = UDim2.new(1, -92, 0, 16), Position = UDim2.fromOffset(108, 54), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = RGB(255, 225, 140), TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
	})
	HomeRef.Server = New("TextLabel", {
		Size = UDim2.new(1, -92, 0, 16), Position = UDim2.fromOffset(108, 71), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = RGB(150, 200, 255), TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
	})
	MakeIcon(card, "house", UDim2.fromOffset(18, 18), UDim2.fromOffset(86, 12), RGB(255, 225, 140), 3)
	MakeIcon(card, "clock", UDim2.fromOffset(15, 15), UDim2.fromOffset(88, 55), RGB(255, 225, 140), 3)
	MakeIcon(card, "users", UDim2.fromOffset(15, 15), UDim2.fromOffset(88, 72), RGB(150, 200, 255), 3)
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
local NoBlob = CreateTab("NoBlob", "crosshair", "ノーブロブ", "No Blob")
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
local SettingsTab = CreateTab("Settings", "settings", "設定", "Settings")
Section(SettingsTab, "パラメータ", "Parameters")
Slider(SettingsTab, "半径", "Radius", 1, 200, 30, 0, "Radius", nil, "Store.Radius に保存されます", "Saved to Store.Radius")
Slider(SettingsTab, "高さ", "Height", 0, 100, 10, 0, "Height", nil, "Store.Height に保存されます", "Saved to Store.Height")
Slider(SettingsTab, "P値", "P Value", 100, 20000, 5000, 0, "PValue", nil, "Store.PValue に保存されます", "Saved to Store.PValue")
Slider(SettingsTab, "MaxForce", "MaxForce", 1000, 1000000, 100000, 0, "MaxForce", nil, "Store.MaxForce に保存されます", "Saved to Store.MaxForce")

-- ======================================================================
-- TAB: PLAYERS (dropdown, search, multi-select)
-- ======================================================================
local PlayersTab = CreateTab("Players", "users", "プレイヤー", "Players")
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
	SelHeaderLbl.Text = (ListOpen and "v " or "> ") .. Tr("選択中: ", "Selected: ") .. n .. " / " .. #Players:GetPlayers()
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
local KeysTab = CreateTab("Keys", "keyboard", "キーバインド", "Keybinds")
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
				Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -62, 0, 110 + idx * 54), BackgroundColor3 = WHITE, Text = "",
				TextSize = 20, TextColor3 = WHITE, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 30, Parent = Gui,
			})
			Corner(pin, 23)
			MakeIcon(pin, info.icon, UDim2.fromOffset(24, 24), UDim2.fromOffset(11, 11), WHITE, 31)
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
	if KeyRows[id] then
		KeyRows[id].pin.TextColor3 = Config.Pins[id] and RGB(255, 215, 90) or RGB(120, 125, 150)
		IconColor(KeyRows[id].pinIcon, Config.Pins[id] and RGB(255, 215, 90) or RGB(120, 125, 150))
	end
end

local function RefreshKeyRows()
	for id, r in pairs(KeyRows) do
		r.key.Text = (Rebind == id) and "..." or ("[" .. ShortKey(Config.Keys[id]) .. "]")
		r.pin.TextColor3 = Config.Pins[id] and RGB(255, 215, 90) or RGB(120, 125, 150)
		IconColor(r.pinIcon, Config.Pins[id] and RGB(255, 215, 90) or RGB(120, 125, 150))
	end
	RefreshBadges()
end

for _, a in ipairs(ActionList) do
	local row = New("Frame", {Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = RGB(20, 20, 36), LayoutOrder = Order(KeysTab), Parent = KeysTab})
	Corner(row, 9)
	GoldStroke(row, 1)
	local nameLbl = New("TextLabel", {
		Size = UDim2.new(1, -166, 1, 0), Position = UDim2.fromOffset(36, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = RGB(228, 232, 248), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	Txt(nameLbl, a.ja, a.en)
	MakeIcon(row, a.icon, UDim2.fromOffset(18, 18), UDim2.fromOffset(10, 8), RGB(255, 225, 140), 3)
	local keyBtn = New("TextButton", {
		Size = UDim2.fromOffset(72, 24), Position = UDim2.new(1, -118, 0.5, -12), BackgroundColor3 = RGB(10, 10, 18), Text = "",
		Font = Enum.Font.Code, TextSize = 12, TextColor3 = RGB(255, 225, 140), AutoButtonColor = false, Parent = row,
	})
	Corner(keyBtn, 7)
	GoldStroke(keyBtn, 1)
	local pinBtn = New("TextButton", {
		Size = UDim2.fromOffset(34, 24), Position = UDim2.new(1, -40, 0.5, -12), BackgroundColor3 = RGB(10, 10, 18), Text = "",
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = RGB(120, 125, 150), AutoButtonColor = false, Parent = row,
	})
	Corner(pinBtn, 7)
	GoldStroke(pinBtn, 1)
	local pinIcon = MakeIcon(pinBtn, "pin", UDim2.fromOffset(16, 16), UDim2.fromOffset(9, 4), RGB(120, 125, 150), 3)
	KeyRows[a.id] = {key = keyBtn, pin = pinBtn, pinIcon = pinIcon}
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
local LogTab = CreateTab("Log", "scroll-text", "ログ", "Log")
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
-- TAB: PROTECT (anti-lag / anti-grab / anti-kick / anti-ragdoll / anti-void)
-- All protections only affect YOUR OWN client / character.
-- ======================================================================
local Protect = CreateTab("Protect", "shield", "防御", "Protection")
local Prot = {Lag = true, Grab = true, Kick = true, Ragdoll = true, Void = true, Spin = false}
local ProtState = {LastSafe = nil, VoidCd = 0, GrabToast = 0}
local ProtAlive = true

local function ProtRoot()
	local c = LocalPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function ProtHum()
	local c = LocalPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local ZERO = Vector3.new(0, 0, 0)

-- ---------------- Anti-Lag: tame effect spam from the world ----------------
local LAG_CLASSES = {ParticleEmitter = true, Smoke = true, Fire = true, Sparkles = true, Trail = true, Beam = true}
local LagTouched = setmetatable({}, {__mode = "k"})
local LagSweeping = false

local function LagTame(inst)
	local cn = inst.ClassName
	if not LAG_CLASSES[cn] and cn ~= "Explosion" then return false end
	if LagTouched[inst] then return false end
	local cam = workspace.CurrentCamera
	local char = LocalPlayer.Character
	if (char and inst:IsDescendantOf(char)) or (cam and inst:IsDescendantOf(cam)) or inst:IsDescendantOf(Gui) then return false end
	if cn == "Explosion" then
		LagTouched[inst] = true
		inst.Visible = false
		return true
	end
	if inst.Enabled then
		LagTouched[inst] = true
		inst.Enabled = false
		return true
	end
	return false
end

local function LagSweep()
	if LagSweeping then return 0 end
	LagSweeping = true
	local n = 0
	local list = workspace:GetDescendants()
	for i, d in ipairs(list) do
		local ok, did = pcall(LagTame, d)
		if ok and did then n = n + 1 end
		if i % 400 == 0 then task.wait() end
	end
	LagSweeping = false
	return n
end

local function LagRestore()
	for inst in pairs(LagTouched) do
		if inst.Parent then
			pcall(function()
				if inst.ClassName == "Explosion" then inst.Visible = true else inst.Enabled = true end
			end)
		end
		LagTouched[inst] = nil
	end
end

Connect(workspace.DescendantAdded, function(inst)
	if Prot.Lag then
		task.defer(function() pcall(LagTame, inst) end)
	end
end)

-- ---------------- Anti-Grab: remove foreign movers / constraints on my character ----------------
local BODY_MOVERS = {
	BodyPosition = true, BodyVelocity = true, BodyGyro = true, BodyForce = true,
	BodyThrust = true, BodyAngularVelocity = true, RocketPropulsion = true,
}

local function ForeignLink(inst, char)
	if inst.Name == "SeatWeld" then return false end
	if inst:IsA("Constraint") then
		local a0, a1 = inst.Attachment0, inst.Attachment1
		local in0 = a0 ~= nil and a0:IsDescendantOf(char)
		local in1 = a1 ~= nil and a1:IsDescendantOf(char)
		return (in0 and a1 ~= nil and not in1) or (in1 and a0 ~= nil and not in0)
	elseif inst:IsA("WeldConstraint") or inst:IsA("JointInstance") then
		local p0, p1 = inst.Part0, inst.Part1
		local in0 = p0 ~= nil and p0:IsDescendantOf(char)
		local in1 = p1 ~= nil and p1:IsDescendantOf(char)
		return (in0 and p1 ~= nil and not in1) or (in1 and p0 ~= nil and not in0)
	end
	return false
end

local function GrabScan()
	local char = LocalPlayer.Character
	if not char then return 0 end
	local n = 0
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			for _, ch in ipairs(part:GetChildren()) do
				if BODY_MOVERS[ch.ClassName] then
					pcall(function() ch:Destroy() end)
					n = n + 1
				elseif ch:IsA("Attachment") then
					local ok, cons = pcall(function() return ch:GetConstraints() end)
					if ok then
						for _, c in ipairs(cons) do
							if ForeignLink(c, char) then
								pcall(function() c:Destroy() end)
								n = n + 1
							end
						end
					end
				end
			end
			local ok, joints = pcall(function() return part:GetJoints() end)
			if ok then
				for _, j in ipairs(joints) do
					if ForeignLink(j, char) then
						pcall(function() j:Destroy() end)
						n = n + 1
					end
				end
			end
		end
	end
	return n
end

local function BreakFree()
	local n = GrabScan()
	local hum, root = ProtHum(), ProtRoot()
	if root then
		root.AssemblyLinearVelocity = ZERO
		root.AssemblyAngularVelocity = ZERO
	end
	if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
	return n
end

-- ---------------- Anti-Kick: block client-side Kick calls on my player ----------------
local KickInstalled = false
local OrigKick = nil
local function InstallAntiKick()
	if KickInstalled then return end
	local ok, err = pcall(function()
		OrigKick = hookfunction(LocalPlayer.Kick, newcclosure(function(self, ...)
			if Prot.Kick and not checkcaller() and self == LocalPlayer then
				task.defer(function()
					Toast("warn", Tr("アンチキック", "Anti-Kick"), Tr("キックをブロックしました", "Blocked a kick attempt"), 4)
				end)
				return
			end
			return OrigKick(self, ...)
		end))
	end)
	KickInstalled = ok
	if not ok then
		Toast("error", Tr("アンチキック", "Anti-Kick"), tostring(err), 5)
		Notify("Aura Hub", "Anti-Kick hook error: " .. string.sub(tostring(err), 1, 80), 4)
	end
end

-- ---------------- Anti-Ragdoll / Anti-Void ----------------
local RAG_STATES = {Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown}
local function RagdollSet(hum, enabled)
	for _, st in ipairs(RAG_STATES) do
		pcall(function() hum:SetStateEnabled(st, enabled) end)
	end
end
local function RagdollTick(hum)
	RagdollSet(hum, false)
	if hum.PlatformStand then hum.PlatformStand = false end
	local st = hum:GetState()
	if st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function SafeSpot()
	local sp = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = sp and sp.Position or Vector3.new(0, 0, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ch = LocalPlayer.Character
	if ch then params.FilterDescendantsInstances = {ch} end
	local r = workspace:Raycast(Vector3.new(base.X, base.Y + 500, base.Z), Vector3.new(0, -1500, 0), params)
	local y = r and r.Position.Y or base.Y
	return Vector3.new(base.X, y + 5, base.Z)
end

local function VoidTick(hum, root)
	local fh = workspace.FallenPartsDestroyHeight
	local threshold = (fh > -100000) and (fh + 150) or -1000
	local pos = root.Position
	if hum.FloorMaterial ~= Enum.Material.Air and pos.Y > threshold + 50 then
		ProtState.LastSafe = root.CFrame
	end
	if pos.Y < threshold and tick() > ProtState.VoidCd then
		ProtState.VoidCd = tick() + 1.5
		local cf = ProtState.LastSafe or CFrame.new(SafeSpot())
		root.AssemblyLinearVelocity = ZERO
		root.AssemblyAngularVelocity = ZERO
		root.CFrame = cf + Vector3.new(0, 4, 0)
		Toast("warn", Tr("アンチボイド", "Anti-Void"), Tr("安全な場所へ戻しました", "Returned you to a safe spot"), 3)
	end
end

-- ---------------- protection loop ----------------
local ProtAcc1, ProtAcc2 = 0, 0
Connect(RunService.Heartbeat, function(dt)
	if not ProtAlive then return end
	ProtAcc1 = ProtAcc1 + dt
	ProtAcc2 = ProtAcc2 + dt
	if ProtAcc1 >= 0.1 then
		ProtAcc1 = 0
		local hum, root = ProtHum(), ProtRoot()
		if hum and root and hum.Health > 0 then
			if Prot.Ragdoll then pcall(RagdollTick, hum) end
			if Prot.Void then pcall(VoidTick, hum, root) end
			if Prot.Spin then
				pcall(function()
					if root.AssemblyAngularVelocity.Magnitude > 8 then root.AssemblyAngularVelocity = ZERO end
				end)
			end
		end
	end
	if ProtAcc2 >= 0.2 then
		ProtAcc2 = 0
		if Prot.Grab then
			local ok, n = pcall(GrabScan)
			if ok and n > 0 and tick() > ProtState.GrabToast then
				ProtState.GrabToast = tick() + 3
				Toast("success", Tr("アンチグラブ", "Anti-Grab"), Tr("掴みを解除しました", "Released a grab"), 2.5)
			end
		end
	end
end)

-- ======================================================================
-- FTAP ANTI LAYER
-- Ported from the supplied anti script (Anti-Grab / Anti-Ragdoll / Anti-Grab (Ragdoll) /
-- Anti-Void / Anti-Sit / Anti-Sticky / Anti-Lag / Anti-Burn / Anti-Explosion / Anti-Paint /
-- Anti-Kick (tool / item) / GUCCI Anti-Grab / Anti Network / Auto Delete Legs).
-- These only touch YOUR OWN character, YOUR OWN toys and YOUR OWN client.
-- ======================================================================
local RSvc = game:GetService("ReplicatedStorage")
local FT = {cons = {}, On = {}, Run = {}, KickTool = "ToolPickaxe", KickItem = "SpookyCandle1", ANItem = "CupMugBrown", IsFTAP = false}

local function FTResolve()
	local ge = RSvc:FindFirstChild("GrabEvents")
	local ce = RSvc:FindFirstChild("CharacterEvents")
	local mt = RSvc:FindFirstChild("MenuToys")
	local pe = RSvc:FindFirstChild("PlayerEvents")
	FT.SetNetworkOwner = ge and ge:FindFirstChild("SetNetworkOwner")
	FT.Struggle = ce and ce:FindFirstChild("Struggle")
	FT.RagdollRemote = ce and ce:FindFirstChild("RagdollRemote")
	FT.SpawnToy = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
	FT.DestroyToy = mt and mt:FindFirstChild("DestroyToy")
	FT.Sticky = pe and pe:FindFirstChild("StickyPartEvent")
	FT.IsFTAP = (FT.Struggle ~= nil and FT.RagdollRemote ~= nil and FT.SetNetworkOwner ~= nil)
	return FT.IsFTAP
end
FTResolve()

local function FTWarn(name)
	Toast("warn", name, Tr("FTAP専用の機能です (このゲームでは使えません)", "FTAP-only feature (not available in this game)"), 3)
end

local function FTClr(name)
	local c = FT.cons[name]
	if c then
		pcall(function() c:Disconnect() end)
		FT.cons[name] = nil
	end
end

local function FTBeat(name, fn)
	FTClr(name)
	FT.cons[name] = RunService.Heartbeat:Connect(function(dt)
		pcall(fn, dt)
	end)
end

local function FTScript(name)
	local ps = LocalPlayer:FindFirstChild("PlayerScripts")
	return ps and ps:FindFirstChild(name)
end

local function FTSno(part)
	if FT.SetNetworkOwner and part then
		pcall(function() FT.SetNetworkOwner:FireServer(part, part.CFrame) end)
	end
end

local function FTDestroyToy(model)
	if model and FT.DestroyToy then
		pcall(function() FT.DestroyToy:FireServer(model) end)
	end
end

-- player's own plot (spawned toys go there when you are inside your own plot)
local function FTHome()
	local plots = workspace:FindFirstChild("Plots")
	local items = workspace:FindFirstChild("PlotItems")
	if not (plots and items) then return nil end
	for i = 1, 5 do
		local plot = plots:FindFirstChild("Plot" .. i)
		local sign = plot and plot:FindFirstChild("PlotSign")
		local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
		if owners then
			for _, v in ipairs(owners:GetChildren()) do
				if v.Value == LocalPlayer.Name then return items:FindFirstChild("Plot" .. i) end
			end
		end
	end
	return nil
end

local function FTSpawnToy(toyName, cf)
	if not (FT.SpawnToy and cf) then return nil end
	local inPlot = LocalPlayer:FindFirstChild("InPlot")
	local inOwned = LocalPlayer:FindFirstChild("InOwnedPlot")
	local canSpawn = LocalPlayer:FindFirstChild("CanSpawnToy")
	if inPlot and inPlot.Value and inOwned and not inOwned.Value then return nil end
	if canSpawn and not canSpawn.Value then
		local t0 = tick()
		while not canSpawn.Value and tick() - t0 < 3 do task.wait(0.1) end
		if not canSpawn.Value then return nil end
	end
	local container = (inOwned and inOwned.Value) and FTHome() or workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
	if not container then return nil end
	local spawned = nil
	local conn = container.ChildAdded:Connect(function(child)
		if child.Name == toyName then spawned = child end
	end)
	task.spawn(function()
		pcall(function() FT.SpawnToy:InvokeServer(toyName, cf, ZERO) end)
	end)
	local t0 = tick()
	while not spawned and tick() - t0 < 2.5 do task.wait() end
	conn:Disconnect()
	return spawned
end

local function FTPCLD(hrp)
	if FT.PCLD and FT.PCLD.Parent then return FT.PCLD end
	for _, v in ipairs(workspace:GetChildren()) do
		if v.Name == "PlayerCharacterLocationDetector" and v:IsA("BasePart") and (v.Position - hrp.Position).Magnitude <= 2 then
			FT.PCLD = v
			return v
		end
	end
	return nil
end
Connect(LocalPlayer.CharacterAdded, function() FT.PCLD = nil end)

-- ---------------- Anti-Grab ----------------
local function FTAntiGrab(on)
	if not on then FTClr("Grab") return end
	FTBeat("Grab", function()
		local hrp, hum = ProtRoot(), ProtHum()
		if hrp and hum and hrp.ReceiveAge ~= 0 then
			hrp.Anchored = true
			local ih = LocalPlayer:FindFirstChild("IsHeld")
			if ih then ih.Value = false end
			task.spawn(function()
				pcall(function()
					FT.Struggle:FireServer()
					FT.RagdollRemote:FireServer(hrp, 0)
				end)
			end)
			hum.AutoRotate = true
			local rj = hrp:FindFirstChild("RootJoint")
			if rj then rj.Enabled = true end
			hrp.Anchored = false
		end
	end)
end

-- ---------------- Anti-Ragdoll ----------------
local function FTAntiRagdoll(on)
	if not on then FTClr("Ragdoll") return end
	FTBeat("Ragdoll", function()
		local hrp, hum = ProtRoot(), ProtHum()
		if hrp and hum then
			if hum.PlatformStand then hum.PlatformStand = false end
			if hum.Sit and not hum.SeatPart then hum.Sit = false end
			local rd = hum:FindFirstChild("Ragdolled")
			if rd and rd.Value and FT.RagdollRemote then FT.RagdollRemote:FireServer(hrp, 0) end
		end
	end)
end

-- ---------------- Anti-Grab (Ragdoll) ----------------
local function FTAntiGrabRG(on)
	FT.On.AGRG = on and true or false
	FTClr("AGHead")
	FTClr("AGChar")
	if not on then return end
	local busy = false
	local function setup(c)
		if not c then return end
		local h = c:WaitForChild("HumanoidRootPart", 5)
		local hu = c:WaitForChild("Humanoid", 5)
		local hd = c:WaitForChild("Head", 5)
		if not (h and hu and hd) then return end
		FTClr("AGHead")
		FT.cons.AGHead = hd.ChildAdded:Connect(function(po)
			if po.Name == "PartOwner" and not busy then
				busy = true
				hu.Sit = false
				pcall(function() FT.Struggle:FireServer(LocalPlayer) end)
				task.spawn(function()
					local ih = LocalPlayer:FindFirstChild("IsHeld")
					while FT.On.AGRG and ((hd and hd:FindFirstChild("PartOwner")) or (ih and ih.Value)) do
						pcall(function()
							FT.Struggle:FireServer(LocalPlayer)
							FT.RagdollRemote:FireServer(h, 0)
						end)
						task.wait()
					end
				end)
				h.Anchored = true
				task.wait(0.5)
				h.Anchored = false
				busy = false
			end
		end)
	end
	task.spawn(setup, LocalPlayer.Character)
	FT.cons.AGChar = LocalPlayer.CharacterAdded:Connect(function(c) task.spawn(setup, c) end)
end

-- ---------------- Anti-Void (FallenPartsDestroyHeight) ----------------
local function FTAntiVoid(on)
	if on then
		if not FT.Orig.Void then FT.Orig.Void = workspace.FallenPartsDestroyHeight end
		workspace.FallenPartsDestroyHeight = -1e95
	else
		workspace.FallenPartsDestroyHeight = FT.Orig.Void or -500
	end
end

-- ---------------- Anti-Sit ----------------
local function FTAntiSit(on)
	if not on then FTClr("Sit") return end
	FTBeat("Sit", function()
		local hrp, hum = ProtRoot(), ProtHum()
		if hum and hrp and hum.Health > 0 then
			hum.Sit = false
			hum:ChangeState(Enum.HumanoidStateType.Running)
			local cam = workspace.CurrentCamera
			if cam then
				local v = cam.CFrame.LookVector
				hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(v.X, 0, v.Z))
			end
		end
	end)
end

-- ---------------- Anti-Sticky / Anti-Lag (local detection scripts) ----------------
local function FTAntiSticky(on)
	local s = FTScript("StickyPartsTouchDetection")
	if s then s.Enabled = not on end
end
local function FTAntiLag(on)
	local a = FTScript("CharacterAndBeamMove")
	local b = FTScript("StickyPartsTouchDetection")
	if a then a.Enabled = not on end
	if b then b.Enabled = not on end
end

-- ---------------- Anti-Burn / Anti-Explosion ----------------
local function FTAntiBurn(on)
	if not on then FTClr("Burn") return end
	FTBeat("Burn", function()
		local hrp = ProtRoot()
		if hrp then
			for _, v in ipairs(hrp:GetChildren()) do
				if v.Name == "FireLight" or v.Name == "FireParticleEmitter" or v.Name == "Fire" then v:Destroy() end
			end
		end
	end)
end

local function FTAntiExplosion(on)
	FTClr("Explosion")
	if not on then return end
	FT.cons.Explosion = workspace.ChildAdded:Connect(function(model)
		if model.Name == "Part" and model:IsA("BasePart") then
			local hrp = ProtRoot()
			if hrp and (model.Position - hrp.Position).Magnitude <= 20 then
				hrp.Anchored = true
				task.wait(0.01)
				hrp.Anchored = false
			end
		end
	end)
end

-- ---------------- Anti-Paint ----------------
FT.Paint = {backup = {}, conn = nil}
local function FTPaintTake(obj)
	if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then
		local ok, clone = pcall(function() return obj:Clone() end)
		if ok and clone then
			table.insert(FT.Paint.backup, {clone = clone, parent = obj.Parent})
		end
		obj:Destroy()
	end
end
local function FTAntiPaint(on)
	local P = FT.Paint
	if on then
		for _, obj in ipairs(workspace:GetDescendants()) do
			pcall(FTPaintTake, obj)
		end
		if P.conn then P.conn:Disconnect() end
		P.conn = workspace.DescendantAdded:Connect(function(obj)
			if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then
				task.defer(function()
					if obj and obj.Parent then pcall(FTPaintTake, obj) end
				end)
			end
		end)
	else
		if P.conn then
			P.conn:Disconnect()
			P.conn = nil
		end
		for _, d in ipairs(P.backup) do
			if d.clone and d.parent and d.parent.Parent then
				pcall(function() d.clone.Parent = d.parent end)
			end
		end
		P.backup = {}
	end
end

-- ---------------- Anti-Kick (tool stuck onto your own FirePlayerPart) ----------------
local TOOL_CONFIGS = {
	ToolPickaxe = {REAL_NAME = "ToolPickaxe", POS_X = -0.5, POS_Y = 0.5, POS_Z = 0.8, ANGLE_Z = 90, FLAT_Y = 90, OFFSET_X = 220, OFFSET_Y = 0, OFFSET_Z = 0},
	ToolCleaver = {REAL_NAME = "ToolCleaver", POS_X = 0, POS_Y = -0.5, POS_Z = 0.8, ANGLE_Z = 90, FLAT_Y = 90, OFFSET_X = 230, OFFSET_Y = 0, OFFSET_Z = 0},
	ToolCleaver2 = {REAL_NAME = "ToolCleaver", POS_X = -1, POS_Y = -1.7, POS_Z = 0.5, ANGLE_Z = 90, FLAT_Y = 361, OFFSET_X = 195, OFFSET_Y = 0, OFFSET_Z = 0},
	ToolPencil = {REAL_NAME = "ToolPencil", POS_X = 0, POS_Y = -1, POS_Z = -0.2, ANGLE_Z = 90, FLAT_Y = -180, OFFSET_X = 0, OFFSET_Y = 0, OFFSET_Z = 0},
	NinjaKunai = {REAL_NAME = "NinjaKunai", POS_X = 0, POS_Y = -1, POS_Z = 0.2, ANGLE_Z = 90, FLAT_Y = 90, OFFSET_X = -360, OFFSET_Y = 0, OFFSET_Z = 0},
}

local function FTAttachAngle(cfg)
	return CFrame.Angles(0, math.rad(cfg.FLAT_Y), 0)
		* CFrame.Angles(math.rad(cfg.OFFSET_X), math.rad(cfg.OFFSET_Y), math.rad(cfg.OFFSET_Z))
		* CFrame.Angles(0, 0, math.rad(cfg.ANGLE_Z))
end

local function FTClearKick()
	local inv = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
	if inv then
		for _, v in ipairs(inv:GetChildren()) do
			if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then FTDestroyToy(v) end
		end
	end
end

local function FTStick(tool, attach)
	local sp = tool:FindFirstChild("StickyPart")
	local hrp = ProtRoot()
	if not (sp and hrp and FT.Sticky) then return end
	local fire = hrp:FindFirstChild("FirePlayerPart") or hrp:WaitForChild("FirePlayerPart", 5)
	if not fire then return end
	for _, o in ipairs(tool:GetChildren()) do
		if o:IsA("BasePart") then
			o.CanTouch = false
			o.CanCollide = false
			o.CanQuery = false
			o.AssemblyLinearVelocity = ZERO
			o.AssemblyAngularVelocity = ZERO
		end
	end
	local soundPart = tool:FindFirstChild("SoundPart")
	if soundPart then
		local po = soundPart:FindFirstChild("PartOwner")
		if not po or po.Value ~= LocalPlayer.Name then FTSno(soundPart) end
	end
	pcall(function() tool:PivotTo(fire.CFrame * attach) end)
	pcall(function() FT.Sticky:FireServer(sp, fire, attach) end)
end

local function FTStartAntiKick()
	local cfg = TOOL_CONFIGS[FT.KickTool]
	if not (FT.Sticky and FT.SpawnToy and cfg) then
		Toast("error", "Anti-Kick", Tr("Remote が見つかりません", "Remote not found"), 4)
		return
	end
	FT.On.Kick = true
	FT.Run.Kick = (FT.Run.Kick or 0) + 1
	local myRun = FT.Run.Kick
	local realName = cfg.REAL_NAME
	local attach = CFrame.new(cfg.POS_X, cfg.POS_Y, cfg.POS_Z) * FTAttachAngle(cfg)
	task.spawn(function()
		while FT.On.Kick and myRun == FT.Run.Kick do
			task.wait(0.05)
			local hum, hrp = ProtHum(), ProtRoot()
			if not hum or not hrp or hum.Health <= 0 then continue end
			local inv = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
			local tool = inv and (inv:FindFirstChild("AntiKick") or inv:FindFirstChild(realName))
			if not tool then
				local inPlot = LocalPlayer:FindFirstChild("InPlot")
				local inOwned = LocalPlayer:FindFirstChild("InOwnedPlot")
				if inPlot and inPlot.Value and not (inOwned and inOwned.Value) then continue end
				tool = FTSpawnToy(realName, hrp.CFrame * CFrame.new(0, 2, 2))
				if not tool then continue end
				tool.Name = "AntiKick"
			end
			local sp = tool:FindFirstChild("StickyPart")
			if sp then
				local weld = sp:FindFirstChild("StickyWeld")
				local isWelded = weld and weld.Part1 ~= nil
				if not isWelded and sp.CanTouch == true then
					FTStick(tool, attach)
					tool.Name = "AntiKick"
					task.wait(0.15)
				end
				if (hrp.Position - sp.Position).Magnitude >= 20 then FTClearKick() end
			end
		end
		FTClearKick()
	end)
end

local function FTStopAntiKick()
	FT.On.Kick = false
	FT.Run.Kick = (FT.Run.Kick or 0) + 1
	task.delay(0.2, FTClearKick)
end

-- ---------------- Anti-Kick [ITEM] ----------------
local function FTClearItems()
	local inv = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
	if inv then
		for _, v in ipairs(inv:GetChildren()) do
			if v.Name == "AntiKickItem" then FTDestroyToy(v) end
		end
	end
end

local function FTStartKickItem()
	if not (FT.SpawnToy and FT.SetNetworkOwner) then
		Toast("error", "Anti-Kick [ITEM]", Tr("Remote が見つかりません", "Remote not found"), 4)
		return
	end
	FT.On.Item = true
	FT.Run.Item = (FT.Run.Item or 0) + 1
	local myRun = FT.Run.Item
	task.spawn(function()
		while FT.On.Item and myRun == FT.Run.Item do
			task.wait()
			local hum, hrp = ProtHum(), ProtRoot()
			local inv = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
			local inPlot = LocalPlayer:FindFirstChild("InPlot")
			if not (hum and hrp and inv) or hum.Health <= 0 then continue end
			if inPlot and inPlot.Value then continue end
			local item = inv:FindFirstChild("AntiKickItem")
			local hitbox = item and item:FindFirstChild("Hitbox")
			if not item or not hitbox then
				for _, v in ipairs(inv:GetChildren()) do
					if v.Name == "AntiKickItem" then FTDestroyToy(v) end
				end
				local pcld = FTPCLD(hrp)
				item = FTSpawnToy(FT.KickItem, (pcld or hrp).CFrame * CFrame.new(0, 14, 20))
				if not item then continue end
				hitbox = item:FindFirstChild("Hitbox") or item:WaitForChild("Hitbox", 0.5)
				if hitbox then FTSno(hitbox) end
				for _, v in ipairs(item:GetChildren()) do
					if v:IsA("BasePart") then
						v.CanCollide = false
						v.Transparency = 0.8
						v.Color = Color3.fromRGB(0, 255, 255)
					end
				end
				item.Name = "AntiKickItem"
			end
			if hitbox then
				local po = hitbox:FindFirstChild("PartOwner")
				if not (po and po.Value == LocalPlayer.Name) then FTSno(hitbox) end
				local target = FTPCLD(hrp) or hrp:FindFirstChild("FirePlayerPart") or hrp
				hitbox.CFrame = target.CFrame
				hitbox.AssemblyLinearVelocity = ZERO
				hitbox.AssemblyAngularVelocity = ZERO
			end
		end
	end)
end

local function FTStopKickItem()
	FT.On.Item = false
	FT.Run.Item = (FT.Run.Item or 0) + 1
	task.delay(0.2, FTClearItems)
end

-- ---------------- GUCCI Anti-Grab ----------------
local Gucci = {Type = "CreatureBlobman", Enabled = false, RunId = 0, Cleanup = nil}

local function GucciFindNicePart(model)
	if not model then return nil end
	for _, name in ipairs({"HumanoidRootPart", "SoundPart", "Handle", "Part", "PrimaryPart"}) do
		local p = model:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then return p end
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function GucciDestroyToy(model)
	if not model then return end
	pcall(function()
		if FT.DestroyToy then FT.DestroyToy:FireServer(model) end
		model:Destroy()
	end)
end

local function GucciSpawnToy(toyName, cf)
	if not FT.SpawnToy then return nil end
	local folder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys") or workspace:WaitForChild(LocalPlayer.Name .. "SpawnedInToys", 5)
	if not folder then return nil end
	local result = nil
	local conn
	conn = folder.ChildAdded:Connect(function(child)
		if child.Name == toyName or string.find(child.Name, toyName) then
			result = child
			if conn then conn:Disconnect() end
		end
	end)
	pcall(function() FT.SpawnToy:InvokeServer(toyName, cf or CFrame.new(0, 1e15, 0), ZERO) end)
	local t0 = tick()
	while not result and tick() - t0 < 3 do task.wait(0.05) end
	if conn then pcall(function() conn:Disconnect() end) end
	return result
end

local function GucciResetVelocity(part)
	if not part then return end
	pcall(function()
		part.AssemblyLinearVelocity = ZERO
		part.AssemblyAngularVelocity = ZERO
	end)
end

local function GucciTeleport(part, cf)
	if not part then return end
	pcall(function()
		part.CFrame = cf
		GucciResetVelocity(part)
	end)
end

local function GucciStop()
	Gucci.RunId = Gucci.RunId + 1
	if Gucci.Cleanup then
		local fn = Gucci.Cleanup
		Gucci.Cleanup = nil
		pcall(fn)
	end
end

local function GucciRun()
	Gucci.RunId = Gucci.RunId + 1
	local myId = Gucci.RunId
	local vehicle, seat, nicePart, usedType, hideConn = nil, nil, nil, nil, nil
	local respawnFlag = false
	local isHeldVal = LocalPlayer:FindFirstChild("IsHeld")

	local function cleanup()
		if hideConn then
			hideConn:Disconnect()
			hideConn = nil
		end
		if vehicle then
			GucciDestroyToy(vehicle)
			vehicle = nil
		end
		seat, nicePart, usedType = nil, nil, nil
	end
	Gucci.Cleanup = cleanup

	local function waitTypeChange(currentType)
		while true do
			task.wait()
			if Gucci.Type ~= currentType or not Gucci.Enabled or myId ~= Gucci.RunId then break end
		end
	end

	local function hideDescendant(desc)
		if desc:IsA("BasePart") then
			desc.Transparency = 1
			desc.CanCollide = false
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		elseif desc.Name == "ItemSpawnSound" then
			desc:Destroy()
		end
	end

	while true do
		if not (Gucci.Enabled and myId == Gucci.RunId) then break end
		task.wait()

		local char = LocalPlayer.Character
		local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health == 0 then
			LocalPlayer.CharacterAdded:Wait()
			respawnFlag = true
			task.delay(1, function() respawnFlag = false end)
			task.wait(0.16)
			continue
		end

		local ragdolled = hum:FindFirstChild("Ragdolled")
		if not hrp or not ragdolled or (isHeldVal and isHeldVal.Value) or ragdolled.Value or hum.Health <= 0 then
			continue
		end

		if hum.Sit then hum.Sit = false end

		local gucciType = Gucci.Type
		local stillValid = vehicle and vehicle.Parent and seat and seat.Parent and usedType == gucciType
		local canReuse = false
		if stillValid then
			local occupant = seat.Occupant
			if occupant == nil or occupant == hum then canReuse = true end
		end

		if not canReuse then
			cleanup()
			if gucciType == "Train" then
				local map = workspace:FindFirstChild("Map")
				map = map and map:FindFirstChild("AlwaysHereTweenedObjects")
				map = map and map:FindFirstChild("Train")
				local object = map and map:FindFirstChild("Object")
				object = object and object:FindFirstChild("ObjectModel")
				if not object then
					Toast("warn", "Gucci", "Train doesn't exist!", 3)
					waitTypeChange(gucciType)
					continue
				end
				vehicle = object
				seat = vehicle:FindFirstChildWhichIsA("Seat")
				nicePart = nil
				usedType = gucciType
				if not seat then
					Toast("warn", "Gucci", "Train doesn't have seats!", 3)
					waitTypeChange(gucciType)
					cleanup()
					continue
				end
			else
				vehicle = GucciSpawnToy(gucciType, CFrame.new(100000, 500000, 0))
				seat = vehicle and vehicle:WaitForChild("VehicleSeat", 1.25)
				nicePart = seat and GucciFindNicePart(vehicle) or nil
				usedType = gucciType
				if vehicle then
					for _, d in ipairs(vehicle:GetDescendants()) do hideDescendant(d) end
					hideConn = vehicle.DescendantAdded:Connect(hideDescendant)
				end
				if not seat then
					cleanup()
					continue
				end
			end
		end

		local vModel, vSeat, vPart = vehicle, seat, nicePart
		local activeSit = true
		if vPart then
			local old = vPart:FindFirstChild("GucciBP")
			if old then old:Destroy() end
		end
		vSeat.Transparency = 1
		vSeat.CanCollide = false
		local seatWeldDestroyed = false
		local savedCF = hrp.CFrame
		local sitStart = tick()

		vSeat.ChildAdded:Once(function(child)
			if child.Name == "SeatWeld" then
				child.Enabled = false
				child:Destroy()
				seatWeldDestroyed = true
			end
		end)

		local ragdollReady = false
		task.defer(function()
			while hum and hum.Health > 0 and activeSit and task.wait() do
				ragdollReady = true
				if FT.RagdollRemote then
					pcall(function() FT.RagdollRemote:FireServer(hrp, 0) end)
				end
			end
			ragdollReady = true
		end)

		while true do
			task.wait()
			if ragdollReady or myId ~= Gucci.RunId then break end
		end
		if myId ~= Gucci.RunId then
			activeSit = false
			cleanup()
			break
		end

		vSeat:Sit(hum)

		while true do
			task.wait()
			local dead = hum.Health <= 0 or not hrp.Parent or not vModel.Parent or not vSeat.Parent
			if dead then break end
			local done = (isHeldVal and isHeldVal.Value) or ragdolled.Value or seatWeldDestroyed or tick() - sitStart > 0.75
			if done then break end
		end

		if seatWeldDestroyed then
			hum.Sit = false
			task.delay(0.15, function()
				activeSit = false
				task.wait()
				if FT.RagdollRemote and hrp.Parent then
					pcall(function() FT.RagdollRemote:FireServer(hrp, 0.15) end)
				end
			end)
			if respawnFlag then GucciTeleport(hrp, savedCF) end
			if Gucci.Type ~= "Train" and vPart then
				local plotItems = workspace:FindFirstChild("PlotItems")
				local isOwned = plotItems and vPart:IsDescendantOf(plotItems)
				local gotOwner = isOwned
				if not gotOwner then
					FTSno(vPart)
					gotOwner = true
				end
				if gotOwner then
					local vector = Vector3.new(math.random(-100000, 100000), 100000, math.random(-100000, 100000))
					local bp = Instance.new("BodyPosition")
					bp.Name = "GucciBP"
					bp.D = 200
					bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
					bp.Position = vector
					vModel.Name = "GucciRSC"
					bp.Parent = vPart
				end
			end
			task.delay(0.75, function()
				if not vSeat or not vSeat.Parent or not vModel or not vModel.Parent then return end
				vSeat.Parent = RSvc
				task.wait()
				if hum and hum.Parent then hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end
				if vModel and vModel.Parent and vSeat then vSeat.Parent = vModel end
			end)

			while true do
				local parentOk = vModel.Parent and vSeat.Parent and hum.Parent
				local keep = parentOk and hum.Health > 0 and not (isHeldVal and isHeldVal.Value) and not ragdolled.Value
					and (vSeat.Occupant == nil or vSeat.Occupant == hum) and Gucci.Enabled and Gucci.Type == gucciType and myId == Gucci.RunId
				if keep then
					task.wait()
					continue
				end
				break
			end

			local occupant = vSeat.Occupant
			if occupant and occupant ~= hum and occupant.Parent then
				local other = Players:FindFirstChild(occupant.Parent.Name)
				if other then Toast("info", "Gucci", other.DisplayName .. " sat on your gucci!", 3) end
			end
			if hum and hum.Parent and hum.Health > 0 then
				if hum.SeatPart and hum.SeatPart ~= vSeat then
					Toast("warn", "Gucci", "You can't sit on other Vehicles while in Gucci!", 3)
				end
				hum.Sit = true
				task.wait(0.05)
				hum.Sit = false
				task.wait(0.05)
			end
		end

		if hideConn then
			hideConn:Disconnect()
			hideConn = nil
		end
		if vModel and vModel.Parent then GucciDestroyToy(vModel) end
		vehicle, seat, nicePart, usedType = nil, nil, nil, nil
		activeSit = false
		task.wait(0.05)
	end

	cleanup()
	if Gucci.Cleanup == cleanup then Gucci.Cleanup = nil end
end

local function FTGucci(on)
	Gucci.Enabled = on
	if on then task.spawn(GucciRun) else GucciStop() end
end

local function FTGucciBinder()
	local c = LocalPlayer.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not (h and r and FT.SpawnToy) then return end
	h.Sit = true
	task.wait(0.02)
	h.Sit = false
	task.wait(0.02)
	task.spawn(function()
		local t = tick()
		while tick() - t < 0.8 do
			for _, v in ipairs(c:GetChildren()) do
				if v:IsA("BasePart") then v.AssemblyLinearVelocity = ZERO end
			end
			task.wait(0.01)
		end
	end)
	local blob = nil
	task.spawn(function()
		pcall(function() FT.SpawnToy:InvokeServer("CreatureBlobman", r.CFrame * CFrame.new(0, 0, -5), Vector3.new(0, -15.716, 0)) end)
		local bp = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
		for _ = 1, 50 do
			blob = bp and bp:FindFirstChild("CreatureBlobman")
			if blob then break end
			task.wait(0.05)
		end
	end)
	for _ = 1, 100 do
		if blob then break end
		task.wait(0.02)
	end
	if not blob then return end
	local seatPart = blob:FindFirstChild("VehicleSeat") or blob:WaitForChild("VehicleSeat", 2)
	if seatPart then seatPart:Sit(h) end
	task.wait(0.4)
	h.Sit = false
	blob.Name = "Gucci"
	for _, v in ipairs(blob:GetChildren()) do
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.CanTouch = false
			v.CanQuery = false
		end
	end
end

-- ---------------- Anti Network (own toy held at your head) ----------------
local AN_LIST = {"CupMugBrown", "PoopPile", "FoodDippyEgg", "FoodCoconut", "FoodBroccoli", "FoodMayonnaise", "InstrumentGuitarViolin", "InstrumentGuitarBanjo"}
local function FTAntiNetwork(on)
	FT.On.AN = on and true or false
	if not on then
		FTClr("AN")
		local f = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
		local o = f and f:FindFirstChild(FT.ANItem)
		if o then FTDestroyToy(o) end
		return
	end
	local acc = 0
	FTBeat("AN", function(dt)
		acc = acc + dt
		if acc < 0.1 then return end
		acc = 0
		local f = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
		if not f then return end
		local o = f:FindFirstChild(FT.ANItem)
		local c = LocalPlayer.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if not o then
			if FT.SpawnToy and hrp then
				pcall(function() FT.SpawnToy:InvokeServer(FT.ANItem, hrp.CFrame, Vector3.new(0, 90, 0)) end)
			end
			return
		end
		local h = c and c:FindFirstChild("Head")
		local hp = o:FindFirstChild("HoldPart")
		if h and hp then
			local hR = hp:FindFirstChild("HoldItemRemoteFunction")
			local dR = hp:FindFirstChild("DropItemRemoteFunction")
			if hR and dR then
				local dp = h.CFrame * CFrame.new(0, 3, 0)
				task.spawn(function()
					pcall(function()
						hR:InvokeServer(o, c)
						dR:InvokeServer(o, dp, dp)
					end)
				end)
			end
		end
	end)
end

-- ---------------- Auto Delete Legs ----------------
local function FTDeleteLegs(c)
	if not c then return end
	local r, h, t = c:FindFirstChild("HumanoidRootPart"), c:FindFirstChild("Humanoid"), c:FindFirstChild("Torso")
	local ll, rl = c:FindFirstChild("Left Leg"), c:FindFirstChild("Right Leg")
	if not (r and h and t and ll and rl) then return end
	local void = workspace.FallenPartsDestroyHeight
	local pos = t.CFrame
	workspace.FallenPartsDestroyHeight = -100
	if FT.RagdollRemote then FT.RagdollRemote:FireServer(r, 2) end
	task.wait(0.5)
	rl.CFrame = CFrame.new(0, -10000, 0)
	ll.CFrame = CFrame.new(0, -10000, 0)
	task.wait(0.3)
	t.CFrame = CFrame.new(0, -9970, 0)
	task.wait(0.5)
	t.CFrame = pos
	task.wait(0.5)
	workspace.FallenPartsDestroyHeight = void
end

local function FTAutoLegs(on)
	FT.On.Legs = on and true or false
	FTClr("LegsChar")
	if not on then return end
	local function perform(c)
		task.wait(0.5)
		if not FT.On.Legs then return end
		pcall(FTDeleteLegs, c)
		local h = c and c:FindFirstChild("Humanoid")
		task.spawn(function()
			while FT.On.Legs and c and c.Parent and h and h.Health > 0 and not c:FindFirstChild("Left Leg") and not c:FindFirstChild("Right Leg") do
				pcall(function()
					local cg = LocalPlayer.PlayerGui:FindFirstChild("ControlsGui")
					if cg and cg:FindFirstChild("PCFrame") and cg.PCFrame:FindFirstChild("Stand") then
						if cg.PCFrame.Stand.Visible == false then h.HipHeight = 2 else h.HipHeight = 0 end
					end
				end)
				task.wait()
			end
		end)
	end
	task.spawn(perform, LocalPlayer.Character)
	FT.cons.LegsChar = LocalPlayer.CharacterAdded:Connect(function(nc)
		if FT.On.Legs then task.spawn(perform, nc) end
	end)
end

-- ---------------- release (used by the Plot Break hook) ----------------
local function FTRelease()
	local hrp = ProtRoot()
	if FT.IsFTAP and hrp then
		pcall(function()
			FT.Struggle:FireServer()
			FT.RagdollRemote:FireServer(hrp, 0)
		end)
		local ih = LocalPlayer:FindFirstChild("IsHeld")
		if ih then ih.Value = false end
	end
end

-- ---------------- cleanup (Unload) ----------------
local function FTCleanup()
	FT.On = {}
	for name in pairs(FT.cons) do FTClr(name) end
	pcall(GucciStop)
	pcall(FTClearKick)
	pcall(FTClearItems)
	pcall(FTAntiLag, false)
	pcall(FTAntiSticky, false)
	pcall(FTAntiPaint, false)
	pcall(function()
		if FT.Orig.Void then workspace.FallenPartsDestroyHeight = FT.Orig.Void end
	end)
end

local function ProtCleanup()
	pcall(FTCleanup)
	ProtAlive = false
	Prot.Lag, Prot.Grab, Prot.Kick, Prot.Void, Prot.Spin = false, false, false, false, false
	local hum = ProtHum()
	if hum and Prot.Ragdoll then RagdollSet(hum, true) end
	Prot.Ragdoll = false
	LagRestore()
end

-- ---------------- Feature switchboard (core 5 + FTAP anti features) ----------------
local Feat = {}

Feat.AntiLag = function(on)
	local useFT = FT.IsFTAP and (FTScript("CharacterAndBeamMove") ~= nil or FTScript("StickyPartsTouchDetection") ~= nil)
	Prot.Lag = on and not useFT
	if useFT then FTAntiLag(on) end
	if on and not useFT then
		task.spawn(function() pcall(LagSweep) end)
	end
	if not on then LagRestore() end
end

Feat.AntiGrab = function(on)
	Prot.Grab = on and not FT.IsFTAP
	if FT.IsFTAP then FTAntiGrab(on) end
end

Feat.AntiKick = function(on)
	Prot.Kick = on
	if on then InstallAntiKick() end
	if FT.IsFTAP then
		if on then FTStartAntiKick() else FTStopAntiKick() end
	end
end

Feat.AntiRagdoll = function(on)
	Prot.Ragdoll = on and not FT.IsFTAP
	if FT.IsFTAP then FTAntiRagdoll(on) end
	if not on then
		local hum = ProtHum()
		if hum then RagdollSet(hum, true) end
	end
end

Feat.AntiVoid = function(on)
	Prot.Void = on
	FTAntiVoid(on)
end

local function FTOnly(name, fn)
	return function(on)
		if not FT.IsFTAP then
			FTResolve()
			if not FT.IsFTAP then
				FTWarn(name)
				return
			end
		end
		fn(on)
	end
end

Feat.AntiGrabRG = FTOnly("Anti-Grab (Ragdoll)", FTAntiGrabRG)
Feat.AntiSit = FTOnly("Anti-Sit", FTAntiSit)
Feat.AntiSticky = FTOnly("Anti-Sticky", FTAntiSticky)
Feat.AntiBurn = FTOnly("Anti-Burn", FTAntiBurn)
Feat.AntiExplosion = FTOnly("Anti-Explosion", FTAntiExplosion)
Feat.AntiPaint = FTOnly("Anti-Paint", FTAntiPaint)
Feat.GucciGrab = FTOnly("GUCCI Anti-Grab", FTGucci)
Feat.AntiKickItem = FTOnly("Anti-Kick [ITEM]", function(on)
	if on then FTStartKickItem() else FTStopKickItem() end
end)
Feat.AntiNetwork = FTOnly("Anti Network", FTAntiNetwork)
Feat.AutoLegs = FTOnly("Auto Delete Legs", FTAutoLegs)

local function OnOff(name, on)
	Toast(on and "success" or "info", name, on and "ON" or "OFF", 2)
end

-- ---------------- Protect tab UI ----------------
Section(Protect, "防御", "Protection")
Toggle(Protect, "アンチラグ", "Anti-Lag", true, "AntiLag", function(s)
	Feat.AntiLag(s)
	OnOff(Tr("アンチラグ", "Anti-Lag"), s)
end, nil, "ラグ原因のスクリプト/エフェクトを止めます", "Stops lag-causing scripts / effects")
Toggle(Protect, "アンチグラブ", "Anti-Grab", true, "AntiGrab", function(s)
	Feat.AntiGrab(s)
	OnOff(Tr("アンチグラブ", "Anti-Grab"), s)
end, nil, "掴まれたら即解除します", "Frees you the moment you get grabbed")
Toggle(Protect, "アンチキック", "Anti-Kick", true, "AntiKick", function(s)
	Feat.AntiKick(s)
	OnOff(Tr("アンチキック", "Anti-Kick"), s)
end, nil, "選択したツールを自分に貼り付けてキックを防ぎます", "Sticks the selected tool onto you to block kicks")
Toggle(Protect, "アンチラグドール", "Anti-Ragdoll", true, "AntiRagdoll", function(s)
	Feat.AntiRagdoll(s)
	OnOff(Tr("アンチラグドール", "Anti-Ragdoll"), s)
end, nil, "ラグドール状態を即解除します", "Instantly recovers from ragdoll")
Toggle(Protect, "アンチボイド", "Anti-Void", true, "AntiVoid", function(s)
	Feat.AntiVoid(s)
	OnOff(Tr("アンチボイド", "Anti-Void"), s)
end, nil, "奈落に落ちても消えないようにします", "Stops the void from destroying you")

Section(Protect, "アンチグラブ / その他", "Anti-Grab / More")
Toggle(Protect, "アンチグラブ (ラグドール)", "Anti-Grab (Ragdoll)", false, "AntiGrabRG", function(s)
	Feat.AntiGrabRG(s)
	OnOff("Anti-Grab (Ragdoll)", s)
end, nil, "頭にPartOwnerが付いたら連続でもがきます", "Struggles repeatedly when a PartOwner is put on your head")
Toggle(Protect, "アンチシット", "Anti-Sit", false, "AntiSit", function(s)
	Feat.AntiSit(s)
	OnOff("Anti-Sit", s)
end)
Toggle(Protect, "アンチステッキー", "Anti-Sticky", false, "AntiSticky", function(s)
	Feat.AntiSticky(s)
	OnOff("Anti-Sticky", s)
end)
Toggle(Protect, "アンチバーン", "Anti-Burn", false, "AntiBurn", function(s)
	Feat.AntiBurn(s)
	OnOff("Anti-Burn", s)
end)
Toggle(Protect, "アンチ爆発", "Anti-Explosion", false, "AntiExplosion", function(s)
	Feat.AntiExplosion(s)
	OnOff("Anti-Explosion", s)
end)
Toggle(Protect, "アンチペイント", "Anti-Paint", false, "AntiPaint", function(s)
	Feat.AntiPaint(s)
	OnOff("Anti-Paint", s)
end)

Section(Protect, "アンチキック設定", "Anti-Kick settings")
Chips(Protect, {
	{id = "ToolPickaxe", ja = "ピッケル", en = "Pickaxe"}, {id = "ToolCleaver", ja = "包丁", en = "Cleaver"},
	{id = "ToolCleaver2", ja = "包丁2", en = "Cleaver2"}, {id = "ToolPencil", ja = "鉛筆", en = "Pencil"},
	{id = "NinjaKunai", ja = "クナイ", en = "Kunai"},
}, "ToolPickaxe", "KickTool", function(id)
	FT.KickTool = id
	if FT.On.Kick then
		task.spawn(function()
			FTStopAntiKick()
			task.wait(0.4)
			FTStartAntiKick()
		end)
	end
end)
Toggle(Protect, "アンチキック [ITEM]", "Anti-Kick [ITEM]", false, "AntiKickItem", function(s)
	Feat.AntiKickItem(s)
	OnOff("Anti-Kick [ITEM]", s)
end, nil, "アイテムを自分の位置に固定してキックを防ぎます", "Pins an item at your position to block kicks")
Chips(Protect, {
	{id = "JapaneseLantern", ja = "提灯", en = "Lantern"}, {id = "SprayCanWD", ja = "スプレー", en = "Spray"},
	{id = "SpookyCandle1", ja = "ろうそく", en = "Candle"},
}, "SpookyCandle1", "KickItem", function(id)
	FT.KickItem = id
	if FT.On.Item then
		task.spawn(function()
			FTStopKickItem()
			task.wait(0.4)
			FTStartKickItem()
		end)
	end
end)

Section(Protect, "[GUCCI] アンチグラブ", "[GUCCI] Anti-Grab")
Chips(Protect, {
	{id = "CreatureBlobman", ja = "ブロブマン", en = "Blobman"}, {id = "TractorGreen", ja = "トラクター", en = "Tractor"},
	{id = "Train", ja = "電車", en = "Train"}, {id = "SantaSleigh", ja = "そり", en = "Sleigh"},
}, "CreatureBlobman", "GucciType", function(id) Gucci.Type = id end)
Toggle(Protect, "[GUCCI] アンチグラブ", "[GUCCI] Anti Grab", false, "GucciGrab", function(s)
	Feat.GucciGrab(s)
	OnOff("[GUCCI] Anti Grab", s)
end, nil, "乗り物に座って掴みを回避します", "Dodges grabs by sitting in a vehicle")
Button(Protect, "Gucci Binder (1回)", "Gucci Binder (once)", function()
	if not FT.IsFTAP then FTResolve() end
	if not FT.IsFTAP then FTWarn("Gucci Binder") return end
	task.spawn(function()
		local ok, err = pcall(FTGucciBinder)
		if not ok then Toast("error", "Gucci", tostring(err), 4) end
	end)
end)

Section(Protect, "Anti Network / 足", "Anti Network / Legs")
local ANList = ListBox(Protect, 90)
local ANRows = {}
for _, name in ipairs(AN_LIST) do
	ANRows[name] = ANList.Add((name == FT.ANItem and "> " or "  ") .. name, function()
		FT.ANItem = name
		for n, r in pairs(ANRows) do
			r.Text = (n == name and "> " or "  ") .. n
		end
		if FT.On.AN then
			task.spawn(function()
				FTAntiNetwork(false)
				task.wait(0.2)
				FTAntiNetwork(true)
			end)
		end
	end)
end
Toggle(Protect, "Anti Network", "Anti Network", false, "AntiNetwork", function(s)
	Feat.AntiNetwork(s)
	OnOff("Anti Network", s)
end)
Toggle(Protect, "両足消し (自動)", "Auto Delete Legs", false, "AutoLegs", function(s)
	Feat.AutoLegs(s)
	OnOff("Auto Delete Legs", s)
end)
Button(Protect, "両足消し (手動)", "Delete Legs (manual)", function()
	if not FT.IsFTAP then FTResolve() end
	if not FT.IsFTAP then FTWarn("Delete Legs") return end
	task.spawn(function()
		local ok, err = pcall(FTDeleteLegs, LocalPlayer.Character)
		if not ok then Toast("error", "Delete Legs", tostring(err), 4) end
	end)
end)

-- ---------------- Hooks (overwrite the placeholders) ----------------
local PROT_KEYS = {"AntiLag", "AntiGrab", "AntiKick", "AntiRagdoll", "AntiVoid"}

Hooks.Run = function()
	for _, k in ipairs(PROT_KEYS) do
		if Reg[k] and not Reg[k].get() then pcall(Reg[k].set, true) end
	end
	local n = BreakFree()
	FTRelease()
	Toast("success", Tr("実行", "Run"), Tr("全ての防御を有効化しました (解除: ", "All protections enabled (released: ") .. n .. ")", 3)
end

Hooks.StopLag = function()
	if Reg.AntiLag and not Reg.AntiLag.get() then pcall(Reg.AntiLag.set, true) end
	local n = LagSweep()
	Toast("success", Tr("ラグ停止", "Stop Lag"), Tr("停止したエフェクト: ", "Effects stopped: ") .. n, 3)
end

Hooks.StopSpin = function(state)
	Prot.Spin = state and true or false
	Toast(state and "success" or "info", Tr("回転停止", "Stop Spin"), state and "ON" or "OFF", 2)
end

Hooks.CenterTP = function()
	local root = ProtRoot()
	if not root then
		Toast("warn", Tr("中心TP", "Center TP"), Tr("キャラクターがありません", "No character found"), 3)
		return
	end
	root.AssemblyLinearVelocity = ZERO
	root.CFrame = CFrame.new(SafeSpot())
	Toast("success", Tr("中心TP", "Center TP"), Tr("中心へ移動しました", "Teleported to the center"), 2.5)
end

Hooks.PlotBreak = function()
	local n = BreakFree()
	FTRelease()
	Toast("success", "Plot Break", Tr("拘束を解除しました: ", "Constraints removed: ") .. n, 3)
end

-- same handlers for the keybind / mobile-pin runners
ActionRun.Run = function() RunHook("Run") end
ActionRun.StopLag = function() RunHook("StopLag") end
ActionRun.CenterTP = function() RunHook("CenterTP") end
ActionRun.PlotBreak = function() RunHook("PlotBreak") end

-- default-ON features start working immediately
task.spawn(function()
	FTResolve()
	for _, k in ipairs(PROT_KEYS) do
		local f = Feat[k]
		if f then pcall(f, true) end
	end
end)

-- ======================================================================
-- TAB: UI SETTINGS
-- ======================================================================
local UITab = CreateTab("UI", "palette", "UI設定", "UI Settings")
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
		PresetList.Add("» " .. n, function()
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
	else
		T(WScale, 0.28, {Scale = 0.01}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		T(Pill, 0.25, {BackgroundColor3 = RGB(8, 8, 12)})
		task.delay(0.3, function()
			Holder.Visible = false
			Busy = false
		end)
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
Txt(LangTitle, "言語", "Language")
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
	HomeRef.Uptime.Text = Tr("起動時間: ", "Uptime: ") .. FmtTime(tick() - START_TIME)
	HomeRef.Server.Text = Tr("サーバー人数: ", "Server players: ") .. PlayersText()
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
	pcall(ProtCleanup)
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
	ActionRun = ActionRun,
	Protection = Prot,
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
