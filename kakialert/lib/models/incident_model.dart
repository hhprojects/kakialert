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
  final Map<String, dynamic>? imageMetadata; // Store metadata
  final bool? metadataValidated; // Whether metadata was validated
  final String? clusterId; // ID of the cluster this incident belongs to
  final int? clusterSize; // Number of incidents in this cluster (only for master)
  final int? verificationCount; // Number of additional reports (cluster size - 1)
  final List<String> contributorIds; // User IDs who reported this incident
  final List<String> aggregatedImageUrls; // All images from clustered incidents
  final DateTime? lastUpdated; // When cluster was last updated

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
    this.imageMetadata,
    this.metadataValidated,
    this.clusterId,
    this.clusterSize,
    this.verificationCount,
    this.contributorIds = const [],
    this.aggregatedImageUrls = const [],
    this.lastUpdated,
  });

  // Factory constructor to create Incident from Firestore document
  factory Incident.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Incident(
      id: doc.id,
      title: data['title'] ?? 'Untitled Incident',
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
      imageMetadata: data['imageMetadata'] != null 
          ? Map<String, dynamic>.from(data['imageMetadata']) 
          : null,
      metadataValidated: data['metadataValidated'],
      clusterId: data['clusterId'],
      clusterSize: data['clusterSize'],
      verificationCount: data['verificationCount'],
      contributorIds: List<String>.from(data['contributorIds'] ?? []),
      aggregatedImageUrls: List<String>.from(data['aggregatedImageUrls'] ?? []),
      lastUpdated: data['lastUpdated'] != null 
          ? (data['lastUpdated'] is Timestamp 
              ? (data['lastUpdated'] as Timestamp).toDate()
              : DateTime.tryParse(data['lastUpdated']))
          : null,
    );
  }

  // Factory constructor to create Incident from Map
  factory Incident.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return Incident(
      id: documentId ?? data['id'],
      title: data['title'] ?? 'Untitled Incident',
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
      imageMetadata: data['imageMetadata'] != null 
          ? Map<String, dynamic>.from(data['imageMetadata']) 
          : null,
      metadataValidated: data['metadataValidated'],
      clusterId: data['clusterId'],
      clusterSize: data['clusterSize'],
      verificationCount: data['verificationCount'],
      contributorIds: List<String>.from(data['contributorIds'] ?? []),
      aggregatedImageUrls: List<String>.from(data['aggregatedImageUrls'] ?? []),
      lastUpdated: data['lastUpdated'] != null 
          ? (data['lastUpdated'] is Timestamp 
              ? (data['lastUpdated'] as Timestamp).toDate()
              : DateTime.tryParse(data['lastUpdated'].toString()))
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
      'imageMetadata': imageMetadata,
      'metadataValidated': metadataValidated,
      'clusterId': clusterId,
      'clusterSize': clusterSize,
      'verificationCount': verificationCount,
      'contributorIds': contributorIds,
      'aggregatedImageUrls': aggregatedImageUrls,
      'lastUpdated': lastUpdated?.toIso8601String(),
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
      'imageMetadata': imageMetadata,
      'metadataValidated': metadataValidated,
      'clusterId': clusterId,
      'clusterSize': clusterSize,
      'verificationCount': verificationCount,
      'contributorIds': contributorIds,
      'aggregatedImageUrls': aggregatedImageUrls,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  // Get first image URL
  String? get firstImageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  // Get LatLng position for Google Maps
  LatLng get position => LatLng(latitude, longitude);

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
    Map<String, dynamic>? imageMetadata,
    bool? metadataValidated,
    String? clusterId,
    int? clusterSize,
    int? verificationCount,
    List<String>? contributorIds,
    List<String>? aggregatedImageUrls,
    DateTime? lastUpdated,
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
      imageMetadata: imageMetadata ?? this.imageMetadata,
      metadataValidated: metadataValidated ?? this.metadataValidated,
      clusterId: clusterId ?? this.clusterId,
      clusterSize: clusterSize ?? this.clusterSize,
      verificationCount: verificationCount ?? this.verificationCount,
      contributorIds: contributorIds ?? this.contributorIds,
      aggregatedImageUrls: aggregatedImageUrls ?? this.aggregatedImageUrls,
      lastUpdated: lastUpdated ?? this.lastUpdated,
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

  // Helper methods
  bool get isClusterMaster => clusterId == null || clusterId == id;
  bool get isInCluster => clusterId != null;
  int get totalReports => (verificationCount ?? 0) + 1;
}
