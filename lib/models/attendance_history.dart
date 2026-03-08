/// Model for storing attendance history records (offline-first)
class AttendanceHistory {
  final String id; // unique local ID
  final String subject;
  final String period;
  final DateTime timestamp;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final List<String> absentRegNos;
  final List<String> absentNames;
  final List<String> presentRegNos;

  AttendanceHistory({
    required this.id,
    required this.subject,
    required this.period,
    required this.timestamp,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.absentRegNos,
    required this.absentNames,
    required this.presentRegNos,
  });

  /// Convert to JSON-safe map (no Firestore dependency)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'period': period,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'totalStudents': totalStudents,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'absentRegNos': absentRegNos,
      'absentNames': absentNames,
      'presentRegNos': presentRegNos,
    };
  }

  factory AttendanceHistory.fromJson(Map<String, dynamic> map) {
    return AttendanceHistory(
      id: map['id'] ?? '',
      subject: map['subject'] ?? '',
      period: map['period'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      totalStudents: map['totalStudents'] ?? 0,
      presentCount: map['presentCount'] ?? 0,
      absentCount: map['absentCount'] ?? 0,
      absentRegNos: List<String>.from(map['absentRegNos'] ?? []),
      absentNames: List<String>.from(map['absentNames'] ?? []),
      presentRegNos: List<String>.from(map['presentRegNos'] ?? []),
    );
  }
}
