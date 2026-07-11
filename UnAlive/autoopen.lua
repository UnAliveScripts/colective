-- == UnAlive Auto-Open [STANDALONE] ==
-- Farm tab: opens eggs, crates, and seed packs.
-- Paste into your script.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local RS = game:GetService("ReplicatedStorage")
    local Net; do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }; local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    local function jitter(a, b) a = a or 0.05; b = b or 0.12; return a + math.random() * (b - a) end
    local _rep; local function rep() if _rep then return _rep end; local ok, psc = pcall(require, RS.ClientModules.PlayerStateClient); if ok and psc and psc.WaitForLocalReplica then local ok2, r = pcall(psc.WaitForLocalReplica, psc, 30); if ok2 and r then _rep = r end end; return _rep end
    local function pd() local r = rep(); return (r and r.Data) or {} end
    local function inv(c) local i = pd().Inventory; return (i and i[c]) or {} end
    local function invNames(c) local out = {}; for k, v in pairs(inv(c)) do local nm, ct; if type(v) == "table" then nm = v.Name or v.ItemName or v.Type or (type(k) == "string" and k) or tostring(k); ct = tonumber(v.Count) or tonumber(v.Amount) or 1 elseif type(v) == "number" then nm, ct = tostring(k), v else nm, ct = tostring(k), 1 end; if nm then out[nm] = (out[nm] or 0) + (ct or 1) end end; return out end
    Sk = { fire = fire, jitter = jitter, invNames = invNames }; getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local jitter = Sk.jitter; local invNames = Sk.invNames

local autoEgg = false; local autoCrate = false; local autoPack = false; local openInterval = 4; local opened = 0

local function openAll(category, path)
    for nm, count in pairs(invNames(category)) do
        for _ = 1, math.min(count, 25) do
            local ok, res = fire(path, nm); if not ok then break end; if type(res) == "table" and res.Success == false then break end
            opened = opened + 1; task.wait(jitter(0.25, 0.5))
        end
    end
end

task.spawn(function() while true do if autoEgg then pcall(openAll, "Eggs", "Egg.OpenEgg") end; task.wait(0.2); if autoCrate then pcall(openAll, "Crates", "Crate.OpenCrate") end; task.wait(0.2); if autoPack then pcall(openAll, "SeedPacks", "SeedPack.OpenSeedPack") end; task.wait(openInterval) end end)
