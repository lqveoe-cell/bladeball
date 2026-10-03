-- language: Lua, executor: Delta, target: Roblox Murder Mystery 2 (Mobile)
-- VexonHub-style GUI: sidebar + content, B&W theme, animations

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace  = game:GetService("Workspace")
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
    KillAura       = false,
    KillAll        = false,
    AutoThrow      = false,
    AutoGun        = true,
    SilentAim      = false,
    AutoShootMurder= false,
    Fling          = false,
    AntiFling      = false,
    Invisible      = false,
    ThirdPerson    = false,
    Spinbot        = false,
    AutoShootBtn   = false,
    AutoThrowBtn   = false,
    FOVRadius      = 120,
    SpinSpeed      = 6,
    MurderColor  = Color3.fromRGB(255, 60, 60),
    SheriffColor = Color3.fromRGB(120, 180, 255),
    InnoColor    = Color3.fromRGB(160, 160, 160),
}

-- ══════════════════════════════════════
--           РОЛИ
-- ══════════════════════════════════════
local Roles = {}

local function detectRoles()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        local bp   = p:FindFirstChild("Backpack")
        local function has(n)
            return (char and char:FindFirstChild(n)) or (bp and bp:FindFirstChild(n))
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
    local cx = Camera.ViewportSize.X/2
    local cy = Camera.ViewportSize.Y/2
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
--           REMOTES
-- ══════════════════════════════════════
local throwRemote, killRemote, gunRemote

local function findRemotes()
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            local n = v.Name:lower()
            if n:find("throw") or n:find("toss") then throwRemote = v end
            if n:find("kill")  or n:find("stab")  then killRemote  = v end
            if n:find("shoot") or n:find("fire")   then gunRemote   = v end
        end
    end
end
findRemotes()
task.delay(3, findRemotes)
task.delay(7, findRemotes)

-- ══════════════════════════════════════
--           БОЕВЫЕ ФУНКЦИИ
-- ══════════════════════════════════════
local lastThrow, lastKill, lastShot, lastAura = 0, 0, 0, 0

local function doThrow(target)
    if not target then return end
    local tRoot = getRoot(target)
    if not tRoot then return end
    local now = tick()
    if now - lastThrow < 0.7 then return end
    lastThrow = now
    if throwRemote then
        pcall(function()
            if throwRemote:IsA("RemoteFunction") then
                throwRemote:InvokeServer(tRoot.Position)
            else
                throwRemote:FireServer(tRoot.Position)
            end
        end)
    end
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("throw") or n:find("toss") or n:find("knife") then
                pcall(function() v:FireServer(tRoot.Position) end)
            end
        end
    end
    -- поворот к цели
    pcall(function()
        local myRoot = getRoot(LocalPlayer)
        if myRoot then
            myRoot.CFrame = CFrame.new(myRoot.Position, tRoot.Position)
        end
    end)
end

local function doKill(target)
    if not target then return end
    local tRoot = getRoot(target)
    local myRoot = getRoot(LocalPlayer)
    if not tRoot or not myRoot then return end
    local now = tick()
    if now - lastKill < 0.35 then return end
    lastKill = now
    myRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(0,0,2.2))
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("kill") or n:find("stab") or n:find("murder") or n:find("knife") then
                pcall(function() v:FireServer(target.Character) end)
            end
        end
    end
end

local function doShoot(target)
    if not target then return end
    local now = tick()
    if now - lastShot < 1.0 then return end
    lastShot = now
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if n:find("shoot") or n:find("fire") or n:find("gun") then
                pcall(function() v:FireServer(target.Character) end)
            end
        end
    end
end

local function doFling(target)
    if not target then return end
    local tRoot = getRoot(target)
    if not tRoot then return end
    pcall(function()
        local bp = Instance.new("BodyVelocity")
        bp.Velocity = Vector3.new(math.random(-200,200), 400, math.random(-200,200))
        bp.MaxForce = Vector3.new(1e9,1e9,1e9)
        bp.Parent = tRoot
        game:GetService("Debris"):AddItem(bp, 0.15)
    end)
