import '../../domain/entities/user_presence.dart';
import '../../domain/repositories/i_user_presence_repository.dart';

/// Returns all users who have accessed the application for [entityId],
/// ordered by most recently active first.
class ListActiveUsersUseCase {
  final IUserPresenceRepository _repository;

  const ListActiveUsersUseCase(this._repository);

  /// Executes the use case, returning presence records for [entityId].
  Future<List<UserPresence>> execute({required String entityId}) =>
      _repository.findAllByEntity(entityId);
}
