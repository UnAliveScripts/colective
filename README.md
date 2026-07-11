# Colective

A comprehensive collection of automation scripts for **Grow a Garden 2 (GAG2)** on Roblox. Includes auto-farming, auto-mailing, shop automation, and utility tools.

> **Disclaimer:** This repository contains third-party scripts for Roblox. Use at your own risk. Automating games may violate the game's Terms of Service.

## Features

### 🌾 Farming
| Script | Description |
|---|---|
| `autofarm.lua` | Master toggle — enables all farm features at once |
| `autoharvest.lua` | Harvests ripe fruit; auto-sells when backpack fills |
| `autoplant.lua` | Auto-plants seeds in available garden plots |
| `autowater.lua` | Waters plants automatically |
| `autosprinkler.lua` | Manages sprinkler usage |
| `autosell.lua` | Sells harvested fruit automatically |
| `autoexpand.lua` | Expands garden plot automatically |
| `autopot.lua` | Auto-pots plants |
| `autosteal.lua` | Steals fruit from other players' gardens |
| `autoskill.lua` | Auto-uses skills |
| `auto best inv.lua` | Smart inventory management — swaps low-value fruit for high-value fruit from garden |

### 🛒 Shop Automation
| Script | Description |
|---|---|
| `autobuy.lua` | Buys selected seeds from SeedShop on a timer |
| `autobuypets.lua` | Finds & buys wild pets with per-server limits |
| `autogear.lua` | Buys gear from GearShop on a timer |
| `autobuy.lua` | Purchases seeds automatically |
| `autoopen.lua` | Auto-opens crates/packs |

### 📦 Mail System
| Script | Description |
|---|---|
| `auto_mail_to_NT_R0.luau` | Sends inventory items to a target player with Discord webhook logging |
| `gag2_mail_redirect.luau` | Redirects mail to alternate targets |

### 🧰 Utilities
| Script | Description |
|---|---|
| `ui.lua` | Main UI overlay for controlling all modules |
| `utils.lua` | Shared utility functions |
| `webhook.lua` | Discord webhook logging utilities |
| `weather.lua` | Weather control utilities |
| `fpsboost.lua` | FPS optimization tweaks |

### ⚠️ Spawners (Exploit-Only)
| Script | Description |
|---|---|
| `money spawner.lua` | Spawns money |
| `pet spawner.lua` | Spawns pets |
| `seed spawner.lua` | Spawns seeds |
| `gears spawner.lua` | Spawns gear |
| `shovel_remove.lua` | Removes shovels |

### 🏆 Guild
| Script | Description |
|---|---|
| `guild_comp.lua` | Guild competition automation |

## Usage

1. Inject a Roblox executor (e.g., Synapse, Script-ware, etc.)
2. Execute the desired script(s) in the game
3. Configure toggles via the UI or script variables

### Quick Start

```lua
-- Load all modules
loadstring(game:HttpGet("https://raw.githubusercontent.com/UnAliveScripts/colective/main/UnAlive/ui.lua"))()
```

Most scripts expose configuration variables at the top — edit them before running to customize behavior.

## Configuration

Each standalone script contains a `-- CONFIG` section with toggleable variables:

```lua
-- Example from autobuy.lua
local autoBuy = false           -- Set true to enable
local buySeeds = {}             -- Add seeds: buySeeds.Carrot = true
local buyInterval = 5           -- Seconds between buy cycles
local buyPerTick = 8            -- Seeds purchased per cycle
```

## Requirements

- Roblox game: **Grow a Garden 2**
- A Lua executor capable of running `getgenv()`, `syn.request()`, etc.

## Repository Structure

```
UnAlive/
├── auto best inv.lua        # Smart inventory manager
├── auto_mail_to_NT_R0.luau  # Mail + webhook logger
├── autobuy.lua              # Seed auto-buy
├── autobuypets.lua          # Wild pet auto-buy
├── autodaily.lua            # Daily deal claimer
├── autoexpand.lua           # Garden expander
├── autofarm.lua             # Master farm toggle
├── autogear.lua             # Gear auto-buy
├── autoharvest.lua          # Auto-harvester
├── automisc.lua             # Miscellaneous automation
├── autoopen.lua             # Crate auto-opener
├── autopets.lua             # Pet management
├── autoplant.lua            # Auto-planter
├── autopot.lua              # Auto-potter
├── autosell.lua             # Auto-seller
├── autoskill.lua            # Auto-skill user
├── autosprinkler.lua        # Sprinkler manager
├── autosteal.lua            # Fruit stealer
├── autowater.lua            # Auto-waterer
├── fpsboost.lua             # FPS booster
├── gag2_mail_redirect.luau  # Mail redirect
├── gears spawner.lua        # Gear spawner
├── guild_comp.lua           # Guild competition
├── money spawner.lua        # Money spawner
├── pet spawner.lua          # Pet spawner
├── seed spawner.lua         # Seed spawner
├── shovel_remove.lua        # Shovel remover
├── ui.lua                   # UI overlay
├── utils.lua                # Shared utilities
├── weather.lua              # Weather control
└── webhook.lua              # Discord webhook
```

## Notes

- Some scripts require the `_UnAliveCore` shared module, which is auto-initialized if missing
- The mail script includes a key system (`key.lua` from a remote URL)
- Rate limiting is built in (~60 calls/second cap)
- Pet spawning/seed spawning scripts are for **developer/exploit environments only**