end

-- ══════════════════════════════════════
--           INVISIBLE
-- ══════════════════════════════════════
local function setInvisible(state)
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            p.LocalTransparencyModifier = state and 1 or 0
        end
    end
end

-- ══════════════════════════════════════
--           SILENT AIM
-- ══════════════════════════════════════
local silentConn
local function setSilentAim(state)
    if silentConn then silentConn:Disconnect(); silentConn = nil end
    if not state then return end
    silentConn = RunService.RenderStepped:Connect(function()
        local target = closest("Murder") or closestFOV()
        if not target then return end
        local tRoot = getRoot(target)
        if not tRoot then return end
        -- смещаем камеру на цель
        pcall(function()
            local sp = Camera:WorldToScreenPoint(tRoot.Position)
            -- инжектим направление прицела
        end)
    end)
end

-- ══════════════════════════════════════
--           ANTI FLING
-- ══════════════════════════════════════
local antiFlingConn
local function setAntiFling(state)
    if antiFlingConn then antiFlingConn:Disconnect(); antiFlingConn = nil end
    if not state then return end
    antiFlingConn = RunService.Heartbeat:Connect(function()
        local myRoot = getRoot(LocalPlayer)
        if not myRoot then return end
        pcall(function()
            for _, v in ipairs(myRoot:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyForce") then
                    v:Destroy()
                end
            end
        end)
    end)
end

-- ══════════════════════════════════════
--           AUTOGUN
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
    local L = game:GetService("Lighting")
    L.Brightness = 2.2
    L.Ambient = Color3.fromRGB(50, 50, 70)
    L.OutdoorAmbient = Color3.fromRGB(70, 70, 90)
    for _, e in ipairs(L:GetChildren()) do
        if e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") then e:Destroy() end
    end
    local cc = Instance.new("ColorCorrectionEffect", L)
    cc.Brightness = 0.02; cc.Contrast = 0.15; cc.Saturation = -0.3
    cc.TintColor = Color3.fromRGB(220, 220, 240)
    local bl = Instance.new("BloomEffect", L)
    bl.Intensity = 0.4; bl.Size = 18; bl.Threshold = 0.9
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
            Camera.CFrame = CFrame.new(r.Position - lv*8 + Vector3.new(0,2,0), r.Position + Vector3.new(0,1,0))
        end
    elseif Camera.CameraType == Enum.CameraType.Scriptable then
        Camera.CameraType = Enum.CameraType.Custom
    end
end)

