# MilestoneKeys Changelog

## [Unreleased]

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
