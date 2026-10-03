-- language: Lua, executor: Delta, target: Roblox Blade Ball (Mobile)
-- GUI fix: CoreGui через pcall + Drawing визуалы + автопарри + ESP

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
    AutoParry      = true,
    ESP            = true,
    Visuals        = true,
    ParryDist      = 65,
    AccentColor    = Color3.fromRGB(160, 60, 255),
    ESPColor       = Color3.fromRGB(200, 80, 255),
    TracerColor    = Color3.fromRGB(100, 180, 255),
    BallColor      = Color3.fromRGB(255, 210, 0),
    DangerColor    = Color3.fromRGB(255, 50, 50),
}

-- ══════════════════════════════════════
--           УТИЛИТЫ
-- ══════════════════════════════════════
local function findBall()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = v.Name:lower()
            if n == "ball" or n == "bladeball" or n:find("ball") then
                if v.Size.Magnitude < 10 then
                    return v
                end
            end
        end
    end
end

local function getChar(p)
    return p and p.Character
end

local function getRoot(p)
    local c = getChar(p)
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- ══════════════════════════════════════
--           АВТО-ПАРРИ
-- ══════════════════════════════════════
local lastParry = 0

local function fireParry()
    local now = tick()
    if now - lastParry < 0.25 then return end
    lastParry = now
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            pcall(function() v:FireServer() end)
        end
    end
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            pcall(function() v:FireServer() end)
        end
    end
end

RunService.Heartbeat:Connect(function()
    if not Config.AutoParry then return end
    local ball = findBall()
    local root = getRoot(LocalPlayer)
    if not ball or not root then return end
    local dist = (ball.Position - root.Position).Magnitude
    if dist <= Config.ParryDist then
        fireParry()
    end
end)

-- ══════════════════════════════════════
--           DRAWING ВИЗУАЛЫ
-- ══════════════════════════════════════
local drawObjects = {}

local function newDrawing(type, props)
    local obj = Drawing.new(type)
    for k, v in pairs(props) do obj[k] = v end
    table.insert(drawObjects, obj)
    return obj
end

-- на каждого игрока: box + имя + трейсер
local espData = {}

local function setupESP(player)
    if player == LocalPlayer then return end
    local data = {
        box = newDrawing("Square", {
            Visible = false,
            Color = Config.ESPColor,
            Thickness = 2,
            Filled = false,
        }),
        corner1 = newDrawing("Square", {
            Visible = false,
            Color = Color3.new(1,1,1),
            Thickness = 1.5,
            Filled = false,
        }),
        name = newDrawing("Text", {
            Visible = false,
            Color = Color3.new(1,1,1),
            Size = 14,
            Font = 2,
            Outline = true,
            OutlineColor = Color3.new(0,0,0),
            Text = player.Name,
        }),
        dist = newDrawing("Text", {
            Visible = false,
            Color = Config.ESPColor,
            Size = 12,
            Font = 2,
            Outline = true,
            OutlineColor = Color3.new(0,0,0),
            Text = "",
        }),
        tracer = newDrawing("Line", {
            Visible = false,
            Color = Config.TracerColor,
            Thickness = 1.5,
        }),
        healthBar = newDrawing("Square", {
            Visible = false,
            Color = Color3.fromRGB(50, 220, 80),
            Thickness = 1,
            Filled = true,
        }),
        healthBg = newDrawing("Square", {
            Visible = false,
            Color = Color3.fromRGB(40, 40, 40),
            Thickness = 1,
            Filled = true,
        }),
    }
    espData[player] = data
end

for _, p in ipairs(Players:GetPlayers()) do setupESP(p) end
Players.PlayerAdded:Connect(setupESP)
Players.PlayerRemoving:Connect(function(p)
    if espData[p] then
        for _, obj in pairs(espData[p]) do
            pcall(function() obj.Visible = false end)
        end
        espData[p] = nil
    end
end)

-- мяч визуал
local ballCircle = newDrawing("Circle", {
    Visible = false,
    Color = Config.BallColor,
    Thickness = 3,
    Filled = false,
    NumSides = 32,
    Radius = 12,
})
local ballArrow = newDrawing("Triangle", {
    Visible = false,
    Color = Config.BallColor,
    Thickness = 2,
    Filled = true,
})
local ballText = newDrawing("Text", {
    Visible = false,
    Color = Config.BallColor,
    Size = 13,
    Font = 2,
    Outline = true,
    OutlineColor = Color3.new(0,0,0),
    Text = "● BALL",
})

