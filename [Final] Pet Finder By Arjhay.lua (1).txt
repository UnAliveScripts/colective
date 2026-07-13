-- Pet Finder + Auto Buy + Auto Hop + GUI (Multi Pet Filter + Per-Server Limits)
-- LocalScript (executor environment)

if syn and syn.request then request = syn.request end

assert(
	typeof(request) == "function"
	and typeof(isfile) == "function"
	and typeof(makefolder) == "function"
	and typeof(isfolder) == "function"
	and typeof(readfile) == "function"
	and typeof(writefile) == "function",
	"Missing required exploit functions"
)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

repeat task.wait() until game:IsLoaded() and Players.LocalPlayer
local LocalPlayer = Players.LocalPlayer

-- run only in target game
local TARGET_PLACE_ID = 97598239454123
if game.PlaceId ~= TARGET_PLACE_ID then
	return
end

-- stronger auto "press any key" routine once game is loaded
local function pressAnyKeyBurst()
	pcall(function()
		local vim = game:GetService("VirtualInputManager")
		local keys = { Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.E }

		for pass = 1, 3 do
			for _, key in ipairs(keys) do
				vim:SendKeyEvent(true, key, false, game)
				task.wait(0.02)
				vim:SendKeyEvent(false, key, false, game)
				task.wait(0.02)
			end
			task.wait(0.08)
		end
	end)
end

-- light prompt handler for repeated checks (no Space to avoid jump spam)
local function pressPromptLight()
	pcall(function()
		local vim = game:GetService("VirtualInputManager")
		local keys = { Enum.KeyCode.Return, Enum.KeyCode.E }
		for _, key in ipairs(keys) do
			vim:SendKeyEvent(true, key, false, game)
			task.wait(0.02)
			vim:SendKeyEvent(false, key, false, game)
			task.wait(0.02)
		end
	end)
end

-- one-time stronger startup kick
pressAnyKeyBurst()

local lastPressAnyKeyAt = 0
local PRESS_ANY_KEY_COOLDOWN = 1.0

local function hasPressAnyKeyPrompt()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return false end

	for _, ui in ipairs(playerGui:GetDescendants()) do
		if ui:IsA("TextLabel") then
			local txt = string.lower(tostring(ui.Text or ""))
			if string.find(txt, "press any key", 1, true)
				or string.find(txt, "click to skip", 1, true) then
				return true
			end
		end
	end
	return false
end

local function clickSkipPromptIfPresent()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return false end

	local clicked = false
	for _, ui in ipairs(playerGui:GetDescendants()) do
		if ui:IsA("TextButton") then
			local txt = string.lower(tostring(ui.Text or ""))
			if string.find(txt, "click to skip", 1, true) or string.find(txt, "skip", 1, true) then
				pcall(function() ui:Activate() end)
				pcall(function() ui.MouseButton1Click:Fire() end)
				clicked = true
			end
		end
	end

	return clicked
end

-- =========================
-- SETTINGS
-- =========================
local SETTINGS = {
	ScanInterval = 0.25,
	ServerSearchTimeout = 20,
	NoEligibleTargetHopTimeout = 10, -- if no selected/needed pet is found for this long, hop
	HopDelay = 1.5,
	StartDelay = 5,

	TweenSpeed = 30,
	BuyDistance = 10,
	PreBuyDelay = 0.65,
	PostBuyWait = 1.35,
	MaxTweenStepDistance = 14,      -- smaller step helps with moving/far targets
	ApproachTimeout = 16,           -- more time for far moving pets
	SnapDetectDistance = 6,         -- detect low progress earlier
	BuyBurstAttempts = 3,
	BuyBurstDelay = 0.18,

	UsePromptBuy = true,
	ForceInstantPrompt = true,
	PromptMaxDistance = 16,

	MinPlayersInServer = 7,          -- legacy setting used by older hop logic
	MinHopPlayers = 4,               -- preferred minimum players when hopping
	HopMinPlayers = 4,               -- preferred target server population minimum
	HopMaxPlayers = 6,               -- preferred target server population maximum
	VerifyInBackpackBeforeHop = true,
	InventoryVerifyTimeout = 10,
	RequireVerifyToHop = true,       -- do not hop until verify succeeds

	Debug = true,
	PetList = { "Bunny", "Frog", "Owl", "Raccoon", "Monkey", "Robin", "Deer", "Bee", "Unicorn", "Golden Dragonfly" },
	DefaultLimitPerPet = 1,
	MinLimit = 1,
	MaxLimit = 10,
}

-- =========================
-- STATE
-- =========================
local state = {
	autoEnabled = false,
	status = "Idle",
	scriptRunning = true,
	isMinimized = false,
	waitingForVerify = false,
	lastVerifyPetName = nil,

	-- hop anti-spam state
	isHopping = false,
	lastHopAttemptAt = 0,
	hopRetryQueued = false,

	selectedPets = {},
	perPetLimit = {},
	boughtThisServer = {},
}

