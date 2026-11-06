# No Quest Hints

**Read the quest. Explore the world. Find your own way.**

Remember when finding a quest objective meant reading the description, looking at your map, and exploring instead of following a marker?

**No Quest Hints** is a lightweight addon built specifically for **World of Warcraft: Forever**. It lets you choose how much of Blizzard's quest guidance you want to keep, without removing the quest journal or changing quest data.

**No more following dots. Just you, your quest journal, and Azeroth.**

> **Compatibility status:** Tested in World of Warcraft: Forever. Native blue quest objective areas, round progress/turn-in map pins, the in-world navigation diamond with distance, quest icons in the journal and tracker, and the Russian quest-hint UI have been confirmed in player testing. The 1.1.1 `/reload` restoration fix was also verified. Some Blizzard CVars are unavailable in Forever; switching between characters has not yet been verified in the live client.

## Features

> **Development branch:** Version 1.3.0 is being prepared and is **not published**. The optional tooltip setting described below is available only in a manually installed development build; the current stable CurseForge release remains v1.2.0.

Four **independent, per-character** options in the unreleased development version:

- **Hide quest map hints:** Suppress native quest markers and highlighted areas on the world map/minimap, and Blizzard's navigation guidance where available.
- **Hide objective tracker:** Remove the right-side list of tracked objectives and progress counters from view. The underlying tracking data and quest journal are unaffected.
- **Hide quest hints in tooltips (unreleased 1.3.0):** Remove the quest title, objective progress and group quest lines from native unit and world-object mouseover tooltips. Normal creature names, levels and other tooltip lines remain.
- **Hide quest NPC names (unreleased 1.3.0):** Temporarily override Blizzard's `UnitNameFriendlySpecialNPCName` setting to conceal quest-relevant floating names while preserving unrelated NPC-name CVars, then restore the original account-wide CVar when disabled. **Blizzard groups some special/friendly NPC names with quest NPCs under this setting, so those may also disappear.** This is a documented Blizzard limitation, not quest-by-quest name filtering.
- **Selective quest hints:** While built-in quest map hints are hidden, open a quest and click **Show hint** next to the **Back** button in the journal, or right-click a quest in either the journal or objective tracker. The addon uses the **original blue Blizzard objective areas** and attempts to show Blizzard's own '?' / progress icons only for chosen quests. Use **Hide hint** to remove them. Multiple quests may be allowed, with their IDs saved per character. **Context-menu actions do not open the map**; clicking a quest normally still opens its details. When permission is granted, that quest becomes Blizzard's super-tracked navigation target (without adding it to the right-side watch list), enabling the native world-space diamond and distance if the client can navigate to it.

The addon leaves the geographical map, quest descriptions, quest-giver exclamation marks above NPCs, and quest voiceover addons alone. It does not hide markers created by other quest addons. **Native badges beside titles in the quest journal and objective tracker** are selectively restored only for allowed quest IDs. The user interface automatically uses **Russian** when the WoW client locale is `ruRU`; otherwise it uses English.

**Remove the directions, not the adventure.**

## Getting started

### Installation

