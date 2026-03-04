import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for storing attendance history records
class AttendanceHistory {
  final String? docId;
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
    this.docId,
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

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'period': period,
      'timestamp': Timestamp.fromDate(timestamp),
      'totalStudents': totalStudents,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'absentRegNos': absentRegNos,
      'absentNames': absentNames,
      'presentRegNos': presentRegNos,
    };
  }

  factory AttendanceHistory.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceHistory(
      docId: id,
      subject: map['subject'] ?? '',
      period: map['period'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      totalStudents: map['totalStudents'] ?? 0,
      presentCount: map['presentCount'] ?? 0,
      absentCount: map['absentCount'] ?? 0,
      absentRegNos: List<String>.from(map['absentRegNos'] ?? []),
      absentNames: List<String>.from(map['absentNames'] ?? []),
      presentRegNos: List<String>.from(map['presentRegNos'] ?? []),
    );
  }
}
