--[[
  猫なのは部 FULL
  - tanpopo&ona 1.25: 全機能（Kick/Anti/UFO/Music/All...）そのまま
  - Resonance: UI=Obsidian + R-Anti全タブ（アンチを絶対に全部）
  - No Blob All / 三人称 追加
  重複アンチは削除しない（両方残す）
]]

if getgenv().NekoFullHub then
    pcall(function() getgenv().NekoFullHub.Unload() end)
end

local OBSIDIAN = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(OBSIDIAN .. "Library.lua"))()
pcall(function() loadstring(game:HttpGet(OBSIDIAN .. "addons/ThemeManager.lua"))() end)
pcall(function() loadstring(game:HttpGet(OBSIDIAN .. "addons/SaveManager.lua"))() end)
Library.ShowToggleFrameInKeybinds = true
Library.ForceCheckbox = false

local WindowObsidian = Library:CreateWindow({
    Title = "猫なのは部 FULL",
    Footer = "tanpopo ALL + Resonance Anti ALL + NBA",
    NotifySide = "Right",
    ShowCustomCursor = false,
    AutoShow = true,
    Center = true,
    MobileButtonsSide = "Left",
})

local function StripFont(s)
    return (tostring(s or ""):gsub("<.->", ""))
end

local tabIndex = 0
local OrionLib = {}
local OrionWindow = nil

function OrionLib:MakeNotification(opts)
    opts = opts or {}
    pcall(function()
        Library:Notify({ Title = opts.Name or "Neko", Description = opts.Content or "", Time = opts.Time or 3 })
    end)
end

function OrionLib:MakeWindow(opts)
    OrionWindow = {}
    function OrionWindow:MakeTab(t)
        t = t or {}
        tabIndex += 1
        local raw = StripFont(t.Name or ("Tab"..tabIndex))
        local short = #raw > 16 and raw:sub(1,16) or raw
        local tab = WindowObsidian:AddTab(short, "sparkles")
        local gb = tab:AddGroupbox({ Side = "Left", Name = short, IconName = "box" })
        local gb2 = nil
        local elem = 0
        local function box()
            elem += 1
            if elem > 16 then
                if not gb2 then gb2 = tab:AddGroupbox({ Side = "Right", Name = short.." · more", IconName = "layers" }) end
                return gb2
            end
            return gb
        end
        local tabApi = {}
        function tabApi:AddSection(s)
            s = s or {}
            pcall(function() box():AddLabel({ Text = "— "..StripFont(s.Name or "Section").." —", DoesWrap = true }) end)
            return {}
        end
        function tabApi:AddLabel(text)
            pcall(function() box():AddLabel({ Text = StripFont(text), DoesWrap = true }) end)
            return {}
        end
        function tabApi:AddButton(cfg)
            cfg = cfg or {}
            pcall(function()
                box():AddButton({ Text = StripFont(cfg.Name or "Button"), Func = function()
                    if cfg.Callback then pcall(cfg.Callback) end
                end })
            end)
            return {}
        end
        function tabApi:AddToggle(cfg)
            cfg = cfg or {}
            local id = "T"..tabIndex.."_"..elem.."_"..math.random(10000,99999)
            local ref = { _value = cfg.Default and true or false }
            pcall(function()
                box():AddToggle(id, {
                    Text = StripFont(cfg.Name or "Toggle"),
                    Default = ref._value,
                    Callback = function(v) ref._value = v if cfg.Callback then pcall(cfg.Callback, v) end end,
                })
            end)
            function ref:Set(v)
                ref._value = v and true or false
                pcall(function() if Library.Toggles and Library.Toggles[id] then Library.Toggles[id]:SetValue(ref._value) end end)
                if cfg.Callback then pcall(cfg.Callback, ref._value) end
            end
            function ref:Get() return ref._value end
            return ref
        end
        function tabApi:AddSlider(cfg)
            cfg = cfg or {}
            local id = "S"..tabIndex.."_"..elem.."_"..math.random(10000,99999)
            local ref = { _value = cfg.Default or cfg.Min or 0 }
            pcall(function()
                box():AddSlider(id, {
                    Text = StripFont(cfg.Name or "Slider"),
                    Default = ref._value, Min = cfg.Min or 0, Max = cfg.Max or 100, Rounding = 0,
                    Callback = function(v) ref._value = v if cfg.Callback then pcall(cfg.Callback, v) end end,
                })
            end)
            function ref:Set(v) ref._value = v end
            function ref:Get() return ref._value end
            return ref
        end
        function tabApi:AddDropdown(cfg)
            cfg = cfg or {}
            local id = "D"..tabIndex.."_"..elem.."_"..math.random(10000,99999)
            local values = cfg.Options or cfg.Values or {}
            local def = cfg.Default
            if type(def) == "number" and values[def] then def = values[def] end
            if def == "" then def = values[1] end
            local ref = { _value = def }
            pcall(function()
                box():AddDropdown(id, {
                    Text = StripFont(cfg.Name or "Select"),
                    Values = values, Default = def, Multi = cfg.MultiSelect or false,
                    Callback = function(v) ref._value = v if cfg.Callback then pcall(cfg.Callback, v) end end,
                })
            end)
            function ref:Refresh(newOpts, _)
                values = newOpts or values
                pcall(function()
                    if Library.Options and Library.Options[id] and Library.Options[id].SetValues then
                        Library.Options[id]:SetValues(values)
                    end
                end)
            end
            function ref:Set(v)
                ref._value = v
                pcall(function() if Library.Options and Library.Options[id] and Library.Options[id].SetValue then Library.Options[id]:SetValue(v) end end)
                if cfg.Callback then pcall(cfg.Callback, v) end
            end
            function ref:Get() return ref._value end
            setmetatable(ref, { __index = function(_, k) if k=="Value" or k=="value" then return ref._value end end })
            return ref
        end
        function tabApi:AddTextbox(cfg)
            cfg = cfg or {}
            local id = "I"..tabIndex.."_"..elem
            pcall(function()
                box():AddInput(id, {
                    Text = StripFont(cfg.Name or "Input"), Default = cfg.Default or cfg.Text or "",
                    Callback = function(v) if cfg.Callback then pcall(cfg.Callback, v) end end,
                })
            end)
            return {}
        end
        function tabApi:AddParagraph(cfg) return tabApi:AddLabel((cfg and (cfg.Content or cfg.Name)) or "") end
        function tabApi:AddBind(cfg) return tabApi:AddButton(cfg) end
        function tabApi:AddColorpicker(cfg) return {} end
        return tabApi
    end
    return OrionWindow
end

function OrionLib:Init() end

OrionOptions = OrionOptions or {}
getgenv().NekoFullHub = {
    Unload = function()
        pcall(function() Library:Unload() end)
        getgenv().NekoFullHub = nil
    end,
    Library = Library,
}

-- ===== tanpopo FULL body below =====
local function __runTanpopoFull()

local StartTick1 = tick()

-- ============================================================
-- サービス
-- ============================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local InsertService = game:GetService("InsertService")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local plr = Players.LocalPlayer
local Player = plr
local mouse = plr:GetMouse()
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local head = char:WaitForChild("Head")
local IsHeld = plr:WaitForChild("IsHeld", 10)
local CanSpawnToy = plr:WaitForChild("CanSpawnToy", 10)
local InPlot = plr:WaitForChild("InPlot", 10)
local InOwnedPlot = plr:WaitForChild("InOwnedPlot", 10)
local AntiLineLag = plr.PlayerScripts:FindFirstChild("CharacterAndBeamMove")
local AntiShuriLag = plr.PlayerScripts:FindFirstChild("StickyPartsTouchDetection")
local inv = workspace:FindFirstChild(plr.Name.."SpawnedInToys") or workspace:WaitForChild(plr.Name.."SpawnedInToys", 10)

local GrabEvents = RS:WaitForChild("GrabEvents", 10)
local SetNetworkOwner = GrabEvents and GrabEvents:WaitForChild("SetNetworkOwner", 5)
local CreateGrabLine = GrabEvents and GrabEvents:WaitForChild("CreateGrabLine", 5)
local DestroyGrabLine = GrabEvents and GrabEvents:WaitForChild("DestroyGrabLine", 5)
local StickyEvent = RS:WaitForChild("PlayerEvents", 10) and RS.PlayerEvents:WaitForChild("StickyPartEvent", 5)
local DestroyToy = RS:WaitForChild("MenuToys", 10) and RS.MenuToys:WaitForChild("DestroyToy", 5)
local SpawnToyRemote = RS:WaitForChild("MenuToys", 10) and RS.MenuToys:WaitForChild("SpawnToyRemoteFunction", 5)
local Struggle = RS:WaitForChild("CharacterEvents", 10) and RS.CharacterEvents:WaitForChild("Struggle", 5)
local RagdollRemote = RS:WaitForChild("CharacterEvents", 10) and RS.CharacterEvents:WaitForChild("RagdollRemote", 5)
local GameCorrectionsNotify = RS:WaitForChild("GameCorrectionEvents", 10) and RS.GameCorrectionEvents:WaitForChild("GameCorrectionsNotify", 5)

-- chat spam removed

-- OrionLib = Obsidian adapter (Neko FULL)

local cons = {}
local bool = {}
local int = {}
local etc = {
    MyPCLD = nil, Contuuti = {}, Bananans = {}, AntiBananaCon = {},
    paintPartsBackup = {}, paintConnections = {},
}

local function GetMagnitude(a, b) return (a.Position - b.Position).Magnitude end
local function FWD(parent, part, time) return parent:FindFirstChild(part) or parent:WaitForChild(part, time) end
local function CFP(parent, part) return parent:FindFirstChild(part) ~= nil end

function cons:disc(k) if cons[k] then cons[k]:Disconnect() cons[k] = nil end end
function cons:cancel(c) if cons[c] then task.cancel(cons[c]) cons[c] = nil end end

local function FindPCLD()
    cons:disc("FindPCLDCon")
    cons["FindPCLDCon"] = RunService.Heartbeat:Connect(function()
        if etc.MyPCLD then cons:disc("FindPCLDCon") end
        for _, v in pairs(workspace:GetChildren()) do
            if v.Name == "PlayerCharacterLocationDetector" and GetMagnitude(v, hrp) <= 2 then
                etc.MyPCLD = v; break
            end
        end
    end)
end

local function OnCharAdded(character)
    char = character
    etc["MyPCLD"] = nil
    cons:disc("AntiMassless"); cons:disc("ThirdpFix")
    head = FWD(char, "Head"); hrp = FWD(char, "HumanoidRootPart"); hum = FWD(char, "Humanoid")
    cons["AntiMassless"] = hrp:GetPropertyChangedSignal("Massless"):Connect(function()
        if hrp.Massless and bool.AntiVoidEnabled then hrp.Massless = false end
    end)
    cons["ThirdpFix"] = head:GetPropertyChangedSignal("Transparency"):Connect(function()
        if head.Transparency == 1 then
            task.wait(0.1)
            for _, v in pairs(char:GetChildren()) do
                if (v:IsA("Accessory") and v.Name ~= "TypingKeyboardMyWorld") or v:IsA("Hat") then
                    v.Handle.Transparency = 0
                elseif v:IsA("BasePart") and v ~= hrp then v.Transparency = 0 end
            end
        end
    end)
    task.spawn(FindPCLD)
    hrp.CFrame = hrp.CFrame * CFrame.new(0, 1, 0)
    local scream = FWD(hrp, "Scream", 2); if scream then scream:Destroy() end
end

local function sno(part) if SetNetworkOwner and part then SetNetworkOwner:FireServer(part, part.CFrame) end end
local function CheckNetworkOwnerOnPart(Part) return CFP(Part, "PartOwner") and Part.PartOwner.Value == plr.Name end

local function CheckForHome()
    for i = 1, 5 do
        local Plot = workspace.Plots:FindFirstChild("Plot"..i)
        if Plot then
            local sign = Plot:FindFirstChild("PlotSign")
            local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
            if owners then
                for _, v in pairs(owners:GetChildren()) do
                    if v.Value == plr.Name then return workspace.PlotItems:FindFirstChild("Plot"..i) end
                end
            end
        end
    end
    return nil
end

local function SpawnToy(ToyName)
    if InPlot and InPlot.Value and InOwnedPlot and not InOwnedPlot.Value then InPlot:GetPropertyChangedSignal("Value"):Wait() end
    if CanSpawnToy and not CanSpawnToy.Value then CanSpawnToy:GetPropertyChangedSignal("Value"):Wait() end
    local SpawnCF = (etc.MyPCLD or hrp).CFrame * CFrame.new(0, 14, 20)
    local Container = (InOwnedPlot and InOwnedPlot.Value) and CheckForHome() or inv
    if not Container then return nil end
    local spawned = nil
    local conn = Container.ChildAdded:Connect(function(child) if child.Name == ToyName then spawned = child end end)
    task.spawn(function() pcall(function() SpawnToyRemote:InvokeServer(ToyName, SpawnCF, Vector3.zero) end) end)
    local start = tick()
    repeat task.wait() until spawned or (tick() - start) > 2.5
    if conn then conn:Disconnect() end
    return spawned
end

local playerDropdownRegistry = {}
local function GetPlayerListDisplay()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")") end
    end
    if #list == 0 then table.insert(list, "No Players") end
    return list
end
local function ExtractUsername(arg)
    if not arg or arg == "" or arg == "No Players" then return nil end
    local m = arg:match("%((@?[^%)]+)%)") or arg:match("@(.+)$") or arg:match("%((.+)%)")
    if m then m = m:gsub("^@", "") end
    return m
end
local function updateKickDropdown(dd) if dd then pcall(function() dd:Refresh(GetPlayerListDisplay(), true) end) end end
local function setupKickDropdown(dd) updateKickDropdown(dd) table.insert(playerDropdownRegistry, dd) end
local function _refreshKickDropdowns() for _, dd in ipairs(playerDropdownRegistry) do updateKickDropdown(dd) end end
Players.PlayerAdded:Connect(function() task.wait(1) _refreshKickDropdowns() end)
Players.PlayerRemoving:Connect(function() task.wait(1) _refreshKickDropdowns() end)

local function ChangeCollision(obj, val)
    for _, v in pairs(obj:GetChildren()) do if v:IsA("BasePart") and v.Name ~= "GrabParts" then v.CanCollide = val end end
end

-- Dance V2
local Fun = { Players = Players, RunService = RunService, ReplicatedStorage = RS, me = plr,
    camera = Workspace.CurrentCamera, RagdollRemote = RagdollRemote,
    currentDanceRawTableV2 = {}, danceListV2 = {}, activeDanceDataV2 = nil,
    selectedDanceNameV2 = "", isDancingV2 = false, poseConnectionV2 = nil, frameIndexV2 = 1, frameTimerV2 = 0 }
local SKIP_PARTS = { HumanoidRootPart = true, Handle = true, LArmIKPart = true, RArmIKPart = true }
local function parseCFrameData(t) return CFrame.new(t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9],t[10],t[11],t[12]) end
Fun.stopHipDanceV2 = function(arg)
    if Fun.poseConnectionV2 then Fun.poseConnectionV2:Disconnect() Fun.poseConnectionV2 = nil end
    if arg then local h = arg:FindFirstChildOfClass("Humanoid"); if h then h.PlatformStand = false h.AutoRotate = true end end
end
Fun.startHipDanceV2 = function(arg)
    if not Fun.activeDanceDataV2 then return end
    Fun.stopHipDanceV2(arg)
    local root = arg:WaitForChild("HumanoidRootPart"); local h = arg:WaitForChild("Humanoid")
    Fun.RagdollRemote:FireServer(root, 9999999)
    local position = root.Position; local ws = h.WalkSpeed > 0 and h.WalkSpeed or 16
    local fc = #Fun.activeDanceDataV2.frames; if fc == 0 then return end
    Fun.frameIndexV2 = 1; Fun.frameTimerV2 = 0
    Fun.poseConnectionV2 = RunService.Heartbeat:Connect(function(dt)
        if not arg.Parent or not root.Parent then return end
        local look = Fun.camera.CFrame.LookVector; local yaw = math.atan2(-look.X, -look.Z)
        if (root.Position - position).Magnitude > 8 then position = root.Position end
        local md = h.MoveDirection
        if md.Magnitude > 0.01 then position += md * ws * dt end
        local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
        root.CFrame = base; root.AssemblyLinearVelocity = Vector3.zero
        Fun.frameTimerV2 = Fun.frameTimerV2 + dt
        local wr = false
        if Fun.activeDanceDataV2.interval <= Fun.frameTimerV2 then
            Fun.frameTimerV2 = Fun.frameTimerV2 - Fun.activeDanceDataV2.interval
            Fun.frameIndexV2 = Fun.frameIndexV2 + 1
            if fc < Fun.frameIndexV2 then Fun.frameIndexV2 = 1 wr = true end
        end
        local fA = Fun.activeDanceDataV2.frames[Fun.frameIndexV2]
        local fB = Fun.activeDanceDataV2.frames[Fun.frameIndexV2 < fc and Fun.frameIndexV2 + 1 or 1]
        local alpha = wr and 1 or (Fun.frameTimerV2 / Fun.activeDanceDataV2.interval)
        for pn, cfd in pairs(fA.parts) do
            if not SKIP_PARTS[pn] then
                local p = arg:FindFirstChild(pn)
                if p and p:IsA("BasePart") then
                    local od = fB.parts[pn] or cfd
                    p.CFrame = base * parseCFrameData(cfd):Lerp(parseCFrameData(od), alpha)
                    p.AssemblyLinearVelocity = Vector3.zero
                end
            end
        end
    end)
end
Fun.refreshDanceV2List = function()
    local nt = {}
    local ok, result = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/dcus-official/PoopHub/refs/heads/main/Assets/Emote/List_Json.lua") end)
    if ok and result then
        local ok2, r2 = pcall(function() local ch = loadstring(result); if ch then return ch() end end)
        if ok2 and type(r2) == "table" then for k, v in pairs(r2) do nt[k] = v end end
    end
    if not isfolder("tanpopoHub") then makefolder("tanpopoHub") end
    if not isfolder("tanpopoHub/FTAP") then makefolder("tanpopoHub/FTAP") end
    if not isfolder("tanpopoHub/FTAP/Emote") then makefolder("tanpopoHub/FTAP/Emote") end
    local ok2, files = pcall(function() return listfiles("tanpopoHub/FTAP/Emote") end)
    if ok2 and type(files) == "table" then
        for _, fp in ipairs(files) do
            if fp:match("%.dance$") then
                local name = fp:gsub("\\", "/"):match("([^/]+)%.dance$")
                if name then local ok3, c = pcall(readfile, fp); if ok3 and c then nt[name] = c end end
            end
        end
    end
    if next(nt) == nil then if #Fun.danceListV2 == 0 then Fun.danceListV2 = { "No dances found" } end return end
    Fun.currentDanceRawTableV2 = nt
    local nl = {}
    for k in pairs(Fun.currentDanceRawTableV2) do table.insert(nl, k) end
    table.sort(nl)
    Fun.danceListV2 = nl
    if OrionOptions and OrionOptions.DanceV2Dropdown then pcall(function() OrionOptions.DanceV2Dropdown:Refresh(Fun.danceListV2, true) end) end
end
plr.CharacterAdded:Connect(function(c)
    task.wait(0.2)
    if Fun.isDancingV2 and Fun.activeDanceDataV2 then task.wait(0.3) Fun.startHipDanceV2(c) end
end)

-- ============================================================
-- UI
-- ============================================================
local Window = OrionLib:MakeWindow({
    Name = "tanpopo&ona1.25hub", IntroEnabled = true, IntroText = "tanpopo&ona1.25hub",
    HidePremium = false, SaveConfig = true, ConfigFolder = "AS_Script",
    Keybind = "K", FreeMouse = true,
})
local Toggles = {}
OrionOptions = {}

-- ============================================================
-- KICK&kill
-- ============================================================
local KickTab = Window:MakeTab({Name = "<font size = \"18\">KICK&kill</font>", Icon = "zap", PremiumOnly = false})
local selectedPlrName = nil
local Dropdown1 = KickTab:AddDropdown({Name = "ターゲット", Default = "", Options = GetPlayerListDisplay(),
    Callback = function(v) selectedPlrName = ExtractUsername(v) end})
setupKickDropdown(Dropdown1)

KickTab:AddSection({ Name = "▼ Anti-AntiKick (単体)" })
local AntiAntiToggles = {}
AntiAntiToggles.WD = KickTab:AddToggle({Name = "Anti-AntiKick<font color=\"rgb(255, 0, 255)\"><b>[WD]</b></font>", Default = false,
    Callback = function(Value)
        bool.LoopWD = Value
        if Value then
            task.spawn(function()
                local WD = inv:FindFirstChild("SprayCanWD")
                local SoundPart = WD and WD:FindFirstChild("SoundPart")
                local Root = selectedPlrName and Players:FindFirstChild(selectedPlrName) and Players:FindFirstChild(selectedPlrName).Character and Players:FindFirstChild(selectedPlrName).Character:FindFirstChild("HumanoidRootPart")
                if not WD then
                    WD = SpawnToy("SprayCanWD")
                    repeat task.wait() until WD and WD:FindFirstChild("SoundPart") or not bool.LoopWD
                    SoundPart = WD:FindFirstChild("SoundPart") or WD:WaitForChild("SoundPart", 3)
                    ChangeCollision(WD, false)
                end
                local HitBox = FWD(WD, "Hitbox")
                repeat sno(HitBox) task.wait(0.05) until not HitBox.Parent or not bool.LoopWD or HitBox:FindFirstChild("PartOwner")
                while bool.LoopWD and task.wait(0.2) do
                    SoundPart = WD and WD.Parent and WD:FindFirstChild("SoundPart")
                    Root = selectedPlrName and Players:FindFirstChild(selectedPlrName) and Players:FindFirstChild(selectedPlrName).Character and Players:FindFirstChild(selectedPlrName).Character:FindFirstChild("HumanoidRootPart")
                    if not Root then repeat Root = selectedPlrName and Players:FindFirstChild(selectedPlrName) and Players:FindFirstChild(selectedPlrName).Character and Players:FindFirstChild(selectedPlrName).Character:FindFirstChild("HumanoidRootPart") task.wait(0.1) until Root or not bool.LoopWD end
                    if SoundPart and Root then
                        SoundPart.CFrame = Root.CFrame * CFrame.new(0, 0, 4)
                        task.wait()
                        SoundPart.CFrame = CFrame.new(-382.838318, 41.6491699, 665.570251)
                        SoundPart.AssemblyAngularVelocity = Vector3.zero
                        SoundPart.AssemblyLinearVelocity = Vector3.zero
                    end
                end
            end)
        end
    end})

AntiAntiToggles.CLICK = KickTab:AddToggle({Name = "Anti-AntiKick<font color=\"rgb(0, 255, 0)\"><b>[CLICK]</b></font>", Default = false,
    Callback = function(Value)
        bool.LoopGrabAntiKick1 = Value
        if Value then
            task.spawn(function()
                local TI = selectedPlrName and workspace:FindFirstChild(selectedPlrName.."SpawnedInToys")
                local TP = selectedPlrName and Players:FindFirstChild(selectedPlrName)
                while bool.LoopGrabAntiKick1 and task.wait() do
                    if not TI or not TP then
                        TI = selectedPlrName and workspace:FindFirstChild(selectedPlrName.."SpawnedInToys")
                        TP = selectedPlrName and Players:FindFirstChild(selectedPlrName)
                    end
                    local Root = TP and TP.Character and TP.Character:FindFirstChild("HumanoidRootPart")
                    if not Root then continue end
                    local FPP = Root:FindFirstChild("FirePlayerPart"); if not FPP then continue end
                    if TI then
                        for _, v in pairs(TI:GetChildren()) do
                            local sp = v:FindFirstChild("StickyPart")
                            if sp then
                                if sp.CanQuery then
                                    task.spawn(function() for _, p in pairs(v:GetChildren()) do if p:IsA("BasePart") then p.CanCollide = false p.CanTouch = false p.CanQuery = false end end end)
                                end
                                if not CheckNetworkOwnerOnPart(sp) then sno(sp) end
                            end
                        end
                    end
                end
            end)
        end
    end})

AntiAntiToggles.BYPASS = KickTab:AddToggle({Name = "Anti-AntiKick<font color=\"rgb(100, 255, 100)\"><b>[BYPASS]</b></font>", Default = false,
    Callback = function(Value)
        bool.LoopGrabAntiKick2 = Value
        if Value then
            task.spawn(function()
                local TI = selectedPlrName and workspace:FindFirstChild(selectedPlrName.."SpawnedInToys")
                local TP = selectedPlrName and Players:FindFirstChild(selectedPlrName)
                while bool.LoopGrabAntiKick2 and task.wait() do
                    if not TI or not TP then
                        TI = selectedPlrName and workspace:FindFirstChild(selectedPlrName.."SpawnedInToys")
                        TP = selectedPlrName and Players:FindFirstChild(selectedPlrName)
                    end
                    local Root = TP and TP.Character and TP.Character:FindFirstChild("HumanoidRootPart")
                    if not Root then continue end
                    local FPP = Root:FindFirstChild("FirePlayerPart"); if not FPP then continue end
                    if TI then
                        for _, v in pairs(TI:GetChildren()) do
                            local sp = v:FindFirstChild("StickyPart")
                            if sp then
                                local sw = sp:FindFirstChild("StickyWeld"); if not sw then continue end
                                if sp.CanQuery then
                                    task.spawn(function() for _, p in pairs(v:GetChildren()) do if p:IsA("BasePart") then p.CanCollide = false p.CanTouch = false p.CanQuery = false end end end)
                                end
                                if sw.Part1 == hrp.FirePlayerPart and GetMagnitude(FPP, sp) > 7 then continue
                                elseif not CheckNetworkOwnerOnPart(sp) then sno(sp)
                                else StickyEvent:FireServer(sp, FPP, CFrame.new(0, -10, 5)) end
                            end
                        end
                    end
                end
            end)
        end
    end})

AntiAntiToggles.BLACKHOLE = KickTab:AddToggle({Name = "Anti-AntiKick<font color=\"rgb(255,100,255)\"><b>[BLACKHOLE]</b></font>", Default = false,
    Callback = function(Value)
        bool.loopGrabAntiKick3 = Value
        if not bool.loopGrabAntiKick3 then return end
        task.spawn(function()
            local S = {}
            while bool.loopGrabAntiKick3 and task.wait() do
                for i = 1, 10 do
                    local Shur = SpawnToy("NinjaKunai"); if not Shur then continue end
                    local sp = FWD(Shur, "StickyPart")
                    sno(sp); Shur.Name = i
                    local bp = Instance.new("BodyPosition")
                    bp.Position = Vector3.new(math.random(-100, 100), 1e3, math.random(-100, 100))
                    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bp.Parent = sp
                    table.insert(S, sp)
                end
                local HRP = Players:FindFirstChild(selectedPlrName) and Players:FindFirstChild(selectedPlrName).Character and Players:FindFirstChild(selectedPlrName).Character:FindFirstChild("HumanoidRootPart") and Players:FindFirstChild(selectedPlrName).Character:FindFirstChild("HumanoidRootPart"):FindFirstChild("FirePlayerPart")
                for _, v in pairs(S) do if v and v.Parent then StickyEvent:FireServer(v, HRP, CFrame.new(0, 0, 0)) end end
                task.wait(10)
            end
        end)
    end})

AntiAntiToggles.Burger = KickTab:AddToggle({Name = "Anti-Burger", Default = false,
    Callback = function(Value)
        bool.StealBurger = Value
        if Value then
            local TI = workspace[selectedPlrName.."SpawnedInToys"]
            for _, v in pairs(TI:GetDescendants()) do
                if v.Name == "HoldPart" then
                    local HF = v:FindFirstChild("HoldItemRemoteFunction")
                    local DF = v:FindFirstChild("DropItemRemoteFunction")
                    repeat
                        HF = v.Parent and v:FindFirstChild("HoldItemRemoteFunction")
                        DF = v.Parent and v:FindFirstChild("DropItemRemoteFunction")
                        if not HF then break end
                        task.wait(0.05)
                        task.spawn(function() HF:InvokeServer(v.Parent, char) end)
                    until not v or not v.Parent or not HF or not bool.StealBurger
                    if DF then task.spawn(function() DF:InvokeServer(v.Parent) end) end
                    v.Name = "NotHoldPart"
                end
            end
            cons["StealBurger"] = TI.DescendantAdded:Connect(function(desc)
                if desc.Name == "HoldPart" then
                    task.spawn(function()
                        FWD(desc, "HoldItemRemoteFunction"):InvokeServer(desc.Parent, char)
                        task.wait()
                    end)
                end
            end)
        else cons:disc("StealBurger") end
    end})

KickTab:AddSection({ Name = "▼ キック連動 Anti-AntiKick" })
local autoAntiAntiActive = false
local function setAllAntiAnti(state)
    if AntiAntiToggles.WD then AntiAntiToggles.WD:Set(state) end
    if AntiAntiToggles.CLICK then AntiAntiToggles.CLICK:Set(state) end
    if AntiAntiToggles.BYPASS then AntiAntiToggles.BYPASS:Set(state) end
    if AntiAntiToggles.BLACKHOLE then AntiAntiToggles.BLACKHOLE:Set(state) end
    if AntiAntiToggles.Burger then AntiAntiToggles.Burger:Set(state) end
end
KickTab:AddToggle({Name = "キック時に Anti-AntiKick 5種を自動発動", Default = false,
    Callback = function(Value) autoAntiAntiActive = Value end})

-- ============================================================
-- ▼ ドリフトキック
-- ============================================================
KickTab:AddSection({ Name = "▼ ドリフトキック" })
local GrabEventsRef = RS:FindFirstChild("GrabEvents")
local akActive = false; local akTask = nil
local function GetBlobmanAS()
    local f = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    return f and f:FindFirstChild("CreatureBlobman")
end
local function SpawnBlobmanAS()
    local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not r then return end
    SpawnToyRemote:InvokeServer("CreatureBlobman", r.CFrame * CFrame.new(0, 0, -5), Vector3.new(0, 90, 0))
end
local function DestroyBlobmanAS()
    local b = GetBlobmanAS(); if b then DestroyToy:FireServer(b) end
end
local function RideBlobmanAS()
    local blob = GetBlobmanAS()
    if not blob then
        SpawnBlobmanAS()
        local t0 = tick()
        repeat task.wait(0.1) blob = GetBlobmanAS() until blob or (tick() - t0) > 3
    end
    if not blob then return false end
    local c = plr.Character
    local h = c and c:FindFirstChild("Humanoid")
    if not h then return false end
    local seat = blob:FindFirstChildOfClass("VehicleSeat") or blob:FindFirstChild("VehicleSeat")
    if not seat then return false end
    if seat.Occupant ~= h then
        for i = 1, 5 do
            c = plr.Character
            h = c and c:FindFirstChild("Humanoid")
            if not h then break end
            local r = c:FindFirstChild("HumanoidRootPart")
            if r then r.CFrame = seat.CFrame + Vector3.new(0, 2, 0) end
            pcall(function() seat:Sit(h) end)
            task.wait(0.15)
            if seat.Occupant == h then break end
        end
    end
    return seat.Occupant == h
end
local function BlobSpamKickLoop(targetName)
    local itp, hc, gt, angle = nil, false, false, 0
    while akActive do
        local ct = Players:FindFirstChild(targetName)
        local blob = GetBlobmanAS()
        local c = plr.Character; local h = c and c:FindFirstChild("Humanoid")
        if not blob then SpawnBlobmanAS() hc = false task.wait(0.5) continue end
        local seat = blob:FindFirstChildOfClass("VehicleSeat") or blob:FindFirstChildOfClass("Seat")
        if seat and h and h.SeatPart ~= seat then seat:Sit(h) end
        local tC = ct and ct.Character
        local tR = tC and tC:FindFirstChild("HumanoidRootPart")
        local tH = tC and tC:FindFirstChildOfClass("Humanoid")
        local bR = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
        if tR and tH and tH.Health > 0 and bR then
            if not itp then itp = tR.Position end
            local cp = itp + Vector3.new(0, 23, 0)
            if not hc then
                tR.CFrame = CFrame.new(cp); tH.PlatformStand = true
                if GrabEventsRef and GrabEventsRef.SetNetworkOwner then GrabEventsRef.SetNetworkOwner:FireServer(tR, tR.CFrame) end
                task.wait(0.1); hc = true
            end
            angle = angle + 0.15
            local ox = math.cos(angle) * 18
            local oz = math.sin(angle) * 18
            bR.CFrame = CFrame.new(cp + Vector3.new(ox, 0, oz), cp)
            bR.Velocity = Vector3.zero
            tR.CFrame = CFrame.new(cp)
            pcall(function()
                local so = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                if so then
                    local CG = so:FindFirstChild("CreatureGrab")
                    local CD = so:FindFirstChild("CreatureDrop")
                    local R = blob:FindFirstChild("RightDetector")
                    local weld = R and (R:FindFirstChild("RightWeld") or R:FindFirstChildWhichIsA("Weld"))
                    if weld then CD:FireServer(weld) end
                    gt = not gt
                    local tg = gt and tR or bR
                    if GrabEventsRef and GrabEventsRef.SetNetworkOwner then GrabEventsRef.SetNetworkOwner:FireServer(tR, tR.CFrame) end
                    if GrabEventsRef and GrabEventsRef.DestroyGrabLine then GrabEventsRef.DestroyGrabLine:FireServer(tR) end
                    if CG and R and weld then CG:FireServer(R, tg, weld) end
                end
            end)
        else itp = nil; hc = false end
        RunService.Heartbeat:Wait()
    end
    DestroyBlobmanAS()
end
KickTab:AddToggle({Name = "ドリフトキック", Default = false,
    Callback = function(Value)
        akActive = Value
        if Value then
            if not selectedPlrName or not Players:FindFirstChild(selectedPlrName) then
                OrionLib:MakeNotification({Name = "Error", Content = "ターゲット未選択", Time = 3}); return
            end
            if autoAntiAntiActive then setAllAntiAnti(true) end
            task.spawn(function()
                local ok = RideBlobmanAS()
                if not akActive then return end
                if not ok then
                    OrionLib:MakeNotification({Name = "Error", Content = "Blobman騎乗失敗", Time = 3})
                    akActive = false
                    return
                end
                akTask = task.spawn(function() BlobSpamKickLoop(selectedPlrName) end)
            end)
        else
            if akTask then task.cancel(akTask) akTask = nil end
            DestroyBlobmanAS()
            if autoAntiAntiActive then setAllAntiAnti(false) end
        end
    end})

-- ============================================================
-- ▼ パレットキック
-- ============================================================
KickTab:AddSection({ Name = "▼ パレットキック" })
local PD_comboActive = false
local PD_comboTask = nil
local PD_ORBIT_RADIUS = 25
local PD_ORBIT_HEIGHT = 25
local PD_ORBIT_SPEED = 3

KickTab:AddSlider({Name = "パレットドリフト Orbit Speed", Min = 1, Max = 30, Default = 3,
    Color = Color3.fromRGB(255, 150, 50),
    Callback = function(v) PD_ORBIT_SPEED = v end})

