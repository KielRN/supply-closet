# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
- Adversarial security review ([`adversarial-review.md`](adversarial-review.md))
- Remediation plan checklist ([`remediation-plan.md`](remediation-plan.md))

### Changed
- Supply tagging now returns the tagged supply id and whether the write created
  a new supply or confirmed an existing one.
- XP awarding now passes `supplyId` and `roomId` through the client and Cloud
  Function verifier, avoiding ambiguous recent-tag scans for normal tagging.
- Existing supply confirmations now award `confirmExisting` XP instead of
  always being treated as new tags.
- Replaced deprecated Flutter color opacity calls with `withValues`.

### Fixed
- `reportNotFound()` now increments supply `version` in a transaction so it
  satisfies the optimistic concurrency Firestore rule.

### Security
- Identified role escalation vulnerability in Firestore user creation rules
- Identified XP farming exploit due to missing server-side action verification
- Identified missing rate limiting on callable Cloud Functions
- Identified unauthenticated `healthCheck` endpoint
- See [`adversarial-review.md`](adversarial-review.md) for full findings

## [0.1.0] - 2026-04-16

### Added
- Project inception and initial documentation
- Product Requirements Document ([`prd.md`](prd.md))
- Technical Architecture Document ([`tech-architecture.md`](tech-architecture.md))
- Data Strategy Document ([`data-strategy.md`](data-strategy.md))
- Branding Brief ([`branding-brief.md`](branding-brief.md))
- Market Research ([`market-research.md`](market-research.md))