for _, petName in ipairs(SETTINGS.PetList) do
	state.selectedPets[petName] = true
	state.perPetLimit[petName] = SETTINGS.DefaultLimitPerPet
	state.boughtThisServer[petName] = 0
end

-- =========================
-- SERVER HOP STORAGE
-- =========================
local PlaceId = game.PlaceId
local JobId = game.JobId
local PlaceFolderRoot = "ArjhayHub"
local PlaceFolder = PlaceFolderRoot .. "\\" .. tostring(PlaceId)
local JobIdStorage = PlaceFolder .. "\\JobIdStorage.json"
local UserSettingsPath = PlaceFolder .. "\\PetFinderSettings.json"

local function jencode(v) return HttpService:JSONEncode(v) end
local function jdecode(v) return HttpService:JSONDecode(v) end

if not isfolder(PlaceFolderRoot) then makefolder(PlaceFolderRoot) end
if not isfolder(PlaceFolder) then makefolder(PlaceFolder) end

local visited = { JobIds = {} }
if isfile(JobIdStorage) then
	local ok, decoded = pcall(function()
		return jdecode(readfile(JobIdStorage))
	end)
	if ok and typeof(decoded) == "table" and typeof(decoded.JobIds) == "table" then
		visited = decoded
	end
end

if not table.find(visited.JobIds, JobId) then
	table.insert(visited.JobIds, JobId)
end
writefile(JobIdStorage, jencode(visited))

local function saveUserSettings()
	local payload = {
		selectedPets = state.selectedPets,
		perPetLimit = state.perPetLimit,
		MinHopPlayers = SETTINGS.MinHopPlayers,
		autoEnabled = state.autoEnabled,
	}
	pcall(function()
		writefile(UserSettingsPath, jencode(payload))
	end)
end

local function loadUserSettings()
	if not isfile(UserSettingsPath) then
		return
	end

	local ok, decoded = pcall(function()
		return jdecode(readfile(UserSettingsPath))
	end)
	if not ok or typeof(decoded) ~= "table" then
		return
	end

	if typeof(decoded.selectedPets) == "table" then
		for _, petName in ipairs(SETTINGS.PetList) do
			if typeof(decoded.selectedPets[petName]) == "boolean" then
				state.selectedPets[petName] = decoded.selectedPets[petName]
			end
		end
	end

	if typeof(decoded.perPetLimit) == "table" then
		for _, petName in ipairs(SETTINGS.PetList) do
			local v = tonumber(decoded.perPetLimit[petName])
			if v then
				v = math.floor(v)
				v = math.max(SETTINGS.MinLimit, math.min(SETTINGS.MaxLimit, v))
				state.perPetLimit[petName] = v
			end
		end
	end

	local mhp = tonumber(decoded.MinHopPlayers)
	if mhp then
		mhp = math.floor(mhp)
		SETTINGS.MinHopPlayers = math.max(0, mhp)
	end

	if typeof(decoded.autoEnabled) == "boolean" then
		state.autoEnabled = decoded.autoEnabled
		if state.autoEnabled then
			state.status = "Searching"
		end
	end
end

loadUserSettings()

local function log(...)
	if SETTINGS.Debug then
		print("[PetFinder]", ...)
	end
end

local function setStatus(newStatus)
	state.status = newStatus
end

local function canHopNow()
	if state.waitingForVerify and SETTINGS.RequireVerifyToHop and state.lastVerifyPetName then
		return false
	end
	return true
end

local function normalizePetName(name)
	return string.lower(name)
end

local function petMatchesName(petName, instanceName)
	return string.find(string.lower(instanceName), string.lower(petName), 1, true) ~= nil
end

local function resetServerPetCounters()
	for _, petName in ipairs(SETTINGS.PetList) do
		state.boughtThisServer[petName] = 0
	end
end

local function isPetNeeded(petName)
	if not state.selectedPets[petName] then
		return false
	end
	local limit = state.perPetLimit[petName] or SETTINGS.DefaultLimitPerPet
	local bought = state.boughtThisServer[petName] or 0
	return bought < limit
end

local function allSelectedPetLimitsReached()
	local anySelected = false
	for _, petName in ipairs(SETTINGS.PetList) do
		if state.selectedPets[petName] then
			anySelected = true
			if isPetNeeded(petName) then
				return false
			end
		end
	end
	return anySelected
end

local function selectedPetSummary()
	local chunks = {}
	for _, petName in ipairs(SETTINGS.PetList) do
		if state.selectedPets[petName] then
			local bought = state.boughtThisServer[petName] or 0
			local limit = state.perPetLimit[petName] or SETTINGS.DefaultLimitPerPet
			table.insert(chunks, petName .. ":" .. tostring(bought) .. "/" .. tostring(limit))
		end
	end
	if #chunks == 0 then
		return "None selected"
	end
	return table.concat(chunks, " | ")
