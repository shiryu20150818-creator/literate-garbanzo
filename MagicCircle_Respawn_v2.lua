--[[
	魔法陣 → 鎖の拘束アニメーション → 降下 → 緑の雷 → 黒化 → 粉末消滅 → Respawn
	モバイル用 (タッチ操作のGui付き)
	・魔法陣は線とルーンが少しずつ構築されていきます
	・鎖(リアル版)・雷・粉末は見た目だけの演出です (R6 / R15 両対応)
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

-- 二重実行対策 (前回のものを片付ける)
if env.MagicCircleCleanup then
	pcall(env.MagicCircleCleanup)
end

------------------------------------------------------------------
-- 設定
------------------------------------------------------------------
local CYAN = Color3.fromRGB(70, 230, 255)
local WHITE = Color3.fromRGB(225, 255, 255)
local GREEN = Color3.fromRGB(80, 255, 120)
local GREEN_CORE = Color3.fromRGB(215, 255, 225)
local GREEN_FLASH = Color3.fromRGB(150, 255, 175)
local BLACKISH = Color3.fromRGB(10, 10, 12)

local CANVAS = 1000      -- SurfaceGuiのキャンバスサイズ(px)
local CEN = 500          -- キャンバス中心
local RAD = 480          -- 魔法陣の最大半径(px)
local DIAMETER = 26      -- 魔法陣の直径(studs)
local RISE = 7           -- 浮かび上がる高さ(studs)
local LINK_POOL = 40     -- 鎖1本あたりの最大リンク数
local LINK_SPACING = 0.5 -- リンク間隔
local HIDE = CFrame.new(0, -5000, 0)

-- 鎖リンク1個 = 細い円柱4本 (長方形の輪)。向きはリンクのCFrameからの相対
local LINK_OFFS = {
	CFrame.new(-0.2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
	CFrame.new(0.2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
	CFrame.new(0, 0, 0.31),
	CFrame.new(0, 0, -0.31),
}

local Alive = false
local Running = false
local CurrentCleanup = nil
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

-- ルーン文字 (角ばった文字を線で構成)
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

-- 魔法陣の設計 (写真に似せた構成)
local function BuildDesign(outerCG, midCG, innerCG)
	local S = {
		outerRings = {}, outerRunes = {}, ticks = {},
		midRings = {}, triangle = {}, midRunes = {},
		sun = {}, moon = {}, star = {},
		innerPoly = {}, innerCircle = {}, innerRunes = {},
	}

	-- 外側: 二重リング / ルーン帯 / 目盛り帯
	Arc(outerCG, CEN, CEN, RAD * 0.985, 4, S.outerRings, 0, 360)
	Arc(outerCG, CEN, CEN, RAD * 0.955, 2, S.outerRings, 0, 360)
	RuneArc(outerCG, CEN, CEN, RAD * 0.92, 76, 26, 0, 360, S.outerRunes)
	Arc(outerCG, CEN, CEN, RAD * 0.885, 2, S.ticks, 0, 360)
	Arc(outerCG, CEN, CEN, RAD * 0.80, 3, S.ticks, 0, 360)
	for i = 0, 71 do
		local deg = i * 5
		MakeLine(outerCG, Pt(CEN, CEN, RAD * 0.80, deg), Pt(CEN, CEN, RAD * 0.885, deg), 2, S.ticks)
	end

	-- 中間: 内側リング / 三角形 / ルーン3列
	Arc(midCG, CEN, CEN, RAD * 0.78, 4, S.midRings, 0, 360)
	Arc(midCG, CEN, CEN, RAD * 0.745, 2, S.midRings, 0, 360)
	Poly(midCG, CEN, CEN, RAD * 0.74, 3, -75, 2, S.triangle)
	RuneArc(midCG, CEN, CEN, RAD * 0.64, 6, 34, -95, -50, S.midRunes)
	RuneArc(midCG, CEN, CEN, RAD * 0.64, 6, 34, 25, 70, S.midRunes)
	RuneArc(midCG, CEN, CEN, RAD * 0.64, 6, 34, 142, 188, S.midRunes)

	-- 太陽 / 月 / 星
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

	-- 内側: 六角形 / 小ルーン帯 / 円と六分割
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
-- 緑の雷 (ギザギザの稲妻を組み立てる)
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
		local s1 = BoltSegment(parent, pts[i], pts[i + 1], w * 3, GREEN, 0.55)
		local s2 = BoltSegment(parent, pts[i], pts[i + 1], w, GREEN_CORE, 0)
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
	cc.Brightness = big and 0.35 or 0.15
	cc.TintColor = Color3.fromRGB(170, 255, 190)
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(big and 0.7 or 0.35), {
		Brightness = 0,
		TintColor = Color3.new(1, 1, 1)
	}):Play()
	Debris:AddItem(cc, 1.2)
end

------------------------------------------------------------------
-- 汎用
------------------------------------------------------------------
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

	Alive = true
	local conn, diedConn
	local State = {
		height = 0, tension = 0.25, pose = 0, shake = 0, bob = 0,
		glow = 0, glowTarget = 0, spin = 0.4,
	}
	local T, Spin = 0, 0
	local Dust = {}

	-- 演出用フォルダ
	local Folder = Instance.new("Folder")
	Folder.Name = "MagicCircleFx"
	Folder.Parent = Workspace

	-- 地面の高さ
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char, Folder}
	local res = Workspace:Raycast(hrp.Position, Vector3.new(0, -60, 0), params)
	local groundY = res and (res.Position.Y + 0.05) or (hrp.Position.Y - 3)
	local center = Vector3.new(hrp.Position.X, groundY, hrp.Position.Z)

	-- 向き(ヨー)のみ取り出す
	local look = hrp.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local baseCF = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
	local yawCF = CFrame.new(center) * CFrame.Angles(0, yaw, 0)

	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.Anchored = true

	-- 魔法陣レイヤー
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

	-- 発光
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

	-- パーティクル (火花 / 黒い煙)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(GREEN)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(0.4, 0.9)
	sparks.Speed = NumberRange.new(6, 14)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 120
	sparks.Enabled = false
	sparks.Parent = hrp

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(12, 12, 14))
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 5),
	})
	smoke.Lifetime = NumberRange.new(1.2, 2)
	smoke.Speed = NumberRange.new(1, 3)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Acceleration = Vector3.new(1.5, 1.5, 0)
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.Rate = 35
	smoke.Enabled = false
	smoke.Parent = hrp

	-- 鎖 (リアル版: 金属の輪が交互に噛み合う)
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
				limb = limb,
				cuff = cuff,
				band = band,
				base = base,
				links = links,
				ground = groundPos,
				p = 0,
				lastCount = 0,
				seed = rng:NextNumber(0, 100),
			})
		end
	end

	local function GetAttach(limb)
		if limb.Name:find(" ") then -- R6
			return limb.CFrame * CFrame.new(0, -limb.Size.Y / 2 + 0.3, 0)
		end
		return limb.CFrame -- R15
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

		-- 地中から出てくるように始点を少し下げる
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
		if not Folder then return end
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

	-- 雷の着弾の光
	local function ImpactLight(pos, big)
		if not Folder then return end
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
		l.Color = GREEN
		l.Range = big and 45 or 25
		l.Brightness = big and 25 or 10
		l.Parent = p
		TweenService:Create(l, TweenInfo.new(0.6), {Brightness = 0}):Play()
		Debris:AddItem(p, 0.8)
	end

	-- 緑の雷を落とす
	local function Strike(target, big)
		if not Alive or not Folder then return end
		local top = target + Vector3.new(rng:NextNumber(-8, 8), 140, rng:NextNumber(-8, 8))
		local w = big and 0.9 or 0.4
		local flickers = big and 4 or 2
		for k = 1, flickers do
			if not Alive or not Folder then return end
			local parts = {}
			BuildBolt(Folder, top, target, w, 16, 0, parts)
			if k == 1 then
				Flash(Vector3.new(target.X, groundY, target.Z), GREEN, big and 18 or 9)
				ImpactLight(target, big)
				ScreenFlash(big)
			end
			task.wait(big and 0.07 or 0.05)
			if k < flickers then
				for _, bp in ipairs(parts) do
					bp:Destroy()
				end
			else
				for _, bp in ipairs(parts) do
					TweenService:Create(bp, TweenInfo.new(0.3), {Transparency = 1}):Play()
					Debris:AddItem(bp, 0.4)
				end
			end
		end
	end

	-- 手足のポーズ (Motor6D)
	local motorDefs = {
		{"RightShoulder", "Right Shoulder", 1, 95},
		{"LeftShoulder", "Left Shoulder", -1, 95},
		{"RightHip", "Right Hip", 1, 30},
		{"LeftHip", "Left Hip", -1, 30},
	}
	local motors = {}
	for _, def in ipairs(motorDefs) do
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Motor6D") and (d.Name == def[1] or d.Name == def[2]) then
				table.insert(motors, {m = d, c0 = d.C0, sign = def[3], ang = def[4]})
				break
			end
		end
	end

	local function ApplyPose(b)
		for _, e in ipairs(motors) do
			local pos = e.c0.Position
			local rot = e.c0 - pos
			e.m.C0 = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(e.sign * e.ang * b)) * rot
		end
	end

	-- 体 (黒化・粉末化用の記録)
	local bodyRecs = {}
	local bodyCollected = false
	local bodyKeep = false
	local origDisplay = hum.DisplayDistanceType

	local function CollectBody()
		bodyCollected = true
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Name ~= "HumanoidRootPart" then
					table.insert(bodyRecs, {inst = d, prop = "Color", color = d.Color, tr = d.Transparency, mat = d.Material})
				end
			elseif d:IsA("Decal") then
				table.insert(bodyRecs, {inst = d, prop = "Color3", color = d.Color3, tr = d.Transparency})
			elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
				table.insert(bodyRecs, {inst = d, prop = "Color3", color = d.Color3})
			elseif d:IsA("SurfaceAppearance") then
				table.insert(bodyRecs, {inst = d, prop = "Color", color = d.Color})
			end
		end
	end

	local function SetBodyColor(c)
		for _, rec in ipairs(bodyRecs) do
			pcall(function()
				rec.inst[rec.prop] = c
			end)
		end
	end

	local function SetBodyNeon(on)
		for _, rec in ipairs(bodyRecs) do
			if rec.mat then
				pcall(function()
					rec.inst.Material = on and Enum.Material.Neon or rec.mat
				end)
			end
		end
	end

	local function RestoreBody()
		for _, rec in ipairs(bodyRecs) do
			pcall(function()
				rec.inst[rec.prop] = rec.color
				if rec.tr then
					rec.inst.Transparency = rec.tr
				end
				if rec.mat then
					rec.inst.Material = rec.mat
				end
			end)
		end
		pcall(function()
			hum.DisplayDistanceType = origDisplay
		end)
	end

	-- 粉末
	local function SpawnDust(part)
		if not Folder then return end
		local sz = part.Size
		local vol = sz.X * sz.Y * sz.Z
		local n = math.clamp(math.floor(vol * 4) + 5, 6, 26)
		for _ = 1, n do
			if #Dust >= 420 then break end
			local lp = Vector3.new(
				rng:NextNumber(-0.5, 0.5) * sz.X,
				rng:NextNumber(-0.5, 0.5) * sz.Y,
				rng:NextNumber(-0.5, 0.5) * sz.Z
			)
			local pos = (part.CFrame * CFrame.new(lp)).Position
			local isSpark = rng:NextNumber() < 0.12
			local s = isSpark and rng:NextNumber(0.08, 0.16) or rng:NextNumber(0.12, 0.32)
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Size = Vector3.new(s, s, s)
			p.Material = isSpark and Enum.Material.Neon or Enum.Material.SmoothPlastic
			p.Color = isSpark and GREEN or Color3.fromHSV(0, 0, rng:NextNumber(0.03, 0.16))
			p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
			p.Parent = Folder

			local out = pos - hrp.Position
			if out.Magnitude > 0.01 then
				out = out.Unit
			else
				out = Vector3.yAxis
			end
			table.insert(Dust, {
				part = p,
				vel = out * rng:NextNumber(0.8, 2.5)
					+ Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.5, 2.5), rng:NextNumber(-1, 1))
					+ Vector3.new(2.5, 0, 0.5),
				age = 0,
				life = rng:NextNumber(1.8, 3.2),
				size = s,
				spin = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6)),
			})
		end
	end

	local function UpdateDust(dt)
		for i = #Dust, 1, -1 do
			local d = Dust[i]
			d.age += dt
			if d.age >= d.life then
				d.part:Destroy()
				table.remove(Dust, i)
			else
				local k = d.age / d.life
				d.vel = d.vel * (1 - math.min(dt * 0.6, 1))
					+ Vector3.new(math.sin(T * 3 + i) * dt * 1.5, dt * 0.35, math.cos(T * 2.3 + i) * dt * 1.5)
					+ Vector3.new(dt * 1.2, 0, 0)
				local cf = d.part.CFrame
				local pos = cf.Position + d.vel * dt
				local sc = d.size * (1 - 0.75 * k)
				d.part.Size = Vector3.new(sc, sc, sc)
				d.part.CFrame = CFrame.new(pos) * (cf - cf.Position) * CFrame.Angles(d.spin.X * dt, d.spin.Y * dt, d.spin.Z * dt)
				d.part.Transparency = math.clamp((k - 0.45) / 0.55, 0, 1)
			end
		end
	end

	-- 後片付け
	CurrentCleanup = function()
		Alive = false
		if conn then conn:Disconnect() conn = nil end
		if diedConn then diedConn:Disconnect() diedConn = nil end
		for _, e in ipairs(motors) do
			pcall(function() e.m.C0 = e.c0 end)
		end
		if bodyCollected and not bodyKeep and hum.Health > 0 then
			RestoreBody()
		end
		pcall(function() sparks:Destroy() end)
		pcall(function() smoke:Destroy() end)
		pcall(function() hrp.Anchored = false end)
		if Folder then
			Folder:Destroy()
			Folder = nil
		end
		Running = false
	end

	diedConn = hum.Died:Connect(function()
		if Alive then
			bodyKeep = true
			CurrentCleanup()
		end
	end)

	-- 毎フレーム更新
	conn = RunService.RenderStepped:Connect(function(dt)
		if not Alive then return end
		T += dt
		Spin += dt * State.spin
		State.glow += (State.glowTarget - State.glow) * math.min(dt * 3, 1)

		outerPart.CFrame = CFrame.new(center + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, Spin * 0.4, 0)
		midPart.CFrame = CFrame.new(center + Vector3.new(0, 0.04, 0))
		innerPart.CFrame = CFrame.new(center + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, -Spin * 1.6, 0)
		light.Brightness = State.glow * (1 + 0.15 * math.sin(T * 4))

		if hrp.Parent then
			local j = Vector3.new(math.sin(T * 43), math.sin(T * 37 + 1), math.cos(T * 41)) * State.shake
			hrp.CFrame = baseCF * CFrame.new(0, State.height + math.sin(T * 1.7) * State.bob, 0) * CFrame.new(j)
			ApplyPose(State.pose)
		end

		for _, c in ipairs(chains) do
			UpdateChain(c)
		end
		UpdateDust(dt)
	end)

	------------------------------------------------------------------
	-- 1) 魔法陣を構築
	------------------------------------------------------------------
	Notify("魔法陣", "展開を開始します", 3)
	local stages = {
		{S.outerRings, 1.0, 0.6},
		{S.outerRunes, 1.5, 0.8},
		{S.ticks, 0.9, 1.0},
		{S.midRings, 0.8, 1.2},
		{S.triangle, 0.6, 1.3},
		{S.midRunes, 0.8, 1.4},
		{S.sun, 0.6, 1.5},
		{S.moon, 0.6, 1.6},
		{S.star, 0.6, 1.7},
		{S.innerPoly, 0.7, 1.8},
		{S.innerCircle, 0.6, 1.9},
		{S.innerRunes, 1.0, 2.0},
	}
	for _, st in ipairs(stages) do
		if not Alive then break end
		State.glowTarget = st[3]
		Reveal(st[1], st[2])
	end
	if Alive then task.wait(0.4) end

	------------------------------------------------------------------
	-- 2) 地面から鎖が出現し手足へ絡みつく
	------------------------------------------------------------------
	if Alive then Notify("拘束", "鎖が現れた", 3) end
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

	------------------------------------------------------------------
	-- 3) 鎖に引っ張られて浮かび上がる
	------------------------------------------------------------------
	Animate(3.2, function(a)
		local e = Ease(a)
		State.height = RISE * e
		State.tension = 0.25 + 0.75 * e
		State.pose = 0.6 + 0.4 * e
		State.shake = 0.03 + 0.05 * e
		State.spin = 0.4 + 1.2 * e
		State.glowTarget = 2 + 1.5 * e
	end)

	-- 宙吊りで抵抗する
	Animate(2.0, function(a)
		State.bob = 0.25
		State.shake = 0.08 + 0.1 * math.sin(a * math.pi)
	end)

	------------------------------------------------------------------
	-- 4) 地面に降ろされる
	------------------------------------------------------------------
	Animate(2.6, function(a)
		local e = Ease(a)
		State.height = RISE * (1 - e)
		State.bob = 0.25 * (1 - e)
		State.shake = 0.08 * (1 - e)
		State.tension = 1 - 0.5 * e
		State.spin = 1.6 - 1.0 * e
	end)
	if Alive then task.wait(0.5) end

	-- 鎖が地面へ戻る (拘束が解かれる)
	Animate(1.0, function(a)
		local e = Ease(a)
		for _, c in ipairs(chains) do
			c.p = 1 - e
		end
		State.pose = 1 - e
	end)

	------------------------------------------------------------------
	-- 5) 上から緑の雷が落ちる
	------------------------------------------------------------------
	if Alive then
		Notify("天罰", "緑の雷が落ちる", 3)
		CollectBody()
		task.wait(0.7)
	end
	if Alive then
		local hitPos = hrp.Position + Vector3.new(0, 1, 0)
		light.Color = GREEN
		State.glowTarget = 5
		task.spawn(Strike, hitPos, true)

		-- 被雷: 一瞬だけ緑に発光して、黒く焼ける
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		SetBodyNeon(true)
		SetBodyColor(GREEN_FLASH)
		State.shake = 0.35
		sparks.Enabled = true
		task.wait(0.18)
		SetBodyNeon(false)

		local s2, s3 = false, false
		Animate(1.6, function(a)
			local e = Ease(a)
			SetBodyColor(GREEN_FLASH:Lerp(BLACKISH, e))
			State.shake = 0.35 - 0.2 * e
			State.glowTarget = 5 - 3 * e
			if a > 0.3 and not s2 then
				s2 = true
				task.spawn(Strike, hrp.Position + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), false)
			end
			if a > 0.65 and not s3 then
				s3 = true
				task.spawn(Strike, hrp.Position + Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5)), false)
			end
		end)
		sparks.Enabled = false
		smoke.Enabled = true
		State.shake = 0.05
		if Alive then task.wait(0.5) end
	end

	------------------------------------------------------------------
	-- 6) 体が崩れて粉になり、空気に紛れて消える
	------------------------------------------------------------------
	if Alive then
		Notify("崩壊", "体が粉になって散っていく", 3)

		-- 魔法陣はゆっくり消えていく
		task.spawn(function()
			Animate(3.0, function(a)
				outerCG.GroupTransparency = a
				midCG.GroupTransparency = a
				innerCG.GroupTransparency = a
				State.glowTarget = 0
			end)
		end)

		-- 足元から頭に向かって順番に崩す
		local minY, maxY = math.huge, -math.huge
		local dparts = {}
		local decalMap = {}
		for _, rec in ipairs(bodyRecs) do
			if rec.inst:IsA("BasePart") and rec.tr < 0.95 then
				local y = rec.inst.Position.Y
				minY = math.min(minY, y)
				maxY = math.max(maxY, y)
				table.insert(dparts, {rec = rec, y = y, decals = {}, started = false})
			elseif rec.inst:IsA("Decal") then
				local owner = rec.inst.Parent
				decalMap[owner] = decalMap[owner] or {}
				table.insert(decalMap[owner], rec)
			end
		end
		for _, pr in ipairs(dparts) do
			pr.delay = ((pr.y - minY) / (maxY - minY + 0.001)) * 1.4
			pr.decals = decalMap[pr.rec.inst] or {}
		end

		local DIS = 2.2
		Animate(DIS, function(a)
			local tNow = a * DIS
			State.shake = 0.06
			for _, pr in ipairs(dparts) do
				if tNow >= pr.delay then
					if not pr.started then
						pr.started = true
						SpawnDust(pr.rec.inst)
					end
					local k = math.clamp((tNow - pr.delay) / 0.6, 0, 1)
					pr.rec.inst.Transparency = pr.rec.tr + (1 - pr.rec.tr) * k
					for _, dr in ipairs(pr.decals) do
						dr.inst.Transparency = dr.tr + (1 - dr.tr) * k
					end
				end
			end
		end)
		smoke.Enabled = false

		-- 粉が空気に紛れて消えるのを待つ
		local waitStart = os.clock()
		while Alive and #Dust > 0 and os.clock() - waitStart < 5 do
			RunService.Heartbeat:Wait()
		end
		if Alive then task.wait(0.4) end
	end

	------------------------------------------------------------------
	-- 7) Respawn
	------------------------------------------------------------------
	local completed = Alive
	bodyKeep = true
	CurrentCleanup()
	if completed then
		Notify("Respawn", "リスポーンします", 3)
		local ok = pcall(function()
			hum.Health = 0
		end)
		if not ok then
			pcall(function()
				char:BreakJoints()
			end)
		end
	end
