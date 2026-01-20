import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  TextRecognizer? _textRecognizer;

  OCRService() {
    // Only initialize on mobile platforms
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

      // Parse the recognized text to extract student info
      return _parseStudentData(recognizedText.text);
    } catch (e) {
      print('OCR Error: $e');
      return [];
    }
  }

  /// Parse raw OCR text to extract names and registration numbers
  List<Map<String, String>> _parseStudentData(String rawText) {
    final List<Map<String, String>> students = [];
    
    // Split by lines
    final lines = rawText.split('\n');
    
    // Regex patterns
    // Registration number pattern: digits followed by letters and more digits (e.g., 99230040723, 21BCE1234)
    final regNoPattern = RegExp(r'\b(\d{2,}[A-Za-z]*\d{3,})\b');
    
    // Name pattern: 2+ consecutive capitalized words
    final namePattern = RegExp(r'\b([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)+)\b');
    
    String? currentName;
    String? currentRegNo;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;
      
      // Try to find registration number
      final regMatch = regNoPattern.firstMatch(trimmedLine);
      if (regMatch != null) {
        currentRegNo = regMatch.group(1);
      }
      
      // Try to find name (uppercase words)
      final nameMatch = namePattern.firstMatch(trimmedLine.toUpperCase());
      if (nameMatch != null) {
        // Use the original case from the line
        final words = trimmedLine.split(RegExp(r'\s+'));
        final nameWords = words.where((w) => 
          RegExp(r'^[A-Za-z]+$').hasMatch(w) && w.length > 1
        ).take(4).toList();
        
        if (nameWords.length >= 2) {
          currentName = nameWords.join(' ').toUpperCase();
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
    
    // Alternative: Look for reg numbers alone and use nearby text as name
    if (students.isEmpty) {
      // Fallback: Just extract all reg numbers found
      final allRegMatches = regNoPattern.allMatches(rawText);
      for (final match in allRegMatches) {
        students.add({
          'name': 'Student ${students.length + 1}',
          'regNo': match.group(1)!,
        });
      }
    }
    
    return students;
  }

  void dispose() {
    _textRecognizer?.close();
  }
}
