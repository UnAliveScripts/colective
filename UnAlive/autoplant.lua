-- == UnAlive Auto-Plant [STANDALONE] ==
-- Farm tab: plants seeds on your plot's PlantArea grid.
-- Paste into your script.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local CS = game:GetService("CollectionService"); local LP = Players.LocalPlayer
    pcall(function() if setthreadidentity then setthreadidentity(8) end; if syn and syn.set_thread_identity then syn.set_thread_identity(8) end end)
    local Net
    do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }; local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    local function jitter(a, b) a = a or 0.05; b = b or 0.12; return a + math.random() * (b - a) end
    Sk = { fire = fire, jitter = jitter, LP = LP, WS = WS, CS = CS, RS = RS }
    getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local jitter = Sk.jitter; local LP = Sk.LP; local WS = Sk.WS; local CS = Sk.CS; local RS = Sk.RS

local function myPlot() local id = LP:GetAttribute("PlotId"); local g = WS:FindFirstChild("Gardens"); if not (id and g) then return nil end; return g:FindFirstChild("Plot" .. tostring(id)) end
local function humanoid() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function toolsByAttr(attr, want) local out = {}; local function scan(c) if not c then return end; for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute(attr) ~= nil then if (not want) or t:GetAttribute(attr) == want or t.Name == want then out[#out + 1] = t end end end end; scan(LP:FindFirstChild("Backpack")); scan(LP.Character); return out end
local function heldToolByAttr(attr) local c = LP.Character; local t = c and c:FindFirstChildWhichIsA("Tool"); if t and t:GetAttribute(attr) ~= nil then return t end; return nil end
local function myPlantAreas() local out = {}; local plot = myPlot(); if not plot then return out end; for _, p in ipairs(CS:GetTagged("PlantArea")) do if p:IsA("BasePart") and p:IsDescendantOf(plot) then out[#out + 1] = p end end; return out end
local function plantGrid(spacing) local pts = {}; local areas = myPlantAreas(); spacing = math.max(2, spacing or 4); local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.FilterDescendantsInstances = areas; for _, area in ipairs(areas) do local cf, size = area.CFrame, area.Size; local topY = (cf * CFrame.new(0, size.Y / 2, 0)).Position.Y; for dx = -size.X / 2 + spacing / 2, size.X / 2 - spacing / 2, spacing do for dz = -size.Z / 2 + spacing / 2, size.Z / 2 - spacing / 2, spacing do local w = (cf * CFrame.new(dx, 0, dz)).Position; local hit = WS:Raycast(Vector3.new(w.X, topY + 10, w.Z), Vector3.new(0, -40, 0), params); if hit then pts[#pts + 1] = hit.Position end end end end; return pts end
local function existingPlantPositions() local out = {}; local plot = myPlot(); local plants = plot and plot:FindFirstChild("Plants"); if not plants then return out end; for _, m in ipairs(plants:GetChildren()) do local ok, piv = pcall(function() return m:GetPivot().Position end); if ok then out[#out + 1] = piv end end; return out end

-- Catalog for best-owned detection
local CATALOG
do
    local out = {}; local ok, data = pcall(require, RS.SharedModules.SeedData)
    if ok and type(data) == "table" then for _, e in pairs(data) do if type(e) == "table" and e.SeedName and e.PurchasePrice then out[#out + 1] = { name = e.SeedName, price = tonumber(e.PurchasePrice) or 0 } end end end
    table.sort(out, function(a, b) return a.price < b.price end)
    if #out == 0 then for _, n in ipairs({"Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple", "Bamboo", "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean", "Banana", "Grape", "Coconut", "Mango", "Dragon Fruit", "Acorn", "Cherry", "Sunflower", "Venus Fly Trap", "Pomegranate", "Poison Apple", "Moon Bloom", "Dragon's Breath", "Ghost Pepper", "Poison Ivy"}) do out[#out + 1] = { name = n, price = 0 } end end
    CATALOG = out
end

local autoPlant = false; local plantSpacing = 4; local plantSeed = "Best owned"

local function pickPlantTool()
    if plantSeed ~= "Best owned" and plantSeed ~= "" then local t = toolsByAttr("SeedTool", plantSeed)[1]; if t then return t end end
    local best, bp
    for _, t in ipairs(toolsByAttr("SeedTool")) do
        local nm = t:GetAttribute("SeedTool"); local pr = 0
        for _, s in ipairs(CATALOG) do if s.name == nm then pr = s.price; break end end
        if not bp or pr > bp then best, bp = t, pr end
    end
    return best or toolsByAttr("SeedTool")[1]
end

local function stepPlant()
    local grid = plantGrid(plantSpacing); if #grid == 0 then return end
    local tool = pickPlantTool(); if not tool then return end
    local hum = humanoid(); if not hum then return end
    if heldToolByAttr("SeedTool") ~= tool then hum:EquipTool(tool); task.wait(0.22) end
    tool = heldToolByAttr("SeedTool"); if not tool then return end
    local seedAttr = tool:GetAttribute("SeedTool"); local occupied = existingPlantPositions()
    for _, pos in ipairs(grid) do
        if not autoPlant then break end
        local clear = true
        for _, op in ipairs(occupied) do if (Vector2.new(pos.X, pos.Z) - Vector2.new(op.X, op.Z)).Magnitude < 1 then clear = false; break end end
        if clear then
            if not heldToolByAttr("SeedTool") then
                local nx = pickPlantTool(); if not nx then return end; hum:EquipTool(nx); task.wait(0.2)
                tool = heldToolByAttr("SeedTool"); if not tool then return end; seedAttr = tool:GetAttribute("SeedTool")
            end
            fire("Plant.PlantSeed", pos, seedAttr, tool); occupied[#occupied + 1] = pos; task.wait(jitter(0.08, 0.16))
        end
    end
end

task.spawn(function() while true do if autoPlant then pcall(stepPlant) end; task.wait(0.6) end end)
