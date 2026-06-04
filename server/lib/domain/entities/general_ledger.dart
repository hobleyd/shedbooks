/// Whether a general ledger account records inflows or outflows.
enum GlDirection { moneyIn, moneyOut }

/// A general ledger account used to classify financial transactions.
class GeneralLedger {
  /// Unique identifier (UUID v4).
  final String id;

  /// Short display label for the account.
  final String label;

  /// Detailed description of the account's purpose.
  final String description;

  /// Whether GST applies to transactions posted to this account.
  final bool gstApplicable;

  /// Whether this account records money coming in or going out.
  final GlDirection direction;

  /// Timestamp when the record was created.
  final DateTime createdAt;

  /// Timestamp when the record was last updated.
  final DateTime updatedAt;

  /// Soft-delete timestamp; null when the record is active.
  final DateTime? deletedAt;

  /// Parent account ID; null for top-level accounts.
  final String? parentId;

  const GeneralLedger({
    required this.id,
    required this.label,
    required this.description,
    required this.gstApplicable,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.parentId,
  });

  /// Returns true when this record has been soft-deleted.
  bool get isDeleted => deletedAt != null;

  GeneralLedger copyWith({
    String? label,
    String? description,
    bool? gstApplicable,
    GlDirection? direction,
    DateTime? updatedAt,
    DateTime? deletedAt,
    Object? parentId = _sentinel,
  }) {
    return GeneralLedger(
      id: id,
      label: label ?? this.label,
      description: description ?? this.description,
      gstApplicable: gstApplicable ?? this.gstApplicable,
      direction: direction ?? this.direction,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      parentId: parentId == _sentinel ? this.parentId : parentId as String?,
    );
  }

  static const Object _sentinel = Object();
}
