-- =====================================================
-- ★ ササミックスHUB 🕊️ Complete Edition ★
-- =====================================================
local SaSaHub = loadstring(game:HttpGet("https://raw.githubusercontent.com/jadpy/suki/refs/heads/main/orion"))()
if not SaSaHub then error("Hub Load Failed") end

-- =====================================================
-- >> サービスバインド
-- =====================================================
local sv_Players = game:GetService("Players")
local sv_Local = sv_Players.LocalPlayer
local sv_Run = game:GetService("RunService")
local sv_Workspace = game:GetService("Workspace")
local sv_RepStorage = game:GetService("ReplicatedStorage")
local sv_Input = game:GetService("UserInputService")
local sv_Camera = sv_Workspace.CurrentCamera
local sv_Debris = game:GetService("Debris")

-- =====================================================
-- >> 内部フラグ管理
-- =====================================================
local FLAG = {}
local beam_count = 0
local lag_target = nil
local auto_antilag_enabled = false

local void_protection_active = false
local void_protection_conn = nil
local grab_defense_enabled = false
local grab_defense_nrd_enabled = false
local grab_defense_nrd_processing = false
local nrd_walk_lock = false
local banana_sit_defense_active = false
local banana_sit_defense_thread = nil
local blob_kill_defense_active = false
local blob_kill_defense_thread = nil
local ragdoll_blob_defense_active = false
local ragdoll_blob_defense_connections = {}
local kunai_antikick_active = false
local gucci_mode_active = false
local gucci_cycle_id = 0
local input_lag_defense_thread = nil
local anti_anti_lag_enabled = false
local remove_anti_input_thread = nil
local burn_guard_conn1 = nil
local burn_guard_conn2 = nil
local burn_root_part = nil
local burn_humanoid = nil
local struggle_remote_nrd = nil
local ragdoll_remote_nrd = nil
local is_held_flag = nil
local struggle_event_ref = nil
local godmode = {}
godmode.running = false
godmode.original_fallen_height = sv_Workspace.FallenPartsDestroyHeight
godmode.saved_cframe = nil
godmode.loop_routine = nil
local joint_break_shield_active = false
local joint_break_shield_conn = nil
local joint_break_cache = {}
local input_lag_shield_active = false
local ragdoll_seat_flag = false

-- >> Kick All 設定
local kick_whitelist = {}
local kick_all_wl_label = nil
local kick_all_wl_dropdown = nil
local last_wl_player_list = {}
local kick_all_placement_mode = "circle"
local kick_all_circle_radius = 25
local kick_all_inner_radius = 15
local kick_all_outer_radius = 35
local kick_all_spiral_start = 10
local kick_all_spiral_end = 40
local kick_all_player_y = 100
local kick_all_self_y = 100

-- >> ノーブロブキックオール設定
local noblob_selected_height = "Spawn"
local noblob_line_lag_thread = nil
local noblob_line_lag_enabled = false

-- >> アイテムレジストリ
local ITEM_DB = {
    ["Coconut"] = "FoodCoconut", ["Banana"] = "FoodBanana", ["Fries"] = "FoodFrenchFries",
    ["MeatStick"] = "FoodMeatStick", ["Poop"] = "PoopPile", ["Donut"] = "FoodDonut",
    ["Cake"] = "FoodCakePink", ["Burger"] = "FoodHamburger", ["Pizza"] = "FoodPizzaCheese",
    ["Hotdog"] = "FoodHotdog", ["Mushroom"] = "FoodMushroomPoison", ["Pepperoni"] = "FoodPizzaPepperoni",
    ["Bread"] = "FoodBread", ["Egg"] = "FoodDippyEgg", ["Mayo"] = "FoodMayonnaise",
    ["WhiteMug"] = "CupMugWhite", ["Ocarina"] = "InstrumentWoodwindOcarina",
    ["SparklePoop"] = "PoopPileSparkle", ["BrownMug"] = "CupMugBrown",
    ["Trumpet"] = "InstrumentBrassTrumpet", ["Snare"] = "InstrumentDrumSnare",
}
local item_dropdown_options = {}
for k, _ in pairs(ITEM_DB) do table.insert(item_dropdown_options, k) end
table.sort(item_dropdown_options)
local selected_food_item = "FoodHamburger"

-- =====================================================
-- >> 汎用ユーティリティ
-- =====================================================
local function FindChildSafe(parent, name, timeout)
    return parent:FindFirstChild(name) or parent:WaitForChild(name, timeout or 3)
end

local function FindChildSafeV2(parent, name, timeout)
    return parent:FindFirstChild(name) or parent:WaitForChild(name, timeout or 3)
end

local function StopPartMotion(part)
    if part and part:IsA("BasePart") then
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
        part.Velocity = Vector3.zero
        part.RotVelocity = Vector3.zero
    end
end

local function TakeNetworkControl(target)
    if not target or not target:IsA("BasePart") then return end
    local ge = sv_RepStorage:FindFirstChild("GrabEvents")
    if ge and ge:FindFirstChild("SetNetworkOwner") then
        pcall(function() ge.SetNetworkOwner:FireServer(target, target.CFrame) end)
    end
end

local function SpawnItem(item_name, cframe_pos, velocity_vec)
    local toy_folder = sv_Workspace:FindFirstChild(sv_Local.Name .. 'SpawnedInToys')
    if not toy_folder then return nil end
    local spawned = nil
    local listener
    listener = toy_folder.ChildAdded:Connect(function(obj)
        if obj.Name == item_name then spawned = obj; listener:Disconnect() end
    end)
    task.spawn(function()
        local mt = sv_RepStorage:FindFirstChild("MenuToys")
        if mt and mt:FindFirstChild("SpawnToyRemoteFunction") then
            pcall(function() mt.SpawnToyRemoteFunction:InvokeServer(item_name, cframe_pos, velocity_vec or Vector3.new()) end)
        end
    end)
    local start_t = tick()
    while not spawned and tick() - start_t < 4 do sv_Run.Heartbeat:Wait() end
    if listener then listener:Disconnect() end
    return spawned
end

-- =====================================================
-- >> 防御モジュール: 爆発対策
-- =====================================================
local function EnableExplosionDefense()
    local root = sv_Local.Character and sv_Local.Character:FindFirstChild("HumanoidRootPart")
    local hum = sv_Local.Character and sv_Local.Character:FindFirstChild("Humanoid")
    if not (root and hum and hum:FindFirstChild("Ragdolled")) then return end
    FLAG["exp_def"] = sv_Workspace.ChildAdded:Connect(function(obj)
        if obj.Name == "Part" and (obj.Position - root.Position).Magnitude < 40 and hum.Ragdolled.Value == true then
            root.Anchored = true; task.wait(0.01); root.Anchored = false
            StopPartMotion(root); hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end)
end

local function DisableExplosionDefense()
    if FLAG["exp_def"] then FLAG["exp_def"]:Disconnect(); FLAG["exp_def"] = nil end
end

-- >> 炎上対策
local function EnableBurnDefense()
    local char = sv_Local.Character or sv_Local.CharacterAdded:Wait()
    burn_root_part = char:WaitForChild("HumanoidRootPart", 0.5)
    burn_humanoid = char:WaitForChild("Humanoid", 0.5)
    
    burn_guard_conn2 = sv_Local.CharacterAdded:Connect(function(ch)
        if burn_guard_conn1 then burn_guard_conn1:Disconnect() end
        burn_guard_conn1 = ch:WaitForChild("Humanoid", 0.5).FireDebounce.Changed:Connect(function()
            if ch:WaitForChild("Humanoid", 0.5).FireDebounce.Value == true then
                local barrier = sv_Workspace.Plots.Plot1.Barrier.PlotBarrier
                local saved_pos = barrier.CFrame
                task.spawn(function() repeat task.wait() barrier.CFrame = burn_root_part.CFrame until not burn_humanoid.FireDebounce.Value end)
                task.wait(1); ch:WaitForChild("Humanoid", 0.5).FireDebounce.Value = false
                task.wait(); barrier.CFrame = saved_pos
            end
        end)
    end)
    
    burn_guard_conn1 = sv_Local.Character.Humanoid.FireDebounce.Changed:Connect(function()
        if sv_Local.Character.Humanoid.FireDebounce.Value == true then
            local barrier = sv_Workspace.Plots.Plot1.Barrier.PlotBarrier
            local saved_pos = barrier.CFrame
            task.spawn(function() repeat task.wait() barrier.CFrame = burn_root_part.CFrame until not burn_humanoid.FireDebounce.Value end)
            task.wait(1); sv_Local.Character.Humanoid.FireDebounce.Value = false
            task.wait(); barrier.CFrame = saved_pos
        end
    end)
end

local function DisableBurnDefense()
    if burn_guard_conn1 then burn_guard_conn1:Disconnect() end
    if burn_guard_conn2 then burn_guard_conn2:Disconnect() end
end

-- >> 奈落対策
local function ToggleVoidProtection(state)
    void_protection_active = state
    if void_protection_conn then void_protection_conn:Disconnect(); void_protection_conn = nil end
    if state then
        local THRESH = -50; local SAFE = 100
        void_protection_conn = sv_Run.Heartbeat:Connect(function()
            if not void_protection_active then return end
            local char = sv_Local.Character
            local prim = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
            if prim and prim.Position.Y < THRESH then
                prim.CFrame = CFrame.new(prim.Position.X, prim.Position.Y + SAFE, prim.Position.Z)
                prim.AssemblyLinearVelocity = Vector3.zero
            end
        end)
    end
end

-- >> バナナ座り対策
local function EnableBananaSitDefense()
    banana_sit_defense_active = true
    banana_sit_defense_thread = task.spawn(function()
        while banana_sit_defense_active do
            local char = sv_Local.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                if hum and root and hum.Health > 0 then
                    hum.Sit = true; hum:ChangeState(Enum.HumanoidStateType.Running)
                    local cam = sv_Workspace.CurrentCamera
                    if cam then
                        local lv = cam.CFrame.LookVector
                        root.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(lv.X, 0, lv.Z))
                    end
                end
            end
            task.wait()
        end
    end)
end

local function DisableBananaSitDefense()
    banana_sit_defense_active = false
    if banana_sit_defense_thread then task.cancel(banana_sit_defense_thread); banana_sit_defense_thread = nil end
end

-- >> ブロブマンキル対策
local function EnableBlobKillDefense()
    blob_kill_defense_active = true
    blob_kill_defense_thread = task.spawn(function()
        while blob_kill_defense_active do
            local char = sv_Local.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                if hum and root and hum.Health > 0 then
                    hum.Sit = true; hum:ChangeState(Enum.HumanoidStateType.Running)
                    local cam = sv_Workspace.CurrentCamera
                    if cam then
                        local lv = cam.CFrame.LookVector
                        root.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(lv.X, 0, lv.Z))
                    end
                end
            end
            task.wait()
        end
    end)
end

local function DisableBlobKillDefense()
    blob_kill_defense_active = false
    if blob_kill_defense_thread then task.cancel(blob_kill_defense_thread); blob_kill_defense_thread = nil end
end

-- >> ブロブマンラグドール対策
local function CleanRagBlobConnection(key)
    if ragdoll_blob_defense_connections[key] then
        ragdoll_blob_defense_connections[key]:Disconnect(); ragdoll_blob_defense_connections[key] = nil
    end
end

local function SetupRagBlobCharacter(char)
    local hum = char and char:FindFirstChild("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local rag_remote = sv_RepStorage:FindFirstChild("RagdollRemote") or 
                       (sv_RepStorage:FindFirstChild("CharacterEvents") and 
                        sv_RepStorage.CharacterEvents:FindFirstChild("RagdollRemote"))
    if hum and root and rag_remote then
        CleanRagBlobConnection("SeatWatch")
        ragdoll_blob_defense_connections["SeatWatch"] = hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
            if hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
                if not ragdoll_seat_flag then
                    ragdoll_seat_flag = true
                    local seat = hum.SeatPart
                    while not hum.Sit do task.wait() end
                    rag_remote:FireServer(root, 3)
                    while not (hum:FindFirstChild("Ragdolled") and hum.Ragdolled.Value) and not hum.Sit do task.wait() end
                    task.wait(0.4); hum.Sit = false
                    if seat and seat:IsA("Part") then seat:Sit(hum) end
                    task.delay(0.25, function()
                        while hum and hum.SeatPart do
                            if sv_Local.Character and sv_Local.Character:FindFirstChild("HumanoidRootPart") then
                                rag_remote:FireServer(sv_Local.Character.HumanoidRootPart, 1)
                            end
                            task.wait(0.05)
                        end
                        ragdoll_seat_flag = false
                    end)
                end
            end
        end)
    end
end

