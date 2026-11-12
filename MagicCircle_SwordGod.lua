--[[
	魔法陣 → 鎖に拘束されて足掻く → 地面に伏せられる → 解放されて脱力
	→ 雷 → 黄金の盾が防ぐ → 目の前の剣を抜く → 8本に増える → 剣の神
	剣: 金色 / 紫のオーラ / 視点方向に切っ先 / 発射ボタンで視点の中心へ飛び、
	    刺さって爆発(粉々) → 元の位置へ戻る
	モバイル用 (タッチ操作のGui付き / 小型・オブシディアン配色)
	※ すべてクライアント側の見た目の演出です (自分にだけ見えます)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local env = getgenv()

local function Notify(title, text, duration)
	StarterGui:SetCore("SendNotification", {
		Title = title,
		Text = text,
		Duration = duration
	})
end

-- 二重実行対策
if env.SwordGodCleanup then
	pcall(env.SwordGodCleanup)
end

------------------------------------------------------------------
-- 設定
------------------------------------------------------------------
local CYAN = Color3.fromRGB(70, 230, 255)
local WHITE = Color3.fromRGB(225, 255, 255)
local GOLD = Color3.fromRGB(255, 196, 48)
local GOLD_D = Color3.fromRGB(214, 150, 24)
local PURPLE = Color3.fromRGB(160, 70, 255)
local LGT_GLOW = Color3.fromRGB(170, 200, 255)
local LGT_CORE = Color3.fromRGB(255, 255, 255)

local CANVAS = 1000
local CEN = 500
local RAD = 480
local DIAMETER = 26
local RISE = 7
local LINK_POOL = 40
local LINK_SPACING = 0.5
local HIDE = CFrame.new(0, -5000, 0)
local SWORD_COUNT = 8

local LINK_OFFS = {
	CFrame.new(-0.2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
	CFrame.new(0.2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
	CFrame.new(0, 0, 0.31),
	CFrame.new(0, 0, -0.31),
}

local Alive = false      -- 演出の進行中
local Running = false    -- 演出〜剣の神モード全体
local God = false        -- 剣の神モード
local Busy = false       -- 発射中
local Ctx = nil
local Swords = {}
local Shards = {}
local FireBtn = nil
local rng = Random.new(2024)

------------------------------------------------------------------
-- 魔法陣パーツ生成用ヘルパー
------------------------------------------------------------------
local function Pt(cx, cy, r, deg)
	local a = math.rad(deg)
	return Vector2.new(cx + r * math.cos(a), cy + r * math.sin(a))
end

local function MakeLine(parent, a, b, th, list)
	local d = b - a
	local len = d.Magnitude
	local mid = (a + b) / 2
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(mid.X, mid.Y)
	f.Size = UDim2.fromOffset(len + th * 0.6, th)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
	f.BorderSizePixel = 0
	f.BackgroundColor3 = CYAN
	f.BackgroundTransparency = 1
	f.Parent = parent
	table.insert(list, f)
	return f
end

local function Arc(parent, cx, cy, r, th, list, a0, a1, segs)
	segs = segs or math.max(16, math.ceil(r * math.rad(math.abs(a1 - a0)) / 20))
	local step = (a1 - a0) / segs
	for i = 0, segs - 1 do
		MakeLine(parent, Pt(cx, cy, r, a0 + step * i), Pt(cx, cy, r, a0 + step * (i + 1)), th, list)
	end
end

local function Poly(parent, cx, cy, r, n, rot, th, list)
	for i = 0, n - 1 do
		MakeLine(parent, Pt(cx, cy, r, rot + 360 / n * i), Pt(cx, cy, r, rot + 360 / n * (i + 1)), th, list)
	end
end

local function Rune(parent, x, y, size, rot, list)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromOffset(x, y)
	box.Size = UDim2.fromOffset(size, size)
	box.Rotation = rot
	box.Parent = parent
	local th = math.max(2, size * 0.08)
	MakeLine(box, Vector2.new(size * 0.5, size * 0.05), Vector2.new(size * 0.5, size * 0.95), th, list)
	for _ = 1, rng:NextInteger(2, 4) do
		local y1 = rng:NextNumber(0.1, 0.9) * size
		local x2 = rng:NextNumber(0.05, 0.95) * size
		local y2 = math.clamp(y1 + rng:NextNumber(-0.35, 0.35) * size, size * 0.02, size * 0.98)
		MakeLine(box, Vector2.new(size * 0.5, y1), Vector2.new(x2, y2), th, list)
	end
end

local function RuneArc(parent, cx, cy, r, count, size, a0, a1, list)
	for i = 1, count do
		local deg = a0 + (a1 - a0) * (i - 0.5) / count
		local p = Pt(cx, cy, r, deg)
		Rune(parent, p.X, p.Y, size, deg + 90, list)
	end
end

local function BuildDesign(outerCG, midCG, innerCG)
	local S = {
		outerRings = {}, outerRunes = {}, ticks = {},
		midRings = {}, triangle = {}, midRunes = {},
		sun = {}, moon = {}, star = {},
		innerPoly = {}, innerCircle = {}, innerRunes = {},
	}

	Arc(outerCG, CEN, CEN, RAD * 0.985, 4, S.outerRings, 0, 360)
	Arc(outerCG, CEN, CEN, RAD * 0.955, 2, S.outerRings, 0, 360)
	RuneArc(outerCG, CEN, CEN, RAD * 0.92, 76, 26, 0, 360, S.outerRunes)
	Arc(outerCG, CEN, CEN, RAD * 0.885, 2, S.ticks, 0, 360)
	Arc(outerCG, CEN, CEN, RAD * 0.80, 3, S.ticks, 0, 360)
	for i = 0, 71 do
		local deg = i * 5
		MakeLine(outerCG, Pt(CEN, CEN, RAD * 0.80, deg), Pt(CEN, CEN, RAD * 0.885, deg), 2, S.ticks)
	end

	Arc(midCG, CEN, CEN, RAD * 0.78, 4, S.midRings, 0, 360)
	Arc(midCG, CEN, CEN, RAD * 0.745, 2, S.midRings, 0, 360)
	Poly(midCG, CEN, CEN, RAD * 0.74, 3, -75, 2, S.triangle)
	RuneArc(midCG, CEN, CEN, RAD * 0.64, 6, 34, -95, -50, S.midRunes)
	RuneArc(midCG, CEN, CEN, RAD * 0.64, 6, 34, 25, 70, S.midRunes)
	RuneArc(midCG, CEN, CEN, RAD * 0.64, 6, 34, 142, 188, S.midRunes)

	local rs = RAD * 0.17
	local function SatRing(p, list)
		Arc(midCG, p.X, p.Y, rs, 3, list, 0, 360)
		Arc(midCG, p.X, p.Y, rs * 0.92, 2, list, 0, 360)
	end

	local sp = Pt(CEN, CEN, RAD * 0.56, -135)
	SatRing(sp, S.sun)
	Arc(midCG, sp.X, sp.Y, rs * 0.42, 3, S.sun, 0, 360)
	for i = 0, 11 do
		local deg = i * 30
		local b1 = Pt(sp.X, sp.Y, rs * 0.50, deg - 9)
		local tip = Pt(sp.X, sp.Y, rs * 0.80, deg)
		local b2 = Pt(sp.X, sp.Y, rs * 0.50, deg + 9)
		MakeLine(midCG, b1, tip, 2, S.sun)
		MakeLine(midCG, tip, b2, 2, S.sun)
	end

	local mp = Pt(CEN, CEN, RAD * 0.56, -10)
	SatRing(mp, S.moon)
	local ro = rs * 0.62
	local d = ro * 0.45
	local ri = ro * 0.78
	local cx = (d * d + ro * ro - ri * ri) / (2 * d)
	local cy = math.sqrt(math.max(ro * ro - cx * cx, 0))
	local t1 = math.deg(math.atan2(cy, cx))
	local t2 = math.deg(math.atan2(cy, cx - d))
	Arc(midCG, mp.X, mp.Y, ro, 3, S.moon, t1, 360 - t1)
	Arc(midCG, mp.X + d, mp.Y, ri, 3, S.moon, t2, 360 - t2)

	local stp = Pt(CEN, CEN, RAD * 0.56, 105)
	SatRing(stp, S.star)
	for i = 0, 15 do
		local r1 = (i % 2 == 0) and rs * 0.80 or rs * 0.34
		local r2 = ((i + 1) % 2 == 0) and rs * 0.80 or rs * 0.34
		MakeLine(midCG, Pt(stp.X, stp.Y, r1, -90 + i * 22.5), Pt(stp.X, stp.Y, r2, -90 + (i + 1) * 22.5), 2, S.star)
	end
	for i = 0, 7 do
		MakeLine(midCG, Vector2.new(stp.X, stp.Y), Pt(stp.X, stp.Y, rs * 0.80, -90 + i * 45), 1.5, S.star)
	end

	Poly(innerCG, CEN, CEN, RAD * 0.36, 6, -15, 3, S.innerPoly)
	Poly(innerCG, CEN, CEN, RAD * 0.33, 6, -15, 2, S.innerPoly)
	Arc(innerCG, CEN, CEN, RAD * 0.245, 2, S.innerCircle, 0, 360)
	Arc(innerCG, CEN, CEN, RAD * 0.225, 2, S.innerCircle, 0, 360)
	for i = 0, 2 do
		MakeLine(innerCG, Pt(CEN, CEN, RAD * 0.225, i * 60), Pt(CEN, CEN, RAD * 0.225, i * 60 + 180), 2, S.innerCircle)
	end
	RuneArc(innerCG, CEN, CEN, RAD * 0.285, 28, 13, 0, 360, S.innerRunes)
	for i = 0, 5 do
		local deg = 30 + i * 60
		local p = Pt(CEN, CEN, RAD * 0.13, deg)
		Rune(innerCG, p.X, p.Y, 26, deg + 90, S.innerRunes)
	end

	return S
end

------------------------------------------------------------------
-- 雷 / 画面フラッシュ
------------------------------------------------------------------
local function BoltSegment(parent, a, b, w, color, transp)
	local d = b - a
	local len = d.Magnitude
	if len < 0.01 then return nil end
	local p = Instance.new("Part")
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transp
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(w, w, len)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = parent
	return p
end

local function BuildBolt(parent, from, to, w, segs, depth, out)
	local pts = {from}
	local dir = to - from
	for i = 1, segs - 1 do
		local f = i / segs
		local amp = 5 * (1 - f * 0.6) * (depth == 0 and 1 or 0.5)
		local off = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * amp
		pts[#pts + 1] = from + dir * f + off
	end
	pts[#pts + 1] = to
	for i = 1, #pts - 1 do
		local s1 = BoltSegment(parent, pts[i], pts[i + 1], w * 3, LGT_GLOW, 0.55)
		local s2 = BoltSegment(parent, pts[i], pts[i + 1], w, LGT_CORE, 0)
		if s1 then table.insert(out, s1) end
		if s2 then table.insert(out, s2) end
		if depth == 0 and i > 2 and rng:NextNumber() < 0.22 then
			local fd = Vector3.new(rng:NextNumber(-1, 1), -1.2, rng:NextNumber(-1, 1)).Unit * rng:NextNumber(10, 22)
			BuildBolt(parent, pts[i], pts[i] + fd, w * 0.5, 4, 1, out)
		end
	end
end

local function ScreenFlash(big)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = big and 0.4 or 0.15
	cc.TintColor = Color3.fromRGB(255, 250, 225)
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(big and 0.8 or 0.35), {
		Brightness = 0,
		TintColor = Color3.new(1, 1, 1)
	}):Play()
	Debris:AddItem(cc, 1.2)
end

local function Ease(t)
	return t * t * (3 - 2 * t)
end

local function Animate(duration, fn)
	local start = os.clock()
	while Alive do
		local a = math.clamp((os.clock() - start) / duration, 0, 1)
		fn(a)
		if a >= 1 then break end
		RunService.Heartbeat:Wait()
	end
end

local function Reveal(list, duration)
	local n = #list
	if n == 0 then return end
	local start = os.clock()
	local shown = 0
	while Alive and shown < n do
		local alpha = math.clamp((os.clock() - start) / duration, 0, 1)
		local target = math.floor(alpha * n + 0.5)
		if alpha >= 1 then target = n end
		while shown < target do
			shown += 1
			local f = list[shown]
			f.BackgroundColor3 = WHITE
			f.BackgroundTransparency = 0
			TweenService:Create(f, TweenInfo.new(0.5), {
				BackgroundColor3 = CYAN,
				BackgroundTransparency = 0.12
			}):Play()
		end
		RunService.Heartbeat:Wait()
	end
end

local function GetControls()
	local ok, controls = pcall(function()
		local ps = LocalPlayer:FindFirstChild("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		if not pm then return nil end
		return require(pm):GetControls()
	end)
	if ok then return controls end
	return nil
end

------------------------------------------------------------------
-- カメラ揺れ / 破片 / 爆発
------------------------------------------------------------------
local function ShakeCam(amount, dur)
	if not Ctx then return end
	local hum = Ctx.hum
	task.spawn(function()
		local t0 = os.clock()
		while Ctx and os.clock() - t0 < dur do
			local k = 1 - (os.clock() - t0) / dur
			pcall(function()
				hum.CameraOffset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) * amount * k
			end)
			RunService.RenderStepped:Wait()
		end
		pcall(function() hum.CameraOffset = Vector3.zero end)
	end)
end

local function SpawnShards(pos, count, speed)
	if not Ctx or not Ctx.Folder then return end
	for _ = 1, count do
		if #Shards > 280 then break end
		local purple = rng:NextNumber() < 0.25
		local s = rng:NextNumber(0.15, 0.45)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(s, s * 0.4, s * rng:NextNumber(1, 2.2))
		p.Material = purple and Enum.Material.Neon or Enum.Material.Metal
		p.Color = purple and PURPLE or GOLD
		p.Reflectance = purple and 0 or 0.3
		p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		p.Parent = Ctx.Folder
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1))
		if dir.Magnitude < 0.1 then dir = Vector3.yAxis end
		table.insert(Shards, {
			part = p,
			vel = dir.Unit * rng:NextNumber(speed * 0.4, speed),
			age = 0,
			life = rng:NextNumber(0.8, 1.5),
			spin = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10)),
		})
	end
end

local function UpdateShards(dt)
	for i = #Shards, 1, -1 do
		local d = Shards[i]
		d.age += dt
		if d.age >= d.life or not d.part.Parent then
			if d.part.Parent then d.part:Destroy() end
			table.remove(Shards, i)
		else
			d.vel += Vector3.new(0, -70, 0) * dt
			local cf = d.part.CFrame
			local pos = cf.Position + d.vel * dt
			d.part.CFrame = CFrame.new(pos) * (cf - cf.Position) * CFrame.Angles(d.spin.X * dt, d.spin.Y * dt, d.spin.Z * dt)
			d.part.Transparency = math.clamp((d.age / d.life - 0.55) / 0.45, 0, 1)
		end
	end
end

local function Explode(pos, scale)
	if not Ctx or not Ctx.Folder then return end
	local folder = Ctx.Folder
	local function Ball(color, s0, s1, dur, tr0)
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		b.Material = Enum.Material.Neon
		b.Color = color
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Size = Vector3.new(s0, s0, s0)
		b.Transparency = tr0
		b.CFrame = CFrame.new(pos)
		b.Parent = folder
		TweenService:Create(b, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(s1, s1, s1),
			Transparency = 1
		}):Play()
		Debris:AddItem(b, dur + 0.1)
	end
	Ball(Color3.fromRGB(255, 238, 180), 1, 12 * scale, 0.35, 0)
	Ball(PURPLE, 1, 18 * scale, 0.5, 0.3)

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = PURPLE
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Size = Vector3.new(0.3, 1, 1)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = folder
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, 26 * scale, 26 * scale),
		Transparency = 1
	}):Play()
	Debris:AddItem(ring, 0.6)

	local lp = Instance.new("Part")
	lp.Anchored = true
	lp.CanCollide = false
	lp.CanQuery = false
	lp.CanTouch = false
	lp.Transparency = 1
	lp.Size = Vector3.new(1, 1, 1)
	lp.CFrame = CFrame.new(pos)
	lp.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 120)
	light.Range = 30 * scale
	light.Brightness = 12
	light.Parent = lp
	TweenService:Create(light, TweenInfo.new(0.5), {Brightness = 0}):Play()

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(1, PURPLE),
	})
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Lifetime = NumberRange.new(0.5, 1.1)
	pe.Speed = NumberRange.new(25, 60)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 0
	pe.Parent = lp
	pe:Emit(math.floor(60 * scale))
	Debris:AddItem(lp, 2)
