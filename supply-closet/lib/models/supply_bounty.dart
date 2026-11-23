import 'package:cloud_firestore/cloud_firestore.dart';

/// A user-initiated Supply Bounty.
///
/// When a nurse searches for a supply that hasn't been tagged yet (or finds
/// a bin empty), she can post a Supply Bounty so another nurse ("Bounty Hunter")
/// can locate and tag it for extra bonus XP.
class SupplyBounty {
  final String id;
  final String supplyName;
  final String? category;
  final String? note;
  final int bonusXp;
  final String status; // 'open' | 'claimed'
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final String? claimedByUid;
  final String? claimedByName;
  final DateTime? claimedAt;
  final String? resolvedLocation;
  final String? resolvedSupplyId;
  final int version;

  const SupplyBounty({
    required this.id,
    required this.supplyName,
    this.category,
    this.note,
    required this.bonusXp,
    required this.status,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    this.claimedByUid,
    this.claimedByName,
    this.claimedAt,
    this.resolvedLocation,
    this.resolvedSupplyId,
    this.version = 1,
  });

  bool get isOpen => status == 'open';

  factory SupplyBounty.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupplyBounty(
      id: doc.id,
      supplyName: (data['supplyName'] ?? '').toString(),
      category: data['category'] as String?,
      note: data['note'] as String?,
      bonusXp: ((data['bonusXp'] ?? 50) as num).toInt(),
      status: (data['status'] ?? 'open').toString(),
      createdByUid: (data['createdByUid'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? 'Nurse').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      claimedByUid: data['claimedByUid'] as String?,
      claimedByName: data['claimedByName'] as String?,
      claimedAt: (data['claimedAt'] as Timestamp?)?.toDate(),
      resolvedLocation: data['resolvedLocation'] as String?,
      resolvedSupplyId: data['resolvedSupplyId'] as String?,
      version: ((data['version'] ?? 1) as num).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'supplyName': supplyName,
      'category': category,
      'note': note,
      'bonusXp': bonusXp,
      'status': status,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'claimedByUid': claimedByUid,
      'claimedByName': claimedByName,
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'resolvedLocation': resolvedLocation,
      'resolvedSupplyId': resolvedSupplyId,
      'version': version,
    };
  }
}
