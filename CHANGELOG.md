# Changelog

## [1.2.0] — unreleased (Forever UI test build)

- Add a Blizzard-styled settings window opened with `/nqh`, and an entry under Options → AddOns with an Open Settings button.
- Add two independent per-character options: hide quest map/navigation hints and hide the Blizzard objective tracker.
- Add compact **Show hint / Hide hint** buttons to native quest details and popup panels, centered away from CatQuest's Read button; add right-click options to quest-journal menus without altering quest watch.
- Remember opted-in quest IDs per character and render native Blizzard blue objective areas using a separate `QuestPOIFrame` and `QuestBlobPinMixin:TryDrawQuest(questID)`. No custom map icons or coordinate approximations.
- The custom **refresh policy** skips the global CVar check only for our own map canvas provider, not for Blizzard's original UI. The engine's actual blob rendering with `questPOI=0` still needs a live Forever test; selective minimap guidance remains out of scope.
- Shorten the in-game addon title and Settings category from `No Quest Hints - Forever` to `No Quest Hints`.
- Replace the previous icon-based experimental implementation. Test native blob operations, multi-quest filters, journal context menus, reload, and delayed Blizzard module loading.
- Preserve the `/nqh on` and `/nqh off` commands as controls for **map hints only**. `/nqh status` reports both states.
- Preserve prior per-character `enabled` settings from 1.1.1; new `hideTracker` defaults to false.
- Suppress the tracker visually via alpha, preserve its original alpha and mouse state, and defer post-hook updates to avoid changing a Blizzard frame inside a secure call path.
- Add UI/runtime tests for window opening, Blizzard Settings category, independent toggles, deferred tracker re-hiding, combat, reload and character isolation.
- Add an opt-in permanent GitHub release workflow triggered by editing `.github/release-request.txt`.
- **Needs in-game verification in the released Forever client before publishing to CurseForge.**


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