local function PD_PalletRagdollFunction(target, isActiveCheck)
    if not target or not target.Character then return end
    local GE     = RS:WaitForChild("GrabEvents")
    local skyPos = CFrame.new(0, 800000, 0)
    RS.MenuToys.SpawnToyRemoteFunction:InvokeServer("PalletLightBrown", skyPos, Vector3.zero)
    local pallet
    repeat
        local folder = workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
        pallet = folder and folder:FindFirstChild("PalletLightBrown")
        RunService.Heartbeat:Wait()
    until pallet or not isActiveCheck()
    if not pallet then return end
    local mainPart = pallet:FindFirstChild("SoundPart") or pallet:FindFirstChildWhichIsA("BasePart")
    if not mainPart then return end
    mainPart.CanCollide = false
    mainPart.Anchored   = false
    local function claim(part)
        GE.SetNetworkOwner:FireServer(part, part.CFrame)
        GE.CreateGrabLine:FireServer(part, Vector3.zero, part.Position, false)
        GE.DestroyGrabLine:FireServer(part)
    end
    claim(mainPart)
    while isActiveCheck() do
        if not target or not target.Parent or not target.Character then break end
        local root = target.Character:FindFirstChild("HumanoidRootPart") or target.Character:FindFirstChild("Torso") or target.Character:FindFirstChild("UpperTorso")
        if not root then RunService.Heartbeat:Wait() continue end
        mainPart.CFrame = CFrame.new(root.Position + Vector3.new(0, 150, 0))
        mainPart.AssemblyLinearVelocity = Vector3.zero
        mainPart.AssemblyAngularVelocity = Vector3.zero
        claim(mainPart)
        mainPart.CanCollide = false
        task.wait(0.05)
        if root and target.Character then
            mainPart.CFrame = CFrame.new(root.Position)
            mainPart.AssemblyLinearVelocity = Vector3.new(0, -400, 0)
            mainPart.AssemblyAngularVelocity = Vector3.zero
            claim(mainPart)
            mainPart.CanCollide = true
        end
        task.wait(0.12)
        if root and target.Character then
            mainPart.CFrame = CFrame.new(root.Position + Vector3.new(0, 30, 0))
            mainPart.AssemblyLinearVelocity = Vector3.new(0, 100, 0)
            mainPart.AssemblyAngularVelocity = Vector3.zero
            claim(mainPart)
            mainPart.CanCollide = false
        end
        task.wait(0.08)
    end
    if pallet and pallet.Parent then
        pcall(function() RS.MenuToys.DestroyToy:FireServer(pallet) end)
        pallet:Destroy()
    end
end

local function PD_ComboFunction(target)
    local GE = RS:FindFirstChild("GrabEvents")
    local myChar = Player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local savedPos      = myRoot.CFrame
    local dragging      = false
    local grabStartTime = 0
    local orbitAngle    = 0
    task.spawn(function() PD_PalletRagdollFunction(target, function() return PD_comboActive end) end)
    while PD_comboActive do
        local dt = RunService.Heartbeat:Wait()
        myChar = Player.Character
        myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then task.wait(0.1) continue end
        if not target or not target.Parent then
            OrionLib:MakeNotification({Name = "パレットドリフト", Content = "ターゲット退出", Time = 3})
            PD_comboActive = false
            break
        end
        local tChar = target.Character
        if not tChar then task.wait(0.1) continue end
        local tRoot = tChar:FindFirstChild("HumanoidRootPart")
        local tHum  = tChar:FindFirstChild("Humanoid")
        local seat  = myChar.Humanoid and myChar.Humanoid.SeatPart
        if tRoot and tHum and tHum.Health > 0 then
            tRoot.AssemblyLinearVelocity  = Vector3.zero
            tRoot.Velocity                = Vector3.zero
            if seat then
                local blobman      = seat.Parent
                local remoteFolder = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
                local grab         = remoteFolder and remoteFolder:FindFirstChild("CreatureGrab")
                local drop         = remoteFolder and remoteFolder:FindFirstChild("CreatureDrop")
                local L_Det = blobman:FindFirstChild("LeftDetector")
                local R_Det = blobman:FindFirstChild("RightDetector")
                local L_Weld = L_Det and (L_Det:FindFirstChild("LeftWeld") or L_Det:FindFirstChild("RigidConstraint"))
                local R_Weld = R_Det and (R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChild("RigidConstraint"))
                if grab and drop and L_Weld and R_Weld then
                    pcall(function()
                        grab:FireServer(L_Det, tRoot, L_Weld)
                        grab:FireServer(R_Det, tRoot, R_Weld)
                        drop:FireServer(L_Weld, tRoot)
                        drop:FireServer(R_Weld, tRoot)
                    end)
                end
            end
            if not dragging then
                myRoot.CFrame = tRoot.CFrame
                if GE then
                    pcall(function()
                        tHum.PlatformStand = true
                        GE.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                        GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                    end)
                end
                if grabStartTime == 0 then grabStartTime = tick() end
                if tick() - grabStartTime > 0.3 then dragging = true grabStartTime = 0 end
            else
                local lockPos = savedPos * CFrame.new(0, PD_ORBIT_HEIGHT, 0)
                tRoot.CFrame  = lockPos
                orbitAngle = orbitAngle + PD_ORBIT_SPEED * dt
                local orbitOffset = Vector3.new(
                    math.cos(orbitAngle) * PD_ORBIT_RADIUS,
                    0,
                    math.sin(orbitAngle) * PD_ORBIT_RADIUS
                )
                myRoot.CFrame = CFrame.new(lockPos.Position + orbitOffset, lockPos.Position)
                if GE then
                    pcall(function()
                        tHum.PlatformStand = true
                        GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                        GE.DestroyGrabLine:FireServer(tRoot)
                        GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                    end)
                end
            end
        else
            dragging      = false
            grabStartTime = 0
        end
    end
    local finalChar = Player.Character
    local finalRoot = finalChar and finalChar:FindFirstChild("HumanoidRootPart")
    if finalRoot and savedPos then finalRoot.CFrame = savedPos end
    task.spawn(function()
        local toysFolder = workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
        if toysFolder then
            local pallet = toysFolder:FindFirstChild("PalletLightBrown")
            if pallet then
                pcall(function() RS.MenuToys.DestroyToy:FireServer(pallet) end)
                pallet:Destroy()
            end
        end
    end)
end

KickTab:AddToggle({Name = "パレットドリフト", Default = false,
    Callback = function(on)
        PD_comboActive = on
        if on then
            local targetPlr = selectedPlrName and Players:FindFirstChild(selectedPlrName)
            if not targetPlr then
                OrionLib:MakeNotification({Name = "パレットドリフト", Content = "ターゲット未選択", Time = 3})
                PD_comboActive = false
                return
            end
            if autoAntiAntiActive then setAllAntiAnti(true) end
            task.spawn(function()
                local ok = RideBlobmanAS()
                if not PD_comboActive then return end
                if not ok then
                    OrionLib:MakeNotification({Name = "パレットドリフト", Content = "Blobman騎乗失敗", Time = 3})
                    PD_comboActive = false
                    return
                end
                if PD_comboTask then task.cancel(PD_comboTask) end
                PD_comboTask = task.spawn(function() PD_ComboFunction(targetPlr) end)
                OrionLib:MakeNotification({Name = "パレットドリフト", Content = "開始: " .. targetPlr.Name, Time = 3})
            end)
        else
            PD_comboActive = false
            if PD_comboTask then task.cancel(PD_comboTask) PD_comboTask = nil end
            DestroyBlobmanAS()
            task.spawn(function()
                local toysFolder = workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                if toysFolder then
                    local pallet = toysFolder:FindFirstChild("PalletLightBrown")
                    if pallet then
                        pcall(function() RS.MenuToys.DestroyToy:FireServer(pallet) end)
                        pallet:Destroy()
                    end
                end
            end)
            if autoAntiAntiActive then setAllAntiAnti(false) end
            OrionLib:MakeNotification({Name = "パレットドリフト", Content = "停止", Time = 2})
        end
    end})

-- ============================================================
-- ▼ ✿ たんぽぽ kick ✿ (pastefy TdQ1jlCu から移植・中身そのまま)
-- ============================================================
KickTab:AddSection({ Name = "▼ ✿ たんぽぽ kick ✿" })
do
    local comboActive = false
    local comboTask = nil
    local ORBIT_RADIUS = 25
    local ORBIT_HEIGHT = 25
    local ORBIT_SPEED = 3

    local function autoSpawnAndRideBlobman()
        local char = Player.Character
        if not char then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return false end

        if hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
            return true
        end

        local spawnedFolder = workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
        local blobman = spawnedFolder and spawnedFolder:FindFirstChild("CreatureBlobman")

        if blobman then
            local lDet = blobman:FindFirstChild("LeftDetector")
            local rDet = blobman:FindFirstChild("RightDetector")
            local hasWeld =
                (lDet and (lDet:FindFirstChild("LeftWeld") or lDet:FindFirstChild("RigidConstraint")))
                or (rDet and (rDet:FindFirstChild("RightWeld") or rDet:FindFirstChild("RigidConstraint")))
            if not hasWeld then
                pcall(function() RS.MenuToys.DestroyToy:FireServer(blobman) end)
                blobman = nil
                task.wait(0.2)
            end
        end

        if not blobman then
            local mt = RS:FindFirstChild("MenuToys")
            local st = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
            if not st then
                OrionLib:MakeNotification({Name = "たんぽぽ", Content = "Spawn function not found.", Time = 3})
                return false
            end

            local spawnCF = root.CFrame + Vector3.new(0, 5, 0)
            pcall(function() st:InvokeServer("CreatureBlobman", spawnCF, Vector3.zero) end)

            local t0 = tick()
            repeat
                task.wait(0.1)
                spawnedFolder = workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                blobman = spawnedFolder and spawnedFolder:FindFirstChild("CreatureBlobman")
            until blobman or (tick() - t0) > 3
        end

        if not blobman then
            OrionLib:MakeNotification({Name = "たんぽぽ", Content = "Spawn failed.", Time = 3})
            return false
        end

        task.wait(0.2)

        local seat = blobman:FindFirstChild("VehicleSeat")
            or blobman:FindFirstChildWhichIsA("VehicleSeat", true)
        if not seat then
            OrionLib:MakeNotification({Name = "たんぽぽ", Content = "Seat not found.", Time = 3})
            return false
        end

        if seat.Occupant ~= hum then
            root.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
            task.wait(0.05)
            seat:Sit(hum)
            task.wait(0.3)
        end

        return true
    end

    KickTab:AddSlider({
        Name = "たんぽぽ Orbit Speed",
        Min = 1,
        Max = 30,
        Default = 3,
        Color = Color3.fromRGB(255, 180, 50),
        Callback = function(v)
            ORBIT_SPEED = v
        end,
    })

    local function PalletRagdollFunction(target, isActiveCheck)
        if not target or not target.Character then return end

        local GE = RS:WaitForChild("GrabEvents")
        local skyPos = CFrame.new(0, 800000, 0)

        RS.MenuToys.SpawnToyRemoteFunction:InvokeServer("PalletLightBrown", skyPos, Vector3.zero)

        local pallet
        repeat
            local folder = workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
            pallet = folder and folder:FindFirstChild("PalletLightBrown")
            RunService.Heartbeat:Wait()
        until pallet or not isActiveCheck()

        if not pallet then return end

        local mainPart = pallet:FindFirstChild("SoundPart")
            or pallet:FindFirstChildWhichIsA("BasePart")
        if not mainPart then return end

        for _, p in pairs(pallet:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
                p.Transparency = 0.8
            end
        end

        local function claim(part)
            GE.SetNetworkOwner:FireServer(part, part.CFrame)
            GE.CreateGrabLine:FireServer(part, Vector3.zero, part.Position, false)
            GE.DestroyGrabLine:FireServer(part)
        end

        claim(mainPart)

        local upDown = false
        local toggleCount = 0

        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not isActiveCheck() then
                if conn then conn:Disconnect() end
                return
            end

            if not target or not target.Parent or not target.Character then
                if conn then conn:Disconnect() end
                return
            end

            local root = target.Character:FindFirstChild("HumanoidRootPart")
                or target.Character:FindFirstChild("Torso")
                or target.Character:FindFirstChild("UpperTorso")

            if not root then return end

            toggleCount = toggleCount + 1
            if toggleCount >= 1 then
                toggleCount = 0
                upDown = not upDown
            end

            if upDown then
                mainPart.CFrame = CFrame.new(root.Position + Vector3.new(0, 30, 0))
            else
                mainPart.CFrame = CFrame.new(root.Position)
            end

            mainPart.AssemblyLinearVelocity = Vector3.zero
            mainPart.AssemblyAngularVelocity = Vector3.zero
            claim(mainPart)
        end)

        while isActiveCheck() do
            RunService.Heartbeat:Wait()
        end

        if conn then conn:Disconnect() end

        if pallet and pallet.Parent then
            pcall(function()
                RS.MenuToys.DestroyToy:FireServer(pallet)
            end)
            pallet:Destroy()
        end
    end

    local function ComboFunction(target)
        local GE = RS:FindFirstChild("GrabEvents")

        local myChar = Player.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local savedPos = myRoot.CFrame
        local dragging = false
        local grabStartTime = 0
        local orbitAngle = 0

        task.spawn(function()
            PalletRagdollFunction(target, function() return comboActive end)
        end)

        while comboActive do
            local dt = RunService.Heartbeat:Wait()

            myChar = Player.Character
            myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myRoot then
                task.wait(0.1)
                continue
            end

            if not selectedPlrName or not Players:FindFirstChild(selectedPlrName) then
                OrionLib:MakeNotification({Name = "たんぽぽ", Content = "Target left.", Time = 3})
                comboActive = false
                break
            end

            local tChar = target.Character
            if not tChar then
                task.wait(0.1)
                continue
            end

            local tRoot = tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar:FindFirstChild("Humanoid")
            local seat = myChar.Humanoid and myChar.Humanoid.SeatPart

            if tRoot and tHum and tHum.Health > 0 then
                tRoot.AssemblyLinearVelocity = Vector3.zero
                tRoot.Velocity = Vector3.zero

                if seat then
                    local blobman = seat.Parent
                    local remoteFolder = blobman:FindFirstChild("BlobmanSeatAndOwnerScript")
                    local grab = remoteFolder and remoteFolder:FindFirstChild("CreatureGrab")
                    local drop = remoteFolder and remoteFolder:FindFirstChild("CreatureDrop")

                    local L_Det = blobman:FindFirstChild("LeftDetector")
                    local R_Det = blobman:FindFirstChild("RightDetector")

                    local L_Weld = L_Det and (L_Det:FindFirstChild("LeftWeld")
                        or L_Det:FindFirstChild("RigidConstraint"))
                    local R_Weld = R_Det and (R_Det:FindFirstChild("RightWeld")
                        or R_Det:FindFirstChild("RigidConstraint"))

                    if grab and drop and L_Weld and R_Weld then
                        pcall(function()
                            grab:FireServer(L_Det, tRoot, L_Weld)
                            grab:FireServer(R_Det, tRoot, R_Weld)
                            drop:FireServer(L_Weld, tRoot)
                            drop:FireServer(R_Weld, tRoot)
                        end)
                    end
                end

                if not dragging then
                    myRoot.CFrame = tRoot.CFrame

                    if GE then
                        pcall(function()
                            tHum.PlatformStand = true
                            GE.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                            GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                        end)
                    end

                    if grabStartTime == 0 then grabStartTime = tick() end
                    if tick() - grabStartTime > 0.3 then
                        dragging = true
                        grabStartTime = 0
                    end
                else
                    local lockPos = savedPos * CFrame.new(0, ORBIT_HEIGHT, 0)
                    tRoot.CFrame = lockPos

                    orbitAngle = orbitAngle + ORBIT_SPEED * dt
                    local orbitOffset = Vector3.new(
                        math.cos(orbitAngle) * ORBIT_RADIUS,
                        0,
                        math.sin(orbitAngle) * ORBIT_RADIUS
                    )
                    myRoot.CFrame = CFrame.new(
                        lockPos.Position + orbitOffset,
                        lockPos.Position
                    )

                    if GE then
                        pcall(function()
                            tHum.PlatformStand = true
                            GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                            GE.DestroyGrabLine:FireServer(tRoot)
                            GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                        end)
                    end
                end
            else
                dragging = false
                grabStartTime = 0
            end
        end

        local finalChar = Player.Character
        local finalRoot = finalChar and finalChar:FindFirstChild("HumanoidRootPart")
        if finalRoot and savedPos then
            finalRoot.CFrame = savedPos
        end

        task.spawn(function()
            local toysFolder = workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
            if toysFolder then
                local pallet = toysFolder:FindFirstChild("PalletLightBrown")
                if pallet then
                    pcall(function() RS.MenuToys.DestroyToy:FireServer(pallet) end)
                    pallet:Destroy()
                end
            end
        end)
    end

    KickTab:AddToggle({
        Name = "✿ たんぽぽ kick ✿",
        Default = false,
        Callback = function(on)
            comboActive = on

            if on then
                local targetPlr = selectedPlrName and Players:FindFirstChild(selectedPlrName)
                if not targetPlr then
                    OrionLib:MakeNotification({Name = "たんぽぽ", Content = "Select target first.", Time = 3})
                    comboActive = false
                    return
                end

                if autoAntiAntiActive then setAllAntiAnti(true) end

                task.spawn(function()
                    autoSpawnAndRideBlobman()
                end)

                task.spawn(function()
                    local t0 = tick()
                    while comboActive and (tick() - t0) < 5 do
                        local char = Player.Character
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if hum and hum.SeatPart and hum.SeatPart.Parent
                            and hum.SeatPart.Parent.Name == "CreatureBlobman" then
                            break
                        end
                        task.wait(0.1)
                    end

                    if not comboActive then return end

                    if comboTask then task.cancel(comboTask) end
                    comboTask = task.spawn(function()
                        ComboFunction(targetPlr)
                    end)

                    OrionLib:MakeNotification({Name = "✿ たんぽぽ ✿", Content = "ON: " .. targetPlr.Name, Time = 3})
                end)
            else
                comboActive = false
                if comboTask then
                    task.cancel(comboTask)
                    comboTask = nil
                end

                task.spawn(function()
                    local toysFolder = workspace:FindFirstChild(Player.Name .. "SpawnedInToys")
                    if toysFolder then
                        local pallet = toysFolder:FindFirstChild("PalletLightBrown")
                        if pallet then
                            pcall(function() RS.MenuToys.DestroyToy:FireServer(pallet) end)
                            pallet:Destroy()
                        end
                    end
                end)

                if autoAntiAntiActive then setAllAntiAnti(false) end
                OrionLib:MakeNotification({Name = "✿ たんぽぽ ✿", Content = "OFF.", Time = 2})
            end
        end,
    })
end

-- Spamキック
KickTab:AddSection({ Name = "▼ Spamキック" })
local SKCfg = { Enabled = false, Distance = 25, HeightValue = 15, HeightMode = "上", Running = false, LagRunning = false, aa17 = nil, aa73 = nil }
KickTab:AddDropdown({Name = "スパムキック高さ位置", Default = "上", Options = {"上", "下"},
    Callback = function(Value) SKCfg.HeightMode = Value end})
KickTab:AddToggle({Name = "Spamキック（ラグドール & ラグ）", Default = false,
    Callback = function(aa61)
        SKCfg.Enabled = aa61; SKCfg.Running = aa61
        if aa61 and autoAntiAntiActive then setAllAntiAnti(true) end
        if not aa61 and autoAntiAntiActive then setAllAntiAnti(false) end
        local function aa31(a, b, t) return a:FindFirstChild(b) or a:WaitForChild(b, t or 5) end
        local function aa35(p) if p and p:IsA("BasePart") then SetNetworkOwner:FireServer(p, p.CFrame) task.wait() end end
        local function aa37(p, n) return p:FindFirstChild(n) ~= nil end
        local function aa40(name)
            local ch = plr.Character; if not ch then return nil end
            local r = ch:WaitForChild("HumanoidRootPart")
            local wc = 0
            while (plr.InPlot.Value and not plr.InOwnedPlot.Value) and wc < 50 do task.wait(0.1) wc = wc + 1 end
            wc = 0
            while not plr.CanSpawnToy.Value and wc < 50 do task.wait(0.1) wc = wc + 1 end
            local cf = r.CFrame * CFrame.new(0, 14, 20)
            local ct = workspace:FindFirstChild(plr.Name.."SpawnedInToys")
            if not ct then ct = workspace:FindFirstChild("PlotItems"); if ct then ct = ct:FindFirstChild("Plot1") end end
            if not ct then ct = workspace end
            local sp = nil
            local cn = ct.ChildAdded:Connect(function(c2) if c2.Name == name then sp = c2 end end)
            task.spawn(function() pcall(function() SpawnToyRemote:InvokeServer(name, cf, Vector3.zero) end) end)
            local st = tick()
            repeat task.wait(0.05) until sp or (tick() - st) > 5
            cn:Disconnect()
            return sp
        end
        local function aa50()
            if SKCfg.aa17 then return nil end
            SKCfg.aa17 = true
            local p = aa40("PalletLightBrown")
            if not p then SKCfg.aa17 = false return nil end
            local s = aa31(p, "SoundPart", 3)
            if not s then p:Destroy() SKCfg.aa17 = false return nil end
            local rc = 0
            while rc < 10 do
                if not SKCfg.Enabled then p:Destroy() SKCfg.aa17 = false return nil end
                aa35(s) task.wait()
                if aa37(s, "PartOwner") then break end
                rc = rc + 1
            end
            if not aa37(s, "PartOwner") then p:Destroy() SKCfg.aa17 = false return nil end
            for _, x in pairs(p:GetDescendants()) do if x:IsA("BasePart") then x.CanCollide = false x.Transparency = 0.8 end end
            p.Name = "RagdollPalete"
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(0, math.huge, 0); bv.Velocity = Vector3.new(0, 900, 0); bv.Parent = s
            SKCfg.aa17 = false
            return p
        end
        local function aa25(pl, root)
            if not pl.Character then return end
            local r2 = pl.Character:FindFirstChild("HumanoidRootPart")
            if not r2 or not root then return end
            local op = root.CFrame
            root.CFrame = r2.CFrame * CFrame.new(0, 0, 2)
            for i = 1, 15 do SetNetworkOwner:FireServer(r2, r2.CFrame) task.wait() end
            root.CFrame = op
        end
        local function startLagSpam()
            if SKCfg.LagRunning then return end
            if not selectedPlrName then return end
            if not CreateGrabLine then return end
            SKCfg.LagRunning = true
            task.spawn(function()
                while SKCfg.LagRunning do
                    local sl = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn") or (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart"))
                    if sl then CreateGrabLine:FireServer(sl, CFrame.new(math.random(-2010000000, 2000000001), 0, math.random(-2008100000, 2000200000))) end
                    task.wait(0.001)
                end
            end)
        end
        local function stopLagSpam() SKCfg.LagRunning = false end
        if aa61 then
            if not selectedPlrName then
                OrionLib:MakeNotification({Name = "エラー", Content = "ターゲット未選択", Time = 3})
                SKCfg.Enabled = false SKCfg.Running = false return
            end
            task.wait(0.5)
            task.defer(function() startLagSpam() end)
        else stopLagSpam() end
        if SKCfg.Enabled then
            task.spawn(function()
                while SKCfg.Enabled do
                    local pl = Players:FindFirstChild(selectedPlrName)
                    local my = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if pl and my then
                        local t = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
                        if t then
                            if (my.Position - t.Position).Magnitude > SKCfg.Distance then aa25(pl, my) end
                            SetNetworkOwner:FireServer(t, t.CFrame)
                            if DestroyGrabLine then DestroyGrabLine:FireServer(t) end
                            t.AssemblyLinearVelocity = Vector3.zero; t.AssemblyAngularVelocity = Vector3.zero
                            local bp = t:FindFirstChild("ControlBP")
                            if not bp then
                                bp = Instance.new("BodyPosition")
                                bp.Name = "ControlBP"; bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                                bp.P = 800000; bp.Parent = t
                            end
                            local ho = SKCfg.HeightValue
                            if SKCfg.HeightMode == "下" then ho = -SKCfg.HeightValue end
                            bp.Position = my.Position + Vector3.new(0, ho, 0)
                        end
                    end
                    task.wait(0.001)
                end
                local pl = Players:FindFirstChild(selectedPlrName)
                if pl and pl.Character then
                    local t = pl.Character:FindFirstChild("HumanoidRootPart")
                    if t and t:FindFirstChild("ControlBP") then t.ControlBP:Destroy() end
                end
            end)
        end
        if aa61 then
            local iv = workspace:FindFirstChild(plr.Name.."SpawnedInToys")
            local pr = nil
            SKCfg.aa73 = RunService.RenderStepped:Connect(function()
                if not SKCfg.Enabled then return end
                if not selectedPlrName then return end
                local pl = Players:FindFirstChild(selectedPlrName)
                if not pl or not pl.Character then return end
                local t = pl.Character:FindFirstChild("HumanoidRootPart")
                local h = pl.Character:FindFirstChild("Humanoid")
                if not t or not h then return end
                if pr and pr:IsDescendantOf(workspace) then
                    local s = pr:FindFirstChild("SoundPart")
                    if s then if not aa37(s, "PartOwner") then pr:Destroy() pr = nil end
                    else pr:Destroy() pr = nil end
                end
                if not SKCfg.aa17 and (not pr or not pr:IsDescendantOf(workspace)) then
                    pr = iv and iv:FindFirstChild("RagdollPalete") or aa50()
                end
                if pr and pr:FindFirstChild("SoundPart") then
                    local rd = h:FindFirstChild("Ragdolled")
                    if rd and not rd.Value then pr.SoundPart.Position = t.Position end
                end
            end)
        else
            if SKCfg.aa73 then SKCfg.aa73:Disconnect() SKCfg.aa73 = nil end
        end
    end})

-- Ragdoll Kill
KickTab:AddSection({ Name = "▼ Ragdoll Kill" })
local RG_isLooping = false
local RG_loopConnection = nil
local RG_monitorConnection = nil
local RG_currentBanana = nil
local RG_isRagdollActive = false
local RG_ragdollMonitorTask = nil
local function getHRP() local c = plr.Character; if c then return c:FindFirstChild("HumanoidRootPart") end end
local function getFolder() return Workspace:FindFirstChild(plr.Name .. "SpawnedInToys") end
local function destroyAllPencils()
    local f = getFolder(); if not f then return end
    for _, c in pairs(f:GetChildren()) do if c.Name == "ToolPencil" then pcall(function() DestroyToy:FireServer(c) end) end end
end
local function countPencils()
    local f = getFolder(); if not f then return 0 end
    local n = 0
    for _, c in pairs(f:GetChildren()) do if c.Name == "ToolPencil" then n = n + 1 end end
    return n
end
local function isPencilWelded()
    local f = getFolder(); if not f then return false end
    local t = Players:FindFirstChild(selectedPlrName)
    if not t or not t.Character then return false end
    local th = t.Character:FindFirstChild("Head"); if not th then return false end
    for _, c in pairs(f:GetChildren()) do
        if c.Name == "ToolPencil" then
            local sp = c:FindFirstChild("StickyPart")
            if sp then local w = sp:FindFirstChild("StickyWeld"); if w and w.Part1 == th then return true end end
        end
    end
    return false
end
local function spawnPencil()
    local r = getHRP(); if not r then return nil end
    local cf = r.CFrame * CFrame.new(0, 14, 20)
    local f = getFolder(); if not f then return nil end
    local sp = nil
    local cn = f.ChildAdded:Connect(function(c) if c.Name == "ToolPencil" then sp = c cn:Disconnect() end end)
    task.spawn(function() pcall(function() SpawnToyRemote:InvokeServer("ToolPencil", cf, Vector3.zero) end) end)
    local st = tick()
    repeat task.wait(0.05) until sp or (tick() - st) > 3
    if cn then pcall(function() cn:Disconnect() end) end
    return sp
end
local function setNetPencil(p) if not p then return end
    pcall(function() for i = 1, 5 do SetNetworkOwner:FireServer(p, p.CFrame) end end) end
local function doSticky()
    if not selectedPlrName or selectedPlrName == "" then return false end
    local t = Players:FindFirstChild(selectedPlrName)
    if not t or not t.Character then return false end
    local th = t.Character:FindFirstChild("Head"); if not th then return false end
    destroyAllPencils(); task.wait(0.05)
    local p = spawnPencil(); if not p then return false end
    local s = p:FindFirstChild("SoundPart")
    local sp = p:FindFirstChild("StickyPart")
    if s then setNetPencil(s) end
    task.wait(0.05)
    if sp then
        pcall(function()
            StickyEvent:FireServer(sp, th, CFrame.new(0, 0/0, 0))
            StickyEvent:FireServer(sp, th, CFrame.new(0, 0/0, 0))
        end)
        task.wait(0.5)
        if not isPencilWelded() then destroyAllPencils(); task.wait(0.05); doSticky() end
        return true
    end
    return false
end
local function RGRespawnMonitor()
    local t = Players:FindFirstChild(selectedPlrName); if not t then return end
    t.CharacterAdded:Connect(function() if RG_isRagdollActive then doSticky() end end)
end
local function PencilMonitor()
    while RG_isRagdollActive do
        local n = countPencils()
        if n == 0 then doSticky()
        elseif n >= 2 then destroyAllPencils(); task.wait(0.05); doSticky()
        elseif n == 1 and not isPencilWelded() then destroyAllPencils(); task.wait(0.05); doSticky() end
        task.wait(0.1)
    end
end
local function destroyBanana(b)
    if not b then return end
    local mt = RS:FindFirstChild("MenuToys"); if not mt then return end
    local dt = mt:FindFirstChild("DestroyToy"); if not dt then return end
    pcall(function() dt:FireServer(b) end)
end
local function spawnBanana()
    local r = getHRP(); if not r then return nil end
    local cf = r.CFrame * CFrame.new(0, 14, 20)
    local f = getFolder(); if not f then return nil end
    local sp = nil
    local cn = f.ChildAdded:Connect(function(c) if c.Name == "FoodBanana" then sp = c cn:Disconnect() end end)
    task.spawn(function() pcall(function() SpawnToyRemote:InvokeServer("FoodBanana", cf, Vector3.zero) end) end)
    local st = tick()
    repeat task.wait(0.05) until sp or (tick() - st) > 3
    if cn then pcall(function() cn:Disconnect() end) end
    return sp
end
local function holdBanana(b)
    if not b then return end
    local hp = b:FindFirstChild("HoldPart"); if not hp then return end
    local hr = hp:FindFirstChild("HoldItemRemoteFunction"); if not hr then return end
    local c = plr.Character; if not c then return end
    for i = 1, 5 do
        if not b or not b.Parent then break end
        local ok = pcall(function() return hr:InvokeServer(b, c) end)
        if ok then break end
        task.wait(0.05)
    end
end
local function useBanana(b)
    if not b then return end
    local u = RS:FindFirstChild("HoldEvents") and RS.HoldEvents:FindFirstChild("Use"); if not u then return end
    pcall(function() u:FireServer(b) end)
end
local function dropBanana(b)
    if not b then return end
    local hp = b:FindFirstChild("HoldPart"); if not hp then return end
    local dr = hp:FindFirstChild("DropItemRemoteFunction"); if not dr then return end
    local r = getHRP(); if not r then return end
    local dp = r.CFrame * CFrame.new(0, 15, 0)
    pcall(function() dr:InvokeServer(b, dp, dp) end)
end
local function getTargetLeg()
    if not selectedPlrName then return nil end
    local t = Players:FindFirstChild(selectedPlrName)
    if not t or not t.Character then return nil end
    return t.Character:FindFirstChild("Left Leg")
end
local function getTargetHealth()
    if not selectedPlrName then return 0 end
    local t = Players:FindFirstChild(selectedPlrName)
    if not t or not t.Character then return 0 end
    local h = t.Character:FindFirstChildOfClass("Humanoid"); if not h then return 0 end
    return h.Health
end
local function fullBananaCycle()
    if not selectedPlrName or selectedPlrName == "" then return false end
    local b = spawnBanana(); if not b then return false end
    holdBanana(b); task.wait(0.05); holdBanana(b); task.wait(0.05); task.wait(0.5)
    useBanana(b); task.wait(2.3)
    dropBanana(b); task.wait(0.05); dropBanana(b); task.wait(0.3)
    return b
end
local function restartLoop(b)
    if RG_loopConnection then RG_loopConnection:Disconnect() RG_loopConnection = nil end
    RG_currentBanana = b
    local hb = b:FindFirstChild("HitboxPart"); if not hb then return end
    RG_loopConnection = RunService.Heartbeat:Connect(function()
        if not RG_isLooping then stopLoop() return end
        if not RG_currentBanana or not RG_currentBanana.Parent then return end
        local f = getFolder(); local ex = false
        if f then for _, c in pairs(f:GetChildren()) do
            if c.Name == "FoodBanana" then ex = true; RG_currentBanana = c; hb = c:FindFirstChild("HitboxPart"); break end
        end end
        if not ex or not hb then RG_loopConnection:Disconnect() RG_loopConnection = nil RG_currentBanana = nil return end
        local r = getHRP(); if not r then return end
        local tp, tc
        local hl = getTargetHealth()
        if hl <= 0 then tp = r.CFrame * CFrame.new(0, 7, 0); tc = CFrame.new(tp.Position)
        else
            local leg = getTargetLeg()
            if leg then tp = leg.CFrame * CFrame.new(0, 0.5, 0); tc = leg.CFrame
            else tp = r.CFrame * CFrame.new(0, 7, 0); tc = CFrame.new(tp.Position) end
        end
        sno(hb); if DestroyGrabLine then DestroyGrabLine:FireServer(hb) end
        local bp = hb:FindFirstChild("BodyPosition")
        if bp then bp.Position = tp.Position
        else bp = Instance.new("BodyPosition"); bp.P = 10000; bp.D = 100
            bp.MaxForce = Vector3.new(1e9, 1e9, 1e9); bp.Position = tp.Position; bp.Parent = hb end
        local bg = hb:FindFirstChild("BodyGyro")
        if bg then bg.CFrame = tc
        else bg = Instance.new("BodyGyro"); bg.P = 10000; bg.D = 100
            bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9); bg.CFrame = tc; bg.Parent = hb end
    end)
end
function stopLoop()
    RG_isLooping = false
    if RG_loopConnection then RG_loopConnection:Disconnect() RG_loopConnection = nil end
    if RG_monitorConnection then RG_monitorConnection:Disconnect() RG_monitorConnection = nil end
    if RG_currentBanana then
        destroyBanana(RG_currentBanana)
        local hb = RG_currentBanana:FindFirstChild("HitboxPart")
        if hb then
            local bp = hb:FindFirstChild("BodyPosition"); if bp then bp:Destroy() end
            local bg = hb:FindFirstChild("BodyGyro"); if bg then bg:Destroy() end
        end
        RG_currentBanana = nil
    end
    local f = getFolder()
    if f then for _, c in pairs(f:GetChildren()) do if c.Name == "FoodBanana" then destroyBanana(c) end end end
end
local function startLoop()
    if RG_isLooping then return end
    if not selectedPlrName or selectedPlrName == "" then return end
    RG_isLooping = true
    local b = fullBananaCycle(); if b then restartLoop(b) end
    RG_monitorConnection = RunService.Heartbeat:Connect(function()
        if not RG_isLooping then return end
        local f = getFolder(); local ex = false
        if f then for _, c in pairs(f:GetChildren()) do if c.Name == "FoodBanana" then ex = true break end end end
        if not ex then
            if RG_loopConnection then RG_loopConnection:Disconnect() RG_loopConnection = nil end
            task.wait(0.05)
            local nb = fullBananaCycle(); if nb then restartLoop(nb) end
        end
    end)
