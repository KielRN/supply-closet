# SupplyCloset.app — Technical Architecture Document

**Version:** 1.0
**Date:** April 12, 2026
**Platform:** Google Cloud (GCP)

---

## 1. Architecture Overview

SupplyCloset is built on a serverless-first GCP stack. The mobile app handles AR rendering and camera processing on-device, communicating with a Firebase + Cloud Run backend. Vertex AI powers the computer vision model that recognizes supply items and supply room layouts. Firestore serves as the real-time database for crowdsourced supply location data.

```
┌─────────────────────────────────────────────────────────────┐
│                      MOBILE CLIENT                          │
│  (Flutter / React Native — iOS & Android)                   │
│                                                             │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐    │
│  │ AR Engine │  │ Camera + CV  │  │ Gamification UI    │    │
│  │ (ARCore / │  │ (on-device   │  │ (Points, Badges,   │    │
│  │  ARKit)   │  │  TFLite      │  │  Leaderboards)     │    │
│  │           │  │  model)      │  │                    │    │
│  └──────────┘  └──────────────┘  └────────────────────┘    │
│                        │                                    │
│                        ▼                                    │
│              ┌──────────────────┐                           │
│              │ Barcode Scanner  │                           │
│              │ (ML Kit)         │                           │
│              └──────────────────┘                           │
└──────────────────────┬──────────────────────────────────────┘
                       │  HTTPS / gRPC
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                    FIREBASE LAYER                             │
│                                                              │
│  ┌────────────────┐  ┌──────────────┐  ┌────────────────┐   │
│  │ Firebase Auth   │  │ Firestore    │  │ Cloud          │   │
│  │ (Google Sign-In │  │ (Real-time   │  │ Functions      │   │
│  │  + future SSO)  │  │  supply DB)  │  │ (triggers,     │   │
│  │                 │  │              │  │  scoring)       │   │
│  └────────────────┘  └──────────────┘  └────────────────┘   │
│                                                              │
│  ┌────────────────┐  ┌──────────────┐                        │
│  │ Firebase Cloud  │  │ Remote       │                        │
│  │ Messaging (FCM) │  │ Config       │                        │
│  │ (push notifs)   │  │ (feature     │                        │
│  │                 │  │  flags)      │                        │
│  └────────────────┘  └──────────────┘                        │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                    GCP BACKEND                                │
│                                                              │
│  ┌────────────────┐  ┌──────────────┐  ┌────────────────┐   │
│  │ Cloud Run       │  │ Vertex AI    │  │ BigQuery       │   │
│  │ (API services,  │  │ (model       │  │ (analytics     │   │
│  │  admin portal)  │  │  training,   │  │  warehouse,    │   │
│  │                 │  │  prediction) │  │  vendor data)  │   │
│  └────────────────┘  └──────────────┘  └────────────────┘   │
│                                                              │
│  ┌────────────────┐  ┌──────────────┐  ┌────────────────┐   │
│  │ Cloud Storage   │  │ Pub/Sub      │  │ Looker Studio  │   │
│  │ (model          │  │ (event       │  │ (dashboards    │   │
│  │  artifacts,     │  │  streaming)  │  │  for hospitals │   │
│  │  training data) │  │              │  │  & vendors)    │   │
│  └────────────────┘  └──────────────┘  └────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Component Deep Dives

### 2.1 Mobile Client

**Framework:** Flutter (recommended for cross-platform with single codebase) or React Native.

**AR Engine:**
- **Android:** ARCore for surface detection, anchor placement, and rendering supply markers in 3D space
- **iOS:** ARKit for the same capabilities on Apple devices
- The AR layer renders floating labels and directional arrows over supply room shelves based on known coordinates

**On-Device Computer Vision:**
- A TensorFlow Lite model runs on-device for real-time supply item recognition
- The model is trained on Vertex AI (see section 2.4) and exported in TFLite format for edge deployment
- Vertex AI supports mobile-optimized export targets: `MOBILE_TF_VERSATILE_1`, `MOBILE_TF_HIGH_ACCURACY_1`, and `MOBILE_TF_LOW_LATENCY_1`
- On-device inference means no camera frames leave the phone — critical for hospital privacy requirements

**Barcode Scanning:**
- Google ML Kit Barcode Scanning API for instant supply identification
- Supports UPC, EAN, Code 128, and GS1 barcodes commonly used on medical supplies

### 2.2 Firebase Layer

**Authentication (Firebase Auth):**
- Google Sign-In for MVP (low friction, most nurses have personal Google accounts)
- Architecture supports adding SAML/OIDC providers later for hospital SSO
- User profiles store: display name, facility ID, unit ID, role (nurse / charge / admin)

**Database (Cloud Firestore):**

Firestore is the primary real-time database. Its document model maps naturally to the data hierarchy:

```
facilities/
  {facilityId}/
    units/
      {unitId}/
        supplyRooms/
          {roomId}/
            supplies/
              {supplyId}/
                - name: "Foley Catheter Kit 16Fr"
                - barcode: "00850003..."
                - location: { shelf: "B", bin: 3, x: 0.45, y: 1.2, z: 0.8 }
                - confidence: 0.87
                - lastConfirmed: timestamp
                - tagCount: 23
                - taggedBy: [ userId1, userId2, ... ]

