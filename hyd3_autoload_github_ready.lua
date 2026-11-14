print("Exe Speed Bypass loaded")

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Black / white / gray color scheme
local C_BG = Color3.fromRGB(0, 0, 0)
local C_PANEL = Color3.fromRGB(30, 30, 30)
local C_ROW = Color3.fromRGB(60, 60, 60)
local C_NEON = Color3.fromRGB(255, 255, 255)
local C_MINT = Color3.fromRGB(200, 200, 200)
local C_MID = Color3.fromRGB(120, 120, 120)
local C_DIM = Color3.fromRGB(80, 80, 80)
local C_EDGE = Color3.fromRGB(50, 50, 50)
local C_EDGE2 = Color3.fromRGB(100, 100, 100)

local GUI_NAME = "LORD HUB SPEED BYPASSE"
local WM_NAME = "IrishWatermark" -- unused, kept for compatibility

-- Scaling factor for a smaller UI
-- 15% larger than the previous 0.7 scale
local S = 0.90

local function safeParent()
	local ok, hidden = pcall(function()
		return (gethui and gethui()) or (get_hidden_gui and get_hidden_gui())
	end)
	if ok and typeof(hidden) == "Instance" then return hidden end
	if pcall(function() return CoreGui.Name end) then return CoreGui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local Parent = safeParent()

-- Clean old instances
for _, v in ipairs(Parent:GetChildren()) do
	if v.Name == GUI_NAME then pcall(function() v:Destroy() end) end
end
pcall(function()
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg and pg:FindFirstChild(WM_NAME) then pg[WM_NAME]:Destroy() end
end)

local State = {
	Mode = "PC",
	Power = 97000,
	Active = false,
	Keybind = Enum.KeyCode.V,
	Binding = false,
	Hidden = false,
	Minimized = false,
	Locked = false,
}

local lagConn = nil
local lagAmount = 0.15

local function applyPower(val)
	State.Power = math.clamp(math.floor(val), 9000, 500000)
	local t = (State.Power - 10000) / 490000
	if t < 0 then t = 0 end
	lagAmount = t * 0.2
end
applyPower(State.Power)

local function startLag()
	if lagConn then lagConn:Disconnect() end
	lagConn = RunService.RenderStepped:Connect(function()
		if not State.Active then return end
		if lagAmount > 0 then
			local t = tick()
			while tick() - t < lagAmount do end
		end
	end)
end

local function stopLag()
	if lagConn then
		lagConn:Disconnect()
		lagConn = nil
	end
end

-- HYD panel UI
-- UI only: hook your own logic into the callbacks marked  >> HOOK <<

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local genv = (getgenv and getgenv()) or _G
genv.TiltedState = genv.TiltedState or { Power = 0, Bypass = false, AutoSteal = true, Mode = "PC" }

-- ================= theme =================
local C = {
	bg      = Color3.fromRGB(3, 3, 3),
	bgTop   = Color3.fromRGB(18, 18, 18),
	card    = Color3.fromRGB(12, 12, 12),
	stroke  = Color3.fromRGB(95, 95, 95),
	accent  = Color3.fromRGB(225, 225, 225),
	accent2 = Color3.fromRGB(145, 145, 145),
	text    = Color3.fromRGB(235, 235, 235),
	dim     = Color3.fromRGB(125, 125, 125),
	white   = Color3.fromRGB(255, 255, 255),
}
local FONT = Enum.Font.GothamBold
local FONT_BLACK = Enum.Font.GothamBlack

-- ================= helpers =================
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function corner(parent, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function stroke(parent, col, th, tr)
	return make("UIStroke", {
		Color = col, Thickness = th or 1, Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function label(parent, text, size, col, font, pos, sz, xAlign)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = col,
		Font = font or FONT,
		Position = pos or UDim2.new(0, 0, 0, 0),
		Size = sz or UDim2.new(1, 0, 1, 0),
		TextXAlignment = xAlign or Enum.TextXAlignment.Center,
	}, parent)
end

-- smooth gradient with a soft moving shine (text is set to white so the colours stay true)
local function smoothSeq(base, shine)
	local stops = { 0, 0.18, 0.36, 0.5, 0.64, 0.82, 1 }
	local amt   = { 0, 0.12, 0.6,  1,   0.6,  0.12, 0 }
	local ks = {}
	for i, t in ipairs(stops) do
		ks[i] = ColorSequenceKeypoint.new(t, base:Lerp(shine, amt[i]))
	end
	return ColorSequence.new(ks)
end

local function shimmer(textObj, base, shine, speed)
	textObj.TextColor3 = Color3.new(1, 1, 1)
	local monoBase = Color3.fromRGB(8, 8, 8)
	local monoShine = Color3.fromRGB(245, 245, 245)
	local g = make("UIGradient", { Color = smoothSeq(monoBase, monoShine) }, textObj)
	task.spawn(function()
		while textObj.Parent do
			g.Offset = Vector2.new(-1, 0)
			local tw = tween(g, speed or 2.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			tw.Completed:Wait()
		end
	end)
	return g
end

local function formatPower(n)
	if n >= 1000 then
		local k = n / 1000
		if k == math.floor(k) then return tostring(math.floor(k)) .. "K" end
		return string.format("%.1fK", k)
	end
	return tostring(n)
end

-- ================= gui root =================
local parentGui
pcall(function() parentGui = (gethui and gethui()) or game:GetService("CoreGui") end)
if not parentGui then parentGui = lp:WaitForChild("PlayerGui") end

local old = parentGui:FindFirstChild("Tilted_Panel")
if old then old:Destroy() end

local gui = make("ScreenGui", {
	Name = "Tilted_Panel", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parentGui)

local FULL_H = 428
local HEAD_H = 64

local main = make("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 258, 0, FULL_H),
	BackgroundColor3 = C.bg,
	ClipsDescendants = true,
}, gui)
corner(main, 24)

-- Monochrome cherry-blossom background (place hyd_bg.png beside this script)
local bgAsset
pcall(function()
    if type(getcustomasset) == "function" then
        bgAsset = getcustomasset("hyd_bg.png")
    end
end)
if bgAsset then
    make("ImageLabel", {
        Name = "HYD_Floral_Background",
        BackgroundTransparency = 1,
        Image = bgAsset,
        ScaleType = Enum.ScaleType.Crop,
        ImageTransparency = 0,
        ClipsDescendants = true,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        ZIndex = 0,
    }, main)
    corner(main:FindFirstChild("HYD_Floral_Background"), 24)
end
local darkWash = make("Frame", {
    Name = "DarkMonochromeWash",
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.80,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromScale(0, 0),
    ZIndex = 0,
}, main)
corner(darkWash, 24)
local mainStroke = stroke(main, C.stroke, 2)
mainStroke.Color = Color3.fromRGB(145, 145, 145)
mainStroke.LineJoinMode = Enum.LineJoinMode.Round
mainStroke.Thickness = 1.5
make("UIScale", { Scale = S }, main)
make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.bgTop),
		ColorSequenceKeypoint.new(0.16, C.bg),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 14)),
	}),
}, main)

-- ================= header =================
local header = make("Frame", {
	Name = "Header", BackgroundTransparency = 1,
	ZIndex = 10,
	Size = UDim2.new(1, 0, 0, HEAD_H),
}, main)

local lockBtn = make("TextButton", {
	Name = "Lock", AutoButtonColor = false, Text = "🔓", TextSize = 14,
	TextColor3 = Color3.fromRGB(255, 160, 40), Font = FONT,
	BackgroundColor3 = Color3.fromRGB(15, 15, 15),
	Position = UDim2.new(0, 14, 0, 16), Size = UDim2.new(0, 26, 0, 30),
}, header)
corner(lockBtn, 8)

