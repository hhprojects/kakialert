import 'package:cloud_firestore/cloud_firestore.dart';

class DiscussionMessage {
  final String? id; // Document ID from Firestore
  final String incidentId; // ID of the incident being discussed
  final String senderId; // User ID of the sender
  final String senderName; // Display name of the sender
  final String senderEmail; // Email of the sender (optional)
  final String message; // The message content
  final DateTime? createdAt; // When the message was created
  final DateTime? editedAt; // When the message was last edited
  final bool isEdited; // Whether the message has been edited
  final String? parentMessageId; // ID of parent message (for replies)
  final int replyCount; // Number of replies to this message
  final List<String> likes; // List of user IDs who liked this message
  final bool isDeleted; // Soft delete flag

  DiscussionMessage({
    this.id,
    required this.incidentId,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.message,
    this.createdAt,
    this.editedAt,
    this.isEdited = false,
    this.parentMessageId,
    this.replyCount = 0,
    this.likes = const [],
    this.isDeleted = false,
  });

  // Factory constructor to create DiscussionMessage from Firestore document
  factory DiscussionMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DiscussionMessage(
      id: doc.id,
      incidentId: data['incidentId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Anonymous',
      senderEmail: data['senderEmail'] ?? '',
      message: data['message'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      editedAt: data['editedAt'] != null 
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      isEdited: data['isEdited'] ?? false,
      parentMessageId: data['parentMessageId'],
      replyCount: data['replyCount'] ?? 0,
      likes: List<String>.from(data['likes'] ?? []),
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  // Factory constructor to create DiscussionMessage from Map
  factory DiscussionMessage.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return DiscussionMessage(
      id: documentId ?? data['id'],
      incidentId: data['incidentId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Anonymous',
      senderEmail: data['senderEmail'] ?? '',
      message: data['message'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(data['createdAt'].toString()))
          : null,
      editedAt: data['editedAt'] != null 
          ? (data['editedAt'] is Timestamp 
              ? (data['editedAt'] as Timestamp).toDate()
              : DateTime.tryParse(data['editedAt'].toString()))
          : null,
      isEdited: data['isEdited'] ?? false,
      parentMessageId: data['parentMessageId'],
      replyCount: data['replyCount'] ?? 0,
      likes: List<String>.from(data['likes'] ?? []),
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  // Convert DiscussionMessage to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'senderId': senderId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'message': message,
      'createdAt': createdAt != null 
          ? Timestamp.fromDate(createdAt!) 
          : FieldValue.serverTimestamp(),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'isEdited': isEdited,
      'parentMessageId': parentMessageId,
      'replyCount': replyCount,
      'likes': likes,
      'isDeleted': isDeleted,
    };
  }

  // Convert DiscussionMessage to Map for creation (with server timestamps)
  Map<String, dynamic> toMapForCreation() {
    return {
      'incidentId': incidentId,
      'senderId': senderId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'isEdited': false,
      'parentMessageId': parentMessageId,
      'replyCount': 0,
      'likes': [],
      'isDeleted': false,
    };
  }

  // Check if this is a top-level message (not a reply)
  bool get isTopLevel => parentMessageId == null;

  // Check if this is a reply
  bool get isReply => parentMessageId != null;

  // Get like count
  int get likeCount => likes.length;

  // Check if user has liked this message
  bool isLikedBy(String userId) => likes.contains(userId);

  // Get formatted time since creation
  String get timeAgo {
    if (createdAt == null) return 'Unknown time';
    
    final now = DateTime.now();
    final difference = now.difference(createdAt!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
    }
  }

  // Copy with method for updating message data
  DiscussionMessage copyWith({
    String? id,
    String? incidentId,
    String? senderId,
    String? senderName,
    String? senderEmail,
    String? message,
    DateTime? createdAt,
    DateTime? editedAt,
    bool? isEdited,
    String? parentMessageId,
    int? replyCount,
    List<String>? likes,
    bool? isDeleted,
  }) {
    return DiscussionMessage(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      isEdited: isEdited ?? this.isEdited,
      parentMessageId: parentMessageId ?? this.parentMessageId,
      replyCount: replyCount ?? this.replyCount,
      likes: likes ?? this.likes,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String toString() {
    return 'DiscussionMessage(id: $id, incidentId: $incidentId, senderName: $senderName, message: ${message.substring(0, message.length > 50 ? 50 : message.length)}...)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscussionMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 