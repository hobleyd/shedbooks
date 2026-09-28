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

/// Creates a new contact.
class CreateContactUseCase {
  final IContactRepository _repository;

  const CreateContactUseCase(this._repository);

  Future<Contact> execute({
    required String entityId,
    required String name,
    required ContactType contactType,
    required bool gstRegistered,
    String? abn,
    String? bsb,
    String? accountNumber,
    bool isBpay = false,
    String? bpayBillerCode,
    String? bpayReference,
    String? address,
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

    validateBpayFields(
      isBpay: isBpay,
      bsb: bsb,
      accountNumber: accountNumber,
      bpayBillerCode: bpayBillerCode,
      bpayReference: bpayReference,
    );

    return _repository.create(
      entityId: entityId,
      name: name.trim(),
      contactType: contactType,
      gstRegistered: gstRegistered,
      abn: contactType == ContactType.company ? abn?.trim() : null,
      bsb: isBpay ? null : bsb?.trim(),
      accountNumber: isBpay ? null : accountNumber?.trim(),
      isBpay: isBpay,
      bpayBillerCode: isBpay ? bpayBillerCode?.trim() : null,
      bpayReference: isBpay ? bpayReference?.trim() : null,
      address: address?.trim().isEmpty ?? true ? null : address!.trim(),
    );
  }
}

/// Validates that BSB/account number and BPAY biller code/reference are
/// mutually exclusive per [isBpay], and that whichever pair is in use is
/// well-formed when non-empty. Shared by [CreateContactUseCase] and
/// `UpdateContactUseCase`.
void validateBpayFields({
  required bool isBpay,
  String? bsb,
  String? accountNumber,
  String? bpayBillerCode,
  String? bpayReference,
}) {
  if (isBpay) {
    if (bsb != null && bsb.trim().isNotEmpty) {
      throw const ContactValidationException(
        'BSB must not be set when payment method is BPAY',
      );
    }
    if (accountNumber != null && accountNumber.trim().isNotEmpty) {
      throw const ContactValidationException(
        'Account number must not be set when payment method is BPAY',
      );
    }
    final billerValue = bpayBillerCode?.trim() ?? '';
    if (billerValue.isNotEmpty && !RegExp(r'^\d{3,10}$').hasMatch(billerValue)) {
      throw const ContactValidationException(
        'BPAY biller code must be 3-10 digits',
      );
    }
    final referenceValue = bpayReference?.trim() ?? '';
    if (referenceValue.isNotEmpty &&
        !RegExp(r'^\d{2,20}$').hasMatch(referenceValue)) {
      throw const ContactValidationException(
        'BPAY reference must be 2-20 digits',
      );
    }
  } else {
    if (bpayBillerCode != null && bpayBillerCode.trim().isNotEmpty) {
      throw const ContactValidationException(
        'BPAY biller code must not be set when payment method is bank transfer',
      );
    }
    if (bpayReference != null && bpayReference.trim().isNotEmpty) {
      throw const ContactValidationException(
        'BPAY reference must not be set when payment method is bank transfer',
      );
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
  }
}