end

------------------------------------------------------------------
-- Gui (モバイル用)
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MagicCircleGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999

local parented = pcall(function()
	gui.Parent = game:GetService("CoreGui")
end)
if not parented or not gui.Parent then
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(220, 130)
main.Position = UDim2.new(0, 20, 0.3, 0)
main.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = CYAN
mainStroke.Thickness = 2
mainStroke.Parent = main

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -40, 0, 38)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "魔法陣 Respawn"
title.TextColor3 = CYAN
title.Font = Enum.Font.SourceSansBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = main

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.fromOffset(32, 32)
closeBtn.Position = UDim2.new(1, -38, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 55)
closeBtn.Text = "×"
closeBtn.TextColor3 = WHITE
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 24
closeBtn.Parent = main
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

local startBtn = Instance.new("TextButton")
startBtn.Name = "Start"
startBtn.Size = UDim2.new(1, -20, 0, 60)
startBtn.Position = UDim2.fromOffset(10, 52)
startBtn.BackgroundColor3 = Color3.fromRGB(20, 80, 100)
startBtn.Text = "発動"
startBtn.TextColor3 = WHITE
startBtn.Font = Enum.Font.SourceSansBold
startBtn.TextSize = 28
startBtn.Parent = main
local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 10)
startCorner.Parent = startBtn
local startStroke = Instance.new("UIStroke")
startStroke.Color = CYAN
startStroke.Thickness = 1.5
startStroke.Parent = startBtn

-- タッチでドラッグ移動
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

-- ボタン動作
local function SetButton(running)
	startBtn.Text = running and "発動中..." or "発動"
	startBtn.BackgroundColor3 = running and Color3.fromRGB(40, 50, 60) or Color3.fromRGB(20, 80, 100)
end

startBtn.Activated:Connect(function()
	if Running then return end
	Running = true
	SetButton(true)
	task.spawn(function()
		local ok, err = pcall(RunBody)
		if not ok then
			Notify("エラー", tostring(err), 6)
			if CurrentCleanup then
				pcall(CurrentCleanup)
			end
		end
		Running = false
		SetButton(false)
	end)
end)

local function FullCleanup()
	if CurrentCleanup and Alive then
		pcall(CurrentCleanup)
	end
	Alive = false
	Running = false
	if dragConn then dragConn:Disconnect() end
	if gui then gui:Destroy() end
	env.MagicCircleCleanup = nil
end

closeBtn.Activated:Connect(FullCleanup)
env.MagicCircleCleanup = FullCleanup

Notify("魔法陣", "Guiを読み込みました。「発動」を押してください", 4)
