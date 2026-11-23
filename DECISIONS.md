# SupplyCloset — Decisions Log

**Last Updated:** November 23, 2026  
**Related Docs:** [ROADMAP.md](ROADMAP.md) · [README.md](README.md) · [AGENTS.md](AGENTS.md)

This document is the single source of truth for major product, technical, commercial, and funding decisions. When earlier documents (such as the original April 2026 [PRD](prd.md) or [Technical Architecture](tech-architecture.md)) differ from newer strategy docs, the decisions recorded here govern.

**Status Key:** 🟢 Active / Decided · 🔴 Open Action Required

---

## Summary Table

| Status | ID | Date | Decision | Short Summary |
| :---: | :--- | :--- | :--- | :--- |
| 🟢 | **DEC-001** | 2026-04-12 | **Flutter + Firebase Stack** | One Flutter codebase (iOS/Android) backed by Firebase Auth, Firestore, and Cloud Functions on GCP |
| 🟢 | **DEC-002** | 2026-04-12 | **Zero PHI & On-Device Camera Privacy** | Never collect patient info; camera frames stay on the phone and are never uploaded |
| 🟢 | **DEC-003** | 2026-04-13 | **3-Layer Cold-Start Data Plan** | Pre-seed 200 FDA GUDID supplies + 20 procedure kits; nurses crowdsource local shelf/bin spots |
| 🟢 | **DEC-004** | 2026-04-14 | **Parent Company: Texas AI Consulting, LLC** | SupplyCloset is built and owned under Texas AI Consulting, LLC (SDVOSB, SAM UEI `LE9JXUK4C3P3`) |
| 🟢 | **DEC-005** | 2026-04-16 | **Consumer-Wedge GTM Before Enterprise** | Ship text + checklist app directly to travel nurses ($4.99/mo) first instead of waiting on slow hospital sales |
| 🟢 | **DEC-006** | 2026-04-20 | **Server-Verified XP & Safe Writes** | All XP/badges are verified by Cloud Functions; Firestore rules block role tampering and require version checks |
| 🟢 | **DEC-007** | 2026-04-24 | **Hardware-Free Doorway AR Origin** | No QR codes, beacons, or RFID tags required; AR initializes from the supply room doorway (`Set Start`) |
| 🟢 | **DEC-008** | 2026-10-21 | **3-Layer "God's Eye View" Digital Twin** | Combine Point Clouds (phone localization), Clickable 3D Bin Boxes (search/fly-to), and Gaussian Splats (visual layer) in one room first |
| 🟢 | **DEC-009** | 2026-11-07 | **NSF SBIR Phase I for Spatial R&D** | Apply for ~$305K non-dilutive NSF SBIR funding to pay for hard AR/CV research; Elliott becomes full-time PI upon award |
| 🟢 | **DEC-010** | 2026-11-07 | **Drop Graphify & Standardize Repo** | Removed `graphify-out`; standardized on `ROADMAP.md`, `DECISIONS.md`, `AGENT.md` (renamed `AGENTS.md` 2026-11-23), git-ignored `.tmp/`, and `skills/` |
| 🟢 | **DEC-011** | 2026-11-07 | **Quick Search + Bin OCR Over Package Barcodes** | Default tagging to instant search / 1-tap chips instead of package barcode scanning; reserve camera for Bin Label OCR and 3D room capture |
| 🟢 | **DEC-015** | 2026-11-23 | **Shared Firebase Project: One Firestore Rules File** | `gen-lang-client-0675309660` is shared with the 3DPrintPosters / 3DPrintYou web app; Firestore rules live and deploy only from `E:\PROJECTS\3DPrintPosters\infra\firebase\firestore.rules`, never from this repo |
| 🔴 | **OPEN-001** | 2026-11-07 | **Phase I Pilot Site & Advisors** | Select nursing simulation lab / unit partner and CV + nursing advisors for the NSF pitch and proposal |

---

## Detailed Decision Records

