import 'package:cloud_firestore/cloud_firestore.dart';

/// A nursing procedure with its required supply checklist
class Procedure {
  final String id;
  final String name;
  final String category;
  final String? description;
  final List<ProcedureSupply> supplies;
  final String? iconName;

  Procedure({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.supplies,
    this.iconName,
  });

  factory Procedure.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Procedure(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'General',
      description: data['description'],
      supplies: (data['supplies'] as List<dynamic>? ?? [])
          .map((s) => ProcedureSupply.fromMap(s as Map<String, dynamic>))
          .toList(),
      iconName: data['iconName'],
    );
  }

  factory Procedure.fromJson(Map<String, dynamic> json) {
    return Procedure(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'General',
      description: json['description'],
      supplies: (json['supplies'] as List<dynamic>? ?? [])
          .map((s) => ProcedureSupply.fromMap(s as Map<String, dynamic>))
          .toList(),
      iconName: json['iconName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'supplies': supplies.map((s) => s.toMap()).toList(),
      'iconName': iconName,
    };
  }

  int get totalSupplies => supplies.length;
}

/// A single supply item required for a procedure
class ProcedureSupply {
  final String name;
  final String? size;
  final int quantity;
  final bool isOptional;
  final String? notes;

  ProcedureSupply({
    required this.name,
    this.size,
    this.quantity = 1,
    this.isOptional = false,
    this.notes,
  });

  factory ProcedureSupply.fromMap(Map<String, dynamic> data) {
    return ProcedureSupply(
      name: data['name'] ?? '',
      size: data['size'],
      quantity: data['quantity'] ?? 1,
      isOptional: data['isOptional'] ?? false,
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'size': size,
      'quantity': quantity,
      'isOptional': isOptional,
      'notes': notes,
    };
  }

  /// Display string: "Foley Catheter Kit (16Fr) x1"
  String get displayName {
    final buffer = StringBuffer(name);
    if (size != null) buffer.write(' ($size)');
    if (quantity > 1) buffer.write(' x$quantity');
    if (isOptional) buffer.write(' [optional]');
    return buffer.toString();
  }
}
