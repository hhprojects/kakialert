import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../controllers/map_controller.dart';
import '../controllers/incident_controller.dart';
import '../services/cloudinary_service.dart';
import '../services/auth_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FormDetailPage extends StatefulWidget {
  final List<XFile> selectedMedia;
  final Map<String, String>? aiAnalysis;
  
  const FormDetailPage({
    super.key, 
    required this.selectedMedia,
    this.aiAnalysis,
  });

  @override
  State<FormDetailPage> createState() => _FormDetailPageState();
}

class _FormDetailPageState extends State<FormDetailPage> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  
  // Add selected subject variable
  String? _selectedSubject;
  
  // Location loading state
  bool _isLoadingLocation = false;
  
  // Submission loading state
  bool _isSubmitting = false;
  
  // Map controller for location services
  late MapController _mapController;
  
  // Services
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final AuthService _authService = AuthService();

  // Define subject options
  final List<Map<String, dynamic>> _subjectOptions = [
    {
      'id': 'medical',
      'label': 'Medical',
      'iconPath': 'assets/icons/medical.png',
      'color': Color(0xFFB8D4A0), // Light green
    },
    {
      'id': 'fire',
      'label': 'Fire',
      'iconPath': 'assets/icons/fire.png',
      'color': Color(0xFFFF9B9B), // Light red
    },
    {
      'id': 'accident',
      'label': 'Accident',
      'iconPath': 'assets/icons/accident.png',
      'color': Color(0xFFB4A7E5), // Light purple
    },
    {
      'id': 'violence',
      'label': 'Violence',
      'iconPath': 'assets/icons/violence.png',
      'color': Color(0xFFE5A7C7), // Light pink
    },
    {
      'id': 'rescue',
      'label': 'Rescue',
      'iconPath': 'assets/icons/rescue.png',
      'color': Color(0xFFE5D4A7), // Light yellow
    },
    {
      'id': 'hdb_facilities',
      'label': 'HDB Facilities',
      'iconPath': 'assets/icons/hdb.png',
      'color': Color(0xFFA7C7E5), // Light blue
    },
    {
      'id': 'mrt',
      'label': 'MRT',
      'iconPath': 'assets/icons/mrt.png', // You can add a train icon here
      'color': Color(0xFFA7E5D4), // Light teal
    },
    {
      'id': 'others',
      'label': 'Others',
      'iconPath': 'assets/icons/others.png',
      'color': Color(0xFFD0D0D0), // Light gray
    },
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController(incidentController: IncidentController());
    _prefillFromAIAnalysis();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _prefillFromAIAnalysis() {
    if (widget.aiAnalysis != null) {
      final analysis = widget.aiAnalysis!;
      
      // Set subject if provided
      if (analysis['subject'] != null && analysis['subject']!.isNotEmpty) {
        setState(() {
          _selectedSubject = analysis['subject'];
        });
      }
      
      // Set title if provided
      if (analysis['title'] != null && analysis['title']!.isNotEmpty) {
        _titleController.text = analysis['title']!;
      }
      
      // Set description if provided
      if (analysis['description'] != null && analysis['description']!.isNotEmpty) {
        _descriptionController.text = analysis['description']!;
      }
    }
  }

  // Get user's current location and prefill location field
  Future<void> _getCurrentLocation() async {
    // Only get location if the field is empty (don't override user input)
    if (_locationController.text.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Get coordinates using existing MapController
      final location = await _mapController.getCurrentLocation();
      if (location != null && mounted) {
        // Convert coordinates to address using geocoding
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude, 
          location.longitude
        );
        
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          
          // Build formatted address string
          List<String> addressParts = [];
          
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            addressParts.add(place.postalCode!);
          }
          if (place.country != null && place.country!.isNotEmpty) {
            addressParts.add(place.country!);
          }

          String formattedAddress = addressParts.join(', ');
          
          if (formattedAddress.isEmpty) {
            formattedAddress = 'Near ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
          }
          
          setState(() {
            _locationController.text = formattedAddress;
          });
        } else {
          // Fallback to coordinates
          setState(() {
            _locationController.text = 'Near ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
          });
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get your location. Please enter it manually.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  // Manual location refresh button handler
  Future<void> _refreshLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Get coordinates using existing MapController
      final location = await _mapController.getCurrentLocation();
      if (location != null && mounted) {
        // Convert coordinates to address using geocoding
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude, 
          location.longitude
        );
        
        String formattedAddress;
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          
          List<String> addressParts = [];
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            addressParts.add(place.postalCode!);
          }
          if (place.country != null && place.country!.isNotEmpty) {
            addressParts.add(place.country!);
          }

          formattedAddress = addressParts.join(', ');
          if (formattedAddress.isEmpty) {
            formattedAddress = 'Near ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
          }
        } else {
          formattedAddress = 'Near ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
        }
        
        setState(() {
          _locationController.text = formattedAddress;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Could not get location');
      }
    } catch (e) {
      print('Error refreshing location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update location. Please check your settings.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Widget _buildImagePreview() {
    if (widget.selectedMedia.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Uploaded Images',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.selectedMedia.length,
            itemBuilder: (context, index) {
              final image = widget.selectedMedia[index];
              
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(image.path),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }


  Widget _buildSubjectSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subject',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _subjectOptions.map((subject) {
            final isSelected = _selectedSubject == subject['id'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSubject = subject['id'];
                });
              },
              child: Container(
                width: (MediaQuery.of(context).size.width - 56) / 2, // Responsive width for 2 columns
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? subject['color'].withOpacity(0.2) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? subject['color'] : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: subject['color'],
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        subject['iconPath'],
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading icon: ${subject['iconPath']} - $error');
                          return Icon(Icons.error, color: Colors.white, size: 20);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        subject['label'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.black : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    // Validate that subject is selected
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a subject category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate that title is provided
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate that location is provided
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Get current user
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user data including displayName
      final userData = await _authService.getUserData();
      final displayName = userData?['displayName'] ?? currentUser.displayName ?? 'Anonymous';

      // 2. Get current location coordinates
      final locationCoords = await _mapController.getCurrentLocation();
      if (locationCoords == null) {
        throw Exception('Could not get location coordinates');
      }

      // 3. Upload images to Cloudinary
      List<String> imageUrls = [];
      List<String> imagePublicIds = [];
      
      for (XFile image in widget.selectedMedia) {
        final uploadResult = await _cloudinaryService.uploadImage(image.path);
        if (uploadResult != null) {
          imageUrls.add(uploadResult['secureUrl']);
          imagePublicIds.add(uploadResult['publicId']);
        }
      }

      if (imageUrls.isEmpty) {
        throw Exception('Failed to upload images');
      }

      // 4. Create incident document for Firestore
      final incidentData = {
        'title': _titleController.text.trim(),
        'datetime': DateTime.now().toIso8601String(),
        'description': _descriptionController.text.trim(),
        'incident': _selectedSubject, // subject category
        'longitude': locationCoords.longitude,
        'latitude': locationCoords.latitude,
        'location': _locationController.text.trim(),
        'imageUrls': imageUrls, // Store all uploaded image URLs
        'imagePublicIds': imagePublicIds, // Store public IDs for management
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 5. Save to Firebase Firestore
      await FirebaseFirestore.instance
          .collection('incidents')
          .add(incidentData);

      // 6. Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back to home
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } catch (e) {
      print('Error submitting incident: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit incident: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Additional Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePreview(),


            // Add Subject Selection
            _buildSubjectSelection(),

            // What happened Section
            const Text(
              'What happened?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Title',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // Location Section
            const Text(
              'Where is this incident?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                if (_isLoadingLocation)
                  Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Getting location...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  )
                else
                  TextButton.icon(
                    onPressed: _refreshLocation,
                    icon: Icon(Icons.my_location, size: 16),
                    label: Text('Update Location'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                  hintText: _isLoadingLocation ? 'Getting your location...' : 'Enter location or tap "Update Location"',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  suffixIcon: _locationController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _locationController.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {}); // Refresh to show/hide clear button
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Description Section
            const Text(
              'Please provide additional descriptions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B), // Red color like in the image
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Submitting...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 100), // Extra space at bottom for scroll
          ],
        ),
      ),
    );
  }
} 