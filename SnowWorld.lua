--[[
	雪の世界 (Snow World)  - モバイル対応
	・降雪: 4層のパーティクル(細かい雪 / 大きめの雪 / きらめく結晶 / カメラの近くを舞う大粒)
	        風の揺らぎ、屋内では自動で止まる、重いときは自動で量を調整
	・景色: 空(スカイボックス 4604073339) / 明るい雪空のライティング / 霞 / 光のにじみ / 地面を雪色に
	・足音: 雪を踏むたびに 139933585379767 が鳴る + 足跡 + 雪けむり
	・雪玉: UIの「雪玉」をONにすると「投げる」ボタンが出る
	        しゃがんで雪を集める → 雪玉が育つ → 投げる → 当たると 9119310905 が鳴って雪が飛び散る
	・雪だるま: ときどき周りに出現(帽子 / マフラー / 人参の鼻 / 炭の目)
	・UI: 白い背景がゆっくり動き、雪が流れる。閉じると小さな雪だるま、タップで大きく開く
	※ すべて自分の画面だけの演出です (他のプレイヤーには見えません / 影響もしません)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")
local ContentProvider = game:GetService("ContentProvider")

local LP = Players.LocalPlayer
local env = getgenv()

local function Notify(title, text, duration)
	StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = duration})
end

if env.SnowWorldCleanup then pcall(env.SnowWorldCleanup) end

local rng = Random.new()
local IDS = {
	sky = "rbxassetid://4604073339",
	step = "rbxassetid://139933585379767",
	hit = "rbxassetid://9119310905",
}
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- 設定 (UIと連動)
local S = {
	snow = true, density = 1.0, wind = 0.35,
	scene = true, ground = true,
	steps = true, volume = 0.65, prints = true,
	ball = false,
	snowmen = true, freq = 1.0,
}

local Conns, Cleanups = {}, {}
local function Track(c) table.insert(Conns, c) return c end
local function OnCleanup(fn) table.insert(Cleanups, fn) end

local Folder = Instance.new("Folder")
Folder.Name = "SnowWorldFx"
Folder.Parent = Workspace
OnCleanup(function() Folder:Destroy() end)

local function Cam() return Workspace.CurrentCamera end
local function CharParts()
	local c = LP.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return c, h, r
end
local function Params()
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = {LP.Character, Folder}
	return p
end

local function Lerp(a, b, t) return a + (b - a) * t end
local function Ease(t) return t * t * (3 - 2 * t) end

------------------------------------------------------------------
-- 1) 景色 (空 / ライティング / 霞 / 後処理 / 地面)
------------------------------------------------------------------
local Env = {on = false, saved = {}, created = {}, oldSkies = {}, tOrig = {}, parts = {}, partSet = {}}

local function SetProp(inst, prop, value)
	pcall(function()
		table.insert(Env.saved, {inst = inst, prop = prop, value = inst[prop]})
		inst[prop] = value
	end)
end

local SNOW_COLOR = Color3.fromRGB(238, 244, 252)
local TERRAIN_MATS = {
	Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Sand, Enum.Material.Ground, Enum.Material.Mud,
	Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Sandstone, Enum.Material.Asphalt, Enum.Material.Pavement,
	Enum.Material.Cobblestone, Enum.Material.Limestone, Enum.Material.Basalt, Enum.Material.Salt, Enum.Material.Concrete,
}

local function ScanGround()
	if not Env.on or not S.ground then return end
	local _, _, r = CharParts()
	local center = r and r.Position or Vector3.zero
	local count = 0
	for _, p in ipairs(Workspace:GetDescendants()) do
		if p:IsA("BasePart") and not Env.partSet[p] and not p:IsDescendantOf(Folder) and p.Size.X * p.Size.Z > 500
			and p.Size.Y < 24 and p.Transparency < 0.9 and not p:FindFirstAncestorOfClass("Model") ~= nil == false then
			-- (キャラクターのパーツは対象外)
			local model = p:FindFirstAncestorOfClass("Model")
			if not (model and model:FindFirstChildOfClass("Humanoid")) and (p.Position - center).Magnitude < 600 then
				Env.partSet[p] = true
				table.insert(Env.parts, {part = p, color = p.Color, material = p.Material})
				p.Color = SNOW_COLOR
				p.Material = Enum.Material.Snow
				count += 1
				if count > 250 then break end
			end
		end
	end
end

local function RestoreGround()
	for _, e in ipairs(Env.parts) do
		pcall(function()
			if e.part.Parent then
				e.part.Color = e.color
				e.part.Material = e.material
			end
		end)
	end
	Env.parts, Env.partSet = {}, {}
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		for m, c in pairs(Env.tOrig) do pcall(function() terrain:SetMaterialColor(m, c) end) end
	end
	Env.tOrig = {}
end

local function ApplyTerrain()
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then return end
	for _, m in ipairs(TERRAIN_MATS) do
		pcall(function()
			if not Env.tOrig[m] then Env.tOrig[m] = terrain:GetMaterialColor(m) end
			terrain:SetMaterialColor(m, SNOW_COLOR)
		end)
	end
	SetProp(terrain, "Decoration", false)
end

local function EnvApply()
	if Env.on then return end
	Env.on = true

	-- ライティング: 明るく青白い雪空
	SetProp(Lighting, "Brightness", 3.2)
	SetProp(Lighting, "ClockTime", 13.5)
	SetProp(Lighting, "Ambient", Color3.fromRGB(125, 146, 178))
	SetProp(Lighting, "OutdoorAmbient", Color3.fromRGB(152, 172, 204))
	SetProp(Lighting, "ColorShift_Top", Color3.fromRGB(255, 250, 244))
	SetProp(Lighting, "EnvironmentDiffuseScale", 1)
	SetProp(Lighting, "EnvironmentSpecularScale", 0.6)
	SetProp(Lighting, "ExposureCompensation", 0.2)
	SetProp(Lighting, "FogColor", Color3.fromRGB(214, 228, 244))
	SetProp(Lighting, "FogStart", 80)
	SetProp(Lighting, "FogEnd", 2600)

	-- 空 (スカイボックス 4604073339 を6面すべてに)
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("Sky") then
			table.insert(Env.oldSkies, c)
			c.Parent = nil
		end
	end
	local sky = Instance.new("Sky")
	sky.Name = "SnowSky"
	for _, f in ipairs({"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"}) do
		sky[f] = IDS.sky
	end
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	sky.Parent = Lighting
	table.insert(Env.created, sky)

	-- 霞
	local at = Lighting:FindFirstChildOfClass("Atmosphere")
	if at then
		SetProp(at, "Density", 0.34); SetProp(at, "Offset", 0.12)
		SetProp(at, "Color", Color3.fromRGB(214, 228, 244)); SetProp(at, "Decay", Color3.fromRGB(190, 210, 236))
		SetProp(at, "Glare", 0.1); SetProp(at, "Haze", 1.4)
	else
		local a = Instance.new("Atmosphere")
		a.Density = 0.34; a.Offset = 0.12; a.Color = Color3.fromRGB(214, 228, 244)
		a.Decay = Color3.fromRGB(190, 210, 236); a.Glare = 0.1; a.Haze = 1.4
		a.Parent = Lighting
		table.insert(Env.created, a)
	end

	-- 後処理 (色味 / きらめきのにじみ)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SnowCC"; cc.Brightness = 0.03; cc.Contrast = 0.1; cc.Saturation = -0.06
	cc.TintColor = Color3.fromRGB(234, 244, 255); cc.Parent = Lighting
	table.insert(Env.created, cc)
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "SnowBloom"; bloom.Intensity = 0.45; bloom.Size = 22; bloom.Threshold = 0.95; bloom.Parent = Lighting
	table.insert(Env.created, bloom)
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "SnowRays"; rays.Intensity = 0.04; rays.Spread = 0.6; rays.Parent = Lighting
	table.insert(Env.created, rays)

	if S.ground then ApplyTerrain() end
	ScanGround()
