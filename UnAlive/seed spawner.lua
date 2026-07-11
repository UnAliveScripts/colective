-- == UnAlive Seed Spawner + Planter [STANDALONE] ==
-- Spawns any seed into your backpack with stacking, then plant on your plot.
-- Client-side: mutations, position checks, growth animation, harvest support.

if getgenv()._UnAliveSeedSpawner then
    print("[UnAlive] Seed Spawner already loaded"); return
end
getgenv()._UnAliveSeedSpawner = true

local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace")
local CS = game:GetService("CollectionService"); local TS = game:GetService("TweenService"); local Debris = game:GetService("Debris")
local Http = game:GetService("HttpService"); local PPS = game:GetService("ProximityPromptService")
local UIS = game:GetService("UserInputService"); local player = Players.LocalPlayer

-- Data modules
local SeedData = require(RS.SharedModules.SeedData)
local GrowRateData = require(RS.SharedModules.GrowRateData)
local PlantSizeMultipliers = require(RS.SharedModules.PlantSizeMultipliers)
local SellValueData = require(RS.SharedModules.SellValueData)
local MutationData = require(RS.SharedModules.MutationData)

-- Controllers
local Cont = player:WaitForChild("PlayerScripts"):WaitForChild("Controllers")
local PlantCtrl = require(Cont:WaitForChild("PlantController"))
local PlantVis = require(Cont:WaitForChild("PlantVisualizerController"))
local FruitVis = require(Cont:WaitForChild("FruitVisualizerController"))
local GardenSync = require(Cont:WaitForChild("GardenSyncController"))
local MutCtrl = require(Cont:WaitForChild("MutationController"))
local SeedsAsset = RS.Assets:FindFirstChild("Seeds")

-- Seed icons
local ICONS = {}
for _, e in ipairs(SeedData) do
    if e.SeedName then
        local img = e.SeedImage
        if typeof(img) == "Instance" then
            if img:IsA("ImageLabel") then ICONS[e.SeedName] = img.Image elseif img:IsA("StringValue") then ICONS[e.SeedName] = img.Value end
        elseif type(img) == "string" then ICONS[e.SeedName] = img end
    end
end

local function allSeedNames()
    local t = {}; for _, e in ipairs(SeedData) do if e.SeedName then table.insert(t, e.SeedName) end end; return t
end

-- ══════ Backpack tool management ══════
local function backpack() return player:WaitForChild("Backpack") end
local function stackCount(t) return t:GetAttribute("Count") or 1 end
local function setStack(t, n) t:SetAttribute("Count", math.max(1, n)) end
local function consumeOne(t) local c = stackCount(t); if c > 1 then setStack(t, c - 1) else t:Destroy() end end

local function findStack(match)
    for _, c in ipairs({ backpack(), player.Character }) do
        if c then for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("_V") and match(t) then return t end end end
    end; return nil
end

local function addToStack(match, factory, amount)
    amount = math.clamp(tonumber(amount) or 1, 1, 999)
    local existing = findStack(match)
    if existing then setStack(existing, stackCount(existing) + amount); return amount end
    local t = factory(); setStack(t, amount); t.Parent = backpack(); return amount
end

local function makeTool(name)
    local t = Instance.new("Tool"); t.Name = name; t.CanBeDropped = true; t.RequiresHandle = true; t:SetAttribute("_V", true)
    local h = Instance.new("Part"); h.Name = "Handle"; h.Size = Vector3.new(0.1, 0.1, 0.1); h.Transparency = 1; h.CanCollide = false; h.Anchored = false; h.Parent = t; return t
end

local function spawnSeed(name, amount)
    local icon = ICONS[name]
    local spawned = addToStack(
        function(t) return t:GetAttribute("SeedTool") == name end,
        function()
            local t = makeTool(name); t:SetAttribute("SeedTool", name); t:SetAttribute("MainCategory", "Seeds")
            if icon then t.TextureId = icon end; return t
        end, amount
    )
    return "Spawned " .. spawned .. "x " .. name
end

