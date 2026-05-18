# MilestoneKeys — API Notes & Technical Reference

Permanent reference for maintainers. Covers lessons reverse-engineered during
the v1.0.x → v1.1.2 development cycle. New API lessons belong here, not in
CHANGELOG entries.

---

## 1. Forces Criteria Detection (TWW / Midnight)

### Which slot is forces?

`isWeightedProgress = true` is the sole reliable signal for the forces criteria
slot in The War Within and Midnight. The pre-TWW `flags & 0x80` bit-check no
longer works — all criteria flags are `0` in the current API.

Boss-kill slots use `criteriaType = 165` with `isWeightedProgress = false`.

### Field layout for the forces slot

| Field | Meaning |
|---|---|
| `isWeightedProgress` | `true` → this is the forces criteria slot |
| `quantity` | Integer percent 0–100 (low precision; do **not** use as the primary value) |
| `totalQuantity` | Total enemies needed for 100% completion |
| `quantityString` | `"<rawKills>%"` — raw enemy kill count with a misleading `%` suffix; **not a percentage string**; parse leading digits only: `tonumber(info.quantityString:match("(%d+)"))` |

Decimal-precision percent must be computed by the addon:

```lua
rawKills = tonumber(info.quantityString:match("(%d+)"))
pct = (rawKills / info.totalQuantity) * 100
```

Clamp to `[0, 100]` after computing to guard against malformed API output.

### Regression history

| Version | Bug | Root cause |
|---|---|---|
| pre-v1.0.9 | Milestones never fired | `flags & 0x80` detection selected a boss-kill slot instead of forces slot |
| v1.0.9 | Fixed detection; treated `quantity` as raw count and divided by `totalQuantity` | `totalQuantity` was 0 in some builds — division-by-zero / wrong result |
| v1.0.11 | Used `quantity` directly as integer %; still wrong | `quantity` is low-precision (e.g. 21 for 21.52%) |
| dev-fix-2 | Parsed `quantityString` as decimal via `[%d%.]+` | `"237%"` parsed as `237.0` — wildly wrong |
| v1.1.0 | Extract `(%d+)` from `quantityString`, divide by `totalQuantity` | Correct; confirmed in-game |

**Do not revert the `(%d+)` + division formula** without re-testing in-game.

### Multi-step scenarios

Some dungeons (e.g. Pit of Saron) are multi-step scenarios. The forces criteria
slot may live in a different step from the one active at run start.
`DetectForcesIndex` must be able to handle cases where the forces slot is not
found in the current step — either by re-running detection on each
`SCENARIO_CRITERIA_UPDATE`, or by iterating across steps.

### API wrapper pattern

Always call via safe wrappers that fall back across client generations:

```lua
local function GetCriteriaInfo(index)
    if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
        return C_ScenarioInfo.GetCriteriaInfo(index)
    elseif C_Scenario and C_Scenario.GetCriteriaInfo then
        return C_Scenario.GetCriteriaInfo(index)
    end
    return nil
end
```

Call `GetCriteriaInfo` fresh on every evaluation — do **not** cache the returned
table across `SCENARIO_CRITERIA_UPDATE` events.

---

## 2. AceGUI Backdrop Texture Gotchas

### Why `SetBackdropColor(r,g,b,1)` can still look transparent

Three independent alpha multipliers stack on every rendered pixel:

1. **Texture per-pixel alpha** — baked into the image file itself
2. **Vertex color alpha** — set by `SetBackdropColor(r, g, b, alpha)`
3. **Frame-level alpha** — set by `frame:SetAlpha(alpha)`

Final pixel alpha = `texture_alpha × vertex_alpha × frame_alpha`.

`SetBackdropColor(0,0,0,1)` sets vertex alpha to 1, but it **cannot push the
result past the ceiling imposed by the texture's own alpha channel**.

### AceGUI's default backdrop texture

AceGUI's `Frame` (and `Window`, `InlineGroup`) uses:

```
bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"
```

This texture has semi-transparent pixels baked in. Even with
`SetBackdropColor(0,0,0,1)`, the panel remains visibly transparent at the
maximum slider setting.

### Fix: replace bgFile with WHITE8x8

`Interface\\Buttons\\WHITE8x8` is a solid 1×1 white pixel with no per-pixel
alpha. Combined with `SetBackdropColor(r,g,b,alpha)`, it gives full opacity
control with no baked-in ceiling.

```lua
local function ApplyPanelOpacity(frame, alpha)
    if not frame or not frame.frame then return end
    local root = frame.frame
    if not root._mkBgPatched then
        root:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
        root._mkBgPatched = true
    end
    root:SetBackdropColor(0, 0, 0, alpha)
end
```

The `_mkBgPatched` flag prevents repeated `SetBackdrop` calls on every slider
drag. Store it on the WoW `Frame` object (the `.frame` field of the AceGUI
widget), not on the AceGUI widget itself, so it survives widget recycling.

This same pattern is used by `HUD.lua` and `Alerts.lua` — both use
`Interface\\Buttons\\WHITE8x8` + `SetBackdropColor(0,0,0,alpha)` with no
`SetAlpha` call on the frame.

### AceGUI Frame child structure (for diagnostics)

If you need to enumerate AceGUI Frame children for debugging:

