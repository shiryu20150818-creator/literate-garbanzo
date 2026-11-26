-- ============================================================
-- FakeWannaCry — 選択式・運命分岐エクスペリエンス
-- 見た目だけ。本物の暗号化は一切しない。Roblox ScreenGui のみ。
-- ============================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local old = PlayerGui:FindFirstChild("FakeWannaCry")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FakeWannaCry"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- ============================================================
-- 状態管理
-- ============================================================
local State = {
	Money = 1000000,          -- 手持ち 100万円
	Demand = 900000,          -- 請求 90万円
	FilesEncrypted = false,
	Timer = 7 * 86400,        -- 7日
	TimeLeft = 7 * 86400,
	Stage = "intro",          -- intro / bsod / ransom / choice / ending
	ChoiceHistory = {},
	FamilyPhotosLost = false,
	PoliceCalled = false,
	Paid = false,
	Negotiated = false,
	Ending = nil,
}

-- ============================================================
-- ユーティリティ
-- ============================================================
local function MakeFrame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do f[k] = v end
	f.Parent = parent
	return f
end

local function MakeLabel(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = Enum.Font.Gotham
	l.TextColor3 = Color3.fromRGB(255, 220, 220)
	l.TextSize = 16
	for k, v in props do l[k] = v end
	l.Parent = parent
	return l
end

local function MakeButton(parent, props, callback)
	local b = Instance.new("TextButton")
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	for k, v in props do b[k] = v end
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 100, 100)
	stroke.Thickness = 1
	stroke.Parent = b
	if callback then b.MouseButton1Click:Connect(callback) end
	return b
end

local function FadeIn(obj, duration)
	obj.BackgroundTransparency = 1
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then obj.TextTransparency = 1 end
	local info = TweenInfo.new(duration or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = {}
	for _, prop in { "BackgroundTransparency", "TextTransparency" } do
		if pcall(function() return obj[prop] end) then
			goal[prop] = obj[prop] == 1 and 0 or obj[prop]
		end
	end
	TweenService:Create(obj, info, goal):Play()
end

local function Shake(obj, intensity, duration)
	intensity = intensity or 5
	duration = duration or 0.3
	local orig = obj.Position
	local start = tick()
	task.spawn(function()
		while tick() - start < duration do
			obj.Position = orig + UDim2.fromOffset(
				math.random(-intensity, intensity),
				math.random(-intensity, intensity)
			)
			task.wait(0.02)
		end
		obj.Position = orig
	end)
end

-- ============================================================
-- 背景（赤黒）
-- ============================================================
local Background = MakeFrame(ScreenGui, {
	Name = "Background",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(10, 0, 0),
})

local RedOverlay = MakeFrame(Background, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(180, 0, 0),
	BackgroundTransparency = 0.9,
})

-- 赤い点滅
task.spawn(function()
	while ScreenGui.Parent do
		TweenService:Create(RedOverlay, TweenInfo.new(1.2), { BackgroundTransparency = 0.75 }):Play()
		task.wait(1.2)
		TweenService:Create(RedOverlay, TweenInfo.new(1.2), { BackgroundTransparency = 0.95 }):Play()
		task.wait(1.2)
	end
end)

-- ============================================================
-- メインコンテナ
-- ============================================================
local Container = MakeFrame(Background, {
	Name = "Container",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1000, 700),
	BackgroundColor3 = Color3.fromRGB(20, 0, 0),
})
local ContainerCorner = Instance.new("UICorner")
ContainerCorner.CornerRadius = UDim.new(0, 10)
ContainerCorner.Parent = Container
local ContainerStroke = Instance.new("UIStroke")
ContainerStroke.Color = Color3.fromRGB(200, 0, 0)
ContainerStroke.Thickness = 2
ContainerStroke.Parent = Container

-- ヘッダー
local Header = MakeFrame(Container, {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 90),
	BackgroundColor3 = Color3.fromRGB(80, 0, 0),
})
local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local LockIcon = MakeLabel(Header, {
	Size = UDim2.fromOffset(60, 60),
	Position = UDim2.fromOffset(20, 15),
	Text = "🔒",
	TextSize = 48,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 50, 50),
})

