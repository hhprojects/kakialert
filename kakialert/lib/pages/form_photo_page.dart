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
  Map<String, dynamic>? _incidentValidationResult;
  bool _isValidatingIncident = false;

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
        
        // Validate metadata and incident content
        await _validateSelectedImages();
        await _validateIncidentContent();
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
        
        // Validate metadata and incident content
        await _validateSelectedImages();
        await _validateIncidentContent();
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

  Future<void> _validateIncidentContent() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isValidatingIncident = true;
    });

    try {
      final validationResult = await _aiService.validateIncidentImages(
        imagePaths: _selectedImages.map((image) => image.path).toList(),
      );

      setState(() {
        _incidentValidationResult = validationResult;
        _isValidatingIncident = false;
      });

      // Show warning if content is not valid
      if (!validationResult['isValid']) {
        _showIncidentValidationWarning();
      }

    } catch (e) {
      setState(() {
        _isValidatingIncident = false;
      });
      print('Incident validation failed: $e');
      // Continue without validation if AI fails
    }
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

  void _showIncidentValidationWarning() {
    if (_incidentValidationResult == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Content Validation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The AI detected that your images may not show a legitimate incident:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason: ${_incidentValidationResult!['reason']}',
                    style: TextStyle(fontSize: 14),
                  ),
                  if (_incidentValidationResult!['recommendations'].isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      'AI suggests: ${_incidentValidationResult!['recommendations']}',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Confidence: ${_incidentValidationResult!['confidence']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Continue Anyway'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _selectedImages.clear();
                _incidentValidationResult = null;
                _imageValidationResults.clear();
              });
            },
            child: Text('Remove Images'),
          ),
        ],
      ),
    );
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
              final metadataValidation = _imageValidationResults
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
                    // Metadata validation indicator
                    if (metadataValidation != null)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: metadataValidation['isValid'] 
                                ? Colors.green 
                                : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            metadataValidation['isValid'] 
                                ? Icons.check 
                                : Icons.schedule,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    // Incident validation indicator
                    if (_incidentValidationResult != null)
                      Positioned(
                        top: 4,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _incidentValidationResult!['isValid'] 
                                ? Colors.blue 
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _incidentValidationResult!['isValid'] 
                                ? Icons.verified 
                                : Icons.error,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    // Loading indicator for incident validation
                    if (_isValidatingIncident)
                      Positioned(
                        top: 4,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
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
        if (_imageValidationResults.isNotEmpty || _incidentValidationResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_imageValidationResults.isNotEmpty)
                  Text(
                    _getMetadataValidationSummary(),
                    style: TextStyle(
                      fontSize: 12,
                      color: _hasInvalidMetadata() ? Colors.orange[700] : Colors.green[700],
                    ),
                  ),
                if (_incidentValidationResult != null)
                  Text(
                    _getIncidentValidationSummary(),
                    style: TextStyle(
                      fontSize: 12,
                      color: _incidentValidationResult!['isValid'] 
                          ? Colors.blue[700] 
                          : Colors.red[700],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _getMetadataValidationSummary() {
    final total = _imageValidationResults.length;
    final valid = _imageValidationResults.where((r) => r['validation']['isValid']).length;
    
    if (valid == total) {
      return '⏰ All images have valid timestamps';
    } else {
      return '⚠ ${total - valid} of $total images may be outdated';
    }
  }

  String _getIncidentValidationSummary() {
    if (_incidentValidationResult == null) return '';
    
    if (_incidentValidationResult!['isValid']) {
      return '✅ AI verified: Appears to be a legitimate incident';
    } else {
      return '❌ AI warning: May not be a legitimate incident';
    }
  }

  bool _hasInvalidMetadata() {
    return _imageValidationResults.any((result) => !result['validation']['isValid']);
  }

  Future<void> _navigateToDetailPage() async {
    if (_selectedImages.isEmpty) {
      _showErrorSnackBar('Please select at least one photo');
      return;
    }

    // Check metadata validation - BLOCK if any image fails
    if (_hasInvalidMetadata()) {
      _showValidationBlockedDialog(
        title: 'Invalid Image Timestamps',
        message: 'Some images were not taken recently or lack timestamp information. Please remove them and use fresh photos taken at the incident scene.',
        icon: Icons.schedule_outlined,
        color: Colors.orange,
      );
      return;
    }

    // Check incident content validation - BLOCK if AI flags content
    if (_incidentValidationResult != null && !_incidentValidationResult!['isValid']) {
      _showValidationBlockedDialog(
        title: 'Non-Incident Content Detected',
        message: 'The AI detected that your images may not show a legitimate incident.\n\n'
            'Reason: ${_incidentValidationResult!['reason']}\n\n'
            'Please submit photos that clearly show an emergency, damage, or safety concern.',
        icon: Icons.error_outline,
        color: Colors.red,
      );
      return;
    }

    // If validation is still in progress, wait
    if (_isValidatingIncident) {
      _showErrorSnackBar('Please wait for image validation to complete');
      return;
    }

    // All validations passed - proceed with form filling
    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Analyze images with AI for form filling
      final analysisResult = await _aiService.analyzeIncidentImages(
        imagePaths: _selectedImages.map((image) => image.path).toList(),
      );

      // Add validation results to the analysis
      Map<String, String> enhancedAnalysis = Map.from(analysisResult);
      enhancedAnalysis['validationStatus'] = 'fully_validated';
      enhancedAnalysis['metadataValidated'] = 'true';
      enhancedAnalysis['contentValidated'] = 'true';

      // Navigate to detail page with analysis results
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FormDetailPage(
              selectedMedia: _selectedImages,
              aiAnalysis: enhancedAnalysis,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('AI Analysis failed: ${e.toString()}. Please try again or contact support.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  // New method to show blocking validation dialogs
  void _showValidationBlockedDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to acknowledge
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: color, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For incident reliability and community safety, all images must pass validation.',
                      style: TextStyle(
                        fontSize: 12,
                        color: color.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Remove Invalid Images',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showValidationDetails() {
    if (_incidentValidationResult == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('AI Validation Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Status', _incidentValidationResult!['isValid'] ? 'Valid Incident' : 'Non-Incident'),
            _buildDetailRow('Confidence', _incidentValidationResult!['confidence']),
            _buildDetailRow('Reason', _incidentValidationResult!['reason']),
            if (_incidentValidationResult!['detectedElements'].isNotEmpty) ...[
              SizedBox(height: 8),
              Text('Detected Elements:', style: TextStyle(fontWeight: FontWeight.w500)),
              ...(_incidentValidationResult!['detectedElements'] as List).map(
                (element) => Padding(
                  padding: EdgeInsets.only(left: 16, top: 2),
                  child: Text('• $element', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
            if (_incidentValidationResult!['recommendations'].isNotEmpty) ...[
              SizedBox(height: 8),
              Text('AI Recommendation:', style: TextStyle(fontWeight: FontWeight.w500)),
              Padding(
                padding: EdgeInsets.only(left: 16, top: 2),
                child: Text(_incidentValidationResult!['recommendations'], style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // Update the continue button to show validation status
  Widget _buildContinueButton() {
    final hasMetadataIssues = _hasInvalidMetadata();
    final hasContentIssues = _incidentValidationResult != null && !_incidentValidationResult!['isValid'];
    final isValidating = _isValidatingIncident;
    
    bool canProceed = !hasMetadataIssues && !hasContentIssues && !isValidating && _selectedImages.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Validation status summary
          if (_selectedImages.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: canProceed ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: canProceed ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    canProceed ? Icons.check_circle : Icons.error,
                    color: canProceed ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          canProceed ? 'All validations passed' : 'Validation issues detected',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: canProceed ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                        if (!canProceed) ...[
                          SizedBox(height: 4),
                          Text(
                            _getBlockingIssuesSummary(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Continue button
          ElevatedButton(
            onPressed: canProceed ? _navigateToDetailPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canProceed ? Colors.blue : Colors.grey,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isAnalyzing || isValidating) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                Text(
                  _getButtonText(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText() {
    if (_isAnalyzing) return 'Analyzing Images...';
    if (_isValidatingIncident) return 'Validating Content...';
    if (_selectedImages.isEmpty) return 'Select Images First';
    if (_hasInvalidMetadata()) return 'Fix Timestamp Issues';
    if (_incidentValidationResult != null && !_incidentValidationResult!['isValid']) {
      return 'Fix Content Issues';
    }
    return 'Continue to Details';
  }

  String _getBlockingIssuesSummary() {
    List<String> issues = [];
    
    if (_hasInvalidMetadata()) {
      issues.add('Invalid timestamps detected');
    }
    
    if (_incidentValidationResult != null && !_incidentValidationResult!['isValid']) {
      issues.add('Non-incident content detected');
    }
    
    if (_isValidatingIncident) {
      issues.add('Validation in progress');
    }
    
    return issues.join(' • ');
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
            _buildContinueButton(),
            
            const SizedBox(height: 24), // Extra space at bottom for scroll
          ],
        ),
      ),
    );
  }
} 