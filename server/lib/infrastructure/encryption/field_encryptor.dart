import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Provides AES-256-GCM authenticated encryption for individual database
/// field values.
///
/// Encrypted values are stored with an [_prefix] so that legacy plaintext
/// rows written before encryption was introduced are returned as-is and
/// re-encrypted transparently on the next write.
///
/// Storage format: `enc:<base64(12-byte-nonce || ciphertext || 16-byte-tag)>`
///
/// The encryption key must be a base64-encoded 32-byte (256-bit) secret
/// supplied via the `ENCRYPTION_KEY` environment variable.
/// Generate one with: `openssl rand -base64 32`
class FieldEncryptor {
  static const _prefix = 'enc:';

  final Uint8List _keyBytes;

  /// Creates a [FieldEncryptor] from a base64-encoded 32-byte key.
  FieldEncryptor(String base64Key) : _keyBytes = base64.decode(base64Key) {
    if (_keyBytes.length != 32) {
      throw ArgumentError(
        'ENCRYPTION_KEY must decode to exactly 32 bytes (256 bits). '
        'Generate one with: openssl rand -base64 32',
      );
    }
  }

  /// Encrypts [plaintext] and returns a prefixed, base64-encoded ciphertext.
  String encrypt(String plaintext) {
    final nonce = _randomBytes(12);
    final cipher = _buildCipher(forEncryption: true, nonce: nonce);

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final output = Uint8List(cipher.getOutputSize(input.length));
    var offset = cipher.processBytes(input, 0, input.length, output, 0);
    offset += cipher.doFinal(output, offset);

    final payload = Uint8List(12 + offset)
      ..setRange(0, 12, nonce)
      ..setRange(12, 12 + offset, output.sublist(0, offset));
    return '$_prefix${base64.encode(payload)}';
  }

  /// Decrypts a value produced by [encrypt].
  ///
  /// If [value] does not start with [_prefix] it is assumed to be legacy
  /// plaintext and is returned unchanged, allowing a gradual migration.
  ///
  /// Throws [ArgumentError] if the authentication tag does not match
  /// (i.e. the ciphertext has been tampered with or the key is wrong).
  String decrypt(String value) {
    if (!value.startsWith(_prefix)) return value;

    final combined = base64.decode(value.substring(_prefix.length));
    final nonce = Uint8List.fromList(combined.sublist(0, 12));
    final cipherAndTag = Uint8List.fromList(combined.sublist(12));

    final cipher = _buildCipher(forEncryption: false, nonce: nonce);
    final output = Uint8List(cipher.getOutputSize(cipherAndTag.length));
    try {
      var offset =
          cipher.processBytes(cipherAndTag, 0, cipherAndTag.length, output, 0);
      offset += cipher.doFinal(output, offset);
      return utf8.decode(output.sublist(0, offset));
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
      AEADParameters(KeyParameter(_keyBytes), 128, nonce, Uint8List(0)),
    );
    return cipher;
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => rng.nextInt(256)),
    );
  }
}
