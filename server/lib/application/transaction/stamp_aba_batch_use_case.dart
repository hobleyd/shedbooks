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

import '../../domain/repositories/i_transaction_repository.dart';

/// Records the ABA batch name against a set of transactions.
class StampAbaBatchUseCase {
  final ITransactionRepository _repository;

  const StampAbaBatchUseCase(this._repository);

  Future<void> execute({
    required List<String> ids,
    required String batchName,
    required String entityId,
  }) async {
    if (ids.isEmpty) return;
    await _repository.stampAbaBatch(ids, batchName, entityId: entityId);
  }
}
