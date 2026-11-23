# SupplyCloset — Session Handoff (`HANDOFF.md`)

**Date:** November 9, 2026  
**Connected Test Device:** Moto G Stylus 5G - 2024 (`ZY22KP4X7C` via USB)  
**Firebase Project:** `gen-lang-client-0675309660`  
**Related Trackers:** [ROADMAP.md](ROADMAP.md) · [DECISIONS.md](DECISIONS.md) · [USER.md](USER.md) · [AGENTS.md](AGENTS.md)

---

## Android doorway pilot — November 21, 2026

The new Android setup measures the two upper doorframe corners from inside the selected room. Finder can restore locally saved bin positions after confirming that same doorway. On November 22, 2026 the verified debug APK was installed over the existing app on Elliott's Moto G Stylus 5G (2024, `boston`). Google Play Services for AR 1.57.262640293 was installed. Finder → Find in AR → Map this bin → Measure bin with AR opened the native scanner and its ARCore session processed live frames. At this check the session was initializing tracking. Doorframe confirmation, physical drift, and five-reopen accuracy remain to be verified. Follow the [phone test guide](USER.md).

## 1. What Was Accomplished & Deployed to the Phone (`ZY22KP4X7C`)

| Status | Item | Details |
| :---: | :--- | :--- |
| 🟢 | **Built Room-Aware Sticky Feature Dots & Finger-in-Bin Scanner (`DEC-014`)** | Added [`spatial_room_scanner.dart`](supply-closet/lib/services/spatial_room_scanner.dart) and native Android 3D orientation sensors in [`MainActivity.kt`](supply-closet/android/app/src/main/kotlin/app/supplycloset/MainActivity.kt), and upgraded [`room_initiation_screen.dart`](supply-closet/lib/screens/room/room_initiation_screen.dart) & [`ar_finder_screen.dart`](supply-closet/lib/screens/find/ar_finder_screen.dart) so feature dots progressively appear on real shelf/bin corners, stick to 3D room coordinates with triangulation mesh lines, and read when a user reaches their finger into (or taps) a 3D wireframe bin cube. |
| 🟢 | **Built Room Initiation Scanner (`+250 XP`)** | Added [`room_initiation_screen.dart`](supply-closet/lib/screens/room/room_initiation_screen.dart) and [`supply_room.dart`](supply-closet/lib/models/supply_room.dart) so unmapped rooms prompt a 3-step doorway scan (Gaussian Splat preview + 3D Shelf Racks A/B/C) awarding **+250 XP** (`initiateRoom`) + `room_pioneer` badge (`DEC-012`). |
| 🟢 | **Upgraded Finder to 3D Gaussian Splat + Gaming AR HUD** | Rebuilt [`ar_finder_screen.dart`](supply-closet/lib/screens/find/ar_finder_screen.dart) with a dual-mode **"God's Eye View" 3D Gaussian Splat Viewer** (click-to-fly camera + layer toggles) and **First-Person Gaming AR HUD** (Compass Ribbon, Mini-Map Radar, 360° Off-Screen Turn Chevrons, 3D Floor Path Chevrons, and Target Lock Diamond). |
| 🟢 | **Added Visual 3D Shelf/Bin Picker & User-Initiated Supply Bounties (`+50 XP`)** | Upgraded [`tag_supply_screen.dart`](supply-closet/lib/screens/tag/tag_supply_screen.dart) Step 2 with an interactive 8-bin 3D shelf grid that assigns real `(x, y, z)` coordinates, and added [`bounty_board_sheet.dart`](supply-closet/lib/screens/bounty/bounty_board_sheet.dart) so nurses can post **Supply Bounties** for untagged supplies and Bounty Hunters earn **+50 Bonus XP** (`claimBounty`). |
| 🟢 | **Built Multi-Room Floor Support (`Med 3A`, `Med 3B`), Door Sign Scanner & Add Room Flow** | Added [`room_provider.dart`](supply-closet/lib/providers/room_provider.dart) and [`room_switcher_sheet.dart`](supply-closet/lib/widgets/room_switcher_sheet.dart) so nurses can add unlimited supply rooms to their floor (from **Tag**, **Find HUD**, or **Profile / Settings**), switch active supply rooms in 1 tap, or match a room by its hospital door plaque (`DEC-013`). |
| 🟢 | **Built Custom Display Name, 8 Pre-Generated Avatars & Camera/Photo Upload** | Added [`user_avatar.dart`](supply-closet/lib/widgets/user_avatar.dart) (`UserAvatar`, `AvatarPresets`, `ProfileIdentitySheet`) so nurses can customize their Display Name, pick from 8 clinical/gaming avatars, or snap/upload a custom profile photo (`DEC-013`). |
| 🟢 | **Built Room Captain System (`+150 XP` Trophy) & Spatial 3D Captain Hints** | Updated [`firestore_service.dart`](supply-closet/lib/services/firestore_service.dart) so the top tagger in each room automatically becomes **Room Captain** (`+150 XP` + `room_captain` badge) and can pin **Spatial Captain Hints** (`CaptainHintSheet`) that render in both the **3D Gaussian Splat** and **First-Person AR HUD** with the Captain's Display Name and Avatar (`DEC-013`). |
| 🟢 | **Deployed Firestore Rules & Installed APK on Moto G Stylus 5G** | Deployed updated [`firestore.rules`](supply-closet/firebase/firestore.rules) to `gen-lang-client-0675309660` and built `app-debug.apk`. |

---

## 2. Immediate Next Work Package for the Next Chat Session (`DEC-013`)

