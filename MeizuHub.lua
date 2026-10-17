--[[
    MEIZU HUB
    Version: 0.1.0
    Purpose: Mobile-first Blox Fruits companion UI scaffold.

    Compatibility:
    - Intended for a Roblox experience you own or are authorized to develop.
    - Uses standard Roblox client APIs; it is not an executor exploit script.
    - Automated farming, arbitrary teleporting, and server-hopping are intentionally
      not implemented here. Add game-specific behavior in an authorized Studio project.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[Meizu Hub] LocalPlayer unavailable; run this as a LocalScript.")
    return
end

local VERSION = "0.1.0"
local GUI_NAME = "MeizuHubGui"
local ACCENT = Color3.fromRGB(82, 132, 255)
local BG = Color3.fromRGB(15, 18, 28)
local PANEL = Color3.fromRGB(23, 27, 41)
local TEXT = Color3.fromRGB(239, 242, 255)
local MUTED = Color3.fromRGB(151, 160, 184)

local function safeDestroyOldGui()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end
    local old = playerGui:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end

safeDestroyOldGui()

local state = {
    running = true,
    minimized = false,
    activeTab = "HOME",
    notifications = true,
    animations = true,
    accent = ACCENT,
    connections = {},
    startedAt = os.clock(),
    logs = {},
    toggles = {},
}

local function log(message)
    local entry = os.date("%H:%M:%S") .. "  " .. tostring(message)
    table.insert(state.logs, 1, entry)
    while #state.logs > 8 do table.remove(state.logs) end
    print("[Meizu Hub] " .. tostring(message))
end

local function addConnection(connection)
    table.insert(state.connections, connection)
    return connection
end

local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local gui = make("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local root = make("Frame", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0.92, 0, 0.72, 0),
    BackgroundColor3 = BG,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 16)}, root)
make("UIStroke", {Color = ACCENT, Transparency = 0.55, Thickness = 1.2}, root)
make("UISizeConstraint", {
    MinSize = Vector2.new(290, 300),
    MaxSize = Vector2.new(720, 560),
}, root)

local scale = make("UIScale", {Scale = 1}, root)
local function updateScale()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    scale.Scale = math.clamp(math.min(viewport.X / 430, viewport.Y / 420), 0.72, 1)
end
updateScale()
if workspace.CurrentCamera then
    addConnection(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
end

local header = make("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0,
}, root)
make("UICorner", {CornerRadius = UDim.new(0, 16)}, header)
make("Frame", {
    Position = UDim2.new(0, 0, 1, -12),
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0,
}, header)

make("TextLabel", {
    Name = "Brand",
    Position = UDim2.new(0, 14, 0, 0),
    Size = UDim2.new(0.6, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "MEIZU HUB",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)
make("TextLabel", {
    Position = UDim2.new(0, 14, 0, 29),
    Size = UDim2.new(0.5, 0, 0, 13),
    BackgroundTransparency = 1,
    Text = "BLOX FRUITS  •  v" .. VERSION,
    TextColor3 = MUTED,
    Font = Enum.Font.Gotham,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local minimizeButton = make("TextButton", {
    Name = "Minimize",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -48, 0.5, 0),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = Color3.fromRGB(44, 51, 72),
    Text = "—",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    AutoButtonColor = true,
}, header)
make("UICorner", {CornerRadius = UDim.new(0, 9)}, minimizeButton)

local closeButton = make("TextButton", {
    Name = "Close",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = Color3.fromRGB(145, 53, 73),
    Text = "×",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    AutoButtonColor = true,
}, header)
make("UICorner", {CornerRadius = UDim.new(0, 9)}, closeButton)

local body = make("Frame", {
    Position = UDim2.new(0, 0, 0, 48),
    Size = UDim2.new(1, 0, 1, -48),
    BackgroundTransparency = 1,
}, root)

local nav = make("ScrollingFrame", {
    Name = "Navigation",
    Position = UDim2.new(0, 8, 0, 8),
    Size = UDim2.new(0, 104, 1, -16),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    CanvasSize = UDim2.new(0, 0, 0, 0),
}, body)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, nav)
local navLayout = make("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, nav)
make("UIPadding", {
    PaddingTop = UDim.new(0, 8),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
}, nav)

local content = make("Frame", {
    Name = "Content",
    Position = UDim2.new(0, 120, 0, 8),
    Size = UDim2.new(1, -128, 1, -16),
    BackgroundTransparency = 1,
}, body)

local pageTitle = make("TextLabel", {
    Name = "PageTitle",
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    Text = "HOME",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local pageScroll = make("ScrollingFrame", {
    Name = "PageScroll",
    Position = UDim2.new(0, 0, 0, 32),
    Size = UDim2.new(1, 0, 1, -32),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.new(0, 0, 0, 0),
}, content)
local pageLayout = make("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, pageScroll)
make("UIPadding", {
    PaddingTop = UDim.new(0, 2),
    PaddingBottom = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 5),
}, pageScroll)

local function updateCanvas(frame, layout)
    frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
end
addConnection(navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    updateCanvas(nav, navLayout)
end))
addConnection(pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    updateCanvas(pageScroll, pageLayout)
end))

local function notify(message)
    log(message)
    if not state.notifications then return end
    local toast = make("TextLabel", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, -12),
        Size = UDim2.new(0.72, 0, 0, 38),
        BackgroundColor3 = PANEL,
        TextColor3 = TEXT,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        Text = tostring(message),
        TextWrapped = true,
        ZIndex = 20,
    }, gui)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, toast)
    make("UIStroke", {Color = state.accent, Transparency = 0.35}, toast)
    if state.animations then
        toast.BackgroundTransparency = 1
        toast.TextTransparency = 1
        TweenService:Create(toast, TweenInfo.new(0.18), {
            BackgroundTransparency = 0,
            TextTransparency = 0,
        }):Play()
    end
    task.delay(2.5, function()
        if toast.Parent then toast:Destroy() end
    end)
