# SupplyCloset — Second-Pass Review

**Reviewer:** Claude Opus 4.7 (1M context), independent audit
**Date:** 2026-04-16
**Scope:** (a) verify the 21 remediations in [../remediation-plan.md](../remediation-plan.md) actually landed and are correct; (b) find new issues the prior [adversarial review](../adversarial-review.md) missed.
**Severity:** 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low

---

## Executive Summary

The remediation pass closed the obvious low-complexity items well (Crashlytics, `healthCheck` removal, role validation, decay-function scale, retention, analytics). But several medium-complexity items were implemented half-way, and **the app does not currently compile** — strong evidence that no one has run the client build since the last round of fixes.

**Headline numbers:**

| Severity | Count |
|---|---|
| 🔴 Critical | 3 |
| 🟠 High | 13 |
| 🟡 Medium | 14 |
| 🔵 Low | 9 |
| **Total new/unresolved** | **39** |

**Top 5 fires to put out first:**

1. 🔴 **Client doesn't build.** Two independent compile errors — a wrong import path in [`routes.dart:8`](../supply-closet/lib/config/routes.dart#L8) and a mismatched `XpAwardResult` constructor in [`gamification_service.dart:523-528`](../supply-closet/lib/services/gamification_service.dart#L523-L528). Either is a hard stop.
2. 🟠 **XP farming loophole remains.** `_verifyRecentTag` validates "did this user tag *any* supply in the last 60s," not *this* supply — one real tag can mint 10 awards under the 10/min rate limit. Compounded by missing Firebase App Check.
3. 🟠 **Facility-hop cooldown is forgeable.** Rule compares a client-supplied `lastFacilityChange` timestamp against itself; nothing forces it to equal `request.time`. The 30-day cooldown is cosmetic as written.
4. 🟠 **Confirm-tag writes will fail in production.** The client writes a `version` field, but Firestore rules omit `version` from the allowed-keys list on both create and update. Every confirm-existing flow will `PERMISSION_DENIED`.
5. 🟠 **Supply CREATE rule is too permissive.** Any authed user can set `confidence: 1.0`, backdate `lastConfirmed`, or include other users in `taggedByUserIds` on creation — bypassing decay and griefing badge paths.

---

## 1. Verification of the 21 Remediations

Read bottom-up: "Verified" = fix landed and is correct. "Partial" = implemented but has a gap. "Broken" = introduces a new bug. "Not Done" = claim does not match code.

