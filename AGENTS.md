# AGENTS.md — No Quest Hints Forever

Repository-wide instructions for contributors and coding agents. Before substantive work, read [README.md](README.md), [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md), and relevant Issues/PRs. Treat source code and live GitHub state as authoritative over dated context.

## Communication and documentation

- **English is the repository language**: documentation, code comments, commits, PR titles and descriptions, changelogs, and agent-authored issue updates. Exceptions are actual `ruRU` in-game strings, locale test fixtures, verbatim diagnostics and other content whose original language matters. UI strings must be localized in **both `ruRU` and `enUS`** (English fallback).
- Communicate with the owner in **Russian** in chat. Be concise and collaborative; summarize changes, verified checks, limitations, and what needs the owner's in-game feedback. Avoid needless explanations or ceremonial comments.
- Preserve durable decisions here or in `PROJECT_CONTEXT.md`, bugs and reproduction evidence in Issues, and change rationale in PRs. Refresh dated context for meaningful handoffs, not after every commit. Never copy private chats, personal data, tokens, or unsupported guesses into this repository.

## Product and safety invariants

- Target **World of Warcraft: Forever**, not Retail/Classic Era. `Interface: 16001` is not proof of Blizzard API compatibility. Keep gameplay code and tests compatible with **Lua 5.1**; no runtime addon dependencies.
- Goal: immersive exploration, **not a quest solver or GPS**. Preserve geographical maps, quest journal/text, actual quest progression, quest-giver exclamation marks, normal NPC interactions and voiceover addons. Do not introduce an external quest database or route planner.
- Preserve the five quest-related controls (map/navigation hints, objective tracker, tooltip lines, quest/special NPC floating names, yellow progress popups) and per-character vendor-price preferences. Merged PR #18 has six checkboxes; pending PR #20 splits price hiding into two independent contexts and adds two quest-title presentation controls, making nine. Do not confuse that pending design with the current main/released behavior or reset saved choices on upgrade.
- Preserve the per-character `enabled` SavedVariable as **hide map hints**, and `revealedQuests` as the quest-ID allowlist. Revealing an individual quest uses original Blizzard blobs, map POIs, journal/tracker badges and SuperTrack where supported, without globally showing all hints, adding the quest to the watch list, or opening the map from context menus.
- Restore **original personal CVar values**, not presumed default `1` values. Keep account-shared CVar baselines across characters, preserve backups when restoration fails, and never change unrelated NPC-name CVars.
- Release behavior differs: stable **v1.3.0** retains map-only `/nqh on|off`; the **unreleased v1.4.0 code now on `main`** retires them and uses `/nqh` (native Settings), `/nqh restore` (all applicable hiding controls off + personal CVar restore), and `/nqh status` (diagnostics). Verify target branch before changing commands.

## Native UI and onboarding (v1.4.0 work)

- Put short checkbox labels **directly** in Blizzard **Options → AddOns → No Quest Hints**, with hover descriptions. The approved PR #20 layout is seven rows under **Quest hints** and two equal-rank rows under **Item prices**: **Hide outside trading** and **Hide at auction**. Both mean hiding, use the same normal font/indent, and remain editable independently. Do not restore the discarded dependent **Show at auction** child or the old **Additional immersion** heading. `/nqh` opens this category.
- The three first-run modes are **As in Blizzard** (no restrictions), **Immersion** (five quest restrictions), and **Full immersion** (original quest restrictions plus hidden numeric quest levels and prices outside trading). Selecting a card only previews a choice; **Begin adventure** applies it. Closing, Later, or Customize does not apply a preset. Keep old characters' preferences, and persist incomplete onboarding correctly across `/reload`.
- Keep card descriptions short and prose-only: the middle card mentions quest guidance without a feature list or price commentary; the right adds price hiding outside trading. No pricing-table/tier feature comparison. Full immersion enables numeric-level hiding only; difficulty-color hiding stays OFF in every preset and is manual-only. Other presets leave both new presentation controls OFF. In PR #20 all presets leave auction hiding OFF, as explicitly chosen by the owner; strict auction hiding is a separate manual choice.
- Prefer native Forever card art, authored atlas dimensions, masked round icons and native button textures; do not stretch small buttons into large ones or draw duplicate fallback borders. Keep the Selected label inset inside the card above the lower border. Use the genuine large gold/red three-slice button and two smaller native buttons aligned below its edges. The chooser must block background hover/click/wheel input, dismiss stale tooltips and release its input blocker on every exit path. No global tooltip hooks or perpetual `OnUpdate` workarounds.
- The explicit restore action preserves revealed quest permissions and failed CVar backups. Normal logout may attempt CVar cleanup without forgetting the selected playstyle. Do not claim cleanup after crash/force quit or once the addon is unloaded; verify sensitive behavior in the actual Forever client.

## Approved price-context behavior (pending PR #20)

