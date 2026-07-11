-- == UnAlive Gear Spawner [STANDALONE] ==
-- Spawns any gear (sprinklers, watering cans, rakes, wheelbarrows) into your backpack.
-- Also enables client-side sprinkler placement via right-click.

if getgenv()._UnAliveGearSpawner then
    print("[UnAlive] Gear Spawner already loaded"); return
end
getgenv()._UnAliveGearSpawner = true

local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local CS = game:GetService("CollectionService"); local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Cont = player:WaitForChild("PlayerScripts"):WaitForChild("Controllers")

-- Gear data modules
local SprinklerData = require(RS.SharedModules.SprinklerData)
local WateringcanData = require(RS.SharedModules.WateringcanData)
local RakeData = require(RS.SharedModules.RakeData)
local WheelbarrowData = require(RS.SharedModules.WheelbarrowData)

-- Gear definitions + icons
local GEAR_DEFS = {}
local ICONS = {}

local function resolveImage(v)
    if type(v) == "number" then return "rbxassetid://" .. v end
    if type(v) == "string" then if v:find("rbxasset") then return v end; if v:match("^%d+$") then return "rbxassetid://" .. v end end
    if typeof(v) ~= "Instance" then return nil end
    if v:IsA("ImageLabel") or v:IsA("ImageButton") then return v.Image end
    if v:IsA("Decal") or v:IsA("Texture") then return v.Texture end
    if v:IsA("StringValue") then return v.Value end
    local img = v:FindFirstChildWhichIsA("ImageLabel", true); if img and img.Image ~= "" then return img.Image end
    return nil
end

for _, e in ipairs(SprinklerData) do
    if e.SprinklerName then
        ICONS[e.SprinklerName] = resolveImage(e.Image)
        GEAR_DEFS[e.SprinklerName] = { key = "Sprinkler", icon = ICONS[e.SprinklerName] }
    end
end
for _, e in ipairs(WateringcanData) do
    if e.Name then
        ICONS[e.Name] = resolveImage(e.Image)
        GEAR_DEFS[e.Name] = { key = "WateringCan", icon = ICONS[e.Name] }
    end
end
if type(RakeData) == "table" and RakeData.RakeName then
    ICONS[RakeData.RakeName] = resolveImage(RakeData.Image)
    GEAR_DEFS[RakeData.RakeName] = { key = "Rake", icon = ICONS[RakeData.RakeName] }
end
do
    local wb = type(WheelbarrowData) == "table" and (WheelbarrowData.Data or WheelbarrowData) or nil
    if wb and wb.Name then
        ICONS[wb.Name] = resolveImage(wb.IMG or wb.Image)
        GEAR_DEFS[wb.Name] = { key = "Wheelbarrow", icon = ICONS[wb.Name] }
    end
end

local function getGearNames()
    local t, seen = {}, {}
    local function add(n) if n and not seen[n] then seen[n] = true; table.insert(t, n) end end
    for _, e in ipairs(SprinklerData) do add(e.SprinklerName) end
    for _, e in ipairs(WateringcanData) do add(e.Name) end
    if type(RakeData) == "table" and RakeData.RakeName then add(RakeData.RakeName) end
    if type(WheelbarrowData) == "table" then
        local wb = WheelbarrowData.Data or WheelbarrowData
        if type(wb) == "table" and wb.Name then add(wb.Name) end
    end
    table.sort(t); return t
end

-- Backpack tool creation
local function backpack() return player:WaitForChild("Backpack") end
local function stackCount(t) return t:GetAttribute("Count") or 1 end
local function setStackCount(t, n) t:SetAttribute("Count", math.max(1, n)) end
local function consumeOne(t)
    local c = stackCount(t)
    if c > 1 then setStackCount(t, c - 1) else t:Destroy() end
end

