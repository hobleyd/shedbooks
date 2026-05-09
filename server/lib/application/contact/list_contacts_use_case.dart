import '../../domain/entities/contact.dart';
import '../../domain/repositories/i_contact_repository.dart';

/// Returns all active contacts for an entity ordered by name ascending.
class ListContactsUseCase {
  final IContactRepository _repository;

  const ListContactsUseCase(this._repository);

  Future<List<Contact>> execute({required String entityId}) =>
      _repository.findAll(entityId: entityId);
}
