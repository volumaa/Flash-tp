-- ╔══════════════════════════════╗
-- ║   VSZ Hub  |  Flash TP       ║
-- ║  discord.gg/NGEMSasjjG       ║
-- ╚══════════════════════════════╝
local Players             = game:GetService("Players")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local CoreGui             = game:GetService("CoreGui")
local UserInputService    = game:GetService("UserInputService")
local StarterGui          = game:GetService("StarterGui")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local plr                 = Players.LocalPlayer
local Camera              = workspace.CurrentCamera

-- ══════════════════════════════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════════════════════════════
local CONFIG = {
    BLOCK_DELAY = 0.05,
    TAP_HEIGHT  = 0.02,
}

-- ══════════════════════════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════════════════════════
local autoGrab    = true
local grabLock    = false
local blockEnabled = false
local autoResetBalloon = false  -- toggle: block all players continuously when ON

-- ══════════════════════════════════════════════════════════════
--  CHARACTER REFS
-- ══════════════════════════════════════════════════════════════
local function getRoot()
    local c = plr.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso"))
end
local function getHum()
    local c = plr.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ══════════════════════════════════════════════════════════════
--  TOOL HELPERS
-- ══════════════════════════════════════════════════════════════
local function equipTool(name)
    local hum = getHum()
    if not hum then return false end
    local bp   = plr:FindFirstChild("Backpack")
    local tool = (bp and bp:FindFirstChild(name))
              or (plr.Character and plr.Character:FindFirstChild(name))
    if tool then hum:EquipTool(tool) return true end
    return false
end

-- ══════════════════════════════════════════════════════════════
--  ADMIN REMOTE (remote-only AP spam, no chat)
-- ══════════════════════════════════════════════════════════════
local AdminRemote = nil
task.spawn(function()
    if not plr.Character then plr.CharacterAdded:Wait() end
    task.wait(1)
    local net = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net")
    local children = net:GetChildren()
    local byIdx, byName = {}, {}
    for i, obj in ipairs(children) do byIdx[i] = obj byName[obj.Name] = i end
    local anchorIdx = byName["RF/a0e78691-cb9b-4efc-ac08-9c06fea70059"]
    if anchorIdx then
        local actual = byIdx[anchorIdx + 1]
        if actual then AdminRemote = actual end
    end
end)

local function spamAP(target)
    if not AdminRemote or not target or target == plr then return end
    local id = "f888ee6e-c86d-46e1-93d7-0639d6635d42"
    for _, cmd in ipairs({"balloon","jumpscare","rocket","jail","ragdoll"}) do
        task.spawn(function() AdminRemote:InvokeServer(id, target, cmd) end)
    end
end

-- ══════════════════════════════════════════════════════════════
--  BLOCK CORE
-- ══════════════════════════════════════════════════════════════
local function confirmBlockDialog()
    local robloxGui = CoreGui:FindFirstChild("RobloxGui")
    if robloxGui then
        for _, v in pairs(robloxGui:GetDescendants()) do
            if v:IsA("TextButton") then
                local t = v.Text:lower()
                local n = v.Name:lower()
                if t == "block" or n:find("block") or n:find("confirm") then
                    local cx = v.AbsolutePosition.X + v.AbsoluteSize.X / 2
                    local cy = v.AbsolutePosition.Y + v.AbsoluteSize.Y / 2
                    for i = 1, 20 do
                        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true,  game, 1)
                        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
                    end
                    return true
                end
            end
        end
    end
    -- Fallback: from screenshot Block button sits at ~55-60% Y
    local view = Camera.ViewportSize
    for _, yPct in ipairs({0.54, 0.57, 0.60, 0.63}) do
        for i = 1, 10 do
            VirtualInputManager:SendMouseButtonEvent(view.X/2, view.Y*yPct, 0, true,  game, 1)
            VirtualInputManager:SendMouseButtonEvent(view.X/2, view.Y*yPct, 0, false, game, 1)
        end
    end
end

local blockedSet = {}

local function blockPlayer(target)
    if not target or target == plr then return end
    if blockedSet[target.UserId] then return end
    blockedSet[target.UserId] = true
    task.spawn(function()
        pcall(function() StarterGui:SetCore("PromptBlockPlayer", target) end)
        task.wait(0.4)
        confirmBlockDialog()
        task.wait(0.2)
        confirmBlockDialog()
    end)
