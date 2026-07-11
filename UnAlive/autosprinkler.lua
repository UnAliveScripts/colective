-- == UnAlive Auto-Sprinkler [STANDALONE] ==
-- Farm tab: places owned sprinklers across your plot.
-- Paste into your script.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local CS = game:GetService("CollectionService"); local LP = Players.LocalPlayer
    pcall(function() if setthreadidentity then setthreadidentity(8) end; if syn and syn.set_thread_identity then syn.set_thread_identity(8) end end)
    local Net; do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }; local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    Sk = { fire = fire, LP = LP, WS = WS, CS = CS }; getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local LP = Sk.LP; local WS = Sk.WS; local CS = Sk.CS

local function myPlot() local id = LP:GetAttribute("PlotId"); local g = WS:FindFirstChild("Gardens"); if not (id and g) then return nil end; return g:FindFirstChild("Plot" .. tostring(id)) end
local function myPlotId() return LP:GetAttribute("PlotId") end
local function humanoid() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function toolsByAttr(attr, want) local out = {}; local function scan(c) if not c then return end; for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute(attr) ~= nil then if (not want) or t:GetAttribute(attr) == want or t.Name == want then out[#out + 1] = t end end end end; scan(LP:FindFirstChild("Backpack")); scan(LP.Character); return out end
local function heldToolByAttr(attr) local c = LP.Character; local t = c and c:FindFirstChildWhichIsA("Tool"); if t and t:GetAttribute(attr) ~= nil then return t end; return nil end
local function myPlantAreas() local out = {}; local plot = myPlot(); if not plot then return out end; for _, p in ipairs(CS:GetTagged("PlantArea")) do if p:IsA("BasePart") and p:IsDescendantOf(plot) then out[#out + 1] = p end end; return out end
local function plantGrid(spacing) local pts = {}; local areas = myPlantAreas(); spacing = math.max(2, spacing or 4); local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.FilterDescendantsInstances = areas; for _, area in ipairs(areas) do local cf, size = area.CFrame, area.Size; local topY = (cf * CFrame.new(0, size.Y / 2, 0)).Position.Y; for dx = -size.X / 2 + spacing / 2, size.X / 2 - spacing / 2, spacing do for dz = -size.Z / 2 + spacing / 2, size.Z / 2 - spacing / 2, spacing do local w = (cf * CFrame.new(dx, 0, dz)).Position; local hit = WS:Raycast(Vector3.new(w.X, topY + 10, w.Z), Vector3.new(0, -40, 0), params); if hit then pts[#pts + 1] = hit.Position end end end end; return pts end
local function existingPlantPositions() local out = {}; local plot = myPlot(); local plants = plot and plot:FindFirstChild("Plants"); if not plants then return out end; for _, m in ipairs(plants:GetChildren()) do local ok, piv = pcall(function() return m:GetPivot().Position end); if ok then out[#out + 1] = piv end end; return out end

local autoSprinkler = false; local sprinklerInterval = 30; local sprinklersPlaced = 0

task.spawn(function()
    while true do
        if autoSprinkler then pcall(function()
            local pid = myPlotId(); if not pid then return end
            local placed = existingPlantPositions()
            for _, t in ipairs(toolsByAttr("Sprinkler")) do
                if not autoSprinkler then break end
                local hum = humanoid(); if not hum then break end; hum:EquipTool(t); task.wait(0.22)
                t = heldToolByAttr("Sprinkler"); if not t then break end
                local grid = plantGrid(8)
                for _, pos in ipairs(grid) do
                    local far = true; for _, op in ipairs(placed) do if (pos - op).Magnitude < 12 then far = false; break end end
                    if far then fire("Place.PlaceSprinkler", pos, t:GetAttribute("Sprinkler"), t, pid); sprinklersPlaced = sprinklersPlaced + 1; placed[#placed + 1] = pos; task.wait(0.3); break end
                end
            end
            pcall(function() local h = humanoid(); if h then h:UnequipTools() end end)
        end) end
        local w = sprinklerInterval; local e = 0; while e < w and autoSprinkler do task.wait(0.4); e = e + 0.4 end; if not autoSprinkler then task.wait(1) end
    end
end)
