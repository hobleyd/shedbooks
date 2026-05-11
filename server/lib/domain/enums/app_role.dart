/// Application roles in ascending privilege order.
enum AppRole {
  viewer,
  contributor,
  administrator;

  /// Returns true if this role has at least the privileges of [minimum].
  bool atLeast(AppRole minimum) => index >= minimum.index;

  /// Parses a list of Auth0 role strings and returns the highest matching role.
  static AppRole fromClaims(List<dynamic> roles) {
    if (roles.contains('administrator')) return AppRole.administrator;
    if (roles.contains('contributor')) return AppRole.contributor;
    return AppRole.viewer;
  }
}