local function EnableRagBlobDefense()
    ragdoll_blob_defense_active = true
    SetupRagBlobCharacter(sv_Local.Character or sv_Local.CharacterAdded:Wait())
    CleanRagBlobConnection("CharWatch")
    ragdoll_blob_defense_connections["CharWatch"] = sv_Local.CharacterAdded:Connect(function(newChar)
        task.wait(0.5); SetupRagBlobCharacter(newChar)
    end)
end

local function DisableRagBlobDefense()
    ragdoll_blob_defense_active = false
    for _, c in pairs(ragdoll_blob_defense_connections) do if c then c:Disconnect() end end
    ragdoll_blob_defense_connections = {}
end

-- >> 手裏剣アンチキック
local function PurgeKunai()
    local inv = sv_Workspace:FindFirstChild(sv_Local.Name.."SpawnedInToys")
    local destroy_remote = sv_RepStorage:FindFirstChild("MenuToys") and sv_RepStorage.MenuToys:FindFirstChild("DestroyToy")
    if inv and destroy_remote then
        for _, v in pairs(inv:GetChildren()) do
            if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                pcall(function() destroy_remote:FireServer(v) end)
            end
        end
    end
end

local function EnableKunaiAntiKick()
    kunai_antikick_active = true
    task.spawn(function()
        local set_owner = sv_RepStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
        local sticky_evt = sv_RepStorage:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
        local spawn_rmt = sv_RepStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
        local can_spawn = sv_Local:WaitForChild("CanSpawnToy")
        
        local function GetMyRoot()
            if sv_Local.Character and sv_Local.Character:FindFirstChild("HumanoidRootPart") then
                return sv_Local.Character.HumanoidRootPart
            else
                local c = sv_Local.CharacterAdded:Wait(); return c:WaitForChild("HumanoidRootPart")
            end
        end
        
        local function CheckMyPlot()
            if not sv_Workspace.PlotItems.PlayersInPlots:FindFirstChild(sv_Local.Name) then return false end
            for _, plot in pairs(sv_Workspace.Plots:GetChildren()) do
                local sign = plot:FindFirstChild("PlotSign")
                local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                if owners then
                    for _, b in pairs(owners:GetChildren()) do
                        if b.Value == sv_Local.Name then
                            local folder = sv_Workspace.PlotItems:FindFirstChild(plot.Name)
                            if folder then return true, folder end
                        end
                    end
                end
            end
            return false
        end
        
        local function AttachKunai(kunai)
            if not kunai or not kunai:FindFirstChild("StickyPart") then return end
            local my_root = GetMyRoot()
            if not my_root then return end
            local fire_part = my_root:FindFirstChild("FirePlayerPart") or my_root:WaitForChild("FirePlayerPart", 5)
            if not fire_part then return end
            for _, obj in pairs(kunai:GetChildren()) do
                if obj:IsA("BasePart") then
                    obj.CanTouch = false; obj.CanCollide = false; obj.CanQuery = false
                    obj.AssemblyLinearVelocity = Vector3.zero; obj.AssemblyAngularVelocity = Vector3.zero
                    if obj.Name == "Pyramid" then
                        obj.Transparency = 0
                        if not obj:FindFirstChild("Highlight") then
                            local hl = Instance.new("Highlight", obj); hl.FillColor = Color3.fromRGB(0,0,0)
                        end
                    elseif obj.Name == "Main" then
                        obj.Transparency = 0
                        if not obj:FindFirstChild("Highlight") then
                            local hl = Instance.new("Highlight", obj); hl.FillColor = Color3.fromRGB(255,255,255)
                        end
                    else obj.Transparency = 1 end
                end
            end
            if kunai:FindFirstChild("SoundPart") then
                if not kunai.SoundPart:FindFirstChild("PartOwner") or kunai.SoundPart.PartOwner.Value ~= sv_Local.Name then
                    pcall(function() set_owner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame) end)
                end
            end
            local tcf = fire_part.CFrame * CFrame.Angles(0, math.rad(90), math.rad(90))
            kunai:PivotTo(tcf)
            sticky_evt:FireServer(kunai.StickyPart, fire_part, CFrame.new(0,0,0) * CFrame.Angles(0,math.rad(90),math.rad(90)))
        end
        
        local function DeployKunai()
            local t = tick()
            while not can_spawn.Value do
                if not kunai_antikick_active or tick() - t > 5 then return nil end
                task.wait(0.1)
            end
            local my_root = GetMyRoot()
            if my_root then
                task.spawn(function() pcall(function() spawn_rmt:InvokeServer("NinjaShuriken", my_root.CFrame * CFrame.new(0,2,2), Vector3.zero) end) end)
            end
            local in_plot, house = CheckMyPlot()
            local inv = sv_Workspace:FindFirstChild(sv_Local.Name.."SpawnedInToys")
            if in_plot and house then return house:WaitForChild("NinjaShuriken", 2)
            elseif not sv_Workspace.PlotItems.PlayersInPlots:FindFirstChild(sv_Local.Name) and inv then return inv:WaitForChild("NinjaShuriken", 2) end
            return nil
        end
        
        while kunai_antikick_active do
            task.wait(0.05)
            if not sv_Local.Character or not sv_Local.Character:FindFirstChild("Humanoid") or sv_Local.Character.Humanoid.Health <= 0 then continue end
            local inv = sv_Workspace:FindFirstChild(sv_Local.Name.."SpawnedInToys")
            local kunai = inv and (inv:FindFirstChild("NinjaShuriken") or inv:FindFirstChild("AntiKick"))
            
            if sv_Workspace.PlotItems.PlayersInPlots:FindFirstChild(sv_Local.Name) then
                local in_plot, house = CheckMyPlot()
                if in_plot and house and sv_Workspace.Plots:FindFirstChild(house.Name) then
                    local sign = sv_Workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                    if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                        if not kunai then kunai = DeployKunai() end
                        if kunai then kunai.Name = "AntiKick"; AttachKunai(kunai) end
                    end
                end
            end
            
            if not kunai then
                if sv_Workspace.PlotItems.PlayersInPlots:FindFirstChild(sv_Local.Name) then continue end
                kunai = DeployKunai()
                if kunai then kunai.Name = "AntiKick" else continue end
            end
            
            if kunai and kunai:FindFirstChild("StickyPart") then
                local welded = kunai.StickyPart:FindFirstChild("StickyWeld") and kunai.StickyPart.StickyWeld.Part1 ~= nil
                if not welded and kunai.StickyPart.CanTouch == true then
                    AttachKunai(kunai); kunai.Name = "AntiKick"; task.wait(0.1)
                end
                if sv_Local.Character and sv_Local.Character:FindFirstChild("HumanoidRootPart") then
                    if (sv_Local.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20 then PurgeKunai() end
                end
            end
        end
        PurgeKunai()
    end)
end

local function DisableKunaiAntiKick()
    kunai_antikick_active = false; PurgeKunai()
end

-- >> ジョイント破壊アンチキック
local function EnableJointBreakShield()
    joint_break_shield_active = true
    local safe_pos = CFrame.new(-272.2197265625, -7.350403785705566, 475.0108947753906)
    sv_Workspace.FallenPartsDestroyHeight = 0/0
    joint_break_cache = {}
    local root_part = nil
    
    local function BreakJoints()
        local char = sv_Local.Character
        if not char then return end
        root_part = char:WaitForChild("HumanoidRootPart")
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("Motor6D") then joint_break_cache[v] = v.Part0; v.Part0 = nil end
        end
        root_part.CFrame = safe_pos
        joint_break_shield_conn = sv_Run.RenderStepped:Connect(function()
            if root_part and root_part.Parent then
                root_part.AssemblyLinearVelocity = Vector3.zero; root_part.AssemblyAngularVelocity = Vector3.zero
            end
        end)
    end
    
    local function RestoreJoints()
        if joint_break_shield_conn then joint_break_shield_conn:Disconnect(); joint_break_shield_conn = nil end
        for m, p0 in pairs(joint_break_cache) do if m and m.Parent then m.Part0 = p0 end end
        joint_break_cache = {}
    end
    
    local function ToggleOnce()
        if not joint_break_shield_active then return end
        if joint_break_shield_conn then RestoreJoints() else BreakJoints() end
    end
    
    ToggleOnce(); task.wait(0.12); ToggleOnce()
    sv_Local.CharacterAdded:Once(function()
        task.wait(0.25)
        if joint_break_shield_active then ToggleOnce(); task.wait(0.12); ToggleOnce() end
    end)
end

local function DisableJointBreakShield()
    joint_break_shield_active = false
    if joint_break_shield_conn then joint_break_shield_conn:Disconnect(); joint_break_shield_conn = nil end
    for m, p0 in pairs(joint_break_cache) do if m and m.Parent then m.Part0 = p0 end end
    joint_break_cache = {}
    sv_Workspace.FallenPartsDestroyHeight = -100
end

-- >> アンチラグ
local function EnableAntiLagSystem()
    pcall(function() sv_Local.PlayerScripts.CharacterAndBeamMove.Enabled = false end)
end

local function DisableAntiLagSystem()
    pcall(function() sv_Local.PlayerScripts.CharacterAndBeamMove.Enabled = true end)
end

local auto_antilag_thread = nil
local function EnableAutoAntiLag()
    auto_antilag_enabled = true
    auto_antilag_thread = task.spawn(function()
        while auto_antilag_enabled do
            task.wait(0.5)
            if beam_count > 100 then
                pcall(function() sv_Local.PlayerScripts.CharacterAndBeamMove.Enabled = false end)
                beam_count = 0
            end
        end
    end)
end

local function DisableAutoAntiLag()
    auto_antilag_enabled = false
    if auto_antilag_thread then task.cancel(auto_antilag_thread); auto_antilag_thread = nil end
    pcall(function() sv_Local.PlayerScripts.CharacterAndBeamMove.Enabled = true end)
end

sv_Workspace.DescendantAdded:Connect(function(obj)
    if obj.Name == "GrabBeam" then
        beam_count = beam_count + 1
        lag_target = obj.Parent and obj.Parent.Parent and obj.Parent.Parent.Parent
    end
end)

-- >> アンチスティッキー
local function EnableAntiStickySystem()
    pcall(function() sv_Local.PlayerScripts.StickyPartsTouchDetection.Enabled = false end)
end

local function DisableAntiStickySystem()
    pcall(function() sv_Local.PlayerScripts.StickyPartsTouchDetection.Enabled = true end)
end

-- >> アンチグラブ通常
task.spawn(function()
    local cev = sv_RepStorage:WaitForChild("CharacterEvents", 10)
    if cev then struggle_event_ref = cev:WaitForChild("Struggle", 5) end
    is_held_flag = sv_Local:WaitForChild("IsHeld", 10)
end)

local function GrabDefenseLoop()
    if not grab_defense_enabled then return end
    local char = sv_Local.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if is_held_flag and is_held_flag.Value == true then
        pcall(function() if struggle_event_ref then struggle_event_ref:FireServer(sv_Local) end end)
        root.Velocity = Vector3.zero; root.Anchored = true
    else root.Anchored = false end
end

sv_Run.Heartbeat:Connect(GrabDefenseLoop)

local function EnableGrabDefense() grab_defense_enabled = true end
local function DisableGrabDefense()
    grab_defense_enabled = false
    local char = sv_Local.Character
    if char then local root = char:FindFirstChild("HumanoidRootPart"); if root then root.Anchored = false end end
end

-- >> アンチグラブNRD
local nrd_connections = {}

local function PurgeNRDConnections()
    for _, c in ipairs(nrd_connections) do pcall(function() c:Disconnect() end) end
    nrd_connections = {}
end

