# Changelog

## [1.1.1] — 2026-11-05 (alpha hotfix)

- Fix per-character SavedVariables initialization: load data on `ADDON_LOADED` after Blizzard restores the globals, instead of capturing empty tables at Lua chunk execution.
- Fix `/nqh off` not restoring quest hints after `/reload`.
- Add regression tests that simulate the actual WoW addon loading order and verify `on → /reload → off`.
- Early in-game feedback confirms map and minimap hint suppression on Forever. The tracker itself still remains visible by design; full regression testing for 1.1.1 is pending.


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
