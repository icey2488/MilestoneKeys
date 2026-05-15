# MilestoneKeys Changelog

## [Unreleased]

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
