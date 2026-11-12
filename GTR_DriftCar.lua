--[[
	GT-R風 スポーツカー (自分にしか見えない / ドリフト可 / 乗り降り可)
	モバイル用 (タッチ操作のGui付き)
	・パーツはすべてクライアント側で生成 → 見えるのは自分だけ
	・GTウイング / 右ハンドルの内装 / 4連テールランプ / 4本出しマフラー再現
	・操作: ◀ ▶ = ハンドル / ▲ = アクセル / ▼ = ブレーキ&バック / DRIFT = サイドブレーキ
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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
if env.GTRCleanup then
	pcall(env.GTRCleanup)
end

------------------------------------------------------------------
-- 設定
------------------------------------------------------------------
local C_BODY = Color3.fromRGB(236, 238, 241)   -- パールホワイト
local C_GLOSS = Color3.fromRGB(16, 16, 18)
local C_CARBON = Color3.fromRGB(30, 30, 34)
local C_GLASS = Color3.fromRGB(26, 36, 46)
local C_CHROME = Color3.fromRGB(195, 200, 205)
local C_INT = Color3.fromRGB(22, 22, 24)
local C_INT2 = Color3.fromRGB(58, 58, 64)
local C_ORANGE = Color3.fromRGB(255, 118, 20)
local C_TIRE = Color3.fromRGB(18, 18, 20)
local C_RIM = Color3.fromRGB(46, 46, 52)
local C_TITAN = Color3.fromRGB(150, 140, 125)
local CYAN = Color3.fromRGB(70, 230, 255)
local WHITE = Color3.fromRGB(235, 245, 250)

local MAT_PLASTIC = Enum.Material.SmoothPlastic
local MAT_METAL = Enum.Material.Metal
local MAT_NEON = Enum.Material.Neon
local MAT_GLASS = Enum.Material.Glass

-- 車体寸法 (stud) : 前=+f / 右=+r
local FRONT_AX = 5.35
local REAR_AX = -4.58
local WHEEL_X = 2.7
local WR = 1.22           -- タイヤ半径
local ARCH_R = 1.55       -- ホイールアーチ半径
local CAB_FRONT = 2.0     -- フロントガラス下端
local CAB_REAR = -5.3     -- リアガラス下端
local SEAT_HRP = CFrame.new(1.2, 2.1, 1.25) -- 運転席のHRP位置(右ハンドル) 調整用
local SW_BASE = CFrame.new(1.2, 3.0, -0.5) * CFrame.Angles(-0.4, 0, 0) -- ハンドル位置

-- 走行性能
local G = 35              -- 重力加速度(studs/s^2)
local MU = 1.35           -- タイヤのグリップ
local A_DIST = 5.35       -- 重心→前軸
local B_DIST = 4.58       -- 重心→後軸
local WBS = A_DIST + B_DIST
local K2 = 22             -- 慣性(回転しやすさ)
local VMAX = 250          -- 最高速

local Car = nil
local Driving = false
local CamMode = 1         -- 1:外 2:車内
local Inp = {left = false, right = false, gas = false, brake = false, drift = false}
local Conns = {}
local gui = nil

------------------------------------------------------------------
-- パーツ生成ヘルパー (座標は 右r / 上y / 前f)
------------------------------------------------------------------
local function CF(r, y, f)
	return CFrame.new(r, y, -f)
end

local function V(r, y, f)
	return Vector3.new(r, y, -f)
end

local function NewPart(parent, size, cf, color, mat, tr, refl)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color or C_BODY
	p.Material = mat or MAT_PLASTIC
	p.Transparency = tr or 0
	p.Reflectance = refl or 0
	p.Parent = parent
	return p
end

local function Box(parent, r, y, f, sr, sy, sf, color, mat, tr, refl)
	return NewPart(parent, Vector3.new(sr, sy, sf), CF(r, y, f), color, mat, tr, refl)
end

local function Bar(parent, a, b, w, h, color, mat, tr, refl)
	local d = b - a
	local len = d.Magnitude
	local up = (math.abs(d.Unit.Y) > 0.98) and Vector3.xAxis or Vector3.yAxis
	return NewPart(parent, Vector3.new(w, h, len), CFrame.lookAt((a + b) / 2, b, up), color, mat, tr, refl)
end

-- 円柱 (軸は元がX軸)
local function NewCyl(parent, size, cf, color, mat, tr, refl)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color or C_BODY
	p.Material = mat or MAT_PLASTIC
	p.Transparency = tr or 0
	p.Reflectance = refl or 0
	p.Parent = parent
	return p
end

-- 前後方向(Z軸)を向いた円柱  len=長さ dia=直径
local function CylZ(parent, r, y, f, len, dia, color, mat, tr, refl)
	return NewCyl(parent, Vector3.new(len, dia, dia), CF(r, y, f) * CFrame.Angles(0, math.pi / 2, 0), color, mat, tr, refl)
end

-- 上下方向(Y軸)を向いた円柱
local function CylY(parent, r, y, f, len, dia, color, mat, tr, refl)
	return NewCyl(parent, Vector3.new(len, dia, dia), CF(r, y, f) * CFrame.Angles(0, 0, math.pi / 2), color, mat, tr, refl)
end

local function Prof(pts, f)
	if f <= pts[1][1] then return pts[1][2] end
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		if f <= b[1] then
			local t = (f - a[1]) / (b[1] - a[1])
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return pts[#pts][2]
end

-- 側面形状 (f, y)
local TOP = {{-8.4, 3.35}, {-7.0, 3.6}, {-5.4, 3.7}, {-3.0, 3.55}, {0, 3.5}, {2.0, 3.6}, {3.2, 3.5}, {5.35, 3.25}, {7.4, 2.85}, {8.4, 2.3}}
local BELT = {{-8.4, 3.35}, {-5.5, 3.55}, {-3, 3.5}, {0, 3.4}, {2.0, 3.45}}
local BOT = {{-8.4, 0.95}, {-7.2, 0.75}, {-5, 0.5}, {5, 0.5}, {7.6, 0.45}, {8.4, 0.62}}
local WID = {{-8.4, 5.9}, {-7.5, 6.5}, {-5.0, 6.8}, {-3.0, 6.75}, {0, 6.4}, {2.5, 6.6}, {5.0, 6.8}, {7.5, 6.2}, {8.4, 5.5}}
local TOPG = {{-5.4, 3.6}, {-3.45, 4.72}, {0, 4.72}, {2.0, 3.5}}

------------------------------------------------------------------
-- ボディ (スライス状に積んで滑らかな曲面を再現)
------------------------------------------------------------------
local DX = 0.3

local function BuildBody(m)
	for i = 0, 55 do
		local f = -8.4 + DX * (i + 0.5)
		local w = Prof(WID, f)
		local bot = Prof(BOT, f)
		local cabin = (f > CAB_REAR and f < CAB_FRONT)

		if not cabin then
			local top = Prof(TOP, f)
			Box(m, 0, (top + bot) / 2, f, 4.6, top - bot, DX + 0.02, C_BODY, MAT_PLASTIC, 0, 0.06)
		end

		for _, s in ipairs({-1, 1}) do
			local outer = w / 2
			local sideTop = cabin and Prof(BELT, f) or (Prof(TOP, f) - 0.05)
			local sideBot = bot
			for _, fa in ipairs({FRONT_AX, REAR_AX}) do
				local dz = f - fa
				if math.abs(dz) < ARCH_R then
					sideBot = math.max(sideBot, WR + math.sqrt(ARCH_R * ARCH_R - dz * dz))
				end
			end
			if sideTop - sideBot > 0.04 then
				Box(m, s * (2.3 + outer) / 2, (sideTop + sideBot) / 2, f, outer - 2.3, sideTop - sideBot, DX + 0.02, C_BODY, MAT_PLASTIC, 0, 0.06)
			end
		end
	end

	-- 室内の床
	Box(m, 0, 0.65, (CAB_FRONT + CAB_REAR) / 2, 4.6, 0.3, CAB_FRONT - CAB_REAR, C_INT)

	-- ホイールハウス内張り
	for _, fa in ipairs({FRONT_AX, REAR_AX}) do
		for _, s in ipairs({-1, 1}) do
			Box(m, s * 2.33, 1.6, fa, 0.05, 2.2, 3.1, C_INT)
		end
	end

	-- サイドスカート
	for _, s in ipairs({-1, 1}) do
		Box(m, s * 3.28, 0.85, 0.4, 0.3, 0.6, 6.8, C_GLOSS, MAT_PLASTIC, 0, 0.1)
	end

	-- フロントスプリッター / 下部インテーク
	Box(m, 0, 0.55, 8.1, 5.8, 0.1, 0.8, C_GLOSS)
	Box(m, 0, 0.9, 8.45, 4.6, 0.5, 0.15, C_GLOSS)
	for _, s in ipairs({-1, 1}) do
		Box(m, s * 2.5, 1.15, 8.4, 1.0, 0.6, 0.2, C_GLOSS)
	end

	-- グリル
	Box(m, 0, 1.6, 8.42, 3.6, 0.95, 0.18, C_GLOSS)
	for i = 0, 4 do
		Box(m, 0, 1.25 + i * 0.19, 8.5, 3.5, 0.05, 0.08, C_INT2, MAT_METAL)
	end
	Box(m, 0, 2.13, 8.4, 3.9, 0.14, 0.25, C_CHROME, MAT_METAL, 0, 0.3)

	-- ヘッドライト
	for _, s in ipairs({-1, 1}) do
		local hcf = CF(s * 2.35, 2.55, 7.15) * CFrame.Angles(0, s * -0.35, 0)
		NewPart(m, Vector3.new(1.55, 0.5, 0.9), hcf, C_GLOSS)
		local lens = NewPart(m, Vector3.new(1.3, 0.28, 0.5), hcf * CFrame.new(0, 0, -0.25), Color3.fromRGB(235, 242, 255), MAT_NEON, 0.15)
		NewPart(m, Vector3.new(1.4, 0.05, 0.06), hcf * CFrame.new(0, 0.27, -0.3), Color3.fromRGB(190, 235, 255), MAT_NEON)
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Front
		sl.Range = 60
		sl.Angle = 70
		sl.Brightness = 2
		sl.Color = Color3.fromRGB(235, 242, 255)
		sl.Parent = lens
	end

	-- ボンネット (ダクト)
	for _, s in ipairs({-1, 1}) do
		Box(m, s * 1.15, Prof(TOP, 4.4) + 0.03, 4.4, 0.55, 0.05, 1.3, C_GLOSS)
		Box(m, s * 1.15, Prof(TOP, 4.4) + 0.05, 4.4, 0.35, 0.03, 1.1, C_INT2, MAT_METAL)
	end

	-- フェンダーのサイドギル
	for _, s in ipairs({-1, 1}) do
		Box(m, s * (Prof(WID, 3.7) / 2 + 0.01), 2.5, 3.7, 0.05, 0.5, 1.0, C_GLOSS)
		Box(m, s * (Prof(WID, 3.7) / 2 + 0.03), 2.5, 3.7, 0.04, 0.05, 1.0, C_CHROME, MAT_METAL)
	end

	-- ドア (ライン / ハンドル)
	for _, s in ipairs({-1, 1}) do
		for _, fl in ipairs({1.6, -2.2}) do
			Box(m, s * (Prof(WID, fl) / 2 + 0.01), 2.2, fl, 0.04, 2.3, 0.05, C_GLOSS)
		end
		Box(m, s * (Prof(WID, -0.5) / 2 + 0.01), 1.1, -0.3, 0.04, 0.05, 3.8, C_GLOSS)
		Box(m, s * (Prof(WID, -1.6) / 2 + 0.04), 3.1, -1.6, 0.08, 0.16, 0.9, C_GLOSS, MAT_PLASTIC, 0, 0.2)
	end

	-- ベルトライン (黒モール)
	local beltPts = {1.5, 0, -3, -5.0}
	for _, s in ipairs({-1, 1}) do
		for i = 1, #beltPts - 1 do
			local f1, f2 = beltPts[i], beltPts[i + 1]
			Bar(m, V(s * 2.93, Prof(BELT, f1) + 0.03, f1), V(s * 2.93, Prof(BELT, f2) + 0.03, f2), 0.12, 0.05, C_GLOSS)
		end
	end

	-- サイドミラー
	for _, s in ipairs({-1, 1}) do
		Box(m, s * 3.5, 3.62, 1.2, 0.9, 0.55, 0.7, C_BODY, MAT_PLASTIC, 0, 0.06)
		Box(m, s * 3.2, 3.5, 1.15, 0.5, 0.15, 0.3, C_GLOSS)
		Box(m, s * 3.5, 3.62, 0.84, 0.8, 0.45, 0.04, C_GLOSS, MAT_PLASTIC, 0, 0.3)
	end

	-- ルーフ / ガラス
	Box(m, 0, 4.78, -1.7, 4.1, 0.2, 3.5, C_BODY, MAT_PLASTIC, 0, 0.06)
	Bar(m, V(0, 3.52, 2.05), V(0, 4.72, 0.1), 4.5, 0.08, C_GLASS, MAT_GLASS, 0.45, 0.1)
	Bar(m, V(0, 4.72, -3.45), V(0, 3.7, -5.35), 4.4, 0.08, C_GLASS, MAT_GLASS, 0.45, 0.1)
	for _, s in ipairs({-1, 1}) do
		Bar(m, V(s * 2.75, 3.5, 2.0), V(s * 2.15, 4.75, 0.05), 0.38, 0.28, C_GLOSS)
		Bar(m, V(s * 2.1, 4.78, -3.45), V(s * 2.75, 3.65, -5.4), 0.55, 0.3, C_BODY, MAT_PLASTIC, 0, 0.06)
	end

	-- サイドウィンドウ (傾斜したガラスを細かく並べる)
	local th = 0.28
	local function Strip(f, widthF, yb, yt, color, mat, tr)
		local h = yt - yb
		local rc = 2.85 - math.tan(th) * h / 2
		for _, s in ipairs({-1, 1}) do
			NewPart(m, Vector3.new(0.06, h / math.cos(th), widthF), CF(s * rc, (yt + yb) / 2, f) * CFrame.Angles(0, 0, s * th), color, mat, tr, 0.1)
		end
	end
	local function Windows(f0, f1)
		local f = f0 + DX / 2
		while f < f1 do
			local yt = Prof(TOPG, f) - 0.16
			local yb = Prof(BELT, f) + 0.06
			if yt - yb > 0.25 then
				Strip(f, DX + 0.01, yb, yt, C_GLASS, MAT_GLASS, 0.45)
			end
			f += DX
		end
	end
	Windows(-2.0, 1.5)
	Windows(-5.0, -2.6)
	Strip(-2.3, 0.6, Prof(BELT, -2.3) + 0.06, Prof(TOPG, -2.3) - 0.1, C_GLOSS, MAT_PLASTIC, 0) -- Bピラー

	-- リア: 4連テールランプ
	Box(m, 0, 2.95, -8.4, 5.6, 0.95, 0.12, C_GLOSS)
	car_tail = {}
	for _, r in ipairs({-2.4, -1.35, 1.35, 2.4}) do
		CylZ(m, r, 2.95, -8.5, 0.12, 1.0, C_GLOSS)
		local lamp = CylZ(m, r, 2.95, -8.57, 0.1, 0.75, Color3.fromRGB(170, 0, 0), MAT_NEON, 0.05)
		table.insert(car_tail, lamp)
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(255, 20, 20)
		pl.Range = 6
		pl.Brightness = 0.6
		pl.Parent = lamp
	end

	-- 4本出しマフラー
	for _, r in ipairs({-1.5, -0.7, 0.7, 1.5}) do
		CylZ(m, r, 1.2, -8.6, 0.55, 0.78, C_TITAN, MAT_METAL, 0, 0.2)
		CylZ(m, r, 1.2, -8.66, 0.45, 0.55, C_INT)
	end

	-- リアディフューザー
	Box(m, 0, 0.9, -8.2, 4.8, 0.5, 0.9, C_GLOSS)
	for i = -2, 2 do
		Box(m, i * 0.9, 0.7, -8.55, 0.06, 0.45, 0.5, C_INT2)
	end

	-- GTウイング (スワンネック / カーボン / 翼端板)
	local wingY = 5.45
	local wingF = -7.6
	for _, s in ipairs({-1, 1}) do
		Bar(m, V(s * 1.8, 3.62, -6.9), V(s * 1.8, wingY - 0.15, wingF + 0.3), 0.22, 0.5, C_CARBON, MAT_PLASTIC, 0, 0.1)
		Box(m, s * 1.8, 3.66, -6.9, 0.5, 0.1, 0.9, C_GLOSS)
		Box(m, s * 3.2, wingY, wingF, 0.12, 1.35, 2.3, C_GLOSS, MAT_PLASTIC, 0, 0.15)
	end
	NewPart(m, Vector3.new(6.4, 0.16, 1.9), CF(0, wingY, wingF) * CFrame.Angles(-0.14, 0, 0), C_CARBON, MAT_PLASTIC, 0, 0.12)
	NewPart(m, Vector3.new(6.4, 0.3, 0.06), CF(0, wingY + 0.18, wingF - 0.93) * CFrame.Angles(-0.14, 0, 0), C_GLOSS)
	NewPart(m, Vector3.new(5.2, 0.05, 0.12), CF(0, wingY - 0.12, wingF + 0.1) * CFrame.Angles(-0.14, 0, 0), C_INT2, MAT_METAL)
end

------------------------------------------------------------------
-- 内装 (右ハンドル)
------------------------------------------------------------------
local function BuildSeat(m, r, fc)
	Box(m, r, 1.0, fc, 1.7, 0.5, 1.7, C_INT)
	Box(m, r - 0.75, 1.2, fc, 0.3, 0.75, 1.55, C_INT2)
	Box(m, r + 0.75, 1.2, fc, 0.3, 0.75, 1.55, C_INT2)
	Box(m, r, 0.88, fc, 1.2, 0.2, 1.9, C_GLOSS)
	local bcf = CF(r, 2.25, fc - 0.85) * CFrame.Angles(0.16, 0, 0)
	NewPart(m, Vector3.new(1.6, 2.1, 0.45), bcf, C_INT)
	NewPart(m, Vector3.new(0.3, 1.9, 0.6), bcf * CFrame.new(-0.78, 0, -0.1), C_INT2)
	NewPart(m, Vector3.new(0.3, 1.9, 0.6), bcf * CFrame.new(0.78, 0, -0.1), C_INT2)
	NewPart(m, Vector3.new(0.85, 0.6, 0.35), bcf * CFrame.new(0, 1.45, 0.05), C_INT)
end

local function BuildInterior(m, car)
	-- カーペット
	Box(m, 0, 0.83, -1.65, 4.4, 0.05, 7.1, Color3.fromRGB(30, 30, 33))

	-- ダッシュボード
	Box(m, 0, 2.85, 1.45, 4.8, 0.5, 1.0, C_INT)
	Box(m, 0, 3.12, 1.35, 4.7, 0.06, 1.2, C_INT2)
	Box(m, 0, 1.7, 1.8, 4.7, 1.8, 0.4, C_INT)
	Box(m, 0, 2.6, 0.95, 4.7, 0.9, 0.12, C_INT)

	-- メーターフード / メーター (SurfaceGui)
	Box(m, 1.2, 3.3, 0.85, 1.7, 0.45, 0.75, C_GLOSS)
	local cluster = Box(m, 1.2, 3.02, 0.55, 1.5, 0.5, 0.05, Color3.fromRGB(5, 5, 8))
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(420, 140)
	sg.LightInfluence = 0
	sg.Brightness = 2
	sg.Adornee = cluster
	sg.Parent = cluster

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(4, 6, 10)
	bg.BorderSizePixel = 0
	bg.Parent = sg

	local speed = Instance.new("TextLabel")
	speed.Size = UDim2.new(0.5, 0, 0.7, 0)
	speed.Position = UDim2.fromScale(0.25, 0.05)
	speed.BackgroundTransparency = 1
	speed.Text = "0"
	speed.TextColor3 = WHITE
	speed.Font = Enum.Font.GothamBold
	speed.TextScaled = true
	speed.Parent = bg

	local unit = Instance.new("TextLabel")
	unit.Size = UDim2.new(0.3, 0, 0.2, 0)
	unit.Position = UDim2.fromScale(0.35, 0.68)
	unit.BackgroundTransparency = 1
	unit.Text = "km/h"
	unit.TextColor3 = CYAN
	unit.Font = Enum.Font.GothamBold
	unit.TextScaled = true
	unit.Parent = bg

	local gear = Instance.new("TextLabel")
	gear.Size = UDim2.new(0.18, 0, 0.5, 0)
	gear.Position = UDim2.fromScale(0.04, 0.1)
	gear.BackgroundTransparency = 1
	gear.Text = "N"
	gear.TextColor3 = CYAN
	gear.Font = Enum.Font.GothamBold
	gear.TextScaled = true
	gear.Parent = bg

	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.new(0.92, 0, 0.1, 0)
	barBack.Position = UDim2.fromScale(0.04, 0.88)
	barBack.BackgroundColor3 = Color3.fromRGB(25, 30, 38)
	barBack.BorderSizePixel = 0
	barBack.Parent = bg
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0.25, 1)
	bar.BackgroundColor3 = CYAN
	bar.BorderSizePixel = 0
	bar.Parent = barBack

	local driftLbl = Instance.new("TextLabel")
	driftLbl.Size = UDim2.new(0.22, 0, 0.3, 0)
	driftLbl.Position = UDim2.fromScale(0.75, 0.1)
	driftLbl.BackgroundTransparency = 1
	driftLbl.Text = "DRIFT"
	driftLbl.TextColor3 = C_ORANGE
	driftLbl.Font = Enum.Font.GothamBold
	driftLbl.TextScaled = true
	driftLbl.Visible = false
	driftLbl.Parent = bg

	car.gSpeed, car.gGear, car.gBar, car.gDrift = speed, gear, bar, driftLbl

	-- センターコンソール / スクリーン / 空調
	Box(m, 0, 2.7, 0.85, 1.1, 1.3, 0.45, C_INT)
	Box(m, 0, 3.05, 0.6, 0.95, 0.55, 0.04, Color3.fromRGB(15, 28, 48), MAT_NEON, 0.25)
	for _, s in ipairs({-1, 1}) do
		Box(m, s * 1.05, 3.0, 0.62, 0.5, 0.22, 0.06, C_GLOSS)
		Box(m, s * 1.05, 3.0, 0.58, 0.44, 0.03, 0.04, C_CHROME, MAT_METAL)
		Box(m, s * 2.1, 2.95, 0.7, 0.3, 0.3, 0.06, C_GLOSS)
	end
	for _, r in ipairs({-0.45, 0, 0.45}) do
		CylZ(m, r, 2.3, 0.7, 0.12, 0.3, C_CHROME, MAT_METAL, 0, 0.3)
	end
	Box(m, 0, 2.0, 0.7, 1.0, 0.12, 0.06, C_INT2)

	-- 中央トンネル / シフト / サイドブレーキ
	Box(m, 0, 1.4, -0.6, 1.0, 1.1, 2.9, C_INT)
	Box(m, 0, 1.97, -0.6, 1.0, 0.06, 2.9, C_INT2)
	Box(m, 0, 2.02, 0.15, 0.7, 0.08, 0.7, C_GLOSS)
	CylY(m, 0, 2.35, 0.15, 0.6, 0.16, C_CHROME, MAT_METAL, 0, 0.3)
	NewPart(m, Vector3.new(0.34, 0.34, 0.34), CF(0, 2.7, 0.15), C_GLOSS, MAT_PLASTIC, 0, 0.2).Shape = Enum.PartType.Ball
	Bar(m, V(0.55, 2.0, -0.8), V(0.55, 2.4, -1.35), 0.12, 0.12, C_GLOSS)
	Box(m, 0.55, 2.42, -1.37, 0.15, 0.1, 0.25, C_CHROME, MAT_METAL)
	Box(m, 0, 2.2, -1.5, 0.9, 0.22, 0.9, C_INT2)
	for _, f in ipairs({-0.25, -0.75}) do
		CylY(m, 0, 2.0, f, 0.04, 0.4, C_GLOSS)
	end

	-- シート (運転席=右 / 助手席=左 / リア2席)
	BuildSeat(m, 1.2, -1.25)
	BuildSeat(m, -1.2, -1.25)
	for _, r in ipairs({-1.2, 1.2}) do
		Box(m, r, 1.0, -3.55, 1.6, 0.45, 1.3, C_INT)
		local rcf = CF(r, 2.0, -4.3) * CFrame.Angles(0.25, 0, 0)
		NewPart(m, Vector3.new(1.6, 1.8, 0.4), rcf, C_INT)
		NewPart(m, Vector3.new(0.3, 1.6, 0.5), rcf * CFrame.new(-0.78, 0, -0.08), C_INT2)
		NewPart(m, Vector3.new(0.3, 1.6, 0.5), rcf * CFrame.new(0.78, 0, -0.08), C_INT2)
	end
	Box(m, 0, 2.3, -5.1, 4.6, 2.9, 0.2, C_INT)
	Box(m, 0, 3.5, -5.0, 4.4, 0.08, 0.5, C_INT2)

	-- ドアトリム
	for _, s in ipairs({-1, 1}) do
		Box(m, s * 2.27, 2.2, -0.2, 0.12, 2.0, 3.4, C_INT)
		Box(m, s * 2.05, 2.3, -0.3, 0.4, 0.2, 1.7, C_INT2)
		Box(m, s * 2.15, 2.75, -1.4, 0.12, 0.12, 0.8, C_CHROME, MAT_METAL, 0, 0.3)
		Box(m, s * 2.12, 2.55, 0.6, 0.2, 0.2, 0.6, C_GLOSS)
		CylX = NewCyl(m, Vector3.new(0.06, 0.7, 0.7), CF(s * 2.2, 1.6, 0.5), C_GLOSS)
		Box(m, s * 2.27, 2.1, -4.0, 0.12, 1.8, 2.6, C_INT)
		-- Aピラー内張り
	end

	-- ペダル
	Box(m, 1.2, 1.15, 1.45, 0.35, 0.1, 0.55, C_CHROME, MAT_METAL, 0, 0.2)
	NewPart(m, Vector3.new(0.35, 0.1, 0.6), CF(0.7, 1.05, 1.5) * CFrame.Angles(0.35, 0, 0), C_GLOSS)
	NewPart(m, Vector3.new(0.4, 0.1, 0.9), CF(1.35, 1.0, 1.55) * CFrame.Angles(0.35, 0, 0), C_GLOSS)
	Box(m, -0.1, 1.0, 1.55, 0.7, 0.1, 0.7, C_INT2)

	-- ステアリングコラム / パドル
	NewPart(m, Vector3.new(0.5, 0.5, 0.9), CF(1.2, 2.75, 0.3) * CFrame.Angles(-0.35, 0, 0), C_GLOSS)
	for _, s in ipairs({-1, 1}) do
		NewPart(m, Vector3.new(0.12, 0.7, 0.05), CF(1.2 + s * 0.6, 3.0, 0.2) * CFrame.Angles(-0.4, 0, 0), C_CHROME, MAT_METAL, 0, 0.3)
	end

	-- 天井 / バイザー / ルームミラー / 室内灯
	Box(m, 0, 4.66, -1.7, 4.0, 0.06, 3.4, Color3.fromRGB(70, 70, 76))
	for _, s in ipairs({-1, 1}) do
		Box(m, s * 1.1, 4.55, 0.0, 1.0, 0.06, 0.5, C_INT)
	end
	Box(m, 0, 4.3, 0.15, 0.9, 0.28, 0.15, C_GLOSS)
	Bar(m, V(0, 4.6, 0.1), V(0, 4.42, 0.15), 0.08, 0.08, C_GLOSS)
	local dome = Box(m, 0, 4.62, -0.8, 0.4, 0.04, 0.4, Color3.fromRGB(255, 244, 220), MAT_NEON, 0.3)
	local pl = Instance.new("PointLight")
	pl.Range = 8
	pl.Brightness = 0.4
	pl.Color = Color3.fromRGB(255, 240, 215)
	pl.Parent = dome
end

------------------------------------------------------------------
-- ホイール (動的)  / ハンドル (動的)
------------------------------------------------------------------
local function BuildWheel(parent, spec)
	local items = {}
	local s = spec.side
	local tw = spec.front and 0.95 or 1.05
	local function add(part, rel, spin)
		table.insert(items, {part = part, rel = rel, spin = spin})
	end

	add(NewCyl(parent, Vector3.new(tw, WR * 2, WR * 2), CFrame.new(), C_TIRE), CFrame.new(), true)
	add(NewCyl(parent, Vector3.new(0.03, 1.85, 1.85), CFrame.new(), Color3.fromRGB(8, 8, 10), MAT_PLASTIC), CFrame.new(s * (tw / 2 + 0.01), 0, 0), true)
	add(NewCyl(parent, Vector3.new(0.08, 1.55, 1.55), CFrame.new(), Color3.fromRGB(165, 168, 172), MAT_METAL, 0, 0.3), CFrame.new(s * (tw / 2 + 0.05), 0, 0), true)
	add(NewCyl(parent, Vector3.new(0.1, 0.5, 0.5), CFrame.new(), Color3.fromRGB(14, 14, 16), MAT_METAL), CFrame.new(s * (tw / 2 + 0.2), 0, 0), true)
	for k = 0, 9 do
		for _, d in ipairs({-8, 8}) do
			local a = math.rad(k * 36 + d)
			local sp = NewPart(parent, Vector3.new(0.1, 0.72, 0.14), CFrame.new(), C_RIM, MAT_METAL, 0, 0.2)
			add(sp, CFrame.Angles(a, 0, 0) * CFrame.new(s * (tw / 2 + 0.15), 0.55, 0), true)
		end
	end
	-- ブレーキキャリパー (オレンジ / 回転しない)
	add(NewPart(parent, Vector3.new(0.28, 0.5, 0.75), CFrame.new(), C_ORANGE, MAT_PLASTIC, 0, 0.1), CFrame.new(s * (tw / 2 + 0.1), 0.2, spec.front and -0.58 or 0.58), false)

	return {x = spec.x, f = spec.f, front = spec.front, side = s, items = items, spin = 0}
end

local function BuildSteeringWheel(parent)
	local items = {}
	local R = 0.62
	for i = 0, 15 do
		local phi = i / 16 * math.pi * 2
		local seg = NewPart(parent, Vector3.new(0.34, 0.17, 0.17), CFrame.new(), C_GLOSS, MAT_PLASTIC, 0, 0.15)
		table.insert(items, {part = seg, rel = CFrame.new(R * math.cos(phi), R * math.sin(phi), 0) * CFrame.Angles(0, 0, phi + math.pi / 2)})
	end
	local hub = NewPart(parent, Vector3.new(0.5, 0.5, 0.18), CFrame.new(), C_GLOSS, MAT_PLASTIC, 0, 0.2)
	table.insert(items, {part = hub, rel = CFrame.new()})
	for _, ang in ipairs({0, math.pi, -math.pi / 2}) do
		local sp = NewPart(parent, Vector3.new(0.16, 0.5, 0.12), CFrame.new(), C_INT2, MAT_PLASTIC)
		table.insert(items, {part = sp, rel = CFrame.Angles(0, 0, ang) * CFrame.new(0, 0.38, 0)})
	end
	local mark = NewPart(parent, Vector3.new(0.1, 0.16, 0.2), CFrame.new(), C_ORANGE, MAT_PLASTIC)
	table.insert(items, {part = mark, rel = CFrame.new(0, R, 0)})
	return items
end

------------------------------------------------------------------
-- 車の組み立て
------------------------------------------------------------------
local function BuildCar(spawnPos, spawnYaw)
	local car = {}
	car_tail = nil

	local folder = Instance.new("Folder")
	folder.Name = "LocalGTR"
	car.folder = folder

	local skidFolder = Instance.new("Folder")
	skidFolder.Name = "LocalGTRSkids"
	skidFolder.Parent = Workspace
	car.skidFolder = skidFolder
	car.skids = {}
	car.skidT = 0

	local model = Instance.new("Model")
	model.Name = "Body"
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Anchored = true
	chassis.CanCollide = false
	chassis.CanQuery = false
	chassis.CanTouch = false
	chassis.Transparency = 1
	chassis.Size = Vector3.new(1, 1, 1)
	chassis.CFrame = CFrame.new()
	chassis.Parent = model
	model.PrimaryPart = chassis
	car.body = model

	BuildBody(model)
	car.tail = car_tail
	BuildInterior(model, car)

	-- 動的パーツ
	local dyn = Instance.new("Folder")
	dyn.Name = "Dynamic"
	dyn.Parent = folder
	car.wheels = {}
	local specs = {
		{x = WHEEL_X, f = FRONT_AX, front = true, side = 1},
		{x = -WHEEL_X, f = FRONT_AX, front = true, side = -1},
		{x = WHEEL_X, f = REAR_AX, front = false, side = 1},
		{x = -WHEEL_X, f = REAR_AX, front = false, side = -1},
	}
	for _, sp in ipairs(specs) do
		table.insert(car.wheels, BuildWheel(dyn, sp))
	end
	car.swItems = BuildSteeringWheel(dyn)

	-- タイヤスモーク用アンカー
	car.smoke = {}
	for _, s in ipairs({-1, 1}) do
		local a = Instance.new("Part")
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.Transparency = 1
		a.Size = Vector3.new(0.5, 0.5, 0.5)
		a.Parent = dyn
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(215, 215, 220))
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(1, 7),
		})
		pe.Lifetime = NumberRange.new(1.0, 1.8)
		pe.Speed = NumberRange.new(2, 6)
		pe.SpreadAngle = Vector2.new(30, 30)
		pe.RotSpeed = NumberRange.new(-60, 60)
		pe.Rate = 0
		pe.Parent = a
		table.insert(car.smoke, {part = a, emitter = pe, side = s})
	end

	-- BulkMoveTo用配列
	car.dynParts = {}
	car.dynCFs = {}

	-- 状態
	car.st = {
		pos = spawnPos,
		yaw = spawnYaw,
		vf = 0, vl = 0, w = 0,
		vy = 0, vyG = 0,
		delta = 0, steerIn = 0,
		pg = 0, rg = 0, pv = 0, rv = 0,
		fx = 0,
		camYaw = spawnYaw,
		grounded = true,
		lastSafe = spawnPos,
		brakeOn = false,
		idle = false,
		gaugeT = 0,
	}

	return car
