# AGENTS.md — No Quest Hints Forever

Repository-wide instructions for contributors and coding agents. Before substantive work, read [README.md](README.md), [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md), and relevant Issues/PRs. Treat source code and live GitHub state as authoritative over dated context.

## Communication and documentation

- **English is the repository language**: documentation, code comments, commits, PR titles and descriptions, changelogs, and agent-authored issue updates. Exceptions are actual localized in-game strings, locale test fixtures, verbatim diagnostics and other content whose original language matters. UI strings must cover **all official client locales** (`enUS`, `enGB`, `ruRU`, `deDE`, `frFR`, `esES`, `esMX`, `itIT`, `ptBR`, `koKR`, `zhCN`, `zhTW`), with English fallback. English and Spanish client variants share their respective translations.
- Communicate with the owner in **Russian** in chat. Be concise and collaborative; summarize changes, verified checks, limitations, and what needs the owner's in-game feedback. Avoid needless explanations or ceremonial comments.
- Preserve durable decisions here or in `PROJECT_CONTEXT.md`, bugs and reproduction evidence in Issues, and change rationale in PRs. Refresh dated context for meaningful handoffs, not after every commit. Never copy private chats, personal data, tokens, or unsupported guesses into this repository.

## Product and safety invariants

- Target **World of Warcraft: Forever**, not Retail/Classic Era. `Interface: 16001` is not proof of Blizzard API compatibility. Keep gameplay code and tests compatible with **Lua 5.1**; no runtime addon dependencies.
- Goal: immersive exploration, **not a quest solver or GPS**. Preserve geographical maps, quest journal/text, actual quest progression, quest-giver exclamation marks, normal NPC interactions and voiceover addons. Do not introduce an external quest database or route planner.
- Preserve the five quest-related controls (map/navigation hints, objective tracker, tooltip lines, quest/special NPC floating names, yellow progress popups) and per-character vendor-price preferences. Merged PR #20 splits price hiding into two independent contexts and adds two quest-title controls, making nine on main. The bag-border follow-up adds a tenth manual-only control. v1.3.0 is historical; never reset saved choices on upgrade.
- Preserve the per-character `enabled` SavedVariable as **hide map hints**, and `revealedQuests` as the quest-ID allowlist. Revealing an individual quest uses original Blizzard blobs, map POIs, journal/tracker badges and SuperTrack where supported, without globally showing all hints, adding the quest to the watch list, or opening the map from context menus.
- Restore **original personal CVar values**, not presumed default `1` values. Keep account-shared CVar baselines across characters, preserve backups when restoration fails, and never change unrelated NPC-name CVars.
- Historical **v1.3.0** retained map-only `/nqh on|off`; **v1.4.0** retires them and uses `/nqh` (native Settings), `/nqh welcome` (playstyle chooser), `/nqh restore` (all applicable hiding controls off + personal CVar restore), and `/nqh status` (diagnostics). Verify target branch before changing commands.

## Native UI and onboarding (v1.4.0 work)

- Put short checkbox labels **directly** in Blizzard **Options → AddOns → No Quest Hints**, with hover descriptions. The merged PR #20 layout is seven rows under **Quest hints** and two equal-rank rows under **Item prices**: **Hide outside trading** and **Hide at auction**. Both mean hiding, use the same normal font/indent, and remain editable independently. Do not restore the discarded dependent **Show at auction** child or the old **Additional immersion** heading. `/nqh` opens this category.
- The three first-run modes are **As in Blizzard** (no restrictions), **Immersion** (five quest restrictions), and **Full immersion** (original quest restrictions plus hidden numeric quest levels and prices outside trading). Selecting a card only previews a choice; **Begin adventure** applies it. Closing, Later, or Customize does not apply a preset. Keep old characters' preferences, and persist incomplete onboarding correctly across `/reload`.
- Keep card descriptions short and prose-only: the middle card mentions quest guidance without a feature list or price commentary; the right adds price hiding outside trading. No pricing-table/tier feature comparison. Full immersion enables numeric-level hiding only; difficulty-color hiding stays OFF in every preset and is manual-only. Other presets leave both new presentation controls OFF. All presets leave auction hiding OFF, as explicitly chosen by the owner; strict auction hiding is a separate manual choice.
- Prefer native Forever card art, authored atlas dimensions, masked round icons and native button textures; do not stretch small buttons into large ones or draw duplicate fallback borders. Keep the Selected label inset inside the card above the lower border. Use the genuine large gold/red three-slice button and two smaller native buttons aligned below its edges. The chooser must block background hover/click/wheel input, dismiss stale tooltips and release its input blocker on every exit path. No global tooltip hooks or perpetual `OnUpdate` workarounds.
- The explicit restore action preserves revealed quest permissions and failed CVar backups. Normal logout may attempt CVar cleanup without forgetting the selected playstyle. Do not claim cleanup after crash/force quit or once the addon is unloaded; verify sensitive behavior in the actual Forever client.

