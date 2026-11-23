import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:camera/camera.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/supply_room.dart';
import '../../models/supply_bounty.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/gamification_service.dart';
import '../../widgets/room_switcher_sheet.dart';
import '../../widgets/user_avatar.dart';
import '../room/room_initiation_screen.dart';
import '../bounty/bounty_board_sheet.dart';

/// Three-step tagging flow: identify (quick search / 1-tap or barcode) → locate
/// (visual 3D shelf & bin grid + text) → confirm (preview + tag + bounty claim).
class TagSupplyScreen extends StatefulWidget {
  final String? initialSupplyName;
  final String? initialBountyId;

  const TagSupplyScreen({
    super.key,
    this.initialSupplyName,
    this.initialBountyId,
  });

  @override
  State<TagSupplyScreen> createState() => _TagSupplyScreenState();
}

class _TagSupplyScreenState extends State<TagSupplyScreen> {
  final _firestore = FirestoreService();
  int _step = 0;

  // Step 1 state
  String? _supplyName;
  String? _supplyCategory;
  String? _barcode;
  String? _supplySize;
  String? _activeBountyId;

  // Step 2 state
  final _shelfController = TextEditingController(text: 'A');
  final _binController = TextEditingController(text: '1');

  bool _isSubmitting = false;
  final bool _isFirstTagOnUnit = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSupplyName != null &&
        widget.initialSupplyName!.trim().isNotEmpty) {
      _supplyName = widget.initialSupplyName!.trim();
      _activeBountyId = widget.initialBountyId;
      _step = 1; // Jump straight to Step 2 (Locate on Shelf)
    }
  }

  @override
  void dispose() {
    _shelfController.dispose();
    _binController.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 2));
  void _back() => setState(() => _step = (_step - 1).clamp(0, 2));

  void _startBountyHunt(SupplyBounty bounty) {
    setState(() {
      _supplyName = bounty.supplyName;
      _supplyCategory = bounty.category;
      _activeBountyId = bounty.id;
      _step = 1;
    });
  }

  Future<void> _submit(SupplyRoom room) async {
    final auth = context.read<AuthProvider>();
    final game = context.read<GamificationProvider>();
    final roomProv = context.read<RoomProvider>();
    final profile = auth.profile;
    if (profile == null ||
        profile.facilityId == null ||
        profile.unitId == null) {
      _showError('Set your facility and unit in your profile first.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final roomId = roomProv.selectedRoomId;

      final shelf = _shelfController.text.trim().toUpperCase();
      final binStr = _binController.text.trim();
      final bin = int.tryParse(binStr) ?? 1;

      // Resolve true 3D room coordinates from the room's shelf geometry
      final resolvedLocation = room.resolveLocation(
        shelf: shelf.isEmpty ? 'A' : shelf,
        bin: bin,
      );

      final tagResult = await _firestore.tagSupply(
        facilityId: profile.facilityId!,
        unitId: profile.unitId!,
        roomId: roomId,
        supplyName: _supplyName ?? 'Untitled',
        barcode: _barcode,
        category: _supplyCategory,
        location: resolvedLocation,
        userId: profile.uid,
        userName: profile.displayName,
        userAvatar: profile.photoUrl,
        bountyId: _activeBountyId,
      );

      // Award XP for the tag (non-blocking if offline)
      try {
        await game.recordAction(
          profile: profile,
          action: tagResult.createdNew
              ? GameAction.tagNew
              : GameAction.confirmExisting,
          isFirstTagOnUnit: _isFirstTagOnUnit,
          isNightShift: _isNightShift(),
          facilityId: profile.facilityId,
          unitId: profile.unitId,
          roomId: roomId,
          supplyId: tagResult.supplyId,
        );

        // If this user became the new Room Captain (most tags in this room), award +150 XP Trophy!
        if (tagResult.becameRoomCaptain) {
          await game.recordAction(
            profile: profile,
            action: GameAction.becomeRoomCaptain,
            isNightShift: _isNightShift(),
            facilityId: profile.facilityId,
            unitId: profile.unitId,
            roomId: roomId,
            supplyId: tagResult.supplyId,
          );
        }

        // If this tag fulfilled a Supply Bounty, award the extra Bounty Hunter XP!
        if (tagResult.claimedBountyId != null) {
          await game.recordAction(
            profile: profile,
            action: GameAction.claimBounty,
            isNightShift: _isNightShift(),
            facilityId: profile.facilityId,
            unitId: profile.unitId,
            roomId: roomId,
            supplyId: tagResult.supplyId,
            bountyId: tagResult.claimedBountyId,
          );
        }
      } catch (_) {
        // Continue cleanly even if Cloud Function XP call fails
      }

      // Log analytics event
      FirebaseAnalytics.instance.logEvent(
        name: 'supply_tagged',
        parameters: {
          'supply_name': _supplyName ?? 'unknown',
          'has_barcode': _barcode != null,
          'is_first_tag': _isFirstTagOnUnit,
          'tag_action': tagResult.createdNew ? 'created' : 'confirmed',
          'claimed_bounty': tagResult.claimedBounty,
          'became_room_captain': tagResult.becameRoomCaptain,
        },
      );

      if (mounted) {
        final taggedName = _supplyName ?? 'supply';
        final bountyMsg = tagResult.claimedBounty
            ? ' 🎯 BOUNTY CLAIMED (+${AppConstants.pointsClaimBounty} Bonus XP)!'
            : '';
        final captainMsg = tagResult.becameRoomCaptain
            ? ' 👑 NEW ROOM CAPTAIN (+${AppConstants.pointsRoomCaptain} XP Trophy)!'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tagged $taggedName at ${resolvedLocation.displayLabel} in ${room.name}!$bountyMsg$captainMsg',
            ),
            backgroundColor: SupplyClosetColors.successDark,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _step = 0;
            _supplyName = null;
            _supplyCategory = null;
            _supplySize = null;
            _barcode = null;
            _activeBountyId = null;
          });
        }
      }
    } catch (e) {
      _showError('Failed to tag: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _isNightShift() {
    final hour = DateTime.now().hour;
    return hour >= 19 || hour < 7;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: SupplyClosetColors.coral,
      ),
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

    return StreamBuilder<SupplyRoom>(
      stream: _firestore.roomStream(facilityId, unitId, roomId),
      builder: (context, roomSnap) {
        final room = roomSnap.data ?? SupplyRoom.uninitiated(roomId);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tag a Supply'),
            leading: _step == 0
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _back,
                  ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: () => BountyBoardSheet.show(
                    context,
                    facilityId: facilityId,
                    unitId: unitId,
                    roomId: roomId,
                    room: room,
                    onHuntBounty: _startBountyHunt,
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor:
                        SupplyClosetColors.warning.withValues(alpha: 0.18),
                    foregroundColor: SupplyClosetColors.charcoal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: SupplyClosetColors.warning),
                    ),
                  ),
                  icon: const Icon(Icons.gps_fixed_rounded,
                      size: 18, color: SupplyClosetColors.warningDark),
                  label: const Text(
                    'Bounties',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Multi-Room Floor Selector + Add Room + Room Captain Bar
              _TagRoomHeaderBar(
                facilityId: facilityId,
                unitId: unitId,
                unitName: unitName,
                room: room,
              ),

              // Room Initiation Prompt Banner if Room is Not Initiated Yet
              if (!room.isInitiated)
                _UninitiatedRoomBanner(
                  onInitiate: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoomInitiationScreen(
                          roomId: roomId,
                          roomName: room.name,
                        ),
                      ),
                    );
                  },
                ),

              // Active Bounty Hunt Banner
              if (_activeBountyId != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: SupplyClosetColors.warning.withValues(alpha: 0.25),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded,
                          color: SupplyClosetColors.warningDark, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🎯 BOUNTY HUNT: Tag "${_supplyName ?? ""}" for +${AppConstants.pointsClaimBounty} Bonus XP!',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: SupplyClosetColors.charcoal,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            setState(() => _activeBountyId = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

              _StepIndicator(currentStep: _step),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildCurrentStep(room),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentStep(SupplyRoom room) {
    switch (_step) {
      case 0:
        return _IdentifyStep(
          key: const ValueKey('identify'),
          onIdentified: (name, category, size, barcode) {
            setState(() {
              _supplyName = name;
              _supplyCategory = category;
              _supplySize = size;
              _barcode = barcode;
            });
            _next();
          },
        );
      case 1:
        return _LocateStep(
          key: const ValueKey('locate'),
          room: room,
          supplyName: _supplyName ?? '',
          shelfController: _shelfController,
          binController: _binController,
          onContinue: _next,
        );
      case 2:
      default:
        return _ConfirmStep(
          key: const ValueKey('confirm'),
          room: room,
          name: _supplyName ?? '',
          size: _supplySize,
          category: _supplyCategory,
          barcode: _barcode,
          shelf: _shelfController.text,
          bin: _binController.text,
          hasBountyBonus: _activeBountyId != null,
          isSubmitting: _isSubmitting,
          onSubmit: () => _submit(room),
        );
    }
  }
}

