--[[
	SNOW WORLD  -  Realistic Winter Atmosphere (Mobile)
	Reference look: bright white snowfield, blue sky, soft haze, glowing star crystals
	-----------------------------------------------------------------------------
	* Multi-layer snowfall (dust / flakes / glowing star crystals / near-camera bokeh)
	* Terminal-velocity wind physics with Perlin gusts, ground-blown snow swirls
	* Shelter detection (no snow under roofs), snow glitter on the ground
	* Time of day palette (night -> dawn -> noon -> sunset), auto day cycle
	* Atmosphere / Clouds / Bloom / SunRays / ColorCorrection driven smoothly
	* Frost vignette, cold breath, footstep snow puffs, optional snow cover
	* 7 weather presets, quality levels, Obsidian-style minimize orb, touch only
	Everything is client-side and restores your original lighting on close.
]]

-- ======================================================================
-- SERVICES
-- ======================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Terrain = Workspace.Terrain

local function Notify(title, text, duration)
	StarterGui:SetCore("SendNotification", {
		Title = title,
		Text = text,
		Duration = duration
	})
end

if getgenv().SnowWorld then
	pcall(function() getgenv().SnowWorld.Destroy() end)
end

-- ======================================================================
-- UTILS
-- ======================================================================
local Conns = {}
local Gradients = {}
local Restores = {}

local function Connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(Conns, c)
	return c
end

local function Clamp(v, a, b)
	return math.max(a, math.min(b, v))
end

