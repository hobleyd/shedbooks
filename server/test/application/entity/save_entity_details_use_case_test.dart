import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:shedbooks_server/domain/entities/entity_details.dart';
import 'package:shedbooks_server/domain/exceptions/entity_details_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_entity_details_repository.dart';
import 'package:shedbooks_server/application/entity/save_entity_details_use_case.dart';

class MockEntityDetailsRepository extends Mock
    implements IEntityDetailsRepository {}

void main() {
  late MockEntityDetailsRepository repository;
  late SaveEntityDetailsUseCase sut;

  const tEntityId = 'entity-1';
  final tDetails = EntityDetails(
    entityId: tEntityId,
    name: 'Woodgate Mens Shed',
    abn: '12345678901',
    incorporationIdentifier: 'IA-2024-001',
    moneyInReceiptFormat: '',
    moneyOutReceiptFormat: 'P-#####',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    repository = MockEntityDetailsRepository();
    sut = SaveEntityDetailsUseCase(repository);
    registerFallbackValue(tDetails);
  });

  group('SaveEntityDetailsUseCase', () {
    test('saves and returns entity details with valid input', () async {
      // Arrange
      when(() => repository.save(any())).thenAnswer((_) async => tDetails);

      // Act
      final result = await sut.execute(
        entityId: tEntityId,
        name: 'Woodgate Mens Shed',
        abn: '12345678901',
        incorporationIdentifier: 'IA-2024-001',
        moneyInReceiptFormat: '',
        moneyOutReceiptFormat: 'P-#####',
      );

      // Assert
      expect(result.name, equals(tDetails.name));
      expect(result.abn, equals(tDetails.abn));
      verify(() => repository.save(any())).called(1);
    });

    test('trims whitespace from all string fields before saving', () async {
      // Arrange
      when(() => repository.save(any())).thenAnswer((_) async => tDetails);

      // Act
      await sut.execute(
        entityId: tEntityId,
        name: '  Woodgate Mens Shed  ',
        abn: '  12345678901  ',
        incorporationIdentifier: '  IA-2024-001  ',
        moneyInReceiptFormat: '  ####  ',
        moneyOutReceiptFormat: '  P-#####  ',
      );

      // Assert
      final captured =
          verify(() => repository.save(captureAny())).captured.single
              as EntityDetails;
      expect(captured.name, equals('Woodgate Mens Shed'));
      expect(captured.abn, equals('12345678901'));
      expect(captured.incorporationIdentifier, equals('IA-2024-001'));
      expect(captured.moneyInReceiptFormat, equals('####'));
      expect(captured.moneyOutReceiptFormat, equals('P-#####'));
    });

    test('throws EntityDetailsValidationException when name is blank', () {
      // Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          name: '   ',
          abn: '12345678901',
          incorporationIdentifier: 'IA-2024-001',
          moneyInReceiptFormat: '',
          moneyOutReceiptFormat: '',
        ),
        throwsA(isA<EntityDetailsValidationException>()),
      );
    });

    test('throws EntityDetailsValidationException when ABN is fewer than 11 digits', () {
      // Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          name: 'Woodgate Mens Shed',
          abn: '1234567890',
          incorporationIdentifier: 'IA-2024-001',
          moneyInReceiptFormat: '',
          moneyOutReceiptFormat: '',
        ),
        throwsA(isA<EntityDetailsValidationException>()),
      );
    });

    test('throws EntityDetailsValidationException when ABN is more than 11 digits', () {
      // Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          name: 'Woodgate Mens Shed',
          abn: '123456789012',
          incorporationIdentifier: 'IA-2024-001',
          moneyInReceiptFormat: '',
          moneyOutReceiptFormat: '',
        ),
        throwsA(isA<EntityDetailsValidationException>()),
      );
    });

    test('throws EntityDetailsValidationException when ABN contains non-digits', () {
      // Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          name: 'Woodgate Mens Shed',
          abn: '1234567890A',
          incorporationIdentifier: 'IA-2024-001',
          moneyInReceiptFormat: '',
          moneyOutReceiptFormat: '',
        ),
        throwsA(isA<EntityDetailsValidationException>()),
      );
    });

    test('throws EntityDetailsValidationException when incorporation identifier is blank', () {
      // Act / Assert
      expect(
        () => sut.execute(
          entityId: tEntityId,
          name: 'Woodgate Mens Shed',
          abn: '12345678901',
          incorporationIdentifier: '   ',
          moneyInReceiptFormat: '',
          moneyOutReceiptFormat: '',
        ),
        throwsA(isA<EntityDetailsValidationException>()),
      );
    });
  });
}
