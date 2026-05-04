import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/gst_rate.dart';
import 'package:shedbooks_server/domain/exceptions/gst_rate_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_gst_rate_repository.dart';
import 'package:shedbooks_server/application/gst_rate/create_gst_rate_use_case.dart';

class MockGstRateRepository extends Mock implements IGstRateRepository {}

void main() {
  late MockGstRateRepository repository;
  late CreateGstRateUseCase sut;

  final tEffectiveFrom = DateTime.utc(2026, 7, 1);
  final tRate = GstRate(
    id: '00000000-0000-0000-0000-000000000001',
    rate: 0.10,
    effectiveFrom: tEffectiveFrom,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockGstRateRepository();
    sut = CreateGstRateUseCase(repository);
    registerFallbackValue(tEffectiveFrom);
  });

  group('CreateGstRateUseCase', () {
    test('creates rate and returns the persisted entity', () async {
      // Arrange
      when(
        () => repository.create(rate: 0.10, effectiveFrom: tEffectiveFrom),
      ).thenAnswer((_) async => tRate);

      // Act
      final result = await sut.execute(rate: 0.10, effectiveFrom: tEffectiveFrom);

      // Assert
      expect(result, equals(tRate));
      verify(() => repository.create(rate: 0.10, effectiveFrom: tEffectiveFrom)).called(1);
    });

    test('throws GstRateValidationException when rate is negative', () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(rate: -0.01, effectiveFrom: tEffectiveFrom),
        throwsA(isA<GstRateValidationException>()),
      );
      verifyNever(
        () => repository.create(
          rate: any(named: 'rate'),
          effectiveFrom: any(named: 'effectiveFrom'),
        ),
      );
    });

    test('throws GstRateValidationException when rate exceeds 1', () async {
      // Arrange / Act / Assert
      expect(
        () => sut.execute(rate: 1.01, effectiveFrom: tEffectiveFrom),
        throwsA(isA<GstRateValidationException>()),
      );
    });

    test('allows rate of exactly 0 (GST-free period)', () async {
      // Arrange
      final zeroRate = GstRate(
        id: '00000000-0000-0000-0000-000000000002',
        rate: 0.0,
        effectiveFrom: tEffectiveFrom,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      when(
        () => repository.create(rate: 0.0, effectiveFrom: tEffectiveFrom),
      ).thenAnswer((_) async => zeroRate);

      // Act
      final result = await sut.execute(rate: 0.0, effectiveFrom: tEffectiveFrom);

      // Assert
      expect(result.rate, equals(0.0));
    });

    test('allows rate of exactly 1', () async {
      // Arrange
      final fullRate = GstRate(
        id: '00000000-0000-0000-0000-000000000003',
        rate: 1.0,
        effectiveFrom: tEffectiveFrom,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      when(
        () => repository.create(rate: 1.0, effectiveFrom: tEffectiveFrom),
      ).thenAnswer((_) async => fullRate);

      // Act
      final result = await sut.execute(rate: 1.0, effectiveFrom: tEffectiveFrom);

      // Assert
      expect(result.rate, equals(1.0));
    });
  });
}
