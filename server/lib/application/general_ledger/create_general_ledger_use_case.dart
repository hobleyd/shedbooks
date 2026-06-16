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

import '../../domain/entities/general_ledger.dart';
import '../../domain/exceptions/general_ledger_exception.dart';
import '../../domain/repositories/i_general_ledger_repository.dart';

/// Creates a new general ledger account.
class CreateGeneralLedgerUseCase {
  final IGeneralLedgerRepository _repository;

  const CreateGeneralLedgerUseCase(this._repository);

  Future<GeneralLedger> execute({
    required String entityId,
    required String label,
    required String description,
    required bool gstApplicable,
    required GlDirection direction,
    String? parentId,
  }) async {
    if (label.trim().isEmpty) {
      throw const GeneralLedgerValidationException('Label must not be empty');
    }
    if (description.trim().isEmpty) {
      throw const GeneralLedgerValidationException('Description must not be empty');
    }

    return _repository.create(
      entityId: entityId,
      label: label.trim(),
      description: description.trim(),
      gstApplicable: gstApplicable,
      direction: direction,
      parentId: parentId,
    );
  }
}
