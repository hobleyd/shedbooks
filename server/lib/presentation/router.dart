import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../infrastructure/auth/auth0_middleware.dart';
import '../infrastructure/auth/jwks_client.dart';
import '../infrastructure/database/database_connection.dart';
import '../infrastructure/encryption/field_encryptor.dart';
import '../infrastructure/repositories/postgres_audit_repository.dart';
import '../infrastructure/repositories/postgres_bank_import_repository.dart';
import '../infrastructure/services/abn_lookup_service.dart';
import '../infrastructure/repositories/postgres_general_ledger_repository.dart';
import '../infrastructure/repositories/postgres_contact_repository.dart';
import '../infrastructure/repositories/postgres_dashboard_preference_repository.dart';
import '../infrastructure/repositories/postgres_bank_account_repository.dart';
import '../infrastructure/repositories/postgres_entity_details_repository.dart';
import '../infrastructure/repositories/postgres_gst_rate_repository.dart';
import '../infrastructure/repositories/postgres_transaction_repository.dart';
import '../application/audit/list_audit_entries_use_case.dart';
import '../application/contact/create_contact_use_case.dart';
import '../application/contact/delete_contact_use_case.dart';
import '../application/contact/get_contact_use_case.dart';
import '../application/contact/list_contacts_use_case.dart';
import '../application/contact/lookup_abn_use_case.dart';
import '../application/contact/merge_contacts_use_case.dart';
import '../application/contact/update_contact_use_case.dart';
import '../application/dashboard/get_dashboard_preference_use_case.dart';
import '../application/dashboard/save_dashboard_preference_use_case.dart';
import '../application/bank_account/create_bank_account_use_case.dart';
import '../application/bank_account/delete_bank_account_use_case.dart';
import '../application/bank_account/get_bank_account_use_case.dart';
import '../application/bank_account/list_bank_accounts_use_case.dart';
import '../application/bank_account/update_bank_account_use_case.dart';
import '../application/entity/get_entity_details_use_case.dart';
import '../application/entity/save_entity_details_use_case.dart';
import '../application/general_ledger/create_general_ledger_use_case.dart';
import '../application/general_ledger/delete_general_ledger_use_case.dart';
import '../application/general_ledger/get_general_ledger_use_case.dart';
import '../application/general_ledger/list_general_ledgers_use_case.dart';
import '../application/general_ledger/update_general_ledger_use_case.dart';
import '../application/gst_rate/create_gst_rate_use_case.dart';
import '../application/gst_rate/delete_gst_rate_use_case.dart';
import '../application/gst_rate/get_effective_gst_rate_use_case.dart';
import '../application/gst_rate/get_gst_rate_use_case.dart';
import '../application/gst_rate/list_gst_rates_use_case.dart';
import '../application/gst_rate/update_gst_rate_use_case.dart';
import '../application/bank_import/get_bank_imports_use_case.dart';
import '../application/bank_import/save_bank_imports_use_case.dart';
import '../application/transaction/bank_match_transactions_use_case.dart';
import '../application/transaction/create_transaction_use_case.dart';
import '../application/transaction/delete_transaction_use_case.dart';
import '../application/transaction/get_transaction_use_case.dart';
import '../application/transaction/list_transactions_use_case.dart';
import '../application/transaction/update_transaction_use_case.dart';
import 'handlers/abn_lookup_handler.dart';
import 'handlers/bank_imports_handler.dart';
import 'handlers/audit_handler.dart';
import 'handlers/backup_handler.dart';
import 'handlers/contact_handler.dart';
import 'handlers/dashboard_preference_handler.dart';
import 'handlers/bank_account_handler.dart';
import 'handlers/entity_details_handler.dart';
import 'handlers/transaction_handler.dart';
import 'handlers/general_ledger_handler.dart';
import 'handlers/gst_rate_handler.dart';
import 'middleware/audit_middleware.dart';
import 'middleware/cors_middleware.dart';
import 'middleware/error_handler_middleware.dart';
import 'middleware/role_guard.dart';

