/// A transaction record returned from the API.
class TransactionEntry {
  final String id;
  final String contactId;
  final String generalLedgerId;
  final String receiptNumber;
  final String description;
  final String transactionType; // 'debit' | 'credit'
  final int amount;
  final int gstAmount;
  final int totalAmount; // in cents
  final String transactionDate; // 'YYYY-MM-DD'

  const TransactionEntry({
    required this.id,
    required this.contactId,
    required this.generalLedgerId,
    required this.receiptNumber,
    required this.description,
    required this.transactionType,
    required this.amount,
    required this.gstAmount,
    required this.totalAmount,
    required this.transactionDate,
  });

  factory TransactionEntry.fromJson(Map<String, dynamic> json) => TransactionEntry(
        id: json['id'] as String,
        contactId: json['contactId'] as String,
        generalLedgerId: json['generalLedgerId'] as String,
        receiptNumber: json['receiptNumber'] as String,
        description: (json['description'] as String?) ?? '',
        transactionType: json['transactionType'] as String,
        amount: json['amount'] as int,
        gstAmount: json['gstAmount'] as int,
        totalAmount: json['totalAmount'] as int,
        transactionDate: json['transactionDate'] as String,
      );

  bool get isCredit => transactionType == 'credit';
}
