/// Request DTO for creating or updating entity details.
class SaveEntityDetailsRequest {
  final String name;
  final String abn;
  final String incorporationIdentifier;
  final String? apcaId;
  final String moneyInReceiptFormat;
  final String moneyOutReceiptFormat;

  const SaveEntityDetailsRequest({
    required this.name,
    required this.abn,
    required this.incorporationIdentifier,
    this.apcaId,
    required this.moneyInReceiptFormat,
    required this.moneyOutReceiptFormat,
  });

  factory SaveEntityDetailsRequest.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final abn = json['abn'];
    final inc = json['incorporationIdentifier'];
    final apcaId = json['apcaId'];
    final moneyIn = json['moneyInReceiptFormat'] ?? '';
    final moneyOut = json['moneyOutReceiptFormat'] ?? '';

    if (name is! String) throw const FormatException('name must be a string');
    if (abn is! String) throw const FormatException('abn must be a string');
    if (inc is! String) {
      throw const FormatException('incorporationIdentifier must be a string');
    }
    if (apcaId != null && apcaId is! String) {
      throw const FormatException('apcaId must be a string');
    }
    if (moneyIn is! String) {
      throw const FormatException('moneyInReceiptFormat must be a string');
    }
    if (moneyOut is! String) {
      throw const FormatException('moneyOutReceiptFormat must be a string');
    }

    return SaveEntityDetailsRequest(
      name: name,
      abn: abn,
      incorporationIdentifier: inc,
      apcaId: apcaId,
      moneyInReceiptFormat: moneyIn,
      moneyOutReceiptFormat: moneyOut,
    );
  }
}
