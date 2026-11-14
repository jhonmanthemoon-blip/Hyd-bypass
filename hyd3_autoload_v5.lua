-- HYD panel UI
-- UI only: hook your own logic into the callbacks marked  >> HOOK <<

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local genv = (getgenv and getgenv()) or _G
genv.TiltedState = genv.TiltedState or { Power = 0, Bypass = false, AutoSteal = true, Mode = "PC" }

-- ================= assets (auto download from GitHub -> executor workspace) =================
-- Upload hyd_bg.png + hyd_intro.mp3 to the SAME GitHub folder as this script.
-- On every run, any missing file is downloaded and saved into your executor's workspace folder.
local ASSET_BASE = "https://raw.githubusercontent.com/jhonmanthemoon-blip/Hyd-bypass/refs/heads/main/"
local REFRESH_ASSETS = false -- true = re-download both files every run (use after you change them on GitHub)
local PLAY_INTRO = true      -- plays hyd_intro.mp3 once when the panel loads

local canFiles = (isfile and writefile and readfile) and true or false

local function httpGet(url)
	local ok, res = pcall(function() return game:HttpGet(url, true) end)
	if ok and type(res) == "string" and #res > 0 and res:sub(1, 3) ~= "404" then return res end
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if req then
		local ok2, r = pcall(req, { Url = url, Method = "GET" })
		if ok2 and type(r) == "table" and r.Body and #r.Body > 0 and (r.StatusCode == nil or r.StatusCode == 200) then
			return r.Body
		end
	end
	return nil
end

-- makes sure `name` exists in the workspace (downloads it if not). returns true when it is there.
local function ensureAsset(name)
	if not canFiles then return false end
	if not REFRESH_ASSETS then
		local ok, exists = pcall(function() return isfile(name) and #readfile(name) > 0 end)
		if ok and exists then return true end
	end
	for _ = 1, 3 do
		local data = httpGet(ASSET_BASE .. name)
		if data and pcall(writefile, name, data) then return true end
		task.wait(0.6)
	end
	warn("[HYD] could not download " .. name .. " - make sure it is uploaded to GitHub with that exact name")
	return false
end

local function asset(name)
	local ok, id = pcall(function()
		return (getcustomasset or getsynasset)(name)
	end)
	if ok and id then return id end
	return nil
end

ensureAsset("hyd_bg.png") -- needed before the UI is built

-- ================= theme (black / white / gray) =================
local C = {
	bg      = Color3.fromRGB(5, 5, 5),
	bgTop   = Color3.fromRGB(28, 28, 28),
	card    = Color3.fromRGB(11, 11, 11),
	stroke  = Color3.fromRGB(78, 78, 78),
	accent  = Color3.fromRGB(205, 205, 205),
	accent2 = Color3.fromRGB(38, 38, 38),
	text    = Color3.fromRGB(255, 255, 255),
	dim     = Color3.fromRGB(208, 208, 208),
	gDark   = Color3.fromRGB(188, 188, 188), -- dark end of the text gradient
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

-- glossy dark-grey button: light top -> dark bottom, soft gloss band on the top half
local function glossBtn(btn, rad)
	btn.BackgroundTransparency = 1
	btn.ZIndex = 2
	local fill = make("Frame", {
		Name = "GlossFill", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		Position = btn.Position, Size = btn.Size, ZIndex = 1,
	}, btn.Parent)
	corner(fill, rad)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(84, 84, 84)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(46, 46, 46)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 20)),
		}),
	}, fill)
	local gloss = make("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0,
		Position = UDim2.new(0, 2, 0, 2), Size = UDim2.new(1, -4, 0.45, 0),
	}, fill)
	corner(gloss, rad)
	return fill
end

-- small white bar on top of a selected segment (like the LOW / MED / HIGH buttons)
local function topBar(hi)
	local bar = make("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.new(0.4, 0, 0, 2),
	}, hi)
	corner(bar, 1)
end

local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local rng = Random.new()

