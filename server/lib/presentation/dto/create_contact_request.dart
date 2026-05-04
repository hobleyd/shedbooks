import '../../domain/entities/contact.dart';

/// Deserialised request body for POST /contacts.
class CreateContactRequest {
  final String name;
  final ContactType contactType;
  final bool gstRegistered;

  const CreateContactRequest({
    required this.name,
    required this.contactType,
    required this.gstRegistered,
  });

  factory CreateContactRequest.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final contactTypeRaw = json['contactType'];
    final gstRegistered = json['gstRegistered'];

    if (name is! String) throw const FormatException('name must be a string');
    if (contactTypeRaw is! String) {
      throw const FormatException('contactType must be a string');
    }
    if (gstRegistered is! bool) {
      throw const FormatException('gstRegistered must be a boolean');
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
    );
  }
}
