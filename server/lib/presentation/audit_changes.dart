/// Mutable holder for field-level change data captured during a request.
///
/// Injected into the Shelf request context by the audit middleware under the
/// key `'audit.changes'` before the inner handler is called.  Handlers may
/// call [set] to attach change details that will be persisted alongside the
/// audit entry.  If [set] is never called the entry is stored without change
/// details.
class AuditChanges {
  Map<String, dynamic>? _data;

  /// Attaches [data] to be stored in the audit log entry.
  void set(Map<String, dynamic> data) => _data = data;

  /// The attached change data, or null if [set] was never called.
  Map<String, dynamic>? get data => _data;
}
