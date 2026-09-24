import 'package:flutter/foundation.dart';

/// A lightweight, app-wide mechanism for switching the bottom navigation tab
/// from any pushed route (e.g. the "View Cart" action shown after adding an
/// item). Holds a single listener so [MainNavigationScreen] can react to
/// requests to switch tabs without resorting to a global key hack.
class NavigationService {
  NavigationService._();

  static final NavigationService instance = NavigationService._();

  final _listeners = <int, ValueChanged<int>>{};

  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  /// Registers a tab-switch handler. Returns an unregister callback.
  ValueChanged<int>? Function() listen(ValueChanged<int> onChanged) {
    final id = _listeners.length;
    _listeners[id] = onChanged;
    return () => _listeners.remove(id);
  }

  /// Switches to [index] (a bottom-navigation tab), notifying the active
  /// listener so the shell can update its state.
  void switchTo(int index) {
    _currentIndex = index;
    for (final l in List.of(_listeners.values)) {
      l(index);
    }
  }

  /// Convenience for switching to the Cart tab.
  void openCart() => switchTo(2);
}
