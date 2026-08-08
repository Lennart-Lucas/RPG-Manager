import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists auth tokens.
///
/// Native platforms use [FlutterSecureStorage]. Web uses [SharedPreferences]
/// because secure storage requires HTTPS / localhost (WebCrypto), and the
/// player site may be served over plain HTTP on a VPS IP.
class TokenStore {
  TokenStore({
    FlutterSecureStorage? storage,
    Future<SharedPreferences> Function()? prefsLoader,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              // Data-protection keychain needs keychain-access-groups + a real
              // development signing identity. This project ad-hoc signs macOS
              // (`CODE_SIGN_IDENTITY="-"`), so disable data protection.
              mOptions: MacOsOptions(useDataProtectionKeyChain: false),
            ),
        _prefsLoader = prefsLoader ?? SharedPreferences.getInstance;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  final Future<SharedPreferences> Function() _prefsLoader;

  bool get _usePrefs => kIsWeb;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (_usePrefs) {
      final prefs = await _prefsLoader();
      await prefs.setString(_accessKey, accessToken);
      await prefs.setString(_refreshKey, refreshToken);
      return;
    }
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<String?> readAccessToken() async {
    if (_usePrefs) {
      final prefs = await _prefsLoader();
      return prefs.getString(_accessKey);
    }
    return _storage.read(key: _accessKey);
  }

  Future<String?> readRefreshToken() async {
    if (_usePrefs) {
      final prefs = await _prefsLoader();
      return prefs.getString(_refreshKey);
    }
    return _storage.read(key: _refreshKey);
  }

  Future<void> clear() async {
    if (_usePrefs) {
      final prefs = await _prefsLoader();
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
      return;
    }
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
