import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/gst_rate.dart';
import 'package:shedbooks_server/domain/repositories/i_gst_rate_repository.dart';
import 'package:shedbooks_server/application/gst_rate/list_gst_rates_use_case.dart';

class MockGstRateRepository extends Mock implements IGstRateRepository {}

void main() {
  late MockGstRateRepository repository;
  late ListGstRatesUseCase sut;

  final tRates = [
    GstRate(
      id: '00000000-0000-0000-0000-000000000002',
      rate: 0.15,
      effectiveFrom: DateTime.utc(2030, 1, 1),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    GstRate(
      id: '00000000-0000-0000-0000-000000000001',
      rate: 0.10,
      effectiveFrom: DateTime.utc(2000, 7, 1),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  setUp(() {
    repository = MockGstRateRepository();
    sut = ListGstRatesUseCase(repository);
  });

  group('ListGstRatesUseCase', () {
    test('returns all active rates from repository', () async {
      // Arrange
      when(() => repository.findAll()).thenAnswer((_) async => tRates);

      // Act
      final result = await sut.execute();

      // Assert
      expect(result, equals(tRates));
      verify(() => repository.findAll()).called(1);
    });

    test('returns empty list when no rates exist', () async {
      // Arrange
      when(() => repository.findAll()).thenAnswer((_) async => []);

      // Act
      final result = await sut.execute();

      // Assert
      expect(result, isEmpty);
    });
  });
}
