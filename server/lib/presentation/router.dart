// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../infrastructure/auth/auth0_middleware.dart';
import '../infrastructure/auth/jwks_client.dart';
import '../infrastructure/database/database_connection.dart';
import '../infrastructure/encryption/field_encryptor.dart';
import '../infrastructure/repositories/postgres_aba_sequence_repository.dart';
import '../infrastructure/repositories/postgres_audit_repository.dart';
import '../infrastructure/repositories/postgres_bank_import_repository.dart';
import '../infrastructure/repositories/postgres_locked_month_repository.dart';
import '../infrastructure/services/abn_lookup_service.dart';
import '../infrastructure/repositories/postgres_general_ledger_repository.dart';
import '../infrastructure/repositories/postgres_contact_repository.dart';
import '../infrastructure/repositories/postgres_dashboard_preference_repository.dart';
import '../infrastructure/repositories/postgres_bank_account_repository.dart';
import '../infrastructure/repositories/postgres_closing_bank_balance_repository.dart';
import '../infrastructure/repositories/postgres_entity_details_repository.dart';
import '../infrastructure/repositories/postgres_gst_rate_repository.dart';
import '../infrastructure/repositories/postgres_transaction_repository.dart';
import '../application/aba_sequence/get_next_aba_sequence_use_case.dart';
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
import '../application/bank_account/reorder_bank_accounts_use_case.dart';
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
import '../application/budget/confirm_budget_import_use_case.dart';
import '../application/budget/delete_budget_use_case.dart';
import '../application/budget/get_budget_gl_mappings_use_case.dart';
import '../application/budget/get_budget_use_case.dart';
import '../application/budget/list_budget_years_use_case.dart';
import '../application/budget/parse_budget_import_use_case.dart';
import '../application/budget/save_budget_gl_mappings_use_case.dart';
import '../application/budget/save_budget_use_case.dart';
import '../application/users/list_active_users_use_case.dart';
import '../infrastructure/repositories/postgres_budget_repository.dart';
import '../infrastructure/repositories/postgres_user_presence_repository.dart';
import '../application/closing_bank_balance/list_all_closing_bank_balances_use_case.dart';
import '../application/closing_bank_balance/list_closing_bank_balances_use_case.dart';
import '../application/closing_bank_balance/save_closing_bank_balance_use_case.dart';
import '../application/locked_month/list_locked_months_use_case.dart';
import '../application/locked_month/lock_month_use_case.dart';
import '../application/locked_month/unlock_month_use_case.dart';
import '../application/transaction/bank_match_transactions_use_case.dart';
import '../application/transaction/create_transaction_use_case.dart';
import '../application/transaction/delete_transaction_use_case.dart';
import '../application/transaction/get_transaction_use_case.dart';
import '../application/transaction/list_transactions_use_case.dart';
import '../application/transaction/update_transaction_use_case.dart';
import 'handlers/aba_sequence_handler.dart';
import 'handlers/abn_lookup_handler.dart';
import 'handlers/bank_reconciliation_handler.dart';
import 'handlers/bank_imports_handler.dart';
import 'handlers/budget_handler.dart';
import 'handlers/closing_bank_balance_handler.dart';
import 'handlers/locked_month_handler.dart';
import 'handlers/audit_handler.dart';
import 'handlers/backup_handler.dart';
import 'handlers/users_handler.dart';
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
import 'middleware/presence_middleware.dart';
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

  final generalLedgerRepository = PostgresGeneralLedgerRepository(pool);
  final generalLedgerHandler = GeneralLedgerHandler(
    create: CreateGeneralLedgerUseCase(generalLedgerRepository),
    get: GetGeneralLedgerUseCase(generalLedgerRepository),
    list: ListGeneralLedgersUseCase(generalLedgerRepository),
    update: UpdateGeneralLedgerUseCase(generalLedgerRepository),
    delete: DeleteGeneralLedgerUseCase(generalLedgerRepository),
  );

  final contactRepository = PostgresContactRepository(pool, fieldEncryptor);
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

  final lockedMonthRepository = PostgresLockedMonthRepository(pool);
  final lockedMonthClosingBalanceRepository =
      PostgresClosingBankBalanceRepository(pool);
  final lockedMonthHandler = LockedMonthHandler(
    list: ListLockedMonthsUseCase(lockedMonthRepository),
    lock: LockMonthUseCase(lockedMonthRepository),
    unlock: UnlockMonthUseCase(lockedMonthRepository),
    listBalances:
        ListClosingBankBalancesUseCase(lockedMonthClosingBalanceRepository),
    saveBalance:
        SaveClosingBankBalanceUseCase(lockedMonthClosingBalanceRepository),
  );

  final transactionRepository = PostgresTransactionRepository(pool);
  final transactionHandler = TransactionHandler(
    create: CreateTransactionUseCase(transactionRepository, lockedMonthRepository),
    get: GetTransactionUseCase(transactionRepository),
    list: ListTransactionsUseCase(transactionRepository),
    update: UpdateTransactionUseCase(transactionRepository, lockedMonthRepository),
    delete: DeleteTransactionUseCase(transactionRepository, lockedMonthRepository),
    bankMatch: BankMatchTransactionsUseCase(transactionRepository),
    getContact: GetContactUseCase(contactRepository),
    getGeneralLedger: GetGeneralLedgerUseCase(generalLedgerRepository),
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
    reorder: ReorderBankAccountsUseCase(bankAccountRepository),
  );

  final entityDetailsRepository = PostgresEntityDetailsRepository(pool, fieldEncryptor);
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

  final closingBankBalanceRepository =
      PostgresClosingBankBalanceRepository(pool);
  final closingBankBalanceHandler = ClosingBankBalanceHandler(
    save: SaveClosingBankBalanceUseCase(closingBankBalanceRepository),
    list: ListClosingBankBalancesUseCase(closingBankBalanceRepository),
    listAll: ListAllClosingBankBalancesUseCase(closingBankBalanceRepository),
  );

  final bankReconciliationHandler = BankReconciliationHandler(
    listBankAccounts: ListBankAccountsUseCase(bankAccountRepository),
  );

  final abaSequenceHandler = AbaSequenceHandler(
    nextSequence:
        GetNextAbaSequenceUseCase(PostgresAbaSequenceRepository(pool)),
  );

  final budgetRepository = PostgresBudgetRepository(pool);
  final budgetHandler = BudgetHandler(
    listYears: ListBudgetYearsUseCase(budgetRepository),
    get: GetBudgetUseCase(budgetRepository),
    save: SaveBudgetUseCase(budgetRepository),
    delete: DeleteBudgetUseCase(budgetRepository),
    parseImport: ParseBudgetImportUseCase(budgetRepository, generalLedgerRepository),
    confirmImport: ConfirmBudgetImportUseCase(budgetRepository),
    getMappings: GetBudgetGlMappingsUseCase(budgetRepository),
    saveMappings: SaveBudgetGlMappingsUseCase(budgetRepository),
  );

  final backupHandler = BackupHandler(pool: pool);

  final auditHandler = AuditHandler(
    list: ListAuditEntriesUseCase(PostgresAuditRepository(pool)),
  );

  final usersHandler = UsersHandler(
    list: ListActiveUsersUseCase(PostgresUserPresenceRepository(pool)),
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
  // Presence middleware tracks last-seen for authenticated users.
  final presence = presenceMiddleware(pool);

  Handler _authed(Handler inner) => Pipeline()
      .addMiddleware(authMiddleware)
      .addMiddleware(presence)
      .addMiddleware(audit)
      .addHandler(inner);

  final router = Router()
    ..get('/health', (Request _) => Response.ok('ok'))
    ..post('/aba-sequences/next',
        _authed(_role(requireAdministrator(), abaSequenceHandler.handleNext)))
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
    ..mount('/locked-months',
        _authed(_lockedMonthsRouter(lockedMonthHandler)))
    ..mount('/closing-bank-balances',
        _authed(_closingBankBalanceRouter(closingBankBalanceHandler)))
    ..mount('/bank-reconciliation',
        _authed(_bankReconciliationRouter(bankReconciliationHandler)))
    ..mount('/budgets',
        _authed(_budgetRouter(budgetHandler)))
    ..mount('/admin',
        _authed(_adminRouter(backupHandler, auditHandler, usersHandler)));

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

// Administrators only.
Router _bankAccountRouter(BankAccountHandler h) {
  return Router()
    ..get('/', _role(requireAdministrator(), h.handleList))
    ..post('/', _role(requireAdministrator(), h.handleCreate))
    // /order must be registered before /<id> to avoid being shadowed
    ..put('/order', _role(requireAdministrator(), h.handleReorder))
    ..get('/<id>', _roleId(requireAdministrator(), h.handleGet))
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

// Administrators only.
Router _gstRateRouter(GstRateHandler h) {
  return Router()
    ..get('/', _role(requireAdministrator(), h.handleList))
    ..post('/', _role(requireAdministrator(), h.handleCreate))
    // /effective must be registered before /<id> to avoid shadowing
    ..get('/effective', _role(requireAdministrator(), h.handleGetEffective))
    ..get('/<id>', _roleId(requireAdministrator(), h.handleGet))
    ..put('/<id>', _roleId(requireAdministrator(), h.handleUpdate))
    ..delete('/<id>', _roleId(requireAdministrator(), h.handleDelete));
}

// Administrators only.
Router _bankImportsRouter(BankImportsHandler h) {
  return Router()
    ..get('/', _role(requireAdministrator(), h.handleList))
    ..post('/', _role(requireAdministrator(), h.handleSave));
}

// All roles can read; only admins can lock or unlock.
Router _lockedMonthsRouter(LockedMonthHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..post('/', _role(requireAdministrator(), h.handleLock))
    ..delete(
      '/<monthYear>/<bankAccountId>',
      (Request req, String monthYear, String bankAccountId) => _role(
        requireAdministrator(),
        (r) => h.handleUnlock(r, monthYear, bankAccountId),
      )(req),
    );
}

// All authenticated users can read; contributors and admins can write.
Router _closingBankBalanceRouter(ClosingBankBalanceHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..post('/', _role(requireContributor(), h.handleSave));
}

// Contributors can post; bank-accounts list accessible to all authenticated users.
Router _bankReconciliationRouter(BankReconciliationHandler h) {
  return Router()
    ..get('/bank-accounts', h.handleListBankAccounts)
    ..post('/parse-statement', _role(requireContributor(), h.handleParseStatement));
}

// Administrators only.
Router _adminRouter(BackupHandler backup, AuditHandler audit, UsersHandler users) {
  return Router()
    ..get('/backup', _role(requireAdministrator(), backup.handleBackup))
    ..post('/restore', _role(requireAdministrator(), backup.handleRestore))
    ..get('/audit-log', _role(requireAdministrator(), audit.handleList))
    ..get('/users', _role(requireAdministrator(), users.handleList));
}

// All roles can read budgets; only admins can write or import.
// Fixed paths (gl-mappings, parse-import) are registered before <year> to avoid shadowing.
Router _budgetRouter(BudgetHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..get('/gl-mappings', h.handleGetMappings)
    ..put('/gl-mappings', _role(requireAdministrator(), h.handleSaveMappings))
    ..post('/parse-import', _role(requireAdministrator(), h.handleParseImport))
    ..get('/<year>', h.handleGet)
    ..put('/<year>', _roleId(requireAdministrator(), h.handleSave))
    ..delete('/<year>', _roleId(requireAdministrator(), h.handleDelete))
    ..post(
      '/<year>/confirm-import',
      (Request req, String year) => _role(
        requireAdministrator(),
        (r) => h.handleConfirmImport(r, year),
      )(req),
    );
}
