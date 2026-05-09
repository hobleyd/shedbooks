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

  const ContactEntry({
    required this.id,
    required this.name,
    required this.contactType,
    required this.gstRegistered,
    this.abn,
  });

  factory ContactEntry.fromJson(Map<String, dynamic> json) {
    return ContactEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      contactType: ContactType.values.byName(json['contactType'] as String),
      gstRegistered: json['gstRegistered'] as bool,
      abn: json['abn'] as String?,
    );
  }
}
