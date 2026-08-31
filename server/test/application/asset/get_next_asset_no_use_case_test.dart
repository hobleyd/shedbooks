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

import 'package:shedbooks_server/application/asset/get_next_asset_no_use_case.dart';
import 'package:shedbooks_server/domain/entities/entity_details.dart';
import 'package:shedbooks_server/domain/exceptions/asset_exception.dart';
import 'package:shedbooks_server/domain/repositories/i_asset_repository.dart';
import 'package:shedbooks_server/domain/repositories/i_entity_details_repository.dart';

class MockEntityDetailsRepository extends Mock
    implements IEntityDetailsRepository {}

class MockAssetRepository extends Mock implements IAssetRepository {}

void main() {
  group('GetNextAssetNoUseCase.execute', () {
    late MockEntityDetailsRepository entityRepo;
    late MockAssetRepository assetRepo;
    late GetNextAssetNoUseCase sut;

    const tEntityId = 'entity-1';
    final yyyy = DateTime.now().year.toString();

    EntityDetails _makeDetails(String format) => EntityDetails(
          entityId: tEntityId,
          name: 'Test Org',
          abn: '',
          incorporationIdentifier: '',
          moneyInReceiptFormat: '',
          moneyOutReceiptFormat: '',
          invoiceNumberFormat: 'WMS-YY-###',
          assetNoFormat: format,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );

    setUp(() {
      entityRepo = MockEntityDetailsRepository();
      assetRepo = MockAssetRepository();
      sut = GetNextAssetNoUseCase(entityRepo, assetRepo);
    });

    test('uses YYYY-{S}-#### default when entity has no format set', () async {
      // Arrange
      when(() => entityRepo.find(tEntityId))
          .thenAnswer((_) async => _makeDetails(''));
      when(() => assetRepo.findAssetNosLike(any(), entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(tEntityId, section: 'Nursery');

      // Assert
      expect(result.assetNo, equals('$yyyy-N-0001'));
      expect(result.format, equals('YYYY-{S}-####'));
    });

    test('resolves the section letter from the first character, upper-cased',
        () async {
      // Arrange
      when(() => entityRepo.find(tEntityId))
          .thenAnswer((_) async => _makeDetails('YYYY-{S}-####'));
      when(() => assetRepo.findAssetNosLike(any(), entityId: tEntityId))
          .thenAnswer((_) async => []);

      // Act
      final result = await sut.execute(tEntityId, section: 'wood shop');

      // Assert
      expect(result.assetNo, equals('$yyyy-W-0001'));
    });

    test('queries with the resolved prefix and increments the max existing number',
        () async {
      // Arrange
      when(() => entityRepo.find(tEntityId))
          .thenAnswer((_) async => _makeDetails('YYYY-{S}-####'));
      when(() => assetRepo.findAssetNosLike('$yyyy-M-%', entityId: tEntityId))
          .thenAnswer((_) async => ['$yyyy-M-001', '$yyyy-M-045']);

      // Act
      final result = await sut.execute(tEntityId, section: 'Metal Shop');

      // Assert — legacy 3-digit numbers are parsed correctly (int.tryParse
      // ignores leading zeros / width) and the next number is 4-digit padded.
      expect(result.assetNo, equals('$yyyy-M-0046'));
      verify(() => assetRepo.findAssetNosLike('$yyyy-M-%', entityId: tEntityId))
          .called(1);
    });

    test('throws AssetValidationException when section is blank', () {
      // Arrange
      when(() => entityRepo.find(tEntityId))
          .thenAnswer((_) async => _makeDetails(''));

      // Act / Assert
      expect(
        () => sut.execute(tEntityId, section: '   '),
        throwsA(isA<AssetValidationException>()),
      );
    });
  });

  group('GetNextAssetNoUseCase.generateNext', () {
    final yyyy = DateTime.now().year.toString();

    test('returns 0001 for default format with no prior numbers', () {
      // Arrange / Act
      final result =
          GetNextAssetNoUseCase.generateNext('YYYY-{S}-####', 'N', []);

      // Assert
      expect(result, equals('$yyyy-N-0001'));
    });

    test('increments the maximum existing sequential number', () {
      // Arrange / Act
      final result = GetNextAssetNoUseCase.generateNext(
        'YYYY-{S}-####',
        'W',
        ['$yyyy-W-0001', '$yyyy-W-0005', '$yyyy-W-0003'],
      );

      // Assert
      expect(result, equals('$yyyy-W-0006'));
    });

    test('mixed digit widths from legacy data are parsed by numeric value', () {
      // Arrange / Act — e.g. Metal Shop historically used 3-digit numbers.
      final result = GetNextAssetNoUseCase.generateNext(
        'YYYY-{S}-####',
        'M',
        ['$yyyy-M-001', '$yyyy-M-045'],
      );

      // Assert
      expect(result, equals('$yyyy-M-0046'));
    });

    test('ignores numbers from a different section letter', () {
      // Arrange / Act
      final result = GetNextAssetNoUseCase.generateNext(
        'YYYY-{S}-####',
        'B',
        ['$yyyy-W-0099', '$yyyy-O-0050'],
      );

      // Assert
      expect(result, equals('$yyyy-B-0001'));
    });
  });
}
