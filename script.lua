-- language: Lua, executor: Delta, target: Roblox Murder Mystery 2 (Mobile)
-- ESP + AutoKill + RoleDetector + ThirdPerson + Spinbot + AimFOV + AutoGun + Visuals + GUI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ══════════════════════════════════════
--           КОНФИГ
-- ══════════════════════════════════════
local Config = {
    ESP             = true,
    RoleDetector    = true,
    AutoKillMurder  = false,
    AutoKillAll     = false,
    ThirdPerson     = false,
    Spinbot         = false,
    AimFOV          = true,
    AutoGun         = true,
    AutoThrow       = false,
    AutoShootSheriff= false,
    WorldVisuals    = true,
    FOVRadius       = 120,
    SpinSpeed       = 8,
    ThirdPersonDist = 8,

    -- цвета
    MurderColor  = Color3.fromRGB(255, 50,  50),
    SheriffColor = Color3.fromRGB(50,  150, 255),
    InnoColor    = Color3.fromRGB(180, 180, 180),
    AccentColor  = Color3.fromRGB(180, 60,  220),
    Accent2      = Color3.fromRGB(80,  120, 255),
    GunColor     = Color3.fromRGB(255, 200, 50),
}

-- ══════════════════════════════════════
--           РОЛИ
-- ══════════════════════════════════════
local Roles = {}  -- [player] = "Murder" / "Sheriff" / "Innocent"

local function detectRoles()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local char = p.Character
        if not char then continue end
        -- MM2 хранит роль в leaderstats или в тегах персонажа
        local function checkTag(name)
            return char:FindFirstChild(name) ~= nil
        end
        if checkTag("Knife") or checkTag("KnifeModel") or checkTag("MurderWeapon") then
            Roles[p] = "Murder"
        elseif checkTag("Gun") or checkTag("GunModel") or checkTag("SheriffGun") then
            Roles[p] = "Sheriff"
        else
            -- через backpack
            local bp = p:FindFirstChild("Backpack")
            if bp then
                if bp:FindFirstChild("Knife") or bp:FindFirstChild("MM2Knife") then
                    Roles[p] = "Murder"
                elseif bp:FindFirstChild("Gun") or bp:FindFirstChild("MM2Gun") then
                    Roles[p] = "Sheriff"
                else
                    Roles[p] = "Innocent"
                end
            else
                Roles[p] = "Innocent"
            end
        end
    end
    -- своя роль
    local myChar = LocalPlayer.Character
    local myBP = LocalPlayer:FindFirstChild("Backpack")
    if myChar then
        if myChar:FindFirstChild("Knife") or (myBP and myBP:FindFirstChild("Knife")) then
            Roles[LocalPlayer] = "Murder"
        elseif myChar:FindFirstChild("Gun") or (myBP and myBP:FindFirstChild("Gun")) then
            Roles[LocalPlayer] = "Sheriff"
        else
            Roles[LocalPlayer] = "Innocent"
        end
    end
end

local function getRoleColor(p)
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

