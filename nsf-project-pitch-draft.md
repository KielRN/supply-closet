# SupplyCloset — NSF SBIR Project Pitch (Draft)

**Date:** November 7, 2026
**Status:** Draft for Elliott's review. Not submitted.
**Program:** NSF SBIR Phase I (America's Seed Fund). The pitch comes first; NSF invites a full proposal if the project fits. NSF typically responds in 1–2 months. Next full-proposal deadline: **March 4, 2027**.
**Companion doc:** [funding-strategy.md](funding-strategy.md)

## Submission settings

- **Topic area (recommended):** Digital Health, subtopic "Healthcare Workflow, Economics and Delivery." NSF says the topic aims to improve healthcare delivery through efficiency, lower cost or better outcomes, which is the problem SupplyCloset addresses.
- **Alternate topic:** Augmented Virtual and Mixed Reality. Use it if Elliott wants AR specialists to review the work. The risk is that these reviewers may see phone AR as off-the-shelf, so the pitch leans on the domain-specific innovation.
- **Applicant:** TEXAS AI CONSULTING, LLC (SAM registered name). UEI `LE9JXUK4C3P3`. PI: Eliud Lamboy.
- **Before submitting:** complete the SBA Company Registry (SBC Control ID) and Research.gov if the pitch portal asks for them. Resolve the IP ownership and employer-policy items in funding-strategy.md §4.
- **Limits:** characters, including spaces. Section text below is plain text, ready to paste. Counts are in the table at the end.

### Placeholders to fill before submitting

- `[ADVISOR-CV]`: AR/computer-vision engineer, advisor or contractor
- `[ADVISOR-NURSING]`: nursing research or human-factors advisor (could be a university partner)
- `[PILOT-SITE]`: simulation lab or hospital unit for testing
- Confirm the time-lost statistic in Section 3 against the peer-reviewed source before submitting. The market-research doc relies partly on a vendor blog (BlueBin).

---

## 1. The Technology Innovation (limit 3,500)

Hospital nurses lose significant shift time searching for supplies in unit supply rooms whose layouts differ from unit to unit and change with every restock. Existing tools (RFID and real-time location systems, automated cabinets, par-level software) track inventory for supply chain staff and require installed infrastructure. None of them tells a nurse standing in the supply room which bin holds what they need right now.

SupplyCloset is a mobile app that turns a nurse's phone into a supply finder. The nurse selects a procedure, sees its supply list, and the phone highlights the exact bin for each item. Location knowledge comes from nurses themselves, who tag and confirm items during normal work.

The innovation is a hardware-free, crowd-maintained spatial model of a supply room that stays accurate at the level of individual bins. Three elements go beyond current practice:

1. Semantic anchoring for repetitive spaces. Supply rooms defeat standard visual relocalization: rows of identical bins, reflective plastic, and contents that change daily. We will anchor the room model to persistent structure (shelf geometry and printed bin labels read on the device) rather than to raw visual features alone. That way any phone, on any shift, can recover the same room frame and the same bin identities.

2. A probabilistic location model built from crowd observations. Each item-and-bin pairing carries a confidence that rises with confirmations and decays with time and "not found" reports. The model supports one item stocked in several bins and resolves conflicting tags. The system knows how sure it is and tells the nurse, falling back to plain shelf-and-bin directions when confidence is low.

3. Low-effort capture and upkeep. A nurse sets up a room in minutes, starting from the doorway, with no QR codes, beacons, RFID tags or hospital IT integration. The model improves through ordinary use, and game mechanics reward the confirmations that keep it current.

Current state: we have a working Flutter and Firebase prototype with:
- supply checklists for 20 common nursing procedures;
- supply tagging;
- a live ARCore/ARKit session with a doorway start point;
- server-side confidence decay;
- lookup of device barcodes against the FDA Global Unique Device Identification Database.

What remains unproven, and what Phase I will test, is whether a phone alone can guide a nurse to the correct bin reliably and repeatably in real supply rooms, across devices and over weeks of change. The system collects no patient information: only supply names, locations and timestamps, with camera frames processed on the device and discarded.

---

## 2. The Technical Objectives and Challenges (limit 3,500)

Phase I will determine whether a phone-only system can guide nurses to the correct bin in a working supply room, repeatably across devices and as the room changes.

Objective 1: Room capture. Build a setup flow that records shelves, bins and bin labels into a persistent room model. Target: one person captures a typical unit supply room in under 15 minutes. Challenges: dense shelving, occlusion, poor lighting and damaged labels.

Objective 2: Cross-device relocalization and bin-level accuracy. Combine phone AR tracking with on-device label reading and shelf geometry to recover the room frame and bin identities. Targets: the correct bin is highlighted in at least 90 percent of trials across at least three phone models, and relocalization from the doorway takes under 10 seconds. Challenges: repetitive appearance, drift and partial views. We will record failure modes and measure how often the system correctly falls back to text directions instead of showing a wrong bin.

Objective 3: Crowd-maintained accuracy. Test the confidence model against scripted restocks, relocations and conflicting tags. Targets: identify stale locations within a defined number of nurse interactions after a change, and quantify how many confirmations per week keep location accuracy at or above 90 percent. Challenges: sparse, noisy and contradictory input, and items stocked in several places.

Objective 4: Usability and time to find. In a mock supply room at [PILOT-SITE], and with approval in one hospital unit, nurses will retrieve procedure supply sets with and without SupplyCloset. Measures: time to find, missed or wrong items, and task load. Human-subjects review will be completed before any testing with participants.

Key risks and mitigations:
- Visual relocalization fails in some rooms. Mitigation: label-based anchors plus a text fallback that never shows an unverified bin.
- Nurses don't contribute. Mitigation: confirmations take two taps or fewer and are built into finding a supply, so contributing is a side effect of using the app.
- Hospital access is slow. Mitigation: start in a simulation lab, which needs no hospital approval.

Success at the end of Phase I means:
- measured bin-level accuracy and relocalization performance in real supply room conditions;
- a validated confidence model;
- evidence of reduced search time.
Together these justify a Phase II multi-unit hospital pilot.

---

## 3. The Market Opportunity (limit 1,750)

Customers are U.S. hospitals, reached through nursing leadership and materials management. Of roughly 6,100 U.S. hospitals, about 2,500 with 200 or more beds are the initial target. Published studies identify supply searching as a leading time waster for hospital nurses, contributing to care delays, burnout and waste, including supplies that expire unused.

Entry is bottom-up. Individual nurses, especially travel, float-pool and newly hired nurses who lack local knowledge of a unit, use the app at low or no cost, building the location data. Hospitals then license unit and facility dashboards (stockout trends, most-searched items, par-level insight) at an estimated $25,000 to $75,000 per facility per year. That puts the U.S. software opportunity at roughly $60 to $190 million a year. A later revenue stream is aggregated, de-identified supply-placement data for suppliers and group purchasing organizations.

Competitors don't serve the nurse in the room. RFID and location systems such as CenTrak and Zebra track equipment and require installed hardware. Inventory and cabinet systems serve supply chain staff. SupplyCloset needs only the phones nurses already carry.

---

## 4. The Company and Team (limit 1,750)

Texas AI Consulting, LLC (San Antonio, Texas) was founded in January 2026. It is a service-disabled veteran-owned small business registered in SAM.gov, building AI solutions for healthcare and small businesses. SupplyCloset is its first product.

Principal Investigator: Eliud "Elliott" Lamboy, founder and CEO.
- More than 20 years as a registered nurse in emergency, intensive care, progressive care, telemetry, rehabilitation and travel nursing.
- Former U.S. Air Force flight nurse and Mission Crew Director in aeromedical evacuation (Air Medal).
- Healthcare IT and clinical data development, including EHR systems and clinical decision-support dashboards.
- IBM AI Engineering and Full Stack Software Developer certificates; MBA.
- Has experienced the supply-hunting problem firsthand and led development of the current prototype.
- Will be employed full time by the company upon award.

Planned team additions for Phase I:
- [ADVISOR-CV], AR and computer vision engineering
- [ADVISOR-NURSING], nursing research and human factors study design
- [PILOT-SITE], the testing location

---

## Character counts

| Section | Limit | Draft |
|---|---|---|
| 1. Technology Innovation | 3,500 | 2,645 |
| 2. Technical Objectives and Challenges | 3,500 | 2,404 |
| 3. Market Opportunity | 1,750 | 1,178 |
| 4. Company and Team | 1,750 | 1,086 |

Counts were measured on this draft and will change after placeholders are filled. Recount after editing.
