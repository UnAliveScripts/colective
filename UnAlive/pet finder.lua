-- == UnAlive Pet Finder + Auto Buy [STANDALONE] ==
-- Full auto-buy pet finder: GUI, per-server limits, tween approach, server hop.
-- 🔒 User-locked to rockytheboy515 only.

local WEBHOOK_URL = ""

if syn and syn.request then request = syn.request end

assert(typeof(request) == "function" and typeof(isfile) == "function" and typeof(makefolder) == "function" and typeof(isfolder) == "function" and typeof(readfile) == "function" and typeof(writefile) == "function", "Missing required exploit functions")

local Players = game:GetService("Players"); local TS = game:GetService("TweenService"); local TPS = game:GetService("TeleportService"); local HS = game:GetService("HttpService"); local RS = game:GetService("ReplicatedStorage")
repeat task.wait() until game:IsLoaded() and Players.LocalPlayer
local LP = Players.LocalPlayer; if game.PlaceId ~= 97598239454123 then return end

-- 🔒 User lock
if LP.Name ~= "rockytheboy515" then
    game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Locked", Text = "This script only works for rockytheboy515", Duration = 8 })
    return
end

-- Press-any-key helpers
local function pressBurst()
    pcall(function() local v = game:GetService("VirtualInputManager"); local keys = { Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.E }; for p = 1, 3 do for _, k in ipairs(keys) do v:SendKeyEvent(true, k, false, game); task.wait(0.02); v:SendKeyEvent(false, k, false, game); task.wait(0.02) end; task.wait(0.08) end end)
end
local function pressLight()
    pcall(function() local v = game:GetService("VirtualInputManager"); for _, k in ipairs({ Enum.KeyCode.Return, Enum.KeyCode.E }) do v:SendKeyEvent(true, k, false, game); task.wait(0.02); v:SendKeyEvent(false, k, false, game); task.wait(0.02) end end)
end
pressBurst()
local lastPress = 0
local function hasPrompt() local g = LP:FindFirstChild("PlayerGui"); if not g then return false end; for _, u in ipairs(g:GetDescendants()) do if u:IsA("TextLabel") then local t = string.lower(u.Text or ""); if t:find("press any key") or t:find("click to skip") then return true end end end; return false end
local function clickSkip() local g = LP:FindFirstChild("PlayerGui"); if not g then return false end; local c = false; for _, u in ipairs(g:GetDescendants()) do if u:IsA("TextButton") then local t = string.lower(u.Text or ""); if t:find("click to skip") or t:find("skip") then pcall(function() u:Activate() end); pcall(function() u.MouseButton1Click:Fire() end); c = true end end end; return c end

-- Settings
local SETTINGS = {
    ScanInterval = 0.25, ServerSearchTimeout = 20, NoEligibleTargetHopTimeout = 10, HopDelay = 1.5, StartDelay = 5,
    TweenSpeed = 30, BuyDistance = 10, PreBuyDelay = 0.65, PostBuyWait = 1.35, MaxTweenStepDistance = 14, ApproachTimeout = 16, SnapDetectDistance = 6, BuyBurstAttempts = 3, BuyBurstDelay = 0.18,
    UsePromptBuy = true, ForceInstantPrompt = true, PromptMaxDistance = 16,
    MinPlayersInServer = 7, MinHopPlayers = 4, HopMinPlayers = 4, HopMaxPlayers = 6,
    VerifyInBackpackBeforeHop = true, InventoryVerifyTimeout = 10, RequireVerifyToHop = true,
    Debug = true,
    PetList = { "Bunny", "Frog", "Owl", "Raccoon", "Monkey", "Robin", "Deer", "Bee", "Unicorn", "GoldenDragonfly" },
    DefaultLimitPerPet = 1, MinLimit = 1, MaxLimit = 10,
}

local state = { autoEnabled = false, status = "Idle", scriptRunning = true, isMinimized = false, waitingForVerify = false, lastVerifyPetName = nil, isHopping = false, lastHopAttemptAt = 0, hopRetryQueued = false, selectedPets = {}, perPetLimit = {}, boughtThisServer = {} }
for _, n in ipairs(SETTINGS.PetList) do state.selectedPets[n] = true; state.perPetLimit[n] = SETTINGS.DefaultLimitPerPet; state.boughtThisServer[n] = 0 end

