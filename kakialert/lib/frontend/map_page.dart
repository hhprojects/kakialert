import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // location identifiers
  LatLng? currentP = LatLng(1.3447, 103.6963);
  LatLng? _initialCameraTarget = LatLng(1.3447, 103.6963);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _initialCameraTarget ?? currentP!,
          zoom: 14,
        ),
        markers: {
          Marker(
            markerId: MarkerId("_currentLocation"),
            icon: BitmapDescriptor.defaultMarker,
            position: currentP!,
          ),
        },
      ),
    );
  }
}