end
KickTab:AddToggle({Name = "Ragdoll Kill", Default = false,
    Callback = function(v)
        if v then
            if not selectedPlrName or selectedPlrName == "" then return end
            RG_isRagdollActive = true
            doSticky(); RGRespawnMonitor()
            RG_ragdollMonitorTask = task.spawn(PencilMonitor)
        else
            RG_isRagdollActive = false
            if RG_ragdollMonitorTask then task.cancel(RG_ragdollMonitorTask) RG_ragdollMonitorTask = nil end
            destroyAllPencils()
        end
    end})
KickTab:AddToggle({Name = "Loop Banana Ragdoll", Default = false,
    Callback = function(v)
        if v then
            if not selectedPlrName or selectedPlrName == "" then
                if Toggles["Loop Banana Ragdoll"] then Toggles["Loop Banana Ragdoll"]:Set(false) end
                return
            end
            stopLoop(); startLoop()
        else stopLoop() end
    end})

-- ============================================================
-- 冷笑&熱笑 タブ
-- ============================================================
local ColdHotTab = Window:MakeTab({Name = "<font size = \"18\">冷笑&熱笑😅</font>", Icon = "message-circle", PremiumOnly = false})
local function GetDisplayName(plr_) local dn = plr_.DisplayName; if dn and dn ~= "" then return dn end return plr_.Name end
local COLD_LIST = {
    ["長文冷笑1"] = "{name}お、おう😅ちょおま、きついって😅えぐぅwかっけー😅",
    ["長文冷笑2"] = "{name}うおwえぐw😅かっこよwまじかwうんそれで？😅",
    ["うお😅"] = "{name}うお😅",
    ["かっけー😅"] = "{name}かっけー😅",
    ["えぐ😅"] = "{name}えぐ😅",
    ["どわー😅"] = "{name}どわー😅",
    ["がんばっちゃってる😅"] = "{name}がんばっちゃってる😅",
    ["きちー😅"] = "{name}きちー😅",
    ["ええて😅"] = "{name}ええて😅",
    ["えーそこまで😅"] = "{name}えーそこまで😅",
    ["イエベなんですね😅"] = "{name}イエベなんですね😅",
    ["落ち着け😅"] = "{name}落ち着け😅",
    ["そうなんだー😅"] = "{name}そうなんだー😅",
    ["うんうん😅"] = "{name}うんうん😅",
}
local HOT_LIST = {
    ["長文熱笑1"] = "{name}お前天才かよ！😎さすが{name}お前マジですげぇ！🥳",
    ["長文熱笑2"] = "{name}お前、ほんとに天才かよ！！😇まじですげぇ！😎俺もそんな風になりたい！一緒お前は親友！",
    ["お前最高！"] = "{name}お前最高！",
    ["天才かよ！😇"] = "{name}天才かよ！😇",
    ["もうお前天才！"] = "{name}もうお前天才！",
    ["最高すぎだろお前！😎"] = "{name}最高すぎだろお前！😎",
    ["もうお前、ほんとにえぐすぎ！"] = "{name}もうお前、ほんとにえぐすぎ！",
}
local SelectedColdKey = "長文冷笑1"
local SelectedHotKey = "長文熱笑1"
local FreeText = "{name}"
local TargetName_CH = ""
local TargetMap_CH = {}
local auraRadius = 30
local auraInterval = 2
local auraLastSent = {}
local coldAuraActive = false
local hotAuraActive = false
local freeAuraActive = false
local auraThread = nil
local serverSendToken = 0

local function SendChat(message)
    if message == nil or message == "" then return end
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local textChannel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if textChannel then textChannel:SendAsync(message) end
        else
            local rbxLegacyChat = RS:FindFirstChild("DefaultChatSystemChatEvents")
            if rbxLegacyChat then
                local sayMessage = rbxLegacyChat:FindFirstChild("SayMessageRequest")
                if sayMessage and sayMessage:IsA("RemoteEvent") then
                    sayMessage:FireServer(message, "All")
                end
            end
        end
    end)
end
local function BuildMessage_CH(template, plr_)
    if not plr_ then return nil end
    return template:gsub("{name}", GetDisplayName(plr_))
end
local function GetPlayerList_CH()
    local names = {}
    TargetMap_CH = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then
            local display = GetDisplayName(p) .. "(@" .. p.Name .. ")"
            table.insert(names, display)
            TargetMap_CH[display] = p.Name
        end
    end
    if #names == 0 then table.insert(names, "(None)") end
    return names
end
local function GetNearbyPlayers_CH(radius)
    local list = {}
    local myRoot = hrp
    if not myRoot then return list end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then
            local c = p.Character
            local root = c and c:FindFirstChild("HumanoidRootPart")
            if root and (root.Position - myRoot.Position).Magnitude <= radius then
                table.insert(list, p)
            end
        end
    end
    return list
end
local function GetAllOtherPlayers_CH()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then table.insert(list, p) end
    end
    return list
end
local function StartServerSend_CH(template)
    serverSendToken = serverSendToken + 1
    local myToken = serverSendToken
    task.spawn(function()
        local all = GetAllOtherPlayers_CH()
        if #all == 0 then
            OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "他にプレイヤーがいません", Time = 3})
            return
        end
        for _, p in ipairs(all) do
            if serverSendToken ~= myToken then
                OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "サーバー全体送信を停止しました", Time = 3})
                return
            end
            SendChat(BuildMessage_CH(template, p))
            task.wait(0.35)
        end
        if serverSendToken == myToken then
            OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "サーバー全体送信が完了しました", Time = 3})
        end
    end)
end

ColdHotTab:AddSection({ Name = "文章選択" })
ColdHotTab:AddDropdown({Name = "🧊 冷笑の文章を選択", Default = SelectedColdKey,
    Options = (function() local t = {} for k, _ in pairs(COLD_LIST) do table.insert(t, k) end table.sort(t) return t end)(),
    Callback = function(val) SelectedColdKey = val OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "冷笑文章を「" .. val .. "」に設定", Time = 3}) end})
ColdHotTab:AddDropdown({Name = "🔥 熱笑の文章を選択", Default = SelectedHotKey,
    Options = (function() local t = {} for k, _ in pairs(HOT_LIST) do table.insert(t, k) end table.sort(t) return t end)(),
    Callback = function(val) SelectedHotKey = val OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "熱笑文章を「" .. val .. "」に設定", Time = 3}) end})
ColdHotTab:AddSection({ Name = "ターゲット" })
local CH_Dropdown = ColdHotTab:AddDropdown({Name = "プレイヤーを選択", Default = "", Options = GetPlayerList_CH(),
    Callback = function(val) TargetName_CH = TargetMap_CH[val] or "" end})
ColdHotTab:AddButton({Name = "🔄 プレイヤーリスト更新", Callback = function()
    CH_Dropdown:Refresh(GetPlayerList_CH(), true)
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "プレイヤーリストを更新しました", Time = 3})
end})
ColdHotTab:AddSection({ Name = "手動送信" })
ColdHotTab:AddButton({Name = "🧊 冷笑を送る", Callback = function()
    local p = Players:FindFirstChild(TargetName_CH)
    if not p then OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "ターゲットを選択してください", Time = 3}) return end
    SendChat(BuildMessage_CH(COLD_LIST[SelectedColdKey], p))
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "冷笑を送信しました", Time = 3})
end})
ColdHotTab:AddButton({Name = "🔥 熱笑を送る", Callback = function()
    local p = Players:FindFirstChild(TargetName_CH)
    if not p then OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "ターゲットを選択してください", Time = 3}) return end
    SendChat(BuildMessage_CH(HOT_LIST[SelectedHotKey], p))
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "熱笑を送信しました", Time = 3})
end})
ColdHotTab:AddSection({ Name = "周囲送信" })
ColdHotTab:AddButton({Name = "🧊 周りに冷笑", Callback = function()
    local nearby = GetNearbyPlayers_CH(auraRadius)
    if #nearby == 0 then OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "近くにプレイヤーがいません", Time = 3}) return end
    for _, p in ipairs(nearby) do SendChat(BuildMessage_CH(COLD_LIST[SelectedColdKey], p)) task.wait(0.3) end
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = #nearby .. "人に冷笑を送信しました", Time = 3})
end})
ColdHotTab:AddButton({Name = "🔥 周りに熱笑", Callback = function()
    local nearby = GetNearbyPlayers_CH(auraRadius)
    if #nearby == 0 then OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "近くにプレイヤーがいません", Time = 3}) return end
    for _, p in ipairs(nearby) do SendChat(BuildMessage_CH(HOT_LIST[SelectedHotKey], p)) task.wait(0.3) end
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = #nearby .. "人に熱笑を送信しました", Time = 3})
end})
ColdHotTab:AddSection({ Name = "サーバー全体送信" })
ColdHotTab:AddButton({Name = "🌐 サーバー全体に冷笑", Callback = function() StartServerSend_CH(COLD_LIST[SelectedColdKey]) end})
ColdHotTab:AddButton({Name = "🌐 サーバー全体に熱笑", Callback = function() StartServerSend_CH(HOT_LIST[SelectedHotKey]) end})
ColdHotTab:AddButton({Name = "🛑 サーバー全体送信 停止", Callback = function()
    serverSendToken = serverSendToken + 1
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "サーバー全体送信を停止しました", Time = 3})
end})
ColdHotTab:AddSection({ Name = "Aura（自動周囲送信）" })
ColdHotTab:AddSlider({Name = "Aura範囲", Min = 5, Max = 100, Default = 30, Color = Color3.fromRGB(150, 200, 255),
    Callback = function(val) auraRadius = val end})
ColdHotTab:AddSlider({Name = "Aura間隔（秒）", Min = 1, Max = 10, Default = 2, Color = Color3.fromRGB(150, 200, 255),
    Callback = function(val) auraInterval = val end})
local function EnsureAuraThread()
    if auraThread then return end
    auraThread = task.spawn(function()
        while coldAuraActive or hotAuraActive or freeAuraActive do
            local nearby = GetNearbyPlayers_CH(auraRadius)
            for _, p in ipairs(nearby) do
                local now = tick()
                if not auraLastSent[p.UserId] or now - auraLastSent[p.UserId] >= auraInterval then
                    auraLastSent[p.UserId] = now
                    if coldAuraActive then SendChat(BuildMessage_CH(COLD_LIST[SelectedColdKey], p)) end
                    if hotAuraActive then task.wait(0.2) SendChat(BuildMessage_CH(HOT_LIST[SelectedHotKey], p)) end
                    if freeAuraActive then task.wait(0.2) SendChat(BuildMessage_CH(FreeText, p)) end
                end
            end
            task.wait(0.5)
        end
        auraThread = nil
    end)
end
ColdHotTab:AddToggle({Name = "🧊 冷笑 Aura", Default = false, Callback = function(state)
    coldAuraActive = state if state then EnsureAuraThread() end
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = state and "冷笑 Aura 開始" or "冷笑 Aura 停止", Time = 3})
end})
ColdHotTab:AddToggle({Name = "🔥 熱笑 Aura", Default = false, Callback = function(state)
    hotAuraActive = state if state then EnsureAuraThread() end
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = state and "熱笑 Aura 開始" or "熱笑 Aura 停止", Time = 3})
end})
ColdHotTab:AddToggle({Name = "✏️ 自由文章 Aura", Default = false, Callback = function(state)
    freeAuraActive = state if state then EnsureAuraThread() end
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = state and "自由文章 Aura 開始" or "自由文章 Aura 停止", Time = 3})
end})
ColdHotTab:AddSection({ Name = "自由文章" })
local freeInputGui = nil
local function OpenFreeInputWindow()
    if freeInputGui and freeInputGui.Parent then freeInputGui:Destroy() end
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FreeInputGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
    if not ScreenGui.Parent then ScreenGui.Parent = plr:WaitForChild("PlayerGui") end
    freeInputGui = ScreenGui
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 480, 0, 260)
    Frame.Position = UDim2.new(0.5, -240, 0.5, -130)
    Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Frame.BorderSizePixel = 0
    Frame.Active = true
    Frame.Draggable = true
    Frame.Parent = ScreenGui
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Frame
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 32)
    Title.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    Title.Text = "自由文章入力（{name} で表示名に置換）"
    Title.TextColor3 = Color3.fromRGB(0, 0, 0)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.Parent = Frame
    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(0.9, 0, 0, 130)
    Box.Position = UDim2.new(0.05, 0, 0.18, 0)
    Box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.PlaceholderText = "ここに自由な文章を入力"
    Box.Text = FreeText
    Box.Font = Enum.Font.Gotham
    Box.TextSize = 14
    Box.TextWrapped = true
    Box.ClearTextOnFocus = false
    Box.MultiLine = true
    Box.TextXAlignment = Enum.TextXAlignment.Left
    Box.TextYAlignment = Enum.TextYAlignment.Top
    Box.Parent = Frame
    local Save = Instance.new("TextButton")
    Save.Size = UDim2.new(0.42, 0, 0, 38)
    Save.Position = UDim2.new(0.05, 0, 0.82, 0)
    Save.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    Save.TextColor3 = Color3.fromRGB(0, 0, 0)
    Save.Text = "保存"
    Save.Font = Enum.Font.GothamBold
    Save.TextSize = 14
    Save.Parent = Frame
    local Cancel = Instance.new("TextButton")
    Cancel.Size = UDim2.new(0.42, 0, 0, 38)
    Cancel.Position = UDim2.new(0.53, 0, 0.82, 0)
    Cancel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    Cancel.TextColor3 = Color3.fromRGB(255, 255, 255)
    Cancel.Text = "キャンセル"
    Cancel.Font = Enum.Font.GothamBold
    Cancel.TextSize = 14
    Cancel.Parent = Frame
    Save.MouseButton1Click:Connect(function()
        FreeText = Box.Text
        OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "自由文章を保存しました", Time = 3})
        ScreenGui:Destroy()
    end)
    Cancel.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
end
ColdHotTab:AddButton({Name = "✏️ 自由文章を入力する", Callback = function() OpenFreeInputWindow() end})
ColdHotTab:AddButton({Name = "📨 自由文章をターゲットに送信", Callback = function()
    local p = Players:FindFirstChild(TargetName_CH)
    if not p then OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "ターゲットを選択してください", Time = 3}) return end
    if FreeText == "" then OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "文章が空です", Time = 3}) return end
    SendChat(BuildMessage_CH(FreeText, p))
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "自由文章を送信しました", Time = 3})
end})
ColdHotTab:AddButton({Name = "📢 自由文章を周りに送信", Callback = function()
    local nearby = GetNearbyPlayers_CH(auraRadius)
    if #nearby == 0 then OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "近くにプレイヤーがいません", Time = 3}) return end
    if FreeText == "" then OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = "文章が空です", Time = 3}) return end
    for _, p in ipairs(nearby) do SendChat(BuildMessage_CH(FreeText, p)) task.wait(0.3) end
    OrionLib:MakeNotification({Name = "冷笑&熱笑", Content = #nearby .. "人に自由文章を送信しました", Time = 3})
end})
ColdHotTab:AddButton({Name = "🌐 自由文章をサーバー全体に送信", Callback = function() StartServerSend_CH(FreeText) end})

-- ============================================================
-- アンチタブ
-- ============================================================
local AntiTab = Window:MakeTab({Name = "<font size = \"18\">アンチ</font>", Icon = "shield", PremiumOnly = false})

AntiTab:AddToggle({Name = "Anti-Grab", Default = true,
    Callback = function(Value)
        bool.AntiGrabToggle = Value
        if Value then
            cons["AntiGrab"] = RunService.Heartbeat:Connect(function()
                if hrp and hum and hrp.ReceiveAge ~= 0 then
                    hrp.Anchored = true
                    if IsHeld then IsHeld.Value = false end
                    task.spawn(function() Struggle:FireServer() RagdollRemote:FireServer(hrp, 0) end)
                    hum.AutoRotate = true
                    if hrp:FindFirstChild("RootJoint") then hrp.RootJoint.Enabled = true end
                    hrp.Anchored = false
                end
            end)
        else cons:disc("AntiGrab") end
    end})

AntiTab:AddToggle({Name = "Anti-Ragdoll", Default = true,
    Callback = function(Value)
        if Value then
            cons["AntiRagdoll"] = RunService.Heartbeat:Connect(function()
                if hrp and hum then
                    if hum.PlatformStand then hum.PlatformStand = false end
                    if hum.Sit and not hum.SeatPart then hum.Sit = false end
                    local rd = hum:FindFirstChild("Ragdolled")
                    if rd and rd.Value then RagdollRemote:FireServer(hrp, 0) end
                end
            end)
        else cons:disc("AntiRagdoll") end
    end})

AntiTab:AddToggle({Name = "Anti-Grab (Ragdoll)", Default = false,
    Callback = function(Value)
        if Value then
            local function setup(c)
                if not c then return end
                local h = c:WaitForChild("HumanoidRootPart", 5)
                local hu = c:WaitForChild("Humanoid", 5)
                local hd = c:WaitForChild("Head", 5)
                if not (h and hu and hd) then return end
                cons["AGHead"] = hd.ChildAdded:Connect(function(PO)
                    if PO.Name == "PartOwner" and not bool.AntigrabRGProc then
                        bool.AntigrabRGProc = true
                        hu.Sit = false
                        Struggle:FireServer(plr)
                        task.spawn(function()
                            while (hd and hd:FindFirstChild("PartOwner")) or IsHeld.Value do
                                Struggle:FireServer(plr); RagdollRemote:FireServer(h, 0); task.wait()
                            end
                        end)
                        h.Anchored = true; task.wait(0.5); h.Anchored = false
                        bool.AntigrabRGProc = false
                    end
                end)
            end
            setup(plr.Character)
            cons["AGChar"] = plr.CharacterAdded:Connect(setup)
        else cons:disc("AGHead") cons:disc("AGChar") end
    end})

AntiTab:AddToggle({Name = "Anti-Void", Default = false,
    Callback = function(state)
        if state then
            if not etc.originalVoidHeight then etc.originalVoidHeight = workspace.FallenPartsDestroyHeight end
            workspace.FallenPartsDestroyHeight = -1e95
        else workspace.FallenPartsDestroyHeight = etc.originalVoidHeight or -100 end
    end})

AntiTab:AddToggle({Name = "Anti-Sit", Default = false,
    Callback = function(Value)
        if Value then
            cons["AntiSit"] = RunService.Heartbeat:Connect(function()
                if hum and hrp and hum.Health > 0 then
                    hum.Sit = false; hum:ChangeState(Enum.HumanoidStateType.Running)
                    local cam = workspace.CurrentCamera
                    if cam then
                        local v = cam.CFrame.LookVector
                        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(v.X, 0, v.Z))
                    end
                end
            end)
        else cons:disc("AntiSit") end
    end})

AntiTab:AddToggle({Name = "Anti-Sticky", Default = false,
    Callback = function(Value) if AntiShuriLag then AntiShuriLag.Enabled = not Value end end})

-- ★ Anti-Lag はデフォルトtrue（起動時自動ON）
AntiTab:AddToggle({Name = "Anti-Lag", Default = true,
    Callback = function(Value)
        if AntiLineLag then AntiLineLag.Enabled = not Value end
        if AntiShuriLag then AntiShuriLag.Enabled = not Value end
    end})

AntiTab:AddToggle({Name = "Anti-Burn", Default = false,
    Callback = function(Value)
        if Value then
            cons["AntiBurn"] = RunService.Heartbeat:Connect(function()
                if hrp then
                    for _, v in pairs(hrp:GetChildren()) do
                        if v.Name == "FireLight" or v.Name == "FireParticleEmitter" or v.Name == "Fire" then v:Destroy() end
                    end
                end
            end)
        else cons:disc("AntiBurn") end
    end})

AntiTab:AddToggle({Name = "Anti-Explosion", Default = false,
    Callback = function(Value)
        if Value then
            cons["AntiExplosion"] = workspace.ChildAdded:Connect(function(model)
                if model.Name == "Part" and hrp and (model.Position - hrp.Position).Magnitude <= 20 then
                    hrp.Anchored = true; task.wait(0.01); hrp.Anchored = false
                end
            end)
        else cons:disc("AntiExplosion") end
    end})

AntiTab:AddToggle({Name = "Anti-Banana (Destroy)", Default = false,
    Callback = function(Value)
        bool.Antbananadest = Value
        etc.Bananans = etc.Bananans or {}; etc.AntiBananaCon = etc.AntiBananaCon or {}
        for name, c in pairs(etc.AntiBananaCon) do c:Disconnect() etc.AntiBananaCon[name] = nil end
        if not Value then table.clear(etc.Bananans) return end
        local function handle(banana)
            if not banana then return end
            local hp = banana:FindFirstChild("HoldPart"); if not hp then return end
            local hRF = hp:FindFirstChild("HoldItemRemoteFunction")
            local dRF = hp:FindFirstChild("DropItemRemoteFunction")
            local rc = hp:FindFirstChild("RigidConstraint")
            if rc and rc:FindFirstChild("Attachment1") then
                repeat task.wait() until not rc:FindFirstChild("Attachment1") or not banana.Parent
            end
            if dRF and hRF then
                repeat
                    task.wait()
                    task.spawn(function() pcall(function() hRF:InvokeServer(banana, char) end) end)
                    pcall(function() dRF:InvokeServer(banana, CFrame.new(0, -51000, 0), Vector3.zero) end)
                until not banana.Parent or not bool.Antbananadest
                if banana.Parent then table.insert(etc.Bananans, banana) end
            end
        end
        for _, p in pairs(Players:GetPlayers()) do
            local ct = workspace:FindFirstChild(p.Name .. "SpawnedInToys")
            if ct then
                for _, c in pairs(ct:GetChildren()) do if c.Name == "FoodBanana" then task.spawn(handle, c) end end
                etc.AntiBananaCon[ct.Name .. "BC"] = ct.ChildAdded:Connect(function(nc)
                    if nc.Name == "FoodBanana" then task.wait(0.1) task.spawn(handle, nc) end
                end)
            end
        end
    end})

AntiTab:AddToggle({Name = "Anti-Paint", Default = false,
    Callback = function(state)
        if state then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then
                    local clone = obj:Clone(); clone.Archivable = true
                    etc.paintPartsBackup[obj:GetDebugId()] = { clone = clone, parent = obj.Parent }
                    obj:Destroy()
                end
            end
            table.insert(etc.paintConnections, workspace.DescendantAdded:Connect(function(obj)
                if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then
                    task.defer(function()
                        if obj and obj.Parent then
                            local clone = obj:Clone(); clone.Archivable = true
                            etc.paintPartsBackup[obj:GetDebugId()] = { clone = clone, parent = obj.Parent }
                            obj:Destroy()
                        end
                    end)
                end
            end))
        else
            for _, conn in ipairs(etc.paintConnections) do if conn.Connected then conn:Disconnect() end end
            etc.paintConnections = {}
            for id, data in pairs(etc.paintPartsBackup) do if data.clone and data.parent then data.clone.Parent = data.parent end end
            etc.paintPartsBackup = {}
        end
    end})

-- Auto Delete Legs
do
    local ADLActive = false
    local ADLConn = nil
    local CE = RS:FindFirstChild("CharacterEvents")
    local RE = CE and CE:FindFirstChild("RagdollRemote")
    local function Perform(c)
        task.wait(0.5)
        if not ADLActive then return end
        local r = c:FindFirstChild("HumanoidRootPart")
        local h = c:FindFirstChild("Humanoid")
        local t = c:FindFirstChild("Torso")
        local ll = c:FindFirstChild("Left Leg")
        local rl = c:FindFirstChild("Right Leg")
        if r and h and t and ll and rl then
            local void = workspace.FallenPartsDestroyHeight
            local pos = t.CFrame
            workspace.FallenPartsDestroyHeight = -100
            if RE then RE:FireServer(r, 2) end
            task.wait(0.5)
            if ll and rl then rl.CFrame = CFrame.new(0, -10000, 0) ll.CFrame = CFrame.new(0, -10000, 0) end
            task.wait(0.3)
            if t then t.CFrame = CFrame.new(0, -9970, 0) end
            task.wait(0.5)
            if t then t.CFrame = pos end
            task.wait(0.5)
            workspace.FallenPartsDestroyHeight = void
            task.spawn(function()
                while ADLActive and c.Parent and h.Health > 0 and not c:FindFirstChild("Left Leg") and not c:FindFirstChild("Right Leg") do
                    pcall(function()
                        local cg = plr.PlayerGui:FindFirstChild("ControlsGui")
                        if cg and cg:FindFirstChild("PCFrame") and cg.PCFrame:FindFirstChild("Stand") then
                            if cg.PCFrame.Stand.Visible == false then h.HipHeight = 2 else h.HipHeight = 0 end
                        end
                    end)
                    task.wait()
                end
            end)
        end
    end
    AntiTab:AddToggle({Name = "Auto Delete Legs（両足消し）", Default = false,
        Callback = function(Value)
            ADLActive = Value
            if Value then
                task.spawn(function() Perform(plr.Character) end)
                if not ADLConn then
                    ADLConn = plr.CharacterAdded:Connect(function(nc)
                        if ADLActive then task.spawn(function() Perform(nc) end) end
                    end)
                end
            else if ADLConn then ADLConn:Disconnect() ADLConn = nil end end
        end})
    AntiTab:AddButton({Name = "Delete Legs（両足消し・手動）",
        Callback = function()
            local c = plr.Character; if not c then return end
            if c:FindFirstChild("Left Leg") and c:FindFirstChild("Right Leg") then
                local ll = c:FindFirstChild("Left Leg"); local rl = c:FindFirstChild("Right Leg")
                local r = c:FindFirstChild("HumanoidRootPart"); local t = c:FindFirstChild("Torso")
                if not r or not t then return end
                local void = workspace.FallenPartsDestroyHeight
                local pos = t.CFrame
                workspace.FallenPartsDestroyHeight = -100
                if RE then RE:FireServer(r, 2) end
                task.wait(0.5)
                rl.CFrame = CFrame.new(0, -10000, 0); ll.CFrame = CFrame.new(0, -10000, 0)
                task.wait(0.3); t.CFrame = CFrame.new(0, -9970, 0); task.wait(0.5)
                t.CFrame = pos; task.wait(0.5); workspace.FallenPartsDestroyHeight = void
            end
        end})
end