end

------------------------------------------------------------------
-- 黄金の剣 (金 / 紫のオーラ)
------------------------------------------------------------------
local function SetSwordShown(s, shown)
	for _, p in ipairs(s.parts) do
		p.Transparency = shown and s.orig[p] or 1
	end
	s.pe.Enabled = shown
	s.pl.Enabled = shown
	if not shown then
		s.trail.Enabled = false
	end
end

local function FadeSwordIn(s, dur)
	for _, p in ipairs(s.parts) do
		TweenService:Create(p, TweenInfo.new(dur), {Transparency = s.orig[p]}):Play()
	end
	s.pe.Enabled = true
	s.pl.Enabled = true
end

local function BuildSword(parent)
	local m = Instance.new("Model")
	m.Name = "GodSword"
	local parts = {}

	local function P(size, cf, color, mat, tr, refl, shape)
		local p = Instance.new("Part")
		if shape then p.Shape = shape end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat
		p.Transparency = tr or 0
		p.Reflectance = refl or 0
		p.Parent = m
		table.insert(parts, p)
		return p
	end

	local METAL = Enum.Material.Metal
	local NEON = Enum.Material.Neon
	local CYL = Enum.PartType.Cylinder
	local BALL = Enum.PartType.Ball

	-- 刀身 (先端は幅を段階的に細く)
	local blade = P(Vector3.new(0.7, 0.12, 3.2), CFrame.new(0, 0, -1.8), GOLD, METAL, 0, 0.35)
	local lastTip
	for i = 0, 6 do
		local w = 0.7 * (1 - (i + 1) / 8)
		lastTip = P(Vector3.new(w, 0.12, 0.21), CFrame.new(0, 0, -3.5 - i * 0.2), GOLD, METAL, 0, 0.35)
	end
	P(Vector3.new(0.16, 0.15, 3.0), CFrame.new(0, 0.06, -1.8), GOLD_D, METAL, 0, 0.2) -- 樋(ひ)

	-- 鍔
	local guard = P(Vector3.new(0.5, 0.34, 0.4), CFrame.new(0, 0, 0), GOLD, METAL, 0, 0.35)
	for _, s in ipairs({-1, 1}) do
		P(Vector3.new(1.3, 0.2, 0.28), CFrame.new(s * 0.95, 0, 0.02) * CFrame.Angles(0, s * 0.2, 0), GOLD, METAL, 0, 0.35)
		P(Vector3.new(0.25, 0.2, 0.5), CFrame.new(s * 1.55, 0, -0.18) * CFrame.Angles(0, s * 0.5, 0), GOLD, METAL, 0, 0.35)
	end
	P(Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0.2, 0), PURPLE, NEON, 0, 0, BALL)

	-- 柄 / 巻き / 柄頭
	P(Vector3.new(1.5, 0.26, 0.26), CFrame.new(0, 0, 0.95) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(60, 28, 90), Enum.Material.SmoothPlastic, 0, 0, CYL)
	for k = 0, 3 do
		P(Vector3.new(0.08, 0.32, 0.32), CFrame.new(0, 0, 0.45 + k * 0.33) * CFrame.Angles(0, math.pi / 2, 0), GOLD, METAL, 0, 0.3, CYL)
	end
	local pommel = P(Vector3.new(0.55, 0.55, 0.55), CFrame.new(0, 0, 1.85), GOLD, METAL, 0, 0.35, BALL)
	P(Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0, 2.08), PURPLE, NEON, 0, 0, BALL)

	-- 紫のオーラ
	P(Vector3.new(1.05, 0.4, 5.1), CFrame.new(0, 0, -2.35), PURPLE, NEON, 0.82, 0)

	m.PrimaryPart = guard

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 130, 255)),
		ColorSequenceKeypoint.new(1, PURPLE),
	})
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Lifetime = NumberRange.new(0.6, 1.1)
	pe.Rate = 28
	pe.Speed = NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, 2, 0)
	pe.Enabled = false
	pe.Parent = blade

	local pl = Instance.new("PointLight")
	pl.Color = PURPLE
	pl.Range = 10
	pl.Brightness = 1.6
	pl.Enabled = false
	pl.Parent = blade

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -0.1)
	a0.Parent = lastTip
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, 1.5)
	a1.Parent = blade
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(1, PURPLE),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.LightEmission = 1
	trail.Enabled = false
	trail.Parent = blade

	local orig = {}
	for _, p in ipairs(parts) do
		orig[p] = p.Transparency
	end

	m.Parent = parent
	local s = {
		model = m, parts = parts, orig = orig, pe = pe, pl = pl, trail = trail,
		state = "hidden", pos = Vector3.new(0, -5000, 0), dir = Vector3.new(0, 0, -1),
		t = 0, slot = 1, cf = CFrame.new(),
	}
	SetSwordShown(s, false)
	return s
