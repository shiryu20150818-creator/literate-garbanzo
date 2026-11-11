--[[
  MrsMajor 3.0 — VISUAL ONLY replica (Roblox ScreenGui)
  見た目専用。実害なし。ローカル演出のみ。
  Based on public descriptions of Elektro Berkay / Siam Alam FMV version.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local LP = Players.LocalPlayer

local BLOOD_SECONDS = 90 -- 血が減り切るまでの秒数（演出用）
local AUTH_CODE = "3158" -- 見た目用（何を入れても次に進める）

local function Notify(t, x, d)
	pcall(function()
		StarterGui:SetCore("SendNotification", {Title = t, Text = x, Duration = d or 3})
	end)
end

local function parent()
	local ok, g = pcall(function()
		if typeof(gethui) == "function" then return gethui() end
	end)
	if ok and g then return g end
	local ok2, c = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and c then return c end
	return LP:WaitForChild("PlayerGui")
end

pcall(function()
	local o = parent():FindFirstChild("MrsMajor3Visual")
	if o then o:Destroy() end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "MrsMajor3Visual"
sg.IgnoreGuiInset = true
sg.ResetOnSpawn = false
sg.DisplayOrder = 100000
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = parent()

local stage = 0
local bloodLeft = 100
local bloodConn = nil
local broken = false

-- ========== helpers ==========
local function clearStage()
	for _, c in ipairs(sg:GetChildren()) do
		c:Destroy()
	end
end

local function mkText(parent, props)
	local t = Instance.new("TextLabel")
	for k, v in pairs(props) do t[k] = v end
	t.Parent = parent
	return t
end

local function mkBtn(parent, props, cb)
	local b = Instance.new("TextButton")
	for k, v in pairs(props) do b[k] = v end
	b.Parent = parent
	if cb then b.MouseButton1Click:Connect(cb) end
	return b
end

local function mkFrame(parent, props)
	local f = Instance.new("Frame")
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end

-- ========== STAGE 0: Attention / infecting ==========
local function stageAttention()
	clearStage()
	stage = 0
	local bg = mkFrame(sg, {
		Size = UDim2.fromScale(1,1),
		BackgroundColor3 = Color3.fromRGB(10,10,12),
		BorderSizePixel = 0,
		ZIndex = 1,
	})
	local box = mkFrame(sg, {
		Size = UDim2.fromOffset(420, 220),
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5,0.5),
		BackgroundColor3 = Color3.fromRGB(32,32,36),
		ZIndex = 2,
	})
	Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
	local st = Instance.new("UIStroke", box)
	st.Color = Color3.fromRGB(160,30,30)
	st.Thickness = 2

	mkText(box, {
		Size = UDim2.new(1,-24,0,28),
		Position = UDim2.fromOffset(12,12),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(220,60,60),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Attention:",
		ZIndex = 3,
	})
	mkText(box, {
		Size = UDim2.new(1,-24,0,90),
		Position = UDim2.fromOffset(12,48),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(220,220,220),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "Be patient while MrsMajor infects your system.\nThis usually takes about 23 seconds.\nYour computer will be forced to restart afterwards.\n\nDo you want to view the screen of Rules?",
		ZIndex = 3,
	})

	local barBg = mkFrame(box, {
		Size = UDim2.new(1,-24,0,10),
		Position = UDim2.fromOffset(12,150),
		BackgroundColor3 = Color3.fromRGB(50,20,20),
		ZIndex = 3,
	})
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(1,0)
	local bar = mkFrame(barBg, {
		Size = UDim2.fromScale(0,1),
		BackgroundColor3 = Color3.fromRGB(180,30,30),
		ZIndex = 4,
	})
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

	local yes = mkBtn(box, {
		Size = UDim2.fromOffset(120,32),
		Position = UDim2.fromOffset(12,172),
		BackgroundColor3 = Color3.fromRGB(140,30,30),
		Text = "Yeah sure",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.new(1,1,1),
		ZIndex = 3,
	}, function()
		stageRules()
	end)
	Instance.new("UICorner", yes).CornerRadius = UDim.new(0,4)

	local no = mkBtn(box, {
		Size = UDim2.fromOffset(120,32),
		Position = UDim2.fromOffset(144,172),
		BackgroundColor3 = Color3.fromRGB(50,50,55),
		Text = "Skip rules",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.new(1,1,1),
		ZIndex = 3,
	}, function()
		stageAuth()
	end)
	Instance.new("UICorner", no).CornerRadius = UDim.new(0,4)

	-- fake 23s infect bar (sped up for demo ~2.5s)
	TweenService:Create(bar, TweenInfo.new(2.5, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1,1)
	}):Play()
end

-- ========== STAGE: Rules ==========
function stageRules()
	clearStage()
	stage = 1
	local bg = mkFrame(sg, {
		Size = UDim2.fromScale(1,1),
		BackgroundColor3 = Color3.fromRGB(8,8,10),
		ZIndex = 1,
	})
	local box = mkFrame(sg, {
		Size = UDim2.fromOffset(460, 360),
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5,0.5),
		BackgroundColor3 = Color3.fromRGB(28,28,32),
		ZIndex = 2,
	})
	Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
	local st = Instance.new("UIStroke", box)
	st.Color = Color3.fromRGB(140,20,20)
	st.Thickness = 2

	mkText(box, {
		Size = UDim2.new(1,-20,0,28),
		Position = UDim2.fromOffset(12,10),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255,80,80),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "MrsMajor 3.0 — RULES",
		ZIndex = 3,
	})

	local rules = [[
• Searching Google for "antivirus download",
  "malwarebytes download", "do i have a virus"
  is not allowed. You will get a blue screen.

• Using 3rd party tools is not allowed.
  You'll get a BSoD again.

• Once the malware runs out of blood,
  you'll get your LogonUI overwritten.

• If you fix your LogonUI, you'll get your
  boot sector overwritten just like System32.
  So don't do that ig.

• This program can't be ran on a real machine.
  (VM only)

Have fun!
Elektro Berkay / MoonCon - tobiaddr0c
]]
	mkText(box, {
		Size = UDim2.new(1,-24,0,260),
		Position = UDim2.fromOffset(12,44),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(210,210,210),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = rules,
		ZIndex = 3,
	})

	local go = mkBtn(box, {
		Size = UDim2.fromOffset(160,34),
		Position = UDim2.new(0.5,-80,1,-48),
		BackgroundColor3 = Color3.fromRGB(150,25,25),
		Text = "I understand",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.new(1,1,1),
		ZIndex = 3,
	}, function()
		stageAuth()
	end)
	Instance.new("UICorner", go).CornerRadius = UDim.new(0,4)
