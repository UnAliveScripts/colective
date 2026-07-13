-- bro obfuscated this script in Base 64 💀 Chat gpt 100%
-- DеоЬfuѕсаtеd bу LeаκD | discord.gg/qteAQmfJmP

-- ══════════════════════════════════════════════════════════════════════════════
--  Grow a Garden 2 Hub  |  v3.0  (ULTRA — direct-remote edition)
--  Game : Faites pousser un jardin 2   |  GameId 10200395747
--  Loop : buy  plant  grow  harvest (direct remote)  sell  repeat
--  Extras: ESP, Weather Alerts, Auto-Water, Auto-Skill, Auto-Gear, Fruit Bids,
--          Mutation Scanner, Player Whitelist, Server Hop, Anti-AFK, Fly, etc.
-- ══════════════════════════════════════════════════════════════════════════════

if not game:IsLoaded() then game.Loaded:Wait() end

-- ── UI Library loader (Y2k Core one-liner) ─────────────────────────────────
local Y2k = loadstring(game:HttpGet("https://y2kscript.xyz/lib?f=Core.lua&cb=" .. tostring(math.random(1, 1e7))))()
local Library, ThemeManager, SaveManager = Y2k.Library, Y2k.ThemeManager, Y2k.SaveManager
local StatsPanel, Watermark, Keybinds = Y2k.StatsPanel, Y2k.Watermark, Y2k.Keybinds
local Toggles, Options = Y2k.Toggles, Y2k.Options

if Y2k.claim and not Y2k.claim("Grow a Garden 2") then
    pcall(function() Library:Notify({ Title = "Grow a Garden 2", Description = "Already running - press Right Ctrl to toggle the menu.", Time = 5 }) end)
    return
end

-- ── Services ───────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UIS               = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TeleportService   = game:GetService("TeleportService")
local HttpService        = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer

-- ── Networking module (the game's remote wrapper) ──────────────────────────
local SharedModules = ReplicatedStorage:WaitForChild("SharedModules", 15)
local Networking = SharedModules and require(SharedModules:WaitForChild("Networking", 15))
if not Networking then warn("[GAG3] Networking module not found — some features will be disabled.") end

-- ── Garden data structures tracked from server events ─────────────────────
--  plantData[plantId] = { fruitIds = { fruitId -> true }, grown = bool }
local plantData  = {}   -- live-synced from GardenPlantAdded / GardenFruitAdded etc.
local fruitData  = {}   -- fruitId -> { plantId, grown, mutated, name }
local gardenOwners = {} -- gardenFolder -> ownerUserId

-- ── Seed list ──────────────────────────────────────────────────────────────
local Seeds = {
    "Carrot","Strawberry","Blueberry","Tulip","Tomato","Apple","Bamboo","Corn","Cactus",
    "Pineapple","Mushroom","Green Bean","Banana","Grape","Coconut","Mango","Dragon Fruit","Acorn",
    "Cherry","Sunflower","Venus Fly Trap","Pomegranate","Poison Apple","Moon Bloom","Dragon's Breath",
    "Ghost Pepper","Poison Ivy","Baby Cactus","Glow Mushroom","Romanesco","Horned Melon","Gold","Rainbow",
}

-- ── Gear list ──────────────────────────────────────────────────────────────
local Gears = { "Basic Sprinkler", "Watering Can", "Power Hose", "Shovel", "Rake", "Trowel" }

-- ── Config ─────────────────────────────────────────────────────────────────
local Cfg = {
    -- Farm (fast defaults)
    AutoHarvest = false, HarvestDelay = 0.1, HarvestOwnOnly = true,
    AutoSell = false, SellDelay = 3,
    AutoPlant = false, PlantSeed = "Carrot", PlantRows = 6, PlantCols = 6, PlantDelay = 0.05,
    AutoBuy = false, BuySeed = "Carrot", BuyDelay = 0.5, AutoBuyAll = false,
    AutoWater = false, WaterDelay = 2,
    AutoSprinkler = false, SprinklerName = "Basic Sprinkler",
    -- Extra
    AutoSteal = false, StealTP = true,
    AutoTame = false,
    AutoBuyPet = false, PetBuyMaxPrice = 500,
    AutoDailyDeal = false,
    AutoMail = false,
    AutoSkill = false, SkillId = "",
    AutoBid = false, BidFruit = "Carrot",
    -- Alerts
    AlertRain = true, AlertNight = true, AlertBloodmoon = true,
    AlertBlizzard = true, AlertLightning = true, AlertRainbow = true,
    -- ESP
    ESPPlayers = false, ESPFruits = false, ESPPets = false,
    -- Player
    WalkSpeed = 25, JumpPower = 50, InfJump = false, Noclip = false,
    Fly = false, FlySpeed = 70, AntiAFK = false,
    -- Misc
    RedeemCode = "",
    LowGraphics = false,
}

-- Unload state: every worker loop checks _DEAD; the unload handler sets it true
local _DEAD = false

-- ── Utility helpers ────────────────────────────────────────────────────────
local function notify(t, d)
    pcall(function() Library:Notify({ Title = t, Description = d, Time = 4 }) end)
end

local function jitter(base, variance)
    variance = variance or base * 0.25
    return base + (math.random() - 0.5) * 2 * variance
end

local function hum()
    local c = LocalPlayer.Character; return c and c:FindFirstChildOfClass("Humanoid")
end
local function root()
    local c = LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart")
end

-- ── Plot helpers ───────────────────────────────────────────────────────────
local function getPlot()
    local g = Workspace:FindFirstChild("Gardens"); if not g then return nil end
    for _, p in ipairs(g:GetChildren()) do
        if tostring(p:GetAttribute("OwnerUserId")) == tostring(LocalPlayer.UserId) then return p end
    end
end
local Plot = getPlot()

local function plotCenter()
    if not Plot then return nil end
    local ref = Plot:FindFirstChild("PlotSizeReference") or Plot:FindFirstChild("SpawnPoint")
    return ref and ref:IsA("BasePart") and ref.Position or nil
end

local function sheckles()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local s = ls and ls:FindFirstChild("Sheckles")
    return s and tostring(s.Value) or "?"
end

-- ── Live-sync garden data from server events ───────────────────────────────
-- This lets Auto-Harvest use real plant/fruit IDs without scanning prompts.
if Networking then
    pcall(function()
        Networking.Garden.PlantAdded:Connect(function(gardenId, plantId, seedType)
            plantData[plantId] = plantData[plantId] or { fruitIds = {}, grown = false, seedType = seedType }
        end)
        Networking.Garden.PlantRemoved:Connect(function(gardenId, plantId)
            plantData[plantId] = nil
        end)
        Networking.Garden.FruitAdded:Connect(function(gardenId, plantId, fruitId, fruitName)
            plantData[plantId] = plantData[plantId] or { fruitIds = {}, grown = false }
            plantData[plantId].fruitIds[fruitId] = true
            fruitData[fruitId] = { plantId = plantId, grown = false, name = fruitName or "" }
        end)
        Networking.Garden.FruitGrowthUpdated:Connect(function(gardenId, plantId, fruitId, age, maxAge)
            if fruitData[fruitId] then fruitData[fruitId].grown = (age ~= nil and maxAge ~= nil and age >= maxAge) end
        end)
        Networking.Garden.FruitRemoved:Connect(function(gardenId, plantId, fruitId)
            if plantData[plantId] then plantData[plantId].fruitIds[fruitId] = nil end
            fruitData[fruitId] = nil
        end)
        Networking.Garden.FruitMutationUpdated:Connect(function(gardenId, plantId, fruitId, mutations)
            if fruitData[fruitId] then fruitData[fruitId].mutated = (mutations and next(mutations) ~= nil) end
        end)
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
--  WINDOW
-- ════════════════════════════════════════════════════════════════════════════
local Window = Library:CreateWindow({
    Title = "GAG2 Hub v3", Footer = "Ultra Edition — Y2k",
    NotifySide = "Right", ShowCustomCursor = true, Center = true,
    AutoShow = true, Resizable = true, CornerRadius = 10,
})

local Tabs = {
    Farm     = Window:AddTab("Auto Farm",  "sprout"),
    Shop     = Window:AddTab("Shop",       "shopping-cart"),
    Player   = Window:AddTab("Player",     "user"),
    Extra    = Window:AddTab("Extra",      "star"),
    ESP      = Window:AddTab("ESP",        "scan-eye"),
    Weather  = Window:AddTab("Weather",    "cloud-sun"),
    Misc     = Window:AddTab("Misc",       "wrench"),
    Settings = Window:AddTab("Settings",   "settings"),
}

-- ── HUD (shared Y2k StatsPanel + Watermark + Keybinds modules) ──────────────
local panel = StatsPanel.new(Library, { title = "GROW A GARDEN 2" })
panel:Line("sheckles", { size = 15, color = Color3.fromRGB(120, 255, 140), bold = true })
panel:Line("players",  { size = 12, color = Color3.fromRGB(150, 210, 255) })
panel:Line("fps",      { size = 12 })

local wm = Watermark.new(Library, { title = "Y2k" })
wm:Bind(function()
    return ("Y2k  |  Grow a Garden 2  |  %d fps"):format(math.floor(Y2k.fps()))
end, 1)

local kb = Keybinds.new(Library, { title = "Keybinds" })

-- ════════════════════════════════════════════════════════════════════════════
--  AUTO FARM TAB
-- ════════════════════════════════════════════════════════════════════════════
local hBox = Tabs.Farm:AddLeftGroupbox("Harvest & Sell", "scissors")
hBox:AddToggle("AutoHarvest", {
    Text = "Auto Harvest (Direct Remote)", Default = false,
    Tooltip = "Fires CollectFruit remote for every grown fruit — no proximity needed.",
    Callback = function(v) Cfg.AutoHarvest = v notify("Auto Harvest (Direct Remote)", v and "ON" or "OFF") end
})
hBox:AddToggle("HarvestOwnOnly", {
    Text = "Own plot only", Default = true,
    Tooltip = "Only harvest fruits from YOUR own garden.",
    Callback = function(v) Cfg.HarvestOwnOnly = v notify("Own plot only", v and "ON" or "OFF") end
})
hBox:AddSlider("HarvestDelay", {
    Text = "Harvest interval (s)", Default = 0.1, Min = 0.05, Max = 5, Rounding = 2,
    Callback = function(v) Cfg.HarvestDelay = v end
})
hBox:AddToggle("AutoSell", {
    Text = "Auto Sell All", Default = false,
    Tooltip = "Fires SellAll remote periodically.",
    Callback = function(v) Cfg.AutoSell = v notify("Auto Sell All", v and "ON" or "OFF") end
})
hBox:AddSlider("SellDelay", {
    Text = "Sell every (s)", Default = 3, Min = 1, Max = 60, Rounding = 0,
    Callback = function(v) Cfg.SellDelay = v end
})
hBox:AddToggle("AutoDailyDeal", {
    Text = "Auto Daily Deal (5x sell)", Default = false,
    Tooltip = "Uses Steven's daily deal for 5x multiplier.",
    Callback = function(v) Cfg.AutoDailyDeal = v notify("Auto Daily Deal (5x sell)", v and "ON" or "OFF") end
})
hBox:AddDivider({ Text = "Quick Actions" })
hBox:AddButton({ Text = "Harvest Now", Func = function() task.spawn(harvestAll) notify("Harvest Now", "done") end })
hBox:AddButton({ Text = "Sell All Now", Func = function()
    local ok = pcall(function() return Networking.NPCS.SellAll:Fire() end)
    notify("GAG2", ok and "Sold all inventory!" or "Sell failed.")
end })
hBox:AddButton({ Text = "Daily Deal Now", Func = function()
    task.spawn(function() pcall(function() return Networking.NPCS.UseDailyDealAll:Fire() end) end)
notify("Daily Deal Now", "done") end })
hBox:AddButton({ Text = "START FULL FARM", Func = function()
    for _, f in ipairs({"AutoHarvest","AutoPlant","AutoBuy","AutoSell","AutoWater"}) do
        pcall(function() Toggles[f]:SetValue(true) end)
    end
    notify("GAG2 Hub", "Full Farm activated!")
end })

-- Right side: Planting
local pBox = Tabs.Farm:AddRightGroupbox("Auto Plant", "shovel")
pBox:AddDropdown("PlantSeed", {
    Text = "Seed", Values = Seeds, Default = "Carrot",
    Callback = function(v) Cfg.PlantSeed = v end
})
pBox:AddToggle("AutoPlant", {
    Text = "Auto Plant Grid", Default = false,
    Callback = function(v) Cfg.AutoPlant = v notify("Auto Plant Grid", v and "ON" or "OFF") end
})
pBox:AddSlider("PlantRows", { Text = "Rows",    Default = 6, Min = 1, Max = 12, Rounding = 0, Callback = function(v) Cfg.PlantRows = v end })
pBox:AddSlider("PlantCols", { Text = "Columns", Default = 6, Min = 1, Max = 12, Rounding = 0, Callback = function(v) Cfg.PlantCols = v end })
pBox:AddButton({ Text = "Plant Grid Once", Func = function() task.spawn(plantGrid) notify("Plant Grid Once", "done") end })
pBox:AddDivider({ Text = "Watering" })
pBox:AddToggle("AutoWater", {
    Text = "Auto Water Plants", Default = false,
    Tooltip = "Fires UseWateringCan remote across your whole plot to speed growth.",
    Callback = function(v) Cfg.AutoWater = v notify("Auto Water Plants", v and "ON" or "OFF") end
})
pBox:AddSlider("WaterDelay", { Text = "Water every (s)", Default = 2, Min = 0.5, Max = 30, Rounding = 1, Callback = function(v) Cfg.WaterDelay = v end })
pBox:AddButton({ Text = "Water Now", Func = function() task.spawn(waterPlot) notify("Water Now", "done") end })

-- Sprinklers
local sprBox = Tabs.Farm:AddLeftGroupbox("Sprinklers", "droplets")
sprBox:AddToggle("AutoSprinkler", {
    Text = "Auto Place Sprinklers", Default = false,
    Callback = function(v) Cfg.AutoSprinkler = v notify("Auto Place Sprinklers", v and "ON" or "OFF") end
})
sprBox:AddInput("SprinklerName", {
    Text = "Sprinkler name", Default = "Basic Sprinkler", Placeholder = "Basic Sprinkler",
    Callback = function(v) Cfg.SprinklerName = v end
})
sprBox:AddButton({ Text = "Place Sprinklers Now", Func = function() task.spawn(placeSprinklers) notify("Place Sprinklers Now", "done") end })

-- ════════════════════════════════════════════════════════════════════════════
--  SHOP TAB
-- ════════════════════════════════════════════════════════════════════════════
local sBox = Tabs.Shop:AddLeftGroupbox("Seed Shop", "store")
sBox:AddDropdown("BuySeed", { Text = "Seed to buy", Values = Seeds, Default = "Carrot", Callback = function(v) Cfg.BuySeed = v end })
sBox:AddToggle("AutoBuy", { Text = "Auto Buy Seed", Default = false, Callback = function(v) Cfg.AutoBuy = v notify("Auto Buy Seed", v and "ON" or "OFF") end })
sBox:AddToggle("AutoBuyAll", { Text = "Auto Buy ALL seeds", Default = false, Callback = function(v) Cfg.AutoBuyAll = v notify("Auto Buy ALL seeds", v and "ON" or "OFF") end })
sBox:AddSlider("BuyDelay", { Text = "Buy every (s)", Default = 0.5, Min = 0.1, Max = 30, Rounding = 1, Callback = function(v) Cfg.BuyDelay = v end })
sBox:AddButton({ Text = "Buy Selected x1", Func = function() pcall(function() Networking.SeedShop.PurchaseSeed:Fire(Cfg.BuySeed) end) notify("Buy Selected x1", "done") end })
sBox:AddButton({ Text = "Buy ALL seeds once", Func = function()
    for _, s in ipairs(Seeds) do pcall(function() Networking.SeedShop.PurchaseSeed:Fire(s) end) task.wait(0.03) end
notify("Buy ALL seeds once", "done") end })

local sBox2 = Tabs.Shop:AddRightGroupbox("Other Shop", "package")
sBox2:AddDropdown("GearToBuy", { Text = "Gear to buy", Values = Gears, Default = "Watering Can", Callback = function() end })
sBox2:AddButton({ Text = "Purchase Gear", Func = function()
    local g = Options.GearToBuy and Options.GearToBuy.Value or "Watering Can"
pcall(function() Networking.GearShop.PurchaseGear:Fire(g) end)
    notify("Shop", "Buying gear: " .. g)
end })
sBox2:AddButton({ Text = "Expand Garden", Func = function() pcall(function() Networking.Actions.ExpandGarden:Fire() end) notify("Expand Garden", "done") end })
sBox2:AddToggle("AutoMail", { Text = "Auto Claim Mail", Default = false, Callback = function(v) Cfg.AutoMail = v notify("Auto Claim Mail", v and "ON" or "OFF") end })
sBox2:AddButton({ Text = "Claim All Mail Now", Func = function() task.spawn(claimMail) notify("Claim All Mail Now", "done") end })

-- Auto Bid
local bidBox = Tabs.Shop:AddLeftGroupbox("Fruit Bid Watcher", "trending-up")
bidBox:AddLabel({ Text = "Watches NPC bids and auto-sells your highest-value fruit.", DoesWrap = true })
bidBox:AddToggle("AutoBid", { Text = "Auto Best Bid Sell", Default = false, Callback = function(v) Cfg.AutoBid = v notify("Auto Best Bid Sell", v and "ON" or "OFF") end })
bidBox:AddDropdown("BidFruit", { Text = "Fruit to bid-sell", Values = Seeds, Default = "Carrot", Callback = function(v) Cfg.BidFruit = v end })
bidBox:AddButton({ Text = "Check Bid Now", Func = function() task.spawn(checkBid) notify("Check Bid Now", "done") end })
bidBox:AddButton({ Text = "Preview Sell Value", Func = function()
    task.spawn(function()
        local ok, val = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
        notify("Sell Preview", ok and tostring(val) or "Failed.")
    end)
end })

-- ════════════════════════════════════════════════════════════════════════════
--  PLAYER TAB
-- ════════════════════════════════════════════════════════════════════════════
local plBox = Tabs.Player:AddLeftGroupbox("Movement", "footprints")
plBox:AddSlider("WalkSpeed",  { Text = "WalkSpeed",  Default = 25, Min = 16, Max = 350, Rounding = 0, Callback = function(v) Cfg.WalkSpeed = v; local h = hum(); if h then h.WalkSpeed = v end end })
plBox:AddSlider("JumpPower",  { Text = "JumpPower",  Default = 50, Min = 50, Max = 350, Rounding = 0, Callback = function(v) Cfg.JumpPower = v; local h = hum(); if h then h.UseJumpPower = true; h.JumpPower = v end end })
plBox:AddToggle("InfJump",    { Text = "Infinite Jump",  Default = false, Callback = function(v) Cfg.InfJump  = v notify("Infinite Jump", v and "ON" or "OFF") end })
plBox:AddToggle("Noclip",     { Text = "Noclip",         Default = false, Callback = function(v) Cfg.Noclip  = v notify("Noclip", v and "ON" or "OFF") end })
plBox:AddButton({ Text = "Reset Speed/Jump", Func = function()
    Cfg.WalkSpeed = 16; Cfg.JumpPower = 50
    local h = hum(); if h then h.WalkSpeed = 16; h.UseJumpPower = true; h.JumpPower = 50 end
notify("Reset Speed/Jump", "done") end })

local flyBox = Tabs.Player:AddRightGroupbox("Fly", "feather")
flyBox:AddToggle("Fly", { Text = "Fly (WASD + Space/Shift)", Default = false, Callback = function(v) Cfg.Fly = v notify("Fly (WASD + Space/Shift)", v and "ON" or "OFF") end })
flyBox:AddSlider("FlySpeed", { Text = "Fly Speed", Default = 70, Min = 10, Max = 500, Rounding = 0, Callback = function(v) Cfg.FlySpeed = v end })
flyBox:AddButton({ Text = "Teleport to my Plot", Func = function()
    local r, sp = root(), Plot and Plot:FindFirstChild("SpawnPoint")
    if r and sp and sp:IsA("BasePart") then r.CFrame = sp.CFrame + Vector3.new(0, 4, 0) end
notify("Teleport to my Plot", "done") end })

-- ════════════════════════════════════════════════════════════════════════════
--  EXTRA TAB
-- ════════════════════════════════════════════════════════════════════════════
local stealBox = Tabs.Extra:AddLeftGroupbox("Steal (Offensive)", "swords")
stealBox:AddLabel({ Text = "Steals ripe fruit from other players during Night only.", DoesWrap = true })
stealBox:AddToggle("AutoSteal", { Text = "Auto Steal Nearby Fruit", Default = false, Callback = function(v) Cfg.AutoSteal = v notify("Auto Steal Nearby Fruit", v and "ON" or "OFF") end })
stealBox:AddToggle("StealTP",   { Text = "Teleport to Fruit",       Default = true,  Callback = function(v) Cfg.StealTP   = v notify("Teleport to Fruit", v and "ON" or "OFF") end })
stealBox:AddButton({ Text = "Steal All Now", Func = function() task.spawn(stealAll) notify("Steal All Now", "done") end })

local petBox = Tabs.Extra:AddRightGroupbox("Pets", "paw-print")
petBox:AddToggle("AutoTame", { Text = "Auto Tame Wild Pets", Default = false, Callback = function(v) Cfg.AutoTame = v notify("Auto Tame Wild Pets", v and "ON" or "OFF") end })
petBox:AddDivider({ Text = "Auto Buy Pet" })
petBox:AddLabel({ Text = "Scans wild pets — if price is within your budget, buys automatically.", DoesWrap = true })
petBox:AddToggle("AutoBuyPet", {
    Text = "Auto Buy Affordable Pets", Default = false,
    Tooltip = "Checks each wild pet's Price attribute vs your Sheckles and buys if affordable.",
    Callback = function(v) Cfg.AutoBuyPet = v notify("Auto Buy Affordable Pets", v and "ON" or "OFF") end
})
petBox:AddSlider("PetBuyMaxPrice", {
    Text = "Max price to spend", Default = 500, Min = 0, Max = 50000, Rounding = 0,
    Callback = function(v) Cfg.PetBuyMaxPrice = v end
})
petBox:AddButton({ Text = "Buy Pets Now", Func = function() task.spawn(buyAffordablePets) notify("Buy Pets Now", "done") end })
petBox:AddDivider({ Text = "Open" })
petBox:AddButton({ Text = "Tame Wild Pets Now",  Func = function() task.spawn(tameWild) notify("Tame Wild Pets Now", "done") end })
petBox:AddButton({ Text = "Open All Eggs",        Func = function() openAll("Egg") notify("Open All Eggs", "done") end })
petBox:AddButton({ Text = "Open All Seed Packs",  Func = function() openAll("SeedPack") notify("Open All Seed Packs", "done") end })
petBox:AddButton({ Text = "Open All Crates",      Func = function() openAll("Crate") notify("Open All Crates", "done") end })
petBox:AddDivider({ Text = "Equip" })
petBox:AddDropdown("PetToEquip", { Text = "Equip pet by name", Values = {}, Default = "", Callback = function() end })
petBox:AddButton({ Text = "Equip Selected Pet", Func = function()
    local n = Options.PetToEquip and Options.PetToEquip.Value or ""
if n ~= "" then pcall(function() Networking.Pets.RequestEquipByName:Fire(n) end) end
notify("Equip Selected Pet", "done") end })

local codeBox = Tabs.Extra:AddLeftGroupbox("Codes & Actions", "ticket")
codeBox:AddInput("RedeemCode", { Text = "Promo Code", Default = "", Placeholder = "enter a code", Callback = function(v) Cfg.RedeemCode = v end })
codeBox:AddButton({ Text = "Redeem Code", Func = function()
    if Cfg.RedeemCode ~= "" then
        task.spawn(function() pcall(function() return Networking.Settings.SubmitCode:Fire(Cfg.RedeemCode) end) end)
        notify("GAG2", "Redeeming: " .. Cfg.RedeemCode)
    end
end })
codeBox:AddDivider({ Text = "Skill Points" })
codeBox:AddToggle("AutoSkill", { Text = "Auto Spend Skill Points", Default = false, Callback = function(v) Cfg.AutoSkill = v notify("Auto Spend Skill Points", v and "ON" or "OFF") end })
codeBox:AddInput("SkillId", { Text = "Skill ID", Default = "", Placeholder = "skill name or id", Callback = function(v) Cfg.SkillId = v end })
codeBox:AddButton({ Text = "Request Skill Data", Func = function()
    task.spawn(function()
        local ok, d = pcall(function() return Networking.SkillPoints.RequestSkillData:Fire() end)
        notify("Skills", ok and "Done — check console." or "Failed.")
    end)
end })

-- Mutation Scanner
local mutBox = Tabs.Extra:AddRightGroupbox("Mutation Scanner", "microscope")
mutBox:AddLabel({ Text = "Scans all tracked fruits for mutations.", DoesWrap = true })
mutBox:AddButton({ Text = "Scan Mutations Now", Func = function()
    local found = 0
    for fid, fd in pairs(fruitData) do
        if fd.mutated then
            found = found + 1
            print("[MUTATION] Fruit:", fid, "Name:", fd.name, "Plant:", fd.plantId)
        end
    end
    notify("Scanner", found > 0 and ("Found " .. found .. " mutated fruits!") or "No mutations found.")
end })
mutBox:AddButton({ Text = "Harvest Only Mutated", Func = function()
    task.spawn(function()
        for fid, fd in pairs(fruitData) do
            if fd.mutated and fd.grown then
                pcall(function() Networking.Garden.CollectFruit:Fire(fd.plantId, fid) end)
                task.wait(0.05)
            end
        end
        notify("Harvest", "Mutated fruits collected.")
    end)
end })

-- ════════════════════════════════════════════════════════════════════════════
--  ESP TAB
-- ════════════════════════════════════════════════════════════════════════════
local espPlayerBox = Tabs.ESP:AddLeftGroupbox("Player ESP", "users")
espPlayerBox:AddToggle("ESPPlayers", { Text = "Player ESP (name+distance)", Default = false, Callback = function(v) Cfg.ESPPlayers = v; if not v then clearESP("player") end notify("Player ESP (name+distance)", v and "ON" or "OFF") end })

local espFruitBox = Tabs.ESP:AddRightGroupbox("Fruit ESP", "apple")
espFruitBox:AddToggle("ESPFruits", { Text = "Fruit ESP (grown only)", Default = false, Callback = function(v) Cfg.ESPFruits = v; if not v then clearESP("fruit") end notify("Fruit ESP (grown only)", v and "ON" or "OFF") end })

local espPetBox = Tabs.ESP:AddLeftGroupbox("Pet ESP", "paw-print")
espPetBox:AddToggle("ESPPets", { Text = "Wild Pet ESP", Default = false, Callback = function(v) Cfg.ESPPets = v; if not v then clearESP("pet") end notify("Wild Pet ESP", v and "ON" or "OFF") end })

-- ════════════════════════════════════════════════════════════════════════════
--  WEATHER TAB
-- ════════════════════════════════════════════════════════════════════════════
local wBox = Tabs.Weather:AddLeftGroupbox("Weather Alerts", "cloud")
wBox:AddLabel({ Text = "Get notified when special weather events start (affects growth & stealing).", DoesWrap = true })
wBox:AddToggle("AlertRain",       { Text = "Alert: Rain",       Default = true,  Callback = function(v) Cfg.AlertRain      = v notify("Alert: Rain", v and "ON" or "OFF") end })
wBox:AddToggle("AlertNight",      { Text = "Alert: Night",      Default = true,  Callback = function(v) Cfg.AlertNight     = v notify("Alert: Night", v and "ON" or "OFF") end })
wBox:AddToggle("AlertBloodmoon",  { Text = "Alert: Bloodmoon",  Default = true,  Callback = function(v) Cfg.AlertBloodmoon = v notify("Alert: Bloodmoon", v and "ON" or "OFF") end })
wBox:AddToggle("AlertBlizzard",   { Text = "Alert: Blizzard",   Default = true,  Callback = function(v) Cfg.AlertBlizzard  = v notify("Alert: Blizzard", v and "ON" or "OFF") end })
wBox:AddToggle("AlertLightning",  { Text = "Alert: Lightning",  Default = true,  Callback = function(v) Cfg.AlertLightning = v notify("Alert: Lightning", v and "ON" or "OFF") end })
wBox:AddToggle("AlertRainbow",    { Text = "Alert: Rainbow",    Default = true,  Callback = function(v) Cfg.AlertRainbow   = v notify("Alert: Rainbow", v and "ON" or "OFF") end })

local wBox2 = Tabs.Weather:AddRightGroupbox("Current State", "moon")
wBox2:AddLabel({ Text = "Steal is only possible during Night.", DoesWrap = true })
local isNightLabel = wBox2:AddLabel({ Text = "Night: unknown" })
local function updateNightLabel()
    local Night = ReplicatedStorage:FindFirstChild("Night")
    local v = Night and Night.Value
    if isNightLabel then
        isNightLabel:SetText(v and " Night: YES (steal enabled)" or " Night: NO (steal disabled)")
    end
end

-- Hook all weather events
if Networking then
    pcall(function()
        local function hookWeather(remote, label, icon)
            Networking.WeatherEffects[remote]:Connect(function()
                if Cfg["Alert"..remote:gsub("Start",""):gsub("End","")] then
                    notify("Weather ", icon .. " " .. label .. "!")
                end
                if remote == "NightStart" then updateNightLabel() end
                if remote == "NightEnd" then updateNightLabel() end
            end)
        end
        hookWeather("RainStart",      "Rain started",      "")
        hookWeather("RainEnd",        "Rain ended",        "")
        hookWeather("NightStart",     "Night started",     "")
        hookWeather("NightEnd",       "Night ended",       "")
        hookWeather("BloodmoonStart", "Bloodmoon started", "")
        hookWeather("BloodmoonEnd",   "Bloodmoon ended",   "")
        hookWeather("BlizzardStart",  "Blizzard started",  "")
        hookWeather("BlizzardEnd",    "Blizzard ended",    "")
        hookWeather("LightningStart", "Lightning storm",   "")
        hookWeather("LightningEnd",   "Lightning ended",   "")
        hookWeather("RainbowStart",   "Rainbow started",   "")
        hookWeather("RainbowEnd",     "Rainbow ended",     "")
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
--  MISC TAB
-- ════════════════════════════════════════════════════════════════════════════
local mBox = Tabs.Misc:AddLeftGroupbox("Server", "globe")
mBox:AddToggle("AntiAFK", { Text = "Anti-AFK", Default = false, Callback = function(v) Cfg.AntiAFK = v notify("Anti-AFK", v and "ON" or "OFF") end })
mBox:AddToggle("LowGraphics", { Text = "Low Graphics (reduce lag)", Default = false, Callback = function(v)
    Cfg.LowGraphics = v
    pcall(function()
        game:GetService("Lighting").GlobalShadows = not v
        settings().Rendering.QualityLevel = v and 1 or 21
    end)
notify("Low Graphics (reduce lag)", v and "ON" or "OFF") end })
mBox:AddButton({ Text = "Rejoin Server", Func = function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
notify("Rejoin Server", "done") end })
mBox:AddButton({ Text = "Server Hop (find best)", Func = function() task.spawn(serverHop) notify("Server Hop (find best)", "done") end })
mBox:AddButton({ Text = "Copy My Plot Name", Func = function()
    local name = Plot and Plot.Name or "No plot found"
pcall(function() setclipboard(name) end)
    notify("Plot", "Copied: " .. name)
end })
mBox:AddButton({ Text = "Print Stats to Console", Func = function()
    print("[GAG2] Sheckles:", sheckles())
    print("[GAG2] Plants tracked:", (function() local n=0; for _ in pairs(plantData) do n=n+1 end; return n end)())
    print("[GAG2] Fruits tracked:", (function() local n=0; for _ in pairs(fruitData) do n=n+1 end; return n end)())
    print("[GAG2] Plot:", Plot and Plot.Name or "none")
notify("Print Stats to Console", "done") end })

-- ════════════════════════════════════════════════════════════════════════════
--  CORE ACTION FUNCTIONS
-- ════════════════════════════════════════════════════════════════════════════

--  Harvest — uses direct remote if tracking data available, falls back to proximity
function harvestAll()
    local used = 0
    -- Method 1: direct remote via live-synced plantData (no proximity check)
    for fid, fd in pairs(fruitData) do
        if fd.grown then
            pcall(function() Networking.Garden.CollectFruit:Fire(fd.plantId, fid) end)
            used = used + 1
            task.wait(jitter(0.05, 0.015))
        end
    end
    -- Method 2: fallback - fire all CollectionService-tagged HarvestPrompts
    if used == 0 then
        for _, p in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
            if p:IsA("ProximityPrompt") then
                pcall(function() fireproximityprompt(p) end)
            end
        end
    end
end

--  Water the whole plot via direct remote
function waterPlot()
    if not Plot then return end
    local ref = Plot:FindFirstChild("PlotSizeReference")
    if not ref or not ref:IsA("BasePart") then return end
    local cf, sz = ref.CFrame, ref.Size
    local topY = ref.Position.Y + sz.Y / 2 + 0.5
    -- Spray 5×5 grid of positions
    for r = 1, 5 do
        for c = 1, 5 do
            local fx = (r / 6 - 0.5) * sz.X * 0.85
            local fz = (c / 6 - 0.5) * sz.Z * 0.85
            local world = cf * CFrame.new(fx, 0, fz)
            local pos = Vector3.new(world.X, topY, world.Z)
            pcall(function() Networking.WateringCan.UseWateringCan:Fire(pos - Vector3.new(0, 0.3, 0), "Watering Can", 1) end)
            task.wait(0.04)
        end
    end
end

--  Plant grid
function plantGrid()
    if not Plot then return end
    local ref = Plot:FindFirstChild("PlotSizeReference")
    if not ref or not ref:IsA("BasePart") then return end
    local cf, sz = ref.CFrame, ref.Size
    local rows, cols = math.floor(Cfg.PlantRows), math.floor(Cfg.PlantCols)
    local topY = ref.Position.Y + sz.Y / 2 + 1
    for r = 1, rows do
        for c = 1, cols do
            local fx = (r / (rows + 1) - 0.5) * sz.X * 0.9
            local fz = (c / (cols + 1) - 0.5) * sz.Z * 0.9
            local world = cf * CFrame.new(fx, 0, fz)
            local pos = Vector3.new(world.X, topY, world.Z)
            pcall(function() Networking.Plant.PlantSeed:Fire(pos, Cfg.PlantSeed, Plot) end)
            task.wait(jitter(0.06, 0.01))
        end
    end
end

--  Sprinkler placement
function placeSprinklers()
    if not Plot then return end
    local ref = Plot:FindFirstChild("PlotSizeReference")
    if not ref or not ref:IsA("BasePart") then return end
    local cf, sz = ref.CFrame, ref.Size
    for r = 1, 3 do
        for c = 1, 3 do
            local world = cf * CFrame.new((r / 4 - 0.5) * sz.X * 0.8, 0, (c / 4 - 0.5) * sz.Z * 0.8)
            local pos = Vector3.new(world.X, ref.Position.Y + sz.Y / 2 + 1, world.Z)
            pcall(function() Networking.Place.PlaceSprinkler:Fire(pos, Cfg.SprinklerName, Plot, 1) end)
            task.wait(0.1)
        end
    end
end

-- Auto Buy Pet: scans wild pet spawns, checks Price attribute vs player's sheckles
function buyAffordablePets()
    -- Wild pets live in Workspace.Map.WildPetSpawns (from SpawnPetController decompile)
    local function getSheckleValue()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        local s = ls and ls:FindFirstChild("Sheckles")
        return s and s.Value or 0
    end

    local function tryBuyPet(petModel)
        -- Fire the WildPetTame remote — server checks sheckles and deducts price
        local ok = pcall(function() Networking.Pets.WildPetTame:Fire(petModel) end)
        return ok
    end

    -- Scan workspace for wild pet models with a Price attribute
    local map = Workspace:FindFirstChild("Map")
    local spawnsFolder = map and map:FindFirstChild("WildPetSpawns")
    local money = getSheckleValue()

    local bought = 0
    local function scanFolder(folder)
        if not folder then return end
        for _, child in ipairs(folder:GetChildren()) do
            -- Each wild pet spawn is a Model with a RefPart BasePart that has a Price attribute
            if child:IsA("Model") then
                local refPart = child:FindFirstChild("HumanoidRootPart") or child:FindFirstChildWhichIsA("BasePart")
                if refPart then
                    local price = refPart:GetAttribute("Price")
                    local owner = refPart:GetAttribute("OwnerUserId")
                    -- Only buy pets with no owner (price > 0 means it's for sale)
                    if type(price) == "number" and price > 0 and price <= Cfg.PetBuyMaxPrice then
                        if (not owner or owner == 0) and money >= price then
                            if tryBuyPet(child) then
                                bought = bought + 1
                                money = money - price  -- optimistically subtract
                                task.wait(0.3)
                            end
                        end
                    end
                end
            end
        end
    end

    scanFolder(spawnsFolder)
    -- Also scan Temporary folder (pets sometimes placed there)
    scanFolder(Workspace:FindFirstChild("Temporary"))
    -- Also try tagged wild pets
    for _, tag in ipairs({"WildPet", "WildPetModel"}) do
        for _, obj in ipairs(CollectionService:GetTagged(tag)) do
            if obj:IsA("Model") then
                local refPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                if refPart then
                    local price = refPart:GetAttribute("Price")
                    local owner = refPart:GetAttribute("OwnerUserId")
                    if type(price) == "number" and price > 0 and price <= Cfg.PetBuyMaxPrice then
                        if (not owner or owner == 0) and money >= price then
                            if tryBuyPet(obj) then
                                bought = bought + 1
                                money = money - price
                                task.wait(0.3)
                            end
                        end
                    end
                end
            end
        end
    end

    if bought > 0 then
        notify("Auto Buy Pet", "Purchased " .. bought .. " pet(s)!")
    end
end

-- Steal
function stealAll()
    local myRoot = root()
    local Night = ReplicatedStorage:FindFirstChild("Night")
    if Night and not Night.Value then
        notify("Steal", "Can only steal at Night!"); return
    end
    for _, p in ipairs(CollectionService:GetTagged("StealPrompt")) do
        if p:IsA("ProximityPrompt") then
            if Cfg.StealTP and myRoot then
                local part = p.Parent
                if part and part:IsA("BasePart") then
                    pcall(function() myRoot.CFrame = part.CFrame * CFrame.new(0, 2, 2) end)
                    task.wait(0.06)
                end
            end
            pcall(function() fireproximityprompt(p) end)
            task.wait(jitter(0.3, 0.05))
        end
    end
end

--  Tame wild pets (fire the wild pet instance directly)
function tameWild()
    local Tags = { "TamePrompt", "WildPetPrompt", "PetPrompt", "WildPet" }
    for _, tag in ipairs(Tags) do
        for _, p in ipairs(CollectionService:GetTagged(tag)) do
            if p:IsA("ProximityPrompt") then
                pcall(function() fireproximityprompt(p) end)
                task.wait(jitter(0.2, 0.04))
            elseif p:IsA("Model") or p:IsA("BasePart") then
                -- Try direct remote with the pet model as argument
                pcall(function() Networking.Pets.WildPetTame:Fire(p) end)
                task.wait(jitter(0.2, 0.04))
            end
        end
    end
end

--  Open eggs/packs/crates
function openAll(kind)
    local packet = (kind == "Egg" and Networking.Egg.OpenEgg)
        or (kind == "SeedPack" and Networking.SeedPack.OpenSeedPack)
        or Networking.Crate.OpenCrate
    task.spawn(function()
        local areas = { LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack"), Plot }
        for _, area in ipairs(areas) do
            if area then
                for _, d in ipairs(area:GetDescendants()) do
                    if d.Name:find(kind) then
                        local id = d:GetAttribute("Id") or d:GetAttribute("UUID") or d:GetAttribute("Uid")
                            or d:GetAttribute("EggId") or d:GetAttribute("ItemId")
                        if id then pcall(function() packet:Fire(id) end) task.wait(0.2) end
                    end
                end
            end
        end
    end)
end

--  Claim mail
function claimMail()
    task.spawn(function()
        local ok, inbox = pcall(function() return Networking.Mailbox.OpenInbox:Fire() end)
        if not ok or type(inbox) ~= "table" then return end
        local list = inbox.mails or inbox.Mails or inbox.items or inbox.Items or inbox
        for _, m in pairs(list) do
            if type(m) == "table" then
                local id = m.Id or m.id or m.MailId or m.mailId or m.uid or m.Uid
                if id then pcall(function() Networking.Mailbox.Claim:Fire(id) end) task.wait(0.2) end
            elseif type(m) == "string" then
                pcall(function() Networking.Mailbox.Claim:Fire(m) end) task.wait(0.2)
            end
        end
    end)
end

--  Bid watcher
function checkBid()
    task.spawn(function()
        local ok, bids = pcall(function() return Networking.NPCS.AskBidAll:Fire() end)
        if ok and type(bids) == "table" then
            local best, bestVal = nil, 0
            for fruitName, val in pairs(bids) do
                if type(val) == "number" and val > bestVal then best, bestVal = fruitName, val end
            end
            if best then
                notify("Best Bid", best .. ": " .. bestVal .. " sheckles")
                if Cfg.AutoBid then
                    pcall(function() Networking.NPCS.SellFruit:Fire(best) end)
                end
            end
        end
    end)
end

--  Server hop
function serverHop()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
        )
    end)
    if ok and data and data.data then
        local best = nil
        for _, s in ipairs(data.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                if not best or s.playing < best.playing then best = s end
            end
        end
        if best then
            notify("Server Hop", "Hopping to server with " .. best.playing .. " players.")
            pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, LocalPlayer) end)
        else
            notify("Server Hop", "No better server found.")
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  ESP SYSTEM
-- ════════════════════════════════════════════════════════════════════════════
local espObjects = { player = {}, fruit = {}, pet = {} }

local function makeESPBillboard(parent, text, color)
    local bb = Instance.new("BillboardGui")
    bb.Name = "GAG2_ESP"
bb.Adornee = parent
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 200, 0, 30)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.5
    lbl.Text = text
    lbl.Parent = bb
    return bb, lbl
end

function clearESP(kind)
    for _, v in ipairs(espObjects[kind] or {}) do pcall(function() v:Destroy() end) end
    espObjects[kind] = {}
end

task.spawn(function()
    while task.wait(1) do
        -- Player ESP
        if Cfg.ESPPlayers then
            clearESP("player")
            local myPos = root() and root().Position or Vector3.zero
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer and pl.Character then
                    local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local dist = math.floor((hrp.Position - myPos).Magnitude)
                        local bb, lbl = makeESPBillboard(hrp, pl.Name .. " [" .. dist .. "m]", Color3.fromRGB(255, 100, 100))
                        table.insert(espObjects.player, bb)
                    end
                end
            end
        end
        -- Fruit ESP
        if Cfg.ESPFruits then
            clearESP("fruit")
            for fid, fd in pairs(fruitData) do
                if fd.grown then
                    -- Find a part tagged with this fruitId to adorn
                    local found = false
                    for _, p in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
                        local attr = p:GetAttribute("FruitId") or p:GetAttribute("Id")
                        if tostring(attr) == tostring(fid) and p.Parent and p.Parent:IsA("BasePart") then
                            local bb = makeESPBillboard(p.Parent, " " .. (fd.name or "Fruit") .. (fd.mutated and " []" or ""), Color3.fromRGB(100, 255, 100))
                            table.insert(espObjects.fruit, bb)
                            found = true; break
                        end
                    end
                end
            end
        end
        -- Pet ESP
        if Cfg.ESPPets then
            clearESP("pet")
            for _, tag in ipairs({"WildPet","WildPetModel"}) do
                for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                    local part = obj:IsA("BasePart") and obj or (obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart"))
                    if part then
                        local bb = makeESPBillboard(part, " Wild Pet!", Color3.fromRGB(255, 200, 50))
                        table.insert(espObjects.pet, bb)
                    end
                end
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
--  MAIN LOOPS (anti-detection: jittered delays, isolated task.spawns)
-- ════════════════════════════════════════════════════════════════════════════

task.spawn(function()  -- AUTO HARVEST (fastest possible)
    while not _DEAD do
        if Cfg.AutoHarvest then pcall(harvestAll) end
        task.wait(Cfg.AutoHarvest and math.max(0.05, Cfg.HarvestDelay) or 1)
    end
end)

task.spawn(function()  -- AUTO SELL
    while not _DEAD do
        if Cfg.AutoSell then pcall(function() return Networking.NPCS.SellAll:Fire() end) end
        task.wait(Cfg.AutoSell and math.max(1, Cfg.SellDelay) or 5)
    end
end)

task.spawn(function()  -- AUTO PLANT
    while not _DEAD do
        if Cfg.AutoPlant then pcall(plantGrid) end
        task.wait(Cfg.AutoPlant and math.max(0.5, Cfg.PlantDelay + 1) or 3)
    end
end)

task.spawn(function()  -- AUTO WATER
    while not _DEAD do
        if Cfg.AutoWater then pcall(waterPlot) end
        task.wait(Cfg.AutoWater and math.max(0.5, Cfg.WaterDelay) or 5)
    end
end)

task.spawn(function()  -- AUTO BUY (hammers remote every BuyDelay)
    while not _DEAD do
        if Cfg.AutoBuyAll then
            for _, s in ipairs(Seeds) do
                pcall(function() Networking.SeedShop.PurchaseSeed:Fire(s) end)
                task.wait(0.03)
            end
        elseif Cfg.AutoBuy then
            pcall(function() Networking.SeedShop.PurchaseSeed:Fire(Cfg.BuySeed) end)
        end
        task.wait((Cfg.AutoBuy or Cfg.AutoBuyAll) and math.max(0.1, Cfg.BuyDelay) or 3)
    end
end)

task.spawn(function()  -- AUTO BUY PET
    while not _DEAD do
        if Cfg.AutoBuyPet then pcall(buyAffordablePets) end
        task.wait(Cfg.AutoBuyPet and 2 or 5)
    end
end)

task.spawn(function()  -- AUTO SPRINKLERS
    while not _DEAD do
        if Cfg.AutoSprinkler then pcall(placeSprinklers) end
        task.wait(Cfg.AutoSprinkler and jitter(20, 3) or 10)
    end
end)

local dealBusy = false
task.spawn(function()  -- AUTO DAILY DEAL
    while not _DEAD do
        if Cfg.AutoDailyDeal and not dealBusy then
            dealBusy = true
            task.spawn(function()
                pcall(function() return Networking.NPCS.UseDailyDealAll:Fire() end)
                task.wait(jitter(30, 5)); dealBusy = false
            end)
        end
        task.wait(30)
    end
end)

task.spawn(function()  -- AUTO MAIL
    while not _DEAD do
        if Cfg.AutoMail then pcall(claimMail) end
        task.wait(jitter(45, 8))
    end
end)

task.spawn(function()  -- AUTO STEAL
    while not _DEAD do
        if Cfg.AutoSteal then pcall(stealAll) end
        task.wait(Cfg.AutoSteal and jitter(1.5, 0.3) or 3)
    end
end)

task.spawn(function()  -- AUTO TAME
    while not _DEAD do
        if Cfg.AutoTame then pcall(tameWild) end
        task.wait(Cfg.AutoTame and jitter(2, 0.4) or 4)
    end
end)

task.spawn(function()  -- AUTO BID
    while not _DEAD do
        if Cfg.AutoBid then pcall(checkBid) end
        task.wait(jitter(60, 10))
    end
end)

task.spawn(function()  -- AUTO SKILL
    while not _DEAD do
        if Cfg.AutoSkill and Cfg.SkillId ~= "" then
            pcall(function() Networking.SkillPoints.SpendSkillPoint:Fire(Cfg.SkillId) end)
        end
        task.wait(jitter(5, 1))
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
--  CHARACTER SYSTEMS
-- ════════════════════════════════════════════════════════════════════════════

RunService.Stepped:Connect(function()
    if Cfg.Noclip then
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end
end)

UIS.JumpRequest:Connect(function()
    if Cfg.InfJump then local h = hum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)

task.spawn(function()  -- FLY
    local bv
    while task.wait() do
        local r = root()
        if Cfg.Fly and r then
            if not bv then
                bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                bv.Parent = r
            end
            local cam, dir = Workspace.CurrentCamera, Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W)          then dir += cam.CFrame.LookVector  end
            if UIS:IsKeyDown(Enum.KeyCode.S)          then dir -= cam.CFrame.LookVector  end
            if UIS:IsKeyDown(Enum.KeyCode.A)          then dir -= cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D)          then dir += cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space)      then dir += Vector3.new(0, 1, 0)   end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift)  then dir -= Vector3.new(0, 1, 0)   end
            bv.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * Cfg.FlySpeed
        elseif bv then bv:Destroy(); bv = nil end
    end
end)