local function RGB(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function T(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local NSK = NumberSequenceKeypoint.new
local CSK = ColorSequenceKeypoint.new

local function ParentGui(g)
	local ok = pcall(function() g.Parent = CoreGui end)
	if not ok or not g.Parent then
		g.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

-- ======================================================================
-- SETTINGS (targets) and CURRENT (smoothed) values
-- ======================================================================
local Settings = {
	Snow = 0.55, Size = 1.0, Crystal = 2.2, WindStr = 5, WindDir = 40,
	Fog = 0.30, Haze = 0.8, Cloud = 0.45, CloudDen = 0.55,
	Bloom = 1.0, Rays = 0.12, Sat = 0.06, Contrast = 0.06, Gloom = 0,
	Frost = 0, Swirl = 0.05, Clock = 13,
	Auto = false, DayLen = 8, Quality = 1.0,
	Shelter = true, Cover = false, Breath = true, Steps = true, Glitter = true,
}
local SMOOTH = {"Snow", "Size", "Crystal", "WindStr", "Fog", "Haze", "Cloud", "CloudDen", "Bloom", "Rays", "Sat", "Contrast", "Gloom", "Frost", "Swirl"}

local Presets = {
	Sparkle = {Snow = 0.55, Size = 1.0, Crystal = 2.2, WindStr = 5, Fog = 0.30, Haze = 0.8, Cloud = 0.45, CloudDen = 0.55, Bloom = 1.0, Rays = 0.12, Sat = 0.06, Contrast = 0.06, Gloom = 0, Frost = 0, Swirl = 0.05, Clock = 13},
	Light = {Snow = 0.7, Size = 1.0, Crystal = 1.0, WindStr = 6, Fog = 0.38, Haze = 1.2, Cloud = 0.6, CloudDen = 0.6, Bloom = 0.7, Rays = 0.08, Sat = -0.02, Contrast = 0.04, Gloom = 0.1, Frost = 0.1, Swirl = 0.1, Clock = 11},
	Heavy = {Snow = 1.5, Size = 1.15, Crystal = 0.6, WindStr = 12, Fog = 0.5, Haze = 2.2, Cloud = 0.85, CloudDen = 0.8, Bloom = 0.5, Rays = 0.02, Sat = -0.08, Contrast = 0.02, Gloom = 0.3, Frost = 0.3, Swirl = 0.35, Clock = 10},
	Blizzard = {Snow = 2.6, Size = 1.0, Crystal = 0.2, WindStr = 38, Fog = 0.72, Haze = 3.8, Cloud = 1.0, CloudDen = 1.0, Bloom = 0.35, Rays = 0, Sat = -0.18, Contrast = 0, Gloom = 0.45, Frost = 0.75, Swirl = 1.0, Clock = 15},
	Diamond = {Snow = 0.15, Size = 0.9, Crystal = 3.6, WindStr = 2, Fog = 0.22, Haze = 0.4, Cloud = 0.15, CloudDen = 0.3, Bloom = 1.5, Rays = 0.3, Sat = 0.1, Contrast = 0.1, Gloom = 0, Frost = 0, Swirl = 0, Clock = 9.5},
	Night = {Snow = 0.8, Size = 1.05, Crystal = 1.2, WindStr = 6, Fog = 0.35, Haze = 1.0, Cloud = 0.4, CloudDen = 0.5, Bloom = 1.1, Rays = 0, Sat = -0.05, Contrast = 0.08, Gloom = 0, Frost = 0.15, Swirl = 0.1, Clock = 23},
	Overcast = {Snow = 1.0, Size = 1.0, Crystal = 0.3, WindStr = 8, Fog = 0.45, Haze = 2.0, Cloud = 1.0, CloudDen = 0.9, Bloom = 0.45, Rays = 0, Sat = -0.15, Contrast = 0, Gloom = 0.35, Frost = 0.15, Swirl = 0.2, Clock = 12},
}
local PresetRow1 = {"Sparkle", "Light", "Heavy", "Blizzard"}
local PresetRow2 = {"Diamond", "Night", "Overcast"}

local Cur = {}
for _, k in ipairs(SMOOTH) do
	Cur[k] = Settings[k]
end
Cur.Clock = Lighting.ClockTime
Cur.Shelter = 1

-- ======================================================================
-- LIGHTING SNAPSHOT / EFFECT ACQUISITION
-- ======================================================================
local LIGHT_PROPS = {"Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "ExposureCompensation"}
local OrigLight = {}
for _, p in ipairs(LIGHT_PROPS) do
	OrigLight[p] = Lighting[p]
end
table.insert(Restores, function()
	for p, v in pairs(OrigLight) do
		pcall(function() Lighting[p] = v end)
	end
end)

local function Acquire(parent, class, propNames)
	local inst = parent:FindFirstChildOfClass(class)
	if inst then
		local saved = {}
		for _, p in ipairs(propNames) do
			saved[p] = inst[p]
		end
		table.insert(Restores, function()
			for p, v in pairs(saved) do
				pcall(function() inst[p] = v end)
			end
		end)
		return inst, saved
	end
	inst = Instance.new(class)
	inst.Name = "SnowWorld_" .. class
	inst.Parent = parent
	table.insert(Restores, function() inst:Destroy() end)
	return inst, nil
end

local function Own(class, parent, props)
	local inst = Instance.new(class)
	inst.Name = "SnowWorld_" .. class
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	inst.Parent = parent
	table.insert(Restores, function() inst:Destroy() end)
	return inst
end

local Atmo, AtmoSaved = Acquire(Lighting, "Atmosphere", {"Density", "Offset", "Color", "Decay", "Glare", "Haze"})
local Clouds, CloudSaved = Acquire(Terrain, "Clouds", {"Cover", "Density", "Color", "Enabled"})
local Bloom = Own("BloomEffect", Lighting, {Intensity = 0, Size = 40, Threshold = 0.9})
local Rays = Own("SunRaysEffect", Lighting, {Intensity = 0, Spread = 0.85})
local CCor = Own("ColorCorrectionEffect", Lighting, {})

-- start from the current look so the snow fades in smoothly
Cur.Fog = AtmoSaved and AtmoSaved.Density or 0
Cur.Haze = AtmoSaved and AtmoSaved.Haze or 0
Cur.Cloud = CloudSaved and CloudSaved.Cover or 0
Cur.CloudDen = CloudSaved and CloudSaved.Density or 0
Cur.Snow = 0
Cur.Crystal = 0
Cur.Bloom = 0
Cur.Rays = 0
Cur.Sat = 0
Cur.Contrast = 0
Cur.Gloom = 0
Cur.Frost = 0
Cur.Swirl = 0
Cur.WindStr = 0

-- ======================================================================
-- TIME OF DAY PALETTE
-- ======================================================================
local function K(t, amb, out, atmo, decay, tint, bright, exp)
	return {
		t = t,
		Ambient = RGB(amb[1], amb[2], amb[3]),
		Outdoor = RGB(out[1], out[2], out[3]),
		Atmo = RGB(atmo[1], atmo[2], atmo[3]),
		Decay = RGB(decay[1], decay[2], decay[3]),
		Tint = RGB(tint[1], tint[2], tint[3]),
		Bright = bright,
		Exp = exp,
	}
end

local KEYS = {
	K(0, {28, 36, 70}, {34, 46, 90}, {34, 44, 82}, {24, 32, 66}, {196, 210, 255}, 0.7, -0.1),
	K(5, {70, 80, 120}, {90, 100, 140}, {125, 135, 185}, {135, 105, 145}, {222, 218, 255}, 1.0, 0),
	K(6.5, {130, 122, 142}, {172, 152, 162}, {255, 192, 172}, {255, 152, 122}, {255, 236, 226}, 1.7, 0),
	K(9, {152, 172, 202}, {172, 192, 222}, {190, 215, 255}, {150, 190, 240}, {240, 248, 255}, 2.3, 0.05),
	K(12, {172, 196, 232}, {192, 212, 242}, {198, 226, 255}, {142, 186, 246}, {238, 248, 255}, 2.8, 0.1),
	K(16, {166, 186, 222}, {186, 202, 236}, {206, 222, 255}, {172, 192, 242}, {248, 246, 255}, 2.5, 0.05),
	K(18, {142, 122, 152}, {182, 142, 152}, {255, 182, 152}, {255, 132, 112}, {255, 232, 218}, 1.7, 0),
	K(19.5, {72, 72, 118}, {92, 92, 142}, {132, 122, 182}, {112, 92, 152}, {232, 226, 255}, 1.0, -0.05),
	K(24, {28, 36, 70}, {34, 46, 90}, {34, 44, 82}, {24, 32, 66}, {196, 210, 255}, 0.7, -0.1),
}

local Pal = {
	Ambient = KEYS[1].Ambient, Outdoor = KEYS[1].Outdoor, Atmo = KEYS[1].Atmo,
	Decay = KEYS[1].Decay, Tint = KEYS[1].Tint, Bright = 1, Exp = 0,
}

local function UpdatePalette(clock)
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if clock >= a.t and clock <= b.t then
			local f = (clock - a.t) / (b.t - a.t)
			f = f * f * (3 - 2 * f)
			Pal.Ambient = a.Ambient:Lerp(b.Ambient, f)
			Pal.Outdoor = a.Outdoor:Lerp(b.Outdoor, f)
			Pal.Atmo = a.Atmo:Lerp(b.Atmo, f)
			Pal.Decay = a.Decay:Lerp(b.Decay, f)
			Pal.Tint = a.Tint:Lerp(b.Tint, f)
			Pal.Bright = a.Bright + (b.Bright - a.Bright) * f
			Pal.Exp = a.Exp + (b.Exp - a.Exp) * f
			return
		end
	end
end

local function ApplyLighting()
	UpdatePalette(Cur.Clock)
	local gloom = Cur.Gloom
	Lighting.ClockTime = Cur.Clock
	Lighting.Ambient = Pal.Ambient
	Lighting.OutdoorAmbient = Pal.Outdoor
	Lighting.Brightness = Pal.Bright * (1 - gloom * 0.55)
	Lighting.ExposureCompensation = Pal.Exp

	Atmo.Density = Clamp(Cur.Fog, 0, 1)
	Atmo.Offset = 0.25
	Atmo.Color = Pal.Atmo
	Atmo.Decay = Pal.Decay
	Atmo.Glare = 0.4
	Atmo.Haze = Clamp(Cur.Haze, 0, 10)

	Clouds.Enabled = true
	Clouds.Cover = Clamp(Cur.Cloud, 0, 1)
	Clouds.Density = Clamp(Cur.CloudDen, 0, 1)
	local cc = Pal.Atmo:Lerp(RGB(255, 255, 255), 0.65)
	Clouds.Color = cc:Lerp(RGB(118, 124, 140), Clamp(gloom * 0.8, 0, 1))

	Bloom.Intensity = Cur.Bloom * 0.6
	Bloom.Size = 30 + Cur.Bloom * 18
	Bloom.Threshold = 0.88
	Rays.Intensity = Cur.Rays
	Rays.Spread = 0.85

	CCor.Brightness = 0.02
	CCor.Contrast = Cur.Contrast
	CCor.Saturation = Cur.Sat
	CCor.TintColor = Pal.Tint
end

-- ======================================================================
-- SNOW RIG (all particle emitters live in local-only parts under the camera)
-- ======================================================================
local SOFT = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local RigFolder = Instance.new("Folder")
RigFolder.Name = "SnowWorldRig"
RigFolder.Parent = Workspace.CurrentCamera
table.insert(Restores, function() RigFolder:Destroy() end)

local function RigPart(size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Parent = RigFolder
	return p
end

local Wide = RigPart(Vector3.new(90, 1, 90))
local Near = RigPart(Vector3.new(34, 1, 34))
local GroundP = RigPart(Vector3.new(80, 1, 80))

local function SizeSeq(mid, env)
	return NumberSequence.new({NSK(0, mid, env), NSK(1, mid, env)})
end

local TR_SOFT = NumberSequence.new({NSK(0, 1), NSK(0.1, 0.3), NSK(0.85, 0.4), NSK(1, 1)})
local TR_FLAKE = NumberSequence.new({NSK(0, 1), NSK(0.1, 0.15), NSK(0.85, 0.3), NSK(1, 1)})
local TR_NEAR = NumberSequence.new({NSK(0, 1), NSK(0.15, 0.4), NSK(0.8, 0.5), NSK(1, 1)})
local TR_SWIRL = NumberSequence.new({NSK(0, 1), NSK(0.15, 0.82), NSK(0.6, 0.9), NSK(1, 1)})
local TWINKLE = NumberSequence.new({NSK(0, 1), NSK(0.12, 0.15), NSK(0.28, 0.75), NSK(0.42, 0.1), NSK(0.58, 0.8), NSK(0.75, 0.2), NSK(1, 1)})
local SNOWCOL = ColorSequence.new(RGB(255, 255, 255))
local CRYSTALCOL = ColorSequence.new({CSK(0, RGB(235, 248, 255)), CSK(0.5, RGB(205, 232, 255)), CSK(1, RGB(235, 248, 255))})

local Layers = {
	{name = "Dust", part = Wide, tex = SOFT, rate = 380, size = 0.14, env = 0.06, life = {8, 10}, fall = 5.5, drag = 1, light = 0.12, infl = 0.8, wmul = 1.0, kind = "snow", seed = 1, tr = TR_SOFT, col = SNOWCOL, rot = {-20, 20}},
	{name = "Flake", part = Wide, tex = SOFT, rate = 120, size = 0.34, env = 0.14, life = {8, 10}, fall = 3.8, drag = 1, light = 0.3, infl = 0.7, wmul = 1.1, kind = "snow", seed = 2, tr = TR_FLAKE, col = SNOWCOL, rot = {-45, 45}},
	{name = "Crystal", part = Wide, tex = SPARKLE, rate = 16, size = 1.0, env = 0.45, life = {9, 11}, fall = 2.4, drag = 1, light = 1, infl = 0, wmul = 0.9, kind = "crystal", seed = 3, tr = TWINKLE, col = CRYSTALCOL, rot = {-80, 80}},
	{name = "NearFlake", part = Near, tex = SOFT, rate = 55, size = 0.55, env = 0.22, life = {4, 6}, fall = 3.2, drag = 1, light = 0.4, infl = 0.6, wmul = 1.0, kind = "snow", seed = 4, tr = TR_NEAR, col = SNOWCOL, rot = {-30, 30}},
	{name = "NearCrystal", part = Near, tex = SPARKLE, rate = 7, size = 1.7, env = 0.7, life = {5, 7}, fall = 2.0, drag = 1, light = 1, infl = 0, wmul = 0.9, kind = "crystal", seed = 5, tr = TWINKLE, col = CRYSTALCOL, rot = {-70, 70}},
	{name = "Swirl", part = GroundP, tex = SOFT, rate = 70, size = 2.6, env = 1.2, life = {2.2, 3.2}, fall = -0.3, drag = 1, light = 0.1, infl = 0.9, wmul = 1.7, kind = "swirl", seed = 6, tr = TR_SWIRL, col = SNOWCOL, rot = {-15, 15}},
	{name = "Glitter", part = GroundP, tex = SPARKLE, rate = 38, size = 0.26, env = 0.14, life = {0.5, 1.1}, fall = 0, drag = 0, light = 1, infl = 0, wmul = 0, kind = "glitter", seed = 7, tr = TWINKLE, col = CRYSTALCOL, rot = {-60, 60}},
}

for _, L in ipairs(Layers) do
	local e = Instance.new("ParticleEmitter")
	e.Texture = L.tex
	e.Color = L.col
	e.Lifetime = NumberRange.new(L.life[1], L.life[2])
	e.Rate = 0
	e.Speed = NumberRange.new(0, 0)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Transparency = L.tr
	e.Size = SizeSeq(L.size * Settings.Size, L.env * Settings.Size)
	e.LightEmission = L.light
	e.LightInfluence = L.infl
	e.Drag = L.drag
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(L.rot[1], L.rot[2])
	e.Shape = Enum.ParticleEmitterShape.Box
	e.LockedToPart = false
	e.Parent = L.part
	L.e = e
end

local LastSize = Settings.Size
local function UpdateSizes()
	for _, L in ipairs(Layers) do
		local k = L.kind
		local s = Cur.Size
		if k == "glitter" then s = 1 end
		L.e.Size = SizeSeq(L.size * s, L.env * s)
	end
	LastSize = Cur.Size
end

local function UpdateRates()
	local Q = Settings.Quality
	local open = Cur.Shelter
	local dayF = Clamp(Pal.Bright / 2.3, 0.3, 1)
	local windF = Clamp(Cur.WindStr / 18, 0.15, 1.5)
	for _, L in ipairs(Layers) do
		local r = 0
		if L.kind == "snow" then
			r = L.rate * Cur.Snow * Q * open
		elseif L.kind == "crystal" then
			r = L.rate * Cur.Crystal * Q * open
		elseif L.kind == "swirl" then
			r = L.rate * Cur.Swirl * windF * Q * open
		elseif L.kind == "glitter" then
			if Settings.Glitter then
				r = L.rate * Clamp(Cur.Crystal, 0, 3) * 0.5 * Q * dayF
			end
		end
		L.e.Rate = r
	end
end

-- wind: terminal velocity = acceleration / drag, so accel = wind * drag
local function UpdateWind(t)
	local th = math.rad(Settings.WindDir)
	local dx, dz = math.cos(th), math.sin(th)
	for _, L in ipairs(Layers) do
		if L.kind ~= "glitter" then
			local gust = Clamp(0.5 + math.noise(t * 0.12, L.seed * 7.31, 0.37) * 1.2, 0.15, 1.6)
			local sway = math.noise(t * 0.5, L.seed * 3.17, 5.43) * 1.6
			local S = Cur.WindStr * gust * L.wmul
			local wx = dx * S + (-dz) * S * sway * 0.5
			local wz = dz * S + dx * S * sway * 0.5
			local flutter = 1 + math.noise(t * 0.9, L.seed * 1.91, 2.71) * 0.5
			local d = L.drag
			L.e.Acceleration = Vector3.new(wx * d, (-L.fall * flutter) * d, wz * d)
		end
	end
end

-- ======================================================================
-- RAY CHECKS (shelter + ground height)
-- ======================================================================
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.RespectCanCollide = true
local GroundY = 0
local Sheltered = false

local function UpdateRay()
	local cam = Workspace.CurrentCamera
	local cp = cam.CFrame.Position
	local char = LocalPlayer.Character
	local ignore = {RigFolder}
	if char then table.insert(ignore, char) end
	RayParams.FilterDescendantsInstances = ignore

	local base = cp
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then base = root.Position end

	local down = Workspace:Raycast(Vector3.new(cp.X, base.Y + 4, cp.Z), Vector3.new(0, -80, 0), RayParams)
	GroundY = down and down.Position.Y or (base.Y - 3)

	if Settings.Shelter then
		local up = Workspace:Raycast(cp, Vector3.new(0, 140, 0), RayParams)
		local up2 = nil
		if root then
			up2 = Workspace:Raycast(root.Position, Vector3.new(0, 140, 0), RayParams)
		end
		Sheltered = (up ~= nil) or (up2 ~= nil)
	else
		Sheltered = false
	end
end

-- ======================================================================
-- CHARACTER EFFECTS (cold breath + footstep snow puffs)
-- ======================================================================
local CharFX = {}

local function ClearCharFX()
	for _, k in ipairs({"Att1", "Att2"}) do
		if CharFX[k] then
			pcall(function() CharFX[k]:Destroy() end)
		end
	end
	CharFX = {}
end

local function SetupChar(char)
	ClearCharFX()
	local head = char:WaitForChild("Head", 6)
	local root = char:WaitForChild("HumanoidRootPart", 6)
	local hum = char:WaitForChild("Humanoid", 6)
	if not (head and root and hum) then return end

	local a1 = Instance.new("Attachment")
	a1.Name = "SnowBreathAtt"
	a1.Position = Vector3.new(0, -0.15, -0.65)
	a1.Parent = head
	local breath = Instance.new("ParticleEmitter")
	breath.Texture = SOFT
	breath.Color = SNOWCOL
	breath.Size = NumberSequence.new({NSK(0, 0.2), NSK(1, 1.25)})
	breath.Transparency = NumberSequence.new({NSK(0, 1), NSK(0.15, 0.55), NSK(1, 1)})
	breath.Lifetime = NumberRange.new(1.1, 1.5)
	breath.Speed = NumberRange.new(2, 3.2)
	breath.SpreadAngle = Vector2.new(22, 22)
	breath.EmissionDirection = Enum.NormalId.Front
	breath.Drag = 1.2
	breath.Acceleration = Vector3.new(0, 0.6, 0)
	breath.LightInfluence = 0.8
	breath.Rate = 0
	breath.Parent = a1

	local a2 = Instance.new("Attachment")
	a2.Name = "SnowStepAtt"
	a2.Position = Vector3.new(0, -2.6, 0)
	a2.Parent = root
	local steps = Instance.new("ParticleEmitter")
	steps.Texture = SOFT
	steps.Color = ColorSequence.new(RGB(238, 246, 255))
	steps.Size = NumberSequence.new({NSK(0, 0.5, 0.2), NSK(1, 1.7, 0.4)})
	steps.Transparency = NumberSequence.new({NSK(0, 0.55), NSK(0.4, 0.7), NSK(1, 1)})
	steps.Lifetime = NumberRange.new(0.5, 0.95)
	steps.Speed = NumberRange.new(2, 4)
	steps.SpreadAngle = Vector2.new(70, 70)
	steps.EmissionDirection = Enum.NormalId.Top
	steps.Drag = 2
	steps.Acceleration = Vector3.new(0, 1.5, 0)
	steps.LightInfluence = 0.9
	steps.Rate = 0
	steps.Parent = a2

	CharFX = {Att1 = a1, Att2 = a2, Breath = breath, Steps = steps, Root = root, Hum = hum}
end

Connect(LocalPlayer.CharacterAdded, function(c)
	task.spawn(SetupChar, c)
end)
if LocalPlayer.Character then
	task.spawn(SetupChar, LocalPlayer.Character)
end

local function UpdateCharFX()
	if CharFX.Breath and CharFX.Breath.Parent and CharFX.Root and CharFX.Root.Parent then
		local vel = CharFX.Root.AssemblyLinearVelocity
		local sp = vel.Magnitude
		local cycle = (sp > 16) and 2.2 or 3.6
		local ph = tick() % cycle
		local cold = Clamp(1.4 - Pal.Bright / 3, 0.5, 1.1)
		CharFX.Breath.Rate = (Settings.Breath and ph < 1.1) and (30 * cold) or 0

		local hv = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local grounded = CharFX.Hum and CharFX.Hum.FloorMaterial ~= Enum.Material.Air
		CharFX.Steps.Rate = (Settings.Steps and grounded and hv > 2) and (6 + hv * 1.1) or 0
	end
end

-- ======================================================================
-- SNOW COVER (client-side recolor of terrain + big flat parts, fully restorable)
-- ======================================================================
local Cover = {Active = false, Orig = setmetatable({}, {__mode = "k"}), Terrain = {}, Token = 0, Conn = nil}
local COVER_COL = RGB(238, 246, 255)
local SKIP_MAT = {
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Water] = true,
}
local TERRAIN_SNOW = {
	[Enum.Material.Grass] = RGB(238, 246, 255),
	[Enum.Material.LeafyGrass] = RGB(232, 242, 252),
	[Enum.Material.Ground] = RGB(224, 233, 244),
	[Enum.Material.Mud] = RGB(214, 224, 238),
	[Enum.Material.Sand] = RGB(240, 245, 252),
	[Enum.Material.Sandstone] = RGB(232, 238, 248),
	[Enum.Material.Rock] = RGB(206, 217, 232),
	[Enum.Material.Slate] = RGB(200, 212, 230),
	[Enum.Material.Basalt] = RGB(196, 208, 226),
	[Enum.Material.Limestone] = RGB(226, 234, 246),
	[Enum.Material.Cobblestone] = RGB(214, 224, 238),
	[Enum.Material.Asphalt] = RGB(210, 220, 236),
	[Enum.Material.Pavement] = RGB(214, 224, 238),
	[Enum.Material.Concrete] = RGB(222, 232, 244),
}

local function InCharacter(p)
	local m = p:FindFirstAncestorOfClass("Model")
	while m do
		if m:FindFirstChildOfClass("Humanoid") then return true end
		local par = m.Parent
		m = par and par:FindFirstAncestorOfClass("Model") or nil
	end
	return false
end

local function Coverable(p)
	if not p:IsA("BasePart") or p:IsA("Terrain") then return false end
	if p.Transparency > 0.6 or SKIP_MAT[p.Material] then return false end
	local s = p.Size
	if s.X * s.Z < 120 then return false end
	if p.CFrame.UpVector.Y < 0.85 then return false end
	if p:IsDescendantOf(RigFolder) then return false end
	if InCharacter(p) then return false end
	return true
end

local function CoverPart(p)
	if Cover.Orig[p] then return end
	Cover.Orig[p] = {Color = p.Color, Material = p.Material}
	p.Color = p.Color:Lerp(COVER_COL, 0.9)
	p.Material = Enum.Material.Snow
end

local function StartCover()
	if Cover.Active then return end
	Cover.Active = true
	Cover.Token = Cover.Token + 1
	local token = Cover.Token
	for m, col in pairs(TERRAIN_SNOW) do
		local ok, c = pcall(function() return Terrain:GetMaterialColor(m) end)
		if ok then
			Cover.Terrain[m] = c
			pcall(function() Terrain:SetMaterialColor(m, col) end)
		end
	end
	task.spawn(function()
		local list = Workspace:GetDescendants()
		for i, d in ipairs(list) do
			if token ~= Cover.Token then return end
			if Coverable(d) then
				pcall(CoverPart, d)
			end
			if i % 300 == 0 then task.wait() end
		end
		if token == Cover.Token then
			Notify("Snow Cover", "Applied", 3)
		end
	end)
	Cover.Conn = Workspace.DescendantAdded:Connect(function(d)
		if not Cover.Active then return end
		task.defer(function()
			if Cover.Active and d.Parent and Coverable(d) then
				pcall(CoverPart, d)
			end
		end)
	end)
end

local function StopCover()
	if not Cover.Active then return end
	Cover.Active = false
	Cover.Token = Cover.Token + 1
	if Cover.Conn then
		Cover.Conn:Disconnect()
		Cover.Conn = nil
	end
	for m, c in pairs(Cover.Terrain) do
		pcall(function() Terrain:SetMaterialColor(m, c) end)
	end
	Cover.Terrain = {}
	for p, d in pairs(Cover.Orig) do
		if p.Parent then
			pcall(function()
				p.Color = d.Color
				p.Material = d.Material
			end)
		end
	end
	Cover.Orig = setmetatable({}, {__mode = "k"})
end

-- ======================================================================
-- FROST VIGNETTE OVERLAY
-- ======================================================================
local OGui = Instance.new("ScreenGui")
OGui.Name = "SnowWorldOverlay"
OGui.ResetOnSpawn = false
OGui.IgnoreGuiInset = true
OGui.DisplayOrder = 5
OGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ParentGui(OGui)

local Edges = {}
local function Edge(pos, size, rot)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = RGB(225, 240, 255)
	f.BorderSizePixel = 0
	f.Position = pos
	f.Size = size
	f.BackgroundTransparency = 1
	f.Active = false
	f.Parent = OGui
	local g = Instance.new("UIGradient")
	g.Rotation = rot
	g.Transparency = NumberSequence.new({NSK(0, 0), NSK(1, 1)})
	g.Parent = f
	table.insert(Edges, f)
end
Edge(UDim2.new(0, 0, 0, 0), UDim2.new(0.2, 0, 1, 0), 0)
Edge(UDim2.new(0.8, 0, 0, 0), UDim2.new(0.2, 0, 1, 0), 180)
Edge(UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.22, 0), 90)
Edge(UDim2.new(0, 0, 0.78, 0), UDim2.new(1, 0, 0.22, 0), 270)

local function UpdateFrost()
	local bt = 1 - Clamp(Cur.Frost, 0, 1) * 0.8
	for _, f in ipairs(Edges) do
		f.BackgroundTransparency = bt
	end
end

-- ======================================================================
-- GUI
-- ======================================================================
local PALETTE = ColorSequence.new({
	CSK(0, RGB(60, 150, 255)),
	CSK(0.35, RGB(110, 100, 255)),
	CSK(0.7, RGB(60, 200, 230)),
	CSK(1, RGB(60, 150, 255)),
})

local Gui = Instance.new("ScreenGui")
Gui.Name = "SnowWorldUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 999
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ParentGui(Gui)

local VP = Workspace.CurrentCamera.ViewportSize
local BaseScale = math.clamp(math.min(VP.Y / 340, VP.X / 500), 0.6, 1)
local WIN_W, WIN_H = 460, 290

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

local function Frame(props)
	local f = Instance.new("Frame")
	for k, v in pairs(props) do f[k] = v end
	return f
end

local function Label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	for k, v in pairs(props) do l[k] = v end
	return l
end

local Holder = Frame({
	Size = UDim2.fromOffset(WIN_W, WIN_H),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = Gui,
})
local Window = Frame({
	Size = UDim2.fromScale(1, 1),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.06,
	ClipsDescendants = true,
	Parent = Holder,
})
Corner(Window, 14)
local WScale = Instance.new("UIScale")
WScale.Scale = 0.01
WScale.Parent = Window
do
	local bg = Instance.new("UIGradient")
	bg.Color = ColorSequence.new(RGB(16, 22, 42), RGB(8, 12, 26))
	bg.Rotation = 60
	bg.Parent = Window
end
local WStroke = Instance.new("UIStroke")
WStroke.Thickness = 2
WStroke.Color = Color3.new(1, 1, 1)
WStroke.Parent = Window
Grad(WStroke, 0)

-- snowflakes inside the window (tiny decoration)
local Deco = Frame({Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Parent = Window})
local DecoFlakes = {}
for i = 1, 16 do
	local s = math.random(2, 5)
	local f = Frame({
		Size = UDim2.fromOffset(s, s),
		Position = UDim2.fromScale(math.random(), math.random()),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = Deco,
	})
	Corner(f, 5)
	table.insert(DecoFlakes, {f = f, v = math.random(5, 13) / 100, d = (math.random() - 0.5) * 0.02})
end

local TopBar = Frame({Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = RGB(14, 20, 40), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5, Parent = Window})
local TitleLbl = Label({
	Size = UDim2.new(0, 160, 1, 0), Position = UDim2.fromOffset(14, 0),
	Text = "SNOW WORLD", Font = Enum.Font.GothamBlack, TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = TopBar,
})
Grad(TitleLbl, 0)
Label({
	Size = UDim2.new(0, 140, 1, 0), Position = UDim2.fromOffset(142, 3),
	Text = "realistic winter", Font = Enum.Font.Gotham, TextSize = 10,
	TextColor3 = RGB(150, 165, 195), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = TopBar,
})

local function TopBtn(text, xOff)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(28, 28)
	b.Position = UDim2.new(1, xOff, 0.5, -14)
	b.BackgroundColor3 = RGB(32, 40, 70)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = false
	b.ZIndex = 7
	b.Parent = TopBar
	Corner(b, 14)
	return b
end
local MinBtn = TopBtn("-", -68)
local CloseBtn = TopBtn("x", -36)

local function Ripple(btn, x, y)
	local sc = WScale.Scale
	local r = Frame({
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x - btn.AbsolutePosition.X) / sc, (y - btn.AbsolutePosition.Y) / sc),
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 20,
		Parent = btn,
	})
	Corner(r, 200)
	local big = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2.2 / sc
	T(r, 0.5, {Size = UDim2.fromOffset(big, big), BackgroundTransparency = 1})
	task.delay(0.55, function() r:Destroy() end)