users/
  {userId}/
    - displayName: "Maria R."
    - facilityId: "mercy_west"
    - unitId: "3_south"
    - points: 1450
    - badges: [ "trailblazer", "night_owl" ]
    - tagsThisMonth: 42

procedures/
  {procedureId}/
    - name: "Foley Catheter Insertion"
    - supplies: [ "foley_kit_16fr", "sterile_gloves_lg", "betadine_swabs", ... ]
    - category: "urinary"
```

**Why Firestore:**
- Real-time listeners let supply locations update across all nurses on a unit instantly
- Offline persistence built in — checklists work without connectivity
- Scales automatically without provisioning
- Firestore Security Rules enforce that nurses can only write to their own facility/unit

**Cloud Functions (Firebase):**
- **Scoring engine:** Triggered on every supply tag/confirm event. Calculates points, checks badge criteria, updates leaderboards.
- **Confidence decay:** Scheduled function runs nightly. Reduces confidence scores for supply locations not confirmed in 7+ days.
- **Stockout aggregation:** When 3+ nurses report an item "not found" within a shift, triggers a notification to the charge nurse.

**Remote Config:**
- Feature flags for phased rollouts (e.g., enable gamification v2 for select facilities)
- Tunable parameters: point values, confidence decay rate, leaderboard reset cadence

### 2.3 GCP Backend Services

**Cloud Run (API Layer):**
- Stateless containerized services for:
  - Admin portal API (hospital dashboard)
  - Vendor data API (authenticated, rate-limited)
  - Bulk data export jobs
  - Procedure checklist management (CRUD)
- Auto-scales to zero when idle — cost-efficient for early stage

**Pub/Sub (Event Bus):**
- Every supply tag, confirmation, and "not found" event is published to Pub/Sub
- Consumers:
  - BigQuery sink (for analytics)
  - Notification service (charge nurse alerts)
  - ML pipeline trigger (retrain models when new data threshold is met)

**BigQuery (Analytics Warehouse):**
- Central analytics store for all supply interaction events
- Powers:
  - Vendor analytics dashboards (Looker Studio)
  - Hospital admin reports
  - Internal product analytics
  - ML training data pipelines
- Partitioned by facility and date for cost-efficient queries

**Cloud Storage:**
- ML model artifacts (trained models, TFLite exports)
- Training data (labeled supply images)
- Static assets for the admin portal

### 2.4 Vertex AI (Computer Vision Pipeline)

**Training Pipeline:**

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Image         │    │ Vertex AI    │    │ Model        │
│ Collection    │───▶│ AutoML       │───▶│ Registry     │
│ (labeled      │    │ Image Object │    │ (versioned   │
│  supply       │    │ Detection    │    │  models)     │
│  photos)      │    │ Training     │    │              │
└──────────────┘    └──────────────┘    └──────┬───────┘
                                               │
                              ┌────────────────┼────────────────┐
                              ▼                ▼                ▼
                    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
                    │ TFLite       │  │ Cloud         │  │ Endpoint     │
                    │ Export       │  │ Endpoint      │  │ (batch       │
                    │ (on-device)  │  │ (fallback)    │  │  prediction) │
                    └──────────────┘  └──────────────┘  └──────────────┘
```

**How it works:**
1. **Bootstrap phase:** Collect and label a seed dataset of common medical supplies (start with the 200 most common items across the top 20 procedures). Use a mix of stock images, manufacturer catalog photos, and a small set of real supply room photos.
2. **AutoML training:** Use Vertex AI AutoML Image Object Detection to train a model that identifies supply items in camera frames. AutoML handles architecture search, hyperparameter tuning, and data augmentation.
3. **Edge export:** Export the trained model in TFLite format optimized for mobile (`MOBILE_TF_VERSATILE_1` for balanced accuracy/latency).
4. **Continuous learning:** As nurses tag and confirm supplies, new labeled data flows into Cloud Storage. When a threshold is met (e.g., 1,000 new tags), a Vertex AI Pipeline retrains the model and pushes an update to the app via Firebase Remote Config.
5. **Fallback:** If on-device inference confidence is low, the app can optionally send the frame to a Vertex AI online prediction endpoint for higher-accuracy server-side inference.

**Crowdsourced Spatial Mapping:**
- Beyond item recognition, the app uses ARCore/ARKit to capture the spatial layout of supply rooms
- Anchor points (shelf edges, bin dividers) are stored as 3D coordinates relative to a room-level origin
- Over time, multiple nurses scanning the same room builds a consensus spatial model — essentially a crowdsourced "planogram" of each supply room

### 2.5 Data Pipeline for Monetization

