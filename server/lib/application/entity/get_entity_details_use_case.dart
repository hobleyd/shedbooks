import '../../domain/entities/entity_details.dart';
import '../../domain/exceptions/entity_details_exception.dart';
import '../../domain/repositories/i_entity_details_repository.dart';

/// Retrieves the entity details for an entity.
class GetEntityDetailsUseCase {
  final IEntityDetailsRepository _repository;

  const GetEntityDetailsUseCase(this._repository);

  /// Throws [EntityDetailsNotFoundException] if no details have been saved.
  Future<EntityDetails> execute(String entityId) async {
    final details = await _repository.find(entityId);
    if (details == null) throw EntityDetailsNotFoundException(entityId);
    return details;
  }
}
