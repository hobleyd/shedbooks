/// Parsed request body for POST /locked-months.
class LockMonthRequest {
  final String monthYear;

  const LockMonthRequest({required this.monthYear});

  factory LockMonthRequest.fromJson(Map<String, dynamic> json) {
    final monthYear = json['monthYear'];
    if (monthYear is! String || monthYear.isEmpty) {
      throw const FormatException('monthYear is required');
    }
    return LockMonthRequest(monthYear: monthYear);
  }
}
