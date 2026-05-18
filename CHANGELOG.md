# MilestoneKeys Changelog

## [Unreleased]

## [1.1.1] - 2026-05-17
### Added
- Options panel default width increased to 820 × 620 (was 540 × 520) so milestone row buttons (All / None) sit side by side without wrapping.
- Options panel position and dimensions now persist across sessions via `AceGUI Frame:SetStatusTable()` backed by `db.profile.uiState`.
- Off-screen safety: saved position is cleared if the frame would land entirely outside the current screen resolution (e.g. after switching from an ultrawide to a laptop).
- Minimum resize guard: the panel cannot be shrunk below 700 × 450 (`SetResizeBounds` with `SetMinResize` fallback).
- "Reset window" button at the bottom of the Settings section: wipes saved position/size and reopens the panel at defaults.
- Options panel opacity slider (0.30–1.00) in Settings: fades the backdrop only, leaving all text and interactive widgets fully opaque. Saved to `db.profile.options.panelOpacity`. Useful for stream overlays and accessibility.

### Notes
- MDT predictive pull alerts are present in code but disabled in this release pending further testing. The MDT Route Import section (add milestones from pull data) is fully functional.

## [1.1.0] - 2026-05-17
### Fixed
- **Forces tracking now works correctly in The War Within (TWW) / Midnight.** All milestone alerts (sound, chat, HUD frame) fire at the right thresholds. Confirmed in-game: Algeth'ar Academy +14, milestones at 20/40/60/80/100% all triggered at correct thresholds; HUD percentage matched Blizzard UI.
- Forces percentage is now computed with decimal precision using raw kill counts from `info.quantityString`, rather than the low-precision integer `info.quantity`.
- Fixed a regression introduced in v1.0.11 where `(quantity / totalQuantity) * 100` produced wildly wrong results (e.g. 4.57% when Blizzard showed 21.52%) because `quantity` is an integer percent, not a raw kill count, when `isWeightedProgress = true`.
- Nominal display mode (`237/585 forces`) now uses the correct raw kill count rather than the integer percent field.

### Documentation
- CHANGELOG now contains a permanent API reference table for the TWW forces scenario criteria slot, preventing future regressions. See `[dev-fix-3]` entry below.

## [dev-fix-3] - 2026-05-17
### Fixed
- Forces percentage now computed correctly for The War Within (TWW) / Midnight.

  **Resolved TWW scenario API layout** (do not change without re-testing in-game):
  | Field | Meaning |
  |---|---|
  | `isWeightedProgress` | `true` → this is the forces criteria slot |
  | `quantity` | Integer percent 0–100 (low precision; do not use as the primary value) |
  | `totalQuantity` | Total enemies needed for 100% completion |
  | `quantityString` | `"<rawKills>%"` — raw enemy kill count with a misleading `%` suffix; **not a percentage string**; parse leading digits only |

  Decimal-precision percent must be computed by the addon: `(rawKills / totalQuantity) * 100`.

  Previous bug: `dev-fix-2` matched the decimal regex `[%d%.]+` against `quantityString`, which parsed e.g. `"237%"` as `237.0`, then used that directly as `pct` — firing all milestones simultaneously. Fix: extract only the leading digit sequence `(%d+)` from `quantityString` and divide by `totalQuantity`.

- `qty` passed to alert formatting (`MK_FormatForces`) is now `rawKills` (the actual enemy count), so nominal display mode correctly renders e.g. `237/585 forces`.
- `pct` is clamped to `[0, 100]` after computation to guard against malformed API output.
- Non-`isWeightedProgress` slots now cause an early `return` in `EvaluateForces` (forces slot is always `isWeightedProgress=true` in TWW; no division fallback needed).
- **Diagnostics kept for one more verification run** — remove `[MK Step]`, `[MK Eval]`, `[MK Detect]` logging in follow-up commit after confirmation.

