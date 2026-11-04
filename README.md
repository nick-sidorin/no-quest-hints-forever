# No Quest Hints — Forever

A minimal, **experimental** addon for **World of Warcraft: Forever**. Explore the world by reading quest descriptions instead of following Blizzard's quest map and navigation hints.

## Commands

- `/nqh on` — suppress the supported native quest hints **for this character**.
- `/nqh off` — stop suppressing hints and restore the values recorded before the addon changed them.
- `/nqh status` — show this character's mode and the actual values of the controlled CVars. An `unavailable` entry means the client did not expose that CVar to the addon.

New characters start **OFF**. The setting persists across `/reload` and normal logouts via `SavedVariablesPerCharacter`.

## What it changes

When enabled, the addon attempts to set these Blizzard CVars to `0` and re-applies them if the game changes them:

| CVar | Intended effect |
| --- | --- |
| `questPOI` | Quest points of interest on the world map |
| `showQuestObjectivesOnMap` | Quest objectives on the main world map |
| `questPOILocalStory` | Local-story quest offers on the world map |
| `minimapShowQuestBlobs` | Quest objective areas on the minimap |
| `showInGameNavigation` | Blizzard's in-game navigation guidance |

The addon does **not** change the quest journal, quest text, the on-screen quest tracker, NPC overhead exclamation marks, or quest voiceover addons. It has no custom overlays or frame manipulation. Quest markers provided by **other addons** (such as Questie) are outside its scope.

**Compatibility warning:** These CVars exist in documented Blizzard UI builds, but their availability and **visual effects in the user's current Forever client have not been verified in game**. Some visual hints may be controlled separately by the game. `/nqh status` helps verify availability, not actual visual behavior.

## Install

Copy `NoQuestHintsForever/` into your **Forever client's** `Interface/AddOns/` directory, so `NoQuestHintsForever.toc` is directly inside that folder. For the released Forever client, the folder is:

```text
World of Warcraft/_forever_/Interface/AddOns/NoQuestHintsForever/
```

The usual Windows installation starts at `C:\Program Files (x86)\World of Warcraft\`. If you have a custom game location, use Battle.net → Forever → gear icon → Show in Explorer to find its `_forever_` directory. The TOC currently declares `## Interface: 16001`, as used by Forever 1.60.1. If the launch build changed this, update the TOC after checking `/dump select(4, GetBuildInfo())`. Fully restart WoW after installing the addon.

## How character isolation works

- `NoQuestHintsForeverChar` (`SavedVariablesPerCharacter`) stores `enabled` and the original character-scoped CVar values.
- `NoQuestHintsForeverAccount` (`SavedVariables`) keeps a temporary snapshot of account-scoped CVar values changed by the addon.
- Logging into an OFF character restores **outstanding account-wide changes made by the addon** and retries any previously failed restores for that character, then stops touching the game's settings. It does not enable hints unconditionally or reset them to Blizzard defaults.
- `/nqh off` restores recorded values and stops listening to CVar changes for enforcement. If a CVar cannot be restored, its snapshot remains for a later attempt.

For reliable persistence, use a normal logout or `/reload` after changing the mode. WoW does not necessarily save addon variables on a crash or force quit.

## Validation needed in the released Forever client

1. On a fresh character, `/nqh status` should report OFF. Check which of the five CVars exist.
2. Use `/nqh on`, open world map and minimap, and check quest markers, highlighted areas, navigation arrow, and standard quest text/tracker/NPC exclamation marks.
3. Use `/console questPOI 1` while ON, then `/nqh status`: if the client fires `CVAR_UPDATE`, it should be restored to `0`.
4. Log out normally, log back into that character and verify ON persists.
5. Switch to a second character that has never used the addon. It should report OFF and retain its normal quest UI, including navigation. Toggle hints manually and verify the addon does not interfere.
6. Log back into the first character and try `/nqh off`. The previously recorded settings should be restored.

Implementation tested outside the game with a mocked Lua environment. **In-game behavior remains unverified**.

## Development

The source is a two-file addon: `NoQuestHintsForever.toc` and `NoQuestHintsForever.lua`. No external runtime dependencies or bundled libraries. Automated mock-runtime checks are in `tests/test_runtime.lua` (run with `texlua tests/test_runtime.lua` or a standard Lua interpreter).

API references: [C_CVar.GetCVar](https://warcraft.wiki.gg/wiki/API_C_CVar.GetCVar), [C_CVar.GetCVarInfo](https://warcraft.wiki.gg/wiki/API_C_CVar.GetCVarInfo), [WoW CVar definitions](https://warcraft.wiki.gg/wiki/Console_variables). The references describe the API; they do **not** constitute in-game validation for the Forever release.

See [CHANGELOG.md](CHANGELOG.md) for version history.
