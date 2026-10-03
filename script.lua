-- language: Lua, executor: Delta, target: Roblox Murder Mystery 2 (Mobile)
-- GUI rework + fixed autothrow + fixed remotes

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ══════════════════════════════════════
--           КОНФИГ
-- ══════════════════════════════════════
local Config = {
    ESP            = true,
    RoleDetector   = true,
    AutoKillMurder = false,
    AutoKillAll    = false,
    AutoThrow      = false,
    AutoGun        = true,
    ThirdPerson    = false,
    Spinbot        = false,
    WorldVisuals   = true,
    FOVRadius      = 120,
    SpinSpeed      = 6,

    MurderColor    = Color3.fromRGB(255, 60,  60),
    SheriffColor   = Color3.fromRGB(60,  160, 255),
    InnoColor      = Color3.fromRGB(160, 160, 160),
    Accent         = Color3.fromRGB(160, 60,  255),
    Accent2        = Color3.fromRGB(80,  120, 255),
}

-- ══════════════════════════════════════
--           РОЛИ
-- ══════════════════════════════════════
local Roles = {}

local function detectRoles()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        local bp   = p:FindFirstChild("Backpack")
        local function has(name)
            return (char and char:FindFirstChild(name)) or (bp and bp:FindFirstChild(name))
        end
        if has("Knife") or has("MM2Knife") or has("KnifeModel") then
            Roles[p] = "Murder"
        elseif has("Gun") or has("MM2Gun") or has("SheriffGun") then
            Roles[p] = "Sheriff"
        else
            Roles[p] = "Innocent"
        end
    end
end

local function roleColor(p)
    local r = Roles[p]
    if r == "Murder"  then return Config.MurderColor  end
    if r == "Sheriff" then return Config.SheriffColor end
    return Config.InnoColor
end

-- ══════════════════════════════════════
--           УТИЛИТЫ
-- ══════════════════════════════════════
local function getRoot(p)
    local c = p and p.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum(p)
    local c = p and p.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function isAlive(p)
    local h = getHum(p)
    return h and h.Health > 0
end

local function closest(filterRole)
    local best, bd = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or not isAlive(p) then continue end
        if filterRole and Roles[p] ~= filterRole then continue end
        local r1 = getRoot(LocalPlayer)
        local r2 = getRoot(p)
        if r1 and r2 then
            local d = (r2.Position - r1.Position).Magnitude
            if d < bd then bd = d; best = p end
        end
    end
    return best
end

local function closestFOV()
    local best, bd = nil, Config.FOVRadius
    local cx = Camera.ViewportSize.X / 2
    local cy = Camera.ViewportSize.Y / 2
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or not isAlive(p) then continue end
        local r = getRoot(p)
        if not r then continue end
        local sp, vis = Camera:WorldToViewportPoint(r.Position)
        if not vis then continue end
        local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(cx, cy)).Magnitude
        if d < bd then bd = d; best = p end
    end
    return best
end

-- ══════════════════════════════════════
--           АВТО БРОСОК — ФИКС
-- ══════════════════════════════════════
-- MM2 бросок ножа идёт через RemoteFunction или RemoteEvent
-- перебираем все ремоуты и логируем чтобы найти нужный

local throwRemote   = nil
local killRemote    = nil
local gunRemote     = nil

local function findRemotes()
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            local n = v.Name:lower()
            if n:find("throw") or n:find("toss") then
                throwRemote = v
            end
            if n:find("kill") or n:find("stab") or n:find("murder") then
                killRemote = v
            end
            if n:find("shoot") or n:find("fire") or n:find("gun") then
                gunRemote = v
            end
        end
    end
end

-- вызываем сразу и через секунду (когда игра догружается)
findRemotes()
task.delay(3, findRemotes)
task.delay(6, findRemotes)

