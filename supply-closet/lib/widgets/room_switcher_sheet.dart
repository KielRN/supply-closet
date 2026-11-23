import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../models/supply_room.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../screens/room/room_initiation_screen.dart';
import '../services/firestore_service.dart';
import 'user_avatar.dart';

/// Bottom sheet for switching which Supply Room on the floor (e.g., Med 3A North
/// vs Med 3A South) the nurse is currently in, scanning a hospital door plaque,
/// or adding a new Supply Room to the floor.
class RoomSwitcherSheet extends StatefulWidget {
  final String facilityId;
  final String unitId;
  final String unitName;
  final bool openAddRoomInitially;
  final bool openDoorScannerInitially;

  const RoomSwitcherSheet({
    super.key,
    required this.facilityId,
    required this.unitId,
    required this.unitName,
    this.openAddRoomInitially = false,
    this.openDoorScannerInitially = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String facilityId,
    required String unitId,
    required String unitName,
    bool openAddRoomInitially = false,
    bool openDoorScannerInitially = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomSwitcherSheet(
        facilityId: facilityId,
        unitId: unitId,
        unitName: unitName,
        openAddRoomInitially: openAddRoomInitially,
        openDoorScannerInitially: openDoorScannerInitially,
      ),
    );
  }

  @override
  State<RoomSwitcherSheet> createState() => _RoomSwitcherSheetState();
}

class _RoomSwitcherSheetState extends State<RoomSwitcherSheet> {
  final _firestore = FirestoreService();
  final _roomNameCtrl = TextEditingController();
  final _doorCodeCtrl = TextEditingController();
  final _doorScanCtrl = TextEditingController();

  CameraController? _doorCamera;
  bool _doorCameraActive = false;

  late bool _showAddForm;
  late bool _showDoorScanner;
  bool _isCreating = false;

  static const List<Map<String, String>> _quickFloorRooms = [
    {
      'name': 'Med 3A · South Supply Rm',
      'door': 'RM 3A-204',
    },
    {
      'name': 'Med 3A · Clean Utility West',
      'door': 'RM 3A-118',
    },
    {
      'name': 'Med 3B · North Supply Rm',
      'door': 'RM 3B-102',
    },
  ];

  @override
  void initState() {
    super.initState();
    _showAddForm = widget.openAddRoomInitially;
    _showDoorScanner = widget.openDoorScannerInitially;
    if (_showDoorScanner) {
      _initDoorCamera();
    }
  }