end

-- =========================
-- GAME HELPERS
-- =========================
local function getCharacter()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootPart(char)
	return char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("Torso")
end

local function getPetPosition(model)
	if not model or not model.Parent then return nil end
	if model:IsA("Model") then
		if model.PrimaryPart then return model.PrimaryPart.Position end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then return d.Position end
		end
	elseif model:IsA("BasePart") then
		return model.Position
	end
	return nil
end

local function getBuyRemote()
	return ReplicatedStorage
		:WaitForChild("SharedModules")
		:WaitForChild("Packet")
		:WaitForChild("RemoteEvent")
end

local function fireBuy(petInstance)
	local remote = getBuyRemote()
	local buyOpcode = ">" .. string.char(0)
	local args = {
		buffer.fromstring(buyOpcode),
		{ petInstance }
	}
	remote:FireServer(unpack(args))
end

local function findPromptInInstance(instance)
	if not instance then return nil end
	if instance:IsA("ProximityPrompt") then
		return instance
	end
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			return d
		end
	end
	return nil
end

local function tryPromptBuy(targetPet, petKeyword, root)
	if not SETTINGS.UsePromptBuy then
		return false
	end

	local prompt = findPromptInInstance(targetPet)
	if not prompt then
		local map = workspace:FindFirstChild("Map")
		if map then
			local wildRef = map:FindFirstChild("WildPetRef")
			if wildRef then
				for _, refPet in ipairs(wildRef:GetChildren()) do
					if petMatchesName(petKeyword, refPet.Name) then
						prompt = findPromptInInstance(refPet)
						if prompt then
							targetPet = refPet
							break
						end
					end
				end
			end
		end
	end

	if not prompt then
		return false
	end

	local ad = prompt.Parent
	local promptPos = nil
	if ad and ad:IsA("BasePart") then
		promptPos = ad.Position
	end
	if not promptPos then
		promptPos = getPetPosition(targetPet)
	end
	if not promptPos then
		return false
	end

	if root and (root.Position - promptPos).Magnitude > SETTINGS.PromptMaxDistance then
		return false
	end

	if SETTINGS.ForceInstantPrompt then
		pcall(function()
			prompt.HoldDuration = 0
		end)
	end

	local fired = false
	if typeof(fireproximityprompt) == "function" then
		pcall(function()
			fireproximityprompt(prompt, 0)
			fired = true
		end)
	end

	if not fired then
		local vim = game:GetService("VirtualInputManager")
		pcall(function()
			vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
			task.wait(0.08)
			vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
			fired = true
		end)
	end

	return fired
end

local function tweenToPosition(root, targetPos)
	local dist = (targetPos - root.Position).Magnitude
	local duration = math.max(0.05, dist / SETTINGS.TweenSpeed)

	local tween = TweenService:Create(
		root,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(targetPos) }
	)

	tween:Play()
	tween.Completed:Wait()
end

local function safeApproachPet(root, petInstance)
	local started = os.clock()
	local firstPos = getPetPosition(petInstance)
	if not firstPos then return false end

	local targetPos = firstPos + Vector3.new(0, 2.5, 0)
	local lastDistance = (targetPos - root.Position).Magnitude
	local stuckCount = 0

	while (os.clock() - started) <= SETTINGS.ApproachTimeout do
		local livePetPos = getPetPosition(petInstance)
		if livePetPos then
			targetPos = livePetPos + Vector3.new(0, 2.5, 0)
		end

		local currentPos = root.Position
		local toTarget = targetPos - currentPos
		local dist = toTarget.Magnitude

		if dist <= SETTINGS.BuyDistance then
			return true
		end

		local stepDist = math.min(SETTINGS.MaxTweenStepDistance, dist)
		local stepPos = currentPos + toTarget.Unit * stepDist

		tweenToPosition(root, stepPos)
		task.wait(0.12)

		local liveAfter = getPetPosition(petInstance)
		if liveAfter then
			targetPos = liveAfter + Vector3.new(0, 2.5, 0)
		end

		local newDist = (targetPos - root.Position).Magnitude
		local movedCloser = lastDistance - newDist

		if movedCloser < SETTINGS.SnapDetectDistance then
			stuckCount = stuckCount + 1
		else
			stuckCount = 0
		end

		if stuckCount >= 2 then
			local nudgePos = targetPos
			pcall(function()
				root.CFrame = CFrame.new(nudgePos)
			end)
			task.wait(0.24)
			stuckCount = 0
		end

		lastDistance = newDist
	end

	local finalLive = getPetPosition(petInstance)
	if finalLive then
		return ((finalLive + Vector3.new(0, 2.5, 0)) - root.Position).Magnitude <= SETTINGS.BuyDistance
	end
	return false
