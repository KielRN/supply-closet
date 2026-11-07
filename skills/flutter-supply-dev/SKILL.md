---
name: flutter-supply-dev
description: Guidelines and workflow for building or modifying Flutter UI, state providers, barcode scanning, and AR finder features in supply-closet/lib/.
---

# Flutter SupplyCloset Development Skill

Use this skill whenever you are adding features, fixing bugs, or updating UI in `supply-closet/lib/` or `supply-closet/test/`.

## 1. Clinical UX & Design Rules (Non-Negotiable)

From [`branding-brief.md`](../../branding-brief.md) and [`DECISIONS.md`](../../DECISIONS.md):
- **30-Second / 3-Tap Rule:** Nurses use the app mid-shift. Keep core flows (`Find` and `Tag`) under 30 seconds and minimal taps.
- **Glove-Friendly Targets:** Every interactive button or tap target must be at least **48×48 dp**.
- **Fluorescent-Proof Contrast:** Primary Teal (`#0D9488`), Warm White (`#FAFAF8`), Charcoal text (`#1E293B`), Sage Green confirmation (`#6EE7B7`), Amber warning (`#FBBF24`). Minimum 16px body text.
- **Text Fallback Always Visible:** Never block a nurse waiting on AR initialization or camera tracking. Always display plain `Shelf` and `Bin` text directions alongside or in place of AR overlays.
- **On-Device Camera Only:** Camera frames (ML Kit barcode scanning, ARCore/ARKit) must never be uploaded to a server.

## 2. Data & Gamification Invariants

1. **Optimistic Concurrency (`version`):**
   - Any Firestore write that updates an existing supply document (`tagSupply()`, `reportNotFound()`) **must** run inside a Firestore transaction and increment `version` by exactly `+1`.
2. **Tag Result Classification (`TagSupplyResult`):**
   - `tagSupply()` returns `TagSupplyResult` containing `supplyId` and `isNewSupply`.
   - Pass `supplyId` and `roomId` into `GamificationProvider.recordAction()`.
   - Award `GameAction.tagNew` (+10 XP) **only** when `isNewSupply == true`; award `GameAction.confirmExisting` (+5 XP) when confirming an existing item.
3. **Never Write XP Directly from Client:**
   - XP, level, and badge updates must go through the `awardXp` callable Cloud Function via `GamificationService`.

## 3. Verification Checklist

Always run from `supply-closet/` before finishing a task:

```powershell
cd supply-closet
flutter analyze --no-pub
flutter test --no-pub
```

Use the root `.tmp/` folder (git-ignored) if you need temporary test payloads or scratch scripts.
