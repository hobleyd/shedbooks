import '../../domain/entities/contact.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Merges one or more contacts into a single surviving contact.
///
/// All active transactions referencing any contact in [mergeIds] are
/// reassigned to [keepId], then those contacts are soft-deleted.
/// Returns the surviving [Contact].
class MergeContactsUseCase {
  final IContactRepository _contacts;
  final ITransactionRepository _transactions;

  const MergeContactsUseCase(this._contacts, this._transactions);

  Future<Contact> execute({
    required String keepId,
    required List<String> mergeIds,
    required String entityId,
  }) async {
    final kept = await _contacts.findById(keepId, entityId: entityId);
    if (kept == null) throw ContactNotFoundException(keepId);

    for (final id in mergeIds) {
      if (await _contacts.findById(id, entityId: entityId) == null) {
        throw ContactNotFoundException(id);
      }
    }

    await _transactions.reassignContact(mergeIds, keepId, entityId: entityId);

    for (final id in mergeIds) {
      await _contacts.delete(id, entityId: entityId);
    }

    return kept;
  }
}
