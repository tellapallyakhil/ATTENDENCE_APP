import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// High-performance OCR service for ID card scanning
/// Optimized for speed - processes ID cards quickly
class IDCardOCRService {
  TextRecognizer? _textRecognizer;

  IDCardOCRService() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _textRecognizer = TextRecognizer();
    }
  }

  /// Extract name and registration number from ID card - FAST
  Future<Map<String, String?>> extractIDCardInfo(String imagePath) async {
    if (_textRecognizer == null) {
      return {'name': null, 'regNo': null};
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await _textRecognizer!.processImage(inputImage);
      return _parseIDCard(recognized.text);
    } catch (e) {
      debugPrint('OCR Error: $e');
      return {'name': null, 'regNo': null, 'error': e.toString()};
    }
  }

  /// Fast parsing - extracts name and reg number
  Map<String, String?> _parseIDCard(String rawText) {
    String? name;
    String? regNo;

    final lines = rawText.split('\n');

    for (final line in lines) {
      final text = line.trim();
      if (text.length < 3) continue;

      // === REGISTRATION NUMBER ===
      // Pattern: 8-15 digits (like 99230040782)
      if (regNo == null) {
        final digitMatch = RegExp(r'\b(\d{8,15})\b').firstMatch(text);
        if (digitMatch != null) {
          regNo = digitMatch.group(1);
          continue;
        }
        // Alphanumeric pattern like 21BCE1234
        final alphaMatch = RegExp(r'\b(\d{2}[A-Z]{2,4}\d{4,})\b').firstMatch(text);
        if (alphaMatch != null) {
          regNo = alphaMatch.group(1);
          continue;
        }
      }

      // === NAME ===
      // Look for uppercase words (typical on ID cards)
      if (name == null && _isLikelyName(text)) {
        final extracted = _extractName(text);
        if (extracted != null && extracted.split(' ').length >= 2) {
          name = extracted;
        }
      }
    }

    // Fallback: find any uppercase word sequence
    if (name == null) {
      name = _fallbackNameSearch(rawText);
    }

    return {
      'name': name?.toUpperCase().trim(),
      'regNo': regNo?.trim(),
    };
  }

  /// Quick check if line looks like a name
  bool _isLikelyName(String text) {
    final lower = text.toLowerCase();
    // Skip common non-name text
    if (lower.contains('university') ||
        lower.contains('college') ||
        lower.contains('academy') ||
        lower.contains('student') ||
        lower.contains('b.tech') ||
        lower.contains('engineering') ||
        lower.contains('department') ||
        lower.contains('registrar') ||
        lower.contains('deemed') ||
        lower.contains('education') ||
        lower.contains('research') ||
        lower.contains('accredited') ||
        lower.contains('naac') ||
        lower.contains('grade')) {
      return false;
    }

    // Must be mostly letters
    final lettersOnly = text.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
    return lettersOnly.length >= text.length * 0.7;
  }

  /// Extract name from line
  String? _extractName(String text) {
    // Remove numbers and special chars
    String cleaned = text
        .replaceAll(RegExp(r'\d+[-–]\d+'), '')
        .replaceAll(RegExp(r'\b\d{4}\b'), '')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
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
    const skip = ['the', 'and', 'for', 'from', 'with', 'under', 
                  'computer', 'science', 'engineering', 'technology',
                  'university', 'college', 'academy', 'institute',
                  'student', 'valid', 'year', 'date'];
    return skip.contains(w);
  }

  /// Fallback: find uppercase word sequences
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
    const ignored = ['KALASALINGAM', 'UNIVERSITY', 'COLLEGE', 'ACADEMY',
                     'EDUCATION', 'RESEARCH', 'DEEMED', 'ENGINEERING',
                     'STUDENT', 'DEPARTMENT', 'COMPUTER', 'SCIENCE'];
    final upper = text.toUpperCase();
    return ignored.any((w) => upper.contains(w));
  }

  void dispose() {
    _textRecognizer?.close();
  }
}
