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
    glassOpacity = 0.16,
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
    "Home", "Farming", "Bosses", "Quests", "Raids", "Sea Events", "Player", "Settings", "About",
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
    state.currentTab = tabName
    pageHeading.Text = tabName
    clearPage()
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

--// Tabs
pages.Home = function()
    addCard("Welcome back", "Meizu Hub is a read-only companion UI. It does not automate combat, farming, or server remotes.")
    local playerCard, playerText = addStatusCard("Player status", "Reading current character…")
    local serverCard, serverText = addStatusCard("Session", "Reading current session…")
    local worldCard, worldText = addStatusCard("World observations", "Scanning visible workspace objects…")
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
    end
    state.pageRefreshers.Home = refreshHomeStatus
    addButton("Refresh status now", function()
        refreshHomeStatus()
        showToast("Status refreshed", "Values were read from the current client.")
    end)
    refreshHomeStatus()
    addCard("Quick note", "If a Blox Fruits object is streamed out or its internal name differs, the tracker may not see it. Not found does not prove an event is inactive.")
end

pages.Farming = function()
    addCard("Farming utilities", "The source script contains extensive auto-farm, bring-mob, mastery and chest automation. Those exploit-style actions are intentionally not reproduced.")
    addCard("Safe alternative: character monitor", "Use Home to read the actual health, walk speed and jump power of your current character. Values update after respawn.")
    addButton("Open Home status", function() showTab("Home") end)
    addCard("Not implemented", "Auto Farm Level, Auto Farm Nearest, chest farming, berry farming, mob pulling, auto mastery, kill aura and fast attack require unauthorized automation or game-specific remote behavior.")
end

pages.Bosses = function()
    addCard("Boss observer", "Read-only scan of visible Workspace instances with common boss names. The client may not have all NPCs streamed in.")
    for _, name in ipairs({"Cake Prince", "Dough King", "Rip Indra", "Soul Reaper", "Tyrant of the Skies", "Terrorshark", "Leviathan"}) do
        local object = findObservedInstance(name)
        addCard(name, object and ("Visible: " .. object:GetFullName()) or "Not visible to this client")
    end
    addButton("Rescan visible bosses", function()
        showTab("Bosses")
        showToast("Boss scan complete", "Only locally visible instances were checked.")
    end)
end

pages.Quests = function()
    addCard("Quest status", "Quest completion and progression are controlled by the game server. This LocalScript does not invoke quest remotes or auto-complete quests.")
    local character = LocalPlayer.Character
    local questUI = PlayerGui:FindFirstChild("Main")
    addCard("Client UI", questUI and "A PlayerGui child named Main is present; its contents are not assumed." or "No PlayerGui child named Main was found.")
    addButton("Refresh quest observation", function()
        local found = PlayerGui:FindFirstChild("Main")
        showToast("Quest observation", found and "Main UI container exists; inspect it in Studio to map your own game's quest UI." or "Quest UI container not found.")
    end)
end

pages.Raids = function()
    addCard("Raid observer", "Raid start, chip purchase, dungeon completion, awakening, Law raid and exit teleport actions from the source rely on game-specific server remotes and are not run here.")
    local raidNames = {"Raid", "RaidIsland", "Dungeon", "Microchip", "Awakening"}
    for _, name in ipairs(raidNames) do
        local object = findObservedInstance(name)
        addCard(name, object and ("Visible instance: " .. object:GetFullName()) or "No matching visible instance")
    end
end

pages["Sea Events"] = function()
    addCard("Sea event observer", "This page only checks whether common sea-event names are visible in the local Workspace.")
    for _, name in ipairs({"Terrorshark", "Sea Beast", "Leviathan", "Fish Boat", "Pirate Grand Brigade", "KitsuneIsland", "Frozen Dimension"}) do
        local object = findObservedInstance(name)
        addCard(name, object and ("Visible: " .. object:GetFullName()) or "Not visible to this client")
    end
    addCard("Not implemented", "Auto-sail, ship noclip, boat speed manipulation, sea-event combat and Azure Ember automation are not included.")
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
    addSlider("Glass transparency (%)", 8, 30, math.floor(state.glassOpacity * 100 + 0.5), function(value)
        state.glassOpacity = value / 100
        root.BackgroundTransparency = state.glassOpacity
    end)
    addButton("Reset appearance", function()
        state.theme = CONFIG.DefaultTheme
        state.scale = CONFIG.DefaultScale
        state.glassOpacity = 0.16
        state.reduceMotion = false
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

-- Refresh Home and Player observations at a controlled rate, not every render frame.
task.spawn(function()
    while not state.destroyed and screenGui.Parent do
        task.wait(CONFIG.RefreshInterval)
        if state.destroyed then break end
        if state.currentTab == "Home" or state.currentTab == "Player" then
            safeCall("periodic status refresh", function()
                local stats = getCharacterStats()
                state.lastSnapshot = {
                    CharacterState = stats.status,
                    Health = stats.health,
                    WalkSpeed = stats.speed,
                    JumpPower = stats.jump,
                    PlayerCount = #Players:GetPlayers(),
                }
                local refreshVisible = state.pageRefreshers[state.currentTab]
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