class _TagRoomHeaderBar extends StatelessWidget {
  final String facilityId;
  final String unitId;
  final String unitName;
  final SupplyRoom room;

  const _TagRoomHeaderBar({
    required this.facilityId,
    required this.unitId,
    required this.unitName,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SupplyClosetColors.tealLight.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          // Active Room Switcher Button
          Expanded(
            child: InkWell(
              onTap: () => RoomSwitcherSheet.show(
                context,
                facilityId: facilityId,
                unitId: unitId,
                unitName: unitName,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.meeting_room_rounded,
                    color: SupplyClosetColors.tealLight,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$unitName · ${room.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          room.hasCaptain
                              ? '👑 Captain: ${room.captainName} (${room.captainTagCount} tags)'
                              : 'Tag supplies here to become Room Captain (+150 XP)!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: room.hasCaptain
                                ? SupplyClosetColors.warning
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: SupplyClosetColors.tealLight,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // + Add Room Quick Button
          InkWell(
            onTap: () => RoomSwitcherSheet.show(
              context,
              facilityId: facilityId,
              unitId: unitId,
              unitName: unitName,
              openAddRoomInitially: true,
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: SupplyClosetColors.teal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 2),
                  Text(
                    'Add Room',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Captain Hint Quick Button
          InkWell(
            onTap: () => CaptainHintSheet.show(
              context,
              facilityId: facilityId,
              unitId: unitId,
              room: room,
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: SupplyClosetColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SupplyClosetColors.warning),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (room.hasCaptain) ...[
                    UserAvatar(
                      displayName: room.captainName ?? 'C',
                      photoUrl: room.captainAvatar,
                      radius: 10,
                    ),
                    const SizedBox(width: 4),
                  ] else
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: SupplyClosetColors.warning,
                      size: 16,
                    ),
                  const Text(
                    'Hint',
                    style: TextStyle(
                      color: SupplyClosetColors.warning,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UninitiatedRoomBanner extends StatelessWidget {
  final VoidCallback onInitiate;
  const _UninitiatedRoomBanner({required this.onInitiate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SupplyClosetColors.warning, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.radar_rounded,
              color: SupplyClosetColors.warning, size: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room Not Initiated Yet (+250 XP)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Scan the room & pin shelves first so tags have 3D Gaussian Splat coordinates!',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onInitiate,
            style: ElevatedButton.styleFrom(
              backgroundColor: SupplyClosetColors.warning,
              foregroundColor: const Color(0xFF020617),
              minimumSize: const Size(88, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text(
              'Scan Room',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step indicator ────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = ['Identify', 'Locate on 3D Shelf', 'Confirm'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == currentStep;
          final isDone = i < currentStep;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive || isDone
                          ? SupplyClosetColors.teal
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive
                          ? SupplyClosetColors.teal
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Step 1: Identify ──────────────────────────────────────────────

class _IdentifyStep extends StatefulWidget {
  final void Function(
          String name, String? category, String? size, String? barcode)
      onIdentified;

  const _IdentifyStep({super.key, required this.onIdentified});

  @override
  State<_IdentifyStep> createState() => _IdentifyStepState();
}

class _IdentifyStepState extends State<_IdentifyStep> {
  static const List<Map<String, String>> _quickSupplies = [
    {'name': '18G IV Catheter', 'category': 'IV Access', 'size': '18G'},
    {'name': '20G IV Catheter', 'category': 'IV Access', 'size': '20G'},
    {'name': '22G IV Catheter', 'category': 'IV Access', 'size': '22G'},
    {'name': 'IV Start Kit', 'category': 'IV Access'},
    {
      'name': '0.9% Normal Saline Flush 10mL',
      'category': 'IV Access',
      'size': '10mL'
    },
    {'name': 'Foley Catheter Kit 16 Fr', 'category': 'Urinary', 'size': '16 Fr'},
    {'name': '4x4 Sterile Gauze Pads', 'category': 'Wound Care', 'size': '4x4'},
    {'name': 'Tegaderm Transparent Dressing', 'category': 'Wound Care'},
    {'name': 'Chlorhexidine Prep Swab', 'category': 'Antiseptic'},
    {'name': 'Blood Culture Bottles (Set)', 'category': 'Lab / Phlebotomy'},
  ];

  CameraController? _camera;
  BarcodeScanner? _scanner;
  bool _isScanning = false;
  bool _showManual = true;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _query = _searchController.text.trim());
      }
    });
  }

  Future<void> _openCameraScanner() async {
    setState(() => _showManual = false);
    if (_camera != null && _camera!.value.isInitialized) return;
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _showManual = true);
        return;
      }
      _camera = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _camera!.initialize();
      _scanner = BarcodeScanner();
      _startScanning();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _showManual = true);
    }
  }

  void _startScanning() {
    if (_camera == null || !_camera!.value.isInitialized) return;
    _camera!.startImageStream((image) async {
      if (_isScanning) return;
      _isScanning = true;
      _isScanning = false;
    });
  }

  @override
  void dispose() {
    _camera?.dispose();
    _scanner?.close();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showManual) {
      return _buildManualSearch();
    }
    if (_camera == null || !_camera!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(_camera!)),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: SupplyClosetColors.teal, width: 4),
          ),
          margin: const EdgeInsets.all(40),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Point at a barcode',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _showManual = true),
            icon: const Icon(Icons.search),
            label: const Text('Search catalog instead'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualSearch() {
    final filtered = _query.isEmpty
        ? _quickSupplies
        : _quickSupplies
            .where((item) =>
                item['name']!.toLowerCase().contains(_query.toLowerCase()) ||
                (item['category']
                        ?.toLowerCase()
                        .contains(_query.toLowerCase()) ??
                    false))
            .toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search or type supply name',
              hintText: 'e.g. 18G IV, Foley 16 Fr, Saline Flush',
              prefixIcon: Icon(Icons.search),
            ),
            autofocus: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                widget.onIdentified(v.trim(), null, null, null);
              }
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Quick-Tap Common Supplies',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return OutlinedButton(
                  onPressed: () => widget.onIdentified(
                    item['name']!,
                    item['category'],
                    item['size'],
                    null,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.medical_services_outlined, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item['name']!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (item['category'] != null)
                        Text(
                          item['category']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              final v = _searchController.text.trim();
              if (v.isNotEmpty) {
                widget.onIdentified(v, null, null, null);
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            child: const Text('Continue with Typed Name'),
          ),
          const SizedBox(height: 2),
          Center(
            child: TextButton.icon(
              onPressed: _openCameraScanner,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Use camera scanner (optional)'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Locate on Visual 3D Shelf & Bin Grid ─────────────────

class _LocateStep extends StatefulWidget {
  final SupplyRoom room;
  final String supplyName;
  final TextEditingController shelfController;
  final TextEditingController binController;
  final VoidCallback onContinue;

  const _LocateStep({
    super.key,
    required this.room,
    required this.supplyName,
    required this.shelfController,
    required this.binController,
    required this.onContinue,
  });

  @override
  State<_LocateStep> createState() => _LocateStepState();
}

class _LocateStepState extends State<_LocateStep> {
  String get _selectedShelf =>
      widget.shelfController.text.trim().isEmpty
          ? 'A'
          : widget.shelfController.text.trim().toUpperCase();

  int get _selectedBin =>
      int.tryParse(widget.binController.text.trim()) ?? 1;

  void _selectShelf(String id) {
    setState(() {
      widget.shelfController.text = id;
    });
  }

  void _selectBin(int binNum) {
    setState(() {
      widget.binController.text = binNum.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shelves = widget.room.shelves.isNotEmpty
        ? widget.room.shelves
        : SupplyRoom.defaultInitiatedShelves();
    final activeRack = widget.room.findShelf(_selectedShelf) ??
        ShelfRack.defaultForCode(_selectedShelf);
    final resolved3D = activeRack.locationForBin(_selectedBin);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tap Shelf & Bin for "${widget.supplyName}"',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: SupplyClosetColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a Shelf Wall below, then tap the Bin slot on the 3D rack.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // 1. Visual Shelf Wall Selector Pills
          Row(
            children: [
              for (final s in shelves)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => _selectShelf(s.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedShelf == s.id
                              ? SupplyClosetColors.teal
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedShelf == s.id
                                ? SupplyClosetColors.teal
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'SHELF ${s.id}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: _selectedShelf == s.id
                                    ? Colors.white
                                    : SupplyClosetColors.charcoal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.id == 'A'
                                  ? 'Left Wall'
                                  : (s.id == 'B' ? 'Center' : 'Right Wall'),
                              style: TextStyle(
                                fontSize: 11,
                                color: _selectedShelf == s.id
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Interactive 8-Bin Visual Shelf Rack Grid
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SupplyClosetColors.tealLight, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📦 ${activeRack.label.toUpperCase()}',
                      style: const TextStyle(
                        color: SupplyClosetColors.success,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '3D: (${resolved3D.x}m, ${resolved3D.y}m, ${resolved3D.z}m)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: activeRack.totalBins,
                  itemBuilder: (context, idx) {
                    final binNum = idx + 1;
                    final isSelected = _selectedBin == binNum;
                    final rowDesc = activeRack
                        .elevationLabelForBin(binNum)
                        .split('·')
                        .first
                        .trim();
                    return InkWell(
                      onTap: () => _selectBin(binNum),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? SupplyClosetColors.successDark
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.white24,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'BIN $binNum',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: isSelected ? 15 : 13,
                              ),
                            ),
                            Text(
                              rowDesc,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Manual text override row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.shelfController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Shelf ID',
                    prefixIcon: Icon(Icons.shelves),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.binController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Bin #',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: widget.onContinue,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(
              'Continue (Shelf $_selectedShelf, Bin $_selectedBin)',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Confirm ───────────────────────────────────────────────

class _ConfirmStep extends StatelessWidget {
  final SupplyRoom room;
  final String name;
  final String? size;
  final String? category;
  final String? barcode;
  final String shelf;
  final String bin;
  final bool hasBountyBonus;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _ConfirmStep({
    super.key,
    required this.room,
    required this.name,
    this.size,
    this.category,
    this.barcode,
    required this.shelf,
    required this.bin,
    required this.hasBountyBonus,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = room.resolveLocation(
      shelf: shelf.isEmpty ? 'A' : shelf,
      bin: int.tryParse(bin) ?? 1,
    );
    final totalXp = AppConstants.pointsTagNew +
        (hasBountyBonus ? AppConstants.pointsClaimBounty : 0);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Confirm 3D Tag',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: SupplyClosetColors.tealLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medical_services,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            if (size != null)
                              Text(size!,
                                  style:
                                      TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _kv('Shelf & Bin', resolved.displayLabel),
                  _kv('3D Coordinates',
                      '(${resolved.x}m, ${resolved.y}m, ${resolved.z}m)'),
                  if (barcode != null) _kv('Barcode', barcode!),
                  if (category != null) _kv('Category', category!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hasBountyBonus
                  ? SupplyClosetColors.warning.withValues(alpha: 0.22)
                  : SupplyClosetColors.tealLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: hasBountyBonus
                  ? Border.all(color: SupplyClosetColors.warningDark)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  hasBountyBonus ? Icons.gps_fixed_rounded : Icons.bolt,
                  color: hasBountyBonus
                      ? SupplyClosetColors.warningDark
                      : SupplyClosetColors.teal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasBountyBonus
                        ? '🎯 +$totalXp XP (Includes +${AppConstants.pointsClaimBounty} Bounty Hunter Bonus!)'
                        : '+$totalXp XP for tagging into 3D room map',
                    style: TextStyle(
                      color: hasBountyBonus
                          ? SupplyClosetColors.charcoal
                          : SupplyClosetColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: isSubmitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    hasBountyBonus
                        ? 'Tag & Claim Bounty (+$totalXp XP)'
                        : 'Tag this supply',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(key,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