local function makeTool(name)
    local t = Instance.new("Tool")
    t.Name = name; t.CanBeDropped = true; t.RequiresHandle = true; t:SetAttribute("_V", true)
    local h = Instance.new("Part"); h.Name = "Handle"; h.Size = Vector3.new(0.1, 0.1, 0.1)
    h.Transparency = 1; h.CanCollide = false; h.Anchored = false; h.Parent = t
    return t
end

local function findStack(match)
    local bp = backpack()
    local function scan(c)
        if not c then return nil end
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("_V") and match(t) then return t end
        end
        return nil
    end
    return scan(bp) or scan(player.Character)
end

local function addToStack(match, factory, amount)
    amount = math.clamp(tonumber(amount) or 1, 1, 999)
    local existing = findStack(match)
    if existing then
        setStackCount(existing, stackCount(existing) + amount)
        return amount
    end
    local t = factory()
    setStackCount(t, amount)
    t.Parent = backpack()
    return amount
end

-- Spawn gear
local function spawnGear(name, amount)
    local def = GEAR_DEFS[name]
    if not def then return "Unknown gear: " .. name end
    local icon = def.icon or ICONS[name]
    local spawned = addToStack(
        function(t) return t:GetAttribute(def.key) == name end,
        function()
            local t = makeTool(name)
            t:SetAttribute(def.key, name)
            t:SetAttribute("MainCategory", "Gears")
            if icon then t.TextureId = icon end
            return t
        end,
        amount
    )
    return "Spawned " .. spawned .. "x " .. name
end

-- Sprinkler placement hook (client-side visual)
local SprinklerCtrl = require(Cont:WaitForChild("SprinklerController"))
local SprinklerVis = require(Cont:WaitForChild("SprinklerVisualizerController"))
local GardenSync = require(Cont:WaitForChild("GardenSyncController"))

if not getgenv()._UnAliveSprHook then
    getgenv()._UnAliveSprHook = true
    local oldTry = SprinklerCtrl.TryPlace; local cd = 0
    SprinklerCtrl.TryPlace = function(self, mPos)
        local tool = self:GetEquippedTool()
        if not (tool and tool:GetAttribute("_V") and tool:GetAttribute("Sprinkler")) then return oldTry(self, mPos) end
        local now = os.clock(); if now - cd < 0.5 then return false end
        local gearName = tool:GetAttribute("Sprinkler")
        local rp = self:CreateRaycastParams(); local hit
        local cam = workspace.CurrentCamera
        if self:IsUsingGamepad() then
            local o, d = self:GetGamepadPlacementRay()
            if o then hit = workspace:Raycast(o, d, rp) end
        else
            local p = mPos or UIS:GetMouseLocation()
            local ray = cam:ViewportPointToRay(p.X, p.Y)
            hit = workspace:Raycast(ray.Origin, ray.Direction * 5000, rp)
        end
        if not hit then return false end; cd = now
        local uid = player.UserId
        local spawn = SprinklerVis:GetSpawnPoint(uid)
        if not spawn or not spawn.CFrame then return false end
        local lp = spawn.CFrame:PointToObjectSpace(hit.Position)
        local sid = Http:GenerateGUID(false)
        local _, pR = spawn.CFrame:ToEulerAnglesYXZ()
        local yR = 0
        if player.Character and player.Character.PrimaryPart then
            local _, y = player.Character.PrimaryPart.CFrame:ToEulerAnglesYXZ(); yR = math.deg(y)
        end
        local data = { SprinklerName = gearName, Positions = { PosX = lp.X, PosY = lp.Y, PosZ = lp.Z, Rotation = yR + math.deg(pR) }, PlacedAt = os.time() }
        GardenSync:HandleSprinklerAdded(uid, sid, data)
        consumeOne(tool)
        print("[UnAlive] Placed " .. gearName)
        return true
    end
end

-- Expose API
getgenv()._UnAliveGearAPI = {
    spawn = spawnGear,
    list = getGearNames,
    defs = GEAR_DEFS,
    icons = ICONS,
}

print("[UnAlive] Gear Spawner loaded — use _UnAliveGearAPI.spawn(\"Basic Sprinkler\", 5)")
