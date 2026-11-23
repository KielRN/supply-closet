# SupplyCloset Roadmap

**Last Updated:** November 7, 2026  
**Related Docs:** [README.md](README.md) · [DECISIONS.md](DECISIONS.md) · [prd.md](prd.md) · [funding-strategy.md](funding-strategy.md)

**Status Key:** 🟢 Done · 🔴 To Do

---

## Top Priorities Right Now

| Status | Priority Item | Track | What Needs to Happen |
| :---: | :--- | :--- | :--- |
| 🟢 | **Multi-Room Switcher (`Med 3A`) & Add Supply Room Flow** | Core / UX | Let nurses add supply rooms from `Tag` & `Settings`, and switch active rooms right inside the Finder HUD (`DEC-013`) |
| 🟢 | **Custom Display Name & Avatar / Photo Picker** | Core / Social | Let users set a custom display name, pick a pre-generated avatar, or upload a profile photo (`DEC-013`) |
| 🟢 | **Room Captain (+150 XP Trophy) & Spatial Captain Hints** | Gaming / Spatial | Top tagger in a room becomes **Room Captain** and can drop 3D **Captain Hints** (showing Captain's avatar & name) visible to all users (`DEC-013`) |
| 🟢 | **Build "God's Eye View" 3D Room Viewer & Gaming AR HUD** | Spatial / 3D | Interactive 3D Gaussian Splat room view + Gaming AR HUD with compass, radar, and off-screen turn chevrons |
| 🟢 | **Room Initiation (+250 XP) & Supply Bounties (+50 XP)** | Core / Spatial | Doorway room scan to pin 3D shelf racks + user-initiated Supply Bounties for untagged items |
| 🔴 | **Map One Real Room (30–50 Items)** | Spatial / 3D | Pick one test room, enter 30–50 common supplies, and allow one item to live in multiple bins |
| 🔴 | **Test Security Rules in Emulator** | Launch Prep | Verify new tags, confirmations, "not found" reports, and XP protections work end-to-end |
| 🔴 | **Submit NSF SBIR Project Pitch** | Funding | Complete SBA / Research.gov registrations and submit the pitch before the March 4, 2027 window |

---

## 1. Core Mobile App (MVP)

| Status | Feature | Simple Description | Notes |
| :---: | :--- | :--- | :--- |
| 🟢 | **App Setup & Navigation** | Flutter mobile app connected to Firebase backend | iOS & Android scaffolding ready |
| 🟢 | **Google Sign-In** | Nurses sign in quickly with a personal Google account | No hospital IT setup needed |
| 🟢 | **20 Procedure Checklists** | Pre-built supply lists for common nursing tasks (IV start, Foley, wound care) | Works offline on the phone |
| 🟢 | **Starter Supply Catalog** | ~200 common medical supplies pre-loaded with FDA lookup (`lookupUdi`) | Seeded in `assets/data/` |
| 🟢 | **Quick Search & 1-Tap Tagging** | Default tagging step uses instant search and glove-friendly 1-tap supply buttons | Replaced slow package barcode scanning as default (`DEC-011`) |
| 🟢 | **Supply Tagging & Confirming** | Nurses can tag where a supply is stored or confirm it is still there | Saves shelf and bin location |
| 🟢 | **"Not Found" Reporting** | Nurses can flag when an item is missing from its listed bin | Lowers location confidence score |
| 🟢 | **Points, Streaks & Leaderboards** | Nurses earn XP, level up, keep shift streaks, and compete on their unit | Verified on the server so points can't be faked |
| 🟢 | **Confidence Decay** | Old locations slowly lose confidence until a nurse confirms them again | Runs daily via Cloud Functions |
| 🟢 | **FDA Recall Checks** | Daily background check against FDA recall data | Runs daily via Cloud Functions |
| 🔴 | **Multiple Bins per Item** | Allow the same supply SKU to be saved in more than one bin | Currently overwrites single entry |
| 🟢 | **Multi-Room Picker & Add Room (`Med 3A`)** | Let nurses switch between multiple supply rooms on a floor (`Med 3A` Room 1, Room 2) in the HUD and add rooms from `Tag` or `Settings` | Implemented in `RoomProvider` & `RoomSwitcherSheet` (`DEC-013`) |
| 🟢 | **Custom Display Name & Avatar Picker** | Let nurses set a custom display name, pick pre-generated avatars, or upload a photo | Implemented in `ProfileIdentitySheet` & `UserAvatar` (`DEC-013`) |
| 🟢 | **Room Captain (+150 XP) & Spatial Hints** | Most tags in a room earns **Room Captain Trophy**; Captain can drop spatial hints in the room with their avatar & name | Implemented in `CaptainHintSheet` & `ArFinderScreen` (`DEC-013`) |
| 🔴 | **Room Door Sign OCR Scanner (Future)** | Scan the hospital room door plaque (e.g. `Med 3A · Clean Supply`) to auto-select the room | Future CV enhancement (`DEC-013`) |
| 🔴 | **On-Device Bin Label OCR** | Read printed shelf/bin labels with the camera during room setup | Stronger fit than crinkled package barcodes (`nsf-project-pitch-draft.md`) |

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
| 🔴 | **Beta Store Release** | Publish closed beta to Apple TestFlight and Google Play Internal Testing | Ready once rule tests finish |

---

## 3. "God's Eye View" 3D Room & AR Guidance (Spatial Track)

We use a **3-Layer Hybrid Spatial Model** from a single 5-minute room scan (see [`reviews/2026-10-21-spatial-product-research.md`](reviews/2026-10-21-spatial-product-research.md) and `DEC-008`):

| Status | Milestone | Simple Description | Notes |
| :---: | :--- | :--- | :--- |
| 🟢 | **Doorway "Set Start" & Room Initiation (+250 XP)** | Nurses scan an unmapped room from the doorway, pin Shelf A/B/C in 3D space, and earn +250 XP | `RoomInitiationScreen` (`DEC-012`) |
| 🟢 | **Gaming AR HUD & 360° Nav Indicators** | Compass tape, mini-map radar, off-screen turn chevrons (`◄◄ TURN LEFT`), floor path chevrons, and target lock diamond | Runs on-device in `ArFinderScreen` |
| 🟢 | **"God's Eye View" & 3DGS Research** | Evaluated `bilawalsidhu/gods-eye-view`, Three.js, Gaussian Splats, Point Clouds, and Cloud Anchors | Documented in `reviews/2026-10-21-spatial-product-research.md` |
| 🟢 | **Layer 2: Clickable 3D Bin Boxes ("God's Eye View")** | Interactive 3D room view where selecting a supply flies the camera to the glowing bin | Built in `ArFinderScreen` (`_GodsEyeSplatPainter`) |
| 🟢 | **Layer 3: Gaussian Splat Visual Layer** | 3D Gaussian Splat layer rendered over the clickable 3D shelf boxes with instant ON/OFF toggle | Built in `ArFinderScreen` & `RoomInitiationScreen` |
| 🟢 | **User-Initiated Supply Bounties (+50 XP)** | Nurses post bounties for untagged/missing supplies; Bounty Hunters earn +50 Bonus XP when tagging them | Built in `BountyBoardSheet` (`DEC-012`) |
| 🔴 | **Verify doorway tracking on the Moto** | Scan from inside the room and find a measured bin after reopening the app | Android pilot stores positions on one phone. Verify ARCore compatibility, sidestepping, and five fresh starts. |
| 🔴 | **Two-Phone Alignment Test** | Test whether Nurse B's phone highlights the exact same physical bin that Nurse A mapped | Measure target accuracy across shifts and lighting |
| 🔴 | **One-Room Nurse Pilot** | Test 1 supply room, 30–50 supplies, and 5–10 nurses; measure time saved | Target: ≥90% right-bin accuracy |

---

## 4. Go-To-Market & Commercial Rollout

| Status | Stage | Simple Description | Target Price / Goal |
| :---: | :--- | :--- | :--- |
| 🟢 | **Market & Brand Strategy** | Defined brand voice, target market sizing, and cold-start data plan | Documented in `prd.md`, `branding-brief.md`, `data-strategy.md` |
| 🟢 | **Consumer-Wedge Plan** | Strategy to launch checklist + quick-search app directly to travel nurses first | Documented in `consumer-wedge-gtm.md` |
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
| 🔴 | **SBA & Research.gov Signup** | Register on `sbir.gov` (SBC Control ID) and `Research.gov` | Required portal accounts |
| 🔴 | **Pilot Site & Advisor Letters** | Line up a nursing simulation lab / unit and CV + nursing advisors | Fills `[PILOT-SITE]` and `[ADVISOR]` placeholders |
| 🔴 | **Submit NSF Project Pitch** | Submit pitch to NSF Digital Health topic for Phase I invitation | Nov–Dec 2026 |
| 🔴 | **Submit Full NSF Phase I Proposal** | Full technical & commercial proposal (~$305K for 6–18 months R&D) | Deadline: **March 4, 2027** |
