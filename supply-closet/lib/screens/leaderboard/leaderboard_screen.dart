import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/gamification_service.dart';

/// Leaderboard tabs: My Unit | My Hospital | All Time
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboards'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: SupplyClosetColors.teal,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: SupplyClosetColors.teal,
          tabs: const [
            Tab(text: 'My Unit'),
            Tab(text: 'My Hospital'),
            Tab(text: 'Unit Rivals'),
          ],
        ),
      ),
      body: profile == null || !profile.hasCompletedOnboarding
          ? _buildSetupNeeded()
          : TabBarView(
              controller: _tabs,
              children: [
                _UnitTab(profile: profile, firestore: _firestore),
                _FacilityTab(profile: profile, firestore: _firestore),
                _UnitVsUnitTab(profile: profile),
              ],
            ),
    );
  }

  Widget _buildSetupNeeded() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Pick your unit to see rankings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Unit tab ──────────────────────────────────────────────────────

class _UnitTab extends StatelessWidget {
  final UserProfile profile;
  final FirestoreService firestore;

  const _UnitTab({required this.profile, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserProfile>>(
      stream: firestore.unitLeaderboard(profile.facilityId!, profile.unitId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!;
        if (users.isEmpty) {
          return const Center(child: Text('No tags yet on this unit.'));
        }
        return _buildLeaderboardList(context, users, profile.uid,
            subtitle: profile.unitName ?? 'Your unit');
      },
    );
  }
}

// ─── Facility tab ──────────────────────────────────────────────────

class _FacilityTab extends StatelessWidget {
  final UserProfile profile;
  final FirestoreService firestore;

  const _FacilityTab({required this.profile, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserProfile>>(
      stream: firestore.facilityLeaderboard(profile.facilityId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!;
        if (users.isEmpty) {
          return const Center(child: Text('No tags yet at this facility.'));
        }
        return _buildLeaderboardList(context, users, profile.uid,
            subtitle: profile.facilityName ?? 'Your hospital');
      },
    );
  }
}

// ─── Unit-vs-unit (cooperative weekly) ─────────────────────────────

class _UnitVsUnitTab extends StatelessWidget {
  final UserProfile profile;
  const _UnitVsUnitTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    // Phase 2: this aggregates per-unit weekly tag counts. For now we render
    // a polished placeholder that explains the upcoming feature.
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [SupplyClosetColors.teal, SupplyClosetColors.tealLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Unit Rivalry — Weekly',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your unit competes against other units at your hospital. '
                  'Top unit at the end of the week wins bragging rights '
                  'and a 2x XP weekend.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _UnitVsUnitRow(
              name: profile.unitName ?? 'Your Unit', tags: 142, isYours: true),
          _UnitVsUnitRow(name: 'ICU', tags: 128),
          _UnitVsUnitRow(name: 'Med-Surg 5', tags: 97),
          _UnitVsUnitRow(name: 'ED', tags: 86),
          _UnitVsUnitRow(name: 'PACU', tags: 64),
        ],
      ),
    );
  }
}

class _UnitVsUnitRow extends StatelessWidget {
  final String name;
  final int tags;
  final bool isYours;
  const _UnitVsUnitRow(
      {required this.name, required this.tags, this.isYours = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isYours
            ? SupplyClosetColors.tealLight.withValues(alpha: 0.15)
            : null,
        border: Border.all(
          color: isYours ? SupplyClosetColors.teal : Colors.grey.shade200,
          width: isYours ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.local_hospital,
              color: isYours ? SupplyClosetColors.teal : Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontWeight: isYours ? FontWeight.w700 : FontWeight.w500)),
          ),
          Text('$tags tags',
              style: TextStyle(
                  color: SupplyClosetColors.teal, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Shared list builder ───────────────────────────────────────────

Widget _buildLeaderboardList(
    BuildContext context, List<UserProfile> users, String currentUid,
    {required String subtitle}) {
  return Column(
    children: [
      if (users.length >= 3)
        _buildPodium(context, users.take(3).toList(), currentUid),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            Text(subtitle,
                style: TextStyle(
                    color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('${users.length} ranked',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final user = users[i];
            return _LeaderboardRow(
              rank: i + 1,
              user: user,
              isCurrentUser: user.uid == currentUid,
            );
          },
        ),
      ),
    ],
  );
}

// ─── Podium widget (top 3) ─────────────────────────────────────────

Widget _buildPodium(
    BuildContext context, List<UserProfile> top, String currentUid) {
  if (top.length < 3) return const SizedBox.shrink();
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
            child: _PodiumColumn(
                user: top[1],
                rank: 2,
                height: 100,
                isCurrentUser: top[1].uid == currentUid)),
        Expanded(
            child: _PodiumColumn(
                user: top[0],
                rank: 1,
                height: 130,
                isCurrentUser: top[0].uid == currentUid)),
        Expanded(
            child: _PodiumColumn(
                user: top[2],
                rank: 3,
                height: 80,
                isCurrentUser: top[2].uid == currentUid)),
      ],
    ),
  );
}

class _PodiumColumn extends StatelessWidget {
  final UserProfile user;
  final int rank;
  final double height;
  final bool isCurrentUser;

  const _PodiumColumn({
    required this.user,
    required this.rank,
    required this.height,
    required this.isCurrentUser,
  });

  Color _medalColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: _medalColor(),
          backgroundImage:
              user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
          child: user.photoUrl == null
              ? Text(user.displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 22))
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          user.displayName.split(' ').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isCurrentUser ? SupplyClosetColors.teal : Colors.black),
        ),
        Text('${user.points} XP',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _medalColor().withValues(alpha: 0.7),
                _medalColor().withValues(alpha: 0.4),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text('#$rank',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

// ─── Leaderboard row ──────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final UserProfile user;
  final bool isCurrentUser;

  const _LeaderboardRow({
    required this.rank,
    required this.user,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final level = GamificationService.levelFromXp(user.points);
    final title = GamificationService.titleForLevel(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? SupplyClosetColors.tealLight.withValues(alpha: 0.15)
            : null,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: SupplyClosetColors.teal, width: 2)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: rank <= 3
                        ? SupplyClosetColors.teal
                        : Colors.grey.shade700)),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: SupplyClosetColors.tealLight,
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(user.displayName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              isCurrentUser ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SupplyClosetColors.teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('YOU',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                Text('Lv $level · $title',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${user.points}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              Text('XP',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
