import 'package:attendance_app/screens/smart_attendance_screen.dart';
import 'package:attendance_app/screens/manual_attendance_screen.dart';
import 'package:attendance_app/screens/id_card_scanner_screen.dart';
import 'package:attendance_app/screens/attendance_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firestore_service.dart';
import '../models/student.dart';
import 'preview_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    final Color primaryColor = Colors.cyanAccent;
    final Color secondaryColor = Colors.tealAccent;
    final List<Color> gradientColors = [
      const Color(0xFF0F172A),
      const Color(0xFF1E293B),
      const Color(0xFF334155),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back',
                            style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
                          ),
                          Text(
                            'Professor',
                            style: GoogleFonts.outfit(
                                fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ).animate().fadeIn().slideX(),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white10,
                        child: Icon(Icons.person, color: primaryColor, size: 30),
                      ).animate().scale(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // AI Smart Attendance
                _buildDashboardCard(
                  context,
                  title: 'AI Smart Attendance',
                  subtitle: 'Detect faces automatically',
                  icon: Icons.face_retouching_natural,
                  color: primaryColor,
                  onTap: () {
                    Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const SmartAttendanceScreen()));
                  },
                ),

                const SizedBox(height: 16),

                // Manual Attendance
                _buildDashboardCard(
                  context,
                  title: 'Manual Attendance',
                  subtitle: 'Mark attendance manually',
                  icon: Icons.checklist_rtl,
                  color: secondaryColor,
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ManualAttendanceScreen()));
                  },
                ),

                const SizedBox(height: 16),

                // ID Card Scanner
                _buildDashboardCard(
                  context,
                  title: 'ID Card Scanner',
                  subtitle: 'Scan ID cards offline',
                  icon: Icons.credit_card,
                  color: Colors.purpleAccent,
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const IDCardScannerScreen()));
                  },
                ),

                const SizedBox(height: 16),

                // Attendance History
                _buildDashboardCard(
                  context,
                  title: 'Attendance History',
                  subtitle: 'View past reports & absentees',
                  icon: Icons.history,
                  color: Colors.orangeAccent,
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()));
                  },
                ),

                const SizedBox(height: 20),

                // Bottom Actions Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Export Report
                      Expanded(
                        child: _buildSmallCard(
                          icon: Icons.picture_as_pdf,
                          label: 'Export PDF',
                          color: Colors.white70,
                          onTap: () async {
                            final students = await firestoreService.getStudentsOnce();
                            if (context.mounted) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => PreviewScreen(
                                            subject: 'General Report',
                                            date: DateTime.now(),
                                            students: students,
                                          )));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Sync Data
                      Expanded(
                        child: _buildSmallCard(
                          icon: Icons.sync,
                          label: 'Sync Data',
                          color: Colors.cyanAccent,
                          onTap: () => _syncData(context, firestoreService),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Watermark
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Made by Tellapalli Akhil Kumar',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: Colors.white24, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () => _showAddStudentDialog(context, firestoreService),
        child: const Icon(Icons.add, color: Colors.black87),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 100,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderGradient:
            LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.1)]),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration:
                      BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.outfit(
                              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(subtitle,
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
              ],
            ),
          ),
        ),
      ).animate().fadeIn().slideX(),
    );
  }

  Widget _buildSmallCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 70,
      borderRadius: 16,
      blur: 20,
      alignment: Alignment.center,
      border: 1,
      linearGradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)]),
      borderGradient: const LinearGradient(colors: [Colors.white24, Colors.white10]),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(label,
                  style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  /// Sync student_data.dart changes to Firestore
  void _syncData(BuildContext context, FirestoreService service) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Sync Student Data', style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose sync option:', style: GoogleFonts.outfit(color: Colors.white70)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New Students Only'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final count = await service.syncStudentData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(count > 0
                            ? '✓ Added $count new students'
                            : '✓ Already up to date'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Force Reload All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await service.forceReloadData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ All student data reloaded'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context, FirestoreService service) {
    final nameController = TextEditingController();
    final regController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Add New Student', style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder:
                    UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder:
                    UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
            TextField(
              controller: regController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reg No',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder:
                    UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder:
                    UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
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
              if (nameController.text.isNotEmpty && regController.text.isNotEmpty) {
                service.addStudent(Student(
                  name: nameController.text,
                  regNo: regController.text,
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
