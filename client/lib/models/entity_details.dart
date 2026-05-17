/// Organisation identity details returned from the API.
class EntityDetails {
  final String name;
  final String abn;
  final String incorporationIdentifier;

  /// 6-digit User ID for ABA file generation.
  final String? apcaId;

  /// Receipt format pattern for money-in transactions.
  /// `#` = digit, `@` = letter, `*` = alphanumeric, other chars are literals.
  /// Empty string means no format is enforced.
  final String moneyInReceiptFormat;

  /// Receipt format pattern for money-out transactions.
  /// `#` = digit, `@` = letter, `*` = alphanumeric, other chars are literals.
  /// Empty string means no format is enforced.
  final String moneyOutReceiptFormat;

  const EntityDetails({
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
    this.apcaId,
    required this.moneyInReceiptFormat,
    required this.moneyOutReceiptFormat,
  });

  factory EntityDetails.fromJson(Map<String, dynamic> json) => EntityDetails(
        name: json['name'] as String,
        abn: json['abn'] as String,
        incorporationIdentifier: json['incorporationIdentifier'] as String,
        apcaId: json['apcaId'] as String?,
        moneyInReceiptFormat: (json['moneyInReceiptFormat'] as String?) ?? '',
        moneyOutReceiptFormat: (json['moneyOutReceiptFormat'] as String?) ?? '',
      );
}
