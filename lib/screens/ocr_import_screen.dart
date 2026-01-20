import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/student.dart';
import '../services/ocr_service.dart';
import '../services/firestore_service.dart';

class OCRImportScreen extends StatefulWidget {
  const OCRImportScreen({super.key});

  @override
  State<OCRImportScreen> createState() => _OCRImportScreenState();
}

class _OCRImportScreenState extends State<OCRImportScreen> {
  final OCRService _ocrService = OCRService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  List<Map<String, String>> _extractedStudents = [];
  Set<int> _selectedIndices = {};
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _extractedStudents = [];
          _selectedIndices = {};
          _errorMessage = null;
        });

        await _processImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final students = await _ocrService.extractStudentsFromImage(_selectedImage!.path);

      setState(() {
        _extractedStudents = students;
        _selectedIndices = Set.from(List.generate(students.length, (i) => i)); // Select all by default
        _isProcessing = false;
      });

      if (students.isEmpty) {
        setState(() {
          _errorMessage = 'No students found in the image. Try a clearer photo.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error processing image: $e';
      });
    }
  }

  void _addSelectedStudents() async {
    final selectedStudents = _selectedIndices.map((i) => _extractedStudents[i]).toList();

    for (final data in selectedStudents) {
      await _firestoreService.addStudent(Student(
        name: data['name']!,
        regNo: data['regNo']!,
        isPresent: true,
        timestamp: DateTime.now(),
      ));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${selectedStudents.length} students!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Scan Student List',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Selection Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Image Preview
              if (_selectedImage != null)
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Processing Indicator
              if (_isProcessing)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Colors.cyanAccent),
                      SizedBox(height: 12),
                      Text(
                        'Extracting text...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Extracted Students List
              if (_extractedStudents.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Found ${_extractedStudents.length} students',
                        style: GoogleFonts.outfit(
                          color: Colors.cyanAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedIndices.length == _extractedStudents.length) {
                              _selectedIndices.clear();
                            } else {
                              _selectedIndices = Set.from(List.generate(_extractedStudents.length, (i) => i));
                            }
                          });
                        },
                        child: Text(
                          _selectedIndices.length == _extractedStudents.length ? 'Deselect All' : 'Select All',
                          style: const TextStyle(color: Colors.cyanAccent),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: _extractedStudents.length,
                    itemBuilder: (context, index) {
                      final student = _extractedStudents[index];
                      final isSelected = _selectedIndices.contains(index);

                      return Card(
                        color: isSelected ? Colors.cyan.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIndices.add(index);
                                } else {
                                  _selectedIndices.remove(index);
                                }
                              });
                            },
                            activeColor: Colors.cyanAccent,
                            checkColor: Colors.black,
                          ),
                          title: Text(
                            student['name']!,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            student['regNo']!,
                            style: GoogleFonts.outfit(color: Colors.white54),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                            onPressed: () => _editStudent(index),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Add Button
                ElevatedButton.icon(
                  onPressed: _selectedIndices.isEmpty ? null : _addSelectedStudents,
                  icon: const Icon(Icons.add),
                  label: Text('Add ${_selectedIndices.length} Students'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              // Empty State
              if (_selectedImage == null && _extractedStudents.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.document_scanner,
                          size: 80,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scan a class list to import students',
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editStudent(int index) {
    final student = _extractedStudents[index];
    final nameController = TextEditingController(text: student['name']);
    final regController = TextEditingController(text: student['regNo']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Edit Student', style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
            TextField(
              controller: regController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reg No',
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
            onPressed: () {
              setState(() {
                _extractedStudents[index] = {
                  'name': nameController.text,
                  'regNo': regController.text,
                };
              });
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