  Future<void> _initDoorCamera() async {
    if (kIsWeb) return;
    if (_doorCamera != null && _doorCamera!.value.isInitialized) {
      if (mounted) setState(() => _doorCameraActive = true);
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        backCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _doorCamera = ctrl;
        _doorCameraActive = true;
      });
    } catch (_) {
      if (mounted) setState(() => _doorCameraActive = false);
    }
  }

  @override
  void dispose() {
    _doorCamera?.dispose();
    _roomNameCtrl.dispose();
    _doorCodeCtrl.dispose();
    _doorScanCtrl.dispose();
    super.dispose();
  }

  Future<void> _createNewRoom({String? presetName, String? presetDoor}) async {
    final name = (presetName ?? _roomNameCtrl.text).trim();
    final door = (presetDoor ?? _doorCodeCtrl.text).trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a supply room name (e.g., Med 3A South Supply).'),
          backgroundColor: SupplyClosetColors.coral,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final roomProv = context.read<RoomProvider>();
    final uid = auth.profile?.uid ?? 'anon';

    setState(() => _isCreating = true);
    try {
      final created = await roomProv.addAndSelectRoom(
        facilityId: widget.facilityId,
        unitId: widget.unitId,
        roomName: name,
        doorCode: door.isEmpty ? null : door,
        userId: uid,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Switched to "${created.name}"! Scan & initiate it for +${AppConstants.pointsInitiateRoom} XP.',
            ),
            backgroundColor: SupplyClosetColors.successDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add supply room: $e'),
            backgroundColor: SupplyClosetColors.coral,
          ),
        );
      }
    }
  }

  void _matchDoorSign(List<SupplyRoom> rooms, String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;

    final roomProv = context.read<RoomProvider>();
    for (final r in rooms) {
      final rDoor = (r.doorCode ?? '').toUpperCase();
      final rName = r.name.toUpperCase();
      if (rDoor == clean || rDoor.contains(clean) || rName.contains(clean)) {
        roomProv.selectRoom(r.id);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚪 Door Sign Matched → Switched to ${r.name}!'),
            backgroundColor: SupplyClosetColors.successDark,
          ),
        );
        return;
      }
    }

    // If not found yet, pre-fill the Add Room form with this door plaque!
    setState(() {
      _showDoorScanner = false;
      _showAddForm = true;
      _doorCodeCtrl.text = clean;
      _roomNameCtrl.text = '${widget.unitName} · Supply Room ($clean)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomProv = context.watch<RoomProvider>();
    final selectedRoomId = roomProv.selectedRoomId;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: 54, bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: SupplyClosetColors.tealLight, width: 2),
        ),
      ),
      child: StreamBuilder<List<SupplyRoom>>(
        stream: _firestore.roomsInUnit(widget.facilityId, widget.unitId),
        builder: (context, snapshot) {
          final rooms = snapshot.data ??
              [
                SupplyRoom.uninitiated(
                  AppConstants.defaultRoomId,
                  name: '${widget.unitName} · North Supply Rm',
                  doorCode: 'RM 3A-102',
                ),
              ];

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SupplyClosetColors.teal.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: SupplyClosetColors.tealLight),
                      ),
                      child: const Icon(
                        Icons.meeting_room_rounded,
                        color: SupplyClosetColors.tealLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supply Rooms on ${widget.unitName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'Switch active supply room, scan door sign, or add a closet',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Floor Wing Switcher Bar (Med 3A / Med 3B / ICU 4E)
                _buildFloorWingSelector(context),
                const SizedBox(height: 12),

                // Action Tabs: Scan Door Sign vs + Add New Room
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final next = !_showDoorScanner;
                          setState(() {
                            _showDoorScanner = next;
                            if (next) _showAddForm = false;
                          });
                          if (next) _initDoorCamera();
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _showDoorScanner
                              ? SupplyClosetColors.teal.withValues(alpha: 0.25)
                              : const Color(0xFF020617),
                          foregroundColor: SupplyClosetColors.tealLight,
                          side: const BorderSide(
                              color: SupplyClosetColors.tealLight),
                          minimumSize: const Size(0, 44),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded,
                            size: 18),
                        label: const Text(
                          'Scan Door Sign',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() {
                          _showAddForm = !_showAddForm;
                          if (_showAddForm) _showDoorScanner = false;
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showAddForm
                              ? SupplyClosetColors.warning
                              : SupplyClosetColors.teal,
                          foregroundColor: _showAddForm
                              ? const Color(0xFF020617)
                              : Colors.white,
                          minimumSize: const Size(0, 44),
                        ),
                        icon: Icon(
                          _showAddForm ? Icons.expand_less : Icons.add_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          '+ Add Supply Room',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                // Door Sign Scanner Panel
                if (_showDoorScanner) ...[
                  const SizedBox(height: 12),
                  _buildDoorScannerCard(rooms),
                ],

                // Add Supply Room Panel
                if (_showAddForm) ...[
                  const SizedBox(height: 12),
                  _buildAddRoomForm(),
                ],

                const SizedBox(height: 14),
                Text(
                  'SELECT ACTIVE SUPPLY ROOM (${rooms.length} ON ${widget.unitName.toUpperCase()})',
                  style: const TextStyle(
                    color: SupplyClosetColors.tealLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),

                // List of Supply Rooms on Floor
                for (final room in rooms)
                  _buildRoomTile(
                    context: context,
                    room: room,
                    isSelected: room.id == selectedRoomId,
                    onSelect: () {
                      roomProv.selectRoom(room.id);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloorWingSelector(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final currentUnitId = auth.profile?.unitId ?? 'med_3a';
    final wings = const [
      ('med_3a', 'Med 3A'),
      ('med_3b', 'Med 3B'),
      ('icu_4e', 'ICU 4E'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined,
              color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          const Text(
            'Floor Wing:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (uId, uName) in wings)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () async {
                          final prof = auth.profile;
                          if (prof == null) return;
                          await auth.updateFacilityAndUnit(
                            facilityId: prof.facilityId ?? 'txai_pilot_lab',
                            facilityName:
                                prof.facilityName ?? 'TxAI Pilot Simulation Lab',
                            unitId: uId,
                            unitName: uName,
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: currentUnitId == uId
                                ? SupplyClosetColors.teal
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            uName,
                            style: TextStyle(
                              color: currentUnitId == uId
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
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
    );
  }

  Widget _buildDoorScannerCard(List<SupplyRoom> rooms) {
    final hasLiveDoorCam = _doorCameraActive &&
        _doorCamera != null &&
        _doorCamera!.value.isInitialized;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SupplyClosetColors.tealLight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sensor_door_outlined,
                  color: SupplyClosetColors.tealLight, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Hospital Room Door Plaque Scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SupplyClosetColors.teal.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasLiveDoorCam ? '📷 LIVE CAM ON' : 'OCR / PLAQUE MATCH',
                  style: TextStyle(
                    color: hasLiveDoorCam
                        ? SupplyClosetColors.success
                        : SupplyClosetColors.tealLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Live Camera Viewfinder for Door Plaque
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SupplyClosetColors.tealLight),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasLiveDoorCam)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _doorCamera!.value.previewSize?.height ?? 480,
                        height: _doorCamera!.value.previewSize?.width ?? 640,
                        child: CameraPreview(_doorCamera!),
                      ),
                    ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: SupplyClosetColors.warning),
                      ),
                      child: Text(
                        hasLiveDoorCam
                            ? 'Aim at Room Door Plaque (e.g. RM 3A-102)'
                            : 'Camera Preview · Tap Detected Plaque Below',
                        style: const TextStyle(
                          color: SupplyClosetColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap a detected hospital door sign plaque below or type the room number on the door frame to auto-switch rooms:',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in rooms)
                ActionChip(
                  backgroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: SupplyClosetColors.tealLight),
                  avatar: const Icon(Icons.qr_code_2_rounded,
                      color: SupplyClosetColors.success, size: 16),
                  label: Text(
                    r.doorCode ?? r.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  onPressed: () => _matchDoorSign(rooms, r.doorCode ?? r.name),
                ),
              ActionChip(
                backgroundColor: const Color(0xFF1E293B),
                side: const BorderSide(color: SupplyClosetColors.warning),
                label: const Text(
                  '🚪 RM 3A-204 (South Closet)',
                  style: TextStyle(
                    color: SupplyClosetColors.warning,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                onPressed: () => _matchDoorSign(rooms, 'RM 3A-204'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _doorScanCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Door sign (e.g. RM 3A-102 or 3A-204)',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (v) => _matchDoorSign(rooms, v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _matchDoorSign(rooms, _doorScanCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SupplyClosetColors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(84, 42),
                ),
                child: const Text('Match'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddRoomForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SupplyClosetColors.warning, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ADD A SUPPLY ROOM ON THIS FLOOR',
            style: TextStyle(
              color: SupplyClosetColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quick-add a common floor supply room or enter custom room details:',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final preset in _quickFloorRooms)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Colors.white24),
                      label: Text(
                        '+ ${preset['name']} (${preset['door']})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => _createNewRoom(
                        presetName: preset['name'],
                        presetDoor: preset['door'],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _roomNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Supply Room Name',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'e.g., Med 3A · South Supply Room',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _doorCodeCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Door Sign / Plaque Number (Optional)',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'e.g., RM 3A-204',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isCreating ? null : () => _createNewRoom(),
            style: ElevatedButton.styleFrom(
              backgroundColor: SupplyClosetColors.warning,
              foregroundColor: const Color(0xFF020617),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.add_business_rounded),
            label: Text(
              _isCreating ? 'ADDING ROOM...' : 'ADD & SWITCH TO THIS ROOM',
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTile({
    required BuildContext context,
    required SupplyRoom room,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? SupplyClosetColors.teal.withValues(alpha: 0.22)
            : const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? SupplyClosetColors.success : Colors.white24,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onSelect,
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color:
                      isSelected ? SupplyClosetColors.success : Colors.white54,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              room.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (room.doorCode != null &&
                              room.doorCode!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                '🚪 ${room.doorCode}',
                                style: const TextStyle(
                                  color: SupplyClosetColors.tealLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        room.isInitiated
                            ? '✓ 3D Gaussian Splat & ${room.shelves.length} Shelf Racks Ready · ${room.hints.length} Captain Hints'
                            : '○ Uninitiated Room — Scan doorway & shelves for +${AppConstants.pointsInitiateRoom} XP',
                        style: TextStyle(
                          color: room.isInitiated
                              ? SupplyClosetColors.success
                              : SupplyClosetColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SupplyClosetColors.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Color(0xFF020617),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Room Captain Status Bar inside each room card
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: room.hasCaptain
                    ? SupplyClosetColors.warning.withValues(alpha: 0.5)
                    : Colors.white12,
              ),
            ),
            child: Row(
              children: [
                if (room.hasCaptain) ...[
                  UserAvatar(
                    displayName: room.captainName ?? 'Captain',
                    photoUrl: room.captainAvatar,
                    radius: 14,
                    isCaptain: true,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '👑 Room Captain: ${room.captainName} (${room.captainTagCount} tags)',
                      style: const TextStyle(
                        color: SupplyClosetColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.emoji_events_outlined,
                      color: Colors.white54, size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'No Room Captain yet — Tag supplies here to earn +150 XP!',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ),
                ],
                if (!room.isInitiated)
                  TextButton(
                    onPressed: () {
                      context.read<RoomProvider>().selectRoom(room.id);
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomInitiationScreen(
                            roomId: room.id,
                            roomName: room.name,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 28),
                    ),
                    child: const Text(
                      'Scan Room →',
                      style: TextStyle(
                        color: SupplyClosetColors.tealLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
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
}

/// Bottom sheet for viewing and placing Spatial Room Captain Hints in a room.
/// When a room has a Captain (the user who tagged the most supplies in the room),
/// the Captain can drop spatial hints at any shelf/bin that all users see in
/// the 3D Gaussian Splat and First-Person AR HUD with the Captain's avatar & name.
class CaptainHintSheet extends StatefulWidget {
  final String facilityId;
  final String unitId;
  final SupplyRoom room;

  const CaptainHintSheet({
    super.key,
    required this.facilityId,
    required this.unitId,
    required this.room,
  });

  static Future<void> show(
    BuildContext context, {
    required String facilityId,
    required String unitId,
    required SupplyRoom room,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CaptainHintSheet(
        facilityId: facilityId,
        unitId: unitId,
        room: room,
      ),
    );
  }

  @override
  State<CaptainHintSheet> createState() => _CaptainHintSheetState();
}

class _CaptainHintSheetState extends State<CaptainHintSheet> {
  final _firestore = FirestoreService();
  final _hintCtrl = TextEditingController();
  String _selectedShelf = 'A';
  int _selectedBin = 2;
  bool _isPosting = false;

  @override
  void dispose() {
    _hintCtrl.dispose();
    super.dispose();
  }

  Future<void> _postHint() async {
    final text = _hintCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a helpful hint for your unit teammates.'),
          backgroundColor: SupplyClosetColors.coral,
        ),
      );
      return;
    }

    final profile = context.read<AuthProvider>().profile;
    if (profile == null) return;

    setState(() => _isPosting = true);
    try {
      final rack = widget.room.findShelf(_selectedShelf) ??
          ShelfRack.defaultForCode(_selectedShelf);
      final loc = rack.locationForBin(_selectedBin);

      final hint = RoomHint(
        id: 'hint_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        shelfId: _selectedShelf,
        binNumber: _selectedBin,
        x: loc.x,
        y: loc.y,
        z: loc.z,
        yawDegrees: rack.yawDegrees,
        captainUid: profile.uid,
        captainName: profile.displayName,
        captainAvatar: profile.photoUrl,
        createdAt: DateTime.now(),
      );

      await _firestore.addCaptainHint(
        facilityId: widget.facilityId,
        unitId: widget.unitId,
        roomId: widget.room.id,
        hint: hint,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '👑 Captain Hint pinned at Shelf $_selectedShelf · Bin $_selectedBin!',
            ),
            backgroundColor: SupplyClosetColors.successDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pin hint: $e'),
            backgroundColor: SupplyClosetColors.coral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    // Allow the Room Captain (or any nurse if no captain is crowned yet) to post hints
    final isCaptain = profile != null &&
        (widget.room.captainUid == profile.uid || !widget.room.hasCaptain);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(top: 56, bottom: bottomInset),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: SupplyClosetColors.warning, width: 2),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Room Captain Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: SupplyClosetColors.warning, width: 1.5),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    displayName: widget.room.captainName ??
                        profile?.displayName ??
                        'Captain',
                    photoUrl: widget.room.captainAvatar ?? profile?.photoUrl,
                    radius: 24,
                    isCaptain: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: SupplyClosetColors.warning
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '👑 ROOM CAPTAIN (+150 XP MEDAL)',
                                style: TextStyle(
                                  color: SupplyClosetColors.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.room.hasCaptain
                              ? '${widget.room.captainName} · ${widget.room.captainTagCount} Supplies Tagged'
                              : 'Tag supplies in ${widget.room.name} to become Room Captain!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'The top tagger in this room earns +150 XP and can pin 3D hints for all nurses.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Existing Spatial Hints in this Room
            if (widget.room.hints.isNotEmpty) ...[
              const Text(
                'ACTIVE CAPTAIN HINTS IN THIS ROOM',
                style: TextStyle(
                  color: SupplyClosetColors.tealLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              for (final h in widget.room.hints.reversed)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: SupplyClosetColors.tealLight
                            .withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                        displayName: h.captainName,
                        photoUrl: h.captainAvatar,
                        radius: 16,
                        isCaptain: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '👑 ${h.captainName} · Shelf ${h.shelfId}${h.binNumber != null ? " Bin ${h.binNumber}" : ""}',
                              style: const TextStyle(
                                color: SupplyClosetColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '"${h.text}"',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Pin a New Spatial Captain Hint
            if (isCaptain) ...[
              const Text(
                'PIN A NEW 3D CAPTAIN HINT IN ROOM',
                style: TextStyle(
                  color: SupplyClosetColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final s in ['A', 'B', 'C'])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text('Shelf $s'),
                          selected: _selectedShelf == s,
                          selectedColor: SupplyClosetColors.teal,
                          backgroundColor: const Color(0xFF020617),
                          labelStyle: TextStyle(
                            color: _selectedShelf == s
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedShelf = s),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: List.generate(8, (i) {
                  final b = i + 1;
                  final sel = _selectedBin == b;
                  return ChoiceChip(
                    label: Text('Bin $b'),
                    selected: sel,
                    selectedColor: SupplyClosetColors.warning,
                    backgroundColor: const Color(0xFF020617),
                    labelStyle: TextStyle(
                      color: sel ? const Color(0xFF020617) : Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                    onSelected: (_) => setState(() => _selectedBin = b),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _hintCtrl,
                maxLength: 80,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'e.g., Extra 18G IV catheters are tucked behind the saline boxes!',
                  hintStyle: const TextStyle(color: Colors.white38),
                  counterStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF020617),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isPosting ? null : _postHint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SupplyClosetColors.warning,
                  foregroundColor: const Color(0xFF020617),
                  minimumSize: const Size(double.infinity, 52),
                ),
                icon: const Icon(Icons.push_pin_rounded),
                label: Text(
                  _isPosting
                      ? 'PINNING HINT...'
                      : '👑 PIN HINT AT SHELF $_selectedShelf · BIN $_selectedBin',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
