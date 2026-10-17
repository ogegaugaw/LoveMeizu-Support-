--[[
    MEIZU HUB
    Version: 1.0.0
    Platform: Roblox Studio / Luau (LocalScript)
    Purpose: Mobile-first, read-only Blox Fruits world/status companion UI.

    IMPORTANT:
    - Install this as a LocalScript in StarterPlayer > StarterPlayerScripts.
    - This is designed for a Roblox experience you own or are authorized to test.
    - It does NOT use executor APIs, loadstring, hidden properties, spoofed remotes,
      arbitrary server calls, combat automation, auto-farming, or exploit teleporting.
    - Blox Fruits-specific server data is not assumed. Trackers only report instances
      they can actually observe in the local client; missing objects are shown as unknown/not found.
    - Roblox LocalScripts cannot safely persist arbitrary settings between sessions without
      a server-side DataStore flow. Settings below are session-only.
]]

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Clean up a previous run and its global input connections.
local oldCleanupSignal = PlayerGui:FindFirstChild("MeizuHubCleanupSignal")
if oldCleanupSignal and oldCleanupSignal:IsA("BindableEvent") then
    oldCleanupSignal:Fire()
    oldCleanupSignal:Destroy()
end
local oldGui = PlayerGui:FindFirstChild("MeizuHubGui")
if oldGui then oldGui:Destroy() end

--// Configuration
local CONFIG = {
    Name = "Meizu Hub",
    Version = "1.0.0",
    RefreshInterval = 1.0,
    DefaultScale = 1.0,
    MinScale = 0.82,
    MaxScale = 1.12,
    DefaultTheme = "Meizu Violet",
    Themes = {
        ["Meizu Violet"] = {
            Accent = Color3.fromRGB(160, 118, 255),
            Accent2 = Color3.fromRGB(95, 155, 255),
        },
        ["Ocean Blue"] = {
            Accent = Color3.fromRGB(77, 177, 255),
            Accent2 = Color3.fromRGB(87, 235, 218),
        },
        ["Mint Glass"] = {
            Accent = Color3.fromRGB(80, 226, 177),
            Accent2 = Color3.fromRGB(120, 190, 255),
        },
        ["Rose Quartz"] = {
            Accent = Color3.fromRGB(255, 119, 177),
            Accent2 = Color3.fromRGB(180, 129, 255),
        },
    },
}

--// State
local state = {
    destroyed = false,
    minimized = false,
    menuVisible = true,
    floatingMoved = false,
    currentTab = "Home",
    theme = CONFIG.DefaultTheme,
    scale = CONFIG.DefaultScale,
    reduceMotion = false,
    liveRefresh = true,
    monitorEnabled = {Home=true, Farming=true, Bosses=true, Quests=true, Raids=true, ["Sea Events"]=true, Fishing=true, ["Mirage & Race"]=true, ["Volcano Event"]=true, ["Stats & ESP"]=true, ["Fruit & Raid"]=true, Teleport=true, Shopping=true, Player=true, Misc=true},
    glassOpacity = 0.16,
    -- Local-only visual/UI overrides. Each override records the value to restore.
    fullBrightEnabled = false,
    timeOverrideEnabled = false,
    selectedTime = "Day",
    hiddenCoreGui = {Chat = false, PlayerList = false},
    originalFullBright = nil,
    originalClockTime = nil,
    originalCoreGui = {},
    connections = {},
    pageButtons = {},
    pageFrames = {},
    pageRefreshers = {},
    themeObjects = {},
    characterConnections = {},
    lastSnapshot = {},
    refreshBusy = false,
}

local showToast
local restoreLocalOverrides

local function trackConnection(connection, bucket)
    bucket = bucket or state.connections
    table.insert(bucket, connection)
    return connection
end

local function disconnectBucket(bucket)
    for i = #bucket, 1, -1 do
        local connection = bucket[i]
        if connection then
            pcall(function() connection:Disconnect() end)
        end
        bucket[i] = nil
    end
end

local function safeCall(label, callback)
    local ok, result = xpcall(callback, debug.traceback)
    if not ok then
        warn(("[Meizu Hub] %s failed:\n%s"):format(label, tostring(result)))
        return false, result
    end
    return true, result
end

local function getTheme()
    return CONFIG.Themes[state.theme] or CONFIG.Themes[CONFIG.DefaultTheme]
end

local function addThemeObject(object, property, role)
    table.insert(state.themeObjects, {
        object = object,
        property = property,
        role = role,
    })
end

local function applyTheme()
    local theme = getTheme()
    for i = #state.themeObjects, 1, -1 do
        local item = state.themeObjects[i]
        local object = item.object
        if not object or not object.Parent then
            table.remove(state.themeObjects, i)
        else
            local color = item.role == "Accent2" and theme.Accent2 or theme.Accent
            pcall(function() object[item.property] = color end)
        end
    end
end

local function tween(object, properties, duration)
    if state.reduceMotion then
        for key, value in pairs(properties) do
            object[key] = value
        end
        return nil
    end
    local animation = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        properties
    )
    animation:Play()
    return animation
end

--// UI helpers
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MeizuHubGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 1000
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local cleanupSignal = Instance.new("BindableEvent")
cleanupSignal.Name = "MeizuHubCleanupSignal"
cleanupSignal.Parent = PlayerGui
trackConnection(cleanupSignal.Event:Connect(function()
    if state.destroyed then return end
    state.destroyed = true
    if restoreLocalOverrides then pcall(restoreLocalOverrides) end
    disconnectBucket(state.connections)
    disconnectBucket(state.characterConnections)
    if screenGui.Parent then screenGui:Destroy() end
end))

local root = Instance.new("Frame")
root.Name = "Window"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromScale(0.76, 0.69)
root.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
root.BackgroundTransparency = state.glassOpacity
root.BorderSizePixel = 0
root.ClipsDescendants = true
root.Parent = screenGui

local rootSizeConstraint = Instance.new("UISizeConstraint")
rootSizeConstraint.MinSize = Vector2.new(300, 360)
rootSizeConstraint.MaxSize = Vector2.new(760, 720)
rootSizeConstraint.Parent = root

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 18)
rootCorner.Parent = root

local rootStroke = Instance.new("UIStroke")
rootStroke.Thickness = 1
rootStroke.Transparency = 0.28
rootStroke.Color = getTheme().Accent
rootStroke.Parent = root
addThemeObject(rootStroke, "Color", "Accent")

local rootGradient = Instance.new("UIGradient")
rootGradient.Rotation = 25
rootGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 34, 52)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(17, 20, 31)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(27, 24, 43)),
})
rootGradient.Parent = root

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 56)
topBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
topBar.BackgroundTransparency = 0.94
topBar.BorderSizePixel = 0
topBar.Parent = root

local topBarLine = Instance.new("Frame")
topBarLine.AnchorPoint = Vector2.new(0, 1)
topBarLine.Position = UDim2.new(0, 12, 1, -1)
topBarLine.Size = UDim2.new(1, -24, 0, 1)
topBarLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
topBarLine.BackgroundTransparency = 0.88
topBarLine.BorderSizePixel = 0
topBarLine.Parent = topBar

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(17, 7)
title.Size = UDim2.new(1, -112, 0, 25)
title.Font = Enum.Font.GothamBold
title.Text = CONFIG.Name
title.TextColor3 = Color3.fromRGB(248, 248, 255)
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(18, 31)
subtitle.Size = UDim2.new(1, -120, 0, 15)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "BLOX FRUITS • MOBILE COMPANION"
subtitle.TextColor3 = Color3.fromRGB(158, 164, 185)
subtitle.TextSize = 9
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = topBar

local reopenButton

local function setMenuVisible(visible, notify)
    if state.destroyed then return end
    state.menuVisible = visible == true
    state.minimized = not state.menuVisible
    root.Visible = state.menuVisible
    reopenButton.Visible = true
    if notify then
        showToast(state.menuVisible and "Menu opened" or "Menu hidden",
            state.menuVisible and "Meizu Hub is ready." or "Tap the floating M icon to reopen.")
    end
end

local function makeTopButton(name, text, xOffset, width)
    local button = Instance.new("TextButton")
    button.Name = name
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, xOffset, 0.5, 0)
    button.Size = UDim2.fromOffset(width, 34)
    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundTransparency = 0.91
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Active = true
    button.Selectable = true
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.TextColor3 = Color3.fromRGB(238, 240, 250)
    button.TextSize = 15
    button.ZIndex = 5
    button.Parent = topBar
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button
    trackConnection(button.Activated:Connect(function()
        if name == "Minimize" or name == "Close" then
            setMenuVisible(false, false)
        end
    end))
    return button
end

local minimizeButton = makeTopButton("Minimize", "—", -52, 34)
local closeButton = makeTopButton("Close", "×", -12, 34)

