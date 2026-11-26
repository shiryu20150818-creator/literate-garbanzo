
------------------------------------------------------------------
-- 窓の種類 (それぞれ build(win, body, sc) が毎フレームの更新関数を返す)
------------------------------------------------------------------
-- 共通: 1文字ずつ打つ文字列表示 (メモ帳 / コマンドプロンプト用)
local function Typewriter(label, pool, maxLines, speed, prefix, cursor)
	local lines, cur, pos, acc = {}, nil, 0, 0
	local function nextLine()
		cur = IA.Pick(pool)
		pos = 0
	end
	nextLine()
	return function(dt)
		acc += dt * speed
		while acc >= 1 do
			acc -= 1
			pos += 1
			if pos > #cur then
				table.insert(lines, (prefix or "") .. cur)
				if #lines > maxLines then table.remove(lines, 1) end
				nextLine()
			end
		end
		local shown = table.concat(lines, "\n")
		local typing = (prefix or "") .. string.sub(cur, 1, pos)
		label.Text = shown .. (#lines > 0 and "\n" or "") .. typing .. ((math.floor(IA.t * 2) % 2 == 0) and (cursor or "█") or "")
	end
end

local SAYINGS = {
	"YOU ARE AN IDIOT!", "You are an idiot.", "Are you still reading this?", "HA HA HA HA HA HA", "Congratulations! You are an idiot.",
	"Why did you click that?", "No, really. You are an idiot.", "あなたはバカです", "クリックしましたね？", "これはジョークです (危害なし)",
}

-- ① 本家: 踊る笑顔の窓
IA.RegisterType("idiot", {
	title = "YOU ARE AN IDIOT!", w = 290, h = 222, bounce = true, bg = C.black, weight = 6, iconColor = C.face,
	build = function(win, body, sc)
		local fs = math.floor(72 * sc)
		local face = IA.Circle(body, fs, UDim2.fromScale(0.5, 0.33), C.face, {})
		New("UIStroke", {Color = C.black, Thickness = 2}, face)
		for _, sx in ipairs({-1, 1}) do   -- 踊る腕
			local arm = New("Frame", {
				AnchorPoint = Vector2.new(sx < 0 and 1 or 0, 0.5), Position = UDim2.fromScale(sx < 0 and 0.02 or 0.98, 0.62),
				Size = UDim2.fromOffset(fs * 0.5, fs * 0.13), BackgroundColor3 = C.face, BorderSizePixel = 0, Rotation = 0,
			}, face)
			New("UICorner", {CornerRadius = UDim.new(1, 0)}, arm)
		end
		for _, ex in ipairs({0.3, 0.7}) do
			IA.Circle(face, fs * 0.13, UDim2.fromScale(ex, 0.38), C.black, {})
		end
		local mouth = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.6, 0.26),
			BackgroundColor3 = C.black, BorderSizePixel = 0,
		}, face)
		New("UICorner", {CornerRadius = UDim.new(0.5, 0)}, mouth)
		local tongue = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.5, 0.55),
			BackgroundColor3 = Color3.fromRGB(230, 60, 60), BorderSizePixel = 0,
		}, mouth)
		New("UICorner", {CornerRadius = UDim.new(1, 0)}, tongue)
		local text = IA.Label(body, "YOU ARE AN IDIOT!", {
			Position = UDim2.fromScale(0, 0.58), Size = UDim2.fromScale(1, 0.24), TextColor3 = C.red, Font = Enum.Font.GothamBlack,
			TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		})
		local ticker = IA.Label(body, "", {
			Position = UDim2.fromScale(0, 0.84), Size = UDim2.fromScale(1, 0.15), TextColor3 = C.white, Font = Enum.Font.Code,
			TextSize = math.floor(13 * sc),
		})
		local counter = IA.Label(body, "IDIOT #" .. win.id, {
			Size = UDim2.fromScale(0.5, 0.1), Position = UDim2.fromOffset(4, 2), TextColor3 = C.yellow, Font = Enum.Font.Code,
			TextSize = math.floor(12 * sc),
		})
		local ph, tc, shift = IA.R(0, 6.28), 0, 0
		return function(dt, t)
			face.Rotation = math.sin(t * 9 + ph) * 20
			face.Position = UDim2.fromScale(0.5, 0.33 + math.sin(t * 12 + ph) * 0.04)
			for i, c in ipairs(face:GetChildren()) do
				if c:IsA("Frame") and c.Size.X.Offset > fs * 0.4 then c.Rotation = math.sin(t * 14 + ph + i) * 35 end
			end
			tc += dt
			if tc > 0.1 then
				tc = 0
				text.TextColor3 = IA.Pick(IA.PALETTE)
				shift = (shift + 1) % 12
				ticker.Text = string.rep("HA ", 12 - shift) .. string.rep("ha ", shift)
				counter.Text = "IDIOT #" .. win.id .. "  LV" .. IA.level
			end
			if IA.beatFlag then body.BackgroundColor3 = IA.Pick({C.black, Color3.fromRGB(70, 0, 0), Color3.fromRGB(0, 0, 70), C.black}) end
		end
	end,
})

