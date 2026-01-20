import 'package:flutter/material.dart';
import '../models/student.dart';

class PreviewScreen extends StatelessWidget {
  final String subject;
  final DateTime date;
  final List<Student> students;

  const PreviewScreen({
    super.key,
    required this.subject,
    required this.date,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    final absentees = students.where((s) => !s.isPresent).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Absentees')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text('Subject: $subject'),
                subtitle: Text('Date: ${date.toString().split(' ')[0]}'),
                trailing: Chip(
                  label: Text('${absentees.length} Absent'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: absentees.isEmpty
                  ? const Center(
                      child: Text(
                        'Perfect Attendance 🎉',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      itemCount: absentees.length,
                      itemBuilder: (context, index) {
                        final s = absentees[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(s.name),
                            subtitle: Text(s.regNo),
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