end

-- ══════════════════════════════════════════════════════════════
--  CONTINUOUS BLOCK LOOP removed — block only fires on Flash TP press
-- ══════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════
--  AUTO GRAB — RenderStepped, instant fire every frame
-- ══════════════════════════════════════════════════════════════
local function getPromptPos(prompt)
    local p = prompt.Parent
    if p:IsA("BasePart") then return p.Position end
    if p:IsA("Model") then
        local prim = p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart")
        return prim and prim.Position
    end
    if p:IsA("Attachment") then return p.WorldPosition end
    local part = p:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position
end

local _grabbing = false

local function firePrompt(prompt)
    pcall(function() fireproximityprompt(prompt, 9999) end)
    pcall(function() prompt:InputHoldBegin() end)
    task.spawn(function()
        local t = 0
        while t < 40 and not plr:GetAttribute("Stealing") do
            RunService.Heartbeat:Wait() t += 1
        end
        while plr:GetAttribute("Stealing") do
            RunService.Heartbeat:Wait()
        end
        pcall(function() prompt:InputHoldEnd() end)
        task.wait(0.1)
        _grabbing = false
    end)
end

RunService.RenderStepped:Connect(function()
    if not autoGrab or _grabbing then return end
    if plr:GetAttribute("Stealing") then return end
    local root = getRoot()
    if not root then return end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    local myPos = root.Position
    for _, plot in ipairs(plots:GetChildren()) do
        for _, obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled and obj.ActionText == "Steal" then
                local pos = getPromptPos(obj)
                if pos and (myPos - pos).Magnitude <= math.max(obj.MaxActivationDistance, 12) then
                    _grabbing = true
                    firePrompt(obj)
                    return
                end
            end
        end
    end
end)

plr.CharacterAdded:Connect(function()
    _grabbing = false
    grabLock = false
    pcall(function() plr:SetAttribute("Stealing", nil) end)
    task.wait(2)
end)

-- ══════════════════════════════════════════════════════════════
--  GUI
-- ══════════════════════════════════════════════════════════════
pcall(function() CoreGui:FindFirstChild("VSZHub_FlashTP"):Destroy() end)

local BG         = Color3.fromRGB(15, 15, 20)
local CARD       = Color3.fromRGB(25, 25, 35)
local HOVER      = Color3.fromRGB(40, 40, 56)
local ORG        = Color3.fromRGB(255, 140, 0)
local RED        = Color3.fromRGB(255, 70, 70)
local GRN        = Color3.fromRGB(50, 200, 80)
local TXT        = Color3.fromRGB(255, 255, 255)
local TXT2       = Color3.fromRGB(170, 170, 190)
local STRK       = Color3.fromRGB(55, 55, 75)
local TWEEN_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local sg = Instance.new("ScreenGui", CoreGui)
sg.Name = "VSZHub_FlashTP"
sg.ResetOnSpawn = false
sg.DisplayOrder = 9999

local FULL_H = 256
local Main = Instance.new("Frame", sg)
Main.Size = UDim2.new(0, 185, 0, FULL_H)
Main.Position = UDim2.new(1, -195, 0, 10)
Main.BackgroundColor3 = BG
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Active = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = STRK mainStroke.Thickness = 2

-- title bar
local TitleBar = Instance.new("Frame", Main)
TitleBar.Size = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = CARD TitleBar.BorderSizePixel = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)
local tbFix = Instance.new("Frame", TitleBar)
tbFix.Size = UDim2.new(1,0,0.5,0) tbFix.Position = UDim2.new(0,0,0.5,0)
tbFix.BackgroundColor3 = CARD tbFix.BorderSizePixel = 0

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size = UDim2.new(1,-50,1,0) TitleLabel.Position = UDim2.new(0,12,0,0)
TitleLabel.BackgroundTransparency = 1 TitleLabel.Text = "VSZ Hub"
TitleLabel.TextColor3 = TXT TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.TextYAlignment = Enum.TextYAlignment.Center
local titleGrad = Instance.new("UIGradient", TitleLabel)
titleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, ORG),
    ColorSequenceKeypoint.new(0.6, TXT),
    ColorSequenceKeypoint.new(1, CARD),
})

