-- == UnAlive Auto-Skill [STANDALONE] ==
-- Config tab: auto-spends skill points on selected stats.
-- Stats: "BaseSpeed", "BaseJump", "ShovelPower", "MaxBackpack"
-- Paste into your script.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local RS = game:GetService("ReplicatedStorage")
    local Net; do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }; local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    Sk = { fire = fire }; getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire

local autoSkill = false
local skillStats = { BaseSpeed = true }

task.spawn(function() while true do if autoSkill then pcall(function() for stat in pairs(skillStats) do if not autoSkill then break end; fire("SkillPoints.SpendSkillPoint", stat); task.wait(0.25) end end) end; task.wait(6) end end)