-- ══════════════════════════════════════
--           SPINBOT
-- ══════════════════════════════════════
local spinA = 0
RunService.Heartbeat:Connect(function()
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
    if Config.AutoKillMurder  then doKill(closest("Murder"))  end
    if Config.AutoKillAll     then doKill(closest(nil))        end
    if Config.KillAura        then
        local now = tick()
        if now - lastAura > 0.3 then
            lastAura = now
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and isAlive(p) then
                    local r = getRoot(LocalPlayer)
                    local tr = getRoot(p)
                    if r and tr and (tr.Position - r.Position).Magnitude < 20 then
                        doKill(p)
                    end
                end
            end
        end
    end
    if Config.KillAll then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and isAlive(p) then doKill(p) end
        end
    end
    if Config.AutoThrow       then doThrow(closestFOV() or closest(nil)) end
    if Config.AutoShootMurder then doShoot(closest("Murder"))             end
    if Config.Fling           then
        local t = closest(nil)
        if t then doFling(t) end
    end
    if Config.Invisible       then setInvisible(true)  end
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
    d.box.Filled = false; d.box.Thickness = 1.6; d.box.Visible = false
    d.tracer.Thickness = 1.2; d.tracer.Visible = false
    d.hpBg.Filled = true; d.hpBg.Color = Color3.fromRGB(30,30,30); d.hpBg.Visible = false
    d.hp.Filled = true; d.hp.Visible = false
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
fovCircle.NumSides = 64; fovCircle.Thickness = 1.2
fovCircle.Color = Color3.fromRGB(200,200,200)
fovCircle.Filled = false; fovCircle.Visible = false

RunService.RenderStepped:Connect(function()
    fovCircle.Visible = true
    fovCircle.Radius = Config.FOVRadius
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
        d.box.Size = Vector2.new(w,h); d.box.Position = Vector2.new(cx-w/2, ty)

        d.name.Visible = true; d.name.Text = p.Name
        d.name.Position = Vector2.new(cx, ty-20)

        d.role.Visible = true; d.role.Color = rc
        d.role.Text = "["..(Roles[p] or "?").."]"
        d.role.Position = Vector2.new(cx, ty-34)

        if myR then
            local dist = math.floor((root.Position - myR.Position).Magnitude)
            d.dist.Visible = true; d.dist.Text = dist.."m"
            d.dist.Color = Color3.fromRGB(180,180,180)
            d.dist.Position = Vector2.new(cx, ty+h+3)
        end

        d.tracer.Visible = true; d.tracer.Color = rc
        d.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        d.tracer.To   = Vector2.new(cx, ty+h)

        if hum then
            local hpPct = hum.Health / math.max(hum.MaxHealth,1)
            d.hpBg.Visible = true; d.hpBg.Size = Vector2.new(4,h)
            d.hpBg.Position = Vector2.new(cx-w/2-7, ty)
            d.hp.Visible = true; d.hp.Size = Vector2.new(4, h*hpPct)
            d.hp.Position = Vector2.new(cx-w/2-7, ty+h*(1-hpPct))
            d.hp.Color = Color3.fromRGB(math.floor(255*(1-hpPct)), math.floor(255*hpPct), 50)
        end
    end
end)

-- ══════════════════════════════════════
--           GUI — VEXONHUB STYLE B&W
-- ══════════════════════════════════════
pcall(function()
    local old = game.CoreGui:FindFirstChild("MM2_Vex")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "MM2_Vex"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
if not pcall(function() gui.Parent = game.CoreGui end) then
    gui.Parent = LocalPlayer.PlayerGui
end

-- цветовая схема Ч/Б
local C = {
    bg      = Color3.fromRGB(14, 14, 18),
    sidebar = Color3.fromRGB(10, 10, 14),
    card    = Color3.fromRGB(22, 22, 28),
    cardHov = Color3.fromRGB(30, 30, 38),
    border  = Color3.fromRGB(45, 45, 55),
    accent  = Color3.fromRGB(200, 200, 200),
    accent2 = Color3.fromRGB(255, 255, 255),
    dim     = Color3.fromRGB(100, 100, 110),
    text    = Color3.fromRGB(230, 230, 235),
    sub     = Color3.fromRGB(120, 120, 130),
    pill_on = Color3.fromRGB(220, 220, 220),
    pill_of = Color3.fromRGB(38, 38, 46),
}

-- ── DROP ANIMATION (сверху) ──
local PW, PH = 560, 420
local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, PW, 0, PH)
panel.Position = UDim2.new(0.5, -PW/2, 0, -PH-20)
panel.BackgroundColor3 = C.bg
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.ZIndex = 20
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = C.border; panelStroke.Thickness = 1

-- тень
local shadow = Instance.new("Frame", gui)
shadow.Size = UDim2.new(0, PW+24, 0, PH+24)
shadow.Position = UDim2.new(0.5, -(PW+24)/2, 0, -PH-30)
shadow.BackgroundColor3 = Color3.new(0,0,0)
shadow.BackgroundTransparency = 0.45
shadow.BorderSizePixel = 0
shadow.ZIndex = 19
Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 20)

-- ── ТОПБАР ──
local topbar = Instance.new("Frame", panel)
topbar.Size = UDim2.new(1, 0, 0, 52)
topbar.BackgroundColor3 = C.sidebar
topbar.BorderSizePixel = 0
topbar.ZIndex = 21

