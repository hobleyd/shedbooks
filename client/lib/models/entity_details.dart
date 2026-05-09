/// Organisation identity details returned from the API.
class EntityDetails {
  final String name;
  final String abn;
  final String incorporationIdentifier;

  const EntityDetails({
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
  });

  factory EntityDetails.fromJson(Map<String, dynamic> json) => EntityDetails(
        name: json['name'] as String,
        abn: json['abn'] as String,
        incorporationIdentifier: json['incorporationIdentifier'] as String,
      );
}