end

local function clearPage()
    for _, child in ipairs(pageScroll:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end

local function section(title)
    return make("TextLabel", {
        Size = UDim2.new(1, -2, 0, 25),
        BackgroundTransparency = 1,
        Text = string.upper(title),
        TextColor3 = state.accent,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, pageScroll)
end

local function card(title, description)
    local frame = make("Frame", {
        Size = UDim2.new(1, -2, 0, description and 62 or 44),
        BackgroundColor3 = PANEL,
        BorderSizePixel = 0,
    }, pageScroll)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, frame)
    make("TextLabel", {
        Position = UDim2.new(0, 10, 0, description and 7 or 0),
        Size = UDim2.new(1, -20, 0, 22),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = TEXT,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)
    if description then
        make("TextLabel", {
            Position = UDim2.new(0, 10, 0, 29),
            Size = UDim2.new(1, -20, 0, 26),
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = MUTED,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        }, frame)
    end
    return frame
end

local function addButton(title, callback)
    local button = make("TextButton", {
        Size = UDim2.new(1, -2, 0, 38),
        BackgroundColor3 = state.accent,
        Text = title,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = true,
    }, pageScroll)
    make("UICorner", {CornerRadius = UDim.new(0, 9)}, button)
    addConnection(button.Activated:Connect(function()
        local ok, err = pcall(callback)
        if not ok then
            notify("Lỗi thao tác: " .. tostring(err))
        end
    end))
    return button
end

local function addToggle(title, description, initial, callback)
    local frame = make("Frame", {
        Size = UDim2.new(1, -2, 0, description and 62 or 46),
        BackgroundColor3 = PANEL,
        BorderSizePixel = 0,
    }, pageScroll)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, frame)
    make("TextLabel", {
        Position = UDim2.new(0, 10, 0, 4),
        Size = UDim2.new(1, -68, 0, 22),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = TEXT,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)
    if description then
        make("TextLabel", {
            Position = UDim2.new(0, 10, 0, 27),
            Size = UDim2.new(1, -68, 0, 28),
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = MUTED,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        }, frame)
    end
    local button = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(42, 24),
        BackgroundColor3 = initial and state.accent or Color3.fromRGB(63, 69, 88),
        Text = initial and "ON" or "OFF",
        TextColor3 = TEXT,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        AutoButtonColor = true,
    }, frame)
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, button)
    state.toggles[title] = initial == true
    addConnection(button.Activated:Connect(function()
        local newValue = not state.toggles[title]
        state.toggles[title] = newValue
        button.Text = newValue and "ON" or "OFF"
        button.BackgroundColor3 = newValue and state.accent or Color3.fromRGB(63, 69, 88)
        local ok, err = pcall(callback, newValue)
        if not ok then
            state.toggles[title] = not newValue
            button.Text = state.toggles[title] and "ON" or "OFF"
            button.BackgroundColor3 = state.toggles[title] and state.accent or Color3.fromRGB(63, 69, 88)
            notify("Không thể đổi trạng thái: " .. tostring(err))
        end
    end))
    return frame
end

local pages = {}
local function currentCharacter()
    return LocalPlayer.Character
end
local function getHumanoid()
    local character = currentCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end
local function getRootPart()
    local character = currentCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