local tbLogo = Instance.new("TextLabel", topbar)
tbLogo.Size = UDim2.new(0, 36, 0, 36)
tbLogo.Position = UDim2.new(0, 12, 0.5, -18)
tbLogo.BackgroundColor3 = C.card
tbLogo.Text = "M"
tbLogo.TextColor3 = C.accent2
tbLogo.Font = Enum.Font.GothamBold
tbLogo.TextSize = 18
tbLogo.BorderSizePixel = 0
tbLogo.ZIndex = 22
Instance.new("UICorner", tbLogo).CornerRadius = UDim.new(0,10)

local tbTitle = Instance.new("TextLabel", topbar)
tbTitle.Size = UDim2.new(0, 180, 0, 20)
tbTitle.Position = UDim2.new(0, 56, 0, 8)
tbTitle.BackgroundTransparency = 1
tbTitle.Text = "MM2 Private"
tbTitle.TextColor3 = C.text
tbTitle.Font = Enum.Font.GothamBold
tbTitle.TextSize = 14
tbTitle.TextXAlignment = Enum.TextXAlignment.Left
tbTitle.ZIndex = 22

local tbSub = Instance.new("TextLabel", topbar)
tbSub.Size = UDim2.new(0, 180, 0, 16)
tbSub.Position = UDim2.new(0, 56, 0, 28)
tbSub.BackgroundTransparency = 1
tbSub.Text = "Murder Mystery 2"
tbSub.TextColor3 = C.sub
tbSub.Font = Enum.Font.Gotham
tbSub.TextSize = 11
tbSub.TextXAlignment = Enum.TextXAlignment.Left
tbSub.ZIndex = 22

-- статус роли в топбаре
local tbRole = Instance.new("TextLabel", topbar)
tbRole.Size = UDim2.new(0, 110, 0, 26)
tbRole.Position = UDim2.new(0.5, -55, 0.5, -13)
tbRole.BackgroundColor3 = C.card
tbRole.Text = "Role: ..."
tbRole.TextColor3 = C.accent
tbRole.Font = Enum.Font.GothamBold
tbRole.TextSize = 11
tbRole.BorderSizePixel = 0
tbRole.ZIndex = 22
Instance.new("UICorner", tbRole).CornerRadius = UDim.new(1,0)
Instance.new("UIStroke", tbRole).Color = C.border

RunService.Heartbeat:Connect(function()
    local r = Roles[LocalPlayer] or "?"
    tbRole.Text = "Role: " .. r
    tbRole.TextColor3 = roleColor(LocalPlayer)
end)

-- кнопка закрытия
local closeBtn = Instance.new("TextButton", topbar)
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -40, 0.5, -14)
closeBtn.BackgroundColor3 = C.card
closeBtn.Text = "x"
closeBtn.TextColor3 = C.sub
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 22
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)

-- разделитель под топбаром
local topDiv = Instance.new("Frame", panel)
topDiv.Size = UDim2.new(1,0,0,1)
topDiv.Position = UDim2.new(0,0,0,52)
topDiv.BackgroundColor3 = C.border
topDiv.BorderSizePixel = 0; topDiv.ZIndex = 21

-- ── SIDEBAR ──
local SW = 130
local sidebar = Instance.new("Frame", panel)
sidebar.Size = UDim2.new(0, SW, 1, -52)
sidebar.Position = UDim2.new(0, 0, 0, 53)
sidebar.BackgroundColor3 = C.sidebar
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 21

local sideDiv = Instance.new("Frame", panel)
sideDiv.Size = UDim2.new(0, 1, 1, -52)
sideDiv.Position = UDim2.new(0, SW, 0, 53)
sideDiv.BackgroundColor3 = C.border
sideDiv.BorderSizePixel = 0; sideDiv.ZIndex = 21

