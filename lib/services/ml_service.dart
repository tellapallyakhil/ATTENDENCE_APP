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
  static const int _frameSkip = 3; // Process every 3rd frame for better performance

  MLService() {
    _initializeDetector();
  }

  void _initializeDetector() {
    if (kIsWeb) return;
    
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.fast,
            enableContours: false,
            enableClassification: true,
            enableLandmarks: false,
            enableTracking: true,
            minFaceSize: 0.1, // Detect smaller faces too
          ),
        );
      }
    } catch (e) {
      debugPrint('MLService init error: $e');
    }
  }

  /// Process camera frame with performance optimizations
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

      final faces = await _faceDetector!.processImage(inputImage);
      _isBusy = false;
      return faces;
    } catch (e) {
      debugPrint('Face detection error: $e');
      _isBusy = false;
      return null;
    }
  }

  /// Process a static image file (from gallery/camera capture)
  Future<List<Face>?> processImageFile(String filePath) async {
    if (_faceDetector == null) return null;
    
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final faces = await _faceDetector!.processImage(inputImage);
      return faces;
    } catch (e) {
      debugPrint('Face detection from file error: $e');
      return null;
    }
  }

  /// Robust camera image conversion - handles multiple Android formats
  InputImage? _convertCameraImage(
    CameraImage image, 
    int sensorOrientation, 
    CameraLensDirection lensDirection
  ) {
    // Try to get format from raw value
    InputImageFormat? format;
    
    if (Platform.isAndroid) {
      // Android: YUV420 format (raw value 35 = YUV_420_888)
      format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) {
        // Fallback: assume nv21 for Android (most common)
        format = InputImageFormat.nv21;
      }
    } else if (Platform.isIOS) {
      // iOS: BGRA8888 format
      format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) {
        format = InputImageFormat.bgra8888;
      }
    }
    
    if (format == null) return null;

    // Concatenate all planes into a single byte array
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

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

  /// Get face analysis data
  Map<String, dynamic>? analyzeFace(Face face) {
    return {
      'trackingId': face.trackingId,
      'smileProb': face.smilingProbability ?? 0.0,
      'leftEyeOpen': face.leftEyeOpenProbability ?? 0.0,
      'rightEyeOpen': face.rightEyeOpenProbability ?? 0.0,
      'headAngleY': face.headEulerAngleY ?? 0.0,
      'headAngleZ': face.headEulerAngleZ ?? 0.0,
      'boundingBox': face.boundingBox,
    };
  }

  void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
  }
}
