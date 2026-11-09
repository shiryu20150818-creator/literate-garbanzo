--[[
	NOT-PETYA JOKE  -  cosmetic screen prank (mobile / executor)
	=====================================================================
	A LOOKS-ONLY parody of the famous "Petya/NotPetya" boot screen: the blinking
	red skull made of ASCII characters, then a fake ransom note with a countdown.

	IMPORTANT - what this is NOT:
	  * It does NOT touch, read, encrypt, or delete any files
	  * It does NOT access the Master Boot Record or any disk structure
	  * It does NOT send anything over the network, to anyone
	  * It does NOT collect money - the BTC address shown is a dummy string
	    labelled "FAKE - DO NOT SEND" in both languages
	  * It does NOT affect other players - everything is local to your screen
	  * A STOP button is always on screen and always works
	This is a harmless visual joke: a flashing skull, a fake "repairing disk"
	bar that always finishes at 100%, and a ransom note you can "decrypt" by
	typing anything, which always "works" and ends the joke.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

local function Notify(title, text, duration)
	StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = duration})
end

if getgenv().NotPetyaJoke then
	pcall(function() getgenv().NotPetyaJoke.Unload() end)
end

local V = {Conns = {}, R = Random.new(), Lang = "ja", Running = false, Acked = false}
local function New(class, props)
	local o = Instance.new(class)
	local parent = nil
	for k, val in pairs(props or {}) do
		if k == "Parent" then parent = val else o[k] = val end
	end
	if parent then o.Parent = parent end
	return o
