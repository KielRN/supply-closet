# SupplyCloset.app — Product Requirements Document

**Version:** 1.0
**Date:** April 12, 2026
**Author:** SupplyCloset founding team

---

## 1. Product Vision

SupplyCloset is a mobile app that turns every nurse's phone into an AR-powered supply finder. Point your camera at a supply room shelf, and the app highlights exactly what you need for the procedure you're about to perform. The more nurses use it, the smarter it gets — crowdsourcing supply locations across shifts, units, and facilities so no one has to waste time hunting again.

**One-liner:** "Never hunt for supplies again."

---

## 2. Target Users

### Primary: Bedside Nurses (RNs, LPNs)

- Work 12-hour shifts on hospital med-surg, ICU, ED, and specialty floors
- Frequently rotate units (float pool, travel nurses, new hires)
- Perform dozens of procedures daily that require gathering supplies from a shared supply room
- Pain point: Supply rooms are disorganized, layouts differ by unit, and institutional knowledge is tribal

### Secondary: Charge Nurses and Unit Managers

- Responsible for ensuring their unit runs efficiently
- Want visibility into supply room usage patterns and common stockouts

### Tertiary: Hospital Supply Chain / Materials Management

- Manage inventory levels, par levels, and vendor contracts
- Currently lack floor-level visibility into how supplies are actually accessed and consumed

---

## 3. Core User Flows

### Flow 1: "I'm About to Do a Procedure"

1. Nurse opens SupplyCloset and selects a procedure (e.g., "Foley Catheter Insertion")
2. App displays a checklist of required supplies for that procedure
3. Nurse taps "Find in Supply Room" and opens the AR camera view
4. Camera recognizes the supply room environment and overlays markers on shelves/bins where each item is located
5. As the nurse picks up each item, they tap to confirm — the checklist updates
6. Nurse earns points for confirming supply locations (gamification)

### Flow 2: "I Found Something — Let Me Tag It"

1. Nurse is in the supply room and spots an item
2. Opens the camera, points at the item, and taps "Tag This"
3. App prompts: "What is this?" — nurse selects from a searchable list or scans the barcode
4. Location is saved to the crowdsourced database for that unit's supply room
5. Nurse earns bonus points for contributing new location data

### Flow 3: "Check My Score"

1. Nurse opens the app to view their profile
2. Sees their points, rank on the unit leaderboard, and badges earned
3. Can compare scores across shifts and units
4. Monthly rewards or recognition for top contributors

### Flow 4: "What's Running Low?" (Charge Nurse / Manager View)

1. Charge nurse opens the dashboard view
2. Sees aggregated data: most-searched items, items frequently marked "not found," and trending stockout alerts
3. Can export or share reports with materials management

---

## 4. Feature Requirements

### 4.1 MVP (Phase 1) — Months 1–4

| Feature | Priority | Description |
|---|---|---|
| **Procedure supply checklists** | P0 | Curated checklists for the 20 most common nursing procedures (Foley, IV start, wound care, NG tube, etc.) |
| **AR camera view** | P0 | Opens device camera and overlays location markers on supply room shelves based on crowdsourced data |
| **Supply tagging** | P0 | Nurses can tag a supply's location by pointing their camera and selecting the item |
| **Barcode scanning** | P0 | Scan a supply's barcode to auto-identify it during tagging |
| **Google Sign-In (Firebase Auth)** | P0 | Simple authentication — nurses sign in with Google. No hospital IT integration required for MVP. |
| **Facility and unit selection** | P0 | Nurse selects their hospital and floor/unit during onboarding. Data is scoped to that unit's supply room. |
| **Basic gamification** | P1 | Points for tagging supplies and confirming locations. Simple leaderboard per unit. |
| **Offline mode (lite)** | P1 | Procedure checklists available offline. AR features require connectivity. |
| **Onboarding tutorial** | P1 | 3-screen walkthrough explaining how to tag, find, and earn points |

### 4.2 Phase 2 — Months 5–8

