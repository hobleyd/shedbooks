import '../../domain/entities/contact.dart';

/// Deserialised request body for POST /contacts.
class CreateContactRequest {
  final String name;
  final ContactType contactType;
  final bool gstRegistered;
  final String? abn;

  const CreateContactRequest({
    required this.name,
    required this.contactType,
    required this.gstRegistered,
    this.abn,
  });

  factory CreateContactRequest.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final contactTypeRaw = json['contactType'];
    final gstRegistered = json['gstRegistered'];
    final abn = json['abn'];

    if (name is! String) throw const FormatException('name must be a string');
    if (contactTypeRaw is! String) {
      throw const FormatException('contactType must be a string');
    }
    if (gstRegistered is! bool) {
      throw const FormatException('gstRegistered must be a boolean');
    }
    if (abn != null && abn is! String) {
      throw const FormatException('abn must be a string');
    }

    final ContactType contactType;
    try {
      contactType = ContactType.values.byName(contactTypeRaw);
    } on ArgumentError {
      throw FormatException(
        'contactType must be one of: ${ContactType.values.map((e) => e.name).join(', ')}',
      );
    }

    return CreateContactRequest(
      name: name,
      contactType: contactType,
      gstRegistered: gstRegistered,
      abn: abn as String?,
    );
  }
}
