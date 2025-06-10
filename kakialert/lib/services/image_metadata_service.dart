import 'dart:io';
import 'package:native_exif/native_exif.dart';

class ImageMetadataService {
  /// Extract metadata from an image file
  static Future<Map<String, dynamic>?> extractMetadata(String imagePath) async {
    try {
      final exif = await Exif.fromPath(imagePath);
      
      // Get all available attributes
      final attributes = await exif.getAttributes();
      
      // Get specific important data
      final originalDate = await exif.getOriginalDate();
      final latLong = await exif.getLatLong();
      
      await exif.close();
      
      return {
        'originalDate': originalDate,
        'latLong': latLong,
        'allAttributes': attributes,
      };
    } catch (e) {
      print('Error extracting metadata: $e');
      return null;
    }
  }
  
  /// Validate if image was taken recently (within reasonable time frame)
  static bool validateImageTimestamp(DateTime? originalDate, {int maxHoursAgo = 24}) {
    if (originalDate == null) {
      // If no timestamp found, we can't validate - might be suspicious
      return false;
    }
    
    final now = DateTime.now();
    final timeDifference = now.difference(originalDate);
    
    // Check if image was taken within the specified time frame
    return timeDifference.inHours <= maxHoursAgo && timeDifference.inHours >= 0;
  }
  
  /// Get formatted validation result
  static Future<Map<String, dynamic>> getValidationResult(String imagePath, {int maxHoursAgo = 24}) async {
    final metadata = await extractMetadata(imagePath);
    final originalDate = metadata?['originalDate'];
    
    final isValid = validateImageTimestamp(originalDate, maxHoursAgo: maxHoursAgo);
    
    return {
      'isValid': isValid,
      'originalDate': originalDate,
      'reason': _getValidationReason(originalDate, maxHoursAgo),
      'metadata': metadata,
    };
  }
  
  static String _getValidationReason(DateTime? originalDate, int maxHoursAgo) {
    if (originalDate == null) {
      return 'No timestamp found in image metadata';
    }
    
    final now = DateTime.now();
    final timeDifference = now.difference(originalDate);
    
    if (timeDifference.inHours > maxHoursAgo) {
      return 'Image was taken more than $maxHoursAgo hours ago';
    } else if (timeDifference.inHours < 0) {
      return 'Image timestamp is in the future';
    } else {
      return 'Image timestamp is valid';
    }
  }
} 