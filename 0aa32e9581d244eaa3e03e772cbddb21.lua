--[[
================================================================================
  MEIZU HUB  v2.0.0  (single-file build)  —  Liquid Glass · mobile-first
  Roblox Luau script hub · target: Blox Fruits · rebuilt from analysis of
  "crackedbananahub.txt" (structure/feature inventory only — no code copied).
  - UI library in reference is REMOTE (loadstring GitHub) and is NOT used here.
  - All cheat automation (auto-farm/quest/boss/aimbot) is LOCKED by design.
  - Implemented features use only standard Roblox APIs (+ probed executor APIs
    with graceful fallback). No remote code, no data collection, no fake data.
================================================================================
  Modules (single file, logically separated):
    1. Bootstrap & single-instance guard
    2. Utils            3. Compatibility      4. Config (+ waypoints)
    5. Logger           6. Notifications      7. PlayerInfo
    8. UI Components (glass-styled: Toggle/Slider/Dropdown/TextInput/Button/
       ProgressBar/Section/InfoRow/LockedToggle)
    9. Window (drag/resize/minimize/overlay/modal/tabs)
   10. TaskManager      11. Real feature modules: SeaEvents, BossTracker, ServerHop
   12. Tabs: Home/Farming/Bosses/Quests/Raids/SeaEvents/Player/Teleport/Server/Settings/About
   13. Boot & cleanup
================================================================================
]]

--!nocheck
local VERSION = "2.0.0"
local PRODUCT = "Meizu Hub"
local START_TIME = tick()

--------------------------------------------------------------------------------
-- 1. BOOTSTRAP & SINGLE-INSTANCE GUARD
--------------------------------------------------------------------------------
local function safeGlobal(name)
	local ok, val = pcall(function() return getfenv()[name] end)
	if ok and val ~= nil then return val end
	local ok2, val2 = pcall(function() return _G[name] end)
	if ok2 and val2 ~= nil then return val2 end
	return nil
end
do
	local function kill(o) if o and o.Destroy then pcall(function() o:Destroy() end) end end
	pcall(function()
		local gg = safeGlobal("getgenv")
		if gg and gg().MeizuHub then if gg().MeizuHub.Destroy then gg().MeizuHub:Destroy() end; gg().MeizuHub = nil end
	end)
	pcall(function()
		local hui = safeGlobal("gethui")
		if hui then local f = hui():FindFirstChild("MeizuHub_Gui"); if f then kill(f) end end
	end)
	pcall(function()
		local lp = game:GetService("Players").LocalPlayer
		if lp and lp:FindFirstChildOfClass("PlayerGui") then
			local f = lp.PlayerGui:FindFirstChild("MeizuHub_Gui"); if f then kill(f) end
		end
	end)
end

--------------------------------------------------------------------------------
-- 2. UTILS
--------------------------------------------------------------------------------
local Utils = {}
function Utils.clamp(v, lo, hi) if v < lo then return lo end; if v > hi then return hi end; return v end
function Utils.round(v, p) p = p or 0; local m = 10 ^ p; return math.floor(v * m + 0.5) / m end
function Utils.formatTime(s)
	s = math.floor(s); local h = math.floor(s / 3600); local m = math.floor((s % 3600) / 60); local sec = s % 60
	if h > 0 then return string.format("%02d:%02d:%02d", h, m, sec) end
	return string.format("%02d:%02d", m, sec)
end
function Utils.probe(name) local ok, val = pcall(function() return getfenv()[name] end); if ok and val ~= nil then return val end; return nil end
function Utils.exists(o) return o and typeof(o) == "Instance" and o.Parent ~= nil end
function Utils.Make(class, props, children)
	local inst = Instance.new(class)
	props = props or {}
	for k, v in pairs(props) do
		if k ~= "Parent" then pcall(function() inst[k] = v end) end
	end
	if children then for _, c in ipairs(children) do if c then c.Parent = inst end end end
	if props.Parent then inst.Parent = props.Parent end
	return inst
end
function Utils.tween(obj, props, dur)
	dur = dur or 0.22
	local t = game:GetService("TweenService"):Create(obj, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play(); return t
end
function Utils.hexToColor3(hex)
	hex = hex:gsub("#", "")
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16) or 56, tonumber(hex:sub(3, 4), 16) or 132, tonumber(hex:sub(5, 6), 16) or 255)
end

--------------------------------------------------------------------------------
-- 3. COMPATIBILITY
--------------------------------------------------------------------------------
local Compat = {}
Compat.cap = {
	writefile = Utils.probe("writefile") ~= nil,
	readfile = Utils.probe("readfile") ~= nil,
	isfolder = Utils.probe("isfolder") ~= nil,
	makefolder = Utils.probe("makefolder") ~= nil,
	appendfile = Utils.probe("appendfile") ~= nil,
	setclipboard = Utils.probe("setclipboard") ~= nil,
	getgenv = Utils.probe("getgenv") ~= nil,
	gethui = Utils.probe("gethui") ~= nil,
	queue_on_teleport = (Utils.probe("syn") and true) or (Utils.probe("queue_on_teleport") ~= nil),
	httpget = false,
}
pcall(function()
	game:HttpGet("https://www.google.com", true)
	Compat.cap.httpget = true
end)
function Compat.report()
	local out = {}
	for k, v in pairs(Compat.cap) do table.insert(out, { name = k, ok = v }) end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

--------------------------------------------------------------------------------
-- 4. CONFIG
--------------------------------------------------------------------------------
local Config = {}
Config.CFG = "meizuhub/config.txt"
Config.WP = "meizuhub/waypoints.txt"
Config.defaults = {
	accent = "#38BDF8", accent2 = "#8B5CF6",
	animations = true, glass = 0.55, uiScale = 1.0, notifications = true,
	windowX = 0.5, windowY = 0.5, windowW = 0.44, windowH = 0.64, minimized = false,
	seaNotify = true,
}
Config.values = {}
for k, v in pairs(Config.defaults) do Config.values[k] = v end
Config.persistent = Compat.cap.writefile and Compat.cap.readfile
function Config.ser(vals)
	local o = {}
	for k, v in pairs(vals) do
		local t = typeof(v)
		if t == "boolean" then table.insert(o, k .. "=bool:" .. tostring(v))
		elseif t == "number" then table.insert(o, k .. "=num:" .. tostring(v))
		elseif t == "string" then table.insert(o, k .. "=str:" .. v) end
	end
	return table.concat(o, "\n")
end
function Config.deser(text)
	local o = {}
	for line in (text .. "\n"):gmatch("(.-)\n") do
		local k, typ, val = line:match("^([%w_]+)=(%w+):(.*)$")
		if k and typ then
			if typ == "bool" then o[k] = (val == "true")
			elseif typ == "num" then o[k] = tonumber(val)
			elseif typ == "str" then o[k] = val end
		end
	end
	return o
end
function Config.folder()
	if not (Compat.cap.isfolder and Compat.cap.makefolder) then return false end
	local ok, is = pcall(function() return isfolder("meizuhub") end)
	if ok and not is then pcall(function() makefolder("meizuhub") end) end
	return true
end
function Config.load()
	if not Config.persistent then return false end
	Config.folder()
	local ok, text = pcall(function() return readfile(Config.CFG) end)
	if not ok or type(text) ~= "string" or text == "" then return false end
	local ok2, parsed = pcall(function() return Config.deser(text) end)
	if not ok2 then return false end
	for k, v in pairs(parsed) do
		if Config.defaults[k] ~= nil and typeof(v) == typeof(Config.defaults[k]) then Config.values[k] = v end
	end
	return true
end
function Config.save()
	if not Config.persistent then return false end
	Config.folder()
	return pcall(function() writefile(Config.CFG, Config.ser(Config.values)) end)
end
function Config.set(k, v) if Config.defaults[k] ~= nil then Config.values[k] = v end end
function Config.get(k) return Config.values[k] end
function Config.reset() for k, v in pairs(Config.defaults) do Config.values[k] = v end end
Config.waypoints = {}
function Config.loadWP()
	Config.waypoints = {}
	if not Config.persistent then return false end
	local ok, text = pcall(function() return readfile(Config.WP) end)
	if not ok then return false end
	for line in (text .. "\n"):gmatch("(.-)\n") do
		local n, x, y, z = line:match("^([^|]+)|([%-%d%.]+)|([%-%d%.]+)|([%-%d%.]+)$")
		if n then table.insert(Config.waypoints, { name = n, x = tonumber(x) or 0, y = tonumber(y) or 0, z = tonumber(z) or 0 }) end
	end
	return true
end
function Config.saveWP()
	if not Config.persistent then return false end
	Config.folder()
	local lines = {}
	for _, w in ipairs(Config.waypoints) do table.insert(lines, string.format("%s|%.2f|%.2f|%.2f", w.name, w.x, w.y, w.z)) end
	return pcall(function() writefile(Config.WP, table.concat(lines, "\n")) end)
end

--------------------------------------------------------------------------------
-- 5. LOGGER
--------------------------------------------------------------------------------
local Logger = {}
Logger.entries = {}; Logger.MAX = 120
function Logger.log(lvl, msg)
	table.insert(Logger.entries, { time = tick(), level = lvl or "info", message = tostring(msg) })
	while #Logger.entries > Logger.MAX do table.remove(Logger.entries, 1) end
	if Config.persistent and Compat.cap.appendfile then
		Config.folder()
		pcall(function() appendfile("meizuhub/log.txt", string.format("[%s] %s: %s\n", os.date("%H:%M:%S"), (lvl or "info"):upper(), tostring(msg))) end)
	end
