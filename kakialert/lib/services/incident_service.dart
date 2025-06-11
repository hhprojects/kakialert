import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/incident_model.dart';
import 'notification_service.dart';

class IncidentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _incidentsCollection => _firestore.collection('incidents');

  // Create a new incident
  Future<String> createIncident(Incident incident) async {
    try {
      print('Creating incident: ${incident.title}');
      final docRef = await _incidentsCollection.add(incident.toMapForCreation());
      print('Incident created successfully with ID: ${docRef.id}');
      
      // Send notification for new incident
      await NotificationService.sendIncidentNotification(
        incidentType: incident.incident,
        title: incident.title,
        location: incident.location,
        incidentId: docRef.id,
      );
      
      return docRef.id;
    } catch (e) {
      print('Error creating incident: $e');
      throw Exception('Failed to create incident: $e');
    }
  }

  // Get incident by ID
  Future<Incident?> getIncidentById(String id) async {
    try {
      final doc = await _incidentsCollection.doc(id).get();
      if (doc.exists) {
        return Incident.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting incident by ID: $e');
      throw Exception('Failed to get incident: $e');
    }
  }

  // Get all incidents
  Future<List<Incident>> getAllIncidents() async {
    try {
      final snapshot = await _incidentsCollection
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting all incidents: $e');
      throw Exception('Failed to get incidents: $e');
    }
  }

  // Get incidents by user ID
  Future<List<Incident>> getIncidentsByUserId(String userId) async {
    try {
      final snapshot = await _incidentsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting incidents by user ID: $e');
      throw Exception('Failed to get incidents by user: $e');
    }
  }

  // Get incidents by type
  Future<List<Incident>> getIncidentsByType(String incidentType) async {
    try {
      final snapshot = await _incidentsCollection
          .where('incident', isEqualTo: incidentType)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting incidents by type: $e');
      throw Exception('Failed to get incidents by type: $e');
    }
  }

  // Get incidents by date range
  Future<List<Incident>> getIncidentsByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _incidentsCollection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting incidents by date range: $e');
      throw Exception('Failed to get incidents by date range: $e');
    }
  }

  // Get incidents for a specific date (for map display)
  Future<List<Incident>> getIncidentsForDate(DateTime date) async {
    try {
      // Get start and end of the day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _incidentsCollection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
      return snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting incidents for date: $e');
      throw Exception('Failed to get incidents for date: $e');
    }
  }

  // Get incidents within a geographic area (bounding box)
  Future<List<Incident>> getIncidentsInArea(
    double minLat, 
    double maxLat, 
    double minLng, 
    double maxLng
  ) async {
    try {
      final snapshot = await _incidentsCollection
          .where('latitude', isGreaterThanOrEqualTo: minLat)
          .where('latitude', isLessThanOrEqualTo: maxLat)
          .get();
      
      // Filter by longitude in memory since Firestore doesn't support multiple range queries
      final incidents = snapshot.docs
          .map((doc) => Incident.fromFirestore(doc))
          .where((incident) => incident.longitude >= minLng && incident.longitude <= maxLng)
          .toList();
      
      return incidents;
    } catch (e) {
      print('Error getting incidents in area: $e');
      throw Exception('Failed to get incidents in area: $e');
    }
  }

  // Get incidents by cluster ID
  Future<List<Incident>> getIncidentsByCluster(String clusterId) async {
    try {
      final snapshot = await _incidentsCollection
          .where('clusterId', isEqualTo: clusterId)
          .orderBy('createdAt', descending: false) // Oldest first for master
          .get();
      
      return snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting incidents by cluster: $e');
      throw Exception('Failed to get incidents by cluster: $e');
    }
  }

  // Update incident
  Future<void> updateIncident(String id, Map<String, dynamic> data) async {
    try {
      await _incidentsCollection.doc(id).update(data);
      print('Incident updated successfully');
    } catch (e) {
      print('Error updating incident: $e');
      throw Exception('Failed to update incident: $e');
    }
  }

  // Delete incident
  Future<void> deleteIncident(String id) async {
    try {
      await _incidentsCollection.doc(id).delete();
      print('Incident deleted successfully');
    } catch (e) {
      print('Error deleting incident: $e');
      throw Exception('Failed to delete incident: $e');
    }
  }

  // Search incidents by title or description
  Future<List<Incident>> searchIncidents(String query) async {
    try {
      // Note: This is a basic implementation. For better search, consider using Algolia or similar
      final titleResults = await _incidentsCollection
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      final descriptionResults = await _incidentsCollection
          .where('description', isGreaterThanOrEqualTo: query)
          .where('description', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      final allDocs = [...titleResults.docs, ...descriptionResults.docs];
      final uniqueDocs = allDocs.toSet().toList(); // Remove duplicates
      
      return uniqueDocs.map((doc) => Incident.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error searching incidents: $e');
      throw Exception('Failed to search incidents: $e');
    }
  }

  // Get incident statistics
  Future<Map<String, int>> getIncidentStatistics() async {
    try {
      final snapshot = await _incidentsCollection.get();
      final incidents = snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
      
      final stats = <String, int>{};
      for (final incident in incidents) {
        stats[incident.incident] = (stats[incident.incident] ?? 0) + 1;
      }
      
      return stats;
    } catch (e) {
      print('Error getting incident statistics: $e');
      throw Exception('Failed to get incident statistics: $e');
    }
  }

  // Stream of all incidents
  Stream<List<Incident>> getAllIncidentsStream() {
    return _incidentsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
    });
  }

  // Stream of incidents by user ID
  Stream<List<Incident>> getIncidentsByUserIdStream(String userId) {
    return _incidentsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
    });
  }

  // Stream of incidents for a specific date
  Stream<List<Incident>> getIncidentsForDateStream(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _incidentsCollection
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
    });
  }

  // Get recent incidents (last 24 hours)
  Future<List<Incident>> getRecentIncidents() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final snapshot = await _incidentsCollection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday))
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Incident.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting recent incidents: $e');
      throw Exception('Failed to get recent incidents: $e');
    }
  }

  // Count incidents by type for a date range
  Future<Map<String, int>> getIncidentCountByType(DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _incidentsCollection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final incident = Incident.fromFirestore(doc);
        counts[incident.incident] = (counts[incident.incident] ?? 0) + 1;
      }
      
      return counts;
    } catch (e) {
      print('Error getting incident count by type: $e');
      throw Exception('Failed to get incident count by type: $e');
    }
  }
}
