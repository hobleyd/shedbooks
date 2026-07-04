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

import '../../domain/repositories/i_user_api_key_repository.dart';

/// Result returned by [GetApiKeyStatusUseCase].
class GetApiKeyStatusResult {
  /// Whether the user currently has an active API key.
  final bool hasKey;

  /// The username to enter in a CardDAV client (the user's email).
  final String username;

  const GetApiKeyStatusResult({required this.hasKey, required this.username});
}

/// Returns whether the authenticated user already has an API key.
///
/// Does not return the key itself — the raw value is never stored and cannot
/// be recovered after generation.
class GetApiKeyStatusUseCase {
  final IUserApiKeyRepository _repository;

  GetApiKeyStatusUseCase(this._repository);

  /// Returns [GetApiKeyStatusResult] for the given user.
  Future<GetApiKeyStatusResult> execute({
    required String entityId,
    required String userId,
    required String userEmail,
  }) async {
    final existing = await _repository.findByUser(
      entityId: entityId,
      userId: userId,
    );
    return GetApiKeyStatusResult(
      hasKey: existing != null,
      username: userEmail,
    );
  }
}
