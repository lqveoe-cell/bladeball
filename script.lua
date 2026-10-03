-- language: Lua, executor: Delta, target: Roblox Blade Ball (Mobile)
-- автопарри через RemoteEvent перехват + ESP + красивый мобильный GUI с тоглом

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ══════════════════════════════════════
--           НАСТРОЙКИ
-- ══════════════════════════════════════
local Config = {
    AutoParry = true,
    ESP = true,
    ParryDistance = 60,     -- дистанция авто-парри (studs)
    ESPBoxColor = Color3.fromRGB(255, 80, 180),
    ESPNameColor = Color3.fromRGB(255, 255, 255),
    ESPTracerColor = Color3.fromRGB(120, 80, 255),
    BallColor = Color3.fromRGB(255, 200, 0),
    GUIAccent = Color3.fromRGB(180, 80, 255),
}

-- ══════════════════════════════════════
--           АВТО-ПАРРИ
-- ══════════════════════════════════════
local function findBall()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (
            obj.Name:lower():find("ball") or
            obj.Name:lower():find("blade")
        ) then
            return obj
        end
    end
end

local parryRemote
for _, v in ipairs(game:GetDescendants()) do
    if v:IsA("RemoteEvent") and v.Name:lower():find("parry") then
        parryRemote = v
        break
    end
end

local lastParry = 0
RunService.Heartbeat:Connect(function()
    if not Config.AutoParry then return end
    local ball = findBall()
    if not ball then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local dist = (ball.Position - char.HumanoidRootPart.Position).Magnitude
    local now = tick()
    if dist <= Config.ParryDistance and now - lastParry > 0.3 then
        lastParry = now
        if parryRemote then
            parryRemote:FireServer()
        end
        -- fallback: симуляция нажатия если remote не найден
        local args = {ball}
        pcall(function()
            for _, r in ipairs(game:GetDescendants()) do
                if r:IsA("RemoteEvent") then
                    pcall(function() r:FireServer(unpack(args)) end)
                end
            end
        end)
    end
end)

-- ══════════════════════════════════════
--           ESP
-- ══════════════════════════════════════
local ESPFolder = Instance.new("Folder", game.CoreGui)
ESPFolder.Name = "BB_ESP"

local function createESP(player)
    if player == LocalPlayer then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_" .. player.Name
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 120, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Parent = ESPFolder

    local nameLabel = Instance.new("TextLabel", billboard)
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Config.ESPNameColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0,0,0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextScaled = true
    nameLabel.Text = player.Name

    local distLabel = Instance.new("TextLabel", billboard)
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Config.ESPBoxColor
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0,0,0)
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextScaled = true
    distLabel.Text = "0 studs"

    -- трейсер
    local tracer = Drawing.new("Line")
    tracer.Color = Config.ESPTracerColor
    tracer.Thickness = 1.5
    tracer.Transparency = 0.7
    tracer.Visible = false

    RunService.RenderStepped:Connect(function()
        if not Config.ESP then
            billboard.Enabled = false
            tracer.Visible = false
            return
        end
        local char = player.Character
        local myChar = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and myChar and myChar:FindFirstChild("HumanoidRootPart") then
            billboard.Adornee = char.HumanoidRootPart
            billboard.Enabled = true
            local dist = math.floor((char.HumanoidRootPart.Position - myChar.HumanoidRootPart.Position).Magnitude)
            distLabel.Text = dist .. " studs"

            -- трейсер
            local screenPos, onScreen = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
            if onScreen then
                tracer.Visible = true
                tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            else
                tracer.Visible = false
            end
        else
            billboard.Enabled = false
            tracer.Visible = false
        end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(function(p)
    local b = ESPFolder:FindFirstChild("ESP_" .. p.Name)
    if b then b:Destroy() end
end)

-- ══════════════════════════════════════
--           МОБИЛЬНЫЙ GUI
-- ══════════════════════════════════════
local screenGui = Instance.new("ScreenGui", game.CoreGui)
screenGui.Name = "BB_Hub"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

-- кнопка-тогл (всегда видна)
local toggleBtn = Instance.new("TextButton", screenGui)
toggleBtn.Size = UDim2.new(0, 54, 0, 54)
toggleBtn.Position = UDim2.new(0, 16, 0.5, -27)
toggleBtn.BackgroundColor3 = Config.GUIAccent
toggleBtn.Text = "⚔"
toggleBtn.TextColor3 = Color3.new(1,1,1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 26
toggleBtn.BorderSizePixel = 0
toggleBtn.AutoButtonColor = false
local tbCorner = Instance.new("UICorner", toggleBtn)
tbCorner.CornerRadius = UDim.new(1, 0)
-- пульсация кнопки
TweenService:Create(toggleBtn, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
    BackgroundColor3 = Color3.fromRGB(100, 30, 200)
}):Play()

-- основная панель
local panel = Instance.new("Frame", screenGui)
panel.Size = UDim2.new(0, 260, 0, 320)
panel.Position = UDim2.new(0, 80, 0.5, -160)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
panel.BorderSizePixel = 0
panel.Visible = false
local panelCorner = Instance.new("UICorner", panel)
panelCorner.CornerRadius = UDim.new(0, 18)

-- градиентная полоса сверху
local topBar = Instance.new("Frame", panel)
topBar.Size = UDim2.new(1, 0, 0, 44)
topBar.BackgroundColor3 = Config.GUIAccent
topBar.BorderSizePixel = 0
local topCorner = Instance.new("UICorner", topBar)
topCorner.CornerRadius = UDim.new(0, 18)
local topGrad = Instance.new("UIGradient", topBar)
topGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 120, 255))
})
topGrad.Rotation = 90