local function label(parent, text, size, col, font, pos, sz, xAlign)
	local lbl = make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = col,
		Font = font or FONT,
		Position = pos or UDim2.new(0, 0, 0, 0),
		Size = sz or UDim2.new(1, 0, 1, 0),
		TextXAlignment = xAlign or Enum.TextXAlignment.Center,
	}, parent)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, lbl)
	return lbl
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
	local g = make("UIGradient", { Color = smoothSeq(base, shine) }, textObj)
	task.spawn(function()
		while textObj.Parent do
			g.Offset = Vector2.new(-1, 0)
			local tw = tween(g, speed or 2.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			tw.Completed:Wait()
		end
	end)
	return g
end

-- ================= ON-state gradient (silver sweep) =================
-- bright silver -> silver -> dark gray, flowing back and forth
-- change these 3 shades to restyle every "ON" gradient at once
local FLOW = {
	Color3.fromRGB(245, 245, 245), -- bright silver
	Color3.fromRGB(178, 178, 178), -- silver
	Color3.fromRGB(78, 78, 78),    -- dark gray
}
local function flowSeq()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0,    FLOW[1]),
		ColorSequenceKeypoint.new(0.25, FLOW[2]),
		ColorSequenceKeypoint.new(0.5,  FLOW[3]),
		ColorSequenceKeypoint.new(0.75, FLOW[2]),
		ColorSequenceKeypoint.new(1,    FLOW[1]),
	})
end

-- adds a gradient that slides forever; starts switched off (Enabled = false)
local function addFlow(parent, speed)
	local g = make("UIGradient", { Color = flowSeq(), Enabled = false }, parent)
	task.spawn(function()
		while parent.Parent do
			g.Offset = Vector2.new(-1, 0)
			tween(g, speed or 2.4, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Linear).Completed:Wait()
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
corner(main, 14)
local mainStroke = stroke(main, Color3.new(1, 1, 1), 1.5)
local borderGrad = make("UIGradient", { Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C.accent),
	ColorSequenceKeypoint.new(0.5, C.stroke),
	ColorSequenceKeypoint.new(1, C.accent),
}) }, mainStroke)
make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.bgTop),
		ColorSequenceKeypoint.new(0.16, C.bg),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(3, 3, 3)),
	}),
}, main)

-- ================= background image + dark shade =================
local bgLayer = make("Frame", {
	Name = "BgLayer", BackgroundTransparency = 1, BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 1, 0), ZIndex = 0,
}, main)
local bgImg = asset("hyd_bg.png")
if bgImg then
	local img = make("ImageLabel", {
		Name = "Bg", BackgroundTransparency = 1, Image = bgImg,
		ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.05,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 1,
	}, bgLayer)
	corner(img, 14)
end
local shade = make("Frame", {
	Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 1, 0), ZIndex = 2,
}, bgLayer)
corner(shade, 14)
make("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.5, 0.62),
		NumberSequenceKeypoint.new(1, 0.4),
	}),
}, shade)

-- ================= background particles =================
bgLayer.ClipsDescendants = true
local particles = make("Frame", {
	Name = "Particles", BackgroundTransparency = 1, BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 1, 0), ZIndex = 3,
}, bgLayer)
for i = 1, 20 do
	local sz = rng:NextInteger(2, 4)
	local p = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(210, 210, 210), BorderSizePixel = 0,
		Size = UDim2.new(0, sz, 0, sz), BackgroundTransparency = 1, ZIndex = 3,
	}, particles)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, p)
	task.spawn(function()
		task.wait(rng:NextNumber(0, 6))
		while p.Parent do
			local x = rng:NextNumber(0.02, 0.98)
			local dur = rng:NextNumber(6, 12)
			local peak = rng:NextNumber(0.5, 0.8)
			p.Position = UDim2.new(x, 0, 1.03, 0)
			p.BackgroundTransparency = 1
			tween(p, dur, { Position = UDim2.new(math.clamp(x + rng:NextNumber(-0.12, 0.12), 0, 1), 0, -0.05, 0) }, Enum.EasingStyle.Linear)
			tween(p, dur * 0.2, { BackgroundTransparency = peak }, Enum.EasingStyle.Sine).Completed:Wait()
			task.wait(dur * 0.6)
			tween(p, dur * 0.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine).Completed:Wait()
		end
	end)
end

-- ================= header =================
local header = make("Frame", {
	Name = "Header", BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, HEAD_H),
}, main)

