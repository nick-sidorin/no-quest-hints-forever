# No Quest Hints

**Read the quest. Explore the world. Find your own way.**

Remember when finding a quest objective meant reading the description, looking at your map, and exploring instead of following a marker?

**No Quest Hints** is a lightweight addon built specifically for **World of Warcraft: Forever**. It lets you choose how much of Blizzard's quest guidance you want to keep, without removing the quest journal or changing quest data.

**No more following dots. Just you, your quest journal, and Azeroth.**

> **Compatibility status:** Tested in World of Warcraft: Forever. Native blue quest objective areas, round progress/turn-in map pins, the in-world navigation diamond with distance, quest icons in the journal and tracker, and the Russian quest-hint UI have been confirmed in player testing. The 1.1.1 `/reload` restoration fix was also verified. Some Blizzard CVars are unavailable in Forever; switching between characters has not yet been verified in the live client.

## Features

> **Development preview:** The onboarding, restoration and grouped native settings below belong to unreleased **v1.4.0**. Stable **v1.3.0** still uses the original separate settings window until a new release is tested and published.

**Independent, per-character** options:

- **Hide quest map hints:** Suppress native quest markers and highlighted areas on the world map/minimap, and Blizzard's navigation guidance where available.
- **Hide objective tracker:** Remove the right-side list of tracked objectives and progress counters from view. The underlying tracking data and quest journal are unaffected.
- **Hide quest hints in tooltips:** Remove the quest title, objective progress and group quest lines from native unit and world-object mouseover tooltips. Normal creature names, levels and other tooltip lines remain.
- **Hide quest NPC names:** Temporarily override Blizzard's `UnitNameFriendlySpecialNPCName` setting to conceal quest-relevant floating names while preserving unrelated NPC-name CVars, then restore the original account-wide CVar when disabled. **Blizzard groups some special/friendly NPC names with quest NPCs under this setting, so those may also disappear.** This is a documented Blizzard limitation, not quest-by-quest name filtering.
- **Item prices:** Two independent controls hide the native vendor SellPrice line **outside trading** and **at auction**. Merchants always show prices. These controls do not change actual prices, stats, trading mechanics or separate price overlays from other addons.
- **Hide quest item borders (optional):** Hide the yellow quest-item border in native bags. Preserve item quality, new-item highlights and quest-start exclamation marks. OFF in every playstyle; enable manually under **Bags**. Custom bag addons may draw their own borders.
- **Hide quest levels:** Remove the native numeric `[level]` prefix from quest titles in the journal and tracker, preserving real quest names and party-member counts.
- **Hide difficulty colors:** Use normal yellow quest titles instead of difficulty-based green/orange/red. Independent of numeric levels; enabled only manually.
- **Hide quest progress popups:** Suppress the six native yellow quest objective progress/completion messages while preserving ordinary status messages and red combat/UI errors. Uses Blizzard `UIErrorsFrame:SetMessageTypeEnabled` and original visibility restoration instead of parsing translated strings.
- **Selective quest hints:** While built-in quest map hints are hidden, open a quest and click **Show hint** next to the **Back** button in the journal, or right-click a quest in either the journal or objective tracker. The addon uses the **original blue Blizzard objective areas** and attempts to show Blizzard's own '?' / progress icons only for chosen quests. Use **Hide hint** to remove them. Multiple quests may be allowed, with their IDs saved per character. **Context-menu actions do not open the map**; clicking a quest normally still opens its details. When permission is granted, that quest becomes Blizzard's super-tracked navigation target (without adding it to the right-side watch list), enabling the native world-space diamond and distance if the client can navigate to it.

The addon leaves the geographical map, quest descriptions, quest-giver exclamation marks above NPCs, and quest voiceover addons alone. It does not hide markers created by other quest addons. **Native badges beside titles in the quest journal and objective tracker** are selectively restored only for allowed quest IDs. The user interface automatically uses **Russian** when the WoW client locale is `ruRU`; otherwise it uses English.

**Remove the directions, not the adventure.**

## Getting started

### Installation

