# Changelog

## [1.3.0] — unreleased development build

- Add an **optional per-character Hide quest hints in tooltips** checkbox, independent of map hints and objective tracker visibility. Default OFF to preserve 1.2.0 users' behavior.
- Filter only native **creature and world-object** tooltip lines typed `QuestTitle`, `QuestObjective`, or `QuestPlayer`. Creature names, level, health and all unrelated tooltip content remain unchanged. Do not modify floating NPC names, nameplates or quest unit circles.
- Provide Russian and English labels and include a tooltip status entry in `/nqh status`.
- Add regression tests for delayed API initialization, reversible toggling, unrelated tooltip safety, character isolation and localization.
- **Not yet released:** requires live Forever testing and a separate release decision; CurseForge stable remains v1.2.0.

## [1.2.0] — 2026-11-05

- Add a Blizzard-styled standalone settings window (`/nqh`) and a launch button under Options → AddOns.
- Add independent per-character options for global quest hint suppression and the on-screen objective tracker.
- Let players selectively reveal *native Blizzard* blue quest objective areas and original round progress/turn-in map POIs by quest ID. These are not custom pin images.
- Add **Show hint / Hide hint** to the journal's details panel, its right-click menu, and the objective tracker's right-click menu; align the details button beside Blizzard's **Back** button.
- Context-menu hint toggles no longer open the map. Normal clicking of a quest still does.
- When revealing a quest, set its native `C_SuperTrack` target for the in-world diamond and distance without adding it to the watch list. Enable `showInGameNavigation` only while the active super-tracked quest is explicitly permitted; restore saved CVar values when global hint suppression is disabled.
- Show Blizzard's **original POI buttons next to quest names** only for permitted quests in the native journal and objective tracker, without turning `questPOI` on globally.
- Add **ruRU** localization for all addon UI controls, hints and status messages, with English (`enUS`) default/fallback.
- Keep the objective-tracker visibility checkbox independent of quest hint permission and native SuperTrack focus.
- Preserve existing per-character options and `/nqh on | off | status` behavior; `on/off` still applies to map hints only.
- Expand Lua regression coverage for SavedVariables lifecycle, navigation gating, localized strings, native POI badges, tracker and journal controls, reload, and character separation.
- Add an opt-in GitHub Actions publishing workflow invoked by a version request, with automatic tag and GitHub Release.
- Verified in World of Warcraft: Forever: selective native blue quest areas, round quest POIs, in-world navigation diamond with distance, quest journal/tracker POI badges, and Russian quest-hint labels. The user also reported no recurrence of a previously observed Blizzard blocked-action dialog in follow-up testing. The root cause of that earlier warning has not been established, and cross-character behavior remains to be checked in-game.

## [1.1.1] — 2026-11-05

- Fix per-character SavedVariables initialization: load data on `ADDON_LOADED` after Blizzard restores the globals, instead of capturing empty tables at Lua chunk execution.
- Fix `/nqh off` not restoring quest hints after `/reload`.
- Add regression tests that simulate the actual WoW addon loading order and verify `on → /reload → off`.
- Verified in the released Forever client: world-map and minimap hints are suppressed; after manual recovery of values left by 1.1.0, the `on → /reload → off` scenario restores the three available CVars.
- Upgrading from affected 1.1.0 installs may require a one-time manual reset of CVars to `1` because the original baseline was not saved by the buggy version.
- The objective tracker remains visible by design. Cross-character switching remains to be verified on the live client.


## [1.1.0] — 2026-11-04 (initial release build)

- Add `/nqh on`, `/nqh off`, and `/nqh status`.
- Default to OFF and persist the ON/OFF setting per character.
- Restore previously changed account-wide CVars when entering an OFF character.
- Restore original values on `/nqh off`, instead of setting all hints to `1`.
- Add `showQuestObjectivesOnMap` to the targeted map settings.
- Add runtime CVar availability checks, event-driven enforcement, and client validation instructions.
- Target the released client folder (`_forever_`). In-game Forever verification still pending.

## [1.0.0] — experimental archive

- Initial proof of concept: four CVars were forced to `0` on login and on CVar updates, globally for all characters.
- No slash commands, persistence, or verification in Forever.
