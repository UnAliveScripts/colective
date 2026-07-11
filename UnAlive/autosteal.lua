-- == UnAlive Auto-Steal [STANDALONE] ==
-- Steal tab: steals highest-value fruit from other players at night.
-- Uses PlantLifecycleHandler for decay-based value, StealFlags for stealability.
-- Paste into your script. No dependencies.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local CS = game:GetService("CollectionService"); local RSvc = game:GetService("RunService"); local LP = Players.LocalPlayer
    pcall(function() if setthreadidentity then setthreadidentity(8) end; if syn and syn.set_thread_identity then syn.set_thread_identity(8) end end)
    local Net
    do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }
    local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    Sk = { fire = fire, LP = LP, WS = WS, CS = CS, RS = RS, RSvc = RSvc, Net = Net, pace = pace }
    getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local LP = Sk.LP; local WS = Sk.WS; local CS = Sk.CS; local RS = Sk.RS; local RSvc = Sk.RSvc; local Net = Sk.Net

-- Moon predictor (for optimal steal timing)
local function getMoonType(cycleID, order)
    local rng = Random.new(cycleID * 1000 + order)
    local roll = rng:NextNumber() * 100
    local sum2 = 0
    local chances = { { Name = "Rainbow Moon", Chance = 6 }, { Name = "Goldmoon", Chance = 13 }, { Name = "Bloodmoon", Chance = 2 }, { Name = "Moon", Chance = 79 } }
    for _, m in ipairs(chances) do sum2 = sum2 + m.Chance; if roll <= sum2 then return m.Name end end
    return "Moon"
end
local function isNight() local n = RS:FindFirstChild("Night"); return n and n.Value == true end

-- Load PlantCycleModule + StealFlags + FruitValueCalc for optimal steal targeting
-- These modules let us find the absolute best-value fruit to steal (decay-aware)
local PlantCycleMod, StealFlagsMod, FruitValueMod

do
    local sm = RS:WaitForChild("SharedModules", 10)
    local flags = sm and sm:FindFirstChild("Flags")
    local stealFlags = flags and flags:FindFirstChild("StealFlags")
    local fruitCalc = sm and sm:FindFirstChild("FruitValueCalc")

    if stealFlags then local ok, m = pcall(require, stealFlags); if ok then StealFlagsMod = m end end
    if fruitCalc then local ok, m = pcall(require, fruitCalc); if ok then FruitValueMod = m end end

    -- PlantLifecycleHandler from player scripts
    local pS = LP:FindFirstChild("PlayerScripts")
    local ctrl = pS and pS:FindFirstChild("Controllers")
    local plHandler = ctrl and ctrl:FindFirstChild("PlantLifecycleHandler")
    if plHandler then local ok, m = pcall(require, plHandler); if ok then PlantCycleMod = m end end
end

-- Get my plot
local function getMyPlot()
    local g = WS:FindFirstChild("Gardens")
    if not g then return nil end
    for _, p in ipairs(g:GetChildren()) do
        if tostring(p:GetAttribute("OwnerUserId")) == tostring(LP.UserId) then return p end
    end
end

-- Check if a player is stealable (not in own garden = stealable)
local function canSteal(player)
    if not player then return false end
    local ok, result = pcall(function() return player:GetAttribute("IsInOwnGarden") end)
    if not ok then return false end
    return not result
end

-- Smooth teleport with lerp
local function teleportTo(hrp, startCF, targetCF, speed)
    if not targetCF or typeof(targetCF) ~= "CFrame" then return end
    if not startCF or typeof(startCF) ~= "CFrame" then return end
    if not hrp then return end
    speed = speed or 33.8
    local dist = (targetCF.Position - startCF.Position).Magnitude
    local duration = dist / speed
    local elapsed = 0
    local con
    con = RSvc.RenderStepped:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed >= duration then
            if hrp and hrp.Parent then hrp.CFrame = targetCF end
            if con then con:Disconnect() end
            return
        end
        local alpha = elapsed / duration
        if hrp and hrp.Parent then hrp.CFrame = startCF:Lerp(targetCF, alpha)
        else if con then con:Disconnect() end end
    end)
    local start = os.clock()
    while con and con.Connected and os.clock() - start < duration + 2 do task.wait() end
    if con and con.Connected then con:Disconnect() end
end

-- Get decay alpha for a plant (0 = fresh, 1 = fully decayed, affects fruit value)
local function getDecay(model)
    if not PlantCycleMod then return 0 end
    local ok, entries = pcall(function() return PlantCycleMod:GetActiveEntries() end)
    if not ok or type(entries) ~= "table" then return 0 end
    for plantId, pt in pairs(entries) do
        if pt and pt.Model and pt.Model == model then
            local a, b = string.match(plantId, "^(%d+)_(.+)$")
            if a and b then
                local ok2, decay = pcall(function() return PlantCycleMod:GetDecayAlpha(tonumber(a), b) end)
                if ok2 then return decay or 0 end
            end
        end
    end
    return 0
end

