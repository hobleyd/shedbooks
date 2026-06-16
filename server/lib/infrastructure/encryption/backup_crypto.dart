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
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Provides gzip compression and AES-256-GCM encryption for backup files.
///
/// File format: [magic(4)] [nonce(12)] [AES-GCM(gzip(plaintext)) + tag(16)]
///
/// The [SBK1] magic header lets [isEncrypted] distinguish new encrypted
/// backups from legacy plain-JSON files so restore can handle both.
///
/// Supply the encryption secret via the `BACKUP_KEY` environment variable.
/// Any non-empty string is accepted; it is hashed with SHA-256 to produce
/// the 32-byte AES key.  When the variable is absent a built-in default is
/// used so the feature works out of the box, but production deployments
/// should set their own secret.
class BackupCrypto {
  static const List<int> _magic = [0x53, 0x42, 0x4B, 0x31]; // 'SBK1'
  static const int _nonceLength = 12;

  final Uint8List _key;

  BackupCrypto(String secret) : _key = _deriveKey(secret);

  /// Returns true if [bytes] begins with the SBK1 magic header.
  static bool isEncrypted(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == _magic[0] &&
      bytes[1] == _magic[1] &&
      bytes[2] == _magic[2] &&
      bytes[3] == _magic[3];

  /// Gzip-compresses then AES-256-GCM-encrypts [plaintext].
  ///
  /// Returns [magic(4) | nonce(12) | ciphertext+tag(n+16)].
  Uint8List encryptAndCompress(List<int> plaintext) {
    final compressed = GZipCodec().encode(plaintext);
    final nonce = _randomBytes(_nonceLength);
    final cipher = _buildCipher(forEncryption: true, nonce: nonce);

    final input = Uint8List.fromList(compressed);
    final output = Uint8List(cipher.getOutputSize(input.length));
    var offset = cipher.processBytes(input, 0, input.length, output, 0);
    offset += cipher.doFinal(output, offset);

    return Uint8List.fromList([..._magic, ...nonce, ...output.sublist(0, offset)]);
  }

  /// AES-256-GCM-decrypts then gzip-decompresses [data].
  ///
  /// Throws [FormatException] when [data] lacks the SBK1 magic header.
  /// Throws [ArgumentError] when the GCM tag is invalid (wrong key or tampered data).
  Uint8List decryptAndDecompress(Uint8List data) {
    if (!isEncrypted(data)) {
      throw FormatException('Not a SBK1 encrypted backup');
    }
    final nonce = data.sublist(4, 4 + _nonceLength);
    final cipherAndTag = data.sublist(4 + _nonceLength);

    final cipher = _buildCipher(forEncryption: false, nonce: nonce);
    final input = Uint8List.fromList(cipherAndTag);
    final output = Uint8List(cipher.getOutputSize(input.length));
    try {
      var offset = cipher.processBytes(input, 0, input.length, output, 0);
      offset += cipher.doFinal(output, offset);
      final decompressed = GZipCodec().decode(output.sublist(0, offset));
      return Uint8List.fromList(decompressed);
    } on InvalidCipherTextException catch (e) {
      throw ArgumentError('Decryption failed — wrong key or corrupted data: $e');
    }
  }

  GCMBlockCipher _buildCipher({
    required bool forEncryption,
    required Uint8List nonce,
  }) {
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      forEncryption,
      AEADParameters(KeyParameter(_key), 128, nonce, Uint8List(0)),
    );
    return cipher;
  }

  static Uint8List _deriveKey(String secret) =>
      SHA256Digest().process(Uint8List.fromList(utf8.encode(secret)));

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }
}
