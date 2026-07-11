-- == UnAlive Utilities [STANDALONE] ==
-- Shared helpers: weather prediction, moon phases, utility functions.
-- Include this first if you want shared core, or each feature script works alone.
-- Paste into your script.

-- Weather / Moon Predictor
local sum = 600
local moonChances = {
    { Name = "Rainbow Moon", Chance = 6 },
    { Name = "Goldmoon",     Chance = 13 },
    { Name = "Bloodmoon",    Chance = 2 },
    { Name = "Moon",         Chance = 79 },
}

local function getMoonType(cycleID, order)
    local rng = Random.new(cycleID * 1000 + order)
    local roll = rng:NextNumber() * 100
    local cumulative = 0
    for _, m in ipairs(moonChances) do
        cumulative = cumulative + m.Chance
        if roll <= cumulative then return m.Name end
    end
    return "Moon"
end

local function getCurrentMoon()
    return getMoonType(math.floor(os.time() / sum), 3)
end

local function isNight()
    local n = game:GetService("ReplicatedStorage"):FindFirstChild("Night")
    return n and n.Value == true
end

local function predict24Hours()
    local startTime = os.time()
    local endTime = startTime + (24 * 3600)
    for t = startTime, endTime, sum do
        local cycleID = math.floor(t / sum)
        local moon = getMoonType(cycleID, 3)
        print(string.format("[%s] Cycle: %d | Moon: %s", os.date("%I:%M %p", t), cycleID, moon))
    end
end

-- Utility helpers
local function jitter(a, b) a = a or 0.05; b = b or 0.12; return a + math.random() * (b - a) end

local function formatNumber(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return ("%.2fT"):format(n / 1e12) end
    if n >= 1e9  then return ("%.2fB"):format(n / 1e9) end
    if n >= 1e6  then return ("%.2fM"):format(n / 1e6) end
    if n >= 1e3  then return ("%.2fK"):format(n / 1e3) end
    return tostring(math.floor(n))
end

-- Notify (Roblox notification)
local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title or "UnAlive",
            Text = text or "",
            Duration = duration or 3,
        })
    end)
end

print("[UnAlive] Utilities loaded")