end
local function T(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function Connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(V.Conns, c)
	return c
end
local function Tr(ja, en) if V.Lang == "ja" then return ja end return en end
local function Rf(a, b) return a + V.R:NextNumber() * (b - a) end
local function Ri(a, b) return V.R:NextInteger(a, b) end
local function Corner(p, r) return New("UICorner", {CornerRadius = UDim.new(0, r), Parent = p}) end
local function ParentGui(g)
	local ok = pcall(function() g.Parent = CoreGui end)
	if not ok or not g.Parent then g.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end
local RED = Color3.fromRGB(180, 0, 0)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

-- ======================================================================
-- GUI roots: effect layer (below) + control layer (always on top: STOP button)
-- ======================================================================
local Gui = New("ScreenGui", {Name = "NotPetyaJokeFX", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 500, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
ParentGui(Gui)
local CGui = New("ScreenGui", {Name = "NotPetyaJokeCtl", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
ParentGui(CGui)

local Layers = {}
local function Layer(name, z)
	if Layers[name] then pcall(function() Layers[name]:Destroy() end) end
	local f = New("Frame", {Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false, ZIndex = z, BorderSizePixel = 0, Parent = Gui})
	Layers[name] = f
	return f
end
local function DropLayer(name)
	if Layers[name] then
		pcall(function() Layers[name]:Destroy() end)
		Layers[name] = nil
	end
end
local function DropAll()
	for n in pairs(Layers) do DropLayer(n) end
end

local function Beep(pitch, vol)
	local s = New("Sound", {SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = vol or 0.2, PlaybackSpeed = pitch or 1, Parent = SoundService})
	s:Play()
	Debris:AddItem(s, 3)
end

-- ======================================================================
-- STOP button + pill (always above everything, always works)
-- ======================================================================
local pill = New("TextButton", {Size = UDim2.fromOffset(100, 30), Position = UDim2.fromOffset(14, 60), BackgroundColor3 = Color3.fromRGB(10, 10, 10), Text = "PETYA", Font = Enum.Font.Code, TextSize = 14, TextColor3 = RED, AutoButtonColor = false, ZIndex = 50, Parent = CGui})
Corner(pill, 8)
New("UIStroke", {Thickness = 1.6, Color = RED, Parent = pill})

local stop = New("TextButton", {Size = UDim2.fromOffset(150, 38), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(190, 20, 20), Text = "", AutoButtonColor = false, ZIndex = 60, Parent = CGui})
Corner(stop, 10)
New("UIStroke", {Thickness = 2, Color = WHITE, Parent = stop})
local stopLbl = New("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = WHITE, Text = "■ 停止 / STOP", Parent = stop})

local DragH, DragE = nil, nil
Connect(UserInputService.InputChanged, function(i)
	if DragH and i.UserInputType == Enum.UserInputType.Touch then DragH(i.Position) end
end)
Connect(UserInputService.InputEnded, function(i)
	if i.UserInputType == Enum.UserInputType.Touch and DragE then DragE() end
end)
local function Draggable(handle, target, onTap)
	Connect(handle.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		local start = input.Position
		local sp = target.Position
		local moved = false
		DragH = function(pos)
			local d = pos - start
			if d.Magnitude > 8 then moved = true end
			if moved then target.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end
		end
		DragE = function()
			DragH, DragE = nil, nil
			if not moved and onTap then onTap() end
		end
	end)
end

local Gen = 0
local function StopAll()
	Gen = Gen + 1
	V.Running = false
	DropAll()
	Notify("NotPetya Joke", "Stopped", 2)
end
Connect(stop.Activated, StopAll)

-- ======================================================================
-- warning modal (shown once before starting)
-- ======================================================================
local modal = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Visible = false, ZIndex = 80, Active = true, Parent = CGui})
local box = New("Frame", {Size = UDim2.fromOffset(340, 210), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(14, 10, 10), ZIndex = 81, Parent = modal})
Corner(box, 14)
New("UIStroke", {Thickness = 2, Color = RED, Parent = box})
New("TextLabel", {Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 10), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 82, Text = Tr("注意: これはジョークです", "Notice: this is a joke"), Parent = box})
New("TextLabel", {Size = UDim2.new(1, -24, 0, 110), Position = UDim2.fromOffset(12, 38), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = WHITE, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 82,
	Text = Tr("有名なマルウェア『Petya/NotPetya』の起動画面の見た目だけを再現したジョークです。ファイルの暗号化・削除、ディスクへのアクセス、通信は一切行いません。表示されるBitcoinアドレスは偽物で、お金は一切集めません。点滅あり。STOPはいつでも押せます。", "A looks-only parody of the famous Petya/NotPetya boot screen. It does not encrypt or delete files, does not touch your disk, and sends nothing over the network. The BTC address shown is fake and collects no money. Contains flashing. STOP always works."),
	Parent = box})
local pending = nil
local function WBtn(text, x, col, fn)
	local b = New("TextButton", {Size = UDim2.fromOffset(150, 34), Position = UDim2.new(0, x, 1, -46), BackgroundColor3 = col, Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE, AutoButtonColor = false, ZIndex = 82, Parent = box})
	Corner(b, 9)
	Connect(b.Activated, fn)
end
WBtn(Tr("続ける", "Continue"), 12, Color3.fromRGB(30, 140, 80), function()
	modal.Visible = false
	V.Acked = true
	local cb = pending
	pending = nil
	if cb then cb() end
end)
WBtn(Tr("やめる", "Cancel"), 178, Color3.fromRGB(90, 30, 30), function()
	modal.Visible = false
	pending = nil
end)
local function Guarded(fn)
	if V.Acked then fn() else
		pending = fn
		modal.Visible = true
	end
end

-- ======================================================================
-- ASCII SKULL (built from a monospace TextLabel, like the real splash art)
-- ======================================================================
local SKULL = table.concat({
"                          ооооооооо",
"                      ооо<>оооооо<>ооо",
"                   оо<><>оооооооооо<><>оо",
"                 оо<><>оооооооооооооо<><>оо",
"               оо<><>оооооооооооооооооо<><>оо",
"              о<><>ооооооооооооооооооооооо<><>о",
"             о<>оооооооооооооооооооооооооооо<>о",
"            о<>ооооооооооооооооооооооooоooооo<>о",
"           о<>оооооооoo%%%%%oooooоoo%%%%%ooooо<>о",
"           о<>ооооооoo%%%%%%%oooоoo%%%%%%%oooо<>о",
"           о<>оооооoo%%%%%%%%%ooоoo%%%%%%%%%oо<>о",
"            о<>оооoo%%%%OOO%%%oooo%%%OOO%%%oоo<>о",
"             о<>ооoo%%%OO#OO%%ooоoo%%OO#OO%%oo<>о",
"              о<>оoo%%%OOOOO%%ooооoo%%OOOOO%%oо<>о",
"               о<>оoo%%%%%%%ooоoooоoo%%%%%%%oо<>о",
"                о<>оoo%%%%%ooооoооооoo%%%%%oо<>о",
"                 о<>ooooooooооooооoooooooooо<>о",
"                  о<>оооооооооVVVVоооооооооо<>о",
"                   о<>ооооооoVVVVVVoооооооо<>о",
"                    о<>оооооoVVVVVVoооооооo<>о",
"                     о<>ооооVVVVVVVVооооо<>о",
"                      о<>оооVVVVVVVVооо<>о",
"                       о<>ооVVVVVVVVоо<>о",
"                        о<>оVVVVVVVVо<>о",
"                         о<>VVVVVVVV<>о",
"                          о<>VVVVVV<>о",
"                           о<><><><>о",
"                            оооооооо",
"                      YOUR FILES ARE NOT",
"                      ACTUALLY ENCRYPTED",
}, "\n")

local function ShowSkull(cb)
	local layer = Layer("Skull", 30)
	local bg = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, Active = true, ZIndex = 30, Parent = layer})
	local hold = New("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 31, Parent = bg})
	local art = New("TextLabel", {
		Size = UDim2.new(1, -20, 1, -80), Position = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Text = SKULL, Font = Enum.Font.Code,
		TextSize = 10, TextColor3 = RED, TextWrapped = false, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 31, Parent = bg,
	})
	local pressLbl = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -60), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 16, TextColor3 = WHITE,
		Text = Tr("画面をタップしてください...", "Press any key / tap the screen..."), ZIndex = 31, Parent = bg,
	})
	local gen = Gen
	local done = false
	local function proceed()
		if done or gen ~= Gen then return end
		done = true
		Beep(0.5, 0.3)
		DropLayer("Skull")
		if cb then cb() end
	end
	Connect(hold.Activated, proceed)
	Beep(0.6, 0.3)
	task.spawn(function()
		local t = 0
		while not done and gen == Gen and bg.Parent do
			t = t + task.wait(0.08)
			local blink = (math.floor(t * 2.2) % 3 ~= 0)
			art.TextTransparency = blink and 0 or 1
			pressLbl.Visible = (math.floor(t * 2) % 2 == 0)
			-- small camera-ish screen shake via the art's position
			art.Position = UDim2.fromOffset(10 + Ri(-1, 1), 10 + Ri(-1, 1))
		end
	end)
	task.delay(6, proceed)
