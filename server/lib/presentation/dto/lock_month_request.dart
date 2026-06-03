/// Parsed request body for POST /locked-months.
class LockMonthRequest {
  final String monthYear;
  final String bankAccountId;

  /// When true, the server copies the most recent prior closing balance to the
  /// last day of [monthYear]. Intended for term-deposit accounts that have no
  /// monthly statement.
  final bool carryOverBalance;

  const LockMonthRequest({
    required this.monthYear,
    required this.bankAccountId,
    this.carryOverBalance = false,
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
    return LockMonthRequest(
      monthYear: monthYear,
      bankAccountId: bankAccountId,
      carryOverBalance: json['carryOverBalance'] as bool? ?? false,
    );
  }
}