-- File storage
local PlaceId = game.PlaceId; local JobId = game.JobId
local PFR = "UnAliveHub"; local PF = PFR .. "\\" .. tostring(PlaceId)
local JSP = PF .. "\\JobIdStorage.json"; local USP = PF .. "\\PetFinderSettings.json"
local function je(v) return HS:JSONEncode(v) end; local function jd(v) return HS:JSONDecode(v) end
if not isfolder(PFR) then makefolder(PFR) end; if not isfolder(PF) then makefolder(PF) end
local visited = { JobIds = {} }
if isfile(JSP) then local ok, d = pcall(function() return jd(readfile(JSP)) end); if ok and type(d) == "table" and type(d.JobIds) == "table" then visited = d end end
if not table.find(visited.JobIds, JobId) then table.insert(visited.JobIds, JobId) end; writefile(JSP, je(visited))

local function save() local p = { selectedPets = state.selectedPets, perPetLimit = state.perPetLimit, MinHopPlayers = SETTINGS.MinHopPlayers, autoEnabled = state.autoEnabled }; pcall(function() writefile(USP, je(p)) end) end
local function load()
    if not isfile(USP) then return end; local ok, d = pcall(function() return jd(readfile(USP)) end); if not ok or type(d) ~= "table" then return end
    if type(d.selectedPets) == "table" then for _, n in ipairs(SETTINGS.PetList) do if type(d.selectedPets[n]) == "boolean" then state.selectedPets[n] = d.selectedPets[n] end end end
    if type(d.perPetLimit) == "table" then for _, n in ipairs(SETTINGS.PetList) do local v = tonumber(d.perPetLimit[n]); if v then v = math.floor(v); v = math.max(SETTINGS.MinLimit, math.min(SETTINGS.MaxLimit, v)); state.perPetLimit[n] = v end end end
    local m = tonumber(d.MinHopPlayers); if m then SETTINGS.MinHopPlayers = math.max(0, math.floor(m)) end
    if type(d.autoEnabled) == "boolean" then state.autoEnabled = d.autoEnabled; if state.autoEnabled then state.status = "Searching" end end
end
load()

local function log(...) if SETTINGS.Debug then print("[UnAlive]", ...) end end
local function setStatus(s) state.status = s end
local function canHop() return not (state.waitingForVerify and SETTINGS.RequireVerifyToHop and state.lastVerifyPetName) end
local function resetCounters() for _, n in ipairs(SETTINGS.PetList) do state.boughtThisServer[n] = 0 end end
local function isNeeded(n) if not state.selectedPets[n] then return false end; return (state.boughtThisServer[n] or 0) < (state.perPetLimit[n] or SETTINGS.DefaultLimitPerPet) end
local function allDone() for _, n in ipairs(SETTINGS.PetList) do if state.selectedPets[n] and isNeeded(n) then return false end end; return true end

local function getChar() return LP.Character or LP.CharacterAdded:Wait() end
local function getRoot(c) return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") end
local function getPetPos(m) if not m or not m.Parent then return nil end; if m:IsA("Model") then if m.PrimaryPart then return m.PrimaryPart.Position end; for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then return d.Position end end elseif m:IsA("BasePart") then return m.Position end; return nil end

local function findBuyRemote() return RS:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent") end
local function fireBuy(pet) local r = findBuyRemote(); local op = ">" .. string.char(0); r:FireServer(buffer.fromstring(op), { pet }) end

local function findPrompt(inst)
    if not inst then return nil end; if inst:IsA("ProximityPrompt") then return inst end
    for _, d in ipairs(inst:GetDescendants()) do if d:IsA("ProximityPrompt") then return d end end; return nil
end

local function tryPrompt(target, kw, root)
    if not SETTINGS.UsePromptBuy then return false end
    local p = findPrompt(target)
    if not p then
        local map = workspace:FindFirstChild("Map")
        if map then local wr = map:FindFirstChild("WildPetRef"); if wr then for _, rp in ipairs(wr:GetChildren()) do if string.find(string.lower(rp.Name), string.lower(kw), 1, true) then p = findPrompt(rp); if p then target = rp; break end end end end end
    end
    if not p then return false end
    local pp = p.Parent; local pPos = pp and pp:IsA("BasePart") and pp.Position or getPetPos(target); if not pPos then return false end
    if root and (root.Position - pPos).Magnitude > SETTINGS.PromptMaxDistance then return false end
    if SETTINGS.ForceInstantPrompt then pcall(function() p.HoldDuration = 0 end) end
    local fired = false
    if type(fireproximityprompt) == "function" then pcall(function() fireproximityprompt(p, 0); fired = true end) end
    if not fired then local v = game:GetService("VirtualInputManager"); pcall(function() v:SendKeyEvent(true, Enum.KeyCode.E, false, game); task.wait(0.08); v:SendKeyEvent(false, Enum.KeyCode.E, false, game); fired = true end) end
    return fired