-- Anti Network
do
    local ANList = { "CupMugBrown","PoopPile","FoodDippyEgg","FoodCoconut","FoodBroccoli","FoodMayonnaise","InstrumentGuitarViolin","InstrumentGuitarBanjo" }
    local ANSelected = "CupMugBrown"
    local ANLooping = false
    local ANConn = nil
    local STR = RS:FindFirstChild("MenuToys") and RS.MenuToys:FindFirstChild("SpawnToyRemoteFunction")
    local DTR = RS:FindFirstChild("MenuToys") and RS.MenuToys:FindFirstChild("DestroyToy")
    local function destroyAN()
        local f = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
        local o = f and f:FindFirstChild(ANSelected)
        if o and DTR then pcall(function() DTR:FireServer(o) end) end
    end
    local function snatchAN(o)
        local c = plr.Character; if not (o and c) then return end
        local h = c:FindFirstChild("Head"); if not h then return end
        local hp = o:FindFirstChild("HoldPart")
        if hp then
            local hR = hp:FindFirstChild("HoldItemRemoteFunction")
            local dR = hp:FindFirstChild("DropItemRemoteFunction")
            if hR and dR then
                local dp = h.CFrame * CFrame.new(0, 3, 0)
                task.spawn(function() pcall(function() hR:InvokeServer(o, c) dR:InvokeServer(o, dp, dp) end) end)
            end
        end
    end
    local function startAN()
        if ANConn then return end
        ANLooping = true
        ANConn = RunService.Heartbeat:Connect(function()
            if not ANLooping then return end
            local f = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            if f then
                local o = f:FindFirstChild(ANSelected)
                if not o then
                    destroyAN()
                    local sp = (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")) and plr.Character.HumanoidRootPart.CFrame or CFrame.new(0, 5, 0)
                    if STR then pcall(function() STR:InvokeServer(ANSelected, sp, Vector3.new(0, 90, 0)) end) end
                    for i = 1, 15 do o = f:FindFirstChild(ANSelected) if o then break end task.wait() end
                end
                if o then snatchAN(o) end
            end
        end)
    end
    local function stopAN()
        ANLooping = false
        if ANConn then ANConn:Disconnect() ANConn = nil end
        destroyAN()
    end
    AntiTab:AddDropdown({Name = "Anti Network - アイテム選択", Default = "CupMugBrown", Options = ANList,
        Callback = function(v) ANSelected = v if ANLooping then stopAN() task.wait(0.1) startAN() end end})
    AntiTab:AddToggle({Name = "Anti Network", Default = false,
        Callback = function(v) if v then startAN() else stopAN() end end})
end

-- 触るとキル
do
    local defenseEnabled = false
    local defenseConnection = nil
    local defenseMode = "Fling"
    local crazyline = false
    local crazylineTask = nil
    local GE = RS:FindFirstChild("GrabEvents")
    local SNO = GE and GE:FindFirstChild("SetNetworkOwner")
    local DGL = GE and GE:FindFirstChild("DestroyGrabLine")
    local CGL = GE and GE:FindFirstChild("CreateGrabLine")
    local function getAttacker()
        local c = plr.Character
        if not c or not c:FindFirstChild("Head") then return nil end
        local owner = c.Head:FindFirstChild("PartOwner")
        if not owner or not owner:IsA("StringValue") then return nil end
        return Players:FindFirstChild(owner.Value)
    end
    local function pFling(a)
        if not a or not a.Character then return end
        local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
        pcall(function()
            if SNO then SNO:FireServer(r, r.CFrame) end
            if DGL then DGL:FireServer(r) end
            local mr = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart"); if not mr then return end
            local aw = (r.Position - mr.Position).Unit
            aw = Vector3.new(aw.X, 0, aw.Z) * 90000
            local bv = Instance.new("BodyVelocity")
            bv.Name = "RinneganFling"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = aw; bv.P = 12500; bv.Parent = r
            Debris:AddItem(bv, 0.01)
        end)
    end
    local function pKill(a)
        if not a or not a.Character then return end
        local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
        pcall(function()
            if SNO then SNO:FireServer(r, r.CFrame) end
            if DGL then DGL:FireServer(r) end
            local mr = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart"); if not mr then return end
            local aw = (r.Position - mr.Position).Unit
            aw = Vector3.new(aw.X, 0, aw.Z) * 99999999999999
            local bv = Instance.new("BodyVelocity")
            bv.Name = "RinneganFling"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = aw; bv.P = 12500; bv.Parent = r
            Debris:AddItem(bv, 0.01)
        end)
    end
    local function pHeaven(a)
        if not a or not a.Character then return end
        local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
        pcall(function()
            if SNO then SNO:FireServer(r, r.CFrame) end
            if DGL then DGL:FireServer(r) end
            r.CFrame = CFrame.new(0, 200, 0)
            local bv = Instance.new("BodyVelocity")
            bv.Name = "RinneganHeaven"; bv.MaxForce = Vector3.new(0, math.huge, 0)
            bv.Velocity = Vector3.new(0, 200, 0); bv.P = 12500; bv.Parent = r
            Debris:AddItem(bv, 0.01)
        end)
    end
    local function pKick(a)
        if not a or not a.Character then return end
        local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
        pcall(function()
            if SNO then SNO:FireServer(r, r.CFrame) end
            if DGL then DGL:FireServer(r) end
            r.CFrame = CFrame.new(0, 999999999999, 0)
            local bv = Instance.new("BodyVelocity")
            bv.Name = "RinneganHeaven"; bv.MaxForce = Vector3.new(0, math.huge, 0)
            bv.Velocity = Vector3.new(0, 99999999999999, 0); bv.P = 12500; bv.Parent = r
            Debris:AddItem(bv, 0.01)
        end)
    end
    local function pRagdoll(a)
        if not a or not a.Character then return end
        local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
        pcall(function()
            if SNO then SNO:FireServer(r, r.CFrame) end
            if DGL then DGL:FireServer(r) end
            local bv = Instance.new("BodyVelocity")
            bv.Name = "RinneganSpy"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, -20, 0); bv.P = 12500; bv.Parent = r
            Debris:AddItem(bv, 0.01)
        end)
    end
    local function pHell(a)
        if not a or not a.Character then return end
        local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
        pcall(function()
            if SNO then SNO:FireServer(r, r.CFrame) end
            if DGL then DGL:FireServer(r) end
            for _, p in ipairs(a.Character:GetDescendants()) do if p:IsA("BasePart") and not p.Anchored then p.CanCollide = false end end
            local bv = Instance.new("BodyVelocity")
            bv.Name = "RinneganSpy"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, -100000000, 0); bv.P = 12500; bv.Parent = r
            local nc
            nc = RunService.Heartbeat:Connect(function()
                if not a.Character or not a.Character.Parent then nc:Disconnect() return end
                for _, p in ipairs(a.Character:GetDescendants()) do if p:IsA("BasePart") and not p.Anchored then p.CanCollide = false end end
            end)
            task.delay(0.01, function() if nc then nc:Disconnect() end end)
            Debris:AddItem(bv, 0.01)
        end)
    end
    local function pChina(a)
        if not a or not a.Character then return end
        local r = a.Character:FindFirstChild("HumanoidRootPart"); if not r then return end
        pcall(function()
            if SNO then SNO:FireServer(r, r.CFrame) end
            if DGL then DGL:FireServer(r) end
            r.CFrame = CFrame.new(591, 153, -101)
        end)
    end
    local function pSpam()
        while crazyline do
            pcall(function()
                local c = plr.Character
                if c then
                    local h = c:FindFirstChild("Head")
                    if h then
                        local owner = h:FindFirstChild("PartOwner")
                        if owner and owner:IsA("StringValue") then
                            local a2 = Players:FindFirstChild(owner.Value)
                            if a2 and a2.Character then
                                local ah = a2.Character:FindFirstChild("Head")
                                local ar = a2.Character:FindFirstChild("HumanoidRootPart")
                                if ah and ar and CGL then
                                    for _ = 1, 10 do pcall(function() CGL:FireServer(ah, ah.CFrame) end) end
                                    for _ = 1, 10 do pcall(function() CGL:FireServer(ar, ar.CFrame) end) end
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(0.01)
        end
    end
    local function startCD()
        if defenseConnection then return end
        defenseConnection = RunService.Heartbeat:Connect(function()
            if not defenseEnabled then return end
            local a = getAttacker(); if not a then return end
            if defenseMode == "Fling" then pFling(a)
            elseif defenseMode == "Kill" then pKill(a)
            elseif defenseMode == "Send to Heaven" then pHeaven(a)
            elseif defenseMode == "Kick" then pKick(a)
            elseif defenseMode == "Ragdoll" then pRagdoll(a)
            elseif defenseMode == "Hell" then pHell(a)
            elseif defenseMode == "China" then pChina(a)
            elseif defenseMode == "GrabLine" then
                if not crazylineTask then crazyline = true crazylineTask = task.spawn(pSpam) end
            end
        end)
    end
    local function stopCD()
        if defenseConnection then defenseConnection:Disconnect() defenseConnection = nil end
        crazyline = false
        if crazylineTask then task.cancel(crazylineTask) crazylineTask = nil end
    end
    AntiTab:AddToggle({Name = "触るとキル（Counter Attacks）", Default = false,
        Callback = function(Value) defenseEnabled = Value if Value then startCD() else stopCD() end end})
    AntiTab:AddDropdown({Name = "Counter Attack Mode", Default = "Fling",
        Options = {"Fling","Kill","Send to Heaven","Kick","Ragdoll","Hell","China","GrabLine"},
        Callback = function(Value) defenseMode = Value end})
end

-- ============================================================
-- [GUCCI] Anti Grab (PoopHub Anti Only から移植・本体そのまま)
-- ============================================================
do
    local GucciCfg = {
        GucciType = "CreatureBlobman",
        Enabled = false,
    }
    local gucciRunId = 0
    local gucciCleanup = nil
    local isHeldVal = plr:FindFirstChild("IsHeld") or IsHeld

    local function gucciFindNicePart(model)
        if not model then return nil end
        for _, name in ipairs({ "HumanoidRootPart", "SoundPart", "Handle", "Part", "PrimaryPart" }) do
            local p = model:FindFirstChild(name, true)
            if p and p:IsA("BasePart") then return p end
        end
        return model:FindFirstChildWhichIsA("BasePart", true)
    end

    local function gucciDestroyToy(model)
        if not model then return end
        pcall(function()
            if DestroyToy then DestroyToy:FireServer(model) end
            model:Destroy()
        end)
    end

    local function gucciSpawnToy(toyName, cframe)
        if not SpawnToyRemote then return nil end
        local folder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
        if not folder then
            folder = Workspace:WaitForChild(plr.Name .. "SpawnedInToys", 5)
        end
        if not folder then return nil end
        local result = nil
        local conn
        conn = folder.ChildAdded:Connect(function(child)
            if child.Name == toyName or child.Name:find(toyName) then
                result = child
                if conn then conn:Disconnect() end
            end
        end)
        pcall(function()
            SpawnToyRemote:InvokeServer(toyName, cframe or CFrame.new(0, 1e15, 0), Vector3.zero)
        end)
        local t0 = tick()
        while not result and tick() - t0 < 3 do
            task.wait(0.05)
        end
        if conn then pcall(function() conn:Disconnect() end) end
        return result
    end

    local function gucciSno(part, cf)
        if not part then return false end
        if SetNetworkOwner then
            pcall(function() SetNetworkOwner:FireServer(part, cf or part.CFrame) end)
        end
        return true
    end

    local function gucciResetVelocity(part)
        if not part then return end
        pcall(function()
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
            part.Velocity = Vector3.zero
            part.RotVelocity = Vector3.zero
        end)
    end

    local function gucciTeleport(part, cf)
        if not part then return end
        pcall(function()
            part.CFrame = cf
            gucciResetVelocity(part)
        end)
    end

    local function stopGucciAntiGrab()
        gucciRunId = gucciRunId + 1
        if gucciCleanup then
            local fn = gucciCleanup
            gucciCleanup = nil
            pcall(fn)
        end
    end

    local function runGucciAntiGrab()
        gucciRunId = gucciRunId + 1
        local myId = gucciRunId
        local vehicle = nil
        local seat = nil
        local nicePart = nil
        local usedType = nil
        local hideConn = nil
        local respawnFlag = false

        local function cleanup()
            if hideConn then
                hideConn:Disconnect()
                hideConn = nil
            end
            if vehicle then
                gucciDestroyToy(vehicle)
                vehicle = nil
            end
            seat = nil
            nicePart = nil
            usedType = nil
        end

        gucciCleanup = cleanup

        local function waitTypeChange(currentType)
            while true do
                task.wait()
                if not (GucciCfg.GucciType ~= currentType or not GucciCfg.Enabled or myId ~= gucciRunId) then
                    continue
                end
                break
            end
        end

        local function hideDescendant(desc)
            if desc:IsA("BasePart") then
                desc.Transparency = 1
                desc.CanCollide = false
            elseif desc:IsA("Decal") or desc:IsA("Texture") then
                desc.Transparency = 1
            elseif desc.Name == "ItemSpawnSound" then
                desc:Destroy()
            end
        end

        while true do
            if not (GucciCfg.Enabled and myId == gucciRunId) then break end
            task.wait()

            local char = plr.Character
            local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health == 0 then
                plr.CharacterAdded:Wait()
                respawnFlag = true
                task.delay(1, function() respawnFlag = false end)
                task.wait(0.16)
                continue
            end

            local ragdolled = hum:FindFirstChild("Ragdolled")
            if not hrp or not ragdolled or (isHeldVal and isHeldVal.Value) or ragdolled.Value or hum.Health <= 0 then
                continue
            end

            if hum.Sit then hum.Sit = false end

            local gucciType = GucciCfg.GucciType
            local stillValid = vehicle and vehicle.Parent and seat and seat.Parent and usedType == gucciType
            local canReuse = false
            if stillValid then
                local occupant = seat.Occupant
                if occupant == nil or occupant == hum then
                    canReuse = true
                end
            end

            if not canReuse then
                cleanup()
                if gucciType == "Train" then
                    local map = Workspace:FindFirstChild("Map")
                    map = map and map:FindFirstChild("AlwaysHereTweenedObjects")
                    map = map and map:FindFirstChild("Train")
                    local object = map and map:FindFirstChild("Object")
                    object = object and object:FindFirstChild("ObjectModel")
                    if not object then
                        OrionLib:MakeNotification({Name = "Gucci", Content = "Train doesn't exist!", Time = 3})
                        waitTypeChange(gucciType)
                        continue
                    end
                    vehicle = object
                    seat = vehicle:FindFirstChildWhichIsA("Seat")
                    nicePart = nil
                    usedType = gucciType
                    if not seat then
                        OrionLib:MakeNotification({Name = "Gucci", Content = "Train doesn't have seats!", Time = 3})
                        waitTypeChange(gucciType)
                        cleanup()
                        continue
                    end
                else
                    vehicle = gucciSpawnToy(gucciType, CFrame.new(100000, 500000, 0))
                    seat = vehicle and vehicle:WaitForChild("VehicleSeat", 1.25)
                    nicePart = seat and gucciFindNicePart(vehicle) or nil
                    usedType = gucciType
                    if vehicle then
                        for _, descendant in pairs(vehicle:GetDescendants()) do
                            hideDescendant(descendant)
                        end
                        hideConn = vehicle.DescendantAdded:Connect(hideDescendant)
                    end
                    if not seat then
                        cleanup()
                        continue
                    end
                end
            end

            local vModel, vSeat, vPart = vehicle, seat, nicePart
            local activeSit = true
            if vPart then
                local gucciBP = vPart:FindFirstChild("GucciBP")
                if gucciBP then gucciBP:Destroy() end
            end
            vSeat.Transparency = 1
            vSeat.CanCollide = false
            local seatWeldDestroyed = false
            local savedCF = hrp.CFrame
            local sitStart = tick()

            vSeat.ChildAdded:Once(function(child)
                if child.Name == "SeatWeld" then
                    child.Enabled = false
                    child:Destroy()
                    seatWeldDestroyed = true
                end
            end)

            local ragdollReady = false
            task.defer(function()
                while hum and hum.Health > 0 and activeSit and task.wait() do
                    ragdollReady = true
                    if RagdollRemote then
                        pcall(function() RagdollRemote:FireServer(hrp, 0) end)
                    end
                end
                ragdollReady = true
            end)

            while true do
                task.wait()
                if ragdollReady or myId ~= gucciRunId then break end
            end
            if myId ~= gucciRunId then
                activeSit = false
                cleanup()
                break
            end

            vSeat:Sit(hum)

            while true do
                task.wait()
                local dead = hum.Health <= 0 or not hrp.Parent or not vModel.Parent or not vSeat.Parent
                if dead then break end
                local done = (isHeldVal and isHeldVal.Value) or ragdolled.Value or seatWeldDestroyed or tick() - sitStart > 0.75
                if done then break end
            end

            if seatWeldDestroyed then
                hum.Sit = false
                task.delay(0.15, function()
                    activeSit = false
                    task.wait()
                    if RagdollRemote and hrp.Parent then
                        pcall(function() RagdollRemote:FireServer(hrp, 0.15) end)
                    end
                end)
                if respawnFlag then
                    gucciTeleport(hrp, savedCF)
                end
                if GucciCfg.GucciType ~= "Train" and vPart then
                    local plotItems = Workspace:FindFirstChild("PlotItems")
                    local isOwned = plotItems and vPart:IsDescendantOf(plotItems)
                    local gotOwner = isOwned or gucciSno(vPart)
                    if gotOwner then
                        local vector = Vector3.new(math.random(-100000, 100000), 100000, math.random(-100000, 100000))
                        local bodyPosition = Instance.new("BodyPosition")
                        bodyPosition.Name = "GucciBP"
                        bodyPosition.D = 200
                        bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bodyPosition.Position = vector
                        vModel.Name = "GucciRSC"
                        bodyPosition.Parent = vPart
                    end
                end
                task.delay(0.75, function()
                    if not vSeat or not vSeat.Parent or not vModel or not vModel.Parent then return end
                    vSeat.Parent = RS
                    task.wait()
                    if hum and hum.Parent then
                        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                    end
                    if vModel and vModel.Parent and vSeat then
                        vSeat.Parent = vModel
                    end
                end)

                while true do
                    local parentOk = vModel.Parent and vSeat.Parent and hum.Parent
                    local keep = parentOk and hum.Health > 0 and not (isHeldVal and isHeldVal.Value) and not ragdolled.Value and (vSeat.Occupant == nil or vSeat.Occupant == hum) and GucciCfg.Enabled and GucciCfg.GucciType == gucciType and myId == gucciRunId
                    if keep then
                        task.wait()
                        continue
                    end
                    break
                end

                local occupant = vSeat.Occupant
                if occupant and occupant ~= hum and occupant.Parent then
                    local other = Players:FindFirstChild(occupant.Parent.Name)
                    if other then
                        OrionLib:MakeNotification({Name = "Gucci", Content = other.DisplayName .. " sat on your gucci!", Time = 3})
                    end
                end
                if hum and hum.Parent and hum.Health > 0 then
                    if hum.SeatPart and hum.SeatPart ~= vSeat then
                        OrionLib:MakeNotification({Name = "Gucci", Content = "You can't sit on other Vehicles while in Gucci!", Time = 3})
                    end
                    hum.Sit = true
                    task.wait(0.05)
                    hum.Sit = false
                    task.wait(0.05)
                end
            end

            if hideConn then
                hideConn:Disconnect()
                hideConn = nil
            end
            if vModel and vModel.Parent then
                gucciDestroyToy(vModel)
            end
            vehicle = nil
            seat = nil
            nicePart = nil
            usedType = nil
            activeSit = false
            task.wait(0.05)
        end

        cleanup()
        if gucciCleanup == cleanup then gucciCleanup = nil end
    end

    AntiTab:AddSection({ Name = "▼ [GUCCI] Anti Grab (PoopHub)" })
    AntiTab:AddDropdown({
        Name = "GUCCI Type",
        Default = "Blobman",
        Options = { "Blobman", "Tractor [Invisible]", "Train [Invisible]", "Sleigh [Invisible]" },
        Callback = function(val)
            if val == "Blobman" then
                GucciCfg.GucciType = "CreatureBlobman"
            elseif val == "Tractor [Invisible]" then
                GucciCfg.GucciType = "TractorGreen"
            elseif val == "Train [Invisible]" then
                GucciCfg.GucciType = "Train"
            elseif val == "Sleigh [Invisible]" then
                GucciCfg.GucciType = "SantaSleigh"
            end
        end,
    })
    AntiTab:AddToggle({
        Name = "[GUCCI] Anti Grab",
        Default = false,
        Callback = function(state)
            GucciCfg.Enabled = state
            if state then
                task.spawn(runGucciAntiGrab)
            else
                stopGucciAntiGrab()
            end
        end,
    })
    AntiTab:AddButton({
        Name = "Gucci Binder (旧・1回)",
        Callback = function()
            local c = plr.Character or plr.CharacterAdded:Wait()
            local h = FWD(c, "Humanoid")
            h.Sit = true; task.wait(0.02); h.Sit = false; task.wait(0.02)
            task.spawn(function()
                local t = tick()
                while tick() - t < 0.8 do
                    for _, v in pairs(c:GetChildren()) do if v:IsA("BasePart") then v.Velocity = Vector3.new() end end
                    task.wait(0.01)
                end
            end)
            local Blob = nil
            local r = FWD(c, "HumanoidRootPart")
            task.spawn(function()
                if SpawnToyRemote then
                    SpawnToyRemote:InvokeServer("CreatureBlobman", r.CFrame * CFrame.new(0, 0, -5), Vector3.new(0, -15.716, 0))
                end
                local bp = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                for i = 1, 50 do
                    Blob = bp and bp:FindFirstChild("CreatureBlobman")
                    if Blob then break end
                    task.wait(0.05)
                end
            end)
            for i = 1, 100 do if Blob then break end task.wait(0.02) end
            if not Blob then return end
            local Seat = FWD(Blob, "VehicleSeat")
            if Seat then Seat:Sit(h) end
            task.wait(0.4)
            h.Sit = false
            Blob.Name = "Gucci"
            for _, v in pairs(Blob:GetChildren()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                    v.CanTouch = false
                    v.CanQuery = false
                end
            end
        end,
    })
end

-- ============================================================
-- ▼ Anti-Kick (lol_private FULL EDITION から移植)
-- ============================================================
AntiTab:AddSection({ Name = "▼ Anti-Kick (lol_private)" })

local KickCfg = {
    Tinko = false,
    kickitemToggle = false,
    kickitemPCLD = nil,
    kickitemPCLDcon = nil,
    AntikickT = false,
    AntikickResetToggle = true,
    AntikickLeaveToggle = false,
    AutoTurnOnAntiKick = true,
    Contuuti = {},
}

-- ============================================================
-- Anti-Kick / Tool Rainbow ESP（全アンチキック関連を虹色に）
-- ============================================================
do
    local ToolESP = {
        highlights = {},
        connections = {},
        enabled = true,
        targets = {
            -- ツール本体
            ToolPickaxe = true,
            NinjaKatana = true,
            ToolCleaver = true,
            ToolPencil = true,
            NinjaKunai = true,
            ToolDiggingForkRusty = true,
            NinjaShuriken = true,
            -- AntiKick リネーム後
            AntiKick = true,
            AntiKickItem = true,
            -- Anti-Kick [ITEM] 系
            JapaneseLantern = true,
            SprayCanWD = true,
            SpookyCandle1 = true,
            -- Back Stab 等
            -- （必要なら追加）
        },
    }

    local function GetRainbowColor(offset)
        local t = tick() * 0.5 + (offset or 0)
        local r = math.sin(t) * 0.5 + 0.5
        local g = math.sin(t + 2.094) * 0.5 + 0.5
        local b = math.sin(t + 4.188) * 0.5 + 0.5
        return Color3.new(r, g, b)
    end

    local function RemoveToolHighlight(model)
        local h = ToolESP.highlights[model]
        if h then
            pcall(function() h:Destroy() end)
            ToolESP.highlights[model] = nil
        end
    end

    local function AddToolHighlight(model)
        if not ToolESP.enabled then return end
        if ToolESP.highlights[model] then return end
        if not model or not model.Parent then return end
        if not ToolESP.targets[model.Name] then return end
        local high = Instance.new("Highlight")
        high.Name = "ToolESP_Highlight"
        high.Adornee = model
        high.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        high.FillTransparency = 0.6
        high.OutlineTransparency = 0
        high.FillColor = GetRainbowColor()
        high.OutlineColor = GetRainbowColor()
        high.Parent = model
        ToolESP.highlights[model] = high
        model.AncestryChanged:Connect(function(_, parent)
            if not parent then RemoveToolHighlight(model) end
        end)
    end

    local function ScanFolderForTools(folder)
        if not folder then return end
        for _, v in ipairs(folder:GetChildren()) do
            if ToolESP.targets[v.Name] then
                AddToolHighlight(v)
            end
        end
    end

    local function SetupFolderConnection(folder)
        if not folder then return end
        if ToolESP.connections[folder] then return end
        ToolESP.connections[folder] = folder.ChildAdded:Connect(function(child)
            if ToolESP.targets[child.Name] then
                task.wait(0.05)
                AddToolHighlight(child)
            end
        end)
    end

    local function ScanAllFolders()
        local myInv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
        SetupFolderConnection(myInv)
        ScanFolderForTools(myInv)

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= plr then
                local f = workspace:FindFirstChild(p.Name .. "SpawnedInToys")
                SetupFolderConnection(f)
                ScanFolderForTools(f)
            end
        end

        local plotItems = workspace:FindFirstChild("PlotItems")
        if plotItems then
            SetupFolderConnection(plotItems)
            for _, plotFolder in ipairs(plotItems:GetChildren()) do
                SetupFolderConnection(plotFolder)
                ScanFolderForTools(plotFolder)
            end
        end
    end

    local function ClearAllHighlights()
        for model, high in pairs(ToolESP.highlights) do
            pcall(function() if high then high:Destroy() end end)
            ToolESP.highlights[model] = nil
        end
    end

    -- 初期スキャン
    task.spawn(function()
        task.wait(0.5)
        ScanAllFolders()
    end)

    Players.PlayerAdded:Connect(function(p)
        task.wait(1)
        local f = workspace:FindFirstChild(p.Name .. "SpawnedInToys")
        SetupFolderConnection(f)
        ScanFolderForTools(f)
    end)

    workspace.ChildAdded:Connect(function(child)
        if child.Name:match("SpawnedInToys$") or child.Name == "PlotItems" then
            task.wait(0.2)
            SetupFolderConnection(child)
            ScanFolderForTools(child)
            if child.Name == "PlotItems" then
                for _, plotFolder in ipairs(child:GetChildren()) do
                    SetupFolderConnection(plotFolder)
                    ScanFolderForTools(plotFolder)
                end
                child.ChildAdded:Connect(function(pf)
                    task.wait(0.1)
                    SetupFolderConnection(pf)
                    ScanFolderForTools(pf)
                end)
            end
        end
    end)

    -- レインボーアニメーション
    task.spawn(function()
        while true do
            task.wait(0.1)
            if not ToolESP.enabled then continue end
            local i = 0
            for model, high in pairs(ToolESP.highlights) do
                if model and model.Parent and high and high.Parent then
                    local color = GetRainbowColor(i * 0.2)
                    high.FillColor = color
                    high.OutlineColor = color
                    i = i + 1
                elseif high then
                    -- 消えたモデルの掃除
                    pcall(function() high:Destroy() end)
                    ToolESP.highlights[model] = nil
                end
            end
        end
    end)

    -- UI トグル
    AntiTab:AddToggle({
        Name = "AntiKick / Tool Rainbow ESP",
        Default = true,
        Callback = function(Value)
            ToolESP.enabled = Value
            if Value then
                ScanAllFolders()
            else
                ClearAllHighlights()
            end
        end
    })
end

-- Break Pcld
AntiTab:AddToggle({Name = "Break Pcld", Default = false,
    Callback = function(Value)
        local hkExpectDeath = false
        local hkSalmonList = {}
        hkSalmonList[plr.UserId] = true
        local function hkApplySalmon(c)
            if not c then return end
            local newHum = c:WaitForChild("Humanoid", 5)
            if not newHum then return end
            if hkSalmonList[plr.UserId] and not hkExpectDeath then
                hkExpectDeath = true
                newHum:ChangeState(Enum.HumanoidStateType.Dead)
            else
                hkExpectDeath = false
            end
        end
        plr.CharacterAdded:Connect(function(c) hkApplySalmon(c) end)
        hkSalmonList[plr.UserId] = Value and true or nil
        if Value then
            hkExpectDeath = false
            local c = plr.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h then h.Health = 0 end
        end
    end})

-- ============================================================
-- Anti-Kick (ツール選択式) — T.I.V.z から移植
-- 刀1 / 刀2 / シャベル(ToolDiggingForkRusty) は除外
-- ============================================================
do
    local TOOL_CONFIGS = {
        ToolPickaxe = {
            REAL_NAME = "ToolPickaxe",
            POS_X = -0.5, POS_Y = 0.5, POS_Z = 0.8,
            ANGLE_Z = 90, FLAT_Y = 90,
            OFFSET_X = 220, OFFSET_Y = 0, OFFSET_Z = 0,
        },
        ToolCleaver = {
            REAL_NAME = "ToolCleaver",
            POS_X = 0, POS_Y = -0.5, POS_Z = 0.8,
            ANGLE_Z = 90, FLAT_Y = 90,
            OFFSET_X = 230, OFFSET_Y = 0, OFFSET_Z = 0,
        },
        ToolCleaver2 = {
            REAL_NAME = "ToolCleaver",
            POS_X = -1, POS_Y = -1.7, POS_Z = 0.5,
            ANGLE_Z = 90, FLAT_Y = 361,
            OFFSET_X = 195, OFFSET_Y = 0, OFFSET_Z = 0,
        },
        ToolPencil = {
            REAL_NAME = "ToolPencil",
            POS_X = 0, POS_Y = -1, POS_Z = -0.2,
            ANGLE_Z = 90, FLAT_Y = -180,
            OFFSET_X = 0, OFFSET_Y = 0, OFFSET_Z = 0,
        },
        NinjaKunai = {
            REAL_NAME = "NinjaKunai",
            POS_X = 0, POS_Y = -1, POS_Z = 0.2,
            ANGLE_Z = 90, FLAT_Y = 90,
            OFFSET_X = -360, OFFSET_Y = 0, OFFSET_Z = 0,
        },
    }

    local antiKickToolName = "ToolPickaxe"
    local shurikenAntiKickActive = false
    local expandedStickies = {}
    local currentMult = {}

    local function AK_Notify(title, content)
        pcall(function()
            OrionLib:MakeNotification({Name = title, Content = content, Time = 2})
        end)
    end

    local function GetRealName(key, cfg)
        return (cfg and cfg.REAL_NAME) or key
    end

    local function BuildAttachAngle(cfg)
        return CFrame.Angles(0, math.rad(cfg.FLAT_Y), 0)
            * CFrame.Angles(math.rad(cfg.OFFSET_X), math.rad(cfg.OFFSET_Y), math.rad(cfg.OFFSET_Z))
            * CFrame.Angles(0, 0, math.rad(cfg.ANGLE_Z))
    end

    local function AK_CheckForHome()
        local plotItems = workspace:FindFirstChild("PlotItems")
        if not plotItems then return false end
        local pip = plotItems:FindFirstChild("PlayersInPlots")
        if not pip or not pip:FindFirstChild(plr.Name) then return false end
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return false end
        for _, v in pairs(plots:GetChildren()) do
            local sign = v:FindFirstChild("PlotSign")
            local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
            if owners then
                for _, b in pairs(owners:GetChildren()) do
                    if b.Value == plr.Name then
                        local folder = plotItems:FindFirstChild(v.Name)
                        if folder then return true, folder end
                    end
                end
            end
        end
        return false
    end

    local function AK_getHRP()
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            return plr.Character.HumanoidRootPart
        else
            local character = plr.CharacterAdded:Wait()
            return character:WaitForChild("HumanoidRootPart")
        end
    end

    local function ExpandSticky(tool, cfg, mult)
        if not cfg.EXPAND_STICKY then return end
        local sp = tool:FindFirstChild("StickyPart")
        if not sp then return end
        if expandedStickies[sp] then return end

        expandedStickies[sp] = {
            size = sp.Size,
            transparency = sp.Transparency,
            cantouch = sp.CanTouch,
            cancollide = sp.CanCollide,
            canquery = sp.CanQuery,
        }

        pcall(function()
            sp.Size = Vector3.new(sp.Size.X, sp.Size.Y * mult, sp.Size.Z)
        end)
        pcall(function() sp.CanTouch = true end)
        pcall(function() sp.CanCollide = false end)
        pcall(function() sp.CanQuery = true end)
    end

    local function RestoreSticky(tool)
        local sp = tool:FindFirstChild("StickyPart")
        if not sp then return end
        local data = expandedStickies[sp]
        if not data then return end

        pcall(function() sp.Size = data.size end)
        pcall(function() sp.Transparency = data.transparency end)
        pcall(function() sp.CanTouch = data.cantouch end)
        pcall(function() sp.CanCollide = data.cancollide end)
        pcall(function() sp.CanQuery = data.canquery end)

        expandedStickies[sp] = nil
    end

    local function ClearKunai()
        local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
        if inv then
            for _, v in pairs(inv:GetChildren()) do
                if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                    RestoreSticky(v)
                end
            end
        end
        if inv and DestroyToy then
            for _, v in pairs(inv:GetChildren()) do
                if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                    pcall(function() DestroyToy:FireServer(v) end)
                end
            end
        end
    end

    local function startAntiKick(toolKey)
        shurikenAntiKickActive = true

        local setOwner = SetNetworkOwner
        local stickyEvent = StickyEvent
        local spawnRemote = SpawnToyRemote
        local canSpawn = CanSpawnToy

        if not stickyEvent or not spawnRemote then
            AK_Notify("Anti Kick", "Remote が見つかりません")
            shurikenAntiKickActive = false
            return
        end

        local cfg = TOOL_CONFIGS[toolKey]
        if not cfg then
            AK_Notify("Anti Kick", "ツール設定が見つかりません")
            shurikenAntiKickActive = false
            return
        end
        local realName = GetRealName(toolKey, cfg)

        local attachOffset = CFrame.new(cfg.POS_X, cfg.POS_Y, cfg.POS_Z)
        local attachAngle = BuildAttachAngle(cfg)
        local attachCombined = attachOffset * attachAngle

        currentMult[toolKey] = cfg.STICKY_SIZE_MULT_BASE or 0.5

        local function StickTool(tool)
            if not tool or not tool:FindFirstChild("StickyPart") then return end
            local currentHRP = AK_getHRP()
            if not currentHRP then return end
            local firePart = currentHRP:FindFirstChild("FirePlayerPart") or currentHRP:WaitForChild("FirePlayerPart", 5)
            if not firePart then return end

            for _, obj in pairs(tool:GetChildren()) do
                if obj:IsA("BasePart") then
                    obj.CanTouch = false
                    obj.CanCollide = false
                    obj.CanQuery = false
                    obj.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    obj.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end

            if tool:FindFirstChild("SoundPart") and setOwner then
                if not tool.SoundPart:FindFirstChild("PartOwner") or tool.SoundPart.PartOwner.Value ~= plr.Name then
                    pcall(function() setOwner:FireServer(tool.SoundPart, tool.SoundPart.CFrame) end)
                end
            end

            local mult = currentMult[toolKey] or 0.5
            ExpandSticky(tool, cfg, mult)

            local targetCFrame = firePart.CFrame * attachCombined
            pcall(function() tool:PivotTo(targetCFrame) end)
            pcall(function() stickyEvent:FireServer(tool.StickyPart, firePart, attachCombined) end)
        end

        local function SpawnToyAK(name)
            if canSpawn then
                local t = tick()
                while not canSpawn.Value do
                    if not shurikenAntiKickActive or tick() - t > 5 then return nil end
                    task.wait(0.1)
                end
            end
            local currentHRP = AK_getHRP()
            if currentHRP then
                task.spawn(function()
                    pcall(function()
                        spawnRemote:InvokeServer(name, currentHRP.CFrame * CFrame.new(0, 2, 2), Vector3.new(0, 0, 0))
                    end)
                end)
            end
            local boolik, house = AK_CheckForHome()
            local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            local plotItems = workspace:FindFirstChild("PlotItems")
            local pip = plotItems and plotItems:FindFirstChild("PlayersInPlots")
            if boolik and house then
                return house:WaitForChild(name, 2)
            elseif (not pip or not pip:FindFirstChild(plr.Name)) and inv then
                return inv:WaitForChild(name, 2)
            end
            return nil
        end

        task.spawn(function()
            while shurikenAntiKickActive do
                task.wait(0.05)
                if not plr.Character or not plr.Character:FindFirstChild("Humanoid") or plr.Character.Humanoid.Health <= 0 then continue end

                local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                local tool = inv and (inv:FindFirstChild("AntiKick") or inv:FindFirstChild(realName))

                local plotItems = workspace:FindFirstChild("PlotItems")
                local pip = plotItems and plotItems:FindFirstChild("PlayersInPlots")
                if pip and pip:FindFirstChild(plr.Name) then
                    local boolik, house = AK_CheckForHome()
                    if boolik and house and workspace.Plots:FindFirstChild(house.Name) then
                        local sign = workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                        local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                        local timeOk = false
                        if owners then
                            -- ThisPlotsOwners.Value.TimeRemainingNum は環境により構造が違うことがある
                            pcall(function()
                                local ov = owners.Value
                                if ov and ov:FindFirstChild("TimeRemainingNum") and ov.TimeRemainingNum.Value > 89 then
                                    timeOk = true
                                end
                            end)
                            -- フォールバック: オーナー確認できたらOK
                            if not timeOk then
                                for _, b in pairs(owners:GetChildren()) do
                                    if b.Value == plr.Name then timeOk = true break end
                                end
                            end
                        end
                        if timeOk then
                            if not tool then tool = SpawnToyAK(realName) end
                            if tool == nil then continue end
                            tool.Name = "AntiKick"
                            StickTool(tool)
                        end
                    end
                end

                if not tool then
                    if pip and pip:FindFirstChild(plr.Name) then continue end
                    tool = SpawnToyAK(realName)
                    if tool == nil then continue end
                    tool.Name = "AntiKick"
                end

                if tool and tool:FindFirstChild("StickyPart") then
                    local isWelded = tool.StickyPart:FindFirstChild("StickyWeld") and tool.StickyPart.StickyWeld.Part1 ~= nil
                    if not isWelded and tool.StickyPart.CanTouch == true then
                        local step = cfg.STICKY_SIZE_MULT_STEP or 0.5
                        local maxM = cfg.STICKY_SIZE_MULT_MAX or 20
                        if cfg.EXPAND_STICKY and currentMult[toolKey] < maxM then
                            currentMult[toolKey] = currentMult[toolKey] + step
                            RestoreSticky(tool)
                        end

                        StickTool(tool)
                        tool.Name = "AntiKick"
                        task.wait(0.15)
                    elseif isWelded then
                        RestoreSticky(tool)
                        currentMult[toolKey] = cfg.STICKY_SIZE_MULT_BASE or 0.5
                    end
                    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        if (plr.Character.HumanoidRootPart.Position - tool.StickyPart.Position).Magnitude >= 20 then
                            ClearKunai()
                        end
                    end
                end
            end
            ClearKunai()
        end)
    end

    local function stopAntiKick()
        shurikenAntiKickActive = false
        ClearKunai()
    end

    AntiTab:AddSection({ Name = "▼ Anti-Kick (ツール選択)" })

    AntiTab:AddDropdown({
        Name = "使うツール",
        Default = "ToolPickaxe",
        Options = { "ToolPickaxe", "ToolCleaver", "ToolCleaver2", "ToolPencil", "NinjaKunai" },
        Callback = function(Value)
            antiKickToolName = Value
            if shurikenAntiKickActive then
                stopAntiKick()
                task.wait(0.2)
                startAntiKick(antiKickToolName)
            end
        end
    })

    AntiTab:AddToggle({
        Name = "Anti Kick（自分・ツール選択）",
        Default = false,
        Callback = function(Value)
            if Value then
                startAntiKick(antiKickToolName)
                AK_Notify("Anti Kick", "有効: " .. tostring(antiKickToolName))
            else
                stopAntiKick()
                AK_Notify("Anti Kick", "無効")
            end
        end
    })
end


-- Anti-Kick [ITEM]
local SelectedToy = "SpookyCandle1"
AntiTab:AddDropdown({Name = "anti kick item",
    Options = (function()
        local list = { ["Japanese Lantern"]="JapaneseLantern", ["Spray Can"]="SprayCanWD", ["Spooky Candle"]="SpookyCandle1" }
        local v = {}
        for k,_ in pairs(list) do table.insert(v,k) end
        table.sort(v) return v
    end)(),
    Default = "Spooky Candle",
    Callback = function(Value)
        local t = { ["Japanese Lantern"]="JapaneseLantern", ["Spray Can"]="SprayCanWD", ["Spooky Candle"]="SpookyCandle1" }
        SelectedToy = t[Value]
    end})

AntiTab:AddToggle({Name = "Anti-Kick [ITEM]", Default = false,
    Callback = function(Val)
        KickCfg.kickitemToggle = Val
        if Val then
            task.spawn(function()
                local Item, SoundPart
                while KickCfg.kickitemToggle and task.wait() do
                    local c = plr.Character
                    local hrp2 = c and c:FindFirstChild("HumanoidRootPart")
                    local hum2 = c and c:FindFirstChild("Humanoid")
                    local inPlot = plr:FindFirstChild("InPlot")
                    local invF = workspace:FindFirstChild(plr.Name.."SpawnedInToys")
                    if not hrp2 or not hum2 or hum2.Health <= 0 or not invF then continue end
                    if inPlot and inPlot.Value then continue end
                    if not KickCfg.kickitemPCLD and not KickCfg.kickitemPCLDcon then
                        if KickCfg.kickitemPCLDcon then KickCfg.kickitemPCLDcon:Disconnect() end
                        KickCfg.kickitemPCLD = nil
                        KickCfg.kickitemPCLDcon = RunService.Heartbeat:Connect(function()
                            if KickCfg.kickitemPCLD or not hrp2 or not hrp2.Parent then
                                if KickCfg.kickitemPCLDcon then KickCfg.kickitemPCLDcon:Disconnect() KickCfg.kickitemPCLDcon = nil end
                                return
                            end
                            for _, v in pairs(workspace:GetChildren()) do
                                if v.Name == "PlayerCharacterLocationDetector" and v:IsA("BasePart") then
                                    if (v.Position - hrp2.Position).Magnitude <= 2 then
                                        KickCfg.kickitemPCLD = v
                                        break
                                    end
                                end
                            end
                        end)
                    end
                    Item = invF:FindFirstChild("AntiKickItem")
                    SoundPart = Item and Item:FindFirstChild("Hitbox")
                    if not Item or not SoundPart then
                        for _,v in pairs(invF:GetChildren()) do
                            if v.Name == "AntiKickItem" then pcall(function() DestroyToy:FireServer(v) end) end
                        end
                        local ToyName = SelectedToy
                        local toyInv = workspace:FindFirstChild(plr.Name.."SpawnedInToys")
                        if InPlot and InPlot.Value and InOwnedPlot and not InOwnedPlot.Value then InPlot:GetPropertyChangedSignal("Value"):Wait() end
                        if CanSpawnToy and not CanSpawnToy.Value then CanSpawnToy:GetPropertyChangedSignal("Value"):Wait() end
                        local curHrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if not curHrp then Item = nil
                        else
                            local SpawnCF = (KickCfg.kickitemPCLD or curHrp).CFrame * CFrame.new(0, 14, 20)
                            local homeContainer = nil
                            local plotItems = workspace:FindFirstChild("PlotItems")
                            local plots = workspace:FindFirstChild("Plots")
                            if plots and plotItems then
                                for i = 1, 5 do
                                    local Plot = plots:FindFirstChild("Plot"..i)
                                    if Plot then
                                        local sign = Plot:FindFirstChild("PlotSign")
                                        local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                                        if owners then
                                            for _,v in pairs(owners:GetChildren()) do
                                                if v.Value == plr.Name then
                                                    homeContainer = plotItems:FindFirstChild("Plot"..i)
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    if homeContainer then break end
                                end
                            end
                            local Container = (InOwnedPlot and InOwnedPlot.Value) and homeContainer or toyInv
                            if not Container then Item = nil
                            else
                                local spawned = nil
                                local conn
                                conn = Container.ChildAdded:Connect(function(child)
                                    if child.Name == ToyName then spawned = child end
                                end)
                                task.spawn(function()
                                    pcall(function() SpawnToyRemote:InvokeServer(ToyName, SpawnCF, Vector3.zero) end)
                                end)
                                local st = tick()
                                repeat task.wait() until spawned or (tick() - st) > 2.5
                                if conn then conn:Disconnect() end
                                Item = spawned
                            end
                        end
                        if not Item then continue end
                        SoundPart = Item and FWD(Item, "Hitbox", 0.5)
                        if SoundPart then SetNetworkOwner:FireServer(SoundPart, SoundPart.CFrame) end
                        for _,v in pairs(Item:GetChildren()) do
                            if v:IsA("BasePart") then
                                v.CanCollide = false
                                v.Transparency = 0.8
                                v.Color = Color3.fromRGB(0, 255, 255)
                            end
                        end
                        Item.Name = "AntiKickItem"
                    end
                    local isNotOwner = false
                    if SoundPart then
                        local po = SoundPart:FindFirstChild("PartOwner")
                        if not (po and po.Value == plr.Name) then isNotOwner = true end
                    end
                    if SoundPart and isNotOwner then sno(SoundPart) end
                    local targetPart = KickCfg.kickitemPCLD or hrp2:FindFirstChild("FirePlayerPart") or hrp2
                    if SoundPart and targetPart then
                        SoundPart.CFrame = targetPart.CFrame
                        SoundPart.AssemblyLinearVelocity = Vector3.zero
                        SoundPart.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end)
        else
            if KickCfg.kickitemPCLDcon then KickCfg.kickitemPCLDcon:Disconnect() KickCfg.kickitemPCLDcon = nil end
            KickCfg.kickitemPCLD = nil
            task.spawn(function()
                local invF = workspace:FindFirstChild(plr.Name.."SpawnedInToys")
                if invF and DestroyToy then
                    for _,v in pairs(invF:GetChildren()) do
                        if v.Name == "AntiKickItem" then pcall(function() DestroyToy:FireServer(v) end) end
                    end
                end
            end)
        end
    end})

-- Anti-Kick (NinjaShuriken 貼り付け型)
AntiTab:AddToggle({Name = "Anti-Kick", Default = false,
    Callback = function(Value)
        KickCfg.AntikickT = Value
        if Value then
            task.spawn(function()
                while KickCfg.AntikickT do
                    task.wait(0.005)
                    if not plr.Character or not plr.Character:FindFirstChild("Humanoid") or plr.Character.Humanoid.Health <= 0 then continue end
                    local isHome = false
                    local homeFolder = nil
                    if workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                        for _, v in pairs(workspace.Plots:GetChildren()) do
                            local sign = v:FindFirstChild("PlotSign")
                            local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                            if owners then
                                for _, b in pairs(owners:GetChildren()) do
                                    if b.Value == plr.Name then
                                        local folder = workspace.PlotItems:FindFirstChild(v.Name)
                                        if folder then isHome = true homeFolder = folder break end
                                    end
                                end
                            end
                            if isHome then break end
                        end
                    end
                    local invF = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    local kunai = invF and invF:FindFirstChild("NinjaShuriken")
                    if workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                        if isHome and homeFolder and workspace.Plots:FindFirstChild(homeFolder.Name) then
                            local sign = workspace.Plots[homeFolder.Name]:FindFirstChild("PlotSign")
                            if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                                local t = tick()
                                local spawnedTarget = nil
                                while not CanSpawnToy.Value do
                                    if not KickCfg.AntikickT or tick() - t > 5 then break end
                                    task.wait(0.1)
                                end
                                if CanSpawnToy.Value then
                                    local curHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                                    if curHRP then
                                        task.spawn(function() pcall(function() SpawnToyRemote:InvokeServer("NinjaShuriken", curHRP.CFrame * CFrame.new(0, 12, 20), Vector3.zero) end) end)
                                    end
                                    if isHome and homeFolder then spawnedTarget = homeFolder:WaitForChild("NinjaShuriken", 2)
                                    elseif not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) and invF then spawnedTarget = invF:WaitForChild("NinjaShuriken", 2) end
                                end
                                kunai = spawnedTarget
                                if kunai == nil then continue end
                                kunai.Name = "AntiKick"
                                if kunai and kunai:FindFirstChild("StickyPart") then
                                    local curHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                                    if curHRP then
                                        if kunai:FindFirstChild("SoundPart") then
                                            if not kunai.SoundPart:FindFirstChild("PartOwner") or kunai.SoundPart.PartOwner.Value ~= plr.Name then
                                                SetNetworkOwner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame)
                                            end
                                        end
                                        local firePart = curHRP:FindFirstChild("FirePlayerPart") or curHRP:WaitForChild("FirePlayerPart", 5)
                                        if firePart then
                                            StickyEvent:FireServer(kunai.StickyPart, firePart, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)))
                                        end
                                        for _, obj in pairs(kunai:GetChildren()) do
                                            if obj:IsA("BasePart") then
                                                obj.CanTouch = false
                                                obj.CanCollide = false
                                                obj.CanQuery = false
                                                obj.Transparency = 1
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if not kunai then
                        if workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then continue end
                        local t = tick()
                        local spawnedTarget = nil
                        while not CanSpawnToy.Value do
                            if not KickCfg.AntikickT or tick() - t > 5 then break end
                            task.wait(0.1)
                        end
                        if CanSpawnToy.Value then
                            local curHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                            if curHRP then
                                task.spawn(function() pcall(function() SpawnToyRemote:InvokeServer("NinjaShuriken", curHRP.CFrame * CFrame.new(0, 12, 20), Vector3.zero) end) end)
                            end
                            if isHome and homeFolder then spawnedTarget = homeFolder:WaitForChild("NinjaShuriken", 2)
                            elseif not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) and invF then spawnedTarget = invF:WaitForChild("NinjaShuriken", 2) end
                        end
                        kunai = spawnedTarget
                        if kunai == nil then continue end
                        kunai.Name = "AntiKick"
                        if not kunai then continue end
                    end
                    repeat
                        if kunai and kunai:FindFirstChild("StickyPart") and kunai.StickyPart.CanTouch == true then
                            if kunai:FindFirstChild("StickyPart") then
                                local curHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                                if curHRP then
                                    if kunai:FindFirstChild("SoundPart") then
                                        if not kunai.SoundPart:FindFirstChild("PartOwner") or kunai.SoundPart.PartOwner.Value ~= plr.Name then
                                            SetNetworkOwner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame)
                                        end
                                    end
                                    local firePart = curHRP:FindFirstChild("FirePlayerPart") or curHRP:WaitForChild("FirePlayerPart", 5)
                                    if firePart then
                                        StickyEvent:FireServer(kunai.StickyPart, firePart, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)))
                                    end
                                    for _, obj in pairs(kunai:GetChildren()) do
                                        if obj:IsA("BasePart") then
                                            obj.CanTouch = false
                                            obj.CanCollide = false
                                            obj.CanQuery = false
                                            obj.Transparency = 1
                                        end
                                    end
                                end
                            end
                            kunai.Name = "AntiKick"
                        end
                        task.wait(0.3)
                    until not kunai
                        or not KickCfg.AntikickT
                        or not kunai:FindFirstChild("StickyPart")
                        or kunai.StickyPart.CanTouch == false
                        or not plr.Character
                        or not plr.Character:FindFirstChild("HumanoidRootPart")
                        or not kunai:FindFirstChild("StickyPart")
                        or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20
                    if not kunai or not kunai:FindFirstChild("StickyPart")
                        or not plr.Character
                        or not plr.Character:FindFirstChild("HumanoidRootPart")
                        or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20 then
                        local targetInv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                        if targetInv and DestroyToy then
                            for _, v in pairs(targetInv:GetChildren()) do
                                if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                                    pcall(function() DestroyToy:FireServer(v) end)
                                end
                            end
                        end
                    end
                    pcall(function()
                        repeat
                            task.wait(0.05)
                        until not KickCfg.AntikickT
                            or not plr.Character
                            or not plr.Character:FindFirstChild("Humanoid")
                            or not kunai
                            or not kunai:FindFirstChild("StickyPart")
                            or not kunai.StickyPart:FindFirstChild("StickyWeld")
                            or not kunai.StickyPart.StickyWeld.Part1
                        if not kunai
                            or not kunai:FindFirstChild("StickyPart")
                            or (plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health <= 0)
                            or not kunai.StickyPart:FindFirstChild("StickyWeld")
                            or not kunai.StickyPart.StickyWeld.Part1 then
                            local targetInv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                            if targetInv and DestroyToy then
                                for _, v in pairs(targetInv:GetChildren()) do
                                    if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                                        pcall(function() DestroyToy:FireServer(v) end)
                                    end
                                end
                            end
                        end
                    end)
                end
            end)
        else
            KickCfg.AntikickT = false
            local targetInv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            if targetInv and DestroyToy then
                for _, v in pairs(targetInv:GetChildren()) do
                    if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                        pcall(function() DestroyToy:FireServer(v) end)
                    end
                end
            end
        end
    end})