/// Builds and returns the application [Handler] with all routes wired up.
Handler buildRouter({
  required String auth0Domain,
  required String audience,
  required String corsOrigin,
  required FieldEncryptor fieldEncryptor,
  String abrGuid = '',
}) {
  final jwksClient = JwksClient(auth0Domain);
  final pool = DatabaseConnection.pool;

  final generalLedgerHandler = GeneralLedgerHandler(
    create: CreateGeneralLedgerUseCase(PostgresGeneralLedgerRepository(pool)),
    get: GetGeneralLedgerUseCase(PostgresGeneralLedgerRepository(pool)),
    list: ListGeneralLedgersUseCase(PostgresGeneralLedgerRepository(pool)),
    update: UpdateGeneralLedgerUseCase(PostgresGeneralLedgerRepository(pool)),
    delete: DeleteGeneralLedgerUseCase(PostgresGeneralLedgerRepository(pool)),
  );

  final contactRepository = PostgresContactRepository(pool);
  final contactTransactionRepository = PostgresTransactionRepository(pool);
  final contactHandler = ContactHandler(
    create: CreateContactUseCase(contactRepository),
    get: GetContactUseCase(contactRepository),
    list: ListContactsUseCase(contactRepository),
    update: UpdateContactUseCase(contactRepository),
    delete: DeleteContactUseCase(contactRepository, contactTransactionRepository),
    merge: MergeContactsUseCase(contactRepository, contactTransactionRepository),
  );
  final abnLookupHandler = AbnLookupHandler(
    lookup: LookupAbnUseCase(AbnLookupService(authGuid: abrGuid)),
  );

  final transactionRepository = PostgresTransactionRepository(pool);
  final transactionHandler = TransactionHandler(
    create: CreateTransactionUseCase(transactionRepository),
    get: GetTransactionUseCase(transactionRepository),
    list: ListTransactionsUseCase(transactionRepository),
    update: UpdateTransactionUseCase(transactionRepository),
    delete: DeleteTransactionUseCase(transactionRepository),
    bankMatch: BankMatchTransactionsUseCase(transactionRepository),
  );

  final gstRateRepository = PostgresGstRateRepository(pool);
  final gstRateHandler = GstRateHandler(
    create: CreateGstRateUseCase(gstRateRepository),
    get: GetGstRateUseCase(gstRateRepository),
    list: ListGstRatesUseCase(gstRateRepository),
    update: UpdateGstRateUseCase(gstRateRepository),
    delete: DeleteGstRateUseCase(gstRateRepository),
    getEffective: GetEffectiveGstRateUseCase(gstRateRepository),
  );

  final bankAccountRepository = PostgresBankAccountRepository(pool, fieldEncryptor);
  final bankAccountHandler = BankAccountHandler(
    create: CreateBankAccountUseCase(bankAccountRepository),
    get: GetBankAccountUseCase(bankAccountRepository),
    list: ListBankAccountsUseCase(bankAccountRepository),
    update: UpdateBankAccountUseCase(bankAccountRepository),
    delete: DeleteBankAccountUseCase(bankAccountRepository),
  );

  final entityDetailsRepository = PostgresEntityDetailsRepository(pool);
  final entityDetailsHandler = EntityDetailsHandler(
    get: GetEntityDetailsUseCase(entityDetailsRepository),
    save: SaveEntityDetailsUseCase(entityDetailsRepository),
  );

  final dashboardPreferenceRepository =
      PostgresDashboardPreferenceRepository(pool);
  final dashboardPreferenceHandler = DashboardPreferenceHandler(
    get: GetDashboardPreferenceUseCase(dashboardPreferenceRepository),
    save: SaveDashboardPreferenceUseCase(dashboardPreferenceRepository),
  );

  final backupHandler = BackupHandler(pool: pool);

  final auditHandler = AuditHandler(
    list: ListAuditEntriesUseCase(PostgresAuditRepository(pool)),
  );

  final bankImportsHandler = BankImportsHandler(
    get: GetBankImportsUseCase(PostgresBankImportRepository(pool)),
    save: SaveBankImportsUseCase(PostgresBankImportRepository(pool)),
  );

  final authMiddleware = auth0Middleware(
    auth0Domain: auth0Domain,
    audience: audience,
    jwksClient: jwksClient,
  );

  // Audit middleware is placed after auth so that auth claims are available.
  final audit = auditMiddleware(pool);

  Handler _authed(Handler inner) => Pipeline()
      .addMiddleware(authMiddleware)
      .addMiddleware(audit)
      .addHandler(inner);

  final router = Router()
    ..get('/health', (Request _) => Response.ok('ok'))
    ..mount('/abn-lookup',
        _authed((req) => abnLookupHandler.handle(req)))
    ..mount('/general-ledger',
        _authed(_generalLedgerRouter(generalLedgerHandler)))
    ..mount('/gst-rates',
        _authed(_gstRateRouter(gstRateHandler)))
    ..mount('/contacts',
        _authed(_contactRouter(contactHandler)))
    ..mount('/transactions',
        _authed(_transactionRouter(transactionHandler)))
    ..mount('/dashboard-preferences',
        _authed(_dashboardPreferenceRouter(dashboardPreferenceHandler)))
    ..mount('/bank-accounts',
        _authed(_bankAccountRouter(bankAccountHandler)))
    ..mount('/entity-details',
        _authed(_entityDetailsRouter(entityDetailsHandler)))
    ..mount('/bank-imports',
        _authed(_bankImportsRouter(bankImportsHandler)))
    ..mount('/admin',
        _authed(_adminRouter(backupHandler, auditHandler)));

  return Pipeline()
      .addMiddleware(errorHandlerMiddleware())
      .addMiddleware(corsMiddleware(allowedOrigin: corsOrigin))
      .addMiddleware(logRequests())
      .addHandler(router.call);
}