-- collapse btn
local ColWrap = Instance.new("Frame", TitleBar)
ColWrap.Size = UDim2.new(0,24,0,18) ColWrap.Position = UDim2.new(1,-28,0.5,-9)
ColWrap.BackgroundColor3 = Color3.fromRGB(40,40,55) ColWrap.BorderSizePixel = 0
Instance.new("UICorner", ColWrap).CornerRadius = UDim.new(0,5)
Instance.new("UIStroke", ColWrap).Color = STRK
local ColBtn = Instance.new("TextButton", ColWrap)
ColBtn.Size = UDim2.new(1,0,1,0) ColBtn.BackgroundTransparency = 1
ColBtn.Text = "×" ColBtn.TextColor3 = TXT2
ColBtn.TextSize = 16 ColBtn.Font = Enum.Font.GothamBold
ColBtn.AutoButtonColor = false
local collapsed = false
ColBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    ColBtn.Text = collapsed and "+" or "×"
    TweenService:Create(Main, TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Size=UDim2.new(0,185,0,collapsed and 34 or FULL_H)}):Play()
end)

-- drag
local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true dragStart = i.Position startPos = Main.Position
    end
end)
TitleBar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end)

-- content
local CF = Instance.new("Frame", Main)
CF.Size = UDim2.new(1,0,1,-34) CF.Position = UDim2.new(0,0,0,34)
CF.BackgroundTransparency = 1

local function makeRow(label, yPos, keybind, color, cb)
    local row = Instance.new("Frame", CF)
    row.Size = UDim2.new(1,-18,0,34) row.Position = UDim2.new(0,9,0,yPos)
    row.BackgroundColor3 = CARD row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1,0,1,0) btn.BackgroundTransparency = 1
    btn.Text = label btn.TextColor3 = TXT
    btn.TextSize = 12 btn.Font = Enum.Font.GothamBlack
    btn.AutoButtonColor = false btn.ZIndex = 2
    if keybind then
        local kb = Instance.new("TextLabel", row)
        kb.Size = UDim2.new(0,20,0,16) kb.Position = UDim2.new(1,-24,0.5,-8)
        kb.BackgroundColor3 = BG kb.BorderSizePixel = 0
        kb.Text = keybind kb.TextColor3 = TXT2
        kb.TextSize = 10 kb.Font = Enum.Font.GothamBold kb.ZIndex = 3
        Instance.new("UICorner", kb).CornerRadius = UDim.new(0,4)
    end
    local hc = color or ORG
    btn.MouseEnter:Connect(function()
        TweenService:Create(row, TWEEN_FAST, {BackgroundColor3=HOVER}):Play()
        TweenService:Create(btn, TWEEN_FAST, {TextColor3=hc}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(row, TWEEN_FAST, {BackgroundColor3=CARD}):Play()
        TweenService:Create(btn, TWEEN_FAST, {TextColor3=TXT}):Play()
    end)
    if cb then btn.MouseButton1Click:Connect(function() task.spawn(cb, btn) end) end
    return btn, row
end

-- ── FLASH TP button (y=8)
local flashBtn = makeRow("FLASH TP", 8, "F", ORG, function(btn)
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    btn.Text = "EXECUTING..."
    equipTool("Flying Carpet")
    task.wait(0.1)
    local targetPos = Vector3.new(-344.03, -7.30, 63.29)
    local targetRot = CFrame.fromEulerAnglesYXZ(math.rad(-12.9), math.rad(-20.0), 0)
    hrp.CFrame = CFrame.new(targetPos) * targetRot
    Camera.CFrame = CFrame.new(Camera.CFrame.Position) * targetRot
    task.wait(0.2)
    equipTool("Flash Teleport")
    -- block only if block toggle is ON
    if blockEnabled then
        blockedSet = {}
        task.spawn(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= plr then blockPlayer(p) end
            end
        end)
    end
    task.wait(0.1)
    local tool = char:FindFirstChild("Flash Teleport")
    if tool then tool:Activate() end
    task.wait(0.8)
    btn.Text = "FLASH TP"
end)

-- ── BLOCK toggle (y=50)
local blockRow = Instance.new("Frame", CF)
blockRow.Size = UDim2.new(1,-18,0,34) blockRow.Position = UDim2.new(0,9,0,50)
blockRow.BackgroundColor3 = CARD blockRow.BorderSizePixel = 0
Instance.new("UICorner", blockRow).CornerRadius = UDim.new(0,7)
local blockRowStroke = Instance.new("UIStroke", blockRow)
blockRowStroke.Color = STRK blockRowStroke.Thickness = 1.2

local blockLbl = Instance.new("TextLabel", blockRow)
blockLbl.Size = UDim2.new(1,-54,1,0) blockLbl.Position = UDim2.new(0,10,0,0)
blockLbl.BackgroundTransparency = 1 blockLbl.Text = "BLOCK"
blockLbl.TextColor3 = TXT2 blockLbl.TextSize = 12
blockLbl.Font = Enum.Font.GothamBlack blockLbl.TextXAlignment = Enum.TextXAlignment.Left

local track = Instance.new("Frame", blockRow)
track.Size = UDim2.new(0,36,0,18) track.Position = UDim2.new(1,-44,0.5,-9)
track.BackgroundColor3 = Color3.fromRGB(15,14,19) track.BorderSizePixel = 0
Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
local dot = Instance.new("Frame", track)
dot.Size = UDim2.new(0,14,0,14) dot.Position = UDim2.new(0,2,0.5,-7)
dot.BackgroundColor3 = TXT2 dot.BorderSizePixel = 0
Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

local blockClickBtn = Instance.new("TextButton", blockRow)
blockClickBtn.Size = UDim2.new(1,0,1,0) blockClickBtn.BackgroundTransparency = 1
blockClickBtn.Text = "" blockClickBtn.AutoButtonColor = false blockClickBtn.ZIndex = 2

local function setBlockVisual(on)
    blockLbl.TextColor3 = on and TXT or TXT2
    TweenService:Create(track, TWEEN_FAST, {BackgroundColor3 = on and RED or Color3.fromRGB(15,14,19)}):Play()
    TweenService:Create(dot, TWEEN_FAST, {
        Position = on and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7),
        BackgroundColor3 = on and BG or TXT2
    }):Play()
    TweenService:Create(blockRowStroke, TWEEN_FAST, {Color = on and RED or STRK}):Play()