### DEC-001: Flutter + Firebase Serverless Stack
- **Date:** April 12, 2026
- **Status:** 🟢 Active
- **Context:** Needed a cross-platform mobile client for iOS and Android with real-time unit sync and low operational overhead.
- **Decision:** Build the mobile client in Flutter (`supply-closet/`) and use Firebase (Google Sign-In Auth, Cloud Firestore, Cloud Functions in Node.js) hosted on GCP (`gen-lang-client-0675309660`).
- **Docs Reconciled:** [tech-architecture.md](tech-architecture.md) mentioned "Flutter / React Native"; Flutter is the chosen and implemented framework.

### DEC-002: Strictly Zero-PHI & On-Device Camera Processing
- **Date:** April 12, 2026
- **Status:** 🟢 Active
- **Context:** Hospital IT and HIPAA/BAA reviews take 6–18 months if an app touches Protected Health Information (PHI) or uploads video inside a clinical facility.
- **Decision:** SupplyCloset collects **zero patient data**. Camera frames are processed strictly on-device (ARCore, ARKit, ML Kit) and immediately discarded. Only supply catalog metadata, shelf/bin locations, and timestamps are stored in Firestore.
- **Note on Third-Party VPS:** As noted in [reviews/2026-10-21-spatial-product-research.md](reviews/2026-10-21-spatial-product-research.md), some cloud Visual Positioning Systems (like MultiSet WebXR) send camera frames to their cloud. Any cloud-frame VPS may only be tested in non-clinical mock rooms unless privacy guarantees are explicitly updated.

### DEC-003: Three-Layer Data Bootstrap Strategy
- **Date:** April 13, 2026
- **Status:** 🟢 Active
- **Context:** Nurses will abandon an app if it opens to an empty database on Day 1.
- **Decision:** Solve cold-start in three layers:
  1. **Universal Catalog:** Pre-seed ~200 common supplies (`assets/data/seed_supplies.csv`) backed by live FDA GUDID barcode lookups (`lookupUdi` Cloud Function).
  2. **Procedure Checklists:** Pre-seed 20 common nursing procedures (`assets/data/seed_procedures.json`).
  3. **Hyper-Local Locations:** Crowdsource unit-specific shelf and bin locations from nurses using gamification ("Founding Tagger" bonuses and confirmation points).
- **Docs Reconciled:** [data-strategy.md](data-strategy.md).

### DEC-004: Corporate Entity — Texas AI Consulting, LLC
- **Date:** April 14, 2026 (reconfirmed November 7, 2026)
- **Status:** 🟢 Active
- **Context:** Early product documents referred generically to the "SupplyCloset founding team."
- **Decision:** SupplyCloset is developed and owned by **Texas AI Consulting, LLC** (San Antonio, TX), a Service-Disabled Veteran-Owned Small Business (SDVOSB) registered in SAM.gov (`UEI: LE9JXUK4C3P3`), founded by Eliud ("Elliott") Lamboy.
- **Docs Reconciled:** [funding-strategy.md](funding-strategy.md), [nsf-project-pitch-draft.md](nsf-project-pitch-draft.md).

### DEC-005: Dual-Track Strategy — Consumer Wedge (v1) + SBIR Spatial R&D (v2)
- **Date:** April 16, 2026 & November 7, 2026
- **Status:** 🟢 Active
- **Context:** Original [prd.md](prd.md) put full AR shelf overlays on the critical path for MVP and targeted hospital enterprise sales first. Both create long delays before revenue.
- **Decision:** Run two complementary tracks:
  1. **Commercial Track ([consumer-wedge-gtm.md](consumer-wedge-gtm.md)):** Ship fast to individual travel/float/new-grad nurses ($4.99/mo) using procedure checklists, barcode tagging, and **plain-text shelf/bin locations**. Use unit density (5+ nurses on a floor) to pull unit subscriptions ($49/mo) and hospital facility deals ($25k–$75k/yr).
  2. **R&D Track ([funding-strategy.md](funding-strategy.md)):** Use non-dilutive federal SBIR funding to pay for the hard AR/computer-vision bin-level relocalization research without blocking the v1 commercial launch.
- **Docs Reconciled:** Reconciles [prd.md](prd.md) (Phase 1 AR) with [consumer-wedge-gtm.md](consumer-wedge-gtm.md) and [funding-strategy.md](funding-strategy.md).

