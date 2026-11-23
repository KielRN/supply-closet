import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/supply_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/gamification_service.dart';
import '../../services/spatial_room_scanner.dart';
import 'doorway_room_setup.dart';

class RoomInitiationScreen extends StatelessWidget {
  final String roomId;
  final String roomName;
  final bool roomIsInitiated;
  final String? initialShelf;
  final int? initialBin;

  const RoomInitiationScreen({
    super.key,
    this.roomId = AppConstants.defaultRoomId,
    this.roomName = 'Supply Room 1',
    this.roomIsInitiated = false,
    this.initialShelf,
    this.initialBin,
  });

  static bool get usesDoorwayScanner =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    if (!usesDoorwayScanner) {
      return _LegacyRoomInitiationScreen(roomId: roomId, roomName: roomName);
    }
    final profile = context.watch<AuthProvider>().profile;
    if (profile == null || profile.facilityId == null || profile.unitId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(roomName)),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Set your facility and unit in Profile to map this room.'),
        ),
      );
    }
    return DoorwayRoomSetup(
      key: ValueKey((profile.uid, profile.facilityId, profile.unitId, roomId)),
      profile: profile,
      roomId: roomId,
      roomName: roomName,
      roomIsInitiated: roomIsInitiated,
      initialShelf: initialShelf,
      initialBin: initialBin,
    );
  }
}

/// Legacy room setup for platforms without the Android doorway scanner.
/// - Streams live camera frames (`startImageStream`) + native 3D orientation sensors
/// - Detects real physical corners/edges so feature-point dots progressively appear
///   and stick to 3D places in the room as you move the phone
/// - Renders 3D perspective wireframe bin cubes (`SHELF A · BIN 1`, `BIN 2`, `BIN 3`...)
///   with `[AR]` lock reticle and `(x, y, z)` coordinates
/// - Detects both real Finger/Hand-in-Bin presence in front of the camera AND direct
///   screen taps on any 3D bin box
class _LegacyRoomInitiationScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const _LegacyRoomInitiationScreen({
    required this.roomId,
    required this.roomName,
  });

  @override
  State<_LegacyRoomInitiationScreen> createState() => _RoomInitiationScreenState();
}

