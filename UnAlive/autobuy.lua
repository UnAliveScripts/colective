-- == UnAlive Auto-Buy Seeds [STANDALONE] ==
-- Shop tab: buys selected seeds from SeedShop on a timer.
-- Paste into your script. No dependencies.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local RS = game:GetService("ReplicatedStorage")
    local function initNet()
        local sm = RS:WaitForChild("SharedModules", 15)
        local m = sm and sm:FindFirstChild("Networking")
        if m then local ok, n = pcall(require, m); if ok then return n end end
        error("Networking module not found")
    end
    local Net = initNet()
    local _rl = { w = 0, c = 0, cap = 60 }
    local function pace()
        local n = os.clock()
        if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end
        if _rl.c >= _rl.cap then task.wait(0.05); return pace() end
        _rl.c = _rl.c + 1
    end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    local function jitter(a, b) a = a or 0.05; b = b or 0.12; return a + math.random() * (b - a) end
    local _rep
    local function rep() if _rep then return _rep end; local ok, psc = pcall(require, RS.ClientModules.PlayerStateClient); if ok and psc and psc.WaitForLocalReplica then local ok2, r = pcall(psc.WaitForLocalReplica, psc, 30); if ok2 and r then _rep = r end end; return _rep end
    local function pd() local r = rep(); return (r and r.Data) or {} end
    local function getSh() return tonumber(pd().Sheckles) or 0 end
    local _due = {}
    local function due(k, p) local n = os.clock(); if not _due[k] or n - _due[k] >= p then _due[k] = n; return true end; return false end
    Sk = { fire = fire, jitter = jitter, due = due, getSh = getSh, RS = RS, Net = Net }
    getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local jitter = Sk.jitter; local due = Sk.due; local getSh = Sk.getSh; local RS = Sk.RS

-- Seed catalog
local CATALOG
do
    local out = {}
    local ok, data = pcall(require, RS.SharedModules.SeedData)
    if ok and type(data) == "table" then
        for _, e in pairs(data) do
            if type(e) == "table" and e.SeedName and e.RestockShop ~= false and e.PurchasePrice then
                out[#out + 1] = { name = e.SeedName, price = tonumber(e.PurchasePrice) or 0 }
            end
        end
    end
    table.sort(out, function(a, b) return a.price < b.price end)
    if #out == 0 then
        for _, n in ipairs({"Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple", "Bamboo", "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean", "Banana", "Grape", "Coconut", "Mango", "Dragon Fruit", "Acorn", "Cherry", "Sunflower", "Venus Fly Trap", "Pomegranate", "Poison Apple", "Moon Bloom", "Dragon's Breath", "Ghost Pepper", "Poison Ivy"}) do
            out[#out + 1] = { name = n, price = 0 }
        end
    end
    CATALOG = out
end

local function stockOf(name)
    local ok, items = pcall(function() return RS.StockValues.SeedShop.Items end)
    if not ok or not items then return nil end
    local v = items:FindFirstChild(name)
    return v and tonumber(v.Value) or 0
end

-- CONFIG
local autoBuy = false
local buySeeds = {}
local buyInterval = 5
local buyPerTick = 8

local function stepBuy()
    if not due("ubuy", buyInterval) or not next(buySeeds) then return end
    for _, s in ipairs(CATALOG) do
        if not autoBuy then break end
        if buySeeds[s.name] then
            local st, b = stockOf(s.name), 0
            while b < buyPerTick do
                if st ~= nil and st <= 0 then break end
                if s.price > 0 and getSh() < s.price then break end
                if not fire("SeedShop.PurchaseSeed", s.name) then break end
                b = b + 1
                if st ~= nil then st = st - 1 end
                task.wait(jitter(0.1, 0.22))
            end
        end
    end
end

task.spawn(function()
    while true do
        if autoBuy then pcall(stepBuy) end
        task.wait(0.55)
    end
end)

-- Set autoBuy = true to enable
-- Add seeds: buySeeds.Carrot = true
