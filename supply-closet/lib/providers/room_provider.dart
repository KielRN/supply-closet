import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import '../models/supply_room.dart';
import '../services/firestore_service.dart';

/// Tracks the currently selected Supply Room on the nurse's floor/unit
/// (e.g., Med 3A North Supply vs Med 3A South Supply) across Finder, Tag,
/// and Profile screens.
class RoomProvider extends ChangeNotifier {
  final FirestoreService _firestore;

  String _selectedRoomId = AppConstants.defaultRoomId;

  RoomProvider({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  String get selectedRoomId => _selectedRoomId;

  void selectRoom(String roomId) {
    if (roomId.trim().isEmpty || _selectedRoomId == roomId) return;
    _selectedRoomId = roomId;
    notifyListeners();
  }

  Future<SupplyRoom> addAndSelectRoom({
    required String facilityId,
    required String unitId,
    required String roomName,
    String? doorCode,
    required String userId,
  }) async {
    final created = await _firestore.createSupplyRoom(
      facilityId: facilityId,
      unitId: unitId,
      roomName: roomName,
      doorCode: doorCode,
      userId: userId,
    );
    _selectedRoomId = created.id;
    notifyListeners();
    return created;
  }
}