end

local function EnvRestore()
	if not Env.on then return end
	Env.on = false
	for i = #Env.saved, 1, -1 do
		local e = Env.saved[i]
		pcall(function() e.inst[e.prop] = e.value end)
	end
	Env.saved = {}
	for _, o in ipairs(Env.created) do pcall(function() o:Destroy() end) end
	Env.created = {}
	for _, s in ipairs(Env.oldSkies) do pcall(function() s.Parent = Lighting end) end
	Env.oldSkies = {}
	RestoreGround()
end
OnCleanup(EnvRestore)

local function SetGround(on)
	S.ground = on
	if not Env.on then return end
	if on then ApplyTerrain(); ScanGround() else RestoreGround() end
end

task.spawn(function()
	while Folder.Parent do
		task.wait(6)
		pcall(ScanGround)
	end
end)

------------------------------------------------------------------
-- 2) 降雪 (4層のパーティクル / 風 / 屋内で止まる / 自動軽量化)
------------------------------------------------------------------
local Fall = {layers = {}, indoor = 0, auto = 1, t = 0}

local function NS(a, b, c) return NumberSequenceKeypoint.new(a, b, c or 0) end

local LAYER_DEFS = {
	{ -- 細かい雪
		tex = TEX_SMOKE, box = Vector3.new(170, 1, 170), y = 55, rate = 260, life = {9, 11}, speed = {6, 10},
		size = {0.16, 0.07}, transp = {0.1, 0.55}, light = 0.25, drag = 0.2, spread = 12, color = Color3.fromRGB(255, 255, 255),
	},
	{ -- 大きめの雪
		tex = TEX_SMOKE, box = Vector3.new(150, 1, 150), y = 55, rate = 90, life = {10, 12}, speed = {5, 8},
		size = {0.34, 0.14}, transp = {0.12, 0.6}, light = 0.3, drag = 0.3, spread = 18, color = Color3.fromRGB(250, 253, 255),
	},
	{ -- きらめく結晶 (動画のような星形)
		tex = TEX_SPARK, box = Vector3.new(120, 1, 120), y = 50, rate = 24, life = {9, 12}, speed = {4, 7},
		size = {0.8, 0.35}, transp = {0.15, 0.7}, light = 0.9, drag = 0.2, spread = 25, color = Color3.fromRGB(235, 245, 255), spin = true,
	},
	{ -- カメラの近くを舞う大粒 (手前のボケ)
		tex = TEX_SMOKE, box = Vector3.new(26, 18, 26), y = 0, rate = 14, life = {3, 5}, speed = {1.5, 3},
		size = {0.8, 0.5}, transp = {0.45, 0.8}, light = 0.2, drag = 0.5, spread = 40, color = Color3.fromRGB(255, 255, 255), near = true,
	},
	{ -- 近くの結晶
		tex = TEX_SPARK, box = Vector3.new(30, 20, 30), y = 0, rate = 8, life = {3, 5}, speed = {1.5, 3},
		size = {1.1, 0.6}, transp = {0.3, 0.8}, light = 1, drag = 0.4, spread = 40, color = Color3.fromRGB(235, 245, 255), near = true, spin = true,
	},
}

for _, d in ipairs(LAYER_DEFS) do
	local part = Instance.new("Part")
	part.Anchored = true; part.CanCollide = false; part.CanQuery = false; part.CanTouch = false; part.CastShadow = false
	part.Transparency = 1; part.Size = d.box
	part.Parent = Folder
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = d.tex
	pe.Color = ColorSequence.new(d.color)
	pe.LightEmission = d.light
	pe.LightInfluence = d.near and 0.3 or 0.7
	pe.Lifetime = NumberRange.new(d.life[1], d.life[2])
	pe.Speed = NumberRange.new(d.speed[1], d.speed[2])
	pe.Size = NumberSequence.new({NS(0, d.size[1], d.size[2]), NS(1, d.size[1], d.size[2])})
	pe.Transparency = NumberSequence.new({NS(0, 1), NS(0.12, d.transp[1]), NS(0.85, d.transp[2]), NS(1, 1)})
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(d.spin and -70 or -25, d.spin and 70 or 25)
	pe.Drag = d.drag
	pe.SpreadAngle = Vector2.new(d.spread, d.spread)
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.Rate = 0
	pe.Parent = part
	table.insert(Fall.layers, {part = part, pe = pe, def = d})
end

local function FallUpdate(dt)
	Fall.t += dt
	local cam = Cam()
	if not cam then return end
	local cp = cam.CFrame.Position
	for _, L in ipairs(Fall.layers) do
		L.part.CFrame = CFrame.new(cp + Vector3.new(0, L.def.y, 0))
		-- 風のゆらぎ (突風)
		local w = S.wind * 7
		local gust = 0.6 + 0.4 * math.sin(Fall.t * 0.31)
		L.pe.Acceleration = Vector3.new(
			w * gust * math.sin(Fall.t * 0.7 + 1) + w * 0.5,
			0,
			w * 0.6 * math.cos(Fall.t * 0.5)
		)
		L.pe.Rate = S.snow and (L.def.rate * S.density * Fall.auto * (1 - Fall.indoor)) or 0
	end
end

-- 屋内判定 (頭上に屋根があれば雪を止める) と 自動軽量化
task.spawn(function()
	local fpsAcc, fpsN, tAcc = 0, 0, 0
	local target = 0
	while Folder.Parent do
		task.wait(0.25)
		local cam = Cam()
		if cam then
			local res = Workspace:Raycast(cam.CFrame.Position, Vector3.new(0, 70, 0), Params())
			target = (res and res.Instance.Transparency < 0.6 and res.Instance.CanCollide) and 1 or 0
		end
	end
end)
Track(RunService.Heartbeat:Connect(function(dt)
	-- 屋内係数をなめらかに
	local cam = Cam()
	if cam then
		local res = Workspace:Raycast(cam.CFrame.Position, Vector3.new(0, 70, 0), Params())
		local target = (res and res.Instance.Transparency < 0.6 and res.Instance.CanCollide) and 1 or 0
		Fall.indoor += (target - Fall.indoor) * math.min(dt * 1.5, 1)
	end
end))
do
	local acc, n, slow = 0, 0, 0
	Track(RunService.RenderStepped:Connect(function(dt)
		acc += dt; n += 1
		if acc >= 3 then
			local fps = n / acc
			acc, n = 0, 0
			if fps < 24 and Fall.auto > 0.35 then Fall.auto *= 0.85
			elseif fps > 50 and Fall.auto < 1 then Fall.auto = math.min(Fall.auto * 1.1, 1) end
		end
	end))
