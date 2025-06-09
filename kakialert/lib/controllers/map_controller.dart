import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  Future<Set<Marker>> loadIncidentMarkers({
    required Function(Incident) onMarkerTap,
    required DateTime selectedDate, // Pass this into the function
  }) async {
    await incidentController.loadIncidents();
    final allIncidents = incidentController.incidents;

    // Format selectedDate to "YYYY-MM-DD"
    final selectedDateString = selectedDate.toIso8601String().substring(0, 10);

    // Filter incidents that match the selected date
    final incidents =
        allIncidents.where((incident) {
          if (incident.dateTime.isEmpty) return false;
          return incident.dateTime.startsWith(selectedDateString);
        }).toList();

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
}