local function closestTarget(filterRole)
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not isAlive(p) then continue end
        if filterRole and Roles[p] ~= filterRole then continue end
        local root = getRoot(p)
        local myRoot = getRoot(LocalPlayer)
        if root and myRoot then
            local d = (root.Position - myRoot.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = p
            end
        end
    end
    return best
end

local function closestToMouse(maxFOV)
    local best, bestDist = nil, maxFOV
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not isAlive(p) then continue end
        local root = getRoot(p)
        if not root then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(root.Position)
        if not onScreen then continue end
        local mp = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
        if d < bestDist then
            bestDist = d
            best = p
        end
    end
    return best
end

-- ══════════════════════════════════════
--           DRAWING ESP
-- ══════════════════════════════════════
local espObjs = {}

local function makeESP(p)
    if p == LocalPlayer then return end
    local d = {
        box      = Drawing.new("Square"),
        name     = Drawing.new("Text"),
        role     = Drawing.new("Text"),
        dist     = Drawing.new("Text"),
        tracer   = Drawing.new("Line"),
        hpBg     = Drawing.new("Square"),
        hpBar    = Drawing.new("Square"),
        cornerTL = Drawing.new("Square"),
        cornerTR = Drawing.new("Square"),
        cornerBL = Drawing.new("Square"),
        cornerBR = Drawing.new("Square"),
    }
    -- box
    d.box.Filled = false
    d.box.Thickness = 1.5
    d.box.Visible = false
    -- угловые акценты
    for _, k in ipairs({"cornerTL","cornerTR","cornerBL","cornerBR"}) do
        d[k].Filled = true
        d[k].Thickness = 1
        d[k].Visible = false
    end
    -- текст
    for _, k in ipairs({"name","role","dist"}) do
        d[k].Size = 13
        d[k].Font = 2
        d[k].Outline = true
        d[k].OutlineColor = Color3.new(0,0,0)
        d[k].Visible = false
        d[k].Color = Color3.new(1,1,1)
    end
    -- трейсер
    d.tracer.Thickness = 1.2
    d.tracer.Visible = false
    -- хп
    d.hpBg.Filled = true
    d.hpBg.Color = Color3.fromRGB(30,30,30)
    d.hpBg.Visible = false
    d.hpBar.Filled = true
    d.hpBar.Visible = false

    espObjs[p] = d
end

for _, p in ipairs(Players:GetPlayers()) do makeESP(p) end
Players.PlayerAdded:Connect(makeESP)
Players.PlayerRemoving:Connect(function(p)
    if espObjs[p] then
        for _, o in pairs(espObjs[p]) do pcall(function() o.Visible = false end) end
        espObjs[p] = nil
        Roles[p] = nil
    end
end)

-- FOV круг
local fovCircle = Drawing.new("Circle")
fovCircle.Radius = Config.FOVRadius
fovCircle.Thickness = 1.5
fovCircle.NumSides = 64
fovCircle.Color = Color3.fromRGB(200, 200, 255)
fovCircle.Filled = false
fovCircle.Visible = false

-- ══════════════════════════════════════
--           WORLD VISUALS
-- ══════════════════════════════════════
local function applyWorldVisuals()
    if not Config.WorldVisuals then return end
    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.Brightness = 3
        lighting.Ambient = Color3.fromRGB(80, 60, 120)
        lighting.OutdoorAmbient = Color3.fromRGB(100, 80, 160)
        lighting.FogEnd = 1200
        lighting.FogColor = Color3.fromRGB(60, 40, 90)

        -- убираем старые эффекты
        for _, e in ipairs(lighting:GetChildren()) do
            if e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("BlurEffect") then
                e:Destroy()
            end
        end

        -- Color Correction — фиолетовый ночной тон
        local cc = Instance.new("ColorCorrectionEffect", lighting)
        cc.Brightness = 0.04
        cc.Contrast   = 0.18
        cc.Saturation = 0.3
        cc.TintColor  = Color3.fromRGB(200, 170, 255)

        -- Bloom
        local bloom = Instance.new("BloomEffect", lighting)
        bloom.Intensity = 0.6
        bloom.Size      = 24
        bloom.Threshold = 0.85

        -- мягкая глубина
        local blur = Instance.new("DepthOfFieldEffect", lighting)
        blur.FarIntensity  = 0
        blur.NearIntensity = 0
        blur.FocusDistance = 60
        blur.InFocusRadius = 40
    end)
end

applyWorldVisuals()

-- ══════════════════════════════════════
--           АВТО-ПОДБОР ПУШКИ
-- ══════════════════════════════════════
local function tryPickupGun()
    if not Config.AutoGun then return end
    local myRole = Roles[LocalPlayer]
    if myRole == "Murder" then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") and (obj.Name:lower():find("gun") or obj.Name:lower():find("sheriff")) then
            local part = obj:FindFirstChildOfClass("BasePart") or obj.PrimaryPart
            local myRoot = getRoot(LocalPlayer)
            if part and myRoot then
                local d = (part.Position - myRoot.Position).Magnitude
                if d < 20 then
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
--           AUTO KILL
-- ══════════════════════════════════════
local lastKill = 0