end

local function normalizeInventoryName(name)
	local s = string.lower(tostring(name or ""))
	s = string.gsub(s, "[^%w%s]", " ")
	s = string.gsub(s, "%s+", " ")
	s = string.gsub(s, "^%s*(.-)%s*$", "%1")
	return s
end

local function hasExactPetInInventory(petName)
	local target = normalizeInventoryName(petName)
	if target == "" then return false end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local character = LocalPlayer.Character

	local function exactOrTokenMatch(normalizedName)
		if normalizedName == target then
			return true
		end
		local pattern = "%f[%w]" .. target .. "%f[%W]"
		return string.find(normalizedName, pattern) ~= nil
	end

	local function containerHas(container)
		if not container then return false end
		for _, obj in ipairs(container:GetDescendants()) do
			local n = obj.Name
			if typeof(n) == "string" then
				local normalized = normalizeInventoryName(n)
				if exactOrTokenMatch(normalized) then
					return true
				end
			end
		end
		return false
	end

	return containerHas(backpack) or containerHas(character)
end

local function waitForPetInInventory(petName, timeoutSec)
	local t0 = os.clock()
	while (os.clock() - t0) <= timeoutSec do
		if hasExactPetInInventory(petName) then
			return true
		end
		task.wait(0.2)
	end
	return false
end

local function findBestEligiblePet()
	local map = workspace:FindFirstChild("Map")
	if not map then return nil, nil end
	local spawns = map:FindFirstChild("WildPetSpawns")
	if not spawns then return nil, nil end

	local bestPetName = nil
	local bestNeed = -math.huge
	local bestInstance = nil

	for _, petInstance in ipairs(spawns:GetChildren()) do
		local name = petInstance.Name
		for _, petName in ipairs(SETTINGS.PetList) do
			if state.selectedPets[petName] and isPetNeeded(petName) and petMatchesName(petName, name) then
				local limit = state.perPetLimit[petName] or SETTINGS.DefaultLimitPerPet
				local bought = state.boughtThisServer[petName] or 0
				local need = limit - bought
				if need > bestNeed then
					bestNeed = need
					bestPetName = petName
					bestInstance = petInstance
				end
			end
		end
	end

	return bestInstance, bestPetName
end

local function listServers(cursor)
	local endpoint = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
	if cursor and cursor ~= "" then
		endpoint = endpoint .. "&cursor=" .. cursor
	end

	local ok, raw = pcall(function()
		return game:HttpGet(endpoint)
	end)
	if not ok or not raw then
		return nil
	end

	local okDecode, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not okDecode or typeof(data) ~= "table" then
		return nil
	end

	return data
end

local hopCachePath = "NotSameServers.json"

local function loadAllIDs()
	local actualHour = os.date("!*t").hour
	local allIDs = {}
	local ok = pcall(function()
		allIDs = HttpService:JSONDecode(readfile(hopCachePath))
	end)
	if not ok or typeof(allIDs) ~= "table" then
		allIDs = { actualHour }
		pcall(function()
			writefile(hopCachePath, HttpService:JSONEncode(allIDs))
		end)
	end
	return allIDs, actualHour
end

local function saveAllIDs(allIDs)
	pcall(function()
		writefile(hopCachePath, HttpService:JSONEncode(allIDs))
	end)
end

local function clickTeleportFailedOkIfPresent()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return false end

	local clicked = false
	for _, ui in ipairs(playerGui:GetDescendants()) do
		if ui:IsA("TextButton") then
			local txt = string.lower(tostring(ui.Text or ""))
			if txt == "ok" then
				local parentText = ""
				if ui.Parent and ui.Parent:IsA("GuiObject") then
					for _, d in ipairs(ui.Parent:GetDescendants()) do
						if d:IsA("TextLabel") then
							parentText = parentText .. " " .. string.lower(tostring(d.Text or ""))
						end
					end
				end
				if string.find(parentText, "teleport failed", 1, true)
					or string.find(parentText, "server is full", 1, true)
					or string.find(parentText, "error code: 772", 1, true) then
					pcall(function()
						ui:Activate()
					end)
					pcall(function()
						ui.MouseButton1Click:Fire()
					end)
					clicked = true
				end
			end
		end
	end
	return clicked
end

local failedServerCooldown = {}
local FAILED_SERVER_RETRY_DELAY = 45
local MIN_FREE_SLOTS_REQUIRED = 2

