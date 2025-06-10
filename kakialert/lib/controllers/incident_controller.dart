import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakialert/models/incident_model.dart';
import '../services/incident_service.dart';

class IncidentController {
  final IncidentService _incidentService = IncidentService();
  List<Incident> incidents = [];

  // Load all incidents
  Future<void> loadIncidents() async {
    try {
      incidents = await _incidentService.getAllIncidents();
    } catch (e) {
      print('Error loading incidents in controller: $e');
      incidents = [];
    }
  }

  // Load incidents for a specific date
  Future<void> loadIncidentsForDate(DateTime date) async {
    try {
      incidents = await _incidentService.getIncidentsForDate(date);
    } catch (e) {
      print('Error loading incidents for date in controller: $e');
      incidents = [];
    }
  }

  // Get incidents by type
  Future<List<Incident>> getIncidentsByType(String type) async {
    try {
      return await _incidentService.getIncidentsByType(type);
    } catch (e) {
      print('Error getting incidents by type in controller: $e');
      return [];
    }
  }

  // Get incidents by user
  Future<List<Incident>> getIncidentsByUser(String userId) async {
    try {
      return await _incidentService.getIncidentsByUserId(userId);
    } catch (e) {
      print('Error getting incidents by user in controller: $e');
      return [];
    }
  }

  // Create new incident
  Future<String?> createIncident(Incident incident) async {
    try {
      final incidentId = await _incidentService.createIncident(incident);
      // Reload incidents to include the new one
      await loadIncidents();
      return incidentId;
    } catch (e) {
      print('Error creating incident in controller: $e');
      return null;
    }
  }

  // Update incident
  Future<bool> updateIncident(String id, Map<String, dynamic> data) async {
    try {
      await _incidentService.updateIncident(id, data);
      // Reload incidents to reflect changes
      await loadIncidents();
      return true;
    } catch (e) {
      print('Error updating incident in controller: $e');
      return false;
    }
  }

  // Delete incident
  Future<bool> deleteIncident(String id) async {
    try {
      await _incidentService.deleteIncident(id);
      // Remove from local list
      incidents.removeWhere((incident) => incident.id == id);
      return true;
    } catch (e) {
      print('Error deleting incident in controller: $e');
      return false;
    }
  }

  // Search incidents
  Future<List<Incident>> searchIncidents(String query) async {
    try {
      return await _incidentService.searchIncidents(query);
    } catch (e) {
      print('Error searching incidents in controller: $e');
      return [];
    }
  }

  // Get incident statistics
  Future<Map<String, int>> getIncidentStatistics() async {
    try {
      return await _incidentService.getIncidentStatistics();
    } catch (e) {
      print('Error getting incident statistics in controller: $e');
      return {};
    }
  }

  // Get recent incidents
  Future<List<Incident>> getRecentIncidents() async {
    try {
      return await _incidentService.getRecentIncidents();
    } catch (e) {
      print('Error getting recent incidents in controller: $e');
      return [];
    }
  }

  // Get incidents in geographic area
  Future<List<Incident>> getIncidentsInArea(
    double minLat, 
    double maxLat, 
    double minLng, 
    double maxLng
  ) async {
    try {
      return await _incidentService.getIncidentsInArea(minLat, maxLat, minLng, maxLng);
    } catch (e) {
      print('Error getting incidents in area in controller: $e');
      return [];
    }
  }
}
