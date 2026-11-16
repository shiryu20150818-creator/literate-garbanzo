--[[
	妖刀 (ようとう) - 抜刀 → 走る → 斬撃
	・地面に刺さった妖刀を、片手で3秒抜こうとして抜けず → 両手でようやく抜く
	・刀は右手に持ち、体を前に傾けて走る
	・刀を持っている間、体から水色と紫のオーラが出て、目が赤く光る
	・斬1: 振りかざして斬る / 斬2: 回転しながら前進して横に斬る
	・刀は人の半分ほどの大きさ。刃は黒く、紫のオーラが横に流れる
	・通知なし / 開閉できる小型Gui (開: 320x200 / 閉: 56x56)
	※ すべてクライアント側の演出です (自分にだけ見えます)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local env = getgenv()

-- 二重実行対策
if env.YoutouCleanup then
	pcall(env.YoutouCleanup)
end

------------------------------------------------------------------
-- 設定
------------------------------------------------------------------
local PURPLE = Color3.fromRGB(150, 70, 255)
local PURPLE_D = Color3.fromRGB(90, 40, 170)
local CYAN = Color3.fromRGB(90, 230, 255)
local BLADE = Color3.fromRGB(14, 10, 22)
local RED = Color3.fromRGB(255, 30, 30)

local rng = Random.new()
local Running = false
local Ctx = nil
local Shards = {}
local Waves = {}
local SlashBtns = nil

local function Ease(t)
	return t * t * (3 - 2 * t)
end

local function Animate(duration, fn)
	local start = os.clock()
	while Running and Ctx do
		local a = math.clamp((os.clock() - start) / duration, 0, 1)
		fn(a)
		if a >= 1 then break end
		RunService.Heartbeat:Wait()
	end
end

local function Wait(sec)
	local t0 = os.clock()
	while Running and Ctx and os.clock() - t0 < sec do
		RunService.Heartbeat:Wait()
	end
end

------------------------------------------------------------------
-- モーター(関節)の取得 / ポーズ
------------------------------------------------------------------
local function CollectMotors(model)
	local defs = {
		root = {"RootJoint"},
		waist = {"Waist"},
		shR = {"RightShoulder", "Right Shoulder"},
		shL = {"LeftShoulder", "Left Shoulder"},
		elR = {"RightElbow"},
		elL = {"LeftElbow"},
		hipR = {"RightHip", "Right Hip"},
		hipL = {"LeftHip", "Left Hip"},
		knR = {"RightKnee"},
		knL = {"LeftKnee"},
	}
	local list = {}
	for key, names in pairs(defs) do
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") then
				for _, n in ipairs(names) do
					if d.Name == n then
						list[key] = {m = d, c0 = d.C0}
					end
				end
			end
		end
	end
	return list
end

local function Pose(e, rx, ry, rz)
	if not e then return end
	local pos = e.c0.Position
	local rot = e.c0 - pos
	e.m.C0 = CFrame.new(pos) * CFrame.Angles(rx, ry or 0, rz or 0) * rot
end

local function RestoreMotors(motors)
	for _, e in pairs(motors or {}) do
		pcall(function()
			e.m.C0 = e.c0
		end)
	end
end

------------------------------------------------------------------
-- 破片 / 衝撃波 / 斬撃エフェクト
------------------------------------------------------------------
local function SpawnShards(pos, count, speed, color, mat)
	if not Ctx then return end
	for _ = 1, count do
		if #Shards > 200 then break end
		local s = rng:NextNumber(0.12, 0.4)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(s, s * 0.6, s * rng:NextNumber(0.8, 1.8))
		p.Material = mat or Enum.Material.Slate
		p.Color = color or Color3.fromRGB(60, 52, 70)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		p.Parent = Ctx.Folder
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.1, 1.2), rng:NextNumber(-1, 1))
		table.insert(Shards, {
			part = p, vel = dir.Unit * rng:NextNumber(speed * 0.4, speed),
			age = 0, life = rng:NextNumber(0.8, 1.4),
			spin = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(-9, 9), rng:NextNumber(-9, 9)),
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
			d.part.Transparency = math.clamp((d.age / d.life - 0.6) / 0.4, 0, 1)
		end
	end
end

local function Ring(pos, color, startSize, endSize, dur, tr0)
	if not Ctx then return end
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CanTouch = false
	r.CastShadow = false
	r.Transparency = tr0 or 0.2
	r.Size = Vector3.new(0.2, startSize, startSize)
	r.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	r.Parent = Ctx.Folder
	TweenService:Create(r, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, endSize, endSize), Transparency = 1
	}):Play()
	Debris:AddItem(r, dur + 0.1)
end

local function ScreenFlash(color, strength)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = strength or 0.25
	cc.TintColor = color
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(0.7), {Brightness = 0, TintColor = Color3.new(1, 1, 1)}):Play()
	Debris:AddItem(cc, 1)
end

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

local function Burst(pos, n, color, speed)
	if not Ctx then return end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.5, 0.5, 0.5)
	p.CFrame = CFrame.new(pos)
	p.Parent = Ctx.Folder
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)})
	pe.Lifetime = NumberRange.new(0.4, 0.9)
	pe.Speed = NumberRange.new((speed or 20) * 0.5, speed or 20)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 0
	pe.Parent = p
	pe:Emit(n)
	Debris:AddItem(p, 1.5)
end

-- 縦の斬撃波 (三日月型)
local function SpawnCrescent(origin)
	if not Ctx then return end
	local parts = {}
	local n = 17
	local tilt = -0.6
	for i = 0, n - 1 do
		local t = -1 + 2 * i / (n - 1)
		local y = t * 3.4
		local x = -(t * t) * 1.4
		local dy = 3.4
		local dx = -2 * t * 1.4
		local ang = math.atan2(dx, dy)
		local w = 0.55 * (1 - math.abs(t) ^ 1.6) + 0.06
		for layer = 1, 2 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = (layer == 1) and PURPLE or Color3.fromRGB(210, 245, 255)
			p.Transparency = (layer == 1) and 0.15 or 0.05
			local seg = 0.5
			p.Size = Vector3.new((layer == 1) and w or w * 0.35, seg, 0.06)
			p.CFrame = origin * CFrame.Angles(0, 0, tilt) * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, -ang)
			p.Parent = Ctx.Folder
			table.insert(parts, p)
		end
	end
	table.insert(Waves, {parts = parts, dir = origin.LookVector, speed = 62, age = 0, life = 0.5})