reopenButton = Instance.new("TextButton")
reopenButton.Name = "MeizuHubFloatingToggle"
reopenButton.AnchorPoint = Vector2.new(1, 1)
reopenButton.Position = UDim2.new(1, -18, 1, -28)
reopenButton.Size = UDim2.fromOffset(48, 48)
reopenButton.BackgroundColor3 = Color3.fromRGB(24, 27, 42)
reopenButton.BackgroundTransparency = 0.10
reopenButton.BorderSizePixel = 0
reopenButton.Text = "M"
reopenButton.Font = Enum.Font.GothamBlack
reopenButton.TextSize = 21
reopenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
reopenButton.Visible = true
reopenButton.Active = true
reopenButton.Selectable = true
reopenButton.AutoButtonColor = false
reopenButton.ZIndex = 100
reopenButton.Parent = screenGui
local reopenCorner = Instance.new("UICorner")
reopenCorner.CornerRadius = UDim.new(1, 0)
reopenCorner.Parent = reopenButton
local reopenStroke = Instance.new("UIStroke")
reopenStroke.Thickness = 1.5
reopenStroke.Transparency = 0.15
reopenStroke.Color = getTheme().Accent
reopenStroke.Parent = reopenButton
addThemeObject(reopenStroke, "Color", "Accent")
local reopenGradient = Instance.new("UIGradient")
reopenGradient.Rotation = 35
reopenGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 47, 72)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 23, 37)),
})
reopenGradient.Parent = reopenButton

-- Tap toggles the existing window; drag only repositions the icon.
do
    local pressInput, pressPosition, initialButtonPosition
    local dragging = false
    local dragThreshold = 8

    local function clampFloatingPosition(x, y)
        local camera = Workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
        local insetTopLeft = GuiService:GetGuiInset()
        local width, height = reopenButton.AbsoluteSize.X, reopenButton.AbsoluteSize.Y
        local minX, maxX = 6, math.max(6, viewport.X - width - 6)
        local minY = insetTopLeft.Y + 6
        local maxY = math.max(minY, viewport.Y - height - 6)
        return Vector2.new(math.clamp(x, minX, maxX), math.clamp(y, minY, maxY))
    end

    trackConnection(reopenButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            pressInput, pressPosition = input, input.Position
            initialButtonPosition = reopenButton.AbsolutePosition
            dragging = false
        end
    end))

    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if not pressInput or not pressPosition or not initialButtonPosition then return end
        local sameTouch = input == pressInput
        local mouseMove = pressInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        if sameTouch or mouseMove then
            local delta = input.Position - pressPosition
            if not dragging and delta.Magnitude >= dragThreshold then dragging = true end
            if dragging then
                state.floatingMoved = true
                local pos = clampFloatingPosition(initialButtonPosition.X + delta.X, initialButtonPosition.Y + delta.Y)
                reopenButton.AnchorPoint = Vector2.new(0, 0)
                reopenButton.Position = UDim2.fromOffset(pos.X, pos.Y)
            end
        end
    end))

    trackConnection(UserInputService.InputEnded:Connect(function(input)
        local ended = pressInput and (input == pressInput or
            (pressInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1))
        if ended then
            local wasDragging = dragging
            pressInput, pressPosition, initialButtonPosition, dragging = nil, nil, nil, false
            if not wasDragging then setMenuVisible(not state.menuVisible, true) end
        end
    end))
end

-- Drag support: mouse and touch use the same InputObject flow.
do
    local dragging = false
    local dragInput
    local dragStart
    local startPosition

    trackConnection(topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = root.Position
            dragInput = input
        end
    end))

    trackConnection(topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput and dragStart and startPosition then
            local delta = input.Position - dragStart
            root.Position = UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
            )
        end
    end))

    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            dragInput = nil
        end
    end))
end

local body = Instance.new("Frame")
body.Name = "Body"
body.Position = UDim2.fromOffset(0, 56)
body.Size = UDim2.new(1, 0, 1, -56)
body.BackgroundTransparency = 1
body.Parent = root

local sidebar = Instance.new("ScrollingFrame")
sidebar.Name = "Navigation"
sidebar.Position = UDim2.fromOffset(10, 10)
sidebar.Size = UDim2.new(0, 112, 1, -20)
sidebar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sidebar.BackgroundTransparency = 0.95
sidebar.BorderSizePixel = 0
sidebar.ScrollBarThickness = 2
sidebar.ScrollBarImageTransparency = 0.5
sidebar.CanvasSize = UDim2.fromOffset(0, 0)
sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebar.Parent = body
local sidebarCorner = Instance.new("UICorner")
sidebarCorner.CornerRadius = UDim.new(0, 13)
sidebarCorner.Parent = sidebar
local sidebarPadding = Instance.new("UIPadding")
sidebarPadding.PaddingTop = UDim.new(0, 8)
sidebarPadding.PaddingBottom = UDim.new(0, 8)
sidebarPadding.PaddingLeft = UDim.new(0, 6)
sidebarPadding.PaddingRight = UDim.new(0, 6)
sidebarPadding.Parent = sidebar
local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 5)
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Parent = sidebar

local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.new(0, 132, 0, 10)
content.Size = UDim2.new(1, -142, 1, -20)
content.BackgroundTransparency = 1
content.Parent = body

local pageHeading = Instance.new("TextLabel")
pageHeading.Name = "PageHeading"
pageHeading.BackgroundTransparency = 1
pageHeading.Size = UDim2.new(1, 0, 0, 27)
pageHeading.Font = Enum.Font.GothamBold
pageHeading.Text = "Home"
pageHeading.TextColor3 = Color3.fromRGB(246, 247, 255)
pageHeading.TextSize = 17
pageHeading.TextXAlignment = Enum.TextXAlignment.Left
pageHeading.Parent = content

local pageScroll = Instance.new("ScrollingFrame")
pageScroll.Name = "PageScroll"
pageScroll.Position = UDim2.fromOffset(0, 33)
pageScroll.Size = UDim2.new(1, 0, 1, -33)
pageScroll.BackgroundTransparency = 1
pageScroll.BorderSizePixel = 0
pageScroll.ScrollBarThickness = 3
pageScroll.ScrollBarImageTransparency = 0.35
pageScroll.CanvasSize = UDim2.fromOffset(0, 0)
pageScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
pageScroll.Parent = content

local pagePadding = Instance.new("UIPadding")
pagePadding.PaddingTop = UDim.new(0, 2)
pagePadding.PaddingBottom = UDim.new(0, 8)
pagePadding.PaddingRight = UDim.new(0, 5)
pagePadding.Parent = pageScroll

local pageLayout = Instance.new("UIListLayout")
pageLayout.Padding = UDim.new(0, 8)
pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
pageLayout.Parent = pageScroll

local function addCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 10)
    corner.Parent = instance
    return corner
end

local function addCard(titleText, descriptionText)
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.new(1, -2, 0, 74)
    card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    card.BackgroundTransparency = 0.94
    card.BorderSizePixel = 0
    card.Parent = pageScroll
    addCorner(card, 12)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromOffset(12, 9)
    titleLabel.Size = UDim2.new(1, -24, 0, 20)
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.Text = titleText
    titleLabel.TextColor3 = Color3.fromRGB(242, 244, 255)
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = card

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.Position = UDim2.fromOffset(12, 31)
    desc.Size = UDim2.new(1, -24, 0, 33)
    desc.Font = Enum.Font.Gotham
    desc.Text = descriptionText
    desc.TextColor3 = Color3.fromRGB(167, 174, 196)
    desc.TextSize = 11
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.Parent = card
    return card, titleLabel, desc
end

local function addStatusCard(titleText, initialText)
    local card, _, description = addCard(titleText, initialText)
    description.Name = "StatusText"
    return card, description
end

local function addButton(labelText, callback)
    local button = Instance.new("TextButton")
    button.Name = "Action_" .. labelText:gsub("%W", "")
    button.Size = UDim2.new(1, -2, 0, 42)
    button.BackgroundColor3 = getTheme().Accent
    button.BackgroundTransparency = 0.12
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamSemibold
    button.Text = labelText
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 12
    button.TextWrapped = true
    button.Parent = pageScroll
    addCorner(button, 11)
    addThemeObject(button, "BackgroundColor3", "Accent")
    trackConnection(button.Activated:Connect(function()
        if state.destroyed then return end
        local ok, err = safeCall("button " .. labelText, callback)
        if not ok then
            showToast("Action failed", tostring(err):sub(1, 110))
        end
    end))
    return button
end