end

------------------------------------------------------------------
-- 3) 足音 / 足跡 / 雪けむり
------------------------------------------------------------------
local stepTemplate = Instance.new("Sound")
stepTemplate.SoundId = IDS.step
stepTemplate.RollOffMaxDistance = 90
task.spawn(function() pcall(function() ContentProvider:PreloadAsync({stepTemplate}) end) end)
OnCleanup(function() stepTemplate:Destroy() end)

local prints = {}
local function Puff(pos, n, size, speed)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1
	p.Size = Vector3.new(0.4, 0.4, 0.4); p.CFrame = CFrame.new(pos); p.Parent = Folder
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = TEX_SMOKE; pe.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	pe.LightEmission = 0.15; pe.LightInfluence = 0.8
	pe.Size = NumberSequence.new({NS(0, size * 0.6), NS(1, size * 1.8)})
	pe.Transparency = NumberSequence.new({NS(0, 0.35), NS(1, 1)})
	pe.Lifetime = NumberRange.new(0.5, 0.9); pe.Speed = NumberRange.new(speed * 0.4, speed)
	pe.SpreadAngle = Vector2.new(70, 70); pe.EmissionDirection = Enum.NormalId.Top; pe.Drag = 3
	pe.Rate = 0; pe.Parent = p
	pe:Emit(n)
	Debris:AddItem(p, 1.5)
end

local function MakePrint(pos, normal, dir, side)
	local base = CFrame.lookAt(pos + normal * 0.03, pos + normal * 0.03 + dir, normal) -- 向きを合わせる
	local right = base.RightVector
	local center = pos + right * side * 0.42
	local group = {}
	for i, off in ipairs({-0.36, 0.34}) do
		local r = (i == 1) and 0.5 or 0.58
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true; part.CanCollide = false; part.CanQuery = false; part.CanTouch = false; part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(186, 204, 228)
		part.Transparency = 0.4
		part.Size = Vector3.new(0.04, r, r)
		part.CFrame = CFrame.new(center + dir * off + normal * 0.035) * CFrame.fromMatrix(Vector3.zero, normal, base.LookVector) * CFrame.Angles(0, 0, 0)
		part.Parent = Folder
		table.insert(group, part)
	end
	table.insert(prints, group)
	if #prints > 60 then
		for _, p in ipairs(table.remove(prints, 1)) do p:Destroy() end
	end
	task.delay(22, function()
		for _, p in ipairs(group) do
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(6), {Transparency = 1}):Play()
				Debris:AddItem(p, 6.2)
			end
		end
	end)
end

local step = {acc = 0, last = nil, side = 1}
local function DoStep(hrp, hum)
	local res = Workspace:Raycast(hrp.Position, Vector3.new(0, -(hum.HipHeight + 4), 0), Params())
	if not res then return end
	local onSnow = S.ground or res.Material == Enum.Material.Snow or Env.partSet[res.Instance]
	if not onSnow then return end
	step.side = -step.side
	if S.steps then
		local s = stepTemplate:Clone()
		s.Volume = S.volume * rng:NextNumber(0.85, 1.1)
		s.PlaybackSpeed = rng:NextNumber(0.94, 1.08)
		s.Parent = hrp
		s:Play()
		Debris:AddItem(s, 4)
	end
	local move = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
	local dir = move.Magnitude > 0.5 and move.Unit or Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
	local foot = res.Position
	Puff(foot + res.Normal * 0.1, 5, 0.9, 5)
	if S.prints and res.Normal.Y > 0.7 then
		pcall(MakePrint, foot, res.Normal, dir, step.side)
	end
end

Track(RunService.Heartbeat:Connect(function()
	local _, hum, hrp = CharParts()
	if not (hum and hrp) or hum.Health <= 0 then step.last = nil return end
	local pos = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
	if step.last and hum.FloorMaterial ~= Enum.Material.Air and hum.MoveDirection.Magnitude > 0.1 then
		step.acc += (pos - step.last).Magnitude
		local len = math.clamp(2.7 * hum.WalkSpeed / 16, 1.8, 4.2)
		if step.acc >= len then
			step.acc -= len
			pcall(DoStep, hrp, hum)
		end
	elseif hum.FloorMaterial == Enum.Material.Air then
		step.acc = 0
	end
	step.last = pos
end))

------------------------------------------------------------------
-- 4) 雪だるま / 雪だまり
------------------------------------------------------------------
local snowmen, mounds = {}, {}

local function Ball(parent, d, cf, color, mat)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = true
	p.Size = Vector3.new(d, d, d); p.CFrame = cf; p.Color = color; p.Material = mat or Enum.Material.Snow
	p.Parent = parent
	return p
end

