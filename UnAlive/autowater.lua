-- == UnAlive Auto-Water [STANDALONE] ==
-- Farm tab: waters all planted crops with watering can.
-- Paste into your script.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local CS = game:GetService("CollectionService"); local LP = Players.LocalPlayer
    local Net; do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }; local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    local function jitter(a, b) a = a or 0.05; b = b or 0.12; return a + math.random() * (b - a) end
    Sk = { fire = fire, jitter = jitter, LP = LP, WS = WS, CS = CS }; getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local jitter = Sk.jitter; local LP = Sk.LP; local WS = Sk.WS; local CS = Sk.CS

local function myPlot() local id = LP:GetAttribute("PlotId"); local g = WS:FindFirstChild("Gardens"); if not (id and g) then return nil end; return g:FindFirstChild("Plot" .. tostring(id)) end
local function humanoid() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function toolsByAttr(attr, want) local out = {}; local function scan(c) if not c then return end; for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute(attr) ~= nil then if (not want) or t:GetAttribute(attr) == want or t.Name == want then out[#out + 1] = t end end end end; scan(LP:FindFirstChild("Backpack")); scan(LP.Character); return out end
local function heldToolByAttr(attr) local c = LP.Character; local t = c and c:FindFirstChildWhichIsA("Tool"); if t and t:GetAttribute(attr) ~= nil then return t end; return nil end
local function equipByAttr(attr, want) local t = heldToolByAttr(attr); if t and ((not want) or t:GetAttribute(attr) == want) then return t end; t = toolsByAttr(attr, want)[1]; if not t then return nil end; local hum = humanoid(); if not hum then return nil end; hum:EquipTool(t); task.wait(0.22); return heldToolByAttr(attr) end
local function existingPlantPositions() local out = {}; local plot = myPlot(); local plants = plot and plot:FindFirstChild("Plants"); if not plants then return out end; for _, m in ipairs(plants:GetChildren()) do local ok, piv = pcall(function() return m:GetPivot().Position end); if ok then out[#out + 1] = piv end end; return out end

local autoWater = false; local waterInterval = 8; local watered = 0

task.spawn(function()
    while true do
        if autoWater then pcall(function()
            local t = equipByAttr("WateringCan"); if not t then return end
            local name = t:GetAttribute("WateringCan")
            for _, pos in ipairs(existingPlantPositions()) do
                if not autoWater then break end
                fire("WateringCan.UseWateringCan", pos - Vector3.new(0, 0.3, 0), name, t)
                watered = watered + 1; task.wait(jitter(0.15, 0.3))
            end
        end) end
        local w = waterInterval; local e = 0; while e < w and autoWater do task.wait(0.4); e = e + 0.4 end; if not autoWater then task.wait(1) end
    end
end)
