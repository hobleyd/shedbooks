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

import '../entities/o365_sync_settings.dart';
import '../exceptions/o365_sync_exception.dart';

/// One Microsoft 365 license SKU with spare seats in the tenant.
class O365LicenseOption {
  /// The SKU's GUID, as required by `Set-MgUserLicense -AddLicenses`.
  final String skuId;

  /// Microsoft's stable short identifier for the plan (e.g.
  /// `SPB`, `EXCHANGESTANDARD`) — human-recognizable, shown to the admin.
  final String skuPartNumber;

  /// Purchased seats minus consumed seats. Only SKUs with at least one
  /// spare seat are returned by [IO365MailboxService.listAvailableLicenses].
  final int availableUnits;

  const O365LicenseOption({
    required this.skuId,
    required this.skuPartNumber,
    required this.availableUnits,
  });
}

/// Outcome of [IO365MailboxService.createMailbox].
class O365MailboxCreateResult {
  /// The tenant sign-in address the mailbox was created under.
  final String upn;

  /// True once [O365LicenseOption.skuId] was successfully assigned. False
  /// means the account and mailbox were created but licensing failed
  /// (e.g. the seat was taken by a concurrent request between the license
  /// list call and this one) — the account exists and the temporary
  /// password is valid, but the mailbox will not receive mail until an
  /// admin assigns a license manually in the Microsoft 365 admin center.
  final bool licenseAssigned;

  /// Set when [licenseAssigned] is false — the underlying error, for
  /// display to the admin.
  final String? licenseError;

  const O365MailboxCreateResult({
    required this.upn,
    required this.licenseAssigned,
    this.licenseError,
  });
}

/// Creates tenant sign-in accounts (Entra ID user + Exchange mailbox) for
/// club members, and reports which Microsoft 365 licenses have spare seats
/// to assign to them.
///
/// Distinct from [IO365ContactSyncService][1], which only ever creates
/// mail-enabled *contacts* (no sign-in, no mailbox) for the GAL.
///
/// [1]: i_o365_contact_sync_service.dart
abstract interface class IO365MailboxService {
  /// Returns every license SKU in the tenant with at least one spare seat.
  ///
  /// Throws [O365MailboxException] if the session itself could not be
  /// established (bad certificate, PowerShell/module unavailable, network
  /// failure).
  Future<List<O365LicenseOption>> listAvailableLicenses({
    required O365SyncSettings settings,
  });

  /// Creates a new Entra ID user and Exchange mailbox at
  /// `<localPart>@<settings.tenantId>`, sets [temporaryPassword] with a
  /// forced change on first sign-in, and assigns [licenseSkuId].
  ///
  /// Throws [O365MailboxConflictException] if that address is already
  /// taken in the tenant — no suffix is generated automatically; the
  /// caller (an admin) must resolve the collision.
  ///
  /// Throws [O365MailboxException] if the session itself could not be
  /// established, or if [licenseSkuId] no longer has a spare seat by the
  /// time this call runs (re-checked here, not trusted from an earlier
  /// [listAvailableLicenses] call).
  Future<O365MailboxCreateResult> createMailbox({
    required O365SyncSettings settings,
    required String firstName,
    required String lastName,
    required String localPart,
    required String temporaryPassword,
    required String licenseSkuId,
  });
}
