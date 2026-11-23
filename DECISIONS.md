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
| 🟢 | **DEC-012** | 2026-11-08 | **Room Initiation Scan, Gaming HUD & Supply Bounties** | Unmapped rooms start with a +250 XP doorway scan (Gaussian Splat + 3D Shelf Racks); Finder uses a Gaming AR HUD + 3D Splat toggle; nurses can post +50 XP Supply Bounties for untagged items |
| 🟢 | **DEC-013** | 2026-11-09 | **Multi-Room Unit Hierarchy, Avatars & Room Captain Hints** | Units (`Med 3A`, `Med 3B`) support multiple supply rooms (`Add Room` in Tag & Settings, switch rooms in HUD, future Door Sign OCR); users customize Display Name + Avatar/Photo; top room tagger becomes **Room Captain (+150 XP Trophy)** and can pin spatial **Captain Hints** in the room |
| 🟢 | **DEC-014** | 2026-11-16 | **Room-Aware Sticky Feature Dots & Finger-in-Bin Detection** | Replaced static 2D scan overlay with on-device corner/edge feature extraction (`CameraImage` YUV420 stream), native Android 3D orientation sensors (`Sensor.TYPE_GAME_ROTATION_VECTOR`), triangulation mesh, and 3D Bin Box finger/hand-in-bin + touch read |
| 🟢 | **DEC-015** | 2026-11-23 | **Firebase Rules Ownership Restored (3DPrintYou Migrated)** | 3DPrintPosters / 3DPrintYou migrated off `gen-lang-client-0675309660` to dedicated `app-3dprintyou` on 2026-11-23; SupplyCloset again owns and deploys `supply-closet/firebase/firestore.rules` directly |
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

### DEC-012: Room Initiation Scan (+250 XP), Gaming Navigation HUD & User-Initiated Supply Bounties
- **Date:** November 8, 2026
- **Status:** 🟢 Active
- **Context:** Initial phone testing on the Moto G Stylus 5G (2024) showed that tagging a single supply with `(0,0,0)` coordinates into an unmapped room made the Finder screen unhelpful. Nurses need spatial room context, clear gaming-style directional indicators, and a way to request untagged supplies.
- **Decision:**
  1. **Room Initiation (+250 XP):** If a supply room is not yet initiated in Firestore, prompt a 3-step doorway scan (`RoomInitiationScreen`) that captures the Gaussian Splat / point cloud preview, pins 3D Shelf Racks (`Shelf A`, `Shelf B`, `Shelf C`), and awards **+250 XP** (`initiateRoom`) + the `room_pioneer` badge.
  2. **Gaming Spatial Finder (`ArFinderScreen`):** Combine an interactive **3D Gaussian Splat "God's Eye View"** (click-to-fly camera + layer toggles) with a **First-Person Gaming AR HUD** (Compass Ribbon, Top-Right Mini-Radar, 360° Off-Screen Edge Turn Chevrons, 3D Floor Path Chevrons, and Target Lock Diamond).
  3. **User-Initiated Supply Bounties (+50 Bonus XP):** When a nurse needs an important supply that hasn't been tagged yet (or is missing from its bin), she can post a **Supply Bounty** (`BountyBoardSheet`). Another nurse ("Bounty Hunter") who locates and tags that supply earns **+50 Bonus XP** (`claimBounty`) + the `bounty_hunter` badge.

### DEC-013: Multi-Room Floor Hierarchy (`Med 3A`), Custom Avatars & Room Captain Spatial Hints
- **Date:** November 9, 2026
- **Status:** 🟢 Active
- **Context:** Nurses and nursing assistants work on hospital floors/wings (e.g., `Med 3A`, `Med 3B`) that typically have **multiple supply rooms** (clean utility rooms, north/south alcoves, overflow closets). Hardcoding a single `main` room prevents switching or adding rooms on a floor. Additionally, social identity (Display Name + Avatar/Photo) powers a new **Room Captain** mechanic.
- **Decision:**
  1. **Multi-Room Unit Model (`Facility -> Unit [e.g. Med 3A] -> Supply Rooms [Room 1, Room 2...]`):**
     - Nurses can **add new Supply Rooms** directly from the **Tag** screen header and from **Profile / Settings** (which lists all rooms on their unit).
     - Nurses can **switch the active Supply Room** directly inside the **Finder HUD** (`ArFinderScreen`) and **Tag** screen (`RoomProvider`).
     - **Future Feature (Roadmap):** Add **Door Sign OCR Scanner** so pointing the camera at a hospital room door plaque (e.g., `3A-102 CLEAN SUPPLY`) auto-selects or creates that supply room.
  2. **Custom Display Name, Pre-Generated Avatars & Photo Upload:**
     - Allow users to edit their public **Display Name**, choose from **pre-generated clinical/gaming avatars**, or upload a custom profile photo in `ProfileScreen` (and persist manual edits so `AuthService` does not overwrite them on login).
  3. **Room Captain (+150 XP Trophy) & Spatial Captain Hints:**
     - The user who has tagged the most supplies in a specific Supply Room automatically becomes that room's **Room Captain** (`captainUid`, `captainName`, `captainAvatar`, `captainTagCount`), earning the **Room Captain Trophy/Medal (`room_captain`, +150 XP)**.
     - The **Room Captain** can place **Spatial Captain Hints** (`hints` subcollection or array on `SupplyRoom`) anchored to a point/shelf in the room.
     - All users viewing that room in the **3D Gaussian Splat** or **Gaming AR HUD** see the **Captain Hint** beacon displaying the **Captain's Avatar, Display Name, and Tip**.