## Approved price-context behavior (merged PR #20)

- Merchants always show the native NPC vendor sell value. Outside merchant/auction UI use only `hideSellPrices`; at an open `AuctionHouseFrame` or legacy `AuctionFrame` use only `hideAuctionSellPrices`. These are not auction-market estimates, cost prices or listing fees. Treat unloaded frames as closed; prefer `IsVisible` over `IsShown`.
- Both price controls default OFF. Full immersion sets outside-trading hiding ON and auction hiding OFF; the other presets set both OFF. Presets deliberately reapply all ten checkboxes, ordinary `/reload` preserves manual choices, and restore/native defaults turn both OFF.
- Migrate the earlier preview's inverse/dependent `showAuctionSellPrices` to effective auction hiding (`old hideSellPrices == true AND old showAuctionSellPrices == false`), then remove the old field. Retain explicit new-format `hideAuctionSellPrices`; perform migration after detecting first-run data.
- Keep the current native-tooltip pre-call filter and non-item isolation. Re-evaluate on the next tooltip composition/hover; do not add global tooltip redraw hooks or polling. Preserve prices drawn independently by other addons.

## Tracker and quest-title presentation follow-ups (merged PR #20)

- A transparent parent does not disable descendant hover. Suppress tracker root and descendants' click/motion/wheel outside combat, preserving each exact original flag. Handle new pooled headers after native updates, restore detached/reparented children and retry failed/blocked restoration after combat. Dismiss only a tooltip owned by the hidden subtree; do not globally suppress GameTooltip or place a world-input-blocking overlay over the tracker.
- Add independent `hideQuestLevels` and `hideQuestDifficulty` preferences. Target known native journal and tracker title regions only; keep real quest data, party-member counts, title-internal numbers and unrelated UI intact. Forever's native title-prefix override ignores the level CVar; a CVar-only fix is insufficient.
- Journal XML can bind original enter/leave functions before global-name hooks are installed. Append deferred handlers to actual pooled row scripts once per frame; test captured script references and late-acquired rows, not only direct calls to global functions.
- Use deferred post-hooks and per-quest reversible text/color snapshots. Do not replace Blizzard return-value functions or hook all FontString setters. Honor pooled row reuse and combat deferral. Difficulty hiding means ordinary yellow title text; it does not recolor quest objectives or NPC/item text.
- Full immersion enables numeric-level hiding but not difficulty-color hiding. All other presets leave both OFF. Existing users get no new restriction until they explicitly toggle it or reselect the preset.

## Architecture, tests and packaging

- `Localization.lua` loads first, followed by `LocaleTranslations.lua` before any consumers; `NoQuestHintsForever.lua` owns state/effects; `Options.lua` owns settings UI. `Onboarding.lua` was introduced in v1.4.0 by PR #18. Selective map/inline guidance is in `QuestHints.lua`, `QuestMarkers.lua`, `QuestInlineHints.lua`; quest title filters in `QuestPresentation.lua`; other filters in `QuestTooltips.lua`, `SellPrices.lua`, `QuestProgressMessages.lua`.
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
- `PROJECT_CONTEXT.md` records product rationale, decisions, caveats and a clearly dated handoff—not an ever-growing task transcript. Before a new session, verify open PRs, releases, branch rules and CI. Verify tags/releases and publisher status before stating which version is published. The owner approved the final 1.4.0 preview and requested stable publication on 2026-11-07.

## Optional bag borders

