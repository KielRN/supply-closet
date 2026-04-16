import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/gamification_service.dart';

/// Card displaying a daily or unit challenge with progress bar.
class ChallengeCard extends StatelessWidget {
  final DailyChallenge challenge;
  const ChallengeCard({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    final isComplete = challenge.isComplete;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? SupplyClosetColors.successDark
              : Colors.grey.shade200,
          width: isComplete ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: challenge.isBonus
                      ? SupplyClosetColors.coral.withOpacity(0.15)
                      : SupplyClosetColors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isComplete
                      ? Icons.check_circle_rounded
                      : (challenge.isBonus ? Icons.star : Icons.flag),
                  color: isComplete
                      ? SupplyClosetColors.successDark
                      : (challenge.isBonus
                          ? SupplyClosetColors.coral
                          : SupplyClosetColors.teal),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            challenge.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (challenge.isBonus)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: SupplyClosetColors.coral,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'BONUS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SupplyClosetColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              FractionallySizedBox(
                widthFactor: challenge.progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isComplete
                          ? [
                              SupplyClosetColors.success,
                              SupplyClosetColors.successDark
                            ]
                          : [
                              SupplyClosetColors.tealLight,
                              SupplyClosetColors.teal
                            ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${challenge.currentProgress} / ${challenge.targetCount}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SupplyClosetColors.textSecondary,
                ),
              ),
              Text(
                '+${challenge.xpReward} XP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isComplete
                      ? SupplyClosetColors.successDark
                      : SupplyClosetColors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