local function BuildSnowman(pos, yaw)
	local s = rng:NextNumber(0.85, 1.5)
	local m = Instance.new("Model")
	m.Name = "Snowman"
	local W = Color3.fromRGB(244, 248, 254)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local d1, d2, d3 = 3.6 * s, 2.7 * s, 1.9 * s
	local y1 = d1 / 2 - 0.35 * s
	local y2 = y1 + d1 / 2 + d2 / 2 - 0.55 * s
	local y3 = y2 + d2 / 2 + d3 / 2 - 0.45 * s
	local lean = CFrame.Angles(rng:NextNumber(-0.04, 0.04), 0, rng:NextNumber(-0.04, 0.04))
	local b1 = Ball(m, d1, base * CFrame.new(0, y1, 0), W)
	b1.CanCollide = true
	Ball(m, d2, base * lean * CFrame.new(0, y2, 0), W)
	local head = Ball(m, d3, base * lean * CFrame.new(0, y3, 0), W)
	local hf = base * lean * CFrame.new(0, y3, 0)
	-- 目 / 口 (炭)
	local coal = Color3.fromRGB(22, 22, 26)
	for _, sx in ipairs({-1, 1}) do
		Ball(m, 0.2 * s, hf * CFrame.new(sx * 0.32 * s, 0.25 * s, -d3 * 0.46), coal, Enum.Material.Slate)
	end
	for i = -2, 2 do
		local a = i * 0.34
		Ball(m, 0.13 * s, hf * CFrame.new(math.sin(a) * 0.55 * s, -0.28 * s - math.abs(i) * 0.04 * s, -d3 * 0.44 * math.cos(a) * 0.98), coal, Enum.Material.Slate)
	end
	-- 人参の鼻
	local nose = Instance.new("WedgePart")
	nose.Anchored = true; nose.CanCollide = false; nose.CanQuery = false; nose.CanTouch = false
	nose.Size = Vector3.new(0.22 * s, 0.22 * s, 0.9 * s); nose.Color = Color3.fromRGB(255, 124, 26); nose.Material = Enum.Material.SmoothPlastic
	nose.CFrame = hf * CFrame.new(0, 0.0, -d3 * 0.5 - 0.35 * s) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	nose.Parent = m
	-- ボタン
	local mf = base * lean * CFrame.new(0, y2, 0)
	for i = -1, 1 do
		Ball(m, 0.22 * s, mf * CFrame.new(0, i * 0.55 * s, -d2 * 0.47 * math.cos(i * 0.4)), coal, Enum.Material.Slate)
	end
	-- 木の枝の腕
	for _, sx in ipairs({-1, 1}) do
		local arm = Instance.new("Part")
		arm.Anchored = true; arm.CanCollide = false; arm.CanQuery = false; arm.CanTouch = false
		arm.Size = Vector3.new(0.14 * s, 0.14 * s, 2.1 * s); arm.Color = Color3.fromRGB(86, 58, 34); arm.Material = Enum.Material.Wood
		arm.CFrame = mf * CFrame.new(sx * d2 * 0.55 + sx * 0.7 * s, 0.35 * s, 0) * CFrame.Angles(0, sx * math.rad(90 - 12), 0) * CFrame.Angles(math.rad(28), 0, 0)
		arm.Parent = m
	end
	-- 帽子 or マフラー
	if rng:NextNumber() < 0.45 then
		local brim = Instance.new("Part"); brim.Shape = Enum.PartType.Cylinder
		brim.Anchored = true; brim.CanCollide = false; brim.CanQuery = false; brim.CanTouch = false
		brim.Size = Vector3.new(0.12 * s, 1.5 * s, 1.5 * s); brim.Color = Color3.fromRGB(26, 26, 30); brim.Material = Enum.Material.SmoothPlastic
		brim.CFrame = hf * CFrame.new(0, d3 * 0.42, 0) * CFrame.Angles(0, 0, math.pi / 2)
		brim.Parent = m
		local top = brim:Clone(); top.Size = Vector3.new(0.9 * s, 0.95 * s, 0.95 * s)
		top.CFrame = hf * CFrame.new(0, d3 * 0.42 + 0.5 * s, 0) * CFrame.Angles(0, 0, math.pi / 2); top.Parent = m
		local band = brim:Clone(); band.Color = Color3.fromRGB(190, 30, 36); band.Size = Vector3.new(0.18 * s, 0.97 * s, 0.97 * s)
		band.CFrame = hf * CFrame.new(0, d3 * 0.42 + 0.14 * s, 0) * CFrame.Angles(0, 0, math.pi / 2); band.Parent = m
	else
		local sc = Instance.new("Part"); sc.Shape = Enum.PartType.Cylinder
		sc.Anchored = true; sc.CanCollide = false; sc.CanQuery = false; sc.CanTouch = false
		sc.Size = Vector3.new(0.3 * s, d3 * 0.95, d3 * 0.95); sc.Color = Color3.fromRGB(200, 36, 44); sc.Material = Enum.Material.Fabric
		sc.CFrame = hf * CFrame.new(0, -d3 * 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
		sc.Parent = m
		local tail = Instance.new("Part"); tail.Anchored = true; tail.CanCollide = false; tail.CanQuery = false; tail.CanTouch = false
		tail.Size = Vector3.new(0.5 * s, 1.1 * s, 0.14 * s); tail.Color = Color3.fromRGB(200, 36, 44); tail.Material = Enum.Material.Fabric
		tail.CFrame = hf * CFrame.new(0.5 * s, -d3 * 0.5 - 0.5 * s, -d3 * 0.42) * CFrame.Angles(0, 0, 0.12)
		tail.Parent = m
	end
	m.Parent = Folder
	return m
end

local function FindFlat(minD, maxD)
	local _, _, r = CharParts()
	if not r then return nil end
	local ang = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(minD, maxD)
	local p = r.Position + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
	local res = Workspace:Raycast(p + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), Params())
	if res and res.Normal.Y > 0.88 and res.Material ~= Enum.Material.Water then return res.Position end
	return nil
end

local function TooClose(list, pos, d)
	for _, it in ipairs(list) do
		if (it.pos - pos).Magnitude < d then return true end
	end
	return false
end