local function addToggle(labelText, initialValue, callback, hint)
    local row = Instance.new("Frame")
    row.Name = "Toggle_" .. labelText:gsub("%W", "")
    row.Size = UDim2.new(1, -2, 0, hint and 66 or 48)
    row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    row.BackgroundTransparency = 0.94
    row.BorderSizePixel = 0
    row.Parent = pageScroll
    addCorner(row, 11)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(11, hint and 8 or 0)
    label.Size = UDim2.new(1, -76, 0, 23)
    label.Font = Enum.Font.GothamSemibold
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(239, 242, 255)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    if hint then
        local hintLabel = Instance.new("TextLabel")
        hintLabel.BackgroundTransparency = 1
        hintLabel.Position = UDim2.fromOffset(11, 31)
        hintLabel.Size = UDim2.new(1, -22, 0, 26)
        hintLabel.Font = Enum.Font.Gotham
        hintLabel.Text = hint
        hintLabel.TextColor3 = Color3.fromRGB(151, 160, 184)
        hintLabel.TextSize = 10
        hintLabel.TextWrapped = true
        hintLabel.TextXAlignment = Enum.TextXAlignment.Left
        hintLabel.TextYAlignment = Enum.TextYAlignment.Top
        hintLabel.Parent = row
    end

    local toggleButton = Instance.new("TextButton")
    toggleButton.AnchorPoint = Vector2.new(1, 0.5)
    toggleButton.Position = UDim2.new(1, -10, 0.5, 0)
    toggleButton.Size = UDim2.fromOffset(44, 25)
    toggleButton.BackgroundColor3 = Color3.fromRGB(68, 73, 91)
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = ""
    toggleButton.AutoButtonColor = false
    toggleButton.Parent = row
    addCorner(toggleButton, 13)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(19, 19)
    knob.Position = UDim2.fromOffset(3, 3)
    knob.BackgroundColor3 = Color3.fromRGB(245, 246, 255)
    knob.BorderSizePixel = 0
    knob.Parent = toggleButton
    addCorner(knob, 10)

    local value = initialValue == true
    local function render()
        if value then
            tween(toggleButton, {BackgroundColor3 = getTheme().Accent}, 0.12)
            tween(knob, {Position = UDim2.new(1, -22, 0, 3)}, 0.12)
        else
            tween(toggleButton, {BackgroundColor3 = Color3.fromRGB(68, 73, 91)}, 0.12)
            tween(knob, {Position = UDim2.fromOffset(3, 3)}, 0.12)
        end
    end
    render()

    trackConnection(toggleButton.Activated:Connect(function()
        local nextValue = not value
        local ok, err = safeCall("toggle " .. labelText, function()
            callback(nextValue)
        end)
        if ok then
            value = nextValue
            render()
        else
            showToast("Toggle failed", tostring(err):sub(1, 110))
        end
    end))
    return {
        Get = function() return value end,
        Set = function(newValue)
            newValue = newValue == true
            if value == newValue then return end
            local ok = safeCall("set toggle " .. labelText, function() callback(newValue) end)
            if ok then value = newValue; render() end
        end,
    }
end

local function addDropdown(labelText, options, initialValue, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -2, 0, 64)
    row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    row.BackgroundTransparency = 0.94
    row.BorderSizePixel = 0
    row.Parent = pageScroll
    addCorner(row, 11)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(11, 6)
    label.Size = UDim2.new(1, -22, 0, 18)
    label.Font = Enum.Font.GothamSemibold
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(239, 242, 255)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local button = Instance.new("TextButton")
    button.Position = UDim2.fromOffset(9, 29)
    button.Size = UDim2.new(1, -18, 0, 27)
    button.BackgroundColor3 = Color3.fromRGB(20, 23, 35)
    button.BackgroundTransparency = 0.1
    button.BorderSizePixel = 0
    button.Font = Enum.Font.Gotham
    button.TextColor3 = Color3.fromRGB(226, 230, 245)
    button.TextSize = 11
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Text = "  " .. tostring(initialValue or options[1] or "Select")
    button.Parent = row
    addCorner(button, 8)

    local index = table.find(options, initialValue) or 1
    local function render()
        button.Text = "  " .. tostring(options[index] or "No options")
    end
    render()

    trackConnection(button.Activated:Connect(function()
        if #options == 0 then return end
        local nextIndex = index % #options + 1
        local nextValue = options[nextIndex]
        local ok, err = safeCall("dropdown " .. labelText, function()
            callback(nextValue)
        end)
        if ok then
            index = nextIndex
            render()
        else
            showToast("Selection failed", tostring(err):sub(1, 110))
        end
    end))
    return {
        Get = function() return options[index] end,
        Set = function(value)
            local found = table.find(options, value)
            if not found then return false end
            local ok = safeCall("set dropdown " .. labelText, function() callback(value) end)
            if ok then index = found; render(); return true end
            return false
        end,
    }
end

local function addSlider(labelText, minimum, maximum, initialValue, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -2, 0, 66)
    row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    row.BackgroundTransparency = 0.94
    row.BorderSizePixel = 0
    row.Parent = pageScroll
    addCorner(row, 11)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(11, 6)
    label.Size = UDim2.new(1, -22, 0, 18)
    label.Font = Enum.Font.GothamSemibold
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(239, 242, 255)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local valueLabel = Instance.new("TextLabel")
    valueLabel.BackgroundTransparency = 1
    valueLabel.AnchorPoint = Vector2.new(1, 0)
    valueLabel.Position = UDim2.new(1, -11, 0, 6)
    valueLabel.Size = UDim2.fromOffset(52, 18)
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.TextColor3 = Color3.fromRGB(186, 194, 218)
    valueLabel.TextSize = 10
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Text = tostring(initialValue)
    valueLabel.Parent = row

    local track = Instance.new("TextButton")
    track.Position = UDim2.fromOffset(11, 37)
    track.Size = UDim2.new(1, -22, 0, 12)
    track.BackgroundColor3 = Color3.fromRGB(63, 68, 85)
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = row
    addCorner(track, 7)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = getTheme().Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    addCorner(fill, 7)
    addThemeObject(fill, "BackgroundColor3", "Accent")

    local value = math.clamp(initialValue, minimum, maximum)
    local dragging = false
    local function setValue(nextValue)
        value = math.clamp(math.floor(nextValue + 0.5), minimum, maximum)
        local alpha = (value - minimum) / math.max(1, maximum - minimum)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        valueLabel.Text = tostring(value)
        callback(value)
    end
    setValue(value)

    local function updateFromX(x)
        local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        setValue(minimum + (maximum - minimum) * alpha)
    end
    trackConnection(track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end))
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end))
    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    return {Get = function() return value end, Set = setValue}
end

--// Toast notification
local toast = Instance.new("Frame")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, -90)
toast.Size = UDim2.new(0.8, 0, 0, 66)
toast.BackgroundColor3 = Color3.fromRGB(25, 29, 44)
toast.BackgroundTransparency = 0.04
toast.BorderSizePixel = 0
toast.Visible = true
toast.ZIndex = 20
toast.Parent = screenGui
addCorner(toast, 12)
local toastStroke = Instance.new("UIStroke")
toastStroke.Color = getTheme().Accent
toastStroke.Transparency = 0.25
toastStroke.Parent = toast
addThemeObject(toastStroke, "Color", "Accent")
local toastTitle = Instance.new("TextLabel")
toastTitle.BackgroundTransparency = 1
toastTitle.Position = UDim2.fromOffset(12, 8)
toastTitle.Size = UDim2.new(1, -24, 0, 20)
toastTitle.Font = Enum.Font.GothamBold
toastTitle.Text = "Meizu Hub"
toastTitle.TextColor3 = Color3.fromRGB(248, 249, 255)
toastTitle.TextSize = 12
toastTitle.TextXAlignment = Enum.TextXAlignment.Left
toastTitle.ZIndex = 21
toastTitle.Parent = toast
local toastBody = Instance.new("TextLabel")
toastBody.BackgroundTransparency = 1
toastBody.Position = UDim2.fromOffset(12, 29)
toastBody.Size = UDim2.new(1, -24, 0, 28)
toastBody.Font = Enum.Font.Gotham
toastBody.Text = ""
toastBody.TextColor3 = Color3.fromRGB(176, 184, 205)
toastBody.TextSize = 10
toastBody.TextWrapped = true
toastBody.TextXAlignment = Enum.TextXAlignment.Left
toastBody.ZIndex = 21
toastBody.Parent = toast

local toastToken = 0
showToast = function(titleText, bodyText)
    toastToken += 1
    local token = toastToken
    toastTitle.Text = tostring(titleText or "Meizu Hub")
    toastBody.Text = tostring(bodyText or "")
    tween(toast, {Position = UDim2.new(0.5, 0, 0, 14)}, 0.2)
    task.delay(2.6, function()
        if token == toastToken and toast.Parent then
            tween(toast, {Position = UDim2.new(0.5, 0, 0, -90)}, 0.2)
        end
    end)
end

