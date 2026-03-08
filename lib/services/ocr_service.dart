import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  TextRecognizer? _textRecognizer;

  OCRService() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _textRecognizer = TextRecognizer();
    }
  }

  /// Process an image file and extract text
  Future<List<Map<String, String>>> extractStudentsFromImage(String imagePath) async {
    if (_textRecognizer == null) {
      return [];
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer!.processImage(inputImage);
      
      debugPrint('=== RAW OCR TEXT ===');
      debugPrint(recognizedText.text);
      debugPrint('==================');
      
      return _parseStudentData(recognizedText.text);
    } catch (e) {
      debugPrint('OCR Error: $e');
      return [];
    }
  }

  /// Get raw text from image (useful for debugging)
  Future<String> getRawText(String imagePath) async {
    if (_textRecognizer == null) return 'OCR not available on this platform';
    
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer!.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Parse raw OCR text to extract names and registration numbers
  List<Map<String, String>> _parseStudentData(String rawText) {
    final List<Map<String, String>> students = [];
    final lines = rawText.split('\n');
    
    // Registration number patterns:
    // 1. Pure digits 8-15 chars: 99230040723
    // 2. Alphanumeric: 21BCE1234, RA2211003010567
    final regNoPatterns = [
      RegExp(r'\b(\d{8,15})\b'),                    // Pure digits
      RegExp(r'\b(\d{2}[A-Z]{2,4}\d{4,})\b'),       // Like 21BCE1234
      RegExp(r'\b([A-Z]{2}\d{10,})\b'),              // Like RA2211003010567
      RegExp(r'\b(\d{2,4}[A-Z]+\d{3,})\b'),         // General alphanumeric
    ];
    
    // Name pattern: 2+ words that are mostly letters
    final namePattern = RegExp(r'\b([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+){1,3})\b');
    
    String? currentName;
    String? currentRegNo;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty || trimmedLine.length < 3) continue;
      
      // Try to find registration number
      if (currentRegNo == null) {
        for (final pattern in regNoPatterns) {
          final regMatch = pattern.firstMatch(trimmedLine);
          if (regMatch != null) {
            currentRegNo = regMatch.group(1);
            break;
          }
        }
      }
      
      // Try to find name (2+ capitalized words, not common labels)
      if (currentName == null) {
        final nameMatch = namePattern.firstMatch(trimmedLine);
        if (nameMatch != null) {
          final candidate = nameMatch.group(1)!;
          if (!_isNonNameText(candidate) && candidate.split(' ').length >= 2) {
            currentName = candidate.toUpperCase();
          }
        }
      }
      
      // If we have both, add to list
      if (currentName != null && currentRegNo != null) {
        students.add({
          'name': currentName,
          'regNo': currentRegNo,
        });
        currentName = null;
        currentRegNo = null;
      }
    }
    
    // Fallback: if no pairs found, just extract all reg numbers
    if (students.isEmpty) {
      for (final pattern in regNoPatterns) {
        final allMatches = pattern.allMatches(rawText);
        for (final match in allMatches) {
          students.add({
            'name': 'Student ${students.length + 1}',
            'regNo': match.group(1)!,
          });
        }
        if (students.isNotEmpty) break; // Use first pattern that finds results
      }
    }
    
    return students;
  }

  /// Check if text is a common label rather than a name
  bool _isNonNameText(String text) {
    final lower = text.toLowerCase();
    const skip = [
      'serial number', 'roll number', 'reg number', 'registration number',
      'student name', 'student list', 'class list', 'attendance list',
      'department of', 'school of', 'faculty of',
    ];
    return skip.any((s) => lower.contains(s));
  }

  void dispose() {
    _textRecognizer?.close();
  }
}
