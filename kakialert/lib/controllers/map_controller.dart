import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kakialert/controllers/incident_controller.dart';
import 'package:kakialert/models/incident_model.dart';

class MapController {
  final IncidentController incidentController;
  MapController({required this.incidentController});

  // gets the user's current location
  Future<LatLng?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }

  /* map markers fucnction */
  // Future<Set<Marker>> loadIncidentMarkers({
  //   required Function(Incident) onMarkerTap,
  //   required DateTime selectedDate,
  // }) async {
  //   await incidentController.loadIncidents();
  //   final allIncidents = incidentController.incidents;

  //   // Filter incidents matching the selected date (only the date part)
  //   final incidents =
  //       allIncidents.where((incident) {
  //         try {
  //           final incidentDate = DateTime.parse(incident.dateTime);
  //           return incidentDate.year == selectedDate.year &&
  //               incidentDate.month == selectedDate.month &&
  //               incidentDate.day == selectedDate.day;
  //         } catch (e) {
  //           return false;
  //         }
  //       }).toList();

  //   Set<Marker> markers = {};

  //   for (var i = 0; i < incidents.length; i++) {
  //     final incident = incidents[i];

  //     final assetPath = getAssetForIncident(incident.incident);
  //     final icon = await getMarkerIconFromAsset(assetPath);

  //     final marker = Marker(
  //       markerId: MarkerId('incident_$i'),
  //       position: incident.position,
  //       icon: icon,
  //       onTap: () => onMarkerTap(incident),
  //     );

  //     markers.add(marker);
  //   }

  //   return markers;
  // }
  Future<Set<Marker>> loadIncidentMarkers({
    required Function(Incident) onMarkerTap,
    required DateTime selectedDate,
  }) async {
    // Load incidents from Firestore
    await incidentController.loadIncidents();
    final allIncidents = incidentController.incidents;

    // Filter incidents that match the selected date (ignoring time)
    final incidents =
        allIncidents.where((incident) {
          try {
            final incidentDate = DateTime.parse(incident.datetime.toString());
            return incidentDate.year == selectedDate.year &&
                incidentDate.month == selectedDate.month &&
                incidentDate.day == selectedDate.day;
          } catch (e) {
            // Skip invalid date strings
            return false;
          }
        }).toList();

    // Convert filtered incidents to markers
    Set<Marker> markers = {};

    for (var i = 0; i < incidents.length; i++) {
      final incident = incidents[i];
      final assetPath = getAssetForIncident(incident.incident);
      final icon = await getMarkerIconFromAsset(assetPath);

      final marker = Marker(
        markerId: MarkerId('incident_$i'),
        position: incident.position,
        icon: icon,
        onTap: () => onMarkerTap(incident),
      );

      markers.add(marker);
    }

    return markers;
  }

  // convert png to marker
  Future<BitmapDescriptor> getMarkerIconFromAsset(
    String assetPath, {
    int width = 100,
  }) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ByteData? bytes = await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  String getAssetForIncident(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return 'assets/icons/fire.png';
      case 'medical':
        return 'assets/icons/medical.png';
      case 'accident':
        return 'assets/icons/accident.png';
      case 'violence':
        return 'assets/icons/violence.png';
      case 'rescue':
        return 'assets/icons/rescue.png';
      case 'hdb_facilities':
        return 'assets/icons/hdb.png';
      case 'mrt':
        return 'assets/icons/mrt.png';
      default:
        return 'assets/icons/others.png';
    }
  }

  // Update the marker creation to show cluster information
  Marker _createIncidentMarker(Incident incident, VoidCallback onTap) {
    return Marker(
      markerId: MarkerId(incident.id ?? 'unknown'),
      position: LatLng(incident.latitude, incident.longitude),
      icon: _getCustomMarkerIcon(incident),
      onTap: onTap,
      infoWindow: InfoWindow(
        title: incident.isInCluster 
            ? '${incident.title} (${incident.totalReports} reports)'
            : incident.title,
        snippet: incident.location,
      ),
    );
  }

  // Create custom marker icons with cluster badges
  BitmapDescriptor _getCustomMarkerIcon(Incident incident) {
    // You would create custom marker icons here that show:
    // - Incident type icon
    // - Number badge if it's a cluster
    // - Different colors based on verification count
    
    // For now, return default marker
    return BitmapDescriptor.defaultMarkerWithHue(
      incident.isInCluster ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueRed,
    );
  }
}
