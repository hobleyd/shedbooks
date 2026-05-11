/// Organisation identity details for an entity (tenant).
class EntityDetails {
  final String entityId;
  final String name;
  final String abn;
  final String incorporationIdentifier;

  /// Receipt number format pattern for money-in transactions.
  /// Uses `#` (digit), `@` (letter), `*` (alphanumeric); other chars are literals.
  /// Empty string means no format is enforced.
  final String moneyInReceiptFormat;

  /// Receipt number format pattern for money-out transactions.
  /// Uses `#` (digit), `@` (letter), `*` (alphanumeric); other chars are literals.
  /// Empty string means no format is enforced.
  final String moneyOutReceiptFormat;

  final DateTime createdAt;
  final DateTime updatedAt;

  const EntityDetails({
    required this.entityId,
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
    required this.moneyInReceiptFormat,
    required this.moneyOutReceiptFormat,
    required this.createdAt,
    required this.updatedAt,
  });
}