end

-- ========== STAGE: Auth code ==========
function stageAuth()
	clearStage()
	stage = 2
	local bg = mkFrame(sg, {
		Size = UDim2.fromScale(1,1),
		BackgroundColor3 = Color3.fromRGB(5,5,8),
		ZIndex = 1,
	})
	local box = mkFrame(sg, {
		Size = UDim2.fromOffset(380, 180),
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5,0.5),
		BackgroundColor3 = Color3.fromRGB(30,30,34),
		ZIndex = 2,
	})
	Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
	Instance.new("UIStroke", box).Color = Color3.fromRGB(120,20,20)

	mkText(box, {
		Size = UDim2.new(1,-20,0,24),
		Position = UDim2.fromOffset(12,14),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(220,220,220),
		Text = "Enter authorization code",
		ZIndex = 3,
	})
	mkText(box, {
		Size = UDim2.new(1,-20,0,36),
		Position = UDim2.fromOffset(12,42),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(160,160,170),
		TextWrapped = true,
		Text = "Decrypt and run the trojan payload.\n(Visual demo — any code works)",
		ZIndex = 3,
	})

	local boxIn = Instance.new("TextBox")
	boxIn.Size = UDim2.new(1,-24,0,32)
	boxIn.Position = UDim2.fromOffset(12,90)
	boxIn.BackgroundColor3 = Color3.fromRGB(20,20,24)
	boxIn.Text = ""
	boxIn.PlaceholderText = "Authorization code"
	boxIn.Font = Enum.Font.Code
	boxIn.TextSize = 14
	boxIn.TextColor3 = Color3.new(1,1,1)
	boxIn.ClearTextOnFocus = false
	boxIn.ZIndex = 3
	boxIn.Parent = box
	Instance.new("UICorner", boxIn).CornerRadius = UDim.new(0,4)

	local run = mkBtn(box, {
		Size = UDim2.fromOffset(120,32),
		Position = UDim2.fromOffset(12,132),
		BackgroundColor3 = Color3.fromRGB(140,25,25),
		Text = "Run",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.new(1,1,1),
		ZIndex = 3,
	}, function()
		stageMain()
	end)
	Instance.new("UICorner", run).CornerRadius = UDim.new(0,4)
end