task.spawn(function()
	while Folder.Parent do
		task.wait(1.5)
		local _, _, r = CharParts()
		if r then
			-- 遠すぎる雪だるま/雪だまりを片付ける
			for i = #snowmen, 1, -1 do
				if (snowmen[i].pos - r.Position).Magnitude > 190 or not S.snowmen then
					snowmen[i].model:Destroy(); table.remove(snowmen, i)
				end
			end
			for i = #mounds, 1, -1 do
				if (mounds[i].pos - r.Position).Magnitude > 150 or not S.snowmen then
					mounds[i].part:Destroy(); table.remove(mounds, i)
				end
			end
			if S.snowmen then
				local want = math.floor(5 * S.freq + 0.5)
				if #snowmen < want then
					local pos = FindFlat(40, 120)
					if pos and not TooClose(snowmen, pos, 14) then
						local ok, m = pcall(BuildSnowman, pos, rng:NextNumber(0, math.pi * 2))
						if ok and m then table.insert(snowmen, {model = m, pos = pos}) end
					end
				end
				if #mounds < math.floor(14 * S.freq) then
					local pos = FindFlat(15, 100)
					if pos and not TooClose(mounds, pos, 6) then
						local d = rng:NextNumber(2.5, 7)
						local part = Ball(Folder, d, CFrame.new(pos + Vector3.new(0, d * 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromRGB(246, 249, 255))
						part.Size = Vector3.new(d, d * rng:NextNumber(0.28, 0.45), d * rng:NextNumber(0.8, 1.2))
						part.CanCollide = true
						table.insert(mounds, {part = part, pos = pos})
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------
-- 5) 雪玉 (しゃがんで集める → 投げる → 着弾で 9119310905)
------------------------------------------------------------------
local SB = {busy = false, balls = {}, motors = nil, active = false, held = nil, shards = {}}
local pose = {c = 0, lean = 0, Rs = 0.1, Ls = 0.1, Rel = 0.2, Lel = 0.2, twist = 0, hasKnee = false}

local function CollectMotors(model)
	local defs = {
		root = {"RootJoint"}, waist = {"Waist"},
		shR = {"RightShoulder", "Right Shoulder"}, shL = {"LeftShoulder", "Left Shoulder"},
		elR = {"RightElbow"}, elL = {"LeftElbow"},
		hipR = {"RightHip", "Right Hip"}, hipL = {"LeftHip", "Left Hip"},
		knR = {"RightKnee"}, knL = {"LeftKnee"},
	}
	local list = {}
	for key, names in pairs(defs) do
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") then
				for _, n in ipairs(names) do
					if d.Name == n then list[key] = {m = d, c0 = d.C0} end
				end
			end
		end
	end
	return list
end

local function PoseJ(e, rx, ry, rz)
	if not e then return end
	local p = e.c0.Position
	e.m.C0 = CFrame.new(p) * CFrame.Angles(rx, ry or 0, rz or 0) * (e.c0 - p)
end

local function RestoreMotors()
	if not SB.motors then return end
	for _, e in pairs(SB.motors) do pcall(function() e.m.C0 = e.c0 end) end
end

Track(RunService.Stepped:Connect(function()
	if not SB.active or not SB.motors then return end
	local m = SB.motors
	if not (m.root and m.root.m.Parent) then return end
	for _, k in ipairs({"shR", "shL", "elR", "elL", "hipR", "hipL", "knR", "knL", "waist", "root"}) do
		if m[k] then m[k].m.Transform = CFrame.new() end
	end
	local c = pose.c
	local d = pose.hasKnee and 1.15 * c or 0
	local th = pose.hasKnee and 1.1 * c or 0
	local v = 2.41 - d - 1.22 * math.cos(th)
	local flex = th + math.acos(math.clamp(v / 1.19, -1, 1))
	if m.root then
		local p = m.root.c0.Position
		m.root.m.C0 = CFrame.new(p + Vector3.new(0, -d, 0)) * CFrame.Angles(m.waist and (-pose.lean * 0.3) or -pose.lean, 0, 0) * (m.root.c0 - p)
	end
	if m.waist then PoseJ(m.waist, -pose.lean * 0.7, pose.twist, 0) end
	PoseJ(m.hipR, th, 0, 0.12 * c); PoseJ(m.hipL, th, 0, -0.12 * c)
	PoseJ(m.knR, -flex, 0, 0); PoseJ(m.knL, -flex, 0, 0)
	PoseJ(m.shR, pose.Rs, 0, 0.12); PoseJ(m.shL, pose.Ls, 0, -0.12)
	PoseJ(m.elR, pose.Rel, 0, 0); PoseJ(m.elL, pose.Lel, 0, 0)
end))

local function HandPoint(limb)
	if limb.Name:find(" ") then
		return (limb.CFrame * CFrame.new(0, -limb.Size.Y / 2 + 0.3, 0)).Position
	end
	return limb.Position
end

local function SnowPart(size, cf)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = true
	p.Size = Vector3.new(size, size, size); p.CFrame = cf
	p.Color = Color3.fromRGB(248, 251, 255); p.Material = Enum.Material.Snow
	p.Parent = Folder
	return p
end

local function Chunks(pos, n, speed)
	for _ = 1, n do
		if #SB.shards > 60 then break end
		local s = rng:NextNumber(0.15, 0.42)
		local p = Instance.new("Part")
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
		p.Size = Vector3.new(s, s * 0.8, s); p.Material = Enum.Material.Snow; p.Color = Color3.fromRGB(246, 250, 255)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		p.Parent = Folder
		table.insert(SB.shards, {
			part = p, age = 0, life = rng:NextNumber(0.6, 1.0),
			vel = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1.2), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(speed * 0.4, speed),
		})
	end
end

local function Impact(pos, normal, hitInst)
	-- 着弾音
	local sp = Instance.new("Part")
	sp.Anchored = true; sp.CanCollide = false; sp.CanQuery = false; sp.CanTouch = false; sp.Transparency = 1
	sp.Size = Vector3.new(0.5, 0.5, 0.5); sp.CFrame = CFrame.new(pos); sp.Parent = Folder
	local snd = Instance.new("Sound")
	snd.SoundId = IDS.hit; snd.Volume = 1; snd.RollOffMaxDistance = 160; snd.PlaybackSpeed = rng:NextNumber(0.95, 1.06)
	snd.Parent = sp
	snd:Play()
	Debris:AddItem(sp, 5)
	-- 雪けむり + きらめき + 破片
	Puff(pos + normal * 0.2, 18, 1.5, 11)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = TEX_SPARK; sparks.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255)); sparks.LightEmission = 0.9
	sparks.Size = NumberSequence.new({NS(0, 0.5, 0.2), NS(1, 0)}); sparks.Lifetime = NumberRange.new(0.5, 1)
	sparks.Speed = NumberRange.new(4, 10); sparks.SpreadAngle = Vector2.new(80, 80); sparks.Rate = 0
	sparks.EmissionDirection = Enum.NormalId.Top; sparks.Parent = sp
	sparks:Emit(14)
	Chunks(pos + normal * 0.2, 9, 14)
	-- 地面にできる雪のあと
	if normal.Y > 0.5 then
		local splat = Instance.new("Part")
		splat.Shape = Enum.PartType.Cylinder
		splat.Anchored = true; splat.CanCollide = false; splat.CanQuery = false; splat.CanTouch = false; splat.CastShadow = false
		splat.Material = Enum.Material.Snow; splat.Color = Color3.fromRGB(250, 252, 255)
		local d = rng:NextNumber(1.8, 2.8)
		splat.Size = Vector3.new(0.12, d, d)
		splat.CFrame = CFrame.lookAt(pos + normal * 0.05, pos + normal * 1.05) * CFrame.Angles(0, math.pi / 2, 0)
		splat.Parent = Folder
		task.delay(9, function()
			if splat.Parent then
				TweenService:Create(splat, TweenInfo.new(4), {Transparency = 1}):Play()
				Debris:AddItem(splat, 4.2)
			end
		end)
	end
end

local function Launch(part, from)
	local cam = Cam()
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local res = Workspace:Raycast(ray.Origin, ray.Direction * 300, Params())
	local target = res and res.Position or (ray.Origin + ray.Direction * 160)
	local dir = (target - from)
	dir = dir.Magnitude > 1 and dir.Unit or ray.Direction
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = TEX_SMOKE; trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)); trail.LightEmission = 0.1
	trail.Size = NumberSequence.new({NS(0, part.Size.X * 0.5), NS(1, 0)})
	trail.Transparency = NumberSequence.new({NS(0, 0.5), NS(1, 1)})
	trail.Lifetime = NumberRange.new(0.35, 0.5); trail.Rate = 40; trail.Speed = NumberRange.new(0, 0.5); trail.Parent = part
	table.insert(SB.balls, {
		part = part, pos = from, vel = dir * 74 + Vector3.new(0, 13, 0), age = 0,
		spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)), rot = CFrame.new(),
	})
end

Track(RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 20)
	FallUpdate(dt)
	-- 手に持った雪玉
	if SB.held then
		local c, _, r = CharParts()
		local rH = c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"))
		local lH = c and (c:FindFirstChild("LeftHand") or c:FindFirstChild("Left Arm"))
		if rH and SB.held.part.Parent then
			local pos
			if SB.held.mode == "gather" and lH then
				pos = (HandPoint(rH) + HandPoint(lH)) / 2 + Vector3.new(0, 0.15, 0)
			else
				pos = HandPoint(rH) + Vector3.new(0, 0.1, 0)
			end
			SB.held.pos = pos
			local s = SB.held.size
			SB.held.part.Size = Vector3.new(s, s, s)
			SB.held.part.CFrame = CFrame.new(pos)
		end
	end
	-- 飛んでいる雪玉
	local params = Params()
	for i = #SB.balls, 1, -1 do
		local b = SB.balls[i]
		b.age += dt
		b.vel += Vector3.new(0, -58, 0) * dt
		local np = b.pos + b.vel * dt
		local dir = np - b.pos
		local res = Workspace:Raycast(b.pos, dir, params)
		if res or b.age > 8 then
			if res then Impact(res.Position, res.Normal, res.Instance) end
			b.part:Destroy()
			table.remove(SB.balls, i)
		else
			b.pos = np
			b.rot = b.rot * CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
			b.part.CFrame = CFrame.new(np) * b.rot
		end
	end
	-- 雪のかけら
	for i = #SB.shards, 1, -1 do
		local d = SB.shards[i]
		d.age += dt
		if d.age >= d.life or not d.part.Parent then
			if d.part.Parent then d.part:Destroy() end
			table.remove(SB.shards, i)
		else
			d.vel += Vector3.new(0, -60, 0) * dt
			local cf = d.part.CFrame
			d.part.CFrame = CFrame.new(cf.Position + d.vel * dt) * (cf - cf.Position) * CFrame.Angles(dt * 6, dt * 5, dt * 4)
			d.part.Transparency = math.clamp((d.age / d.life - 0.5) / 0.5, 0, 1)
		end
	end