| Feature | Priority | Description |
|---|---|---|
| **Confidence scoring** | P0 | Supply locations gain confidence scores based on recency and number of confirmations. Stale data fades. |
| **Smart search** | P1 | Type a supply name and get its most likely location in your unit's supply room |
| **Shift-based insights** | P1 | "Items tagged this shift" and "new items since your last shift" notifications |
| **Badge system** | P1 | Achievement badges: "First Tag," "100 Club," "Night Shift Hero," "Supply Room Sensei" |
| **Push notifications** | P2 | Alerts for stockout trends on your unit, new badges earned, leaderboard changes |
| **Charge nurse dashboard** | P1 | Web or in-app view showing unit-level supply search and stockout patterns |

### 4.3 Phase 3 — Months 9–12

| Feature | Priority | Description |
|---|---|---|
| **Hospital admin portal** | P0 | Web dashboard for materials management: supply room analytics, heatmaps, par level recommendations |
| **Data export API** | P0 | Anonymized, aggregated supply intelligence available via API for vendor partners |
| **Custom procedure lists** | P1 | Hospitals can add their own procedure checklists and supply kits |
| **Multi-facility support** | P1 | Travel nurses can switch between facilities and see data for each |
| **Vendor analytics dashboard** | P1 | Self-serve portal for supply vendors to view product-level placement and access data |
| **SSO integration** | P2 | SAML/OIDC integration for hospitals that require enterprise authentication |

---

## 5. Gamification Design

### Point System

| Action | Points |
|---|---|
| Tag a new supply location | +10 |
| Confirm an existing location | +5 |
| Complete a procedure checklist | +15 |
| Report an item as "not found" / stockout | +5 |
| First tag on a new unit | +25 (bonus) |
| Streak: 5 consecutive shifts with activity | +50 (bonus) |

### Leaderboards

- **Unit leaderboard**: Rank among nurses on your floor
- **Facility leaderboard**: Rank across the hospital
- **Monthly reset**: Keeps competition fresh and accessible to new users

### Badges

- **Trailblazer**: First nurse to tag a supply on a new unit
- **Night Owl**: 50+ tags during night shifts
- **Supply Sensei**: 500 lifetime tags
- **Eagle Eye**: Found a supply that 10+ nurses had marked "not found"
- **Team Player**: Referred 3 colleagues who signed up

### Rewards (Future)

- Partner with hospital gift shops, coffee vendors, or CE credit providers for tangible rewards
- Recognition on facility-wide screens or newsletters (opt-in)

---

## 6. Non-Functional Requirements

| Requirement | Target |
|---|---|
| **AR overlay latency** | < 500ms from camera frame to overlay render |
| **App cold start** | < 3 seconds |
| **Camera-to-tag flow** | < 30 seconds end-to-end |
| **Uptime** | 99.9% (nurses work 24/7 including holidays) |
| **Data freshness** | Supply locations update in near-real-time across users on the same unit |
| **Supported platforms** | iOS 16+ and Android 12+ |
| **Accessibility** | WCAG 2.1 AA for non-AR screens; high-contrast mode for AR overlays |
| **Privacy** | No PHI collected. No patient data. No camera images stored on server (processed on-device, only metadata sent). |

---

## 7. Success Metrics

### Adoption

- **North star:** Monthly active nurses (MANs) per facility
- 60% of nurses on a unit using the app within 8 weeks of launch on that unit
- 3+ sessions per nurse per week

### Engagement

- Average points earned per nurse per shift
- % of supply tags that are confirmations of existing data (indicates trust in the system)
- Leaderboard participation rate

### Data Quality

- Median confidence score across all tagged supply locations
- % of "not found" reports that are resolved within 48 hours (supply restocked or location updated)
- Data coverage: % of items in a unit's par list that have been tagged at least once

### Business

- Facility-level contract value (ARR)
- Number of vendor data subscriptions
- Net Promoter Score (NPS) among nursing staff

---

## 8. Out of Scope for V1

- Integration with hospital EHR systems (Epic, Cerner)
- Automated supply ordering or restock triggers
- Wearable / smart glasses support
- Patient-facing features
- RFID or Bluetooth beacon hardware
