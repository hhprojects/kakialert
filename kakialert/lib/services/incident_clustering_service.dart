import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/incident_model.dart';
import '../services/incident_service.dart';
import '../services/openrouter_service.dart';

class IncidentClusteringService {
  final IncidentService _incidentService = IncidentService();
  final OpenRouterService _aiService = OpenRouterService();

  // Clustering parameters
  static const double MAX_DISTANCE_METERS = 500; // 500m radius
  static const int MAX_TIME_HOURS = 6; // 6 hours window
  static const double SIMILARITY_THRESHOLD = 0.7; // 70% similarity

  /// Find if a new incident should be clustered with existing ones
  Future<String?> findClusterForIncident(Incident newIncident) async {
    try {
      // Get recent incidents within time window
      final recentIncidents = await _getRecentIncidentsInArea(
        newIncident.latitude,
        newIncident.longitude,
        newIncident.datetime ?? DateTime.now(),
      );

      if (recentIncidents.isEmpty) return null;

      // Check each recent incident for clustering potential
      for (final existingIncident in recentIncidents) {
        final shouldCluster = await _shouldClusterIncidents(newIncident, existingIncident);
        if (shouldCluster) {
          // Return the cluster ID (either existing cluster or the incident ID)
          return existingIncident.clusterId ?? existingIncident.id;
        }
      }

      return null; // No cluster found
    } catch (e) {
      print('Error finding cluster: $e');
      return null;
    }
  }

  /// Determine if two incidents should be clustered together
  Future<bool> _shouldClusterIncidents(Incident incident1, Incident incident2) async {
    // 1. Check spatial proximity
    if (!_isWithinDistance(incident1, incident2)) return false;

    // 2. Check temporal proximity
    if (!_isWithinTimeWindow(incident1, incident2)) return false;

    // 3. Check incident type similarity
    if (!_isSameIncidentType(incident1, incident2)) return false;

    // 4. Check content similarity using AI
    final contentSimilarity = await _checkContentSimilarity(incident1, incident2);
    if (contentSimilarity < SIMILARITY_THRESHOLD) return false;

    return true;
  }

  /// Check if incidents are within geographical distance
  bool _isWithinDistance(Incident incident1, Incident incident2) {
    final distance = Geolocator.distanceBetween(
      incident1.latitude,
      incident1.longitude,
      incident2.latitude,
      incident2.longitude,
    );
    return distance <= MAX_DISTANCE_METERS;
  }

  /// Check if incidents are within time window
  bool _isWithinTimeWindow(Incident incident1, Incident incident2) {
    final time1 = incident1.datetime ?? incident1.createdAt ?? DateTime.now();
    final time2 = incident2.datetime ?? incident2.createdAt ?? DateTime.now();
    
    final timeDifference = time1.difference(time2).abs();
    return timeDifference.inHours <= MAX_TIME_HOURS;
  }

  /// Check if incidents are of the same type
  bool _isSameIncidentType(Incident incident1, Incident incident2) {
    return incident1.incident.toLowerCase() == incident2.incident.toLowerCase();
  }

  /// Use AI to check content similarity
  Future<double> _checkContentSimilarity(Incident incident1, Incident incident2) async {
    try {
      final similarityResult = await _aiService.compareIncidentSimilarity(
        incident1: incident1,
        incident2: incident2,
      );
      return similarityResult['similarity'] ?? 0.0;
    } catch (e) {
      print('Error checking content similarity: $e');
      // Fallback to basic text similarity
      return _calculateTextSimilarity(incident1.description, incident2.description);
    }
  }

  /// Basic text similarity calculation (fallback)
  double _calculateTextSimilarity(String text1, String text2) {
    final words1 = text1.toLowerCase().split(' ').toSet();
    final words2 = text2.toLowerCase().split(' ').toSet();
    
    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    
    return union > 0 ? intersection / union : 0.0;
  }

  /// Get recent incidents in the area
  Future<List<Incident>> _getRecentIncidentsInArea(
    double latitude,
    double longitude,
    DateTime referenceTime,
  ) async {
    final incidents = await _incidentService.getAllIncidents();
    
    return incidents.where((incident) {
      final incidentTime = incident.datetime ?? incident.createdAt ?? DateTime.now();
      final timeDiff = referenceTime.difference(incidentTime).abs();
      
      return timeDiff.inHours <= MAX_TIME_HOURS &&
             _isWithinDistance(
               Incident(
                 title: '',
                 incident: '',
                 description: '',
                 location: '',
                 latitude: latitude,
                 longitude: longitude,
                 userId: '',
                 userEmail: '',
                 displayName: '',
               ),
               incident,
             );
    }).toList();
  }

  /// Create or update incident cluster
  Future<void> processIncidentClustering(Incident newIncident, String? clusterId) async {
    if (clusterId == null) {
      // No cluster found, create new incident as potential cluster head
      await _incidentService.createIncident(newIncident);
    } else {
      // Add to existing cluster
      await _addToCluster(newIncident, clusterId);
    }
  }

  /// Add incident to existing cluster
  Future<void> _addToCluster(Incident incident, String clusterId) async {
    // Update the new incident with cluster ID
    final clusteredIncident = incident.copyWith(clusterId: clusterId);
    await _incidentService.createIncident(clusteredIncident);

    // Update cluster statistics
    await _updateClusterStats(clusterId);
  }

  /// Update cluster statistics
  Future<void> _updateClusterStats(String clusterId) async {
    final clusterIncidents = await _incidentService.getIncidentsByCluster(clusterId);
    
    // Update the master incident with aggregated data
    if (clusterIncidents.isNotEmpty) {
      final masterIncident = clusterIncidents.first;
      final stats = _calculateClusterStats(clusterIncidents);
      
      await _incidentService.updateIncident(masterIncident.id!, {
        'clusterSize': clusterIncidents.length,
        'verificationCount': clusterIncidents.length - 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'aggregatedImageUrls': stats['allImageUrls'],
        'contributorIds': stats['contributorIds'],
      });
    }
  }

  Map<String, dynamic> _calculateClusterStats(List<Incident> incidents) {
    final allImageUrls = <String>[];
    final contributorIds = <String>[];
    
    for (final incident in incidents) {
      allImageUrls.addAll(incident.imageUrls);
      if (!contributorIds.contains(incident.userId)) {
        contributorIds.add(incident.userId);
      }
    }
    
    return {
      'allImageUrls': allImageUrls,
      'contributorIds': contributorIds,
    };
  }
} 