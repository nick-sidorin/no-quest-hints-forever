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

The owner rejected the extra standalone addon settings dialog. Settings should work like **CatQuest**: six checkboxes directly inside Blizzard **Options → AddOns → No Quest Hints** with compact labels and hover-only descriptions. PR #18 initially grouped them into **Quest hints** and **Additional immersion**. The owner subsequently approved **Quest hints** plus **Item prices**, with two equal-rank price controls in pending PR #20 (see below); that change is not yet in main. `/nqh` opens this standard category.

### Three first-run playstyles

New characters choose one of three realm-rule-style cards:

- **As in Blizzard:** no restrictions; keep normal game behavior.
- **Immersion:** all five quest-related concealment options; vendor prices unaffected.
- **Full immersion:** quest concealment plus hidden prices outside trading. Pending PR #20 deliberately keeps auction prices visible by default, following the owner's explicit choice; strict auction hiding is a separate manual option.

**No change before confirmation.** Clicking a card only selects it; **Begin adventure** applies it. Closing the chooser, choosing Later or Customize does not select a playstyle. An unfinished chooser must not be mistaken for a completed first run after `/reload`. Existing characters preserve their preferences on upgrade rather than being shown onboarding or force-switched to a preset. Players may subsequently customize individual controls or choose another playstyle. Completion is recorded by `onboardingComplete`, not by whether all checkboxes happen to be OFF. Restoring settings does not make an existing character a new install. Deleting the addon folder does not delete its SavedVariables; modifying save files while the game runs can be overwritten from memory.

### Native appearance and interaction lessons

Use Forever's **native** realm-rule imagery rather than generic invented cards or downloaded artwork. The unreleased v1.4.0 implementation (merged via PR #18) uses `Mode-Selection-Card-Regular`, its glow, `Mode-Selection-Ring`, `CircleMask`, and Blizzard icon assets `INV_Misc_Map_01`, `icon_treasuremap` and `Achievement_Zone_ElwynnForest`. Preserve the authored atlas proportions, genuine circular masked portraits, inner text padding, short localized descriptions and a genuine `SharedGoldRedButtonExtraLargeTemplate` primary confirmation button with two `SharedButtonSmallTemplate` actions aligned symmetrically below its left/right edges. The Selected label belongs inside the card, clear of its bottom border. Do not stretch a small template to impersonate a larger native button, or draw a rectangular backup border behind an existing native border.

The first visual iteration needed multiple corrections: external rectangle, squashed border proportions, flat portrait rings, cramped text, unclear confirmation hierarchy and a lingering background ability tooltip. The current preview includes an unscaled fullscreen mouse/wheel **modal blocker** behind the scaled chooser, hides a pre-existing GameTooltip, and releases the shield on all close paths including Esc, Customize, restore and combat. Do not introduce global tooltip hooks or a continuous `OnUpdate` to mask the problem. The owner reviewed the functional preview and subsequent in-game visual screenshots, approved the final modal/native-button layout, and explicitly requested merging #18 after moving Selected inside the lower border (60px inset). That request was fulfilled. This approval is not evidence that every logout/restore scenario was independently verified or that Issue #3 is fixed.

### Explicit restoration before removal

The unreleased v1.4.0 code includes `/nqh`, `/nqh status`, and **`/nqh restore`**; the older, ambiguous map-only `on/off` commands are retired **in v1.4.0 only**. Restore game settings disables all six restrictions and returns persistent CVars to saved **personal** values, not arbitrary factory defaults. It retains individual revealed-quest permissions and backups for failed restores. The normal logout path attempts CVar cleanup without clearing the player's configured playstyle; the next login may reapply the chosen settings.

An addon that is disabled/uninstalled cannot clean up afterward, and crashes/forced exits may skip restoration. The owner should explicitly restore **while still running the addon**, with SavedVariables intact. Deleting saved data is not a restoration method. The exact CVar-save ordering and addon-off recovery still need validation in Forever.

## Approved follow-up — independent item-price controls (PR #20, pending)

The owner rejected the first auction preview's **Show at auction** child checkbox: its positive meaning conflicted with the parent's negative meaning, and the small indented/disabled row looked subordinate. The final approved model is two independently editable, equal-rank checkboxes under **Item prices**, both phrased as hiding:

| Context | Controlling setting | Default |
| --- | --- | --- |
| Neither merchant nor auction UI is open | Hide outside trading (`hideSellPrices`) | OFF |
| Modern or legacy auction UI is open | Hide at auction (`hideAuctionSellPrices`) | OFF |
| A merchant is open | Native vendor sell values are always visible | No hiding override |

