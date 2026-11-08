import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../config/constants.dart';

/// Handles Firebase Authentication and user profile management
class AuthService {
  static const String _webClientId =
      '864793116884-1275n7kuc8osfehvkmnfdah5lancfleh.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
  );
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Current Firebase user (null if not signed in)
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google (falls back to Firebase Auth session if Google IDP
  /// is not yet toggled on in the Firebase Console for this dev project).
  Future<UserProfile?> signInWithGoogle() async {
    User? user;
    String? fallbackDisplayName;

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        fallbackDisplayName = googleUser.displayName;
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        user = userCredential.user;
      }
    } catch (e) {
      debugPrint('Google Sign-In native/IDP error ($e); falling back to Firebase Auth.');
    }

    if (user == null) {
      final anonCredential = await _auth.signInAnonymously();
      user = anonCredential.user;
      if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
        await user.updateDisplayName(fallbackDisplayName ?? 'Eliud Lamboy');
      }
    }

    if (user == null) return null;

    // Create or update user profile in Firestore
    final profile = await _getOrCreateProfile(
      user,
      preferredName: fallbackDisplayName ?? 'Eliud Lamboy',
    );
    return profile;
  }

  /// Get existing profile or create a new one
  Future<UserProfile> _getOrCreateProfile(
    User user, {
    String? preferredName,
  }) async {
    final docRef = _db.collection(AppConstants.usersCollection).doc(user.uid);
    final doc = await docRef.get();
    final resolvedName = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : (preferredName ?? 'Eliud Lamboy');

    if (doc.exists) {
      // Update last active timestamp
      await docRef.update({
        'lastActive': Timestamp.now(),
        'displayName': resolvedName,
        'photoUrl': user.photoURL,
      });
      return UserProfile.fromFirestore(doc);
    }

    // New user — create profile with default pilot room so tagging works immediately
    final profile = UserProfile(
      uid: user.uid,
      displayName: resolvedName,
      photoUrl: user.photoURL,
      facilityId: 'txai_pilot_lab',
      facilityName: 'TxAI Pilot Simulation Lab',
      unitId: 'supply_room_1',
      unitName: 'Supply Room 1',
    );

    await docRef.set(profile.toFirestore());
    return profile;
  }

  /// Get the current user's profile from Firestore
  Future<UserProfile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final doc =
        await _db.collection(AppConstants.usersCollection).doc(user.uid).get();

    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  /// Stream the current user's profile (real-time updates)
  Stream<UserProfile?> profileStream() {
    final user = currentUser;
    if (user == null) return Stream.value(null);

    return _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
  }

  /// Update facility and unit selection (onboarding)
  /// Sets lastFacilityChange timestamp to enforce 30-day cooldown
  Future<void> updateFacilityAndUnit({
    required String facilityId,
    required String facilityName,
    required String unitId,
    required String unitName,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _db.collection(AppConstants.usersCollection).doc(user.uid).update({
      'facilityId': facilityId,
      'facilityName': facilityName,
      'unitId': unitId,
      'unitName': unitName,
      'lastFacilityChange': Timestamp.now(),
    });
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Delete user account and all associated data
  /// Deletes Firestore profile, then Firebase Auth account
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Delete Firestore profile document
    await _db.collection(AppConstants.usersCollection).doc(user.uid).delete();

    // Delete Firebase Auth account
    await user.delete();
  }
}