local function SetupGrabNRD(char)
    if not grab_defense_nrd_enabled then return end
    local root = FindChildSafeV2(char, "HumanoidRootPart", 5)
    local hum = FindChildSafeV2(char, "Humanoid", 5)
    local head = FindChildSafeV2(char, "Head", 5)
    if not root or not hum or not head then return end
    
    local po_conn = head.ChildAdded:Connect(function(obj)
        if not grab_defense_nrd_enabled then return end
        if obj and obj.Name == "PartOwner" then
            if not grab_defense_nrd_processing then
                grab_defense_nrd_processing = true
                pcall(function() hum.Sit = false end)
                pcall(function() if struggle_remote_nrd then struggle_remote_nrd:FireServer(sv_Local) end end)
                
                task.spawn(function()
                    while grab_defense_nrd_enabled and (head and head:FindFirstChild("PartOwner")) do
                        pcall(function() if struggle_remote_nrd then struggle_remote_nrd:FireServer(sv_Local) end end)
                        pcall(function() if ragdoll_remote_nrd then ragdoll_remote_nrd:FireServer(root, 0) end end)
                        task.wait()
                    end
                end)
                
                pcall(function() root.Anchored = true end)
                
                if not nrd_walk_lock then
                    nrd_walk_lock = true
                    while grab_defense_nrd_enabled and task.wait() do
                        local hf = sv_Local:FindFirstChild("IsHeld")
                        if not hf or not hf.Value then break end
                        pcall(function() if hum and hum.MoveDirection then root.CFrame = root.CFrame + hum.MoveDirection * 0.43 end end)
                    end
                    nrd_walk_lock = false
                end
                
                pcall(function() root.Anchored = false end)
                grab_defense_nrd_processing = false
            end
        end
    end)
    table.insert(nrd_connections, po_conn)
    
    local rag_val = FindChildSafeV2(hum, "Ragdolled", 3)
    if rag_val then
        local rag_conn = rag_val.Changed:Connect(function()
            if not grab_defense_nrd_enabled then return end
            if rag_val.Value then
                for _, v in pairs(char:GetChildren()) do
                    if v:IsA("BasePart") and v:FindFirstChild("BallSocketConstraint") and v.Name ~= "Head" then
                        pcall(function() v.BallSocketConstraint.Enabled = false end)
                        if v:FindFirstChild("RagdollLimbPart") then
                            pcall(function() v.RagdollLimbPart.WeldConstraint.Enabled = false end)
                        end
                    end
                end
            end
        end)
        table.insert(nrd_connections, rag_conn)
    end
    
    local whrp = FindChildSafeV2(root, "WeldHRP", 3)
    if whrp then
        local wc = whrp.Changed:Connect(function()
            if not grab_defense_nrd_enabled then return end
            if whrp.Enabled then
                while not hum.Sit do task.wait() end
                pcall(function() hum.Sit = false; hum.AutoRotate = true; hum.HipHeight = 1 end)
                while whrp.Enabled and task.wait() do
                    pcall(function() head.CFrame = root.CFrame + Vector3.new(0, 1.35, 0) end)
                end
                pcall(function() hum.HipHeight = 0 end)
            end
        end)
        table.insert(nrd_connections, wc)
    end
end

local function EnableGrabDefenseNRD()
    grab_defense_nrd_enabled = true; PurgeNRDConnections()
    task.spawn(function()
        local ce = sv_RepStorage:FindFirstChild("CharacterEvents")
        if ce then struggle_remote_nrd = ce:FindFirstChild("Struggle"); ragdoll_remote_nrd = ce:FindFirstChild("RagdollRemote") end
    end)
    if sv_Local.Character then task.defer(function() SetupGrabNRD(sv_Local.Character) end) end
end

local function DisableGrabDefenseNRD()
    grab_defense_nrd_enabled = false; grab_defense_nrd_processing = false; nrd_walk_lock = false; PurgeNRDConnections()
end

-- >> GODMODE
local function EnableFallenProtection()
    godmode.original_fallen_height = sv_Workspace.FallenPartsDestroyHeight
    sv_Workspace.FallenPartsDestroyHeight = 0/0
end

local function DisableFallenProtection()
    sv_Workspace.FallenPartsDestroyHeight = godmode.original_fallen_height ~= nil and godmode.original_fallen_height or -100
end

local function TeleportToSavedPosition()
    local char = sv_Local.Character
    if char and godmode.saved_cframe then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = godmode.saved_cframe end
    end
end

local function ExecuteGodCycle()
    local char = sv_Local.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if godmode.saved_cframe == nil then godmode.saved_cframe = root.CFrame end
    local orig = root.CFrame
    local st = tick()
    local rad = 10000
    while tick() - st < 1 and godmode.running do
        if not sv_Local.Character or not root.Parent then return end
        local t = tick() * 12
        root.CFrame = orig + Vector3.new(math.cos(t) * rad, -10000, math.sin(t) * rad)
        sv_Run.RenderStepped:Wait()
    end
    if godmode.running and root and root.Parent then root.CFrame = orig end
end

local function StartGodMode()
    if godmode.running then return end
    godmode.running = true
    local char = sv_Local.Character
    if char then local root = char:FindFirstChild("HumanoidRootPart"); if root then godmode.saved_cframe = root.CFrame end end
    EnableFallenProtection()
    godmode.loop_routine = coroutine.wrap(function()
        while godmode.running do
            if not sv_Local.Character then task.wait(0.5) else ExecuteGodCycle() end
            task.wait(0.0001)
        end
    end)
    godmode.loop_routine()
end

local function StopGodMode()
    godmode.running = false; godmode.loop_routine = nil
    TeleportToSavedPosition(); DisableFallenProtection()
end

sv_Local.CharacterAdded:Connect(function(char)
    if godmode.running then
        task.wait(0.1)
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = CFrame.new(0, -15000, 0) end
    end
end)

