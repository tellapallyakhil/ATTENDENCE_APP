import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ml_service.dart';

class SmartAttendanceScreen extends StatefulWidget {
  const SmartAttendanceScreen({super.key});

  @override
  State<SmartAttendanceScreen> createState() => _SmartAttendanceScreenState();
}

class _SmartAttendanceScreenState extends State<SmartAttendanceScreen> 
    with WidgetsBindingObserver {
  CameraController? _controller;
  late MLService _mlService;
  bool _isCameraInitialized = false;
  List<Face> _faces = [];
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;
  Size? _previewSize;
  
  // Performance: Track detected face IDs to avoid duplicate processing
  final Set<int> _detectedFaceIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mlService = MLService();
    
    if (defaultTargetPlatform == TargetPlatform.android || 
        defaultTargetPlatform == TargetPlatform.iOS) {
      _initializeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle for camera resource management
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
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
    if (cameras.isEmpty) return;

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == _cameraLensDirection,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // Balance quality and performance
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;

      _previewSize = _controller!.value.previewSize;
      
      setState(() {
        _isCameraInitialized = true;
      });

      // Start image stream with optimized processing
      _controller!.startImageStream(_processFrame);
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  /// Optimized frame processing
  void _processFrame(CameraImage image) async {
    if (_controller == null || !mounted) return;
    
    try {
      final faces = await _mlService.processImage(
        image,
        _controller!.description.sensorOrientation,
        _cameraLensDirection,
      );
      
      if (faces != null && mounted) {
        // Track face IDs for ML recognition
        for (final face in faces) {
          if (face.trackingId != null) {
            _detectedFaceIds.add(face.trackingId!);
          }
        }
        
        // Only update UI if faces changed
        if (_faces.length != faces.length || faces.isNotEmpty) {
          setState(() {
            _faces = faces;
          });
        }
      }
    } catch (e) {
      // Silently handle frame processing errors
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _mlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Not supported on web/desktop
    if (defaultTargetPlatform != TargetPlatform.android && 
        defaultTargetPlatform != TargetPlatform.iOS) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text("Smart Attendance"),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.no_photography, size: 80, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                'Face Detection requires\nAndroid or iOS device',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Loading state
    if (!_isCameraInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.cyanAccent),
              const SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview with RepaintBoundary for performance
          RepaintBoundary(
            child: CameraPreview(_controller!),
          ),
          
          // Face Bounding Boxes
          if (_faces.isNotEmpty && _previewSize != null)
            RepaintBoundary(
              child: CustomPaint(
                painter: FacePainter(
                  faces: _faces,
                  imageSize: Size(
                    _previewSize!.height, // Swap for portrait
                    _previewSize!.width,
                  ),
                  widgetSize: screenSize,
                  isFrontCamera: _cameraLensDirection == CameraLensDirection.front,
                ),
              ),
            ),
          
          // Top Status Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: _buildStatusBar(),
          ),
          
          // Bottom Controls
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: _faces.isNotEmpty ? Colors.greenAccent.withOpacity(0.5) : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.face_retouching_natural,
            color: _faces.isNotEmpty ? Colors.greenAccent : Colors.white54,
            size: 24,
          ),
          const SizedBox(width: 10),
          Text(
            _faces.isEmpty 
              ? 'Scanning...' 
              : '${_faces.length} Face${_faces.length > 1 ? 's' : ''} Detected',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_faces.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Switch Camera Button
        FloatingActionButton(
          heroTag: 'switch',
          backgroundColor: Colors.white24,
          onPressed: _switchCamera,
          child: const Icon(Icons.flip_camera_ios, color: Colors.white),
        ),
        
        // Close Button
        FloatingActionButton(
          heroTag: 'close',
          backgroundColor: Colors.redAccent,
          onPressed: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.white),
        ),
        
        // Capture/Mark Attendance Button
        FloatingActionButton(
          heroTag: 'capture',
          backgroundColor: _faces.isNotEmpty ? Colors.greenAccent : Colors.grey,
          onPressed: _faces.isNotEmpty ? _markAttendance : null,
          child: Icon(
            Icons.check,
            color: _faces.isNotEmpty ? Colors.black : Colors.white54,
          ),
        ),
      ],
    );
  }

  void _switchCamera() async {
    _cameraLensDirection = _cameraLensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    
    await _controller?.dispose();
    setState(() {
      _isCameraInitialized = false;
      _faces = [];
    });
    
    await _initializeCamera();
  }

  void _markAttendance() {
    // TODO: Implement face matching with stored embeddings
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_faces.length} face(s) captured for attendance'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

/// Optimized Face Painter with caching
class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final Size widgetSize;
  final bool isFrontCamera;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.widgetSize,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;
    
    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.greenAccent.withOpacity(0.1);

    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;

    for (final face in faces) {
      Rect rect = face.boundingBox;
      
      // Mirror for front camera
      if (isFrontCamera) {
        rect = Rect.fromLTRB(
          imageSize.width - rect.right,
          rect.top,
          imageSize.width - rect.left,
          rect.bottom,
        );
      }
      
      final scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );
      
      // Draw fill and border
      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledRect, const Radius.circular(8)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledRect, const Radius.circular(8)),
        boxPaint,
      );
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    // Only repaint if faces actually changed
    if (faces.length != oldDelegate.faces.length) return true;
    for (int i = 0; i < faces.length; i++) {
      if (faces[i].trackingId != oldDelegate.faces[i].trackingId) return true;
    }
    return false;
  }
}
