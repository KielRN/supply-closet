import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/supply_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/gamification_service.dart';

/// AR finder screen — the camera-overlay view that points the nurse at the
/// supplies they need. Wraps the ar_flutter_plugin AR view in a fallback-safe
/// container so the screen still works on devices without ARCore/ARKit.
class ArFinderScreen extends StatefulWidget {
  /// If provided, the AR finder filters to just the supplies needed for this
  /// procedure. Otherwise it shows everything in the room.
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
  final Set<String> _foundSupplyIds = {};
  bool _arSupported = true; // toggled by AR init
  String? _activeFilter;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.targetSupplyNames?.isNotEmpty == true
        ? widget.targetSupplyNames!.first
        : null;
    // Real implementation initializes ARSessionManager from ar_flutter_plugin
    // and registers anchor placement callbacks. We default to AR-supported
    // and let the build method gracefully degrade if needed.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    if (profile?.facilityId == null || profile?.unitId == null) {
      return _buildSetupNeeded();
    }
    const roomId = AppConstants.defaultRoomId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<SupplyItem>>(
        stream: _firestore.suppliesInRoom(
            profile!.facilityId!, profile.unitId!, roomId),
        builder: (context, snapshot) {
          final allSupplies = snapshot.data ?? [];
          final supplies = _filterSupplies(allSupplies);

          return Stack(
            children: [
              _buildArView(),
              ..._buildOverlayMarkers(supplies),
              _buildTopBar(context, supplies),
              _buildBottomChecklist(context, profile.uid, supplies),
            ],
          );
        },
      ),
    );
  }

  List<SupplyItem> _filterSupplies(List<SupplyItem> all) {
    if (widget.targetSupplyNames == null ||
        widget.targetSupplyNames!.isEmpty) {
      return all;
    }
    final targets = widget.targetSupplyNames!.map((n) => n.toLowerCase());
    return all
        .where((s) => targets.any((t) => s.name.toLowerCase().contains(t)))
        .toList();
  }

  Widget _buildArView() {
    if (!_arSupported) {
      return Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'AR not supported on this device — showing list view instead.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    // In production, this is the ARView from ar_flutter_plugin with
    // onArViewCreated wired to ARSessionManager + anchor management.
    // Placeholder gradient simulates the camera feed for now.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey.shade800, Colors.grey.shade900],
        ),
      ),
      child: const Center(
        child: Icon(Icons.camera_alt_outlined,
            size: 64, color: Colors.white24),
      ),
    );
  }

  List<Widget> _buildOverlayMarkers(List<SupplyItem> supplies) {
    // Real impl: project 3D anchor positions to screen space.
    // For Phase 1 we render markers in a grid based on relative confidence.
    return supplies.asMap().entries.take(8).map((entry) {
      final i = entry.key;
      final supply = entry.value;
      final isFound = _foundSupplyIds.contains(supply.id);
      final col = i % 3;
      final row = i ~/ 3;
      return Positioned(
        left: 40 + col * 100.0,
        top: 140 + row * 90.0,
        child: _ArMarker(
          supply: supply,
          isFound: isFound,
          onTap: () => _onMarkerTap(supply),
        ),
      );
    }).toList();
  }

  void _onMarkerTap(SupplyItem supply) {
    setState(() {
      if (_foundSupplyIds.contains(supply.id)) {
        _foundSupplyIds.remove(supply.id);
      } else {
        _foundSupplyIds.add(supply.id);
        // Award confirm XP for the find
        final auth = context.read<AuthProvider>();
        final game = context.read<GamificationProvider>();
        if (auth.profile != null) {
          game.recordAction(
            profile: auth.profile!,
            action: GameAction.confirmExisting,
            isNightShift:
                DateTime.now().hour >= 19 || DateTime.now().hour < 7,
            facilityId: auth.profile!.facilityId,
            unitId: auth.profile!.unitId,
            supplyId: supply.id,
          );
        }
      }
    });
  }

  Widget _buildTopBar(BuildContext context, List<SupplyItem> supplies) {
    final foundCount = supplies.where((s) => _foundSupplyIds.contains(s.id)).length;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Row(
        children: [
          _circleButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: SupplyClosetColors.success, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$foundCount / ${supplies.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16),
                ),
              ],
            ),
          ),
          const Spacer(),
          _circleButton(
            icon: Icons.help_outline,
            onTap: () => _showHelp(context),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(48),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildBottomChecklist(
      BuildContext context, String userId, List<SupplyItem> supplies) {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.12,
      maxChildSize: 0.72,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: SupplyClosetColors.warmWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Text(
                      widget.procedureId != null
                          ? 'Procedure checklist'
                          : 'Supplies in this room',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text('${supplies.length} items',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: supplies.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 60),
                  itemBuilder: (context, i) {
                    final supply = supplies[i];
                    final isFound = _foundSupplyIds.contains(supply.id);
                    return _SupplyListTile(
                      supply: supply,
                      isFound: isFound,
                      onToggle: () => _onMarkerTap(supply),
                      onNotFound: () => _onNotFound(supply, userId),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onNotFound(SupplyItem supply, String userId) async {
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    if (profile == null) return;
    await _firestore.reportNotFound(
      facilityId: profile.facilityId!,
      unitId: profile.unitId!,
      roomId: 'main',
      supplyId: supply.id,
      userId: userId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked "${supply.name}" as not found at this location'),
          backgroundColor: SupplyClosetColors.warning,
        ),
      );
    }
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How AR Finder works',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text(
              'Point your camera at the supply room. Markers appear on top '
              'of the bins your team has tagged. Tap a marker when you grab '
              'the item — that confirms its location and earns you XP.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'See a marker but the supply isn\'t there? Tap "Not here" — we\'ll '
              'lower the confidence and surface it for re-tagging.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupNeeded() {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Supplies')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('Set your unit first',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Go to your profile and tell us where you work — '
                'we need to know which supply room to show.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Marker overlay widget ─────────────────────────────────────────

class _ArMarker extends StatelessWidget {
  final SupplyItem supply;
  final bool isFound;
  final VoidCallback onTap;

  const _ArMarker({
    required this.supply,
    required this.isFound,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFound
        ? SupplyClosetColors.success
        : (supply.isReliable
            ? SupplyClosetColors.teal
            : SupplyClosetColors.warning);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isFound ? Icons.check : Icons.medical_services,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 110),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              supply.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom sheet list tile ────────────────────────────────────────

class _SupplyListTile extends StatelessWidget {
  final SupplyItem supply;
  final bool isFound;
  final VoidCallback onToggle;
  final VoidCallback onNotFound;

  const _SupplyListTile({
    required this.supply,
    required this.isFound,
    required this.onToggle,
    required this.onNotFound,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: GestureDetector(
        onTap: onToggle,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isFound
                ? SupplyClosetColors.success
                : SupplyClosetColors.warmWhite,
            shape: BoxShape.circle,
            border: Border.all(
              color: isFound
                  ? SupplyClosetColors.success
                  : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: isFound
              ? const Icon(Icons.check, color: Colors.white)
              : null,
        ),
      ),
      title: Text(
        supply.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          decoration: isFound ? TextDecoration.lineThrough : null,
          color: isFound ? Colors.grey.shade500 : Colors.black87,
        ),
      ),
      subtitle: Text(
        supply.location.displayLabel,
        style: TextStyle(
          fontSize: 12,
          color: supply.isReliable
              ? Colors.grey.shade700
              : SupplyClosetColors.warning,
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'not_found') onNotFound();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'not_found',
            child: Text('Not here'),
          ),
        ],
      ),
    );
  }
}
