-- == UnAlive Auto-Buy Wild Pets [STANDALONE] ==
-- Shop tab: finds & buys wild pets with verification and per-server limits.
-- Paste into your script. No dependencies.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local LP = Players.LocalPlayer
    pcall(function() if setthreadidentity then setthreadidentity(8) end; if syn and syn.set_thread_identity then syn.set_thread_identity(8) end end)
    local Net
    do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }
    local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    local function jitter(a, b) a = a or .05; b = b or .12; return a + math.random() * (b - a) end
    local _rep
    local function rep() if _rep then return _rep end; local ok, psc = pcall(require, RS.ClientModules.PlayerStateClient); if ok and psc and psc.WaitForLocalReplica then local ok2, r = pcall(psc.WaitForLocalReplica, psc, 30); if ok2 and r then _rep = r end end; return _rep end
    local function pd() local r = rep(); return (r and r.Data) or {} end
    local function getSh() return tonumber(pd().Sheckles) or 0 end
    Sk = { fire = fire, jitter = jitter, getSh = getSh, LP = LP, WS = WS, RS = RS, Net = Net }
    getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local jitter = Sk.jitter; local getSh = Sk.getSh; local LP = Sk.LP; local WS = Sk.WS; local RS = Sk.RS

-- Inventory check helpers
local function normalizeName(name) return string.lower(tostring(name or "")):gsub("[^%w%s]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") end

local function hasPetInInventory(petName)
    local target = normalizeName(petName)
    if target == "" then return false end
    local bp = LP:FindFirstChild("Backpack")
    local char = LP.Character
    local function check(c)
        if not c then return false end
        for _, obj in ipairs(c:GetDescendants()) do
            local n = normalizeName(obj.Name)
            if n == target or n:find(target) then return true end
        end
        return false
    end
    return check(bp) or check(char)
end

-- Find wild pets
local function findWildPets()
    local out = {}
    local map = WS:FindFirstChild("Map")
    local ref = map and map:FindFirstChild("WildPetRef")
    if ref then
        for _, p in ipairs(ref:GetChildren()) do
            if p:IsA("BasePart") then
                out[#out + 1] = {
                    part = p, name = p:GetAttribute("PetName"),
                    price = tonumber(p:GetAttribute("Price")) or 0,
                    owner = tonumber(p:GetAttribute("OwnerUserId")) or 0,
                    pos = p.Position,
                }
            end
        end
    end
    return out
end

local function atPosition(pos, fn)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local saved = hrp.CFrame
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
    task.wait(0.45)
    local ok = pcall(fn)
    task.wait(0.15)
    if hrp and hrp.Parent then hrp.CFrame = saved end
    return ok
end

-- CONFIG
local autoBuyWildPets = false
local wildPetList = { "Bunny", "Frog", "Owl", "Raccoon", "Monkey", "Robin", "Deer", "Bee", "Unicorn", "Golden Dragonfly" }
local selectedWildPets = { Bunny = true, Frog = true }
local perPetLimit = {}
local boughtThisServer = {}
local maxPetPrice = 25000
local petTeleport = true
local petBuyInterval = 5
local verifyBeforeHop = true
for _, name in ipairs(wildPetList) do perPetLimit[name] = 1; boughtThisServer[name] = 0 end

local function isPetNeeded(name)
    local limit = perPetLimit[name] or 1
    local bought = boughtThisServer[name] or 0
    return bought < limit
end

local function allLimitsReached()
    for _, name in ipairs(wildPetList) do
        if selectedWildPets[name] and isPetNeeded(name) then return false end
    end
    return true
end

local function findBestPet()
    local pets = findWildPets()
    local best, bestNeed = nil, -1
    for _, w in ipairs(pets) do
        local name = w.name
        if name and selectedWildPets[name] and isPetNeeded(name) then
            local need = (perPetLimit[name] or 1) - (boughtThisServer[name] or 0)
            if need > bestNeed and w.owner == 0 and w.price > 0 and w.price <= maxPetPrice and getSh() >= w.price then
                bestNeed = need
                best = w
            end
        end
    end
    return best
end

task.spawn(function()
    while true do
        if autoBuyWildPets then
            pcall(function()
                if allLimitsReached() then
                    print("[UnAlive] All pet limits reached for this server")
                    task.wait(5)
                    return
                end

                local pet = findBestPet()
                if pet then
                    if petTeleport then
                        atPosition(pet.pos, function() fire("Pets.WildPetTame", pet.part) end)
                    else
                        fire("Pets.WildPetTame", pet.part)
                    end

                    -- Verify purchase
                    local t0 = os.clock()
                    local verified = false
                    while os.clock() - t0 < 10 do
                        if hasPetInInventory(pet.name) then
                            verified = true
                            break
                        end
                        task.wait(0.2)
                    end

                    if verified then
                        boughtThisServer[pet.name] = (boughtThisServer[pet.name] or 0) + 1
                        print("[UnAlive] Bought", pet.name, "| Server total:", boughtThisServer[pet.name])
                    end
                end
            end)
        end
        local w = petBuyInterval
        local e = 0
        while e < w and autoBuyWildPets do task.wait(0.4); e = e + 0.4 end
        if not autoBuyWildPets then task.wait(2) end
    end
end)
