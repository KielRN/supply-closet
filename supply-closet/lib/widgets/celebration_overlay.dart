import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../providers/gamification_provider.dart';
import '../services/gamification_service.dart';

/// Full-screen celebration overlay that shows XP bursts, level-ups,
/// badge reveals, and challenge completions.
///
/// Each celebration plays for ~2-3 seconds with satisfying motion.
class CelebrationOverlay extends StatefulWidget {
  final CelebrationEvent event;
  final VoidCallback onDismiss;

  const CelebrationOverlay({
    super.key,
    required this.event,
    required this.onDismiss,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _exitCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _exitOpacityAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _exitCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
    );
    _exitOpacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(_exitCtrl);

    _entryCtrl.forward();

    // Auto-dismiss timing varies by celebration type
    final dismissDelay = switch (widget.event.type) {
      CelebrationType.xpAward => const Duration(milliseconds: 1400),
      CelebrationType.levelUp => const Duration(milliseconds: 3000),
      CelebrationType.badgeReveal => const Duration(milliseconds: 3500),
      CelebrationType.challengeComplete => const Duration(milliseconds: 2500),
      CelebrationType.streakMilestone => const Duration(milliseconds: 2500),
    };

    Future.delayed(dismissDelay, () {
      if (mounted) {
        _exitCtrl.forward().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entryCtrl, _exitCtrl]),
      builder: (context, _) {
        return Opacity(
          opacity: _exitOpacityAnim.value,
          child: Material(
            color: Colors.black.withOpacity(0.6 * _opacityAnim.value),
            child: GestureDetector(
              onTap: () {
                _exitCtrl.forward().then((_) => widget.onDismiss());
              },
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: _buildCelebrationContent(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCelebrationContent() {
    return switch (widget.event.type) {
      CelebrationType.xpAward => _XpBurstCard(result: widget.event.xpResult!),
      CelebrationType.levelUp => _LevelUpCard(
          level: widget.event.newLevel!,
          title: widget.event.newTitle!,
        ),
      CelebrationType.badgeReveal => _BadgeRevealCard(badge: widget.event.badge!),
      CelebrationType.challengeComplete =>
        _ChallengeCompleteCard(challenge: widget.event.challenge!),
      CelebrationType.streakMilestone => const SizedBox.shrink(),
    };
  }
}

// ─── XP BURST (small, fast, satisfying) ──────────────────────

class _XpBurstCard extends StatelessWidget {
  final XpAwardResult result;
  const _XpBurstCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SupplyClosetColors.tealLight, SupplyClosetColors.teal],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: SupplyClosetColors.teal.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+${result.totalXp} XP',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          if (result.hasBonuses) ...[
            const SizedBox(height: 8),
            ...result.bonusReasons.map((reason) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    reason,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ─── LEVEL UP (big moment) ───────────────────────────────────

class _LevelUpCard extends StatelessWidget {
  final int level;
  final String title;
  const _LevelUpCard({required this.level, required this.title});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Radiating burst
        ...List.generate(8, (i) {
          final angle = (i * math.pi / 4);
          return Transform.rotate(
            angle: angle,
            child: Container(
              width: 4,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.amber.withOpacity(0.0),
                    Colors.amber.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.6),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LEVEL UP!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: Color(0xFFB45309),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: SupplyClosetColors.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'New rank unlocked',
                style: TextStyle(
                  fontSize: 13,
                  color: SupplyClosetColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── BADGE REVEAL (loot-box style) ───────────────────────────

class _BadgeRevealCard extends StatelessWidget {
  final GameBadge badge;
  const _BadgeRevealCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final rarityColor = Color(badge.rarityColor);

    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: rarityColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withOpacity(0.6),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rarity tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: rarityColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge.rarityLabel.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Badge medallion
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  rarityColor.withOpacity(0.9),
                  rarityColor,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: rarityColor.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.shield,
              color: Colors.white,
              size: 70,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'BADGE UNLOCKED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: SupplyClosetColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: SupplyClosetColors.charcoal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            badge.description,
            style: const TextStyle(
              fontSize: 14,
              color: SupplyClosetColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: SupplyClosetColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '+${badge.xpReward} XP',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: SupplyClosetColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CHALLENGE COMPLETE ──────────────────────────────────────

class _ChallengeCompleteCard extends StatelessWidget {
  final DailyChallenge challenge;
  const _ChallengeCompleteCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: SupplyClosetColors.success.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  SupplyClosetColors.success,
                  SupplyClosetColors.successDark,
                ],
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'CHALLENGE COMPLETE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: SupplyClosetColors.successDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            challenge.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            challenge.description,
            style: const TextStyle(
              fontSize: 14,
              color: SupplyClosetColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '+${challenge.xpReward} XP',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: SupplyClosetColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}