-- >> Gucciアンチグラブ
local function ActivateGucciDefense()
    gucci_cycle_id = gucci_cycle_id + 1
    local my_id = gucci_cycle_id
    local setup_done = false
    
    local char = sv_Local.Character or sv_Local.CharacterAdded:Wait()
    local hum = FindChildSafe(char, "Humanoid")
    local root = FindChildSafe(char, "HumanoidRootPart")
    if not (hum and root) then return end
    
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
    
    task.spawn(function()
        local t = tick()
        while tick() - t < 0.8 and my_id == gucci_cycle_id do
            if root and root.Parent then root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero end
            sv_Run.Heartbeat:Wait()
        end
    end)
    
    local blob = SpawnItem("CreatureBlobman", root.CFrame * CFrame.new(0, 0, -5), Vector3.new(0, -15.716, 0))
    if not blob then return end
    
    local bhead = FindChildSafe(blob, "Head")
    local hitbox = FindChildSafe(blob, "GrabbableHitbox")
    local seat = FindChildSafe(blob, "VehicleSeat")
    
    task.spawn(function()
        local st = tick()
        while my_id == gucci_cycle_id and not setup_done and tick() - st < 1.2 do
            if hitbox and hitbox.Parent then TakeNetworkControl(hitbox) end
            if bhead and bhead.Parent then TakeNetworkControl(bhead) end
            if seat and seat.Parent and seat.Occupant ~= hum then pcall(function() seat:Sit(hum) end) end
            local ce = sv_RepStorage:FindFirstChild("CharacterEvents")
            if ce and ce:FindFirstChild("RagdollRemote") then pcall(function() ce.RagdollRemote:FireServer(root, 0.09) end) end
            sv_Run.Heartbeat:Wait()
        end
    end)
    
    task.wait(0.45)
    if my_id ~= gucci_cycle_id then if blob and blob.Parent then blob:Destroy() end; return end
    setup_done = true
    
    pcall(function() hum.Sit = false end)
    if seat and seat.Parent then
        seat.Disabled = true; seat.CanTouch = false; seat.CanQuery = false
        for _, v in pairs(seat:GetChildren()) do if v:IsA("Weld") or v.Name == "SeatWeld" then v:Destroy() end end
    end
    
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end); task.wait(0.05)
    local ce = sv_RepStorage:FindFirstChild("CharacterEvents")
    if ce and ce:FindFirstChild("RagdollRemote") then pcall(function() ce.RagdollRemote:FireServer(root, false) end) end
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    
    blob.Name = "Gucci"
    for _, v in pairs(blob:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = false; v.CanTouch = false; v.CanQuery = false; v.Massless = true end
    end
    
    task.spawn(function()
        while my_id == gucci_cycle_id and bhead and bhead.Parent do
            if bhead and bhead.Parent then bhead.CFrame = CFrame.new(bhead.Position.X, 100000, bhead.Position.Z) end
            sv_Run.Heartbeat:Wait()
        end
    end)
    
    gucci_mode_active = true
end

local function DeactivateGucciDefense()
    gucci_cycle_id = gucci_cycle_id + 1; gucci_mode_active = false
    local tf = sv_Workspace:FindFirstChild(sv_Local.Name .. 'SpawnedInToys')
    if tf then for _, v in pairs(tf:GetChildren()) do if v.Name == "Gucci" or v.Name == "CreatureBlobman" then pcall(function() v:Destroy() end) end end end
end

-- >> 入力ラグ対策
local function QuickItemCycle(hold_rmt, drop_rmt, item, char, high_pos)
    task.spawn(function() hold_rmt:InvokeServer(item, char); sv_Run.Heartbeat:Wait(); drop_rmt:InvokeServer(item, high_pos, high_pos) end)
end

local function EnableInputLagDefense()
    input_lag_shield_active = true
    input_lag_defense_thread = task.spawn(function()
        while input_lag_shield_active do
            local char = sv_Local.Character or sv_Local.CharacterAdded:Wait()
            local root = char:WaitForChild("HumanoidRootPart")
            local spawn_rmt = sv_RepStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
            local toys = sv_Workspace:FindFirstChild(sv_Local.Name .. "SpawnedInToys")
            if not toys then task.wait(0.1); continue end

            local toy = toys:FindFirstChild(selected_food_item)
            if not toy then
                pcall(function() spawn_rmt:InvokeServer(selected_food_item, root.CFrame * CFrame.new(0,5,0), Vector3.zero) end)
                local t0 = tick()
                repeat sv_Run.Heartbeat:Wait(); toys = sv_Workspace:FindFirstChild(sv_Local.Name .. "SpawnedInToys"); toy = toys and toys:FindFirstChild(selected_food_item) until toy or tick() - t0 > 1
            end
            
            if toy and toy.Parent then
                local hp = toy:FindFirstChild("HoldPart")
                if hp then
                    local holder = hp:FindFirstChild("HoldingPlayer")
                    holder = holder and holder.Value
                    if holder and holder ~= sv_Local then
                        pcall(function() hp.DropItemRemoteFunction:InvokeServer(toy, root.CFrame * CFrame.new(0,2000,0), Vector3.zero) end)
                        toy:Destroy()
                    else
                        QuickItemCycle(hp.HoldItemRemoteFunction, hp.DropItemRemoteFunction, toy, char, root.CFrame * CFrame.new(0,2000,0))
                    end
                end
            end
            sv_Run.Heartbeat:Wait()
        end
    end)
end

local function DisableInputLagDefense()
    input_lag_shield_active = false
    if input_lag_defense_thread then task.cancel(input_lag_defense_thread); input_lag_defense_thread = nil end
end

-- >> 全アイテム削除
local function EnableGlobalItemCleaner()
    anti_anti_lag_enabled = true
    remove_anti_input_thread = task.spawn(function()
        local valid_items = { 
            FoodHamburger = true, FoodCoconut = true, FoodPizzaCheese = true, FoodPizzaPepperoni = true,
            FoodHotdog = true, FoodMushroomPoison = true, FoodBread = true, FoodDippyEgg = true,
            FoodMayonnaise = true, FoodFrenchFries = true, FoodMeatStick = true, FoodDonut = true,
            FoodCakePink = true, InstrumentGuitarBanjo = true, InstrumentGuitarViolin = true,
            InstrumentGuitarUkulele = true, InstrumentWoodwindSaxophone = true, InstrumentWoodwindOcarina = true,
            InstrumentBrassVuvuzelaQwizik = true, InstrumentBrassTrumpet = true, InstrumentDrumBongos = true,
            InstrumentDrumSnare = true, InstrumentPianoMelodica = true, InstrumentVoiceMicrophone = true,
            CupMugWhite = true, CupMugBrown = true, PoopPile = true, PoopPileSparkle = true 
        }
        local items = {}
        
        local desc_conn = sv_Workspace.DescendantAdded:Connect(function(obj)
            if valid_items[obj.Name] and obj:IsA("Model") then
                task.spawn(function() if obj:WaitForChild("HoldPart", 3) then table.insert(items, obj) end end)
            end
        end)
        
        for _, v in ipairs(sv_Workspace:GetDescendants()) do
            if valid_items[v.Name] and v:IsA("Model") and v:FindFirstChild("HoldPart") then table.insert(items, v) end
        end
        
        while anti_anti_lag_enabled do
            local char = sv_Local.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for i = #items, 1, -1 do
                    local b = items[i]
                    if not b or not b.Parent or not b:FindFirstChild("HoldPart") then table.remove(items, i)
                    else
                        local hp = b.HoldPart
                        pcall(function() hp.HoldItemRemoteFunction:InvokeServer(b, char) end); task.wait()
                        pcall(function() hp.DropItemRemoteFunction:InvokeServer(b, CFrame.new(root.Position + Vector3.new(0,-2000,0)), Vector3.zero) end)
                    end
                end
            end
            task.wait()
        end
        desc_conn:Disconnect()
    end)
end

local function DisableGlobalItemCleaner()
    anti_anti_lag_enabled = false
    if remove_anti_input_thread then task.cancel(remove_anti_input_thread); remove_anti_input_thread = nil end
end

-- =====================================================
-- >> グラブ機能
-- =====================================================
local throw_connection = nil
local throw_power = 400
local poison_grab_routine = nil
local ufo_grab_routine = nil
local fire_grab_routine = nil
local poison_parts = {}
local paint_parts = {}

for _, d in ipairs(sv_Workspace:GetDescendants()) do
    if d.Name == "PoisonHurtPart" then table.insert(poison_parts, d)
    elseif d.Name == "PaintPlayerPart" then table.insert(paint_parts, d) end
end

local function GrabEffectLoop(effect_type)
    while true do
        pcall(function()
            local gp = sv_Workspace:FindFirstChild("GrabParts")
            if gp and gp.Name == "GrabParts" then
                local grab_part = gp:FindFirstChild("GrabPart")
                if grab_part and grab_part:FindFirstChild("WeldConstraint") then
                    local target = grab_part.WeldConstraint.Part1
                    local head = target and target.Parent and target.Parent:FindFirstChild("Head")
                    if head then
                        local parts = effect_type == "poison" and poison_parts or paint_parts
                        for _, p in pairs(parts) do p.Size = Vector3.new(2,2,2); p.Transparency = 1; p.Position = head.Position end
                        task.wait()
                        for _, p in pairs(parts) do p.Position = Vector3.new(0,-200,0) end
                    end
                end
            end
        end)
        task.wait()
    end
end

local function FireGrabLoop()
    while true do
        pcall(function()
            local gp = sv_Workspace:FindFirstChild("GrabParts")
            if gp and gp.Name == "GrabParts" then
                local grab_part = gp:FindFirstChild("GrabPart")
                if grab_part and grab_part:FindFirstChild("WeldConstraint") then
                    local target = grab_part.WeldConstraint.Part1
                    local head = target and target.Parent and target.Parent:FindFirstChild("Head")
                    if head then
                        local toys = sv_Workspace:FindFirstChild(sv_Local.Name .. "SpawnedInToys")
                        if toys and not toys:FindFirstChild("Campfire") then
                            local sr = sv_RepStorage:FindFirstChild("MenuToys") and sv_RepStorage.MenuToys:FindFirstChild("SpawnToyRemoteFunction")
                            if sr then pcall(function() sr:InvokeServer("Campfire", sv_Local.Character.Head.CFrame, Vector3.new(0,90,0)) end) end
                        end
                        local cf = toys and toys:FindFirstChild("Campfire")
                        if cf then
                            local bp = cf:FindFirstChild("FirePlayerPart")
                            if bp then bp.Size = Vector3.new(7,7,7); bp.Position = head.Position; task.wait(0.3); bp.Position = Vector3.new(0,-50,0) end
                        end
                    end
                end
            end
        end)
        task.wait()
    end
end

local GrabModeFlags = { KillGrab = false, SkyGrab = false, DownGrab = false, StableGrab = false }
local GrabModeConns = {}

local function ProcessGrabMode(model, mode)
    if model.Name == "GrabParts" then
        local part = model:FindFirstChild("GrabPart")
        if part and part:FindFirstChild("WeldConstraint") then
            local target = part.WeldConstraint.Part1
            if target then
                if mode == "Kill" then
                    local hum = target.Parent and target.Parent:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Health = 0 end
                elseif mode == "Sky" then
                    local bv = Instance.new("BodyVelocity", target)
                    bv.Velocity = Vector3.new(0,50,0); bv.MaxForce = Vector3.new(0,math.huge,0); sv_Debris:AddItem(bv, 1)
                elseif mode == "Down" then
                    local bv = Instance.new("BodyVelocity", target)
                    bv.Velocity = Vector3.new(0,-50,0); bv.MaxForce = Vector3.new(0,math.huge,0); sv_Debris:AddItem(bv, 1)
                elseif mode == "Stable" then
                    local oy = target.Position.Y
                    local bp = Instance.new("BodyPosition", target)
                    bp.P = 5000; bp.D = 1000; bp.MaxForce = Vector3.new(0,math.huge,0); bp.Position = Vector3.new(target.Position.X, oy, target.Position.Z)
                    task.spawn(function()
                        while sv_Workspace:FindFirstChild("GrabParts") and target and target.Parent do
                            bp.Position = Vector3.new(target.Position.X, oy, target.Position.Z); task.wait(0.05)
                        end
                        bp:Destroy()
                    end)
                end
            end
        end
    end
end

local function ToggleGrabMode(flag, mode)
    if GrabModeFlags[flag] then
        if GrabModeConns[flag] then GrabModeConns[flag]:Disconnect() end
        GrabModeConns[flag] = sv_Workspace.ChildAdded:Connect(function(m) ProcessGrabMode(m, mode) end)
    else
        if GrabModeConns[flag] then GrabModeConns[flag]:Disconnect(); GrabModeConns[flag] = nil end
    end
end

local ExtendedGrabFlags = { NoclipGrab = false, KillGrabExt = false }

local function ProcessExtendedGrab(model)
    if model.Name == "GrabParts" then
        local part = model:FindFirstChild("GrabPart")
        if part and part:FindFirstChild("WeldConstraint") then
            local target = part.WeldConstraint.Part1
            if target then
                local tchar = target.Parent
                if ExtendedGrabFlags.KillGrabExt and tchar then
                    local hum = tchar:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Health = 0 end
                end
                if ExtendedGrabFlags.NoclipGrab and tchar then
                    for _, bp in pairs(tchar:GetDescendants()) do if bp:IsA("BasePart") then bp.CanCollide = false end end
                    model.AncestryChanged:Connect(function(_, parent)
                        if not parent and tchar then
                            for _, bp in pairs(tchar:GetDescendants()) do if bp:IsA("BasePart") then bp.CanCollide = true end end
                        end
                    end)
                end
            end
        end
    end
end

local ext_grab_conn = sv_Workspace.ChildAdded:Connect(ProcessExtendedGrab)

-- =====================================================
-- >> ループボイド
-- =====================================================
local void_loop_target = nil
local void_loop_active = false
local void_loop_interval = 1.5
local void_loop_conn = nil
local void_loop_timer = 0
local void_loop_dropdown = nil
local void_loop_toggle_ref = nil

local function GetVoidLoopRoot()
    local c = sv_Local.Character or sv_Local.CharacterAdded:Wait()
    return c:FindFirstChild("HumanoidRootPart")
end

local function SetNetOwner(part, cf)
    if not part then return end
    pcall(function()
        local ge = sv_RepStorage:FindFirstChild("GrabEvents")
        if ge and ge:FindFirstChild("SetNetworkOwner") then ge.SetNetworkOwner:FireServer(part, cf or GetVoidLoopRoot().CFrame) end
    end)
end

local function ApplyVelocityBurst(part, vel)
    if not part or not part.Parent then return end
    local bv = Instance.new("BodyVelocity", part)
    bv.MaxForce = Vector3.new(1e8,1e8,1e8); bv.Velocity = vel; sv_Debris:AddItem(bv, 1)
end

local function ExecuteVoidLoop(target)
    local char = target.Character
    if not char then return end
    local troot = char:FindFirstChild("HumanoidRootPart")
    if not troot or not troot.Parent then return end
    local saved = GetVoidLoopRoot().CFrame
    task.spawn(function()
        for _, pn in pairs({"Head","Torso","HumanoidRootPart"}) do
            local p = sv_Local.Character:FindFirstChild(pn); if p then p.CanCollide = false end
        end
        GetVoidLoopRoot().CFrame = CFrame.new(troot.Position.X, troot.Position.Y - 6, troot.Position.Z)
        task.wait(0.1)
        sv_Workspace.CurrentCamera.CFrame = CFrame.lookAt(sv_Workspace.CurrentCamera.CFrame.Position, troot.Position)
        for _ = 1, 4 do SetNetOwner(troot, GetVoidLoopRoot().CFrame); task.wait(0.05) end
        local look = sv_Workspace.CurrentCamera.CFrame
        task.wait(0.1); ApplyVelocityBurst(troot, Vector3.new(0,10000,0))
        sv_Workspace.CurrentCamera.CFrame = look
        task.wait(0.1)
        for _, pn in pairs({"Head","Torso","HumanoidRootPart"}) do
            local p = sv_Local.Character:FindFirstChild(pn); if p then p.CanCollide = true end
        end
        GetVoidLoopRoot().CFrame = saved; ApplyVelocityBurst(GetVoidLoopRoot(), Vector3.zero)
    end)
end

local function StartVoidLoop()
    if void_loop_conn then void_loop_conn:Disconnect(); void_loop_conn = nil end
    void_loop_active = true; void_loop_timer = 0
    SaSaHub:MakeNotification({Name = "Void Loop Start", Content = "Target: " .. (void_loop_target and void_loop_target.DisplayName or "???"), Time = 3})
    void_loop_conn = sv_Run.Heartbeat:Connect(function(dt)
        void_loop_timer = void_loop_timer + dt
        if void_loop_timer >= void_loop_interval then
            if void_loop_target and void_loop_target.Character and void_loop_active then task.spawn(ExecuteVoidLoop, void_loop_target) end
            void_loop_timer = 0
        end
    end)
end

local function StopVoidLoop()
    void_loop_active = false
    if void_loop_conn then void_loop_conn:Disconnect(); void_loop_conn = nil end
    SaSaHub:MakeNotification({Name = "Void Loop Stop", Content = "Stopped", Time = 2})
end

local function GetPlayerListFormatted()
    local list = {}
    for _, p in pairs(sv_Players:GetPlayers()) do if p ~= sv_Local then table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")") end end
    return list
end

local function ExtractPlayerName(display_str)
    if not display_str then return nil end
    local name = display_str:match("%@(.*)%)")
    return name and sv_Players:FindFirstChild(name) or nil
end

local function SetVoidLoopTarget(display_str)
    void_loop_target = ExtractPlayerName(display_str)
    if void_loop_target then SaSaHub:MakeNotification({Name = "Void Loop", Content = "Target: " .. void_loop_target.DisplayName, Time = 2})
    else SaSaHub:MakeNotification({Name = "Void Loop", Content = "Target Set Failed", Time = 2}) end
end

local function OnVoidTargetLeft(player)
    if void_loop_target == player then
        void_loop_target = nil
        if void_loop_active then StopVoidLoop(); if void_loop_toggle_ref then void_loop_toggle_ref:Set(false) end end
        SaSaHub:MakeNotification({Name = "Void Loop", Content = "Target left server", Time = 3})
        if void_loop_dropdown then void_loop_dropdown:Refresh(GetPlayerListFormatted(), true) end
    end
end

local function OnVoidPlayerJoined()
    if void_loop_dropdown then void_loop_dropdown:Refresh(GetPlayerListFormatted(), true) end
end

sv_Players.PlayerRemoving:Connect(OnVoidTargetLeft)
sv_Players.PlayerAdded:Connect(OnVoidPlayerJoined)

-- =====================================================
-- >> Blobmanモジュール
-- =====================================================
local BlobSystem = {}

function BlobSystem.GetMyChar() return sv_Local.Character end
function BlobSystem.GetMyRoot()
    local c = BlobSystem.GetMyChar()
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
end
function BlobSystem.GetMyHumanoid()
    local c = BlobSystem.GetMyChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
function BlobSystem.GetInventory() return sv_Workspace:FindFirstChild(sv_Local.Name .. "SpawnedInToys") end
function BlobSystem.ClaimPart(part)
    local ge = sv_RepStorage:FindFirstChild("GrabEvents")
    if ge and ge:FindFirstChild("SetNetworkOwner") then
        local root = BlobSystem.GetMyRoot()
        if root then ge.SetNetworkOwner:FireServer(part, root.CFrame) end
    end
end
function BlobSystem.ReleaseGrab(part)
    local ge = sv_RepStorage:FindFirstChild("GrabEvents")
    if ge and ge:FindFirstChild("DestroyGrabLine") then ge.DestroyGrabLine:FireServer(part) end
end
function BlobSystem.FindBlobman()
    local inv = BlobSystem.GetInventory()
    if inv then
        local v = inv:FindFirstChild("CreatureBlobman")
        if v and v:FindFirstChild("VehicleSeat") then return v end
    end
    local pi = sv_Workspace:FindFirstChild("PlotItems")
    if pi then
        for _, p in pairs(pi:GetChildren()) do
            local m = p:FindFirstChild("CreatureBlobman")
            if m and m:FindFirstChild("PlayerValue") and m.PlayerValue.Value == sv_Local.Name then return m end
        end
    end
    return nil
end
function BlobSystem.SpawnBlobman()
    local mt = sv_RepStorage:FindFirstChild("MenuToys")
    if mt and mt:FindFirstChild("SpawnToyRemoteFunction") then
        local root = BlobSystem.GetMyRoot()
        if root then
            mt.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", root.CFrame, Vector3.zero)
            task.wait(1.0)
            return BlobSystem.FindBlobman()
        end
    end
    return nil
end
function BlobSystem.DestroyBlobman()
    local blob = BlobSystem.FindBlobman()
    if blob then
        local mt = sv_RepStorage:FindFirstChild("MenuToys")
        if mt and mt:FindFirstChild("DestroyToy") then mt.DestroyToy:FireServer(blob) end
    end