local function tryKill(target)
    if not target then return end
    local myRoot = getRoot(LocalPlayer)
    local tRoot = getRoot(target)
    if not myRoot or not tRoot then return end
    local now = tick()
    if now - lastKill < 0.5 then return end
    lastKill = now
    -- телепорт к цели и удар ножом
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = tRoot.CFrame + Vector3.new(0, 0, 2.5)
    end
    -- ищем нож/инструмент убийства
    local function fireKnife()
        for _, v in ipairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") and (
                v.Name:lower():find("kill") or
                v.Name:lower():find("stab") or
                v.Name:lower():find("knife")
            ) then
                pcall(function() v:FireServer(target.Character) end)
            end
        end
    end
    fireKnife()
end

-- ══════════════════════════════════════
--           AUTO THROW (нож)
-- ══════════════════════════════════════
local function tryThrow(target)
    if not target then return end
    local tRoot = getRoot(target)
    if not tRoot then return end
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") and (
            v.Name:lower():find("throw") or
            v.Name:lower():find("knife")
        ) then
            pcall(function() v:FireServer(tRoot.Position) end)
        end
    end
end

-- ══════════════════════════════════════
--           AUTO SHOOT SHERIFF
-- ══════════════════════════════════════
local lastShot = 0
local function tryShootSheriff()
    if not Config.AutoShootSheriff then return end
    if Roles[LocalPlayer] ~= "Sheriff" then return end
    local target = closestTarget("Murder")
    if not target then return end
    local now = tick()
    if now - lastShot < 1.2 then return end
    lastShot = now
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") and (
            v.Name:lower():find("shoot") or
            v.Name:lower():find("fire") or
            v.Name:lower():find("gun")
        ) then
            pcall(function() v:FireServer(target.Character) end)
        end
    end
end

-- ══════════════════════════════════════
--           ТРЕТЬЕ ЛИЦО
-- ══════════════════════════════════════
local origCamType
RunService.RenderStepped:Connect(function()
    if Config.ThirdPerson then
        local myRoot = getRoot(LocalPlayer)
        if myRoot then
            Camera.CameraType = Enum.CameraType.Scriptable
            local lookVec = Camera.CFrame.LookVector
            Camera.CFrame = CFrame.new(
                myRoot.Position - lookVec * Config.ThirdPersonDist + Vector3.new(0, 2, 0),
                myRoot.Position + Vector3.new(0, 1, 0)
            )
        end
    else
        if Camera.CameraType == Enum.CameraType.Scriptable then
            Camera.CameraType = Enum.CameraType.Custom
        end
    end
end)

-- ══════════════════════════════════════
--           SPINBOT
-- ══════════════════════════════════════
local spinAngle = 0
RunService.Heartbeat:Connect(function(dt)
    if not Config.Spinbot then return end
    local myRoot = getRoot(LocalPlayer)
    if not myRoot then return end
    spinAngle = (spinAngle + Config.SpinSpeed) % 360
    local rad = math.rad(spinAngle)
    local cf = myRoot.CFrame
    myRoot.CFrame = CFrame.new(cf.Position) * CFrame.Angles(0, rad, 0)
end)

