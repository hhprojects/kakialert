// Import the Cloudinary packages.
import 'dart:async';

import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:cloudinary_api/uploader/cloudinary_uploader.dart';
import 'package:cloudinary_api/src/request/model/uploader_params.dart';
import 'package:cloudinary_url_gen/transformation/resize/resize.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class CloudinaryService {
  
  late Cloudinary _cloudinary;
  late Cloudinary _urlCloudinary;
  
  CloudinaryService() {
    _cloudinary = Cloudinary.fromStringUrl(
      'cloudinary://${dotenv.env['CLOUDINARY_API_KEY']}:${dotenv.env['CLOUDINARY_API_SECRET']}@${dotenv.env['CLOUDINARY_CLOUD_NAME']}',
    );
    
    // For URL generation (only needs cloud name)
    _urlCloudinary = Cloudinary.fromCloudName(
      cloudName: dotenv.env['CLOUDINARY_CLOUD_NAME']!,
    );
  }

  Future<Map<String, dynamic>?> uploadImage(String imagePath) async {
    try {
      var response = await _cloudinary.uploader().upload(File(imagePath),
        params: UploadParams(
          resourceType: 'image',
          publicId: 'post_${DateTime.now().millisecondsSinceEpoch}',
          folder: 'posts',
        ),
      );
      if (response?.data != null) {
        return {
            'publicId': response?.data!.publicId!,
            'secureUrl': response?.data!.secureUrl!,
            'width': response?.data!.width,
            'height': response?.data!.height,
            'format': response?.data!.format,
          };
      }
      return null;
    } catch (e) {
      print('Upload failed: $e');
      return null;
    }
  }

    // Method 2: Generate URL from Public ID (Basic)
  String getImageUrl(String publicId) {
    return _urlCloudinary
        .image(publicId)
        .transformation(Transformation())
        .toString();
  }

  // Method 3: Generate URL with specific transformations
  String getTransformedImageUrl(String publicId, {
    int? width,
    int? height,
    String cropMode = 'fill',
    int quality = 80,
  }) {
    var transformation = Transformation();
    
    if (width != null || height != null) {
      if (cropMode == 'fill' && width != null && height != null) {
        transformation.resize(Resize.fill()..width(width)..height(height));
      } else if (width != null) {
        transformation.resize(Resize.scale()..width(width));
      }
    }
    
    return _urlCloudinary
        .image(publicId)
        .transformation(transformation)
        .toString();
  }

  // Method 4: Generate multiple sizes for responsive images
  Map<String, String> getResponsiveImageUrls(String publicId) {
    return {
      'thumbnail': getTransformedImageUrl(publicId, width: 150, height: 150),
      'small': getTransformedImageUrl(publicId, width: 300),
      'medium': getTransformedImageUrl(publicId, width: 600),
      'large': getTransformedImageUrl(publicId, width: 1200),
      'original': getImageUrl(publicId),
    };
  }
}