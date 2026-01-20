import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';

/// High-performance ML Service for Face Detection
/// Uses Google ML Kit with optimized settings for real-time processing
class MLService {
  FaceDetector? _faceDetector;
  bool _isBusy = false;
  
  // Frame skipping for performance - process every Nth frame
  int _frameCount = 0;
  static const int _frameSkip = 2; // Process every 2nd frame for better performance

  MLService() {
    _initializeDetector();
  }

  void _initializeDetector() {
    if (kIsWeb) return;
    
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            // FAST mode for real-time performance
            performanceMode: FaceDetectorMode.fast,
            // Disable heavy features for speed
            enableContours: false,
            enableClassification: true, // Keep for smile/eye detection
            enableLandmarks: false, // Disable for speed
            enableTracking: true, // Enable tracking for consistent IDs
            minFaceSize: 0.15, // Minimum face size relative to image
          ),
        );
      }
    } catch (e) {
      debugPrint('MLService init error: $e');
    }
  }

  /// Process camera frame with performance optimizations
  /// Returns null if busy or frame should be skipped
  Future<List<Face>?> processImage(
    CameraImage image, 
    int sensorOrientation, 
    CameraLensDirection cameraLensDirection
  ) async {
    if (_faceDetector == null) return null;
    if (_isBusy) return null;
    
    // Frame skipping for performance
    _frameCount++;
    if (_frameCount % _frameSkip != 0) return null;
    
    _isBusy = true;

    try {
      final inputImage = _convertCameraImage(image, sensorOrientation, cameraLensDirection);
      if (inputImage == null) {
        _isBusy = false;
        return null;
      }

      // Run face detection in isolate for better UI performance
      final faces = await _faceDetector!.processImage(inputImage);
      _isBusy = false;
      return faces;
    } catch (e) {
      debugPrint('Face detection error: $e');
      _isBusy = false;
      return null;
    }
  }

  /// Optimized camera image conversion
  InputImage? _convertCameraImage(
    CameraImage image, 
    int sensorOrientation, 
    CameraLensDirection lensDirection
  ) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Use direct byte concatenation for speed
    final int totalBytes = image.planes.fold(0, (sum, plane) => sum + plane.bytes.length);
    final bytes = Uint8List(totalBytes);
    int offset = 0;
    for (final plane in image.planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }

    final imageRotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (imageRotation == null) return null;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  /// Get face analysis data (smile probability, eye open probability)
  Map<String, dynamic>? analyzeFace(Face face) {
    return {
      'trackingId': face.trackingId,
      'smileProb': face.smilingProbability ?? 0.0,
      'leftEyeOpen': face.leftEyeOpenProbability ?? 0.0,
      'rightEyeOpen': face.rightEyeOpenProbability ?? 0.0,
      'headAngleY': face.headEulerAngleY ?? 0.0, // Looking left/right
      'headAngleZ': face.headEulerAngleZ ?? 0.0, // Tilting head
      'boundingBox': face.boundingBox,
    };
  }

  void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
  }
}
