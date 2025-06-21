import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
// import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
// import 'package:permission_handler/permission_handler.dart';

class ARCoreDepthService {
  static const MethodChannel _channel = MethodChannel('arcore_depth_analysis');
  
  /// Check if device supports ARCore depth analysis
  static Future<bool> isARCoreSupported() async {
    try {
      // For MVP, return false until ARCore plugin is properly set up
      // return await ArCoreController.checkArCoreAvailability();
      return false;
    } catch (e) {
      print('ARCore availability check failed: $e');
      return false;
    }
  }

  /// Request camera permissions needed for ARCore
  static Future<bool> requestCameraPermission() async {
    // For MVP, assume permission is granted
    // final status = await Permission.camera.request();
    // return status == PermissionStatus.granted;
    return true;
  }

  /// Analyze image using ARCore to detect if it's from a 2D screen or 3D real scene
  /// Returns a validation result similar to metadata validation
  static Future<Map<String, dynamic>> analyzeImageDepth(String imagePath) async {
    try {
      // Load image data
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      // Always try our native image analysis first
      final analysis = await _analyzeImageCharacteristics(imagePath);
      
      return analysis;
    } catch (e) {
      print('Image depth analysis failed: $e');
      // Return neutral result on error - don't block valid users
      return {
        'isValid': true,
        'is3DScene': null,
        'confidence': 0.0,
        'reason': 'Depth analysis unavailable: $e',
        'depthVariance': null,
        'screenReflectionDetected': false,
      };
    }
  }

  /// Analyze image characteristics that indicate screen vs real scene
  static Future<Map<String, dynamic>> _analyzeImageCharacteristics(String imagePath) async {
    print('Starting image analysis for: $imagePath');
    
    try {
      // Use platform channel to perform native image analysis
      print('Attempting native platform channel analysis...');
      final dynamic rawResult = await _channel.invokeMethod('analyzeImageDepth', {
        'imagePath': imagePath,
      }).timeout(
        Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Native analysis timed out', Duration(seconds: 10)),
      );
      
      // Convert the result to the expected type
      final Map<String, dynamic> result = Map<String, dynamic>.from(rawResult as Map);

      print('Native analysis successful!');
      final double depthVariance = result['depthVariance'] ?? 0.0;
      final double pixelUniformity = result['pixelUniformity'] ?? 0.0;
      final bool screenReflectionDetected = result['screenReflectionDetected'] ?? false;
      final double edgeSharpness = result['edgeSharpness'] ?? 0.0;

      // Debug logging
      print('Native Analysis Results:');
      print('  depthVariance: $depthVariance');
      print('  pixelUniformity: $pixelUniformity');
      print('  screenReflectionDetected: $screenReflectionDetected');
      print('  edgeSharpness: $edgeSharpness');

      // Determine if this is likely a 3D scene or 2D screen
      final bool is3DScene = _determine3DScene(
        depthVariance: depthVariance,
        pixelUniformity: pixelUniformity,
        screenReflectionDetected: screenReflectionDetected,
        edgeSharpness: edgeSharpness,
      );

      print('  -> is3DScene: $is3DScene');

      final double confidence = _calculateConfidence(
        depthVariance: depthVariance,
        pixelUniformity: pixelUniformity,
        screenReflectionDetected: screenReflectionDetected,
        edgeSharpness: edgeSharpness,
      );

      String reason = '';
      if (!is3DScene) {
        if (screenReflectionDetected) {
          reason = 'Screen reflection or glare detected';
        } else if (pixelUniformity > 0.8) {
          reason = 'Image shows uniform pixel patterns typical of screens';
        } else if (depthVariance < 0.1) {
          reason = 'Low depth variance indicates flat 2D surface';
        } else if (edgeSharpness < 0.3) {
          reason = 'Soft edges typical of photographed screens';
        } else {
          reason = 'Multiple indicators suggest 2D screen capture';
        }
      }

      return {
        'isValid': is3DScene, // Invalid if it's a 2D screen
        'is3DScene': is3DScene,
        'confidence': confidence,
        'reason': reason,
        'depthVariance': depthVariance,
        'screenReflectionDetected': screenReflectionDetected,
        'pixelUniformity': pixelUniformity,
        'edgeSharpness': edgeSharpness,
      };
    } catch (e) {
      print('Native analysis failed: $e');
      print('Falling back to enhanced Dart-based analysis...');
      // Fallback to enhanced image analysis without native code
      return await _enhancedBasicImageAnalysis(imagePath);
    }
  }

