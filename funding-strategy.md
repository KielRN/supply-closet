# SupplyCloset — Funding Strategy (SBIR/STTR)

**Date:** November 7, 2026
**Status:** Planning draft. Nothing has been submitted or registered beyond SAM.gov.
**Applicant:** Texas AI Consulting, LLC (SupplyCloset is a TxAI application, per the April 14, 2026 decision in `CEO_Journal.md`)
**Relationship to existing docs:** This document pairs with [prd.md](prd.md), [market-research.md](market-research.md), [consumer-wedge-gtm.md](consumer-wedge-gtm.md) and [reviews/2026-10-21-spatial-product-research.md](reviews/2026-10-21-spatial-product-research.md).

---

## 1. Recommendation

Pursue **non-dilutive federal R&D funding** to pay for the hardest part of SupplyCloset: reliable, shared, bin-level AR guidance in a real supply room.

| Priority | Program | Why |
|---|---|---|
| **1** | **NSF SBIR Phase I** (America's Seed Fund) | Funds technical risk in almost any market. Software and AI are eligible when there's real technical innovation. Starts with a short Project Pitch. |
| 2 | **NIH / AHRQ SBIR** (HHS omnibus) | Possible if framed around patient-safety delays, nurse workload and health-system efficiency. Stronger after Phase I data exists. |
| 3 | **DoD SBIR (Defense Health Agency)** | Only if a matching medical-logistics topic is posted. Watch, don't build around it. |
| Alt | **STTR** (any agency above) | Use only if a university partner (for example a nursing simulation lab) would strengthen the research. |

**Decision recorded (Elliott, 2026-11-07):** If SupplyCloset wins an SBIR award, Elliott will go full time at Texas AI Consulting. That makes Elliott the principal investigator (PI) and removes the main eligibility blocker (Section 4).

---

## 2. Program Status (as of November 7, 2026)

- **SBIR/STTR is reauthorized.** The programs lapsed on September 30, 2025. The Small Business Innovation and Economic Security Act (S. 3971) was signed April 13, 2026, extending them through September 30, 2031. The law also added a Phase II "strategic breakthrough" tier (up to $30M) and expanded security screening of applicants.
- **NSF** reopened in mid-2026 under solicitation **NSF 26-510** (deep technology). NSF's full-proposal page lists deadlines of July 27, 2026, November 4, 2026 and **March 4, 2027**. The first two have passed.
- **NIH** reissued its parent SBIR announcement (**PA-27-100**; STTR **PA-27-102**). Standard receipt dates are September, January and April. The next is about **January 5, 2027**.
- **DoD** posts topics through the Defense SBIR/STTR Innovation Portal (DSIP). No 2026 DHA medical-supply topic was found; DHA has an open medical-logistics RFI, not an SBIR topic.

**Typical NSF Phase I award:** up to about **$305,000** over 6–18 months. This comes from secondary sources; confirm it in NSF 26-510 before budgeting.

---

## 3. The Fundable Technical Problem

NSF and NIH fund **technical risk**, not routine app development. Our own October 21 research identifies the unsolved problems, and they are the core of a Phase I proposal:

| Current gap (from the October review) | Phase I research question |
|---|---|
| Tags save no measured position; `x/y/z` are zero | Can a nurse capture a supply room's shelves and bins into a persistent room model in minutes, without installing hardware? |
| Markers are scaled to screen pixels, not anchored to shelves | Can the app highlight the correct bin, and keep it attached as the phone moves, in cluttered, look-alike shelving? |
| No shared room frame; each "Set Start" is local | Can different phones, on different shifts, find the same bin from the same saved room model? |
| One location per barcode; stock can live in several bins | Can the data model represent the same item in several bins, with per-location confidence that fades when stale? |
| Crowdsourced confirmations aren't validated | How many nurse confirmations, and how often, keep location data accurate as rooms change? |

**Proposed Phase I scope:** Build and test the one-room digital twin with AR guidance recommended in the October review.
1. **Room model capture:** a setup flow that records shelves and bins into a saved room model.
2. **Shared localization:** persistent anchors so any device lands in the same room frame. Measure bin-highlight accuracy and drift across sessions and devices.
3. **Crowdsourced freshness:** validate the confidence and decay model against real changes in a room.
4. **Time-to-find study:** compare nurses finding procedure supplies with and without SupplyCloset. A **mock supply room** (for example in a nursing simulation lab) is the lowest-friction place to start.

**Success metrics:** Set these before the pitch. Candidates:
- correct-bin highlight rate (for example ≥90% of trials);
- relocalization time;
- time-to-find reduction versus baseline;
- location accuracy after N weeks of crowdsourcing.

**How this fits the consumer wedge:** The [consumer-wedge GTM](consumer-wedge-gtm.md) drops AR from v1 to reach revenue faster. The two plans are complementary: the wedge ships the text-based product and builds the dataset, while SBIR money funds the AR research the wedge postponed. Proposals should present the wedge as early commercial traction, not as competing scope.

---

## 4. Eligibility and Blockers

| Requirement | Status |
|---|---|
| U.S. for-profit small business, ≤500 employees, ≥51% owned by U.S. citizens | Texas AI Consulting, LLC qualifies. Confirm the ownership details in the application. |
| Active SAM.gov registration | **Active, All Awards.** UEI `LE9JXUK4C3P3`, CAGE `26UG0`. A renewal adding NAICS 611430/611420 was submitted 2026-11-07, pending validation. SAM must stay active through award. |
| **PI primarily employed (>50%) by the company** at award and during the project | **Resolved by decision:** Elliott goes full time at TxAI if awarded. You can apply while still employed at Methodist; the requirement applies at award. Confirm the exact NSF 26-510 wording, and avoid outside employment beyond about 19.6 hours a week during the award. |
| Company owns the IP & employer policy | **Confirmed (Eliud, 2026-11-08):** Eliud Lamboy is the sole owner of Texas AI Consulting, LLC, owns all SupplyCloset IP, and has verified Methodist policy compliance. |
| Pilot site / letters of support | **Open.** A hospital unit, nursing school or simulation lab willing to host testing strengthens the proposal. Methodist can't be assumed. |
| Human-subjects compliance | Testing with nurses is research with people. Plan for IRB review (or an exemption determination), especially for NIH. A mock room lowers the risk. |
| Security screening (new in 2026 law) | Prepare to disclose foreign ties, funding sources and foreign components. None are known; confirm in the application. |
| Privacy | Already designed with no PHI: supply names, locations and timestamps only, with on-device camera processing (see [data-strategy.md](data-strategy.md)). Restate this in the proposal. |

---

## 5. Registrations Still Needed

- [ ] **SBA Company Registry** (sbir.gov) → SBC Control ID. Required by all agencies.
- [ ] **Research.gov** account linked to the UEI (NSF).
- [ ] **Grants.gov** + **eRA Commons** (NIH only; start early, since eRA Commons setup takes time).
- [ ] **DSIP** account (DoD only, if a topic fits).
- [ ] Claim and complete the **SBA Small Business Search** profile (empty narrative, keywords and contact as of 2026-11-07). This helps contracting work more than SBIR, but it's the same identity.
- [ ] Consider adding **NAICS 541715** (R&D in physical, engineering and life sciences) at the next SAM update. It's optional for SBIR.

---

## 6. Timeline

| When | Step |
|---|---|
| Nov–Dec 2026 | Complete the SBA Company Registry and Research.gov. Draft and submit the **NSF Project Pitch**. |
| Dec 2026 – Jan 2027 | Receive the NSF invitation decision. If invited, start the full proposal: technical narrative, commercialization plan, budget, letters of support. |
| Jan 5, 2027 (optional) | NIH SBIR receipt date, only if eRA Commons and a pilot partner are already in place. Otherwise target April 2027. |
| **Mar 4, 2027** | **NSF full-proposal deadline** (if invited). |
| ~6 months after submission | Typical award decision window (confirm with the agency). At award, Elliott transitions to full time at TxAI. |
| Oct 23, 2027 | Current SAM expiration. Confirm the new date once the renewal validates. |

---

## 7. Budget Notes

- Phase I (about $305K at NSF) should realistically fund **Elliott's salary as full-time PI**, contracted AR/computer-vision help, devices, a mock supply room setup, study participant costs and allowed indirect costs and fee. The NSF ceiling includes these.
- **Bridge plan:** The time between submission and award runs months. TxAI consulting revenue covers the gap, and the full-time move happens at award, not at submission.
- SBIR is non-dilutive: TxAI keeps ownership and the IP, with standard government data rights.

---

## 8. Help Available

- **Grant Engine (Joel Tabb):** SBIR consultant already in contact. He flagged the reauthorization on April 14, 2026. Ask about Project Pitch review and fees before engaging.
- **NSF program directors:** NSF invites contact about fit after a pitch. Use it.
- **UTSA Small Business Development Center:** works with newer businesses. The UTSA Center for Government Contracting (former APEX) requires two years of revenue for one-on-one advising.
- **Possible STTR or study partners:** local nursing schools or simulation labs. Not yet contacted.

---

## 9. Open Questions for Elliott

1. Which hospital unit, nursing school or simulation lab could host the Phase I study and write a letter of support?
2. Engage Grant Engine, or write the Project Pitch in-house first?

---

## Sources

- [Crowell — SBIR/STTR programs reauthorized after six-month lapse](https://www.crowell.com/en/insights/client-alerts/sbirsttr-programs-reauthorized-after-six-month-lapse)
- [SBA — Administrator Loeffler applauds SBIR-STTR reauthorization (Apr 13, 2026)](https://www.sba.gov/article/2026/04/13/administrator-loeffler-applauds-sbir-sttr-reauthorization)
- [Inside Government Contracts — what's changing](https://www.insidegovernmentcontracts.com/2026/03/is-congress-finally-reauthorizing-sbir-sttr-and-whats-changing/)
- [NSF Seed Fund — Project Pitch information](https://seedfund.nsf.gov/apply/project-pitch-information/)
- [NSF Seed Fund — Full proposal (deadlines, NSF 26-510/26-511)](https://seedfund.nsf.gov/apply/full-proposal/)
- [GrantedAI — NSF 26-510 Phase I math ($305K)](https://grantedai.com/blog/nsf-sbir-sttr-nsf-26-510-july-27-deadline-305k-phase-i-instrumentation-pilot-startup-strategy-2026)
- [NSF SBIR program guide (PI employment)](https://nsfproposal.com/blog/nsf-sbir-program-guide/)
- [GrantedAI — NIH parent SBIR PA-27-100](https://grantedai.com/news/pa-27-100-1-4b-2026-05-31)
- [DHA RFI — Joint Operational Medicine Medical Logistics](https://orangeslices.ai/?p=115822)
- [UTSA — Center for Government Contracting absorbs APEX services](https://news.utsa.edu/2025/07/center-for-government-contracting-enhances-small-business-support/)

Secondary sources (blogs and aggregators) were used for some figures. Confirm award amounts, deadlines and PI rules against the official solicitation before submitting.
