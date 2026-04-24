# MVP Launch Recommendations Checklist

Use this checklist to close the current code review findings and keep the spatial positioning roadmap scoped for an MVP launch.

## Blocking Fixes

- [x] Fix `reportNotFound()` so Firestore rules allow the write.
  - Update `supply-closet/lib/services/firestore_service.dart`.
  - Use a transaction like `tagSupply()`.
  - Read the current supply document.
  - Increment `version` by exactly 1.
  - Update `confidence` and `notFoundReports` in the same write.
  - Verify the deployed Firestore rule accepts the update.

- [x] Return tag write metadata from `tagSupply()`.
  - Return the supply document id.
  - Return whether the action created a new supply or confirmed an existing one.
  - Consider a small result object, for example `TagSupplyResult`.
  - Avoid making the UI infer the outcome from local state.

- [x] Pass the tagged `supplyId` into XP awarding.
  - Update `supply-closet/lib/screens/tag/tag_supply_screen.dart`.
  - Pass the returned supply id to `GamificationProvider.recordAction()`.
  - Confirm the Cloud Function verifier no longer has to scan recent supplies for the common path.

- [x] Award the correct XP action.
  - Send `GameAction.tagNew` only for newly created supply documents.
  - Send `GameAction.confirmExisting` for existing supply confirmations.
  - Confirm challenge progress and analytics still classify the action correctly.

- [x] Add room-aware XP verification.
  - Pass `roomId` through the client, provider, service, and Cloud Function.
  - Update `_verifyRecentTag()` so it does not hard-code `supplyRooms/main`.
  - Keep `AppConstants.defaultRoomId` as the MVP default.

## Launch Verification

- [x] Add at least one test directory and smoke test.
  - Add `supply-closet/test/`.
  - Cover `tagSupply()` result behavior if it can be isolated.
  - Cover gamification action mapping if practical.

- [x] Run Flutter checks.
  - Run `flutter analyze`.
  - Run `flutter test`.
  - Resolve warnings that affect launch confidence.

- [ ] Install and run Firebase Functions lint.
  - Run `npm install` inside `supply-closet/firebase/functions`.
  - Run `npm --prefix firebase/functions run lint`.
  - Fix deploy-blocking lint errors.
  - Current blocker: `npm install` fails while writing `node_modules` under Google Drive, and the local Node runtime is v22 while functions request Node 20.

- [ ] Test Firestore rules against key workflows.
  - Create a new supply.
  - Confirm an existing supply.
  - Report a supply as not found.
  - Attempt to write XP or badges directly from the client and confirm it is denied.

## AR And Positioning Scope

- [ ] Decide how the MVP should describe the finder experience.
  - If it remains a guided list/checklist, avoid promising full AR wayfinding.
  - If it is marketed as AR, wire a real ARCore/ARKit session before launch.

- [x] Add a human-defined origin strategy for closets.
  - Use the closet entrance threshold as the default origin.
  - Prompt the user to stand at the entrance and face the main shelves.
  - Let the user tap `Set Start Point` to initialize the AR session origin.
  - Store shelf/bin positions relative to that start point.
  - Let ARCore/ARKit handle local motion tracking after initialization.
  - Avoid requiring printed QR codes or installed physical markers for MVP.

- [x] Add setup and recenter flows for new closets.
  - Add a `Set up this closet` flow for the first user in a room.
  - Add a `Start from entrance` flow for later users.
  - Add a `Markers look off?` or `Recenter` action.
  - Keep shelf/bin text visible when spatial alignment is uncertain.
  - Record whether the closet has been calibrated before.

- [x] Keep ARCore/ARKit as the runtime tracking layer.
  - Use native AR tracking for pose, anchors, surfaces, and session state.
  - Do not build custom SLAM for MVP.
  - Treat custom SLAM as research only if native tracking and VPS both fail.

- [ ] Pilot VPS behind an abstraction.
  - Create a `SpatialLocator` or equivalent service boundary.
  - Keep the first implementation human-origin-based.
  - Add Multiset AI or another VPS provider as a swappable implementation.
  - Record localization confidence and fallback to list mode when confidence is low.
  - Treat QR, AprilTag, NFC, and VPS as optional future localization upgrades, not launch requirements.

- [ ] Defer Gaussian splatting and point-cloud-heavy work.
  - Use point clouds as mapping input if a VPS provider requires them.
  - Use Gaussian splats only for visual inspection or future digital twin workflows.
  - Do not put splat rendering on the critical MVP path.

## Product Readiness

- [ ] Make fallback behavior explicit.
  - If AR or VPS is unavailable, show shelf/bin/list guidance.
  - Avoid blocking the nurse's workflow on spatial localization.

- [ ] Add telemetry for launch learning.
  - Tag created versus confirmed.
  - XP award success versus failure.
  - Finder mode used: list, human-origin AR, marker-based AR, VPS.
  - Localization confidence and fallback reason.
  - Recenter frequency per closet.
  - New closet setup completion rate.

- [ ] Create an MVP go/no-go checklist.
  - Security rules pass core workflows.
  - Tagging works offline/poor network as expected or fails clearly.
  - XP cannot be farmed from direct client writes.
  - Finder language matches actual implemented capability.
  - Crash reporting is enabled and verified.
