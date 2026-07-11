-- == UnAlive Guild Competition Auto-Farmer ==
-- Auto-detects comp requirement, restocks shop, buys seeds, plants, harvests.

if getgenv()._GuildComp then pcall(getgenv()._GuildComp.stop) end

local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local CS = game:GetService("CollectionService"); local LP = Players.LocalPlayer
local Net
do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
local SeedData do local ok, d = pcall(require, RS.SharedModules.SeedData); if ok then SeedData = d end end
local running = false
local compCache = nil

local PLANT_LIST = {"Carrot","Strawberry","Tomato","Blueberry","Apple","Banana","Grape","Mango","Cherry","Sunflower","Pineapple","Cactus","Mushroom","Bamboo","Corn","Green Bean","Coconut","Dragon Fruit","Acorn","Pomegranate","Poison Apple","Moon Bloom","Ghost Pepper","Venus Fly Trap","Glow Mushroom","Baby Cactus","Tulip"}

local function myPlot()
    local id = LP:GetAttribute("PlotId")
    if not id then local g = WS:FindFirstChild("Gardens"); if not g then return nil end; for _, p in ipairs(g:GetChildren()) do local sp = p:FindFirstChild("SpawnPoint"); if sp and LP.Character and (sp.Position - LP.Character:GetPivot().Position).Magnitude < 50 then return p end end; return nil end
    return WS:FindFirstChild("Gardens") and WS.Gardens:FindFirstChild("Plot" .. tostring(id))
end

local function getSheckles()
    local ls = LP:FindFirstChild("leaderstats"); return ls and tonumber(ls.Sheckles.Value) or 0
end

local function checkComp()
    local ok, comp = pcall(function() return Net.Guild.GetCompetition:Fire() end)
    if ok and comp then compCache = comp end
    return compCache
end

local function getTargetPlant(comp)
    if not comp or not comp.lastConfig then return nil end
    local cfg = comp.lastConfig
    local signals = {}
    if cfg.id then table.insert(signals, cfg.id) end
    if cfg.displayName then table.insert(signals, cfg.displayName) end
    if cfg.tags then for tag, _ in pairs(cfg.tags) do table.insert(signals, tag) end end
    if cfg.description then for _, desc in ipairs(cfg.description) do for _, word in ipairs(desc:split(" ")) do table.insert(signals, word) end end end
    local scores = {}
    for _, plant in ipairs(PLANT_LIST) do
        local score = 0; local pl = plant:lower()
        for _, sig in ipairs(signals) do local sl = tostring(sig):lower(); if sl:find(pl) then score = score + 1 end end
        if score > 0 then scores[plant] = score end
    end
    local bestPlant, bestScore = nil, 0
    for plant, score in pairs(scores) do if score > bestScore then bestPlant, bestScore = plant, score end end
    if not bestPlant and cfg.description then
        for _, desc in ipairs(cfg.description) do local dl = desc:lower()
            if dl:find("heaviest") or dl:find("biggest") then for _, plant in ipairs(PLANT_LIST) do if dl:find(plant:lower()) then return plant end end end
        end
    end
    return bestPlant
end

local function getSeedPrice(plantName)
    if not SeedData then return 1 end
    for _, v in pairs(SeedData) do if type(v) == "table" and v.SeedName == plantName then return v.PurchasePrice or 1 end end
    return 1
end

-- Restock shop then buy seeds
local function buySeeds(plantName, maxCount)
    local bought = 0
    local price = getSeedPrice(plantName)
    -- Try restock first
    pcall(function() Net.SeedShop.PersonalRestock:Fire(plantName, 1) end)
    task.wait(0.3)
    for i = 1, maxCount do
        if not running then break end
        if getSheckles() < price then break end
        Net.SeedShop.PurchaseSeed:Fire(plantName)
        bought = bought + 1
        task.wait(0.3)
    end
    return bought
end

