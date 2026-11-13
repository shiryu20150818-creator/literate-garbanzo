--[[
	汎用ダミーを使った演出 (見た目だけ / 自分にだけ見える)
	・実在のプレイヤーは使いません。標準のRobloxアバター(ダミー)が地面に押し倒されています
	・実行者が両手でナイフを握り、「ごめんっ…」と言いながら何度も振り下ろします
	・ダミーは暴れ、だんだん弱っていきます
	・血の代わりに、黒紫の墨の水たまりがじわじわ広がります
	・セリフは公開チャットではなく、自分の画面にだけ出る字幕です
	・モバイル用 (タッチ操作のGui付き / 小型・オブシディアン配色)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

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
if env.StabSceneCleanup then
	pcall(env.StabSceneCleanup)
end

------------------------------------------------------------------
-- 設定
------------------------------------------------------------------
local INK_A = Color3.fromRGB(38, 10, 58)    -- 墨の色(黒紫)
local INK_B = Color3.fromRGB(12, 4, 20)
local STAB_COUNT = 6
local KNEEL_H = 2.15      -- しゃがんだ時のHRPの高さ(地面から)
local TOP_UP = 4.0        -- 振り上げた時の手の高さ(胸の上)
local BOT_UP = 1.55       -- 振り下ろした時の手の高さ(胸の上)

local Alive = false
local Running = false
local Ctx = nil
local rng = Random.new()

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

local function Wait(sec)
	local t0 = os.clock()
	while Alive and os.clock() - t0 < sec do
		RunService.Heartbeat:Wait()
	end
end

------------------------------------------------------------------
-- モーター (手足) の取得とポーズ
------------------------------------------------------------------
local function CollectMotors(model)
	local defs = {
		{key = "shR", names = {"RightShoulder", "Right Shoulder"}, sign = 1},
		{key = "shL", names = {"LeftShoulder", "Left Shoulder"}, sign = -1},
		{key = "hipR", names = {"RightHip", "Right Hip"}, sign = 1},
		{key = "hipL", names = {"LeftHip", "Left Hip"}, sign = -1},
		{key = "knR", names = {"RightKnee"}, sign = 1},
		{key = "knL", names = {"LeftKnee"}, sign = -1},
	}
	local list = {}
	for _, def in ipairs(defs) do
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") then
				for _, n in ipairs(def.names) do
					if d.Name == n then
						list[def.key] = {m = d, c0 = d.C0, sign = def.sign}
					end
				end
			end
		end
	end
	return list
end

local function Pose(motors, key, swing, spread)
	local e = motors[key]
	if not e then return end
	local pos = e.c0.Position
	local rot = e.c0 - pos
	e.m.C0 = CFrame.new(pos) * CFrame.Angles(swing, 0, spread) * rot
end

local function RestoreMotors(motors)
	for _, e in pairs(motors or {}) do
		pcall(function() e.m.C0 = e.c0 end)
	end
end

------------------------------------------------------------------
-- 汎用ダミー (標準のRobloxアバター)
------------------------------------------------------------------
local function MakeDummy(char)
	local model = nil

	-- 1) 標準のR15アバターを生成
	pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = Color3.fromRGB(245, 205, 48)
		desc.LeftArmColor = Color3.fromRGB(245, 205, 48)
		desc.RightArmColor = Color3.fromRGB(245, 205, 48)
		desc.TorsoColor = Color3.fromRGB(13, 105, 172)
		desc.LeftLegColor = Color3.fromRGB(40, 127, 71)
		desc.RightLegColor = Color3.fromRGB(40, 127, 71)
		desc.Face = 144080495
		model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)

	-- 2) 失敗した場合: 自分のキャラを複製して服やアクセサリーを外す
	if not model then
		pcall(function()
			char.Archivable = true
			model = char:Clone()
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("Accessory") or d:IsA("Clothing") or d:IsA("ShirtGraphic") then
					d:Destroy()
				end
			end
			local bc = model:FindFirstChildOfClass("BodyColors")
			if not bc then
				bc = Instance.new("BodyColors")
				bc.Parent = model
			end
			bc.HeadColor3 = Color3.fromRGB(245, 205, 48)
			bc.LeftArmColor3 = Color3.fromRGB(245, 205, 48)
			bc.RightArmColor3 = Color3.fromRGB(245, 205, 48)
			bc.TorsoColor3 = Color3.fromRGB(13, 105, 172)
			bc.LeftLegColor3 = Color3.fromRGB(40, 127, 71)
			bc.RightLegColor3 = Color3.fromRGB(40, 127, 71)
		end)
	end

	if not model then return nil end

	model.Name = "StabDummy"
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = true
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false
	end
	return model
