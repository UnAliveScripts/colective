-- == UnAlive UI [STANDALONE] ==
-- Full GUI organized for Farm / Shop / Steal / Config / Settings tabs.
-- Requires MacLib. Load after all feature scripts.

local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/dvorfkar6-lab/uis/refs/heads/main/Mac"))()
if not MacLib then return error("Failed to load MacLib") end

local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local HttpService = game:GetService("HttpService"); local LP = Players.LocalPlayer
local Net; do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
if not Net then return error("Networking module not found") end
local _rep; local function rep() if _rep then return _rep end; local ok, psc = pcall(require, RS.ClientModules.PlayerStateClient); if ok and psc and psc.WaitForLocalReplica then local ok2, r = pcall(psc.WaitForLocalReplica, psc, 30); if ok2 and r then _rep = r end end; return _rep end
local function pd() local r = rep(); return (r and r.Data) or {} end
local function getSh() return tonumber(pd().Sheckles) or 0 end; local function getTk() return tonumber(pd().Tokens) or 0 end
local function fmt(n) n = tonumber(n) or 0; if n >= 1e12 then return ("%.2fT"):format(n / 1e12) elseif n >= 1e9 then return ("%.2fB"):format(n / 1e9) elseif n >= 1e6 then return ("%.2fM"):format(n / 1e6) elseif n >= 1e3 then return ("%.2fK"):format(n / 1e3) else return tostring(math.floor(n)) end end
local function fire(p, ...) local a = (function(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end)(p); if not (a and a.Fire) then return false end; local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
local function pickMulti(sel, into) for k in pairs(into) do into[k] = nil end; if type(sel) == "table" then for k, v in pairs(sel) do if v == true then into[k] = true elseif type(v) == "string" then into[v] = true end end end end

-- Catalogs
local function seedCat() local out = {}; local ok, data = pcall(require, RS.SharedModules.SeedData); if ok and type(data) == "table" then for _, e in pairs(data) do if type(e) == "table" and e.SeedName and e.PurchasePrice then out[#out + 1] = e.SeedName end end end; if #out == 0 then for _, n in ipairs({"Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple", "Bamboo", "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean", "Banana", "Grape", "Coconut", "Mango", "Dragon Fruit", "Acorn", "Cherry", "Sunflower", "Venus Fly Trap", "Pomegranate", "Poison Apple", "Moon Bloom", "Dragon's Breath", "Ghost Pepper", "Poison Ivy"}) do out[#out + 1] = n end end; table.sort(out); return out end
local function gearCat() local out, seen = {}, {}; local ok, data = pcall(require, RS.SharedModules.GearShopData); if ok and data and type(data.Data) == "table" then for _, e in pairs(data.Data) do if type(e) == "table" and e.ItemName and not e.RobuxOnly and not seen[e.ItemName] then seen[e.ItemName] = true; out[#out + 1] = e.ItemName end end end; if #out == 0 then local ok2, items = pcall(function() return RS.StockValues.GearShop.Items end); if ok2 and items then for _, c in ipairs(items:GetChildren()) do out[#out + 1] = c.Name end end end; table.sort(out); return out end
local SEEDS = seedCat(); local GEAR = gearCat()
local function myPlot() local id = LP:GetAttribute("PlotId"); local g = WS:FindFirstChild("Gardens"); if not (id and g) then return nil end; return g:FindFirstChild("Plot" .. tostring(id)) end
local function petNames() local names, seen = {}, {}; local function inv(c) local i = pd().Inventory; return (i and i[c]) or {} end; local function invNames(c) local out = {}; for k, v in pairs(inv(c)) do local nm, ct; if type(v) == "table" then nm = v.Name or v.ItemName or v.Type or (type(k) == "string" and k) or tostring(k); ct = tonumber(v.Count) or tonumber(v.Amount) or 1 elseif type(v) == "number" then nm, ct = tostring(k), v else nm, ct = tostring(k), 1 end; if nm then out[nm] = (out[nm] or 0) + (ct or 1) end end; return out end; for nm in pairs(invNames("Pets")) do if not seen[nm] then seen[nm] = true; names[#names + 1] = nm end end; table.sort(names); return names end

-- Global state (links to standalone script globals)
S = { killed = false, autoFarm = false, autoBuy = false, buySeeds = {}, buyInterval = 5, buyPerTick = 8, autoPlant = false, plantSpacing = 4, plantSeed = "Best owned", autoHarvest = false, harvestDelay = 0.01, autoSell = false, sellInterval = 15, autoExpand = false, autoDaily = false, autoPot = false, autoSprinkler = false, sprinklerInterval = 30, autoWater = false, waterInterval = 8, autoSkill = false, skillStats = {}, autoEquipPets = false, autoPetSlot = false, autoBuyPets = false, maxPetPrice = 25000, petTeleport = true, petBuyInterval = 5, autoSellPets = false, sellPets = {}, autoEgg = false, autoCrate = false, autoPack = false, openInterval = 4, autoGear = false, gearBuy = {}, gearInterval = 10, autoSteal = false, stealTeleport = true, stealReturnBase = true, stealDelay = 0.05, autoMail = false, autoAcceptGift = false, autoHop = false, hopInterval = 0, autoCodes = false, antiAfk = true, fpsBoost = false, webhookEnabled = false, webhookInterval = 300 }
Stats = { bought = 0, planted = 0, harvested = 0, sold = 0, earned = 0, sprinklers = 0, watered = 0, tamed = 0, opened = 0, stolen = 0, codes = 0, startAt = os.clock() }

local function sync(name, global) return function(v) S[name] = v; if global then _G[global] = v end end end

local Window = MacLib:Window({ Title = "UnAlive Hub | Grow a Garden 2", Subtitle = "full auto", Size = UDim2.fromOffset(860, 620), DragStyle = 2, DisabledWindowControls = {}, ShowUserInfo = false, Keybind = Enum.KeyCode.LeftControl, AcrylicBlur = false })
local tg = Window:TabGroup()
local T = {}
T.Farm     = tg:Tab({ Name = "Farm",     Image = "rbxassetid://10723407389" })
T.Shop     = tg:Tab({ Name = "Shop",     Image = "rbxassetid://10734897102" })
T.Steal    = tg:Tab({ Name = "Steal",    Image = "rbxassetid://10747384394" })
T.Config   = tg:Tab({ Name = "Config",   Image = "rbxassetid://10723345756" })
T.Settings = tg:Tab({ Name = "Settings", Image = "rbxassetid://10734950309" })

-- ═══ FARM TAB ═══
local s1 = T.Farm:Section({ Side = "Left" }); s1:Header({ Text = "Status" })
local pl = s1:Label({ Text = "Plot: …" }); local cl = s1:Label({ Text = "Sheckles: …" }); local sl = s1:Label({ Text = "—" })

local s2 = T.Farm:Section({ Side = "Left" }); s2:Header({ Text = "Farm Controls" })
s2:Toggle({ Name = "Auto-Farm (master)", Default = false, Callback = sync("autoFarm", "autoFarm") }, "AutoFarm")
s2:Toggle({ Name = "Auto-Expand", Default = false, Callback = sync("autoExpand", "autoExpand") }, "AutoExpand")
s2:Toggle({ Name = "Auto-Daily", Default = false, Callback = sync("autoDaily", "autoDaily") }, "AutoDaily")
s2:Toggle({ Name = "Auto-Pot", Default = false, Callback = sync("autoPot", "autoPot") }, "AutoPot")

local s3 = T.Farm:Section({ Side = "Right" }); s3:Header({ Text = "Planting" })
local opts = { "Best owned" }; for _, n in ipairs(SEEDS) do opts[#opts + 1] = n end
s3:Dropdown({ Name = "Seed to plant", Options = opts, Default = "Best owned", Callback = function(v) S.plantSeed = v end }, "PlantSeed")
s3:Toggle({ Name = "Auto-Plant", Default = false, Callback = sync("autoPlant", "autoPlant") }, "AutoPlant")
s3:Slider({ Name = "Spacing (studs)", Default = 4, Min = 2, Max = 10, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.plantSpacing = v end }, "PlantSpacing")

local s4 = T.Farm:Section({ Side = "Right" }); s4:Header({ Text = "Harvest & Sell" })
s4:Toggle({ Name = "Auto-Harvest", Default = false, Callback = sync("autoHarvest", "autoHarvest") }, "AutoHarvest")
s4:Slider({ Name = "Harvest pace (s)", Default = 0.01, Min = 0, Max = 0.2, DisplayMethod = "Value", Precision = 3, Callback = function(v) S.harvestDelay = v end }, "HarvestDelay")
s4:Toggle({ Name = "Auto-Sell", Default = false, Callback = sync("autoSell", "autoSell") }, "AutoSell")
s4:Slider({ Name = "Sell interval (s)", Default = 15, Min = 3, Max = 120, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.sellInterval = v end }, "SellInterval")

local s5 = T.Farm:Section({ Side = "Right" }); s5:Header({ Text = "Sprinklers & Water" })
s5:Toggle({ Name = "Auto-Sprinkler", Default = false, Callback = sync("autoSprinkler", "autoSprinkler") }, "AutoSprinkler")
s5:Slider({ Name = "Interval (s)", Default = 30, Min = 10, Max = 120, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.sprinklerInterval = v end }, "SprinklerInterval")
s5:Toggle({ Name = "Auto-Water", Default = false, Callback = sync("autoWater", "autoWater") }, "AutoWater")
s5:Slider({ Name = "Interval (s)", Default = 8, Min = 2, Max = 60, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.waterInterval = v end }, "WaterInterval")

local s6 = T.Farm:Section({ Side = "Right" }); s6:Header({ Text = "Pets & Opening" })
s6:Toggle({ Name = "Auto-Equip Pets", Default = false, Callback = sync("autoEquipPets", "autoEquipPets") }, "AutoEquipPets")
s6:Toggle({ Name = "Auto-Buy Slots", Default = false, Callback = sync("autoPetSlot", "autoPetSlot") }, "AutoPetSlot")
s6:Dropdown({ Name = "Pets to sell", Multi = true, Options = petNames(), Default = {}, Callback = function(sel) pickMulti(sel, S.sellPets) end }, "SellPets")
s6:Toggle({ Name = "Auto-Sell Pets", Default = false, Callback = sync("autoSellPets", "autoSellPets") }, "AutoSellPets")
s6:Toggle({ Name = "Auto-Eggs", Default = false, Callback = sync("autoEgg", "autoEgg") }, "AutoEgg")
s6:Toggle({ Name = "Auto-Crates", Default = false, Callback = sync("autoCrate", "autoCrate") }, "AutoCrate")
s6:Toggle({ Name = "Auto-Seed Packs", Default = false, Callback = sync("autoPack", "autoPack") }, "AutoPack")

-- ═══ SHOP TAB ═══
local h1 = T.Shop:Section({ Side = "Left" }); h1:Header({ Text = "Seed Shop" })
h1:Dropdown({ Name = "Seeds to buy", Multi = true, Options = SEEDS, Default = {}, Callback = function(sel) pickMulti(sel, S.buySeeds) end }, "BuySeeds")
h1:Toggle({ Name = "Auto-Buy Seeds", Default = false, Callback = sync("autoBuy", "autoBuy") }, "AutoBuy")
h1:Slider({ Name = "Interval (s)", Default = 5, Min = 1, Max = 30, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.buyInterval = v end }, "BuyInterval")
h1:Slider({ Name = "Max/seed/pass", Default = 8, Min = 1, Max = 50, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.buyPerTick = v end }, "BuyPerTick")

local h2 = T.Shop:Section({ Side = "Left" }); h2:Header({ Text = "Gear Shop" })
h2:Dropdown({ Name = "Gear to buy", Multi = true, Options = GEAR, Default = {}, Callback = function(sel) pickMulti(sel, S.gearBuy) end }, "GearBuy")
h2:Toggle({ Name = "Auto-Buy Gear", Default = false, Callback = sync("autoGear", "autoGear") }, "AutoGear")
h2:Slider({ Name = "Interval (s)", Default = 10, Min = 2, Max = 60, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.gearInterval = v end }, "GearInterval")

local h3 = T.Shop:Section({ Side = "Right" }); h3:Header({ Text = "Wild Pet Buyer" })
h3:Toggle({ Name = "Auto-Buy Wild Pets", Default = false, Callback = sync("autoBuyPets", "autoBuyPets") }, "AutoBuyPets")
h3:Slider({ Name = "Max price", Default = 25000, Min = 1000, Max = 1e6, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.maxPetPrice = v end }, "MaxPetPrice")
h3:Toggle({ Name = "Teleport to pet", Default = true, Callback = function(v) S.petTeleport = v end }, "PetTeleport")
h3:Slider({ Name = "Buy interval (s)", Default = 5, Min = 2, Max = 60, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.petBuyInterval = v end }, "PetBuyInterval")

-- ═══ STEAL TAB ═══
local st1 = T.Steal:Section({ Side = "Left" }); st1:Header({ Text = "Auto-Steal (night only)" })
st1:Toggle({ Name = "Auto-Steal", Default = false, Callback = sync("autoSteal", "autoSteal") }, "AutoSteal")
st1:Toggle({ Name = "Teleport to fruit", Default = true, Callback = function(v) S.stealTeleport = v end }, "StealTeleport")
st1:Toggle({ Name = "Return to base", Default = true, Callback = function(v) S.stealReturnBase = v end }, "StealReturnBase")
st1:Slider({ Name = "Delay/fruit (s)", Default = 0.05, Min = 0, Max = 1, DisplayMethod = "Value", Precision = 2, Callback = function(v) S.stealDelay = v end }, "StealDelay")
local st2 = T.Steal:Section({ Side = "Right" }); st2:Header({ Text = "Info" })
st2:Label({ Text = "Uses PlantCycleModule + StealFlags" })
st2:Label({ Text = "for optimal fruit targeting." })
st2:Label({ Text = "Smooth lerp teleport." })
st2:Label({ Text = "Night-only." })

-- ═══ CONFIG TAB ═══
local c1 = T.Config:Section({ Side = "Left" }); c1:Header({ Text = "Master Control" })
c1:Toggle({ Name = "Master Farm Toggle", Default = false, Callback = sync("autoFarm", "autoFarm") }, "MasterFarm")

local c2 = T.Config:Section({ Side = "Left" }); c2:Header({ Text = "Skill Points" })
c2:Dropdown({ Name = "Stats to level", Multi = true, Options = { "BaseSpeed", "BaseJump", "ShovelPower", "MaxBackpack" }, Default = {}, Callback = function(sel) pickMulti(sel, S.skillStats) end }, "SkillStats")
c2:Toggle({ Name = "Auto-Spend", Default = false, Callback = sync("autoSkill", "autoSkill") }, "AutoSkill")

local c3 = T.Config:Section({ Side = "Right" }); c3:Header({ Text = "Weather Predictor" })
c3:Label({ Text = "Moon phases affect steal & growth." })
c3:Button({ Name = "Predict next 24h", Callback = function()
    local sum = 600
    local chances = { { Name = "Rainbow Moon", Chance = 6 }, { Name = "Goldmoon", Chance = 13 }, { Name = "Bloodmoon", Chance = 2 }, { Name = "Moon", Chance = 79 } }
    local function getMoonType(cid, ord) local rng = Random.new(cid * 1000 + ord); local roll = rng:NextNumber() * 100; local cum = 0; for _, m in ipairs(chances) do cum = cum + m.Chance; if roll <= cum then return m.Name end end; return "Moon" end
    local st = os.time(); local et = st + (24 * 3600); local lines = {}
    for t = st, et, sum do local cid = math.floor(t / sum); lines[#lines + 1] = string.format("[%s] %s", os.date("%I:%M %p", t), getMoonType(cid, 3)) end
    print("[UnAlive] Weather Prediction:\n" .. table.concat(lines, "\n"))
    MacLib:Notify({ Title = "Weather", Description = "Prediction printed to console", Lifetime = 3 })
end end)

-- ═══ SETTINGS TAB ═══
local g1 = T.Settings:Section({ Side = "Left" }); g1:Header({ Text = "Performance" })
g1:Toggle({ Name = "FPS Boost", Default = false, Callback = sync("fpsBoost", "fpsBoost") }, "FpsBoost")
g1:Slider({ Name = "UI Scale", Default = 1, Min = 0.6, Max = 1.4, DisplayMethod = "Value", Precision = 2, Callback = function(v) pcall(function() Window:SetScale(v) end) end }, "UiSize")
pcall(function() Window:GlobalSetting({ Name = "UI Blur", Default = Window:GetAcrylicBlurState(), Callback = function(v) pcall(function() Window:SetAcrylicBlurState(v) end) end }, "UIBlur") end)
g1:Button({ Name = "Unload All", Callback = function() S.killed = true; pcall(function() Window:Unload() end) end })

local g2 = T.Settings:Section({ Side = "Right" }); g2:Header({ Text = "Webhook & Misc" })
g2:Toggle({ Name = "Webhook Reports", Default = false, Callback = sync("webhookEnabled", "webhookEnabled") }, "WebhookEnabled")
g2:Slider({ Name = "Interval (min)", Default = 5, Min = 1, Max = 60, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.webhookInterval = v * 60 end }, "WebhookInterval")
g2:Button({ Name = "Test Webhook", Callback = function()
    local hr = (syn and syn.request) or http_request or request or (http and http.request)
    if not hr then MacLib:Notify({ Title = "Webhook", Description = "No HTTP function", Lifetime = 3 }); return end
    local url = "https://discord.com/api/webhooks/your-webhook-id/your-webhook-token"
    local p = { username = "UnAlive Hub", embeds = { { title = "Test — " .. LP.Name, color = 5763719, fields = { { name = "Sheckles", value = fmt(getSh()), inline = true }, { name = "Tokens", value = fmt(getTk()), inline = true }, { name = "Status", value = "Working", inline = true } }, footer = { text = "UnAlive Hub" } } } }
    local ok, res = pcall(function() return hr({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(p) }) end)
    local code = ok and res and (res.StatusCode or res.Status or res.status_code)
    MacLib:Notify({ Title = "Webhook", Description = ok and (code == 200 or code == 204) and "Sent" or "Failed: " .. tostring(code), Lifetime = 3 })
end end)

local g3 = T.Settings:Section({ Side = "Right" }); g3:Header({ Text = "Session" })
g3:Toggle({ Name = "Anti-AFK", Default = true, Callback = function(v) S.antiAfk = v end }, "AntiAfk")
g3:Toggle({ Name = "Auto Server-Hop", Default = false, Callback = sync("autoHop", "autoHop") }, "AutoHop")
g3:Slider({ Name = "Hop every (min)", Default = 0, Min = 0, Max = 120, DisplayMethod = "Value", Precision = 0, Callback = function(v) S.hopInterval = v * 60 end }, "HopInterval")
g3:Toggle({ Name = "Auto-Mailbox", Default = false, Callback = sync("autoMail", "autoMail") }, "AutoMail")
g3:Toggle({ Name = "Auto-Accept Gifts", Default = false, Callback = sync("autoAcceptGift", "autoAcceptGift") }, "AutoAcceptGift")
g3:Input({ Name = "Redeem code", Placeholder = "enter code", Callback = function(t) if t and t ~= "" then local ok, res = fire("Settings.SubmitCode", t); MacLib:Notify({ Title = "Code", Description = (ok and res == true) and "Redeemed: " .. t or "Invalid: " .. t, Lifetime = 3 }) end end }, "CodeInput")
g3:Toggle({ Name = "Auto-Redeem List", Default = false, Callback = sync("autoCodes", "autoCodes") }, "AutoCodes")

local g4 = T.Settings:Section({ Side = "Right" }); g4:Header({ Text = "About" })
g4:Label({ Text = "UnAlive Hub · Grow a Garden 2" })
g4:Label({ Text = "Hotkey: Left Ctrl" })

-- Live status
task.spawn(function() while not S.killed do local p = myPlot(); pcall(function() pl:UpdateName("Plot: " .. (p and p.Name or "?")) end); pcall(function() cl:UpdateName(string.format("Sheckles: %s | Tokens: %s", fmt(getSh()), fmt(getTk()))) end); pcall(function() sl:UpdateName(string.format("bought %d | planted %d | harvested %d | sold %d (+%s)", Stats.bought, Stats.planted, Stats.harvested, Stats.sold, fmt(Stats.earned))) end); task.wait(2) end end)

task.spawn(function() task.wait(0.25); pcall(function() Window:CreateMinimizer({ Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -10, 0.5, 0), Icon = "rbxassetid://10734950309" }) end) end)
Window.onUnloaded(function() S.killed = true end)

getgenv()._UnAliveCore = getgenv()._UnAliveCore or {}
getgenv()._UnAliveCore.Window = Window; getgenv()._UnAliveCore.S = S; getgenv()._UnAliveCore.Stats = Stats

MacLib:Notify({ Title = "UnAlive Hub", Description = "Loaded · Left Ctrl to toggle", Lifetime = 4 })
