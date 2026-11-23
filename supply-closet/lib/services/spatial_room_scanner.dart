import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/supply_item.dart';
import '../models/supply_room.dart';

/// Represents a single 3D feature point ("sticky dot") detected from a real
/// physical corner/edge in the room and anchored in 3D room angle space
/// relative to the doorway origin (0,0,0).
class AnchoredFeaturePoint {
  final int id;
  double worldYawDeg;
  double worldPitchDeg;
  final double depthMeters;
  double edgeStrength;
  int observations;
  final DateTime createdAt;
  DateTime lastSeenAt;

  AnchoredFeaturePoint({
    required this.id,
    required this.worldYawDeg,
    required this.worldPitchDeg,
    required this.depthMeters,
    required this.edgeStrength,
    this.observations = 1,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastSeenAt = createdAt ?? DateTime.now();

  /// 0.0 = newly discovered (yellow/amber dot), 1.0 = locked sticky point (cyan/green dot)
  double get lockStrength {
    final ageMs = DateTime.now().difference(createdAt).inMilliseconds;
    final obsFactor = ((observations - 1) * 0.32).clamp(0.0, 0.75);
    final ageFactor = (ageMs / 900.0).clamp(0.0, 0.55);
    return (0.22 + obsFactor + ageFactor).clamp(0.0, 1.0);
  }

  bool get isLocked => lockStrength >= 0.62;
}

/// Projected 2D screen geometry for a 3D Bin Box so both the CustomPainter,
/// touch hit-testing, and camera finger-in-bin detector share exact coordinates.
class ProjectedBinBox {
  final String shelfId;
  final int binNumber;
  final SupplyLocation location3D;
  final double worldYawDeg;
  final double worldPitchDeg;
  final Rect frontRect;
  final Rect backRect;
  final Rect hitRect;

  const ProjectedBinBox({
    required this.shelfId,
    required this.binNumber,
    required this.location3D,
    required this.worldYawDeg,
    required this.worldPitchDeg,
    required this.frontRect,
    required this.backRect,
    required this.hitRect,
  });

  String get key => '$shelfId:$binNumber';
  String get label => 'SHELF $shelfId · BIN $binNumber';
}

/// Real-time room-aware spatial scanner engine that fuses:
/// 1. Native Android 3D orientation sensors (`app.supplycloset/spatial_sensors`)
/// 2. Live camera frame visual odometry + Sobel/corner feature extraction
/// 3. 3D sticky feature point cloud accumulation & shelf surface triangulation
/// 4. Camera Region-of-Interest (ROI) Finger/Hand-in-Bin presence detection
class SpatialRoomScannerEngine extends ChangeNotifier {
  static const double horizontalFovDeg = 58.0;
  static const double verticalFovDeg = 74.0;

  static const EventChannel _sensorChannel =
      EventChannel('app.supplycloset/spatial_sensors');
  static const MethodChannel _controlChannel =
      MethodChannel('app.supplycloset/spatial_control');

  StreamSubscription<dynamic>? _sensorSub;
  bool _hasHardwareSensorFix = false;

  double _sensorYawDeg = 0.0;
  double _sensorPitchDeg = 0.0;
  double _manualYawOffsetDeg = 0.0;
  double _manualPitchOffsetDeg = 0.0;
  double _angularSpeedDegPerSec = 0.0;

  // Sticky 3D feature points anchored to world (yaw, pitch, depth) in the room
  final List<AnchoredFeaturePoint> _points = [];
  int _nextPointId = 1;

  // Previous downsampled luminance grid (16x16) for optical flow & motion analysis
  List<int>? _prevLumaGrid;
  DateTime _lastFrameProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isProcessingFrame = false;

  // Finger / Hand-in-Bin presence tracking per "Shelf:Bin" key
  final Map<String, double> _binBaselineLuma = {};
  final Map<String, double> _binFingerProgress = {};
  String? _activeFingerBinKey;
  DateTime _lastBinTriggerAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Callback fired when the user puts their real finger/hand into a 3D bin box
  /// in front of the camera and holds it briefly to select/read that bin.
  final void Function(String shelfId, int binNumber)? onFingerReadBin;

  SpatialRoomScannerEngine({this.onFingerReadBin});

  double get cameraYawDeg =>
      (_sensorYawDeg + _manualYawOffsetDeg).clamp(-85.0, 85.0);
  double get cameraPitchDeg =>
      (_sensorPitchDeg + _manualPitchOffsetDeg).clamp(-45.0, 45.0);
  double get angularSpeedDegPerSec => _angularSpeedDegPerSec;
  bool get hasHardwareSensors => _hasHardwareSensorFix;

  List<AnchoredFeaturePoint> get points => List.unmodifiable(_points);
  int get lockedPointCount => _points.where((p) => p.isLocked).length;
  int get totalPointCount => _points.length;

  String? get activeFingerBinKey => _activeFingerBinKey;
  double fingerProgressFor(String binKey) => _binFingerProgress[binKey] ?? 0.0;

  /// Start listening to native 3D orientation sensors on the device.
  void startSensors() {
    if (kIsWeb) return;
    _sensorSub?.cancel();
    _sensorSub = _sensorChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final yaw = (event['yawDeg'] as num?)?.toDouble() ?? 0.0;
          final pitch = (event['pitchDeg'] as num?)?.toDouble() ?? 0.0;
          final speed = (event['angularSpeed'] as num?)?.toDouble() ?? 0.0;

          _hasHardwareSensorFix = true;
          // Smooth low-pass filter to keep AR rendering jitter-free
          _sensorYawDeg = _lerpAngle(_sensorYawDeg, yaw, 0.35);
          _sensorPitchDeg = _sensorPitchDeg + (pitch - _sensorPitchDeg) * 0.35;
          _angularSpeedDegPerSec = speed;
          notifyListeners();
        }
      },
      onError: (_) {
        _hasHardwareSensorFix = false;
      },
    );
  }

  double _lerpAngle(double current, double target, double t) {
    var diff = ((target - current + 180.0) % 360.0) - 180.0;
    if (diff < -180.0) diff += 360.0;
    return current + diff * t;
  }

  /// Recenter doorway `(0,0,0)` heading to the phone's current direction.
  Future<void> recenterDoorwayOrigin() async {
    _manualYawOffsetDeg = 0.0;
    _manualPitchOffsetDeg = 0.0;
    _sensorYawDeg = 0.0;
    _sensorPitchDeg = 0.0;
    if (!kIsWeb) {
      try {
        await _controlChannel.invokeMethod('recenterOrigin');
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Reset all detected feature dots to start a fresh room scan from 0 points.
  void resetScanPoints() {
    _points.clear();
    _binBaselineLuma.clear();
    _binFingerProgress.clear();
    _activeFingerBinKey = null;
    notifyListeners();
  }

  /// Allow touch panning (or fallback when testing without physical rotation)
  /// and spawn progressive feature points along the swept area if camera stream
  /// is simulated.
  void addManualPan(
    double deltaDx,
    double deltaDy, {
    bool spawnSimulatedPointsIfNoStream = false,
  }) {
    _manualYawOffsetDeg =
        (_manualYawOffsetDeg - deltaDx * 0.24).clamp(-85.0, 85.0);
    _manualPitchOffsetDeg =
        (_manualPitchOffsetDeg + deltaDy * 0.16).clamp(-40.0, 40.0);

    if (spawnSimulatedPointsIfNoStream) {
      _spawnSimulatedFeatureClusterAt(cameraYawDeg, cameraPitchDeg);
    }
    notifyListeners();
  }

  /// Spawn a realistic cluster of feature points around a specific world angle
  /// (used when anchoring a shelf or when testing in camera-sim mode).
  void seedFeaturePointsAround({
    required double centerYawDeg,
    double centerPitchDeg = 0.0,
    double depthMeters = 2.2,
    int count = 18,
  }) {
    final rng = math.Random(centerYawDeg.round() * 97 + _points.length);
    for (int i = 0; i < count; i++) {
      final wy = centerYawDeg + (rng.nextDouble() - 0.5) * 22.0;
      final wp = centerPitchDeg + (rng.nextDouble() - 0.5) * 28.0;
      _registerOrReinforceFeaturePoint(
        worldYawDeg: wy,
        worldPitchDeg: wp,
        depthMeters: depthMeters + (rng.nextDouble() - 0.5) * 0.35,
        edgeStrength: 0.7 + rng.nextDouble() * 0.3,
      );
    }
    notifyListeners();
  }

  void _spawnSimulatedFeatureClusterAt(double yawDeg, double pitchDeg) {
    final rng = math.Random(DateTime.now().microsecondsSinceEpoch);
    for (int i = 0; i < 4; i++) {
      final wy = yawDeg + (rng.nextDouble() - 0.5) * 26.0;
      final wp = pitchDeg + (rng.nextDouble() - 0.5) * 32.0;
      _registerOrReinforceFeaturePoint(
        worldYawDeg: wy,
        worldPitchDeg: wp,
        depthMeters: 2.1 + (rng.nextDouble() - 0.5) * 0.4,
        edgeStrength: 0.65 + rng.nextDouble() * 0.35,
      );
    }
  }

  /// Project all active 3D shelf bins onto the current 2D viewport `size`
  /// given the phone's live `(cameraYawDeg, cameraPitchDeg)`.
  List<ProjectedBinBox> projectBinsForShelves({
    required List<ShelfRack> shelves,
    required Set<String> pinnedShelfIds,
    required Size screenSize,
    int maxBinsPerShelfToShow = 4,
  }) {
    final result = <ProjectedBinBox>[];
    if (screenSize.width <= 0 || screenSize.height <= 0) return result;

    for (final shelf in shelves) {
      if (!pinnedShelfIds.contains(shelf.id)) continue;

      final binsToRender = math.min(maxBinsPerShelfToShow, shelf.totalBins);
      for (int binNum = 1; binNum <= binsToRender; binNum++) {
        final loc = shelf.locationForBin(binNum);

        // Compute world yaw & pitch of this bin relative to doorway eye height (1.30m)
        final colIdx = (binNum - 1) % shelf.binsPerRow;
        final colYawOffset = (colIdx - (shelf.binsPerRow - 1) / 2.0) * 8.5;
        final worldYaw = shelf.yawDegrees + colYawOffset;

        final rowIdx = (binNum - 1) ~/ shelf.binsPerRow;
        // Row 0 = top (+12°), Row 1 = eye level (+1°), Row 2 = waist (-10°), Row 3 = bottom (-20°)
        final worldPitch = 12.0 - (rowIdx * 11.0);

        final relYaw = worldYaw - cameraYawDeg;
        final relPitch = worldPitch - cameraPitchDeg;

        // Skip if completely outside wide view frustum
        if (relYaw.abs() > 48.0 || relPitch.abs() > 52.0) continue;

        final cx = screenSize.width * 0.5 +
            (relYaw / horizontalFovDeg) * screenSize.width;
        final cy = screenSize.height * 0.46 -
            (relPitch / verticalFovDeg) * screenSize.height;

        // Perspective scale based on distance in meters
        final scale = (2.2 / loc.z.clamp(1.2, 4.0)).clamp(0.72, 1.25);
        final boxW = 92.0 * scale;
        final boxH = 56.0 * scale;

        final frontRect =
            Rect.fromCenter(center: Offset(cx, cy), width: boxW, height: boxH);
        // 3D depth offset for back face of wireframe cube
        final perspectiveShiftX =
            ((cx - screenSize.width * 0.5) * -0.10).clamp(-16.0, 16.0);
        final backRect = frontRect.shift(Offset(perspectiveShiftX + 10, -10));
        final hitRect = frontRect.expandToInclude(backRect).inflate(8);

        result.add(
          ProjectedBinBox(
            shelfId: shelf.id,
            binNumber: binNum,
            location3D: loc,
            worldYawDeg: worldYaw,
            worldPitchDeg: worldPitch,
            frontRect: frontRect,
            backRect: backRect,
            hitRect: hitRect,
          ),
        );
      }
    }
    return result;
  }

  /// Process a live `CameraImage` frame on-device (Zero PHI / never uploaded):
  /// 1. Extracts real high-contrast corners/edges (shelf posts, bin corners) and
  ///    anchors them at 3D world `(yaw, pitch, depth)` coordinates so dots appear
  ///    and stick to the room as you move the camera.
  /// 2. Estimates camera optical-flow motion if hardware gyro isn't active.
  /// 3. Monitors projected 3D bin boxes for real hand/finger entry in front of
  ///    the camera lens.
  void processCameraFrame({
    required CameraImage image,
    required int sensorOrientation,
    required List<ShelfRack> shelves,
    required Set<String> pinnedShelfIds,
    required Size screenSize,
  }) {
    if (_isProcessingFrame || image.planes.isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameProcessedAt).inMilliseconds < 85) {
      return; // Throttle to ~11 FPS for 60 FPS UI smoothness
    }
    _isProcessingFrame = true;
    _lastFrameProcessedAt = now;

    try {
      final yPlane = image.planes[0];
      final bytes = yPlane.bytes;
      final bytesPerRow = yPlane.bytesPerRow;
      final imgW = image.width;
      final imgH = image.height;

      if (imgW < 32 || imgH < 32 || bytes.isEmpty) {
        return;
      }

      // Helper to sample luminance [0..255] at normalized portrait screen (u, v) in [0..1]
      int sampleLuma(double u, double v) {
        final cu = u.clamp(0.01, 0.99);
        final cv = v.clamp(0.01, 0.99);
        int sx;
        int sy;
        if (sensorOrientation == 90) {
          sx = (cv * (imgW - 1)).round();
          sy = ((1.0 - cu) * (imgH - 1)).round();
        } else if (sensorOrientation == 270) {
          sx = ((1.0 - cv) * (imgW - 1)).round();
          sy = (cu * (imgH - 1)).round();
        } else {
          sx = (cu * (imgW - 1)).round();
          sy = (cv * (imgH - 1)).round();
        }
        final idx = sy * bytesPerRow + sx;
        if (idx < 0 || idx >= bytes.length) return 128;
        return bytes[idx];
      }

      // 1. Coarse 16x16 grid for optical flow & global camera motion check
      const gridN = 16;
      final currentGrid = List<int>.filled(gridN * gridN, 0);
      for (int gy = 0; gy < gridN; gy++) {
        final v = 0.15 + (gy / (gridN - 1)) * 0.70;
        for (int gx = 0; gx < gridN; gx++) {
          final u = 0.10 + (gx / (gridN - 1)) * 0.80;
          currentGrid[gy * gridN + gx] = sampleLuma(u, v);
        }
      }

      double frameMotionDiff = 0.0;
      if (_prevLumaGrid != null) {
        int diffSum = 0;
        for (int i = 0; i < currentGrid.length; i++) {
          diffSum += (currentGrid[i] - _prevLumaGrid![i]).abs();
        }
        frameMotionDiff = diffSum / currentGrid.length;

        // If hardware rotation vector sensor isn't reporting, estimate coarse
        // horizontal/vertical visual odometry shift from the luminance grid!
        if (!_hasHardwareSensorFix && frameMotionDiff > 4.0) {
          final flow = _estimateCoarseOpticalFlow(_prevLumaGrid!, currentGrid, gridN);
          _manualYawOffsetDeg =
              (_manualYawOffsetDeg + flow.dx * 2.4).clamp(-80.0, 80.0);
          _manualPitchOffsetDeg =
              (_manualPitchOffsetDeg - flow.dy * 1.8).clamp(-40.0, 40.0);
        }
      }
      _prevLumaGrid = currentGrid;

      // 2. Real Corner & Edge Detection across the camera view -> Sticky 3D Dots
      // Sample a 12x16 grid of candidate regions and find strong physical corners
      const cols = 12;
      const rows = 16;
      const stepU = 0.008;
      const stepV = 0.006;

      int newOrUpdated = 0;
      for (int r = 0; r < rows; r++) {
        final v = 0.16 + (r / (rows - 1)) * 0.64;
        for (int c = 0; c < cols; c++) {
          final u = 0.08 + (c / (cols - 1)) * 0.84;

          final center = sampleLuma(u, v);
          final left = sampleLuma(u - stepU, v);
          final right = sampleLuma(u + stepU, v);
          final up = sampleLuma(u, v - stepV);
          final down = sampleLuma(u, v + stepV);
          final diag1 = sampleLuma(u + stepU, v + stepV);
          final diag2 = sampleLuma(u - stepU, v - stepV);

          final gx = (right - left).abs();
          final gy = (down - up).abs();
          final gd = (diag1 - diag2).abs();

          // Cornerness requires strong gradient in multiple directions (real shelf/bin corners & edges)
          final minAxis = math.min(gx, gy);
          final maxAxis = math.max(gx, gy);
          final cornerScore = minAxis * 1.35 + maxAxis * 0.45 + gd * 0.35 + (center - ((left + right + up + down) >> 2)).abs();

          if (cornerScore >= 34.0) {
            final worldYaw = cameraYawDeg + (u - 0.5) * horizontalFovDeg;
            final worldPitch = cameraPitchDeg + (0.5 - v) * verticalFovDeg;
            final strength = ((cornerScore - 34.0) / 80.0).clamp(0.35, 1.0);
            final estDepth = 2.0 + ((1.0 - v) * 0.7);

            _registerOrReinforceFeaturePoint(
              worldYawDeg: worldYaw,
              worldPitchDeg: worldPitch,
              depthMeters: estDepth,
              edgeStrength: strength,
            );
            newOrUpdated++;
            if (newOrUpdated >= 14) break; // Cap per frame so dots appear progressively
          }
        }
        if (newOrUpdated >= 14) break;
      }

      // 3. Finger / Hand-in-Bin Camera Detection inside visible 3D Bin Boxes
      _detectFingerInVisibleBins(
        sampleLuma: sampleLuma,
        image: image,
        sensorOrientation: sensorOrientation,
        shelves: shelves,
        pinnedShelfIds: pinnedShelfIds,
        screenSize: screenSize,
        globalFrameMotion: frameMotionDiff,
      );

      notifyListeners();
    } finally {
      _isProcessingFrame = false;
    }
  }

  Offset _estimateCoarseOpticalFlow(
      List<int> prev, List<int> curr, int gridN) {
    int bestDx = 0;
    int bestDy = 0;
    int bestSad = 1 << 30;

    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        int sad = 0;
        for (int y = 2; y < gridN - 2; y++) {
          for (int x = 2; x < gridN - 2; x++) {
            final pIdx = y * gridN + x;
            final cIdx = (y + dy) * gridN + (x + dx);
            sad += (prev[pIdx] - curr[cIdx]).abs();
          }
        }
        if (sad < bestSad) {
          bestSad = sad;
          bestDx = dx;
          bestDy = dy;
        }
      }
    }
    return Offset(bestDx.toDouble(), bestDy.toDouble());
  }

  void _registerOrReinforceFeaturePoint({
    required double worldYawDeg,
    required double worldPitchDeg,
    required double depthMeters,
    required double edgeStrength,
  }) {
    // Check if an existing sticky dot is already anchored at this 3D spot in the room
    for (final existing in _points) {
      final dYaw = (existing.worldYawDeg - worldYawDeg).abs();
      final dPitch = (existing.worldPitchDeg - worldPitchDeg).abs();
      if (dYaw < 2.2 && dPitch < 2.2) {
        existing.observations += 1;
        existing.lastSeenAt = DateTime.now();
        // Gently refine world anchor toward latest observation
        existing.worldYawDeg = existing.worldYawDeg * 0.75 + worldYawDeg * 0.25;
        existing.worldPitchDeg =
            existing.worldPitchDeg * 0.75 + worldPitchDeg * 0.25;
        existing.edgeStrength = math.max(existing.edgeStrength, edgeStrength);
        return;
      }
    }

    // Cap maximum stored points to 750 (evict oldest low-observation point if full)
    if (_points.length >= 750) {
      final removeIdx = _points.indexWhere((p) => p.observations <= 1);
      if (removeIdx >= 0) {
        _points.removeAt(removeIdx);
      } else {
        _points.removeAt(0);
      }
    }

    _points.add(
      AnchoredFeaturePoint(
        id: _nextPointId++,
        worldYawDeg: worldYawDeg,
        worldPitchDeg: worldPitchDeg,
        depthMeters: depthMeters,
        edgeStrength: edgeStrength,
      ),
    );
  }

  void _detectFingerInVisibleBins({
    required int Function(double u, double v) sampleLuma,
    required CameraImage image,
    required int sensorOrientation,
    required List<ShelfRack> shelves,
    required Set<String> pinnedShelfIds,
    required Size screenSize,
    required double globalFrameMotion,
  }) {
    if (screenSize.width <= 0 || screenSize.height <= 0) return;

    // Only read finger/hand inside a bin when the phone itself isn't panning fast
    final phoneIsSteady =
        _angularSpeedDegPerSec < 28.0 && globalFrameMotion < 22.0;

    final projectedBins = projectBinsForShelves(
      shelves: shelves,
      pinnedShelfIds: pinnedShelfIds,
      screenSize: screenSize,
    );

    String? bestBinKey;
    double bestScore = 0.0;
    ProjectedBinBox? bestBin;

    for (final bin in projectedBins) {
      final rect = bin.frontRect;
      final uMin = (rect.left / screenSize.width).clamp(0.05, 0.90);
      final uMax = (rect.right / screenSize.width).clamp(0.10, 0.95);
      final vMin = (rect.top / screenSize.height).clamp(0.10, 0.85);
      final vMax = (rect.bottom / screenSize.height).clamp(0.15, 0.90);

      if (uMax <= uMin || vMax <= vMin) continue;

      // Sample a 4x4 interior grid inside this 3D bin's screen rectangle
      double sumLuma = 0;
      int count = 0;
      for (int ry = 0; ry < 4; ry++) {
        final v = vMin + (ry + 0.5) / 4.0 * (vMax - vMin);
        for (int rx = 0; rx < 4; rx++) {
          final u = uMin + (rx + 0.5) / 4.0 * (uMax - uMin);
          sumLuma += sampleLuma(u, v);
          count++;
        }
      }
      final avgLuma = count > 0 ? sumLuma / count : 128.0;
      final prevBaseline = _binBaselineLuma[bin.key];

      if (prevBaseline == null || !phoneIsSteady) {
        _binBaselineLuma[bin.key] = avgLuma;
        _binFingerProgress[bin.key] =
            ((_binFingerProgress[bin.key] ?? 0.0) - 0.15).clamp(0.0, 1.0);
        continue;
      }

      // Localized foreground change inside this specific bin box while background is steady
      final localDelta = (avgLuma - prevBaseline).abs();
      final localizedContrast = localDelta - (globalFrameMotion * 0.65);

      if (localizedContrast > 11.5) {
        if (localizedContrast > bestScore) {
          bestScore = localizedContrast;
          bestBinKey = bin.key;
          bestBin = bin;
        }
      } else {
        // Slowly adapt baseline when no finger is entering the bin
        _binBaselineLuma[bin.key] = prevBaseline * 0.85 + avgLuma * 0.15;
        _binFingerProgress[bin.key] =
            ((_binFingerProgress[bin.key] ?? 0.0) - 0.18).clamp(0.0, 1.0);
      }
    }

    if (bestBin != null && bestBinKey != null && phoneIsSteady) {
      _activeFingerBinKey = bestBinKey;
      final nextProg =
          ((_binFingerProgress[bestBinKey] ?? 0.0) + 0.36).clamp(0.0, 1.0);
      _binFingerProgress[bestBinKey] = nextProg;

      final now = DateTime.now();
      if (nextProg >= 1.0 &&
          now.difference(_lastBinTriggerAt).inMilliseconds > 1600) {
        _lastBinTriggerAt = now;
        _binFingerProgress[bestBinKey] = 0.4;
        _binBaselineLuma[bestBinKey] =
            (_binBaselineLuma[bestBinKey] ?? 128.0);
        HapticFeedback.heavyImpact();
        onFingerReadBin?.call(bestBin.shelfId, bestBin.binNumber);
      }
    } else {
      _activeFingerBinKey = null;
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    super.dispose();
  }
}
