-- == UnAlive Auto-Misc [STANDALONE] ==
-- Settings tab: mailbox, gifts, server-hop, codes, anti-afk.
-- Paste into your script.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local LP = Players.LocalPlayer
    local VU = pcall(function() return game:GetService("VirtualUser") end) and game:GetService("VirtualUser") or nil
    local Net; do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rl = { w = 0, c = 0, cap = 60 }; local function pace() local n = os.clock(); if n - _rl.w >= 1 then _rl.w = n; _rl.c = 0 end; if _rl.c >= _rl.cap then task.wait(0.05); return pace() end; _rl.c = _rl.c + 1 end
    local function action(p) local c = Net; for pt in p:gmatch("[^.]+") do if type(c) ~= "table" then return nil end; c = c[pt] end; return c end
    local function fire(p, ...) local a = action(p); if not (a and a.Fire) then return false end; pace(); local args = table.pack(...); return select(2, pcall(a.Fire, a, table.unpack(args, 1, args.n))) end
    local _due = {}; local function due(k, p) local n = os.clock(); if not _due[k] or n - _due[k] >= p then _due[k] = n; return true end; return false end
    Sk = { fire = fire, action = action, due = due, LP = LP, VU = VU }; getgenv()._UnAliveCore = Sk
end
local fire = Sk.fire; local action = Sk.action; local due = Sk.due; local LP = Sk.LP; local VU = Sk.VU

local autoMail = false; local autoAcceptGift = false; local autoHop = false; local hopInterval = 0
local autoCodes = false; local antiAfk = true; local codesRedeemed = 0; local triedCodes = {}

-- Mailbox
task.spawn(function() while true do if autoMail then pcall(function() if not due("umail", 30) then return end; local ok, box = fire("Mailbox.OpenInbox"); if ok and type(box) == "table" then local mb = box.Mailbox or box.Inbox or box; for id, entry in pairs(mb) do if not autoMail then break end; if type(entry) ~= "table" or not (entry.Claimed == true or entry.IsClaimed == true) then fire("Mailbox.Claim", id); task.wait(0.3) end end end end) end; task.wait(5) end end)

-- Gifts
pcall(function() local g = action("Gifting.Prompted"); if g and g.OnClientEvent then g.OnClientEvent:Connect(function(fp) if autoAcceptGift and fp then pcall(function() fire("Gifting.Response", fp, true) end) end end) end end)

-- Server hop
task.spawn(function() while true do if autoHop and hopInterval > 0 then pcall(function() if due("u hop", math.max(60, hopInterval)) then fire("AntiAfk.RequestHop") end end) end; task.wait(10) end end)

-- Anti-AFK
if VU then LP.Idled:Connect(function() if antiAfk then pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new(0, 0)) end) end end) end

-- Codes
task.spawn(function() while true do if autoCodes then pcall(function() local list = {}; for _, code in ipairs(list) do if code ~= "" and not triedCodes[code] then local ok, res = fire("Settings.SubmitCode", code); triedCodes[code] = true; if ok and res == true then codesRedeemed = codesRedeemed + 1 end; task.wait(0.4) end end end) end; task.wait(120) end end)
