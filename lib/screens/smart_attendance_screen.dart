import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ml_service.dart';
import 'dart:math' as math;

class SmartAttendanceScreen extends StatefulWidget {
  const SmartAttendanceScreen({super.key});

  @override
  State<SmartAttendanceScreen> createState() => _SmartAttendanceScreenState();
}

class _SmartAttendanceScreenState extends State<SmartAttendanceScreen> {
  CameraController? _controller;
  MLService _mlService = MLService();
  bool _isCameraInitialized = false;
  List<Face> _faces = [];
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Camera permission is required')),
         );
       }
       return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugPrint('No cameras found');
      return;
    }

    final firstCamera = cameras.firstWhere(
      (c) => c.lensDirection == _cameraLensDirection,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium, // Lower resolution for better performance/compatibility
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      _controller!.startImageStream((image) async {
         if (_controller == null) return;
         try {
           final faces = await _mlService.processImage(
             image, 
             _controller!.description.sensorOrientation,
             _cameraLensDirection
           );
           if (faces != null && mounted) {
             setState(() {
               _faces = faces;
             });
           }
         } catch (e) {
           debugPrint("Error processing image: $e");
         }
      });
    } catch (e) {
       debugPrint("Error initializing camera: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _mlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text("Not Supported"), backgroundColor: Colors.transparent),
        body: Center(
          child: Text(
            'Face Detection is only supported on Android & iOS devices.',
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          if (_faces.isNotEmpty)
            CustomPaint(
              painter: FacePainter(
                faces: _faces,
                imageSize: Size(
                  _controller!.value.previewSize!.height, // Swap W/H for portrait
                  _controller!.value.previewSize!.width,
                ),
                widgetSize: MediaQuery.of(context).size,
              ),
            ),
          
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.face, color: Colors.white, size: 28),
                   const SizedBox(width: 12),
                   Text(
                     '${_faces.length} Faces Detected',
                     style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                   ),
                ],
              ),
            ),
          ),
          
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                onPressed: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final Size widgetSize;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    for (final face in faces) {
      final rect = _scaleRect(
        rect: face.boundingBox,
        imageSize: imageSize,
        widgetSize: widgetSize,
      );
      canvas.drawRect(rect, paint);
    }
  }
  
  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
  }) {
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;

    // For front camera, we might need to mirror X, but let's keep it simple for now or assume back camera.
    // If it's front camera (selfie), usually we flip X.
    // Let's assume standard scaling.
    
    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
