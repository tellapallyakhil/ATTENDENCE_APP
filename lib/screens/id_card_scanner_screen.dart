import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/student.dart';
import '../services/id_card_ocr_service.dart';
import '../services/local_storage_service.dart';
import '../services/firestore_service.dart';

class IDCardScannerScreen extends StatefulWidget {
  const IDCardScannerScreen({super.key});

  @override
  State<IDCardScannerScreen> createState() => _IDCardScannerScreenState();
}

class _IDCardScannerScreenState extends State<IDCardScannerScreen> {
  final IDCardOCRService _ocrService = IDCardOCRService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isProcessing = false;
  bool _isSyncing = false;
  
  String? _extractedName;
  String? _extractedRegNo;
  String? _errorMessage;
  
  ScanResult? _scanResult;
  Student? _foundStudent;

  @override
  void initState() {
    super.initState();
    _localStorageService.init();
  }

  /// Sync local storage with Firestore data
  Future<void> _syncWithFirestore() async {
    setState(() => _isSyncing = true);
    
    try {
      final firestoreStudents = await _firestoreService.getStudentsOnce();
      await _localStorageService.syncFromFirestore(firestoreStudents);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Synced ${firestoreStudents.length} students'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    if (mounted) setState(() => _isSyncing = false);
  }

  /// Pick image - optimized for speed
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1280, // Reduced for faster processing
        maxHeight: 1280,
        imageQuality: 80, // Slightly lower quality for speed
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _extractedName = null;
          _extractedRegNo = null;
          _errorMessage = null;
          _scanResult = null;
          _foundStudent = null;
          _isProcessing = true;
        });

        // Process immediately
        await _processIDCard();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    }
  }

  /// Process ID card - optimized
  Future<void> _processIDCard() async {
    if (_selectedImage == null) return;

    try {
      final result = await _ocrService.extractIDCardInfo(_selectedImage!.path);
      
      _extractedName = result['name'];
      _extractedRegNo = result['regNo'];

      // Immediately check if student exists
      await _checkStudentExists();
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error processing: $e';
      });
    }
  }

  /// Check if student exists - fast lookup
  Future<void> _checkStudentExists() async {
    if (_extractedName == null && _extractedRegNo == null) {
      setState(() {
        _isProcessing = false;
        _scanResult = ScanResult.noDataFound;
      });
      return;
    }

    final student = await _localStorageService.findStudent(_extractedName, _extractedRegNo);

    if (student != null) {
      // Mark present immediately
      if (_extractedRegNo != null) {
        await _localStorageService.markPresent(_extractedRegNo!);
      } else if (_extractedName != null) {
        await _localStorageService.markPresentByName(_extractedName!);
      }
      
      HapticFeedback.heavyImpact();
      
      setState(() {
        _isProcessing = false;
        _scanResult = ScanResult.studentFound;
        _foundStudent = student;
      });
    } else {
      HapticFeedback.mediumImpact();
      
      setState(() {
        _isProcessing = false;
        _scanResult = ScanResult.studentNotFound;
        _foundStudent = null;
      });
    }
  }

  /// Register new student - fast
  Future<void> _registerNewStudent() async {
    if (_extractedName == null || _extractedRegNo == null) {
      _showManualEntryDialog();
      return;
    }

    final newStudent = Student(
      name: _extractedName!,
      regNo: _extractedRegNo!,
      isPresent: true,
      timestamp: DateTime.now(),
    );

    await _localStorageService.addStudent(newStudent);
    
    // Try Firestore in background (non-blocking)
    _firestoreService.addStudent(newStudent).catchError((_) {});

    HapticFeedback.heavyImpact();

    setState(() {
      _scanResult = ScanResult.studentRegistered;
      _foundStudent = newStudent;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${_extractedName} registered!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showManualEntryDialog() {
    final nameController = TextEditingController(text: _extractedName ?? '');
    final regController = TextEditingController(text: _extractedRegNo ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Register Student', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: regController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reg. No',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () async {
              if (nameController.text.isNotEmpty && regController.text.isNotEmpty) {
                Navigator.pop(context);
                _extractedName = nameController.text.toUpperCase();
                _extractedRegNo = regController.text;
                await _registerNewStudent();
              }
            },
            child: const Text('Register', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _selectedImage = null;
      _extractedName = null;
      _extractedRegNo = null;
      _errorMessage = null;
      _scanResult = null;
      _foundStudent = null;
    });
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'ID Card Scanner',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _syncWithFirestore,
            icon: _isSyncing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
              : const Icon(Icons.sync),
            tooltip: 'Sync offline',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scan Buttons - Large touch targets
              Row(
                children: [
                  Expanded(child: _buildScanButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.purple,
                    onTap: () => _pickImage(ImageSource.camera),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildScanButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.cyan,
                    onTap: () => _pickImage(ImageSource.gallery),
                  )),
                ],
              ),

              const SizedBox(height: 16),

              // Image Preview
              if (_selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

              // Processing
              if (_isProcessing)
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.cyanAccent),
                      const SizedBox(height: 12),
                      Text('Scanning...', style: GoogleFonts.outfit(color: Colors.white70)),
                    ],
                  ),
                ),

              // Error
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                ),

              // Result
              if (_scanResult != null && !_isProcessing)
                _buildResultCard(),

              // Extracted Data
              if (_extractedName != null || _extractedRegNo != null)
                _buildExtractedData(),

              const SizedBox(height: 16),

              // Action Buttons
              if (_scanResult != null && !_isProcessing)
                _buildActions(),

              // Empty State
              if (_selectedImage == null && _scanResult == null)
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 6),
              Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    Color color;
    IconData icon;
    String title;
    String message;

    switch (_scanResult) {
      case ScanResult.studentFound:
        color = Colors.green;
        icon = Icons.check_circle;
        title = 'PRESENT ✓';
        message = _foundStudent?.name ?? _extractedName ?? '';
        break;
      case ScanResult.studentNotFound:
        color = Colors.orange;
        icon = Icons.person_search;
        title = 'Not Found';
        message = 'Student not in list. Register?';
        break;
      case ScanResult.studentRegistered:
        color = Colors.blue;
        icon = Icons.person_add;
        title = 'Registered ✓';
        message = _foundStudent?.name ?? '';
        break;
      case ScanResult.noDataFound:
        color = Colors.red;
        icon = Icons.warning;
        title = 'Cannot Read';
        message = 'Try a clearer photo';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                if (message.isNotEmpty)
                  Text(message, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedData() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_extractedName != null)
            Row(
              children: [
                const Icon(Icons.person, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _extractedName!,
                    style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          if (_extractedRegNo != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.numbers, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  _extractedRegNo!,
                  style: GoogleFonts.outfit(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        if (_scanResult == ScanResult.studentNotFound)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _registerNewStudent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: Text('Register', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resetScanner,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.cyanAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.qr_code_scanner, color: Colors.cyanAccent),
            label: Text('Scan Next', style: GoogleFonts.outfit(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Icon(Icons.credit_card, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Scan ID Card',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture or select ID card photo',
            style: GoogleFonts.outfit(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _tip('Name (RED) will be detected'),
                _tip('Reg. No (digits) extracted'),
                _tip('Works 100% offline'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.cyanAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}

enum ScanResult { studentFound, studentNotFound, studentRegistered, noDataFound }