-- ══════════════════════════════════════
--           ГЛАВНЫЙ LOOP
-- ══════════════════════════════════════
local ticker = 0
RunService.RenderStepped:Connect(function(dt)
    ticker = ticker + dt
    if ticker > 0.5 then
        ticker = 0
        detectRoles()
        tryPickupGun()
        tryShootSheriff()
    end

    -- AutoKill
    if Config.AutoKillMurder then
        local t = closestTarget("Murder")
        tryKill(t)
    end
    if Config.AutoKillAll then
        local t = closestTarget(nil)
        if t and t ~= LocalPlayer then tryKill(t) end
    end

    -- AutoThrow
    if Config.AutoThrow then
        local t = closestToMouse(Config.FOVRadius)
        if t then tryThrow(t) end
    end

    -- FOV круг
    fovCircle.Visible = Config.AimFOV
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Radius = Config.FOVRadius

    -- ESP loop
    for p, d in pairs(espObjs) do
        local show = Config.ESP and isAlive(p) and p.Character ~= nil
        if not show then
            for _, o in pairs(d) do pcall(function() o.Visible = false end) end
            continue
        end
        local char = p.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local myRoot = getRoot(LocalPlayer)
        if not root then continue end

        local top, topVis = Camera:WorldToViewportPoint(root.Position + Vector3.new(0,3.2,0))
        local bot, _      = Camera:WorldToViewportPoint(root.Position - Vector3.new(0,3.2,0))

        if not topVis then
            for _, o in pairs(d) do pcall(function() o.Visible = false end) end
            continue
        end

        local h  = math.abs(top.Y - bot.Y)
        local w  = h * 0.52
        local cx = top.X
        local ty = math.min(top.Y, bot.Y)
        local rc = getRoleColor(p)

        -- box
        d.box.Visible  = true
        d.box.Color    = rc
        d.box.Size     = Vector2.new(w, h)
        d.box.Position = Vector2.new(cx - w/2, ty)

        -- угловые L-образные акценты
        local cs = 7 -- угловой размер
        local corners = {
            {d.cornerTL, Vector2.new(cx - w/2,     ty),          Vector2.new(cs, 2)},
            {d.cornerTL, Vector2.new(cx - w/2,     ty),          Vector2.new(2,  cs)},
            {d.cornerTR, Vector2.new(cx + w/2 - cs,ty),          Vector2.new(cs, 2)},
            {d.cornerTR, Vector2.new(cx + w/2 - 2, ty),          Vector2.new(2,  cs)},
            {d.cornerBL, Vector2.new(cx - w/2,     ty+h-2),      Vector2.new(cs, 2)},
            {d.cornerBL, Vector2.new(cx - w/2,     ty+h-cs),     Vector2.new(2,  cs)},
            {d.cornerBR, Vector2.new(cx + w/2 - cs,ty+h-2),      Vector2.new(cs, 2)},
            {d.cornerBR, Vector2.new(cx + w/2 - 2, ty+h-cs),     Vector2.new(2,  cs)},
        }
        -- упрощённо: один угол на объект
        d.cornerTL.Visible  = true
        d.cornerTL.Color    = Color3.new(1,1,1)
        d.cornerTL.Size     = Vector2.new(cs, 2)
        d.cornerTL.Position = Vector2.new(cx - w/2, ty)
        d.cornerTR.Visible  = true
        d.cornerTR.Color    = Color3.new(1,1,1)
        d.cornerTR.Size     = Vector2.new(cs, 2)
        d.cornerTR.Position = Vector2.new(cx + w/2 - cs, ty)
        d.cornerBL.Visible  = true
        d.cornerBL.Color    = Color3.new(1,1,1)
        d.cornerBL.Size     = Vector2.new(cs, 2)
        d.cornerBL.Position = Vector2.new(cx - w/2, ty + h - 2)
        d.cornerBR.Visible  = true
        d.cornerBR.Color    = Color3.new(1,1,1)
        d.cornerBR.Size     = Vector2.new(cs, 2)
        d.cornerBR.Position = Vector2.new(cx + w/2 - cs, ty + h - 2)

        -- имя
        d.name.Visible  = true
        d.name.Text     = p.Name
        d.name.Color    = Color3.new(1,1,1)
        d.name.Position = Vector2.new(cx, ty - 20)

        -- роль
        local roleStr = Roles[p] or "?"
        d.role.Visible  = true
        d.role.Text     = "[" .. roleStr .. "]"
        d.role.Color    = rc
        d.role.Position = Vector2.new(cx, ty - 34)

        -- дистанция
        if myRoot then
            local dist = math.floor((root.Position - myRoot.Position).Magnitude)
            d.dist.Visible  = true
            d.dist.Text     = dist .. "m"
            d.dist.Color    = Color3.fromRGB(180,180,180)
            d.dist.Position = Vector2.new(cx, ty + h + 3)
        end

        -- трейсер
        d.tracer.Visible = true
        d.tracer.Color   = rc
        d.tracer.From    = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        d.tracer.To      = Vector2.new(cx, ty + h)

        -- хп бар
        if hum then
            local hp = hum.Health / math.max(hum.MaxHealth, 1)
            d.hpBg.Visible  = true
            d.hpBg.Size     = Vector2.new(4, h)
            d.hpBg.Position = Vector2.new(cx - w/2 - 7, ty)
            d.hpBar.Visible = true
            d.hpBar.Size    = Vector2.new(4, h * hp)
            d.hpBar.Position= Vector2.new(cx - w/2 - 7, ty + h*(1-hp))
            d.hpBar.Color   = Color3.fromRGB(
                math.floor(255*(1-hp)),
                math.floor(255*hp),
                60
            )
        end
    end
end)

