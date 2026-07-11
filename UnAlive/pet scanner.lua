-- == UnAlive Pet Scanner + Webhook [STANDALONE] ==
-- Scans wild pets, sends Discord webhook for high-rarity finds, then server hops.
-- Set WEBHOOK_URL and MIN_RARITY below. 🔒 Locked to rockytheboy515.

local WEBHOOK_URL = ""
local MIN_RARITY = "Legendary"

if syn and syn.request then request = syn.request end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

repeat task.wait() until game:IsLoaded()
local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

-- 🔒 User lock
if LocalPlayer.Name ~= "rockytheboy515" then
    game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Locked", Text = "This script only works for rockytheboy515", Duration = 8 })
    return
end

local RARITY_ORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Super = 5, Legendary = 6, Mythic = 7 }

local RARITIES = {
    Bunny = "Common", Frog = "Common", Owl = "Uncommon", Raccoon = "Super", Monkey = "Mythic",
    Robin = "Legendary", Deer = "Rare", Bee = "Legendary", Unicorn = "Mythic", GoldenDragonfly = "Mythic",
    Bear = "Mythic", ["Black Dragon"] = "Super", ["Ice Serpent"] = "Super",
}

local RARITY_EMOJIS = { Common = "⚪", Uncommon = "🟢", Rare = "🔵", Epic = "🟣", Legendary = "🟠", Mythic = "🔴", Super = "🟣" }
local RARITY_COLORS = { Common = 8421504, Uncommon = 65280, Rare = 255, Epic = 10494192, Legendary = 16766720, Mythic = 16711680, Super = 16711935 }

local function cleanName(raw)
    local name = raw:gsub("WildPet_", ""):gsub("_WildPet", "")
    return name:gsub("_[%w]+%-[%w]+%-[%w]+%-[%w]+%-[%w]+$", "")
end

local function getRarity(name) return RARITIES[name] or "Unknown" end

local function shouldSend(rarity) return (RARITY_ORDER[rarity] or 0) >= (RARITY_ORDER[MIN_RARITY] or 0) end

local function getText(pet, name)
    local root = pet:FindFirstChild("RootPart") or pet:FindFirstChildWhichIsA("BasePart")
    if not root then return "N/A", "N/A" end
    local timerLabel = root:FindFirstChild("PetLeaveTimer")
    local timeLeft = timerLabel and timerLabel:FindFirstChildOfClass("TextLabel") and timerLabel:FindFirstChildOfClass("TextLabel").Text or "N/A"
    local price = "N/A"
    for _, child in ipairs(pet:GetDescendants()) do
        if child:IsA("TextLabel") then
            local txt = child.Text
            if txt:find("¢") or txt:find("Coin") or txt:find("$") then price = txt; break end
        end
    end
    return price, timeLeft
end

local function sendWebhook(petName, rarity, price, timeLeft)
    local joinLink = "https://starscripts-five.vercel.app/start?placeId=" .. PLACE_ID .. "&gameInstanceId=" .. JOB_ID
    local embed = {
        embeds = {{
            title = petName, description = "A pet has been found in the server",
            color = RARITY_COLORS[rarity] or 8421504,
            fields = {
                { name = "Rarity", value = (RARITY_EMOJIS[rarity] or "⚪") .. " " .. rarity, inline = true },
                { name = "Price", value = price, inline = true },
                { name = "Time Remaining", value = timeLeft, inline = true },
                { name = "Join Server", value = "[Click to Join](" .. joinLink .. ")", inline = false },
            },
            footer = { text = "UnAlive Hub" },
        }}
    }
    pcall(function()
        request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(embed) })
    end)
    print("[UnAlive] Found:", petName, "|", rarity, "|", price, "|", timeLeft)
end

local function scanPets()
    local map = workspace:FindFirstChild("Map")
    if not map then return end
    local spawns = map:FindFirstChild("WildPetSpawns")
    if not spawns then return end
    for _, pet in ipairs(spawns:GetChildren()) do
        local clean = cleanName(pet.Name)
        local rarity = getRarity(clean)
        if shouldSend(rarity) then
            local price, timeLeft = getText(pet, clean)
            sendWebhook(clean, rarity, price, timeLeft)
        end
        task.wait(1)
    end
end

local function serverHop()
    local ok, data = pcall(function() return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?limit=100")) end)
    if ok and data and data.data then
        local servers = {}
        for _, s in ipairs(data.data) do
            if s.id ~= JOB_ID and s.playing < s.maxPlayers then table.insert(servers, s.id) end
        end
        if #servers > 0 then
            TeleportService:TeleportToPlaceInstance(PLACE_ID, servers[math.random(1, #servers)], LocalPlayer)
        end
    end
end

scanPets()
task.wait(5)
serverHop()
