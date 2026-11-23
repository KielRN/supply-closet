import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/supply_item.dart';
import '../../models/supply_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/gamification_service.dart';
import '../../services/spatial_room_scanner.dart';
import '../../widgets/room_switcher_sheet.dart';
import '../../widgets/user_avatar.dart';
import '../room/room_initiation_screen.dart';
import '../bounty/bounty_board_sheet.dart';
import 'doorway_finder_controls.dart';

/// Gaming-style Spatial Finder Screen combining:
/// 1. "God's Eye View" 3D Gaussian Splat + Shelf/Bin Volume Viewer
/// 2. First-Person Gaming AR HUD (Compass Ribbon, Mini-Radar, 360° Off-Screen
///    Edge Chevrons, 3D Floor Path Chevrons, and Target Lock Diamond)
/// 3. User-Initiated Supply Bounty Creation when a needed supply isn't tagged yet
class ArFinderScreen extends StatefulWidget {
  final String? procedureId;
  final List<String>? targetSupplyNames;

  const ArFinderScreen({
    super.key,
    this.procedureId,
    this.targetSupplyNames,
  });

  @override
  State<ArFinderScreen> createState() => _ArFinderScreenState();
}

class _ArFinderScreenState extends State<ArFinderScreen> {
  final _firestore = FirestoreService();
  final _searchController = TextEditingController();
  final Set<String> _foundSupplyIds = {};
  late final SpatialRoomScannerEngine _scannerEngine;

  CameraController? _cameraController;
  bool _arSupported = true;
  bool _useArCamera = false; // false = 3D Gaussian Splat God's Eye View, true = AR HUD
  bool _liveCameraActive = false;
  int _sensorOrientation = 90;
  Size _arViewportSize = const Size(390, 844);
  SupplyItem? _currentActiveSupply;
  String _currentRoomId = AppConstants.defaultRoomId;

  // 3D Gaussian Splat Viewer toggles & camera orbit
  bool _showGaussianSplat = true;
  bool _showBinBoxes = true;
  double _orbitAngle = 0.32;