-- ========== STAGE: Main blood overlay ==========
function stageMain()
	clearStage()
	stage = 3
	bloodLeft = 100
	broken = false

	-- dark forest-ish bg
	local bg = mkFrame(sg, {
		Size = UDim2.fromScale(1,1),
		BackgroundColor3 = Color3.fromRGB(8, 12, 10),
		ZIndex = 1,
	})
	-- vignette layers
	for i = 1, 4 do
		local v = mkFrame(sg, {
			Size = UDim2.fromScale(1,1),
			BackgroundColor3 = Color3.fromRGB(0,0,0),
			BackgroundTransparency = 0.85 - i * 0.08,
			ZIndex = 1,
		})
	end

	-- doll panel (silhouette representation)
	local doll = mkFrame(sg, {
		Size = UDim2.fromOffset(220, 280),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.38, 0, 0.48, 0),
		BackgroundColor3 = Color3.fromRGB(18, 10, 12),
		ZIndex = 5,
	})
	Instance.new("UICorner", doll).CornerRadius = UDim.new(0,8)
	local dStroke = Instance.new("UIStroke", doll)
	dStroke.Color = Color3.fromRGB(120, 20, 20)
	dStroke.Thickness = 2

	-- head
	local head = mkFrame(doll, {
		Size = UDim2.fromOffset(70, 70),
		Position = UDim2.fromOffset(75, 24),
		BackgroundColor3 = Color3.fromRGB(40, 30, 30),
		ZIndex = 6,
	})
	Instance.new("UICorner", head).CornerRadius = UDim.new(1,0)
	-- eyes (empty / bloody)
	for _, x in ipairs({18, 42}) do
		local eye = mkFrame(head, {
			Size = UDim2.fromOffset(14, 10),
			Position = UDim2.fromOffset(x, 28),
			BackgroundColor3 = Color3.fromRGB(10, 0, 0),
			ZIndex = 7,
		})
		Instance.new("UICorner", eye).CornerRadius = UDim.new(1,0)
		-- blood drip
		local drip = mkFrame(head, {
			Size = UDim2.fromOffset(4, 28),
			Position = UDim2.fromOffset(x + 5, 38),
			BackgroundColor3 = Color3.fromRGB(140, 10, 10),
			ZIndex = 7,
		})
	end
	-- forehead holes
	for i = 1, 3 do
		mkFrame(head, {
			Size = UDim2.fromOffset(6, 6),
			Position = UDim2.fromOffset(22 + i * 12, 10),
			BackgroundColor3 = Color3.fromRGB(60, 5, 5),
			ZIndex = 7,
		})
	end
	-- body
	local body = mkFrame(doll, {
		Size = UDim2.fromOffset(90, 110),
		Position = UDim2.fromOffset(65, 100),
		BackgroundColor3 = Color3.fromRGB(35, 25, 28),
		ZIndex = 6,
	})
	Instance.new("UICorner", body).CornerRadius = UDim.new(0,6)
	-- mouth blood
	mkFrame(head, {
		Size = UDim2.fromOffset(20, 8),
		Position = UDim2.fromOffset(25, 52),
		BackgroundColor3 = Color3.fromRGB(160, 15, 15),
		ZIndex = 7,
	})

	mkText(doll, {
		Size = UDim2.new(1,-10,0,36),
		Position = UDim2.fromOffset(5, 230),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(200, 60, 60),
		Text = "MrsMajor 3.0",
		ZIndex = 7,
	})

	-- Blood Left meter (vertical)
	local meterBg = mkFrame(sg, {
		Size = UDim2.fromOffset(36, 280),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.38, 130, 0.48, 0),
		BackgroundColor3 = Color3.fromRGB(25, 10, 10),
		ZIndex = 5,
	})
	Instance.new("UICorner", meterBg).CornerRadius = UDim.new(0,6)
	local meterFill = mkFrame(meterBg, {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(170, 15, 15),
		ZIndex = 6,
	})
	Instance.new("UICorner", meterFill).CornerRadius = UDim.new(0,6)

	local bloodLbl = mkText(sg, {
		Size = UDim2.fromOffset(120, 24),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.38, 175, 0.48, -150),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 80, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Blood Left: 100%",
		ZIndex = 8,
	})

	-- rules reminder strip
	local strip = mkFrame(sg, {
		Size = UDim2.new(0.9, 0, 0, 40),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		BackgroundColor3 = Color3.fromRGB(20, 8, 8),
		ZIndex = 8,
	})
	Instance.new("UICorner", strip).CornerRadius = UDim.new(0,6)
	mkText(strip, {
		Size = UDim2.fromScale(1,1),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(220, 180, 180),
		Text = "Don't search antivirus. Don't use recovery tools. Blood is draining...",
		ZIndex = 9,
	})

	-- break-rule buttons (visual triggers)
	local breakBtn = mkBtn(sg, {
		Size = UDim2.fromOffset(160, 34),
		Position = UDim2.new(1, -180, 0, 20),
		BackgroundColor3 = Color3.fromRGB(60, 20, 20),
		Text = "Open Task Manager",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 150, 150),
		ZIndex = 10,
	}, function()
		triggerBSOD("CRITICAL_PROCESS_DIED\nYou broke a rule.")
	end)
	Instance.new("UICorner", breakBtn).CornerRadius = UDim.new(0,4)

	local searchBtn = mkBtn(sg, {
		Size = UDim2.fromOffset(160, 34),
		Position = UDim2.new(1, -180, 0, 60),
		BackgroundColor3 = Color3.fromRGB(60, 20, 20),
		Text = "Search 'antivirus'",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 150, 150),
		ZIndex = 10,
	}, function()
		triggerBSOD("CRITICAL_PROCESS_DIED\nGoogle search not allowed.")
	end)
	Instance.new("UICorner", searchBtn).CornerRadius = UDim.new(0,4)

	-- blood drain
	local start = tick()
	if bloodConn then bloodConn:Disconnect() end
	bloodConn = RunService.RenderStepped:Connect(function()
		if broken then return end
		local elapsed = tick() - start
		local ratio = math.clamp(1 - elapsed / BLOOD_SECONDS, 0, 1)
		bloodLeft = math.floor(ratio * 100)
		bloodLbl.Text = "Blood Left: " .. bloodLeft .. "%"
		meterFill.Size = UDim2.fromScale(1, ratio)
		meterFill.Position = UDim2.fromScale(0, 1 - ratio)
		-- pulse red
		if bloodLeft < 20 then
			meterFill.BackgroundColor3 = Color3.fromRGB(255, 20, 20)
		end
		if ratio <= 0 then
			bloodConn:Disconnect()
			triggerBSOD("LogonUI overwritten.\nI own not only your thoughts\nbut also your machine.")
		end
	end)
