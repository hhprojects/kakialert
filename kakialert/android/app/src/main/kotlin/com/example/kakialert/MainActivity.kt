package com.example.kakialert

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "arcore_depth_analysis"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            println("Native: Method channel call received: ${call.method}")
            when (call.method) {
                "analyzeImageDepth" -> {
                    val imagePath = call.argument<String>("imagePath")
                    println("Native: Received image path: $imagePath")
                    if (imagePath != null) {
                        try {
                            val analysis = analyzeImageForScreenDetection(imagePath)
                            println("Native: Analysis successful, returning results")
                            result.success(analysis)
                        } catch (e: Exception) {
                            println("Native: Analysis failed with exception: ${e.message}")
                            e.printStackTrace()
                            result.error("ANALYSIS_ERROR", "Failed to analyze image: ${e.message}", null)
                        }
                    } else {
                        println("Native: No image path provided")
                        result.error("INVALID_ARGUMENT", "Image path is required", null)
                    }
                }
                else -> {
                    println("Native: Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private fun analyzeImageForScreenDetection(imagePath: String): Map<String, Any> {
        println("Native: Starting analysis for path: $imagePath")
        
        val file = File(imagePath)
        if (!file.exists()) {
            println("Native: File does not exist at path: $imagePath")
            throw IllegalArgumentException("Image file does not exist at path: $imagePath")
        }
        
        println("Native: File exists, size: ${file.length()} bytes")

        // Load and analyze the image
        val bitmap = loadAndOrientBitmap(imagePath)
        println("Native: Bitmap loaded successfully, size: ${bitmap.width}x${bitmap.height}")
        
        // Perform various analyses to detect screen characteristics
        println("Native: Starting depthVariance calculation...")
        val depthVariance = calculateDepthVariance(bitmap)
        println("Native: depthVariance = $depthVariance")
        
        println("Native: Starting pixelUniformity calculation...")
        val pixelUniformity = calculatePixelUniformity(bitmap)
        println("Native: pixelUniformity = $pixelUniformity")
        
        println("Native: Starting screenReflection detection...")
        val screenReflectionDetected = detectScreenReflection(bitmap)
        println("Native: screenReflectionDetected = $screenReflectionDetected")
        
        println("Native: Starting edgeSharpness calculation...")
        val edgeSharpness = calculateEdgeSharpness(bitmap)
        println("Native: edgeSharpness = $edgeSharpness")
        
        println("Native: Analysis complete - depthVariance=$depthVariance, pixelUniformity=$pixelUniformity, screenReflection=$screenReflectionDetected, edgeSharpness=$edgeSharpness")
        
        return mapOf<String, Any>(
            "depthVariance" to depthVariance as Double,
            "pixelUniformity" to pixelUniformity as Double,
            "screenReflectionDetected" to screenReflectionDetected as Boolean,
            "edgeSharpness" to edgeSharpness as Double
        )
    }

    private fun loadAndOrientBitmap(imagePath: String): Bitmap {
        val options = BitmapFactory.Options()
        options.inSampleSize = 4 // Reduce size for analysis
        var bitmap = BitmapFactory.decodeFile(imagePath, options)
        
        if (bitmap == null) {
            println("Native: Failed to decode bitmap from path: $imagePath")
            throw IllegalArgumentException("Failed to decode bitmap from path: $imagePath")
        }
        
        println("Native: Initial bitmap size: ${bitmap.width}x${bitmap.height}")
        
        // Handle EXIF orientation
        val exif = ExifInterface(imagePath)
        val orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        println("Native: EXIF orientation: $orientation")
        
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
        }
        
        if (!matrix.isIdentity) {
            bitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            println("Native: Bitmap rotated to: ${bitmap.width}x${bitmap.height}")
        }
        
        return bitmap
    }

    /**
     * Calculate depth variance by analyzing luminance patterns
     * Lower variance suggests flat surface (screen)
     */
    private fun calculateDepthVariance(bitmap: Bitmap): Double {
        val width = bitmap.width
        val height = bitmap.height
        val centerX = width / 2
        val centerY = height / 2
        val radius = minOf(width, height) / 4
        
        val luminances = mutableListOf<Double>()
        
        // Sample luminance in a grid pattern
        for (x in centerX - radius until centerX + radius step 10) {
            for (y in centerY - radius until centerY + radius step 10) {
                if (x >= 0 && x < width && y >= 0 && y < height) {
                    val pixel = bitmap.getPixel(x, y)
                    val r = (pixel shr 16) and 0xFF
                    val g = (pixel shr 8) and 0xFF
                    val b = pixel and 0xFF
                    val luminance = 0.299 * r + 0.587 * g + 0.114 * b
                    luminances.add(luminance)
                }
            }
        }
        
        if (luminances.isEmpty()) return 0.0
        
        val mean = luminances.average()
        val variance = luminances.map { (it - mean).pow(2) }.average()
        
        // FIX: Proper normalization - luminance variance typically ranges 0-10000 for natural images
        // Normalize variance to 0-1 range with correct scaling
        return (variance / 10000.0).coerceIn(0.0, 1.0)
    }

    /**
     * Calculate pixel uniformity using gradient analysis - screens show different gradient patterns
     */
    private fun calculatePixelUniformity(bitmap: Bitmap): Double {
        val width = bitmap.width
        val height = bitmap.height
        
        var totalGradientVariance = 0.0
        var sampleCount = 0
        val gradients = mutableListOf<Double>()
        
        // Calculate gradients across the image (similar to edge detection but for uniformity)
        for (x in 1 until width - 1 step 8) {
            for (y in 1 until height - 1 step 8) {
                val centerPixel = bitmap.getPixel(x, y)
                val centerGray = ((centerPixel shr 16) and 0xFF) * 0.299 + 
                               ((centerPixel shr 8) and 0xFF) * 0.587 + 
                               (centerPixel and 0xFF) * 0.114
                
                // Calculate horizontal and vertical gradients
                val leftPixel = bitmap.getPixel(x - 1, y)
                val rightPixel = bitmap.getPixel(x + 1, y)
                val topPixel = bitmap.getPixel(x, y - 1)
                val bottomPixel = bitmap.getPixel(x, y + 1)
                
                val leftGray = ((leftPixel shr 16) and 0xFF) * 0.299 + 
                              ((leftPixel shr 8) and 0xFF) * 0.587 + 
                              (leftPixel and 0xFF) * 0.114
                val rightGray = ((rightPixel shr 16) and 0xFF) * 0.299 + 
                               ((rightPixel shr 8) and 0xFF) * 0.587 + 
                               (rightPixel and 0xFF) * 0.114
                val topGray = ((topPixel shr 16) and 0xFF) * 0.299 + 
                             ((topPixel shr 8) and 0xFF) * 0.587 + 
                             (topPixel and 0xFF) * 0.114
                val bottomGray = ((bottomPixel shr 16) and 0xFF) * 0.299 + 
                                ((bottomPixel shr 8) and 0xFF) * 0.587 + 
                                (bottomPixel and 0xFF) * 0.114
                
                val gradientMagnitude = sqrt((rightGray - leftGray).pow(2) + (bottomGray - topGray).pow(2))
                gradients.add(gradientMagnitude)
                sampleCount++
            }
        }
        
        if (gradients.isEmpty()) return 0.5
        
        // Calculate variance of gradients - screens tend to have more consistent gradient patterns
        val meanGradient = gradients.average()
        val gradientVariance = gradients.map { (it - meanGradient).pow(2) }.average()
        
        // Normalize: lower gradient variance suggests more uniform (screen-like) patterns
        // Natural photos have more varied gradient patterns
        val uniformityScore = 1.0 - (gradientVariance / 2000.0) // 2000 is typical max variance for natural images
        
        return uniformityScore.coerceIn(0.0, 1.0)
    }

    private fun calculatePatchVariation(bitmap: Bitmap, startX: Int, startY: Int, size: Int): Double {
        val pixels = mutableListOf<Int>()
        
        for (x in startX until minOf(startX + size, bitmap.width)) {
            for (y in startY until minOf(startY + size, bitmap.height)) {
                val pixel = bitmap.getPixel(x, y)
                val gray = ((pixel shr 16) and 0xFF) * 0.299 + 
                          ((pixel shr 8) and 0xFF) * 0.587 + 
                          (pixel and 0xFF) * 0.114
                pixels.add(gray.toInt())
            }
        }
        
        if (pixels.isEmpty()) return 0.0
        
        val mean = pixels.average()
        return pixels.map { abs(it - mean) }.average()
    }

    /**
     * Detect screen reflection patterns - bright spots or glare typical of photographed screens
     */
    private fun detectScreenReflection(bitmap: Bitmap): Boolean {
        val width = bitmap.width
        val height = bitmap.height
        
        var brightSpotCount = 0
        var totalPixels = 0
        
        // Look for bright spots that might indicate screen reflection
        for (x in 0 until width step 5) {
            for (y in 0 until height step 5) {
                val pixel = bitmap.getPixel(x, y)
                val r = (pixel shr 16) and 0xFF
                val g = (pixel shr 8) and 0xFF
                val b = pixel and 0xFF
                
                val brightness = (r + g + b) / 3.0
                
                if (brightness > 240) { // FIX: Much higher threshold - only very bright pixels
                    // Check if surrounded by similar bright pixels (reflection pattern)
                    val surroundingBrightness = checkSurroundingBrightness(bitmap, x, y, 3)
                    if (surroundingBrightness > 220) { // FIX: Higher threshold to avoid natural bright areas
                        brightSpotCount++
                    }
                }
                totalPixels++
            }
        }
        
        // FIX: Require more evidence - 3% of pixels need to show strong reflection patterns
        return totalPixels > 0 && (brightSpotCount.toDouble() / totalPixels) > 0.03
    }

    private fun checkSurroundingBrightness(bitmap: Bitmap, centerX: Int, centerY: Int, radius: Int): Double {
        var totalBrightness = 0.0
        var count = 0
        
        for (x in (centerX - radius)..(centerX + radius)) {
            for (y in (centerY - radius)..(centerY + radius)) {
                if (x >= 0 && x < bitmap.width && y >= 0 && y < bitmap.height) {
                    val pixel = bitmap.getPixel(x, y)
                    val r = (pixel shr 16) and 0xFF
                    val g = (pixel shr 8) and 0xFF
                    val b = pixel and 0xFF
                    totalBrightness += (r + g + b) / 3.0
                    count++
                }
            }
        }
        
        return if (count > 0) totalBrightness / count else 0.0
    }

    /**
     * Calculate edge sharpness - screens often produce softer edges when photographed
     */
    private fun calculateEdgeSharpness(bitmap: Bitmap): Double {
        val width = bitmap.width
        val height = bitmap.height
        
        var totalGradient = 0.0
        var gradientCount = 0
        
        // Apply Sobel edge detection
        for (x in 1 until width - 1) {
            for (y in 1 until height - 1 step 5) { // Sample every 5th row for performance
                val gx = calculateSobelX(bitmap, x, y)
                val gy = calculateSobelY(bitmap, x, y)
                val gradient = sqrt(gx * gx + gy * gy)
                
                totalGradient += gradient
                gradientCount++
            }
        }
        
        if (gradientCount == 0) return 0.0
        
        val averageGradient = totalGradient / gradientCount
        
        // Normalize to 0-1 range (higher values = sharper edges)
        return (averageGradient / 255.0).coerceIn(0.0, 1.0)
    }

    private fun calculateSobelX(bitmap: Bitmap, x: Int, y: Int): Double {
        val pixels = Array(3) { IntArray(3) }
        
        for (i in -1..1) {
            for (j in -1..1) {
                val pixelX = x + i
                val pixelY = y + j
                // Add bounds checking
                if (pixelX >= 0 && pixelX < bitmap.width && pixelY >= 0 && pixelY < bitmap.height) {
                    val pixel = bitmap.getPixel(pixelX, pixelY)
                    pixels[i + 1][j + 1] = ((pixel shr 16) and 0xFF) // Use red channel
                } else {
                    pixels[i + 1][j + 1] = 0 // Use 0 for out-of-bounds pixels
                }
            }
        }
        
        return (-pixels[0][0] - 2 * pixels[0][1] - pixels[0][2] +
                pixels[2][0] + 2 * pixels[2][1] + pixels[2][2]).toDouble()
    }

    private fun calculateSobelY(bitmap: Bitmap, x: Int, y: Int): Double {
        val pixels = Array(3) { IntArray(3) }
        
        for (i in -1..1) {
            for (j in -1..1) {
                val pixelX = x + i
                val pixelY = y + j
                // Add bounds checking
                if (pixelX >= 0 && pixelX < bitmap.width && pixelY >= 0 && pixelY < bitmap.height) {
                    val pixel = bitmap.getPixel(pixelX, pixelY)
                    pixels[i + 1][j + 1] = ((pixel shr 16) and 0xFF) // Use red channel
                } else {
                    pixels[i + 1][j + 1] = 0 // Use 0 for out-of-bounds pixels
                }
            }
        }
        
        return (-pixels[0][0] - 2 * pixels[1][0] - pixels[2][0] +
                pixels[0][2] + 2 * pixels[1][2] + pixels[2][2]).toDouble()
    }
}
