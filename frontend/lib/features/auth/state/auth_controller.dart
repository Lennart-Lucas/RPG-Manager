import 'package:flutter/foundation.dart';

import '../../../core/platform/client_platform.dart';
import '../data/auth_api.dart';
import '../data/token_store.dart';
import '../models/auth_models.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthController extends ChangeNotifier {
  AuthController({
    AuthApi? api,
    TokenStore? tokenStore,
  })  : _api = api ?? AuthApi(),
        _tokenStore = tokenStore ?? TokenStore();

  final AuthApi _api;
  final TokenStore _tokenStore;

  AuthStatus status = AuthStatus.unknown;
  UserProfile? user;
  String? errorMessage;
  bool busy = false;

  String? _accessToken;
  String? _refreshToken;

  Future<void> bootstrap() async {
    status = AuthStatus.unknown;
    notifyListeners();

    final refresh = await _tokenStore.readRefreshToken();
    final access = await _tokenStore.readAccessToken();
    if (refresh == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      if (access != null) {
        _accessToken = access;
        _refreshToken = refresh;
        user = await _api.me(access);
        status = AuthStatus.authenticated;
        notifyListeners();
        return;
      }
    } on AuthApiException {
      // try refresh below
    }

    try {
      final tokens = await _api.refresh(refresh);
      await _persistTokens(tokens);
      user = await _api.me(tokens.accessToken);
      status = AuthStatus.authenticated;
    } catch (_) {
      await _tokenStore.clear();
      _accessToken = null;
      _refreshToken = null;
      user = null;
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register(String email, String password) async {
    return _authenticate(() {
      return _api.register(
        email: email.trim(),
        password: password,
        platform: detectClientPlatform(),
      );
    });
  }

  Future<bool> login(String email, String password) async {
    return _authenticate(() {
      return _api.login(email: email.trim(), password: password);
    });
  }

  Future<void> logout() async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final access = _accessToken;
      final refresh = _refreshToken;
      if (access != null) {
        try {
          await _api.logout(
            accessToken: access,
            refreshToken: refresh,
            logoutAll: refresh == null,
          );
        } on AuthApiException {
          // local logout still proceeds
        }
      }
    } finally {
      await _tokenStore.clear();
      _accessToken = null;
      _refreshToken = null;
      user = null;
      status = AuthStatus.unauthenticated;
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> _authenticate(Future<TokenPair> Function() action) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final tokens = await action();
      await _persistTokens(tokens);
      user = await _api.me(tokens.accessToken);
      status = AuthStatus.authenticated;
      return true;
    } on AuthApiException catch (e) {
      errorMessage = e.message;
      status = AuthStatus.unauthenticated;
      return false;
    } catch (e) {
      errorMessage = 'Could not reach the server. Is the API running?';
      status = AuthStatus.unauthenticated;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _persistTokens(TokenPair tokens) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    await _tokenStore.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }
}
