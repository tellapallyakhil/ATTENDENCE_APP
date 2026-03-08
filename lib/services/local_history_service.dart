import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_history.dart';

/// Offline-first history service using SharedPreferences
/// Works completely without internet - no Firestore dependency
class LocalHistoryService {
  static const String _historyKey = 'attendance_history_v2';
  static LocalHistoryService? _instance;
  SharedPreferences? _prefs;

  LocalHistoryService._();

  /// Singleton instance for fast access
  static LocalHistoryService get instance {
    _instance ??= LocalHistoryService._();
    return _instance!;
  }

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save a new history record (instant, offline)
  Future<void> saveHistory(AttendanceHistory history) async {
    final prefs = await _preferences;
    final List<String> existing = prefs.getStringList(_historyKey) ?? [];
    existing.insert(0, jsonEncode(history.toJson())); // newest first
    await prefs.setStringList(_historyKey, existing);
  }

  /// Get all history records (newest first)
  Future<List<AttendanceHistory>> getHistory() async {
    final prefs = await _preferences;
    final List<String> stored = prefs.getStringList(_historyKey) ?? [];
    return stored.map((json) {
      return AttendanceHistory.fromJson(jsonDecode(json));
    }).toList();
  }

  /// Delete a history record by ID
  Future<void> deleteHistory(String id) async {
    final prefs = await _preferences;
    final List<String> stored = prefs.getStringList(_historyKey) ?? [];
    stored.removeWhere((json) {
      final map = jsonDecode(json);
      return map['id'] == id;
    });
    await prefs.setStringList(_historyKey, stored);
  }

  /// Clear all history
  Future<void> clearAll() async {
    final prefs = await _preferences;
    await prefs.remove(_historyKey);
  }

  /// Get count of history records
  Future<int> getCount() async {
    final prefs = await _preferences;
    final List<String> stored = prefs.getStringList(_historyKey) ?? [];
    return stored.length;
  }
}
