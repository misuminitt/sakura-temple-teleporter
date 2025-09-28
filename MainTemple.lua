--[[ 
Sakura Temple Teleporter (Executor-Compatible)
- Stripped Luau type annotations (pure Lua)
- GUI auto-parent ke CoreGui/gethui() agar muncul saat loadstring
- Fitur: Tabs (Main / Settings / Checkpoint), Start/Stop, Pause/Resume, Manual TP, Theme
- Loop: CP1..CP16 (double TP) -> TeleportPart1 (once) -> Respawn -> delay -> repeat
--]]

-- ===== Services =====
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ===== Config Runtime =====
local STEP_DELAY = 2.9
local DELAY_AFTER_RESPAWN = 3.0
local DELAY_AFTER_TP1 = 3.0
local MAX_CP = 16

-- ===== Settings (editable from Settings tab) =====
local Settings = {
	MinimizeKey = Enum.KeyCode.RightControl,
	Theme = "Dark",
	Minimized = false,
}

local Themes = {
	Dark     = { bg=Color3.fromRGB(25,25,25),   accent=Color3.fromRGB(52,152,219), good=Color3.fromRGB(46,204,113), bad=Color3.fromRGB(231,76,60), text=Color3.fromRGB(235,235,235), sub=Color3.fromRGB(200,200,200), hint=Color3.fromRGB(160,160,160) },
	Midnight = { bg=Color3.fromRGB(16,18,24),   accent=Color3.fromRGB(114,137,218), good=Color3.fromRGB(88,214,141),  bad=Color3.fromRGB(242,100,92), text=Color3.fromRGB(230,232,239), sub=Color3.fromRGB(200,203,212), hint=Color3.fromRGB(160,164,180) },
	Emerald  = { bg=Color3.fromRGB(18,24,20),   accent=Color3.fromRGB(46,204,113),  good=Color3.fromRGB(46,204,113),  bad=Color3.fromRGB(231,76,60), text=Color3.fromRGB(230,255,240), sub=Color3.fromRGB(200,230,210), hint=Color3.fromRGB(160,200,180) },
	Sunset   = { bg=Color3.fromRGB(28,20,24),   accent=Color3.fromRGB(255,99,72),   good=Color3.fromRGB(254,149,120), bad=Color3.fromRGB(231,76,60), text=Color3.fromRGB(255,235,225), sub=Color3.fromRGB(230,210,205), hint=Color3.fromRGB(200,170,160) },
}

-- ===== Forward declarations =====
local setStatus
local applyTheme
local applyMinimize
local teleportToCFrame

-- ===== Helpers =====
local function getGuiParent()
	-- Prioritaskan gethui/CoreGui agar UI tampil via executor
	local ok, parent = pcall(function()
		if gethui then return gethui() end
		return game:GetService("CoreGui")
	end)
	if ok and parent then
		return parent
	end
	-- fallback: PlayerGui (kalau CoreGui tidak bisa)
	return player:WaitForChild("PlayerGui")
end

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getHRP(char)
	return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
end

local function getHumanoid(char)
	return char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
end

local function getCFrameFromNode(node)
	if not node then return nil end
	if node:IsA("BasePart") then return node.CFrame end
	if node:IsA("Model") then
		if node.PrimaryPart then return node.PrimaryPart.CFrame end
		local p = node:FindFirstChildWhichIsA("BasePart", true)
		if p then return p.CFrame end
	elseif node:IsA("Folder") then
		local p = node:FindFirstChildWhichIsA("BasePart", true)
		if p then return p.CFrame end
	end
	return nil
end

-- ===== GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CPControllerGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = getGuiParent()
pcall(function() if syn and syn.protect_gui then syn.protect_gui(screenGui) end end)

local theme = Themes[Settings.Theme]

local bg = Instance.new("Frame")
bg.Name = "Panel"
bg.Position = UDim2.new(0, 20, 0, 120)
bg.BackgroundColor3 = theme.bg
bg.BorderSizePixel = 0
bg.ClipsDescendants = true
bg.Parent = screenGui
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 12)

