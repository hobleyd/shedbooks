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

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/application/o365/generate_o365_certificate_use_case.dart';
import 'package:shedbooks_server/domain/exceptions/o365_sync_exception.dart';
import 'package:shedbooks_server/domain/services/i_certificate_generator.dart';

class MockCertificateGenerator extends Mock implements ICertificateGenerator {}

void main() {
  late MockCertificateGenerator generator;
  late GenerateO365CertificateUseCase sut;

  final tCertificate = GeneratedCertificate(
    pfxBase64: 'ZmFrZS1wZng=',
    publicCertBase64: 'ZmFrZS1jZXI=',
    expiresAt: DateTime.utc(2028, 1, 1),
  );

  setUp(() {
    generator = MockCertificateGenerator();
    sut = GenerateO365CertificateUseCase(generator);
  });

  group('GenerateO365CertificateUseCase', () {
    test('generates a certificate with a fixed subject name', () async {
      // Arrange
      when(() => generator.generateSelfSigned(
          password: any(named: 'password'),
          subjectName: any(named: 'subjectName'))).thenAnswer((_) async => tCertificate);

      // Act
      final result = await sut.execute(password: 'hunter2');

      // Assert
      expect(result, equals(tCertificate));
      verify(() => generator.generateSelfSigned(
          password: 'hunter2', subjectName: 'Shedbooks O365 Sync')).called(1);
    });

    test('trims whitespace from the password before passing it through',
        () async {
      // Arrange
      when(() => generator.generateSelfSigned(
          password: any(named: 'password'),
          subjectName: any(named: 'subjectName'))).thenAnswer((_) async => tCertificate);

      // Act
      await sut.execute(password: '  hunter2  ');

      // Assert
      verify(() => generator.generateSelfSigned(
          password: 'hunter2', subjectName: any(named: 'subjectName'))).called(1);
    });

    test('throws O365SyncValidationException when the password is blank',
        () async {
      // Act / Assert
      expect(
        () => sut.execute(password: '   '),
        throwsA(isA<O365SyncValidationException>()),
      );
      verifyNever(() => generator.generateSelfSigned(
          password: any(named: 'password'),
          subjectName: any(named: 'subjectName')));
    });
  });
}
