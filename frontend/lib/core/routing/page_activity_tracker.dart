import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/state/auth_controller.dart';
import '../../features/dm_tools/users/data/users_api.dart';
import '../../features/shell/app_page.dart';
import 'app_paths.dart';

/// Reports authenticated DM page navigations to the backend (fire-and-forget).
class PageActivityTracker {
  PageActivityTracker({
    required GoRouter router,
    required AuthController auth,
    UsersApi? api,
  })  : _router = router,
        _auth = auth,
        _api = api ?? UsersApi() {
    _router.routerDelegate.addListener(_onRouteChanged);
    _auth.addListener(_onAuthChanged);
    _onRouteChanged();
  }

  final GoRouter _router;
  final AuthController _auth;
  final UsersApi _api;
  String? _lastReportedPath;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _router.routerDelegate.removeListener(_onRouteChanged);
    _auth.removeListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (_auth.status != AuthStatus.authenticated) {
      _lastReportedPath = null;
    }
  }

  void _onRouteChanged() {
    if (_disposed) return;
    if (_auth.status != AuthStatus.authenticated) return;
    if (!_auth.showsDmUi) return;

    final path = _router.state.uri.path;
    if (AppPaths.isAuthPath(path)) return;
    if (path == _lastReportedPath) return;
    _lastReportedPath = path;

    final page = AppPaths.pageFromPath(path);
    final title = page == null ? path : appPageTitle(page);
    _report(path: path, title: title);
  }

  Future<void> _report({required String path, required String title}) async {
    try {
      final token = await _auth.requireAccessToken();
      if (token == null || _disposed) return;
      await _api.reportPageVisit(
        accessToken: token,
        path: path,
        title: title,
      );
    } catch (e, st) {
      debugPrint('Page activity report failed: $e\n$st');
    }
  }
}