end
function Logger.info(m) Logger.log("info", m) end
function Logger.warn(m) Logger.log("warn", m) end
function Logger.error(m) Logger.log("error", m) end
function Logger.recent(n)
	n = n or 8; local o = {}
	for i = math.max(1, #Logger.entries - n + 1), #Logger.entries do table.insert(o, Logger.entries[i]) end
	return o
end

--------------------------------------------------------------------------------
-- 6. NOTIFICATIONS (glass toasts)
--------------------------------------------------------------------------------
local Notif = { enabled = true, container = nil }
function Notif.init(parent)
	Notif.container = Utils.Make("Frame", {
		Name = "Toasts", BackgroundTransparency = 1,
		Position = UDim2.new(1, -14, 0, 14), AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0, 300, 1, -28), Parent = parent,
	}, { Utils.Make("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder }) })
end
function Notif.show(title, text, typ)
	if not Notif.enabled or not Notif.container then return end
	typ = typ or "info"
	local a = Utils.hexToColor3(Config.get("accent"))
	local bar = a
	if typ == "warn" then bar = Color3.fromRGB(255, 180, 60) end
	if typ == "error" then bar = Color3.fromRGB(255, 90, 90) end
	local t = Utils.Make("Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 24, 34), BackgroundTransparency = 0.25,
		BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 0), Parent = Notif.container,
	}, {
		Utils.Make("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Utils.Make("UIStroke", { Color = bar, Thickness = 1, Transparency = 0.55 }),
		Utils.Make("Frame", { Name = "Bar", BackgroundColor3 = bar, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0) }),
		Utils.Make("TextLabel", { Name = "T", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = title, TextColor3 = Color3.fromRGB(240, 244, 250), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -20, 0, 16) }),
		Utils.Make("TextLabel", { Name = "B", BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = text or "", TextColor3 = Color3.fromRGB(170, 178, 195), TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 28), Size = UDim2.new(1, -20, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }),
	})
	local h = math.max(16, t.B.TextBounds.Y)
	t.B.Size = UDim2.new(1, -20, 0, h)
	t.Size = UDim2.new(1, 0, 0, 36 + h)
	if Config.get("animations") then t.Position = UDim2.new(1.2, 0, 0, 0); Utils.tween(t, { Position = UDim2.new(0, 0, 0, 0) }, 0.25) else t.Position = UDim2.new(0, 0, 0, 0) end
	task.delay(4.5, function()
		if not Utils.exists(t) then return end
		if Config.get("animations") then Utils.tween(t, { Position = UDim2.new(1.2, 0, 0, 0), BackgroundTransparency = 1 }, 0.3); task.wait(0.35) end
		pcall(function() t:Destroy() end)
	end)
end

--------------------------------------------------------------------------------
-- 7. PLAYER INFO
--------------------------------------------------------------------------------
local PInfo = {}
function PInfo.get()
	local lp = game:GetService("Players").LocalPlayer
	local d = { name = "N/A", userId = "N/A", level = "N/A", health = "N/A", maxHealth = "N/A", energy = "N/A", maxEnergy = "N/A", walkSpeed = "N/A", jumpPower = "N/A", position = "N/A", hasChar = false }
	if not lp then return d end
	d.name = lp.Name; pcall(function() d.userId = tostring(lp.UserId) end)
	pcall(function()
		local ls = lp:FindFirstChild("leaderstats")
		if ls then local lv = ls:FindFirstChild("Level"); if lv then d.level = tostring(lv.Value) end end
	end)
	local char = lp.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hum then
			d.hasChar = true
			d.health = tostring(Utils.round(hum.Health, 1)); d.maxHealth = tostring(Utils.round(hum.MaxHealth, 1))
			d.walkSpeed = tostring(Utils.round(hum.WalkSpeed, 1))
			d.jumpPower = tostring(Utils.round(hum.UseJumpPower and hum.JumpPower or hum.JumpHeight, 1))
		end
		if hrp then local p = hrp.Position; d.position = string.format("%.0f, %.0f, %.0f", p.X, p.Y, p.Z) end
		pcall(function()
			local sf = char:FindFirstChild("Stats") or lp:FindFirstChild("Stats")
			if sf then
				local en = sf:FindFirstChild("Energy")
				if en then d.energy = tostring(en.Value); local mx = sf:FindFirstChild("MaxEnergy") or sf:FindFirstChild("Max Energy"); if mx then d.maxEnergy = tostring(mx.Value) end end
			end
		end)
	end
	return d
end

--------------------------------------------------------------------------------
-- 8. UI COMPONENTS (Liquid Glass)
--------------------------------------------------------------------------------
local UI = {}
UI.glass = function() return Config.get("glass") end
UI.accent = function() return Utils.hexToColor3(Config.get("accent")) end
UI.accent2 = function() return Utils.hexToColor3(Config.get("accent2")) end
UI.text = Color3.fromRGB(238, 242, 250)
UI.subtext = Color3.fromRGB(155, 163, 180)
UI.panel = Color3.fromRGB(30, 36, 50)
UI.border = Color3.fromRGB(70, 80, 105)
UI.overlayParent = nil
UI.openDropdowns = {}
function UI.closeAllDropdowns() for _, d in ipairs(UI.openDropdowns) do pcall(function() d.Close() end) end; UI.openDropdowns = {} end

function UI.Section(parent, title)
	return Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = parent }, {
		Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = title, TextColor3 = UI.accent(), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 4, 0, 6), Size = UDim2.new(1, 0, 0, 16) }),
		Utils.Make("Frame", { BackgroundColor3 = UI.border, BackgroundTransparency = 0.5, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 1), Position = UDim2.new(0, 4, 1, -4) }),
	})
end
function UI.Paragraph(parent, text, color)
	return Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = text, TextColor3 = color or UI.subtext, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent })
end
function UI.InfoRow(parent, label, value)
	local f = Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = parent })
	Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = label, TextColor3 = UI.subtext, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(0.48, 0, 1, 0), Parent = f })
	local v = Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, Text = value or "N/A", TextColor3 = UI.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.new(0.52, -12, 1, 0), Parent = f })
	return { Set = function(x) v.Text = tostring(x or "N/A") end, SetColor = function(c) v.TextColor3 = c end }
end

function UI.Toggle(parent, label, default, cb)
	local holder = Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = parent })
	local lbl = Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, Text = label, TextColor3 = UI.text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(1, -60, 1, 0), Parent = holder })
	local track = Utils.Make("TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(55, 62, 80), BackgroundTransparency = 0.2, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0, 42, 0, 22), Text = "", Parent = holder }, { Utils.Make("UICorner", { CornerRadius = UDim.new(1, 0) }), Utils.Make("UIStroke", { Color = UI.border, Thickness = 1, Transparency = 0.6 }) })
	local knob = Utils.Make("Frame", { BackgroundColor3 = Color3.fromRGB(240, 244, 250), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), Parent = track }, { Utils.Make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local state = not not default; local disabled = false
	local function render()
		local on = state
		if Config.get("animations") then
			Utils.tween(track, { BackgroundColor3 = on and UI.accent() or Color3.fromRGB(55, 62, 80) }, 0.18)
			Utils.tween(knob, { Position = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.18)
		else
			track.BackgroundColor3 = on and UI.accent() or Color3.fromRGB(55, 62, 80)
			knob.Position = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		end
	end
	render()
	local api = {}
	function api.Set(v) state = not not v; render(); if cb then pcall(cb, state) end end
	function api.Get() return state end
	function api.SetDisabled(d) disabled = d; lbl.TextColor3 = d and UI.subtext or UI.text; track.BackgroundTransparency = d and 0.6 or 0.2 end
	track.MouseButton1Click:Connect(function() if not disabled then api.Set(not state) end end)
	return api, holder
end

function UI.LockedToggle(parent, label, reason)
	local t, _ = UI.Toggle(parent, label, false, function() end)
	t.SetDisabled(true)
	UI.Paragraph(parent, "   [LOCKED] " .. reason, Color3.fromRGB(255, 170, 90))
	return t
end

function UI.Slider(parent, label, mn, mx, default, fmt, cb)
	mn = mn or 0; mx = mx or 100; default = default or mn
	local holder = Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Parent = parent })
	Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, Text = label, TextColor3 = UI.text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 6, 0, 2), Size = UDim2.new(1, -70, 0, 16), Parent = holder })
	local vlbl = Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "", TextColor3 = UI.accent(), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 2), Size = UDim2.new(0, 60, 0, 16), Parent = holder })
	local bar = Utils.Make("TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(48, 54, 72), BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 28), Size = UDim2.new(1, -12, 0, 8), Text = "", Parent = holder }, { Utils.Make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill = Utils.Make("Frame", { BackgroundColor3 = UI.accent(), BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), Parent = bar }, { Utils.Make("UICorner", { CornerRadius = UDim.new(1, 0) }), Utils.Make("UIGradient", { Color = ColorSequence.new(UI.accent(), UI.accent2()) }) })
	local value = Utils.clamp(default, mn, mx); local dragging = false; local disabled = false
	local function render()
		local pct = (value - mn) / (mx - mn)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		vlbl.Text = fmt and fmt(value) or tostring(Utils.round(value, 1))
		vlbl.TextColor3 = UI.accent()
	end
	render()
	local function upd(input)
		local rel = Utils.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		value = mn + rel * (mx - mn); render()
		if cb then pcall(cb, value) end
	end
	bar.InputBegan:Connect(function(i)
		if disabled then return end
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; upd(i) end
	end)
	local UIS = game:GetService("UserInputService")
	UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i) end end)
	UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	local api = {}
	function api.Set(v) value = Utils.clamp(v, mn, mx); render() end
	function api.Get() return value end
	function api.SetDisabled(d) disabled = d end
	return api, holder
end

