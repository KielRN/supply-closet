import 'package:cloud_firestore/cloud_firestore.dart';

/// A SupplyCloset user profile with gamification data
class UserProfile {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String? facilityId;
  final String? facilityName;
  final String? unitId;
  final String? unitName;
  final String role; // 'nurse', 'charge', 'admin'
  final int points;
  final int totalTags;
  final int tagsThisMonth;
  final int streakDays;
  final List<String> badges;
  final DateTime createdAt;
  final DateTime lastActive;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
    this.facilityId,
    this.facilityName,
    this.unitId,
    this.unitName,
    this.role = 'nurse',
    this.points = 0,
    this.totalTags = 0,
    this.tagsThisMonth = 0,
    this.streakDays = 0,
    this.badges = const [],
    DateTime? createdAt,
    DateTime? lastActive,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActive = lastActive ?? DateTime.now();

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] ?? 'Nurse',
      email: data['email'],
      photoUrl: data['photoUrl'],
      facilityId: data['facilityId'],
      facilityName: data['facilityName'],
      unitId: data['unitId'],
      unitName: data['unitName'],
      role: data['role'] ?? 'nurse',
      points: data['points'] ?? 0,
      totalTags: data['totalTags'] ?? 0,
      tagsThisMonth: data['tagsThisMonth'] ?? 0,
      streakDays: data['streakDays'] ?? 0,
      badges: List<String>.from(data['badges'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'facilityId': facilityId,
      'facilityName': facilityName,
      'unitId': unitId,
      'unitName': unitName,
      'role': role,
      'points': points,
      'totalTags': totalTags,
      'tagsThisMonth': tagsThisMonth,
      'streakDays': streakDays,
      'badges': badges,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
    };
  }

  /// Whether the user has completed onboarding (selected facility + unit)
  bool get hasCompletedOnboarding =>
      facilityId != null && unitId != null;

  /// Rank title based on total points
  String get rankTitle {
    if (points >= 5000) return 'Supply Sensei';
    if (points >= 2000) return 'Floor Expert';
    if (points >= 1000) return 'Supply Pro';
    if (points >= 500) return 'Pathfinder';
    if (points >= 100) return 'Scout';
    return 'New Nurse';
  }

  UserProfile copyWith({
    String? facilityId,
    String? facilityName,
    String? unitId,
    String? unitName,
    int? points,
    int? totalTags,
    int? tagsThisMonth,
    int? streakDays,
    List<String>? badges,
    DateTime? lastActive,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      role: role,
      points: points ?? this.points,
      totalTags: totalTags ?? this.totalTags,
      tagsThisMonth: tagsThisMonth ?? this.tagsThisMonth,
      streakDays: streakDays ?? this.streakDays,
      badges: badges ?? this.badges,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