## [dev-fix-2] - 2026-05-16
### Fixed
- `EvaluateForces` now reads `info.quantity` directly as the forces percentage when `info.isWeightedProgress == true`, instead of computing `(quantity / totalQuantity) * 100`. When `isWeightedProgress=true`, Blizzard stores the forces % as an integer in `quantity` (e.g. 21 for 21.52%); `totalQuantity` holds the total enemy forces count and is **not** a denominator. Dividing produced wildly wrong results (e.g. 4.57% when Blizzard showed 21.52%). This restores the intent of the v1.0.9 fix — the v1.0.11 reversion to the division formula was based on a misread of the diagnostic data. **Future maintainers: do NOT revert this to a division formula for the `isWeightedProgress` path.**
- If `info.quantityString` contains a decimal string (e.g. `"21.52"`) that differs from the integer `quantity`, that parsed value is used as `pct` for sub-percent precision. If `quantityString` is nil or matches the integer, the integer `quantity` is used.
- Guard is now `if not info then return end` only; `totalQuantity == 0` is no longer an early-exit for the `isWeightedProgress` path (where `totalQuantity` is informational, not a divisor).
- `[MK Step]` forces-slot diagnostic line now prints `quantityString` and shows computed pct with 4 decimal places, so the next screenshot can confirm precision matches Blizzard UI. **Diagnostics kept for one more verification cycle — remove in follow-up commit.**

## [dev-fix-1] - 2026-05-16
### Fixed
- `EvaluateForces` nil guard now also checks `not info.totalQuantity` before testing `== 0`, preventing a potential nil arithmetic error if the API returns an info table with no `totalQuantity` field.
- `[MK Step]` diagnostic: per-slot loop now marks which slot is `FORCES_IDX` with a `← FORCES_IDX` suffix so the forces row is immediately visible in output. Final forces-slot print now issues a fresh `GetCriteriaInfo(idx)` call (rather than reusing the `info` local from the top of the function) and prints the computed `pct` alongside qty/totalQty, confirming the re-fetched values are consistent with what milestone evaluation uses. **Diagnostics not yet removed — keeping until next in-game test confirms pct matches Blizzard UI.**

## [dev-diag-4] - 2026-05-16
### Debug
- Added `[MK Detect]` prints inside `DetectForcesIndex`: logs the returned index on success, or nil with the reason (numCriteria=0 vs no isWeightedProgress slot found). Fires every time detection runs so call-site timing is visible.
- Added `[MK Step]` block inside the existing 3s-throttled log in `EvaluateForces` (before `[MK Eval]`): dumps `currentStep`, `stepName`, and `numCriteria` from `C_Scenario.GetStepInfo()`, then enumerates every criteria slot in the current step (desc, qty/totalQty, isWeightedProgress, criteriaType), then prints which slot `FORCES_IDX` is cached at and what qty/totalQty it's reading. Intended to diagnose multi-step scenario bug (Pit of Saron) where forces criteria lives in a different step than the one detected at run start. **Not for release.**

## [dev-feat-location] - 2026-05-15
### Added
- `MK:GetCurrentDungeonContext()` in Core.lua: returns the challenge map ID for the player's current context, checking active M+ key first, then party-instance map ID (translated via `C_ChallengeMode.GetMapUIInfo`). Returns a reason code (`"active_key"` or `"in_instance"`) alongside the ID. API calls are wrapped in `pcall` for forward-compatibility.
- Dungeon dropdown in the options panel now auto-selects the current dungeon when the panel is opened, if `sessionManualDungeonOverride` is false. Shows a coloured indicator label to the right of the dropdown (`📍 Current key` in green or `📍 Current dungeon` in gold).
- `MK.sessionManualDungeonOverride` flag: set to `true` when the player manually changes the dropdown (clears the indicator); reset to `false` in `InitRun` so the next key re-enables auto-detection.

## [dev-diag-3] - 2026-05-15
### Debug
- Added throttled (once per 3 s) diagnostic in `EvaluateForces` that logs: which milestone table is being iterated and from which DB path (global vs dungeon-specific), then for every milestone slot: index, label, threshold value and type, `State.triggered[i]` status, current pct, pct type, and whether the threshold comparison passes. Intended to diagnose why an 89% milestone failed to trigger at 93% forces. **Not for release — remove before merging to main.**