/// Wraps a plain [Handler] with a role-guard [middleware].
Handler _role(Middleware middleware, Handler inner) =>
    Pipeline().addMiddleware(middleware).addHandler(inner);

/// Wraps a path-parameterised handler `(Request, String)` with a role-guard.
///
/// shelf_router passes the path segment as a second positional argument, so
/// the signature differs from a plain [Handler].  This adapter captures the
/// id in a closure and delegates to the guarded plain handler.
FutureOr<Response> Function(Request, String) _roleId(
  Middleware middleware,
  FutureOr<Response> Function(Request, String) inner,
) =>
    (Request request, String id) =>
        _role(middleware, (Request r) => inner(r, id))(request);

// ── Route sub-routers ──────────────────────────────────────────────────────

// Viewers can read; contributors and admins can write.
Router _transactionRouter(TransactionHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..post('/', _role(requireContributor(), h.handleCreate))
    // /bank-match must be registered before /<id> to avoid being shadowed
    ..post('/bank-match', _role(requireContributor(), h.handleBankMatch))
    ..get('/<id>', h.handleGet)
    ..put('/<id>', _roleId(requireContributor(), h.handleUpdate))
    ..delete('/<id>', _roleId(requireContributor(), h.handleDelete));
}

// Viewers can read; contributors and admins can write.
Router _generalLedgerRouter(GeneralLedgerHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..post('/', _role(requireContributor(), h.handleCreate))
    ..get('/<id>', h.handleGet)
    ..put('/<id>', _roleId(requireContributor(), h.handleUpdate))
    ..delete('/<id>', _roleId(requireContributor(), h.handleDelete));
}

// Viewers can read; contributors and admins can write.
Router _contactRouter(ContactHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..post('/', _role(requireContributor(), h.handleCreate))
    // /merge must be registered before /<id> to avoid being shadowed
    ..post('/merge', _role(requireContributor(), h.handleMerge))
    ..get('/<id>', h.handleGet)
    ..put('/<id>', _roleId(requireContributor(), h.handleUpdate))
    ..delete('/<id>', _roleId(requireContributor(), h.handleDelete));
}

// Contributors have no access. Viewers can read; only admins can write.
Router _bankAccountRouter(BankAccountHandler h) {
  return Router()
    ..get('/', _role(blockContributor(), h.handleList))
    ..post('/', _role(requireAdministrator(), h.handleCreate))
    ..get('/<id>', _roleId(blockContributor(), h.handleGet))
    ..put('/<id>', _roleId(requireAdministrator(), h.handleUpdate))
    ..delete('/<id>', _roleId(requireAdministrator(), h.handleDelete));
}

// Viewers can read; contributors and admins can write.
Router _entityDetailsRouter(EntityDetailsHandler h) {
  return Router()
    ..get('/', h.handleGet)
    ..put('/', _role(requireContributor(), h.handleSave));
}

// Viewers can read; contributors and admins can write.
Router _dashboardPreferenceRouter(DashboardPreferenceHandler h) {
  return Router()
    ..get('/', h.handleGet)
    ..put('/', _role(requireContributor(), h.handleSave));
}

// Contributors have no access. Viewers can read; only admins can write.
Router _gstRateRouter(GstRateHandler h) {
  return Router()
    ..get('/', _role(blockContributor(), h.handleList))
    ..post('/', _role(requireAdministrator(), h.handleCreate))
    // /effective must be registered before /<id> to avoid shadowing
    ..get('/effective', _role(blockContributor(), h.handleGetEffective))
    ..get('/<id>', _roleId(blockContributor(), h.handleGet))
    ..put('/<id>', _roleId(requireAdministrator(), h.handleUpdate))
    ..delete('/<id>', _roleId(requireAdministrator(), h.handleDelete));
}

// Viewers can read; contributors and admins can write.
Router _bankImportsRouter(BankImportsHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..post('/', _role(requireContributor(), h.handleSave));
}

// Contributors have no access to audit or backup. Only admins can restore.
Router _adminRouter(BackupHandler backup, AuditHandler audit) {
  return Router()
    ..get('/backup', _role(blockContributor(), backup.handleBackup))
    ..post('/restore', _role(requireAdministrator(), backup.handleRestore))
    ..get('/audit-log', _role(blockContributor(), audit.handleList));
}
