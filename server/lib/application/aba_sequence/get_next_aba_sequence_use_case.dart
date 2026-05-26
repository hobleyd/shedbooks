import '../../domain/repositories/i_aba_sequence_repository.dart';

/// Returns the next daily ABA file sequence number for an entity.
class GetNextAbaSequenceUseCase {
  final IAbaSequenceRepository _repository;

  const GetNextAbaSequenceUseCase(this._repository);

  /// Returns the next sequence number (1-based) for [entityId] on today's date.
  Future<int> execute(String entityId) => _repository.nextSequence(entityId);
}