RunService.RenderStepped:Connect(function()
    local myRoot = getRoot(LocalPlayer)

    -- ESP игроков
    for player, data in pairs(espData) do
        local show = Config.ESP and getChar(player) ~= nil
        local char = getChar(player)
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if show and root then
            -- верхняя и нижняя точки персонажа
            local topPos, topVis = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3.2, 0))
            local botPos, botVis = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3.2, 0))

            if topVis or botVis then
                local height = math.abs(topPos.Y - botPos.Y)
                local width = height * 0.55
                local cx = topPos.X
                local ty = math.min(topPos.Y, botPos.Y)

                -- box
                data.box.Visible = true
                data.box.Size = Vector2.new(width, height)
                data.box.Position = Vector2.new(cx - width/2, ty)

                -- имя
                data.name.Visible = true
                data.name.Position = Vector2.new(cx, ty - 18)
                data.name.Text = player.Name

                -- дистанция
                if myRoot then
                    local d = math.floor((root.Position - myRoot.Position).Magnitude)
                    data.dist.Visible = true
                    data.dist.Position = Vector2.new(cx, ty + height + 2)
                    data.dist.Text = d .. "m"
                    -- цвет по дистанции
                    data.box.Color = d < 25
                        and Config.DangerColor
                        or Config.ESPColor
                    data.tracer.Color = d < 25
                        and Config.DangerColor
                        or Config.TracerColor
                end

                -- трейсер
                data.tracer.Visible = true
                data.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y * 0.95)
                data.tracer.To = Vector2.new(cx, ty + height)

                -- хп бар
                if hum then
                    local hp = hum.Health / hum.MaxHealth
                    local barH = height
                    local barX = cx - width/2 - 6
                    data.healthBg.Visible = true
                    data.healthBg.Size = Vector2.new(4, barH)
                    data.healthBg.Position = Vector2.new(barX, ty)
                    data.healthBar.Visible = true
                    data.healthBar.Size = Vector2.new(4, barH * hp)
                    data.healthBar.Position = Vector2.new(barX, ty + barH * (1 - hp))
                    data.healthBar.Color = Color3.fromRGB(
                        math.floor(255 * (1 - hp)),
                        math.floor(255 * hp),
                        50
                    )
                end
            else
                -- за экраном — скрыть
                for _, obj in pairs(data) do
                    pcall(function() obj.Visible = false end)
                end
            end
        else
            for _, obj in pairs(data) do
                pcall(function() obj.Visible = false end)
            end
        end
    end

    -- визуал мяча
    local ball = findBall()
    if Config.Visuals and ball then
        local bPos, bVis = Camera:WorldToViewportPoint(ball.Position)
        if bVis then
            ballCircle.Visible = true
            ballCircle.Position = Vector2.new(bPos.X, bPos.Y)
            ballText.Visible = true
            ballText.Position = Vector2.new(bPos.X - 18, bPos.Y - 28)

            -- стрелка-индикатор
            ballArrow.Visible = true
            local ax, ay = bPos.X, bPos.Y + 16
            ballArrow.PointA = Vector2.new(ax, ay)
            ballArrow.PointB = Vector2.new(ax - 7, ay + 12)
            ballArrow.PointC = Vector2.new(ax + 7, ay + 12)

            if myRoot then
                local d = math.floor((ball.Position - myRoot.Position).Magnitude)
                ballText.Text = "● BALL  " .. d .. "m"
                ballCircle.Color = d < 30
                    and Config.DangerColor
                    or Config.BallColor
                ballText.Color = ballCircle.Color
                ballArrow.Color = ballCircle.Color
            end
        else
            -- мяч за экраном — стрелка по краю
            ballCircle.Visible = false
            ballText.Visible = false
            if myRoot then
                local dir = (ball.Position - Camera.CFrame.Position)
                local screenDir = Camera.CFrame:VectorToObjectSpace(dir)
                local angle = math.atan2(screenDir.X, -screenDir.Z)
                local cx = Camera.ViewportSize.X / 2
                local cy = Camera.ViewportSize.Y / 2
                local r = math.min(cx, cy) - 40
                local ex = cx + math.sin(angle) * r
                local ey = cy - math.cos(angle) * r
                ballArrow.Visible = true
                ballArrow.PointA = Vector2.new(ex, ey)
                ballArrow.PointB = Vector2.new(ex - 8, ey + 14)
                ballArrow.PointC = Vector2.new(ex + 8, ey + 14)
                ballArrow.Color = Config.BallColor
            else
                ballArrow.Visible = false
            end
        end
    else
        ballCircle.Visible = false
        ballText.Visible = false
        ballArrow.Visible = false
    end