local Title = MakeLabel(Header, {
	Size = UDim2.new(1, -100, 0, 40),
	Position = UDim2.fromOffset(100, 15),
	Text = "Wana Decrypt0r 2.0",
	TextSize = 32,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 50, 50),
	TextXAlignment = Enum.TextXAlignment.Left,
})

local Subtitle = MakeLabel(Header, {
	Size = UDim2.new(1, -100, 0, 20),
	Position = UDim2.fromOffset(100, 55),
	Text = "Ooops, your files have been encrypted!",
	TextSize = 16,
	TextColor3 = Color3.fromRGB(255, 150, 150),
	TextXAlignment = Enum.TextXAlignment.Left,
})

-- 本文
local Body = Instance.new("ScrollingFrame")
Body.Position = UDim2.fromOffset(20, 110)
Body.Size = UDim2.new(1, -40, 1, -200)
Body.BackgroundTransparency = 1
Body.BorderSizePixel = 0
Body.ScrollBarThickness = 6
Body.ScrollBarImageColor3 = Color3.fromRGB(200, 0, 0)
Body.CanvasSize = UDim2.new(0, 0, 0, 0)
Body.AutomaticCanvasSize = Enum.AutomaticSize.Y
Body.Parent = Container

local BodyLayout = Instance.new("UIListLayout")
BodyLayout.Padding = UDim.new(0, 10)
BodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
BodyLayout.Parent = Body

local function AddText(text, color, size, bold)
	local label = MakeLabel(Body, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextColor3 = color or Color3.fromRGB(255, 200, 200),
		TextSize = size or 16,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	return label
end

-- フッター
local Footer = MakeFrame(Container, {
	Name = "Footer",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 80),
	BackgroundColor3 = Color3.fromRGB(50, 0, 0),
})
local FooterCorner = Instance.new("UICorner")
FooterCorner.CornerRadius = UDim.new(0, 10)
FooterCorner.Parent = Footer

local TimerLabel = MakeLabel(Footer, {
	Size = UDim2.new(0.4, 0, 1, 0),
	Position = UDim2.fromOffset(20, 0),
	Text = "Time left: 07:00:00:00",
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 50, 50),
	TextXAlignment = Enum.TextXAlignment.Left,
})

local MoneyLabel = MakeLabel(Footer, {
	Size = UDim2.new(0.6, 0, 1, 0),
	Position = UDim2.new(0.4, 0, 0, 0),
	Text = "所持金: ¥1,000,000 | 請求: ¥900,000",
	TextSize = 16,
	Font = Enum.Font.Code,
	TextColor3 = Color3.fromRGB(255, 220, 100),
	TextXAlignment = Enum.TextXAlignment.Right,
})

-- ボタンエリア
local ButtonsFrame = MakeFrame(Container, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 90),
	Size = UDim2.fromOffset(800, 50),
	BackgroundTransparency = 1,
})
local ButtonsLayout = Instance.new("UIListLayout")
ButtonsLayout.FillDirection = Enum.FillDirection.Horizontal
ButtonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ButtonsLayout.Padding = UDim.new(0, 10)
ButtonsLayout.Parent = ButtonsFrame

-- ============================================================
-- ステージ管理
-- ============================================================
local StageGui = MakeFrame(ScreenGui, {
	Name = "StageGui",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
})

-- ============================================================
-- BSOD（ブルースクリーン）エフェクト
-- ============================================================
local function ShowBSOD(text, duration, callback)
	StageGui.Visible = true
	local bsod = MakeFrame(StageGui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 170),
	})
	local bsodLabel = MakeLabel(bsod, {
		Size = UDim2.new(1, -80, 1, -80),
		Position = UDim2.fromOffset(40, 40),
		Text = text or "A fatal exception 0E has occurred at 0028:C0011E36 in VXD VMM(01) + 00010E36.\n\nThe current application will be terminated.\n\n*  Press any key to terminate the current application.\n*  Press CTRL+ALT+DEL again to restart your computer.\n   You will lose any unsaved information in all applications.\n\nPress any key to continue _",
		TextSize = 18,
		Font = Enum.Font.Code,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	})
	-- 点滅カーソル
	task.spawn(function()
		while bsod.Parent do
			bsodLabel.Text = bsodLabel.Text:gsub("_$", "")
			task.wait(0.5)
			bsodLabel.Text = bsodLabel.Text .. "_"
			task.wait(0.5)
		end
	end)
	task.delay(duration or 3, function()
		if bsod then bsod:Destroy() end
		StageGui.Visible = false
		if callback then callback() end
	end)
