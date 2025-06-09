import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Incident {
  final String? id; // Document ID from Firestore
  final String title; // Incident title
  final String incident; // Incident type/category
  final String description; // Incident description
  final String location; // Human-readable location
  final double latitude; // GPS latitude
  final double longitude; // GPS longitude
  final List<String> imageUrls; // Cloudinary image URLs
  final List<String> imagePublicIds; // Cloudinary public IDs
  final String userId; // User who reported the incident
  final String userEmail; // User's email
  final String displayName; // User's display name
  final DateTime? datetime; // When the incident occurred
  final DateTime? createdAt; // When the report was created

  Incident({
    this.id,
    required this.title,
    required this.incident,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.imageUrls = const [],
    this.imagePublicIds = const [],
    required this.userId,
    required this.userEmail,
    required this.displayName,
    this.datetime,
    this.createdAt,
  });

  // Legacy constructor for backward compatibility
  Incident.legacy({
    required this.incident,
    required this.description,
    required this.location,
    String? image,
    required String dateTime,
    required this.latitude,
    required this.longitude,
  }) : 
    id = null,
    title = description, // Use description as title for legacy data
    imageUrls = image != null ? [image] : [],
    imagePublicIds = [],
    userId = '',
    userEmail = '',
    displayName = 'Anonymous',
    datetime = DateTime.tryParse(dateTime),
    createdAt = DateTime.tryParse(dateTime);

  // Factory constructor to create Incident from Firestore document
  factory Incident.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Incident(
      id: doc.id,
      title: data['title'] ?? data['description'] ?? 'Untitled Incident',
      incident: data['incident'] ?? 'others',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      imagePublicIds: List<String>.from(data['imagePublicIds'] ?? []),
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      displayName: data['displayName'] ?? 'Anonymous',
      datetime: data['datetime'] != null 
          ? (data['datetime'] is Timestamp 
              ? (data['datetime'] as Timestamp).toDate()
              : DateTime.tryParse(data['datetime']))
          : null,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Factory constructor to create Incident from Map
  factory Incident.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return Incident(
      id: documentId ?? data['id'],
      title: data['title'] ?? data['description'] ?? 'Untitled Incident',
      incident: data['incident'] ?? 'others',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      imagePublicIds: List<String>.from(data['imagePublicIds'] ?? []),
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      displayName: data['displayName'] ?? 'Anonymous',
      datetime: data['datetime'] != null 
          ? (data['datetime'] is Timestamp 
              ? (data['datetime'] as Timestamp).toDate()
              : DateTime.tryParse(data['datetime'].toString()))
          : null,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(data['createdAt'].toString()))
          : null,
    );
  }

  // Convert Incident to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'incident': incident,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'imagePublicIds': imagePublicIds,
      'userId': userId,
      'userEmail': userEmail,
      'displayName': displayName,
      'datetime': datetime?.toIso8601String(),
      'createdAt': createdAt != null 
          ? Timestamp.fromDate(createdAt!) 
          : FieldValue.serverTimestamp(),
    };
  }

  // Convert Incident to Map for creation (with server timestamps)
  Map<String, dynamic> toMapForCreation() {
    return {
      'title': title,
      'incident': incident,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'imagePublicIds': imagePublicIds,
      'userId': userId,
      'userEmail': userEmail,
      'displayName': displayName,
      'datetime': datetime?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Get first image URL
  String? get firstImageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  // Get LatLng position for Google Maps
  LatLng get position => LatLng(latitude, longitude);

  // Get formatted date string for legacy compatibility
  String get dateTime => datetime?.toIso8601String() ?? createdAt?.toIso8601String() ?? '';

  // Legacy image property for backward compatibility
  String? get image => imageUrls.isNotEmpty ? imageUrls.first : null;

  // Copy with method for updating incident data
  Incident copyWith({
    String? id,
    String? title,
    String? incident,
    String? description,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? imageUrls,
    List<String>? imagePublicIds,
    String? userId,
    String? userEmail,
    String? displayName,
    DateTime? datetime,
    DateTime? createdAt,
  }) {
    return Incident(
      id: id ?? this.id,
      title: title ?? this.title,
      incident: incident ?? this.incident,
      description: description ?? this.description,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrls: imageUrls ?? this.imageUrls,
      imagePublicIds: imagePublicIds ?? this.imagePublicIds,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      displayName: displayName ?? this.displayName,
      datetime: datetime ?? this.datetime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Incident(id: $id, title: $title, incident: $incident, location: $location, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Incident && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
