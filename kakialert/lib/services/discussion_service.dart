import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/discussion_model.dart';

class DiscussionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _discussionsCollection => _firestore.collection('discussions');

  // Create a new discussion message
  Future<String> createMessage(DiscussionMessage message) async {
    try {
      print('Creating discussion message for incident: ${message.incidentId}');
      final docRef = await _discussionsCollection.add(message.toMapForCreation());
      
      // If this is a reply, increment the parent message's reply count
      if (message.parentMessageId != null) {
        await _incrementReplyCount(message.parentMessageId!);
      }
      
      print('Discussion message created successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating discussion message: $e');
      throw Exception('Failed to create message: $e');
    }
  }

  // Get message by ID
  Future<DiscussionMessage?> getMessageById(String id) async {
    try {
      final doc = await _discussionsCollection.doc(id).get();
      if (doc.exists) {
        return DiscussionMessage.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting message by ID: $e');
      throw Exception('Failed to get message: $e');
    }
  }

  // Get all top-level messages for an incident (not replies)
  Future<List<DiscussionMessage>> getTopLevelMessages(String incidentId) async {
    try {
      // Simplified query to avoid index requirements
      final snapshot = await _discussionsCollection
          .where('incidentId', isEqualTo: incidentId)
          .orderBy('createdAt', descending: false)
          .get();
      
      // Filter in memory to avoid composite index requirement
      final messages = snapshot.docs
          .map((doc) => DiscussionMessage.fromFirestore(doc))
          .where((message) => message.parentMessageId == null && !message.isDeleted)
          .toList();
      
      return messages;
    } catch (e) {
      print('Error getting top-level messages: $e');
      throw Exception('Failed to get messages: $e');
    }
  }

  // Get replies for a specific message
  Future<List<DiscussionMessage>> getReplies(String parentMessageId) async {
    try {
      // Simplified query to avoid index requirements
      final snapshot = await _discussionsCollection
          .where('parentMessageId', isEqualTo: parentMessageId)
          .orderBy('createdAt', descending: false)
          .get();
      
      // Filter in memory to avoid composite index requirement
      final replies = snapshot.docs
          .map((doc) => DiscussionMessage.fromFirestore(doc))
          .where((message) => !message.isDeleted)
          .toList();
      
      return replies;
    } catch (e) {
      print('Error getting replies: $e');
      throw Exception('Failed to get replies: $e');
    }
  }

  // Get all messages for an incident (both top-level and replies)
  Future<List<DiscussionMessage>> getAllMessages(String incidentId) async {
    try {
      final snapshot = await _discussionsCollection
          .where('incidentId', isEqualTo: incidentId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: false)
          .get();
      
      return snapshot.docs.map((doc) => DiscussionMessage.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting all messages: $e');
      throw Exception('Failed to get all messages: $e');
    }
  }

  // Get messages by user ID
  Future<List<DiscussionMessage>> getMessagesByUser(String userId) async {
    try {
      final snapshot = await _discussionsCollection
          .where('senderId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => DiscussionMessage.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting messages by user: $e');
      throw Exception('Failed to get user messages: $e');
    }
  }

  // Update message content
  Future<void> updateMessage(String messageId, String newContent) async {
    try {
      await _discussionsCollection.doc(messageId).update({
        'message': newContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
      print('Message updated successfully: $messageId');
    } catch (e) {
      print('Error updating message: $e');
      throw Exception('Failed to update message: $e');
    }
  }

  // Soft delete message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _discussionsCollection.doc(messageId).update({
        'isDeleted': true,
        'message': '[deleted]',
      });
      print('Message soft deleted successfully: $messageId');
    } catch (e) {
      print('Error deleting message: $e');
      throw Exception('Failed to delete message: $e');
    }
  }

  // Like/Unlike a message
  Future<void> toggleLike(String messageId, String userId) async {
    try {
      final doc = await _discussionsCollection.doc(messageId).get();
      if (!doc.exists) throw Exception('Message not found');
      
      final message = DiscussionMessage.fromFirestore(doc);
      List<String> updatedLikes = List.from(message.likes);
      
      if (updatedLikes.contains(userId)) {
        // Unlike
        updatedLikes.remove(userId);
      } else {
        // Like
        updatedLikes.add(userId);
      }
      
      await _discussionsCollection.doc(messageId).update({
        'likes': updatedLikes,
      });
      
      print('Message like toggled successfully: $messageId');
    } catch (e) {
      print('Error toggling like: $e');
      throw Exception('Failed to toggle like: $e');
    }
  }

  // Increment reply count for a parent message
  Future<void> _incrementReplyCount(String parentMessageId) async {
    try {
      await _discussionsCollection.doc(parentMessageId).update({
        'replyCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing reply count: $e');
      // Don't throw error for this non-critical operation
    }
  }

  // Decrement reply count for a parent message
  Future<void> _decrementReplyCount(String parentMessageId) async {
    try {
      await _discussionsCollection.doc(parentMessageId).update({
        'replyCount': FieldValue.increment(-1),
      });
    } catch (e) {
      print('Error decrementing reply count: $e');
      // Don't throw error for this non-critical operation
    }
  }

  // Search messages by content
  Future<List<DiscussionMessage>> searchMessages(String incidentId, String query) async {
    try {
      final snapshot = await _discussionsCollection
          .where('incidentId', isEqualTo: incidentId)
          .where('message', isGreaterThanOrEqualTo: query)
          .where('message', isLessThanOrEqualTo: query + '\uf8ff')
          .where('isDeleted', isEqualTo: false)
          .get();
      
      return snapshot.docs.map((doc) => DiscussionMessage.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error searching messages: $e');
      throw Exception('Failed to search messages: $e');
    }
  }

  // Get message count for an incident
  Future<int> getMessageCount(String incidentId) async {
    try {
      final snapshot = await _discussionsCollection
          .where('incidentId', isEqualTo: incidentId)
          .where('isDeleted', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting message count: $e');
      return 0;
    }
  }

  // Stream of top-level messages for real-time updates
  Stream<List<DiscussionMessage>> getTopLevelMessagesStream(String incidentId) {
    return _discussionsCollection
        .where('incidentId', isEqualTo: incidentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      // Filter in memory to avoid composite index requirement
      return snapshot.docs
          .map((doc) => DiscussionMessage.fromFirestore(doc))
          .where((message) => message.parentMessageId == null && !message.isDeleted)
          .toList();
    });
  }

  // Stream of replies for a specific message
  Stream<List<DiscussionMessage>> getRepliesStream(String parentMessageId) {
    return _discussionsCollection
        .where('parentMessageId', isEqualTo: parentMessageId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      // Filter in memory to avoid composite index requirement
      return snapshot.docs
          .map((doc) => DiscussionMessage.fromFirestore(doc))
          .where((message) => !message.isDeleted)
          .toList();
    });
  }

  // Stream of all messages for an incident
  Stream<List<DiscussionMessage>> getAllMessagesStream(String incidentId) {
    return _discussionsCollection
        .where('incidentId', isEqualTo: incidentId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => DiscussionMessage.fromFirestore(doc)).toList();
    });
  }

  // Get recent messages across all incidents (for activity feed)
  Future<List<DiscussionMessage>> getRecentMessages({int limit = 50}) async {
    try {
      final snapshot = await _discussionsCollection
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => DiscussionMessage.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting recent messages: $e');
      throw Exception('Failed to get recent messages: $e');
    }
  }

  // Get messages with pagination
  Future<List<DiscussionMessage>> getMessagesWithPagination(
    String incidentId, {
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      Query query = _discussionsCollection
          .where('incidentId', isEqualTo: incidentId)
          .where('parentMessageId', isNull: true)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: false)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => DiscussionMessage.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting messages with pagination: $e');
      throw Exception('Failed to get messages: $e');
    }
  }

  // Get discussion statistics for an incident
  Future<Map<String, dynamic>> getDiscussionStats(String incidentId) async {
    try {
      final snapshot = await _discussionsCollection
          .where('incidentId', isEqualTo: incidentId)
          .where('isDeleted', isEqualTo: false)
          .get();

      final messages = snapshot.docs.map((doc) => DiscussionMessage.fromFirestore(doc)).toList();
      
      final topLevelCount = messages.where((m) => m.isTopLevel).length;
      final replyCount = messages.where((m) => m.isReply).length;
      final uniqueUsers = messages.map((m) => m.senderId).toSet().length;
      final totalLikes = messages.fold<int>(0, (sum, m) => sum + m.likeCount);
      
      return {
        'totalMessages': messages.length,
        'topLevelMessages': topLevelCount,
        'replies': replyCount,
        'uniqueParticipants': uniqueUsers,
        'totalLikes': totalLikes,
      };
    } catch (e) {
      print('Error getting discussion stats: $e');
      return {};
    }
  }
} 