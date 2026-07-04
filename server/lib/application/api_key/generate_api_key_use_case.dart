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

import 'package:uuid/uuid.dart';

import '../../domain/entities/user_api_key.dart';
import '../../domain/repositories/i_user_api_key_repository.dart';
import '../../infrastructure/encryption/sha256_hex.dart';

/// Result returned by [GenerateApiKeyUseCase].
class GenerateApiKeyResult {
  /// The raw API key — shown to the user once and never stored.
  final String apiKey;

  /// The username to enter in a CardDAV client (the user's email).
  final String username;

  const GenerateApiKeyResult({required this.apiKey, required this.username});
}

/// Generates (or regenerates) a random API key for the authenticated user.
///
/// The raw key is returned once in [GenerateApiKeyResult.apiKey] and must be
/// presented to the user immediately.  Only its SHA-256 hash is persisted.
class GenerateApiKeyUseCase {
  final IUserApiKeyRepository _repository;
  final Uuid _uuid;

  GenerateApiKeyUseCase(this._repository, {Uuid uuid = const Uuid()})
      : _uuid = uuid;

  /// Generates a new key, replacing any existing key for this user.
  Future<GenerateApiKeyResult> execute({
    required String entityId,
    required String userId,
    required String userEmail,
  }) async {
    final rawKey = _uuid.v4();
    final hash = sha256Hex(rawKey);

    await _repository.upsert(UserApiKey(
      id: _uuid.v4(),
      entityId: entityId,
      userId: userId,
      userEmail: userEmail,
      apiKeyHash: hash,
      createdAt: DateTime.now().toUtc(),
    ));

    return GenerateApiKeyResult(apiKey: rawKey, username: userEmail);
  }
}