function UI.Button(parent, label, cb, wscale)
	local btn = Utils.Make("TextButton", {
		AutoButtonColor = false, BackgroundColor3 = UI.panel, BackgroundTransparency = UI.glass() * 0.5,
		BorderSizePixel = 0, Font = Enum.Font.GothamSemibold, Text = label, TextColor3 = UI.text, TextSize = 13,
		Size = UDim2.new(wscale or 1, -8, 0, 38), Parent = parent,
	}, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 9) }), Utils.Make("UIStroke", { Color = UI.border, Thickness = 1, Transparency = 0.5 }) })
	local disabled = false; local accent = false
	btn.MouseButton1Click:Connect(function()
		if disabled then return end
		if Config.get("animations") then
			Utils.tween(btn, { BackgroundColor3 = accent and UI.accent2() or UI.accent() }, 0.08)
			task.delay(0.12, function() if Utils.exists(btn) then Utils.tween(btn, { BackgroundColor3 = accent and UI.accent() or UI.panel }, 0.15) end end)
		end
		if cb then pcall(cb) end
	end)
	btn.MouseEnter:Connect(function() if not disabled then Utils.tween(btn, { BackgroundTransparency = UI.glass() * 0.25 }, 0.12) end end)
	btn.MouseLeave:Connect(function() if Utils.exists(btn) then Utils.tween(btn, { BackgroundTransparency = UI.glass() * 0.5 }, 0.15) end end)
	local api = {}
	function api.SetLabel(t) btn.Text = t end
	function api.SetDisabled(d) disabled = d; btn.TextColor3 = d and UI.subtext or UI.text; btn.BackgroundTransparency = d and 0.7 or (UI.glass() * 0.5) end
	function api.SetAccent(on) accent = on; btn.BackgroundColor3 = on and UI.accent() or UI.panel; if on then btn.TextColor3 = Color3.fromRGB(255, 255, 255) end end
	return api, btn
end

function UI.TextInput(parent, label, ph, default)
	local holder = Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Parent = parent })
	Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, Text = label, TextColor3 = UI.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 6, 0, 2), Size = UDim2.new(1, -12, 0, 14), Parent = holder })
	local box = Utils.Make("TextBox", {
		BackgroundColor3 = UI.panel, BackgroundTransparency = UI.glass() * 0.5, BorderSizePixel = 0, Font = Enum.Font.Gotham,
		Text = default or "", PlaceholderText = ph or "", PlaceholderColor3 = UI.subtext, TextColor3 = UI.text, TextSize = 13,
		ClearTextOnFocus = false, Position = UDim2.new(0, 6, 0, 20), Size = UDim2.new(1, -12, 0, 28), Parent = holder,
	}, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 7) }), Utils.Make("UIStroke", { Color = UI.border, Thickness = 1, Transparency = 0.5 }) })
	box.Focused:Connect(function() Utils.tween(box, { BackgroundTransparency = UI.glass() * 0.2 }, 0.1) end)
	box.FocusLost:Connect(function() Utils.tween(box, { BackgroundTransparency = UI.glass() * 0.5 }, 0.15) end)
	local api = { Get = function() return box.Text end, Set = function(t) box.Text = t end, SetDisabled = function(d) box.TextEditable = not d end }
	return api, holder
end

function UI.Dropdown(parent, label, options, default, cb)
	options = options or {}
	local holder = Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Parent = parent })
	Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, Text = label, TextColor3 = UI.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 6, 0, 2), Size = UDim2.new(1, -12, 0, 14), Parent = holder })
	local head = Utils.Make("TextButton", {
		AutoButtonColor = false, BackgroundColor3 = UI.panel, BackgroundTransparency = UI.glass() * 0.5, BorderSizePixel = 0,
		Font = Enum.Font.Gotham, Text = default or options[1] or "—", TextColor3 = UI.text, TextSize = 13,
		Position = UDim2.new(0, 6, 0, 20), Size = UDim2.new(1, -12, 0, 30), Parent = holder,
	}, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 7) }), Utils.Make("UIStroke", { Color = UI.border, Thickness = 1, Transparency = 0.5 }) })
	Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "▾", TextColor3 = UI.subtext, TextSize = 14, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), Parent = head })
	local list = Utils.Make("ScrollingFrame", {
		BackgroundTransparency = 0.4, BackgroundColor3 = Color3.fromRGB(16, 20, 30), BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 1, 2), Size = UDim2.new(1, -12, 0, 0), Visible = false,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y,
		ScrollBarThickness = 4, ScrollBarImageColor3 = UI.subtext, ZIndex = 40, Parent = holder,
	}, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 7) }), Utils.Make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local current = default or options[1]; local open = false; local disabled = false; local btns = {}; local api = {}
	local function close()
		open = false
		if Config.get("animations") then
			Utils.tween(list, { Size = UDim2.new(1, -12, 0, 0) }, 0.15)
			task.delay(0.16, function()
				if Utils.exists(list) then
					list.Visible = false
					if UI.overlayParent and list.Parent == UI.overlayParent then list.Parent = holder; list.Position = UDim2.new(0, 6, 1, 2) end
				end
			end)
		else
			list.Visible = false; list.Size = UDim2.new(1, -12, 0, 0)
			if UI.overlayParent and list.Parent == UI.overlayParent then list.Parent = holder; list.Position = UDim2.new(0, 6, 1, 2) end
		end
		local cl = {}; for _, d in ipairs(UI.openDropdowns) do if d ~= api then table.insert(cl, d) end end; UI.openDropdowns = cl
	end
	local function build()
		for _, b in ipairs(btns) do pcall(function() b:Destroy() end) end
		btns = {}
		for i, opt in ipairs(options) do
			local b = Utils.Make("TextButton", {
				AutoButtonColor = false, BackgroundColor3 = UI.panel, BackgroundTransparency = 0.3, BorderSizePixel = 0,
				Font = Enum.Font.Gotham, Text = "  " .. tostring(opt), TextColor3 = (tostring(opt) == tostring(current)) and UI.accent() or UI.text,
				TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i, ZIndex = 41, Parent = list,
			})
			b.MouseButton1Click:Connect(function() current = opt; head.Text = tostring(opt); close(); if cb then pcall(cb, opt) end end)
			table.insert(btns, b)
		end
	end
	build()
	head.MouseButton1Click:Connect(function()
		if disabled then return end
		if open then close(); return end
		UI.closeAllDropdowns()
		open = true; table.insert(UI.openDropdowns, api); list.Visible = true
		local h = math.min(#options * 28, 140)
		if UI.overlayParent then
			list.Parent = UI.overlayParent
			local ap = holder.AbsolutePosition; local aw = holder.AbsoluteSize.X
			list.Position = UDim2.fromOffset(ap.X + 6, ap.Y + holder.AbsoluteSize.Y + 2)
			list.Size = UDim2.fromOffset(aw - 12, h)
		elseif Config.get("animations") then
			Utils.tween(list, { Size = UDim2.new(1, -12, 0, h) }, 0.18)
		else
			list.Size = UDim2.new(1, -12, 0, h)
		end
	end)
	function api.Set(opt) current = opt; head.Text = tostring(opt); build() end
	function api.Get() return current end
	function api.Refresh(opts)
		options = opts
		if not table.find(options, current) then current = options[1]; head.Text = tostring(current or "—") end
		build()
	end
	function api.SetDisabled(d) disabled = d end
	api.Close = close
	return api, holder
end

function UI.ProgressBar(parent, label)
	local holder = Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = parent })
	local lbl = Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamSemibold, Text = label or "", TextColor3 = UI.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 6, 0, 2), Size = UDim2.new(1, -12, 0, 14), Parent = holder })
	local bar = Utils.Make("Frame", { BackgroundColor3 = Color3.fromRGB(48, 54, 72), BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 22), Size = UDim2.new(1, -12, 0, 10), Parent = holder }, { Utils.Make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill = Utils.Make("Frame", { BackgroundColor3 = UI.accent(), BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), Parent = bar }, { Utils.Make("UICorner", { CornerRadius = UDim.new(1, 0) }), Utils.Make("UIGradient", { Color = ColorSequence.new(UI.accent(), UI.accent2()) }) })
	return { Set = function(p) p = Utils.clamp(p, 0, 1); fill.Size = UDim2.new(p, 0, 1, 0) end, SetLabel = function(t) lbl.Text = t end }
end

--------------------------------------------------------------------------------
-- 9. WINDOW (Liquid Glass)
--------------------------------------------------------------------------------
local Window = { conns = {}, tabs = {}, current = nil, modalOpen = false }
function Window.connect(sig, fn) local c = sig:Connect(fn); table.insert(Window.conns, c); return c end