-- ══════ Weather → mutation ══════
local WeatherMul = {
    Rainbow = { Rainbow = 3, Gold = 1.5 }, Bloodmoon = { Bloodlit = 3 }, Snowfall = { Frozen = 3, Electric = 1.5 },
    Goldmoon = { Gold = 3, Rainbow = 1.5 }, ["Rainbow Moon"] = { Rainbow = 5, Gold = 2 },
    ["Chained Moon"] = { Chained = 3 }, ["Pizza Moon"] = { Pizza = 3 },
    Starfall = { Starstruck = 3, Aurora = 1.5 }, Aurora = { Aurora = 3, Starstruck = 1.5 },
    ["Mega Moon"] = { Mega = 3 }, Sunburst = { Ignited = 3, Electric = 1.5 }, Lightning = { Electric = 2 },
}

local function detectWeather()
    local night = RS:FindFirstChild("Night")
    if night and night.Value == true then
        local wv = RS:FindFirstChild("WeatherValues")
        if wv then for name in pairs(WeatherMul) do local f = wv:FindFirstChild(name); if f and f:IsA("Folder") then for _, c in f:GetChildren() do if c:IsA("BoolValue") and c.Value then return name end end end end end
        return "Night"
    end
    local mt = game:GetService("SoundService"):FindFirstChild("SFX"):FindFirstChild("MusicTracks")
    if mt then for _, c in mt:GetChildren() do if c:IsA("Folder") then for _, s in c:GetChildren() do if s:IsA("Sound") and s.Playing then return c.Name end end elseif c:IsA("Sound") and c.Playing then return "Day" end end end
    return "Day"
end

local wCache = { c = "Day", t = 0 }
local function getWeatherMul()
    local n = os.clock(); if n - wCache.t > 5 then wCache.c = detectWeather(); wCache.t = n end; return WeatherMul[wCache.c] or {}
end

local function rollMutation(seed, isFruit)
    local mul = getWeatherMul()
    if isFruit then return select(1, MutationData.ReturnFruitMutation(seed, mul)) end
    return select(1, MutationData.ReturnPlantMutation(seed, {}))
end

-- ══════ Growth helpers ══════
local function growInfo(pn) local g = GrowRateData[pn]; if g then return g end; return { GrowRate = 0.2, GrowFruitTime = NumberRange.new(5, 15), FruitGrowRate = 0.2 } end
local function playerLuck() local m = Cont:FindFirstChild("PlayerStateClient"); if not m then return 1 end; local ok, r = pcall(function() return require(m):WaitForLocalReplica(0.5) end); if ok and r and r.Data then return r.Data.Luck or r.Data.PetLuck or 1 end; return 1 end
local function seedInfo(n) for _, e in ipairs(SeedData) do if e.SeedName == n then return e end end; return nil end

local function rollPlantState(pn)
    local luck = playerLuck(); local seed = math.random(1, 2147483647)
    local sm, dc = PlantSizeMultipliers.GetRandomPlantSize(luck, seed, pn)
    local g = growInfo(pn); local r = Random.new(seed); local ma = 10
    if g.GrowFruitTime then ma = r:NextInteger(g.GrowFruitTime.Min, g.GrowFruitTime.Max); if dc and dc > 0 then ma = ma + dc * r:NextInteger(2, 8) end end
    local si = seedInfo(pn)
    return { Seed = seed, SizeMultiplier = sm, MaxAge = math.max(1, ma), Weight = sm, PrimeTime = si and si.PrimeTime or 90, IsSingleHarvest = si and si.IsSingleHarvest == true, Mutation = rollMutation(seed, false) }
end

local function applySize(m, mult) if not m or not mult or mult <= 0 then return end; m:SetAttribute("SizeMultiplier", mult); pcall(function() m:ScaleTo(mult) end) end
local function markGrown(uid, pid, age) GardenSync:HandlePlantGrowthUpdated(uid, pid, { Age = age, FinishedGrowingAt = os.time() }) end

local function cleanSoil(m)
    pcall(function() PlantVis:RemoveGrowthSFX(m) end)
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") and (d.Name == "Base" or d.Name:lower():find("dirt") or d.Name:lower():find("soil")) then d.Transparency = 1; d.CanCollide = false end
    end
