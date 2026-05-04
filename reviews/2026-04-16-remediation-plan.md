# Second-Pass Remediation Plan

Tracks the 39 findings from [2026-04-16-second-pass-review.md](2026-04-16-second-pass-review.md), grouped by the priority tiers proposed in §3 of that review. Severity icons: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low.

Each item lists: finding ID, file(s), fix outline, and an acceptance check.

---

## P0 — Before Next Commit (build is broken right now)

- [x] **F-0 🔴 Fix wrong screen-folder import** ✅ Fixed & verified 2026-04-16
  - **File:** [`supply-closet/lib/config/routes.dart:8`](../supply-closet/lib/config/routes.dart#L8)
  - **Fix:** changed `import '../screens/ar/ar_finder_screen.dart';` → `import '../screens/find/ar_finder_screen.dart';`
  - **Verification:** `flutter analyze` reports 0 errors on routes.dart (only a cosmetic unused-import warning, unrelated to this fix). Verified with Flutter 3.41.7 stable.

- [x] **F-2 🔴 Fix `XpAwardResult` constructor mismatch** ✅ Fixed & verified 2026-04-16
  - **Files:** [`gamification_service.dart:521-524`](../supply-closet/lib/services/gamification_service.dart#L521-L524), [`gamification_service.dart:657-690`](../supply-closet/lib/services/gamification_service.dart#L657-L690)
  - **Fix:** added `XpAwardResult.fromServer({required int xp, required List<String> newBadges})` initializer-list constructor. Added `newBadges` field (default `[]`) to the default constructor — existing caller at line 477 still compiles. Replaced broken `XpAwardResult(...)` call in `awardXp` with `XpAwardResult.fromServer(xp: xpAwarded, newBadges: ...)`.
  - **Verification:** `flutter analyze` reports 0 errors on gamification_service.dart. No other call sites reference removed fields (grep confirmed).

- [x] **F-6 🟠 Add `version` to Firestore rule allow-lists** ✅ Fixed 2026-04-16
  - **File:** [`firestore.rules:43-49, 122-142`](../supply-closet/firebase/firestore.rules#L43-L142)
  - **Fix:** (1) added `'version'` to `tagFieldsOnly()` keys list. (2) added `'version'` to supply UPDATE `affectedKeys().hasOnly([...])`. (3) enforced `request.resource.data.version == 1` on CREATE. (4) enforced `request.resource.data.version == (resource.data.version == null ? 0 : resource.data.version) + 1` on UPDATE — the null-guard supports legacy docs written before `version` existed. Two clients racing on the same base version will both try to write `version: N+1`; Firestore transaction semantics ensure only one succeeds.
  - **Verification:** emulator test not run (not set up locally). Recommend running `firebase emulators:exec --only firestore "jest firestore.test.js"` before deploy. Client writes at `firestore_service.dart:117-127, 143` already produce conforming `version` values.

- [x] **F-14 🔵 Add missing composite index for `_verifyRecentTag`** ✅ Fixed 2026-04-16
  - **File:** [`firestore.indexes.json:28-35`](../supply-closet/firebase/firestore.indexes.json#L28-L35)
  - **Fix:** added composite index on `supplies` collection with `{taggedByUserIds: CONTAINS, lastConfirmed: DESC}`. `queryScope: "COLLECTION"` matches the call site in `functions/index.js:257-264` which queries a specific subcollection path (not a collection-group query).
  - **Verification:** JSON schema valid; still need `firebase deploy --only firestore:indexes` to provision in prod (indexes take a few minutes to build). Without this step the first `awardXp` call in prod will still return `FAILED_PRECONDITION` until the index finishes building.

### P0 collateral — uncovered by `flutter analyze` during P0 verification

These four pre-existing compile errors weren't in the original adversarial review because they were shadowed by F-0 and F-2. They blocked the build, so fixed as part of the P0 pass.

- [x] **F-40 🔴 `CardTheme` → `CardThemeData`** ✅ Fixed & verified 2026-04-16
  - **File:** [`supply-closet/lib/config/theme.dart:116`](../supply-closet/lib/config/theme.dart#L116)
  - **Fix:** Flutter 3.22+ renamed the type; changed `cardTheme: CardTheme(...)` → `cardTheme: CardThemeData(...)`.

- [x] **F-41 🔴 Missing `dart:ui` import for `PlatformDispatcher`** ✅ Fixed & verified 2026-04-16
  - **File:** [`supply-closet/lib/main.dart:1`](../supply-closet/lib/main.dart#L1)
  - **Fix:** added `import 'dart:ui';` so `PlatformDispatcher.instance.onError` (used for Crashlytics async-error hook from F-6.1 remediation) resolves.

- [x] **F-42 🔴 `XpBar` caller passes non-existent `level:` param** ✅ Fixed & verified 2026-04-16
  - **File:** [`supply-closet/lib/screens/profile/profile_screen.dart:49`](../supply-closet/lib/screens/profile/profile_screen.dart#L49)
  - **Fix:** removed `, level: level` from the `XpBar(...)` call. `XpBar` has `showLevel: true` by default and computes level internally from `currentXp`. (Partial resolution of F-27 duplicate level sources; full consolidation is still in P2.)

- [x] **F-43 🔴 Non-exhaustive switch on `GameAction`** ✅ Fixed & verified 2026-04-16
  - **File:** [`supply-closet/lib/services/gamification_service.dart:503-510`](../supply-closet/lib/services/gamification_service.dart#L503-L510)
  - **Fix:** added explicit case for `GameAction.completeChallenge || GameAction.earnBadge` that throws `ArgumentError('Action $action is server-driven; clients cannot award it')`. These two actions are awarded by server triggers, not the client `awardXp` callable.

**End-to-end verification:** `flutter analyze` on the project now reports **0 errors** (down from 6). Remaining 37 issues are 4 unused-import/field warnings and 33 `withOpacity` deprecation infos — all non-blocking.

---

## P1 — Before Deployment

- [ ] **F-5 🟠 Make facility-change cooldown unforgeable**
  - **Files:** [`firestore.rules:97-103`](../supply-closet/firebase/firestore.rules#L97-L103), [`auth_service.dart:119`](../supply-closet/lib/services/auth_service.dart#L119)
  - **Fix:** add `request.resource.data.lastFacilityChange == request.time` to the rule. Change client to write `FieldValue.serverTimestamp()` instead of `Timestamp.now()`.
  - **Accept:** emulator: update with fabricated future timestamp fails; a legitimate update writes `request.time`; second legitimate update within 30 days fails.

- [ ] **F-15 🟠 Pin supply CREATE fields**
  - **File:** [`firestore.rules:122-128`](../supply-closet/firebase/firestore.rules#L122)
  - **Fix:** enforce `confidence == 0.5` (or whatever the design's initial value is), `lastConfirmed == request.time`, and `taggedByUserIds.size() == 1 && taggedByUserIds[0] == request.auth.uid`.
  - **Accept:** emulator test — create with `confidence: 1.0` rejected; create with other-uid in `taggedByUserIds` rejected; legit create accepted.

- [ ] **F-3 🟠 Bound `notFoundReports` growth**
  - **File:** [`firestore.rules:132-138`](../supply-closet/firebase/firestore.rules#L132)
  - **Fix:** enforce `request.resource.data.notFoundReports.size() <= resource.data.notFoundReports.size() + 1` on UPDATE. Better: move the write into a Cloud Function that validates entry shape/size, and deny direct client writes to this field via rules.
  - **Accept:** emulator test — adding one report succeeds; adding 10 in one write fails; adding a report with a 10KB blob fails.

- [ ] **F-8 🟠 Enable Firebase App Check**
  - **Files:** [`functions/index.js:38`](../supply-closet/firebase/functions/index.js#L38), [`functions/index.js:148`](../supply-closet/firebase/functions/index.js#L148), client `main.dart`, Firebase console
  - **Fix:** add `enforceAppCheck: true` to both `onCall` options. On client, initialize `FirebaseAppCheck.instance.activate(androidProvider: PlayIntegrity, appleProvider: DeviceCheck)` in `main.dart` before any callable. Register the app with App Check in Firebase console.
  - **Accept:** curl call to `awardXp` with only an ID token returns `unauthenticated`; real app call succeeds.

- [ ] **F-9 🟠 Close XP-farming loophole**
  - **File:** [`functions/index.js:240-270`](../supply-closet/firebase/functions/index.js#L240) (`_verifyRecentTag`)
  - **Fix:** require `supplyId` in the callable payload (client already passes it). On the supply doc add `xpClaimedBy: [uid]` and reject the award if `uid in xpClaimedBy`. Alternative (cleaner): delete the callable-based XP award entirely; move XP grants into a Firestore `onWrite` trigger on the supply doc that runs exactly once per tag.
  - **Accept:** calling `awardXp` 10× with the same `supplyId` grants XP exactly once.

- [ ] **F-1 🟠 Make `lookupUdi` rate-limit transactional**
  - **File:** [`functions/index.js:44-60`](../supply-closet/firebase/functions/index.js#L44-L60)
  - **Fix:** wrap the read + write of `udiLookupTimestamps` in `db.runTransaction`, same pattern as `awardXp`.
  - **Accept:** 50 concurrent `lookupUdi` calls from one uid result in at most 30 succeeding (the window cap).

- [ ] **F-16 🟠 Resolve client-direct-write contradiction**
  - **Files:** [`firestore_service.dart:79-146`](../supply-closet/lib/services/firestore_service.dart#L79-L146), optionally new `functions/index.js` callable
  - **Fix:** pick one path and commit:
    - **Path A (preferred):** create `tagSupply` callable in Cloud Functions; have the function validate, write the supply, and return the XP. Client replaces its Firestore transaction with a `httpsCallable('tagSupply')` call.
    - **Path B:** keep client writes but ensure F-3, F-6, F-15 land fully so the client can't bypass.
  - **Accept:** documented in code comment which path was chosen; rules or function (whichever is authoritative) reject all attacks F-3/F-15 exercise.

- [ ] **F-19 🟠 Stop camera image stream before dispose**
  - **File:** [`tag_supply_screen.dart:300-317`](../supply-closet/lib/screens/tag/tag_supply_screen.dart#L300-L317)
  - **Fix:** in `dispose()`: `if (_camera?.value.isStreamingImages ?? false) { await _camera!.stopImageStream(); } await _camera?.dispose();`
  - **Accept:** rapidly open and back out of the tag screen 20× — no "CameraController was used after being disposed" exception in Crashlytics.

- [ ] **F-20 🟠 Either wire the barcode scanner or remove it**
  - **File:** [`tag_supply_screen.dart:302-309`](../supply-closet/lib/screens/tag/tag_supply_screen.dart#L302-L309)
  - **Fix:** call `await scanner.processImage(InputImage.fromCameraImage(...))` and populate the barcode field on successful decode. If barcode is deprioritized, remove `google_mlkit_barcode_scanning` from pubspec and the scanner allocation entirely.
  - **Accept:** scanning a supply with a UDI barcode auto-fills the barcode field; OR the dependency is gone.

---

## P2 — First Cleanup Sprint

- [ ] **F-17 🟠 Cancel `StreamSubscription`s in providers**
  - **Files:** [`auth_provider.dart:22`](../supply-closet/lib/providers/auth_provider.dart#L22), [`procedure_provider.dart:62`](../supply-closet/lib/providers/procedure_provider.dart#L62)
  - **Fix:** store `StreamSubscription` field; cancel before re-listening in `loadProcedures`; override `dispose()` in both providers to cancel.
  - **Accept:** navigating Procedures tab 10× doesn't increase Firestore listener count (check Firestore debug logs).

- [ ] **F-18 🟠 Replace `print` + empty catches with Crashlytics breadcrumbs**
  - **Files:** [`auth_service.dart:43`](../supply-closet/lib/services/auth_service.dart#L43), [`auth_provider.dart:42-46`](../supply-closet/lib/providers/auth_provider.dart#L42), [`procedure_provider.dart:52-59, 83-88`](../supply-closet/lib/providers/procedure_provider.dart#L52)
  - **Fix:** `print` → `debugPrint`. In every `catch (e, s)`, call `FirebaseCrashlytics.instance.recordError(e, s, reason: 'loadProcedures failed')`.
  - **Accept:** grep `print(` in `lib/` returns 0 hits; every catch has a `recordError` or rethrows.

- [ ] **F-21 🟠 Add loading / empty / error states**
  - **Files:** [`procedure_list_screen.dart:165-180`](../supply-closet/lib/screens/procedures/procedure_list_screen.dart#L165), [`leaderboard_screen.dart:96-138`](../supply-closet/lib/screens/leaderboard/leaderboard_screen.dart#L96-L138), [`ar_finder_screen.dart:58-74`](../supply-closet/lib/screens/find/ar_finder_screen.dart#L58-L74)
  - **Fix:** render a shared `ErrorState` widget on `snapshot.hasError`, `EmptyState` on no data, loading spinner with timeout. Add a retry button.
  - **Accept:** toggling airplane mode on the device shows an error state in all three screens, not an infinite spinner.

- [ ] **F-22 🟠 Enforce 48dp glove-friendly touch targets**
  - **Files:** [`procedure_detail_screen.dart:162-182`](../supply-closet/lib/screens/procedures/procedure_detail_screen.dart#L162), [`ar_finder_screen.dart:211-225`](../supply-closet/lib/screens/find/ar_finder_screen.dart#L211)
  - **Fix:** wrap interactive elements in `SizedBox(width: AppConstants.minTouchTarget, height: AppConstants.minTouchTarget, child: ...)` or use `InkResponse(radius: 24)`.
  - **Accept:** Flutter Inspector shows every tappable region ≥ 48×48 logical px on the checklist and AR screens.

- [ ] **F-23 🟠 Validate onboarding form + collision-safe facility IDs**
  - **File:** [`profile_screen.dart:162-214`](../supply-closet/lib/screens/profile/profile_screen.dart#L162-L214)
  - **Fix:** wrap dialog body in `Form`, use `TextFormField.validator` for required fields and min-length. Generate facility IDs server-side (callable `createOrJoinFacility`) that dedupes case-insensitively and rejects collisions. Or use a Firestore `facilities_by_name` index with `runTransaction` to check-and-insert.
  - **Accept:** two users typing "Mount Sinai" from different devices end up in the same `facilityId`; "Mt Sinai" vs "Mount Sinai" are flagged or presented as existing match.

- [ ] **F-26 🟡 Collapse duplicate badge catalogs**
  - **Files:** [`constants.dart:43-87`](../supply-closet/lib/config/constants.dart#L43-L87), [`gamification_service.dart:245-383`](../supply-closet/lib/services/gamification_service.dart#L245-L383), [`profile_screen.dart`](../supply-closet/lib/screens/profile/profile_screen.dart)
  - **Fix:** delete `BadgeDefinitions.badges`; make profile UI iterate `GamificationService.allBadges`. Migrate any profile-only fields (icon, color) into the service definition.
  - **Accept:** every badge earned via `GamificationService` renders on the profile grid.

- [ ] **F-27 🟡 Collapse duplicate level/title sources**
  - **Files:** [`user_profile.dart:94-101`](../supply-closet/lib/models/user_profile.dart#L94-L101), [`gamification_service.dart:26-56`](../supply-closet/lib/services/gamification_service.dart#L26-L56)
  - **Fix:** delete `UserProfile.rankTitle`; add `GamificationService.titleFromXp(int xp)` and use it everywhere titles are displayed.
  - **Accept:** grep shows only one level-threshold table in the codebase; profile and leaderboard show identical titles for the same user.

- [ ] **F-36 🟠 Reconcile AR claim with implementation**
  - **Files:** [`ar_finder_screen.dart`](../supply-closet/lib/screens/find/ar_finder_screen.dart), [`pubspec.yaml:30`](../supply-closet/pubspec.yaml#L30), [`prd.md`](../prd.md), [`tech-architecture.md`](../tech-architecture.md)
  - **Decision required:** product call, not engineering. Two options:
    - **Option A:** rename to "Supply Finder," present as 2D map; strip `ar_flutter_plugin`, remove AR language from PRD/marketing.
    - **Option B:** invest in a maintained AR stack (`arcore_flutter_plugin` + `arkit_plugin`, or ARCore Geospatial); implement surface detection, anchor placement, world-to-screen projection; populate real `SupplyLocation.x/y/z`.
  - **Fix (whichever):** update PRD + code together. The current state is both technical dead end (abandoned plugin) and marketing liability.
  - **Accept:** PRD and code agree on what "AR" means; user-visible flow matches.

- [ ] **F-37 🟠 Add a `test/` directory with gamification unit tests**
  - **Files:** new `test/gamification_service_test.dart`, new `test/user_profile_test.dart`
  - **Fix:** cover `levelFromXp` (boundaries), `streakMultiplier` (all 4 tiers), `currentEvent` (in/out of each seasonal window, year boundaries), `weeklyUnitChallenges` rotation, and every badge unlock predicate.
  - **Accept:** `flutter test` runs ≥ 30 assertions and passes.

- [ ] **F-39 🔵 Add CI that runs build + tests on every PR**
  - **File:** new `.github/workflows/ci.yml`
  - **Fix:** workflow with `flutter analyze`, `flutter test`, `flutter build apk --debug`, `cd firebase/functions && npm ci && npm test` (add a basic test file). Fail the PR on any non-zero exit.
  - **Accept:** a commit that breaks compilation (like F-0 or F-2) fails CI before merge.

---

## P3 — Backlog Polish

### Backend correctness

- [ ] **F-10 🟡 Move `_verifyRecentTag` out of `runTransaction`**
  - **File:** [`functions/index.js:193`](../supply-closet/firebase/functions/index.js#L193)
  - **Fix:** validate the tag (via `supplyId`, see F-9) *before* entering `db.runTransaction`, then pass the verified ref into the transaction and use `tx.get(supplyRef)`. Transactions can't run collection queries.

- [ ] **F-11 🔵 Store `xpAwardTimestamps` as Timestamps**
  - **Files:** [`functions/index.js:182, 222`](../supply-closet/firebase/functions/index.js#L182), [`user_profile.dart:62`](../supply-closet/lib/models/user_profile.dart#L62)
  - **Fix:** write `admin.firestore.Timestamp.fromMillis(now)` server-side, or make the client `fromFirestore` accept both `int` and `Timestamp`.

- [ ] **F-12 🔵 Monthly reset for `tagsThisMonth`**
  - **File:** [`functions/index.js`](../supply-closet/firebase/functions/index.js)
  - **Fix:** add a scheduled function on cron `0 0 1 * *` that batch-resets `tagsThisMonth` to 0 across all users. Or compute from a bounded query.

- [ ] **F-13 🔵 Fix `syncRecalls` date upper-bound**
  - **File:** [`functions/index.js:387`](../supply-closet/firebase/functions/index.js#L387)
  - **Fix:** replace literal `"NOW"` with `new Date().toISOString().slice(0,10).replace(/-/g, "")`.

- [ ] **F-7 🟡 Fix `deleteAccount` ordering**
  - **File:** [`auth_service.dart:131-140`](../supply-closet/lib/services/auth_service.dart#L131-L140)
  - **Fix:** delete auth first (reauth if `requires-recent-login`); on success delete Firestore; if auth delete fails, don't touch Firestore. Alternatively, set `deletedAt: serverTimestamp()` on the profile and run a cleanup cron that deletes after auth is gone.

- [ ] **F-4 🟡 Null-guard `userFacility()` on cold-start**
  - **File:** [`firestore.rules:22-24, 69`](../supply-closet/firebase/firestore.rules#L22-L24)
  - **Fix:** `allow read: if isAuthed() && (isOwner(userId) || (exists(/databases/$(database)/documents/users/$(request.auth.uid)) && userFacility() == resource.data.facilityId));` Consider moving `facilityId` into custom claims to eliminate the per-request `get`.

### Client polish

- [ ] **F-24 🟡 Drive level-up off server response, not local `profile.points`**
  - **File:** [`gamification_provider.dart:73-76`](../supply-closet/lib/providers/gamification_provider.dart#L73-L76)

- [ ] **F-25 🟡 Fix `XpBar` animation origin**
  - **File:** [`xp_bar.dart:42-48`](../supply-closet/lib/widgets/xp_bar.dart#L42-L48)
  - **Fix:** store the last-rendered XP in state; animate from there.

- [ ] **F-28 🟡 Notify on `DailyChallenge.currentProgress` increment**
  - **File:** [`gamification_provider.dart:111-120`](../supply-closet/lib/providers/gamification_provider.dart#L111-L120)

- [ ] **F-29 🟡 Scope `context.watch` to consumers**
  - **File:** [`procedure_list_screen.dart:37-39`](../supply-closet/lib/screens/procedures/procedure_list_screen.dart#L37)
  - **Fix:** replace root-level `watch` with `Consumer` / `Selector` around only the widgets that actually depend on each provider.

- [ ] **F-30 🟡 Use `cached_network_image` for avatars**
  - **Files:** [`leaderboard_screen.dart:351, 443`](../supply-closet/lib/screens/leaderboard/leaderboard_screen.dart#L351), [`profile_screen.dart:90`](../supply-closet/lib/screens/profile/profile_screen.dart#L90)

- [ ] **F-31 🟡 Cancel `Future.delayed` in `CelebrationOverlay`**
  - **File:** [`celebration_overlay.dart:64-68`](../supply-closet/lib/widgets/celebration_overlay.dart#L64-L68)

- [ ] **F-32 🔵 Dispose dialog `TextEditingController`s**
  - **File:** [`profile_screen.dart:162-214`](../supply-closet/lib/screens/profile/profile_screen.dart#L162-L214)

- [ ] **F-33 🔵 Remove hardcoded leaderboard placeholder data**
  - **File:** [`leaderboard_screen.dart:191-195`](../supply-closet/lib/screens/leaderboard/leaderboard_screen.dart#L191-L195)
  - **Fix:** either ship real data or hide the tab behind a feature flag.

- [ ] **F-34 🔵 Prune dead dependencies**
  - **File:** [`pubspec.yaml`](../supply-closet/pubspec.yaml)
  - **Fix:** remove `firebase_messaging`, `fl_chart`, `shimmer`, `lottie`, `json_annotation`, `json_serializable` unless they're about to be used. Re-add when a feature needs them.

- [ ] **F-35 🔵 Replace deprecated `withOpacity`**
  - **Fix:** global find/replace `.withOpacity(x)` → `.withValues(alpha: x)` across `lib/`.

- [ ] **F-38 🔵 Unit-test `_weekOfYear`**
  - **File:** [`gamification_provider.dart:141-145`](../supply-closet/lib/providers/gamification_provider.dart#L141-L145)
  - **Fix:** add boundary tests (Dec 31, Jan 1, leap years) as part of the F-37 test suite.

---

## Progress Summary

| Priority | Severity mix | Count | Complete | Remaining |
|---|---|---|---|---|
| P0 | 2× 🔴, 1× 🟠, 1× 🔵 | 4 | **4** | **0** |
| P0 collateral | 4× 🔴 (F-40..F-43) | 4 | **4** | **0** |
| P1 | 7× 🟠 + 2× 🟠 (client) | 9 | 0 | 9 |
| P2 | 7× 🟠, 2× 🟡, 1× 🔵 | 10 | 0 | 10 |
| P3 | 10× 🟡, 6× 🔵 | 16 | 0 | 16 |
| **Total** | **7× 🔴 · 13× 🟠 · 14× 🟡 · 9× 🔵** | **43** | **8** | **35** |

---

## Rollout Suggestion

1. **Hour 1–2:** P0 (F-0, F-2, F-6, F-14). Unblocks the build; no deploy without these.
2. **Day 1–3:** P1 security/integrity (F-5, F-15, F-3, F-8, F-9, F-1, F-16, F-19, F-20). Lands before any public/beta deploy.
3. **Week 1–2:** P2 (F-17, F-18, F-21, F-22, F-23, F-26, F-27, F-36, F-37, F-39). Hardens the app and adds a safety net so P0-class bugs can't reach main again.
4. **Ongoing:** P3 backlog, one or two items per sprint.

Re-run the adversarial review after P1 completes — the combination of App Check, tightened rules, and per-supply XP-claim tracking materially changes the threat model, and some P3 items may become obsolete.

*End of Remediation Plan*