Download the installable ZIP (from [GitHub Actions](https://github.com/nick-sidorin/no-quest-hints-forever/actions) for unreleased test builds or from [GitHub Releases](https://github.com/nick-sidorin/no-quest-hints-forever/releases) for published versions). Copy the `NoQuestHintsForever/` folder into your Forever client's `Interface/AddOns/` directory:

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
                ├── QuestHints.lua
                ├── QuestMarkers.lua
                ├── QuestHintPins.xml
                ├── QuestInlineHints.lua
                └── LICENSE
```

Restart the game or use `/reload` if you're updating an existing installation. Ensure you do not have an extra nested addon folder.

### Open settings

- Type **`/nqh`** without arguments to open or close the standalone Blizzard-styled settings window.
- Or visit **Esc → Options → AddOns → No Quest Hints** and click **Open addon settings**.

The development version's settings window contains four checkboxes:

| Checkbox | Behavior | Default for new characters |
| --- | --- | --- |
| Hide quest map hints | Hide the supported built-in map/minimap markers and navigation | Off |
| Hide objective tracker | Hide the on-screen right-side task list | Off |
| Hide quest hints in tooltips (dev) | Hide quest titles and progress on NPC/object mouseover, not in quest journal | Off |
| Hide quest NPC names (dev) | Also hides some special/friendly NPC names due to Blizzard's shared CVar | Off |

The second option is independent of the first: you can keep the task list while hiding map hints, or hide both. **The quest hint allowlist is also independent of objective tracking** — the right-side list can stay hidden even when selected quest areas are visible on the map.

### Slash commands

| Command | What it does |
| --- | --- |
| `/nqh` | Open or close the addon settings window. |
| `/nqh on` | Turn **on** hiding quest **map hints only**. |
| `/nqh off` | Turn **off** hiding quest **map hints only** and restore their saved CVar values. |
| `/nqh status` | Display both option states and the values of targeted CVars. |

The existing `on`/`off` commands stay backward-compatible with version 1.1.1. They do **not** toggle the objective tracker. Use the new checkbox for that.

## Per-character settings and persistence

- Settings are stored in `NoQuestHintsForeverChar` using `SavedVariablesPerCharacter`. The existing `enabled` flag is retained as the **Hide quest map hints** value so existing users keep their preference. The new `hideTracker` value defaults to **false**.
- CVar baselines are saved before the addon modifies them. A separate `NoQuestHintsForeverAccount` SavedVariable tracks original values for CVars treated as shared across characters.
- While map hint suppression is enabled, relevant `CVAR_UPDATE` events trigger re-enforcement. When disabled, the addon restores the saved baselines and stops enforcing.
- Individual quest permissions are stored in the character's `revealedQuests` table, keyed by quest ID. A separate native `QuestPOIFrame` uses Blizzard's `QuestBlobPinMixin` and calls `DrawBlob(questID, true)` for allowed quests. The original blue blobs work in Forever with `questPOI=0`. A second provider uses a unique XML template inherited from Blizzard's `QuestPinTemplate` and `QuestDataProviderMixin:AddQuest()` for the clickable map POIs; both areas and POIs have been confirmed in an in-game test.
- The journal's `POIButtonOwnerMixin` and tracker's `ObjectiveTrackerQuestPOIBlockMixin` originally suppress all title badges when `questPOI=0`. The addon restores their *native pooled buttons* only for allowed quest IDs, using post-hooks and deferred layout updates. **This new behavior still requires in-game validation.**
- `Show hint` changes the native `C_SuperTrack` quest target, **not** the Blizzard watch list, so it can drive the world-space diamond while leaving the right-side list independently hidden. While the global Hide Quest Map Hints option is ON, `showInGameNavigation` is allowed only when the active super-tracked quest is itself permitted; it is otherwise suppressed. The original account/character CVar value is restored when the global option is turned OFF. Navigation cannot be guaranteed for quests lacking a valid destination in the Forever client.
- The optional NPC name suppression uses only `UnitNameFriendlySpecialNPCName`. It never changes `UnitNameHostleNPC`, `UnitNameInteractiveNPC`, `UnitNameNPC` or `ShowQuestUnitCircles`. The original shared CVar is kept in `NoQuestHintsForeverAccount.npcNameOriginal` while suppression is enabled, restored when disabled or on the next character if they have the option turned off. Blizzard's NPC names dropdown may display an adjusted category while this override is active. Use Blizzard's own menu to control other name categories.
- When global hint suppression is OFF, the addon draws no extra map pins and Blizzard handles the normal map. Its journal/tracker badge hooks likewise stay passive.
- The tracker option is cosmetic: the addon changes the Blizzard `ObjectiveTrackerFrame` alpha to zero, and disables its mouse input when allowed. It retains that frame's previous alpha/mouse values in memory for restoration when unchecked.
- Blizzard can update the tracker itself. The addon watches its `Show` and `SetAlpha` methods, then **defers** its own update rather than mutating Blizzard frames inside a secure hook. There is no continuous `OnUpdate` loop.
- If the tracker frame is not loaded, the addon waits until it appears instead of raising an error.

The goal is to leave the normal game behavior alone whenever each option is disabled. **The new name-CVar override is account-wide at the game level** even though the addon preference is per character; when switching characters, the addon restores or reapplies the override for the newly loaded character. Another addon that also edits the same frame or CVars may conflict.

WoW normally saves SavedVariables on logout and `/reload`; forced exits or crashes can lose the most recent change.

## Technical details

### Target client and dependencies

- **Client:** World of Warcraft: Forever, **not** Retail or Classic Era.
- **TOC Interface:** `16001`, checked against early Forever client builds. This does not by itself prove runtime API compatibility.
- **Dependencies:** None. Uses Blizzard UI templates and Lua.
- **Blizzard Settings integration:** `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`, if present.
- **Stand-alone window:** native `BasicFrameTemplateWithInset`, `UICheckButtonTemplate`, and `UIPanelButtonTemplate`.
- **Tracker:** `ObjectiveTrackerFrame`. These behaviors must still be validated in the current release of Forever, including combat and Edit Mode.

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
├── Options.lua               # Native window and Blizzard AddOns entry
├── QuestHints.lua            # Per-quest permission, menus, native blue blobs and SuperTrack
├── QuestMarkers.lua          # Filtered native in-progress / turn-in map POI buttons
├── QuestHintPins.xml         # XML templates inheriting native Blizzard map widgets
├── QuestInlineHints.lua      # Per-quest journal and objective-tracker POI badges
├── QuestTooltips.lua         # Opt-in quest line suppression on unit/object hover
└── LICENSE                   # MIT license in the installation archive
tests/
├── test_runtime.lua          # SavedVariables/reload and CVar regression checks
├── test_ui.lua               # UI, tracker hook, combat and alt simulations
├── test_quest_hints.lua      # Native blobs, journal/tracker menus and whitelist tests
├── test_quest_markers.lua    # Native quest progress/turn-in pin tests
├── test_inline_hints.lua     # Journal/tracker title badges, secure/deferred layout
├── test_navigation.lua       # Selective in-world diamond and CVar restoration
├── test_localization.lua     # Russian and English UI translations
└── test_quest_tooltips.lua   # Tooltip callback, late load and isolation
.github/
├── release-request.txt       # Release request: changing this triggers publication
└── workflows/
    ├── release.yml           # Manual/test and tagged-release builds
    └── publish.yml           # Automated tag + GitHub Release publication
CHANGELOG.md
README.md
LICENSE
.pkgmeta                       # CurseForge's native source packager configuration
```

Local tests, using Lua 5.1 from the repository root:

```sh
lua5.1 tests/test_runtime.lua
lua5.1 tests/test_ui.lua
lua5.1 tests/test_quest_hints.lua
lua5.1 tests/test_quest_markers.lua
lua5.1 tests/test_inline_hints.lua
lua5.1 tests/test_navigation.lua
lua5.1 tests/test_localization.lua
lua5.1 tests/test_quest_tooltips.lua
```

Mocked tests check Lua loading order, CVar restoration, independent checkboxes, a delayed Blizzard tracker, re-hiding after Blizzard changes alpha, combat and character isolation. The unreleased name override tests preserve and restore the original account CVar and check that unrelated name CVars remain untouched. Selective hint tests validate native blob calls, map POI filtering, tracker right-click capture, **no automatic map opening**, safe navigation gating, original title badges and per-character reload. Native blobs, map POIs, in-world navigation diamond, title badges and Russian quest-hint labels have also been checked in the released Forever client. **Automated tests do not replace broader in-game regression testing**, particularly across different characters and UI addons.

## Validation checklist for Forever 1.2.0

1. Run `/nqh`: confirm the standalone settings window opens with two checkboxes. Open it again to close it.
2. Open **Options → AddOns → No Quest Hints**: confirm **Open addon settings** opens the same window.
3. Verify that enabling **Hide quest map hints** removes the built-in quest areas/markers but does not hide the objective tracker.
4. Enable **Hide objective tracker**: verify the full right-side list disappears; journal, quest text and NPC exclamation marks remain.
5. Uncheck the tracker option: its original display returns. Check quest updates and world-map opening while it is hidden, and check whether it stays hidden.
6. Run `/nqh on`, `/reload`, `/nqh off`; verify map hints return and the tracker checkbox keeps its independent state.
7. Log in as another character: verify default-off settings do not inherit hidden hints. Switch back to confirm both options persist.
8. In the journal, click **Show hint** next to **Back**. Confirm the blue objective area is visible and look for Blizzard's native round quest icon (in-progress or turn-in). If an icon is missing even when a blob is present, note the quest title and state; the client's quest POI APIs may not return coordinates with `questPOI=0`.
9. Right-click a quest **in the objective tracker** and select **Show hint**. Verify **the map does not automatically open**; the allowed quest's map guidance still appears when you open the map normally. Repeat with a different quest, then **Hide hint**. Check that the right-click never affects a different quest. The journal context menu should behave the same way.
10. With global quest hints hidden, show a hint and return to the game world. Check for Blizzard's in-world **navigation diamond and distance** toward that quest. Hide it and verify the diamond disappears. If another quest becomes SuperTracked, verify it is suppressed until explicitly allowed. Confirm normal CVar behavior with `/nqh off`.
11. Verify the native '?' / '...' badges appear beside the title of **allowed quests only** in both the quest journal and right-side objective tracker. Verify they disappear when a hint is hidden, and return after `/reload`.
12. With a **Russian client (`ruRU`)**, check the localized UI and context-menu labels; the short journal button should read **Показать / Скрыть**.
13. Confirm that the journal button is horizontally aligned with Blizzard's **Back** button and does not overlap CatQuest's **Read** button. Check both detail layouts.
14. If possible, check in combat and Edit Mode. Note any blocked-action error, click-blocking invisible region or conflict with other UI addons.

Please report the Forever build, version, `/nqh status` output, steps to reproduce and screenshots at [GitHub Issues](https://github.com/nick-sidorin/no-quest-hints-forever/issues).

## Automated releases and CurseForge

**Normal development:** Commits to `main` do **not** automatically run Actions. This avoids noisy failure notifications during active development. To produce a test ZIP, run **Actions → Build and release → Run workflow** manually; this runs tests and uploads the installable ZIP as an artifact but **does not publish** it to CurseForge. Pushing an explicit version tag still runs the build/release workflow.

**Publishing on request:** The permanent [`publish.yml`](.github/workflows/publish.yml) watches [`.github/release-request.txt`](.github/release-request.txt). To release a new version, first update the `.toc` version and `CHANGELOG.md`, then change the request file to e.g. `1.2.0-beta.1`. The workflow runs tests, verifies the version, creates the annotated `v1.2.0-beta.1` tag, builds the ZIP and publishes a GitHub prerelease. For a verified stable version, request `1.2.0`, producing a normal Release. Duplicate tag names are rejected. The owner can ask the repository-maintaining assistant to perform these steps without manual tag creation.

**CurseForge:** The project uses GitHub source-based Automatic Packaging and a GitHub webhook. The tag push requests packaging through the configured webhook; CurseForge handles its own file approval. Do not add a second upload through Actions, and **never commit CurseForge author tokens**. The [.pkgmeta](.pkgmeta) tells CurseForge which files to package.

The original [`release.yml`](.github/workflows/release.yml) still builds ZIPs for direct, manually pushed tags. Tags created by `publish.yml` use the release action in that same workflow, because GitHub Actions does not automatically trigger another workflow from a tag push made with the default `GITHUB_TOKEN`.

See [CHANGELOG.md](CHANGELOG.md) and the [MIT License](LICENSE).

---

*The world is more interesting when you have to find your own way.*
