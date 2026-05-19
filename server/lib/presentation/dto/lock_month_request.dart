/// Parsed request body for POST /locked-months.
class LockMonthRequest {
  final String monthYear;
  final String bankAccountId;

  const LockMonthRequest({
    required this.monthYear,
    required this.bankAccountId,
  });

  factory LockMonthRequest.fromJson(Map<String, dynamic> json) {
    final monthYear = json['monthYear'];
    if (monthYear is! String || monthYear.isEmpty) {
      throw const FormatException('monthYear is required');
    }
    final bankAccountId = json['bankAccountId'];
    if (bankAccountId is! String || bankAccountId.isEmpty) {
      throw const FormatException('bankAccountId is required');
    }
    return LockMonthRequest(monthYear: monthYear, bankAccountId: bankAccountId);
  }
}
