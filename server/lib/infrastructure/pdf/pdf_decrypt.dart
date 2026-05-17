import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/md5.dart';

/// Decrypts PDF streams that use Standard RC4 encryption (V=1, R=2, 40-bit key).
///
/// CBA bank statement PDFs use 40-bit RC4 with an empty user password.
/// This class derives the file encryption key and can decrypt individual streams.
class PdfDecryptor {
  final Uint8List _fileKey;

  PdfDecryptor._(this._fileKey);

  /// Parses [pdfBytes] for Standard encryption metadata and constructs a
  /// decryptor, or returns null if the PDF is not RC4-encrypted (unencrypted
  /// PDFs don't need decryption).
  static PdfDecryptor? fromPdf(Uint8List pdfBytes) {
    final text = latin1.decode(pdfBytes, allowInvalid: true);

    // Does the PDF use Standard encryption?
    if (!text.contains('/Type /Encrypt')) return null;

    // ── Trailer: locate /Encrypt reference and /ID[0] ──────────────────────

    final trailerIdx = text.lastIndexOf('trailer');
    if (trailerIdx < 0) return null;
    final trailerRegion =
        text.substring(trailerIdx, (trailerIdx + 600).clamp(0, text.length));

    // /Encrypt N G R
    final encRefRe = RegExp(r'/Encrypt\s+(\d+)\s+(\d+)\s+R');
    final encRefMatch = encRefRe.firstMatch(trailerRegion);
    if (encRefMatch == null) return null;
    final encObjNum = int.parse(encRefMatch.group(1)!);

    // /ID [<hex1> <hex2>]
    final idRe = RegExp(r'/ID\s*\[<([0-9a-fA-F]+)>');
    final idMatch = idRe.firstMatch(trailerRegion);
    if (idMatch == null) return null;
    final fileId = _hexDecode(idMatch.group(1)!);

    // ── Encryption object: extract /O, /P ────────────────────────────────────

    final encObjRe = RegExp('${RegExp.escape('$encObjNum 0 obj')}(.*?)endobj',
        dotAll: true);
    final encObjMatch = encObjRe.firstMatch(text);
    if (encObjMatch == null) return null;
    final encDict = encObjMatch.group(1)!;

    // /P integer
    final pRe = RegExp(r'/P\s+(-?\d+)');
    final pMatch = pRe.firstMatch(encDict);
    if (pMatch == null) return null;
    final pValue = int.parse(pMatch.group(1)!);

    // /O (string) — parse the raw string bytes from the PDF bytes.
    final oBytesStart = _findKey(pdfBytes, text, encObjMatch.start, '/O (');
    if (oBytesStart < 0) return null;
    final oValue = _parsePdfStringAt(pdfBytes, oBytesStart);
    if (oValue == null || oValue.length < 32) return null;

    // ── Compute file encryption key (Algorithm 3.1, PDF 1.3 spec) ───────────
    //
    // MD5(padding[32] + O[32] + P[4 LE] + ID0[16]) → take first 5 bytes
    final md5 = MD5Digest();
    md5.update(Uint8List.fromList(_kPadding), 0, 32);
    md5.update(Uint8List.fromList(oValue.sublist(0, 32)), 0, 32);
    final pBytes = Uint8List(4)
      ..buffer.asByteData().setInt32(0, pValue, Endian.little);
    md5.update(pBytes, 0, 4);
    md5.update(Uint8List.fromList(fileId), 0, fileId.length);
    final digest = Uint8List(16);
    md5.doFinal(digest, 0);

    return PdfDecryptor._(digest.sublist(0, 5));
  }

  /// RC4-decrypts [data] belonging to object [objNum] / generation [genNum].
  Uint8List decrypt(List<int> data, int objNum, int genNum) {
    // Per-object key: MD5(fileKey + obj_num[3LE] + gen_num[2LE])
    final keyMat = Uint8List(_fileKey.length + 5);
    keyMat.setAll(0, _fileKey);
    keyMat[_fileKey.length + 0] = objNum & 0xff;
    keyMat[_fileKey.length + 1] = (objNum >> 8) & 0xff;
    keyMat[_fileKey.length + 2] = (objNum >> 16) & 0xff;
    keyMat[_fileKey.length + 3] = genNum & 0xff;
    keyMat[_fileKey.length + 4] = (genNum >> 8) & 0xff;

    final md5 = MD5Digest();
    md5.update(keyMat, 0, keyMat.length);
    final digest = Uint8List(16);
    md5.doFinal(digest, 0);

    final keyLen = (_fileKey.length + 5).clamp(0, 16);
    return Uint8List.fromList(_rc4(digest.sublist(0, keyLen), data));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int _findKey(
      Uint8List bytes, String text, int searchFrom, String key) {
    final idx = text.indexOf(key, searchFrom);
    if (idx < 0) return -1;
    // Position of the '(' in the raw bytes.
    return idx + key.length - 1;
  }

  /// Parses a PDF literal string starting at the `(` at [startIdx] in [bytes].
  static List<int>? _parsePdfStringAt(Uint8List bytes, int startIdx) {
    if (startIdx >= bytes.length || bytes[startIdx] != 0x28 /* '(' */) {
      return null;
    }
    final result = <int>[];
    int i = startIdx + 1;
    while (i < bytes.length) {
      final b = bytes[i];
      if (b == 0x29 /* ')' */) break;
      if (b == 0x5C /* '\' */ && i + 1 < bytes.length) {
        final next = bytes[i + 1];
        switch (next) {
          case 0x6E: // n
            result.add(0x0A);
          case 0x72: // r
            result.add(0x0D);
          case 0x74: // t
            result.add(0x09);
          case 0x62: // b
            result.add(0x08);
          case 0x66: // f
            result.add(0x0C);
          case 0x28: // (
            result.add(0x28);
          case 0x29: // )
            result.add(0x29);
          case 0x5C: // \
            result.add(0x5C);
          default:
            // Octal \ooo
            if (next >= 0x30 && next <= 0x37) {
              int octal = next - 0x30;
              int consumed = 1;
              while (consumed < 3 &&
                  i + 1 + consumed < bytes.length &&
                  bytes[i + 1 + consumed] >= 0x30 &&
                  bytes[i + 1 + consumed] <= 0x37) {
                octal = octal * 8 + (bytes[i + 1 + consumed] - 0x30);
                consumed++;
              }
              result.add(octal & 0xff);
              i += consumed; // extra chars consumed above the +1 below
            } else {
              result.add(next);
            }
        }
        i += 2;
      } else {
        result.add(b);
        i++;
      }
    }
    return result;
  }

  static Uint8List _hexDecode(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static List<int> _rc4(List<int> key, List<int> data) {
    final s = List<int>.generate(256, (i) => i);
    int j = 0;
    for (int i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) & 0xff;
      final tmp = s[i];
      s[i] = s[j];
      s[j] = tmp;
    }
    final out = List<int>.filled(data.length, 0);
    int x = 0, y = 0;
    for (int k = 0; k < data.length; k++) {
      x = (x + 1) & 0xff;
      y = (y + s[x]) & 0xff;
      final tmp = s[x];
      s[x] = s[y];
      s[y] = tmp;
      out[k] = data[k] ^ s[(s[x] + s[y]) & 0xff];
    }
    return out;
  }

  // PDF password-padding constant (PDF 1.3 spec §3.5).
  static const List<int> _kPadding = [
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41,
    0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
    0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
    0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
  ];
}
