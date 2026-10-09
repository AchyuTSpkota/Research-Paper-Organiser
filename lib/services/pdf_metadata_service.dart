import 'dart:io';
import 'dart:isolate';

import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfMetadataService {
  Future<Map<String, dynamic>> read(String pdfPath) async {
    final file = File(pdfPath);
    if (!file.existsSync()) {
      throw Exception('PDF not found: $pdfPath');
    }

    // Runs in a background isolate so the UI never freezes.
    // If extraction takes longer than 60 seconds, we give up gracefully.
    try {
      final result = await Isolate.run(() => _extract(pdfPath))
          .timeout(const Duration(seconds: 60));
      return result;
    } catch (e) {
      // Fall back to a metadata-only entry so the app doesn't hang forever.
      return {
        'title': _fileStem(pdfPath),
        'authors': 'Unknown author',
        'year': DateTime.now().year,
        'abstract': '',
        'keywords': '',
        'doi': '',
        'fullText': '',
      };
    }
  }
}

// -------- top-level functions (required for isolates) --------

Map<String, dynamic> _extract(String pdfPath) {
  final bytes = File(pdfPath).readAsBytesSync();
  final document = PdfDocument(inputBytes: bytes);
  try {
    final extractor = PdfTextExtractor(document);
    final fullText = extractor.extractText();
    final pages = fullText.split('\f');
    final head = pages.isNotEmpty ? pages.first : '';
    final fallbackTitle = _fileStem(pdfPath);

    return {
      'title': _guessTitle(head, fallbackTitle),
      'authors': _guessAuthors(head),
      'year': _guessYear(head) ?? DateTime.now().year,
      'abstract': _guessAbstract(fullText),
      'keywords': '',
      'doi': _guessDoi(fullText),
      'fullText': fullText,
    };
  } finally {
    document.dispose();
  }
}

String _fileStem(String path) {
  final fileName = path.split('\\').last.split('/').last;
  return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
}

String _guessTitle(String head, String fallback) {
  if (head.isEmpty) return fallback;
  final lines = head
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.length >= 12 && l.length <= 220)
      .toList();
  for (final l in lines.take(8)) {
    final letters = l.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length < 10) continue;
    final upperRatio =
        letters.split('').where((c) => c == c.toUpperCase()).length /
            letters.length;
    if (upperRatio > 0.85) continue;
    return l;
  }
  return fallback;
}

String _guessAuthors(String head) {
  final match = RegExp(
    r'^([A-Z][\w\.\-]+(?:\s+[A-Z][\w\.\-]+){0,3}(?:\s*,\s*|\s+and\s+)[^\n]{3,120})$',
    multiLine: true,
  ).firstMatch(head);
  return match?.group(1) ?? 'Unknown author';
}

int? _guessYear(String text) {
  final m = RegExp(r'\b(19[5-9]\d|20[0-4]\d)\b').firstMatch(text);
  return m == null ? null : int.tryParse(m.group(1)!);
}

String _guessAbstract(String text) {
  final m = RegExp(
    r'\b(?:Abstract|ABSTRACT|Summary)\b[\s:—\-–]*\n?(.{120,2500}?)(?:\n\s*\n|\b(?:1\.?\s+Introduction|Keywords|Index Terms)\b)',
    dotAll: true,
  ).firstMatch(text);
  if (m == null) return '';
  return m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _guessDoi(String text) {
  final m = RegExp(
    r'\b10\.\d{4,9}/[-._;()/:A-Z0-9]+\b',
    caseSensitive: false,
  ).firstMatch(text);
  return m?.group(0)?.replaceAll(RegExp(r'[.,;]$'), '') ?? '';
}