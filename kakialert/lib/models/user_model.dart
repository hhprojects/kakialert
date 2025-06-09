import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final DateTime? createdAt;
  final DateTime? lastSignIn;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.createdAt,
    this.lastSignIn,
  });

  // Factory constructor to create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      lastSignIn: data['lastSignIn'] != null 
          ? (data['lastSignIn'] as Timestamp).toDate()
          : null,
    );
  }

  // Factory constructor to create UserModel from Map
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.parse(data['createdAt']))
          : null,
      lastSignIn: data['lastSignIn'] != null 
          ? (data['lastSignIn'] is Timestamp 
              ? (data['lastSignIn'] as Timestamp).toDate()
              : DateTime.parse(data['lastSignIn']))
          : null,
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'lastSignIn': lastSignIn != null ? Timestamp.fromDate(lastSignIn!) : FieldValue.serverTimestamp(),
    };
  }

  // Convert UserModel to Map for creation (with server timestamps)
  Map<String, dynamic> toMapForCreation() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSignIn': FieldValue.serverTimestamp(),
    };
  }

  // Copy with method for updating user data
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? lastSignIn,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      lastSignIn: lastSignIn ?? this.lastSignIn,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, createdAt: $createdAt, lastSignIn: $lastSignIn)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
} 