local minBtn = make("TextButton", {
	Name = "Min", AutoButtonColor = false, Text = "-", TextSize = 16,
	TextColor3 = C.accent, Font = FONT,
	BackgroundColor3 = Color3.fromRGB(15, 15, 15),
	Position = UDim2.new(1, -40, 0, 16), Size = UDim2.new(0, 26, 0, 30),
}, header)
corner(minBtn, 8)

-- ================= HYD TITLE (CUSTOM CHROME PNG) =================
local titleAsset
pcall(function()
    if type(getcustomasset) == "function" then
        titleAsset = getcustomasset("hyd_title.png")
    end
end)

if titleAsset then
    make("ImageLabel", {
        Name = "HYD_Title",
        BackgroundTransparency = 1,
        Image = titleAsset,
        ScaleType = Enum.ScaleType.Fit,
        Position = UDim2.new(0, 38, 0, 5),
        Size = UDim2.new(1, -76, 0, 52),
        ImageTransparency = 0,
        ZIndex = 20,
    }, header)
else
    make("TextLabel", {
        Name = "HYD_Title_Fallback",
        BackgroundTransparency = 1,
        Text = "HYD",
        Font = Enum.Font.GothamBlack,
        TextSize = 37,
        TextColor3 = Color3.fromRGB(225, 225, 225),
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
        TextStrokeTransparency = 0.35,
        Position = UDim2.new(0, 42, 0, 5),
        Size = UDim2.new(1, -84, 0, 52),
        ZIndex = 5,
    }, header)
end

make("Frame", {
	Name = "Divider", BackgroundColor3 = C.stroke, BackgroundTransparency = 0.35,
	BorderSizePixel = 0, Position = UDim2.new(0, 8, 0, HEAD_H), Size = UDim2.new(1, -16, 0, 1),
}, main)

-- ================= body =================
local body = make("Frame", {
	Name = "Body", BackgroundTransparency = 1,
	ZIndex = 10,
	Position = UDim2.new(0, 0, 0, HEAD_H + 1), Size = UDim2.new(1, 0, 1, -(HEAD_H + 1)),
}, main)

local function row(y, h, x, w)
	local f = make("Frame", {
		BackgroundColor3 = C.card,
		Position = UDim2.new(0, x or 15, 0, y), Size = UDim2.new(0, w or 228, 0, h),
	}, body)
	corner(f, 9)
	stroke(f, C.stroke, 1.2, 0.1)
	return f
end

-- offset so rows match the video (body starts at y = 65)
local function Y(v) return v - (HEAD_H + 1) end

-- ---------- PC / MOBILE ----------
local modeRow = row(Y(76), 30)
local modeHi = make("Frame", {
	BackgroundColor3 = C.accent, Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.new(0.5, -3, 1, -6),
}, modeRow)
corner(modeHi, 7)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(220, 220, 220), Color3.fromRGB(115, 115, 115)) }, modeHi)

local pcBtn = make("TextButton", { BackgroundTransparency = 1, Text = "PC", TextSize = 10, Font = FONT, TextColor3 = C.dim,
	Size = UDim2.new(0.5, 0, 1, 0), AutoButtonColor = false }, modeRow)
local mobBtn = make("TextButton", { BackgroundTransparency = 1, Text = "MOBILE", TextSize = 10, Font = FONT, TextColor3 = C.white,
	Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), AutoButtonColor = false }, modeRow)

local PRESET = { PC = 97000, MOBILE = 72000 }
local setPower -- defined below

local mode = "MOBILE"
local function setMode(m)
	mode = m
	State.Mode = m
	genv.TiltedState.Mode = m
	if setPower then setPower(PRESET[m]) end
	local pc = (m == "PC")
	tween(modeHi, 0.2, { Position = UDim2.new(pc and 0 or 0.5, pc and 3 or 0, 0, 3) })
	tween(pcBtn, 0.2, { TextColor3 = pc and C.white or C.dim })
	tween(mobBtn, 0.2, { TextColor3 = pc and C.dim or C.white })
	-- >> HOOK << mode changed (m = "PC" / "MOBILE")