-- ② エラーダイアログ (ボタンを押すとさらに増える)
local ERR_TITLES = {"Error", "Warning", "System Error", "Idiot.exe", "Windows", "Fatal Error", "Microsoft Idiot"}
local ERR_MSGS = {
	"You are an idiot!", "Idiot.exe has performed an illegal operation and will be shut down.",
	"A fatal exception 0E has occurred at 0028:C0011E36 in VXD VMM(01).", "Your computer is infected with the IDIOT virus.",
	"Are you sure you are not an idiot?", "ユーザーは idiot です。続行できません。", "Not enough memory to be smart.",
	"Cannot find intelligence.dll", "Windows has detected that you are an idiot.", "Click OK to continue being an idiot.",
}
IA.RegisterType("error", {
	title = "Error", w = 330, h = 132, bg = C.gray, weight = 4, iconColor = C.red, resizable = false, noMax = true, noMin = true,
	build = function(win, body, sc)
		win.SetTitle(IA.Pick(ERR_TITLES))
		local kind = IA.RI(1, 3)
		local icol = (kind == 1) and C.red or ((kind == 2) and C.yellow or C.blue)
		local sym = (kind == 1) and "X" or ((kind == 2) and "!" or "i")
		local ic = IA.Circle(body, math.floor(38 * sc), UDim2.fromOffset(math.floor(34 * sc), math.floor(34 * sc)), icol, {})
		IA.Label(ic, sym, {TextColor3 = (kind == 2) and C.black or C.white, Font = Enum.Font.ArialBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1)})
		IA.Label(body, IA.Pick(ERR_MSGS), {
			Position = UDim2.fromOffset(math.floor(66 * sc), 8), Size = UDim2.new(1, -math.floor(76 * sc), 0, math.floor(54 * sc)),
			TextWrapped = true, TextSize = math.floor(14 * sc), TextYAlignment = Enum.TextYAlignment.Top,
		})
		local sets = {{"OK"}, {"Yes", "No"}, {"Abort", "Retry", "Ignore"}, {"OK", "Cancel"}}
		local set = IA.Pick(sets)
		local bwid = math.floor(74 * sc)
		local total = #set * bwid + (#set - 1) * 8
		for i, label in ipairs(set) do
			IA.Button(body, label, {
				AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, -total / 2 + (i - 1) * (bwid + 8), 1, -8),
				Size = UDim2.fromOffset(bwid, math.floor(26 * sc)), TextSize = math.floor(14 * sc),
			}, function()
				if label == "OK" or label == "Yes" or label == "Abort" then
					win.Close(true)
				else
					win.Shake(10)     -- 「No」「Cancel」は閉じられない
					IA.Spawn("error")
				end
			end)
		end
		local f = 0
		return function(dt, t)
			if IA.beatFlag and IA.Chance(0.3) then win.Shake(5) end
		end
	end,
})