- The owner approved PR #20 in Forever and explicitly requested its squash merge on 2026-11-07. New bag-border concealment is a **separate PR**, OFF in every preset, with an equal-rank checkbox in **Bags**. Restore/defaults turn it OFF; reload preserves manual choices.
- Target native carried-bag `IconQuestTexture` borders only. Preserve quest-start exclamation marks, quality/new-item overlays, native Show/Hide state and original alpha. Cover actual pooled button methods, new slots/late UI and combat-end restoration. Do not promise compatibility with custom bag overlays without verification.

- Keep **Playstyle and restoration** first in native Settings, with both existing buttons, above Quest hints, Item prices and Bags. The owner confirmed the bag preview works and explicitly chose to leave Baganator/custom bag highlighting under those addons' control; do not add compatibility hooks for them.

- Keep **Support → Report a problem** last in Settings. Use a native popup with a selected copyable repository URL and localized Issues instructions; no browser-launch promises, SavedVariable changes or report submission. `/nqh welcome` delegates to the existing combat-aware chooser without resetting preferences/onboarding.

- The Settings restore button must request explicit confirmation before changing flags/CVars. Cancel/Escape or missing popup APIs leaves the full configuration unchanged; the explicit `/nqh restore` command remains immediate.
- Forever quest pins assign OnMouseEnter to UpdateTooltip; periodic calls also dispatch MapCanvas.QuestPin.OnEnter and rebuild/scroll the journal. Disable only that periodic callback on NQH-owned pins; preserve native actual entry/leave, tooltip rendering on re-entry and clicks. Keep identical selective pins across repeated quest events; invalidate the snapshot for actual membership/position/style/selection/map changes and RemoveAllData. No global tooltip or registry overrides.

- Upgrade notices read actual TOC Version metadata after LOADING_SCREEN_DISABLED in the deferred post-load callback and keep the highest seen version in account.lastSeenVersion. Announce once per account for upgrades (including legacy installations without a baseline), not fresh installs, reloads/alts or downgrades. Do not reset gameplay preferences, onboarding completion or open Settings automatically. Unknown metadata must not update the baseline; keep ruRU/enUS strings. Test ZIPs with the same TOC version are not separate upgrades.

- Feature releases are explicitly listed in core featureReleases with their first shipping version and newly introduced checkbox IDs. Scan the entire `(lastSeenVersion, installedVersion]` interval; do not call a fix-only update a feature update or infer features from version numbering. Preserve pending account.newSettings until each actual native row is viewed. Override only addon initializers' IsNewTagShown/MarkSettingAsSeen hooks; never add IDs to Blizzard NewSettings/NewSettingsSeen or replace global feature predicates. On clients lacking those initializer hooks, retain working controls without custom fake badges.

## CurseForge description style

- Preserve the owner-approved feature-first structure: title/tagline, compact benefit-led feature bullets immediately at the top, then optional detailed sections for selective hints, playstyles, settings and compatibility. Update release facts without replacing the agreed marketing structure with a long introduction or leading playstyle section.
- Keep the prominent **Source Code & Bug Reports** link to the repository, the separate known-issue link and the closing Read the quest tagline. Do not silently drop or replace existing destination links. Keep the short description close to the live wording unless the owner requests a new positioning. Hand over copy-ready Markdown for manual CurseForge editing.

- Automatic onboarding must wait for LOADING_SCREEN_DISABLED and a deferred callback, never PLAYER_LOGIN. Track loading transitions so queued opens cannot escape a new loading screen, retry after combat only when loaded, and preserve Later/Customize dismissal for the session. Explicit pending=false/true bookkeeping is separate from visibility; test full login/reload, preserved custom preferences, loading/combat and repeated zone transitions.

- The shared post-load callback delivers upgrade chat before attempting the chooser. Do not advance account.lastSeenVersion while the loading screen is active or after logout has begun. Repeated zone/combat callbacks must not duplicate the notice.

- The approved onboarding composition has two existing header lines: localized Welcome to No Quest Hints in white, then the Read the quest slogan in gold. Below the cards use a static Choose your playstyle instruction; never replace it with selected-status text. Selection is communicated by the card glow/Selected label and enabled Begin adventure button. Russian chooser copy uses informal singular address (Читай задания. Исследуй мир. Найди свой путь.; Выбери свой стиль игры). Keep current font sizes, spacing and large gap above the cards. Custom circular art remains a separate design direction; the runtime still uses game icons.
