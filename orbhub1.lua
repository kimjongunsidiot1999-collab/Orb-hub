--[[ ORB HUB · copy this whole block into your executor ]]
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local HS = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local LP = Players.LocalPlayer

local OH = {
    SinkDepth = 6.8,
    Walkspeed = 24,
    WalkspeedEnabled = true,
    InfiniteJump = true,
    AutoTP = false,
    AutoInvisOnSteal = true,
    AutoCloneAtBase = false,
    BrainrotESP = true,
    ESPMinGen = 5000,
    invisible = false,
}

-- kick block
pcall(function()
    if type(hookfunction) == "function" then
        local kick = LP.Kick
        if type(kick) == "function" then
            hookfunction(kick, function() end)
        end
    end
end)
pcall(function()
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local ok, method = pcall(getnamecallmethod)
        if ok and self == LP and (method == "Kick" or method == "kick") then
            return nil
        end
        return old(self, ...)
    end)
end)
pcall(function()
    if type(getconnections) ~= "function" then return end
    for _, c in ipairs(getconnections(LP.Idled)) do
        pcall(function() c:Disable() end)
    end
end)

local orb, conn
local surfacePos = Vector3.zero
local velY, sinkNow = 0, 0
local jumpQueued = false
local stickTouch, stickStart, stickVec = nil, nil, Vector3.zero
local hooked, hookedRel, hookedAt = Vector3.zero, true, 0
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

pcall(function()
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local ok, method = pcall(getnamecallmethod)
        if ok and method == "Move" and typeof(self) == "Instance" and self.ClassName == "Humanoid" and self.Parent == LP.Character then
            local vec, rel = ...
            if typeof(vec) == "Vector3" then
                hooked, hookedRel, hookedAt = vec, rel ~= false, tick()
            end
        end
        return old(self, ...)
    end)
end)

local function inStick(pos)
    local vs = workspace.CurrentCamera.ViewportSize
    return pos.X < vs.X * 0.5 and pos.Y > vs.Y * 0.38
end
UIS.InputBegan:Connect(function(input)
    if not OH.invisible or input.UserInputType ~= Enum.UserInputType.Touch or stickTouch then return end
    if not inStick(input.Position) then return end
    stickTouch, stickStart, stickVec = input, input.Position, Vector3.zero
end)
UIS.InputChanged:Connect(function(input)
    if input ~= stickTouch or not stickStart then return end
    local d = input.Position - stickStart
    local mag = math.clamp(Vector2.new(d.X, d.Y).Magnitude / 55, 0, 1)
    if mag < 0.15 then stickVec = Vector3.zero return end
    local dir = Vector2.new(d.X, d.Y).Unit * mag
    stickVec = Vector3.new(dir.X, 0, dir.Y)
end)
UIS.InputEnded:Connect(function(input)
    if input ~= stickTouch then return end
    stickTouch, stickStart, stickVec = nil, nil, Vector3.zero
end)

local function flat(cam, raw)
    if not cam or raw.Magnitude < 0.08 then return Vector3.zero end
    local scale = math.clamp(raw.Magnitude, 0, 1)
    if raw.Magnitude > 1 then raw = raw.Unit end
    local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
    local fl, fr = Vector3.new(look.X, 0, look.Z), Vector3.new(right.X, 0, right.Z)
    if fl.Magnitude < 0.2 then
        local up = cam.CFrame.UpVector
        fl = Vector3.new(up.X, 0, up.Z)
    end
    if fl.Magnitude < 0.01 then fl = Vector3.new(0, 0, -1) end
    if fr.Magnitude < 0.01 then fr = Vector3.new(1, 0, 0) end
    local w = fr.Unit * raw.X + fl.Unit * -raw.Z
    if w.Magnitude < 0.05 then return Vector3.zero end
    return w.Unit * scale
end

local function wish(hum)
    local cam = workspace.CurrentCamera
    if stickVec.Magnitude > 0.08 then
        local w = flat(cam, stickVec)
        if w.Magnitude > 0.05 then return w end
    end
    if tick() - hookedAt < 0.2 and hooked.Magnitude > 0.08 then
        if hookedRel then
            local w = flat(cam, hooked)
            if w.Magnitude > 0.05 then return w end
        else
            local w = Vector3.new(hooked.X, 0, hooked.Z)
            if w.Magnitude > 0.05 then return w.Unit end
        end
    end
    local x, z = 0, 0
    if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then x -= 1 end
    if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then x += 1 end
    if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up) then z -= 1 end
    if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down) then z += 1 end
    if x ~= 0 or z ~= 0 then
        local w = flat(cam, Vector3.new(x, 0, z))
        if w.Magnitude > 0.05 then return w end
    end
    if hum and hum.MoveDirection.Magnitude > 0.08 then
        local m = hum.MoveDirection
        return Vector3.new(m.X, 0, m.Z).Unit
    end
    return Vector3.zero
end

local function groundY(pos, ignore)
    groundParams.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 8, pos.Z), Vector3.new(0, -24, 0), groundParams)
    if not hit then
        hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 120, pos.Z), Vector3.new(0, -600, 0), groundParams)
    end
    return hit and hit.Position.Y
end