-- Anti-Kick (Pencil) ← lol_private版
AntiTab:AddToggle({Name = "Anti-Kick (Pencil ✏)", Default = false,
    Callback = function(Value)
        KickCfg.Tinko = Value
        if KickCfg.Tinko then
            while KickCfg.Tinko do
                local spawnedFolder = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                while KickCfg.Tinko and spawnedFolder and not spawnedFolder:FindFirstChild("PencilDDD") do
                    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        local existingObjects = {}
                        for _, child in pairs(spawnedFolder:GetChildren()) do existingObjects[child] = true end
                        SpawnToyRemote:InvokeServer("ToolPencil", CFrame.new(plr.Character.HumanoidRootPart.CFrame.Position) + Vector3.new(0, 0, 15), Vector3.new(0, 0, 0))
                        local newPencil = nil
                        local startTime = tick()
                        repeat
                            for _, child in pairs(spawnedFolder:GetChildren()) do
                                if not existingObjects[child] and child.Name == "ToolPencil" then
                                    newPencil = child
                                    break
                                end
                            end
                            task.wait()
                        until newPencil or (tick() - startTime > 2) or not KickCfg.Tinko
                        if newPencil then newPencil.Name = "PencilDDD" end
                    end
                    task.wait()
                end
                if plr.Character then
                    if plr.Character:FindFirstChild("Torso") and plr.Character:FindFirstChild("HumanoidRootPart") and spawnedFolder and spawnedFolder:FindFirstChild("PencilDDD") then
                        local pencil = spawnedFolder.PencilDDD
                        if pencil:FindFirstChild("StickyPart") then
                            if pencil.StickyPart:FindFirstChild("StickyWeld") then
                                if pencil.StickyPart.StickyWeld.Part1 ~= plr.Character.Torso then
                                    local a = pencil.SoundPart.CFrame.Position
                                    local b = plr.Character.HumanoidRootPart.CFrame.Position
                                    local distance = Vector3.new((a.X - b.X) ^ 2, (a.Y - b.Y) ^ 2, (a.Z - b.Z) ^ 2)
                                    if math.sqrt(distance.X + distance.Y + distance.Z) > 20 then
                                        DestroyToy:FireServer(pencil)
                                    else
                                        StickyEvent:FireServer(pencil.StickyPart, plr.Character.Torso, CFrame.new(0, -1, 0) * CFrame.Angles(0, math.pi, 0))
                                        for _, prt in pairs(pencil:GetChildren()) do
                                            if prt.ClassName == "Part" then prt.CanQuery = false end
                                        end
                                        task.wait(0.2)
                                        if plr.Character then
                                            if plr.Character:FindFirstChild("Torso") and plr.Character:FindFirstChild("HumanoidRootPart") and spawnedFolder:FindFirstChild("PencilDDD") then
                                                if pencil:FindFirstChild("StickyPart") then
                                                    if pencil.StickyPart:FindFirstChild("StickyWeld") then
                                                        if pencil.StickyPart.StickyWeld.Part1 ~= plr.Character.Torso then
                                                            if spawnedFolder:FindFirstChild("PencilDDD") then
                                                                if pencil.StickyPart.StickyWeld.Part1 ~= plr.Character.Torso then
                                                                    SetNetworkOwner:FireServer(pencil.SoundPart, pencil.SoundPart.CFrame)
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait()
            end
        else
            local spawnedFolder = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            if spawnedFolder then
                local dddPencil = spawnedFolder:FindFirstChild("PencilDDD")
                if dddPencil then DestroyToy:FireServer(dddPencil) end
            end
        end
    end})

-- Auto-Reset
AntiTab:AddToggle({Name = "Auto-Reset", Default = true,
    Callback = function(Value)
        KickCfg.AntikickResetToggle = Value
        if KickCfg.AntikickResetToggle then
            KickCfg.Contuuti['GameNotify'] = GameCorrectionsNotify.OnClientEvent:Connect(function(actionType)
                if actionType == "Flying" then
                    Struggle:FireServer(plr)
                    local c = plr.Character
                    local h = c and c:FindFirstChild("Humanoid")
                    if h then h.Health = 0 end
                end
            end)
        else
            for connectionName, connection in KickCfg.Contuuti do
                if connectionName:find("GameNotify") then
                    connection:Disconnect()
                    connection = nil
                end
            end
        end
    end})

-- Auto-Leave
AntiTab:AddToggle({Name = "Auto-Leave", Default = false,
    Callback = function(Value)
        KickCfg.AntikickLeaveToggle = Value
        if KickCfg.AntikickLeaveToggle then
            KickCfg.Contuuti['GameLeaveNotify'] = GameCorrectionsNotify.OnClientEvent:Connect(function(actionType)
                if actionType == "Flying" then
                    plr:Kick("Disconnected to prevent ban. [by: tanpopo_private_lol]")
                end
            end)
        else
            for connectionName, connection in KickCfg.Contuuti do
                if connectionName:find("GameLeaveNotify") then
                    connection:Disconnect()
                    connection = nil
                end
            end
        end
    end})

-- Auto-Enable
AntiTab:AddToggle({Name = "Auto-Enable", Default = true,
    Callback = function(Value)
        KickCfg.AutoTurnOnAntiKick = Value
        if KickCfg.AutoTurnOnAntiKick then
            KickCfg.Contuuti['AntiKickAutoOn'] = GameCorrectionsNotify.OnClientEvent:Connect(function(actionType)
                if actionType == "Flying" then
                    if not KickCfg.AntikickT then
                        pcall(function() if Toggles["Anti-Kick"] then Toggles["Anti-Kick"]:Set(true) end end)
                    end
                end
            end)
        else
            if KickCfg.Contuuti['AntiKickAutoOn'] then
                KickCfg.Contuuti['AntiKickAutoOn']:Disconnect()
                KickCfg.Contuuti['AntiKickAutoOn'] = nil
            end
        end
    end})

-- Anti-Input（日本語アイテム選択式）
AntiTab:AddSection({ Name = "▼ Anti-Input（日本語）" })
do
    local ItemMap = {
        -- 食べ物
        ["ピザ（チーズ）"]           = "FoodPizzaCheese",
        ["ピザ（ペパロニ）"]         = "FoodPizzaPepperoni",
        ["コーラ"]                   = "FoodSodaCan",
        ["ハンバーガー"]             = "FoodHamburger",
        ["ホットドッグ"]             = "FoodHotdog",
        ["マヨネーズ"]               = "FoodMayonnaise",
        ["肉"]                       = "FoodMeatStick",
        ["毒キノコ"]                 = "FoodMushroomPoison",
        ["ピンクケーキ"]             = "FoodCakePink",
        ["ココナッツ"]               = "FoodCoconut",
        ["目玉焼き"]                 = "FoodDippyEgg",
        ["ドーナツ"]                 = "FoodDonut",
        ["フライドポテト"]           = "FoodFrenchFries",
        ["バナナ"]                   = "FoodBanana",
        ["パン"]                     = "FoodBread",
        ["ブロッコリー"]             = "FoodBroccoli",
        -- カップ
        ["マグカップ（茶）"]         = "CupMugBrown",
        ["マグカップ（白）"]         = "CupMugWhite",
        -- うんち系
        ["うんち"]                   = "PoopPile",
        ["キラキラうんち"]           = "PoopPileSparkle",
        -- 楽器（鍵盤）
        ["キーボード"]               = "InstrumentPianoKeyboard",
        ["メロディカ"]               = "InstrumentPianoMelodica",
        -- 楽器（声）
        ["マイク"]                   = "InstrumentVoiceMicrophone",
        -- 楽器（木管）
        ["鳥の笛"]                   = "InstrumentWoodwindOcarina",
        ["サックス"]                 = "InstrumentWoodwindSaxophone",
        -- 楽器（ギター系）
        ["アコースティックギター"]   = "InstrumentGuitarAcoustic",
        ["バンジョー"]               = "InstrumentGuitarBanjo",
        ["ライア"]                   = "InstrumentGuitarLyre",
        ["パイナップルギター"]       = "InstrumentGuitarUkulele",
        ["バイオリン"]               = "InstrumentGuitarViolin",
        -- 楽器（金管）
        ["ラッパ"]                   = "InstrumentBrassBugle",
        ["トランペット"]             = "InstrumentBrassTrumpet",
        ["笛"]                       = "InstrumentBrassVuvuzela",
        -- 楽器（ドラム）
        ["2個の太鼓"]                = "InstrumentDrumBongos",
        ["スネアドラム"]             = "InstrumentDrumSnare",
    }

    local DisplayItems = {}
    for jpName, _ in pairs(ItemMap) do
        table.insert(DisplayItems, jpName)
    end
    table.sort(DisplayItems)

    local AIConfig = {
        targetToy = "InstrumentGuitarBanjo",
        targetToyJP = "バンジョー",
        loopActive = false,
        runLoop = nil,
        respawnHandler = nil,
    }

    local function AI_Notify(title, content)
        pcall(function()
            OrionLib:MakeNotification({Name = title, Content = content, Time = 2})
        end)
    end

    local function destroyExistingToy()
        local folder = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
        if not folder then return end
        for _, v in pairs(folder:GetChildren()) do
            if v.Name == AIConfig.targetToy then
                if DestroyToy then
                    pcall(function() DestroyToy:FireServer(v) end)
                end
            end
        end
    end

    local function startAntiInput()
        if AIConfig.loopActive then return end
        destroyExistingToy()
        AIConfig.loopActive = true

        AIConfig.runLoop = RunService.Heartbeat:Connect(function()
            if not AIConfig.loopActive then return end

            local toyFolder = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            if not toyFolder then return end

            local toy = toyFolder:FindFirstChild(AIConfig.targetToy)

            -- アイテム生成
            if not toy then
                if InPlot and InPlot.Value and InOwnedPlot and not InOwnedPlot.Value then return end
                if CanSpawnToy and not CanSpawnToy.Value then return end

                local char = plr.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local spawnCFrame = root.CFrame * CFrame.new(0, 14, 20)

                if SpawnToyRemote then
                    pcall(function()
                        SpawnToyRemote:InvokeServer(AIConfig.targetToy, spawnCFrame, Vector3.new(0, 90, 0))
                    end)
                end

                for _ = 1, 30 do
                    toy = toyFolder:FindFirstChild(AIConfig.targetToy)
                    if toy then break end
                    task.wait(0.02)
                end
            end

            if not toy then return end

            -- 掴んで落とす処理
            local char = plr.Character
            local head = char and char:FindFirstChild("Head")
            if not head then return end

            local holdPart = toy:FindFirstChild("HoldPart")
            if not holdPart then return end

            local holdRemote = holdPart:FindFirstChild("HoldItemRemoteFunction")
            local dropRemote = holdPart:FindFirstChild("DropItemRemoteFunction")
            if not (holdRemote and dropRemote) then return end

            local dropPosition = head.CFrame * CFrame.new(0, 3, 0)

            task.spawn(function()
                pcall(function()
                    holdRemote:InvokeServer(toy, char)
                    dropRemote:InvokeServer(toy, dropPosition, dropPosition)
                end)
            end)
        end)

        -- リスポーン時の再接続
        AIConfig.respawnHandler = plr.CharacterAdded:Connect(function()
            if not AIConfig.loopActive then return end
            task.wait(0.5)
            AIConfig.loopActive = false
            if AIConfig.runLoop then AIConfig.runLoop:Disconnect() AIConfig.runLoop = nil end
            destroyExistingToy()
            task.wait(0.2)
            startAntiInput()
        end)
    end

    local function stopAntiInput()
        AIConfig.loopActive = false
        if AIConfig.runLoop then AIConfig.runLoop:Disconnect() AIConfig.runLoop = nil end
        if AIConfig.respawnHandler then AIConfig.respawnHandler:Disconnect() AIConfig.respawnHandler = nil end
        destroyExistingToy()
    end

    AntiTab:AddDropdown({
        Name = "アイテムを選択",
        Default = "バンジョー",
        Options = DisplayItems,
        Callback = function(Value)
            AIConfig.targetToyJP = Value
            AIConfig.targetToy = ItemMap[Value] or "InstrumentGuitarBanjo"
            if AIConfig.loopActive then
                stopAntiInput()
                task.wait(0.1)
                startAntiInput()
            end
        end
    })

    AntiTab:AddToggle({
        Name = "アンチインプットを有効化",
        Default = false,
        Callback = function(Value)
            if Value then
                startAntiInput()
                AI_Notify("アンチインプット", "有効化: " .. AIConfig.targetToyJP)
            else
                stopAntiInput()
                AI_Notify("アンチインプット", "無効化しました")
            end
        end
    })

    AntiTab:AddButton({
        Name = "現在のアイテムを削除",
        Callback = function()
            destroyExistingToy()
            AI_Notify("アンチインプット", "アイテムを削除しました")
        end
    })
end



-- ============================================================
-- Back Stab (統合選択式)
-- ToolPickaxe / NinjaKatana をドロップダウンで選択
-- ============================================================
do
    local TOOL_CONFIGS = {
        ToolPickaxe = {
            POS_X = 0.5,
            POS_Y = -0.5,
            POS_Z = 0.8,
            ANGLE_Z = 90,
            FLAT_Y  = 90,
            OFFSET_X = 45,
            OFFSET_Y = 0,
            OFFSET_Z = 0,
        },
        NinjaKatana = {
            POS_X = 0,
            POS_Y = -0.5,
            POS_Z = 0.8,
            ANGLE_Z = 90,
            FLAT_Y  = 90,
            OFFSET_X = 25,
            OFFSET_Y = 0,
            OFFSET_Z = 0,
        },
    }

    local currentToolName = "ToolPickaxe"
    local checkInterval = 0.3
    local autoRestore = false
    local currentTool = nil

    local function BS_Notify(title, content)
        pcall(function()
            OrionLib:MakeNotification({Name = title, Content = content, Time = 2})
        end)
    end

    local function BS_GetTorso()
        local char = plr.Character
        if not char then return nil end
        return char:FindFirstChild("Torso")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("HumanoidRootPart")
    end

    local function BS_GetConfig()
        return TOOL_CONFIGS[currentToolName]
    end

    local function BS_BuildAngle()
        local cfg = BS_GetConfig()
        return CFrame.Angles(0, math.rad(cfg.FLAT_Y), 0)
            * CFrame.Angles(math.rad(cfg.OFFSET_X), math.rad(cfg.OFFSET_Y), math.rad(cfg.OFFSET_Z))
            * CFrame.Angles(0, 0, math.rad(cfg.ANGLE_Z))
    end

    local function BS_AttachTool()
        local cfg = BS_GetConfig()
        if not SpawnToyRemote or not StickyEvent then return nil end

        local torso = BS_GetTorso()
        if not torso then return nil end

        if CanSpawnToy then
            local t = tick()
            while not CanSpawnToy.Value do
                if tick() - t > 5 then return nil end
                task.wait(0.1)
            end
        end

        local offset = CFrame.new(cfg.POS_X, cfg.POS_Y, cfg.POS_Z)
        local angle = BS_BuildAngle()
        local spawnCF = torso.CFrame * offset * angle

        pcall(function()
            SpawnToyRemote:InvokeServer(currentToolName, spawnCF, Vector3.new(0, 0, 0))
        end)

        local invFolder = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
        if not invFolder then return nil end

        local tool = invFolder:WaitForChild(currentToolName, 3)
        if not tool then return nil end

        pcall(function() tool:PivotTo(spawnCF) end)

        local stickyPart = tool:FindFirstChild("StickyPart")
        if stickyPart then
            pcall(function()
                StickyEvent:FireServer(stickyPart, torso, offset * angle)
            end)
        end

        return tool
    end

    local function BS_IsAttached(tool)
        if not tool or not tool.Parent then return false end
        local stickyPart = tool:FindFirstChild("StickyPart")
        if not stickyPart then return false end
        local weld = stickyPart:FindFirstChild("StickyWeld")
        if not weld then return false end
        return weld.Part1 ~= nil
    end

    local function BS_ClearTools()
        local invFolder = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
        if invFolder and DestroyToy then
            for _, v in ipairs(invFolder:GetChildren()) do
                if v.Name == "ToolPickaxe" or v.Name == "NinjaKatana" or v.Name == "AntiKick" then
                    pcall(function() DestroyToy:FireServer(v) end)
                end
            end
        end
    end

    AntiTab:AddSection({ Name = "▼ Back Stab" })

    AntiTab:AddDropdown({
        Name = "ツール選択",
        Default = "ToolPickaxe",
        Options = { "ToolPickaxe", "NinjaKatana" },
        Callback = function(Value)
            if autoRestore then
                BS_ClearTools()
                currentTool = nil
                BS_Notify("ツール切替", Value)
            end
            currentToolName = Value
        end
    })

    AntiTab:AddToggle({
        Name = "刺す (Back Stab)",
        Default = false,
        Callback = function(Value)
            autoRestore = Value
            if Value then
                BS_ClearTools()
                task.wait(0.2)
                currentTool = BS_AttachTool()
                if currentTool then
                    BS_Notify("Back Stab", currentToolName .. " を刺しました")
                else
                    BS_Notify("Back Stab", "刺し付けに失敗")
                end

                task.spawn(function()
                    while autoRestore do
                        task.wait(checkInterval)
                        local torso = BS_GetTorso()
                        if not torso then continue end
                        if not BS_IsAttached(currentTool) then
                            BS_ClearTools()
                            task.wait(0.1)
                            currentTool = BS_AttachTool()
                        end
                    end
                end)
            else
                BS_ClearTools()
                currentTool = nil
                BS_Notify("Back Stab", "削除しました")
            end
        end
    })
end

