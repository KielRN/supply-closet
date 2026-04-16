import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../config/constants.dart';
import '../models/user_profile.dart';

/// ── GAME ENGINE ──────────────────────────────────────────────
///
/// SupplyCloset's gamification is modeled after mobile RPGs:
///   - XP bar with level-ups and rank progression
///   - Daily challenges with bonus XP
///   - Streak multipliers that reward consistency
///   - Achievement badges with rarity tiers
///   - "Loot drop" moments when tagging reveals a rare find
///   - Weekly unit challenges (cooperative)
///   - Seasonal events tied to hospital life (Flu Season Rush, etc.)
///
/// Design philosophy: every interaction should feel like progress.
/// Even a 10-second tag should produce visible XP movement.

class GamificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── XP & LEVELING SYSTEM ────────────────────────────────────

  /// XP thresholds for each level (RPG-style curve)
  static const List<int> levelThresholds = [
    0,      // Level 1: New Nurse
    100,    // Level 2: Scout
    300,    // Level 3: Pathfinder
    600,    // Level 4: Explorer
    1000,   // Level 5: Supply Pro
    1500,   // Level 6: Floor Expert
    2200,   // Level 7: Unit Champion
    3000,   // Level 8: Supply Veteran
    4000,   // Level 9: Master Tagger
    5000,   // Level 10: Supply Sensei
    6500,   // Level 11: Legend
    8000,   // Level 12: Mythic
    10000,  // Level 13: Transcendent
  ];

  static const List<String> levelTitles = [
    'New Nurse',
    'Scout',
    'Pathfinder',
    'Explorer',
    'Supply Pro',
    'Floor Expert',
    'Unit Champion',
    'Supply Veteran',
    'Master Tagger',
    'Supply Sensei',
    'Legend',
    'Mythic',
    'Transcendent',
  ];

  /// Calculate current level from total XP
  static int levelFromXp(int xp) {
    for (int i = levelThresholds.length - 1; i >= 0; i--) {
      if (xp >= levelThresholds[i]) return i + 1;
    }
    return 1;
  }

  /// XP needed to reach next level
  static int xpToNextLevel(int xp) {
    final level = levelFromXp(xp);
    if (level >= levelThresholds.length) return 0; // Max level
    return levelThresholds[level] - xp;
  }

  /// Progress percentage toward next level (0.0 to 1.0)
  static double levelProgress(int xp) {
    final level = levelFromXp(xp);
    if (level >= levelThresholds.length) return 1.0;
    final currentLevelXp = levelThresholds[level - 1];
    final nextLevelXp = levelThresholds[level];
    final range = nextLevelXp - currentLevelXp;
    if (range <= 0) return 1.0;
    return ((xp - currentLevelXp) / range).clamp(0.0, 1.0);
  }

  /// Title for a given level
  static String titleForLevel(int level) {
    if (level < 1) return levelTitles[0];
    if (level > levelTitles.length) return levelTitles.last;
    return levelTitles[level - 1];
  }

  // ─── STREAK SYSTEM ───────────────────────────────────────────

  /// Streak multiplier: consecutive active shifts boost XP gain
  /// 1 shift  = 1.0x
  /// 2 shifts = 1.1x
  /// 3 shifts = 1.2x
  /// 5 shifts = 1.5x (bonus badge unlocked)
  /// 7 shifts = 2.0x (on fire!)
  /// 14 shifts = 2.5x (legendary)
  static double streakMultiplier(int streakDays) {
    if (streakDays >= 14) return 2.5;
    if (streakDays >= 7) return 2.0;
    if (streakDays >= 5) return 1.5;
    if (streakDays >= 3) return 1.2;
    if (streakDays >= 2) return 1.1;
    return 1.0;
  }

  /// Human-readable streak status
  static StreakStatus streakStatus(int streakDays) {
    if (streakDays >= 14) {
      return StreakStatus(
        label: 'LEGENDARY',
        emoji: 'legendary',
        color: 0xFFFFD700,
        multiplier: 2.5,
        message: '14-shift streak! You\'re unstoppable.',
      );
    }
    if (streakDays >= 7) {
      return StreakStatus(
        label: 'ON FIRE',
        emoji: 'fire',
        color: 0xFFFF4500,
        multiplier: 2.0,
        message: '7-shift streak — 2x XP on everything!',
      );
    }
    if (streakDays >= 5) {
      return StreakStatus(
        label: 'Hot Streak',
        emoji: 'streak',
        color: 0xFFF97316,
        multiplier: 1.5,
        message: '5 shifts strong. 1.5x XP active.',
      );
    }
    if (streakDays >= 3) {
      return StreakStatus(
        label: 'Rolling',
        emoji: 'rolling',
        color: 0xFF0D9488,
        multiplier: 1.2,
        message: '3-shift streak. Keep it going!',
      );
    }
    return StreakStatus(
      label: 'Building',
      emoji: 'building',
      color: 0xFF64748B,
      multiplier: 1.0,
      message: 'Tag supplies each shift to build your streak.',
    );
  }

  // ─── DAILY CHALLENGES ────────────────────────────────────────

  /// Generate today's challenges based on day-of-week and user level
  static List<DailyChallenge> dailyChallenges(int userLevel, int dayOfWeek) {
    final challenges = <DailyChallenge>[];

    // Challenge 1: Always present — basic tag target
    final tagTarget = 3 + (userLevel ~/ 2); // scales with level
    challenges.add(DailyChallenge(
      id: 'daily_tags',
      title: 'Tag $tagTarget Supplies',
      description: 'Tag or confirm $tagTarget supply locations this shift',
      targetCount: tagTarget,
      xpReward: 25 + (userLevel * 5),
      type: ChallengeType.tagCount,
    ));

    // Challenge 2: Rotates by day of week
    switch (dayOfWeek % 5) {
      case 0: // Procedure challenge
        challenges.add(DailyChallenge(
          id: 'daily_procedure',
          title: 'Procedure Pro',
          description: 'Complete 2 procedure checklists using Find mode',
          targetCount: 2,
          xpReward: 40 + (userLevel * 5),
          type: ChallengeType.procedureComplete,
        ));
        break;
      case 1: // Confirm challenge
        challenges.add(DailyChallenge(
          id: 'daily_confirm',
          title: 'Fact Checker',
          description: 'Confirm 5 existing supply locations',
          targetCount: 5,
          xpReward: 30 + (userLevel * 3),
          type: ChallengeType.confirmCount,
        ));
        break;
      case 2: // New tag challenge
        challenges.add(DailyChallenge(
          id: 'daily_new',
          title: 'Uncharted',
          description: 'Tag 2 supplies that haven\'t been mapped yet',
          targetCount: 2,
          xpReward: 50 + (userLevel * 5),
          type: ChallengeType.newTagCount,
        ));
        break;
      case 3: // Speed challenge
        challenges.add(DailyChallenge(
          id: 'daily_speed',
          title: 'Speed Scanner',
          description: 'Tag 3 supplies in under 2 minutes',
          targetCount: 3,
          xpReward: 60 + (userLevel * 5),
          type: ChallengeType.speedTag,
        ));
        break;
      case 4: // Barcode challenge
        challenges.add(DailyChallenge(
          id: 'daily_barcode',
          title: 'Barcode Hunter',
          description: 'Scan and tag 3 supplies using barcode scan',
          targetCount: 3,
          xpReward: 35 + (userLevel * 3),
          type: ChallengeType.barcodeScan,
        ));
        break;
    }

    // Challenge 3: Weekend bonus (Fri/Sat/Sun shifts)
    if (dayOfWeek >= 5 || dayOfWeek == 0) {
      challenges.add(DailyChallenge(
        id: 'weekend_warrior',
        title: 'Weekend Warrior',
        description: 'Complete any 2 other challenges this shift',
        targetCount: 2,
        xpReward: 75,
        type: ChallengeType.metaChallenge,
        isBonus: true,
      ));
    }

    return challenges;
  }

  // ─── BADGE SYSTEM (with rarity tiers) ────────────────────────

  static const List<GameBadge> allBadges = [
    // ── COMMON (easy to earn, first-session targets) ──
    GameBadge(
      id: 'first_tag',
      name: 'First Tag',
      description: 'Tagged your very first supply',
      rarity: BadgeRarity.common,
      icon: 'tag',
      xpReward: 10,
    ),
    GameBadge(
      id: 'first_scan',
      name: 'Scanner',
      description: 'Used barcode scanning for the first time',
      rarity: BadgeRarity.common,
      icon: 'barcode',
      xpReward: 10,
    ),
    GameBadge(
      id: 'first_procedure',
      name: 'By the Book',
      description: 'Completed your first procedure checklist',
      rarity: BadgeRarity.common,
      icon: 'checklist',
      xpReward: 15,
    ),

    // ── UNCOMMON (1-2 weeks of use) ──
    GameBadge(
      id: 'century_club',
      name: '100 Club',
      description: '100 lifetime supply tags',
      rarity: BadgeRarity.uncommon,
      icon: 'century',
      xpReward: 50,
    ),
    GameBadge(
      id: 'streak_5',
      name: 'On a Roll',
      description: '5 consecutive shifts with activity',
      rarity: BadgeRarity.uncommon,
      icon: 'streak',
      xpReward: 50,
    ),
    GameBadge(
      id: 'night_owl',
      name: 'Night Owl',
      description: '50+ tags during night shifts (7pm-7am)',
      rarity: BadgeRarity.uncommon,
      icon: 'moon',
      xpReward: 60,
    ),
    GameBadge(
      id: 'helping_hand',
      name: 'Helping Hand',
      description: 'Your tags have been used by 10 other nurses',
      rarity: BadgeRarity.uncommon,
      icon: 'hand',
      xpReward: 40,
    ),

    // ── RARE (dedicated players, ~1 month) ──
    GameBadge(
      id: 'trailblazer',
      name: 'Trailblazer',
      description: 'First nurse to tag a supply on a new unit',
      rarity: BadgeRarity.rare,
      icon: 'compass',
      xpReward: 100,
    ),
    GameBadge(
      id: 'eagle_eye',
      name: 'Eagle Eye',
      description: 'Found a supply that 10+ nurses marked "not found"',
      rarity: BadgeRarity.rare,
      icon: 'eagle',
      xpReward: 100,
    ),
    GameBadge(
      id: 'streak_14',
      name: 'Unstoppable',
      description: '14 consecutive shifts. Legendary streak.',
      rarity: BadgeRarity.rare,
      icon: 'flame',
      xpReward: 150,
    ),
    GameBadge(
      id: 'challenge_master',
      name: 'Challenge Master',
      description: 'Completed 30 daily challenges',
      rarity: BadgeRarity.rare,
      icon: 'star',
      xpReward: 100,
    ),

    // ── EPIC (top ~5% of users) ──
    GameBadge(
      id: 'supply_sensei',
      name: 'Supply Sensei',
      description: '500 lifetime supply tags',
      rarity: BadgeRarity.epic,
      icon: 'sensei',
      xpReward: 250,
    ),
    GameBadge(
      id: 'unit_mvp',
      name: 'Unit MVP',
      description: '#1 on your unit leaderboard for a full month',
      rarity: BadgeRarity.epic,
      icon: 'trophy',
      xpReward: 300,
    ),
    GameBadge(
      id: 'team_player',
      name: 'Team Player',
      description: 'Referred 3 colleagues who signed up',
      rarity: BadgeRarity.epic,
      icon: 'team',
      xpReward: 200,
    ),

    // ── LEGENDARY (top ~1%) ──
    GameBadge(
      id: 'floor_cartographer',
      name: 'Floor Cartographer',
      description: 'Tagged 90%+ of known supplies on your unit',
      rarity: BadgeRarity.legendary,
      icon: 'map',
      xpReward: 500,
    ),
    GameBadge(
      id: 'thousand_tags',
      name: 'The Thousand',
      description: '1,000 lifetime supply tags. Absolute legend.',
      rarity: BadgeRarity.legendary,
      icon: 'crown',
      xpReward: 500,
    ),
  ];

  /// Check which new badges a user has earned
  static List<GameBadge> checkNewBadges({
    required UserProfile profile,
    required int totalTags,
    required int nightTags,
    required int streakDays,
    required int challengesCompleted,
    required int referralCount,
    required int nursesHelpedByTags,
    required bool isFirstOnUnit,
    required bool foundLongLostSupply,
    required double unitCoverage,
    required bool isUnitMvp,
    required bool usedBarcode,
    required bool completedProcedure,
  }) {
    final earned = <GameBadge>[];
    final existing = profile.badges.toSet();

    for (final badge in allBadges) {
      if (existing.contains(badge.id)) continue;

      final unlocked = switch (badge.id) {
        'first_tag' => totalTags >= 1,
        'first_scan' => usedBarcode,
        'first_procedure' => completedProcedure,
        'century_club' => totalTags >= 100,
        'streak_5' => streakDays >= 5,
        'night_owl' => nightTags >= 50,
        'helping_hand' => nursesHelpedByTags >= 10,
        'trailblazer' => isFirstOnUnit,
        'eagle_eye' => foundLongLostSupply,
        'streak_14' => streakDays >= 14,
        'challenge_master' => challengesCompleted >= 30,
        'supply_sensei' => totalTags >= 500,
        'unit_mvp' => isUnitMvp,
        'team_player' => referralCount >= 3,
        'floor_cartographer' => unitCoverage >= 0.9,
        'thousand_tags' => totalTags >= 1000,
        _ => false,
      };

      if (unlocked) earned.add(badge);
    }

    return earned;
  }

  // ─── XP AWARD ENGINE ─────────────────────────────────────────

  /// Calculate XP for an action, applying streak multiplier and bonuses
  static XpAwardResult calculateXp({
    required GameAction action,
    required int streakDays,
    required int userLevel,
    bool isFirstTagOnUnit = false,
    bool isNightShift = false,
  }) {
    // Base XP for the action
    int baseXp = switch (action) {
      GameAction.tagNew => AppConstants.pointsTagNew,
      GameAction.confirmExisting => AppConstants.pointsConfirmExisting,
      GameAction.completeProcedure => AppConstants.pointsCompleteProcedure,
      GameAction.reportNotFound => AppConstants.pointsReportNotFound,
      GameAction.completeChallenge => 0, // Challenge has its own XP
      GameAction.earnBadge => 0, // Badge has its own XP
    };

    // Bonuses
    int bonusXp = 0;
    final bonusReasons = <String>[];

    if (isFirstTagOnUnit) {
      bonusXp += AppConstants.pointsFirstTagOnUnit;
      bonusReasons.add('First tag on this unit! +${AppConstants.pointsFirstTagOnUnit}');
    }

    if (isNightShift && action == GameAction.tagNew) {
      bonusXp += 3;
      bonusReasons.add('Night shift bonus +3');
    }

    // Streak multiplier
    final multiplier = streakMultiplier(streakDays);
    final multipliedXp = ((baseXp + bonusXp) * multiplier).round();
    final streakBonus = multipliedXp - (baseXp + bonusXp);

    if (streakBonus > 0) {
      bonusReasons.add(
          '${multiplier}x streak multiplier +$streakBonus');
    }

    return XpAwardResult(
      baseXp: baseXp,
      bonusXp: bonusXp,
      streakBonus: streakBonus,
      totalXp: multipliedXp,
      multiplier: multiplier,
      bonusReasons: bonusReasons,
    );
  }

  /// Award XP via the server-side Cloud Function.
  ///
  /// The server validates the action actually occurred (anti-farming)
  /// and applies streak/bonus multipliers atomically.
  Future<XpAwardResult> awardXp({
    required String userId,
    required GameAction action,
    required int streakDays,
    required int userLevel,
    bool isFirstTagOnUnit = false,
    bool isNightShift = false,
    String? facilityId,
    String? unitId,
    String? supplyId,
  }) async {
    // Map client action enum to server action string
    final actionStr = switch (action) {
      GameAction.tagNew => 'tagNew',
      GameAction.confirmExisting => 'confirmExisting',
      GameAction.completeProcedure => 'completeProcedure',
      GameAction.reportNotFound => 'reportNotFound',
    };

    final callable = FirebaseFunctions.instance.httpsCallable('awardXp');
    final response = await callable.call({
      'action': actionStr,
      'isFirstTagOnUnit': isFirstTagOnUnit,
      'isNightShift': isNightShift,
      'facilityId': facilityId,
      'unitId': unitId,
      'supplyId': supplyId,
    });

    final data = response.data as Map<String, dynamic>;
    final xpAwarded = data['xpAwarded'] as int? ?? 0;

    return XpAwardResult(
      baseXp: xpAwarded,
      streakMultiplier: 1.0, // server handles this
      totalXp: xpAwarded,
      newBadges: List<String>.from(data['newBadges'] ?? []),
    );
  }

  // ─── WEEKLY UNIT CHALLENGES (cooperative) ─────────────────────

  /// Unit-wide cooperative challenges — the whole floor works together
  static List<UnitChallenge> weeklyUnitChallenges(int weekOfYear) {
    // Rotate through a set of cooperative challenges
    final challenges = [
      UnitChallenge(
        id: 'unit_map_blitz',
        title: 'Map Blitz',
        description: 'As a unit, tag 100 supplies this week',
        targetCount: 100,
        xpRewardPerNurse: 100,
        icon: 'map',
      ),
      UnitChallenge(
        id: 'unit_zero_notfound',
        title: 'Zero "Not Found"',
        description: 'Go 3 days without a "not found" report',
        targetCount: 3,
        xpRewardPerNurse: 75,
        icon: 'check_circle',
      ),
      UnitChallenge(
        id: 'unit_full_roster',
        title: 'Full Roster',
        description: 'Get every nurse on the unit to tag at least 1 supply',
        targetCount: 1,
        xpRewardPerNurse: 150,
        icon: 'people',
      ),
      UnitChallenge(
        id: 'unit_confirm_wave',
        title: 'Confirm Wave',
        description: 'Confirm 200 existing supply locations as a team',
        targetCount: 200,
        xpRewardPerNurse: 80,
        icon: 'verified',
      ),
    ];

    return [challenges[weekOfYear % challenges.length]];
  }

  // ─── SEASONAL EVENTS ─────────────────────────────────────────

  /// Special limited-time events tied to hospital life
  static SeasonalEvent? currentEvent(DateTime now) {
    final month = now.month;
    final day = now.day;

    // Flu Season Rush (Oct 1 - Nov 30)
    if (month == 10 || month == 11) {
      return SeasonalEvent(
        id: 'flu_season',
        name: 'Flu Season Rush',
        description:
            'Flu season is here! Tag respiratory and infection control supplies for 3x XP.',
        xpMultiplier: 3.0,
        targetCategories: ['respiratory', 'infection_control', 'ppe'],
        startDate: DateTime(now.year, 10, 1),
        endDate: DateTime(now.year, 11, 30),
        badgeReward: 'flu_fighter',
      );
    }

    // Nurses Week (May 6 - May 12)
    if (month == 5 && day >= 6 && day <= 12) {
      return SeasonalEvent(
        id: 'nurses_week',
        name: 'Nurses Week Special',
        description:
            'Happy Nurses Week! All XP is doubled. You deserve it.',
        xpMultiplier: 2.0,
        targetCategories: null, // All categories
        startDate: DateTime(now.year, 5, 6),
        endDate: DateTime(now.year, 5, 12),
        badgeReward: 'nurses_week_2026',
      );
    }

    // New Year Reset Rally (Jan 1 - Jan 14)
    if (month == 1 && day <= 14) {
      return SeasonalEvent(
        id: 'new_year_rally',
        name: 'New Year Supply Rally',
        description:
            'New year, fresh supplies! Help re-map your unit after the holiday restock.',
        xpMultiplier: 1.5,
        targetCategories: null,
        startDate: DateTime(now.year, 1, 1),
        endDate: DateTime(now.year, 1, 14),
        badgeReward: 'fresh_start',
      );
    }

    return null;
  }
}