local lockBtn = make("TextButton", {
	Name = "Lock", AutoButtonColor = false, Text = "◇", TextSize = 14,
	TextColor3 = Color3.new(1, 1, 1), Font = FONT,
	BackgroundColor3 = Color3.fromRGB(16, 16, 16),
	Position = UDim2.new(0, 14, 0, 16), Size = UDim2.new(0, 26, 0, 30),
}, header)
corner(lockBtn, 8)
stroke(lockBtn, Color3.fromRGB(90, 90, 90), 1, 0.4)
glossBtn(lockBtn, 8)

local minBtn = make("TextButton", {
	Name = "Min", AutoButtonColor = false, Text = "-", TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1), Font = FONT,
	BackgroundColor3 = Color3.fromRGB(16, 16, 16),
	Position = UDim2.new(1, -40, 0, 16), Size = UDim2.new(0, 26, 0, 30),
}, header)
corner(minBtn, 8)
stroke(minBtn, Color3.fromRGB(90, 90, 90), 1, 0.4)
glossBtn(minBtn, 8)

-- ================= HYD TITLE =================
local title = make("TextLabel", {
	Name = "HYD_Title",
	BackgroundTransparency = 1,
	Text = "HYD",
	Font = Enum.Font.GothamBlack,
	TextSize = 30,
	TextColor3 = Color3.new(1, 1, 1),
	Rotation = 0,
	Position = UDim2.new(0, 46, 0, 9),
	Size = UDim2.new(1, -92, 0, 32),
}, header)
label(header, "CONTROL PANEL", 8, C.dim, FONT, UDim2.new(0, 46, 0, 40), UDim2.new(1, -92, 0, 12))
make("UIStroke", {
	Color = Color3.fromRGB(0, 0, 0), Thickness = 1.5, Transparency = 0.2,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
}, title)
local titleGrad = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(190, 190, 190)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(235, 235, 235)),
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(235, 235, 235)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(190, 190, 190)),
	}),
}, title)
task.spawn(function()
	while title.Parent do
		titleGrad.Offset = Vector2.new(-1, 0)
		tween(titleGrad, 3.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine).Completed:Wait()
	end
end)

make("Frame", {
	Name = "Divider", BackgroundColor3 = C.stroke, BackgroundTransparency = 0.35,
	BorderSizePixel = 0, Position = UDim2.new(0, 8, 0, HEAD_H), Size = UDim2.new(1, -16, 0, 1),
}, main)

-- ================= body =================
local body = make("Frame", {
	Name = "Body", BackgroundTransparency = 1,
	Position = UDim2.new(0, 0, 0, HEAD_H + 1), Size = UDim2.new(1, 0, 1, -(HEAD_H + 1)),
}, main)

local function row(y, h, x, w)
	local f = make("Frame", {
		BackgroundColor3 = C.card, BackgroundTransparency = 0.3,
		Position = UDim2.new(0, x or 15, 0, y), Size = UDim2.new(0, w or 228, 0, h),
	}, body)
	corner(f, 8)
	stroke(f, C.stroke, 1.2, 0.1)
	return f
end

-- offset so rows match the video (body starts at y = 65)
local function Y(v) return v - (HEAD_H + 1) end

-- ---------- PC / MOBILE ----------
local modeRow = row(Y(76), 30)
local modeHi = make("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.new(0.5, -3, 1, -6),
}, modeRow)
corner(modeHi, 7)
stroke(modeHi, Color3.new(1, 1, 1), 1.6, 0)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(84, 84, 84), Color3.fromRGB(26, 26, 26)) }, modeHi)
topBar(modeHi)

local pcBtn = make("TextButton", { BackgroundTransparency = 1, Text = "PC", TextSize = 10, Font = FONT, TextColor3 = C.dim,
	Size = UDim2.new(0.5, 0, 1, 0), AutoButtonColor = false }, modeRow)
local mobBtn = make("TextButton", { BackgroundTransparency = 1, Text = "MOBILE", TextSize = 10, Font = FONT, TextColor3 = C.white,
	Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), AutoButtonColor = false }, modeRow)

local PRESET = { PC = 100000, MOBILE = 72000 }
local setPower -- defined below