end

local function MakeBtn(parent, text, cb, size, order)
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.Text = ""
	b.AutoButtonColor = false
	b.ClipsDescendants = true
	b.LayoutOrder = order or 0
	b.Parent = parent
	Corner(b, 8)
	Grad(b)
	Label({Size = UDim2.fromScale(1, 1), Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = b})
	Connect(b.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch then Ripple(b, i.Position.X, i.Position.Y) end
	end)
	Connect(b.Activated, function() if cb then cb() end end)
	return b
end

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

-- sidebar / pages
local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Size = UDim2.new(0, 88, 1, -46)
Sidebar.Position = UDim2.fromOffset(6, 42)
Sidebar.BackgroundTransparency = 1
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 0
Sidebar.CanvasSize = UDim2.new()
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.ZIndex = 4
Sidebar.Parent = Window
do
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 3)
	l.Parent = Sidebar
end
local Content = Frame({Size = UDim2.new(1, -104, 1, -50), Position = UDim2.fromOffset(98, 44), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 4, Parent = Window})

local Pages, TabBtns, CurrentTab = {}, {}, nil

local function SelectTab(name)
	if CurrentTab == name then return end
	CurrentTab = name
	for n, pg in pairs(Pages) do
		local active = (n == name)
		local tb = TabBtns[n]
		tb.Grad.Enabled = active
		T(tb.Btn, 0.25, {BackgroundColor3 = active and Color3.new(1, 1, 1) or RGB(24, 32, 58)})
		T(tb.Lbl, 0.25, {TextColor3 = active and Color3.new(1, 1, 1) or RGB(160, 175, 205)})
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