end

local function UpdateWaves(dt)
	for i = #Waves, 1, -1 do
		local w = Waves[i]
		w.age += dt
		if w.age >= w.life then
			for _, p in ipairs(w.parts) do p:Destroy() end
			table.remove(Waves, i)
		else
			local k = w.age / w.life
			for _, p in ipairs(w.parts) do
				p.CFrame += w.dir * w.speed * dt
				p.Transparency = math.clamp(0.1 + k * 0.95, 0, 1)
			end
		end
	end
end

------------------------------------------------------------------
-- 妖刀 (人の半分ほどの大きさ / 黒い刃 / 紫のオーラ)
------------------------------------------------------------------
local function BuildSword(parent)
	local m = Instance.new("Model")
	m.Name = "Youtou"
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

	-- 柄 (中心が握る位置)
	local handle = P(Vector3.new(0.18, 0.2, 0.8), CFrame.new(0, 0, 0), Color3.fromRGB(20, 16, 28), Enum.Material.SmoothPlastic)
	for _, z in ipairs({-0.27, -0.09, 0.09, 0.27}) do
		P(Vector3.new(0.2, 0.22, 0.05), CFrame.new(0, 0, z), Color3.fromRGB(70, 40, 110), Enum.Material.SmoothPlastic)
	end
	P(Vector3.new(0.22, 0.24, 0.1), CFrame.new(0, 0, 0.45), Color3.fromRGB(40, 28, 60), METAL, 0, 0.2)
	P(Vector3.new(0.12, 0.12, 0.04), CFrame.new(0, 0, 0.52), PURPLE, NEON)

	-- 鍔
	P(Vector3.new(0.06, 0.62, 0.62), CFrame.new(0, 0, -0.44) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(16, 12, 24), METAL, 0, 0.25, Enum.PartType.Cylinder)
	P(Vector3.new(0.03, 0.66, 0.66), CFrame.new(0, 0, -0.44) * CFrame.Angles(0, math.pi / 2, 0), PURPLE_D, NEON, 0.2, 0, Enum.PartType.Cylinder)

	-- 刃 (反りを付けて6+3分割)
	local cur = CFrame.new(0, 0, -0.5)
	local firstSeg, lastSeg
	for i = 1, 6 do
		cur = cur * CFrame.Angles(0.045, 0, 0)
		local h = 0.22 - i * 0.008
		local seg = P(Vector3.new(0.06, h, 0.25), cur * CFrame.new(0, 0, -0.125), BLADE, METAL, 0, 0.3)
		P(Vector3.new(0.02, 0.03, 0.25), cur * CFrame.new(0, -h / 2, -0.125), PURPLE, NEON, 0.35)
		if i == 1 then firstSeg = seg end
		lastSeg = seg
		cur = cur * CFrame.new(0, 0, -0.25)
	end
	for i = 1, 3 do
		cur = cur * CFrame.Angles(0.06, 0, 0)
		local h = 0.17 * (1 - i / 4)
		lastSeg = P(Vector3.new(0.05, h + 0.02, 0.13), cur * CFrame.new(0, 0, -0.065), BLADE, METAL, 0, 0.3)
		cur = cur * CFrame.new(0, 0, -0.13)
	end

	-- 紫のオーラ (刃を包む)
	local aura = P(Vector3.new(0.2, 0.46, 1.95), CFrame.new(0, 0.02, -1.5), PURPLE, NEON, 0.86)
	m.PrimaryPart = handle

	-- 光
	local light = Instance.new("PointLight")
	light.Color = PURPLE
	light.Range = 9
	light.Brightness = 1.4
	light.Parent = aura

	-- 横に流れるオーラ (煙)
	for _, face in ipairs({Enum.NormalId.Right, Enum.NormalId.Left}) do
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 120, 255)),
			ColorSequenceKeypoint.new(1, PURPLE_D),
		})
		pe.LightEmission = 1
		pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)})
		pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1)})
		pe.Lifetime = NumberRange.new(0.5, 0.9)
		pe.Rate = 38
		pe.Speed = NumberRange.new(2.5, 5)
		pe.EmissionDirection = face
		pe.SpreadAngle = Vector2.new(8, 8)
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		pe.Parent = aura
	end

	-- 軌跡
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -0.05)
	a0.Parent = lastSeg
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, 0.1)
	a1.Parent = firstSeg
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.3
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(210, 150, 255)),
		ColorSequenceKeypoint.new(0.5, PURPLE),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 10, 40)),
	})
	trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	trail.LightEmission = 0.8
	trail.Enabled = false
	trail.Parent = firstSeg

	m.Parent = parent

	-- 横流れのオーラ線
	local ribbons = {}
	for i = 1, 14 do
		local r = Instance.new("Part")
		r.Anchored = true
		r.CanCollide = false
		r.CanQuery = false
		r.CanTouch = false
		r.CastShadow = false
		r.Material = Enum.Material.Neon
		r.Color = (i % 3 == 0) and Color3.fromRGB(200, 140, 255) or PURPLE
		r.Transparency = 1
		r.Size = Vector3.new(0.025, 0.03, 0.6)
		r.Parent = parent
		table.insert(ribbons, {
			part = r, age = rng:NextNumber(0, 0.6), life = rng:NextNumber(0.4, 0.8),
			z = rng:NextNumber(-0.7, -2.5), y = rng:NextNumber(-0.18, 0.18),
			vx = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(2.5, 5),
			len = rng:NextNumber(0.4, 1.1),
		})
	end

	return {model = m, parts = parts, aura = aura, light = light, trail = trail, ribbons = ribbons, cf = CFrame.new()}
end

