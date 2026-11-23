import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/supply_room.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/gamification_service.dart';
import '../../widgets/room_switcher_sheet.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/xp_bar.dart';
import '../../widgets/streak_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final level = GamificationService.levelFromXp(profile.points);
    final title = GamificationService.titleForLevel(level);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 245,
            pinned: true,
            backgroundColor: SupplyClosetColors.teal,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(context, profile, level, title),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                tooltip: 'Edit Display Name & Avatar',
                onPressed: () => ProfileIdentitySheet.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => _openSettings(context, profile),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                XpBar(currentXp: profile.points),
                const SizedBox(height: 16),
                StreakCard(streakDays: profile.streakDays),
                const SizedBox(height: 16),
                _StatsGrid(profile: profile),
                const SizedBox(height: 24),
                _FloorRoomsSection(profile: profile),
                const SizedBox(height: 24),
                _BadgesSection(badges: profile.badges),
                const SizedBox(height: 24),
                _UnitInfoCard(
                  profile: profile,
                  onTap: () => _changeFacility(context),
                ),
                const SizedBox(height: 24),
                _SignOutButton(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, UserProfile profile, int level, String title) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SupplyClosetColors.teal,
            SupplyClosetColors.tealLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => ProfileIdentitySheet.show(context),
            child: UserAvatar(
              displayName: profile.displayName,
              photoUrl: profile.photoUrl,
              radius: 36,
              isCaptain: profile.badges.contains('room_captain'),
            ),
          ),
          const SizedBox(height: 8),
          Text(profile.displayName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Lv $level · $title',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => ProfileIdentitySheet.show(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.face_retouching_natural,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Edit Avatar & Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context, UserProfile profile) {
    final facilityId = profile.facilityId ?? 'txai_pilot_lab';
    final unitId = profile.unitId ?? 'med_3a';
    final unitName = profile.unitName ?? 'Med 3A';

    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.face_retouching_natural,
                  color: SupplyClosetColors.teal),
              title: const Text('Customize display name & avatar'),
              subtitle: const Text(
                  'Choose a pre-generated avatar, upload photo, or edit name'),
              onTap: () {
                Navigator.pop(context);
                ProfileIdentitySheet.show(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.meeting_room_rounded,
                  color: SupplyClosetColors.teal),
              title: Text('Manage Supply Rooms ($unitName)'),
              subtitle: const Text(
                  'Switch active supply room, scan door sign, or add a closet'),
              onTap: () {
                Navigator.pop(context);
                RoomSwitcherSheet.show(
                  context,
                  facilityId: facilityId,
                  unitId: unitId,
                  unitName: unitName,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: const Text('Change hospital / floor wing (e.g. Med 3A)'),
              onTap: () {
                Navigator.pop(context);
                _changeFacility(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy & data'),
              subtitle: const Text('We collect zero PHI'),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  void _changeFacility(BuildContext context) {
    final facilityCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Where do you work?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: facilityCtrl,
              decoration: const InputDecoration(
                labelText: 'Hospital / Facility',
                hintText: 'St. Mary\'s Medical Center',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(
                labelText: 'Unit',
                hintText: 'ICU 4 East',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final fac = facilityCtrl.text.trim();
              final unit = unitCtrl.text.trim();
              if (fac.isEmpty || unit.isEmpty) return;
              final facilityId =
                  fac.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
              final unitId = unit.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
              await context.read<AuthProvider>().updateFacilityAndUnit(
                    facilityId: facilityId,
                    facilityName: fac,
                    unitId: unitId,
                    unitName: unit,
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Stats grid ────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final UserProfile profile;
  const _StatsGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _StatCard(
          label: 'Total tags',
          value: '${profile.totalTags}',
          icon: Icons.label_outline,
        ),
        _StatCard(
          label: 'This month',
          value: '${profile.tagsThisMonth}',
          icon: Icons.calendar_today,
        ),
        _StatCard(
          label: 'Streak',
          value: '${profile.streakDays}d',
          icon: Icons.local_fire_department,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: SupplyClosetColors.teal, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Supply Rooms on Floor (Multi-Room Management & Room Captains) ──

class _FloorRoomsSection extends StatelessWidget {
  final UserProfile profile;
  const _FloorRoomsSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final roomProv = context.watch<RoomProvider>();
    final facilityId = profile.facilityId ?? 'txai_pilot_lab';
    final unitId = profile.unitId ?? 'med_3a';
    final unitName = profile.unitName ?? 'Med 3A';

    return StreamBuilder<List<SupplyRoom>>(
      stream: firestore.roomsInUnit(facilityId, unitId),
      builder: (context, snapshot) {
        final rooms = snapshot.data ??
            [
              SupplyRoom.uninitiated(
                AppConstants.defaultRoomId,
                name: '$unitName · North Supply Rm',
                doorCode: 'RM 3A-102',
              ),
            ];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SupplyClosetColors.tealLight.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.meeting_room_rounded,
                    color: SupplyClosetColors.tealLight,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Supply Rooms on $unitName (${rooms.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => RoomSwitcherSheet.show(
                      context,
                      facilityId: facilityId,
                      unitId: unitId,
                      unitName: unitName,
                      openAddRoomInitially: true,
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: SupplyClosetColors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Add Room',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final room in rooms) ...[
                InkWell(
                  onTap: () => roomProv.selectRoom(room.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: room.id == roomProv.selectedRoomId
                          ? SupplyClosetColors.teal.withValues(alpha: 0.25)
                          : const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: room.id == roomProv.selectedRoomId
                            ? SupplyClosetColors.success
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          room.id == roomProv.selectedRoomId
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: room.id == roomProv.selectedRoomId
                              ? SupplyClosetColors.success
                              : Colors.white54,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${room.name}${room.doorCode != null ? " (${room.doorCode})" : ""}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                room.hasCaptain
                                    ? '👑 Room Captain: ${room.captainName} (${room.captainTagCount} tags)'
                                    : 'No Captain yet — tag supplies here for +150 XP!',
                                style: TextStyle(
                                  color: room.hasCaptain
                                      ? SupplyClosetColors.warning
                                      : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (room.hasCaptain)
                          UserAvatar(
                            displayName: room.captainName ?? 'C',
                            photoUrl: room.captainAvatar,
                            radius: 14,
                            isCaptain: true,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Badges ─────────────────────────────────────────────────────────

class _BadgesSection extends StatelessWidget {
  final List<String> badges;
  const _BadgesSection({required this.badges});

  @override
  Widget build(BuildContext context) {
    final allBadgeIds = BadgeDefinitions.badges.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Text('Badges',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${badges.length}/${allBadgeIds.length}',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.85,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: allBadgeIds.length,
          itemBuilder: (context, i) {
            final id = allBadgeIds[i];
            final earned = badges.contains(id);
            final info = BadgeDefinitions.badges[id]!;
            return _BadgeTile(info: info, earned: earned);
          },
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeInfo info;
  final bool earned;
  const _BadgeTile({required this.info, required this.earned});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBadgeDetail(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: earned
              ? SupplyClosetColors.tealLight.withValues(alpha: 0.2)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: earned ? SupplyClosetColors.teal : Colors.grey.shade300,
            width: earned ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              earned ? Icons.emoji_events : Icons.lock_outline,
              color: earned ? SupplyClosetColors.teal : Colors.grey.shade400,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              info.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: earned ? FontWeight.w600 : FontWeight.w400,
                color: earned ? Colors.black : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              earned ? Icons.emoji_events : Icons.lock_outline,
              color: earned ? SupplyClosetColors.teal : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(info.name)),
          ],
        ),
        content: Text(info.description),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

// ─── Unit info ──────────────────────────────────────────────────────

class _UnitInfoCard extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onTap;
  const _UnitInfoCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.local_hospital, color: SupplyClosetColors.teal),
        title: Text(profile.facilityName ?? 'No facility set'),
        subtitle: Text(profile.unitName ?? 'No unit selected'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ─── Sign out ───────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        await context.read<AuthProvider>().signOut();
      },
      icon: const Icon(Icons.logout),
      label: const Text('Sign out'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: SupplyClosetColors.coral,
        side: BorderSide(color: SupplyClosetColors.coral),
      ),
    );
  }
}