end

-- ============================================================
-- 画面フラッシュ
-- ============================================================
local function Flash(color, duration)
	local flash = MakeFrame(ScreenGui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color or Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		ZIndex = 99999,
	})
	TweenService:Create(flash, TweenInfo.new(duration or 0.3), { BackgroundTransparency = 1 }):Play()
	task.delay(duration or 0.3, function() flash:Destroy() end)
end

-- ============================================================
-- グリッチエフェクト
-- ============================================================
local function Glitch(duration)
	local glitch = MakeFrame(ScreenGui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 99998,
	})
	local start = tick()
	task.spawn(function()
		while tick() - start < (duration or 1) do
			local bar = MakeFrame(glitch, {
				Size = UDim2.new(1, 0, 0, math.random(2, 20)),
				Position = UDim2.new(0, 0, math.random(), 0),
				BackgroundColor3 = Color3.fromRGB(math.random(0, 255), 0, 0),
				BackgroundTransparency = 0.5,
			})
			task.delay(0.05, function() if bar then bar:Destroy() end end)
			task.wait(0.03)
		end
		if glitch then glitch:Destroy() end
	end)
end

-- ============================================================
-- ステージ1: イントロ（感染演出）
-- ============================================================
local function StageIntro()
	State.Stage = "intro"
	Body:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = Body

	AddText("システムに異常が発生しています...", Color3.fromRGB(255, 80, 80), 22, true)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("> 不明なプロセスが実行中です", Color3.fromRGB(255, 200, 200), 16)
	AddText("> ファイルシステムへのアクセスを検出", Color3.fromRGB(255, 200, 200), 16)
	AddText("> 暗号化プロセスが開始されました", Color3.fromRGB(255, 200, 200), 16)
	AddText("> 重要なファイルを暗号化しています...", Color3.fromRGB(255, 200, 200), 16)
	AddText("> 家族の写真を暗号化しています...", Color3.fromRGB(255, 200, 200), 16)
	AddText("> 思い出の動画を暗号化しています...", Color3.fromRGB(255, 200, 200), 16)
	AddText("> 連絡先を暗号化しています...", Color3.fromRGB(255, 200, 200), 16)

	-- ボタン
	for _, b in ButtonsFrame:GetChildren() do
		if b:IsA("TextButton") then b:Destroy() end
	end

	local ProceedBtn = MakeButton(ButtonsFrame, {
		Size = UDim2.fromOffset(300, 44),
		Text = "続行する",
	}, function()
		Glitch(0.5)
		Flash(Color3.fromRGB(255, 0, 0), 0.2)
		Shake(Container, 8, 0.5)
		task.wait(0.5)
		StageBSOD()
	end)
end