end
function BlobSystem.IsSeatedOnBlob()
    local hum = BlobSystem.GetMyHumanoid()
    if not hum then return false end
    local blob = BlobSystem.FindBlobman()
    if not blob or not blob:FindFirstChild("VehicleSeat") then return false end
    return hum.Sit and hum.SeatPart == blob.VehicleSeat
end
function BlobSystem.ForceSitOnBlob()
    local blob = BlobSystem.FindBlobman()
    if not blob or not blob:FindFirstChild("VehicleSeat") then return false end
    local seat = blob.VehicleSeat
    local hum = BlobSystem.GetMyHumanoid()
    if hum and not hum.Sit then
        seat:Sit(hum)
        task.wait(0.6)
    end
    return BlobSystem.IsSeatedOnBlob()
end
function BlobSystem.GrabWithBlob(blob, target, side)
    if not blob then return end
    local det = blob:FindFirstChild(side .. "Detector")
    if not det then return end
    local weld = det:FindFirstChild(side .. "Weld")
    if not weld then return end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript", true)
    if not script then return end
    local remote = script:FindFirstChild("CreatureGrab")
    if remote then pcall(function() remote:FireServer(det, target, weld) end) end
end
function BlobSystem.DropWithBlob(blob, target, side)
    if not blob then return end
    local det = blob:FindFirstChild(side .. "Detector")
    if not det then return end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript", true)
    if not script then return end
    local remote = script:FindFirstChild("CreatureDrop")
    if remote then pcall(function() remote:FireServer(det, target) end) end
end
function BlobSystem.ExecuteKick(blob, target_root, side)
    BlobSystem.GrabWithBlob(blob, BlobSystem.GetMyRoot(), side)
    task.wait(0.08)
    BlobSystem.ClaimPart(target_root)
    task.wait(0.08)
    target_root.CFrame = target_root.CFrame + Vector3.new(0, 16, 0)
    task.wait(0.08)
    BlobSystem.ReleaseGrab(target_root)
    task.wait(0.08)
    BlobSystem.GrabWithBlob(blob, target_root, side)
    task.wait(0.08)
    BlobSystem.DropWithBlob(blob, target_root, side)
    task.wait(0.08)
    BlobSystem.ReleaseGrab(target_root)
end

-- =====================================================
-- >> Arkadia Spam Kick Module
-- =====================================================
arkadia_active = false
arkadia_thread = nil
arkadia_adj_x = 0
arkadia_adj_y = 23
arkadia_adj_z = 0
arkadia_radius = 18
arkadia_speed = 0.15
arkadia_angle = 0
arkadia_init_pos = nil
arkadia_captured = false
arkadia_grab_toggle = false
arkadia_target_name = nil