end

local function SlotPos(i)
	local look = Ctx.look
	local right = look:Cross(Vector3.yAxis)
	if right.Magnitude < 0.05 then
		right = Workspace.CurrentCamera.CFrame.RightVector
	end
	right = right.Unit
	local up = right:Cross(look).Unit
	local center = Ctx.hrp.Position - look * 3.4 + Vector3.new(0, 1.6, 0)
	local a = Ctx.ringA + (i - 1) / SWORD_COUNT * math.pi * 2
	return center + (right * math.cos(a) + up * math.sin(a)) * 4.8
end

local function UpdateSwords(dt)
	if #Swords == 0 or not Ctx then return end
	local camLook = Workspace.CurrentCamera.CFrame.LookVector
	local nl = Ctx.look:Lerp(camLook, math.min(dt * 12, 1))
	if nl.Magnitude < 0.01 then nl = camLook end
	Ctx.look = nl.Unit
	Ctx.ringA += dt * Ctx.ringSpeed
	local now = os.clock()

	for _, s in ipairs(Swords) do
		local st = s.state
		s.t += dt

		if st == "orbit" then
			s.pos = SlotPos(s.slot) + Vector3.new(0, math.sin(now * 2 + s.slot) * 0.15, 0)
			local nd = s.dir:Lerp(Ctx.look, math.min(dt * 10, 1))
			if nd.Magnitude < 0.01 then nd = Ctx.look end
			s.dir = nd.Unit

		elseif st == "fly" then
			local p = math.clamp(s.t / s.dur, 0, 1)
			s.pos = s.start:Lerp(s.endO, p * p)
			if p >= 1 then
				s.state = "embed"
				s.t = 0
				s.pos = s.endO
				Explode(s.target, 0.3)
				SpawnShards(s.target, 6, 25)
			end

		elseif st == "embed" then
			s.pos = s.endO + Vector3.new(rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.06, 0.06))
			if s.t > 0.4 then
				s.state = "gone"
				s.t = 0
				Explode(s.target, s.big and 1.3 or 0.7)
				for k = 0, 3 do
					SpawnShards(s.target - s.dir * (k * 1.2), 8, 55)
				end
				if s.big then ShakeCam(0.6, 0.4) end
				SetSwordShown(s, false)
			end

		elseif st == "gone" then
			if s.t > 0.95 then
				s.state = "return"
				s.t = 0
				s.start = s.target
				s.dur = 0.8
				s.arc = rng:NextNumber(1, 4)
				s.pos = s.target
				FadeSwordIn(s, 0.2)
				s.trail.Enabled = true
				Explode(s.target, 0.35)
			end

		elseif st == "return" or st == "toSlot" then
			local p = math.clamp(s.t / s.dur, 0, 1)
			local e = Ease(p)
			local slot = SlotPos(s.slot)
			s.pos = s.start:Lerp(slot, e) + Vector3.new(0, math.sin(p * math.pi) * (s.arc or 2), 0)
			if st == "return" then
				local d = slot - s.pos
				if d.Magnitude > 0.1 then s.dir = d.Unit end
			else
				local nd = s.dir:Lerp(Ctx.look, math.min(dt * 6, 1))
				if nd.Magnitude < 0.01 then nd = Ctx.look end
				s.dir = nd.Unit
			end
			if p >= 1 then
				s.state = "orbit"
				s.trail.Enabled = false
			end
		end

		if st ~= "hidden" then
			local d = s.dir
			local upv = (math.abs(d.Y) > 0.98) and (s.upHint or Vector3.zAxis) or Vector3.yAxis
			s.cf = CFrame.lookAt(s.pos, s.pos + d, upv)
			s.model:PivotTo(s.cf)
		end
	end