end

local function tweenTo(r, pos) local d = (pos - r.Position).Magnitude; local dur = math.max(0.05, d / SETTINGS.TweenSpeed); local t = TS:Create(r, TweenInfo.new(dur, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = CFrame.new(pos) }); t:Play(); t.Completed:Wait() end

local function approach(r, pet)
    local start = os.clock(); local first = getPetPos(pet); if not first then return false end
    local target = first + Vector3.new(0, 2.5, 0); local lastDist = (target - r.Position).Magnitude; local stuck = 0
    while (os.clock() - start) <= SETTINGS.ApproachTimeout do
        local live = getPetPos(pet); if live then target = live + Vector3.new(0, 2.5, 0) end
        local d = (target - r.Position).Magnitude; if d <= SETTINGS.BuyDistance then return true end
        local step = math.min(SETTINGS.MaxTweenStepDistance, d); tweenTo(r, r.Position + (target - r.Position).Unit * step); task.wait(0.12)
        local live2 = getPetPos(pet); if live2 then target = live2 + Vector3.new(0, 2.5, 0) end
        local nd = (target - r.Position).Magnitude; if (lastDist - nd) < SETTINGS.SnapDetectDistance then stuck = stuck + 1 else stuck = 0 end
        if stuck >= 2 then pcall(function() r.CFrame = CFrame.new(target) end); task.wait(0.24); stuck = 0 end; lastDist = nd
    end
    local fin = getPetPos(pet); return fin and ((fin + Vector3.new(0, 2.5, 0)) - r.Position).Magnitude <= SETTINGS.BuyDistance
end

local function normName(n) return string.lower(tostring(n or "")):gsub("[^%w%s]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") end
local function hasInv(n)
    local t = normName(n); if t == "" then return false end
    local function ck(c) if not c then return false end; for _, o in ipairs(c:GetDescendants()) do if normName(o.Name) == t then return true end end; return false end
    return ck(LP:FindFirstChild("Backpack")) or ck(LP.Character)
end
local function waitInv(n, t) local t0 = os.clock(); while (os.clock() - t0) <= t do if hasInv(n) then return true end; task.wait(0.2) end; return false end

local function findBest()
    local map = workspace:FindFirstChild("Map"); if not map then return nil, nil end; local sp = map:FindFirstChild("WildPetSpawns"); if not sp then return nil, nil end
    local bestName, bestNeed, bestInst = nil, -1e9, nil
    for _, pi in ipairs(sp:GetChildren()) do
        local nm = pi.Name
        for _, pn in ipairs(SETTINGS.PetList) do
            if state.selectedPets[pn] and isNeeded(pn) and string.find(string.lower(nm), string.lower(pn), 1, true) then
                local need = (state.perPetLimit[pn] or 1) - (state.boughtThisServer[pn] or 0)
                if need > bestNeed then bestNeed = need; bestName = pn; bestInst = pi end
            end
        end
    end; return bestInst, bestName
end

-- Hop helpers
local hcPath = "NotSameServers.json"
local function loadIDs() local h = os.date("!*t").hour; local a = {}; local ok = pcall(function() a = HS:JSONDecode(readfile(hcPath)) end); if not ok or type(a) ~= "table" then a = { h }; pcall(function() writefile(hcPath, HS:JSONEncode(a)) end) end; return a, h end
local function saveIDs(a) pcall(function() writefile(hcPath, HS:JSONEncode(a)) end) end
local function clickFail()
    local g = LP:FindFirstChild("PlayerGui"); if not g then return false end; local c = false
    for _, u in ipairs(g:GetDescendants()) do if u:IsA("TextButton") then local t = string.lower(u.Text or ""); if t == "ok" then local pt = ""; if u.Parent and u.Parent:IsA("GuiObject") then for _, d in ipairs(u.Parent:GetDescendants()) do if d:IsA("TextLabel") then pt = pt .. " " .. string.lower(d.Text or "") end end end; if pt:find("teleport failed") or pt:find("server is full") or pt:find("error code: 772") then pcall(function() u:Activate() end); pcall(function() u.MouseButton1Click:Fire() end); c = true end end end end; return c
