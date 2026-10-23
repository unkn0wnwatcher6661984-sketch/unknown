local P = game:GetService("Players")
local W = game:GetService("Workspace")
local U = game:GetService("UserInputService")
local R = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local pl = P.LocalPlayer
if not pl then return end

local pg = pl:WaitForChild("PlayerGui")
local m = pl:GetMouse()
local c = pl.Character or pl.CharacterAdded:Wait()
local cam = W.CurrentCamera

local TP_INSTANCE_ID = HttpService:GenerateGUID(false)
local TP_INSTANCE_PASSWORD = string.format("%08d", math.random(0, 99999999))

local bk = {
    curPage = 1,
    ok = false,
    pl_rad = false,
    sf_act = false,
    cnt = 0,
    safe_hp = 0.30,
    safe_pos = nil,
    mapPoints = {},
    playerPoints = {}
}

local connections = {}
local guiClosed = false
local buildGui

local function connect(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(connections, connection)
    return connection
end

local function disconnectOwnConnections()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)
end

local W_T, CD, SF_CD, PL_CD = 2, 4, 7, 5
local t1, t2, t3, t_sf, t_pl = 0, 0, 0, 0, 0
local HRP = "HumanoidRootPart"

local specActive, specIndex = false, 0
local specCamBtn, specExitBtn, specConnection
local specYaw, specPitch, specDistance = 0, -0.65, 18
local rotating, lastPointer, inConfigMode = false, nil, false

local sg, MF, cfgBtn, minBtn, closeBtn
local scroll1, scroll2, scroll3
local layout1, layout2, layout3
local createBtn, radarBtn, refreshBtn, safeBtn
local navLeft, navLabel, navRight
local zone
local configFrame, cfgLabel, hpInput, hpSaveBtn, cfgBackBtn
local xInput, yInput, zInput
local safe_data
local frameOpen = true

-- PALETA DO NOVO DESIGN
local THEME = {
    background = Color3.fromRGB(18, 20, 29),
    panel = Color3.fromRGB(25, 28, 40),
    header = Color3.fromRGB(15, 17, 25),
    text = Color3.fromRGB(245, 247, 255),
    muted = Color3.fromRGB(155, 165, 185),
    border = Color3.fromRGB(57, 64, 84),
    red = Color3.fromRGB(235, 75, 85),
    blue = Color3.fromRGB(65, 145, 255),
    green = Color3.fromRGB(45, 195, 130),
    button = Color3.fromRGB(39, 44, 61),
    input = Color3.fromRGB(31, 35, 49)
}

