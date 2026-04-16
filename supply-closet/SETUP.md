# SupplyCloset — Setup Guide

This guide walks you through getting SupplyCloset running locally and deployed to Firebase + GCP. Estimated time: 60–90 minutes the first time.

## Prerequisites

You'll need:

- macOS, Linux, or Windows with WSL2
- Flutter SDK 3.22+ (`flutter doctor` should be all green)
- Node.js 20.x (for Cloud Functions)
- Firebase CLI (`npm install -g firebase-tools`)
- gcloud CLI (`brew install --cask google-cloud-sdk` or platform equivalent)
- Xcode (for iOS) and Android Studio (for Android), with simulators/emulators set up
- A GCP project (you have `gen-lang-client-0675309660`)
- Domain access for `supplycloset.app` (for production link routing)

## Step 1 — Clone and install dependencies

```bash
git clone https://github.com/KielRN/supply-closet.git
cd supply-closet/supply-closet
flutter pub get
```

## Step 2 — Create the Firebase project

We're going to layer Firebase on top of your existing GCP project rather than create a new one.

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → **Add Firebase to Google Cloud project**
3. Select `gen-lang-client-0675309660`
4. Accept defaults; enable Google Analytics (optional but recommended)

Once the project is created, enable these Firebase services:

- **Authentication** → Get Started → Sign-in method → Enable **Google**
  - Set the project support email to your address