local function UpdateRibbons(sw, dt)
	for _, r in ipairs(sw.ribbons) do
		r.age += dt
		if r.age >= r.life then
			r.age = 0
			r.life = rng:NextNumber(0.4, 0.8)
			r.z = rng:NextNumber(-0.7, -2.5)
			r.y = rng:NextNumber(-0.18, 0.18)
			r.vx = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(2.5, 5)
			r.len = rng:NextNumber(0.4, 1.1)
		end
		local k = r.age / r.life
		r.part.CFrame = sw.cf * CFrame.new(r.vx * r.age, r.y, r.z)
		r.part.Size = Vector3.new(0.025, 0.03, r.len * (1 - k * 0.5))
		r.part.Transparency = 0.2 + 0.8 * k
	end
end

------------------------------------------------------------------
-- 後片付け
------------------------------------------------------------------
local function Teardown()
	local c = Ctx
	Running = false
	Ctx = nil
	if SlashBtns then
		pcall(function() SlashBtns.Visible = false end)
	end
	for _, d in ipairs(Shards) do pcall(function() d.part:Destroy() end) end
	Shards = {}
	for _, w in ipairs(Waves) do
		for _, p in ipairs(w.parts) do pcall(function() p:Destroy() end) end
	end
	Waves = {}
	if not c then return end
	for _, k in ipairs({"stepConn", "renderConn", "diedConn"}) do
		pcall(function() c[k]:Disconnect() end)
	end
	RestoreMotors(c.motors)
	pcall(function() c.hum.PlatformStand = false end)
	pcall(function() c.hum.AutoRotate = true end)
	pcall(function() c.hum.CameraOffset = Vector3.zero end)
	pcall(function() c.hrp.Anchored = false end)
	pcall(function() Workspace.CurrentCamera.FieldOfView = c.fov end)
	for _, inst in ipairs(c.charFx or {}) do
		pcall(function() inst:Destroy() end)
	end
	if c.Folder then pcall(function() c.Folder:Destroy() end) end
end

