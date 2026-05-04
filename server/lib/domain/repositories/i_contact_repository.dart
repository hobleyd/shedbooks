import '../entities/contact.dart';

/// Contract for contact persistence.
abstract interface class IContactRepository {
  /// Creates a new contact and returns the persisted entity.
  Future<Contact> create({
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
  });

  /// Returns a contact by [id], or null if not found / deleted.
  Future<Contact?> findById(String id);

  /// Returns all active (non-deleted) contacts ordered by name ascending.
  Future<List<Contact>> findAll();

  /// Updates an existing contact and returns the updated entity.
  /// Throws [ContactNotFoundException] if [id] does not exist.
  Future<Contact> update({
    required String id,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
  });

  /// Soft-deletes the contact with [id].
  /// Throws [ContactNotFoundException] if [id] does not exist.
  Future<void> delete(String id);
}