end

-- ======================================================================
-- FAKE "REPAIRING FILE SYSTEM" bar (always reaches 100%, nothing happens)
-- ======================================================================
local CHKDSK_LINES_JA = {
	"CHKDSK はドライブを修復しています。", "お使いのハードディスクを検査しています。",
	"このプロセス中にコンピュータの電源を切らないでください。", "電源を切ると、すべてのデータが失われる可能性があります。",
	"ごはんを食べながら待ちましょう。", "心配いりません、何も壊れていません。", "これはジョークです。",
}
local CHKDSK_LINES_EN = {
	"Repairing file system on C:", "The harddisk is being scanned.",
	"Do not turn off your computer during this process.", "If you turn off your computer, all data may be lost.",
	"Go grab a snack while you wait.", "Don't worry, nothing is actually broken.", "This is a joke.",
}

local function ShowChkdsk(cb)
	local layer = Layer("Chkdsk", 29)
	local bg = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, Active = true, ZIndex = 29, Parent = layer})
	local title = New("TextLabel", {
		Size = UDim2.new(1, -40, 0, 60), Position = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 18, TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = Tr("CHKDSK はドライブを修復しています。\nこのプロセスには時間がかかる場合があります。", "Repairing file system on C:\nThis process may take a while."), ZIndex = 30, Parent = bg,
	})
	local pct = New("TextLabel", {Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 90), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 16, TextColor3 = Color3.fromRGB(200, 200, 200), TextXAlignment = Enum.TextXAlignment.Left, Text = "0%", ZIndex = 30, Parent = bg})
	local log = New("TextLabel", {
		Size = UDim2.new(1, -40, 1, -170), Position = UDim2.fromOffset(20, 130), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 12, TextColor3 = Color3.fromRGB(170, 170, 170),
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "", ZIndex = 30, Parent = bg,
	})
	local gen = Gen
	task.spawn(function()
		local lines = {}
		local lineSrc = (V.Lang == "ja") and CHKDSK_LINES_JA or CHKDSK_LINES_EN
		local t0 = tick()
		local dur = 10
		local nextLine = 0
		while tick() - t0 < dur and gen == Gen and bg.Parent do
			local p = (tick() - t0) / dur
			pct.Text = string.format("%d%% complete", math.floor(p * 100))
			nextLine = nextLine - task.wait(0.05)
			if nextLine <= 0 then
				nextLine = Rf(0.8, 1.8)
				table.insert(lines, V.Pick and V.Pick(lineSrc) or lineSrc[Ri(1, #lineSrc)])
				if #lines > 7 then table.remove(lines, 1) end
				log.Text = table.concat(lines, "\n")
			end
		end
		if gen ~= Gen or not bg.Parent then return end
		pct.Text = "100% complete"
		task.wait(0.6)
		DropLayer("Chkdsk")
		if cb then cb() end
	end)
end

-- ======================================================================
-- RED GLITCH LAYER (behind the ransom note, purely decorative)
-- ======================================================================
local function StartGlitch()
	local layer = Layer("Glitch", 10)
	local cells = {}
	for i = 1, 18 do
		local f = New("Frame", {Size = UDim2.new(1, 0, 0, Ri(1, 4)), Position = UDim2.fromScale(0, V.R:NextNumber()), BackgroundColor3 = RED, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, Parent = layer})
		table.insert(cells, f)
	end
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not layer.Parent then
			if conn then conn:Disconnect() end
			return
		end
		for _, f in ipairs(cells) do
			if V.R:NextNumber() < 0.08 then
				f.Position = UDim2.fromScale((V.R:NextNumber() - 0.5) * 0.05, V.R:NextNumber())
				f.Size = UDim2.new(1, 0, 0, Ri(1, 5))
				f.BackgroundTransparency = Rf(0.4, 0.8)
			end
		end
	end)
	table.insert(V.Conns, conn)
end

-- ======================================================================
-- RANSOM NOTE (fixed countdown that only COUNTS UP toward "repaired")
-- ======================================================================
local FAKE_BTC = "1FAKE-DO-NOT-SEND-MONEY-abcXYZ999"

local function ShowNote()
	StartGlitch()
	local layer = Layer("Note", 15)
	local root = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BorderSizePixel = 0, Active = true, ZIndex = 15, Parent = layer})
	local title = New("TextLabel", {
		Size = UDim2.new(1, -40, 0, 44), Position = UDim2.fromOffset(20, 24), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 26, TextColor3 = WHITE,
		Text = "Ooops, your important files are encrypted.", TextWrapped = true, ZIndex = 16, Parent = root,
	})
	local sub = New("TextLabel", {
		Size = UDim2.new(1, -40, 0, 150), Position = UDim2.fromOffset(20, 76), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 13, TextColor3 = WHITE,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 16, Parent = root,
		Text = Tr(
			"これはジョークです。実際のファイルは何も暗号化されていません。\n\n"..
			"もし心配なら、何も送金する必要はありません。この画面は見た目を真似ているだけです。\n\n"..
			"送金先として表示されているアドレスは偽物です。",
			"This is a joke. No real files have been encrypted.\n\n"..
			"Don't worry, you don't need to send anything. This screen is only a visual parody.\n\n"..
			"The address shown below is fake."
		),
	})
	local btcBox = New("Frame", {Size = UDim2.new(1, -40, 0, 56), Position = UDim2.fromOffset(20, 234), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 16, Parent = root})
	New("TextLabel", {Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 4), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 12, TextColor3 = Color3.fromRGB(255, 180, 180), TextXAlignment = Enum.TextXAlignment.Left, Text = "Bitcoin wallet:  [" .. Tr("偽物 / これは送金先ではありません", "FAKE - do not send money here") .. "]", ZIndex = 17, Parent = btcBox})
	New("TextLabel", {Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 24), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 15, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = FAKE_BTC, ZIndex = 17, Parent = btcBox})

	local timerLbl = New("TextLabel", {
		Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 302), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 14, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16, Parent = root,
	})

	local inputBox = New("TextBox", {
		Size = UDim2.new(1, -40, 0, 36), Position = UDim2.fromOffset(20, 336), BackgroundColor3 = BLACK, Text = "", PlaceholderText = Tr("復号キーを入力...", "Enter decryption key..."),
		PlaceholderColor3 = Color3.fromRGB(200, 150, 150), TextColor3 = WHITE, Font = Enum.Font.Code, TextSize = 14, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16, Parent = root,
	})
	New("UIPadding", {PaddingLeft = UDim.new(0, 8), Parent = inputBox})
	local decryptBtn = New("TextButton", {
		Size = UDim2.new(1, -40, 0, 42), Position = UDim2.fromOffset(20, 382), BackgroundColor3 = BLACK, Text = Tr("復号する (DECRYPT)", "DECRYPT"), Font = Enum.Font.Code, TextSize = 16, TextColor3 = WHITE,
		AutoButtonColor = false, ZIndex = 16, Parent = root,
	})
	New("UIStroke", {Thickness = 2, Color = WHITE, Parent = decryptBtn})

	local footer = New("TextLabel", {
		Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 20, 1, -30), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 11, TextColor3 = Color3.fromRGB(255, 210, 210),
		Text = Tr("※ これはジョークです。何も壊れていません。STOPでいつでも終了できます。", "This is a joke. Nothing is broken. Press STOP any time to end it."), ZIndex = 16, Parent = root,
	})

	local gen = Gen
	local t0 = tick()
	local dur = 20
	task.spawn(function()
		while gen == Gen and root.Parent do
			local left = math.max(0, dur - (tick() - t0))
			local m = math.floor(left / 60)
			local s2 = math.floor(left % 60)
			timerLbl.Text = Tr("復元まで: ", "Repair ETA: ") .. string.format("%02d:%02d", m, s2) .. Tr(" (支払いは不要です)", " (no payment required)")
			local pulse = 0.85 + 0.15 * math.sin(tick() * 2)
			root.BackgroundColor3 = RED:Lerp(Color3.fromRGB(120, 0, 0), 1 - pulse)
			if left <= 0 then break end
			task.wait(0.2)
		end
	end)

	local function finish()
		if gen ~= Gen then return end
		Beep(1.3, 0.3)
		DropLayer("Note")
		ShowChkdsk(function()
			local done = Layer("Done", 15)
			local bg = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 60, 20), BorderSizePixel = 0, ZIndex = 15, Parent = done})
			New("TextLabel", {
				Size = UDim2.new(1, -40, 0, 120), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1,
				Font = Enum.Font.Code, TextSize = 20, TextColor3 = WHITE, TextWrapped = true,
				Text = Tr("修復完了!\nファイルは最初から何も壊れていませんでした。\nこれはジョークでした。おつかれさま。", "Repair complete!\nYour files were never actually touched.\nThat was just a joke. Thanks for playing along."), ZIndex = 16, Parent = bg,
			})
			Notify("NotPetya Joke", Tr("終了しました", "Finished"), 3)
			task.delay(5, function()
				if Gen == gen then DropLayer("Done") StopAll() end
			end)
		end)
	end
	Connect(decryptBtn.Activated, finish)
	task.delay(dur + 0.5, finish)
