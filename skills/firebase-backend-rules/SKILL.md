---
name: firebase-backend-rules
description: Guidelines for editing Firestore security rules (firestore.rules), indexes, and Cloud Functions (firebase/functions/index.js) without breaking security invariants.
---

# Firebase Backend & Security Rules Skill

Use this skill whenever modifying files under `supply-closet/firebase/` or changing how the Flutter client reads/writes Firestore documents.

## 0. Read First: The Firestore Rules File Is Shared

Firebase project `gen-lang-client-0675309660` hosts SupplyCloset AND the 3DPrintPosters / 3DPrintYou web app in ONE Firestore database `(default)`. A database has only one rules file, and every rules deploy replaces it for both apps. A rules deploy from this repo on 2026-11-09 locked 3DPrintYou customers out of their orders.

- **Deployed file:** `E:\PROJECTS\3DPrintPosters\infra\firebase\firestore.rules`. It has a labeled SupplyCloset section and a labeled 3DPrintPosters section, plus the shared `users/{userId}` block, which uses SupplyCloset's rule.
- **To change SupplyCloset rules:** edit the SupplyCloset section (or the shared `users` block) in that file, leave the 3DPrintPosters section unchanged, then run `npm run firebase:deploy:firestore-rules:dry-run` and `npm run firebase:deploy:firestore-rules:dev` from `E:\PROJECTS\3DPrintPosters`. Mirror the change into `supply-closet/firebase/firestore.rules`, which is a SupplyCloset-only reference copy and is never deployed.
- **Blocked on purpose:** `supply-closet/firebase/firebase.json` has no `"rules"` entry, so a deploy from that folder skips rules entirely. Do not add it back; the Firestore emulator is not used here (only the Functions emulator).
- **Never** run `firebase deploy`, `firebase deploy --only firestore`, or `--only firestore:rules` from `supply-closet/firebase/`. Use `--only functions` for Cloud Functions, and `--only firestore:indexes` (never with `--force`) for indexes.
- The invariants below still apply to the SupplyCloset section of the shared file.

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
