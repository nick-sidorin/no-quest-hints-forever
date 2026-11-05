# No Quest Hints

**Read the quest. Explore the world. Find your own way.**

Remember when finding a quest objective meant reading the description, looking at your map, and exploring instead of following a marker?

**No Quest Hints** is a lightweight addon built specifically for **World of Warcraft: Forever**. It lets you choose how much of Blizzard's quest guidance you want to keep, without removing the quest journal or changing quest data.

**No more following dots. Just you, your quest journal, and Azeroth.**

> **Compatibility status:** Quest map/minimap hint suppression and the 1.1.1 `on → /reload → off` fix have been tested in the released Forever client. The **1.2.0 selective native quest blobs are an experimental test build**, not yet verified in the game. Some CVars are not available in Forever. Cross-character switching still requires a live test.

## Features

Two **independent, per-character** options:

- **Hide quest map hints:** Suppress native quest markers and highlighted areas on the world map/minimap, and Blizzard's navigation guidance where available.
- **Hide objective tracker:** Remove the right-side list of tracked objectives and progress counters from view. The underlying tracking data and quest journal are unaffected.
- **Selective quest hints:** While built-in quest map hints are hidden, open a quest and click **Show hint** in its detail panel, or use its right-click menu in the journal. The addon asks Blizzard to draw the **original blue objective area** only for chosen quests, rather than placing map icons. Use **Hide hint** to remove a quest. Multiple quests may be allowed, with their IDs saved per character.

The addon leaves the geographical map, quest descriptions, quest-giver exclamation marks above NPCs, and quest voiceover addons alone. It does not hide markers created by other quest addons.

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
                ├── NoQuestHintsForever.lua
                ├── Options.lua
                ├── QuestHints.lua
                ├── QuestHintPins.xml
                └── LICENSE