-- ══════════════════════════════════════
--           GUI
-- ══════════════════════════════════════
pcall(function()
    local old = game.CoreGui:FindFirstChild("MM2_Hub")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "MM2_Hub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
local ok = pcall(function() gui.Parent = game.CoreGui end)
if not ok then gui.Parent = LocalPlayer.PlayerGui end

-- ── иконка-тогл ──
local iconBtn = Instance.new("ImageButton", gui)
iconBtn.Size = UDim2.new(0, 64, 0, 64)
iconBtn.Position = UDim2.new(0, 10, 0.5, -32)
iconBtn.BackgroundColor3 = Color3.fromRGB(20, 16, 32)
iconBtn.BorderSizePixel = 0
iconBtn.ZIndex = 20
iconBtn.Image = "rbxassetid://0"  -- fallback пока нет загруженного asset
Instance.new("UICorner", iconBtn).CornerRadius = UDim.new(1, 0)

-- обводка иконки с анимацией
local iconStroke = Instance.new("UIStroke", iconBtn)
iconStroke.Color = Config.AccentColor
iconStroke.Thickness = 2.5
TweenService:Create(iconStroke,
    TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    {Color = Config.Accent2}
):Play()

-- текст если нет картинки
local iconTxt = Instance.new("TextLabel", iconBtn)
iconTxt.Size = UDim2.new(1,0,1,0)
iconTxt.BackgroundTransparency = 1
iconTxt.Text = "☽"
iconTxt.TextColor3 = Color3.new(1,1,1)
iconTxt.Font = Enum.Font.GothamBold
iconTxt.TextSize = 28
iconTxt.ZIndex = 21

-- ── основная панель ──
local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 290, 0, 480)
panel.Position = UDim2.new(0, 86, 0.5, -240)
panel.BackgroundColor3 = Color3.fromRGB(12, 10, 20)
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 15
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 22)

-- тень панели
local panelShadow = Instance.new("Frame", gui)
panelShadow.Size = UDim2.new(0, 298, 0, 488)
panelShadow.Position = UDim2.new(0, 89, 0.5, -236)
panelShadow.BackgroundColor3 = Color3.new(0,0,0)
panelShadow.BackgroundTransparency = 0.5
panelShadow.BorderSizePixel = 0
panelShadow.Visible = false
panelShadow.ZIndex = 14
Instance.new("UICorner", panelShadow).CornerRadius = UDim.new(0, 24)

-- шапка
local header = Instance.new("Frame", panel)
header.Size = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = Config.AccentColor
header.BorderSizePixel = 0
header.ZIndex = 16
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 22)
local hGrad = Instance.new("UIGradient", header)
hGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 50, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 130, 255)),
})
hGrad.Rotation = 35

