import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'form_detail_page.dart';
import '../services/openrouter_service.dart';
import '../services/image_metadata_service.dart';

class FormPhotoPage extends StatefulWidget {
  const FormPhotoPage({super.key});

  @override
  State<FormPhotoPage> createState() => _FormPhotoPageState();
}

class _FormPhotoPageState extends State<FormPhotoPage> {
  final ImagePicker _picker = ImagePicker();
  final OpenRouterService _aiService = OpenRouterService();
  List<XFile> _selectedImages = [];
  bool _isAnalyzing = false;
  List<Map<String, dynamic>> _imageValidationResults = [];

  @override
  void initState() {
    super.initState();
  }

  // Simplified gallery picker - only images
  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
        
        // Validate each image's metadata
        await _validateSelectedImages();
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting images: $e');
    }
  }

  // Simplified camera picker - only images
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
        
        // Validate the image's metadata
        await _validateSelectedImages();
      }
    } catch (e) {
      _showErrorSnackBar('Error taking photo: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _validateSelectedImages() async {
    List<Map<String, dynamic>> results = [];
    
    for (int i = 0; i < _selectedImages.length; i++) {
      final image = _selectedImages[i];
      final validationResult = await ImageMetadataService.getValidationResult(
        image.path,
        maxHoursAgo: 24, // Allow images taken within last 24 hours
      );
      
      results.add({
        'index': i,
        'validation': validationResult,
      });
    }
    
    setState(() {
      _imageValidationResults = results;
    });
    
    // Show warnings for invalid images
    _showValidationWarnings();
  }

  void _showValidationWarnings() {
    final invalidImages = _imageValidationResults
        .where((result) => !result['validation']['isValid'])
        .toList();
    
    if (invalidImages.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Image Validation Warning'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Some images may not be recent:'),
              const SizedBox(height: 8),
              ...invalidImages.map((result) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• Image ${result['index'] + 1}: ${result['validation']['reason']}',
                  style: const TextStyle(fontSize: 12),
                ),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Anyway'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeInvalidImages();
              },
              child: const Text('Remove Invalid Images'),
            ),
          ],
        ),
      );
    }
  }

  void _removeInvalidImages() {
    final invalidIndices = _imageValidationResults
        .where((result) => !result['validation']['isValid'])
        .map((result) => result['index'] as int)
        .toList()
        ..sort((a, b) => b.compareTo(a)); // Sort in descending order
    
    setState(() {
      for (final index in invalidIndices) {
        _selectedImages.removeAt(index);
      }
    });
    
    // Re-validate remaining images
    _validateSelectedImages();
  }

  Widget _buildImagePreview() {
    if (_selectedImages.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Selected Images',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              final image = _selectedImages[index];
              final validation = _imageValidationResults
                  .where((result) => result['index'] == index)
                  .firstOrNull?['validation'];
              
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(image.path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Validation indicator
                    if (validation != null)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: validation['isValid'] 
                                ? Colors.green 
                                : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            validation['isValid'] 
                                ? Icons.check 
                                : Icons.warning,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    // Remove button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Validation summary
        if (_imageValidationResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _getValidationSummary(),
              style: TextStyle(
                fontSize: 12,
                color: _hasInvalidImages() ? Colors.orange[700] : Colors.green[700],
              ),
            ),
          ),
      ],
    );
  }

  String _getValidationSummary() {
    final total = _imageValidationResults.length;
    final valid = _imageValidationResults.where((r) => r['validation']['isValid']).length;
    
    if (valid == total) {
      return '✓ All images have valid timestamps';
    } else {
      return '⚠ ${total - valid} of $total images may be outdated';
    }
  }

  bool _hasInvalidImages() {
    return _imageValidationResults.any((result) => !result['validation']['isValid']);
  }

  Future<void> _navigateToDetailPage() async {
    if (_selectedImages.isEmpty) {
      _showErrorSnackBar('Please select at least one photo');
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Analyze images with AI
      final analysisResult = await _aiService.analyzeIncidentImages(
        imagePaths: _selectedImages.map((image) => image.path).toList(),
      );

      // Navigate to detail page with analysis results
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FormDetailPage(
              selectedMedia: _selectedImages,
              aiAnalysis: analysisResult,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('AI Analysis failed: ${e.toString()}. You can still fill the form manually.');
        
        // Navigate without AI analysis if it fails
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FormDetailPage(
              selectedMedia: _selectedImages,
              aiAnalysis: null,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
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
          'Upload Photos',
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
            // Upload Photos Section
            const Text(
              'Upload/Take Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            
            // Upload Area
            GestureDetector(
              onTap: _pickImagesFromGallery,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select Photos from Gallery',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // OR Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Camera Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _pickImageFromCamera,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Open Camera & Take Photo',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            
            _buildImagePreview(),
            
            const SizedBox(height: 32),
            
            // Next Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAnalyzing ? null : _navigateToDetailPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B), // Red color like in the image
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isAnalyzing
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
                            'Analyzing Images...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Next',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 24), // Extra space at bottom for scroll
          ],
        ),
      ),
    );
  }
} 