local function roundify(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = object
    return corner
end

local function outline(object, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or THEME.border
    stroke.Thickness = thickness or 1
    stroke.Transparency = 0.15
    stroke.Parent = object
    return stroke
end

local function styleButton(button, color)
    button.AutoButtonColor = true
    button.BorderSizePixel = 0
    button.BackgroundColor3 = color or THEME.button
    button.TextColor3 = THEME.text
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    roundify(button, 7)
end

local function snd(id, speed)
    if guiClosed then return end

    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. id
    s.Volume = 1
    s.PlaybackSpeed = speed or 1
    s.Parent = W.CurrentCamera or W

    connect(s.Ended, function()
        s:Destroy()
    end)

    s:Play()
end

local function tp(pos, isPl, tPl)
    if guiClosed then return end

    c = pl.Character
    if not c or not c:FindFirstChild(HRP) then return end

    local dest = pos

    if isPl and tPl and tPl.Character then
        local targetRoot = tPl.Character:FindFirstChild(HRP)
        if targetRoot then
            dest = targetRoot.Position - targetRoot.CFrame.LookVector * 3
            c:PivotTo(CFrame.new(dest, targetRoot.Position))
            snd(9120705982, 1.5)
            return
        end
    end

    if typeof(dest) ~= "Vector3" then return end

    snd(9120705982, 1.5)
    c:PivotTo(CFrame.new(dest + Vector3.new(0, 3, 0)))
end

local function endSpectate()
    specActive, rotating, lastPointer = false, false, nil

    if specConnection then
        specConnection:Disconnect()
        specConnection = nil
    end

    cam = W.CurrentCamera

    if cam then
        cam.CameraType = Enum.CameraType.Custom

        local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            cam.CameraSubject = hum
        end
    end

    if specCamBtn then
        specCamBtn:Destroy()
        specCamBtn = nil
    end

    if specExitBtn then
        specExitBtn:Destroy()
        specExitBtn = nil
    end
end

local function updateSpecCamera()
    if not specActive or guiClosed then return end

    local item = bk.mapPoints[specIndex]

    if not item or not item.Ancor or not item.Ancor.Parent then
        endSpectate()
        return
    end

    cam = W.CurrentCamera
    if not cam then return end

    cam.CameraType = Enum.CameraType.Scriptable

    local targetPos = item.Ancor.Position - Vector3.new(0, 10, 0)
    local cp = math.clamp(specPitch, -1.35, 1.1)

    local direction = Vector3.new(
        math.cos(cp) * math.sin(specYaw),
        math.sin(cp),
        math.cos(cp) * math.cos(specYaw)
    )

    cam.CFrame = CFrame.lookAt(
        targetPos - direction * specDistance,
        targetPos
    )
end

local function jumpSpectate(offset)
    if #bk.mapPoints == 0 then return end

    specIndex += offset

    if specIndex > #bk.mapPoints then
        specIndex = 1
    elseif specIndex < 1 then
        specIndex = #bk.mapPoints
    end

    updateSpecCamera()
end

local function startSpectate(_, idx)
    if guiClosed or not sg then return end

    endSpectate()

    if #bk.mapPoints == 0 then return end

    specActive = true
    specIndex = idx or 1
    specYaw, specPitch = 0, -0.35

    specCamBtn = Instance.new("TextButton")
    specCamBtn.Name = "TP_SpecCam_" .. TP_INSTANCE_ID
    specCamBtn:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
    specCamBtn.Size = UDim2.new(0, 140, 0, 40)
    specCamBtn.Position = UDim2.new(0.5, -75, 0.82, 0)
    specCamBtn.Text = "Ir ao ponto"
    specCamBtn.Parent = sg
    styleButton(specCamBtn, THEME.green)

    specExitBtn = Instance.new("TextButton")
    specExitBtn.Name = "TP_SpecExit_" .. TP_INSTANCE_ID
    specExitBtn:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
    specExitBtn.Size = UDim2.new(0, 40, 0, 40)
    specExitBtn.Position = UDim2.new(0.5, 70, 0.82, 0)
    specExitBtn.Text = "X"
    specExitBtn.Parent = sg
    styleButton(specExitBtn, THEME.red)

    connect(specCamBtn.MouseButton1Click, function()
        if guiClosed then return end

        local item = bk.mapPoints[specIndex]
        if item then
            tp(item.Pos, false, nil)
        end

        endSpectate()
    end)

    connect(specExitBtn.MouseButton1Click, endSpectate)

    specConnection = R.RenderStepped:Connect(updateSpecCamera)
    table.insert(connections, specConnection)

    updateSpecCamera()
end

connect(U.InputBegan, function(input, processed)
    if processed or not specActive or guiClosed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.Touch then
        rotating, lastPointer = true, input.Position
    end
end)

connect(U.InputChanged, function(input)
    if not specActive or not rotating or not lastPointer or guiClosed then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then

        local delta = input.Position - lastPointer
        lastPointer = input.Position

        specYaw -= delta.X * 0.008
        specPitch = math.clamp(
            specPitch + delta.Y * 0.008,
            -1.35,
            1.1
        )
    end
end)

connect(U.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.Touch then
        rotating, lastPointer = false, nil
    end
end)

local function makeLabel3D(pos, txt, isPl)
    local part = Instance.new("Part")
    part.Name = "TP_TextAncor_" .. TP_INSTANCE_ID
    part:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
    part:SetAttribute("TP_InstanceId", TP_INSTANCE_ID)
    part.Size = Vector3.new(1, 1, 1)
    part.Transparency = 1
    part.CanCollide = false
    part.Anchored = true
    part.Position = pos + Vector3.new(0, 10, 0)
    part.Parent = W

    local gui = Instance.new("BillboardGui")
    gui.Name = "TP_Billboard_" .. TP_INSTANCE_ID
    gui.Size = UDim2.new(0, 110, 0, 36)
    gui.AlwaysOnTop = true
    gui.Adornee = part
    gui.Parent = part

    local btn = Instance.new("TextButton")
    btn.Name = "TP_LabelButton_" .. TP_INSTANCE_ID
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundColor3 = THEME.header
    btn.BackgroundTransparency = 0.1
    btn.BorderSizePixel = 0
    btn.Text = txt
    btn.TextColor3 = isPl and THEME.blue or THEME.red
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = gui

    roundify(btn, 7)
    return part, btn
end

local function rebuildLists()
    if guiClosed or not scroll1 or not scroll2 or not scroll3 then
        return
    end

    local function clearRows(scroll)
        for _, child in ipairs(scroll:GetChildren()) do
            if not child:IsA("UIListLayout")
                and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
    end

    clearRows(scroll1)
    clearRows(scroll2)
    clearRows(scroll3)

    for i, item in ipairs(bk.mapPoints) do
        local bMap = Instance.new("TextButton")
        bMap.Name = "TPPoint_" .. TP_INSTANCE_ID .. "_" .. tostring(item.Idx)
        bMap.Size = UDim2.new(1, -6, 0, 34)
        bMap.Text = "   ◆   tppoint " .. tostring(item.Idx)
        bMap.TextXAlignment = Enum.TextXAlignment.Left
        bMap.Parent = scroll1
        styleButton(bMap, Color3.fromRGB(45, 38, 49))

        connect(bMap.MouseButton1Click, function()
            if not guiClosed then
                tp(item.Pos, false, nil)
            end
        end)

        local bSpec = Instance.new("TextButton")
        bSpec.Name = "SpecPoint_" .. TP_INSTANCE_ID .. "_" .. tostring(item.Idx)
        bSpec.Size = UDim2.new(1, -6, 0, 34)
        bSpec.Text = "   ◉   Spec Point " .. tostring(item.Idx)
        bSpec.TextXAlignment = Enum.TextXAlignment.Left
        bSpec.Parent = scroll3
        styleButton(bSpec, Color3.fromRGB(34, 45, 62))

        connect(bSpec.MouseButton1Click, function()
            if not guiClosed then
                startSpectate(item.Pos, i)
            end
        end)
    end

    for _, item in ipairs(bk.playerPoints) do
        local bPl = Instance.new("TextButton")
        bPl.Name = "Player_" .. TP_INSTANCE_ID .. "_" .. tostring(item.PlName)
        bPl.Size = UDim2.new(1, -6, 0, 34)
        bPl.Text = "   ●   " .. tostring(item.PlName)
        bPl.TextXAlignment = Enum.TextXAlignment.Left
        bPl.Parent = scroll2
        styleButton(bPl, Color3.fromRGB(30, 45, 65))
        bPl.TextColor3 = Color3.fromRGB(130, 195, 255)

        connect(bPl.MouseButton1Click, function()
            if guiClosed then return end

            local target = P:FindFirstChild(item.PlName)

            if target and target.Character
                and target.Character:FindFirstChild(HRP) then
                tp(target.Character[HRP].Position, true, target)
            elseif item.Pos then
                tp(item.Pos, false, nil)
            end
        end)
    end
end

local function addListButton(pos, isPl, targetPlayer, index)
    if guiClosed or not pos then return end

    local name = isPl and targetPlayer.Name or ("tppoint " .. tostring(index))
    local anchor, labelButton = makeLabel3D(pos, name, isPl)

    connect(labelButton.MouseButton1Click, function()
        if guiClosed then return end

        local now = tick()

        if now - t2 <= W_T and t2 ~= 0 then
            tp(anchor.Position - Vector3.new(0, 10, 0), isPl, targetPlayer)
            t2 = 0
        else
            t2 = now
        end
    end)

    if isPl then
        table.insert(bk.playerPoints, {
            Pos = pos,
            PlName = targetPlayer.Name,
            PlayerObj = targetPlayer,
            Ancor = anchor
        })
    else
        table.insert(bk.mapPoints, {
            Pos = pos,
            Idx = index,
            Ancor = anchor
        })
    end

    rebuildLists()
end

local function updatePage()
    if not MF or guiClosed then return end

    scroll1.Visible = bk.curPage == 1 and not inConfigMode
    scroll2.Visible = bk.curPage == 2 and not inConfigMode
    scroll3.Visible = bk.curPage == 3 and not inConfigMode
    navLeft.Visible = bk.curPage > 1 and not inConfigMode
    navRight.Visible = bk.curPage < 3 and not inConfigMode

    if bk.curPage == 1 then
        MF.BackgroundColor3 = THEME.background
        navLabel.Text = "MAPA"
        navLabel.TextColor3 = THEME.red
        createBtn.BackgroundColor3 = THEME.red
    elseif bk.curPage == 2 then
        MF.BackgroundColor3 = THEME.background
        navLabel.Text = "PLAYERS"
        navLabel.TextColor3 = THEME.blue
        createBtn.BackgroundColor3 = THEME.blue
    else
        MF.BackgroundColor3 = THEME.background
        navLabel.Text = "SPECTATE"
        navLabel.TextColor3 = THEME.green
        createBtn.BackgroundColor3 = THEME.green
    end
end

local function toggleConfigMode(state)
    if guiClosed then return end

    inConfigMode = state
    configFrame.Visible = state

    if state then
        local pos = (safe_data and safe_data.TargetPos) or bk.safe_pos

        if not pos then
            c = pl.Character
            local root = c and c:FindFirstChild(HRP)
            pos = root and root.Position or Vector3.zero
        end

        hpInput.Text = tostring(math.floor(bk.safe_hp * 100 + 0.5))
        xInput.Text = tostring(math.floor(pos.X * 100) / 100)
        yInput.Text = tostring(math.floor(pos.Y * 100) / 100)
        zInput.Text = tostring(math.floor(pos.Z * 100) / 100)
    end

    scroll1.Visible = not state and bk.curPage == 1
    scroll2.Visible = not state and bk.curPage == 2
    scroll3.Visible = not state and bk.curPage == 3

    createBtn.Visible = not state
    radarBtn.Visible = not state
    refreshBtn.Visible = not state
    safeBtn.Visible = not state
    navLeft.Visible = not state and bk.curPage > 1
    navRight.Visible = not state and bk.curPage < 3
    navLabel.Visible = not state
    cfgBtn.Visible = not state
end

local function closeThisInstance()
    if guiClosed then return end

    guiClosed = true
    endSpectate()

    for _, item in ipairs(bk.mapPoints) do
        if item.Ancor then item.Ancor:Destroy() end
    end

    for _, item in ipairs(bk.playerPoints) do
        if item.Ancor then item.Ancor:Destroy() end
    end

    if safe_data then
        if safe_data.Cube then safe_data.Cube:Destroy() end
        if safe_data.Ancor then safe_data.Ancor:Destroy() end
        safe_data = nil
    end

    if zone then
        zone:Destroy()
        zone = nil
    end

    bk.mapPoints = {}
    bk.playerPoints = {}

    disconnectOwnConnections()

    if sg then
        sg:Destroy()
        sg = nil
    end
end

buildGui = function()
    if guiClosed then return end

    sg = Instance.new("ScreenGui")
    sg.Name = "TP_Tabs_Gui_" .. TP_INSTANCE_ID
    sg:SetAttribute("TP_InstanceId", TP_INSTANCE_ID)
    sg:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
    sg.ResetOnSpawn = false
    sg.Parent = pg

    MF = Instance.new("Frame")
    MF.Name = "MainFrame_" .. TP_INSTANCE_ID
    MF.Size = UDim2.new(0, 320, 0, 390)
    MF.Position = UDim2.new(0.5, -160, 0.5, -195)
    MF.BackgroundColor3 = THEME.background
    MF.BorderSizePixel = 0
    MF.Active = true
    MF.Parent = sg

    roundify(MF, 14)
    outline(MF, THEME.border, 1.5)

    -- Cabeçalho
    local header = Instance.new("Frame")
    header.Name = "Header_" .. TP_INSTANCE_ID
    header.Size = UDim2.new(1, 0, 0, 58)
    header.BackgroundColor3 = THEME.header
    header.BorderSizePixel = 0
    header.Parent = MF
    roundify(header, 14)

    local headerCover = Instance.new("Frame")
    headerCover.Size = UDim2.new(1, 0, 0, 14)
    headerCover.Position = UDim2.new(0, 0, 1, -14)
    headerCover.BackgroundColor3 = THEME.header
    headerCover.BorderSizePixel = 0
    headerCover.Parent = header

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title_" .. TP_INSTANCE_ID
    titleLabel.Size = UDim2.new(1, -145, 0, 27)
    titleLabel.Position = UDim2.new(0, 16, 0, 7)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "tppointsGUIV2"
    titleLabel.TextColor3 = THEME.text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 17
    titleLabel.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -145, 0, 16)
    subtitle.Position = UDim2.new(0, 17, 0, 32)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "TELEPORT  /  CONTROL PANEL"
    subtitle.TextColor3 = THEME.muted
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 8
    subtitle.Parent = header

    local accentLine = Instance.new("Frame")
    accentLine.Name = "AccentLine_" .. TP_INSTANCE_ID
    accentLine.Size = UDim2.new(1, -24, 0, 2)
    accentLine.Position = UDim2.new(0, 12, 0, 57)
    accentLine.BackgroundColor3 = THEME.red
    accentLine.BorderSizePixel = 0
    accentLine.Parent = MF
    roundify(accentLine, 2)

    cfgBtn = Instance.new("TextButton")
    cfgBtn.Name = "ConfigButton_" .. TP_INSTANCE_ID
    cfgBtn.Size = UDim2.new(0, 77, 0, 29)
    cfgBtn.Position = UDim2.new(1, -151, 0, 14)
    cfgBtn.Text = "⚙  Config"
    cfgBtn.Parent = header
    styleButton(cfgBtn, THEME.button)
    cfgBtn.TextSize = 10

    minBtn = Instance.new("TextButton")
    minBtn.Name = "MinimizeButton_" .. TP_INSTANCE_ID
    minBtn.Size = UDim2.new(0, 29, 0, 29)
    minBtn.Position = UDim2.new(1, -67, 0, 14)
    minBtn.Text = "−"
    minBtn.Parent = header
    styleButton(minBtn, THEME.button)
    minBtn.TextSize = 16

    closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton_" .. TP_INSTANCE_ID
    closeBtn.Size = UDim2.new(0, 29, 0, 29)
    closeBtn.Position = UDim2.new(1, -33, 0, 14)
    closeBtn.Text = "×"
    closeBtn.Parent = header
    styleButton(closeBtn, THEME.red)
    closeBtn.TextSize = 17

    local function makeScroll(name)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = name .. "_" .. TP_INSTANCE_ID
        scroll.Size = UDim2.new(1, -24, 0, 150)
        scroll.Position = UDim2.new(0, 12, 0, 145)
        scroll.BackgroundColor3 = THEME.panel
        scroll.BackgroundTransparency = 0
        scroll.BorderSizePixel = 0
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = THEME.muted
        scroll.Parent = MF

        roundify(scroll, 9)
        outline(scroll, THEME.border, 1)

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 7)
        padding.PaddingBottom = UDim.new(0, 7)
        padding.PaddingLeft = UDim.new(0, 6)
        padding.PaddingRight = UDim.new(0, 6)
        padding.Parent = scroll

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = scroll

        return scroll, layout
    end

    -- Botões principais
    createBtn = Instance.new("TextButton")
    createBtn.Name = "CreatePointButton_" .. TP_INSTANCE_ID
    createBtn.Size = UDim2.new(0.5, -18, 0, 34)
    createBtn.Position = UDim2.new(0, 12, 0, 72)
    createBtn.Text = "＋  Criar ponto"
    createBtn.Parent = MF
    styleButton(createBtn, THEME.red)

    radarBtn = Instance.new("TextButton")
    radarBtn.Name = "RadarButton_" .. TP_INSTANCE_ID
    radarBtn.Size = UDim2.new(0.5, -18, 0, 34)
    radarBtn.Position = UDim2.new(0.5, 6, 0, 72)
    radarBtn.Text = "◎  Radar players"
    radarBtn.Parent = MF
    styleButton(radarBtn, THEME.button)

    -- Identificação da seção
    local sectionCaption = Instance.new("TextLabel")
    sectionCaption.Size = UDim2.new(1, -24, 0, 18)
    sectionCaption.Position = UDim2.new(0, 13, 0, 115)
    sectionCaption.BackgroundTransparency = 1
    sectionCaption.Text = "PONTOS SALVOS"
    sectionCaption.TextColor3 = THEME.muted
    sectionCaption.TextXAlignment = Enum.TextXAlignment.Left
    sectionCaption.Font = Enum.Font.GothamBold
    sectionCaption.TextSize = 9
    sectionCaption.Parent = MF

    scroll1, layout1 = makeScroll("MapPoints")
    scroll2, layout2 = makeScroll("PlayerPoints")
    scroll3, layout3 = makeScroll("SpectatePoints")

    scroll2.Visible = false
    scroll3.Visible = false

    refreshBtn = Instance.new("TextButton")
    refreshBtn.Name = "RefreshButton_" .. TP_INSTANCE_ID
    refreshBtn.Size = UDim2.new(0.5, -18, 0, 34)
    refreshBtn.Position = UDim2.new(0, 12, 0, 307)
    refreshBtn.Text = "↻  Limpar tudo"
    refreshBtn.Parent = MF
    styleButton(refreshBtn, THEME.button)
    refreshBtn.TextColor3 = Color3.fromRGB(255, 190, 90)

    safeBtn = Instance.new("TextButton")
    safeBtn.Name = "SafeButton_" .. TP_INSTANCE_ID
    safeBtn.Size = UDim2.new(0.5, -18, 0, 34)
    safeBtn.Position = UDim2.new(0.5, 6, 0, 307)
    safeBtn.Text = "◇  Safe Orb"
    safeBtn.Parent = MF
    styleButton(safeBtn, THEME.button)
    safeBtn.TextColor3 = Color3.fromRGB(150, 175, 255)

    -- Navegação
    navLeft = Instance.new("TextButton")
    navLeft.Name = "NavLeft_" .. TP_INSTANCE_ID
    navLeft.Size = UDim2.new(0, 35, 0, 30)
    navLeft.Position = UDim2.new(0, 12, 0, 350)
    navLeft.Text = "‹"
    navLeft.Parent = MF
    styleButton(navLeft, THEME.button)
    navLeft.TextSize = 19

    navLabel = Instance.new("TextLabel")
    navLabel.Name = "NavLabel_" .. TP_INSTANCE_ID
    navLabel.Size = UDim2.new(1, -106, 0, 30)
    navLabel.Position = UDim2.new(0, 53, 0, 350)
    navLabel.BackgroundTransparency = 1
    navLabel.TextColor3 = THEME.text
    navLabel.Font = Enum.Font.GothamBold
    navLabel.TextSize = 11
    navLabel.Parent = MF

    navRight = Instance.new("TextButton")
    navRight.Name = "NavRight_" .. TP_INSTANCE_ID
    navRight.Size = UDim2.new(0, 35, 0, 30)
    navRight.Position = UDim2.new(1, -47, 0, 350)
    navRight.Text = "›"
    navRight.Parent = MF
    styleButton(navRight, THEME.button)
    navRight.TextSize = 19

    -- Configuração
    configFrame = Instance.new("Frame")
    configFrame.Name = "ConfigFrame_" .. TP_INSTANCE_ID
    configFrame.Size = UDim2.new(1, -24, 0, 190)
    configFrame.Position = UDim2.new(0, 12, 0, 112)
    configFrame.BackgroundColor3 = THEME.panel
    configFrame.BorderSizePixel = 0
    configFrame.Visible = false
    configFrame.Parent = MF
    roundify(configFrame, 9)
    outline(configFrame, THEME.border, 1)

    cfgLabel = Instance.new("TextLabel")
    cfgLabel.Name = "ConfigLabel_" .. TP_INSTANCE_ID
    cfgLabel.Size = UDim2.new(1, -20, 0, 22)
    cfgLabel.Position = UDim2.new(0, 10, 0, 8)
    cfgLabel.BackgroundTransparency = 1
    cfgLabel.Text = "HP DE RESGATE (%)"
    cfgLabel.TextColor3 = THEME.text
    cfgLabel.Font = Enum.Font.GothamBold
    cfgLabel.TextSize = 11
    cfgLabel.TextXAlignment = Enum.TextXAlignment.Left
    cfgLabel.Parent = configFrame

    hpInput = Instance.new("TextBox")
    hpInput.Name = "HPInput_" .. TP_INSTANCE_ID
    hpInput.Size = UDim2.new(1, -20, 0, 29)
    hpInput.Position = UDim2.new(0, 10, 0, 32)
    hpInput.BackgroundColor3 = THEME.input
    hpInput.Text = tostring(math.floor(bk.safe_hp * 100 + 0.5))
    hpInput.PlaceholderText = "Ex.: 30"
    hpInput.TextColor3 = THEME.text
    hpInput.Font = Enum.Font.Gotham
    hpInput.TextSize = 12
    hpInput.ClearTextOnFocus = false
    hpInput.Parent = configFrame
    roundify(hpInput, 6)

    local coordLabel = Instance.new("TextLabel")
    coordLabel.Name = "CoordLabel_" .. TP_INSTANCE_ID
    coordLabel.Size = UDim2.new(1, -20, 0, 22)
    coordLabel.Position = UDim2.new(0, 10, 0, 68)
    coordLabel.BackgroundTransparency = 1
    coordLabel.Text = "DESTINO DO TELEPORTE (X / Y / Z)"
    coordLabel.TextColor3 = THEME.text
    coordLabel.Font = Enum.Font.GothamBold
    coordLabel.TextSize = 9
    coordLabel.TextXAlignment = Enum.TextXAlignment.Left
    coordLabel.Parent = configFrame

    local function makeCoordInput(name, x, placeholder)
        local box = Instance.new("TextBox")
        box.Name = name .. "_" .. TP_INSTANCE_ID
        box.Size = UDim2.new(0.333, -11, 0, 29)
        box.Position = UDim2.new(0, x, 0, 92)
        box.BackgroundColor3 = THEME.input
        box.TextColor3 = THEME.text
        box.PlaceholderText = placeholder
        box.Text = ""
        box.Font = Enum.Font.Gotham
        box.TextSize = 11
        box.ClearTextOnFocus = false
        box.Parent = configFrame
        roundify(box, 6)
        return box
    end

    xInput = makeCoordInput("SafeX", 10, "X")
    yInput = makeCoordInput("SafeY", 101, "Y")
    zInput = makeCoordInput("SafeZ", 192, "Z")

    hpSaveBtn = Instance.new("TextButton")
    hpSaveBtn.Name = "HPSaveButton_" .. TP_INSTANCE_ID
    hpSaveBtn.Size = UDim2.new(0.5, -15, 0, 30)
    hpSaveBtn.Position = UDim2.new(0, 10, 0, 137)
    hpSaveBtn.Text = "Salvar"
    hpSaveBtn.Parent = configFrame
    styleButton(hpSaveBtn, THEME.green)

    cfgBackBtn = Instance.new("TextButton")
    cfgBackBtn.Name = "ConfigBackButton_" .. TP_INSTANCE_ID
    cfgBackBtn.Size = UDim2.new(0.5, -15, 0, 30)
    cfgBackBtn.Position = UDim2.new(0.5, 5, 0, 137)
    cfgBackBtn.Text = "Voltar"
    cfgBackBtn.Parent = configFrame
    styleButton(cfgBackBtn, THEME.red)

    local function dragFrame(frame)
        local dragging = false
        local startPos, framePos

        connect(header.InputBegan, function(input)
            if guiClosed then return end

            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then

                dragging, startPos, framePos = true, input.Position, frame.Position

                connect(input.Changed, function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        connect(U.InputChanged, function(input)
            if not dragging or guiClosed then return end

            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end

            local delta = input.Position - startPos

            frame.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end)
    end

    dragFrame(MF)

    connect(cfgBtn.MouseButton1Click, function()
        toggleConfigMode(true)
    end)

    connect(cfgBackBtn.MouseButton1Click, function()
        toggleConfigMode(false)
    end)

    connect(hpSaveBtn.MouseButton1Click, function()
        if guiClosed then return end

        local hpValue = tonumber(hpInput.Text)
        local x, y, z = tonumber(xInput.Text), tonumber(yInput.Text), tonumber(zInput.Text)

        if not hpValue or not x or not y or not z then
            cfgLabel.Text = "Preencha HP e X / Y / Z!"
            cfgLabel.TextColor3 = THEME.red
            return
        end

        bk.safe_hp = math.clamp(hpValue / 100, 0.01, 0.99)

        local newPos = Vector3.new(x, y, z)
        bk.safe_pos = newPos

        if safe_data then
            safe_data.TargetPos = newPos

            if safe_data.Cube and safe_data.Cube.Parent then
                safe_data.Cube.Position = newPos + Vector3.new(0, 25, 0)
            end

            if safe_data.Ancor and safe_data.Ancor.Parent then
                safe_data.Ancor.Position = newPos + Vector3.new(0, 35, 0)
            end
        end

        cfgLabel.Text = "HP DE RESGATE (%)"
        cfgLabel.TextColor3 = THEME.text
        toggleConfigMode(false)
    end)

    connect(navLeft.MouseButton1Click, function()
        if guiClosed then return end

        if specActive then
            jumpSpectate(-1)
        elseif bk.curPage > 1 then
            bk.curPage -= 1
            updatePage()
        end
    end)

    connect(navRight.MouseButton1Click, function()
        if guiClosed then return end

        if specActive then
            jumpSpectate(1)
        elseif bk.curPage < 3 then
            bk.curPage += 1
            updatePage()
        end
    end)

    connect(createBtn.MouseButton1Click, function()
        if guiClosed then return end

        bk.ok = not bk.ok
        createBtn.Text = bk.ok and "✓  Criar ponto: ON" or "＋  Criar ponto"
        createBtn.BackgroundColor3 = bk.ok and THEME.green
            or (bk.curPage == 1 and THEME.red
            or bk.curPage == 2 and THEME.blue or THEME.green)
    end)

    connect(radarBtn.MouseButton1Click, function()
        if guiClosed then return end

        bk.pl_rad = not bk.pl_rad
        radarBtn.BackgroundColor3 = bk.pl_rad and THEME.blue or THEME.button

        if bk.pl_rad then
            if not zone then
                zone = Instance.new("Part")
                zone.Name = "set_tppoint_inplayer_" .. TP_INSTANCE_ID
                zone:SetAttribute("TP_InstanceId", TP_INSTANCE_ID)
                zone:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
                zone.Size = Vector3.new(50, 0.2, 50)
                zone.Material = Enum.Material.Neon
                zone.Color = THEME.blue
                zone.Transparency = 0.8
                zone.CanCollide = false
                zone.Anchored = true
                zone.Parent = W
            end
        elseif zone then
            zone:Destroy()
            zone = nil
        end
    end)

    connect(safeBtn.MouseButton1Click, function()
        if guiClosed then return end

        c = pl.Character
        local root = c and c:FindFirstChild(HRP)
        if not root then return end

        if safe_data then
            if safe_data.Cube then safe_data.Cube:Destroy() end
            if safe_data.Ancor then safe_data.Ancor:Destroy() end
            safe_data = nil
        end

        local safePos = root.Position
        bk.safe_pos, bk.sf_act = safePos, true
        snd(1841353894, 1)

        local cube = Instance.new("Part")
        cube.Name = "TP_safetppoint_" .. TP_INSTANCE_ID
        cube:SetAttribute("TP_InstanceId", TP_INSTANCE_ID)
        cube:SetAttribute("TP_InstancePassword", TP_INSTANCE_PASSWORD)
        cube.Size = Vector3.new(4, 4, 4)
        cube.Position = safePos + Vector3.new(0, 25, 0)
        cube.Material = Enum.Material.Neon
        cube.Color = Color3.new(0, 0, 0)
        cube.Anchored = true
        cube.CanCollide = false
        cube.Parent = W

        local anchor, label = makeLabel3D(cube.Position, "SAFE_POINT", false)
        label.TextColor3 = THEME.green

        safe_data = {
            Cube = cube,
            Ancor = anchor,
            TargetPos = safePos
        }

        connect(label.MouseButton1Click, function()
            if guiClosed then return end

            local now = tick()

            if now - t2 <= W_T and t2 ~= 0 then
                local targetPos = safe_data and safe_data.TargetPos
                if targetPos then tp(targetPos, false, nil) end
                t2 = 0
            else
                t2 = now
            end
        end)
    end)

    connect(refreshBtn.MouseButton1Click, function()
        if guiClosed then return end

        for _, item in ipairs(bk.mapPoints) do
            if item.Ancor then item.Ancor:Destroy() end
        end

        for _, item in ipairs(bk.playerPoints) do
            if item.Ancor then item.Ancor:Destroy() end
        end

        if safe_data then
            if safe_data.Cube then safe_data.Cube:Destroy() end
            if safe_data.Ancor then safe_data.Ancor:Destroy() end
        end

        if zone then
            zone:Destroy()
            zone = nil
        end

        bk.mapPoints = {}
        bk.playerPoints = {}
        bk.cnt = 0
        bk.sf_act = false
        bk.safe_pos = nil
        bk.pl_rad = false
        safe_data = nil

        radarBtn.BackgroundColor3 = THEME.button
        endSpectate()
        rebuildLists()
    end)

    local function setUiActive(value)
        cfgBtn.Visible = value
        closeBtn.Visible = true

        createBtn.Visible = value and not inConfigMode
        radarBtn.Visible = value and not inConfigMode
        refreshBtn.Visible = value and not inConfigMode
        safeBtn.Visible = value and not inConfigMode

        navLabel.Visible = value and not inConfigMode
        navLeft.Visible = value and bk.curPage > 1 and not inConfigMode
        navRight.Visible = value and bk.curPage < 3 and not inConfigMode

        configFrame.Visible = value and inConfigMode

        scroll1.Visible = value and bk.curPage == 1 and not inConfigMode
        scroll2.Visible = value and bk.curPage == 2 and not inConfigMode
        scroll3.Visible = value and bk.curPage == 3 and not inConfigMode

        hpInput.Active = value and inConfigMode
        xInput.Active = value and inConfigMode
        yInput.Active = value and inConfigMode
        zInput.Active = value and inConfigMode

        hpSaveBtn.Active = value and inConfigMode
        cfgBackBtn.Active = value and inConfigMode
    end

    connect(minBtn.MouseButton1Click, function()
        if guiClosed then return end

        frameOpen = not frameOpen
        minBtn.Text = frameOpen and "−" or "+"

        if frameOpen then
            MF.Size = UDim2.new(0, 320, 0, 390)
            setUiActive(true)
            updatePage()
        else
            setUiActive(false)
            MF.Size = UDim2.new(0, 320, 0, 58)
        end
    end)

    connect(closeBtn.MouseButton1Click, function()
        closeThisInstance()
    end)

    updatePage()
    rebuildLists()
end

connect(m.Button1Down, function()
    if guiClosed or not bk.ok then return end

    local now = tick()
    if now - t3 < CD then return end

    if t1 == 0 or now - t1 > W_T then
        t1 = now
        return
    end

    t1, t3 = 0, now

    local hit = m.Hit
    if not hit then return end

    bk.cnt = #bk.mapPoints + 1
    addListButton(hit.Position, false, nil, bk.cnt)
end)

connect(R.Heartbeat, function()
    if guiClosed then return end

    c = pl.Character

    local root = c and c:FindFirstChild(HRP)
    local hum = c and c:FindFirstChildOfClass("Humanoid")

    if not root or not hum then return end

    if safe_data and safe_data.TargetPos
        and hum.Health > 0 and hum.MaxHealth > 0 then

        local now = tick()

        if hum.Health / hum.MaxHealth <= bk.safe_hp
            and now - t_sf >= SF_CD then

            t_sf = now
            tp(safe_data.TargetPos, false, nil)
        end
    end

    if bk.pl_rad then
        if zone then
            zone.Position = root.Position + Vector3.new(0, -3, 0)
        end

        local now = tick()

        if now - t_pl >= PL_CD then
            t_pl = now

            for _, other in ipairs(P:GetPlayers()) do
                if other ~= pl and other.Character
                    and other.Character:FindFirstChild(HRP) then

                    local otherRoot = other.Character[HRP]

                    if (root.Position - otherRoot.Position).Magnitude <= 25 then
                        local found = false

                        for _, item in ipairs(bk.playerPoints) do
                            if item.PlName == other.Name then
                                found = true
                                break
                            end
                        end

                        if not found then
                            snd(1841353894, 1.5)
                            addListButton(otherRoot.Position, true, other, 0)
                        end
                    end
                end
            end
        end
    end

    for _, item in ipairs(bk.playerPoints) do
        if item.PlayerObj and item.PlayerObj.Character
            and item.PlayerObj.Character:FindFirstChild(HRP) then

            local playerRoot = item.PlayerObj.Character[HRP]

            if item.Ancor and item.Ancor.Parent then
                item.Ancor.Position = playerRoot.Position + Vector3.new(0, 10, 0)
            end

            item.Pos = playerRoot.Position
        end
    end
end)

connect(pl.CharacterAdded, function(newCharacter)
    if guiClosed then return end
    c = newCharacter
end)

buildGui()
