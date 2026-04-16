import 'package:flutter/material.dart';
import '../services/gamification_service.dart';
import '../models/user_profile.dart';

/// Manages live gamification state — daily challenges, current streak,
/// pending XP awards, level-up animations, badge reveals
class GamificationProvider extends ChangeNotifier {
  final GamificationService _service = GamificationService();

  // Active challenges for this shift
  List<DailyChallenge> _dailyChallenges = [];
  List<DailyChallenge> get dailyChallenges => _dailyChallenges;

  // Active unit challenges this week
  List<UnitChallenge> _unitChallenges = [];
  List<UnitChallenge> get unitChallenges => _unitChallenges;

  // Current seasonal event
  SeasonalEvent? _activeEvent;
  SeasonalEvent? get activeEvent => _activeEvent;

  // Pending celebrations (queue of things to show the user)
  final List<CelebrationEvent> _celebrationQueue = [];
  CelebrationEvent? get nextCelebration =>
      _celebrationQueue.isNotEmpty ? _celebrationQueue.first : null;

  /// Initialize challenges based on current date and user level
  void initializeChallenges(UserProfile profile) {
    final now = DateTime.now();
    final dayOfWeek = now.weekday;
    final weekOfYear = _weekOfYear(now);
    final level = GamificationService.levelFromXp(profile.points);

    _dailyChallenges = GamificationService.dailyChallenges(level, dayOfWeek);
    _unitChallenges = GamificationService.weeklyUnitChallenges(weekOfYear);
    _activeEvent = GamificationService.currentEvent(now);

    notifyListeners();
  }

  /// Award XP for an action and queue celebrations
  ///
  /// The server validates the action and returns the actual XP awarded.
  /// Client uses server response for celebrations (no client-side prediction).
  Future<void> recordAction({
    required UserProfile profile,
    required GameAction action,
    bool isFirstTagOnUnit = false,
    bool isNightShift = false,
    String? facilityId,
    String? unitId,
    String? supplyId,
  }) async {
    // Update challenge progress locally (UI feedback)
    _updateChallengeProgress(action);

    // Award XP via Cloud Function — server is source of truth
    final serverResult = await _service.awardXp(
      userId: profile.uid,
      action: action,
      streakDays: profile.streakDays,
      userLevel: GamificationService.levelFromXp(profile.points),
      isFirstTagOnUnit: isFirstTagOnUnit,
      isNightShift: isNightShift,
      facilityId: facilityId ?? profile.facilityId,
      unitId: unitId ?? profile.unitId,
      supplyId: supplyId,
    );

    // Use server-returned XP for celebrations
    final oldLevel = GamificationService.levelFromXp(profile.points);
    final newLevel = GamificationService.levelFromXp(
        profile.points + serverResult.totalXp);

    // Queue XP burst celebration
    _celebrationQueue.add(CelebrationEvent(
      type: CelebrationType.xpAward,
      xpResult: serverResult,
    ));

    // Queue level up if it happened
    if (newLevel > oldLevel) {
      _celebrationQueue.add(CelebrationEvent(
        type: CelebrationType.levelUp,
        newLevel: newLevel,
        newTitle: GamificationService.titleForLevel(newLevel),
      ));
    }

    notifyListeners();
  }

  void _updateChallengeProgress(GameAction action) {
    for (final challenge in _dailyChallenges) {
      final shouldIncrement = switch (challenge.type) {
        ChallengeType.tagCount =>
            action == GameAction.tagNew || action == GameAction.confirmExisting,
        ChallengeType.confirmCount => action == GameAction.confirmExisting,
        ChallengeType.newTagCount => action == GameAction.tagNew,
        ChallengeType.procedureComplete =>
            action == GameAction.completeProcedure,
        ChallengeType.speedTag =>
            action == GameAction.tagNew || action == GameAction.confirmExisting,
        ChallengeType.barcodeScan => action == GameAction.tagNew,
        ChallengeType.metaChallenge => false,
      };

      if (shouldIncrement && !challenge.isComplete) {
        challenge.currentProgress++;
        if (challenge.isComplete) {
          // Queue challenge complete celebration
          _celebrationQueue.add(CelebrationEvent(
            type: CelebrationType.challengeComplete,
            challenge: challenge,
          ));
        }
      }
    }
  }

  /// Queue a badge reveal celebration
  void queueBadgeReveal(GameBadge badge) {
    _celebrationQueue.add(CelebrationEvent(
      type: CelebrationType.badgeReveal,
      badge: badge,
    ));
    notifyListeners();
  }

  /// Pop the current celebration after it's been displayed
  void dismissCurrentCelebration() {
    if (_celebrationQueue.isNotEmpty) {
      _celebrationQueue.removeAt(0);
      notifyListeners();
    }
  }

  int _weekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays;
    return ((dayOfYear + startOfYear.weekday - 1) / 7).floor();
  }
}

enum CelebrationType {
  xpAward,
  levelUp,
  badgeReveal,
  challengeComplete,
  streakMilestone,
}

class CelebrationEvent {
  final CelebrationType type;
  final XpAwardResult? xpResult;
  final int? newLevel;
  final String? newTitle;
  final GameBadge? badge;
  final DailyChallenge? challenge;

  CelebrationEvent({
    required this.type,
    this.xpResult,
    this.newLevel,
    this.newTitle,
    this.badge,
    this.challenge,
  });
}