-- ============================================================
-- ステージ2: BSOD連発
-- ============================================================
local function StageBSOD()
	State.Stage = "bsod"
	Body:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = Body

	AddText("致命的なエラーが発生しました", Color3.fromRGB(255, 80, 80), 24, true)
	AddText("システムは復旧できません。", Color3.fromRGB(255, 200, 200), 18)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("以下のファイルが暗号化されました:", Color3.fromRGB(255, 200, 200), 16)
	AddText("  • C:\\Users\\YourName\\Documents\\", Color3.fromRGB(255, 180, 180), 14)
	AddText("  • C:\\Users\\YourName\\Pictures\\Family\\", Color3.fromRGB(255, 180, 180), 14)
	AddText("  • C:\\Users\\YourName\\Videos\\Wedding.mp4", Color3.fromRGB(255, 180, 180), 14)
	AddText("  • C:\\Users\\YourName\\Desktop\\重要書類.xlsx", Color3.fromRGB(255, 180, 180), 14)
	AddText("  • C:\\Users\\YourName\\Pictures\\子供の写真\\", Color3.fromRGB(255, 180, 180), 14)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("あなたの大切なファイルはすべて暗号化されました。", Color3.fromRGB(255, 50, 50), 18, true)

	for _, b in ButtonsFrame:GetChildren() do
		if b:IsA("TextButton") then b:Destroy() end
	end

	local ProceedBtn = MakeButton(ButtonsFrame, {
		Size = UDim2.fromOffset(300, 44),
		Text = "身代金画面へ",
	}, function()
		Glitch(0.5)
		Flash(Color3.fromRGB(0, 0, 255), 0.3)
		Shake(Container, 10, 0.5)
		task.wait(0.3)
		ShowBSOD("A fatal exception 0E has occurred at 0028:C0011E36 in VXD VMM(01).\n\nThe current application will be terminated.\n\n*  Press any key to terminate the current application.\n*  Press CTRL+ALT+DEL again to restart your computer.\n   You will lose any unsaved information in all applications.", 2.5, function()
			ShowBSOD("KERNEL_DATA_INPAGE_ERROR\n\n*** STOP: 0x0000007A (0xC000000E, 0xC000000E, 0x00000000, 0x00000000)\n\nBeginning dump of physical memory...", 2.5, function()
				ShowBSOD("CRITICAL_PROCESS_DIED\n\n*** STOP: 0x000000EF (0x00000000, 0x00000000, 0x00000000, 0x00000000)\n\nYour PC ran into a problem and needs to restart.", 2, function()
					StageRansom()
				end)
			end)
		end)
	end)
end

-- ============================================================
-- ステージ3: 身代金画面
-- ============================================================
local function StageRansom()
	State.Stage = "ransom"
	State.FilesEncrypted = true
	Body:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = Body

	AddText("あなたは感染しました", Color3.fromRGB(255, 50, 50), 26, true)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("あなたのファイルには大切な情報や、家族とのもう二度と撮れない写真が含まれています。", Color3.fromRGB(255, 220, 220), 18)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("請求金額: ¥900,000", Color3.fromRGB(255, 255, 0), 22, true)
	AddText("あなたの所持金: ¥1,000,000", Color3.fromRGB(255, 255, 0), 22, true)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("支払えばファイルは復号されます。", Color3.fromRGB(255, 200, 200), 18)
	AddText("支払わなければ、ファイルは永久に失われます。", Color3.fromRGB(255, 50, 50), 18, true)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("警察に相談することもできます。", Color3.fromRGB(100, 200, 255), 18)
	AddText("しかし、警察が動く保証はありません。", Color3.fromRGB(255, 200, 200), 16)

	for _, b in ButtonsFrame:GetChildren() do
		if b:IsA("TextButton") then b:Destroy() end
	end

	local PayBtn = MakeButton(ButtonsFrame, {
		Size = UDim2.fromOffset(280, 50),
		Text = "支払う (¥900,000)",
		BackgroundColor3 = Color3.fromRGB(0, 120, 0),
	}, function()
		State.Paid = true
		StagePayResult()
	end)

	local PoliceBtn = MakeButton(ButtonsFrame, {
		Size = UDim2.fromOffset(280, 50),
		Text = "警察に相談する",
		BackgroundColor3 = Color3.fromRGB(0, 80, 200),
	}, function()
		State.PoliceCalled = true
		StagePoliceResult()
	end)
end

-- ============================================================
-- ステージ4a: 支払い結果
-- ============================================================
local function StagePayResult()
	State.Stage = "pay_result"
	Body:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = Body

	State.Money = State.Money - State.Demand

	AddText("支払いが完了しました", Color3.fromRGB(0, 255, 100), 24, true)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("¥900,000 を送金しました。", Color3.fromRGB(255, 255, 0), 18)
	AddText("残りの所持金: ¥" .. string.format("%d", State.Money), Color3.fromRGB(255, 255, 0), 18)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("復号キーが送られてきました。", Color3.fromRGB(255, 200, 200), 16)
	AddText("ファイルは復号されています...", Color3.fromRGB(255, 200, 200), 16)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("しかし、あなたは気づいていません。", Color3.fromRGB(255, 100, 100), 18)
	AddText("この取引が、次の感染への入り口だったことに。", Color3.fromRGB(255, 100, 100), 18)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("あなたは身代金を支払いました。", Color3.fromRGB(255, 200, 200), 16)
	AddText("犯罪者に資金を提供したのです。", Color3.fromRGB(255, 50, 50), 18, true)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("エンディング: 支払いの代償", Color3.fromRGB(255, 255, 0), 22, true)

	State.Ending = "paid"

	for _, b in ButtonsFrame:GetChildren() do
		if b:IsA("TextButton") then b:Destroy() end
	end
	MakeButton(ButtonsFrame, {
		Size = UDim2.fromOffset(300, 44),
		Text = "最初からやり直す",
		BackgroundColor3 = Color3.fromRGB(80, 80, 80),
	}, function()
		ScreenGui:Destroy()
	end)