end
local fsCD = {}; local FSRD = 45; local MFSR = 2
local function hopServer()
    if state.isHopping then state.hopRetryQueued = true; return end
    if state.waitingForVerify and SETTINGS.RequireVerifyToHop and state.lastVerifyPetName then log("Hop blocked: verify", state.lastVerifyPetName); setStatus("Verifying"); return end
    state.isHopping = true; state.lastHopAttemptAt = os.clock(); setStatus("Hopping")
    local allIDs, ah = loadIDs(); local fa = ""; local hopOK = false
    local function ensureH() if tonumber(allIDs[1]) ~= tonumber(ah) then pcall(function() delfile(hcPath) end); allIDs = { ah }; saveIDs(allIDs) end end
    local function tryTP(id)
        if not table.find(visited.JobIds, id) then table.insert(visited.JobIds, id); pcall(function() writefile(JSP, je(visited)) end) end
        local ok = pcall(function() TPS:TeleportToPlaceInstance(PlaceId, id, LP) end)
        if ok then hopOK = true; return true end; fsCD[id] = os.clock() + FSRD; return false
    end
    local function TPR()
        local Site; local ok, data = pcall(function() return HS:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100" .. (fa ~= "" and "&cursor=" .. fa or ""))) end)
        if not ok or type(data) ~= "table" then return false end; if data.nextPageCursor and data.nextPageCursor ~= "null" then fa = data.nextPageCursor else fa = "" end; ensureH()
        for _, v in pairs(data.data or {}) do
            local id = tostring(v.id); local playing = tonumber(v.playing) or 0; local maxP = tonumber(v.maxPlayers) or 0
            if id ~= JobId and (maxP - playing) >= MFSR and (os.clock() >= (fsCD[id] or 0)) then
                local ok2 = true; for idx, e in pairs(allIDs) do if idx ~= 1 and id == tostring(e) then ok2 = false; break end end
                if ok2 then table.insert(allIDs, id); saveIDs(allIDs); if tryTP(id) then task.wait(1); return true end; task.wait(0.02) end
            end
        end; return false
    end
    local tries = 0
    while state.scriptRunning and state.autoEnabled and not hopOK and tries < 60 do
        tries = tries + 1; pcall(function() TPR(); if not hopOK and fa ~= "" then TPR() end end)
        if not hopOK and (tries == 1 or tries == 3 or tries == 4 or tries == 5 or tries == 6) then pcall(function() TPR() end) end; task.wait(0.03)
    end
    if not hopOK then clickFail(); log("Hop retrying"); setStatus("Searching") end
    state.isHopping = false; state.lastHopAttemptAt = os.clock() - (SETTINGS.HopDelay * 0.2)
    if state.hopRetryQueued and state.autoEnabled and state.scriptRunning then state.hopRetryQueued = false; task.spawn(function() task.wait(0.05); hopServer() end) end
end

-- Webhook notify
local function sendWebhook(text)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then return end
    if not request then return end
    local embed = { embeds = { { title = "Pet Finder", description = text, color = 5763719, footer = { text = "UnAlive Hub" } } } }
    pcall(function() request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HS:JSONEncode(embed) }) end)
end

-- GUI
local sg = Instance.new("ScreenGui"); sg.Name = "UnAlivePetFinder"; sg.ResetOnSpawn = false; sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.Parent = LP:WaitForChild("PlayerGui")
local f = Instance.new("Frame"); f.Name = "Main"; f.Size = UDim2.new(0, 410, 0, 490); f.Position = UDim2.new(0, 20, 0, 90); f.BackgroundColor3 = Color3.fromRGB(22, 24, 30); f.BorderSizePixel = 0; f.Active = true; f.Draggable = true; f.Parent = sg
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
local t = Instance.new("TextLabel"); t.Size = UDim2.new(1, -100, 0, 34); t.Position = UDim2.new(0, 12, 0, 8); t.BackgroundTransparency = 1; t.Text = "UnAlive · Pet Finder"; t.TextColor3 = Color3.fromRGB(245, 248, 255); t.Font = Enum.Font.GothamBold; t.TextSize = 18; t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = f