------------------------------------------------------------------
-- メイン演出
------------------------------------------------------------------
local function RunBody()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hum and hrp) or hum.Health <= 0 then return end

	Running = true

	local Folder = Instance.new("Folder")
	Folder.Name = "YoutouFx"
	Folder.Parent = Workspace

	Ctx = {char = char, hum = hum, hrp = hrp, Folder = Folder, charFx = {}, fov = Workspace.CurrentCamera.FieldOfView}

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char, Folder}

	local look = hrp.CFrame.LookVector
	local F = Vector3.new(look.X, 0, look.Z)
	if F.Magnitude < 0.01 then F = Vector3.new(0, 0, -1) end
	F = F.Unit
	local yawP = math.atan2(-F.X, -F.Z)

	local res0 = Workspace:Raycast(hrp.Position, Vector3.new(0, -60, 0), params)
	local gy = res0 and res0.Position.Y or (hrp.Position.Y - 3)
	local standOff = hrp.Position.Y - gy

	local swordXZ = hrp.Position + F * 4.4
	local res1 = Workspace:Raycast(Vector3.new(swordXZ.X, hrp.Position.Y + 8, swordXZ.Z), Vector3.new(0, -60, 0), params)
	local sy = res1 and res1.Position.Y or gy
	local groundPt = Vector3.new(swordXZ.X, sy, swordXZ.Z)

	local motors = CollectMotors(char)
	Ctx.motors = motors
	local hasKnee = motors.knR ~= nil

	local rHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local lHand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or hrp

	local function HandPoint(limb)
		if limb.Name:find(" ") then
			return (limb.CFrame * CFrame.new(0, -limb.Size.Y / 2 + 0.3, 0)).Position
		end
		return limb.Position
	end

	-- 状態
	local mode = "cine"            -- cine / free / slash
	local T = 0
	local basePos = Vector3.new(hrp.Position.X, gy, hrp.Position.Z)
	local yaw = yawP
	local State = {
		height = standOff, yOff = 0, crouch = 0, lean = 0, shake = 0,
		Rs = 0, Rsp = 0, Rel = 0, Ls = 0, Lsp = 0, Lel = 0,
		ik = nil, ikTarget = Vector3.zero, runK = 0, override = nil, busy = false,
		swordJit = 0, auraOn = 0,
	}
	local CROUCH_DROP = hasKnee and 1.0 or 0.3

	-- 妖刀
	local sw = BuildSword(Folder)
	local swordMode = "stuck"
	local stuckPos = groundPt + Vector3.new(0, 1.5, 0)
	local swordPos = stuckPos
	local swordDir = Vector3.new(0, -1, 0)
	local swordHint = F
	local swordRise = 0

	-- 地面の演出 (妖しい光と霧)
	local baseGlow = Instance.new("Part")
	baseGlow.Shape = Enum.PartType.Cylinder
	baseGlow.Material = Enum.Material.Neon
	baseGlow.Color = PURPLE
	baseGlow.Anchored = true
	baseGlow.CanCollide = false
	baseGlow.CanQuery = false
	baseGlow.CanTouch = false
	baseGlow.CastShadow = false
	baseGlow.Transparency = 0.6
	baseGlow.Size = Vector3.new(0.08, 3.4, 3.4)
	baseGlow.CFrame = CFrame.new(groundPt + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	baseGlow.Parent = Folder

	local sparkPart = Instance.new("Part")
	sparkPart.Anchored = true
	sparkPart.CanCollide = false
	sparkPart.CanQuery = false
	sparkPart.CanTouch = false
	sparkPart.Transparency = 1
	sparkPart.Size = Vector3.new(0.5, 0.5, 0.5)
	sparkPart.CFrame = CFrame.new(groundPt + Vector3.new(0, 0.3, 0))
	sparkPart.Parent = Folder
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(PURPLE_D)
	mist.LightEmission = 0.6
	mist.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1)})
	mist.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.5)})
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Rate = 10
	mist.Speed = NumberRange.new(0.5, 1.5)
	mist.SpreadAngle = Vector2.new(180, 20)
	mist.Parent = sparkPart
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(200, 140, 255))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)})
	sparks.Lifetime = NumberRange.new(0.4, 0.9)
	sparks.Speed = NumberRange.new(6, 14)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Rate = 0
	sparks.Parent = sparkPart

	-- オーラ / 赤い目 (刀を手にしてから有効)
	local hl = Instance.new("Highlight")
	hl.Adornee = char
	hl.FillColor = PURPLE
	hl.FillTransparency = 1
	hl.OutlineColor = CYAN
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
	table.insert(Ctx.charFx, hl)

	local function AuraEmitter(color, rate)
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(color)
		pe.LightEmission = 1
		pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1)})
		pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.2)})
		pe.Lifetime = NumberRange.new(0.8, 1.4)
		pe.Rate = rate
		pe.Speed = NumberRange.new(1, 3)
		pe.Acceleration = Vector3.new(0, 4, 0)
		pe.SpreadAngle = Vector2.new(25, 25)
		pe.RotSpeed = NumberRange.new(-60, 60)
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		pe.Enabled = false
		pe.Parent = torso
		table.insert(Ctx.charFx, pe)
		return pe
	end
	local auraC = AuraEmitter(CYAN, 38)
	local auraP = AuraEmitter(PURPLE, 38)

	local glints = Instance.new("ParticleEmitter")
	glints.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, CYAN), ColorSequenceKeypoint.new(1, PURPLE)})
	glints.LightEmission = 1
	glints.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
	glints.Lifetime = NumberRange.new(0.5, 1.1)
	glints.Rate = 30
	glints.Speed = NumberRange.new(2, 6)
	glints.SpreadAngle = Vector2.new(180, 180)
	glints.Shape = Enum.ParticleEmitterShape.Box
	glints.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	glints.Enabled = false
	glints.Parent = torso
	table.insert(Ctx.charFx, glints)

	local auraLight = Instance.new("PointLight")
	auraLight.Color = Color3.fromRGB(140, 150, 255)
	auraLight.Range = 14
	auraLight.Brightness = 0
	auraLight.Parent = torso
	table.insert(Ctx.charFx, auraLight)

	local eyes = {}
	if head then
		for _, sx in ipairs({-1, 1}) do
			local e = Instance.new("Part")
			e.Material = Enum.Material.Neon
			e.Color = RED
			e.Size = Vector3.new(0.26, 0.1, 0.04)
			e.CanCollide = false
			e.CanQuery = false
			e.CanTouch = false
			e.Massless = true
			e.CastShadow = false
			e.Transparency = 1
			e.CFrame = head.CFrame * CFrame.new(sx * 0.2, 0.05, -0.62) * CFrame.Angles(0, 0, sx * -0.22)
			e.Parent = Folder
			local w = Instance.new("WeldConstraint")
			w.Part0 = head
			w.Part1 = e
			w.Parent = e
			local l = Instance.new("PointLight")
			l.Color = RED
			l.Range = 5
			l.Brightness = 0
			l.Parent = e
			table.insert(eyes, {part = e, light = l})
		end
	end

	local function SetAura(k)
		State.auraOn = k
		auraC.Enabled = k > 0.5
		auraP.Enabled = k > 0.5
		glints.Enabled = k > 0.5
		hl.FillTransparency = 1 - 0.16 * k
		hl.OutlineTransparency = 1 - 0.85 * k
		auraLight.Brightness = 1.2 * k
		for _, e in ipairs(eyes) do
			e.part.Transparency = 1 - k
			e.light.Brightness = 2.2 * k
		end
	end

	------------------------------------------------------------
	-- 毎フレームのポーズ (アニメーション後)
	------------------------------------------------------------
	local standPos = basePos
	local stepConn = RunService.Stepped:Connect(function(_, dt)
		if not Ctx then return end
		T += dt

		if mode == "cine" then
			if State.ik and rHand and lHand then
				local Hm = (State.ik == "both") and ((HandPoint(rHand) + HandPoint(lHand)) / 2) or HandPoint(rHand)
				local gain = math.min(dt * 12, 1)
				basePos += Vector3.new(State.ikTarget.X - Hm.X, 0, State.ikTarget.Z - Hm.Z) * gain
				local flat = Vector3.new(basePos.X - standPos.X, 0, basePos.Z - standPos.Z)
				if flat.Magnitude > 2.4 then
					flat = flat.Unit * 2.4
					basePos = Vector3.new(standPos.X + flat.X, gy, standPos.Z + flat.Z)
				end
				State.yOff = math.clamp(State.yOff + (State.ikTarget.Y - Hm.Y) * math.min(dt * 8, 1), -0.7, 0.7)
			end
			local j = Vector3.new(math.sin(T * 43), math.sin(T * 37 + 1), math.cos(T * 41)) * State.shake
			hrp.CFrame = CFrame.new(basePos + Vector3.new(0, State.height + State.yOff, 0) + j) * CFrame.Angles(0, yaw, 0)

			for _, k in ipairs({"shR", "shL", "elR", "elL", "waist", "root"}) do
				if motors[k] then motors[k].m.Transform = CFrame.new() end
			end
			Pose(motors.shR, State.Rs, 0, State.Rsp)
			Pose(motors.shL, State.Ls, 0, State.Lsp)
			Pose(motors.elR, State.Rel, 0, 0)
			Pose(motors.elL, State.Lel, 0, 0)
			local c = State.crouch
			Pose(motors.hipR, c * 1.0, 0, c * 0.2)
			Pose(motors.hipL, c * 1.0, 0, -c * 0.2)
			Pose(motors.knR, -c * 1.8, 0, 0)
			Pose(motors.knL, -c * 1.8, 0, 0)
			if motors.waist then
				Pose(motors.waist, -State.lean * 0.7, 0, 0)
				Pose(motors.root, -State.lean * 0.3, 0, 0)
			else
				Pose(motors.root, -State.lean, 0, 0)
			end
		else
			-- 走り / 斬撃: 右腕は刀を持つので上書き、他はアニメーションのまま
			local vel = hrp.AssemblyLinearVelocity
			local sp = Vector2.new(vel.X, vel.Z).Magnitude
			State.runK += (math.clamp(sp / 14, 0, 1) - State.runK) * math.min(dt * 6, 1)
			local o = State.override
			local Rs, Rsp, Rel = -0.5 - 0.15 * State.runK, 0.1, 0.5
			local lean = 0.5 * State.runK
			local twist = 0
			local Ls, Lsp, Lel
			if o then
				Rs, Rsp, Rel = o.S, o.spread, o.elbow
				lean = o.lean
				twist = o.twist or 0
				Ls, Lsp, Lel = o.Ls, o.Lsp, o.Lel
			end
			for _, k in ipairs({"shR", "elR"}) do
				if motors[k] then motors[k].m.Transform = CFrame.new() end
			end
			Pose(motors.shR, Rs, 0, Rsp)
			Pose(motors.elR, Rel, 0, 0)
			if Ls then
				for _, k in ipairs({"shL", "elL"}) do
					if motors[k] then motors[k].m.Transform = CFrame.new() end
				end
				Pose(motors.shL, Ls, 0, Lsp)
				Pose(motors.elL, Lel or 0.2, 0, 0)
			else
				RestoreMotors({motors.shL, motors.elL})
			end
			if o and o.crouch then
				local c = o.crouch
				Pose(motors.hipR, c * 0.8, 0, c * 0.25)
				Pose(motors.hipL, c * 0.8, 0, -c * 0.25)
				Pose(motors.knR, -c * 1.4, 0, 0)
				Pose(motors.knL, -c * 1.4, 0, 0)
			else
				RestoreMotors({motors.hipR, motors.hipL, motors.knR, motors.knL})
			end
			if motors.waist then
				Pose(motors.waist, -lean * 0.7, twist, 0)
				Pose(motors.root, -lean * 0.3, 0, 0)
			else
				Pose(motors.root, -lean, twist, 0)
			end
		end
	end)
	Ctx.stepConn = stepConn

	------------------------------------------------------------
	-- 毎フレームの描画 (刀の位置 / 地面の光)
	------------------------------------------------------------
	local renderConn = RunService.RenderStepped:Connect(function(dt)
		if not Ctx then return end
		dt = math.min(dt, 1 / 20)
		UpdateShards(dt)
		UpdateWaves(dt)

		baseGlow.Transparency = 0.55 + 0.2 * math.sin(T * 3)

		local cf
		if swordMode == "hand" and rHand then
			local gp = HandPoint(rHand)
			local armDir = -rHand.CFrame.UpVector
			cf = CFrame.lookAt(gp, gp + armDir, rHand.CFrame.LookVector)
		else
			local jit = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * State.swordJit
			local d = swordDir
			local upv = (math.abs(d.Y) > 0.95) and swordHint or Vector3.yAxis
			cf = CFrame.lookAt(swordPos + jit + Vector3.new(0, swordRise, 0), swordPos + jit + Vector3.new(0, swordRise, 0) + d, upv)
		end
		sw.cf = cf
		sw.model:PivotTo(cf)
		UpdateRibbons(sw, dt)

		if mode ~= "cine" then
			Workspace.CurrentCamera.FieldOfView = Ctx.fov + 8 * State.runK
		end
	end)
	Ctx.renderConn = renderConn

	Ctx.diedConn = hum.Died:Connect(function()
		Teardown()
	end)

	------------------------------------------------------------
	-- 演出 1: 刀の前へ歩く
	------------------------------------------------------------
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.Anchored = true
	hum.PlatformStand = true
	hum.AutoRotate = false
	local startPos = basePos
	standPos = groundPt - F * 1.9
	standPos = Vector3.new(standPos.X, gy, standPos.Z)

	local gripPoint = stuckPos + Vector3.new(0, 0.05, 0)

	Animate(1.1, function(a)
		local e = Ease(a)
		basePos = startPos:Lerp(standPos, e)
		State.crouch = 0.85 * e
		State.height = standOff - CROUCH_DROP * State.crouch
		State.Rs = 0.8 * e
		State.Rel = 0.35 * e
		State.Ls = -0.15 * e
		State.Lsp = -0.3 * e
	end)

	------------------------------------------------------------
	-- 演出 2: 片手で3秒抜こうとするが抜けない
	------------------------------------------------------------
	State.ik = "R"
	State.ikTarget = gripPoint
	local sparkT = 0
	local t0 = os.clock()
	Animate(3.0, function(a)
		local e = Ease(math.clamp((a - 0.12) / 0.88, 0, 1))
		State.lean = -0.3 * e
		State.shake = 0.012 + 0.055 * e
		State.swordJit = 0.01 + 0.04 * e
		State.Rs = 0.9 + 0.1 * math.sin(T * 14) * e
		sparkT += 1 / 60
		if e > 0.15 and sparkT > 0.22 then
			sparkT = 0
			sparks:Emit(math.floor(4 + 10 * e))
			ShakeCam(0.05 + 0.12 * e, 0.15)
		end
		mist.Rate = 10 + 40 * e
		baseGlow.Size = Vector3.new(0.08, 3.4 + 1.2 * e, 3.4 + 1.2 * e)
	end)

	-- 手が滑って後ろによろめく
	State.ik = nil
	State.swordJit = 0.07
	Burst(groundPt + Vector3.new(0, 1.8, 0), 40, Color3.fromRGB(200, 140, 255), 26)
	ShakeCam(0.4, 0.35)
	local recoilFrom = basePos
	Animate(0.4, function(a)
		local e = 1 - (1 - a) ^ 2
		basePos = recoilFrom - F * 1.0 * e
		State.lean = -0.3 - 0.35 * e
		State.Rs = 1.0 + 1.0 * e
		State.Rel = 0.35 + 0.4 * e
		State.shake = 0.04 * (1 - a)
		State.swordJit = 0.07 * (1 - a * 0.7)
	end)
	State.swordJit = 0.012
	-- 息を整える
	Animate(0.9, function(a)
		State.lean = -0.1 + 0.05 * math.sin(a * math.pi * 3)
		State.Rs = 2.0 - 1.1 * Ease(a)
		State.Rel = 0.5
		State.shake = 0
	end)

	------------------------------------------------------------
	-- 演出 3: 両手で抜く
	------------------------------------------------------------
	local recoverFrom = basePos
	Animate(0.7, function(a)
		local e = Ease(a)
		basePos = recoverFrom:Lerp(standPos, e)
		State.crouch = 0.85 + 0.15 * e
		State.height = standOff - CROUCH_DROP * State.crouch
		State.Rs = 0.9
		State.Ls = 0.9
		State.Rsp = -0.45 * e
		State.Lsp = 0.45 * e
		State.Rel = 0.35
		State.Lel = 0.35
		State.lean = 0
	end)
	State.ik = "both"
	State.ikTarget = gripPoint

	local function RiseAt(t)
		-- 少しずつ、引っかかりながら上がっていく
		if t < 0.9 then return 0.0 end
		if t < 1.1 then return 0.12 * Ease((t - 0.9) / 0.2) end
		if t < 1.5 then return 0.12 - 0.1 * Ease((t - 1.1) / 0.4) end
		if t < 1.8 then return 0.02 + 0.25 * Ease((t - 1.5) / 0.3) end
		if t < 2.2 then return 0.27 - 0.2 * Ease((t - 1.8) / 0.4) end
		if t < 2.9 then return 0.07 + 0.45 * Ease((t - 2.2) / 0.7) end
		return 0.52
	end

	local cracksMade = false
	sparkT = 0
	Animate(3.2, function(a)
		local t = a * 3.2
		local e = Ease(a)
		State.lean = -0.25 * e
		State.shake = 0.02 + 0.1 * e
		State.swordJit = 0.02 + 0.045 * e
		swordRise = RiseAt(t)
		State.ikTarget = gripPoint + Vector3.new(0, swordRise, 0)
		sparkT += 1 / 60
		if sparkT > 0.16 then
			sparkT = 0
			sparks:Emit(math.floor(6 + 14 * e))
			ShakeCam(0.08 + 0.2 * e, 0.12)
		end
		mist.Rate = 30 + 70 * e
		baseGlow.Size = Vector3.new(0.08, 4.6 + 2.5 * e, 4.6 + 2.5 * e)
		baseGlow.Color = PURPLE:Lerp(Color3.fromRGB(230, 170, 255), e)
		if t > 1.6 and not cracksMade then
			cracksMade = true
			for i = 1, 8 do
				local ang = i / 8 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
				local len = rng:NextNumber(3, 6)
				local c = Instance.new("Part")
				c.Anchored = true
				c.CanCollide = false
				c.CanQuery = false
				c.CanTouch = false
				c.CastShadow = false
				c.Material = Enum.Material.Neon
				c.Color = PURPLE
				c.Size = Vector3.new(0.12, 0.05, len)
				local dirv = Vector3.new(math.cos(ang), 0, math.sin(ang))
				c.CFrame = CFrame.lookAt(groundPt + Vector3.new(0, 0.08, 0) + dirv * len / 2, groundPt + Vector3.new(0, 0.08, 0) + dirv * len)
				c.Parent = Folder
			end
			Ring(groundPt + Vector3.new(0, 0.1, 0), PURPLE, 2, 14, 0.8, 0.3)
		end
	end)

	------------------------------------------------------------
	-- 演出 4: 抜けた！ 宙を舞い、右手に収まる
	------------------------------------------------------------
	State.ik = nil
	State.swordJit = 0
	ScreenFlash(Color3.fromRGB(190, 150, 255), 0.35)
	ShakeCam(1.0, 0.5)
	Ring(groundPt + Vector3.new(0, 0.1, 0), CYAN, 2, 22, 0.7, 0.1)
	Ring(groundPt + Vector3.new(0, 0.2, 0), PURPLE, 2, 30, 1.0, 0.2)
	Burst(groundPt + Vector3.new(0, 1.2, 0), 90, Color3.fromRGB(190, 120, 255), 40)
	SpawnShards(groundPt + Vector3.new(0, 0.4, 0), 26, 34)
	mist.Rate = 10

	local baseBack = basePos
	local liftStart = swordPos + Vector3.new(0, swordRise, 0)
	swordRise = 0
	swordPos = liftStart
	local spinAng = 0
	Animate(1.0, function(a)
		-- 体は反動でよろめく
		local e = 1 - (1 - math.min(a * 2, 1)) ^ 2
		basePos = baseBack - F * 0.9 * e + F * 0.9 * Ease(math.clamp((a - 0.5) / 0.5, 0, 1)) * 0.6
		State.lean = -0.5 * (1 - a) - 0.05
		State.Rs = 2.3 * (1 - Ease(a)) + 0.9 * Ease(a)
		State.Ls = 1.8 * (1 - Ease(a))
		State.Lsp = 0.45 * (1 - a)
		State.Rsp = -0.45 * (1 - a)
		State.crouch = math.max(1 - a * 1.4, 0)
		State.height = standOff - CROUCH_DROP * State.crouch
		State.shake = 0.1 * (1 - a)
		-- 刀は宙を舞う
		local up = math.sin(a * math.pi) * 5.5
		local fromHand = rHand and HandPoint(rHand) or liftStart
		local k = Ease(math.clamp((a - 0.45) / 0.55, 0, 1))
		local arc = liftStart:Lerp(fromHand, k) + Vector3.new(0, up, 0)
		spinAng += 14 / 60
		swordPos = arc
		local d = Vector3.new(math.sin(spinAng) * 0.8, -math.cos(spinAng * 0.5) + 0.2, math.cos(spinAng) * 0.8)
		swordDir = d.Unit
		swordHint = F
	end)
	-- 右手でキャッチ
	swordMode = "hand"
	Burst(rHand and HandPoint(rHand) or hrp.Position, 40, CYAN, 22)
	ShakeCam(0.3, 0.25)

	------------------------------------------------------------
	-- 演出 5: オーラが吹き上がり、目が赤く光る
	------------------------------------------------------------
	SetAura(1)
	auraC:Emit(60)
	auraP:Emit(60)
	Ring(Vector3.new(hrp.Position.X, gy + 0.1, hrp.Position.Z), CYAN, 2, 26, 0.9, 0.15)
	Ring(Vector3.new(hrp.Position.X, gy + 0.15, hrp.Position.Z), PURPLE, 2, 34, 1.2, 0.25)
	ScreenFlash(Color3.fromRGB(150, 230, 255), 0.2)

	Animate(0.9, function(a)
		local e = Ease(a)
		State.Rs = 0.9 + 1.6 * e   -- 刀を天に掲げる
		State.Rsp = 0.2 * e
		State.Rel = 0.35 + 0.2 * e
		State.Ls = 0.4 * (1 - a)
		State.lean = -0.2 * e
		State.shake = 0.03
	end)
	Animate(0.6, function(a)
		local e = Ease(a)
		State.Rs = 2.5 - 3.0 * e   -- 構えに戻る
		State.Rel = 0.55 - 0.05 * e
		State.lean = -0.2 + 0.2 * e
		State.shake = 0.03 * (1 - a)
	end)

	------------------------------------------------------------
	-- 演出 6: 操作を返す → 走れる / 斬れる
	------------------------------------------------------------
	hrp.Anchored = false
	hum.PlatformStand = false
	hum.AutoRotate = true
	hrp.AssemblyLinearVelocity = Vector3.zero
	pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
	mode = "free"
	State.ik = nil
	State.shake = 0
	State.crouch = 0
	RestoreMotors({motors.shL, motors.elL, motors.hipR, motors.hipL, motors.knR, motors.knL})
	if SlashBtns then SlashBtns.Visible = true end

	------------------------------------------------------------
	-- 斬1: 振りかざして斬る
	------------------------------------------------------------
	local function Slash1()
		if mode ~= "free" or State.busy then return end
		State.busy = true
		mode = "slash"
		local oldWS = hum.WalkSpeed
		hum.WalkSpeed = math.min(oldWS, 6)
		sw.trail.Enabled = true
		local cur = {S = -0.5 - 0.15 * State.runK, lean = 0.5 * State.runK}
		State.override = {S = cur.S, spread = 0.1, elbow = 0.5, lean = cur.lean}
		local o = State.override

		-- 振りかぶる
		Animate(0.24, function(a)
			local e = Ease(a)
			o.S = cur.S + (3.0 - cur.S) * e
			o.elbow = 0.5 - 0.2 * e
			o.lean = cur.lean + (-0.2 - cur.lean) * e
			o.Ls = 1.2 * e
			o.Lsp = 0.4 * e
			o.Lel = 0.3
		end)
		Wait(0.04)

		-- 斬り下ろす
		local look0 = hrp.CFrame.LookVector
		local fwd = Vector3.new(look0.X, 0, look0.Z)
		if fwd.Magnitude > 0.01 then fwd = fwd.Unit end
		hrp.AssemblyLinearVelocity = Vector3.new(fwd.X * 26, hrp.AssemblyLinearVelocity.Y, fwd.Z * 26)
		local waved = false
		Animate(0.15, function(a)
			local e = a * a
			o.S = 3.0 - 2.35 * e
			o.elbow = 0.2 + 0.1 * e
			o.lean = -0.2 + 0.7 * e
			o.Ls = 1.2 * (1 - e) - 0.3 * e
			if a > 0.45 and not waved then
				waved = true
				local origin = CFrame.lookAt(hrp.Position + fwd * 2.5 + Vector3.new(0, 0.6, 0), hrp.Position + fwd * 10 + Vector3.new(0, 0.6, 0))
				SpawnCrescent(origin)
				Burst(hrp.Position + fwd * 3 + Vector3.new(0, 1.5, 0), 30, PURPLE, 26)
				ShakeCam(0.25, 0.2)
			end
		end)

		-- 残心
		Animate(0.3, function(a)
			local e = Ease(a)
			o.S = 0.65 + 0.25 * e
			o.lean = 0.5 - 0.25 * e
		end)
		sw.trail.Enabled = false
		Animate(0.3, function(a)
			local e = Ease(a)
			local runS = -0.5 - 0.15 * State.runK
			o.S = 0.9 + (runS - 0.9) * e
			o.elbow = 0.5
			o.lean = 0.25 + (0.5 * State.runK - 0.25) * e
			o.Ls = nil
		end)
		State.override = nil
		hum.WalkSpeed = oldWS
		mode = "free"
		State.busy = false
	end

	------------------------------------------------------------
	-- 斬2: 回転しながら前進して横に斬る
	------------------------------------------------------------
	local function Slash2()
		if mode ~= "free" or State.busy then return end
		State.busy = true
		mode = "slash"
		local oldWS = hum.WalkSpeed
		local look0 = hrp.CFrame.LookVector
		local fwd = Vector3.new(look0.X, 0, look0.Z)
		if fwd.Magnitude < 0.01 then fwd = F end
		fwd = fwd.Unit
		local yaw0 = math.atan2(-fwd.X, -fwd.Z)
		State.override = {S = -0.6, spread = 0.1, elbow = 0.5, lean = 0.3}
		local o = State.override

		-- 体をひねって溜める
		hum.AutoRotate = false
		Animate(0.2, function(a)
			local e = Ease(a)
			o.S = -0.6 + 0.6 * e
			o.spread = 0.1 + 1.0 * e
			o.elbow = 0.5 - 0.4 * e
			o.lean = 0.3 - 0.1 * e
			o.twist = 0.8 * e
			o.crouch = 0.5 * e
			o.Ls = 0.0
			o.Lsp = -0.9 * e
			o.Lel = 0.2
		end)

		-- 回転しながら前進
		hum.PlatformStand = true
		sw.trail.Enabled = true
		local ringMade = false
		local lastT = os.clock()
		Animate(0.75, function(a)
			local now = os.clock()
			local dt = math.max(now - lastT, 1 / 120)
			lastT = now
			local e = a < 0.5 and (2 * a * a) or (1 - (-2 * a + 2) ^ 2 / 2)
			local ang = yaw0 + math.pi * 2.2 * e
			local pos = hrp.Position
			hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, ang, 0)
			local sp = 30 * (1 - a * 0.6)
			hrp.AssemblyLinearVelocity = Vector3.new(fwd.X * sp, hrp.AssemblyLinearVelocity.Y, fwd.Z * sp)
			hrp.AssemblyAngularVelocity = Vector3.zero
			o.S = 0.0
			o.spread = 1.2
			o.elbow = 0.1
			o.lean = 0.2
			o.twist = 0
			o.crouch = 0.4
			o.Lsp = -1.0
			if a > 0.1 and not ringMade then
				ringMade = true
				local c = hrp.Position
				Ring(c + Vector3.new(0, 0.3, 0), PURPLE, 3, 22, 0.6, 0.15)
				Ring(c + Vector3.new(0, 1.4, 0), CYAN, 3, 18, 0.6, 0.2)
				Burst(c + Vector3.new(0, 1.5, 0), 50, PURPLE, 34)
				ShakeCam(0.3, 0.4)
			end
			if rng:NextNumber() < 0.25 then
				Burst(hrp.Position + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(0.5, 2.5), rng:NextNumber(-3, 3)), 6, PURPLE, 18)
			end
		end)

		-- 着地・立て直し
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw0, 0)
		hrp.AssemblyAngularVelocity = Vector3.zero
		hum.PlatformStand = false
		hum.AutoRotate = true
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
		sw.trail.Enabled = false
		Animate(0.35, function(a)
			local e = Ease(a)
			o.S = 0.0 + (-0.6 - 0.0) * e
			o.spread = 1.2 + (0.1 - 1.2) * e
			o.elbow = 0.1 + 0.4 * e
			o.lean = 0.2 + (0.5 * State.runK - 0.2) * e
			o.crouch = 0.4 * (1 - e)
			o.Lsp = -1.0 * (1 - e)
		end)
		State.override = nil
		hum.WalkSpeed = oldWS
		mode = "free"
		State.busy = false
	end

	Ctx.slash1 = Slash1
	Ctx.slash2 = Slash2