- Merchants always show the native NPC vendor sell value. Outside merchant/auction UI use only `hideSellPrices`; at an open `AuctionHouseFrame` or legacy `AuctionFrame` use only `hideAuctionSellPrices`. These are not auction-market estimates, cost prices or listing fees. Treat unloaded frames as closed; prefer `IsVisible` over `IsShown`.
- Both price controls default OFF. Full immersion sets outside-trading hiding ON and auction hiding OFF; the other presets set both OFF. Presets deliberately reapply all nine checkboxes, ordinary `/reload` preserves manual choices, and restore/native defaults turn both OFF.
- Migrate the earlier preview's inverse/dependent `showAuctionSellPrices` to effective auction hiding (`old hideSellPrices == true AND old showAuctionSellPrices == false`), then remove the old field. Retain explicit new-format `hideAuctionSellPrices`; perform migration after detecting first-run data.
- Keep the current native-tooltip pre-call filter and non-item isolation. Re-evaluate on the next tooltip composition/hover; do not add global tooltip redraw hooks or polling. Preserve prices drawn independently by other addons.

## Tracker and quest-title presentation follow-ups (pending PR #20)

- A transparent parent does not disable descendant hover. Suppress tracker root and descendants' click/motion/wheel outside combat, preserving each exact original flag. Handle new pooled headers after native updates, restore detached/reparented children and retry failed/blocked restoration after combat. Dismiss only a tooltip owned by the hidden subtree; do not globally suppress GameTooltip or place a world-input-blocking overlay over the tracker.
- Add independent `hideQuestLevels` and `hideQuestDifficulty` preferences. Target known native journal and tracker title regions only; keep real quest data, party-member counts, title-internal numbers and unrelated UI intact. Forever's native title-prefix override ignores the level CVar; a CVar-only fix is insufficient.
- Journal XML can bind original enter/leave functions before global-name hooks are installed. Append deferred handlers to actual pooled row scripts once per frame; test captured script references and late-acquired rows, not only direct calls to global functions.
- Use deferred post-hooks and per-quest reversible text/color snapshots. Do not replace Blizzard return-value functions or hook all FontString setters. Honor pooled row reuse and combat deferral. Difficulty hiding means ordinary yellow title text; it does not recolor quest objectives or NPC/item text.
- Full immersion enables numeric-level hiding but not difficulty-color hiding. All other presets leave both OFF. Existing users get no new restriction until they explicitly toggle it or reselect the preset.

## Architecture, tests and packaging

- `Localization.lua` loads first; `NoQuestHintsForever.lua` owns state/effects; `Options.lua` owns settings UI. `Onboarding.lua` was introduced in unreleased v1.4.0 code by PR #18. Selective map/inline guidance is in `QuestHints.lua`, `QuestMarkers.lua`, `QuestInlineHints.lua`; quest title filters in `QuestPresentation.lua`; other filters in `QuestTooltips.lua`, `SellPrices.lua`, `QuestProgressMessages.lua`.
- Account for late Blizzard UI initialization, combat lockdown, `/reload`, native settings changes and competing addons. Avoid invasive protected-frame hooks or silently removing working features to cover up unproven taint.
- Run **`bash scripts/run_ci.sh`** from repo root (Python 3, `lua5.1`, `luac5.1`). It finds `tests/test_*.lua`, validates Lua syntax and checks TOC/package integrity. Add a focused regression test for a confirmed behavior fix.
- Use **`scripts/package_addon.py`** for installable ZIPs; the `.toc` plus LICENSE defines files. Keep new runtime modules in the `.toc` and internal docs out of CurseForge packages via `.pkgmeta`. Mock tests cannot prove visual correctness or freedom from protected-action taint.
- For PR/manual previews, give the owner a direct link to **one usable ZIP** with `NoQuestHintsForever/` immediately inside. GitHub's artifact is already a ZIP; avoid a ZIP inside a ZIP. Tagged releases may use their separate canonical packaged ZIP.

## GitHub, reviews and releases

- Branch + PR for every change to protected `main`; **Squash and merge only**. Never directly commit, force-push or bypass protections on `main`; do not merge PRs waiting for explicit owner playtesting.
- Verify the latest PR head passes **`build`**, and independently verify branch protection really **requires** that check. CI passing and CI being mandatory are different facts.
- Keep unrelated changes out of PRs. Do not create tags, bump versions, publish, or change `.github/release-request.txt` without a release request. Use existing `publish.yml` and CurseForge webhook; do not add another uploader or credentials.
- Release only after green final-code CI and a real Forever smoke test. Update `CHANGELOG.md` and `CURSEFORGE_DESCRIPTION.md` for user-facing changes; include refreshed short/full CurseForge listing text in the release handoff. GitHub Release success does not establish CurseForge publication.

## Unresolved protected-action error

- [Issue #3 — `ADDON_ACTION_BLOCKED`](https://github.com/nick-sidorin/no-quest-hints-forever/issues/3) remains open. The map/journal is involved in reports, but no specific hook is proven guilty. Collect the action before the warning, combat status and `taint.log`; avoid broad changes based only on guesses. Do not close because mock tests passed.

## Keeping context usable

- When parallel PRs touch these files, reconcile both branches before merging. Keep the English contributor rules and latest approved decisions; a gameplay PR must not reintroduce obsolete Russian documentation or the rejected price hierarchy.
- `PROJECT_CONTEXT.md` records product rationale, decisions, caveats and a clearly dated handoff—not an ever-growing task transcript. Before a new session, verify open PRs, releases, branch rules and CI. Keep stable 1.3.0 distinct from the 1.4.0 preview until a new stable release actually ships.
