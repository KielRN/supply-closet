# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Android room setup and Finder can measure the fixed doorframe with ARCore, save bin positions locally and recover them after reopening. Exact Moto G Stylus 5G (2024) support and physical placement accuracy are pending device testing.
- Room-aware sticky feature-point scanner (`supply-closet/lib/services/spatial_room_scanner.dart`) and native Android 3D orientation sensor channel (`supply-closet/android/app/src/main/kotlin/app/supplycloset/MainActivity.kt`) so feature dots progressively appear on real shelf/bin edges and stick to 3D locations in the room (`DEC-014`).
- 3D holographic wireframe bin boxes (`SHELF A · BIN 1`, `BIN 2`, `BIN 3`) with `[AR]` corner lock reticles, `(x, y, z)` coordinate badges, and live camera Finger/Hand-in-Bin ROI detection + direct screen tap support in `RoomInitiationScreen` and `ArFinderScreen` (`DEC-014`).
- Master project roadmap with status tables ([`ROADMAP.md`](ROADMAP.md)).
- Authoritative architectural, product, GTM, and funding decisions log ([`DECISIONS.md`](DECISIONS.md)).
- Root project overview ([`README.md`](README.md)), AI coding instructions ([`AGENT.md`, now `AGENTS.md`](AGENTS.md)), shared agent-agnostic [`skills/`](skills/README.md), and git-ignored `.tmp/` scratch folder.
- SBIR/STTR funding strategy ([`funding-strategy.md`](funding-strategy.md)).
- NSF SBIR Project Pitch draft ([`nsf-project-pitch-draft.md`](nsf-project-pitch-draft.md)).
- Spatial product research for one-room digital twin ("God's Eye View") and shared AR anchors ([`reviews/2026-10-21-spatial-product-research.md`](reviews/2026-10-21-spatial-product-research.md)).
- Real ARCore/ARKit finder session using `ar_flutter_plugin`, with an
  entrance-based `Set Start` and `Recenter` flow for human-defined closet
  origins.
- MVP launch recommendations checklist
  ([`mvp-launch-recommendations-checklist.md`](mvp-launch-recommendations-checklist.md)).
- Smoke tests for gamification level math, tag result classification, and
  new-tag versus confirmation XP.
- Initial project scaffolding (Flutter + Firebase)
- AR-powered supply finder with camera overlay
- Supply tagging flow with barcode scanning (ML Kit)
- Google Sign-In authentication via Firebase Auth
- Firestore-backed supply location database with confidence scoring
- Gamification system: XP, levels, streaks, badges, leaderboards
- Procedure checklists for 20 common nursing procedures
- Cloud Functions: `lookupUdi`, `awardXp`, `decayConfidence`, `syncRecalls`
- Firestore security rules with facility-scoped access control
- Seed data for procedures and supplies

### Changed
- Updated `TagSupplyScreen` (`supply-closet/lib/screens/tag/tag_supply_screen.dart`) to open directly to instant search and glove-friendly 1-tap common supply buttons instead of waiting on the barcode camera (`DEC-011`).
- Updated `ROADMAP.md` and `DECISIONS.md` (`DEC-008`) to center Track 3 on the 3-Layer "God's Eye View" Digital Twin (Point Cloud localization + Clickable 3D Bin Boxes + Gaussian Splat visual layer).
- Reconciled documentation across [`prd.md`](prd.md), [`mvp-launch-recommendations-checklist.md`](mvp-launch-recommendations-checklist.md), and [`supply-closet/SETUP.md`](supply-closet/SETUP.md); removed unused `graphify-out/` artifacts.
- Supply tagging now returns the tagged supply id and whether the write created
  a new supply or confirmed an existing one.
- XP awarding now passes `supplyId` and `roomId` through the client and Cloud
  Function verifier, avoiding ambiguous recent-tag scans for normal tagging.
- Existing supply confirmations now award `confirmExisting` XP instead of
  always being treated as new tags.
- Replaced deprecated Flutter color opacity calls with `withValues`.
- Renamed `AGENT.md` to the standard [`AGENTS.md`](AGENTS.md), the file name AI coding agents load automatically, and updated all links. This is the only agent instructions file (`DEC-010` update).

### Fixed
- `reportNotFound()` now increments supply `version` in a transaction so it
  satisfies the optimistic concurrency Firestore rule.

### Security
- Firestore rules now deploy only from the shared file `E:\PROJECTS\3DPrintPosters\infra\firebase\firestore.rules`. Firebase project `gen-lang-client-0675309660` is shared with the 3DPrintPosters / 3DPrintYou web app, so a rules deploy from this repo on 2026-11-09 had replaced that app's rules. The merged file keeps the SupplyCloset rules unchanged and was verified with 44 Rules test API scenarios. Removed the `"rules"` entry from `supply-closet/firebase/firebase.json` so deploys from this repo can no longer replace the shared rules, and changed the rules-deploy steps in `HANDOFF.md` and `supply-closet/SETUP.md` to point to 3DPrintPosters. Agent guardrails added to [`AGENTS.md`](AGENTS.md) and [`skills/firebase-backend-rules/SKILL.md`](skills/firebase-backend-rules/SKILL.md) (`DEC-015`).
- Remediated all 21/21 findings from the April 2026 adversarial security review (locked user role creation, added server-side XP action verification, rate-limited callable Cloud Functions, enforced optimistic concurrency version checks, and secured `healthCheck`). See [`DECISIONS.md`](DECISIONS.md) (`DEC-006`).

## [0.1.0] - 2026-04-16

### Added
- Project inception and initial documentation
- Product Requirements Document ([`prd.md`](prd.md))
- Technical Architecture Document ([`tech-architecture.md`](tech-architecture.md))
- Data Strategy Document ([`data-strategy.md`](data-strategy.md))
- Branding Brief ([`branding-brief.md`](branding-brief.md))
- Market Research ([`market-research.md`](market-research.md))
- Consumer-Wedge GTM Strategy ([`consumer-wedge-gtm.md`](consumer-wedge-gtm.md))
