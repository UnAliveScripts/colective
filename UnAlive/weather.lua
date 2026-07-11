-- == UnAlive Weather Predictor [STANDALONE] ==
-- Predicts moon phases and weather for steal timing.
-- Paste into your script. No dependencies.

local sum = 600

local moonChances = {
    {Name = "Rainbow Moon", Chance = 6},
    {Name = "Goldmoon", Chance = 13},
    {Name = "Bloodmoon", Chance = 2},
    {Name = "Moon", Chance = 79}
}

local function getMoonType(cycleID, order)
    local rng = Random.new(cycleID * 1000 + order)
    local roll = rng:NextNumber() * 100
    local sum2 = 0
    for _, moon in ipairs(moonChances) do
        sum2 = sum2 + moon.Chance
        if roll <= sum2 then return moon.Name end
    end
    return "Moon"
end

local function getCurrentMoonType()
    local t = os.time()
    local cycleID = math.floor(t / sum)
    return getMoonType(cycleID, 3)
end

local function isNightNow()
    local RS = game:GetService("ReplicatedStorage")
    local n = RS:FindFirstChild("Night")
    return n and n.Value == true
end

local function predictWindow(hours)
    hours = hours or 24
    local startTime = os.time()
    local endTime = startTime + (hours * 3600)
    local results = {}
    for t = startTime, endTime, sum do
        local cycleID = math.floor(t / sum)
        local timeString = os.date("%I:%M %p", t)
        local moonType = getMoonType(cycleID, 3)
        results[#results + 1] = { time = timeString, cycleID = cycleID, moon = moonType, timestamp = t }
    end
    return results
end

-- Returns table of upcoming night windows (when Night value should be true)
-- Note: actual Night toggling is server-side; this predicts moon phases
local function getUpcomingNightWindows(count)
    count = count or 5
    local t = os.time()
    local windows = {}
    local inNight = false
    local windowStart = nil
    for i = 0, 1000 do
        local ts = t + (i * sum)
        local cycleID = math.floor(ts / sum)
        local moon = getMoonType(cycleID, 3)
        local isNight = (moon ~= "Sun")  -- any moon type = night
        if isNight and not inNight then
            windowStart = ts
            inNight = true
        elseif not isNight and inNight and windowStart then
            windows[#windows + 1] = { start = windowStart, end = ts, moon = getMoonType(math.floor(windowStart / sum), 3) }
            inNight = false
            if #windows >= count then break end
        end
    end
    return windows
end

print("[UnAlive] Weather predictor loaded")
