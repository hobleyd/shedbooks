// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';
import 'dart:typed_data';

import 'package:shedbooks_server/infrastructure/encryption/backup_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('BackupCrypto', () {
    const secret = 'test-backup-secret';
    final crypto = BackupCrypto(secret);
    const plainJson = '{"version":1,"entity_id":"org_abc","data":[1,2,3]}';

    // ── encryptAndCompress / decryptAndDecompress ──────────────────────────

    test('round-trip returns original plaintext', () {
      // Arrange
      final input = Uint8List.fromList(utf8.encode(plainJson));

      // Act
      final encrypted = crypto.encryptAndCompress(input);
      final decrypted = crypto.decryptAndDecompress(encrypted);

      // Assert
      expect(utf8.decode(decrypted), equals(plainJson));
    });

    test('each encryption produces different ciphertext (random nonce)', () {
      // Arrange
      final input = Uint8List.fromList(utf8.encode(plainJson));

      // Act
      final enc1 = crypto.encryptAndCompress(input);
      final enc2 = crypto.encryptAndCompress(input);

      // Assert
      expect(enc1, isNot(equals(enc2)));
    });

    test('compresses — output is smaller than input for repetitive data', () {
      // Arrange
      final large = List.generate(500, (i) => plainJson).join(',');
      final input = Uint8List.fromList(utf8.encode(large));

      // Act
      final encrypted = crypto.encryptAndCompress(input);

      // Assert
      expect(encrypted.length, lessThan(input.length));
    });

    // ── isEncrypted ────────────────────────────────────────────────────────

    test('isEncrypted returns true for encrypted output', () {
      // Arrange
      final input = Uint8List.fromList(utf8.encode(plainJson));
      final encrypted = crypto.encryptAndCompress(input);

      // Act / Assert
      expect(BackupCrypto.isEncrypted(encrypted), isTrue);
    });

    test('isEncrypted returns false for plain JSON bytes', () {
      // Arrange
      final plainBytes = Uint8List.fromList(utf8.encode(plainJson));

      // Act / Assert
      expect(BackupCrypto.isEncrypted(plainBytes), isFalse);
    });

    test('isEncrypted returns false for empty bytes', () {
      expect(BackupCrypto.isEncrypted(Uint8List(0)), isFalse);
    });

    // ── Error cases ────────────────────────────────────────────────────────

    test('decryptAndDecompress throws FormatException for plain-JSON input', () {
      // Arrange
      final plainBytes = Uint8List.fromList(utf8.encode(plainJson));

      // Act / Assert
      expect(
        () => crypto.decryptAndDecompress(plainBytes),
        throwsFormatException,
      );
    });

    test('decryptAndDecompress throws on wrong key', () {
      // Arrange
      final input = Uint8List.fromList(utf8.encode(plainJson));
      final encrypted = crypto.encryptAndCompress(input);
      final wrongCrypto = BackupCrypto('completely-different-secret');

      // Act / Assert
      expect(
        () => wrongCrypto.decryptAndDecompress(encrypted),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('decryptAndDecompress throws on tampered ciphertext', () {
      // Arrange
      final input = Uint8List.fromList(utf8.encode(plainJson));
      final encrypted = crypto.encryptAndCompress(input);
      // Flip a byte in the ciphertext (after the 16-byte header).
      final tampered = Uint8List.fromList(encrypted);
      tampered[20] ^= 0xFF;

      // Act / Assert
      expect(
        () => crypto.decryptAndDecompress(tampered),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ── Different secrets produce different outputs ─────────────────────────

    test('two BackupCrypto instances with different secrets cannot cross-decrypt', () {
      // Arrange
      final crypto2 = BackupCrypto('other-secret');
      final input = Uint8List.fromList(utf8.encode(plainJson));

      // Act
      final encrypted = crypto.encryptAndCompress(input);

      // Assert
      expect(
        () => crypto2.decryptAndDecompress(encrypted),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
