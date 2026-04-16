# SupplyCloset.app — Market Research Report

**Date:** April 12, 2026
**Prepared for:** SupplyCloset founding team

---

## Executive Summary

SupplyCloset is a mobile app that uses augmented reality and crowdsourced intelligence to help nurses locate supplies on their hospital floor in real time. The app opens a camera view inside the supply room and visually highlights the items a nurse needs for a given procedure (e.g., Foley catheter insertion). As more nurses use the app across shifts and units, the system builds a living map of where supplies actually live — and that data becomes valuable to the hospitals, GPOs, and vendors who stock those shelves.

This report examines the market opportunity, competitive landscape, and key risks.

---

## 1. The Problem

Nurses waste a staggering amount of time searching for supplies. Industry data paints a clear picture:

- Nurses lose up to **60 minutes per shift** hunting for supplies — roughly 8% of a 12-hour shift spent on non-clinical activity.
- Hospitals collectively lose an estimated **6,000 nursing hours per month per facility** to supply searches.
- Across the ~3 million registered nurses in the U.S., the aggregate productivity cost reaches an estimated **$14 billion annually**.
- **69% of perioperative staff** report having delayed a case because they couldn't locate a needed supply.
- The American Hospital Association estimates hospitals spend **$25 billion per year** on avoidable supply chain inefficiencies.
- **20–30% of hospital inventory expires before use**, often because items are misplaced or overlooked.

The root cause is simple: supply rooms are chaotic, layouts differ by floor and facility, and institutional knowledge about where things are lives in nurses' heads — not in any system. When a nurse floats to a new unit, is newly hired, or works a less-familiar shift, the problem compounds.

---

## 2. Market Sizing

### Total Addressable Market (TAM)

The healthcare supply chain management market was valued at **$3.93 billion in 2025** and is projected to reach **$11.35 billion by 2034** (CAGR of 12.2%). North America holds **48.6%** of this market.

Healthcare data monetization — the secondary revenue stream for SupplyCloset — is projected to grow from **$0.58 billion (2025) to $1.16 billion by 2030** (CAGR of 14.9%), with some analysts projecting the broader market reaching **$3.4 billion by 2033**.

### Serviceable Addressable Market (SAM)

There are approximately **6,100 hospitals** in the United States. Targeting mid-to-large hospitals (200+ beds) narrows the focus to roughly **2,500 facilities**. At an estimated contract value of $25,000–$75,000/year per facility (based on per-nurse or site licensing), the SAM is roughly **$60–190 million annually** for the software alone.

### Serviceable Obtainable Market (SOM)

Capturing 2–5% of U.S. mid-to-large hospitals within the first 3 years (50–125 facilities) would yield **$1.25–9.4 million in ARR** before data monetization revenue.

---

## 3. Competitive Landscape

No current competitor does exactly what SupplyCloset proposes — AR-guided supply finding powered by crowdsourced nurse data. However, several adjacent categories overlap:

### RFID / RTLS Asset Tracking

| Company | What They Do | Gap vs. SupplyCloset |
|---|---|---|
| **CenTrak** | Real-time location of equipment via IR/RFID/Wi-Fi | Tracks *equipment* (pumps, beds), not consumable supplies. Requires hardware infrastructure. |
| **Zebra Technologies** | RFID/barcode asset visibility | Focused on high-value assets and warehouse-style inventory. Not nurse-facing UX. |
| **GuardRFID** | RFID asset tracking and security | Hospital-wide asset tracking; no procedure-specific guidance for nurses. |
| **CYBRA** | RFID + RTLS track-and-trace | Enterprise-grade; no mobile-first AR experience. |

### Inventory Management Software

| Company | What They Do | Gap vs. SupplyCloset |
|---|---|---|
| **eTurns TrackStock** | Phone/RFID-based supply replenishment | Manages reorder levels, not real-time in-room finding. |
| **ASAP Systems** | Barcode/RFID inventory for hospitals | Traditional inventory management; no nurse workflow integration. |
| **Capterra-listed medical inventory tools** | Various web-based inventory platforms | Back-office tools for materials management, not bedside/supply-room tools for nurses. |

### AR in Healthcare

AR is growing rapidly in healthcare (projected **40.9% CAGR through 2030**), but current applications focus on clinical use cases like vein visualization (AccuVein), surgical navigation, and nursing education — not supply logistics. This leaves a clear whitespace.

### Key Takeaway

The competitive moat for SupplyCloset is the intersection of three things no one else combines: **(1)** AR visual guidance, **(2)** crowdsourced supply location data from nurses, and **(3)** a consumer-grade mobile experience that doesn't require RFID tags or hardware installation.

---

## 4. Data Monetization Opportunity