local function hopServer()
	if state.isHopping then
		-- queue one retry instead of spamming hard-ignore
		state.hopRetryQueued = true
		return
	end

	if state.waitingForVerify and SETTINGS.RequireVerifyToHop and state.lastVerifyPetName then
		log("Hop blocked: verification required for", state.lastVerifyPetName)
		setStatus("Verifying")
		return
	end

	state.isHopping = true
	state.lastHopAttemptAt = os.clock()
	setStatus("Hopping")

	local allIDs, actualHour = loadAllIDs()
	local foundAnything = ""
	local hopSucceeded = false

	local function ensureHourHeader()
		if tonumber(allIDs[1]) ~= tonumber(actualHour) then
			pcall(function()
				delfile(hopCachePath)
			end)
			allIDs = { actualHour }
			saveAllIDs(allIDs)
		end
	end

	local function tryTeleportID(serverID)
		if not table.find(visited.JobIds, serverID) then
			table.insert(visited.JobIds, serverID)
			pcall(function()
				writefile(JobIdStorage, jencode(visited))
			end)
		end

		local ok, err = pcall(function()
			TeleportService:TeleportToPlaceInstance(PlaceId, serverID, LocalPlayer)
		end)

		if ok then
			log("Teleporting to:", serverID)
			hopSucceeded = true
			return true
		end

		-- if teleport fails (e.g., server full), remember and skip this server for a while
		failedServerCooldown[serverID] = os.clock() + FAILED_SERVER_RETRY_DELAY
		log("Teleport failed for server:", serverID, err or "")
		return false
	end

	local function TPReturner()
		local Site
		if foundAnything == "" then
			local ok, data = pcall(function()
				return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
			end)
			if not ok or typeof(data) ~= "table" then
				return false
			end
			Site = data
		else
			local ok, data = pcall(function()
				return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. foundAnything))
			end)
			if not ok or typeof(data) ~= "table" then
				return false
			end
			Site = data
		end

		if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
			foundAnything = Site.nextPageCursor
		else
			foundAnything = ""
		end

		ensureHourHeader()

		for _, v in pairs(Site.data or {}) do
			local Possible = true
			local ID = tostring(v.id)
			local playing = tonumber(v.playing) or 0
			local maxPlayers = tonumber(v.maxPlayers) or 0

			local freeSlots = maxPlayers - playing
			local failedUntil = failedServerCooldown[ID] or 0
			local isCoolingDown = os.clock() < failedUntil

			if ID ~= JobId and freeSlots >= MIN_FREE_SLOTS_REQUIRED and not isCoolingDown then
				for idx, Existing in pairs(allIDs) do
					if idx ~= 1 and ID == tostring(Existing) then
						Possible = false
						break
					end
				end

				if Possible then
					table.insert(allIDs, ID)
					saveAllIDs(allIDs)

					if tryTeleportID(ID) then
						task.wait(1.0)
						return true
					end
					task.wait(0.02)
				end
			end
		end

		return false
	end

	-- retry repeatedly until hop succeeds or attempts exhausted; prioritize repeated attempts around early failures
	local tries = 0
	local maxTries = 60
	while state.scriptRunning and state.autoEnabled and (not hopSucceeded) and tries < maxTries do
		tries = tries + 1
		pcall(function()
			TPReturner()
			if not hopSucceeded and foundAnything ~= "" then
				TPReturner()
			end
		end)

		-- extra retries on the user-requested attempt windows (1,3,4,5,6) and generally keep retrying
		if not hopSucceeded and (tries == 1 or tries == 3 or tries == 4 or tries == 5 or tries == 6) then
			pcall(function()
				TPReturner()
			end)
		end

		task.wait(0.03)
	end

	if not hopSucceeded then
		clickTeleportFailedOkIfPresent()
		log("Hop did not succeed yet; keeping auto loop alive for next retry cycle.")
		setStatus("Searching")
	end

	-- always release hop lock unless teleport actually took us out
	state.isHopping = false
	state.lastHopAttemptAt = os.clock() - ((SETTINGS.HopDelay or 1.5) * 0.2)

	if state.hopRetryQueued and state.autoEnabled and state.scriptRunning then
		state.hopRetryQueued = false
		task.spawn(function()
			task.wait(0.05)
			hopServer()
		end)
	end
end

-- =========================
-- GUI
-- =========================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetFinderGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.new(0, 410, 0, 490)
frame.Position = UDim2.new(0, 20, 0, 90)
frame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 8)
frameCorner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -100, 0, 34)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Text = "ArjhayHub  •  Pet Finder GAG2"
title.TextColor3 = Color3.fromRGB(245, 248, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local minButton = Instance.new("TextButton")
minButton.Size = UDim2.new(0, 34, 0, 26)
minButton.Position = UDim2.new(1, -82, 0, 12)
minButton.BackgroundColor3 = Color3.fromRGB(58, 63, 74)
minButton.Text = "-"
minButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minButton.Font = Enum.Font.GothamBold
minButton.TextSize = 16
minButton.Parent = frame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minButton

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 34, 0, 26)
closeButton.Position = UDim2.new(1, -42, 0, 12)
closeButton.BackgroundColor3 = Color3.fromRGB(171, 63, 74)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Parent = frame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -24, 0, 22)
statusLabel.Position = UDim2.new(0, 12, 0, 48)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: OFF"
statusLabel.TextColor3 = Color3.fromRGB(196, 203, 255)
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.TextSize = 13
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

