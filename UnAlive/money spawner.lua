-- == UnAlive Money Spawner [STANDALONE] ==
-- Adds sheckles directly and enables client-side fruit selling.
-- Pasted spawned fruits work with Sell All for instant cash.

if getgenv()._UnAliveMoneySpawner then
    print("[UnAlive] Money Spawner already loaded"); return
end
getgenv()._UnAliveMoneySpawner = true

local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local Http = game:GetService("HttpService")
local player = Players.LocalPlayer; local Net = require(RS.SharedModules.Networking)

-- Value calculation
local SellValueData = require(RS.SharedModules.SellValueData)
local MutationData = require(RS.SharedModules.MutationData)

local function calculateFruitValue(tool)
    local fruitName = tool:GetAttribute("Fruit") or tool:GetAttribute("FruitName")
    if not fruitName then return 0 end
    local base = SellValueData[fruitName] or 100
    local sizeMult = tonumber(tool:GetAttribute("SizeMultiplier")) or 1
    local weight = tonumber(tool:GetAttribute("Weight")) or sizeMult
    local value = math.max(1, math.floor(base * weight * sizeMult))
    local mutation = tool:GetAttribute("Mutation")
    if mutation and mutation ~= "" then
        value = math.floor(value * MutationData.ReturnPriceMultiplier(mutation))
    end
    return value
end

-- Find spawned fruit tools
local function findAllFruits()
    local fruits = {}
    local function scan(c)
        if not c then return end
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("_V") and t:GetAttribute("HarvestedFruit") then
                table.insert(fruits, t)
            end
        end
    end
    scan(player:FindFirstChild("Backpack"))
    scan(player.Character)
    return fruits
end

-- Sell a single fruit tool
local function sellFruitTool(tool)
    local value = calculateFruitValue(tool)
    local ls = player:FindFirstChild("leaderstats")
    local sh = ls and ls:FindFirstChild("Sheckles")
    if sh then sh.Value = (sh.Value or 0) + value end
    local fid = tool:GetAttribute("FruitId") or tool:GetAttribute("Id")
    if fid then
        local visFS = getgenv()._UnAliveFruitVis or {}
        visFS[fid] = nil
        getgenv()._UnAliveFruitVis = visFS
    end
    tool:Destroy()
    return { Success = true, Value = value, SellPrice = value }
end

-- Sell all spawned fruits
local function sellAllFruits()
    local fruits = findAllFruits()
    if #fruits == 0 then return { Success = true, SoldCount = 0, Value = 0 } end
    local total = 0
    for _, t in ipairs(fruits) do
        local r = sellFruitTool(t)
        total = total + (r.Value or 0)
    end
    return { Success = true, SoldCount = #fruits, Value = total, SellPrice = total }
end

-- Add sheckles directly
local function addSheckles(amount)
    amount = math.clamp(tonumber(amount) or 1, 1, 999999999)
    local ls = player:FindFirstChild("leaderstats")
    local sh = ls and ls:FindFirstChild("Sheckles")
    if sh then
        sh.Value = (sh.Value or 0) + amount
        return true
    end
    return false
end

-- Hook SellFruit and SellAll so spawned fruits work with NPC
if not getgenv()._UnAliveSellHook then
    getgenv()._UnAliveSellHook = true

    local function findFruitById(fid)
        for _, c in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
            if c then
                for _, ch in ipairs(c:GetChildren()) do
                    if ch:IsA("Tool") and (ch:GetAttribute("FruitId") == fid or ch:GetAttribute("Id") == fid) and ch:GetAttribute("_V") then
                        return ch
                    end
                end
            end
        end
        return nil
    end

    -- SellFruit
    local oldSellFruit = Net.NPCS.SellFruit.Fire
    Net.NPCS.SellFruit.Fire = function(self, fid)
        local t = findFruitById(fid)
        if t then return sellFruitTool(t) end
        return oldSellFruit(self, fid)
    end

    -- SellAll
    local oldSellAll = Net.NPCS.SellAll.Fire
    Net.NPCS.SellAll.Fire = function(self)
        local f = findAllFruits()
        if #f > 0 then
            local total = 0
            for _, t2 in ipairs(f) do
                local r = sellFruitTool(t2)
                total = total + (r.Value or 0)
            end
            return { Success = true, Value = total, SellPrice = total, SoldCount = #f }
        end
        return oldSellAll(self)
    end

    -- PreviewSellAll
    local oldPreview = Net.NPCS.PreviewSellAll.Fire
    Net.NPCS.PreviewSellAll.Fire = function(self)
        local f = findAllFruits()
        local r = oldPreview(self)
        if type(r) == "table" then
            r.FruitCount = (r.FruitCount or 0) + #f
            local total = 0
            for _, t in ipairs(f) do total = total + calculateFruitValue(t) end
            r.TotalValue = (r.TotalValue or 0) + total
            return r
        end
        if #f > 0 then return { FruitCount = #f, TotalValue = (function() local t = 0; for _, v in ipairs(f) do t = t + calculateFruitValue(v) end; return t end)() } end
        return r
    end
end

-- Expose API
getgenv()._UnAliveMoneyAPI = {
    add = addSheckles,
    sellAll = sellAllFruits,
    count = function() return #findAllFruits() end,
    valueOf = calculateFruitValue,
}

print("[UnAlive] Money Spawner loaded — use _UnAliveMoneyAPI.add(50000) or .sellAll()")