end

local function spawnFruits(uid, pid, pn, m, st)
    local ls = m:FindFirstChild("FruitSpawnLocations"); if not ls then return end
    for idx, ch in ipairs(ls:GetChildren()) do if ch:IsA("BasePart") then addFruit(uid, pid, pn, idx, st.Seed, st.SizeMultiplier) end end
end

local visP, visF, visFS = {}, {}, {}

function addFruit(uid, pid, pn, sIdx, pSeed, pSize, fid)
    fid = fid or Http:GenerateGUID(false)
    local luck = playerLuck(); local fSeed = math.random(1, 2147483647)
    local sm = PlantSizeMultipliers.GetRandomFruitSize(luck, fSeed)
    local g = growInfo(pn); local r = Random.new(fSeed); local ma = 10
    if g and g.GrowFruitTime then ma = r:NextInteger(g.GrowFruitTime.Min, g.GrowFruitTime.Max) end
    local fd = { Age = 0, MaxAge = ma, Seed = fSeed, SizeMultiplier = sm, GrowRate = g and (g.FruitGrowRate or g.GrowRate) or 0.2, SpawnLocationIndex = sIdx, OvertimeGrowth = 1, FinishedGrowingAt = 0, Mutation = rollMutation(fSeed, true), DecayAlpha = 0, Weight = sm }
    visF[fid] = { plantId = pid, spawnIndex = sIdx }
    GardenSync:HandleFruitAdded(uid, pid, fid, fd)
    return fid, fd
end

local function regrowFruit(uid, pid, pn, sIdx, pSeed, pSize, primeTime)
    task.delay(primeTime or 90, function() if not visP[pid] then return end; local m = PlantVis:WaitForPlantModel(uid, pid); if m then addFruit(uid, pid, pn, sIdx, pSeed, pSize) end end)
end

local function watchMaturation(uid, pid, pn, m, st)
    local cleaned = false
    local function check()
        local age = m:GetAttribute("Age") or 0
        if age > 0.15 and not cleaned then cleaned = true; cleanSoil(m) end
        local ma = m:GetAttribute("MaxAge") or st.MaxAge; if age < ma then return end
        markGrown(uid, pid, ma); cleanSoil(m)
        if st.Mutation then m:SetAttribute("Mutation", st.Mutation); MutCtrl:ApplyMutation(m) end
        if PlantVis:IsSingleHarvestPlant(pn) then PlantVis:AddHarvestPrompt(m) else spawnFruits(uid, pid, pn, m, st) end
    end
    m:GetAttributeChangedSignal("Age"):Connect(check); task.defer(check)
end

-- Harvested fruit tool
local function makeFruitTool(pn, fd)
    local fid = Http:GenerateGUID(false); local t = makeTool(pn)
    t:SetAttribute("HarvestedFruit", true); t:SetAttribute("FruitName", pn); t:SetAttribute("Fruit", pn)
    t:SetAttribute("FruitId", fid); t:SetAttribute("Id", fid)
    t:SetAttribute("Seed", fd.Seed or 1); t:SetAttribute("SizeMultiplier", fd.SizeMultiplier or 1)
    t:SetAttribute("Weight", fd.Weight or fd.SizeMultiplier or 1); t:SetAttribute("OvertimeGrowth", 1)
    t:SetAttribute("DecayAlpha", 0); t:SetAttribute("MainCategory", "Fruit"); t:SetAttribute("Count", 1)
    if fd.Mutation then t:SetAttribute("Mutation", fd.Mutation) end
    if ICONS[pn] then t.TextureId = ICONS[pn] end
    visFS[fid] = t; t.Parent = backpack(); return t
end

-- ══════ Bed parts for raycasting ══════
local function scanBedParts()
    local parts = {}
    for _, plot in WS.Gardens:GetChildren() do
        if not (plot:IsA("Model") or plot:IsA("Folder")) then continue end
        local vis = plot:FindFirstChild("Visual"); if not vis then continue end
        for _, mdl in vis:GetChildren() do
            if mdl:IsA("Model") and (mdl.Name == "BedSection" or mdl.Name == "FRONT_BedSection") then
                for _, p in mdl:GetChildren() do if p:IsA("BasePart") and p.Name == "Part" then table.insert(parts, p) end end
            end
        end
    end; return parts