end

------------------------------------------------------------------
-- レイキャスト用フィルタ
------------------------------------------------------------------
local function RefreshFilter(car)
	local list = {car.folder, car.skidFolder}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(list, plr.Character)
		end
	end
	car.rayParams.FilterDescendantsInstances = list
end

------------------------------------------------------------------
-- 見た目の更新
------------------------------------------------------------------
local function UpdateVisuals(car)
	local st = car.st
	local carCF = CFrame.new(st.pos) * CFrame.Angles(0, st.yaw, 0) * CFrame.Angles(st.pv, 0, st.rv)
	car.cf = carCF
	car.body:PivotTo(carCF)

	local parts, cfs = car.dynParts, car.dynCFs
	local n = 0
	for _, w in ipairs(car.wheels) do
		local base = carCF * CFrame.new(w.x, WR, -w.f)
		if w.front then
			base = base * CFrame.Angles(0, st.delta, 0)
		end
		local spinCF = base * CFrame.Angles(w.spin, 0, 0)
		for _, it in ipairs(w.items) do
			n += 1
			parts[n] = it.part
			cfs[n] = (it.spin and spinCF or base) * it.rel
		end
	end

	local swBase = carCF * SW_BASE * CFrame.Angles(0, 0, st.delta * 4)
	for _, it in ipairs(car.swItems) do
		n += 1
		parts[n] = it.part
		cfs[n] = swBase * it.rel
	end

	for _, sm in ipairs(car.smoke) do
		n += 1
		parts[n] = sm.part
		cfs[n] = carCF * CFrame.new(sm.side * WHEEL_X, 0.3, -REAR_AX)
	end

	Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