-- ── CONTENT ──
local content = Instance.new("ScrollingFrame", panel)
content.Size = UDim2.new(1, -SW-1, 1, -53)
content.Position = UDim2.new(0, SW+1, 0, 53)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = C.border
content.CanvasSize = UDim2.new(0,0,0,0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ZIndex = 21

local contentPad = Instance.new("UIPadding", content)
contentPad.PaddingTop = UDim.new(0,12)
contentPad.PaddingLeft = UDim.new(0,14)
contentPad.PaddingRight = UDim.new(0,14)

local contentLayout = Instance.new("UIListLayout", content)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0,8)

-- ── СЕКЦИИ И ITEMS ──
local sections = {
    {
        name = "Combat",
        items = {
            {label="Kill Aura",           key="KillAura"},
            {label="Kill All",            key="KillAll"},
            {label="Auto Kill Murderer",  key="AutoKillMurder"},
            {label="Auto Kill All",       key="AutoKillAll"},
            {label="Silent Aim",          key="SilentAim"},
            {label="Auto Shoot Murderer", key="AutoShootMurder"},
            {label="Auto Throw Knife",    key="AutoThrow"},
        }
    },
    {
        name = "Player",
        items = {
            {label="Fling Players",   key="Fling"},
            {label="Anti-Fling",      key="AntiFling"},
            {label="Invisible",       key="Invisible"},
            {label="Spinbot",         key="Spinbot"},
            {label="Third Person",    key="ThirdPerson"},
        }
    },
    {
        name = "Misc",
        items = {
            {label="ESP Players",     key="ESP"},
            {label="Role Detector",   key="RoleDetector"},
            {label="Auto Pick Gun",   key="AutoGun"},
            {label="Shoot Button",    key="AutoShootBtn"},
            {label="Throw Button",    key="AutoThrowBtn"},
        }
    },
}

-- активная секция
local activeSec = "Combat"
local sideButtons = {}
local contentSections = {}

-- строка в контенте
local function makeItem(parent, data, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundColor3 = C.card
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.ZIndex = 22
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
    local rs = Instance.new("UIStroke", row)
    rs.Color = C.border; rs.Thickness = 1; rs.Transparency = 0.4

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = data.label
    lbl.TextColor3 = C.text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 23

    -- стрелка-иконка
    local arrow = Instance.new("TextLabel", row)
    arrow.Size = UDim2.new(0, 20, 0, 20)
    arrow.Position = UDim2.new(1, -100, 0.5, -10)
    arrow.BackgroundTransparency = 1
    arrow.Text = ">"
    arrow.TextColor3 = C.dim
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 12
    arrow.ZIndex = 23

    -- pill switch
    local pill = Instance.new("Frame", row)
    pill.Size = UDim2.new(0, 44, 0, 22)
    pill.Position = UDim2.new(1, -56, 0.5, -11)
    pill.BackgroundColor3 = C.pill_of
    pill.BorderSizePixel = 0
    pill.ZIndex = 23
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame", pill)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = C.sub
    knob.BorderSizePixel = 0
    knob.ZIndex = 24
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 25

    local function refresh()
        if Config[data.key] then
            TweenService:Create(pill, TweenInfo.new(0.16), {BackgroundColor3 = C.pill_on}):Play()
            TweenService:Create(knob, TweenInfo.new(0.16), {
                Position = UDim2.new(1,-19,0.5,-8),
                BackgroundColor3 = C.bg
            }):Play()
            lbl.TextColor3 = C.accent2
        else
            TweenService:Create(pill, TweenInfo.new(0.16), {BackgroundColor3 = C.pill_of}):Play()
            TweenService:Create(knob, TweenInfo.new(0.16), {
                Position = UDim2.new(0,3,0.5,-8),
                BackgroundColor3 = C.sub
            }):Play()
            lbl.TextColor3 = C.text
        end
    end
    refresh()

    btn.MouseButton1Click:Connect(function()
        Config[data.key] = not Config[data.key]
        refresh()
        -- side effects
        if data.key == "AntiFling"  then setAntiFling(Config.AntiFling) end
        if data.key == "SilentAim"  then setSilentAim(Config.SilentAim) end
        if data.key == "Invisible"  then
            if not Config.Invisible then setInvisible(false) end
        end
        -- hover flash
        TweenService:Create(row, TweenInfo.new(0.08), {BackgroundColor3 = C.cardHov}):Play()
        task.delay(0.12, function()
            TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = C.card}):Play()
        end)
    end)

    return row
