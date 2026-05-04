import '../../domain/entities/transaction.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '_transaction_validator.dart';

/// Creates a new financial transaction.
class CreateTransactionUseCase {
  final ITransactionRepository _repository;

  const CreateTransactionUseCase(this._repository);

  Future<Transaction> execute({
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    required DateTime transactionDate,
  }) async {
    TransactionValidator.validate(
      amount: amount,
      gstAmount: gstAmount,
      receiptNumber: receiptNumber,
    );

    return _repository.create(
      contactId: contactId,
      generalLedgerId: generalLedgerId,
      amount: amount,
      gstAmount: gstAmount,
      transactionType: transactionType,
      receiptNumber: receiptNumber.trim(),
      transactionDate: transactionDate,
    );
  }
}