end
pcBtn.MouseButton1Click:Connect(function() setMode("PC") end)
mobBtn.MouseButton1Click:Connect(function() setMode("MOBILE") end)

-- ---------- POWER / STATUS cards ----------
local function statCard(x, big, small)
	local f = row(Y(115), 69, x, 111)
	local b = label(f, big, 20, C.text, FONT_BLACK, UDim2.new(0, 0, 0, 12), UDim2.new(1, 0, 0, 28))
	local g = shimmer(b, C.accent, Color3.fromRGB(240, 220, 255), 2.6)
	label(f, small, 8, C.dim, FONT, UDim2.new(0, 0, 0, 46), UDim2.new(1, 0, 0, 14)).TextColor3 = Color3.fromRGB(150, 150, 150)
	return b, g
end
local powerBig = statCard(15, "72K", "POWER")
local statusBig, statusGrad = statCard(132, "IDLE", "STATUS")

-- status text: "ON" (green) when the bypass is on, "IDLE" (purple) when it is off
local function setStatus(txt)
	statusBig.Text = txt
	if txt == "ON" then
		statusGrad.Color = smoothSeq(Color3.fromRGB(8, 8, 8), Color3.fromRGB(245, 245, 245))
	else
		statusGrad.Color = smoothSeq(Color3.fromRGB(8, 8, 8), Color3.fromRGB(245, 245, 245))
	end
end

-- ---------- toggle builder ----------
local function toggle(parent, x, y, w, h, startOn, onColor, callback)
	local track = make("TextButton", {
		AutoButtonColor = false, Text = "",
		BackgroundColor3 = startOn and C.accent2 or Color3.fromRGB(22, 22, 22),
		Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, w, 0, h),
	}, parent)
	corner(track, h)
	stroke(track, C.stroke, 1, 0.3)
	local d = h - 6
	local knob = make("Frame", {
		BackgroundColor3 = startOn and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(115, 115, 115),
		Size = UDim2.new(0, d, 0, d),
		Position = startOn and UDim2.new(1, -(d + 3), 0, 3) or UDim2.new(0, 3, 0, 3),
	}, track)
	corner(knob, d)
	local on = startOn
	local function setState(v)
		on = v
		tween(track, 0.18, { BackgroundColor3 = on and C.accent2 or Color3.fromRGB(22, 22, 22) })
		tween(knob, 0.18, {
			Position = on and UDim2.new(1, -(d + 3), 0, 3) or UDim2.new(0, 3, 0, 3),
			BackgroundColor3 = on and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(115, 115, 115),
		})
		if callback then callback(on) end
	end
	track.MouseButton1Click:Connect(function() setState(not on) end)
	return track, setState, function() return on end
end

-- ---------- AUTO ON STEAL ----------
local autoRow = row(Y(190), 32)
label(autoRow, "AUTO ON STEAL", 9, C.text, FONT, UDim2.new(0, 14, 0, 0), UDim2.new(0, 120, 1, 0), Enum.TextXAlignment.Left)
local refreshAuto -- defined below
local _, setAutoState, getAuto = toggle(autoRow, 174, 6, 42, 20, false, nil, function(on)
	genv.TiltedState.AutoSteal = on
	-- >> HOOK << auto on steal toggled (on = true/false)
	if refreshAuto then refreshAuto() end
end)
genv.TiltedState.AutoSteal = false

-- ---------- V1 / V2 ----------
local verRow = row(Y(228), 31)
local verHi = make("Frame", {
	BackgroundColor3 = C.accent, Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0.5, -3, 1, -6),
}, verRow)
corner(verHi, 7)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(220, 220, 220), Color3.fromRGB(115, 115, 115)) }, verHi)
local v1 = make("TextButton", { BackgroundTransparency = 1, Text = "V1", TextSize = 10, Font = FONT, TextColor3 = C.white,
	Size = UDim2.new(0.5, 0, 1, 0), AutoButtonColor = false }, verRow)
