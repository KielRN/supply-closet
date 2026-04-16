import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/procedure.dart';
import '../services/firestore_service.dart';

class ProcedureProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  List<Procedure> _procedures = [];
  List<Procedure> get procedures => _procedures;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Filtered procedures based on search and category
  List<Procedure> get filteredProcedures {
    var filtered = _procedures;
    if (_selectedCategory != null) {
      filtered =
          filtered.where((p) => p.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    return filtered;
  }

  /// Available categories
  List<String> get categories {
    final cats = _procedures.map((p) => p.category).toSet().toList();
    cats.sort();
    return cats;
  }

  /// Initialize and load procedures (from local seed first, then Firestore)
  Future<void> loadProcedures() async {
    _isLoading = true;
    notifyListeners();

    // Load from local seed JSON for instant UX
    try {
      final raw = await rootBundle.loadString('assets/data/seed_procedures.json');
      final List<dynamic> data = json.decode(raw);
      _procedures = data.map((j) => Procedure.fromJson(j)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Could not load seed procedures: $e');
    }

    // Listen for Firestore updates
    _firestore.proceduresStream().listen((live) {
      if (live.isNotEmpty) {
        _procedures = live;
        notifyListeners();
      }
    });

    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Procedure? getById(String id) {
    try {
      return _procedures.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
