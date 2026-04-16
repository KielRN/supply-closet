# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
