# SupplyCloset — Consumer-Wedge GTM (Faster-to-Revenue Variant)

**Status:** Alternative GTM proposal
**Relationship to existing docs:** Reframes the launch sequence in [prd.md](prd.md). Hospital admin portal and vendor data API (Phase 3 in the PRD) remain the long-term prize — this doc proposes a different path to get there.

---

## Why this variant exists

The PRD ([prd.md](prd.md)) as written targets hospital materials management and charge nurses as buyers. That's where the real ARR lives, but hospital sales cycles are 6–18 months, HIPAA/BAA procurement gates add months more, and pilots often stall without converting.

A consumer-wedge GTM lets the product generate revenue in month 1 instead of month 12, and uses bottom-up adoption to pull enterprise sales rather than push them.

**Core insight:** travel nurses, float-pool RNs, and new grads have the same pain as staff nurses but zero institutional gatekeepers. They can download an app and pay $4.99 today.

---

## Scope cut: drop AR for v1

The AR overlay is the product's most distinctive feature — and its biggest technical risk. Getting reliable shelf-level overlays in cluttered supply rooms across thousands of layouts is a hard CV problem. Don't bet the company on it before you know nurses will pay for the underlying utility.

**v1 is just:**
- Curated checklists for the 20 most common procedures (already P0 in the PRD)
- Crowdsourced supply location data *as text* — "IV start kit: Supply Room B, shelf 3, bin 12"
- Barcode scanning for tagging (already P0)
- Gamification + unit leaderboards (already P1)
- Facility/unit scoping (already P0)

**AR becomes v2** — added once there's enough location data per unit to make the overlay accurate, and enough paying users to justify the CV investment.

This collapses the MVP from 4 months to ~6 weeks.

---

## Revenue ladder

| Stage | Customer | Price | Motion |
|---|---|---|---|
| **1. Nurse** | Individual RN | $4.99/mo or $39/yr | App store, self-serve |
| **2. Unit** | Charge nurse / floor | $49/mo per unit | PLG — pitched once 5+ nurses on a floor are active |
| **3. Facility** | Materials management / CNO | $500–2,000/mo per facility | Inside sales once 3+ units on one facility are on unit plans |
| **4. Vendor data** | Supply vendors (BD, Cardinal, Medline) | $5k–25k/mo API contracts | Enterprise sales once multi-facility data coverage exists |

You don't start at rung 4. You climb.

---

## Target user for v1: travel nurses

Why travel nurses first:
- Highest pain: new unit every 13 weeks, zero institutional knowledge
- Highest willingness to pay: already pay for scrubs, stethoscopes, NCLEX tools, CEU subscriptions
- Concentrated channels: travel nurse Facebook groups, Reddit r/TravelNursing, Trusted Health / Aya / Vivian communities, nursing TikTok
- No hospital gatekeeper: they download the app, period
- Natural evangelists: they land on a new unit and tell staff nurses "this saved me on my last contract"

Secondary v1 user: **new grad nurses in their first 90 days** — same pain profile, same zero-gatekeeper access.

---

## 30-day wedge plan

Week 1 — **Content + waitlist**
- Landing page with the one-liner from the PRD: "Never hunt for supplies again."
- 3 short TikTok/Reels videos per week from a nurse creator (partner, not employee) demonstrating the pain
- Waitlist signup — collect email + facility + role

Week 2 — **TestFlight / closed beta**
- Procedure checklists for the top 20 procedures (curate from existing nursing references — not clinical advice, just kit contents)
- Manual supply tagging (no AR)
- Simple leaderboard
- 50–100 travel nurses from the waitlist

Week 3 — **Paid launch**
- $4.99/mo or $39/yr in App Store / Play Store
- First paid conversion target: 5% of beta users = a handful of paying customers, but real revenue and real feedback
- Affiliate link for travel nurse influencers (30% first-year rev share)

Week 4 — **Unit-level hook**
- When the app detects 5+ active users on the same unit, surface: "Your unit has a SupplyCloset community — want to share it with your charge nurse?"
- Email capture → charge nurse outreach → $49/mo/unit pitch

By day 60, there's MRR from individual nurses. By day 90, there's at least one paying unit. By month 6, there's enough multi-unit footprint at one facility to start a facility-level conversation — the conversation the PRD originally wanted to start on day 1.

---

## What stops being on the critical path

- **AR camera overlay** — v2, after location data exists
- **Hospital admin portal** — v3, unchanged from PRD but no longer blocking
- **SAML/SSO, HIPAA BAAs, IT security reviews** — not required for B2C
- **Sales team** — not needed until facility-level deals
- **Epic/Cerner integrations** — already out of scope per PRD, stays out

---

## What changes in the PRD

- **Phase 1 MVP**: drop AR camera view from P0 → move to v2. Everything else stays.
- **Phase 2**: add "Individual nurse subscription" and "Unit subscription" as P0 monetization features.
- **Non-functional requirements**: the `< 500ms AR latency` target is deferred with AR itself. The rest stand.
- **Privacy**: stronger, not weaker — no hospital data flow means no PHI risk at all in v1.

---

## Risks this variant introduces

- **Thin moat at the consumer tier** — another app could clone the checklist + tagging feature. Mitigation: the crowdsourced location database per unit is the moat, and it compounds faster with bottom-up adoption than with slow hospital rollouts.
- **App store ToS** — some medical apps get flagged. Mitigation: position as a workflow/productivity tool for nurses, not a clinical decision tool. No dosing, no patient data.
- **Facility pushback** — some hospitals may view unofficial nurse tools as a security concern. Mitigation: no PHI, no patient data, no hospital network access required. It's a nurse's personal productivity tool, like a stethoscope.

---

## Decision gates

**Day 30:** Are beta users tagging supplies without being paid to? If no → the crowdsourcing loop is broken, fix before launch.

**Day 90:** Is there at least one paying unit? If no → the PLG motion isn't working; fall back to direct charge-nurse sales.

**Day 180:** Is facility-level conversion conversation happening organically? If yes → hire first AE. If no → stay consumer-only and re-evaluate the ARR thesis.

---

## Why this is lower risk than the original plan

- Revenue on day 21 instead of month 9+
- No HIPAA / BAA / procurement dependency for v1
- AR technical risk deferred until demand is proven
- Enterprise motion becomes *pulled* by footprint, not *pushed* by cold outreach
- Same end-state vision as the PRD — different, faster path to get there
