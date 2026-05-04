import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/gst_rate.dart';
import 'package:shedbooks_server/domain/exceptions/gst_rate_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_gst_rate_repository.dart';
import 'package:shedbooks_server/application/gst_rate/delete_gst_rate_use_case.dart';

class MockGstRateRepository extends Mock implements IGstRateRepository {}

void main() {
  late MockGstRateRepository repository;
  late DeleteGstRateUseCase sut;

  const tId = '00000000-0000-0000-0000-000000000001';
  final tRate = GstRate(
    id: tId,
    rate: 0.10,
    effectiveFrom: DateTime.utc(2000, 7, 1),
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockGstRateRepository();
    sut = DeleteGstRateUseCase(repository);
  });

  group('DeleteGstRateUseCase', () {
    test('calls repository delete when rate exists', () async {
      // Arrange
      when(() => repository.findById(tId)).thenAnswer((_) async => tRate);
      when(() => repository.delete(tId)).thenAnswer((_) async {});

      // Act
      await sut.execute(tId);

      // Assert
      verify(() => repository.delete(tId)).called(1);
    });

    test('throws GstRateNotFoundException when rate does not exist', () async {
      // Arrange
      when(() => repository.findById(tId)).thenAnswer((_) async => null);

      // Act / Assert
      expect(
        () => sut.execute(tId),
        throwsA(isA<GstRateNotFoundException>()),
      );
      verifyNever(() => repository.delete(any()));
    });
  });
}