-- ============================================================
-- Plot Break ground タブ
-- ============================================================
local GroundTab = Window:MakeTab({Name = "<font size = \"18\">Plot Break ground</font>", Icon = "rbxassetid://16570630989", PremiumOnly = false})
do
    GroundTab:AddSection({ Name = "プロット破壊" })
    local SPTB = {}; local PBE = false; local PSS = {}
    local function cleanupPS()
        if DestroyToy then for _, s in pairs(PSS) do if s and s.Parent then pcall(function() DestroyToy:FireServer(s) end) end end end
        PSS = {}
    end
    GroundTab:AddDropdown({Name = "プロットを選択", Options = {"プロット1","プロット2","プロット3","プロット4","プロット5"}, Default = "", MultiSelect = true,
        Callback = function(O)
            SPTB = {}
            if type(O) == "table" then for _, p in pairs(O) do table.insert(SPTB, p:gsub("プロット", "Plot")) end end
        end})
    GroundTab:AddToggle({Name = "プロット破壊を実行", Default = false,
        Callback = function(V)
            PBE = V
            if PBE then
                task.spawn(function()
                    local cs = plr:WaitForChild("CanSpawnToy")
                    while PBE do
                        local vp = {}
                        for _, pn in pairs(SPTB) do
                            local tp = workspace.Plots:FindFirstChild(pn)
                            local pa = tp and tp:FindFirstChild("PlotArea")
                            if pa then table.insert(vp, { Name = pn, Area = pa }) end
                        end
                        local rc = #vp
                        if rc == 0 then task.wait(1) continue end
                        local function gh()
                            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then return plr.Character.HumanoidRootPart end
                            local c = plr.CharacterAdded:Wait() return c:WaitForChild("HumanoidRootPart")
                        end
                        local function cfh()
                            if not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then return false end
                            for _, v in pairs(workspace.Plots:GetChildren()) do
                                local s = v:FindFirstChild("PlotSign"); local o = s and s:FindFirstChild("ThisPlotsOwners")
                                if o then for _, b in pairs(o:GetChildren()) do
                                    if b.Value == plr.Name then local f = workspace.PlotItems:FindFirstChild(v.Name); if f then return true, f end end
                                end end
                            end
                            return false
                        end
                        local bk, h = cfh()
                        local i = workspace:FindFirstChild(plr.Name.."SpawnedInToys")
                        local tc = (bk and h) or i
                        local ao = {}
                        for _, s in pairs(PSS) do if s and s.Parent then table.insert(ao, s) end end
                        PSS = ao
                        if #PSS < rc then
                            for j = 1, rc - #PSS do
                                if not PBE then break end
                                local pe = {}
                                if tc then for _, c in pairs(tc:GetChildren()) do if c.Name == "NinjaShuriken" then table.insert(pe, c) end end end
                                local t = tick()
                                while not cs.Value do if not PBE then break end if tick() - t > 3 then break end task.wait(0.01) end
                                if not PBE then break end
                                local ch = gh()
                                if ch and SpawnToyRemote then task.spawn(function() pcall(function() SpawnToyRemote:InvokeServer("NinjaShuriken", ch.CFrame * CFrame.new(0, 2, 8), Vector3.new(0,0,0)) end) end) end
                                local ns = nil
                                if tc then
                                    local ss = tick()
                                    while tick() - ss < 2 do
                                        for _, c in pairs(tc:GetChildren()) do
                                            if c.Name == "NinjaShuriken" and not table.find(pe, c) and not table.find(PSS, c) then ns = c break end
                                        end
                                        if ns then
                                            if SetNetworkOwner then
                                                local sp = ns:FindFirstChild("SoundPart") or ns:WaitForChild("SoundPart", 0.1)
                                                if sp then task.spawn(function() pcall(function() SetNetworkOwner:FireServer(sp, sp.CFrame) end) end) end
                                            end
                                            break
                                        end
                                        task.wait()
                                    end
                                end
                                if ns then
                                    table.insert(PSS, ns)
                                    local tpd = vp[#PSS]
                                    if tpd and ns:FindFirstChild("StickyPart") then
                                        pcall(function() StickyEvent:FireServer(ns.StickyPart, tpd.Area, CFrame.new(9.99999996e+11, 9.99999996e+11, 9.99999996e+11, 1, 0, 0, 0, 1, 0, 0, 0, 1)) end)
                                    end
                                end
                                task.wait(0.05)
                            end
                        end
                        if not PBE then cleanupPS() break end
                        local el = 0
                        while el < 0.5 do if not PBE then cleanupPS() break end task.wait(0.05) el = el + 0.05 end
                    end
                end)
            else cleanupPS() end
        end})
end
do
    GroundTab:AddSection({ Name = "地面・パーツ破壊" })
    local AGB = false; local GSS = {}; local CCG = nil
    local function cleanupGS()
        if DestroyToy then for _, s in pairs(GSS) do if s and s.Parent then pcall(function() DestroyToy:FireServer(s) end) end end end
        GSS = {}
    end
    local function spawnBreak(tp)
        if not tp or tp:IsA("Terrain") then return end
        task.spawn(function()
            local cs = plr:WaitForChild("CanSpawnToy")
            local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if not r then return end
            local function cfh()
                if not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then return false end
                for _, v in pairs(workspace.Plots:GetChildren()) do
                    local s = v:FindFirstChild("PlotSign"); local o = s and s:FindFirstChild("ThisPlotsOwners")
                    if o then for _, b in pairs(o:GetChildren()) do
                        if b.Value == plr.Name then local f = workspace.PlotItems:FindFirstChild(v.Name); if f then return true, f end end
                    end end
                end
                return false
            end
            local bk, h = cfh()
            local i = workspace:FindFirstChild(plr.Name.."SpawnedInToys")
            local tc = (bk and h) or i
            local pe = {}
            if tc then for _, c in pairs(tc:GetChildren()) do if c.Name == "NinjaShuriken" then table.insert(pe, c) end end end
            if cs.Value and SpawnToyRemote then
                pcall(function() SpawnToyRemote:InvokeServer("NinjaShuriken", r.CFrame * CFrame.new(0, 2, 8), Vector3.new(0,0,0)) end)
                local ns = nil
                if tc then
                    local ss = tick()
                    while tick() - ss < 2 do
                        for _, c in pairs(tc:GetChildren()) do if c.Name == "NinjaShuriken" and not table.find(pe, c) then ns = c break end end
                        if ns then
                            if SetNetworkOwner then
                                local sp = ns:FindFirstChild("SoundPart") or ns:WaitForChild("SoundPart", 0.1)
                                if sp then pcall(function() SetNetworkOwner:FireServer(sp, sp.CFrame) end) end
                            end
                            break
                        end
                        task.wait()
                    end
                end
                if ns and ns:FindFirstChild("StickyPart") then
                    table.insert(GSS, ns)
                    pcall(function() StickyEvent:FireServer(ns.StickyPart, tp, CFrame.new(9.99999996e+11, 9.99999996e+11, 9.99999996e+11, 1, 0, 0, 0, 1, 0, 0, 0, 1)) end)
                end
            end
        end)
    end
    GroundTab:AddToggle({Name = "足元の地面判定を消す (自動)", Default = false,
        Callback = function(V)
            AGB = V
            if AGB then
                task.spawn(function()
                    while AGB do
                        local c = plr.Character; local r = c and c:FindFirstChild("HumanoidRootPart")
                        if r then
                            local rp = RaycastParams.new()
                            rp.FilterDescendantsInstances = {c}; rp.FilterType = Enum.RaycastFilterType.Exclude
                            local rr = workspace:Raycast(r.Position, Vector3.new(0, -10, 0), rp)
                            local tp = rr and rr.Instance
                            if tp and tp:IsA("BasePart") and not tp:IsA("Terrain") then spawnBreak(tp) end
                        end
                        task.wait(0.8)
                    end
                end)
            else cleanupGS() end
        end})
    GroundTab:AddToggle({Name = "クリックしたパーツ/地面を消す", Default = false,
        Callback = function(V)
            local m = plr:GetMouse()
            if V then
                CCG = m.Button1Down:Connect(function()
                    local tp = m.Target
                    if tp and tp:IsA("BasePart") and not tp:IsA("Terrain") then spawnBreak(tp) end
                end)
            else
                if CCG then CCG:Disconnect() CCG = nil end
                cleanupGS()
            end
        end})
end

-- ============================================================
-- Mics タブ（Plot Breaker 1-5 + Attach 追加版）
-- ============================================================
local MicsTab = Window:MakeTab({Name = "<font size = \"18\">Mics</font>", Icon = "rbxassetid://7733730381", PremiumOnly = false})
do
    MicsTab:AddButton({Name = "バリア破壊 (Barrier Destroy)",
        Callback = function()
            pcall(function()
                for _, plot in pairs(Workspace:FindFirstChild("Plots"):GetChildren()) do
                    local barrier = plot:FindFirstChild("Barrier")
                    if barrier then barrier:Destroy() end
                end
                OrionLib:MakeNotification({Name = "Success", Content = "すべてのバリアを破壊しました！", Time = 3})
            end)
        end})
    local function getRootV2()
        local c = plr.Character
        return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
    end
    local function spawnToyV2(name, cf)
        local mt = RS:FindFirstChild("MenuToys")
        local sp = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
        if sp then
            pcall(function() sp:InvokeServer(name, cf, Vector3.zero) end)
            local iv = workspace:FindFirstChild(plr.Name.."SpawnedInToys")
            return iv and (iv:FindFirstChild(name) or iv:WaitForChild(name, 3))
        end
    end
    local function destroyToyV2(m)
        local mt = RS:FindFirstChild("MenuToys"); local d = mt and mt:FindFirstChild("DestroyToy")
        if m and d then pcall(function() d:FireServer(m) end) end
    end
    local function setOwnerV2(p)
        local r = getRootV2()
        local ge = RS:FindFirstChild("GrabEvents"); local s = ge and ge:FindFirstChild("SetNetworkOwner")
        if r and s then pcall(function() s:FireServer(p, r.CFrame) end) end
    end
    MicsTab:AddButton({Name = "ハウスバリアーブレイカー V2",
        Callback = function()
            task.spawn(function()
                local root = getRootV2(); if not root then return end
                local pos = root.CFrame
                local toy = spawnToyV2("InstrumentWoodwindOcarina", root.CFrame)
                if not toy then return end
                local hp = toy:FindFirstChild("HoldPart"); local hr = hp and hp:FindFirstChild("HoldRemoteFunction")
                if hr then pcall(function() hr:InvokeServer(toy, plr.Character) end) end
                task.wait(0.05); root.CFrame = CFrame.new(304.06, 25.77, 488.54); task.wait(0.05)
                destroyToyV2(toy); task.wait(0.05); root.CFrame = pos
                local pls = workspace:FindFirstChild("Plots")
                if pls then for _, v in pairs(pls:GetChildren()) do
                    local b = v:FindFirstChild("Barrier")
                    if b then for _, p in pairs(b:GetChildren()) do if p:IsA("BasePart") then p.CanCollide = false end end end
                end end
                task.wait(1)
                local scf = CFrame.new(264.767242, -7.350404, 428.284058, 0.901897, 0, 0.43195, 0, 1, 0, -0.43195, 0, 0.901897)
                local p = spawnToyV2("InstrumentWoodwindOcarina", scf)
                if p then
                    local part = p:FindFirstChild("HoldPart") or p:FindFirstChild("SoundPart") or p:FindFirstChild("Handle") or p.PrimaryPart
                    if part then setOwnerV2(part); task.wait(0.5); part.CFrame = CFrame.new(304, 25, 488); task.wait(0.75) end
                    destroyToyV2(p)
                end
                OrionLib:MakeNotification({Name = "Success", Content = "ハウスバリアーブレイカー V2 完了", Time = 3})
            end)
        end})

    -- Plot Breaker 1~5
    MicsTab:AddSection({ Name = "▼ Plot Breaker" })

    local PB_SetNetworkOwner = nil
    local PB_SpawnToyRemote = nil
    local PB_StickyPartEvent = nil
    for _, v in pairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            if v.Name == "SetNetworkOwner" then PB_SetNetworkOwner = v
            elseif v.Name == "StickyPartEvent" then PB_StickyPartEvent = v end
        elseif v:IsA("RemoteFunction") and v.Name == "SpawnToyRemoteFunction" then PB_SpawnToyRemote = v end
    end
    if not PB_StickyPartEvent then PB_StickyPartEvent = RS:FindFirstChild("PlayerEvents") and RS.PlayerEvents:FindFirstChild("StickyPartEvent") end
    if not PB_SetNetworkOwner then PB_SetNetworkOwner = RS:FindFirstChild("GrabEvents") and RS.GrabEvents:FindFirstChild("SetNetworkOwner") end
    if not PB_SpawnToyRemote then PB_SpawnToyRemote = RS:FindFirstChild("MenuToys") and RS.MenuToys:FindFirstChild("SpawnToyRemoteFunction") end

    local function PB_getHumanoidRootPart(plr_)
        if plr_.Character and plr_.Character:FindFirstChild("HumanoidRootPart") then
            return plr_.Character.HumanoidRootPart
        else
            local c = plr_.CharacterAdded:Wait()
            return c:WaitForChild("HumanoidRootPart")
        end
    end
    local function PB_breakPlot(plotIndex)
        local invFolder = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
        if not invFolder then
            OrionLib:MakeNotification({Name = "Plot Breaker", Content = "インベントリが見つかりません", Time = 3})
            return
        end
        local curHRP = PB_getHumanoidRootPart(plr)
        if not curHRP then return end
        task.spawn(function()
            local shur = nil
            local conn = invFolder.ChildAdded:Connect(function(child)
                if child.Name == "NinjaShuriken" then shur = child conn:Disconnect() end
            end)
            if PB_SpawnToyRemote then
                PB_SpawnToyRemote:InvokeServer("NinjaShuriken", curHRP.CFrame * CFrame.new(5, 8, 20), Vector3.new(0, 0, 0))
            end
            local startTime = tick()
            repeat
                if shur and shur:FindFirstChild("StickyPart") and shur:FindFirstChild("SoundPart") then break end
                task.wait(0.01)
            until tick() - startTime > 0.5
            shur = shur or invFolder:FindFirstChild("NinjaShuriken")
            if shur and PB_SetNetworkOwner and PB_StickyPartEvent then
                local soundPart = shur:FindFirstChild("SoundPart")
                local stickyPart = shur:FindFirstChild("StickyPart")
                if soundPart and stickyPart then
                    for j = 1, 15 do
                        PB_SetNetworkOwner:FireServer(soundPart, soundPart.CFrame)
                        if soundPart:FindFirstChild("PartOwner") and soundPart.PartOwner.Value == plr.Name then break end
                    end
                    for _, obj in pairs(shur:GetChildren()) do
                        if obj:IsA("BasePart") then
                            obj.CanTouch = false
                            obj.CanCollide = false
                            obj.Transparency = 1
                        end
                    end
                    shur.Name = "Noclipped"
                    local plot = workspace.Plots:FindFirstChild("Plot" .. plotIndex)
                    if plot then
                        local plotArea = plot:FindFirstChild("PlotArea")
                        if plotArea then
                            PB_StickyPartEvent:FireServer(stickyPart, plotArea, CFrame.new(1e12, 1e12, 1e12))
                        end
                    end
                end
            end
            task.wait(0.1)
            OrionLib:MakeNotification({Name = "Plot Breaker", Content = "Plot " .. plotIndex .. " を破壊しました！", Time = 3})
        end)
    end
    MicsTab:AddButton({Name = "Break All Plots (1-5)",
        Callback = function()
            local invFolder = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            if not invFolder then
                OrionLib:MakeNotification({Name = "Plot Breaker", Content = "インベントリが見つかりません", Time = 3})
                return
            end
            local curHRP = PB_getHumanoidRootPart(plr)
            if not curHRP then return end
            task.spawn(function()
                for i = 1, 5 do
                    local shur = nil
                    local conn = invFolder.ChildAdded:Connect(function(child)
                        if child.Name == "NinjaShuriken" then shur = child conn:Disconnect() end
                    end)
                    if PB_SpawnToyRemote then
                        PB_SpawnToyRemote:InvokeServer("NinjaShuriken", curHRP.CFrame * CFrame.new(5, 8, 20), Vector3.new(0, 0, 0))
                    end
                    local startTime = tick()
                    repeat
                        if shur and shur:FindFirstChild("StickyPart") and shur:FindFirstChild("SoundPart") then break end
                        task.wait(0.01)
                    until tick() - startTime > 0.5
                    shur = shur or invFolder:FindFirstChild("NinjaShuriken")
                    if shur and PB_SetNetworkOwner and PB_StickyPartEvent then
                        local soundPart = shur:FindFirstChild("SoundPart")
                        local stickyPart = shur:FindFirstChild("StickyPart")
                        if soundPart and stickyPart then
                            for j = 1, 15 do
                                PB_SetNetworkOwner:FireServer(soundPart, soundPart.CFrame)
                                if soundPart:FindFirstChild("PartOwner") and soundPart.PartOwner.Value == plr.Name then break end
                            end
                            for _, obj in pairs(shur:GetChildren()) do
                                if obj:IsA("BasePart") then
                                    obj.CanTouch = false
                                    obj.CanCollide = false
                                    obj.Transparency = 1
                                end
                            end
                            shur.Name = "Noclipped"
                            local plot = workspace.Plots:FindFirstChild("Plot" .. i)
                            if plot then
                                local plotArea = plot:FindFirstChild("PlotArea")
                                if plotArea then
                                    PB_StickyPartEvent:FireServer(stickyPart, plotArea, CFrame.new(1e12, 1e12, 1e12))
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
                OrionLib:MakeNotification({Name = "Plot Breaker", Content = "全てのPlotを破壊しました！", Time = 3})
            end)
        end})
    for i = 1, 5 do
        MicsTab:AddButton({Name = "Break Plot " .. i,
            Callback = function() PB_breakPlot(i) end})
    end

    -- Attach（板張り付き）
    MicsTab:AddSection({ Name = "▼ Attach（板張り付き）" })
    local attachState = {
        attached = false, targetPart = nil, localContactCFrame = nil, rootPart = nil,
        footOffsetY = 2.5, heightOffset = 0, connection = nil, touchConnections = {},
        moveDirection = Vector3.new(0, 0, 0), moveSpeed = 16, autoDetachOnTouch = true,
    }
    local attachToggleRef = nil
    local attachHeightRef = nil
    local function getCharacterParts()
        local c = plr.Character
        if not c or not c.Parent then return false end
        attachState.rootPart = c:FindFirstChild("HumanoidRootPart")
        if not attachState.rootPart then return false end
        local foot = c:FindFirstChild("LeftFoot") or c:FindFirstChild("RightFoot")
        if foot and foot:IsA("BasePart") then
            local diff = (attachState.rootPart.Position - foot.Position).Y
            if diff > 0 then attachState.footOffsetY = diff end
        end
        return true
    end
    local function getContactData()
        local c = plr.Character
        if not c or not attachState.rootPart then return nil end
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = { c }
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        rayParams.IgnoreWater = true
        local origin = attachState.rootPart.Position
        local direction = Vector3.new(0, -1, 0) * 10
        local result = Workspace:Raycast(origin, direction, rayParams)
        if result then
            local hit = result.Instance
            if hit and hit:IsA("BasePart") then
                return { Part = hit, Position = result.Position, Normal = result.Normal }
            end
        end
        return nil
    end
    local function detach()
        if attachState.connection then attachState.connection:Disconnect() attachState.connection = nil end
        attachState.attached = false
        attachState.targetPart = nil
        attachState.localContactCFrame = nil
        attachState.moveDirection = Vector3.new(0, 0, 0)
        if attachToggleRef then attachToggleRef:Set(false) end
        OrionLib:MakeNotification({Title = "Attach", Content = "解除しました", Time = 2})
    end
    local function attachToContact()
        if not getCharacterParts() then return false end
        local data = getContactData()
        if not data then
            OrionLib:MakeNotification({Title = "Attach", Content = "足下に物体がありません", Time = 2})
            return false
        end
        attachState.targetPart = data.Part
        if not attachState.targetPart or not attachState.targetPart.Parent then return false end
        local hitPos = data.Position
        local normal = data.Normal
        local targetPos = hitPos + normal * (attachState.footOffsetY + attachState.heightOffset)
        local currentRot = attachState.rootPart.CFrame - attachState.rootPart.Position
        local rootCF = CFrame.new(targetPos) * currentRot
        attachState.localContactCFrame = attachState.targetPart.CFrame:ToObjectSpace(rootCF)
        if attachState.connection then attachState.connection:Disconnect() end
        attachState.attached = true
        attachState.connection = RunService.Heartbeat:Connect(function(dt)
            if not attachState.attached or not attachState.targetPart or not attachState.targetPart.Parent then
                if attachState.connection then attachState.connection:Disconnect() attachState.connection = nil end
                attachState.attached = false
                return
            end
            if not attachState.rootPart then return end
            local targetCF = attachState.targetPart.CFrame:ToWorldSpace(attachState.localContactCFrame)
            local normalVector = attachState.targetPart.CFrame:ToWorldSpace(CFrame.new(0, 0, 0)).UpVector
            targetCF = targetCF + normalVector * attachState.heightOffset
            if attachState.moveDirection.Magnitude > 0 then
                local camera = workspace.CurrentCamera
                if camera then
                    local forward = camera.CFrame.LookVector
                    forward = Vector3.new(forward.X, 0, forward.Z).Unit
                    local right = camera.CFrame.RightVector
                    right = Vector3.new(right.X, 0, right.Z).Unit
                    local worldMove = (forward * -attachState.moveDirection.Z + right * attachState.moveDirection.X) * attachState.moveSpeed * dt
                    local moveOnPlane = worldMove - (worldMove:Dot(normalVector)) * normalVector
                    targetCF = targetCF + moveOnPlane
                end
            end
            attachState.rootPart.CFrame = targetCF
        end)
        return true
    end
    local function changeHeight(delta)
        attachState.heightOffset = attachState.heightOffset + delta
        if attachHeightRef then attachHeightRef:Set(attachState.heightOffset) end
        if attachState.attached then detach() task.wait(0.05) attachToContact() end
    end
    local function setupTouchDetection()
        local c = plr.Character
        if not c then return end
        for _, conn in ipairs(attachState.touchConnections) do conn:Disconnect() end
        attachState.touchConnections = {}
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then
                local conn = part.Touched:Connect(function(hit)
                    if not attachState.attached then return end
                    if not hit or not hit:IsA("BasePart") then return end
                    if hit:IsDescendantOf(c) then return end
                    local hitParent = hit.Parent
                    while hitParent and hitParent ~= Workspace do
                        if hitParent:IsA("Model") then
                            local hitPlayer = Players:GetPlayerFromCharacter(hitParent)
                            if hitPlayer and hitPlayer ~= plr then
                                if attachState.autoDetachOnTouch then detach() end
                                return
                            end
                        end
                        hitParent = hitParent.Parent
                    end
                end)
                table.insert(attachState.touchConnections, conn)
            end
        end
    end
    UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.W then attachState.moveDirection = attachState.moveDirection + Vector3.new(0, 0, -1) end
        if input.KeyCode == Enum.KeyCode.S then attachState.moveDirection = attachState.moveDirection + Vector3.new(0, 0, 1) end
        if input.KeyCode == Enum.KeyCode.A then attachState.moveDirection = attachState.moveDirection + Vector3.new(-1, 0, 0) end
        if input.KeyCode == Enum.KeyCode.D then attachState.moveDirection = attachState.moveDirection + Vector3.new(1, 0, 0) end
    end)
    UIS.InputEnded:Connect(function(input, gp)
        if input.KeyCode == Enum.KeyCode.W then attachState.moveDirection = attachState.moveDirection - Vector3.new(0, 0, -1) end
        if input.KeyCode == Enum.KeyCode.S then attachState.moveDirection = attachState.moveDirection - Vector3.new(0, 0, 1) end
        if input.KeyCode == Enum.KeyCode.A then attachState.moveDirection = attachState.moveDirection - Vector3.new(-1, 0, 0) end
        if input.KeyCode == Enum.KeyCode.D then attachState.moveDirection = attachState.moveDirection - Vector3.new(1, 0, 0) end
    end)
    attachToggleRef = MicsTab:AddToggle({Name = "アタッチ切替", Default = false,
        Callback = function(v)
            if v then
                local ok = attachToContact()
                if not ok then attachToggleRef:Set(false) end
            else
                if attachState.attached then detach() end
            end
        end})
    MicsTab:AddButton({Name = "アタッチ解除", Callback = function() detach() end})
    MicsTab:AddButton({Name = "高さ +1", Callback = function() changeHeight(1) end})
    MicsTab:AddButton({Name = "高さ -1", Callback = function() changeHeight(-1) end})
    attachHeightRef = MicsTab:AddSlider({Name = "高さオフセット", Min = -20, Max = 20, Default = 0,
        Color = Color3.fromRGB(255, 200, 0),
        Callback = function(v) attachState.heightOffset = v end})
    MicsTab:AddSlider({Name = "移動速度", Min = 1, Max = 100, Default = 16,
        Color = Color3.fromRGB(255, 200, 0),
        Callback = function(v) attachState.moveSpeed = v end})
    MicsTab:AddToggle({Name = "他プレイヤー接触で自動解除", Default = true,
        Callback = function(v) attachState.autoDetachOnTouch = v end})
    MicsTab:AddLabel("📖 足下のパーツに固定します。WASDで固定面を移動できます。")
    plr.CharacterAdded:Connect(function()
        detach()
        attachState.heightOffset = 0
        task.wait(0.3)
        getCharacterParts()
        setupTouchDetection()
    end)
    if plr.Character then
        task.wait(0.3)
        getCharacterParts()
        setupTouchDetection()
    end

    -- Camera
    MicsTab:AddSection({ Name = "▼ Camera" })
    local Camera = workspace.CurrentCamera
    MicsTab:AddToggle({Name = "Third Person", Default = false,
        Callback = function(Value)
            if Value then
                plr.CameraMode = Enum.CameraMode.Classic
                Camera.CameraType = Enum.CameraType.Custom
                Camera.CameraSubject = plr.Character:WaitForChild("Humanoid")
                plr.CameraMaxZoomDistance = 16456456546
                plr.CameraMinZoomDistance = 0.5
            else
                plr.CameraMode = Enum.CameraMode.LockFirstPerson
                Camera.CameraType = Enum.CameraType.Custom
                Camera.CameraSubject = plr.Character:WaitForChild("Humanoid")
                plr.CameraMaxZoomDistance = 0
                plr.CameraMinZoomDistance = 0
            end
        end})
    MicsTab:AddToggle({Name = "Fov", Default = false,
        Callback = function(Value)
            bool.FovToggle = Value
            if bool.FovToggle then Camera.FieldOfView = int.FovValue or 70 else Camera.FieldOfView = 70 end
        end})
    MicsTab:AddSlider({Name = "Fov °", Min = 10, Max = 120, Default = 70, Color = Color3.fromRGB(100, 200, 255),
        Callback = function(Value) int.FovValue = Value if bool.FovToggle then Camera.FieldOfView = Value end end})

    -- Blackhole Texture
    MicsTab:AddSection({ Name = "▼ Blackhole Texture" })
    local CosmicBlackhole = {
        Enabled = false, Active = {}, Connection = nil, Selected = "tanpopo black hole1",
        Options = {
            ["tanpopo black hole1"] = {Id = "rbxassetid://99340233207059", Scale = 1.0},
            ["tanpopo black hole2"] = {Id = "rbxassetid://81101997556973", Scale = 1.0},
            ["tanpopo black hole3"] = {Id = "rbxassetid://108336765562063", Scale = 1.0},
            ["tanpopo black hole4"] = {Id = "rbxassetid://76490441012398", Scale = 1.0},
            ["tanpopo black hole5"] = {Id = "rbxassetid://9528329581", Scale = 1.0},
            ["tanpopo black hole6"] = {Id = "rbxassetid://15601115261", Scale = 1.0},
            ["tanpopo black hole7"] = {Id = "rbxassetid://13481688755", Scale = 1.0},
        },
    }
    local function BH_WipeOriginal(bh)
        if not bh then return end
        for _, desc in ipairs(bh:GetDescendants()) do
            pcall(function()
                if desc:IsA("BasePart") or desc:IsA("MeshPart") or desc:IsA("UnionOperation") then desc.Transparency = 1 desc.CastShadow = false
                elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Smoke") or desc:IsA("Fire") or desc:IsA("Sparkles") then desc.Enabled = false
                elseif desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then desc.Enabled = false
                elseif desc:IsA("Decal") or desc:IsA("Texture") then desc.Transparency = 1
                elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then desc.Enabled = false end
            end)
        end
        pcall(function()
            if bh:IsA("BasePart") then bh.Transparency = 1 end
            if bh:IsA("Model") and bh.PrimaryPart then bh.PrimaryPart.Transparency = 1 end
        end)
    end
    local function BH_RestoreOriginal(bh)
        if not bh then return end
        for _, desc in ipairs(bh:GetDescendants()) do
            pcall(function()
                if desc:IsA("BasePart") or desc:IsA("MeshPart") or desc:IsA("UnionOperation") then desc.Transparency = 0
                elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Smoke") or desc:IsA("Fire") or desc:IsA("Sparkles") then desc.Enabled = true
                elseif desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then desc.Enabled = true
                elseif desc:IsA("Decal") or desc:IsA("Texture") then desc.Transparency = 0
                elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then desc.Enabled = true end
            end)
        end
        pcall(function()
            if bh:IsA("BasePart") then bh.Transparency = 0 end
            if bh:IsA("Model") and bh.PrimaryPart then bh.PrimaryPart.Transparency = 0 end
        end)
    end
    local function BH_Cleanup(bh)
        if not bh then return end
        local data = CosmicBlackhole.Active[bh]
        if not data then return end
        if data.Anim then pcall(function() data.Anim:Disconnect() end) end
        if data.Model then pcall(function() data.Model:Destroy() end) end
        pcall(function() BH_RestoreOriginal(bh) end)
        CosmicBlackhole.Active[bh] = nil
    end
    local function BH_LoadCustomModel(assetId)
        if not assetId then return nil end
        local cleanId = tonumber((assetId:gsub("rbxassetid://", "")))
        if not cleanId then return nil end
        local ok1, res1 = pcall(function() return game:GetObjects(assetId)[1] end)
        if ok1 and res1 then return res1 end
        local ok2, res2 = pcall(function() return InsertService:LoadAsset(cleanId) end)
        if ok2 and res2 then
            local children = res2:GetChildren()
            if #children > 0 then return children[1] end
            return res2
        end
        return nil
    end
    local function BH_Build(bh)
        if not bh or not bh.Parent then return end
        if CosmicBlackhole.Active[bh] then return end
        local hole = bh:FindFirstChild("Hole") or bh:FindFirstChildWhichIsA("BasePart")
        if not hole then return end
        local option = CosmicBlackhole.Options[CosmicBlackhole.Selected]
        if not option then return end
        local model = BH_LoadCustomModel(option.Id)
        if not model then
            OrionLib:MakeNotification({Name = "Blackhole", Content = "アセット読み込み失敗: " .. tostring(option.Id), Time = 4})
            return
        end
        BH_WipeOriginal(bh)
        local pos = hole.Position
        local data = {Time = 0, Hole = hole, Anim = nil, Model = nil, SpinSpeed = 0, TargetSpin = 0.8, Scale = 0, TargetScale = option.Scale, StartTime = tick()}
        model.Parent = bh
        model.Name = "CosmicMesh"
        for _, desc in ipairs(model:GetDescendants()) do
            pcall(function()
                if desc:IsA("AnimationController") or desc:IsA("Animator") or desc:IsA("Animation") then desc:Destroy() end
            end)
        end
        for _, part in ipairs(model:GetDescendants()) do
            pcall(function()
                if part:IsA("BasePart") or part:IsA("MeshPart") then
                    part.Anchored = true part.CanCollide = false part.CastShadow = false part.Size = part.Size * 0.01
                end
                if part:IsA("Smoke") or part:IsA("ParticleEmitter") then
                    local n = part.Name:lower()
                    if n:find("smog") or n:find("fog") or n:find("mist") or n:find("haze") or n:find("cloud") then part:Destroy() end
                end
            end)
        end
        pcall(function()
            if model.PrimaryPart then
                local offset = pos - model.PrimaryPart.Position
                model:SetPrimaryPartCFrame(model.PrimaryPart.CFrame + offset)
            else
                local firstPart = nil
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") then firstPart = part break end
                end
                if firstPart then
                    local offset = pos - firstPart.Position
                    for _, part in ipairs(model:GetDescendants()) do
                        if part:IsA("BasePart") then part.CFrame = part.CFrame + offset end
                    end
                end
            end
        end)
        data.Model = model
        data.Anim = RunService.Heartbeat:Connect(function(dt)
            if not bh or not bh.Parent then BH_Cleanup(bh) return end
            local currentPos = hole.Position
            data.Time = data.Time + dt * data.SpinSpeed
            if data.Model and data.Model.Parent then
                if data.Model:IsA("Model") then                    if data.Model.PrimaryPart then
                        local cf = CFrame.new(currentPos) * CFrame.Angles(0, data.Time, 0)
                        pcall(function() data.Model:SetPrimaryPartCFrame(cf) end)
                    else
                        for _, part in ipairs(data.Model:GetDescendants()) do
                            if part:IsA("BasePart") then
                                pcall(function() part.CFrame = CFrame.new(currentPos) * CFrame.Angles(0, data.Time, 0) end)
                                break
                            end
                        end
                    end
                    for _, part in ipairs(data.Model:GetDescendants()) do
                        if part:IsA("BasePart") or part:IsA("MeshPart") then
                            pcall(function()
                                if not part:GetAttribute("BaseSize") then part:SetAttribute("BaseSize", part.Size / 0.01) end
                                local baseSize = part:GetAttribute("BaseSize")
                                part.Size = baseSize * data.Scale
                            end)
                        end
                    end
                elseif data.Model:IsA("BasePart") then
                    pcall(function()
                        data.Model.CFrame = CFrame.new(currentPos) * CFrame.Angles(0, data.Time, 0)
                        if not data.Model:GetAttribute("BaseSize") then data.Model:SetAttribute("BaseSize", data.Model.Size / 0.01) end
                        data.Model.Size = data.Model:GetAttribute("BaseSize") * data.Scale
                    end)
                end
            end
        end)
        bh.AncestryChanged:Connect(function() if not bh.Parent then BH_Cleanup(bh) end end)
        CosmicBlackhole.Active[bh] = data
    end
    local function BH_StartSystem()
        if CosmicBlackhole.Connection then return end
        CosmicBlackhole.Connection = workspace.ChildAdded:Connect(function(obj)
            if not CosmicBlackhole.Enabled then return end
            if obj.Name:lower():find("blackhole") then task.wait(0.2) BH_Build(obj) end
        end)
    end
    MicsTab:AddDropdown({Name = "Blackhole Model", Default = "tanpopo black hole1",
        Options = {"tanpopo black hole1","tanpopo black hole2","tanpopo black hole3","tanpopo black hole4","tanpopo black hole5","tanpopo black hole6","tanpopo black hole7"},
        Callback = function(val)
            CosmicBlackhole.Selected = val
            if CosmicBlackhole.Enabled then
                for bh, _ in pairs(CosmicBlackhole.Active) do BH_Cleanup(bh) end
                for _, obj in ipairs(workspace:GetChildren()) do
                    if obj.Name:lower():find("blackhole") then BH_Build(obj) end
                end
            end
        end})
    MicsTab:AddToggle({Name = "Enable Custom Blackhole", Default = false,
        Callback = function(val)
            local wasEnabled = CosmicBlackhole.Enabled
            CosmicBlackhole.Enabled = val
            if not val then
                if CosmicBlackhole.Connection then CosmicBlackhole.Connection:Disconnect() CosmicBlackhole.Connection = nil end
                for bh, _ in pairs(CosmicBlackhole.Active) do BH_Cleanup(bh) end
                return
            end
            if not wasEnabled then BH_StartSystem() end
            for bh, _ in pairs(CosmicBlackhole.Active) do BH_Cleanup(bh) end
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name:lower():find("blackhole") then BH_Build(obj) end
            end
        end})

    -- Dance V2
    MicsTab:AddSection({ Name = "▼ Dance V2" })
    OrionOptions.DanceV2Dropdown = MicsTab:AddDropdown({Name = "Select Dance", Options = { "Loading..." }, Default = 1, MultipleSelection = false, Searchable = true,
        Callback = function(selected)
            if selected == "Loading..." or selected == "No dances found" or selected == "" then return end
            Fun.selectedDanceNameV2 = selected
            local raw = Fun.currentDanceRawTableV2[selected]
            if raw then
                local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
                if ok then
                    Fun.activeDanceDataV2 = data
                    if Fun.isDancingV2 and Fun.me.Character then Fun.startHipDanceV2(Fun.me.Character) end
                end
            end
        end})
    OrionOptions.DanceV2Toggle = MicsTab:AddToggle({Name = "Enable Dance V2", Default = false,
        Callback = function(value)
            Fun.isDancingV2 = value
            if value then
                if Fun.activeDanceDataV2 and Fun.me.Character then Fun.startHipDanceV2(Fun.me.Character)
                else
                    OrionLib:MakeNotification({Name = "Error", Content = "No dance selected", Time = 3})
                    if OrionOptions.DanceV2Toggle then OrionOptions.DanceV2Toggle:Set(false) end
                end
            else Fun.stopHipDanceV2(Fun.me.Character) end
        end})
    MicsTab:AddButton({Name = "Refresh Dance List", Callback = function() Fun.refreshDanceV2List() end})
    MicsTab:AddButton({Name = "Stop Dance", Callback = function()
        Fun.isDancingV2 = false
        Fun.stopHipDanceV2(Fun.me.Character)
        if OrionOptions.DanceV2Toggle then OrionOptions.DanceV2Toggle:Set(false) end
    end})

    -- ============================================================
    -- ▼ ココナッツちんこ (Coconut Penis) from pastefy eDa8Y4QS
    -- ============================================================
    MicsTab:AddSection({ Name = "▼ ココナッツちんこ" })
    local CoconutEn = false
    MicsTab:AddToggle({
        Name = "ココナッツちんこ (Coconut Penis)",
        Default = false,
        Callback = function(Value)
            CoconutEn = Value
            _G.En = Value
            if not Value then return end
            task.spawn(function()
                local Me = plr
                local Offsets = {
                    [1] = CFrame.new(-0.45, -1.2, -0.7),
                    [2] = CFrame.new(0.45,  -1.2, -0.7),
                    [3] = CFrame.new(0,     -1,    0.8),
                }
                local Length = 10
                local Coconuts = {}
                while CoconutEn do
                    local Char = Me.Character
                    local Root = Char and Char:FindFirstChild("HumanoidRootPart")
                    if not Root then
                        task.wait(0.1)
                        continue
                    end
                    local inv = workspace:FindFirstChild(Me.Name .. "SpawnedInToys")
                    if not inv then
                        task.wait(0.5)
                        continue
                    end
                    Coconuts = {}
                    for _, toy in pairs(inv:GetChildren()) do
                        if toy.Name == "FoodCoconut" then
                            table.insert(Coconuts, toy)
                        end
                    end
                    if #Coconuts < (Length + 2) then
                        task.spawn(function()
                            pcall(function()
                                SpawnToyRemote:InvokeServer(
                                    "FoodCoconut",
                                    Root.CFrame * CFrame.new(-5, 0, 10),
                                    Vector3.zero
                                )
                            end)
                        end)
                    end
                    for i, Coco in ipairs(Coconuts) do
                        local Part      = Coco:FindFirstChild("SoundPart")
                        local HoldPart  = Coco:FindFirstChild("HoldPart")
                        local Rigid     = HoldPart and HoldPart:FindFirstChild("RigidConstraint")
                        local PartOwner = Part and Part:FindFirstChild("PartOwner")
                        if Part and HoldPart and Rigid then
                            if PartOwner and PartOwner.Value == Me.Name then
                                if i <= 2 then
                                    Part.CFrame = Root.CFrame * Offsets[i] * CFrame.new(Root.Velocity / 100)
                                else
                                    Part.CFrame = Root.CFrame * Offsets[3]
                                        * CFrame.new(Root.Velocity / 100)
                                        * CFrame.new(0, 0, Offsets[3].Z - (i + 0.2))
                                end
                                Part.Velocity = Vector3.zero
                            end
                            if not PartOwner or PartOwner.Value ~= Me.Name then
                                pcall(function()
                                    SetNetworkOwner:FireServer(Part, Part.CFrame)
                                end)
                            end
                            if Rigid.Attachment1 then
                                pcall(function()
                                    DestroyToy:FireServer(Coco)
                                end)
                            end
                            for _, part in pairs(Coco:GetChildren()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
                                    part.CanQuery  = false
                                    if part.Transparency ~= 1 then
                                        part.Transparency = 0
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.01)
                end
            end)
        end,
    })

    -- ============================================================
    -- ▼ ESP (Player / PCLD / Rainbow Corner) from pastefy VEtmZPcU
    -- ============================================================
    MicsTab:AddSection({ Name = "▼ ESP" })

    local ESPConnections = {}
    local PCLD_ESP_CON = nil
    local RainbowConnection = nil
    local ESPBool = { ESPEnabled = false, PCLDESP = false }

    local function RainbowColor(offset)
        local r = math.sin(offset)*0.5+0.5
        local g = math.sin(offset+2.094)*0.5+0.5
        local b = math.sin(offset+4.188)*0.5+0.5
        return Color3.new(math.max(0.25,r), math.max(0.25,g), math.max(0.25,b))
    end

    local function createESP(plr_)
        if plr_ == plr then return end
        local function onAdd(char)
            local Head = char:FindFirstChild("Head")
            if not Head or Head:FindFirstChild("BillboardGui") then return end
            local bg = Instance.new("BillboardGui")
            bg.Adornee = Head; bg.Size = UDim2.new(0,50,0,50); bg.AlwaysOnTop = true
            bg.StudsOffset = Vector3.new(0,3,0); bg.Parent = Head
            local il = Instance.new("ImageLabel")
            il.BackgroundTransparency = 1; il.Size = UDim2.new(0,50,0,50)
            il.Position = UDim2.new(0.5,-25,0,0)
            il.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..plr_.UserId.."&width=420&height=420&format=png"
            il.Parent = bg
            local tl = Instance.new("TextLabel")
            tl.BackgroundTransparency = 1; tl.Size = UDim2.new(1,0,0,32)
            tl.Position = UDim2.new(0,0,1,-32)
            tl.Text = plr_.Name.." ("..plr_.DisplayName..")"
            tl.TextColor3 = Color3.new(1,1,1); tl.TextStrokeTransparency = 0
            tl.TextScaled = true; tl.Font = Enum.Font.GothamBold
            tl.Parent = bg
        end
        if plr_.Character then onAdd(plr_.Character) end
        table.insert(ESPConnections, plr_.CharacterAdded:Connect(onAdd))
    end

    local function clearESP()
        for _, c in ipairs(ESPConnections) do c:Disconnect() end
        ESPConnections = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character:FindFirstChild("Head") then
                local g = p.Character.Head:FindFirstChild("BillboardGui")
                if g then g:Destroy() end
            end
        end
    end

    local function AddPCLD(obj)
        if obj.Name=="PlayerCharacterLocationDetector" and not obj:FindFirstChild("PCLD_ESP") then
            local a = Instance.new("BoxHandleAdornment")
            a.Name="PCLD_ESP"; a.Size=obj.Size; a.AlwaysOnTop=true; a.ZIndex=10
            a.Color3=Color3.fromRGB(255,0,0); a.Transparency=0.8; a.Adornee=obj; a.Parent=obj
            local s = Instance.new("SelectionBox")
            s.Name="PCLD_Edge"; s.Adornee=obj; s.LineThickness=0.04
            s.Color3=Color3.fromRGB(255,0,0); s.SurfaceTransparency=1; s.Transparency=0.45; s.Parent=obj
        end
    end

    local function RemovePCLD(obj)
        if obj.Name=="PlayerCharacterLocationDetector" then
            local e = obj:FindFirstChild("PCLD_ESP"); if e then e:Destroy() end
            local e2 = obj:FindFirstChild("PCLD_Edge"); if e2 then e2:Destroy() end
        end
    end

    local function UpdateRainbow()
        if not ESPBool.PCLDESP then
            if RainbowConnection then RainbowConnection:Disconnect(); RainbowConnection=nil end
            return
        end
        local c = RainbowColor(tick()*2.5)
        for _, v in pairs(Workspace:GetChildren()) do
            if v.Name=="PlayerCharacterLocationDetector" then
                local e = v:FindFirstChild("PCLD_Edge"); if e then e.Color3=c end
                local e2 = v:FindFirstChild("PCLD_ESP"); if e2 then e2.Color3=c end
            end
        end
    end

    MicsTab:AddToggle({
        Name = "プレイヤーESP (Name + Headshot)",
        Default = false,
        Callback = function(v)
            ESPBool.ESPEnabled = v
            if v then
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= plr then createESP(p) end
                end
                if not ESPConnections.NewPlayer then
                    ESPConnections.NewPlayer = Players.PlayerAdded:Connect(function(p)
                        if p ~= plr then createESP(p) end
                    end)
                end
            else
                clearESP()
                if ESPConnections.NewPlayer then ESPConnections.NewPlayer:Disconnect(); ESPConnections.NewPlayer=nil end
            end
        end,
    })

    MicsTab:AddToggle({
        Name = "PCLD ESP (虹色)",
        Default = false,
        Callback = function(v)
            ESPBool.PCLDESP = v
            if v then
                for _, obj in pairs(Workspace:GetChildren()) do AddPCLD(obj) end
                PCLD_ESP_CON = Workspace.ChildAdded:Connect(AddPCLD)
                if not RainbowConnection then RainbowConnection = RunService.Heartbeat:Connect(UpdateRainbow) end
            else
                for _, obj in pairs(Workspace:GetChildren()) do RemovePCLD(obj) end
                if PCLD_ESP_CON then PCLD_ESP_CON:Disconnect(); PCLD_ESP_CON=nil end
                if RainbowConnection then RainbowConnection:Disconnect(); RainbowConnection=nil end
            end
        end,
    })

    -- Rainbow Corner ESP
    do
        local RB_ESP = false
        local rb_espObjects = {}
        local rb_espUpdateConn = nil
        local rb_globalHue = 0
        local rb_pulseTime = 0
        local rb_playerAddedConn = nil
        local rb_playerRemovingConn = nil

        local rb_espGui = Instance.new("ScreenGui")
        rb_espGui.Name = "TanpopoCornerESP"
        rb_espGui.ResetOnSpawn = false
        rb_espGui.IgnoreGuiInset = true
        pcall(function() rb_espGui.Parent = CoreGui end)
        if not rb_espGui.Parent then rb_espGui.Parent = plr:WaitForChild("PlayerGui") end

        local function RB_getTorsoCenter(char)
            local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if torso then return torso.Position
            elseif hrp then return hrp.Position + Vector3.new(0, 0.5, 0) end
            return nil
        end

        local function RB_getPlayerHeight(char)
            local head = char:FindFirstChild("Head")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            local lowerTorso = char:FindFirstChild("LowerTorso")
            if not head or not hrp then return 4 end
            local topY = head.Position.Y + head.Size.Y/2
            local bottomY
            if lowerTorso then bottomY = lowerTorso.Position.Y - lowerTorso.Size.Y/2
            elseif torso then bottomY = torso.Position.Y - torso.Size.Y/2
            else bottomY = hrp.Position.Y - 2 end
            return topY - bottomY
        end

        local function RB_AddESP(p)
            if p == plr or rb_espObjects[p] then return end
            if not p.Character then return end
            local container = Instance.new("Frame")
            container.BackgroundTransparency = 1
            container.Size = UDim2.new(0, 80, 0, 80)
            container.Visible = false
            container.Parent = rb_espGui
            local thickness = 2
            local cornerSize = 8
            local function createCornerLine(anchorPoint, position, size)
                local line = Instance.new("Frame")
                line.BackgroundColor3 = Color3.fromHSV(0, 1, 1)
                line.BorderSizePixel = 0
                line.AnchorPoint = anchorPoint
                line.Position = position
                line.Size = size
                line.Parent = container
                return line
            end
            createCornerLine(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), UDim2.new(0, cornerSize, 0, thickness))
            createCornerLine(Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), UDim2.new(0, thickness, 0, cornerSize))
            createCornerLine(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), UDim2.new(0, cornerSize, 0, thickness))
            createCornerLine(Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), UDim2.new(0, thickness, 0, cornerSize))
            createCornerLine(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), UDim2.new(0, cornerSize, 0, thickness))
            createCornerLine(Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), UDim2.new(0, thickness, 0, cornerSize))
            createCornerLine(Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), UDim2.new(0, cornerSize, 0, thickness))
            createCornerLine(Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), UDim2.new(0, thickness, 0, cornerSize))
            rb_espObjects[p] = { container = container, lines = container:GetChildren(), rotation = 0, player = p }
        end

        local function RB_RemoveESP(p)
            if rb_espObjects[p] then
                rb_espObjects[p].container:Destroy()
                rb_espObjects[p] = nil
            end
        end

        local function RB_RemoveAllESP()
            for p, data in pairs(rb_espObjects) do
                if data and data.container then data.container:Destroy() end
            end
            rb_espObjects = {}
        end

        local function RB_AddAllESP()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= plr then RB_AddESP(p) end
            end
        end

        local function RB_UpdateESP()
            if not RB_ESP then return end
            rb_globalHue = (rb_globalHue + 0.004) % 1
            local currentColor = Color3.fromHSV(rb_globalHue, 1, 1)
            rb_pulseTime = rb_pulseTime + 0.025
            local pulseFactor = 0.7 + 0.3 * math.sin(rb_pulseTime)
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= plr then
                    if not rb_espObjects[player] then RB_AddESP(player) end
                    local data = rb_espObjects[player]
                    if not data then continue end
                    local container = data.container
                    local char = player.Character
                    if not char then container.Visible = false continue end
                    local torsoPos = RB_getTorsoCenter(char)
                    if not torsoPos then container.Visible = false continue end
                    local height = RB_getPlayerHeight(char)
                    local dist = (workspace.CurrentCamera.CFrame.Position - torsoPos).Magnitude
                    local vec, onScreen = workspace.CurrentCamera:WorldToViewportPoint(torsoPos)
                    if onScreen then
                        local heightOnScreen = (height / dist) * (workspace.CurrentCamera.FieldOfView * 0.3)
                        local baseSize = heightOnScreen * 90
                        local finalSize = math.clamp(baseSize * pulseFactor, 25, 130)
                        if dist > 800 then
                            container.Visible = false
                        else
                            container.Size = UDim2.new(0, finalSize, 0, finalSize)
                            container.Position = UDim2.new(0, vec.X - finalSize/2, 0, vec.Y - finalSize/2)
                            container.Visible = true
                            data.rotation = (data.rotation + 1.0) % 360
                            container.Rotation = data.rotation
                            for _, line in ipairs(data.lines) do
                                if line:IsA("Frame") then line.BackgroundColor3 = currentColor end
                            end
                        end
                    else
                        container.Visible = false
                    end
                end
            end
        end

        local function RB_ToggleESP(state)
            RB_ESP = state
            if state then
                RB_RemoveAllESP()
                RB_AddAllESP()
                if rb_espUpdateConn then rb_espUpdateConn:Disconnect() end
                rb_espUpdateConn = RunService.RenderStepped:Connect(RB_UpdateESP)
                if rb_playerAddedConn then rb_playerAddedConn:Disconnect() end
                if rb_playerRemovingConn then rb_playerRemovingConn:Disconnect() end
                rb_playerAddedConn = Players.PlayerAdded:Connect(function(p)
                    if RB_ESP then task.wait(0.5) RB_AddESP(p) end
                end)
                rb_playerRemovingConn = Players.PlayerRemoving:Connect(function(p) RB_RemoveESP(p) end)
            else
                RB_RemoveAllESP()
                if rb_espUpdateConn then rb_espUpdateConn:Disconnect(); rb_espUpdateConn = nil end
                if rb_playerAddedConn then rb_playerAddedConn:Disconnect(); rb_playerAddedConn = nil end
                if rb_playerRemovingConn then rb_playerRemovingConn:Disconnect(); rb_playerRemovingConn = nil end
                rb_pulseTime = 0
            end
        end

        MicsTab:AddToggle({
            Name = "Rainbow Corner ESP",
            Default = false,
            Callback = function(Value)
                RB_ToggleESP(Value)
                OrionLib:MakeNotification({
                    Name = "Corner ESP",
                    Content = Value and "虹色パルスESP 有効" or "ESP 無効",
                    Time = 2,
                })
            end,
        })
    end

    MicsTab:AddButton({
        Name = "全ESPリセット",
        Callback = function()
            ESPBool.ESPEnabled = false
            clearESP()
            if ESPConnections.NewPlayer then ESPConnections.NewPlayer:Disconnect(); ESPConnections.NewPlayer=nil end
            ESPBool.PCLDESP = false
            for _, v in pairs(Workspace:GetChildren()) do RemovePCLD(v) end
            if PCLD_ESP_CON then PCLD_ESP_CON:Disconnect(); PCLD_ESP_CON=nil end
            if RainbowConnection then RainbowConnection:Disconnect(); RainbowConnection=nil end
            OrionLib:MakeNotification({Name = "ESP", Content = "全ESPをリセットしました", Time = 2})
        end,
    })
