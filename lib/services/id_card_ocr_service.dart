import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Optimized OCR service for ID card scanning
/// Detects name and registration number from college ID cards
class IDCardOCRService {
  TextRecognizer? _textRecognizer;

  IDCardOCRService() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _textRecognizer = TextRecognizer();
    }
  }

  /// Extract name and registration number from ID card
  Future<Map<String, String?>> extractIDCardInfo(String imagePath) async {
    if (_textRecognizer == null) {
      return {'name': null, 'regNo': null, 'error': 'OCR not available'};
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _textRecognizer!.processImage(inputImage);
      
      debugPrint('=== ID CARD RAW TEXT ===');
      debugPrint(recognized.text);
      debugPrint('=======================');
      
      return _parseIDCard(recognized.text);
    } catch (e) {
      debugPrint('OCR Error: $e');
      return {'name': null, 'regNo': null, 'error': e.toString()};
    }
  }

  /// Parse ID card text to extract name and reg number
  Map<String, String?> _parseIDCard(String rawText) {
    String? name;
    String? regNo;

    final lines = rawText.split('\n');

    // === FIND REGISTRATION NUMBER ===
    // Multiple patterns for different ID card formats
    final regPatterns = [
      RegExp(r'\b(\d{11,15})\b'),             // 11-15 pure digits: 99230040782
      RegExp(r'\b(\d{8,10})\b'),              // 8-10 digits
      RegExp(r'\b(\d{2}[A-Z]{2,4}\d{4,})\b'), // Alphanumeric: 21BCE1234
      RegExp(r'\b([A-Z]{2}\d{10,})\b'),        // RA2211003010567
    ];

    for (final line in lines) {
      final text = line.trim();
      if (text.length < 3) continue;

      // Try reg number first
      if (regNo == null) {
        for (final pattern in regPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null) {
            regNo = match.group(1);
            break;
          }
        }
      }

      // Try name - look for uppercase text that is a person's name
      if (name == null && _isLikelyName(text)) {
        final extracted = _extractName(text);
        if (extracted != null && extracted.split(' ').length >= 2) {
          name = extracted;
        }
      }
    }

    // Fallback: search for any uppercase word sequence of 2-4 words
    if (name == null) {
      name = _fallbackNameSearch(rawText);
    }

    return {
      'name': name?.toUpperCase().trim(),
      'regNo': regNo?.trim(),
      'rawText': rawText,
    };
  }

  /// Check if line looks like a name (not an institution or label)
  bool _isLikelyName(String text) {
    final lower = text.toLowerCase();
    const skipWords = [
      'university', 'college', 'academy', 'institute', 'student',
      'b.tech', 'engineering', 'department', 'registrar', 'deemed',
      'education', 'research', 'accredited', 'naac', 'grade',
      'kalasalingam', 'school', 'faculty', 'computer', 'science',
      'valid', 'date', 'year', 'branch', 'section', 'semester',
      'blood', 'group', 'address', 'phone', 'mobile', 'email',
    ];
    
    if (skipWords.any((w) => lower.contains(w))) return false;

    // Must be mostly letters (not digits/symbols)
    final lettersOnly = text.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
    return lettersOnly.length >= text.length * 0.6 && lettersOnly.length >= 5;
  }

  /// Extract name from a text line
  String? _extractName(String text) {
    // Remove numbers, dates, and special chars
    String cleaned = text
        .replaceAll(RegExp(r'\d+[-–/]\d+[-–/]?\d*'), '') // Dates
        .replaceAll(RegExp(r'\b\d{4,}\b'), '')             // Long numbers
        .replaceAll(RegExp(r'[^\w\s]'), ' ')               // Special chars
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final words = cleaned.split(' ').where((w) {
      return w.length >= 2 && 
             RegExp(r'^[A-Za-z]+$').hasMatch(w) &&
             !_isCommonWord(w.toLowerCase());
    }).toList();

    if (words.length >= 2) {
      return words.take(4).join(' ');
    }
    return null;
  }

  bool _isCommonWord(String w) {
    const skip = [
      'the', 'and', 'for', 'from', 'with', 'under', 'name', 'reg', 'no',
      'computer', 'science', 'engineering', 'technology',
      'university', 'college', 'academy', 'institute',
      'student', 'valid', 'year', 'date', 'roll', 'number',
    ];
    return skip.contains(w);
  }

  /// Fallback: find any sequence of 2-4 uppercase words
  String? _fallbackNameSearch(String rawText) {
    final pattern = RegExp(r'\b([A-Z][A-Z]+(?:\s+[A-Z][A-Z]+)+)\b');
    final matches = pattern.allMatches(rawText);

    for (final match in matches) {
      final candidate = match.group(1)!;
      if (_containsIgnored(candidate)) continue;
      final wordCount = candidate.split(' ').length;
      if (wordCount >= 2 && wordCount <= 4) {
        return candidate;
      }
    }
    return null;
  }

  bool _containsIgnored(String text) {
    const ignored = [
      'KALASALINGAM', 'UNIVERSITY', 'COLLEGE', 'ACADEMY',
      'EDUCATION', 'RESEARCH', 'DEEMED', 'ENGINEERING',
      'STUDENT', 'DEPARTMENT', 'COMPUTER', 'SCIENCE',
      'INSTITUTE', 'TECHNOLOGY', 'SCHOOL',
    ];
    final upper = text.toUpperCase();
    return ignored.any((w) => upper.contains(w));
  }

  void dispose() {
    _textRecognizer?.close();
  }
}