end))

local throwBtn -- UI側で作成

local function SetThrowBusy(b)
	SB.busy = b
	if throwBtn then
		throwBtn.Text = b and "…" or "投げる"
		throwBtn.BackgroundTransparency = b and 0.35 or 0
	end
end

local function Anim(duration, fn)
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		fn(a)
		if a >= 1 then break end
		RunService.Heartbeat:Wait()
	end
end

local function DoThrow()
	if SB.busy or not S.ball then return end
	local c, hum, hrp = CharParts()
	if not (c and hum and hrp) or hum.Health <= 0 then return end
	SetThrowBusy(true)
	SB.motors = CollectMotors(c)
	pose.hasKnee = SB.motors.knR ~= nil
	local oldWS, oldJP, oldJH = hum.WalkSpeed, hum.JumpPower, hum.JumpHeight
	local ok, err = pcall(function()
		hum.WalkSpeed = 0
		pcall(function() hum.JumpPower = 0 end)
		pcall(function() hum.JumpHeight = 0 end)
		-- カメラの向きを向く
		local look = Cam().CFrame.LookVector
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)

		pose.c, pose.lean, pose.Rs, pose.Ls, pose.Rel, pose.Lel, pose.twist = 0, 0, 0.1, 0.1, 0.2, 0.2, 0
		SB.active = true
		local ball = SnowPart(0.2, CFrame.new(hrp.Position))
		SB.held = {part = ball, mode = "gather", size = 0.2, pos = hrp.Position}

		-- 1) しゃがむ
		Anim(0.42, function(a)
			local e = Ease(a)
			pose.c = e; pose.lean = 0.85 * e
			pose.Rs = Lerp(0.1, 0.95, e); pose.Ls = Lerp(0.1, 0.95, e)
			pose.Rel = 0.35; pose.Lel = 0.35
		end)
		-- 2) 雪をすくって丸める (雪玉が育つ)
		local lastPuff = 0
		Anim(1.1, function(a)
			pose.c = 1; pose.lean = 0.85
			pose.Rs = 0.98 + 0.2 * math.sin(a * math.pi * 2 * 3)
			pose.Ls = 0.98 + 0.2 * math.sin(a * math.pi * 2 * 3 + math.pi)
			SB.held.size = Lerp(0.2, 1.25, Ease(a))
			if a - lastPuff > 0.12 and SB.held.pos then
				lastPuff = a
				Puff(SB.held.pos + Vector3.new(0, -0.1, 0), 4, 0.7, 4)
			end
		end)
		SB.held.mode = "hand"
		-- 3) 立ち上がって振りかぶる
		Anim(0.36, function(a)
			local e = Ease(a)
			pose.c = Lerp(1, 0.25, e); pose.lean = Lerp(0.85, -0.2, e)
			pose.Rs = Lerp(0.98, -1.35, e); pose.Ls = Lerp(0.98, 0.6, e)
			pose.Rel = Lerp(0.35, 0.95, e); pose.twist = Lerp(0, -0.55, e)
		end)
		-- 4) 投げる
		local released = false
		Anim(0.2, function(a)
			local e = 1 - (1 - a) ^ 2
			pose.Rs = Lerp(-1.35, 2.3, e); pose.Rel = Lerp(0.95, 0.15, e)
			pose.lean = Lerp(-0.2, 0.45, e); pose.twist = Lerp(-0.55, 0.5, e)
			pose.Ls = Lerp(0.6, -0.4, e)
			if a >= 0.5 and not released then
				released = true
				local part, from = SB.held.part, SB.held.pos
				SB.held = nil
				Launch(part, from)
			end
		end)
		-- 5) 余韻
		Anim(0.45, function(a)
			local e = Ease(a)
			pose.c = Lerp(0.25, 0, e); pose.lean = Lerp(0.45, 0, e)
			pose.Rs = Lerp(2.3, 0.1, e); pose.Ls = Lerp(-0.4, 0.1, e)
			pose.twist = Lerp(0.5, 0, e); pose.Rel = Lerp(0.15, 0.2, e)
		end)
	end)
	-- 後片付け (エラーでも必ず元に戻す)
	SB.active = false
	RestoreMotors()
	if SB.held then pcall(function() SB.held.part:Destroy() end) SB.held = nil end
	pcall(function() hum.WalkSpeed = oldWS end)
	pcall(function() hum.JumpPower = oldJP end)
	pcall(function() hum.JumpHeight = oldJH end)
	SetThrowBusy(false)
	if not ok then Notify("雪玉エラー", tostring(err), 5) end
end

Track(LP.CharacterAdded:Connect(function()
	SB.active = false; SB.motors = nil; SB.busy = false; SB.held = nil
	step.last = nil
	SetThrowBusy(false)
end))

------------------------------------------------------------------
-- 6) UI (白い背景がゆっくり動き、雪が流れる / 閉じると小さな雪だるま)
------------------------------------------------------------------
local TXT = Color3.fromRGB(52, 84, 126)
local SUB = Color3.fromRGB(110, 140, 178)
local BLUE = Color3.fromRGB(88, 158, 228)
local LINE = Color3.fromRGB(176, 208, 240)
local WHITE = Color3.fromRGB(255, 255, 255)

local Gui = Instance.new("ScreenGui")
Gui.Name = "SnowWorldGui"; Gui.ResetOnSpawn = false; Gui.DisplayOrder = 10000
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; Gui.IgnoreGuiInset = true
do
	local ok = pcall(function() Gui.Parent = LP:WaitForChild("PlayerGui") end)
	if not ok or not Gui.Parent then pcall(function() Gui.Parent = game:GetService("CoreGui") end) end
end
OnCleanup(function() Gui:Destroy() end)

local function New(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function Corner(o, r) New("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function Stroke(o, c, t) return New("UIStroke", {Color = c, Thickness = t}, o) end

local WIN_W, WIN_H, TITLE_H = 340, 380, 46
local Win = New("CanvasGroup", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(WIN_W, WIN_H),
	BackgroundColor3 = WHITE, BorderSizePixel = 0, Active = true,
}, Gui)
Corner(Win, 18)
Stroke(Win, LINE, 2)
local WinScale = New("UIScale", {Scale = 1}, Win)

-- 動く白い背景
local Bg = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 1}, Win)
local Grad = New("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(231, 242, 253)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}),
	Rotation = 60,
}, Bg)

-- 流れる雪
local Flakes = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, ClipsDescendants = true}, Win)
local flakeList = {}
for i = 1, 46 do
	local sz = rng:NextInteger(3, 9)
	local f = New("Frame", {
		Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = Color3.fromRGB(176, 208, 242),
		BackgroundTransparency = rng:NextNumber(0.1, 0.5), BorderSizePixel = 0, ZIndex = 2,
	}, Flakes)
	Corner(f, 5)
	table.insert(flakeList, {
		f = f, x = rng:NextNumber(0, 1), y = rng:NextNumber(0, 1), v = rng:NextNumber(0.05, 0.16),
		drift = rng:NextNumber(0.02, 0.06), ph = rng:NextNumber(0, 6.28), sw = rng:NextNumber(0.01, 0.03),
	})