## [1.0.11] - 2026-05-15
### Fixed
- `DetectForcesIndex` rewritten for TWW/Midnight: detection now uses `isWeightedProgress == true` as the sole signal for the forces criteria slot. The old `flags & 0x80` bit-check no longer works — all criteria flags are 0 in the current API, causing boss-kill slots (`criteriaType=165`) to be selected instead. Confirmed via in-game diagnostic dump that the forces slot is uniquely identified by `isWeightedProgress=true` with real `quantity/totalQuantity` counts.
- `EvaluateForces` now always computes `pct = (quantity / totalQuantity) * 100`. The previous branch that set `pct = info.quantity` directly when `isWeightedProgress` was true has been removed — the diagnostic showed `quantity` holds a raw enemy count (e.g. 66), not a percentage.
- All diagnostic logging (`[MK Debug]` prints, `lastDump` throttle variable) removed. Code is back to clean production state.

## [dev-diag-2] - 2026-05-15
### Debug
- Expanded diagnostic in `EvaluateForces` to enumerate **every** scenario criteria slot on each `SCENARIO_CRITERIA_UPDATE`, not just the slot `DetectForcesIndex` selected. Each line shows slot index, description, quantity/totalQuantity, flags, criteriaType, and isWeightedProgress. Output is throttled to once per 5 seconds to avoid chat spam. The selected slot index is printed last so incorrect detection is immediately visible. **Not for release — remove before merging to main.**

## [dev-diag-1] - 2026-05-13
### Debug
- Added diagnostic `print` statements to `DetectForcesIndex` and `EvaluateForces` in Core.lua to capture the exact field names and values Blizzard returns for the forces scenario criteria. Each `SCENARIO_CRITERIA_UPDATE` event now dumps the full `info` table and computed `pct` to the chat frame so the correct percentage field can be identified. **Not for release — remove before merging to main.**

## [1.0.10] - 2026-05-08
### Fixed
- `C_Scenario.GetCriteriaInfo` and `C_Scenario.GetStepInfo` are now called through safe local wrappers (`GetCriteriaInfo`, `GetStepInfo`) that try `C_ScenarioInfo` first (TWW), fall back to `C_Scenario`, and return nil/defaults rather than erroring if neither exists. Eliminates the "attempt to call a nil value" Lua error on line 141 that prevented forces tracking from functioning.

## [1.0.9] - 2026-05-07
### Fixed
- "Level Up" alert sound now uses FileDataID 569593 (`Sound/Spells/LevelUp.ogg`, SoundKit 888) — the actual WoW level-up fanfare — instead of 543587 (BigWigs "Beware" chime). Play button and live alerts now both play the correct sound for each label.
- Forces tracking now works in The War Within: when `isWeightedProgress = true`, `quantity` is already the forces percentage (Blizzard hides raw counts). `DetectForcesIndex` now recognises `isWeightedProgress` as the forces criteria, and `EvaluateForces` uses `quantity` directly instead of dividing by `totalQuantity` (which TWW sets to 0). Milestones were silently never triggering before this fix.
- "Chat" and "Frame" checkboxes in the milestone list widened (65 px and 70 px respectively) to prevent label truncation.

## [1.0.8] - 2026-05-07
### Fixed
- Sound playback completely reworked: replaced `PlaySound(soundKitID)` with `PlaySoundFile(fileDataID)` for both alert triggers and sound preview Play buttons. SoundKit IDs are unreliable in The War Within; raw FileDataIDs with `PlaySoundFile` work correctly.
- SOUNDS table now uses verified WoW FileDataIDs (567397 alarm, 569200 gong, 543587 level-up) instead of BigWigs OGG paths or SOUNDKIT constants. No external addon dependency.
- Removed all `[MK Debug]` print statements from the sound preview Play buttons.

## [1.0.7] - 2026-05-07
### Added
- HUD frame: "Preview HUD" toggle button in Settings — shows/hides the HUD outside an active key so it can be repositioned freely.
- HUD frame: "Lock HUD position" checkbox in Settings — saves lock state to `db.profile.hudLocked`; when locked the frame is click-through (EnableMouse false).
- `hudLocked = false` added to DB_DEFAULTS.

### Fixed
- `PlaySound` channel changed from `"Master"` to `"SFX"` in both alert triggers (Alerts.lua) and sound preview Play buttons (UI.lua). `"Master"` was routing through an audio path that produced no audible output on some systems.

