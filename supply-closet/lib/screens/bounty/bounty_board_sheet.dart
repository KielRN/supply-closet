import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/supply_bounty.dart';
import '../../models/supply_room.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../room/room_initiation_screen.dart';

/// User-Initiated Supply Bounty Board & Creation Sheet.
///
/// Nurses can post a Supply Bounty when an important supply hasn't been tagged
/// yet (so they can't find it), and other nurses ("Bounty Hunters") earn extra
/// XP (+50 Bonus XP on top of the tag) for hunting it down and tagging its bin.
class BountyBoardSheet extends StatefulWidget {
  final String facilityId;
  final String unitId;
  final String roomId;
  final SupplyRoom? room;
  final String? initialSupplyNameToPost;
  final String? initialNote;
  final void Function(SupplyBounty bounty)? onHuntBounty;

  const BountyBoardSheet({
    super.key,
    required this.facilityId,
    required this.unitId,
    required this.roomId,
    this.room,
    this.initialSupplyNameToPost,
    this.initialNote,
    this.onHuntBounty,
  });

  static Future<void> show(
    BuildContext context, {
    required String facilityId,
    required String unitId,
    required String roomId,
    SupplyRoom? room,
    String? initialSupplyNameToPost,
    String? initialNote,
    void Function(SupplyBounty bounty)? onHuntBounty,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: BountyBoardSheet(
          facilityId: facilityId,
          unitId: unitId,
          roomId: roomId,
          room: room,
          initialSupplyNameToPost: initialSupplyNameToPost,
          initialNote: initialNote,
          onHuntBounty: onHuntBounty,
        ),
      ),
    );
  }

  @override
  State<BountyBoardSheet> createState() => _BountyBoardSheetState();
}

