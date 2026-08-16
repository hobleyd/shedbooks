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

import '../../domain/exceptions/o365_sync_exception.dart';
import '../../domain/services/i_certificate_generator.dart';

/// Generates a self-signed certificate for O365 Exchange Online app-only
/// auth. Deliberately does not persist anything — the caller (the settings
/// UI) still submits the returned certificate through the normal
/// `PUT /admin/o365-settings` save flow, same as if the admin had uploaded
/// their own .pfx file. This keeps "generate" a pure, side-effect-free
/// operation and reuses all of `SaveO365SyncSettingsUseCase`'s existing
/// validation/persistence logic unchanged.
class GenerateO365CertificateUseCase {
  final ICertificateGenerator _generator;

  const GenerateO365CertificateUseCase(this._generator);

  /// Throws [O365SyncValidationException] when [password] is blank, or
  /// [O365CertificateGenerationException] if generation fails.
  Future<GeneratedCertificate> execute({required String password}) {
    if (password.trim().isEmpty) {
      throw const O365SyncValidationException(
          'Certificate password must not be empty');
    }
    return _generator.generateSelfSigned(
      password: password.trim(),
      subjectName: 'Shedbooks O365 Sync',
    );
  }
}
