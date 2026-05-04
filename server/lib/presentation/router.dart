import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../infrastructure/auth/auth0_middleware.dart';
import '../infrastructure/auth/jwks_client.dart';
import '../infrastructure/database/database_connection.dart';
import '../infrastructure/repositories/postgres_general_ledger_repository.dart';
import '../infrastructure/repositories/postgres_contact_repository.dart';
import '../infrastructure/repositories/postgres_gst_rate_repository.dart';
import '../infrastructure/repositories/postgres_transaction_repository.dart';
import '../application/contact/create_contact_use_case.dart';
import '../application/contact/delete_contact_use_case.dart';
import '../application/contact/get_contact_use_case.dart';
import '../application/contact/list_contacts_use_case.dart';
import '../application/contact/update_contact_use_case.dart';
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
import '../application/transaction/create_transaction_use_case.dart';
import '../application/transaction/delete_transaction_use_case.dart';
import '../application/transaction/get_transaction_use_case.dart';
import '../application/transaction/list_transactions_use_case.dart';
import '../application/transaction/update_transaction_use_case.dart';
import 'handlers/contact_handler.dart';
import 'handlers/transaction_handler.dart';
import 'handlers/general_ledger_handler.dart';
import 'handlers/gst_rate_handler.dart';
import 'middleware/cors_middleware.dart';
import 'middleware/error_handler_middleware.dart';

/// Builds and returns the application [Handler] with all routes wired up.
Handler buildRouter({
  required String auth0Domain,
  required String audience,
  required String corsOrigin,
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
  final contactHandler = ContactHandler(
    create: CreateContactUseCase(contactRepository),
    get: GetContactUseCase(contactRepository),
    list: ListContactsUseCase(contactRepository),
    update: UpdateContactUseCase(contactRepository),
    delete: DeleteContactUseCase(contactRepository),
  );

  final transactionRepository = PostgresTransactionRepository(pool);
  final transactionHandler = TransactionHandler(
    create: CreateTransactionUseCase(transactionRepository),
    get: GetTransactionUseCase(transactionRepository),
    list: ListTransactionsUseCase(transactionRepository),
    update: UpdateTransactionUseCase(transactionRepository),
    delete: DeleteTransactionUseCase(transactionRepository),
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

  final authMiddleware = auth0Middleware(
    auth0Domain: auth0Domain,
    audience: audience,
    jwksClient: jwksClient,
  );

  final router = Router()
    ..get('/health', (Request _) => Response.ok('ok'))
    ..mount(
      '/general-ledger',
      Pipeline()
          .addMiddleware(authMiddleware)
          .addHandler(_generalLedgerRouter(generalLedgerHandler)),
    )
    ..mount(
      '/gst-rates',
      Pipeline()
          .addMiddleware(authMiddleware)
          .addHandler(_gstRateRouter(gstRateHandler)),
    )
    ..mount(
      '/contacts',
      Pipeline()
          .addMiddleware(authMiddleware)
          .addHandler(_contactRouter(contactHandler)),
    )
    ..mount(
      '/transactions',
      Pipeline()
          .addMiddleware(authMiddleware)
          .addHandler(_transactionRouter(transactionHandler)),
    );

  return Pipeline()
      .addMiddleware(errorHandlerMiddleware())
      .addMiddleware(corsMiddleware(allowedOrigin: corsOrigin))
      .addMiddleware(logRequests())
      .addHandler(router.call);
}

Router _transactionRouter(TransactionHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..post('/', h.handleCreate)
    ..get('/<id>', h.handleGet)
    ..put('/<id>', h.handleUpdate)
    ..delete('/<id>', h.handleDelete);
}

Router _generalLedgerRouter(GeneralLedgerHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..post('/', h.handleCreate)
    ..get('/<id>', h.handleGet)
    ..put('/<id>', h.handleUpdate)
    ..delete('/<id>', h.handleDelete);
}

Router _contactRouter(ContactHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..post('/', h.handleCreate)
    ..get('/<id>', h.handleGet)
    ..put('/<id>', h.handleUpdate)
    ..delete('/<id>', h.handleDelete);
}

Router _gstRateRouter(GstRateHandler h) {
  return Router()
    ..get('/', h.handleList)
    ..post('/', h.handleCreate)
    // /effective must be registered before /<id> to avoid shadowing
    ..get('/effective', h.handleGetEffective)
    ..get('/<id>', h.handleGet)
    ..put('/<id>', h.handleUpdate)
    ..delete('/<id>', h.handleDelete);
}
