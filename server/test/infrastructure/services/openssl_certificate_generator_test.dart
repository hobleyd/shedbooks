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

import 'package:test/test.dart';

import 'package:shedbooks_server/domain/exceptions/o365_sync_exception.dart';
import 'package:shedbooks_server/infrastructure/services/openssl_certificate_generator.dart';

void main() {
  /// A fake `openssl`/`chmod` runner that writes plausible output files for
  /// whichever openssl subcommand is invoked, so the generator's
  /// file-reads after each step succeed without ever shelling out for real.
  Future<ProcessResult> Function(String, List<String>) fakeOpenSsl({
    void Function(List<String> args)? onCall,
  }) {
    return (executable, arguments) async {
      onCall?.call(arguments);
      if (executable == 'chmod') return ProcessResult(0, 0, '', '');
      if (executable != 'openssl') return ProcessResult(0, 0, '', '');

      String outPathAfter(String flag) =>
          arguments[arguments.indexOf(flag) + 1];

      switch (arguments.first) {
        case 'req':
          await File(outPathAfter('-keyout')).writeAsString('fake-key');
          await File(outPathAfter('-out')).writeAsString('fake-cert-pem');
          break;
        case 'pkcs12':
          await File(outPathAfter('-out')).writeAsBytes([1, 2, 3, 4]);
          break;
        case 'x509':
          await File(outPathAfter('-out')).writeAsBytes([5, 6, 7]);
          break;
      }
      return ProcessResult(0, 0, '', '');
    };
  }

  group('OpenSslCertificateGenerator', () {
    test('returns base64-encoded pfx and public cert bytes with an expiry',
        () async {
      // Arrange
      final sut =
          OpenSslCertificateGenerator(runProcess: fakeOpenSsl());

      // Act
      final result = await sut.generateSelfSigned(
        password: 'hunter2',
        subjectName: 'Shedbooks O365 Sync',
      );

      // Assert
      expect(base64Decode(result.pfxBase64), equals([1, 2, 3, 4]));
      expect(base64Decode(result.publicCertBase64), equals([5, 6, 7]));
      expect(result.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('passes the subject name to openssl req and the password via a '
        'file, never argv', () async {
      // Arrange
      final calls = <List<String>>[];
      final sut = OpenSslCertificateGenerator(
        runProcess: fakeOpenSsl(onCall: calls.add),
      );

      // Act
      await sut.generateSelfSigned(
        password: 'super-secret-password',
        subjectName: 'Shedbooks O365 Sync',
      );

      // Assert
      final reqArgs = calls.firstWhere((a) => a.first == 'req');
      expect(reqArgs, contains('/CN=Shedbooks O365 Sync'));

      final pkcs12Args = calls.firstWhere((a) => a.first == 'pkcs12');
      final passoutArg =
          pkcs12Args[pkcs12Args.indexOf('-passout') + 1];
      expect(passoutArg, startsWith('file:'));
      expect(pkcs12Args.join(' '), isNot(contains('super-secret-password')));
    });

    test('restricts permissions on every temporary file it writes',
        () async {
      // Arrange
      final chmodCalls = <List<String>>[];
      final sut = OpenSslCertificateGenerator(
        runProcess: (executable, arguments) async {
          if (executable == 'chmod') chmodCalls.add(arguments);
          return fakeOpenSsl()(executable, arguments);
        },
      );

      // Act
      await sut.generateSelfSigned(password: 'hunter2', subjectName: 'CN');

      // Assert — key, cert, pass file, and pfx all restricted.
      expect(chmodCalls, hasLength(4));
      expect(chmodCalls.every((c) => c.first == '600'), isTrue);
    });

    test('throws O365CertificateGenerationException when openssl exits non-zero',
        () async {
      // Arrange
      final sut = OpenSslCertificateGenerator(
        runProcess: (executable, arguments) async {
          if (executable == 'openssl') {
            return ProcessResult(0, 1, '', 'no such algorithm');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(
        () => sut.generateSelfSigned(password: 'hunter2', subjectName: 'CN'),
        throwsA(isA<O365CertificateGenerationException>()),
      );
    });

    test('throws O365CertificateGenerationException when openssl is not installed',
        () async {
      // Arrange
      final sut = OpenSslCertificateGenerator(
        runProcess: (executable, arguments) async {
          if (executable == 'openssl') {
            throw const ProcessException(
                'openssl', [], 'No such file or directory');
          }
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      expect(
        () => sut.generateSelfSigned(password: 'hunter2', subjectName: 'CN'),
        throwsA(isA<O365CertificateGenerationException>()),
      );
    });

    test('throws O365CertificateGenerationException on timeout', () async {
      // Arrange
      final sut = OpenSslCertificateGenerator(
        timeout: const Duration(milliseconds: 50),
        runProcess: (executable, arguments) async {
          if (executable == 'openssl') return Completer<ProcessResult>().future;
          return ProcessResult(0, 0, '', '');
        },
      );

      // Act / Assert
      await expectLater(
        () => sut.generateSelfSigned(password: 'hunter2', subjectName: 'CN'),
        throwsA(isA<O365CertificateGenerationException>()),
      );
    });
  });
}
