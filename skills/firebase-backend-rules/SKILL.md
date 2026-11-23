---
name: firebase-backend-rules
description: Guidelines for editing Firestore security rules (firestore.rules), indexes, and Cloud Functions (firebase/functions/index.js) without breaking security invariants.
---

# Firebase Backend & Security Rules Skill

Use this skill whenever modifying files under `supply-closet/firebase/` or changing how the Flutter client reads/writes Firestore documents.

## 0. Firebase Project Scope (`gen-lang-client-0675309660`)

As of 2026-11-23, 3DPrintPosters / 3DPrintYou migrated to its own dedicated Firebase project (`app-3dprintyou`), so SupplyCloset owns Firestore rules on `gen-lang-client-0675309660` again (`DEC-015` update):

- **Deployed file:** `supply-closet/firebase/firestore.rules`, configured in `supply-closet/firebase/firebase.json`.
- **Deploy commands (run from `supply-closet/firebase/`):**
  - Rules: `npx -y firebase-tools@latest deploy --only firestore:rules --project gen-lang-client-0675309660`
  - Indexes: `npx -y firebase-tools@latest deploy --only firestore:indexes --project gen-lang-client-0675309660` (never use `--force`)
  - Functions: `npx -y firebase-tools@latest deploy --only functions --project gen-lang-client-0675309660`
- **Shared Auth note:** `gen-lang-client-0675309660` still shares Firebase Auth with the Texas AI Consulting website admin sign-in (`E:\PROJECTS\TexasAI Landing Page`, Auth only). Do not delete/disable non-SupplyCloset Auth users.

## 1. Security Invariants (21/21 Audit Remediation)

All changes to `supply-closet/firebase/firestore.rules` and `supply-closet/firebase/functions/index.js` must preserve these invariants (see [`DECISIONS.md`](../../DECISIONS.md) `DEC-006`):

1. **Role & XP Protection on User Docs (`/users/{userId}`):**
   - On `create`: `role` must be `"nurse"`, `xp == 0`, `level == 1`, `badges.size() == 0`.
   - On `update`: Clients cannot modify `role`, `xp`, `level`, `badges`, `streakDays`, or `totalTags`. Only Admin SDK (Cloud Functions) may update gamification fields.
   - Facility switching is rate-limited by cooldown (`lastFacilityChange`).
2. **Facility Scoping (`/facilities/{facilityId}/...`):**
   - Reads and writes inside a facility require the authenticated user's profile `/users/$(request.auth.uid)` to have a matching `facilityId`.
3. **Supply Optimistic Concurrency (`version`):**
   - Updating a supply document under `supplyRooms/{roomId}/supplies/{supplyId}` requires `request.resource.data.version == resource.data.version + 1`.
   - Confidence must remain bounded between `0.0` and `1.0`.
4. **Callable Cloud Functions (`functions/index.js`):**
   - Every callable (`lookupUdi`, `awardXp`) and HTTP endpoint (`healthCheck`) must verify authentication / rate limits as configured.
   - `awardXp` verifies the user's recent tag in the specified `roomId` and `supplyId` before granting XP.

## 2. Verification Commands

Run linting in `supply-closet/firebase/functions` after any backend change:

```powershell
npm --prefix supply-closet/firebase/functions run lint
```

## 3. Never Commit Secrets

Never commit `.env`, `google-services.json`, `GoogleService-Info.plist`, `lib/firebase_options.dart`, or service account keys. Use `.tmp/` for any local scratch data.
