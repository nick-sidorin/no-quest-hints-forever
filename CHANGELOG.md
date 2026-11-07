# Changelog

## [1.4.0] — unreleased development build

- Move the entire Playstyle and restoration section above individual checkboxes so both actions are immediately accessible when opening Settings.

- Add an optional **Bags → Hide quest item borders** checkbox, localized in ruRU/enUS, saved per character and OFF in every preset. Hide only native carried-bag quest borders; preserve quest-start markers, quality/new-item overlays and Blizzard visibility. Restore original alpha on disable/restore or slot reuse, defer in combat and cover pooled/late-loaded bags. Custom bag overlays are outside this initial integration.

- Keep difficulty-color concealment active during hover in the large quest journal by appending handlers to actual pooled row scripts; XML-bound function references can bypass global-name hooks. Cover enter/leave, new rows, single registration and native behavior after disabling.

- Fix ghost tracker hover/click areas by disabling input on tracker descendants as well as its root, including newly pooled blocks. Restore original click/motion/wheel flags individually, release detached children and defer protected writes until combat ends.
- Add independent numeric quest-level and difficulty-color controls for native journal/tracker titles. Preserve actual title content and party counts, defer post-hook updates, and restore native text/colors. Full immersion hides numeric levels but leaves difficulty colors and auction values visible; other playstyles leave both presentation controls OFF.
- Consolidate English contributor/product documentation with merged PR #19; retain ruRU/enUS UI localization and all current owner decisions. Expand regression coverage to thirteen suites.

- Add two equal-rank **Item prices** controls: Hide outside trading and Hide at auction. Both are independent and default OFF; merchants always show native vendor sell values. Preserve effective behavior when migrating the earlier dependent Show at auction preview. Full immersion hides outside trading but keeps auction values visible. Shorten onboarding descriptions without lists or price commentary in the middle card.

- Make the chooser modal with a full-screen mouse/wheel shield; hide stale background tooltips and release input on every close path. Use a native gold/red three-slice primary button with centered text and two aligned native secondary buttons.

- Refine onboarding after the first in-game review: use the exact native realm-rule card/ring atlases at authored sizes, remove duplicate borders, use native icon sizing and padded text, simplify the header, and emphasize the large confirmation button above plain secondary actions.

- Add a consent-based first-run chooser: As in Blizzard (no hiding), Immersion (five quest features), Full immersion (all six, including merchant-only prices). Native game-art cards and circular icons; no changes before confirmation.
- Preserve existing users' preferences; unfinished onboarding persists separately per character and can be reopened from Settings.
- Group native Settings into Quest hints and Additional immersion; explanations remain hover-only. Add playstyle and restoration buttons.
- Add `/nqh restore` for all six features, restoring saved personal CVars and retaining failed backups for retry. Keep `/nqh` and `/nqh status`; remove the ambiguous map-only `on`/`off` commands (now help only).
- Attempt CVar restoration on normal logout/reload without resetting saved preferences; guard against re-enforcement during shutdown. Requires live Forever verification of shutdown/save ordering, combat and character switching; no crash cleanup guarantee.
- Expand Lua 5.1 regression coverage to eleven suites, including preset consent, upgrades, pending onboarding, restoration retry and shutdown/reload.

- Move all six configuration checkboxes directly into Blizzard's **Options → AddOns → No Quest Hints** using its native vertical Settings layout, like CatQuest.
- Show short setting labels only; explanations now appear in the standard WoW hover tooltips rather than occupying permanent rows.
- Make `/nqh` navigate straight to the AddOns settings category; remove the duplicate floating window and launcher button.
- Preserve existing per-character SavedVariables, state logic, default values and independent toggles. Add native Settings integration, tooltip and slash-navigation regression coverage.
- **Not yet released:** requires live Forever UI validation and a separate stable release request.


## [1.3.0] — 2026-11-06

- Add **Hide quest hints in tooltips**: selectively suppress native quest title/objective/player lines on creature and world-object mouseover without hiding normal details.
- Add **Hide quest NPC names**: independently override Blizzard's `UnitNameFriendlySpecialNPCName` CVar while preserving the original account value on disable or character change. Because Blizzard groups these name types, some special/friendly NPC names may also be hidden; regular hostile-name CVars are untouched.
- Add **Hide item sell prices**: hide the native SellPrice tooltip line outside the merchant window. Original prices reappear while trading, and selling mechanics remain unchanged. Addons that draw their own price overlays are unaffected.
- Add **Hide quest progress popups**: suppress six native quest-specific yellow objective count/completion messages, but preserve ordinary game messages and red errors. Restore pre-existing message-type settings when disabled.
- All four new controls are **independent**, **per-character**, **off by default**, and localized in Russian and English. The full settings window now has six checkboxes.
- Expand Lua 5.1 regression coverage to ten suites, including independent options, saved settings, safe Blizzard UI integration, deferred loading, merchant-only prices and quest-message filtering.
- Add shared release-quality gates: all Lua syntax, all automatically discovered regression suites and manifest-verified ZIP packaging must pass in PR CI and again before a tag/release is published.
- New controls were evaluated by the addon author in World of Warcraft: Forever before requesting the stable release. Mocked Lua tests cannot exclude every client-side compatibility issue.

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