end
local BedParts = scanBedParts()

-- ══════ Position tracking ══════
local plantedPos = {}
local function posKey(pos) return string.format("%.1f,%.1f", pos.X, pos.Z) end
local function isFree(pos)
    local k = posKey(pos)
    if plantedPos[k] then return false end
    local uid = player.UserId; local garden = GardenSync:GetGarden(uid)
    if garden then for _, pd in pairs(garden) do if pd.Positions and posKey(Vector3.new(pd.Positions.PosX, 0, pd.Positions.PosZ)) == k then return false end end end
    return true
end

-- ══════ Planting animation ══════
local function plantFX(pos, seedName)
    local mdl = SeedsAsset and SeedsAsset:FindFirstChild(seedName)
    if mdl then
        local cl = mdl:Clone(); local pr = cl:IsA("BasePart") and cl or cl.PrimaryPart
        if pr then
            pr.Anchored = true; pr.CanCollide = false; local oS = pr.Size; local oR = pr.Orientation
            local sC = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(oR.Y), 0)
            local bC = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(oR.Y + 15), 0)
            local lC = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, math.rad(oR.Y + 60), 0)
            local sqC = CFrame.new(pos + Vector3.new(0, 0.15 - oS.Y * 0.15, 0)) * CFrame.Angles(0, math.rad(oR.Y + 60), 0)
            local vC = CFrame.new(pos + Vector3.new(0, -0.1, 0)) * CFrame.Angles(0, math.rad(oR.Y + 60), 0)
            pr.CFrame = sC; PlantCtrl:SetPartsTransparency(cl, 1); cl.Parent = (WS:FindFirstChild("Temporary") or WS)
            PlantCtrl:TweenAllPartsTransparency(cl, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 0)
            local t1 = TS:Create(pr, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = bC })
            t1:Play(); t1.Completed:Once(function()
                local t2 = TS:Create(pr, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = lC })
                t2:Play(); t2.Completed:Once(function()
                    local t3 = TS:Create(pr, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = sqC, Size = Vector3.new(oS.X * 1.3, oS.Y * 0.6, oS.Z * 1.3) })
                    t3:Play(); t3.Completed:Once(function()
                        local vi = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                        TS:Create(pr, vi, { CFrame = vC, Size = oS * 0.8 }):Play(); PlantCtrl:TweenAllPartsTransparency(cl, vi, 1)
                        PlantCtrl:PlaySfx(); PlantCtrl:SpawnDirtChunks(pos); PlantCtrl:CreateDirtDecal(pos, seedName); PlantCtrl:CreateImpactRing(pos); Debris:AddItem(cl, 0.2)
                    end)
                end)
            end); return true
        else cl:Destroy() end
    end
    PlantCtrl:PlaySfx(); PlantCtrl:SpawnDirtChunks(pos); PlantCtrl:CreateDirtDecal(pos, seedName); PlantCtrl:CreateImpactRing(pos); return false
end

-- ══════ Raycast planting ══════
local function raycastPlant(plot)
    local ap = RaycastParams.new(); ap.FilterType = Enum.RaycastFilterType.Include; ap.FilterDescendantsInstances = BedParts
    local cam = workspace.CurrentCamera; local p = UIS:GetMouseLocation(); local ray = cam:ViewportPointToRay(p.X, p.Y)
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 5000, ap)
    if not hit then return nil end
    if not hit.Instance:IsDescendantOf(plot) then return nil end
    local plantHit = workspace:Raycast(ray.Origin, ray.Direction * 5000, PlantCtrl:CreatePlantsParams())
    if plantHit then local a, b = hit.Position, plantHit.Position; if (Vector2.new(b.X, b.Z) - Vector2.new(a.X, a.Z)).Magnitude < 1 then return nil end end
    if not isFree(hit.Position) then return nil end
    return hit
end

