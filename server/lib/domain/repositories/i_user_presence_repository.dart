import '../entities/user_presence.dart';

/// Contract for user presence persistence.
abstract interface class IUserPresenceRepository {
  /// Inserts or updates the user's presence record.
  ///
  /// Updates [UserPresence.userEmail], [UserPresence.role], last_seen, and
  /// [UserPresence.ipAddress] when a row for (entity_id, user_id) already
  /// exists.  Failures are non-fatal — callers should swallow errors.
  Future<void> upsert(UserPresence presence);

  /// Returns all presence records for [entityId], ordered by last_seen
  /// descending (most recently active first).
  Future<List<UserPresence>> findAllByEntity(String entityId);
}
