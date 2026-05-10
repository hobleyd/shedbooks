# Project Context

## Overview
This solution implements a **Flutter Clean Architecture API** with a **Flutter web frontend**.
The backend follows a **Contract-First** design using **OpenAPI** (for REST endpoints).

Authentication is handled through **Auth0**.

## Technology Stack
- Flutter (web frontend + Dart/Shelf backend server)
- PostgreSQL database (postgres Dart package v3.3.0 — use `Pool`, `Sql.named()`, `TxSession`, `runTx`)
- Docker Compose for local dev and production deployment
- nginx for TLS termination — proxies `/api/` → Dart server on port 8080; client uses `API_URL=/api`
- Auth0 for authentication (JWT validation via `dart_jsonwebtoken`)

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
- Auth0 organisation ID is delivered as a custom JWT claim: `https://shedbooks.com/entity_id`
- Auth0 user email is read from `claims['email']` or `claims['https://shedbooks.com/email']`.  
  Email is **not** in the access token by default — add it via an Auth0 Action:  
  `api.accessToken.setCustomClaim('email', event.user.email ?? '');`

## Database Migrations
- Migration files live in `server/lib/infrastructure/database/migrations/` named `NNN_description.sql`.
- Applied automatically at server startup by `DatabaseMigrator` — tracked in the `schema_migrations` table.
- Legacy versions (001–012) bootstrapped via `docker-entrypoint-initdb.d` are seeded automatically on first run.
- **SQL gotcha**: strip single-line comments (`--…`) from migration SQL *before* splitting on `;`. Comments containing semicolons (e.g. `-- null; otherwise`) will break statement splitting if you split first.

## Shelf Middleware Pipeline
- Auth middleware must run **before** audit middleware so `auth.claims` is populated for audit logging.
- Audit middleware injects an `AuditChanges` holder into the request context (`'audit.changes'`).  
  Handlers read it to attach field-level change details (diff for UPDATE, snapshot for CREATE/DELETE).
- Pipeline order in router: `authMiddleware → auditMiddleware → handler`.

## PostgreSQL / Dart Package Notes
- Use `Sql.named()` for parameterised queries. Cast JSONB parameters explicitly: `@param::jsonb`.
- Pass JSONB as `jsonEncode(map)` in parameters; on read, handle both `Map` (already decoded) and `String` (decode manually).
- Transactions via `_pool.runTx((tx) async { … })`.

## Backup / Restore
- Backups are entity-scoped JSON (not pg_dump). Downloaded as `.json`.
- Restore deletes entity rows in reverse FK order then re-inserts within a single transaction.

## Key Custom Claims (Auth0 Action)
```javascript
const ns = 'https://shedbooks.com/';
api.accessToken.setCustomClaim(ns + 'entity_id', event.organization?.id ?? '');
api.accessToken.setCustomClaim('email', event.user.email ?? '');
```