function Window.init()
	local Players = game:GetService("Players"); local lp = Players.LocalPlayer; local UIS = game:GetService("UserInputService")
	local parentGui
	if Compat.cap.gethui then local ok, h = pcall(function() return gethui() end); if ok and h then parentGui = h end end
	if not parentGui then parentGui = lp:WaitForChild("PlayerGui", 10) or lp.PlayerGui end

	local screen = Utils.Make("ScreenGui", { Name = "MeizuHub_Gui", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parentGui })
	Window.screen = screen
	UI.overlayParent = Utils.Make("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 30, Parent = screen })

	local vp = workspace.CurrentCamera.ViewportSize
	Window.mobile = UIS.TouchEnabled or math.min(vp.X, vp.Y) < 700
	Window.sideW = Window.mobile and 50 or 148
	local topInset = 0; pcall(function() topInset = game:GetService("GuiService"):GetGuiInset().Y end)

	Notif.init(screen)

	local glass = Config.get("glass")
	local main = Utils.Make("Frame", {
		Name = "Main", BackgroundColor3 = Color3.fromRGB(18, 22, 32), BackgroundTransparency = glass,
		BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), ClipsDescendants = true,
		Position = UDim2.new(Config.get("windowX"), 0, Config.get("windowY"), 0),
		Size = UDim2.new(Window.mobile and 0.94 or Config.get("windowW"), 0, Window.mobile and 0.88 or Config.get("windowH"), 0),
		Visible = not Config.get("minimized"), Parent = screen,
	}, {
		Utils.Make("UICorner", { CornerRadius = UDim.new(0, 16) }),
		Utils.Make("UIStroke", { Color = UI.accent(), Thickness = 1.5, Transparency = 0.5 }),
	})
	Window.main = main
	local scale = Instance.new("UIScale"); scale.Scale = Config.get("uiScale"); scale.Parent = main; Window.scale = scale

	local header = Utils.Make("Frame", { Name = "Header", BackgroundColor3 = Color3.fromRGB(28, 34, 48), BackgroundTransparency = glass * 0.6, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 46), ZIndex = 5, Parent = main }, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 16) }) })
	Utils.Make("Frame", { BackgroundColor3 = Color3.fromRGB(28, 34, 48), BackgroundTransparency = glass * 0.6, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0.5, 0), ZIndex = 5, Parent = header })
	local accentLine = Utils.Make("Frame", { BackgroundColor3 = UI.accent(), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2), ZIndex = 6, Parent = header }, { Utils.Make("UIGradient", { Color = ColorSequence.new(UI.accent(), UI.accent2()) }) })
	Utils.Make("Frame", { BackgroundColor3 = UI.accent(), BorderSizePixel = 0, Position = UDim2.new(0, 12, 0.5, -4), Size = UDim2.new(0, 8, 0, 8), ZIndex = 6, Parent = header }, { Utils.Make("UICorner", { CornerRadius = UDim.new(1, 0) }), Utils.Make("UIGradient", { Color = ColorSequence.new(UI.accent(), UI.accent2()) }) })
	Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "MEIZU HUB", TextColor3 = UI.text, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(0, 150, 1, 0), ZIndex = 6, Parent = header })
	Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "v" .. VERSION, TextColor3 = UI.subtext, TextSize = 11, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -86, 0.5, 0), Size = UDim2.new(0, 40, 0, 14), ZIndex = 6, Parent = header })

	local function hbtn(text, xOff, cb)
		local b = Utils.Make("TextButton", { AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(50, 58, 78), BackgroundTransparency = 0.3, BorderSizePixel = 0, Font = Enum.Font.GothamBold, Text = text, TextColor3 = UI.text, TextSize = 15, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOff, 0.5, 0), Size = UDim2.new(0, 30, 0, 26), ZIndex = 7, Parent = header }, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 7) }) })
		b.MouseButton1Click:Connect(function()
			Utils.tween(b, { BackgroundColor3 = UI.accent() }, 0.08)
			task.delay(0.1, function() if Utils.exists(b) then Utils.tween(b, { BackgroundColor3 = Color3.fromRGB(50, 58, 78) }, 0.12) end end)
			pcall(cb)
		end)
	end
	hbtn("×", -8, function() Window.confirm("Unload Meizu Hub?", "All tasks will stop and the GUI will close.", function() Window.destroy() end) end)
	hbtn("—", -42, function() Window.minimize() end)

	local dragging = false; local dragStart, startPos
	Window.connect(header.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = i.Position; startPos = main.Position end
	end)
	Window.connect(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart; local v = workspace.CurrentCamera.ViewportSize
			local nx = Utils.clamp(startPos.X.Scale + d.X / v.X, 0.08, 0.92); local ny = Utils.clamp(startPos.Y.Scale + d.Y / v.Y, 0.08, 0.92)
			main.Position = UDim2.new(nx, 0, ny, 0); Config.set("windowX", nx); Config.set("windowY", ny)
		end
	end)
	Window.connect(UIS.InputEnded, function(i)
		if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and dragging then dragging = false; Config.save() end
	end)

	local rz = Utils.Make("TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, Text = "◢", Font = Enum.Font.GothamBold, TextColor3 = UI.subtext, TextSize = 14, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, -2), Size = UDim2.new(0, 22, 0, 22), ZIndex = 8, Parent = main })
	local resizing = false; local rzStart, startSize
	Window.connect(rz.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then resizing = true; rzStart = i.Position; startSize = main.Size end
	end)
	Window.connect(UIS.InputChanged, function(i)
		if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - rzStart; local v = workspace.CurrentCamera.ViewportSize
			local nw = Utils.clamp(startSize.X.Scale + d.X / v.X, 0.34, 0.95); local nh = Utils.clamp(startSize.Y.Scale + d.Y / v.Y, 0.38, 0.95)
			main.Size = UDim2.new(nw, 0, nh, 0); Config.set("windowW", nw); Config.set("windowH", nh)
		end
	end)
	Window.connect(UIS.InputEnded, function(i)
		if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and resizing then resizing = false; Config.save() end
	end)

	local sidebar = Utils.Make("Frame", { Name = "Sidebar", BackgroundColor3 = Color3.fromRGB(24, 30, 42), BackgroundTransparency = glass * 0.5, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(0, Window.sideW, 1, -46), ZIndex = 4, Parent = main }, {
		Utils.Make("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top }),
		Utils.Make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	})
	Window.sidebar = sidebar
	local content = Utils.Make("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.new(0, Window.sideW + 4, 0, 50), Size = UDim2.new(1, -Window.sideW - 12, 1, -54), ZIndex = 3, ClipsDescendants = true, Parent = main })
	Window.content = content

	local float = Utils.Make("TextButton", { Name = "Float", AutoButtonColor = false, BackgroundColor3 = UI.accent(), BorderSizePixel = 0, Font = Enum.Font.GothamBlack, Text = "M", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 18, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14 - topInset), Size = UDim2.new(0, 52, 0, 52), Visible = Config.get("minimized"), ZIndex = 50, Parent = screen }, { Utils.Make("UICorner", { CornerRadius = UDim.new(1, 0) }), Utils.Make("UIGradient", { Color = ColorSequence.new(UI.accent(), UI.accent2()) }) })
	Window.float = float
	float.MouseButton1Click:Connect(function() Window.restore() end)

	Window.modalLayer = Utils.Make("Frame", { Name = "Modal", BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.6, Size = UDim2.new(1, 0, 1, 0), Visible = false, ZIndex = 100, Parent = screen })
	Window.connect(UIS.InputBegan, function(i, gp) if gp then return end; if i.KeyCode == Enum.KeyCode.RightControl then if main.Visible then Window.minimize() else Window.restore() end end end)

	function Window.recolor()
		local a = UI.accent(); local a2 = UI.accent2()
		main.UIStroke.Color = a
		accentLine.UIGradient.Color = ColorSequence.new(a, a2)
		float.BackgroundColor3 = a; float.UIGradient.Color = ColorSequence.new(a, a2)
	end
end

function Window.minimize() Window.main.Visible = false; Window.float.Visible = true; Config.set("minimized", true); Config.save(); Logger.info("GUI minimized — tap M or press RightControl to restore.") end
function Window.restore() Window.main.Visible = true; Window.float.Visible = false; Config.set("minimized", false); Config.save() end

function Window.confirm(title, msg, onYes)
	if Window.modalOpen then return end
	Window.modalOpen = true; local layer = Window.modalLayer; layer.Visible = true
	local box = Utils.Make("Frame", { BackgroundColor3 = Color3.fromRGB(20, 24, 34), BackgroundTransparency = 0.1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 320, 0, 170), ZIndex = 101, Parent = layer }, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 12) }), Utils.Make("UIStroke", { Color = UI.accent(), Thickness = 1.5, Transparency = 0.4 }) })
	Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = title, TextColor3 = UI.text, TextSize = 15, Position = UDim2.new(0, 16, 0, 14), Size = UDim2.new(1, -32, 0, 20), ZIndex = 102, Parent = box })
	Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = msg, TextColor3 = UI.subtext, TextSize = 12, TextWrapped = true, Position = UDim2.new(0, 16, 0, 44), Size = UDim2.new(1, -32, 0, 60), ZIndex = 102, Parent = box })
	local yes = Utils.Make("TextButton", { AutoButtonColor = false, BackgroundColor3 = UI.accent(), BorderSizePixel = 0, Font = Enum.Font.GothamBold, Text = "Confirm", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13, Position = UDim2.new(0, 16, 1, -46), Size = UDim2.new(0.45, -8, 0, 32), ZIndex = 102, Parent = box }, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	local no = Utils.Make("TextButton", { AutoButtonColor = false, BackgroundColor3 = UI.panel, BorderSizePixel = 0, Font = Enum.Font.GothamBold, Text = "Cancel", TextColor3 = UI.text, TextSize = 13, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -46), Size = UDim2.new(0.45, -8, 0, 32), ZIndex = 102, Parent = box }, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	local done = false
	local function close() if done then return end; done = true; Window.modalOpen = false; layer.Visible = false; pcall(function() box:Destroy() end) end
	yes.MouseButton1Click:Connect(function() close(); if onYes then pcall(onYes) end end)
	no.MouseButton1Click:Connect(function() close() end)
end

function Window.addTab(id, label, icon, buildFn)
	local btn = Utils.Make("TextButton", {
		AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.GothamSemibold,
		Text = Window.mobile and icon or (icon .. "  " .. label), TextColor3 = UI.subtext, TextSize = Window.mobile and 18 or 13,
		Size = UDim2.new(1, -8, 0, Window.mobile and 42 or 36), LayoutOrder = #Window.tabs + 1, Parent = Window.sidebar,
	}, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	local page = Utils.Make("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = UI.subtext, Visible = false, Parent = Window.content,
	}, { Utils.Make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Left }), Utils.Make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }) })
	local tab = { id = id, label = label, btn = btn, page = page, built = false, buildFn = buildFn }
	table.insert(Window.tabs, tab)
	btn.MouseButton1Click:Connect(function() Window.select(id) end)
	return tab
end