-- Size per tab
local SIZE_MAIN       = UDim2.new(0, 360, 0, 320)
local SIZE_SETTINGS   = UDim2.new(0, 360, 0, 210)
local SIZE_CHECKPOINT = UDim2.new(0, 360, 0, 260)

bg.Size = SIZE_MAIN
local expandedSize = bg.Size

-- Header (drag area)
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = theme.bg
header.BorderSizePixel = 0
header.Parent = bg
header.ZIndex = 10

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -120, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = theme.text
title.Text = "Checkpoint Teleporter"
title.Parent = header
title.ZIndex = 10

-- Window buttons
local btnMin = Instance.new("TextButton")
btnMin.Size = UDim2.new(0, 36, 0, 24)
btnMin.Position = UDim2.new(1, -84, 0.5, -12)
btnMin.BackgroundColor3 = theme.accent
btnMin.TextColor3 = Color3.new(1,1,1)
btnMin.Font = Enum.Font.GothamBold
btnMin.TextSize = 14
btnMin.Text = "–"
btnMin.Parent = header
Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0, 6)

local btnClose = Instance.new("TextButton")
btnClose.Size = UDim2.new(0, 36, 0, 24)
btnClose.Position = UDim2.new(1, -44, 0.5, -12)
btnClose.BackgroundColor3 = theme.bad
btnClose.TextColor3 = Color3.new(1,1,1)
btnClose.Font = Enum.Font.GothamBold
btnClose.TextSize = 14
btnClose.Text = "×"
btnClose.Parent = header
Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 6)

-- Tabs
local tabs = Instance.new("Frame")
tabs.Size = UDim2.new(1, -16, 0, 28)
tabs.Position = UDim2.new(0, 8, 0, 40)
tabs.BackgroundTransparency = 1
tabs.Parent = bg

local function makeTabButton(text, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 100, 0, 28)
	b.Position = UDim2.new(0, x, 0, 0)
	b.BackgroundColor3 = theme.accent
	b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.Text = text
	b.Parent = tabs
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

local tabMainBtn = makeTabButton("Main", 0)
local tabSettingsBtn = makeTabButton("Settings", 108)
local tabCheckpointBtn = makeTabButton("Checkpoint", 216)

-- Pages
local pages = Instance.new("Frame")
pages.Size = UDim2.new(1, -16, 1, -84)
pages.Position = UDim2.new(0, 8, 0, 72)
pages.BackgroundTransparency = 1
pages.Parent = bg

local mainPage = Instance.new("Frame");        mainPage.Size = UDim2.new(1,0,1,0); mainPage.BackgroundTransparency=1; mainPage.Parent = pages
local settingsPage = Instance.new("Frame");    settingsPage.Size = UDim2.new(1,0,1,0); settingsPage.BackgroundTransparency=1; settingsPage.Visible=false; settingsPage.Parent = pages
local cpPage = Instance.new("Frame");          cpPage.Size = UDim2.new(1,0,1,0); cpPage.BackgroundTransparency=1; cpPage.Visible=false; cpPage.Parent = pages

-- === MAIN PAGE UI ===
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 20)
status.Position = UDim2.new(0, 8, 0, 0)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = theme.sub
status.Text = "Status: Idle"
status.Parent = mainPage

local delayInfo = Instance.new("TextLabel")
delayInfo.Size = UDim2.new(1, -16, 0, 36)
delayInfo.Position = UDim2.new(0, 8, 0, 22)
delayInfo.BackgroundTransparency = 1
delayInfo.Font = Enum.Font.Gotham
delayInfo.TextSize = 13
delayInfo.TextXAlignment = Enum.TextXAlignment.Left
delayInfo.TextColor3 = theme.hint
delayInfo.Parent = mainPage

-- Info delay
local function updateDelayInfoText()
	delayInfo.Text = ("CP Delay: %.2fs | After Respawn: %.2fs"):format(STEP_DELAY, DELAY_AFTER_RESPAWN)
end
updateDelayInfoText()

-- Control change delay (2 row)
local delayRow = Instance.new("Frame")
delayRow.Size = UDim2.new(1, -16, 0, 72)
delayRow.Position = UDim2.new(0, 8, 0, 60)
delayRow.BackgroundTransparency = 1
delayRow.Parent = mainPage

