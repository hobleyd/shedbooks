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

import 'package:shedbooks_server/application/contact/lookup_abn_use_case.dart';
import 'package:shedbooks_server/infrastructure/services/abn_lookup_service.dart';

class MockAbnLookupService extends Mock implements AbnLookupService {}

void main() {
  late MockAbnLookupService service;
  late LookupAbnUseCase sut;

  setUp(() {
    service = MockAbnLookupService();
    sut = LookupAbnUseCase(service);
  });

  group('LookupAbnUseCase', () {
    test('returns found and gstRegistered true for GST-registered ABN',
        () async {
      // Arrange
      const abn = '51824753556';
      when(() => service.lookup(abn)).thenAnswer(
        (_) async =>
            const AbnLookupResult(found: true, gstRegistered: true),
      );

      // Act
      final result = await sut.execute(abn);

      // Assert
      expect(result.found, isTrue);
      expect(result.gstRegistered, isTrue);
    });

    test('returns found true and gstRegistered false for non-GST ABN',
        () async {
      // Arrange
      const abn = '12345678901';
      when(() => service.lookup(abn)).thenAnswer(
        (_) async =>
            const AbnLookupResult(found: true, gstRegistered: false),
      );

      // Act
      final result = await sut.execute(abn);

      // Assert
      expect(result.found, isTrue);
      expect(result.gstRegistered, isFalse);
    });

    test('returns found false for an ABN not in the register', () async {
      // Arrange
      const abn = '00000000000';
      when(() => service.lookup(abn)).thenAnswer(
        (_) async =>
            const AbnLookupResult(found: false, gstRegistered: false),
      );

      // Act
      final result = await sut.execute(abn);

      // Assert
      expect(result.found, isFalse);
      expect(result.gstRegistered, isFalse);
    });

    test('propagates exceptions from the service', () async {
      // Arrange
      const abn = '51824753556';
      when(() => service.lookup(abn)).thenThrow(Exception('network error'));

      // Act / Assert
      expect(() => sut.execute(abn), throwsA(isA<Exception>()));
    });
  });
}
