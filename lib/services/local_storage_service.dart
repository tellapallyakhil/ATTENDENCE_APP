import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';

/// Offline local storage service for attendance management
/// This allows the app to work without internet connectivity
class LocalStorageService {
  static const String _studentsKey = 'offline_students';
  static const String _attendanceKey = 'offline_attendance';
  
  SharedPreferences? _prefs;
  
  /// Initialize the local storage
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Get all students from local storage
  Future<List<Student>> getStudents() async {
    if (_prefs == null) await init();
    
    final String? data = _prefs!.getString(_studentsKey);
    if (data == null || data.isEmpty) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => Student(
        regNo: json['regNo'] ?? '',
        name: json['name'] ?? '',
        isPresent: json['isPresent'] ?? false,
        docId: json['docId'],
        note: json['note'],
        timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : null,
      )).toList();
    } catch (e) {
      print('Error loading students: $e');
      return [];
    }
  }
  
  /// Save all students to local storage
  Future<void> saveStudents(List<Student> students) async {
    if (_prefs == null) await init();
    
    final jsonList = students.map((s) => {
      'regNo': s.regNo,
      'name': s.name,
      'isPresent': s.isPresent,
      'docId': s.docId ?? s.regNo, // Use regNo as ID for local storage
      'note': s.note,
      'timestamp': s.timestamp?.toIso8601String(),
    }).toList();
    
    await _prefs!.setString(_studentsKey, jsonEncode(jsonList));
  }
  
  /// Find student by registration number
  Future<Student?> findStudentByRegNo(String regNo) async {
    final students = await getStudents();
    final cleanedRegNo = regNo.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    
    return students.cast<Student?>().firstWhere(
      (s) => s!.regNo.replaceAll(RegExp(r'\s+'), '').toLowerCase() == cleanedRegNo,
      orElse: () => null,
    );
  }
  
  /// Find student by name (partial match)
  Future<Student?> findStudentByName(String name) async {
    final students = await getStudents();
    final cleanedName = name.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return students.cast<Student?>().firstWhere(
      (s) => s!.name.toUpperCase().contains(cleanedName) || 
             cleanedName.contains(s.name.toUpperCase()),
      orElse: () => null,
    );
  }
  
  /// Find student by name OR registration number
  Future<Student?> findStudent(String? name, String? regNo) async {
    if (regNo != null && regNo.isNotEmpty) {
      final byRegNo = await findStudentByRegNo(regNo);
      if (byRegNo != null) return byRegNo;
    }
    
    if (name != null && name.isNotEmpty) {
      final byName = await findStudentByName(name);
      if (byName != null) return byName;
    }
    
    return null;
  }
  
  /// Add a new student
  Future<void> addStudent(Student student) async {
    final students = await getStudents();
    
    // Check if already exists
    final exists = students.any((s) => 
      s.regNo.toLowerCase() == student.regNo.toLowerCase()
    );
    
    if (!exists) {
      students.add(Student(
        regNo: student.regNo,
        name: student.name,
        isPresent: student.isPresent,
        docId: student.regNo, // Use regNo as local ID
        timestamp: DateTime.now(),
        note: student.note,
      ));
      await saveStudents(students);
    }
  }
  
  /// Mark student as present
  Future<bool> markPresent(String regNo) async {
    final students = await getStudents();
    final cleanedRegNo = regNo.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    
    bool found = false;
    for (int i = 0; i < students.length; i++) {
      if (students[i].regNo.replaceAll(RegExp(r'\s+'), '').toLowerCase() == cleanedRegNo) {
        students[i] = Student(
          regNo: students[i].regNo,
          name: students[i].name,
          isPresent: true,
          docId: students[i].docId,
          timestamp: DateTime.now(),
          note: students[i].note,
        );
        found = true;
        break;
      }
    }
    
    if (found) {
      await saveStudents(students);
    }
    return found;
  }
  
  /// Mark student as present by name
  Future<bool> markPresentByName(String name) async {
    final students = await getStudents();
    final cleanedName = name.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    
    bool found = false;
    for (int i = 0; i < students.length; i++) {
      final studentName = students[i].name.toUpperCase();
      if (studentName.contains(cleanedName) || cleanedName.contains(studentName)) {
        students[i] = Student(
          regNo: students[i].regNo,
          name: students[i].name,
          isPresent: true,
          docId: students[i].docId,
          timestamp: DateTime.now(),
          note: students[i].note,
        );
        found = true;
        break;
      }
    }
    
    if (found) {
      await saveStudents(students);
    }
    return found;
  }
  
  /// Update attendance status
  Future<void> updateAttendance(String regNo, bool isPresent) async {
    final students = await getStudents();
    
    for (int i = 0; i < students.length; i++) {
      if (students[i].regNo.toLowerCase() == regNo.toLowerCase()) {
        students[i] = Student(
          regNo: students[i].regNo,
          name: students[i].name,
          isPresent: isPresent,
          docId: students[i].docId,
          timestamp: DateTime.now(),
          note: students[i].note,
        );
        break;
      }
    }
    
    await saveStudents(students);
  }
  
  /// Clear all local data
  Future<void> clearAll() async {
    if (_prefs == null) await init();
    await _prefs!.remove(_studentsKey);
  }
  
  /// Sync from Firestore data (import existing students)
  Future<void> syncFromFirestore(List<Student> firestoreStudents) async {
    final localStudents = await getStudents();
    
    // Merge: keep local attendance status if student exists
    final merged = <String, Student>{};
    
    // First add all firestore students
    for (final s in firestoreStudents) {
      merged[s.regNo.toLowerCase()] = s;
    }
    
    // Then update with local attendance status
    for (final s in localStudents) {
      final key = s.regNo.toLowerCase();
      if (merged.containsKey(key)) {
        // Keep the more recent attendance status
        final firestoreStudent = merged[key]!;
        if (s.timestamp != null && 
            (firestoreStudent.timestamp == null || 
             s.timestamp!.isAfter(firestoreStudent.timestamp!))) {
          merged[key] = s;
        }
      } else {
        merged[key] = s;
      }
    }
    
    await saveStudents(merged.values.toList());
  }
}
