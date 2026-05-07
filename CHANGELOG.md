# MilestoneKeys Changelog

## [Unreleased]

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
