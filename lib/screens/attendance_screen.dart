import 'package:flutter/material.dart';
import '../models/student.dart';
import 'preview_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final List<Student> students;
  const AttendanceScreen({super.key, required this.students});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final TextEditingController subjectController = TextEditingController();
  DateTime selectedDate = DateTime.now();

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    int presentCount =
        widget.students.where((s) => s.isPresent).length;
    int absentCount = widget.students.length - presentCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // SUBJECT + DATE CARD
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        labelText: 'Subject Name',
                        prefixIcon: const Icon(Icons.menu_book),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined),
                          const SizedBox(width: 8),
                          Text(
                            selectedDate
                                .toString()
                                .split(' ')[0],
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          const Icon(Icons.edit, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // SUMMARY CHIPS
            Row(
              children: [
                Chip(
                  avatar: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 18,
                  ),
                  label: Text('Present: $presentCount'),
                  backgroundColor:
                      Colors.green.withOpacity(0.1),
                ),
                const SizedBox(width: 10),
                Chip(
                  avatar: const Icon(
                    Icons.cancel,
                    color: Colors.red,
                    size: 18,
                  ),
                  label: Text('Absent: $absentCount'),
                  backgroundColor:
                      Colors.red.withOpacity(0.1),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // SELECT / CLEAR
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (var s in widget.students) {
                        s.isPresent = true;
                      }
                    });
                  },
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (var s in widget.students) {
                        s.isPresent = false;
                      }
                    });
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // STUDENT LIST
            Expanded(
              child: ListView.builder(
                itemCount: widget.students.length,
                itemBuilder: (context, index) {
                  final s = widget.students[index];
                  return AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 200),
                    margin:
                        const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: s.isPresent
                          ? Colors.white
                          : Colors.red.withOpacity(0.05),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        s.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(s.regNo),
                      value: s.isPresent,
                      activeColor:
                          const Color(0xFF4F46E5),
                      onChanged: (v) {
                        setState(() => s.isPresent = v!);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // BOTTOM BUTTON
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(14),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize:
                const Size(double.infinity, 54),
            backgroundColor:
                const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PreviewScreen(
                  subject: subjectController.text,
                  date: selectedDate,
                  students: widget.students,
                ),
              ),
            );
          },
          child: const Text(
            'View Absentees',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
