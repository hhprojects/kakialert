import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakialert/models/incident.dart';

class IncidentController {
  List<Incident> incidents = [];

  Future<void> loadIncidents() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('incidents').get();

    incidents =
        snapshot.docs.map((doc) {
          final data = doc.data();
          return Incident(
            incident: data['incident'] ?? '',
            description: data['description'] ?? '',
            location: data['location'] ?? '',
            dateTime: data['dateTime'] ?? '',
            latitude: (data['latitude'] ?? 0).toDouble(),
            longitude: (data['longitude'] ?? 0).toDouble(),
          );
        }).toList();
  }

  // test data
  /*List<Incident> testIncidents = [
    Incident(
      incident: "Fire",
      description: "A fire broke out at the industrial area.",
      location: "123 Industrial Road, Singapore",
      dateTime: "2025-06-02 14:30",
      latitude: 1.4090,
      longitude: 103.7970,
    ),
    Incident(
      incident: "Medical",
      description: "Heavy rainfall caused flooding in several streets.",
      location: "456 River Valley Road, Singapore",
      dateTime: "2025-06-02 10:00",
      latitude: 1.4390,
      longitude: 103.7970,
    ),
    Incident(
      incident: "Accident",
      description: "Two vehicles collided at the junction.",
      location: "789 Orchard Road, Singapore",
      dateTime: "2025-06-01 18:15",
      latitude: 1.4290,
      longitude: 103.7970,
    ),
    Incident(
      incident: "Violence",
      description: "Power outage reported in multiple housing units.",
      location: "101 Bukit Batok Street, Singapore",
      dateTime: "2025-06-01 22:00",
      latitude: 1.3900,
      longitude: 103.7970,
    ),
  ];*/
}
