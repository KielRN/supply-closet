---
name: docs-and-roadmap-sync
description: Conventions for updating ROADMAP.md, DECISIONS.md, CHANGELOG.md, and keeping project documentation reconciled.
---

# Documentation & Roadmap Sync Skill

Use this skill whenever completing a milestone, making an architectural/product decision, or reconciling project documents.

## 1. Roadmap Formatting (`ROADMAP.md`)

- **Use Tables:** Organize roadmap items in clean Markdown tables.
- **Simple Terms:** Write descriptions in plain, everyday English—avoid dense jargon.
- **Status Emojis:** Always use circle emojis in the `Status` column:
  - `🟢` = Done / Complete
  - `🔴` = To Do / Next
- Keep the **Top Priorities Right Now** table at the top of [`ROADMAP.md`](../../ROADMAP.md) aligned with the detailed track tables below it.

## 2. Decisions Log (`DECISIONS.md`)

- Whenever a technical, product, GTM, or funding choice overrides or refines an earlier document (such as `prd.md` or `tech-architecture.md`), add or update an entry (`DEC-XXX`) in [`DECISIONS.md`](../../DECISIONS.md).
- Include the status emoji (`🟢` Decided / `🔴` Open Action) in the summary table at the top of `DECISIONS.md`.

## 3. Changelog (`CHANGELOG.md`)

- Follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) under `## [Unreleased]`.
- Group changes under `### Added`, `### Changed`, `### Fixed`, or `### Security`.
- Verify all markdown file links resolve to existing files in the repository.
