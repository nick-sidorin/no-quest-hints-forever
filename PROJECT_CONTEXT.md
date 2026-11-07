# No Quest Hints Forever — Product Context and Decision Record

> **Reviewed: 2026-11-07.** This is a durable record of product intent and verified development decisions recovered from earlier chats and the repository. It does **not** supersede [README.md](README.md), [CHANGELOG.md](CHANGELOG.md), [AGENTS.md](AGENTS.md), source code or current GitHub issues/PRs. The handoff at the end is a dated snapshot, not a live status feed.

## Why this addon exists

**Read the quest. Explore the world. Find your own way.**

The project began as a small quality-of-life addon for the immersive **World of Warcraft: Forever** experience. The owner wanted the world map to be **geography, not quest GPS**: read the quest, look for landmarks, travel naturally and ask other players for directions rather than following objective blobs, markers and arrows.

The goal is **removing spoilers, not removing the game**. Keep the quest journal and descriptions, real quest progress, the world map itself, quest-giver exclamation marks, ordinary NPC interactions and compatibility with voiceover addons. No automated pathfinding, external quest databases or replacement quest objectives.

A later decision deliberately softened the all-or-nothing approach: when stuck, the player can selectively **Show hint** for a specific quest, revealing Blizzard's native blue area, POI/turn-in marker, journal or tracker badge and possible SuperTrack navigation. Multiple quest IDs can be allowed. Doing this must not turn on hints for unrelated quests, add quests to the right-side tracked list, or pop open the map from a context-menu action.

## Feature boundaries — published v1.3.0

Six independent per-character options are available. They should not affect one another.

| Setting | User-facing intent and limits |
| --- | --- |
| Hide quest map hints | Hide supported Blizzard world-map/minimap quest areas, markers and navigation. Allow individually approved quest hints; restore the player's own CVar values on disable. |
| Hide objective tracker | Conceal the right-side task list cosmetically without deleting quest data, changing tracked quests or hiding the journal. |
| Hide quest hints in tooltips | Hide objective titles/progress in native unit and world-object mouseover lines, not normal unit/object information. |
| Hide quest NPC names | Override only `UnitNameFriendlySpecialNPCName`. Blizzard's shared category may hide other special/friendly NPC names too: this is not precise quest-NPC filtering. |
| Hide item sell prices | Hide native sell-price tooltip lines **until a merchant is open**, without changing actual vendor values or other addons' overlays. |
| Hide quest progress popups | Suppress the relevant native yellow quest objective notifications, not ordinary information or red UI/combat errors. |

Prefer supported, original Blizzard UI over custom replacements. In particular, selective revealed quests use native providers/pins/badges; original interactive quest markers should remain functional. `C_SuperTrack` can point to a revealed quest without adding it to the watch list, and navigation must remain hidden for unrevealed targets. Some CVars are absent in Forever and some quests lack navigable destinations, so avoid claiming universal support.

### Persistence and the restoration lesson

- Options are saved per character. The legacy `NoQuestHintsForeverChar.enabled` means **map suppression**, and `revealedQuests` holds individually allowed quest IDs. Do not reset these on an upgrade.
- Some affected game CVars are account-scoped. Back up the user's **actual prior values**, reapply only the active character's selected behavior, and restore saved baselines when the relevant feature is disabled. Do not modify other NPC name categories.
- The **1.1.0 bug** captured SavedVariables too early and could fail to restore map settings after `/reload`. **v1.1.1** fixed initialization on `ADDON_LOADED`; older affected installations sometimes needed manual recovery. This is why tests need to reflect Blizzard load/save ordering and character changes.
- Green standalone Lua tests do not prove which Blizzard CVar values persist through `/reload`, logout, disabling an addon or competing addons. Test those in the real Forever client.

## UX decisions — unreleased v1.4.0 on `main`

The owner rejected the extra standalone addon settings dialog. Settings should work like **CatQuest**: six checkboxes directly inside Blizzard **Options → AddOns → No Quest Hints** with compact labels and hover-only descriptions. There are two groups: **Quest hints** (the five quest-related options, including NPC names and yellow progress) and **Additional immersion** (vendor sell prices). `/nqh` opens this standard category.

### Three first-run playstyles

New characters choose one of three realm-rule-style cards:

- **As in Blizzard:** no restrictions; keep normal game behavior.
- **Immersion:** all five quest-related concealment options; vendor prices unaffected.
- **Full immersion:** all six, including merchant-only sell prices.

**No change before confirmation.** Clicking a card only selects it; **Begin adventure** applies it. Closing the chooser, choosing Later or Customize does not select a playstyle. An unfinished chooser must not be mistaken for a completed first run after `/reload`. Existing characters preserve their preferences on upgrade rather than being shown onboarding or force-switched to a preset. Players may subsequently customize individual controls or choose another playstyle.

### Native appearance and interaction lessons

Use Forever's **native** realm-rule imagery rather than generic invented cards or downloaded artwork. The unreleased v1.4.0 implementation (merged via PR #18) uses `Mode-Selection-Card-Regular`, its glow, `Mode-Selection-Ring`, `CircleMask`, and Blizzard icon assets `INV_Misc_Map_01`, `icon_treasuremap` and `Achievement_Zone_ElwynnForest`. Preserve the authored atlas proportions, genuine circular masked portraits, inner text padding, short localized descriptions and a strong native primary confirmation button flanked by two symmetrical smaller buttons. Do not stretch a small template to impersonate a larger native button, or draw a rectangular backup border behind an existing native border.

