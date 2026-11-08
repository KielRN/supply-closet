# SupplyCloset

Flutter app for AR-assisted clinical supply finding and tagging.

## Android Phone Testing (Moto G Stylus 5G - 2024)

This repo is set up for Android dev builds from Windows targeting the **Moto G Stylus 5G (2024)** (see [`../USER.md`](../USER.md) for simple step-by-step phone instructions).

1. Enable Developer options on the Android phone.
2. Enable USB debugging.
3. Plug the phone into this machine and accept the USB debugging prompt.
4. Confirm Flutter sees it:

```powershell
flutter devices
```

5. Run the app on the phone:

```powershell
flutter run -d <device-id>
```

To verify the Android build without a phone:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Firebase Android Setup

Android application id:

```text
app.supplycloset
```

For Firebase Auth / Google Sign-In debug testing, register this machine's debug
certificate fingerprints on the Firebase Android app:

```text
SHA1:   7F:D9:D6:89:19:82:6F:24:EB:13:44:19:2D:6E:34:55:4A:D1:E6:98
SHA256: 84:EB:78:FF:F4:71:29:CC:67:A3:2E:09:C5:62:95:EC:86:43:D8:5E:3C:68:74:90:24:F6:DD:A8:BD:1B:6F:A1
```
