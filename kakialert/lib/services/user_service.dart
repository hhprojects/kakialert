import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Get current Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  // Create user document in Firestore
  Future<void> createUser(UserModel user) async {
    try {
      print('Creating user document for UID: ${user.uid}');
      await _usersCollection.doc(user.uid).set(user.toMapForCreation());
      print('User document created successfully for UID: ${user.uid}');
    } catch (e) {
      print('Error creating user document: $e');
      throw Exception('Failed to create user profile: $e');
    }
  }

  // Get user by UID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      throw Exception('Failed to get user data: $e');
    }
  }

  // Get current user data
  Future<UserModel?> getCurrentUser() async {
    final currentUser = currentFirebaseUser;
    if (currentUser == null) return null;
    
    return await getUserById(currentUser.uid);
  }

  // Get current user data as Map (for backward compatibility)
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final currentUser = currentFirebaseUser;
    if (currentUser == null) return null;
    
    try {
      final doc = await _usersCollection.doc(currentUser.uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }

  // Update user data
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _usersCollection.doc(uid).update(data);
      print('User data updated successfully for UID: $uid');
    } catch (e) {
      print('Error updating user data: $e');
      throw Exception('Failed to update user data: $e');
    }
  }

  // Update current user's last sign in time
  Future<void> updateLastSignIn() async {
    final currentUser = currentFirebaseUser;
    if (currentUser == null) return;

    try {
      await _usersCollection.doc(currentUser.uid).update({
        'lastSignIn': FieldValue.serverTimestamp(),
      });
      print('Last sign in updated for user: ${currentUser.uid}');
    } catch (e) {
      print('Error updating last sign in: $e');
      // Don't throw error for this non-critical operation
    }
  }

  // Update user display name
  Future<void> updateDisplayName(String uid, String displayName) async {
    try {
      await _usersCollection.doc(uid).update({
        'displayName': displayName,
      });
      print('Display name updated for user: $uid');
    } catch (e) {
      print('Error updating display name: $e');
      throw Exception('Failed to update display name: $e');
    }
  }

  // Delete user document
  Future<void> deleteUser(String uid) async {
    try {
      await _usersCollection.doc(uid).delete();
      print('User document deleted for UID: $uid');
    } catch (e) {
      print('Error deleting user document: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  // Check if user exists
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('Error checking if user exists: $e');
      return false;
    }
  }

  // Get all users (admin function)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _usersCollection.get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting all users: $e');
      throw Exception('Failed to get users: $e');
    }
  }

  // Search users by display name
  Future<List<UserModel>> searchUsersByDisplayName(String query) async {
    try {
      final snapshot = await _usersCollection
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error searching users: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  // Stream of current user data
  Stream<UserModel?> getCurrentUserStream() {
    final currentUser = currentFirebaseUser;
    if (currentUser == null) {
      return Stream.value(null);
    }
    
    return _usersCollection.doc(currentUser.uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Stream of all users
  Stream<List<UserModel>> getAllUsersStream() {
    return _usersCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }
}
