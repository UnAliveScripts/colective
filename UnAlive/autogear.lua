-- == UnAlive Auto-Gear [STANDALONE] ==
-- Shop tab: buys gear from GearShop on a timer.
-- Paste into your script. No dependencies.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local RS = game:GetService("ReplicatedStorage")
    local Net
    do
        local sm = RS:WaitForChild("SharedModules", 15)
        local m = sm and sm:FindFirstChild("Networking")
        if m then local ok, n = pcall(require, m); if ok then Net = n end end
    end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }
    local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    local function jitter(a, b) a = a or 0.05; b = b or 0.12; return a + math.random() * (b - a) end
    local function stockOf(name)
        local ok, items = pcall(function() return RS.StockValues.GearShop.Items end)
        if not ok or not items then return nil end
        local v = items:FindFirstChild(name)
        return v and tonumber(v.Value) or 0
    end
    Sk = { fire = fire, jitter = jitter, stockOf = stockOf }
    getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local jitter = Sk.jitter; local stockOf = Sk.stockOf

-- CONFIG
local autoGear = false
local gearBuy = {}
local gearInterval = 10

task.spawn(function()
    while true do
        if autoGear and next(gearBuy) then
            pcall(function()
                for name in pairs(gearBuy) do
                    if not autoGear then break end
                    local st = stockOf(name)
                    if st == nil or st > 0 then
                        fire("GearShop.PurchaseGear", name)
                        task.wait(jitter(0.2, 0.4))
                    end
                end
            end)
        end
        local w = gearInterval
        local e = 0
        while e < w and autoGear do task.wait(0.4); e = e + 0.4 end
        if not autoGear then task.wait(2) end
    end
end)
