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

import 'package:shedbooks_server/domain/entities/gst_rate.dart';
import 'package:shedbooks_server/domain/exceptions/gst_rate_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_gst_rate_repository.dart';
import 'package:shedbooks_server/application/gst_rate/update_gst_rate_use_case.dart';

class MockGstRateRepository extends Mock implements IGstRateRepository {}

void main() {
  late MockGstRateRepository repository;
  late UpdateGstRateUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  const tEntityId = 'entity-1';
  final tEffectiveFrom = DateTime.utc(2026, 7, 1);
  final tUpdated = GstRate(
    id: tId,
    rate: 0.15,
    effectiveFrom: tEffectiveFrom,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 2, 1),
  );

  setUp(() {
    repository = MockGstRateRepository();
    sut = UpdateGstRateUseCase(repository);
    registerFallbackValue(tEffectiveFrom);
  });

  group('UpdateGstRateUseCase', () {
    test('updates and returns the updated entity', () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          entityId: tEntityId,
          rate: 0.15,
          effectiveFrom: tEffectiveFrom,
        ),
      ).thenAnswer((_) async => tUpdated);

      // Act
      final result = await sut.execute(
        id: tId,
        entityId: tEntityId,
        rate: 0.15,
        effectiveFrom: tEffectiveFrom,
      );

      // Assert
      expect(result, equals(tUpdated));
    });

    test('throws GstRateValidationException when rate is negative', () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          rate: -0.01,
          effectiveFrom: tEffectiveFrom,
        ),
        throwsA(isA<GstRateValidationException>()),
      );
    });

    test('throws GstRateNotFoundException propagated from repository',
        () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          entityId: tEntityId,
          rate: any(named: 'rate'),
          effectiveFrom: any(named: 'effectiveFrom'),
        ),
      ).thenThrow(GstRateNotFoundException(tId));

      // Act / Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          rate: 0.10,
          effectiveFrom: tEffectiveFrom,
        ),
        throwsA(isA<GstRateNotFoundException>()),
      );
    });

    test(
        'throws GstRateDuplicateEffectiveDateException propagated from repository',
        () async {
      // Arrange
      when(
        () => repository.update(
          id: tId,
          entityId: tEntityId,
          rate: any(named: 'rate'),
          effectiveFrom: any(named: 'effectiveFrom'),
        ),
      ).thenThrow(GstRateDuplicateEffectiveDateException(tEffectiveFrom));

      // Act / Assert
      expect(
        () => sut.execute(
          id: tId,
          entityId: tEntityId,
          rate: 0.10,
          effectiveFrom: tEffectiveFrom,
        ),
        throwsA(isA<GstRateDuplicateEffectiveDateException>()),
      );
    });
  });
}
