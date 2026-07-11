if getgenv()._SmartInv then pcall(getgenv()._SmartInv.stop) end

local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local CS = game:GetService("CollectionService"); local LP = Players.LocalPlayer
local Net
do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
local function fireFast(p, ...) local a = action(p); if not (a and a.Fire) then return nil end; local args = table.pack(...); local s, r = pcall(a.Fire, a, table.unpack(args, 1, args.n)); if s then return r else return nil end end
local FVC = require(RS.SharedModules.FruitValueCalc)
local running = true

local function deepScanInv()
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return {} end
    local fruits = {}
    local function scan(inst)
        for _, child in ipairs(inst:GetChildren()) do
            local fn = child:GetAttribute("FruitName")
            if fn then
                local sz = tonumber(child:GetAttribute("SizeMultiplier")) or 1
                local wt = tonumber(child:GetAttribute("Weight")) or sz
                local mut = child:GetAttribute("Mutation")
                local dec = child:GetAttribute("DecayAlpha")
                local val = FVC(fn, sz, mut, LP, dec)
                table.insert(fruits, { id = child:GetAttribute("Id"), name = fn, size = sz, weight = wt, mutation = mut, decay = dec, val = val, class = child.ClassName, obj = child })
            end
            if child:GetChildren() and #child:GetChildren() > 0 then scan(child) end
        end
    end
    scan(bp)
    table.sort(fruits, function(a, b) return a.val < b.val end)
    return fruits
end

local function deepScanGarden()
    local fruits = {}
    local seen = {}
    for _, pr in ipairs(CS:GetTagged("HarvestPrompt")) do
        if pr:IsA("ProximityPrompt") and pr.Enabled and pr:IsDescendantOf(WS) then
            local m = pr:FindFirstAncestorWhichIsA("Model")
            if not m then local n = pr.Parent; while n and n ~= WS and n:GetAttribute("PlantId") == nil do n = n.Parent end; m = n end
            if m then
                local pid = m:GetAttribute("PlantId"); local fid = m:GetAttribute("FruitId")
                local key = tostring(pid) .. "_" .. tostring(fid)
                if not seen[key] then
                    seen[key] = true
                    local name = m:GetAttribute("FruitName") or m:GetAttribute("CorePartName") or ""
                    local sz = tonumber(m:GetAttribute("SizeMultiplier") or m:GetAttribute("SizeMulti")) or 1
                    local mut = m:GetAttribute("Mutation")
                    for _, child in ipairs(m:GetChildren()) do
                        local cfn = child:GetAttribute("FruitName") or child:GetAttribute("CorePartName")
                        if cfn and name == "" then name = cfn end
                        local csz = tonumber(child:GetAttribute("SizeMultiplier") or child:GetAttribute("SizeMulti"))
                        if csz then sz = csz end
                        local cmut = child:GetAttribute("Mutation")
                        if cmut then mut = cmut end
                    end
                    local userId = tonumber(m:GetAttribute("UserId"))
                    if name ~= "" and (userId == nil or userId == LP.UserId) then
                        local val = FVC(name, sz, mut, LP, nil)
                        if val > 0 then table.insert(fruits, { val = val, plantId = tostring(pid), fruitId = tostring(fid), name = name, size = sz, mutation = mut }) end
                    end
                end
            end
        end
    end
    table.sort(fruits, function(a, b) return a.val > b.val end)
    return fruits
end

task.spawn(function()
    while true do
        if not running then task.wait(1); continue end
        pcall(function()
            local count = tonumber(LP:GetAttribute("FruitCount")) or 0
            local cap = tonumber(LP:GetAttribute("MaxFruitCapacity")) or 100
            local free = cap - count

            if free > 0 then
                local g = deepScanGarden()
                if #g == 0 then return end
                local n = math.min(free, #g)
                for i = 1, n do task.wait(0.03); fireFast("Garden.CollectFruit", g[i].plantId, g[i].fruitId) end
                return
            end

            local inv = deepScanInv()
            local g = deepScanGarden()
            if #inv == 0 or #g == 0 then return end

            local n = 0
            for i = 1, math.min(#g, #inv) do
                if g[i].val > inv[i].val then n = n + 1 else break end
            end
            if n == 0 then return end

            for i = 1, n do
                local cur = deepScanInv()
                if #cur == 0 then break end
                local r = fireFast("NPCS.SellFruit", cur[1].id)
                if r and type(r) == "table" and r.Success then
                    task.wait(0.1)
                    local fresh = deepScanGarden()
                    if #fresh > 0 then fireFast("Garden.CollectFruit", fresh[1].plantId, fresh[1].fruitId) end
                    task.wait(0.05)
                end
            end
        end)
        task.wait(1)
    end
end)

getgenv()._SmartInv = { stop = function() running = false end, start = function() running = true end }