local v2 = make("TextButton", { BackgroundTransparency = 1, Text = "V2", TextSize = 10, Font = FONT, TextColor3 = C.dim,
	Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), AutoButtonColor = false }, verRow)
local version = "V1"
local function setVersion(v)
	version = v
	local one = (v == "V1")
	tween(verHi, 0.2, { Position = UDim2.new(one and 0 or 0.5, one and 3 or 0, 0, 3) })
	tween(v1, 0.2, { TextColor3 = one and C.white or C.dim })
	tween(v2, 0.2, { TextColor3 = one and C.dim or C.white })
	-- >> HOOK << version changed (v = "V1" / "V2")
end
v1.MouseButton1Click:Connect(function() setVersion("V1") end)
v2.MouseButton1Click:Connect(function() setVersion("V2") end)

-- ---------- power amount  - 50000 + ----------
local power = PRESET.MOBILE
local STEP = 5000
local powerRow = row(Y(265), 37)
local powerNum = make("TextBox", {
    BackgroundTransparency = 1,
    ClearTextOnFocus = false,
    Text = tostring(power),
    TextSize = 17,
    TextColor3 = Color3.new(1, 1, 1),
    Font = FONT_BLACK,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    Position = UDim2.new(0, 40, 0, 0),
    Size = UDim2.new(1, -80, 1, 0),
}, powerRow)
shimmer(powerNum, C.accent, Color3.fromRGB(240, 220, 255), 2.8)

local function stepBtn(txt, x)
	local b = make("TextButton", {
		AutoButtonColor = false, Text = txt, TextSize = 16, Font = FONT_BLACK, TextColor3 = C.accent,
		BackgroundColor3 = Color3.fromRGB(18, 18, 18), Position = UDim2.new(0, x, 0, 3), Size = UDim2.new(0, 34, 1, -6),
	}, powerRow)
	corner(b, 8)
	return b
end
local minus, plus = stepBtn("-", 4), stepBtn("+", 190)
function setPower(n)
	power = math.clamp(math.floor(n), 9000, 500000)
	applyPower(power)
	genv.TiltedState.Power = State.Power
	power = State.Power
	powerNum.Text = tostring(power)
	powerBig.Text = formatPower(power)
end
minus.MouseButton1Click:Connect(function() setPower(power - STEP) end)
plus.MouseButton1Click:Connect(function() setPower(power + STEP) end)
powerNum.FocusLost:Connect(function()
    local entered = tonumber((powerNum.Text:gsub(",", "")))
    if entered then
        setPower(entered)
    else
        powerNum.Text = tostring(power)
    end
end)

-- ---------- KEY [C] EDIT ----------
local keyRow = row(Y(309), 31)
label(keyRow, "KEY", 9, Color3.fromRGB(150, 150, 150), FONT, UDim2.new(0, 14, 0, 0), UDim2.new(0, 40, 1, 0), Enum.TextXAlignment.Left)
local keyLbl = label(keyRow, "[" .. State.Keybind.Name .. "]", 13, C.text, FONT_BLACK, UDim2.new(0, 60, 0, 0), UDim2.new(0, 100, 1, 0))
local editBtn = make("TextButton", {
	AutoButtonColor = false, Text = "EDIT", TextSize = 9, Font = FONT_BLACK, TextColor3 = C.white,
	BackgroundColor3 = Color3.fromRGB(15, 15, 15), Position = UDim2.new(1, -62, 0, 3), Size = UDim2.new(0, 58, 1, -6),
}, keyRow)
corner(editBtn, 8)