end

local function LaunchSword(s, target)
	local dist = (target - s.pos).Magnitude
	local jitter = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 1.4
	local tgt = target + jitter
	local dir = (tgt - s.pos)
	if dir.Magnitude < 0.5 then dir = Ctx.look end
	dir = dir.Unit
	s.dir = dir
	s.target = tgt
	s.start = s.pos
	s.endO = tgt - dir * 3.3
	s.dur = math.clamp(dist / 260, 0.2, 1.1)
	s.state = "fly"
	s.t = 0
	s.trail.Enabled = true
end

local function Fire()
	if not God or Busy or not Ctx then return end
	for _, s in ipairs(Swords) do
		if s.state ~= "orbit" then return end
	end
	Busy = true

	local cam = Workspace.CurrentCamera
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {Ctx.char, Ctx.Folder}
	local res = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = res and res.Position or (ray.Origin + ray.Direction * 220)

	for i, s in ipairs(Swords) do
		task.delay((i - 1) * 0.07, function()
			if God and Ctx then
				LaunchSword(s, target)
				s.big = (i == 1)
			end
		end)
	end

	task.spawn(function()
		task.wait(0.3)
		while God and Ctx do
			local all = true
			for _, s in ipairs(Swords) do
				if s.state ~= "orbit" then all = false break end
			end
			if all then break end
			task.wait(0.1)
		end
		Busy = false
	end)
end

------------------------------------------------------------------
-- 後片付け
------------------------------------------------------------------
local function Teardown()
	local c = Ctx
	Alive = false
	Running = false
	God = false
	Busy = false
	Ctx = nil
	if FireBtn then FireBtn.Visible = false end
	for _, s in ipairs(Swords) do
		pcall(function() s.model:Destroy() end)
	end
	Swords = {}
	for _, d in ipairs(Shards) do
		pcall(function() d.part:Destroy() end)
	end
	Shards = {}
	if not c then return end
	pcall(function() c.conn:Disconnect() end)
	pcall(function() c.diedConn:Disconnect() end)
	for _, e in ipairs(c.motors or {}) do
		pcall(function() e.m.C0 = e.c0 end)
	end
	pcall(function() c.hum.PlatformStand = false end)
	pcall(function() c.hum.CameraOffset = Vector3.zero end)
	pcall(function() c.hrp.Anchored = false end)
	local controls = GetControls()
	if controls then pcall(function() controls:Enable() end) end
	if c.Folder then pcall(function() c.Folder:Destroy() end) end
end