Download the installable ZIP (from [GitHub Actions](https://github.com/nick-sidorin/no-quest-hints-forever/actions) for unreleased test builds or from [GitHub Releases](https://github.com/nick-sidorin/no-quest-hints-forever/releases) for published versions). Test artifact downloads contain the addon folder directly, with no nested ZIP. Copy the `NoQuestHintsForever/` folder into your Forever client's `Interface/AddOns/` directory:

```text
World of Warcraft/
└── _forever_/
    └── Interface/
        └── AddOns/
            └── NoQuestHintsForever/
                ├── NoQuestHintsForever.toc
                ├── Localization.lua
                ├── NoQuestHintsForever.lua
                ├── Options.lua
                ├── Onboarding.lua
                ├── QuestHints.lua
                ├── QuestMarkers.lua
                ├── QuestHintPins.xml
                ├── QuestInlineHints.lua
                ├── QuestPresentation.lua     # Numeric title levels and difficulty-color filtering
                ├── QuestTooltips.lua
                ├── SellPrices.lua
                ├── QuestItemHighlight.lua   # Optional native bag quest borders
                ├── QuestProgressMessages.lua
                └── LICENSE
```

Restart the game or use `/reload` if you're updating an existing installation. Ensure you do not have an extra nested addon folder.

### First run and playstyles (1.4.0 preview)

A new character sees three realm-rule-style cards, with native game icons and circular portraits:

| Playstyle | Features enabled |
| --- | --- |
| **As in Blizzard** | None; keep your personal game settings |
| **Immersion** | Original five quest concealment options; numeric levels and difficulty colors remain unchanged |
| **Full immersion** | Immersion plus hidden numeric quest levels and prices outside trading; difficulty colors and auction prices remain visible |

Clicking a card only selects it. **Begin adventure** confirms the choice. Closing the window, choosing **Later**, or opening **Customize settings…** applies no preset. An unfinished first run reappears on the next login; editing a checkbox completes setup. Existing characters keep their saved choices and do not see onboarding after upgrading.

Reopen the cards with **Choose playstyle** in the addon settings. Applying a playstyle replaces the ten checkbox values. As in Blizzard and Immersion keep both price controls OFF; Full immersion hides outside trading and keeps auction prices visible, as requested. Auction hiding can then be enabled separately for strict RP. Quest-item border hiding remains OFF in every preset. Choices are saved per character.

After an upgrade, one localized login message per account shows the new addon version and points to `/nqh` for new options. Ordinary reloads, alts and downgrades do not repeat it; a first install uses onboarding instead. Existing installations without version bookkeeping receive one notice, then keep a baseline in account SavedVariables. Test builds with the same TOC version do not count as separate upgrades.

### Open settings

- Type **`/nqh`** without arguments to open **Options → AddOns → No Quest Hints** directly.
- Or open **Esc → Options → AddOns → No Quest Hints** yourself. All ten checkboxes live directly on that page; no separate popup window.

The **Playstyle and restoration** section appears first, with both playstyle selection and restore buttons. Below it, the native Blizzard settings category groups seven checkboxes under **Quest hints** and two equal-rank controls under **Item prices**, plus one manual option under **Bags**. Both price controls mean hiding and are independently editable; neither is indented or dependent on the other. Labels are kept compact; the descriptions appear **only when hovering** over the controls, like other WoW addon settings:

| Checkbox | Behavior | Default for new characters |
| --- | --- | --- |
| Hide quest map hints | Hide the supported built-in map/minimap markers and navigation | Off |
| Hide objective tracker | Hide the on-screen right-side task list | Off |
| Hide quest hints in tooltips | Hide quest titles and progress on NPC/object mouseover, not in quest journal | Off |
| Hide quest NPC names | Also hides some special/friendly NPC names due to Blizzard's shared CVar | Off |
| Hide outside trading | Hide native vendor sell values when neither a merchant nor auction house is open | Off |
| Hide quest item borders | Hide yellow quest-item borders in native carried bags; preserve quest-start markers | Off |
| Hide quest levels | Remove numeric level decoration in native journal/tracker titles | Off |
| Hide difficulty colors | Render quest titles in normal yellow instead of difficulty colors | Off |
| Hide at auction | Hide native vendor sell values while the auction house is open | Off |
| Hide quest progress popups | Hide yellow objective updates, preserving other notifications | Off |

**Hide at auction** concerns the NPC vendor sell value, not an auction market estimate, cost price, deposit or suggested listing price. Both controls default OFF. The former preview's positive/dependent Show at auction preference is migrated to preserve effective visibility: only an active old price-hiding setting combined with Show at auction OFF becomes Hide at auction ON. Old fields are then removed; explicit new-format choices are retained. Both modern and legacy auction frames are supported. Changes take effect on the next native tooltip composition/hover.

The merchant always shows native values. Elsewhere, the active context selects the relevant checkbox: at auction only Hide at auction matters; away from both windows only Hide outside trading matters. `/nqh restore` and native defaults turn both OFF. Presets reset them to their documented values, and ordinary `/reload` preserves the current pair.

The second option is independent of the first: you can keep the task list while hiding map hints, or hide both. **The quest hint allowlist is also independent of objective tracking** — the right-side list can stay hidden even when selected quest areas are visible on the map.

The final **Support → Report a problem** button opens a selected, copyable GitHub project URL. Copy it into your browser, then use **Issues → New issue** for bug reports or suggestions. Include the Forever build, addon version and reproduction steps. WoW does not launch a browser from this button.

### Slash commands

| Command | What it does |
| --- | --- |
| `/nqh` | Open the native Blizzard AddOns settings category. |
| `/nqh welcome` | Reopen the playstyle chooser without changing settings until confirmation. |
| `/nqh restore` | Turn off all ten hiding controls and restore saved pre-addon game settings. |
| `/nqh status` | Display all ten checkbox states and targeted CVars. |

The ambiguous map-only `on`/`off` commands have been removed in this preview. They now show command help without changing anything.

### Restoring settings before disabling or removing the addon

The **Restore game settings** button asks for confirmation before clearing your current checkbox combination. Cancel or Escape leaves it intact. The explicit `/nqh restore` command restores immediately.

Use **Restore game settings** in the addon settings or run `/nqh restore` **before disabling/removing the addon**. All ten hiding controls turn off; map/navigation and NPC-name CVars return to their saved personal values, rather than invented Blizzard defaults. Your per-quest hint permissions are kept. All ten checkbox defaults are OFF; choosing the immersion preset is an explicit first-run decision.

At normal logout or `/reload` the addon also attempts to restore the persistent CVars, without turning off your saved preferences. At the next login with the addon enabled it reapplies those preferences. Failed writes retain their backups for a later restore; an incomplete explicit restore reports that it needs another attempt. A tracker mouse change may wait until combat ends.

**An unloaded addon cannot run cleanup.** The shutdown path and the game's CVar save ordering still need live Forever validation. Crashes, forced termination, disabling without a normal shutdown, or interference from another addon may leave changed CVars behind. If this happens, re-enable/reinstall the addon with its SavedVariables intact, run `/nqh restore`, then disable it. If those backups were deleted, exact personal pre-addon values cannot be recovered by the addon; adjust the affected settings in Blizzard's interface. Do not delete SavedVariables as a restoration procedure.

## Per-character settings and persistence

- Settings are stored in `NoQuestHintsForeverChar` using `SavedVariablesPerCharacter`. The existing `enabled` flag is retained as the **Hide quest map hints** value so existing users keep their preference. New hiding options default to **false**, preserving existing users' choices. Existing Full immersion users must explicitly reselect that preset or enable Hide quest levels to adopt its new numeric-level restriction.
- CVar baselines are saved before the addon modifies them. A separate `NoQuestHintsForeverAccount` SavedVariable tracks original values for CVars treated as shared across characters.
- While map hint suppression is enabled, relevant `CVAR_UPDATE` events trigger re-enforcement. When disabled, the addon restores the saved baselines and stops enforcing.
- Individual quest permissions are stored in the character's `revealedQuests` table, keyed by quest ID. A separate native `QuestPOIFrame` uses Blizzard's `QuestBlobPinMixin` and calls `DrawBlob(questID, true)` for allowed quests. The original blue blobs work in Forever with `questPOI=0`. A second provider uses a unique XML template inherited from Blizzard's `QuestPinTemplate` and `QuestDataProviderMixin:AddQuest()` for the clickable map POIs; both areas and POIs have been confirmed in an in-game test.
- The journal's `POIButtonOwnerMixin` and tracker's `ObjectiveTrackerQuestPOIBlockMixin` originally suppress all title badges when `questPOI=0`. The addon restores their *native pooled buttons* only for allowed quest IDs, using post-hooks and deferred layout updates. **This behavior has been tested in Forever.**
- `Show hint` changes the native `C_SuperTrack` quest target, **not** the Blizzard watch list, so it can drive the world-space diamond while leaving the right-side list independently hidden. While the global Hide Quest Map Hints option is ON, `showInGameNavigation` is allowed only when the active super-tracked quest is itself permitted; it is otherwise suppressed. The original account/character CVar value is restored when the global option is turned OFF. Navigation cannot be guaranteed for quests lacking a valid destination in the Forever client.
- The optional NPC name suppression uses only `UnitNameFriendlySpecialNPCName`. It never changes `UnitNameHostleNPC`, `UnitNameInteractiveNPC`, `UnitNameNPC` or `ShowQuestUnitCircles`. The original shared CVar is kept in `NoQuestHintsForeverAccount.npcNameOriginal` while suppression is enabled, restored when disabled or on the next character if they have the option turned off. Blizzard's NPC names dropdown may display an adjusted category while this override is active. Use Blizzard's own menu to control other name categories.
- When global hint suppression is OFF, the addon draws no extra map pins and Blizzard handles the normal map. Its journal/tracker badge hooks likewise stay passive.
- The tracker keeps its quest data/layout but becomes transparent and non-interactive. Its root **and descendants** have click, motion and wheel input disabled outside combat. Each original input flag is preserved separately, including mixed click/motion states; newly pooled headers are handled after native updates, and detached children regain input. Existing tooltips owned by the hidden subtree are dismissed without hiding unrelated tooltips. Protected input changes and restoration wait for combat to end; failed writes retain recovery state.
- Blizzard can update the tracker itself. The addon watches its `Show` and `SetAlpha` methods, then **defers** its own update rather than mutating Blizzard frames inside a secure hook. There is no continuous `OnUpdate` loop.
- If the tracker frame is not loaded, the addon waits until it appears instead of raising an error.

The goal is to leave the normal game behavior alone whenever each option is disabled. **The new name-CVar override is account-wide at the game level** even though the addon preference is per character; when switching characters, the addon restores or reapplies the override for the newly loaded character. Another addon that also edits the same frame or CVars may conflict.

WoW normally saves SavedVariables on logout and `/reload`; forced exits or crashes can lose the most recent change.

## Technical details

### Target client and dependencies

- **Client:** World of Warcraft: Forever, **not** Retail or Classic Era.
- **TOC Interface:** `16001`, checked against early Forever client builds. This does not by itself prove runtime API compatibility.
- **Dependencies:** None. Uses Blizzard UI templates and Lua.
- **Blizzard Settings integration:** `Settings.RegisterVerticalLayoutCategory`, ten equal-rank `Settings.RegisterProxySetting` values (seven quest controls, two independent price contexts and one bag control) and native `Settings.CreateCheckbox` controls (labels only, explanatory tooltip on hover). The option accessors read the active character; all native controls update the live game state. No separate settings dialog or copied checkbox state. A dedicated first-run chooser uses native game art; it is separate from the actual Settings page.
- **Tracker:** `ObjectiveTrackerFrame`. These behaviors must still be validated in the current release of Forever, including combat and Edit Mode.

Selective circular map pins keep their native real hover/click behavior. Their tooltip content refreshes on re-entry; periodic synthetic hover callbacks are disabled because Forever also rebuilds the journal through that callback. Unchanged quest events preserve existing pins, while changed permissions, position, style, selection or map refresh them.

### Quest title presentation

Forever's Camelot `GetQuestTitlePrefix` adds numeric levels even when the native show-level CVar is OFF. This addon therefore filters only known quest-title FontStrings after deferred native journal/tracker updates. It identifies the real title and numeric level from quest metadata, preserving party counts, actual title content and quest data. Difficulty color concealment applies ordinary yellow to those titles and removes an outer native difficulty-color wrapper. It does not recolor objectives, zones, NPCs, item rarity, or other UI.

The module does not replace Blizzard return-value functions or hook every FontString. Disabling/restoring recovers recorded native text/colors; recycled quest rows are checked by quest ID. Visual mutations and restoration defer in combat. Broader client/addon compatibility still requires the in-game smoke test.

### Onboarding art

Only game textures are used; no Wowhead images are bundled. The cards use the exact Forever realm-rule `Mode-Selection-Card-Regular` atlas and its matching selection glow at their authored sizes; the native 260 × 530 card layout leaves a 180px text column. The gold dialog fallback is used only when that atlas is unavailable, so borders are never doubled. Portraits use the native 64px icons, circular mask and beveled `Mode-Selection-Ring`. Glue-only templates and account/realm rules are not modified.

| Card | Game texture | Reference |
| --- | --- | --- |
| As in Blizzard | `INV_Misc_Map_01` | [Map](https://www.wowhead.com/icon=134269/inv-misc-map-01) |
| Immersion | `icon_treasuremap` | [Chosen treasure map](https://www.wowhead.com/icon=1064187/icon-treasuremap) |
| Full immersion | `Achievement_Zone_ElwynnForest` | [Elwynn Forest](https://www.wowhead.com/icons?filter=na=achievement_zone_elwynnforest) |

The visual follow-up uses the [Forever SuperDistrict card assets and layout](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GlueXML/Mainline/SuperDistrict.xml), two header text styles and a native gold/red three-slice confirmation button above two smaller native buttons aligned to its left and right edges. A full-screen mouse/wheel shield prevents background UI hover or clicks while the chooser is open; it is released when the chooser closes. The owner reported general functionality working on the first preview; the revised rendering and text fit still require in-game review; mocked UI tests cannot establish the final rendering.

### Map and navigation CVars

| CVar | Intended effect |
| --- | --- |
| `questPOI` | Quest points of interest on the world map |
| `showQuestObjectivesOnMap` | Quest objectives on the world map |
| `questPOILocalStory` | Local-story quest map markers |
| `minimapShowQuestBlobs` | Quest objective areas on the minimap |
| `showInGameNavigation` | Native in-game navigation guidance |

The addon normally suppresses available hint CVars using `0`. The exception is `showInGameNavigation`: with global hiding ON it becomes `1` **only** when the active Blizzard SuperTrack target is an allowed quest, otherwise `0`. When global hiding is disabled, all original saved CVar values are restored. In the initially tested Forever client, `showQuestObjectivesOnMap` and `minimapShowQuestBlobs` reported **unavailable**. Other three CVars were usable.

### Source layout

```text
NoQuestHintsForever/
├── NoQuestHintsForever.toc    # Interface, version, SavedVariables and load order
├── Localization.lua          # Russian UI, English fallback
├── NoQuestHintsForever.lua    # CVar/navigation and tracker controls; slash commands
├── Options.lua               # Grouped native Settings page and restoration actions
├── Onboarding.lua            # Three consent-based first-run playstyles
├── QuestHints.lua            # Per-quest permission, menus, native blue blobs and SuperTrack
├── QuestMarkers.lua          # Filtered native in-progress / turn-in map POI buttons
├── QuestHintPins.xml         # XML templates inheriting native Blizzard map widgets
├── QuestInlineHints.lua      # Per-quest journal and objective-tracker POI badges
├── QuestTooltips.lua         # Opt-in quest line suppression on unit/object hover
├── SellPrices.lua            # Filter native vendor values with merchant/auction exceptions
├── QuestProgressMessages.lua # Hide only native quest progress message categories
└── LICENSE                   # MIT license in the installation archive
tests/
├── test_runtime.lua          # SavedVariables/reload and CVar regression checks
├── test_ui.lua               # UI, tracker hook, combat and alt simulations
├── test_quest_hints.lua      # Native blobs, journal/tracker menus and whitelist tests
├── test_quest_markers.lua    # Native quest progress/turn-in pin tests
├── test_inline_hints.lua     # Journal/tracker title badges, secure/deferred layout
├── test_navigation.lua       # Selective in-world diamond and CVar restoration
├── test_localization.lua     # Russian and English UI translations
├── test_quest_presentation.lua # Quest title metadata, prefixes, color and restoration
├── test_tracker_input.lua    # Descendant mouse input and combat recovery
├── test_quest_tooltips.lua   # Tooltip callback, late load and isolation
├── test_sell_prices.lua      # Merchant/auction tooltip price filtering
└── test_quest_progress.lua   # Native quest progress message type filtering
scripts/
├── run_ci.sh                 # Shared regression, Lua syntax and manifest validation
└── package_addon.py          # TOC-derived verified release ZIP
.github/
├── release-request.txt       # Release request: changing this triggers publication
└── workflows/
    ├── release.yml           # PR CI, manual test ZIP and tagged-release builds
    └── publish.yml           # Automated tag + GitHub Release publication
CHANGELOG.md
README.md
LICENSE
.pkgmeta                       # CurseForge's native source packager configuration
```

Local tests, using Lua 5.1 from the repository root:

```sh
bash scripts/run_ci.sh
```

Mocked tests check Lua loading order, CVar restoration, independent checkboxes, a delayed Blizzard tracker, re-hiding after Blizzard changes alpha, combat and character isolation. The native NPC-name override tests preserve and restore the original account CVar and check that unrelated name CVars remain untouched. Selective hint tests validate native blob calls, map POI filtering, tracker right-click capture, **no automatic map opening**, safe navigation gating, original title badges and per-character reload. Native blobs, map POIs, in-world navigation diamond, title badges and Russian quest-hint labels have also been checked in the released Forever client. **Automated tests do not replace broader in-game regression testing**, particularly across different characters and UI addons.

## Validation checklist for Forever 1.4.0 preview

1. Run `/nqh`: confirm Blizzard **Options → AddOns → No Quest Hints** opens, containing seven quest checkboxes, two equal-rank item price checkboxes and one bag checkbox (no floating window).
2. Open the same category manually from the AddOns list: all ten controls must appear directly in the page; hover each to see its explanation without a permanent description line.
3. Verify that enabling **Hide quest map hints** removes the built-in quest areas/markers but does not hide the objective tracker.
4. Enable **Hide objective tracker**: verify the full right-side list disappears; journal, quest text and NPC exclamation marks remain.
5. Uncheck the tracker option: its original display returns. Check quest updates and world-map opening while it is hidden, and check whether it stays hidden.
6. Enable map hiding in Settings, `/reload`, then disable that checkbox; verify original map values return and the tracker keeps its independent state.
7. Log in as another character: verify default-off settings do not inherit hidden hints. Switch back to confirm both options persist.
8. In the journal, click **Show hint** next to **Back**. Confirm the blue objective area is visible and look for Blizzard's native round quest icon (in-progress or turn-in). If an icon is missing even when a blob is present, note the quest title and state; the client's quest POI APIs may not return coordinates with `questPOI=0`.
9. Right-click a quest **in the objective tracker** and select **Show hint**. Verify **the map does not automatically open**; the allowed quest's map guidance still appears when you open the map normally. Repeat with a different quest, then **Hide hint**. Check that the right-click never affects a different quest. The journal context menu should behave the same way.
10. With global quest hints hidden, show a hint and return to the game world. Check for Blizzard's in-world **navigation diamond and distance** toward that quest. Hide it and verify the diamond disappears. If another quest becomes SuperTracked, verify it is suppressed until explicitly allowed. Confirm normal CVar behavior after disabling the map checkbox.
11. Verify the native '?' / '...' badges appear beside the title of **allowed quests only** in both the quest journal and right-side objective tracker. Verify they disappear when a hint is hidden, and return after `/reload`.
12. With a **Russian client (`ruRU`)**, check the localized UI and context-menu labels; the short journal button should read **Показать / Скрыть**.
13. Confirm that the journal button is horizontally aligned with Blizzard's **Back** button and does not overlap CatQuest's **Read** button. Check both detail layouts.
14. If possible, check in combat and Edit Mode. Note any blocked-action error, click-blocking invisible region or conflict with other UI addons.
15. Toggle **Hide quest hints in tooltips** and **Hide quest NPC names**; normal combat information should remain.
16. Test all four combinations of Hide outside trading / Hide at auction: away from trading only the first applies, at auction only the second applies, and at a merchant prices are always visible. Close each window and re-hover. Test reload, another character and migration from the previous Show at auction preview. Both checkbox rows must have equal rank/size and remain editable.
17. Toggle **Hide quest progress popups**; quest counts disappear but ordinary warnings and status messages remain.
18. Change characters and reload to check the six independent settings.
19. On a fresh character, verify three cards, round icons, readable ruRU/enUS text and layout at different UI scales. Selecting a card or closing the window must not change settings. No default card is selected.
20. Confirm each preset, especially that Immersion leaves prices visible and Full immersion hides them outside trading while keeping the auction control OFF. Then enable Hide at auction manually to check strict RP. Reopen via Choose playstyle. Test Customize settings and first checkbox edit.
21. Upgrade an existing character (including all options OFF) and verify no first-run popup or changed preferences. On a new character, choose Later and reload: the chooser should reappear.
22. Record personal CVar values, apply Full immersion, and run `/nqh restore`; verify all ten checkbox effects are off and the original values return. Restore twice; try while in combat and finish after combat.
23. Apply a preset, disable the addon and reload through the normal addon UI. Verify game settings remain restored without the addon. Re-enable it and verify your saved mode returns. Repeat with normal logout/relogin and switching characters. This client test is required before claiming automatic uninstall cleanup works.
24. With the chooser open, move/click/scroll over background action bars, quests and screen edges: no background tooltip or action should occur. Test Esc, Later, Customize settings, confirmation and combat; the background must become interactive again when the chooser closes. Check the primary button label and the aligned secondary buttons in ruRU/enUS.
25. Hide the tracker and hover/click/scroll across its former quest rows; no quest tooltip or quest action should fire. Add/track another quest while hidden, then restore the tracker and verify interaction returns. Test mixed input states, combat and existing tooltip dismissal.
26. Toggle Hide quest levels and Hide difficulty colors separately in the journal and visible tracker. Verify `[level]` disappears but group counts and numbers in actual names remain. Hover/unhover, reload, change quests and restore. Full immersion must enable only numeric concealment; colors remain normal unless explicitly hidden.
27. Confirm removed `/nqh on` and `/nqh off` only show help and `/nqh status` still prints diagnostics.

Please report the Forever build, version, `/nqh status` output, steps to reproduce and screenshots at [GitHub Issues](https://github.com/nick-sidorin/no-quest-hints-forever/issues).

## Automated releases and CurseForge

**Normal development (GitHub Flow):** Implement changes in a feature branch and open a **Pull Request targeting `main`**. The PR runs the shared `scripts/run_ci.sh` gate: automatically discovered Lua 5.1 tests, syntax validation for every addon Lua file, TOC manifest checks, and packaging a ZIP from the exact TOC entries. Every failure turns the build red. New commits in the same PR cancel outdated runs. **Ordinary pushes to `main` do not run CI.** Manual builds remain available through **Actions → Build and release → Run workflow**. Stable publication follows green CI and a live Forever smoke test.

**Merge safety and history:** Use **Squash and merge** for **every** Pull Request, including documentation and release-request PRs; do not use merge commits or rebase merges. The repository's required CI check is named `build`. An administrator should enable a ruleset for `main` requiring PRs and that check. GitHub repository **Settings → General → Pull Requests** can allow *only* Squash merging by disabling *Allow merge commits* and *Allow rebase merging*. The connected GitHub App cannot edit these repository settings directly.

**Publishing on request:** The permanent [`publish.yml`](.github/workflows/publish.yml) watches [`.github/release-request.txt`](.github/release-request.txt). To release a new version, first update the `.toc` version and `CHANGELOG.md`, then change the request file to e.g. `1.4.0-beta.1`. The workflow re-runs the **same full regression, syntax and manifest gates**, verifies the version, creates the annotated `v1.4.0-beta.1` tag, builds the ZIP and publishes a GitHub prerelease. For a verified stable version, request `1.4.0`, producing a normal Release. Duplicate tag names are rejected. The owner can ask the repository-maintaining assistant to perform these steps without manual tag creation.

**CurseForge description:** [`CURSEFORGE_DESCRIPTION.md`](CURSEFORGE_DESCRIPTION.md) is the single copy-ready source for the CurseForge **short and full descriptions**. Update it when user-facing features change, include the updated text in each release handoff, and paste the two sections into the CurseForge project editor. The GitHub release pipeline does **not** update the CurseForge description automatically.

**CurseForge:** The project uses GitHub source-based Automatic Packaging and a GitHub webhook. The tag push requests packaging through the configured webhook; CurseForge handles its own file approval. Do not add a second upload through Actions, and **never commit CurseForge author tokens**. The [.pkgmeta](.pkgmeta) tells CurseForge which files to package.

The original [`release.yml`](.github/workflows/release.yml) still builds ZIPs for direct, manually pushed tags. Tags created by `publish.yml` use the release action in that same workflow, because GitHub Actions does not automatically trigger another workflow from a tag push made with the default `GITHUB_TOKEN`.

For repository work and continuation in a new chat, read [AGENTS.md](AGENTS.md) and the dated [project context](PROJECT_CONTEXT.md). Keep decisions and validation results in the repository rather than only in chat.

See [CHANGELOG.md](CHANGELOG.md) and the [MIT License](LICENSE).

---

*The world is more interesting when you have to find your own way.*

Bag-border smoke test: enable **Bags → Hide quest item borders**, move quest and ordinary items between individual/combined native bags, obtain/complete a quest and reload. Quest borders should disappear; quality/new-item overlays and quest-start exclamation marks should remain. Disable or restore to recover original alpha/visibility. Check combat-end retry. Custom bag overlays require separate compatibility work.