end

------------------------------------------------------------------
-- Gui (開: 320x200 / 閉: 56x56 / オブシディアン)
------------------------------------------------------------------
local OBS_BG = Color3.fromRGB(8, 8, 12)
local OBS_BTN = Color3.fromRGB(20, 18, 28)
local OBS_STROKE = Color3.fromRGB(110, 70, 190)
local OBS_TEXT = Color3.fromRGB(210, 200, 235)

local gui = Instance.new("ScreenGui")
gui.Name = "YoutouGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999

local parented = pcall(function()
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)
if not parented or not gui.Parent then
	pcall(function()
		gui.Parent = game:GetService("CoreGui")
	end)
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

local function MakeButton(parent, text, size, pos, textSize)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = OBS_BTN
	b.BackgroundTransparency = 0.05
	b.Text = text
	b.TextColor3 = OBS_TEXT
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = textSize or 18
	b.AutoButtonColor = true
	b.Parent = parent
	Round(b, 10)
	Stroke(b, OBS_STROKE, 1.2)
	return b
end

local EXPANDED = UDim2.fromOffset(320, 200)
local COLLAPSED = UDim2.fromOffset(56, 56)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = EXPANDED
panel.Position = UDim2.new(0, 8, 0.12, 0)
panel.BackgroundColor3 = OBS_BG
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = gui
Round(panel, 12)
Stroke(panel, OBS_STROKE, 1.8)

