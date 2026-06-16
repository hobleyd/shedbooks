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

/// Contract for ABA file sequence number persistence.
abstract interface class IAbaSequenceRepository {
  /// Atomically increments and returns the daily ABA sequence number for [entityId].
  ///
  /// The sequence resets to 1 each calendar day. The first call on a given day
  /// returns 1, the second returns 2, and so on.
  Future<int> nextSequence(String entityId);
}