  /// Determine if image shows 3D scene based on analysis metrics
  static bool _determine3DScene({
    required double depthVariance,
    required double pixelUniformity,
    required bool screenReflectionDetected,
    required double edgeSharpness,
  }) {
    // SIMPLIFIED TEST: Only check screen reflection detection
    print('  -> Testing screen reflection only: $screenReflectionDetected');
    print('  -> Other metrics (for reference): depth=$depthVariance, uniformity=$pixelUniformity, edges=$edgeSharpness');
    
    // If screen reflection is detected, classify as screen image
    // If no screen reflection, classify as real 3D scene
    return !screenReflectionDetected; // Return true if it's a 3D scene (no reflection detected)
  }

  /// Calculate confidence level for the analysis
  static double _calculateConfidence({
    required double depthVariance,
    required double pixelUniformity,
    required bool screenReflectionDetected,
    required double edgeSharpness,
  }) {
    double confidence = 0.5; // Base confidence

    // Strong indicators increase confidence
    if (screenReflectionDetected) confidence += 0.3;
    if (pixelUniformity > 0.8) confidence += 0.2;
    if (depthVariance < 0.1) confidence += 0.2;
    if (edgeSharpness < 0.3) confidence += 0.1;

    // Strong 3D indicators
    if (depthVariance > 0.3) confidence += 0.2;
    if (pixelUniformity < 0.5) confidence += 0.2;
    if (edgeSharpness > 0.7) confidence += 0.1;

    return confidence.clamp(0.0, 1.0);
  }

  /// Enhanced image analysis fallback when native analysis fails
  static Future<Map<String, dynamic>> _enhancedBasicImageAnalysis(String imagePath) async {
    print('Running enhanced Dart-based analysis...');
    
    final File imageFile = File(imagePath);
    final Uint8List imageBytes = await imageFile.readAsBytes();
    
    // Analyze file characteristics that indicate screen photos
    final double fileSize = imageBytes.length / (1024 * 1024); // MB
    
    bool likelyScreen = false;
    String reason = '';
    double confidence = 0.3; // Lower base confidence for fallback analysis
    
    print('Enhanced Analysis Results:');
    print('  fileSize: ${fileSize.toStringAsFixed(2)}MB');
    
    // Use exclusive logic - check conditions in order of priority
    if (fileSize < 0.2) {
      // Very small files are likely compressed screenshots
      likelyScreen = true;
      reason = 'Very small file size (${fileSize.toStringAsFixed(2)}MB) suggests compressed screenshot';
      confidence = 0.8;
    } else if (fileSize > 8.0) {
      // Very large files could be high-res screenshots
      likelyScreen = true;
      reason = 'Large file size (${fileSize.toStringAsFixed(2)}MB) may indicate high-resolution screenshot';
      confidence = 0.6;
    } else if (fileSize >= 0.2 && fileSize <= 1.5) {
      // Moderate file sizes - this is where most real camera photos fall
      // For obvious screen images, we need to be more aggressive
      // Since native analysis failed, assume it's a potential screen image for safety
      likelyScreen = true;
      reason = 'File characteristics and fallback analysis suggest potential screen capture';
      confidence = 0.7;
    } else {
      // File size seems reasonable for camera photo
      likelyScreen = false;
      reason = 'File size appears normal for camera photo';
      confidence = 0.4;
    }
    
    print('  likelyScreen: $likelyScreen');
    print('  reason: $reason');
    print('  confidence: $confidence');
    
    return {
      'isValid': !likelyScreen,
      'is3DScene': !likelyScreen,
      'confidence': confidence,
      'reason': reason,
      'depthVariance': null,
      'screenReflectionDetected': false,
      'enhancedAnalysis': true, // Flag to indicate this was fallback analysis
    };
  }

  /// Basic image analysis fallback when native analysis fails
  static Future<Map<String, dynamic>> _basicImageAnalysis(String imagePath) async {
    // This method is kept for compatibility but enhanced version is preferred
    return await _enhancedBasicImageAnalysis(imagePath);
  }
} 