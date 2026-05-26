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
