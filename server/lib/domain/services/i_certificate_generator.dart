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

import '../exceptions/o365_sync_exception.dart';

/// A freshly generated self-signed certificate.
class GeneratedCertificate {
  /// Base64-encoded PKCS#12 (.pfx) — public and private key, password
  /// protected. This is what gets stored as
  /// `O365SyncSettings.certificatePfxBase64`.
  final String pfxBase64;

  /// Base64-encoded DER (.cer) — public key only. This is what the admin
  /// downloads and uploads to the Azure app registration; it must never be
  /// treated as a secret (no private key inside it).
  final String publicCertBase64;

  final DateTime expiresAt;

  const GeneratedCertificate({
    required this.pfxBase64,
    required this.publicCertBase64,
    required this.expiresAt,
  });
}

/// Generates self-signed certificates for Exchange Online app-only auth.
abstract interface class ICertificateGenerator {
  /// Creates a new RSA key pair and a self-signed certificate over it,
  /// packaged as a password-protected PKCS#12 file.
  ///
  /// Throws [O365CertificateGenerationException] on failure.
  Future<GeneratedCertificate> generateSelfSigned({
    required String password,
    required String subjectName,
  });
}
