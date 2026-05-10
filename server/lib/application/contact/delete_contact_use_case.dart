import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Soft-deletes a contact.
///
/// Throws [ContactInUseException] if any active transaction references the contact.
class DeleteContactUseCase {
  final IContactRepository _repository;
  final ITransactionRepository _transactions;

  const DeleteContactUseCase(this._repository, this._transactions);

  Future<void> execute(String id, {required String entityId}) async {
    final existing = await _repository.findById(id, entityId: entityId);
    if (existing == null) throw ContactNotFoundException(id);
    if (await _transactions.hasTransactions(id, entityId: entityId)) {
      throw ContactInUseException(id);
    }
    await _repository.delete(id, entityId: entityId);
  }
}
