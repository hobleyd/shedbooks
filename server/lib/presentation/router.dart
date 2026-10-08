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
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../infrastructure/auth/carddav_auth_middleware.dart';
import '../infrastructure/auth/jwks_client.dart';
import '../infrastructure/auth/multi_issuer_auth_middleware.dart';
import '../infrastructure/auth/multi_issuer_jwt.dart';
import '../infrastructure/database/database_connection.dart';
import '../infrastructure/encryption/field_encryptor.dart';
import '../infrastructure/repositories/postgres_aba_sequence_repository.dart';
import '../infrastructure/repositories/postgres_audit_repository.dart';
import '../infrastructure/repositories/postgres_bank_import_repository.dart';
import '../infrastructure/repositories/postgres_locked_month_repository.dart';
import '../infrastructure/repositories/postgres_member_repository.dart';
import '../infrastructure/repositories/postgres_o365_sync_settings_repository.dart';
import '../infrastructure/security/temporary_password_generator.dart';
import '../infrastructure/services/abn_lookup_service.dart';
import '../infrastructure/services/exchange_online_mail_contact_sync_service.dart';
import '../infrastructure/services/exchange_online_mailbox_service.dart';
import '../infrastructure/services/graph_app_role_assignment_service.dart';
import '../infrastructure/services/openssl_certificate_generator.dart';
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
import '../application/entity/get_next_invoice_number_use_case.dart';
import '../application/invoice/create_invoice_use_case.dart';
import '../application/invoice/delete_invoice_use_case.dart';
import '../application/invoice/get_invoice_use_case.dart';
import '../application/invoice/list_invoices_use_case.dart';
import '../application/invoice/mark_invoice_paid_use_case.dart';
import '../application/invoice/update_invoice_use_case.dart';
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
import '../application/member/create_member_use_case.dart';
import '../application/member/delete_member_use_case.dart';
import '../application/member/get_member_use_case.dart';
import '../application/member/import_members_use_case.dart';
import '../application/member/list_members_use_case.dart';
import '../application/member/update_member_use_case.dart';
import '../application/o365/create_member_mailbox_use_case.dart';
import '../application/o365/generate_o365_certificate_use_case.dart';
import '../application/o365/get_o365_sync_settings_use_case.dart';
import '../application/o365/list_available_o365_licenses_use_case.dart';
import '../application/o365/member_o365_auto_sync.dart';
import '../application/o365/save_o365_sync_settings_use_case.dart';
import '../application/o365/set_member_app_role_use_case.dart';
import '../application/o365/sync_members_to_o365_use_case.dart';
import '../application/users/set_user_app_role_use_case.dart';
import '../infrastructure/repositories/postgres_budget_repository.dart';
import '../infrastructure/repositories/postgres_user_presence_repository.dart';
import '../application/closing_bank_balance/list_all_closing_bank_balances_use_case.dart';
import '../application/closing_bank_balance/list_closing_bank_balances_use_case.dart';
import '../application/closing_bank_balance/save_closing_bank_balance_use_case.dart';
import '../application/locked_month/list_locked_months_use_case.dart';
import '../application/locked_month/lock_month_use_case.dart';
import '../application/locked_month/unlock_month_use_case.dart';
import '../application/transaction/bank_match_transactions_use_case.dart';
import '../application/transaction/create_split_transaction_use_case.dart';
import '../application/transaction/create_transaction_use_case.dart';
import '../application/transaction/delete_transaction_use_case.dart';
import '../application/transaction/get_transaction_use_case.dart';
import '../application/transaction/list_transactions_use_case.dart';
import '../application/transaction/stamp_aba_batch_use_case.dart';
import '../application/transaction/update_split_transaction_use_case.dart';
import '../application/transaction/update_transaction_use_case.dart';
import '../application/capex_request/create_capex_request_use_case.dart';
import '../application/capex_request/decide_capex_request_use_case.dart';
import '../application/capex_request/delete_capex_request_use_case.dart';
import '../application/capex_request/get_capex_request_use_case.dart';
import '../application/capex_request/get_next_capex_request_no_use_case.dart';
import '../application/capex_request/list_capex_requests_use_case.dart';
import '../application/capex_request/set_capex_request_executed_date_use_case.dart';
import '../application/capex_request/update_capex_request_use_case.dart';
import '../application/asset/create_asset_use_case.dart';
import '../application/asset/delete_asset_use_case.dart';
import '../application/asset/get_asset_use_case.dart';
import '../application/asset/get_next_asset_no_use_case.dart';
import '../application/asset/import_assets_use_case.dart';
import '../application/asset/list_asset_sections_use_case.dart';
import '../application/asset/list_assets_use_case.dart';
import '../application/asset/update_asset_use_case.dart';
import '../application/member/list_member_equipment_training_use_case.dart';
import '../application/member/list_training_equipment_use_case.dart';
import '../application/member/set_member_equipment_training_use_case.dart';
import '../infrastructure/repositories/postgres_capex_request_repository.dart';
import '../infrastructure/repositories/postgres_asset_repository.dart';
import '../infrastructure/repositories/postgres_member_equipment_training_repository.dart';
import '../infrastructure/repositories/postgres_invoice_repository.dart';
import '../infrastructure/repositories/postgres_user_api_key_repository.dart';
import '../application/api_key/generate_api_key_use_case.dart';
import '../application/api_key/get_api_key_status_use_case.dart';
import 'handlers/api_key_handler.dart';
import 'handlers/aba_sequence_handler.dart';
import 'handlers/capex_request_handler.dart';
import 'handlers/asset_handler.dart';
import 'handlers/carddav_handler.dart';
import 'handlers/member_handler.dart';
import 'handlers/o365_settings_handler.dart';
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
import 'handlers/invoice_handler.dart';
import 'handlers/transaction_handler.dart';
import 'handlers/general_ledger_handler.dart';
import 'handlers/gst_rate_handler.dart';
import 'handlers/roles_handler.dart';
import 'middleware/audit_middleware.dart';
import 'middleware/cors_middleware.dart';
import 'middleware/error_handler_middleware.dart';
import 'middleware/presence_middleware.dart';
import 'middleware/role_guard.dart';
import '../application/roles/get_effective_permissions_use_case.dart';
import '../application/roles/get_role_permissions_use_case.dart';
import '../application/roles/save_role_permissions_use_case.dart';
import '../domain/enums/permission_access.dart';
import '../domain/enums/permission_action.dart';
import '../domain/enums/permission_page.dart';
import '../domain/repositories/i_role_permission_repository.dart';
import '../infrastructure/repositories/postgres_role_permission_repository.dart';