end

-- ============================================================
-- All タブ
-- ============================================================
local AllTab = Window:MakeTab({Name = "<font size = \"18\">All</font>", Icon = "users", PremiumOnly = false})

-- ▼ Lag only (Spam Kick のラグ部分のみ)
AllTab:AddSection({ Name = "▼ Lag Only (Spam Kick ラグ)" })
local LagOnlyRunning = false
local function startLagOnly()
    if LagOnlyRunning then return end
    if not CreateGrabLine then
        OrionLib:MakeNotification({Name = "Lag", Content = "CreateGrabLine が見つかりません", Time = 3})
        return
    end
    LagOnlyRunning = true
    task.spawn(function()
        while LagOnlyRunning do
            local sl = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn") or (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart"))
            if sl then
                pcall(function()
                    CreateGrabLine:FireServer(sl, CFrame.new(math.random(-2010000000, 2000000001), 0, math.random(-2008100000, 2000200000)))
                end)
            end
            task.wait(0.001)
        end
    end)
end
local function stopLagOnly()
    LagOnlyRunning = false
end
AllTab:AddToggle({
    Name = "Lag Only (Spam Kick ラグのみ)",
    Default = false,
    Callback = function(Value)
        if Value then
            startLagOnly()
            OrionLib:MakeNotification({Name = "Lag", Content = "Lag Only 開始", Time = 2})
        else
            stopLagOnly()
            OrionLib:MakeNotification({Name = "Lag", Content = "Lag Only 停止", Time = 2})
        end
    end,
})

