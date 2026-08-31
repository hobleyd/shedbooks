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

import '../../domain/entities/entity_details.dart';
import '../../domain/exceptions/entity_details_exception.dart';
import '../../domain/repositories/i_entity_details_repository.dart';

/// Creates or updates the entity details for an entity.
class SaveEntityDetailsUseCase {
  final IEntityDetailsRepository _repository;

  const SaveEntityDetailsUseCase(this._repository);

  /// Validates input and upserts entity details.
  ///
  /// Throws [EntityDetailsValidationException] when:
  /// - [name] is blank
  /// - [abn] is not exactly 11 digits
  /// - [incorporationIdentifier] is blank
  Future<EntityDetails> execute({
    required String entityId,
    required String name,
    required String abn,
    required String incorporationIdentifier,
    String? apcaId,
    required String moneyInReceiptFormat,
    required String moneyOutReceiptFormat,
    required String invoiceNumberFormat,
    required String assetNoFormat,
  }) async {
    final trimmedName = name.trim();
    final trimmedAbn = abn.trim();
    final trimmedIncorporation = incorporationIdentifier.trim();
    final trimmedApcaId = apcaId?.trim();

    if (trimmedName.isEmpty) {
      throw const EntityDetailsValidationException('Name must not be empty');
    }
    if (!RegExp(r'^\d{11}$').hasMatch(trimmedAbn)) {
      throw const EntityDetailsValidationException(
          'ABN must be exactly 11 digits');
    }
    if (trimmedIncorporation.isEmpty) {
      throw const EntityDetailsValidationException(
          'Incorporation identifier must not be empty');
    }

    if (trimmedApcaId != null && trimmedApcaId.isNotEmpty) {
      if (!RegExp(r'^\d{6}$').hasMatch(trimmedApcaId)) {
        throw const EntityDetailsValidationException('APCA ID must be 6 digits');
      }
    }

    return _repository.save(EntityDetails(
      entityId: entityId,
      name: trimmedName,
      abn: trimmedAbn,
      incorporationIdentifier: trimmedIncorporation,
      apcaId: trimmedApcaId,
      moneyInReceiptFormat: moneyInReceiptFormat.trim(),
      moneyOutReceiptFormat: moneyOutReceiptFormat.trim(),
      invoiceNumberFormat: invoiceNumberFormat.trim(),
      assetNoFormat: assetNoFormat.trim(),
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
  }
}