local minB = Instance.new("TextButton"); minB.Size = UDim2.new(0, 34, 0, 26); minB.Position = UDim2.new(1, -82, 0, 12); minB.BackgroundColor3 = Color3.fromRGB(58, 63, 74); minB.Text = "-"; minB.TextColor3 = Color3.fromRGB(255, 255, 255); minB.Font = Enum.Font.GothamBold; minB.TextSize = 16; minB.Parent = f; Instance.new("UICorner", minB).CornerRadius = UDim.new(0, 6)
local clB = Instance.new("TextButton"); clB.Size = UDim2.new(0, 34, 0, 26); clB.Position = UDim2.new(1, -42, 0, 12); clB.BackgroundColor3 = Color3.fromRGB(171, 63, 74); clB.Text = "X"; clB.TextColor3 = Color3.fromRGB(255, 255, 255); clB.Font = Enum.Font.GothamBold; clB.TextSize = 14; clB.Parent = f; Instance.new("UICorner", clB).CornerRadius = UDim.new(0, 6)

local stL = Instance.new("TextLabel"); stL.Size = UDim2.new(1, -24, 0, 22); stL.Position = UDim2.new(0, 12, 0, 48); stL.BackgroundTransparency = 1; stL.Text = "Status: OFF"; stL.TextColor3 = Color3.fromRGB(196, 203, 255); stL.Font = Enum.Font.GothamSemibold; stL.TextSize = 13; stL.TextXAlignment = Enum.TextXAlignment.Left; stL.Parent = f
local suL = Instance.new("TextLabel"); suL.Size = UDim2.new(1, -24, 0, 38); suL.Position = UDim2.new(0, 12, 0, 70); suL.BackgroundTransparency = 1; suL.Text = "Filter: Bunny:0/2 | Frog:0/2"; suL.TextColor3 = Color3.fromRGB(145, 215, 255); suL.Font = Enum.Font.Gotham; suL.TextSize = 12; suL.TextWrapped = true; suL.TextXAlignment = Enum.TextXAlignment.Left; suL.TextYAlignment = Enum.TextYAlignment.Top; suL.Parent = f

local autoB = Instance.new("TextButton"); autoB.Size = UDim2.new(1, -24, 0, 34); autoB.Position = UDim2.new(0, 12, 0, 114); autoB.BackgroundColor3 = Color3.fromRGB(170, 50, 50); autoB.Text = "Auto: OFF"; autoB.TextColor3 = Color3.fromRGB(255, 255, 255); autoB.Font = Enum.Font.GothamBold; autoB.TextSize = 14; autoB.Parent = f; Instance.new("UICorner", autoB).CornerRadius = UDim.new(0, 8)

local plF = Instance.new("ScrollingFrame"); plF.Name = "PetList"; plF.Size = UDim2.new(1, -24, 0, 330); plF.Position = UDim2.new(0, 12, 0, 156); plF.BackgroundColor3 = Color3.fromRGB(18, 20, 26); plF.BackgroundTransparency = 0.15; plF.BorderSizePixel = 0; plF.ScrollBarThickness = 6; plF.ScrollBarImageColor3 = Color3.fromRGB(92, 102, 122); plF.CanvasSize = UDim2.new(0, 0, 0, 0); plF.Parent = f; Instance.new("UICorner", plF).CornerRadius = UDim.new(0, 8)

