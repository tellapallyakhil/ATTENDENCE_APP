import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../models/attendance_history.dart';
import '../data/student_data.dart';

class FirestoreService {
  final CollectionReference _studentsCollection =
      FirebaseFirestore.instance.collection('students');
  final CollectionReference _historyCollection =
      FirebaseFirestore.instance.collection('attendance_history');

  // Seed data if empty
  Future<void> initializeData() async {
    final snapshot = await _studentsCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (var student in classStudents) {
      final docRef = _studentsCollection.doc();
      batch.set(docRef, student.toMap());
    }
    await batch.commit();
  }

  /// Re-sync student_data.dart changes to Firestore
  /// Adds new students that don't exist yet, keeps existing ones
  Future<int> syncStudentData() async {
    final existing = await _studentsCollection.get();
    final existingRegNos = existing.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['regNo'] as String? ?? '';
    }).toSet();

    int addedCount = 0;
    final batch = FirebaseFirestore.instance.batch();

    for (var student in classStudents) {
      if (!existingRegNos.contains(student.regNo)) {
        final docRef = _studentsCollection.doc();
        batch.set(docRef, student.toMap());
        addedCount++;
      }
    }

    if (addedCount > 0) {
      await batch.commit();
    }
    return addedCount;
  }

  /// Force reload: delete all and re-load from student_data.dart
  Future<void> forceReloadData() async {
    final snapshot = await _studentsCollection.get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Now re-add all
    final addBatch = FirebaseFirestore.instance.batch();
    for (var student in classStudents) {
      final docRef = _studentsCollection.doc();
      addBatch.set(docRef, student.toMap());
    }
    await addBatch.commit();
  }

  // Add a new student
  Future<void> addStudent(Student student) async {
    try {
      await _studentsCollection.add(student.toMap());
    } catch (e) {
      print('Error adding student: $e');
      rethrow;
    }
  }

  // Get stream of students
  Stream<List<Student>> getStudents() {
    return _studentsCollection.orderBy('regNo').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Student.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<List<Student>> getStudentsOnce() async {
    final snapshot = await _studentsCollection.orderBy('regNo').get();
    return snapshot.docs.map((doc) {
      return Student.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  // Update attendance status
  Future<void> updateAttendance(String docId, bool isPresent) async {
    try {
      await _studentsCollection.doc(docId).update({'isPresent': isPresent});
    } catch (e) {
      print('Error updating attendance: $e');
    }
  }

  // Update student note
  Future<void> updateNote(String docId, String? note) async {
    try {
      await _studentsCollection.doc(docId).update({'note': note});
    } catch (e) {
       print('Error updating note: $e');
    }
  }

  // Mark all as present/absent
  Future<void> markAll(bool isPresent) async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await _studentsCollection.get();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isPresent': isPresent});
    }
    await batch.commit();
  }

  // ====== HISTORY METHODS ======

  /// Save attendance report to history
  Future<void> saveHistory(AttendanceHistory history) async {
    try {
      await _historyCollection.add(history.toMap());
    } catch (e) {
      print('Error saving history: $e');
    }
  }

  /// Get all history records, newest first
  Stream<List<AttendanceHistory>> getHistory() {
    return _historyCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AttendanceHistory.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Get history once
  Future<List<AttendanceHistory>> getHistoryOnce() async {
    final snapshot = await _historyCollection
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      return AttendanceHistory.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  /// Delete a history record
  Future<void> deleteHistory(String docId) async {
    try {
      await _historyCollection.doc(docId).delete();
    } catch (e) {
      print('Error deleting history: $e');
    }
  }
}
