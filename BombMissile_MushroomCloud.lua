--[[
	BombMissile - Mushroom Cloud FX (Mobile)
	- Missile falls -> flash/shockwave -> smoke column slowly rises -> cap blooms
	- Fireball rises like a sunrise
	- After a few seconds: green radiation particles fall for 10 seconds
	- During radiation: YOUR OWN character respawns (toggle). Other players are not touched.
	- All effects are local (client-side). Touch UI only.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local function Notify(title, text, duration)
	StarterGui:SetCore("SendNotification", {
		Title = title,
		Text = text,
		Duration = duration
	})
end

if getgenv().BombMissileToy then
	pcall(function() getgenv().BombMissileToy.Destroy() end)
end

-- ================= CONFIG =================
local CFG = {
	FallTime = 1.6,        -- missile fall seconds
	StemHeight = 130,      -- smoke column height
	StemRiseTime = 10,     -- seconds for column to rise
	CapStart = 6,          -- seconds after impact: cap starts blooming
	CapEnd = 15,           -- seconds after impact: cap stops emitting
	RadiationDelay = 7,    -- seconds after impact: radiation begins
	RadiationTime = 10,    -- radiation duration
	CleanupTime = 32,      -- seconds after impact: remove all effects
}
local State = {SelfKill = true}
local Gen = 0
local Folder = nil
local CC = nil
local Conns = {}
local Gradients = {}

local function Connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(Conns, c)
	return c
end

local function T(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- ================= FX HELPERS =================
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function EnsureFolder()
	if Folder and Folder.Parent then return end
	Folder = Instance.new("Folder")
	Folder.Name = "BombMissileFX"
	Folder.Parent = workspace.CurrentCamera
end

local function FxPart(shape, size, cf, color, mat, transp)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.new(1, 1, 1)
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = transp or 0
	p.Parent = Folder
	return p
end

local function Emitter(parent, c)
	local e = Instance.new("ParticleEmitter")
	e.Texture = c.Texture or SMOKE
	e.Color = c.Color
	e.Size = c.Size
	e.Transparency = c.Transparency
	e.Lifetime = c.Lifetime
	e.Rate = c.Rate
	e.Speed = c.Speed
	e.SpreadAngle = c.Spread or Vector2.new(0, 0)
	e.Acceleration = c.Accel or Vector3.new(0, 0, 0)
	e.Drag = c.Drag or 0
	e.LightEmission = c.Light or 0
	e.LightInfluence = c.Influence or 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-25, 25)
	e.EmissionDirection = c.Dir or Enum.NormalId.Top
	e.Enabled = (c.Enabled ~= false)
	e.Parent = parent
	return e
end

local function CS(...)
	local k = {}
	for _, v in ipairs({...}) do
		table.insert(k, ColorSequenceKeypoint.new(v[1], v[2]))
	end
	return ColorSequence.new(k)
end

local function NS(...)
	local k = {}
	for _, v in ipairs({...}) do
		table.insert(k, NumberSequenceKeypoint.new(v[1], v[2]))
	end
	return NumberSequence.new(k)
end

local function GetCC()
	if CC and CC.Parent then return CC end
	CC = Instance.new("ColorCorrectionEffect")
	CC.Name = "BombMissileCC"
	CC.Parent = Lighting
	return CC
end

local function ResetCC()
	if CC then
		CC:Destroy()
		CC = nil
	end
end

local function Shake(duration, power)
	task.spawn(function()
		local t0 = tick()
		while true do
			local el = tick() - t0
			local ch = LocalPlayer.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			if not hum then break end
			if el >= duration then
				hum.CameraOffset = Vector3.new(0, 0, 0)
				break
			end
			local k = (1 - el / duration) * power
			hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
			RunService.RenderStepped:Wait()
		end
	end)
end

-- ================= STATUS =================
local StatusLabel = nil
local function SetStatus(text)
	if StatusLabel then StatusLabel.Text = text end
end

-- ================= RADIATION =================
local function Radiation(gen)
	if gen ~= Gen then return end
	EnsureFolder()
	local cam = workspace.CurrentCamera
	local rp = FxPart(Enum.PartType.Block, Vector3.new(200, 1, 200), CFrame.new(cam.CFrame.Position + Vector3.new(0, 80, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	local em = Emitter(rp, {
		Texture = SPARK,
		Color = CS({0, Color3.fromRGB(150, 255, 120)}, {0.5, Color3.fromRGB(40, 255, 70)}, {1, Color3.fromRGB(0, 140, 30)}),
		Size = NS({0, 0.9}, {1, 0.5}),
		Transparency = NS({0, 0.05}, {0.8, 0.25}, {1, 1}),
		Lifetime = NumberRange.new(2.5, 3.5),
		Rate = 500,
		Speed = NumberRange.new(35, 50),
		Dir = Enum.NormalId.Bottom,
		Light = 1,
	})
	em.Shape = Enum.ParticleEmitterShape.Box

	local rp2 = FxPart(Enum.PartType.Block, Vector3.new(40, 1, 40), CFrame.new(cam.CFrame.Position + Vector3.new(0, 25, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	local em2 = Emitter(rp2, {
		Texture = SMOKE,
		Color = CS({0, Color3.fromRGB(80, 255, 90)}, {1, Color3.fromRGB(10, 90, 20)}),
		Size = NS({0, 6}, {1, 14}),
		Transparency = NS({0, 0.85}, {0.5, 0.8}, {1, 1}),
		Lifetime = NumberRange.new(2, 3),
		Rate = 12,
		Speed = NumberRange.new(4, 8),
		Dir = Enum.NormalId.Bottom,
		Light = 0.8,
	})
	em2.Shape = Enum.ParticleEmitterShape.Box

	local follow = RunService.Heartbeat:Connect(function()
		local c = workspace.CurrentCamera
		if rp.Parent then rp.CFrame = CFrame.new(c.CFrame.Position + Vector3.new(0, 80, 0)) end
		if rp2.Parent then rp2.CFrame = CFrame.new(c.CFrame.Position + Vector3.new(0, 25, 0)) end
	end)
	table.insert(Conns, follow)

	local cc = GetCC()
	T(cc, 1.2, {TintColor = Color3.fromRGB(150, 255, 150), Saturation = 0.25, Contrast = 0.1})
	Notify("RADIATION", "Radiation started (" .. CFG.RadiationTime .. "s)", 4)

	local t0 = tick()
	while tick() - t0 < CFG.RadiationTime and gen == Gen do
		local left = math.ceil(CFG.RadiationTime - (tick() - t0))
		SetStatus("RADIATION  " .. left .. "s")
		if State.SelfKill then
			local ch = LocalPlayer.Character
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum.Health = 0
			end
		end
		task.wait(0.25)
	end

	pcall(function() follow:Disconnect() end)
	em.Enabled = false
	em2.Enabled = false
	if gen == Gen then
		T(GetCC(), 2, {TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0})
		SetStatus("Radiation ended")
		Notify("RADIATION", "Radiation ended", 3)
	end
end

-- ================= EXPLOSION =================
local function Explode(pos, gen)
	local function After(t, fn)
		task.delay(t, function()
			if gen == Gen then fn() end
		end)
	end
	EnsureFolder()
	SetStatus("Explosion")

	-- flash + warm tint
	local cc = GetCC()
	cc.Brightness = 0.9
	cc.TintColor = Color3.fromRGB(255, 225, 190)
	T(cc, 1.6, {Brightness = 0})
	T(cc, 10, {TintColor = Color3.fromRGB(255, 235, 215)}, Enum.EasingStyle.Sine)
	Shake(1.6, 1.4)

	-- shockwave ring
	local ring = FxPart(Enum.PartType.Cylinder, Vector3.new(0.6, 10, 10), CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 225, 170), Enum.Material.Neon, 0.2)
	T(ring, 1.7, {Size = Vector3.new(0.6, 440, 440), Transparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- ground dust skirt
	local base = FxPart(Enum.PartType.Block, Vector3.new(6, 1, 6), CFrame.new(pos + Vector3.new(0, 1, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	local skirt = Emitter(base, {
		Color = CS({0, Color3.fromRGB(150, 115, 80)}, {1, Color3.fromRGB(95, 85, 75)}),
		Size = NS({0, 12}, {1, 40}),
		Transparency = NS({0, 0.3}, {0.7, 0.6}, {1, 1}),
		Lifetime = NumberRange.new(6, 9),
		Rate = 110,
		Speed = NumberRange.new(30, 55),
		Spread = Vector2.new(82, 82),
		Drag = 3,
	})
	After(4, function() skirt.Enabled = false end)

	-- smoke column (rises slowly)
	local stem = FxPart(Enum.PartType.Block, Vector3.new(6, 1, 6), CFrame.new(pos + Vector3.new(0, 2, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	local stemSmoke = Emitter(stem, {
		Color = CS({0, Color3.fromRGB(125, 92, 62)}, {0.4, Color3.fromRGB(92, 86, 80)}, {1, Color3.fromRGB(52, 52, 52)}),
		Size = NS({0, 10}, {1, 26}),
		Transparency = NS({0, 0.15}, {0.7, 0.45}, {1, 1}),
		Lifetime = NumberRange.new(9, 12),
		Rate = 75,
		Speed = NumberRange.new(2, 5),
		Spread = Vector2.new(14, 14),
		Drag = 0.5,
	})
	local stemFire = Emitter(stem, {
		Texture = FIRE,
		Color = CS({0, Color3.fromRGB(255, 190, 70)}, {0.5, Color3.fromRGB(255, 90, 20)}, {1, Color3.fromRGB(70, 20, 10)}),
		Size = NS({0, 8}, {1, 20}),
		Transparency = NS({0, 0.2}, {0.7, 0.5}, {1, 1}),
		Lifetime = NumberRange.new(2, 3.5),
		Rate = 50,
		Speed = NumberRange.new(3, 8),
		Spread = Vector2.new(18, 18),
		Light = 0.9,
	})
	T(stem, CFG.StemRiseTime, {Position = pos + Vector3.new(0, CFG.StemHeight, 0)}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	After(CFG.StemRiseTime * 0.55, function() stemFire.Enabled = false end)
	After(CFG.StemRiseTime + 1, function() stemSmoke.Enabled = false end)

	-- mushroom cap (blooms at top of the column)
	local capSmoke = Emitter(stem, {
		Color = CS({0, Color3.fromRGB(215, 135, 70)}, {0.3, Color3.fromRGB(130, 102, 82)}, {1, Color3.fromRGB(58, 58, 58)}),
		Size = NS({0, 18}, {1, 46}),
		Transparency = NS({0, 0.2}, {0.7, 0.5}, {1, 1}),
		Lifetime = NumberRange.new(7, 9),
		Rate = 150,
		Speed = NumberRange.new(20, 32),
		Spread = Vector2.new(80, 80),
		Accel = Vector3.new(0, -4, 0),
		Drag = 1.3,
		Enabled = false,
	})
	local capFire = Emitter(stem, {
		Texture = FIRE,
		Color = CS({0, Color3.fromRGB(255, 200, 90)}, {0.5, Color3.fromRGB(255, 100, 25)}, {1, Color3.fromRGB(80, 25, 10)}),
		Size = NS({0, 12}, {1, 30}),
		Transparency = NS({0, 0.25}, {0.7, 0.55}, {1, 1}),
		Lifetime = NumberRange.new(2.5, 4),
		Rate = 70,
		Speed = NumberRange.new(14, 22),
		Spread = Vector2.new(80, 80),
		Accel = Vector3.new(0, -2, 0),
		Drag = 1,
		Light = 0.9,
		Enabled = false,
	})
	After(CFG.CapStart, function()
		capSmoke.Enabled = true
		capFire.Enabled = true
		SetStatus("Cloud rising")
	end)
	After(CFG.CapEnd - 3, function() capFire.Enabled = false end)
	After(CFG.CapEnd, function() capSmoke.Enabled = false end)

	-- fireball rising like a sun
	local ball = FxPart(Enum.PartType.Ball, Vector3.new(26, 26, 26), CFrame.new(pos - Vector3.new(0, 8, 0)), Color3.fromRGB(255, 110, 20), Enum.Material.Neon, 0.08)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 60
	light.Brightness = 8
	light.Parent = ball
	T(ball, 13, {
		Position = pos + Vector3.new(0, CFG.StemHeight + 5, 0),
		Size = Vector3.new(80, 80, 80),
		Color = Color3.fromRGB(255, 205, 95),
	}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	After(8, function()
		T(ball, 5, {Transparency = 1}, Enum.EasingStyle.Sine)
		T(light, 5, {Brightness = 0})
	end)

	-- radiation
	After(CFG.RadiationDelay, function()
		task.spawn(Radiation, gen)
	end)

	-- cleanup
	After(CFG.CleanupTime, function()
		if Folder then Folder:Destroy() Folder = nil end
		ResetCC()
		SetStatus("Ready")
	end)
end

-- ================= LAUNCH =================
local function GetTarget()
	local cam = workspace.CurrentCamera
	local origin = cam.CFrame.Position
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
	local p = origin + flat.Unit * 110
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
	if Folder then table.insert(ignore, Folder) end
	params.FilterDescendantsInstances = ignore
	local r = workspace:Raycast(p + Vector3.new(0, 300, 0), Vector3.new(0, -800, 0), params)
	return r and r.Position or Vector3.new(p.X, origin.Y - 3, p.Z)
end

local function Clear()
	Gen += 1
	if Folder then Folder:Destroy() Folder = nil end
	ResetCC()
	local ch = LocalPlayer.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end
	SetStatus("Ready")
end

local function Launch()
	Clear()
	Gen += 1
	local gen = Gen
	EnsureFolder()
	local target = GetTarget()
	SetStatus("Missile falling")

	local startPos = target + Vector3.new(0, 380, 0)
	local body = FxPart(Enum.PartType.Cylinder, Vector3.new(10, 2.2, 2.2), CFrame.new(startPos) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 30, 34), Enum.Material.Metal, 0)
	local nose = FxPart(Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4), CFrame.new(startPos - Vector3.new(0, 5.2, 0)), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, 0)
	Emitter(body, {
		Color = CS({0, Color3.fromRGB(210, 210, 210)}, {1, Color3.fromRGB(70, 70, 70)}),
		Size = NS({0, 2.5}, {1, 7}),
		Transparency = NS({0, 0.3}, {1, 1}),
		Lifetime = NumberRange.new(2.5, 3.5),
		Rate = 70,
		Speed = NumberRange.new(0, 1),
		Dir = Enum.NormalId.Top,
	})
	Emitter(body, {
		Texture = FIRE,
		Color = CS({0, Color3.fromRGB(255, 200, 80)}, {1, Color3.fromRGB(255, 60, 20)}),
		Size = NS({0, 4}, {1, 1}),
		Transparency = NS({0, 0.1}, {1, 1}),
		Lifetime = NumberRange.new(0.4, 0.8),
		Rate = 60,
		Speed = NumberRange.new(2, 5),
		Dir = Enum.NormalId.Top,
		Light = 1,
	})
	T(body, CFG.FallTime, {CFrame = CFrame.new(target + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90))}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	T(nose, CFG.FallTime, {Position = target + Vector3.new(0, 0, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	task.delay(CFG.FallTime, function()
		if gen ~= Gen then return end
		body:Destroy()
		nose:Destroy()
		Explode(target, gen)
	end)
end

-- ================= GUI =================
local Gui = Instance.new("ScreenGui")
Gui.Name = "BombMissileUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 999
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local okP = pcall(function() Gui.Parent = CoreGui end)
if not okP or not Gui.Parent then
	Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local PALETTE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 30)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 190, 40)),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(60, 255, 110)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 30)),
})

local function Corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
	return c
end

local function Grad(parent, rot)
	local g = Instance.new("UIGradient")
	g.Color = PALETTE
	g.Rotation = rot or math.random(0, 359)
	g.Parent = parent
	table.insert(Gradients, g)
	return g
end

local function Ripple(btn, x, y)
	local r = Instance.new("Frame")
	r.BackgroundColor3 = Color3.new(1, 1, 1)
	r.BackgroundTransparency = 0.55
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Position = UDim2.fromOffset(x - btn.AbsolutePosition.X, y - btn.AbsolutePosition.Y)
	r.Size = UDim2.fromOffset(0, 0)
	r.ZIndex = 20
	r.Parent = btn
	Corner(r, 200)
	local big = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2.2
	T(r, 0.5, {Size = UDim2.fromOffset(big, big), BackgroundTransparency = 1})
	task.delay(0.55, function() r:Destroy() end)
end

local Holder = Instance.new("Frame")
Holder.Size = UDim2.fromOffset(230, 178)
Holder.AnchorPoint = Vector2.new(0.5, 0.5)
Holder.Position = UDim2.fromScale(0.25, 0.45)
Holder.BackgroundTransparency = 1
Holder.Parent = Gui

local Window = Instance.new("Frame")
Window.Size = UDim2.fromScale(1, 1)
Window.AnchorPoint = Vector2.new(0.5, 0.5)
Window.Position = UDim2.fromScale(0.5, 0.5)
Window.BackgroundColor3 = Color3.fromRGB(14, 12, 20)
Window.BackgroundTransparency = 0.06
Window.ClipsDescendants = true
Window.Parent = Holder
Corner(Window, 14)
local WScale = Instance.new("UIScale")
WScale.Scale = 0.01
WScale.Parent = Window
local WStroke = Instance.new("UIStroke")
WStroke.Thickness = 2
WStroke.Color = Color3.new(1, 1, 1)
WStroke.Parent = Window
Grad(WStroke, 0)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundTransparency = 1
TopBar.Parent = Window

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.fromOffset(12, 0)
Title.BackgroundTransparency = 1
Title.Text = "BombMissile"
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 17
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar
Grad(Title, 0)

local function TopBtn(text, xOff)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(26, 26)
	b.Position = UDim2.new(1, xOff, 0.5, -13)
	b.BackgroundColor3 = Color3.fromRGB(38, 34, 54)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = false
	b.Parent = TopBar
	Corner(b, 13)
	return b
end
local MinBtn = TopBtn("-", -64)
local CloseBtn = TopBtn("x", -34)

local function MakeBtn(text, y, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -20, 0, 34)
	b.Position = UDim2.fromOffset(10, y)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.Text = ""
	b.AutoButtonColor = false
	b.ClipsDescendants = true
	b.Parent = Window
	Corner(b, 9)
	Grad(b)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamBold
	l.TextSize = 13
	l.TextColor3 = Color3.new(1, 1, 1)
	l.ZIndex = 3
	l.Parent = b
	Connect(b.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch then
			Ripple(b, i.Position.X, i.Position.Y)
		end
	end)
	Connect(b.Activated, cb)
	return b
end

MakeBtn("LAUNCH BombMissile", 42, function()
	Launch()
	Notify("BombMissile", "Launched", 2)
end)
MakeBtn("CLEAR", 82, function()
	Clear()
	Notify("BombMissile", "Cleared", 2)
end)

-- toggle
local TogHolder = Instance.new("TextButton")
TogHolder.Size = UDim2.new(1, -20, 0, 30)
TogHolder.Position = UDim2.fromOffset(10, 122)
TogHolder.BackgroundColor3 = Color3.fromRGB(26, 24, 38)
TogHolder.Text = ""
TogHolder.AutoButtonColor = false
TogHolder.Parent = Window
Corner(TogHolder, 9)
local TogText = Instance.new("TextLabel")
TogText.Size = UDim2.new(1, -62, 1, 0)
TogText.Position = UDim2.fromOffset(10, 0)
TogText.BackgroundTransparency = 1
TogText.Text = "Radiation: self respawn"
TogText.Font = Enum.Font.GothamMedium
TogText.TextSize = 11
TogText.TextColor3 = Color3.fromRGB(225, 225, 240)
TogText.TextXAlignment = Enum.TextXAlignment.Left
TogText.Parent = TogHolder
local Track = Instance.new("Frame")
Track.Size = UDim2.fromOffset(38, 18)
Track.Position = UDim2.new(1, -48, 0.5, -9)
Track.BackgroundColor3 = Color3.new(1, 1, 1)
Track.Parent = TogHolder
Corner(Track, 9)
local TrackGrad = Grad(Track)
local Knob = Instance.new("Frame")
Knob.Size = UDim2.fromOffset(14, 14)
Knob.Position = UDim2.fromOffset(22, 2)
Knob.BackgroundColor3 = Color3.new(1, 1, 1)
Knob.Parent = Track
Corner(Knob, 7)
local function RenderToggle()
	TrackGrad.Enabled = State.SelfKill
	T(Knob, 0.22, {Position = State.SelfKill and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2)}, Enum.EasingStyle.Back)
	T(Track, 0.22, {BackgroundColor3 = State.SelfKill and Color3.new(1, 1, 1) or Color3.fromRGB(55, 52, 75)})
end
RenderToggle()
Connect(TogHolder.Activated, function()
	State.SelfKill = not State.SelfKill
	RenderToggle()
	Notify("BombMissile", "Self respawn: " .. tostring(State.SelfKill), 2)
end)

StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 18)
StatusLabel.Position = UDim2.new(0, 10, 1, -22)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready"
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextSize = 11
StatusLabel.TextColor3 = Color3.fromRGB(170, 170, 195)
StatusLabel.Parent = Window

-- orb (minimized)
local Orb = Instance.new("TextButton")
Orb.Size = UDim2.fromOffset(0, 0)
Orb.AnchorPoint = Vector2.new(0.5, 0.5)
Orb.Position = UDim2.fromScale(0.1, 0.3)
Orb.BackgroundColor3 = Color3.new(1, 1, 1)
Orb.Text = "B"
Orb.Font = Enum.Font.GothamBlack
Orb.TextSize = 22
Orb.TextColor3 = Color3.new(1, 1, 1)
Orb.AutoButtonColor = false
Orb.Visible = false
Orb.ZIndex = 10
Orb.Parent = Gui
Corner(Orb, 30)
Grad(Orb)
local OrbStroke = Instance.new("UIStroke")
OrbStroke.Thickness = 2
OrbStroke.Color = Color3.new(1, 1, 1)
OrbStroke.Parent = Orb
Grad(OrbStroke)

-- drag
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

local Minimized, Busy = false, false
local function SetMinimized(state)
	if Busy or Minimized == state then return end
	Busy = true
	Minimized = state
	if state then
		local c = Holder.AbsolutePosition + Holder.AbsoluteSize / 2
		Orb.Position = UDim2.fromOffset(c.X, c.Y)
		T(WScale, 0.3, {Scale = 0.01}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.3, function()
			Holder.Visible = false
			Orb.Visible = true
			Orb.Size = UDim2.fromOffset(0, 0)
			T(Orb, 0.35, {Size = UDim2.fromOffset(52, 52)}, Enum.EasingStyle.Back)
			task.delay(0.35, function() Busy = false end)
		end)
	else
		local vp = workspace.CurrentCamera.ViewportSize
		local c = Orb.AbsolutePosition + Orb.AbsoluteSize / 2
		local cx = math.clamp(c.X, 115, math.max(115, vp.X - 115))
		local cy = math.clamp(c.Y, 89, math.max(89, vp.Y - 89))
		T(Orb, 0.2, {Size = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.2, function()
			Orb.Visible = false
			Holder.Position = UDim2.fromOffset(cx, cy)
			Holder.Visible = true
			WScale.Scale = 0.01
			T(WScale, 0.4, {Scale = 1}, Enum.EasingStyle.Back)
			task.delay(0.4, function() Busy = false end)
		end)
	end
end
MakeDraggable(TopBar, Holder, nil)
MakeDraggable(Orb, Orb, function() SetMinimized(false) end)
Connect(MinBtn.Activated, function() SetMinimized(true) end)

local function Destroy()
	Gen += 1
	if Folder then Folder:Destroy() Folder = nil end
	ResetCC()
	for _, c in ipairs(Conns) do
		pcall(function() c:Disconnect() end)
	end
	Conns = {}
	if Gui then Gui:Destroy() end
	getgenv().BombMissileToy = nil
end
getgenv().BombMissileToy = {Destroy = Destroy, Launch = Launch}

Connect(CloseBtn.Activated, function()
	T(WScale, 0.25, {Scale = 0.01}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.3, Destroy)
end)

Connect(RunService.Heartbeat, function(dt)
	for i = #Gradients, 1, -1 do
		local g = Gradients[i]
		if g.Parent then
			if g.Enabled then g.Rotation = (g.Rotation + dt * 45) % 360 end
		else
			table.remove(Gradients, i)
		end
	end
end)

T(WScale, 0.5, {Scale = 1}, Enum.EasingStyle.Back)
Notify("BombMissile", "Loaded", 3)