local toggle = MakeButton(panel, "≡", UDim2.fromOffset(44, 44), UDim2.fromOffset(6, 6), 26)

local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, 0, 1, 0)
content.BackgroundTransparency = 1
content.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 44)
title.Position = UDim2.fromOffset(60, 6)
title.BackgroundTransparency = 1
title.Text = "妖刀"
title.TextColor3 = OBS_TEXT
title.Font = Enum.Font.SourceSansBold
title.TextSize = 24
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = content

local startBtn = MakeButton(content, "発動", UDim2.fromOffset(142, 52), UDim2.fromOffset(14, 66), 24)
local resetBtn = MakeButton(content, "解除", UDim2.fromOffset(142, 52), UDim2.fromOffset(164, 66), 24)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -28, 0, 56)
hint.Position = UDim2.fromOffset(14, 130)
hint.BackgroundTransparency = 1
hint.Text = "発動 → 妖刀を抜く → 走れる\n右側の「斬1」「斬2」で斬撃"
hint.TextColor3 = Color3.fromRGB(150, 140, 175)
hint.Font = Enum.Font.SourceSans
hint.TextSize = 16
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top
hint.Parent = content

local open = true
toggle.Activated:Connect(function()
	open = not open
	if open then
		content.Visible = true
		TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = EXPANDED}):Play()
		toggle.Text = "≡"
	else
		TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = COLLAPSED}):Play()
		task.delay(0.2, function()
			if not open then content.Visible = false end
		end)
		toggle.Text = "▣"
	end
