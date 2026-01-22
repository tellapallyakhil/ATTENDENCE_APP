import 'package:attendance_app/screens/smart_attendance_screen.dart';
import 'package:attendance_app/screens/manual_attendance_screen.dart';
import 'package:attendance_app/screens/id_card_scanner_screen.dart';
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

    // Theme Colors
    final Color primaryColor = Colors.cyanAccent;
    final Color secondaryColor = Colors.tealAccent;
    final List<Color> gradientColors = [
      const Color(0xFF0F172A), // Dark Slate
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
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          'Professor',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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

              const SizedBox(height: 30),

              // AI Smart Attendance Card
              _buildDashboardCard(
                context,
                title: 'AI Smart Attendance',
                subtitle: 'Detect faces automatically',
                icon: Icons.face_retouching_natural,
                color: primaryColor,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartAttendanceScreen()));
                },
              ),

              const SizedBox(height: 20),

              // Manual Attendance Card
              _buildDashboardCard(
                context,
                title: 'Manual Attendance',
                subtitle: 'Mark attendance manually',
                icon: Icons.checklist_rtl,
                color: secondaryColor,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualAttendanceScreen()));
                },
              ),

              const SizedBox(height: 20),

              // ID Card Scanner Card (NEW!)
              _buildDashboardCard(
                context,
                title: 'ID Card Scanner',
                subtitle: 'Scan ID cards offline',
                icon: Icons.credit_card,
                color: Colors.purpleAccent,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const IDCardScannerScreen()));
                },
              ),

              const Spacer(),

              // Bottom Actions (e.g. Export)
               Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: GlassmorphicContainer(
                   width: double.infinity,
                   height: 100,
                   borderRadius: 20,
                   blur: 20,
                   alignment: Alignment.center,
                   border: 2,
                   linearGradient: LinearGradient(
                       colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
                       begin: Alignment.topLeft,
                       end: Alignment.bottomRight),
                   borderGradient: LinearGradient(
                       colors: [Colors.white24, Colors.white10]),
                   child: InkWell(
                     onTap: () async {
                         final students = await firestoreService.getStudentsOnce();
                         if (context.mounted) {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewScreen(
                             subject: 'General Report',
                             date: DateTime.now(),
                             students: students,
                           )));
                         }
                     },
                     child: Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 24),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 'Export Report',
                                 style: GoogleFonts.outfit(
                                   fontSize: 18,
                                   fontWeight: FontWeight.bold,
                                   color: Colors.white,
                                 ),
                               ),
                               Text(
                                 'Download PDF',
                                 style: GoogleFonts.outfit(
                                   fontSize: 14,
                                   color: Colors.white54,
                                 ),
                               ),
                             ],
                           ),
                           Icon(Icons.picture_as_pdf, color: Colors.white70, size: 32),
                         ],
                       ),
                     ),
                   ),
                ),
               ),

               // Watermark
               Padding(
                 padding: const EdgeInsets.only(bottom: 10),
                 child: Center(
                   child: Text(
                     'Made by Tellapalli Akhil Kumar',
                     style: GoogleFonts.outfit(
                       fontSize: 12,
                       color: Colors.white24,
                       fontStyle: FontStyle.italic,
                     ),
                   ),
                 ),
               ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () {
          _showAddStudentDialog(context, firestoreService);
        },
        child: const Icon(Icons.add, color: Colors.black87), // Black icon on bright color
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 120,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderGradient: LinearGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0.1)]),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
              ],
            ),
          ),
        ),
      ).animate().fadeIn().slideX(),
    );
  }

  void _showAddStudentDialog(BuildContext context, FirestoreService service) {
    final nameController = TextEditingController();
    final regController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B), // Match new theme
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
