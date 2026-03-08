import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ml_service.dart';
import '../services/firestore_service.dart';
import '../models/student.dart';

class SmartAttendanceScreen extends StatefulWidget {
  const SmartAttendanceScreen({super.key});

  @override
  State<SmartAttendanceScreen> createState() => _SmartAttendanceScreenState();
}

class _SmartAttendanceScreenState extends State<SmartAttendanceScreen> 
    with WidgetsBindingObserver {
  CameraController? _controller;
  late MLService _mlService;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  List<Face> _faces = [];
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;
  Size? _previewSize;
  String? _errorMessage;
  
  // Track detected face count per capture
  int _totalDetected = 0;

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
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    if (state == AppLifecycleState.inactive) {
      _stopImageStream();
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  void _stopImageStream() {
    try {
      if (_controller?.value.isStreamingImages ?? false) {
        _controller?.stopImageStream();
      }
    } catch (e) {
      debugPrint('Stop stream error: $e');
    }
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() => _errorMessage = 'Camera permission denied. Please enable it in Settings.');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras found on this device.');
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == _cameraLensDirection,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.nv21 
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

      _previewSize = _controller!.value.previewSize;
      
      setState(() {
        _isCameraInitialized = true;
        _errorMessage = null;
      });

      // Start live face detection
      await _controller!.startImageStream(_processFrame);
    } catch (e) {
      debugPrint("Camera init error: $e");
      setState(() => _errorMessage = 'Camera error: ${e.toString().split('\n').first}');
    }
  }

  /// Optimized frame processing
  void _processFrame(CameraImage image) async {
    if (_controller == null || !mounted || _isDetecting) return;
    _isDetecting = true;
    
    try {
      final faces = await _mlService.processImage(
        image,
        _controller!.description.sensorOrientation,
        _cameraLensDirection,
      );
      
      if (faces != null && mounted) {
        if (_faces.length != faces.length) {
          setState(() => _faces = faces);
        }
      }
    } catch (e) {
      // Silently handle frame errors
    }
    _isDetecting = false;
  }

  /// Capture photo and detect faces from static image (more reliable)
  Future<void> _captureAndDetect() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Stop stream before capture
      _stopImageStream();
      
      final XFile photo = await _controller!.takePicture();
      
      // Detect faces from the captured image (more accurate)
      final faces = await _mlService.processImageFile(photo.path);
      
      if (faces != null && faces.isNotEmpty && mounted) {
        setState(() {
          _totalDetected = faces.length;
        });
        
        _showDetectionResult(faces.length, photo.path);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No faces detected. Try again with better lighting.'),
            backgroundColor: Colors.orange,
          ),
        );
        // Restart stream
        await _controller!.startImageStream(_processFrame);
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture error: $e'), backgroundColor: Colors.redAccent),
        );
      }
      // Restart stream  
      try { await _controller!.startImageStream(_processFrame); } catch (_) {}
    }
  }

  /// Show detection result and mark attendance
  void _showDetectionResult(int faceCount, String imagePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
            const SizedBox(width: 10),
            Text('$faceCount Face${faceCount > 1 ? "s" : ""} Detected',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show captured image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(imagePath), height: 200, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            Text(
              '$faceCount student${faceCount > 1 ? "s" : ""} detected.\nMark all as present?',
              style: GoogleFonts.outfit(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restartStream();
            },
            child: const Text('Retake', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Mark Present'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _markFacesPresent(faceCount);
            },
          ),
        ],
      ),
    );
  }

  /// Mark detected faces as present
  Future<void> _markFacesPresent(int count) async {
    try {
      // Get all students
      final students = await _firestoreService.getStudentsOnce();
      
      // Show student picker - let user select which students were detected
      if (!mounted) return;
      
      _showStudentPicker(students, count);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
      _restartStream();
    }
  }

  /// Show student picker to select detected students
  void _showStudentPicker(List<Student> students, int detectedCount) {
    final selected = <int>{};
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Select Students ($detectedCount detected)',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Tap to mark as present',
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: students.length,
                  itemBuilder: (_, i) {
                    final s = students[i];
                    final isSelected = selected.contains(i);
                    return GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          if (isSelected) {
                            selected.remove(i);
                          } else {
                            selected.add(i);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.greenAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.greenAccent.withOpacity(0.5) : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? Colors.greenAccent : Colors.white38,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                                  Text(s.regNo, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (s.isPresent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                child: const Text('Present', style: TextStyle(color: Colors.green, fontSize: 10)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Mark button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: Text('Mark ${selected.length} Present'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected.isEmpty ? Colors.grey : Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: selected.isEmpty ? null : () async {
                      for (final i in selected) {
                        final s = students[i];
                        if (s.docId != null) {
                          await _firestoreService.updateAttendance(s.docId!, true);
                        }
                      }
                      Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Marked ${selected.length} students present'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      _restartStream();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => _restartStream());
  }

  void _restartStream() async {
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        if (!(_controller!.value.isStreamingImages)) {
          await _controller!.startImageStream(_processFrame);
        }
      }
    } catch (e) {
      debugPrint('Restart stream error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopImageStream();
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
              const Icon(Icons.no_photography, size: 80, color: Colors.white24),
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

    // Error state
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(_errorMessage!, 
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    setState(() => _errorMessage = null);
                    _initializeCamera();
                  },
                ),
              ],
            ),
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
              Text('Initializing Camera...', style: GoogleFonts.outfit(color: Colors.white70)),
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
          // Camera Preview
          RepaintBoundary(child: CameraPreview(_controller!)),
          
          // Face Bounding Boxes
          if (_faces.isNotEmpty && _previewSize != null)
            RepaintBoundary(
              child: CustomPaint(
                painter: FacePainter(
                  faces: _faces,
                  imageSize: Size(_previewSize!.height, _previewSize!.width),
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
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (_faces.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 8)],
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
        // Switch Camera
        FloatingActionButton(
          heroTag: 'switch',
          backgroundColor: Colors.white24,
          onPressed: _switchCamera,
          child: const Icon(Icons.flip_camera_ios, color: Colors.white),
        ),
        
        // Capture Button (main action)
        GestureDetector(
          onTap: _faces.isNotEmpty ? _captureAndDetect : null,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              color: _faces.isNotEmpty ? Colors.greenAccent : Colors.grey.withOpacity(0.3),
            ),
            child: Icon(
              Icons.camera,
              color: _faces.isNotEmpty ? Colors.black : Colors.white54,
              size: 36,
            ),
          ),
        ),
        
        // Close
        FloatingActionButton(
          heroTag: 'close',
          backgroundColor: Colors.redAccent,
          onPressed: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    );
  }

  void _switchCamera() async {
    _cameraLensDirection = _cameraLensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    
    _stopImageStream();
    await _controller?.dispose();
    _controller = null;
    
    setState(() {
      _isCameraInitialized = false;
      _faces = [];
    });
    
    await _initializeCamera();
  }
}

/// Optimized Face Painter
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
    if (faces.length != oldDelegate.faces.length) return true;
    for (int i = 0; i < faces.length; i++) {
      if (faces[i].trackingId != oldDelegate.faces[i].trackingId) return true;
    }
    return false;
  }
}
