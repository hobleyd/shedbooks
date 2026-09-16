# Project Context

## Overview
This solution implements a **Flutter Clean Architecture API** with a **Flutter web frontend**.
The backend follows a **Contract-First** design using **OpenAPI** (for REST endpoints).

Authentication is handled through **Microsoft Entra ID**.

## Technology Stack
- Flutter (web frontend + Dart/Shelf backend server)
- PostgreSQL database (postgres Dart package v3.3.0 — use `Pool`, `Sql.named()`, `TxSession`, `runTx`)
- Docker Compose for local dev and production deployment
- nginx for TLS termination — proxies `/api/` → Dart server on port 8080; client uses `API_URL=/api`
- Microsoft Entra ID for authentication (JWT validation via `dart_jsonwebtoken`; client login via `msal-browser`, wrapped in `client/lib/auth/msal_web.dart`)

## Coding Standards
- **Principles**:SOLID, DRY (Don't Repeat Yourself), KISS (Keep It Simple, Stupid), YAGNI (You Aren't Gonna Need It), SoC (Separation of Concerns)
- Use explicit types rather than var for clarity
- All public methods must have XML documentation
- SQL files must include parameter documentation
- Unit tests follow Arrange-Act-Assert pattern
- Integration tests use real database in Docker container

## Unit Testing
1. Create Unit tests when new Appplication & Infrastructure methods are created.
2. Following AAA practice
3. Only proceed to next step when unit tests are passed.

## Secure Development Guide - OWASP Top 10
1. SQL injection prevention
2. A01:2021-Broken Access Control
3. A03:2021-Injection 
4. A04:2021-Insecure Design
5. A05:2021-Security Misconfiguration
6. A06:2021-Vulnerable and Outdated Components 
7. A07:2021-Identification and Authentication Failures 
8. A08:2021-Software and Data Integrity Failures 
9. A09:2021-Security Logging and Monitoring Failures 
10. A10:2021-Server-Side Request Forgery 

## Architecture Layers
- Entities, Value Objects, Domain Events, Aggregates
- Interfaces for Repositories, Services, and Unit of Work

