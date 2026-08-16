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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/exceptions/o365_sync_exception.dart';
import '../../domain/services/i_certificate_generator.dart';
import 'process_runner.dart';

/// Generates self-signed certificates by shelling out to `openssl` —
/// PowerShell's certificate-generation cmdlets (`New-SelfSignedCertificate`)
/// are part of the Windows-only PKI module and unavailable on PowerShell
/// Core/Linux, so this can't reuse the Exchange Online PowerShell runtime
/// already in the image.
///
/// Used for Exchange Online app-only auth (see
/// ExchangeOnlineMailContactSyncService) — the generated certificate's
/// public half is handed back to the admin to upload to their Azure app
/// registration; the private-key-bearing PFX is what gets stored (encrypted)
/// in `O365SyncSettings`.
class OpenSslCertificateGenerator implements ICertificateGenerator {
  static const _validityDays = 730; // ~2 years

  final ProcessRunner _runProcess;
  final Duration _timeout;

  OpenSslCertificateGenerator({
    ProcessRunner? runProcess,
    Duration timeout = const Duration(seconds: 30),
  })  : _runProcess = runProcess ?? Process.run,
        _timeout = timeout;

  @override
  Future<GeneratedCertificate> generateSelfSigned({
    required String password,
    required String subjectName,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('o365cert-');
    try {
      final keyPath = '${tempDir.path}/key.pem';
      final certPath = '${tempDir.path}/cert.pem';
      final derPath = '${tempDir.path}/cert.cer';
      final pfxPath = '${tempDir.path}/cert.pfx';
      final passFilePath = '${tempDir.path}/pfx.pass';

      // Self-signed cert + unencrypted key — the key only ever exists
      // inside this restricted, short-lived temp dir; PKCS#12 export below
      // is what actually protects it with the caller's password.
      await _run([
        'req', '-x509', '-newkey', 'rsa:2048',
        '-keyout', keyPath, '-out', certPath,
        '-days', '$_validityDays', '-nodes',
        '-subj', '/CN=$subjectName',
      ]);
      await _restrictPermissions(keyPath);
      await _restrictPermissions(certPath);

      // Password passed via a file, not argv, so it never appears in a
      // process listing (`ps`).
      await File(passFilePath).writeAsString(password);
      await _restrictPermissions(passFilePath);
      await _run([
        'pkcs12', '-export', '-out', pfxPath,
        '-inkey', keyPath, '-in', certPath,
        '-passout', 'file:$passFilePath',
      ]);
      await _restrictPermissions(pfxPath);

      // The public certificate (no private key) — safe to hand to the
      // client for download and upload to Azure.
      await _run(['x509', '-in', certPath, '-outform', 'DER', '-out', derPath]);

      final pfxBytes = await File(pfxPath).readAsBytes();
      final derBytes = await File(derPath).readAsBytes();

      return GeneratedCertificate(
        pfxBase64: base64Encode(pfxBytes),
        publicCertBase64: base64Encode(derBytes),
        expiresAt:
            DateTime.now().toUtc().add(const Duration(days: _validityDays)),
      );
    } finally {
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
    }
  }

  Future<void> _run(List<String> args) async {
    final ProcessResult result;
    try {
      result = await _runProcess('openssl', args).timeout(_timeout);
    } on TimeoutException {
      throw const O365CertificateGenerationException(
          'Certificate generation timed out');
    } on ProcessException catch (e) {
      throw O365CertificateGenerationException(
          'openssl not available: ${e.message}');
    }
    if (result.exitCode != 0) {
      throw O365CertificateGenerationException(
          'openssl failed: ${result.stderr}');
    }
  }

  Future<void> _restrictPermissions(String path) async {
    final result = await _runProcess('chmod', ['600', path]);
    if (result.exitCode != 0) {
      throw const O365CertificateGenerationException(
          'Failed to restrict permissions on a temporary certificate file');
    }
  }
}
