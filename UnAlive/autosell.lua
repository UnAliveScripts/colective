-- == UnAlive Auto-Sell [STANDALONE] ==
-- Farm tab: sells all fruit on a timer without harvesting.
-- Paste into your script.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local RS = game:GetService("ReplicatedStorage")
    local Net; do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fireFast(p, ...) local a = action(p); if not (a and a.Fire) then return false end; local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    local function sellAllNow() local ok, res = fireFast("NPCS.SellAll"); if ok and type(res) == "table" and res.Success then return { sold = tonumber(res.SoldCount) or 0, earned = tonumber(res.SellPrice) or 0 } end; return { sold = 0, earned = 0 } end
    local _due = {}; local function due(k, p) local n = os.clock(); if not _due[k] or n - _due[k] >= p then _due[k] = n; return true end; return false end
    Sk = { sellAllNow = sellAllNow, due = due }
    getgenv()._UnAliveCore = Sk
end
local sellAllNow = Sk.sellAllNow; local due = Sk.due

local autoSell = false; local sellInterval = 15

local function stepSell() if not due("usell", sellInterval) then return end; local r = sellAllNow(); if r.sold > 0 then print("[UnAlive] Sold", r.sold, "for", r.earned) end end
task.spawn(function() while true do if autoSell then pcall(stepSell) end; task.wait(0.5) end end)