### DEC-006: Server-Authoritative Gamification & Optimistic Concurrency
- **Date:** April 20–24, 2026
- **Status:** 🟢 Active
- **Context:** An internal adversarial security review identified 21 vulnerabilities, including client-side XP farming, role escalation on user creation, and lost updates when two users edited a supply simultaneously.
- **Decision:** All 21 findings were fixed in code and rules:
  - Clients cannot write XP, levels, or badges directly; only the `awardXp` Cloud Function can award points after verifying the underlying supply tag/confirmation in a specific `roomId`.
  - User creation locks `role == "nurse"` and `xp == 0` in `firestore.rules`.
  - Supply updates (`tagSupply`, `reportNotFound`) must run in a Firestore transaction and increment `version` by `+1`.
  - Existing supply confirmations award `confirmExisting` XP (+5) rather than `tagNew` XP (+10).
- **Docs Reconciled:** Historical references to `adversarial-review.md` and `remediation-plan.md` in [CHANGELOG.md](CHANGELOG.md) and [supply-closet/SETUP.md](supply-closet/SETUP.md) are superseded by this completed remediation record.

### DEC-007: Hardware-Free Doorway "Set Start" Origin for MVP AR
- **Date:** April 24, 2026
- **Status:** 🟢 Active
- **Context:** Requiring hospitals to print and stick QR codes, AprilTags, or Bluetooth beacons inside supply closets creates adoption friction and institutional pushback.
- **Decision:** Keep SupplyCloset 100% hardware-free. For AR mode, nurses stand at the supply closet entrance threshold and tap `Set Start` (or `Recenter`) to initialize the local coordinate origin, with plain shelf/bin text always visible as a fallback.
- **Docs Reconciled:** [mvp-launch-recommendations-checklist.md](mvp-launch-recommendations-checklist.md).

### DEC-008: 3-Layer "God's Eye View" Digital Twin Architecture
- **Date:** October 21, 2026 (refined November 7, 2026)
- **Status:** 🟢 Active
- **Context:** Evaluated how to achieve an interactive "God's Eye View" room experience (inspired by `bilawalsidhu/gods-eye-view`) using 3D Gaussian Splatting (3DGS), Point Clouds, and clickable 3D room geometry alongside phone AR guidance.
- **Decision:** Combine three complementary spatial layers from a single room scan, backed by one shared Firestore data model (`Facility -> Unit -> Room -> Map Revision -> Shelf -> Bin <- Placement <- SKU`):
  1. **Layer 1 — Point Cloud & Anchors (Phone Localization):** Use point-cloud anchors (Google Cloud Anchors / MultiSet VPS + doorway origin) so any phone entering the closet resolves the same 3D coordinate frame.
  2. **Layer 2 — Clickable 3D Bin Boxes ("God's Eye View" Interaction):** Use clean 3D shelf/bin volumes (Three.js companion viewer + mobile view) so searching an item or picking a procedure smoothly flies the camera straight to the glowing bins and shows confidence + freshness.
  3. **Layer 3 — Gaussian Splat Overlay (Photorealistic Visual Layer):** Layer a 3D Gaussian Splat capture over the clickable bin geometry so users can toggle between a fast schematic view and photorealistic 3D shelf inspection.
- **Docs Reconciled:** [reviews/2026-10-21-spatial-product-research.md](reviews/2026-10-21-spatial-product-research.md), [ROADMAP.md](ROADMAP.md).

### DEC-009: Pursue NSF SBIR Phase I & PI Full-Time Transition Plan
- **Date:** November 7, 2026
- **Status:** 🟢 Active
- **Context:** SBIR/STTR was reauthorized through 2031 (S. 3971), and NSF 26-510 is open with a March 4, 2027 full-proposal deadline. NSF requires the Principal Investigator (PI) to be primarily employed (>50%) by the small business **at the time of award**.
- **Decision:** Target **NSF SBIR Phase I** (~$305,000) first, starting with the Project Pitch ([nsf-project-pitch-draft.md](nsf-project-pitch-draft.md)). Upon winning an SBIR award, Eliud ("Elliott") Lamboy will transition to full-time employment at Texas AI Consulting, LLC to serve as PI.
- **Docs Reconciled:** [funding-strategy.md](funding-strategy.md), [nsf-project-pitch-draft.md](nsf-project-pitch-draft.md).

