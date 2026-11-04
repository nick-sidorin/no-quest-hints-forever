# No Quest Hints — Forever

**Read the quest. Explore the world. Find your own way.**

Remember when finding a quest objective meant reading its description, studying the map, and exploring the world instead of following a marker?

**No Quest Hints — Forever** is a small addon built specifically for **World of Warcraft: Forever**. It is for players who want to navigate Azeroth through quest text, landmarks, and curiosity — not glowing objective areas and arrows.

**No more following dots. Just you, your quest journal, and Azeroth.**

> **Release status:** This is an early, experimental release. The Lua logic has been tested with a mocked WoW environment, but the exact CVar availability and visual results **have not yet been verified in the released Forever client**. See [Testing in Forever](#testing-in-forever) before reporting a feature as working or broken.

## What it does

When enabled, the addon **attempts** to suppress Blizzard's native quest guidance:

- **World map:** quest objective points and highlighted quest areas.
- **Minimap:** highlighted quest objective areas.
- **Navigation:** in-game guidance toward quest objectives.

It deliberately leaves these alone:

- The geographical world map.
- Quest journal and quest descriptions.
- Exclamation marks above quest-giving NPCs.
- The regular on-screen quest tracker.
- Quest voiceover addons.

It does not modify map frames, add custom map overlays, or attempt to hide quest markers created by other addons.

**Remove the directions, not the adventure.**

## Getting started

### Installation

1. Download the addon ZIP and extract it.
2. Copy the **`NoQuestHintsForever`** directory into your Forever client's `Interface/AddOns/` folder.
3. Start or restart Forever and enable the addon in the game's addon list if necessary.
4. Type `/nqh on` on the character you want to play without quest hints.

For the released Forever client, the folder structure is:

```text
World of Warcraft/
└── _forever_/
    └── Interface/
        └── AddOns/
            └── NoQuestHintsForever/
                ├── NoQuestHintsForever.toc
                └── NoQuestHintsForever.lua
```

If you have a custom WoW installation, locate the **Forever** game directory rather than assuming the default Windows location.

### Commands

| Command | Effect |
| --- | --- |
| `/nqh on` | Enable quest-hint suppression for the current character. |
| `/nqh off` | Disable suppression and attempt to restore the settings the addon changed. |
| `/nqh status` | Show the character's ON/OFF setting and the current values of the targeted CVars. |

**New characters start OFF.** The addon never automatically turns itself on for a newly created character.

## Your settings belong to your character

You may want to wander without hints on your main character while keeping the default questing UI on an alt. The addon is designed for exactly that.

- The ON/OFF preference is stored **per character** using `SavedVariablesPerCharacter`.
- It persists through normal logouts and `/reload`.
- The addon tracks the values it changed so `/nqh off` can attempt to restore them, rather than blindly forcing every hint ON.
- Some WoW CVars can be shared between characters. The addon keeps a separate account-level snapshot for the shared settings it manages and attempts to restore outstanding changes when logging into a character with suppression OFF.
- While ON, it listens for `CVAR_UPDATE` and reapplies the hiding settings if the game turns a targeted CVar back on.
- While OFF, it does **not** continuously enforce or manage the game's settings. It may perform a one-time restoration of changes previously made by the addon.

**Note:** WoW saves addon variables on normal logout or reload. A crash or forced termination may prevent the latest preference change from being saved.

## Technical details

### Target client

- **Game:** World of Warcraft: Forever, **not** Retail or Classic Era.
- **TOC Interface:** `16001` in the current manifest. This identifies the expected build, **not** proof that any particular API or CVar works.
- **Runtime:** Blizzard's Lua addon environment; no third-party libraries or dependencies.

### Targeted CVars

The current implementation attempts to set the following CVars to `0`:

| CVar | Intended behavior |
| --- | --- |
| `questPOI` | Suppress quest points of interest on the world map. |
| `showQuestObjectivesOnMap` | Suppress quest objective information on the world map. |
| `questPOILocalStory` | Suppress some local-story quest markers on the world map. |
| `minimapShowQuestBlobs` | Suppress highlighted quest areas on the minimap. |
| `showInGameNavigation` | Suppress Blizzard's in-game navigation hints. |

These names are based on documented Blizzard CVars. **Their existence and actual effects in the released Forever client are not yet confirmed.** Some interface elements may be controlled by other mechanisms. The addon checks whether it can read a CVar and safely ignores unavailable APIs rather than assuming full support.

`/nqh status` shows `unavailable` when a value cannot be read. A reported value of `0` confirms the stored CVar value, **not necessarily that every visual marker disappeared**.

### Persistence and CVar lifecycle

The addon declares two SavedVariables in its `.toc`:

| Variable | Scope | Purpose |
| --- | --- | --- |
| `NoQuestHintsForeverChar` | `SavedVariablesPerCharacter` | The current character's `enabled` flag and original character-scoped CVar values. |
| `NoQuestHintsForeverAccount` | `SavedVariables` | Original values for CVars treated as shared across characters. |

The current implementation uses `C_CVar.GetCVar` and `C_CVar.SetCVar`, with legacy global function fallbacks when the namespace is unavailable. It consults `C_CVar.GetCVarInfo` when present and uses a fallback classification for `showInGameNavigation`. Exact scoping behavior must still be tested in Forever.

When suppression is ON, it applies the CVar changes on login/world entry and on relevant `CVAR_UPDATE` events. It snapshots a value before the first attempted change and does not overwrite that snapshot with the suppressed value on later events.

When suppression is OFF, it attempts to restore saved values; failed restorations remain recorded for a later attempt. An OFF character is not continuously monitored for enforced hiding.

### Repository layout

```text
NoQuestHintsForever/
├── NoQuestHintsForever.toc   # Addon manifest, version, SavedVariables
└── NoQuestHintsForever.lua   # CVar management, events, slash commands
tests/
└── test_runtime.lua          # Mocked Lua runtime checks
README.md
CHANGELOG.md
```

The release ZIP only needs the `NoQuestHintsForever/` directory. The repository's tests and documentation do not need to be installed into the game.

### Running the local tests

From the repository root, using a standard Lua interpreter:

```sh
lua tests/test_runtime.lua
```

The test harness covers default-OFF behavior, persistence between simulated sessions, CVar re-enforcement, switching to a second character, restoration, and absent CVar APIs. **These are mocked-runtime tests, not an integration test with the Forever game client.**

## Testing in Forever

Before calling this version fully compatible, verify the following in the actual released client:

1. **Fresh character:** Run `/nqh status`. The default should be OFF. Note which CVars report `unavailable`.
2. **Enable hiding:** Run `/nqh on`, inspect the world map, minimap, objective areas, and navigation guidance. Verify that journal text, NPC exclamation marks, and the on-screen tracker remain usable.
3. **Re-enforcement:** While ON, try `/console questPOI 1`, then `/nqh status`. Check whether the client sends the expected CVar update and whether the value returns to `0`.
4. **Persistence:** Log out normally and back in. Check that the character remains ON.
5. **Character isolation:** Log into a second character that has never enabled the addon. It should be OFF and should not inherit forced quest-hint suppression from the first character.
6. **Restoration:** Back on the first character, run `/nqh off` and check whether previously changed hints return to their original state.

If some visual hints remain even with their relevant CVars at `0`, please report the specific hint and location rather than assuming all quest hints use the same API.

## Issues and contributions

Bug reports and suggestions are welcome: [GitHub Issues](https://github.com/nick-sidorin/no-quest-hints-forever/issues).

For a useful report, include the Forever client build, addon version, `/nqh status` output, reproduction steps, expected and actual behavior, and (if relevant) a map or minimap screenshot.

- [Changelog](CHANGELOG.md)
- Blizzard API references: [C_CVar.GetCVar](https://warcraft.wiki.gg/wiki/API_C_CVar.GetCVar), [C_CVar.GetCVarInfo](https://warcraft.wiki.gg/wiki/API_C_CVar.GetCVarInfo), [Console variables](https://warcraft.wiki.gg/wiki/Console_variables)

---

*The world is more interesting when you have to find your own way.*
