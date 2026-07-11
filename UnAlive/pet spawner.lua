-- == UnAlive Pet Spawner [STANDALONE] ==
-- Spawn any pet into your backpack as a tool. Use the tool to equip/see the 3D pet.
-- Supports all species, sizes, Rainbow mutation, full wandering AI.

if getgenv()._UnAlivePetSpawner then print("[UnAlive] Pet Spawner already loaded"); return end
getgenv()._UnAlivePetSpawner = true

local player = game.Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local HS = game:GetService("HttpService")
local RunSvc = game:GetService("RunService")

local PM = require(RS.SharedModules.PetModules)
local PD = require(RS.SharedData.PetData)
local PS = require(RS.SharedData.PetSizes)
local Models = workspace:WaitForChild("_PetVisualClient"):WaitForChild("Models")

local NC = pcall(function() return require(player.PlayerScripts.Controllers.NotificationController) end) and require(player.PlayerScripts.Controllers.NotificationController) or nil
local function notify(m) if NC then pcall(function() NC:CreateNotification(m) end) end end

local AG = pcall(function() return require(RS.SharedModules.AnimatedGradient) end) and require(RS.SharedModules.AnimatedGradient) or nil
local PC = pcall(function() return require(player.PlayerScripts.Controllers.PetListController) end) and require(player.PlayerScripts.Controllers.PetListController) or nil

local RarityColors = {
    Common = Color3.fromRGB(180, 180, 180), Uncommon = Color3.fromRGB(60, 200, 70), Rare = Color3.fromRGB(60, 130, 255),
    Epic = Color3.fromRGB(160, 60, 220), Legendary = Color3.fromRGB(255, 215, 0), Mythic = Color3.fromRGB(220, 40, 40),
}
local RainbowSeq = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 165, 0)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 200, 0)),
    ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 100, 255)), ColorSequenceKeypoint.new(0.83, Color3.fromRGB(140, 0, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 200)),
})

local FO = { Bear = 1.51, Bunny = 0.67, Deer = 1.56, Frog = 0.87, Monkey = 1.11, Raccoon = 1, Turtle = 0.94, Unicorn = 1.55, Bee = 0.87, BlackDragon = 0.13, GoldenDragonfly = 1.06, IceSerpent = 1.8, Owl = 0.92, Robin = 0.93 }
local RO = { Turtle = "RigPart", BlackDragon = "Root" }
local SO = { { x = 0, z = 5 }, { x = -5, z = 4 }, { x = 5, z = 4 }, { x = -7, z = 7 }, { x = 7, z = 7 }, { x = 0, z = 8 }, { x = 0, z = 8 }, { x = 0, z = 8 } }

local function getGroundY(pos, filter)
    local origin = pos + Vector3.new(0, 200, 0); local dir = Vector3.new(0, -600, 0)
    for _ = 1, 8 do
        local r = workspace:Raycast(origin, dir, filter)
        if not r then return nil end
        if r.Instance.Transparency < 0.99 and r.Instance.CanCollide then return r.Position.Y end
        local f2 = table.clone(filter.FilterDescendantsInstances); table.insert(f2, r.Instance); filter.FilterDescendantsInstances = f2
    end
    return nil
end

local speciesList = {}
for n, e in pairs(PD) do if type(e) == "table" and e.Rarity then table.insert(speciesList, n) end end; table.sort(speciesList)

local activePets = {}

