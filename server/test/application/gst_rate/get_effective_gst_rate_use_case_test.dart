import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/gst_rate.dart';
import 'package:shedbooks_server/domain/exceptions/gst_rate_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_gst_rate_repository.dart';
import 'package:shedbooks_server/application/gst_rate/get_effective_gst_rate_use_case.dart';

class MockGstRateRepository extends Mock implements IGstRateRepository {}

void main() {
  late MockGstRateRepository repository;
  late GetEffectiveGstRateUseCase sut;

  const tEntityId = 'entity-1';
  final tDate = DateTime.utc(2026, 5, 1);
  final tRate = GstRate(
    id: '00000000-0000-0000-0000-000000000001',
    rate: 0.10,
    effectiveFrom: DateTime.utc(2000, 7, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockGstRateRepository();
    sut = GetEffectiveGstRateUseCase(repository);
    registerFallbackValue(tDate);
  });

  group('GetEffectiveGstRateUseCase', () {
    test('returns the effective rate at the given date', () async {
      // Arrange
      when(() => repository.findEffectiveAt(tDate, entityId: tEntityId))
          .thenAnswer((_) async => tRate);

      // Act
      final result = await sut.execute(entityId: tEntityId, date: tDate);

      // Assert
      expect(result, equals(tRate));
    });

    test('throws GstRateNotEffectiveException when no rate covers the date',
        () async {
      // Arrange
      when(() => repository.findEffectiveAt(tDate, entityId: tEntityId))
          .thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(entityId: tEntityId, date: tDate),
        throwsA(isA<GstRateNotEffectiveException>()),
      );
    });

    test('uses current time when no date is supplied', () async {
      // Arrange — match any DateTime passed to findEffectiveAt
      when(() => repository.findEffectiveAt(any(), entityId: tEntityId))
          .thenAnswer((_) async => tRate);

      // Act
      final result = await sut.execute(entityId: tEntityId);

      // Assert
      expect(result, equals(tRate));
      verify(() => repository.findEffectiveAt(any(), entityId: tEntityId))
          .called(1);
    });
  });
}