local rows = {}; local rH = 40; local rG = 8
for i, pn in ipairs(SETTINGS.PetList) do
    local y = (i - 1) * (rH + rG)
    local sb = Instance.new("TextButton"); sb.Size = UDim2.new(0, 172, 0, rH); sb.Position = UDim2.new(0, 10, 0, y); sb.BackgroundColor3 = Color3.fromRGB(70, 76, 90); sb.TextColor3 = Color3.fromRGB(255, 255, 255); sb.Font = Enum.Font.GothamBold; sb.TextSize = 13; sb.Parent = plF; Instance.new("UICorner", sb).CornerRadius = UDim.new(0, 6)
    local miB = Instance.new("TextButton"); miB.Size = UDim2.new(0, 36, 0, rH); miB.Position = UDim2.new(0, 190, 0, y); miB.BackgroundColor3 = Color3.fromRGB(61, 66, 78); miB.Text = "-"; miB.TextColor3 = Color3.fromRGB(255, 255, 255); miB.Font = Enum.Font.GothamBold; miB.TextSize = 18; miB.Parent = plF; Instance.new("UICorner", miB).CornerRadius = UDim.new(0, 6)
    local ll = Instance.new("TextLabel"); ll.Size = UDim2.new(0, 105, 0, rH); ll.Position = UDim2.new(0, 234, 0, y); ll.BackgroundColor3 = Color3.fromRGB(24, 27, 35); ll.TextColor3 = Color3.fromRGB(255, 255, 255); ll.Font = Enum.Font.GothamBold; ll.TextSize = 13; ll.Text = "Limit: " .. tostring(state.perPetLimit[pn]); ll.Parent = plF; Instance.new("UICorner", ll).CornerRadius = UDim.new(0, 6)
    local plB = Instance.new("TextButton"); plB.Size = UDim2.new(0, 36, 0, rH); plB.Position = UDim2.new(0, 345, 0, y); plB.BackgroundColor3 = Color3.fromRGB(61, 66, 78); plB.Text = "+"; plB.TextColor3 = Color3.fromRGB(255, 255, 255); plB.Font = Enum.Font.GothamBold; plB.TextSize = 18; plB.Parent = plF; Instance.new("UICorner", plB).CornerRadius = UDim.new(0, 6)
    rows[pn] = { sb = sb, mi = miB, pl = plB, ll = ll }