-- Row 1
local row1 = Instance.new("Frame")
row1.Size = UDim2.new(1, 0, 0, 32)
row1.BackgroundTransparency = 1
row1.Parent = delayRow

local r1list = Instance.new("UIListLayout")
r1list.FillDirection = Enum.FillDirection.Horizontal
r1list.Padding = UDim.new(0, 8)
r1list.VerticalAlignment = Enum.VerticalAlignment.Center
r1list.Parent = row1

local function makeLabeledBox(parent, labelText, initial)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, 150, 1, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 14)
	lbl.Position = UDim2.new(0, 0, 0, -2)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextSize = 12
	lbl.TextColor3 = theme.sub
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = labelText
	lbl.Parent = holder

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0, 150, 0, 24)
	box.Position = UDim2.new(0, 0, 0, 14)
	box.BackgroundColor3 = theme.accent
	box.TextColor3 = Color3.new(1,1,1)
	box.Font = Enum.Font.GothamBold
	box.TextSize = 14
	box.Text = string.format("%.2f", initial)
	box.ClearTextOnFocus = false
	box.Parent = holder
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

	return box
end

local cpDelayBox      = makeLabeledBox(row1, "CP Delay (s)", STEP_DELAY)
local respawnDelayBox = makeLabeledBox(row1, "After Respawn (s)", DELAY_AFTER_RESPAWN)

-- Row 2 (Apply)
local applyDelayBtn = Instance.new("TextButton")
applyDelayBtn.Size = UDim2.new(0, 120, 0, 34)
applyDelayBtn.Position = UDim2.new(0, 0, 0, 55)
applyDelayBtn.BackgroundColor3 = theme.good
applyDelayBtn.TextColor3 = Color3.new(1,1,1)
applyDelayBtn.Font = Enum.Font.GothamBold
applyDelayBtn.TextSize = 14
applyDelayBtn.Text = "Apply"
applyDelayBtn.Parent = delayRow
Instance.new("UICorner", applyDelayBtn).CornerRadius = UDim.new(0, 8)

local function clampDelay(x)
	if not x then return nil end
	if x < 0 then x = 0 end
	if x > 30 then x = 30 end
	return x
end

applyDelayBtn.MouseButton1Click:Connect(function()
	local newStep = clampDelay(tonumber(cpDelayBox.Text))
	local newResp = clampDelay(tonumber(respawnDelayBox.Text))
	if newStep then STEP_DELAY = newStep end
	if newResp then DELAY_AFTER_RESPAWN = newResp end
	updateDelayInfoText()
	setStatus("Delays updated")
end)

-- Credit (pojok kanan bawah)
local credit = Instance.new("TextLabel")
credit.Size = UDim2.new(0, 180, 0, 18)
credit.AnchorPoint = Vector2.new(1, 1)
credit.Position = UDim2.new(1, -10, 1, -4)
credit.BackgroundTransparency = 1
credit.Font = Enum.Font.Gotham
credit.TextSize = 12
credit.TextXAlignment = Enum.TextXAlignment.Right
credit.TextColor3 = Color3.fromRGB(140,140,255)
credit.Text = "made by misuminitt"
credit.Parent = mainPage

-- Start / Stop
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0, 170, 0, 34)
startBtn.Position = UDim2.new(0, 7, 0, 170)
startBtn.BackgroundColor3 = theme.good
startBtn.TextColor3 = Color3.new(1,1,1)
startBtn.Text = "Start"
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 14
startBtn.Parent = mainPage
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 160, 0, 34)
stopBtn.Position = UDim2.new(0, 185, 0, 170)
stopBtn.BackgroundColor3 = theme.bad
stopBtn.TextColor3 = Color3.new(1,1,1)
stopBtn.Text = "Stop"
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 14
stopBtn.Parent = mainPage
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 8)