| ID | Claim (from remediation-plan.md) | Status | Evidence |
|----|---|---|---|
| 1.1 | `role == 'nurse'` on profile create | ✅ Verified | [`firestore.rules:76`](../supply-closet/firebase/firestore.rules#L76) also enforces zero gamification fields and empty badges. |
| 2.1 | Server-side XP verification + rate limit | ⚠️ Partial | Rate limit exists, but `_verifyRecentTag` hard-codes `supplyRooms/doc("main")` ([`functions/index.js:245, 260`](../supply-closet/firebase/functions/index.js#L245)) — kills multi-room. Also the client still writes supplies directly (claim says it calls Cloud Function — it doesn't). See F-9, F-16. |
| 1.2 | `healthCheck` removed | ✅ Verified | [`functions/index.js:473`](../supply-closet/firebase/functions/index.js#L473) has only a comment; no `onRequest` export. |
| 1.3 | Rate limit on callable functions | ⚠️ Partial | `awardXp` is transactional; `lookupUdi` rate-limit read+write is **outside** a transaction ([`functions/index.js:44-60`](../supply-closet/firebase/functions/index.js#L44-L60)) → TOCTOU bypass. See F-1. |
| 2.2 | Streak requires meaningful action | ✅ Verified | `lastTagAt` set only when `isTagAction` ([`functions/index.js:225-227, 278-286`](../supply-closet/firebase/functions/index.js#L225)). |
| 3.1 | Atomic confidence updates | ✅ Verified | `runTransaction` + `FieldValue.increment` in [`firestore_service.dart:105-128`](../supply-closet/lib/services/firestore_service.dart#L105-L128). |
| 3.2 | `decayConfidence` scales | ✅ Verified | `collectionGroup` + `startAfter` batching of 400 ([`functions/index.js:329-374`](../supply-closet/firebase/functions/index.js#L329)). |
| 4.1 | Same-facility profile reads | ✅ Verified | [`firestore.rules:67-70`](../supply-closet/firebase/firestore.rules#L67). Minor cold-start caveat in F-4. |
| 5.1 | Remove hard-coded `roomId = 'main'` | ⚠️ Partial | Constant defined and used in two places, but [`ar_finder_screen.dart:299`](../supply-closet/lib/screens/find/ar_finder_screen.dart#L299) still passes `roomId: 'main'` literally; server also hard-codes "main". |
| 6.1 | Firebase Crashlytics | ✅ Verified | [`main.dart:17-23`](../supply-closet/lib/main.dart#L17); both Flutter and async handlers registered. (But no individual catches call `recordError` — see F-18.) |
| 1.4 | Supply name + barcode validation | ⚠️ Partial | Defined and wired into CREATE ([`rules:125-126`](../supply-closet/firebase/firestore.rules#L125)) but **not** UPDATE ([`rules:132-138`](../supply-closet/firebase/firestore.rules#L132)). `notFoundReports` is unbounded-appendable. See F-3. |
| 1.5 | Remove client-side XP prediction | 🔴 Broken | Client constructor [`gamification_service.dart:523-528`](../supply-closet/lib/services/gamification_service.dart#L523-L528) passes `streakMultiplier:` and `newBadges:` — neither exist on [`XpAwardResult` class at lines 659-677](../supply-closet/lib/services/gamification_service.dart#L659-L677). **Compile error.** See F-2. |
| 2.3 | 30-day facility cooldown | 🔴 Broken | [`rules:96-103`](../supply-closet/firebase/firestore.rules#L96-L103) compares `request.resource.data.lastFacilityChange` against itself; no constraint to `request.time`. Client can set any value and pass. See F-5. |
| 4.2 | Camera docs in SETUP.md | ✅ Verified | Doc-only; no code change claimed. |
| 5.2 | Offline conflict / version field | 🔴 Broken | `version` incremented in [`firestore_service.dart:126`](../supply-closet/lib/services/firestore_service.dart#L126) but absent from `tagFieldsOnly()` ([`rules:43-49`](../supply-closet/firebase/firestore.rules#L43)) and update `hasOnly` ([`rules:134-138`](../supply-closet/firebase/firestore.rules#L134)). Every confirm-existing write fails `PERMISSION_DENIED` in production. See F-6. |
| 6.2 | Forced update via Remote Config | ⚠️ Not Done | [`main.dart:42-66`](../supply-closet/lib/main.dart#L42) fetches `min_app_version` and **only `debugPrint`s** on mismatch — no blocking UI. The comment on line 59 acknowledges this. Not functional. |
| 3.3 | Retention / account deletion | ✅ Verified | `deleteAccount()` present; `cleanupStaleSupplies` cron present. Unsafe ordering — see F-7. |
| 4.3 | Remove email from profile | ⚠️ Partial | `toFirestore()` no longer writes email, but `fromFirestore` still reads it and update rule still lists `'email'` as allowed. Stale emails remain readable to same-facility users. |
| 5.3 | Provider DI | ✅ Verified | Optional service params in both providers. |
| 6.3 | Analytics events | ✅ Verified | `logLogin`, `supply_tagged` events present. |

**Verification totals:** 10/21 Verified · 6/21 Partial · 3/21 Broken · 2/21 Not Done.

---

## 2. New Findings (not in the prior review)

### Client — compile and runtime

- **F-0 🔴 Wrong screen-folder import path.** [`routes.dart:8`](../supply-closet/lib/config/routes.dart#L8) imports `../screens/ar/ar_finder_screen.dart`, but the file is at `../screens/find/ar_finder_screen.dart`. App does not compile. **Fix:** rename import to `../screens/find/...`.
- **F-2 🔴 `XpAwardResult` constructor mismatch.** [`gamification_service.dart:523-528`](../supply-closet/lib/services/gamification_service.dart#L523-L528) calls `XpAwardResult(baseXp:, streakMultiplier: 1.0, totalXp:, newBadges:)` but the class ([lines 659-677](../supply-closet/lib/services/gamification_service.dart#L659-L677)) requires `bonusXp`, `streakBonus`, `multiplier`, `bonusReasons` — and has no `streakMultiplier` or `newBadges` fields. Compile error. **Fix:** add a `XpAwardResult.fromServer({int xp, List<String> newBadges})` named constructor and use that, or supply all required fields.

### Backend — security

- **F-1 🟠 `lookupUdi` rate-limit TOCTOU.** Read and write on `udiLookupTimestamps` happen outside a transaction ([`functions/index.js:44-60`](../supply-closet/firebase/functions/index.js#L44-L60)). 30 concurrent calls from one uid all pass the check. **Fix:** wrap in `db.runTransaction`, same shape as `awardXp`.
- **F-5 🟠 Facility-change cooldown forgeable.** [`rules:97-103`](../supply-closet/firebase/firestore.rules#L97) has no constraint that `lastFacilityChange == request.time`. Client sets `Timestamp.now()` in [`auth_service.dart:119`](../supply-closet/lib/services/auth_service.dart#L119). Malicious client sends a future timestamp to pass. **Fix:** require `request.resource.data.lastFacilityChange == request.time` and switch the client to `FieldValue.serverTimestamp()`.
- **F-8 🟠 No Firebase App Check.** Neither `awardXp` nor `lookupUdi` specify `enforceAppCheck: true` ([`functions/index.js:38, 148`](../supply-closet/firebase/functions/index.js#L38)). Any stolen ID token calls them from curl. **Fix:** enforce App Check + Play Integrity / DeviceCheck.
- **F-9 🟠 XP farming via 60s any-tag window.** `_verifyRecentTag` checks "this user tagged any supply in the last 60s" — not the specific supply. One legit tag unlocks 10 XP awards per minute under the existing rate cap. **Fix:** pass `supplyId` and record `xpClaimedBy: [uid]` on the supply doc, or drive XP from a Firestore `onSupplyTagged` trigger instead of a client-callable.
- **F-15 🟡 Supply CREATE rule too permissive.** Create rule only checks `tagCount == 1` and `auth.uid in taggedByUserIds` ([`rules:122-128`](../supply-closet/firebase/firestore.rules#L122)). Client can set `confidence: 1.0`, backdate `lastConfirmed`, or credit other uids. **Fix:** pin `confidence == 0.5`, `lastConfirmed == request.time`, and `taggedByUserIds == [auth.uid]`.
- **F-3 🟠 `notFoundReports` unbounded growth on UPDATE.** Update rule allows `notFoundReports` via `arrayUnion` with no size cap. Attacker balloons docs to 1MB. **Fix:** enforce `notFoundReports.size() <= resource.data.notFoundReports.size() + 1` and move write to a Cloud Function with element-size validation.
- **F-6 🟠 `version` field rejected by Firestore rules.** Confirm-tag writes `version` but neither `tagFieldsOnly()` nor the update `hasOnly` list includes it. Every confirm-existing fails `PERMISSION_DENIED`. **Fix:** add `'version'` to both allow-lists; enforce `request.resource.data.version == resource.data.version + 1`.
- **F-16 🟠 Client still writes supplies directly, contradicting plan claim.** Remediation 2.1 says "Client now calls Cloud Function instead of direct Firestore write." But [`firestore_service.dart:79-146`](../supply-closet/lib/services/firestore_service.dart#L79) still writes to `/facilities/.../supplies` via the client SDK. **Fix:** either migrate tag writes to a callable Cloud Function, or tighten rules per F-3, F-6, F-15.

### Backend — correctness & reliability

- **F-10 🟡 Firestore query inside `runTransaction`.** `_verifyRecentTag` calls `db.collection(...).get()` (not `tx.get()`) from inside `awardXp`'s transaction ([`functions/index.js:193`](../supply-closet/firebase/functions/index.js#L193)). Firestore transactions can't run collection queries; this escapes transactional consistency. **Fix:** compute verification outside the transaction, pass the pre-validated `supplyId` in, then use `tx.get(supplyRef)`.
- **F-11 🔵 `xpAwardTimestamps` stored as raw millis.** Server pushes `Date.now()` ints ([`functions/index.js:182, 222`](../supply-closet/firebase/functions/index.js#L182)) while `UserProfile.fromFirestore` parses each entry as `Timestamp` ([`user_profile.dart:62`](../supply-closet/lib/models/user_profile.dart#L62)). Next read will throw. **Fix:** write `admin.firestore.Timestamp.fromMillis(now)` server-side, or make client parse int-or-Timestamp.
- **F-12 🔵 `tagsThisMonth` never resets.** Incremented on every award; no monthly cron resets it. Monthly leaderboards will show lifetime totals. **Fix:** add a monthly reset job or compute from a time-bounded query.
- **F-13 🔵 `syncRecalls` malformed date range.** URL uses literal `"NOW"` ([`functions/index.js:387`](../supply-closet/firebase/functions/index.js#L387)); openFDA expects `YYYYMMDD`. Query silently returns empty. **Fix:** `new Date().toISOString().slice(0,10).replace(/-/g, "")`.
- **F-14 🔵 Missing Firestore index for `_verifyRecentTag`.** Query is `where taggedByUserIds array-contains uid orderBy lastConfirmed desc` — no composite index declared. First prod call throws `FAILED_PRECONDITION`. **Fix:** add composite index on `(taggedByUserIds ASC, lastConfirmed DESC)` in `firestore.indexes.json`.
- **F-7 🟡 `deleteAccount` order leaves zombies.** Deletes Firestore doc first ([`auth_service.dart:131-140`](../supply-closet/lib/services/auth_service.dart#L131-L140)); if auth `delete()` throws `requires-recent-login`, profile is gone but auth remains. **Fix:** delete auth first (re-auth if needed), or soft-delete via `deletedAt` + cleanup job.
- **F-4 🟡 Profile-read rule requires existing user doc.** `userFacility()` does a `get()` on `/users/{uid}`; brand-new users hit `permission-denied` on any profile read before their own doc is written. Also adds one extra read per request at scale. **Fix:** `exists(...)` null-guard; or push `facilityId` into custom claims.

### Client — state, lifecycle, UX

- **F-17 🟠 `StreamSubscription` leaks in providers.** [`procedure_provider.dart:62`](../supply-closet/lib/providers/procedure_provider.dart#L62) and [`auth_provider.dart:22`](../supply-closet/lib/providers/auth_provider.dart#L22) call `.listen(...)` without keeping a reference. `loadProcedures()` re-runs on every `ProcedureListScreen.initState` via post-frame callback → duplicated Firestore listeners stack per navigation. **Fix:** store the subscription, cancel before re-listening.
- **F-18 🟠 `print()` in production and silent `catch(_)` swallows.** [`auth_service.dart:43`](../supply-closet/lib/services/auth_service.dart#L43) uses bare `print`. [`auth_provider.dart:42-46`](../supply-closet/lib/providers/auth_provider.dart#L42), [`procedure_provider.dart:52-59, 83-88`](../supply-closet/lib/providers/procedure_provider.dart#L52) swallow exceptions without calling `FirebaseCrashlytics.instance.recordError`. Crashlytics is wired globally but never invoked from per-feature catches. **Fix:** replace `print` with `debugPrint`; add `recordError` breadcrumbs in every catch.
- **F-19 🟠 `CameraController` dispose race.** [`tag_supply_screen.dart:300-317`](../supply-closet/lib/screens/tag/tag_supply_screen.dart#L300-L317) starts an image stream but doesn't `stopImageStream` before `dispose`. Back-navigation during scan throws "CameraController was used after being disposed." **Fix:** `await _camera?.stopImageStream()` before `dispose()`.
- **F-20 🟠 Barcode scanner allocated but never scans.** The `processImage` call is missing in the image-stream callback ([`tag_supply_screen.dart:302-309`](../supply-closet/lib/screens/tag/tag_supply_screen.dart#L302-L309)). ML-Kit dependency is dead weight; barcode scanning is non-functional despite being a PRD P0 feature.
- **F-21 🟠 No loading / empty / error states.** [`ProcedureListScreen`](../supply-closet/lib/screens/procedures/procedure_list_screen.dart#L165-L180), [`LeaderboardScreen` tabs](../supply-closet/lib/screens/leaderboard/leaderboard_screen.dart#L96-L110) render nothing on error — `snapshot.error` ignored. Users see an infinite spinner or blank screen.
- **F-22 🟠 Glove-friendly 48dp target not enforced.** `AppConstants.minTouchTarget = 48` exists, but [`procedure_detail_screen.dart:162-182`](../supply-closet/lib/screens/procedures/procedure_detail_screen.dart#L162) uses 28x28 and [`ar_finder_screen.dart:211-225`](../supply-closet/lib/screens/find/ar_finder_screen.dart#L211) uses 44x44. Primary user wears nitrile gloves.
- **F-23 🟠 Onboarding form has zero validation.** [`profile_screen.dart:162-214`](../supply-closet/lib/screens/profile/profile_screen.dart#L162-L214) takes any text, regex-slugs it to an ID. Two "Mount Sinai" hospitals collapse to one `facilityId` and cross-contaminate data. No `Form`, no `validator`. No first-launch flow — users without a facility see "Set your unit first" placeholders app-wide.
- **F-24 🟡 `GamificationProvider.recordAction` uses stale `profile.points`.** [`gamification_provider.dart:73-76`](../supply-closet/lib/providers/gamification_provider.dart#L73-L76) computes `oldLevel → newLevel` from the local snapshot, not the authoritative server response. Parallel awards race and mis-fire level-up celebrations. **Fix:** drive level-up off the server's returned `totalXp` (or off the profile stream).
- **F-25 🟡 `XpBar.didUpdateWidget` uses stale `previousXp`.** [`xp_bar.dart:42-48`](../supply-closet/lib/widgets/xp_bar.dart#L42-L48) animates from `widget.previousXp` (rarely updated) instead of last-rendered XP. Every XP gain animates from 0%.
- **F-26 🟡 Two sources of truth for badges.** [`BadgeDefinitions.badges`](../supply-closet/lib/config/constants.dart#L43-L87) has 7 entries; [`GamificationService.allBadges`](../supply-closet/lib/services/gamification_service.dart#L245-L383) has 17. Badges earned via the service don't appear on the profile grid.
- **F-27 🟡 Two sources of truth for level/title.** `UserProfile.rankTitle` uses `{100,500,1000,2000,5000}` with 6 titles; `GamificationService.levelThresholds` uses 13 titles and different thresholds. Profile and leaderboard show different levels for the same user.
- **F-28 🟡 `DailyChallenge` progress doesn't notify.** [`gamification_provider.dart:111-120`](../supply-closet/lib/providers/gamification_provider.dart#L111-L120) increments `currentProgress` without `notifyListeners` unless complete — partial progress bars stay frozen.
- **F-29 🟡 `context.watch` at screen root.** [`procedure_list_screen.dart:37-39`](../supply-closet/lib/screens/procedures/procedure_list_screen.dart#L37) subscribes to three providers — any daily-challenge tick rebuilds the whole scroll view.
- **F-30 🟡 Leaderboard rebuilds re-download avatars.** Uses `NetworkImage` ([`leaderboard_screen.dart:351, 443`](../supply-closet/lib/screens/leaderboard/leaderboard_screen.dart#L351), `profile_screen.dart:90`) despite `cached_network_image` already in deps.
- **F-31 🟡 `CelebrationOverlay` uses uncancellable `Future.delayed`.** [`celebration_overlay.dart:64-68`](../supply-closet/lib/widgets/celebration_overlay.dart#L64-L68). Store a `Timer` and cancel in dispose.
- **F-32 🔵 Dialog `TextEditingController`s never disposed.** [`profile_screen.dart:162-214`](../supply-closet/lib/screens/profile/profile_screen.dart#L162-L214). Minor leak per open.
- **F-33 🔵 Hardcoded placeholder numbers visible to users.** `_UnitVsUnitTab` fake counts 142/128/97/86/64 ([`leaderboard_screen.dart:191-195`](../supply-closet/lib/screens/leaderboard/leaderboard_screen.dart#L191)). Comment says "Phase 2" but ships today.
- **F-34 🔵 Dead dependencies.** `firebase_messaging`, `fl_chart`, `shimmer`, `lottie`, `json_annotation`/`json_serializable` declared in [`pubspec.yaml`](../supply-closet/pubspec.yaml) but never imported or used in `lib/`.
- **F-35 🔵 Deprecated `Colors.*.withOpacity` throughout (~20+).** Should be `withValues(alpha:)` on current Flutter.

### AR marketing vs implementation

- **F-36 🟠 "AR-powered supply finder" is camera-preview-plus-Stack.** `ar_flutter_plugin: ^0.7.3` is declared but **not imported anywhere** in `lib/`. [`ar_finder_screen.dart:105-142`](../supply-closet/lib/screens/find/ar_finder_screen.dart#L105-L142) renders a static gradient `Container` as "camera" and places markers on a literal `col/row` pixel grid. `SupplyLocation.x/y/z` are written as `0,0,0` in [`tag_supply_screen.dart:80-83`](../supply-closet/lib/screens/tag/tag_supply_screen.dart#L80-L83). There is no ARCore/ARKit session, surface detection, anchor placement, or camera-to-world transform. The PRD markets AR as P0; the `ar_flutter_plugin` package has been abandoned since 2023. **Fix:** decide — either rename the product to "Supply Finder" and present as 2D map, or pick a maintained AR stack (e.g., `arcore_flutter_plugin` + `arkit_plugin`, or ARCore Geospatial) and wire real anchors.

### Testing posture

- **F-37 🟠 No `test/` directory.** Zero unit, widget, or integration tests. `flutter_test` declared but unused. The entire gamification module (`levelFromXp`, `streakMultiplier`, `currentEvent`, 16 badge predicates) is pure and trivially testable. An integration test for `tagSupply` would have caught F-6 before production.
- **F-38 🔵 `_weekOfYear` off-by-one risk.** [`gamification_provider.dart:141-145`](../supply-closet/lib/providers/gamification_provider.dart#L141-L145) classic ISO-week pitfall; unit-testable.
- **F-39 🔵 No CI evidence.** No GitHub Actions, no `.github/workflows`, no linter gate, no build verification on commit. Nothing prevents shipping code that doesn't compile (see F-0, F-2 — they shipped).

---

## 3. Priority Action List

### P0 — Before next commit
1. **F-0, F-2:** Fix the two compile errors. Run `flutter analyze` and `flutter build apk --debug` in CI before merging anything else.
2. **F-6:** Add `version` to both rule allow-lists — without this, the app's core write path fails.
3. **F-14:** Add the missing composite index — the first prod XP award will otherwise crash.

### P1 — Before deployment
4. **F-5, F-15, F-3:** Tighten supply CREATE rule (pin `confidence`, `lastConfirmed`, `taggedByUserIds`) and facility-change rule (require `request.time`); bound `notFoundReports` growth.
5. **F-8, F-9:** Enable App Check; rework `_verifyRecentTag` to require `supplyId` and track per-supply XP-claim state.
6. **F-1:** Make `lookupUdi` rate-limit transactional.
7. **F-16:** Decide — tag-writes via Cloud Function, or bullet-proof the client-write rules. Half-and-half is the current worst-of-both.

### P2 — First cleanup sprint
8. **F-17–F-21:** Cancel stream subscriptions, stop the camera stream before dispose, replace `print` with `debugPrint` + `recordError`, render error states.
9. **F-26, F-27:** Collapse the two badge sources and two level/title sources to one each.
10. **F-36:** Decide what the AR story actually is and make the code match the marketing.
11. **F-37, F-39:** Create `test/` with gamification unit tests; add a CI workflow that runs `flutter analyze` + tests on every PR.

### P3 — Backlog polish
12. **F-10, F-11, F-12, F-13, F-7, F-4:** Backend correctness nits (transactional query, millis vs Timestamp, monthly reset, syncRecalls date, deleteAccount order, rule cold-start).
13. **F-22–F-25, F-28–F-35, F-38:** Client polish — touch targets, onboarding validation, celebration race, deprecated APIs, dead deps, leaderboard placeholder data.

---

## 4. Notes on Review Method

- Both critical compile errors (F-0, F-2) were confirmed by reading the source files directly, not just by agent assertion.
- Rule findings (F-5, F-6, F-15) were read against the current `firestore.rules` line numbers.
- Cloud Functions findings (F-1, F-9, F-10, F-13, F-14) cite current `functions/index.js` line numbers.
- Some findings (F-34 dead deps, F-35 deprecated API count) are approximations — grep before acting.
- Recommend re-running this review after the P0/P1 fixes land; partial fixes in this round show the codebase would benefit from an emulator-based integration test gate.

*End of Second-Pass Review*