- **Firestore Database** → Create database → Production mode → us-central1 (multi-region)
- **Cloud Functions** → Get Started (requires Blaze plan — credit card needed but free tier covers everything we'll use during development)

## Step 3 — Wire Firebase to the Flutter app

```bash
# From the supply-closet directory
dart pub global activate flutterfire_cli
flutterfire configure --project=gen-lang-client-0675309660
```

This will:

- Register iOS and Android apps in Firebase
- Generate `lib/firebase_options.dart` (gitignored — never commit)
- Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

When prompted, select both **iOS** and **Android** platforms.

## Step 4 — Configure Google Sign-In

### iOS

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target → Info → URL Types
3. Add a new URL Type with the `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` as the URL Scheme
4. Save and close

### Android

1. Get your debug SHA-1: `cd android && ./gradlew signingReport`
2. Copy the SHA-1 for the `debug` variant
3. Firebase Console → Project Settings → Your Android app → Add fingerprint → paste SHA-1
4. Re-download `google-services.json` and replace `android/app/google-services.json`

For release builds you'll repeat this with your release keystore SHA-1.

## Step 5 — Deploy Firestore rules and indexes

```bash
cd firebase
firebase use gen-lang-client-0675309660
firebase deploy --only firestore:rules,firestore:indexes
```

## Step 6 — Deploy Cloud Functions

```bash
cd firebase/functions
npm install

# Get a free openFDA API key (optional but recommended; bumps rate limit
# from 1000 to 120000 requests/day): https://open.fda.gov/apis/authentication/
firebase functions:config:set openfda.key="YOUR_OPENFDA_KEY"
# Or set it as a runtime env var instead:
# echo "OPENFDA_API_KEY=YOUR_KEY" > .env

cd ..
firebase deploy --only functions
```

You should see the following functions deployed:

- `lookupUdi` (callable)
- `awardXp` (callable)
- `onSupplyTagged` (Firestore trigger)
- `decayConfidence` (scheduled, daily 03:00 UTC)
- `syncRecalls` (scheduled, daily 04:00 UTC)
- `rolloverDailyChallenges` (scheduled, daily 00:00 UTC)
- `healthCheck` (HTTP)

## Step 7 — Seed the procedures and supplies catalogs

The app will load procedures from `assets/data/seed_procedures.json` on first launch and write them to Firestore. Same for `seed_supplies.csv`.

If you want to seed manually instead:

```bash
# From the firebase folder
firebase firestore:import ./seed_data
```

(You'll need to create `seed_data/` from the JSON/CSV beforehand using the Firestore CLI export format.)

## Step 8 — Run locally

### Android

```bash
# Make sure an emulator is running
flutter run
```

### iOS

```bash
cd ios
pod install
cd ..
flutter run
```

### Web (limited — AR features won't work in browser)

```bash
flutter run -d chrome
```

## Step 9 — Production builds

### Android (Play Store)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS (App Store)

```bash
flutter build ipa --release
# Then open ios/Runner.xcworkspace in Xcode and use Product → Archive
```

## Step 10 — GCP / Vertex AI for image recognition (Phase 2)

This is for the supply-image recognition feature that lets nurses tag supplies by snapping a photo instead of scanning a barcode. Not required for v1.

```bash
gcloud config set project gen-lang-client-0675309660
gcloud services enable aiplatform.googleapis.com
gcloud services enable storage.googleapis.com

# Create the bucket for training images
gsutil mb -l us-central1 gs://supplycloset-training-images
```

Vertex AI AutoML training will be set up via the GCP console once we have ~50 example images per supply class.

## Project structure cheat sheet

```
supply-closet/
├── lib/
│   ├── config/        # Theme, constants, routes
│   ├── models/        # SupplyItem, Procedure, UserProfile
│   ├── services/      # Auth, Firestore, Gamification engine
│   ├── providers/     # ChangeNotifier-based state
│   ├── widgets/       # XP bar, celebrations, streak card, etc.
│   ├── screens/
│   │   ├── auth/      # Login
│   │   ├── home/      # Bottom nav shell
│   │   ├── procedures/ # Procedures list, detail
│   │   ├── tag/       # 3-step tag flow
│   │   ├── find/      # AR finder
│   │   ├── leaderboard/
│   │   └── profile/
│   ├── app.dart
│   └── main.dart
├── assets/data/
│   ├── seed_procedures.json   # 20 nursing procedures
│   └── seed_supplies.csv      # ~200 universal supplies
├── firebase/
│   ├── firebase.json
│   ├── firestore.rules
│   ├── firestore.indexes.json
│   └── functions/
│       ├── package.json
│       └── index.js
└── android/, ios/
```

## Sensitive files (NEVER commit)

The `.gitignore` already excludes:

- `.env` and any `*.env` variants
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `credentials.json` (any GCP service account keys)
- `firebase-debug.log`
- Build outputs, IDE configs, etc.

If you accidentally commit any of these, rotate the credentials immediately.

## Troubleshooting

**`flutterfire configure` fails with "permission denied"** — make sure you're logged in: `firebase login` and `gcloud auth login`.

**Build fails on iOS with "Pods not found"** — `cd ios && pod install` then retry.

**Google Sign-In returns nothing on Android** — your debug SHA-1 isn't registered. Re-run Step 4.

**Cloud Functions fail to deploy with "Default service account not found"** — enable the Cloud Functions API: `gcloud services enable cloudfunctions.googleapis.com`.

**Firestore writes are denied** — check `firestore.rules` is deployed and your user document exists. The first sign-in creates the user doc; if that failed, the user is authed but rules block their writes.

## ⚠️ Security Notice

An adversarial review identified **21 findings** across security, data integrity, and gamification exploits. **2 critical issues** (role escalation, XP farming) must be fixed before any deployment.

See the full review: [`adversarial-review.md`](../adversarial-review.md)
Track remediation progress: [`remediation-plan.md`](../remediation-plan.md)

## What's next

After you have it running locally, the immediate roadmap is:

1. **Fix critical security findings** (see remediation plan)
2. Test the full sign-in → tag → find loop on a real device
3. Recruit a friendly nurse (you?) to tag 50 real supplies in a supply room
4. Validate the gamification feels rewarding
5. Set up Crashlytics + Analytics
6. Submit to TestFlight (iOS) and Internal Testing (Android)

When you're ready for pilot, see `data-strategy.md` for the Founding Tagger onboarding flow.