class _BountyBoardSheetState extends State<BountyBoardSheet> {
  final _firestore = FirestoreService();
  late final TextEditingController _supplyController;
  late final TextEditingController _noteController;
  bool _showCreateForm = false;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _supplyController =
        TextEditingController(text: widget.initialSupplyNameToPost ?? '');
    _noteController = TextEditingController(
      text: widget.initialNote ?? 'Not tagged in this room yet — please locate!',
    );
    if (widget.initialSupplyNameToPost != null &&
        widget.initialSupplyNameToPost!.trim().isNotEmpty) {
      _showCreateForm = true;
    }
  }

  @override
  void dispose() {
    _supplyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _postBounty() async {
    final name = _supplyController.text.trim();
    if (name.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    if (profile == null) return;

    setState(() => _isPosting = true);
    try {
      await _firestore.createBounty(
        facilityId: widget.facilityId,
        unitId: widget.unitId,
        roomId: widget.roomId,
        supplyName: name,
        note: _noteController.text.trim(),
        bonusXp: AppConstants.pointsClaimBounty,
        userId: profile.uid,
        userName: profile.displayName.isNotEmpty ? profile.displayName : 'Nurse',
      );
      if (mounted) {
        setState(() {
          _isPosting = false;
          _showCreateForm = false;
          _supplyController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🎯 Posted Supply Bounty for "$name" (+${AppConstants.pointsClaimBounty} Bonus XP for Hunter)!'),
            backgroundColor: SupplyClosetColors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not post bounty: $e'),
            backgroundColor: SupplyClosetColors.coral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SupplyClosetColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SupplyClosetColors.warning),
                  ),
                  child: const Icon(
                    Icons.gps_fixed_rounded,
                    color: SupplyClosetColors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UNIT QUEST BOARD',
                        style: TextStyle(
                          color: SupplyClosetColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'Supply Bounties',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      setState(() => _showCreateForm = !_showCreateForm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showCreateForm
                        ? const Color(0xFF334155)
                        : SupplyClosetColors.warning,
                    foregroundColor: _showCreateForm
                        ? Colors.white
                        : const Color(0xFF020617),
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: Icon(
                    _showCreateForm ? Icons.close : Icons.add_alert_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _showCreateForm ? 'Cancel' : '+ Post Bounty',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),

          // User-Initiated Create Bounty Form
          if (_showCreateForm) _buildCreateBountyCard(),

          // Stream of Open & Claimed Bounties
          Expanded(
            child: StreamBuilder<List<SupplyBounty>>(
              stream: _firestore.bountiesInRoom(
                widget.facilityId,
                widget.unitId,
                widget.roomId,
              ),
              builder: (context, snapshot) {
                final bounties = snapshot.data ?? [];
                final openBounties =
                    bounties.where((b) => b.isOpen).toList();
                final claimedBounties =
                    bounties.where((b) => !b.isOpen).take(5).toList();
                final roomInitiated = widget.room?.isInitiated ?? false;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    // Legendary Room Initiation Contract if room isn't initiated yet
                    if (!roomInitiated) _buildRoomContractCard(context),

                    if (openBounties.isEmpty && roomInitiated)
                      _buildEmptyBountiesPrompt(),

                    for (final b in openBounties) _buildOpenBountyCard(b),

                    if (claimedBounties.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'RECENTLY HUNTED & RESOLVED',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final b in claimedBounties)
                        _buildClaimedBountyCard(b),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateBountyCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SupplyClosetColors.warning, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.campaign_rounded,
                  color: SupplyClosetColors.warning, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Need an untagged supply? Post a Bounty!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '+${AppConstants.pointsClaimBounty} XP to Hunter',
                style: TextStyle(
                  color: SupplyClosetColors.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _supplyController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Supply needed (untagged or missing)',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'e.g. Blood Culture Bottles, 16 Fr Foley...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              prefixIcon: const Icon(Icons.medical_services_outlined,
                  color: SupplyClosetColors.tealLight),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Context / Note for Bounty Hunter',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              prefixIcon: const Icon(Icons.notes_rounded,
                  color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isPosting ? null : _postBounty,
            style: ElevatedButton.styleFrom(
              backgroundColor: SupplyClosetColors.warning,
              foregroundColor: const Color(0xFF020617),
              minimumSize: const Size(double.infinity, 50),
            ),
            icon: const Icon(Icons.gps_fixed_rounded),
            label: Text(
              _isPosting
                  ? 'POSTING BOUNTY...'
                  : 'POST SUPPLY BOUNTY (+${AppConstants.pointsClaimBounty} BONUS XP)',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomContractCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SupplyClosetColors.warning.withValues(alpha: 0.22),
            const Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SupplyClosetColors.warning, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SupplyClosetColors.warning,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '🏛️ LEGENDARY ROOM CONTRACT',
                  style: TextStyle(
                    color: Color(0xFF020617),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Text(
                '+${AppConstants.pointsInitiateRoom} XP',
                style: TextStyle(
                  color: SupplyClosetColors.warning,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Initiate Supply Room 1 (3D Splat + Shelf Racks)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'This room has not been spatially scanned yet. Perform a doorway scan and pin Shelf A, B, C to unlock 3D navigation for the whole unit.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RoomInitiationScreen(roomId: widget.roomId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SupplyClosetColors.warning,
              foregroundColor: const Color(0xFF020617),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.radar_rounded),
            label: const Text(
              'START ROOM SCANNER (+250 XP)',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenBountyCard(SupplyBounty bounty) {
    final totalXp = AppConstants.pointsTagNew + bounty.bonusXp;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SupplyClosetColors.tealLight.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SupplyClosetColors.teal.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SupplyClosetColors.tealLight),
                ),
                child: Text(
                  '🎯 WANTED BY ${bounty.createdByName.toUpperCase()}',
                  style: const TextStyle(
                    color: SupplyClosetColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '+$totalXp XP TOTAL',
                style: const TextStyle(
                  color: SupplyClosetColors.success,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bounty.supplyName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (bounty.note != null && bounty.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              bounty.note!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onHuntBounty?.call(bounty);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SupplyClosetColors.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: Text(
              'HUNT & TAG THIS SUPPLY (+${bounty.bonusXp} BONUS XP)',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimedBountyCard(SupplyBounty bounty) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: SupplyClosetColors.success, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bounty.supplyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Found at ${bounty.resolvedLocation ?? "Shelf"} by ${bounty.claimedByName ?? "Hunter"}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '+${bounty.bonusXp} XP',
            style: const TextStyle(
              color: SupplyClosetColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBountiesPrompt() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_rounded,
              color: SupplyClosetColors.success, size: 36),
          const SizedBox(height: 8),
          const Text(
            'No Open Supply Bounties Right Now',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Can\'t find a supply because it hasn\'t been tagged yet? Tap "+ Post Bounty" above so a teammate can hunt it down for +50 Bonus XP!',
            style: TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showCreateForm = true),
            style: OutlinedButton.styleFrom(
              foregroundColor: SupplyClosetColors.warning,
              side: const BorderSide(color: SupplyClosetColors.warning),
              minimumSize: const Size(double.infinity, 46),
            ),
            icon: const Icon(Icons.add_alert_rounded),
            label: const Text('Post a Supply Bounty'),
          ),
        ],
      ),
    );
  }
}
