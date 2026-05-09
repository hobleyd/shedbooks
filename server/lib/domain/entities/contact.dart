/// Classifies whether a contact is an individual or a business entity.
enum ContactType { person, company }

/// A contact — either a person or a company — that can appear on transactions.
class Contact {
  /// Unique identifier (UUID v4).
  final String id;

  /// Display name of the contact.
  final String name;

  /// Whether this is a person or a company.
  final ContactType contactType;

  /// Whether the contact is registered for GST.
  /// Always false for [ContactType.person] — enforced in the application layer.
  final bool gstRegistered;

  /// Australian Business Number (11 digits). Required for [ContactType.company],
  /// always null for [ContactType.person].
  final String? abn;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  /// Timestamp when the record was last updated.
  final DateTime updatedAt;

  /// Soft-delete timestamp; null when the record is active.
  final DateTime? deletedAt;

  const Contact({
    required this.id,
    required this.name,
    required this.contactType,
    required this.gstRegistered,
    this.abn,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
}
