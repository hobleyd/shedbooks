import '../entities/entity_details.dart';

/// Repository interface for entity details persistence.
abstract class IEntityDetailsRepository {
  /// Returns the entity details for [entityId], or null if not yet created.
  Future<EntityDetails?> find(String entityId);

  /// Upserts the entity details and returns the persisted record.
  Future<EntityDetails> save(EntityDetails details);
}