function Arkadia_GetToys() return sv_Workspace:FindFirstChild(sv_Local.Name .. "SpawnedInToys") end
function Arkadia_GetBlob() local f = Arkadia_GetToys(); return f and f:FindFirstChild("CreatureBlobman") end
function Arkadia_Spawn()
    local c = sv_Local.Character; local r = c and c:FindFirstChild("HumanoidRootPart")
    if not r then return end
    local cf = r.CFrame * CFrame.new(0,0,-5)
    local mt = sv_RepStorage:FindFirstChild("MenuToys")
    if mt and mt:FindFirstChild("SpawnToyRemoteFunction") then pcall(function() mt.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", cf, Vector3.new(0,90,0)) end) end
end
function Arkadia_Destroy()
    local b = Arkadia_GetBlob()
    if b then local mt = sv_RepStorage:FindFirstChild("MenuToys"); if mt and mt:FindFirstChild("DestroyToy") then pcall(function() mt.DestroyToy:FireServer(b) end) end end
end

function Arkadia_MainLoop(tname)
    local init_pos = nil; local captured = false; local gt = false; local ang = 0
    while arkadia_active do
        local ct = sv_Players:FindFirstChild(tname)
        local blob = Arkadia_GetBlob()
        local char = sv_Local.Character; local hum = char and char:FindFirstChild("Humanoid")
        if not blob then Arkadia_Spawn(); captured = false; task.wait(0.5); continue end
        local seat = blob:FindFirstChildOfClass("VehicleSeat") or blob:FindFirstChildOfClass("Seat")
        if seat and hum and hum.SeatPart ~= seat then seat:Sit(hum) end
        local tc = ct and ct.Character; local tr = tc and tc:FindFirstChild("HumanoidRootPart")
        local th = tc and tc:FindFirstChild("Humanoid"); local br = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
        if tr and th and th.Health > 0 and br then
            if not init_pos then init_pos = tr.Position end
            local cp = init_pos + Vector3.new(arkadia_adj_x, arkadia_adj_y, arkadia_adj_z)
            if not captured then tr.CFrame = CFrame.new(cp); th.PlatformStand = true
                local ge = sv_RepStorage:FindFirstChild("GrabEvents")
                if ge and ge:FindFirstChild("SetNetworkOwner") then ge.SetNetworkOwner:FireServer(tr, tr.CFrame) end
                task.wait(0.1); captured = true
            end
            ang = ang + arkadia_speed
            local ox = math.cos(ang) * arkadia_radius; local oz = math.sin(ang) * arkadia_radius
            br.CFrame = CFrame.new(cp + Vector3.new(ox,0,oz), cp); br.Velocity = Vector3.zero; tr.CFrame = CFrame.new(cp)
            pcall(function()
                local so = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                if so then
                    local cg = so:FindFirstChild("CreatureGrab"); local cd = so:FindFirstChild("CreatureDrop")
                    local rd = blob:FindFirstChild("RightDetector"); local w = rd and (rd:FindFirstChild("RightWeld") or rd:FindFirstChildWhichIsA("Weld"))
                    if w then cd:FireServer(w) end
                    gt = not gt; local tg = gt and tr or br
                    local ge = sv_RepStorage:FindFirstChild("GrabEvents")
                    if ge and ge:FindFirstChild("SetNetworkOwner") then ge.SetNetworkOwner:FireServer(tr, tr.CFrame) end
                    if ge and ge:FindFirstChild("DestroyGrabLine") then ge.DestroyGrabLine:FireServer(tr) end
                    if cg and rd and w then cg:FireServer(rd, tg, w) end
                end
            end)
        else init_pos = nil; captured = false end
        sv_Run.Heartbeat:Wait()
    end
    Arkadia_Destroy()
end

function StartArkadia(tname)
    if arkadia_active then SaSaHub:MakeNotification({Name="Arkadia",Content="Already running",Time=2}); return end
    if not tname then SaSaHub:MakeNotification({Name="Error",Content="No target",Time=2}); return end
    local t = sv_Players:FindFirstChild(tname)
    if not t then SaSaHub:MakeNotification({Name="Error",Content="Target not found: "..tname,Time=3}); return end
    arkadia_active = true; arkadia_angle = 0; arkadia_init_pos = nil; arkadia_captured = false; arkadia_grab_toggle = false
    arkadia_thread = task.spawn(function() Arkadia_MainLoop(tname) end)
    SaSaHub:MakeNotification({Name="Arkadia",Content="Started: "..tname,Time=3})
end

function StopArkadia()
    arkadia_active = false
    if arkadia_thread then task.cancel(arkadia_thread); arkadia_thread = nil end
    Arkadia_Destroy()
    SaSaHub:MakeNotification({Name="Arkadia",Content="Stopped",Time=2})
end

function SetArkadiaRadius(v) arkadia_radius = v end
function SetArkadiaSpeed(v) arkadia_speed = v / 100 end
function SetArkadiaHeight(v) arkadia_adj_y = v end
function SetArkadiaOffsetX(v) arkadia_adj_x = v end
function SetArkadiaOffsetZ(v) arkadia_adj_z = v end
function ResetArkadiaPosition()
    arkadia_adj_x = 0; arkadia_adj_y = 23; arkadia_adj_z = 0; arkadia_radius = 18; arkadia_speed = 0.15; arkadia_angle = 0
    SaSaHub:MakeNotification({Name="Reset",Content="Position reset",Time=2})
end

-- =====================================================
-- >> 旧式/新式 キック
-- =====================================================
local old_kick_running = false

local function ExecuteOldKick(tname)
    if not tname then SaSaHub:MakeNotification({Name="Error",Content="Select player",Time=3}); return end
    local t = sv_Players:FindFirstChild(tname)
    if not t then SaSaHub:MakeNotification({Name="Error",Content="Player not found",Time=3}); return end
    if not t.Character or not t.Character:FindFirstChild("HumanoidRootPart") then SaSaHub:MakeNotification({Name="Error",Content="No character",Time=3}); return end
    old_kick_running = true
    task.spawn(function()
        local blob = nil
        local sp = sv_Workspace:FindFirstChild(sv_Local.Name .. "SpawnedInToys")
        if sp then blob = sp:FindFirstChild("CreatureBlobman") end
        if not blob then
            local mt = sv_RepStorage:FindFirstChild("MenuToys"); local st = mt and mt:FindFirstChild("SpawnToyRemoteFunction")
            if st then
                local mr = sv_Local.Character and sv_Local.Character:FindFirstChild("HumanoidRootPart")
                local scf = mr and (mr.CFrame + Vector3.new(0,5,0)) or CFrame.new(0,50,0)
                st:InvokeServer("CreatureBlobman", scf, Vector3.zero); task.wait(0.5)
                sp = sv_Workspace:FindFirstChild(sv_Local.Name .. "SpawnedInToys")
                if sp then blob = sp:FindFirstChild("CreatureBlobman") end
            end
        end
        if not blob then
            for _, obj in ipairs(sv_Workspace:GetChildren()) do
                if obj.Name == "CreatureBlobman" and obj:FindFirstChild("VehicleSeat") then blob = obj; break end
            end
        end
        if blob then
            local so = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
            local gr = so and so:FindFirstChild("CreatureGrab"); local dr = so and so:FindFirstChild("CreatureDrop")
            local ld = blob:FindFirstChild("LeftDetector"); local rd = blob:FindFirstChild("RightDetector")
            local lw = ld and (ld:FindFirstChild("LeftWeld") or ld:FindFirstChild("RigidConstraint"))
            local rw = rd and (rd:FindFirstChild("RightWeld") or rd:FindFirstChild("RigidConstraint"))
            local seat = blob:FindFirstChild("VehicleSeat"); local hum = sv_Local.Character and sv_Local.Character:FindFirstChild("Humanoid")
            if seat and hum then
                if seat.Occupant ~= hum then sv_Local.Character.HumanoidRootPart.CFrame = seat.CFrame + Vector3.new(0,2,0); seat:Sit(hum); task.wait(0.3) end
            end
            if gr and dr and ((ld and lw) or (rd and rw)) then
                SaSaHub:MakeNotification({Name="Execute",Content="Old Kick Start",Time=2})
                local ge = sv_RepStorage:WaitForChild("GrabEvents"); local br = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
                local saved = br.CFrame; local Det = rd or ld; local Weld = rw or lw
                local bs = tick()
                while tick() - bs < 0.35 do
                    if not old_kick_running or not blob or not blob.Parent then break end
                    if t.Character and t.Character:FindFirstChild("HumanoidRootPart") then
                        local tr = t.Character.HumanoidRootPart; br.CFrame = tr.CFrame; br.AssemblyLinearVelocity = Vector3.zero
                        pcall(function() if Det then gr:FireServer(Det, tr, Weld) end; ge.CreateGrabLine:FireServer(tr, Vector3.zero, tr.Position, false); ge.SetNetworkOwner:FireServer(tr, br.CFrame) end)
                    end
                    sv_Run.Heartbeat:Wait()
                end
                if br then br.CFrame = saved; br.AssemblyLinearVelocity = Vector3.zero; task.wait(0.05) end
                while old_kick_running and blob and blob.Parent do
                    if not t or not t.Parent or not t.Character then break end
                    local tc = t.Character; local tr = tc:FindFirstChild("HumanoidRootPart"); local th = tc:FindFirstChild("Humanoid")
                    if tr and th and th.Health > 0 and br then
                        br.CFrame = saved; br.AssemblyLinearVelocity = Vector3.zero
                        local lp = saved * CFrame.new(0,23,0); tr.CFrame = lp; tr.AssemblyLinearVelocity = Vector3.zero; tr.AssemblyAngularVelocity = Vector3.zero
                        pcall(function()
                            th.PlatformStand = true; th.Sit = true; ge.SetNetworkOwner:FireServer(tr, lp)
                            local cw = Det:FindFirstChild("RightWeld") or Det:FindFirstChild("LeftWeld") or Det:FindFirstChildWhichIsA("Weld") or Det:FindFirstChild("RigidConstraint")
                            if cw then dr:FireServer(cw) end
                            ge.DestroyGrabLine:FireServer(tr); if Det then gr:FireServer(Det, tr, Weld) end; ge.CreateGrabLine:FireServer(tr, Vector3.zero, tr.Position, false)
                        end)
                    else if br then br.CFrame = saved; br.AssemblyLinearVelocity = Vector3.zero end end
                    sv_Run.Heartbeat:Wait()
                end
                if br then br.CFrame = saved; br.AssemblyLinearVelocity = Vector3.zero end
                BlobSystem.DestroyBlobman(); old_kick_running = false
                SaSaHub:MakeNotification({Name="Done",Content="Old Kick End",Time=2})
            end
        else SaSaHub:MakeNotification({Name="Error",Content="Blobman not found",Time=3}); old_kick_running = false end
    end)
end

local function ExecuteNewKick(tname)
    if not tname then SaSaHub:MakeNotification({Name="Error",Content="Select player",Time=3}); return end
    local tp = sv_Players:FindFirstChild(tname)
    if not tp then SaSaHub:MakeNotification({Name="Error",Content="Player not found",Time=3}); return end
    local tc = tp.Character; if not tc then SaSaHub:MakeNotification({Name="Error",Content="No character",Time=3}); return end
    local tr = tc:FindFirstChild("HumanoidRootPart"); if not tr then SaSaHub:MakeNotification({Name="Error",Content="No HRP",Time=3}); return end
    local blob = BlobSystem.FindBlobman()
    if not blob then blob = BlobSystem.SpawnBlobman(); if not blob then SaSaHub:MakeNotification({Name="Error",Content="Blob spawn failed",Time=4}); return end end
    if not BlobSystem.IsSeatedOnBlob() then BlobSystem.ForceSitOnBlob(); if not BlobSystem.IsSeatedOnBlob() then SaSaHub:MakeNotification({Name="Error",Content="Sit failed",Time=3}); return end end
    local mr = BlobSystem.GetMyRoot()
    if mr and tr then local op = mr.CFrame; mr.CFrame = tr.CFrame; task.wait(0.07); BlobSystem.ExecuteKick(blob, tr, "Left"); task.wait(0.15); mr.CFrame = op end
    BlobSystem.DestroyBlobman()
    SaSaHub:MakeNotification({Name="Success",Content=tp.DisplayName .. " kicked (New)",Time=3})
end

-- >> Kick All (完全版)
local function IsWhitelisted(player)
    if not player then return false end
    return kick_whitelist[player.Name] == true
end

local function GetNonWhitelistedPlayers()
    local list = {}
    for _, p in ipairs(sv_Players:GetPlayers()) do
        if p ~= sv_Local and not IsWhitelisted(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(list, p)
        end
    end
    return list
end

local function GetWLPlayerList()
    local list = {}
    for _, p in pairs(sv_Players:GetPlayers()) do
        if p ~= sv_Local then
            table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")")
        end
    end
    return list
end

local function UpdateWLDropdownAuto()
    if not kick_all_wl_dropdown then return end
    local cp = GetWLPlayerList()
    local changed = false
    if #cp ~= #last_wl_player_list then changed = true
    else for i, v in ipairs(cp) do if last_wl_player_list[i] ~= v then changed = true; break end end end
    if changed then last_wl_player_list = cp; kick_all_wl_dropdown:Refresh(cp, true) end
end

local function UpdateWLUI()
    local list = {}
    for name in pairs(kick_whitelist) do table.insert(list, name) end
    if #list == 0 then
        if kick_all_wl_label then kick_all_wl_label:Set("保護リスト", "現在ホワイトリストは空です") end
    else
        if kick_all_wl_label then kick_all_wl_label:Set("保護リスト", "保護中: " .. table.concat(list, ", ")) end
    end
end

local function WaitForBlobmanAndRide()
    for i = 1, 30 do
        task.wait(0.1)
        local blob = BlobSystem.FindBlobman()
        if blob then
            local seat = blob:FindFirstChild("VehicleSeat")
            if seat then
                local hum = BlobSystem.GetMyHumanoid()
                if hum then
                    seat:Sit(hum)
                    task.wait(0.2)
                    if hum.SeatPart == seat then return blob end
                end
            end
        end
    end
    return nil
end

local function SpawnAndRideBlobman()
    local root = BlobSystem.GetMyRoot()
    if not root then return nil end
    local spawnPos = root.CFrame * CFrame.new(0, 0, -8)
    local mt = sv_RepStorage:FindFirstChild("MenuToys")
    if mt and mt:FindFirstChild("SpawnToyRemoteFunction") then
        pcall(function() mt.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", spawnPos, Vector3.new(0, 27.4, 0)) end)
    end
    return WaitForBlobmanAndRide()
end

local function GrabReleaseTarget(blob, target)
    if not blob or not target or not target.Character or IsWhitelisted(target) then return end
    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    if not script then return end
    pcall(function()
        if script:FindFirstChild("CreatureGrab") and blob:FindFirstChild("LeftDetector") then
            script.CreatureGrab:FireServer(blob.LeftDetector, targetRoot, blob.LeftDetector.LeftWeld)
        end
        if script:FindFirstChild("CreatureRelease") and blob:FindFirstChild("LeftDetector") then
            script.CreatureRelease:FireServer(blob.LeftDetector.LeftWeld)
        end
    end)
end

local function KickBoth(blob, target)
    if not blob or not target or not target.Character or IsWhitelisted(target) then return end
    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    local script = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    if not script or not script:FindFirstChild("CreatureGrab") then return end
    pcall(function()
        script.CreatureGrab:FireServer(blob.LeftDetector, targetRoot, blob.LeftDetector.LeftWeld)
        script.CreatureGrab:FireServer(blob.RightDetector, targetRoot, blob.RightDetector.RightWeld)
    end)
end

local function DoGrab(targetPart)
    if not targetPart then return false end
    local ge = sv_RepStorage:FindFirstChild("GrabEvents")
    if not ge then return false end
    pcall(function()
        if ge:FindFirstChild("SetNetworkOwner") then ge.SetNetworkOwner:FireServer(targetPart, CFrame.new(targetPart.Position)) end
        if ge:FindFirstChild("DestroyGrabLine") then ge.DestroyGrabLine:FireServer(targetPart) end
    end)
    return true
end

local function AnchorBlob(blob)
    if not blob then return end
    for _, part in ipairs(blob:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.Anchored = true end) end
    end
end

local function UnanchorBlob(blob)
    if not blob then return end
    for _, part in ipairs(blob:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.Anchored = false end) end
    end
end

local function GetCirclePositions(center, radius, count)
    local positions = {}
    if count == 0 then return positions end
    local angleStep = (math.pi * 2) / count
    for i = 1, count do
        local angle = (i - 1) * angleStep
        table.insert(positions, {x = center.X + radius * math.cos(angle), z = center.Z + radius * math.sin(angle)})
    end
    return positions
end

local function GetDoubleCirclePositions(center, innerR, outerR, count)
    local positions = {}
    if count == 0 then return positions end
    local halfCount = math.floor(count / 2)
    local innerCount, outerCount = halfCount, count - halfCount
    local innerStep = (math.pi * 2) / math.max(innerCount, 1)
    for i = 1, innerCount do
        local a = (i - 1) * innerStep
        table.insert(positions, {x = center.X + innerR * math.cos(a), z = center.Z + innerR * math.sin(a)})
    end
    local outerStep = (math.pi * 2) / math.max(outerCount, 1)
    for i = 1, outerCount do
        local a = (i - 1) * outerStep + (math.pi / outerCount)
        table.insert(positions, {x = center.X + outerR * math.cos(a), z = center.Z + outerR * math.sin(a)})
    end
    return positions
end

local function GetSpiralPositions(center, startR, endR, count)
    local positions = {}
    if count == 0 then return positions end
    for i = 1, count do
        local t = (i - 1) / math.max(count - 1, 1)
        local radius = startR + (endR - startR) * t
        local angle = (i - 1) * (math.pi * 2 / count) * 3
        table.insert(positions, {x = center.X + radius * math.cos(angle), z = center.Z + radius * math.sin(angle)})
    end
    return positions
end

local function TeleportPlayersToPositions(players, centerX, centerZ, getPosFunc, ...)
    local positions = getPosFunc({X = centerX, Z = centerZ}, ...)
    for i, target in ipairs(players) do
        if target.Character and positions[i] then
            local root = target.Character:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = CFrame.new(positions[i].x, kick_all_player_y, positions[i].z) end
        end
    end
end

local function ExecuteKickAll()
    local allPlayers = GetNonWhitelistedPlayers()
    if #allPlayers == 0 then
        SaSaHub:MakeNotification({Name = "エラー", Content = "キック対象のプレイヤーがいません", Time = 2})
        return
    end
    
    SaSaHub:MakeNotification({Name = "実行", Content = #allPlayers .. "人をキック開始", Time = 2})
    
    local blob = SpawnAndRideBlobman()
    if not blob then
        SaSaHub:MakeNotification({Name = "エラー", Content = "Blobmanに乗れませんでした", Time = 3})
        return
    end
    
    task.wait(0.3)
    local myRoot = BlobSystem.GetMyRoot()
    if not myRoot then return end
    
    for _, target in ipairs(allPlayers) do
        local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            myRoot.CFrame = targetRoot.CFrame
            task.wait(0.02)
            BlobSystem.ClaimPart(targetRoot)
            for j = 1, 3 do
                GrabReleaseTarget(blob, target)
                if j < 3 then task.wait(0.08) end
            end
        end
    end
    
    myRoot.CFrame = CFrame.new(0, kick_all_self_y, 0)
    task.wait(0.1)
    AnchorBlob(blob)
    task.wait(0.1)
    
    local cx, cz = 0, 0
    if kick_all_placement_mode == "circle" then
        TeleportPlayersToPositions(allPlayers, cx, cz, GetCirclePositions, kick_all_circle_radius, #allPlayers)
    elseif kick_all_placement_mode == "double" then
        TeleportPlayersToPositions(allPlayers, cx, cz, GetDoubleCirclePositions, kick_all_inner_radius, kick_all_outer_radius, #allPlayers)
    elseif kick_all_placement_mode == "spiral" then
        TeleportPlayersToPositions(allPlayers, cx, cz, GetSpiralPositions, kick_all_spiral_start, kick_all_spiral_end, #allPlayers)
    end
    
    task.wait(0.1)
    
    for _, target in ipairs(allPlayers) do
        local tr = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if tr then DoGrab(tr) end
    end
    task.wait(0.1)
    for _, target in ipairs(allPlayers) do
        local tr = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if tr then DoGrab(tr) end
    end
    
    task.wait(0.3)
    for i = 1, 3 do
        for _, target in ipairs(allPlayers) do
            KickBoth(blob, target)
        end
        if i < 3 then task.wait(0.08) end
    end
    
    task.wait(0.1)
    UnanchorBlob(blob)
    
    SaSaHub:MakeNotification({Name = "Kick All 完了", Content = #allPlayers .. "人をキック", Time = 4})
end

-- =====================================================
-- >> ノーブロブキックオール (新バージョン)
-- =====================================================
local function NoblobGetAllPlayers()
    local players = {}
    for _, plr in pairs(sv_Players:GetPlayers()) do
        if plr ~= sv_Local then table.insert(players, plr) end
    end
    return players
end

local function NoblobSpamOwnership(hrp)
    local ge = sv_RepStorage:FindFirstChild("GrabEvents")
    if not ge then return end
    local setOwner = ge:FindFirstChild("SetNetworkOwner")
    if setOwner and hrp then pcall(function() setOwner:FireServer(hrp, hrp.CFrame) end) end
end

local function NoblobTeleportToPlayer(myHrp, targetHrp)
    if not myHrp or not targetHrp then return end
    pcall(function()
        myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 5, 5)
        myHrp.AssemblyLinearVelocity = Vector3.zero
    end)
end

local function NoblobDestroyLineOnPlayer(hrp)
    local ge = sv_RepStorage:FindFirstChild("GrabEvents")
    if not ge then return end
    local createLine = ge:FindFirstChild("CreateGrabLine")
    local destroyLine = ge:FindFirstChild("DestroyGrabLine")
    if not createLine or not destroyLine then return end
    pcall(function()
        createLine:FireServer(hrp, CFrame.new(0, 1e9, 0))
        task.wait()
        destroyLine:FireServer(hrp)
    end)
end

local function NoblobStartLineLag()
    if noblob_line_lag_enabled then return end
    noblob_line_lag_enabled = true
    noblob_line_lag_thread = coroutine.create(function()
        local ge = sv_RepStorage:FindFirstChild("GrabEvents")
        if not ge then return end
        local createLine = ge:FindFirstChild("CreateGrabLine")
        if not createLine then return end
        while noblob_line_lag_enabled do
            local spawnLocation = sv_Workspace:FindFirstChild("SpawnLocation") or sv_Workspace:FindFirstChild("Spawn") or (sv_Local.Character and sv_Local.Character:FindFirstChild("HumanoidRootPart"))
            if spawnLocation then
                local randomX = math.random(-1e9, 1e9)
                local randomZ = math.random(-1e9, 1e9)
                local directions = {CFrame.new(randomX, 0, randomZ), CFrame.new(-randomX, 0, -randomZ), CFrame.new(randomX, 0, -randomZ), CFrame.new(-randomX, 0, randomZ)}
                for _, pos in pairs(directions) do createLine:FireServer(spawnLocation, pos) end
            end
            task.wait()
        end
    end)
    coroutine.resume(noblob_line_lag_thread)
end

local function NoblobStopLineLag()
    noblob_line_lag_enabled = false
    if noblob_line_lag_thread then coroutine.close(noblob_line_lag_thread); noblob_line_lag_thread = nil end
end

local function ExecuteNoblobKickAll()
    task.spawn(function()
        local height = (noblob_selected_height == "Heaven") and 1e9 or 35
        NoblobStartLineLag()
        task.wait(1)

        local players = NoblobGetAllPlayers()
        if #players == 0 then
            NoblobStopLineLag()
            SaSaHub:MakeNotification({Name = "ノーブロブキックオール", Content = "対象プレイヤーがいません", Time = 3})
            return
        end

        local myChar = sv_Local.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHrp then NoblobStopLineLag(); return end

        local playerData = {}
        for _, plr in ipairs(players) do
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then table.insert(playerData, {player = plr, hrp = hrp}) end
        end

        for _, data in ipairs(playerData) do
            NoblobTeleportToPlayer(myHrp, data.hrp)
            task.wait(0.2)
            NoblobSpamOwnership(data.hrp)
            task.wait()
        end

        local radius = 40
        local angleStep = (math.pi * 2) / #playerData
        for idx, data in ipairs(playerData) do
            local angle = (idx - 1) * angleStep
            local x = math.cos(angle) * radius
            local z = math.sin(angle) * radius

            pcall(function()
                data.hrp.CFrame = CFrame.new(x, height, z)
                data.hrp.AssemblyLinearVelocity = Vector3.zero
            end)

            local bp = Instance.new("BodyPosition")
            bp.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bp.P = 40000000
            bp.Position = Vector3.new(x, height, z)
            bp.Parent = data.hrp
            task.delay(2, function() pcall(function() bp:Destroy() end) end)
            task.wait()
        end

        for i = 1, 8 do
            for _, data in ipairs(playerData) do NoblobDestroyLineOnPlayer(data.hrp) end
            task.wait(0.3)
        end
        
        SaSaHub:MakeNotification({Name = "ノーブロブキックオール", Content = "キックオール完了！ラグは継続中です。", Time = 2})
    end)
end

local function NoblobStopLag()
    NoblobStopLineLag()
    SaSaHub:MakeNotification({Name = "ノーブロブキックオール", Content = "ラグ処理を停止しました", Time = 2})
end

-- =====================================================
-- >> UI構築
-- =====================================================
local MainWindow = SaSaHub:MakeWindow({
    Name = "ササミックスHUB 🕊️ Complete",
    HidePremium = true, SaveConfig = false, IntroEnabled = true,
    IntroText = "🕊️ Loading...", IntroIcon = "rbxassetid://4483345998"
})

-- =====================================================
-- >> 掴むタブ
-- =====================================================
local GrabTab = MainWindow:MakeTab({Name = "掴む", Icon = "rbxassetid://73570431850302"})

GrabTab:AddToggle({Name = "投げる", Default = false, Callback = function(v)
    if v then
        throw_connection = sv_Workspace.ChildAdded:Connect(function(model)
            if model.Name == "GrabParts" then
                local pt = model:FindFirstChild("GrabPart")
                if pt and pt:FindFirstChild("WeldConstraint") then
                    pt = pt.WeldConstraint.Part1
                    if pt then
                        local bv = Instance.new("BodyVelocity", pt)
                        model:GetPropertyChangedSignal("Parent"):Connect(function()
                            if not model.Parent then
                                local li = sv_Input:GetLastInputType()
                                if li == Enum.UserInputType.MouseButton2 or li == Enum.UserInputType.Touch then
                                    bv.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
                                    bv.Velocity = sv_Workspace.CurrentCamera.CFrame.LookVector * throw_power
                                    sv_Debris:AddItem(bv, 1)
                                else bv:Destroy() end
                            end
                        end)
                    end
                end
            end
        end)
    elseif throw_connection then throw_connection:Disconnect(); throw_connection = nil end
end})

GrabTab:AddSlider({Name = "投げる強さ", Min = 300, Max = 4000, Default = 400, Callback = function(v) throw_power = v end})

GrabTab:AddToggle({Name = "毒掴む", Default = false, Callback = function(v)
    if v then poison_grab_routine = coroutine.create(function() GrabEffectLoop("poison") end); coroutine.resume(poison_grab_routine)
    else if poison_grab_routine then coroutine.close(poison_grab_routine); poison_grab_routine = nil; for _, p in pairs(poison_parts) do p.Position = Vector3.new(0,-200,0) end end end
end})

GrabTab:AddToggle({Name = "Radioactive掴む", Default = false, Callback = function(v)
    if v then ufo_grab_routine = coroutine.create(function() GrabEffectLoop("radioactive") end); coroutine.resume(ufo_grab_routine)
    else if ufo_grab_routine then coroutine.close(ufo_grab_routine); ufo_grab_routine = nil; for _, p in pairs(paint_parts) do p.Position = Vector3.new(0,-200,0) end end end
end})

GrabTab:AddToggle({Name = "燃やす掴む", Default = false, Callback = function(v)
    if v then fire_grab_routine = coroutine.create(FireGrabLoop); coroutine.resume(fire_grab_routine)
    else if fire_grab_routine then coroutine.close(fire_grab_routine); fire_grab_routine = nil end end
end})

GrabTab:AddToggle({Name = "キルグラブ", Default = false, Callback = function(v) ExtendedGrabFlags.KillGrabExt = v end})
GrabTab:AddToggle({Name = "Noclipグラブ", Default = false, Callback = function(v) ExtendedGrabFlags.NoclipGrab = v end})
GrabTab:AddToggle({Name = "キル掴む", Default = false, Callback = function(v) GrabModeFlags.KillGrab = v; ToggleGrabMode("KillGrab", "Kill") end})
GrabTab:AddToggle({Name = "上に上がる掴む", Default = false, Callback = function(v) GrabModeFlags.SkyGrab = v; ToggleGrabMode("SkyGrab", "Sky") end})
GrabTab:AddToggle({Name = "下に下がる掴む", Default = false, Callback = function(v) GrabModeFlags.DownGrab = v; ToggleGrabMode("DownGrab", "Down") end})
GrabTab:AddToggle({Name = "高さを保ちながら掴む", Default = false, Callback = function(v) GrabModeFlags.StableGrab = v; ToggleGrabMode("StableGrab", "Stable") end})

-- =====================================================
-- >> バリア破壊タブ
-- =====================================================
local BarrierTab = MainWindow:MakeTab({Name = "バリア破壊", Icon = "rbxassetid://4483362458"})
BarrierTab:AddSection({Name = "バリア破壊機能"})
BarrierTab:AddButton({Name = "実行", Callback = function()
    local p = sv_Local
    if not (p.Character and p.Character:FindFirstChild("HumanoidRootPart")) then SaSaHub:MakeNotification({Name="Error",Content="Character not ready",Time=4}); return end
    local hum = p.Character:FindFirstChildOfClass("Humanoid"); local ows, ojp
    if hum then ows = hum.WalkSpeed; ojp = hum.JumpPower; pcall(function() hum.WalkSpeed = 0; hum.JumpPower = 0 end) end
    local ok, err = pcall(function()
        local mt = sv_RepStorage:WaitForChild("MenuToys"); local hrp = p.Character.HumanoidRootPart; local ocf = hrp.CFrame
        hrp.CFrame = CFrame.new(246.052, -7.35, 431.821); task.wait(0.05)
        mt.SpawnToyRemoteFunction:InvokeServer("InstrumentWoodwindOcarina", CFrame.new(184.148834, -5.54824972, 498.136749, 0.829037189, -0.214714944, 0.516328275, 0, 0.923344612, 0.383972496, -0.559193552, -0.318327487, 0.765486956), Vector3.new(0, 34, 0))
        task.wait(0.2)
        local tf = sv_Workspace:FindFirstChild(p.Name .. "SpawnedInToys"); if not tf then error("No folder") end
        local oc = tf:FindFirstChild("InstrumentWoodwindOcarina"); if not oc then error("No item") end
        if oc:FindFirstChild("HoldPart") and oc.HoldPart:FindFirstChild("HoldItemRemoteFunction") then pcall(function() oc.HoldPart.HoldItemRemoteFunction:InvokeServer(oc, p.Character) end); task.wait(0.2) end
        p.Character.HumanoidRootPart.CFrame = CFrame.new(304.06, 25.77, 488.54); task.wait(0.05)
        if mt:FindFirstChild("DestroyToy") then mt.DestroyToy:FireServer(oc) end; task.wait(0.05)
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then p.Character.HumanoidRootPart.CFrame = ocf end
        SaSaHub:MakeNotification({Name="Barrier",Content="Success",Time=3})
    end)
    local function restore()
        if ows == nil and ojp == nil then return end
        local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() if ows ~= nil then h.WalkSpeed = ows end; if ojp ~= nil then h.JumpPower = ojp end end) end
    end
    restore()
    if not ok then SaSaHub:MakeNotification({Name="Error",Content=tostring(err),Time=6}) end
end})

-- =====================================================
-- >> キックタブ
-- =====================================================
local KickTab = MainWindow:MakeTab({Name = "キック", Icon = "rbxassetid://4483345998"})
local KickLabel = KickTab:AddParagraph("Target", "None")
local selected_player = nil

local player_dropdown = KickTab:AddDropdown({Name = "プレイヤー選択", Options = GetPlayerListFormatted(), Callback = function(v)
    if v then local un = v:match("@(.+)%)"); selected_player = un; local p = sv_Players:FindFirstChild(un); if p then KickLabel:Set("Target", p.DisplayName.." @"..p.Name) end end
end})

local last_plist = GetPlayerListFormatted()
task.spawn(function() while true do task.wait(1)
    local cp = GetPlayerListFormatted(); local ch = false
    if #cp ~= #last_plist then ch = true else for i, v in ipairs(cp) do if last_plist[i] ~= v then ch = true; break end end end
    if ch and player_dropdown then last_plist = cp; player_dropdown:Refresh(cp, true) end
end end)

KickTab:AddButton({Name = "👊 Blobman Kick (Old)", Callback = function() if not selected_player then SaSaHub:MakeNotification({Name="Error",Content="Select player",Time=3}); return end; ExecuteOldKick(selected_player) end})
KickTab:AddButton({Name = "👊 Blobman Kick (New)", Callback = function() if not selected_player then SaSaHub:MakeNotification({Name="Error",Content="Select player",Time=3}); return end; ExecuteNewKick(selected_player) end})

KickTab:AddSection({Name = "Kick All (Whitelist)"})
kick_all_wl_label = KickTab:AddParagraph("保護リスト", "現在ホワイトリストは空です")
kick_all_wl_dropdown = KickTab:AddDropdown({
    Name = "Whitelist Manager",
    Default = "",
    Options = GetWLPlayerList(),
    Callback = function(v)
        if v then
            local n = v:match("@(.+)%)")
            if n then
                if kick_whitelist[n] then kick_whitelist[n] = nil; SaSaHub:MakeNotification({Name = "WL", Content = n .. " を削除", Time = 2})
                else kick_whitelist[n] = true; SaSaHub:MakeNotification({Name = "WL", Content = n .. " を追加", Time = 2}) end
                UpdateWLUI()
            end
        end
    end
})
task.spawn(function() while true do task.wait(1); UpdateWLDropdownAuto() end end)
KickTab:AddButton({Name = "👊 Kick All", Callback = ExecuteKickAll})

KickTab:AddSection({Name = "Kick All 配置設定"})
KickTab:AddDropdown({Name = "配置モード", Default = "circle", Options = {"circle", "double", "spiral"}, Callback = function(v) kick_all_placement_mode = v end})
KickTab:AddSlider({Name = "円の半径", Min = 5, Max = 100, Default = 25, Callback = function(v) kick_all_circle_radius = v end})
KickTab:AddSlider({Name = "内側円の半径", Min = 5, Max = 50, Default = 15, Callback = function(v) kick_all_inner_radius = v end})
KickTab:AddSlider({Name = "外側円の半径", Min = 10, Max = 100, Default = 35, Callback = function(v) kick_all_outer_radius = v end})
KickTab:AddSlider({Name = "スパイラル開始半径", Min = 5, Max = 50, Default = 10, Callback = function(v) kick_all_spiral_start = v end})
KickTab:AddSlider({Name = "スパイラル終了半径", Min = 10, Max = 100, Default = 40, Callback = function(v) kick_all_spiral_end = v end})
KickTab:AddSlider({Name = "プレイヤー Y座標", Min = 10, Max = 500, Default = 100, Callback = function(v) kick_all_player_y = v end})
KickTab:AddSlider({Name = "自分 Y座標", Min = 10, Max = 500, Default = 100, Callback = function(v) kick_all_self_y = v end})

KickTab:AddSection({Name = "Arkadia Spam Kick"})
local arkadia_dropdown = KickTab:AddDropdown({Name = "Target", Default = "", Options = GetPlayerListFormatted(), Callback = function(v) if v then arkadia_target_name = v:match("@(.+)%)") end end})
task.spawn(function()
    local last_al = {}
    while true do task.wait(1)
        if arkadia_dropdown then
            local cl = GetPlayerListFormatted(); local ch = false
            if #cl ~= #last_al then ch = true else for i, v in ipairs(cl) do if last_al[i] ~= v then ch = true; break end end end
            if ch then last_al = cl; pcall(function() arkadia_dropdown:Refresh(cl, true) end) end
        end
    end
end)
KickTab:AddToggle({Name = "🔄 Arkadia Spam", Default = false, Callback = function(s) if s then if arkadia_target_name then StartArkadia(arkadia_target_name) else SaSaHub:MakeNotification({Name="Error",Content="Select target first",Time=3}) end else StopArkadia() end end})
KickTab:AddSlider({Name = "Radius", Min = 5, Max = 100, Default = 18, Callback = SetArkadiaRadius})
KickTab:AddSlider({Name = "Speed", Min = 1, Max = 100, Default = 15, Callback = SetArkadiaSpeed})
KickTab:AddSlider({Name = "Height", Min = 0, Max = 1000, Default = 23, Callback = SetArkadiaHeight})
KickTab:AddSlider({Name = "X Offset", Min = -50, Max = 50, Default = 0, Callback = SetArkadiaOffsetX})
KickTab:AddSlider({Name = "Z Offset", Min = -50, Max = 50, Default = 0, Callback = SetArkadiaOffsetZ})
KickTab:AddButton({Name = "Reset Position", Callback = ResetArkadiaPosition})

-- =====================================================
-- >> ノーブロブキックオール
-- =====================================================
KickTab:AddSection({Name = "ノーブロブキックオール"})

KickTab:AddDropdown({
    Name = "破壊の高さモード",
    Default = "Spawn (地上)",
    Options = {"Spawn (地上)", "Heaven (天国)"},
    Callback = function(Value)
        noblob_selected_height = (Value == "Heaven (天国)") and "Heaven" or "Spawn"
    end
})

KickTab:AddButton({
    Name = "🚀 キックオール実行",
    Callback = ExecuteNoblobKickAll
})

KickTab:AddButton({
    Name = "⏹ ラグ停止",
    Callback = NoblobStopLag
})

-- =====================================================
-- >> キル系タブ
-- =====================================================
local KillTab = MainWindow:MakeTab({Name = "キル系", Icon = "rbxassetid://4483345998"})
KillTab:AddSection({Name = "Void Loop"})
void_loop_dropdown = KillTab:AddDropdown({Name = "Target", Default = "", Options = GetPlayerListFormatted(), Callback = function(v) if v and v ~= "" then SetVoidLoopTarget(v) end end})
task.spawn(function()
    local last_vl = {}
    while true do task.wait(1)
        if void_loop_dropdown then
            local cl = GetPlayerListFormatted(); local ch = false
            if #cl ~= #last_vl then ch = true else for i, v in ipairs(cl) do if last_vl[i] ~= v then ch = true; break end end end
            if ch then last_vl = cl; void_loop_dropdown:Refresh(cl, true) end
        end
    end
end)
KillTab:AddSlider({Name = "Interval", Min = 0.1, Max = 10.0, Default = 1.5, Increment = 0.1, ValueName = "s", Callback = function(v) void_loop_interval = v; if void_loop_active then StopVoidLoop(); task.wait(0.1); StartVoidLoop() end end})
void_loop_toggle_ref = KillTab:AddToggle({Name = "Void Loop", Default = false, Color = Color3.fromRGB(255,0,0), Callback = function(s)
    if s then if not void_loop_target then SaSaHub:MakeNotification({Name="Void",Content="Select target first",Time=3}); if void_loop_toggle_ref then void_loop_toggle_ref:Set(false) end; return end; StartVoidLoop()
    else StopVoidLoop() end
end})

-- =====================================================
-- >> ESPタブ
-- =====================================================
local ESPTab = MainWindow:MakeTab({Name = "ESP", Icon = "rbxassetid://7733774602"})
ESPTab:AddSection({Name = "Highlight"})
local esp_on = false; local esp_cache = {}
local function RefreshESP()
    for _, p in pairs(sv_Players:GetPlayers()) do
        if p ~= sv_Local then
            if esp_on and p.Character then
                if not esp_cache[p] then
                    local h = Instance.new("Highlight", p.Character); h.Adornee = p.Character
                    h.FillColor = Color3.fromRGB(255,0,0); h.FillTransparency = 0.5; h.OutlineColor = Color3.fromRGB(255,255,255); esp_cache[p] = h
                end
            else if esp_cache[p] then esp_cache[p]:Destroy(); esp_cache[p] = nil end end
        end
    end
end
ESPTab:AddToggle({Name = "ESP", Default = false, Callback = function(v) esp_on = v; RefreshESP() end})

-- =====================================================
-- >> プレイヤータブ
-- =====================================================
local PlayerTab = MainWindow:MakeTab({Name = "プレイヤー", Icon = "rbxassetid://7743871002"})
PlayerTab:AddSection({Name = "Speed"})
local super_speed = false; local speed_mult = 0.15
PlayerTab:AddToggle({Name = "Speed Hack", Default = false, Callback = function(v) super_speed = v end})
PlayerTab:AddSlider({Name = "Multiplier", Min = 0.1, Max = 5, Default = 0.15, Increment = 0.01, Callback = function(v) speed_mult = v end})
PlayerTab:AddSection({Name = "Jump"})
local inf_jump = false
PlayerTab:AddToggle({Name = "Inf Jump", Default = false, Callback = function(v) inf_jump = v end})
PlayerTab:AddSlider({Name = "Jump Power", Min = 24, Max = 1000, Default = 24, Increment = 10, Callback = function(v) local h = sv_Local.Character and sv_Local.Character:FindFirstChildOfClass("Humanoid"); if h then h.JumpPower = v end end})
PlayerTab:AddSection({Name = "Noclip"})
local noclip_on = false; local noclip_conn = nil
PlayerTab:AddToggle({Name = "Noclip", Default = false, Callback = function(v)
    noclip_on = v
    if v then noclip_conn = sv_Run.Stepped:Connect(function() if sv_Local.Character then for _, p in pairs(sv_Local.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end end)
    elseif noclip_conn then noclip_conn:Disconnect(); noclip_conn = nil end
end})
PlayerTab:AddSection({Name = "Camera"})
local third_person = false
PlayerTab:AddToggle({Name = "Third Person", Default = false, Callback = function(s)
    third_person = s
    if s then sv_Local.CameraMode = Enum.CameraMode.Classic; sv_Local.CameraMaxZoomDistance = 100; sv_Local.CameraMinZoomDistance = 0.5
    else sv_Local.CameraMode = Enum.CameraMode.LockFirstPerson; sv_Local.CameraMaxZoomDistance = 0.5; sv_Local.CameraMinZoomDistance = 0.5 end
end})

sv_Run.Heartbeat:Connect(function()
    if super_speed and sv_Local.Character then
        local h = sv_Local.Character:FindFirstChildOfClass("Humanoid"); local r = sv_Local.Character:FindFirstChild("HumanoidRootPart")
        if h and r then r.CFrame = r.CFrame + h.MoveDirection * speed_mult end
    end
end)

sv_Input.JumpRequest:Connect(function()
    if inf_jump and sv_Local.Character then local h = sv_Local.Character:FindFirstChild("Humanoid"); if h then h:ChangeState("Jumping") end end
end)

-- =====================================================
-- >> アンチタブ
-- =====================================================
local DefenseTab = MainWindow:MakeTab({Name = "🛡️ Defense", Icon = "rbxassetid://129017321982695"})
DefenseTab:AddSection({Name = "Basic"})
DefenseTab:AddToggle({Name = "Anti Explode", Default = false, Callback = function(v) if v then EnableExplosionDefense() else DisableExplosionDefense() end end})
DefenseTab:AddToggle({Name = "Anti Burn", Default = false, Callback = function(v) if v then EnableBurnDefense() else DisableBurnDefense() end end})
DefenseTab:AddToggle({Name = "Anti Void", Default = false, Callback = ToggleVoidProtection})
DefenseTab:AddToggle({Name = "Anti Banana Sit", Default = false, Callback = function(v) if v then EnableBananaSitDefense() else DisableBananaSitDefense() end end})
DefenseTab:AddToggle({Name = "Anti Blob Kill", Default = false, Callback = function(v) if v then EnableBlobKillDefense() else DisableBlobKillDefense() end end})
DefenseTab:AddToggle({Name = "Anti Blob Ragdoll", Default = false, Callback = function(v) if v then EnableRagBlobDefense() else DisableRagBlobDefense() end end})

DefenseTab:AddSection({Name = "Anti Kick"})
DefenseTab:AddToggle({Name = "Anti Kick (Kunai)", Default = false, Callback = function(v) if v then EnableKunaiAntiKick() else DisableKunaiAntiKick() end end})
DefenseTab:AddToggle({Name = "Anti Kick (JointBreak)", Default = false, Callback = function(v) if v then EnableJointBreakShield() else DisableJointBreakShield() end end})

DefenseTab:AddSection({Name = "Anti Lag"})
DefenseTab:AddToggle({Name = "Anti Lag", Default = false, Callback = function(v) if v then EnableAntiLagSystem() else DisableAntiLagSystem() end end})
DefenseTab:AddToggle({Name = "Auto Anti Lag", Default = false, Callback = function(v) if v then EnableAutoAntiLag() else DisableAutoAntiLag() end end})

DefenseTab:AddSection({Name = "Anti Grab"})
DefenseTab:AddToggle({Name = "Anti Sticky", Default = false, Callback = function(v) if v then EnableAntiStickySystem() else DisableAntiStickySystem() end end})
DefenseTab:AddToggle({Name = "Anti Grab", Default = false, Callback = function(v) if v then EnableGrabDefense() else DisableGrabDefense() end end})
DefenseTab:AddToggle({Name = "Anti Grab NRD", Default = false, Callback = function(v) if v then EnableGrabDefenseNRD() else DisableGrabDefenseNRD() end end})

DefenseTab:AddSection({Name = "Advanced"})
DefenseTab:AddToggle({Name = "GOD MODE", Default = false, Callback = function(v) if v then StartGodMode(); SaSaHub:MakeNotification({Name="God",Content="ON",Time=2}) else StopGodMode(); SaSaHub:MakeNotification({Name="God",Content="OFF",Time=2}) end end})
DefenseTab:AddToggle({Name = "Gucci Anti Grab", Default = false, Callback = function(v) if v then ActivateGucciDefense(); SaSaHub:MakeNotification({Name="Gucci",Content="ON",Time=2}) else DeactivateGucciDefense(); SaSaHub:MakeNotification({Name="Gucci",Content="OFF",Time=2}) end end})

DefenseTab:AddSection({Name = "Input Lag"})
DefenseTab:AddDropdown({Name = "Item", Default = item_dropdown_options[1] or "Burger", Options = item_dropdown_options, Callback = function(v) selected_food_item = ITEM_DB[v] or "FoodHamburger" end})
DefenseTab:AddToggle({Name = "Anti Input Lag", Default = false, Callback = function(v) if v then EnableInputLagDefense() else DisableInputLagDefense() end end})
DefenseTab:AddToggle({Name = "Remove All Items", Default = false, Callback = function(v) if v then EnableGlobalItemCleaner() else DisableGlobalItemCleaner() end end})

-- =====================================================
-- >> 設定タブ
-- =====================================================
local SettingsTab = MainWindow:MakeTab({Name = "Settings", Icon = "rbxassetid://4483362458"})
SettingsTab:AddButton({Name = "Reload", Callback = function()
    SaSaHub:MakeNotification({Name="Reload",Content="Reloading...",Time=2}); task.wait(0.5)
    SaSaHub:Destroy(); task.wait(0.5)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/jadpy/suki/refs/heads/main/orion"))()
end})
SettingsTab:AddButton({Name = "Close", Callback = function() SaSaHub:Destroy() end})

-- =====================================================
-- >> 起動
-- =====================================================
SaSaHub:Init()
UpdateWLUI()
print("🕊️ SaSaHub Complete Edition - Ready")