local function CreateTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 30)
	btn.BackgroundColor3 = RGB(24, 32, 58)
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ClipsDescendants = true
	btn.Parent = Sidebar
	Corner(btn, 8)
	local g = Grad(btn)
	g.Enabled = false
	local lbl = Label({Size = UDim2.fromScale(1, 1), Text = name, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = RGB(160, 175, 205), ZIndex = 3, Parent = btn})
	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = Content
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 6)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = page
	local pd = Instance.new("UIPadding")
	pd.PaddingRight = UDim.new(0, 6)
	pd.PaddingBottom = UDim.new(0, 8)
	pd.Parent = page
	Pages[name] = page
	TabBtns[name] = {Btn = btn, Lbl = lbl, Grad = g}
	Connect(btn.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch then Ripple(btn, i.Position.X, i.Position.Y) end
	end)
	Connect(btn.Activated, function() SelectTab(name) end)
	return page
end

-- components
local function Section(page, text)
	local l = Label({
		Size = UDim2.new(1, -4, 0, 20), Text = string.upper(text), Font = Enum.Font.GothamBlack, TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = Order(page), Parent = page,
	})
	Grad(l, 0)
end

local function InfoLabel(page, text, height)
	local holder = Frame({Size = UDim2.new(1, -4, 0, height or 24), BackgroundColor3 = RGB(22, 30, 52), LayoutOrder = Order(page), Parent = page})
	Corner(holder, 8)
	return Label({
		Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = text, Font = Enum.Font.Gotham, TextSize = 12,
		TextColor3 = RGB(215, 225, 245), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = holder,
	})