```

Restart the game or use `/reload` if you're updating an existing installation. Ensure you do not have an extra nested addon folder.

### Open settings

- Type **`/nqh`** without arguments to open or close the standalone Blizzard-styled settings window.
- Or visit **Esc → Options → AddOns → No Quest Hints** and click **Open addon settings**.

The settings window contains two checkboxes:

| Checkbox | Behavior | Default for new characters |
| --- | --- | --- |
| Hide quest map hints | Hide the supported built-in map/minimap markers and navigation | Off |
| Hide objective tracker | Hide the on-screen right-side task list | Off |

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
- Individual quest map permissions are stored in the character's `revealedQuests` table, keyed by quest ID. The addon creates a **separate native `QuestPOIFrame`** using Blizzard's `QuestBlobPinMixin` and calls `DrawBlob(questID, true)` only for allowed quests. Its refresh omits Blizzard's global `questPOI` gate, but only for our separate frame. Whether the game engine permits rendering native blobs with that CVar off **must be checked in Forever**. If global hint hiding is OFF, the addon draws no additional blobs and Blizzard controls the normal map. Blizzard's quest-watch state is never modified.
- The tracker option is cosmetic: the addon changes the Blizzard `ObjectiveTrackerFrame` alpha to zero, and disables its mouse input when allowed. It retains that frame's previous alpha/mouse values in memory for restoration when unchecked.
- Blizzard can update the tracker itself. The addon watches its `Show` and `SetAlpha` methods, then **defers** its own update rather than mutating Blizzard frames inside a secure hook. There is no continuous `OnUpdate` loop.
- If the tracker frame is not loaded, the addon waits until it appears instead of raising an error.

The goal is to leave the normal game behavior alone whenever each option is disabled. Another addon that also edits the same frame or CVars may conflict.

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

The addon attempts to set available CVars to `0`. In the initially tested Forever client, `showQuestObjectivesOnMap` and `minimapShowQuestBlobs` reported **unavailable**. The other three could be read and set. A `0` in `/nqh status` does not, by itself, prove a visual feature is suppressed.

### Source layout

```text
NoQuestHintsForever/
├── NoQuestHintsForever.toc    # Interface, version, SavedVariables and load order
├── NoQuestHintsForever.lua    # CVar and tracker control; slash commands
├── Options.lua               # Native window and Blizzard AddOns entry
├── QuestHints.lua            # Journal buttons, per-quest whitelist and map provider
├── QuestHintPins.xml         # Native Blizzard QuestPOIFrame template
└── LICENSE                   # MIT license in the installation archive
tests/
├── test_runtime.lua          # SavedVariables/reload and CVar regression checks
├── test_ui.lua               # UI, tracker hook, combat and alt simulations
└── test_quest_hints.lua      # Native blobs, journal buttons, menu and allowlist tests
.github/
├── release-request.txt       # Release request: changing this triggers publication
└── workflows/
    ├── release.yml           # Verify/build ZIP on commits and tags
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
```

Mocked tests check Lua loading order, CVar restoration, independent checkboxes, a delayed Blizzard tracker, re-hiding after Blizzard changes alpha, combat and character isolation. The selective hint tests validate native `QuestPOIFrame` use, per-quest filtering, journal buttons, context menu, load order and per-character reload. These cannot prove that the **engine** draws blobs with `questPOI=0`. **They are not a substitute for an in-game integration test.**

## Validation checklist for Forever 1.2.0

1. Run `/nqh`: confirm the standalone settings window opens with two checkboxes. Open it again to close it.
2. Open **Options → AddOns → No Quest Hints - Forever**: confirm **Open addon settings** opens the same window.
3. Verify that enabling **Hide quest map hints** removes the built-in quest areas/markers but does not hide the objective tracker.
4. Enable **Hide objective tracker**: verify the full right-side list disappears; journal, quest text and NPC exclamation marks remain.
5. Uncheck the tracker option: its original display returns. Check quest updates and world-map opening while it is hidden, and check whether it stays hidden.
6. Run `/nqh on`, `/reload`, `/nqh off`; verify map hints return and the tracker checkbox keeps its independent state.
7. Log in as another character: verify default-off settings do not inherit hidden hints. Switch back to confirm both options persist.
8. In the native journal, open a quest and click **Show hint**. Check whether its **native blue Blizzard objective area** appears while every other quest stays hidden. Test two quests, then remove them one by one. This experiment deliberately has **no custom quest icons**. If the blue blob does not appear, report that result; the `questPOI=0` engine behavior is still unverified.
9. Try right-clicking a quest **in the journal** and using **Show hint / Hide hint**. The right-side objective tracker menu is not yet modified because Blizzard's menu tag does not pass a quest ID directly. The tracker visibility checkbox remains independent.
10. Check both quest detail layouts (the map's detail panel and the separate popup window) and confirm the compact centered hint button does not overlap Blizzard's Back button or CatQuest's Read button.
11. If possible, check in combat and Edit Mode. Note any blocked-action error, click-blocking invisible region or conflict with other UI addons.

Please report the Forever build, version, `/nqh status` output, steps to reproduce and screenshots at [GitHub Issues](https://github.com/nick-sidorin/no-quest-hints-forever/issues).

## Automated releases and CurseForge

**Normal development:** Pushes to `main` run tests and build an installable ZIP in [GitHub Actions](https://github.com/nick-sidorin/no-quest-hints-forever/actions). They **do not publish** to CurseForge.

**Publishing on request:** The permanent [`publish.yml`](.github/workflows/publish.yml) watches [`.github/release-request.txt`](.github/release-request.txt). To release a new version, first update the `.toc` version and `CHANGELOG.md`, then change the request file to e.g. `1.2.0-beta.1`. The workflow runs tests, verifies the version, creates the annotated `v1.2.0-beta.1` tag, builds the ZIP and publishes a GitHub prerelease. For a verified stable version, request `1.2.0`, producing a normal Release. Duplicate tag names are rejected. The owner can ask the repository-maintaining assistant to perform these steps without manual tag creation.

**CurseForge:** The project uses GitHub source-based Automatic Packaging and a GitHub webhook. The tag push requests packaging through the configured webhook; CurseForge handles its own file approval. Do not add a second upload through Actions, and **never commit CurseForge author tokens**. The [.pkgmeta](.pkgmeta) tells CurseForge which files to package.

The original [`release.yml`](.github/workflows/release.yml) still builds ZIPs for direct, manually pushed tags. Tags created by `publish.yml` use the release action in that same workflow, because GitHub Actions does not automatically trigger another workflow from a tag push made with the default `GITHUB_TOKEN`.

See [CHANGELOG.md](CHANGELOG.md) and the [MIT License](LICENSE).

---

*The world is more interesting when you have to find your own way.*