function Window.select(id)
	for _, t in ipairs(Window.tabs) do
		if t.id == id then
			t.page.Visible = true; t.btn.BackgroundTransparency = 0; t.btn.BackgroundColor3 = UI.accent(); t.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			if not t.built then
				t.built = true
				local ok, err = pcall(t.buildFn, t.page)
				if not ok then Logger.error("Tab [" .. t.label .. "] build failed: " .. tostring(err)); UI.Paragraph(t.page, "Build error: " .. tostring(err)) end
			end
			Window.current = id
		else
			t.page.Visible = false; t.btn.BackgroundTransparency = 1; t.btn.TextColor3 = UI.subtext
		end
	end
end

function Window.destroy()
	TaskManager.stopAll()
	SeaEvents.stop()
	BossTracker.stop()
	for _, c in ipairs(Window.conns) do pcall(function() c:Disconnect() end) end
	Window.conns = {}
	pcall(function() if Compat.cap.getgenv then getgenv().MeizuHub = nil end end)
	pcall(function() Window.screen:Destroy() end)
	Logger.info("Meizu Hub unloaded.")
end

--------------------------------------------------------------------------------
-- 10. TASK MANAGER
--------------------------------------------------------------------------------
local TaskManager = { running = {} }
function TaskManager.start(id, fn)
	TaskManager.stop(id)
	local tok = { cancelled = false }; TaskManager.running[id] = tok
	task.spawn(function()
		local ok, err = pcall(fn, tok)
		if not ok then Logger.error("Task [" .. id .. "]: " .. tostring(err)); Notif.show("Task error", id .. ": " .. tostring(err), "error") end
		TaskManager.running[id] = nil
	end)
	Logger.info("Task started: " .. id)
end
function TaskManager.stop(id) local t = TaskManager.running[id]; if t then t.cancelled = true; TaskManager.running[id] = nil; Logger.info("Task stopped: " .. id) end end
function TaskManager.isRunning(id) return TaskManager.running[id] ~= nil end
function TaskManager.stopAll() for _, t in pairs(TaskManager.running) do t.cancelled = true end; TaskManager.running = {} end

--------------------------------------------------------------------------------
-- 11. REAL FEATURE MODULES (read-only / standard API)
--------------------------------------------------------------------------------
local SeaEvents = { rows = {}, last = {}, conn = nil }
SeaEvents.defs = {
	{ name = "Mirage Island", path = { "_WorldOrigin", "Locations" }, child = "Mirage Island" },
	{ name = "Kitsune Island", path = { "Map" }, child = "KitsuneIsland" },
	{ name = "Prehistoric Island", path = { "_WorldOrigin", "Locations" }, child = "Prehistoric Island" },
	{ name = "Frozen Dimension", path = { "_WorldOrigin", "Locations" }, child = "Frozen Dimension" },
}
function SeaEvents.check(def)
	local node = workspace
	for _, seg in ipairs(def.path) do
		local ok, nxt = pcall(function() return node:FindFirstChild(seg) end)
		if not ok or not nxt then return false end
		node = nxt
	end
	local ok, found = pcall(function() return node:FindFirstChild(def.child) end)
	return ok and found ~= nil
end
function SeaEvents.poll()
	for _, def in ipairs(SeaEvents.defs) do
		local active = SeaEvents.check(def)
		local prev = SeaEvents.last[def.name]
		if prev == nil then prev = active end
		if active ~= prev and Config.get("seaNotify") and Notif.enabled then
			Notif.show("Sea Event", def.name .. (active and " has spawned!" or " has despawned."), active and "info" or "warn")
			Logger.info("Sea event " .. def.name .. ": " .. (active and "spawned" or "despawned"))
		end
		SeaEvents.last[def.name] = active
		local row = SeaEvents.rows[def.name]
		if row then
			row.Set(active and "ACTIVE" or "inactive")
			row.SetColor(active and Color3.fromRGB(80, 220, 140) or UI.subtext)
		end
	end
end
function SeaEvents.start()
	if SeaEvents.conn then return end
	SeaEvents.conn = true
	TaskManager.start("seaevents", function(tok)
		while not tok.cancelled do
			pcall(SeaEvents.poll)
			for _ = 1, 6 do if tok.cancelled then break end; task.wait(0.5) end
		end
	end)
end
function SeaEvents.stop() if SeaEvents.conn then SeaEvents.conn = nil; TaskManager.stop("seaevents") end end

local BossTracker = { name = "", conn = nil, row = nil, posRow = nil }
function BossTracker.scan()
	if BossTracker.name == "" then if BossTracker.row then BossTracker.row.Set("no target") end; return end
	local found = nil
	local ok = pcall(function()
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("Humanoid") and d.Parent and d.Parent.Name == BossTracker.name then
				found = d; break
			end
		end
	end)
	if not ok or not found then
		if BossTracker.row then BossTracker.row.Set("not found / dead") end
		if BossTracker.posRow then BossTracker.posRow.Set("—") end
		return
	end
	local hum = found
	if BossTracker.row then BossTracker.row.Set(string.format("ALIVE — %.0f / %.0f HP", hum.Health, hum.MaxHealth)) end
	local hrp = hum.Parent:FindFirstChild("HumanoidRootPart") or hum.Parent.PrimaryPart
	if hrp and BossTracker.posRow then local p = hrp.Position; BossTracker.posRow.Set(string.format("%.0f, %.0f, %.0f", p.X, p.Y, p.Z)) end
end
function BossTracker.start()
	if BossTracker.conn then return end
	BossTracker.conn = true
	TaskManager.start("bosstracker", function(tok)
		while not tok.cancelled do
			if Window.current == "bosses" then pcall(BossTracker.scan) end
			for _ = 1, 4 do if tok.cancelled then break end; task.wait(0.5) end
		end
	end)
end
function BossTracker.stop() if BossTracker.conn then BossTracker.conn = nil; TaskManager.stop("bosstracker") end end

local ServerHop = {}
function ServerHop.hop(maxPlayers)
	if not Compat.cap.httpget then
		return false, "HttpGet not available in this executor — cannot fetch server list."
	end
	local HttpService = game:GetService("HttpService")
	local servers
	local ok = pcall(function()
		local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
		local raw = game:HttpGet(url)
		servers = HttpService:JSONDecode(raw).data
	end)
	if not ok or type(servers) ~= "table" then
		return false, "Failed to fetch/parse server list (network or API changed)."
	end
	local candidates = {}
	for _, s in ipairs(servers) do
		if s.id and s.id ~= game.JobId and type(s.playing) == "number" and s.playing <= maxPlayers and s.playing > 0 then
			table.insert(candidates, s.id)
		end
	end
	if #candidates == 0 then
		return false, string.format("No public server with <= %d players found.", maxPlayers)
	end
	local target = candidates[math.random(1, #candidates)]
	local tps = game:GetService("TeleportService")
	local ok2, err = pcall(function() tps:TeleportToPlaceInstance(game.PlaceId, target) end)
	if ok2 then
		Logger.info("Server hop -> " .. target:sub(1, 8))
		return true, "Teleporting to server " .. target:sub(1, 8) .. "..."
	end
	return false, "Teleport failed: " .. tostring(err)
end

--------------------------------------------------------------------------------
-- 12. TABS
--------------------------------------------------------------------------------
local Tabs = { state = { keepWS = false, keepJP = false, ws = 16, jp = 50, fov = 70, farmMode = "Demo Loop (safe)" } }
local function hum() local lp = game:GetService("Players").LocalPlayer; if not lp or not lp.Character then return nil end; return lp.Character:FindFirstChildOfClass("Humanoid") end

function Tabs.Home(page)
	UI.Section(page, "OVERVIEW")
	local gameName = game.Name
	pcall(function() gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
	UI.InfoRow(page, "Product", PRODUCT)
	UI.InfoRow(page, "Version", "v" .. VERSION)
	UI.InfoRow(page, "Game", gameName)
	UI.InfoRow(page, "Place Id", tostring(game.PlaceId))
	local statusRow = UI.InfoRow(page, "Status", "Ready")
	local uptimeRow = UI.InfoRow(page, "Session time", "00:00")
	local gameTimeRow = UI.InfoRow(page, "Game time", "0h 0m 0s")
	local countryRow = UI.InfoRow(page, "Region", "...")
	local playerRow = UI.InfoRow(page, "Player", "N/A")
	local levelRow = UI.InfoRow(page, "Level", "N/A")
	task.spawn(function()
		local code = "Unknown"
		local ok = pcall(function() code = game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(game:GetService("Players").LocalPlayer) end)
		if not ok then code = "Unknown" end
		countryRow.Set(code)
	end)

	UI.Section(page, "QUICK ACTIONS")
	local row = Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = page })
	local h1 = Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5, -4, 1, 0), Parent = row })
	local h2 = Utils.Make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), Parent = row })
	UI.Button(h1, "Open Settings", function() Window.select("settings") end, 1)
	UI.Button(h2, "Rejoin Server", function()
		Window.confirm("Rejoin?", "Teleport to a new server of the same place.", function()
			local ok = pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId) end)
			if not ok then Notif.show("Rejoin failed", "TeleportService rejected.", "error") end
		end)
	end, 1)

	UI.Section(page, "RECENT ACTIVITY")
	local logBox = Utils.Make("Frame", { BackgroundColor3 = UI.panel, BackgroundTransparency = UI.glass() * 0.6, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 140), Parent = page }, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	local logScroll = Utils.Make("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -8, 1, -8), Position = UDim2.new(0, 4, 0, 4), CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y, ScrollBarThickness = 3, Parent = logBox }, { Utils.Make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

	Tabs._home = function()
		uptimeRow.Set(Utils.formatTime(tick() - START_TIME))
		local gt = math.floor(workspace.DistributedGameTime)
		gameTimeRow.Set(string.format("%dh %dm %ds", math.floor(gt / 3600), math.floor((gt % 3600) / 60), gt % 60))
		local info = PInfo.get()
		playerRow.Set(info.name); levelRow.Set(info.level)
		statusRow.Set(TaskManager.isRunning("farm") and "Farm running" or "Ready")
		for _, c in ipairs(logScroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
		for i, e in ipairs(Logger.recent(12)) do
			local col = UI.text
			if e.level == "warn" then col = Color3.fromRGB(255, 190, 90) end
			if e.level == "error" then col = Color3.fromRGB(255, 110, 110) end
			Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = string.format("[%s] %s", os.date("%H:%M:%S", e.time), e.message), TextColor3 = col, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, -4, 0, 14), LayoutOrder = i, Parent = logScroll })
		end
	end
	Tabs._home()
