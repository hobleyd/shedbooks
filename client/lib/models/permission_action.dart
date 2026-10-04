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

/// A specific action button that can be granted independently of its parent
/// [page]'s write permission — when no override exists, it inherits the
/// page's write access. Only actions capable of diverging from their page
/// are registered here (see the server's matching
/// `server/lib/domain/enums/permission_action.dart` for why); every other
/// button on a page is controlled directly by that page's write cell.
///
/// [key] must match the server's `PermissionAction.key` exactly.
enum PermissionAction {
  transactionsImport(
      'transactions-import', 'Import bank statement', PermissionPage.transactions),
  transactionsBankUpload(
      'transactions-bank-upload', 'Bank Upload (ABA)', PermissionPage.transactions),
  invoicesManageUnpaid(
      'invoices-manage-unpaid', 'Edit/delete unpaid invoices', PermissionPage.invoices),
  membersSyncO365('members-sync-o365', 'Sync to O365', PermissionPage.members),
  membersCreateMailbox(
      'members-create-mailbox', 'Create O365 mailbox', PermissionPage.members),
  membersSetRole('members-set-role', 'Grant/change Shedbooks access', PermissionPage.members),
  capexApproveReject(
      'capex-approve-reject', 'Approve/reject requests', PermissionPage.capexRequests),
  contactsRevealBankDetails('contacts-reveal-bank-details', 'Reveal masked bank details',
      PermissionPage.adminContacts),
  contactsTogglePaymentMethod('contacts-toggle-payment-method',
      'Change payment method on an existing contact', PermissionPage.adminContacts);

  final String key;
  final String label;
  final PermissionPage page;
  const PermissionAction(this.key, this.label, this.page);

  static PermissionAction fromKey(String key) =>
      values.firstWhere((a) => a.key == key);
}