end

------------------------------------------------------------------
-- ナイフ
------------------------------------------------------------------
local function BuildKnife(parent)
	local m = Instance.new("Model")
	m.Name = "Knife"
	local function P(size, cf, color, mat, refl)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat
		p.Reflectance = refl or 0
		p.Parent = m
		return p
	end
	local STEEL = Color3.fromRGB(205, 210, 218)
	local handle = P(Vector3.new(0.22, 0.22, 0.9), CFrame.new(0, 0, 0.1), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic)
	P(Vector3.new(0.5, 0.12, 0.14), CFrame.new(0, 0, -0.38), Color3.fromRGB(60, 60, 66), Enum.Material.Metal, 0.2)
	P(Vector3.new(0.09, 0.36, 1.15), CFrame.new(0, 0, -1.0), STEEL, Enum.Material.Metal, 0.45)
	for i = 0, 3 do
		local w = 0.36 * (1 - (i + 1) / 5)
		P(Vector3.new(0.07, w, 0.2), CFrame.new(0, -(0.36 - w) / 2 * 0.0, -1.7 - i * 0.2), STEEL, Enum.Material.Metal, 0.45)
	end
	P(Vector3.new(0.24, 0.24, 0.12), CFrame.new(0, 0, 0.6), Color3.fromRGB(60, 60, 66), Enum.Material.Metal, 0.2)
	m.PrimaryPart = handle
	m.Parent = parent
	return m
end