end

-- ======================================================================
-- START sequence
-- ======================================================================
local function StartSequence()
	if V.Running then return end
	V.Running = true
	ShowSkull(function()
		ShowChkdsk(function()
			ShowNote()
		end)
	end)
end

-- ======================================================================
-- CONTROL PANEL (small window)
-- ======================================================================
local Holder = New("Frame", {Size = UDim2.fromOffset(300, 190), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = CGui})
local Window = New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 8, 8), BackgroundTransparency = 0.05, ClipsDescendants = true, Parent = Holder})
Corner(Window, 14)
local WS = New("UIScale", {Scale = 0.01, Parent = Window})
New("UIStroke", {Thickness = 2, Color = RED, Parent = Window})
local top = New("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(16, 10, 10), BorderSizePixel = 0, Parent = Window})
New("TextLabel", {Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Text = "NOT-PETYA JOKE", Font = Enum.Font.Code, TextSize = 15, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left, Parent = top})
local minB = New("TextButton", {Size = UDim2.fromOffset(28, 26), Position = UDim2.new(1, -36, 0.5, -13), BackgroundColor3 = Color3.fromRGB(28, 20, 20), Text = "-", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = WHITE, AutoButtonColor = false, Parent = top})
Corner(minB, 8)
Draggable(top, Holder, nil)

local startBtn = New("TextButton", {Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 48), BackgroundColor3 = RED, Text = Tr("▶ ジョークを開始", "▶ Start the joke"), Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = WHITE, AutoButtonColor = false, Parent = Window})
Corner(startBtn, 10)
Connect(startBtn.Activated, function() Guarded(StartSequence) end)