local lastThrow = 0
local function doThrow(target)
    if not target then return end
    local tRoot = getRoot(target)
    if not tRoot then return end
    local now = tick()
    if now - lastThrow < 0.8 then return end
    lastThrow = now

    -- способ 1: через найденный remote
    if throwRemote then
        pcall(function()
            if throwRemote:IsA("RemoteFunction") then
                throwRemote:InvokeServer(tRoot.Position)
            else
                throwRemote:FireServer(tRoot.Position)
            end
        end)
    end

    -- способ 2: перебор всех ремоутов с throw/toss в имени
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("throw") or n:find("toss") or n:find("knife") then
                pcall(function() v:FireServer(tRoot.Position) end)
            end
        end
    end

    -- способ 3: симуляция через инструмент
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local knife = char:FindFirstChild("Knife")
            or char:FindFirstChild("MM2Knife")
            or LocalPlayer.Backpack:FindFirstChild("Knife")
        if knife and knife:FindFirstChild("Handle") then
            local tool = knife
            -- активируем и направляем в цель
            local hum = getHum(LocalPlayer)
            if hum then
                local cf = CFrame.new(getRoot(LocalPlayer).Position, tRoot.Position)
                getRoot(LocalPlayer).CFrame = cf
            end
        end
    end)
end

local lastKill = 0
local function doKill(target)
    if not target then return end
    local tRoot = getRoot(target)
    local myRoot = getRoot(LocalPlayer)
    if not tRoot or not myRoot then return end
    local now = tick()
    if now - lastKill < 0.4 then return end
    lastKill = now
    -- телепорт вплотную
    myRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(0,0,2))
    -- fire kill remote
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("kill") or n:find("stab") or n:find("murder") or n:find("knife") then
                pcall(function() v:FireServer(target.Character) end)
            end
        end
    end
end

-- ══════════════════════════════════════
--           АВТОПОДБОР ПУШКИ
-- ══════════════════════════════════════
local function tryPickGun()
    if not Config.AutoGun then return end
    if Roles[LocalPlayer] == "Murder" then return end
    local myRoot = getRoot(LocalPlayer)
    if not myRoot then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") then
            local n = obj.Name:lower()
            if n:find("gun") or n:find("sheriff") then
                local part = obj:FindFirstChildOfClass("BasePart")
                if part and (part.Position - myRoot.Position).Magnitude < 18 then
                    pcall(function()
                        local hum = getHum(LocalPlayer)
                        if hum then hum:EquipTool(obj) end
                    end)
                end
            end
        end
    end
end

-- ══════════════════════════════════════
--           WORLD VISUALS
-- ══════════════════════════════════════
pcall(function()
    if not Config.WorldVisuals then return end
    local L = game:GetService("Lighting")
    L.Brightness = 2.5
    L.Ambient = Color3.fromRGB(60, 40, 100)
    L.OutdoorAmbient = Color3.fromRGB(80, 60, 130)
    for _, e in ipairs(L:GetChildren()) do
        if e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") then e:Destroy() end
    end
    local cc = Instance.new("ColorCorrectionEffect", L)
    cc.Brightness = 0.03
    cc.Contrast   = 0.2
    cc.Saturation = 0.25
    cc.TintColor  = Color3.fromRGB(210, 180, 255)
    local bl = Instance.new("BloomEffect", L)
    bl.Intensity = 0.5
    bl.Size      = 20
    bl.Threshold = 0.88
end)

-- ══════════════════════════════════════
--           THIRD PERSON
-- ══════════════════════════════════════
RunService.RenderStepped:Connect(function()
    if Config.ThirdPerson then
        local r = getRoot(LocalPlayer)
        if r then
            Camera.CameraType = Enum.CameraType.Scriptable
            local lv = Camera.CFrame.LookVector
            Camera.CFrame = CFrame.new(r.Position - lv * 8 + Vector3.new(0,2,0), r.Position + Vector3.new(0,1,0))
        end
    elseif Camera.CameraType == Enum.CameraType.Scriptable then
        Camera.CameraType = Enum.CameraType.Custom
    end
end)

-- ══════════════════════════════════════
--           SPINBOT
-- ══════════════════════════════════════
local spinA = 0
RunService.Heartbeat:Connect(function(dt)
    if not Config.Spinbot then return end
    local r = getRoot(LocalPlayer)
    if not r then return end
    spinA = (spinA + Config.SpinSpeed) % 360
    r.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, math.rad(spinA), 0)
end)

-- ══════════════════════════════════════
--           MAIN LOOP
-- ══════════════════════════════════════
local ticker = 0
RunService.Heartbeat:Connect(function(dt)
    ticker = ticker + dt
    if ticker >= 0.4 then
        ticker = 0
        detectRoles()
        tryPickGun()
    end
    if Config.AutoKillMurder then doKill(closest("Murder")) end
    if Config.AutoKillAll    then doKill(closest(nil))      end
    if Config.AutoThrow      then doThrow(closestFOV())     end
end)