end

function Tabs.Farming(page)
	UI.Section(page, "FARM CONTROLLER (framework)")
	UI.Paragraph(page, "Task controller (start/stop/cancel, progress, runtime limit, error log) fully implemented. Only a safe demo loop is active. Blox Fruits combat automation from the reference is LOCKED — requires verified game remotes/offsets.")
	local mode = UI.Dropdown(page, "Mode", { "Demo Loop (safe)", "[Locked] Auto Farm Level", "[Locked] Auto Farm Nearest", "[Locked] Auto Boss", "[Locked] Auto Chest", "[Locked] Auto Berry", "[Locked] Auto Material", "[Locked] Auto Mastery" }, "Demo Loop (safe)", function(o) Tabs.state.farmMode = o end)
	local limit = UI.Slider(page, "Max runtime (min)", 1, 120, 15, function(v) return tostring(Utils.round(v)) .. "m" end)
	local progress = UI.ProgressBar(page, "Progress — idle")
	local statusRow = UI.InfoRow(page, "Status", "Stopped")
	local elapsedRow = UI.InfoRow(page, "Elapsed", "00:00")
	local ticksRow = UI.InfoRow(page, "Ticks", "0")

	local farmStart = 0; local ticks = 0; local startBtn, stopBtn
	local function render()
		if TaskManager.isRunning("farm") then statusRow.Set("Running — " .. tostring(Tabs.state.farmMode)); if startBtn then startBtn.SetDisabled(true) end; if stopBtn then stopBtn.SetDisabled(false) end
		else statusRow.Set("Stopped"); if startBtn then startBtn.SetDisabled(false) end; if stopBtn then stopBtn.SetDisabled(true) end end
		elapsedRow.Set(Utils.formatTime(tick() - farmStart)); ticksRow.Set(tostring(ticks))
		local pct = Utils.clamp((tick() - farmStart) / (limit.Get() * 60), 0, 1)
		progress.Set(pct); progress.SetLabel(string.format("Progress — %d%%", math.floor(pct * 100)))
	end
	local function onStart()
		if Tabs.state.farmMode ~= "Demo Loop (safe)" then Notif.show("Locked", "This mode requires game-specific logic and is disabled.", "warn"); return end
		if TaskManager.isRunning("farm") then return end
		farmStart = tick(); ticks = 0
		TaskManager.start("farm", function(tok)
			local lim = limit.Get() * 60
			while not tok.cancelled do
				if (tick() - farmStart) >= lim then Logger.warn("Farm hit max runtime — auto-stop."); Notif.show("Farm stopped", "Max runtime reached.", "info"); break end
				ticks = ticks + 1
				if ticks % 10 == 0 then Logger.info("Farm tick #" .. ticks .. " (demo)") end
				task.wait(1)
			end
		end)
		render()
	end
	local function onStop() TaskManager.stop("farm"); render() end
	local btnRow = Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = page })
	local sh = Utils.Make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5, -4, 1, 0), Parent = btnRow })
	local sth = Utils.Make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), Parent = btnRow })
	startBtn = UI.Button(sh, "START", onStart, 1); startBtn.SetAccent(true)
	stopBtn = UI.Button(sth, "STOP", onStop, 1); stopBtn.SetDisabled(true)
	render()

	UI.Section(page, "LOCKED AUTOMATION (reference features, excluded)")
	UI.LockedToggle(page, "Auto Farm Level / Nearest", "requires verified mob/quest remotes — excluded by design.")
	UI.LockedToggle(page, "Auto Boss / Rip Indra / Dough King", "requires boss AI + remote spoofing — excluded.")
	UI.LockedToggle(page, "Auto Mastery (Fruit/Gun/Sword)", "requires combat automation — excluded.")
	UI.LockedToggle(page, "Fast Attack / Bring Mobs", "requires remote manipulation — excluded.")

	UI.Section(page, "ERROR LOG")
	local errBox = Utils.Make("Frame", { BackgroundColor3 = UI.panel, BackgroundTransparency = UI.glass() * 0.6, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 100), Parent = page }, { Utils.Make("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	local errLbl = Utils.Make("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "No errors this session.", TextColor3 = UI.subtext, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(1, -12, 1, -8), Parent = errBox })
	Tabs._farm = function()
		render()
		local errs = {}
		for _, e in ipairs(Logger.entries) do if e.level == "error" or e.level == "warn" then table.insert(errs, e) end end
		if #errs == 0 then errLbl.Text = "No errors this session."
		else
			local lines = {}
			for i = math.max(1, #errs - 6), #errs do local e = errs[i]; table.insert(lines, string.format("[%s] %s: %s", os.date("%H:%M:%S", e.time), e.level:upper(), e.message)) end
			errLbl.Text = table.concat(lines, "\n")
		end
	end
	Tabs._farm()
end

function Tabs.Bosses(page)
	UI.Section(page, "BOSS TRACKER (read-only)")
	UI.Paragraph(page, "Type an NPC/boss name. Tracker scans workspace (read-only, throttled) and shows alive status, HP and position. No auto-attack — that automation is locked.")
	local nameInput = UI.TextInput(page, "Boss / NPC name", "e.g. Rip_Indra, Cake Prince", "")
	local statusRow = UI.InfoRow(page, "Status", "idle")
	local posRow = UI.InfoRow(page, "Position", "—")
	BossTracker.row = statusRow; BossTracker.posRow = posRow
	UI.Button(page, "Start tracking", function()
		local n = nameInput.Get()
		if n == "" then Notif.show("No name", "Enter a boss/NPC name first.", "warn"); return end
		BossTracker.name = n; BossTracker.start()
		statusRow.Set("scanning..."); Notif.show("Tracker", "Tracking " .. n, "info"); Logger.info("Boss tracker started: " .. n)
	end, 1)
	UI.Button(page, "Stop tracking", function() BossTracker.stop(); statusRow.Set("stopped"); posRow.Set("—") end, 1)

	UI.Section(page, "LOCKED (reference features)")
	UI.LockedToggle(page, "Auto Attack Boss / Bring Boss", "requires combat remote automation — excluded.")
	UI.LockedToggle(page, "Auto Summon (Cake Prince / Soul Reaper)", "requires item + remote logic — excluded.")
	UI.LockedToggle(page, "Auto Accept Boss Quest", "requires quest remote — excluded.")
end

function Tabs.Quests(page)
	UI.Section(page, "QUEST TRACKER (framework)")
	UI.Paragraph(page, "Quest acceptance/completion in Blox Fruits uses game-specific remotes that change with updates and cannot be verified here. Tracking framework present; auto-quest locked.")
	UI.Dropdown(page, "Quest tier (reference groups)", { "Sea 1", "Sea 2", "Sea 3", "Elite Hunter", "Sword Quests", "Fighting Style Quests" }, "Sea 1")
	UI.ProgressBar(page, "Quest progress — no active quest")
	UI.InfoRow(page, "Active quest", "None")
	UI.InfoRow(page, "Kills / target", "N/A")

	UI.Section(page, "LOCKED (reference features)")
	UI.LockedToggle(page, "Auto Quest Sea 1/2/3", "requires verified quest NPC + kill remotes — excluded.")
	UI.LockedToggle(page, "Auto Sword (Tushita/Yama/CDK/TTK/Rengoku...)", "requires multi-step quest automation — excluded.")
	UI.LockedToggle(page, "Auto Fighting Style (Superhuman/Godhuman...)", "requires quest + item automation — excluded.")
	UI.LockedToggle(page, "Auto Observation V2 / Race Awakening", "requires event + remote logic — excluded.")
end

function Tabs.Raids(page)
	UI.Section(page, "RAID STATUS (read-only framework)")
	UI.Paragraph(page, "Raid/dungeon instance detection requires reading game-specific folders. No auto-raid implemented.")
	UI.InfoRow(page, "Raid active", "N/A (no verified path)")
	UI.InfoRow(page, "Dungeon event", "N/A")
	UI.InfoRow(page, "Fruit raid micro", "N/A")
	UI.Section(page, "LOCKED (reference features)")
	UI.LockedToggle(page, "Auto Factory / Pirate Raid", "requires raid NPC + combat automation — excluded.")
	UI.LockedToggle(page, "Auto Fruit Raid / Dungeon", "requires raid lobby + micro automation — excluded.")
	UI.LockedToggle(page, "Auto Magnet Token / Shop", "requires currency + shop remotes — excluded.")
end

function Tabs.SeaEvents(page)
	UI.Section(page, "SEA EVENT MONITOR (real, read-only)")
	UI.Paragraph(page, "Polls workspace every ~3s for Mirage Island, Kitsune Island, Prehistoric Island and Frozen Dimension. Notifies on spawn/despawn. Read-only — no teleport or auto-collect.")
	SeaEvents.rows = {}
	for _, def in ipairs(SeaEvents.defs) do
		SeaEvents.rows[def.name] = UI.InfoRow(page, def.name, "checking...")
	end
	UI.Toggle(page, "Notify on spawn/despawn", Config.get("seaNotify"), function(on) Config.set("seaNotify", on) end)
	UI.Button(page, "Start monitor", function() SeaEvents.start(); Notif.show("Monitor", "Sea event monitor started.", "info") end, 1)
	UI.Button(page, "Stop monitor", function() SeaEvents.stop() end, 1)

	UI.Section(page, "LOCKED (reference features)")
	UI.LockedToggle(page, "Auto Find / Tween To Mirage", "requires auto-teleport automation — excluded.")
	UI.LockedToggle(page, "Auto Collect Gear / Race V4", "requires event interaction automation — excluded.")
	UI.LockedToggle(page, "Auto Sea Event (Kitsune/Frozen)", "requires event automation — excluded.")
end

function Tabs.Player(page)
	UI.Section(page, "CHARACTER STATS")
	local level = UI.InfoRow(page, "Level", "N/A")
	local health = UI.InfoRow(page, "Health", "N/A")
	local energy = UI.InfoRow(page, "Energy", "N/A")
	local wsRow = UI.InfoRow(page, "WalkSpeed", "N/A")
	local jpRow = UI.InfoRow(page, "JumpPower", "N/A")
	local posRow = UI.InfoRow(page, "Position", "N/A")

	UI.Section(page, "CLIENT-SIDE CONTROLS (standard API)")
	UI.Toggle(page, "Keep WalkSpeed", false, function(on)
		Tabs.state.keepWS = on; local h = hum()
		if on and h then pcall(function() h.WalkSpeed = Tabs.state.ws end) elseif h then pcall(function() h.WalkSpeed = 16 end) end
		Logger.info("Keep WalkSpeed " .. (on and "ON" or "OFF"))
	end)
	UI.Slider(page, "WalkSpeed", 8, 200, 16, function(v) return tostring(Utils.round(v)) end, function(v)
		Tabs.state.ws = v; if Tabs.state.keepWS then local h = hum(); if h then pcall(function() h.WalkSpeed = v end) end end
	end)
	UI.Toggle(page, "Keep JumpPower", false, function(on)
		Tabs.state.keepJP = on; local h = hum()
		if h then pcall(function() if h.UseJumpPower then h.JumpPower = on and Tabs.state.jp or 50 else h.JumpHeight = on and (Tabs.state.jp / 5) or 7.2 end end) end
	end)
	UI.Slider(page, "JumpPower", 10, 300, 50, function(v) return tostring(Utils.round(v)) end, function(v)
		Tabs.state.jp = v; if Tabs.state.keepJP then local h = hum(); if h then pcall(function() if h.UseJumpPower then h.JumpPower = v else h.JumpHeight = v / 5 end end) end end
	end)
	UI.Slider(page, "Camera FOV", 40, 120, 70, function(v) return tostring(Utils.round(v)) .. "deg" end, function(v)
		Tabs.state.fov = v; local c = workspace.CurrentCamera; if c then pcall(function() c.FieldOfView = v end) end
	end)
	UI.Button(page, "Reset Character (respawn)", function()
		Window.confirm("Reset?", "Your character will respawn.", function()
			local ok = pcall(function() game:GetService("Players").LocalPlayer:LoadCharacter() end)
			Notif.show(ok and "Respawn" or "Failed", ok and "Reset requested." or "LoadCharacter rejected.", ok and "info" or "error")
		end)
	end, 1)
	UI.Button(page, "Copy position", function()
		local info = PInfo.get()
		if info.position == "N/A" then Notif.show("No position", "Character not loaded.", "error"); return end
		if Compat.cap.setclipboard then pcall(function() setclipboard(info.position) end); Notif.show("Copied", "Position copied.", "info")
		else Notif.show("Clipboard", "setclipboard not supported.", "warn") end
	end, 1)

	UI.Section(page, "LOCKED (reference features)")
	UI.LockedToggle(page, "NoClip / Fly / Speed-hack", "requires physics bypass — excluded.")
	UI.LockedToggle(page, "Aimbot / Auto-Aim", "requires combat automation — excluded.")
	UI.LockedToggle(page, "ESP / Player Highlight", "visual cheat — excluded.")
	UI.LockedToggle(page, "Anti-AFK (input synthesis)", "requires executor input API — excluded.")

	Tabs._player = function()
		local info = PInfo.get()
		level.Set(info.level); health.Set(info.health .. " / " .. info.maxHealth)
		energy.Set(info.energy .. (info.maxEnergy ~= "N/A" and (" / " .. info.maxEnergy) or ""))
		wsRow.Set(info.walkSpeed); jpRow.Set(info.jumpPower); posRow.Set(info.position)
	end
	Tabs._player()

	local lp = game:GetService("Players").LocalPlayer
	Window.connect(lp.CharacterAdded, function(char)
		task.wait(1)
		local h = char:FindFirstChildOfClass("Humanoid"); if not h then return end
		if Tabs.state.keepWS then pcall(function() h.WalkSpeed = Tabs.state.ws end) end
		if Tabs.state.keepJP then pcall(function() if h.UseJumpPower then h.JumpPower = Tabs.state.jp else h.JumpHeight = Tabs.state.jp / 5 end end) end
	end)
end

function Tabs.Teleport(page)
	UI.Section(page, "TELEPORT (standard PivotTo)")
	UI.Paragraph(page, "Uses Character:PivotTo (standard). No hardcoded island coords (unverified). Save your own waypoints.")
	local Players = game:GetService("Players")
	local names = {}; for _, p in ipairs(Players:GetPlayers()) do table.insert(names, p.Name) end
	local pdd = UI.Dropdown(page, "Teleport to player", names, names[1] or "—")
	UI.Button(page, "Go to selected player", function()
		local t = Players:FindFirstChild(pdd.Get())
		local lp = Players.LocalPlayer
		if not t or not t.Character or not lp or not lp.Character then Notif.show("Failed", "Target or your character missing.", "error"); return end
		local a = lp.Character:FindFirstChild("HumanoidRootPart"); local b = t.Character:FindFirstChild("HumanoidRootPart")
		if not a or not b then Notif.show("Failed", "Root part missing.", "error"); return end
		local ok = pcall(function() lp.Character:PivotTo(b.CFrame + Vector3.new(3, 0, 3)) end)
		Notif.show(ok and "Teleported" or "Failed", ok and "Moved to " .. t.Name or "PivotTo rejected.", ok and "info" or "error")
	end, 1)
	UI.Button(page, "Refresh player list", function() local n = {}; for _, p in ipairs(Players:GetPlayers()) do table.insert(n, p.Name) end; pdd.Refresh(n) end, 1)

	UI.Section(page, "CUSTOM COORDINATES")
	local x = UI.TextInput(page, "X", "number", "0"); local y = UI.TextInput(page, "Y", "number", "0"); local z = UI.TextInput(page, "Z", "number", "0")
	UI.Button(page, "Teleport to XYZ", function()
		local nx, ny, nz = tonumber(x.Get()), tonumber(y.Get()), tonumber(z.Get())
		if not (nx and ny and nz) then Notif.show("Invalid", "X/Y/Z must be numbers.", "error"); return end
		local lp = Players.LocalPlayer
		if not lp or not lp.Character then Notif.show("Failed", "Character not loaded.", "error"); return end
		local ok = pcall(function() lp.Character:PivotTo(CFrame.new(nx, ny, nz)) end)
		Notif.show(ok and "Teleported" or "Failed", ok and string.format("%.0f, %.0f, %.0f", nx, ny, nz) or "PivotTo rejected.", ok and "info" or "error")
	end, 1)

	UI.Section(page, "SAVED WAYPOINTS")
	UI.Paragraph(page, Config.persistent and "Saved to meizuhub/waypoints.txt." or "File save unavailable — in-memory only.")
	local wn = UI.TextInput(page, "Waypoint name", "e.g. Middle Town", "")
	UI.Button(page, "Save current position", function()
		local n = wn.Get(); if n == "" then Notif.show("Need name", "Enter a name first.", "warn"); return end
		local lp = Players.LocalPlayer; local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then Notif.show("No position", "Character not loaded.", "error"); return end
		local p = hrp.Position; table.insert(Config.waypoints, { name = n, x = p.X, y = p.Y, z = p.Z }); Config.saveWP(); wn.Set("")
		Notif.show("Saved", "Waypoint '" .. n .. "' saved.", "info"); Logger.info("Saved waypoint: " .. n)
	end, 1)
	local wnames = {}; for _, w in ipairs(Config.waypoints) do table.insert(wnames, w.name) end
	local wdd = UI.Dropdown(page, "Waypoint", wnames, wnames[1] or "—")
	UI.Button(page, "Teleport to waypoint", function()
		local found; for _, w in ipairs(Config.waypoints) do if w.name == wdd.Get() then found = w; break end end
		if not found then Notif.show("Not found", "Waypoint missing.", "error"); return end
		local lp = Players.LocalPlayer; if not lp or not lp.Character then Notif.show("Failed", "Character not loaded.", "error"); return end
		local ok = pcall(function() lp.Character:PivotTo(CFrame.new(found.x, found.y, found.z)) end)
		Notif.show(ok and "Teleported" or "Failed", ok and found.name or "PivotTo rejected.", ok and "info" or "error")
	end, 1)
	UI.Button(page, "Delete waypoint", function()
		local n = wdd.Get()
		for i, w in ipairs(Config.waypoints) do if w.name == n then table.remove(Config.waypoints, i); break end end
		Config.saveWP()
		local ns = {}; for _, w in ipairs(Config.waypoints) do table.insert(ns, w.name) end; wdd.Refresh(ns)
		Notif.show("Deleted", "Waypoint removed.", "info")
	end, 1)
end

function Tabs.Server(page)
	UI.Section(page, "SERVER INFO")
	UI.InfoRow(page, "Place Id", tostring(game.PlaceId))
	UI.InfoRow(page, "Game Id", tostring(game.GameId))
	local ver = UI.InfoRow(page, "Place Version", "N/A"); pcall(function() ver.Set(tostring(game.PlaceVersion)) end)
	local job = UI.InfoRow(page, "Job Id", "(hidden/studio)")
	pcall(function() if game.JobId and game.JobId ~= "" then job.Set(game.JobId) end end)
	local pcount = UI.InfoRow(page, "Players", tostring(#game:GetService("Players"):GetPlayers()))
	local fps = UI.InfoRow(page, "Client FPS", "—")
	Tabs._fpsA = 0; Tabs._fpsN = 0
	Window.connect(game:GetService("RunService").Heartbeat, function(dt) Tabs._fpsA = Tabs._fpsA + dt; Tabs._fpsN = Tabs._fpsN + 1 end)

	UI.Section(page, "SERVER HOP (one-shot, games.roblox.com API)")
	UI.Paragraph(page, "Fetches public servers and teleports to one under the player limit. Same mechanism as the reference. One hop per click — no infinite loop. Requires executor HttpGet.")
	local hopLimit = UI.Slider(page, "Max players in target", 1, 30, 12, function(v) return "<=" .. tostring(Utils.round(v)) end)
	UI.Button(page, "Hop to smaller server", function()
		Window.confirm("Server hop?", string.format("Teleport to a random public server with <= %d players.", math.floor(hopLimit.Get())), function()
			local ok, msg = ServerHop.hop(math.floor(hopLimit.Get()))
			Notif.show(ok and "Hopping" or "Hop failed", msg, ok and "info" or "error")
			if not ok then Logger.warn("Server hop failed: " .. msg) end
		end)
	end, 1)
	UI.Button(page, "Rejoin (new server)", function()
		Window.confirm("Rejoin?", "Teleport to a new server of this place.", function()
			local ok = pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId) end)
			if not ok then Notif.show("Failed", "Teleport rejected.", "error") end
		end)
	end, 1)
	UI.Button(page, "Copy Job Id", function()
		if not (game.JobId and game.JobId ~= "") then Notif.show("No Job Id", "Studio/reserved server.", "warn"); return end
		if Compat.cap.setclipboard then pcall(function() setclipboard(game.JobId) end); Notif.show("Copied", "Job Id copied.", "info")
		else Notif.show("Clipboard", "setclipboard unsupported.", "warn") end
	end, 1)
	UI.Button(page, "Refresh", function()
		pcount.Set(tostring(#game:GetService("Players"):GetPlayers()))
		pcall(function() if game.JobId and game.JobId ~= "" then job.Set(game.JobId) end end)
		Notif.show("Refreshed", "Server data refreshed.", "info")
	end, 1)

	Tabs._server = function()
		pcount.Set(tostring(#game:GetService("Players"):GetPlayers()))
		if Tabs._fpsN > 0 and Tabs._fpsA > 0 then fps.Set(tostring(math.floor(Tabs._fpsN / Tabs._fpsA))) end
		Tabs._fpsA = 0; Tabs._fpsN = 0
	end
end

function Tabs.Settings(page)
	UI.Section(page, "APPEARANCE (Liquid Glass)")
	local presets = {
		{ name = "Ocean (cyan->violet)", a = "#38BDF8", b = "#8B5CF6" },
		{ name = "Sunset (rose->amber)", a = "#FB7185", b = "#F59E0B" },
		{ name = "Forest (emerald->cyan)", a = "#10B981", b = "#06B6D4" },
		{ name = "Mono (slate->blue)", a = "#64748B", b = "#3B82F6" },
		{ name = "Meizu Blue", a = "#3884FF", b = "#60A5FA" },
	}
	local pnames = {}; for _, p in ipairs(presets) do table.insert(pnames, p.name) end
	UI.Dropdown(page, "Accent gradient", pnames, "Ocean (cyan->violet)", function(opt)
		for _, p in ipairs(presets) do
			if p.name == opt then Config.set("accent", p.a); Config.set("accent2", p.b); Window.recolor(); Logger.info("Accent -> " .. opt); break end
		end
	end)
	UI.Toggle(page, "Animations", Config.get("animations"), function(on) Config.set("animations", on) end)
	UI.Slider(page, "Glass transparency", 0.1, 0.85, Config.get("glass"), function(v) return tostring(Utils.round(v * 100)) .. "%" end, function(v)
		Config.set("glass", v); Window.main.BackgroundTransparency = v
	end)
	UI.Slider(page, "UI scale", 0.7, 1.4, Config.get("uiScale"), function(v) return tostring(Utils.round(v, 2)) .. "x" end, function(v)
		Config.set("uiScale", v); Window.scale.Scale = v
	end)
	UI.Toggle(page, "Notifications", Config.get("notifications"), function(on) Config.set("notifications", on); Notif.enabled = on end)

	UI.Section(page, "CONFIGURATION")
	UI.Paragraph(page, Config.persistent and "Saved to meizuhub/config.txt (writefile)." or "writefile/readfile missing — in-memory only.")
	UI.Button(page, "Save configuration", function()
		local ok = Config.save()
		Notif.show(ok and "Saved" or "Save failed", ok and "Config saved." or "writefile unsupported.", ok and "info" or "warn")
	end, 1)
	UI.Button(page, "Reset to defaults", function()
		Window.confirm("Reset?", "All settings return to defaults; restart script to fully apply.", function()
			Config.reset(); Config.save(); Notif.show("Reset", "Defaults restored.", "info"); Logger.warn("Settings reset — restart recommended.")
		end)
	end, 1)
	UI.Button(page, "Unload Meizu Hub", function() Window.confirm("Unload?", "Stops all tasks and closes GUI.", function() Window.destroy() end) end, 1)
end

function Tabs.About(page)
	UI.Section(page, "PRODUCT")
	UI.InfoRow(page, "Name", PRODUCT)
	UI.InfoRow(page, "Version", "v" .. VERSION)
	UI.InfoRow(page, "Build date", "2026-10-17")
	UI.InfoRow(page, "Based on analysis of", "crackedbananahub.txt (31487 lines)")
	UI.InfoRow(page, "External UI lib used", "None — original implementation")
	UI.InfoRow(page, "Network calls", "games.roblox.com (server hop only, if enabled)")
	UI.InfoRow(page, "Data collection", "None")

	UI.Section(page, "COMPATIBILITY REPORT")
	local lines = {}
	for _, e in ipairs(Compat.report()) do table.insert(lines, string.format("%s:%s", e.name, e.ok and "OK" or "-")) end
	UI.Paragraph(page, table.concat(lines, "  "))

	UI.Section(page, "REFERENCE ANALYSIS SUMMARY")
	UI.Paragraph(page, "Reference: 13 tabs (Info/Farming/Setting/Fishing/Quest/SeaEvent/Mirage/Volcano/Stats+Esp/Fruit+Raid/LocalPlayer/Teleport/Shop/Misc), 354 UI components, ~120 automation toggles. UI library loaded REMOTELY from GitHub (not in file). Server hop uses games.roblox.com API. No credential-theft code found. All cheat automation is LOCKED in this rebuild.")

	UI.Section(page, "DISCLAIMER")
	UI.Paragraph(page, "No claim of undetectability. Use only where permitted. Not tested on a live Android executor. Syntax verified with Luau 0.743; boot path smoke-tested under stubbed Roblox environment.")
end

--------------------------------------------------------------------------------
-- 13. BOOT
--------------------------------------------------------------------------------
local function boot()
	Config.load(); Config.loadWP()
	Logger.info(PRODUCT .. " v" .. VERSION .. " starting...")
	Logger.info("Persistence: " .. (Config.persistent and "enabled" or "in-memory only"))
	Logger.info("HttpGet (server hop): " .. (Compat.cap.httpget and "available" or "unavailable"))
	Window.init()

	Window.addTab("home", "Home", "⌂", Tabs.Home)
	Window.addTab("farming", "Farming", "⚙", Tabs.Farming)
	Window.addTab("bosses", "Bosses", "!", Tabs.Bosses)
	Window.addTab("quests", "Quests", "?", Tabs.Quests)
	Window.addTab("raids", "Raids", "X", Tabs.Raids)
	Window.addTab("seaevents", "Sea Events", "~", Tabs.SeaEvents)
	Window.addTab("player", "Player", "O", Tabs.Player)
	Window.addTab("teleport", "Teleport", ">", Tabs.Teleport)
	Window.addTab("server", "Server", "#", Tabs.Server)
	Window.addTab("settings", "Settings", "*", Tabs.Settings)
	Window.addTab("about", "About", "i", Tabs.About)

	Window.select("home")

	if Compat.cap.getgenv then
		pcall(function() getgenv().MeizuHub = { Destroy = function() Window.destroy() end, Version = VERSION } end)
	end

	task.spawn(function()
		while Utils.exists(Window.screen) do
			pcall(function()
				if Tabs._home then Tabs._home() end
				if Tabs._farm then Tabs._farm() end
				if Tabs._player and Window.current == "player" then Tabs._player() end
				if Tabs._server and Window.current == "server" then Tabs._server() end
			end)
			task.wait(1)
		end
	end)

	Notif.show(PRODUCT .. " loaded", "v" .. VERSION .. " — tap M or RightControl to toggle.", "info")
	Logger.info(PRODUCT .. " ready.")
end

local ok, err = pcall(boot)
if not ok then
	pcall(function()
		local lp = game:GetService("Players").LocalPlayer
		local pg = lp:WaitForChild("PlayerGui", 5)
		local sg = Instance.new("ScreenGui"); sg.Name = "MeizuHub_Error"; sg.Parent = pg
		local l = Instance.new("TextLabel")
		l.BackgroundColor3 = Color3.fromRGB(40, 10, 10); l.TextColor3 = Color3.fromRGB(255, 200, 200)
		l.Size = UDim2.new(0.8, 0, 0.2, 0); l.Position = UDim2.new(0.1, 0, 0.4, 0)
		l.Font = Enum.Font.Gotham; l.TextSize = 14; l.TextWrapped = true
		l.Text = "Meizu Hub failed to start: " .. tostring(err); l.Parent = sg
	end)
	error("[Meizu Hub] boot failed: " .. tostring(err))
end