end

blockClickBtn.MouseButton1Click:Connect(function()
    blockEnabled = not blockEnabled
    setBlockVisual(blockEnabled)
end)

-- ── RESET button (y=92)
local function doInstantReset()
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    -- method 1: teleport to death zone (CraftingMachine) — instant, no void
    local ok = pcall(function()
        local targetPart = workspace:FindFirstChild("CraftingMachine")
            and workspace.CraftingMachine:FindFirstChild("VFX")
            and workspace.CraftingMachine.VFX:FindFirstChild("Secret")
            and workspace.CraftingMachine.VFX.Secret:FindFirstChild("SoundPart")
        if targetPart then
            char:PivotTo(CFrame.new(targetPart.Position))
        else
            error("no part")
        end
    end)
    -- method 2: fallback — break ragdoll + velocity kill
    if not ok then
        local bp = plr:FindFirstChild("Backpack")
        local carpet = (bp and bp:FindFirstChild("Flying Carpet")) or char:FindFirstChild("Flying Carpet")
        if carpet then pcall(function() hum:EquipTool(carpet) end) end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BallSocketConstraint") or obj:IsA("NoCollisionConstraint") or obj:IsA("HingeConstraint") then
                pcall(function() obj:Destroy() end)
            end
        end
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 2147483647, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 2147483647, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 2147483647, 0)
    end
    hum.Health = 0
end

makeRow("INSTANT RESET", 92, "R", RED, function()
    doInstantReset()
end)

-- ── SPAM AP NEAREST (y=134)
makeRow("SPAM AP NEAREST", 134, "E", RED, function(btn)
    local root = getRoot()
    if not root then return end
    local nearest, dist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (root.Position - hrp.Position).Magnitude
                if d < dist then dist = d nearest = p end
            end
        end
    end
    if not nearest then return end
    btn.Text = "SPAMMING..."
    spamAP(nearest)
    task.wait(0.8)
    btn.Text = "SPAM AP NEAREST"
end)

