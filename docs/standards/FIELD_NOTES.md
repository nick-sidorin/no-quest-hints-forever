# Field notes — verified patterns and limits

Evidence snapshot: **2026-11-10**. These examples explain the rules; they are not code to paste into a different addon. The principal source project targets WoW: Forever. Recheck APIs for every supported client/build.

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