local function createPet3D(species, size, petType, mod, tmpl, petId, callback)
    local maxEq = player:GetAttribute("MaxEquippedPets"); if not maxEq or maxEq <= 0 then return end
    local count = 0; for _ in pairs(Models:GetChildren()) do count = count + 1 end
    if count >= math.floor(maxEq) then notify("Max " .. math.floor(maxEq) .. " pets"); return end

    local pet = tmpl:Clone(); pet.Name = species; pcall(function() pet:SetAttribute("PetName", species) end); pet:SetAttribute("CreatedAt", os.clock())

    local ppr = workspace:FindFirstChild("PlayerPetReferences")
    if ppr then
        local pf = ppr:FindFirstChild(player.Name)
        if pf then
            local sn = "VisualPet_" .. petId; pet:SetAttribute("Owner", player.Name); pet:SetAttribute("OwnerSlot", sn)
            if not pf:FindFirstChild(sn) then
                local sp = Instance.new("Part"); sp.Name = sn; sp.Anchored = true; sp.Transparency = 1; sp.Size = Vector3.new(1, 1, 1); sp.CanCollide = false; sp.CanQuery = false; sp.CanTouch = false
                sp:SetAttribute("PetSpecies", species); sp:SetAttribute("PetSize", size or nil); sp:SetAttribute("PetType", petType or nil); sp.Parent = pf
            end
        end
    end

    pet.Parent = Models
    local rn = RO[species] or "RootPart"; local pr = pet:FindFirstChild(rn) or pet:FindFirstChild("Torso")
    if not pr then for _, c in pairs(pet:GetChildren()) do if c:IsA("BasePart") then pr = c; break end end end
    for _, d in pairs(pet:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.Massless = true end end
    pr.Anchored = true; pet.PrimaryPart = pr
    local pv = pr:FindFirstChild("PetPivot") or Instance.new("Attachment"); pv.Name = "PetPivot"; pv.Parent = pr
    for _, d in pairs(pet:GetDescendants()) do if d:IsA("BasePart") and d ~= pr then d.Anchored = false end end; pr.Transparency = 1
    local sc = (size ~= "" and (mod[size .. "Scale"] or PS.Scales[size])) or 1
    if sc ~= 1 then pcall(function() pet:ScaleTo(sc) end) end
    if petType == "Rainbow" then pet:SetAttribute("PetType", "Rainbow") end
    local fo = (FO[species] or 0.5) * sc
    local sp = CFrame.Angles(math.rad(mod.Pivot.X), math.rad(mod.Pivot.Y), math.rad(mod.Pivot.Z))
    local isF = mod.IsFlying == true; local wS = mod.WanderSpeed or 6; local hJ = mod.WanderHeightJitter or 2

    local animTracks = {}
    local af = pet:FindFirstChild("Animations")
    local ac = pet:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController")
    local at = ac:FindFirstChildOfClass("Animator") or Instance.new("Animator")
    ac.Parent = pet; at.Parent = ac
    if af and at then for _, o in pairs(af:GetChildren()) do if o:IsA("Animation") and o.AnimationId ~= "" then local ok, t = pcall(function() return at:LoadAnimation(o) end); if ok then t.Looped = true; t.Priority = Enum.AnimationPriority.Movement; animTracks[o.Name] = t end end end end
    local curAnim = ""
    local function resolveAnim(name) if animTracks[name] then return name end; if name == "Idle" then if animTracks["FlyIdle"] then return "FlyIdle" end; if animTracks["GroundIdle"] then return "GroundIdle" end; if animTracks["Breathe"] then return "Breathe" end end; return nil end
    local function playAnim(name, fade) fade = fade or 0.2; local r = resolveAnim(name); if not r or r == curAnim then return end; for a, b in pairs(animTracks) do if a == r then b:Play(fade) elseif b.IsPlaying then b:Stop(fade) end end; curAnim = r end

    local sd = SO[count + 1] or { x = 0, z = 5 }; local scf = CFrame.new(sd.x, isF and 0.5 or 0, sd.z)
    local hh = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hh then pr.CFrame = hh.CFrame * scf; if not isF then pr.CFrame = pr.CFrame * CFrame.new(0, fo, 0) end end
    if isF then playAnim("Fly", 0.1) else playAnim("Walk", 0.1) end

    local st = { ss = 0, ly = 0, lvp = nil, lvt = nil, lp = hh and hh.Position or Vector3.new(), wg = nil, st2 = 0, ws = 0, nwg = nil, tr = false, tt = nil, lgy = nil, rp = nil, flPh = mod.AlwaysFlying and "Flying" or "Grounded", flH = mod.AlwaysFlying and (mod.AirHeight or 5) * 0.6 or 0, flSt = os.clock(), flLH = nil, flWk = nil, flTm = os.clock() }
    local function getSlotCF()
        local pts = {}; for _, p in pairs(Models:GetChildren()) do table.insert(pts, { model = p, time = p:GetAttribute("CreatedAt") or 0 }) end
        table.sort(pts, function(a, b) return a.time < b.time end)
        local rank = 0; for i, p in ipairs(pts) do if p.model == pet then rank = i; break end end; if rank == 0 then rank = #pts end
        local sd2 = SO[rank] or { x = 0, z = 5 }; return CFrame.new(sd2.x, isF and 0.5 or 0, sd2.z)
    end
    local function getBounds()
        local g = workspace:FindFirstChild("Gardens"); if not g then return nil end; local pid = player:GetAttribute("PlotId"); if not pid then return nil end
        local pl = g:FindFirstChild("Plot" .. pid); if not pl then return nil end; local vf = pl:FindFirstChild("Visual"); if not vf then return nil end
        local ta = vf:FindFirstChild("Move"); if not ta then return nil end; local c = ta.Position; local s = ta.Size
        return { x1 = c.X - s.X / 2, x2 = c.X + s.X / 2, z1 = c.Z - s.Z / 2, z2 = c.Z + s.Z / 2, cy = c.Y }
    end
    local function randPos(b) if not b then return nil end; return Vector3.new(b.x1 + 5 + math.random() * (b.x2 - b.x1 - 10), b.cy + 1 + (math.random() * 2 - 1) * hJ, b.z1 + 5 + math.random() * (b.z2 - b.z1 - 10)) end

    local hb; hb = RunSvc.Heartbeat:Connect(function(dt)
        if not pr or not pr.Parent then if hb then hb:Disconnect() end; return end
        local ch = player.Character; if not ch then return end; local hrp = ch:FindFirstChild("HumanoidRootPart"); local hum = ch:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        local aH = mod.FollowAirHeight or (mod.AirHeight or 5) * 0.6; local ldt = 2; local tod = mod.TakeoffDuration or 0.8
        local function updateFlight(walk)
            if not isF then return end
            if walk ~= st.flWk then st.flWk = walk; st.flTm = os.clock() end
            local ok = (os.clock() - st.flTm) > 0.15
            if st.flPh == "Grounded" then st.flH = 0; if walk and ok then st.flPh = "Takeoff"; st.flSt = os.clock() end
            elseif st.flPh == "Takeoff" then local p = math.clamp((os.clock() - st.flSt) / tod, 0, 1); st.flH = aH * p; if walk then if p >= 1 then st.flPh = "Flying"; st.flH = aH end elseif ok then st.flPh = "Landing"; st.flSt = os.clock(); st.flLH = st.flH end
            elseif st.flPh == "Flying" then st.flH = aH; if not walk and ok then st.flPh = "Landing"; st.flSt = os.clock(); st.flLH = aH end
            elseif st.flPh == "Landing" then local p = math.clamp((os.clock() - st.flSt) / ldt, 0, 1); st.flH = (st.flLH or aH) * (1 - p); if walk and ok then st.flPh = "Takeoff"; st.flSt = os.clock() elseif p >= 1 then st.flH = 0; st.flPh = "Grounded" end end
            if st.flPh == "Landing" and st.flH > 0 and st.rp then local fPos = pr.Position - Vector3.new(0, fo, 0); local gY = getGroundY(fPos, st.rp); if gY and (fPos.Y - gY) < 0.5 * sc then st.flPh = "Grounded"; st.flH = 0 end end
        end
        local held = false; local tool = nil
        for _, tp in pairs(ch:GetChildren()) do if tp:IsA("Tool") and tp:GetAttribute("VisualPetId") == petId then held = true; tool = tp; break end end
        if held and tool then
            if pet.Parent ~= tool then pet.Parent = tool; local handle = tool:FindFirstChild("Handle"); if handle then local w = Instance.new("WeldConstraint"); w.Name = "PetWeld"; w.Part0 = handle; w.Part1 = pr; w.Parent = pr end; pr.Anchored = false; pr.CanCollide = false; pr.CanQuery = false; pr.CanTouch = false; pr.Massless = true end
            playAnim("FlyIdle"); return
        else
            if pet.Parent ~= Models then pet.Parent = Models; pr.Anchored = true; local w = pr:FindFirstChild("PetWeld"); if w then w:Destroy() end end
        end
        local now = os.clock(); local pp = hrp.Position; local cp = pr.Position
        local iG = player:GetAttribute("IsInOwnGarden") == true; local b = getBounds()
        if not st.rp then st.rp = RaycastParams.new(); st.rp.FilterDescendantsInstances = { ch, Models } end
        if not iG and (pp - st.lp).Magnitude > 15 then local tg = hrp.CFrame * getSlotCF(); pr.CFrame = tg * CFrame.Angles(0, st.ly, 0) * sp; st.ss = 0; st.lvp = tg.Position; st.lvt = now; st.lp = pp; st.wg = nil; st.tr = false; st.tt = nil; return end
        st.lp = pp
        if iG and b then
            if not st.rp then st.rp = RaycastParams.new(); local sz2 = {}; for i = 1, 8 do local p2 = workspace.Gardens:FindFirstChild("Plot" .. i); if p2 then local psr = p2:FindFirstChild("PlotSizeReference"); if psr then table.insert(sz2, psr) end; local v2 = p2:FindFirstChild("Visual"); if v2 then local r2 = v2:FindFirstChild("PlotSizeReferenceVisual"); if r2 then table.insert(sz2, r2) end end end end; local sfz2 = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("SafeZones") and workspace.Map.SafeZones:FindFirstChild("Part") or nil; local ex2 = { ch, Models }; for _, o in pairs(sz2) do table.insert(ex2, o) end; if sfz2 then table.insert(ex2, sfz2) end; st.rp.FilterDescendantsInstances = ex2 end
            local function gY(x, z) return isF and b.cy or getGroundY(Vector3.new(x, cp.Y, z), st.rp) end
            if not st.wg and not st.tr then st.tt = randPos(b); st.tr = true; st.wg = st.tt; while st.tt and (cp - st.tt).Magnitude < 8 do st.tt = randPos(b) end; st.wg = st.tt end
            if st.tr then
                local d = st.tt - cp; local ds = d.Magnitude; local spd2 = wS * math.max(1, hum.WalkSpeed / 16) * dt; local step = math.min(spd2, ds); local np = cp + d.Unit * step
                updateFlight(true); local gy = gY(np.X, np.Z); local ty = math.atan2(-d.Unit.X, -d.Unit.Z); st.ly = st.ly + ((ty - st.ly + math.pi) % (2 * math.pi) - math.pi) * math.clamp(8 * dt, 0, 1); pr.CFrame = CFrame.new(np.X, gy + fo + st.flH, np.Z) * CFrame.Angles(0, st.ly, 0) * sp
                if step > 0.3 then playAnim("Fly") elseif isF and st.flH <= 0.01 then playAnim("GroundIdle") else playAnim("FlyIdle") end
                if ds < 5 then st.tr = false; st.tt = nil; st.ws = 0; st.st2 = 0; st.nwg = randPos(b); while st.nwg and (cp - st.nwg).Magnitude < 8 do st.nwg = randPos(b) end end
            else
                if st.ws == 0 then st.st2 = st.st2 + dt; updateFlight(isF); if isF and st.flH <= 0.01 then playAnim("GroundIdle") else playAnim("FlyIdle") end; if st.st2 >= 1.7 then st.ws = 1; st.st2 = 0 end
                elseif st.ws == 1 then local d = (st.nwg - cp); local ty = math.atan2(-d.Unit.X, -d.Unit.Z); local yd = (ty - st.ly + math.pi) % (2 * math.pi) - math.pi; st.ly = st.ly + yd * math.clamp(4 * dt, 0, 1); pr.CFrame = CFrame.new(cp) * CFrame.Angles(0, st.ly, 0) * sp; updateFlight(isF); if isF and st.flH <= 0.01 then playAnim("GroundIdle") else playAnim("FlyIdle") end; if math.abs(yd) < 0.1 then st.wg = st.nwg; st.ws = 2; st.st2 = 0 end
                elseif st.ws == 2 then local d = st.wg - cp; local ds = d.Magnitude; if ds < 3 then st.ws = 0; st.st2 = 0; st.nwg = randPos(b); while st.nwg and (cp - st.nwg).Magnitude < 8 do st.nwg = randPos(b) end else local step = math.min(wS * dt, ds); local np = cp + d.Unit * step; np = Vector3.new(math.clamp(np.X, b.x1 + 2, b.x2 - 2), np.Y, math.clamp(np.Z, b.z1 + 2, b.z2 - 2)); local gy = gY(np.X, np.Z); updateFlight(true); local ty = math.atan2(-d.Unit.X, -d.Unit.Z); st.ly = st.ly + ((ty - st.ly + math.pi) % (2 * math.pi) - math.pi) * math.clamp(8 * dt, 0, 1); pr.CFrame = CFrame.new(np.X, gy + fo + st.flH, np.Z) * CFrame.Angles(0, st.ly, 0) * sp; playAnim("Fly") end end
            end
        else
            st.wg = nil; st.tr = false; st.tt = nil; st.ws = 0; st.st2 = 0
            local tcf = hrp.CFrame * getSlotCF(); local tp = tcf.Position; local lf = 1 - math.exp(-60 * dt)
            local dx = tp.X - cp.X; local dz = tp.Z - cp.Z; local d = math.sqrt(dx * dx + dz * dz); local spd2 = 14 * math.max(1, hum.WalkSpeed / 16) * dt; local nx, nz
            if d <= 0.05 or d <= spd2 then nx, nz = tp.X, tp.Z else local s = spd2 / math.max(lf, 0.001); nx = cp.X + dx / d * s; nz = cp.Z + dz / d * s end
            local ty; local mv2 = Vector3.new(nx - cp.X, 0, nz - cp.Z); local ms2 = mv2.Magnitude / math.max(dt, 0.001)
            if isF and mod.AlwaysFlying then
                if ms2 > 0.5 and mv2.Magnitude > 0.0001 then local d2 = mv2.Unit; ty = math.atan2(-d2.X, -d2.Z) else ty = math.atan2(-tcf.LookVector.X, -tcf.LookVector.Z) end
                st.ly = st.ly + ((ty - st.ly + math.pi) % (2 * math.pi) - math.pi) * math.clamp(12 * dt, 0, 1); pr.CFrame = pr.CFrame:Lerp(CFrame.new(nx, tp.Y, nz) * CFrame.Angles(0, st.ly, 0) * sp, lf)
            elseif isF then
                local moving = hum.MoveDirection.Magnitude > 0 or d > 1; if moving then st.flH = math.min(aH, st.flH + dt * aH / 0.8) else st.flH = math.max(0, st.flH - dt * aH / 2) end
                st.rp.FilterDescendantsInstances = { ch, Models }; local gy = getGroundY(Vector3.new(nx, nz, cp.Y), st.rp) or st.lgy or cp.Y
                st.lgy = st.lgy or gy; local sf = math.clamp(18 * dt, 0, 1); st.lgy = st.lgy + (gy - st.lgy) * sf
                local groundY = st.lgy + fo; local v290 = st.flH / (aH + 0.001); local targetY = groundY * (1 - v290) + tp.Y * v290
                if ms2 > 0.5 and mv2.Magnitude > 0.0001 then local d2 = mv2.Unit; ty = math.atan2(-d2.X, -d2.Z) else ty = math.atan2(-tcf.LookVector.X, -tcf.LookVector.Z) end
                st.ly = st.ly + ((ty - st.ly + math.pi) % (2 * math.pi) - math.pi) * math.clamp(12 * dt, 0, 1); pr.CFrame = pr.CFrame:Lerp(CFrame.new(nx, targetY, nz) * CFrame.Angles(0, st.ly, 0) * sp, lf)
            else
                st.rp = st.rp or RaycastParams.new(); local sz2 = {}; for i = 1, 8 do local p2 = workspace.Gardens:FindFirstChild("Plot" .. i); if p2 then local psr = p2:FindFirstChild("PlotSizeReference"); if psr then table.insert(sz2, psr) end; local pl2 = p2:FindFirstChild("Plants"); if pl2 then table.insert(sz2, pl2) end; local v2 = p2:FindFirstChild("Visual"); if v2 then local r2 = v2:FindFirstChild("PlotSizeReferenceVisual"); if r2 then table.insert(sz2, r2) end end end end; local sfz2 = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("SafeZones") and workspace.Map.SafeZones:FindFirstChild("Part") or nil; local ex2 = { ch, Models }; for _, o in pairs(sz2) do table.insert(ex2, o) end; if sfz2 then table.insert(ex2, sfz2) end; st.rp.FilterDescendantsInstances = ex2
                local gy = getGroundY(Vector3.new(nx, cp.Y, nz), st.rp) or st.lgy or cp.Y; st.lgy = st.lgy or gy; local sf = math.clamp(18 * dt, 0, 1); st.lgy = st.lgy + (gy - st.lgy) * sf; local targetY = st.lgy + fo
                if ms2 > 0.5 and mv2.Magnitude > 0.0001 then local d2 = mv2.Unit; ty = math.atan2(-d2.X, -d2.Z) else ty = math.atan2(-tcf.LookVector.X, -tcf.LookVector.Z) end
                st.ly = st.ly + ((ty - st.ly + math.pi) % (2 * math.pi) - math.pi) * math.clamp(12 * dt, 0, 1); pr.CFrame = pr.CFrame:Lerp(CFrame.new(nx, targetY, nz) * CFrame.Angles(0, st.ly, 0) * sp, lf)
            end
            local vp = pr.Position; if st.lvp and st.lvt then local td = math.max(0.001, now - st.lvt); local dm = (vp - st.lvp).Magnitude; if dm < 50 then local f = math.clamp(dt * 6, 0, 1); st.ss = st.ss * (1 - f) + (dm / td) * f end end; st.lvp = vp; st.lvt = now
            if isF then if st.flH <= 0.01 then playAnim("GroundIdle") elseif st.ss > 2 then playAnim("Fly") elseif st.ss < 0.6 then playAnim("FlyIdle") elseif curAnim == "Fly" then playAnim("Fly") else playAnim("FlyIdle") end else if st.ss > 2 then playAnim("Walk") elseif st.ss < 0.6 then playAnim("Idle") elseif curAnim == "Walk" then playAnim("Walk") else playAnim("Idle") end end
        end
    end)

    activePets[petId] = { cleanup = function() if hb then hb:Disconnect() end; for _, t in pairs(animTracks) do t:Stop(); t:Destroy() end; if pet and pet.Parent then pet:Destroy() end end }

    pcall(function()
        local sf = player.PlayerGui.PetList.Frame.Notepad.ScrollingFrame; local tpl = sf:FindFirstChild("Template"); if not tpl then return end
        local dn = PD.GetDisplayName(species, size) or species; local pi = PD.GetImage(species, size) or ""; local rr = (PD[species] or {}).Rarity or "Common"
        local en = tpl:Clone(); en.Name = "PetEntry_" .. petId; en.Visible = true; local mf = en:FindFirstChild("Main_Frame")
        if mf then
            local ig = mf:FindFirstChild("PetImage"); if ig then ig.Image = pi; if petType == "Rainbow" and AG then AG:AddRainbowColor(ig, "ImageColor3") end end
            local lb = mf:FindFirstChild("TextLabel")
            if lb then
                lb.Text = dn; local cl = lb:FindFirstChild("TextLabel")
                if cl then cl.Text = dn
                    if petType == "Rainbow" then cl.TextColor3 = Color3.new(1, 1, 1); local g = Instance.new("UIGradient"); g.Color = RainbowSeq; g.Parent = cl; if AG then AG:Add(g) end
                    elseif rr == "Super" then cl.TextColor3 = Color3.new(1, 1, 1); local g = Instance.new("UIGradient"); g.Color = RainbowSeq; g.Parent = cl
                    elseif RarityColors[rr] then cl.TextColor3 = RarityColors[rr] elseif rr == "Secret" then cl.TextColor3 = Color3.new(1, 1, 1) end end
            end
            local iF = mf:FindFirstChild("InfoFrame"); if iF then local iB = iF:FindFirstChild("InfoButton"); if iB and PC then iB.Activated:Connect(function() pcall(function() PC:ShowPetInfo(species, size, petType) end) end) end end
            local uq = mf:FindFirstChild("Unequip")
            if uq then
                uq.Activated:Connect(function()
                    activePets[petId].cleanup(); en:Destroy(); activePets[petId] = nil
                    pcall(function() local lb2 = player.PlayerGui.PetList.Frame.Header.TextLabel; local me = player:GetAttribute("MaxEquippedPets") or 4; local t = 0; local sf2 = player.PlayerGui.PetList.Frame.Notepad.ScrollingFrame; if sf2 then for _, c in pairs(sf2:GetChildren()) do if c:IsA("Frame") and c.Name:find("PetEntry_") then t = t + 1 end end end; lb2.Text = t .. "/" .. math.floor(me) .. " Active"; local cl2 = lb2:FindFirstChild("TextLabel"); if cl2 then cl2.Text = lb2.Text end; notify(t .. "/" .. math.floor(me) .. " Pets Equipped!") end)
                    spawnPetTool(species, size, petType)
                end)
            end
        end; en.Parent = sf
    end)

    if callback then callback() end
    pcall(function()
        local lb = player.PlayerGui.PetList.Frame.Header.TextLabel; local cl = lb:FindFirstChild("TextLabel"); local me = player:GetAttribute("MaxEquippedPets") or 4; local t = 0
        local sf = player.PlayerGui.PetList.Frame.Notepad.ScrollingFrame; if sf then for _, c in pairs(sf:GetChildren()) do if c:IsA("Frame") and c.Name:find("PetEntry_") then t = t + 1 end end end
        lb.Text = t .. "/" .. math.floor(me) .. " Active"; if cl then cl.Text = lb.Text end; notify(t .. "/" .. math.floor(me) .. " Pets Equipped!")
    end)
end

function spawnPetTool(species, size, petType)
    species = species or "IceSerpent"; size = size or ""; petType = petType or ""
    local mod = PM[species]; if not mod then notify("Unknown: " .. species); return end
    local tmpl = RS.Assets.Pets:FindFirstChild(mod.AssetName or species); if not tmpl then return end
    local petId = HS:GenerateGUID(false)
    pcall(function()
        local t = Instance.new("Tool"); t.Name = PD.GetDisplayName(species, size) or species; t.CanBeDropped = true; t.RequiresHandle = true
        t:SetAttribute("_Visual", true); t:SetAttribute("Pet", species); t:SetAttribute("VisualPetId", petId); t:SetAttribute("PetSize", size or nil); t:SetAttribute("PetType", petType or nil)
        local img = PD.GetImage(species, size); if img and img ~= "" then t.TextureId = img end
        local hg = mod.HandGrip or Vector3.new()
        local handle = Instance.new("Part"); handle.Name = "Handle"; handle.Size = Vector3.new(1, 1, 1); handle.Transparency = 1
        handle.CanCollide = false; handle.CanQuery = false; handle.CanTouch = false; handle.Massless = true; handle.Parent = t
        t.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(hg.X), math.rad(hg.Y), math.rad(hg.Z))
        t.Activated:Connect(function() createPet3D(species, size, petType, mod, tmpl, petId, function() pcall(function() t:Destroy() end) end) end)
        t.Parent = player:WaitForChild("Backpack")
    end)
end

getgenv().SpawnPet = spawnPetTool
getgenv().SpawnPetTool = spawnPetTool

-- Live pet count updater
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local lb = player.PlayerGui.PetList.Frame.Header.TextLabel; local cl = lb:FindFirstChild("TextLabel"); local me = player:GetAttribute("MaxEquippedPets") or 4; local t = 0
            local sf = player.PlayerGui.PetList.Frame.Notepad.ScrollingFrame
            if sf then for _, c in pairs(sf:GetChildren()) do if c:IsA("Frame") and c.Name:find("PetEntry_") then t = t + 1 end end end
            local tx = t .. "/" .. math.floor(me) .. " Active"; if lb.Text ~= tx then lb.Text = tx; if cl then cl.Text = tx end end
        end)
    end
end)

print("[UnAlive] Pet Spawner loaded — use SpawnPet(\"IceSerpent\") or SpawnPet(\"Bunny\", \"\", \"Rainbow\")")
