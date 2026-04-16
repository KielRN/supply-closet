import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/gamification_service.dart';

/// Displays current streak with animated flame effect.
/// Hot streaks pulse to communicate momentum.
class StreakCard extends StatefulWidget {
  final int streakDays;
  const StreakCard({super.key, required this.streakDays});

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = GamificationService.streakStatus(widget.streakDays);
    final color = Color(status.color);
    final isHot = widget.streakDays >= 5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isHot
              ? [color, color.withOpacity(0.7)]
              : [Colors.white, SupplyClosetColors.surfaceLight],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHot ? Colors.transparent : Colors.grey.shade200,
        ),
        boxShadow: isHot
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              return Transform.scale(
                scale: isHot ? 1.0 + (_pulseCtrl.value * 0.1) : 1.0,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHot ? Colors.white : color.withOpacity(0.15),
                  ),
                  child: Icon(
                    isHot ? Icons.local_fire_department : Icons.bolt,
                    color: isHot ? color : color,
                    size: 32,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${widget.streakDays}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isHot ? Colors.white : SupplyClosetColors.charcoal,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        widget.streakDays == 1 ? 'shift' : 'shifts',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isHot
                              ? Colors.white.withOpacity(0.9)
                              : SupplyClosetColors.textSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (status.multiplier > 1.0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isHot
                              ? Colors.white
                              : color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${status.multiplier}x XP',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isHot
                        ? Colors.white
                        : SupplyClosetColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: isHot
                        ? Colors.white.withOpacity(0.85)
                        : SupplyClosetColors.textTertiary,
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
