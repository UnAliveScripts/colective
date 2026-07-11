-- == UnAlive FPS Boost [STANDALONE] ==
-- Settings tab: lowers graphics quality for better performance.
-- Paste into your script. No Net needed.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local fpsBoost = false
local _applied = false

local function apply()
    if _applied then return end; _applied = true
    pcall(function()
        Lighting.GlobalShadows = false; Lighting.FogEnd = 1e6
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("BlurEffect") then e.Enabled = false end
        end
        if sethiddenproperty then pcall(sethiddenproperty, Lighting, "Technology", 1) end
        settings().Rendering.QualityLevel = 1
    end)
    task.spawn(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if not fpsBoost then break end
            if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then d.Enabled = false
            elseif d:IsA("Texture") or d:IsA("Decal") then pcall(function() d.Transparency = 1 end) end
        end
    end)
end

task.spawn(function() while true do if fpsBoost then apply() end; task.wait(3) end end)
