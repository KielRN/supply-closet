# SupplyCloset Roadmap

**Last Updated:** November 7, 2026  
**Related Docs:** [README.md](README.md) · [DECISIONS.md](DECISIONS.md) · [prd.md](prd.md) · [funding-strategy.md](funding-strategy.md)

**Status Key:** 🟢 Done · 🔴 To Do

---

## Top Priorities Right Now

| Status | Priority Item | Track | What Needs to Happen |
| :---: | :--- | :--- | :--- |
| 🔴 | **Finish Camera Barcode Scanning** | Mobile App | Connect the phone camera stream in `tag_supply_screen.dart` to decode barcodes automatically |
| 🔴 | **Test Security Rules in Emulator** | Launch Prep | Verify new tags, confirmations, "not found" reports, and XP protections work end-to-end |
| 🔴 | **Pre-Submission IP & Policy Check** | Funding | Confirm Texas AI Consulting owns all IP and review Methodist outside-work policy |
| 🔴 | **Submit NSF SBIR Project Pitch** | Funding | Complete SBA / Research.gov registrations and submit the pitch before the March 4, 2027 window |
| 🔴 | **Map One Real Room (30–50 Items)** | Spatial / AR | Pick one test room, enter 30–50 common supplies, and support one item living in multiple bins |

---

## 1. Core Mobile App (MVP)

| Status | Feature | Simple Description | Notes |
| :---: | :--- | :--- | :--- |
| 🟢 | **App Setup & Navigation** | Flutter mobile app connected to Firebase backend | iOS & Android scaffolding ready |
| 🟢 | **Google Sign-In** | Nurses sign in quickly with a personal Google account | No hospital IT setup needed |
| 🟢 | **20 Procedure Checklists** | Pre-built supply lists for common nursing tasks (IV start, Foley, wound care) | Works offline on the phone |
| 🟢 | **Starter Supply Catalog** | ~200 common medical supplies pre-loaded with FDA barcode lookup (`lookupUdi`) | Seeded in `assets/data/` |
| 🟢 | **Supply Tagging & Confirming** | Nurses can tag where a supply is stored or confirm it is still there | Saves shelf and bin location |
| 🟢 | **"Not Found" Reporting** | Nurses can flag when an item is missing from its listed bin | Lowers location confidence score |
| 🟢 | **Points, Streaks & Leaderboards** | Nurses earn XP, level up, keep shift streaks, and compete on their unit | Verified on the server so points can't be faked |
| 🟢 | **Confidence Decay** | Old locations slowly lose confidence until a nurse confirms them again | Runs daily via Cloud Functions |
| 🟢 | **FDA Recall Checks** | Daily background check against FDA recall data | Runs daily via Cloud Functions |
| 🔴 | **Live Camera Barcode Decode** | Point the camera at a package barcode to auto-fill the supply | Camera UI is built; frame decoding needs wiring |
| 🔴 | **Multiple Bins per Item** | Allow the same supply SKU to be saved in more than one bin | Currently overwrites single barcode entry |
| 🔴 | **Room Picker** | Let nurses switch between different supply rooms on a floor | Currently defaults to `main` room |

---

## 2. Security, Testing & Launch Readiness

| Status | Milestone | Simple Description | Notes |
| :---: | :--- | :--- | :--- |
| 🟢 | **Security Audit Fixes (21/21)** | Fixed all 21 issues from the security review (blocked fake XP, locked user roles, added rate limits) | Completed April 2026 |
| 🟢 | **Safe Concurrent Updates** | Added version checks so two nurses tagging at once don't overwrite each other | Enforced in Firestore rules |
| 🟢 | **Flutter Code & Unit Checks** | `flutter analyze` and `flutter test` pass with zero errors | Smoke tests added in `test/` |
| 🟢 | **Cloud Functions Lint Check** | `npm run lint` passes cleanly on backend code | Verified on local workspace |
| 🔴 | **Firestore Emulator Rule Tests** | Automated test suite proving security rules allow normal use and block tampering | Needed before public store launch |
| 🔴 | **Clear Text Fallback** | Always show plain "Shelf + Bin" text whenever camera or AR is off or unsure | Never block a nurse waiting on AR |
| 🔴 | **Basic Usage Tracking** | Log tags vs. confirmations, search times, and how often AR needs recentering | Needed to measure pilot success |
| 🔴 | **Beta Store Release** | Publish closed beta to Apple TestFlight and Google Play Internal Testing | Ready once barcode & rule tests finish |