-- ===== SETTINGS PAGE =====
local keyLabel = Instance.new("TextLabel")
keyLabel.Size = UDim2.new(1, -16, 0, 18)
keyLabel.Position = UDim2.new(0, 8, 0, 0)
keyLabel.BackgroundTransparency = 1
keyLabel.Font = Enum.Font.GothamMedium
keyLabel.TextSize = 13
keyLabel.TextXAlignment = Enum.TextXAlignment.Left
keyLabel.TextColor3 = theme.sub
keyLabel.Text = "Minimize Keybind:"
keyLabel.Parent = settingsPage

local keyBtn = Instance.new("TextButton")
keyBtn.Size = UDim2.new(0, 160, 0, 28)
keyBtn.Position = UDim2.new(0, 8, 0, 22)
keyBtn.BackgroundColor3 = theme.accent
keyBtn.TextColor3 = Color3.new(1,1,1)
keyBtn.Font = Enum.Font.GothamBold
keyBtn.TextSize = 14
keyBtn.Text = Settings.MinimizeKey.Name
keyBtn.Parent = settingsPage
Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 8)

local themeLabel = Instance.new("TextLabel")
themeLabel.Size = UDim2.new(1, -16, 0, 18)
themeLabel.Position = UDim2.new(0, 8, 0, 60)
themeLabel.BackgroundTransparency = 1
themeLabel.Font = Enum.Font.GothamMedium
themeLabel.TextSize = 13
themeLabel.TextXAlignment = Enum.TextXAlignment.Left
themeLabel.TextColor3 = theme.sub
themeLabel.Text = "Theme:"
themeLabel.Parent = settingsPage

local themeRow = Instance.new("Frame")
themeRow.Size = UDim2.new(1, -16, 0, 30)
themeRow.Position = UDim2.new(0, 8, 0, 82)
themeRow.BackgroundTransparency = 1
themeRow.Parent = settingsPage

local function makeThemeButton(name, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 80, 0, 26)
	b.Position = UDim2.new(0, x, 0, 2)
	b.BackgroundColor3 = Themes[name].accent
	b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = name
	b.Parent = themeRow
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

local themeBtns = {
	makeThemeButton("Dark", 0),
	makeThemeButton("Midnight", 86),
	makeThemeButton("Emerald", 172),
	makeThemeButton("Sunset", 258),
}

-- ===== CHECKPOINT PAGE =====
local cpControls = Instance.new("Frame")
cpControls.Size = UDim2.new(1, -16, 0, 30)
cpControls.Position = UDim2.new(0, 8, 0, 4)
cpControls.BackgroundTransparency = 1
cpControls.Parent = cpPage

local pauseBtn = Instance.new("TextButton")
pauseBtn.Size = UDim2.new(0, 140, 0, 28)
pauseBtn.Position = UDim2.new(0, 0, 0, 0)
pauseBtn.BackgroundColor3 = theme.accent
pauseBtn.TextColor3 = Color3.new(1,1,1)
pauseBtn.Font = Enum.Font.GothamBold
pauseBtn.TextSize = 13
pauseBtn.Text = "Pause Loop"
pauseBtn.Parent = cpControls
Instance.new("UICorner", pauseBtn).CornerRadius = UDim.new(0, 8)

-- Scroll container
local cpScroll = Instance.new("ScrollingFrame")
cpScroll.Name = "CpScroll"
cpScroll.Size = UDim2.new(1, -16, 1, -44)
cpScroll.Position = UDim2.new(0, 8, 0, 40)
cpScroll.BackgroundTransparency = 1
cpScroll.BorderSizePixel = 0
cpScroll.ScrollBarThickness = 6
cpScroll.ScrollBarImageTransparency = 0
cpScroll.ScrollingDirection = Enum.ScrollingDirection.Y
cpScroll.ElasticBehavior = Enum.ElasticBehavior.Never
cpScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
cpScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
cpScroll.Parent = cpPage

local cpGrid = Instance.new("Frame")
cpGrid.Name = "Grid"
cpGrid.Size = UDim2.new(1, -2, 0, 0)
cpGrid.Position = UDim2.new(0, 1, 0, 0)
cpGrid.BackgroundTransparency = 1
cpGrid.Parent = cpScroll

local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(0, 70, 0, 28)
layout.CellPadding = UDim2.new(0, 8, 0, 8)
layout.FillDirectionMaxCells = 4
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = cpGrid

