# SupplyCloset (`supplycloset.app`)

> **"Never hunt for supplies again."**  
> A nurse-first mobile app that combines procedure supply checklists, crowdsourced shelf/bin locations, barcode scanning, and AR guidance so hospital nurses can find what they need in seconds.

**Owner:** Texas AI Consulting, LLC (SDVOSB)  
**Primary Trackers:** [ROADMAP.md](ROADMAP.md) · [DECISIONS.md](DECISIONS.md) · [CHANGELOG.md](CHANGELOG.md) · [AGENT.md](AGENT.md)

---

## Why SupplyCloset Exists

Hospital nurses lose up to **60 minutes per shift** hunting for supplies in disorganized unit supply rooms whose layouts change from floor to floor. Travel nurses, float-pool RNs, and new hires feel this pain on every shift.

SupplyCloset solves this without requiring hospitals to install RFID hardware, beacons, or IT integrations:
1. **Pick a Procedure:** Choose from 20 common nursing procedures (IV start, Foley catheter, wound care, etc.) to get an instant supply checklist.
2. **Find Every Item:** See the exact **Shelf + Bin** location on your unit—with optional doorway-initialized AR camera guidance and a planned 3D room overview.
3. **Tag & Confirm in Seconds:** Scan a barcode or tap to confirm an item is still in its bin, earning XP, shift streaks, and unit leaderboard ranks while keeping the map fresh for the next nurse.

---

## Project Snapshot

| Area | Status | Details |
| :---: | :---: | :--- |
| **Flutter Mobile App** | 🟢 | Auth, 20 procedures, ~200 seeded supplies, quick-search + 1-tap tagging, gamification, and AR finder session built (`supply-closet/`) |
| **Firebase Backend** | 🟢 | Firestore security rules (21/21 audit fixes complete) + Cloud Functions (`lookupUdi`, `awardXp`, `decayConfidence`, `syncRecalls`) |
| **"God's Eye View" 3D Twin** | 🔴 | Next spatial milestone: 3-layer room model (Point Cloud anchors + Clickable 3D Bin Boxes + Gaussian Splat visual layer) for 1 room (30–50 items) |
| **NSF SBIR Phase I Pitch** | 🔴 | Funding strategy and Project Pitch drafted (`nsf-project-pitch-draft.md`); pending IP/policy check and submission |

See [ROADMAP.md](ROADMAP.md) for the complete status table.

---

## Repository Structure

```text
SupplyCloset/
├── README.md                                 # Project overview and doc index (you are here)
├── ROADMAP.md                                # Master roadmap with 🟢/🔴 status tables
├── DECISIONS.md                              # Product, technical, GTM, and funding decision log
├── AGENT.md                                  # Instructions and guardrails for AI coding agents
├── CHANGELOG.md                              # Release and milestone history
├── skills/                                   # Shared AI-agent-agnostic skills (SKILL.md format)
├── .tmp/                                     # Git-ignored scratch folder for temporary scripts/files
├── supply-closet/                            # Flutter mobile app & Firebase backend
│   ├── lib/                                  # Dart source (models, providers, screens, services, widgets)
│   ├── test/                                 # Flutter unit and smoke tests
│   ├── assets/data/                          # Seeded procedures (JSON) and supplies catalog (CSV)
│   ├── firebase/                             # Firestore security rules, indexes, and Cloud Functions
│   ├── README.md                             # Android device & build quickstart
│   └── SETUP.md                              # Full local + GCP/Firebase deployment guide
└── reviews/
    └── 2026-10-21-spatial-product-research.md # "God's Eye View" 3D room & AR localization research
```

---

## Documentation Index

| Document | Purpose |
| :--- | :--- |
| **[ROADMAP.md](ROADMAP.md)** | Current status (`🟢` / `🔴`) across app, launch, spatial/AR, GTM, and SBIR funding tracks |
| **[DECISIONS.md](DECISIONS.md)** | Authoritative log reconciling product, architecture, security, GTM, and grant decisions |
| **[AGENT.md](AGENT.md)** | Workspace instructions, commands, and safety invariants for AI assistants |
| **[prd.md](prd.md)** | Original Product Requirements Document (user flows, personas, gamification design) |
| **[consumer-wedge-gtm.md](consumer-wedge-gtm.md)** | Faster-to-revenue B2C → PLG rollout plan starting with travel nurses ($4.99/mo) |
| **[tech-architecture.md](tech-architecture.md)** | Mobile, Firebase, and GCP system architecture |
| **[data-strategy.md](data-strategy.md)** | Cold-start solution using FDA GUDID, openFDA, procedure kits, and "Founding Tagger" mechanics |
| **[branding-brief.md](branding-brief.md)** | Brand voice, color palette, typography, and clinical UX principles (30-second & glove-friendly rules) |
| **[market-research.md](market-research.md)** | TAM/SAM/SOM sizing, competitive landscape, and vendor data monetization model |
| **[mvp-launch-recommendations-checklist.md](mvp-launch-recommendations-checklist.md)** | Pre-launch engineering & positioning checklist |
| **[reviews/2026-10-21-spatial-product-research.md](reviews/2026-10-21-spatial-product-research.md)** | Architecture plan for the one-room digital twin ("God's Eye View") and shared AR anchors |
| **[funding-strategy.md](funding-strategy.md)** | Non-dilutive SBIR/STTR funding roadmap (NSF, NIH, DoD) |
| **[nsf-project-pitch-draft.md](nsf-project-pitch-draft.md)** | Ready-to-review NSF SBIR Phase I Project Pitch |

---

## Quickstart (Development)

Full setup instructions live in [supply-closet/SETUP.md](supply-closet/SETUP.md) and [supply-closet/README.md](supply-closet/README.md).

```powershell
# 1. Run Flutter static analysis and unit tests
cd supply-closet
flutter analyze
flutter test

# 2. Lint Firebase Cloud Functions
npm --prefix firebase/functions run lint

# 3. Build a debug APK or run on a connected Android phone
flutter build apk --debug
flutter run -d <device-id>
```

---

## Privacy & Security Highlights

- **Zero PHI:** SupplyCloset never collects patient data or connects to hospital EHRs.
- **On-Device Camera Processing:** Camera frames used for barcode scanning and AR tracking stay on the phone and are never uploaded.
- **Server-Verified Gamification:** XP, levels, and badges are validated server-side via Cloud Functions (`awardXp`), and Firestore security rules enforce facility scoping and optimistic concurrency (`version` checks).
