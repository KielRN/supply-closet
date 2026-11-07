# Moving SupplyCloset toward a God's Eye View experience

Research date: October 21, 2026. This is a research recommendation, not an approved implementation design. No application source was changed during this review.

## Recommendation

Build a useful digital twin of **one supply room**, backed by real shelf/bin locations, and then add reliable AR guidance against that same room model. Keep the existing Flutter/Firebase application. A separate browser room viewer can deliver the explorable overview without forcing a mobile rewrite.

The intended moment: a nurse searches for an item, the room view focuses on the right shelf/bin, and the phone can optionally highlight that bin in the physical room. Always show the shelf/bin description and when someone last confirmed it. Hospital-wide navigation can follow after this works repeatedly in one room.

One-room-first is my recommendation and working assumption; it is not a preference the user has confirmed. The exact value of an overview versus camera guidance still needs a reaction to a concrete prototype.

## The reference project

The likely reference is [bilawalsidhu/gods-eye-view](https://github.com/bilawalsidhu/gods-eye-view), previously called WorldView. Sidhu's [own site](https://bilawal.ai/) identifies him as a former Google PM for AR/VR and 3D Maps.

The repository combines a CesiumJS globe, modular data layers, selected-object inspection, camera controls, and voice tools. Its UI ideas transfer well: overview-to-object focus, search that moves the camera, visibility toggles, contextual details, and explicit freshness. It does not provide a hospital's indoor map or shelf inventory.

Treat it as an interaction and architecture reference. My recommendation is to build our own room viewer rather than start by forking its globe and removing unrelated systems. Its [source license](https://github.com/bilawalsidhu/gods-eye-view/blob/main/LICENSE) is MIT, with notice requirements; third-party data and assets have separate terms. Any actual code reuse needs its notices preserved and the reused files checked for third-party content.

## What actually exists here

The April review describes an older revision. Later changes fixed some of those problems, so its findings cannot be treated as the current status wholesale.

| Area | Current source evidence | Consequence |
| --- | --- | --- |
| App foundation | Flutter, Firebase Auth, Firestore services, procedure screens and gamification exist | Preserve and extend this work |
| Room data | Firestore paths already include facility, unit and room; finder/tag screens use the default room | Extend room selection rather than replace the backend |
| AR session | `lib/screens/find/ar_finder_screen.dart:122` creates `ARView`; `:151` reads the camera pose | A real AR session exists, but it is not sufficient for accurate item placement |
| Tag coordinates | `lib/screens/tag/tag_supply_screen.dart:81` saves `x/y/z` as zero | New tags contain shelf/bin labels but no measured spatial placement |
| Marker rendering | `lib/screens/find/ar_finder_screen.dart:223` scales item coordinates into screen pixels | Markers do not use camera view/projection or stay attached to shelves as the phone moves |
| Shared alignment | `_originPose` is widget state; no saved map/anchor resolution in that finder | Two people pressing Set Start do not establish a reproducible shared frame |
| Barcode input | `lib/screens/tag/tag_supply_screen.dart:306` starts image streaming but explicitly skips conversion and processing | Scanning remains unfinished despite the camera UI |
| Multiple stock locations | `lib/services/firestore_service.dart:92` finds one matching barcode; `:115` overwrites its location | The same SKU in multiple bins needs separate placement records |
| Inventory | Existing observations describe finding/not finding an item | A location confirmation is not a measurement of stock quantity |

Paths above are relative to `supply-closet/`.

### Checks run on this checkout

- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: all three existing tests passed.
- `npm run lint` in `supply-closet/firebase/functions`: passed.

These are static checks and small smoke tests. No new APK build, device AR exercise, Firebase emulator workflow test, or deployed-backend verification was performed. The checks do not establish that sign-in, scanning, cross-device positioning, or production authorization works end to end.

## Separate three problems

1. **Display the room:** a schematic or 3D scene can show shelves and clickable bins, even when the viewer is elsewhere.
2. **Locate the phone:** AR needs the camera pose relative to that room, consistently across sessions and devices.
3. **Know what is in a bin:** barcode/catalog identity plus recent human or system observations. A room scan alone does not establish current contents or counts.

A photorealistic room model solves only part of the first problem. The critical technical experiment is the second one.

## Technology choices

| Choice | Useful role | Recommendation |
| --- | --- | --- |
| Simple measured shelves and bins | Editable geometry, explicit dimensions, deterministic item selection | Start here; a beautiful scan is optional |
| Three.js browser viewer | Orbit/cutaway room view, click-to-focus shelves, supply detail panels | My preferred companion viewer; [GLTFLoader](https://threejs.org/docs/pages/GLTFLoader.html) supports glTF models when we need imported assets |
| Existing Flutter app | Nurse authentication, procedures, tagging, field guidance | Keep it; avoid making web AR a requirement for nurses |
| Google Cloud Anchors | Resolve a saved local anchor across sessions/devices | First room-scale positioning candidate to benchmark |
| MultiSet VPS | Map-based indoor localization and larger spatial datasets | Second candidate; stronger fit to evaluate if whole-room mapping is needed |
| RoomPlan | LiDAR-assisted room layout capture on supported Apple hardware | Optional setup tool; not a mandatory device requirement for every nurse |
| Gaussian splats / photogrammetry | Photorealistic remote inspection and presentation | Later enhancement after reliable bin lookup |
| Cesium / Google map tiles | Campus or geographic context | Optional later; not the foundation for shelf placement |

### Shared positioning

[Google Cloud Anchors](https://developers.google.com/ar/develop/cloud-anchors) supports shared AR content across Android and iOS and is intended for room-scale experiences. Hosting/resolving requires connectivity and a visual feature map. Test anchors around stable room structure, rather than assuming changing cartons and reflective shelves will localize well. Account for renewal/expiration, service quotas, device support, and failure states when implementing.

[MultiSet's documentation](https://docs.multiset.ai/quick-access/faq) lists native Android/iOS, Unity and WebXR SDKs plus REST integration. There is no Flutter SDK listed there; a native bridge or REST integration is work to budget. Its [current pricing](https://multiset.ai/pricing) advertises a free tier with five active maps and 1,000 lifetime API calls, and Lite at $99/month with 10,000 monthly calls. This can fund a limited experiment, not establish the total operating cost. Accuracy and speed figures on the site are vendor claims, not measurements in a supply room.

The [MultiSet WebXR documentation](https://docs.multiset.ai/web-sdk/webxr-sdk.md) says camera frames are sent to its cloud for localization, and its required camera-access feature is unavailable in iOS Safari. A browser room viewer is viable; cross-platform browser AR should not be assumed. Cloud-based localization also changes the PRD's on-device-only camera-processing promise. Decide the image/feature-data handling requirements before scanning a real room or sending imagery to a provider.

[ARCore Geospatial](https://developers.google.com/ar/develop/geospatial) relies on Google's Street View localization model. That is not evidence of coverage inside a particular private supply room. Use a mapped indoor/local-anchor approach for that room.

### Capture and rendering

[Apple RoomPlan](https://developer.apple.com/augmented-reality/roomplan/) uses camera and LiDAR to produce a parametric room layout and exports USD/USDZ. It can accelerate setup, but shelf/bin annotation is still our responsibility; conversion would be needed for a GLB-based web asset workflow.

The current Flutter AR dependency, [ar_flutter_plugin 0.7.3](https://pub.dev/packages/ar_flutter_plugin), has an old published release. [ar_flutter_plugin_plus](https://pub.dev/packages/ar_flutter_plugin_plus) is an alternative fork, but its own README flags an Android tracking issue on some devices. Do not assume changing the package fixes spatial alignment. Benchmark the current plugin, a maintained candidate, and native integration effort before choosing.

## Proposed common data model

Use one source of truth for both the room viewer and AR:

```text
Facility -> Unit -> Room -> Map revision -> Shelf -> Bin
Catalog item / SKU -> Placement in a bin -> Observations
Room map -> Anchor/localization reference
```

- Separate a catalog item from its placements so the same SKU can live in multiple bins.
- Give geometry explicit units, axis conventions and a room coordinate frame.
- Bind placements and localization references to a map revision; changing a room must not silently reuse an incompatible frame.
- Store confirmation time/source and finding reports as observations with an audit trail.
- Keep item-location freshness distinct from localization confidence and measured inventory quantity.
- Use true anchors or per-frame view/projection transforms for AR, including behind-camera/off-screen handling.
- Persist stable structure; let contents change without requiring a full rescan every time supplies move.

The existing Firestore hierarchy is a useful starting point. New room metadata/map/placement paths will require explicit access rules; they are not automatically authorized by the existing supplies rule.

## Best next sequence

### 1. Finish the usable finder foundation

Complete the barcode pipeline, select a real room, import/enter 30–50 common items, and make shelf/bin lookup and confirmation dependable. Add an explicit placement model, actual room selection, and missing-data/offline states. Record find time before adding AR so the comparison has a baseline.

Review facility membership and observation writes in Firebase emulator tests before a real deployment. The current rules authorize supplies using a facility ID in a self-editable profile; a selection/cooldown is not verified facility membership. Preserve the data-quality controls needed to stop one erroneous update from corrupting the shared map. These are concrete gaps in the reviewed code, not a conclusion from an emulator test.

### 2. Build the one-room overview

Use a few measured shelf/bin blocks, a cutaway/overhead view, search, click-to-focus, and a details panel. Connect the same data used by the phone. Show last confirmation and reported-not-found status; avoid asserting real-time stock counts. This is the quickest useful demonstration of the God's Eye interaction idea.

### 3. Run a bounded localization experiment

Use the same room and targets to compare improved manual entrance alignment, Google Cloud Anchors, and MultiSet if needed. Keep the existing no-required-marker direction from the checklist. A QR/AprilTag can be an optional diagnostic reference if acceptable later; it need not become a product requirement.

Test two physical phones, fresh sessions on a later day, different lighting, partial shelf occlusion, ordinary restocking, moving around a corner, and loss of connectivity. The key test is whether a second phone finds the same bin without an expert correcting alignment. Store a measured target error and explicitly refuse an AR highlight when it may indicate the adjacent bin.

### 4. Pilot and decide what earns expansion

Suggested initial pilot: one room, 30–50 supplies, and 5–10 nurses. These are proposed experiment sizes, not user commitments or market evidence.

Proposed acceptance targets to refine with bin dimensions:

- At least 90% of repeat localization attempts succeed within 10 seconds under tested conditions.
- Evaluate positional error at the shelf: the high-percentile error must be below half the spacing between neighboring bin targets; otherwise fall back to shelf/bin text.
- AR must not reduce task success versus the list/room-view baseline; compare median and slower-tail find times.
- A setup owner can update a moved item without rebuilding the entire room.
- Fallback guidance remains available whenever localization, camera access or networking fails.

These are acceptance proposals, not claimed provider capabilities. If AR cannot meet them, the room viewer and location finder can still proceed while positioning remains experimental.

## What should wait

Voice can later translate a request such as “show the supplies for this checklist” into validated search/highlight actions. Start with read-only navigation over stored data, not an AI making up locations or stock levels. Delay hospital-wide analytics, custom SLAM, automatic shelf counting, and a photorealistic scan pipeline until the room pilot demonstrates value.

The existing launch checklist already recommends a `SpatialLocator` abstraction, optional VPS, and deferring Gaussian splats. The useful change now is to make that roadmap measurable and align it with the overview experience the user remembers.

The next concrete work package I recommend is **one-room mapping plus a clickable room viewer, followed by a two-phone anchor experiment**. Device access, room access, and the user's preferred first experience determine the implementation plan and schedule. No paid services, hospital imagery uploads, deployment, or implementation changes were initiated in this research pass.
