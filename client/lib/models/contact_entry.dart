/// Contact type classification.
enum ContactType { person, company }

/// A contact entry returned from the API.
class ContactEntry {
  final String id;
  final String name;
  final ContactType contactType;
  final bool gstRegistered;

  /// ABN (11 digits). Only present for company contacts.
  final String? abn;

  /// BSB (6 digits) for ABA payments.
  final String? bsb;

  /// Account number (6-10 digits) for ABA payments.
  final String? accountNumber;

  const ContactEntry({
    required this.id,
    required this.name,
    required this.contactType,
    required this.gstRegistered,
    this.abn,
    this.bsb,
    this.accountNumber,
  });

  factory ContactEntry.fromJson(Map<String, dynamic> json) {
    return ContactEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      contactType: ContactType.values.byName(json['contactType'] as String),
      gstRegistered: json['gstRegistered'] as bool,
      abn: json['abn'] as String?,
      bsb: json['bsb'] as String?,
      accountNumber: json['accountNumber'] as String?,
    );
  }
}
