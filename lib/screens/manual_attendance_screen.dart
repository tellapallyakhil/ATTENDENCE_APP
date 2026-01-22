import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/student.dart';
import '../services/firestore_service.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'absentees_screenshot_screen.dart';
import 'attendance_share_screen.dart';
import 'ocr_import_screen.dart';
import 'id_card_scanner_screen.dart';


class ManualAttendanceScreen extends StatefulWidget {
  const ManualAttendanceScreen({super.key});

  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}



class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  late Stream<List<Student>> _studentsStream;
  Timer? _debounce;
  String _searchQuery = "";
  String _filterStatus = "All"; // All, Present, Absent
  String _sortBy = "Time"; // Time, RegNo, Status
  
  @override
  void initState() {
    super.initState();
    _studentsStream = _firestoreService.getStudents();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Manual Attendance',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () {
               setState(() {
                 if (_sortBy == "Time") _sortBy = "Status";
                 else if (_sortBy == "Status") _sortBy = "RegNo";
                 else _sortBy = "Time";
               });
            },
            icon: Icon(
              _sortBy == "Time" ? Icons.access_time_filled
              : _sortBy == "Status" ? Icons.sort 
              : Icons.numbers,
            ),
            tooltip: 'Sort by $_sortBy',
          ),
          IconButton(
            onPressed: () => _showAddStudentDialog(context),
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Student',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OCRImportScreen()),
              );
            },
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan List',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IDCardScannerScreen()),
              );
            },
            icon: const Icon(Icons.credit_card),
            tooltip: 'Scan ID Card',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'mark_all') {
                _firestoreService.markAll(true);
              } else if (value == 'unmark_all') {
                _firestoreService.markAll(false);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'mark_all',
                  child: Text('Mark All Present'),
                ),
                const PopupMenuItem(
                  value: 'unmark_all',
                  child: Text('Mark All Absent'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)], // Darker Theme
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<Student>>(
            stream: _studentsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                 return _buildEmptyState();
              }

              final allStudents = snapshot.data!;
              
              // 1. Filter
              var filteredStudents = allStudents.where((s) {
                final query = _searchQuery.toLowerCase();
                final matchesSearch = s.name.toLowerCase().contains(query) || s.regNo.toLowerCase().contains(query);
                
                if (!matchesSearch) return false;

                if (_filterStatus == "Present") return s.isPresent;
                if (_filterStatus == "Absent") return !s.isPresent;
                return true;
              }).toList();

              // 2. Sort
              filteredStudents.sort((a, b) {
                if (_sortBy == "Time") {
                  if (a.timestamp == null && b.timestamp == null) return a.name.compareTo(b.name);
                  if (a.timestamp == null) return 1; // a is older (null) -> go to bottom
                  if (b.timestamp == null) return -1; // b is older -> go to bottom
                  return b.timestamp!.compareTo(a.timestamp!); // Newest first
                }
                if (_sortBy == "RegNo") return a.regNo.compareTo(b.regNo);
                if (_sortBy == "Status") {
                  // Put Absentees first
                  if (a.isPresent == b.isPresent) return a.name.compareTo(b.name);
                  return a.isPresent ? 1 : -1; 
                }
                return a.name.compareTo(b.name); // Default fallback
              });

              final total = allStudents.length;
              final present = allStudents.where((s) => s.isPresent).length;
              final absent = total - present;

              return Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) {
                         if (_debounce?.isActive ?? false) _debounce!.cancel();
                         _debounce = Timer(const Duration(milliseconds: 300), () {
                           setState(() {
                             _searchQuery = val;
                           });
                         });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search student...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                      ),
                    ),
                  ),

                  // Stats & Filter (omitted for brevity, they are unchanged)
                  Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                     child: Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         gradient: LinearGradient(colors: [Colors.cyan.withOpacity(0.2), Colors.purple.withOpacity(0.2)]),
                         borderRadius: BorderRadius.circular(20),
                         border: Border.all(color: Colors.white10),
                       ),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceAround,
                         children: [
                           _buildStatItem("Total", total.toString(), Colors.white),
                           Container(width: 1, height: 30, color: Colors.white24),
                           _buildStatItem("Present", present.toString(), Colors.cyanAccent),
                           Container(width: 1, height: 30, color: Colors.white24),
                           _buildStatItem("Absent", absent.toString(), Colors.redAccent),
                         ],
                       ),
                     ).animate().scale(),
                   ),

                   SingleChildScrollView(
                     scrollDirection: Axis.horizontal,
                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                     child: Row(
                       children: [
                         _buildFilterChip("All", Icons.list),
                         const SizedBox(width: 10),
                         _buildFilterChip("Present", Icons.check_circle_outline, activeColor: Colors.cyanAccent),
                          const SizedBox(width: 10),
                         _buildFilterChip("Absent", Icons.cancel_outlined, activeColor: Colors.redAccent),
                       ],
                     ),
                   ),

                  // List
                  Expanded(
                    child: filteredStudents.isEmpty 
                    ? Center(child: Text("No students found", style: GoogleFonts.outfit(color: Colors.white54)))
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      cacheExtent: 500, // Cache more items for smoother scroll
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) {
                        final s = filteredStudents[index];
                        return StudentTile(
                          key: Key(s.docId ?? s.regNo),
                          student: s,
                          firestoreService: _firestoreService,
                          onLongPress: () => _showNoteDialog(context, s),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<List<Student>>(
        stream: _firestoreService.getStudents(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
          final allStudents = snapshot.data!;
          final absentees = allStudents.where((s) => !s.isPresent).toList();

          return FloatingActionButton.extended(
            backgroundColor: absentees.isEmpty ? Colors.green : Colors.redAccent,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttendanceShareScreen(allStudents: allStudents),
                ),
              );
            },
            label: Text(
              absentees.isEmpty ? "All Present!" : "${absentees.length} Absent", 
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)
            ),
            icon: Icon(
              absentees.isEmpty ? Icons.check_circle : Icons.assignment_late, 
              color: Colors.white
            ),
          ).animate().scale(delay: 500.ms);
        }
      ),
    );
  }

  // Same as before
  Widget _buildFilterChip(String label, IconData icon, {Color activeColor = Colors.white}) {
    final bool isSelected = _filterStatus == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = label;
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? activeColor : Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.black : Colors.white70),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Same as before
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
  

  Widget _buildEmptyState() {
     return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No students found',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _firestoreService.initializeData();
              },
              icon: const Icon(Icons.cloud_upload),
              label: const Text("Load Default Class Data"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.teal,
              ),
            ),
          ],
        ));
  }
  
  void _showNoteDialog(BuildContext context, Student s) {
     final noteController = TextEditingController(text: s.note);
     showDialog(
       context: context,
       builder: (_) => AlertDialog(
         backgroundColor: const Color(0xFF1E293B),
         title: Text("Add Note for ${s.name}", style: GoogleFonts.outfit(color: Colors.white)),
         content: TextField(
           controller: noteController,
           style: const TextStyle(color: Colors.white),
           maxLines: 3,
           decoration: const InputDecoration(
             hintText: "e.g. Sick Leave, On Duty...",
             hintStyle: TextStyle(color: Colors.white54),
             enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
             focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
           ),
         ),
         actions: [
            TextButton(
             onPressed: () => Navigator.pop(context),
             child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
           ),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
             onPressed: () {
                if (s.docId != null) {
                  _firestoreService.updateNote(s.docId!, noteController.text);
                }
                Navigator.pop(context);
             },
             child: const Text('Save', style: TextStyle(color: Colors.black)),
           ),
         ],
       )
     );
  }

  void _showAddStudentDialog(BuildContext context) {
    final nameController = TextEditingController();
    final regController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF004D40),
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
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
              ),
            ),
            TextField(
              controller: regController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reg No',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
            onPressed: () {
              if (nameController.text.isNotEmpty && regController.text.isNotEmpty) {
                _firestoreService.addStudent(Student(
                  name: nameController.text,
                  regNo: regController.text,
                  isPresent: true, // Default to present
                  timestamp: DateTime.now(),
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }
  
  void _showAbsenteesReport(BuildContext context, List<Student> absentees) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF004D40),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Container(
                 width: 40,
                 height: 4,
                 decoration: BoxDecoration(
                   color: Colors.white24,
                   borderRadius: BorderRadius.circular(2)
                 ),
               ),
             ),
             Padding(
               padding: const EdgeInsets.only(bottom: 20),
               child: Text(
                 "Absentees Report",
                 style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
               ),
             ),
             Expanded(
               child: absentees.isEmpty 
               ? Center(
                   child: Text("everyone is present! 🎉", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 18))
                 )
               : ListView.builder(
                   controller: controller,
                   itemCount: absentees.length,
                   itemBuilder: (context, index) {
                     final s = absentees[index];
                     return ListTile(
                       leading: CircleAvatar(
                         backgroundColor: Colors.redAccent.withOpacity(0.2),
                         child: Text("${index + 1}", style: const TextStyle(color: Colors.redAccent)),
                       ),
                       title: Text(s.name, style: GoogleFonts.outfit(color: Colors.white)),
                       subtitle: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(s.regNo, style: GoogleFonts.outfit(color: Colors.white54)),
                           if (s.note != null && s.note!.isNotEmpty)
                             Text("Note: ${s.note}", style: GoogleFonts.outfit(color: Colors.amberAccent, fontStyle: FontStyle.italic)),
                         ],
                       ),
                     );
                   },
                 ),
             ),
          ],
        ),
      ),
    );
  }

}

