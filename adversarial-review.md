# SupplyCloset — Adversarial Review

**Reviewer:** Roo (Architect Mode)  
**Date:** April 16, 2026  
**Scope:** Full-stack review of Flutter mobile client, Firebase security rules, Cloud Functions, and architectural design  
**Severity Scale:** 🔴 Critical | 🟠 High | 🟡 Medium | 🔵 Low | ⚪ Informational

---

## Executive Summary

SupplyCloset is a well-conceived AR-powered supply finder for nurses with a thoughtful data strategy and gamification layer. However, the review uncovered **18 findings** across security, data integrity, gamification exploits, and compliance gaps. The most severe issues involve Firestore rule bypasses that could allow privilege escalation, a gamification system vulnerable to XP farming, and missing HIPAA-adjacent safeguards for a healthcare-adjacent application.

**Top 5 Risks:**
1. Role escalation via client-writable `role` field on profile creation
2. Gamification XP farming through rapid-fire tagging
3. No rate limiting on supply tagging (data pollution attack)
4. Missing input sanitization on supply names (XSS/injection vector)
5. `healthCheck` endpoint exposed without authentication

---

## 1. Security Vulnerabilities

### 1.1 🔴 Role Escalation via Profile Creation

**File:** [`firestore.rules:57-60`](supply-closet/firebase/firestore.rules:57)

```
allow create: if isOwner(userId)
  && request.resource.data.uid == userId
  && request.resource.data.points == 0
  && request.resource.data.badges.size() == 0;
```

**Finding:** The create rule validates `uid`, `points`, and `badges`, but does NOT validate the `role` field. A malicious user can create their profile with `role: 'admin'` on first sign-in, gaining write access to procedures, facility metadata, and the ability to delete any supply tag in their facility.

**Attack Scenario:**  
1. Attacker signs in with Google  
2. Intercepts the Firestore `set()` call in [`auth_service.dart:73`](supply-closet/lib/services/auth_service.dart:73)  
3. Modifies the payload to include `role: 'admin'`  
4. Gains full admin privileges

**Recommendation:**  
Add explicit role validation to the create rule:
```
allow create: if isOwner(userId)
  && request.resource.data.uid == userId
  && request.resource.data.points == 0
  && request.resource.data.badges.size() == 0
  && request.resource.data.role == 'nurse';
```

