-- == UnAlive Auto-Harvest [STANDALONE] ==
-- Farm tab: harvests ripe fruit + auto-sells when pack fills.
-- Paste into your script.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local CS = game:GetService("CollectionService"); local LP = Players.LocalPlayer
    pcall(function() if setthreadidentity then setthreadidentity(8) end; if syn and syn.set_thread_identity then syn.set_thread_identity(8) end end)
    local Net
    do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fireFast(p, ...) local a = action(p); if not (a and a.Fire) then return false end; local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    local function promptCarrier(pr) local n = pr.Parent; while n and n ~= WS and n:GetAttribute("PlantId") == nil do n = n.Parent end; if n and n:GetAttribute("PlantId") ~= nil then return n end; return pr:FindFirstAncestorWhichIsA("Model") end
    local function ripeHarvests() local out = {}; for _, pr in ipairs(CS:GetTagged("HarvestPrompt")) do if pr:IsA("ProximityPrompt") and pr.Enabled and pr:IsDescendantOf(WS) then local m = promptCarrier(pr); local pid = m and m:GetAttribute("PlantId"); if pid then local uid = tonumber(m:GetAttribute("UserId")); if uid == nil or uid == LP.UserId then out[#out + 1] = { plantId = tostring(pid), fruitId = tostring(m:GetAttribute("FruitId") or "") } end end end end; return out end
    local function fruitCount() return tonumber(LP:GetAttribute("FruitCount")) or 0 end
    local function maxFruitCap() return tonumber(LP:GetAttribute("MaxFruitCapacity")) or 100 end
    local function sellAllNow() local ok, res = fireFast("NPCS.SellAll"); if ok and type(res) == "table" and res.Success then return { sold = tonumber(res.SoldCount) or 0, earned = tonumber(res.SellPrice) or 0 } end; return { sold = 0, earned = 0 } end
    Sk = { fireFast = fireFast, ripeHarvests = ripeHarvests, fruitCount = fruitCount, maxFruitCap = maxFruitCap, sellAllNow = sellAllNow, LP = LP }
    getgenv()._UnAliveCore = Sk
end
local fireFast = Sk.fireFast; local ripeHarvests = Sk.ripeHarvests; local fruitCount = Sk.fruitCount; local maxFruitCap = Sk.maxFruitCap; local sellAllNow = Sk.sellAllNow

local autoHarvest = false; local harvestDelay = 0.01; local autoSell = true
local stats = { harvested = 0, sold = 0, earned = 0 }

local function stepHarvest()
    local list = ripeHarvests()
    if #list == 0 then if autoSell and fruitCount() > 0 then local r = sellAllNow(); stats.sold = stats.sold + r.sold; stats.earned = stats.earned + r.earned end; return end
    local cap = maxFruitCap(); local d = harvestDelay
    for _, h in ipairs(list) do
        if not autoHarvest then break end
        if fruitCount() >= cap - 1 then break end
        fireFast("Garden.CollectFruit", h.plantId, h.fruitId); stats.harvested = stats.harvested + 1
        if d > 0 then task.wait(d) end
    end
    if autoSell then local r = sellAllNow(); stats.sold = stats.sold + r.sold; stats.earned = stats.earned + r.earned end
end

task.spawn(function() while true do if autoHarvest then pcall(stepHarvest) end; task.wait(0.05) end end)
