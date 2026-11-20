# Field notes — patterns, evidence and limits

Evidence snapshot: **2026-11-18**; individual findings are dated below. These examples explain the rules; they are not code to paste into a different addon. The principal source project targets WoW: Forever. Recheck APIs for every supported client/build.

## 1. Registered native templates may be forbidden

In Forever, `C_XMLUtil.GetTemplateInfo("GamepadSecureBaseDialogTemplate")` reported a registered template. An addon dialog inherited it to obtain native controller navigation. Real-client creation failed in mouse and Gamepad Beta modes:

```text
CreateFrame(): Cannot create a forbidden frame from a tainted context.
```

Automatic startup, a slash command and a settings button all appeared broken because they called the same failing constructor. A mock that accepted every template missed the regression. Restoring an ordinary `BackdropTemplate` dialog fixed opening; the owner verified the preview before the hotfix release.

**Reuse:** test “exists but forbidden,” not just “exists/missing.” Do not swallow the failure and claim controller support. Ordinary-frame controller navigation remains a separate unverified implementation, not something this kit supplies.

Evidence: [controller change #34](https://github.com/nick-sidorin/no-quest-hints-forever/pull/34), [verified correction #38](https://github.com/nick-sidorin/no-quest-hints-forever/pull/38), [hotfix 1.4.4](https://github.com/nick-sidorin/no-quest-hints-forever/releases/tag/v1.4.4). These references belong here, not in another addon's public copy.

## 2. The blocked action may be downstream of the real cause

A native waypoint's Shift-click clipboard operation was blocked after reload. Addon-generated native widgets had called helpers that populated shared Blizzard Lua caches; the journal later consumed that data along a path leading to the native waypoint. It was not sufficient to inspect only the final clipboard call. The correction avoided shared cache population and native journal rebuilding from addon execution, keeping addon-owned widgets isolated.

**Reuse:** inspect native helper side effects and the first relevant taint propagation, not just the final blocked function. An all-options-OFF reproduction and an active-feature reproduction can have different causes. Test both when the evidence points there. Deferred execution is not an untainting boundary.

Evidence: [lazy initialization #31](https://github.com/nick-sidorin/no-quest-hints-forever/pull/31), [shared-cache isolation #35](https://github.com/nick-sidorin/no-quest-hints-forever/pull/35). The owner verified their specific reproduction scenarios; this does not prove universal taint safety.

## 3. A bag-slot Lua error can masquerade as a gamepad problem

A native enumerator produced an index with a nil pooled item button during initialization. Indexing or hooking it caused a Lua error, even when the feature's effect was OFF. The error dialog entered native gamepad focus/binding code and was followed by repeated protected-action warnings. Skipping absent buttons fixed the confirmed error; the owner could no longer reproduce the reported map-close/movement warning with Gamepad Beta enabled and mouse/keyboard.

**Reuse:** model sparse/reused native objects; make disabled features inert and validate pooled references. Do not conclude that fixing one Lua error resolves every controller warning. Physical-controller input was not established by that test.

## 4. Native gamepad mode and a physical gamepad are different checks

The reported world-map problem occurred using either input device while Gamepad Beta was enabled. A mouse-only developer could reproduce the mode-specific native path without owning a controller. Separately, a context menu seemed broken with the mouse, but other native entries behaved the same way; the owner withdrew the addon-specific menu report and the experimental workaround was reverted.

**Reuse:** compare native baseline behavior before adding workarounds. Keep abandoned fixes out of the release. Document reduced functionality and exact validation scope. Do not label behavior intentional or an upstream bug without evidence.

## 5. Visibility does not mean input isolation

Dimming textures left action-bar tooltips visible over a modal. A transparent parent left child rows responding to hover. The solutions differed: a full-screen shield was appropriate for the modal, while suppressing/restoring the hidden subtree's input was appropriate for the hidden panel.

**Reuse:** scope the solution to ownership and intent. Do not install a full-screen shield to hide a small panel or disable global tooltips. Check every close path for leaked input blocking, and preserve original flags for reusable native frames.

## 6. World readiness is a state transition, not a fixed delay

A saved first-run state remained pending across restart, but no dialog appeared because startup tried to open it too early. Waiting for the loading screen to finish and deferring the open fixed the real-client case. A later refactor that broke dialog creation produced a similar visible symptom for a different reason.

**Reuse:** log persistence, scheduling and constructor errors separately. Model loading transitions, combat retries, queued callbacks and session dismissal. Do not add a longer arbitrary timer or repeatedly reset preferences as a substitute for identifying the failing stage.

## 7. Native visual art still needs authored geometry

Early cards had duplicate borders and stretched button art. Reusing authored atlas dimensions, circular masks, actual portrait rings and native large-button slices improved the result. Clear secondary buttons and one selection signal per purpose reduced ambiguity.

**Reuse:** use native artwork where available, but validate its size, loading context and permissions. A native-looking recreation with ordinary frames may be safer than inheriting a Glue or forbidden secure template. Do not transfer a specific card layout into every addon automatically.

## 8. Release delivery and listing copy are separate products

A GitHub Actions artifact already wraps files in a ZIP; uploading an installable ZIP as an artifact produced a confusing extra archive layer. Preview artifacts now contain the extracted addon folder. Tagged releases expose the canonical installable ZIP directly.

CurseForge's source packager has separate `.pkgmeta` behavior. Its output can lag GitHub publication. Full listing copy also needs manual editing unless an explicitly configured integration handles it; release automation alone does not update the description.

**Reuse:** validate each packaging route, verify publication separately and hand over copy-ready short/full Markdown with an editor link. Keep concise benefit bullets at the top and separate Issues from Source Code. Never promise that a GitHub release means CurseForge is already public.

## 9. Search for the native component before recreating its appearance

**Target/evidence:** WoW: Forever, matching `forever` UI source inspected 2026-11-12; exact owner client build is not recorded. Character/professions-style addon windows could reuse the ordinary `PortraitFrameTemplate` and right-side tab controls rather than assembling an approximate shell. Native templates still need their scripts, geometry and loading context inspected; section 1's forbidden-dialog finding remains applicable.

For achievement-style progress, the source already defines `AchievementProgressBarTemplate`: a short status bar, a translucent track, three border/shadow slices and a fill drawn below the border. A generic status bar with an unrelated border did not reproduce that depth. Inspecting the complete native component supplied the intended construction. Real-achievement templates can depend on actual Blizzard IDs or shared providers, so safe reuse may instead mean applying the authored artwork to an ordinary addon-owned StatusBar. Source geometry and mock checks alone do not establish the final rendering or taint behavior.

**Reuse:** start with documented APIs and existing components, then verify whether they can safely own the addon's data and lifecycle. Prefer direct permitted reuse. If that is unsuitable, document the reason and reuse the smallest safe native pieces before inventing a custom design. Record the source and validation boundary in the consuming project.

Source references: [Forever shared UI templates](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml), [Forever achievement components](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.xml), and [generated widget API documentation](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated). These are research references, not a guarantee of permission to instantiate every exported template.

## 10. A native layout refresh can taint unrelated gameplay UI

**Target/evidence:** WoW: Forever, reported 2026-11-11/12; exact client build was not recorded. Hiding the XP bar left space until Blizzard's next layout pass. An addon-triggered `EditModeManager.UpdateBottomActionBarPositions` notification made the space collapse immediately and initially passed owner testing. Later, ordinary ability use repeatedly raised secret-value errors in `ActionButton` cooldown updates; entering Edit Mode also raised `CompactUnitFrame` errors/protected-action warnings. A single native event dispatch was therefore not an acceptable layout API merely because it appeared to fix positioning.

The owner subsequently verified a candidate without the addon-originated layout dispatch, with hiding suspended during Edit Mode. The reported errors no longer reproduced. The remaining gap until native layout updates was explicitly accepted. A `ForceUpdateAction` probe did not fix spacing. Source research found other addons either accepting the same delayed layout or owning a replacement layout; neither establishes a safe generic refresh for the preserved native layout.

**Reuse:** inspect the complete callback chain and native state it writes, including frame visibility wrappers and anchor tables. Frequency and combat deferral do not remove taint. Do not replace a missing safe layout API with fake pet actions, gameplay toggles or hardcoded anchors. Test combat cooldowns and Edit Mode as distinct scenarios. This is evidence for the reported path, not a universal ban on layout APIs or proof of universal taint safety.

Evidence: [original HUD change #41](https://github.com/nick-sidorin/no-quest-hints-forever/pull/41), [fix candidate #43](https://github.com/nick-sidorin/no-quest-hints-forever/pull/43), [verified-runtime reintroduction #45](https://github.com/nick-sidorin/no-quest-hints-forever/pull/45). Matching source research used Gethe/wow-ui-source `forever` commit `4cd0ab752a77164f654ccbca9d0c1fe8dafceebe`.

## 11. Preserve the native timer instead of reconstructing its appearance and clock

**Target/evidence:** WoW: Forever, owner-tested 2026-11-11; exact client build was not recorded. A custom compact quest timer was rejected visually. Reusing the actual `QuestTimerFrame` preserved its native border, localized countdown, quest-title tooltip and click-to-open behavior. With the tracker transparent, supported ignore-parent-alpha behavior and a narrowly scoped input exemption kept only the timer usable. An addon-owned anchor/header drag handle changed placement without replacing its parent, native countdown, pools or button scripts. The owner confirmed the result worked and looked original.

Native timer lifecycle remains authoritative across reload; the addon does not save/restart its own countdown. During one quest offer, `C_QuestLog.GetTimeAllowed` yielded no pre-acceptance value even though the accepted quest was timed. That observation does not identify all timed quests or establish an API-wide absence. The full journal already contained Blizzard's own timer, so no duplicate annotation was needed.

**Reuse:** inspect the existing component and data owner before copying a renderer. Keep position persistence separate from authoritative gameplay time. Treat unavailable offer metadata as unknown and preserve existing journal content. Capability-check and restore scoped frame state; this example is not permission to call native update/layout routines from addon execution.

Evidence: [native-timer release 1.5.0](https://github.com/nick-sidorin/no-quest-hints-forever/releases/tag/v1.5.0); matching source at the commit in section 10, `Blizzard_QuestTimer` and generated quest API documentation.

## 12. A rollback is an update, not a moved tag

**Target/evidence:** WoW: Forever addon distribution, 2026-11-12. After the HUD regression, GitHub Actions had an outage and a candidate fix was not yet owner-verified. The emergency 1.6.1 update restored the known-good 1.5.0 runtime, with explicit version differences, rather than bundling the unverified candidate. Existing HUD preferences remained stored but inert. Making the GitHub 1.6.0 release a draft did not remove the already published CurseForge file; its tag remained fixed. A later owner-tested candidate was reintroduced as 1.7.0 with explicit feature-notice metadata.

**Reuse:** publish an authorized higher-version known-good package for update delivery, verify packaged bytes and preserve recovery/user choices. Distinguish candidate, tested fix and published result. Verify separate distributors independently; do not move an existing tag or equate withdrawal on one service with rollback everywhere. Do not open duplicate PRs or bypass checks solely because a runner is queued; inspect service/run status and keep the recovery procedure explicit.

Evidence: [rollback 1.6.1](https://github.com/nick-sidorin/no-quest-hints-forever/releases/tag/v1.6.1), [reintroduction 1.7.0](https://github.com/nick-sidorin/no-quest-hints-forever/releases/tag/v1.7.0), and #43/#45 above.

## 13. Temporary context exceptions need an effect boundary

**Target/evidence:** WoW: Forever source/API research and automated preview tests, 2026-11-17; **not yet owner-verified in an instance**. A proposed dungeon/raid exception initially included map/navigation suppression. The owner narrowed it to tooltip lines and NPC names, leaving map/navigation and manual per-quest permissions unchanged. Native `IsInInstance()` supplies both the inside flag and instance type; being in a raid group outdoors is not the same condition.

The preview keeps configured preferences separate from effective accessors. Native checkboxes retain the player's saved choices while selected effects are suspended. Tests cover party/raid vs other/unknown types, reload, combat/loading deferral, personal CVar baselines, failed restoration, manual edits, unchanged quest permissions and no policy-triggered pin refresh. This supports the state-management design, not a claim that native instance rendering or taint safety has been verified.

**Reuse:** specify an explicit participating-effect set. Context changes must not apply a preset, mutate saved flags or refresh unrelated UI. Preserve the player's actual original settings and manual changes. State which evidence is source inspection, automated behavior or actual client observation.

Evidence: [preview #46](https://github.com/nick-sidorin/no-quest-hints-forever/pull/46), head `20be6f617157e3f6e8384f3396785df750713b6c`; generated `InstanceDocumentation.lua` in the Forever UI source.

## 14. Atlas state, draw layers and content bounds are separate contracts

**Target/evidence:** Forever UI source, owner screenshots and mocked regressions, 2026-11-10–13; exact client build is not recorded. An achievement-style alert showed a magnified/cropped shield and displaced icon framing. The correction explicitly reset file-sheet UVs when selecting an atlas, retained authored artwork size and followed the native icon/shield subframes and draw layers. The owner approved the corrected alert artwork, while point centering remained under refinement. This validates that combined artwork correction in the supplied scenario, not every texture API or a single isolated cause.

A later screenshot still lacked card dates. The proposed fix owns the date FontString in the shield frame's OVERLAY but anchors it inside the card, independently of the image rectangle. A regression exercises an oversized atlas rectangle; **the owner has not confirmed the final date rendering**. Treat transparent padding/frame-layer interactions as debugging leads rather than declaring this specific cause proven. An opaque base with a translucent shade retains texture without exposing the world; an opaque color wash cannot substitute for that layering.

**Reuse:** explicitly reset UVs when changing texture representation, inspect authored size/layers and locate the content's intended bounds. Check text, visibility, parent levels and anchors before moving fonts by guessed pixel offsets. Mocks can check contracts and deliberately varied dimensions; they do not establish actual rasterization or optical alignment.

Evidence: [Azeroth Fitness UI research](https://github.com/nick-sidorin/azeroth-fitness/blob/19185608011bc829a62614e6cee581190161969e/docs/NATIVE_UI_RESEARCH.md), [artwork regressions](https://github.com/nick-sidorin/azeroth-fitness/blob/19185608011bc829a62614e6cee581190161969e/tests/test_achievement_art.lua), and the source references in section 9.

## 15. Independent displays need independent update lifetimes

**Target/evidence:** Forever source/API research and automated preview tests, 2026-11-12/13; **final rings/minimap rendering is not yet owner-verified**. A visible shortcut must continue reflecting activity while its dashboard is closed. Both views reuse one ring renderer, palette and proportional geometry. Activity, goal, reset and login notifications update the visible shortcut directly; hidden views skip rendering and catch up on show. Unchanged fractions do not write new texture state.

For addon-owned daily activity, one local-calendar next-midnight callback handles idle rollover. Hide/rebuild cancels it; a generation check rejects a stale callback that would otherwise replace a newer timer. This is the addon's reporting calendar, not permission to reconstruct authoritative gameplay timers from section 11. Tests cover closed-window updates, goal/reset/character changes, rollover with history preservation and cancellation. The documented native radial texture API/masks support the proposed renderer with an API-missing fallback; successful mocked calls do not prove the final arcs/caps in game.

**Reuse:** share state and rendering logic without coupling visibility or running a permanent timer for every view. Include configuration, resets and time boundaries in the notification contract. Make decorative child frames noninteractive so the owning button retains click/drag behavior. Check clock/calendar semantics appropriate to the data owner.

Evidence: [minimap implementation](https://github.com/nick-sidorin/azeroth-fitness/blob/19185608011bc829a62614e6cee581190161969e/Minimap.lua), [live-view regressions](https://github.com/nick-sidorin/azeroth-fitness/blob/19185608011bc829a62614e6cee581190161969e/tests/test_minimap_rings.lua), and [matching radial texture API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua).

## 16. A sorted row is not the identity of its data

**Target/evidence:** addon-owned achievement UI, automated tests dated 2026-11-11–13; **navigation/rendering still needs the preview's client check**. Earned-first sorting changes row positions. An alert click therefore resolves its current award ID after refreshing the list, scrolls that matching card into view and highlights it. Clicking one alert advances the remaining queue rather than clearing it. Ordinary refresh does not pull the user back after manual scrolling; a real reorder preserves the selected ID.

Progress getters and thresholds are shared by unlocking and presentation. Display counters floor fractional estimates instead of announcing the goal early. Visual fill clamps at completion while authoritative totals can exceed it; an earned streak award remains earned when the active streak expires. Reused cards reapply completed/unfinished visibility, text color and shadow, preventing stale appearance after reset. These are state-management examples, not a requirement that every addon use achievements or the same completed-card design.

**Reuse:** bind actions/selection to stable IDs, refresh derived presentation from the model and test reuse transitions. Do not infer completion from rounded labels, persist duplicate progress counters unnecessarily or let a queue callback capture an obsolete row.

Evidence: [progress and navigation regressions](https://github.com/nick-sidorin/azeroth-fitness/blob/19185608011bc829a62614e6cee581190161969e/tests/test_achievement_navigation.lua), plus the core/card modules at that revision.

## 17. A dependency download failure is not a project regression

**Target/evidence:** GitHub Actions logs and verified build attempts, 2026-11-11–13. An `ubuntu-latest` rollout selected Ubuntu 26.04; APT failed resolving `security.ubuntu.com` before project tests. A retry and a pinned Ubuntu 24.04 attempt did not establish a working install. A shared installer instead compiled the official Lua 5.1.5 archive after verifying a pinned SHA-256. Subsequent lua.org timeout/reset failures required a bounded transport retry and a BLFS/OSU mirror; the mirror bytes matched the same digest before adoption.

The fallback was tested with the primary host deliberately unavailable. Final exact-head CI ran the project gates and produced an archive verified against source. This does not establish that a particular Ubuntu release is generally broken, that another mirror is always reachable or that every addon must compile Lua. The appropriate installation/cache strategy depends on the project.

**Reuse:** identify the failed stage, keep the interpreter/version and integrity requirements fixed, and rerun real gates after recovery. Every accepted mirror must satisfy the same known digest before extraction or compilation. Fail on integrity errors; do not hide skipped tests behind a green installer or weaken transport verification to obtain a build.

Evidence: failed install runs [43058573073](https://github.com/nick-sidorin/azeroth-fitness/actions/runs/43058573073) and [43091066544](https://github.com/nick-sidorin/azeroth-fitness/actions/runs/43091066544), successful [final preview 43419587773](https://github.com/nick-sidorin/azeroth-fitness/actions/runs/43419587773), and its [pinned-source installer](https://github.com/nick-sidorin/azeroth-fitness/blob/19185608011bc829a62614e6cee581190161969e/scripts/install_lua51.sh).