end

local function Button(page, text, cb)
	return MakeBtn(page, text, cb, UDim2.new(1, -4, 0, 34), Order(page))
end

local function ChipRow(page, options, default, cb)
	local row = Frame({Size = UDim2.new(1, -4, 0, 30), BackgroundTransparency = 1, LayoutOrder = Order(page), Parent = page})
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.Padding = UDim.new(0, 4)
	lay.Parent = row
	local n = #options
	local chips = {}
	local obj = {}
	function obj.Select(idx)
		for i, c in ipairs(chips) do
			local on = (i == idx)
			c.g.Enabled = on
			T(c.b, 0.2, {BackgroundColor3 = on and Color3.new(1, 1, 1) or RGB(28, 36, 62)})
		end
	end
	for i, name in ipairs(options) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1 / n, -(4 * (n - 1)) / n, 1, 0)
		b.BackgroundColor3 = RGB(28, 36, 62)
		b.Text = name
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.TextColor3 = Color3.new(1, 1, 1)
		b.AutoButtonColor = false
		b.ClipsDescendants = true
		b.Parent = row
		Corner(b, 8)
		local g = Grad(b)
		g.Enabled = false
		table.insert(chips, {b = b, g = g})
		Connect(b.InputBegan, function(inp)
			if inp.UserInputType == Enum.UserInputType.Touch then Ripple(b, inp.Position.X, inp.Position.Y) end
		end)
		Connect(b.Activated, function()
			obj.Select(i)
			if cb then cb(i, name) end
		end)
	end
	obj.Select(default)
	return obj
