/// Tracks when a user most recently accessed the application.
class UserPresence {
  /// Auth0 organisation ID.
  final String entityId;

  /// Auth0 sub claim (unique user identifier).
  final String userId;

  /// User email from JWT; may be empty for service accounts.
  final String userEmail;

  /// Highest role held by the user at last activity.
  final String role;

  /// UTC timestamp of the user's most recent authenticated request.
  final DateTime lastSeen;

  /// Client IP address at last access.
  final String ipAddress;

  const UserPresence({
    required this.entityId,
    required this.userId,
    required this.userEmail,
    required this.role,
    required this.lastSeen,
    required this.ipAddress,
  });
}
