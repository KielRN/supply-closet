import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  UserProfile? get profile => _profile;
  bool get isLoggedIn => _authService.currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get firebaseUser => _authService.currentUser;

  AuthProvider() {
    // Listen for auth state changes
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        _profile = await _authService.getCurrentProfile();
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return _profile != null;
    } catch (e) {
      _error = 'Sign-in failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateFacilityAndUnit({
    required String facilityId,
    required String facilityName,
    required String unitId,
    required String unitName,
  }) async {
    await _authService.updateFacilityAndUnit(
      facilityId: facilityId,
      facilityName: facilityName,
      unitId: unitId,
      unitName: unitName,
    );
    _profile = _profile?.copyWith(
      facilityId: facilityId,
      facilityName: facilityName,
      unitId: unitId,
      unitName: unitName,
    );
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    _profile = await _authService.getCurrentProfile();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _profile = null;
    notifyListeners();
  }
}