local titleLabel = Instance.new("TextLabel", topBar)
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚔  BLADE BALL"
titleLabel.TextColor3 = Color3.new(1,1,1)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18

-- функция создания тогл-кнопки
local yOffset = 54
local function makeToggle(labelText, configKey)
    local row = Instance.new("Frame", panel)
    row.Size = UDim2.new(1, -24, 0, 44)
    row.Position = UDim2.new(0, 12, 0, yOffset)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
    row.BorderSizePixel = 0
    local rc = Instance.new("UICorner", row)
    rc.CornerRadius = UDim.new(0, 12)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 52, 0, 28)
    btn.Position = UDim2.new(1, -64, 0.5, -14)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.AutoButtonColor = false

    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(1, 0)

    local function refreshBtn()
        if Config[configKey] then
            btn.Text = "ON"
            btn.BackgroundColor3 = Color3.fromRGB(100, 220, 120)
            btn.TextColor3 = Color3.fromRGB(10, 40, 10)
        else
            btn.Text = "OFF"
            btn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
            btn.TextColor3 = Color3.new(1,1,1)
        end
    end
    refreshBtn()

    btn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        refreshBtn()
    end)

    yOffset = yOffset + 52
end

makeToggle("🛡  Авто-Парри", "AutoParry")
makeToggle("👁  ESP Игроков", "ESP")

-- статус мяча
local ballStatus = Instance.new("TextLabel", panel)
ballStatus.Size = UDim2.new(1, -24, 0, 36)
ballStatus.Position = UDim2.new(0, 12, 0, yOffset + 4)
ballStatus.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
ballStatus.BorderSizePixel = 0
ballStatus.Text = "🟡 Мяч: поиск..."
ballStatus.TextColor3 = Color3.fromRGB(255, 200, 80)
ballStatus.Font = Enum.Font.Gotham
ballStatus.TextSize = 13
local bsc = Instance.new("UICorner", ballStatus)
bsc.CornerRadius = UDim.new(0, 12)

RunService.Heartbeat:Connect(function()
    local ball = findBall()
    local char = LocalPlayer.Character
    if ball and char and char:FindFirstChild("HumanoidRootPart") then
        local d = math.floor((ball.Position - char.HumanoidRootPart.Position).Magnitude)
        ballStatus.Text = "🟡 Мяч: " .. d .. " studs"
        ballStatus.TextColor3 = d < 30
            and Color3.fromRGB(255, 80, 80)
            or Color3.fromRGB(255, 200, 80)
    else
        ballStatus.Text = "🟡 Мяч: не найден"
        ballStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

-- тогл панели
local panelOpen = false
toggleBtn.MouseButton1Click:Connect(function()
    panelOpen = not panelOpen
    panel.Visible = panelOpen
    if panelOpen then
        panel.Size = UDim2.new(0, 0, 0, 0)
        panel.Position = UDim2.new(0, 80, 0.5, 0)
        TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
            Size = UDim2.new(0, 260, 0, 320),
            Position = UDim2.new(0, 80, 0.5, -160)
        }):Play()
    end
end)

-- перетаскивание панели (мобильный)
local dragging, dragStart, startPos
panel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = panel.Position
    end
end)
panel.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)
panel.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
