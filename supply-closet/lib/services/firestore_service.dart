import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supply_item.dart';
import '../models/supply_room.dart';
import '../models/supply_bounty.dart';
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
    return _db.collection(AppConstants.proceduresCollection).snapshots().map(
        (snap) => snap.docs
            .map((doc) => Procedure.fromFirestore(doc))
            .where((p) => p.name.toLowerCase().contains(queryLower))
            .toList());
  }

  // ─── SUPPLY ROOMS & INITIATION ───────────────────────────────

  /// Collection reference for all supply rooms on a floor/unit (e.g., Med 3A)
  CollectionReference _roomsCollection(String facilityId, String unitId) {
    return _db
        .collection(AppConstants.facilitiesCollection)
        .doc(facilityId)
        .collection(AppConstants.unitsCollection)
        .doc(unitId)
        .collection(AppConstants.supplyRoomsCollection);
  }

  /// Document reference for a supply room
  DocumentReference _roomRef(String facilityId, String unitId, String roomId) {
    return _roomsCollection(facilityId, unitId).doc(roomId);
  }

  /// Stream all supply rooms on a floor/unit (e.g., Med 3A North & South closets).
  /// Always includes the default primary room (`main`) if no rooms exist yet.
  Stream<List<SupplyRoom>> roomsInUnit(String facilityId, String unitId) {
    return _roomsCollection(facilityId, unitId).snapshots().map((snap) {
      final rooms =
          snap.docs.map((doc) => SupplyRoom.fromFirestore(doc)).toList();
      if (!rooms.any((r) => r.id == AppConstants.defaultRoomId)) {
        rooms.insert(
          0,
          SupplyRoom.uninitiated(
            AppConstants.defaultRoomId,
            name: 'Med 3A · North Supply Rm',
            doorCode: 'RM 3A-102',
          ),
        );
      }
      return rooms;
    });
  }

  /// Create a new supply room on the nurse's floor/unit (e.g., "Med 3A South Closet")
  Future<SupplyRoom> createSupplyRoom({
    required String facilityId,
    required String unitId,
    required String roomName,
    String? doorCode,
    required String userId,
  }) async {
    final cleanName = roomName.trim();
    final slug = cleanName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final roomId =
        slug.isEmpty ? 'room_${DateTime.now().millisecondsSinceEpoch}' : slug;

    final ref = _roomRef(facilityId, unitId, roomId);
    late SupplyRoom created;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        created = SupplyRoom.fromFirestore(snap);
        return;
      }
      created = SupplyRoom(
        id: roomId,
        name: cleanName,
        doorCode: (doorCode != null && doorCode.trim().isNotEmpty)
            ? doorCode.trim().toUpperCase()
            : null,
        isInitiated: false,
        initiatedBy: userId,
        initiatedAt: DateTime.now(),
        hasGaussianSplat: false,
        shelves: SupplyRoom.defaultInitiatedShelves(),
        version: 1,
      );
      tx.set(ref, created.toFirestore());
    });

    return created;
  }

  /// Add a spatial Captain Hint to a supply room (only Room Captain can pin hints)
  Future<void> addCaptainHint({
    required String facilityId,
    required String unitId,
    required String roomId,
    required RoomHint hint,
  }) async {
    final ref = _roomRef(facilityId, unitId, roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final existing = snap.exists
          ? SupplyRoom.fromFirestore(snap)
          : SupplyRoom.uninitiated(roomId);
      final nextVersion = snap.exists ? existing.version + 1 : 1;
      final updatedHints = [...existing.hints, hint];
      final updatedRoom = SupplyRoom(
        id: existing.id,
        name: existing.name,
        doorCode: existing.doorCode,
        isInitiated: existing.isInitiated,
        initiatedBy: existing.initiatedBy ?? hint.captainUid,
        initiatedAt: existing.initiatedAt ?? DateTime.now(),
        hasGaussianSplat: existing.hasGaussianSplat,
        splatAssetName: existing.splatAssetName,
        shelves: existing.shelves.isNotEmpty
            ? existing.shelves
            : SupplyRoom.defaultInitiatedShelves(),
        captainUid: existing.captainUid ?? hint.captainUid,
        captainName: existing.captainName ?? hint.captainName,
        captainAvatar: existing.captainAvatar ?? hint.captainAvatar,
        captainTagCount: existing.captainTagCount,
        tagCountsByUser: existing.tagCountsByUser,
        hints: updatedHints,
        version: nextVersion,
      );
      tx.set(ref, updatedRoom.toFirestore());
    });
  }

  /// Stream a supply room's spatial configuration (shelves, splat status, initiation)
  Stream<SupplyRoom> roomStream(
      String facilityId, String unitId, String roomId) {
    return _roomRef(facilityId, unitId, roomId)
        .snapshots()
        .map((doc) => SupplyRoom.fromFirestore(doc));
  }

  /// Fetch current supply room state once
  Future<SupplyRoom> getRoom(
      String facilityId, String unitId, String roomId) async {
    final doc = await _roomRef(facilityId, unitId, roomId).get();
    return SupplyRoom.fromFirestore(doc);
  }

  /// Register the first measured setup. Spatial measurements stay on the phone.
  /// Returns true only to the client that first changed the room to initiated.
  Future<bool> initiateMeasuredRoom({
    required String facilityId,
    required String unitId,
    required String roomId,
    required String roomName,
    required String userId,
  }) {
    final ref = _roomRef(facilityId, unitId, roomId);
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final existing = snap.data() as Map<String, dynamic>?;
      if (existing?['isInitiated'] == true) return false;
      tx.set(ref, {
        if (!snap.exists) 'name': roomName,
        'isInitiated': true,
        'initiatedBy': userId,
        'initiatedAt': FieldValue.serverTimestamp(),
        'version': ((existing?['version'] as num?)?.toInt() ?? 0) + 1,
      }, SetOptions(merge: true));
      return true;
    });
  }

  /// Initiate a supply room with doorway-anchored 3D shelf geometry and Gaussian Splat state.
  Future<SupplyRoom> initiateRoom({
    required String facilityId,
    required String unitId,
    required String roomId,
    required String roomName,
    String? doorCode,
    required String userId,
    required List<ShelfRack> shelves,
    bool hasGaussianSplat = true,
    String? splatAssetName,
  }) async {
    final ref = _roomRef(facilityId, unitId, roomId);
    late SupplyRoom updatedRoom;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final existing = snap.exists ? SupplyRoom.fromFirestore(snap) : null;
      final currentVersion = existing?.version ?? 0;
      final newVersion = currentVersion + 1;

      updatedRoom = SupplyRoom(
        id: roomId,
        name: roomName,
        doorCode: doorCode ?? existing?.doorCode ?? 'RM 3A-102',
        isInitiated: true,
        initiatedBy: userId,
        initiatedAt: DateTime.now(),
        hasGaussianSplat: hasGaussianSplat,
        splatAssetName: splatAssetName ?? 'room_${roomId}_scan.splat',
        shelves: shelves.isNotEmpty
            ? shelves
            : SupplyRoom.defaultInitiatedShelves(),
        captainUid: existing?.captainUid,
        captainName: existing?.captainName,
        captainAvatar: existing?.captainAvatar,
        captainTagCount: existing?.captainTagCount ?? 0,
        tagCountsByUser: existing?.tagCountsByUser ?? const {},
        hints: existing?.hints ?? const [],
        version: newVersion,
      );

      tx.set(ref, updatedRoom.toFirestore());
    });

    return updatedRoom;
  }

  // ─── SUPPLY BOUNTIES (User-Initiated Quests) ─────────────────

  CollectionReference _bountiesRef(
      String facilityId, String unitId, String roomId) {
    return _roomRef(facilityId, unitId, roomId)
        .collection(AppConstants.bountiesCollection);
  }

  /// Stream open and recently claimed bounties in a room
  Stream<List<SupplyBounty>> bountiesInRoom(
      String facilityId, String unitId, String roomId) {
    return _bountiesRef(facilityId, unitId, roomId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => SupplyBounty.fromFirestore(doc)).toList());
  }

  /// Create a user-initiated Supply Bounty when a needed supply isn't tagged yet
  Future<String> createBounty({
    required String facilityId,
    required String unitId,
    required String roomId,
    required String supplyName,
    String? category,
    String? note,
    int bonusXp = AppConstants.pointsClaimBounty,
    required String userId,
    required String userName,
  }) async {
    final ref = _bountiesRef(facilityId, unitId, roomId);
    final bounty = SupplyBounty(
      id: '',
      supplyName: supplyName.trim(),
      category: category,
      note: note,
      bonusXp: bonusXp,
      status: 'open',
      createdByUid: userId,
      createdByName: userName,
      createdAt: DateTime.now(),
      version: 1,
    );
    final doc = await ref.add(bounty.toFirestore());
    return doc.id;
  }

  /// Claim an open bounty when a nurse locates and tags the supply
  Future<void> claimBounty({
    required String facilityId,
    required String unitId,
    required String roomId,
    required String bountyId,
    required String userId,
    required String userName,
    required String resolvedLocation,
    required String resolvedSupplyId,
  }) async {
    final ref = _bountiesRef(facilityId, unitId, roomId).doc(bountyId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if (data['status'] == 'claimed') return;
      final currentVersion = ((data['version'] ?? 1) as num).toInt();

      tx.update(ref, {
        'status': 'claimed',
        'claimedByUid': userId,
        'claimedByName': userName,
        'claimedAt': Timestamp.now(),
        'resolvedLocation': resolvedLocation,
        'resolvedSupplyId': resolvedSupplyId,
        'version': currentVersion + 1,
      });
    });
  }

  // ─── SUPPLY ITEMS (per facility/unit/room) ───────────────────

  /// Path to a supply room's supplies collection
  CollectionReference _suppliesRef(
      String facilityId, String unitId, String roomId) {
    return _roomRef(facilityId, unitId, roomId)
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

  /// Tag a new supply location (or update existing), and update the room's
  /// per-user tag count so the top tagger automatically becomes Room Captain.
  Future<TagSupplyResult> tagSupply({
    required String facilityId,
    required String unitId,
    required String roomId,
    required String supplyName,
    String? barcode,
    String? category,
    required SupplyLocation location,
    required String userId,
    String? userName,
    String? userAvatar,
    String? bountyId,
  }) async {
    final ref = _suppliesRef(facilityId, unitId, roomId);

    // Resolve 3D coordinates from the room's shelf geometry if x/y/z are 0
    SupplyLocation resolvedLoc = location;
    if (location.x == 0 && location.y == 0 && location.z == 0) {
      final room = await getRoom(facilityId, unitId, roomId);
      resolvedLoc = room.resolveLocation(
        shelf: location.shelf,
        bin: location.bin,
      );
    }

    // Check if this supply already exists (by barcode or name)
    QuerySnapshot existing;
    if (barcode != null) {
      existing = await ref.where('barcode', isEqualTo: barcode).limit(1).get();
    } else {
      existing = await ref.where('name', isEqualTo: supplyName).limit(1).get();
    }

    late String supplyId;
    late TagSupplyAction action;

    if (existing.docs.isNotEmpty) {
      // Update existing — use transaction for atomic update with conflict detection
      final doc = existing.docs.first;
      supplyId = doc.id;
      action = TagSupplyAction.confirmedExisting;
      await _db.runTransaction((tx) async {
        final snap = await tx.get(doc.reference);
        if (!snap.exists) {
          throw Exception('Supply was deleted during update');
        }
        final currentData = snap.data() as Map<String, dynamic>;
        final currentConfidence = (currentData['confidence'] ?? 0.5).toDouble();
        final newConfidence =
            (currentConfidence + AppConstants.confidenceConfirmBoost)
                .clamp(0.0, 1.0);

        // Optimistic concurrency: increment version for conflict detection
        final currentVersion = currentData['version'] ?? 0;

        tx.update(doc.reference, {
          'location': resolvedLoc.toMap(),
          'confidence': newConfidence,
          'lastConfirmed': Timestamp.now(),
          'tagCount': FieldValue.increment(1),
          'taggedByUserIds': FieldValue.arrayUnion([userId]),
          'version': currentVersion + 1,
        });
      });
    } else {
      // New supply tag — include version field for conflict detection
      final item = SupplyItem(
        id: '',
        name: supplyName,
        barcode: barcode,
        category: category,
        location: resolvedLoc,
        confidence: AppConstants.confidenceInitial,
        lastConfirmed: DateTime.now(),
        tagCount: 1,
        taggedByUserIds: [userId],
      );
      final data = item.toFirestore();
      data['version'] = 1;
      final doc = await ref.add(data);
      supplyId = doc.id;
      action = TagSupplyAction.createdNew;
    }

    // Update Room Captain leaderboard for this room (most tags in room = Room Captain)
    bool becameRoomCaptain = false;
    try {
      final roomRef = _roomRef(facilityId, unitId, roomId);
      await _db.runTransaction((tx) async {
        final roomSnap = await tx.get(roomRef);
        final currentRoom = roomSnap.exists
            ? SupplyRoom.fromFirestore(roomSnap)
            : SupplyRoom.uninitiated(roomId);
        final nextVersion = roomSnap.exists ? currentRoom.version + 1 : 1;

        final counts = Map<String, int>.from(currentRoom.tagCountsByUser);
        final myNewCount = (counts[userId] ?? 0) + 1;
        counts[userId] = myNewCount;

        final prevCaptainUid = currentRoom.captainUid;
        final prevCaptainCount = currentRoom.captainTagCount;

        String? nextCaptainUid = prevCaptainUid;
        String? nextCaptainName = currentRoom.captainName;
        String? nextCaptainAvatar = currentRoom.captainAvatar;
        int nextCaptainCount = prevCaptainCount;

        if (prevCaptainUid == null ||
            prevCaptainUid.isEmpty ||
            myNewCount > prevCaptainCount ||
            prevCaptainUid == userId) {
          if (prevCaptainUid != userId) {
            becameRoomCaptain = true;
          }
          nextCaptainUid = userId;
          nextCaptainName = userName ?? 'Room Captain';
          nextCaptainAvatar = userAvatar ?? currentRoom.captainAvatar;
          nextCaptainCount = myNewCount;
        }

        final updatedRoom = SupplyRoom(
          id: currentRoom.id,
          name: currentRoom.name,
          doorCode: currentRoom.doorCode,
          isInitiated: currentRoom.isInitiated,
          initiatedBy: currentRoom.initiatedBy ?? userId,
          initiatedAt: currentRoom.initiatedAt ?? DateTime.now(),
          hasGaussianSplat: currentRoom.hasGaussianSplat,
          splatAssetName: currentRoom.splatAssetName,
          shelves: currentRoom.shelves.isNotEmpty
              ? currentRoom.shelves
              : SupplyRoom.defaultInitiatedShelves(),
          captainUid: nextCaptainUid,
          captainName: nextCaptainName,
          captainAvatar: nextCaptainAvatar,
          captainTagCount: nextCaptainCount,
          tagCountsByUser: counts,
          hints: currentRoom.hints,
          version: nextVersion,
        );

        tx.set(roomRef, updatedRoom.toFirestore());
      });
    } catch (_) {
      // Non-fatal if room captain metadata update encounters a transient error
    }

    // Check if this tag fulfills an explicit or matching open Supply Bounty
    String? claimedBountyId = bountyId;
    if (claimedBountyId == null) {
      final openBounties = await _bountiesRef(facilityId, unitId, roomId)
          .where('status', isEqualTo: 'open')
          .get();
      for (final bDoc in openBounties.docs) {
        final bData = bDoc.data() as Map<String, dynamic>;
        final bName = (bData['supplyName'] ?? '').toString().toLowerCase();
        if (bName.isNotEmpty &&
            (bName == supplyName.toLowerCase() ||
                supplyName.toLowerCase().contains(bName) ||
                bName.contains(supplyName.toLowerCase()))) {
          claimedBountyId = bDoc.id;
          break;
        }
      }
    }

    if (claimedBountyId != null) {
      await claimBounty(
        facilityId: facilityId,
        unitId: unitId,
        roomId: roomId,
        bountyId: claimedBountyId,
        userId: userId,
        userName: userName ?? 'Bounty Hunter',
        resolvedLocation: resolvedLoc.displayLabel,
        resolvedSupplyId: supplyId,
      );
    }

    return TagSupplyResult(
      supplyId: supplyId,
      action: action,
      claimedBountyId: claimedBountyId,
      becameRoomCaptain: becameRoomCaptain,
    );
  }

  /// Report a supply as "not found"
  Future<void> reportNotFound({
    required String facilityId,
    required String unitId,
    required String roomId,
    required String supplyId,
    required String userId,
  }) async {
    final ref = _suppliesRef(facilityId, unitId, roomId).doc(supplyId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Supply was deleted before it could be reported');
      }
      final currentData = snap.data() as Map<String, dynamic>;
      final currentVersion = currentData['version'] ?? 0;
      tx.update(ref, {
        'confidence': FieldValue.increment(-0.15),
        'notFoundReports': FieldValue.arrayUnion([
          {
            'userId': userId,
            'timestamp': Timestamp.now(),
          }
        ]),
        'version': currentVersion + 1,
      });
    });
  }

  // ─── LEADERBOARD ─────────────────────────────────────────────

  /// Get top users for a unit (unit leaderboard)
  Stream<List<UserProfile>> unitLeaderboard(String facilityId, String unitId,
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
      final ref =
          _db.collection(AppConstants.proceduresCollection).doc(proc['id']);
      batch.set(ref, proc, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

enum TagSupplyAction {
  createdNew,
  confirmedExisting,
}

class TagSupplyResult {
  final String supplyId;
  final TagSupplyAction action;
  final String? claimedBountyId;
  final bool becameRoomCaptain;

  const TagSupplyResult({
    required this.supplyId,
    required this.action,
    this.claimedBountyId,
    this.becameRoomCaptain = false,
  });

  bool get createdNew => action == TagSupplyAction.createdNew;
  bool get claimedBounty => claimedBountyId != null;
}