class StudentTile extends StatefulWidget {
  final Key? key;
  final Student student;
  final FirestoreService firestoreService;
  final VoidCallback onLongPress;

  const StudentTile({
    this.key,
    required this.student,
    required this.firestoreService,
    required this.onLongPress,
  }) : super(key: key);

  @override
  State<StudentTile> createState() => _StudentTileState();
}

class _StudentTileState extends State<StudentTile> {
  // Local state for optimistic UI
  late bool _isPresent;

  @override
  void initState() {
    super.initState();
    _isPresent = widget.student.isPresent;
  }

  @override
  void didUpdateWidget(StudentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.student.isPresent != _isPresent) {
       _isPresent = widget.student.isPresent;
    }
  }

  void _toggleAttendance() {
    setState(() {
      _isPresent = !_isPresent;
    });
    HapticFeedback.lightImpact();

    if (widget.student.docId != null) {
      widget.firestoreService.updateAttendance(widget.student.docId!, _isPresent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final bool isPresent = _isPresent;

    return Dismissible(
      key: Key(s.docId ?? s.regNo),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.check, color: Colors.white, size: 30),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.close, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
         bool newStatus = direction == DismissDirection.startToEnd; // Swipe Right -> Present
         setState(() {
           _isPresent = newStatus;
         });
         HapticFeedback.mediumImpact();
         
         if (s.docId != null) {
           widget.firestoreService.updateAttendance(s.docId!, newStatus);
         }
         return false; // Don't allow dismiss
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: isPresent 
               ? Colors.cyan.withOpacity(0.05) 
               : Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPresent ? Colors.cyan.withOpacity(0.3) : Colors.red.withOpacity(0.3)
            )),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: isPresent ? Colors.cyanAccent : Colors.redAccent.withOpacity(0.2),
            child: Text(
              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: isPresent ? Colors.black : Colors.redAccent, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          title: Text(s.name,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          subtitle: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(s.regNo, style: GoogleFonts.outfit(color: Colors.white54)),
               if (s.note != null && s.note!.isNotEmpty)
                 Text("Note: ${s.note}", style: GoogleFonts.outfit(color: Colors.amberAccent, fontStyle: FontStyle.italic)),
             ],
           ),
          trailing: AnimatedContainer(
            duration: 300.ms,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPresent ? Colors.cyanAccent : Colors.transparent,
              border: Border.all(color: isPresent ? Colors.cyanAccent : Colors.redAccent),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPresent ? "Present" : "Absent",
              style: TextStyle(
                color: isPresent ? Colors.black : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          onTap: _toggleAttendance,
          onLongPress: widget.onLongPress,
        ),
      ),
    );
  }
}