local mode = "MOBILE"
local function setMode(m)
	mode = m
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
	local g = shimmer(b, C.gDark, C.white, 2.6)
	label(f, small, 8, C.dim, FONT, UDim2.new(0, 0, 0, 46), UDim2.new(1, 0, 0, 14)).TextColor3 = C.dim
	return b, g
end
local powerBig = statCard(15, "72K", "POWER")
local statusBig, statusGrad = statCard(132, "IDLE", "STATUS")

-- status text: "ON" (bright) when the bypass is on, "IDLE" (gray) when it is off
local function setStatus(txt)
	statusBig.Text = txt
	if txt == "ON" then
		statusGrad.Color = smoothSeq(Color3.fromRGB(200, 200, 200), C.white)
	else
		statusGrad.Color = smoothSeq(C.gDark, C.white)
	end
end

-- ---------- toggle builder (flowing gradient + glowing border when ON) ----------
local T_ON, T_OFF = Color3.new(1, 1, 1), Color3.fromRGB(22, 22, 22)
local K_ON, K_OFF = Color3.fromRGB(10, 10, 10), Color3.fromRGB(128, 128, 128)
local function toggle(parent, x, y, w, h, startOn, onColor, callback)
	local track = make("TextButton", {
		AutoButtonColor = false, Text = "",
		BackgroundColor3 = startOn and T_ON or T_OFF,
		Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, w, 0, h),
	}, parent)
	corner(track, 10)
	local trackStroke = stroke(track, C.stroke, 1, 0.2)
	local trackFlow = addFlow(track, 2.4)
	local strokeFlow = addFlow(trackStroke, 2.4)
	local d = h - 6
	local knob = make("Frame", {
		BackgroundColor3 = startOn and K_ON or K_OFF,
		Size = UDim2.new(0, d, 0, d),
		Position = startOn and UDim2.new(1, -(d + 3), 0, 3) or UDim2.new(0, 3, 0, 3),
	}, track)
	corner(knob, 7)
	local on = startOn
	local function paint()
		trackFlow.Enabled = on
		strokeFlow.Enabled = on
		trackStroke.Color = on and C.accent or C.stroke
		trackStroke.Transparency = on and 0 or 0.2
		trackStroke.Thickness = on and 1.6 or 1
	end
	paint()
	local function setState(v)
		on = v
		paint()
		tween(track, 0.18, { BackgroundColor3 = on and T_ON or T_OFF })
		tween(knob, 0.18, {
			Position = on and UDim2.new(1, -(d + 3), 0, 3) or UDim2.new(0, 3, 0, 3),
			BackgroundColor3 = on and K_ON or K_OFF,
		})
		if callback then callback(on) end
	end
	track.MouseButton1Click:Connect(function() setState(not on) end)
	return track, setState, function() return on end
end

-- ---------- AUTO ON STEAL ----------
local autoRow = row(Y(190), 32)
shimmer(label(autoRow, "AUTO ON STEAL", 9, C.text, FONT, UDim2.new(0, 14, 0, 0), UDim2.new(0, 120, 1, 0), Enum.TextXAlignment.Left), C.gDark, C.white, 3)
local refreshAuto -- defined below
local _, setAutoState, getAuto = toggle(autoRow, 174, 6, 42, 20, true, nil, function(on)
	genv.TiltedState.AutoSteal = on
	-- >> HOOK << auto on steal toggled (on = true/false)
	if refreshAuto then refreshAuto() end
end)
genv.TiltedState.AutoSteal = true

-- ---------- V1 / V2 ----------
local verRow = row(Y(228), 31)
local verHi = make("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0.5, -3, 1, -6),
}, verRow)
corner(verHi, 7)
stroke(verHi, Color3.new(1, 1, 1), 1.6, 0)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(84, 84, 84), Color3.fromRGB(26, 26, 26)) }, verHi)
topBar(verHi)
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
local powerNum = label(powerRow, tostring(power), 17, C.text, FONT_BLACK, UDim2.new(0, 40, 0, 0), UDim2.new(1, -80, 1, 0))
shimmer(powerNum, C.gDark, C.white, 2.8)