-- ══════════════════════════════════════
--           DRAWING ESP
-- ══════════════════════════════════════
local espData = {}

local function mkESP(p)
    if p == LocalPlayer then return end
    espData[p] = {
        box    = Drawing.new("Square"),
        name   = Drawing.new("Text"),
        role   = Drawing.new("Text"),
        dist   = Drawing.new("Text"),
        tracer = Drawing.new("Line"),
        hpBg   = Drawing.new("Square"),
        hp     = Drawing.new("Square"),
    }
    local d = espData[p]
    d.box.Filled    = false; d.box.Thickness = 1.8; d.box.Visible = false
    d.tracer.Thickness = 1.4; d.tracer.Visible = false
    d.hpBg.Filled   = true;  d.hpBg.Color = Color3.fromRGB(25,25,25); d.hpBg.Visible = false
    d.hp.Filled     = true;  d.hp.Visible = false
    for _, k in ipairs({"name","role","dist"}) do
        d[k].Size = 13; d[k].Font = 2
        d[k].Outline = true; d[k].OutlineColor = Color3.new(0,0,0)
        d[k].Color = Color3.new(1,1,1); d[k].Visible = false
    end
end

for _, p in ipairs(Players:GetPlayers()) do mkESP(p) end
Players.PlayerAdded:Connect(mkESP)
Players.PlayerRemoving:Connect(function(p)
    if espData[p] then
        for _, o in pairs(espData[p]) do pcall(function() o.Visible = false end) end
        espData[p] = nil; Roles[p] = nil
    end
end)

local fovCircle = Drawing.new("Circle")
fovCircle.NumSides = 64; fovCircle.Thickness = 1.4
fovCircle.Color = Color3.fromRGB(180,180,255)
fovCircle.Filled = false; fovCircle.Visible = false

RunService.RenderStepped:Connect(function()
    fovCircle.Visible = true
    fovCircle.Radius  = Config.FOVRadius
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for p, d in pairs(espData) do
        if not Config.ESP or not isAlive(p) then
            for _, o in pairs(d) do pcall(function() o.Visible = false end) end
            continue
        end
        local char = p.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local myR  = getRoot(LocalPlayer)
        if not root then continue end
        local top, vis = Camera:WorldToViewportPoint(root.Position + Vector3.new(0,3.2,0))
        local bot      = Camera:WorldToViewportPoint(root.Position - Vector3.new(0,3.2,0))
        if not vis then
            for _, o in pairs(d) do pcall(function() o.Visible = false end) end
            continue
        end
        local h  = math.abs(top.Y - bot.Y)
        local w  = h * 0.5
        local cx = top.X
        local ty = math.min(top.Y, bot.Y)
        local rc = roleColor(p)

        d.box.Visible = true; d.box.Color = rc
        d.box.Size = Vector2.new(w, h)
        d.box.Position = Vector2.new(cx - w/2, ty)

        d.name.Visible = true; d.name.Text = p.Name
        d.name.Position = Vector2.new(cx, ty - 20)

        d.role.Visible = true; d.role.Color = rc
        d.role.Text = "[" .. (Roles[p] or "?") .. "]"
        d.role.Position = Vector2.new(cx, ty - 34)

        if myR then
            local dist = math.floor((root.Position - myR.Position).Magnitude)
            d.dist.Visible = true
            d.dist.Text = dist .. "m"
            d.dist.Position = Vector2.new(cx, ty + h + 3)
        end

        d.tracer.Visible = true; d.tracer.Color = rc
        d.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        d.tracer.To   = Vector2.new(cx, ty + h)

        if hum then
            local hpPct = hum.Health / math.max(hum.MaxHealth, 1)
            d.hpBg.Visible = true
            d.hpBg.Size = Vector2.new(4, h)
            d.hpBg.Position = Vector2.new(cx - w/2 - 7, ty)
            d.hp.Visible = true
            d.hp.Size = Vector2.new(4, h * hpPct)
            d.hp.Position = Vector2.new(cx - w/2 - 7, ty + h*(1-hpPct))
            d.hp.Color = Color3.fromRGB(math.floor(255*(1-hpPct)), math.floor(255*hpPct), 50)
        end
    end
end)