Also enforce that the `role` field can never be changed via client update (it's already restricted in the update rule, but the create gap is the problem).

---

### 1.2 🟠 Unauthenticated Health Check Endpoint

**File:** [`firebase/functions/index.js:303-305`](supply-closet/firebase/functions/index.js:303)

```javascript
exports.healthCheck = onRequest({region: "us-central1"}, (req, res) => {
  res.json({ok: true, time: new Date().toISOString()});
});
```

**Finding:** The `healthCheck` function is an `onRequest` (HTTP) function with no authentication. While health checks are typically public, this one returns a server timestamp which could be used for timing attacks or server fingerprinting. More importantly, it's an unnecessary attack surface — health checks should use Cloud Run health endpoints or Firebase's built-in monitoring.

**Recommendation:**  
- Remove this function and rely on GCP-native health monitoring  
- If kept, add IP allowlisting or a shared secret header

---

### 1.3 🟠 No Rate Limiting on Cloud Functions

**File:** [`firebase/functions/index.js`](supply-closet/firebase/functions/index.js)

**Finding:** None of the callable functions (`lookupUdi`, `awardXp`) implement rate limiting. A malicious user could:
- Spam `lookupUdi` with random barcodes to exhaust the openFDA API quota (1,000/day without key)
- Call `awardXp` in rapid succession to farm XP (though the transaction model limits double-spending)

**Recommendation:**  
- Implement per-user rate limiting using a Firestore counter or Redis  
- Add Firebase App Check to prevent unauthorized client access  
- Consider Cloud Armor for DDoS protection

---

### 1.4 🟡 Missing Input Sanitization on Supply Names

**File:** [`firestore.rules:43-48`](supply-closet/firebase/firestore.rules:43)

```
function tagFieldsOnly() {
  return request.resource.data.keys().hasOnly([
    'name', 'barcode', 'category', 'location',
    'confidence', 'lastConfirmed', 'tagCount', 'taggedByUserIds',
    'notFoundReports'
  ]);
}
```

**Finding:** The `tagFieldsOnly()` function validates field names but not field values. The `name` field has no length limit, character validation, or sanitization. A user could inject:
- Extremely long strings (DoS via storage cost)
- HTML/script content (if rendered in a web dashboard)
- Profanity or offensive content (reputational risk)

**Recommendation:**  
- Add Firestore validation: `request.resource.data.name.size() <= 60`  
- Add a profanity filter in the Cloud Function trigger  
- Sanitize output in all rendering contexts

---

### 1.5 🟡 Client-Side XP Calculation Mismatch

**File:** [`gamification_provider.dart:48-54`](supply-closet/lib/providers/gamification_provider.dart:48)

**Finding:** The client calculates XP locally via `GamificationService.calculateXp()` and then calls the server-side `awardXp` function. The server recalculates XP independently. If the calculations diverge (e.g., due to different multiplier logic), the user sees one XP value locally but a different value is persisted. This creates a desync that could confuse users or be exploited to understand server internals.

**Recommendation:**  
- Remove client-side XP calculation entirely  
- Let the server return the awarded XP and update the UI from the response  
- The client should never "predict" server-side state

---

## 2. Gamification Exploits

### 2.1 🔴 XP Farming via Rapid Tagging

**File:** [`gamification_service.dart`](supply-closet/lib/services/gamification_service.dart) and [`firestore_service.dart:79-133`](supply-closet/lib/services/firestore_service.dart:79)

**Finding:** There is no cooldown or rate limit on supply tagging. A user could:
1. Tag the same supply with slightly different names ("Glove", "Gloves", "Exam Glove", "Nitrile Glove")  
2. Each tag awards 10 XP  
3. With streak multipliers (up to 2.5x), a user could earn 25 XP per tag  
4. Rapid tagging could yield hundreds of XP per minute

The server-side `awardXp` function doesn't validate that the tag actually happened — it trusts the client's claim that an action occurred.

**Attack Scenario:**  
A script calls `awardXp` with `action: 'tagNew'` 100 times in a minute, earning 1,000+ XP and climbing the leaderboard without ever using the app.

**Recommendation:**  
- The `awardXp` function should verify the action actually occurred (e.g., check that a supply was recently tagged by this user)  
- Implement a per-user tagging cooldown (e.g., max 1 tag per 10 seconds)  
- Add anomaly detection for suspicious XP velocity

---

### 2.2 🟠 Streak Manipulation

**File:** [`firebase/functions/index.js:165-172`](supply-closet/firebase/functions/index.js:165)

```javascript
function updateStreak(profile) {
  const last = profile.lastActive ? profile.lastActive.toDate() : null;
  if (!last) return 1;
  const now = new Date();
  const diffHours = (now - last) / (1000 * 60 * 60);
  if (diffHours < 24) return profile.streakDays || 1;
  if (diffHours < 48) return (profile.streakDays || 0) + 1;
  return 1;
}
```

**Finding:** The streak system uses `lastActive` timestamp to determine streak continuity. A user can maintain a streak by simply opening the app once per day without performing any meaningful action. The streak is updated on every `awardXp` call, which means even a single "report not found" action (5 XP) maintains the streak.

**Recommendation:**  
- Require a minimum meaningful action (e.g., at least 1 tag) to maintain a streak  
- Track "active shifts" rather than "active days"  
- Consider requiring actions during actual shift hours

---

### 2.3 🟡 Leaderboard Manipulation via Facility Hopping

**File:** [`user_profile.dart:98-100`](supply-closet/lib/models/user_profile.dart:98) and [`firestore.rules:64-69`](supply-closet/firebase/firestore.rules:64)

**Finding:** Users can change their `facilityId` and `unitId` at will via the profile update rule. A user could:
1. Build up XP on one unit  
2. Switch to a less active unit  
3. Dominate the leaderboard with minimal effort

**Recommendation:**  
- Limit facility/unit changes (e.g., max 1 per 30 days)  
- Or require admin approval for facility changes  
- Track facility change history

---

## 3. Data Integrity Issues

### 3.1 🟠 Confidence Score Race Condition

**File:** [`firestore_service.dart:102-118`](supply-closet/lib/services/firestore_service.dart:102)

```javascript
final currentConfidence = (currentData['confidence'] ?? 0.5).toDouble();
final newConfidence = (currentConfidence + AppConstants.confidenceConfirmBoost)
    .clamp(0.0, 1.0);
```

**Finding:** The confidence update reads the current value and writes a new value without using a Firestore transaction. If two users tag the same supply simultaneously, both reads return the same `currentConfidence`, and both writes set `newConfidence = currentConfidence + 0.1`. The second write overwrites the first, losing one confirmation.

**Recommendation:**  
- Use `FieldValue.increment()` for atomic confidence updates  
- Or wrap in a Firestore transaction

---

### 3.2 🟡 Decay Function Performance Risk

**File:** [`firebase/functions/index.js:216-248`](supply-closet/firebase/functions/index.js:216)

```javascript
for (const fac of facilitiesSnap.docs) {
  const unitsSnap = await fac.ref.collection("units").get();
  for (const unit of unitsSnap.docs) {
    const roomsSnap = await unit.ref.collection("supplyRooms").get();
    for (const room of roomsSnap.docs) {
      const suppliesSnap = await room.ref.collection("supplies").get();
```

**Finding:** The `decayConfidence` function performs nested collection reads across all facilities, units, rooms, and supplies. With 100 facilities × 10 units × 5 rooms × 500 supplies = 2.5 million documents, this function will:
- Exceed the 9-minute Cloud Functions timeout  
- Incur massive Firestore read costs (~$1.80/day at $0.06/100K reads)  
- Potentially hit Firestore rate limits

**Recommendation:**  
- Use collection group queries to query all `supplies` collections at once  
- Process in batches with pagination  
- Consider using Cloud Run for long-running jobs  
- Add a `lastDecayedAt` field and only process stale documents

---

### 3.3 🔵 No Data Retention Policy

**Finding:** The application has no data retention or deletion mechanism. Supply tags, user profiles, and tag history accumulate indefinitely. Over time, this creates:
- Storage cost growth  
- GDPR "right to erasure" compliance risk (if expanding internationally)  
- Stale data that degrades AR accuracy

**Recommendation:**  
- Implement automatic cleanup of supplies with confidence < 0.1  
- Add user account deletion flow  
- Document data retention policy

---

## 4. Privacy & Compliance

### 4.1 🟠 HIPAA-Adjacent Data Exposure

**File:** [`firestore.rules:54`](supply-closet/firebase/firestore.rules:54)

```
// Anyone authed can read profiles (for leaderboards)
allow read: if isAuthed();
```

**Finding:** While the PRD states "No PHI is stored in Firestore," the application stores:
- User display names (could be full names)  
- Email addresses  
- Facility and unit assignments  
- Activity patterns (when nurses are active, which supplies they search for)

This data, while not PHI per se, could be used to infer:
- Which nurses work which shifts  
- Which procedures are performed on which units  
- Staffing patterns

Hospitals may classify this as sensitive operational data requiring protection.

**Recommendation:**  
- Restrict profile reads to same-facility users only  
- Anonymize leaderboard data (show initials, not full names)  
- Add a hospital-facing data processing agreement (DPA)  
- Consider pseudonymization for analytics

---

### 4.2 🟡 Camera Permission Scope

**File:** [`tag_supply_screen.dart:3`](supply-closet/lib/screens/tag/tag_supply_screen.dart:3) and [`ar_finder_screen.dart`](supply-closet/lib/screens/find/ar_finder_screen.dart)

**Finding:** The app requests camera access for AR and barcode scanning. While the tech architecture doc states "no camera frames leave the phone," there's no technical enforcement of this claim. A future code change could silently upload frames without user knowledge.

**Recommendation:**  
- Add a privacy policy that explicitly states camera data handling  
- Consider network traffic monitoring in CI/CD to detect accidental frame uploads  
- Document the on-device-only processing guarantee in code comments

---

### 4.3 🔵 Email Exposure in User Profiles

**File:** [`auth_service.dart:69`](supply-closet/lib/services/auth_service.dart:69)

```dart
final profile = UserProfile(
  uid: user.uid,
  displayName: user.displayName ?? 'Nurse',
  email: user.email,  // <-- stored in Firestore
  photoUrl: user.photoURL,
);
```

**Finding:** User emails are stored in Firestore and readable by any authenticated user (via the leaderboard read rule). This could enable:
- Phishing attacks targeting nurses  
- Spam campaigns  
- Social engineering

**Recommendation:**  
- Remove email from the Firestore profile (it's already in Firebase Auth)  
- If needed for notifications, store a hashed version  
- Restrict email reads to the user themselves

---

## 5. Architectural Weaknesses

### 5.1 🟠 Single Room Per Unit Hard-Coded

**File:** [`tag_supply_screen.dart:64`](supply-closet/lib/screens/tag/tag_supply_screen.dart:64)

```dart
const roomId = 'main';
```

**Finding:** The room ID is hard-coded to `'main'` throughout the application. Many hospitals have multiple supply rooms per unit (e.g., clean utility room, medication room, linen closet). This architectural decision will require significant refactoring to support multiple rooms.

**Recommendation:**  
- Make the room ID configurable per unit  
- Design the data model to support multiple rooms from the start  
- At minimum, document this as a known limitation

---

### 5.2 🟡 No Offline Conflict Resolution

**File:** [`prd.md:85`](prd.md:85)

**Finding:** The PRD mentions "Offline mode (lite)" for procedure checklists, but the Firestore implementation has no offline conflict resolution strategy. If two nurses tag the same supply while offline, the last-write-wins behavior will lose data.

**Recommendation:**  
- Implement conflict resolution for offline tags  
- Use Firestore's built-in offline persistence with custom merge logic  
- Queue offline actions and reconcile on reconnect

---

### 5.3 🔵 Provider Instantiation Anti-Pattern

**File:** [`auth_provider.dart:7`](supply-closet/lib/providers/auth_provider.dart:7)

```dart
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
```

**Finding:** Each provider creates its own `AuthService` and `FirestoreService` instance. This prevents dependency injection, makes testing difficult, and could lead to multiple Firestore listeners.

**Recommendation:**  
- Use a dependency injection framework (e.g., `get_it` + `injectable`)  
- Or pass services via constructor injection  
- Share service instances across providers

---

## 6. Operational Risks

### 6.1 🟠 No Error Reporting / Crash Analytics

**Finding:** The application has no crash reporting (e.g., Firebase Crashlytics, Sentry). Errors are caught and logged to `print()` or `debugPrint()`, which are invisible in production.

**Recommendation:**  
- Add Firebase Crashlytics  
- Implement structured error logging  
- Set up alerts for error rate spikes

---

### 6.2 🟡 No App Versioning Strategy

**File:** [`pubspec.yaml:4`](supply-closet/pubspec.yaml:4)

```yaml
version: 0.1.0+1
```

**Finding:** There's no forced update mechanism or minimum version check. If a critical bug is deployed, there's no way to force users to update.

**Recommendation:**  
- Use Firebase Remote Config to enforce minimum app version  
- Implement a version check on app launch  
- Add a "force update" flow for critical bugs

---

### 6.3 🔵 No Analytics Event Tracking

**Finding:** While `firebase_analytics` is in the dependencies, there's no evidence of custom event tracking for key user actions (tagging, searching, completing procedures).

**Recommendation:**  
- Define a analytics event taxonomy  
- Track key conversion funnels  
- Monitor feature adoption rates

---

## 7. Summary Table

| # | Severity | Category | Finding | File |
|---|----------|----------|---------|------|
| 1.1 | 🔴 Critical | Security | Role escalation via profile creation | `firestore.rules:57` |
| 2.1 | 🔴 Critical | Gamification | XP farming via rapid tagging | `gamification_service.dart` |
| 1.2 | 🟠 High | Security | Unauthenticated health check | `functions/index.js:303` |
| 1.3 | 🟠 High | Security | No rate limiting on Cloud Functions | `functions/index.js` |
| 2.2 | 🟠 High | Gamification | Streak manipulation | `functions/index.js:165` |
| 2.3 | 🟡 Medium | Gamification | Leaderboard facility hopping | `user_profile.dart:98` |
| 1.4 | 🟡 Medium | Security | Missing input sanitization | `firestore.rules:43` |
| 1.5 | 🟡 Medium | Security | Client/server XP mismatch | `gamification_provider.dart:48` |
| 3.1 | 🟠 High | Data | Confidence score race condition | `firestore_service.dart:102` |
| 3.2 | 🟡 Medium | Data | Decay function performance risk | `functions/index.js:216` |
| 3.3 | 🔵 Low | Data | No data retention policy | — |
| 4.1 | 🟠 High | Privacy | HIPAA-adjacent data exposure | `firestore.rules:54` |
| 4.2 | 🟡 Medium | Privacy | Camera permission scope | `tag_supply_screen.dart` |
| 4.3 | 🔵 Low | Privacy | Email exposure in profiles | `auth_service.dart:69` |
| 5.1 | 🟠 High | Architecture | Single room hard-coded | `tag_supply_screen.dart:64` |
| 5.2 | 🟡 Medium | Architecture | No offline conflict resolution | `prd.md:85` |
| 5.3 | 🔵 Low | Architecture | Provider instantiation anti-pattern | `auth_provider.dart:7` |
| 6.1 | 🟠 High | Operations | No error reporting | — |
| 6.2 | 🟡 Medium | Operations | No app versioning strategy | `pubspec.yaml:4` |
| 6.3 | 🔵 Low | Operations | No analytics event tracking | — |

---

## 8. Recommended Priority Actions

### Immediate (Before Any Deployment)
1. Fix role escalation vulnerability in Firestore rules  
2. Add rate limiting to `awardXp` and `lookupUdi`  
3. Add input validation for supply names  
4. Remove unauthenticated `healthCheck` endpoint

### Short-Term (Within 30 Days)
5. Implement atomic confidence updates  
6. Add server-side XP verification  
7. Restrict profile reads to same-facility users  
8. Add Firebase Crashlytics

### Medium-Term (Within 90 Days)
9. Redesign decay function for scale  
10. Support multiple rooms per unit  
11. Implement offline conflict resolution  
12. Add forced update mechanism

---

*End of Adversarial Review*