end)

local dragging = false
local dragStart, startPos
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = panel.Position
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
		panel.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

-- 斬ボタン (抜刀後に表示)
SlashBtns = Instance.new("Frame")
SlashBtns.Name = "SlashButtons"
SlashBtns.Size = UDim2.fromScale(1, 1)
SlashBtns.BackgroundTransparency = 1
SlashBtns.Visible = false
SlashBtns.Parent = gui

local function SlashButton(text, yScale)
	local b = MakeButton(SlashBtns, text, UDim2.fromOffset(84, 84), UDim2.new(1, -18, yScale, 0), 22)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.BackgroundColor3 = Color3.fromRGB(28, 16, 46)
	Stroke(b, Color3.fromRGB(90, 230, 255), 1.4)
	return b
end
local slash1Btn = SlashButton("斬1", 0.4)
local slash2Btn = SlashButton("斬2", 0.62)

slash1Btn.Activated:Connect(function()
	if Ctx and Ctx.slash1 then
		task.spawn(function() pcall(Ctx.slash1) end)
	end
end)
slash2Btn.Activated:Connect(function()
	if Ctx and Ctx.slash2 then
		task.spawn(function() pcall(Ctx.slash2) end)
	end
end)

startBtn.Activated:Connect(function()
	if Running then return end
	task.spawn(function()
		local ok = pcall(RunBody)
		if not ok then
			Teardown()
		end
	end)
end)

resetBtn.Activated:Connect(function()
	Teardown()
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
	env.YoutouCleanup = nil
end

env.YoutouCleanup = FullCleanup
