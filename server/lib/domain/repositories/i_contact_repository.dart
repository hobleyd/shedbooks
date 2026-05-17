import '../entities/contact.dart';

/// Contract for contact persistence.
abstract interface class IContactRepository {
  /// Creates a new contact and returns the persisted entity.
  Future<Contact> create({
    required String entityId,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
    String? abn,
    String? bsb,
    String? accountNumber,
  });

  /// Returns a contact by [id] within [entityId], or null if not found / deleted.
  Future<Contact?> findById(String id, {required String entityId});

  /// Returns all active (non-deleted) contacts for [entityId] ordered by name ascending.
  Future<List<Contact>> findAll({required String entityId});

  /// Updates an existing contact and returns the updated entity.
  /// Throws [ContactNotFoundException] if [id] does not exist within [entityId].
  Future<Contact> update({
    required String id,
    required String entityId,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
    String? abn,
    String? bsb,
    String? accountNumber,
  });

  /// Soft-deletes the contact with [id] within [entityId].
  /// Throws [ContactNotFoundException] if [id] does not exist within [entityId].
  Future<void> delete(String id, {required String entityId});
}