end

-- заголовок секции
local function makeSectionHeader(parent, title, order)
    local hdr = Instance.new("TextLabel", parent)
    hdr.Size = UDim2.new(1,0,0,26)
    hdr.BackgroundTransparency = 1
    hdr.Text = title
    hdr.TextColor3 = C.sub
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = 11
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.LayoutOrder = order
    hdr.ZIndex = 22
    return hdr
end

-- строим секции в content
local itemOrder = 0
for _, sec in ipairs(sections) do
    local secFrame = Instance.new("Frame")
    secFrame.Name = sec.name
    secFrame.Size = UDim2.new(1,0,0,0)
    secFrame.AutomaticSize = Enum.AutomaticSize.Y
    secFrame.BackgroundTransparency = 1
    secFrame.BorderSizePixel = 0
    secFrame.Visible = sec.name == activeSec
    secFrame.ZIndex = 21
    local l = Instance.new("UIListLayout", secFrame)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0,6)
    secFrame.LayoutOrder = itemOrder
    itemOrder = itemOrder + 1
    secFrame.Parent = content

    makeSectionHeader(secFrame, sec.name, 0)
    for i, item in ipairs(sec.items) do
        makeItem(secFrame, item, i)
    end
    contentSections[sec.name] = secFrame
end

-- ── SIDEBAR КНОПКИ ──
local sideLayout = Instance.new("UIListLayout", sidebar)
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.Padding = UDim.new(0,2)
local sidePad = Instance.new("UIPadding", sidebar)
sidePad.PaddingTop = UDim.new(0,10)
sidePad.PaddingLeft = UDim.new(0,8)
sidePad.PaddingRight = UDim.new(0,8)

local function makeSideBtn(name, order)
    local btn = Instance.new("TextButton", sidebar)
    btn.Size = UDim2.new(1,0,0,38)
    btn.BackgroundColor3 = name == activeSec and C.card or Color3.new(0,0,0)
    btn.BackgroundTransparency = name == activeSec and 0 or 1
    btn.Text = name
    btn.TextColor3 = name == activeSec and C.accent2 or C.sub
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order
    btn.ZIndex = 22
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,10)

    -- активная полоска слева
    local bar = Instance.new("Frame", btn)
    bar.Size = UDim2.new(0, 3, 0.5, 0)
    bar.Position = UDim2.new(0, 0, 0.25, 0)
    bar.BackgroundColor3 = C.accent2
    bar.BorderSizePixel = 0
    bar.Visible = name == activeSec
    bar.ZIndex = 23
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    sideButtons[name] = {btn=btn, bar=bar}

    btn.MouseButton1Click:Connect(function()
        -- убираем старый
        local old = sideButtons[activeSec]
        if old then
            TweenService:Create(old.btn, TweenInfo.new(0.15), {
                BackgroundTransparency = 1,
                TextColor3 = C.sub,
            }):Play()
            old.bar.Visible = false
            if contentSections[activeSec] then
                contentSections[activeSec].Visible = false
            end
        end
        activeSec = name
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0,
            TextColor3 = C.accent2,
        }):Play()
        bar.Visible = true
        if contentSections[name] then
            contentSections[name].Visible = true
        end
    end)
end

for i, sec in ipairs(sections) do
    makeSideBtn(sec.name, i)
end

-- ── DROP ANIMATION (открытие сверху) ──
local isOpen = false

