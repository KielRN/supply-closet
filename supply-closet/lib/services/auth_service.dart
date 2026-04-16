import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../config/constants.dart';

/// Handles Firebase Authentication and user profile management
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Current Firebase user (null if not signed in)
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  Future<UserProfile?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      // Get auth credentials
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return null;

      // Create or update user profile in Firestore
      final profile = await _getOrCreateProfile(user);
      return profile;
    } catch (e) {
      print('Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Get existing profile or create a new one
  Future<UserProfile> _getOrCreateProfile(User user) async {
    final docRef = _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      // Update last active timestamp
      await docRef.update({
        'lastActive': Timestamp.now(),
        'displayName': user.displayName ?? 'Nurse',
        'photoUrl': user.photoURL,
      });
      return UserProfile.fromFirestore(doc);
    }

    // New user — create profile
    final profile = UserProfile(
      uid: user.uid,
      displayName: user.displayName ?? 'Nurse',
      email: user.email,
      photoUrl: user.photoURL,
    );

    await docRef.set(profile.toFirestore());
    return profile;
  }

  /// Get the current user's profile from Firestore
  Future<UserProfile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .get();

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
}