local summaryLabel = Instance.new("TextLabel")
summaryLabel.Size = UDim2.new(1, -24, 0, 38)
summaryLabel.Position = UDim2.new(0, 12, 0, 70)
summaryLabel.BackgroundTransparency = 1
summaryLabel.Text = "Filter: Bunny:0/2 | Frog:0/2 | Owl:0/2"
summaryLabel.TextColor3 = Color3.fromRGB(145, 215, 255)
summaryLabel.Font = Enum.Font.Gotham
summaryLabel.TextSize = 12
summaryLabel.TextWrapped = true
summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
summaryLabel.TextYAlignment = Enum.TextYAlignment.Top
summaryLabel.Parent = frame

local autoButton = Instance.new("TextButton")
autoButton.Size = UDim2.new(1, -24, 0, 34)
autoButton.Position = UDim2.new(0, 12, 0, 114)
autoButton.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
autoButton.Text = "Auto: OFF"
autoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
autoButton.Font = Enum.Font.GothamBold
autoButton.TextSize = 14
autoButton.Parent = frame

local autoCorner = Instance.new("UICorner")
autoCorner.CornerRadius = UDim.new(0, 8)
autoCorner.Parent = autoButton

local petListFrame = Instance.new("ScrollingFrame")
petListFrame.Name = "PetList"
petListFrame.Size = UDim2.new(1, -24, 0, 330)
petListFrame.Position = UDim2.new(0, 12, 0, 156)
petListFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
petListFrame.BackgroundTransparency = 0.15
petListFrame.BorderSizePixel = 0
petListFrame.ScrollBarThickness = 6
petListFrame.ScrollBarImageColor3 = Color3.fromRGB(92, 102, 122)
petListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
petListFrame.Parent = frame

local petListCorner = Instance.new("UICorner")
petListCorner.CornerRadius = UDim.new(0, 8)
petListCorner.Parent = petListFrame

local petRows = {}
local rowHeight = 40
local rowGap = 8
for i, petName in ipairs(SETTINGS.PetList) do
	local y = (i - 1) * (rowHeight + rowGap)

	local selectBtn = Instance.new("TextButton")
	selectBtn.Size = UDim2.new(0, 172, 0, rowHeight)
	selectBtn.Position = UDim2.new(0, 10, 0, y)
	selectBtn.BackgroundColor3 = Color3.fromRGB(70, 76, 90)
	selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	selectBtn.Font = Enum.Font.GothamBold
	selectBtn.TextSize = 13
	selectBtn.Parent = petListFrame

	local selectCorner = Instance.new("UICorner")
	selectCorner.CornerRadius = UDim.new(0, 6)
	selectCorner.Parent = selectBtn

	local minusBtn = Instance.new("TextButton")
	minusBtn.Size = UDim2.new(0, 36, 0, rowHeight)
	minusBtn.Position = UDim2.new(0, 190, 0, y)
	minusBtn.BackgroundColor3 = Color3.fromRGB(61, 66, 78)
	minusBtn.Text = "-"
	minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	minusBtn.Font = Enum.Font.GothamBold
	minusBtn.TextSize = 18
	minusBtn.Parent = petListFrame

	local minusCorner = Instance.new("UICorner")
	minusCorner.CornerRadius = UDim.new(0, 6)
	minusCorner.Parent = minusBtn

	local limitLabel = Instance.new("TextLabel")
	limitLabel.Size = UDim2.new(0, 105, 0, rowHeight)
	limitLabel.Position = UDim2.new(0, 234, 0, y)
	limitLabel.BackgroundColor3 = Color3.fromRGB(24, 27, 35)
	limitLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	limitLabel.Font = Enum.Font.GothamBold
	limitLabel.TextSize = 13
	limitLabel.Text = "Limit: " .. tostring(state.perPetLimit[petName])
	limitLabel.Parent = petListFrame

	local limitCorner = Instance.new("UICorner")
	limitCorner.CornerRadius = UDim.new(0, 6)
	limitCorner.Parent = limitLabel

	local plusBtn = Instance.new("TextButton")
	plusBtn.Size = UDim2.new(0, 36, 0, rowHeight)
	plusBtn.Position = UDim2.new(0, 345, 0, y)
	plusBtn.BackgroundColor3 = Color3.fromRGB(61, 66, 78)
	plusBtn.Text = "+"
	plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	plusBtn.Font = Enum.Font.GothamBold
	plusBtn.TextSize = 18
	plusBtn.Parent = petListFrame

	local plusCorner = Instance.new("UICorner")
	plusCorner.CornerRadius = UDim.new(0, 6)
	plusCorner.Parent = plusBtn

	petRows[petName] = {
		selectBtn = selectBtn,
		minusBtn = minusBtn,
		plusBtn = plusBtn,
		limitLabel = limitLabel,
	}
