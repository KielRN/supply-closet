/// App-wide constants
class AppConstants {
  // Gamification point values
  static const int pointsTagNew = 10;
  static const int pointsConfirmExisting = 5;
  static const int pointsCompleteProcedure = 15;
  static const int pointsReportNotFound = 5;
  static const int pointsFirstTagOnUnit = 25;
  static const int pointsStreakBonus = 50;
  static const int streakThreshold = 5; // consecutive shifts

  // Confidence scoring
  static const double confidenceInitial = 0.5;
  static const double confidenceConfirmBoost = 0.1;
  static const double confidenceDecayPerDay = 0.02;
  static const double confidenceMinDisplay = 0.3;
  static const int confidenceStaleAfterDays = 7;

  // AR
  static const double arOverlayMinConfidence = 0.4;
  static const double arMarkerScale = 0.08; // meters

  // Rooms
  static const String defaultRoomId = 'main';

  // UI
  static const double minTouchTarget = 48.0; // dp, glove-friendly
  static const int maxProcedureNameLength = 60;

  // Collections (Firestore)
  static const String facilitiesCollection = 'facilities';
  static const String unitsCollection = 'units';
  static const String supplyRoomsCollection = 'supplyRooms';
  static const String suppliesCollection = 'supplies';
  static const String usersCollection = 'users';
  static const String proceduresCollection = 'procedures';
  static const String tagsCollection = 'tags';
  static const String leaderboardCollection = 'leaderboard';
}

/// Badge definitions
class BadgeDefinitions {
  static const Map<String, BadgeInfo> badges = {
    'trailblazer': BadgeInfo(
      id: 'trailblazer',
      name: 'Trailblazer',
      description: 'First nurse to tag a supply on a new unit',
      icon: 'trailblazer',
    ),
    'night_owl': BadgeInfo(
      id: 'night_owl',
      name: 'Night Owl',
      description: '50+ tags during night shifts (7pm-7am)',
      icon: 'night_owl',
    ),
    'supply_sensei': BadgeInfo(
      id: 'supply_sensei',
      name: 'Supply Sensei',
      description: '500 lifetime supply tags',
      icon: 'supply_sensei',
    ),
    'eagle_eye': BadgeInfo(
      id: 'eagle_eye',
      name: 'Eagle Eye',
      description: 'Found a supply 10+ nurses had marked "not found"',
      icon: 'eagle_eye',
    ),
    'team_player': BadgeInfo(
      id: 'team_player',
      name: 'Team Player',
      description: 'Referred 3 colleagues who signed up',
      icon: 'team_player',
    ),
    'century_club': BadgeInfo(
      id: 'century_club',
      name: '100 Club',
      description: '100 lifetime supply tags',
      icon: 'century_club',
    ),
    'streak_5': BadgeInfo(
      id: 'streak_5',
      name: 'On a Roll',
      description: '5 consecutive shifts with activity',
      icon: 'streak_5',
    ),
  };
}

class BadgeInfo {
  final String id;
  final String name;
  final String description;
  final String icon;

  const BadgeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}
