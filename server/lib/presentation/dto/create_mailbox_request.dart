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

/// Request DTO for `POST /members/<id>/create-mailbox`.
///
/// [licenseSkuId] is always required — the client is expected to have
/// already called `GET /members/available-licenses` and resolved which SKU
/// to use (auto-selecting the only option, or prompting the admin when
/// there's more than one).
class CreateMailboxRequest {
  final String licenseSkuId;

  const CreateMailboxRequest({required this.licenseSkuId});

  factory CreateMailboxRequest.fromJson(Map<String, dynamic> json) {
    final licenseSkuId = json['licenseSkuId'];
    if (licenseSkuId is! String || licenseSkuId.isEmpty) {
      throw const FormatException('licenseSkuId must be a non-empty string');
    }
    return CreateMailboxRequest(licenseSkuId: licenseSkuId);
  }
}