local function registerPlant(uid, pid, pd)
    visP[pid] = true; plantedPos[posKey(Vector3.new(pd.Positions.PosX, 0, pd.Positions.PosZ))] = true
    GardenSync:HandlePlantAdded(uid, pid, pd)
    task.defer(function()
        local f = PlantVis:GetPlantsFolder(uid); local m = f and f:FindFirstChild(uid .. "_" .. pid)
        if m then m:SetAttribute("_VP", true); applySize(m, pd.SizeMultiplier); watchMaturation(uid, pid, pd.PlantName, m, pd) end
    end)
end

local function doPlant(hit, seedName, tool)
    local uid = player.UserId
    local spawn = PlantVis:GetSpawnPoint(uid); if not spawn or not spawn.CFrame then return false, "No plot" end
    local st = rollPlantState(seedName)
    local lp = spawn.CFrame:PointToObjectSpace(hit.Position)
    local pid = Http:GenerateGUID(false)
    local yR = 0; if player.Character and player.Character.PrimaryPart then local _, y = player.Character.PrimaryPart.CFrame:ToEulerAnglesYXZ(); yR = math.deg(y) end
    local pd = {
        PlantName = seedName, Positions = { PosX = lp.X, PosY = lp.Y, PosZ = lp.Z, Rotation = yR },
        MaxAge = st.MaxAge, Age = 0, PlantedAt = os.time(), Seed = st.Seed, SizeMultiplier = st.SizeMultiplier,
        Weight = st.Weight, Variant = "Normal", PrimeTime = st.PrimeTime, PrimeStartedAt = os.time(),
        FinishedGrowingAt = 0, Fruits = {}, Mutation = st.Mutation,
    }
    plantFX(hit.Position, seedName)
    local ok, err = pcall(function() registerPlant(uid, pid, pd) end)
    if not ok then visP[pid] = nil; plantedPos[posKey(Vector3.new(lp.X, 0, lp.Z))] = nil; return false, tostring(err) end
    consumeOne(tool)
    return true, string.format("%s (size %.2f%s)", seedName, st.SizeMultiplier, st.Mutation and " [" .. st.Mutation .. "]" or "")
end

-- Hook PlantCtrl.TryPlantWithRay
if not getgenv()._UnAlivePlantHook then
    getgenv()._UnAlivePlantHook = true
    local old = PlantCtrl.TryPlantWithRay; local cd = 0
    PlantCtrl.TryPlantWithRay = function(self, ray)
        local tool = self:GetEquippedTool()
        if not (tool and tool:GetAttribute("_V") and tool:GetAttribute("SeedTool")) then return old(self, ray) end
        local n = os.clock(); if n - cd < 0.05 then return false end
        local sn = tool:GetAttribute("SeedTool"); local plot = self:GetPlayerPlot(); if not plot then return false end
        local hit = raycastPlant(plot); if not hit then return false end; cd = n
        local ok, msg = doPlant(hit, sn, tool); if ok then print("[UnAlive] Planted", msg) end; return ok
    end
end

-- Harvest hook
PPS.PromptTriggered:Connect(function(p, w)
    if w ~= player then return end; if not p:IsA("ProximityPrompt") then return end; if p.Name ~= "HarvestPrompt" then return end
    local m = p:FindFirstAncestorWhichIsA("Model"); if not m then return end
    local pid = m:GetAttribute("PlantId"); local fid = m:GetAttribute("FruitId")
    if not pid or not visP[pid] then return end
    local uid = player.UserId; local pd = GardenSync:GetPlant(uid, pid); if not pd then return end; local pn = pd.PlantName
    if fid == nil or fid == "" then
        if not PlantVis:IsSingleHarvestPlant(pn) then return end
        GardenSync:HandlePlantRemoved(uid, pid); pcall(function() PlantVis:RemovePlantById(uid, pid) end)
        if pd.Positions then plantedPos[posKey(Vector3.new(pd.Positions.PosX, 0, pd.Positions.PosZ))] = nil end
        makeFruitTool(pn, pd); visP[pid] = nil; return
    end
    local fd = pd.Fruits and pd.Fruits[fid]; if not fd then return end; local meta = visF[fid]
    GardenSync:HandleFruitRemoved(uid, pid, fid); pcall(function() FruitVis:RemoveFruitById(uid, pid, fid) end)
    makeFruitTool(pn, fd); visF[fid] = nil
    if meta then regrowFruit(uid, pid, pn, meta.spawnIndex, pd.Seed, pd.SizeMultiplier, pd.PrimeTime) end
end)

