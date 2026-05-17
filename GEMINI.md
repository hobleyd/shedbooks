# ShedBooks Project Overview

ShedBooks is a bookkeeping system consisting of a Dart backend and a Flutter web client. It follows Clean Architecture principles on the backend and uses Auth0 for authentication.

## Architecture

### Backend (server/)
The backend follows **Clean Architecture** with four distinct layers:
- **Domain:** Entities, enums, repository interfaces, and domain exceptions.
- **Application:** Use cases — one class per operation, containing all business rules.
- **Infrastructure:** Concrete implementations of repositories (PostgreSQL), Auth0 JWT middleware, and database connection management.
- **Presentation:** Shelf HTTP handlers, DTOs, routing, and error handling.

### Frontend (client/)
A **Flutter Web** application that:
- Uses `Provider` for state management.
- Uses `GoRouter` for routing.
- Communicates with the backend via a centralized `ApiClient`.
- Handles authentication through `auth0_flutter`.

## Technology Stack

- **Language:** Dart 3.3+
- **Backend Framework:** [shelf](https://pub.dev/packages/shelf) & [shelf_router](https://pub.dev/packages/shelf_router)
- **Frontend Framework:** Flutter (Web)
- **Database:** PostgreSQL 16
- **Authentication:** Auth0 (RS256 JWT via JWKS)
- **Containerization:** Docker & Docker Compose
- **Testing:** [test](https://pub.dev/packages/test) & [mocktail](https://pub.dev/packages/mocktail)

## Getting Started

### Prerequisites
- Docker and Docker Compose
- Dart SDK 3.3+
- Flutter SDK

### Development Environment Setup
1. Copy `.env.example` to `.env` and fill in the required Auth0 and Database credentials.
2. **Backend:**
   ```bash
   cd server
   dart pub get
   # To run tests
   dart test
   # To run locally (requires DB and ENV)
   dart run bin/server.dart
   ```
3. **Frontend:**
   ```bash
   cd client
   flutter pub get
   # To run locally
   flutter run -d chrome --dart-define-from-file=.env
   ```
4. **Docker Compose:**
   ```bash
   docker compose up --build
   ```

## Development Conventions

### Backend
- **Use Cases:** Every business operation must be implemented as a use case class in the `application/` layer.
- **API First:** The API contract is defined in `server/openapi/api.yaml`. All changes to the API should start here.
- **Reusability First:** NEVER copy-paste complex logic or UI code between screens (e.g., report calculations, PDF layouts). Always refactor shared functionality into reusable components (in `lib/widgets/`), models, or utility classes to maintain a single source of truth.
- **Testing:** Every use case should have a corresponding unit test in `server/test/application/` using the Arrange-Act-Assert (AAA) pattern and `mocktail` for mocking dependencies.
- **Database Migrations:** SQL migrations are stored in `server/lib/infrastructure/database/migrations/` and are numbered sequentially.

### Frontend
- **API Client:** Use the `ApiClient` service for all backend communication to ensure consistent header and token management.
- **State Management:** Prefer `ChangeNotifier` with `Provider` for simple state, and specialized providers for services like `ApiClient`.

## Key Files
- `server/openapi/api.yaml`: Canonical API specification.
- `server/bin/server.dart`: Backend entry point.
- `client/lib/main.dart`: Frontend entry point.
- `docker-compose.yml`: System orchestration.
- `README.md`: Detailed project documentation.