```
Firestore (real-time) ──▶ Pub/Sub ──▶ BigQuery (raw events)
                                           │
                                           ▼
                                    ┌──────────────┐
                                    │ dbt / SQL    │
                                    │ transforms   │
                                    └──────┬───────┘
                                           │
                              ┌────────────┼────────────────┐
                              ▼            ▼                ▼
                    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
                    │ Looker       │ │ Vendor API   │ │ Hospital     │
                    │ Studio       │ │ (Cloud Run)  │ │ Admin Portal │
                    │ (internal)   │ │              │ │              │
                    └──────────────┘ └──────────────┘ └──────────────┘
```

All data is anonymized before reaching vendor-facing layers. Nurse identities are never exposed — only aggregated facility/unit-level metrics.

---

## 3. Security and Compliance

| Concern | Approach |
|---|---|
| **No PHI** | The app collects zero patient health information. It only records supply item identities, locations, and timestamps. |
| **Camera privacy** | Camera frames are processed on-device. No images are uploaded to the server. Only metadata (item ID, spatial coordinates) is transmitted. |
| **Authentication** | Firebase Auth with Google Sign-In. Tokens are short-lived (1 hour) with automatic refresh. |
| **Data in transit** | All communication over HTTPS/TLS 1.3. gRPC for high-frequency data. |
| **Data at rest** | Firestore and BigQuery encrypt data at rest by default (Google-managed keys). Option to use Customer-Managed Encryption Keys (CMEK) for enterprise contracts. |
| **Access control** | Firestore Security Rules enforce facility/unit-level data isolation. Cloud Run services use IAM for service-to-service auth. |
| **SOC 2** | Target SOC 2 Type II compliance within 12 months. GCP's underlying infrastructure is already SOC 2 certified. |
| **HIPAA BAA** | Not required for MVP (no PHI), but GCP supports HIPAA BAAs if future features touch clinical data. |

---

## 4. Infrastructure Cost Estimate (MVP, ~50 Facilities)

| Service | Estimated Monthly Cost | Notes |
|---|---|---|
| Firebase Auth | Free | Up to 10K MAUs on Spark plan; Blaze plan beyond |
| Firestore | $200–$500 | Based on ~5M reads/day, ~500K writes/day |
| Cloud Functions | $50–$150 | Event-driven, scales to zero |
| Cloud Run | $100–$300 | Admin portal + API; scales to zero |
| Vertex AI (training) | $200–$500/month | AutoML retraining monthly; inference mostly on-device |
| BigQuery | $100–$300 | Storage + queries; partitioned for efficiency |
| Cloud Storage | $20–$50 | Model artifacts, training data |
| Pub/Sub | $20–$50 | Event streaming |
| FCM | Free | Push notifications |
| **Total** | **~$700–$1,850/month** | Grows with usage; serverless means no idle waste |

---

## 5. Technology Decisions and Rationale

| Decision | Choice | Why |
|---|---|---|
| Mobile framework | Flutter | Single codebase, excellent ARCore/ARKit plugin ecosystem, strong Google ecosystem alignment |
| Database | Firestore | Real-time sync across nurses on the same unit, offline support, serverless scaling |
| ML platform | Vertex AI AutoML | Low barrier to train custom object detection models; native TFLite export for on-device inference |
| Backend compute | Cloud Run | Serverless containers — no infra to manage, scales to zero, pay-per-use |
| Analytics | BigQuery + Looker Studio | Best-in-class for the data monetization pipeline; SQL-native, integrates with everything on GCP |
| Auth | Firebase Auth | Google Sign-In in 5 lines of code; extensible to SAML/OIDC later |
| Event bus | Pub/Sub | Decouples real-time events from downstream consumers; guaranteed delivery |

---

## 6. Development Roadmap (Technical Milestones)

### Month 1–2: Foundation
- Set up GCP project, Firebase project, CI/CD pipeline
- Flutter app scaffold with Firebase Auth (Google Sign-In)
- Firestore data model and security rules
- Basic procedure checklist UI (no AR yet)
- Seed database with 20 procedure checklists

### Month 3–4: AR + CV Core
- Integrate ARCore/ARKit into Flutter app
- Collect and label seed training data (~5,000 supply images)
- Train initial Vertex AI AutoML object detection model
- Export TFLite model, integrate on-device inference
- Build tag-and-confirm flow with AR overlays
- Barcode scanning via ML Kit

### Month 5–6: Gamification + Real-Time
- Points, badges, and leaderboard system (Cloud Functions)
- Real-time supply location updates via Firestore listeners
- Confidence scoring and decay logic
- Push notifications (FCM)
- Pub/Sub event pipeline to BigQuery

### Month 7–8: Dashboards + Data
- Hospital admin portal (Cloud Run + React web app)
- Looker Studio dashboards for internal analytics
- Vendor data API (Cloud Run, authenticated)
- Data anonymization and aggregation pipeline in BigQuery

### Month 9–12: Scale + Harden
- Continuous model retraining pipeline (Vertex AI Pipelines)
- SSO integration for enterprise hospitals
- SOC 2 Type II preparation
- Performance optimization, load testing, accessibility audit
