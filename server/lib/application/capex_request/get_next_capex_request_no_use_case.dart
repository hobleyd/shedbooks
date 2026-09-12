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

import '../../domain/repositories/i_capex_request_repository.dart';

/// Returns the next capex request number for an entity.
///
/// Format is fixed at `CER YY-###` (e.g. "CER 26-012"), matching the club's
/// existing paper form numbering — unlike invoice/asset numbers this is not
/// user-configurable since no such requirement has been raised.
class GetNextCapexRequestNoUseCase {
  final ICapexRequestRepository _repository;

  static const format = 'CER YY-###';

  const GetNextCapexRequestNoUseCase(this._repository);

  /// Returns the next request number for [entityId].
  Future<String> execute(String entityId) async {
    final resolved = _resolveDate(format);
    final firstHash = resolved.indexOf('#');
    final prefix = resolved.substring(0, firstHash);
    final existing = await _repository.findRequestNosLike(
      '$prefix%',
      entityId: entityId,
    );
    return generateNext(existing);
  }

  /// Generates the next request number given [existingNumbers].
  /// Exposed as a static method so it can be tested independently.
  static String generateNext(List<String> existingNumbers) {
    final resolved = _resolveDate(format);
    final firstHash = resolved.indexOf('#');

    int lastHash = firstHash;
    while (lastHash + 1 < resolved.length && resolved[lastHash + 1] == '#') {
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
    final yy = (now.year % 100).toString().padLeft(2, '0');
    return format.replaceAll('YY', yy);
  }
}
