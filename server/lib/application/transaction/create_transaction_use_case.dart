import '../../domain/entities/transaction.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '_transaction_validator.dart';

/// Creates a new financial transaction.
class CreateTransactionUseCase {
  final ITransactionRepository _repository;

  const CreateTransactionUseCase(this._repository);

  Future<Transaction> execute({
    required String entityId,
    required String contactId,
    required String generalLedgerId,
    required int amount,
    required int gstAmount,
    required TransactionType transactionType,
    required String receiptNumber,
    required String description,
    required DateTime transactionDate,
  }) async {
    TransactionValidator.validate(
      amount: amount,
      gstAmount: gstAmount,
      receiptNumber: receiptNumber,
    );

    return _repository.create(
      entityId: entityId,
      contactId: contactId,
      generalLedgerId: generalLedgerId,
      amount: amount,
      gstAmount: gstAmount,
      transactionType: transactionType,
      receiptNumber: receiptNumber.trim(),
      description: description.trim(),
      transactionDate: transactionDate,
    );
  }
}
