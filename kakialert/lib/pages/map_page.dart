import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kakialert/controllers/incident_controller.dart';
import 'package:kakialert/controllers/map_controller.dart';
import 'package:kakialert/models/incident_model.dart';
import 'package:kakialert/utils/TColorTheme.dart';

class MapPage extends StatefulWidget {
  final VoidCallback onNavigateToForum; //
  //const MapPage({super.key});
  const MapPage({Key? key, required this.onNavigateToForum}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  //variables
  LatLng? currentP;
  Incident? selectedIncident;
  Set<Marker> incidentMarkers = {};
  DateTime selectedDate = DateTime.now();

  //controllers
  final mapController = MapController(incidentController: IncidentController());

  //conditional helpers
  bool showMarkerCard = false;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          currentP == null
              ? Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  buildGoogleMap(),
                  buildAppBar(),
                  if (showMarkerCard) buildMarkerCard(),
                ],
              ),
    );
  }

  // widget builders
  Widget buildAppBar() {
    final String formattedDate =
        "${selectedDate.day.toString().padLeft(2, '0')}/"
        "${selectedDate.month.toString().padLeft(2, '0')}/"
        "${selectedDate.year}";

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        color: TColorTheme.primaryRed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center, // Centered horizontally
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12), // spacing between text and icon
                  IconButton(
                    icon: const Icon(Icons.calendar_today, color: Colors.white),
                    onPressed: () async {
                      final DateTime today = DateTime.now();

                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: today,
                      );

                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });

                        await loadMarkers();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  GoogleMap buildGoogleMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: currentP!, zoom: 14),
      markers: {
        Marker(
          markerId: MarkerId("_currentLocation"),
          icon: BitmapDescriptor.defaultMarker,
          position: currentP!,
        ),
        ...incidentMarkers, // include markers from map_controller.dart
      },
    );
  }

  Widget buildFilterPanel() {
    /* TODO */
    return Scaffold();
  }

  Widget buildMarkerCard() {
    if (selectedIncident == null) return SizedBox.shrink();

    return Positioned(
      left: 16,
      right: 16,
      bottom: 30,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: TColorTheme.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        mapController.getAssetForIncident(
                          selectedIncident!.incident,
                        ),
                        width: 32,
                        height: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selectedIncident!.incident,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: TColorTheme.getIncidentColor(
                            selectedIncident!.incident,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        calculateDistanceFromUser(
                          selectedIncident!,
                        ), // see below
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: TColorTheme.primaryRed,
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() {
                        selectedIncident = null;
                        showMarkerCard = false;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                selectedIncident!.location,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF000000),
                ),
              ),
              Text(
                selectedIncident!.description,
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                selectedIncident?.datetime?.toString() ?? 'No time',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              SizedBox(height: 12),
              // GestureDetector(
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (context) => const ForumPage()),
              //     );
              //   },
              //   child: Text(
              //     'Navigate to forum',
              //     style: TextStyle(
              //       color: Colors.blue,

              //       fontWeight: FontWeight.w500,
              //     ),
              //   ),
              // ),
              GestureDetector(
                onTap: () {
                  widget.onNavigateToForum();
                },
                child: Text(
                  'Navigate to forum',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // helper methods
  Future<void> _initMap() async {
    currentP = await mapController.getCurrentLocation();
    loadMarkers();
    setState(() {});
  }

  Future<void> loadMarkers() async {
    final markers = await mapController.loadIncidentMarkers(
      onMarkerTap: (incident) {
        setState(() {
          selectedIncident = incident;
          showMarkerCard = true;
        });
      },
      selectedDate: selectedDate,
    );
    setState(() {
      incidentMarkers = markers;
    });
  }

  String calculateDistanceFromUser(Incident incident) {
    final distanceInMeters = Geolocator.distanceBetween(
      currentP!.latitude,
      currentP!.longitude,
      incident.latitude,
      incident.longitude,
    );

    final distanceInKm = (distanceInMeters / 1000).toStringAsFixed(2);
    return '$distanceInKm km';
  }
}