local function makeOrb(at)
    if orb and orb.Parent then
        orb.CFrame = CFrame.new(at)
        return orb
    end
    local p = Instance.new("Part")
    p.Name = "OrbProxy"
    p.Shape = Enum.PartType.Ball
    p.Size = Vector3.new(2.2, 2.2, 2.2)
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(140, 210, 255)
    p.Transparency = 0.15
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CFrame = CFrame.new(at)
    p.Parent = workspace
    orb = p
    return p
end

local function restore()
    if conn then conn:Disconnect() conn = nil end
    OH.invisible = false
    stickVec = Vector3.zero
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hrp and surfacePos.Magnitude > 1 then
        pcall(function()
            hrp.CFrame = CFrame.new(surfacePos + Vector3.new(0, 3, 0))
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CanCollide = true
            hrp.Transparency = 0
        end)
    end
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.CanCollide = true end)
            end
        end
    end
    if orb then pcall(function() orb:Destroy() end) orb = nil end
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam and hum then
            cam.CameraSubject = hum
            cam.CameraType = Enum.CameraType.Custom
        end
    end)
end

local function enable()
    if OH.invisible then return end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    OH.invisible = true
    surfacePos = hrp.Position
    velY, sinkNow = 0, 0
    local hip = 3
    local gy = groundY(hrp.Position, {char})
    if gy then hip = math.clamp(hrp.Position.Y - gy, 1.5, 6) end
    local o = makeOrb(surfacePos + Vector3.new(0, 1.2, 0))
    pcall(function()
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        workspace.CurrentCamera.CameraSubject = o
    end)
    local spaceWas = false
    conn = RunService.Heartbeat:Connect(function(dt)
        if not OH.invisible or not hrp.Parent then restore() return end
        dt = math.clamp(dt or 0.016, 0.001, 0.05)
        sinkNow = sinkNow + (OH.SinkDepth - sinkNow) * math.clamp(dt * 3.5, 0, 1)
        local speed = OH.WalkspeedEnabled and OH.Walkspeed or 16
        local dir = wish(hum)
        local step = dir * speed * dt
        if step.Magnitude > 2.4 then step = step.Unit * 2.4 end
        local nextPos = surfacePos + Vector3.new(step.X, 0, step.Z)
        local ignore = {char, orb}
        local gy2 = groundY(nextPos, ignore)
        local standY = gy2 and (gy2 + hip) or surfacePos.Y
        local grounded = surfacePos.Y <= standY + 0.45 and velY <= 1
        local edge = jumpQueued
        jumpQueued = false
        local space = UIS:IsKeyDown(Enum.KeyCode.Space)
        if space and not spaceWas then edge = true end
        spaceWas = space
        if edge and (grounded or OH.InfiniteJump) then
            velY = 52
            grounded = false
        end
        local newY
        if grounded and velY <= 0 then
            newY, velY = standY, 0
        else
            velY = velY - 96 * dt
            newY = surfacePos.Y + velY * dt
            if gy2 and newY <= gy2 + hip then newY, velY = gy2 + hip, 0 end
        end
        surfacePos = Vector3.new(nextPos.X, newY, nextPos.Z)
        local look = dir.Magnitude > 0.05 and dir or Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
        if look.Magnitude < 0.05 then look = Vector3.new(0, 0, -1) else look = look.Unit end
        local body = surfacePos - Vector3.new(0, sinkNow, 0)
        pcall(function()
            hum.PlatformStand = false
            hum.AutoRotate = false
            hrp.CanCollide = false
            hrp.Transparency = 1
            hrp.CFrame = CFrame.new(body, body + look)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part ~= hrp then
                    part.CanCollide = false
                end
            end
        end)
        local ball = makeOrb(surfacePos + Vector3.new(0, 1.2, 0))
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam.CameraSubject ~= ball then
                cam.CameraType = Enum.CameraType.Custom
                cam.CameraSubject = ball
            end
        end)
    end)
end

UIS.JumpRequest:Connect(function()
    if OH.invisible then
        jumpQueued = true
        return
    end
    if not OH.InfiniteJump then return end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

LP:GetAttributeChangedSignal("Stealing"):Connect(function()
    if not OH.AutoInvisOnSteal then return end
    if LP:GetAttribute("Stealing") then
        task.wait(0.25)
        if not OH.invisible then enable() end
    else
        task.wait(0.3)
        if OH.invisible then restore() end
    end
end)
LP.CharacterAdded:Connect(function()
    restore()
end)

-- tiny button. tap the orb icon to turn move-mode on or off
local guiParent = (gethui and gethui()) or game:GetService("CoreGui") or LP:WaitForChild("PlayerGui")
pcall(function()
    local old = guiParent:FindFirstChild("OrbHubBtn")
    if old then old:Destroy() end
end)
local sg = Instance.new("ScreenGui")
sg.Name = "OrbHubBtn"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 1000000
sg.Parent = guiParent
local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(64, 64)
btn.Position = UDim2.new(0, 16, 0.4, 0)
btn.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
btn.Text = "ORB\nOFF"
btn.TextColor3 = Color3.fromRGB(180, 230, 255)
btn.Font = Enum.Font.GothamBlack
btn.TextSize = 14
btn.Parent = sg
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, 16)
c.Parent = btn
btn.MouseButton1Click:Connect(function()
    if OH.invisible then
        restore()
        btn.Text = "ORB\nOFF"
    else
        enable()
        btn.Text = "ORB\nON"
    end
end)

print("[ORB] ready · tap ORB · drag lower-left to move · body stays under the orb")