end

local function Toggle(page, text, default, cb)
	local holder = Instance.new("TextButton")
	holder.Size = UDim2.new(1, -4, 0, 34)
	holder.BackgroundColor3 = RGB(22, 30, 52)
	holder.Text = ""
	holder.AutoButtonColor = false
	holder.LayoutOrder = Order(page)
	holder.Parent = page
	Corner(holder, 8)
	Label({
		Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(10, 0), Text = text, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = RGB(225, 232, 248), TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
	})
	local track = Frame({Size = UDim2.fromOffset(42, 20), Position = UDim2.new(1, -52, 0.5, -10), BackgroundColor3 = RGB(46, 56, 86), Parent = holder})
	Corner(track, 10)
	local tg = Grad(track)
	tg.Enabled = false
	local knob = Frame({Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track})
	Corner(knob, 8)
	local state = default and true or false
	local function render(anim)
		tg.Enabled = state
		local gp = state and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2)
		local gc = state and Color3.new(1, 1, 1) or RGB(46, 56, 86)
		if anim then
			T(knob, 0.25, {Position = gp}, Enum.EasingStyle.Back)
			T(track, 0.25, {BackgroundColor3 = gc})
		else
			knob.Position = gp
			track.BackgroundColor3 = gc
		end
	end
	render(false)
	Connect(holder.Activated, function()
		state = not state
		render(true)
		if cb then cb(state) end
	end)
	return {Set = function(v) state = v render(true) end}
end

