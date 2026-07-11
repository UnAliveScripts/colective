-- == UnAlive Shovel Plant Remover ==

local Players = game:GetService("Players"); local WS = game:GetService("Workspace"); local LP = Players.LocalPlayer
local Net = require(game.ReplicatedStorage.SharedModules.Networking)

local function getPlot()
    local id = LP:GetAttribute("PlotId")
    if not id then return nil end
    return WS:FindFirstChild("Gardens") and WS.Gardens:FindFirstChild("Plot" .. tostring(id))
end

local function getShovel()
    local c = LP.Character
    if c then for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("Shovel") then return t end end end
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("Shovel") then return t end end end
    return nil
end

local function findPlants(targetName)
    local out = {}
    local plot = getPlot()
    if not plot then return out end
    local pf = plot:FindFirstChild("Plants")
    if not pf then return out end
    for _, plant in ipairs(pf:GetChildren()) do
        local ff = plant:FindFirstChild("Fruits")
        if ff then
            for _, fruit in ipairs(ff:GetChildren()) do
                if fruit:GetAttribute("CorePartName") == targetName then
                    local pid = plant:GetAttribute("PlantId")
                    if pid then table.insert(out, tostring(pid)) end
                    break
                end
            end
        end
    end
    return out
end

getgenv()._ShovelRemove = {
    remove = function(name)
        if type(name) ~= "string" then print("Usage: .remove(\"Strawberry\")"); return end
        local shovel = getShovel()
        if not shovel then print("No shovel found"); return end
        local plants = findPlants(name)
        if #plants == 0 then print("No " .. name .. " plants found"); return end
        local count = 0
        for _, pid in ipairs(plants) do
            Net.Shovel.UseShovel:Fire(pid, "", shovel:GetAttribute("Shovel") or "Shovel", shovel)
            count = count + 1
            task.wait(0.15)
        end
        print("Removed " .. count .. " " .. name)
    end,
    list = function()
        local counts = {}
        local plot = getPlot()
        if not plot then return counts end
        local pf = plot:FindFirstChild("Plants")
        if not pf then return counts end
        for _, plant in ipairs(pf:GetChildren()) do
            local ff = plant:FindFirstChild("Fruits")
            if ff then
                local seen = {}
                for _, fruit in ipairs(ff:GetChildren()) do
                    local ct = fruit:GetAttribute("CorePartName")
                    if ct and not seen[ct] then seen[ct] = true; counts[ct] = (counts[ct] or 0) + 1 end
                end
            end
        end
        return counts
    end
}

print("Loaded. .remove(\"Strawberry\") .list()")
