--[[
	白黒ピクセル動画プレイヤー (モバイル用 / Gui付き)
	・画面に白黒のピクセル動画を最初から最後まで再生します
	・動画データは「BW1形式」のテキストを読み込みます (下の説明を参照)
	・データを指定しない場合は、オリジナルのデモアニメを再生します

	【使い方】 実行する前に、必要なら次のように設定できます
		getgenv().PixelVideoConfig = {
			url = "あなたが用意したBW1データのURL",
			-- audioId = 1234567,   -- 自分で用意した音声のアセットID(任意)
			-- loop = false,
		}

	【BW1形式】
		1行目: BW1 幅 高さ fps        例) BW1 64 48 15
		2行目以降: 1行が1フレーム。左上から右へ・下へ、白=1 黒=0 を
		          4ピクセルずつ16進数1文字にして並べた文字列

	【データの作り方 (PC / Python + OpenCV。自分で用意した動画用)】
		import cv2
		W,H,FPS=64,48,15
		cap=cv2.VideoCapture("input.mp4"); out=[f"BW1 {W} {H} {FPS}"]
		step=max(1,round(cap.get(cv2.CAP_PROP_FPS)/FPS)); i=0
		while True:
		    ok,f=cap.read()
		    if not ok: break
		    if i%step==0:
		        g=cv2.cvtColor(cv2.resize(f,(W,H)),cv2.COLOR_BGR2GRAY)
		        b="".join("1" if v>127 else "0" for v in g.flatten())
		        out.append("".join("%x"%int(b[k:k+4],2) for k in range(0,len(b),4)))
		    i+=1
		open("video.bw1","w").write("\n".join(out))
	※ 他の人が作った動画を使う場合は、その権利者のルールに従ってください
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local env = getgenv()

local function Notify(title, text, duration)
	StarterGui:SetCore("SendNotification", {
		Title = title,
		Text = text,
		Duration = duration
	})
end

if env.PixelPlayerCleanup then
	pcall(env.PixelPlayerCleanup)
end

local CFG = env.PixelVideoConfig or {}

------------------------------------------------------------------
-- 動画データの読み込み (BW1)
------------------------------------------------------------------
local W, H, FPS = 64, 48, 15
local frames = nil      -- {文字列,...}  (データ指定時)
local demo = true

local function ParseBW1(text)
	local lines = {}
	for line in string.gmatch(text, "[^\r\n]+") do
		lines[#lines + 1] = line
	end
	local w, h, fps = string.match(lines[1] or "", "^BW1%s+(%d+)%s+(%d+)%s+(%d+)")
	if not w then return nil end
	W, H, FPS = tonumber(w), tonumber(h), tonumber(fps)
	table.remove(lines, 1)
	return lines
end

if CFG.url then
	local ok, text = pcall(function()
		return game:HttpGet(CFG.url)
	end)
	if ok and text then
		local parsed = ParseBW1(text)
		if parsed and #parsed > 0 then
			frames = parsed
			demo = false
		else
			Notify("読み込み失敗", "BW1形式のデータではありません。デモを再生します", 5)
		end
	else
		Notify("読み込み失敗", "URLからデータを取得できませんでした。デモを再生します", 5)
	end
end

-- 16進文字列 → 1フレーム分のビット配列
local HEX = {}
for i = 0, 15 do
	HEX[string.format("%x", i)] = i
	HEX[string.format("%X", i)] = i
end

local function DecodeFrame(str)
	local bits = table.create(W * H, 0)
	local n = 0
	for i = 1, #str do
		local v = HEX[string.sub(str, i, i)] or 0
		bits[n + 1] = (v >= 8) and 1 or 0
		bits[n + 2] = (v % 8 >= 4) and 1 or 0
		bits[n + 3] = (v % 4 >= 2) and 1 or 0
		bits[n + 4] = (v % 2 >= 1) and 1 or 0
		n += 4
	end
	return bits
end

-- オリジナルのデモ (動く白い図形)
local DEMO_FRAMES = 15 * 20
local function DemoFrame(i)
	local t = i / FPS
	local bits = table.create(W * H, 0)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local on = 0
			-- 波打つ帯
			local wave = H * 0.5 + math.sin(x * 0.18 + t * 3) * H * 0.18
			if math.abs(y - wave) < 2.5 then on = 1 end
			-- 弾むボール
			local bx = W * 0.5 + math.sin(t * 1.3) * W * 0.34
			local by = H * 0.5 - math.abs(math.sin(t * 2.2)) * H * 0.38
			local dx, dy = x - bx, y - by
			if dx * dx + dy * dy < 36 then on = 1 end
			-- 回る輪
			local r = math.sqrt((x - W * 0.5) ^ 2 + (y - H * 0.5) ^ 2)
			if r > 17 and r < 19 and math.sin(math.atan2(y - H * 0.5, x - W * 0.5) * 6 + t * 4) > 0 then
				on = 1
			end
			bits[y * W + x + 1] = on
		end
	end
	return bits
end

local total = demo and DEMO_FRAMES or #frames

------------------------------------------------------------------
-- Gui (画面いっぱいのピクセル表示 + 小さな操作ボタン)
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "PixelPlayerGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
pcall(function()
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)
if not gui.Parent then
	pcall(function()
		gui.Parent = game:GetService("CoreGui")
	end)
end

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
bg.BorderSizePixel = 0
bg.Parent = gui

local screen = Instance.new("Frame")
screen.AnchorPoint = Vector2.new(0.5, 0.5)
screen.Position = UDim2.fromScale(0.5, 0.5)
screen.Size = UDim2.fromScale(0.96, 0.96)
screen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
screen.BorderSizePixel = 0
screen.Parent = bg
local ar = Instance.new("UIAspectRatioConstraint")
ar.AspectRatio = W / H
ar.AspectType = Enum.AspectType.FitWithinMaxSize
ar.Parent = screen

-- ピクセル
local px = table.create(W * H)
local state = table.create(W * H, 0)
local BLACK, WHITE = Color3.fromRGB(0, 0, 0), Color3.fromRGB(255, 255, 255)
for y = 0, H - 1 do
	for x = 0, W - 1 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = BLACK
		f.Position = UDim2.fromScale(x / W, y / H)
		f.Size = UDim2.fromScale(1 / W + 0.0006, 1 / H + 0.0006)
		f.Parent = screen
		px[y * W + x + 1] = f
	end
end

local function ShowBits(bits)
	for i = 1, W * H do
		local v = bits[i] or 0
		if v ~= state[i] then
			state[i] = v
			px[i].BackgroundColor3 = (v == 1) and WHITE or BLACK
		end
	end
end

-- 操作ボタン
local OBS_BTN = Color3.fromRGB(20, 18, 28)
local function MakeButton(text, pos)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(46, 36)
	b.Position = pos
	b.BackgroundColor3 = OBS_BTN
	b.BackgroundTransparency = 0.25
	b.Text = text
	b.TextColor3 = Color3.fromRGB(210, 200, 235)
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 18
	b.ZIndex = 10
	b.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	return b
end
local playBtn = MakeButton("⏸", UDim2.new(0, 8, 1, -44))
local closeBtn = MakeButton("×", UDim2.new(0, 60, 1, -44))
local info = Instance.new("TextLabel")
info.Size = UDim2.fromOffset(160, 20)
info.Position = UDim2.new(0, 112, 1, -36)
info.BackgroundTransparency = 1
info.TextColor3 = Color3.fromRGB(150, 140, 175)
info.Font = Enum.Font.SourceSans
info.TextSize = 14
info.TextXAlignment = Enum.TextXAlignment.Left
info.ZIndex = 10
info.Text = ""
info.Parent = gui

-- 音声 (自分で用意したIDのみ / 任意)
local sound = nil
if CFG.audioId then
	sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(CFG.audioId)
	sound.Volume = 1
	sound.Parent = gui
end

------------------------------------------------------------------
-- 再生
------------------------------------------------------------------
local playing = true
local clock = 0
local lastIndex = -1
local conn
local loop = (CFG.loop ~= false) and demo or (CFG.loop == true)

local function Cleanup()
	if conn then conn:Disconnect() conn = nil end
	if sound then pcall(function() sound:Stop() end) end
	gui:Destroy()
	env.PixelPlayerCleanup = nil
end

playBtn.Activated:Connect(function()
	playing = not playing
	playBtn.Text = playing and "⏸" or "▶"
	if sound then
		if playing then sound:Resume() else sound:Pause() end
	end
end)
closeBtn.Activated:Connect(Cleanup)
env.PixelPlayerCleanup = Cleanup

if sound then sound:Play() end

conn = RunService.Heartbeat:Connect(function(dt)
	if not playing then return end
	clock += dt
	local idx = math.floor(clock * FPS)
	if idx >= total then
		if loop then
			clock = 0
			idx = 0
			if sound then sound.TimePosition = 0 end
		else
			playing = false
			playBtn.Text = "▶"
			clock = 0
			return
		end
	end
	if idx ~= lastIndex then
		lastIndex = idx
		local bits
		if demo then
			bits = DemoFrame(idx)
		else
			bits = DecodeFrame(frames[idx + 1])
		end
		ShowBits(bits)
		info.Text = string.format("%d / %d  (%dfps)", idx + 1, total, FPS)
	end
end)