## [1.0.6] - 2026-05-07
### Added
- Persistent in-run HUD frame (HUD.lua): lists all enabled milestones; triggered rows flash then dim with a strikethrough line. Draggable; position saved to `db.profile.hudFramePos`.
- "Show milestone HUD during keys" checkbox in Settings.
- "HUD Frame Opacity" slider in Settings (0.1–1.0, default 0.8), calls `MK_HUD_SetAlpha` live.
- `hudFramePos`, `hudFrameAlpha`, and `options.showHUD` added to DB_DEFAULTS in Core.lua.
- `MK_HUD_OnMilestoneTriggered(i)` wired into `EvaluateForces`; `MK_HUD_OnRunStart/End` wired into `InitRun`, `CHALLENGE_MODE_COMPLETED`, and `CHALLENGE_MODE_RESET`.

### Debug
- Added temporary debug prints to sound preview Play buttons (key, sound ID, before/after PlaySound) for in-game tracing.

## [1.0.5] - 2026-05-07
### Added
- Forces display consolidated into a single dropdown: Percentage (85%), Percentage (84.9%), Percentage (84.94%), Nominal (382/450). Replaces the separate "decimal places" dropdown and "Nominal forces" checkbox.
- `MK_FormatForces(pct, quantity, total)` in Core.lua is now the single source of truth for forces formatting, applied in alerts, frame subtitle, and minimap tooltip.

### Fixed
- Sound preview Play buttons now capture their key per-iteration via `local k = snd.key` to avoid potential Lua closure scoping issues in the loop.
- "None" button on milestone rows widened to 70 px (was 56 px) so the full label renders without truncation.
- Minimap tooltip Forces line now respects the selected Forces display mode (was hardcoded to 1 decimal).

## [1.0.4] - 2026-05-07
### Added
- Column headers ("On", "Forces %", "Label", "Alerts") above the milestone list, styled in gold with GameFontNormalSmall.

### Fixed
- Truncated "P..." Play buttons in Alert Sound section widened to 60 px so "Play" renders fully.
- Truncated "..." All/None buttons on milestone rows widened (All → 50 px, None → 56 px).
- Play button OnClick now has an explicit fallback sound ID in case MK_GetSoundID returns nil.
- `/mk test` and "Test Alert" button now use `alertType = "sound_chat_frame"` so the on-screen alert frame fires during tests (was `sound_chat`, which suppressed the frame).
- Nominal forces mode now renders correctly during `/mk test`: when quantity/total are unavailable, derives stand-in values from the current % (e.g. "42/100 forces") instead of silently falling back to percentage format.

## [1.0.3] - 2026-05-07
### Added
- Milestone rows now have independent Sound / Chat / Frame checkboxes instead of a single dropdown, with All and None buttons for quick selection.
- Forces display options: configurable decimal places (0, 1, or 2) and a "Nominal forces" mode (e.g. 382/450 instead of 84.9%).
- Hover tooltips on all Settings options for extra context.

### Fixed
- "Calculate & Add" (MDT route import) now immediately updates the Milestones list without requiring the panel to be closed and reopened.
- Sound preview "Play" buttons now render correctly (replaced unrenderable UTF-8 glyph).

## [1.0.2] - 2026-05-07
### Fixed
- Milestone rows: alert type dropdown replaced with Sound/Chat/Frame checkboxes.
- Alert type now stored as a substring-based string, backward-compatible with existing saved data.

## [1.0.1] - 2026-05-07
### Fixed
- MDT route import now correctly reads saved routes.
  - Routes are stored in `MDT.db.global.presets` (not `profile.routes`).
  - Pull data accessed from `preset.value.pulls` with the correct flat `[enemyIdx] = {cloneIdx, ...}` structure.
  - Active preset resolved via `MDT.db.global.currentPreset`.
- MDT Route Import dropdown now shows "Select a dungeon profile above to load MDT routes" when the global profile is active, instead of silently showing no routes.

## [1.0.0] - 2026-05-06
### Added
- Core enemy forces tracking with milestone alerts (sound, chat, on-screen frame).
- Per-dungeon milestone profiles.
- Minimap button (LibDBIcon).
- Party sync — broadcasts milestone hits to party chat via `MKSYNV1` prefix.
- MDT route integration — calculate forces % at any pull and add it as a milestone.
- MDT predictive alerts — warns in chat when the next pull will cross a milestone threshold.
- `/mk` to open config, `/mk test` to fire a test alert.
