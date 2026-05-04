# Project Context

## Overview
This solution implements a **Flutter Clean Architecture API** with a **Flutter web frontend**.
The backend follows a **Contract-First** design using **OpenAPI** (for REST endpoints).

Authentication is handled through **Auth0**.

## Technology Stack
- Flutter
- PostgreSQL Database
- docker

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

