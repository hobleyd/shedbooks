import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'pdf_decrypt.dart';

/// A positioned text element extracted from a PDF content stream.
class TextElement {
  final double x;
  final double y;
  final String text;

  const TextElement({required this.x, required this.y, required this.text});
}

/// Extracts positioned text elements from a raw PDF byte array.
///
/// Finds every stream/endstream block, attempts zlib decompression, then
/// parses `1 0 0 1 x y Tm … (text)Tj` sequences from the decoded content.
class PdfTextExtractor {
  /// Returns all [TextElement]s from every page of the PDF.
  static List<TextElement> extract(Uint8List bytes) {
    final elements = <TextElement>[];

    // If the PDF is Standard-encrypted (RC4), build a decryptor.
    final decryptor = PdfDecryptor.fromPdf(bytes);

    // We need the decoded text to look up object numbers adjacent to streams.
    final pdfText = latin1.decode(bytes, allowInvalid: true);

    int pos = 0;
    while (true) {
      // Find next occurrence of the literal word "stream" (not "endstream").
      final streamIdx = _findStreamKeyword(bytes, pos);
      if (streamIdx < 0) break;

      // "stream" must be followed by \r\n or \n.
      int contentStart = streamIdx + 6;
      if (contentStart < bytes.length && bytes[contentStart] == 13) {
        contentStart++;
      }
      if (contentStart >= bytes.length || bytes[contentStart] != 10) {
        pos = streamIdx + 1;
        continue;
      }
      contentStart++;

      // Find the matching endstream keyword.
      final endIdx = _indexOfBytes(bytes, _endStreamMarker, contentStart);
      if (endIdx < 0) break;

      pos = endIdx + _endStreamMarker.length;

      // Strip optional trailing \r\n before endstream.
      int end = endIdx;
      if (end > contentStart && bytes[end - 1] == 10) end--;
      if (end > contentStart && bytes[end - 1] == 13) end--;

      if (end <= contentStart) continue;
      List<int> raw = bytes.sublist(contentStart, end);

      // If the PDF is encrypted, RC4-decrypt the stream using its object number.
      if (decryptor != null) {
        final (objNum, genNum) = _findObjectNumber(pdfText, streamIdx);
        if (objNum > 0) {
          raw = decryptor.decrypt(raw, objNum, genNum);
        }
      }

      // Try zlib then raw deflate decompression.
      List<int>? decompressed;
      try {
        decompressed = zlib.decode(raw);
      } catch (_) {
        try {
          decompressed = ZLibDecoder(raw: true).convert(raw);
        } catch (_) {
          continue; // Not a compressed stream — skip.
        }
      }

      final streamText = latin1.decode(decompressed, allowInvalid: true);
      elements.addAll(_parseContentStream(streamText));
    }

    return elements;
  }

  /// Finds the object number for the stream keyword at [streamCharPos].
  ///
  /// Scans backward from [streamCharPos] for the nearest `N G obj` pattern.
  static (int, int) _findObjectNumber(String pdfText, int streamCharPos) {
    // Look back up to 2000 chars to find the nearest `N G obj`.
    final searchStart = (streamCharPos - 2000).clamp(0, pdfText.length);
    final region = pdfText.substring(searchStart, streamCharPos);
    final objRe = RegExp(r'(\d+)\s+(\d+)\s+obj\b');
    RegExpMatch? last;
    for (final m in objRe.allMatches(region)) {
      last = m;
    }
    if (last == null) return (0, 0);
    return (int.parse(last.group(1)!), int.parse(last.group(2)!));
  }

  // ── Byte scanning ─────────────────────────────────────────────────────────

  static final List<int> _streamMarker = latin1.encode('stream');
  static final List<int> _endStreamMarker = latin1.encode('endstream');
  static final List<int> _endPrefix = latin1.encode('end');

  /// Finds the next occurrence of the word "stream" that is NOT part of "endstream".
  static int _findStreamKeyword(Uint8List bytes, int from) {
    int pos = from;
    while (true) {
      final idx = _indexOfBytes(bytes, _streamMarker, pos);
      if (idx < 0) return -1;
      // Reject if preceded by "end".
      if (idx >= 3) {
        bool isEnd = true;
        for (int i = 0; i < 3; i++) {
          if (bytes[idx - 3 + i] != _endPrefix[i]) {
            isEnd = false;
            break;
          }
        }
        if (isEnd) {
          pos = idx + 6;
          continue;
        }
      }
      return idx;
    }
  }

  static int _indexOfBytes(Uint8List haystack, List<int> needle, int from) {
    if (needle.isEmpty) return from;
    outer:
    for (int i = from; i <= haystack.length - needle.length; i++) {
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  // ── Content stream parser ─────────────────────────────────────────────────

  static final _tmRe = RegExp(r'1\s+0\s+0\s+1\s+([-\d.]+)\s+([-\d.]+)\s+Tm');
  static final _tjRe = RegExp(r'\(([^)]*(?:\\.[^)]*)*)\)\s*Tj');

  /// Parses a decompressed PDF content stream and returns text elements.
  static List<TextElement> _parseContentStream(String stream) {
    final elements = <TextElement>[];
    double curX = 0, curY = 0;

    for (final line in stream.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Update text matrix — may appear on same line as Tj.
      final tmMatch = _tmRe.firstMatch(trimmed);
      if (tmMatch != null) {
        curX = double.tryParse(tmMatch.group(1)!) ?? curX;
        curY = double.tryParse(tmMatch.group(2)!) ?? curY;
        // Fall through: allow Tj on the same line.
      }

      // Extract all (text)Tj occurrences on this line.
      for (final match in _tjRe.allMatches(trimmed)) {
        final decoded = _decodePdfString(match.group(1)!);
        if (decoded.trim().isNotEmpty) {
          elements.add(TextElement(x: curX, y: curY, text: decoded.trim()));
        }
      }
    }

    return elements;
  }

  /// Handles PDF string escape sequences.
  static String _decodePdfString(String raw) {
    final buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (raw[i] == r'\' && i + 1 < raw.length) {
        switch (raw[i + 1]) {
          case 'n':
            buf.write('\n');
          case 'r':
            buf.write('\r');
          case 't':
            buf.write('\t');
          case '(':
            buf.write('(');
          case ')':
            buf.write(')');
          case r'\':
            buf.write(r'\');
          default:
            buf.write(raw[i + 1]);
        }
        i++;
      } else {
        buf.write(raw[i]);
      }
    }
    return buf.toString();
  }
}