end; plF.CanvasSize = UDim2.new(0, 0, 0, (#SETTINGS.PetList * (rH + rG)) + 8)

local fullSz = UDim2.new(0, 410, 0, 490); local minSz = UDim2.new(0, 410, 0, 48)
local function setMin(v)
    state.isMinimized = v; f.Size = v and minSz or fullSz
    for _, w in ipairs({ stL, suL, autoB, plF }) do w.Visible = not v end
    for _, row in pairs(rows) do row.sb.Visible = not v; row.mi.Visible = not v; row.pl.Visible = not v; row.ll.Visible = not v end
    minB.Text = v and "+" or "-"
end

local function ref()
    stL.Text = "Status: " .. tostring(state.status)
    local chunks = {}; for _, pn in ipairs(SETTINGS.PetList) do if state.selectedPets[pn] then chunks[#chunks + 1] = pn .. ":" .. tostring(state.boughtThisServer[pn]) .. "/" .. tostring(state.perPetLimit[pn]) end end
    suL.Text = "Filter: " .. (#chunks > 0 and table.concat(chunks, " | ") or "None selected")
    autoB.Text = state.autoEnabled and "Auto: ON" or "Auto: OFF"; autoB.BackgroundColor3 = state.autoEnabled and Color3.fromRGB(50, 170, 70) or Color3.fromRGB(170, 50, 50)
    for _, pn in ipairs(SETTINGS.PetList) do local r = rows[pn]; if r then local e = state.selectedPets[pn]; r.sb.Text = pn .. (e and " [ON]" or " [OFF]"); r.sb.BackgroundColor3 = e and Color3.fromRGB(50, 145, 80) or Color3.fromRGB(85, 85, 85); r.ll.Text = "Limit: " .. tostring(state.perPetLimit[pn] or SETTINGS.DefaultLimitPerPet) end end
end

autoB.MouseButton1Click:Connect(function() state.autoEnabled = not state.autoEnabled; if state.autoEnabled then resetCounters(); setStatus("Finding Pets") else setStatus("OFF") end; save(); ref() end)
for _, pn in ipairs(SETTINGS.PetList) do local r = rows[pn]; if r then
    r.sb.MouseButton1Click:Connect(function() state.selectedPets[pn] = not state.selectedPets[pn]; save(); ref() end)
    r.mi.MouseButton1Click:Connect(function() local c = math.max(SETTINGS.MinLimit, (state.perPetLimit[pn] or SETTINGS.DefaultLimitPerPet) - 1); state.perPetLimit[pn] = c; save(); ref() end)
    r.pl.MouseButton1Click:Connect(function() local c = math.min(SETTINGS.MaxLimit, (state.perPetLimit[pn] or SETTINGS.DefaultLimitPerPet) + 1); state.perPetLimit[pn] = c; save(); ref() end)
end end
minB.MouseButton1Click:Connect(function() setMin(not state.isMinimized) end)
clB.MouseButton1Click:Connect(function() state.scriptRunning = false; state.autoEnabled = false; if sg then sg:Destroy() end end)
ref(); setMin(false); save()

-- Background watcher
task.spawn(function()
    while state.scriptRunning do
        local now = os.clock()
        if hasPrompt() and (now - lastPress) >= 1 then lastPress = now; pressLight(); clickSkip() end
        if clickFail() and state.autoEnabled then if canHop() then state.isHopping = false; task.spawn(function() hopServer() end) else setStatus("Verifying"); ref() end end
        task.wait(0.2)
    end
end)

-- Main loop
task.wait(SETTINGS.StartDelay)
task.spawn(function()
    while state.scriptRunning do
        if not state.autoEnabled then task.wait(0.2)
        else
            if allDone() then
                if canHop() then log("All limits reached, hopping"); hopServer(); task.wait(0.05) else setStatus("Verifying"); ref(); task.wait(0.3) end
            else
                local noElStart = os.clock(); local found, foundName = nil, nil; setStatus("Searching"); ref()
                while state.scriptRunning and state.autoEnabled do
                    if allDone() then break end; found, foundName = findBest()
                    if found and found.Parent and foundName then break end
                    if (os.clock() - noElStart) >= SETTINGS.NoEligibleTargetHopTimeout then if canHop() then log("No targets, hopping"); break else setStatus("Verifying"); ref(); task.wait(0.3) end end; task.wait(SETTINGS.ScanInterval)
                end
                if not state.scriptRunning then break end
                if not state.autoEnabled then setStatus("Idle"); ref(); task.wait(0.2)
                elseif allDone() then if canHop() then hopServer(); return else setStatus("Verifying"); ref(); task.wait(0.3) end
                elseif found and found.Parent and foundName then
                    log("Target:", foundName); local char = getChar(); local root = getRoot(char)
                    if root then
                        local pos = getPetPos(found)
                        if pos then
                            setStatus("Approaching"); ref(); local reached = approach(root, found); local check = getPetPos(found)
                            if reached and check and (root.Position - check).Magnitude <= SETTINGS.BuyDistance then
                                setStatus("Buying"); ref(); task.wait(SETTINGS.PreBuyDelay)
                                for a = 1, SETTINGS.BuyBurstAttempts do
                                    local live = getPetPos(found)
                                    if live and (root.Position - live).Magnitude > SETTINGS.BuyDistance then setStatus("Re-Approaching"); ref(); approach(root, found) end
                                    local bought = SETTINGS.UsePromptBuy and tryPrompt(found, foundName, root) or false
                                    if not bought then pcall(function() fireBuy(found) end) end; if bought then break end; task.wait(SETTINGS.BuyBurstDelay + 0.08)
                                end
                                task.wait(SETTINGS.PostBuyWait)
                                state.waitingForVerify = true; state.lastVerifyPetName = foundName; setStatus("Verifying"); ref()
                                local verified = true
                                if SETTINGS.VerifyInBackpackBeforeHop then
                                    verified = waitInv(foundName, SETTINGS.InventoryVerifyTimeout)
                                    if not verified and SETTINGS.RequireVerifyToHop then
                                        while state.scriptRunning and state.autoEnabled do setStatus("Verifying"); ref(); if hasInv(foundName) then verified = true; break end; task.wait(0.3) end
                                    end
                                end
                                if verified then
                                    state.waitingForVerify = false; state.lastVerifyPetName = nil
                                    state.boughtThisServer[foundName] = (state.boughtThisServer[foundName] or 0) + 1
                                    sendWebhook("Bought " .. foundName .. " (" .. state.boughtThisServer[foundName] .. "/" .. (state.perPetLimit[foundName] or 1) .. ")")
                                    setStatus("Searching"); ref()
                                else state.waitingForVerify = true; state.lastVerifyPetName = foundName; setStatus("Verifying"); ref() end
                            end
                        end
                    end
                else if canHop() then log("No pet, hopping"); hopServer(); task.wait(0.05) else setStatus("Verifying"); ref(); task.wait(0.3) end end
            end
        end
    end
end)
