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

import '../../domain/repositories/i_entity_details_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';

/// Returns the next invoice number for an entity based on its configured format.
///
/// Format tokens: YYYY (4-digit year), YY (2-digit year), # (sequential digit),
/// other characters are treated as required literals.
/// The `#` tokens must form a contiguous block; digits in that block are padded
/// to the block length.  Returns 001 (padded) when no prior invoice exists.
class GetNextInvoiceNumberUseCase {
  final IEntityDetailsRepository _entityRepo;
  final ITransactionRepository _transactionRepo;

  const GetNextInvoiceNumberUseCase(this._entityRepo, this._transactionRepo);

  /// Returns `(invoiceNumber, format)` for [entityId].
  Future<({String invoiceNumber, String format})> execute(
      String entityId) async {
    final details = await _entityRepo.find(entityId);
    final format =
        (details?.invoiceNumberFormat.trim().isNotEmpty == true)
            ? details!.invoiceNumberFormat.trim()
            : 'WMS-YY-###';

    final resolved = _resolveDate(format);
    final firstHash = resolved.indexOf('#');

    final List<String> existing;
    if (firstHash == -1) {
      existing = [];
    } else {
      final prefix = resolved.substring(0, firstHash);
      existing = await _transactionRepo.findReceiptNumbersLike(
        '$prefix%',
        entityId: entityId,
      );
    }

    final invoiceNumber = generateNext(format, existing);
    return (invoiceNumber: invoiceNumber, format: format);
  }

  /// Generates the next invoice number from [format] given [existingNumbers].
  /// Exposed as a static method so it can be tested independently.
  static String generateNext(String format, List<String> existingNumbers) {
    final resolved = _resolveDate(format);
    final firstHash = resolved.indexOf('#');
    if (firstHash == -1) return resolved;

    int lastHash = firstHash;
    while (lastHash + 1 < resolved.length &&
        resolved[lastHash + 1] == '#') {
      lastHash++;
    }

    final prefix = resolved.substring(0, firstHash);
    final hashCount = lastHash - firstHash + 1;
    final suffix = resolved.substring(lastHash + 1);

    int maxNum = 0;
    for (final num in existingNumbers) {
      if (!num.startsWith(prefix)) continue;
      final afterPrefix = num.substring(prefix.length);
      final String middle;
      if (suffix.isEmpty) {
        middle = afterPrefix;
      } else if (afterPrefix.endsWith(suffix)) {
        middle = afterPrefix.substring(0, afterPrefix.length - suffix.length);
      } else {
        continue;
      }
      final n = int.tryParse(middle);
      if (n != null && n > maxNum) maxNum = n;
    }

    final next = (maxNum + 1).toString().padLeft(hashCount, '0');
    return '$prefix$next$suffix';
  }

  static String _resolveDate(String format) {
    final now = DateTime.now();
    final yyyy = now.year.toString();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    return format.replaceAll('YYYY', yyyy).replaceAll('YY', yy);
  }
}