-- ══════════════════════════════════════
--           GUI — ПОЛНЫЙ РEWORK
-- ══════════════════════════════════════
pcall(function()
    local old = game.CoreGui:FindFirstChild("MM2_v2")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "MM2_v2"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
if not pcall(function() gui.Parent = game.CoreGui end) then
    gui.Parent = LocalPlayer.PlayerGui
end

-- ── КНОПКА ОТКРЫТИЯ ──
local openBtn = Instance.new("ImageButton", gui)
openBtn.Size = UDim2.new(0, 60, 0, 60)
openBtn.Position = UDim2.new(0, 14, 0.5, -30)
openBtn.BackgroundColor3 = Color3.fromRGB(16, 12, 28)
openBtn.BorderSizePixel = 0
openBtn.ZIndex = 30
openBtn.Image = ""
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)

-- градиент на кнопке
local btnGrad = Instance.new("UIGradient", openBtn)
btnGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 50, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 100, 255)),
})
btnGrad.Rotation = 135

local btnIcon = Instance.new("TextLabel", openBtn)
btnIcon.Size = UDim2.new(1,0,1,0)
btnIcon.BackgroundTransparency = 1
btnIcon.Text = "✦"
btnIcon.TextColor3 = Color3.new(1,1,1)
btnIcon.Font = Enum.Font.GothamBold
btnIcon.TextSize = 26
btnIcon.ZIndex = 31

-- пульс обводка
local btnStroke = Instance.new("UIStroke", openBtn)
btnStroke.Thickness = 2
btnStroke.Color = Color3.fromRGB(180, 50, 255)
TweenService:Create(btnStroke,
    TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    {Color = Color3.fromRGB(60, 100, 255), Thickness = 2.8}
):Play()

-- ── ПАНЕЛЬ ──
local W, H = 300, 520

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, W, 0, H)
panel.Position = UDim2.new(0, 86, 0.5, -H/2)
panel.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 20
panel.ClipsDescendants = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 24)

-- внутренний градиент фона
local bgGrad = Instance.new("UIGradient", panel)
bgGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 12, 30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 6, 16)),
})
bgGrad.Rotation = 120

-- обводка панели
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Thickness = 1.5
panelStroke.Color = Color3.fromRGB(80, 40, 140)
panelStroke.Transparency = 0.3

-- тень
local shadow = Instance.new("ImageLabel", gui)
shadow.Size = UDim2.new(0, W+40, 0, H+40)
shadow.Position = UDim2.new(0, 66, 0.5, -H/2-20)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://6014261993"
shadow.ImageColor3 = Color3.fromRGB(80, 0, 160)
shadow.ImageTransparency = 0.6
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(49,49,450,450)
shadow.ZIndex = 19
shadow.Visible = false

-- ── ШАПКА ──
local topBar = Instance.new("Frame", panel)
topBar.Size = UDim2.new(1, 0, 0, 64)
topBar.BackgroundColor3 = Color3.fromRGB(20, 14, 38)
topBar.BorderSizePixel = 0
topBar.ZIndex = 21

local topGrad = Instance.new("UIGradient", topBar)
topGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 40, 220)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 60, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 80, 180)),
})
topGrad.Rotation = 25

-- иконка в шапке
local headerIcon = Instance.new("TextLabel", topBar)
headerIcon.Size = UDim2.new(0, 44, 0, 44)
headerIcon.Position = UDim2.new(0, 12, 0.5, -22)
headerIcon.BackgroundColor3 = Color3.fromRGB(255,255,255)
headerIcon.BackgroundTransparency = 0.85
headerIcon.Text = "☽"
headerIcon.TextColor3 = Color3.new(1,1,1)
headerIcon.Font = Enum.Font.GothamBold
headerIcon.TextSize = 22
headerIcon.ZIndex = 22
Instance.new("UICorner", headerIcon).CornerRadius = UDim.new(1,0)

local headerTitle = Instance.new("TextLabel", topBar)
headerTitle.Size = UDim2.new(0, 160, 0, 24)
headerTitle.Position = UDim2.new(0, 64, 0, 10)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "MURDER MYSTERY"
headerTitle.TextColor3 = Color3.new(1,1,1)
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = 15
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.ZIndex = 22

local headerSub = Instance.new("TextLabel", topBar)
headerSub.Size = UDim2.new(0, 160, 0, 18)
headerSub.Position = UDim2.new(0, 64, 0, 34)
headerSub.BackgroundTransparency = 1
headerSub.Text = "private cheat • delta"
headerSub.TextColor3 = Color3.fromRGB(160, 120, 220)
headerSub.Font = Enum.Font.Gotham
headerSub.TextSize = 11
headerSub.TextXAlignment = Enum.TextXAlignment.Left
headerSub.ZIndex = 22

