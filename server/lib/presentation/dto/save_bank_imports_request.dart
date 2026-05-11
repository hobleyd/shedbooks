/// Parsed body for POST /bank-imports.
class SaveBankImportsRequest {
  final List<({String processDate, String description, int amountCents, bool isDebit})> rows;

  const SaveBankImportsRequest({required this.rows});

  factory SaveBankImportsRequest.fromJson(Map<String, dynamic> json) {
    final raw = json['rows'];
    if (raw is! List) throw const FormatException('"rows" must be an array');
    final rows = raw.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('each row must be an object');
      }
      final processDate = item['processDate'];
      final description = item['description'];
      final amountCents = item['amountCents'];
      final isDebit = item['isDebit'];
      if (processDate is! String) {
        throw const FormatException('"processDate" must be a string');
      }
      if (description is! String) {
        throw const FormatException('"description" must be a string');
      }
      if (amountCents is! int) {
        throw const FormatException('"amountCents" must be an integer');
      }
      if (isDebit is! bool) {
        throw const FormatException('"isDebit" must be a boolean');
      }
      return (
        processDate: processDate,
        description: description,
        amountCents: amountCents,
        isDebit: isDebit,
      );
    }).toList();
    return SaveBankImportsRequest(rows: rows);
  }
}