-- ③ ブラウザ
IA.RegisterType("ie", {
	title = "Microsoft Internet Explorer", w = 360, h = 270, bg = C.white, weight = 1.5, iconColor = C.blue,
	build = function(win, body, sc)
		body.BackgroundColor3 = C.gray
		local tb = New("Frame", {Size = UDim2.new(1, 0, 0, math.floor(30 * sc)), BackgroundColor3 = C.gray, BorderSizePixel = 0}, body)
		local names = {"Back", "Forward", "Stop", "Refresh", "Home"}
		for i, n in ipairs(names) do
			IA.Button(tb, n, {Position = UDim2.fromOffset(4 + (i - 1) * math.floor(54 * sc), 3), Size = UDim2.fromOffset(math.floor(52 * sc), math.floor(24 * sc)), TextSize = math.floor(12 * sc)},
				function() win.Shake(4); IA.Spawn() end)
		end
		local addr = New("Frame", {Position = UDim2.fromOffset(4, math.floor(32 * sc)), Size = UDim2.new(1, -8, 0, math.floor(22 * sc)), BackgroundColor3 = C.white, BorderSizePixel = 0}, body)
		IA.Bevel(addr, true)
		IA.Label(addr, "http://www.youareanidiot.org/", {Position = UDim2.fromOffset(6, 0), TextSize = math.floor(13 * sc)})
		local page = New("Frame", {Position = UDim2.fromOffset(4, math.floor(58 * sc)), Size = UDim2.new(1, -8, 1, -math.floor(84 * sc)), BackgroundColor3 = C.white, BorderSizePixel = 0, ClipsDescendants = true}, body)
		IA.Bevel(page, true)
		local head = IA.Label(page, "WELCOME, IDIOT!", {Size = UDim2.fromScale(1, 0.28), Position = UDim2.fromScale(0, 0.04), Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center})
		local mq = IA.Label(page, "*** YOU ARE AN IDIOT *** YOU ARE AN IDIOT *** YOU ARE AN IDIOT ***", {Size = UDim2.fromScale(2, 0.12), Position = UDim2.fromScale(0, 0.36), TextColor3 = C.blue, Font = Enum.Font.Code, TextSize = math.floor(14 * sc)})
		local visit = IA.Label(page, "You are visitor number 000001", {Size = UDim2.fromScale(1, 0.12), Position = UDim2.fromScale(0, 0.52), TextSize = math.floor(13 * sc), TextXAlignment = Enum.TextXAlignment.Center})
		local link = IA.Label(page, "Click HERE to win a FREE iPod!!!", {Size = UDim2.fromScale(1, 0.14), Position = UDim2.fromScale(0, 0.68), TextColor3 = C.blue, TextSize = math.floor(15 * sc), TextXAlignment = Enum.TextXAlignment.Center})
		local btn = New("TextButton", {Size = UDim2.fromScale(1, 0.14), Position = UDim2.fromScale(0, 0.68), BackgroundTransparency = 1, Text = ""}, page)
		btn.Activated:Connect(function() IA.Spawn(); IA.Spawn() end)
		local sbar = IA.Label(body, "Opening page http://www.youareanidiot.org/...", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -3), Size = UDim2.new(0.62, 0, 0, math.floor(18 * sc)), TextSize = math.floor(12 * sc)})
		local pbarBg = New("Frame", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -4), Size = UDim2.new(0.3, 0, 0, math.floor(14 * sc)), BackgroundColor3 = C.white, BorderSizePixel = 0}, body)
		IA.Bevel(pbarBg, true)
		local pbar = New("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.navy, BorderSizePixel = 0}, pbarBg)
		local n = IA.RI(1, 999999)
		return function(dt, t)
			head.TextColor3 = IA.Rainbow(t * 0.8)
			mq.Position = UDim2.fromScale(-((t * 0.25) % 1), 0.36)
			n += IA.RI(0, 9)
			if IA.beatFlag then visit.Text = string.format("You are visitor number %06d", n) end
			pbar.Size = UDim2.fromScale((t * 0.35) % 1, 1)
			link.TextColor3 = (math.floor(t * 3) % 2 == 0) and C.blue or C.red
		end
	end,
})