------------------------------------------------------------------
-- 走行物理 (バイシクルモデル + タイヤの摩擦円)
------------------------------------------------------------------
local function PhysicsStep(car, dt, inp)
	local st = car.st
	local thr = inp.gas and 1 or 0
	local brk = inp.brake and 1 or 0

	-- ハンドル入力 (左が正)
	local target = 0
	if inp.left and not inp.right then target = 1 elseif inp.right and not inp.left then target = -1 end
	if type(inp.analog) == "number" and math.abs(inp.analog) > 0.05 then
		target = math.clamp(inp.analog, -1, 1)
	end
	local rate = (target == 0) and 6 or 4
	st.steerIn += math.clamp(target - st.steerIn, -rate * dt, rate * dt)

	local SUB = 3
	local h = dt / SUB
	local ax = 0
	for _ = 1, SUB do
		local vf, vl, w = st.vf, st.vl, st.w
		local sp = math.abs(vf)
		local vfa = math.max(sp, 3)
		local sgn = (vf >= 0) and 1 or -1

		-- 舵角 (速度で減少 + カウンターステア補助)
		local dmax = 0.55 - 0.40 * math.clamp(sp / 150, 0, 1)
		local beta = math.atan(vl / vfa)
		local assistW = (sp > 15) and math.clamp((math.abs(beta) - 0.08) / 0.25, 0, 1) or 0
		local assist = math.clamp(beta * 0.9, -0.6, 0.6) * assistW
		local deltaT = math.clamp(st.steerIn * dmax + assist, -0.65, 0.65)
		st.delta += (deltaT - st.delta) * math.min(h * 12, 1)
		local delta = st.delta

		-- 前後方向の力
		local fx = 0
		if thr > 0 then
			fx += 40 * math.max(1 - (math.max(vf, 0) / VMAX) ^ 2, 0)
		end
		if brk > 0 then
			if vf > 1.5 then
				fx -= 48
			elseif thr == 0 and vf > -35 then
				fx -= 16
			end
		end
		fx -= sgn * (1.5 + 0.00012 * vf * vf)
		if inp.drift then
			fx -= sgn * 8
		end

		-- タイヤのグリップ上限 (摩擦円)
		local capF = MU * G * 0.52
		local capRtot = MU * G * 0.48
		local capR = capRtot
		if inp.drift then
			capR *= 0.28
		end
		if thr > 0.9 and math.abs(st.steerIn) > 0.5 and sp > 50 then
			capR *= 0.65
		end
		local ratio = math.clamp(math.abs(fx) * 0.5 / capRtot, 0, 0.97)
		local capRlat = capR * math.sqrt(1 - ratio * ratio)

		-- スリップ角と横力
		local aF = math.atan((vl + A_DIST * w) / vfa) - delta * sgn
		local aR = math.atan((vl - B_DIST * w) / vfa)
		local Fyf = -capF * math.tanh(6 * aF)
		local Fyr = -capRlat * math.tanh(6 * aR)
		local cd, sd = math.cos(delta), math.sin(delta)

		local dvf = fx - Fyf * sd + vl * w
		local dvl = Fyf * cd + Fyr - vf * w
		local dw = (A_DIST * Fyf * cd - B_DIST * Fyr) / K2 - w * 0.35

		local oldVf = vf
		vf += dvf * h
		vl += dvl * h
		w += dw * h
		ax = fx

		-- 停止時のガタつき防止
		if thr == 0 and brk == 0 and oldVf * vf < 0 then
			vf = 0
		end

		-- 低速は運動学的に安定化
		if sp < 8 then
			local k = sp / 8
			local wk = vf * math.tan(delta) / WBS
			w = w * k + wk * (1 - k)
			vl *= (1 - (1 - k) * math.min(h * 10, 1))
		end

		vf = math.clamp(vf, -35, VMAX * 1.05)
		w = math.clamp(w, -3.2, 3.2)
		st.vf, st.vl, st.w = vf, vl, w

		-- 位置の更新
		st.yaw += w * h
		local sy, cy = math.sin(st.yaw), math.cos(st.yaw)
		local look = Vector3.new(-sy, 0, -cy)
		local left = Vector3.new(-cy, 0, sy)
		local vel = look * st.vf + left * st.vl
		st.pos += Vector3.new(vel.X, 0, vel.Z) * h
	end

	st.fx += (ax - st.fx) * math.min(dt * 8, 1)

	-- ホイール回転
	for _, wh in ipairs(car.wheels) do
		wh.spin -= st.vf / WR * dt
	end