### DEC-014: Room-Aware Sticky Feature Point Cloud & Finger-in-Bin Camera Read
- **Date:** November 16, 2026
- **Status:** 🟢 Active
- **Context:** During on-device phone testing (`Moto G Stylus 5G - 2024`), the initial room scanner felt unaware of the physical room because feature points were drawn at static screen coordinates and the 3D bin boxes did not respond when the user placed their finger in the bin area in front of the camera.
- **Decision:**
  1. **Native 3D Orientation Sensor Stream (`MainActivity.kt`):** Stream hardware `TYPE_GAME_ROTATION_VECTOR` / `TYPE_ROTATION_VECTOR` / `TYPE_GYROSCOPE` orientation (`yawDeg`, `pitchDeg`, `angularSpeed`) over `app.supplycloset/spatial_sensors` so turning or tilting the phone moves the 3D AR room frame in real time.
  2. **Progressive Sticky Feature Points (`SpatialRoomScannerEngine`):** Start scans at 0 points and analyze live on-device `CameraImage` luminance frames (`startImageStream`) for real high-contrast corners/edges (shelf posts, wire racks, plastic bin edges). Anchor discovered points to 3D world `(worldYawDeg, worldPitchDeg, depthMeters)` coordinates so yellow discovery dots pop in along the scan wave and turn into locked cyan/green sticky dots with triangulation mesh lines that stay stuck to the room as the phone pans.
  3. **3D Holographic Bin Cubes with Finger-in-Bin & Screen-Tap Read:** Render 3D wireframe bin cubes (`SHELF A · BIN 1`, `BIN 2`, `BIN 3`...) with `[AR]` lock reticles and `(x, y, z)` coordinates, and monitor each visible bin box's camera region of interest (ROI) so reaching a finger/hand into the bin spot in front of the camera (or tapping the bin box on screen) reads and locks that bin.

### DEC-015: Shared Firebase Rules Interim Fix & Ownership Restoration
- **Date:** November 23, 2026
- **Status:** 🟢 Active (Resolved via dedicated 3DPrintYou migration)
- **Context:** Firebase project `gen-lang-client-0675309660` (see DEC-001) previously hosted both SupplyCloset and the 3DPrintPosters / 3DPrintYou web app in one Firestore database `(default)`. Earlier on 2026-11-23 the rules were temporarily merged in `3DPrintPosters` to prevent cross-app overwrites. Later on 2026-11-23, 3DPrintPosters / 3DPrintYou migrated to its own dedicated Firebase project (`app-3dprintyou`).
- **Decision:**
  1. SupplyCloset once again owns Firestore rules on `gen-lang-client-0675309660`. `"rules": "firestore.rules"` has been re-enabled in `supply-closet/firebase/firebase.json`, and `supply-closet/firebase/firestore.rules` is deployed directly from `supply-closet/firebase/`.
  2. `gen-lang-client-0675309660` still shares Firebase Auth with the Texas AI Consulting website admin sign-in (`E:\PROJECTS\TexasAI Landing Page`, Auth only). Do not delete or disable non-SupplyCloset Auth users.
  3. Always deploy with explicit `--only` targets (`--only firestore:rules`, `--only firestore:indexes`, `--only functions`) and never use `--force` on indexes. Keep this repo's Functions codebase `default`.
- **Docs Reconciled:** [AGENTS.md](AGENTS.md) (guardrail 6), [skills/firebase-backend-rules/SKILL.md](skills/firebase-backend-rules/SKILL.md) (section 0), [supply-closet/SETUP.md](supply-closet/SETUP.md) (step 5), [HANDOFF.md](HANDOFF.md).