---

## 3. Room View & AR Guidance (Spatial Track)

| Status | Milestone | Simple Description | Notes |
| :---: | :--- | :--- | :--- |
| 🟢 | **Doorway "Set Start" Flow** | Nurses stand at the doorway and tap `Set Start` or `Recenter` to align the room | No QR codes or beacons needed |
| 🟢 | **Basic AR Camera Session** | Live ARCore / ARKit camera view inside the finder screen | Runs on-device; no video leaves the phone |
| 🟢 | **Spatial Research & Plan** | Evaluated 3D room viewers, Google Cloud Anchors, and MultiSet VPS | Documented in `reviews/2026-10-21-spatial-product-research.md` |
| 🔴 | **Save Real 3D Tag Coordinates** | Record actual shelf/bin positions during room setup instead of `0, 0, 0` | Needed so markers stick to real shelves |
| 🔴 | **3D Room Overview ("God's Eye View")** | Simple interactive 3D/cutaway map of one room where clicking a supply highlights its bin | Browser + app companion view |
| 🔴 | **Two-Phone Alignment Test** | Test whether Nurse B's phone highlights the exact same bin that Nurse A mapped | Benchmark doorway start vs. Cloud Anchors |
| 🔴 | **One-Room Nurse Pilot** | Test 1 supply room, 30–50 supplies, and 5–10 nurses; measure time saved | Target: ≥90% right-bin accuracy |

---

## 4. Go-To-Market & Commercial Rollout

| Status | Stage | Simple Description | Target Price / Goal |
| :---: | :--- | :--- | :--- |
| 🟢 | **Market & Brand Strategy** | Defined brand voice, target market sizing, and cold-start data plan | Documented in `prd.md`, `branding-brief.md`, `data-strategy.md` |
| 🟢 | **Consumer-Wedge Plan** | Strategy to launch text + checklist app directly to travel nurses first | Documented in `consumer-wedge-gtm.md` |
| 🔴 | **Waitlist & Nurse Creator Videos** | Simple landing page (`supplycloset.app`) and short nurse videos showing the pain | 50–100 beta nurses on waitlist |
| 🔴 | **Stage 1: Individual Nurse App** | Self-serve download for travel nurses, float pool, and new grads | $4.99/mo or $39/yr |
| 🔴 | **Stage 2: Unit Plan** | Pitch charge nurses once 5+ nurses on the same floor use the app | $49/mo per unit |
| 🔴 | **Stage 3: Hospital Facility Plan** | Dashboards for materials management showing stockouts and search trends | $25k–$75k/yr per hospital |
| 🔴 | **Stage 4: Vendor Data Subscriptions** | De-identified supply usage insights for suppliers and GPOs | $5k–$25k/mo API/reports |

---

## 5. Non-Dilutive R&D Funding (SBIR / STTR)

| Status | Step | Simple Description | Target Date / Notes |
| :---: | :--- | :--- | :--- |
| 🟢 | **SAM.gov Registration** | Texas AI Consulting, LLC registered (`UEI: LE9JXUK4C3P3`) | Active through Oct 23, 2027 |
| 🟢 | **PI Full-Time Commitment Decision** | Decided Elliott will move full-time to Texas AI Consulting upon SBIR award | Removes PI eligibility blocker |
| 🟢 | **SBIR Funding Strategy** | Mapped NSF Phase I (~$305K), NIH, and DoD grant options | See `funding-strategy.md` |
| 🟢 | **NSF Project Pitch Draft** | Written 4-part pitch within NSF character limits | See `nsf-project-pitch-draft.md` |
| 🔴 | **IP & Employer Policy Review** | Confirm written IP ownership in TxAI and check Methodist outside-work rules | Must finish before submitting pitch |
| 🔴 | **SBA & Research.gov Signup** | Register on `sbir.gov` (SBC Control ID) and `Research.gov` | Required portal accounts |
| 🔴 | **Pilot Site & Advisor Letters** | Line up a nursing simulation lab / unit and CV + nursing advisors | Fills `[PILOT-SITE]` and `[ADVISOR]` placeholders |
| 🔴 | **Submit NSF Project Pitch** | Submit pitch to NSF Digital Health topic for Phase I invitation | Nov–Dec 2026 |
| 🔴 | **Submit Full NSF Phase I Proposal** | Full technical & commercial proposal (~$305K for 6–18 months R&D) | Deadline: **March 4, 2027** |