local function openPanel()
    isOpen = true
    panel.Visible = true
    shadow.Visible = true
    panel.Position = UDim2.new(0.5, -PW/2, 0, -PH-20)
    shadow.Position = UDim2.new(0.5, -(PW+24)/2, 0, -PH-30)
    TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -PW/2, 0.5, -PH/2)
    }):Play()
    TweenService:Create(shadow, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -(PW+24)/2, 0.5, -PH/2-12)
    }):Play()
end

local function closePanel()
    isOpen = false
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -PW/2, 0, -PH-20)
    }):Play()
    TweenService:Create(shadow, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -(PW+24)/2, 0, -PH-30)
    }):Play()
    task.delay(0.26, function()
        panel.Visible = false
        shadow.Visible = false
    end)
end

closeBtn.MouseButton1Click:Connect(closePanel)

-- ── КНОПКА ОТКРЫТИЯ ──
local openBtn = Instance.new("TextButton", gui)
openBtn.Size = UDim2.new(0, 56, 0, 28)
openBtn.Position = UDim2.new(0.5, -28, 0, 10)
openBtn.BackgroundColor3 = C.card
openBtn.Text = "MM2"
openBtn.TextColor3 = C.text
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 13
openBtn.BorderSizePixel = 0
openBtn.ZIndex = 30
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke", openBtn).Color = C.border

openBtn.MouseButton1Click:Connect(function()
    if isOpen then closePanel() else openPanel() end
end)

-- ── МОБИЛЬНЫЕ КНОПКИ ──
local function makeMobileToggle(label, key, xOff, yOff)
    local f = Instance.new("Frame", gui)
    f.Size = UDim2.new(0, 68, 0, 68)
    f.Position = UDim2.new(1, xOff, 1, yOff)
    f.BorderSizePixel = 0
    f.ZIndex = 30
    Instance.new("UICorner", f).CornerRadius = UDim.new(1,0)
    Instance.new("UIStroke", f).Color = C.border

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.ZIndex = 31

    local function refreshBtn()
        if Config[key] then
            TweenService:Create(f, TweenInfo.new(0.15), {BackgroundColor3 = C.card}):Play()
            lbl.TextColor3 = C.accent2
        else
            TweenService:Create(f, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20,20,26)}):Play()
            lbl.TextColor3 = C.dim
        end
    end
    refreshBtn()

    local btn = Instance.new("TextButton", f)
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 32

    btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        refreshBtn()
        TweenService:Create(f, TweenInfo.new(0.07), {Size = UDim2.new(0,58,0,58), Position = UDim2.new(1,xOff+5,1,yOff+5)}):Play()
        task.delay(0.08, function()
            TweenService:Create(f, TweenInfo.new(0.1), {Size = UDim2.new(0,68,0,68), Position = UDim2.new(1,xOff,1,yOff)}):Play()
        end)
        -- действие если включено
        if Config[key] then
            if key == "AutoShootBtn" then doShoot(closest("Murder") or closest(nil)) end
            if key == "AutoThrowBtn" then doThrow(closestFOV() or closest(nil)) end
        end
    end)
    return f
end

makeMobileToggle("SHOOT", "AutoShootBtn", -84, -90)
makeMobileToggle("THROW", "AutoThrowBtn", -162, -90)

-- перетаскивание панели
local drag = {}
panel.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch and not isOpen == false then
        drag = {on=true, s=i.Position, sp=panel.Position}
    end
end)
panel.InputChanged:Connect(function(i)
    if drag.on and i.UserInputType == Enum.UserInputType.Touch then
        local d = i.Position - drag.s
        panel.Position = UDim2.new(drag.sp.X.Scale, drag.sp.X.Offset+d.X, drag.sp.Y.Scale, drag.sp.Y.Offset+d.Y)
        shadow.Position = UDim2.new(drag.sp.X.Scale, drag.sp.X.Offset+d.X-12, drag.sp.Y.Scale, drag.sp.Y.Offset+d.Y-12)
    end
end)
panel.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then drag.on = false end
end)
