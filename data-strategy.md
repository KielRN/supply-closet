# SupplyCloset — Data Strategy

**Subtitle:** How we solve the cold-start problem and build a defensible data moat
**Author:** Elliott
**Last updated:** April 2026
**Status:** Draft for review

---

## Executive summary

SupplyCloset's value to a nurse on day one depends on the app already knowing two things:

1. **What** supplies exist (canonical names, sizes, barcodes, what they look like)
2. **Where** those supplies live in *their* specific supply room

The first is a content problem solvable with public data. The second is a crowdsourced spatial-mapping problem that no one has solved at scale — and it is our moat.

This document covers:

- Which public hospital supply databases exist and what they're useful for
- The hybrid bootstrap strategy: pre-seeded universal catalog + procedure kits + crowdsourced facility data
- The "First Tagger" gamification mechanic that turns the empty-database problem into an onboarding hook
- Technical implementation: data sources, sync cadence, conflict resolution, confidence scoring
- A 90-day roadmap to get from zero data to a usable app on the first hospital floor

The short version: we ship with ~200 universally-used supplies pre-mapped to the top 20 nursing procedures, then let nurses crowdsource the rest of their facility-specific catalog and exact bin locations. The first nurse on each unit becomes the "Founding Tagger" and earns outsized rewards for mapping the room.

---

## The cold-start problem

A typical med-surg supply room contains 800–1,500 distinct SKUs. A typical hospital uses 30,000–50,000 unique medical supplies across all units. No two hospitals stock identically — they buy through different Group Purchasing Organizations (GPOs) like Premier, Vizient, or HealthTrust, which means the brand of Foley catheter on Unit 4 East at Hospital A is almost certainly different from the one on the same unit type at Hospital B.

If a nurse downloads SupplyCloset and the app shows an empty list, they bounce. We need to give them value within the first 60 seconds.

There are three layers of data we need to populate:

| Layer | What it is | How it's obtained | Universal vs. local |
|---|---|---|---|
| 1. Canonical catalog | Every medical device's name, brand, sizes, barcode, image | Pre-seeded from public sources (GUDID, openFDA) + barcode scans | Universal |
| 2. Procedure kits | Which supplies are needed for which procedures (Foley insert, IV start, dressing change) | Hand-curated from nursing standards (AORN, ANA, textbooks) | Universal with local variants |
| 3. Spatial mapping | Where each supply lives in *this specific* supply room (which bin, which shelf) | Crowdsourced from nurses on each unit | Hyper-local |

Public data solves layer 1. Hand-curation solves layer 2. Layers 3 is what nurses on the unit do — and it's what we own.

---

## Public data sources

### GUDID (Global Unique Device Identification Database) — primary source

The FDA's [GUDID](https://accessgudid.nlm.nih.gov/) is the single most useful public source for medical supply data. Every Class I, II, and III medical device sold in the US is required by law to have a Unique Device Identifier (UDI) and be registered in GUDID.

**What it provides for each device:**
- Brand name and proprietary name (e.g., "Bardex I.C. Foley Catheter")
- Company name (e.g., "C. R. Bard, Inc.")
- Device description
- Sizes and dimensions
- GMDN preferred term (the global classification code)
- Primary UDI/DI (Device Identifier portion of the barcode)
- Production identifiers (lot, serial, expiration formatting)
- Lifecycle status (in commercial distribution, recalled, etc.)

