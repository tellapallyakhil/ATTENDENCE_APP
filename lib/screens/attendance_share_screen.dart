import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/student.dart';

/// Mobile-optimized Attendance Share Screen
/// Allows sharing absentees or presentees with subject name and time period
class AttendanceShareScreen extends StatefulWidget {
  final List<Student> allStudents;

  const AttendanceShareScreen({
    super.key,
    required this.allStudents,
  });

  @override
  State<AttendanceShareScreen> createState() => _AttendanceShareScreenState();
}

class _AttendanceShareScreenState extends State<AttendanceShareScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _periodController = TextEditingController();
  bool _showAbsentees = true;
  
  // Cache lists to avoid recalculating
  late final List<Student> _absentees;
  late final List<Student> _presentees;
  
  @override
  void initState() {
    super.initState();
    // Pre-compute lists once
    _absentees = widget.allStudents.where((s) => !s.isPresent).toList();
    _presentees = widget.allStudents.where((s) => s.isPresent).toList();
  }
  
  List<Student> get selectedStudents => _showAbsentees ? _absentees : _presentees;

  @override
  void dispose() {
    _subjectController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  void _shareMessage() {
    final subject = _subjectController.text.trim().isEmpty 
        ? 'General' 
        : _subjectController.text.trim();
    final period = _periodController.text.trim().isEmpty 
        ? '' 
        : ' (${_periodController.text.trim()})';
    final date = DateFormat('dd MMM yyyy').format(DateTime.now());
    final type = _showAbsentees ? 'Absentees' : 'Presentees';
    
    final StringBuffer message = StringBuffer();
    message.writeln('📋 *$type Report*');
    message.writeln('━━━━━━━━━━━━━━');
    message.writeln('📚 Subject: $subject$period');
    message.writeln('📅 Date: $date');
    message.writeln('👥 Total: ${selectedStudents.length}');
    message.writeln('━━━━━━━━━━━━━━');
    message.writeln('');
    message.writeln('*Reg. Numbers:*');
    message.writeln(selectedStudents.map((s) => s.regNo).join(', '));
    message.writeln('');
    message.writeln('_Smart Attendance App_');
    
    Share.share(message.toString());
  }

  @override
  Widget build(BuildContext context) {
    final isAbsent = _showAbsentees;
    final color = isAbsent ? Colors.redAccent : Colors.green;
    final bgColor = isAbsent ? Colors.red.shade50 : Colors.green.shade50;
    final textColor = isAbsent ? Colors.red.shade900 : Colors.green.shade900;
    final regNumbers = selectedStudents.map((s) => s.regNo).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: color,
        elevation: 0,
        title: Text(
          isAbsent ? 'Absentees' : 'Presentees',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareMessage,
          ),
        ],
      ),
      body: Column(
        children: [
          // Toggle & Input Section (Fixed height for performance)
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Toggle Buttons
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildToggle('Absent (${_absentees.length})', true, Colors.redAccent),
                      _buildToggle('Present (${_presentees.length})', false, Colors.green),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Input Fields
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(_subjectController, 'Subject', 'e.g., Maths'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(_periodController, 'Period', '4-6'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: bgColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${selectedStudents.length}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                  style: GoogleFonts.outfit(color: textColor.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          
          // Registration Numbers (Scrollable)
          Expanded(
            child: selectedStudents.isEmpty
              ? Center(
                  child: Text(
                    isAbsent ? '🎉 No Absentees!' : '😔 No Presentees',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: regNumbers.map((regNo) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        regNo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
          ),
          
          // Share Button (Fixed at bottom)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _shareMessage,
                  icon: const Icon(Icons.share, size: 20),
                  label: Text(
                    'Share ${isAbsent ? 'Absentees' : 'Presentees'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool isAbsentToggle, Color color) {
    final isSelected = _showAbsentees == isAbsentToggle;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showAbsentees = isAbsentToggle),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          labelStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