LocalPlayer.Idled:Connect(function()
    if Cfg.AntiAFK then
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end
end)

LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(0.6)
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then
        h.WalkSpeed = Cfg.WalkSpeed
        h.UseJumpPower = true
        h.JumpPower = Cfg.JumpPower
    end
    -- Re-cache plot in case of respawn
    task.wait(1)
    Plot = getPlot()
end)

-- ════════════════════════════════════════════════════════════════════════════
--  HUD KEYBINDS + UPDATE LOOP
-- ════════════════════════════════════════════════════════════════════════════
kb:Bind("harvest", "Auto Harvest", Enum.KeyCode.G, function(a) Cfg.AutoHarvest = a; pcall(function() Toggles.AutoHarvest:SetValue(a) end) end)
kb:Bind("sell",    "Auto Sell",    Enum.KeyCode.H, function(a) Cfg.AutoSell = a;    pcall(function() Toggles.AutoSell:SetValue(a) end) end)
kb:Bind("plant",   "Auto Plant",   Enum.KeyCode.J, function(a) Cfg.AutoPlant = a;   pcall(function() Toggles.AutoPlant:SetValue(a) end) end)

task.spawn(function()
    while not _DEAD do
        pcall(function()
            panel:Set("sheckles", "Sheckles: " .. sheckles())
            panel:Set("players", ("Players: %d"):format(#Players:GetPlayers()))
            panel:Set("fps", ("FPS: %d"):format(math.floor(Y2k.fps())))
            kb:Set("harvest", Cfg.AutoHarvest); kb:Set("sell", Cfg.AutoSell); kb:Set("plant", Cfg.AutoPlant)
        end)
        task.wait(0.4)
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
--  SETTINGS (SaveManager / ThemeManager)
-- ════════════════════════════════════════════════════════════════════════════
Y2k.modulesGroup(Tabs.Settings, { panel = panel, wm = wm, kb = kb })
local function fullUnload()
    _DEAD = true
    for k, v in pairs(Cfg) do if type(v) == "boolean" then Cfg[k] = false end end
    pcall(function() Y2k.release("Grow a Garden 2") end)
    pcall(function() panel:Destroy() end); pcall(function() wm:Destroy() end); pcall(function() kb:Destroy() end)
end
pcall(function() Library:OnUnload(fullUnload) end)
pcall(function() if Y2k.setUnload then Y2k.setUnload("Grow a Garden 2", fullUnload) end end)
pcall(function()
    SaveManager:SetLibrary(Library)
    ThemeManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetFolder("Y2kScript/GAG2-v3")
    ThemeManager:SetFolder("Y2kScript/GAG2-v3")
    ThemeManager:ApplyToTab(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
    SaveManager:LoadAutoloadConfig()
end)

-- ════════════════════════════════════════════════════════════════════════════
--  STARTUP
-- ════════════════════════════════════════════════════════════════════════════
updateNightLabel()
notify(
    "GAG2 Hub v3 — LOADED",
    "Plot: " .. (Plot and Plot.Name or "?") .. " | Sheckles: " .. sheckles()
)
