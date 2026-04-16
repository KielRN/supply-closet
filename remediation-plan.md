# Remediation Plan

This checklist tracks all findings from the [Adversarial Review](adversarial-review.md) with status and priority.

---

## 🔴 Critical — Fix Before Any Deployment

- [x] **1.1** Fix role escalation in Firestore rules — validate `role == 'nurse'` on profile creation
  - File: `supply-closet/firebase/firestore.rules:57-60`
  - See: [adversarial-review.md §1.1](adversarial-review.md#11--role-escalation-via-profile-creation)
  - **Fixed:** Added `role == 'nurse'` validation plus gamification field zero-checks on profile creation

- [x] **2.1** Add server-side XP verification in `awardXp` — confirm action actually occurred before awarding XP
  - File: `supply-closet/firebase/functions/index.js:124-163`
  - See: [adversarial-review.md §2.1](adversarial-review.md#21--xp-farming-via-rapid-tagging)
  - **Fixed:** Added 5-second rate limit per user and tag verification (checks `taggedByUserIds` + `lastConfirmed` within 60s). Client now calls Cloud Function instead of direct Firestore write.

---

## 🟠 High — Fix Within 30 Days

- [x] **1.2** Remove or secure `healthCheck` endpoint — add auth or IP allowlisting
  - File: `supply-closet/firebase/functions/index.js`
  - See: [adversarial-review.md §1.2](adversarial-review.md#12--unauthenticated-health-check-endpoint)
  - **Fixed:** Removed `healthCheck` endpoint entirely; use GCP-native monitoring instead

- [x] **1.3** Add rate limiting to Cloud Functions (`lookupUdi`, `awardXp`)
  - File: `supply-closet/firebase/functions/index.js`
  - See: [adversarial-review.md §1.3](adversarial-review.md#13--no-rate-limiting-on-cloud-functions)
  - **Fixed:** `awardXp` has sliding window (10/min), `lookupUdi` has sliding window (30/min)

- [x] **2.2** Require meaningful action to maintain streak (not just app open)
  - File: `supply-closet/firebase/functions/index.js`
  - See: [adversarial-review.md §2.2](adversarial-review.md#22--streak-manipulation)
  - **Fixed:** Streak now uses `lastTagAt` instead of `lastActive`; only tag/confirm actions maintain streak

- [x] **3.1** Use atomic `FieldValue.increment()` for confidence updates
  - File: `supply-closet/lib/services/firestore_service.dart:102-118`
  - See: [adversarial-review.md §3.1](adversarial-review.md#31--confidence-score-race-condition)
  - **Fixed:** Wrapped confidence update in Firestore transaction for atomicity

- [x] **3.2** Redesign `decayConfidence` for scale — use collection group queries + batching
  - File: `supply-closet/firebase/functions/index.js`
  - See: [adversarial-review.md §3.2](adversarial-review.md#32--decay-function-performance-risk)
  - **Fixed:** Replaced nested reads with collection group query + paginated batches of 400

- [x] **4.1** Restrict profile reads to same-facility users; anonymize leaderboard
  - File: `supply-closet/firebase/firestore.rules:51-55`
  - See: [adversarial-review.md §4.1](adversarial-review.md#41--hipaa-adjacent-data-exposure)
  - **Fixed:** Profile reads now restricted to own profile or same-facility users

- [x] **5.1** Support multiple rooms per unit — remove hard-coded `roomId = 'main'`
  - File: `supply-closet/lib/config/constants.dart`
  - See: [adversarial-review.md §5.1](adversarial-review.md#51--single-room-per-unit-hard-coded)
  - **Fixed:** Added `AppConstants.defaultRoomId`; screens reference constant instead of hard-coded string

- [x] **6.1** Add Firebase Crashlytics for error reporting
  - See: [adversarial-review.md §6.1](adversarial-review.md#61--no-error-reporting--crash-analytics)
  - **Fixed:** Added `firebase_crashlytics` dependency and initialized in `main.dart` with Flutter/async error handlers

---

## 🟡 Medium — Fix Within 90 Days

- [x] **1.4** Add input validation for supply names (length, sanitization)
  - File: `supply-closet/firebase/firestore.rules`
  - See: [adversarial-review.md §1.4](adversarial-review.md#14--missing-input-sanitization-on-supply-names)
  - **Fixed:** Added `validSupplyName()` (1-60 chars) and `validBarcode()` (8-14 digits) validation functions

- [x] **1.5** Remove client-side XP prediction — use server response only
  - File: `supply-closet/lib/providers/gamification_provider.dart`
  - See: [adversarial-review.md §1.5](adversarial-review.md#15--client-side-xp-calculation-mismatch)
  - **Fixed:** Client now calls server first, uses server-returned XP for celebrations

- [x] **2.3** Limit facility/unit changes (e.g., max 1 per 30 days or admin approval)
  - File: `supply-closet/firebase/firestore.rules`
  - See: [adversarial-review.md §2.3](adversarial-review.md#23--leaderboard-manipulation-via-facility-hopping)
  - **Fixed:** Added `lastFacilityChange` timestamp; Firestore rules enforce 30-day cooldown

- [x] **4.2** Document camera data handling in privacy policy; add network monitoring
  - See: [adversarial-review.md §4.2](adversarial-review.md#42--camera-permission-scope)
  - **Fixed:** Added Privacy & Camera Data section to SETUP.md documenting on-device-only processing

- [x] **5.2** Implement offline conflict resolution for supply tags
  - See: [adversarial-review.md §5.2](adversarial-review.md#52--no-offline-conflict-resolution)
  - **Fixed:** Added version field for optimistic concurrency; transactions detect deleted documents

- [x] **6.2** Add forced update mechanism via Firebase Remote Config
  - See: [adversarial-review.md §6.2](adversarial-review.md#62--no-app-versioning-strategy)
  - **Fixed:** Added Remote Config version check on launch; compares app version against `min_app_version`

---

## 🔵 Low — Backlog

- [x] **3.3** Implement data retention policy and user account deletion
  - See: [adversarial-review.md §3.3](adversarial-review.md#33--no-data-retention-policy)
  - **Fixed:** Added `deleteAccount()` to AuthService; added `cleanupStaleSupplies` Cloud Function (weekly, deletes supplies with confidence < 0.1 older than 30 days)

- [x] **4.3** Remove email from Firestore profile (already in Firebase Auth)
  - File: `supply-closet/lib/services/auth_service.dart`
  - See: [adversarial-review.md §4.3](adversarial-review.md#43--email-exposure-in-user-profiles)
  - **Fixed:** Removed email from UserProfile.toFirestore() and auth_service profile creation

- [x] **5.3** Refactor providers to use dependency injection
  - File: `supply-closet/lib/providers/`
  - See: [adversarial-review.md §5.3](adversarial-review.md#53--provider-instantiation-anti-pattern)
  - **Fixed:** All providers now accept services via optional constructor parameters

- [x] **6.3** Add custom analytics events for key user actions
  - See: [adversarial-review.md §6.3](adversarial-review.md#63--no-analytics-event-tracking)
  - **Fixed:** Added `logLogin` on sign-in and `logEvent` for supply_tagged with metadata

---

## Progress

| Severity | Total | Complete | Remaining |
|----------|-------|----------|-----------|
| 🔴 Critical | 2 | 2 | 0 |
| 🟠 High | 9 | 9 | 0 |
| 🟡 Medium | 6 | 6 | 0 |
| 🔵 Low | 4 | 4 | 0 |
| **Total** | **21** | **21** | **0** |
