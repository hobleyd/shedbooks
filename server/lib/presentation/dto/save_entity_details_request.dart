/// Request DTO for creating or updating entity details.
class SaveEntityDetailsRequest {
  final String name;
  final String abn;
  final String incorporationIdentifier;

  const SaveEntityDetailsRequest({
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
  });

  factory SaveEntityDetailsRequest.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final abn = json['abn'];
    final inc = json['incorporationIdentifier'];

    if (name is! String) throw const FormatException('name must be a string');
    if (abn is! String) throw const FormatException('abn must be a string');
    if (inc is! String) {
      throw const FormatException('incorporationIdentifier must be a string');
    }

    return SaveEntityDetailsRequest(
      name: name,
      abn: abn,
      incorporationIdentifier: inc,
    );
  }
}