------------------------------------------------------------------
-- メイン演出
------------------------------------------------------------------
local function RunBody()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hum and hrp) or hum.Health <= 0 then
		Notify("エラー", "キャラクターが見つかりません", 4)
		return
	end

	Running = true
	Alive = true
	God = false
	Busy = false

	local State = {
		height = 0, pitch = 0, tension = 0.25, pose = 0, shake = 0, bob = 0,
		flail = 0, grab = 0, glow = 0, glowTarget = 0, spin = 0.4,
		free = false, posing = true,
	}
	local T, Spin = 0, 0
	local circleOn, chainsOn = true, false

	local Folder = Instance.new("Folder")
	Folder.Name = "SwordGodFx"
	Folder.Parent = Workspace

	Ctx = {
		char = char, hum = hum, hrp = hrp, Folder = Folder,
		look = Workspace.CurrentCamera.CFrame.LookVector,
		ringA = 0, ringSpeed = 0.8,
	}

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char, Folder}
	local res = Workspace:Raycast(hrp.Position, Vector3.new(0, -60, 0), params)
	local groundY = res and (res.Position.Y + 0.05) or (hrp.Position.Y - 3)
	local center = Vector3.new(hrp.Position.X, groundY, hrp.Position.Z)
	local standOff = hrp.Position.Y - groundY      -- 立っている時のHRP高さ
	local proneOff = 1.15 - standOff               -- 伏せた時の高さ変化

	local look = hrp.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local basePos = hrp.Position
	local baseCF = CFrame.new(basePos) * CFrame.Angles(0, yaw, 0)
	local yawCF = CFrame.new(center) * CFrame.Angles(0, yaw, 0)

	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.Anchored = true
	hum.PlatformStand = true

	------------------------------------------------------------
	-- 魔法陣
	------------------------------------------------------------
	local function MakeLayer(yOff, name)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.new(DIAMETER, 0.05, DIAMETER)
		part.CFrame = CFrame.new(center + Vector3.new(0, yOff, 0))
		part.Parent = Folder
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Top
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(CANVAS, CANVAS)
		sg.LightInfluence = 0
		sg.Brightness = 3
		sg.AlwaysOnTop = false
		sg.Adornee = part
		sg.Parent = part
		local cg = Instance.new("CanvasGroup")
		cg.BackgroundTransparency = 1
		cg.Size = UDim2.fromScale(1, 1)
		cg.GroupTransparency = 0
		cg.Parent = sg
		return part, cg
	end

	local outerPart, outerCG = MakeLayer(0.02, "Outer")
	local midPart, midCG = MakeLayer(0.04, "Mid")
	local innerPart, innerCG = MakeLayer(0.06, "Inner")
	local S = BuildDesign(outerCG, midCG, innerCG)

	local glowPart = Instance.new("Part")
	glowPart.Anchored = true
	glowPart.CanCollide = false
	glowPart.CanQuery = false
	glowPart.CanTouch = false
	glowPart.Transparency = 1
	glowPart.Size = Vector3.new(1, 1, 1)
	glowPart.CFrame = CFrame.new(center + Vector3.new(0, 2.5, 0))
	glowPart.Parent = Folder
	local light = Instance.new("PointLight")
	light.Color = CYAN
	light.Range = 22
	light.Brightness = 0
	light.Parent = glowPart

	------------------------------------------------------------
	-- 鎖 (リアル版)
	------------------------------------------------------------
	local chainModel = Instance.new("Model")
	chainModel.Name = "Chains"
	chainModel.Parent = Folder
	local hl = Instance.new("Highlight")
	hl.Adornee = chainModel
	hl.FillTransparency = 1
	hl.OutlineColor = CYAN
	hl.OutlineTransparency = 0.6
	hl.Parent = chainModel

	local function NewLink(i)
		local set = {}
		local shade = (i % 2 == 0) and 62 or 52
		for k = 1, 4 do
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Cylinder
			p.Size = (k <= 2) and Vector3.new(0.62, 0.13, 0.13) or Vector3.new(0.46, 0.13, 0.13)
			p.Material = Enum.Material.Metal
			p.Color = Color3.fromRGB(shade, shade + 5, shade + 12)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.CFrame = HIDE
			p.Parent = chainModel
			set[k] = p
		end
		return set
	end

	local function NewMetalCylinder(size, color, material)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Material = material
		p.Color = color
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.CFrame = HIDE
		p.Parent = Folder
		return p
	end

	local specs = {
		{limbs = {"RightHand", "Right Arm"}, off = Vector3.new(7, 0, 0.5)},
		{limbs = {"LeftHand", "Left Arm"}, off = Vector3.new(-7, 0, 0.5)},
		{limbs = {"RightFoot", "Right Leg"}, off = Vector3.new(5, 0, 4)},
		{limbs = {"LeftFoot", "Left Leg"}, off = Vector3.new(-5, 0, 4)},
	}

	local chains = {}
	for _, spec in ipairs(specs) do
		local limb = char:FindFirstChild(spec.limbs[1]) or char:FindFirstChild(spec.limbs[2])
		if limb then
			local dia = math.max(limb.Size.X, limb.Size.Z) + 0.3
			local cuff = NewMetalCylinder(Vector3.new(0.35, dia, dia), Color3.fromRGB(45, 50, 58), Enum.Material.Metal)
			local band = NewMetalCylinder(Vector3.new(0.08, dia + 0.06, dia + 0.06), CYAN, Enum.Material.Neon)
			local groundPos = (yawCF * CFrame.new(spec.off)).Position
			local base = NewMetalCylinder(Vector3.new(0.25, 2.4, 2.4), Color3.fromRGB(35, 38, 44), Enum.Material.Slate)
			base.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			local links = {}
			for i = 1, LINK_POOL do
				links[i] = NewLink(i)
			end
			table.insert(chains, {
				limb = limb, cuff = cuff, band = band, base = base, links = links,
				ground = groundPos, p = 0, lastCount = 0, seed = rng:NextNumber(0, 100),
			})
		end
	end

	local function GetAttach(limb)
		if limb.Name:find(" ") then
			return limb.CFrame * CFrame.new(0, -limb.Size.Y / 2 + 0.3, 0)
		end
		return limb.CFrame
	end

	local function HideLinks(c, count)
		for i = 1, count do
			local set = c.links[i]
			for k = 1, 4 do
				set[k].CFrame = HIDE
			end
		end
	end

	local function UpdateChain(c)
		local limb = c.limb
		if not limb or not limb.Parent then return end
		local acf = GetAttach(limb)
		local A = acf.Position
		local G = c.ground
		local p = c.p

		local cuffCF = acf * CFrame.Angles(0, 0, math.pi / 2)
		c.cuff.CFrame = cuffCF
		c.band.CFrame = cuffCF * CFrame.new(0.2, 0, 0)
		local vis = (p >= 0.98)
		c.cuff.Transparency = vis and 0 or 1
		c.band.Transparency = vis and 0 or 1
		c.base.Transparency = (p > 0.01) and 0 or 1

		if p <= 0.001 then
			if c.lastCount > 0 then
				HideLinks(c, c.lastCount)
				c.lastCount = 0
			end
			return
		end

		local G0 = G - Vector3.new(0, 1.5, 0)
		local dist = (A - G0).Magnitude
		local ctrl = (G + Vector3.new(0, 2 + dist * 0.5, 0)):Lerp((G + A) / 2, State.tension)
		local length = dist * (1.25 - 0.25 * State.tension) * p
		local m = math.clamp(math.floor(length / LINK_SPACING) + 1, 1, LINK_POOL)
		local vib = (State.tension > 0.7) and (State.tension - 0.7) * 0.25 or 0

		for i = 1, math.max(m, c.lastCount) do
			local set = c.links[i]
			if i <= m then
				local t = p * (i - 0.5) / m
				local u = 1 - t
				local pos = u * u * G0 + 2 * u * t * ctrl + t * t * A
				local tan = 2 * u * (ctrl - G0) + 2 * t * (A - ctrl)
				if tan.Magnitude < 1e-3 then
					tan = Vector3.new(0, 1, 0)
				end
				tan = tan.Unit
				local upv = (math.abs(tan.Y) > 0.95) and Vector3.xAxis or Vector3.yAxis
				local roll = (i % 2) * math.pi / 2 + math.sin(T * 45 + i * 1.3 + c.seed) * vib
				local lcf = CFrame.lookAt(pos, pos + tan, upv) * CFrame.Angles(0, 0, roll)
				for k = 1, 4 do
					set[k].CFrame = lcf * LINK_OFFS[k]
				end
			else
				for k = 1, 4 do
					set[k].CFrame = HIDE
				end
			end
		end
		c.lastCount = m
	end

	local function Flash(pos, color, maxSize)
		if not Ctx then return end
		color = color or CYAN
		maxSize = maxSize or 6
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Size = Vector3.new(0.15, 1, 1)
		ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = Folder
		TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.15, maxSize, maxSize),
			Transparency = 1
		}):Play()
		Debris:AddItem(ring, 1)
	end

	local function ImpactLight(pos)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
		p.Parent = Folder
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(220, 235, 255)
		l.Range = 45
		l.Brightness = 25
		l.Parent = p
		TweenService:Create(l, TweenInfo.new(0.6), {Brightness = 0}):Play()
		Debris:AddItem(p, 0.8)
	end

	------------------------------------------------------------
	-- 手足のポーズ (足掻き / 脱力 / 剣を掴む)
	------------------------------------------------------------
	local motorDefs = {
		{"RightShoulder", "Right Shoulder", 1, 95, true, 0},
		{"LeftShoulder", "Left Shoulder", -1, 95, true, 2.1},
		{"RightHip", "Right Hip", 1, 30, false, 4.2},
		{"LeftHip", "Left Hip", -1, 30, false, 1.0},
	}
	local motors = {}
	for _, def in ipairs(motorDefs) do
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Motor6D") and (d.Name == def[1] or d.Name == def[2]) then
				table.insert(motors, {m = d, c0 = d.C0, sign = def[3], ang = def[4], arm = def[5], phase = def[6]})
				break
			end
		end
	end
	Ctx.motors = motors

	local function ApplyPose()
		for _, e in ipairs(motors) do
			local pos = e.c0.Position
			local rot = e.c0 - pos
			local spread = e.sign * e.ang * State.pose
			local swing = e.arm and (State.grab * 1.9) or 0
			local fl = State.flail
			if fl > 0 then
				spread += fl * 0.55 * math.sin(T * 9 + e.phase)
				swing += fl * 0.7 * math.sin(T * 11.3 + e.phase * 1.7)
			end
			e.m.C0 = CFrame.new(pos) * CFrame.Angles(swing, 0, math.rad(0) + spread) * rot
		end
	end

	local function RestoreMotors()
		for _, e in ipairs(motors) do
			pcall(function() e.m.C0 = e.c0 end)
		end
	end

	------------------------------------------------------------
	-- 黄金の盾
	------------------------------------------------------------
	local shield = nil
	local function RaiseShield()
		local c = hrp.Position + Vector3.new(0, 1.2, 0)
		local function Ball(size, color, mat, tr)
			local b = Instance.new("Part")
			b.Shape = Enum.PartType.Ball
			b.Material = mat
			b.Color = color
			b.Transparency = tr
			b.Anchored = true
			b.CanCollide = false
			b.CanQuery = false
			b.CanTouch = false
			b.CastShadow = false
			b.Size = Vector3.new(size, size, size)
			b.CFrame = CFrame.new(c)
			b.Parent = Folder
			return b
		end
		local dome = Ball(0.5, Color3.fromRGB(255, 205, 70), Enum.Material.ForceField, 0.3)
		local glow = Ball(0.5, GOLD, Enum.Material.Neon, 0.88)
		local rings = {}
		for i = 1, 3 do
			local r = Instance.new("Part")
			r.Shape = Enum.PartType.Cylinder
			r.Material = Enum.Material.Neon
			r.Color = GOLD
			r.Transparency = 0.25
			r.Anchored = true
			r.CanCollide = false
			r.CanQuery = false
			r.CanTouch = false
			r.CastShadow = false
			r.Size = Vector3.new(0.18, 0.5, 0.5)
			r.CFrame = CFrame.new(c)
			r.Parent = Folder
			rings[i] = r
		end
		shield = {dome = dome, glow = glow, rings = rings, t = 0}
		local ti = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(dome, ti, {Size = Vector3.new(14, 14, 14)}):Play()
		TweenService:Create(glow, ti, {Size = Vector3.new(13.4, 13.4, 13.4)}):Play()
		for i, r in ipairs(rings) do
			local d = 14.4 + i * 0.5
			TweenService:Create(r, ti, {Size = Vector3.new(0.18, d, d)}):Play()
		end

		-- 波紋
		for k = 1, 2 do
			task.delay((k - 1) * 0.12, function()
				if not Ctx then return end
				local rp = Ball(12, Color3.fromRGB(255, 235, 170), Enum.Material.Neon, 0.35)
				TweenService:Create(rp, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(19, 19, 19), Transparency = 1
				}):Play()
				Debris:AddItem(rp, 0.6)
			end)
		end
		Explode(c + Vector3.new(0, 7, 0), 0.6)
	end

	local function UpdateShield(dt)
		if not shield then return end
		shield.t += dt
		local t = shield.t
		local c = hrp.Position + Vector3.new(0, 1.2, 0)
		shield.dome.CFrame = CFrame.new(c)
		shield.glow.CFrame = CFrame.new(c)
		if not shield.fading then
			shield.dome.Transparency = 0.32 + 0.1 * math.sin(t * 6)
		end
		shield.rings[1].CFrame = CFrame.new(c) * CFrame.Angles(0, 0, math.pi / 2)
		shield.rings[2].CFrame = CFrame.new(c) * CFrame.Angles(t * 0.9, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
		shield.rings[3].CFrame = CFrame.new(c) * CFrame.Angles(0, t * 0.7, 0)
	end

	local function FadeShield()
		if not shield then return end
		local sh = shield
		sh.fading = true
		local ti = TweenInfo.new(0.8)
		TweenService:Create(sh.dome, ti, {Transparency = 1}):Play()
		TweenService:Create(sh.glow, ti, {Transparency = 1}):Play()
		for _, r in ipairs(sh.rings) do
			TweenService:Create(r, ti, {Transparency = 1}):Play()
		end
		task.delay(0.9, function()
			if shield == sh then shield = nil end
			sh.dome:Destroy()
			sh.glow:Destroy()
			for _, r in ipairs(sh.rings) do r:Destroy() end
		end)
	end

	-- 雷
	local function Strike(target, onHit)
		local top = target + Vector3.new(rng:NextNumber(-6, 6), 150, rng:NextNumber(-6, 6))
		for k = 1, 5 do
			if not Alive then return end
			local parts = {}
			BuildBolt(Folder, top, target, 1.0, 16, 0, parts)
			if k == 1 then
				Flash(Vector3.new(target.X, groundY, target.Z), LGT_GLOW, 20)
				ImpactLight(target)
				ScreenFlash(true)
				ShakeCam(0.8, 0.5)
				if onHit then onHit() end
			end
			task.wait(0.07)
			if k < 5 then
				for _, bp in ipairs(parts) do bp:Destroy() end
			else
				for _, bp in ipairs(parts) do
					TweenService:Create(bp, TweenInfo.new(0.3), {Transparency = 1}):Play()
					Debris:AddItem(bp, 0.4)
				end
			end
		end
	end

	-- 盾の表面を走る稲妻
	local function DomeArcs()
		local c = hrp.Position + Vector3.new(0, 1.2, 0)
		local topPt = c + Vector3.new(0, 7.2, 0)
		for j = 1, 7 do
			local a = j / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local gp = Vector3.new(c.X + math.cos(a) * 9, groundY, c.Z + math.sin(a) * 9)
			local parts = {}
			BuildBolt(Folder, topPt, gp, 0.3, 7, 1, parts)
			for _, bp in ipairs(parts) do
				TweenService:Create(bp, TweenInfo.new(0.35), {Transparency = 1}):Play()
				Debris:AddItem(bp, 0.45)
			end
		end
	end

	------------------------------------------------------------
	-- 毎フレーム更新
	------------------------------------------------------------
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not Running or not Ctx then return end
		dt = math.min(dt, 1 / 20)
		T += dt
		State.glow += (State.glowTarget - State.glow) * math.min(dt * 3, 1)

		if circleOn then
			Spin += dt * State.spin
			outerPart.CFrame = CFrame.new(center + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, Spin * 0.4, 0)
			midPart.CFrame = CFrame.new(center + Vector3.new(0, 0.04, 0))
			innerPart.CFrame = CFrame.new(center + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, -Spin * 1.6, 0)
			light.Brightness = State.glow * (1 + 0.15 * math.sin(T * 4))
		end

		if not State.free and hrp.Parent then
			baseCF = CFrame.new(basePos) * CFrame.Angles(0, yaw, 0)
			local j = Vector3.new(math.sin(T * 43), math.sin(T * 37 + 1), math.cos(T * 41)) * State.shake
			hrp.CFrame = baseCF * CFrame.new(0, State.height + math.sin(T * 1.7) * State.bob, 0) * CFrame.new(j) * CFrame.Angles(State.pitch, 0, 0)
			if State.posing then ApplyPose() end
		end

		if chainsOn then
			for _, c in ipairs(chains) do
				UpdateChain(c)
			end
		end

		UpdateShield(dt)
		UpdateShards(dt)
		UpdateSwords(dt)
	end)
	Ctx.conn = conn

	Ctx.diedConn = hum.Died:Connect(function()
		Teardown()
	end)

	------------------------------------------------------------
	-- 1) 魔法陣を構築
	------------------------------------------------------------
	Notify("魔法陣", "展開を開始します", 3)
	local stages = {
		{S.outerRings, 1.0, 0.6}, {S.outerRunes, 1.5, 0.8}, {S.ticks, 0.9, 1.0},
		{S.midRings, 0.8, 1.2}, {S.triangle, 0.6, 1.3}, {S.midRunes, 0.8, 1.4},
		{S.sun, 0.6, 1.5}, {S.moon, 0.6, 1.6}, {S.star, 0.6, 1.7},
		{S.innerPoly, 0.7, 1.8}, {S.innerCircle, 0.6, 1.9}, {S.innerRunes, 1.0, 2.0},
	}
	for _, st in ipairs(stages) do
		if not Alive then break end
		State.glowTarget = st[3]
		Reveal(st[1], st[2])
	end
	if Alive then task.wait(0.4) end

	------------------------------------------------------------
	-- 2) 鎖が出現し手足を拘束
	------------------------------------------------------------
	if Alive then Notify("拘束", "鎖が現れた", 3) end
	chainsOn = true
	for i, c in ipairs(chains) do
		task.delay((i - 1) * 0.14, function()
			if Alive then Flash(c.ground) end
		end)
	end
	Animate(1.4, function(a)
		for i, c in ipairs(chains) do
			c.p = Ease(math.clamp((a - (i - 1) * 0.1) / 0.6, 0, 1))
		end
		State.pose = 0.6 * Ease(a)
		State.shake = 0.03 * a
	end)

	------------------------------------------------------------
	-- 3) 浮かび上がり、必死に足掻く
	------------------------------------------------------------
	Animate(3.2, function(a)
		local e = Ease(a)
		State.height = RISE * e
		State.tension = 0.25 + 0.75 * e
		State.pose = 0.6 + 0.4 * e
		State.shake = 0.03 + 0.05 * e
		State.flail = 0.5 * e
		State.spin = 0.4 + 1.2 * e
		State.glowTarget = 2 + 1.5 * e
	end)
	if Alive then Notify("足掻く", "必死に抵抗している…", 3) end
	Animate(3.2, function(a)
		State.bob = 0.3
		State.flail = 0.5 + 0.5 * math.min(a * 3, 1)
		State.shake = 0.1 + 0.12 * math.abs(math.sin(a * math.pi * 4))
	end)

	------------------------------------------------------------
	-- 4) 地面へ伏せられる
	------------------------------------------------------------
	if Alive then Notify("伏せ", "鎖に地面へ押さえつけられる", 3) end
	Animate(1.0, function(a)
		local e = a * a
		State.height = RISE + (proneOff - RISE) * e
		State.pitch = -math.pi / 2 * Ease(a)
		State.bob = 0.3 * (1 - a)
		State.tension = 1
	end)
	if Alive then
		Flash(Vector3.new(basePos.X, groundY, basePos.Z), WHITE, 12)
		ShakeCam(1.0, 0.4)
	end
	Animate(1.0, function(a)
		State.flail = 0.6 * (1 - a) + 0.2
		State.shake = 0.12 * (1 - a) + 0.04
	end)

	------------------------------------------------------------
	-- 5) 鎖から解放 → 力無く地面にへたり込む
	------------------------------------------------------------
	if Alive then Notify("解放", "鎖が消えた…", 3) end
	Animate(1.0, function(a)
		local e = Ease(a)
		for _, c in ipairs(chains) do
			c.p = 1 - e
		end
		State.pose = 1 - e
		State.flail = 0.2 * (1 - e)
		State.shake = 0.04 * (1 - e)
		State.spin = 1.6 - 1.0 * e
	end)
	chainsOn = false
	State.flail = 0
	if Alive then
		Animate(0.9, function(a)
			State.height = proneOff - 0.15 * math.sin(a * math.pi)
		end)
		task.wait(0.6)
	end

	------------------------------------------------------------
	-- 6) 雷 → 黄金の盾
	------------------------------------------------------------
	if Alive then
		Notify("雷", "雷が落ちる…！", 3)
		task.wait(0.3)
		task.spawn(Strike, hrp.Position + Vector3.new(0, 1, 0), function()
			RaiseShield()
			task.delay(0.05, DomeArcs)
		end)
		task.wait(0.8)
		Notify("黄金の盾", "黄金の盾が守ってくれた！", 3)
		task.wait(1.4)
	end

	------------------------------------------------------------
	-- 7) 目の前に剣が刺さっている
	------------------------------------------------------------
	local sword1 = nil
	local groundPt = nil
	if Alive then
		local fwd = baseCF.LookVector
		local gp = Vector3.new(basePos.X, groundY, basePos.Z) + fwd * 5.5
		local r2 = Workspace:Raycast(gp + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), params)
		local gy = r2 and r2.Position.Y or groundY
		groundPt = Vector3.new(gp.X, gy, gp.Z)

		sword1 = BuildSword(Folder)
		sword1.slot = 1
		sword1.state = "stuck"
		sword1.dir = Vector3.new(0, -1, 0)
		sword1.upHint = fwd
		sword1.pos = groundPt + Vector3.new(0, 2.6, 0)
		table.insert(Swords, sword1)
		FadeSwordIn(sword1, 0.7)

		Flash(groundPt, GOLD, 10)
		local pillar = Instance.new("Part")
		pillar.Shape = Enum.PartType.Cylinder
		pillar.Material = Enum.Material.Neon
		pillar.Color = Color3.fromRGB(255, 225, 140)
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.CanQuery = false
		pillar.CanTouch = false
		pillar.CastShadow = false
		pillar.Transparency = 0.3
		pillar.Size = Vector3.new(60, 3, 3)
		pillar.CFrame = CFrame.new(groundPt + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		pillar.Parent = Folder
		TweenService:Create(pillar, TweenInfo.new(1.0), {Transparency = 1, Size = Vector3.new(60, 0.4, 0.4)}):Play()
		Debris:AddItem(pillar, 1.1)

		Notify("剣", "目の前に黄金の剣が刺さっている…", 3)
		task.wait(1.0)
		FadeShield()
		task.wait(0.8)
	end

	------------------------------------------------------------
	-- 8) 起き上がる → 剣へ歩く
	------------------------------------------------------------
	if Alive then
		Animate(1.8, function(a)
			local e = Ease(a)
			State.pitch = -math.pi / 2 * (1 - e)
			State.height = proneOff * (1 - e)
			State.shake = 0.05 * (1 - e)
		end)
		State.pitch = 0
		State.height = 0
		State.posing = false
		RestoreMotors()

		-- 実際に歩いて近づく (操作は一時的に無効)
		local controls = GetControls()
		if controls then pcall(function() controls:Disable() end) end
		State.free = true
		hum.PlatformStand = false
		hrp.Anchored = false
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)

		local fwd = baseCF.LookVector
		local standPos = groundPt - fwd * 2.8
		hum:MoveTo(standPos)
		local t0 = os.clock()
		while Alive do
			local dflat = Vector3.new(hrp.Position.X - standPos.X, 0, hrp.Position.Z - standPos.Z).Magnitude
			if dflat < 1.3 or os.clock() - t0 > 4.5 then break end
			task.wait(0.05)
		end
		hum:Move(Vector3.zero)

		-- 剣の方を向いて固定
		local toS = Vector3.new(groundPt.X - hrp.Position.X, 0, groundPt.Z - hrp.Position.Z)
		if toS.Magnitude > 0.1 then
			yaw = math.atan2(-toS.Unit.X, -toS.Unit.Z)
		end
		basePos = hrp.Position
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.Anchored = true
		State.free = false
		State.posing = true
		State.pose = 0
		State.height = 0
		State.pitch = 0
		hum.AutoRotate = false
	end

	------------------------------------------------------------
	-- 9) 剣を抜く → 8本に増える
	------------------------------------------------------------
	if Alive and sword1 then
		Notify("剣を抜く", "剣を引き抜く…", 3)
		Animate(0.7, function(a)
			State.grab = Ease(a)
		end)

		local startPos = sword1.pos
		local fwdH = Vector3.new(math.sin(-yaw) * -1, 0, 0)
		fwdH = CFrame.Angles(0, yaw, 0).LookVector
		-- 引き抜いて持ち上げる
		Animate(1.2, function(a)
			local e = Ease(a)
			sword1.pos = startPos + Vector3.new(0, 5.4 * e, 0)
			sword1.upHint = fwdH
		end)
		local liftPos = sword1.pos
		Explode(Vector3.new(groundPt.X, groundPt.Y + 0.5, groundPt.Z), 0.5)
		SpawnShards(groundPt + Vector3.new(0, 0.5, 0), 14, 22)

		-- 切っ先を前方へ向ける
		Animate(0.9, function(a)
			local e = Ease(a)
			local phi = math.rad(-90 + 125 * e)
			sword1.dir = (fwdH * math.cos(phi) + Vector3.new(0, math.sin(phi), 0)).Unit
			sword1.pos = liftPos + Vector3.new(0, 1.2 * e, 0) + fwdH * (-1.0 * e)
		end)

		-- 増殖
		Notify("増殖", "剣が8本に増えた！", 3)
		ScreenFlash(false)
		Explode(sword1.pos, 0.9)
		local origin = sword1.pos
		sword1.state = "toSlot"
		sword1.t = 0
		sword1.dur = 1.1
		sword1.start = origin
		sword1.arc = 2
		for i = 2, SWORD_COUNT do
			local n = BuildSword(Folder)
			n.slot = i
			n.state = "toSlot"
			n.t = 0
			n.dur = 1.0 + rng:NextNumber(0, 0.3)
			n.start = origin
			n.pos = origin
			n.dir = sword1.dir
			n.arc = rng:NextNumber(1, 4)
			n.upHint = fwdH
			SetSwordShown(n, true)
			table.insert(Swords, n)
		end

		Animate(0.5, function(a)
			State.grab = 1 - Ease(a)
		end)
		task.wait(1.2)
	end

	------------------------------------------------------------
	-- 10) 剣の神: 操作を返す
	------------------------------------------------------------
	if Alive then
		State.free = true
		State.posing = false
		RestoreMotors()
		hum.AutoRotate = true
		hum.PlatformStand = false
		hrp.Anchored = false
		local controls = GetControls()
		if controls then pcall(function() controls:Enable() end) end
		circleOn = false
		for _, cg in ipairs({outerCG, midCG, innerCG}) do
			TweenService:Create(cg, TweenInfo.new(1.5), {GroupTransparency = 1}):Play()
		end
		State.glowTarget = 0

		God = true
		Alive = false
		if FireBtn then FireBtn.Visible = true end
		Notify("剣の神", "あなたは剣の神になった。「発射」で視点の中心へ放てる", 5)
	end
