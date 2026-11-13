--[[
    ORB HUB · SNOW EDITION v2.2 (orb drive)
    ─────────────────────────
    snow UI · deep underground hitbox
    infinite jump · auto TP · auto clone at base
    brainrot ESP · stronger unhittable
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UIS               = game:GetService("UserInputService")
local TS                = game:GetService("TweenService")
local HS                = game:GetService("HttpService")
local RS                = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local LP                = Players.LocalPlayer

-- ═══════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════
local CFG_FILE = "OrbHubSnow.json"

local function loadCfg()
    local d = {}
    if type(isfile) == "function" and isfile(CFG_FILE) then
        pcall(function()
            local t = HS:JSONDecode(readfile(CFG_FILE))
            if type(t) == "table" then d = t end
        end)
    end
    return d
end

local function saveCfg(data)
    if type(writefile) == "function" then
        pcall(function() writefile(CFG_FILE, HS:JSONEncode(data)) end)
    end
end

local cfg = loadCfg()

_G.OrbHub = _G.OrbHub or {}
local OH = _G.OrbHub

OH.InvisAngle         = cfg.InvisAngle or 6
OH.SinkDepth          = cfg.SinkDepth or 6.8
OH.AutoInvisOnSteal   = cfg.AutoInvisOnSteal \~= false
OH.AutoRecoverLagback = cfg.AutoRecoverLagback \~= false
OH.Walkspeed          = cfg.Walkspeed or 24
OH.WalkspeedEnabled   = cfg.WalkspeedEnabled \~= false
OH.AutoTP             = cfg.AutoTP == true
OH.InfiniteJump       = cfg.InfiniteJump \~= false
OH.AutoCloneAtBase    = cfg.AutoCloneAtBase == true
OH.BrainrotESP        = cfg.BrainrotESP \~= false
OH.ESPMinGen          = cfg.ESPMinGen or 5000
OH.FOV                = cfg.FOV or 75
OH.SnowEnabled        = cfg.SnowEnabled \~= false
OH.UIVisible          = true
OH.invisibleStealEnabled = false

local function persist()
    saveCfg({
        InvisAngle         = OH.InvisAngle,
        SinkDepth          = OH.SinkDepth,
        AutoInvisOnSteal   = OH.AutoInvisOnSteal,
        AutoRecoverLagback = OH.AutoRecoverLagback,
        Walkspeed          = OH.Walkspeed,
        WalkspeedEnabled   = OH.WalkspeedEnabled,
        AutoTP             = OH.AutoTP,
        InfiniteJump       = OH.InfiniteJump,
        AutoCloneAtBase    = OH.AutoCloneAtBase,
        BrainrotESP        = OH.BrainrotESP,
        ESPMinGen          = OH.ESPMinGen,
        FOV                = OH.FOV,
        SnowEnabled        = OH.SnowEnabled,
    })
end

local chanTable = {}
local function getPackages()
    return RS:FindFirstChild("Packages") or RS:WaitForChild("Packages", 8)
end

local function pullPlot(name)
    local pk = getPackages()
    local sy = pk and pk:FindFirstChild("Synchronizer")
    local rf = sy and sy:FindFirstChild("RequestData")
    if not rf or not rf:IsA("RemoteFunction") then return nil end
    local ok, res = pcall(function() return rf:InvokeServer(name) end)
    if ok and type(res) == "table" then
        chanTable[name] = res
        return res
    end
    return nil
end

local function animalsOf(ct)
    if type(ct) \~= "table" then return nil end
    return rawget(ct, "AnimalList") or rawget(ct, "Animals")
end

local function ownerName(o)
    if o == nil then return nil end
    if typeof(o) == "Instance" then return o.Name end
    if type(o) == "table" then return o.Name end
    if type(o) == "string" and o \~= "" and o \~= "..." then return o end
    return nil
end

local function getGen(animal)
    local gen = 0
    pcall(function()
        if _G._xenGen then
            gen = _G._xenGen(animal.Index, animal.Mutation, animal.Traits) or 0
        elseif _G.JAF_SafeGen then
            gen = _G.JAF_SafeGen(animal.Index, animal.Mutation, animal.Traits) or 0
        end
    end)
    return gen
end

local function scanAllAnimals()
    local out = {}
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return out end
    for _, plot in ipairs(plots:GetChildren()) do
        local ct = chanTable[plot.Name] or pullPlot(plot.Name)
        if type(ct) == "table" then
            local al = animalsOf(ct)
            local owner = ownerName(rawget(ct, "Owner"))
            if type(al) == "table" then
                for slot, animal in pairs(al) do
                    if type(animal) == "table" and animal.Index then
                        local gen = getGen(animal)
                        table.insert(out, {
                            name = animal.Index,
                            mutation = animal.Mutation,
                            gen = gen,
                            owner = owner,
                            plot = plot.Name,
                            slot = tostring(slot),
                            uid = plot.Name .. "_" .. tostring(slot),
                        })
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return (a.gen or 0) > (b.gen or 0) end)
    return out
end

task.spawn(function()
    local plots = workspace:WaitForChild("Plots", 10)
    if not plots then return end
    for _, p in ipairs(plots:GetChildren()) do
        task.spawn(pullPlot, p.Name)
    end
    plots.ChildAdded:Connect(function(p)
        task.wait(0.4)
        pullPlot(p.Name)
    end)
end)

local invisConn, lagbackConn
local lastToggle = 0
local lastGoodCF = CFrame.new()
local lastApply = 0
local surfaceOrb = nil
local surfacePos = Vector3.zero
local orbSpeed = 28

local function destroyOrb()
    if surfaceOrb then
        pcall(function() surfaceOrb:Destroy() end)
        surfaceOrb = nil
    end
    pcall(function()
        local cam = workspace.CurrentCamera
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if cam and hum then
            cam.CameraSubject = hum
            cam.CameraType = Enum.CameraType.Custom
        end
    end)
end

local function ensureOrb(atPos)
    if surfaceOrb and surfaceOrb.Parent then
        surfaceOrb.CFrame = CFrame.new(atPos)
        return surfaceOrb
    end

    local orb = Instance.new("Part")
    orb.Name = "OrbProxy"
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(2.4, 2.4, 2.4)
    orb.Material = Enum.Material.Neon
    orb.Color = Color3.fromRGB(80, 255, 140)
    orb.Transparency = 0.22
    orb.Anchored = true
    orb.CanCollide = false
    orb.CanQuery = false
    orb.CanTouch = false
    orb.CastShadow = false
    orb.CFrame = CFrame.new(atPos)
    orb.Parent = workspace.CurrentCamera

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(90, 255, 150)
    light.Brightness = 3.2
    light.Range = 16
    light.Parent = orb

    local ring = Instance.new("Part")
    ring.Name = "OrbRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.12, 3.8, 3.8)
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(60, 255, 120)
    ring.Transparency = 0.38
    ring.Anchored = true
    ring.CanCollide = false
    ring.CFrame = CFrame.new(atPos) * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = orb

    local ring2 = Instance.new("Part")
    ring2.Name = "OrbRing2"
    ring2.Shape = Enum.PartType.Cylinder
    ring2.Size = Vector3.new(0.08, 4.4, 4.4)
    ring2.Material = Enum.Material.Neon
    ring2.Color = Color3.fromRGB(140, 255, 180)
    ring2.Transparency = 0.52
    ring2.Anchored = true
    ring2.CanCollide = false
    ring2.CFrame = CFrame.new(atPos) * CFrame.Angles(0, 0, math.rad(90))
    ring2.Parent = orb

    surfaceOrb = orb
    return orb
end

local function cleanupInvis()
    if invisConn then pcall(function() invisConn:Disconnect() end) invisConn = nil end
    if lagbackConn then pcall(function() lagbackConn:Disconnect() end) lagbackConn = nil end
    destroyOrb()
    local char = LP.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRoot