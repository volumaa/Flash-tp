-- leaked by https://discord.gg/eZ5RcpXZ7c

local stealCooldown = 0.2
local HOLD_DURATION = 0.5
local USE_TELEPORT = false  -- not used in this version

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Variables for the stealing loop
local stealingEnabled = false
local stealLoopCoroutine = nil

-- Helper functions (adapted from original)
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getCharacter()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function getPromptPart(prompt)
    local parent = prompt.Parent
    if parent:IsA("BasePart") then return parent end
    if parent:IsA("Model") then
        return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
    end
    if parent:IsA("Attachment") then return parent.Parent end
    return parent:FindFirstChildWhichIsA("BasePart", true)
end

local function findNearestStealPrompt(hrp)
    local nearestPrompt = nil
    local minDist = math.huge
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end

    for _, desc in pairs(plots:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled and desc.ActionText == "Steal" then
            local part = getPromptPart(desc)
            if part then
                local dist = (hrp.Position - part.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearestPrompt = desc
                end
            end
        end
    end
    return nearestPrompt
end

local function triggerPrompt(prompt)
    if not prompt or not prompt:IsDescendantOf(workspace) then return end

    prompt.MaxActivationDistance = 9e9
    prompt.RequiresLineOfSight = false
    prompt.ClickablePrompt = true

    local usedFire = pcall(function()
        fireproximityprompt(prompt, 9e9, HOLD_DURATION)
    end)

    if not usedFire then
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(HOLD_DURATION)
            prompt:InputHoldEnd()
        end)
    end
end

-- Main stealing loop
local function stealLoop()
    while stealingEnabled do
        local hrp = getHRP()
        if hrp then
            local prompt = findNearestStealPrompt(hrp)
            if prompt then
                triggerPrompt(prompt)
            end
        else
            -- Wait for character to respawn
            LocalPlayer.CharacterAdded:Wait()
        end
        task.wait(stealCooldown)
    end
end

-- Function to start/stop stealing
local function setStealing(state)
    if state == stealingEnabled then return end
    stealingEnabled = state

    if stealingEnabled then
        stealLoopCoroutine = coroutine.create(stealLoop)
        coroutine.resume(stealLoopCoroutine)
    else
        stealLoopCoroutine = nil
    end
end

-- Create the GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoStealGUI"
screenGui.ResetOnSpawn = false  -- Keep GUI on respawn
screenGui.Parent = PlayerGui

-- Main frame (black box with white outline)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 200, 0, 100)
mainFrame.Position = UDim2.new(0.5, -100, 0.5, -50)  -- centered
mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)  -- pure black
mainFrame.BackgroundTransparency = 0  -- opaque
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)  -- 8px radius
corner.Parent = mainFrame

-- White outline
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.new(1, 1, 1)  -- white
stroke.Transparency = 0
stroke.Parent = mainFrame

-- Optional subtle inner shadow for depth (using another frame)
local shadowFrame = Instance.new("Frame")
shadowFrame.Size = UDim2.new(1, -4, 1, -4)
shadowFrame.Position = UDim2.new(0, 2, 0, 2)
shadowFrame.BackgroundColor3 = Color3.new(0, 0, 0)
shadowFrame.BackgroundTransparency = 0.5  -- semi-transparent for shadow effect
shadowFrame.BorderSizePixel = 0
shadowFrame.ZIndex = 0
shadowFrame.Parent = mainFrame

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 6)  -- slightly smaller radius
shadowCorner.Parent = shadowFrame

-- Title label
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "AUTO STEAL"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextStrokeTransparency = 0.7
titleLabel.Parent = mainFrame

-- Toggle button (sleek modern)
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0.8, 0, 0, 35)
toggleButton.Position = UDim2.new(0.1, 0, 0, 50)
toggleButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)  -- dark gray, not pure black
toggleButton.Text = "START"
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.TextScaled = true
toggleButton.Font = Enum.Font.Gotham
toggleButton.AutoButtonColor = false  -- we handle custom hover
toggleButton.Parent = mainFrame

-- Button corner rounding
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = toggleButton

-- Button white outline (thin)
local buttonStroke = Instance.new("UIStroke")
buttonStroke.Thickness = 1
buttonStroke.Color = Color3.new(1, 1, 1)
buttonStroke.Transparency = 0
buttonStroke.Parent = toggleButton

-- Button hover effects (modern glow)
toggleButton.MouseEnter:Connect(function()
    TweenService:Create(toggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)}):Play()
end)
toggleButton.MouseLeave:Connect(function()
    TweenService:Create(toggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)}):Play()
end)

-- Toggle logic
toggleButton.MouseButton1Click:Connect(function()
    if stealingEnabled then
        setStealing(false)
        toggleButton.Text = "START"
        TweenService:Create(toggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)}):Play()
    else
        setStealing(true)
        toggleButton.Text = "STOP"
        TweenService:Create(toggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.new(0.1, 0.5, 0.1)}):Play()  -- greenish when on
    end
end)

-- Make the frame draggable (optional)
local dragging = false
local dragInput, dragStart, startPos

local function updateInput(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

mainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateInput(input)
    end
end)

-- Clean up when GUI is destroyed
screenGui.Destroying:Connect(function()
    setStealing(false)
end)

print("Auto Steal GUI loaded. (Sleek modern edition)")