end

local TitleBar = New("Frame", {Size = UDim2.new(1, 0, 0, TITLE_H), BackgroundTransparency = 1, Active = true, ZIndex = 5}, Win)
New("TextLabel", {
	Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -110, 1, 0), BackgroundTransparency = 1,
	Text = "❄ 雪の世界", TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
}, TitleBar)
local function TopBtn(text, x)
	local b = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(40, 36),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.1, Text = text, TextColor3 = TXT, Font = Enum.Font.GothamBold,
		TextSize = 22, BorderSizePixel = 0, AutoButtonColor = true, ZIndex = 6,
	}, TitleBar)
	Corner(b, 12); Stroke(b, LINE, 1.5)
	return b
end
local MinBtn = TopBtn("−", -52)
local CloseBtn = TopBtn("×", -8)

local Page = New("ScrollingFrame", {
	Position = UDim2.fromOffset(0, TITLE_H), Size = UDim2.new(1, 0, 1, -TITLE_H - 30), BackgroundTransparency = 1,
	BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
	ScrollBarImageColor3 = BLUE, ZIndex = 5,
}, Win)
New("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, Page)
New("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10)}, Page)
local Status = New("TextLabel", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -6), Size = UDim2.new(1, -28, 0, 20), BackgroundTransparency = 1,
	Text = "雪が降っています", TextColor3 = SUB, Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
}, Win)
local function SetStatus(t) Status.Text = t end

local order = 0
local function Row(h)
	order += 1
	local r = New("Frame", {Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 5}, Page)
	Corner(r, 12); Stroke(r, LINE, 1.4)
	return r
end

local function Toggle(name, desc, default, cb)
	local row = Row(desc and 58 or 48)
	New("TextLabel", {
		Position = UDim2.fromOffset(14, desc and 7 or 0), Size = UDim2.new(1, -90, 0, desc and 24 or 48), BackgroundTransparency = 1, Text = name,
		TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
	}, row)
	if desc then
		New("TextLabel", {
			Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -90, 0, 20), BackgroundTransparency = 1, Text = desc,
			TextColor3 = SUB, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
		}, row)
	end
	local sw = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(60, 32), Text = "",
		BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 6,
	}, row)
	Corner(sw, 16)
	local knob = New("Frame", {AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 7}, sw)
	Corner(knob, 13)
	local state = default
	local function Vis()
		sw.BackgroundColor3 = state and BLUE or Color3.fromRGB(200, 214, 232)
		TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -29, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)}):Play()
	end
	Vis()
	local last = 0
	sw.Activated:Connect(function()
		if os.clock() - last < 0.15 then return end
		last = os.clock()
		state = not state
		Vis()
		local ok, err = pcall(cb, state)
		if not ok then state = not state; Vis(); Notify("エラー", tostring(err), 5) end
		SetStatus(name .. (state and ": ON" or ": OFF"))
	end)
	return function(v) state = v; Vis() end
end

local function Slider(name, min, max, default, step, cb)
	local row = Row(66)
	New("TextLabel", {
		Position = UDim2.fromOffset(14, 4), Size = UDim2.new(0.6, 0, 0, 28), BackgroundTransparency = 1, Text = name,
		TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
	}, row)
	local val = New("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 4), Size = UDim2.new(0.35, 0, 0, 28), BackgroundTransparency = 1,
		Text = "", TextColor3 = BLUE, Font = Enum.Font.GothamBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
	}, row)
	local track = New("Frame", {Position = UDim2.new(0, 16, 0, 42), Size = UDim2.new(1, -32, 0, 10), BackgroundColor3 = Color3.fromRGB(214, 226, 242), BorderSizePixel = 0, Active = true, ZIndex = 6}, row)
	Corner(track, 5)
	local fill = New("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = BLUE, BorderSizePixel = 0, ZIndex = 7}, track)
	Corner(fill, 5)
	local knob = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 8}, track)
	Corner(knob, 12); Stroke(knob, BLUE, 2)
	local value = default
	local function Vis()
		local a = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		val.Text = string.format("%.2f", value)
	end
	Vis()
	local dragging, dragInput = false, nil
	local function From(input)
		local a = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = math.clamp(math.floor((min + (max - min) * a) / step + 0.5) * step, min, max)
		if v ~= value then
			value = v; Vis()
			local ok, err = pcall(cb, v)
			if not ok then Notify("エラー", tostring(err), 5) end
		end
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, dragInput = true, input
			Page.ScrollingEnabled = false
			From(input)
			local c
			c = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false; Page.ScrollingEnabled = true; SetStatus(name .. ": " .. val.Text); c:Disconnect()
				end
			end)
		end
	end)
	Track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then From(input) end
	end))
end

local function Section(text)
	order += 1
	New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "❄ " .. text, TextColor3 = BLUE, Font = Enum.Font.GothamBold,
		TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 5,
	}, Page)
end

-- 投げるボタン (雪玉ONのときだけ表示)
throwBtn = New("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.55, 0), Size = UDim2.fromOffset(96, 96),
	BackgroundColor3 = WHITE, Text = "投げる", TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 22,
	BorderSizePixel = 0, Visible = false, ZIndex = 20,
}, Gui)
Corner(throwBtn, 48); Stroke(throwBtn, BLUE, 3)
New("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 10), BackgroundTransparency = 1, Text = "⛄", TextSize = 24, ZIndex = 21,
}, throwBtn)
throwBtn.TextYAlignment = Enum.TextYAlignment.Bottom
throwBtn.Activated:Connect(function() task.spawn(DoThrow) end)

Section("天気")
Toggle("雪を降らせる", "細かい雪・大きな雪・きらめく結晶", true, function(v) S.snow = v end)
Slider("降雪量", 0.2, 2.0, S.density, 0.1, function(v) S.density = v end)
Slider("風", 0, 1, S.wind, 0.05, function(v) S.wind = v end)
Section("景色")
Toggle("雪景色 (空・光・霞)", "スカイボックスと明るい雪の光に変更", true, function(v) S.scene = v; if v then EnvApply() else EnvRestore() end end)
Toggle("地面を雪にする", "地面・テレインを白い雪色に", true, function(v) SetGround(v) end)
Section("足元")
Toggle("足音", "雪を踏むたびに音が鳴る", true, function(v) S.steps = v end)
Slider("足音の大きさ", 0, 1.5, S.volume, 0.05, function(v) S.volume = v end)
Toggle("足跡", "歩いたあとに足跡が残る", true, function(v) S.prints = v end)
Section("遊ぶ")
Toggle("雪玉", "ONで「投げる」ボタンが出ます", false, function(v)
	S.ball = v
	throwBtn.Visible = v
end)
Toggle("雪だるま", "ときどき周りに雪だるまが現れる", true, function(v) S.snowmen = v end)
Slider("雪だるまの数", 0.4, 3, S.freq, 0.2, function(v) S.freq = v end)

-- 開閉 (閉じると小さな雪だるま)
local Bubble = New("Frame", {
	Name = "SnowmanBubble", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(64, 84),
	BackgroundTransparency = 1, Visible = false, Active = true, ZIndex = 30,
}, Gui)
local BubbleScale = New("UIScale", {Scale = 0}, Bubble)
local function Circle(parent, size, pos, color, z, stroke)
	local c = New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z}, parent)
	Corner(c, size)
	if stroke then Stroke(c, LINE, 2) end
	return c