end

------------------------------------------------------------------
-- Gui (モバイル用 / 小型・オブシディアン)
------------------------------------------------------------------
local OBS_BG = Color3.fromRGB(8, 8, 12)
local OBS_BTN = Color3.fromRGB(20, 18, 28)
local OBS_STROKE = Color3.fromRGB(88, 78, 124)
local OBS_TEXT = Color3.fromRGB(205, 198, 225)

local gui = Instance.new("ScreenGui")
gui.Name = "SwordGodGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999

local parented = pcall(function()
	gui.Parent = game:GetService("CoreGui")
end)
if not parented or not gui.Parent then
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local function Round(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = obj
end

local function Stroke(obj, color, th)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = th
	s.Parent = obj
end

local function MakeButton(parent, text, size, pos, anchor, textSize)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.AnchorPoint = anchor or Vector2.new(0, 0)
	b.BackgroundColor3 = OBS_BTN
	b.BackgroundTransparency = 0.1
	b.Text = text
	b.TextColor3 = OBS_TEXT
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = textSize or 16
	b.AutoButtonColor = true
	b.Parent = parent
	Round(b, 10)
	Stroke(b, OBS_STROKE, 1)
	return b
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(150, 98)
main.Position = UDim2.new(0, 8, 0.15, 0)
main.BackgroundColor3 = OBS_BG
main.BorderSizePixel = 0
main.Parent = gui
Round(main, 10)
Stroke(main, OBS_STROKE, 1.5)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -34, 0, 26)
title.Position = UDim2.fromOffset(8, 0)
title.BackgroundTransparency = 1
title.Text = "剣の神"
title.TextColor3 = OBS_TEXT
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = main

