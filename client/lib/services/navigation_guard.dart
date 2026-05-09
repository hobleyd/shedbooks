import 'package:flutter/foundation.dart';

/// Tracks whether the current screen has unsaved changes that should
/// block navigation away from it.
class NavigationGuard extends ChangeNotifier {
  bool _isDirty = false;

  bool get isDirty => _isDirty;

  void setDirty(bool dirty) {
    if (_isDirty == dirty) return;
    _isDirty = dirty;
    notifyListeners();
  }
}