end

------------------------------------------------------------------
-- 地面追従
------------------------------------------------------------------
local function GroundStep(car, dt)
	local st = car.st
	local cfYaw = CFrame.new(st.pos) * CFrame.Angles(0, st.yaw, 0)
	local ys = {}
	local hits, sum = 0, 0
	for i, wv in ipairs(car.wheels) do
		local origin = (cfYaw * CFrame.new(wv.x, 2.5, -wv.f)).Position
		local r = Workspace:Raycast(origin, Vector3.new(0, -9, 0), car.rayParams)
		if r then
			ys[i] = r.Position.Y
			hits += 1
			sum += r.Position.Y
		end
	end

	local oldY = st.pos.Y
	if hits > 0 then
		local avg = sum / hits
		for i = 1, 4 do
			if not ys[i] then ys[i] = avg end
		end
		local pitchT = math.atan2((ys[1] + ys[2]) / 2 - (ys[3] + ys[4]) / 2, WBS)
		local rollT = math.atan2((ys[1] + ys[3]) / 2 - (ys[2] + ys[4]) / 2, WHEEL_X * 2)
		st.pg += (pitchT - st.pg) * math.min(dt * 14, 1)
		st.rg += (rollT - st.rg) * math.min(dt * 14, 1)

		if st.pos.Y <= avg + 0.25 and st.vy <= 0.5 then
			st.pos = Vector3.new(st.pos.X, st.pos.Y + (avg - st.pos.Y) * math.min(dt * 25, 1), st.pos.Z)
			st.vyG = math.clamp((st.pos.Y - oldY) / math.max(dt, 1e-3), -50, 60)
			st.vy = 0
			st.grounded = true
			st.lastSafe = st.pos
		else
			st.grounded = false
			st.vy -= Workspace.Gravity * dt
			st.pos += Vector3.new(0, st.vy * dt, 0)
			if st.pos.Y < avg then
				st.pos = Vector3.new(st.pos.X, avg, st.pos.Z)
				st.vy = 0
			end
		end
	else
		if st.grounded then
			st.vy = st.vyG
		end
		st.grounded = false
		st.vy -= Workspace.Gravity * dt
		st.pos += Vector3.new(0, st.vy * dt, 0)
		st.pg += (0 - st.pg) * math.min(dt * 2, 1)
		st.rg += (0 - st.rg) * math.min(dt * 2, 1)
		if st.pos.Y < Workspace.FallenPartsDestroyHeight + 60 then
			st.pos = st.lastSafe + Vector3.new(0, 3, 0)
			st.vy, st.vf, st.vl, st.w = 0, 0, 0, 0
			Notify("復帰", "落下したので安全な場所に戻しました", 3)
		end
	end

	-- 加減速・旋回による車体の傾き
	local pvT = math.clamp(st.fx * 0.0009, -0.045, 0.05)
	local rvT = math.clamp(-(st.vf * st.w) * 0.0012, -0.08, 0.08)
	st.pv += ((st.pg + pvT) - st.pv) * math.min(dt * 10, 1)
	st.rv += ((st.rg + rvT) - st.rv) * math.min(dt * 10, 1)

	return ys