local function stepBtn(txt, x)
	local b = make("TextButton", {
		AutoButtonColor = false, Text = txt, TextSize = 16, Font = FONT_BLACK, TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(16, 16, 16), Position = UDim2.new(0, x, 0, 3), Size = UDim2.new(0, 34, 1, -6),
	}, powerRow)
	corner(b, 8)
	stroke(b, Color3.fromRGB(90, 90, 90), 1, 0.4)
	glossBtn(b, 8)
	return b
end
local minus, plus = stepBtn("-", 4), stepBtn("+", 190)
function setPower(n)
	power = math.clamp(n, STEP, 1000000)
	genv.TiltedState.Power = power
	powerNum.Text = tostring(power)
	powerBig.Text = formatPower(power)
	-- >> HOOK << power changed (power = number)
end
minus.MouseButton1Click:Connect(function() setPower(power - STEP) end)
plus.MouseButton1Click:Connect(function() setPower(power + STEP) end)

-- ---------- KEY [C] EDIT ----------
local keyRow = row(Y(309), 31)
label(keyRow, "KEY", 9, C.dim, FONT, UDim2.new(0, 14, 0, 0), UDim2.new(0, 40, 1, 0), Enum.TextXAlignment.Left)
local keyLbl = label(keyRow, "[C]", 13, C.text, FONT_BLACK, UDim2.new(0, 60, 0, 0), UDim2.new(0, 100, 1, 0))
shimmer(keyLbl, C.gDark, C.white, 2.8)
local editBtn = make("TextButton", {
	AutoButtonColor = false, Text = "EDIT", TextSize = 9, Font = FONT_BLACK, TextColor3 = C.white,
	BackgroundColor3 = Color3.fromRGB(16, 16, 16), Position = UDim2.new(1, -62, 0, 3), Size = UDim2.new(0, 58, 1, -6),
}, keyRow)
corner(editBtn, 8)
stroke(editBtn, Color3.fromRGB(90, 90, 90), 1, 0.4)
glossBtn(editBtn, 8)

local bindKey = Enum.KeyCode.C
local listening = false
editBtn.MouseButton1Click:Connect(function()
	if listening then return end
	listening = true
	editBtn.Text = "..."
	local conn
	conn = UserInputService.InputBegan:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			bindKey = input.KeyCode
			keyLbl.Text = "[" .. input.KeyCode.Name .. "]"
			editBtn.Text = "EDIT"
			listening = false
			conn:Disconnect()
		end
	end)
end)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp or listening then return end
	if input.KeyCode == bindKey then
		-- >> HOOK << keybind pressed
	end
end)

-- ---------- ENABLE BYPASS ----------
local bypassBtn = make("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.new(0, 15, 0, Y(347)), Size = UDim2.new(0, 228, 0, 38),
}, body)
corner(bypassBtn, 9)
local bypassStroke = stroke(bypassBtn, C.stroke, 1.2, 0.1)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 70, 70), Color3.fromRGB(28, 28, 28)) }, bypassBtn)
-- flowing colour layer that fades in over the bar when bypass is ON (sits under the text)
local barGlow = make("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 1, 0),
}, bypassBtn)
corner(barGlow, 9)
local barFlow = addFlow(barGlow, 3)
local barStrokeFlow = addFlow(bypassStroke, 2.4)
local function setBarGlow(on)
	barFlow.Enabled = on
	barStrokeFlow.Enabled = on
	bypassStroke.Color = on and C.accent or C.stroke
	bypassStroke.Transparency = on and 0 or 0.1
	bypassStroke.Thickness = on and 1.8 or 1.2
	tween(barGlow, 0.3, { BackgroundTransparency = on and 0.55 or 1 })
end
local bypassTxt = label(bypassBtn, "ENABLE BYPASS", 10, C.text, FONT_BLACK,
	UDim2.new(0, 14, 0, 0), UDim2.new(0, 150, 1, 0), Enum.TextXAlignment.Left)
shimmer(bypassTxt, C.gDark, C.white, 2.6)
-- =====================================================================
-- YOUR LOGIC
-- Put your own non-destructive client-side callbacks in these two functions:
--   OnToggle(ctx, enabled) runs once whenever bypass changes:
--       enabled = true  when switched ON
--       enabled = false when switched OFF
--   Loop(ctx, dt) runs on Heartbeat while bypass is ON.
--
-- Shared state belongs in Logic.State. It is kept between callbacks.
-- ctx.GetPower()       = current power value shown by the panel.
-- ctx.GetModePower()   = default power for the selected mode (PC 100000 /
--                        MOBILE 72000), even if the +/- buttons changed power.
-- ctx.GetMode()        = "PC" or "MOBILE".
-- ctx.GetVersion()     = "V1" or "V2".
-- ctx.IsHolding()      = current hold/carry detection result.
-- ctx.SetStatus(text)  = update the status card.
-- =====================================================================

