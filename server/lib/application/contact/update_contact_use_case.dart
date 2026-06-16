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

import '../../domain/entities/contact.dart';
import '../../domain/exceptions/contact_exception.dart';
import '../../domain/repositories/i_contact_repository.dart';

/// Updates an existing contact.
class UpdateContactUseCase {
  final IContactRepository _repository;

  const UpdateContactUseCase(this._repository);

  Future<Contact> execute({
    required String id,
    required String entityId,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
    String? abn,
    String? bsb,
    String? accountNumber,
  }) async {
    if (name.trim().isEmpty) {
      throw const ContactValidationException('Name must not be empty');
    }
    if (contactType == ContactType.person && gstRegistered) {
      throw const ContactValidationException(
        'A person contact cannot be GST registered',
      );
    }
    if (contactType == ContactType.person && abn != null) {
      throw const ContactValidationException(
        'A person contact cannot have an ABN',
      );
    }
    if (contactType == ContactType.company) {
      final abnValue = abn?.trim() ?? '';
      if (!RegExp(r'^\d{11}$').hasMatch(abnValue)) {
        throw const ContactValidationException(
          'ABN must be exactly 11 digits for a company contact',
        );
      }
    }

    if (bsb != null && bsb.trim().isNotEmpty) {
      if (!RegExp(r'^\d{6}$').hasMatch(bsb.trim())) {
        throw const ContactValidationException('BSB must be 6 digits');
      }
    }
    if (accountNumber != null && accountNumber.trim().isNotEmpty) {
      if (!RegExp(r'^\d{6,10}$').hasMatch(accountNumber.trim())) {
        throw const ContactValidationException(
          'Account number must be 6-10 digits',
        );
      }
    }

    return _repository.update(
      id: id,
      entityId: entityId,
      name: name.trim(),
      contactType: contactType,
      gstRegistered: gstRegistered,
      abn: contactType == ContactType.company ? abn?.trim() : null,
      bsb: bsb?.trim(),
      accountNumber: accountNumber?.trim(),
    );
  }
}
