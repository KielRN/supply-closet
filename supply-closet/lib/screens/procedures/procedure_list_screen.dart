import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/procedure_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../widgets/xp_bar.dart';
import '../../widgets/streak_card.dart';
import '../../widgets/challenge_card.dart';

class ProcedureListScreen extends StatefulWidget {
  const ProcedureListScreen({super.key});

  @override
  State<ProcedureListScreen> createState() => _ProcedureListScreenState();
}

class _ProcedureListScreenState extends State<ProcedureListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final procProvider = context.read<ProcedureProvider>();
      procProvider.loadProcedures();
      final auth = context.read<AuthProvider>();
      if (auth.profile != null) {
        context
            .read<GamificationProvider>()
            .initializeChallenges(auth.profile!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final procProvider = context.watch<ProcedureProvider>();
    final gamification = context.watch<GamificationProvider>();
    final profile = auth.profile;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header with XP bar ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: SupplyClosetColors.textSecondary,
                              ),
                            ),
                            Text(
                              profile?.displayName.split(' ').first ?? 'Nurse',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        if (profile?.unitName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: SupplyClosetColors.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              profile!.unitName!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (profile != null) XpBar(currentXp: profile.points),
                  ],
                ),
              ),
            ),

            // ─── Streak card ───
            if (profile != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: StreakCard(streakDays: profile.streakDays),
                ),
              ),

            // ─── Active seasonal event ───
            if (gamification.activeEvent != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: _SeasonalEventBanner(event: gamification.activeEvent!),
                ),
              ),

            // ─── Daily challenges ───
            if (gamification.dailyChallenges.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: _SectionHeader(
                    title: 'Today\'s Challenges',
                    subtitle: 'Complete for bonus XP',
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: ChallengeCard(
                        challenge: gamification.dailyChallenges[i]),
                  ),
                  childCount: gamification.dailyChallenges.length,
                ),
              ),
            ],

            // ─── Procedures list ───
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: _SectionHeader(
                  title: 'Procedures',
                  subtitle: 'Tap to see required supplies',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search procedures...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: procProvider.setSearchQuery,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final p = procProvider.filteredProcedures[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: _ProcedureTile(
                      title: p.name,
                      subtitle: '${p.totalSupplies} items • ${p.category}',
                      onTap: () => context.go('/procedure/${p.id}'),
                    ),
                  );
                },
                childCount: procProvider.filteredProcedures.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late shift,';
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    if (h < 21) return 'Good evening,';
    return 'Late shift,';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 13, color: SupplyClosetColors.textSecondary)),
      ],
    );
  }
}

class _ProcedureTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ProcedureTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SupplyClosetColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medical_services_rounded,
                    color: SupplyClosetColors.teal),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13,
                            color: SupplyClosetColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: SupplyClosetColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonalEventBanner extends StatelessWidget {
  final dynamic event; // SeasonalEvent
  const _SeasonalEventBanner({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_rounded, color: Colors.white),
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
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${event.xpMultiplier}x XP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ends in ${event.daysRemaining}d',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  event.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
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
