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

/// Application roles in ascending privilege order.
enum AppRole {
  viewer,
  contributor,
  administrator;

  /// Returns true if this role has at least the privileges of [minimum].
  bool atLeast(AppRole minimum) => index >= minimum.index;

  /// Parses a list of Auth0 role strings and returns the highest matching role.
  static AppRole fromList(List<dynamic> roles) {
    if (roles.contains('administrator')) return AppRole.administrator;
    if (roles.contains('contributor')) return AppRole.contributor;
    return AppRole.viewer;
  }
}
