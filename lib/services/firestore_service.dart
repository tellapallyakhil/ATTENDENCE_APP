import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../data/student_data.dart';

class FirestoreService {
  final CollectionReference _studentsCollection =
      FirebaseFirestore.instance.collection('students');

  // Seed data if empty
  Future<void> initializeData() async {
    final snapshot = await _studentsCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // Already data exists

    final batch = FirebaseFirestore.instance.batch();
    for (var student in classStudents) {
      final docRef = _studentsCollection.doc(); // Auto-ID
      batch.set(docRef, student.toMap());
    }
    await batch.commit();
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
}