-- Handle binding
local HCList = { "HarvestedFruitHandleController", "SeedHandleController" }
local function tryBind(t)
    if not t or not t.Parent then return end; local c = player.Character; if not c then return end
    for _, name in ipairs(HCList) do local md = Cont:FindFirstChild(name); if md then local hc = require(md); if hc.IsTrackedTool and hc:IsTrackedTool(t) then pcall(function() hc:SetupTool(t, c) end); return end end end
end
for _, c in ipairs({ backpack(), player.Character }) do if c then for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("_V") then task.defer(function() tryBind(t) end) end end end end
backpack().ChildAdded:Connect(function(ch) if ch:IsA("Tool") and ch:GetAttribute("_V") then task.defer(function() tryBind(ch) end) end end)

-- Sell hook
local Net = require(RS.SharedModules.Networking)
local function fruitValue(t)
    local n = t:GetAttribute("Fruit"); if not n then return 0 end
    local b = SellValueData[n] or 100; local sm = t:GetAttribute("SizeMultiplier") or 1; local w = t:GetAttribute("Weight") or sm
    local v = math.max(1, math.floor(b * w * sm)); local mut = t:GetAttribute("Mutation")
    if mut and mut ~= "" then v = math.floor(v * MutationData.ReturnPriceMultiplier(mut)) end; return v
end
local function findVFruit(fid)
    local t = visFS[fid]; if t and t.Parent then return t end
    for _, c in ipairs({ backpack(), player.Character }) do if c then for _, ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch:GetAttribute("FruitId") == fid and ch:GetAttribute("_V") then return ch end end end end; return nil
end
local function sellFT(t)
    local val = fruitValue(t); local fid = t:GetAttribute("FruitId")
    local ls = player:FindFirstChild("leaderstats"); local sh = ls and ls:FindFirstChild("Sheckles")
    if sh then sh.Value = sh.Value + val end; if fid then visFS[fid] = nil end; t:Destroy()
    return { Success = true, Value = val, SellPrice = val }
end
local function collectFruits()
    local f, t = {}, 0
    for _, c in ipairs({ backpack(), player.Character }) do if c then for _, t2 in ipairs(c:GetChildren()) do if t2:IsA("Tool") and t2:GetAttribute("_V") and t2:GetAttribute("HarvestedFruit") then t = t + fruitValue(t2); table.insert(f, t2) end end end end; return f, t
end

if not getgenv()._UnAliveSeedSellHook then
    getgenv()._UnAliveSeedSellHook = true
    local os = Net.NPCS.SellFruit.Fire; Net.NPCS.SellFruit.Fire = function(self, fid) local t = findVFruit(fid); if t then return sellFT(t) end; return os(self, fid) end
    local osa = Net.NPCS.SellAll.Fire; Net.NPCS.SellAll.Fire = function(self) local f, t = collectFruits(); if #f > 0 then for _, t2 in ipairs(f) do sellFT(t2) end; return { Success = true, Value = t, SellPrice = t } end; return osa(self) end
    local osp = Net.NPCS.PreviewSellAll.Fire; Net.NPCS.PreviewSellAll.Fire = function(self) local f, t = collectFruits(); local r = osp(self); if type(r) == "table" then r.FruitCount = (r.FruitCount or 0) + #f; r.TotalValue = (r.TotalValue or 0) + t; return r end; if #f > 0 then return { FruitCount = #f, TotalValue = t } end; return r end
end

-- Expose API
getgenv()._UnAliveSeedAPI = {
    spawn = spawnSeed,
    list = allSeedNames,
    icons = ICONS,
    planted = function() return visP end,
    fruits = function() return visFS end,
}

print("[UnAlive] Seed Spawner loaded — use _UnAliveSeedAPI.spawn(\"Carrot\", 5)")