The healthcare data monetization market is growing rapidly, and SupplyCloset sits on a unique data asset: real-world, timestamped, facility-level intelligence about how supplies move (or don't) on hospital floors.

### Who Would Buy This Data

- **Medical supply distributors** (McKesson, Cardinal Health, Medline): Understand which products nurses actually reach for, which are hard to find, and which go unused.
- **GPOs (Group Purchasing Organizations)**: Validate contract compliance — are hospitals actually stocking and using the contracted items?
- **Device and supply manufacturers**: Get visibility into how their products are stored, accessed, and adopted at the unit level.
- **Hospital operations teams**: Benchmark their own supply rooms against anonymized data from peer facilities.

### Data Products

- **Supply velocity reports**: How quickly specific items are located and consumed by unit and shift.
- **Planogram optimization**: Data-driven recommendations for how to lay out supply rooms.
- **Stockout prediction**: Pattern recognition on when and where shortages are likely to occur.
- **Adoption dashboards**: For manufacturers launching new products, track real-world shelf placement and nurse interaction.

### Revenue Model

The analytics-enabled platform-as-a-service model dominates healthcare data monetization (38.9% of revenue share). SupplyCloset could offer tiered data subscriptions to vendors and aggregated benchmarking dashboards to hospitals, layered on top of the core SaaS license.

---

## 5. Gamification Validation

Recent research supports gamification as a viable engagement strategy for nurses. A 2025 study published in JMIR Serious Games tested a gamified mobile app with hospital nurses over 8 weeks and found strong motivational engagement, with the highest scores in "development and accomplishment" (mean 7.29 out of 10) and "empowerment of creativity and feedback" (mean 6.55).

The healthcare gamification market is projected to exceed **$47 billion by 2026** (CAGR of 11.9%).

For SupplyCloset, gamification serves a dual purpose: it drives adoption (critical for crowdsourcing data) and creates friendly competition that makes a mundane task — scanning and tagging supply locations — feel rewarding.

---

## 6. Risks and Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| **Hospital IT security / approval barriers** | High | HIPAA-compliant architecture (no PHI collected). Firebase Auth + GCP security posture. Pursue SOC 2 early. |
| **Nurse adoption and daily habit formation** | High | Gamification, unit-level leaderboards, peer referral loops. Keep the UX under 30 seconds per interaction. |
| **Supply room variability** | Medium | Crowdsourced model adapts per facility. The more variable rooms are, the more valuable the app becomes. |
| **RFID incumbents adding AR features** | Medium | Incumbents are hardware-dependent and enterprise-sold. SupplyCloset's advantage is zero-hardware, nurse-first, bottom-up adoption. |
| **Data privacy and vendor trust** | Medium | Anonymize and aggregate all data. Transparent opt-in for data sharing. Comply with state-level health data regulations. |
| **Camera use restrictions in clinical areas** | Low–Med | The app operates in supply rooms, not patient care areas. Clear policy guidance for partner hospitals. |

---

## 7. Go-to-Market Considerations

**Beachhead segment:** Travel nurses and float pool nurses — the people who change units most frequently and feel the supply-finding pain most acutely.

**Entry strategy:** Free tier for individual nurses (build the crowdsourced dataset), paid tier for hospitals wanting facility-wide dashboards and supply room optimization. Data products sold separately to vendors and GPOs.

**Distribution:** Organic adoption through nursing communities (NurseTok, allnurses.com, nursing subreddits), partnerships with travel nurse agencies, and direct sales to hospital supply chain directors.

---

## Sources

- [Fortune Business Insights — Healthcare Supply Chain Management Market](https://www.fortunebusinessinsights.com/industry-reports/healthcare-supply-chain-management-market-101051)
- [BlueBin — Nurse Burnout and Supply Hunts: The $14B Productivity Crisis](https://blog.bluebin.com/nurse-burnout-supply-hunts-the-14b-productivity-crisis-healthcare-ignores)
- [BlueBin — The Hidden Iceberg: True Cost of Healthcare Supply Chain Inefficiency](https://blog.bluebin.com/the-hidden-iceberg-true-cost-of-healthcare-supply-chain-inefficiency-beyond-purchase-price)
- [PMC — Time Wasters Facing Nurses During Work in Hospital Departments](https://pmc.ncbi.nlm.nih.gov/articles/PMC11960182/)
- [PMC — Designed for Workarounds: Causes of Operational Failures in Hospitals](https://pmc.ncbi.nlm.nih.gov/articles/PMC4116263/)
- [MarketsandMarkets — Healthcare Data Monetization Market](https://www.marketsandmarkets.com/Market-Reports/healthcare-data-monetization-market-56622234.html)
- [Grand View Research — Data Monetization Solution for Healthcare Providers](https://www.grandviewresearch.com/industry-analysis/data-monetization-solution-healthcare-providers-market-report)
- [JMIR Serious Games — Gamified Mobile App for Nurses (2025)](https://games.jmir.org/2025/1/e66262)
- [Open Loyalty — Gamification in Healthcare (2026)](https://www.openloyalty.io/insider/gamification-healthcare)
- [Vertex AI Vision — Google Cloud](https://cloud.google.com/vertex-ai-vision)
- [Terso Solutions — Frustrations of Manual Inventory Management: A Nurse's Perspective](https://www.tersosolutions.com/frustrations-of-manual-inventory-management-a-nurses-perspective/)
- [Infor — Healthcare Supply Chain and Nurse Patient Outcomes](https://www.infor.com/blog/optimizing-supply-availability-for-nurses)
