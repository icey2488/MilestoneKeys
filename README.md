# MilestoneKeys

> Set enemy-forces % milestones for Mythic+ dungeons and get
> sound / chat / on-screen alerts as you hit each threshold.

---

## Installation

1. Drop the `MilestoneKeys/` folder into:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
2. The addon requires **Ace3** libraries. Install them via:
   - [CurseForge standalone Ace3](https://www.curseforge.com/wow/addons/ace3)  
   — OR — copy the Libs/ folder from another Ace3 addon you already use.

3. Log in and type `/mk` to open the config panel.

---

## Usage

| Command | Action |
|---|---|
| `/mk` | Open / close the config panel |
| `/milestonekeys` | Same as above |
| `/mk test` | Fire a test alert immediately |

---

## How It Works

```
CHALLENGE_MODE_START
        │
        ▼
   InitRun()  ──► detects forces criteria index dynamically
        │
        ▼
SCENARIO_CRITERIA_UPDATE (fires on every forces tick)
        │
        ▼
   EvaluateForces()
        │   quantity / totalQuantity × 100  =  current %
        ▼
   for each milestone: if pct >= threshold and not triggered
        │
        ▼
   MK_TriggerAlert()  ──► Sound + Chat + Frame
```

Forces progress is read from `C_Scenario.GetCriteriaInfo()`.
The criteria index is detected dynamically each run by inspecting
criteria flags (flag bit `0x80`) so it works across all dungeons
without a lookup table.

---

## Milestone Options

Each milestone has:

| Field | Description |
|---|---|
| **Threshold %** | 1–100, fires once when forces cross this value |
| **Label** | Custom name shown in the alert |
| **Alert Type** | `Sound + Chat`, `Sound Only`, `Chat Only`, `Frame Only` |
| **Enabled** | Toggle without deleting |

Milestones are stored in `SavedVariables` and persist across sessions.
They are reset (un-triggered) automatically at the start of each key.

---

## Midnight API Note

The Midnight expansion introduces more granular dungeon telemetry under
`C_DungeonScore`. Future versions of MilestoneKeys plan to use per-pack
forces data to add **predictive** alerts:

> *"Next pull will push you past 40%"*

This is not available in the current live API but the architecture is
intentionally designed to slot this in via a separate prediction module.

---

## Files

```
MilestoneKeys/
├── MilestoneKeys.toc   — Metadata & load order
├── Core.lua            — Event handling, forces detection, milestone eval
├── Alerts.lua          — Sound / chat / frame alert delivery
├── UI.lua              — AceGUI config panel
└── Libs/               — Ace3 (AceAddon, AceEvent, AceDB, AceGUI)
```
