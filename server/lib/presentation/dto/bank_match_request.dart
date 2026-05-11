/// Request body for POST /transactions/bank-match.
class BankMatchRequest {
  final List<String> transactionIds;

  const BankMatchRequest({required this.transactionIds});

  factory BankMatchRequest.fromJson(Map<String, dynamic> json) {
    final ids = json['transactionIds'];
    if (ids is! List) {
      throw const FormatException('transactionIds must be an array');
    }
    return BankMatchRequest(
      transactionIds: ids.cast<String>(),
    );
  }
}