The first visual iteration needed multiple corrections: external rectangle, squashed border proportions, flat portrait rings, cramped text, unclear confirmation hierarchy and a lingering background ability tooltip. The current preview includes an unscaled fullscreen mouse/wheel **modal blocker** behind the scaled chooser, hides a pre-existing GameTooltip, and releases the shield on all close paths including Esc, Customize, restore and combat. Do not introduce global tooltip hooks or a continuous `OnUpdate` to mask the problem. These are implementation decisions; **latest live visual sign-off is still outstanding**.

### Explicit restoration before removal

The unreleased v1.4.0 code includes `/nqh`, `/nqh status`, and **`/nqh restore`**; the older, ambiguous map-only `on/off` commands are retired **in v1.4.0 only**. Restore game settings disables all six restrictions and returns persistent CVars to saved **personal** values, not arbitrary factory defaults. It retains individual revealed-quest permissions and backups for failed restores. The normal logout path attempts CVar cleanup without clearing the player's configured playstyle; the next login may reapply the chosen settings.

An addon that is disabled/uninstalled cannot clean up afterward, and crashes/forced exits may skip restoration. The owner should explicitly restore **while still running the addon**, with SavedVariables intact. Deleting saved data is not a restoration method. The exact CVar-save ordering and addon-off recovery still need validation in Forever.

## Engineering, tests and release expectations

- **Client:** WoW Forever, TOC Interface 16001. Not Retail or Classic Era; check API availability and combat restrictions instead of assuming Retail APIs. Runtime and tests target **Lua 5.1**.
- **Architecture:** `Localization.lua` before gameplay modules; `NoQuestHintsForever.lua` for persistence/state/CVars, `Options.lua` for Blizzard settings, and `Onboarding.lua` added in PR #18. Selective hint code lives in the `QuestHints`, `QuestMarkers` and `QuestInlineHints` modules; other filters are isolated by concern.
- **CI:** `bash scripts/run_ci.sh` runs all discovered Lua regression suites, syntax validation and TOC/package integrity. The shared packager is `scripts/package_addon.py`, with runtime file list from `.toc` plus LICENSE. For game-UI changes, add tests **and** request real-client validation; mock testing cannot detect `ADDON_ACTION_BLOCKED`.
- **Preview builds:** owner wants a direct download link to **one installation-ready ZIP** containing `NoQuestHintsForever/` immediately within it. The GitHub Actions artifact already downloads as ZIP, so do not nest another package ZIP inside that artifact. Tagged release jobs still use the canonical packaged ZIP.
- **Workflow:** branch + PR, **Squash and merge only**, required passing CI, and a separate explicit release decision. There are existing CurseForge users; never ship a preview automatically. `.github/release-request.txt` triggers the established publish process. `CURSEFORGE_DESCRIPTION.md` is the editable English project-page source; hand over updated short/full copy for a release. CurseForge availability and GitHub Release creation are different things.
- **Languages:** all project documentation, comments, PRs and commit descriptions are in **English**; direct owner chat is **Russian**; actual addon UI/fixture strings continue to support **ruRU/enUS**.

## Dated handoff — checked 2026-11-07

- Repo: https://github.com/nick-sidorin/no-quest-hints-forever. `main` head at review: `10a063159c08c6b3f1511b4f2101670aa62cbc10`. Latest verified GitHub release: [v1.3.0](https://github.com/nick-sidorin/no-quest-hints-forever/releases/tag/v1.3.0). CurseForge listing/upload status was **not independently rechecked**.
- **[PR #18](https://github.com/nick-sidorin/no-quest-hints-forever/pull/18)** was **squash-merged into `main`** on 2026-11-07 (`10a063159c08c6b3f1511b4f2101670aa62cbc10`). It introduced native settings (superseding #16), explicit restoration, first-run playstyles, native visual refinements and modal input shielding. The owner generally tested an **earlier** preview as functional; the latest modal/button revision and all logout/restore/character-change scenarios still lack recorded sign-off. **v1.4.0 is not a published stable release:** test the current merged code in Forever before publishing.
- **[Issue #3](https://github.com/nick-sidorin/no-quest-hints-forever/issues/3)** reports recurrent `ADDON_ACTION_BLOCKED` naming NoQuestHintsForever around the map/quest journal. The triggering interaction and root cause remain unconfirmed; collect preceding action, combat status and `taint.log` before changing hooks. No mock test proves the error resolved.
- **[Main protection ruleset](https://github.com/nick-sidorin/no-quest-hints-forever/rules/26724884)** is active and specifies PRs, squash merges, linear history and no bypass; however, its `required_status_checks` list was **empty** at review time even though PRs run a `build` job. Confirm/configure the actual mandatory check separately; do not mistake a green job for an enforced merge gate.

## Maintenance policy

This document should remain a **decision record with a short, dated handoff**, not a transcript, running debug log or endless list of intermediate artifacts and SHAs. Keep precise bug evidence in Issues, implementation/change discussions in PRs, user instructions in README, version history in CHANGELOG, and enforceable contributor rules in AGENTS. Update this file only when product intent, a material trade-off or the handoff state truly changes.