| Index | Object type | Role |
|---|---|---|
| child[1] | Button | Close button |
| child[2] | Button + BackdropTemplate | Status bar (`statusbg`) |
| child[3] | Frame | Title bar (FontString only, no regions) |
| child[4] | Frame | `sizer_se` resize grip (2× BACKGROUND line textures) |
| child[5] | Frame | `sizer_s` resize grip |
| child[6] | Frame | `sizer_e` resize grip |
| child[7] | Frame | Content frame (no regions) |

The two `BACKGROUND` textures on child[4] are the diagonal resize-grip lines,
**not** the panel body background. The body background is controlled by the root
frame's `BackdropTemplate` backdrop.

---

## 3. Sound Playback on Midnight

### PlaySound vs PlaySoundFile

| Function | First argument | Use case |
|---|---|---|
| `PlaySound(id, channel)` | SOUNDKIT constant or numeric soundKit ID | Built-in game sounds |
| `PlaySoundFile(file, channel)` | File path string or numeric FileDataID | External / verified-ID sounds |

SoundKit IDs resolved from `SOUNDKIT.*` enum values are stable across patches.
Hardcoded numeric FileDataIDs can shift between patches without warning.

Prefer:
```lua
local id = (SOUNDKIT and SOUNDKIT.UI_RAID_WARNING) or 567397  -- fallback
PlaySound(id, "SFX")
```

If using `PlaySoundFile` with a numeric FileDataID (as MilestoneKeys currently
does), cross-reference against BigWigs `Media.lua` or similar verified sources
and re-test after each major patch.

### Channel: use "SFX", not "Master"

`"Master"` routes through an audio path that produces no audible output on some
systems. `"SFX"` is the correct channel for in-game alert sounds.

### Lua closure capture in sound preview loops

In a button-creation loop, capture the key into a local before the callback:

```lua
for _, snd in ipairs(sounds) do
    local k = snd.key   -- capture per-iteration
    btn:SetScript("OnClick", function()
        MK_PlaySound(k)
    end)
end
```

Without `local k`, all button callbacks share the same upvalue and play
whichever sound `snd.key` last pointed to when the loop ended.

---

## 4. AceDB Profile Structure

### Per-dungeon milestone profiles

Keyed by `C_ChallengeMode.GetActiveChallengeMapID()`. These IDs are stable for
persistent dungeons across expansions, but new dungeons each season receive new
IDs — design for additive introduction (never remap existing IDs).

Fallback when a saved dungeon profile is empty: use the global milestones list.
Surface this fallback visibly in the UI rather than silently falling back.

### AceGUI frame position persistence

`AceGUI Frame:SetStatusTable(tbl)` handles position and size persistence
automatically. It writes on close and resize, and reads on open. Do not
reimplement this manually. The status table is backed by `db.profile.uiState`.

---

## 5. MDT Integration Data Structure

Routes and pull data are stored differently from what their documentation (or
intuition) suggests:

| What you want | Where it actually lives |
|---|---|
| All saved routes | `MDT.db.global.presets` (not `profile.routes`) |
| Active preset key | `MDT.db.global.currentPreset` |
| Pull data | `preset.value.pulls` — flat `[enemyIdx] = {cloneIdx, ...}` table |
| Enemy forces per NPC | `MDT.dungeonEnemies[dungeonIndex][npcIndex].count` |
| 100% total forces | `MDT:GetDungeonTotalCount(dungeonIndex)` — do **not** sum manually; MDT applies season-specific adjustments |

The pull data structure is `pulls[enemyIdx] = {cloneIdx, cloneIdx, ...}`, not
the compound `"[npcIdx][cloneIdx]"` string-key format.

---

## 6. Midnight Addon Environment

### Combat log access

Midnight removed combat log access for addons (the "addon apocalypse" / "secret
values" model). `COMBAT_LOG_EVENT_UNFILTERED` and related APIs are not available
for retail addons. MilestoneKeys is unaffected because it uses the Scenario API,
which was **not** restricted.

### Scenario API availability

`C_Scenario` / `C_ScenarioInfo` remains fully accessible in Midnight. Forces
tracking via `SCENARIO_CRITERIA_UPDATE` + `GetCriteriaInfo` is viable.

### WeakAuras

WeakAuras discontinued for retail in Midnight; the Classic version continues.
Players migrating from WA-heavy setups are actively looking for replacement
audio cues — this is MilestoneKeys' primary growth opportunity.

### MDT Predictive Alerts — graduation status

MDT predictive pull alerts graduated from experimental to production-ready in
v1.1.2. Verified working in live M+ keys across multiple dungeons during
pre-release testing. The feature is opt-in via the Behavior group toggle and
requires MDT to be installed and a route to be active.

### Addon design positioning

MilestoneKeys surfaces information Blizzard already exposes via the Scenario API
and adds player-defined alerting on top. This is the addon design pattern
Blizzard explicitly endorsed in their post-restriction statements ("addons that
read sanctioned APIs and present that data differently are fine"). Avoid designs
that circumvent restricted APIs or depend on third-party data scrapers.

### Ecosystem

BigWigs, DBM, and MDT all continue development with Midnight-compatible
versions. The built-in Cooldown Manager is one of the few sanctioned
combat-audio-cue sources in the new environment.