end

------------------------------------------------------------------
-- 壁との衝突
------------------------------------------------------------------
local function Collide(car, dt)
	local st = car.st
	local sy, cy = math.sin(st.yaw), math.cos(st.yaw)
	local look = Vector3.new(-sy, 0, -cy)
	local left = Vector3.new(-cy, 0, sy)
	local right = -left
	local base = Vector3.new(st.pos.X, st.pos.Y + 1.8, st.pos.Z)
	local probes = {
		{base + look * 5 + right * 2, look, 3.8},
		{base + look * 5 - right * 2, look, 3.8},
		{base - look * 5 + right * 2, -look, 3.8},
		{base - look * 5 - right * 2, -look, 3.8},
		{base + look * 3.5, right, 3.55},
		{base + look * 3.5, left, 3.55},
		{base - look * 3.5, right, 3.55},
		{base - look * 3.5, left, 3.55},
	}
	local extra = math.abs(st.vf) * dt
	for _, pr in ipairs(probes) do
		local origin, dir, D = pr[1], pr[2], pr[3]
		local res = Workspace:Raycast(origin, dir * (D + extra), car.rayParams)
		if res and math.abs(res.Normal.Y) < 0.6 then
			local n = Vector3.new(res.Normal.X, 0, res.Normal.Z)
			if n.Magnitude > 0.01 then
				n = n.Unit
				local dist = (res.Position - origin).Magnitude
				local pen = D - dist
				if pen > 0 then
					st.pos += n * pen
				end
				local vw = look * st.vf + left * st.vl
				local vn = vw:Dot(n)
				if vn < 0 then
					vw = (vw - n * vn * 1.3) * 0.94
					st.vf = vw:Dot(look)
					st.vl = vw:Dot(left)
					st.w *= 0.9
				end
			end
		end
	end