-- Find the best plant to steal by fruit value
local function findBestPlant()
    local best, bestVal = nil, -1
    local gardens = WS:FindFirstChild("Gardens")
    if not gardens then return nil end

    for _, plot in ipairs(gardens:GetChildren()) do
        if plot:IsA("Model") then
            local plants = plot:FindFirstChild("Plants")
            if plants then
                for _, model in ipairs(plants:GetChildren()) do
                    if model:IsA("Model") then
                        local fruits = model:FindFirstChild("Fruits")
                        if fruits then
                            for _, fruit in ipairs(fruits:GetChildren()) do
                                if fruit:IsA("Model") then
                                    local seedName = model:GetAttribute("SeedName") or model:GetAttribute("CorePartName")
                                    local plantId = model:GetAttribute("PlantId")
                                    if seedName and plantId then
                                        -- Check if stealable
                                        if StealFlagsMod and StealFlagsMod.IsPlantStealable then
                                            local valid = StealFlagsMod.IsPlantStealable(seedName)
                                            if not valid then continue end
                                        end
                                        -- Check owner
                                        local targetUserId = model:GetAttribute("UserId")
                                        if targetUserId then
                                            local targetPlayer = Players:GetPlayerByUserId(tonumber(targetUserId))
                                            if targetPlayer and not canSteal(targetPlayer) then
                                                -- Calculate value
                                                local mutation = fruit:GetAttribute("Mutation") or ""
                                                local sizeMulti = fruit:GetAttribute("SizeMulti") or 1
                                                local decayAlpha = getDecay(model)
                                                if FruitValueMod then
                                                    local ok3, value = pcall(function()
                                                        return FruitValueMod(seedName, sizeMulti, mutation, LP, decayAlpha)
                                                    end)
                                                    if ok3 and value and value > bestVal then
                                                        bestVal = value
                                                        best = model
                                                    end
                                                elseif bestVal < 0 then
                                                    best = model
                                                    bestVal = 0
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- Fallback: find stealable fruits via CollectionService (if modules unavailable)
local function findStealableFallback()
    local out = {}
    for _, pr in ipairs(CS:GetTagged("StealPrompt")) do
        if pr:IsA("ProximityPrompt") and pr.Enabled and pr:IsDescendantOf(WS) then
            local node = pr.Parent
            while node and node ~= WS and node:GetAttribute("PlantId") == nil do node = node.Parent end
            local pid = node and node:GetAttribute("PlantId")
            if pid then
                local pos
                if pr.Parent and pr.Parent:IsA("BasePart") then pos = pr.Parent.Position
                elseif node then local ok, pv = pcall(function() return node:GetPivot().Position end); if ok then pos = pv end end
                out[#out + 1] = { owner = tonumber(node:GetAttribute("UserId")) or 0, plantId = tostring(pid), fruitId = tostring(node:GetAttribute("FruitId") or ""), pos = pos, model = node }
            end
        end
    end
    return out
end

-- Get my base position for returning
local function myBasePos()
    local plot = getMyPlot()
    if not plot then return nil end
    for _, tag in ipairs({ "GardenTotalArea", "GardenZone" }) do
        for _, p in ipairs(CS:GetTagged(tag)) do
            if p:IsA("BasePart") and p:IsDescendantOf(plot) then
                return Vector3.new(p.Position.X, p.Position.Y - p.Size.Y / 2 + 5, p.Position.Z)
            end
        end
    end
    local sp = plot:FindFirstChild("SpawnPoint")
    if sp and sp:IsA("BasePart") then return sp.Position end
    local ok, piv = pcall(function() return plot:GetPivot().Position end)
    return ok and piv or nil
end

local function hrpNow() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

-- CONFIG
local autoSteal = false
local stealTeleport = true
local stealReturnBase = true
local stealDelay = 0.05
local useSmoothTeleport = true
local stolen = 0

-- Main steal loop
task.spawn(function()
    while true do
        if autoSteal and isNight() then
            pcall(function()
                local target, ownerId, plantId, fruitId, targetPos

                -- Try advanced module-based targeting first
                if PlantCycleMod and StealFlagsMod and FruitValueMod then
                    local best = findBestPlant()
                    if best then
                        ownerId = tonumber(best:GetAttribute("UserId")) or 0
                        plantId = best:GetAttribute("PlantId") or ""
                        fruitId = best:GetAttribute("FruitId") or ""
                        local bp = best:FindFirstChildWhichIsA("BasePart")
                        if bp then targetPos = bp.Position end
                        target = best
                    end
                end

                -- Fallback to CollectionService tags
                if not target then
                    local list = findStealableFallback()
                    for _, f in ipairs(list) do
                        if f.owner ~= LP.UserId then
                            ownerId, plantId, fruitId, targetPos = f.owner, f.plantId, f.fruitId, f.pos
                            target = f.model
                            break
                        end
                    end
                end

                if target and ownerId and plantId and plantId ~= "" then
                    if stealTeleport and targetPos then
                        local hrp = hrpNow()
                        if hrp then
                            if useSmoothTeleport then
                                teleportTo(hrp, hrp.CFrame, CFrame.new(targetPos + Vector3.new(0, 3, 0)), 33.8)
                            else
                                hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 4, 0))
                                task.wait(0.4)
                            end
                        end
                    end

                    fire("Steal.BeginSteal", ownerId, plantId, fruitId)
                    fire("Steal.CompleteSteal")
                    stolen = stolen + 1

                    if stealReturnBase then
                        local base = myBasePos()
                        local hrp = hrpNow()
                        if base and hrp then
                            if useSmoothTeleport then
                                teleportTo(hrp, hrp.CFrame, CFrame.new(base + Vector3.new(0, 4, 0)), 33.8)
                            else
                                hrp.CFrame = CFrame.new(base + Vector3.new(0, 4, 0))
                            end
                            local t0 = os.clock()
                            while LP:GetAttribute("CarryingStolenFruit") and os.clock() - t0 < 3 and autoSteal do task.wait(0.15) end
                        end
                    end
                    if stealDelay > 0 then task.wait(stealDelay) end
                end
            end)
        end
        task.wait(1.5)
    end
end)