**How to access it:**
- Free bulk downloads as zip files (~1.5GB, updated weekly)
- Free API via [openFDA](https://open.fda.gov/apis/device/udi/): `https://api.fda.gov/device/udi.json?search=brand_name:foley`
- Rate limited to 1,000 requests/day without a key, 120,000/day with a free API key

**Limitations:**
- US-only (devices sold internationally won't be there unless also sold in the US)
- Catalog data only — no pricing, no images of most items, no facility-level data
- Some smaller manufacturers have minimal records
- Doesn't include consumables that aren't classified as medical devices (alcohol pads, paper towels, generic gloves)

### GS1 GDSN (Global Data Synchronization Network)

GS1 maintains the [global standards for barcodes](https://www.gs1.org/) (GTINs, the 12–14 digit numbers under every barcode). Hospital supply chains use GS1 standards extensively. A subset of product data flows through the GS1 GDSN data pool.

**What it provides:**
- The global barcode-to-product registry
- Higher-quality images and dimensional data than GUDID for many items
- International coverage

**Access:**
- Reading a GS1-128 or GS1 DataMatrix barcode and parsing it to extract the GTIN: free and open
- Looking up a GTIN against the full GDSN catalog: requires GS1 membership and data pool subscription (~$1,200–$5,000/year depending on company size)

**Our recommendation:** Build the barcode parser using open GS1 standards (we don't need to pay anything to scan and decode a barcode). Use GUDID as the lookup database for now. Revisit a GDSN subscription later when we want richer non-medical-device data.

### openFDA (broader)

Beyond GUDID, [openFDA](https://open.fda.gov/) exposes:
- Device recalls (`/device/recall.json`) — useful for showing a "RECALLED" warning if a nurse scans a pulled SKU
- 510(k) clearances (`/device/510k.json`) — useful for understanding device equivalence
- Adverse event reports (`/device/event.json`) — could power a long-term safety feature

### NDC (National Drug Code) — for drug-adjacent supplies

The [FDA's NDC directory](https://www.accessdata.fda.gov/scripts/cder/ndc/) covers prescription drugs and many drug-adjacent supplies (saline flushes, heparin locks, prefilled syringes). Free download, daily updates. We'll need this for any procedure kit that includes a medication-prep step.

### What's NOT publicly available

- **Pricing**: Hospital contract pricing is opaque and proprietary to each GPO/hospital relationship. We will never have this through public channels.
- **Par levels and stock levels**: Lives in each hospital's materials management system (Workday Supply Chain, Oracle, McKesson, Epic Willow). Requires per-hospital integration.
- **Bin locations and physical layouts**: Doesn't exist anywhere. This is what nurses tell us — and what makes our data unique.
- **GPO formularies**: Premier, Vizient, and HealthTrust catalogs are members-only. We could potentially partner with a GPO down the road.

---

## The hybrid bootstrap strategy

We get the best of all worlds by stacking three approaches.

### Layer 1: The Universal Starter Catalog (~200 items)

Ship the app with a hand-curated catalog of the most common nursing supplies. Every nurse, regardless of facility, recognizes these. They cover roughly 80% of the supplies needed for the top 20 procedures.

The catalog is built once by us:

1. Pull the top-frequency items from nursing textbook procedure kits (Lippincott, Potter & Perry)
2. For each, find the canonical GUDID record (or generic equivalent if not a registered device)
3. Capture: canonical name, common sizes, image URL (source from manufacturer if license allows, else stock photo), GMDN code, typical barcode pattern

A nurse opening the app for the first time sees a populated catalog they recognize. When they tag the first Foley in their supply room, they pick from this list rather than typing.

**Suggested initial 200 (sample):**

- Foley catheter kits (14 Fr, 16 Fr, 18 Fr — silicone and latex)
- IV start kits (20 ga, 22 ga, 24 ga)
- Sterile gloves (sizes 6.0–8.5 in 0.5 increments)
- Non-sterile exam gloves (S, M, L, XL — nitrile and latex)
- 4x4 gauze pads (sterile and non-sterile)
- Alcohol prep pads (small and large)
- Chlorhexidine prep applicators (3 mL and 26 mL)
- Saline flushes (3 mL, 10 mL)
- Tegaderm and similar transparent dressings (multiple sizes)
- Tape (paper, silk, cloth — multiple widths)
- Syringes (1 mL, 3 mL, 5 mL, 10 mL, 20 mL, 60 mL)
- Needles (multiple gauges and lengths)
- Specimen cups
- Urine hat
- Bedpans, urinals, emesis basins
- Suction catheters (multiple sizes)
- NG tubes (multiple sizes)
- Trach care kits
- Wound care supplies (multiple)
- Ostomy supplies (multiple)
- ECG electrodes
- Pulse ox sensors (adult, ped, neonatal — disposable)
- BP cuffs (single-patient-use)
- Dressing change kits
- Suture removal kits
- Staple removal kits
- IV tubing (primary, secondary, with filter)
- IV fluids — note the canonical packaging (NS, LR, D5W, D5NS in 250/500/1000 mL)
- Central line dressing kits
- Restraint supplies

A more complete CSV of the 200 lives at `assets/data/seed_supplies.csv`.

### Layer 2: Procedure Kits (~20 procedures at launch)

Each procedure has a canonical kit pulled from nursing standards. When a nurse selects "Foley insertion" they see the checklist immediately, even if no one on their unit has tagged anything yet.

**Launch procedures:**

1. Foley catheter insertion (female / male)
2. Peripheral IV start
3. Central line dressing change
4. Tracheostomy care
5. NG tube insertion
6. Wound dressing change (clean / sterile)
7. Blood draw / specimen collection
8. IM injection
9. Sub-Q injection
10. Sterile dressing change
11. Catheterization removal
12. Suture removal
13. Staple removal
14. Foley irrigation
15. Suctioning (oral / nasal / trach)
16. Ostomy care
17. Glucose check
18. Isolation room setup
19. Code blue cart restock check
20. Admission kit assembly

Each kit lists supplies + sizes + quantities, marks optional vs. required, and links to a brief technique reminder.

### Layer 3: Crowdsourced Local Data (everything else)

This is the magic. The app shows the seed catalog and procedure kits, but the actual locations are blank until nurses tag them. The first nurse to tag a supply in their room gets:

- Big XP bonus (+50 vs. the standard +10)
- "Founding Tagger" badge (rare tier) for the first 10 supplies they tag in a new room
- A leaderboard slot specifically for "rooms mapped" alongside "supplies tagged"
- A visible counter on the home screen: "You've mapped 23 of an estimated 800 supplies on your unit"

Once 2–3 nurses confirm a tag (matching item + matching location ± 1 meter), the confidence score crosses the "reliable" threshold and other staff trust it without needing to verify.

For facility-specific brands not in our seed catalog, the nurse:

1. Scans the barcode (Google ML Kit barcode scanner, on-device)
2. The barcode is parsed for GTIN and looked up against GUDID via openFDA in real time
3. If found, the canonical record auto-populates (brand, size, etc.) and the nurse just confirms
4. If not found (rare for medical devices, common for generic consumables), the nurse types a short name and snaps a photo — the entry is flagged as "user-submitted" until reviewed

After 30 days on a unit with 5+ active nurses, we expect to have ~70% of the supply room mapped.

---

## The "First Tagger" mechanic — turning the empty-database problem into a feature

Empty databases feel broken. But "be the first to map your supply room" feels exciting — especially when paired with the gamification system already in the app.

**The flow when a nurse opens the app on a new unit:**

1. Onboarding asks for facility + unit
2. App detects: "No one from your unit has used SupplyCloset yet"
3. Big celebration screen: **"You're the founding nurse for [Unit Name]! Map your supply room and earn 5x XP for everything you tag this week."**
4. Tutorial walks them through tagging their first 3 supplies (slow, guided)
5. They get a Founding Tagger badge after their 10th tag
6. Their name is displayed at the bottom of the unit's leaderboard with a special "FOUNDER" chip

**The flow when nurse #2 joins:**

1. Onboarding detects: "1 other nurse from your unit is using SupplyCloset"
2. They see [First Nurse]'s tags already on the map
3. App suggests: "Confirm [First Nurse]'s tags as you find them in the supply room. Each confirmation = +5 XP. If something has moved, just retag it."

**The flow at unit saturation (~70% mapped):**

1. App switches messaging from "tag new supplies" to "keep your map fresh"
2. Stale supplies (not confirmed in 7+ days) get a yellow flag and offer +10 XP for confirming
3. Leaderboard shifts to weekly cycles ("most freshness updates this week")

**Why this works:**

- It reframes "the database is empty" as "you have an opportunity"
- It rewards the highest-effort early adopters most
- It naturally throttles — once a unit is mapped, the rewards shift to maintenance
- It creates a per-unit social dynamic (everyone knows who founded the room)
- It drives organic growth: founders evangelize because they want their tags confirmed

---

## Technical implementation

### Data sources and sync

| Source | Sync method | Frequency | Where it lives |
|---|---|---|---|
| GUDID (full bulk) | One-time download → BigQuery | Initial seed | BigQuery dataset `gudid_raw` |
| GUDID (delta updates) | openFDA API polling | Weekly Cloud Function | Updates `gudid_raw` |
| openFDA recall data | API polling | Daily Cloud Function | Firestore `recalls/{udi}` |
| Seed catalog (200 items) | Hand-curated, version-controlled | On app release | `assets/data/seed_supplies.csv` |
| Procedure kits | Hand-curated, version-controlled | On app release + Firestore overlay | `assets/data/seed_procedures.json` |
| User-tagged supplies | App writes to Firestore | Real-time | `facilities/{fid}/units/{uid}/supplies` |
| Barcode → catalog lookup | App calls Cloud Function `lookupUdi` | On scan | Returns GUDID record + caches |

### The barcode lookup function

A Cloud Function `lookupUdi(barcode: string)` does the following:

1. Parses the barcode — handles GS1-128, GS1 DataMatrix, plain UPC/EAN
2. Extracts the GTIN/UDI-DI
3. Checks Firestore cache `udi_cache/{di}` first (cheap, fast)
4. If miss, queries openFDA: `https://api.fda.gov/device/udi.json?search=identifiers.id:"{di}"`
5. If found, returns the canonical record and writes to cache
6. If not found, falls back to GS1 prefix lookup (manufacturer identification at minimum)
7. If still nothing, returns `unknown` and the app prompts the nurse to enter details manually

Cached UDIs are evicted after 90 days to pick up any GUDID record updates.

### Confidence scoring (recap from architecture doc)

A tag's confidence is a function of:

- Number of distinct nurses who confirmed it: `min(n * 0.2, 0.6)`
- Recency of last confirmation: decays by 0.05/week after 7 days
- Spatial agreement: confirmations within 1m boost, conflicting locations split
- Source reliability: Founding Tagger gets a 0.1 boost (they earned trust)

Reliable threshold: 0.6. Below that, the supply is shown but flagged "Unconfirmed".

### Conflict resolution

When two nurses tag the same supply in different locations:

- If both within 1m: merged, midpoint location, confidence summed
- If 1–3m apart: app shows both, asks the next nurse "which bin?"
- If 3m+: treated as separate stock locations (possible — same supply in two bins)

### Privacy and HIPAA

- We capture supply names, locations, timestamps, and tagger IDs only
- No patient data, no procedure-on-patient linking, no PHI ever
- Camera frames are processed on-device (TFLite + ARCore/ARKit) and discarded
- Nurses can opt out of leaderboards (still earn XP privately)
- Facility admins can see aggregate utilization but never individual nurse tagging history (to prevent surveillance concerns)

---

## 90-day roadmap to first usable hospital floor

### Days 0–30: Build the seed

- Curate the 200-item universal catalog (CSV)
- Curate the 20 procedure kits (JSON)
- Pull GUDID bulk download into BigQuery
- Deploy `lookupUdi` Cloud Function with openFDA integration
- Write the recall sync function
- Build the in-app first-tag tutorial
- Implement Founding Tagger badge + 5x XP onboarding bonus

### Days 30–60: Pilot a single unit

- Recruit one friendly unit at one hospital (start with Elliott's network)
- Onboard 3–5 nurses as Founding Taggers
- Daily monitoring of tag accuracy, confidence scores, and conflict frequency
- Tune the confidence model based on what we see
- Add any common supplies missing from the seed catalog
- Goal: 70% of supply room mapped, 90% confidence on top-50 supplies

### Days 60–90: Expand to 3 units

- Same hospital, different unit types (ICU, med-surg, ED)
- Test the cross-unit data leak — does mapping ICU help med-surg? (probably partially)
- Run the first weekly unit challenge (cooperative)
- Survey nurses on accuracy, time-to-find, NPS
- Decide: is the seed catalog +1 hospital data enough to launch a new hospital cold, or do we need a "starter unit" partnership model?

### Day 90 onward

- Open registration for additional facilities
- Build the analytics dashboard for facility supply chain teams (this is also our monetization play)
- Begin GPO partnership conversations (Premier, Vizient) — they want utilization data too

---

## Open questions

1. **Image rights for the catalog**: Manufacturer product photos are typically copyrighted. We should either (a) license images from manufacturers (often free if we're driving sales of their SKUs), (b) take our own photos of common supplies, or (c) use AI-generated stock illustrations for the seed catalog and replace with nurse-snapped photos as they tag.
2. **Voice tagging**: Many nurses wear gloves. Should the first version support voice tagging ("I'm at bin C-3, this is Foley 16 French")? Probably yes — Whisper API on-device or via Cloud Functions.
3. **Generic vs. branded SKUs**: When a seed entry says "alcohol prep pad" but the unit stocks "BD Alcohol Swabstick", do we treat them as the same supply or distinct? Recommendation: same canonical entity, two SKU children.
4. **Supply room boundaries**: How does the app know when the nurse is in the supply room vs. a patient room? GPS won't work indoors. Likely solution: nurse opens the app explicitly and the AR session marks the room via visual SLAM.

---

## TL;DR

We don't need to wait for a complete database to ship. We pre-seed the universal stuff (200 supplies, 20 procedures), use openFDA/GUDID for barcode enrichment, and let the crowdsourced spatial mapping be the unique value we build over time. The "Founding Tagger" mechanic turns the empty-database problem into an onboarding hook that aligns perfectly with the gamification system we already have.

Next step: I'll bake the seed catalog and openFDA enrichment into the codebase as I write the remaining screens (tag, AR finder) and Cloud Functions.