end

------------------------------------------------------------------
-- タイヤ痕 / スモーク / メーター
------------------------------------------------------------------
local function AddSkid(car, cf)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = MAT_PLASTIC
	p.Color = Color3.fromRGB(14, 14, 14)
	p.Transparency = 0.3
	p.Size = Vector3.new(0.85, 0.04, 1.6)
	p.CFrame = cf
	p.Parent = car.skidFolder
	table.insert(car.skids, p)
	if #car.skids > 220 then
		local old = table.remove(car.skids, 1)
		old:Destroy()
	end
end

local function Effects(car, dt, ys)
	local st = car.st
	local sp = math.abs(st.vf)
	local drifting = st.grounded and math.abs(st.vl) > 7 and sp > 12

	for _, sm in ipairs(car.smoke) do
		sm.emitter.Rate = drifting and math.clamp(math.abs(st.vl) * 3, 10, 80) or 0
	end

	if drifting then
		car.skidT += dt
		if car.skidT > 0.04 then
			car.skidT = 0
			local cfYaw = CFrame.new(st.pos) * CFrame.Angles(0, st.yaw, 0)
			for i = 3, 4 do
				local wv = car.wheels[i]
				local y = (ys and ys[i]) or st.pos.Y
				local pos = (cfYaw * CFrame.new(wv.x, 0, -wv.f)).Position
				AddSkid(car, CFrame.new(pos.X, y + 0.03, pos.Z) * CFrame.Angles(0, st.yaw, 0))
			end
		end
	end

	-- ブレーキランプ
	local braking = (st.vf > 1 and Inp.brake) or Inp.drift
	if braking ~= st.brakeOn and car.tail then
		st.brakeOn = braking
		for _, lamp in ipairs(car.tail) do
			lamp.Color = braking and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(170, 0, 0)
		end
	end

	-- メーター表示
	st.gaugeT += dt
	if st.gaugeT > 0.08 then
		st.gaugeT = 0
		local kmh = math.floor(sp * 1.008 + 0.5)
		car.gSpeed.Text = tostring(kmh)
		local g
		if st.vf < -1 then
			g = "R"
		elseif kmh < 2 then
			g = "N"
		else
			g = tostring(math.clamp(math.floor(kmh / 45) + 1, 1, 6))
		end
		car.gGear.Text = g
		car.gBar.Size = UDim2.fromScale(math.clamp(0.2 + ((kmh % 45) / 45) * 0.75, 0, 1), 1)
		car.gDrift.Visible = drifting
	end

	return drifting
