import 'package:cloud_firestore/cloud_firestore.dart';

/// A supply item tagged in a supply room with its spatial location
class SupplyItem {
  final String id;
  final String name;
  final String? barcode;
  final String? category;
  final SupplyLocation location;
  final double confidence;
  final DateTime lastConfirmed;
  final int tagCount;
  final List<String> taggedByUserIds;

  SupplyItem({
    required this.id,
    required this.name,
    this.barcode,
    this.category,
    required this.location,
    required this.confidence,
    required this.lastConfirmed,
    required this.tagCount,
    required this.taggedByUserIds,
  });

  factory SupplyItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupplyItem(
      id: doc.id,
      name: data['name'] ?? '',
      barcode: data['barcode'],
      category: data['category'],
      location: SupplyLocation.fromMap(data['location'] ?? {}),
      confidence: (data['confidence'] ?? 0.5).toDouble(),
      lastConfirmed:
          (data['lastConfirmed'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tagCount: data['tagCount'] ?? 0,
      taggedByUserIds: List<String>.from(data['taggedByUserIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'barcode': barcode,
      'category': category,
      'location': location.toMap(),
      'confidence': confidence,
      'lastConfirmed': Timestamp.fromDate(lastConfirmed),
      'tagCount': tagCount,
      'taggedByUserIds': taggedByUserIds,
    };
  }

  /// Whether this item's location data is considered reliable
  bool get isReliable => confidence >= 0.6;

  /// Whether this item's location data is stale and needs reconfirmation
  bool get isStale {
    final daysSinceConfirmed = DateTime.now().difference(lastConfirmed).inDays;
    return daysSinceConfirmed > 7;
  }

  SupplyItem copyWith({
    double? confidence,
    DateTime? lastConfirmed,
    int? tagCount,
    List<String>? taggedByUserIds,
    SupplyLocation? location,
  }) {
    return SupplyItem(
      id: id,
      name: name,
      barcode: barcode,
      category: category,
      location: location ?? this.location,
      confidence: confidence ?? this.confidence,
      lastConfirmed: lastConfirmed ?? this.lastConfirmed,
      tagCount: tagCount ?? this.tagCount,
      taggedByUserIds: taggedByUserIds ?? this.taggedByUserIds,
    );
  }
}

/// 3D spatial location of a supply within a supply room
class SupplyLocation {
  final String? shelf; // e.g., "A", "B", "Top"
  final int? bin; // bin number on the shelf
  final double x; // meters from room origin
  final double y; // meters from floor
  final double z; // meters depth

  SupplyLocation({
    this.shelf,
    this.bin,
    required this.x,
    required this.y,
    required this.z,
  });

  factory SupplyLocation.fromMap(Map<String, dynamic> data) {
    return SupplyLocation(
      shelf: data['shelf'],
      bin: data['bin'],
      x: (data['x'] ?? 0).toDouble(),
      y: (data['y'] ?? 0).toDouble(),
      z: (data['z'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shelf': shelf,
      'bin': bin,
      'x': x,
      'y': y,
      'z': z,
    };
  }

  /// Human-readable description: "Shelf B, Bin 3"
  String get displayLabel {
    final parts = <String>[];
    if (shelf != null) parts.add('Shelf $shelf');
    if (bin != null) parts.add('Bin $bin');
    return parts.isNotEmpty ? parts.join(', ') : 'Unknown location';
  }
}