end
local body = Circle(Bubble, 50, UDim2.new(0.5, 0, 0.72, 0), WHITE, 31, true)
local head = Circle(Bubble, 34, UDim2.new(0.5, 0, 0.34, 0), WHITE, 32, true)
Circle(head, 5, UDim2.new(0.32, 0, 0.42, 0), Color3.fromRGB(30, 30, 34), 33)
Circle(head, 5, UDim2.new(0.68, 0, 0.42, 0), Color3.fromRGB(30, 30, 34), 33)
local nose = New("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(12, 5), BackgroundColor3 = Color3.fromRGB(255, 130, 30), BorderSizePixel = 0, ZIndex = 33}, head)
Corner(nose, 3)
Circle(body, 5, UDim2.new(0.5, 0, 0.35, 0), Color3.fromRGB(30, 30, 34), 33)
Circle(body, 5, UDim2.new(0.5, 0, 0.62, 0), Color3.fromRGB(30, 30, 34), 33)
local brim = New("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.2, 0), Size = UDim2.fromOffset(40, 5), BackgroundColor3 = Color3.fromRGB(34, 34, 40), BorderSizePixel = 0, ZIndex = 34}, Bubble)
local topHat = New("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.2, -5), Size = UDim2.fromOffset(24, 15), BackgroundColor3 = Color3.fromRGB(34, 34, 40), BorderSizePixel = 0, ZIndex = 34}, Bubble)
New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(40, 6), BackgroundColor3 = Color3.fromRGB(206, 40, 48), BorderSizePixel = 0, ZIndex = 34}, head).Position = UDim2.new(0.5, 0, 0.95, 0)

local isOpen, animating = true, false
local winCenter, bubblePos = Vector2.new(0, 0), Vector2.new(60, 150)
local respScale = 1

local function View()
	local v = Gui.AbsoluteSize
	if v.X < 10 then v = Cam().ViewportSize end
	return v
end
local function PlaceWin()
	local vp = View()
	local w, h = WIN_W * respScale, WIN_H * respScale
	local left = math.clamp(winCenter.X - w / 2, 110 - w, vp.X - 110)
	local top = math.clamp(winCenter.Y - h / 2, 0, vp.Y - 60)
	winCenter = Vector2.new(left + w / 2, top + h / 2)
	Win.Position = UDim2.fromOffset(winCenter.X, winCenter.Y)
end
local function PlaceBubble()
	local vp = View()
	bubblePos = Vector2.new(math.clamp(bubblePos.X, 40, vp.X - 40), math.clamp(bubblePos.Y, 50, vp.Y - 50))
	Bubble.Position = UDim2.fromOffset(bubblePos.X, bubblePos.Y)
end

local function SetOpen(open)
	if animating or open == isOpen then return end
	animating, isOpen = true, open
	local ti = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tiOut = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if open then
		Win.Visible = true
		Win.Position = UDim2.fromOffset(bubblePos.X, bubblePos.Y)
		WinScale.Scale = 0.05 * respScale
		Win.GroupTransparency = 1
		TweenService:Create(BubbleScale, TweenInfo.new(0.18), {Scale = 0}):Play()
		PlaceWin()
		TweenService:Create(Win, ti, {Position = UDim2.fromOffset(winCenter.X, winCenter.Y), GroupTransparency = 0}):Play()
		local t = TweenService:Create(WinScale, ti, {Scale = respScale})
		t.Completed:Connect(function() Bubble.Visible = false; animating = false end)
		t:Play()
	else
		PlaceWin(); PlaceBubble()
		Bubble.Visible = true
		TweenService:Create(Win, tiOut, {Position = UDim2.fromOffset(bubblePos.X, bubblePos.Y), GroupTransparency = 1}):Play()
		TweenService:Create(BubbleScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		local t = TweenService:Create(WinScale, tiOut, {Scale = 0.05 * respScale})
		t.Completed:Connect(function() Win.Visible = false; animating = false end)
		t:Play()
	end
end

local function UpdateScale()
	local vp = View()
	respScale = math.clamp(math.min(vp.X * 0.94 / WIN_W, vp.Y * 0.9 / WIN_H), 0.6, 1.3)
	if isOpen and not animating then WinScale.Scale = respScale end
	PlaceWin(); PlaceBubble()
end

local function MakeDraggable(handle, getPos, setPos, onTap)
	local dragging, startInput, startPoint, startPos, moved = false, nil, nil, nil, false
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, moved, startInput = true, false, input
			startPoint = Vector2.new(input.Position.X, input.Position.Y)
			startPos = getPos()
			local c
			c = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false; c:Disconnect()
					if not moved and onTap then onTap() end
				end
			end)
		end
	end)
	Track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input == startInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = Vector2.new(input.Position.X, input.Position.Y) - startPoint
			if d.Magnitude > 8 then moved = true end
			if moved then setPos(startPos + d) end
		end
	end))
end
MakeDraggable(TitleBar, function() return winCenter end, function(p) winCenter = p; PlaceWin() end)
MakeDraggable(Bubble, function() return bubblePos end, function(p) bubblePos = p; PlaceBubble() end, function() SetOpen(true) end)
MinBtn.Activated:Connect(function() SetOpen(false) end)

-- 背景のアニメーション (グラデーション + 流れる雪)
local uiT = 0
Track(RunService.RenderStepped:Connect(function(dt)
	if not Win.Visible then return end
	uiT += dt
	Grad.Rotation = 60 + 18 * math.sin(uiT * 0.35)
	Grad.Offset = Vector2.new(math.sin(uiT * 0.22) * 0.3, math.cos(uiT * 0.17) * 0.3)
	for _, f in ipairs(flakeList) do
		f.y += f.v * dt
		f.x += f.drift * dt * 0.4 + math.sin(uiT * 0.9 + f.ph) * f.sw * dt * 3
		if f.y > 1.04 then f.y = -0.04; f.x = rng:NextNumber(0, 1) end
		if f.x > 1.03 then f.x = -0.03 elseif f.x < -0.03 then f.x = 1.03 end
		f.f.Position = UDim2.fromScale(f.x, f.y)
	end
end))
Track(Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateScale))

local function Cleanup()
	for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
	Conns = {}
	SB.active = false
	pcall(RestoreMotors)
	for i = #Cleanups, 1, -1 do pcall(Cleanups[i]) end
	Cleanups = {}
	env.SnowWorldCleanup = nil
end
env.SnowWorldCleanup = Cleanup
CloseBtn.Activated:Connect(Cleanup)

------------------------------------------------------------------
-- 起動
------------------------------------------------------------------
do
	local vp = View()
	winCenter = Vector2.new(vp.X / 2, vp.Y / 2)
	bubblePos = Vector2.new(56, math.max(vp.Y * 0.3, 90))
	UpdateScale()
	WinScale.Scale = 0.05 * respScale
	Win.GroupTransparency = 1
	TweenService:Create(WinScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = respScale}):Play()
	TweenService:Create(Win, TweenInfo.new(0.35), {GroupTransparency = 0}):Play()
	EnvApply()
end
