import 'package:google_maps_flutter/google_maps_flutter.dart';

class Incident {
  final String incident; //incident name
  final String description; //more details about incident
  final String location; //location of the incident
  String? image; //images of the incident, can be empty
  final String dateTime; //date & time of incident
  final double latitude; //lat position
  final double longitude; //lng position

  Incident({
    required this.incident,
    required this.description,
    required this.location,
    this.image,
    required this.dateTime,
    required this.latitude,
    required this.longitude,
  });

  LatLng get position => LatLng(latitude, longitude);
}
