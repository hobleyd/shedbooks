# ShedBooks

A bookkeeping backend built with Dart, served from a Docker container and backed by PostgreSQL. Authentication is handled via Auth0 (RS256 JWTs). The API follows a contract-first design — the canonical spec lives at [`server/openapi/api.yaml`](server/openapi/api.yaml).

---

## Table of Contents

- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Running Tests](#running-tests)
- [Database Migrations](#database-migrations)
- [API Reference](#api-reference)
  - [Authentication](#authentication)
  - [General Ledger](#general-ledger)
  - [GST Rates](#gst-rates)
  - [Contacts](#contacts)
  - [Transactions](#transactions)
- [Common Response Codes](#common-response-codes)

---

## Architecture

The server follows **Clean Architecture** with four layers:

```
Presentation  ←  Application  ←  Domain
                                    ↑
                             Infrastructure
```

| Layer | Responsibility |
|---|---|
| **Domain** | Entities, enums, repository interfaces, domain exceptions |
| **Application** | Use cases — one class per operation, all business rules live here |
| **Infrastructure** | PostgreSQL repositories, Auth0 JWT middleware, JWKS client |
| **Presentation** | Shelf HTTP handlers, DTOs, routing, CORS, error handling |

Dependencies only point inward. Infrastructure implements domain interfaces; application use cases depend only on those interfaces, never on concrete implementations.

---

## Technology Stack

| Component | Technology |
|---|---|
| Language | Dart ≥ 3.3 |
| HTTP server | [shelf](https://pub.dev/packages/shelf) + [shelf_router](https://pub.dev/packages/shelf_router) |
| Database | PostgreSQL 16 |
| DB driver | [postgres](https://pub.dev/packages/postgres) v3 |
| Authentication | Auth0 (RS256 JWT via JWKS) |
| Containerisation | Docker + Docker Compose |
| Testing | [test](https://pub.dev/packages/test) + [mocktail](https://pub.dev/packages/mocktail) |

---

## Project Structure

```
shedbooks/
├── docker-compose.yml
├── .env.example
└── server/
    ├── bin/
    │   └── server.dart                        # Entry point
    ├── openapi/
    │   └── api.yaml                           # OpenAPI 3.0 contract
    ├── lib/
    │   ├── domain/
    │   │   ├── entities/                      # Pure data classes
    │   │   ├── exceptions/                    # Typed domain exceptions
    │   │   └── repositories/                  # Repository interfaces
    │   ├── application/
    │   │   ├── contact/                       # Contact use cases
    │   │   ├── general_ledger/                # General ledger use cases
    │   │   ├── gst_rate/                      # GST rate use cases
    │   │   └── transaction/                   # Transaction use cases
    │   ├── infrastructure/
    │   │   ├── auth/                          # Auth0 middleware + JWKS client
    │   │   ├── database/
    │   │   │   ├── database_connection.dart   # Connection pool
    │   │   │   └── migrations/                # Numbered SQL migrations
    │   │   └── repositories/                  # PostgreSQL implementations
    │   └── presentation/
    │       ├── dto/                           # Request / response shapes
    │       ├── handlers/                      # Shelf request handlers
    │       ├── middleware/                    # CORS, error handler
    │       └── router.dart                    # Route wiring
    └── test/
        └── application/                       # Unit tests (AAA, mocktail)
```

---

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- [Dart SDK](https://dart.dev/get-dart) ≥ 3.3 (for local development / running tests)
- An Auth0 tenant with an API configured

### Running with Docker Compose

```bash
# 1. Copy and fill in environment variables
cp .env.example .env

# 2. Build and start
docker compose up --build

# Server: http://localhost:8080
# Postgres: localhost:5432
```

The database schema is applied automatically on first startup via `docker-entrypoint-initdb.d`.

### Running locally (without Docker)

```bash
cd server
dart pub get

# Export required environment variables (see below), then:
dart run bin/server.dart
```

---

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `AUTH0_DOMAIN` | Yes | — | Auth0 tenant domain, e.g. `your-tenant.au.auth0.com` |
| `AUTH0_AUDIENCE` | Yes | — | Auth0 API audience, e.g. `https://api.shedbooks.com` |
| `DB_HOST` | Yes | — | PostgreSQL host |
| `DB_PORT` | No | `5432` | PostgreSQL port |
| `DB_NAME` | Yes | — | Database name |
| `DB_USER` | Yes | — | Database user |
| `DB_PASSWORD` | Yes | — | Database password |
| `PORT` | No | `8080` | HTTP listen port |
| `CORS_ORIGIN` | No | `*` | Allowed CORS origin — restrict in production |

---

## Running Tests

```bash
cd server
dart test
```

All tests are unit tests using `mocktail` mocks. They follow the **Arrange-Act-Assert** pattern and cover every application use case. No database or network connection is required.

```
65 tests — all passing
```

---

## Database Migrations

Migrations are plain SQL files in `server/lib/infrastructure/database/migrations/`, numbered sequentially. Docker Compose mounts this directory to `docker-entrypoint-initdb.d`, so Postgres runs them in order on first boot.

| File | Description |
|---|---|
| `001_create_general_ledger.sql` | `general_ledger` table |
| `002_create_gst_rates.sql` | `gst_rates` table with unique effective-date index |
| `003_create_contacts.sql` | `contacts` table with `contact_type` ENUM |
| `004_create_transactions.sql` | `transactions` table with FK constraints and amount checks |

---

## API Reference

### Authentication

All endpoints (except `GET /health`) require a valid Auth0 Bearer token.

```
Authorization: Bearer <access_token>
```

The server fetches the JWKS from `https://{AUTH0_DOMAIN}/.well-known/jwks.json`, caches keys for one hour, and validates the `iss` and `aud` claims on every request.

---

### Health Check

```
GET /health
```

Returns `200 OK` with body `ok`. No authentication required. Use this for container health checks.

---

### General Ledger

A chart-of-accounts entry that classifies financial transactions.

#### Schema

| Field | Type | Description |
|---|---|---|
| `id` | `string (uuid)` | Auto-generated UUID v4 |
| `label` | `string` | Short display name (max 255 chars) |
| `description` | `string` | Detailed purpose of the account |
| `gstApplicable` | `boolean` | Whether GST applies to transactions on this account |
| `createdAt` | `string (date-time)` | ISO 8601 UTC timestamp |
| `updatedAt` | `string (date-time)` | ISO 8601 UTC timestamp |

#### Endpoints

##### List general ledger accounts
```
GET /general-ledger
```
Returns all active accounts ordered by `label` ascending.

**Response `200`**
```json
[
  {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "label": "Sales Revenue",
    "description": "Revenue from product and service sales",
    "gstApplicable": true,
    "createdAt": "2026-01-01T00:00:00.000Z",
    "updatedAt": "2026-01-01T00:00:00.000Z"
  }
]
```

##### Create a general ledger account
```
POST /general-ledger
```

**Request body**
```json
{
  "label": "Sales Revenue",
  "description": "Revenue from product and service sales",
  "gstApplicable": true
}
```

**Response `201`** — returns the created account.

**Validation**
- `label` and `description` must be non-empty strings.

##### Get a general ledger account
```
GET /general-ledger/{id}
```

**Response `200`** — the account object. `404` if not found.

##### Update a general ledger account
```
PUT /general-ledger/{id}
```

**Request body** — same shape as create. **Response `200`** — updated account.

##### Delete a general ledger account
```
DELETE /general-ledger/{id}
```

Soft-deletes the record. **Response `204`**. `404` if not found.

---

### GST Rates

Stores the applicable GST rate for each date range. The effective rate at any point in time is the record with the highest `effectiveFrom` that is on or before that date. Future rates can be pre-configured.

#### Schema

| Field | Type | Description |
|---|---|---|
| `id` | `string (uuid)` | Auto-generated UUID v4 |
| `rate` | `number` | Decimal fraction — `0.10` = 10% |
| `effectiveFrom` | `string (date)` | The date from which this rate applies (`YYYY-MM-DD`) |
| `createdAt` | `string (date-time)` | ISO 8601 UTC timestamp |
| `updatedAt` | `string (date-time)` | ISO 8601 UTC timestamp |

#### Endpoints

##### List GST rates
```
GET /gst-rates
```
Returns all active rates ordered by `effectiveFrom` descending.

**Response `200`**
```json
[
  {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "rate": 0.1,
    "effectiveFrom": "2000-07-01",
    "createdAt": "2026-01-01T00:00:00.000Z",
    "updatedAt": "2026-01-01T00:00:00.000Z"
  }
]
```

##### Create a GST rate
```
POST /gst-rates
```

**Request body**
```json
{
  "rate": 0.1,
  "effectiveFrom": "2026-07-01"
}
```

**Response `201`** — the created rate. `409` if a rate with the same `effectiveFrom` already exists.

**Validation**
- `rate` must be between `0` and `1` inclusive.
- `effectiveFrom` must be a valid ISO 8601 date.
- Only one active rate may exist per `effectiveFrom` date.

##### Get the effective rate at a date
```
GET /gst-rates/effective?at=<iso8601>
```

Returns the rate whose `effectiveFrom` is the highest value on or before `at`. Omitting `at` returns the currently applicable rate.

**Examples**
```
GET /gst-rates/effective
GET /gst-rates/effective?at=2026-07-01T00:00:00Z
```

**Response `200`** — the applicable rate object. `404` if no rate covers the requested date.

##### Get a GST rate by ID
```
GET /gst-rates/{id}
```

**Response `200`** — the rate object. `404` if not found.

##### Update a GST rate
```
PUT /gst-rates/{id}
```

**Request body** — same shape as create. **Response `200`** — updated rate. `409` on duplicate `effectiveFrom`.

##### Delete a GST rate
```
DELETE /gst-rates/{id}
```

Soft-deletes the record. **Response `204`**. `404` if not found.

---

### Contacts

A contact represents a person or company that appears on transactions.

#### Schema

| Field | Type | Description |
|---|---|---|
| `id` | `string (uuid)` | Auto-generated UUID v4 |
| `name` | `string` | Display name (max 500 chars) |
| `contactType` | `"person" \| "company"` | Classification |
| `gstRegistered` | `boolean` | Whether the contact holds a GST registration. Always `false` for `person`. |
| `createdAt` | `string (date-time)` | ISO 8601 UTC timestamp |
| `updatedAt` | `string (date-time)` | ISO 8601 UTC timestamp |

#### Endpoints

##### List contacts
```
GET /contacts
```
Returns all active contacts ordered by `name` ascending.

**Response `200`**
```json
[
  {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "name": "Acme Pty Ltd",
    "contactType": "company",
    "gstRegistered": true,
    "createdAt": "2026-01-01T00:00:00.000Z",
    "updatedAt": "2026-01-01T00:00:00.000Z"
  }
]
```

##### Create a contact
```
POST /contacts
```

**Request body**
```json
{
  "name": "Acme Pty Ltd",
  "contactType": "company",
  "gstRegistered": true
}
```

**Response `201`** — the created contact.

**Validation**
- `name` must be non-empty.
- `contactType` must be `"person"` or `"company"`.
- `gstRegistered` must be `false` when `contactType` is `"person"` — returns `400` otherwise.

##### Get a contact
```
GET /contacts/{id}
```

**Response `200`** — the contact object. `404` if not found.

##### Update a contact
```
PUT /contacts/{id}
```

**Request body** — same shape as create. **Response `200`** — updated contact.

##### Delete a contact
```
DELETE /contacts/{id}
```

Soft-deletes the record. **Response `204`**. `404` if not found.

---

### Transactions

A financial transaction posted against a contact and a general ledger account. All monetary values are stored as integers in **cents** to avoid floating-point rounding errors.

#### Schema

| Field | Type | Description |
|---|---|---|
| `id` | `string (uuid)` | Auto-generated UUID v4 |
| `contactId` | `string (uuid)` | FK → contacts |
| `generalLedgerId` | `string (uuid)` | FK → general_ledger |
| `amount` | `integer` | Transaction value in cents (must be > 0) |
| `gstAmount` | `integer` | GST component in cents (0 when not applicable; must be ≤ `amount`) |
| `transactionType` | `"debit" \| "credit"` | Direction of the transaction |
| `receiptNumber` | `string` | External document reference for tracking (max 100 chars) |
| `transactionDate` | `string (date)` | Date the transaction occurred (`YYYY-MM-DD`) |
| `createdAt` | `string (date-time)` | ISO 8601 UTC timestamp |
| `updatedAt` | `string (date-time)` | ISO 8601 UTC timestamp |

#### Endpoints

##### List transactions
```
GET /transactions
```
Returns all active transactions ordered by `transactionDate` descending, then `createdAt` descending.

**Response `200`**
```json
[
  {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "contactId": "a1b2c3d4-0000-0000-0000-000000000001",
    "generalLedgerId": "b2c3d4e5-0000-0000-0000-000000000002",
    "amount": 11000,
    "gstAmount": 1000,
    "transactionType": "debit",
    "receiptNumber": "REC-2026-001",
    "transactionDate": "2026-05-01",
    "createdAt": "2026-05-01T09:30:00.000Z",
    "updatedAt": "2026-05-01T09:30:00.000Z"
  }
]
```

##### Create a transaction
```
POST /transactions
```

**Request body**
```json
{
  "contactId": "a1b2c3d4-0000-0000-0000-000000000001",
  "generalLedgerId": "b2c3d4e5-0000-0000-0000-000000000002",
  "amount": 11000,
  "gstAmount": 1000,
  "transactionType": "debit",
  "receiptNumber": "REC-2026-001",
  "transactionDate": "2026-05-01"
}
```

**Response `201`** — the created transaction.

**Validation**
- `amount` must be > 0.
- `gstAmount` must be ≥ 0 and ≤ `amount`.
- `receiptNumber` must be non-empty.
- `contactId` must reference an existing contact — returns `400` if not found.
- `generalLedgerId` must reference an existing general ledger account — returns `400` if not found.
- `transactionDate` must be a valid ISO 8601 date.

##### Get a transaction
```
GET /transactions/{id}
```

**Response `200`** — the transaction object. `404` if not found.

##### Update a transaction
```
PUT /transactions/{id}
```

**Request body** — same shape as create. **Response `200`** — updated transaction. The same validation rules apply.

##### Delete a transaction
```
DELETE /transactions/{id}
```

Soft-deletes the record. **Response `204`**. `404` if not found.

---

## Common Response Codes

| Code | Meaning |
|---|---|
| `200` | Success |
| `201` | Created |
| `204` | No content (successful delete) |
| `400` | Bad request — validation failure, malformed JSON, or referential integrity violation |
| `401` | Unauthorised — missing, expired, or invalid JWT |
| `404` | Not found — resource does not exist or has been soft-deleted |
| `409` | Conflict — uniqueness constraint violation (e.g. duplicate GST rate effective date) |
| `500` | Internal server error — logged server-side |

### Error response body

All error responses return a JSON object:

```json
{
  "error": "A human-readable description of the problem"
}
```