This is the native NPC vendor sell amount, **not** a market estimate, acquisition cost, auction deposit or suggested listing price. Showing it at auction is convenient; hiding it is available for stricter roleplay. The owner explicitly chose **auction values visible when selecting Full immersion**. Thus Full sets outside-trading hiding ON and auction hiding OFF; the other presets set both OFF. A preset reapplies the full nine-checkbox configuration, `/reload` preserves manual choices, and restore/native defaults turn all restrictions OFF.

The earlier preview stored an inverse dependent permission. Migrate it to effective independent hiding: `hideAuctionSellPrices = old hideSellPrices == true AND old showAuctionSellPrices == false`, unless a new-format value already exists; then remove the obsolete field. Migrate only after first-run detection. This preserves effective price visibility, rather than an inactive old permission. Do not reintroduce a parent dependency or small-font child control.

Native window visibility is checked at tooltip composition, including late-loaded `AuctionHouseFrame` and legacy `AuctionFrame`; `IsVisible` takes priority over `IsShown`. Re-hover to rebuild a tooltip after a change. Keep non-item tooltip isolation and other addons' price overlays intact; no global hooks or polling are needed.

### Concise playstyle copy

The owner rejected both long feature enumerations and a pricing-tier comparison layout. Keep the existing three native cards with short prose. The middle describes only quest guidance (no price commentary), and the right adds hidden item sell values outside trading. The approved English copy in #20 is:

- **Immersion:** Hide quest guidance. Read the quests and find your own way.
- **Full immersion:** Everything in Immersion, plus hidden quest levels and item sell prices outside trading.

Localize both immediately in `enUS` and `ruRU`; do not remove the Russian UI when translating repository documentation to English.

## Tracker ghost input and quest-title controls (owner follow-up)

The owner reported that the hidden objective tracker still displayed quest tooltips when hovering its former rows. Source review confirmed the parent was made transparent and its own mouse input disabled, but descendant header buttons remained interactive. The pending fix suppresses root and descendants' click/motion/wheel input, preserves exact original flags, handles newly pooled blocks and restores detached children. It defers protected input changes during combat and retries failed restoration. Only an existing tooltip owned by that subtree is hidden; no global tooltip hooks or world-blocking tracker overlay.

The owner also requested two separate controls for native journal/tracker titles:
- **Hide quest levels** removes numeric `[level]` decoration. **Full immersion enables this**, while other presets leave it OFF.
- **Hide difficulty colors** uses normal yellow quest titles instead of level-based green/orange/red. **Every preset leaves it OFF**; it is manual-only for players seeking stricter concealment.

The native Forever/Camelot `QuestUtilsOverrides.GetQuestTitlePrefix` returns a numeric prefix unconditionally, explaining why the default map menu checkbox may not remove it. `QuestPresentation.lua` filters only known title regions after deferred native updates, using raw quest title/level metadata. Preserve party counts, numbers inside real titles, tags, underlying quest data and unrelated UI. The color filter handles outer native difficulty wrappers and hover updates, not NPC/item/objective coloring. Disable/restore uses per-quest snapshots and checks pooled reuse. No global formatter replacements or continuous polling.

These additions expand pending #20 to nine equal-rank controls: seven under Quest hints and two under Item prices. Existing users' new presentation flags remain OFF until explicitly changed or a preset is selected again. Restore/defaults turn all nine OFF. The functionality is implemented and regression-tested in the combined preview, but has not yet been verified by the owner in Forever.

## Engineering, tests and release expectations

- **Client:** WoW Forever, TOC Interface 16001. Not Retail or Classic Era; check API availability and combat restrictions instead of assuming Retail APIs. Runtime and tests target **Lua 5.1**.
- **Architecture:** `Localization.lua` before gameplay modules; `NoQuestHintsForever.lua` for persistence/state/CVars, `Options.lua` for Blizzard settings, and `Onboarding.lua` added in PR #18. Selective hint code lives in the `QuestHints`, `QuestMarkers` and `QuestInlineHints` modules; other filters are isolated by concern.
- **CI:** `bash scripts/run_ci.sh` runs all discovered Lua regression suites, syntax validation and TOC/package integrity. The shared packager is `scripts/package_addon.py`, with runtime file list from `.toc` plus LICENSE. For game-UI changes, add tests **and** request real-client validation; mock testing cannot detect `ADDON_ACTION_BLOCKED`.
- **Preview builds:** owner wants a direct download link to **one installation-ready ZIP** containing `NoQuestHintsForever/` immediately within it. The GitHub Actions artifact already downloads as ZIP, so do not nest another package ZIP inside that artifact. Tagged release jobs still use the canonical packaged ZIP.
- **Workflow:** branch + PR, **Squash and merge only**, required passing CI, and a separate explicit release decision. There are existing CurseForge users; never ship a preview automatically. `.github/release-request.txt` triggers the established publish process. `CURSEFORGE_DESCRIPTION.md` is the editable English project-page source; hand over updated short/full copy for a release. CurseForge availability and GitHub Release creation are different things.
- **Languages:** all project documentation, comments, PRs and commit descriptions are in **English**; direct owner chat is **Russian**; actual addon UI/fixture strings continue to support **ruRU/enUS**.