-- ── AUTO RESET ON BALLOON
task.spawn(function()
    local function hookRemote(obj)
        obj.OnClientEvent:Connect(function(...)
            if not autoResetBalloon then return end
            for _, v in ipairs({...}) do
                if type(v) == "string" then
                    local s = v:lower()
                    -- only match balloon specifically, nothing else
                    if s == "balloon" or s:find("balloon") and not s:find("jail") and not s:find("rocket") and not s:find("ragdoll") and not s:find("inverse") and not s:find("jumpscare") and not s:find("morph") and not s:find("nightvision") and not s:find("tiny") then
                        task.wait(0.05)
                        doInstantReset()
                        return
                    end
                end
            end
        end)
    end
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") then hookRemote(obj) end
    end
    game.DescendantAdded:Connect(function(obj)
        if obj:IsA("RemoteEvent") then hookRemote(obj) end
    end)
end)

-- ── AUTO RESET ON BALLOON toggle (y=176)
local arRow = Instance.new("Frame", CF)
arRow.Size = UDim2.new(1,-18,0,34) arRow.Position = UDim2.new(0,9,0,176)
arRow.BackgroundColor3 = CARD arRow.BorderSizePixel = 0
Instance.new("UICorner", arRow).CornerRadius = UDim.new(0,7)
local arStroke = Instance.new("UIStroke", arRow)
arStroke.Color = STRK arStroke.Thickness = 1.2
local arLbl = Instance.new("TextLabel", arRow)
arLbl.Size = UDim2.new(1,-54,1,0) arLbl.Position = UDim2.new(0,10,0,0)
arLbl.BackgroundTransparency = 1 arLbl.Text = "AUTO RESET BALLOON"
arLbl.TextColor3 = TXT2 arLbl.TextSize = 11
arLbl.Font = Enum.Font.GothamBlack arLbl.TextXAlignment = Enum.TextXAlignment.Left
local arTrack = Instance.new("Frame", arRow)
arTrack.Size = UDim2.new(0,36,0,18) arTrack.Position = UDim2.new(1,-44,0.5,-9)
arTrack.BackgroundColor3 = Color3.fromRGB(15,14,19) arTrack.BorderSizePixel = 0
Instance.new("UICorner", arTrack).CornerRadius = UDim.new(1,0)
local arDot = Instance.new("Frame", arTrack)
arDot.Size = UDim2.new(0,14,0,14) arDot.Position = UDim2.new(0,2,0.5,-7)
arDot.BackgroundColor3 = TXT2 arDot.BorderSizePixel = 0
Instance.new("UICorner", arDot).CornerRadius = UDim.new(1,0)
local arBtn = Instance.new("TextButton", arRow)
arBtn.Size = UDim2.new(1,0,1,0) arBtn.BackgroundTransparency = 1
arBtn.Text = "" arBtn.AutoButtonColor = false arBtn.ZIndex = 2
arBtn.MouseButton1Click:Connect(function()
    autoResetBalloon = not autoResetBalloon
    local on = autoResetBalloon
    arLbl.TextColor3 = on and TXT or TXT2
    TweenService:Create(arTrack, TWEEN_FAST, {BackgroundColor3 = on and ORG or Color3.fromRGB(15,14,19)}):Play()
    TweenService:Create(arDot, TWEEN_FAST, {
        Position = on and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7),
        BackgroundColor3 = on and BG or TXT2
    }):Play()
    TweenService:Create(arStroke, TWEEN_FAST, {Color = on and ORG or STRK}):Play()
end)

-- keybinds
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F then
        flashBtn.MouseButton1Click:Fire()
    elseif input.KeyCode == Enum.KeyCode.R then
        doInstantReset()
    elseif input.KeyCode == Enum.KeyCode.E then
        local root = getRoot()
        if not root then return end
        local nearest, dist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= plr and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = (root.Position - hrp.Position).Magnitude
                    if d < dist then dist = d nearest = p end
                end
            end
        end
        if nearest then spamAP(nearest) end
    end
end)

print("VSZ Hub (Flash TP) loaded")