-- версия
local verLbl = Instance.new("TextLabel", topBar)
verLbl.Size = UDim2.new(0, 50, 0, 20)
verLbl.Position = UDim2.new(1, -58, 0.5, -10)
verLbl.BackgroundColor3 = Color3.fromRGB(255,255,255)
verLbl.BackgroundTransparency = 0.88
verLbl.Text = "v2.0"
verLbl.TextColor3 = Color3.fromRGB(200,160,255)
verLbl.Font = Enum.Font.GothamBold
verLbl.TextSize = 11
verLbl.ZIndex = 22
Instance.new("UICorner", verLbl).CornerRadius = UDim.new(1,0)

-- роль строка под шапкой
local roleStrip = Instance.new("Frame", panel)
roleStrip.Size = UDim2.new(1, -24, 0, 34)
roleStrip.Position = UDim2.new(0, 12, 0, 72)
roleStrip.BackgroundColor3 = Color3.fromRGB(20, 16, 36)
roleStrip.BorderSizePixel = 0
roleStrip.ZIndex = 21
Instance.new("UICorner", roleStrip).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", roleStrip).Color = Color3.fromRGB(60, 40, 100)

local roleLbl = Instance.new("TextLabel", roleStrip)
roleLbl.Size = UDim2.new(1, -16, 1, 0)
roleLbl.Position = UDim2.new(0, 10, 0, 0)
roleLbl.BackgroundTransparency = 1
roleLbl.Font = Enum.Font.GothamBold
roleLbl.TextSize = 12
roleLbl.TextXAlignment = Enum.TextXAlignment.Left
roleLbl.ZIndex = 22
roleLbl.Text = "👤  Роль: определяю..."
roleLbl.TextColor3 = Color3.fromRGB(180,180,200)

RunService.Heartbeat:Connect(function()
    local r = Roles[LocalPlayer] or "?"
    local icons = {Murder="🔪", Sheriff="🔫", Innocent="👤"}
    roleLbl.Text = (icons[r] or "👤") .. "  Моя роль: " .. r
    roleLbl.TextColor3 = roleColor(LocalPlayer)
end)

-- ── ТОГЛ СТРОКИ ──
local function makeRow(parent, label, icon, key, yOff)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -24, 0, 44)
    row.Position = UDim2.new(0, 12, 0, yOff)
    row.BackgroundColor3 = Color3.fromRGB(16, 12, 28)
    row.BorderSizePixel = 0
    row.ZIndex = 21
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

    -- левая полоска
    local accent = Instance.new("Frame", row)
    accent.Size = UDim2.new(0, 3, 0.55, 0)
    accent.Position = UDim2.new(0, 0, 0.225, 0)
    accent.BackgroundColor3 = Config.Accent
    accent.BorderSizePixel = 0
    accent.ZIndex = 22
    Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

    local ico = Instance.new("TextLabel", row)
    ico.Size = UDim2.new(0, 30, 1, 0)
    ico.Position = UDim2.new(0, 10, 0, 0)
    ico.BackgroundTransparency = 1
    ico.Text = icon
    ico.TextSize = 17
    ico.Font = Enum.Font.GothamBold
    ico.ZIndex = 22

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Position = UDim2.new(0, 44, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200, 195, 215)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 22

    -- pill
    local pill = Instance.new("Frame", row)
    pill.Size = UDim2.new(0, 46, 0, 24)
    pill.Position = UDim2.new(1, -56, 0.5, -12)
    pill.BackgroundColor3 = Color3.fromRGB(40, 36, 60)
    pill.BorderSizePixel = 0
    pill.ZIndex = 22
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", pill)
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(100, 90, 130)
    knob.BorderSizePixel = 0
    knob.ZIndex = 23
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local pillBtn = Instance.new("TextButton", row)
    pillBtn.Size = UDim2.new(1, 0, 1, 0)
    pillBtn.BackgroundTransparency = 1
    pillBtn.Text = ""
    pillBtn.ZIndex = 24

    local function refresh()
        if Config[key] then
            TweenService:Create(pill,  TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(110, 50, 200)}):Play()
            TweenService:Create(knob,  TweenInfo.new(0.18), {
                Position = UDim2.new(1, -21, 0.5, -9),
                BackgroundColor3 = Color3.new(1,1,1)
            }):Play()
            TweenService:Create(accent, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(130, 60, 220)}):Play()
        else
            TweenService:Create(pill,  TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(40, 36, 60)}):Play()
            TweenService:Create(knob,  TweenInfo.new(0.18), {
                Position = UDim2.new(0, 3, 0.5, -9),
                BackgroundColor3 = Color3.fromRGB(100, 90, 130)
            }):Play()
            TweenService:Create(accent, TweenInfo.new(0.18), {BackgroundColor3 = Config.Accent}):Play()
        end
    end
    refresh()

    pillBtn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        refresh()
    end)
