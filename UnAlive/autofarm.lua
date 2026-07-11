-- == UnAlive Master Toggle [STANDALONE] ==
-- Config tab: enables all farm features at once.
-- Load after the individual feature scripts.

local autoFarm = false
local autoBuy = false; local autoPlant = false; local autoHarvest = false; local autoSell = false
local autoExpand = false; local autoDaily = false; local autoPot = false

-- Toggle all farm features on/off
local function setFarmState(enabled)
    autoBuy = enabled; autoPlant = enabled; autoHarvest = enabled; autoSell = enabled
    autoExpand = enabled; autoDaily = enabled; autoPot = enabled
    autoFarm = enabled
    print("[UnAlive] Farm", enabled and "ON" or "OFF")
end

-- Set autoFarm = true to enable all
-- Set autoFarm = false to disable all