local closeBtn = MakeButton(main, "×", UDim2.fromOffset(22, 22), UDim2.new(1, -26, 0, 2), Vector2.new(0, 0), 16)
local startBtn = MakeButton(main, "発動", UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 30), Vector2.new(0, 0), 16)
local resetBtn = MakeButton(main, "解除", UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 62), Vector2.new(0, 0), 16)

FireBtn = MakeButton(gui, "⚔\n発射", UDim2.fromOffset(78, 78), UDim2.new(1, -16, 0.5, 0), Vector2.new(1, 0.5), 18)
FireBtn.Visible = false
FireBtn.BackgroundColor3 = Color3.fromRGB(34, 22, 52)
Stroke(FireBtn, Color3.fromRGB(255, 196, 48), 1.5)

local dragging = false
local dragStart, startPos
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)
local dragConn = UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

startBtn.Activated:Connect(function()
	if Running then
		Notify("実行中", "「解除」してからもう一度押してください", 3)
		return
	end
	task.spawn(function()
		local ok, err = pcall(RunBody)
		if not ok then
			Notify("エラー", tostring(err), 6)
			Teardown()
		end
	end)
end)

resetBtn.Activated:Connect(function()
	Teardown()
	Notify("解除", "元に戻しました", 3)
end)

FireBtn.Activated:Connect(function()
	local ok, err = pcall(Fire)
	if not ok then
		Notify("エラー", tostring(err), 5)
	end
end)

local charConn = LocalPlayer.CharacterAdded:Connect(function()
	if Running then
		Teardown()
	end
end)

local function FullCleanup()
	Teardown()
	pcall(function() dragConn:Disconnect() end)
	pcall(function() charConn:Disconnect() end)
	if gui then gui:Destroy() end
	env.SwordGodCleanup = nil
end

closeBtn.Activated:Connect(FullCleanup)
env.SwordGodCleanup = FullCleanup

Notify("剣の神", "Guiを読み込みました。「発動」を押してください", 4)
