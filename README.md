# MilestoneKeys

> Set enemy-forces % milestones for Mythic+ dungeons and get
> sound / chat / on-screen alerts as you hit each threshold.

Supports **WoW Midnight (12.x)**. All libraries are bundled — no separate Ace3 install needed.

---

## Installation

Drop the `MilestoneKeys/` folder into:

```
World of Warcraft/_retail_/Interface/AddOns/
```

Log in and type `/mk` to open the config panel.

---

## Commands

| Command | Action |
|---|---|
| `/mk` | Open / close the config panel |
| `/milestonekeys` | Same as above |
| `/mk test` | Fire a test alert immediately |

---

## Features

### Milestone alerts
Define up to any number of force-% thresholds (1–100). When enemy forces cross a threshold during a key, you get any combination of:
- **Sound** — one of three built-in sounds (Alarm Horn, Gong, Level Up)
- **Chat** — a message printed to your chat frame
- **Frame** — a large on-screen banner that fades out automatically

Each milestone has independent Sound / Chat / Frame toggles with All / None shortcuts.

### In-run HUD
A persistent, draggable frame lists all enabled milestones during a key. Triggered rows flash and dim with a strikethrough. Position and opacity are saved across sessions. Can be locked to prevent accidental dragging.

### Forces display modes
Choose how forces are shown in alerts and tooltips:
- `85%` — rounded percentage
- `84.9%` — one decimal
- `84.94%` — two decimals
- `382/450` — nominal (raw kill count / total)

### Per-dungeon profiles
Store a separate milestone set for each dungeon. When enabled, the profile matching the active dungeon is used automatically during the run. The config panel auto-selects the current dungeon when opened.

### MDT Route Import
If Mythic Dungeon Tools is installed, the config panel shows a **MDT Route Import** section. Pick a saved route and a pull number to calculate the forces % at that pull, then add it as a milestone with one click.

### Party sync
Optionally broadcasts a party chat message (via `MKSYNV1` prefix) when you cross a milestone, so the group sees your progress.

---

## How It Works

```
CHALLENGE_MODE_START
        │
        ▼
   InitRun()  ──► detects forces criteria slot (isWeightedProgress = true)
        │
        ▼
SCENARIO_CRITERIA_UPDATE (fires on every forces tick)
        │
        ▼
   EvaluateForces()
        │   rawKills (from quantityString) / totalQuantity × 100  =  current %
        ▼
   for each milestone: if pct >= threshold and not triggered
        │
        ▼
   MK_TriggerAlert()  ──► Sound + Chat + Frame
```

Forces progress is read from `C_ScenarioInfo.GetCriteriaInfo()` (falls back to `C_Scenario` on older clients). The forces slot is identified by `isWeightedProgress = true`. Raw kill count is parsed from `quantityString` for sub-percent precision.

---

## Files

```
MilestoneKeys/
├── MilestoneKeys.toc   — Metadata & load order
├── Core.lua            — Event handling, forces detection, milestone eval
├── Alerts.lua          — Sound / chat / frame alert delivery
├── HUD.lua             — In-run milestone tracker HUD
├── UI.lua              — AceGUI config panel
├── Minimap.lua         — LibDBIcon minimap button
├── Sync.lua            — Party broadcast (MKSYNV1 prefix)
├── Predict.lua         — MDT route import & predictive pull alerts
└── Libs/               — Bundled: Ace3, LibDataBroker, LibDBIcon
```