/// Builds and returns the application [Handler] with all routes wired up.
Handler buildRouter({
  required String entraTenantId,
  required String entraClientId,
  required String entraLoginServicePrincipalId,
  required String corsOrigin,
  required FieldEncryptor fieldEncryptor,
  String abrGuid = '',
}) {
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
    createSplit: CreateSplitTransactionUseCase(transactionRepository, lockedMonthRepository),
    get: GetTransactionUseCase(transactionRepository),
    list: ListTransactionsUseCase(transactionRepository),
    update: UpdateTransactionUseCase(transactionRepository, lockedMonthRepository),
    updateSplit: UpdateSplitTransactionUseCase(transactionRepository, lockedMonthRepository),
    delete: DeleteTransactionUseCase(transactionRepository, lockedMonthRepository),
    bankMatch: BankMatchTransactionsUseCase(transactionRepository, lockedMonthRepository),
    stampAbaBatch: StampAbaBatchUseCase(transactionRepository),
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

  final rolePermissionRepository =
      PostgresRolePermissionRepository(pool, entityDetailsRepository);
  final rolesHandler = RolesHandler(
    get: GetRolePermissionsUseCase(rolePermissionRepository),
    save: SaveRolePermissionsUseCase(rolePermissionRepository, entityDetailsRepository),
    getEffective: GetEffectivePermissionsUseCase(rolePermissionRepository),
  );

  final invoiceRepository = PostgresInvoiceRepository(pool);
  final invoiceHandler = InvoiceHandler(
    nextNumber: GetNextInvoiceNumberUseCase(
      entityDetailsRepository,
      invoiceRepository,
    ),
    create: CreateInvoiceUseCase(invoiceRepository),
    get: GetInvoiceUseCase(invoiceRepository),
    list: ListInvoicesUseCase(invoiceRepository),
    markPaid: MarkInvoicePaidUseCase(invoiceRepository, transactionRepository),
    delete: DeleteInvoiceUseCase(invoiceRepository),
    update: UpdateInvoiceUseCase(invoiceRepository),
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

  final bankImportsHandler = BankImportsHandler(
    get: GetBankImportsUseCase(PostgresBankImportRepository(pool)),
    save: SaveBankImportsUseCase(PostgresBankImportRepository(pool)),
  );

  final memberRepository = PostgresMemberRepository(pool, fieldEncryptor);

  final o365SettingsRepository =
      PostgresO365SyncSettingsRepository(pool, fieldEncryptor);
  final o365ContactSyncService = ExchangeOnlineMailContactSyncService();
  final o365MailboxService = ExchangeOnlineMailboxService();
  final graphAppRoleService = GraphAppRoleAssignmentService();

  final usersHandler = UsersHandler(
    list: ListActiveUsersUseCase(PostgresUserPresenceRepository(pool)),
    setAppRole: SetUserAppRoleUseCase(
      o365SettingsRepository,
      graphAppRoleService,
      entraLoginServicePrincipalId,
    ),
  );

  final o365SettingsHandler = O365SettingsHandler(
    get: GetO365SyncSettingsUseCase(o365SettingsRepository),
    save: SaveO365SyncSettingsUseCase(o365SettingsRepository),
    generateCertificate:
        GenerateO365CertificateUseCase(OpenSslCertificateGenerator()),
  );
  // Auto-sync fires after every member create/update once the entity has
  // completed its first manual "sync to O365" run — see MemberO365AutoSync.
  final memberO365AutoSync = MemberO365AutoSync(
    o365SettingsRepository,
    memberRepository,
    o365ContactSyncService,
  );

  final memberTrainingRepository =
      PostgresMemberEquipmentTrainingRepository(pool);
  final memberHandler = MemberHandler(
    create: CreateMemberUseCase(memberRepository, memberO365AutoSync),
    get: GetMemberUseCase(memberRepository),
    list: ListMembersUseCase(memberRepository),
    update: UpdateMemberUseCase(memberRepository, memberO365AutoSync),
    delete: DeleteMemberUseCase(memberRepository),
    // Bulk import intentionally does not auto-sync — hundreds of inline
    // Graph calls in one request would risk a proxy timeout. Imported rows
    // stay pending for the "sync to O365" button.
    import: ImportMembersUseCase(memberRepository),
    syncO365: SyncMembersToO365UseCase(
      o365SettingsRepository,
      memberRepository,
      o365ContactSyncService,
    ),
    availableLicenses: ListAvailableO365LicensesUseCase(
      o365SettingsRepository,
      o365MailboxService,
    ),
    createMailbox: CreateMemberMailboxUseCase(
      o365SettingsRepository,
      memberRepository,
      o365MailboxService,
      TemporaryPasswordGenerator(),
    ),
    setAppRole: SetMemberAppRoleUseCase(
      memberRepository,
      o365SettingsRepository,
      graphAppRoleService,
      entraLoginServicePrincipalId,
    ),
    trainingEquipment: ListTrainingEquipmentUseCase(memberTrainingRepository),
    listTraining: ListMemberEquipmentTrainingUseCase(memberTrainingRepository),
    setTraining: SetMemberEquipmentTrainingUseCase(
      memberRepository,
      memberTrainingRepository,
    ),
  );
  final assetRepository = PostgresAssetRepository(pool);
  final assetHandler = AssetHandler(
    create: CreateAssetUseCase(assetRepository),
    get: GetAssetUseCase(assetRepository),
    list: ListAssetsUseCase(assetRepository),
    update: UpdateAssetUseCase(assetRepository),
    delete: DeleteAssetUseCase(assetRepository),
    import: ImportAssetsUseCase(assetRepository),
    nextNumber: GetNextAssetNoUseCase(entityDetailsRepository, assetRepository),
    listSections: ListAssetSectionsUseCase(assetRepository),
  );
  final capexRequestRepository = PostgresCapexRequestRepository(pool);
  final capexRequestHandler = CapexRequestHandler(
    create: CreateCapexRequestUseCase(capexRequestRepository, invoiceRepository),
    get: GetCapexRequestUseCase(capexRequestRepository),
    list: ListCapexRequestsUseCase(capexRequestRepository),
    update: UpdateCapexRequestUseCase(capexRequestRepository, invoiceRepository),
    delete: DeleteCapexRequestUseCase(capexRequestRepository),
    decide: DecideCapexRequestUseCase(capexRequestRepository),
    nextNumber: GetNextCapexRequestNoUseCase(capexRequestRepository),
    setExecutedDate: SetCapexRequestExecutedDateUseCase(capexRequestRepository),
    permissions: rolePermissionRepository,
  );

  final cardDavPathPrefix =
      Platform.environment['CARDDAV_PATH_PREFIX'] ?? '/api';
  final cardDavHandler = CardDavHandler(
    list: ListMembersUseCase(memberRepository),
    get: GetMemberUseCase(memberRepository),
    create: CreateMemberUseCase(memberRepository, memberO365AutoSync),
    update: UpdateMemberUseCase(memberRepository, memberO365AutoSync),
    delete: DeleteMemberUseCase(memberRepository),
    pathPrefix: cardDavPathPrefix,
  );

  final apiKeyRepository = PostgresUserApiKeyRepository(pool);
  final apiKeyHandler = ApiKeyHandler(
    getStatus: GetApiKeyStatusUseCase(apiKeyRepository),
    generate: GenerateApiKeyUseCase(apiKeyRepository),
  );

  // Auth0 was accepted alongside Entra during the migration between them —
  // now that every user has cut over, Entra is the sole issuer. Kept as a
  // map (rather than a single hardcoded verifier) since that's exactly
  // what a future second issuer would need again.
  final verifiersByIssuer = <String, ClaimsVerifier>{
    'https://login.microsoftonline.com/$entraTenantId/v2.0': EntraJwtVerifier(
      tenantId: entraTenantId,
      clientId: entraClientId,
      jwksClient: JwksClient(
        Uri.https(
          'login.microsoftonline.com',
          '/$entraTenantId/discovery/v2.0/keys',
        ),
      ),
      entityDetailsRepository: entityDetailsRepository,
    ),
  };

  final authMiddleware = multiIssuerAuthMiddleware(verifiersByIssuer);

  // Audit middleware is placed after auth so that auth claims are available.
  final audit = auditMiddleware(pool);
  // Presence middleware tracks last-seen for authenticated users.
  final presence = presenceMiddleware(pool);

  Handler _authed(Handler inner) => Pipeline()
      .addMiddleware(authMiddleware)
      .addMiddleware(presence)
      .addMiddleware(audit)
      .addHandler(inner);

  final cardDavAuth = cardDavAuthMiddleware(
    verifiersByIssuer: verifiersByIssuer,
    apiKeyRepository: apiKeyRepository,
  );

  // CardDAV uses its own auth middleware (accepts Bearer OR Basic with JWT as
  // password) and does not include presence tracking — it is called by sync
  // clients, not interactive users.
  Handler _cardDavAuthed(Handler inner) => Pipeline()
      .addMiddleware(cardDavAuth)
      .addMiddleware(audit)
      .addHandler(inner);

  final router = Router()
    ..get('/health', (Request _) => Response.ok('ok'))
    // Only ever called as part of the Transactions page's "Bank Upload"
    // bulk action, alongside /transactions/aba-batch — same action guard.
    ..post(
      '/aba-sequences/next',
      _authed(_action(rolePermissionRepository,
          PermissionAction.transactionsBankUpload, abaSequenceHandler.handleNext)),
    )
    ..mount('/abn-lookup',
        _authed((req) => abnLookupHandler.handle(req)))
    ..mount('/general-ledger',
        _authed(_generalLedgerRouter(generalLedgerHandler, rolePermissionRepository)))
    ..mount('/gst-rates',
        _authed(_gstRateRouter(gstRateHandler, rolePermissionRepository)))
    ..mount('/contacts',
        _authed(_contactRouter(contactHandler, rolePermissionRepository)))
    ..mount('/transactions',
        _authed(_transactionRouter(transactionHandler, rolePermissionRepository)))
    ..mount('/dashboard-preferences',
        _authed(_dashboardPreferenceRouter(dashboardPreferenceHandler, rolePermissionRepository)))
    ..mount('/bank-accounts',
        _authed(_bankAccountRouter(bankAccountHandler, rolePermissionRepository)))
    ..mount('/entity-details',
        _authed(_entityDetailsRouter(entityDetailsHandler, rolePermissionRepository)))
    ..mount('/invoices',
        _authed(_invoiceRouter(invoiceHandler, rolePermissionRepository)))
    ..mount('/bank-imports',
        _authed(_bankImportsRouter(bankImportsHandler, rolePermissionRepository)))
    ..mount('/locked-months',
        _authed(_lockedMonthsRouter(lockedMonthHandler, rolePermissionRepository)))
    ..mount('/closing-bank-balances',
        _authed(_closingBankBalanceRouter(closingBankBalanceHandler, rolePermissionRepository)))
    ..mount('/bank-reconciliation',
        _authed(_bankReconciliationRouter(bankReconciliationHandler, rolePermissionRepository)))
    ..mount('/budgets',
        _authed(_budgetRouter(budgetHandler, rolePermissionRepository)))
    ..mount('/members',
        _authed(_memberRouter(memberHandler, rolePermissionRepository)))
    ..mount('/assets',
        _authed(_assetRouter(assetHandler, rolePermissionRepository)))
    ..mount('/capex-requests',
        _authed(_capexRequestRouter(capexRequestHandler, rolePermissionRepository)))
    ..mount('/admin',
        _authed(_adminRouter(backupHandler, auditHandler, usersHandler,
            o365SettingsHandler, rolePermissionRepository)))
    ..mount('/roles',
        _authed(_rolesRouter(rolesHandler, rolePermissionRepository)))
    ..mount('/api-key',
        _authed(_apiKeyRouter(apiKeyHandler)))
    // CardDAV addressbook — uses separate auth (Bearer OR Basic w/ JWT password or API key).
    ..add('OPTIONS', '/carddav/members', cardDavHandler.handleOptions)
    ..add('OPTIONS', '/carddav/members/', cardDavHandler.handleOptions)
    // Principal URL — macOS/iOS follows current-user-principal here to find addressbook-home-set.
    ..add('OPTIONS', '/carddav/principal', cardDavHandler.handleOptions)
    ..add('OPTIONS', '/carddav/principal/', cardDavHandler.handleOptions)
    ..add('PROPFIND', '/carddav/principal', _cardDavAuthed(cardDavHandler.handlePrincipalPropfind))
    ..add('PROPFIND', '/carddav/principal/', _cardDavAuthed(cardDavHandler.handlePrincipalPropfind))
    ..add('PROPFIND', '/carddav/members', _cardDavAuthed(cardDavHandler.handlePropfind))
    ..add('PROPFIND', '/carddav/members/', _cardDavAuthed(cardDavHandler.handlePropfind))
    ..get('/carddav/members/<uid>',
        (Request req, String uid) => _cardDavAuthed(
              (r) => cardDavHandler.handleGet(r, uid),
            )(req))
    ..put('/carddav/members/<uid>',
        (Request req, String uid) => _cardDavAuthed(
              (r) => cardDavHandler.handlePut(r, uid),
            )(req))
    ..delete('/carddav/members/<uid>',
        (Request req, String uid) => _cardDavAuthed(
              (r) => cardDavHandler.handleDelete(r, uid),
            )(req));

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

/// Wraps a plain [Handler], requiring [access] on [page] for the caller's role.
Handler _page(
  IRolePermissionRepository permissions,
  PermissionPage page,
  PermissionAccess access,
  Handler inner,
) =>
    _role(requirePagePermission(permissions, page, access), inner);

/// [_page], for a path-parameterised handler `(Request, String)`.
FutureOr<Response> Function(Request, String) _pageId(
  IRolePermissionRepository permissions,
  PermissionPage page,
  PermissionAccess access,
  FutureOr<Response> Function(Request, String) inner,
) =>
    _roleId(requirePagePermission(permissions, page, access), inner);

/// Wraps a plain [Handler], requiring the caller's role be able to perform
/// [action] (an explicit override, else its page's write permission).
Handler _action(
  IRolePermissionRepository permissions,
  PermissionAction action,
  Handler inner,
) =>
    _role(requireActionPermission(permissions, action), inner);

/// [_action], for a path-parameterised handler `(Request, String)`.
FutureOr<Response> Function(Request, String) _actionId(
  IRolePermissionRepository permissions,
  PermissionAction action,
  FutureOr<Response> Function(Request, String) inner,
) =>
    _roleId(requireActionPermission(permissions, action), inner);

// ── Route sub-routers ──────────────────────────────────────────────────────

// Viewers can read; contributors and admins can write. Importing a bank
// statement and stamping an ABA batch both back the "Bank Upload" bulk
// action, which is administrator-only regardless of the page's write access.
Router _transactionRouter(TransactionHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.transactions;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..post('/', _page(permissions, page, PermissionAccess.write, h.handleCreate))
    // Fixed paths must be registered before /<id> to avoid being shadowed.
    ..post('/bank-match', _page(permissions, page, PermissionAccess.write, h.handleBankMatch))
    ..post('/aba-batch',
        _action(permissions, PermissionAction.transactionsBankUpload, h.handleStampAbaBatch))
    ..get('/<id>', _pageId(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleUpdate))
    ..delete('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleDelete));
}

// Viewers can read; contributors and admins can write.
Router _generalLedgerRouter(GeneralLedgerHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.adminGeneralLedger;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..post('/', _page(permissions, page, PermissionAccess.write, h.handleCreate))
    ..get('/<id>', _pageId(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleUpdate))
    ..delete('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleDelete));
}

// Viewers can read; contributors and admins can write. Revealing masked bank
// details and switching payment method on an existing row are UI-only
// affordances within this same write access (see PermissionAction docs on
// contactsRevealBankDetails/contactsTogglePaymentMethod) — there's no
// separate server endpoint for either to guard independently.
Router _contactRouter(ContactHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.adminContacts;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..post('/', _page(permissions, page, PermissionAccess.write, h.handleCreate))
    // /merge must be registered before /<id> to avoid being shadowed
    ..post('/merge', _page(permissions, page, PermissionAccess.write, h.handleMerge))
    ..get('/<id>', _pageId(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleUpdate))
    ..delete('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleDelete));
}

// Administrators only.
Router _bankAccountRouter(BankAccountHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.adminBankAccounts;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..post('/', _page(permissions, page, PermissionAccess.write, h.handleCreate))
    // /order must be registered before /<id> to avoid being shadowed
    ..put('/order', _page(permissions, page, PermissionAccess.write, h.handleReorder))
    ..get('/<id>', _pageId(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleUpdate))
    ..delete('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleDelete));
}

// Viewers can read; contributors and admins can write.
Router _entityDetailsRouter(EntityDetailsHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.adminEntity;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/', _page(permissions, page, PermissionAccess.write, h.handleSave));
}

// Viewers can read; contributors and admins can write.
Router _dashboardPreferenceRouter(
    DashboardPreferenceHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.dashboard;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/', _page(permissions, page, PermissionAccess.write, h.handleSave));
}

// Administrators only, except /effective: every authenticated user needs the
// current rate to price a transaction, so it's readable by all roles while
// the rate list/CRUD stay admin-only (and outside the page permission system
// entirely, per CLAUDE.md).
Router _gstRateRouter(GstRateHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.adminGstManagement;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..post('/', _page(permissions, page, PermissionAccess.write, h.handleCreate))
    // /effective must be registered before /<id> to avoid shadowing
    ..get('/effective', h.handleGetEffective)
    ..get('/<id>', _pageId(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleUpdate))
    ..delete('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleDelete));
}

// Backs the Transactions page's bank-statement "Import" menu — not a page of
// its own (no dedicated client route), so it's action- rather than
// page-guarded.
Router _bankImportsRouter(BankImportsHandler h, IRolePermissionRepository permissions) {
  const action = PermissionAction.transactionsImport;
  return Router()
    ..get('/', _action(permissions, action, h.handleList))
    ..post('/', _action(permissions, action, h.handleSave));
}

// All roles can read; only admins can lock or unlock.
Router _lockedMonthsRouter(LockedMonthHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.adminLockedMonths;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..post('/', _page(permissions, page, PermissionAccess.write, h.handleLock))
    ..delete(
      '/<monthYear>/<bankAccountId>',
      (Request req, String monthYear, String bankAccountId) => _page(
        permissions,
        page,
        PermissionAccess.write,
        (r) => h.handleUnlock(r, monthYear, bankAccountId),
      )(req),
    );
}

// All authenticated users can read (used by Dashboard/Monthly Report); only
// writable from the Bank Reconciliation page, which owns this write action.
Router _closingBankBalanceRouter(
    ClosingBankBalanceHandler h, IRolePermissionRepository permissions) {
  return Router()
    ..get('/', h.handleList)
    ..post('/',
        _page(permissions, PermissionPage.bankReconciliation, PermissionAccess.write, h.handleSave));
}

// Administrators only; bank-accounts list accessible to all authenticated users.
Router _bankReconciliationRouter(
    BankReconciliationHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.bankReconciliation;
  return Router()
    ..get('/bank-accounts', h.handleListBankAccounts)
    ..post('/parse-statement',
        _page(permissions, page, PermissionAccess.write, h.handleParseStatement));
}

// Administrators only.
Router _adminRouter(
    BackupHandler backup,
    AuditHandler audit,
    UsersHandler users,
    O365SettingsHandler o365Settings,
    IRolePermissionRepository permissions) {
  const backupPage = PermissionPage.adminBackup;
  const auditPage = PermissionPage.adminAuditLog;
  const usersPage = PermissionPage.adminUsers;
  const o365Page = PermissionPage.adminO365Sync;
  return Router()
    ..get('/backup', _page(permissions, backupPage, PermissionAccess.read, backup.handleBackup))
    ..post('/restore', _page(permissions, backupPage, PermissionAccess.write, backup.handleRestore))
    ..get('/audit-log', _page(permissions, auditPage, PermissionAccess.read, audit.handleList))
    ..get('/users', _page(permissions, usersPage, PermissionAccess.read, users.handleList))
    ..put(
      '/users/<userId>/role',
      (Request req, String userId) => _page(
        permissions,
        usersPage,
        PermissionAccess.write,
        (r) => users.handleSetRole(r, userId),
      )(req),
    )
    ..get('/o365-settings',
        _page(permissions, o365Page, PermissionAccess.read, o365Settings.handleGet))
    ..put('/o365-settings',
        _page(permissions, o365Page, PermissionAccess.write, o365Settings.handleSave))
    ..post('/o365-settings/generate-certificate',
        _page(permissions, o365Page, PermissionAccess.write,
            o365Settings.handleGenerateCertificate));
}

// Viewers/contributors can read budgets; only admins can write or import.
// Fixed paths (gl-mappings, parse-import) are registered before <year> to avoid shadowing.
Router _budgetRouter(BudgetHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.reportsBudget;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..get('/gl-mappings', _page(permissions, page, PermissionAccess.read, h.handleGetMappings))
    ..put('/gl-mappings',
        _page(permissions, page, PermissionAccess.write, h.handleSaveMappings))
    ..post('/parse-import',
        _page(permissions, page, PermissionAccess.write, h.handleParseImport))
    ..get('/<year>', _pageId(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/<year>', _pageId(permissions, page, PermissionAccess.write, h.handleSave))
    ..delete('/<year>', _pageId(permissions, page, PermissionAccess.write, h.handleDelete))
    ..post(
      '/<year>/confirm-import',
      (Request req, String year) => _page(
        permissions,
        page,
        PermissionAccess.write,
        (r) => h.handleConfirmImport(r, year),
      )(req),
    );
}

// Viewers can read; contributors and admins can write.
// O365 sync settings are admin-owned, so triggering a sync run — and
// creating a tenant mailbox account — is administrator-only. Fixed paths
// (import, sync-o365, available-licenses) must be registered before /<id>
// to avoid being shadowed.
Router _memberRouter(MemberHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.members;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..post('/', _page(permissions, page, PermissionAccess.write, h.handleCreate))
    ..post('/import', _page(permissions, page, PermissionAccess.write, h.handleImport))
    ..post('/sync-o365',
        _action(permissions, PermissionAction.membersSyncO365, h.handleSyncO365))
    ..get('/available-licenses',
        _action(permissions, PermissionAction.membersCreateMailbox, h.handleAvailableLicenses))
    ..get('/training-equipment',
        _page(permissions, page, PermissionAccess.read, h.handleTrainingEquipment))
    ..get('/<id>', _pageId(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleUpdate))
    ..delete('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleDelete))
    ..put('/<id>/equipment-training',
        _pageId(permissions, page, PermissionAccess.write, h.handleSetEquipmentTraining))
    ..post(
      '/<id>/create-mailbox',
      (Request req, String id) => _action(
        permissions,
        PermissionAction.membersCreateMailbox,
        (r) => h.handleCreateMailbox(r, id),
      )(req),
    )
    ..put(
      '/<id>/app-role',
      (Request req, String id) => _action(
        permissions,
        PermissionAction.membersSetRole,
        (r) => h.handleSetAppRole(r, id),
      )(req),
    );
}

// Viewers can read; contributors and admins can write.
// Fixed paths (import, next-number, sections) must be registered before
// /<id> to avoid being shadowed.
Router _assetRouter(AssetHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.assets;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..post('/', _page(permissions, page, PermissionAccess.write, h.handleCreate))
    ..post('/import', _page(permissions, page, PermissionAccess.write, h.handleImport))
    ..get('/next-number', _page(permissions, page, PermissionAccess.read, h.handleNextNumber))
    ..get('/sections', _page(permissions, page, PermissionAccess.read, h.handleListSections))
    ..get('/<id>', _pageId(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleUpdate))
    ..delete('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleDelete));
}

// Viewers can read; contributors and admins can create/edit/delete;
// only administrators can approve/reject (record the decision) or edit a
// request once decided (capex-edit-decided, checked inside handleUpdate
// because it depends on the request's current status).
// Fixed paths (next-number) must be registered before /<id> to avoid shadowing.
Router _capexRequestRouter(CapexRequestHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.capexRequests;
  return Router()
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..post('/', _page(permissions, page, PermissionAccess.write, h.handleCreate))
    ..get('/next-number', _page(permissions, page, PermissionAccess.read, h.handleNextNumber))
    ..get('/<id>', _pageId(permissions, page, PermissionAccess.read, h.handleGet))
    ..put('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleUpdate))
    ..delete('/<id>', _pageId(permissions, page, PermissionAccess.write, h.handleDelete))
    ..put('/<id>/executed-date',
        _pageId(permissions, page, PermissionAccess.write, h.handleSetExecutedDate))
    ..post(
      '/<id>/decision',
      (Request req, String id) => _action(
        permissions,
        PermissionAction.capexApproveReject,
        (r) => h.handleDecide(r, id),
      )(req),
    );
}

// Contributors and administrators only — a personal CardDAV-sync credential,
// not a page in the Roles registry (see requireContributor() doc comment).
Router _apiKeyRouter(ApiKeyHandler h) {
  return Router()
    ..get('/', _role(requireContributor(), h.handleGetStatus))
    ..post('/generate', _role(requireContributor(), h.handleGenerate));
}

// Read-only bootstrap for the caller's own permissions; the matrix itself is
// administrator-only, guarded by the Roles page's own permission cell.
Router _rolesRouter(RolesHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.adminRoles;
  return Router()
    ..get('/effective', h.handleGetEffective)
    ..get('/permissions', _page(permissions, page, PermissionAccess.read, h.handleGetPermissions))
    ..put('/permissions',
        _page(permissions, page, PermissionAccess.write, h.handleSavePermissions));
}

// Viewers can read; contributors and admins can create; admins only can
// edit/delete (invoicesManageUnpaid — stricter than the page's write access).
// Fixed paths (next-number) must be registered before /<id> to avoid shadowing.
Router _invoiceRouter(InvoiceHandler h, IRolePermissionRepository permissions) {
  const page = PermissionPage.invoices;
  return Router()
    ..get('/next-number', _page(permissions, page, PermissionAccess.read, h.handleNextNumber))
    ..get('/', _page(permissions, page, PermissionAccess.read, h.handleList))
    ..post('/', _page(permissions, page, PermissionAccess.write, h.handleCreate))
    ..post(
      '/<id>/mark-paid',
      (Request req, String id) => _page(
        permissions,
        page,
        PermissionAccess.write,
        (r) => h.handleMarkPaid(r, id),
      )(req),
    )
    ..get('/<id>', _pageId(permissions, page, PermissionAccess.read,
        (Request req, String id) => h.handleGet(req, id)))
    ..put('/<id>', _actionId(permissions, PermissionAction.invoicesManageUnpaid, h.handleUpdate))
    ..delete(
        '/<id>', _actionId(permissions, PermissionAction.invoicesManageUnpaid, h.handleDelete));
}
