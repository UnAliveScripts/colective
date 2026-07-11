-- == UnAlive Auto-Pot [STANDALONE] ==
-- Farm tab: pots all plants in your garden.
-- Paste into your script.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local LP = Players.LocalPlayer
    local Net; do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }; local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    Sk = { fire = fire, LP = LP, WS = WS }; getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local LP = Sk.LP; local WS = Sk.WS
local function myPlot() local id = LP:GetAttribute("PlotId"); local g = WS:FindFirstChild("Gardens"); if not (id and g) then return nil end; return g:FindFirstChild("Plot" .. tostring(id)) end
local autoPot = false
task.spawn(function() while true do if autoPot then pcall(function() local plot = myPlot(); local plants = plot and plot:FindFirstChild("Plants"); if not plants then return end; for _, m in ipairs(plants:GetChildren()) do if not autoPot then break end; local pid = m:GetAttribute("PlantId") or m.Name; if pid then fire("Garden.PotPlant", tostring(pid)); task.wait(0.3) end end end) end; task.wait(5) end end)