During phone testing on November 9, 2026, the user identified the next three core features to plan, mock up (if needed), and build:

### Feature 1: Multi-Room Floor Architecture (`Med 3A`, `Med 3B`) & HUD Room Switcher
- **Domain Context:** Hospital nurses and nursing assistants work on floors/wings with designations like **`Med 3A`** (Medical/Surgical 3rd Floor Wing A) or **`Med 3B`**, and a single wing (`Med 3A`) often has **2 or more supply rooms** (e.g., *Med 3A North Supply Room*, *Med 3A South Supply Room*).
- **What to Build:**
  1. **`RoomProvider` (`supply-closet/lib/providers/room_provider.dart`):**
     - Replaces hardcoded `AppConstants.defaultRoomId` (`'main'`).
     - Streams all `SupplyRoom` documents under `facilities/{facilityId}/units/{unitId}/supplyRooms` and tracks the currently active `selectedRoomId`.
  2. **Switch Rooms Directly in the Finder HUD (`ArFinderScreen`) & Tag Screen (`TagSupplyScreen`):**
     - Add an interactive **Supply Room Selector Pill** in the top HUD (e.g., `🚪 Med 3A · North Supply Rm ▾`) so nurses can switch which supply room they are standing in with 1 tap.
     - Include a placeholder / roadmap hook for **Scan Room Door Sign** (hospitals have door plaques with the room designation that nurses will eventually be able to scan with the camera to auto-switch rooms).
  3. **Add Supply Rooms from `Tag` & Display/Manage in `Profile / Settings`:**
     - Let nurses tap **`+ Add Supply Room`** right from the **Tag** screen room selector AND from **Profile / Settings** (`ProfileScreen`), where all supply rooms on their unit (`Med 3A`) are listed and managed.

### Feature 2: Custom Display Name, Pre-Generated Avatars & Profile Photo Upload
- **What to Build:**
  1. Update [`UserProfile`](supply-closet/lib/models/user_profile.dart), [`AuthService`](supply-closet/lib/services/auth_service.dart), and [`ProfileScreen`](supply-closet/lib/screens/profile/profile_screen.dart):
     - Let users set a custom **Display Name** visible to all other nurses on the unit (ensure `AuthService._getOrCreateProfile` preserves user-customized `displayName` and `avatarId`/`photoUrl` on subsequent logins).
     - Provide a **Pre-Generated Avatar Picker** (8–12 clinical/gaming avatars with distinct icons/colors/frames) **plus** the ability to upload/pick a custom profile picture.

### Feature 3: Room Captain System (`+150 XP` Trophy) & Spatial Captain Hints
- **What to Build:**
  1. **Room Captain Computation & Trophy (`+150 XP`):**
     - The user who has tagged the most supplies in a specific `SupplyRoom` automatically becomes that room's **Room Captain** (`captainUid`, `captainDisplayName`, `captainAvatar`, `captainTagCount` on `SupplyRoom`).
     - Becoming **Room Captain** awards the **🏅 Room Captain Trophy / Medal (`room_captain`)** and **+150 XP** (`GameAction.becomeRoomCaptain` in `awardXp`).
     - Display the Room Captain badge (`👑 Captain: [Name] + [Avatar]`) in the room switcher, Finder HUD, and Tag screen.
  2. **Room Captain Spatial Hints (Visible to All Users in 3D Splat & AR HUD):**
     - When the current user is the **Room Captain** of the active room, enable a **`👑 + Drop Captain Hint`** action in the room.
     - A **Captain Hint (`RoomHint`)** is anchored to a point/shelf in the room (`shelf`, `x, y, z`, `yawDegrees`) and stores `hintText`, `captainUid`, `captainDisplayName`, and `captainAvatar`.
     - All nurses in that room see **Captain Hint Beacons** rendered in the **3D Gaussian Splat ("God's Eye View")** and **First-Person Gaming AR HUD** showing the **Captain's Avatar, Display Name, and Hint Text**!

---

## 3. Quick Commands for Next Agent

```powershell
# 1. Verify Flutter static analysis, unit tests, and Cloud Functions lint
Set-Location "e:\PROJECTS\SupplyCloset\supply-closet"
flutter analyze --no-pub
flutter test --no-pub
Set-Location "e:\PROJECTS\SupplyCloset"
npm --prefix supply-closet/firebase/functions run lint

# 2. Deploy Firestore rules if SupplyCloset rules changed (3DPrintYou moved to app-3dprintyou on 2026-11-23; SupplyCloset owns rules on gen-lang-client-0675309660)
Set-Location "e:\PROJECTS\SupplyCloset\supply-closet\firebase"
npx -y firebase-tools@latest deploy --only firestore:rules --project gen-lang-client-0675309660 --dry-run
npx -y firebase-tools@latest deploy --only firestore:rules --project gen-lang-client-0675309660

# 3. Build, install, and launch on connected Moto G Stylus 5G (ZY22KP4X7C)
Set-Location "e:\PROJECTS\SupplyCloset\supply-closet"
flutter build apk --debug
& "C:\Users\Eliud\development\android-sdk\platform-tools\adb.exe" -s ZY22KP4X7C install -r "e:\PROJECTS\SupplyCloset\supply-closet\build\app\outputs\flutter-apk\app-debug.apk"
& "C:\Users\Eliud\development\android-sdk\platform-tools\adb.exe" -s ZY22KP4X7C shell am force-stop app.supplycloset
& "C:\Users\Eliud\development\android-sdk\platform-tools\adb.exe" -s ZY22KP4X7C shell am start -n app.supplycloset/.MainActivity
```