local function findSeedTool(plantName)
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return nil end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t:GetAttribute("SeedTool") == plantName then return t end
    end
    if LP.Character then
        for _, t in ipairs(LP.Character:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("SeedTool") == plantName then return t end
        end
    end
    return nil
end

local function getPlantPositions()
    local pos = {}
    local plot = myPlot()
    if not plot then return pos end
    for _, area in ipairs(CS:GetTagged("PlantArea")) do
        if area:IsA("BasePart") and area:IsDescendantOf(plot) then
            local cf, size = area.CFrame, area.Size; local spacing = 4
            local topY = (cf * CFrame.new(0, size.Y / 2, 0)).Position.Y
            local p = RaycastParams.new(); p.FilterType = Enum.RaycastFilterType.Include; p.FilterDescendantsInstances = {area}
            for dx = -size.X / 2 + spacing / 2, size.X / 2 - spacing / 2, spacing do
                for dz = -size.Z / 2 + spacing / 2, size.Z / 2 - spacing / 2, spacing do
                    local w = (cf * CFrame.new(dx, 0, dz)).Position
                    local hit = WS:Raycast(Vector3.new(w.X, topY + 10, w.Z), Vector3.new(0, -40, 0), p)
                    if hit then table.insert(pos, hit.Position) end
                end
            end
        end
    end
    return pos
end

local function getOccupied()
    local out = {}
    local plot = myPlot(); local plants = plot and plot:FindFirstChild("Plants")
    if not plants then return out end
    for _, m in ipairs(plants:GetChildren()) do
        local ok, piv = pcall(function() return m:GetPivot().Position end)
        if ok then table.insert(out, piv) end
    end
    return out
end

local function harvestRipe()
    local h = 0
    for _, pr in ipairs(CS:GetTagged("HarvestPrompt")) do
        if not running then break end
        if pr:IsA("ProximityPrompt") and pr.Enabled and pr:IsDescendantOf(WS) then
            local n = pr.Parent; while n and n ~= WS and n:GetAttribute("PlantId") == nil do n = n.Parent end
            local m = n or pr:FindFirstAncestorWhichIsA("Model")
            if m then
                local pid = m:GetAttribute("PlantId")
                if pid then
                    local uid = tonumber(m:GetAttribute("UserId"))
                    if uid == nil or uid == LP.UserId then
                        Net.Garden.CollectFruit:Fire(tostring(pid), tostring(m:GetAttribute("FruitId") or "")); h = h + 1; task.wait(0.05)
                    end
                end
            end
        end
    end
    return h
end

local function plantSeeds(plantName, count)
    local planted = 0
    local positions = getPlantPositions(); local occupied = getOccupied()
    for _, pos in ipairs(positions) do
        if planted >= count or not running then break end
        local clear = true
        for _, op in ipairs(occupied) do if (Vector2.new(pos.X, pos.Z) - Vector2.new(op.X, op.Z)).Magnitude < 1 then clear = false; break end end
        if not clear then continue end
        local tool = findSeedTool(plantName)
        if not tool then
            local b = buySeeds(plantName, 20)
            if b == 0 then break end
            task.wait(0.5); tool = findSeedTool(plantName)
        end
        if not tool then break end
        if LP.Character and LP.Character:FindFirstChild("Humanoid") then
            if LP.Character:FindFirstChildWhichIsA("Tool") ~= tool then LP.Character.Humanoid:EquipTool(tool); task.wait(0.15) end
        end
        Net.Plant.PlantSeed:Fire(pos, plantName, tool); planted = planted + 1; table.insert(occupied, pos); task.wait(0.1)
    end
    return planted
end

local function cycle()
    local comp = checkComp()
    if not comp then return end
    local cfg = comp.lastConfig
    if not cfg then return end
    local plantName = getTargetPlant(comp)
    if not plantName then return end

    harvestRipe()
    local pos = getPlantPositions(); local occ = getOccupied()
    local empty = #pos - #occ
    if empty > 0 then
        local tool = findSeedTool(plantName)
        if not tool then buySeeds(plantName, empty) end
        plantSeeds(plantName, empty)
    end
end

task.spawn(function()
    while true do
        if running then pcall(cycle) end
        task.wait(10)
    end
end)

getgenv()._GuildComp = {
    start = function() running = true; local c = checkComp(); print("[GuildComp] Started - " .. (c and c.lastConfig and c.lastConfig.displayName or "?")) end,
    stop = function() running = false; print("[GuildComp] Stopped") end,
    status = function() local c = compCache or checkComp(); if not c then return "No data" end; local cfg = c.lastConfig; return { name = cfg and cfg.displayName, plant = getTargetPlant(c), phase = c.phase, mode = cfg and cfg.mode } end,
    check = function() pcall(cycle) end
}

print("[GuildComp] Loaded. Use .start()")