end

-- ========== BSOD / final ==========
function triggerBSOD(msg)
	if broken then return end
	broken = true
	if bloodConn then bloodConn:Disconnect() end
	clearStage()

	local bg = mkFrame(sg, {
		Size = UDim2.fromScale(1,1),
		BackgroundColor3 = Color3.fromRGB(0, 90, 180),
		ZIndex = 1,
	})

	mkText(sg, {
		Size = UDim2.new(0.9,0,0,40),
		Position = UDim2.new(0.05,0,0.18,0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 48,
		TextColor3 = Color3.new(1,1,1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = ":(",
		ZIndex = 2,
	})

	mkText(sg, {
		Size = UDim2.new(0.85,0,0,80),
		Position = UDim2.new(0.05,0,0.32,0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 18,
		TextColor3 = Color3.new(1,1,1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "Your PC ran into a problem and needs to restart.\nWe're just collecting some error info, and then we'll restart for you.",
		ZIndex = 2,
	})

	mkText(sg, {
		Size = UDim2.new(0.85,0,0,100),
		Position = UDim2.new(0.05,0,0.48,0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(200, 220, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = tostring(msg) .. "\n\nStop code: CRITICAL_PROCESS_DIED\nWhat failed: LogonUI.exe / MrsMajor",
		ZIndex = 2,
	})

	local pct = mkText(sg, {
		Size = UDim2.new(0.5,0,0,24),
		Position = UDim2.new(0.05,0,0.72,0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.new(1,1,1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0% complete",
		ZIndex = 2,
	})

	task.spawn(function()
		for i = 0, 100, 2 do
			if not sg.Parent then return end
			pct.Text = i .. "% complete"
			task.wait(0.05)
		end
		task.wait(0.8)
		-- Red final screen
		clearStage()
		local r = mkFrame(sg, {
			Size = UDim2.fromScale(1,1),
			BackgroundColor3 = Color3.fromRGB(120, 0, 0),
			ZIndex = 1,
		})
		mkText(sg, {
			Size = UDim2.new(0.9,0,0,200),
			AnchorPoint = Vector2.new(0.5,0.5),
			Position = UDim2.fromScale(0.5,0.45),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 20,
			TextColor3 = Color3.new(1,1,1),
			TextWrapped = true,
			Text = "A problem has been detected and Windows has been shut down\nto prevent damage to your computer.\n\nTROJANS_NEVER_JOKE_RESPECT_THE_TROJANS\n\nI own not only your thoughts\nbut also your machine.\n\n— MrsMajor 3.0",
			ZIndex = 2,
		})
		local leave = mkBtn(sg, {
			Size = UDim2.fromOffset(140, 40),
			AnchorPoint = Vector2.new(0.5,0),
			Position = UDim2.new(0.5, 0, 0.78, 0),
			BackgroundColor3 = Color3.fromRGB(40,40,40),
			Text = "End demo",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = Color3.new(1,1,1),
			ZIndex = 3,
		}, function()
			sg:Destroy()
		end)
		Instance.new("UICorner", leave).CornerRadius = UDim.new(0,6)
	end)
end

-- start
stageAttention()
Notify("MrsMajor 3.0", "Visual demo only — no real infection.", 4)