local cpButtons = {}
local function makeCpButton(labelText)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 70, 0, 28)
	b.BackgroundColor3 = theme.accent
	b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = labelText
	b.Parent = cpGrid
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	table.insert(cpButtons, b)
	return b
end

local cpBtnsByIndex = {}
for i = 1, 16 do
	cpBtnsByIndex[i] = makeCpButton("CP "..i)
end
local tp1Btn = makeCpButton("TP1")

-- ===== Panel size helper =====
local function setPanelSizeFor(tabName)
	if Settings.Minimized then return end
	if tabName == "Main" then
		bg.Size = SIZE_MAIN
	elseif tabName == "Settings" then
		bg.Size = SIZE_SETTINGS
	elseif tabName == "Checkpoint" then
		bg.Size = SIZE_CHECKPOINT
	end
	expandedSize = bg.Size
end

-- ===== Tab switcher =====
local function setActiveTab(name)
	mainPage.Visible      = (name == "Main")
	settingsPage.Visible  = (name == "Settings")
	cpPage.Visible        = (name == "Checkpoint")

	if delayRow then delayRow.Visible = (name == "Main") end
	if applyDelayBtn then applyDelayBtn.Visible = (name == "Main") end
	if startBtn then startBtn.Visible = (name == "Main") end
	if stopBtn then stopBtn.Visible = (name == "Main") end
	if credit then credit.Visible = (name == "Main") end

	setPanelSizeFor(name)
end

local function showMain()       setActiveTab("Main") end
local function showSettings()   setActiveTab("Settings") end
local function showCheckpoint() setActiveTab("Checkpoint") end

tabMainBtn.MouseButton1Click:Connect(showMain)
tabSettingsBtn.MouseButton1Click:Connect(showSettings)
tabCheckpointBtn.MouseButton1Click:Connect(showCheckpoint)

setActiveTab("Main")

-- ===== Draggable header =====
do
	local dragging=false; local dragStart; local startPos
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging=true; dragStart=input.Position; startPos=bg.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging=false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
			local delta=input.Position-dragStart
			bg.Position=UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
		end
	end)
end

-- ===== Minimize & Close =====
local collapsedHeight = 36
local hidden = false

btnClose.MouseButton1Click:Connect(function()
	hidden = true
	bg.Visible = false
end)

local headerToggle = Instance.new("TextButton")
headerToggle.Size = UDim2.new(1,0,1,0)
headerToggle.BackgroundTransparency = 1
headerToggle.AutoButtonColor = false
headerToggle.ZIndex = 11
headerToggle.Text = ""
headerToggle.Visible = false
headerToggle.Parent = header

local NORMAL_TITLE_TEXT = "Checkpoint Teleporter"
local NORMAL_TITLE_SIZE = UDim2.new(1, -120, 1, 0)
local NORMAL_TITLE_POS  = UDim2.new(0, 12, 0, 0)
local NORMAL_TITLE_ALIGN= Enum.TextXAlignment.Left

local MINI_TITLE_TEXT = "checkpoint teleport"
local MINI_TITLE_SIZE = UDim2.new(1, -16, 1, 0)
local MINI_TITLE_POS  = UDim2.new(0, 8, 0, 0)
local MINI_TITLE_ALIGN= Enum.TextXAlignment.Center

applyMinimize = function(min)
	Settings.Minimized = min
	if min then
		expandedSize = bg.Size
		bg.Size = UDim2.new(bg.Size.X.Scale, bg.Size.X.Offset, 0, collapsedHeight)
		for _, child in ipairs(bg:GetChildren()) do
			if child ~= header then child.Visible=false end
		end
		btnMin.Visible=false; btnClose.Visible=false
		title.Text=MINI_TITLE_TEXT; title.TextXAlignment=MINI_TITLE_ALIGN; title.Size=MINI_TITLE_SIZE; title.Position=MINI_TITLE_POS
		headerToggle.Visible=true
	else
		bg.Size = expandedSize
		for _, child in ipairs(bg:GetChildren()) do
			if child ~= header then child.Visible=true end
		end
		btnMin.Visible=true; btnClose.Visible=true
		title.Text=NORMAL_TITLE_TEXT; title.TextXAlignment=NORMAL_TITLE_ALIGN; title.Size=NORMAL_TITLE_SIZE; title.Position=NORMAL_TITLE_POS
		headerToggle.Visible=false
	end