local Logic = {
	State = {},

	OnToggle = function(ctx, enabled)
		-- One callback handles BOTH states.
		if enabled then
			-- Bypass was enabled.
			ctx.SetStatus("ON")
		else
			-- Bypass was disabled; reset shared state if needed.
			Logic.State = {}
			ctx.SetStatus("IDLE")
		end
	end,

	Loop = function(ctx, dt)
		-- Repeats while bypass is ON. Keep this short; it runs every frame.
		-- Example: local currentPower = ctx.GetPower()
	end,
}

-- (Wiring below connects the callbacks above to the bypass switch.)
local RunService = game:GetService("RunService")
local ctx = {
	Player = lp,
	Character = function() return lp.Character end,
	GetPower = function() return power end,
	GetMode = function() return mode end,
	GetModePower = function()
		return PRESET[mode] or PRESET.MOBILE
	end,
	GetVersion = function() return version end,
	IsHolding = function() return false end, -- replaced below once hold detection exists
	SetStatus = setStatus,
}

local loopConn
local logicEnabled = false

local function safe(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[HYD] logic error: " .. tostring(err)) end
end

-- Stops only the repeating Heartbeat loop; bypass state stays unchanged.
local function stopLoop()
	if loopConn then
		loopConn:Disconnect()
		loopConn = nil
	end
end

-- Starts the repeating loop if bypass is enabled and no loop is running.
local function startLoop()
	if not logicEnabled or loopConn then return end
	loopConn = RunService.Heartbeat:Connect(function(dt)
		if not gui.Parent then
			stopLoop()
			return
		end
		if logicEnabled then safe(Logic.Loop, ctx, dt) end
	end)
end

-- Expose controls to your callbacks: ctx.StopLoop() / ctx.StartLoop().
ctx.StopLoop = stopLoop
ctx.StartLoop = startLoop

local function runBypassLogic(on)
	-- Ignore duplicate requests so enable/disable callbacks only run once.
	if on == logicEnabled then return end
	logicEnabled = on

	if on then
		safe(Logic.OnToggle, ctx, true)
		startLoop()
	else
		stopLoop()
		safe(Logic.OnToggle, ctx, false)
	end
end

local autoBusy = false
local autoTurnedOn = false
local _, setBypassState, getBypass = toggle(bypassBtn, 172, 9, 44, 20, false, nil, function(on)
	if not autoBusy then autoTurnedOn = false end -- a manual click takes over
	genv.TiltedState.Bypass = on
	setStatus(on and "ON" or "IDLE")
	setBarGlow(on)
	runBypassLogic(on) -- runs YOUR LOGIC (OnToggle / Loop)
end)

-- ---------- footer ----------
local foot = label(body, "discord.gg/hyd", 8, C.dim, FONT, UDim2.new(0, 0, 0, Y(406)), UDim2.new(1, 0, 0, 14))
shimmer(foot, C.gDark, C.white, 3)

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

-- ================= animated border (slow rotating blue gradient) =================
task.spawn(function()
	while main.Parent do
		borderGrad.Rotation = 0
		tween(borderGrad, 5, { Rotation = 360 }, Enum.EasingStyle.Linear).Completed:Wait()
	end
end)

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
	lockBtn.Text = locked and "◆" or "◇"
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

-- ================= intro sound (downloads in the background, plays when ready) =================
if PLAY_INTRO then
	task.spawn(function()
		if not ensureAsset("hyd_intro.mp3") then return end
		local id = asset("hyd_intro.mp3")
		if not id then return end
		local snd = Instance.new("Sound")
		snd.Name = "HYD_Intro"
		snd.SoundId = id
		snd.Volume = 1
		snd.Parent = game:GetService("SoundService")
		snd:Play()
		snd.Ended:Connect(function() snd:Destroy() end)
	end)
end