pages.HOME = function()
    section("Welcome back")
    card("MEIZU HUB  •  v" .. VERSION, "Mobile-first companion interface. Các chức năng chưa được tích hợp sẽ được ghi rõ.")
    local humanoid = getHumanoid()
    local rootPart = getRootPart()
    card("Player", "Tên: " .. LocalPlayer.Name .. "  |  UserId: " .. tostring(LocalPlayer.UserId))
    card("Character", humanoid and ("Health: " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth) .. "  •  Energy: " .. math.floor(humanoid.WalkSpeed)) or "N/A — nhân vật chưa tải.")
    card("Position", rootPart and tostring(rootPart.Position) or "N/A")
    card("Session uptime", tostring(math.floor(os.clock() - state.startedAt)) .. " giây")
    addButton("Làm mới thông tin nhân vật", function()
        notify("Thông tin nhân vật đã được cập nhật.")
        renderTab("HOME")
    end)
    section("Recent activity")
    for _, entry in ipairs(state.logs) do card(entry) end
end

pages.MAIN = function()
    section("Character & gameplay")
    card("Feature status", "Các mục dưới đây chỉ là trạng thái UI/công cụ đọc dữ liệu; chưa tự động điều khiển Blox Fruits.")
    addToggle("Theo dõi chỉ số", "Làm mới dữ liệu khi mở lại tab; không tự farm.", false, function(enabled)
        notify(enabled and "Đã bật theo dõi thủ công." or "Đã tắt theo dõi thủ công.")
    end)
    addButton("Đọc cấp độ / chỉ số", function()
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if not leaderstats then
            notify("Không tìm thấy leaderstats — N/A.")
            return
        end
        local found = {}
        for _, value in ipairs(leaderstats:GetChildren()) do
            if value:IsA("ValueBase") then
                table.insert(found, value.Name .. "=" .. tostring(value.Value))
            end
        end
        notify(#found > 0 and table.concat(found, " • ") or "Không có chỉ số đọc được.")
    end)
    card("Automation", "Tự farm, combat automation và exploit gameplay không được triển khai trong scaffold này.")
end

pages.FARM = function()
    section("Farm controller")
    card("Status", "IDLE — không có tác vụ farm đang chạy.")
    addButton("Start", function()
        notify("Chưa có bộ điều khiển farm được triển khai. Không có tác vụ nào được khởi chạy.")
    end)
    addButton("Stop", function()
        notify("Không có tác vụ farm nào đang chạy.")
    end)
    card("Safety", "Không có vòng lặp nền hoặc tự động đánh quái trong bản này.")
end

pages.TELEPORT = function()
    section("Navigation")
    card("Teleport", "Teleport đến tọa độ/địa điểm Blox Fruits chưa được tích hợp vì cần dữ liệu đã xác minh và cơ chế được phép.")
    addButton("Hiển thị vị trí hiện tại", function()
        local part = getRootPart()
        notify(part and tostring(part.Position) or "Vị trí: N/A")
    end)
    addButton("Làm mới nhân vật", function()
        local character = currentCharacter()
        notify(character and ("Character: " .. character.Name) or "Nhân vật chưa tải.")
    end)
end

pages.PLAYER = function()
    section("Live player data")
    local humanoid = getHumanoid()
    local rootPart = getRootPart()
    card("Level", "Đang dò leaderstats; nếu game không cung cấp dữ liệu thì hiển thị N/A.")
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local levelText = "N/A"
    if leaderstats then
        for _, item in ipairs(leaderstats:GetChildren()) do
            if item.Name:lower():find("level") and item:IsA("ValueBase") then
                levelText = tostring(item.Value)
                break
            end
        end
    end
    card("Level value", levelText)
    card("Health", humanoid and (math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)) or "N/A")
    card("WalkSpeed", humanoid and tostring(humanoid.WalkSpeed) or "N/A")
    card("Position", rootPart and string.format("%.1f, %.1f, %.1f", rootPart.Position.X, rootPart.Position.Y, rootPart.Position.Z) or "N/A")
    addButton("Refresh", function()
        notify("Đã yêu cầu cập nhật dữ liệu.")
        renderTab("PLAYER")
    end)
end