## Multi-tenancy
- Every table has an `entity_id` column. All queries must be scoped to the authenticated entity.
- The server never trusts a raw Entra claim directly — `EntraJwtVerifier`
  (`server/lib/infrastructure/auth/multi_issuer_jwt.dart`) verifies the token,
  resolves `entity_id` from the token's `tid` claim via
  `entity_details.entra_tenant_id` (migration 059), and normalises everything
  into this app's canonical claim keys before it reaches
  `request.context['auth.claims']`: `https://shedbooks.com/entity_id`, `sub`
  (Entra's `oid`, not its per-app pairwise `sub`), `email`, and
  `https://shedbooks.com/roles`. Handlers/middleware read those canonical
  keys via `server/lib/presentation/request_identity.dart` — never Entra's
  own claim names directly.
- Entra access tokens don't always carry an `email` claim — `resolveEntraEmail`
  falls back through `preferred_username` then `upn`.
- The client (`AuthState.role` in `client/lib/auth/auth_state.dart`) reads the
  raw token straight from MSAL, so it sees Entra's *native* unnamespaced
  `roles` claim directly — no normalisation happens client-side.

## Database Migrations
- Migration files live in `server/lib/infrastructure/database/migrations/` named `NNN_description.sql`.
- Applied automatically at server startup by `DatabaseMigrator` — tracked in the `schema_migrations` table.
- Legacy databases (pre-migrator) that have 001–012 already applied via initdb.d are detected by the presence of `general_ledger` with an empty `schema_migrations`; those versions are seeded automatically so they are never re-executed.
- **SQL gotcha**: strip single-line comments (`--…`) from migration SQL *before* splitting on `;`. Comments containing semicolons (e.g. `-- null; otherwise`) will break statement splitting if you split first.

## Shelf Middleware Pipeline
- Auth middleware must run **before** audit middleware so `auth.claims` is populated for audit logging.
- Audit middleware injects an `AuditChanges` holder into the request context (`'audit.changes'`).  
  Handlers read it to attach field-level change details (diff for UPDATE, snapshot for CREATE/DELETE).
- Pipeline order in router: `authMiddleware → auditMiddleware → handler`.

## Audit Logging — Required for Every Handler That Writes to the DB
Every handler that creates, updates, or deletes data **must** call `_auditChanges(request)?.set(...)` with meaningful change details after the write succeeds. Read-only endpoints (GET) and pure-parse endpoints (no DB write) must **not** set audit changes.

**Checklist when adding or modifying a handler:**
1. Add `static AuditChanges? _auditChanges(Request r) => r.context['audit.changes'] as AuditChanges?;` to the handler class if not already present.
2. Call `_auditChanges(request)?.set({...})` immediately after every successful write, with a map describing what changed (e.g. `{'year': year, 'lineCount': n}` for budget save; diff map for updates; snapshot map for creates/deletes).
3. If the endpoint's path uses a non-UUID trailing segment (e.g. `confirm-import`, `gl-mappings`), add it to `nonIdSegments` in `audit_middleware.dart → _recordId()`.
4. If the resource is not yet in `_tableMap` in `audit_middleware.dart`, add it.
5. If the endpoint is a POST that performs no DB write (e.g. a parse/preview endpoint), exclude it in `_shouldAudit()` by path suffix.

## Flutter Widget Notes
- **Never use `DropdownButtonFormField`** — its `value` parameter is deprecated (as of Flutter 3.33) and triggers a lint error. Use `DropdownButton` directly instead, managing state with a local field and `setState`.

## Receipt Format Notation
Stored in `entity_details.money_in_receipt_format` / `money_out_receipt_format`. Parsed by `client/lib/utils/receipt_format.dart` (`ReceiptFormat` class).

| Token | Meaning |
|-------|---------|
| `YYYY` | 4-digit year (e.g. 2026) |
| `YY` | 2-digit year (e.g. 26) |
| `#` | any digit |
| `@` | any letter |
| `*` | any alphanumeric |
| `{S}` | dynamically-resolved letter (used by Asset No format's Section letter; literal elsewhere) |
| `x?` | literal character x is optional |
| other | required literal |

Example: `P-?YY###` matches `P-26062` or `P26062` (dash optional); `example()` returns `P-26000`.

Asset numbers use a separate but token-compatible format: `entity_details.asset_no_format` (default `YYYY-{S}-####`), where `{S}` resolves to the first letter (upper-cased) of the asset's selected Section. Generated server-side by `GetNextAssetNoUseCase` (mirrors `GetNextInvoiceNumberUseCase`'s stateless max-scan approach, scoped by the resolved prefix via `IAssetRepository.findAssetNosLike`).

## PostgreSQL / Dart Package Notes
- Use `Sql.named()` for parameterised queries. Cast JSONB parameters explicitly: `@param::jsonb`.
- Pass JSONB as `jsonEncode(map)` in parameters; on read, handle both `Map` (already decoded) and `String` (decode manually).
- Transactions via `_pool.runTx((tx) async { … })`.

## Backup / Restore
- Backups are entity-scoped JSON (not pg_dump). Downloaded as `.json`.
- Restore deletes entity rows in reverse FK order then re-inserts within a single transaction.

## Roles and Permissions

Three roles managed as Entra ID App Roles and enforced on both server and client:

| Role | Read | Write general | Write admin resources |
|------|------|---------------|----------------------|
| `viewer` | all | none | none |
| `contributor` | general only | yes | none |
| `administrator` | all | yes | yes |

**Admin resources** (contributor has no access, viewer can read):
- Bank accounts (`/bank-accounts/*`)
- GST rates (`/gst-rates/*`) — except `GET /gst-rates/effective`, which every
  authenticated role can read (needed to price a transaction; the rate
  *list* and CRUD stay administrator-only)
- Audit log (`/admin/audit-log`)
- Backup/restore (`/admin/backup`, `/admin/restore`)

**Server enforcement**: `server/lib/presentation/middleware/role_guard.dart` provides
`blockContributor()`, `requireContributor()`, `requireAdministrator()` Shelf middleware
applied per-route in `router.dart`.

**Client enforcement**: `AuthState.canEdit` (contributor+admin), `AuthState.isAdmin`
(admin only) gate buttons/fields in each screen. Router redirects contributors away from
restricted paths. Sidebar hides restricted admin nav items for contributors.

**Entra ID setup** — entirely code-managed by `terraform/entra_login.tf` (a dedicated
"Shedbooks Login" App Registration, deliberately separate from the app-only,
certificate-authenticated registration used for O365/Exchange sync — mixing
interactive user login with a client-credentials flow in one registration
would be hard to reason about securely):
1. App Roles `viewer`, `contributor`, `administrator` are declared directly on
   the App Registration (`app_role` blocks) — values match `AppRole` exactly,
   so no string-mapping layer is needed on either client or server.
2. Per-user role assignment is `azuread_app_role_assignment`, keyed by each
   person's Entra object id — not a dashboard click-through.
3. The client requests the app's own API scope
   (`"<clientId>/access_as_user"`, declared via `api.oauth2_permission_scope`)
   so the returned *access* token (not just an ID token) carries the caller's
   assigned role — `requested_access_token_version = 2` is what makes this a
   v2.0-shaped token (`iss` ending `/v2.0`, `preferred_username` instead of
   the v1.0-only `upn`).
4. `entity_details.entra_tenant_id` (the Entra tenant GUID, i.e. the token's
   `tid` claim) must be set per entity for login to resolve — deliberately a
   separate column/value from `o365_sync_settings.tenant_id` (that one is the
   tenant's *default domain*, required by Exchange Online's cert-based auth,
   not the GUID — same real-world tenant, different id format, different
   feature, not interchangeable).