  // First-person AR HUD simulated/camera yaw (-75° to +75°)
  double _cameraYawDeg = 0.0;
  int _selectedSupplyIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _arSupported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!RoomInitiationScreen.usesDoorwayScanner) {
      _scannerEngine = SpatialRoomScannerEngine(
      onFingerReadBin: (shelfId, binNumber) {
        if (!mounted || !_useArCamera) return;
        final active = _currentActiveSupply;
        if (active != null) {
          _confirmGrabbed(active, _currentRoomId);
        }
      },
    )..addListener(_onScannerEngineUpdated);
      _scannerEngine.startSensors();
    }

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim();
          _selectedSupplyIndex = 0;
        });
      }
    });
  }

  void _onScannerEngineUpdated() {
    if (!mounted || !_useArCamera) return;
    setState(() {
      _cameraYawDeg = _scannerEngine.cameraYawDeg.clamp(-75.0, 75.0);
    });
  }

  Future<void> _ensureCameraInitialized() async {
    if (kIsWeb) return;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      if (mounted) setState(() => _liveCameraActive = true);
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _sensorOrientation = backCam.sensorOrientation;
      final controller = CameraController(
        backCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      try {
        await controller.startImageStream((CameraImage image) {
          if (!mounted || !_useArCamera) return;
          _scannerEngine.processCameraFrame(
            image: image,
            sensorOrientation: _sensorOrientation,
            shelves: SupplyRoom.defaultInitiatedShelves(),
            pinnedShelfIds: const {'A', 'B', 'C'},
            screenSize: _arViewportSize,
          );
        });
      } catch (_) {}
      setState(() {
        _cameraController = controller;
        _liveCameraActive = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _liveCameraActive = false);
      }
    }
  }

  Future<void> _toggleArHudMode() async {
    final nextMode = !_useArCamera;
    setState(() => _useArCamera = nextMode);
    if (nextMode && _arSupported) {
      await _ensureCameraInitialized();
    }
  }

  Future<void> _toggleLiveCamera() async {
    if (_liveCameraActive) {
      setState(() => _liveCameraActive = false);
    } else {
      await _ensureCameraInitialized();
    }
  }

  @override
  void dispose() {
    if (!RoomInitiationScreen.usesDoorwayScanner) {
      _scannerEngine.removeListener(_onScannerEngineUpdated);
      _scannerEngine.dispose();
    }
    _cameraController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<SupplyItem> _filterSupplies(List<SupplyItem> all) {
    Iterable<SupplyItem> result = all;
    if (widget.targetSupplyNames != null &&
        widget.targetSupplyNames!.isNotEmpty) {
      final targets = widget.targetSupplyNames!.map((n) => n.toLowerCase());
      result = result.where(
          (s) => targets.any((t) => s.name.toLowerCase().contains(t)));
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) =>
          s.name.toLowerCase().contains(q) ||
          (s.category?.toLowerCase().contains(q) ?? false) ||
          s.location.displayLabel.toLowerCase().contains(q));
    }
    return result.toList();
  }

  double _targetYawForSupply(SupplyItem? supply, SupplyRoom room) {
    if (supply == null) return 0.0;
    final shelf = room.findShelf(supply.location.shelf) ??
        ShelfRack.defaultForCode(supply.location.shelf ?? 'A');
    final bin = supply.location.bin ?? 1;
    final colIdx = (bin - 1) % shelf.binsPerRow;
    final colOffset = (colIdx - (shelf.binsPerRow - 1) / 2.0) * 7.5;
    return shelf.yawDegrees + colOffset;
  }

  String _elevationLabelForSupply(SupplyItem? supply, SupplyRoom room) {
    if (supply == null) return 'Eye Level ▲';
    final shelf = room.findShelf(supply.location.shelf) ??
        ShelfRack.defaultForCode(supply.location.shelf ?? 'A');
    return shelf.elevationLabelForBin(supply.location.bin);
  }

  double _distanceMetersForSupply(SupplyItem? supply, SupplyRoom room) {
    if (supply == null) return 2.1;
    final loc = supply.location;
    if (loc.x != 0 || loc.z != 0) {
      return double.parse(
          math.sqrt(loc.x * loc.x + loc.z * loc.z).toStringAsFixed(1));
    }
    final shelf = room.findShelf(loc.shelf) ??
        ShelfRack.defaultForCode(loc.shelf ?? 'A');
    return shelf.distanceMeters;
  }

  void _selectSupply(int idx, List<SupplyItem> supplies, SupplyRoom room) {
    if (idx < 0 || idx >= supplies.length) return;
    final item = supplies[idx];
    final targetYaw = _targetYawForSupply(item, room);
    setState(() {
      _selectedSupplyIndex = idx;
      // Fly 3D Splat camera to face this shelf
      _orbitAngle = (targetYaw * math.pi / 180.0) * 0.65;
    });
  }

  Future<void> _confirmGrabbed(SupplyItem supply, String roomId) async {
    final auth = context.read<AuthProvider>();
    final game = context.read<GamificationProvider>();
    final profile = auth.profile;

    setState(() {
      _foundSupplyIds.add(supply.id);
    });

    if (profile != null) {
      try {
        await game.recordAction(
          profile: profile,
          action: GameAction.confirmExisting,
          isNightShift: DateTime.now().hour >= 19 || DateTime.now().hour < 7,
          facilityId: profile.facilityId,
          unitId: profile.unitId,
          roomId: roomId,
          supplyId: supply.id,
        );
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Grabbed ${supply.name} from ${supply.location.displayLabel} (+${AppConstants.pointsConfirmExisting} XP)!',
          ),
          backgroundColor: SupplyClosetColors.successDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _reportMissingAndOfferBounty(
    SupplyItem supply,
    String facilityId,
    String unitId,
    String roomId,
    SupplyRoom room,
  ) async {
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    if (profile != null &&
        profile.facilityId != null &&
        profile.unitId != null) {
      try {
        await _firestore.reportNotFound(
          facilityId: profile.facilityId!,
          unitId: profile.unitId!,
          roomId: roomId,
          supplyId: supply.id,
          userId: profile.uid,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    BountyBoardSheet.show(
      context,
      facilityId: facilityId,
      unitId: unitId,
      roomId: roomId,
      room: room,
      initialSupplyNameToPost: supply.name,
      initialNote:
          'Missing from ${supply.location.displayLabel} — please locate & re-tag!',
      onHuntBounty: (bounty) {
        context.go(
          Uri(
            path: '/tag',
            queryParameters: {
              'supply': bounty.supplyName,
              'bountyId': bounty.id,
            },
          ).toString(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final roomProv = context.watch<RoomProvider>();
    final profile = auth.profile;
    final facilityId = profile?.facilityId ?? 'txai_pilot_lab';
    final unitId = profile?.unitId ?? 'med_3a';
    final unitName = profile?.unitName ?? 'Med 3A';
    final roomId = roomProv.selectedRoomId;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: StreamBuilder<SupplyRoom>(
        key: ValueKey((profile?.uid, facilityId, unitId, roomId)),
        stream: _firestore.roomStream(facilityId, unitId, roomId),
        builder: (context, roomSnap) {
          final room = roomSnap.data ?? SupplyRoom.uninitiated(roomId);

          return StreamBuilder<List<SupplyItem>>(
            stream: _firestore.suppliesInRoom(facilityId, unitId, roomId),
            builder: (context, supplySnap) {
              final allSupplies = supplySnap.data ?? [];
              final supplies = _filterSupplies(allSupplies);
              final activeIdx = supplies.isEmpty
                  ? 0
                  : _selectedSupplyIndex.clamp(0, supplies.length - 1);
              final activeSupply =
                  supplies.isNotEmpty ? supplies[activeIdx] : null;
              _currentActiveSupply = activeSupply;
              _currentRoomId = roomId;

              return Stack(
                children: [
                  // 1. Spatial Viewport: Either 3D Gaussian Splat God's Eye View OR Gaming AR HUD
                  Positioned.fill(
                    child: _useArCamera
                        ? _buildGamingArViewport(
                            room: room,
                            supplies: supplies,
                            activeSupply: activeSupply,
                          )
                        : _buildGodsEyeSplatViewport(
                            room: room,
                            supplies: supplies,
                            activeSupply: activeSupply,
                          ),
                  ),

                  // 2. Top Gaming HUD (Room Switcher, Compass Ribbon, Search Bar, Target Lock Banner, Mini-Radar)
                  SafeArea(
                    child: Column(
                      children: [
                        _buildTopGamingHud(
                          context: context,
                          facilityId: facilityId,
                          unitId: unitId,
                          unitName: unitName,
                          roomId: roomId,
                          room: room,
                          supplies: supplies,
                          activeSupply: activeSupply,
                        ),

                        // Uninitiated Room Contract Banner
                        if (!room.isInitiated)
                          _buildInitiateRoomBanner(context, roomId, room.name),

                        const Spacer(),

                        // Off-Screen 360° Edge Turn Chevrons (when in AR HUD mode)
                        if (_useArCamera && activeSupply != null)
                          _buildOffScreenEdgeChevrons(activeSupply, room),

                        const Spacer(),

                        // Empty / Untagged Supply -> Post Bounty Prompt Card
                        if (supplies.isEmpty)
                          _buildUntaggedSupplyBountyCard(
                            context: context,
                            facilityId: facilityId,
                            unitId: unitId,
                            roomId: roomId,
                            room: room,
                          )
                        else
                          _buildBottomGamingControls(
                            context: context,
                            facilityId: facilityId,
                            unitId: unitId,
                            roomId: roomId,
                            room: room,
                            supplies: supplies,
                            activeSupply: activeSupply!,
                            activeIdx: activeIdx,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ─── VIEWPORT 1: GOD'S EYE 3D GAUSSIAN SPLAT VIEWER ───────────

  Widget _buildGodsEyeSplatViewport({
    required SupplyRoom room,
    required List<SupplyItem> supplies,
    required SupplyItem? activeSupply,
  }) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _orbitAngle += details.delta.dx * 0.012;
        });
      },
      child: CustomPaint(
        painter: _GodsEyeSplatPainter(
          room: room,
          supplies: supplies,
          activeSupply: activeSupply,
          foundIds: _foundSupplyIds,
          showGaussianSplat: _showGaussianSplat,
          showBinBoxes: _showBinBoxes,
          orbitAngle: _orbitAngle,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  // ─── VIEWPORT 2: FIRST-PERSON GAMING AR HUD ───────────────────

  Widget _buildGamingArViewport({
    required SupplyRoom room,
    required List<SupplyItem> supplies,
    required SupplyItem? activeSupply,
  }) {
    final targetYaw = _targetYawForSupply(activeSupply, room);
    final hasLiveCam = _arSupported &&
        _liveCameraActive &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _arViewportSize = size;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            _scannerEngine.addManualPan(
              details.delta.dx,
              0,
              spawnSimulatedPointsIfNoStream: !hasLiveCam,
            );
            setState(() {
              _cameraYawDeg =
                  (_cameraYawDeg - details.delta.dx * 0.25).clamp(-75.0, 75.0);
            });
          },
          onTapUp: (details) {
            if (activeSupply == null) return;
            final targetX = (size.width / 2) + (targetYaw - _cameraYawDeg) * 4.5;
            final bin = activeSupply.location.bin ?? 1;
            final rowIdx = ((bin - 1) ~/ 2).clamp(0, 3);
            final targetY = size.height * 0.30 + (rowIdx * 48.0);
            final binHitRect = Rect.fromCenter(
              center: Offset(targetX, targetY),
              width: 110,
              height: 92,
            );
            if (binHitRect.contains(details.localPosition)) {
              HapticFeedback.heavyImpact();
              _confirmGrabbed(activeSupply, _currentRoomId);
            }
          },
          child: Stack(
            children: [
              if (hasLiveCam)
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
              if (hasLiveCam)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF020617).withValues(alpha: 0.18),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GamingArHudPainter(
                      room: room,
                      activeSupply: activeSupply,
                      cameraYawDeg: _cameraYawDeg,
                      cameraPitchDeg: _scannerEngine.cameraPitchDeg,
                      targetYawDeg: targetYaw,
                      liveCameraActive: hasLiveCam,
                      stickyPoints: _scannerEngine.points,
                      isFound: activeSupply != null &&
                          _foundSupplyIds.contains(activeSupply.id),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── TOP GAMING HUD ───────────────────────────────────────────

  Widget _buildTopGamingHud({
    required BuildContext context,
    required String facilityId,
    required String unitId,
    required String unitName,
    required String roomId,
    required SupplyRoom room,
    required List<SupplyItem> supplies,
    required SupplyItem? activeSupply,
  }) {
    final targetYaw = _targetYawForSupply(activeSupply, room);
    final dist = _distanceMetersForSupply(activeSupply, room);
    final elevation = _elevationLabelForSupply(activeSupply, room);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xF2020617),
            Color(0xB3020617),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // 0. Active Supply Room Switcher + Door Plaque Scanner + Room Captain Bar
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => RoomSwitcherSheet.show(
                    context,
                    facilityId: facilityId,
                    unitId: unitId,
                    unitName: unitName,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: SupplyClosetColors.tealLight,
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.meeting_room_rounded,
                          color: SupplyClosetColors.tealLight,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$unitName · ${room.name}${room.doorCode != null ? " (${room.doorCode})" : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: SupplyClosetColors.tealLight,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Door Sign Scanner Quick Button
              InkWell(
                onTap: () => RoomSwitcherSheet.show(
                  context,
                  facilityId: facilityId,
                  unitId: unitId,
                  unitName: unitName,
                  openDoorScannerInitially: true,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        color: SupplyClosetColors.tealLight,
                        size: 15,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Door Sign',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Room Captain Badge + Pin Hint Button
              InkWell(
                onTap: () => CaptainHintSheet.show(
                  context,
                  facilityId: facilityId,
                  unitId: unitId,
                  room: room,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: SupplyClosetColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: SupplyClosetColors.warning,
                      width: 1.3,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (room.hasCaptain) ...[
                        UserAvatar(
                          displayName: room.captainName ?? 'Captain',
                          photoUrl: room.captainAvatar,
                          radius: 10,
                          isCaptain: false,
                        ),
                        const SizedBox(width: 5),
                      ] else ...[
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: SupplyClosetColors.warning,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        room.hasCaptain
                            ? '👑 ${(room.captainName ?? "Capt").split(" ").first} · +Hint'
                            : '👑 Capt +Hint',
                        style: const TextStyle(
                          color: SupplyClosetColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 1. Compass Ribbon (Skyrim / Halo / Apex style)
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: SupplyClosetColors.tealLight.withValues(alpha: 0.5)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Transform.translate(
                    offset: Offset(-_cameraYawDeg * 2.2, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('NW   •   ',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                        const Text('◄ SHELF A (-32°)   •   ',
                            style: TextStyle(
                                color: SupplyClosetColors.tealLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                        const Text('N [DOORWAY 0°]   •   ',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        if (activeSupply != null)
                          Text(
                            '🎯 ${activeSupply.location.displayLabel.toUpperCase()}   •   ',
                            style: const TextStyle(
                              color: SupplyClosetColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        const Text('SHELF C (+34°) ►   •   NE',
                            style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                // Center Lubber Line
                Container(
                  width: 2,
                  height: 28,
                  color: SupplyClosetColors.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. Search Input + Mode Toggle + Bounties Button + Mini-Radar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Search Bar + Bounties Button Row
                    Row(
                      children: [
                        if (Navigator.of(context).canPop()) ...[
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 38,
                              height: 38,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Search supply or untagged item...',
                                hintStyle: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 0),
                                prefixIcon: const Icon(Icons.search,
                                    color: SupplyClosetColors.tealLight,
                                    size: 18),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            color: Colors.white54, size: 16),
                                        onPressed: () =>
                                            _searchController.clear(),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.white24),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Mode Switcher: 3D Splat vs AR HUD
                        InkWell(
                          onTap: RoomInitiationScreen.usesDoorwayScanner
                              ? () => showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (sheetContext) => SafeArea(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(20),
                                        child: DoorwayFinderControls(
                                          room: room,
                                          profile: context.read<AuthProvider>().profile,
                                          supply: activeSupply,
                                        ),
                                      ),
                                    ),
                                  )
                              : _toggleArHudMode,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: _useArCamera
                                  ? SupplyClosetColors.successDark
                                  : const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              RoomInitiationScreen.usesDoorwayScanner ? 'Find in AR' : (_useArCamera ? '🌐 3D Splat' : '🎯 AR HUD'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // High-Contrast Shelf + Bin Target Lock Banner (DEC-007)
                    if (activeSupply != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF064E3B).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: SupplyClosetColors.success, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: SupplyClosetColors.success,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                activeSupply.location.displayLabel.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF020617),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${activeSupply.name} · $elevation',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${dist}m ▲',
                              style: const TextStyle(
                                color: SupplyClosetColors.warning,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Top-Right Mini-Map Radar
              GestureDetector(
                onTap: () => BountyBoardSheet.show(
                  context,
                  facilityId: facilityId,
                  unitId: unitId,
                  roomId: roomId,
                  room: room,
                  onHuntBounty: (bounty) {
                    context.go(
                      Uri(
                        path: '/tag',
                        queryParameters: {
                          'supply': bounty.supplyName,
                          'bountyId': bounty.id,
                        },
                      ).toString(),
                    );
                  },
                ),
                child: Container(
                  width: 76,
                  height: 84,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: SupplyClosetColors.tealLight, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'RADAR',
                        style: TextStyle(
                          color: SupplyClosetColors.tealLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Expanded(
                        child: CustomPaint(
                          painter: _MiniRadarPainter(
                            cameraYawDeg: _cameraYawDeg,
                            targetYawDeg: targetYaw,
                            hasTarget: activeSupply != null,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Layer Toggle Pills Row (3D Splat Controls or AR Camera Toggle + Bounties)
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (!_useArCamera) ...[
                  _hudPill(
                    label:
                        '✨ Gaussian Splat: ${_showGaussianSplat ? "ON" : "OFF"}',
                    active: _showGaussianSplat,
                    onTap: () => setState(
                        () => _showGaussianSplat = !_showGaussianSplat),
                  ),
                  const SizedBox(width: 6),
                  _hudPill(
                    label: '📦 3D Bin Boxes: ${_showBinBoxes ? "ON" : "OFF"}',
                    active: _showBinBoxes,
                    onTap: () => setState(() => _showBinBoxes = !_showBinBoxes),
                  ),
                  const SizedBox(width: 6),
                  _hudPill(
                    label: '🔄 Orbit 45°',
                    active: false,
                    onTap: () => setState(() => _orbitAngle += 0.55),
                  ),
                ] else ...[
                  if (_arSupported)
                    _hudPill(
                      label: _liveCameraActive
                          ? '📷 Live Camera: ON'
                          : '📷 Live Camera: OFF (HUD Sim)',
                      active: _liveCameraActive,
                      onTap: _toggleLiveCamera,
                    ),
                ],
                const SizedBox(width: 6),
                _hudPill(
                  label: '🎯 Unit Bounties (+50 XP)',
                  active: true,
                  isWarning: true,
                  onTap: () => BountyBoardSheet.show(
                    context,
                    facilityId: facilityId,
                    unitId: unitId,
                    roomId: roomId,
                    room: room,
                    onHuntBounty: (bounty) {
                      context.go(
                        Uri(
                          path: '/tag',
                          queryParameters: {
                            'supply': bounty.supplyName,
                            'bountyId': bounty.id,
                          },
                        ).toString(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudPill({
    required String label,
    required bool active,
    bool isWarning = false,
    required VoidCallback onTap,
  }) {
    final borderColor = isWarning
        ? SupplyClosetColors.warning
        : (active ? SupplyClosetColors.tealLight : Colors.white24);
    final bgColor = isWarning
        ? SupplyClosetColors.warning.withValues(alpha: 0.22)
        : (active
            ? SupplyClosetColors.teal.withValues(alpha: 0.28)
            : const Color(0xFF0F172A));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isWarning
                ? SupplyClosetColors.warning
                : (active ? SupplyClosetColors.success : Colors.white70),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildInitiateRoomBanner(
      BuildContext context, String roomId, String roomName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SupplyClosetColors.warning, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.radar_rounded,
              color: SupplyClosetColors.warning, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              RoomInitiationScreen.usesDoorwayScanner
                  ? 'Set up $roomName to mark a bin from its doorway.'
                  : '$roomName not initiated! Scan room & pin shelves for +250 XP.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RoomInitiationScreen(
                    roomId: roomId,
                    roomName: roomName,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SupplyClosetColors.warning,
              foregroundColor: const Color(0xFF020617),
              minimumSize: const Size(84, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text(
              'Scan +250 XP',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ─── OFF-SCREEN 360° EDGE TURN CHEVRONS ──────────────────────

  Widget _buildOffScreenEdgeChevrons(SupplyItem activeSupply, SupplyRoom room) {
    final targetYaw = _targetYawForSupply(activeSupply, room);
    final relAngle = (targetYaw - _cameraYawDeg).round();

    if (relAngle.abs() <= 20) return const SizedBox.shrink();

    final isLeft = relAngle < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: SupplyClosetColors.warning,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: SupplyClosetColors.warning.withValues(alpha: 0.45),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLeft)
                const Text(
                  '◄◄ ',
                  style: TextStyle(
                    color: Color(0xFF020617),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              Column(
                crossAxisAlignment:
                    isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Text(
                    'TURN ${isLeft ? "LEFT" : "RIGHT"} ${relAngle.abs()}°',
                    style: const TextStyle(
                      color: Color(0xFF020617),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    activeSupply.location.displayLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF020617),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (!isLeft)
                const Text(
                  ' ►►',
                  style: TextStyle(
                    color: Color(0xFF020617),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── UNTAGGED SUPPLY -> USER-INITIATED BOUNTY CARD ────────────

  Widget _buildUntaggedSupplyBountyCard({
    required BuildContext context,
    required String facilityId,
    required String unitId,
    required String roomId,
    required SupplyRoom room,
  }) {
    final wantedName =
        _searchQuery.isNotEmpty ? _searchQuery : 'Needed Clinical Supply';
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SupplyClosetColors.warning, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SupplyClosetColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gps_fixed_rounded,
                    color: SupplyClosetColors.warning, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _searchQuery.isNotEmpty
                          ? '"$_searchQuery" Not Tagged Yet!'
                          : 'No Supplies Tagged in This Room Yet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      'Post a Supply Bounty so a teammate can hunt & tag it for +50 Bonus XP!',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => BountyBoardSheet.show(
              context,
              facilityId: facilityId,
              unitId: unitId,
              roomId: roomId,
              room: room,
              initialSupplyNameToPost:
                  _searchQuery.isNotEmpty ? _searchQuery : '',
              initialNote:
                  'Needed on floor — not tagged in ${room.name} yet!',
              onHuntBounty: (bounty) {
                context.go(
                  Uri(
                    path: '/tag',
                    queryParameters: {
                      'supply': bounty.supplyName,
                      'bountyId': bounty.id,
                    },
                  ).toString(),
                );
              },
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: SupplyClosetColors.warning,
              foregroundColor: const Color(0xFF020617),
              minimumSize: const Size(double.infinity, 50),
            ),
            icon: const Icon(Icons.add_alert_rounded),
            label: Text(
              _searchQuery.isNotEmpty
                  ? '🎯 POST BOUNTY FOR "${wantedName.toUpperCase()}" (+50 XP)'
                  : '🎯 POST A SUPPLY BOUNTY (+50 XP FOR HUNTER)',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go(
              Uri(
                path: '/tag',
                queryParameters:
                    _searchQuery.isNotEmpty ? {'supply': _searchQuery} : null,
              ).toString(),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: SupplyClosetColors.tealLight,
              side: const BorderSide(color: SupplyClosetColors.tealLight),
              minimumSize: const Size(double.infinity, 46),
            ),
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: const Text('Found it myself? Tag Location Now (+10 XP)'),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM GAMING HUD CONTROLS & FLY-TO SUPPLY BAR ───────────

  Widget _buildBottomGamingControls({
    required BuildContext context,
    required String facilityId,
    required String unitId,
    required String roomId,
    required SupplyRoom room,
    required List<SupplyItem> supplies,
    required SupplyItem activeSupply,
    required int activeIdx,
  }) {
    final targetYaw = _targetYawForSupply(activeSupply, room);
    final relAngle = (targetYaw - _cameraYawDeg).round();
    final isLocked = relAngle.abs() <= 20;
    final isFound = _foundSupplyIds.contains(activeSupply.id);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xFA020617),
            Color(0xE6020617),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Look-Around / Turn Simulation Slider when in AR HUD mode
          if (_useArCamera)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🔄 Pan / Turn Heading in Room:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isLocked
                            ? '🎯 LOCKED ON ${activeSupply.location.displayLabel.toUpperCase()}'
                            : (relAngle < 0
                                ? '◄ ${relAngle.abs()}° LEFT'
                                : '${relAngle.abs()}° RIGHT ►'),
                        style: TextStyle(
                          color: isLocked
                              ? SupplyClosetColors.success
                              : SupplyClosetColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 28,
                    child: Slider(
                      value: _cameraYawDeg,
                      min: -75,
                      max: 75,
                      activeColor: SupplyClosetColors.tealLight,
                      inactiveColor: const Color(0xFF334155),
                      onChanged: (v) => setState(() => _cameraYawDeg = v),
                    ),
                  ),
                ],
              ),
            ),

          // 1-Tap Glove-Friendly Action Row: GRABBED IT vs NOT HERE -> BOUNTY
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmGrabbed(activeSupply, roomId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFound
                        ? const Color(0xFF059669)
                        : SupplyClosetColors.successDark,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                  ),
                  icon: Icon(
                    isFound ? Icons.verified_rounded : Icons.check_circle,
                    size: 20,
                  ),
                  label: Text(
                    isFound
                        ? 'CONFIRMED (+5 XP)'
                        : 'GRABBED IT (+${AppConstants.pointsConfirmExisting} XP)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reportMissingAndOfferBounty(
                    activeSupply,
                    facilityId,
                    unitId,
                    roomId,
                    room,
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        SupplyClosetColors.coral.withValues(alpha: 0.16),
                    foregroundColor: SupplyClosetColors.coralLight,
                    side: const BorderSide(color: SupplyClosetColors.coral),
                    minimumSize: const Size(0, 50),
                  ),
                  icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                  label: const Text(
                    'NOT HERE → BOUNTY',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Click-to-Fly Supply Selector Cards
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: supplies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final item = supplies[idx];
                final selected = idx == activeIdx;
                final found = _foundSupplyIds.contains(item.id);
                return InkWell(
                  onTap: () => _selectSupply(idx, supplies, room),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 155,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? SupplyClosetColors.teal.withValues(alpha: 0.32)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? SupplyClosetColors.success
                            : Colors.white24,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              found
                                  ? Icons.check_circle
                                  : Icons.my_location_rounded,
                              size: 14,
                              color: found
                                  ? SupplyClosetColors.success
                                  : SupplyClosetColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.location.displayLabel.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SupplyClosetColors.success,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PAINTER 1: GOD'S EYE 3D GAUSSIAN SPLAT & SHELF VOLUMES ──────

class _GodsEyeSplatPainter extends CustomPainter {
  final SupplyRoom room;
  final List<SupplyItem> supplies;
  final SupplyItem? activeSupply;
  final Set<String> foundIds;
  final bool showGaussianSplat;
  final bool showBinBoxes;
  final double orbitAngle;

  _GodsEyeSplatPainter({
    required this.room,
    required this.supplies,
    required this.activeSupply,
    required this.foundIds,
    required this.showGaussianSplat,
    required this.showBinBoxes,
    required this.orbitAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.50;
    final cosA = math.cos(orbitAngle);
    final sinA = math.sin(orbitAngle);

    Offset project3D(double x, double y, double z) {
      final rx = x * cosA - z * sinA;
      final rz = x * sinA + z * cosA;
      return Offset(
        cx + rx * 68.0,
        cy - (y - 1.0) * 65.0 + (rz - 1.2) * 32.0,
      );
    }

    // 1. Isometric 3D Floor Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.16)
      ..strokeWidth = 1.0;

    for (int i = -3; i <= 3; i++) {
      final p1 = project3D(i * 0.8, 0, 0.2);
      final p2 = project3D(i * 0.8, 0, 3.4);
      canvas.drawLine(p1, p2, gridPaint);

      final p3 = project3D(-2.4, 0, (i + 3) * 0.55);
      final p4 = project3D(2.4, 0, (i + 3) * 0.55);
      canvas.drawLine(p3, p4, gridPaint);
    }

    // Doorway Origin Marker (0,0,0)
    final doorPt = project3D(0, 0, 0.3);
    final doorPaint = Paint()
      ..color = SupplyClosetColors.tealLight.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(doorPt, 14, doorPaint);
    _drawLabel(
      canvas,
      '🚪 DOORWAY (0,0,0)',
      doorPt + const Offset(0, 18),
      SupplyClosetColors.tealLight,
    );

    // 2. Photorealistic 3D Gaussian Splat Cloud Layer along the 3 Shelf Racks
    if (showGaussianSplat) {
      final splatWalls = [
        (-1.25, 1.8, SupplyClosetColors.tealLight),
        (0.0, 2.75, const Color(0xFF38BDF8)),
        (1.30, 1.85, const Color(0xFFA78BFA)),
      ];
      for (final (wx, wz, color) in splatWalls) {
        for (int i = 0; i < 85; i++) {
          final ox = wx + math.sin(i * 19.3) * 0.48;
          final oy = 0.45 + ((i % 12) / 12.0) * 1.35;
          final oz = wz + math.cos(i * 31.7) * 0.42;
          final pt = project3D(ox, oy, oz);
          final paint = Paint()
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: 0.42),
                color.withValues(alpha: 0.0),
              ],
            ).createShader(Rect.fromCircle(center: pt, radius: 9));
          canvas.drawCircle(pt, 9, paint);
        }
      }
    }

    // 3. Draw 3D Shelf Racks & Tagged Supply Bin Volumes
    final shelves = room.shelves.isNotEmpty
        ? room.shelves
        : SupplyRoom.defaultInitiatedShelves();

    if (showBinBoxes) {
      for (final shelf in shelves) {
        final centerLoc = shelf.locationForBin(3);
        final pt = project3D(centerLoc.x, 1.1, centerLoc.z);
        final rackRect =
            Rect.fromCenter(center: pt, width: 88, height: 110);
        final rackPaint = Paint()
          ..color = const Color(0xFF1E293B).withValues(alpha: 0.55)
          ..style = PaintingStyle.fill;
        final rackBorder = Paint()
          ..color = Colors.white24
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rackRect, const Radius.circular(8)),
          rackPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rackRect, const Radius.circular(8)),
          rackBorder,
        );
        _drawLabel(
          canvas,
          'SHELF ${shelf.id}',
          Offset(rackRect.center.dx, rackRect.top - 10),
          Colors.white70,
        );
      }
    }

    // 4. Draw Supply Items & Active Target Fly-To Highlight
    for (final s in supplies) {
      final loc = (s.location.x == 0 && s.location.z == 0)
          ? room.resolveLocation(shelf: s.location.shelf, bin: s.location.bin)
          : s.location;
      final pt = project3D(loc.x, loc.y, loc.z);
      final isSelected = activeSupply?.id == s.id;
      final isFound = foundIds.contains(s.id);

      if (showBinBoxes) {
        final boxRect = Rect.fromCenter(
          center: pt,
          width: isSelected ? 54 : 40,
          height: isSelected ? 34 : 26,
        );
        final fill = Paint()
          ..color = isSelected
              ? SupplyClosetColors.successDark.withValues(alpha: 0.55)
              : (isFound
                  ? SupplyClosetColors.teal.withValues(alpha: 0.4)
                  : const Color(0xFF0F172A).withValues(alpha: 0.85));
        final stroke = Paint()
          ..color = isSelected
              ? SupplyClosetColors.success
              : const Color(0xFF38BDF8)
          ..strokeWidth = isSelected ? 2.5 : 1.5
          ..style = PaintingStyle.stroke;

        canvas.drawRRect(
          RRect.fromRectAndRadius(boxRect, const Radius.circular(6)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(boxRect, const Radius.circular(6)),
          stroke,
        );
      }

      if (isSelected) {
        // Golden Target Lock Ring + Line from Doorway
        final pathPaint = Paint()
          ..color = SupplyClosetColors.warning.withValues(alpha: 0.65)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(doorPt, pt, pathPaint);
        canvas.drawCircle(pt, 28, pathPaint);

        // Callout Badge above target bin
        _drawCalloutCard(
          canvas,
          center: pt + const Offset(0, -44),
          topText: '🎯 ${s.location.displayLabel.toUpperCase()}',
          bottomText: s.name,
        );
      }
    }

    // 5. Draw Spatial Room Captain Hints (with Captain's Display Name & Avatar)
    for (final hint in room.hints) {
      final hPt = project3D(hint.x, hint.y, hint.z);
      final avatarEmoji = AvatarPresets.emojiFor(hint.captainAvatar);

      // Glowing golden pin at the 3D point in the room
      canvas.drawCircle(
        hPt,
        10,
        Paint()..color = SupplyClosetColors.warning.withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        hPt,
        5,
        Paint()..color = SupplyClosetColors.warning,
      );

      _drawCaptainHintCard(
        canvas,
        center: hPt + const Offset(0, 34),
        captainLine:
            '👑 $avatarEmoji ${hint.captainName} · Shelf ${hint.shelfId}',
        hintText: '"${hint.text}"',
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawCalloutCard(
    Canvas canvas, {
    required Offset center,
    required String topText,
    required String bottomText,
  }) {
    final rect = Rect.fromCenter(center: center, width: 168, height: 42);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xF2020617),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = SupplyClosetColors.success
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke,
    );
    _drawLabel(
      canvas,
      topText,
      center + const Offset(0, -8),
      SupplyClosetColors.success,
    );
    _drawLabel(
      canvas,
      bottomText.length > 22 ? '${bottomText.substring(0, 20)}…' : bottomText,
      center + const Offset(0, 8),
      Colors.white,
    );
  }

  void _drawCaptainHintCard(
    Canvas canvas, {
    required Offset center,
    required String captainLine,
    required String hintText,
  }) {
    final rect = Rect.fromCenter(center: center, width: 186, height: 40);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xF20F172A),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = SupplyClosetColors.warning
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
    _drawLabel(
      canvas,
      captainLine.length > 26
          ? '${captainLine.substring(0, 24)}…'
          : captainLine,
      center + const Offset(0, -8),
      SupplyClosetColors.warning,
    );
    _drawLabel(
      canvas,
      hintText.length > 28 ? '${hintText.substring(0, 26)}…"' : hintText,
      center + const Offset(0, 8),
      Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _GodsEyeSplatPainter oldDelegate) => true;
}

// ─── PAINTER 2: FIRST-PERSON GAMING AR HUD ───────────────────────

class _GamingArHudPainter extends CustomPainter {
  final SupplyRoom room;
  final SupplyItem? activeSupply;
  final double cameraYawDeg;
  final double cameraPitchDeg;
  final double targetYawDeg;
  final bool liveCameraActive;
  final List<AnchoredFeaturePoint> stickyPoints;
  final bool isFound;

  _GamingArHudPainter({
    required this.room,
    required this.activeSupply,
    required this.cameraYawDeg,
    required this.cameraPitchDeg,
    required this.targetYawDeg,
    required this.liveCameraActive,
    required this.stickyPoints,
    required this.isFound,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shiftX = -cameraYawDeg * 4.5;

    // 0. Draw Sticky 3D Room Feature Points & Mesh Triangulation (from live scan)
    final lockedScreenPts = <Offset>[];
    for (final pt in stickyPoints) {
      final relYaw = pt.worldYawDeg - cameraYawDeg;
      final relPitch = pt.worldPitchDeg - cameraPitchDeg;
      if (relYaw.abs() > 38.0 || relPitch.abs() > 45.0) continue;
      final sx = size.width * 0.5 +
          (relYaw / SpatialRoomScannerEngine.horizontalFovDeg) * size.width;
      final sy = size.height * 0.48 -
          (relPitch / SpatialRoomScannerEngine.verticalFovDeg) * size.height;
      if (sx < 0 || sx > size.width || sy < 80 || sy > size.height - 100) {
        continue;
      }
      final offset = Offset(sx, sy);
      final color = pt.isLocked
          ? (pt.id.isEven ? const Color(0xFF10B981) : const Color(0xFF00F5D4))
          : const Color(0xFFFACC15);
      if (pt.isLocked) lockedScreenPts.add(offset);

      canvas.drawCircle(
        offset,
        7.5,
        Paint()..color = color.withValues(alpha: 0.22),
      );
      canvas.drawCircle(
        offset,
        3.5,
        Paint()..color = color,
      );
    }

    final meshPaint = Paint()
      ..color = const Color(0xFF00F5D4).withValues(alpha: 0.25)
      ..strokeWidth = 0.85;
    for (int i = 0; i < lockedScreenPts.length; i++) {
      int count = 0;
      for (int j = i + 1; j < lockedScreenPts.length; j++) {
        final d = (lockedScreenPts[i] - lockedScreenPts[j]).distance;
        if (d > 18 && d < 82) {
          canvas.drawLine(lockedScreenPts[i], lockedScreenPts[j], meshPaint);
          if (++count >= 2) break;
        }
      }
    }

    // If live camera isn't active, draw 3D Shelf Racks in first-person perspective
    if (!liveCameraActive) {
      final racks = [
        ('SHELF A (LEFT)', -32.0, SupplyClosetColors.tealLight),
        ('SHELF B (CENTER)', 0.0, const Color(0xFF38BDF8)),
        ('SHELF C (RIGHT)', 34.0, const Color(0xFFA78BFA)),
      ];
      for (final (label, yaw, color) in racks) {
        final rx = (size.width / 2) + (yaw * 4.5) + shiftX;
        final rect = Rect.fromCenter(
          center: Offset(rx, size.height * 0.43),
          width: 120,
          height: 230,
        );
        final fill = Paint()
          ..color = const Color(0xFF1E293B).withValues(alpha: 0.65);
        final border = Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke;

        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(10)), fill);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(10)), border);

        for (int r = 1; r < 4; r++) {
          final ry = rect.top + (rect.height / 4) * r;
          canvas.drawLine(
              Offset(rect.left, ry), Offset(rect.right, ry), border);
        }
        canvas.drawLine(
          Offset(rect.center.dx, rect.top),
          Offset(rect.center.dx, rect.bottom),
          border,
        );

        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.top - 16));
      }
    }

    // Draw Spatial Captain Hints in First-Person AR View
    for (int i = 0; i < room.hints.length; i++) {
      final hint = room.hints[i];
      final hx = (size.width / 2) + (hint.yawDegrees - cameraYawDeg) * 4.5;
      if (hx > 30 && hx < size.width - 30) {
        final hy = size.height * 0.22 + ((i % 2) * 46.0);
        final avatarEmoji = AvatarPresets.emojiFor(hint.captainAvatar);
        final hRect =
            Rect.fromCenter(center: Offset(hx, hy), width: 188, height: 40);
        canvas.drawRRect(
          RRect.fromRectAndRadius(hRect, const Radius.circular(10)),
          Paint()..color = const Color(0xEB0F172A),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(hRect, const Radius.circular(10)),
          Paint()
            ..color = SupplyClosetColors.warning
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
        final hTp1 = TextPainter(
          text: TextSpan(
            text:
                '👑 $avatarEmoji ${hint.captainName} (Shelf ${hint.shelfId})',
            style: const TextStyle(
              color: SupplyClosetColors.warning,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        hTp1.paint(
            canvas, hRect.center - Offset(hTp1.width / 2, hTp1.height));

        final shortHint = hint.text.length > 26
            ? '"${hint.text.substring(0, 24)}…"'
            : '"${hint.text}"';
        final hTp2 = TextPainter(
          text: TextSpan(
            text: shortHint,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        hTp2.paint(canvas, hRect.center + Offset(-hTp2.width / 2, 2));
      }
    }

    if (activeSupply == null) return;

    // Compute Target Bin Screen Position
    final targetX = (size.width / 2) + (targetYawDeg - cameraYawDeg) * 4.5;
    final bin = activeSupply!.location.bin ?? 1;
    final rowIdx = ((bin - 1) ~/ 2).clamp(0, 3);
    final targetY = size.height * 0.30 + (rowIdx * 48.0);

    // 1. Draw 3D Floor Navigation Path (Glowing Corridor + Chevrons » » »)
    final floorStartX = size.width / 2;
    final floorStartY = size.height * 0.72;
    final floorEndX = targetX.clamp(40.0, size.width - 40.0);
    final floorEndY = size.height * 0.58;

    final corridorPaint = Paint()
      ..color = SupplyClosetColors.tealLight.withValues(alpha: 0.45)
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(floorStartX - 48, floorStartY),
      Offset(floorEndX - 20, floorEndY),
      corridorPaint,
    );
    canvas.drawLine(
      Offset(floorStartX + 48, floorStartY),
      Offset(floorEndX + 20, floorEndY),
      corridorPaint,
    );

    // Draw 4 Floor Chevrons
    for (int step = 1; step <= 4; step++) {
      final frac = step / 5.0;
      final cx = floorStartX + (floorEndX - floorStartX) * frac;
      final cy = floorStartY + (floorEndY - floorStartY) * frac;
      final span = 30.0 * (1.0 - frac * 0.45);
      final chevPaint = Paint()
        ..color = step.isEven
            ? SupplyClosetColors.tealLight
            : SupplyClosetColors.success
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(cx - span, cy + 10)
        ..lineTo(cx, cy)
        ..lineTo(cx + span, cy + 10);
      canvas.drawPath(path, chevPaint);
    }

    // 2. Draw 3D Wireframe Bin Cube, [AR] Corner Reticle & (x, y, z) Badge when within FOV
    if (targetX > 20 && targetX < size.width - 20) {
      final loc = (activeSupply!.location.x == 0 && activeSupply!.location.z == 0)
          ? room.resolveLocation(
              shelf: activeSupply!.location.shelf,
              bin: activeSupply!.location.bin,
            )
          : activeSupply!.location;

      final frontRect = Rect.fromCenter(
        center: Offset(targetX, targetY),
        width: 88,
        height: 58,
      );
      final backRect = frontRect.shift(const Offset(10, -10));
      final cubeColor = isFound
          ? SupplyClosetColors.success
          : const Color(0xFFFACC15);

      // 3D Cube Fill & Wireframe Edges
      canvas.drawRect(
        frontRect,
        Paint()..color = cubeColor.withValues(alpha: 0.16),
      );
      final wirePaint = Paint()
        ..color = cubeColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawRect(
        backRect,
        Paint()
          ..color = cubeColor.withValues(alpha: 0.5)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
      canvas.drawRect(frontRect, wirePaint);
      canvas.drawLine(frontRect.topLeft, backRect.topLeft, wirePaint);
      canvas.drawLine(frontRect.topRight, backRect.topRight, wirePaint);
      canvas.drawLine(frontRect.bottomLeft, backRect.bottomLeft, wirePaint);
      canvas.drawLine(frontRect.bottomRight, backRect.bottomRight, wirePaint);

      // [AR] Corner Reticle inside 3D Bin Box
      const half = 15.0;
      const corner = 6.0;
      final c = frontRect.center;
      canvas.drawLine(c + const Offset(-half, -half),
          c + const Offset(-half + corner, -half), wirePaint);
      canvas.drawLine(c + const Offset(-half, -half),
          c + const Offset(-half, -half + corner), wirePaint);
      canvas.drawLine(c + const Offset(half, -half),
          c + const Offset(half - corner, -half), wirePaint);
      canvas.drawLine(c + const Offset(half, -half),
          c + const Offset(half, -half + corner), wirePaint);
      canvas.drawLine(c + const Offset(-half, half),
          c + const Offset(-half + corner, half), wirePaint);
      canvas.drawLine(c + const Offset(-half, half),
          c + const Offset(-half, half - corner), wirePaint);
      canvas.drawLine(c + const Offset(half, half),
          c + const Offset(half - corner, half), wirePaint);
      canvas.drawLine(c + const Offset(half, half),
          c + const Offset(half, half - corner), wirePaint);

      final arTp = TextPainter(
        text: TextSpan(
          text: isFound ? '✓' : 'AR',
          style: TextStyle(
            color: cubeColor,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      arTp.paint(canvas, c - Offset(arTp.width / 2, arTp.height / 2));

      // 3D Coordinates Badge (x, y, z) on right of Bin Cube
      final coordRect = Rect.fromLTWH(
        (frontRect.right + 8).clamp(8.0, size.width - 78.0),
        frontRect.center.dy - 26,
        72,
        52,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(coordRect, const Radius.circular(8)),
        Paint()..color = const Color(0xD9090D16),
      );
      final coordTp = TextPainter(
        text: TextSpan(
          text: 'x: ${loc.x}m\ny: ${loc.y}m\nz: ${loc.z}m',
          style: TextStyle(
            color: cubeColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      coordTp.paint(canvas, Offset(coordRect.left + 7, coordRect.top + 5));

      // Floating Callout Tag above 3D Bin Cube
      final calloutRect = Rect.fromCenter(
        center: Offset(targetX.clamp(92.0, size.width - 92.0), backRect.top - 28),
        width: 182,
        height: 44,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(calloutRect, const Radius.circular(10)),
        Paint()..color = const Color(0xF2020617),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(calloutRect, const Radius.circular(10)),
        Paint()
          ..color = cubeColor
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke,
      );

      final tp1 = TextPainter(
        text: TextSpan(
          text: '🎯 ${activeSupply!.location.displayLabel.toUpperCase()} (TAP OR REACH)',
          style: TextStyle(
            color: cubeColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp1.paint(
        canvas,
        calloutRect.center - Offset(tp1.width / 2, tp1.height + 1),
      );

      final nameStr = activeSupply!.name.length > 22
          ? '${activeSupply!.name.substring(0, 20)}…'
          : activeSupply!.name;
      final tp2 = TextPainter(
        text: TextSpan(
          text: nameStr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp2.paint(
        canvas,
        calloutRect.center + Offset(-tp2.width / 2, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GamingArHudPainter oldDelegate) => true;
}

// ─── PAINTER 3: TOP-RIGHT MINI-MAP RADAR ─────────────────────────

class _MiniRadarPainter extends CustomPainter {
  final double cameraYawDeg;
  final double targetYawDeg;
  final bool hasTarget;

  _MiniRadarPainter({
    required this.cameraYawDeg,
    required this.targetYawDeg,
    required this.hasTarget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final gridPaint = Paint()
      ..color = SupplyClosetColors.tealLight.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)), gridPaint);

    final origin = Offset(size.width / 2, size.height - 6);
    final radYaw = (cameraYawDeg - 90) * (math.pi / 180.0);

    // Viewing cone
    final conePaint = Paint()
      ..color = SupplyClosetColors.tealLight.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    final conePath = Path()
      ..moveTo(origin.dx, origin.dy)
      ..arcTo(
        Rect.fromCircle(center: origin, radius: size.height * 0.78),
        radYaw - 0.45,
        0.90,
        false,
      )
      ..close();
    canvas.drawPath(conePath, conePaint);

    // Doorway player dot
    canvas.drawCircle(origin, 3.0, Paint()..color = Colors.white);

    // Target dot
    if (hasTarget) {
      final tx = (size.width / 2) + (targetYawDeg * 0.42);
      const ty = 12.0;
      canvas.drawCircle(
        Offset(tx.clamp(8.0, size.width - 8.0), ty),
        4.5,
        Paint()..color = SupplyClosetColors.success,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniRadarPainter oldDelegate) => true;
}