class _RoomInitiationScreenState extends State<_LegacyRoomInitiationScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirestoreService();
  late final SpatialRoomScannerEngine _scannerEngine;

  CameraController? _cameraController;
  bool _liveCameraActive = false;
  int _sensorOrientation = 90;

  late final AnimationController _scanWaveController;

  // Starts with Shelf A anchored so 3D Bin Boxes (Bin 1, Bin 2, Bin 3...) are
  // immediately visible & interactive, while Shelf B and C can be anchored as you scan
  final Set<String> _pinnedShelfIds = {'A'};
  final Map<String, ShelfRack> _customAnchoredShelves = {
    'A': const ShelfRack(
      id: 'A',
      label: 'Shelf A · Left Wall',
      yawDegrees: -12.0,
      distanceMeters: 2.1,
      rows: 4,
      binsPerRow: 2,
    ),
    'B': const ShelfRack(
      id: 'B',
      label: 'Shelf B · Center Back',
      yawDegrees: 14.0,
      distanceMeters: 2.6,
      rows: 4,
      binsPerRow: 2,
    ),
    'C': const ShelfRack(
      id: 'C',
      label: 'Shelf C · Right Wall',
      yawDegrees: 36.0,
      distanceMeters: 2.2,
      rows: 4,
      binsPerRow: 2,
    ),
  };

  String _selectedShelfId = 'A';
  int _selectedBinNumber = 2;
  String? _lastBinReadMessage;
  Size _viewportSize = const Size(390, 844);

  bool _isSaving = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _scannerEngine = SpatialRoomScannerEngine(
      onFingerReadBin: _handleBinReadFromCameraFinger,
    )..startSensors();

    _scanWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();

    _initLiveCamera();
  }

  void _handleBinReadFromCameraFinger(String shelfId, int binNumber) {
    if (!mounted) return;
    final rack = _customAnchoredShelves[shelfId] ??
        ShelfRack.defaultForCode(shelfId);
    final loc = rack.locationForBin(binNumber);
    setState(() {
      _selectedShelfId = shelfId;
      _selectedBinNumber = binNumber;
      _lastBinReadMessage =
          '✋ FINGER READ: SHELF $shelfId · BIN $binNumber (x:${loc.x}m, y:${loc.y}m, z:${loc.z}m)';
    });
  }

  Future<void> _initLiveCamera() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _liveCameraActive = false;
        });
      }
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _liveCameraActive = false;
          });
        }
        return;
      }
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _sensorOrientation = backCamera.sensorOrientation;

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      // Start live on-device image stream for real corner/edge feature dots
      // and finger-in-bin presence detection
      try {
        await controller.startImageStream((CameraImage image) {
          if (!mounted) return;
          _scannerEngine.processCameraFrame(
            image: image,
            sensorOrientation: _sensorOrientation,
            shelves: _customAnchoredShelves.values.toList(),
            pinnedShelfIds: _pinnedShelfIds,
            screenSize: _viewportSize,
          );
        });
      } catch (_) {
        // Ignore if stream already active or unsupported in test harness
      }

      setState(() {
        _cameraController = controller;
        _liveCameraActive = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _liveCameraActive = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scanWaveController.dispose();
    _scannerEngine.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  int get _progressPercent {
    // Combine real locked feature dots + anchored shelf racks for mapping progress
    final pointProgress =
        (_scannerEngine.totalPointCount / 180.0).clamp(0.0, 1.0) * 55.0;
    final shelfProgress = (_pinnedShelfIds.length / 3.0).clamp(0.0, 1.0) * 45.0;
    return (pointProgress + shelfProgress).round().clamp(5, 100);
  }

  String? get _nextUnpinnedShelfId {
    for (final id in ['A', 'B', 'C']) {
      if (!_pinnedShelfIds.contains(id)) return id;
    }
    return null;
  }

  /// Anchors the next shelf rack (or re-anchors the selected shelf rack) at the
  /// phone's current real-world camera yaw direction and seeds feature points.
  void _anchorShelfAtCurrentView() {
    HapticFeedback.mediumImpact();
    final targetShelfId = _nextUnpinnedShelfId ?? _selectedShelfId;
    final currentYaw = _scannerEngine.cameraYawDeg;
    final existing = _customAnchoredShelves[targetShelfId]!;

    setState(() {
      _pinnedShelfIds.add(targetShelfId);
      _selectedShelfId = targetShelfId;
      _customAnchoredShelves[targetShelfId] = ShelfRack(
        id: targetShelfId,
        label: existing.label,
        yawDegrees: currentYaw,
        distanceMeters: existing.distanceMeters,
        rows: existing.rows,
        binsPerRow: existing.binsPerRow,
      );
      _lastBinReadMessage =
          '⚓ Anchored Shelf $targetShelfId at ${currentYaw.toStringAsFixed(0)}° (8 3D Bins Locked)';
    });

    // Ensure feature points cluster around this newly anchored shelf
    _scannerEngine.seedFeaturePointsAround(
      centerYawDeg: currentYaw,
      centerPitchDeg: _scannerEngine.cameraPitchDeg,
      depthMeters: existing.distanceMeters,
      count: 22,
    );
  }

  void _toggleShelfChip(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_pinnedShelfIds.contains(id) && _pinnedShelfIds.length > 1) {
        _pinnedShelfIds.remove(id);
      } else {
        _pinnedShelfIds.add(id);
        _selectedShelfId = id;
      }
    });
  }

  void _handleCanvasTap(TapUpDetails details, Size size) {
    // 1. Hit-test projected 3D Bin Boxes first!
    final projectedBins = _scannerEngine.projectBinsForShelves(
      shelves: _customAnchoredShelves.values.toList(),
      pinnedShelfIds: _pinnedShelfIds,
      screenSize: size,
    );

    for (final bin in projectedBins.reversed) {
      if (bin.hitRect.contains(details.localPosition)) {
        HapticFeedback.heavyImpact();
        setState(() {
          _selectedShelfId = bin.shelfId;
          _selectedBinNumber = bin.binNumber;
          _lastBinReadMessage =
              '✓ LOCKED ${bin.label} (x:${bin.location3D.x}m, y:${bin.location3D.y}m, z:${bin.location3D.z}m)';
        });
        return;
      }
    }

    // 2. Otherwise, tapping a place in the room drops sticky feature points right
    // at that tapped 3D spot in the room!
    final u = (details.localPosition.dx / size.width).clamp(0.05, 0.95);
    final v = (details.localPosition.dy / size.height).clamp(0.10, 0.90);
    final tappedYaw = _scannerEngine.cameraYawDeg +
        (u - 0.5) * SpatialRoomScannerEngine.horizontalFovDeg;
    final tappedPitch = _scannerEngine.cameraPitchDeg +
        (0.5 - v) * SpatialRoomScannerEngine.verticalFovDeg;

    HapticFeedback.lightImpact();
    _scannerEngine.seedFeaturePointsAround(
      centerYawDeg: tappedYaw,
      centerPitchDeg: tappedPitch,
      count: 10,
    );
  }

  Future<void> _finishInitiation() async {
    final auth = context.read<AuthProvider>();
    final game = context.read<GamificationProvider>();
    final profile = auth.profile;
    if (profile == null ||
        profile.facilityId == null ||
        profile.unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set your facility and unit in Profile first.'),
          backgroundColor: SupplyClosetColors.coral,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Save all anchored shelves (defaulting to all 3 if user finishes right away)
      final savedIds =
          _pinnedShelfIds.isNotEmpty ? _pinnedShelfIds : {'A', 'B', 'C'};
      final pinnedShelves = _customAnchoredShelves.values
          .where((s) => savedIds.contains(s.id))
          .toList();

      await _firestore.initiateRoom(
        facilityId: profile.facilityId!,
        unitId: profile.unitId!,
        roomId: widget.roomId,
        roomName: widget.roomName,
        userId: profile.uid,
        shelves: pinnedShelves,
        hasGaussianSplat: true,
        splatAssetName: 'room_${widget.roomId}_gaussian.splat',
      );

      try {
        await game.recordAction(
          profile: profile,
          action: GameAction.initiateRoom,
          isNightShift: DateTime.now().hour >= 19 || DateTime.now().hour < 7,
          facilityId: profile.facilityId,
          unitId: profile.unitId,
          roomId: widget.roomId,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSaving = false;
          _completed = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate room: $e'),
            backgroundColor: SupplyClosetColors.coral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLivePreview = _liveCameraActive &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: ListenableBuilder(
        listenable: Listenable.merge([_scannerEngine, _scanWaveController]),
        builder: (context, _) {
          return Stack(
            children: [
              // 1. Live Device Camera Feed
              if (hasLivePreview)
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width:
                          _cameraController!.value.previewSize?.height ?? 720,
                      height:
                          _cameraController!.value.previewSize?.width ?? 1280,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),

              // Subtle contrast vignette so glowing sticky dots & 3D bin cubes pop
              if (hasLivePreview)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF020617).withValues(alpha: 0.16),
                  ),
                ),

              // 2. Room-Aware AR Point Cloud + Triangulation Mesh + 3D Bin Boxes Canvas
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size =
                        Size(constraints.maxWidth, constraints.maxHeight);
                    _viewportSize = size;
                    final projectedBins = _scannerEngine.projectBinsForShelves(
                      shelves: _customAnchoredShelves.values.toList(),
                      pinnedShelfIds: _pinnedShelfIds,
                      screenSize: size,
                    );

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        _scannerEngine.addManualPan(
                          details.delta.dx,
                          details.delta.dy,
                          spawnSimulatedPointsIfNoStream: !hasLivePreview,
                        );
                      },
                      onTapUp: (details) => _handleCanvasTap(details, size),
                      child: CustomPaint(
                        painter: _StickyDotsRoomScanPainter(
                          points: _scannerEngine.points,
                          projectedBins: projectedBins,
                          cameraYawDeg: _scannerEngine.cameraYawDeg,
                          cameraPitchDeg: _scannerEngine.cameraPitchDeg,
                          scanWaveProgress: _scanWaveController.value,
                          selectedShelfId: _selectedShelfId,
                          selectedBinNumber: _selectedBinNumber,
                          activeFingerBinKey: _scannerEngine.activeFingerBinKey,
                          liveCameraActive: hasLivePreview,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 3. Top Scanner HUD, Center Crosshair + Instruction Pill, Bottom Controls
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTopScannerCard(context),
                    _buildCenterCrosshairAndPrompt(),
                    _buildBottomControls(context),
                  ],
                ),
              ),

              // 4. Completion Celebration Overlay
              if (_completed) _buildCelebrationModal(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopScannerCard(BuildContext context) {
    final pct = _progressPercent;
    final pointCount = _scannerEngine.totalPointCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Close button (48x48 glove-friendly target)
                InkWell(
                  onTap: () => Navigator.of(context).pop(false),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 22),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'ROOM SCANNER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            TextSpan(
                              text: '$pointCount',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const TextSpan(
                              text: ' Feature Points Locked · ',
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextSpan(
                              text: '$pct%',
                              style: const TextStyle(
                                color: SupplyClosetColors.success,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const TextSpan(
                              text: ' Mapped',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Recenter & Clear Dots Button
                InkWell(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    _scannerEngine.resetScanPoints();
                    await _scannerEngine.recenterDoorwayOrigin();
                    if (mounted) {
                      setState(() {
                        _lastBinReadMessage =
                            '🔄 Doorway (0,0,0) recentered — move phone to lock new dots!';
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Tooltip(
                    message: 'Reset Scan & Recenter Doorway',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.center_focus_strong_rounded,
                        color: SupplyClosetColors.tealLight,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Glowing Cyan-to-Green Progress Bar matching mockup
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    FractionallySizedBox(
                      widthFactor: (pct / 100.0).clamp(0.04, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF38BDF8),
                              Color(0xFF00F5D4),
                              SupplyClosetColors.success,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterCrosshairAndPrompt() {
    final activeFingerKey = _scannerEngine.activeFingerBinKey;
    final promptText = activeFingerKey != null
        ? '✋ READING FINGER AT SHELF ${activeFingerKey.replaceAll(":", " · BIN ")}...'
        : (_lastBinReadMessage ??
            'MOVE PHONE SLOWLY · DOTS STICK TO SHELF & BIN EDGES');

    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Crosshair Reticle from Mockup
          SizedBox(
            width: 76,
            height: 76,
            child: CustomPaint(
              painter: _CenterCrosshairPainter(
                isLockedOnFinger: activeFingerKey != null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Translucent Dark Callout Pill below Crosshair
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16).withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: activeFingerKey != null
                    ? SupplyClosetColors.warning
                    : Colors.white.withValues(alpha: 0.20),
                width: activeFingerKey != null ? 1.8 : 1.0,
              ),
            ),
            child: Text(
              promptText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: activeFingerKey != null
                    ? SupplyClosetColors.warning
                    : Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xF5020617),
            Color(0xCC020617),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Shelf & Bin Status Chips (also kept for tests & 1-tap accessibility)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final id in ['A', 'B', 'C']) ...[
                  _statusChip(
                    label: _pinnedShelfIds.contains(id)
                        ? '✓ Shelf $id (8 Bins)'
                        : '+ Anchor Shelf $id',
                    active: _pinnedShelfIds.contains(id),
                    onTap: () => _toggleShelfChip(id),
                  ),
                  const SizedBox(width: 8),
                ],
                _statusChip(
                  label: '🎯 Active: Shelf $_selectedShelfId · Bin $_selectedBinNumber',
                  active: true,
                  isGold: true,
                  onTap: () {
                    setState(() {
                      _selectedBinNumber = (_selectedBinNumber % 4) + 1;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Main Bottom Bar Matching the Approved Mockup Image
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                // Left Button: Tap to Anchor Shelf Rack
                Expanded(
                  child: InkWell(
                    onTap: _anchorShelfAtCurrentView,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.anchor_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Tap to Anchor\nShelf Rack',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Right Button: Finish Scan (+250 XP) with Glowing Green Border
                Expanded(
                  child: InkWell(
                    onTap: _isSaving ? null : _finishInitiation,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF065F46),
                            Color(0xFF047857),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: SupplyClosetColors.success,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SupplyClosetColors.success
                                .withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isSaving ? 'Saving...' : 'Finish Scan',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Text(
                                  '(+${AppConstants.pointsInitiateRoom} XP)',
                                  style: TextStyle(
                                    color: SupplyClosetColors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _isSaving
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.login_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required bool active,
    bool isGold = false,
    required VoidCallback onTap,
  }) {
    final borderColor = isGold
        ? SupplyClosetColors.warning
        : (active ? SupplyClosetColors.success : Colors.white24);
    final textColor = isGold
        ? SupplyClosetColors.warning
        : (active ? SupplyClosetColors.success : Colors.white70);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? (isGold
                  ? SupplyClosetColors.warning.withValues(alpha: 0.18)
                  : SupplyClosetColors.teal.withValues(alpha: 0.28))
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationModal(BuildContext context) {
    return Container(
      color: const Color(0xF2020617),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SupplyClosetColors.warning, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: SupplyClosetColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: SupplyClosetColors.warning, width: 2),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: SupplyClosetColors.warning,
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: SupplyClosetColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'ROOM PIONEER BADGE UNLOCKED!',
                  style: TextStyle(
                    color: SupplyClosetColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.roomName} Initiated!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${_scannerEngine.totalPointCount} Sticky Feature Points + ${_pinnedShelfIds.length} Shelf Racks (${_pinnedShelfIds.length * 8} 3D Bins) anchored to Doorway Origin (0,0,0).',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Room Initiation Reward',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '+${AppConstants.pointsInitiateRoom} XP 🎉',
                      style: TextStyle(
                        color: SupplyClosetColors.success,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SupplyClosetColors.successDark,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                ),
                icon: const Icon(Icons.explore_rounded),
                label: const Text(
                  'OPEN 3D SPLAT & GAMING FINDER →',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the center circular crosshair reticle from the approved mockup.
class _CenterCrosshairPainter extends CustomPainter {
  final bool isLockedOnFinger;

  const _CenterCrosshairPainter({required this.isLockedOnFinger});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.34;
    final color =
        isLockedOnFinger ? SupplyClosetColors.warning : Colors.white;

    final circlePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, circlePaint);

    // 4 tick lines extending through the circle
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final inner = radius * 0.42;
    final outer = radius * 1.32;

    // Top, Bottom, Left, Right ticks
    canvas.drawLine(
        Offset(center.dx, center.dy - outer),
        Offset(center.dx, center.dy - inner),
        tickPaint);
    canvas.drawLine(
        Offset(center.dx, center.dy + inner),
        Offset(center.dx, center.dy + outer),
        tickPaint);
    canvas.drawLine(
        Offset(center.dx - outer, center.dy),
        Offset(center.dx - inner, center.dy),
        tickPaint);
    canvas.drawLine(
        Offset(center.dx + inner, center.dy),
        Offset(center.dx + outer, center.dy),
        tickPaint);

    // Center dot
    canvas.drawCircle(
      center,
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _CenterCrosshairPainter oldDelegate) =>
      oldDelegate.isLockedOnFinger != isLockedOnFinger;
}

/// CustomPainter that renders:
/// 1. Sticky 3D feature points anchored to world `(yaw, pitch)` in the room:
///    - Locked points: glowing cyan/neon-green dots + thin triangulation mesh lines
///    - Newly discovered points / near scan wave: yellow/amber dots
/// 2. Vertical curved cyan-white AR scan wave sweeping across the room
/// 3. 3D Holographic Bin Wireframe Cubes (`SHELF A · BIN 1`, `BIN 2`, `BIN 3`...)
///    with `[AR]` lock reticle and `(x, y, z)` coordinate badge
class _StickyDotsRoomScanPainter extends CustomPainter {
  final List<AnchoredFeaturePoint> points;
  final List<ProjectedBinBox> projectedBins;
  final double cameraYawDeg;
  final double cameraPitchDeg;
  final double scanWaveProgress;
  final String selectedShelfId;
  final int selectedBinNumber;
  final String? activeFingerBinKey;
  final bool liveCameraActive;

  _StickyDotsRoomScanPainter({
    required this.points,
    required this.projectedBins,
    required this.cameraYawDeg,
    required this.cameraPitchDeg,
    required this.scanWaveProgress,
    required this.selectedShelfId,
    required this.selectedBinNumber,
    required this.activeFingerBinKey,
    required this.liveCameraActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // If running in simulator without live camera, draw subtle shelf rack silhouettes
    if (!liveCameraActive) {
      _drawSimulatedRoomBackdrop(canvas, size);
    }

    // 1. Compute vertical curved scan wave X position across the screen
    final pingPong = 0.5 - 0.5 * math.cos(scanWaveProgress * math.pi * 2);
    final waveX = size.width * (0.18 + pingPong * 0.64);

    // 2. Project all Sticky 3D Feature Points onto current camera viewport
    final visibleLockedOffsets = <Offset>[];
    final visiblePoints = <(Offset, AnchoredFeaturePoint, bool)>[];

    for (final pt in points) {
      final relYaw = pt.worldYawDeg - cameraYawDeg;
      final relPitch = pt.worldPitchDeg - cameraPitchDeg;
      if (relYaw.abs() > 38.0 || relPitch.abs() > 45.0) continue;

      final sx = size.width * 0.5 +
          (relYaw / SpatialRoomScannerEngine.horizontalFovDeg) * size.width;
      final sy = size.height * 0.48 -
          (relPitch / SpatialRoomScannerEngine.verticalFovDeg) * size.height;

      if (sx < -10 ||
          sx > size.width + 10 ||
          sy < size.height * 0.12 ||
          sy > size.height * 0.88) {
        continue;
      }

      final screenPt = Offset(sx, sy);
      final nearWave = (sx - waveX).abs() < 34.0;
      visiblePoints.add((screenPt, pt, nearWave));
      if (pt.isLocked && !nearWave) {
        visibleLockedOffsets.add(screenPt);
      }
    }

    // 3. Draw Triangulation Mesh Lines connecting nearby locked sticky dots
    final meshPaint = Paint()
      ..color = const Color(0xFF00F5D4).withValues(alpha: 0.28)
      ..strokeWidth = 0.9;

    for (int i = 0; i < visibleLockedOffsets.length; i++) {
      final p1 = visibleLockedOffsets[i];
      int connections = 0;
      for (int j = i + 1; j < visibleLockedOffsets.length; j++) {
        final p2 = visibleLockedOffsets[j];
        final dist = (p1 - p2).distance;
        if (dist > 18.0 && dist < 86.0) {
          canvas.drawLine(p1, p2, meshPaint);
          connections++;
          if (connections >= 3) break;
        }
      }
    }

    // 4. Draw Sticky Feature Dots (Yellow for newly discovered/wave, Cyan/Green for locked)
    for (final (offset, pt, nearWave) in visiblePoints) {
      final isYellowNew = !pt.isLocked || nearWave;
      final coreColor = isYellowNew
          ? const Color(0xFFFACC15) // Bright yellow discovery dot
          : (pt.id.isEven
              ? const Color(0xFF10B981) // Neon green locked dot
              : const Color(0xFF00F5D4)); // Glowing cyan locked dot

      final radius = isYellowNew ? 3.2 : 4.2;

      // Outer glow halo
      canvas.drawCircle(
        offset,
        radius * 2.3,
        Paint()..color = coreColor.withValues(alpha: 0.26),
      );
      // Solid bright dot core
      canvas.drawCircle(
        offset,
        radius,
        Paint()..color = coreColor,
      );
    }

    // 5. Draw Glowing Vertical Curved AR Scan Wave (matching mockup)
    final wavePath = Path()
      ..moveTo(waveX + 26, size.height * 0.12)
      ..quadraticBezierTo(
        waveX - 28,
        size.height * 0.50,
        waveX + 22,
        size.height * 0.88,
      );

    canvas.drawPath(
      wavePath,
      Paint()
        ..color = const Color(0xFF67E8F9).withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      wavePath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    // 6. Draw 3D Perspective Wireframe Bin Boxes stuck to the room
    for (final bin in projectedBins) {
      final isSelected = bin.shelfId == selectedShelfId &&
          bin.binNumber == selectedBinNumber;
      final isFingerActive = bin.key == activeFingerBinKey;
      final highlightGold = isSelected || isFingerActive;

      _draw3DBinCube(
        canvas: canvas,
        bin: bin,
        highlightGold: highlightGold,
        isFingerActive: isFingerActive,
      );
    }
  }

  void _draw3DBinCube({
    required Canvas canvas,
    required ProjectedBinBox bin,
    required bool highlightGold,
    required bool isFingerActive,
  }) {
    final primaryColor = highlightGold
        ? const Color(0xFFFACC15) // Gold/yellow active 3D bin box
        : const Color(0xFF7DD3FC); // Crisp light-cyan wireframe bin box

    final front = bin.frontRect;
    final back = bin.backRect;

    // Translucent glass fill on front & side faces
    final fillPaint = Paint()
      ..color = primaryColor.withValues(alpha: highlightGold ? 0.16 : 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawRect(front, fillPaint);

    final wirePaint = Paint()
      ..color = primaryColor.withValues(alpha: highlightGold ? 0.95 : 0.75)
      ..strokeWidth = highlightGold ? 2.2 : 1.5
      ..style = PaintingStyle.stroke;

    // Draw back face, front face, and 4 depth edges of the 3D cube
    canvas.drawRect(
      back,
      Paint()
        ..color = primaryColor.withValues(alpha: highlightGold ? 0.55 : 0.40)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawRect(front, wirePaint);

    canvas.drawLine(front.topLeft, back.topLeft, wirePaint);
    canvas.drawLine(front.topRight, back.topRight, wirePaint);
    canvas.drawLine(front.bottomLeft, back.bottomLeft, wirePaint);
    canvas.drawLine(front.bottomRight, back.bottomRight, wirePaint);

    // Top Label Tab ("SHELF A · BIN 2")
    final labelTp = TextPainter(
      text: TextSpan(
        text: bin.label,
        style: const TextStyle(
          color: Color(0xFF020617),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tabRect = Rect.fromLTWH(
      front.left,
      back.top - 20,
      labelTp.width + 14,
      19,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tabRect, const Radius.circular(4)),
      Paint()
        ..color = highlightGold
            ? const Color(0xFFFACC15)
            : const Color(0xFFBAE6FD),
    );
    labelTp.paint(canvas, Offset(tabRect.left + 7, tabRect.top + 2.5));

    // If this bin is selected or finger-read, draw the [ AR ] corner reticle
    // inside the cube AND the (x, y, z) coordinate badge to its right!
    if (highlightGold) {
      _drawArCornerReticle(canvas, front.center, primaryColor, isFingerActive);

      final loc = bin.location3D;
      final coordCardRect = Rect.fromLTWH(
        front.right + 8,
        front.center.dy - 28,
        74,
        56,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(coordCardRect, const Radius.circular(8)),
        Paint()..color = const Color(0xD9090D16),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(coordCardRect, const Radius.circular(8)),
        Paint()
          ..color = primaryColor.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      final coordTp = TextPainter(
        text: TextSpan(
          text: 'x: ${loc.x}m\ny: ${loc.y}m\nz: ${loc.z}m',
          style: const TextStyle(
            color: Color(0xFFFDE047),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.28,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      coordTp.paint(
        canvas,
        Offset(coordCardRect.left + 8, coordCardRect.top + 6),
      );
    }
  }

  void _drawArCornerReticle(
    Canvas canvas,
    Offset center,
    Color color,
    bool isFingerActive,
  ) {
    const half = 17.0;
    const corner = 6.5;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Top-left bracket
    canvas.drawLine(
        center + const Offset(-half, -half),
        center + const Offset(-half + corner, -half),
        p);
    canvas.drawLine(
        center + const Offset(-half, -half),
        center + const Offset(-half, -half + corner),
        p);
    // Top-right bracket
    canvas.drawLine(
        center + const Offset(half, -half),
        center + const Offset(half - corner, -half),
        p);
    canvas.drawLine(
        center + const Offset(half, -half),
        center + const Offset(half, -half + corner),
        p);
    // Bottom-left bracket
    canvas.drawLine(
        center + const Offset(-half, half),
        center + const Offset(-half + corner, half),
        p);
    canvas.drawLine(
        center + const Offset(-half, half),
        center + const Offset(-half, half - corner),
        p);
    // Bottom-right bracket
    canvas.drawLine(
        center + const Offset(half, half),
        center + const Offset(half - corner, half),
        p);
    canvas.drawLine(
        center + const Offset(half, half),
        center + const Offset(half, half - corner),
        p);

    final tp = TextPainter(
      text: TextSpan(
        text: isFingerActive ? '✋' : 'AR',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawSimulatedRoomBackdrop(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = SupplyClosetColors.tealLight.withValues(alpha: 0.14)
      ..strokeWidth = 1.0;
    for (double y = size.height * 0.20; y < size.height * 0.85; y += 52) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StickyDotsRoomScanPainter oldDelegate) => true;
}