end

headerToggle.MouseButton1Click:Connect(function() applyMinimize(false) end)
btnMin.MouseButton1Click:Connect(function() applyMinimize(not Settings.Minimized) end)

-- Keybind minimize
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Settings.MinimizeKey then
		if hidden then bg.Visible=true; hidden=false else applyMinimize(not Settings.Minimized) end
	end
end)

-- ===== Status setter =====
setStatus = function(txt) status.Text = "Status: " .. txt end

-- ===== Theme =====
applyTheme = function(name)
	if not Themes[name] then return end
	Settings.Theme = name
	theme = Themes[name]

	bg.BackgroundColor3 = theme.bg
	header.BackgroundColor3 = theme.bg
	title.TextColor3 = theme.text

	btnMin.BackgroundColor3 = theme.accent
	btnClose.BackgroundColor3 = theme.bad

	tabMainBtn.BackgroundColor3 = theme.accent
	tabSettingsBtn.BackgroundColor3 = theme.accent
	tabCheckpointBtn.BackgroundColor3 = theme.accent

	status.TextColor3 = theme.sub
	delayInfo.TextColor3 = theme.hint
	if startBtn then startBtn.BackgroundColor3 = theme.good end
	if stopBtn  then stopBtn.BackgroundColor3  = theme.bad  end

	keyLabel.TextColor3 = theme.sub
	keyBtn.BackgroundColor3 = theme.accent
	themeLabel.TextColor3 = theme.sub

	for _, b in ipairs(themeBtns) do
		b.BackgroundColor3 = Themes[b.Text].accent
		b.TextColor3 = Color3.new(1,1,1)
	end

	pauseBtn.BackgroundColor3 = theme.accent
	pauseBtn.TextColor3 = Color3.new(1,1,1)
	for _, b in ipairs(cpButtons) do
		b.BackgroundColor3 = theme.accent
		b.TextColor3 = Color3.new(1,1,1)
	end

	if cpScroll then
		cpScroll.ScrollBarImageColor3 = theme.hint
	end

	if cpDelayBox and respawnDelayBox and applyDelayBtn then
		cpDelayBox.BackgroundColor3 = theme.accent
		cpDelayBox.TextColor3 = Color3.new(1,1,1)
		respawnDelayBox.BackgroundColor3 = theme.accent
		respawnDelayBox.TextColor3 = Color3.new(1,1,1)
		applyDelayBtn.BackgroundColor3 = theme.good
		applyDelayBtn.TextColor3 = Color3.new(1,1,1)
	end
end

for _, b in ipairs(themeBtns) do
	b.MouseButton1Click:Connect(function() applyTheme(b.Text) end)
end
applyTheme(Settings.Theme)

-- ===== Teleport utils =====
teleportToCFrame = function(cf)
	local char = getCharacter()
	local hrp = getHRP(char)
	local up = Vector3.new(0, 3, 0)
	hrp.CFrame = CFrame.new(cf.Position + up, (cf.Position + up) + cf.LookVector)
	return hrp
end

-- ===== Loop control =====
local state = { running = false }

local function waitDelayCancellable(sec)
	local t0 = time()
	while state.running and (time() - t0) < sec do
		RunService.Heartbeat:Wait()
	end
end

local function respawnAvatar()
	setStatus("Respawning avatar…")
	local char = getCharacter()
	local hum = getHumanoid(char)
	if hum then hum.Health = 0 else char:BreakJoints() end
	local newChar = player.CharacterAdded:Wait()
	getHRP(newChar)
end

-- helper: teleport 2x ke satu tujuan
local function tpTwiceTo(cf, label)
	setStatus(("Teleport → %s (1/2)"):format(label))
	teleportToCFrame(cf)
	waitDelayCancellable(STEP_DELAY)

	if not state.running then return end
	setStatus(("Teleport → %s (2/2)"):format(label))
	teleportToCFrame(cf)
	waitDelayCancellable(STEP_DELAY)
