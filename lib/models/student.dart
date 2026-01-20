import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String regNo;
  final String name;
  bool isPresent;
  String? docId;
  DateTime? timestamp;
  String? note;

  Student({
    required this.regNo,
    required this.name,
    this.isPresent = true,
    this.docId,
    this.timestamp,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'regNo': regNo,
      'name': name,
      'isPresent': isPresent,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'note': note,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map, String id) {
    return Student(
      regNo: map['regNo'] ?? '',
      name: map['name'] ?? '',
      isPresent: map['isPresent'] ?? false,
      docId: id,
      timestamp: map['timestamp'] != null ? (map['timestamp'] as Timestamp).toDate() : null,
      note: map['note'],
    );
  }
}