end

------------------------------------------------------------------
-- 乗り降り / カメラ
------------------------------------------------------------------
local Camera = Workspace.CurrentCamera
local SavedFov = 70
local DrivePad = nil
local EnterBtn = nil

local function SetCharHidden(char, hidden)
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			local isHead = (d.Name == "Head") or (d.Parent and d.Parent:IsA("Accessory"))
			if isHead then
				d.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
end

local function GetControls()
	local ok, controls = pcall(function()
		return require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	end)
	if ok then return controls end
	return nil
end

local function ExitCar(silent)
	if not Driving then return end
	Driving = false
	for k in pairs(Inp) do Inp[k] = false end

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	SetCharHidden(char, false)
	if hum then
		hum.Sit = false
		hum.AutoRotate = true
		pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
	end
	if hrp then
		if Car and Car.cf then
			hrp.CFrame = Car.cf * CFrame.new(5.2, 2.8, 0)
		end
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.Anchored = false
	end

	Camera.CameraType = Enum.CameraType.Custom
	if hum then Camera.CameraSubject = hum end
	Camera.FieldOfView = SavedFov

	local controls = GetControls()
	if controls then pcall(function() controls:Enable() end) end

	if DrivePad then DrivePad.Visible = false end
	if EnterBtn then EnterBtn.Text = "乗る" end
	if not silent then Notify("降車", "車から降りました", 2) end
end

local function EnterCar()
	if not Car then
		Notify("車がありません", "先に「召喚」を押してください", 3)
		return
	end
	if Driving then return end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hum and hrp) or hum.Health <= 0 then
		Notify("エラー", "キャラクターが見つかりません", 3)
		return
	end
	if (hrp.Position - Car.st.pos).Magnitude > 22 then
		Notify("遠すぎます", "車に近づいてから乗ってください", 3)
		return
	end

	Driving = true
	Car.st.idle = false
	SavedFov = Camera.FieldOfView

	local controls = GetControls()
	if controls then pcall(function() controls:Disable() end) end

	hrp.Anchored = true
	hum.AutoRotate = false
	hum.Sit = true
	pcall(function() hum:ChangeState(Enum.HumanoidStateType.Seated) end)

	Camera.CameraType = Enum.CameraType.Scriptable
	SetCharHidden(char, CamMode == 2)

	if DrivePad then DrivePad.Visible = true end
	if EnterBtn then EnterBtn.Text = "降りる" end
	Notify("乗車", "右ハンドルです。▲アクセル ▼ブレーキ DRIFTでドリフト", 4)

	hum.Died:Connect(function()
		if Driving then
			ExitCar(true)
		end
	end)
end

local function UpdateCamera(car, dt)
	local st = car.st
	if CamMode == 2 then
		Camera.CFrame = car.cf * CFrame.new(1.2, 4.05, 0.7)
		Camera.FieldOfView = 80
	else
		local d = ((st.yaw - st.camYaw + math.pi) % (math.pi * 2)) - math.pi
		st.camYaw += d * math.min(dt * 5, 1)
		local look = Vector3.new(-math.sin(st.camYaw), 0, -math.cos(st.camYaw))
		local sp = math.abs(st.vf)
		local camPos = st.pos - look * (15 + sp * 0.02) + Vector3.new(0, 6.5, 0)
		Camera.CFrame = CFrame.lookAt(camPos, st.pos + Vector3.new(0, 2.5, 0) + look * 6)
		Camera.FieldOfView = 70 + math.clamp(sp * 0.08, 0, 22)
	end
end

------------------------------------------------------------------
-- 召喚 / 回収
------------------------------------------------------------------
local SpawnBtn = nil

local function RemoveCar()
	if Driving then ExitCar(true) end
	if Car then
		pcall(function() Car.folder:Destroy() end)
		pcall(function() Car.skidFolder:Destroy() end)
		Car = nil
	end
	if SpawnBtn then SpawnBtn.Text = "召喚" end
end

local function SpawnCar()
	if Car then
		RemoveCar()
		Notify("回収", "車を片付けました", 2)
		return
	end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		Notify("エラー", "キャラクターが見つかりません", 3)
		return
	end

	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
	flat = flat.Unit
	local yaw = math.atan2(-flat.X, -flat.Z)
	local want = hrp.Position + flat * 16

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	local res = Workspace:Raycast(want + Vector3.new(0, 30, 0), Vector3.new(0, -120, 0), params)
	local gy = res and res.Position.Y or (hrp.Position.Y - 3)
	local pos = Vector3.new(want.X, gy, want.Z)

	Car = BuildCar(pos, yaw)
	Car.rayParams = RaycastParams.new()
	Car.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	Car.rayParams.IgnoreWater = true
	RefreshFilter(Car)
	Car.refreshT = 0

	UpdateVisuals(Car)
	Car.folder.Parent = Workspace
	Car.body.Parent = Car.folder

	if SpawnBtn then SpawnBtn.Text = "回収" end
	Notify("召喚", "GT-Rを出しました (自分だけに見えます)", 3)
end

