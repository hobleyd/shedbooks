/// Organisation identity details for an entity (tenant).
class EntityDetails {
  final String entityId;
  final String name;
  final String abn;
  final String incorporationIdentifier;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EntityDetails({
    required this.entityId,
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
    required this.createdAt,
    required this.updatedAt,
  });
}