// ─── DATA CLASSES ──────────────────────────────────────────────

enum GameAction {
  tagNew,
  confirmExisting,
  completeProcedure,
  reportNotFound,
  completeChallenge,
  earnBadge,
}

enum BadgeRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

enum ChallengeType {
  tagCount,
  confirmCount,
  newTagCount,
  procedureComplete,
  speedTag,
  barcodeScan,
  metaChallenge,
}

class XpAwardResult {
  final int baseXp;
  final int bonusXp;
  final int streakBonus;
  final int totalXp;
  final double multiplier;
  final List<String> bonusReasons;

  XpAwardResult({
    required this.baseXp,
    required this.bonusXp,
    required this.streakBonus,
    required this.totalXp,
    required this.multiplier,
    required this.bonusReasons,
  });

  bool get hasBonuses => bonusReasons.isNotEmpty;
}

class StreakStatus {
  final String label;
  final String emoji;
  final int color;
  final double multiplier;
  final String message;

  StreakStatus({
    required this.label,
    required this.emoji,
    required this.color,
    required this.multiplier,
    required this.message,
  });
}

class DailyChallenge {
  final String id;
  final String title;
  final String description;
  final int targetCount;
  final int xpReward;
  final ChallengeType type;
  final bool isBonus;
  int currentProgress;

  DailyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.targetCount,
    required this.xpReward,
    required this.type,
    this.isBonus = false,
    this.currentProgress = 0,
  });

  bool get isComplete => currentProgress >= targetCount;
  double get progress =>
      (currentProgress / targetCount).clamp(0.0, 1.0);
}

class UnitChallenge {
  final String id;
  final String title;
  final String description;
  final int targetCount;
  final int xpRewardPerNurse;
  final String icon;
  int currentProgress;

  UnitChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.targetCount,
    required this.xpRewardPerNurse,
    required this.icon,
    this.currentProgress = 0,
  });

  bool get isComplete => currentProgress >= targetCount;
  double get progress =>
      (currentProgress / targetCount).clamp(0.0, 1.0);
}

class SeasonalEvent {
  final String id;
  final String name;
  final String description;
  final double xpMultiplier;
  final List<String>? targetCategories;
  final DateTime startDate;
  final DateTime endDate;
  final String badgeReward;

  SeasonalEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.xpMultiplier,
    this.targetCategories,
    required this.startDate,
    required this.endDate,
    required this.badgeReward,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  int get daysRemaining =>
      endDate.difference(DateTime.now()).inDays;
}

class GameBadge {
  final String id;
  final String name;
  final String description;
  final BadgeRarity rarity;
  final String icon;
  final int xpReward;

  const GameBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    required this.icon,
    required this.xpReward,
  });

  /// Rarity color for UI rendering
  int get rarityColor => switch (rarity) {
        BadgeRarity.common => 0xFF94A3B8,     // Slate
        BadgeRarity.uncommon => 0xFF22C55E,    // Green
        BadgeRarity.rare => 0xFF3B82F6,        // Blue
        BadgeRarity.epic => 0xFF8B5CF6,        // Purple
        BadgeRarity.legendary => 0xFFFFD700,   // Gold
      };

  String get rarityLabel => switch (rarity) {
        BadgeRarity.common => 'Common',
        BadgeRarity.uncommon => 'Uncommon',
        BadgeRarity.rare => 'Rare',
        BadgeRarity.epic => 'Epic',
        BadgeRarity.legendary => 'Legendary',
      };
}