local bindKey = State.Keybind
local listening = false
local _, setBypassState, getBypass
editBtn.MouseButton1Click:Connect(function()
	if listening then return end
	listening = true
	editBtn.Text = "..."
	local conn
	conn = UserInputService.InputBegan:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.Unknown then
				bindKey = input.KeyCode
				State.Keybind = bindKey
				keyLbl.Text = "[" .. input.KeyCode.Name .. "]"
			end
			editBtn.Text = "EDIT"
			listening = false
			conn:Disconnect()
		end
	end)
end)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp or listening then return end
	if input.KeyCode == bindKey and setBypassState and getBypass then
		setBypassState(not getBypass())
	end
end)

-- ---------- ENABLE BYPASS ----------
local bypassBtn = make("Frame", {
	BackgroundColor3 = C.accent2, Position = UDim2.new(0, 15, 0, Y(347)), Size = UDim2.new(0, 228, 0, 38),
}, body)
corner(bypassBtn, 10)
make("UIGradient", { Rotation = 45, Color = ColorSequence.new(Color3.fromRGB(170, 170, 170), Color3.fromRGB(75, 75, 75)) }, bypassBtn)
local bypassTxt = label(bypassBtn, "ENABLE BYPASS", 10, Color3.fromRGB(232, 232, 232), FONT_BLACK,
	UDim2.new(0, 14, 0, 0), UDim2.new(0, 150, 1, 0), Enum.TextXAlignment.Left)
shimmer(bypassTxt, Color3.fromRGB(232, 232, 232), C.white, 2.6)
-- =====================================================================
-- YOUR LOGIC  -  paste your code inside these three functions.
-- They are connected to ENABLE BYPASS automatically, so they run no matter how it
-- gets switched (the switch itself, AUTO ON STEAL, or any other code):
--   OnEnable   runs once when the bypass turns ON
--   OnDisable  runs once when the bypass turns OFF
--   Loop       runs every frame while the bypass is ON (leave it empty if you don't need it)
-- ctx gives you:
--   ctx.Player              your player
--   ctx.Character()         your current character (or nil)
--   ctx.GetPower()          the power number on the panel (e.g. 72000)
--   ctx.GetMode()           "PC" or "MOBILE"
--   ctx.GetVersion()        "V1" or "V2"
--   ctx.IsHolding()         true while you are holding / carrying something
--   ctx.SetStatus("TEXT")   change the STATUS box text yourself (optional)
-- =====================================================================

-- (nothing to edit below this line in this section: it wires the functions above to the switch)
local RunService = game:GetService("RunService")
local ctx = {
	Player = lp,
	Character = function() return lp.Character end,
	GetPower = function() return power end,
	GetMode = function() return mode end,
	GetVersion = function() return version end,
	IsHolding = function() return false end, -- replaced below once the hold check exists
	SetStatus = setStatus,
}

local Logic = {
	OnEnable = function()
		State.Active = true
		startLag()
	end,
	OnDisable = function()
		State.Active = false
		stopLag()
	end,
	Loop = function() end,
}

local loopConn
local function safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then warn("[HYD] your logic error: " .. tostring(err)) end
end

local function runBypassLogic(on)
	if loopConn then loopConn:Disconnect() loopConn = nil end
	if on then
		safe(Logic.OnEnable, ctx)
		loopConn = RunService.Heartbeat:Connect(function(dt)
			if not gui.Parent then runBypassLogic(false) return end
			safe(Logic.Loop, ctx, dt)
		end)
	else
		safe(Logic.OnDisable, ctx)
	end
end

local autoBusy = false
local autoTurnedOn = false
_, setBypassState, getBypass = toggle(bypassBtn, 172, 9, 44, 20, false, nil, function(on)
	if not autoBusy then autoTurnedOn = false end -- a manual click takes over
	genv.TiltedState.Bypass = on
	setStatus(on and "ON" or "IDLE")
	runBypassLogic(on) -- runs YOUR LOGIC (OnEnable / OnDisable / Loop)
end)

-- ---------- footer ----------
local foot = label(body, "discord.gg/hyd", 8, C.dim, FONT, UDim2.new(0, 0, 0, Y(406)), UDim2.new(1, 0, 0, 14))
shimmer(foot, C.dim, Color3.fromRGB(190, 190, 190), 3)

-- ================= auto on steal: bypass switches on while you hold something =================
-- (only when AUTO ON STEAL is on; turns off again when you let go)
local HOLD_DEBUG   = true   -- prints "[HYD] holding: ..." in the console whenever the hold state changes
local CUSTOM_NAMES = {}     -- add exact names here once you know them, e.g. { "BrainrotModel" }
local HOLD_WORDS   = { "stealing", "carrying", "carry", "holding" } -- attribute names that count when set to true

local trackedChar, trackUntil, lastReason = nil, 0, nil
local baseline = {}

local function attrReason(inst, label)
	for name, v in pairs(inst:GetAttributes()) do
		if v == true then
			local n = string.lower(name)
			for _, w in ipairs(HOLD_WORDS) do
				if string.find(n, w, 1, true) then return label .. " attribute " .. name end
			end
		end
	end
	return nil
end

-- returns a text reason when you are holding / carrying something, or nil when you are not
local function holdingReason()
	local char = lp.Character
	if not char then return nil end

	-- every new character gets a short "settle" time; everything on it then counts as normal
	if char ~= trackedChar then
		trackedChar = char
		trackUntil = os.clock() + 2.5
		baseline = {}
	end
	local children = char:GetChildren()
	if os.clock() < trackUntil then
		for _, c in ipairs(children) do baseline[c] = true end
		return nil
	end

	-- 1) a Tool equipped in your hand
	if char:FindFirstChildOfClass("Tool") then return "Tool equipped" end

	-- 2) names you added yourself
	for _, n in ipairs(CUSTOM_NAMES) do
		if char:FindFirstChild(n) then return "found " .. n end
	end

	-- 3) attributes like Stealing / Carrying set to true on you or your character
	local r = attrReason(char, "character") or attrReason(lp, "player")
	if r then return r end

	-- 4) something new attached to your character after it settled (model, accessory or part)
	for _, c in ipairs(children) do
		if not baseline[c] and (c:IsA("Model") or c:IsA("Accessory") or c:IsA("BasePart")) then
			return "new item on character: " .. c.Name
		end
	end
	return nil