------------------------------------------------------------------
-- 墨の水たまり (血の代わり)
------------------------------------------------------------------
local function SpawnPool(folder, center)
	for k = 1, 9 do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.4
		p.Color = (k % 3 == 0) and INK_B or INK_A
		p.Size = Vector3.new(0.05, 0.2, 0.2)
		local off = Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
		p.CFrame = CFrame.new(center + off + Vector3.new(0, 0.03 + k * 0.004, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		p.Parent = folder
		local d = rng:NextNumber(3.5, 7.5)
		TweenService:Create(p, TweenInfo.new(rng:NextNumber(6, 10), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.05, d, d)
		}):Play()
	end
end

------------------------------------------------------------------
-- 後片付け
------------------------------------------------------------------
local function Teardown()
	local c = Ctx
	Alive = false
	Running = false
	Ctx = nil
	if not c then return end
	pcall(function() c.conn:Disconnect() end)
	pcall(function() c.diedConn:Disconnect() end)
	RestoreMotors(c.motors)
	pcall(function() c.hum.PlatformStand = false end)
	pcall(function() c.hum.AutoRotate = true end)
	pcall(function() c.hum.CameraOffset = Vector3.zero end)
	pcall(function() c.hrp.AssemblyLinearVelocity = Vector3.zero end)
	pcall(function() c.hrp.Anchored = false end)
	if c.Folder then pcall(function() c.Folder:Destroy() end) end
	if c.subGui then pcall(function() c.subGui:Destroy() end) end
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

	local function Try(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			Notify("エラー: " .. label, tostring(err), 8)
		end
		return ok
	end

	local Folder = Instance.new("Folder")
	Folder.Name = "StabSceneFx"
	Folder.Parent = Workspace

	Ctx = {char = char, hum = hum, hrp = hrp, Folder = Folder}

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char, Folder}

	-- 向きと位置
	local look = hrp.CFrame.LookVector
	local F = Vector3.new(look.X, 0, look.Z)
	if F.Magnitude < 0.01 then F = Vector3.new(0, 0, -1) end
	F = F.Unit
	local yawP = math.atan2(-F.X, -F.Z)

	local want = hrp.Position + F * 5.2
	local res = Workspace:Raycast(want + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), params)
	local gy = res and res.Position.Y or (hrp.Position.Y - 3)
	local E = Vector3.new(want.X, gy + 1.0, want.Z)          -- ダミーのHRP位置
	local yawD = yawP + math.pi                               -- 頭が前(F方向)を向くように
	local chest = E + F * 1.0 + Vector3.new(0, 0.7, 0)        -- 刺す位置
	local P0 = Vector3.new(E.X, gy + KNEEL_H, E.Z) - F * 1.0  -- 実行者の位置(馬乗り)

	-- 字幕 (自分の画面だけ)
	local subGui = Instance.new("ScreenGui")
	subGui.Name = "StabSceneSub"
	subGui.ResetOnSpawn = false
	subGui.DisplayOrder = 2000
	pcall(function() subGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
	if not subGui.Parent then
		pcall(function() subGui.Parent = game:GetService("CoreGui") end)
	end
	Ctx.subGui = subGui
	local subLbl = Instance.new("TextLabel")
	subLbl.AnchorPoint = Vector2.new(0.5, 1)
	subLbl.Position = UDim2.new(0.5, 0, 0.86, 0)
	subLbl.Size = UDim2.new(0.9, 0, 0, 44)
	subLbl.BackgroundTransparency = 1
	subLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	subLbl.TextStrokeTransparency = 0
	subLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subLbl.Font = Enum.Font.SourceSansBold
	subLbl.TextSize = 28
	subLbl.Text = ""
	subLbl.TextTransparency = 1
	subLbl.TextStrokeTransparency = 1
	subLbl.Parent = subGui
	local subId = 0
	local function Say(text, shake)
		subId += 1
		local my = subId
		subLbl.Text = text
		subLbl.TextTransparency = 0
		subLbl.TextStrokeTransparency = 0
		local j = shake or 0
		subLbl.Position = UDim2.new(0.5, rng:NextInteger(-j, j), 0.86, rng:NextInteger(-j, j))
		task.delay(1.4, function()
			if subId == my and subLbl.Parent then
				TweenService:Create(subLbl, TweenInfo.new(0.4), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
			end
		end)
	end

	local function ShakeCam(amount, dur)
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

	-- ダミー
	local dummy = MakeDummy(char)
	if not dummy then
		Notify("エラー", "ダミーを作れませんでした", 5)
		Teardown()
		return
	end
	local dHRP = dummy:FindFirstChild("HumanoidRootPart")
	if not dHRP then
		Notify("エラー", "ダミーの作成に失敗しました", 5)
		Teardown()
		return
	end
	dHRP.Anchored = true
	local dBase = CFrame.new(E) * CFrame.Angles(0, yawD, 0) * CFrame.Angles(math.pi / 2, 0, 0)
	dHRP.CFrame = dBase
	dummy.Parent = Folder
	local dMotors = CollectMotors(dummy)

	-- 実行者
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.Anchored = true
	hum.PlatformStand = true
	hum.AutoRotate = false
	local pMotors = CollectMotors(char)
	Ctx.motors = pMotors

	local rHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local lHand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
	local function HandPoint(limb)
		if limb.Name:find(" ") then
			return (limb.CFrame * CFrame.new(0, -limb.Size.Y / 2 + 0.3, 0)).Position
		end
		return limb.Position
	end

	local knife = BuildKnife(Folder)

	local T = 0
	local startPos = hrp.Position
	local basePos = startPos
	local yaw = math.atan2(-F.X, -F.Z)
	local State = {
		S = 0, psi = 0, crouch = 0, lean = 0, stab = 0, yOff = 0,
		A = 0.3, spike = 0, ik = false, knife = false, shake = 0,
	}

	local function GetHands()
		if rHand and lHand then
			return (HandPoint(rHand) + HandPoint(lHand)) / 2
		end
		return hrp.Position
	end

	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not Running or not Ctx then return end
		dt = math.min(dt, 1 / 20)
		T += dt
		State.spike *= math.exp(-dt * 8)

		-- 実行者
		local Hm = GetHands()
		if State.ik then
			local top = chest + Vector3.new(0, TOP_UP, 0) - F * 0.5
			local bot = chest + Vector3.new(0, BOT_UP, 0)
			local target = top:Lerp(bot, State.stab)
			local gain = math.min(dt * 14, 1)
			basePos += Vector3.new(target.X - Hm.X, 0, target.Z - Hm.Z) * gain
			local flat = Vector3.new(basePos.X - P0.X, 0, basePos.Z - P0.Z)
			if flat.Magnitude > 2.2 then
				flat = flat.Unit * 2.2
				basePos = Vector3.new(P0.X + flat.X, basePos.Y, P0.Z + flat.Z)
			end
			State.yOff = math.clamp(State.yOff + (target.Y - Hm.Y) * math.min(dt * 10, 1), -0.5, 0.9)
		end
		local j = Vector3.new(math.sin(T * 43), math.sin(T * 37 + 1), math.cos(T * 41)) * State.shake
		hrp.CFrame = CFrame.new(basePos + Vector3.new(0, State.yOff, 0) + j) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(State.lean, 0, 0)

		Pose(pMotors, "shR", State.S, -State.psi)
		Pose(pMotors, "shL", State.S, State.psi)
		Pose(pMotors, "hipR", State.crouch * 1.0, State.crouch * 0.35)
		Pose(pMotors, "hipL", State.crouch * 1.0, -State.crouch * 0.35)
		Pose(pMotors, "knR", -State.crouch * 1.8, 0)
		Pose(pMotors, "knL", -State.crouch * 1.8, 0)

		-- ナイフ (両手の中間に持つ)
		if State.knife then
			local d = chest - Hm
			if d.Magnitude < 0.1 then d = Vector3.new(0, -1, 0) end
			d = d.Unit
			local upv = (math.abs(d.Y) > 0.95) and F or Vector3.yAxis
			knife:PivotTo(CFrame.lookAt(Hm, Hm + d, upv))
		else
			knife:PivotTo(CFrame.new(0, -5000, 0))
		end

		-- ダミー (暴れる)
		local A = State.A + State.spike
		local jit = Vector3.new(math.sin(T * 31), math.abs(math.sin(T * 17)) * 0.5, math.cos(T * 27)) * A * 0.18
		dHRP.CFrame = CFrame.new(jit) * dBase * CFrame.Angles(math.sin(T * 13) * A * 0.12, 0, math.sin(T * 15 + 1) * A * 0.3)
		Pose(dMotors, "shR", A * 1.3 * math.sin(T * 9), 0.5 + A * 0.8 * (0.5 + 0.5 * math.sin(T * 7)))
		Pose(dMotors, "shL", A * 1.3 * math.sin(T * 9 + 2.1), -(0.5 + A * 0.8 * (0.5 + 0.5 * math.sin(T * 7 + 1.3))))
		Pose(dMotors, "hipR", A * 1.1 * math.sin(T * 10 + 4.2) + 0.1, 0.1 + A * 0.5 * (0.5 + 0.5 * math.sin(T * 8)))
		Pose(dMotors, "hipL", A * 1.1 * math.sin(T * 10 + 1.0) + 0.1, -(0.1 + A * 0.5 * (0.5 + 0.5 * math.sin(T * 8 + 2))))
		Pose(dMotors, "knR", -A * 1.2 * (0.5 + 0.5 * math.sin(T * 12)), 0)
		Pose(dMotors, "knL", -A * 1.2 * (0.5 + 0.5 * math.sin(T * 12 + 1.7)), 0)
	end)
	Ctx.conn = conn
	Ctx.diedConn = hum.Died:Connect(function()
		Teardown()
	end)

	Notify("演出", "汎用ダミーを使った見た目だけの演出です (解除でいつでも終了)", 4)

	------------------------------------------------------------
	-- 1) 馬乗りの位置へ近づく
	------------------------------------------------------------
	Try("近づく", function()
		Wait(1.0) -- ダミーが弱く暴れている
		Animate(1.1, function(a)
			local e = Ease(a)
			basePos = startPos:Lerp(P0, e)
			State.crouch = 0.6 * e
			State.lean = -0.1 * e
		end)
		yaw = yawP
	end)

	------------------------------------------------------------
	-- 2) 両手でナイフを振り上げる
	------------------------------------------------------------
	Try("構える", function()
		if not Alive then return end
		State.knife = true
		State.A = 0.6
		Say("ごめんっ…", 2)
		Animate(0.9, function(a)
			local e = Ease(a)
			State.S = 3.0 * e
			State.psi = 0.5 * e
			State.crouch = 0.6 + 0.4 * e
			State.lean = -0.1 + 0.2 * e
		end)
		State.ik = true
		Wait(0.3)
	end)

	------------------------------------------------------------
	-- 3) 何度も刺す
	------------------------------------------------------------
	Try("刺す", function()
		local amps = {1.0, 0.95, 0.8, 0.6, 0.4, 0.2}
		local lines = {"ごめんっ…", "ごめんっ…！", "ごめん…ごめんっ！", "ごめんっ！", "ごめん…", "……ごめん"}
		for i = 1, STAB_COUNT do
			if not Alive then return end
			-- 振り上げ
			if i > 1 then
				local w = math.max(0.45 - 0.04 * i, 0.22)
				Animate(w, function(a)
					local e = Ease(a)
					State.stab = 1 - e
					State.S = 1.4 + 1.6 * (1 - State.stab)
					State.lean = -0.4 + 0.5 * (1 - State.stab)
				end)
				Wait(0.06)
			end
			-- 振り下ろし
			Animate(0.11, function(a)
				local e = a * a
				State.stab = e
				State.S = 3.0 - 1.6 * e
				State.lean = 0.1 - 0.5 * e
			end)
			-- 刺さった瞬間
			State.A = amps[i]
			State.spike = 0.9
			State.shake = 0.06
			ShakeCam(0.35, 0.25)
			Say(lines[i], 3 + (STAB_COUNT - i))
			if i == 2 then
				SpawnPool(Folder, Vector3.new(E.X, gy + 0.02, E.Z))
			end
			Wait(0.13)
			State.shake = 0
		end
	end)

	------------------------------------------------------------
	-- 4) 動かなくなる → 墨が広がるのを眺める
	------------------------------------------------------------
	Try("余韻", function()
		if not Alive then return end
		local a0 = State.A
		Animate(0.9, function(a)
			State.A = a0 * (1 - Ease(a))
		end)
		State.A = 0
		Wait(1.0)
		Say("……ごめん……", 0)
		Animate(1.2, function(a)
			local e = Ease(a)
			State.S = 1.4 - 0.9 * e
			State.psi = 0.5 - 0.3 * e
		end)
		Wait(4.5)
	end)

	------------------------------------------------------------
	-- 終了
	------------------------------------------------------------
	local done = Alive
	Teardown()
	if done then
		Notify("終了", "演出が終わりました", 3)
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
gui.Name = "StabSceneGui"
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
title.Text = "ツータイム風"
title.TextColor3 = OBS_TEXT
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true
title.Parent = main

local closeBtn = MakeButton(main, "×", UDim2.fromOffset(22, 22), UDim2.new(1, -26, 0, 2), 16)
local startBtn = MakeButton(main, "実行", UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 30), 16)
local resetBtn = MakeButton(main, "解除", UDim2.new(1, -12, 0, 28), UDim2.fromOffset(6, 62), 16)

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
	env.StabSceneCleanup = nil
end

closeBtn.Activated:Connect(FullCleanup)
env.StabSceneCleanup = FullCleanup

Notify("ツータイム風", "Guiを読み込みました。「実行」で汎用ダミーの演出が始まります", 4)
