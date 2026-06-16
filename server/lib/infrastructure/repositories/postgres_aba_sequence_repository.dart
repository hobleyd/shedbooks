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

import 'package:postgres/postgres.dart';

import '../../domain/repositories/i_aba_sequence_repository.dart';

/// PostgreSQL implementation of [IAbaSequenceRepository].
class PostgresAbaSequenceRepository implements IAbaSequenceRepository {
  final Pool _pool;

  const PostgresAbaSequenceRepository(this._pool);

  /// Atomically increments and returns the daily sequence number using
  /// INSERT … ON CONFLICT DO UPDATE, which is a single atomic statement in PostgreSQL.
  @override
  Future<int> nextSequence(String entityId) async {
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO aba_sequences (entity_id, sequence_date, sequence_number)
        VALUES (@entityId, CURRENT_DATE, 1)
        ON CONFLICT (entity_id, sequence_date)
        DO UPDATE SET sequence_number = aba_sequences.sequence_number + 1
        RETURNING sequence_number
      '''),
      parameters: {'entityId': entityId},
    );
    return result.first.toColumnMap()['sequence_number'] as int;
  }
}
