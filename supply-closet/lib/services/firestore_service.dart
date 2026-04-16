import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supply_item.dart';
import '../models/procedure.dart';
import '../models/user_profile.dart';
import '../config/constants.dart';

/// Central Firestore data access layer
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── PROCEDURES ──────────────────────────────────────────────

  /// Get all procedures, optionally filtered by category
  Stream<List<Procedure>> proceduresStream({String? category}) {
    Query query = _db.collection(AppConstants.proceduresCollection);
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => Procedure.fromFirestore(doc)).toList());
  }

  /// Get a single procedure by ID
  Future<Procedure?> getProcedure(String id) async {
    final doc =
        await _db.collection(AppConstants.proceduresCollection).doc(id).get();
    return doc.exists ? Procedure.fromFirestore(doc) : null;
  }

  /// Search procedures by name
  Stream<List<Procedure>> searchProcedures(String query) {
    final queryLower = query.toLowerCase();
    return _db
        .collection(AppConstants.proceduresCollection)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Procedure.fromFirestore(doc))
            .where((p) => p.name.toLowerCase().contains(queryLower))
            .toList());
  }

  // ─── SUPPLY ITEMS (per facility/unit/room) ───────────────────

  /// Path to a supply room's supplies collection
  CollectionReference _suppliesRef(
      String facilityId, String unitId, String roomId) {
    return _db
        .collection(AppConstants.facilitiesCollection)
        .doc(facilityId)
        .collection(AppConstants.unitsCollection)
        .doc(unitId)
        .collection(AppConstants.supplyRoomsCollection)
        .doc(roomId)
        .collection(AppConstants.suppliesCollection);
  }

  /// Stream all tagged supplies in a room
  Stream<List<SupplyItem>> suppliesInRoom(
      String facilityId, String unitId, String roomId) {
    return _suppliesRef(facilityId, unitId, roomId)
        .orderBy('confidence', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => SupplyItem.fromFirestore(doc)).toList());
  }

  /// Find a specific supply by name in a room
  Future<List<SupplyItem>> findSupplyByName(
      String facilityId, String unitId, String roomId, String name) async {
    final nameLower = name.toLowerCase();
    final snap = await _suppliesRef(facilityId, unitId, roomId).get();
    return snap.docs
        .map((doc) => SupplyItem.fromFirestore(doc))
        .where((s) => s.name.toLowerCase().contains(nameLower))
        .toList();
  }

  /// Tag a new supply location (or update existing)
  Future<void> tagSupply({
    required String facilityId,
    required String unitId,
    required String roomId,
    required String supplyName,
    String? barcode,
    String? category,
    required SupplyLocation location,
    required String userId,
  }) async {
    final ref = _suppliesRef(facilityId, unitId, roomId);

    // Check if this supply already exists (by barcode or name)
    QuerySnapshot existing;
    if (barcode != null) {
      existing = await ref.where('barcode', isEqualTo: barcode).limit(1).get();
    } else {
      existing = await ref
          .where('name', isEqualTo: supplyName)
          .limit(1)
          .get();
    }

    if (existing.docs.isNotEmpty) {
      // Update existing — boost confidence, update location
      final doc = existing.docs.first;
      final currentData = doc.data() as Map<String, dynamic>;
      final currentConfidence =
          (currentData['confidence'] ?? 0.5).toDouble();
      final newConfidence =
          (currentConfidence + AppConstants.confidenceConfirmBoost)
              .clamp(0.0, 1.0);

      await doc.reference.update({
        'location': location.toMap(),
        'confidence': newConfidence,
        'lastConfirmed': Timestamp.now(),
        'tagCount': FieldValue.increment(1),
        'taggedByUserIds': FieldValue.arrayUnion([userId]),
      });
    } else {
      // New supply tag
      final item = SupplyItem(
        id: '',
        name: supplyName,
        barcode: barcode,
        category: category,
        location: location,
        confidence: AppConstants.confidenceInitial,
        lastConfirmed: DateTime.now(),
        tagCount: 1,
        taggedByUserIds: [userId],
      );
      await ref.add(item.toFirestore());
    }
  }

  /// Report a supply as "not found"
  Future<void> reportNotFound({
    required String facilityId,
    required String unitId,
    required String roomId,
    required String supplyId,
    required String userId,
  }) async {
    final ref =
        _suppliesRef(facilityId, unitId, roomId).doc(supplyId);
    await ref.update({
      'confidence': FieldValue.increment(-0.15),
      'notFoundReports': FieldValue.arrayUnion([
        {
          'userId': userId,
          'timestamp': Timestamp.now(),
        }
      ]),
    });
  }

  // ─── LEADERBOARD ─────────────────────────────────────────────

  /// Get top users for a unit (unit leaderboard)
  Stream<List<UserProfile>> unitLeaderboard(
      String facilityId, String unitId,
      {int limit = 20}) {
    return _db
        .collection(AppConstants.usersCollection)
        .where('facilityId', isEqualTo: facilityId)
        .where('unitId', isEqualTo: unitId)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => UserProfile.fromFirestore(doc)).toList());
  }

  /// Get top users for a facility
  Stream<List<UserProfile>> facilityLeaderboard(String facilityId,
      {int limit = 50}) {
    return _db
        .collection(AppConstants.usersCollection)
        .where('facilityId', isEqualTo: facilityId)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => UserProfile.fromFirestore(doc)).toList());
  }

  // ─── SEEDING ─────────────────────────────────────────────────

  /// Seed procedures from JSON data (run once during setup)
  Future<void> seedProcedures(List<Map<String, dynamic>> procedures) async {
    final batch = _db.batch();
    for (final proc in procedures) {
      final ref = _db
          .collection(AppConstants.proceduresCollection)
          .doc(proc['id']);
      batch.set(ref, proc, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