-- ④ メモ帳
IA.RegisterType("notepad", {
	title = "Untitled - Notepad", w = 300, h = 230, bg = C.white, weight = 1, iconColor = C.white,
	build = function(win, body, sc)
		local menu = New("Frame", {Size = UDim2.new(1, 0, 0, math.floor(20 * sc)), BackgroundColor3 = C.gray, BorderSizePixel = 0}, body)
		for i, n in ipairs({"File", "Edit", "Search", "Help"}) do
			IA.Label(menu, n, {Position = UDim2.fromOffset(6 + (i - 1) * math.floor(48 * sc), 0), Size = UDim2.fromOffset(math.floor(44 * sc), math.floor(20 * sc)), TextSize = math.floor(13 * sc)})
		end
		local txt = IA.Label(body, "", {Position = UDim2.fromOffset(4, math.floor(22 * sc)), Size = UDim2.new(1, -8, 1, -math.floor(24 * sc)), Font = Enum.Font.Code, TextSize = math.floor(14 * sc), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
		return Typewriter(txt, SAYINGS, 9, 22, "", "_")
	end,
})

-- ⑤ コマンドプロンプト
local CMD_POOL = {
	"C:\\WINDOWS>idiot.exe", "Loading IDIOT.SYS ...", "Access denied: you are an idiot", "scanning drive C: ... 100%",
	"format c: /idiot", "ERROR: user is an idiot", "C:\\WINDOWS>dir /idiot", "Volume in drive C is IDIOT", "     1 file(s)  YOU_ARE_AN_IDIOT.TXT",
	"C:\\>echo YOU ARE AN IDIOT", "YOU ARE AN IDIOT", "Bad command or file name (you)", "[##########----------] 50%", "[####################] 100%",
}
IA.RegisterType("cmd", {
	title = "MS-DOS Prompt", w = 330, h = 210, bg = C.black, weight = 1, iconColor = C.black,
	build = function(win, body, sc)
		local txt = IA.Label(body, "", {Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 1, -8), TextColor3 = C.gray, Font = Enum.Font.Code, TextSize = math.floor(14 * sc), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
		return Typewriter(txt, CMD_POOL, 9, 28, "", "█")
	end,
})

-- ⑥ ペイント
IA.RegisterType("paint", {
	title = "untitled - Paint", w = 330, h = 250, bg = C.gray, weight = 1, iconColor = C.red,
	build = function(win, body, sc)
		local tools = New("Frame", {Size = UDim2.new(0, math.floor(44 * sc), 1, -math.floor(30 * sc)), BackgroundTransparency = 1}, body)
		for i = 0, 11 do
			local b = New("Frame", {Position = UDim2.fromOffset(2 + (i % 2) * math.floor(20 * sc), 2 + math.floor(i / 2) * math.floor(20 * sc)), Size = UDim2.fromOffset(math.floor(19 * sc), math.floor(19 * sc)), BackgroundColor3 = C.gray, BorderSizePixel = 0}, tools)
			IA.Bevel(b, i == 4)
		end
		local canvas = New("Frame", {Position = UDim2.new(0, math.floor(46 * sc), 0, 2), Size = UDim2.new(1, -math.floor(50 * sc), 1, -math.floor(32 * sc)), BackgroundColor3 = C.white, BorderSizePixel = 0, ClipsDescendants = true}, body)
		IA.Bevel(canvas, true)
		local pal = New("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, math.floor(46 * sc), 1, -2), Size = UDim2.new(1, -math.floor(50 * sc), 0, math.floor(24 * sc)), BackgroundTransparency = 1}, body)
		local sw = {}
		for i, col in ipairs(IA.PAINT16) do
			local s = New("Frame", {Position = UDim2.fromOffset(((i - 1) % 8) * math.floor(14 * sc), math.floor(((i - 1) // 8) * 11 * sc)), Size = UDim2.fromOffset(math.floor(13 * sc), math.floor(10 * sc)), BackgroundColor3 = col, BorderSizePixel = 0}, pal)
			sw[i] = s
		end
		local shapes, acc = {}, 0
		return function(dt, t)
			acc += dt
			if acc > 0.18 then
				acc = 0
				local col = IA.Pick(IA.PAINT16)
				local f = New("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(IA.R(0.05, 0.95), IA.R(0.05, 0.95)),
					Size = UDim2.fromOffset(IA.R(8, 90) * sc, IA.R(2, 6) * sc), BackgroundColor3 = col, BorderSizePixel = 0, Rotation = IA.R(0, 180),
				}, canvas)
				if IA.Chance(0.25) then New("UICorner", {CornerRadius = UDim.new(1, 0)}, f); f.Size = UDim2.fromOffset(IA.R(12, 40) * sc, IA.R(12, 40) * sc) end
				table.insert(shapes, f)
				if #shapes > 34 then table.remove(shapes, 1):Destroy() end
				for i, s in ipairs(sw) do s.BorderSizePixel = (i == IA.RI(1, 16)) and 1 or 0 end
			end
		end
	end,
})

-- ⑦ メディアプレイヤー
IA.RegisterType("media", {
	title = "Idiot Player - theme.wav", w = 320, h = 180, bg = C.black, weight = 1, iconColor = C.green,
	build = function(win, body, sc)
		local n = 20
		local bars = {}
		local vis = New("Frame", {Size = UDim2.new(1, -12, 0.58, 0), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(5, 10, 5), BorderSizePixel = 0}, body)
		for i = 1, n do
			bars[i] = New("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((i - 1) / n, 1, 1, 0), Size = UDim2.new(1 / n, -2, 0.3, 0), BackgroundColor3 = C.green, BorderSizePixel = 0}, vis)
		end
		local timeLbl = IA.Label(body, "00:00 / 03:12", {Position = UDim2.new(0, 8, 0.62, 0), Size = UDim2.new(0.5, 0, 0.14, 0), TextColor3 = C.green, Font = Enum.Font.Code, TextSize = math.floor(14 * sc)})
		IA.Label(body, "YOU ARE AN IDIOT (loop)", {Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.new(0.5, -6, 0.14, 0), TextColor3 = C.yellow, Font = Enum.Font.Code, TextSize = math.floor(12 * sc), TextXAlignment = Enum.TextXAlignment.Right})
		local seekBg = New("Frame", {Position = UDim2.new(0, 8, 0.78, 0), Size = UDim2.new(1, -16, 0, math.floor(8 * sc)), BackgroundColor3 = C.darker, BorderSizePixel = 0}, body)
		local seek = New("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green, BorderSizePixel = 0}, seekBg)
		for i, s in ipairs({"|<", ">", "[]", ">|"}) do
			IA.Button(body, s, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8 + (i - 1) * math.floor(34 * sc), 1, -4), Size = UDim2.fromOffset(math.floor(32 * sc), math.floor(20 * sc)), TextSize = math.floor(12 * sc)}, function() win.Shake(3) end)
		end
		return function(dt, t)
			for i, b in ipairs(bars) do
				local h = 0.18 + 0.8 * math.abs(math.sin(t * 5 + i * 0.7)) * (0.5 + 0.5 * math.sin(t * 2.3 + i))
				if IA.beatFlag then h = math.min(h + 0.25, 1) end
				b.Size = UDim2.new(1 / n, -2, h, 0)
				b.BackgroundColor3 = Color3.fromHSV(0.33 - h * 0.33, 1, 1)
			end
			local p = (t * 0.05) % 1
			seek.Size = UDim2.fromScale(p, 1)
			timeLbl.Text = string.format("%02d:%02d / 03:12", (p * 192) // 60, (p * 192) % 60)
		end
	end,
})

-- ⑧ ウイルススキャン
local SCAN_FILES = {"C:\\WINDOWS\\SYSTEM\\IDIOT.DLL", "C:\\WINDOWS\\WIN.INI", "C:\\MY DOCUMENTS\\HOMEWORK.DOC", "C:\\PROGRAM FILES\\SMART\\BRAIN.EXE", "C:\\AUTOEXEC.BAT", "C:\\IO.SYS", "C:\\COMMAND.COM", "C:\\IDIOT\\YOU.TXT"}
IA.RegisterType("scan", {
	title = "Virus Scanner", w = 320, h = 160, bg = C.gray, weight = 1, iconColor = C.green,
	build = function(win, body, sc)
		local cur = IA.Label(body, "", {Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, math.floor(20 * sc)), TextSize = math.floor(12 * sc), TextTruncate = Enum.TextTruncate.AtEnd})
		local bg = New("Frame", {Position = UDim2.new(0, 8, 0, math.floor(34 * sc)), Size = UDim2.new(1, -16, 0, math.floor(22 * sc)), BackgroundColor3 = C.white, BorderSizePixel = 0}, body)
		IA.Bevel(bg, true)
		local blocks = {}
		for i = 1, 22 do
			blocks[i] = New("Frame", {Position = UDim2.new((i - 1) / 22, 2, 0, 2), Size = UDim2.new(1 / 22, -2, 1, -4), BackgroundColor3 = C.navy, BorderSizePixel = 0, Visible = false}, bg)
		end
		local found = IA.Label(body, "Idiots found: 0", {Position = UDim2.new(0, 8, 0, math.floor(66 * sc)), Size = UDim2.new(1, -16, 0, math.floor(22 * sc)), TextColor3 = C.red, Font = Enum.Font.ArialBold, TextSize = math.floor(16 * sc)})
		IA.Button(body, "Cancel", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(math.floor(80 * sc), math.floor(26 * sc))}, function() win.Shake(8); IA.Spawn("error") end)
		local prog, n, acc = 0, 0, 0
		return function(dt, t)
			prog += dt * 0.22
			if prog >= 1.2 then prog = 0; n = n + 999 end
			acc += dt
			if acc > 0.12 then acc = 0; cur.Text = "Scanning " .. IA.Pick(SCAN_FILES); n += IA.RI(1, 7) end
			for i, b in ipairs(blocks) do b.Visible = i / 22 <= math.min(prog, 1) end
			found.Text = "Idiots found: " .. n
		end
	end,
})

-- ⑨ タスクマネージャ
IA.RegisterType("taskman", {
	title = "Task Manager", w = 300, h = 220, bg = C.gray, weight = 0.8, iconColor = C.blue,
	build = function(win, body, sc)
		local procs = {{"idiot.exe", 99}, {"explorer.exe", 4}, {"iexplore.exe", 17}, {"brain.exe", 0}, {"IDIOT_SVC.exe", 88}, {"notepad.exe", 2}, {"System", 1}}
		local list = New("Frame", {Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -math.floor(36 * sc)), BackgroundColor3 = C.white, BorderSizePixel = 0, ClipsDescendants = true}, body)
		IA.Bevel(list, true)
		IA.Label(list, "Image Name                 CPU    Mem", {Size = UDim2.new(1, 0, 0, math.floor(18 * sc)), Position = UDim2.fromOffset(4, 0), Font = Enum.Font.Code, TextSize = math.floor(12 * sc), BackgroundTransparency = 0, BackgroundColor3 = C.gray})
		local rows = {}
		for i = 1, #procs do
			rows[i] = IA.Label(list, "", {Position = UDim2.fromOffset(4, math.floor((i + 0.1) * 19 * sc)), Size = UDim2.new(1, 0, 0, math.floor(18 * sc)), Font = Enum.Font.Code, TextSize = math.floor(12 * sc)})
		end
		IA.Button(body, "End Task", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(math.floor(80 * sc), math.floor(24 * sc))}, function() IA.Spawn("idiot"); IA.Spawn("error") end)
		local acc = 0
		return function(dt, t)
			acc += dt
			if acc > 0.4 then
				acc = 0
				for i, p in ipairs(procs) do
					local cpu = (p[2] > 50) and IA.RI(p[2], 100) or math.max(0, p[2] + IA.RI(-2, 3))
					rows[i].Text = string.format("%-24s %3d%%  %5dK", p[1], cpu, IA.RI(2000, 9000) + i * 100)
					rows[i].TextColor3 = (p[2] > 50) and C.red or C.black
				end
			end
		end
	end,
})

-- ⑩ 電卓
IA.RegisterType("calc", {
	title = "Calculator", w = 200, h = 250, bg = C.gray, weight = 0.8, iconColor = C.gray, resizable = false, noMax = true,
	build = function(win, body, sc)
		local disp = New("Frame", {Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, math.floor(34 * sc)), BackgroundColor3 = C.white, BorderSizePixel = 0}, body)
		IA.Bevel(disp, true)
		local out = IA.Label(disp, "1+1=", {Size = UDim2.new(1, -6, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.Code, TextSize = math.floor(18 * sc)})
		local keys = {"7", "8", "9", "/", "4", "5", "6", "*", "1", "2", "3", "-", "0", ".", "=", "+"}
		for i, k in ipairs(keys) do
			local cx, cy = (i - 1) % 4, (i - 1) // 4
			IA.Button(body, k, {Position = UDim2.new(0, 6 + cx * math.floor(44 * sc), 0, math.floor(48 * sc) + cy * math.floor(40 * sc)), Size = UDim2.fromOffset(math.floor(40 * sc), math.floor(34 * sc)), TextSize = math.floor(15 * sc)}, function()
				out.Text = IA.Pick({"IDIOT", "1+1=3", "NaN", "YOU", "0xBAD", "idiot"})
				if IA.Chance(0.4) then IA.Spawn() end
			end)
		end
		local acc = 0
		return function(dt)
			acc += dt
			if acc > 0.7 then acc = 0; out.Text = IA.Pick({"1+1=", "IDIOT", "2+2=5", "I DIOT"}) end
		end
	end,
})

-- ⑪ ソリティアの勝利演出 (カードの残像)
IA.RegisterType("cards", {
	title = "Solitaire", w = 340, h = 240, bg = Color3.fromRGB(0, 128, 0), weight = 1, iconColor = C.red, bounce = false,
	build = function(win, body, sc)
		local cards = {}
		local suits = {"♠", "♥", "♦", "♣"}
		local cw, ch = math.floor(40 * sc), math.floor(56 * sc)
		local live, acc, spawnAcc = {}, 0, 0
		local function newCard()
			local f = New("Frame", {Size = UDim2.fromOffset(cw, ch), Position = UDim2.fromScale(IA.R(0.1, 0.8), 0.2), BackgroundColor3 = C.white, BorderSizePixel = 0}, body)
			New("UIStroke", {Color = C.black, Thickness = 1}, f)
			local s = IA.Pick(suits)
			IA.Label(f, s .. " A", {TextColor3 = (s == "♥" or s == "♦") and C.red or C.black, TextSize = math.floor(14 * sc), Font = Enum.Font.ArialBold, Position = UDim2.fromOffset(3, 1)})
			return {f = f, x = IA.R(20, 200), y = IA.R(0, 60), vx = IA.R(-90, 90), vy = IA.R(-20, 20), age = 0}
		end
		table.insert(live, newCard())
		return function(dt, t)
			spawnAcc += dt
			if spawnAcc > 0.9 and #live < 5 then spawnAcc = 0; table.insert(live, newCard()) end
			local bw, bh = body.AbsoluteSize.X, body.AbsoluteSize.Y
			for _, c in ipairs(live) do
				c.vy += 260 * dt
				c.x += c.vx * dt; c.y += c.vy * dt
				if c.y > bh - ch then c.y = bh - ch; c.vy = -c.vy * 0.82 end
				if c.x < 0 or c.x > bw - cw then c.vx = -c.vx; c.x = math.clamp(c.x, 0, bw - cw) end
				c.f.Position = UDim2.fromOffset(c.x, c.y)
				c.age += dt
				if c.age > 0.05 then   -- 残像
					c.age = 0
					local g = c.f:Clone()
					g.Parent = body
					table.insert(cards, g)
					if #cards > 70 then table.remove(cards, 1):Destroy() end
				end
			end
		end
	end,
})

-- ⑫ ブルースクリーン
IA.RegisterType("bsod", {
	title = "Windows", w = 330, h = 200, bg = Color3.fromRGB(0, 0, 170), weight = 0.6, iconColor = C.blue, noMax = false,
	build = function(win, body, sc)
		IA.Label(body, "Windows", {Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(math.floor(90 * sc), math.floor(20 * sc)), BackgroundTransparency = 0, BackgroundColor3 = C.gray, TextColor3 = Color3.fromRGB(0, 0, 170), Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Center})
		IA.Label(body, "A fatal exception 0E has occurred at\n0028:C0011E36 in VXD IDIOT(01).\n\nYOU ARE AN IDIOT.\n\n* Press any key to terminate the idiot.\n* Press CTRL+ALT+DEL to restart.", {
			Position = UDim2.fromOffset(10, math.floor(38 * sc)), Size = UDim2.new(1, -20, 1, -math.floor(60 * sc)), TextColor3 = C.white,
			Font = Enum.Font.Code, TextSize = math.floor(13 * sc), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		})
		local prompt = IA.Label(body, "Press any key to continue _", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -4), Size = UDim2.new(1, -20, 0, math.floor(18 * sc)), TextColor3 = C.white, Font = Enum.Font.Code, TextSize = math.floor(13 * sc)})
		local btn = New("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = ""}, body)
		btn.Activated:Connect(function() IA.Spawn("bsod"); IA.Spawn() end)
		return function(dt, t) prompt.Visible = math.floor(t * 2) % 2 == 0 end
	end,
})

-- ⑬ デフラグ
IA.RegisterType("defrag", {
	title = "Disk Defragmenter", w = 320, h = 210, bg = C.gray, weight = 0.8, iconColor = C.cyan,
	build = function(win, body, sc)
		local grid = New("Frame", {Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -math.floor(44 * sc)), BackgroundColor3 = C.white, BorderSizePixel = 0}, body)
		IA.Bevel(grid, true)
		local cols, rowsN = 24, 9
		local cells = {}
		for i = 0, cols * rowsN - 1 do
			cells[i + 1] = New("Frame", {Position = UDim2.new((i % cols) / cols, 1, (i // cols) / rowsN, 1), Size = UDim2.new(1 / cols, -2, 1 / rowsN, -2), BackgroundColor3 = C.blue, BorderSizePixel = 0}, grid)
		end
		local lbl = IA.Label(body, "Defragmenting... 0%", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -6), Size = UDim2.new(0.7, 0, 0, math.floor(20 * sc)), TextSize = math.floor(13 * sc)})
		local pos, acc = 1, 0
		return function(dt, t)
			acc += dt
			while acc > 0.03 do
				acc -= 0.03
				local c = cells[pos]
				if c then c.BackgroundColor3 = IA.Pick({C.green, C.blue, C.red, C.cyan}) end
				pos += 1
				if pos > #cells then
					pos = 1
					for _, x in ipairs(cells) do x.BackgroundColor3 = C.blue end
				end
			end
			lbl.Text = string.format("Defragmenting... %d%%   (idiot.dat is fragmented)", math.floor(pos / #cells * 100))
		end
	end,
})

-- ⑭ マインスイーパ (地雷はぜんぶ IDIOT)
IA.RegisterType("mine", {
	title = "Minesweeper", w = 240, h = 276, bg = C.gray, weight = 0.8, iconColor = C.red, resizable = false, noMax = true,
	build = function(win, body, sc)
		local face = IA.Circle(body, math.floor(28 * sc), UDim2.new(0.5, 0, 0, math.floor(20 * sc)), C.face, {})
		local cs = math.floor(20 * sc)
		local cells = {}
		for i = 0, 63 do
			local b = IA.Button(body, "", {Position = UDim2.fromOffset(8 + (i % 8) * cs, math.floor(44 * sc) + (i // 8) * cs), Size = UDim2.fromOffset(cs, cs), TextSize = math.floor(12 * sc)}, nil)
			cells[i + 1] = b
			b.Activated:Connect(function()
				b.Text = IA.Chance(0.5) and "💣" or tostring(IA.RI(1, 8))
				b.BackgroundColor3 = IA.Chance(0.3) and C.red or C.gray
				face.BackgroundColor3 = C.red
				win.Shake(5)
				if IA.Chance(0.5) then IA.Spawn() end
			end)
		end
		return function(dt, t)
			if IA.beatFlag then face.BackgroundColor3 = IA.Pick({C.face, C.red, C.yellow}) end
		end
	end,
})
