import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'user_service.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is logged in
  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(displayName);

      // Create user document in Firestore using UserService
      if (userCredential.user != null) {
        final userModel = UserModel(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? email,
          displayName: displayName,
        );
        await _userService.createUser(userModel);
      }

      return userCredential;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Error signing out: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Update user's last sign in time
  Future<void> updateLastSignIn() async {
    await _userService.updateLastSignIn();
  }

  // Get user data from Firestore (for backward compatibility)
  Future<Map<String, dynamic>?> getUserData() async {
    return await _userService.getCurrentUserData();
  }

  // Get user model
  Future<UserModel?> getUserModel() async {
    return await _userService.getCurrentUser();
  }

  // Legacy method - kept for backward compatibility
  Future<void> _createUserDocument(User user, String displayName) async {
    final userModel = UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: displayName,
    );
    await _userService.createUser(userModel);
  }
}