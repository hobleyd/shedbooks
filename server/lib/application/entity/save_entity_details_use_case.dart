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
  }) async {
    final trimmedName = name.trim();
    final trimmedAbn = abn.trim();
    final trimmedIncorporation = incorporationIdentifier.trim();

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

    return _repository.save(EntityDetails(
      entityId: entityId,
      name: trimmedName,
      abn: trimmedAbn,
      incorporationIdentifier: trimmedIncorporation,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
  }
}
