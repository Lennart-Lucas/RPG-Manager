import 'package:flutter/material.dart';

/// Per-page extras for the shell [AppBar].
class ShellPageAppBarData {
  const ShellPageAppBarData({this.actions = const []});

  final List<Widget> actions;
}

/// Lets page bodies (e.g. Spells) update the shell app bar without the shell
/// owning their state.
class ShellPageAppBarStore extends ChangeNotifier {
  ShellPageAppBarStore._();
  static final ShellPageAppBarStore instance = ShellPageAppBarStore._();

  final Map<String, ShellPageAppBarData> _map = {};

  /// Set by [AppShell] each build so [setPageBar] only notifies when visible.
  String? activeShellPageKey;

  void setPageBar(String pageKey, ShellPageAppBarData data) {
    _map[pageKey] = data;
    if (pageKey == activeShellPageKey) {
      notifyListeners();
    }
  }

  void clearPageBar(String pageKey) {
    if (_map.remove(pageKey) != null && pageKey == activeShellPageKey) {
      notifyListeners();
    }
  }

  ShellPageAppBarData? forPage(String pageKey) => _map[pageKey];
}
