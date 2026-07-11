-- == UnAlive Auto-Pets [STANDALONE] ==
-- Farm tab: equip pets, buy slots, sell pets.
-- Paste into your script.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local LP = Players.LocalPlayer
    pcall(function() if setthreadidentity then setthreadidentity(8) end; if syn and syn.set_thread_identity then syn.set_thread_identity(8) end end)
    local Net; do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }; local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    local function jitter(a, b) a = a or .05; b = b or .12; return a + math.random() * (b - a) end
    local _rep; local function rep() if _rep then return _rep end; local ok, psc = pcall(require, RS.ClientModules.PlayerStateClient); if ok and psc and psc.WaitForLocalReplica then local ok2, r = pcall(psc.WaitForLocalReplica, psc, 30); if ok2 and r then _rep = r end end; return _rep end
    local function pd() local r = rep(); return (r and r.Data) or {} end
    local function inv(c) local i = pd().Inventory; return (i and i[c]) or {} end
    Sk = { fire = fire, jitter = jitter, inv = inv, LP = LP, WS = WS, RS = RS }; getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local jitter = Sk.jitter; local inv = Sk.inv; local LP = Sk.LP; local WS = Sk.WS

local function toolsByAttr(attr, want) local out = {}; local function scan(c) if not c then return end; for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute(attr) ~= nil then if (not want) or t:GetAttribute(attr) == want or t.Name == want then out[#out + 1] = t end end end end; scan(LP:FindFirstChild("Backpack")); scan(LP.Character); return out end
local function humanoid() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function invNames(c) local out = {}; for k, v in pairs(inv(c)) do local nm, ct; if type(v) == "table" then nm = v.Name or v.ItemName or v.Type or (type(k) == "string" and k) or tostring(k); ct = tonumber(v.Count) or tonumber(v.Amount) or 1 elseif type(v) == "number" then nm, ct = tostring(k), v else nm, ct = tostring(k), 1 end; if nm then out[nm] = (out[nm] or 0) + (ct or 1) end end; return out end
local function ownedPetNames() local names, seen = {}, {}; for nm in pairs(invNames("Pets")) do if not seen[nm] then seen[nm] = true; names[#names + 1] = nm end end; for _, t in ipairs(toolsByAttr("PetId")) do local nm = t:GetAttribute("PetName") or t.Name; if nm and not seen[nm] then seen[nm] = true; names[#names + 1] = nm end end; table.sort(names); return names end
local function equippedPetCount() local ok, list = fire("Pets.GetEquippedPets"); if ok and type(list) == "table" then local n = 0; for _ in pairs(list) do n = n + 1 end; return n end; return 0 end

local autoEquipPets = false; local autoPetSlot = false; local autoSellPets = false; local sellPets = {}; local tamed = 0

task.spawn(function() while true do if autoEquipPets then pcall(function() local cap = tonumber(LP:GetAttribute("MaxEquippedPets")) or 3; local have = equippedPetCount(); if have >= cap then return end; for _, nm in ipairs(ownedPetNames()) do if not autoEquipPets or have >= cap then break end; fire("Pets.RequestEquipByName", nm); have = have + 1; task.wait(0.3) end end) end; task.wait(12) end end)
task.spawn(function() while true do if autoPetSlot then pcall(function() fire("Pets.RequestPurchasePetSlot") end) end; task.wait(20) end end)
task.spawn(function() while true do if autoSellPets and next(sellPets) then pcall(function() for _, t in ipairs(toolsByAttr("PetId")) do if not autoSellPets then break end; local nm = t:GetAttribute("PetName") or t.Name; if sellPets[nm] then local hum = humanoid(); if hum then hum:EquipTool(t); task.wait(0.25) end; fire("NPCS.SellPet", t:GetAttribute("PetId")); task.wait(0.3) end end end) end; task.wait(4) end end)