end

local items = {
    {"ESP Игроков",      "👁",  "ESP",            115},
    {"AutoKill Мардер",  "🔪",  "AutoKillMurder", 165},
    {"AutoKill Все",     "💀",  "AutoKillAll",    215},
    {"AutoThrow Нож",    "🗡",  "AutoThrow",      265},
    {"Автоподбор Пушки", "🔫",  "AutoGun",        315},
    {"Третье лицо",      "📷",  "ThirdPerson",    365},
    {"Spinbot",          "🌀",  "Spinbot",        415},
}
for _, v in ipairs(items) do
    makeRow(panel, v[1], v[2], v[3], v[4])
end

-- ── МОБИЛЬНЫЕ КНОПКИ ──
local function mobileBtn(label, col, xOff, yOff, cb)
    local f = Instance.new("Frame", gui)
    f.Size = UDim2.new(0, 70, 0, 70)
    f.Position = UDim2.new(1, xOff, 1, yOff)
    f.BackgroundColor3 = col
    f.BorderSizePixel = 0
    f.ZIndex = 30
    Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
    local s = Instance.new("UIStroke", f)
    s.Thickness = 1.8; s.Color = Color3.new(1,1,1); s.Transparency = 0.7

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.ZIndex = 31

    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 32
    btn.MouseButton1Click:Connect(function()
        TweenService:Create(f, TweenInfo.new(0.08), {Size = UDim2.new(0,60,0,60), Position = UDim2.new(1, xOff+5, 1, yOff+5)}):Play()
        task.delay(0.1, function()
            TweenService:Create(f, TweenInfo.new(0.1), {Size = UDim2.new(0,70,0,70), Position = UDim2.new(1, xOff, 1, yOff)}):Play()
        end)
        cb()
    end)
    return f
end

mobileBtn("🔫\nВЫСТРЕЛ", Color3.fromRGB(50,120,240), -88, -92, function()
    local t = closest("Murder") or closest(nil)
    if t then
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local n = v.Name:lower()
                if n:find("shoot") or n:find("fire") or n:find("gun") then
                    pcall(function() v:FireServer(t.Character) end)
                end
            end
        end
    end
end)

mobileBtn("🗡\nБРОСОК", Color3.fromRGB(200,45,80), -168, -92, function()
    doThrow(closestFOV() or closest(nil))
end)

-- ── ОТКРЫТИЕ/ЗАКРЫТИЕ ──
local open = false
openBtn.MouseButton1Click:Connect(function()
    open = not open
    shadow.Visible = open
    if open then
        panel.Visible = true
        panel.Size = UDim2.new(0, W, 0, 0)
        panel.Position = UDim2.new(0, 86, 0.5, 0)
        panel.BackgroundTransparency = 1
        TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, W, 0, H),
            Position = UDim2.new(0, 86, 0.5, -H/2),
            BackgroundTransparency = 0,
        }):Play()
        TweenService:Create(btnIcon, TweenInfo.new(0.3), {TextTransparency = 0.4}):Play()
    else
        TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, W, 0, 0),
            Position = UDim2.new(0, 86, 0.5, 0),
            BackgroundTransparency = 1,
        }):Play()
        TweenService:Create(btnIcon, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
        task.delay(0.23, function() panel.Visible = false end)
    end
end)

-- перетаскивание
local drag = {}
panel.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then
        drag = {on=true, s=i.Position, sp=panel.Position}
    end
end)
panel.InputChanged:Connect(function(i)
    if drag.on and i.UserInputType == Enum.UserInputType.Touch then
        local d = i.Position - drag.s
        panel.Position = UDim2.new(drag.sp.X.Scale, drag.sp.X.Offset+d.X, drag.sp.Y.Scale, drag.sp.Y.Offset+d.Y)
    end
end)
panel.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then drag.on = false end
end)