end

petListFrame.CanvasSize = UDim2.new(0, 0, 0, (#SETTINGS.PetList * (rowHeight + rowGap)) + 8)

local fullSize = UDim2.new(0, 410, 0, 490)
local minimizedSize = UDim2.new(0, 410, 0, 48)

local function setMinimized(minimized)
	state.isMinimized = minimized
	if minimized then
		frame.Size = minimizedSize
		statusLabel.Visible = false
		summaryLabel.Visible = false
		autoButton.Visible = false
		petListFrame.Visible = false
		for _, row in pairs(petRows) do
			row.selectBtn.Visible = false
			row.minusBtn.Visible = false
			row.plusBtn.Visible = false
			row.limitLabel.Visible = false
		end
		minButton.Text = "+"
	else
		frame.Size = fullSize
		statusLabel.Visible = true
		summaryLabel.Visible = true
		autoButton.Visible = true
		petListFrame.Visible = true
		for _, row in pairs(petRows) do
			row.selectBtn.Visible = true
			row.minusBtn.Visible = true
			row.plusBtn.Visible = true
			row.limitLabel.Visible = true
		end
		minButton.Text = "-"
	end
end

local function refreshGui()
	statusLabel.Text = "Status: " .. tostring(state.status)
	summaryLabel.Text = "Filter: " .. selectedPetSummary()

	if state.autoEnabled then
		autoButton.Text = "Auto: ON"
		autoButton.BackgroundColor3 = Color3.fromRGB(50, 170, 70)
	else
		autoButton.Text = "Auto: OFF"
		autoButton.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
	end

	for _, petName in ipairs(SETTINGS.PetList) do
		local row = petRows[petName]
		if row then
			local enabled = state.selectedPets[petName]
			row.selectBtn.Text = petName .. (enabled and " [ON]" or " [OFF]")
			row.selectBtn.BackgroundColor3 = enabled and Color3.fromRGB(50, 145, 80) or Color3.fromRGB(85, 85, 85)
			row.limitLabel.Text = "Limit: " .. tostring(state.perPetLimit[petName] or SETTINGS.DefaultLimitPerPet)
		end
	end
end

autoButton.MouseButton1Click:Connect(function()
	state.autoEnabled = not state.autoEnabled
	if state.autoEnabled then
		resetServerPetCounters()
		setStatus("Finding Pets")
	else
		setStatus("OFF")
	end
	saveUserSettings()
	refreshGui()
end)

for _, petName in ipairs(SETTINGS.PetList) do
	local row = petRows[petName]
	if row then
		row.selectBtn.MouseButton1Click:Connect(function()
			state.selectedPets[petName] = not state.selectedPets[petName]
			saveUserSettings()
			refreshGui()
		end)

		row.minusBtn.MouseButton1Click:Connect(function()
			local current = state.perPetLimit[petName] or SETTINGS.DefaultLimitPerPet
			current = math.max(SETTINGS.MinLimit, current - 1)
			state.perPetLimit[petName] = current
			saveUserSettings()
			refreshGui()
		end)

		row.plusBtn.MouseButton1Click:Connect(function()
			local current = state.perPetLimit[petName] or SETTINGS.DefaultLimitPerPet
			current = math.min(SETTINGS.MaxLimit, current + 1)
			state.perPetLimit[petName] = current
			saveUserSettings()
			refreshGui()
		end)
	end
end

minButton.MouseButton1Click:Connect(function()
	setMinimized(not state.isMinimized)
end)

closeButton.MouseButton1Click:Connect(function()
	state.scriptRunning = false
	state.autoEnabled = false
	if screenGui then
		screenGui:Destroy()
	end
end)

refreshGui()
setMinimized(false)
saveUserSettings()

-- background watcher: clear teleport failed popup, handle press-any-key prompt, and keep hopping alive
task.spawn(function()
	while state.scriptRunning do
		local now = os.clock()

		if hasPressAnyKeyPrompt() and (now - lastPressAnyKeyAt) >= PRESS_ANY_KEY_COOLDOWN then
			lastPressAnyKeyAt = now
			pressPromptLight()
			clickSkipPromptIfPresent()
		end

		local handled = clickTeleportFailedOkIfPresent()
		if handled and state.autoEnabled then
			if canHopNow() then
				state.isHopping = false
				task.spawn(function()
					hopServer()
				end)
			else
				setStatus("Verifying")
				refreshGui()
			end
		end

		task.wait(0.2)
	end
end)

-- =========================
-- MAIN LOOP
-- =========================
task.wait(SETTINGS.StartDelay)
task.spawn(function()
	while state.scriptRunning do
		if not state.autoEnabled then
			task.wait(0.2)
		else
			if allSelectedPetLimitsReached() then
				if state.waitingForVerify and SETTINGS.RequireVerifyToHop then
					setStatus("Verifying")
					refreshGui()
					task.wait(0.3)
				else
					if canHopNow() then
						log("All selected pet limits reached for this server. Hopping...")
						hopServer()
						task.wait(0.05)
					else
						setStatus("Verifying")
						refreshGui()
						task.wait(0.3)
					end
				end
			end

			local noEligibleStart = os.clock()
			local foundPet, foundPetName = nil, nil

			setStatus("Searching")
			refreshGui()

			while state.scriptRunning and state.autoEnabled do
				if allSelectedPetLimitsReached() then
					break
				end

				foundPet, foundPetName = findBestEligiblePet()
				if foundPet and foundPet.Parent and foundPetName then
					break
				end

				if (os.clock() - noEligibleStart) >= SETTINGS.NoEligibleTargetHopTimeout then
					if state.waitingForVerify and SETTINGS.RequireVerifyToHop then
						setStatus("Verifying")
						refreshGui()
						task.wait(0.3)
					else
						if canHopNow() then
							log("No eligible selected pet found for timeout. Hopping...")
							break
						else
							setStatus("Verifying")
							refreshGui()
						end
					end
				end

				task.wait(SETTINGS.ScanInterval)
			end

			if not state.scriptRunning then
				break
			end

			if not state.autoEnabled then
				setStatus("Idle")
				refreshGui()
				task.wait(0.2)
			else
				if allSelectedPetLimitsReached() then
					if state.waitingForVerify and SETTINGS.RequireVerifyToHop then
						setStatus("Verifying")
						refreshGui()
						task.wait(0.3)
					else
						if canHopNow() then
							hopServer()
							return
						else
							setStatus("Verifying")
							refreshGui()
							task.wait(0.3)
						end
					end
				end

				if foundPet and foundPet.Parent and foundPetName then
					log("Target pet found:", foundPetName, foundPet.Name)
					local character = getCharacter()
					local root = getRootPart(character)

					if root then
						local petPos = getPetPosition(foundPet)
						if petPos then
							setStatus("Tweening")
							refreshGui()
							local reached = safeApproachPet(root, foundPet)

							local checkPos = getPetPosition(foundPet)
							if reached and checkPos and (root.Position - checkPos).Magnitude <= SETTINGS.BuyDistance then
								setStatus("Buying")
								refreshGui()

								task.wait(SETTINGS.PreBuyDelay)

								local bought = false
								for attempt = 1, SETTINGS.BuyBurstAttempts do
									local livePos = getPetPosition(foundPet)
									if livePos and (root.Position - livePos).Magnitude > SETTINGS.BuyDistance then
										setStatus("Re-Approaching")
										refreshGui()
										safeApproachPet(root, foundPet)
										livePos = getPetPosition(foundPet)
									end

									if SETTINGS.UsePromptBuy then
										bought = tryPromptBuy(foundPet, foundPetName, root)
									end

									if not bought then
										pcall(function()
											fireBuy(foundPet)
										end)
									end

									if bought then
										break
									end
									task.wait(SETTINGS.BuyBurstDelay + 0.08)
								end

								task.wait(SETTINGS.PostBuyWait)

								local verified = true
								state.waitingForVerify = true
								state.lastVerifyPetName = foundPetName
								setStatus("Verifying")
								refreshGui()

								if SETTINGS.VerifyInBackpackBeforeHop then
									verified = waitForPetInInventory(foundPetName, SETTINGS.InventoryVerifyTimeout)

									if not verified and SETTINGS.RequireVerifyToHop then
										log("Verification failed; waiting (RequireVerifyToHop=true)")
										while state.scriptRunning and state.autoEnabled do
											setStatus("Verifying")
											refreshGui()
											if hasExactPetInInventory(foundPetName) then
												verified = true
												break
											end
											task.wait(0.3)
										end
									end
								end

								if verified then
									state.waitingForVerify = false
									state.lastVerifyPetName = nil
									state.boughtThisServer[foundPetName] = (state.boughtThisServer[foundPetName] or 0) + 1
									log("Verified buy count:", foundPetName, state.boughtThisServer[foundPetName], "/", state.perPetLimit[foundPetName])
									setStatus("Searching")
									refreshGui()
								else
									state.waitingForVerify = true
									state.lastVerifyPetName = foundPetName
									setStatus("Verifying")
									refreshGui()
								end
							end
						end
					end
				else
					if canHopNow() then
						log("No eligible pet found in timeout window, hopping...")
						hopServer()
						task.wait(0.05)
					else
						setStatus("Verifying")
						refreshGui()
						task.wait(0.3)
					end
				end
			end
		end
	end
end)