end)

-- ══════════════════════════════════════
--           GUI (МОБИЛЬНЫЙ)
-- ══════════════════════════════════════
local gui
pcall(function()
    -- убираем старый если был
    local old = game.CoreGui:FindFirstChild("BB_Hub")
    if old then old:Destroy() end
end)

pcall(function()
    gui = Instance.new("ScreenGui")
    gui.Name = "BB_Hub"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.Parent = game.CoreGui
end)

if not gui then
    pcall(function()
        gui = Instance.new("ScreenGui")
        gui.Name = "BB_Hub"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 999
        gui.Parent = LocalPlayer.PlayerGui
    end)
end

-- кнопка тогл
local toggleBtn = Instance.new("TextButton", gui)
toggleBtn.Size = UDim2.new(0, 58, 0, 58)
toggleBtn.Position = UDim2.new(0, 12, 0.5, -29)
toggleBtn.BackgroundColor3 = Config.AccentColor
toggleBtn.Text = "⚔"
toggleBtn.TextColor3 = Color3.new(1,1,1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 28
toggleBtn.BorderSizePixel = 0
toggleBtn.ZIndex = 10
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1,0)

-- тень кнопки
local tbShadow = Instance.new("Frame", gui)
tbShadow.Size = UDim2.new(0, 58, 0, 58)
tbShadow.Position = UDim2.new(0, 14, 0.5, -27)
tbShadow.BackgroundColor3 = Color3.fromRGB(0,0,0)
tbShadow.BackgroundTransparency = 0.6
tbShadow.BorderSizePixel = 0
tbShadow.ZIndex = 9
Instance.new("UICorner", tbShadow).CornerRadius = UDim.new(1,0)

-- пульс кнопки
TweenService:Create(toggleBtn, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
    BackgroundColor3 = Color3.fromRGB(80, 20, 180),
}):Play()

-- панель
local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 270, 0, 340)
panel.Position = UDim2.new(0, 82, 0.5, -170)
panel.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 10
local panelCorner = Instance.new("UICorner", panel)
panelCorner.CornerRadius = UDim.new(0, 20)

-- тень панели
local shadow = Instance.new("Frame", gui)
shadow.Size = UDim2.new(0, 278, 0, 348)
shadow.Position = UDim2.new(0, 85, 0.5, -166)
shadow.BackgroundColor3 = Color3.new(0,0,0)
shadow.BackgroundTransparency = 0.55
shadow.BorderSizePixel = 0
shadow.Visible = false
shadow.ZIndex = 9
Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 22)

-- шапка с градиентом
local header = Instance.new("Frame", panel)
header.Size = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = Config.AccentColor
header.BorderSizePixel = 0
header.ZIndex = 11
local hCorner = Instance.new("UICorner", header)
hCorner.CornerRadius = UDim.new(0, 20)
local hGrad = Instance.new("UIGradient", header)
hGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 60, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 140, 255)),
})
hGrad.Rotation = 45