end

-- start loop
local function startLoop()
	if state.running then return end
	state.running = true
	setStatus("Running")

	task.spawn(function()
		while state.running do
			local checkpoints = Workspace:FindFirstChild("Checkpoints")
			if not checkpoints then
				setStatus("Workspace.Checkpoints not found")
				break
			end

			for i = 1, MAX_CP do
				if not state.running then break end
				local node = checkpoints:FindFirstChild(tostring(i))
				local cf = node and getCFrameFromNode(node)
				if cf then
					tpTwiceTo(cf, ("CP %d"):format(i))
				else
					setStatus(("CP %d missing/invalid (skip)"):format(i))
					waitDelayCancellable(STEP_DELAY)
				end
			end
			if not state.running then break end

			local tpFolder = Workspace:FindFirstChild("TeleportParts")
			local tp1 = tpFolder and tpFolder:FindFirstChild("TeleportPart1")
			local tpCF = tp1 and getCFrameFromNode(tp1)
			if tpCF then
				setStatus("Teleport → TeleportPart1 (1x)")
				teleportToCFrame(tpCF)
			else
				setStatus("TeleportPart1 not found/invalid (skip)")
			end
			if not state.running then break end

			respawnAvatar()
			if not state.running then break end

			setStatus("Waiting (after respawn)")
			local t0 = time()
			while state.running and (time() - t0) < DELAY_AFTER_RESPAWN do
				RunService.Heartbeat:Wait()
			end
		end

		state.running = false
		setStatus("Stopped")
	end)
end

local function stopLoop()
	state.running = false
	setStatus("Stopping…")
end

-- ===== Pause/Resume + Manual TP =====
local function updatePauseBtn()
	if state.running then pauseBtn.Text = "Pause Loop" else pauseBtn.Text = "Resume Loop" end
end

pauseBtn.MouseButton1Click:Connect(function()
	if state.running then
		state.running = false
		setStatus("Paused")
	else
		startLoop()
	end
	updatePauseBtn()
end)

startBtn.MouseButton1Click:Connect(function() startLoop(); updatePauseBtn() end)
stopBtn.MouseButton1Click:Connect(function() stopLoop(); updatePauseBtn() end)

local function ensurePaused()
	if state.running then
		state.running = false
		setStatus("Paused (manual control)")
		RunService.Heartbeat:Wait()
		updatePauseBtn()
	end
end

local function tpToCheckpoint(index)
	local checkpoints = Workspace:FindFirstChild("Checkpoints")
	if not checkpoints then setStatus("No Checkpoints folder"); return end
	local node = checkpoints:FindFirstChild(tostring(index))
	local cf = node and getCFrameFromNode(node)
	if cf then
		ensurePaused()
		setStatus(("Manual TP → CP %d"):format(index))
		teleportToCFrame(cf)
	else
		setStatus(("CP %d not found/invalid"):format(index))
	end
end

local function tpToTP1()
	local tpFolder = Workspace:FindFirstChild("TeleportParts")
	local tp1 = tpFolder and tpFolder:FindFirstChild("TeleportPart1")
	local cf = tp1 and getCFrameFromNode(tp1)
	if cf then
		ensurePaused()
		setStatus("Manual TP → TeleportPart1")
		teleportToCFrame(cf)
	else
		setStatus("TeleportPart1 not found/invalid")
	end
end

for i = 1, 16 do
	cpBtnsByIndex[i].MouseButton1Click:Connect(function() tpToCheckpoint(i) end)
end
tp1Btn.MouseButton1Click:Connect(tpToTP1)

-- ===== Keybind capture =====
local listening = false
keyBtn.MouseButton1Click:Connect(function()
	if listening then return end
	listening = true
	keyBtn.Text = "Press any key..."
	local conn
	conn = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode ~= Enum.KeyCode.Unknown then
			Settings.MinimizeKey = input.KeyCode
			keyBtn.Text = Settings.MinimizeKey.Name
			listening = false
			conn:Disconnect()
		end
	end)
end)

