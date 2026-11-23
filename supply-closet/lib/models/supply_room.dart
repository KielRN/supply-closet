import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'supply_item.dart';

/// Represents a physical supply room's 3D spatial configuration, including
/// whether it has been initiated via doorway scan, its pinned 3D shelf racks,
/// its Gaussian Splat visual layer metadata, its Room Captain (the user who
/// has tagged the most supplies in this room), and spatial Captain Hints.
class SupplyRoom {
  final String id;
  final String name;
  final String? doorCode; // e.g., "3A-102", "Med 3A North"
  final bool isInitiated;
  final String? initiatedBy;
  final DateTime? initiatedAt;
  final bool hasGaussianSplat;
  final String? splatAssetName;
  final List<ShelfRack> shelves;
  final String? captainUid;
  final String? captainName;
  final String? captainAvatar;
  final int captainTagCount;
  final Map<String, int> tagCountsByUser;
  final List<RoomHint> hints;
  final int version;

  const SupplyRoom({
    required this.id,
    required this.name,
    this.doorCode,
    required this.isInitiated,
    this.initiatedBy,
    this.initiatedAt,
    this.hasGaussianSplat = false,
    this.splatAssetName,
    this.shelves = const [],
    this.captainUid,
    this.captainName,
    this.captainAvatar,
    this.captainTagCount = 0,
    this.tagCountsByUser = const {},
    this.hints = const [],
    this.version = 1,
  });

  bool get hasCaptain => captainUid != null && captainUid!.isNotEmpty;

  /// Uninitiated fallback room state when no room document exists in Firestore yet.
  factory SupplyRoom.uninitiated(
    String roomId, {
    String? name,
    String? doorCode,
  }) {
    final defaultName = name ??
        (roomId == 'main'
            ? 'Med 3A · North Supply Rm'
            : roomId
                .split('_')
                .where((w) => w.isNotEmpty)
                .map((w) => w[0].toUpperCase() + w.substring(1))
                .join(' '));
    return SupplyRoom(
      id: roomId,
      name: defaultName,
      doorCode: doorCode ?? (roomId == 'main' ? 'RM 3A-102' : null),
      isInitiated: false,
      hasGaussianSplat: false,
      shelves: const [],
      version: 0,
    );
  }

