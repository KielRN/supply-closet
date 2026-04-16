# Remediation Plan

This checklist tracks all findings from the [Adversarial Review](adversarial-review.md) with status and priority.

---

## 🔴 Critical — Fix Before Any Deployment

- [ ] **1.1** Fix role escalation in Firestore rules — validate `role == 'nurse'` on profile creation
  - File: `supply-closet/firebase/firestore.rules:57-60`
  - See: [adversarial-review.md §1.1](adversarial-review.md#11--role-escalation-via-profile-creation)

- [ ] **2.1** Add server-side XP verification in `awardXp` — confirm action actually occurred before awarding XP
  - File: `supply-closet/firebase/functions/index.js:124-163`
  - See: [adversarial-review.md §2.1](adversarial-review.md#21--xp-farming-via-rapid-tagging)

---

## 🟠 High — Fix Within 30 Days

- [ ] **1.2** Remove or secure `healthCheck` endpoint — add auth or IP allowlisting
  - File: `supply-closet/firebase/functions/index.js:303-305`
  - See: [adversarial-review.md §1.2](adversarial-review.md#12--unauthenticated-health-check-endpoint)

- [ ] **1.3** Add rate limiting to Cloud Functions (`lookupUdi`, `awardXp`)
  - File: `supply-closet/firebase/functions/index.js`
  - See: [adversarial-review.md §1.3](adversarial-review.md#13--no-rate-limiting-on-cloud-functions)

- [ ] **2.2** Require meaningful action to maintain streak (not just app open)
  - File: `supply-closet/firebase/functions/index.js:165-172`
  - See: [adversarial-review.md §2.2](adversarial-review.md#22--streak-manipulation)

- [ ] **3.1** Use atomic `FieldValue.increment()` for confidence updates
  - File: `supply-closet/lib/services/firestore_service.dart:102-118`
  - See: [adversarial-review.md §3.1](adversarial-review.md#31--confidence-score-race-condition)

- [ ] **3.2** Redesign `decayConfidence` for scale — use collection group queries + batching
  - File: `supply-closet/firebase/functions/index.js:216-248`
  - See: [adversarial-review.md §3.2](adversarial-review.md#32--decay-function-performance-risk)

- [ ] **4.1** Restrict profile reads to same-facility users; anonymize leaderboard
  - File: `supply-closet/firebase/firestore.rules:54`
  - See: [adversarial-review.md §4.1](adversarial-review.md#41--hipaa-adjacent-data-exposure)

- [ ] **5.1** Support multiple rooms per unit — remove hard-coded `roomId = 'main'`
  - File: `supply-closet/lib/screens/tag/tag_supply_screen.dart:64`
  - See: [adversarial-review.md §5.1](adversarial-review.md#51--single-room-per-unit-hard-coded)

- [ ] **6.1** Add Firebase Crashlytics for error reporting
  - See: [adversarial-review.md §6.1](adversarial-review.md#61--no-error-reporting--crash-analytics)

---

## 🟡 Medium — Fix Within 90 Days

- [ ] **1.4** Add input validation for supply names (length, sanitization)
  - File: `supply-closet/firebase/firestore.rules:43-48`
  - See: [adversarial-review.md §1.4](adversarial-review.md#14--missing-input-sanitization-on-supply-names)

- [ ] **1.5** Remove client-side XP prediction — use server response only
  - File: `supply-closet/lib/providers/gamification_provider.dart:48-54`
  - See: [adversarial-review.md §1.5](adversarial-review.md#15--client-side-xp-calculation-mismatch)

- [ ] **2.3** Limit facility/unit changes (e.g., max 1 per 30 days or admin approval)
  - File: `supply-closet/firebase/firestore.rules:64-69`
  - See: [adversarial-review.md §2.3](adversarial-review.md#23--leaderboard-manipulation-via-facility-hopping)

- [ ] **4.2** Document camera data handling in privacy policy; add network monitoring
  - See: [adversarial-review.md §4.2](adversarial-review.md#42--camera-permission-scope)

- [ ] **5.2** Implement offline conflict resolution for supply tags
  - See: [adversarial-review.md §5.2](adversarial-review.md#52--no-offline-conflict-resolution)

- [ ] **6.2** Add forced update mechanism via Firebase Remote Config
  - See: [adversarial-review.md §6.2](adversarial-review.md#62--no-app-versioning-strategy)

---

## 🔵 Low — Backlog

- [ ] **3.3** Implement data retention policy and user account deletion
  - See: [adversarial-review.md §3.3](adversarial-review.md#33--no-data-retention-policy)

- [ ] **4.3** Remove email from Firestore profile (already in Firebase Auth)
  - File: `supply-closet/lib/services/auth_service.dart:69`
  - See: [adversarial-review.md §4.3](adversarial-review.md#43--email-exposure-in-user-profiles)

- [ ] **5.3** Refactor providers to use dependency injection
  - File: `supply-closet/lib/providers/auth_provider.dart:7`
  - See: [adversarial-review.md §5.3](adversarial-review.md#53--provider-instantiation-anti-pattern)

- [ ] **6.3** Add custom analytics events for key user actions
  - See: [adversarial-review.md §6.3](adversarial-review.md#63--no-analytics-event-tracking)

---

## Progress

| Severity | Total | Complete | Remaining |
|----------|-------|----------|-----------|
| 🔴 Critical | 2 | 0 | 2 |
| 🟠 High | 9 | 0 | 9 |
| 🟡 Medium | 6 | 0 | 6 |
| 🔵 Low | 4 | 0 | 4 |
| **Total** | **21** | **0** | **21** |