AllTab:AddSection({ Name = "▼ Blobman All Kick" })
do
    local BK = { isActive = false, selectedHeight = "Spawn", radius = 14, tiltDeg = 45 }
    AllTab:AddDropdown({Name = "Blobman All Kick 高さ", Default = "Spawn (低い)", Options = {"Spawn (低い)", "Heaven (高い)"},
        Callback = function(Value) BK.selectedHeight = (Value == "Heaven (高い)") and "Heaven" or "Spawn" end})
    AllTab:AddSlider({Name = "円の半径", Min = 5, Max = 100, Default = 14, Callback = function(Value) BK.radius = Value end})
    AllTab:AddSlider({Name = "前傾角度", Min = 0, Max = 90, Default = 45, Callback = function(Value) BK.tiltDeg = Value end})
    local function getMyRoot() return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") end
    local function BlobAllKick()
        if BK.isActive then return end
        BK.isActive = true
        -- Spam Kick のラグも同時起動
        startLagOnly()
        local allPlayers = {}
        for _, p in pairs(Players:GetPlayers()) do if p ~= plr then table.insert(allPlayers, p) end end
        if #allPlayers == 0 then BK.isActive = false stopLagOnly() return end
        local height = (BK.selectedHeight == "Heaven") and 35 or 5
        local radius = BK.radius
        local tiltDeg = BK.tiltDeg
        local rootPart = getMyRoot()
        if rootPart then
            local spawnPos = rootPart.CFrame * CFrame.new(0, 0, -5)
            pcall(function() SpawnToyRemote:InvokeServer("CreatureBlobman", spawnPos, Vector3.new(0, 127, 0)) end)
        end
        task.wait(0.5)
        local tf = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
        local currentBlob = tf and tf:FindFirstChild("CreatureBlobman")
        if not currentBlob then BK.isActive = false stopLagOnly() return end
        local vseat = currentBlob:FindFirstChild("VehicleSeat")
        if vseat and plr.Character then
            local h = plr.Character:FindFirstChildOfClass("Humanoid")
            if h then vseat:Sit(h) end
        end
        task.wait(0.3)
        local myRoot = getMyRoot()
        if not myRoot then BK.isActive = false stopLagOnly() return end
        for _, tP in ipairs(allPlayers) do
            local tR = tP.Character and tP.Character:FindFirstChild("HumanoidRootPart")
            if tR then
                myRoot.CFrame = tR.CFrame
                myRoot.AssemblyAngularVelocity = Vector3.zero
                task.wait(0.025)
                if (myRoot.Position - tR.Position).Magnitude <= 35 then
                    for i = 1, 8 do
                        if not tR.Parent or not currentBlob.Parent then break end
                        pcall(function()
                            currentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(currentBlob.LeftDetector, tR, currentBlob.LeftDetector.LeftWeld)
                            currentBlob.BlobmanSeatAndOwnerScript.CreatureRelease:FireServer(currentBlob.LeftDetector.LeftWeld)
                        end)
                        task.wait()
                    end
                end
            end
        end
        myRoot.CFrame = CFrame.new(0, 0, 0)
        myRoot.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.1)
        for _, p in ipairs(currentBlob:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.Anchored = true end) end end
        task.wait(0.1)
        local pd = {}
        for _, tP in ipairs(allPlayers) do
            local tR = tP.Character and tP.Character:FindFirstChild("HumanoidRootPart")
            if tR then table.insert(pd, {hrp = tR, player = tP}) end
        end
        for i, d in ipairs(pd) do
            local angle = math.rad((i - 1) * (360 / #pd))
            local x = radius * math.cos(angle)
            local z = radius * math.sin(angle)
            -- 全員 中心を向いて「地面を見るように」45度下を向く
            local pos = Vector3.new(x, height, z)
            -- 中心の少し下（地面方向）を見るポイントを作る → 自然に45度前後で下を向く
            local lookTarget = Vector3.new(0, height - radius, 0) -- 中心から半径分下を見る
            local lcf = CFrame.lookAt(pos, lookTarget)

            pcall(function()
                d.hrp.CFrame = lcf
                d.hrp.AssemblyLinearVelocity = Vector3.zero
                d.hrp.AssemblyAngularVelocity = Vector3.zero
            end)
            local bp = Instance.new("BodyPosition")
            bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bp.P = 4000
            bp.Position = Vector3.new(x, height, z)
            bp.Parent = d.hrp
            task.delay(2, function() pcall(function() bp:Destroy() end) end)
        end
        task.wait(0.1)
        for _ = 1, 2 do
            for _, d in ipairs(pd) do
                local tR = d.hrp
                if tR then task.spawn(function() pcall(function()
                    SetNetworkOwner:FireServer(tR, CFrame.new(tR.Position))
                    DestroyGrabLine:FireServer(tR)
                end) end) end
            end
            task.wait(0.1)
        end
        task.wait(0.3)
        for _, d in ipairs(pd) do
            local tR = d.hrp
            if tR then task.spawn(function() pcall(function()
                currentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(currentBlob.LeftDetector, tR, currentBlob.LeftDetector.LeftWeld)
                currentBlob.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(currentBlob.RightDetector, tR, currentBlob.RightDetector.RightWeld)
            end) end) end
        end
        task.wait(0.1)
        for _, p in ipairs(currentBlob:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.Anchored = false end) end end
        task.wait(1)
        BK.isActive = false
        -- ラグは継続（Lag Onlyトグルで別途停止可能）
    end
    AllTab:AddButton({Name = "▶ Blobman All Kick 実行",
        Callback = function() task.spawn(function() pcall(BlobAllKick) OrionLib:MakeNotification({Name = "Blobman All Kick", Content = "実行完了 (Lag同時起動)", Time = 3}) end) end})
    AllTab:AddButton({Name = "■ Blobman All Kick 停止",
        Callback = function()
            BK.isActive = false
            stopLagOnly()
            OrionLib:MakeNotification({Name = "Blobman All Kick", Content = "停止しました (Lagも停止)", Time = 2})
        end})
end
AllTab:AddSection({ Name = "▼ Ground Kick" })
do
    local function getHRPAll()
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then return plr.Character.HumanoidRootPart end
        local c = plr.CharacterAdded:Wait() return c:WaitForChild("HumanoidRootPart")
    end
    local function getContainerAll()
        if not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then return workspace:FindFirstChild(plr.Name .. "SpawnedInToys") end
        for _, v in pairs(workspace.Plots:GetChildren()) do
            local sign = v:FindFirstChild("PlotSign")
            local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
            if owners then
                for _, b in pairs(owners:GetChildren()) do
                    if b.Value == plr.Name then
                        local folder = workspace.PlotItems:FindFirstChild(v.Name)
                        if folder then return folder end
                    end
                end
            end
        end
        return workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    end
    local function spawnAndAttach(targetPart, container)
        if not targetPart or not container then return nil end
        local cs = plr:WaitForChild("CanSpawnToy")
        local hrp_ = getHRPAll(); if not hrp_ then return nil end
        local pe = {}
        for _, c in pairs(container:GetChildren()) do if c.Name == "NinjaShuriken" then table.insert(pe, c) end end
        if not cs.Value or not SpawnToyRemote then return nil end
        local ok, newSh = pcall(function()
            SpawnToyRemote:InvokeServer("NinjaShuriken", hrp_.CFrame * CFrame.new(0, 2, 8), Vector3.new(0,0,0))
            local st = tick()
            while tick() - st < 2 do
                for _, c in pairs(container:GetChildren()) do
                    if c.Name == "NinjaShuriken" and not table.find(pe, c) then return c end
                end
                task.wait()
            end
            return nil
        end)
        if not ok or not newSh then return nil end
        local sp = newSh:FindFirstChild("SoundPart") or newSh:WaitForChild("SoundPart", 0.1)
        if sp and SetNetworkOwner then pcall(function() SetNetworkOwner:FireServer(sp, sp.CFrame) end) end
        if newSh:FindFirstChild("StickyPart") and StickyEvent then
            pcall(function() StickyEvent:FireServer(newSh.StickyPart, targetPart, CFrame.new(0, -2.3e+09, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)) end)
        end
        return newSh
    end
    AllTab:AddLabel("📖 足元の地面に手裏剣を貼り付けて破壊します")
    AllTab:AddButton({Name = "破壊 (Ground Kick)",
        Callback = function()
            local ct = getContainerAll()
            if not ct then OrionLib:MakeNotification({Title = "Ground Kick", Content = "コンテナが見つかりません", Time = 3}) return end
            local r = getHRPAll(); if not r then return end
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = {plr.Character}
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local res = workspace:Raycast(r.Position, Vector3.new(0, -15, 0), rp)
            local tp = res and res.Instance
            if tp and tp:IsA("BasePart") and not tp:IsA("Terrain") then
                local ns = spawnAndAttach(tp, ct)
                if ns then OrionLib:MakeNotification({Title = "Ground Kick", Content = "破壊: " .. tp.Name, Time = 2})
                else OrionLib:MakeNotification({Title = "Ground Kick", Content = "手裏剣スポーン失敗", Time = 2}) end
            else OrionLib:MakeNotification({Title = "Ground Kick", Content = "真下にパーツなし", Time = 2}) end
        end})
end
AllTab:AddSection({ Name = "▼ Loop Kick All (Beta)" })
do
    local flag2 = false
    local v16 = nil
    local n8 = 10
    local flag3 = true
    local tbl16 = {}
    local flag4 = false
    local flag5 = false
    local thread = nil
    local LP2 = plr
    local function fn_() return LP2.Character end
    local function fn_2() local v = fn_(); return v and v:FindFirstChildOfClass("Humanoid") end
    local function fn_3() local v = fn_(); if not v then return nil end; return v:FindFirstChild("HumanoidRootPart") or v:FindFirstChild("Torso") end
    local function fn_4() return workspace:FindFirstChild(LP2.Name .. "SpawnedInToys") end
    local function fn_5(a) if not a then return nil end; local m = a:FindFirstAncestorOfClass("Model"); if m and m.Name == "CreatureBlobman" then return m end; return nil end
    local function fn_6() if v16 and v16.Parent then
        local mt = RS:FindFirstChild("MenuToys"); local dt = mt and mt:FindFirstChild("DestroyToy")
        if dt then dt:FireServer(v16) else v16:Destroy() end end v16 = nil end
    local function fn_7(a) local v = fn_3(); if not (a and v) then return end; RS.GrabEvents.SetNetworkOwner:FireServer(a, v.CFrame) end
    local function fn_8(a, t)
        local e = os.clock() + (t or 3); task.wait()
        while os.clock() < e do
            if not (a and a.Parent) then return false end
            fn_7(a); task.wait()
            if not (a and a.Parent) then return false end
            local p = a.Position.Y + 0.1
            a.CFrame = a.CFrame + Vector3.new(0, 0.1, 0); task.wait()
            if not (a and a.Parent) then return false end
            if not (p - 0.05 <= a.Position.Y) then continue end
            return true
        end
        return false
    end
    local function fn_9(a, t, s)
        local v = a and a:FindFirstChild(s .. "Detector"); local w = v and v:FindFirstChild(s .. "Weld")
        local bs = a and a:FindFirstChild("BlobmanSeatAndOwnerScript"); bs = bs and bs:FindFirstChild("CreatureGrab")
        if v and w and bs and t then bs:FireServer(v, t, w) end
    end
    local function fn_10(a) if a then RS.GrabEvents.DestroyGrabLine:FireServer(a) end end
    local function fn_11(a, r, s)
        local v = fn_2(); if not (v and v.Sit and v16 and v16.Parent and r) then return end
        for i = 1, 3 do fn_9(a, fn_3(), s) end
        task.wait(0.12); fn_8(r, 2)
        if r and r.Parent then for i = 1, 2 do r.CFrame = r.CFrame + Vector3.new(0, 20, 0) end end
        fn_10(r); task.wait(0.02); fn_9(a, r, s)
    end
    local function fn_12(a) return a and a.UserId and LP2:IsFriendsWith(a.UserId) end
    local function fn_13(a) return a.InPlot and a.InPlot.Value end
    local function fn_14(a)
        local c = a.Character; if not c then return false end
        local h = c:FindFirstChildOfClass("Humanoid"); return h and h.Health > 0
    end
    local function fn_15(a) for _, d in ipairs(a:GetDescendants()) do
        if d:IsA("BodyForce") or d:IsA("BodyVelocity") or d:IsA("BodyAngularVelocity") or d:IsA("BodyGyro") or d:IsA("VectorForce") or d:IsA("LinearVelocity") or d:IsA("AngularVelocity") or d:IsA("AlignPosition") or d:IsA("AlignOrientation") then d:Destroy() end end end
    local function fn_16(a) local v = fn_(); if not v then return end; for _, d in ipairs(v:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = not a end end end
    local function fn_17() if not v16 then return end
        local ld = v16:FindFirstChild("LeftDetector", true); if not ld then return end
        local ap = ld:FindFirstChild("AttachPlayer"); if ap then ap:Destroy() end end
    local function fn_18()
        if not flag5 then return end
        local v = fn_2(); local v2 = fn_3(); if not (v and v2) then return end
        if v.SeatPart then local c = fn_5(v.SeatPart); if c then v16 = c return end end
        if not (v16 and v16.Parent) then
            local mt = RS:FindFirstChild("MenuToys"); mt = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
            if not mt then return end
            mt:InvokeServer("CreatureBlobman", v2.CFrame * CFrame.new(0, 0, -5), Vector3.new(0, -15.716, 0))
            local f = fn_4()
            if f then for _, ch in ipairs(f:GetChildren()) do if ch.Name == "CreatureBlobman" and ch:FindFirstChildOfClass("VehicleSeat") then v16 = ch break end end end
        end
        local vs = v16 and v16:FindFirstChildOfClass("VehicleSeat")
        if vs and not v.Sit then vs:Sit(v) end
    end
    local function fn_19(a) a = a and a.Character; if not a then return nil end; return a:FindFirstChild("HumanoidRootPart") or a:FindFirstChild("Torso") end
    local function fn_20(a)
        if a == LP2 then return false end
        if not fn_14(a) then return false end
        if flag3 and fn_12(a) then return false end
        if fn_13(a) then return false end
        local c = a.Character; local v = tbl16[a.UserId]
        local f = v and os.clock() - v.time < n8 or v
        if f and v.char == c then return false end
        local v2 = fn_19(a); if not v2 then return false end
        return true, v2, c
    end
    local function fn_21()
        local v = fn_3(); if not v then return {} end
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local a, b, c = fn_20(p)
            if a then t[#t+1] = { player = p, root = b, char = c, distance = (b.Position - v.Position).Magnitude } end
        end
        table.sort(t, function(x, y) return x.distance < y.distance end)
        return t
    end
    RunService.Heartbeat:Connect(function()
        if not flag2 or not flag5 then return end
        fn_18()
        local v = fn_2(); local sit = v and v.Sit or false
        if sit and not flag4 then flag5 = false end
        flag4 = sit
    end)
    local function fn_22()
        if thread then thread = nil end
        flag5 = true; flag4 = false
        thread = task.spawn(function()
            while flag2 do
                local v = fn_2()
                if v and v.Sit and v16 and v16.Parent then
                    local v2 = fn_3()
                    if v2 then
                        fn_17()
                        local t = fn_21()
                        if #t == 0 then task.wait()
                        else
                            for _, e in ipairs(t) do
                                if flag2 then
                                    local p = e.player; local r = e.root; local c = e.char
                                    if p and r and c and c.Parent then
                                        local pos = r.Position; local y = pos.Y - 7; local cf = v2.CFrame
                                        fn_16(true); v2.CFrame = CFrame.new(pos.X, y, pos.Z)
                                        local f6 = true
                                        local th2 = task.spawn(function()
                                            local a = math.atan2(v2.Position.Z - pos.Z, v2.Position.X - pos.X)
                                            while f6 and flag2 and r.Parent and c.Parent do
                                                a += 50 * task.wait()
                                                v2.CFrame = CFrame.new(Vector3.new(pos.X + math.cos(a) * 20, y, pos.Z + math.sin(a) * 20), Vector3.new(pos.X, y, pos.Z))
                                            end
                                        end)
                                        fn_11(v16, r, "Left")
                                        f6 = false; task.cancel(th2)
                                        v2.CFrame = cf; fn_16(false); fn_15(c)
                                        tbl16[p.UserId] = { time = os.clock(), char = c }
                                        task.wait(0.02)
                                    end
                                    continue
                                end
                                break
                            end
                            task.wait(0)
                        end
                    else task.wait() end
                else flag5 = true task.wait() end
            end
        end)
    end
    local function fn_23()
        flag2 = false
        if thread then thread = nil end
        flag5 = false; flag4 = false; tbl16 = {}; fn_6()
    end
    _G.LoopKickAllBetaStart = function() if not flag2 then flag2 = true; fn_22() end end
    _G.LoopKickAllBetaStop = function() if flag2 then fn_23() end end
end
AllTab:AddToggle({Name = "Loop Kick All (Beta)", Default = false,
    Callback = function(Value)
        if Value then if _G.LoopKickAllBetaStart then _G.LoopKickAllBetaStart() end
        else if _G.LoopKickAllBetaStop then _G.LoopKickAllBetaStop() end end
    end})

-- ============================================================
-- All: No Blob All
-- ============================================================
do
    local NBA_running = false

    local function NBA_Notify(t, c)
        pcall(function() OrionLib:MakeNotification({Name = t, Content = c, Time = 3}) end)
    end

    local function NBA_spamOwnership(part)
        if SetNetworkOwner and part then
            pcall(function() SetNetworkOwner:FireServer(part, part.CFrame) end)
        end
    end

    local function NBA_teleportTo(myHrp, targetHrp)
        if not myHrp or not targetHrp then return end
        pcall(function()
            myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 3)
            myHrp.AssemblyLinearVelocity = Vector3.zero
        end)
    end

    local function NBA_destroyLineOnPlayer(part)
        if not CreateGrabLine or not DestroyGrabLine or not part then return end
        pcall(function()
            CreateGrabLine:FireServer(part, CFrame.new(3e9, 4e9, 2e9))
            task.wait()
            DestroyGrabLine:FireServer(part)
        end)
    end

    local function NBA_IsInPlot(p)
        if not p then return false end
        local ip = p:FindFirstChild("InPlot")
        return ip and ip:IsA("BoolValue") and ip.Value
    end

    AllTab:AddSection({ Name = "▼ No Blob All" })

    AllTab:AddButton({
        Name = "No Blob All",
        Callback = function()
            if NBA_running then
                NBA_Notify("No Blob All", "既に実行中")
                return
            end
            NBA_running = true
            task.spawn(function()
                -- ★ ラグ発動（既存の Lag Only と同じ方式）
                startLagOnly()
                NBA_Notify("No Blob All", "ラグ開始 + キック実行中...")

                local targets = {}
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= plr and not NBA_IsInPlot(p) then
                        local c = p.Character
                        local hrp = c and c:FindFirstChild("HumanoidRootPart")
                        if hrp then table.insert(targets, { player = p, hrp = hrp }) end
                    end
                end

                if #targets == 0 then
                    NBA_running = false
                    NBA_Notify("No Blob All", "ターゲットなし（ラグ継続 → ラグ停止ボタンで停止）")
                    return
                end

                local myChar = plr.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myHrp then
                    NBA_running = false
                    NBA_Notify("No Blob All", "自分のキャラなし（ラグ継続 → ラグ停止ボタンで停止）")
                    return
                end

                NBA_Notify("No Blob All", #targets .. " 人に実行中...")

                for _, t in ipairs(targets) do
                    if not t.hrp or not t.hrp.Parent then continue end
                    NBA_teleportTo(myHrp, t.hrp)
                    task.wait(0.16)
                    NBA_spamOwnership(t.hrp); NBA_spamOwnership(t.hrp)
                    task.wait(); NBA_spamOwnership(t.hrp)
                    task.wait(); NBA_spamOwnership(t.hrp); NBA_spamOwnership(t.hrp)
                end

                local step = (2 * math.pi) / math.max(#targets, 1)
                for i, t in ipairs(targets) do
                    if not t.hrp or not t.hrp.Parent then continue end
                    local ang = (i - 1) * step
                    local x = math.cos(ang) * 80
                    local z = math.sin(ang) * 80
                    pcall(function()
                        t.hrp.CFrame = CFrame.new(x, 32, z)
                        t.hrp.AssemblyLinearVelocity = Vector3.zero
                    end)
                    local bp = Instance.new("BodyPosition")
                    bp.MaxForce = Vector3.new(3e9, 4e9, 3e9)
                    bp.P = 50000000
                    bp.Position = Vector3.new(x, 32, z)
                    bp.Parent = t.hrp
                    task.delay(3, function() pcall(function() bp:Destroy() end) end)
                    task.wait()
                end

                task.wait(1.3)
                for _, t in ipairs(targets) do
                    if t.hrp and t.hrp.Parent then
                        NBA_destroyLineOnPlayer(t.hrp)
                    end
                end

                NBA_running = false
                NBA_Notify("No Blob All", "完了（ラグ継続中 → 「ラグ停止」ボタンで停止）")
            end)
        end
    })

    AllTab:AddButton({
        Name = "No Blob All ラグ停止",
        Callback = function()
            stopLagOnly()
            NBA_Notify("No Blob All", "ラグを停止しました")
        end
    })
end

-- ============================================================
-- UFO タブ
-- ============================================================
local UFOTab = Window:MakeTab({Name = "<font size = \"18\">UFO</font>", Icon = "rbxassetid://4483362458", PremiumOnly = false})
do
    local function UFO_Notify(t, c)
        pcall(function() OrionLib:MakeNotification({Name = t, Content = c, Time = 3}) end)
    end

    local function getBackpack()
        return Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    end

    local function spawnShurikens(count)
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not SpawnToyRemote then return end
        local spawnCFrame = hrp.CFrame * CFrame.new(0, 3, 0)
        for i = 1, count do
            pcall(function()
                SpawnToyRemote:InvokeServer("NinjaShuriken", spawnCFrame, Vector3.new(0, 0, 0))
            end)
            task.wait(0.05)
        end
    end

    local function hijackTweenObject(pathParts, bodyChildName)
        -- pathParts: list of names under Workspace.Map.AlwaysHereTweenedObjects
        task.spawn(function()
            local ok, err = pcall(function()
                local node = Workspace:FindFirstChild("Map")
                if not node then UFO_Notify("UFO", "Map が見つかりません"); return end
                node = node:FindFirstChild("AlwaysHereTweenedObjects")
                if not node then UFO_Notify("UFO", "AlwaysHereTweenedObjects なし"); return end
                for _, name in ipairs(pathParts) do
                    node = node:WaitForChild(name, 3)
                    if not node then UFO_Notify("UFO", name .. " なし"); return end
                end
                local obj = node -- Object
                local model = obj:FindFirstChild("ObjectModel") or obj
                local body = bodyChildName and model:FindFirstChild(bodyChildName) or model:FindFirstChild("Body") or model:FindFirstChild("Part")
                if not body then
                    -- CaveCart: GetChildren()[13]
                    local children = model:GetChildren()
                    body = children[13] or children[1]
                end
                if not body then UFO_Notify("UFO", "Body なし"); return end

                local bp = getBackpack()
                spawnShurikens(10)
                task.wait(1)
                bp = getBackpack()
                if not bp then UFO_Notify("UFO", "SpawnedInToys なし"); return end

                for i = 1, 10 do
                    local shur = bp:FindFirstChild("NinjaShuriken")
                    if not shur then break end
                    shur.Name = tostring(i)
                    local sp = shur:FindFirstChild("StickyPart")
                    if sp and StickyEvent then
                        pcall(function() StickyEvent:FireServer(sp, body, CFrame.Angles(0, 0, 0)) end)
                    end
                end

                local myHrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                for i = 1, 100 do
                    myHrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if myHrp and body.Parent then
                        myHrp.CFrame = body.CFrame
                        if SetNetworkOwner then
                            pcall(function() SetNetworkOwner:FireServer(body, body.CFrame) end)
                        end
                    end
                    task.wait()
                end

                local attach = body:FindFirstChild("ObjectModelAttachment")
                if attach then attach:Destroy() end

                local ftp = obj:FindFirstChild("FollowThisPart")
                if ftp then
                    local ap = ftp:FindFirstChild("AlignPosition")
                    local ao = ftp:FindFirstChild("AlignOrientation")
                    if ap then ap.Attachment0 = nil end
                    if ao then ao.Attachment0 = nil end
                end
                UFO_Notify("UFO", "完了")
            end)
            if not ok then UFO_Notify("UFO", "エラー: " .. tostring(err)) end
        end)
    end

    UFOTab:AddSection({ Name = "▼ UFO / Train / CaveCart" })

    UFOTab:AddButton({
        Name = "UFO1 (OuterUFO)",
        Callback = function()
            hijackTweenObject({"OuterUFO", "Object"}, "Body")
        end
    })

    UFOTab:AddButton({
        Name = "UFO2 (InnerUFO)",
        Callback = function()
            hijackTweenObject({"InnerUFO", "Object"}, "Body")
        end
    })

    UFOTab:AddButton({
        Name = "Train",
        Callback = function()
            hijackTweenObject({"Train", "Object"}, "Part")
        end
    })

    UFOTab:AddButton({
        Name = "CaveCart",
        Callback = function()
            hijackTweenObject({"CaveCart", "Object"}, nil)
        end
    })

    -- Hitbox Spin / Follow
    UFOTab:AddSection({ Name = "▼ UFO Hitbox" })

    local spinEnabled = false
    local followEnabled = false
    local spinSpeed = 6
    local radius = 15
    local height = 5
    local angle = 0
    local hitboxes = {}

    local function refreshHitboxes()
        hitboxes = {}
        local ok, folder = pcall(function()
            return Workspace:WaitForChild("Map", 2)
                :WaitForChild("AlwaysHereTweenedObjects", 2)
                :WaitForChild("OuterUFO", 2)
                :WaitForChild("Object", 2)
                :WaitForChild("ObjectModel", 2)
        end)
        if ok and folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child.Name:match("Hitbox") then
                    table.insert(hitboxes, child)
                end
            end
        end
    end

    task.spawn(function()
        task.wait(1)
        refreshHitboxes()
    end)

    UFOTab:AddToggle({
        Name = "UFO Hitbox Spin",
        Default = false,
        Callback = function(Value)
            spinEnabled = Value
            if Value then
                followEnabled = false
                refreshHitboxes()
            end
        end
    })

    UFOTab:AddToggle({
        Name = "UFO Hitbox Follow Head",
        Default = false,
        Callback = function(Value)
            followEnabled = Value
            if Value then
                spinEnabled = false
                refreshHitboxes()
            end
        end
    })

    RunService.RenderStepped:Connect(function(dt)
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if spinEnabled then
            angle = angle + dt * spinSpeed
            local count = #hitboxes
            if count == 0 then return end
            for i, hitbox in ipairs(hitboxes) do
                if hitbox and hitbox.Parent then
                    local offset = (i / count) * (2 * math.pi)
                    local x = math.sin(angle + offset) * radius
                    local z = math.cos(angle + offset) * radius
                    hitbox.CFrame = CFrame.new(hrp.Position + Vector3.new(x, height, z))
                end
            end
        elseif followEnabled then
            for _, hitbox in ipairs(hitboxes) do
                if hitbox and hitbox.Parent then
                    hitbox.CFrame = CFrame.new(hrp.Position + Vector3.new(0, height + 3, 0))
                end
            end
        end
    end)

    -- Massless Grab
    UFOTab:AddSection({ Name = "▼ Massless Grab" })
    local Sense, MasslessCon = 30, nil
    UFOTab:AddToggle({
        Name = "Massless Grab (PLAYER & OBJECT)",
        Default = false,
        Callback = function(v)
            if v then
                MasslessCon = Workspace.ChildAdded:Connect(function(r)
                    if r.Name == "GrabParts" then
                        while Workspace:FindFirstChild("GrabParts") do
                            task.wait()
                            local dp = r:FindFirstChild("DragPart")
                            if dp and dp:FindFirstChild("AlignPosition") and dp:FindFirstChild("AlignOrientation") then
                                dp.AlignPosition.Responsiveness = Sense
                                dp.AlignPosition.MaxForce = math.huge
                                dp.AlignPosition.MaxVelocity = math.huge
                                dp.AlignOrientation.Responsiveness = Sense
                                dp.AlignOrientation.MaxTorque = math.huge
                            end
                        end
                    end
                end)
            else
                if MasslessCon then MasslessCon:Disconnect() MasslessCon = nil end
            end
        end
    })

    UFOTab:AddSlider({
        Name = "Massless Sense",
        Min = 1,
        Max = 100,
        Default = 30,
        Callback = function(Value)
            Sense = Value
        end
    })
end

-- ============================================================
-- Music タブ (音源) - album art対応 (Musicタブを開いた時だけ表示)
-- ============================================================
local MusicTab = Window:MakeTab({Name = "<font size = \"18\">Music</font>", Icon = "music", PremiumOnly = false})
do
    local getAsset = getcustomasset or syn_getcustomasset
    local folderName = "music"

    if not isfolder(folderName) then
        makefolder(folderName)
    end

    -- ============================================
    -- ユーティリティ
    -- ============================================
    local function getMusicFiles()
        local files = {}
        if not isfolder(folderName) then
            makefolder(folderName)
            return files
        end
        for _, file in ipairs(listfiles(folderName)) do
            local lower = string.lower(file)
            if string.match(lower, "%.mp3$")
                or string.match(lower, "%.ogg$")
                or string.match(lower, "%.wav$") then
                local fileName = string.match(file, "[/\\]([^/\\]+)$") or file
                -- アルバムアートのキャッシュファイルは除外
                if not fileName:match("^%.art_") then
                    table.insert(files, { name = fileName, path = file })
                end
            end
        end
        return files
    end

    local function Notify(title, content)
        pcall(function()
            OrionLib:MakeNotification({Name = title, Content = content, Time = 3})
        end)
    end

    -- ============================================
    -- アルバムアート抽出 (ID3v2 APIC)
    -- ============================================
    local function readSyncSafe(bytes, i)
        local b1 = string.byte(bytes, i) or 0
        local b2 = string.byte(bytes, i + 1) or 0
        local b3 = string.byte(bytes, i + 2) or 0
        local b4 = string.byte(bytes, i + 3) or 0
        return (b1 % 128) * 0x200000 + (b2 % 128) * 0x4000 + (b3 % 128) * 0x80 + (b4 % 128)
    end

    local function readUInt32(bytes, i)
        local b1 = string.byte(bytes, i) or 0
        local b2 = string.byte(bytes, i + 1) or 0
        local b3 = string.byte(bytes, i + 2) or 0
        local b4 = string.byte(bytes, i + 3) or 0
        return b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4
    end

    local function extractAlbumArtFromMP3(content)
        if type(content) ~= "string" or #content < 10 then return nil end
        if content:sub(1, 3) ~= "ID3" then return nil end

        local majorVer = string.byte(content, 4) or 0
        if majorVer < 2 or majorVer > 4 then return nil end

        local tagSize = readSyncSafe(content, 7)
        local scanEnd = math.min(10 + tagSize, #content)

        local pos = 11
        while pos < scanEnd - 10 do
            local frameId = content:sub(pos, pos + 3)
            if frameId == "\0\0\0\0" or frameId == "" then break end

            local frameSize
            if majorVer == 4 then
                frameSize = readSyncSafe(content, pos + 4)
            else
                frameSize = readUInt32(content, pos + 4)
            end

            if not frameSize or frameSize <= 0 then break end

            if frameId == "APIC" then
                local dataStart = pos + 10
                local encoding = string.byte(content, dataStart) or 0

                local mimeEnd = content:find("\0", dataStart + 1, true)
                if not mimeEnd then return nil end
                local mime = content:sub(dataStart + 1, mimeEnd - 1)

                local descStart = mimeEnd + 2 -- skip pic type byte
                local descEnd
                if encoding == 1 or encoding == 2 then
                    local _, e = content:find("\0\0", descStart, true)
                    descEnd = e
                else
                    descEnd = content:find("\0", descStart, true)
                end
                if not descEnd then return nil end

                local imageStart = descEnd + 1
                local imageEnd = dataStart + frameSize - 1
                if imageEnd > #content then imageEnd = #content end

                local imageData = content:sub(imageStart, imageEnd)
                if #imageData < 100 then return nil end

                local ext = ".jpg"
                local ml = mime:lower()
                if ml:find("png", 1, true) then ext = ".png"
                elseif ml:find("gif", 1, true) then ext = ".gif"
                end

                return imageData, ext
            end

            pos = pos + 10 + frameSize
        end

        return nil
    end

    local artCache = {}
    local function extractAlbumArt(filePath)
        if not filePath then return nil end
        if artCache[filePath] ~= nil then
            return artCache[filePath] or nil
        end

        local ext = string.match(string.lower(filePath), "%.([^%.]+)$") or ""
        if ext ~= "mp3" then
            artCache[filePath] = false
            return nil
        end

        local ok, content = pcall(readfile, filePath)
        if not ok or type(content) ~= "string" then
            artCache[filePath] = false
            return nil
        end

        local imageData, imgExt = extractAlbumArtFromMP3(content)
        if not imageData then
            artCache[filePath] = false
            return nil
        end

        local hash = 0
        for i = 1, math.min(#filePath, 64) do
            hash = (hash * 31 + string.byte(filePath, i)) % 2147483647
        end
        local savePath = folderName .. "/.art_" .. tostring(hash) .. imgExt

        local wok = pcall(writefile, savePath, imageData)
        if not wok then
            artCache[filePath] = false
            return nil
        end

        artCache[filePath] = savePath
        return savePath
    end

    -- ============================================
    -- 再生関連
    -- ============================================
    local currentSound = nil
    local selectedFile = nil
    local isPlaying = false
    local volumeValue = 5

    local function stopCurrentSound()
        if currentSound then
            pcall(function()
                currentSound:Stop()
                currentSound:Destroy()
            end)
            currentSound = nil
        end
    end

    local function playMusicFile(fileInfo)
        if not getAsset then
            Notify("❌ エラー", "getcustomasset 非対応")
            return
        end

        stopCurrentSound()

        local ok, assetId = pcall(getAsset, fileInfo.path)
        if not ok or not assetId then
            Notify("❌ 読み込み失敗", fileInfo.name)
            return
        end

        local sound = Instance.new("Sound")
        sound.Name = "LocalMusicPlayer"
        sound.SoundId = assetId
        sound.Volume = volumeValue / 5
        sound.Looped = true
        sound.Parent = SoundService
        sound:Play()

        currentSound = sound
        Notify("▶ 再生中", fileInfo.name)
    end

    -- ============================================
    -- UI (OrionLib) — アルバムアートをMusicタブのItemContainer内に配置
    -- ============================================
    MusicTab:AddSection({ Name = "▼ アルバムアート" })

    -- マーカーラベル（このTextLabelの親を辿ってItemContainerを特定する）
    local MARKER_TEXT = "♪ TANPOPO_ALBUM_ART_MARKER_♪"
    MusicTab:AddLabel(MARKER_TEXT)

    local AlbumArtImage, AlbumArtPlaceholder, AlbumArtContainer
    local musicItemContainer = nil

    local function findMusicItemContainer()
        -- Orion ScreenGui 名: NNhubOrion
        local candidates = {}
        local function collect(root)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text == MARKER_TEXT then
                    table.insert(candidates, d)
                end
            end
        end
        pcall(function()
            collect(CoreGui:FindFirstChild("NNhubOrion"))
            collect(CoreGui:FindFirstChild("Orion"))
            collect(CoreGui:FindFirstChild("OrionLib"))
            local pg = plr:FindFirstChild("PlayerGui")
            if pg then
                collect(pg:FindFirstChild("NNhubOrion"))
                collect(pg:FindFirstChild("Orion"))
            end
            if gethui then
                for _, c in ipairs(gethui():GetChildren()) do
                    collect(c)
                end
            end
        end)

        for _, label in ipairs(candidates) do
            local cur = label.Parent
            while cur do
                if cur:IsA("ScrollingFrame") and cur.Name == "ItemContainer" then
                    return cur, label
                end
                -- ItemContainer 以外でも UIListLayout を持つスクロールなら採用
                if cur:IsA("ScrollingFrame") and cur:FindFirstChildOfClass("UIListLayout") then
                    return cur, label
                end
                cur = cur.Parent
            end
        end
        return nil, nil
    end

    -- UI構築を待ってから挿入
    task.spawn(function()
        -- フォールバック用ScreenGuiが残っていれば削除
        pcall(function()
            local old = CoreGui:FindFirstChild("TanpopoAlbumArtFallback")
            if old then old:Destroy() end
            local old2 = CoreGui:FindFirstChild("TanpopoAlbumArt")
            if old2 then old2:Destroy() end
            local pg = plr:FindFirstChild("PlayerGui")
            if pg then
                local o = pg:FindFirstChild("TanpopoAlbumArtFallback")
                if o then o:Destroy() end
                local o2 = pg:FindFirstChild("TanpopoAlbumArt")
                if o2 then o2:Destroy() end
            end
        end)

        for _ = 1, 50 do
            musicItemContainer = select(1, findMusicItemContainer())
            if musicItemContainer then break end
            task.wait(0.1)
        end

        local container, markerLabel = findMusicItemContainer()
        musicItemContainer = container

        AlbumArtContainer = Instance.new("Frame")
        AlbumArtContainer.Name = "TanpopoAlbumArtInUI"
        AlbumArtContainer.Size = UDim2.new(1, 0, 0, 200)
        AlbumArtContainer.BackgroundTransparency = 1
        AlbumArtContainer.BorderSizePixel = 0
        AlbumArtContainer.LayoutOrder = -1000 -- 一番上に表示
        AlbumArtContainer.Visible = true

        local artBg = Instance.new("Frame")
        artBg.Name = "ArtBg"
        artBg.Size = UDim2.fromOffset(180, 180)
        artBg.Position = UDim2.new(0.5, -90, 0, 10)
        artBg.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
        artBg.BackgroundTransparency = 0.15
        artBg.BorderSizePixel = 0
        artBg.Parent = AlbumArtContainer

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = artBg

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(100, 90, 160)
        stroke.Thickness = 2
        stroke.Transparency = 0.25
        stroke.Parent = artBg

        AlbumArtPlaceholder = Instance.new("TextLabel")
        AlbumArtPlaceholder.Name = "Placeholder"
        AlbumArtPlaceholder.Size = UDim2.fromScale(1, 1)
        AlbumArtPlaceholder.BackgroundTransparency = 1
        AlbumArtPlaceholder.Text = "♪"
        AlbumArtPlaceholder.TextSize = 72
        AlbumArtPlaceholder.Font = Enum.Font.GothamBold
        AlbumArtPlaceholder.TextColor3 = Color3.fromRGB(160, 160, 180)
        AlbumArtPlaceholder.Parent = artBg

        AlbumArtImage = Instance.new("ImageLabel")
        AlbumArtImage.Name = "Image"
        AlbumArtImage.Size = UDim2.fromScale(1, 1)
        AlbumArtImage.BackgroundTransparency = 1
        AlbumArtImage.Image = ""
        AlbumArtImage.ScaleType = Enum.ScaleType.Crop
        AlbumArtImage.Visible = false
        AlbumArtImage.Parent = artBg

        local corner2 = Instance.new("UICorner")
        corner2.CornerRadius = UDim.new(0, 12)
        corner2.Parent = AlbumArtImage

        if musicItemContainer then
            AlbumArtContainer.Parent = musicItemContainer
            -- マーカーラベルの行を隠す（枠ごと）
            if markerLabel then
                local row = markerLabel.Parent
                if row and row:IsA("GuiObject") and row ~= musicItemContainer then
                    row.Visible = false
                    row.Size = UDim2.new(1, 0, 0, 0)
                else
                    markerLabel.Text = ""
                    markerLabel.Visible = false
                end
            end
            -- CanvasSize 更新を促す
            pcall(function()
                local layout = musicItemContainer:FindFirstChildOfClass("UIListLayout")
                if layout then
                    musicItemContainer.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 30)
                end
            end)
        else
            -- どうしても見つからない場合のみ警告（ScreenGuiには出さない）
            warn("[tanpopo] Music ItemContainer が見つかりませんでした。アルバムアートは非表示です。")
            AlbumArtContainer:Destroy()
            AlbumArtContainer = nil
            AlbumArtImage = nil
            AlbumArtPlaceholder = nil
        end

        -- 既に選択中の曲があれば表示更新
        if selectedFile then
            updateAlbumArtDisplay(selectedFile.path)
        end
    end)

    local function updateAlbumArtDisplay(filePath)
        if not AlbumArtImage then return end
        if not filePath then
            AlbumArtImage.Visible = false
            if AlbumArtPlaceholder then AlbumArtPlaceholder.Visible = true end
            return
        end

        local artPath = extractAlbumArt(filePath)
        if artPath and getAsset then
            local ok, asset = pcall(getAsset, artPath)
            if ok and asset then
                AlbumArtImage.Image = asset
                AlbumArtImage.Visible = true
                if AlbumArtPlaceholder then AlbumArtPlaceholder.Visible = false end
                return
            end
        end

        AlbumArtImage.Visible = false
        if AlbumArtPlaceholder then AlbumArtPlaceholder.Visible = true end
    end

    -- ▼ サウンド再生コントロール（アルバムアートの下）
    MusicTab:AddSection({ Name = "▼ サウンド再生" })
    MusicTab:AddLabel("📁 music フォルダの mp3 / ogg / wav を再生")

    local fileMap = {}
    local PlayToggleRef = nil
    local MusicDropdown = nil

    local function refreshMusicList()
        local files = getMusicFiles()
        local options = {}
        fileMap = {}
        for _, f in ipairs(files) do
            table.insert(options, f.name)
            fileMap[f.name] = f
        end
        if #options == 0 then
            options = {"(music フォルダに音楽がありません)"}
            selectedFile = nil
        else
            if not selectedFile or not fileMap[selectedFile.name] then
                selectedFile = fileMap[options[1]]
            end
        end
        if MusicDropdown then
            pcall(function()
                MusicDropdown:Refresh(options, true)
            end)
        end
        if selectedFile then
            updateAlbumArtDisplay(selectedFile.path)
        else
            updateAlbumArtDisplay(nil)
        end
        return options
    end

    local initialOptions = refreshMusicList()

    MusicDropdown = MusicTab:AddDropdown({
        Name = "曲を選択",
        Default = initialOptions[1] or "",
        Options = initialOptions,
        Callback = function(Value)
            if Value and fileMap[Value] then
                selectedFile = fileMap[Value]
                updateAlbumArtDisplay(selectedFile.path)
                if isPlaying then
                    playMusicFile(selectedFile)
                end
            end
        end
    })

    if selectedFile then
        updateAlbumArtDisplay(selectedFile.path)
    end

    PlayToggleRef = MusicTab:AddToggle({
        Name = "再生 (Play)",
        Default = false,
        Callback = function(Value)
            isPlaying = Value
            if Value then
                if not selectedFile then
                    Notify("⚠️ 注意", "曲が選択されていません")
                    isPlaying = false
                    if PlayToggleRef then pcall(function() PlayToggleRef:Set(false) end) end
                    return
                end
                playMusicFile(selectedFile)
            else
                stopCurrentSound()
                Notify("⏹ 停止", "再生を止めました")
            end
        end
    })

    MusicTab:AddSlider({
        Name = "音量 (Volume)",
        Min = 0,
        Max = 30,
        Default = 5,
        Color = Color3.fromRGB(180, 120, 255),
        Callback = function(Value)
            volumeValue = Value
            if currentSound then currentSound.Volume = Value / 5 end
        end
    })

    MusicTab:AddButton({
        Name = "🔄 リスト更新 (Refresh)",
        Callback = function()
            local opts = refreshMusicList()
            Notify("更新", #opts .. " 曲を読み込みました")
        end
    })

    MusicTab:AddLabel("💡 mp3 の埋め込みアルバムアートが上に大きく表示されます")
end



-- ============================================================
-- 初期化
-- ============================================================
task.spawn(function()
    task.wait(1)
    if Toggles["Anti-Grab"] then pcall(function() Toggles["Anti-Grab"]:Set(true) end) end
    if Toggles["Anti-Ragdoll"] then pcall(function() Toggles["Anti-Ragdoll"]:Set(true) end) end
    if Toggles["Anti-Lag"] then pcall(function() Toggles["Anti-Lag"]:Set(true) end) end
    pcall(function()
        if AntiLineLag then AntiLineLag.Enabled = false end
        if AntiShuriLag then AntiShuriLag.Enabled = false end
    end)
end)
task.spawn(function() task.wait(0.5) Fun.refreshDanceV2List() end)
plr.CharacterAdded:Connect(OnCharAdded)

-- ============================================================
-- EXTRA: No Blob All (from Neko Resonance short script)
-- ============================================================
do
    local NBATab = Window:MakeTab({Name = "No Blob All", Icon = "zap", PremiumOnly = false})
    local NBA = {
        LagEnabled = false, FixRadius = 80, FixHeight = 32, FixDuration = 5,
        PValue = 1e9, MaxForce = 1e10, AutoCenterTP = true,
        CenterX = 0, CenterY = 32, CenterZ = 0, TiltAngle = 45, running = false
    }
    local lagThread
    local function startLag()
        if NBA.LagEnabled then return end
        NBA.LagEnabled = true
        lagThread = task.spawn(function()
            while NBA.LagEnabled and CreateGrabLine do
                local t = workspace:FindFirstChild("SpawnLocation") or hrp
                if t then
                    pcall(function()
                        CreateGrabLine:FireServer(t, CFrame.new(math.random(-2e9,2e9),0,math.random(-2e9,2e9)))
                    end)
                end
                task.wait(0.05)
            end
        end)
    end
    local function stopLag()
        NBA.LagEnabled = false
        if lagThread then pcall(task.cancel, lagThread) lagThread = nil end
    end
    local function getInnerTiltCFrame(ang, rad, idx, tiltDeg)
        local x, z = math.cos(ang)*rad, math.sin(ang)*rad
        local y = NBA.FixHeight + math.floor(idx/8)*3
        local pos = Vector3.new(NBA.CenterX+x, NBA.CenterY+y, NBA.CenterZ+z)
        local targetPos = Vector3.new(NBA.CenterX, NBA.CenterY, NBA.CenterZ)
        return CFrame.lookAt(pos, targetPos)*CFrame.Angles(-math.rad(tiltDeg),0,0), pos
    end
    NBATab:AddSection({Name = "▼ No Blob All"})
    NBATab:AddButton({Name = "No Blob All 実行", Callback = function()
        if NBA.running then return end
        NBA.running = true
        task.spawn(function()
            startLag()
            local targets = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= plr and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    table.insert(targets, {hrp = p.Character.HumanoidRootPart})
                end
            end
            if #targets == 0 or not hrp then NBA.running = false return end
            for _, t in ipairs(targets) do
                pcall(function() hrp.CFrame = t.hrp.CFrame * CFrame.new(0,0,3) end)
                task.wait(0.16)
                for _ = 1,4 do pcall(function() if SetNetworkOwner then SetNetworkOwner:FireServer(t.hrp, t.hrp.CFrame) end end) task.wait() end
            end
            local step = (2*math.pi)/math.max(#targets,1)
            for i, t in ipairs(targets) do
                if t.hrp.Parent then
                    local cf, pos = getInnerTiltCFrame((i-1)*step, NBA.FixRadius, i, NBA.TiltAngle)
                    pcall(function() t.hrp.CFrame = cf end)
                    local bp = Instance.new("BodyPosition", t.hrp)
                    bp.MaxForce = Vector3.new(NBA.MaxForce,NBA.MaxForce,NBA.MaxForce)
                    bp.P = NBA.PValue; bp.D = 1000; bp.Position = pos
                    local bg = Instance.new("BodyGyro", t.hrp)
                    bg.MaxTorque = Vector3.new(math.huge,math.huge,math.huge)
                    bg.P = 30000; bg.D = 500; bg.CFrame = cf.Rotation
                    task.delay(NBA.FixDuration, function() pcall(function() bp:Destroy() bg:Destroy() end) end)
                    task.wait()
                end
            end
            if NBA.AutoCenterTP and hrp then
                task.wait(0.5)
                pcall(function() hrp.CFrame = CFrame.new(NBA.CenterX, NBA.CenterY+NBA.FixHeight, NBA.CenterZ) end)
            end
            task.wait(1.3)
            for _, t in ipairs(targets) do
                if t.hrp.Parent and CreateGrabLine and DestroyGrabLine then
                    pcall(function()
                        CreateGrabLine:FireServer(t.hrp, CFrame.new(3e9,4e9,2e9))
                        task.wait()
                        DestroyGrabLine:FireServer(t.hrp)
                    end)
                end
            end
            NBA.running = false
            OrionLib:MakeNotification({Name="NBA", Content="完了", Time=3})
        end)
    end})
    NBATab:AddButton({Name = "ラグ停止", Callback = stopLag})
    NBATab:AddToggle({Name = "中心へテレポート", Default = true, Callback = function(v) NBA.AutoCenterTP = v end})
    NBATab:AddSlider({Name = "半径", Min = 1, Max = 200, Default = 80, Callback = function(v) NBA.FixRadius = v end})
    NBATab:AddSlider({Name = "高さ", Min = 0, Max = 200, Default = 32, Callback = function(v) NBA.FixHeight = v end})
    NBATab:AddSlider({Name = "角度", Min = 0, Max = 90, Default = 45, Callback = function(v) NBA.TiltAngle = v end})
    NBATab:AddSection({Name = "▼ Camera"})
    NBATab:AddToggle({Name = "三人称視点", Default = false, Callback = function(v)
        local cam = workspace.CurrentCamera
        if v then
            plr.CameraMode = Enum.CameraMode.Classic
            cam.CameraType = Enum.CameraType.Custom
            cam.CameraSubject = hum
            plr.CameraMaxZoomDistance = 999999
            plr.CameraMinZoomDistance = 0.5
        else
            plr.CameraMode = Enum.CameraMode.LockFirstPerson
            plr.CameraMaxZoomDistance = 0
            plr.CameraMinZoomDistance = 0
        end
    end})
end

-- ============================================================
-- EXTRA: Resonance-priority Anti layer (duplicate OK — user asked for ALL)
-- ============================================================
do
    local RAnti = Window:MakeTab({Name = "R-Anti全", Icon = "shield", PremiumOnly = false})
    RAnti:AddSection({Name = "▼ Resonance優先アンチ（たんぽぽと重複可）"})
    local rFlags = {
        AntiLag=true, AutoAntiLag=true, AntiGrab=true, AntiRagdoll=true,
        AntiFling=true, AntiKick=true, AntiVoid=false, AntiSit=false,
        AntiSticky=false, AntiGucci=true, AntiShuriken=true,
        AntiBurn=true, AntiExplosion=true, AntiPaint=false, AntiBanana=false,
        AntiInput=false, AntiPoison=false, AntiSnowball=false, AntiInvis=false,
        AntiBlobman=false, AntiNet=false,
    }
    local rConns = {}
    local function disc(n) if rConns[n] then pcall(function() rConns[n]:Disconnect() end) rConns[n]=nil end end
    local function applyLag(on)
        local ps = plr:FindFirstChild("PlayerScripts")
        if not ps then return end
        local a = ps:FindFirstChild("CharacterAndBeamMove")
        local b = ps:FindFirstChild("StickyPartsTouchDetection")
        if a then a.Enabled = not on end
        if b then b.Enabled = not on end
    end
    local function bind(name, fn)
        disc(name)
        rConns[name] = RunService.Heartbeat:Connect(fn)
    end
    RAnti:AddToggle({Name="[R] Anti-Lag", Default=true, Callback=function(v) rFlags.AntiLag=v applyLag(v) end})
    RAnti:AddToggle({Name="[R] Auto Anti-Lag", Default=true, Callback=function(v)
        rFlags.AutoAntiLag=v
        if v then bind("AutoLag", function() if rFlags.AutoAntiLag and rFlags.AntiLag and tick()%0.5<0.03 then applyLag(true) end end)
        else disc("AutoLag") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Grab", Default=true, Callback=function(v)
        rFlags.AntiGrab=v
        if v then bind("AG", function()
            if not rFlags.AntiGrab or not hrp or not hum then return end
            if hrp.ReceiveAge ~= 0 then
                hrp.Anchored = true
                if IsHeld then IsHeld.Value = false end
                pcall(function() if Struggle then Struggle:FireServer() end end)
                pcall(function() if RagdollRemote then RagdollRemote:FireServer(hrp,0) end end)
                hum.AutoRotate = true
                hrp.Anchored = false
            end
        end) else disc("AG") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Ragdoll", Default=true, Callback=function(v)
        rFlags.AntiRagdoll=v
        if v then bind("AR", function()
            if not rFlags.AntiRagdoll or not hum or not hrp then return end
            if hum.PlatformStand then hum.PlatformStand=false end
            if hum.Sit and not hum.SeatPart then hum.Sit=false end
            local rd = hum:FindFirstChild("Ragdolled")
            if rd and rd.Value and RagdollRemote then pcall(function() RagdollRemote:FireServer(hrp,0) end) end
        end) else disc("AR") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Fling", Default=true, Callback=function(v)
        rFlags.AntiFling=v
        if v then bind("AF", function()
            if not rFlags.AntiFling or not hrp then return end
            if hrp.AssemblyLinearVelocity.Magnitude > 120 then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end) else disc("AF") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Kick", Default=true, Callback=function(v)
        rFlags.AntiKick=v
        if v then bind("AK", function()
            if not rFlags.AntiKick or not hrp then return end
            -- 異常CFrame/Velocityを抑え、ネットオーナー奪取を粘る
            if hrp.AssemblyLinearVelocity.Magnitude > 200 then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            if SetNetworkOwner then pcall(function() SetNetworkOwner:FireServer(hrp, hrp.CFrame) end) end
            if IsHeld and IsHeld.Value and Struggle then pcall(function() Struggle:FireServer() end) end
        end) else disc("AK") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Void", Default=false, Callback=function(v)
        rFlags.AntiVoid=v
        if v then
            if not etc.originalVoidHeight then etc.originalVoidHeight = workspace.FallenPartsDestroyHeight end
            workspace.FallenPartsDestroyHeight = -1e95
        else
            workspace.FallenPartsDestroyHeight = etc.originalVoidHeight or -500
        end
    end})
    RAnti:AddToggle({Name="[R] Anti-Sit", Default=false, Callback=function(v)
        rFlags.AntiSit=v
        if v then bind("AS", function()
            if rFlags.AntiSit and hum then hum.Sit=false end
        end) else disc("AS") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Sticky", Default=false, Callback=function(v)
        rFlags.AntiSticky=v
        if AntiShuriLag then AntiShuriLag.Enabled = not v end
    end})
    RAnti:AddToggle({Name="[R] Anti-Gucci", Default=true, Callback=function(v)
        rFlags.AntiGucci=v
        if v then bind("GG", function()
            if not rFlags.AntiGucci or not hrp then return end
            for _, d in ipairs(hrp:GetChildren()) do
                if d.Name=="PartOwner" or d.Name:find("Gucci") or d.Name:find("Blob") then pcall(d.Destroy, d) end
            end
        end) else disc("GG") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Shuriken", Default=true, Callback=function(v)
        rFlags.AntiShuriken=v
        if v then bind("SH", function()
            if not rFlags.AntiShuriken or not hrp then return end
            for _, d in ipairs(workspace:GetChildren()) do
                local n = d.Name
                if n:find("Kunai") or n:find("Shuri") or n:find("Ninja") then
                    if d:IsA("Model") or d:IsA("BasePart") then
                        local pos = d:IsA("BasePart") and d.Position or (d.PrimaryPart and d.PrimaryPart.Position)
                        if pos and (pos-hrp.Position).Magnitude < 14 then
                            for _, p in ipairs(d:GetDescendants()) do
                                if p:IsA("BasePart") then p.CanTouch=false p.CanQuery=false p.CanCollide=false end
                            end
                        end
                    end
                end
            end
        end) else disc("SH") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Burn", Default=true, Callback=function(v)
        rFlags.AntiBurn=v
        if v then bind("AB", function()
            if not rFlags.AntiBurn or not hrp then return end
            for _, x in ipairs(hrp:GetChildren()) do
                if x.Name=="FireLight" or x.Name=="FireParticleEmitter" or x.Name=="Fire" then x:Destroy() end
            end
        end) else disc("AB") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Explosion", Default=true, Callback=function(v)
        rFlags.AntiExplosion=v
        if v then bind("AE", function()
            if not rFlags.AntiExplosion or not hrp then return end
            for _, x in ipairs(hrp:GetDescendants()) do
                if x:IsA("Explosion") then x:Destroy() end
            end
        end) else disc("AE") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Paint", Default=false, Callback=function(v) rFlags.AntiPaint=v end})
    RAnti:AddToggle({Name="[R] Anti-Banana", Default=false, Callback=function(v)
        rFlags.AntiBanana=v
        if v then bind("BN", function()
            if not rFlags.AntiBanana then return end
            for _, d in ipairs(workspace:GetChildren()) do
                if d.Name:find("Banana") or d.Name:find("banana") then
                    pcall(function() d:Destroy() end)
                end
            end
        end) else disc("BN") end
    end})
    RAnti:AddToggle({Name="[R] Anti-Input Lag", Default=false, Callback=function(v) rFlags.AntiInput=v end})
    RAnti:AddToggle({Name="[R] Anti-Poison", Default=false, Callback=function(v) rFlags.AntiPoison=v end})
    RAnti:AddToggle({Name="[R] Anti-Snowball", Default=false, Callback=function(v) rFlags.AntiSnowball=v end})
    RAnti:AddToggle({Name="[R] Anti-Invis", Default=false, Callback=function(v) rFlags.AntiInvis=v end})
    RAnti:AddToggle({Name="[R] Anti-Blobman", Default=false, Callback=function(v) rFlags.AntiBlobman=v end})
    RAnti:AddToggle({Name="[R] Anti-Network", Default=false, Callback=function(v)
        rFlags.AntiNet=v
        if v then bind("AN", function()
            if rFlags.AntiNet and hrp and SetNetworkOwner then
                pcall(function() SetNetworkOwner:FireServer(hrp, hrp.CFrame) end)
            end
        end) else disc("AN") end
    end})
    RAnti:AddButton({Name="[R] 全アンチ推奨ON", Callback=function()
        applyLag(true)
        rFlags.AntiLag=true; rFlags.AutoAntiLag=true; rFlags.AntiGrab=true
        rFlags.AntiRagdoll=true; rFlags.AntiFling=true; rFlags.AntiKick=true
        rFlags.AntiGucci=true; rFlags.AntiShuriken=true; rFlags.AntiBurn=true
        OrionLib:MakeNotification({Name="R-Anti", Content="推奨セット ON", Time=3})
    end})
    -- boot defaults
    task.spawn(function()
        task.wait(0.6)
        applyLag(true)
    end)
end

OrionLib:Init()
OrionLib:MakeNotification({Name = "tanpopo&ona1.25hub", Content = "読み込み完了 ("..tostring(math.round(tick() - StartTick1)).."s)", Time = 5})

end

local ok, err = pcall(__runTanpopoFull)
if not ok then
    warn("[Neko FULL]", err)
    pcall(function() Library:Notify({Title="Neko FULL", Description="一部エラー: "..string.sub(tostring(err),1,80), Time=8}) end)
else
    pcall(function() Library:Notify({Title="猫なのは部 FULL", Description="tanpopo ALL + R-Anti ALL + NBA", Time=5}) end)
end