  factory SupplyRoom.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return SupplyRoom.uninitiated(doc.id);
    }
    final data = doc.data() as Map<String, dynamic>;
    final rawShelves = (data['shelves'] as List<dynamic>?) ?? [];
    final rawHints = (data['hints'] as List<dynamic>?) ?? [];
    final rawCounts =
        (data['tagCountsByUser'] as Map<String, dynamic>?) ?? const {};
    final parsedCounts = <String, int>{};
    rawCounts.forEach((key, value) {
      if (value is num) {
        parsedCounts[key] = value.toInt();
      }
    });

    return SupplyRoom(
      id: doc.id,
      name: data['name'] ?? 'Med 3A · North Supply Rm',
      doorCode: data['doorCode'] as String?,
      isInitiated: data['isInitiated'] == true,
      initiatedBy: data['initiatedBy'] as String?,
      initiatedAt: (data['initiatedAt'] as Timestamp?)?.toDate(),
      hasGaussianSplat: data['hasGaussianSplat'] == true,
      splatAssetName: data['splatAssetName'] as String?,
      shelves: rawShelves
          .map((e) => ShelfRack.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      captainUid: data['captainUid'] as String?,
      captainName: data['captainName'] as String?,
      captainAvatar: data['captainAvatar'] as String?,
      captainTagCount: (data['captainTagCount'] as num?)?.toInt() ?? 0,
      tagCountsByUser: parsedCounts,
      hints: rawHints
          .map((e) => RoomHint.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      version: (data['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'doorCode': doorCode,
      'isInitiated': isInitiated,
      'initiatedBy': initiatedBy,
      'initiatedAt': initiatedAt != null
          ? Timestamp.fromDate(initiatedAt!)
          : FieldValue.serverTimestamp(),
      'hasGaussianSplat': hasGaussianSplat,
      'splatAssetName': splatAssetName,
      'shelves': shelves.map((s) => s.toMap()).toList(),
      'captainUid': captainUid,
      'captainName': captainName,
      'captainAvatar': captainAvatar,
      'captainTagCount': captainTagCount,
      'tagCountsByUser': tagCountsByUser,
      'hints': hints.map((h) => h.toMap()).toList(),
      'version': version,
    };
  }

  /// Find a shelf rack by its ID (e.g. "A", "B", "C")
  ShelfRack? findShelf(String? shelfId) {
    if (shelfId == null || shelfId.trim().isEmpty) return null;
    final normalized = shelfId
        .trim()
        .toUpperCase()
        .replaceAll('SHELF', '')
        .trim();
    for (final s in shelves) {
      if (s.id.toUpperCase() == normalized) return s;
    }
    return null;
  }

  /// Compute a 3D SupplyLocation for a given shelf ID and bin number using
  /// the room's initiated shelf geometry (or sensible defaults if custom shelf).
  SupplyLocation resolveLocation({
    required String? shelf,
    required int? bin,
  }) {
    final cleanShelf = shelf?.trim().toUpperCase();
    final matched = findShelf(cleanShelf);
    if (matched != null) {
      return matched.locationForBin(bin ?? 1);
    }

    // Default geometry fallback based on letter A/B/C/D if custom shelf name
    final defaultRack = ShelfRack.defaultForCode(cleanShelf ?? 'A');
    return defaultRack.locationForBin(bin ?? 1, overrideShelfId: cleanShelf);
  }

  /// Default 3-shelf layout created during a standard doorway room scan.
  static List<ShelfRack> defaultInitiatedShelves() {
    return const [
      ShelfRack(
        id: 'A',
        label: 'Shelf A · Left Wall',
        yawDegrees: -32.0,
        distanceMeters: 2.1,
        rows: 4,
        binsPerRow: 2,
      ),
      ShelfRack(
        id: 'B',
        label: 'Shelf B · Center Back',
        yawDegrees: 0.0,
        distanceMeters: 2.8,
        rows: 4,
        binsPerRow: 2,
      ),
      ShelfRack(
        id: 'C',
        label: 'Shelf C · Right Wall',
        yawDegrees: 34.0,
        distanceMeters: 2.2,
        rows: 4,
        binsPerRow: 2,
      ),
    ];
  }
}

/// A 3D shelf rack pinned relative to the supply room's doorway origin (0,0,0).
class ShelfRack {
  final String id; // e.g., "A", "B", "C"
  final String label; // e.g., "Shelf A · Left Wall"
  final double yawDegrees; // -90 (left) to +90 (right) from doorway center
  final double distanceMeters; // distance from doorway in meters
  final int rows; // number of vertical shelves (default 4)
  final int binsPerRow; // bins per row (default 2 -> 8 bins total)

  const ShelfRack({
    required this.id,
    required this.label,
    required this.yawDegrees,
    required this.distanceMeters,
    this.rows = 4,
    this.binsPerRow = 2,
  });

  int get totalBins => rows * binsPerRow;

  factory ShelfRack.defaultForCode(String code) {
    final upper = code.isEmpty ? 'A' : code[0].toUpperCase();
    switch (upper) {
      case 'A':
        return const ShelfRack(
          id: 'A',
          label: 'Shelf A · Left Wall',
          yawDegrees: -32.0,
          distanceMeters: 2.1,
        );
      case 'B':
        return const ShelfRack(
          id: 'B',
          label: 'Shelf B · Center Back',
          yawDegrees: 0.0,
          distanceMeters: 2.8,
        );
      case 'C':
        return const ShelfRack(
          id: 'C',
          label: 'Shelf C · Right Wall',
          yawDegrees: 34.0,
          distanceMeters: 2.2,
        );
      default:
        return ShelfRack(
          id: upper,
          label: 'Shelf $upper · Aux Cart',
          yawDegrees: 50.0,
          distanceMeters: 1.9,
        );
    }
  }

  factory ShelfRack.fromMap(Map<String, dynamic> map) {
    return ShelfRack(
      id: (map['id'] ?? 'A').toString(),
      label: (map['label'] ?? 'Shelf A').toString(),
      yawDegrees: ((map['yawDegrees'] ?? 0.0) as num).toDouble(),
      distanceMeters: ((map['distanceMeters'] ?? 2.2) as num).toDouble(),
      rows: ((map['rows'] ?? 4) as num).toInt(),
      binsPerRow: ((map['binsPerRow'] ?? 2) as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'yawDegrees': yawDegrees,
      'distanceMeters': distanceMeters,
      'rows': rows,
      'binsPerRow': binsPerRow,
    };
  }

  /// Convert a 1-based bin number into deterministic 3D room coordinates (x,y,z)
  /// relative to the doorway origin (0,0,0).
  SupplyLocation locationForBin(int binNumber, {String? overrideShelfId}) {
    final safeBin = binNumber.clamp(1, math.max(1, totalBins));
    final zeroIdx = safeBin - 1;
    final rowIdx = zeroIdx ~/ binsPerRow; // 0 = top row, rows-1 = bottom row
    final colIdx = zeroIdx % binsPerRow;

    // Slight yaw offset per column so adjacent bins sit side-by-side in 3D
    final colOffsetDeg = (colIdx - (binsPerRow - 1) / 2.0) * 7.5;
    final binYawRad = (yawDegrees + colOffsetDeg) * (math.pi / 180.0);

    final x = double.parse(
        (distanceMeters * math.sin(binYawRad)).toStringAsFixed(2));
    final z = double.parse(
        (distanceMeters * math.cos(binYawRad)).toStringAsFixed(2));

    // Vertical height in meters from floor (0.55m bottom shelf to 1.65m top shelf)
    final rowFraction = rows <= 1 ? 0.5 : (1.0 - (rowIdx / (rows - 1)));
    final y = double.parse((0.55 + rowFraction * 1.10).toStringAsFixed(2));

    return SupplyLocation(
      shelf: overrideShelfId ?? id,
      bin: binNumber,
      x: x,
      y: y,
      z: z,
    );
  }

  /// Human-readable elevation guide for gaming HUD ("Middle Row · Eye Level")
  String elevationLabelForBin(int? binNumber) {
    if (binNumber == null) return 'Eye Level ▲';
    final safeBin = binNumber.clamp(1, math.max(1, totalBins));
    final rowIdx = (safeBin - 1) ~/ binsPerRow;
    if (rowIdx == 0) return 'Top Row · Reach Up ▲';
    if (rowIdx == 1) return 'Upper-Mid · Eye Level ●';
    if (rowIdx == 2) return 'Lower-Mid · Waist Level ●';
    return 'Bottom Row · Low Rack ▼';
  }
}

/// A spatial hint placed at a 3D point/shelf in the room by the Room Captain.
/// Visible to all nurses in both the 3D Gaussian Splat viewer and the AR HUD,
/// displaying the Captain's display name and avatar.
class RoomHint {
  final String id;
  final String text;
  final String shelfId; // "A", "B", "C"
  final int? binNumber;
  final double x;
  final double y;
  final double z;
  final double yawDegrees;
  final String captainUid;
  final String captainName;
  final String? captainAvatar;
  final DateTime createdAt;

  const RoomHint({
    required this.id,
    required this.text,
    required this.shelfId,
    this.binNumber,
    required this.x,
    required this.y,
    required this.z,
    required this.yawDegrees,
    required this.captainUid,
    required this.captainName,
    this.captainAvatar,
    required this.createdAt,
  });

  factory RoomHint.fromMap(Map<String, dynamic> map) {
    final ts = map['createdAt'];
    return RoomHint(
      id: (map['id'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      shelfId: (map['shelfId'] ?? 'A').toString(),
      binNumber: (map['binNumber'] as num?)?.toInt(),
      x: ((map['x'] ?? 0.0) as num).toDouble(),
      y: ((map['y'] ?? 1.2) as num).toDouble(),
      z: ((map['z'] ?? 2.2) as num).toDouble(),
      yawDegrees: ((map['yawDegrees'] ?? 0.0) as num).toDouble(),
      captainUid: (map['captainUid'] ?? '').toString(),
      captainName: (map['captainName'] ?? 'Room Captain').toString(),
      captainAvatar: map['captainAvatar'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'shelfId': shelfId,
      'binNumber': binNumber,
      'x': x,
      'y': y,
      'z': z,
      'yawDegrees': yawDegrees,
      'captainUid': captainUid,
      'captainName': captainName,
      'captainAvatar': captainAvatar,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
