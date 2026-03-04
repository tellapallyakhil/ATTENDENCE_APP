import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/attendance_history.dart';
import '../services/firestore_service.dart';

/// Attendance History Screen - shows saved reports with subject and timeline
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Attendance History',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<AttendanceHistory>>(
        stream: _firestoreService.getHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('No history yet',
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Reports will appear here when you save them',
                      style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
                ],
              ),
            );
          }

          final history = snapshot.data!;

          // Group by date
          final Map<String, List<AttendanceHistory>> grouped = {};
          for (final h in history) {
            final dateKey = DateFormat('dd MMM yyyy').format(h.timestamp);
            grouped.putIfAbsent(dateKey, () => []);
            grouped[dateKey]!.add(h);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final dateKey = grouped.keys.toList()[index];
              final dayRecords = grouped[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.cyanAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(dateKey,
                            style: GoogleFonts.outfit(
                                color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${dayRecords.length} report${dayRecords.length > 1 ? 's' : ''}',
                            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                  // Records for that day
                  ...dayRecords.map((record) => _buildHistoryCard(record)),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(AttendanceHistory record) {
    final time = DateFormat('hh:mm a').format(record.timestamp);
    final hasAbsentees = record.absentCount > 0;

    return GestureDetector(
      onTap: () => _showHistoryDetail(record),
      onLongPress: () => _confirmDelete(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasAbsentees ? Colors.redAccent.withOpacity(0.3) : Colors.green.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasAbsentees
                    ? Colors.redAccent.withOpacity(0.15)
                    : Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasAbsentees ? Icons.person_off : Icons.check_circle,
                color: hasAbsentees ? Colors.redAccent : Colors.green,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.subject,
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(time, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                      if (record.period.isNotEmpty) ...[
                        Text(' • ', style: TextStyle(color: Colors.white38)),
                        Text(record.period,
                            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${record.presentCount}',
                        style: GoogleFonts.outfit(
                            color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('/', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14)),
                    Text('${record.totalStudents}',
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
                  ],
                ),
                if (hasAbsentees)
                  Text('${record.absentCount} absent',
                      style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  /// Show detailed view of a history record
  void _showHistoryDetail(AttendanceHistory record) {
    final time = DateFormat('hh:mm a').format(record.timestamp);
    final date = DateFormat('dd MMM yyyy').format(record.timestamp);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(record.subject,
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$date  •  $time${record.period.isNotEmpty ? "  •  ${record.period}" : ""}',
                      style: GoogleFonts.outfit(color: Colors.white54)),
                ],
              ),
            ),
            // Stats row
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statCol('Total', '${record.totalStudents}', Colors.white),
                  Container(width: 1, height: 30, color: Colors.white24),
                  _statCol('Present', '${record.presentCount}', Colors.green),
                  Container(width: 1, height: 30, color: Colors.white24),
                  _statCol('Absent', '${record.absentCount}', Colors.redAccent),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Absentees list header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Absentees',
                    style: GoogleFonts.outfit(
                        color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 8),
            // Absentees list
            Expanded(
              child: record.absentRegNos.isEmpty
                  ? Center(
                      child: Text('🎉 Everyone was present!',
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16)))
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: record.absentRegNos.length,
                      itemBuilder: (_, i) {
                        final name = i < record.absentNames.length
                            ? record.absentNames[i]
                            : 'Unknown';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.redAccent.withOpacity(0.2),
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: GoogleFonts.outfit(
                                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                    Text(record.absentRegNos[i],
                                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ),
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

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.outfit(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  /// Confirm delete
  void _confirmDelete(AttendanceHistory record) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Record?', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${record.subject}" report?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (record.docId != null) {
                _firestoreService.deleteHistory(record.docId!);
              }
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