local titleLbl = Instance.new("TextLabel", header)
titleLbl.Size = UDim2.new(1, -16, 1, 0)
titleLbl.Position = UDim2.new(0, 16, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "☽  MURDER MYSTERY 2"
titleLbl.TextColor3 = Color3.new(1,1,1)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 17
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 17

-- полоса под шапкой
local divLine = Instance.new("Frame", panel)
divLine.Size = UDim2.new(0.88, 0, 0, 1)
divLine.Position = UDim2.new(0.06, 0, 0, 62)
divLine.BackgroundColor3 = Color3.fromRGB(55, 45, 85)
divLine.BorderSizePixel = 0
divLine.ZIndex = 16

-- роль-детектор строка
local roleBox = Instance.new("Frame", panel)
roleBox.Size = UDim2.new(1, -24, 0, 38)
roleBox.Position = UDim2.new(0, 12, 0, 70)
roleBox.BackgroundColor3 = Color3.fromRGB(22, 18, 38)
roleBox.BorderSizePixel = 0
roleBox.ZIndex = 16
Instance.new("UICorner", roleBox).CornerRadius = UDim.new(0, 12)

local roleLbl = Instance.new("TextLabel", roleBox)
roleLbl.Size = UDim2.new(1, -12, 1, 0)
roleLbl.Position = UDim2.new(0, 12, 0, 0)
roleLbl.BackgroundTransparency = 1
roleLbl.Text = "👤 Роль: определяю..."
roleLbl.TextColor3 = Color3.new(1,1,1)
roleLbl.Font = Enum.Font.GothamBold
roleLbl.TextSize = 13
roleLbl.TextXAlignment = Enum.TextXAlignment.Left
roleLbl.ZIndex = 17

RunService.Heartbeat:Connect(function()
    if not Config.RoleDetector then
        roleLbl.Text = "👤 Роль: выкл"
        return
    end
    local r = Roles[LocalPlayer] or "?"
    local col = getRoleColor(LocalPlayer)
    roleLbl.Text = "👤 Моя роль:  " .. r
    roleLbl.TextColor3 = col
end)

-- строки настроек
local function makeToggle(parent, lbl, icon, configKey, yPos)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -24, 0, 46)
    row.Position = UDim2.new(0, 12, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(20, 16, 34)
    row.BorderSizePixel = 0
    row.ZIndex = 16
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 14)
    -- левая цветная полоска
    local bar = Instance.new("Frame", row)
    bar.Size = UDim2.new(0, 3, 0.6, 0)
    bar.Position = UDim2.new(0, 0, 0.2, 0)
    bar.BackgroundColor3 = Config.AccentColor
    bar.BorderSizePixel = 0
    bar.ZIndex = 17
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local iconL = Instance.new("TextLabel", row)
    iconL.Size = UDim2.new(0, 32, 1, 0)
    iconL.Position = UDim2.new(0, 8, 0, 0)
    iconL.BackgroundTransparency = 1
    iconL.Text = icon
    iconL.TextSize = 18
    iconL.Font = Enum.Font.GothamBold
    iconL.ZIndex = 17

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(0.58, 0, 1, 0)
    nameLbl.Position = UDim2.new(0, 44, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = lbl
    nameLbl.TextColor3 = Color3.fromRGB(210, 210, 230)
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextSize = 13
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 17

    local pill = Instance.new("TextButton", row)
    pill.Size = UDim2.new(0, 56, 0, 28)
    pill.Position = UDim2.new(1, -66, 0.5, -14)
    pill.BorderSizePixel = 0
    pill.Font = Enum.Font.GothamBold
    pill.TextSize = 12
    pill.AutoButtonColor = false
    pill.ZIndex = 17
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local function refresh()
        if Config[configKey] then
            TweenService:Create(pill, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(100, 220, 120)
            }):Play()
            pill.Text = "ON"
            pill.TextColor3 = Color3.fromRGB(5, 35, 5)
            TweenService:Create(bar, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(100, 220, 120)
            }):Play()
        else
            TweenService:Create(pill, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(50, 46, 72)
            }):Play()
            pill.Text = "OFF"
            pill.TextColor3 = Color3.fromRGB(140, 140, 160)
            TweenService:Create(bar, TweenInfo.new(0.15), {
                BackgroundColor3 = Config.AccentColor
            }):Play()
        end
    end
    refresh()
    pill.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        refresh()
        -- вибрация анимация
        TweenService:Create(row, TweenInfo.new(0.07), {Position = UDim2.new(0, 16, 0, yPos)}):Play()
        task.delay(0.07, function()
            TweenService:Create(row, TweenInfo.new(0.07), {Position = UDim2.new(0, 12, 0, yPos)}):Play()
        end)
    end)
    return row
