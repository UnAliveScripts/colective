-- == UnAlive Webhook Reporter [STANDALONE] ==
-- Settings tab: sends farm reports to Discord.
-- Paste into your script. Edit WEBHOOK_URL below.

local Sk = getgenv and getgenv()._UnAliveCore
if not Sk then
    local Players = game:GetService("Players"); local RS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace"); local HttpService = game:GetService("HttpService"); local LP = Players.LocalPlayer
    local Net; do local sm = RS:WaitForChild("SharedModules", 15); local m = sm and sm:FindFirstChild("Networking"); if m then local ok, n = pcall(require, m); if ok then Net = n end end end
    if not Net then error("Networking module not found") end
    local _rep; local function rep() if _rep then return _rep end; local ok, psc = pcall(require, RS.ClientModules.PlayerStateClient); if ok and psc and psc.WaitForLocalReplica then local ok2, r = pcall(psc.WaitForLocalReplica, psc, 30); if ok2 and r then _rep = r end end; return _rep end
    local function pd() local r = rep(); return (r and r.Data) or {} end
    local function getSh() return tonumber(pd().Sheckles) or 0 end
    local function getTk() return tonumber(pd().Tokens) or 0 end
    local function myPlot() local id = LP:GetAttribute("PlotId"); local g = WS:FindFirstChild("Gardens"); if not (id and g) then return nil end; return g:FindFirstChild("Plot" .. tostring(id)) end
    local function fmt(n) n = tonumber(n) or 0; if n >= 1e12 then return ("%.2fT"):format(n / 1e12) elseif n >= 1e9 then return ("%.2fB"):format(n / 1e9) elseif n >= 1e6 then return ("%.2fM"):format(n / 1e6) elseif n >= 1e3 then return ("%.2fK"):format(n / 1e3) else return tostring(math.floor(n)) end end
    Sk = { LP = LP, getSh = getSh, getTk = getTk, myPlot = myPlot, fmt = fmt, HttpService = HttpService }; getgenv()._UnAliveCore = Sk
end
local LP = Sk.LP; local getSh = Sk.getSh; local getTk = Sk.getTk; local myPlot = Sk.myPlot; local fmt = Sk.fmt; local HttpService = Sk.HttpService

local httpRequest = (syn and syn.request) or http_request or request or (http and http.request)

-- ═══════════════════════════════════════════════════════════
-- EDIT THIS: replace with your own Discord webhook URL
-- ═══════════════════════════════════════════════════════════
local WEBHOOK_URL = "https://discord.com/api/webhooks/your-webhook-id/your-webhook-token"

local webhookEnabled = false
local webhookInterval = 300
local startAt = os.clock()

local function hms(sec)
    sec = math.floor(sec); local h = sec // 3600; local m = (sec % 3600) // 60
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, sec % 60) end
    return sec .. "s"
end

local function sendReport(isTest)
    if not httpRequest then print("[UnAlive] No HTTP function"); return false end
    if WEBHOOK_URL == "" or not WEBHOOK_URL:match("^https?://") then print("[UnAlive] Set WEBHOOK_URL"); return false end
    local payload = {
        username = "UnAlive Hub",
        embeds = {{
            title = "Farm Report — " .. LP.Name, color = 5763719,
            fields = {
                { name = "Sheckles", value = fmt(getSh()), inline = true },
                { name = "Tokens", value = fmt(getTk()), inline = true },
                { name = "Plot", value = tostring((myPlot() and myPlot().Name) or "?"), inline = true },
                { name = "Uptime", value = hms(os.clock() - startAt), inline = true },
            },
            footer = { text = "UnAlive Hub" },
        }}
    }
    local ok, res = pcall(function() return httpRequest({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(payload) }) end)
    local code = ok and res and (res.StatusCode or res.Status or res.status_code)
    local good = ok and (code == nil or code == 200 or code == 204)
    if isTest then print("[UnAlive]", good and "Webhook sent" or "Failed " .. tostring(code)) end
    return good
end

task.spawn(function() while true do if webhookEnabled and WEBHOOK_URL ~= "" then pcall(sendReport) end; task.wait(webhookInterval) end end)