## Dated handoff — checked 2026-11-07

- PR #20 is merged (`74439931cf724248635a21d47fdb182f5509c2f3`). PR #21 is now squash-merged (`eee40da35e880f564ee2bf8420f25568e148e70e`) after the owner confirmed both native bag borders and the final Settings section reorder work in Forever. Playstyle and restoration is first, followed by seven quest controls, two independent prices, and one manual-only bag control. Custom bag highlighting, including Baganator, is explicitly left to those addons.
- The owner initially requested release 1.4.0, then **paused publication** to add support access and an onboarding command. No release request file, tag or version was changed; stable remains v1.3.0. **Send a test ZIP only; do not publish until requested again.**
- Current follow-up: **Support → Report a problem** last in Settings, opening a native popup with a selected copyable repository URL and localized instructions to use Issues → New issue. Do not claim automatic browser opening or submit reports. Both ruRU/enUS are required. `/nqh welcome` reopens the existing playstyle chooser, preserves preferences and onboarding completion until confirmation, and uses the existing combat deferral. Help lists it.
- Latest preview follow-ups: the owner reported journal flicker while hovering one circular map pin with three quests revealed. Forever assigns the native OnMouseEnter renderer to periodic UpdateTooltip; each tick also emits MapCanvas.QuestPin.OnEnter and calls QuestLogQuests_Update. NQH-owned pins now disable only that periodic callback, preserving actual hover/leave/click and refreshing native tooltip text on re-entry. Snapshot comparison preserves unchanged pins across repeated quest events; changes to permissions/position/native style/supertrack/map and explicit removal rebuild correctly. Tests reproduced repeated synthetic journal entry before the fix.
- The owner also requested confirmation for clicking Restore game settings: native confirmation, localized ruRU/enUS; no changes until acceptance, cancellation/Escape/missing popup preserves the profile. `/nqh restore` remains explicit and immediate. Both follow-ups require client verification; release remains paused.
- New owner request: a localized one-time login notice after upgrading, inviting users to check `/nqh` for new features. Implemented with actual TOC metadata and account-wide `lastSeenVersion` high-water mark; no reload/alt/downgrade spam, first installs use onboarding only, and legacy existing saves without a baseline receive one notice. No gameplay preference changes or automatic Settings opening. Test ZIPs sharing TOC 1.4.0 do not trigger separate notices. Fifteen Lua 5.1 suites now cover version lifecycle and prior behavior. Release remains paused.
- Local tests cover native GetEditBox and legacy popup field shapes, link selection/focus and Enter/Escape dismissal, missing-popup fallback, unchanged saved state, ruRU/enUS strings, welcome command reopening/combat deferral, and all existing gameplay behavior. Use green final-head CI before sending the installable single-ZIP artifact.
- CurseForge screenshot proposal sent to the owner (the older chat's exact list was not recovered): English three-card chooser with Full immersion selected; Settings top plus lower controls if scrolling is necessary; the same quest-active map without hints and with one selectively revealed hint at identical zoom/position; an immersive world scene with readable quest text. Chooser/settings are the most important new-version images. Skip bag screenshots with Baganator's independent borders. Open the chooser with `/nqh welcome` in this preview.
- Issue #3 (`ADDON_ACTION_BLOCKED`) remains unresolved. No mock test proves freedom from client taint. Main ruleset 26724884 remains active, but its required_status_checks list was empty at review; CI passes independently. No ruleset changes were made.

## Maintenance policy

This document should remain a **decision record with a short, dated handoff**, not a transcript, running debug log or endless list of intermediate artifacts and SHAs. Keep precise bug evidence in Issues, implementation/change discussions in PRs, user instructions in README, version history in CHANGELOG, and enforceable contributor rules in AGENTS. Update this file only when product intent, a material trade-off or the handoff state truly changes.