end

local y = 116
local rows = {
    {"ESP Игроков",     "👁",  "ESP",             y},
    {"Роль-Детектор",   "🎭",  "RoleDetector",    y+50},
    {"AutoKill Мардер", "🔪",  "AutoKillMurder",  y+100},
    {"AutoKill Все",    "💀",  "AutoKillAll",      y+150},
    {"AutoThrow Нож",   "🗡",  "AutoThrow",       y+200},
    {"Автопозиция Пушки","🔫", "AutoGun",         y+250},
    {"Третье лицо",     "📷",  "ThirdPerson",     y+300},
    {"Spinbot",         "🌀",  "Spinbot",         y+350},
}
for _, r in ipairs(rows) do
    makeToggle(panel, r[1], r[2], r[3], r[4])
end

-- ── мобильные боевые кнопки ──
local function makeMobileBtn(txt, col, xPos, yPos, callback)
    local btn = Instance.new("TextButton", gui)
    btn.Size = UDim2.new(0, 72, 0, 72)
    btn.Position = UDim2.new(1, xPos, 1, yPos)
    btn.BackgroundColor3 = col
    btn.Text = txt
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.ZIndex = 20
    btn.BackgroundTransparency = 0.15
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    -- обводка
    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.new(1,1,1)
    s.Thickness = 1.5
    s.Transparency = 0.7
    -- нажатие
    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), {
            Size = UDim2.new(0, 62, 0, 62),
        }):Play()
        task.delay(0.08, function()
            TweenService:Create(btn, TweenInfo.new(0.1), {
                Size = UDim2.new(0, 72, 0, 72),
            }):Play()
        end)
        callback()
    end)
    return btn
end

-- кнопка выстрел в шерифа
makeMobileBtn("🔫\nШЕРИФ",
    Color3.fromRGB(50, 130, 255),
    -88, -88,
    function()
        local t = closestTarget("Murder") or closestTarget(nil)
        if t then
            for _, v in ipairs(game:GetDescendants()) do
                if v:IsA("RemoteEvent") and (v.Name:lower():find("shoot") or v.Name:lower():find("fire")) then
                    pcall(function() v:FireServer(t.Character) end)
                end
            end
        end
    end
)

-- кнопка авто-бросок
makeMobileBtn("🗡\nБРОСОК",
    Color3.fromRGB(200, 50, 80),
    -168, -88,
    function()
        local t = closestToMouse(Config.FOVRadius)
        if t then tryThrow(t) end
    end
)

-- ── открытие/закрытие панели ──
local isOpen = false
iconBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    panelShadow.Visible = isOpen
    if isOpen then
        panel.Visible = true
        panel.Size = UDim2.new(0, 0, 0, 0)
        panel.Position = UDim2.new(0, 86, 0.5, 0)
        panel.BackgroundTransparency = 1
        TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 290, 0, 480),
            Position = UDim2.new(0, 86, 0.5, -240),
            BackgroundTransparency = 0,
        }):Play()
    else
        TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0, 86, 0.5, 0),
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.21, function() panel.Visible = false end)
    end
end)

-- перетаскивание панели
local drag = {on=false, s=nil, sp=nil}
panel.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then
        drag.on = true; drag.s = i.Position; drag.sp = panel.Position
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