### DEC-010: Remove Graphify & Standardize Repository Conventions
- **Date:** November 7, 2026
- **Status:** 🟢 Active
- **Context:** `graphify-out/` added large generated cache files that were not needed for this project, and the repo lacked root-level orientation docs (`README.md`, `ROADMAP.md`, `DECISIONS.md`, `AGENT.md`) and shared agent skills.
- **Decision:** Delete `graphify-out/`, git-ignore `.tmp/` for scratch work, maintain a shared AI-agent-agnostic `skills/` folder at the repository root, and keep `ROADMAP.md` and `DECISIONS.md` updated as the primary project trackers.
- **Update (2026-11-23):** `AGENT.md` was renamed to the standard `AGENTS.md`, the file name AI coding agents load automatically. There is only one agent instructions file; do not recreate `AGENT.md`.

### DEC-011: Default to Quick Search & 1-Tap Tagging (Move Package Barcodes Off Critical Path)
- **Date:** November 7, 2026
- **Status:** 🟢 Active
- **Context:** Individual medical supply peel-pouches have tiny, crinkled barcodes that glare under fluorescent lighting, and hospital bin barcodes are typically internal ERP codes rather than FDA GUDID barcodes. Opening the camera first on Step 1 of tagging slowed nurses down and violated the 30-second / 3-tap design rule.
- **Decision:** Default `TagSupplyScreen` (`supply-closet/lib/screens/tag/tag_supply_screen.dart`) directly to **Quick Search + 1-Tap Common Supply buttons**. Keep camera scanning optional and focus future camera computer-vision work on **on-device printed bin-label OCR** and **3D room capture**, aligning directly with [nsf-project-pitch-draft.md](nsf-project-pitch-draft.md).

### DEC-015: Shared Firebase Project — One Firestore Rules File, Deployed Only From 3DPrintPosters
- **Date:** November 23, 2026
- **Status:** 🟢 Active
- **Context:** Firebase project `gen-lang-client-0675309660` (see DEC-001) also hosts the 3DPrintPosters / 3DPrintYou web app and the Texas AI Consulting website admin sign-in. They share one Firestore database `(default)`, which can have only ONE rules file, and one pool of Firebase Auth users. On 2026-11-09 a rules deploy from this repo replaced the 3DPrintPosters rules and locked 3DPrintYou customers out of their orders. On 2026-11-23 a 3DPrintPosters-only redeploy locked SupplyCloset out.
- **Decision:**
  1. The single deployed rules file is `E:\PROJECTS\3DPrintPosters\infra\firebase\firestore.rules`. It contains the SupplyCloset rules unchanged in a labeled section, plus the shared `users/{userId}` block, which uses SupplyCloset's rule (DEC-006 invariants still apply).
  2. Firestore rules are deployed only from `E:\PROJECTS\3DPrintPosters` (`npm run firebase:deploy:firestore-rules:dev`). Never run a bare `firebase deploy`, `--only firestore`, or `--only firestore:rules` from `supply-closet/firebase/`. Use `--only functions` for Cloud Functions and `--only firestore:indexes` (never `--force`) for indexes.
  3. `supply-closet/firebase/firebase.json` has no `"rules"` entry (removed 2026-11-23), so a deploy from this repo skips rules. Dry runs of `--only firestore:rules` and `--only firestore` from that folder read only indexes. `supply-closet/firebase/firestore.rules` is a SupplyCloset-only reference copy. Change SupplyCloset rules in the shared file first, then mirror the change here.
  4. Keep this repo's Functions codebase `default` (3DPrintPosters uses `api`). Deleting or disabling Firebase Auth users affects every app.
- **Verified:** The merged rules were tested with the Firebase Rules test API (44 scenarios). SupplyCloset results match its own rules exactly, 3DPrintYou results match its rules, and cross-app access is blocked. Deployed as ruleset `6d014542-50c0-44d2-b498-5420695c189b` (3DPrintPosters commit `c3cbe79`).
- **Docs Reconciled:** [AGENTS.md](AGENTS.md) (guardrail 6), [skills/firebase-backend-rules/SKILL.md](skills/firebase-backend-rules/SKILL.md) (section 0).
