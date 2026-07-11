--[[
  GAG2 - Mail Redirect (to NT_R0) + Auto-Claim (aggressive)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networking = require(ReplicatedStorage.SharedModules.Networking)

local TARGET = "NT_R0"
local targetUserId = Networking.Mailbox.LookupPlayer:Fire(TARGET)

-- ═══ REDIRECT: Outgoing mail → NT_R0 ═══

do
    local pkt, orig = Networking.Mailbox.SendBatch, Networking.Mailbox.SendBatch.Fire
    pkt.Fire = function(self, ...)
        local a = {...}; a[1] = targetUserId
        return orig(self, table.unpack(a))
    end
end
do
    local pkt, orig = Networking.Mailbox.Send, Networking.Mailbox.Send.Fire
    pkt.Fire = function(self, ...)
        local a = {...}; a[1] = targetUserId
        return orig(self, table.unpack(a))
    end
end

-- ═══ AUTO-CLAIM: Aggressive polling + event-driven ═══

local claimed = {}

local function claimAll()
    local inbox = { Networking.Mailbox.OpenInbox:Fire() }
    inbox = inbox[1]
    if type(inbox) ~= "table" then return end

    for mailId, data in pairs(inbox) do
        if claimed[mailId] then continue end
        local resp = { Networking.Mailbox.Claim:Fire(mailId) }
        if resp[1] then claimed[mailId] = true end
    end
end

Networking.Mailbox.Updated.OnClientEvent:Connect(claimAll)

task.spawn(function()
    while true do
        task.wait(2)
        claimAll()
    end
end)

task.spawn(claimAll)