local langBtn = New("TextButton", {Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 96), BackgroundColor3 = Color3.fromRGB(28, 20, 20), Text = "English", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE, AutoButtonColor = false, Parent = Window})
Corner(langBtn, 9)
Connect(langBtn.Activated, function()
	V.Lang = (V.Lang == "ja") and "en" or "ja"
	langBtn.Text = (V.Lang == "ja") and "English" or "日本語"
	Notify("NotPetya Joke", Tr("日本語に切り替えました", "Switched to English"), 2)
end)

New("TextLabel", {Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 138), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = Color3.fromRGB(200, 170, 170), TextWrapped = true, Text = Tr("見た目だけのジョークです。ファイルは一切触りません。", "Looks-only joke. No files are ever touched."), Parent = Window})

local open, busy = false, false
local function SetOpen(state)
	if busy or open == state then return end
	busy, open = true, state
	if state then
		Holder.Visible = true
		WS.Scale = 0.01
		T(WS, 0.35, {Scale = 1}, Enum.EasingStyle.Back)
		task.delay(0.35, function() busy = false end)
	else
		T(WS, 0.22, {Scale = 0.01}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.25, function() Holder.Visible = false busy = false end)
	end
end
Connect(minB.Activated, function() SetOpen(false) end)
Draggable(pill, pill, function() SetOpen(not open) end)

SetOpen(true)

-- ======================================================================
-- UNLOAD
-- ======================================================================
local function Unload()
	Gen = Gen + 1
	for _, c in ipairs(V.Conns) do pcall(function() c:Disconnect() end) end
	V.Conns = {}
	pcall(function() Gui:Destroy() end)
	pcall(function() CGui:Destroy() end)
	getgenv().NotPetyaJoke = nil
end
getgenv().NotPetyaJoke = {Unload = Unload, Start = function() Guarded(StartSequence) end, Stop = StopAll}
Notify("NotPetya Joke", Tr("読み込み完了 (見た目だけのジョーク)", "Loaded (looks-only joke)"), 4)
