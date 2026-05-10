/// A single audit log entry recording an API action taken by a user.
class AuditEntry {
  /// Unique identifier (UUID v4).
  final String id;

  /// Auth0 organisation ID of the acting entity.
  final String entityId;

  /// Auth0 sub claim of the acting user.
  final String userId;

  /// Email of the acting user (from JWT email claim, may be empty).
  final String userEmail;

  /// Client IP address derived from X-Forwarded-For / X-Real-IP headers.
  final String ipAddress;

  /// HTTP method (GET, POST, PUT, DELETE).
  final String method;

  /// Full request path (e.g. /contacts/uuid).
  final String path;

  /// Semantic action: CREATE, UPDATE, DELETE, MERGE, BACKUP, RESTORE.
  final String action;

  /// Logical table affected (e.g. contacts, general_ledger).
  final String tableName;

  /// ID of the affected record when identifiable; null otherwise.
  final String? recordId;

  /// HTTP response status code.
  final int statusCode;

  /// Timestamp when the action occurred.
  final DateTime createdAt;

  const AuditEntry({
    required this.id,
    required this.entityId,
    required this.userId,
    required this.userEmail,
    required this.ipAddress,
    required this.method,
    required this.path,
    required this.action,
    required this.tableName,
    this.recordId,
    required this.statusCode,
    required this.createdAt,
  });
}
