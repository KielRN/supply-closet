# AGENTS.md — AI Coding Agent Instructions

This file provides workspace context, conventions, and guardrails for any AI coding assistant working in the **SupplyCloset** repository.

---

## 1. Quick Orientation

- **Product:** **SupplyCloset** (`supplycloset.app`) — a mobile app that helps hospital nurses find clinical supplies in seconds using procedure checklists, crowdsourced shelf/bin locations, barcode scanning, and doorway-initialized AR guidance.
- **Owner:** Texas AI Consulting, LLC (SDVOSB).
- **Authoritative Trackers:**
  - [`HANDOFF.md`](HANDOFF.md) — Latest session handoff, current phone test state, and immediate next tasks.
  - [`ROADMAP.md`](ROADMAP.md) — Current status (`🟢` Done / `🔴` To Do) across all tracks.
  - [`DECISIONS.md`](DECISIONS.md) — Single source of truth when older docs (`prd.md`, `tech-architecture.md`) differ from newer decisions.
  - [`USER.md`](USER.md) — Simple phone setup, USB connection, and room-mapping guide for the user's test device (**Moto G Stylus 5G - 2024**).
  - [`CHANGELOG.md`](CHANGELOG.md) — Chronological history of changes.

---

## 2. Shared Skills (`skills/`)

Before modifying code, backend rules, or project docs, read the relevant agent-agnostic skill in [`skills/`](skills/README.md):

| Task Area | Skill File |
| :--- | :--- |
| **Flutter UI, Barcode, AR, Providers** | [`skills/flutter-supply-dev/SKILL.md`](skills/flutter-supply-dev/SKILL.md) |
| **Firestore Rules & Cloud Functions** | [`skills/firebase-backend-rules/SKILL.md`](skills/firebase-backend-rules/SKILL.md) |
| **Roadmap, Decisions & Docs Sync** | [`skills/docs-and-roadmap-sync/SKILL.md`](skills/docs-and-roadmap-sync/SKILL.md) |

---

## 3. Workspace Layout & Scratch Directory

- **`supply-closet/`** — Flutter mobile app (`lib/`, `test/`, `assets/data/`) and Firebase backend (`firebase/firestore.rules`, `firebase/functions/`). **The Firebase project is shared with other apps: `firebase/firestore.rules` is NOT the file that gets deployed. See guardrail 6.**
- **`skills/`** — Shared AI-agent-agnostic skill instructions.
- **`reviews/`** — Deep-dive research and architecture reviews (e.g., [`reviews/2026-10-21-spatial-product-research.md`](reviews/2026-10-21-spatial-product-research.md)).
- **`.tmp/`** — Git-ignored scratch directory at the repository root. **Always place temporary files, scratch scripts, or test outputs inside `.tmp/`** rather than cluttering the root or app folders.
- **No Graphify:** Do not run or generate `graphify-out/` artifacts in this project.

---

## 4. Essential Verification Commands

Run these checks after modifying Dart or Cloud Functions code:

```powershell
# Flutter static analysis and unit tests (run from supply-closet/)
cd supply-closet
flutter analyze --no-pub
flutter test --no-pub

# Firebase Cloud Functions lint (run from repo root)
npm --prefix supply-closet/firebase/functions run lint
```

### Pushing Software to the User's Connected Phone (Moto G Stylus 5G - 2024)

When the user connects their **Moto G Stylus 5G (2024)** (device ID `ZY22KP4X7C`) via USB and asks to push/install the app:

```powershell
# 1. Verify the phone is connected and authorized
& "C:\Users\Eliud\development\android-sdk\platform-tools\adb.exe" devices -l

# 2. Build the debug APK (from supply-closet/)
cd supply-closet
flutter build apk --debug

# 3. Install and launch directly on the Moto G Stylus 5G (2024)
& "C:\Users\Eliud\development\android-sdk\platform-tools\adb.exe" -s ZY22KP4X7C install -r "e:\PROJECTS\SupplyCloset\supply-closet\build\app\outputs\flutter-apk\app-debug.apk"
& "C:\Users\Eliud\development\android-sdk\platform-tools\adb.exe" -s ZY22KP4X7C shell am start -n app.supplycloset/.MainActivity
```

---

## 5. Non-Negotiable Guardrails

1. **Zero PHI & On-Device Camera Privacy (`DEC-002`):**
   - Never collect patient information.
   - Camera frames (barcode scanning, AR tracking) must stay strictly on-device and never be uploaded to Firebase or external servers.
2. **Server-Verified Gamification & Concurrency (`DEC-006`):**
   - Never write `xp`, `level`, `badges`, or `role` directly from the Flutter client. All XP goes through the `awardXp` Cloud Function with `supplyId` and `roomId`.
   - Every update to an existing supply document (`tagSupply()`, `reportNotFound()`) must run inside a Firestore transaction and increment `version` by `+1`.
3. **Clinical UX & Text Fallback (`DEC-007`):**
   - Touch targets must be at least **48×48 dp** (glove-friendly) with high-contrast colors for fluorescent supply rooms.
   - Always display plain **Shelf + Bin** text directions so a nurse is never blocked if AR is unavailable or uncalibrated.
4. **Documentation & Roadmap Style:**
   - When updating [`ROADMAP.md`](ROADMAP.md) or status tables, use **simple, easy-to-read terms** inside Markdown tables with `🟢` (Done) and `🔴` (To Do) circle emojis.
5. **Secrets Protection:**
   - Never commit `.env`, `google-services.json`, `GoogleService-Info.plist`, or service account keys.
6. **Shared Firebase Project — Never Deploy Firestore Rules From This Repo:**
   - Firebase project `gen-lang-client-0675309660` is shared with the 3DPrintPosters / 3DPrintYou web app (`E:\PROJECTS\3DPrintPosters`) and the Texas AI Consulting website admin sign-in (`E:\PROJECTS\TexasAI Landing Page`). They share ONE Firestore database `(default)`, so ONE rules file, and one pool of Firebase Auth users.
   - A Firestore rules deploy replaces the whole file for every app. On 2026-11-09 a rules deploy from this repo locked 3DPrintYou customers out of their orders; on 2026-11-23 a 3DPrintPosters-only deploy locked SupplyCloset out. Both were fixed by merging the rules into one shared file.
   - The single source of truth is `E:\PROJECTS\3DPrintPosters\infra\firebase\firestore.rules`. It has a labeled SupplyCloset section. To change SupplyCloset rules, edit that section there, then deploy from `E:\PROJECTS\3DPrintPosters` with `npm run firebase:deploy:firestore-rules:dev`. Mirror the change in `supply-closet/firebase/firestore.rules`, which is now a SupplyCloset-only reference copy.
   - `supply-closet/firebase/firebase.json` deliberately has no `"rules"` entry, so even `firebase deploy` from that folder cannot replace the shared rules. Do not add it back.
   - From this repo, always deploy with `--only functions` (or another explicit `--only` target). Never run a bare `firebase deploy`, `--only firestore`, or `--only firestore:rules`. Deploy indexes only with `--only firestore:indexes` and never with `--force`, which deletes other apps' indexes.
   - Keep this repo's Functions codebase name `default`; 3DPrintPosters uses `api`. Deleting or disabling Firebase Auth users affects every app.