pages.SERVER = function()
    section("Current session")
    local players = Players:GetPlayers()
    card("Place ID", tostring(game.PlaceId))
    card("Players", tostring(#players) .. (Players.MaxPlayers and ("/" .. tostring(Players.MaxPlayers)) or ""))
    card("Job ID", game.JobId ~= "" and game.JobId or "N/A")
    addButton("Copy session info", function()
        local info = "PlaceId=" .. tostring(game.PlaceId) .. "\nJobId=" .. tostring(game.JobId) .. "\nPlayers=" .. tostring(#Players:GetPlayers())
        if typeof(setclipboard) == "function" then
            setclipboard(info)
            notify("Đã sao chép thông tin phiên.")
        else
            notify("Clipboard API không có sẵn. Thông tin: " .. info)
        end
    end)
    card("Server hopping", "Chưa triển khai; không tự chuyển server hoặc tạo vòng lặp chuyển server.")
end

pages.SETTINGS = function()
    section("Appearance")
    addToggle("Animations", "Bật/tắt tween thông báo.", state.animations, function(value)
        state.animations = value
        notify("Animations: " .. (value and "ON" or "OFF"))
    end)
    addToggle("Notifications", "Bật/tắt thông báo nổi.", state.notifications, function(value)
        state.notifications = value
        if value then notify("Thông báo đã bật.") end
    end)
    addButton("Accent: Blue", function()
        state.accent = Color3.fromRGB(82, 132, 255)
        notify("Đã chọn màu xanh.")
        renderTab("SETTINGS")
    end)
    addButton("Accent: Purple", function()
        state.accent = Color3.fromRGB(166, 105, 255)
        notify("Đã chọn màu tím.")
        renderTab("SETTINGS")
    end)
    addButton("Restore defaults", function()
        state.animations = true
        state.notifications = true
        state.accent = ACCENT
        notify("Đã khôi phục tùy chọn mặc định.")
        renderTab("SETTINGS")
    end)
    addButton("Export config JSON", function()
        local config = {
            version = VERSION,
            animations = state.animations,
            notifications = state.notifications,
            accent = {state.accent.R, state.accent.G, state.accent.B},
        }
        notify(HttpService:JSONEncode(config))
    end)
    card("Persistence", "Bản này chưa ghi file cấu hình vì Roblox client tiêu chuẩn không có API lưu file tùy ý.")
end

pages.ABOUT = function()
    section("About")
    card("MEIZU HUB", "Version " .. VERSION)
    card("Author", "Meizu Hub community build")
    card("Compatibility", "LocalScript trong Roblox Studio/experience được phép. Không đảm bảo tương thích executor.")
    card("Libraries", "Roblox Instance, Players, TweenService, UserInputService, RunService, HttpService.")
    card("Changelog", "0.1.0 — mobile-first UI, tabs, player/session info, notifications, theme settings.")
    card("Limitations", "Không có auto farm, combat exploit, arbitrary teleport, hoặc server-hop.")
end

local tabNames = {"HOME", "MAIN", "FARM", "TELEPORT", "PLAYER", "SERVER", "SETTINGS", "ABOUT"}
local tabButtons = {}

function renderTab(tabName)
    if not pages[tabName] then return end
    state.activeTab = tabName
    pageTitle.Text = tabName
    clearPage()
    local ok, err = pcall(pages[tabName])
    if not ok then
        card("Tab error", tostring(err))
        log("Tab " .. tabName .. " failed: " .. tostring(err))
    end
    for name, button in pairs(tabButtons) do
        button.BackgroundColor3 = name == tabName and state.accent or Color3.fromRGB(37, 43, 61)
        button.TextColor3 = TEXT
    end
end

for index, tabName in ipairs(tabNames) do
    local button = make("TextButton", {
        Name = "Tab_" .. tabName,
        LayoutOrder = index,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(37, 43, 61),
        Text = tabName,
        TextColor3 = TEXT,
        Font = Enum.Font.GothamSemibold,
        TextSize = 10,
        AutoButtonColor = true,
    }, nav)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, button)
    tabButtons[tabName] = button
    addConnection(button.Activated:Connect(function()
        renderTab(tabName)
    end))
end

local reopenButton = make("TextButton", {
    Name = "Reopen",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.fromOffset(54, 54),
    BackgroundColor3 = ACCENT,
    Text = "M",
    TextColor3 = TEXT,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    Visible = false,
    ZIndex = 30,
}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, reopenButton)
make("UIStroke", {Color = TEXT, Transparency = 0.65, Thickness = 1}, reopenButton)

local function setMinimized(value)
    state.minimized = value
    root.Visible = not value
    reopenButton.Visible = value
end
addConnection(minimizeButton.Activated:Connect(function() setMinimized(true) end))
addConnection(reopenButton.Activated:Connect(function() setMinimized(false) end))

local dragging = false
local dragStart, startPosition
addConnection(header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = root.Position
    end
end))
addConnection(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        root.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
end))
addConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

local function cleanup()
    if not state.running then return end
    state.running = false
    for _, connection in ipairs(state.connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(state.connections)
    if gui then gui:Destroy() end
end
addConnection(closeButton.Activated:Connect(function()
    cleanup()
end))

addConnection(Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then cleanup() end
end))

log("UI initialized.")
renderTab("HOME")
