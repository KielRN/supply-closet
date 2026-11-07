# Shared AI Agent Skills (`skills/`)

This directory contains **AI-agent-agnostic skills** for the SupplyCloset repository. Each skill lives in its own subfolder with a standard `SKILL.md` file (YAML frontmatter + Markdown instructions) so it works across any agentic coding tool (Antigravity, Claude Code, Cursor, OpenAI Codex, Windsurf, GitHub Copilot, etc.).

## Available Skills

| Skill | Path | When to Use |
| :--- | :--- | :--- |
| **flutter-supply-dev** | [`flutter-supply-dev/SKILL.md`](flutter-supply-dev/SKILL.md) | Building or editing Flutter screens, providers, barcode scanning, or AR finder flows in `supply-closet/lib/` |
| **firebase-backend-rules** | [`firebase-backend-rules/SKILL.md`](firebase-backend-rules/SKILL.md) | Modifying `firestore.rules`, Firestore data models, or Cloud Functions in `supply-closet/firebase/` |
| **docs-and-roadmap-sync** | [`docs-and-roadmap-sync/SKILL.md`](docs-and-roadmap-sync/SKILL.md) | Updating `ROADMAP.md`, `DECISIONS.md`, `CHANGELOG.md`, or reconciling project documentation |

## Adding a New Skill

1. Create a folder `skills/<skill-name>/`.
2. Add a `SKILL.md` file starting with YAML frontmatter:
   ```markdown
   ---
   name: <skill-name>
   description: One-sentence description of what this skill does and when an agent should load it.
   ---
   ```
3. Keep instructions concise, tool-agnostic, and grounded in concrete repository paths and commands.
4. Register the new skill in this `skills/README.md` and in [`../AGENT.md`](../AGENT.md).