end

-- ============================================================
-- ステージ4b: 警察結果
-- ============================================================
local function StagePoliceResult()
	State.Stage = "police_result"
	Body:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = Body

	AddText("警察に相談しました", Color3.fromRGB(100, 200, 255), 24, true)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("警察はあなたの話を聞きました。", Color3.fromRGB(255, 200, 200), 16)
	AddText("しかし、彼らは言いました。", Color3.fromRGB(255, 200, 200), 16)
	AddText("「この種の犯罪は国境を越えています。追跡は困難です。」", Color3.fromRGB(200, 200, 200), 18)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("「ファイルの復号は保証できません。」", Color3.fromRGB(200, 200, 200), 18)
	AddText("「身代金は支払わないでください。」", Color3.fromRGB(200, 200, 200), 18)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("あなたは待つことにしました。", Color3.fromRGB(255, 200, 200), 16)
	AddText("1日、2日、3日...", Color3.fromRGB(255, 200, 200), 16)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("7日後、タイマーが0になりました。", Color3.fromRGB(255, 50, 50), 18)
	AddText("復号キーは永久に破棄されました。", Color3.fromRGB(255, 50, 50), 18)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("家族との写真は、もう戻りません。", Color3.fromRGB(255, 100, 100), 18)
	AddText("あなたの所持金は残っています。", Color3.fromRGB(255, 255, 0), 16)
	AddText("しかし、思い出は失われました。", Color3.fromRGB(255, 100, 100), 18)
	AddText("", Color3.fromRGB(255, 200, 200), 16)
	AddText("エンディング: 失われた思い出", Color3.fromRGB(255, 255, 0), 22, true)

	State.Ending = "police"

	for _, b in ButtonsFrame:GetChildren() do
		if b:IsA("TextButton") then b:Destroy() end
	end
	MakeButton(ButtonsFrame, {
		Size = UDim2.fromOffset(300, 44),
		Text = "最初からやり直す",
		BackgroundColor3 = Color3.fromRGB(80, 80, 80),
	}, function()
		ScreenGui:Destroy()
	end)
end

-- ============================================================
-- タイマーカウントダウン
-- ============================================================
task.spawn(function()
	while ScreenGui.Parent do
		if State.Stage == "ransom" or State.Stage == "intro" or State.Stage == "bsod" then
			State.TimeLeft = math.max(0, State.TimeLeft - 1)
			local d = math.floor(State.TimeLeft / 86400)
			local h = math.floor((State.TimeLeft % 86400) / 3600)
			local m = math.floor((State.TimeLeft % 3600) / 60)
			local s = State.TimeLeft % 60
			TimerLabel.Text = string.format("Time left: %02d:%02d:%02d:%02d", d, h, m, s)
			MoneyLabel.Text = string.format("所持金: ¥%d | 請求: ¥%d", State.Money, State.Demand)
		end
		task.wait(1)
	end
end)

-- ============================================================
-- 起動: イントロから
-- ============================================================
StageIntro()

-- ============================================================
-- ESCで閉じる（お前のため）
-- ============================================================
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if ScreenGui.Parent then
			ScreenGui:Destroy()
		end
	end
end)

-- 閉じるボタン
local CloseBtn = MakeButton(Background, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(30, 30),
	Text = "×",
	BackgroundColor3 = Color3.fromRGB(200, 0, 0),
	TextSize = 20,
}, function()
	ScreenGui:Destroy()
end)

print("[FakeWannaCry] 選択式エクスペリエンスを開始しました。実際の暗号化は一切していません。ESCで閉じます。")