local titleLbl = Instance.new("TextLabel", header)
titleLbl.Size = UDim2.new(1, 0, 1, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "⚔  BLADE BALL"
titleLbl.TextColor3 = Color3.new(1,1,1)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 19
titleLbl.ZIndex = 12

-- разделитель
local sep = Instance.new("Frame", panel)
sep.Size = UDim2.new(0.85, 0, 0, 1)
sep.Position = UDim2.new(0.075, 0, 0, 58)
sep.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
sep.BorderSizePixel = 0
sep.ZIndex = 11

-- тогл-строки
local function makeRow(labelTxt, icon, configKey, yPos)
    local row = Instance.new("Frame", panel)
    row.Size = UDim2.new(1, -24, 0, 48)
    row.Position = UDim2.new(0, 12, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 36)
    row.BorderSizePixel = 0
    row.ZIndex = 11
    local rc = Instance.new("UICorner", row)
    rc.CornerRadius = UDim.new(0, 14)

    local iconLbl = Instance.new("TextLabel", row)
    iconLbl.Size = UDim2.new(0, 36, 1, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon
    iconLbl.TextSize = 20
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.ZIndex = 12

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(0.55, 0, 1, 0)
    nameLbl.Position = UDim2.new(0, 38, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = labelTxt
    nameLbl.TextColor3 = Color3.new(1,1,1)
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextSize = 14
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 12

    local pill = Instance.new("TextButton", row)
    pill.Size = UDim2.new(0, 58, 0, 30)
    pill.Position = UDim2.new(1, -70, 0.5, -15)
    pill.BorderSizePixel = 0
    pill.Font = Enum.Font.GothamBold
    pill.TextSize = 13
    pill.AutoButtonColor = false
    pill.ZIndex = 12
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local function refresh()
        if Config[configKey] then
            pill.Text = "ON"
            pill.BackgroundColor3 = Color3.fromRGB(90, 210, 110)
            pill.TextColor3 = Color3.fromRGB(5, 35, 5)
            TweenService:Create(pill, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(90, 210, 110)
            }):Play()
        else
            pill.Text = "OFF"
            pill.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
            pill.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        end
    end
    refresh()

    pill.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        refresh()
    end)
end

makeRow("Авто-Парри",  "🛡", "AutoParry", 68)
makeRow("ESP Игроков", "👁", "ESP",        124)
makeRow("Визуалы Мяча","✨", "Visuals",    180)

-- статус строка
local statusRow = Instance.new("Frame", panel)
statusRow.Size = UDim2.new(1, -24, 0, 42)
statusRow.Position = UDim2.new(0, 12, 0, 238)
statusRow.BackgroundColor3 = Color3.fromRGB(22, 22, 36)
statusRow.BorderSizePixel = 0
statusRow.ZIndex = 11
Instance.new("UICorner", statusRow).CornerRadius = UDim.new(0, 14)

local statusLbl = Instance.new("TextLabel", statusRow)
statusLbl.Size = UDim2.new(1, -12, 1, 0)
statusLbl.Position = UDim2.new(0, 12, 0, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "🟡 Мяч: поиск..."
statusLbl.TextColor3 = Color3.fromRGB(255, 200, 80)
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 13
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.ZIndex = 12

RunService.Heartbeat:Connect(function()
    local ball = findBall()
    local myRoot = getRoot(LocalPlayer)
    if ball and myRoot then
        local d = math.floor((ball.Position - myRoot.Position).Magnitude)
        statusLbl.Text = (d < 30 and "🔴" or "🟡") .. " Мяч: " .. d .. "m"
        statusLbl.TextColor3 = d < 30
            and Config.DangerColor
            or Color3.fromRGB(255, 200, 80)
    else
        statusLbl.Text = "⚪ Мяч: не найден"
        statusLbl.TextColor3 = Color3.fromRGB(130, 130, 130)
    end
end)

-- кредит
local credit = Instance.new("TextLabel", panel)
credit.Size = UDim2.new(1, 0, 0, 28)
credit.Position = UDim2.new(0, 0, 0, 290)
credit.BackgroundTransparency = 1
credit.Text = "delta executor • by forge"
credit.TextColor3 = Color3.fromRGB(70, 70, 100)
credit.Font = Enum.Font.Gotham
credit.TextSize = 11
credit.ZIndex = 11

-- тогл открытия/закрытия
local isOpen = false
toggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    if isOpen then
        panel.Visible = true
        shadow.Visible = true
        panel.Size = UDim2.new(0, 0, 0, 0)
        panel.Position = UDim2.new(0, 82, 0.5, 0)
        TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 270, 0, 340),
            Position = UDim2.new(0, 82, 0.5, -170),
        }):Play()
        TweenService:Create(shadow, TweenInfo.new(0.22), {
            BackgroundTransparency = 0.55,
        }):Play()
    else
        TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0, 82, 0.5, 0),
        }):Play()
        task.delay(0.19, function()
            panel.Visible = false
            shadow.Visible = false
        end)
    end
end)

-- перетаскивание
local drag = {active = false, start = nil, startPos = nil}
panel.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        drag.active = true
        drag.start = inp.Position
        drag.startPos = panel.Position
    end
end)
panel.InputChanged:Connect(function(inp)
    if drag.active and inp.UserInputType == Enum.UserInputType.Touch then
        local d = inp.Position - drag.start
        panel.Position = UDim2.new(
            drag.startPos.X.Scale, drag.startPos.X.Offset + d.X,
            drag.startPos.Y.Scale, drag.startPos.Y.Offset + d.Y
        )
    end
end)
panel.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch then
        drag.active = false
    end
end)
