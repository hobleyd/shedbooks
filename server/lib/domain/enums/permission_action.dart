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

import 'permission_page.dart';

/// A specific action button whose permission can be set independently of
/// its parent [page]'s write permission — when no explicit override exists
/// (neither entity-scoped nor global), it simply inherits the page's
/// can_write. Only actions that are genuinely capable of diverging from
/// their page's write permission are registered here; a button with no
/// independent meaning (e.g. a page's only write action) is controlled
/// directly by that page's write cell instead.
///
/// [key] is the stable identifier persisted in
/// `role_action_permission_defaults` / `entity_action_permission_overrides`
/// — keep it in sync with the client's mirrored `PermissionAction` registry
/// in `client/lib/models/permission_action.dart`.
enum PermissionAction {
  transactionsImport('transactions-import', PermissionPage.transactions),
  transactionsBankUpload('transactions-bank-upload', PermissionPage.transactions),
  invoicesManageUnpaid('invoices-manage-unpaid', PermissionPage.invoices),
  membersSyncO365('members-sync-o365', PermissionPage.members),
  membersCreateMailbox('members-create-mailbox', PermissionPage.members),
  membersSetRole('members-set-role', PermissionPage.members),
  capexApproveReject('capex-approve-reject', PermissionPage.capexRequests),
  capexEditDecided('capex-edit-decided', PermissionPage.capexRequests),
  contactsRevealBankDetails('contacts-reveal-bank-details', PermissionPage.adminContacts),
  contactsTogglePaymentMethod('contacts-toggle-payment-method', PermissionPage.adminContacts);

  final String key;
  final PermissionPage page;
  const PermissionAction(this.key, this.page);

  static PermissionAction fromKey(String key) => values.firstWhere(
        (a) => a.key == key,
        orElse: () => throw FormatException('Unknown action key: $key'),
      );
}