end

local function isHolding()
	local r = holdingReason()
	if HOLD_DEBUG and r ~= lastReason then
		lastReason = r
		print("[HYD] holding: " .. tostring(r or "nothing"))
	end
	return r ~= nil
end
ctx.IsHolding = isHolding

local lastShould = false
function refreshAuto()
	local should = getAuto() and isHolding()
	if should == lastShould then return end
	lastShould = should
	if should then
		if not getBypass() then
			autoBusy = true
			autoTurnedOn = true
			setBypassState(true)
			autoBusy = false
		end
	elseif autoTurnedOn then
		autoBusy = true
		autoTurnedOn = false
		if getBypass() then setBypassState(false) end
		autoBusy = false
	end
end

task.spawn(function()
	while gui.Parent do
		pcall(refreshAuto)
		task.wait(0.1)
	end
end)

-- start with the right preset for this device (PC 100K / MOBILE 72K)
setMode(UserInputService.TouchEnabled and "MOBILE" or "PC")

-- Solid monochrome border; no animated gradient.

-- ================= minimize =================
local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	minBtn.Text = minimized and "+" or "-"
	tween(main, 0.25, { Size = UDim2.new(0, 258, 0, minimized and (HEAD_H + 1) or FULL_H) })
end)

-- ================= lock + drag =================
local locked = false
lockBtn.MouseButton1Click:Connect(function()
	locked = not locked
	lockBtn.Text = locked and "🔒" or "🔓"
end)

local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
	if locked then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local d = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
