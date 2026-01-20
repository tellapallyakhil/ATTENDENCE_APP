import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'dart:io'; // Check Platform.isAndroid/iOS
import 'dart:ui';

class MLService {
  FaceDetector? _faceDetector;

  MLService() {
    // Only initialize FaceDetector on supported mobile platforms
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableClassification: true,
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
    }
  }

  bool _isBusy = false;

  Future<List<Face>?> processImage(CameraImage image, int sensorOrientation, CameraLensDirection cameraLensDirection) async {
    if (_faceDetector == null) return null; // Not supported
    if (_isBusy) return null;
    _isBusy = true;

    final inputImage = _inputImageFromCameraImage(image, sensorOrientation, cameraLensDirection);
    if (inputImage == null) {
      _isBusy = false;
      return null;
    }

    try {
      final faces = await _faceDetector!.processImage(inputImage);
      _isBusy = false;
      return faces;
    } catch (e) {
      print('Error processing face detection: $e');
      _isBusy = false;
      return null;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, int sensorOrientation, CameraLensDirection cameraLensDirection) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

    final imageRotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (imageRotation == null) return null;

    final inputImageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  void dispose() {
    _faceDetector?.close();
  }
}