--// Page management
local pages = {}
local navButtons = {}
local tabNames = {
    "Home", "Farming", "Bosses", "Quests", "Raids", "Sea Events", "Fishing", "Mirage & Race", "Volcano Event", "Stats & ESP", "Fruit & Raid", "Teleport", "Shopping", "Player", "Misc", "Settings", "About",
}

local function clearPage()
    state.pageRefreshers[state.currentTab] = nil
    for _, child in ipairs(pageScroll:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

local function showTab(tabName)
    if not pages[tabName] then return end
    -- Clear the page being left before changing currentTab so its refresher is removed.
    clearPage()
    state.currentTab = tabName
    pageHeading.Text = tabName
    safeCall("render tab " .. tabName, pages[tabName])
    for name, button in pairs(navButtons) do
        local selected = name == tabName
        button.BackgroundTransparency = selected and 0.08 or 0.94
        button.TextColor3 = selected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(176, 183, 204)
        if selected then
            button.BackgroundColor3 = getTheme().Accent
        else
            button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
end

for index, tabName in ipairs(tabNames) do
    local button = Instance.new("TextButton")
    button.Name = "Nav_" .. tabName:gsub("%W", "")
    button.LayoutOrder = index
    button.Size = UDim2.new(1, 0, 0, 38)
    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    button.BackgroundTransparency = 0.94
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamSemibold
    button.Text = tabName
    button.TextColor3 = Color3.fromRGB(176, 183, 204)
    button.TextSize = 10
    button.TextWrapped = true
    button.Parent = sidebar
    addCorner(button, 9)
    navButtons[tabName] = button
    trackConnection(button.Activated:Connect(function()
        showTab(tabName)
    end))
end

--// Read-only game observations
local observedWorldNames = {
    "Mirage Island", "Frozen Dimension", "Prehistoric Island", "KitsuneIsland",
    "Kitsune Island", "Terrorshark", "Sea Beast", "Leviathan", "Dough King",
    "Cake Prince", "Rip Indra", "Soul Reaper", "Tyrant of the Skies",
}

local function findObservedInstance(name)
    local roots = {Workspace}
    local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")
    local map = Workspace:FindFirstChild("Map")
    if worldOrigin then table.insert(roots, worldOrigin) end
    if map then table.insert(roots, map) end

    for _, rootObject in ipairs(roots) do
        local found = rootObject:FindFirstChild(name, true)
        if found then return found end
    end
    return nil
end

local function getCharacterStats()
    local character = LocalPlayer.Character
    if not character then
        return {status = "Character not spawned", health = "—", speed = "—", jump = "—"}
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return {status = "Waiting for Humanoid", health = "—", speed = "—", jump = "—"}
    end
    return {
        status = humanoid.Health > 0 and "Alive" or "Down",
        health = ("%d / %d"):format(math.floor(humanoid.Health + 0.5), math.floor(humanoid.MaxHealth + 0.5)),
        speed = tostring(math.floor(humanoid.WalkSpeed + 0.5)),
        jump = tostring(math.floor(humanoid.JumpPower + 0.5)),
    }
end

local function getObservedWorldStatus()
    local result = {}
    for _, name in ipairs(observedWorldNames) do
        local object = findObservedInstance(name)
        result[name] = object and ("Found: " .. object:GetFullName()) or "Not visible to this client"
    end
    return result
end

local function countPlayerCharacters()
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
            count += 1
        end
    end
    return count
end

-- Read-only utilities sourced from the original Info/Status, Farming, Quest and Raid groups.
local function getGameClockText()
    local clock = Lighting.ClockTime
    local hours = math.floor(clock)
    local minutes = math.floor((clock - hours) * 60 + 0.5)
    if minutes >= 60 then hours = (hours + 1) % 24; minutes = 0 end
    local period = (hours >= 6 and hours < 18) and "Daylight" or "Night"
    return ("%02d:%02d game time • %s"):format(hours, minutes, period)
end

local function getClientClockText()
    local ok, value = pcall(function() return os.date("%Y-%m-%d %H:%M:%S") end)
    return ok and tostring(value) or "Local clock unavailable"
end

--// Real local-only utility features (no game remotes or executor APIs)
local function setFullBright(enabled)
    if enabled then
        if not state.originalFullBright then
            state.originalFullBright = {
                Brightness = Lighting.Brightness,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                FogEnd = Lighting.FogEnd,
                GlobalShadows = Lighting.GlobalShadows,
            }
        end
        state.fullBrightEnabled = true
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    else
        state.fullBrightEnabled = false
        local original = state.originalFullBright
        if original then
            Lighting.Brightness = original.Brightness
            Lighting.Ambient = original.Ambient
            Lighting.OutdoorAmbient = original.OutdoorAmbient
            Lighting.FogEnd = original.FogEnd
            Lighting.GlobalShadows = original.GlobalShadows
            state.originalFullBright = nil
        end
    end
end

local function setTimeOverride(enabled)
    if enabled then
        if not state.timeOverrideEnabled then
            state.originalClockTime = Lighting.ClockTime
        end
        state.timeOverrideEnabled = true
        Lighting.ClockTime = state.selectedTime == "Night" and 0 or 12
    else
        state.timeOverrideEnabled = false
        if state.originalClockTime ~= nil then
            Lighting.ClockTime = state.originalClockTime
            state.originalClockTime = nil
        end
    end
end

local function setCoreGuiHidden(coreGuiType, hidden, stateKey)
    if hidden then
        if state.originalCoreGui[stateKey] == nil then
            local ok, wasEnabled = pcall(function()
                return StarterGui:GetCoreGuiEnabled(coreGuiType)
            end)
            if ok then
                state.originalCoreGui[stateKey] = wasEnabled
            else
                -- If Roblox does not expose the current state, use the normal visible default.
                state.originalCoreGui[stateKey] = true
            end
        end
        StarterGui:SetCoreGuiEnabled(coreGuiType, false)
        state.hiddenCoreGui[stateKey] = true
    else
        local original = state.originalCoreGui[stateKey]
        StarterGui:SetCoreGuiEnabled(coreGuiType, original == nil and true or original)
        state.originalCoreGui[stateKey] = nil
        state.hiddenCoreGui[stateKey] = false
    end
end

restoreLocalOverrides = function()
    if state.fullBrightEnabled then setFullBright(false) end
    if state.timeOverrideEnabled then setTimeOverride(false) end
    for key, hidden in pairs(state.hiddenCoreGui) do
        if hidden then
            local coreGuiType = key == "Chat" and Enum.CoreGuiType.Chat or Enum.CoreGuiType.PlayerList
            pcall(function() setCoreGuiHidden(coreGuiType, false, key) end)
        end
    end
end

local function reapplyLocalOverrides()
    if state.fullBrightEnabled then
        -- Keep the override active if the game updates Lighting while enabled.
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    end
    if state.timeOverrideEnabled then
        Lighting.ClockTime = state.selectedTime == "Night" and 0 or 12
    end
end

local function getVisibleEnemySummary()
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return "Workspace.Enemies not found; target hierarchy is unknown." end
    local count, nearestName, nearestDistance = 0, nil, math.huge
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    for _, model in ipairs(enemies:GetChildren()) do
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local targetRoot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
        if humanoid and humanoid.Health > 0 then
            count += 1
            if rootPart and targetRoot and targetRoot:IsA("BasePart") then
                local distance = (targetRoot.Position - rootPart.Position).Magnitude
                if distance < nearestDistance then
                    nearestDistance, nearestName = distance, model.Name
                end
            end
        end
    end
    if nearestName then
        return ("Visible living models: %d • Nearest: %s (%.0f studs)"):format(count, nearestName, nearestDistance)
    end
    return ("Visible living models: %d • Nearest distance unavailable"):format(count)
end

local function getQuestUiSummary()
    local main = PlayerGui:FindFirstChild("Main")
    if not main then return "Quest UI container 'Main' is not present on this client." end
    local candidates = {}
    for _, item in ipairs(main:GetDescendants()) do
        if item:IsA("TextLabel") and item.Visible and item.Text ~= "" then
            local textValue = item.Text
            local lower = string.lower(textValue)
            if lower:find("quest", 1, true) or lower:find("mission", 1, true) or lower:find("defeat", 1, true) or lower:find("kill", 1, true) then
                table.insert(candidates, textValue:gsub("%s+", " "))
                if #candidates >= 3 then break end
            end
        end
    end
    if #candidates == 0 then
        return "Main UI exists, but no visible quest-like TextLabel was detected. This does not establish quest completion."
    end
    return table.concat(candidates, " | ")
end

local function getToolInventorySummary()
    local containers = {}
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local character = LocalPlayer.Character
    if backpack then table.insert(containers, backpack) end
    if character then table.insert(containers, character) end
    local tools, chipCount = {}, 0
    for _, container in ipairs(containers) do
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(tools, item.Name)
                local lower = string.lower(item.Name)
                if lower:find("microchip", 1, true) or lower:find("micro chip", 1, true) then chipCount += 1 end
            end
        end
    end
    table.sort(tools)
    local shown = {}
    for i = 1, math.min(#tools, 8) do shown[i] = tools[i] end
    local toolText = #shown > 0 and table.concat(shown, ", ") or "No Tool instances found"
    if #tools > #shown then toolText ..= (" +%d more"):format(#tools - #shown) end
    return ("Tools: %d • Raid microchip-like tools: %d • %s"):format(#tools, chipCount, toolText)
end

--// Tabs
pages.Home = function()
    addCard("Welcome back", "Meizu Hub is a read-only companion UI. It does not automate combat, farming, or server remotes.")
    local playerCard, playerText = addStatusCard("Player status", "Reading current character…")
    local serverCard, serverText = addStatusCard("Session", "Reading current session…")
    local worldCard, worldText = addStatusCard("World observations", "Scanning visible workspace objects…")
    local clockCard, clockText = addStatusCard("Game / local time", "Reading clocks…")
    local function refreshHomeStatus()
        local stats = getCharacterStats()
        playerText.Text = ("%s  •  HP %s  •  WalkSpeed %s  •  JumpPower %s"):format(stats.status, stats.health, stats.speed, stats.jump)
        serverText.Text = ("Players: %d  •  PlaceId: %s  •  JobId: %s"):format(#Players:GetPlayers(), tostring(game.PlaceId), game.JobId ~= "" and game.JobId or "Unavailable")
        local found = 0
        local statuses = getObservedWorldStatus()
        for _, value in pairs(statuses) do
            if value:sub(1, 6) == "Found:" then found += 1 end
        end
        worldText.Text = ("%d of %d tracked names currently visible. This is a client-side observation, not authoritative event data."):format(found, #observedWorldNames)
        clockText.Text = getGameClockText() .. " • Client: " .. getClientClockText()
    end
    state.pageRefreshers.Home = refreshHomeStatus
    addToggle("Live home status monitor", state.monitorEnabled.Home, function(value)
        state.monitorEnabled.Home = value
        if value then refreshHomeStatus() end
        showToast("Home status monitor", value and "Enabled: Home observations update automatically." or "Disabled: automatic Home updates stopped.")
    end, "Controls periodic character/session/world-clock observations on Home.")
    addButton("Refresh status now", function()
        refreshHomeStatus()
        showToast("Status refreshed", "Values were read from the current client.")
    end)
    refreshHomeStatus()
    addCard("Quick note", "If a Blox Fruits object is streamed out or its internal name differs, the tracker may not see it. Not found does not prove an event is inactive.")
end

pages.Farming = function()
    addCard("Farming utilities", "This tab offers a live, read-only enemy monitor. It does not start auto-farm, attack, pull mobs, or manipulate progression.")
    local _, enemyText = addStatusCard("Visible enemy monitor", getVisibleEnemySummary())
    local function refreshEnemySummary() enemyText.Text = getVisibleEnemySummary() end
    state.pageRefreshers.Farming = refreshEnemySummary
    addToggle("Live enemy monitor", state.monitorEnabled.Farming, function(value)
        state.monitorEnabled.Farming = value
        if value then refreshEnemySummary() end
        showToast("Enemy monitor", value and "Enabled: read-only scan updates while this tab is open." or "Disabled: automatic enemy scans stopped.")
    end, "Only reads visible Workspace.Enemies; it does not target or attack NPCs.")
    addButton("Refresh visible enemy count", function()
        refreshEnemySummary()
        showToast("Enemy monitor refreshed", "Read-only Workspace scan completed.")
    end)
    addCard("Safe alternative: character monitor", "Use Home or Player to read actual health, walk speed and jump power. The monitor does not target, highlight, move toward or attack anything.")
    addButton("Open Home status", function() showTab("Home") end)
    addCard("Not integrated from source", "Auto Farm Level/Nearest, chest and berry farming, mob pulling, mastery automation, kill aura and fast attack are excluded because they automate combat/progression in a third-party experience.")
end

pages.Bosses = function()
    addCard("Boss observer", "Toggle the read-only scan of common boss names visible to this client. Not visible does not prove a boss is absent from the server.")
    local names = {"Cake Prince", "Dough King", "Rip Indra", "Soul Reaper", "Tyrant of the Skies", "Terrorshark", "Leviathan"}
    local labels = {}
    for _, name in ipairs(names) do local _, textLabel = addStatusCard(name, "Scanning…"); labels[name] = textLabel end
    local function refreshBosses()
        for _, name in ipairs(names) do
            local object = findObservedInstance(name)
            labels[name].Text = object and ("Visible: " .. object:GetFullName()) or "Not visible to this client"
        end
    end
    state.pageRefreshers.Bosses = refreshBosses
    addToggle("Live boss monitor", state.monitorEnabled.Bosses, function(value)
        state.monitorEnabled.Bosses = value
        if value then refreshBosses() end
        showToast("Boss monitor", value and "Enabled: visible boss scan updates while this tab is open." or "Disabled: automatic boss scans stopped.")
    end, "Read-only; does not teleport to, target, or attack bosses.")
    addButton("Rescan visible bosses", function() refreshBosses(); showToast("Boss scan complete", "Only locally visible instances were checked.") end)
    refreshBosses()
end

pages.Quests = function()
    addCard("Quest status", "Quest completion/progression are server-authoritative. This page only reads visible quest-like text from the local PlayerGui.")
    local _, questText = addStatusCard("Visible quest text", getQuestUiSummary())
    local function refreshQuestText() questText.Text = getQuestUiSummary() end
    state.pageRefreshers.Quests = refreshQuestText
    addToggle("Live quest UI observer", state.monitorEnabled.Quests, function(value)
        state.monitorEnabled.Quests = value
        if value then refreshQuestText() end
        showToast("Quest UI observer", value and "Enabled: visible quest text refreshes on this tab." or "Disabled: automatic quest UI scans stopped.")
    end, "Reads visible text only; it cannot verify server progress or complete quests.")
    addButton("Refresh quest UI observation", function() refreshQuestText(); showToast("Quest observation refreshed", "Visible client UI text was scanned; server progress was not queried.") end)
    addCard("Compatibility", "The source's Tushita/Yama, Skull Guitar, Cursed Dual Katana, race, Bartilo/Citizen and other quest automation depends on private game state and server calls; it is not enabled here.")
    refreshQuestText()
end

pages.Raids = function()
    addCard("Raid observer", "Toggle a read-only inventory/instance monitor. Raid start, chip purchase, dungeon completion and awakening remotes are not invoked.")
    local _, inventoryText = addStatusCard("Local tool inventory", getToolInventorySummary())
    local raidNames = {"Raid", "RaidIsland", "Dungeon", "Microchip", "Awakening"}
    local raidLabels = {}
    for _, name in ipairs(raidNames) do local _, textLabel = addStatusCard(name, "Scanning…"); raidLabels[name] = textLabel end
    local function refreshRaidObserver()
        inventoryText.Text = getToolInventorySummary()
        for _, name in ipairs(raidNames) do
            local object = findObservedInstance(name)
            raidLabels[name].Text = object and ("Visible instance: " .. object:GetFullName()) or "No matching visible instance"
        end
    end
    state.pageRefreshers.Raids = refreshRaidObserver
    addToggle("Live raid inventory observer", state.monitorEnabled.Raids, function(value)
        state.monitorEnabled.Raids = value
        if value then refreshRaidObserver() end
        showToast("Raid observer", value and "Enabled: local inventory and visible names refresh on this tab." or "Disabled: automatic raid observations stopped.")
    end, "Does not buy chips, start raids, awaken fruits, or call game remotes.")
    addButton("Refresh tool inventory", function() refreshRaidObserver(); showToast("Raid observation refreshed", "Only local Tool instances and visible names were inspected.") end)
    refreshRaidObserver()
end

pages["Sea Events"] = function()
    addCard("Sea event observer", "Toggle periodic checks for common sea-event names visible in the local Workspace.")
    local names = {"Terrorshark", "Sea Beast", "Leviathan", "Fish Boat", "Pirate Grand Brigade", "KitsuneIsland", "Frozen Dimension"}
    local labels = {}
    for _, name in ipairs(names) do local _, textLabel = addStatusCard(name, "Scanning…"); labels[name] = textLabel end
    local function refreshSeaEvents()
        for _, name in ipairs(names) do
            local object = findObservedInstance(name)
            labels[name].Text = object and ("Visible: " .. object:GetFullName()) or "Not visible to this client"
        end
    end
    state.pageRefreshers["Sea Events"] = refreshSeaEvents
    addToggle("Live sea-event monitor", state.monitorEnabled["Sea Events"], function(value)
        state.monitorEnabled["Sea Events"] = value
        if value then refreshSeaEvents() end
        showToast("Sea-event monitor", value and "Enabled: visible event scan updates while this tab is open." or "Disabled: automatic sea-event scans stopped.")
    end, "Read-only observation; no sailing, ship manipulation, or event combat.")
    addCard("Not implemented", "Auto-sail, ship noclip, boat speed manipulation, sea-event combat and Azure Ember automation are not included.")
    refreshSeaEvents()
end

pages.Fishing = function()
    addCard("Fishing observer", "Read-only view of locally held fishing tools and visible fishing-related objects. This does not auto-cast, catch, buy bait, or invoke remotes.")
    local _, toolsText = addStatusCard("Local fishing tools", "Scanning…")
    local _, objectsText = addStatusCard("Visible fishing objects", "Scanning…")
    local _, uiText = addStatusCard("Fishing UI text", "Scanning…")
    local function refreshFishing()
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local character = LocalPlayer.Character
        local found = {}
        local containers = {}
        if backpack then table.insert(containers, backpack) end
        if character then table.insert(containers, character) end
        for _, container in ipairs(containers) do
            for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Tool") then
                        local n = string.lower(item.Name)
                        if n:find("fish", 1, true) or n:find("rod", 1, true) or n:find("bait", 1, true) then
                            table.insert(found, item.Name)
                        end
                    end
            end
        end
        table.sort(found)
        toolsText.Text = #found > 0 and table.concat(found, ", ") or "No locally held fishing-related Tool detected"
        local names = {"FishingRod", "Fishing Rod", "FishingZone", "FishingSpot", "Fish"}
        local visible = {}
        for _, name in ipairs(names) do
            local object = findObservedInstance(name)
            if object then table.insert(visible, name .. ": " .. object:GetFullName()) end
        end
        objectsText.Text = #visible > 0 and table.concat(visible, "\n") or "No matching fishing-related instance visible to this client"
        local uiMatches = {}
        for _, item in ipairs(PlayerGui:GetDescendants()) do
            if item:IsA("TextLabel") and item.Visible and item.Text ~= "" then
                local lower = string.lower(item.Text)
                if lower:find("fish", 1, true) or lower:find("bait", 1, true) or lower:find("cast", 1, true) then
                    table.insert(uiMatches, item.Text:gsub("%s+", " "))
                    if #uiMatches >= 3 then break end
                end
            end
        end
        uiText.Text = #uiMatches > 0 and table.concat(uiMatches, " | ") or "No visible fishing-related UI text found"
    end
    state.pageRefreshers.Fishing = refreshFishing
    addToggle("Live fishing observer", state.monitorEnabled.Fishing, function(value)
        state.monitorEnabled.Fishing = value
        if value then refreshFishing() end
        showToast("Fishing observer", value and "Local inventory/UI scan enabled." or "Automatic fishing observations paused.")
    end, "Observes local tools and visible UI only; no fishing automation.")
    addButton("Refresh fishing observations", function() refreshFishing(); showToast("Fishing scan", "Local fishing observations refreshed.") end)
    refreshFishing()
end

pages["Mirage & Race"] = function()
    addCard("Mirage and race observer", "Checks only named objects and race-related text visible to this client. It cannot confirm server-side race progress.")
    local names = {"Mirage Island", "MirageIsland", "Blue Gear", "BlueGear", "RaceV4", "Temple of Time", "TempleOfTime"}
    local labels = {}
    for _, name in ipairs(names) do local _, label = addStatusCard(name, "Scanning…"); labels[name] = label end
    local _, raceUi = addStatusCard("Visible race UI", "Scanning…")
    local function refreshMirageRace()
        for _, name in ipairs(names) do
            local object = findObservedInstance(name)
            labels[name].Text = object and ("Visible locally: " .. object:GetFullName()) or "Not visible to this client"
        end
        local found = {}
        for _, item in ipairs(PlayerGui:GetDescendants()) do
            if item:IsA("TextLabel") and item.Visible and item.Text ~= "" then
                local lower = string.lower(item.Text)
                if lower:find("race", 1, true) or lower:find("gear", 1, true) or lower:find("mirage", 1, true) then
                    table.insert(found, item.Text:gsub("%s+", " "))
                    if #found >= 3 then break end
                end
            end
        end
        raceUi.Text = #found > 0 and table.concat(found, " | ") or "No visible race/Mirage-related text found"
    end
    state.pageRefreshers["Mirage & Race"] = refreshMirageRace
    addToggle("Live Mirage/race observer", state.monitorEnabled["Mirage & Race"], function(value)
        state.monitorEnabled["Mirage & Race"] = value
        if value then refreshMirageRace() end
        showToast("Mirage/race observer", value and "Visible instance/UI scan enabled." or "Automatic observations paused.")
    end, "No gear collection, race upgrade, teleport, or remote calls.")
    addButton("Rescan Mirage and race", function() refreshMirageRace(); showToast("Scan complete", "Only local visible objects/UI were checked.") end)
    refreshMirageRace()
end

pages["Volcano Event"] = function()
    addCard("Volcano event observer", "Looks for locally visible volcano, lava, prehistoric and eruption-related objects. Names may differ by experience version.")
    local names = {"Volcano", "VolcanoEvent", "Volcanic", "Eruption", "Lava", "Prehistoric Island", "PrehistoricIsland", "Dinosaur"}
    local labels = {}
    for _, name in ipairs(names) do local _, label = addStatusCard(name, "Scanning…"); labels[name] = label end
    local function refreshVolcano()
        for _, name in ipairs(names) do
            local object = findObservedInstance(name)
            labels[name].Text = object and ("Visible locally: " .. object:GetFullName()) or "Not visible to this client"
        end
    end
    state.pageRefreshers["Volcano Event"] = refreshVolcano
    addToggle("Live volcano observer", state.monitorEnabled["Volcano Event"], function(value)
        state.monitorEnabled["Volcano Event"] = value
        if value then refreshVolcano() end
        showToast("Volcano observer", value and "Visible event scan enabled." or "Automatic observations paused.")
    end, "Read-only; does not trigger, enter, or automate an event.")
    addButton("Rescan volcano event", function() refreshVolcano(); showToast("Volcano scan", "Local instance scan completed.") end)
    refreshVolcano()
end

pages["Stats & ESP"] = function()
    addCard("Player status list", "Read-only list of players and locally observable character stats. This is not an ESP overlay and does not reveal hidden/server-only information.")
    local _, countText = addStatusCard("Players observed", "Scanning…")
    local playerRows = {}
    for index = 1, 12 do local _, label = addStatusCard("Player " .. index, "—"); playerRows[index] = label end
    local function refreshPlayerList()
        local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local playerList = Players:GetPlayers()
        table.sort(playerList, function(a, b) return a.Name:lower() < b.Name:lower() end)
        countText.Text = ("%d players in this client session; list capped at %d."):format(#playerList, #playerRows)
        for index, label in ipairs(playerRows) do
            local player = playerList[index]
            if player then
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                local health = humanoid and ("HP " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)) or "HP unavailable"
                local distance = localRoot and rootPart and (" • " .. math.floor((rootPart.Position - localRoot.Position).Magnitude) .. " studs") or ""
                label.Text = player.Name .. (player == LocalPlayer and " (you)" or "") .. " • " .. health .. distance
            else
                label.Text = "—"
            end
        end
    end
    state.pageRefreshers["Stats & ESP"] = refreshPlayerList
    addToggle("Live player status list", state.monitorEnabled["Stats & ESP"], function(value)
        state.monitorEnabled["Stats & ESP"] = value
        if value then refreshPlayerList() end
        showToast("Player list", value and "Local player status updates enabled." or "Automatic player status updates paused.")
    end, "No wallhack, target highlighting, aimbot, or hidden-player data.")
    addButton("Refresh player list", function() refreshPlayerList() end)
    refreshPlayerList()
end

pages["Fruit & Raid"] = function()
    addCard("Fruit and raid inventory observer", "Lists locally held tools with fruit/raid-related names and visible raid-related instances. It does not buy, activate, awaken, or start anything.")
    local _, fruitText = addStatusCard("Fruit-related tools", "Scanning…")
    local _, raidText = addStatusCard("Raid-related tools", "Scanning…")
    local _, objectsText = addStatusCard("Visible raid objects", "Scanning…")
    local function refreshFruitRaid()
        local containers = {}
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then table.insert(containers, backpack) end
        if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end
        local fruits, raids = {}, {}
        for _, container in ipairs(containers) do
            for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Tool") then
                        local lower = string.lower(item.Name)
                        if lower:find("fruit", 1, true) or lower:find("blox", 1, true) then table.insert(fruits, item.Name) end
                        if lower:find("raid", 1, true) or lower:find("chip", 1, true) or lower:find("microchip", 1, true) or lower:find("awakening", 1, true) then table.insert(raids, item.Name) end
                    end
            end
        end
        table.sort(fruits); table.sort(raids)
        fruitText.Text = #fruits > 0 and table.concat(fruits, ", ") or "No fruit-related Tool detected locally"
        raidText.Text = #raids > 0 and table.concat(raids, ", ") or "No raid-related Tool detected locally"
        local names = {"RaidIsland", "Raid Island", "Dungeon", "Microchip", "Awakening"}
        local found = {}
        for _, name in ipairs(names) do local object = findObservedInstance(name); if object then table.insert(found, name .. ": " .. object:GetFullName()) end end
        objectsText.Text = #found > 0 and table.concat(found, "\n") or "No matching raid object visible to this client"
    end
    state.pageRefreshers["Fruit & Raid"] = refreshFruitRaid
    addToggle("Live fruit/raid observer", state.monitorEnabled["Fruit & Raid"], function(value)
        state.monitorEnabled["Fruit & Raid"] = value
        if value then refreshFruitRaid() end
        showToast("Fruit/raid observer", value and "Local inventory scan enabled." or "Automatic observations paused.")
    end, "Read-only local inventory and visible object scan.")
    addButton("Refresh fruit/raid inventory", function() refreshFruitRaid() end)
    refreshFruitRaid()
end

pages.Teleport = function()
    addCard("Destination observer", "Lists destination-like BaseParts visible under Workspace._WorldOrigin.Locations. This tab does not teleport or move the character.")
    local _, locationText = addStatusCard("Visible locations", "Scanning…")
    local _, spawnText = addStatusCard("Spawn-related objects", "Scanning…")
    local function refreshLocations()
        local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")
        local locations = worldOrigin and worldOrigin:FindFirstChild("Locations")
        local names = {}
        if locations then
            for _, item in ipairs(locations:GetChildren()) do
                if item:IsA("BasePart") then table.insert(names, item.Name) end
            end
        end
        table.sort(names)
        local shown = {}
        for index = 1, math.min(#names, 18) do shown[index] = names[index] end
        locationText.Text = #shown > 0 and table.concat(shown, ", ") or "No visible location markers found"
        local spawnNames = {"SpawnPoint", "SpawnLocation", "SetSpawnPoint", "HomePoint"}
        local found = {}
        for _, name in ipairs(spawnNames) do local object = findObservedInstance(name); if object then table.insert(found, name .. ": " .. object:GetFullName()) end end
        spawnText.Text = #found > 0 and table.concat(found, "\n") or "No matching spawn-related object visible"
    end
    state.pageRefreshers.Teleport = refreshLocations
    addToggle("Live destination observer", state.monitorEnabled.Teleport, function(value)
        state.monitorEnabled.Teleport = value
        if value then refreshLocations() end
        showToast("Destination observer", value and "Location scan enabled." or "Automatic location scans paused.")
    end, "No teleport, server hopping, or character movement is performed.")
    addButton("Refresh visible destinations", function() refreshLocations() end)
    refreshLocations()
end

pages.Shopping = function()
    addCard("Shop and currency UI observer", "Reads visible local UI text that appears related to currency or shops. It does not purchase items or query private server data.")
    local _, currencyText = addStatusCard("Visible currency text", "Scanning…")
    local _, shopText = addStatusCard("Visible shop text", "Scanning…")
    local function refreshShopUI()
        local currency, shops = {}, {}
        for _, item in ipairs(PlayerGui:GetDescendants()) do
            if item:IsA("TextLabel") and item.Visible and item.Text ~= "" then
                local textValue = item.Text:gsub("%s+", " ")
                local lower = string.lower(textValue)
                if lower:find("beli", 1, true) or lower:find("money", 1, true) or lower:find("fragment", 1, true) or lower:find("cash", 1, true) then
                    table.insert(currency, textValue)
                end
                if lower:find("shop", 1, true) or lower:find("buy", 1, true) or lower:find("price", 1, true) then
                    table.insert(shops, textValue)
                end
            end
            if #currency >= 4 and #shops >= 4 then break end
        end
        currencyText.Text = #currency > 0 and table.concat(currency, " | ") or "No visible currency-related text found"
        shopText.Text = #shops > 0 and table.concat(shops, " | ") or "No visible shop-related text found"
    end
    state.pageRefreshers.Shopping = refreshShopUI
    addToggle("Live shop UI observer", state.monitorEnabled.Shopping, function(value)
        state.monitorEnabled.Shopping = value
        if value then refreshShopUI() end
        showToast("Shop UI observer", value and "Visible shop/currency text scan enabled." or "Automatic UI scans paused.")
    end, "Visible UI text only; no purchases or currency manipulation.")
    addButton("Refresh visible shop UI", function() refreshShopUI() end)
    refreshShopUI()
end

pages.Misc = function()
    addCard("Local diagnostics", "Supported client-side diagnostics and UI preferences only. Executor hooks, anti-admin evasion, anti-AFK spoofing and hidden-property changes are not included.")
    local _, runtimeText = addStatusCard("Runtime", "Reading…")
    local _, inputText = addStatusCard("Input mode", "Reading…")
    local _, guiText = addStatusCard("UI state", "Reading…")
    local function refreshDiagnostics()
        runtimeText.Text = (RunService:IsStudio() and "Roblox Studio" or "Roblox client") .. " • PlaceId " .. tostring(game.PlaceId)
        inputText.Text = UserInputService.TouchEnabled and "Touch enabled" or "Touch unavailable"
        if UserInputService.MouseEnabled then inputText.Text ..= " • Mouse enabled" end
        guiText.Text = (state.menuVisible and "Menu visible" or "Menu hidden") .. " • " .. (state.destroyed and "Cleaning up" or "Connections active")
    end
    state.pageRefreshers.Misc = refreshDiagnostics
    addToggle("Live local diagnostics", state.monitorEnabled.Misc, function(value)
        state.monitorEnabled.Misc = value
        if value then refreshDiagnostics() end
        showToast("Local diagnostics", value and "Diagnostics updates enabled." or "Automatic diagnostics paused.")
    end, "Reports supported local runtime/input state only.")
    addButton("Refresh local diagnostics", function() refreshDiagnostics() end)
    addButton("Return to Home", function() showTab("Home") end)
    refreshDiagnostics()
end

pages.Player = function()
    addCard("Local character", "Read-only values from your current Humanoid. Values are refreshed periodically and after respawn.")
    local statusCard, statusText = addStatusCard("Character", "Waiting for character…")
    local hpCard, hpText = addStatusCard("Health", "—")
    local movementCard, movementText = addStatusCard("Movement", "—")
    local function refreshCharacter()
        local stats = getCharacterStats()
        statusText.Text = stats.status
        hpText.Text = stats.health
        movementText.Text = ("WalkSpeed %s  •  JumpPower %s"):format(stats.speed, stats.jump)
    end
    state.pageRefreshers.Player = refreshCharacter
    addToggle("Live character monitor", state.monitorEnabled.Player, function(value)
        state.monitorEnabled.Player = value
        if value then refreshCharacter() end
        showToast("Character monitor", value and "Enabled: health and movement values update while this tab is open." or "Disabled: automatic character reads stopped.")
    end, "Read-only health, WalkSpeed and JumpPower; this does not modify movement.")
    refreshCharacter()
    addButton("Refresh character values", refreshCharacter)
    addCard("Not included", "No-clip, fly, infinite energy/range, dash cooldown changes, aimbot, player targeting, PvP automation, or forced movement.")
end

pages.Settings = function()
    addCard("Appearance", "Settings apply to this UI for the current session only.")
    addDropdown("Accent theme", {"Meizu Violet", "Ocean Blue", "Mint Glass", "Rose Quartz"}, state.theme, function(value)
        state.theme = value
        applyTheme()
        for name, button in pairs(navButtons) do
            if name == state.currentTab then
                button.BackgroundColor3 = getTheme().Accent
            end
        end
        showToast("Theme applied", value)
    end)
    addSlider("Window scale (%)", 82, 112, math.floor(state.scale * 100 + 0.5), function(value)
        state.scale = value / 100
        root.Size = UDim2.new(0.76 * state.scale, 0, 0.69 * state.scale, 0)
    end)
    addToggle("Reduce motion", state.reduceMotion, function(value)
        state.reduceMotion = value
        showToast("Reduce motion", value and "Animations reduced." or "Animations enabled.")
    end, "Reduces UI tween animations; useful on lower-powered phones.")
    addToggle("Live status refresh", state.liveRefresh, function(value)
        state.liveRefresh = value
        showToast("Live status refresh", value and "Periodic Home/Player/Farming refresh enabled." or "Periodic refresh paused; use Refresh buttons manually.")
    end, "Master switch for periodic read-only updates across all monitor tabs. Manual refresh buttons remain available.")
    addToggle("Full Bright (local Lighting)", state.fullBrightEnabled, function(value)
        setFullBright(value)
        showToast("Full Bright", value and "Local Lighting override enabled." or "Original Lighting values restored.")
    end, "Changes only local Lighting properties. Original values are restored when switched off or the UI is cleaned up.")
    addDropdown("Time override", {"Day", "Night"}, state.selectedTime, function(value)
        state.selectedTime = value
        if state.timeOverrideEnabled then
            Lighting.ClockTime = value == "Night" and 0 or 12
        end
        showToast("Time selection", value .. (state.timeOverrideEnabled and " applied locally." or " selected; enable Time override to apply."))
    end)
    addToggle("Enable Day / Night override", state.timeOverrideEnabled, function(value)
        setTimeOverride(value)
        showToast("Time override", value and (state.selectedTime .. " applied locally.") or "Original ClockTime restored.")
    end, "Uses a separate Day/Night setting (fixes the original source's shared-variable conflict).")
    addToggle("Hide Chat UI", state.hiddenCoreGui.Chat, function(value)
        setCoreGuiHidden(Enum.CoreGuiType.Chat, value, "Chat")
        showToast("Chat UI", value and "Chat hidden locally." or "Chat visibility restored.")
    end, "Hides only the local Roblox Chat CoreGui; it does not affect other players.")
    addToggle("Hide Player List UI", state.hiddenCoreGui.PlayerList, function(value)
        setCoreGuiHidden(Enum.CoreGuiType.PlayerList, value, "PlayerList")
        showToast("Player List UI", value and "Player list hidden locally." or "Player list visibility restored.")
    end, "Hides only the local Roblox PlayerList CoreGui; it does not affect server player data.")
    addSlider("Glass transparency (%)", 8, 30, math.floor(state.glassOpacity * 100 + 0.5), function(value)
        state.glassOpacity = value / 100
        root.BackgroundTransparency = state.glassOpacity
    end)
    addButton("Reset appearance", function()
        state.theme = CONFIG.DefaultTheme
        state.scale = CONFIG.DefaultScale
        state.glassOpacity = 0.16
        state.reduceMotion = false
        state.liveRefresh = true
        for tabName in pairs(state.monitorEnabled) do state.monitorEnabled[tabName] = true end
        root.Size = UDim2.fromScale(0.76, 0.69)
        root.BackgroundTransparency = state.glassOpacity
        applyTheme()
        showToast("Appearance reset", "Default session appearance restored.")
        showTab("Settings")
    end)
    addCard("Session-only settings", "A LocalScript cannot save settings across sessions by itself. Add a server-authorized DataStore flow if you own the experience and need persistence.")
end

pages.About = function()
    addCard("Meizu Hub", "Version " .. CONFIG.Version .. " • Roblox Studio LocalScript")
    addCard("Source analysis", "The reference uses a remote Banana UI library and many executor-specific calls. This implementation uses Roblox Instances and supported client APIs only.")
    addCard("Compatibility", "Designed for touch and mouse input. Actual layout and runtime behavior still need verification in Roblox Studio on the target phone.")
    addButton("Show limitation notice", function()
        showToast("Compatibility notice", "Not tested in a live Blox Fruits session or on Delta/other executors.")
    end)
    addCard("Safety boundary", "No executor API, hidden property edits, arbitrary RemoteEvent/RemoteFunction invocation, exploit teleporting, aimbot, or automated combat.")
end

--// Responsive layout
local function updateResponsiveLayout()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
    local isNarrow = viewport.X < 560
    if isNarrow then
        root.Size = UDim2.new(0.86, 0, 0.72, 0)
        sidebar.Size = UDim2.new(0, 88, 1, -20)
        content.Position = UDim2.new(0, 103, 0, 10)
        content.Size = UDim2.new(1, -113, 1, -20)
        for _, button in pairs(navButtons) do
            button.TextSize = 9
        end
    else
        root.Size = UDim2.new(0.76 * state.scale, 0, 0.69 * state.scale, 0)
        sidebar.Size = UDim2.new(0, 112, 1, -20)
        content.Position = UDim2.new(0, 132, 0, 10)
        content.Size = UDim2.new(1, -142, 1, -20)
        for _, button in pairs(navButtons) do
            button.TextSize = 10
        end
    end
    local insetTopLeft, insetBottomRight = GuiService:GetGuiInset()
    local safeWidth = math.max(240, viewport.X - 16)
    local safeHeight = math.max(280, viewport.Y - insetTopLeft.Y - insetBottomRight.Y - 16)
    rootSizeConstraint.MinSize = Vector2.new(math.min(300, safeWidth), math.min(360, safeHeight))
    rootSizeConstraint.MaxSize = Vector2.new(math.min(760, safeWidth), math.min(720, safeHeight))
    local absSize = root.AbsoluteSize
    if absSize.X > safeWidth then root.Size = UDim2.new(0, safeWidth, root.Size.Y.Scale, root.Size.Y.Offset) end
    if absSize.Y > safeHeight then root.Size = UDim2.new(root.Size.X.Scale, root.Size.X.Offset, 0, safeHeight) end

    local iconPos, iconSize = reopenButton.AbsolutePosition, reopenButton.AbsoluteSize
    local x, y
    if not state.floatingMoved then
        x = math.max(6, viewport.X - iconSize.X - 18)
        y = math.max(insetTopLeft.Y + 6, viewport.Y - iconSize.Y - 28)
    else
        x = math.clamp(iconPos.X, 6, math.max(6, viewport.X - iconSize.X - 6))
        y = math.clamp(iconPos.Y, insetTopLeft.Y + 6, math.max(insetTopLeft.Y + 6, viewport.Y - iconSize.Y - 6))
    end
    reopenButton.AnchorPoint = Vector2.new(0, 0)
    reopenButton.Position = UDim2.fromOffset(x, y)
end

local cameraViewportConnection
local function bindCurrentCamera()
    if cameraViewportConnection then cameraViewportConnection:Disconnect(); cameraViewportConnection = nil end
    local camera = Workspace.CurrentCamera
    if camera then
        cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
        trackConnection(cameraViewportConnection)
    end
    updateResponsiveLayout()
end
trackConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCurrentCamera))
bindCurrentCamera()

trackConnection(Players.PlayerAdded:Connect(function()
    state.lastSnapshot.PlayerCount = #Players:GetPlayers()
end))
trackConnection(Players.PlayerRemoving:Connect(function()
    state.lastSnapshot.PlayerCount = #Players:GetPlayers()
end))

local function bindCharacter(character)
    disconnectBucket(state.characterConnections)
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
    if humanoid and humanoid:IsA("Humanoid") then
        trackConnection(humanoid.HealthChanged:Connect(function()
            state.lastSnapshot.Health = humanoid.Health
        end), state.characterConnections)
        trackConnection(humanoid.Died:Connect(function()
            state.lastSnapshot.CharacterState = "Down"
        end), state.characterConnections)
    end
end

trackConnection(LocalPlayer.CharacterAdded:Connect(bindCharacter))
trackConnection(LocalPlayer.CharacterRemoving:Connect(function()
    disconnectBucket(state.characterConnections)
    state.lastSnapshot.CharacterState = "Respawning"
end))
if LocalPlayer.Character then
    bindCharacter(LocalPlayer.Character)
end

-- Reapply local visual overrides at a low rate in case the experience updates Lighting.
task.spawn(function()
    while not state.destroyed and screenGui.Parent do
        task.wait(1)
        if state.destroyed then break end
        safeCall("local visual override refresh", reapplyLocalOverrides)
    end
end)

-- Refresh Home and Player observations at a controlled rate, not every render frame.
task.spawn(function()
    while not state.destroyed and screenGui.Parent do
        task.wait(CONFIG.RefreshInterval)
        if state.destroyed then break end
        local tab = state.currentTab
        if state.liveRefresh and state.monitorEnabled[tab] then
            safeCall("periodic status refresh", function()
                if tab == "Home" or tab == "Player" then
                    local stats = getCharacterStats()
                    state.lastSnapshot = {CharacterState=stats.status, Health=stats.health, WalkSpeed=stats.speed, JumpPower=stats.jump, PlayerCount=#Players:GetPlayers()}
                end
                local refreshVisible = state.pageRefreshers[tab]
                if refreshVisible then refreshVisible() end
            end)
        end
    end
end)

-- Initial layout and page.
state.menuVisible = true
state.minimized = false
root.Visible = true
reopenButton.Visible = true
updateResponsiveLayout()
showTab("Home")
showToast("Meizu Hub ready", "Tap the floating M icon to hide or reopen the menu.")