local function Slider(page, text, min, max, def, cb, decimals)
	decimals = decimals or 0
	local holder = Frame({Size = UDim2.new(1, -4, 0, 46), BackgroundColor3 = RGB(22, 30, 52), LayoutOrder = Order(page), Parent = page})
	Corner(holder, 8)
	Label({
		Size = UDim2.new(1, -70, 0, 20), Position = UDim2.fromOffset(10, 4), Text = text, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = RGB(225, 232, 248), TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
	})
	local val = Label({
		Size = UDim2.fromOffset(56, 20), Position = UDim2.new(1, -64, 0, 4), Text = tostring(def), Font = Enum.Font.Code, TextSize = 12,
		TextColor3 = RGB(185, 200, 230), TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
	})
	local bar = Frame({Size = UDim2.new(1, -20, 0, 8), Position = UDim2.new(0, 10, 0, 30), BackgroundColor3 = RGB(40, 50, 78), Parent = holder})
	Corner(bar, 4)
	local fill = Frame({Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar})
	Corner(fill, 4)
	Grad(fill)
	local knob = Frame({Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = bar})
	Corner(knob, 7)
	local function set(v, silent)
		local m = 10 ^ decimals
		v = math.clamp(math.floor(v * m + 0.5) / m, min, max)
		local a = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		val.Text = tostring(v)
		if not silent and cb then cb(v) end
	end
	set(def, true)
	local function fromX(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		set(min + (max - min) * a, false)
	end
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
	return {Set = set}
end

local Sliders = {}
local function Bind(page, text, key, min, max, decimals)
	Sliders[key] = Slider(page, text, min, max, Settings[key], function(v) Settings[key] = v end, decimals)
end

-- ---------------- TAB: Weather ----------------
local TabWeather = CreateTab("Weather")
local Row1, Row2
local function ApplyPreset(name)
	local p = Presets[name]
	if not p then return end
	for k, v in pairs(p) do
		Settings[k] = v
		if Sliders[k] then Sliders[k].Set(v, true) end
	end
	Notify("Weather", name .. " applied", 2)
end
Section(TabWeather, "Presets")
Row1 = ChipRow(TabWeather, PresetRow1, 1, function(_, name)
	Row2.Select(nil)
	ApplyPreset(name)
end)
Row2 = ChipRow(TabWeather, PresetRow2, nil, function(_, name)
	Row1.Select(nil)
	ApplyPreset(name)
end)
Section(TabWeather, "Quality (particles)")
local QUALITY = {0.35, 0.7, 1.0, 1.5}
ChipRow(TabWeather, {"Low", "Mid", "High", "Ultra"}, 3, function(i)
	Settings.Quality = QUALITY[i]
	Notify("Quality", "x" .. QUALITY[i], 2)
end)
InfoLabel(TabWeather, "Sparkle = bright snowfield with glowing star crystals.", 36)

-- ---------------- TAB: Snow ----------------
local TabSnow = CreateTab("Snow")
Section(TabSnow, "Snowfall")
Bind(TabSnow, "Snow Amount", "Snow", 0, 3, 2)
Bind(TabSnow, "Flake Size", "Size", 0.4, 2.5, 2)
Bind(TabSnow, "Star Crystals", "Crystal", 0, 4, 1)
Section(TabSnow, "Wind")
Bind(TabSnow, "Wind Strength", "WindStr", 0, 60, 0)
Bind(TabSnow, "Wind Direction", "WindDir", 0, 360, 0)
Bind(TabSnow, "Ground Blown Snow", "Swirl", 0, 1, 2)
Section(TabSnow, "Screen")
Bind(TabSnow, "Frost Vignette", "Frost", 0, 1, 2)

-- ---------------- TAB: Sky ----------------
local TabSky = CreateTab("Sky")
Section(TabSky, "Time of Day")
local ClockLbl = InfoLabel(TabSky, "Time: --:--", 24)
Bind(TabSky, "Time", "Clock", 0, 24, 1)
Toggle(TabSky, "Auto day cycle", false, function(s) Settings.Auto = s end)
Bind(TabSky, "Day length (min)", "DayLen", 1, 30, 0)
Section(TabSky, "Atmosphere")
Bind(TabSky, "Fog Density", "Fog", 0, 0.8, 2)
Bind(TabSky, "Haze", "Haze", 0, 6, 1)
Bind(TabSky, "Cloud Cover", "Cloud", 0, 1, 2)
Bind(TabSky, "Cloud Density", "CloudDen", 0, 1, 2)
Section(TabSky, "Look")
Bind(TabSky, "Bloom Glow", "Bloom", 0, 2.5, 2)
Bind(TabSky, "Sun Rays", "Rays", 0, 0.6, 2)
Bind(TabSky, "Saturation", "Sat", -0.3, 0.5, 2)
Bind(TabSky, "Contrast", "Contrast", 0, 0.3, 2)
Bind(TabSky, "Gloom (darker)", "Gloom", 0, 0.8, 2)

-- ---------------- TAB: World ----------------
local TabWorld = CreateTab("World")
Section(TabWorld, "Environment")
Toggle(TabWorld, "Shelter detection", true, function(s) Settings.Shelter = s end)
Toggle(TabWorld, "Snow glitter (ground)", true, function(s) Settings.Glitter = s end)
Section(TabWorld, "Character")
Toggle(TabWorld, "Cold breath", true, function(s) Settings.Breath = s end)
Toggle(TabWorld, "Footstep snow puffs", true, function(s) Settings.Steps = s end)
Section(TabWorld, "Snow Cover")
Toggle(TabWorld, "Cover ground in snow", false, function(s)
	Settings.Cover = s
	if s then
		StartCover()
		Notify("Snow Cover", "Applying...", 2)
	else
		StopCover()
		Notify("Snow Cover", "Restored", 2)
	end
end)
Button(TabWorld, "Re-apply Snow Cover", function()
	if Settings.Cover then
		StopCover()
		StartCover()
	else
		Notify("Snow Cover", "Turn the toggle on first", 3)
	end
end)

-- ---------------- TAB: UI ----------------
local TabUI = CreateTab("UI")
local GradSpeed = 45
Section(TabUI, "Interface")
Slider(TabUI, "UI Scale", 0.5, 1.4, BaseScale, function(v)
	BaseScale = v
	if Holder.Visible then WScale.Scale = v end
end, 2)
Slider(TabUI, "Window Transparency", 0, 0.6, 0.06, function(v)
	Window.BackgroundTransparency = v
end, 2)
Slider(TabUI, "Gradient Speed", 0, 180, GradSpeed, function(v) GradSpeed = v end, 0)

-- ======================================================================
-- ORB (minimize)
-- ======================================================================
local Orb = Instance.new("TextButton")
Orb.Size = UDim2.fromOffset(0, 0)
Orb.AnchorPoint = Vector2.new(0.5, 0.5)
Orb.Position = UDim2.fromScale(0.1, 0.3)
Orb.BackgroundColor3 = Color3.new(1, 1, 1)
Orb.Text = "*"
Orb.Font = Enum.Font.GothamBlack
Orb.TextSize = 28
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
local Ring = Frame({Size = UDim2.fromOffset(52, 52), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 9, Parent = Orb})
Corner(Ring, 100)
local RingStroke = Instance.new("UIStroke")
RingStroke.Thickness = 2
RingStroke.Color = Color3.new(1, 1, 1)
RingStroke.Parent = Ring
Grad(RingStroke)

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
		local vp = Workspace.CurrentCamera.ViewportSize
		local hw, hh = WIN_W * BaseScale / 2, WIN_H * BaseScale / 2
		local c = Orb.AbsolutePosition + Orb.AbsoluteSize / 2
		local cx = math.clamp(c.X, hw, math.max(hw, vp.X - hw))
		local cy = math.clamp(c.Y, hh, math.max(hh, vp.Y - hh))
		T(Orb, 0.2, {Size = UDim2.fromOffset(0, 0)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.2, function()
			Orb.Visible = false
			Holder.Position = UDim2.fromOffset(cx, cy)
			Holder.Visible = true
			WScale.Scale = 0.01
			T(WScale, 0.45, {Scale = BaseScale}, Enum.EasingStyle.Back)
			task.delay(0.45, function() Busy = false end)
		end)
	end
end
MakeDraggable(TopBar, Holder, nil)
MakeDraggable(Orb, Orb, function() SetMinimized(false) end)
Connect(MinBtn.Activated, function() SetMinimized(true) end)

-- ======================================================================
-- DESTROY
-- ======================================================================
local Destroyed = false
local function Destroy()
	if Destroyed then return end
	Destroyed = true
	StopCover()
	ClearCharFX()
	for _, c in ipairs(Conns) do
		pcall(function() c:Disconnect() end)
	end
	Conns = {}
	for i = #Restores, 1, -1 do
		pcall(Restores[i])
	end
	Restores = {}
	if OGui then OGui:Destroy() end
	if Gui then Gui:Destroy() end
	getgenv().SnowWorld = nil
end
getgenv().SnowWorld = {Destroy = Destroy, Settings = Settings, ApplyPreset = ApplyPreset}

Button(TabUI, "Close & Restore Lighting", function()
	Notify("Snow World", "Restoring...", 2)
	T(WScale, 0.3, {Scale = 0.01}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.35, Destroy)
end)
Connect(CloseBtn.Activated, function()
	T(WScale, 0.3, {Scale = 0.01}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.35, Destroy)
end)

-- ======================================================================
-- MAIN LOOP
-- ======================================================================
local windTimer, rayTimer, clockTimer = 0, 0, 0
UpdateRay()
UpdatePalette(Cur.Clock)

Connect(RunService.Heartbeat, function(dt)
	if Destroyed then return end
	local now = tick()

	-- auto time
	if Settings.Auto then
		Settings.Clock = (Settings.Clock + dt * 24 / (Settings.DayLen * 60)) % 24
	end

	-- smoothing
	local a = 1 - math.exp(-dt * 2.2)
	for _, k in ipairs(SMOOTH) do
		Cur[k] = Cur[k] + (Settings[k] - Cur[k]) * a
	end
	local diff = ((Settings.Clock - Cur.Clock + 12) % 24) - 12
	Cur.Clock = (Cur.Clock + diff * a) % 24
	local openTarget = Sheltered and 0 or 1
	Cur.Shelter = Cur.Shelter + (openTarget - Cur.Shelter) * (1 - math.exp(-dt * 4))

	ApplyLighting()
	UpdateFrost()

	-- periodic checks
	rayTimer = rayTimer + dt
	if rayTimer >= 0.2 then
		rayTimer = 0
		UpdateRay()
	end
	windTimer = windTimer + dt
	if windTimer >= 0.1 then
		windTimer = 0
		UpdateWind(now)
	end

	if math.abs(Cur.Size - LastSize) > 0.02 then
		UpdateSizes()
	end
	UpdateRates()
	UpdateCharFX()

	-- rig follows the camera
	local cam = Workspace.CurrentCamera
	local cp = cam.CFrame.Position
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then flat = flat.Unit else flat = Vector3.new(0, 0, 0) end
	local th = math.rad(Settings.WindDir)
	local wvec = Vector3.new(math.cos(th), 0, math.sin(th)) * Cur.WindStr
	Wide.CFrame = CFrame.new(cp + Vector3.new(0, 46, 0) - wvec * 2.6 + flat * 20)
	Near.CFrame = CFrame.new(cp + Vector3.new(0, 13, 0) + flat * 10 - wvec * 0.5)
	GroundP.CFrame = CFrame.new(Vector3.new(cp.X, GroundY + 0.4, cp.Z) + flat * 22 - wvec * 0.4)

	-- gradients
	for i = #Gradients, 1, -1 do
		local g = Gradients[i]
		if g.Parent then
			if g.Enabled then g.Rotation = (g.Rotation + dt * GradSpeed) % 360 end
		else
			table.remove(Gradients, i)
		end
	end

	-- window decoration flakes
	if Holder.Visible then
		for _, p in ipairs(DecoFlakes) do
			local pos = p.f.Position
			local y = pos.Y.Scale + p.v * dt
			local x = pos.X.Scale + p.d * dt
			if y > 1.05 then
				y = -0.05
				x = math.random()
			end
			p.f.Position = UDim2.fromScale(x, y)
		end
	end

	-- orb pulse
	if Orb.Visible then
		local pr = (now % 1.6) / 1.6
		local s = 52 + pr * 26
		Ring.Size = UDim2.fromOffset(s, s)
		RingStroke.Transparency = pr
	end

	-- clock label / slider sync
	clockTimer = clockTimer + dt
	if clockTimer >= 0.5 then
		clockTimer = 0
		local h = math.floor(Cur.Clock)
		local m = math.floor((Cur.Clock - h) * 60)
		ClockLbl.Text = string.format("Time: %02d:%02d   %s", h, m, Sheltered and "(sheltered)" or "")
		if Settings.Auto and Sliders.Clock then
			Sliders.Clock.Set(Settings.Clock, true)
		end
	end
end)

-- ======================================================================
-- START
-- ======================================================================
SelectTab("Weather")
Holder.Visible = true
T(WScale, 0.55, {Scale = BaseScale}, Enum.EasingStyle.Back)
Notify("Snow World", "Loaded - snow is fading in", 4)
