import '../../infrastructure/services/abn_lookup_service.dart';

export '../../infrastructure/services/abn_lookup_service.dart' show AbnLookupResult;

/// Resolves an ABN against the Australian Business Register.
class LookupAbnUseCase {
  final AbnLookupService _service;

  const LookupAbnUseCase(this._service);

  /// Looks up [abn] (must be exactly 11 digits).
  Future<AbnLookupResult> execute(String abn) {
    return _service.lookup(abn);
  }
}