------------------------------------------------------------------
-- メインループ
------------------------------------------------------------------
table.insert(Conns, RunService.RenderStepped:Connect(function(dt)
	if not Car then return end
	dt = math.min(dt, 1 / 20)
	local st = Car.st

	Car.refreshT += dt
	if Car.refreshT > 2 then
		Car.refreshT = 0
		RefreshFilter(Car)
	end

	local active = Driving or math.abs(st.vf) > 0.05 or math.abs(st.vl) > 0.05 or math.abs(st.w) > 0.01 or not st.grounded
	if not active then
		if Driving then return end
		return
	end

	local inp = Driving and Inp or {}
	PhysicsStep(Car, dt, inp)
	local ys = GroundStep(Car, dt)
	Collide(Car, dt)
	UpdateVisuals(Car)
	Effects(Car, dt, ys)

	if Driving then
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hum then
			hrp.CFrame = Car.cf * SEAT_HRP
			hrp.AssemblyLinearVelocity = Vector3.zero
			if not hum.Sit then hum.Sit = true end
		end
		UpdateCamera(Car, dt)
	end
end))

------------------------------------------------------------------
-- Gui (モバイル用)
------------------------------------------------------------------
gui = Instance.new("ScreenGui")
gui.Name = "GTRDriftGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999

local parented = pcall(function()
	gui.Parent = game:GetService("CoreGui")
end)
if not parented or not gui.Parent then
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local OBS_BG = Color3.fromRGB(8, 8, 12)
local OBS_BTN = Color3.fromRGB(20, 18, 28)
local OBS_STROKE = Color3.fromRGB(88, 78, 124)
local OBS_TEXT = Color3.fromRGB(205, 198, 225)

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

local function MakeButton(parent, text, size, pos, anchor, bg, textSize)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.AnchorPoint = anchor or Vector2.new(0, 0)
	b.BackgroundColor3 = bg
	b.BackgroundTransparency = 0.1
	b.Text = text
	b.TextColor3 = OBS_TEXT
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = textSize or 24
	b.AutoButtonColor = true
	b.Parent = parent
	Round(b, 12)
	Stroke(b, OBS_STROKE, 1)
	return b
end

-- メインパネル
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(150, 126)
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
title.Text = "GT-R"
title.TextColor3 = OBS_TEXT
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = main

local closeBtn = MakeButton(main, "×", UDim2.fromOffset(22, 22), UDim2.new(1, -26, 0, 2), Vector2.new(0, 0), OBS_BTN, 16)

SpawnBtn = MakeButton(main, "召喚", UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 30), Vector2.new(0, 0), OBS_BTN, 16)
EnterBtn = MakeButton(main, "乗る", UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 62), Vector2.new(0, 0), OBS_BTN, 16)
local camBtn = MakeButton(main, "視点", UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 94), Vector2.new(0, 0), OBS_BTN, 16)

-- 運転パッド
DrivePad = Instance.new("Frame")
DrivePad.Name = "DrivePad"
DrivePad.Size = UDim2.fromScale(1, 1)
DrivePad.BackgroundTransparency = 1
DrivePad.Visible = false
DrivePad.Parent = gui

local function Hold(btn, key)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Inp[key] = true
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					Inp[key] = false
				end
			end)
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Inp[key] = false
		end
	end)
end

local bLeft = MakeButton(DrivePad, "◀", UDim2.fromOffset(58, 58), UDim2.new(0, 12, 1, -12), Vector2.new(0, 1), OBS_BTN, 24)
local bRight = MakeButton(DrivePad, "▶", UDim2.fromOffset(58, 58), UDim2.new(0, 76, 1, -12), Vector2.new(0, 1), OBS_BTN, 24)
local bGas = MakeButton(DrivePad, "▲", UDim2.fromOffset(66, 66), UDim2.new(1, -12, 1, -12), Vector2.new(1, 1), OBS_BTN, 28)
local bBrake = MakeButton(DrivePad, "▼", UDim2.fromOffset(58, 58), UDim2.new(1, -86, 1, -12), Vector2.new(1, 1), OBS_BTN, 24)
local bDrift = MakeButton(DrivePad, "DRIFT", UDim2.fromOffset(66, 40), UDim2.new(1, -12, 1, -84), Vector2.new(1, 1), OBS_BTN, 15)
local bExit = MakeButton(DrivePad, "降りる", UDim2.fromOffset(62, 30), UDim2.new(1, -12, 0, 10), Vector2.new(1, 0), OBS_BTN, 14)

Hold(bLeft, "left")
Hold(bRight, "right")
Hold(bGas, "gas")
Hold(bBrake, "brake")
Hold(bDrift, "drift")

-- ステアリングスライダー (指を左右にスライドして細かく操舵)
local sliderBack = Instance.new("Frame")
sliderBack.Size = UDim2.fromOffset(134, 40)
sliderBack.Position = UDim2.new(0, 12, 1, -76)
sliderBack.AnchorPoint = Vector2.new(0, 1)
sliderBack.BackgroundColor3 = OBS_BG
sliderBack.BackgroundTransparency = 0.25
sliderBack.Active = true
sliderBack.Parent = DrivePad
Round(sliderBack, 20)
Stroke(sliderBack, OBS_STROKE, 1)

local sliderKnob = Instance.new("Frame")
sliderKnob.Size = UDim2.fromOffset(32, 32)
sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sliderKnob.Position = UDim2.fromScale(0.5, 0.5)
sliderKnob.BackgroundColor3 = OBS_STROKE
sliderKnob.BackgroundTransparency = 0.1
sliderKnob.Parent = sliderBack
Round(sliderKnob, 16)

local function SliderSet(x)
	local rel = math.clamp((x - sliderBack.AbsolutePosition.X) / sliderBack.AbsoluteSize.X, 0, 1)
	sliderKnob.Position = UDim2.fromScale(math.clamp(rel, 0.12, 0.88), 0.5)
	Inp.analog = -(rel - 0.5) * 2 -- 左へスライド = 左に曲がる
end

local function SliderReset()
	sliderKnob.Position = UDim2.fromScale(0.5, 0.5)
	Inp.analog = 0
end

local sliding = false
local slideInput = nil
sliderBack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		sliding = true
		slideInput = input
		SliderSet(input.Position.X)
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				sliding = false
				slideInput = nil
				SliderReset()
			end
		end)
	end
end)
table.insert(Conns, UserInputService.InputChanged:Connect(function(input)
	if sliding and input == slideInput then
		SliderSet(input.Position.X)
	end
end))

-- ドラッグ移動 (タッチ)
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
table.insert(Conns, UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end))

-- ボタン動作
SpawnBtn.Activated:Connect(function()
	local ok, err = pcall(SpawnCar)
	if not ok then
		Notify("エラー", tostring(err), 6)
	end
end)

EnterBtn.Activated:Connect(function()
	local ok, err = pcall(function()
		if Driving then
			ExitCar()
		else
			EnterCar()
		end
	end)
	if not ok then
		Notify("エラー", tostring(err), 6)
	end
end)

bExit.Activated:Connect(function()
	pcall(ExitCar)
end)

camBtn.Activated:Connect(function()
	CamMode = (CamMode == 1) and 2 or 1
	if Driving then
		SetCharHidden(LocalPlayer.Character, CamMode == 2)
	end
	Notify("視点", CamMode == 1 and "外からの視点" or "車内の視点", 2)
end)

local function FullCleanup()
	pcall(function()
		if Driving then ExitCar(true) end
	end)
	pcall(RemoveCar)
	for _, c in ipairs(Conns) do
		pcall(function() c:Disconnect() end)
	end
	Conns = {}
	if gui then gui:Destroy() end
	env.GTRCleanup = nil
end

closeBtn.Activated:Connect(FullCleanup)
env.GTRCleanup = FullCleanup

Notify("GT-R", "Guiを読み込みました。「召喚」を押してください", 4)
