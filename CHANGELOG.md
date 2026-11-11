# Changelog

## Unreleased

- Add an independent Hide quest timers option, OFF by default and in every preset. Preserve the actual Blizzard QuestTimerFrame through a hidden tracker, including native artwork, localized countdown, title tooltip and quest-opening click. Remove the custom countdown renderer.
- Place the native timer below the minimap using an invisible addon-owned anchor. Drag its header to save per-character placement; native time buttons retain their original interaction. Exempt only the timer subtree from hidden-tracker mouse suppression and defer native visibility/position changes outside combat.
- Leave native full-journal content untouched. A duration-free NPC-offer note fits between Accept and Decline only when client metadata identifies that offered quest. The owner confirmed no pre-acceptance time values for quest 3364; reliable first-time warnings for such offers remain unavailable.

## [1.4.4] — 2026-11-09

- Restore automatic onboarding, `/nqh welcome` and the settings playstyle button by removing a native forbidden dialog template introduced in 1.4.3. Saved settings, preset confirmation and map/controller fixes are preserved. The chooser currently uses mouse input in either interface mode; native controller navigation inside it needs a separately validated implementation.
- The owner verified the fixed preview in Forever and approved this hotfix. Add a regression that rejects forbidden template creation even when the template is registered. This is a fix-only update with no new controls.

## [1.4.3] — 2026-11-09

- Add native Gamepad Beta navigation to the playstyle chooser, preserving Blizzard's focus cleanup and explicit preset confirmation.
- Improve native gamepad map compatibility: keep NQH-owned pins out of Blizzard's gamepad hover list and show allowed quest titles/objectives in a private crosshair tooltip. Skip the quest area's independent shared-tooltip tick in this mode while preserving native area drawing and mouse-interface tooltips.
- Fix a Lua error when native bags enumerate a slot before its pooled item button exists, including when quest-item border hiding is OFF. The owner could no longer reproduce the map-close/movement warning with Gamepad Beta enabled and mouse/keyboard after this fix.
- Fix the native waypoint Shift-click clipboard block after reload with active selective quest hints. Read quest state without filling shared Blizzard Lua caches and reconcile private native-template journal/tracker badges without rebuilding the native journal from addon execution. The owner verified the reported scenario in Forever.
- Remove a quest's saved Show hint permission after a confirmed turn-in/removal event during play. Preserve active permissions through loading/reload and refresh hint visuals outside combat without replacing the native SuperTrack target.
- Show Blizzard's treasure-map icon beside No Quest Hints in the native addon list; approved by the owner in-game.
- Preserve saved settings, presets, localization and original native context-menu behavior. No new checkboxes or feature-badge entries.

**Gamepad limitation:** NQH-owned map pins provide information under the crosshair; select/focus the quest through the journal. Mouse pin actions are preserved. Physical controller navigation has not yet been verified; client checks used mouse/keyboard with Gamepad Beta enabled.

## [1.4.2] — 2026-11-08

- Fix the reported protected-action warning that prevented Shift-clicking a native map waypoint from copying coordinates after `/reload`, even with all hiding controls OFF. Create selective quest map providers only when map hiding is enabled and a valid quest hint is revealed, avoiding unused map initialization.
- The owner verified the fix in Forever across repeated cases before approving publication. Preserve saved preferences and on-demand selective hints. This is a fix-only release; it adds no options or feature notifications. The experimental minimap questgiver-icon option is not included.

## [1.4.1] — 2026-11-07

- Identify the addon in the white welcome headline, keep the slogan in the gold second line, and use a short static Choose your playstyle instruction below the cards. Remove duplicated selected-status text while retaining the selected card marker and Begin adventure action. Use informal Russian address throughout the chooser; update all locales without changing typography or spacing.

- Deliver version-upgrade chat notices after loading-screen completion, outside the event stack, to keep them out of the initial login-message burst. Update the seen-version baseline only at delivery; interrupted loading/logout retains the notice for a later attempt.

- Defer automatic onboarding until the loading screen has finished, then open it outside the loading event stack. Preserve explicit pending state, combat retry and once-per-session dismissal. Fix the reported case where `pending=true, complete=false` survived a full restart but no chooser appeared.

- The owner verified automatic startup and approved the final welcome layout in Forever before requesting release. All 15 Lua 5.1 suites, source syntax, TOC integrity and the 16-file package pass validation.

## [1.4.0] — 2026-11-07

- Choose **As in Blizzard**, **Immersion** or **Full immersion** in a native three-card onboarding window. Changes apply only after confirmation; existing characters keep their preferences. Reopen it with `/nqh welcome`.
- Move settings into Blizzard **Options → AddOns → No Quest Hints**, opened by `/nqh`. Playstyle and restoration come first, followed by seven quest controls, two item-price controls, optional bag borders and support access.
- Add independent **Hide quest levels** and **Hide difficulty colors** options for journal/tracker titles. Full immersion hides numeric levels but preserves difficulty colors. All other presets leave both OFF.
- Split native vendor-value hiding into **Hide outside trading** and **Hide at auction**. Merchants always show prices; Full immersion keeps auction values visible. Preserve effective visibility when migrating the older preview's auction option.
- Add manual-only **Hide quest item borders** for native carried bags. Preserve quality/new-item highlights and quest-start exclamation marks. Custom bag overlays, including Baganator, remain under their own addons' control.
- Add a confirmation for the Settings restore button. `/nqh restore` immediately turns all ten restrictions off and restores saved personal game settings, retaining failed CVar backups for retry. Use before disabling or removing the addon. Normal logout/reload attempts CVar cleanup without forgetting saved preferences; forced termination cannot guarantee cleanup.
- Add **Support → Report a problem** with a copyable GitHub repository link and issue-report instructions. Retire the old map-only `/nqh on|off` commands; keep `/nqh status` for diagnostics.
- Automatically localize for all official WoW client locales, including both English/Spanish variants, with English fallback. New translation wording and layout can be refined with player feedback.
- Announce upgrades once per account. Fix-only updates use neutral text; upgrades spanning feature releases invite players to inspect Settings. New checkbox rows use Blizzard's native **New** marker until viewed. Preserve unseen markers across patches/reloads and dismiss viewed markers across characters.
- Fix invisible tracker rows still receiving mouse input/tooltips. Restore exact original input flags, handle pooled/reparented rows and retry protected changes after combat.
- Fix difficulty-color concealment being lost on journal hover. Stop stationary selective-map tooltips from repeatedly rebuilding the journal; retain unchanged pins and refresh real map/quest changes. Native tooltip content updates on actual re-entry.
- Refine native onboarding cards, round icons, spacing and buttons. Block background hover/click/wheel input while the chooser is open and release it on every exit path.
- Validate with **15 Lua 5.1 regression suites**, syntax/TOC checks and a byte-verified **16-file** installable ZIP. The owner confirmed the final preview in Forever and explicitly requested this stable release.
- **Known issue:** intermittent `ADDON_ACTION_BLOCKED` reports remain under investigation in [Issue #3](https://github.com/nick-sidorin/no-quest-hints-forever/issues/3).

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
