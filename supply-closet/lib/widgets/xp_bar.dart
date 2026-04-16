import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/gamification_service.dart';

/// Animated XP progress bar that pulses and fills smoothly.
/// Designed to feel like an MMO-style level bar.
class XpBar extends StatefulWidget {
  final int currentXp;
  final int previousXp;
  final bool showLevel;
  final bool compact;

  const XpBar({
    super.key,
    required this.currentXp,
    this.previousXp = 0,
    this.showLevel = true,
    this.compact = false,
  });

  @override
  State<XpBar> createState() => _XpBarState();
}

class _XpBarState extends State<XpBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _setupAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(XpBar old) {
    super.didUpdateWidget(old);
    if (old.currentXp != widget.currentXp) {
      _setupAnimation();
      _controller.forward(from: 0);
    }
  }

  void _setupAnimation() {
    final start = GamificationService.levelProgress(widget.previousXp);
    final end = GamificationService.levelProgress(widget.currentXp);
    _progressAnim = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = GamificationService.levelFromXp(widget.currentXp);
    final title = GamificationService.titleForLevel(level);
    final xpToNext = GamificationService.xpToNextLevel(widget.currentXp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLevel)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            SupplyClosetColors.teal,
                            SupplyClosetColors.tealDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'LV $level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  xpToNext > 0 ? '$xpToNext XP to LV ${level + 1}' : 'MAX',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        AnimatedBuilder(
          animation: _progressAnim,
          builder: (context, _) {
            return Container(
              height: widget.compact ? 8 : 14,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: _progressAnim.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            SupplyClosetColors.tealLight,
                            SupplyClosetColors.teal,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: SupplyClosetColors.teal.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (!widget.compact && widget.showLevel)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${widget.currentXp} XP',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
